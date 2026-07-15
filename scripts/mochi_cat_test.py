"""Proves the first pet is the requested black-cat Mochi design."""

from __future__ import annotations

import sys

from quest_chain_test import boot


def values(table):
    return [table[index] for index in range(1, len(table) + 1)]


def rgb(color):
    return tuple(round(float(component) * 255) for component in (color.R, color.G, color.B))


def main() -> int:
    lua, modules, data_service, game, player, _toasts = boot()
    style = modules["WildwoodStyle"]
    catalog = modules["Catalog"]
    world = game._world
    failures: list[str] = []
    data = data_service.Get(data_service, player)

    if data.Pet.Name != "Mochi" or data.Pet.Species != "Cat":
        failures.append("the first profile pet is not Mochi the Cat")
    if data.Adventure.ActiveCompanion != "Cat":
        failures.append("Mochi is not the first active companion")
    if "Mochi" not in catalog.Companions.Cat.DisplayName:
        failures.append("the Cat companion catalog entry is no longer Mochi")

    pet = world._createPet(world, player)
    descendants = values(pet.GetDescendants(pet))
    named = {item.Name: item for item in descendants}
    is_ball = lua.eval("function(item) return item.Shape == Enum.PartType.Ball end")
    is_block = lua.eval("function(item) return item.Shape == Enum.PartType.Block end")

    expected_black = (17, 18, 20)
    if rgb(style.Pets.Cat.Main) != expected_black:
        failures.append(f"Mochi's approved black is {rgb(style.Pets.Cat.Main)}, expected {expected_black}")
    for name in ("BodyRoot", "CatHead", "CatTail", "CatEarLeft", "CatEarRight"):
        item = pet.PrimaryPart if name == "BodyRoot" else named.get(name)
        if not item:
            failures.append(f"Mochi is missing {name}")
        elif rgb(item.Color) != expected_black:
            failures.append(f"{name} is {rgb(item.Color)}, not Mochi black {expected_black}")

    for name in ("CatEarLeft", "CatEarRight"):
        ear = named.get(name)
        if ear and (ear.ClassName != "WedgePart" or not ear.GetAttribute(ear, "TriangleFeature")):
            failures.append(f"{name} is not triangular wedge geometry")

    # Approved concept A is Voxel all the way through, not a box head placed on
    # the previous sphere body. The root, face, eyes, legs, paws and stepped tail
    # must contain no PartType.Ball geometry.
    required_voxel_parts = {
        "CatHead",
        "CatMuzzle",
        "CatEyeLeft",
        "CatEyeRight",
        "CatPupilLeft",
        "CatPupilRight",
        "CatFrontLegLeft",
        "CatFrontPawLeft",
        "CatBackLegRight",
        "CatBackPawRight",
        "CatTail",
        "CatTailStep2",
        "CatTailStep3",
        "CatTailStep4",
    }
    missing_voxel = sorted(required_voxel_parts - set(named))
    if missing_voxel:
        failures.append(f"Mochi's Voxel silhouette is missing {', '.join(missing_voxel)}")

    voxel_parts = [pet.PrimaryPart] + [
        item
        for item in descendants
        if item.IsA(item, "BasePart") and item.GetAttribute(item, "CompanionDetail")
    ]
    ball_parts = [
        item.Name
        for item in voxel_parts
        if item.ClassName == "Part" and is_ball(item)
    ]
    if ball_parts:
        failures.append(f"approved Voxel Mochi still contains round geometry: {', '.join(sorted(ball_parts))}")
    for name in ("BodyRoot", "CatHead", "CatMuzzle", "CatTail", "CatTailStep4"):
        item = pet.PrimaryPart if name == "BodyRoot" else named.get(name)
        if item and (item.ClassName != "Part" or not is_block(item)):
            failures.append(f"{name} is not block geometry")

    nose = named.get("CatNose")
    if not nose:
        failures.append("Mochi is missing the nose")
    else:
        if nose.Text != "▼":
            failures.append(f"Mochi's nose is {nose.Text!r}, not a down-pointing triangle")
        if rgb(nose.TextColor3) != (244, 188, 198):
            failures.append(f"Mochi's nose is {rgb(nose.TextColor3)}, not pale pink")

    mouth = named.get("CatMouth")
    if not mouth:
        failures.append("Mochi is missing the cat mouth")
    elif mouth.Text != "ω":
        failures.append(f"Mochi's mouth is {mouth.Text!r}, not the two-lobed cat-mouth shape")

    world_label = pet.PrimaryPart.FindFirstChild(pet.PrimaryPart, "WorldLabel")
    label = world_label and world_label.FindFirstChild(world_label, "Text")
    if not label or label.Text != "Mochi":
        failures.append("the first spawned black cat is not visibly named Mochi")

    if failures:
        print("Mochi cat failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print(
        "Mochi Voxel cat passed: black cuboid head/body, rectangular eyes and four block paws contain "
        "no spheres; ears are triangular wedges; the four-piece tail rises in steps; the pale-pink "
        "downward triangle nose and omega cat mouth remain visible."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
