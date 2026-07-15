"""Drives the real bag rules, server actions, capacity guards and grid contracts."""

from __future__ import annotations

import sys
from pathlib import Path

from quest_chain_test import boot


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    lua, modules, data_service, game, player, _toasts = boot()
    config = modules["Config"]
    bag = modules["BagInventory"]
    profile = data_service.Get(data_service, player)
    failures: list[str] = []

    if int(config.Bag.StartingSlots) != 20:
        failures.append(f"new bags start with {config.Bag.StartingSlots} slots instead of 20")
    if int(profile.Adventure.BagSlots) != 20:
        failures.append(f"a fresh profile has {profile.Adventure.BagSlots} bag slots instead of 20")
    if int(config.Bag.StackSize) != 10:
        failures.append("material stacks are not capped at 10 items per grid cell")
    if int(config.Bag.SlotsPerUpgrade) != 5 or int(config.Bag.MaxSlots) != 60:
        failures.append("bag upgrades must add 5 slots up to a 60-slot maximum")

    sample = lua.table_from({"Wood": 21, "Stone": 10, "Herbs": 1, "Fish": 0, "Crystal": 11})
    if int(bag.usedSlots(sample)) != 7:
        failures.append(f"stack arithmetic used {bag.usedSlots(sample)} slots, expected 7")
    stacks = bag.stacks(sample)
    if len(stacks) != 7:
        failures.append(f"grid produced {len(stacks)} material cells, expected 7")
    if int(bag.slotsForExisting(lua.table_from({"Wood": 230}))) != 25:
        failures.append("a legacy 23-stack inventory was not preserved in a 25-slot bag")

    prices: list[int] = []
    slots = 20
    while True:
        upgrade = bag.nextUpgrade(slots)
        if upgrade is None:
            break
        prices.append(int(upgrade.Cost))
        if int(upgrade.Slots) != slots + 5:
            failures.append(f"upgrade from {slots} did not add exactly 5 slots")
        slots = int(upgrade.Slots)
    if slots != 60 or prices != [500, 750, 1000, 1250, 1500, 1750, 2000, 2250]:
        failures.append(f"bag price path ended at {slots} with prices {prices}")
    if bag.nextUpgrade(60) is not None:
        failures.append("a maximum bag can still be upgraded")

    # Fill all twenty starter slots with real Wildwood stacks.
    for resource_id in ("Wood", "Stone", "Herbs", "Fish", "Crystal"):
        profile.Adventure.Resources[resource_id] = 0
    profile.Adventure.Resources.Wood = 200
    profile.Adventure.BagSlots = 20
    profile.Coins = 500
    chain_before = (
        int(profile.Quests.ChainIndex),
        int(profile.Quests.Step),
        int(profile.Quests.Progress),
    )

    lua.globals().bagGame = game
    lua.execute("bagGame._isNearWaypoint = function() return true end")
    collect = lua.table_from({"zone": "WildwoodForest", "resource": "Wood"})
    ok, message = game._handleAction(game, player, "AdventureCollect", collect)
    if ok or int(profile.Adventure.Resources.Wood) != 200 or "full" not in str(message).lower():
        failures.append("the server allowed collection past the 20-slot limit")

    # Expand through the real server action. It must charge coins, add five cells,
    # leave quest progress alone, and allow the previously rejected node at once.
    ok, _ = game._handleAction(game, player, "BagUpgrade", lua.table())
    if not ok or int(profile.Adventure.BagSlots) != 25 or int(profile.Coins) != 0:
        failures.append("the first 500-coin purchase did not expand 20 slots to 25")
    chain_after = (
        int(profile.Quests.ChainIndex),
        int(profile.Quests.Step),
        int(profile.Quests.Progress),
    )
    if chain_after != chain_before:
        failures.append("buying bag space advanced the story")
    ok, _ = game._handleAction(game, player, "AdventureCollect", collect)
    if not ok or int(profile.Adventure.Resources.Wood) != 201:
        failures.append("a full-bag rejection consumed the node cooldown or expansion did not make room")

    slots_before = int(profile.Adventure.BagSlots)
    ok, _ = game._handleAction(game, player, "BagUpgrade", lua.table())
    if ok or int(profile.Adventure.BagSlots) != slots_before:
        failures.append("the server granted the 750-coin upgrade without enough coins")

    # Cave rewards and gifts must obey the same capacity, not bypass it.
    profile.Adventure.Resources.Wood = 250
    profile.Adventure.Resources.Crystal = 0
    profile.Adventure.PuzzleStep = 3
    profile.Adventure.PuzzlesSolved = 0
    ok, message = game._handleAction(
        game, player, "AdventurePuzzleRune", lua.table_from({"rune": "Sun"})
    )
    if ok or int(profile.Adventure.Resources.Crystal) != 0 or int(profile.Adventure.PuzzleStep) != 3:
        failures.append("the Mystery Cave pushed crystals into a full bag")
    if "full" not in str(message).lower():
        failures.append("the full-bag cave refusal does not explain the problem")

    client = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
    grid_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/BagGrid.lua").read_text(encoding="utf-8")
    game_source = (ROOT / "src/ServerScriptService/Services/GameService.lua").read_text(encoding="utf-8")
    data_source = (ROOT / "src/ServerScriptService/Services/DataService.lua").read_text(encoding="utf-8")
    for contract in ("UIGridLayout", 'grid.Name = "BagGrid"', "BagInventory.stacks", "FillDirectionMaxCells = columns"):
        if contract not in grid_source:
            failures.append(f"Bag UI lost its grid contract: {contract}")
    if "BagGrid.create" not in client or '"BagUpgrade"' not in client:
        failures.append("the player Bag menu does not use the tested grid and upgrade action")
    for contract in (
        "BagInventory.canAdd(data.Adventure.BagSlots",
        'action == "BagUpgrade"',
        "targetData.Adventure.BagSlots",
    ):
        if contract not in game_source:
            failures.append(f"server bag authority is missing: {contract}")
    if "BagSlots = Config.Bag.StartingSlots" not in data_source:
        failures.append("bag capacity is not saved in the player profile")

    if failures:
        print("Bag inventory failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        "Bag inventory passed: 20-slot material grid, 10-item stacks, "
        "coin-priced +5 expansions to 60, full-bag guards, migration, and cave safety."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
