"""Verifies the supplied Stitch Wildwood sheets reach every visual system."""

from __future__ import annotations

import sys
from pathlib import Path

from quest_chain_test import boot


ROOT = Path(__file__).resolve().parents[1]


def values(table):
    return [table[index] for index in range(1, len(table) + 1)]


def rgb(color):
    return tuple(round(float(component) * 255) for component in (color.R, color.G, color.B))


def main() -> int:
    lua, modules, _data, game, player, _toasts = boot()
    style = modules["WildwoodStyle"]
    world_service = game._world
    world = world_service._world
    failures: list[str] = []

    expected_palette = {
        "ForestGreen": (79, 107, 69),
        "EarthBrown": (107, 94, 60),
        "Parchment": (235, 217, 171),
        "MutedOrange": (217, 128, 72),
        "GoldenYellow": (246, 215, 122),
        "SlateBlue": (111, 160, 177),
    }
    for name, expected in expected_palette.items():
        actual = rgb(style.Colors[name])
        if actual != expected:
            failures.append(f"{name} is {actual}, expected supplied swatch {expected}")

    if style.FontNames.Headline != "Plus Jakarta Sans" or style.FontNames.Body != "Quicksand":
        failures.append("the supplied Plus Jakarta Sans / Quicksand typography roles are missing")

    descendants = values(world.GetDescendants(world))
    tree_count = sum(1 for item in descendants if item.GetAttribute(item, "WildwoodTree"))
    sign_count = sum(1 for item in descendants if item.GetAttribute(item, "WildwoodCarvedSign"))
    moss_count = sum(1 for item in descendants if item.GetAttribute(item, "MossyPathTile"))
    bulb_count = sum(1 for item in descendants if item.Name == "StringLightBulb")
    tier_count = sum(1 for item in descendants if item.Name == "PineCrownTier")
    if tree_count < 30 or tier_count < tree_count * 4:
        failures.append(f"tiered pine coverage is incomplete ({tree_count} trees, {tier_count} tiers)")
    if sign_count < 9:
        failures.append(f"only {sign_count} carved signs were generated")
    if moss_count < 40:
        failures.append(f"only {moss_count} mossy path tiles were generated")
    if bulb_count < 36:
        failures.append(f"only {bulb_count} plaza string-light bulbs were generated")

    pet = world_service._createPet(world_service, player)
    scale = pet.GetAttribute(pet, "PetScale")
    species_parts = {
        "Cat": {"CatHead", "CatTail", "CatMuzzle"},
        "Fox": {"FoxHead", "FoxTail", "FoxTailTip"},
        "Dog": {"ShibaHead", "CurledTail1", "Bandana"},
        "Owl": {"OwlHead", "OwlEyeDisc", "OwlWingLeft"},
        "Rabbit": {"RabbitHead", "RabbitEarLeft", "CottonTail"},
    }
    for species, required in species_parts.items():
        world_service._buildCompanionGeometry(world_service, pet, species, scale)
        names = {child.Name for child in values(pet.GetChildren(pet))}
        missing = sorted(required - names)
        if missing:
            failures.append(f"{species} silhouette is missing {', '.join(missing)}")
        if pet.GetAttribute(pet, "CompanionId") != species:
            failures.append(f"{species} did not record its companion identity")

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
    world_service._styleExplorerCharacter(world_service, character, modules["Catalog"].Outfits.MaleTrailRanger)
    kit = character.FindFirstChild(character, "ApprovedWoodlandAvatar")
    if not kit:
        failures.append("characters do not receive the full Wildwood avatar visual")
    else:
        kit_names = {child.Name for child in values(kit.GetChildren(kit))}
        for name in ("BlockHead", "BlockTorso", "TrailScarf", "TrailMapPouch", "TrailMapStrap"):
            if name not in kit_names:
                failures.append(f"character avatar visual is missing {name}")

    source = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")
    theme_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/Theme.lua").read_text(encoding="utf-8")
    contracts = {
        "carvedSignFace": "carved sign system is not wired into the world",
        "_pineTree": "tiered pine generator is missing",
        "_mossyCobble": "mossy path generator is missing",
        "_stringLightSpan": "plaza string lights are missing",
        "_buildCompanionGeometry": "species-specific companion generator is missing",
        "_styleExplorerCharacter": "explorer character styling is missing",
    }
    for contract, message in contracts.items():
        if contract not in source:
            failures.append(message)
    if "WildwoodStyle.Colors" not in theme_source:
        failures.append("UI theme does not use the supplied Wildwood palette")

    if failures:
        print("Wildwood redesign failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Wildwood redesign passed: exact 6-swatch palette, supplied font roles, "
        f"{tree_count} tiered pines, {sign_count} carved signs, {moss_count} mossy stones, "
        f"{bulb_count} string lights, 5 distinct pets, and approved block avatar."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
