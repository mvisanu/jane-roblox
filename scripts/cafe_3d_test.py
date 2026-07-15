"""Checks that every cafe food is real, distinct 3D geometry throughout the game."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODELS = (ROOT / "src/ReplicatedStorage/Shared/CafeModels.lua").read_text(encoding="utf-8")
WORLD = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")
CLIENT = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
GAME = (ROOT / "src/ServerScriptService/Services/GameService.lua").read_text(encoding="utf-8")

ITEMS = {
    "MoonBerryTart": ("buildTart", "GoldenTartCrust", "MoonBerryFilling", "BraidedCrust"),
    "MoonberryCake": ("buildCake", "LavenderCakeLower", "VanillaFrostingTop", "MoonTopper"),
    "StarCupcake": ("buildCupcake", "CupcakeWrapper", "FrostingPeak", "StarPoint"),
    "SunTea": ("buildTea", "GlassCup", "GoldenTea", "LemonWheel"),
}


def main() -> int:
    failures: list[str] = []

    for item_id, required in ITEMS.items():
        mapping = rf"{item_id}\s*=\s*{required[0]}"
        if not re.search(mapping, MODELS):
            failures.append(f"{item_id} is not mapped to its own builder")
        for semantic_part in required[1:]:
            if semantic_part not in MODELS:
                failures.append(f"{item_id} is missing 3D detail {semantic_part}")

    for contract in (
        'CafeModels.Tag = "MoonleafCafeFood3D"',
        'model:SetAttribute("CafeFood3D", true)',
        'model:SetAttribute("GeometryKind", geometryKind)',
        "model.PrimaryPart = primary",
        "Enum.PartType.Cylinder",
        "Enum.PartType.Ball",
        "CollectionService:AddTag(model, CafeModels.Tag)",
    ):
        if contract not in MODELS:
            failures.append(f"CafeModels is missing contract: {contract}")

    if "CafeFood3DDisplay" not in WORLD:
        failures.append("Cafe has no physical 3D food display folder")
    if "CafeModels.build(foodDisplay, itemId" not in WORLD:
        failures.append("Cafe display does not build each menu item in 3D")
    if "CafeModels.build(guest, CafeMenu.resolve(cafeItemId)" not in WORLD:
        failures.append("Served food does not appear as a 3D model beside the guest")

    if 'Instance.new("ViewportFrame")' not in CLIENT:
        failures.append("Cafe menu still lacks 3D ViewportFrame previews")
    if "CafeModels.build(previewWorld, itemId" not in CLIENT:
        failures.append("Cafe menu preview does not build the selected 3D item")
    if 'invoke("CafeServe", { item = itemId })' not in CLIENT:
        failures.append("Cafe menu item no longer serves its exact item id")

    for flat_artifact in ("CafeItemCard", "CafeMenuIcon", 'Instance.new("ImageLabel")'):
        if flat_artifact in WORLD:
            failures.append(f"Flat world food display remains: {flat_artifact}")
    if "CafeIcon" in CLIENT:
        failures.append("Cafe menu still invokes the old flat image renderer")

    for placeholder in ("GoldenCrust", "GlowingMoonBerry", "StarCookie", "MoonberryPastry"):
        if placeholder in WORLD:
            failures.append(f"Old primitive placeholder remains: {placeholder}")

    for server_contract in ("CafeMenu.resolve(payload.item)", "ShowCafeCustomer(player, cafeItemId)", "cafeItem.Name"):
        if server_contract not in GAME:
            failures.append(f"Cafe serving flow is missing {server_contract}")

    if failures:
        print("Cafe 3D coverage failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("Cafe 3D coverage passed: four distinct detailed models appear in the case, menu previews, and serving flow.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
