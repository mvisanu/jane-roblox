local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WildwoodStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildwoodStyle"))

local CafeModels = {}

CafeModels.Tag = "MoonleafCafeFood3D"

local COLORS = {
	Plate = WildwoodStyle.World.CanvasLight,
	Crust = WildwoodStyle.World.TimberLight,
	CrustLight = WildwoodStyle.World.Plaster,
	Berry = WildwoodStyle.World.Water,
	BerryGlow = WildwoodStyle.World.WaterLight,
	Leaf = WildwoodStyle.World.FoliageLight,
	Cream = WildwoodStyle.World.Flower,
	Lavender = WildwoodStyle.World.Water,
	Pink = WildwoodStyle.World.RoofHighlight,
	Tea = WildwoodStyle.World.RoofTile,
	TeaGlow = WildwoodStyle.World.Lantern,
	Lemon = WildwoodStyle.World.Window,
	Glass = WildwoodStyle.World.Glass,
}

local function transformed(root, scale, x, y, z, rx, ry, rz)
	return root
		* CFrame.new(x * scale, y * scale, z * scale)
		* CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function piece(model, name, size, cframe, color, material, shape, transparency)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Shape = shape or Enum.PartType.Block
	object.Transparency = transparency or 0
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = transparency == nil or transparency < 0.4
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = model
	return object
end

local function ball(model, name, diameter, cframe, color, material, transparency)
	return piece(model, name, Vector3.new(diameter, diameter, diameter), cframe, color, material, Enum.PartType.Ball, transparency)
end

-- Roblox cylinders run along local X. Rotating 90 degrees around Z stands
-- them upright, producing a genuinely round plate, pastry or drink volume.
local function uprightCylinder(model, name, height, diameter, root, scale, x, y, z, color, material, transparency)
	return piece(
		model,
		name,
		Vector3.new(height * scale, diameter * scale, diameter * scale),
		transformed(root, scale, x, y, z, 0, 0, 90),
		color,
		material,
		Enum.PartType.Cylinder,
		transparency
	)
end

local function plate(model, root, scale)
	local base = uprightCylinder(model, "CeramicPlate", 0.1, 1.72, root, scale, 0, 0.08, 0, COLORS.Plate, Enum.Material.SmoothPlastic)
	uprightCylinder(model, "PlateRim", 0.035, 1.9, root, scale, 0, 0.145, 0, WildwoodStyle.World.Glass, Enum.Material.SmoothPlastic)
	return base
end

local function addBerry(model, root, scale, index, x, y, z, diameter)
	local berry = ball(
		model,
		string.format("MoonBerry%02d", index),
		diameter * scale,
		transformed(root, scale, x, y, z),
		index % 2 == 0 and COLORS.BerryGlow or COLORS.Berry,
		Enum.Material.Neon
	)
	if index == 1 then
		local glow = Instance.new("PointLight")
		glow.Name = "BerryGlow"
		glow.Color = COLORS.BerryGlow
		glow.Brightness = 0.35
		glow.Range = 3 * scale
		glow.Parent = berry
	end
	return berry
end

