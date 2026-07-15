"""Proves concept A fully replaced the old cafe outside and inside."""

from __future__ import annotations

import math
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from walkability_test import load_world  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
WORLD = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")

EXTERIOR_COUNTS = {
    "BakeryFacadeWall": 9,
    "BakeryStoneFoundation": 5,
    "RoofPlane": 4,
    "RoofRidge": 2,
    "GableCourse": 40,
    "BakeryDormerRoof": 4,
    "BakeryDormerWindow": 2,
    "BakeryCupolaRoof": 2,
    "BakeryOpenServiceBay": 1,
	"BakeryOpenSideBay": 1,
    "BakeryStreetCounter": 1,
	"BakerySideCounter": 1,
	"BakerySideAwning": 1,
    "BakeryDisplayWindow": 1,
    "BakeryDisplayMullion": 4,
	"BakeryDisplayWingFoundation": 1,
	"BakeryDisplaySideGlass": 2,
    "BakeryWindowShelf": 2,
    "BakeryDoorArch": 5,
    "BakeryCanvasAwning": 6,
    "BakeryDisplayCanopy": 1,
    "BakeryBaySign": 1,
	"BakeryMoonBreadSign": 1,
	"BakeryCrescentOuter": 1,
	"BakeryCrescentCutout": 1,
	"BakeryBreadLoaf": 1,
	"BakeryCoffeeCup": 1,
	"BakeryCoffeeCupBody": 2,
	"BakeryCoffeeCupHandle": 3,
	"BakeryCoffeeSteam": 6,
	"BakerySidewalkSignLeg": 4,
	"BakerySidewalkSignFoot": 4,
	"HandCoffeeGrinderBody": 1,
	"HandCoffeeGrinderHopper": 1,
	"HandCoffeeGrinderCrank": 1,
	"BakeryOakBarrelPlanter": 2,
	"BakeryBarrelHoop": 4,
	"BakeryBarrelFlower": 12,
}

INTERIOR_COUNTS = {
    "BakeryInteriorFloor": 1,
    "BakeryCeilingBeam": 4,
    "BakeryCeilingSlat": 5,
    "BakeryPendantGlow": 5,
    "ServiceCounter": 1,
    "BakeryCounterFront": 5,
    "PastryDisplayGlass": 1,
    "BakeryInteriorMenu": 1,
    "BakeryBackShelf": 3,
    "BakeryIngredientJar": 15,
    "BakeryDiningTable": 3,
    "BakeryChairSeat": 6,
    "BakeryWallBench": 2,
}

LEGACY_PARTS = {
    "BalconyDeck",
    "BalconyRail",
    "BalconyBaluster",
    "BannerCloth",
    "CounterPanel",
    "MoonKettle",
    "TeaWisp",
    "FireflyOrb",
    "EnchantedMenu",
    "CafeTable",
    "CafeChairSeat",
    "BakeryBayCladding",
    "TakeawayServiceHatch",
    "TakeawayPickupCounter",
}

LEGACY_CAFE_SOURCE = LEGACY_PARTS - {
    "BalconyDeck",
    "BalconyRail",
    "BalconyBaluster",
    "BannerCloth",
}

APPROVED_TIMBERS = {
	(29, 17, 8),    # deep beam sampled from A
	(42, 31, 20),   # dark structural timber
	(69, 44, 23),   # wall plank
	(89, 58, 32),   # warm wood
	(147, 103, 63), # highlighted wood
}


def distance(a: dict, b: dict) -> float:
    return math.sqrt((a["px"] - b["px"]) ** 2 + (a["pz"] - b["pz"]) ** 2)


def local_z(origin: dict, row: dict) -> float:
    """Project a world-space row onto the cafe's local Z axis."""
    dx = row["px"] - origin["px"]
    dz = row["pz"] - origin["pz"]
    return dx * origin["zx"] + dz * origin["zz"]


def local_x(origin: dict, row: dict) -> float:
    """Project a world-space row onto the cafe's local X axis."""
    dx = row["px"] - origin["px"]
    dz = row["pz"] - origin["pz"]
    return dx * origin["xx"] + dz * origin["xz"]


