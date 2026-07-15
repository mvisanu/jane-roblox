--[[
	ShopService: the game's Robux income.

	Roblox provides no way to pay Robux out to a player, so nothing here tries.
	What it does is take Robux IN: players buy coin packs (developer products)
	and a cosmetic supporter pass, and that revenue goes to the game owner.

	Two rules this file exists to enforce:

	1. A receipt is granted exactly once. Roblox re-delivers receipts until the
	   game confirms them, so a naive handler pays the same purchase repeatedly.
	   Every granted receipt id is written into the player's profile, and the
	   profile is saved BEFORE the purchase is confirmed - if the save fails we
	   return NotProcessedYet and Roblox will hand us the receipt again, rather
	   than the player paying real money for coins that were never persisted.

	2. Nothing bought here touches quest progress. Coins buy furniture and seeds.
	   No chest, chain, or step can be purchased, so paying money can never skip
	   the game for a child playing it.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ShopService = {}
ShopService.__index = ShopService

local function bilingualMessage(english, thai)
	return string.format("%s / %s", thai, english)
end

function ShopService.new(dataService, remotes)
	local self = setmetatable({}, ShopService)
	self._data = dataService
	self._remotes = remotes

	self._packsByProduct = {}
	for _, pack in ipairs(Config.Monetization.CoinPacks) do
		if pack.ProductId and pack.ProductId > 0 then
			self._packsByProduct[pack.ProductId] = pack
		end
	end

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Monetization.SupporterPassId then
			self:_grantSupporter(player)
		end
	end)

	return self
end

--[[ True when the store has anything to sell: with no ids set, it stays hidden. ]]
function ShopService.IsConfigured()
	if Config.Monetization.SupporterPassId > 0 then
		return true
	end
	for _, pack in ipairs(Config.Monetization.CoinPacks) do
		if pack.ProductId > 0 then
			return true
		end
	end
	return false
end

function ShopService:_grantSupporter(player)
	local data = self._data:Get(player)
	if not data or data.Shop.Supporter then
		return
	end
	data.Shop.Supporter = true
	self._data:Save(player, "supporter")
	self._remotes.Toast:FireClient(player, bilingualMessage(
		string.format("Thank you! The %s is yours.", Config.Monetization.SupporterName),
		string.format("ขอบคุณ! %s เป็นของคุณแล้ว", Config.Monetization.SupporterNameThai)
	))
end

--[[ Reads the pass state on join, so a supporter keeps it across servers. ]]
function ShopService:RefreshSupporter(player)
	local passId = Config.Monetization.SupporterPassId
	if passId <= 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and owns then
		local data = self._data:Get(player)
		if data and not data.Shop.Supporter then
			data.Shop.Supporter = true
		end
	end
end

function ShopService:_processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- They left mid-purchase. Do not consume the receipt: Roblox will
		-- deliver it again next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = self._data:Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(receiptInfo.PurchaseId)
	if data.Shop.Receipts[receiptKey] then
		-- Already paid for. Confirm it so Roblox stops re-delivering it.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local pack = self._packsByProduct[receiptInfo.ProductId]
	if not pack then
		warn(string.format("ShopService: unknown product %s", tostring(receiptInfo.ProductId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Shop.Receipts[receiptKey] = true
	data.Coins += pack.Coins
	data.Shop.RobuxSpent += (receiptInfo.CurrencySpent or pack.Robux or 0)

	-- Persist before confirming. If the DataStore rejects the write, undo the
	-- grant and let Roblox re-deliver the receipt, rather than confirming a
	-- purchase whose coins would vanish on rejoin.
	--
	-- A Studio session with no DataStore is not a failed save, it is no save at
	-- all, and refusing there would leave a real purchase undeliverable forever.
	if self._data:IsPersistent() and not self._data:Save(player, "purchase") then
		data.Shop.Receipts[receiptKey] = nil
		data.Coins -= pack.Coins
		data.Shop.RobuxSpent -= (receiptInfo.CurrencySpent or pack.Robux or 0)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self._data:SyncLeaderstats(player)
	self._remotes.Toast:FireClient(player, bilingualMessage(
		string.format("Thank you! +%d coins", pack.Coins),
		string.format("ขอบคุณ! +%d เหรียญ", pack.Coins)
	))
	self._remotes.StateChanged:FireClient(player, self._data:GetSnapshot(player))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return ShopService
