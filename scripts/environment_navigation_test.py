"""Verifies local-time lighting, house lamps, and complete quest routing."""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    print("This test needs the Lua bridge. Install it with: python -m pip install lupa")
    raise SystemExit(2)

from walkability_test import load_world, luau_to_lua  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]


def load_modules():
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path: Path, name: str):
        source = luau_to_lua(path.read_text(encoding="utf-8"))
        chunk = lua.eval(f"function(source) return load(source, {name!r}) end")(source)
        if isinstance(chunk, tuple):
            raise SystemExit(f"Could not parse {path}: {chunk[1]}")
        return chunk()

    mock = load(ROOT / "scripts/robloxmock.lua", "@robloxmock")
    mock.install(lua.globals())
    shared = ROOT / "src/ReplicatedStorage/Shared"
    style = load(shared / "WildwoodStyle.lua", "@WildwoodStyle")
    mock.registerModule("WildwoodStyle", style)
    config = load(shared / "Config.lua", "@Config")
    mock.registerModule("Config", config)
    catalog = load(shared / "Catalog.lua", "@Catalog")
    clock = load(shared / "EnvironmentClock.lua", "@EnvironmentClock")
    guide = load(shared / "QuestGuide.lua", "@QuestGuide")
    return config, catalog, clock, guide


def main() -> int:
    config, catalog, clock, guide = load_modules()
    failures: list[str] = []

    expected_light = {0: 0, 5: 0, 6: 0.5, 7: 1, 12: 1, 17: 1, 18: 0.5, 19: 0, 23: 0}
    for hour, expected in expected_light.items():
        actual = float(clock.daylight(hour))
        if abs(actual - expected) > 1e-6:
            failures.append(f"daylight({hour}) was {actual}, expected {expected}")
    if not clock.isDay(12) or clock.isDay(0) or clock.isDay(18):
        failures.append("06:00-18:00 day/night boundary is incorrect")

    quest_actions: set[str] = set()
    for chain in dict(catalog.QuestChains).values():
        for step in dict(chain.Steps).values():
            quest_actions.add(str(step.Action))
    game_source = (ROOT / "src/ServerScriptService/Services/GameService.lua").read_text(encoding="utf-8")
    daily_block = game_source.split("local QUESTS = {", 1)[1].split("}", 1)[0]
    quest_actions.update(re.findall(r'Action\s*=\s*"([A-Za-z]+)"', daily_block))

    dynamic = {"Home", "HomeGarden"}
    waypoints = set(dict(config.Waypoints))
    for action in sorted(quest_actions):
        route = guide.get(action)
        if route is None:
            failures.append(f"quest action {action} has no waypoint route")
            continue
        target = str(route.Target)
        if target not in dynamic and target not in waypoints:
            failures.append(f"quest action {action} points to unknown target {target}")

    parts, _ = load_world(False)
    home_lamps = [row for row in parts if row["name"] == "LampGlow" and re.search(r"\.Home\d\dLampPost\.", row["path"])]
    expected_home_lamps = int(config.HomeCount) * 2
    if len(home_lamps) != expected_home_lamps:
        failures.append(f"found {len(home_lamps)} house lamp glows, expected {expected_home_lamps}")

    controller = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/EnvironmentController.lua").read_text(encoding="utf-8")
    navigator = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/QuestNavigator.lua").read_text(encoding="utf-8")
    board = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/QuestBoard.lua").read_text(encoding="utf-8")
    client = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
    world = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")

    for required in (
        "DateTime.now():ToLocalTime()",
        "Lighting.ClockTime = hour",
        "EnvironmentClock.daylight(hour)",
        "child.Enabled = night",
        "CollectionService:GetTagged(RemoteNames.LampTag)",
    ):
        if required not in controller:
            failures.append(f"environment controller is missing {required}")
    for required in (
        'markerFolder.Name = "LocalQuestWaypoint"',
        'trailFolder.Name = "GroundPath"',
        'trailPart.Name = string.format("GroundPath%02d", index)',
        'column.Name = "WaypointBeam"',
        "workspace:Raycast",
        "ARRIVAL_DISTANCE = 10",
        "RESUME_DISTANCE = 16",
        "self._navigationLight.Enabled = visible",
        "QuestGuide.get(self._action)",
        "OwnerUserId",
        "GardenSlot",
    ):
        if required not in navigator:
            failures.append(f"quest navigator is missing {required}")
    for removed in ("QuestDirectionArrow", "WorldToViewportPoint", "ArrowVisible"):
        if removed in navigator:
            failures.append(f"old screen-arrow navigation remains: {removed}")
    for required in (
        "trailPart.Transparency = 0.43",
        "self._column.Transparency = visible and 0.62 or 1",
        "distance <= ARRIVAL_DISTANCE",
        "self:_setNavigationVisible(false)",
    ):
        if required not in navigator:
            failures.append(f"ground-path arrival behavior is missing {required}")
    if "SHOW GROUND PATH" not in board or 'self:_navigateButton(card, "Daily")' not in board or 'self:_navigateButton(row, "Chain")' not in board:
        failures.append("quest board does not expose ground-path buttons for both daily and chain quests")
    if "EnvironmentController.new()" not in client or "QuestNavigator.new" not in client or "questNavigator:Update(state)" not in client:
        failures.append("client does not start and update the new controllers")
    if "Lighting.ClockTime = 16.6" in world:
        failures.append("fixed late-afternoon lighting is still active")
    if "CollectionService:AddTag(lightPart, RemoteNames.LampTag)" not in world:
        failures.append("lamp posts are not tagged for automatic night switching")

    if failures:
        print("Environment/navigation failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        f"Environment/navigation passed: local day/night curve, {len(home_lamps)} house lamps, "
        f"and routes for all {len(quest_actions)} quest actions."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
