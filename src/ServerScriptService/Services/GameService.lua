local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local BagInventory = require(Shared:WaitForChild("BagInventory"))
local CampPlan = require(Shared:WaitForChild("CampPlan"))
local CafeMenu = require(Shared:WaitForChild("CafeMenu"))
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Furniture = require(Shared:WaitForChild("Furniture"))
local Placement = require(Shared:WaitForChild("Placement"))
local Progression = require(Shared:WaitForChild("Progression"))

local GameService = {}
GameService.__index = GameService

local QUESTS = {
	{ Action = "PetFeed", Description = "Feed Mochi 3 times", DescriptionThai = "ให้อาหารโมจิ 3 ครั้ง", Target = 3 },
	{ Action = "GardenHarvest", Description = "Pick 2 flowers", DescriptionThai = "เก็บดอกไม้ 2 ดอก", Target = 2 },
	{ Action = "CafeServe", Description = "Serve 3 cafe guests", DescriptionThai = "เสิร์ฟลูกค้าคาเฟ่ 3 คน", Target = 3 },
	{ Action = "Decorate", Description = "Place 2 home items", DescriptionThai = "วางของแต่งบ้าน 2 ชิ้น", Target = 2 },
}

local SEED_PRICES = { Daisy = 15, Tulip = 25, Lavender = 40 }
local CAVE_SEQUENCE = { "Leaf", "River", "Sun" }

local function bilingualMessage(english, thai)
	return string.format("%s / %s", thai, english)
end

