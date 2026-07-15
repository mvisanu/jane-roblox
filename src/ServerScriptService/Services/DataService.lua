local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local BagInventory = require(Shared:WaitForChild("BagInventory"))
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Furniture = require(Shared:WaitForChild("Furniture"))
local Placement = require(Shared:WaitForChild("Placement"))
local Progression = require(Shared:WaitForChild("Progression"))

local DataService = {}
DataService.__index = DataService

local function validHomePaint(name)
	for _, entry in ipairs(Config.HomeColors) do
		if entry.Name == name then
			return true
		end
	end
	return false
end

local function makeGardenSlots()
	local slots = {}
	for index = 1, Config.GardenSlots do
		slots[index] = {
			State = "Empty",
			Seed = "",
			PlantedAt = 0,
			Watered = false,
		}
	end
	return slots
end

local PROFILE_TEMPLATE = {
	Version = Config.DataVersion,
	Coins = Config.StartingCoins,
	-- XP earned inside the current level, not a lifetime total: see Progression.
	Level = 1,
	XP = 0,
	Home = {
		Paint = Config.DefaultHomeColor,
		-- Each entry is { Id, X, Z, R }: a grid position and a quarter turn.
		Furniture = {},
		OwnedFurniture = { Chair = 1 },
		Favorites = {},
	},
	Garden = {
		Seeds = { Daisy = Config.StartingSeeds, Tulip = 0, Lavender = 0 },
		Slots = makeGardenSlots(),
	},
	Pet = {
		Species = "Cat",
		Name = "Mochi",
		Level = 1,
		XP = 0,
		Hunger = 100,
		Cleanliness = 100,
		LastPlayedAt = 0,
	},
	Cafe = {
		Unlocked = false,
		Level = 1,
		Served = 0,
		Staff = 0,
		LastServedAt = 0,
	},
	Wardrobe = {
		Owned = {
			"MaleTrailRanger",
			"MaleRiverWarden",
			"MaleAutumnArcher",
			"FemaleWildflowerBotanist",
			"FemaleFernGuardian",
			"FemalePineScout",
		},
		-- Players enter as their own Roblox avatar. A preset is saved only after
		-- they deliberately choose one in Style.
		Equipped = "Original",
	},
	Daily = {
		LastClaimDay = -1,
		Streak = 0,
		Quest = {
			Day = -1,
			Action = "PetFeed",
			Description = "Feed your pet",
			DescriptionThai = "ให้อาหารสัตว์เลี้ยง",
			Progress = 0,
			Target = 3,
			Completed = false,
		},
	},
	Adventure = {
		BagSlots = Config.Bag.StartingSlots,
		CampLevel = 1,
		Resources = { Wood = 0, Stone = 0, Herbs = 0, Fish = 0, Crystal = 0 },
		OwnedCompanions = { "Cat" },
		ActiveCompanion = "Cat",
		Discoveries = {
			WildwoodForest = false,
			Mountain = false,
			RiverAdventure = false,
			MysteryCave = false,
		},
		PuzzleStep = 1,
		LastPuzzleAt = 0,
		PuzzlesSolved = 0,
		ItemsCollected = 0,
		ItemsShared = 0,
		BuildsCompleted = 0,
	},
	Stats = {
		FlowersHarvested = 0,
		CustomersServed = 0,
		FurniturePlaced = 0,
	},
	Settings = {
		Onboarded = false,
		ShowLabels = true,
	},
	Shop = {
		-- Receipt ids already granted. Roblox can deliver the same receipt more
		-- than once, so without this a player could be paid twice for one purchase.
		Receipts = {},
		RobuxSpent = 0,
		Supporter = false,
	},
	Quests = {
		Version = Catalog.QuestlineVersion,
		ChainIndex = 1,
		Step = 1,
		Progress = 0,
		-- Banked when a chain's last step lands. The player claims it by hand,
		-- because that press is the payoff the whole chain builds towards.
		PendingBonus = 0,
		ChainsCompleted = 0,
		TotalEarned = 0,
	},
}

