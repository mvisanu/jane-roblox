"""Verifies that both camps render a wood fire rather than circular placeholders.

The source contract prevents the old ball-and-stone-ring implementation from
returning. The runtime probe then builds the real WorldService with the Roblox
mock and checks that both visible camps receive crossed cylindrical firewood,
irregular embers and layered neon flame geometry.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

from walkability_test import load_world


ROOT = Path(__file__).resolve().parents[1]
WORLD_PATH = ROOT / "src/ServerScriptService/Services/WorldService.lua"


def main() -> int:
    source = WORLD_PATH.read_text(encoding="utf-8")
    failures: list[str] = []

    match = re.search(
        r'local function buildCampfire\(parent, origin, scale\)(.*?)\nend\n\n--\[\[',
        source,
        re.DOTALL,
    )
    if not match:
        failures.append("WorldService has no shared buildCampfire implementation")
        helper = ""
    else:
        helper = match.group(1)

    for legacy in ('"FireRing"', '"CampStone"', '"CampFlame"'):
        if legacy in source:
            failures.append(f"legacy circular campfire geometry remains: {legacy}")

    if helper:
        if "math.cos" in helper or "math.sin" in helper:
            failures.append("campfire pieces are still distributed with circular trigonometry")
        if "Enum.PartType.Ball" in helper:
            failures.append("campfire still uses ball geometry")

        for contract in (
            'model:SetAttribute("CampfireStyle", "CrossedLogsAndLayeredFlames")',
            'model:SetAttribute("CircularLayout", false)',
            '"FirewoodLog"',
            '"FirewoodEndGrain"',
            '"FirewoodHeartwood"',
            '"CharredBarkBand"',
            '"GlowingEmber"',
            'Instance.new("WedgePart")',
            '"OuterFlameTongue"',
            '"InnerFlameTongue"',
            'Instance.new("Fire")',
            'livingFlame.TimeScale = 1.15',
            'Instance.new("Smoke")',
            'Instance.new("PointLight")',
        ):
            if contract not in helper:
                failures.append(f"realistic campfire contract is missing: {contract}")

    call_count = len(re.findall(r"^\s*buildCampfire\(", source, re.MULTILINE))
    if call_count != 2:
        failures.append(f"shared campfire should be placed at both camps, found {call_count} calls")

    try:
        parts, _ = load_world(False)
    except Exception as exc:  # pragma: no cover - turns a harness failure into context
        failures.append(f"WorldService could not render the new campfire: {exc}")
        parts = []

    logs = [part for part in parts if part["name"] == "FirewoodLog"]
    if len(logs) != 6:
        failures.append(f"two fires should contain three full logs each, found {len(logs)}")
    if any(part["shape"] != "Cylinder" or part["material"] != "Wood" for part in logs):
        failures.append("firewood is not cylindrical Wood geometry")

    fire_groups: dict[str, list[dict]] = defaultdict(list)
    for log in logs:
        if ".Campfire." not in log["path"]:
            failures.append(f"firewood is not parented to a Campfire model: {log['path']}")
            continue
        fire_groups[log["path"].rsplit(".Campfire.", 1)[0]].append(log)

    if len(fire_groups) != 2:
        failures.append(f"expected a public and player campfire, found {len(fire_groups)}")
    for path, group in fire_groups.items():
        directions = {(round(log["xx"], 2), round(log["xz"], 2)) for log in group}
        if len(group) != 3 or len(directions) != 3:
            failures.append(f"logs are not visibly crossed at three angles in {path}")

    expected_counts = {
        "FirewoodEndGrain": 12,
        "FirewoodHeartwood": 12,
        "CharredBarkBand": 12,
        "GlowingEmber": 8,
        "OuterFlameTongue": 8,
        "InnerFlameTongue": 4,
    }
    for name, expected in expected_counts.items():
        actual = len([part for part in parts if part["name"] == name])
        if actual != expected:
            failures.append(f"{name} count is {actual}, expected {expected} across both fires")

    flame_parts = [
        part
        for part in parts
        if part["name"] in {"OuterFlameTongue", "InnerFlameTongue"}
    ]
    if flame_parts and any(part["material"] != "Neon" for part in flame_parts):
        failures.append("solid flame tongues are not luminous Neon geometry")
    if flame_parts and len({round(part["sy"], 2) for part in flame_parts}) < 6:
        failures.append("flame silhouette lacks varied tongue heights")

    if failures:
        print("Campfire visual coverage failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Campfire visual coverage passed: both camps use three crossed detailed logs, "
        "irregular embers, six layered flame tongues, animated fire, smoke and warm light."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
