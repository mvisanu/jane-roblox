local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WildwoodStyle = require(Shared:WaitForChild("WildwoodStyle"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local BagInventory = require(Shared:WaitForChild("BagInventory"))
local CafeMenu = require(Shared:WaitForChild("CafeMenu"))
local CafeModels = require(Shared:WaitForChild("CafeModels"))
local Config = require(Shared:WaitForChild("Config"))
local EnvironmentClock = require(Shared:WaitForChild("EnvironmentClock"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local QuestGuide = require(Shared:WaitForChild("QuestGuide"))
local QuestBoardLayout = require(Shared:WaitForChild("QuestBoardLayout"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

assert(Config.DataVersion == 2, "Adventure data version was not applied")
assert(Config.Bag.StartingSlots == 20, "A new bag must start with 20 slots")
assert(Config.Bag.StackSize == 10, "Bag stack size drifted")
assert(BagInventory.nextUpgrade(20).Slots == 25, "The first bag expansion must add five slots")
assert(BagInventory.nextUpgrade(20).Cost == 500, "The first bag expansion price drifted")
local activityWidth, activityHeight = HudLayout.panelSize(1450, 805)
local activityX, activityY = HudLayout.center(1450, 805, activityWidth, activityHeight)
assert(activityWidth == 680 and activityHeight == 579, "Activity panel size drifted on the reference viewport")
assert(activityX == 385 and activityY == 103, "Activity panel is not centred on the reference viewport")
assert(HudLayout.TITLE_TEXT_SIZE >= 20, "Activity panel title is too small")
assert(HudLayout.HEADING_TEXT_SIZE >= 17, "Activity panel headings are too small")
assert(HudLayout.BODY_TEXT_SIZE >= 15 and HudLayout.CONTROL_TEXT_SIZE >= 15, "Activity panel copy is too small")
local referenceQuestMenu = QuestBoardLayout.open(1868, 1186)
assert(referenceQuestMenu.X == 16 and referenceQuestMenu.Y == 82, "Quest menu is not fixed at the upper-left")
assert(referenceQuestMenu.Width == 620 and referenceQuestMenu.Height == 620, "Quest menu did not keep its previous desktop size")
assert(QuestBoardLayout.insideScreen(1868, 1186, referenceQuestMenu), "Upper-left Quest menu leaves the reference viewport")
local hiddenQuestMenu = QuestBoardLayout.closed(1868, 1186)
assert(hiddenQuestMenu.X == referenceQuestMenu.X and hiddenQuestMenu.Y == referenceQuestMenu.Y, "Hiding Quest menu moves its header")

local UI = StarterPlayer.StarterPlayerScripts:WaitForChild("UI")
local QuestBoard = require(UI:WaitForChild("QuestBoard"))
local BagGrid = require(UI:WaitForChild("BagGrid"))
local Components = require(UI:WaitForChild("Components"))
local Theme = require(UI:WaitForChild("Theme"))
assert(Theme.Colors.Primary == WildwoodStyle.Colors.ForestGreen, "UI is not using the supplied Wildwood green")
assert(Theme.FontNames.Headline == "Plus Jakarta Sans" and Theme.FontNames.Body == "Quicksand", "Supplied font roles are missing")
local questProbeParent = Instance.new("Frame")
questProbeParent.Size = UDim2.fromOffset(1868, 1186)
local questProbe = QuestBoard.new(questProbeParent, Theme, Components, Catalog, Config, function(english, thai)
	return string.format("%s\n%s", thai, english)
end, function() end, function() end)
assert(questProbe._panel.AnchorPoint == Vector2.new(0, 0), "Quest menu panel is not upper-left anchored")
assert(questProbe._title.TextSize >= 15, "Quest menu heading is too small")
assert(questProbe._body.ScrollBarThickness >= 7, "Quest menu scroll bar is too narrow")
questProbe:SetOpen(true)
assert(questProbe._body.Visible, "Quest menu body did not open")
questProbe:SetOpen(false)
assert(not questProbe._body.Visible and questProbe._toggle.Text:find("OPEN"), "Quest menu body cannot be hidden")
questProbeParent:Destroy()
local bagHolder = Instance.new("Frame")
local bagGrid = BagGrid.create(bagHolder, { Wood = 12, Crystal = 1 }, 20, Theme, Components, function(english, thai)
	return string.format("%s\n%s", thai, english)
end)
assert(bagGrid:FindFirstChildOfClass("UIGridLayout"), "Bag is not rendered with a grid layout")
local bagCells = 0
for _, child in ipairs(bagGrid:GetChildren()) do
	if child:IsA("Frame") then
		bagCells += 1
	end
end
assert(bagCells == 20, string.format("Starter bag rendered %d cells instead of 20", bagCells))
assert(bagGrid:FindFirstChild("BagSlot01_Wood"), "Material stack is missing from the first bag cell")
assert(bagGrid:FindFirstChild("BagSlot03_Crystal"), "Rare crystal stack is missing from the bag grid")
assert(bagGrid.BagSlot01_Wood.ItemName.TextSize >= 12, "Bag item names are too small")
assert(bagGrid.BagSlot01_Wood.StackCount.TextSize >= 13, "Bag stack counts are too small")
assert(Config.Waypoints.MysteryCave, "Mystery Cave waypoint is missing")
assert(#Catalog.CampLevels == 6, "Expected six camp progression stages")
assert(Catalog.Companions.Fox and Catalog.Companions.Owl and Catalog.Companions.Dog and Catalog.Companions.Rabbit, "Adventure companions are incomplete")
assert(Catalog.QuestlineVersion == 2, "The rewritten quest journal version is missing")
assert(#Catalog.QuestChains == 8, "Expected eight continuous story chapters")
local storyStepCount = 0
for _, chapter in ipairs(Catalog.QuestChains) do
	storyStepCount += #chapter.Steps
end
assert(storyStepCount == 41, "Expected 41 authored story steps")
assert(Catalog.QuestChains[1].Steps[1].Action == "FinishOnboarding", "The story must begin at the welcome card")
local finaleSteps = Catalog.QuestChains[#Catalog.QuestChains].Steps
assert(finaleSteps[#finaleSteps].Action == "CafeServeMoonBerryTart", "The story must end at the Moon Berry Tart celebration")
for _, action in ipairs({ "CafeServeMoonBerryTart", "AdventureWood", "AdventureHerbs", "AdventureStone", "AdventureFish" }) do
	assert(QuestGuide.get(action), string.format("Story action has no route: %s", action))
end

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "SmokeRemotes"
remoteFolder.Parent = ReplicatedStorage

local remotes = {}
for _, name in ipairs({ "StateChanged", "Toast" }) do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remoteFolder
	remotes[name] = event
end
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = remoteFolder
remotes.Request = request

local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local GameService = require(Services:WaitForChild("GameService"))

local dataService = DataService.new()
local worldService = WorldService.new(remotes)
local gameService = GameService.new(dataService, worldService, remotes)
worldService:SetActionHandler(function(player, action, payload)
	return gameService:Handle(player, action, payload)
end)

local world = workspace:FindFirstChild("CuteFamilyTown")
assert(world, "Generated town is missing")
local wildwoodTrees, carvedSigns, mossyStones, stringBulbs = 0, 0, 0, 0
for _, descendant in ipairs(world:GetDescendants()) do
	if descendant:GetAttribute("WildwoodTree") then
		wildwoodTrees += 1
	end
	if descendant:GetAttribute("WildwoodCarvedSign") then
		carvedSigns += 1
	end
	if descendant:GetAttribute("MossyPathTile") then
		mossyStones += 1
	end
	if descendant.Name == "StringLightBulb" then
		stringBulbs += 1
	end
end
assert(wildwoodTrees >= 30, string.format("Only %d supplied-style tiered pines were generated", wildwoodTrees))
assert(carvedSigns >= 9, string.format("Only %d carved Wildwood signs were generated", carvedSigns))
assert(mossyStones >= 40, string.format("Only %d mossy path stones were generated", mossyStones))
assert(stringBulbs >= 36, string.format("Only %d plaza string-light bulbs were generated", stringBulbs))
assert(world:FindFirstChild("WildwoodAdventure"), "Wildwood adventure region is missing")
assert(world.WildwoodAdventure:FindFirstChild("AdventureCamp"), "Shared adventure camp is missing")
assert(world.WildwoodAdventure:FindFirstChild("WildwoodForest"), "Wildwood Forest is missing")
assert(world.WildwoodAdventure:FindFirstChild("SunriseMountain"), "Mountain is missing")
assert(world.WildwoodAdventure:FindFirstChild("RiverAndLake"), "River and lake are missing")
assert(world.WildwoodAdventure:FindFirstChild("MysteryCave"), "Mystery Cave is missing")

-- Every visible world part comes from an approved source of truth: Bakery Bay
-- for architecture/landscape and Woodland Canopy for placed furniture.
-- Characters, pets and the transparent TownSpawn marker remain separate.
local bakeryBayRoles = {
	"TimberDeep", "TimberDark", "TimberMid", "TimberWarm", "TimberLight",
	"RoofShadow", "RoofTile", "RoofHighlight",
	"StoneDeep", "Stone", "StoneLight", "Cobble",
	"Plaster", "CanvasLight", "Terracotta",
	"FoliageDeep", "Foliage", "Grass", "FoliageLight", "Soil",
	"Water", "WaterLight", "Window", "Lantern", "Glass", "Flower",
	"DaySky", "DayFog", "NightSky",
}
local function colorKey(color)
	return string.format(
		"%d,%d,%d",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end
local approvedWorldColors = {}
for _, role in ipairs(bakeryBayRoles) do
	approvedWorldColors[colorKey(WildwoodStyle.World[role])] = true
end
local woodlandCanopyRoles = {
	"PineNeedle", "ForestFern", "WoodlandMoss", "PaleLichen",
	"Eucalyptus", "RiverSlate", "Mushroom", "ReedLinen",
	"Goldenrod", "YarrowCream", "FoxgloveBerry", "TimberTrim",
}
local approvedFurnitureColors = {}
for _, role in ipairs(woodlandCanopyRoles) do
	approvedFurnitureColors[colorKey(WildwoodStyle.Furniture[role])] = true
end
for _, descendant in ipairs(world:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.Name ~= "TownSpawn" then
		local belongsToPet = descendant:IsDescendantOf(world.Pets)
		local belongsToCharacter = false
		local belongsToFurniture = false
		local ancestor = descendant.Parent
		while ancestor and ancestor ~= world do
			if ancestor.Name == "PlacedFurniture" then
				belongsToFurniture = true
			end
			if ancestor:IsA("Model") and (ancestor.Name == "CafeGuest" or ancestor:FindFirstChildOfClass("Humanoid")) then
				belongsToCharacter = true
				break
			end
			ancestor = ancestor.Parent
		end
		if not belongsToPet and not belongsToCharacter then
			local allowed = belongsToFurniture and approvedFurnitureColors or approvedWorldColors
			assert(
				allowed[colorKey(descendant.Color)],
				string.format("World part uses a colour outside its approved palette: %s (%s)", descendant:GetFullName(), colorKey(descendant.Color))
			)
		end
	end
end

local home = world.PlayerHomes:FindFirstChild("Home01")
assert(home, "Starter home is missing")
assert(home:FindFirstChild("InteriorSpawn"), "Home interior spawn is missing")
assert(home:FindFirstChild("Door") and not home.Door.CanCollide, "Home door must remain passable")

local cave = world.WildwoodAdventure.MysteryCave
for _, runeName in ipairs({ "LeafRune", "RiverRune", "SunRune" }) do
	assert(cave:FindFirstChild(runeName), string.format("Missing cave rune: %s", runeName))
end

-- Every home and building must be enterable. scripts/walkability_test.py proves
-- a character can actually walk the route offline; this repeats the load-bearing
-- half of that check against real Roblox collision, which is the source of truth.
local enterable = {}
for _, model in ipairs(world:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("Enterable") then
		table.insert(enterable, model)
	end
end

assert(#enterable >= 13, string.format("Expected at least 13 enterable structures, found %d", #enterable))

for _, model in ipairs(enterable) do
	local doorway = model:FindFirstChild("DoorwayVolume")
	local interior = model:FindFirstChild("InteriorMarker")
	assert(doorway, string.format("%s has no doorway", model.Name))
	assert(interior, string.format("%s has no interior marker", model.Name))
	assert(not doorway.CanCollide, string.format("%s doorway marker must not collide", model.Name))

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { doorway, interior }
	for _, hit in ipairs(workspace:GetPartBoundsInBox(doorway.CFrame, doorway.Size, params)) do
		assert(
			not hit.CanCollide,
			string.format("%s doorway is blocked by a solid part: %s", model.Name, hit:GetFullName())
		)
	end
end

-- Sunrise Mountain must be climbable on foot, not just by map travel.
local sunrise = world.WildwoodAdventure.SunriseMountain
assert(sunrise:GetAttribute("Climbable"), "Sunrise Mountain is not marked climbable")
assert(sunrise:FindFirstChild("SummitMarker"), "Sunrise Mountain has no summit marker")
local stairCount = 0
for _, child in ipairs(sunrise:GetChildren()) do
	if child.Name == "MountainStair" then
		stairCount += 1
	end
end
assert(stairCount >= 30, string.format("Expected stairs up all five terraces, found %d steps", stairCount))

for _, buildingName in ipairs({ "FamilyCafe", "PetShop", "FlowerShop", "LittleSchool" }) do
	local building = world.Town:FindFirstChild(buildingName)
	assert(building, string.format("Missing town building: %s", buildingName))
	assert(building:GetAttribute("Enterable"), string.format("%s is not enterable", buildingName))
	assert(not building:FindFirstChild("Body"), string.format("%s is still a solid block", buildingName))
end

-- Cafe food must be distinct, detailed 3D models rather than flat artwork or
-- the old generic cylinder/ball stand-ins.
local cafe = world.Town.FamilyCafe
assert(cafe:GetAttribute("ExteriorStyle") == "Bakery Bay", "Cafe is not using the approved Bakery Bay exterior")
assert(cafe:GetAttribute("InteriorStyle") == "Bakery Bay", "Cafe is not using the approved Bakery Bay interior")
assert(cafe:GetAttribute("StructureVersion") == "Bakery Bay Full Rebuild", "Cafe is not the full Bakery Bay rebuild")
for _, exteriorPart in ipairs({
	"RoofPlane",
	"BakeryDormerWindow",
	"BakeryCupolaRoof",
	"BakeryOpenServiceBay",
	"BakeryOpenSideBay",
	"BakerySideCounter",
	"BakerySideAwning",
	"BakeryDisplayWindow",
	"BakeryDisplayWingFoundation",
	"BakeryDisplaySideGlass",
	"BakeryStreetCounter",
	"BakeryCanvasAwning",
	"BakeryBaySign",
	"BakeryMoonBreadSign",
	"BakeryCrescentOuter",
	"BakeryBreadLoaf",
	"BakerySidewalkMenu",
	"BakeryCoffeeCup",
	"BakeryCoffeeCupBody",
	"BakeryCoffeeCupHandle",
	"BakeryCoffeeSteam",
	"BakerySidewalkSignLeg",
	"BakerySidewalkSignFoot",
	"HandCoffeeGrinderBody",
	"BakeryOakBarrelPlanter",
}) do
	assert(cafe:FindFirstChild(exteriorPart), string.format("Bakery Bay is missing %s", exteriorPart))
end

local cafeDoorway = cafe:FindFirstChild("DoorwayVolume")
for _, child in ipairs(cafe:GetChildren()) do
	if child:IsA("BasePart") and (child.Name == "WallRail" or child.Name == "WallBrace") then
		local localPosition = cafeDoorway.CFrame:PointToObjectSpace(child.Position)
		assert(
			not (localPosition.Z > -2 and localPosition.Z < 2 and child.Position.Y > 4 and child.Position.Y < 12),
			string.format("%s still crosses a front cafe window", child.Name)
		)
	end
end
local cafeSteps = {}
for _, child in ipairs(cafe:GetChildren()) do
	if child.Name == "BakeryDoorStep" then
		table.insert(cafeSteps, child)
	end
end
table.sort(cafeSteps, function(left, right)
	return cafeDoorway.CFrame:PointToObjectSpace(left.Position).Z > cafeDoorway.CFrame:PointToObjectSpace(right.Position).Z
end)
assert(#cafeSteps == 3, "Bakery door stairs are incomplete")
assert(cafeSteps[1].Position.Y > cafeSteps[2].Position.Y and cafeSteps[2].Position.Y > cafeSteps[3].Position.Y, "Bakery door stairs run backwards")
local townGround = world:FindFirstChild("Ground")
assert(townGround and townGround:IsA("BasePart"), "Town ground is missing")
local groundTop = townGround.Position.Y + townGround.Size.Y / 2
local lowestStepBottom = cafeSteps[3].Position.Y - cafeSteps[3].Size.Y / 2
assert(math.abs(lowestStepBottom - groundTop) <= 0.05, "Lowest bakery step is floating above the grass")
local bakerySign = cafe:FindFirstChild("BakeryBaySign")
local signLocal = cafeDoorway.CFrame:PointToObjectSpace(bakerySign.Position)
assert(bakerySign.Size.X <= 12 and bakerySign.Size.Y <= 2.8, "Main bakery sign is still too large")
assert(signLocal.X > 5, "Main bakery sign is not over the screen-left awning")
assert(signLocal.Z < -4, "Main bakery sign is still behind the roof overhang")
local awningTop = -math.huge
for _, child in ipairs(cafe:GetChildren()) do
	if child.Name == "BakeryCanvasAwning" then
		awningTop = math.max(awningTop, child.Position.Y)
	end
end
assert(bakerySign.Position.Y - bakerySign.Size.Y / 2 > awningTop, "Main bakery sign is not above the striped awning")
local sidewalkMenu = cafe:FindFirstChild("BakerySidewalkMenu")
local sidewalkBack = cafe:FindFirstChild("BakerySidewalkMenuBack")
local coffeeCup = cafe:FindFirstChild("BakeryCoffeeCup")
assert(sidewalkMenu.CFrame.ZVector:Dot(cafeDoorway.CFrame.ZVector) < -0.9, "Bakery sidewalk menu was not rotated")
local menuZ = cafeDoorway.CFrame:PointToObjectSpace(sidewalkMenu.Position).Z
local backZ = cafeDoorway.CFrame:PointToObjectSpace(sidewalkBack.Position).Z
local cupZ = cafeDoorway.CFrame:PointToObjectSpace(coffeeCup.Position).Z
assert(cupZ < menuZ and menuZ < backZ, "Coffee art is not on the street-facing menu board")
local menuTop = sidewalkMenu.Position + sidewalkMenu.CFrame.YVector * sidewalkMenu.Size.Y / 2
local backTop = sidewalkBack.Position + sidewalkBack.CFrame.YVector * sidewalkBack.Size.Y / 2
assert((menuTop - backTop).Magnitude <= 0.05, "Bakery menu boards do not share a top hinge")
assert(math.abs(sidewalkMenu.CFrame.ZVector.Y) >= 0.18, "Bakery menu face is not pitched from its top hinge")
local menuFeet = 0
local coffeeBodies = 0
local coffeeHandles = 0
local coffeeSteam = 0
for _, child in ipairs(cafe:GetChildren()) do
	if child.Name == "BakerySidewalkSignFoot" then
		menuFeet += 1
		assert(math.abs((child.Position.Y - child.Size.Y / 2) - groundTop) <= 0.05, "Bakery menu foot floats above the grass")
	elseif child.Name == "BakeryCoffeeCupBody" then
		coffeeBodies += 1
	elseif child.Name == "BakeryCoffeeCupHandle" then
		coffeeHandles += 1
	elseif child.Name == "BakeryCoffeeSteam" then
		coffeeSteam += 1
	end
end
assert(menuFeet == 4, "Bakery menu A-frame feet are incomplete")
assert(coffeeBodies == 2 and coffeeHandles == 3 and coffeeSteam == 6, "Bakery menu coffee emblem is incomplete")
assert(not sidewalkMenu:FindFirstChild("BakeryMenuLettering"), "Lettering still appears behind the bakery coffee emblem")
assert(not sidewalkBack:FindFirstChild("CarvedLettering"), "The back of the bakery menu still contains lettering")
assert(not cafe:FindFirstChild("BakeryArchedDoor") and not cafe:FindFirstChild("BakeryDoorWindow"), "Bakery entrance still has a door panel")
for _, interiorPart in ipairs({
	"BakeryInteriorFloor",
	"BakeryCeilingBeam",
	"BakeryPendantGlow",
	"BakeryCounterFront",
	"BakeryInteriorMenu",
	"BakeryBackShelf",
	"BakeryDiningTable",
}) do
	assert(cafe:FindFirstChild(interiorPart), string.format("Bakery Bay interior is missing %s", interiorPart))
end
for _, legacyPart in ipairs({ "BalconyDeck", "BannerCloth", "CounterPanel", "MoonKettle", "TeaWisp", "FireflyOrb", "EnchantedMenu", "CafeTable", "TakeawayServiceHatch" }) do
	assert(not cafe:FindFirstChild(legacyPart), string.format("Legacy cafe part still exists: %s", legacyPart))
end
assert(not world.Town.PetShop:FindFirstChild("BakeryDisplayWindow"), "Bakery facade leaked into Pet Shop")
assert(not world.Town.FlowerShop:FindFirstChild("BakeryOpenServiceBay"), "Bakery facade leaked into Flower Shop")
local display = cafe:FindFirstChild("CafeFood3DDisplay")
assert(display, "Cafe 3D display is missing")
local modelCount = 0
local seenItems = {}
local geometryKinds = {}
for _, model in ipairs(display:GetChildren()) do
	if CollectionService:HasTag(model, CafeModels.Tag) then
		modelCount += 1
		assert(model:IsA("Model"), "Tagged cafe food is not a Model")
		assert(model:GetAttribute("CafeFood3D") == true, "Cafe model is not marked as 3D food")
		local itemId = model:GetAttribute("CafeItemId")
		assert(CafeMenu.get(itemId), string.format("Cafe model has unknown item id: %s", tostring(itemId)))
		assert(not seenItems[itemId], string.format("Duplicate cafe model: %s", itemId))
		seenItems[itemId] = true
		local geometryKind = model:GetAttribute("GeometryKind")
		assert(type(geometryKind) == "string" and geometryKind ~= "", string.format("%s has no geometry kind", itemId))
		assert(not geometryKinds[geometryKind], string.format("Cafe foods share generic geometry kind: %s", geometryKind))
		geometryKinds[geometryKind] = true

		local solidParts = 0
		local hasCylinder = false
		local hasBall = false
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				solidParts += 1
				assert(descendant.Anchored and not descendant.CanCollide, string.format("%s geometry is unsafe", descendant:GetFullName()))
				assert(descendant.Size.X > 0 and descendant.Size.Y > 0 and descendant.Size.Z > 0, string.format("%s has zero-volume geometry", descendant:GetFullName()))
				if descendant:IsA("Part") and descendant.Shape == Enum.PartType.Cylinder then
					hasCylinder = true
				elseif descendant:IsA("Part") and descendant.Shape == Enum.PartType.Ball then
					hasBall = true
				end
			elseif descendant:IsA("ImageLabel") then
				error(string.format("Flat image found inside 3D cafe model: %s", descendant:GetFullName()))
			end
		end
		assert(solidParts >= 10, string.format("%s is too simple to be a detailed 3D model (%d parts)", itemId, solidParts))
		assert(hasCylinder and hasBall, string.format("%s lacks varied 3D geometry", itemId))
		local _, bounds = model:GetBoundingBox()
		assert(bounds.X > 0.5 and bounds.Y > 0.5 and bounds.Z > 0.5, string.format("%s does not have visible 3D volume", itemId))
	end
end
assert(modelCount == #CafeMenu.Order, string.format("Expected %d cafe 3D models, found %d", #CafeMenu.Order, modelCount))
for _, itemId in ipairs(CafeMenu.Order) do
	assert(seenItems[itemId], string.format("Missing 3D cafe model: %s", itemId))
end
for _, oldPlaceholder in ipairs({ "GoldenCrust", "GlowingMoonBerry", "StarCookie", "MoonberryPastry" }) do
	assert(not cafe:FindFirstChild(oldPlaceholder, true), string.format("Primitive cafe placeholder remains: %s", oldPlaceholder))
end

-- The companion used to be roughly player-sized. Build the real model and let
-- Roblox calculate its bounds: it must now be exactly one quarter of the
-- standard character height, not merely carry a scale constant in source.
local petProbe = Instance.new("Folder")
petProbe.Name = "PetScaleProbe"
local scaledPet = worldService:_createPet(petProbe)
local _, petBounds = scaledPet:GetBoundingBox()
local expectedPetHeight = Config.CharacterReferenceHeight * Config.PetHeightRatio
assert(math.abs(petBounds.Y - expectedPetHeight) < 0.01, string.format(
	"Pet height %.3f is not one quarter of character height %.3f",
	petBounds.Y,
	Config.CharacterReferenceHeight
))
assert(scaledPet:GetAttribute("HeightRatio") == 0.25, "Pet model does not record the 1:4 ratio")
local mochiHead = scaledPet:FindFirstChild("CatHead")
local mochiLeftEar = scaledPet:FindFirstChild("CatEarLeft")
local mochiRightEar = scaledPet:FindFirstChild("CatEarRight")
local mochiTailTop = scaledPet:FindFirstChild("CatTailStep4")
local mochiNose = scaledPet:FindFirstChild("CatNose", true)
local mochiMouth = scaledPet:FindFirstChild("CatMouth", true)
assert(mochiHead and mochiHead.Color == Color3.fromRGB(17, 18, 20), "Mochi is not a black cat")
assert(scaledPet.PrimaryPart.Shape == Enum.PartType.Block, "Mochi's body is not Voxel block geometry")
assert(mochiHead.Shape == Enum.PartType.Block, "Mochi's head is not Voxel block geometry")
assert(mochiLeftEar and mochiLeftEar:IsA("WedgePart"), "Mochi's left ear is not triangular")
assert(mochiRightEar and mochiRightEar:IsA("WedgePart"), "Mochi's right ear is not triangular")
assert(mochiTailTop and mochiTailTop.Shape == Enum.PartType.Block, "Mochi's stepped Voxel tail is missing")
for _, detail in ipairs(scaledPet:GetDescendants()) do
	if detail:IsA("Part") and detail:GetAttribute("CompanionDetail") then
		assert(detail.Shape ~= Enum.PartType.Ball, string.format("Mochi still contains a round %s", detail.Name))
	end
end
assert(mochiNose and mochiNose.Text == "▼", "Mochi's nose is not a down-pointing triangle")
assert(mochiNose.TextColor3 == Color3.fromRGB(244, 188, 198), "Mochi's nose is not pale pink")
assert(mochiMouth and mochiMouth.Text == "ω", "Mochi does not have a cat-shaped mouth")
for species, expectedPart in pairs({ Cat = "CatHead", Fox = "FoxTailTip", Dog = "CurledTail1", Owl = "OwlEyeDisc", Rabbit = "CottonTail" }) do
	worldService:_buildCompanionGeometry(scaledPet, species, scaledPet:GetAttribute("PetScale"))
	assert(scaledPet:FindFirstChild(expectedPart), string.format("%s silhouette is missing %s", species, expectedPart))
	assert(scaledPet:GetAttribute("CompanionId") == species, string.format("%s identity was not applied", species))
end
scaledPet:Destroy()
worldService._pets[petProbe] = nil

local explorerProbe = Instance.new("Model")
explorerProbe.Name = "ExplorerStyleProbe"
local explorerTorso = Instance.new("Part")
explorerTorso.Name = "Torso"
explorerTorso.CFrame = CFrame.new(0, 3, 0)
explorerTorso.Parent = explorerProbe
explorerProbe.PrimaryPart = explorerTorso
local explorerHead = Instance.new("Part")
explorerHead.Name = "Head"
explorerHead.CFrame = CFrame.new(0, 4.5, 0)
explorerHead.Parent = explorerProbe
worldService:_styleExplorerCharacter(explorerProbe, Catalog.Outfits.MaleTrailRanger)
local explorerKit = explorerProbe:FindFirstChild("ApprovedWoodlandAvatar")
assert(explorerKit and explorerKit:GetAttribute("StandardBlockBody"), "Approved block avatar was not built")
assert(explorerKit:GetAttribute("Gender") == "Male", "Approved gender row was not recorded")
assert(explorerKit:FindFirstChild("BlockHead") and explorerKit:FindFirstChild("BlockTorso"), "Roblox block body was not replaced")
assert(explorerKit:FindFirstChild("TrailScarf") and explorerKit:FindFirstChild("TrailMapPouch"), "Trail Ranger identity was not built")
assert(not explorerKit:FindFirstChild("ExplorerBackpack"), "Legacy oversized backpack still exists")
explorerProbe:Destroy()

-- Every house has two automatic path lamps, plus eight lamps in the town. The
-- real client controller must switch both the light source and emissive globe.
local lampGlows = CollectionService:GetTagged(RemoteNames.LampTag)
assert(#lampGlows >= Config.HomeCount * 2 + 8, string.format("Expected at least 24 automatic lamps, found %d", #lampGlows))
local homeLampCounts = {}
for _, glow in ipairs(lampGlows) do
	assert(glow:IsA("BasePart") and glow:GetAttribute("NightLampGlow"), "Automatic lamp tag is on the wrong object")
	local lampModel = glow.Parent
	local homeIndex = lampModel and lampModel:GetAttribute("HomeIndex")
	if homeIndex then
		homeLampCounts[homeIndex] = (homeLampCounts[homeIndex] or 0) + 1
	end
end
for index = 1, Config.HomeCount do
	assert(homeLampCounts[index] == 2, string.format("Home %d has %s path lamps instead of 2", index, tostring(homeLampCounts[index])))
end

assert(EnvironmentClock.isDay(12) and not EnvironmentClock.isDay(0), "Day/night boundary is incorrect")
assert(EnvironmentClock.daylight(12) == 1 and EnvironmentClock.daylight(0) == 0, "Day/night intensity is incorrect")

local EnvironmentController = require(UI:WaitForChild("EnvironmentController"))
local environment = EnvironmentController.new()
local noonLight, noonNight = environment:ApplyAtHour(12)
local noonBrightness = game:GetService("Lighting").Brightness
assert(noonLight == 1 and not noonNight and game:GetService("Lighting").ClockTime == 12, "Noon environment did not apply")
for _, glow in ipairs(lampGlows) do
	assert(not glow.NightLight.Enabled, "Lamp stayed on during daylight")
end
local midnightLight, midnightNight = environment:ApplyAtHour(0)
assert(midnightLight == 0 and midnightNight and game:GetService("Lighting").ClockTime == 0, "Midnight environment did not apply")
assert(game:GetService("Lighting").Brightness < noonBrightness, "Night is not darker than day")
for _, glow in ipairs(lampGlows) do
	assert(glow.NightLight.Enabled, "Lamp did not switch on at night")
end
local actualLocalHour = environment:UpdateFromComputer()
local expectedLocal = EnvironmentClock.fromLocalDate(DateTime.now():ToLocalTime())
local timeDifference = math.abs(actualLocalHour - expectedLocal)
timeDifference = math.min(timeDifference, 24 - timeDifference)
assert(timeDifference < 0.05, string.format("Environment is not using computer-local time (difference %.3f hours)", timeDifference))
environment:Destroy()

-- Every active chain and daily quest has a valid physical destination.
for _, chain in ipairs(Catalog.QuestChains) do
	for _, step in ipairs(chain.Steps) do
		local guide = QuestGuide.get(step.Action)
		assert(guide, string.format("Quest action has no navigation guide: %s", step.Action))
		assert(guide.Target == "Home" or guide.Target == "HomeGarden" or Config.Waypoints[guide.Target], string.format("Quest guide target does not exist: %s", guide.Target))
	end
end
for _, dailyAction in ipairs({ "GardenHarvest", "Decorate", "CafeServe", "PetFeed" }) do
	assert(QuestGuide.get(dailyAction), string.format("Daily quest has no navigation guide: %s", dailyAction))
end

-- Build the actual navigator in the engine: a long line follows the ground to a
-- translucent destination light, and both vanish inside the arrival radius.
local Theme = require(UI:WaitForChild("Theme"))
local QuestNavigator = require(UI:WaitForChild("QuestNavigator"))
local navigationGui = Instance.new("ScreenGui")
navigationGui.Name = "SmokeNavigationGui"
navigationGui.Parent = game:GetService("StarterGui")
local navigator = QuestNavigator.new(navigationGui, Theme, Catalog, Config, function(english, thai)
	return string.format("%s / %s", thai, english)
end)
assert(navigator:Track("CafeServe", "Serve a guest", "Serve a guest"), "Navigator refused a mapped quest")
local distanceToCafe = navigator:UpdatePathFrom(Config.Waypoints.Town)
local navigationState = navigator:GetDebugState()
assert(distanceToCafe > 10, "Navigation test did not start far enough from the cafe")
assert(navigationState.GroundLineVisible and navigationState.TrailSegments >= 2, "Ground navigation line is missing")
assert(navigationState.WaypointVisible and navigationState.NavigationLightEnabled, "Translucent waypoint light is hidden before arrival")
assert(navigationState.WaypointTransparency >= 0.5 and navigationState.WaypointTransparency < 1, "Waypoint light is not semi-transparent")
assert((navigationState.Target - Config.Waypoints.Cafe).Magnitude < 0.01, "Quest waypoint points to the wrong place")
navigator:UpdatePathFrom(Config.Waypoints.Cafe)
local arrivedState = navigator:GetDebugState()
assert(arrivedState.Arrived, "Navigator did not recognize arrival")
assert(not arrivedState.GroundLineVisible and arrivedState.TrailSegments == 0, "Ground line stayed visible after arrival")
assert(not arrivedState.WaypointVisible and not arrivedState.NavigationLightEnabled, "Waypoint light stayed visible after arrival")
navigator:Destroy()
navigationGui:Destroy()

-- World labels: small, distance-culled, and tagged so the client can fade them
-- in as the player approaches and switch them off from the top bar.
assert(Config.LabelScale < 1, "Labels are not scaled down")
assert(Config.LabelNearDistance < Config.LabelFarDistance, "Label fade range is inverted")

local labelCount = 0
for _, descendant in ipairs(world:GetDescendants()) do
	if descendant:IsA("BillboardGui") and descendant.Name == "WorldLabel" then
		labelCount += 1
		assert(
			CollectionService:HasTag(descendant, RemoteNames.LabelTag),
			string.format("World label is untagged, so the client cannot hide it: %s", descendant:GetFullName())
		)
		assert(
			descendant.MaxDistance == Config.LabelFarDistance,
			string.format("World label is not distance-culled: %s", descendant:GetFullName())
		)
	end
end
assert(labelCount >= 20, string.format("Expected the town to be labelled, found %d labels", labelCount))

print(string.format(
	"STUDIO_SMOKE_OK: town, Wildwood, %d enterable structures, %d labels, %d cafe models, %d lamps, %d tiered pines, %d carved signs, %d mossy stones, 5 pets + explorer kit",
	#enterable,
	labelCount,
	modelCount,
	#lampGlows,
	wildwoodTrees,
	carvedSigns,
	mossyStones
))
