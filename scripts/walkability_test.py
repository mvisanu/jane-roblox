"""Proves a player can walk into and out of every home and building.

Roblox Studio is not available in a shell, so this test loads the real
WorldService source into a Lua interpreter with a mocked Roblox API
(scripts/robloxmock.lua), generates the whole town exactly as the server would,
and then runs a voxel flood fill with a Roblox-sized character over the
resulting collision geometry.

A structure passes only when a character standing on open ground outside can
reach the marker inside it by walking - no jumping, no clipping through parts.

Usage:
    python scripts/walkability_test.py [--verbose]
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:  # pragma: no cover - dependency hint
    print("This test needs the Lua bridge. Install it with: python -m pip install lupa")
    raise SystemExit(2)


ROOT = Path(__file__).resolve().parents[1]

# Dependency order: Placement requires Config and Furniture at load time, so they
# have to be registered with the mock's require() before it is loaded.
SHARED_MODULES = ("WildwoodStyle", "Config", "Catalog", "AvatarModels", "BagInventory", "QuestBoardLayout", "Util", "RemoteNames", "Progression", "Furniture", "Placement", "CampPlan", "CafeMenu", "CafeModels")

# Roblox R15 character envelope and walking limits.
CHARACTER_HEIGHT = 5.0
CHARACTER_RADIUS = 1.0
MAX_STEP_UP = 2.0
CLEARANCE_EPSILON = 0.15
GRID = 1.0
MARGIN = 22.0

# Every structure a player is expected to be able to enter. Camp buildings only
# exist once the shared campsite has been upgraded, so the harness upgrades one.
EXPECTED_STRUCTURES = {
    "FamilyCafe",
    "PetShop",
    "FlowerShop",
    "LittleSchool",
    "MysteryCave",
    "TreeHouse",
    "CampCottage",
    "AdventureCenter",
    *(f"Home{index:02d}" for index in range(1, 9)),
}

# Places a player must be able to climb on foot, marked with a SummitMarker.
EXPECTED_CLIMBS = {"SunriseMountain"}


@dataclass
class Solid:
    """A collidable part reduced to what a vertical ray needs to know."""

    name: str
    path: str
    center: tuple[float, float, float]
    half: tuple[float, float, float]
    # Rotation columns (local -> world).
    x_axis: tuple[float, float, float]
    y_axis: tuple[float, float, float]
    z_axis: tuple[float, float, float]
    is_ball: bool
    min_x: float
    max_x: float
    min_z: float
    max_z: float
    min_y: float
    max_y: float


def build_solid(row) -> Solid:
    center = (row["px"], row["py"], row["pz"])
    half = (row["sx"] / 2.0, row["sy"] / 2.0, row["sz"] / 2.0)
    x_axis = (row["xx"], row["xy"], row["xz"])
    y_axis = (row["yx"], row["yy"], row["yz"])
    z_axis = (row["zx"], row["zy"], row["zz"])
    is_ball = row["shape"] == "Ball"

    if is_ball:
        radius = min(half)
        extent = (radius, radius, radius)
    else:
        # World-space AABB of the oriented box.
        extent = tuple(
            abs(x_axis[axis]) * half[0] + abs(y_axis[axis]) * half[1] + abs(z_axis[axis]) * half[2]
            for axis in range(3)
        )

    return Solid(
        name=row["name"],
        path=row["path"],
        center=center,
        half=half,
        x_axis=x_axis,
        y_axis=y_axis,
        z_axis=z_axis,
        is_ball=is_ball,
        min_x=center[0] - extent[0],
        max_x=center[0] + extent[0],
        min_z=center[2] - extent[2],
        max_z=center[2] + extent[2],
        min_y=center[1] - extent[1],
        max_y=center[1] + extent[1],
    )


def column_span(solid: Solid, x: float, z: float) -> tuple[float, float] | None:
    """Y range where the vertical line through (x, z) is inside this part."""
    if x < solid.min_x or x > solid.max_x or z < solid.min_z or z > solid.max_z:
        return None

    cx, cy, cz = solid.center
    if solid.is_ball:
        radius = min(solid.half)
        dx = x - cx
        dz = z - cz
        planar = dx * dx + dz * dz
        if planar >= radius * radius:
            return None
        reach = math.sqrt(radius * radius - planar)
        return (cy - reach, cy + reach)

    # Slab test against the oriented box. The ray is (x, 0, z) + t * (0, 1, 0),
    # so t is world Y directly.
    origin = (x - cx, -cy, z - cz)
    axes = (solid.x_axis, solid.y_axis, solid.z_axis)
    t_min = -1.0e9
    t_max = 1.0e9
    for index, axis in enumerate(axes):
        # Project both ray origin and ray direction onto this box axis.
        start = origin[0] * axis[0] + origin[1] * axis[1] + origin[2] * axis[2]
        direction = axis[1]  # dot((0, 1, 0), axis)
        limit = solid.half[index]
        if abs(direction) < 1.0e-9:
            if start < -limit or start > limit:
                return None
            continue
        low = (-limit - start) / direction
        high = (limit - start) / direction
        if low > high:
            low, high = high, low
        t_min = max(t_min, low)
        t_max = min(t_max, high)
        if t_min > t_max:
            return None
    return (t_min, t_max)


def to_cell(x: float, z: float) -> tuple[int, int]:
    return (int(math.floor(x / GRID)), int(math.floor(z / GRID)))


class Terrain:
    """Collision columns for one region of the world."""

    def __init__(self, solids: list[Solid], bounds: tuple[float, float, float, float]) -> None:
        self.min_x, self.max_x, self.min_z, self.max_z = bounds
        self.low_cell = to_cell(self.min_x, self.min_z)
        self.high_cell = to_cell(self.max_x, self.max_z)
        self.solids = solids
        self.buckets: dict[tuple[int, int], list[Solid]] = {}
        for solid in solids:
            for bucket_x in range(int(solid.min_x // 8), int(solid.max_x // 8) + 1):
                for bucket_z in range(int(solid.min_z // 8), int(solid.max_z // 8) + 1):
                    self.buckets.setdefault((bucket_x, bucket_z), []).append(solid)
        self._spans: dict[tuple[int, int], list[tuple[float, float]]] = {}

    def spans(self, cell: tuple[int, int]) -> list[tuple[float, float]]:
        """Merged solid Y intervals for the column at this grid cell."""
        cached = self._spans.get(cell)
        if cached is not None:
            return cached

        x = (cell[0] + 0.5) * GRID
        z = (cell[1] + 0.5) * GRID
        found: list[tuple[float, float]] = []
        for solid in self.buckets.get((int(x // 8), int(z // 8)), ()):
            span = column_span(solid, x, z)
            if span is not None:
                found.append(span)

        found.sort()
        merged: list[tuple[float, float]] = []
        for low, high in found:
            if merged and low <= merged[-1][1] + 1.0e-6:
                merged[-1] = (merged[-1][0], max(merged[-1][1], high))
            else:
                merged.append((low, high))
        self._spans[cell] = merged
        return merged

    def is_clear(self, cell: tuple[int, int], low: float, high: float) -> bool:
        for span_low, span_high in self.spans(cell):
            if span_high > low and span_low < high:
                return False
        return True

    def stand_heights(self, cell: tuple[int, int]) -> list[float]:
        """Surfaces in this column with room for a character to stand on them."""
        heights = []
        for _, top in self.spans(cell):
            if self.is_clear(cell, top + CLEARANCE_EPSILON, top + CHARACTER_HEIGHT):
                heights.append(top)
        return heights

    def fits(self, cell: tuple[int, int], height: float) -> bool:
        """True when the character's body, not just a point, fits at this cell.

        Anything low enough to step onto (a stair tread, a kerb, a shop counter)
        does not count as blocking, because a humanoid walks up over it. Only
        geometry that rises more than a step above the feet is a real obstacle.
        """
        low = height + CLEARANCE_EPSILON
        high = height + CHARACTER_HEIGHT
        steppable = height + MAX_STEP_UP
        reach = int(math.ceil(CHARACTER_RADIUS / GRID))
        for offset_x in range(-reach, reach + 1):
            for offset_z in range(-reach, reach + 1):
                neighbour = (cell[0] + offset_x, cell[1] + offset_z)
                for span_low, span_high in self.spans(neighbour):
                    if span_high > low and span_low < high and span_high > steppable:
                        return False
        return True

    def in_bounds(self, cell: tuple[int, int]) -> bool:
        # Compared in cell indices, not world coordinates: a border cell's centre
        # can sit just outside the region edge, and rejecting it would make the
        # walk asymmetric (seedable, but not steppable into on the way back out).
        return (
            self.low_cell[0] <= cell[0] <= self.high_cell[0]
            and self.low_cell[1] <= cell[1] <= self.high_cell[1]
        )


def walk(terrain: Terrain, starts: list[tuple[tuple[int, int], float]], reached_goal):
    """Flood fill by walking. Returns the first node satisfying reached_goal, or None."""
    queue: deque[tuple[tuple[int, int], float]] = deque()
    seen: set[tuple[int, int, int]] = set()

    def key(cell: tuple[int, int], height: float) -> tuple[int, int, int]:
        return (cell[0], cell[1], int(round(height * 2)))

    for cell, height in starts:
        if terrain.fits(cell, height) and key(cell, height) not in seen:
            seen.add(key(cell, height))
            queue.append((cell, height))

    while queue:
        cell, height = queue.popleft()
        if reached_goal(cell, height):
            return cell, height
        for step_x, step_z in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            neighbour = (cell[0] + step_x, cell[1] + step_z)
            if not terrain.in_bounds(neighbour):
                continue
            for candidate in terrain.stand_heights(neighbour):
                if abs(candidate - height) > MAX_STEP_UP:
                    continue
                node = key(neighbour, candidate)
                if node in seen:
                    continue
                if not terrain.fits(neighbour, candidate):
                    continue
                seen.add(node)
                queue.append((neighbour, candidate))
    return None


def point_inside(solid: Solid, point: tuple[float, float, float]) -> bool:
    """Exact containment against the oriented box (or sphere), not its AABB."""
    offset = (point[0] - solid.center[0], point[1] - solid.center[1], point[2] - solid.center[2])
    if solid.is_ball:
        radius = min(solid.half)
        return offset[0] ** 2 + offset[1] ** 2 + offset[2] ** 2 < radius * radius
    for index, axis in enumerate((solid.x_axis, solid.y_axis, solid.z_axis)):
        local = offset[0] * axis[0] + offset[1] * axis[1] + offset[2] * axis[2]
        if abs(local) > solid.half[index]:
            return False
    return True


def luau_to_lua(source: str) -> str:
    """Rewrites the Luau-only syntax the mock's Lua interpreter cannot parse.

    Only compound assignment (`x += 1`, `x -= 1`, ...) differs in the sources
    here. Everything else the game uses is valid Lua, so the test runs the real
    code rather than a transliteration of it.
    """
    return re.sub(r"(\S+)\s*([+\-*/])=\s*(.+)$", r"\1 = \1 \2 \3", source, flags=re.MULTILINE)


def load_world(verbose: bool):
    """Run the real WorldService against the mocked engine and return its parts."""
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path: Path, name: str):
        source = luau_to_lua(path.read_text(encoding="utf-8"))
        chunk = lua.eval(f"function(source) return load(source, {name!r}) end")(source)
        if isinstance(chunk, tuple):
            raise SystemExit(f"Could not parse {path}: {chunk[1]}")
        return chunk

    mock = load(ROOT / "scripts/robloxmock.lua", "@robloxmock")()
    mock.install(lua.globals())

    shared = ROOT / "src/ReplicatedStorage/Shared"
    modules = {}
    for module in SHARED_MODULES:
        modules[module] = load(shared / f"{module}.lua", f"@{module}")()
        mock.registerModule(module, modules[module])

    waypoints = {
        str(name): (point.X, point.Y, point.Z)
        for name, point in dict(modules["Config"].Waypoints).items()
    }

    world_service = load(ROOT / "src/ServerScriptService/Services/WorldService.lua", "@WorldService")()

    remotes = lua.eval("{ Toast = { FireClient = function() end }, StateChanged = { FireClient = function() end } }")
    world = world_service.new(remotes)

    # Camp buildings only exist after an upgrade, so drive one home to the top
    # stage and render it the same way GameService would.
    player = lua.globals().Instance.new("Player")
    player.Name = "TestPlayer"
    player.DisplayName = "TestPlayer"
    player.UserId = 1
    world.AssignHome(world, player)
    profile = lua.eval("{ Home = { Paint = 'Coffee', Furniture = {} }, Adventure = { CampLevel = 6, ActiveCompanion = 'Cat' } }")
    world.RefreshHome(world, player, profile)
    world.RefreshAdventureCamp(world, player, profile)

    rows = mock.exportParts()
    parts = [dict(rows[index]) for index in range(1, len(rows) + 1)]
    if verbose:
        print(f"Generated {len(parts)} parts")
    return parts, waypoints


def collect_structures(parts: list[dict]) -> dict[str, dict]:
    """Find every structure the world marked as enterable."""
    structures: dict[str, dict] = {}
    for row in parts:
        if row["name"] not in ("DoorwayVolume", "InteriorMarker"):
            continue
        # Path is Workspace.CuteFamilyTown.<folder>...<Model>.<Marker>
        model = row["path"].split(".")[-2]
        entry = structures.setdefault(model, {})
        entry[row["name"]] = row
    return {
        name: entry
        for name, entry in structures.items()
        if "DoorwayVolume" in entry and "InteriorMarker" in entry
    }


def doorway_blockers(door_box: Solid, solids: list[Solid]) -> set[str]:
    """Collidable parts that actually intrude into the doorway opening.

    Sampled against the true oriented boxes: several homes are rotated, and a
    rotated wall's bounding box overlaps a doorway it does not touch.
    """
    nearby = [
        solid
        for solid in solids
        if solid.max_x > door_box.min_x
        and solid.min_x < door_box.max_x
        and solid.max_y > door_box.min_y
        and solid.min_y < door_box.max_y
        and solid.max_z > door_box.min_z
        and solid.min_z < door_box.max_z
    ]
    if not nearby:
        return set()

    blockers: set[str] = set()
    steps = (7, 7, 5)
    for i in range(steps[0]):
        for j in range(steps[1]):
            for k in range(steps[2]):
                local = (
                    (i / (steps[0] - 1) - 0.5) * 2 * door_box.half[0],
                    (j / (steps[1] - 1) - 0.5) * 2 * door_box.half[1],
                    (k / (steps[2] - 1) - 0.5) * 2 * door_box.half[2],
                )
                world = tuple(
                    door_box.center[axis]
                    + local[0] * door_box.x_axis[axis]
                    + local[1] * door_box.y_axis[axis]
                    + local[2] * door_box.z_axis[axis]
                    for axis in range(3)
                )
                for solid in nearby:
                    if point_inside(solid, world):
                        blockers.add(solid.name)
    return blockers


def check_structure(name: str, entry: dict, solids: list[Solid], verbose: bool) -> str | None:
    doorway = entry["DoorwayVolume"]
    interior = entry["InteriorMarker"]
    door_box = build_solid(doorway)

    # 1. The doorway must be a hole: nothing collidable standing in the opening.
    blockers = doorway_blockers(door_box, solids)
    if blockers:
        return f"{name}: doorway is blocked by {', '.join(sorted(blockers))}"

    # 2. A character on open ground outside must be able to walk to the inside.
    goal_x, goal_y, goal_z = interior["px"], interior["py"], interior["pz"]
    goal_cell = to_cell(goal_x, goal_z)
    goal_floor = goal_y - interior["sy"] / 2

    model_path = interior["path"].rsplit(".", 1)[0]
    min_x = min(goal_x, door_box.center[0]) - MARGIN
    max_x = max(goal_x, door_box.center[0]) + MARGIN
    min_z = min(goal_z, door_box.center[2]) - MARGIN
    max_z = max(goal_z, door_box.center[2]) + MARGIN
    for solid in solids:
        if solid.path.startswith(model_path):
            min_x = min(min_x, solid.min_x - MARGIN)
            max_x = max(max_x, solid.max_x + MARGIN)
            min_z = min(min_z, solid.min_z - MARGIN)
            max_z = max(max_z, solid.max_z + MARGIN)

    region = [
        solid
        for solid in solids
        if solid.max_x > min_x - 8
        and solid.min_x < max_x + 8
        and solid.max_z > min_z - 8
        and solid.min_z < max_z + 8
    ]
    terrain = Terrain(region, (min_x, max_x, min_z, max_z))

    low_cell = to_cell(min_x, min_z)
    high_cell = to_cell(max_x, max_z)

    def border_cells():
        for cell_x in range(low_cell[0], high_cell[0] + 1):
            yield (cell_x, low_cell[1])
            yield (cell_x, high_cell[1])
        for cell_z in range(low_cell[1] + 1, high_cell[1]):
            yield (low_cell[0], cell_z)
            yield (high_cell[0], cell_z)

    border = set(border_cells())
    # The region edge is open ground well outside the structure.
    starts = [(cell, height) for cell in border for height in terrain.stand_heights(cell)]
    if not starts:
        return f"{name}: no open ground outside the structure to start from"

    goal_heights = terrain.stand_heights(goal_cell)
    if not goal_heights:
        return f"{name}: there is nowhere to stand inside (interior is solid or has no headroom)"
    goal_height = min(goal_heights, key=lambda height: abs(height - goal_floor))
    if abs(goal_height - goal_floor) > MAX_STEP_UP:
        return f"{name}: the interior floor is buried under geometry"

    inbound = walk(terrain, starts, lambda cell, height: cell == goal_cell and abs(height - goal_height) < 0.01)
    if inbound is None:
        return f"{name}: cannot walk in from outside - the interior is sealed off"

    # 3. And back out again, from the inside to open ground.
    outbound = walk(terrain, [inbound], lambda cell, _height: cell in border)
    if outbound is None:
        return f"{name}: can get in but not back out"

    if verbose:
        print(f"  {name}: walked in (floor y={inbound[1]:.1f}) and back out to open ground")
    return None


def collect_climbs(parts: list[dict]) -> dict[str, dict]:
    """Find every model that claims a summit a player is meant to reach on foot."""
    return {
        row["path"].split(".")[-2]: row
        for row in parts
        if row["name"] == "SummitMarker"
    }


def check_climb(name: str, marker: dict, solids: list[Solid], verbose: bool) -> str | None:
    """A character on open ground must be able to walk all the way to the summit."""
    model_path = marker["path"].rsplit(".", 1)[0]
    own = [solid for solid in solids if solid.path.startswith(model_path)]
    if not own:
        return f"{name}: has a summit marker but no geometry"

    min_x = min(solid.min_x for solid in own) - MARGIN
    max_x = max(solid.max_x for solid in own) + MARGIN
    min_z = min(solid.min_z for solid in own) - MARGIN
    max_z = max(solid.max_z for solid in own) + MARGIN

    region = [
        solid
        for solid in solids
        if solid.max_x > min_x - 8
        and solid.min_x < max_x + 8
        and solid.max_z > min_z - 8
        and solid.min_z < max_z + 8
    ]
    terrain = Terrain(region, (min_x, max_x, min_z, max_z))
    low_cell, high_cell = terrain.low_cell, terrain.high_cell

    starts: list[tuple[tuple[int, int], float]] = []
    for cell_x in range(low_cell[0], high_cell[0] + 1):
        for cell in ((cell_x, low_cell[1]), (cell_x, high_cell[1])):
            starts.extend((cell, height) for height in terrain.stand_heights(cell))
    for cell_z in range(low_cell[1] + 1, high_cell[1]):
        for cell in ((low_cell[0], cell_z), (high_cell[0], cell_z)):
            starts.extend((cell, height) for height in terrain.stand_heights(cell))
    if not starts:
        return f"{name}: no open ground around it to start the climb from"

    summit_cell = to_cell(marker["px"], marker["pz"])
    summit_floor = marker["py"] - marker["sy"] / 2
    heights = terrain.stand_heights(summit_cell)
    if not heights:
        return f"{name}: there is nowhere to stand on the summit"
    summit_height = min(heights, key=lambda height: abs(height - summit_floor))
    if abs(summit_height - summit_floor) > MAX_STEP_UP:
        return f"{name}: the summit marker is buried in geometry"

    reached = walk(terrain, starts, lambda cell, height: cell == summit_cell and abs(height - summit_height) < 0.01)
    if reached is None:
        return f"{name}: cannot be climbed on foot - the summit is only reachable by teleporting"

    if verbose:
        print(f"  {name}: climbed from open ground to the summit at y={reached[1]:.1f}")
    return None


def check_waypoints(waypoints: dict[str, tuple[float, float, float]], solids: list[Solid], verbose: bool) -> list[str]:
    """Map travel drops the character at waypoint + 3 studs. It must land on floor.

    Several shops are hollow now, so travelling to one puts the player inside it.
    That only works if the drop point is open air above a real surface.
    """
    failures = []
    for name, (x, y, z) in sorted(waypoints.items()):
        drop = y + 3.0
        cell = to_cell(x, z)
        nearby = [
            solid
            for solid in solids
            if solid.max_x > x - 4 and solid.min_x < x + 4 and solid.max_z > z - 4 and solid.min_z < z + 4
        ]
        terrain = Terrain(nearby, (x - 4, x + 4, z - 4, z + 4))

        if not terrain.is_clear(cell, drop, drop + CHARACTER_HEIGHT):
            failures.append(f"waypoint {name}: the character materialises inside solid geometry")
            continue
        landings = [height for height in terrain.stand_heights(cell) if height <= drop + 0.01]
        if not landings:
            failures.append(f"waypoint {name}: nothing to land on below the drop point")
            continue
        if verbose:
            print(f"  waypoint {name}: drops from y={drop:.1f} onto floor y={max(landings):.1f}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    parts, WAYPOINTS = load_world(args.verbose)
    solids = [build_solid(row) for row in parts if row["canCollide"] == 1]
    markers = [row for row in parts if row["name"] in ("DoorwayVolume", "InteriorMarker")]
    if args.verbose:
        print(f"{len(solids)} collidable parts, {len(markers)} entrance markers")

    structures = collect_structures(parts)
    failures: list[str] = []

    missing = sorted(EXPECTED_STRUCTURES - set(structures))
    for name in missing:
        failures.append(f"{name}: no doorway - the structure cannot be entered at all")

    for name in sorted(structures):
        problem = check_structure(name, structures[name], solids, args.verbose)
        if problem:
            failures.append(problem)

    climbs = collect_climbs(parts)
    for name in sorted(EXPECTED_CLIMBS - set(climbs)):
        failures.append(f"{name}: has no summit marker, so nothing proves it can be climbed")
    for name in sorted(climbs):
        problem = check_climb(name, climbs[name], solids, args.verbose)
        if problem:
            failures.append(problem)

    failures.extend(check_waypoints(WAYPOINTS, solids, args.verbose))

    if failures:
        print("Walkability failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        f"Walkability passed: a character can walk in and out of all {len(structures)} structures "
        f"and climb {len(climbs)} summit(s)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
