"""Regression checks for the approved organic town plan and house design A."""

from __future__ import annotations

from collections import Counter, defaultdict

from walkability_test import load_world


HOME_FEATURES = {
    "Porch": 1,
    "PorchStep": 1,
    "PorchCanopy": 1,
    "PorchPost": 4,
    "WindowGlow": 2,
    "WindowShutter": 4,
    "StoneChimney": 1,
    "ChimneyCap": 1,
    "RoofPlane": 2,
    "RoofCourse": 14,
    "GableCourse": 28,
}

DEFAULT_ACTIVE_COLORS = {
	"BackWall": {(89, 58, 32)},
	"RoofPlane": {(89, 58, 32)},
	"CornerPost": {(42, 31, 20)},
	"WindowGlow": {(217, 162, 90)},
	"WindowShutter": {(52, 56, 27)},
	"StoneChimney": {(75, 67, 58)},
	"Door": {(42, 31, 20)},
}

UNOWNED_TEMPLATE_COLORS = {
	"BackWall": {(89, 58, 32)},
	"RoofPlane": {(130, 78, 48)},
	"CornerPost": {(42, 31, 20)},
	"WindowGlow": {(217, 162, 90)},
	"WindowShutter": {(52, 56, 27)},
	"StoneChimney": {(75, 67, 58)},
	"Door": {(42, 31, 20)},
}

LEGACY_HOME_PARTS = {"BannerCloth", "BalconyDeck", "Footing", "DoorPost", "DoorLintel"}


def local_x(origin: dict, row: dict) -> float:
    """Project a world-space offset onto the house floor's local X axis."""
    offset = (row["px"] - origin["px"], row["py"] - origin["py"], row["pz"] - origin["pz"])
    return offset[0] * origin["xx"] + offset[1] * origin["xy"] + offset[2] * origin["xz"]


def main() -> int:
    parts, _ = load_world(False)
    names = Counter(row["name"] for row in parts)
    failures: list[str] = []

    if names["MainRoadNS"] or names["MainRoadEW"]:
        failures.append("the retired cross-road slabs were generated")
    for path_name, expected in {
        "VillageLoopPath": 12,
        "WestHomeGrove": 5,
        "EastHomeGrove": 5,
        "MarketLane": 2,
        "FamilyLane": 2,
    }.items():
        if names[path_name] != expected:
            failures.append(f"{path_name}: expected {expected} segments, found {names[path_name]}")

    home_parts: dict[str, Counter[str]] = defaultdict(Counter)
    home_rows: dict[str, list[dict]] = defaultdict(list)
    home_floors: list[dict] = []
    for row in parts:
        path = row["path"].split(".")
        home = next((entry for entry in path if entry.startswith("Home") and len(entry) == 6), None)
        # Direct children are the approved cottage itself. Home01 also contains
        # a player's upgradable adventure camp, which must not be mistaken for
        # house geometry or allow legacy camp parts to satisfy these checks.
        if home and len(path) == 5 and path[3] == home:
            home_parts[home][row["name"]] += 1
            home_rows[home].append(row)
            if row["name"] == "Floor":
                home_floors.append(row)

    if len(home_parts) != 8:
        failures.append(f"expected 8 family cottages, found {len(home_parts)}")
    for home, features in sorted(home_parts.items()):
        for feature, expected in HOME_FEATURES.items():
            if features[feature] < expected:
                failures.append(f"{home}: expected at least {expected} {feature}, found {features[feature]}")

        rows = home_rows[home]
        colors: dict[str, set[tuple[int, int, int]]] = defaultdict(set)
        for row in rows:
            colors[row["name"]].add((row["r"], row["g"], row["b"]))
        # load_world assigns Home01 to the test player and refreshes its saved
        # Coffee paint. The other seven plots are intentionally unowned, so they
        # retain the detailed reference palette until a player claims them.
        expected_colors = DEFAULT_ACTIVE_COLORS if home == "Home01" else UNOWNED_TEMPLATE_COLORS
        for part_name, expected in expected_colors.items():
            if colors[part_name] != expected:
                failures.append(
                    f"{home}: {part_name} colours {sorted(colors[part_name])} do not match expected state {sorted(expected)}"
                )
        legacy = sorted(LEGACY_HOME_PARTS & set(features))
        if legacy:
            failures.append(f"{home}: still contains legacy village dressing: {', '.join(legacy)}")

        floor = next((row for row in rows if row["name"] == "Floor"), None)
        door = next((row for row in rows if row["name"] == "Door"), None)
        chimney = next((row for row in rows if row["name"] == "StoneChimney"), None)
        ridge = next((row for row in rows if row["name"] == "RoofRidge"), None)
        if not floor or (round(floor["sx"]), round(floor["sz"])) != (30, 22):
            failures.append(f"{home}: shell is not the new broad 30x22 silhouette")
        if floor and door and abs(local_x(floor, door) - 4) > 0.1:
            failures.append(f"{home}: door is not offset right like reference A")
        if floor and chimney and local_x(floor, chimney) > -9:
            failures.append(f"{home}: chimney is not on the left side like reference A")
        if floor and ridge and ridge["py"] - floor["py"] < 27:
            failures.append(f"{home}: roof ridge is too low for the steep reference-A gable")

    west = sum(1 for floor in home_floors if floor["px"] < -140)
    east = sum(1 for floor in home_floors if floor["px"] > 140)
    if (west, east) != (4, 4):
        failures.append(f"Home Groves are not balanced 4/4 (west={west}, east={east})")

    if failures:
        print("Town layout failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Town layout passed: organic loop and district lanes generated, cross roads removed, "
        "and all 8 cottages use approved Porch Gable design A in balanced Home Groves."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
