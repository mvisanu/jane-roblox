"""Proves the companion is one quarter of the reference player height."""

from __future__ import annotations

import sys

from quest_chain_test import boot


def model_height(pet) -> float:
    children = pet.GetChildren(pet)
    parts = [children[index] for index in range(1, len(children) + 1)]
    parts = [part for part in parts if part.IsA(part, "BasePart")]
    lowest = min(float(part.CFrame.Position.Y) - float(part.Size.Y) / 2 for part in parts)
    highest = max(float(part.CFrame.Position.Y) + float(part.Size.Y) / 2 for part in parts)
    return highest - lowest


def main() -> int:
    lua, modules, _data, game, player, _toasts = boot()
    config = modules["Config"]
    world = game._world
    pet = world._createPet(world, player)
    failures: list[str] = []

    children = pet.GetChildren(pet)
    parts = [children[index] for index in range(1, len(children) + 1)]
    parts = [part for part in parts if part.IsA(part, "BasePart")]
    actual_height = model_height(pet)
    player_height = float(config.CharacterReferenceHeight)
    expected_height = player_height * float(config.PetHeightRatio)

    if abs(float(config.PetHeightRatio) - 0.25) > 1e-9:
        failures.append(f"PetHeightRatio is {config.PetHeightRatio}, expected 0.25")
    if abs(actual_height - expected_height) > 1e-6:
        failures.append(f"pet is {actual_height:.4f} studs tall, expected {expected_height:.4f}")
    if abs(float(pet.GetAttribute(pet, "HeightRatio")) - 0.25) > 1e-9:
        failures.append("the spawned model does not record the 1:4 ratio")
    if not parts or any(float(axis) <= 0 for part in parts for axis in (part.Size.X, part.Size.Y, part.Size.Z)):
        failures.append("resizing produced missing or zero-volume pet geometry")

    # A taller avatar must get a proportionally taller pet, still at 25%.
    instance = lua.globals().Instance
    vector3 = lua.globals().Vector3
    cframe = lua.globals().CFrame
    character = instance.new("Model")
    root = instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = vector3.new(2, 2, 1)
    root.CFrame = cframe.new(0, 4, 0)
    root.Parent = character
    envelope = instance.new("Part")
    envelope.Name = "AvatarBodyEnvelope"
    envelope.Size = vector3.new(2, 8, 1)
    envelope.CFrame = cframe.new(0, 4, 0)
    envelope.Parent = character
    player.Character = character
    tall_pet = world._createPet(world, player)
    tall_height = model_height(tall_pet)
    if abs(tall_height - 2.0) > 1e-6:
        failures.append(f"an 8-stud avatar received a {tall_height:.4f}-stud pet instead of 2.0")

    source = open("src/ServerScriptService/Services/WorldService.lua", encoding="utf-8").read()
    for contract in ("characterBodyMetrics", "CharacterFootOffset", "bounceHeight"):
        if contract not in source:
            failures.append(f"pet resize lost its {contract} grounding/follow contract")

    if failures:
        print("Pet scale failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        f"Pet scale passed: {actual_height:.2f}-stud standard and {tall_height:.2f}-stud tall-avatar "
        f"companions are exactly {float(config.PetHeightRatio):.0%} of their characters."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
