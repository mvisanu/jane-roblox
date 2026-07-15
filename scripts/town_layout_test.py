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
    "HomeNameSignBoard": 1,
    "HomeNameSignPost": 1,
    "HomeNameSignFoot": 1,
    "HomeNameSignTrim": 4,
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


def local_z(origin: dict, row: dict) -> float:
    """Project a world-space offset onto the house floor's local Z axis."""
    offset = (row["px"] - origin["px"], row["py"] - origin["py"], row["pz"] - origin["pz"])
    return offset[0] * origin["zx"] + offset[1] * origin["zy"] + offset[2] * origin["zz"]


def contrast_ratio(first: tuple[int, int, int], second: tuple[int, int, int]) -> float:
    """WCAG contrast ratio for proving the physical sign is readable."""
    def luminance(rgb: tuple[int, int, int]) -> float:
        channels = []
        for channel in rgb:
            value = channel / 255
            channels.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

    one, two = luminance(first), luminance(second)
    return (max(one, two) + 0.05) / (min(one, two) + 0.05)


def main() -> int:
    parts, _, signs, home_blips = load_world(False, include_home_signs=True)
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
        name_board = next((row for row in rows if row["name"] == "HomeNameSignBoard"), None)
        name_post = next((row for row in rows if row["name"] == "HomeNameSignPost"), None)
        if not floor or (round(floor["sx"]), round(floor["sz"])) != (30, 22):
            failures.append(f"{home}: shell is not the new broad 30x22 silhouette")
        if floor and door and abs(local_x(floor, door) - 4) > 0.1:
            failures.append(f"{home}: door is not offset right like reference A")
        if floor and chimney and local_x(floor, chimney) > -9:
            failures.append(f"{home}: chimney is not on the left side like reference A")
        if floor and ridge and ridge["py"] - floor["py"] < 27:
            failures.append(f"{home}: roof ridge is too low for the steep reference-A gable")
        if floor and name_board:
            board_x = local_x(floor, name_board)
            board_z = local_z(floor, name_board)
            if abs(board_x - 18) > 0.1 or abs(board_z + 19.5) > 0.1:
                failures.append(
                    f"{home}: name sign is not at the front-right plot corner "
                    f"(local x={board_x:.1f}, z={board_z:.1f})"
                )
            if (name_board["r"], name_board["g"], name_board["b"]) != (89, 58, 32):
                failures.append(f"{home}: name sign board is not approved TimberWarm wood")
            expected_half_size = (6.5, 2.4, 0.45)
            actual_size = (name_board["sx"], name_board["sy"], name_board["sz"])
            if any(abs(actual - expected) > 0.01 for actual, expected in zip(actual_size, expected_half_size)):
                failures.append(
                    f"{home}: name sign board {actual_size} is not exactly 50% of the original 13x4.8x0.9 board"
                )
        if floor and name_board and name_post:
            if abs(local_x(floor, name_board) - local_x(floor, name_post)) > 0.1 or abs(
                local_z(floor, name_board) - local_z(floor, name_post)
            ) > 0.1:
                failures.append(f"{home}: name sign post is not centred under its board")
            board_bottom = name_board["py"] - name_board["sy"] / 2
            post_top = name_post["py"] + name_post["sy"] / 2
            if name_post["sy"] >= 7:
                failures.append(f"{home}: name sign post was not shortened")
            if post_top > board_bottom + 0.01:
                failures.append(
                    f"{home}: shortened post still overlaps/obscures the board "
                    f"(post top={post_top:.2f}, board bottom={board_bottom:.2f})"
                )
        for sign_piece in (row for row in rows if row["name"].startswith("HomeNameSign")):
            if sign_piece["canCollide"]:
                failures.append(f"{home}: {sign_piece['name']} blocks the lawn or path")

    if len(signs) != 8:
        failures.append(f"expected 8 rendered cottage name signs, found {len(signs)}")
    else:
        owner_texts = Counter(sign["ownerText"] for sign in signs)
        if owner_texts != Counter({"TestPlayer": 1, "AVAILABLE": 7}):
            failures.append(f"owner sign text does not follow live home assignment: {dict(owner_texts)}")
        for sign in signs:
            if sign["corner"] != "FrontRight":
                failures.append(f"{sign['path']}: sign is not marked for the front-right corner")
            if sign["ownerFont"] != "GothamBold" or sign["subtitleFont"] != "GothamMedium":
                failures.append(
                    f"{sign['path']}: lettering does not use the approved readable Gotham fonts"
                )
            if (sign["textR"], sign["textG"], sign["textB"]) != (224, 200, 165):
                failures.append(f"{sign['path']}: owner lettering is not high-contrast CanvasLight")
            elif contrast_ratio((224, 200, 165), (89, 58, 32)) < 4.5:
                failures.append(f"{sign['path']}: owner lettering does not meet WCAG AA contrast")
            if (sign["strokeR"], sign["strokeG"], sign["strokeB"]) != (29, 17, 8):
                failures.append(f"{sign['path']}: owner lettering lacks the dark readability stroke")
            if sign["pixelsPerStud"] < 50 or sign["lightInfluence"] != 0:
                failures.append(f"{sign['path']}: SurfaceGui resolution/lighting reduces readability")
            if "HOME" not in sign["subtitleText"] or "บ้าน" not in sign["subtitleText"]:
                failures.append(f"{sign['path']}: bilingual HOME subtitle is missing")

    if len(home_blips) != 8:
        failures.append(f"expected 8 home minimap entries, found {len(home_blips)}")
    else:
        map_names = Counter(blip["Name"] for blip in home_blips)
        if map_names != Counter({"TestPlayer": 1, "Available Home": 7}):
            failures.append(f"home minimap labels still use plot numbers instead of owner names: {dict(map_names)}")

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
        "all 8 cottages use approved Porch Gable design A, and every front-right owner sign is "
        "exactly 50% size with a shortened post that stops below the board."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