local function buildTart(model, root, scale)
	local primary = plate(model, root, scale)
	uprightCylinder(model, "GoldenTartCrust", 0.3, 1.38, root, scale, 0, 0.29, 0, COLORS.Crust, Enum.Material.SmoothPlastic)
	uprightCylinder(model, "MoonBerryFilling", 0.11, 1.12, root, scale, 0, 0.5, 0, WildwoodStyle.World.Water, Enum.Material.SmoothPlastic)

	for index = 1, 12 do
		local angle = (index - 1) * math.pi * 2 / 12
		ball(
			model,
			string.format("BraidedCrust%02d", index),
			0.22 * scale,
			transformed(root, scale, math.cos(angle) * 0.62, 0.53, math.sin(angle) * 0.62),
			index % 2 == 0 and COLORS.CrustLight or COLORS.Crust,
			Enum.Material.SmoothPlastic
		)
	end

	for index, berryAt in ipairs({
		{ -0.3, 0.65, -0.16 },
		{ 0.05, 0.68, -0.25 },
		{ 0.32, 0.64, -0.03 },
		{ -0.12, 0.67, 0.18 },
		{ 0.2, 0.66, 0.25 },
	}) do
		addBerry(model, root, scale, index, berryAt[1], berryAt[2], berryAt[3], 0.3)
	end

	piece(model, "MintLeafLeft", Vector3.new(0.4, 0.08, 0.2) * scale, transformed(root, scale, -0.13, 0.78, 0.02, 0, -25, 18), COLORS.Leaf, Enum.Material.SmoothPlastic)
	piece(model, "MintLeafRight", Vector3.new(0.4, 0.08, 0.2) * scale, transformed(root, scale, 0.13, 0.78, 0.04, 0, 25, -18), COLORS.Leaf, Enum.Material.SmoothPlastic)
	return primary, "Tart"
end

