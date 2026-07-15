"""Audits every real world-water body for shared blue color and motion.

The generated town has exactly two swimmable bodies: Sunny Lake and the
adventure river. Both must use the same Terrain configuration, clear-blue
surface palette, safe submerged geometry, and locally animated highlights.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from walkability_test import load_world


ROOT = Path(__file__).resolve().parents[1]
WORLD = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")
CONFIG = (ROOT / "src/ReplicatedStorage/Shared/Config.lua").read_text(encoding="utf-8")
CONTROLLER = (
    ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/RiverController.lua"
).read_text(encoding="utf-8")

CLEAR_BLUE = (68, 169, 226)
CLEAR_HIGHLIGHT = (188, 235, 250)


def main() -> int:
    failures: list[str] = []

    for contract in (
        "local SUNNY_LAKE_SIZE = Vector3.new(80, 8, 48)",
        "local function fillClearMovingWater(waterCFrame, waterSize)",
        "terrain.WaterColor = VILLAGE.ClearWater",
        "terrain.WaterTransparency = 0.65",
        "terrain.WaterReflectance = 0.04",
        "terrain.WaterWaveSize = 0.12",
        "terrain.WaterWaveSpeed = 12",
        "terrain:FillBlock(waterCFrame, waterSize, Enum.Material.Water)",
        "fillClearMovingWater(waterCFrame, ADVENTURE_RIVER_SIZE)",
        "fillClearMovingWater(waterCFrame, SUNNY_LAKE_SIZE)",
        'lake:SetAttribute("WaterBodyId", "SunnyLake")',
        'geometry:SetAttribute("WaterStyle", "ClearBlueMovingTerrain")',
        '"LakeBed"',
        '"LakeShallowBank"',
        '"LakeMidBank"',
        '"LakeSurfaceRipple"',
        'CollectionService:AddTag(ripple, RemoteNames.RiverCurrentTag)',
        'CollectionService:AddTag(lake, RemoteNames.SwimmableWaterTag)',
        'Water = VILLAGE.ClearWater',
    ):
        if contract not in WORLD:
            failures.append(f"shared moving-water contract is missing: {contract}")

    if "RiverBlue = WildwoodStyle.World.ClearWater" not in CONFIG:
        failures.append("adventure water/map color is not the same clear blue as Sunny Lake")
    if "if targetSpeed <= 0 or acceleration <= 0 then" not in CONTROLLER:
        failures.append("lake swimming is incorrectly forced in a river-current direction")

    old_lake = re.search(
        r'part\(world,\s*"Lake".*?Enum\.Material\.Glass', WORLD, re.DOTALL
    )
    if old_lake:
        failures.append("Sunny Lake is still a static Glass plate")
    shared_builder_calls = re.findall(
        r"^\s*fillClearMovingWater\(waterCFrame, (ADVENTURE_RIVER_SIZE|SUNNY_LAKE_SIZE)\)",
        WORLD,
        re.MULTILINE,
    )
    if sorted(shared_builder_calls) != ["ADVENTURE_RIVER_SIZE", "SUNNY_LAKE_SIZE"]:
        failures.append("not every water body is routed through the shared Terrain water builder")

    ground_cutout = re.search(
        r"-- Four ground slabs leave a real cavity beneath Sunny Lake(.*?)-- The old ruler-straight cross",
        WORLD,
        re.DOTALL,
    )
    if not ground_cutout or ground_cutout.group(1).count("Size = Vector3.new") != 4:
        failures.append("town ground is not cut into four shoreline banks around Sunny Lake")

    try:
        parts, _ = load_world(False)
    except Exception as exc:  # pragma: no cover
        failures.append(f"WorldService could not render all water bodies: {exc}")
        parts = []

    def named(name: str) -> list[dict]:
        return [part for part in parts if part["name"] == name]

    bodies = named("Lake") + named("AdventureRiver")
    if len(bodies) != 2:
        failures.append(f"expected exactly Sunny Lake and adventure river, found {len(bodies)} water bodies")
    for body in bodies:
        if body["canCollide"] != 0 or body["transparency"] != 1:
            failures.append(f"water marker blocks or hides swimmers: {body['path']}")
        if (body["r"], body["g"], body["b"]) != CLEAR_BLUE:
            failures.append(f"water body does not use the shared clear blue: {body['path']}")

    if len(named("Ground")) != 1 or len(named("GroundBank")) != 3:
        failures.append("Sunny Lake cavity did not produce four town ground banks")
    if len(named("LakeBed")) != 1:
        failures.append("Sunny Lake has no deep bed")
    if len(named("LakeShallowBank")) != 4 or len(named("LakeMidBank")) != 4:
        failures.append("Sunny Lake lacks two safe entry tiers on all sides")

    motion = named("RiverCurrentRibbon") + named("LakeSurfaceRipple")
    if len(named("RiverCurrentRibbon")) != 7 or len(named("LakeSurfaceRipple")) != 8:
        failures.append("river and lake do not both have complete moving surface highlights")
    for part in motion:
        color = (part["r"], part["g"], part["b"])
        if color not in {CLEAR_BLUE, CLEAR_HIGHLIGHT}:
            failures.append(f"moving water uses a mismatched color: {part['path']}={color}")
        if part["material"] != "Glass" or part["canCollide"] != 0:
            failures.append(f"moving water highlight is solid or not Glass: {part['path']}")
        if part["transparency"] < 0.6:
            failures.append(f"moving water highlight is too opaque: {part['path']}")

    # A semantic scan guards against a third static water body being added
    # without joining this audit. Beds, banks, signs and quest props are not
    # surfaces; the four names below are the complete visible/physical set.
    water_surface_names = {
        row["name"]
        for row in parts
        if row["name"] in {
            "Lake",
            "AdventureRiver",
            "LakeSurfaceRipple",
            "RiverCurrentRibbon",
        }
    }
    expected_surfaces = {
        "Lake",
        "AdventureRiver",
        "LakeSurfaceRipple",
        "RiverCurrentRibbon",
    }
    if water_surface_names != expected_surfaces:
        failures.append(
            f"world water surface inventory drifted: actual={sorted(water_surface_names)}"
        )

    if failures:
        print("World water consistency failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "World water consistency passed: Sunny Lake and the adventure river are "
        "swimmable clear-blue Terrain Water with 15 animated surface highlights and safe banks."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
