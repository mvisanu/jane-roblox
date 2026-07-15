--[[
	Placement rules.

	The server is the authority on where furniture may go, but the client needs
	the same answer to colour the ghost preview red or green while the player is
	dragging it. Rather than write the rules twice and watch them drift apart,
	both require this module. The server simply never trusts the client's word
	for the result: it runs these checks again itself.

	Coordinates are in studs, local to the player's house, on a one-stud grid.
	Rotation is a quarter turn: 0, 90, 180 or 270.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Furniture = require(Shared:WaitForChild("Furniture"))

local Placement = {}

Placement.GRID = 1
Placement.ROTATIONS = { 0, 90, 180, 270 }

local function rectangle(itemId, x, z, rotation)
	local width, depth = Furniture.footprint(itemId, rotation)
	return {
		MinX = x - width / 2,
		MaxX = x + width / 2,
		MinZ = z - depth / 2,
		MaxZ = z + depth / 2,
	}
end

local function overlaps(a, b)
	return a.MinX < b.MaxX and a.MaxX > b.MinX and a.MinZ < b.MaxZ and a.MaxZ > b.MinZ
end

local function inside(inner, outer)
	return inner.MinX >= outer.MinX
		and inner.MaxX <= outer.MaxX
		and inner.MinZ >= outer.MinZ
		and inner.MaxZ <= outer.MaxZ
end

--[[ Snaps a free position onto the grid. ]]
function Placement.snap(value)
	return math.floor(value / Placement.GRID + 0.5) * Placement.GRID
end

function Placement.normaliseRotation(rotation)
	local turns = math.floor((tonumber(rotation) or 0) / 90 + 0.5) % 4
	return turns * 90
end

function Placement.rectangleFor(itemId, x, z, rotation)
	return rectangle(itemId, x, z, rotation)
end

--[[ The region an item of this kind is allowed to live in. ]]
function Placement.regionFor(itemId)
	if Furniture.isOutdoor(itemId) then
		return Config.Furniture.Yard
	end
	return Config.Furniture.Interior
end

--[[
	Can this item go here?

	Returns false plus a reason a child can understand. `ignoreIndex` lets an
	item be moved without colliding with the copy of itself it is moving from.
]]
function Placement.canPlace(placed, itemId, x, z, rotation, ignoreIndex)
	local item = Furniture.get(itemId)
	if not item then
		return false, "That item is not in the catalogue."
	end

	rotation = Placement.normaliseRotation(rotation)
	local rect = rectangle(itemId, x, z, rotation)

	-- Inside the house (or on the lawn, for garden pieces) and not through a wall.
	if not inside(rect, Placement.regionFor(itemId)) then
		if Furniture.isOutdoor(itemId) then
			return false, "Garden things go outside on the lawn."
		end
		return false, "That does not fit inside your house."
	end

	-- The doorway has to stay walkable, or a full house locks the player out.
	if not Furniture.isOutdoor(itemId) and overlaps(rect, Config.Furniture.DoorClear) then
		return false, "Keep the doorway clear so you can get in."
	end

	-- Nothing may sit inside anything else. Flat things (rugs, sandboxes) are the
	-- exception: you are meant to put a table on a rug.
	for index, entry in ipairs(placed) do
		if index ~= ignoreIndex then
			local other = Furniture.get(entry.Id)
			local bothFlat = item.Flat and other and other.Flat
			local eitherFlat = (item.Flat or (other and other.Flat)) and not bothFlat
			if other and not eitherFlat then
				local otherRect = rectangle(entry.Id, entry.X, entry.Z, entry.R)
				if overlaps(rect, otherRect) then
					return false, "Something is already there."
				end
			end
		end
	end

	return true, nil
end

--[[
	The first free spot for an item, scanned from the back of the room forward.

	This is only the starting pose of the placement ghost. The player moves or
	turns that preview and the server buys at the confirmed pose; this function
	never decides the final position on the player's behalf.
]]
function Placement.findFreeSpot(placed, itemId)
	local region = Placement.regionFor(itemId)
	for _, rotation in ipairs({ 0, 90 }) do
		local width, depth = Furniture.footprint(itemId, rotation)
		local z = region.MaxZ - depth / 2
		while z >= region.MinZ + depth / 2 do
			local x = region.MinX + width / 2
			while x <= region.MaxX - width / 2 do
				local snappedX, snappedZ = Placement.snap(x), Placement.snap(z)
				if Placement.canPlace(placed, itemId, snappedX, snappedZ, rotation) then
					return snappedX, snappedZ, rotation
				end
				x += Placement.GRID
			end
			z -= Placement.GRID
		end
	end
	return nil
end

return Placement
