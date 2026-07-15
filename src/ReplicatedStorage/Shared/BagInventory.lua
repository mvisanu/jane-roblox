--[[
	One authoritative set of bag rules, shared by the server, UI, migration and
	tests. Adventure supplies stack; a stack occupies one visible grid cell.
	Keeping the arithmetic here prevents a client that says "there is room" from
	overruling the server, and prevents the grid from disagreeing with collection.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))

local BagInventory = {}

local function nonNegativeWhole(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

function BagInventory.usedSlots(resources)
	resources = resources or {}
	local used = 0
	for _, resourceId in ipairs(Catalog.AdventureResourceOrder) do
		local count = nonNegativeWhole(resources[resourceId])
		if count > 0 then
			used += math.ceil(count / Config.Bag.StackSize)
		end
	end
	return used
end

function BagInventory.itemCount(resources)
	resources = resources or {}
	local total = 0
	for _, resourceId in ipairs(Catalog.AdventureResourceOrder) do
		total += nonNegativeWhole(resources[resourceId])
	end
	return total
end

function BagInventory.normaliseSlots(value)
	local bag = Config.Bag
	local slots = math.clamp(nonNegativeWhole(value), bag.StartingSlots, bag.MaxSlots)
	local upgrades = math.floor((slots - bag.StartingSlots) / bag.SlotsPerUpgrade)
	return bag.StartingSlots + upgrades * bag.SlotsPerUpgrade
end

-- Legacy saves had no capacity. Give them enough purchased-size slots for the
-- supplies they already own, never delete an item, and never exceed the cap.
function BagInventory.slotsForExisting(resources)
	local bag = Config.Bag
	local used = BagInventory.usedSlots(resources)
	local neededUpgrades = math.max(0, math.ceil((used - bag.StartingSlots) / bag.SlotsPerUpgrade))
	return math.min(bag.MaxSlots, bag.StartingSlots + neededUpgrades * bag.SlotsPerUpgrade)
end

function BagInventory.availableFor(slots, resources, resourceId)
	if not Catalog.AdventureResources[resourceId] then
		return 0
	end
	resources = resources or {}
	slots = BagInventory.normaliseSlots(slots)
	local used = BagInventory.usedSlots(resources)
	if used > slots then
		return 0
	end
	local count = nonNegativeWhole(resources[resourceId])
	local partial = count % Config.Bag.StackSize
	local roomInStack = partial > 0 and Config.Bag.StackSize - partial or 0
	return roomInStack + math.max(0, slots - used) * Config.Bag.StackSize
end

function BagInventory.canAdd(slots, resources, resourceId, amount)
	amount = nonNegativeWhole(amount)
	return amount > 0 and BagInventory.availableFor(slots, resources, resourceId) >= amount
end

function BagInventory.nextUpgrade(slots)
	local bag = Config.Bag
	slots = BagInventory.normaliseSlots(slots)
	if slots >= bag.MaxSlots then
		return nil
	end
	local purchased = math.floor((slots - bag.StartingSlots) / bag.SlotsPerUpgrade)
	return {
		Slots = math.min(bag.MaxSlots, slots + bag.SlotsPerUpgrade),
		Added = math.min(bag.SlotsPerUpgrade, bag.MaxSlots - slots),
		Cost = bag.FirstUpgradeCost + purchased * bag.UpgradeCostIncrease,
	}
end

function BagInventory.stacks(resources)
	resources = resources or {}
	local stacks = {}
	for _, resourceId in ipairs(Catalog.AdventureResourceOrder) do
		local remaining = nonNegativeWhole(resources[resourceId])
		while remaining > 0 do
			local amount = math.min(Config.Bag.StackSize, remaining)
			table.insert(stacks, { Resource = resourceId, Count = amount })
			remaining -= amount
		end
	end
	return stacks
end

return table.freeze(BagInventory)
