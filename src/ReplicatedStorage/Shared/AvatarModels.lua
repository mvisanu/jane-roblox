--[[
	Approved woodland avatar builder.

	All six characters use the classic Roblox block silhouette: rectangular head,
	square torso, straight block arms and legs. The player's Humanoid and animated
	joints stay in place underneath, while these visual blocks follow each body
	part with welds. The same builder renders the Style-menu ViewportFrames.

	"Original" is deliberately not a preset. AvatarModels.Clear restores the
	player's own Roblox appearance and is the default until they choose a model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))

local AvatarModels = {}

AvatarModels.OriginalId = "Original"
AvatarModels.VisualName = "ApprovedWoodlandAvatar"
AvatarModels.LegacyVisualNames = { "WildwoodAvatarVisual", "WildwoodExplorerKit" }
AvatarModels.PreviewCameraCFrame = CFrame.lookAt(Vector3.new(3.2, 3.8, -10.3), Vector3.new(0, 2.25, 0))
AvatarModels.PreviewFocus = Vector3.new(0, 2.25, 0)

local ORIGINAL_TRANSPARENCY = "ApprovedAvatarOriginalTransparency"
local ORIGINAL_DECAL_TRANSPARENCY = "ApprovedAvatarOriginalDecalTransparency"

local function isAvatar(outfit)
	return type(outfit) == "table"
		and type(outfit.Style) == "string"
		and (outfit.Gender == "Male" or outfit.Gender == "Female")
		and outfit.Palette ~= nil
end

function AvatarModels.IsAvatarId(avatarId)
	return isAvatar(type(avatarId) == "string" and Catalog.Outfits[avatarId] or nil)
end

local function restoreOriginal(character)
	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") then
			local saved = object:GetAttribute(ORIGINAL_TRANSPARENCY)
			if saved ~= nil then
				object.Transparency = saved
				object:SetAttribute(ORIGINAL_TRANSPARENCY, nil)
			end
		elseif object:IsA("Decal") then
			local saved = object:GetAttribute(ORIGINAL_DECAL_TRANSPARENCY)
			if saved ~= nil then
				object.Transparency = saved
				object:SetAttribute(ORIGINAL_DECAL_TRANSPARENCY, nil)
			end
		end
	end
end

function AvatarModels.Clear(character)
	local current = character:FindFirstChild(AvatarModels.VisualName)
	if current then
		current:Destroy()
	end
	for _, name in ipairs(AvatarModels.LegacyVisualNames) do
		local legacy = character:FindFirstChild(name)
		if legacy then
			legacy:Destroy()
		end
	end
	local legacyHighlight = character:FindFirstChild("FamilyTownStyle")
	if legacyHighlight then
		legacyHighlight:Destroy()
	end
	restoreOriginal(character)
end

local function hideOriginal(character)
	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") and object.Name ~= "HumanoidRootPart" then
			object:SetAttribute(ORIGINAL_TRANSPARENCY, object.Transparency)
			object.Transparency = 1
		elseif object:IsA("Decal") then
			object:SetAttribute(ORIGINAL_DECAL_TRANSPARENCY, object.Transparency)
			object.Transparency = 1
		end
	end
end

local function findFirst(character, names)
	for _, name in ipairs(names) do
		local target = character:FindFirstChild(name)
		if target and target:IsA("BasePart") then
			return target
		end
	end
	return nil
end

local function piece(visual, name, target, size, offset, color, material, className, shape)
	if not target then
		return nil
	end
	local object = Instance.new(className or "Part")
	object.Name = name
	object.Size = size
	object.CFrame = target.CFrame * (offset or CFrame.new())
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = false
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = true
	object.Massless = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		object.Shape = shape
	end
	object:SetAttribute("ApprovedAvatarPiece", true)
	object.Parent = visual

	local weld = Instance.new("WeldConstraint")
	weld.Name = "ApprovedAvatarWeld"
	weld.Part0 = target
	weld.Part1 = object
	weld.Parent = object
	return object
end

local function block(visual, name, target, size, offset, color, material)
	return piece(visual, name, target, size, offset, color, material)
end

local function wedge(visual, name, target, size, offset, color, material)
	return piece(visual, name, target, size, offset, color, material, "WedgePart")
end

local function cylinder(visual, name, target, size, offset, color, material)
	return piece(visual, name, target, size, offset, color, material, "Part", Enum.PartType.Cylinder)
end

local function orb(visual, name, target, diameter, offset, color, material)
	return piece(visual, name, target, Vector3.new(diameter, diameter, diameter), offset, color, material, "Part", Enum.PartType.Ball)
end

-- Small authored geometry replaces unavailable uploaded clothing textures.
-- These details remain actual 3D parts in both the live avatar and ViewportFrame.
local function fernMotif(visual, prefix, target, x, y, z, color, scale)
	scale = scale or 1
	block(visual, prefix .. "Stem", target, Vector3.new(0.045, 0.58, 0.035) * scale, CFrame.new(x, y, z), color, Enum.Material.Fabric)
	for index = 1, 3 do
		local leafY = y - 0.2 * scale + index * 0.14 * scale
		local width = (0.19 - index * 0.018) * scale
		block(visual, prefix .. "LeftLeaf" .. index, target, Vector3.new(width, 0.055 * scale, 0.035), CFrame.new(x - 0.09 * scale, leafY, z - 0.006) * CFrame.Angles(0, 0, math.rad(-28)), color, Enum.Material.Fabric)
		block(visual, prefix .. "RightLeaf" .. index, target, Vector3.new(width, 0.055 * scale, 0.035), CFrame.new(x + 0.09 * scale, leafY + 0.035 * scale, z - 0.006) * CFrame.Angles(0, 0, math.rad(28)), color, Enum.Material.Fabric)
	end
end

local function addBootLaces(visual, character, palette)
	for _, side in ipairs({ "Left", "Right" }) do
		local leg = findFirst(character, { side .. " Leg", side .. "UpperLeg" })
		if leg then
			for index = 1, 3 do
				block(visual, side .. "BootLace" .. index, leg, Vector3.new(0.7, 0.055, 0.045), CFrame.new(0, -0.48 - index * 0.12, -0.75), palette.Accent, Enum.Material.Fabric)
			end
			block(visual, side .. "BootSole", leg, Vector3.new(1.1, 0.12, 1.32), CFrame.new(0, -1.0, -0.1), palette.Deep, Enum.Material.Fabric)
		end
	end
end

local function addCargoPockets(visual, character, palette)
	for _, side in ipairs({ "Left", "Right" }) do
		local leg = findFirst(character, { side .. " Leg", side .. "UpperLeg" })
		if leg then
			block(visual, side .. "CargoPocket", leg, Vector3.new(0.7, 0.46, 0.1), CFrame.new(0, 0.42, -0.56), palette.Leather, Enum.Material.Fabric)
			block(visual, side .. "CargoPocketFlap", leg, Vector3.new(0.72, 0.12, 0.12), CFrame.new(0, 0.61, -0.62), palette.Secondary, Enum.Material.Fabric)
		end
	end
end

local function addSleeveTrim(visual, character, palette)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		if arm then
			block(visual, side .. "SleeveCuff", arm, Vector3.new(1.08, 0.18, 1.08), CFrame.new(0, -0.3, 0), palette.Leather, Enum.Material.Fabric)
			block(visual, side .. "SleeveStitch", arm, Vector3.new(1.1, 0.05, 0.05), CFrame.new(0, -0.18, -0.55), palette.Accent, Enum.Material.Fabric)
		end
	end
end

local function addJacketTailTrim(visual, prefix, torso, color)
	for _, side in ipairs({ -1, 1 }) do
		block(visual, prefix .. (side < 0 and "Left" or "Right"), torso, Vector3.new(0.78, 0.065, 0.04), CFrame.new(side * 0.47, -1.11, -0.68) * CFrame.Angles(0, 0, math.rad(side * 7)), color, Enum.Material.Fabric)
	end
end

local function addFace(visual, head, skin, palette)
	block(visual, "BlockHead", head, Vector3.new(2.04, 1.48, 1.5), CFrame.new(0, 0.22, 0), skin)
	for index, x in ipairs({ -0.38, 0.38 }) do
		block(visual, "FaceEye" .. index, head, Vector3.new(0.16, 0.25, 0.055), CFrame.new(x, 0.28, -0.775), Color3.fromRGB(37, 31, 26))
		block(visual, "FaceEyeGlint" .. index, head, Vector3.new(0.045, 0.055, 0.025), CFrame.new(x - 0.025, 0.34, -0.81), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	end
	block(visual, "FriendlySmile", head, Vector3.new(0.22, 0.06, 0.045), CFrame.new(0, -0.1, -0.785), Color3.fromRGB(112, 64, 55))
	block(visual, "LeftSmileCurve", head, Vector3.new(0.2, 0.055, 0.045), CFrame.new(-0.18, -0.06, -0.785) * CFrame.Angles(0, 0, math.rad(-18)), Color3.fromRGB(112, 64, 55))
	block(visual, "RightSmileCurve", head, Vector3.new(0.2, 0.055, 0.045), CFrame.new(0.18, -0.06, -0.785) * CFrame.Angles(0, 0, math.rad(18)), Color3.fromRGB(112, 64, 55))
	block(visual, "LeftBrow", head, Vector3.new(0.34, 0.055, 0.04), CFrame.new(-0.38, 0.51, -0.785) * CFrame.Angles(0, 0, math.rad(-7)), palette.Hair)
	block(visual, "RightBrow", head, Vector3.new(0.34, 0.055, 0.04), CFrame.new(0.38, 0.51, -0.785) * CFrame.Angles(0, 0, math.rad(7)), palette.Hair)
end

local function addMaleHair(visual, head, palette, style)
	block(visual, "HairTop", head, Vector3.new(2.08, 0.48, 1.53), CFrame.new(0, 0.83, 0.03), palette.Hair, Enum.Material.Fabric)
	block(visual, "HairBack", head, Vector3.new(2.04, 0.72, 0.34), CFrame.new(0, 0.46, 0.71), palette.Hair, Enum.Material.Fabric)
	if style == "MaleRiverWarden" then
		-- Low, glossy side sweep from the approved middle character.
		for index, entry in ipairs({
			{ -0.72, 0.76, -18, 0.72 },
			{ -0.3, 0.84, -12, 0.8 },
			{ 0.15, 0.9, 8, 0.72 },
			{ 0.56, 0.84, 18, 0.62 },
		}) do
			wedge(visual, "SideSweptFringe" .. index, head, Vector3.new(0.52, entry[4], 0.5), CFrame.new(entry[1], entry[2], -0.43) * CFrame.Angles(0, math.rad(180), math.rad(entry[3])), palette.Hair, Enum.Material.Fabric)
		end
		block(visual, "RiverSideSweep", head, Vector3.new(1.18, 0.25, 0.34), CFrame.new(-0.3, 0.62, -0.66) * CFrame.Angles(0, 0, math.rad(-12)), palette.Hair, Enum.Material.Fabric)
	else
		local archer = style == "MaleAutumnArcher"
		for index, x in ipairs({ -0.88, -0.56, -0.22, 0.14, 0.5, 0.84 }) do
			local tilt = (x < 0 and -1 or 1) * (archer and 20 or 14)
			wedge(visual, "HairSpike" .. index, head, Vector3.new(0.46, archer and 0.7 or 0.6, 0.46), CFrame.new(x, 0.92 + math.abs(x) * 0.1, -0.3) * CFrame.Angles(0, math.rad(180), math.rad(tilt)), palette.Hair, Enum.Material.Fabric)
		end
		if archer then
			wedge(visual, "AutumnCrownSpike", head, Vector3.new(0.52, 0.82, 0.48), CFrame.new(0.12, 1.14, 0.05) * CFrame.Angles(0, math.rad(180), math.rad(10)), palette.Hair, Enum.Material.Fabric)
		end
	end
	block(visual, "LeftSideburn", head, Vector3.new(0.28, 0.55, 0.34), CFrame.new(-0.9, 0.38, -0.48), palette.Hair, Enum.Material.Fabric)
	block(visual, "RightSideburn", head, Vector3.new(0.28, 0.55, 0.34), CFrame.new(0.9, 0.38, -0.48), palette.Hair, Enum.Material.Fabric)
end

local function addFemaleHair(visual, head, torso, palette, style)
	block(visual, "HairTop", head, Vector3.new(2.1, 0.48, 1.54), CFrame.new(0, 0.83, 0.03), palette.Hair, Enum.Material.Fabric)
	if style == "FemaleWildflowerBotanist" then
		block(visual, "LongWavyHairBack", head, Vector3.new(1.96, 1.82, 0.34), CFrame.new(0, -0.2, 0.72), palette.Hair, Enum.Material.Fabric)
		for index, side in ipairs({ -1, 1 }) do
			for segment = 1, 3 do
				orb(visual, (side < 0 and "Left" or "Right") .. "WavyLock" .. segment, head, 0.42, CFrame.new(side * (0.82 + segment * 0.03), 0.45 - segment * 0.42, -0.48), palette.Hair, Enum.Material.Fabric)
			end
		end
	elseif style == "FemaleFernGuardian" then
		block(visual, "GuardianHairBack", head, Vector3.new(1.75, 0.75, 0.34), CFrame.new(0, 0.34, 0.72), palette.Hair, Enum.Material.Fabric)
		orb(visual, "GuardianHairBunBase", head, 0.78, CFrame.new(0, 1.15, 0.28), palette.Hair, Enum.Material.Fabric)
		orb(visual, "GuardianHairBunTop", head, 0.62, CFrame.new(0.1, 1.48, 0.24), palette.Hair, Enum.Material.Fabric)
		for _, side in ipairs({ -1, 1 }) do
			for segment = 1, 4 do
				block(visual, (side < 0 and "Left" or "Right") .. "GuardianBraid" .. segment, torso, Vector3.new(0.28, 0.42, 0.28), CFrame.new(side * 0.72, 0.82 - segment * 0.34, -0.66) * CFrame.Angles(0, 0, math.rad(side * (segment % 2 == 0 and 8 or -8))), palette.Hair, Enum.Material.Fabric)
			end
		end
	else
		block(visual, "ScoutHairBack", head, Vector3.new(1.75, 1.2, 0.3), CFrame.new(0, 0.02, 0.7), palette.Hair, Enum.Material.Fabric)
		block(visual, "ScoutSideFringe", head, Vector3.new(0.82, 0.24, 0.34), CFrame.new(-0.28, 0.58, -0.68) * CFrame.Angles(0, 0, math.rad(-12)), palette.Hair, Enum.Material.Fabric)
		for segment = 1, 5 do
			block(visual, "ScoutBraid" .. segment, torso, Vector3.new(0.3, 0.42, 0.3), CFrame.new(0.74, 0.8 - segment * 0.34, -0.66) * CFrame.Angles(0, 0, math.rad(segment % 2 == 0 and 8 or -8)), palette.Hair, Enum.Material.Fabric)
		end
	end
end

local function addR6Body(visual, character, palette, skin)
	local torso = character:FindFirstChild("Torso")
	block(visual, "BlockTorso", torso, Vector3.new(2.08, 2.05, 1.08), CFrame.new(), palette.Primary, Enum.Material.Fabric)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = character:FindFirstChild(side .. " Arm")
		local leg = character:FindFirstChild(side .. " Leg")
		if arm then
			block(visual, side .. "BlockSleeve", arm, Vector3.new(1.05, 1.42, 1.05), CFrame.new(0, 0.29, 0), palette.Primary, Enum.Material.Fabric)
			block(visual, side .. "BlockHand", arm, Vector3.new(0.95, 0.62, 0.95), CFrame.new(0, -0.72, 0), skin)
		end
		if leg then
			block(visual, side .. "BlockTrouser", leg, Vector3.new(1.05, 1.38, 1.05), CFrame.new(0, 0.31, 0), palette.Deep, Enum.Material.Fabric)
			block(visual, side .. "BlockBoot", leg, Vector3.new(1.06, 0.72, 1.28), CFrame.new(0, -0.67, -0.1), palette.Leather, Enum.Material.Fabric)
		end
	end
	return torso
end

local function addR15Body(visual, character, palette, skin)
	local upper = character:FindFirstChild("UpperTorso")
	local styleAnchor
	-- Render a single classic R6-shaped shell over an R15 animation skeleton.
	-- This prevents a player's R15 scale from changing the approved silhouettes.
	if upper then
		block(visual, "BlockTorso", upper, Vector3.new(2.08, 2.05, 1.08), CFrame.new(0, -0.3, 0), palette.Primary, Enum.Material.Fabric)
		styleAnchor = block(visual, "StyleTorsoAnchor", upper, Vector3.new(0.1, 0.1, 0.1), CFrame.new(0, -0.3, 0), palette.Primary)
		styleAnchor.Transparency = 1
		styleAnchor.CastShadow = false
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = character:FindFirstChild(side .. "UpperArm")
		local leg = character:FindFirstChild(side .. "UpperLeg")
		if arm then
			block(visual, side .. "BlockSleeve", arm, Vector3.new(1.05, 1.42, 1.05), CFrame.new(0, -0.24, 0), palette.Primary, Enum.Material.Fabric)
			block(visual, side .. "BlockHand", arm, Vector3.new(0.95, 0.62, 0.95), CFrame.new(0, -1.25, 0), skin)
		end
		if leg then
			block(visual, side .. "BlockTrouser", leg, Vector3.new(1.05, 1.38, 1.05), CFrame.new(0, -0.22, 0), palette.Deep, Enum.Material.Fabric)
			block(visual, side .. "BlockBoot", leg, Vector3.new(1.06, 0.72, 1.28), CFrame.new(0, -1.22, -0.1), palette.Leather, Enum.Material.Fabric)
		end
	end
	return styleAnchor or upper
end

local function addSharedClothing(visual, character, torso, palette, style)
	block(visual, "JacketFront", torso, Vector3.new(1.78, 1.68, 0.12), CFrame.new(0, 0.08, -0.6), palette.Primary, Enum.Material.Fabric)
	block(visual, "JacketLeftSeam", torso, Vector3.new(0.045, 1.58, 0.035), CFrame.new(-0.74, 0.08, -0.68), palette.Accent, Enum.Material.Fabric)
	block(visual, "JacketRightSeam", torso, Vector3.new(0.045, 1.58, 0.035), CFrame.new(0.74, 0.08, -0.68), palette.Accent, Enum.Material.Fabric)
	block(visual, "JacketCenterSeam", torso, Vector3.new(0.045, 1.38, 0.035), CFrame.new(0, 0.12, -0.69), palette.Deep, Enum.Material.Fabric)
	for index = 1, 3 do
		orb(visual, "JacketButton" .. index, torso, 0.1, CFrame.new(0.12, 0.5 - index * 0.34, -0.71), palette.Accent, Enum.Material.Metal)
	end
	wedge(visual, "LeftShirtCollar", torso, Vector3.new(0.52, 0.38, 0.12), CFrame.new(-0.28, 0.78, -0.68) * CFrame.Angles(0, math.rad(180), math.rad(-16)), palette.Light, Enum.Material.Fabric)
	wedge(visual, "RightShirtCollar", torso, Vector3.new(0.52, 0.38, 0.12), CFrame.new(0.28, 0.78, -0.68) * CFrame.Angles(0, math.rad(180), math.rad(16)), palette.Light, Enum.Material.Fabric)
	block(visual, "LeatherBelt", torso, Vector3.new(2.1, 0.22, 1.15), CFrame.new(0, -0.5, 0), palette.Leather, Enum.Material.Fabric)
	block(visual, "BeltBuckle", torso, Vector3.new(0.3, 0.3, 0.12), CFrame.new(0, -0.5, -0.64), palette.Accent, Enum.Material.Metal)
	block(visual, "LeftJacketHem", torso, Vector3.new(0.82, 0.58, 0.14), CFrame.new(-0.47, -0.83, -0.59), palette.Secondary, Enum.Material.Fabric)
	block(visual, "RightJacketHem", torso, Vector3.new(0.82, 0.58, 0.14), CFrame.new(0.47, -0.83, -0.59), palette.Secondary, Enum.Material.Fabric)
	addJacketTailTrim(visual, "JacketHemTrim", torso, palette.Accent)
	addSleeveTrim(visual, character, palette)
	if style ~= "FemaleFernGuardian" then
		addBootLaces(visual, character, palette)
	end
	if style == "MaleTrailRanger" or style == "MaleAutumnArcher" or style == "FemaleWildflowerBotanist" or style == "FemalePineScout" then
		addCargoPockets(visual, character, palette)
	end
end

local function crossBodyStrap(visual, name, torso, palette, direction)
	block(visual, name, torso, Vector3.new(0.18, 2.15, 0.12), CFrame.new(0, 0.12, -0.67) * CFrame.Angles(0, 0, math.rad(direction * 28)), palette.Leather, Enum.Material.Fabric)
end

local function addTrailRanger(visual, character, head, torso, palette)
	block(visual, "TrailScarf", torso, Vector3.new(1.35, 0.32, 0.22), CFrame.new(0, 0.87, -0.55), palette.Secondary, Enum.Material.Fabric)
	block(visual, "TrailScarfKnot", torso, Vector3.new(0.32, 0.32, 0.2), CFrame.new(0, 0.68, -0.7) * CFrame.Angles(0, 0, math.rad(45)), palette.Secondary, Enum.Material.Fabric)
	block(visual, "TrailScarfTail", torso, Vector3.new(0.18, 0.62, 0.12), CFrame.new(0.16, 0.38, -0.68) * CFrame.Angles(0, 0, math.rad(-8)), palette.Secondary, Enum.Material.Fabric)
	crossBodyStrap(visual, "TrailMapStrap", torso, palette, 1)
	block(visual, "TrailChestPocket", torso, Vector3.new(0.54, 0.46, 0.1), CFrame.new(-0.48, 0.36, -0.7), palette.Secondary, Enum.Material.Fabric)
	block(visual, "TrailChestPocketFlap", torso, Vector3.new(0.56, 0.11, 0.12), CFrame.new(-0.48, 0.53, -0.74), palette.Leather, Enum.Material.Fabric)
	block(visual, "TrailMapPouch", torso, Vector3.new(0.7, 0.68, 0.26), CFrame.new(-0.72, -0.42, -0.68), palette.Light, Enum.Material.Fabric)
	for index = 1, 3 do
		block(visual, "TrailMapLine" .. index, torso, Vector3.new(0.42 - index * 0.05, 0.035, 0.025), CFrame.new(-0.72, -0.2 - index * 0.12, -0.83) * CFrame.Angles(0, 0, math.rad(index % 2 == 0 and -18 or 18)), palette.Leather)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		fernMotif(visual, side .. "SleeveFern", arm, 0, 0.34, -0.58, palette.Accent, 0.7)
		block(visual, side .. "FernPatch", arm, Vector3.new(0.52, 0.05, 0.035), CFrame.new(0, 0.06, -0.59), palette.Accent, Enum.Material.Fabric)
		local leg = findFirst(character, { side .. " Leg", side .. "UpperLeg" })
		fernMotif(visual, side .. "TrouserFern", leg, 0, 0.36, -0.58, palette.Secondary, 0.55)
	end
end

local function addRiverWarden(visual, character, head, torso, palette)
	block(visual, "RiverMantle", torso, Vector3.new(2.32, 0.36, 1.25), CFrame.new(0, 0.83, 0), palette.Deep, Enum.Material.Fabric)
	block(visual, "RiverMantleTrim", torso, Vector3.new(2.36, 0.09, 1.29), CFrame.new(0, 0.64, 0), palette.Accent, Enum.Material.Metal)
	wedge(visual, "RiverLeftPauldron", torso, Vector3.new(0.7, 0.42, 1.18), CFrame.new(-1.0, 0.75, 0) * CFrame.Angles(0, math.rad(180), 0), palette.Primary, Enum.Material.Fabric)
	wedge(visual, "RiverRightPauldron", torso, Vector3.new(0.7, 0.42, 1.18), CFrame.new(1.0, 0.75, 0) * CFrame.Angles(0, math.rad(180), 0), palette.Primary, Enum.Material.Fabric)
	cylinder(visual, "RiverBrooch", torso, Vector3.new(0.1, 0.34, 0.34), CFrame.new(0, 0.68, -0.68) * CFrame.Angles(0, math.rad(90), 0), palette.Light, Enum.Material.Metal)
	fernMotif(visual, "RiverMantleFern", torso, -0.48, 0.53, -0.7, palette.Light, 0.55)
	crossBodyStrap(visual, "RiverWardenStrap", torso, palette, -1)
	block(visual, "RiverCoatLeftPanel", torso, Vector3.new(0.82, 0.86, 0.14), CFrame.new(-0.48, -0.92, -0.59), palette.Primary, Enum.Material.Fabric)
	block(visual, "RiverCoatRightPanel", torso, Vector3.new(0.82, 0.86, 0.14), CFrame.new(0.48, -0.92, -0.59), palette.Primary, Enum.Material.Fabric)
	block(visual, "RiverCoatLeftTrim", torso, Vector3.new(0.05, 0.82, 0.035), CFrame.new(-0.88, -0.92, -0.68), palette.Accent, Enum.Material.Fabric)
	block(visual, "RiverCoatRightTrim", torso, Vector3.new(0.05, 0.82, 0.035), CFrame.new(0.88, -0.92, -0.68), palette.Accent, Enum.Material.Fabric)
	for index, x in ipairs({ -0.14, 0.14 }) do
		block(visual, "RiverTasselCord" .. index, torso, Vector3.new(0.055, 0.48, 0.045), CFrame.new(x, 0.34, -0.72), palette.Accent, Enum.Material.Fabric)
		orb(visual, "RiverTassel" .. index, torso, 0.13, CFrame.new(x, 0.08, -0.72), palette.Accent, Enum.Material.Fabric)
	end
	local arm = findFirst(character, { "Right Arm", "RightHand", "RightLowerArm" }) or torso
	block(visual, "LanternFrame", arm, Vector3.new(0.62, 0.82, 0.62), CFrame.new(0.12, -0.82, -0.18), palette.Leather, Enum.Material.Metal)
	block(visual, "LanternGlow", arm, Vector3.new(0.4, 0.54, 0.4), CFrame.new(0.12, -0.82, -0.18), palette.Accent, Enum.Material.Neon)
	block(visual, "LanternHandle", arm, Vector3.new(0.12, 0.55, 0.12), CFrame.new(0.12, -0.22, -0.18), palette.Leather, Enum.Material.Metal)
	for index, x in ipairs({ -0.16, 0.4 }) do
		block(visual, "LanternRail" .. index, arm, Vector3.new(0.07, 0.82, 0.07), CFrame.new(x, -0.82, -0.5), palette.Deep, Enum.Material.Metal)
	end
end

local function addAutumnArcher(visual, character, head, torso, palette)
	block(visual, "AutumnScarf", torso, Vector3.new(1.45, 0.38, 0.24), CFrame.new(0, 0.84, -0.55), palette.Secondary, Enum.Material.Fabric)
	block(visual, "AutumnScarfFold", torso, Vector3.new(1.28, 0.13, 0.08), CFrame.new(0, 0.92, -0.7), palette.Accent, Enum.Material.Fabric)
	block(visual, "AutumnScarfTail", torso, Vector3.new(0.28, 0.72, 0.12), CFrame.new(-0.28, 0.46, -0.69) * CFrame.Angles(0, 0, math.rad(12)), palette.Secondary, Enum.Material.Fabric)
	crossBodyStrap(visual, "ArcherChestStrap", torso, palette, -1)
	crossBodyStrap(visual, "ArcherSecondStrap", torso, palette, 1)
	for _, x in ipairs({ -0.65, 0.65 }) do
		block(visual, x < 0 and "ArcherLeftPouch" or "ArcherRightPouch", torso, Vector3.new(0.5, 0.45, 0.25), CFrame.new(x, -0.52, -0.68), palette.Leather, Enum.Material.Fabric)
	end
	block(visual, "AutumnTunicTrim", torso, Vector3.new(1.86, 0.08, 0.04), CFrame.new(0, -1.08, -0.68), palette.Secondary, Enum.Material.Fabric)
	for index, x in ipairs({ -0.7, -0.35, 0, 0.35, 0.7 }) do
		wedge(visual, "AutumnPointedHem" .. index, torso, Vector3.new(0.34, 0.28, 0.12), CFrame.new(x, -1.18, -0.62) * CFrame.Angles(0, math.rad(180), 0), palette.Secondary, Enum.Material.Fabric)
	end
	block(visual, "CompactQuiver", torso, Vector3.new(0.48, 1.55, 0.42), CFrame.new(0.72, 0.18, 0.73) * CFrame.Angles(0, 0, math.rad(-14)), palette.Leather, Enum.Material.Wood)
	for index, x in ipairs({ 0.58, 0.72, 0.86 }) do
		block(visual, "Arrow" .. index, torso, Vector3.new(0.09, 1.55, 0.09), CFrame.new(x, 0.75, 0.78) * CFrame.Angles(0, 0, math.rad(-14)), palette.Light, Enum.Material.Wood)
	end
	block(visual, "BowUpper", torso, Vector3.new(0.12, 1.25, 0.14), CFrame.new(1.28, 0.55, -0.1) * CFrame.Angles(0, 0, math.rad(-18)), palette.Leather, Enum.Material.Wood)
	block(visual, "BowLower", torso, Vector3.new(0.12, 1.25, 0.14), CFrame.new(1.28, -0.55, -0.1) * CFrame.Angles(0, 0, math.rad(18)), palette.Leather, Enum.Material.Wood)
	block(visual, "BowGrip", torso, Vector3.new(0.18, 0.48, 0.18), CFrame.new(1.12, 0, -0.1), palette.Deep, Enum.Material.Fabric)
	block(visual, "BowString", torso, Vector3.new(0.035, 2.36, 0.035), CFrame.new(1.48, 0, -0.1), palette.Light, Enum.Material.Fabric)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		block(visual, side .. "AutumnArmBand", arm, Vector3.new(1.08, 0.12, 1.08), CFrame.new(0, 0.08, 0), palette.Secondary, Enum.Material.Fabric)
	end
end

local function addWildflowerBotanist(visual, character, head, torso, palette)
	wedge(visual, "BotanistLeftCollar", torso, Vector3.new(0.62, 0.42, 0.14), CFrame.new(-0.3, 0.78, -0.7) * CFrame.Angles(0, math.rad(180), math.rad(-18)), palette.Light, Enum.Material.Fabric)
	wedge(visual, "BotanistRightCollar", torso, Vector3.new(0.62, 0.42, 0.14), CFrame.new(0.3, 0.78, -0.7) * CFrame.Angles(0, math.rad(180), math.rad(18)), palette.Light, Enum.Material.Fabric)
	block(visual, "BotanistApron", torso, Vector3.new(1.48, 1.58, 0.13), CFrame.new(0, -0.08, -0.62), palette.Light, Enum.Material.Fabric)
	block(visual, "ApronWaistTie", torso, Vector3.new(1.62, 0.16, 0.12), CFrame.new(0, 0.08, -0.71), palette.Leather, Enum.Material.Fabric)
	block(visual, "ApronPocket", torso, Vector3.new(0.72, 0.5, 0.12), CFrame.new(0.3, -0.46, -0.71), palette.Light:Lerp(palette.Leather, 0.18), Enum.Material.Fabric)
	fernMotif(visual, "ApronFern", torso, -0.23, -0.46, -0.78, palette.Leather, 0.48)
	for index, x in ipairs({ 0.17, 0.34, 0.51 }) do
		block(visual, "BotanistTool" .. index, torso, Vector3.new(0.055, 0.55 - index * 0.06, 0.05), CFrame.new(x, -0.12, -0.8) * CFrame.Angles(0, 0, math.rad((index - 2) * 8)), index == 2 and palette.Accent or palette.Leather, index == 2 and Enum.Material.Metal or Enum.Material.Wood)
	end
	crossBodyStrap(visual, "BotanistSatchelStrap", torso, palette, 1)
	block(visual, "FlowerSatchel", torso, Vector3.new(0.7, 0.62, 0.28), CFrame.new(-0.76, -0.43, -0.68), palette.Leather, Enum.Material.Fabric)
	for index, flower in ipairs({
		{ -0.88, -0.06, palette.Accent },
		{ -0.65, 0.02, palette.Light },
		{ -0.48, -0.12, palette.Accent:Lerp(palette.Light, 0.45) },
	}) do
		orb(visual, "SatchelFlower" .. index, torso, 0.22, CFrame.new(flower[1], flower[2], -0.86), flower[3], Enum.Material.Fabric)
	end
	for index, x in ipairs({ -0.62, -0.36 }) do
		orb(visual, "HairFlower" .. index, head, 0.24, CFrame.new(x, 0.78, -0.72), index == 1 and palette.Light or palette.Accent, Enum.Material.Fabric)
	end
	for index, x in ipairs({ 0.38, 0.61 }) do
		orb(visual, "RightHairFlower" .. index, head, 0.2, CFrame.new(x, 0.76, -0.72), index == 1 and palette.Accent or palette.Light, Enum.Material.Fabric)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		fernMotif(visual, side .. "BotanistSleeveFlowers", arm, 0, 0.28, -0.58, palette.Accent, 0.55)
	end
end

local function addFernGuardian(visual, character, head, torso, palette)
	block(visual, "GuardianNeckWrap", torso, Vector3.new(1.42, 0.34, 0.22), CFrame.new(0, 0.86, -0.55), palette.Deep, Enum.Material.Fabric)
	block(visual, "FernBreastplate", torso, Vector3.new(1.72, 1.48, 0.18), CFrame.new(0, 0.08, -0.64), palette.Primary, Enum.Material.Fabric)
	block(visual, "GreenTabard", torso, Vector3.new(0.92, 1.75, 0.12), CFrame.new(0, -0.02, -0.75), palette.Primary, Enum.Material.Fabric)
	fernMotif(visual, "GuardianChestFern", torso, 0, 0.18, -0.83, palette.Light, 1.05)
	block(visual, "GuardianTabardLeftTrim", torso, Vector3.new(0.05, 1.62, 0.035), CFrame.new(-0.45, -0.05, -0.83), palette.Accent, Enum.Material.Metal)
	block(visual, "GuardianTabardRightTrim", torso, Vector3.new(0.05, 1.62, 0.035), CFrame.new(0.45, -0.05, -0.83), palette.Accent, Enum.Material.Metal)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		local leg = findFirst(character, { side .. " Leg", side .. "LowerLeg" })
		wedge(visual, side .. "ShoulderArmor", arm or torso, Vector3.new(1.12, 0.54, 1.18), arm and CFrame.new(0, 0.66, 0) * CFrame.Angles(0, math.rad(180), 0) or CFrame.new(side == "Left" and -1.05 or 1.05, 0.68, 0) * CFrame.Angles(0, math.rad(180), 0), palette.Light, Enum.Material.Metal)
		block(visual, side .. "ArmorEdge", arm or torso, Vector3.new(1.14, 0.08, 1.2), arm and CFrame.new(0, 0.38, 0) or CFrame.new(side == "Left" and -1.05 or 1.05, 0.4, 0), palette.Deep, Enum.Material.Metal)
		block(visual, side .. "GuardianGauntlet", arm, Vector3.new(1.08, 0.68, 1.12), CFrame.new(0, -0.22, 0), palette.Light, Enum.Material.Metal)
		block(visual, side .. "GuardianGreave", leg, Vector3.new(1.08, 0.72, 1.14), CFrame.new(0, -0.55, -0.04), palette.Accent, Enum.Material.Metal)
		wedge(visual, side .. "GuardianKnee", leg, Vector3.new(0.9, 0.55, 0.25), CFrame.new(0, 0.04, -0.62) * CFrame.Angles(0, math.rad(180), 0), palette.Light, Enum.Material.Metal)
	end
	cylinder(visual, "ShieldRim", torso, Vector3.new(0.2, 1.82, 1.82), CFrame.new(1.24, -0.05, -0.59) * CFrame.Angles(0, math.rad(90), 0), palette.Light, Enum.Material.Metal)
	cylinder(visual, "FernRoundShield", torso, Vector3.new(0.22, 1.62, 1.62), CFrame.new(1.24, -0.05, -0.64) * CFrame.Angles(0, math.rad(90), 0), palette.Primary, Enum.Material.Metal)
	cylinder(visual, "ShieldBoss", torso, Vector3.new(0.23, 0.46, 0.46), CFrame.new(1.24, -0.05, -0.73) * CFrame.Angles(0, math.rad(90), 0), palette.Light, Enum.Material.Metal)
	fernMotif(visual, "ShieldFern", torso, 1.24, -0.05, -0.88, palette.Light, 0.95)
end

local function addPineScout(visual, character, head, torso, palette)
	block(visual, "PineHoodTop", head, Vector3.new(2.14, 0.45, 1.58), CFrame.new(0, 0.82, 0.02), palette.Primary, Enum.Material.Fabric)
	block(visual, "PineHoodLeft", head, Vector3.new(0.32, 1.25, 1.55), CFrame.new(-0.94, 0.26, 0), palette.Primary, Enum.Material.Fabric)
	block(visual, "PineHoodRight", head, Vector3.new(0.32, 1.25, 1.55), CFrame.new(0.94, 0.26, 0), palette.Primary, Enum.Material.Fabric)
	wedge(visual, "PineHoodPeak", head, Vector3.new(0.75, 0.42, 0.55), CFrame.new(-0.52, 0.86, -0.58) * CFrame.Angles(0, math.rad(180), math.rad(-8)), palette.Primary, Enum.Material.Fabric)
	fernMotif(visual, "HoodLeafPin", head, -0.72, 0.6, -0.81, palette.Accent, 0.42)
	crossBodyStrap(visual, "PineScoutStrapLeft", torso, palette, -1)
	crossBodyStrap(visual, "PineScoutStrapRight", torso, palette, 1)
	for _, x in ipairs({ -0.68, 0.68 }) do
		block(visual, x < 0 and "PineLeftBeltPouch" or "PineRightBeltPouch", torso, Vector3.new(0.48, 0.42, 0.24), CFrame.new(x, -0.52, -0.67), palette.Leather, Enum.Material.Fabric)
		block(visual, x < 0 and "PineLeftPouchClasp" or "PineRightPouchClasp", torso, Vector3.new(0.12, 0.12, 0.05), CFrame.new(x, -0.5, -0.82), palette.Accent, Enum.Material.Metal)
	end
	block(visual, "CompactFieldPack", torso, Vector3.new(1.25, 1.32, 0.36), CFrame.new(0, -0.02, 0.72), palette.Leather, Enum.Material.Fabric)
	block(visual, "FieldNotebook", torso, Vector3.new(0.42, 0.56, 0.16), CFrame.new(0.76, -0.42, -0.66), palette.Light, Enum.Material.Fabric)
	cylinder(visual, "ScoutVial", torso, Vector3.new(0.18, 0.44, 0.18), CFrame.new(-0.78, -0.3, -0.72) * CFrame.Angles(0, 0, math.rad(90)), palette.Accent, Enum.Material.Glass)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		block(visual, side .. "PineSleeveGoldStitch", arm, Vector3.new(0.64, 0.045, 0.035), CFrame.new(0, 0.34, -0.58), palette.Accent, Enum.Material.Fabric)
		local leg = findFirst(character, { side .. " Leg", side .. "UpperLeg" })
		block(visual, side .. "TrouserPatch", leg, Vector3.new(0.52, 0.38, 0.08), CFrame.new(0, 0.36, -0.58), palette.Secondary, Enum.Material.Fabric)
		fernMotif(visual, side .. "TrouserPatchLeaf", leg, 0, 0.36, -0.64, palette.Accent, 0.38)
	end
end

local ROLE_BUILDERS = {
	MaleTrailRanger = addTrailRanger,
	MaleRiverWarden = addRiverWarden,
	MaleAutumnArcher = addAutumnArcher,
	FemaleWildflowerBotanist = addWildflowerBotanist,
	FemaleFernGuardian = addFernGuardian,
	FemalePineScout = addPineScout,
}

function AvatarModels.Apply(character, outfitOrId)
	local outfit = type(outfitOrId) == "string" and Catalog.Outfits[outfitOrId] or outfitOrId
	AvatarModels.Clear(character)
	if not isAvatar(outfit) then
		return nil
	end

	local head = findFirst(character, { "Head" })
	local torso = findFirst(character, { "UpperTorso", "Torso" }) or character.PrimaryPart
	if not head or not torso then
		return nil
	end

	hideOriginal(character)
	local visual = Instance.new("Model")
	visual.Name = AvatarModels.VisualName
	visual:SetAttribute("AvatarStyle", outfit.Style)
	visual:SetAttribute("Gender", outfit.Gender)
	visual:SetAttribute("ConceptIndex", outfit.ConceptIndex)
	visual:SetAttribute("ApprovedConceptSheet", true)
	visual:SetAttribute("StandardBlockBody", true)
	visual.Parent = character

	local palette = outfit.Palette
	local animatedTorso
	if character:FindFirstChild("UpperTorso") then
		animatedTorso = addR15Body(visual, character, palette, outfit.Arms)
	else
		animatedTorso = addR6Body(visual, character, palette, outfit.Arms)
	end
	animatedTorso = animatedTorso or torso
	addFace(visual, head, outfit.Arms, palette)
	if outfit.Gender == "Male" then
		addMaleHair(visual, head, palette, outfit.Style)
	else
		addFemaleHair(visual, head, animatedTorso, palette, outfit.Style)
	end
	addSharedClothing(visual, character, animatedTorso, palette, outfit.Style)
	ROLE_BUILDERS[outfit.Style](visual, character, head, animatedTorso, palette)
	return visual
end

local function previewPart(rig, name, size, cframe)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = rig
	return part
end

function AvatarModels.BuildPreview(parent, avatarId)
	if not AvatarModels.IsAvatarId(avatarId) then
		return nil
	end
	local rig = Instance.new("Model")
	rig.Name = avatarId .. "PreviewModel"
	rig:SetAttribute("AvatarPreview", true)
	rig:SetAttribute("AvatarId", avatarId)
	rig.Parent = parent

	local torso = previewPart(rig, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 2.65, 0))
	previewPart(rig, "Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.22, 0))
	previewPart(rig, "Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 2.65, 0))
	previewPart(rig, "Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 2.65, 0))
	previewPart(rig, "Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 0.65, 0))
	previewPart(rig, "Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 0.65, 0))
	rig.PrimaryPart = torso
	AvatarModels.Apply(rig, avatarId)
	return rig
end

return table.freeze(AvatarModels)