local function wholeNumber(value, minimum, maximum)
	return type(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
end

local function contains(list, value)
	return Util.findIndex(list, value) ~= nil
end

function GameService.new(dataService, worldService, remotes)
	local self = setmetatable({}, GameService)
	self._data = dataService
	self._world = worldService
	self._remotes = remotes
	self._lastRequests = {}
	self._adventureCooldowns = {}
	-- A purchase starts in the shop, but coins are not spent until the player
	-- positions the ghost and confirms. Weak player keys avoid retaining a
	-- disconnected player whose preview was abandoned.
	self._pendingFurniturePurchases = setmetatable({}, { __mode = "k" })
	self:_bindRemote()
	return self
end

function GameService:_today()
	return math.floor(os.time() / 86400)
end

function GameService:_ensureQuest(player)
	local data = self._data:Get(player)
	if not data then
		return
	end

	local day = self:_today()
	if data.Daily.Quest.Day ~= day or type(data.Daily.Quest.DescriptionThai) ~= "string" then
		local choice = QUESTS[((day + player.UserId) % #QUESTS) + 1]
		data.Daily.Quest = {
			Day = day,
			Action = choice.Action,
			Description = choice.Description,
			DescriptionThai = choice.DescriptionThai,
			Progress = 0,
			Target = choice.Target,
			Completed = false,
		}
	end
end

--[[
	Grants the XP an action is worth and levels the player up if it is enough.

	Every gameplay action already funnels through _progressQuest, so hooking XP
	in here means one call site instead of thirty, and a new XP source is a line
	in Progression.Rewards rather than a new code path.
]]
function GameService:_awardXP(player, action, amount)
	local data = self._data:Get(player)
	local reward = Progression.rewardFor(action) * (amount or 1)
	if not data or reward <= 0 then
		return
	end

	local level, xp, gained = Progression.addXP(data.Level, data.XP, reward)
	data.Level, data.XP = level, xp
	if gained > 0 then
		self._world:CelebrateLevelUp(player, level)
		self._remotes.Toast:FireClient(player, bilingualMessage(
			string.format("Level Up!  You are level %d", level),
			string.format("เลเวลอัพ! คุณอยู่เลเวล %d", level)
		))
	end
	self._world:RefreshLevelBadge(player, data)
end

function GameService:_progressQuest(player, action, amount)
	self:_awardXP(player, action, amount)
	self:_ensureQuest(player)
	local data = self._data:Get(player)
	local quest = data and data.Daily.Quest
	if quest and not quest.Completed and quest.Action == action then
		quest.Progress = math.min(quest.Target, quest.Progress + (amount or 1))
		if quest.Progress >= quest.Target then
			quest.Completed = true
			data.Coins += Config.QuestReward
			data.Quests.TotalEarned += Config.QuestReward
			self._remotes.Toast:FireClient(player, bilingualMessage(
				string.format("Daily quest done! +%d coins", Config.QuestReward),
				string.format("ภารกิจวันนี้สำเร็จ! +%d เหรียญ", Config.QuestReward)
			))
		end
	end

	self:_progressChain(player, action, amount)
end

--[[ The active step of the player's quest chain. Nil once every chain is done. ]]
function GameService:_currentChain(data)
	local chain = Catalog.QuestChains[data.Quests.ChainIndex]
	if not chain then
		return nil, nil
	end
	return chain, chain.Steps[data.Quests.Step]
end

-- Returning players keep the cafe and camp they already built when a new
-- authored journal begins. When the story reaches a one-time milestone they
-- already own, remember it immediately instead of asking them to buy or build
-- the same unlock again (which may be impossible at maximum level).
function GameService:_storyMilestoneMet(data, step)
	if step.CafeUnlocked then
		return data.Cafe.Unlocked == true
	elseif step.CafeLevel then
		return data.Cafe.Level >= step.CafeLevel
	elseif step.CafeStaff then
		return data.Cafe.Staff >= step.CafeStaff
	elseif step.CampLevel then
		return data.Adventure.CampLevel >= step.CampLevel
	elseif step.Companion then
		return contains(data.Adventure.OwnedCompanions, step.Companion)
	end
	return false
end

function GameService:_syncStoryMilestones(player)
	local data = self._data:Get(player)
	if not data then
		return
	end
	-- One pass can reveal the next already-owned milestone. The fixed bound also
	-- makes malformed catalogue data unable to loop forever.
	for _ = 1, 8 do
		local _, step = self:_currentChain(data)
		if not step or not self:_storyMilestoneMet(data, step) then
			break
		end
		self:_progressChain(player, step.Action, step.Target)
	end
end

--[[
	Advances the chain when the player does something its current step asks for.

	Steps land one at a time and pay out immediately; the last step of a chain
	banks the chest bonus instead, for the player to claim from the board.
]]
function GameService:_progressChain(player, action, amount)
	local data = self._data:Get(player)
	if not data then
		return
	end
	local chain, step = self:_currentChain(data)
	if not chain or not step or step.Action ~= action then
		return
	end

	data.Quests.Progress = math.min(step.Target, data.Quests.Progress + (amount or 1))
	if data.Quests.Progress < step.Target then
		self._remotes.Toast:FireClient(player, bilingualMessage(
			string.format("%s  %d/%d", step.Description, data.Quests.Progress, step.Target),
			string.format("%s  %d/%d", step.DescriptionThai, data.Quests.Progress, step.Target)
		))
		return
	end

	data.Coins += step.Reward
	data.Quests.TotalEarned += step.Reward
	self:_awardXP(player, "ChainStep", 1)

	if data.Quests.Step < #chain.Steps then
		data.Quests.Step += 1
		data.Quests.Progress = 0
		local nextStep = chain.Steps[data.Quests.Step]
		self._remotes.Toast:FireClient(player, bilingualMessage(
			string.format("+%d coins!  Next: %s", step.Reward, nextStep.Description),
			string.format("+%d เหรียญ!  ต่อไป: %s", step.Reward, nextStep.DescriptionThai)
		))
		return
	end

	-- Last step of the chain: bank the chest and open the next chain.
	data.Quests.PendingBonus += chain.Bonus
	data.Quests.ChainsCompleted += 1
	self:_awardXP(player, "ChainComplete", 1)
	data.Quests.ChainIndex += 1
	data.Quests.Step = 1
	data.Quests.Progress = 0
	self._world:PetCelebrate(player)
	self._remotes.Toast:FireClient(player, bilingualMessage(
		string.format("%s complete! A %d coin chest is waiting on your quest board.", chain.Name, chain.Bonus),
		string.format("%s สำเร็จ! หีบรางวัล %d เหรียญรออยู่ที่กระดานภารกิจ", chain.NameThai, chain.Bonus)
	))
end

function GameService:GetState(player)
	self:_ensureQuest(player)
	self:_syncStoryMilestones(player)
	local state = self._data:GetSnapshot(player)
	if not state then
		return nil
	end

	state.ServerTime = os.time()
	local month = tonumber(os.date("!%m")) or 1
	local season = month >= 3 and month <= 5 and "Spring"
		or month >= 6 and month <= 8 and "Summer"
		or month >= 9 and month <= 11 and "Autumn"
		or "Winter"
	state.Adventure.Season = season
	state.Adventure.SeasonEvent = Util.deepCopy(Catalog.SeasonEvents[season])
	if state.Adventure and state.Adventure.ActiveCompanion == "Owl" then
		state.Adventure.PuzzleHint = CAVE_SEQUENCE[state.Adventure.PuzzleStep]
	end
	state.Daily.CanClaim = state.Daily.LastClaimDay ~= self:_today()
	for _, slot in ipairs(state.Garden.Slots) do
		if slot.State == "Planted" and Catalog.Seeds[slot.Seed] then
			local elapsed = os.time() - slot.PlantedAt
			slot.SecondsLeft = math.max(0, Catalog.Seeds[slot.Seed].GrowSeconds - elapsed)
			slot.Ready = slot.Watered and slot.SecondsLeft <= 0
		else
			slot.SecondsLeft = 0
			slot.Ready = false
		end
	end
	return state
end

function GameService:_result(player, ok, message)
	self._data:SyncLeaderstats(player)
	local state = self:GetState(player)
	if state then
		self._remotes.StateChanged:FireClient(player, state)
	end
	return { ok = ok, message = message, state = state }
end

function GameService:_spend(data, amount)
	if data.Coins < amount then
		return false
	end
	data.Coins -= amount
	return true
end

function GameService:_canAffordResources(data, cost)
	for resourceId, amount in pairs(cost) do
		if (data.Adventure.Resources[resourceId] or 0) < amount then
			return false, resourceId
		end
	end
	return true, nil
end

function GameService:_spendResources(data, cost)
	for resourceId, amount in pairs(cost) do
		data.Adventure.Resources[resourceId] -= amount
	end
end

function GameService:_ownsCompanion(data, companionId)
	return contains(data.Adventure.OwnedCompanions, companionId)
end

function GameService:_isNearWaypoint(player, waypointId, maximumDistance)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = Config.Waypoints[waypointId]
	return root ~= nil and target ~= nil and (root.Position - target).Magnitude <= maximumDistance
end

function GameService:_isNearAdventureGuild(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil
		and (root.CFrame.Position - Config.AdventureGuildCenter).Magnitude <= Config.AdventureGuildTravelRadius
end

function GameService:_levelPet(pet)
	while pet.XP >= pet.Level * 25 do
		pet.XP -= pet.Level * 25
		pet.Level += 1
	end
end

function GameService:_checkRate(player, action)
	if action == "GetState" then
		return true
	end
	local now = os.clock()
	local playerRates = self._lastRequests[player]
	if not playerRates then
		playerRates = {}
		self._lastRequests[player] = playerRates
	end
	if playerRates[action] and now - playerRates[action] < Config.RequestCooldown then
		return false
	end
	playerRates[action] = now
	return true
end

function GameService:_gardenSmart(player, payload)
	local data = self._data:Get(player)
	local index = tonumber(payload.slot)
	if not data or not wholeNumber(index, 1, Config.GardenSlots) then
		return false, "Choose a garden patch first."
	end
	local slot = data.Garden.Slots[index]
	if slot.State == "Empty" then
		return self:_gardenPlant(player, { slot = index, seed = "Daisy" })
	elseif not slot.Watered then
		return self:_gardenWater(player, { slot = index })
	else
		return self:_gardenHarvest(player, { slot = index })
	end
end

function GameService:_gardenPlant(player, payload)
	local data = self._data:Get(player)
	local index = tonumber(payload.slot)
	local seed = payload.seed
	if not data or not wholeNumber(index, 1, Config.GardenSlots) or type(seed) ~= "string" or not Catalog.Seeds[seed] then
		return false, "That seed cannot be planted."
	end
	local slot = data.Garden.Slots[index]
	if slot.State ~= "Empty" then
		return false, "That patch is already growing something."
	end
	if (data.Garden.Seeds[seed] or 0) < 1 then
		return false, "You need more seeds from the flower shop."
	end

	data.Garden.Seeds[seed] -= 1
	slot.State = "Planted"
	slot.Seed = seed
	slot.PlantedAt = os.time()
	slot.Watered = false
	self:_progressQuest(player, "GardenPlant", 1)
	self._world:RefreshGarden(player, data)
	return true, string.format("%s planted! Water it next.", Catalog.Seeds[seed].DisplayName)
end

function GameService:_gardenWater(player, payload)
	local data = self._data:Get(player)
	local index = tonumber(payload.slot)
	if not data or not wholeNumber(index, 1, Config.GardenSlots) then
		return false, "Choose a garden patch first."
	end
	local slot = data.Garden.Slots[index]
	if slot.State ~= "Planted" then
		return false, "Plant a seed here first."
	end
	if slot.Watered then
		return false, "This flower is already watered."
	end
	slot.Watered = true
	self:_progressQuest(player, "GardenWater", 1)
	self._world:RefreshGarden(player, data)
	return true, "Splish splash! Your flower is growing."
end

function GameService:_gardenHarvest(player, payload)
	local data = self._data:Get(player)
	local index = tonumber(payload.slot)
	if not data or not wholeNumber(index, 1, Config.GardenSlots) then
		return false, "Choose a garden patch first."
	end
	local slot = data.Garden.Slots[index]
	local seedInfo = Catalog.Seeds[slot.Seed]
	if slot.State ~= "Planted" or not seedInfo then
		return false, "There is no flower to pick yet."
	end
	if not slot.Watered then
		return false, "This flower needs water first."
	end
	local secondsLeft = seedInfo.GrowSeconds - (os.time() - slot.PlantedAt)
	if secondsLeft > 0 then
		return false, string.format("Your flower needs %d more seconds.", math.ceil(secondsLeft))
	end

	data.Coins += seedInfo.SellPrice
	data.Stats.FlowersHarvested += 1
	data.Garden.Slots[index] = { State = "Empty", Seed = "", PlantedAt = 0, Watered = false }
	local rabbitBonus = data.Adventure and data.Adventure.ActiveCompanion == "Rabbit"
	if rabbitBonus then
		data.Garden.Seeds.Daisy = (data.Garden.Seeds.Daisy or 0) + 1
	end
	self:_progressQuest(player, "GardenHarvest", 1)
	self._world:RefreshGarden(player, data)
	if rabbitBonus then
		return true, bilingualMessage(
			string.format("Beautiful! +%d coins and Clover found a Daisy seed.", seedInfo.SellPrice),
			string.format("สวยมาก! +%d เหรียญ และโคลเวอร์พบเมล็ดเดซี่", seedInfo.SellPrice)
		)
	end
	return true, string.format("Beautiful! +%d coins", seedInfo.SellPrice)
end

function GameService:_handleAction(player, action, payload)
	local data = self._data:Get(player)
	if not data then
		return false, "Your home is still loading."
	end

	if action == "ClaimDaily" then
		local today = self:_today()
		if data.Daily.LastClaimDay == today then
			return false, "You already opened today's gift."
		end
		if data.Daily.LastClaimDay == today - 1 then
			data.Daily.Streak += 1
		else
			data.Daily.Streak = 1
		end
		data.Daily.LastClaimDay = today
		local reward = Config.DailyBaseReward + math.min(data.Daily.Streak - 1, 7) * Config.DailyStreakBonus
		data.Coins += reward
		return true, string.format("Daily gift: +%d coins!", reward)
	elseif action == "GardenSmart" then
		return self:_gardenSmart(player, payload)
	elseif action == "GardenPlant" then
		return self:_gardenPlant(player, payload)
	elseif action == "GardenWater" then
		return self:_gardenWater(player, payload)
	elseif action == "GardenHarvest" then
		return self:_gardenHarvest(player, payload)
	elseif action == "BuySeed" then
		local seed = payload.seed
		local price = type(seed) == "string" and SEED_PRICES[seed]
		if not price or not Catalog.Seeds[seed] then
			return false, "That seed is not for sale."
		end
		if not self:_spend(data, price) then
			return false, "Save a few more coins for that seed."
		end
		data.Garden.Seeds[seed] = (data.Garden.Seeds[seed] or 0) + 1
		return true, string.format("One %s seed added!", Catalog.Seeds[seed].DisplayName)
	elseif action == "PetFeed" then
		if not self:_spend(data, 5) then
			return false, "A pet snack costs 5 coins."
		end
		data.Pet.Hunger = math.min(100, data.Pet.Hunger + 20)
		data.Pet.Cleanliness = math.max(0, data.Pet.Cleanliness - 2)
		data.Pet.XP += 5
		self:_levelPet(data.Pet)
		self:_progressQuest(player, "PetFeed", 1)
		self._world:RefreshPet(player, data)
		return true, "Mochi loved the snack!"
	elseif action == "PetPlay" then
		local waitLeft = 5 - (os.time() - data.Pet.LastPlayedAt)
		if waitLeft > 0 then
			return false, string.format("Mochi is catching their breath (%ds).", waitLeft)
		end
		data.Pet.LastPlayedAt = os.time()
		data.Pet.Hunger = math.max(0, data.Pet.Hunger - 5)
		data.Pet.Cleanliness = math.max(0, data.Pet.Cleanliness - 5)
		data.Pet.XP += 4
		self:_levelPet(data.Pet)
		self:_progressQuest(player, "PetPlay", 1)
		self._world:PetCelebrate(player)
		return true, "You and Mochi played together!"
	elseif action == "PetBath" then
		if data.Pet.Cleanliness >= 100 then
			return false, "Mochi is already squeaky clean."
		end
		data.Pet.Cleanliness = 100
		self:_progressQuest(player, "PetBath", 1)
		self._world:PetCelebrate(player)
		return true, "Bubble bath complete! Mochi is sparkling."
	elseif action == "CafeUnlock" then
		if data.Cafe.Unlocked then
			return false, "Your café is already open."
		end
		if not self:_spend(data, Config.CafeUnlockCost) then
			return false, string.format("The café needs %d coins to open.", Config.CafeUnlockCost)
		end
		data.Cafe.Unlocked = true
		self:_progressQuest(player, "CafeUnlock", 1)
		return true, "Your family café is open!"
	elseif action == "CafeSmart" or action == "CafeServe" then
		if not data.Cafe.Unlocked then
			return self:_handleAction(player, "CafeUnlock", payload)
		end
		local cafeItemId = CafeMenu.resolve(payload.item)
		local cafeItem = CafeMenu.Items[cafeItemId]
		local waitLeft = Config.CafeServeCooldown - (os.time() - data.Cafe.LastServedAt)
		if waitLeft > 0 then
			return false, string.format("The next guest arrives in %ds.", waitLeft)
		end
		data.Cafe.LastServedAt = os.time()
		data.Cafe.Served += 1
		data.Stats.CustomersServed += 1
		local reward = Config.CafeServeReward + (data.Cafe.Level - 1) * 5 + data.Cafe.Staff * 5
		data.Coins += reward
		self:_progressQuest(player, "CafeServe", 1)
		if cafeItemId == "MoonBerryTart" then
			-- Signature-dish story steps are deliberately narrower than the normal
			-- cafe action. They share the validated serve, cooldown and payout above.
			self:_progressChain(player, "CafeServeMoonBerryTart", 1)
		end
		self._world:ShowCafeCustomer(player, cafeItemId)
		return true, string.format("%s served! +%d coins", cafeItem.Name, reward)
	elseif action == "CafeUpgrade" then
		if not data.Cafe.Unlocked then
			return false, "Open your cafe first."
		end
		if data.Cafe.Served < data.Cafe.Level * 5 then
			return false, string.format("Serve %d guests before the next upgrade.", data.Cafe.Level * 5)
		end
		local cost = data.Cafe.Level * 180
		if not self:_spend(data, cost) then
			return false, string.format("The cafe upgrade costs %d coins.", cost)
		end
		data.Cafe.Level += 1
		self:_progressQuest(player, "CafeUpgrade", 1)
		return true, string.format("Your cafe reached level %d!", data.Cafe.Level)
	elseif action == "HireCafeStaff" then
		if not data.Cafe.Unlocked then
			return false, "Open your cafe first."
		end
		if data.Cafe.Staff >= 3 then
			return false, "Your cafe team is full."
		end
		local cost = 250 + data.Cafe.Staff * 200
		if not self:_spend(data, cost) then
			return false, string.format("A friendly helper costs %d coins.", cost)
		end
		data.Cafe.Staff += 1
		self:_progressQuest(player, "HireCafeStaff", 1)
		return true, "A friendly NPC helper joined your cafe!"
	elseif action == "BeginFurniturePurchase" then
		local itemId = Furniture.resolve(payload.item)
		local item = itemId and Furniture.get(itemId)
		if not item then
			return false, bilingualMessage("That furniture is not in the shop.", "ไม่มีเฟอร์นิเจอร์ชิ้นนี้ในร้าน")
		end
		if self._pendingFurniturePurchases[player] then
			return false, bilingualMessage(
				"Finish placing or cancel the current item first.",
				"วางหรือยกเลิกเฟอร์นิเจอร์ชิ้นปัจจุบันก่อน"
			)
		end
		if #data.Home.Furniture >= Config.MaxFurniture then
			return false, bilingualMessage("Your home is full for now.", "บ้านของคุณเต็มแล้ว")
		end
		if data.Coins < item.Price then
			return false, bilingualMessage(
				string.format("%s costs %d coins.", item.Name, item.Price),
				string.format("%s ราคา %d เหรียญ", item.NameThai, item.Price)
			)
		end
		self._pendingFurniturePurchases[player] = itemId
		return true, bilingualMessage(
			string.format("Arrange %s, then confirm BUY & PLACE.", item.Name),
			string.format("จัดตำแหน่ง %s แล้วกดยืนยันซื้อและวาง", item.NameThai)
		)
	elseif action == "CancelFurniturePurchase" then
		if not self._pendingFurniturePurchases[player] then
			return true, bilingualMessage("Placement cancelled.", "ยกเลิกการจัดวางแล้ว")
		end
		self._pendingFurniturePurchases[player] = nil
		return true, bilingualMessage("Purchase cancelled. No coins were spent.", "ยกเลิกการซื้อแล้ว ไม่เสียเหรียญ")
	elseif action == "BuyFurniture" then
		local itemId = Furniture.resolve(payload.item)
		local item = itemId and Furniture.get(itemId)
		if not item then
			return false, bilingualMessage("That furniture is not in the shop.", "ไม่มีเฟอร์นิเจอร์ชิ้นนี้ในร้าน")
		end
		if self._pendingFurniturePurchases[player] ~= itemId then
			return false, bilingualMessage(
				"Arrange this item before buying it.",
				"จัดตำแหน่งเฟอร์นิเจอร์ชิ้นนี้ก่อนซื้อ"
			)
		end
		if #data.Home.Furniture >= Config.MaxFurniture then
			return false, bilingualMessage("Your home is full for now.", "บ้านของคุณเต็มแล้ว")
		end
		if data.Coins < item.Price then
			return false, bilingualMessage(
				string.format("%s costs %d coins.", item.Name, item.Price),
				string.format("%s ราคา %d เหรียญ", item.NameThai, item.Price)
			)
		end

		-- Buying is an atomic placement confirmation. Missing coordinates are never
		-- replaced with the origin and the server validates the exact ghost pose.
		if type(payload.x) ~= "number" or type(payload.z) ~= "number" then
			return false, bilingualMessage(
				"Choose a position before buying.",
				"เลือกตำแหน่งก่อนยืนยันซื้อ"
			)
		end
		local x = Placement.snap(payload.x)
		local z = Placement.snap(payload.z)
		local rotation = Placement.normaliseRotation(payload.r)
		local canPlace, reason = Placement.canPlace(data.Home.Furniture, itemId, x, z, rotation)
		if not canPlace then
			return false, reason
		end

		-- Spend only after every placement check passes. This prevents a failed or
		-- cancelled preview from charging the player or creating a boxed item.
		self:_spend(data, item.Price)
		data.Home.OwnedFurniture[itemId] = (data.Home.OwnedFurniture[itemId] or 0) + 1
		table.insert(data.Home.Furniture, { Id = itemId, X = x, Z = z, R = rotation })
		self._pendingFurniturePurchases[player] = nil
		data.Stats.FurniturePlaced += 1
		self:_progressQuest(player, "Decorate", 1)
		self._world:RefreshHome(player, data)
		return true, bilingualMessage(
			string.format("%s bought exactly where you placed it!", item.Name),
			string.format("ซื้อและวาง %s ตามตำแหน่งที่เลือกแล้ว!", item.NameThai)
		)
	elseif action == "PlaceFurniture" then
		local itemId = Furniture.resolve(payload.item)
		local item = itemId and Furniture.get(itemId)
		if not item then
			return false, bilingualMessage("Choose a home item first.", "เลือกของแต่งบ้านก่อน")
		end
		if #data.Home.Furniture >= Config.MaxFurniture then
			return false, bilingualMessage("Your home is full for now.", "บ้านของคุณเต็มแล้ว")
		end

		-- You may only place what you own and have not already put out.
		local placedCount = 0
		for _, entry in ipairs(data.Home.Furniture) do
			if entry.Id == itemId then
				placedCount += 1
			end
		end
		if placedCount >= (data.Home.OwnedFurniture[itemId] or 0) then
			return false, bilingualMessage("Buy another one before placing it.", "ซื้ออีกชิ้นก่อนวาง")
		end

		local x = Placement.snap(tonumber(payload.x) or 0)
		local z = Placement.snap(tonumber(payload.z) or 0)
		local rotation = Placement.normaliseRotation(payload.r)
		-- The client colours its own preview, but the server never takes its word
		-- for it: the same rules are checked again here.
		local ok, reason = Placement.canPlace(data.Home.Furniture, itemId, x, z, rotation)
		if not ok then
			return false, reason
		end

		table.insert(data.Home.Furniture, { Id = itemId, X = x, Z = z, R = rotation })
		data.Stats.FurniturePlaced += 1
		self:_progressQuest(player, "Decorate", 1)
		self._world:RefreshHome(player, data)
		return true, bilingualMessage(string.format("%s placed!", item.Name), string.format("วาง %s แล้ว!", item.NameThai))
	elseif action == "MoveFurniture" then
		local index = tonumber(payload.index)
		if not wholeNumber(index, 1, #data.Home.Furniture) then
			return false, bilingualMessage("Pick something to move.", "เลือกของที่จะย้าย")
		end
		local entry = data.Home.Furniture[index]
		local x = Placement.snap(tonumber(payload.x) or entry.X)
		local z = Placement.snap(tonumber(payload.z) or entry.Z)
		local rotation = Placement.normaliseRotation(payload.r ~= nil and payload.r or entry.R)

		-- Ignore the item's own current square, or it would collide with itself.
		local ok, reason = Placement.canPlace(data.Home.Furniture, entry.Id, x, z, rotation, index)
		if not ok then
			return false, reason
		end
		entry.X, entry.Z, entry.R = x, z, rotation
		self._world:RefreshHome(player, data)
		return true, bilingualMessage("Moved!", "ย้ายแล้ว!")
	elseif action == "RemoveFurniture" then
		if #data.Home.Furniture == 0 then
			return false, bilingualMessage("There is nothing to pack away.", "ไม่มีของให้เก็บ")
		end
		local index = tonumber(payload.index) or #data.Home.Furniture
		if not wholeNumber(index, 1, #data.Home.Furniture) then
			return false, bilingualMessage("Pick something to pack away.", "เลือกของที่จะเก็บ")
		end
		local removed = table.remove(data.Home.Furniture, index)
		self._world:RefreshHome(player, data)
		local item = Furniture.get(removed.Id)
		return true, bilingualMessage(
			string.format("%s is back in your box.", item and item.Name or "The item"),
			string.format("เก็บ %s กลับกล่องแล้ว", item and item.NameThai or "ของชิ้นนี้")
		)
	elseif action == "FavoriteFurniture" then
		local itemId = Furniture.resolve(payload.item)
		if not itemId then
			return false, bilingualMessage("That furniture is not in the shop.", "ไม่มีเฟอร์นิเจอร์ชิ้นนี้ในร้าน")
		end
		if data.Home.Favorites[itemId] then
			data.Home.Favorites[itemId] = nil
			return true, bilingualMessage("Removed from favourites.", "เอาออกจากรายการโปรดแล้ว")
		end
		data.Home.Favorites[itemId] = true
		return true, bilingualMessage("Added to favourites.", "เพิ่มในรายการโปรดแล้ว")
	elseif action == "PaintHome" then
		local requested = type(payload.color) == "string" and payload.color or nil
		local selected = nil
		for _, entry in ipairs(Config.HomeColors) do
			if entry.Name == requested then
				selected = entry
				break
			end
		end
		if not selected then
			return false, bilingualMessage("Choose a color from the cottage palette.", "เลือกสีจากพาเลทบ้าน")
		end
		if data.Home.Paint == selected.Name then
			return false, bilingualMessage("Your cottage already uses that color.", "บ้านของคุณใช้สีนี้อยู่แล้ว")
		end
		data.Home.Paint = selected.Name
		self:_progressQuest(player, "PaintHome", 1)
		self._world:RefreshHome(player, data)
		return true, bilingualMessage(
			string.format("Your cottage is now %s!", selected.DisplayName),
			string.format("บ้านของคุณเปลี่ยนเป็นสี%sแล้ว!", selected.NameThai)
		)
	elseif action == "EquipAvatar" then
		local avatarId = payload.avatar
		if avatarId == "Original" then
			data.Wardrobe.Equipped = "Original"
			self._world:ApplyOutfit(player, data)
			return true, bilingualMessage("Your original Roblox avatar is back!", "กลับมาใช้อวตาร Roblox เดิมของคุณแล้ว!")
		end
		local preset = type(avatarId) == "string" and Catalog.Outfits[avatarId] or nil
		if not preset or preset.Style ~= avatarId or not contains(data.Wardrobe.Owned, avatarId) then
			return false, bilingualMessage("Choose one of the six approved avatars.", "เลือกอวตารที่อนุมัติจากทั้ง 6 ตัว")
		end
		data.Wardrobe.Equipped = avatarId
		self._world:ApplyOutfit(player, data)
		return true, bilingualMessage(
			string.format("You are now %s!", preset.DisplayName),
			string.format("เปลี่ยนเป็น%sแล้ว!", preset.DisplayNameThai)
		)
	elseif action == "BagUpgrade" then
		local upgrade = BagInventory.nextUpgrade(data.Adventure.BagSlots)
		if not upgrade then
			return false, bilingualMessage("Your bag already has every slot.", "กระเป๋ามีช่องครบสูงสุดแล้ว")
		end
		if not self:_spend(data, upgrade.Cost) then
			return false, bilingualMessage(
				string.format("The next %d bag slots cost %d coins.", upgrade.Added, upgrade.Cost),
				string.format("ช่องกระเป๋าเพิ่ม %d ช่อง ราคา %d เหรียญ", upgrade.Added, upgrade.Cost)
			)
		end
		data.Adventure.BagSlots = upgrade.Slots
		return true, bilingualMessage(
			string.format("Bag expanded to %d slots!", upgrade.Slots),
			string.format("ขยายกระเป๋าเป็น %d ช่องแล้ว!", upgrade.Slots)
		)
	elseif action == "AdventureCollect" then
		local zoneId = payload.zone
		local resourceId = payload.resource
		local zone = type(zoneId) == "string" and Catalog.AdventureZones[zoneId]
		local resource = type(resourceId) == "string" and Catalog.AdventureResources[resourceId]
		local allowed = {
			WildwoodForest = { Wood = true, Herbs = true },
			Mountain = { Stone = true, Crystal = true },
			RiverAdventure = { Fish = true, Herbs = true },
			MysteryCave = { Crystal = true, Stone = true },
		}
		if not zone or not resource or not allowed[zoneId] or not allowed[zoneId][resourceId] then
			return false, bilingualMessage("That item does not belong to this adventure zone.", "ของชิ้นนี้ไม่ได้อยู่ในเขตผจญภัยนี้")
		end
		if not self:_isNearWaypoint(player, zoneId, 100) then
			return false, bilingualMessage("Travel to that adventure zone before collecting.", "เดินทางไปยังเขตผจญภัยนั้นก่อนเก็บของ")
		end
		local playerCooldowns = self._adventureCooldowns[player]
		if not playerCooldowns then
			playerCooldowns = {}
			self._adventureCooldowns[player] = playerCooldowns
		end
		local cooldownKey = string.format("%s:%s", zoneId, resourceId)
		local now = os.clock()
		local waitLeft = Config.AdventureCollectCooldown - (now - (playerCooldowns[cooldownKey] or -math.huge))
		if waitLeft > 0 then
			return false, bilingualMessage(string.format("Search again in %d seconds.", math.ceil(waitLeft)), string.format("ค้นหาอีกครั้งใน %d วินาที", math.ceil(waitLeft)))
		end
		local amount = 1
		local active = data.Adventure.ActiveCompanion
		if (active == "Fox" and zoneId == "WildwoodForest")
			or (active == "Dog" and zoneId == "Mountain")
			or (active == "Owl" and zoneId == "MysteryCave")
		then
			amount += 1
		end
		if not BagInventory.canAdd(data.Adventure.BagSlots, data.Adventure.Resources, resourceId, amount) then
			return false, bilingualMessage(
				"Your bag is full. Open Bag to buy more slots.",
				"กระเป๋าเต็ม เปิดเมนูกระเป๋าเพื่อซื้อช่องเพิ่ม"
			)
		end
		-- A full bag must not consume the collection cooldown. The player can make
		-- room or expand it and collect this same node immediately.
		playerCooldowns[cooldownKey] = now
		data.Adventure.Resources[resourceId] += amount
		data.Adventure.ItemsCollected += amount
		data.Adventure.Discoveries[zoneId] = true
		data.Coins += 5 * amount
		self:_progressQuest(player, "AdventureCollect", amount)
		if resourceId == "Crystal" then
			self:_progressQuest(player, "AdventureCrystal", amount)
		else
			local resourceQuestAction = {
				Wood = "AdventureWood",
				Stone = "AdventureStone",
				Herbs = "AdventureHerbs",
				Fish = "AdventureFish",
			}
			-- Specific supply steps make the story honest: collecting a fish cannot
			-- satisfy a request for timber. XP is already awarded by AdventureCollect.
			self:_progressChain(player, resourceQuestAction[resourceId], amount)
		end
		return true, bilingualMessage(
			string.format("Found %d %s! +%d coins", amount, resource.DisplayName, 5 * amount),
			string.format("พบ%s %d ชิ้น! +%d เหรียญ", resource.DisplayNameThai, amount, 5 * amount)
		)
	elseif action == "AdventureUpgradeCamp" then
		local currentLevel = data.Adventure.CampLevel
		if currentLevel >= #Catalog.CampLevels then
			return false, bilingualMessage("Your Adventure Center is fully built!", "ศูนย์ผจญภัยของคุณสร้างเสร็จสมบูรณ์แล้ว!")
		end
		local nextLevel = Catalog.CampLevels[currentLevel + 1]
		-- Name everything that is still missing, and how much of it. Telling a child
		-- about one missing item at a time - which is what naming a single resource
		-- out of `pairs()` did - turns the last camp into a guessing game.
		if not CampPlan.canBuild(currentLevel, data.Adventure.Resources) then
			return false, bilingualMessage(
				string.format(
					"To build the %s you still need %s.",
					nextLevel.Name,
					CampPlan.missingText(currentLevel, data.Adventure.Resources, false)
				),
				string.format(
					"อยากสร้าง%s ต้องเก็บ %s เพิ่ม",
					nextLevel.NameThai,
					CampPlan.missingText(currentLevel, data.Adventure.Resources, true)
				)
			)
		end
		self:_spendResources(data, nextLevel.Cost)
		data.Adventure.CampLevel += 1
		data.Adventure.BuildsCompleted += 1
		self:_progressQuest(player, "AdventureUpgradeCamp", 1)
		self._world:RefreshAdventureCamp(player, data)
		return true, bilingualMessage(string.format("Built: %s!", nextLevel.Name), string.format("สร้าง%sสำเร็จ!", nextLevel.NameThai))
	elseif action == "AdventureUnlockCompanion" then
		local companionId = payload.companion
		local companion = type(companionId) == "string" and Catalog.Companions[companionId]
		if not companion then
			return false, bilingualMessage("That companion could not be found.", "ไม่พบสัตว์คู่ใจตัวนั้น")
		end
		if self:_ownsCompanion(data, companionId) then
			return false, bilingualMessage("That companion is already your friend.", "สัตว์ตัวนี้เป็นเพื่อนของคุณแล้ว")
		end
		local canAfford, missing = self:_canAffordResources(data, companion.Cost)
		if not canAfford then
			local missingInfo = Catalog.AdventureResources[missing]
			return false, bilingualMessage(string.format("Collect more %s first.", missingInfo.DisplayName), string.format("เก็บ%sเพิ่มก่อน", missingInfo.DisplayNameThai))
		end
		self:_spendResources(data, companion.Cost)
		table.insert(data.Adventure.OwnedCompanions, companionId)
		self:_progressQuest(player, "AdventureUnlockCompanion", 1)
		data.Adventure.ActiveCompanion = companionId
		self._world:RefreshPet(player, data)
		return true, bilingualMessage(string.format("%s joined your adventure!", companion.DisplayName), string.format("%sร่วมผจญภัยกับคุณแล้ว!", companion.DisplayNameThai))
	elseif action == "AdventureSelectCompanion" then
		local companionId = payload.companion
		local companion = type(companionId) == "string" and Catalog.Companions[companionId]
		if not companion or not self:_ownsCompanion(data, companionId) then
			return false, bilingualMessage("Unlock that companion first.", "ปลดล็อกสัตว์คู่ใจก่อน")
		end
		data.Adventure.ActiveCompanion = companionId
		self._world:RefreshPet(player, data)
		return true, bilingualMessage(string.format("Exploring with %s.", companion.DisplayName), string.format("ออกสำรวจกับ%s", companion.DisplayNameThai))
	elseif action == "AdventurePuzzleRune" then
		local rune = payload.rune
		if rune ~= "Leaf" and rune ~= "River" and rune ~= "Sun" then
			return false, bilingualMessage("That cave rune is unknown.", "ไม่รู้จักรูนถ้ำนี้")
		end
		if not self:_isNearWaypoint(player, "MysteryCave", 85) then
			return false, bilingualMessage("Travel to Mystery Cave to touch the runes.", "เดินทางไปถ้ำลึกลับเพื่อแตะรูน")
		end
		local puzzleWait = 60 - (os.time() - data.Adventure.LastPuzzleAt)
		if data.Adventure.PuzzleStep == 1 and data.Adventure.PuzzlesSolved > 0 and puzzleWait > 0 then
			return false, bilingualMessage(string.format("The cave resets in %d seconds.", puzzleWait), string.format("ถ้ำจะรีเซ็ตใน %d วินาที", puzzleWait))
		end
		local expected = CAVE_SEQUENCE[data.Adventure.PuzzleStep]
		if rune ~= expected then
			data.Adventure.PuzzleStep = 1
			return false, bilingualMessage("The runes dimmed. Try a new order.", "รูนดับลง ลองเรียงใหม่อีกครั้ง")
		end
		if data.Adventure.PuzzleStep < #CAVE_SEQUENCE then
			data.Adventure.PuzzleStep += 1
			return true, bilingualMessage("The rune glows. Choose the next one!", "รูนส่องแสง เลือกอันต่อไป!")
		end
		if not BagInventory.canAdd(data.Adventure.BagSlots, data.Adventure.Resources, "Crystal", 2) then
			return false, bilingualMessage(
				"The cave found 2 crystals, but your bag is full.",
				"ถ้ำพบคริสตัล 2 ชิ้น แต่กระเป๋าของคุณเต็ม"
			)
		end
		data.Adventure.PuzzleStep = 1
		data.Adventure.LastPuzzleAt = os.time()
		data.Adventure.PuzzlesSolved += 1
		self:_progressQuest(player, "AdventurePuzzleSolved", 1)
		data.Adventure.Resources.Crystal += 2
		data.Adventure.Discoveries.MysteryCave = true
		data.Coins += Config.AdventurePuzzleReward
		self._world:PulseMysteryCave()
		return true, bilingualMessage(
			string.format("Mystery solved! +2 crystals and +%d coins", Config.AdventurePuzzleReward),
			string.format("ไขปริศนาสำเร็จ! +2 คริสตัล และ +%d เหรียญ", Config.AdventurePuzzleReward)
		)
	elseif action == "AdventureShare" then
		local resourceId = payload.resource
		local resource = type(resourceId) == "string" and Catalog.AdventureResources[resourceId]
		if not resource then
			return false, bilingualMessage("Choose a valid supply to share.", "เลือกของที่ต้องการแบ่งปัน")
		end
		if data.Adventure.Resources[resourceId] < 1 then
			return false, bilingualMessage(string.format("You need a %s first.", resource.DisplayName), string.format("คุณต้องมี%sก่อน", resource.DisplayNameThai))
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local nearestPlayer
		local nearestDistance = 50
		if root then
			for _, candidate in ipairs(Players:GetPlayers()) do
				if candidate ~= player then
					local candidateCharacter = candidate.Character
					local candidateRoot = candidateCharacter and candidateCharacter:FindFirstChild("HumanoidRootPart")
					local candidateData = self._data:Get(candidate)
					if candidateRoot and candidateData then
						local distance = (root.Position - candidateRoot.Position).Magnitude
						if distance < nearestDistance then
							nearestPlayer = candidate
							nearestDistance = distance
						end
					end
				end
			end
		end
		if not nearestPlayer then
			return false, bilingualMessage("Move within 50 studs of another explorer to share.", "เข้าใกล้นักสำรวจคนอื่นในระยะ 50 สตัดเพื่อแบ่งปัน")
		end
		local targetData = self._data:Get(nearestPlayer)
		if not BagInventory.canAdd(targetData.Adventure.BagSlots, targetData.Adventure.Resources, resourceId, 1) then
			return false, bilingualMessage(
				string.format("%s's bag is full.", nearestPlayer.DisplayName),
				string.format("กระเป๋าของ%sเต็มแล้ว", nearestPlayer.DisplayName)
			)
		end
		data.Adventure.Resources[resourceId] -= 1
		data.Adventure.ItemsShared += 1
		targetData.Adventure.Resources[resourceId] += 1
		self._remotes.StateChanged:FireClient(nearestPlayer, self:GetState(nearestPlayer))
		self._remotes.Toast:FireClient(nearestPlayer, bilingualMessage(
			string.format("%s shared 1 %s with you!", player.DisplayName, resource.DisplayName),
			string.format("%sแบ่ง%sให้คุณ 1 ชิ้น!", player.DisplayName, resource.DisplayNameThai)
		))
		return true, bilingualMessage(
			string.format("Shared 1 %s with %s!", resource.DisplayName, nearestPlayer.DisplayName),
			string.format("แบ่ง%s 1 ชิ้นให้%sแล้ว!", resource.DisplayNameThai, nearestPlayer.DisplayName)
		)
	elseif action == "Teleport" then
		local destination = payload.destination
		if not self:_isNearAdventureGuild(player) then
			return false, bilingualMessage(
				"Travel from the map station at the Adventure Guild in the town centre.",
				"เดินทางได้ที่จุดแผนที่ของ Adventure Guild ตรงกลางเมือง"
			)
		end
		if destination == "Home" then
			self._world:TeleportHome(player)
		elseif type(destination) == "string" and Config.Waypoints[destination] then
			self._world:Teleport(player, destination)
		else
			return false, "That place is not on your map."
		end
		return true, string.format("Welcome to %s!", destination)
	elseif action == "TeleportHome" then
		self._world:TeleportHome(player)
		return true, bilingualMessage("Welcome home!", "ยินดีต้อนรับกลับบ้าน!")
	elseif action == "FinishOnboarding" then
		data.Settings.Onboarded = true
		self:_progressQuest(player, "FinishOnboarding", 1)
		return true, "Have a lovely day in Family Town!"
	elseif action == "ToggleLabels" then
		data.Settings.ShowLabels = not data.Settings.ShowLabels
		return true, data.Settings.ShowLabels and "Place names are on." or "Place names are off."
	elseif action == "ClaimChainBonus" then
		local bonus = data.Quests.PendingBonus
		if bonus <= 0 then
			return false, bilingualMessage("No chest to open yet.", "ยังไม่มีหีบรางวัล")
		end
		data.Quests.PendingBonus = 0
		data.Coins += bonus
		data.Quests.TotalEarned += bonus
		self._world:PetCelebrate(player)
		return true, bilingualMessage(
			string.format("Chest opened! +%d coins", bonus),
			string.format("เปิดหีบรางวัล! +%d เหรียญ", bonus)
		)
	end

	return false, "That activity is not available."
end

function GameService:Handle(player, action, payload)
	if type(action) ~= "string" then
		return self:_result(player, false, "That request was not understood.")
	end
	if action == "GetState" then
		return self:_result(player, true, "Ready")
	end
	if action == "GetMap" then
		-- Read-only: the layout of the town the server already built, plus which
		-- of the eight homes belongs to this player.
		return { ok = true, map = self._world:GetMapData(player) }
	end
	if not self:_checkRate(player, action) then
		return self:_result(player, false, "One moment, please.")
	end
	payload = type(payload) == "table" and payload or {}

	local ok, actionOk, message = xpcall(function()
		local success, response = self:_handleAction(player, action, payload)
		return success, response
	end, debug.traceback)
	if not ok then
		warn(string.format("Action %s failed for %s: %s", action, player.Name, tostring(actionOk)))
		return self:_result(player, false, "Something went wobbly. Please try again.")
	end
	return self:_result(player, actionOk, message)
end

function GameService:OnPlayerReady(player)
	self:_ensureQuest(player)
	local data = self._data:Get(player)
	if data then
		self._world:RefreshHome(player, data)
		self._world:RefreshGarden(player, data)
		self._world:RefreshPet(player, data)
		self._world:RefreshAdventureCamp(player, data)
		self._world:ApplyOutfit(player, data)
		self._remotes.StateChanged:FireClient(player, self:GetState(player))
	end
end

function GameService:ForgetPlayer(player)
	self._lastRequests[player] = nil
	self._adventureCooldowns[player] = nil
end

function GameService:_bindRemote()
	self._remotes.Request.OnServerInvoke = function(player, action, payload)
		return self:Handle(player, action, payload)
	end
end

return GameService
