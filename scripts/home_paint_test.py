"""Proves cottage paint changes only structural walls and the main roof."""

from __future__ import annotations

from collections import Counter

from furniture_test import boot, ok_of


EXPECTED_PAINT_COUNTS = Counter({
    "BackWall",
    "FrontLeft",
    "FrontRight",
    "LeftWall",
    "RightWall",
    "DoorHeader",
    "RoofPlane",
})
EXPECTED_PAINT_COUNTS["RoofPlane"] = 2

REQUIRED_PRESERVED = {
    "Floor",
    "Ceiling",
    "WallPlankSeam",
    "CornerPost",
    "WallRail",
    "StoneFoundation",
    "FoundationStone",
    "RoofCourse",
    "RoofRidge",
    "GableCourse",
    "GablePost",
    "WallBrace",
    "Porch",
    "PorchStep",
    "PorchCanopy",
    "PorchRoofCourse",
    "PorchCanopyTrim",
    "PorchPostBase",
    "PorchPost",
    "EaveBracket",
    "PorchRail",
    "PorchBaluster",
    "WindowFrame",
    "WindowMullion",
    "WindowShutter",
    "WindowBox",
    "WindowGlow",
    "SideWindowGlow",
    "Door",
    "DoorFrame",
    "DoorWindow",
    "DoorHandle",
    "StoneChimney",
    "ChimneyStone",
    "ChimneyCap",
    "LanternBracket",
    "LanternCap",
    "LanternGlow",
    "CeilingLamp",
    "WindowBoxLeaf",
    "WindowBoxFlower",
    "Mailbox",
    "GardenSlot1",
}


def rgb(part) -> tuple[int, int, int]:
    return tuple(round(float(value) * 255) for value in (part.Color.R, part.Color.G, part.Color.B))


def values(table):
    return [table[index] for index in range(1, len(table) + 1)]


def main() -> int:
    lua, modules, data, game, world, player = boot()
    profile = data.Get(data, player)
    home = world._homeByPlayer[player]
    failures: list[str] = []

    world.RefreshHome(world, player, profile)
    paint_parts = values(home.PaintParts)
    paint_counts = Counter(str(part.Name) for part in paint_parts)

    if paint_counts != EXPECTED_PAINT_COUNTS:
        failures.append(
            f"paint targets must be exactly six wall pieces and two main roof planes: "
            f"expected={EXPECTED_PAINT_COUNTS}, actual={paint_counts}"
        )

    descendants = values(home.Model.GetDescendants(home.Model))
    preserved = [
        part for part in descendants
        if part.IsA(part, "BasePart") and not part.GetAttribute(part, "HomePaintSurface")
    ]
    preserved_names = {str(part.Name) for part in preserved}
    missing_preserved = sorted(REQUIRED_PRESERVED - preserved_names)
    if missing_preserved:
        failures.append(f"test could not find preserved cottage parts: {missing_preserved}")
    preserved_before = {id(part): rgb(part) for part in preserved}

    colors = modules["Config"].HomeColors
    # This order visits every swatch and never requests the same colour twice.
    sequence = ("Brown", "Hickory", "Mocha", "Coffee", "Peanut")
    by_name = {str(entry.Name): entry for entry in values(colors)}
    for color_name in sequence:
        if str(profile.Home.Paint) == color_name:
            continue
        result = game._handleAction(game, player, "PaintHome", lua.table_from({"color": color_name}))
        if not ok_of(result):
            failures.append(f"PaintHome rejected approved menu colour {color_name}")
            continue

        expected = rgb(by_name[color_name])
        wrong = [part for part in paint_parts if rgb(part) != expected]
        if wrong:
            examples = ", ".join(str(part.Name) for part in wrong[:8])
            failures.append(
                f"{color_name}: {len(wrong)}/{len(paint_parts)} house surfaces did not change ({examples})"
            )
        for part in paint_parts:
            if str(part.GetAttribute(part, "ActiveHomePaint")) != color_name:
                failures.append(f"{part.Name} did not record active paint {color_name}")
                break
        changed_preserved = [part for part in preserved if rgb(part) != preserved_before[id(part)]]
        if changed_preserved:
            examples = ", ".join(str(part.Name) for part in changed_preserved[:8])
            failures.append(
                f"{color_name}: {len(changed_preserved)} original-colour parts changed ({examples})"
            )
        if str(profile.Home.Paint) != color_name:
            failures.append(f"profile did not save selected colour {color_name}")
        if str(home.Model.GetAttribute(home.Model, "PaintColor")) != color_name:
            failures.append(f"home model did not expose selected colour {color_name}")

    # DataStore round-trip: the selected swatch must still cover only the target
    # walls and main roof when the player rejoins from saved data.
    data.Unload(data, player)
    data.Load(data, player)
    reloaded = data.Get(data, player)
    if str(reloaded.Home.Paint) != "Peanut":
        failures.append(f"selected paint did not survive rejoin: {reloaded.Home.Paint}")
    world.RefreshHome(world, player, reloaded)
    peanut = rgb(by_name["Peanut"])
    if any(rgb(part) != peanut for part in paint_parts):
        failures.append("rejoining did not repaint the walls and main roof from saved colour")
    if any(rgb(part) != preserved_before[id(part)] for part in preserved):
        failures.append("rejoining changed a cottage detail that must retain its authored colour")

    if failures:
        print("Home paint failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        f"Home paint passed: exactly {len(paint_parts)} surfaces (six wall pieces and two main roof planes) "
        f"follow every swatch and survive rejoin while {len(preserved)} other cottage parts retain their authored colours."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