local function buildCake(model, root, scale)
	local primary = plate(model, root, scale)
	uprightCylinder(model, "LavenderCakeLower", 0.5, 1.42, root, scale, 0, 0.39, 0, COLORS.Lavender, Enum.Material.SmoothPlastic)
	uprightCylinder(model, "VanillaFrostingLower", 0.14, 1.5, root, scale, 0, 0.7, 0, COLORS.Cream, Enum.Material.SmoothPlastic)
	uprightCylinder(model, "MoonberryCakeUpper", 0.4, 1.04, root, scale, 0, 0.96, 0, WildwoodStyle.World.WaterLight, Enum.Material.SmoothPlastic)
	uprightCylinder(model, "VanillaFrostingTop", 0.14, 1.13, root, scale, 0, 1.23, 0, COLORS.Cream, Enum.Material.SmoothPlastic)

	for index = 1, 8 do
		local angle = (index - 1) * math.pi * 2 / 8
		ball(
			model,
			string.format("FrostingDollop%02d", index),
			0.25 * scale,
			transformed(root, scale, math.cos(angle) * 0.43, 1.35, math.sin(angle) * 0.43),
			COLORS.Cream,
			Enum.Material.SmoothPlastic
		)
	end
	addBerry(model, root, scale, 1, -0.18, 1.48, -0.03, 0.29)
	addBerry(model, root, scale, 2, 0.16, 1.48, 0.02, 0.29)
	ball(model, "MoonTopper", 0.3 * scale, transformed(root, scale, 0, 1.72, 0), COLORS.BerryGlow, Enum.Material.Neon)
	piece(model, "MoonTopperInset", Vector3.new(0.25, 0.25, 0.14) * scale, transformed(root, scale, 0.1, 1.77, -0.1), COLORS.Cream, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	return primary, "LayerCake"
end

local function buildCupcake(model, root, scale)
	local primary = plate(model, root, scale)
	uprightCylinder(model, "CupcakeWrapper", 0.52, 0.94, root, scale, 0, 0.4, 0, WildwoodStyle.World.Terracotta, Enum.Material.Fabric)

	for index = 1, 10 do
		local angle = (index - 1) * math.pi * 2 / 10
		piece(
			model,
			string.format("WrapperRidge%02d", index),
			Vector3.new(0.055, 0.48, 0.055) * scale,
			transformed(root, scale, math.cos(angle) * 0.45, 0.41, math.sin(angle) * 0.45),
			COLORS.Pink,
			Enum.Material.SmoothPlastic
		)
	end

	ball(model, "FrostingBase", 0.92 * scale, transformed(root, scale, 0, 0.74, 0), COLORS.Cream, Enum.Material.SmoothPlastic)
	ball(model, "FrostingMiddle", 0.68 * scale, transformed(root, scale, 0, 1.04, 0), WildwoodStyle.World.CanvasLight, Enum.Material.SmoothPlastic)
	ball(model, "FrostingPeak", 0.42 * scale, transformed(root, scale, 0, 1.28, 0), COLORS.Cream, Enum.Material.SmoothPlastic)

	ball(model, "StarCenter", 0.24 * scale, transformed(root, scale, 0, 1.58, -0.03), COLORS.TeaGlow, Enum.Material.Neon)
	for index = 1, 5 do
		local angle = math.rad(-90 + (index - 1) * 72)
		ball(
			model,
			string.format("StarPoint%02d", index),
			0.17 * scale,
			transformed(root, scale, math.cos(angle) * 0.25, 1.58 + math.sin(angle) * 0.25, -0.03),
			COLORS.TeaGlow,
			Enum.Material.Neon
		)
	end
	return primary, "Cupcake"
end

local function buildTea(model, root, scale)
	local primary = plate(model, root, scale)
	uprightCylinder(model, "GoldenTea", 0.62, 0.74, root, scale, 0, 0.46, 0, COLORS.Tea, Enum.Material.Neon, 0.08)
	uprightCylinder(model, "GlassCup", 0.78, 0.9, root, scale, 0, 0.48, 0, COLORS.Glass, Enum.Material.Glass, 0.55)
	uprightCylinder(model, "TeaSurface", 0.04, 0.76, root, scale, 0, 0.81, 0, COLORS.TeaGlow, Enum.Material.Neon, 0.08)

	for index, segment in ipairs({
		{ 0.52, 0.64, 0, 0.08, 0.3, 0.08, 18 },
		{ 0.65, 0.47, 0, 0.08, 0.28, 0.08, 0 },
		{ 0.52, 0.3, 0, 0.08, 0.3, 0.08, -18 },
	}) do
		piece(
			model,
			string.format("GlassHandle%02d", index),
			Vector3.new(segment[4], segment[5], segment[6]) * scale,
			transformed(root, scale, segment[1], segment[2], segment[3], 0, 0, segment[7]),
			COLORS.Glass,
			Enum.Material.Glass,
			Enum.PartType.Block,
			0.35
		)
	end

	-- A vertical lemon wheel hangs on the front lip of the glass.
	piece(model, "LemonWheel", Vector3.new(0.08, 0.48, 0.48) * scale, transformed(root, scale, 0.2, 0.76, -0.43, 0, 90, 0), COLORS.Lemon, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(model, "LemonCentre", Vector3.new(0.085, 0.29, 0.29) * scale, transformed(root, scale, 0.2, 0.76, -0.47, 0, 90, 0), WildwoodStyle.World.CanvasLight, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(model, "TeaLeaf", Vector3.new(0.42, 0.06, 0.2) * scale, transformed(root, scale, -0.18, 0.92, -0.05, 0, 20, 20), COLORS.Leaf, Enum.Material.SmoothPlastic)

	for index = 1, 3 do
		ball(
			model,
			string.format("SteamWisp%02d", index),
			(0.2 + index * 0.04) * scale,
			transformed(root, scale, (index % 2 == 0 and 0.12 or -0.1), 0.98 + index * 0.23, 0),
			WildwoodStyle.World.Glass,
			Enum.Material.Neon,
			0.45 + index * 0.1
		)
	end
	return primary, "TeaCup"
end

local BUILDERS = {
	MoonBerryTart = buildTart,
	MoonberryCake = buildCake,
	StarCupcake = buildCupcake,
	SunTea = buildTea,
}

function CafeModels.build(parent, itemId, baseCFrame, scale)
	local builder = BUILDERS[itemId]
	assert(builder, string.format("Unknown cafe item model: %s", tostring(itemId)))

	local model = Instance.new("Model")
	model.Name = itemId .. "3D"
	model:SetAttribute("CafeItemId", itemId)
	model:SetAttribute("CafeFood3D", true)
	model.Parent = parent

	local primary, geometryKind = builder(model, baseCFrame, scale or 1)
	model.PrimaryPart = primary
	model:SetAttribute("GeometryKind", geometryKind)
	CollectionService:AddTag(model, CafeModels.Tag)
	return model
end

return CafeModels
