"""Offline structural checks for Cute Family Town.

This is intentionally dependency-free. Roblox Studio remains the source of truth for
engine-level execution, but these checks catch broken project wiring before a sync.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "default.project.json",
    "src/ReplicatedStorage/Shared/Config.lua",
    "src/ReplicatedStorage/Shared/WildwoodStyle.lua",
    "src/ReplicatedStorage/Shared/Catalog.lua",
    "src/ReplicatedStorage/Shared/BagInventory.lua",
    "src/ReplicatedStorage/Shared/CampPlan.lua",
    "src/ReplicatedStorage/Shared/CafeMenu.lua",
    "src/ReplicatedStorage/Shared/CafeModels.lua",
    "src/ReplicatedStorage/Shared/EnvironmentClock.lua",
    "src/ReplicatedStorage/Shared/QuestGuide.lua",
    "src/ReplicatedStorage/Shared/QuestBoardLayout.lua",
    "src/ReplicatedStorage/Shared/RemoteNames.lua",
    "src/ServerScriptService/Server.server.lua",
    "src/ServerScriptService/Services/DataService.lua",
    "src/ServerScriptService/Services/GameService.lua",
    "src/ServerScriptService/Services/WorldService.lua",
    "src/StarterPlayer/StarterPlayerScripts/Client.client.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/Components.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/BagGrid.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/EnvironmentController.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/HomePalette.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/Iconography.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/QuestNavigator.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/RiverController.lua",
    "src/StarterPlayer/StarterPlayerScripts/UI/Theme.lua",
]


def scan_delimiters(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    pairs = {")": "(", "]": "[", "}": "{"}
    opening = set(pairs.values())
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    line = 1
    index = 0
    quote: str | None = None
    long_string = False

    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if char == "\n":
            line += 1

        if long_string:
            if char == "]" and nxt == "]":
                long_string = False
                index += 2
                continue
            index += 1
            continue

        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
            index += 1
            continue

        if char == "-" and nxt == "-":
            if text[index + 2 : index + 4] == "[[":
                end = text.find("]]", index + 4)
                if end == -1:
                    errors.append(f"{path}: unterminated long comment at line {line}")
                    return errors
                line += text[index:end].count("\n")
                index = end + 2
                continue
            end = text.find("\n", index + 2)
            if end == -1:
                break
            index = end
            continue

        if char in {"'", '"'}:
            quote = char
        elif char == "[" and nxt == "[":
            long_string = True
            index += 2
            continue
        elif char in opening:
            stack.append((char, line))
        elif char in pairs:
            if not stack or stack[-1][0] != pairs[char]:
                errors.append(f"{path}: unmatched {char!r} at line {line}")
            else:
                stack.pop()
        index += 1

    if quote:
        errors.append(f"{path}: unterminated string")
    if long_string:
        errors.append(f"{path}: unterminated long string")
    errors.extend(f"{path}: unclosed {char!r} from line {line_no}" for char, line_no in stack)
    return errors


def quoted_values(text: str, pattern: str) -> set[str]:
    return set(re.findall(pattern, text))


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"Missing required file: {relative}")

    try:
        project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
        if project.get("name") != "CuteFamilyTown":
            errors.append("default.project.json has an unexpected project name")
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"Invalid default.project.json: {exc}")

    for path in (ROOT / "src").rglob("*.lua"):
        errors.extend(scan_delimiters(path))
    errors.extend(scan_delimiters(ROOT / "scripts/studio_smoke.lua"))

    game_source = (ROOT / "src/ServerScriptService/Services/GameService.lua").read_text(encoding="utf-8")
    world_source = (ROOT / "src/ServerScriptService/Services/WorldService.lua").read_text(encoding="utf-8")
    client_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/Client.client.lua").read_text(encoding="utf-8")
    config_source = (ROOT / "src/ReplicatedStorage/Shared/Config.lua").read_text(encoding="utf-8")
    data_source = (ROOT / "src/ServerScriptService/Services/DataService.lua").read_text(encoding="utf-8")
    catalog_source = (ROOT / "src/ReplicatedStorage/Shared/Catalog.lua").read_text(encoding="utf-8")

    # The approved cottage palette is a user-visible contract: the swatches,
    # labels, saved ids and actual wall colours must all describe the same five
    # choices, with no retired colour silently remaining selectable.
    home_palette_source = (
        ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/HomePalette.lua"
    ).read_text(encoding="utf-8")
    home_block = re.search(r"Config\.HomeColors\s*=\s*\{(.*?)\n\}", config_source, re.DOTALL)
    approved_home_colors = [
        ("Brown", "Deep Timber", "#1D1108", "TimberDeep"),
        ("Hickory", "Dark Timber", "#2A1F14", "TimberDark"),
        ("Mocha", "Wall Wood", "#452C17", "TimberMid"),
        ("Coffee", "Warm Wood", "#593A20", "TimberWarm"),
        ("Peanut", "Highlight Wood", "#93673F", "TimberLight"),
    ]
    actual_home_colors = []
    if home_block:
        entries = re.findall(
            r'\{\s*Name = "([^"]+)",\s*DisplayName = "([^"]+)",\s*NameThai = "([^"]+)",'
            r'\s*Hex = "(#[0-9A-F]{6})",\s*Color = WildwoodStyle\.World\.([A-Za-z]+)\s*\}',
            home_block.group(1),
        )
        actual_home_colors = [
            (name, display, hex_value, role)
            for name, display, _thai, hex_value, role in entries
        ]
    if actual_home_colors != approved_home_colors:
        errors.append(
            "Home palette no longer matches the approved Bakery Bay ids, labels, hex values and central roles"
        )
    for contract in (
        "SelectedColorPreview",
        "WALLS & MAIN ROOF",
        "SELECTED COLOR",
        "entry.Hex",
        'SetAttribute("PaintColor"',
        "SelectedBadge",
        "onChoose(entry.Name)",
    ):
        if contract not in home_palette_source:
            errors.append(f"Direct-select home palette contract is missing: {contract}")
    if 'invoke("PaintHome", { color = colorName })' not in client_source:
        errors.append("Home palette does not send the selected colour id to the server")
    if "Paint = Config.DefaultHomeColor" not in data_source or "or Config.DefaultHomeColor" not in data_source:
        errors.append("New and retired home paints do not migrate to the configured reference-matched default")
    for contract in ('type(payload.color) == "string"', "if entry.Name == requested"):
        if contract not in game_source:
            errors.append(f"Server-side home palette whitelist is missing: {contract}")

    client_actions = quoted_values(client_source, r'invoke\("([A-Za-z]+)"')
    client_actions |= quoted_values(client_source, r'addButton\([^\n]*,\s*"([A-Za-z]+)"')
    client_actions |= quoted_values(world_source, r'_connectPrompt\([^\n]*,\s*"([A-Za-z]+)"')
    server_actions = quoted_values(game_source, r'action\s*==\s*"([A-Za-z]+)"')
    server_actions.add("GetState")
    for action in sorted(client_actions - server_actions):
        errors.append(f"Client action has no server handler: {action}")

    destinations = quoted_values(client_source, r'destination\s*=\s*"([A-Za-z]+)"')
    map_loop = re.search(r'for _, destination in ipairs\(\{([^}]+)\}\)', client_source)
    if map_loop:
        destinations |= quoted_values(map_loop.group(1), r'"([A-Za-z]+)"')
    config_destinations = quoted_values(config_source, r'\b([A-Za-z]+)\s*=\s*Vector3\.new')
    for destination in sorted(destinations - config_destinations - {"Home"}):
        errors.append(f"Client destination is missing from Config.Waypoints: {destination}")

    adventure_actions = {
        "AdventureCollect",
        "AdventureUpgradeCamp",
        "AdventureUnlockCompanion",
        "AdventureSelectCompanion",
        "AdventurePuzzleRune",
        "AdventureShare",
    }
    adventure_surface = client_source + world_source
    for action in sorted(adventure_actions):
        if f'action == "{action}"' not in game_source:
            errors.append(f"Adventure server action is missing: {action}")
        if f'"{action}"' not in adventure_surface:
            errors.append(f"Adventure action is not reachable from UI or world: {action}")

    required_adventure_destinations = {
        "AdventureCamp",
        "WildwoodForest",
        "Mountain",
        "RiverAdventure",
        "MysteryCave",
    }
    for destination in sorted(required_adventure_destinations - config_destinations):
        errors.append(f"Adventure destination is missing from Config.Waypoints: {destination}")

    required_adventure_contracts = [
        (game_source, "Catalog.CampLevels"),
        (game_source, "Catalog.Companions"),
        (world_source, "_buildAdventureWorld"),
        (world_source, "RefreshAdventureCamp"),
        (client_source, 'menu == "Adventure"'),
    ]
    for source, contract in required_adventure_contracts:
        if contract not in source:
            errors.append(f"Adventure contract is missing: {contract}")

    legacy_actions = {
        "ClaimDaily", "GardenSmart", "GardenPlant", "GardenWater", "GardenHarvest", "BuySeed",
        "PetFeed", "PetPlay", "PetBath", "CafeUnlock", "CafeSmart", "CafeServe", "CafeUpgrade",
        "HireCafeStaff", "BuyFurniture", "PlaceFurniture", "RemoveFurniture", "PaintHome",
        "EquipAvatar", "Teleport", "FinishOnboarding",
    }
    for action in sorted(legacy_actions):
        if f'action == "{action}"' not in game_source:
            errors.append(f"Existing server action was removed: {action}")

    for section in ("Home", "Garden", "Pet", "Cafe", "Wardrobe", "Daily", "Stats", "Settings", "Adventure"):
        if f"\t{section} = {{" not in data_source:
            errors.append(f"Profile section is missing: {section}")

    for contract in ("AdventureResources", "AdventureZones", "Companions", "CampLevels", "SeasonEvents"):
        if f"Catalog.{contract}" not in catalog_source:
            errors.append(f"Adventure catalog is missing: {contract}")

    # A Level 5 player could not find out what the last camp wanted: the quest step
    # said "Upgrade your camp" and the server named one missing resource at a time.
    # The fix is that one module computes the list and everything reads from it, so
    # these are the contracts that stop the parts drifting back apart.
    # `scripts/camp_plan_test.py` checks the behaviour; these check it is still wired in.
    campplan_source = (ROOT / "src/ReplicatedStorage/Shared/CampPlan.lua").read_text(encoding="utf-8")
    questboard_source = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/QuestBoard.lua").read_text(encoding="utf-8")

    for contract in ("function CampPlan.requirements", "function CampPlan.missingText", "function CampPlan.canBuild"):
        if contract not in campplan_source:
            errors.append(f"CampPlan is missing the function the UI and server read from: {contract}")

    # Every resource needs a picture and a place to find it: the game is played by
    # five-year-olds, for whom "Cave Crystal" is not yet a readable label.
    for resource in ("Wood", "Stone", "Herbs", "Fish", "Crystal"):
        entry = re.search(rf"\n\t{resource} = \{{([^\n]*)\}},", catalog_source)
        if not entry:
            errors.append(f"Adventure resource is missing from the catalog: {resource}")
        elif "Icon =" not in entry.group(1) or "FoundIn =" not in entry.group(1):
            errors.append(f"Adventure resource {resource} needs an Icon and a FoundIn, for players who cannot read")

    requirement_contracts = [
        (game_source, "CampPlan.canBuild", "the server still refuses camp upgrades without naming every missing item"),
        (game_source, "CampPlan.missingText", "the server's refusal no longer lists what is missing"),
        (questboard_source, "_campRequirements", "the quest board no longer shows what the camp upgrade needs"),
        (client_source, 'menu == "Bag"', "the inventory screen is gone"),
        (client_source, "local function addSlot", "the bag no longer draws storage slots"),
        (client_source, "CampPlan.requirements", "the adventure menu no longer shows the camp checklist"),
    ]
    for source, contract, complaint in requirement_contracts:
        if contract not in source:
            errors.append(f"Camp requirement contract is missing ({contract}): {complaint}")

    if "door.CanCollide = false" not in world_source or "home.InteriorSpawn or home.Spawn" not in world_source:
        errors.append("Passable home entrance regression fix is missing")

    # Homes and buildings must stay enterable. scripts/walkability_test.py proves
    # the geometry; these checks stop the contract it relies on from being removed.
    for contract in ("_shell", "DoorwayVolume", "InteriorMarker", 'SetAttribute("Enterable", true)'):
        if contract not in world_source:
            errors.append(f"Enterable-structure contract is missing from WorldService: {contract}")

    if re.search(r'part\(building,\s*"Body"', world_source):
        errors.append("Town buildings are solid blocks again: remove the 'Body' part and use _shell")

    for helper in ("_buildTreeHouse", "_buildCampCottage", "_buildAdventureCenter"):
        if f"function WorldService:{helper}" not in world_source:
            errors.append(f"Enterable camp building is missing: {helper}")

    # Sunrise Mountain must stay climbable on foot, not teleport-only.
    for contract in ("MOUNTAIN_LEVELS", "_mountainStairs", "SummitMarker"):
        if contract not in world_source:
            errors.append(f"Climbable mountain contract is missing from WorldService: {contract}")

    # World labels: scaled down, distance-culled, tagged, and toggleable.
    remote_source = (ROOT / "src/ReplicatedStorage/Shared/RemoteNames.lua").read_text(encoding="utf-8")
    if "LabelTag" not in remote_source:
        errors.append("RemoteNames is missing the shared LabelTag used to find world labels")
    for setting in ("LabelScale", "LabelNearDistance", "LabelFarDistance"):
        if setting not in config_source:
            errors.append(f"Label tuning value is missing from Config: {setting}")
    for contract in ("Config.LabelScale", "MaxDistance", "CollectionService:AddTag"):
        if contract not in world_source:
            errors.append(f"World labels are not fade-ready: {contract} is missing from WorldService")
    for contract in ("RemoteNames.LabelTag", "labelsEnabled", 'invoke("ToggleLabels"'):
        if contract not in client_source:
            errors.append(f"Label toggle is missing from the client: {contract}")
    if "ShowLabels" not in data_source:
        errors.append("Settings.ShowLabels is missing from the profile, so the label toggle cannot persist")

    # The village look from images/home.png. scripts/village_style_test.py proves
    # the palette and architecture; these stop the contract from being deleted.
    if "VillagePalette" not in config_source:
        errors.append("Config.VillagePalette is missing: the village colours came from images/home.png")
    for helper in ("_gableRoof", "_timberFrame", "_stoneFooting", "_hangingLantern", "_dressBuilding"):
        if f"function WorldService:{helper}" not in world_source:
            errors.append(f"Village architecture helper is missing: {helper}")
    if not (ROOT / "images/home.png").is_file():
        errors.append("images/home.png is missing: it is the reference the buildings are matched against")

    # The broader redesign comes from the supplied Stitch export: one shared
    # palette/font source must feed UI, world, furniture, characters and pets.
    style_path = ROOT / "src/ReplicatedStorage/Shared/WildwoodStyle.lua"
    style_source = style_path.read_text(encoding="utf-8") if style_path.is_file() else ""
    for contract in (
        "ForestGreen = Color3.fromRGB(79, 107, 69)",
        "EarthBrown = Color3.fromRGB(107, 94, 60)",
        "Parchment = Color3.fromRGB(235, 217, 171)",
        'Headline = "Plus Jakarta Sans"',
        'Body = "Quicksand"',
    ):
        if contract not in style_source:
            errors.append(f"Supplied Stitch visual contract is missing: {contract}")
    for helper in ("_pineTree", "_mossyCobble", "_stringLightSpan", "_buildCompanionGeometry", "_styleExplorerCharacter"):
        if f"function WorldService:{helper}" not in world_source:
            errors.append(f"Wildwood redesign helper is missing: {helper}")
    for contract in (
        'Instance.new("WedgePart")',
        'nose.Text = "▼"',
        'mouth.Text = "ω"',
        'Main = Color3.fromRGB(17, 18, 20)',
        'Accent = Color3.fromRGB(244, 188, 198)',
        'local function voxelEyes',
        'root.Shape = companionId == "Cat" and Enum.PartType.Block',
        'petPart("CatTailStep4"',
    ):
        if contract not in world_source and contract not in style_source:
            errors.append(f"Approved black-cat Mochi contract is missing: {contract}")
    reference_root = ROOT / "theme/stitch_roblox_color_code_extractor"
    for relative in (
        "wildwood_adventure/DESIGN.md",
        "mood_board.png/screen.png",
        "architecture_reference_sheet/screen.png",
        "environment_props_sheet/screen.png",
        "character_reference_sheet/screen.png",
        "animal_reference_sheet/screen.png",
    ):
        if not (reference_root / relative).is_file():
            errors.append(f"Supplied Stitch reference is missing: {relative}")

    # The minimap draws the town the server built; it must not grow a second,
    # hand-maintained copy of the layout that can drift out of step.
    minimap_path = ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/Minimap.lua"
    if not minimap_path.is_file():
        errors.append("Minimap UI module is missing")
    else:
        minimap_source = minimap_path.read_text(encoding="utf-8")
        for contract in ("function Minimap:SetMap", "function Minimap:_zoom", "function Minimap:_setState"):
            if contract not in minimap_source:
                errors.append(f"Minimap is missing a control it is meant to offer: {contract}")
        if "Config.Waypoints" in minimap_source:
            errors.append("Minimap must draw the layout the server sends, not rebuild it from Config")
    if "function WorldService:GetMapData" not in world_source:
        errors.append("WorldService.GetMapData is missing, so the minimap has no layout to draw")
    if "_addBlip" not in world_source:
        errors.append("WorldService no longer records map landmarks as it builds the town")
    if 'InvokeServer("GetMap"' not in client_source or "Minimap.new" not in client_source:
        errors.append("Client does not create the minimap or fetch the town layout")

    # Quest chains. scripts/quest_chain_test.py plays through every step and
    # checks the payouts; these keep the pieces it relies on in place.
    if "Catalog.QuestChains" not in catalog_source:
        errors.append("Catalog.QuestChains is missing, so there are no quest chains")
    for contract in ("function GameService:_progressChain", 'action == "ClaimChainBonus"'):
        if contract not in game_source:
            errors.append(f"Quest chain server logic is missing: {contract}")
    if "Quests" not in data_source or "PendingBonus" not in data_source:
        errors.append("The profile cannot store quest chain progress or a banked chest")

    board_path = ROOT / "src/StarterPlayer/StarterPlayerScripts/UI/QuestBoard.lua"
    if not board_path.is_file():
        errors.append("QuestBoard UI module is missing")
    else:
        board_source = board_path.read_text(encoding="utf-8")
        for contract in ("function QuestBoard:SetOpen", "function QuestBoard:Update", "ClaimChainBonus"):
            if contract not in board_source:
                errors.append(f"Quest board is missing a control it must offer: {contract}")
        # Both the collapsed control and opened reading panel stay top-left.
        for contract in (
            "AnchorPoint = Vector2.new(0, 0)",
            "QuestBoardLayout.open",
            "QuestBoardLayout.closed",
        ):
            if contract not in board_source:
                errors.append(f"Quest board responsive top-left layout is missing: {contract}")
    if "QuestBoard.new" not in client_source:
        errors.append("Client does not create the quest board")
    if "questPill" in client_source:
        errors.append("The old quest banner is back; quests belong in the responsive Quest board")

    # The Robux shop. scripts/shop_test.py proves receipts pay out exactly once.
    shop_path = ROOT / "src/ServerScriptService/Services/ShopService.lua"
    if not shop_path.is_file():
        errors.append("ShopService is missing, so the game cannot take Robux")
    else:
        shop_source = shop_path.read_text(encoding="utf-8")
        for contract in ("MarketplaceService.ProcessReceipt", "data.Shop.Receipts[receiptKey]", "IsPersistent"):
            if contract not in shop_source:
                errors.append(f"ShopService is missing a purchase safeguard: {contract}")
        # Money must never buy quest progress.
        for forbidden in ("Quests", "PendingBonus", "ChainIndex"):
            if forbidden in shop_source:
                errors.append(f"ShopService touches quest progress ({forbidden}): quests must be earned, not bought")
    if "Config.Monetization" not in config_source and "Monetization" not in config_source:
        errors.append("Config.Monetization is missing, so product ids cannot be set")
    if "ShopService.new" not in (ROOT / "src/ServerScriptService/Server.server.lua").read_text(encoding="utf-8"):
        errors.append("ShopService is never started, so no purchase would ever be processed")

    world_methods = quoted_values(world_source, r"function\s+WorldService:([A-Za-z_]+)\s*\(")
    game_world_calls = quoted_values(game_source, r"self\._world:([A-Za-z_]+)\s*\(")
    for method in sorted(game_world_calls - world_methods):
        errors.append(f"GameService calls missing WorldService method: {method}")

    game_methods = quoted_values(game_source, r"function\s+GameService:([A-Za-z_]+)\s*\(")
    game_self_calls = quoted_values(game_source, r"self:([A-Za-z_]+)\s*\(")
    for method in sorted(game_self_calls - game_methods):
        errors.append(f"GameService calls undefined method: {method}")

    world_self_calls = quoted_values(world_source, r"self:([A-Za-z_]+)\s*\(")
    for method in sorted(world_self_calls - world_methods):
        errors.append(f"WorldService calls undefined method: {method}")

    adventure_profile_fields = {
        "CampLevel", "Resources", "OwnedCompanions", "ActiveCompanion", "Discoveries",
        "PuzzleStep", "LastPuzzleAt", "PuzzlesSolved", "ItemsCollected", "BuildsCompleted",
        "ItemsShared",
    }
    for field in sorted(adventure_profile_fields):
        if re.search(rf"\b{field}\s*=", data_source) is None:
            errors.append(f"Adventure profile field is missing: {field}")

    if errors:
        print("Validation failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    lua_count = len(list((ROOT / "src").rglob("*.lua")))
    print(f"Validation passed: project JSON, {lua_count} Luau files, action contracts, and destinations.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
