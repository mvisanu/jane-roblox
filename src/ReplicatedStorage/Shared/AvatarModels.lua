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
AvatarModels.PreviewCameraCFrame = CFrame.lookAt(Vector3.new(5.8, 3.9, -8.8), Vector3.new(0, 2.25, 0))
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

local function addFace(visual, head, skin, palette)
	block(visual, "BlockHead", head, Vector3.new(2.04, 1.48, 1.5), CFrame.new(0, 0.22, 0), skin)
	for index, x in ipairs({ -0.38, 0.38 }) do
		block(visual, "FaceEye" .. index, head, Vector3.new(0.16, 0.25, 0.055), CFrame.new(x, 0.28, -0.775), Color3.fromRGB(37, 31, 26))
		block(visual, "FaceEyeGlint" .. index, head, Vector3.new(0.045, 0.055, 0.025), CFrame.new(x - 0.025, 0.34, -0.81), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	end
	block(visual, "FriendlySmile", head, Vector3.new(0.34, 0.065, 0.045), CFrame.new(0, -0.08, -0.785), Color3.fromRGB(112, 64, 55))
	block(visual, "LeftBrow", head, Vector3.new(0.34, 0.055, 0.04), CFrame.new(-0.38, 0.51, -0.785) * CFrame.Angles(0, 0, math.rad(-7)), palette.Hair)
	block(visual, "RightBrow", head, Vector3.new(0.34, 0.055, 0.04), CFrame.new(0.38, 0.51, -0.785) * CFrame.Angles(0, 0, math.rad(7)), palette.Hair)
end

local function addMaleHair(visual, head, palette, style)
	block(visual, "HairTop", head, Vector3.new(2.08, 0.48, 1.53), CFrame.new(0, 0.83, 0.03), palette.Hair, Enum.Material.Fabric)
	block(visual, "HairBack", head, Vector3.new(2.04, 0.72, 0.34), CFrame.new(0, 0.46, 0.71), palette.Hair, Enum.Material.Fabric)
	local sweep = style == "MaleRiverWarden" and -1 or 1
	for index, x in ipairs({ -0.82, -0.42, 0, 0.42, 0.82 }) do
		wedge(
			visual,
			"HairSpike" .. index,
			head,
			Vector3.new(0.48, 0.62, 0.46),
			CFrame.new(x, 0.9 + math.abs(x) * 0.08, -0.28) * CFrame.Angles(0, math.rad(180), math.rad(sweep * (x * 15))),
			palette.Hair,
			Enum.Material.Fabric
		)
	end
	block(visual, "LeftSideburn", head, Vector3.new(0.28, 0.55, 0.34), CFrame.new(-0.9, 0.38, -0.48), palette.Hair, Enum.Material.Fabric)
	block(visual, "RightSideburn", head, Vector3.new(0.28, 0.55, 0.34), CFrame.new(0.9, 0.38, -0.48), palette.Hair, Enum.Material.Fabric)
end

local function addFemaleHair(visual, head, torso, palette, style)
	block(visual, "HairTop", head, Vector3.new(2.1, 0.48, 1.54), CFrame.new(0, 0.83, 0.03), palette.Hair, Enum.Material.Fabric)
	block(visual, "LongHairBack", head, Vector3.new(1.96, 1.75, 0.34), CFrame.new(0, -0.18, 0.72), palette.Hair, Enum.Material.Fabric)
	block(visual, "LeftHairLock", head, Vector3.new(0.34, 1.4, 0.34), CFrame.new(-0.88, -0.06, -0.49) * CFrame.Angles(0, 0, math.rad(-7)), palette.Hair, Enum.Material.Fabric)
	block(visual, "RightHairLock", head, Vector3.new(0.34, 1.4, 0.34), CFrame.new(0.88, -0.06, -0.49) * CFrame.Angles(0, 0, math.rad(7)), palette.Hair, Enum.Material.Fabric)

	if style == "FemaleFernGuardian" or style == "FemalePineScout" then
		local side = style == "FemaleFernGuardian" and -0.76 or 0.76
		for index = 1, 4 do
			block(
				visual,
				"HairBraid" .. index,
				torso,
				Vector3.new(0.3, 0.46, 0.3),
				CFrame.new(side, 0.65 - index * 0.38, -0.66) * CFrame.Angles(0, 0, math.rad((index % 2 == 0 and 1 or -1) * 8)),
				palette.Hair,
				Enum.Material.Fabric
			)
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
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		block(visual, "BlockUpperTorso", upper, Vector3.new(upper.Size.X * 1.06, upper.Size.Y * 1.04, upper.Size.Z * 1.08), CFrame.new(), palette.Primary, Enum.Material.Fabric)
	end
	if lower then
		block(visual, "BlockLowerTorso", lower, Vector3.new(lower.Size.X * 1.06, lower.Size.Y * 1.04, lower.Size.Z * 1.08), CFrame.new(), palette.Secondary, Enum.Material.Fabric)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		for _, segment in ipairs({ "UpperArm", "LowerArm", "Hand" }) do
			local target = character:FindFirstChild(side .. segment)
			if target then
				block(visual, side .. "Block" .. segment, target, Vector3.new(target.Size.X * 1.05, target.Size.Y * 1.04, target.Size.Z * 1.05), CFrame.new(), segment == "Hand" and skin or palette.Primary, segment == "Hand" and Enum.Material.SmoothPlastic or Enum.Material.Fabric)
			end
		end
		for _, segment in ipairs({ "UpperLeg", "LowerLeg", "Foot" }) do
			local target = character:FindFirstChild(side .. segment)
			if target then
				local foot = segment == "Foot"
				block(visual, side .. "Block" .. segment, target, Vector3.new(target.Size.X * 1.05, target.Size.Y * 1.04, target.Size.Z * (foot and 1.2 or 1.05)), foot and CFrame.new(0, 0, -0.06) or CFrame.new(), foot and palette.Leather or palette.Deep, Enum.Material.Fabric)
			end
		end
	end
	return upper or lower
end

local function addSharedClothing(visual, torso, palette)
	block(visual, "JacketFront", torso, Vector3.new(1.78, 1.68, 0.12), CFrame.new(0, 0.08, -0.6), palette.Primary, Enum.Material.Fabric)
	block(visual, "LeatherBelt", torso, Vector3.new(2.1, 0.22, 1.15), CFrame.new(0, -0.5, 0), palette.Leather, Enum.Material.Fabric)
	block(visual, "BeltBuckle", torso, Vector3.new(0.3, 0.3, 0.12), CFrame.new(0, -0.5, -0.64), palette.Accent, Enum.Material.Metal)
	block(visual, "LeftJacketHem", torso, Vector3.new(0.82, 0.58, 0.14), CFrame.new(-0.47, -0.83, -0.59), palette.Secondary, Enum.Material.Fabric)
	block(visual, "RightJacketHem", torso, Vector3.new(0.82, 0.58, 0.14), CFrame.new(0.47, -0.83, -0.59), palette.Secondary, Enum.Material.Fabric)
end

local function crossBodyStrap(visual, name, torso, palette, direction)
	block(visual, name, torso, Vector3.new(0.18, 2.15, 0.12), CFrame.new(0, 0.12, -0.67) * CFrame.Angles(0, 0, math.rad(direction * 28)), palette.Leather, Enum.Material.Fabric)
end

local function addTrailRanger(visual, character, head, torso, palette)
	block(visual, "TrailScarf", torso, Vector3.new(1.35, 0.32, 0.22), CFrame.new(0, 0.87, -0.55), palette.Secondary, Enum.Material.Fabric)
	crossBodyStrap(visual, "TrailMapStrap", torso, palette, 1)
	block(visual, "TrailMapPouch", torso, Vector3.new(0.7, 0.68, 0.26), CFrame.new(-0.72, -0.42, -0.68), palette.Light, Enum.Material.Fabric)
	block(visual, "TrailMapMark", torso, Vector3.new(0.34, 0.05, 0.03), CFrame.new(-0.72, -0.4, -0.83) * CFrame.Angles(0, 0, math.rad(18)), palette.Leather)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		block(visual, side .. "FernPatch", arm, Vector3.new(0.45, 0.52, 0.08), CFrame.new(0, 0.35, -0.55), palette.Accent, Enum.Material.Fabric)
	end
end

local function addRiverWarden(visual, character, head, torso, palette)
	block(visual, "RiverMantle", torso, Vector3.new(2.32, 0.36, 1.25), CFrame.new(0, 0.83, 0), palette.Deep, Enum.Material.Fabric)
	block(visual, "RiverMantleTrim", torso, Vector3.new(2.36, 0.09, 1.29), CFrame.new(0, 0.64, 0), palette.Accent, Enum.Material.Metal)
	crossBodyStrap(visual, "RiverWardenStrap", torso, palette, -1)
	local arm = findFirst(character, { "Right Arm", "RightHand", "RightLowerArm" }) or torso
	block(visual, "LanternFrame", arm, Vector3.new(0.62, 0.82, 0.62), CFrame.new(0.12, -0.82, -0.18), palette.Leather, Enum.Material.Metal)
	block(visual, "LanternGlow", arm, Vector3.new(0.4, 0.54, 0.4), CFrame.new(0.12, -0.82, -0.18), palette.Accent, Enum.Material.Neon)
	block(visual, "LanternHandle", arm, Vector3.new(0.12, 0.55, 0.12), CFrame.new(0.12, -0.22, -0.18), palette.Leather, Enum.Material.Metal)
end

local function addAutumnArcher(visual, character, head, torso, palette)
	block(visual, "AutumnScarf", torso, Vector3.new(1.45, 0.38, 0.24), CFrame.new(0, 0.84, -0.55), palette.Secondary, Enum.Material.Fabric)
	crossBodyStrap(visual, "ArcherChestStrap", torso, palette, -1)
	block(visual, "CompactQuiver", torso, Vector3.new(0.48, 1.55, 0.42), CFrame.new(0.72, 0.18, 0.73) * CFrame.Angles(0, 0, math.rad(-14)), palette.Leather, Enum.Material.Wood)
	for index, x in ipairs({ 0.58, 0.72, 0.86 }) do
		block(visual, "Arrow" .. index, torso, Vector3.new(0.09, 1.55, 0.09), CFrame.new(x, 0.75, 0.78) * CFrame.Angles(0, 0, math.rad(-14)), palette.Light, Enum.Material.Wood)
	end
	block(visual, "BowUpper", torso, Vector3.new(0.12, 1.25, 0.14), CFrame.new(1.28, 0.55, -0.1) * CFrame.Angles(0, 0, math.rad(-18)), palette.Leather, Enum.Material.Wood)
	block(visual, "BowLower", torso, Vector3.new(0.12, 1.25, 0.14), CFrame.new(1.28, -0.55, -0.1) * CFrame.Angles(0, 0, math.rad(18)), palette.Leather, Enum.Material.Wood)
	block(visual, "BowGrip", torso, Vector3.new(0.18, 0.48, 0.18), CFrame.new(1.12, 0, -0.1), palette.Deep, Enum.Material.Fabric)
end

local function addWildflowerBotanist(visual, character, head, torso, palette)
	block(visual, "BotanistApron", torso, Vector3.new(1.48, 1.58, 0.13), CFrame.new(0, -0.08, -0.62), palette.Light, Enum.Material.Fabric)
	block(visual, "ApronPocket", torso, Vector3.new(0.72, 0.5, 0.12), CFrame.new(0.3, -0.46, -0.71), palette.Light:Lerp(palette.Leather, 0.18), Enum.Material.Fabric)
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
end

local function addFernGuardian(visual, character, head, torso, palette)
	block(visual, "FernBreastplate", torso, Vector3.new(1.72, 1.48, 0.18), CFrame.new(0, 0.08, -0.64), palette.Light, Enum.Material.Metal)
	block(visual, "GreenTabard", torso, Vector3.new(0.92, 1.75, 0.12), CFrame.new(0, -0.02, -0.75), palette.Primary, Enum.Material.Fabric)
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = findFirst(character, { side .. " Arm", side .. "UpperArm" })
		local leg = findFirst(character, { side .. " Leg", side .. "LowerLeg" })
		block(visual, side .. "ShoulderArmor", arm or torso, Vector3.new(1.08, 0.48, 1.14), arm and CFrame.new(0, 0.66, 0) or CFrame.new(side == "Left" and -1.05 or 1.05, 0.68, 0), palette.Light, Enum.Material.Metal)
		block(visual, side .. "GuardianGreave", leg, Vector3.new(1.08, 0.72, 1.14), CFrame.new(0, -0.55, -0.04), palette.Accent, Enum.Material.Metal)
	end
	cylinder(visual, "FernRoundShield", torso, Vector3.new(0.18, 1.65, 1.65), CFrame.new(1.24, -0.05, -0.62) * CFrame.Angles(0, math.rad(90), 0), palette.Primary, Enum.Material.Metal)
	cylinder(visual, "ShieldBoss", torso, Vector3.new(0.23, 0.46, 0.46), CFrame.new(1.24, -0.05, -0.73) * CFrame.Angles(0, math.rad(90), 0), palette.Light, Enum.Material.Metal)
end

local function addPineScout(visual, character, head, torso, palette)
	block(visual, "PineHoodTop", head, Vector3.new(2.14, 0.45, 1.58), CFrame.new(0, 0.82, 0.02), palette.Primary, Enum.Material.Fabric)
	block(visual, "PineHoodLeft", head, Vector3.new(0.32, 1.25, 1.55), CFrame.new(-0.94, 0.26, 0), palette.Primary, Enum.Material.Fabric)
	block(visual, "PineHoodRight", head, Vector3.new(0.32, 1.25, 1.55), CFrame.new(0.94, 0.26, 0), palette.Primary, Enum.Material.Fabric)
	crossBodyStrap(visual, "PineScoutStrapLeft", torso, palette, -1)
	crossBodyStrap(visual, "PineScoutStrapRight", torso, palette, 1)
	block(visual, "CompactFieldPack", torso, Vector3.new(1.25, 1.32, 0.36), CFrame.new(0, -0.02, 0.72), palette.Leather, Enum.Material.Fabric)
	block(visual, "FieldNotebook", torso, Vector3.new(0.42, 0.56, 0.16), CFrame.new(0.76, -0.42, -0.66), palette.Light, Enum.Material.Fabric)
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
	addSharedClothing(visual, animatedTorso, palette)
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
