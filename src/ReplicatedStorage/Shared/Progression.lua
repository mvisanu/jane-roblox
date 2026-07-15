--[[
	Progression: the XP curve, in one place.

	The server awards XP and decides when a player levels up; the client draws the
	bar and the badge. Both need identical maths, so both require this module
	rather than each keeping its own copy of the numbers.

	The curve matches the brief: level 1 needs 100 XP, level 2 needs 250, level 3
	needs 450, and it keeps growing from there. The step between levels grows by a
	fixed 50 XP each time, which gives exactly those numbers and never stops
	scaling:

		cost(n) = 100 + 50 * (n - 1) * ... ->  100, 250, 450, 700, 1000, ...

	These are the totals to go from level n to n+1, so they are compared against
	XP held *within* the current level, not a lifetime total. That keeps the bar
	filling from empty on every level.
]]

local Progression = {}

local BASE_COST = 100
local STEP = 50
local MAX_LEVEL = 100

--[[ XP needed to get from `level` to the next one. ]]
function Progression.costForLevel(level)
	local n = math.max(1, math.floor(level))
	-- 100, 250, 450, 700, 1000 ... the gap grows by STEP each level.
	return BASE_COST * n + STEP * (n - 1) * n / 2
end

function Progression.maxLevel()
	return MAX_LEVEL
end

function Progression.isMaxLevel(level)
	return level >= MAX_LEVEL
end

--[[
	Applies XP and returns the new level, the XP left inside it, and how many
	levels were gained. A single award can cross several levels at once, so this
	loops rather than assuming one.
]]
function Progression.addXP(level, xp, amount)
	level = math.clamp(math.floor(tonumber(level) or 1), 1, MAX_LEVEL)
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	amount = math.max(0, math.floor(tonumber(amount) or 0))

	if Progression.isMaxLevel(level) then
		return level, 0, 0
	end

	xp += amount
	local gained = 0
	while not Progression.isMaxLevel(level) do
		local cost = Progression.costForLevel(level)
		if xp < cost then
			break
		end
		xp -= cost
		level += 1
		gained += 1
	end

	if Progression.isMaxLevel(level) then
		xp = 0
	end
	return level, xp, gained
end

--[[ How far through the current level the player is, from 0 to 1. ]]
function Progression.fraction(level, xp)
	if Progression.isMaxLevel(level) then
		return 1
	end
	local cost = Progression.costForLevel(level)
	if cost <= 0 then
		return 0
	end
	return math.clamp(xp / cost, 0, 1)
end

--[[ The badge text shown over a player's head. ]]
function Progression.badgeText(level)
	return string.format("\u{2B50} Level %d", math.floor(level))
end

--[[
	What each gameplay action is worth.

	This is the placeholder the brief asks for: the actions listed here already
	exist and are already validated server-side, so XP is earned by playing.
	Adding a new source is one line here, not a new code path.
]]
Progression.Rewards = {
	FinishOnboarding = 20,
	PaintHome = 10,
	GardenPlant = 5,
	GardenWater = 5,
	GardenHarvest = 12,
	PetFeed = 8,
	PetPlay = 8,
	PetBath = 8,
	CafeServe = 15,
	CafeUnlock = 40,
	CafeUpgrade = 60,
	HireCafeStaff = 50,
	Decorate = 10,
	AdventureCollect = 6,
	AdventureCrystal = 15,
	AdventureUpgradeCamp = 80,
	AdventurePuzzleSolved = 150,
	AdventureUnlockCompanion = 100,
	ChainStep = 40,
	ChainComplete = 250,
}

function Progression.rewardFor(action)
	return Progression.Rewards[action] or 0
end

return table.freeze(Progression)
