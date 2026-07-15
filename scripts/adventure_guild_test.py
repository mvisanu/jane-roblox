"""Proves the balanced three-way Adventure Guild and centre-only map travel."""

from __future__ import annotations

import math
import time
from collections import Counter
from pathlib import Path

from quest_chain_test import COOLDOWN, boot
from walkability_test import load_world


ROOT = Path(__file__).resolve().parents[1]


def make_character(lua, x: float, z: float):
    instance, vector3, cframe = lua.globals().Instance, lua.globals().Vector3, lua.globals().CFrame
    character = instance.new("Model")
    root = instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = vector3.new(2, 2, 1)
    root.CFrame = cframe.new(x, 4, z)
    root.Parent = character
    character.PrimaryPart = root
    return character, root


def main() -> int:
    parts, _waypoints = load_world(False)
    failures: list[str] = []
    guild_parts = [row for row in parts if ".AdventureGuild." in row["path"]]
    counts = Counter(row["name"] for row in guild_parts)

    required_counts = {
        "GuildFoundation": 3,
        "GuildPillar": 1,
        "GuildPillarRib": 4,
        "GuildCanopyArm": 3,
        "GuildPathInlay": 3,
        "GuildStationPlatform": 3,
        "GuildStationPost": 3,
        "GuildStationCanopy": 3,
        "GuildStationBoard": 3,
        "GuildNameBoard": 1,
    }
    for name, expected in required_counts.items():
        if counts[name] != expected:
            failures.append(f"{name}: expected {expected}, found {counts[name]}")
    if counts["Fountain"] or counts["FountainTop"]:
        failures.append("legacy fountain geometry remains at the town centre")

    stations = [row for row in guild_parts if row["name"] == "GuildStationPlatform"]
    if len(stations) == 3:
        centroid_x = sum(row["px"] for row in stations) / 3
        centroid_z = sum(row["pz"] for row in stations) / 3
        radii = [math.hypot(row["px"], row["pz"]) for row in stations]
        distances = [
            math.hypot(stations[first]["px"] - stations[second]["px"], stations[first]["pz"] - stations[second]["pz"])
            for first, second in ((0, 1), (1, 2), (2, 0))
        ]
        if abs(centroid_x) > 0.01 or abs(centroid_z) > 0.01:
            failures.append(f"three Guild stations are not centred (centroid={centroid_x:.2f},{centroid_z:.2f})")
        if max(radii) - min(radii) > 0.01 or abs(sum(radii) / 3 - 10.8) > 0.01:
            failures.append(f"Guild stations are not on one equal 10.8-stud radius: {radii}")
        if max(distances) - min(distances) > 0.01:
            failures.append(f"Guild stations are not exactly 120 degrees apart: {distances}")

    world_source = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")
    client_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
    game_source = (ROOT / "src/ServerScriptService/Services/GameService.lua").read_text(encoding="utf-8")
    remote_source = (ROOT / "src/ReplicatedStorage/Shared/RemoteNames.lua").read_text(encoding="utf-8")
    server_source = (ROOT / "src/ServerScriptService/Server.server.lua").read_text(encoding="utf-8")

    contracts = {
        world_source: {
            'square:SetAttribute("DistrictName", "Adventure Guild")': "town-centre district was not renamed",
            'carvedSignFace(nameBoard, "ADVENTURE GUILD"': "central pillar lacks the physical Adventure Guild name",
            'Sign = "🏕️ รับภารกิจ\\nQUESTS"': "quest station sign is missing",
            'Sign = "🗺️ เปิดแผนที่\\nMAP & TRAVEL"': "map station sign is missing",
            'Sign = "🐾 ช่วยสัตว์\\nHELP ANIMALS"': "animal-help station sign is missing",
            'guild:SetAttribute("Layout", "BalancedThreeWay")': "Guild is not marked as a balanced three-way hub",
            'self:_addBlip("Area", "Adventure Guild", "กิลด์ผจญภัย"': "minimap still uses the old square name",
            'self:_connectGuildPrompt(guildPrompt, station.Id)': "physical stations are not connected to Guild UI actions",
        },
        client_source: {
            "guildActionRemote.OnClientEvent:Connect": "client does not listen to physical Guild stations",
            'action == "Quest"': "quest station does not open the quest board",
            'action == "Map"': "map station does not open map travel",
            'action == "Animals"': "animal station does not open pet care",
            "if not guildMapAccess then": "bottom Map tab is not locked away from the Guild",
            "addGuildTravelButton": "Guild map contains no travel destinations",
        },
        game_source: {
            "function GameService:_isNearAdventureGuild": "server lacks a Guild-distance check",
            "if not self:_isNearAdventureGuild(player) then": "server accepts map travel away from the Guild",
            'elseif action == "TeleportHome" then': "cottage-door travel was not separated from map travel",
        },
        remote_source: {'GuildAction = "GuildAction"': "Guild UI remote name is missing"},
        server_source: {"guildAction.Name = RemoteNames.GuildAction": "server does not create the Guild UI remote"},
    }
    for source, checks in contracts.items():
        for contract, message in checks.items():
            if contract not in source:
                failures.append(message)
    if "WILDWOOD GUILD SQUARE" in world_source or '"Guild Square"' in world_source:
        failures.append("old Wildwood Guild Square name remains in generated world source")

    # The UI lock is convenience; this is the authoritative security/gameplay
    # proof. A fabricated Teleport request fails away from the centre and works
    # at the pillar, while a physical cottage door remains usable elsewhere.
    lua, modules, _data, game, player, _toasts = boot()
    character, root = make_character(lua, 90, 90)
    player.Character = character
    far = game.Handle(game, player, "Teleport", lua.table_from({"destination": "Cafe"}))
    if far.ok:
        failures.append("server allowed map travel while the player was away from Adventure Guild")
    time.sleep(COOLDOWN + 0.05)
    center = modules["Config"].AdventureGuildCenter
    root.CFrame = lua.globals().CFrame.new(center.X, center.Y, center.Z)
    near = game.Handle(game, player, "Teleport", lua.table_from({"destination": "Cafe"}))
    if not near.ok:
        failures.append("server rejected map travel at the Adventure Guild pillar")
    time.sleep(COOLDOWN + 0.05)
    root.CFrame = lua.globals().CFrame.new(90, 4, 90)
    home = game.Handle(game, player, "TeleportHome", lua.table())
    if not home.ok:
        failures.append("separate cottage-door travel was incorrectly locked to the Guild")

    if failures:
        print("Adventure Guild failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        "Adventure Guild passed: renamed physical centre, three equal 120-degree service stations, "
        "working quest/map/animal UI routes, and server-enforced centre-only map travel."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
