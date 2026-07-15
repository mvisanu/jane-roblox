"""Verifies the approved 3-male/3-female block avatar selector and Original default."""

from __future__ import annotations

import sys
import time
from pathlib import Path

from quest_chain_test import COOLDOWN, boot


ROOT = Path(__file__).resolve().parents[1]


def values(table):
    return [table[index] for index in range(1, len(table) + 1)]


def rgb(color):
    return tuple(round(float(component) * 255) for component in (color.R, color.G, color.B))


def make_character(lua):
    instance, vector3, cframe = lua.globals().Instance, lua.globals().Vector3, lua.globals().CFrame
    character = instance.new("Model")
    torso = instance.new("Part")
    torso.Name = "Torso"
    torso.Size = vector3.new(2, 2, 1)
    torso.CFrame = cframe.new(0, 3, 0)
    torso.Parent = character
    character.PrimaryPart = torso
    head = instance.new("Part")
    head.Name = "Head"
    head.Size = vector3.new(2, 1, 1)
    head.CFrame = cframe.new(0, 4.5, 0)
    head.Parent = character
    for name, x, y in (
        ("Left Arm", -1.5, 3),
        ("Right Arm", 1.5, 3),
        ("Left Leg", -0.5, 1),
        ("Right Leg", 0.5, 1),
    ):
        limb = instance.new("Part")
        limb.Name = name
        limb.Size = vector3.new(1, 2, 1)
        limb.CFrame = cframe.new(x, y, 0)
        limb.Parent = character
    return character


