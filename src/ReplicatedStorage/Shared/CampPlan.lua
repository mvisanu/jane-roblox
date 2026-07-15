--[[
	CampPlan: exactly what the next camp upgrade needs, and what you already have.

	The bug this exists for: "Upgrade your camp" was the whole of the quest step. It
	never said the Adventure Center wants 25 Wildwood, 15 Mountain Stone, 6 Cave
	Crystal and 5 River Fish - and when the server refused the upgrade it named a
	single missing resource, chosen by `pairs()`, which has no defined order. A
	player short of three different things was told about one of them, went and got
	it, and was then told about another. For a five-year-old that is not a quest,
	it is a guessing game with the answer hidden.

	So the requirement list is computed here, once, in a fixed order, carrying both
	the amount needed and the amount held. The quest board, the adventure menu, the
	bag and the server's refusal message all read from this function, which is the
	reason they cannot drift apart and tell the player different stories.

	Deliberately plain Lua with no Roblox API beyond the Catalog it reads, so
	`scripts/camp_plan_test.py` can check it without an engine.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))

local CampPlan = {}

--[[ The camp the player is building towards, or nil once it is all built. ]]
function CampPlan.nextLevel(campLevel)
	return Catalog.CampLevels[(campLevel or 1) + 1]
end

--[[
	The full shopping list for the next camp.

	Every entry the cost mentions, in Catalog.AdventureResourceOrder - never in
	`pairs()` order, so the checklist a player reads is the same one every time
	they open it, and the same one on every device.

	Returns nil when the camp is fully built, which the callers render as "done"
	rather than as an empty list.
]]
function CampPlan.requirements(campLevel, resources)
	local nextLevel = CampPlan.nextLevel(campLevel)
	if not nextLevel then
		return nil
	end
	resources = resources or {}

	local items = {}
	local missing = 0
	for _, resourceId in ipairs(Catalog.AdventureResourceOrder) do
		local need = nextLevel.Cost[resourceId]
		if need and need > 0 then
			local have = resources[resourceId] or 0
			local met = have >= need
			if not met then
				missing += 1
			end
			table.insert(items, {
				Id = resourceId,
				Name = Catalog.AdventureResources[resourceId].DisplayName,
				NameThai = Catalog.AdventureResources[resourceId].DisplayNameThai,
				Icon = Catalog.AdventureResources[resourceId].Icon,
				Color = Catalog.AdventureResources[resourceId].Color,
				FoundIn = Catalog.AdventureResources[resourceId].FoundIn,
				FoundInThai = Catalog.AdventureResources[resourceId].FoundInThai,
				Need = need,
				Have = have,
				-- What is still to collect. This is the number a child acts on, so it
				-- is computed here rather than left as have-minus-need arithmetic for
				-- four different callers to get subtly wrong.
				Short = math.max(0, need - have),
				Met = met,
			})
		end
	end

	return {
		Level = (campLevel or 1) + 1,
		Name = nextLevel.Name,
		NameThai = nextLevel.NameThai,
		Items = items,
		Missing = missing,
		Ready = missing == 0,
	}
end

--[[
	Everything still missing, named and counted: "5 more Wildwood and 2 more Cave
	Crystal". The server says this when it turns an upgrade down, so the player is
	told the whole truth in one go instead of one item per attempt.
]]
function CampPlan.missingText(campLevel, resources, thai)
	local plan = CampPlan.requirements(campLevel, resources)
	if not plan or plan.Ready then
		return ""
	end

	local pieces = {}
	for _, item in ipairs(plan.Items) do
		if not item.Met then
			table.insert(pieces, string.format("%s %d %s", item.Icon, item.Short, thai and item.NameThai or item.Name))
		end
	end

	if #pieces == 1 then
		return pieces[1]
	end
	local joiner = thai and " และ " or " and "
	local last = table.remove(pieces)
	return string.format("%s%s%s", table.concat(pieces, ", "), joiner, last)
end

--[[ Can the next camp be built right now? ]]
function CampPlan.canBuild(campLevel, resources)
	local plan = CampPlan.requirements(campLevel, resources)
	return plan ~= nil and plan.Ready
end

return CampPlan
