"""Proves the furniture shop actually works, end to end.

These tests drive the real GameService and prove buying is a two-step flow:
reserve one preview, choose its exact pose, then atomically spend and place.
They also check that placement cannot cross a wall or overlap another piece,
that move/rotate/pack work, and that everything survives a rejoin.

Also covers the XP and level system, which shares the same profile.

Usage:
    python scripts/furniture_test.py [--verbose]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:  # pragma: no cover
    print("This test needs the Lua bridge. Install it with: python -m pip install lupa")
    raise SystemExit(2)

sys.path.insert(0, str(Path(__file__).resolve().parent))

from walkability_test import SHARED_MODULES, luau_to_lua  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]

APPROVED_WOODLAND_CANOPY = {
    (38, 53, 31),    # Pine Needle
    (67, 90, 50),    # Forest Fern
    (104, 115, 74),  # Woodland Moss
    (164, 167, 122), # Pale Lichen
    (126, 146, 133), # Eucalyptus
    (89, 106, 100),  # River Slate
    (154, 136, 112), # Mushroom
    (201, 180, 143), # Reed Linen
    (199, 146, 62),  # Goldenrod
    (216, 198, 155), # Yarrow Cream
    (139, 90, 91),   # Foxglove Berry
    (89, 58, 32),    # Timber Trim
}
TIMBER_TRIM = (89, 58, 32)


def color_key(color) -> tuple[int, int, int]:
    return tuple(round(channel * 255) for channel in (color.R, color.G, color.B))


def boot():
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path: Path, name: str):
        result = lua.eval(f"function(s) return load(s, {name!r}) end")(luau_to_lua(path.read_text(encoding="utf-8")))
        if isinstance(result, tuple):
            raise SystemExit(f"Could not parse {path}: {result[1]}")
        return result

    mock = load(ROOT / "scripts/robloxmock.lua", "@robloxmock")()
    mock.install(lua.globals())

    shared = ROOT / "src/ReplicatedStorage/Shared"
    modules = {}
    for name in SHARED_MODULES:
        modules[name] = load(shared / f"{name}.lua", f"@{name}")()
        mock.registerModule(name, modules[name])

    services = ROOT / "src/ServerScriptService/Services"
    data = load(services / "DataService.lua", "@DataService")().new()
    world = load(services / "WorldService.lua", "@WorldService")()
    game_service = load(services / "GameService.lua", "@GameService")()

    remotes = lua.eval(
        "{ Toast = { FireClient = function() end },"
        "  StateChanged = { FireClient = function() end },"
        "  Request = {} }"
    )
    world_instance = world.new(remotes)
    game = game_service.new(data, world_instance, remotes)

    player = lua.globals().Instance.new("Player")
    player.Name = "Decorator"
    player.DisplayName = "Decorator"
    player.UserId = 11
    data.Load(data, player)
    world_instance.AssignHome(world_instance, player)

    return lua, modules, data, game, world_instance, player


def placed_count(profile) -> int:
    return len(dict(profile.Home.Furniture))


def ok_of(result) -> bool:
    """_handleAction returns (ok, message); lupa hands that back as a tuple."""
    if isinstance(result, tuple):
        return bool(result[0])
    return bool(result)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    lua, modules, data, game, world, player = boot()
    furniture = modules["Furniture"]
    placement = modules["Placement"]
    progression = modules["Progression"]
    profile = data.Get(data, player)
    failures: list[str] = []

    catalogue = dict(furniture.Items)
    if args.verbose:
        print(f"{len(catalogue)} furniture items across {len(dict(furniture.Categories))} categories\n")

    # Every item must be complete enough to buy, price, rank and build.
    furniture_colors: set[tuple[int, int, int]] = set()
    furniture_volume = 0.0
    timber_volume = 0.0
    for item_id, item in catalogue.items():
        if not item.Name or not item.NameThai:
            failures.append(f"{item_id}: has no name")
        if (item.Price or 0) <= 0:
            failures.append(f"{item_id}: has no price")
        if not furniture.Rarities[item.Rarity]:
            failures.append(f"{item_id}: rarity '{item.Rarity}' is not a real rarity")
        if (item.W or 0) <= 0 or (item.D or 0) <= 0:
            failures.append(f"{item_id}: has no footprint, so it cannot be grid-snapped")
        if len(dict(item.Parts)) == 0:
            failures.append(f"{item_id}: has no parts, so it would be invisible")
        for part in dict(item.Parts).values():
            if not part.Color:
                continue
            rgb = color_key(part.Color)
            furniture_colors.add(rgb)
            if rgb not in APPROVED_WOODLAND_CANOPY:
                failures.append(f"{item_id}: uses colour {rgb} outside Woodland Canopy")
            if part.Size:
                volume = float(part.Size.X * part.Size.Y * part.Size.Z)
                furniture_volume += volume
                if rgb == TIMBER_TRIM:
                    timber_volume += volume

    if len(catalogue) != 51:
        failures.append(f"Woodland Canopy was expected on 51 furniture items, found {len(catalogue)}")
    if furniture_colors != APPROVED_WOODLAND_CANOPY:
        missing = sorted(APPROVED_WOODLAND_CANOPY - furniture_colors)
        failures.append(f"Woodland Canopy colours are not all represented across the catalogue: missing={missing}")
    timber_share = timber_volume / furniture_volume if furniture_volume else 1.0
    if timber_share > 0.15:
        failures.append(f"brown timber occupies {timber_share:.1%} of furniture volume; approved maximum is 15%")

    shop_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/FurnitureShop.lua").read_text(encoding="utf-8")
    client_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
    for contract in (
        'self:_startPurchase(itemId)',
        '"BeginFurniturePurchase"',
        '"CancelFurniturePurchase"',
        'Purchase = purchase == true',
        'payload = { item = draft.Id, x = draft.X, z = draft.Z, r = draft.R }',
        'if visible and self._draft then',
    ):
        if contract not in shop_source:
            failures.append(f"placement-before-purchase UI contract is missing: {contract}")
    if "function(action, payload, onComplete)" not in client_source:
        failures.append("furniture requests cannot wait for server confirmation before ending placement")

    def free_spot(item_id: str):
        result = placement.findFreeSpot(profile.Home.Furniture, item_id)
        if not isinstance(result, tuple) or len(result) < 3 or result[0] is None:
            return None
        return float(result[0]), float(result[1]), int(result[2])

    def begin_purchase(item_id: str):
        return game._handleAction(game, player, "BeginFurniturePurchase", lua.table_from({"item": item_id}))

    def buy_and_place(item_id: str, pose=None):
        begun = begin_purchase(item_id)
        if not ok_of(begun):
            return begun
        chosen = pose or free_spot(item_id)
        if not chosen:
            return False, "test could not find a free pose"
        x, z, rotation = chosen
        return game._handleAction(game, player, "BuyFurniture", lua.table_from(
            {"item": item_id, "x": x, "z": z, "r": rotation}
        ))

    # A direct BUY is forbidden: preview/position must happen first and neither
    # coins, ownership nor placed state may change before final confirmation.
    profile.Coins = 100000
    profile.Daily.Quest.Completed = True
    before = placed_count(profile)
    coins_before = profile.Coins
    direct = game._handleAction(game, player, "BuyFurniture", lua.eval(
        '{ item = "Sofa", x = 5, z = 0, r = 90 }'
    ))
    if ok_of(direct):
        failures.append("server allowed a furniture purchase without placement preview")
    if placed_count(profile) != before or profile.Coins != coins_before or (profile.Home.OwnedFurniture.Sofa or 0):
        failures.append("unpreviewed purchase changed coins, ownership or the house")

    begun = begin_purchase("Sofa")
    if not ok_of(begun):
        failures.append("the sofa placement preview could not be started")
    if placed_count(profile) != before or profile.Coins != coins_before or (profile.Home.OwnedFurniture.Sofa or 0):
        failures.append("starting the placement preview spent coins or created furniture")

    overlapping_begin = begin_purchase("Bed")
    if ok_of(overlapping_begin):
        failures.append("a second furniture purchase started before the current placement was finished")

    invalid = game._handleAction(game, player, "BuyFurniture", lua.eval(
        '{ item = "Sofa", x = 40, z = 0, r = 0 }'
    ))
    if ok_of(invalid):
        failures.append("purchase confirmation accepted a position through the wall")
    if placed_count(profile) != before or profile.Coins != coins_before:
        failures.append("invalid purchase confirmation charged coins or placed furniture")

    chosen_pose = (5, 0, 90)
    can, why = placement.canPlace(profile.Home.Furniture, "Sofa", *chosen_pose)
    if not can:
        failures.append(f"the test's chosen sofa pose is not legal: {why}")
    result = game._handleAction(game, player, "BuyFurniture", lua.table_from(
        {"item": "Sofa", "x": chosen_pose[0], "z": chosen_pose[1], "r": chosen_pose[2]}
    ))
    if not ok_of(result):
        failures.append("confirming the positioned sofa was rejected")
    after = placed_count(profile)
    if after != before + 1:
        failures.append(f"confirmed sofa was not placed (placed went {before} -> {after})")
    else:
        sofa = profile.Home.Furniture[after]
        if (sofa.X, sofa.Z, sofa.R) != chosen_pose:
            failures.append(f"sofa ignored the player's pose and appeared at {(sofa.X, sofa.Z, sofa.R)}")
    if (profile.Home.OwnedFurniture.Sofa or 0) != 1:
        failures.append("confirmed sofa purchase did not record exactly one owned copy")
    if coins_before - profile.Coins != int(catalogue["Sofa"].Price):
        failures.append("confirmed sofa purchase did not charge exactly its catalogue price")

    # Cancelling clears the pending purchase and never charges the player.
    cancel_coins = profile.Coins
    cancel_count = placed_count(profile)
    if not ok_of(begin_purchase("GoldenChandelier")):
        failures.append("a new preview could not start after completing the previous purchase")
    cancelled = game._handleAction(game, player, "CancelFurniturePurchase", lua.eval("{}"))
    if not ok_of(cancelled):
        failures.append("pending furniture purchase could not be cancelled")
    after_cancel = game._handleAction(game, player, "BuyFurniture", lua.eval(
        '{ item = "GoldenChandelier", x = 0, z = 0, r = 0 }'
    ))
    if ok_of(after_cancel) or profile.Coins != cancel_coins or placed_count(profile) != cancel_count:
        failures.append("cancelled preview still bought furniture or spent coins")

    # It costs money only when the chosen pose is confirmed.
    coins_before = profile.Coins
    bed_purchase = buy_and_place("Bed")
    if not ok_of(bed_purchase):
        failures.append("positioned bed purchase was rejected")
    spent = coins_before - profile.Coins
    if spent != int(catalogue["Bed"].Price):
        failures.append(f"a bed cost {spent} coins, the catalogue says {int(catalogue['Bed'].Price)}")

    # No money, no furniture.
    profile.Coins = 0
    poor = begin_purchase("GoldenChandelier")
    if ok_of(poor):
        failures.append("a player with no coins still entered chandelier purchase placement")
    profile.Coins = 100000

    # Placement rules: through a wall, and on top of something else.
    ok, _ = placement.canPlace(profile.Home.Furniture, "Bed", 40, 0, 0)
    if ok:
        failures.append("a bed could be placed outside the house, through the wall")
    ok, _ = placement.canPlace(profile.Home.Furniture, "Bookshelf", 0, -6, 0)
    if ok:
        failures.append("furniture could be placed in the doorway, walling the player in")

    first = profile.Home.Furniture[1]
    ok, _ = placement.canPlace(profile.Home.Furniture, "Bookshelf", first.X, first.Z, 0)
    if ok:
        failures.append("furniture could be placed on top of other furniture")

    # Garden things belong on the lawn, not the living room.
    ok, _ = placement.canPlace(profile.Home.Furniture, "Swing", 0, 0, 0)
    if ok:
        failures.append("a garden swing could be placed inside the living room")

    # Move and rotate. A rotated sofa is 4 wide by 8 deep, so it only fits with
    # its centre far enough from the walls: the server must accept this one.
    game._handleAction(game, player, "RemoveFurniture", lua.eval("{ index = 2 }"))
    target_x, target_z, target_r = -5, 0, 90
    can, why = placement.canPlace(profile.Home.Furniture, "Sofa", target_x, target_z, target_r, 1)
    if not can:
        failures.append(f"the test's own move target is not legal: {why}")
    moved = game._handleAction(game, player, "MoveFurniture", lua.table_from(
        {"index": 1, "x": target_x, "z": target_z, "r": target_r}
    ))
    entry = profile.Home.Furniture[1]
    if not ok_of(moved):
        failures.append(f"furniture could not be moved or rotated: {moved[1] if isinstance(moved, tuple) else ''}")
    elif (entry.X, entry.Z, entry.R) != (target_x, target_z, target_r):
        failures.append(f"move did not stick: item is at ({entry.X}, {entry.Z}, r={entry.R})")

    # And an illegal move must be refused outright.
    refused = game._handleAction(game, player, "MoveFurniture", lua.eval("{ index = 1, x = 40, z = 0, r = 0 }"))
    if ok_of(refused):
        failures.append("furniture could be moved out through the wall")

    # Rotation swaps the footprint, which is why it has to be validated.
    width, depth = furniture.footprint("Sofa", 0)
    turned_width, turned_depth = furniture.footprint("Sofa", 90)
    if (width, depth) != (turned_depth, turned_width):
        failures.append("rotating an item did not swap its footprint")

    # Pack away.
    count_before = placed_count(profile)
    game._handleAction(game, player, "RemoveFurniture", lua.eval("{ index = 1 }"))
    if placed_count(profile) != count_before - 1:
        failures.append("packing furniture away did not remove it from the house")

    # Favourites.
    game._handleAction(game, player, "FavoriteFurniture", lua.eval('{ item = "Sofa" }'))
    if not profile.Home.Favorites.Sofa:
        failures.append("an item could not be favourited")
    game._handleAction(game, player, "FavoriteFurniture", lua.eval('{ item = "Sofa" }'))
    if profile.Home.Favorites.Sofa:
        failures.append("a favourite could not be un-favourited")

    # Buy a few more, then prove it all survives a rejoin.
    for item_id in ("CoffeeTable", "Bookshelf", "FloorLamp", "GardenBench"):
        purchased = buy_and_place(item_id)
        if not ok_of(purchased):
            failures.append(f"positioned purchase failed for {item_id}")

    saved = [
        (str(e.Id), e.X, e.Z, e.R)
        for e in dict(profile.Home.Furniture).values()
    ]
    if not saved:
        failures.append("nothing was in the house to save")

    # Rejoining runs the profile back through the sanitiser, exactly as a real
    # DataStore load does. Positions and rotations must come back unchanged.
    reloaded = data.Get(data, player)
    data.Unload(data, player)
    data.Load(data, player)
    reloaded = data.Get(data, player)
    restored = [
        (str(e.Id), e.X, e.Z, e.R)
        for e in dict(reloaded.Home.Furniture).values()
    ]
    if restored != saved:
        failures.append(
            f"furniture did not survive a rejoin: saved {len(saved)} pieces, got {len(restored)} back"
        )
    elif args.verbose:
        print(f"  {len(saved)} pieces survived a rejoin with their positions and rotations intact")

    # An outdoor piece must have been put outside, not in the lounge.
    for item_id, x, z, _r in saved:
        if furniture.isOutdoor(item_id):
            yard = modules["Config"].Furniture.Yard
            if not (yard.MinX <= x <= yard.MaxX and yard.MinZ <= z <= yard.MaxZ):
                failures.append(f"{item_id} is a garden piece but was placed at ({x}, {z}), off the lawn")

    # --- XP and levels ------------------------------------------------------
    if int(progression.costForLevel(1)) != 100:
        failures.append("level 1 does not need 100 XP")
    if int(progression.costForLevel(2)) != 250:
        failures.append("level 2 does not need 250 XP")
    if int(progression.costForLevel(3)) != 450:
        failures.append("level 3 does not need 450 XP")

    level, xp, gained = progression.addXP(1, 0, 100)
    if level != 2 or gained != 1:
        failures.append(f"100 XP did not take a level 1 player to level 2 (got level {level})")

    # A single big award may cross several levels at once.
    level, xp, gained = progression.addXP(1, 0, 100 + 250 + 450)
    if level != 4 or gained != 3:
        failures.append(f"800 XP should reach level 4 in one go, reached level {level}")

    if str(progression.badgeText(7)) != "⭐ Level 7":
        failures.append(f"badge text is wrong: {progression.badgeText(7)}")

    # Playing the game earns XP.
    fresh = data.Get(data, player)
    fresh.Level, fresh.XP = 1, 0
    game._awardXP(game, player, "CafeServe", 1)
    if fresh.XP != int(progression.rewardFor("CafeServe")):
        failures.append("serving a cafe guest awarded no XP")

    # Enough of it levels you up.
    fresh.Level, fresh.XP = 1, 0
    for _ in range(20):
        game._awardXP(game, player, "CafeServe", 1)
    if fresh.Level < 2:
        failures.append("twenty cafe serves did not level the player up even once")
    elif args.verbose:
        print(f"  20 cafe serves took the player to level {fresh.Level} ({fresh.XP} XP into it)")

    if failures:
        print("Furniture and XP failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        f"Furniture and XP passed: {len(catalogue)} items use exclusive preview-before-purchase, "
        "coins are spent only on a server-validated chosen pose, "
        "walls and doorways block placement, move/rotate/remove work, everything survives a rejoin, "
        f"Woodland Canopy covers all pieces with {timber_share:.1%} timber trim, and the XP curve is 100/250/450 as specified."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