local function sanitizeProfile(data)
	local storedQuestlineVersion = type(data.Quests) == "table" and tonumber(data.Quests.Version) or 1
	local storedBagSlots = type(data.Adventure) == "table" and tonumber(data.Adventure.BagSlots) or nil
	for _, section in ipairs({ "Home", "Garden", "Pet", "Cafe", "Wardrobe", "Daily", "Adventure", "Stats", "Settings", "Quests", "Shop" }) do
		if type(data[section]) ~= "table" then
			data[section] = Util.deepCopy(PROFILE_TEMPLATE[section])
		end
	end
	Util.reconcile(data, PROFILE_TEMPLATE)

	-- A rewritten journal starts at chapter one for everyone, while all of the
	-- world progress they already earned stays intact. Reopening onboarding is
	-- important because its final button is the first authored story action.
	if storedQuestlineVersion ~= Catalog.QuestlineVersion then
		data.Quests = Util.deepCopy(PROFILE_TEMPLATE.Quests)
		data.Settings.Onboarded = false
	end

	data.Coins = math.max(0, math.floor(tonumber(data.Coins) or Config.StartingCoins))
	-- Old paint ids are deliberately retired. Existing cottages move to the
	-- first approved swatch instead of keeping a hidden legacy colour.
	data.Home.Paint = validHomePaint(data.Home.Paint) and data.Home.Paint or Config.DefaultHomeColor
	if type(data.Home.Furniture) ~= "table" then
		data.Home.Furniture = {}
	end
	if type(data.Home.OwnedFurniture) ~= "table" then
		data.Home.OwnedFurniture = { Chair = 1 }
	end
	-- Rebuild the placed list. Entries from the old catalogue carried a Slot
	-- number instead of a position, so they are re-homed onto the grid here and
	-- nobody loses furniture they already own.
	local cleanFurniture = {}
	for _, entry in ipairs(data.Home.Furniture) do
		if #cleanFurniture >= Config.MaxFurniture then
			break
		end
		local itemId = type(entry) == "table" and Furniture.resolve(entry.Id)
		if itemId then
			local x = tonumber(entry.X)
			local z = tonumber(entry.Z)
			local rotation = Placement.normaliseRotation(entry.R)
			if x and z and Placement.canPlace(cleanFurniture, itemId, Placement.snap(x), Placement.snap(z), rotation) then
				table.insert(cleanFurniture, { Id = itemId, X = Placement.snap(x), Z = Placement.snap(z), R = rotation })
			else
				local freeX, freeZ, freeRotation = Placement.findFreeSpot(cleanFurniture, itemId)
				if freeX then
					table.insert(cleanFurniture, { Id = itemId, X = freeX, Z = freeZ, R = freeRotation })
				end
			end
		end
	end
	data.Home.Furniture = cleanFurniture

	local ownedFurniture = {}
	for itemId in pairs(Furniture.Items) do
		ownedFurniture[itemId] = 0
	end
	for itemId, count in pairs(data.Home.OwnedFurniture) do
		local resolved = Furniture.resolve(itemId)
		if resolved then
			ownedFurniture[resolved] = (ownedFurniture[resolved] or 0) + math.max(0, math.floor(tonumber(count) or 0))
		end
	end
	data.Home.OwnedFurniture = ownedFurniture
	data.Home.OwnedFurniture.Chair = math.max(1, data.Home.OwnedFurniture.Chair)

	-- Owning fewer than you have placed would let a player duplicate items.
	local placedCounts = {}
	for _, entry in ipairs(data.Home.Furniture) do
		placedCounts[entry.Id] = (placedCounts[entry.Id] or 0) + 1
	end
	for itemId, count in pairs(placedCounts) do
		data.Home.OwnedFurniture[itemId] = math.max(data.Home.OwnedFurniture[itemId], count)
	end

	if type(data.Home.Favorites) ~= "table" then
		data.Home.Favorites = {}
	end
	local favorites = {}
	for itemId, value in pairs(data.Home.Favorites) do
		local resolved = Furniture.resolve(itemId)
		if resolved and value == true then
			favorites[resolved] = true
		end
	end
	data.Home.Favorites = favorites

	data.Level = math.clamp(math.floor(tonumber(data.Level) or 1), 1, Progression.maxLevel())
	data.XP = math.max(0, math.floor(tonumber(data.XP) or 0))
	if not Progression.isMaxLevel(data.Level) and data.XP >= Progression.costForLevel(data.Level) then
		-- A profile that arrives holding more XP than its level allows is levelled
		-- up rather than left stuck below a bar that can never fill.
		data.Level, data.XP = Progression.addXP(data.Level, 0, data.XP)
	end

	if type(data.Garden.Seeds) ~= "table" then
		data.Garden.Seeds = {}
	end
	for seedId in pairs(Catalog.Seeds) do
		data.Garden.Seeds[seedId] = math.max(0, math.floor(tonumber(data.Garden.Seeds[seedId]) or 0))
	end
	if type(data.Garden.Slots) ~= "table" then
		data.Garden.Slots = makeGardenSlots()
	end
	for index = 1, Config.GardenSlots do
		local slot = data.Garden.Slots[index]
		if type(slot) ~= "table" or (slot.State ~= "Empty" and slot.State ~= "Planted") then
			data.Garden.Slots[index] = { State = "Empty", Seed = "", PlantedAt = 0, Watered = false }
		else
			slot.Seed = type(slot.Seed) == "string" and slot.Seed or ""
			slot.PlantedAt = math.max(0, math.floor(tonumber(slot.PlantedAt) or 0))
			slot.Watered = slot.Watered == true
			if slot.State == "Planted" and not Catalog.Seeds[slot.Seed] then
				data.Garden.Slots[index] = { State = "Empty", Seed = "", PlantedAt = 0, Watered = false }
			end
		end
	end

	data.Pet.Name = type(data.Pet.Name) == "string" and string.sub(data.Pet.Name, 1, 20) or "Mochi"
	data.Pet.Species = "Cat"
	data.Pet.Level = math.clamp(math.floor(tonumber(data.Pet.Level) or 1), 1, 100)
	data.Pet.XP = math.max(0, math.floor(tonumber(data.Pet.XP) or 0))
	data.Pet.Hunger = math.clamp(math.floor(tonumber(data.Pet.Hunger) or 100), 0, 100)
	data.Pet.Cleanliness = math.clamp(math.floor(tonumber(data.Pet.Cleanliness) or 100), 0, 100)
	data.Pet.LastPlayedAt = math.max(0, math.floor(tonumber(data.Pet.LastPlayedAt) or 0))

	data.Cafe.Unlocked = data.Cafe.Unlocked == true
	data.Cafe.Level = math.clamp(math.floor(tonumber(data.Cafe.Level) or 1), 1, 100)
	data.Cafe.Served = math.max(0, math.floor(tonumber(data.Cafe.Served) or 0))
	data.Cafe.Staff = math.clamp(math.floor(tonumber(data.Cafe.Staff) or 0), 0, 3)
	data.Cafe.LastServedAt = math.max(0, math.floor(tonumber(data.Cafe.LastServedAt) or 0))

	data.Wardrobe.Owned = Util.deepCopy(Catalog.OutfitOrder)
	local equippedOutfit = type(data.Wardrobe.Equipped) == "string" and Catalog.Outfits[data.Wardrobe.Equipped] or nil
	if data.Wardrobe.Equipped ~= "Original" and (not equippedOutfit or equippedOutfit.Style ~= data.Wardrobe.Equipped) then
		-- This also migrates every retired preset from the previous concept back
		-- to the player's untouched Roblox character.
		data.Wardrobe.Equipped = "Original"
	end

	if type(data.Daily.Quest) ~= "table"
		or type(data.Daily.Quest.Day) ~= "number"
		or type(data.Daily.Quest.Action) ~= "string"
		or type(data.Daily.Quest.Description) ~= "string"
		or type(data.Daily.Quest.DescriptionThai) ~= "string"
	then
		data.Daily.Quest = Util.deepCopy(PROFILE_TEMPLATE.Daily.Quest)
	end
	data.Daily.LastClaimDay = math.floor(tonumber(data.Daily.LastClaimDay) or -1)
	data.Daily.Streak = math.max(0, math.floor(tonumber(data.Daily.Streak) or 0))
	data.Daily.Quest.Progress = math.max(0, math.floor(tonumber(data.Daily.Quest.Progress) or 0))
	data.Daily.Quest.Target = math.clamp(math.floor(tonumber(data.Daily.Quest.Target) or 3), 1, 20)
	data.Daily.Quest.Completed = data.Daily.Quest.Completed == true

	if type(data.Adventure.Resources) ~= "table" then
		data.Adventure.Resources = {}
	end
	for resourceId in pairs(Catalog.AdventureResources) do
		data.Adventure.Resources[resourceId] = math.max(0, math.floor(tonumber(data.Adventure.Resources[resourceId]) or 0))
	end
	data.Adventure.BagSlots = storedBagSlots == nil
		and BagInventory.slotsForExisting(data.Adventure.Resources)
		or BagInventory.normaliseSlots(storedBagSlots)
	data.Adventure.CampLevel = math.clamp(math.floor(tonumber(data.Adventure.CampLevel) or 1), 1, #Catalog.CampLevels)
	if type(data.Adventure.OwnedCompanions) ~= "table" then
		data.Adventure.OwnedCompanions = { "Cat" }
	end
	local ownedCompanions = { "Cat" }
	local seenCompanions = { Cat = true }
	for _, companionId in ipairs(data.Adventure.OwnedCompanions) do
		if type(companionId) == "string" and Catalog.Companions[companionId] and not seenCompanions[companionId] then
			seenCompanions[companionId] = true
			table.insert(ownedCompanions, companionId)
		end
	end
	data.Adventure.OwnedCompanions = ownedCompanions
	if type(data.Adventure.ActiveCompanion) ~= "string" or not seenCompanions[data.Adventure.ActiveCompanion] then
		data.Adventure.ActiveCompanion = "Cat"
	end
	if type(data.Adventure.Discoveries) ~= "table" then
		data.Adventure.Discoveries = {}
	end
	for zoneId in pairs(Catalog.AdventureZones) do
		data.Adventure.Discoveries[zoneId] = data.Adventure.Discoveries[zoneId] == true
	end
	data.Adventure.PuzzleStep = math.clamp(math.floor(tonumber(data.Adventure.PuzzleStep) or 1), 1, 3)
	data.Adventure.LastPuzzleAt = math.max(0, math.floor(tonumber(data.Adventure.LastPuzzleAt) or 0))
	data.Adventure.PuzzlesSolved = math.max(0, math.floor(tonumber(data.Adventure.PuzzlesSolved) or 0))
	data.Adventure.ItemsCollected = math.max(0, math.floor(tonumber(data.Adventure.ItemsCollected) or 0))
	data.Adventure.ItemsShared = math.max(0, math.floor(tonumber(data.Adventure.ItemsShared) or 0))
	data.Adventure.BuildsCompleted = math.max(0, math.floor(tonumber(data.Adventure.BuildsCompleted) or 0))

	for statName in pairs(PROFILE_TEMPLATE.Stats) do
		data.Stats[statName] = math.max(0, math.floor(tonumber(data.Stats[statName]) or 0))
	end
	if type(data.Shop.Receipts) ~= "table" then
		data.Shop.Receipts = {}
	end
	local receipts = {}
	for key, value in pairs(data.Shop.Receipts) do
		if type(key) == "string" and value == true then
			receipts[key] = true
		end
	end
	data.Shop.Receipts = receipts
	data.Shop.RobuxSpent = math.max(0, math.floor(tonumber(data.Shop.RobuxSpent) or 0))
	data.Shop.Supporter = data.Shop.Supporter == true

	-- Quest chain progress. A profile that arrives with nonsense here is pulled
	-- back to a real step rather than being allowed to sit on a chain that does
	-- not exist, which would silently stall the player's questline forever.
	local chainCount = #Catalog.QuestChains
	data.Quests.Version = Catalog.QuestlineVersion
	data.Quests.ChainIndex = math.clamp(math.floor(tonumber(data.Quests.ChainIndex) or 1), 1, chainCount + 1)
	local chain = Catalog.QuestChains[data.Quests.ChainIndex]
	local stepCount = chain and #chain.Steps or 1
	data.Quests.Step = math.clamp(math.floor(tonumber(data.Quests.Step) or 1), 1, stepCount)
	data.Quests.Progress = math.max(0, math.floor(tonumber(data.Quests.Progress) or 0))
	data.Quests.PendingBonus = math.max(0, math.floor(tonumber(data.Quests.PendingBonus) or 0))
	data.Quests.ChainsCompleted = math.clamp(math.floor(tonumber(data.Quests.ChainsCompleted) or 0), 0, chainCount)
	data.Quests.TotalEarned = math.max(0, math.floor(tonumber(data.Quests.TotalEarned) or 0))

	data.Settings.Onboarded = data.Settings.Onboarded == true
	-- Labels are on unless the player turned them off, so older profiles that
	-- predate the setting keep seeing them.
	data.Settings.ShowLabels = data.Settings.ShowLabels ~= false
	return data
end

function DataService.new()
	local self = setmetatable({}, DataService)
	self._profiles = {}
	self._loading = {}
	local storeSuccess, storeOrError = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if storeSuccess then
		self._store = storeOrError
	elseif RunService:IsStudio() then
		self._store = nil
		warn("DataStore is unavailable for this local place; using a session-only Studio profile.")
	else
		error(string.format("Could not open the player DataStore: %s", tostring(storeOrError)))
	end
	self._running = true
	return self
end

function DataService:_key(player)
	return string.format("Player_%d", player.UserId)
end

function DataService:_createLeaderstats(player, data)
	local old = player:FindFirstChild("leaderstats")
	if old then
		old:Destroy()
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = math.floor(data.Coins)
	coins.Parent = leaderstats
end

function DataService:SyncLeaderstats(player)
	local data = self._profiles[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if data and coins then
		coins.Value = math.max(0, math.floor(data.Coins))
	end
end

function DataService:Load(player)
	if self._profiles[player] then
		return true
	end
	if self._loading[player] then
		repeat
			task.wait()
		until not self._loading[player] or not player.Parent
		return self._profiles[player] ~= nil
	end

	self._loading[player] = true
	local loadedData
	local lastError

	if self._store then
		local maxAttempts = RunService:IsStudio() and 1 or 3
		for attempt = 1, maxAttempts do
			local success, result = pcall(function()
				return self._store:GetAsync(self:_key(player))
			end)
			if success then
				loadedData = result
				lastError = nil
				break
			end
			lastError = result
			if attempt < maxAttempts then
				task.wait(attempt)
			end
		end
	end

	if lastError and not RunService:IsStudio() then
		self._loading[player] = nil
		warn(string.format("Profile load failed for %d: %s", player.UserId, tostring(lastError)))
		player:Kick("Your cozy home could not be loaded. Please rejoin in a moment.")
		return false
	end

	if type(loadedData) ~= "table" then
		loadedData = Util.deepCopy(PROFILE_TEMPLATE)
	else
		sanitizeProfile(loadedData)
	end

	loadedData.Version = Config.DataVersion
	sanitizeProfile(loadedData)
	self._profiles[player] = loadedData
	self._loading[player] = nil
	self:_createLeaderstats(player, loadedData)
	player:SetAttribute("DataLoaded", true)
	return true
end

function DataService:Get(player)
	return self._profiles[player]
end

function DataService:GetSnapshot(player)
	local data = self._profiles[player]
	if not data then
		return nil
	end
	return Util.deepCopy(data)
end

--[[
	True when profiles are actually being written to a DataStore.

	Studio without API access runs on session-only profiles, where Save always
	reports failure. Callers that must not lose a real purchase need to tell that
	apart from a DataStore that genuinely rejected the write.
]]
function DataService:IsPersistent()
	return self._store ~= nil
end

function DataService:Save(player, reason)
	local data = self._profiles[player]
	if not data then
		return false
	end
	if not self._store then
		return false
	end

	local snapshot = Util.deepCopy(data)
	local success, result = pcall(function()
		return self._store:UpdateAsync(self:_key(player), function()
			return snapshot
		end)
	end)

	if not success then
		warn(string.format("Profile save failed for %d (%s): %s", player.UserId, reason or "unknown", tostring(result)))
	end
	return success
end

function DataService:Unload(player)
	self:Save(player, "leave")
	self._profiles[player] = nil
	self._loading[player] = nil
end

function DataService:StartAutosave(playersService)
	task.spawn(function()
		while self._running do
			task.wait(Config.AutoSaveSeconds)
			for _, player in ipairs(playersService:GetPlayers()) do
				task.spawn(function()
					self:Save(player, "autosave")
				end)
			end
		end
	end)
end

function DataService:Shutdown(playersService)
	self._running = false
	local pending = 0
	for _, player in ipairs(playersService:GetPlayers()) do
		pending += 1
		task.spawn(function()
			self:Save(player, "shutdown")
			pending -= 1
		end)
	end

	local started = os.clock()
	repeat
		task.wait()
	until pending == 0 or os.clock() - started > 25
end

return DataService