def main() -> int:
    lua, modules, data, game, player, _toasts = boot()
    catalog = modules["Catalog"]
    avatar_models = modules["AvatarModels"]
    world_service = game._world
    failures: list[str] = []

    expected_order = [
        "MaleTrailRanger",
        "MaleRiverWarden",
        "MaleAutumnArcher",
        "FemaleWildflowerBotanist",
        "FemaleFernGuardian",
        "FemalePineScout",
    ]
    actual_order = values(catalog.AvatarOrder)
    if actual_order != expected_order:
        failures.append(f"avatar order is {actual_order}, expected approved concept order {expected_order}")

    expected_gender = {avatar_id: ("Male" if index < 3 else "Female") for index, avatar_id in enumerate(expected_order)}
    expected_visuals = {
        "MaleTrailRanger": {"TrailScarf", "TrailMapPouch", "LeftFernPatch"},
        "MaleRiverWarden": {"RiverMantle", "LanternFrame", "LanternGlow"},
        "MaleAutumnArcher": {"AutumnScarf", "CompactQuiver", "BowUpper"},
        "FemaleWildflowerBotanist": {"BotanistApron", "FlowerSatchel", "HairFlower1"},
        "FemaleFernGuardian": {"FernBreastplate", "FernRoundShield", "LeftShoulderArmor"},
        "FemalePineScout": {"PineHoodTop", "CompactFieldPack", "FieldNotebook"},
    }
    expected_primary = {
        "MaleTrailRanger": (77, 88, 52),
        "MaleRiverWarden": (18, 63, 58),
        "MaleAutumnArcher": (55, 71, 45),
        "FemaleWildflowerBotanist": (86, 99, 58),
        "FemaleFernGuardian": (50, 74, 53),
        "FemalePineScout": (23, 72, 63),
    }

    retired = ("ForestExplorer", "WildflowerKeeper", "PineScout", "RiverMage", "FernKnight", "AutumnArcher")
    for retired_id in retired:
        if catalog.Outfits[retired_id]:
            failures.append(f"retired preset {retired_id} still exists")

    for concept_index, avatar_id in enumerate(expected_order, start=1):
        outfit = catalog.Outfits[avatar_id]
        if not outfit:
            failures.append(f"{avatar_id} is missing from Catalog.Outfits")
            continue
        if outfit.Style != avatar_id or outfit.Gender != expected_gender[avatar_id]:
            failures.append(f"{avatar_id} identity/gender does not match the approved sheet")
        if outfit.ConceptIndex != concept_index:
            failures.append(f"{avatar_id} concept position is {outfit.ConceptIndex}, expected {concept_index}")
        if rgb(outfit.Palette.Primary) != expected_primary[avatar_id]:
            failures.append(f"{avatar_id} primary color drifted from the approved model")
        for role in ("Primary", "Secondary", "Leather", "Accent", "Light", "Deep", "Hair"):
            if not outfit.Palette[role]:
                failures.append(f"{avatar_id} palette is missing {role}")

        character = make_character(lua)
        visual = avatar_models.Apply(character, avatar_id)
        if not visual:
            failures.append(f"{avatar_id} did not create a block avatar")
            continue
        if visual.GetAttribute(visual, "AvatarStyle") != avatar_id:
            failures.append(f"{avatar_id} visual did not record its identity")
        if visual.GetAttribute(visual, "Gender") != expected_gender[avatar_id]:
            failures.append(f"{avatar_id} visual lost its gender row")
        if visual.GetAttribute(visual, "StandardBlockBody") is not True:
            failures.append(f"{avatar_id} is not marked as a standard Roblox block body")

        children = values(visual.GetChildren(visual))
        names = {child.Name for child in children}
        for body_piece in ("BlockHead", "BlockTorso", "LeftBlockSleeve", "RightBlockBoot", "JacketFront"):
            if body_piece not in names:
                failures.append(f"{avatar_id} standard block body is missing {body_piece}")
        missing = sorted(expected_visuals[avatar_id] - names)
        if missing:
            failures.append(f"{avatar_id} is missing approved details: {', '.join(missing)}")
        if any("Chibi" in name or "Cape" in name or "Backpack" in name for name in names):
            failures.append(f"{avatar_id} still contains a rejected chibi/cape/backpack piece")
        for child in children:
            if child.IsA(child, "BasePart") and max(child.Size.X, child.Size.Y, child.Size.Z) > 2.6:
                failures.append(f"{avatar_id} contains oversized piece {child.Name}")
        for body_piece in ("BlockHead", "BlockTorso"):
            part = visual.FindFirstChild(visual, body_piece)
            if not part or part.Shape.Name != "Block":
                failures.append(f"{avatar_id} {body_piece} is not rectangular")

        preview_world = lua.globals().Instance.new("WorldModel")
        preview = avatar_models.BuildPreview(preview_world, avatar_id)
        preview_visual = preview and preview.FindFirstChild(preview, "ApprovedWoodlandAvatar")
        if not preview_visual or preview_visual.GetAttribute(preview_visual, "AvatarStyle") != avatar_id:
            failures.append(f"{avatar_id} preview does not use the approved live builder")

    # Fresh and migrated profiles must begin with the player's untouched Roblox
    # appearance, then switch and reset through the public server action.
    profile = data.Get(data, player)
    live_character = make_character(lua)
    player.Character = live_character
    world_service.ApplyOutfit(world_service, player, profile)
    if profile.Wardrobe.Equipped != "Original":
        failures.append("new players are forced into a preset instead of their original Roblox avatar")
    if live_character.FindFirstChild(live_character, "ApprovedWoodlandAvatar"):
        failures.append("Original default created an avatar overlay")
    if live_character.FindFirstChild(live_character, "Torso").Transparency != 0:
        failures.append("Original default hid the player's Roblox body")

    result = game.Handle(game, player, "EquipAvatar", lua.table_from({"avatar": "FemaleFernGuardian"}))
    live_visual = live_character.FindFirstChild(live_character, "ApprovedWoodlandAvatar")
    if not result.ok or profile.Wardrobe.Equipped != "FemaleFernGuardian":
        failures.append("choosing a model did not persist the approved avatar")
    if not live_visual or live_visual.GetAttribute(live_visual, "AvatarStyle") != "FemaleFernGuardian":
        failures.append("choosing a model did not replace the live character")
    if live_character.FindFirstChild(live_character, "Torso").Transparency != 1:
        failures.append("chosen model did not hide the original body under its block visual")

    time.sleep(COOLDOWN + 0.05)
    reset = game.Handle(game, player, "EquipAvatar", lua.table_from({"avatar": "Original"}))
    if not reset.ok or profile.Wardrobe.Equipped != "Original":
        failures.append("Original reset did not persist")
    if live_character.FindFirstChild(live_character, "ApprovedWoodlandAvatar"):
        failures.append("Original reset left the selected model attached")
    if live_character.FindFirstChild(live_character, "Torso").Transparency != 0:
        failures.append("Original reset did not restore the player's Roblox body")

    client_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
    grid_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/AvatarGrid.lua").read_text(encoding="utf-8")
    data_source = (ROOT / "src/ServerScriptService/Services/DataService.lua").read_text(encoding="utf-8")
    if 'invoke("EquipAvatar", { avatar = avatarId })' not in client_source:
        failures.append("3D cards do not send the selected avatar to the server")
    if '"EquipAvatar"' not in client_source or '{ avatar = "Original" }' not in client_source:
        failures.append("Style is missing the explicit Original-avatar reset")
    for contract in ('gender .. "AvatarGroup"', 'addGenderGroup(grid, "Male"', 'addGenderGroup(grid, "Female"', "MALE AVATARS", "FEMALE AVATARS", "UIGridLayout"):
        if contract not in grid_source:
            failures.append(f"gender-separated 3x2 grid is missing {contract}")
    if 'Equipped = "Original"' not in data_source:
        failures.append("profile template does not start with the original Roblox avatar")

    if failures:
        print("Approved block avatar system failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Approved block avatar system passed: three male and three female 3D models use "
        "classic rectangular Roblox bodies; Original is the default and reset state."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
