local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WildwoodStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildwoodStyle"))

local Config = {
	DataStoreName = "CuteFamilyTown_v1",
	DataVersion = 2,
	AutoSaveSeconds = 60,
	StartingCoins = 500,
	StartingSeeds = 5,
	MaxFurniture = 40,
	InteractionDistance = 18,
	CafeUnlockCost = 300,
	CafeServeCooldown = 6,
	CafeServeReward = 35,
	DailyBaseReward = 75,
	DailyStreakBonus = 15,
	QuestReward = 120,
	GardenSlots = 4,
	HomeCount = 8,
	-- Pet geometry is authored against a five-stud Roblox character. The world
	-- also measures each spawned avatar, so scaled R6/R15 bodies keep this ratio.
	CharacterReferenceHeight = 5,
	PetHeightRatio = 0.25,
	RequestCooldown = 0.12,
	-- Map travel is a physical town service: players must stand at the central
	-- Adventure Guild before the server accepts a destination request.
	AdventureGuildCenter = Vector3.new(0, 4, 0),
	AdventureGuildTravelRadius = 24,
	AdventureCollectCooldown = 8,
	AdventurePuzzleReward = 150,
	-- World labels are readable up close and fade out as you walk away, so the
	-- town is not a wall of floating text when you look across it.
	LabelScale = 0.6,
	LabelNearDistance = 70,
	LabelFarDistance = 120,
}

--[[
	Furniture placement, in studs, local to the player's house.

	Approved house design A is a broad 28 x 20 stud porch-gable cottage. The
	one-stud walls leave a generous but safe furnishing area inside the shell.
	Furniture stays inset from the walls so even large pieces never clip outside.

	DoorClear is the strip in front of the door. Nothing may sit there, because a
	house filled to the cap would otherwise wall the player out of their own home.
]]
Config.Furniture = {
	Interior = { MinX = -13, MaxX = 13, MinZ = -9, MaxZ = 9 },
	DoorClear = { MinX = -4, MaxX = 4, MinZ = -10, MaxZ = -6 },
	-- Garden pieces go on the lawn in front of the porch, clear of the mailbox,
	-- the garden patches and the camp.
	Yard = { MinX = -20, MaxX = 20, MinZ = -36, MaxZ = -21 },
}

Config.Bag = {
	StartingSlots = 20,
	StackSize = 10,
	SlotsPerUpgrade = 5,
	MaxSlots = 60,
	FirstUpgradeCost = 500,
	UpgradeCostIncrease = 250,
}

--[[
	Robux.

	Roblox has no API that pays Robux out to players, so nothing here pretends to.
	What this does is let the game EARN Robux: players spend Robux on coin packs
	and on a cosmetic supporter pass, and that revenue is yours.

	The ids below are 0, which keeps the shop hidden entirely. Create the products
	in the Creator Dashboard (Monetization > Developer Products / Passes) and paste
	their ids here; the shop appears on the quest board the moment one is set.

	The supporter pass is deliberately cosmetic. Coin packs buy furniture and
	seeds, never quest progress, so no chest and no chain can be bought.
]]
Config.Monetization = {
	CoinPacks = {
		{ ProductId = 0, Coins = 1200, Robux = 25, Name = "Pouch of Coins", NameThai = "ถุงเหรียญ" },
		{ ProductId = 0, Coins = 5500, Robux = 100, Name = "Chest of Coins", NameThai = "หีบเหรียญ" },
		{ ProductId = 0, Coins = 13000, Robux = 200, Name = "Cart of Coins", NameThai = "รถเข็นเหรียญ" },
	},
	-- Cosmetic only: a golden lantern over your head and a star on your name.
	SupporterPassId = 0,
	SupporterName = "Golden Lantern",
	SupporterNameThai = "โคมไฟทองคำ",
	SupporterRobux = 149,
}

-- Approved A — Bakery Bay roles shared by every world-building system.
Config.VillagePalette = WildwoodStyle.World

-- Roof pitch and how far the eaves overhang the walls, in studs.
Config.RoofPitch = 0.8
Config.RoofOverhang = 3
Config.MaxRoofRise = 16

Config.Environment = {
	Sunrise = 6,
	Sunset = 18,
	UpdateSeconds = 20,
}

Config.AdventurePalette = {
	ForestGreen = WildwoodStyle.World.Foliage,
	WoodBrown = WildwoodStyle.World.TimberWarm,
	WarmBeige = WildwoodStyle.World.Plaster,
	SunsetOrange = WildwoodStyle.World.Terracotta,
	SoftYellow = WildwoodStyle.World.Window,
	RiverBlue = WildwoodStyle.World.ClearWater,
}

-- Direct-select cottage swatches resampled from approved Bakery Bay concept A.
Config.HomeColors = {
	{ Name = "Brown", DisplayName = "Deep Timber", NameThai = "ไม้เงาลึก", Hex = "#1D1108", Color = WildwoodStyle.World.TimberDeep },
	{ Name = "Hickory", DisplayName = "Dark Timber", NameThai = "ไม้โครงเข้ม", Hex = "#2A1F14", Color = WildwoodStyle.World.TimberDark },
	{ Name = "Mocha", DisplayName = "Wall Wood", NameThai = "ไม้ผนัง", Hex = "#452C17", Color = WildwoodStyle.World.TimberMid },
	{ Name = "Coffee", DisplayName = "Warm Wood", NameThai = "ไม้โทนอุ่น", Hex = "#593A20", Color = WildwoodStyle.World.TimberWarm },
	{ Name = "Peanut", DisplayName = "Highlight Wood", NameThai = "ไม้ไฮไลต์", Hex = "#93673F", Color = WildwoodStyle.World.TimberLight },
}
-- Warm Wood is the balanced default between deep beams and light trim.
Config.DefaultHomeColor = "Coffee"

Config.Waypoints = {
	-- Adventure Guild anchors an organic village loop. Market Lane sits to the
	-- west, Family Lane to the east, and the park/lake form the quiet north end.
	Town = Vector3.new(0, 4, 28),
	Cafe = Vector3.new(-78, 4, -62),
	PetShop = Vector3.new(78, 4, -62),
	FlowerShop = Vector3.new(-96, 4, 22),
	Playground = Vector3.new(94, 4, 26),
	School = Vector3.new(0, 4, -126),
	Park = Vector3.new(0, 4, 116),
	Lake = Vector3.new(0, 4, 174),
	Beach = Vector3.new(235, 4, 20),
	Forest = Vector3.new(-235, 4, 45),
	AdventureCamp = Vector3.new(0, 4, 325),
	WildwoodForest = Vector3.new(-185, 4, 430),
	Mountain = Vector3.new(0, 40, 510),
	RiverAdventure = Vector3.new(185, 4, 430),
	MysteryCave = Vector3.new(0, 4, 570),
}

return table.freeze(Config)
