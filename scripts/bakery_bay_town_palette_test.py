"""Proves world and furniture colours stay in their approved palettes.

Characters, pet palettes and purely UI rarity stripes are the only deliberate
exceptions. Architecture, landscape, foods, resources and environment use
Bakery Bay; placed furniture uses Woodland Canopy and no independent literals.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from walkability_test import load_world  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "src/ReplicatedStorage/Shared"
WORLD_SERVICE = ROOT / "src/ServerScriptService/Services/WorldService.lua"
ENVIRONMENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/EnvironmentController.lua"

APPROVED_ROLES = {
    "TimberDeep": (29, 17, 8),
    "TimberDark": (42, 31, 20),
    "TimberMid": (69, 44, 23),
    "TimberWarm": (89, 58, 32),
    "TimberLight": (147, 103, 63),
    "RoofShadow": (59, 35, 21),
    "RoofTile": (130, 78, 48),
    "RoofHighlight": (149, 98, 59),
    "StoneDeep": (45, 41, 35),
    "Stone": (75, 67, 58),
    "StoneLight": (126, 112, 97),
    "Cobble": (95, 83, 71),
    "Plaster": (197, 160, 117),
    "CanvasLight": (224, 200, 165),
    "Terracotta": (129, 68, 39),
    "FoliageDeep": (32, 34, 19),
    "Foliage": (52, 56, 27),
    "Grass": (69, 72, 34),
    "FoliageLight": (91, 93, 45),
    "Soil": (54, 39, 25),
    "Water": (79, 103, 96),
    "WaterLight": (130, 150, 138),
    "Window": (217, 162, 90),
    "Lantern": (240, 184, 90),
    "Glass": (215, 187, 149),
    "Flower": (224, 200, 165),
    "DaySky": (215, 187, 149),
    "DayFog": (198, 168, 131),
    "NightSky": (27, 27, 32),
}

APPROVED_FURNITURE_ROLES = {
    "PineNeedle": (38, 53, 31),
    "ForestFern": (67, 90, 50),
    "WoodlandMoss": (104, 115, 74),
    "PaleLichen": (164, 167, 122),
    "Eucalyptus": (126, 146, 133),
    "RiverSlate": (89, 106, 100),
    "Mushroom": (154, 136, 112),
    "ReedLinen": (201, 180, 143),
    "Goldenrod": (199, 146, 62),
    "YarrowCream": (216, 198, 155),
    "FoxgloveBerry": (139, 90, 91),
    "TimberTrim": (89, 58, 32),
}

RGB = re.compile(r"Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)")


def rgb_literals(source: str) -> list[tuple[int, int, int]]:
    return [tuple(map(int, match)) for match in RGB.findall(source)]


def literal_palette(source: str, table_name: str) -> dict[str, tuple[int, int, int]] | None:
    match = re.search(rf"WildwoodStyle\.{table_name}\s*=\s*\{{(.*?)\n\}}", source, re.DOTALL)
    if not match:
        return None
    return {
        role: (int(red), int(green), int(blue))
        for role, red, green, blue in re.findall(
            r"(\w+)\s*=\s*Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)",
            match.group(1),
        )
    }


def main() -> int:
    failures: list[str] = []
    style_source = (SHARED / "WildwoodStyle.lua").read_text(encoding="utf-8")
    actual_roles = literal_palette(style_source, "World")
    if actual_roles is None:
        failures.append("WildwoodStyle.World palette block is missing")
    elif actual_roles != APPROVED_ROLES:
        missing = sorted(set(APPROVED_ROLES) - set(actual_roles))
        extra = sorted(set(actual_roles) - set(APPROVED_ROLES))
        changed = sorted(
            role
            for role in set(actual_roles) & set(APPROVED_ROLES)
            if actual_roles[role] != APPROVED_ROLES[role]
        )
        failures.append(
            f"central Bakery Bay palette drifted (missing={missing}, extra={extra}, changed={changed})"
        )

    actual_furniture_roles = literal_palette(style_source, "Furniture")
    if actual_furniture_roles is None:
        failures.append("WildwoodStyle.Furniture palette block is missing")
    elif actual_furniture_roles != APPROVED_FURNITURE_ROLES:
        missing = sorted(set(APPROVED_FURNITURE_ROLES) - set(actual_furniture_roles))
        extra = sorted(set(actual_furniture_roles) - set(APPROVED_FURNITURE_ROLES))
        changed = sorted(
            role
            for role in set(actual_furniture_roles) & set(APPROVED_FURNITURE_ROLES)
            if actual_furniture_roles[role] != APPROVED_FURNITURE_ROLES[role]
        )
        failures.append(
            f"central Woodland Canopy palette drifted (missing={missing}, extra={extra}, changed={changed})"
        )

    # No world-producing module may hide an independent colour literal.
    source_contracts = {
        WORLD_SERVICE: [(255, 224, 189), (255, 224, 189)],  # cafe guest character skin
        SHARED / "CafeModels.lua": [],
        SHARED / "Config.lua": [],
        SHARED / "Catalog.lua": [(238, 183, 123)],  # approved character-sheet skin
        SHARED / "Furniture.lua": [
            (110, 120, 126),
            (46, 116, 181),
            (124, 77, 178),
            (176, 118, 20),
        ],  # UI-only rarity stripes
        ENVIRONMENT: [],
    }
    for path, allowed in source_contracts.items():
        found = rgb_literals(path.read_text(encoding="utf-8"))
        if Counter(found) != Counter(allowed):
            failures.append(
                f"{path.name} contains unapproved direct RGB literals: "
                f"found={Counter(found)}, allowed={Counter(allowed)}"
            )

    parts, _ = load_world(False)
    palette_values = set(APPROVED_ROLES.values())
    furniture_values = set(APPROVED_FURNITURE_ROLES.values())
    ignored_names = {"TownSpawn"}  # fully transparent Roblox spawn marker
    visible_world = [
        row
        for row in parts
        if ".CuteFamilyTown." in row["path"]
        and ".Pets." not in row["path"]
        and row["name"] not in ignored_names
    ]
    outside_rows = [
        row
        for row in visible_world
        if (row["r"], row["g"], row["b"])
        not in (palette_values | furniture_values if ".PlacedFurniture." in row["path"] else palette_values)
    ]
    outside = sorted({(row["r"], row["g"], row["b"]) for row in outside_rows})
    if outside_rows:
        examples = {
            rgb: [row["path"] for row in outside_rows if (row["r"], row["g"], row["b"]) == rgb][:3]
            for rgb in outside
        }
        failures.append(f"generated geometry contains colours outside its approved palette: {examples}")

    # Character and pet source blocks must remain explicitly separate.
    if "WildwoodStyle.Pets = {" not in style_source:
        failures.append("pet palette was removed instead of preserved")
    catalog_source = (SHARED / "Catalog.lua").read_text(encoding="utf-8")
    if (
        "Catalog.Outfits = {" not in catalog_source
        or "local SKIN = Color3.fromRGB(238, 183, 123)" not in catalog_source
        or catalog_source.count("Arms = SKIN") != 6
        or "WildwoodStyle.Avatars = {" not in style_source
    ):
        failures.append("six-avatar character palette was not preserved")

    if failures:
        print("Bakery Bay whole-town palette failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        f"Bakery Bay + Woodland Canopy palettes passed: {len(visible_world):,} generated world parts use only "
        f"{len(palette_values)} approved world colours, furniture has {len(furniture_values)} approved colours; RGB literals are centralized, "
        "while character, pet and UI-only rarity colours remain separate."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