def main() -> int:
    parts, _ = load_world(False)
    cafe = [row for row in parts if ".Town.FamilyCafe." in row["path"]]
    counts = Counter(row["name"] for row in cafe)
    failures: list[str] = []

    for section, required in (("exterior", EXTERIOR_COUNTS), ("interior", INTERIOR_COUNTS)):
        for name, minimum in required.items():
            if counts[name] < minimum:
                failures.append(f"Bakery Bay {section} has {counts[name]} {name} part(s); expected {minimum}")

    present_legacy = sorted(name for name in LEGACY_PARTS if counts[name])
    if present_legacy:
        failures.append(f"old cafe parts still generate: {present_legacy}")

    solid_generic_front = sorted(name for name in ("FrontLeft", "FrontRight", "DoorHeader", "RightWall") if counts[name])
    if solid_generic_front:
        failures.append(f"generic solid front wall still covers the shop openings: {solid_generic_front}")

    if '_building("Family Cafe"' in WORLD:
        failures.append("FamilyCafe still calls the generic town-building generator")
    if "_buildLegacyFantasyCafe" in WORLD:
        failures.append("the legacy cafe builder still exists in source")
    # Shared balcony/banner helpers still serve the other town buildings; only
    # cafe-specific legacy source must disappear from WorldService entirely.
    for old_name in LEGACY_CAFE_SOURCE:
        if f'"{old_name}"' in WORLD:
            failures.append(f"legacy cafe source still contains {old_name}")

    colors = {(row["r"], row["g"], row["b"]) for row in cafe}
    missing_timbers = sorted(APPROVED_TIMBERS - colors)
    if missing_timbers:
        failures.append(f"approved five-brown palette is incomplete: {missing_timbers}")

    service = next((row for row in cafe if row["name"] == "BakeryOpenServiceBay"), None)
    display = next((row for row in cafe if row["name"] == "BakeryDisplayWindow"), None)
    doorway = next((row for row in cafe if row["name"] == "DoorwayVolume"), None)
    if service and display and doorway:
        if distance(service, display) < 20:
            failures.append("open counter and display window do not read as separate facade wings")
        if min(distance(service, doorway), distance(display, doorway)) < 7:
            failures.append("a shopfront wing intrudes into the narrow central entrance")
        service_side = (service["px"] - doorway["px"]) * doorway["xx"] + (service["pz"] - doorway["pz"]) * doorway["xz"]
        display_side = (display["px"] - doorway["px"]) * doorway["xx"] + (display["pz"] - doorway["pz"]) * doorway["xz"]
        if service_side <= 0 or display_side >= 0:
            failures.append("facade is mirrored: concept A requires the open counter left and display window right")
        display_forward = (display["px"] - doorway["px"]) * doorway["zx"] + (display["pz"] - doorway["pz"]) * doorway["zz"]
        if display_forward > -3:
            failures.append("pastry display does not project far enough beyond the main doorway facade")

        front_obstructors = [
            row
            for row in cafe
            if row["name"] in {"WallRail", "WallBrace"}
            and -2 < local_z(doorway, row) < 2
            and 4 < row["py"] < 12
        ]
        if front_obstructors:
            failures.append("structural rails or braces still cross the front window openings")

        steps = sorted(
            (row for row in cafe if row["name"] == "BakeryDoorStep"),
            key=lambda row: local_z(doorway, row),
            reverse=True,
        )
        if len(steps) != 3 or not (steps[0]["py"] > steps[1]["py"] > steps[2]["py"]):
            failures.append("door stairs run backwards: the highest step must be closest to the door")

        ground = next((row for row in parts if row["path"] == "Workspace.CuteFamilyTown.Ground"), None)
        if ground and steps:
            ground_top = ground["py"] + ground["sy"] / 2
            lowest_step_bottom = steps[-1]["py"] - steps[-1]["sy"] / 2
            if abs(lowest_step_bottom - ground_top) > 0.05:
                failures.append("lowest bakery step does not rest directly on the grass")
        else:
            failures.append("cannot verify the bakery steps against the town ground")

        shop_sign = next((row for row in cafe if row["name"] == "BakeryBaySign"), None)
        awnings = [row for row in cafe if row["name"] == "BakeryCanvasAwning"]
        if shop_sign and awnings:
            if shop_sign["sx"] > 12 or shop_sign["sy"] > 2.8:
                failures.append("main bakery sign is still too large")
            if local_x(doorway, shop_sign) < 5:
                failures.append("main bakery sign is not over the screen-left awning")
            if local_z(doorway, shop_sign) > -4:
                failures.append("main bakery sign is still behind the roof overhang")
            if shop_sign["py"] - shop_sign["sy"] / 2 <= max(row["py"] for row in awnings):
                failures.append("main bakery sign is not mounted above the striped awning")
        else:
            failures.append("main bakery sign or striped awning geometry is incomplete")

        side_opening = next((row for row in cafe if row["name"] == "BakeryOpenSideBay"), None)
        side_walls = [row for row in cafe if row["name"] == "BakeryServiceSideWall"]
        if side_opening and len(side_walls) >= 3:
            full_wall = max(side_walls, key=lambda row: row["sy"])
            lower_wall = min((row for row in side_walls if row is not full_wall), key=lambda row: row["py"])
            upper_wall = max((row for row in side_walls if row is not full_wall), key=lambda row: row["py"])
            opening_rear_edge = local_z(doorway, side_opening) + side_opening["sz"] / 2
            wall_front_edge = local_z(doorway, full_wall) - full_wall["sz"] / 2
            opening_bottom = side_opening["py"] - side_opening["sy"] / 2
            opening_top = side_opening["py"] + side_opening["sy"] / 2
            if abs(opening_rear_edge - wall_front_edge) > 0.25:
                failures.append("side wall still has a full-height gap behind the service window")
            if abs((lower_wall["py"] + lower_wall["sy"] / 2) - opening_bottom) > 0.25:
                failures.append("side wall is open below the intended service window")
            if abs((upper_wall["py"] - upper_wall["sy"] / 2) - opening_top) > 0.25:
                failures.append("side wall is open above the intended service window")
        else:
            failures.append("service-side wall/window pieces are incomplete")

        menu = next((row for row in cafe if row["name"] == "BakerySidewalkMenu"), None)
        menu_back = next((row for row in cafe if row["name"] == "BakerySidewalkMenuBack"), None)
        coffee_cup = next((row for row in cafe if row["name"] == "BakeryCoffeeCup"), None)
        if menu and menu_back and coffee_cup:
            facing_dot = menu["zx"] * doorway["zx"] + menu["zz"] * doorway["zz"]
            if facing_dot > -0.9:
                failures.append("sidewalk menu has not been rotated 180 degrees")
            if not (local_z(doorway, coffee_cup) < local_z(doorway, menu) < local_z(doorway, menu_back)):
                failures.append("coffee artwork is not on the street-facing side of the corrected menu sign")
            menu_top = (
                menu["px"] + menu["yx"] * menu["sy"] / 2,
                menu["py"] + menu["yy"] * menu["sy"] / 2,
                menu["pz"] + menu["yz"] * menu["sy"] / 2,
            )
            back_top = (
                menu_back["px"] + menu_back["yx"] * menu_back["sy"] / 2,
                menu_back["py"] + menu_back["yy"] * menu_back["sy"] / 2,
                menu_back["pz"] + menu_back["yz"] * menu_back["sy"] / 2,
            )
            hinge_gap = math.sqrt(sum((left - right) ** 2 for left, right in zip(menu_top, back_top)))
            if hinge_gap > 0.05:
                failures.append("sidewalk menu boards do not meet at a shared top hinge")
            if abs(menu["zy"]) < 0.18:
                failures.append("street menu face is not pitched down from the top hinge")
        else:
            failures.append("corrected A-frame menu sign geometry is incomplete")

        sign_feet = [row for row in cafe if row["name"] == "BakerySidewalkSignFoot"]
        if ground and len(sign_feet) == 4:
            ground_top = ground["py"] + ground["sy"] / 2
            if any(abs((foot["py"] - foot["sy"] / 2) - ground_top) > 0.05 for foot in sign_feet):
                failures.append("A-frame menu feet do not rest on the grass")
        else:
            failures.append("realistic A-frame menu feet are incomplete")

        if counts["BakeryArchedDoor"] or counts["BakeryDoorWindow"]:
            failures.append("the Bakery Bay entrance is not fully open; a door panel remains")
        if "BakeryMenuLettering" in WORLD or 'carvedSignFace(sidewalkBack' in WORLD:
            failures.append("lettering still appears behind the sidewalk coffee-cup emblem")

    if "displayWindow.Transparency = 0.72" not in WORLD:
        failures.append("right pastry glass is not the approved clearer 0.72 transparency")

    awning_colors = {
        (row["r"], row["g"], row["b"])
        for row in cafe
        if row["name"] == "BakeryCanvasAwning"
    }
    if len(awning_colors) != 2:
        failures.append(f"concept A canvas awning has {len(awning_colors)} colors instead of two stripes")

    menu_models = {
        row["path"].split(".")[-2]
        for row in cafe
        if ".CafeFood3DDisplay." in row["path"]
    }
    if len(menu_models) != 4:
        failures.append(f"interior menu retained {len(menu_models)} detailed food models instead of 4")

    other_shops = [
        row
        for row in parts
        if (".Town.PetShop." in row["path"] or ".Town.FlowerShop." in row["path"])
        and (row["name"].startswith("Bakery") or row["name"] == "PastryDisplayGlass")
    ]
    if other_shops:
        failures.append("Bakery Bay structure leaked into PetShop or FlowerShop")

    if failures:
        print("Cafe full-rebuild coverage failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Cafe full rebuild passed: concept A has two gabled timber wings, dormers, cupola, "
        "open counter, pastry window and a complete warm bakery interior; the old structure "
        "is absent and all four menu foods remain."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
