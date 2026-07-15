"""Proves the adventure river is moving, enterable Terrain water.

Offline geometry checks cover the cut channel, safe banks, current ribbons and
bridge access. Source contracts cover the engine-only Terrain swimming state
and the local downstream force that preserves normal player steering.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from walkability_test import load_world


ROOT = Path(__file__).resolve().parents[1]
WORLD = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")
CONTROLLER = (
    ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/RiverController.lua"
).read_text(encoding="utf-8")
CLIENT = (
    ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua"
).read_text(encoding="utf-8")
REMOTE_NAMES = (
    ROOT / "src/ReplicatedStorage/Shared/RemoteNames.lua"
).read_text(encoding="utf-8")
STYLE = (ROOT / "src/ReplicatedStorage/Shared/WildwoodStyle.lua").read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    for contract in (
        "local ADVENTURE_RIVER_SIZE = Vector3.new(104, 8, 96)",
        "fillClearMovingWater(waterCFrame, ADVENTURE_RIVER_SIZE)",
        "terrain.WaterColor = VILLAGE.ClearWater",
        "terrain.WaterTransparency = 0.65",
        "terrain.WaterReflectance = 0.04",
        "terrain.WaterWaveSize = 0.12",
        "terrain.WaterWaveSpeed = 12",
        'swimVolume:SetAttribute("SwimmableTerrainWater", true)',
        "swimVolume.CanCollide = false",
        'CollectionService:AddTag(swimVolume, RemoteNames.SwimmableWaterTag)',
        '"RiverBed"',
        '"RiverShallowBank"',
        '"RiverMidBank"',
        '"RiverCurrentRibbon"',
        'CollectionService:AddTag(ribbon, RemoteNames.RiverCurrentTag)',
        "for plank = -6, 6 do",
        '"BridgeStep"',
    ):
        if contract not in WORLD:
            failures.append(f"swimmable river builder is missing: {contract}")

    if re.search(
        r'part\(river,\s*"AdventureRiver".*Enum\.Material\.Glass',
        WORLD,
        re.DOTALL,
    ):
        failures.append("the old collidable Glass river plate remains")

    ground_block = re.search(
        r"-- Split the former monolithic ground(.*?)part\(adventure, \"AdventureTrail\"",
        WORLD,
        re.DOTALL,
    )
    if not ground_block or ground_block.group(1).count("Size = Vector3.new") != 4:
        failures.append("adventure ground is not split into four banks around the channel")

    for contract in (
        "CollectionService:GetTagged(RemoteNames.RiverCurrentTag)",
        "CollectionService:GetTagged(RemoteNames.SwimmableWaterTag)",
        "RunService.RenderStepped:Connect",
        "cycle % span - span / 2",
        "math.sin(ripple)",
        "humanoid:GetState() ~= Enum.HumanoidStateType.Swimming",
        "insideVolume(volume, root.Position)",
        "local downstreamSpeed = velocity:Dot(direction)",
        "root.AssemblyLinearVelocity = velocity + direction * addition",
        "deltaTime = math.min(math.max(deltaTime or 0, 0), 0.1)",
        "math.clamp(base.Transparency + math.sin(ripple) * 0.07, 0.56, 0.88)",
    ):
        if contract not in CONTROLLER:
            failures.append(f"river movement controller is missing: {contract}")

    if 'local RiverController = require(UI:WaitForChild("RiverController"))' not in CLIENT:
        failures.append("Client does not load the river controller")
    if "local riverController = RiverController.new(player)" not in CLIENT:
        failures.append("Client does not start the river controller")
    for tag in (
        'RiverCurrentTag = "FamilyTownRiverCurrent"',
        'SwimmableWaterTag = "FamilyTownSwimmableWater"',
    ):
        if tag not in REMOTE_NAMES:
            failures.append(f"river CollectionService contract is missing: {tag}")

    for color_contract in (
        "ClearWater = Color3.fromRGB(68, 169, 226)",
        "ClearWaterLight = Color3.fromRGB(188, 235, 250)",
    ):
        if color_contract not in STYLE:
            failures.append(f"clear-blue river palette is missing: {color_contract}")

    try:
        parts, _ = load_world(False)
    except Exception as exc:  # pragma: no cover
        failures.append(f"WorldService could not build the river: {exc}")
        parts = []

    def named(name: str) -> list[dict]:
        return [part for part in parts if part["name"] == name]

    grounds = named("AdventureGround")
    if len(grounds) != 4:
        failures.append(f"river cutout rendered {len(grounds)} ground banks instead of four")

    volumes = named("AdventureRiver")
    if len(volumes) != 1:
        failures.append(f"expected one swimming volume, found {len(volumes)}")
    elif volumes[0]["canCollide"] != 0 or (
        volumes[0]["sx"], volumes[0]["sz"]
    ) != (104, 96):
        failures.append("swimming volume is collidable or has the wrong footprint")

    bed = named("RiverBed")
    if len(bed) != 1 or bed[0]["py"] >= -7:
        failures.append("deep river bed is missing")
    elif (bed[0]["r"], bed[0]["g"], bed[0]["b"]) != (126, 112, 97):
        failures.append("river bed is too dark for a submerged character to remain visible")
    if len(named("RiverShallowBank")) != 4 or len(named("RiverMidBank")) != 4:
        failures.append("two-tier entries do not surround all four sides of the river")

    ribbons = named("RiverCurrentRibbon")
    if len(ribbons) != 7:
        failures.append(f"river has {len(ribbons)} moving streaks instead of seven")
    if any(row["canCollide"] != 0 or row["material"] != "Glass" for row in ribbons):
        failures.append("moving current streaks obstruct swimmers or use the wrong material")
    approved_clear_blues = {(68, 169, 226), (188, 235, 250)}
    if any((row["r"], row["g"], row["b"]) not in approved_clear_blues for row in ribbons):
        failures.append("moving current streaks are not using the clear-blue river palette")
    if any(row["transparency"] < 0.6 for row in ribbons):
        failures.append("moving current streaks are opaque enough to hide swimmers")
    if len({round(row["sx"], 2) for row in ribbons}) < 5 or len(
        {round(row["sz"], 2) for row in ribbons}
    ) < 6:
        failures.append("current streak silhouette is repetitive rather than natural")

    planks = named("BridgePlank")
    steps = named("BridgeStep")
    if len(planks) != 13 or len(steps) != 2:
        failures.append("bridge no longer connects both banks after widening the channel")
    elif min(row["px"] for row in planks) > 137 or max(row["px"] for row in planks) < 233:
        failures.append("bridge planks do not span the swimming channel")

    fishing = named("FishingSpot")
    herbs = named("RiverHerbs")
    if not fishing or fishing[0]["px"] <= 237:
        failures.append("fishing interaction still obstructs the water")
    if not herbs or herbs[0]["px"] >= 133:
        failures.append("river herb interaction still obstructs the water")

    if failures:
        print("River swimming coverage failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "River swimming coverage passed: clear-blue 65%-transparent Terrain Water keeps "
        "swimmers visible, with animated flow, safe banks, a full bridge, and swimming-only current."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
