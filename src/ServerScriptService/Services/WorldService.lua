local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local AvatarModels = require(Shared:WaitForChild("AvatarModels"))
local CafeMenu = require(Shared:WaitForChild("CafeMenu"))
local CafeModels = require(Shared:WaitForChild("CafeModels"))
local Config = require(Shared:WaitForChild("Config"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local Furniture = require(Shared:WaitForChild("Furniture"))
local Progression = require(Shared:WaitForChild("Progression"))
local WildwoodStyle = require(Shared:WaitForChild("WildwoodStyle"))
local STYLE = WildwoodStyle.Colors

local LABEL_TAG = RemoteNames.LabelTag
local FURNITURE_TAG = RemoteNames.FurnitureTag

-- Top of the house floor, in house-local studs. Furniture stands on this.
local HOME_FLOOR_TOP = 1

local WorldService = {}
WorldService.__index = WorldService

local VILLAGE = Config.VillagePalette

-- Every environmental role now resolves to the approved Bakery Bay palette.
local COLORS = {
	Grass = VILLAGE.Grass,
	Road = VILLAGE.Cobble,
	Cream = VILLAGE.Plaster,
	Pink = VILLAGE.RoofHighlight,
	Mint = VILLAGE.FoliageLight,
	Blue = VILLAGE.Water,
	Purple = VILLAGE.WaterLight,
	Yellow = VILLAGE.Lantern,
	Brown = VILLAGE.TimberMid,
	DarkBrown = VILLAGE.TimberDark,
	White = VILLAGE.PlasterShade,
	Soil = VILLAGE.Soil,
	Leaf = VILLAGE.Foliage,
	Water = VILLAGE.Water,
}

local ADVENTURE_COLORS = Config.AdventurePalette

-- Both approved architectural kits now resolve to the single town palette;
-- the former standalone colour tables and their legacy codes are gone.
local PORCH_GABLE = VILLAGE
local BAKERY_BAY = VILLAGE

-- A Roblox character is about 2 studs wide and 5 tall, so every doorway is cut
-- wider and taller than that. Doors themselves are decoration: the hole in the
-- wall is what the player walks through.
local WALL_THICKNESS = 1
local DOORWAY_MARGIN = 0.5

-- The unscaled pet runs from the bottom of BodyRoot (-1.5) to the top of its
-- ears (3.75): 5.25 studs. Every size and offset is scaled from that single
-- envelope so the finished model is exactly one quarter of its player's body.
local PET_CANONICAL_HEIGHT = 5.25

local function characterBodyMetrics(player)
	local character = player and player:IsA("Player") and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local lowest = math.huge
	local highest = -math.huge
	if character then
		-- Direct body parts only: an oversized hat must not make the pet enormous.
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("BasePart") then
				local position = child.Position or child.CFrame.Position
				lowest = math.min(lowest, position.Y - child.Size.Y / 2)
				highest = math.max(highest, position.Y + child.Size.Y / 2)
			end
		end
	end
	if lowest < highest then
		local height = highest - lowest
		local rootPosition = root and (root.Position or root.CFrame.Position)
		local footOffset = rootPosition and math.max(0.5, rootPosition.Y - lowest) or height / 2
		return height, footOffset
	end
	return Config.CharacterReferenceHeight, Config.CharacterReferenceHeight * 0.6
end

local function bilingual(english, thai)
	return string.format("%s / %s", thai, english)
end

local function part(parent, name, size, cframe, color, material, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.CastShadow = true
	if shape then
		object.Shape = shape
	end
	object.Parent = parent
	return object
end

--[[
	A floating world label. Every one is scaled down from the size the caller
	asks for, culled by the engine past Config.LabelFarDistance, and tagged so
	the client can fade it in as the player walks up and switch it off entirely.
]]
local function billboard(adornee, text, color, size)
	local requested = size or UDim2.fromOffset(180, 46)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(
		math.round(requested.X.Offset * Config.LabelScale),
		math.round(requested.Y.Offset * Config.LabelScale)
	)
	gui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + 2, 0)
	gui.MaxDistance = Config.LabelFarDistance
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundColor3 = VILLAGE.CanvasLight
	label.BackgroundTransparency = 0.08
	label.Size = UDim2.fromScale(1, 1)
	label.Font = WildwoodStyle.Fonts.Headline
	label.Text = text
	label.TextColor3 = color or VILLAGE.TimberDark
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = VILLAGE.TimberWarm
	stroke.Thickness = 2
	stroke.Transparency = 0.25
	stroke.Parent = label

	CollectionService:AddTag(gui, LABEL_TAG)
	return label
end

-- A physical carved board matching the supplied Adventure Guild sign: dark
-- weathered timber, raised rim, hanging ropes, and warm cream/gold lettering.
local function carvedSignFace(sign, text, accent)
	sign.Color = VILLAGE.TimberWarm
	sign.Material = Enum.Material.WoodPlanks
	sign:SetAttribute("WildwoodCarvedSign", true)
	sign:SetAttribute("ReferenceStyle", WildwoodStyle.Reference)
	local parent = sign.Parent
	local width, height = sign.Size.X, sign.Size.Y

	for _, y in ipairs({ -1, 1 }) do
		local rail = part(parent, "SignBorder", Vector3.new(width + 0.7, 0.35, sign.Size.Z + 0.2), sign.CFrame * CFrame.new(0, y * height / 2, 0), VILLAGE.TimberDark, Enum.Material.Wood)
		rail.CanCollide = false
	end
	for _, x in ipairs({ -1, 1 }) do
		local rail = part(parent, "SignBorder", Vector3.new(0.35, height, sign.Size.Z + 0.2), sign.CFrame * CFrame.new(x * width / 2, 0, 0), VILLAGE.TimberDark, Enum.Material.Wood)
		rail.CanCollide = false
		local rope = part(parent, "SignRope", Vector3.new(0.18, 1.5, 0.18), sign.CFrame * CFrame.new(x * width * 0.32, height / 2 + 0.7, 0), VILLAGE.TimberDark, Enum.Material.Fabric)
		rope.CanCollide = false
	end

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "CarvedLettering"
		surface.Face = face
		surface.LightInfluence = 0.15
		surface.PixelsPerStud = 42
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.Parent = sign

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, 0.08)
		label.Size = UDim2.fromScale(0.92, 0.84)
		label.Font = WildwoodStyle.Fonts.Sign
		label.Text = text
		label.TextColor3 = accent or VILLAGE.Lantern
		label.TextScaled = true
		label.TextStrokeColor3 = VILLAGE.TimberDark
		label.TextStrokeTransparency = 0.15
		label.TextWrapped = true
		label.Parent = surface
	end
	return sign
end

local function prompt(parent, actionText, objectText)
	local interaction = Instance.new("ProximityPrompt")
	interaction.Name = "TownPrompt"
	interaction.ActionText = actionText
	interaction.ObjectText = objectText
	interaction.HoldDuration = 0
	interaction.MaxActivationDistance = Config.InteractionDistance
	interaction.RequiresLineOfSight = false
	interaction.Style = Enum.ProximityPromptStyle.Default
	interaction.Parent = parent
	return interaction
end

local function modelWithPrimary(name, parent, primary)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	primary.Parent = model
	model.PrimaryPart = primary
	return model
end

function WorldService.new(remotes)
	local self = setmetatable({}, WorldService)
	self._remotes = remotes
	self._homes = {}
	self._homeByPlayer = {}
	self._pets = {}
	self._actionHandler = nil
	self._followAccumulator = 0
	self._mapBlips = {}
	self:_buildWorld()
	self:_startPetFollow()
	return self
end

--[[
	Records a landmark for the minimap as the world is built, so the map is
	always drawn from the town that actually exists rather than a second,
	hand-maintained copy of the layout that can drift out of step.
]]
function WorldService:_addBlip(kind, name, nameThai, position, width, depth, color, index)
	table.insert(self._mapBlips, {
		Kind = kind,
		Name = name,
		NameThai = nameThai,
		X = position.X,
		Z = position.Z,
		W = width,
		D = depth,
		Color = color,
		Index = index,
	})
end

function WorldService:GetMapData(player)
	local home = self._homeByPlayer[player]
	return {
		Bounds = { MinX = -300, MaxX = 300, MinZ = -300, MaxZ = 690 },
		Blips = self._mapBlips,
		HomeIndex = home and home.Index or nil,
	}
end

function WorldService:SetActionHandler(handler)
	self._actionHandler = handler
end

function WorldService:_runPrompt(player, action, payload, homeIndex)
	if homeIndex and player:GetAttribute("HomeIndex") ~= homeIndex then
		self._remotes.Toast:FireClient(player, "This garden belongs to another family.")
		return
	end
	if not self._actionHandler then
		return
	end
	local response = self._actionHandler(player, action, payload or {})
	if response and response.message then
		self._remotes.Toast:FireClient(player, response.message)
	end
end

function WorldService:_connectPrompt(interaction, action, payload, homeIndex)
	interaction.Triggered:Connect(function(player)
		task.spawn(function()
			self:_runPrompt(player, action, payload, homeIndex)
		end)
	end)
end

--[[
	Builds four walls around `base` with a doorway cut through the front (-Z) face.

	`base` sits at the middle of the interior floor surface, so every offset here
	is measured from the floor a player actually stands on. The doorway is left
	as a real gap in the geometry and recorded as an invisible DoorwayVolume, so
	the offline walkability test can prove nothing solid ever creeps into it.
]]
function WorldService:_shell(model, base, spec)
	local thickness = spec.Thickness or WALL_THICKNESS
	local width, depth, height = spec.Width, spec.Depth, spec.Height
	local doorWidth = spec.DoorWidth or 8
	local doorOffset = spec.DoorOffset or 0
	local doorHeight = math.min(spec.DoorHeight or 10, height)
	local material = spec.Material or Enum.Material.SmoothPlastic
	local halfWidth, halfDepth = width / 2, depth / 2
	local leftWidth = halfWidth + doorOffset - doorWidth / 2
	local rightWidth = halfWidth - doorOffset - doorWidth / 2

	local function shellPart(name, size, offset)
		return part(model, name, size, base * CFrame.new(offset), spec.Color, material)
	end

	local walls = {
		shellPart("BackWall", Vector3.new(width, height, thickness), Vector3.new(0, height / 2, halfDepth - thickness / 2)),
		shellPart("LeftWall", Vector3.new(thickness, height, depth - thickness * 2), Vector3.new(-halfWidth + thickness / 2, height / 2, 0)),
		shellPart("RightWall", Vector3.new(thickness, height, depth - thickness * 2), Vector3.new(halfWidth - thickness / 2, height / 2, 0)),
		shellPart("FrontLeft", Vector3.new(leftWidth, height, thickness), Vector3.new(-halfWidth + leftWidth / 2, height / 2, -halfDepth + thickness / 2)),
		shellPart("FrontRight", Vector3.new(rightWidth, height, thickness), Vector3.new(halfWidth - rightWidth / 2, height / 2, -halfDepth + thickness / 2)),
	}
	if height - doorHeight > 0.1 then
		table.insert(walls, shellPart(
			"DoorHeader",
			Vector3.new(doorWidth, height - doorHeight, thickness),
			Vector3.new(doorOffset, doorHeight + (height - doorHeight) / 2, -halfDepth + thickness / 2)
		))
	end

	if spec.Ceiling ~= false then
		local ceilingThickness = spec.CeilingThickness or 1
		table.insert(walls, part(
			model,
			"Ceiling",
			Vector3.new(width, ceilingThickness, depth),
			base * CFrame.new(0, height + ceilingThickness / 2, 0),
			spec.CeilingColor or COLORS.White,
			spec.CeilingMaterial or Enum.Material.SmoothPlastic
		))
	end

	local doorwayHeight = doorHeight - DOORWAY_MARGIN
	local doorway = part(
		model,
		"DoorwayVolume",
		Vector3.new(doorWidth - DOORWAY_MARGIN, doorwayHeight, thickness + 4),
		base * CFrame.new(doorOffset, doorwayHeight / 2 + 0.15, -halfDepth + thickness / 2),
		COLORS.Mint,
		Enum.Material.SmoothPlastic
	)
	doorway.CanCollide = false
	doorway.Transparency = 1
	doorway.CastShadow = false

	local interior = part(
		model,
		"InteriorMarker",
		Vector3.new(2, 1, 2),
		base * CFrame.new(0, 0.5, spec.InteriorOffset or 0),
		COLORS.Mint,
		Enum.Material.SmoothPlastic
	)
	interior.CanCollide = false
	interior.Transparency = 1
	interior.CastShadow = false

	model:SetAttribute("Enterable", true)
	return { Walls = walls, Doorway = doorway, Interior = interior }
end

function WorldService:_interiorLamp(model, base, offset, range)
	local lamp = part(model, "CeilingLamp", Vector3.new(3, 0.8, 3), base * CFrame.new(offset), COLORS.Yellow, Enum.Material.Neon)
	lamp.CanCollide = false
	lamp.CastShadow = false
	local light = Instance.new("PointLight")
	light.Brightness = 1.6
	light.Range = range or 34
	light.Color = VILLAGE.CanvasLight
	light.Parent = lamp
	return lamp
end

--[[
	Cladding.

	Everything below is decoration laid over the structural shell: timber framing,
	a pitched shingle roof, stone footings, lanterns, balconies. All of it is
	non-collidable, so a player still walks through exactly the same doorway and
	stands on exactly the same floor as before - the buildings only change how
	they look, never how they behave.
]]
local function clad(model, name, size, cframe, color, material)
	local piece = part(model, name, size, cframe, color, material or Enum.Material.WoodPlanks)
	piece.CanCollide = false
	return piece
end

--[[ A pitched, overhanging shingle roof with a timber ridge, gable ends and eaves. ]]
function WorldService:_gableRoof(model, base, width, depth, wallHeight, tileColor)
	local overhang = Config.RoofOverhang
	local halfWidth = width / 2 + overhang
	local rise = math.min(halfWidth * Config.RoofPitch, Config.MaxRoofRise)
	local slope = math.sqrt(halfWidth * halfWidth + rise * rise)
	local angle = math.atan2(rise, halfWidth)
	local roofDepth = depth + overhang * 2
	local eave = wallHeight

	-- Two flat planes leaning together on the ridge. Rotating a slab about Z is
	-- unambiguous, unlike a wedge, and gives a clean unbroken pitch.
	for _, side in ipairs({ -1, 1 }) do
		local plane = clad(
			model,
			"RoofPlane",
			Vector3.new(slope, 1, roofDepth),
			base * CFrame.new(side * halfWidth / 2, eave + rise / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			tileColor or VILLAGE.RoofTile,
			Enum.Material.Slate
		)
		-- Shingle courses: shallow ridges running across the pitch.
		for course = 1, 5 do
			local along = (course / 6 - 0.5) * slope
			clad(
				model,
				"RoofCourse",
				Vector3.new(0.7, 0.35, roofDepth + 0.1),
				plane.CFrame * CFrame.new(along, 0.6, 0),
				VILLAGE.RoofShade,
				Enum.Material.Slate
			)
		end
		-- Fascia board closing off the eave.
		clad(
			model,
			"RoofFascia",
			Vector3.new(0.6, 1.4, roofDepth),
			base * CFrame.new(side * halfWidth, eave - 0.4, 0),
			VILLAGE.TimberDark,
			Enum.Material.Wood
		)
	end

	clad(
		model,
		"RoofRidge",
		Vector3.new(1.6, 1.3, roofDepth + 1),
		base * CFrame.new(0, eave + rise + 0.3, 0),
		VILLAGE.TimberDark,
		Enum.Material.Wood
	)

	-- Gable ends: the triangle of wall between the eaves and the ridge, stacked
	-- in thin courses so it follows the pitch, then braced with timber.
	local courses = 14
	for _, face in ipairs({ -1, 1 }) do
		for index = 0, courses - 1 do
			local fraction = (index + 0.5) / courses
			local halfCourse = math.min(width / 2, halfWidth * (1 - fraction))
			if halfCourse > 0.4 then
				clad(
					model,
					"GableCourse",
					Vector3.new(halfCourse * 2, rise / courses + 0.06, 0.8),
					base * CFrame.new(0, eave + fraction * rise, face * (depth / 2 - 0.1)),
					VILLAGE.Plaster,
					Enum.Material.Sand
				)
			end
		end
		local gableZ = face * (depth / 2 + 0.15)
		clad(model, "GablePost", Vector3.new(0.9, rise, 0.5), base * CFrame.new(0, eave + rise / 2, gableZ), VILLAGE.TimberDark, Enum.Material.Wood)
		for _, side in ipairs({ -1, 1 }) do
			local braceLength = math.sqrt((width / 2) ^ 2 + rise ^ 2) * 0.55
			clad(
				model,
				"GableBrace",
				Vector3.new(braceLength, 0.7, 0.5),
				base * CFrame.new(side * width / 5, eave + rise * 0.42, gableZ) * CFrame.Angles(0, 0, -side * math.atan2(rise, width / 2) * 0.85),
				VILLAGE.TimberDark,
				Enum.Material.Wood
			)
		end
	end
	return rise
end

--[[ Dark beams and braces over the plaster, the way the reference village frames its walls. ]]
function WorldService:_timberFrame(model, base, width, depth, height, doorWidth)
	local halfWidth, halfDepth = width / 2, depth / 2
	local proud = 0.35

	-- Corner posts.
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			clad(model, "CornerPost", Vector3.new(1.1, height, 1.1), base * CFrame.new(x * halfWidth, height / 2, z * halfDepth), VILLAGE.TimberDark, Enum.Material.Wood)
		end
	end

	-- Top plate, sill and a mid rail on all four sides.
	for _, level in ipairs({ 0.4, height * 0.55, height - 0.5 }) do
		for _, z in ipairs({ -1, 1 }) do
			clad(model, "WallRail", Vector3.new(width, 0.9, 0.6), base * CFrame.new(0, level, z * (halfDepth + proud)), VILLAGE.TimberDark, Enum.Material.Wood)
		end
		for _, x in ipairs({ -1, 1 }) do
			clad(model, "WallRail", Vector3.new(0.6, 0.9, depth), base * CFrame.new(x * (halfWidth + proud), level, 0), VILLAGE.TimberDark, Enum.Material.Wood)
		end
	end

	-- Diagonal braces in the upper panels: the signature of a timber-framed wall.
	local panelHeight = height - height * 0.55 - 1
	local braceLength = math.sqrt(panelHeight * panelHeight + 36)
	local braceAngle = math.atan2(panelHeight, 6)
	local upperY = height * 0.55 + panelHeight / 2 + 0.5
	for _, x in ipairs({ -1, 1 }) do
		for _, offset in ipairs({ -depth / 4, depth / 4 }) do
			clad(
				model,
				"WallBrace",
				Vector3.new(0.6, braceLength, 0.6),
				base * CFrame.new(x * (halfWidth + proud), upperY, offset) * CFrame.Angles(math.sign(offset) * (math.pi / 2 - braceAngle), 0, 0),
				VILLAGE.TimberDark,
				Enum.Material.Wood
			)
		end
	end
	-- Back wall braces, and front braces kept clear of the doorway.
	for _, z in ipairs({ -1, 1 }) do
		local reach = z < 0 and (doorWidth / 2 + 5) or (width / 4)
		for _, x in ipairs({ -1, 1 }) do
			clad(
				model,
				"WallBrace",
				Vector3.new(0.6, braceLength, 0.6),
				base * CFrame.new(x * reach, upperY, z * (halfDepth + proud)) * CFrame.Angles(0, 0, -x * (math.pi / 2 - braceAngle)),
				VILLAGE.TimberDark,
				Enum.Material.Wood
			)
		end
	end
end

--[[ Stone footing around the base of the walls, split so it never crosses the doorway. ]]
function WorldService:_stoneFooting(model, base, width, depth, doorWidth)
	local halfWidth, halfDepth = width / 2, depth / 2
	local sideWidth = (width - doorWidth) / 2 - 0.5
	clad(model, "Footing", Vector3.new(width + 1.6, 3.4, 1.2), base * CFrame.new(0, 0.5, halfDepth + 0.3), VILLAGE.Stone, Enum.Material.Rock)
	for _, x in ipairs({ -1, 1 }) do
		clad(model, "Footing", Vector3.new(1.2, 3.4, depth + 1.6), base * CFrame.new(x * (halfWidth + 0.3), 0.5, 0), VILLAGE.Stone, Enum.Material.Rock)
		clad(
			model,
			"Footing",
			Vector3.new(sideWidth, 3.4, 1.2),
			base * CFrame.new(x * (width - sideWidth) / 2, 0.5, -halfDepth - 0.3),
			VILLAGE.Stone,
			Enum.Material.Rock
		)
	end
end

--[[ A hanging lantern on a bracket. These are what make the reference feel warm. ]]
function WorldService:_hangingLantern(model, cframe, range)
	clad(model, "LanternBracket", Vector3.new(0.3, 0.3, 2.2), cframe * CFrame.new(0, 1.6, 1), VILLAGE.TimberDark, Enum.Material.Metal)
	clad(model, "LanternCap", Vector3.new(1.5, 0.35, 1.5), cframe * CFrame.new(0, 1, 0), VILLAGE.TimberDark, Enum.Material.Metal)
	clad(model, "LanternBody", Vector3.new(1.2, 1.5, 1.2), cframe, VILLAGE.TimberMid, Enum.Material.Metal)
	local glow = clad(model, "LanternGlow", Vector3.new(0.85, 1.2, 0.85), cframe, VILLAGE.Lantern, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = range or 22
	light.Color = VILLAGE.Lantern
	light.Parent = glow
	return glow
end

--[[ A hanging banner, like the teal ones strung across the reference village. ]]
function WorldService:_banner(model, cframe, color)
	clad(model, "BannerPole", Vector3.new(0.3, 0.3, 1.6), cframe * CFrame.new(0, 3.2, 0.6), VILLAGE.TimberDark, Enum.Material.Metal)
	clad(model, "BannerCloth", Vector3.new(2.6, 6, 0.2), cframe, color or VILLAGE.Banner, Enum.Material.Fabric)
	clad(model, "BannerTrim", Vector3.new(2.6, 0.7, 0.25), cframe * CFrame.new(0, 2.6, 0), VILLAGE.Plaster, Enum.Material.Fabric)
end

--[[ Timber surround and glazing bars for a window opening. ]]
function WorldService:_windowFrame(model, cframe, windowWidth, windowHeight)
	local halfW, halfH = windowWidth / 2, windowHeight / 2
	clad(model, "WindowSill", Vector3.new(windowWidth + 1.4, 0.5, 1), cframe * CFrame.new(0, -halfH - 0.2, 0), VILLAGE.TimberDark, Enum.Material.Wood)
	clad(model, "WindowHead", Vector3.new(windowWidth + 1.4, 0.5, 1), cframe * CFrame.new(0, halfH + 0.2, 0), VILLAGE.TimberDark, Enum.Material.Wood)
	for _, x in ipairs({ -1, 1 }) do
		clad(model, "WindowJamb", Vector3.new(0.5, windowHeight, 1), cframe * CFrame.new(x * (halfW + 0.2), 0, 0), VILLAGE.TimberDark, Enum.Material.Wood)
	end
	clad(model, "WindowMullion", Vector3.new(0.3, windowHeight, 0.9), cframe, VILLAGE.TimberDark, Enum.Material.Wood)
	clad(model, "WindowTransom", Vector3.new(windowWidth, 0.3, 0.9), cframe, VILLAGE.TimberDark, Enum.Material.Wood)
end

--[[ An overhanging balcony above the door, on carved brackets. ]]
function WorldService:_balcony(model, base, width, depth, height, doorWidth)
	local deckWidth = doorWidth + 8
	local deckY = height * 0.62
	local reach = 3.6
	local front = -(depth / 2 + reach / 2)

	clad(model, "BalconyDeck", Vector3.new(deckWidth, 0.6, reach), base * CFrame.new(0, deckY, front), VILLAGE.TimberMid, Enum.Material.WoodPlanks)
	clad(model, "BalconyRail", Vector3.new(deckWidth, 0.5, 0.4), base * CFrame.new(0, deckY + 2.6, front - reach / 2 + 0.2), VILLAGE.TimberDark, Enum.Material.Wood)
	for index = 0, 6 do
		local x = -deckWidth / 2 + (index / 6) * deckWidth
		clad(model, "BalconyBaluster", Vector3.new(0.35, 2.4, 0.35), base * CFrame.new(x, deckY + 1.4, front - reach / 2 + 0.2), VILLAGE.TimberMid, Enum.Material.Wood)
	end
	for _, x in ipairs({ -1, 1 }) do
		clad(model, "BalconyRail", Vector3.new(0.4, 0.5, reach), base * CFrame.new(x * deckWidth / 2, deckY + 2.6, front), VILLAGE.TimberDark, Enum.Material.Wood)
		clad(
			model,
			"BalconyBracket",
			Vector3.new(0.6, 3.4, 0.6),
			base * CFrame.new(x * (deckWidth / 2 - 1), deckY - 1.5, -(depth / 2 + 0.8)) * CFrame.Angles(math.rad(38), 0, 0),
			VILLAGE.TimberDark,
			Enum.Material.Wood
		)
	end
end

--[[ Puts the whole village look on one building. ]]
function WorldService:_dressBuilding(model, base, spec)
	local width, depth, height = spec.Width, spec.Depth, spec.Height
	local doorWidth, doorHeight = spec.DoorWidth, spec.DoorHeight

	-- A tree house has no ground to stand a stone footing on.
	if spec.Footing ~= false then
		self:_stoneFooting(model, base, width, depth, doorWidth)
	end
	self:_timberFrame(model, base, width, depth, height, doorWidth)
	self:_gableRoof(model, base, width, depth, height, spec.RoofColor)

	-- Door surround: heavy posts and a lintel around the opening.
	local jamb = (doorWidth + 1.6) / 2
	for _, x in ipairs({ -1, 1 }) do
		clad(model, "DoorPost", Vector3.new(0.8, doorHeight + 1, 1.2), base * CFrame.new(x * jamb, (doorHeight + 1) / 2, -(depth / 2 + 0.4)), VILLAGE.TimberDark, Enum.Material.Wood)
	end
	clad(model, "DoorLintel", Vector3.new(doorWidth + 3.2, 1, 1.4), base * CFrame.new(0, doorHeight + 0.8, -(depth / 2 + 0.4)), VILLAGE.TimberDark, Enum.Material.Wood)

	-- Lanterns either side of the door, and a banner on the front.
	for _, x in ipairs({ -1, 1 }) do
		self:_hangingLantern(model, base * CFrame.new(x * (jamb + 2.6), doorHeight - 1.5, -(depth / 2 + 1.6)))
	end
	if spec.Banner then
		self:_banner(model, base * CFrame.new(-(width / 2 - 3), height * 0.55, -(depth / 2 + 0.7)), spec.Banner)
		self:_banner(model, base * CFrame.new(width / 2 - 3, height * 0.55, -(depth / 2 + 0.7)), spec.Banner)
	end
	if spec.Balcony then
		self:_balcony(model, base, width, depth, height, doorWidth)
	end
end

local BUILDING_HEIGHT = 14
local BUILDING_DOOR_WIDTH = 10
local BUILDING_DOOR_HEIGHT = 10

--[[
	A town shop or hall. The floor slab runs 3 studs past each wall so the step
	up from the street is a single stud, which a Roblox humanoid walks over.

	The building is turned to face the plaza, so its doorway meets the player
	coming up the road instead of hiding around the back. Returns the model and
	the CFrame of its interior floor, so callers can place fittings inside it.
]]
function WorldService:_building(name, position, color, width, depth, spec)
	local building = Instance.new("Model")
	building.Name = name:gsub(" ", "")
	building.Parent = self._townFolder

	local floorTop = 1
	local doorstep = position + Vector3.new(0, floorTop, 0)
	local plaza = Vector3.new(0, floorTop, 0)
	-- LookVector is -Z, and _shell cuts the doorway in the -Z face.
	local base = CFrame.lookAt(doorstep, plaza)
	-- Cobbled apron outside, boards inside, the way the reference village paves
	-- right up to its doorsteps.
	part(building, "Floor", Vector3.new(width + 6, floorTop, depth + 6), base * CFrame.new(0, -floorTop / 2, 0), VILLAGE.Cobble, Enum.Material.Cobblestone)
	local interiorFloor = part(building, "InteriorFloor", Vector3.new(width - 1, 0.2, depth - 1), base * CFrame.new(0, 0.1, 0), VILLAGE.TimberLight, Enum.Material.WoodPlanks)
	interiorFloor.CanCollide = false

	self:_shell(building, base, {
		Width = width,
		Depth = depth,
		Height = BUILDING_HEIGHT,
		Thickness = WALL_THICKNESS,
		DoorWidth = BUILDING_DOOR_WIDTH,
		DoorHeight = BUILDING_DOOR_HEIGHT,
		Color = color,
		Material = Enum.Material.Sandstone,
		CeilingColor = VILLAGE.TimberMid,
		CeilingMaterial = Enum.Material.WoodPlanks,
	})

	self:_dressBuilding(building, base, {
		Width = width,
		Depth = depth,
		Height = BUILDING_HEIGHT,
		DoorWidth = BUILDING_DOOR_WIDTH,
		DoorHeight = BUILDING_DOOR_HEIGHT,
		Balcony = true,
		Banner = spec and spec.Banner,
		RoofColor = spec and spec.RoofColor,
	})

	local door = part(
		building,
		"Door",
		Vector3.new(BUILDING_DOOR_WIDTH - 0.8, BUILDING_DOOR_HEIGHT - 0.4, 0.5),
		base * CFrame.new(0, (BUILDING_DOOR_HEIGHT - 0.4) / 2, -depth / 2 - 0.4),
		VILLAGE.TimberMid,
		Enum.Material.WoodPlanks
	)
	door.CanCollide = false
	door.Transparency = 0.55

	local sign = part(
		building,
		"Sign",
		Vector3.new(math.min(width - 4, 20), 2.6, 0.5),
		base * CFrame.new(0, BUILDING_DOOR_HEIGHT + 2.2, -depth / 2 - 1),
		VILLAGE.TimberMid,
		Enum.Material.WoodPlanks
	)
	sign.CanCollide = false
	carvedSignFace(sign, name, VILLAGE.Lantern)

	self:_addBlip("Building", name, (spec and spec.Thai) or name, position, width + 6, depth + 6, color)

	local sideWidth = (width - BUILDING_DOOR_WIDTH) / 2
	for _, side in ipairs({ -1, 1 }) do
		local frontAt = base * CFrame.new(side * (BUILDING_DOOR_WIDTH + sideWidth) / 2, 7, -depth / 2 + WALL_THICKNESS / 2)
		local frontWindow = part(building, "Window", Vector3.new(5, 5, WALL_THICKNESS + 0.4), frontAt, VILLAGE.Glass, Enum.Material.Glass)
		frontWindow.CanCollide = false
		frontWindow.Transparency = 0.45
		self:_windowFrame(building, frontAt * CFrame.new(0, 0, -0.5), 5, 5)

		local sideAt = base * CFrame.new(side * (width / 2 - WALL_THICKNESS / 2), 7, 0) * CFrame.Angles(0, math.rad(90), 0)
		local sideWindow = part(building, "Window", Vector3.new(6, 5, WALL_THICKNESS + 0.4), sideAt, VILLAGE.Glass, Enum.Material.Glass)
		sideWindow.CanCollide = false
		sideWindow.Transparency = 0.45
		self:_windowFrame(building, sideAt * CFrame.new(0, 0, -side * 0.5), 6, 5)

		self:_interiorLamp(building, base, Vector3.new(side * width / 4, BUILDING_HEIGHT - 1.2, 0))
	end

	return building, base
end

function WorldService:_pineTree(parent, position, scale, variant)
	scale = scale or 1
	variant = variant or 1
	local tree = Instance.new("Model")
	tree.Name = string.format("WildwoodPine%02d", variant)
	tree:SetAttribute("WildwoodTree", true)
	tree:SetAttribute("Variant", variant)
	tree:SetAttribute("HandPaintedLowPoly", true)
	tree.Parent = parent or self._decorFolder

	part(tree, "Trunk", Vector3.new(2.1, 9, 2.1) * scale, CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)), VILLAGE.TimberMid, Enum.Material.Wood)
	for rootIndex = 1, 4 do
		local angle = (rootIndex - 1) * math.pi / 2 + variant * 0.23
		local root = part(
			tree,
			"RootFlare",
			Vector3.new(0.65, 0.65, 3.4) * scale,
			CFrame.new(position + Vector3.new(math.sin(angle) * 1.35 * scale, 0.45 * scale, math.cos(angle) * 1.35 * scale)) * CFrame.Angles(0, angle, math.rad(8)),
			VILLAGE.TimberDark,
			Enum.Material.Wood
		)
		root.CanCollide = false
	end

	local foliage = { VILLAGE.FoliageDark, VILLAGE.Foliage, VILLAGE.FoliageLight, VILLAGE.Foliage }
	for tier = 1, 4 do
		local width = (11.5 - tier * 1.65 + (variant % 2) * 0.45) * scale
		local height = (5.2 - tier * 0.3) * scale
		local y = (7.2 + tier * 2.35) * scale
		local crown = part(
			tree,
			"PineCrownTier",
			Vector3.new(width, height, width * 0.92),
			CFrame.new(position + Vector3.new(((tier + variant) % 2 - 0.5) * 0.45 * scale, y, 0)) * CFrame.Angles(0, tier * 0.47 + variant, 0),
			foliage[((tier + variant - 2) % #foliage) + 1],
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		crown.CanCollide = tier <= 2
	end
	local tip = part(tree, "PineTip", Vector3.new(2.6, 3.8, 2.6) * scale, CFrame.new(position + Vector3.new(0, 18.2 * scale, 0)), VILLAGE.FoliageLight, Enum.Material.Grass, Enum.PartType.Ball)
	tip.CanCollide = false
	return tree
end

function WorldService:_tree(position, scale)
	return self:_pineTree(self._decorFolder, position, scale, math.floor(math.abs(position.X + position.Z)) % 3 + 1)
end

function WorldService:_mossyCobble(position, variant)
	local stone = part(
		self._decorFolder,
		"MossyCobble",
		Vector3.new(3.3 + (variant % 3) * 0.5, 0.5, 2.7 + (variant % 2) * 0.45),
		CFrame.new(position + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, variant * 0.71, 0),
		variant % 2 == 0 and VILLAGE.Stone or VILLAGE.StoneLight,
		Enum.Material.Rock,
		Enum.PartType.Ball
	)
	stone.CanCollide = false
	stone:SetAttribute("MossyPathTile", true)
	stone:SetAttribute("Variant", variant % 4 + 1)
	local moss = part(self._decorFolder, "PathMoss", Vector3.new(1.6, 0.18, 1.2), stone.CFrame * CFrame.new(0, 0.3, 0), VILLAGE.Moss, Enum.Material.Grass, Enum.PartType.Ball)
	moss.CanCollide = false
	return stone
end

function WorldService:_stringLightSpan(parent, from, to, index)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	local wire = part(parent, "StringLightWire", Vector3.new(0.12, 0.12, length), CFrame.lookAt(middle, to), VILLAGE.TimberDark, Enum.Material.Metal)
	wire.CanCollide = false
	for bulbIndex = 1, 6 do
		local alpha = bulbIndex / 7
		local sag = math.sin(alpha * math.pi) * 1.3
		local at = from + (to - from) * alpha - Vector3.new(0, sag, 0)
		local bulb = part(parent, "StringLightBulb", Vector3.new(0.55, 0.72, 0.55), CFrame.new(at), VILLAGE.Lantern, Enum.Material.Neon, Enum.PartType.Ball)
		bulb.CanCollide = false
		bulb:SetAttribute("NightLampGlow", true)
		bulb:SetAttribute("StringIndex", index)
		local light = Instance.new("PointLight")
		light.Name = "NightLight"
		light.Brightness = 0.8
		light.Range = 12
		light.Color = VILLAGE.Lantern
		light.Parent = bulb
		CollectionService:AddTag(bulb, RemoteNames.LampTag)
	end
end

function WorldService:_flower(position, color)
	local stem = part(self._decorFolder, "FlowerStem", Vector3.new(0.25, 1.5, 0.25), CFrame.new(position + Vector3.new(0, 0.75, 0)), COLORS.Leaf, Enum.Material.SmoothPlastic)
	stem.CanCollide = false
	local bloom = part(self._decorFolder, "Flower", Vector3.new(1.1, 1.1, 1.1), CFrame.new(position + Vector3.new(0, 1.7, 0)), color, Enum.Material.Neon, Enum.PartType.Ball)
	bloom.CanCollide = false
end

function WorldService:_lamp(position, groupName, homeIndex)
	local lamp = Instance.new("Model")
	lamp.Name = (groupName or "Town") .. "LampPost"
	lamp:SetAttribute("AutomaticNightLamp", true)
	if homeIndex then
		lamp:SetAttribute("HomeIndex", homeIndex)
	end
	lamp.Parent = self._decorFolder

	part(lamp, "LampBase", Vector3.new(1.4, 0.55, 1.4), CFrame.new(position + Vector3.new(0, 0.275, 0)), VILLAGE.Stone, Enum.Material.Rock)
	part(lamp, "LampPost", Vector3.new(0.7, 7, 0.7), CFrame.new(position + Vector3.new(0, 3.5, 0)), COLORS.DarkBrown, Enum.Material.Metal)
	part(lamp, "LampArm", Vector3.new(2.4, 0.35, 0.35), CFrame.new(position + Vector3.new(0.85, 7.1, 0)), COLORS.DarkBrown, Enum.Material.Metal)
	part(lamp, "LampCap", Vector3.new(2.25, 0.35, 2.25), CFrame.new(position + Vector3.new(0, 8.35, 0)), COLORS.DarkBrown, Enum.Material.Metal)
	local lightPart = part(lamp, "LampGlow", Vector3.new(1.65, 1.8, 1.65), CFrame.new(position + Vector3.new(0, 7.55, 0)), VILLAGE.Lantern, Enum.Material.Neon)
	lightPart.CanCollide = false
	lightPart:SetAttribute("NightLampGlow", true)
	local light = Instance.new("PointLight")
	light.Name = "NightLight"
	light.Brightness = 1.8
	light.Range = 26
	light.Color = VILLAGE.CanvasLight
	light.Shadows = true
	light.Parent = lightPart
	CollectionService:AddTag(lightPart, RemoteNames.LampTag)
	return lamp
end

function WorldService:_buildPlayground(position)
	local playground = Instance.new("Model")
	playground.Name = "PlaygroundEquipment"
	playground.Parent = self._townFolder
	part(playground, "Sandbox", Vector3.new(24, 1, 18), CFrame.new(position + Vector3.new(0, 0.5, 9)), VILLAGE.Plaster, Enum.Material.Sand)
	part(playground, "SlideDeck", Vector3.new(7, 1, 7), CFrame.new(position + Vector3.new(-8, 7, -5)), COLORS.Purple, Enum.Material.SmoothPlastic)
	part(playground, "Slide", Vector3.new(5, 0.8, 14), CFrame.new(position + Vector3.new(-8, 4.2, 2)) * CFrame.Angles(math.rad(25), 0, 0), COLORS.Pink, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -11, -5 }) do
		part(playground, "Support", Vector3.new(0.8, 7, 0.8), CFrame.new(position + Vector3.new(x, 3.5, -8)), COLORS.Mint, Enum.Material.Metal)
	end
	local archLeft = part(playground, "SwingPost", Vector3.new(0.8, 10, 0.8), CFrame.new(position + Vector3.new(8, 5, -7)), COLORS.Blue, Enum.Material.Metal)
	part(playground, "SwingPost", Vector3.new(0.8, 10, 0.8), CFrame.new(position + Vector3.new(16, 5, -7)), COLORS.Blue, Enum.Material.Metal)
	part(playground, "SwingBar", Vector3.new(9, 0.8, 0.8), CFrame.new(position + Vector3.new(12, 10, -7)), COLORS.Blue, Enum.Material.Metal)
	part(playground, "SwingSeat", Vector3.new(4, 0.5, 2), CFrame.new(position + Vector3.new(12, 3, -7)), COLORS.Pink, Enum.Material.WoodPlanks)
	local carousel = part(playground, "Carousel", Vector3.new(12, 1, 12), CFrame.new(position + Vector3.new(12, 0.8, 10)), COLORS.Purple, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	carousel.CFrame = CFrame.new(position + Vector3.new(12, 0.8, 10)) * CFrame.Angles(0, 0, math.rad(90))
	part(playground, "CarouselPole", Vector3.new(0.8, 6, 0.8), CFrame.new(position + Vector3.new(12, 3.5, 10)), COLORS.Yellow, Enum.Material.Metal)
	for index, color in ipairs({ COLORS.Pink, COLORS.Blue, COLORS.Mint }) do
		part(playground, "PlayBall", Vector3.new(2.5, 2.5, 2.5), CFrame.new(position + Vector3.new(3 + index * 3, 2, 19)), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	for index, color in ipairs({ COLORS.Pink, COLORS.Mint, COLORS.Blue }) do
		part(playground, "LittleTrain", Vector3.new(4, 3, 5), CFrame.new(position + Vector3.new(-1 + index * 5, 1.7, 25)), color, Enum.Material.SmoothPlastic)
	end
	billboard(archLeft, "PLAYGROUND", VILLAGE.WaterLight, UDim2.fromOffset(190, 44))
end

-- One softly turning section of the village path. A chain of short, rotated
-- sections reads as an organic woodland lane while remaining completely flat
-- and easy for young players to walk across.
function WorldService:_pathSegment(parent, name, from, to, width, color)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	local lane = part(
		parent,
		name,
		Vector3.new(width, 0.42, length + 1.5),
		CFrame.lookAt(middle + Vector3.new(0, 0.21, 0), to + Vector3.new(0, 0.21, 0)),
		color or VILLAGE.Cobble,
		Enum.Material.Cobblestone
	)
	lane:SetAttribute("TownPath", true)
	lane:SetAttribute("PathStyle", "OrganicLoop")
	return lane
end

function WorldService:_pathChain(parent, name, points, width, closed)
	local last = closed and #points or (#points - 1)
	for index = 1, last do
		self:_pathSegment(parent, name, points[index], points[index % #points + 1], width)
	end
end

function WorldService:_buildHome(index, baseCFrame)
	local home = Instance.new("Model")
	home.Name = string.format("Home%02d", index)
	home:SetAttribute("OwnerUserId", 0)
	home:SetAttribute("HouseStyle", "A_PorchGable")
	home:SetAttribute("ApprovedDesign", "A")
	home:SetAttribute("ReferenceFaithfulRebuild", true)
	home:SetAttribute("LegacyVillageDress", false)
	home.Parent = self._homesFolder

	local function localPart(name, size, offset, color, material)
		return part(home, name, size, baseCFrame * CFrame.new(offset), color, material)
	end
	local function visual(name, size, cframe, color, material, shape)
		local piece = part(home, name, size, cframe, color, material or Enum.Material.WoodPlanks, shape)
		piece.CanCollide = false
		return piece
	end

	local floorTop = 1
	local width, depth, height = 30, 22, 12
	local doorWidth, doorHeight, doorOffset = 7, 8.2, 4

	local floor = localPart("Floor", Vector3.new(width, floorTop, depth), Vector3.new(0, floorTop / 2, 0), PORCH_GABLE.Coffee, Enum.Material.WoodPlanks)
	localPart("Porch", Vector3.new(32, floorTop, 9), Vector3.new(0, floorTop / 2, -depth / 2 - 4.5), PORCH_GABLE.Coffee, Enum.Material.WoodPlanks)
	localPart("PorchStep", Vector3.new(9, 0.45, 3), Vector3.new(doorOffset, 0.225, -depth / 2 - 10.1), PORCH_GABLE.StoneLight, Enum.Material.Slate)
	localPart("PorchStep", Vector3.new(7, 0.8, 2.2), Vector3.new(doorOffset, 0.4, -depth / 2 - 8), PORCH_GABLE.Peanut, Enum.Material.WoodPlanks)

	local base = baseCFrame * CFrame.new(0, floorTop, 0)
	local shell = self:_shell(home, base, {
		Width = width,
		Depth = depth,
		Height = height,
		Thickness = WALL_THICKNESS,
		DoorWidth = doorWidth,
		DoorHeight = doorHeight,
		DoorOffset = doorOffset,
		Color = PORCH_GABLE.Coffee,
		Material = Enum.Material.WoodPlanks,
		CeilingColor = PORCH_GABLE.Mocha,
		CeilingMaterial = Enum.Material.WoodPlanks,
		InteriorOffset = 2,
	})
	local walls = {}
	for _, wall in ipairs(shell.Walls) do
		if wall.Name ~= "Ceiling" then
			table.insert(walls, wall)
		end
	end

	-- Stone plinth: broad, irregular-looking courses like the reference, with a
	-- real gap at the offset doorway. These are decorative and never block it.
	for _, side in ipairs({ -1, 1 }) do
		visual("StoneFoundation", Vector3.new(1.5, 3.2, depth + 2), base * CFrame.new(side * (width / 2 + 0.25), 1, 0), PORCH_GABLE.Stone, Enum.Material.Slate)
	end
	visual("StoneFoundation", Vector3.new(width + 1.5, 3.2, 1.4), base * CFrame.new(0, 1, depth / 2 + 0.25), PORCH_GABLE.Stone, Enum.Material.Slate)
	visual("StoneFoundation", Vector3.new(13, 3.2, 1.4), base * CFrame.new(-8.5, 1, -depth / 2 - 0.25), PORCH_GABLE.StoneLight, Enum.Material.Slate)
	visual("StoneFoundation", Vector3.new(8, 3.2, 1.4), base * CFrame.new(11, 1, -depth / 2 - 0.25), PORCH_GABLE.Stone, Enum.Material.Slate)
	for course = 1, 2 do
		for stoneIndex = 1, 7 do
			local x = -14 + (stoneIndex - 1) * 4.6 + (course % 2) * 1.1
			visual("FoundationStone", Vector3.new(3.8, 1.25, 0.45), base * CFrame.new(x, course * 1.2 - 0.2, -depth / 2 - 1), stoneIndex % 2 == 0 and PORCH_GABLE.Stone or PORCH_GABLE.StoneLight, Enum.Material.Rock)
		end
	end

	-- Horizontal plank seams and a restrained frame replace the old plaster,
	-- banners and busy Tudor dressing. All five approved brown swatches appear in
	-- functional timber roles exactly as supplied.
	for level = 1.5, height - 0.8, 1.5 do
		for _, face in ipairs({ -1, 1 }) do
			visual("WallPlankSeam", Vector3.new(width, 0.16, 0.2), base * CFrame.new(0, level, face * (depth / 2 + 0.52)), PORCH_GABLE.Brown, Enum.Material.Wood)
		end
		for _, side in ipairs({ -1, 1 }) do
			visual("WallPlankSeam", Vector3.new(0.2, 0.16, depth), base * CFrame.new(side * (width / 2 + 0.52), level, 0), PORCH_GABLE.Brown, Enum.Material.Wood)
		end
	end
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			visual("CornerPost", Vector3.new(1.4, height, 1.4), base * CFrame.new(x * width / 2, height / 2, z * depth / 2), PORCH_GABLE.Hickory, Enum.Material.Wood)
		end
	end
	for _, y in ipairs({ 0.6, height - 0.7 }) do
		for _, z in ipairs({ -1, 1 }) do
			visual("WallRail", Vector3.new(width + 1, 1.1, 0.8), base * CFrame.new(0, y, z * (depth / 2 + 0.6)), PORCH_GABLE.Hickory, Enum.Material.Wood)
		end
	end

	-- Steep terracotta main roof with seven visible shingle courses. Its height
	-- and dark ridge reproduce the dominant silhouette of concept A.
	local roofOverhang = 3.5
	local roofHalfWidth = width / 2 + roofOverhang
	local roofRise = 15
	local roofSlope = math.sqrt(roofHalfWidth ^ 2 + roofRise ^ 2)
	local roofAngle = math.atan2(roofRise, roofHalfWidth)
	local roofDepth = depth + 6
	local roof
	local roofPlanes = {}
	for _, side in ipairs({ -1, 1 }) do
		local plane = visual(
			"RoofPlane",
			Vector3.new(roofSlope, 1.1, roofDepth),
			base * CFrame.new(side * roofHalfWidth / 2, height + roofRise / 2, 0) * CFrame.Angles(0, 0, -side * roofAngle),
			PORCH_GABLE.RoofTile,
			Enum.Material.Slate
		)
		roof = roof or plane
		table.insert(roofPlanes, plane)
		for course = 1, 7 do
			local along = (course / 8 - 0.5) * roofSlope
			visual(
				"RoofCourse",
				Vector3.new(0.75, 0.28, roofDepth + 0.2),
				plane.CFrame * CFrame.new(along, 0.62, 0),
				course % 2 == 0 and PORCH_GABLE.RoofHighlight or PORCH_GABLE.RoofShadow,
				Enum.Material.Slate
			)
		end
	end
	visual("RoofRidge", Vector3.new(1.8, 1.5, roofDepth + 1), base * CFrame.new(0, height + roofRise + 0.3, 0), PORCH_GABLE.Brown, Enum.Material.Wood)
	for _, zFace in ipairs({ -1, 1 }) do
		for course = 1, 14 do
			local fraction = (course - 0.5) / 14
			local courseWidth = width * (1 - fraction)
			visual(
				"GableCourse",
				Vector3.new(math.max(0.7, courseWidth), roofRise / 14 + 0.08, 0.7),
				base * CFrame.new(0, height + fraction * roofRise, zFace * (depth / 2 + 0.25)),
				course % 3 == 0 and PORCH_GABLE.Peanut or PORCH_GABLE.Coffee,
				Enum.Material.WoodPlanks
			)
		end
	end
	visual("GablePost", Vector3.new(1.2, roofRise, 0.8), base * CFrame.new(0, height + roofRise / 2, -depth / 2 - 0.75), PORCH_GABLE.Hickory, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		visual("WallBrace", Vector3.new(10.5, 0.9, 0.7), base * CFrame.new(side * 4.1, height + 6, -depth / 2 - 0.8) * CFrame.Angles(0, 0, -side * math.rad(46)), PORCH_GABLE.Hickory, Enum.Material.Wood)
	end

	-- The porch has its own shallow tiled roof, four heavy posts on stone feet,
	-- exposed brackets and open railing just like the approved front elevation.
	local canopy = visual("PorchCanopy", Vector3.new(33, 1, 10), base * CFrame.new(0, 9.1, -depth / 2 - 4.6) * CFrame.Angles(math.rad(-12), 0, 0), PORCH_GABLE.RoofTile, Enum.Material.Slate)
	for course = 1, 4 do
		visual("PorchRoofCourse", Vector3.new(33.2, 0.3, 0.65), canopy.CFrame * CFrame.new(0, 0.58, (course - 2.5) * 2.25), course % 2 == 0 and PORCH_GABLE.RoofHighlight or PORCH_GABLE.RoofShadow, Enum.Material.Slate)
	end
	visual("PorchCanopyTrim", Vector3.new(33, 1, 0.8), base * CFrame.new(0, 8.25, -depth / 2 - 9.1), PORCH_GABLE.Brown, Enum.Material.Wood)
	for _, x in ipairs({ -13, -5, 6, 13 }) do
		visual("PorchPostBase", Vector3.new(2.2, 2.4, 2.2), base * CFrame.new(x, 1.2, -depth / 2 - 8), PORCH_GABLE.StoneLight, Enum.Material.Slate)
		visual("PorchPost", Vector3.new(1.35, 7.2, 1.35), base * CFrame.new(x, 5.7, -depth / 2 - 8), PORCH_GABLE.Hickory, Enum.Material.Wood)
		visual("EaveBracket", Vector3.new(3.3, 0.75, 0.75), base * CFrame.new(x + (x < 0 and 1.1 or -1.1), 7.3, -depth / 2 - 7.6) * CFrame.Angles(0, 0, x < 0 and math.rad(42) or math.rad(-42)), PORCH_GABLE.Mocha, Enum.Material.Wood)
	end
	for _, rail in ipairs({ { X = -9.2, W = 6.2 }, { X = 10.5, W = 5 } }) do
		visual("PorchRail", Vector3.new(rail.W, 0.65, 0.55), base * CFrame.new(rail.X, 3, -depth / 2 - 8.5), PORCH_GABLE.Hickory, Enum.Material.Wood)
		for postIndex = 1, 4 do
			local x = rail.X - rail.W / 2 + postIndex * rail.W / 5
			visual("PorchBaluster", Vector3.new(0.38, 2.5, 0.38), base * CFrame.new(x, 1.75, -depth / 2 - 8.5), PORCH_GABLE.Peanut, Enum.Material.Wood)
		end
	end

	local function window(cframe, windowWidth, windowHeight, sideWindow, shutters, flowerBox)
		local glow = visual(sideWindow and "SideWindowGlow" or "WindowGlow", Vector3.new(windowWidth, windowHeight, 0.28), cframe, PORCH_GABLE.Window, Enum.Material.Glass)
		glow.Transparency = 0.12
		local halfW, halfH = windowWidth / 2, windowHeight / 2
		for _, x in ipairs({ -1, 1 }) do
			visual("WindowFrame", Vector3.new(0.55, windowHeight + 0.8, 0.7), cframe * CFrame.new(x * (halfW + 0.25), 0, 0), PORCH_GABLE.Hickory, Enum.Material.Wood)
		end
		for _, y in ipairs({ -1, 1 }) do
			visual("WindowFrame", Vector3.new(windowWidth + 1, 0.55, 0.7), cframe * CFrame.new(0, y * (halfH + 0.25), 0), PORCH_GABLE.Hickory, Enum.Material.Wood)
		end
		visual("WindowMullion", Vector3.new(0.35, windowHeight, 0.5), cframe, PORCH_GABLE.Hickory, Enum.Material.Wood)
		visual("WindowMullion", Vector3.new(windowWidth, 0.35, 0.5), cframe, PORCH_GABLE.Hickory, Enum.Material.Wood)
		if shutters then
			for _, side in ipairs({ -1, 1 }) do
				visual("WindowShutter", Vector3.new(1.45, windowHeight + 0.9, 0.55), cframe * CFrame.new(side * (halfW + 1.15), 0, 0), PORCH_GABLE.Shutter, Enum.Material.WoodPlanks)
			end
		end
		if flowerBox then
			visual("WindowBox", Vector3.new(windowWidth + 1.2, 1.1, 1.5), cframe * CFrame.new(0, -halfH - 1, -0.6), PORCH_GABLE.Hickory, Enum.Material.WoodPlanks)
			for flowerIndex = 1, 5 do
				local flowerX = -windowWidth / 2 + flowerIndex * windowWidth / 6
				visual("WindowBoxLeaf", Vector3.new(0.75, 0.75, 0.75), cframe * CFrame.new(flowerX, -halfH - 0.25, -0.85), PORCH_GABLE.FlowerLeaf, Enum.Material.Grass, Enum.PartType.Ball)
				visual("WindowBoxFlower", Vector3.new(0.35, 0.35, 0.35), cframe * CFrame.new(flowerX + 0.18, -halfH - 0.05, -1.15), PORCH_GABLE.Flower, Enum.Material.Neon, Enum.PartType.Ball)
			end
		end
		return glow
	end

	window(base * CFrame.new(-6, 5.5, -depth / 2 - 0.65), 4.8, 5, false, true, true)
	window(base * CFrame.new(0, height + 6.4, -depth / 2 - 0.7), 4.1, 4.4, false, true, false)
	for _, side in ipairs({ -1, 1 }) do
		window(base * CFrame.new(side * (width / 2 + 0.65), 5.5, 2) * CFrame.Angles(0, math.rad(90), 0), 4.8, 5, true, false, false)
	end

	local function houseLantern(cframe)
		visual("LanternBracket", Vector3.new(0.35, 0.35, 2), cframe * CFrame.new(0, 1.4, 0.8), PORCH_GABLE.Brown, Enum.Material.Metal)
		visual("LanternCap", Vector3.new(1.35, 0.3, 1.35), cframe * CFrame.new(0, 0.85, 0), PORCH_GABLE.Brown, Enum.Material.Metal)
		local glow = visual("LanternGlow", Vector3.new(1, 1.5, 1), cframe, PORCH_GABLE.Window, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Brightness = 1.5
		light.Range = 20
		light.Color = PORCH_GABLE.Window
		light.Parent = glow
	end
	houseLantern(base * CFrame.new(doorOffset - 4.8, 6.2, -depth / 2 - 1.6))
	houseLantern(base * CFrame.new(doorOffset + 4.8, 6.2, -depth / 2 - 1.6))

	-- Left-side masonry chimney assembled from alternating blocks, rather than
	-- one smooth old-village column.
	visual("StoneChimney", Vector3.new(4.6, 25, 4.6), base * CFrame.new(-10.5, 12.5, 4), PORCH_GABLE.Stone, Enum.Material.Slate)
	for course = 1, 9 do
		local offset = course % 2 == 0 and 0.55 or -0.55
		for _, side in ipairs({ -1, 1 }) do
			visual("ChimneyStone", Vector3.new(2.1, 2.35, 4.85), base * CFrame.new(-10.5 + offset + side * 1.05, course * 2.55 - 0.8, 4), course % 3 == 0 and PORCH_GABLE.StoneLight or PORCH_GABLE.Stone, Enum.Material.Rock)
		end
	end
	visual("ChimneyCap", Vector3.new(5.5, 1.2, 5.5), base * CFrame.new(-10.5, 25.2, 4), PORCH_GABLE.StoneLight, Enum.Material.Slate)

	local interiorLamp = visual("CeilingLamp", Vector3.new(3, 0.8, 3), base * CFrame.new(0, height - 1.2, 2), PORCH_GABLE.Window, Enum.Material.Neon)
	local interiorLight = Instance.new("PointLight")
	interiorLight.Brightness = 1.6
	interiorLight.Range = 26
	interiorLight.Color = PORCH_GABLE.Window
	interiorLight.Parent = interiorLamp

	local door = localPart("Door", Vector3.new(doorWidth - 0.4, doorHeight - 0.3, 0.6), Vector3.new(doorOffset, floorTop + (doorHeight - 0.3) / 2, -depth / 2 - 0.35), PORCH_GABLE.Hickory, Enum.Material.WoodPlanks)
	door.CanCollide = false
	door.Transparency = 0.08
	visual("DoorFrame", Vector3.new(0.8, doorHeight + 1, 1), base * CFrame.new(doorOffset - doorWidth / 2 - 0.5, (doorHeight + 1) / 2, -depth / 2 - 0.6), PORCH_GABLE.Brown, Enum.Material.Wood)
	visual("DoorFrame", Vector3.new(0.8, doorHeight + 1, 1), base * CFrame.new(doorOffset + doorWidth / 2 + 0.5, (doorHeight + 1) / 2, -depth / 2 - 0.6), PORCH_GABLE.Brown, Enum.Material.Wood)
	visual("DoorFrame", Vector3.new(doorWidth + 2, 0.9, 1), base * CFrame.new(doorOffset, doorHeight + 0.7, -depth / 2 - 0.6), PORCH_GABLE.Brown, Enum.Material.Wood)
	local doorWindow = visual("DoorWindow", Vector3.new(2.4, 3, 0.25), base * CFrame.new(doorOffset, 5.3, -depth / 2 - 0.72), PORCH_GABLE.Window, Enum.Material.Glass)
	doorWindow.Transparency = 0.15
	visual("DoorHandle", Vector3.new(0.45, 0.45, 0.45), base * CFrame.new(doorOffset + 2.3, 3.7, -depth / 2 - 0.9), PORCH_GABLE.Peanut, Enum.Material.Metal, Enum.PartType.Ball)
	local ownerLabel = billboard(door, "A cozy home", PORCH_GABLE.Peanut, UDim2.fromOffset(210, 48))
	local doorPrompt = prompt(door, bilingual("Go to my home", "ไปบ้านของฉัน"), bilingual("Home", "บ้าน"))
	self:_connectPrompt(doorPrompt, "Teleport", { destination = "Home" })

	local spawnPart = localPart("HomeSpawn", Vector3.new(5, 1, 5), Vector3.new(doorOffset, floorTop + 0.5, -24), COLORS.Mint)
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	local interiorSpawn = localPart("InteriorSpawn", Vector3.new(5, 1, 3), Vector3.new(0, floorTop + 0.5, -3), COLORS.Mint)
	interiorSpawn.Transparency = 1
	interiorSpawn.CanCollide = false

	local furnitureFolder = Instance.new("Folder")
	furnitureFolder.Name = "PlacedFurniture"
	furnitureFolder.Parent = home
	local adventureCampFolder = Instance.new("Folder")
	adventureCampFolder.Name = "AdventureCamp"
	adventureCampFolder.Parent = home

	local gardenParts = {}
	for slot = 1, Config.GardenSlots do
		local row = math.floor((slot - 1) / 2)
		local column = (slot - 1) % 2
		local soil = localPart(
			string.format("GardenSlot%d", slot),
			Vector3.new(5, 1, 5),
			Vector3.new(19 + column * 6, 0.6, -3 + row * 6),
			COLORS.Soil,
			Enum.Material.Ground
		)
		local gardenPrompt = prompt(
			soil,
			bilingual("Plant Daisy", "ปลูกเดซี่"),
			bilingual(string.format("Garden patch %d", slot), string.format("แปลงสวน %d", slot))
		)
		self:_connectPrompt(gardenPrompt, "GardenSmart", { slot = slot }, index)
		gardenParts[slot] = soil
	end

	local mailbox = localPart("Mailbox", Vector3.new(2, 3, 2), Vector3.new(-13, 2, -23), PORCH_GABLE.Hickory, Enum.Material.WoodPlanks)
	billboard(mailbox, string.format("Home %d", index), PORCH_GABLE.Peanut, UDim2.fromOffset(120, 36))

	-- Player paint is deliberately narrow: the six structural wall pieces and
	-- the two main roof planes only. A BasePart colour appears on every face, so
	-- this covers the visible interior and exterior wall/roof surfaces together.
	-- All dimension-defining trim, shingles, gables, stone, porch, doors,
	-- windows, floor and ceiling retain their authored colours.
	local paintParts = {}
	for _, surface in ipairs(walls) do
		surface:SetAttribute("HomePaintSurface", true)
		table.insert(paintParts, surface)
	end
	for _, surface in ipairs(roofPlanes) do
		surface:SetAttribute("HomePaintSurface", true)
		table.insert(paintParts, surface)
	end

	-- A pair of automatic lamp posts frames every front path. They live in Decor
	-- so repainting or refreshing the owned house never removes the street light.
	for side = -1, 1, 2 do
		local lampPosition = (baseCFrame * CFrame.new(side * 11, 0, -24.5)).Position
		self:_lamp(lampPosition, string.format("Home%02d", index), index)
	end

	self:_addBlip(
		"Home",
		string.format("Home %d", index),
		string.format("บ้าน %d", index),
		baseCFrame.Position,
		width + 4,
		depth + 4,
		PORCH_GABLE.Coffee,
		index
	)

	local record = {
		Index = index,
		Model = home,
		BaseCFrame = baseCFrame,
		Floor = floor,
		Walls = walls,
		PaintParts = paintParts,
		Roof = roof,
		Door = door,
		OwnerLabel = ownerLabel,
		Spawn = spawnPart,
		InteriorSpawn = interiorSpawn,
		GardenParts = gardenParts,
		FurnitureFolder = furnitureFolder,
		AdventureCampFolder = adventureCampFolder,
		Owner = nil,
	}
	table.insert(self._homes, record)
end

-- Sunrise Mountain, from the base up. Each terrace is 8 studs above the one
-- below and pulls back 11 studs in Z, which is the ledge the stairs live on.
local MOUNTAIN_LEVELS = {
	{ HalfX = 60, HalfZ = 56, Top = 6 },
	{ HalfX = 50, HalfZ = 45, Top = 14 },
	{ HalfX = 40, HalfZ = 34, Top = 22 },
	{ HalfX = 30, HalfZ = 23, Top = 30 },
	{ HalfX = 20, HalfZ = 12, Top = 38 },
}

--[[
	One flight of steps up the front of the mountain, from the terrace at
	`fromTop` to the one at `toTop`. The steps run sideways along X so they fit
	on the ledge, and press against the face of the terrace above (`faceOffsetZ`)
	so the last step lands level with it and you simply walk forward off the top.
]]
function WorldService:_mountainStairs(model, center, fromTop, toTop, faceOffsetZ)
	local steps = 6
	local run = 2.2
	local depth = 6
	local startX = -7
	for index = 1, steps do
		local top = fromTop + (toTop - fromTop) * (index / steps)
		part(
			model,
			"MountainStair",
			Vector3.new(run, top - fromTop + 1, depth),
			CFrame.new(center + Vector3.new(startX + (index - 0.5) * run, (fromTop + top) / 2 - 0.5, faceOffsetZ - depth / 2)),
			VILLAGE.StoneLight,
			Enum.Material.Rock
		)
	end
end

function WorldService:_adventureNode(parent, name, position, color, zoneId, resourceId, englishAction, thaiAction)
	local node = part(parent, name, Vector3.new(4, 4, 4), CFrame.new(position), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local resource = Catalog.AdventureResources[resourceId]
	local interaction = prompt(
		node,
		bilingual(englishAction, thaiAction),
		bilingual(resource.DisplayName, resource.DisplayNameThai)
	)
	self:_connectPrompt(interaction, "AdventureCollect", { zone = zoneId, resource = resourceId })
	return node
end

function WorldService:_buildAdventureWorld()
	local adventure = Instance.new("Folder")
	adventure.Name = "WildwoodAdventure"
	adventure.Parent = self._world
	self._adventureFolder = adventure

	part(adventure, "AdventureGround", Vector3.new(520, 2, 410), CFrame.new(0, -0.8, 480), ADVENTURE_COLORS.ForestGreen, Enum.Material.Grass)
	part(adventure, "AdventureTrail", Vector3.new(22, 0.5, 390), CFrame.new(0, 0.3, 465), ADVENTURE_COLORS.WarmBeige, Enum.Material.Cobblestone)

	local campCenter = Vector3.new(Config.Waypoints.AdventureCamp.X, 0, Config.Waypoints.AdventureCamp.Z + 25)
	local camp = Instance.new("Model")
	camp.Name = "AdventureCamp"
	camp.Parent = adventure
	local campSign = part(camp, "CampSign", Vector3.new(15, 7, 1), CFrame.new(campCenter + Vector3.new(0, 4, -16)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	campSign.CanCollide = false
	carvedSignFace(campSign, "ศูนย์ผจญภัย\nADVENTURE CAMP", ADVENTURE_COLORS.SoftYellow)
	local upgradePrompt = prompt(campSign, bilingual("Upgrade camp", "อัปเกรดแคมป์"), bilingual("Build together", "สร้างไปด้วยกัน"))
	self:_connectPrompt(upgradePrompt, "AdventureUpgradeCamp", {})
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2
		local stone = part(camp, "FireRing", Vector3.new(2, 1.2, 2), CFrame.new(campCenter + Vector3.new(math.cos(angle) * 5, 0.8, math.sin(angle) * 5)), VILLAGE.Stone, Enum.Material.Slate, Enum.PartType.Ball)
		stone.CanCollide = false
	end
	local fire = part(camp, "Campfire", Vector3.new(4, 4, 4), CFrame.new(campCenter + Vector3.new(0, 2.3, 0)), ADVENTURE_COLORS.SunsetOrange, Enum.Material.Neon, Enum.PartType.Ball)
	local fireLight = Instance.new("PointLight")
	fireLight.Color = ADVENTURE_COLORS.SoftYellow
	fireLight.Brightness = 1.2
	fireLight.Range = 28
	fireLight.Parent = fire
	part(camp, "CampTable", Vector3.new(12, 1, 6), CFrame.new(campCenter + Vector3.new(13, 2.6, 4)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)

	local forestCenter = Config.Waypoints.WildwoodForest - Vector3.new(0, 4, 0)
	local forest = Instance.new("Model")
	forest.Name = "WildwoodForest"
	forest.Parent = adventure
	local forestSign = part(forest, "ForestSign", Vector3.new(13, 6, 1), CFrame.new(forestCenter + Vector3.new(0, 3.5, -24)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	forestSign.CanCollide = false
	carvedSignFace(forestSign, "ป่าไวลด์วูด\nWILDWOOD FOREST", ADVENTURE_COLORS.SoftYellow)
	for index = 1, 16 do
		local x = ((index - 1) % 4) * 22 - 34
		local z = math.floor((index - 1) / 4) * 23 - 22
		local treePosition = forestCenter + Vector3.new(x, 0, z)
		self:_pineTree(forest, treePosition, 1.15 + (index % 3) * 0.12, index % 3 + 1)
	end
	part(forest, "HiddenPath", Vector3.new(8, 0.4, 62), CFrame.new(forestCenter + Vector3.new(-28, 0.3, 18)) * CFrame.Angles(0, math.rad(-28), 0), ADVENTURE_COLORS.WarmBeige, Enum.Material.Ground)
	self:_adventureNode(forest, "WoodBundle", forestCenter + Vector3.new(-10, 2, 6), ADVENTURE_COLORS.WoodBrown, "WildwoodForest", "Wood", "Collect wood", "เก็บไม้")
	self:_adventureNode(forest, "HerbBush", forestCenter + Vector3.new(17, 2, -2), ADVENTURE_COLORS.ForestGreen, "WildwoodForest", "Herbs", "Gather herbs", "เก็บสมุนไพร")
	self:_adventureNode(forest, "SecretHerbCache", forestCenter + Vector3.new(-44, 2, 35), ADVENTURE_COLORS.SoftYellow, "WildwoodForest", "Herbs", "Open secret cache", "เปิดที่ซ่อนลับ")

	local mountainCenter = Vector3.new(Config.Waypoints.Mountain.X, 0, Config.Waypoints.Mountain.Z)
	local mountain = Instance.new("Model")
	mountain.Name = "SunriseMountain"
	mountain.Parent = adventure

	-- The terraces used to rise ten studs at a time onto a four-stud ledge, so
	-- the summit could only be reached by teleporting and the crystal was walled
	-- up inside the rock. Each terrace now leaves an eleven-stud ledge: six for a
	-- flight of steps against the face above, five for a walkway along the front
	-- to the foot of the next flight.
	for index, level in ipairs(MOUNTAIN_LEVELS) do
		part(
			mountain,
			"MountainStep",
			Vector3.new(level.HalfX * 2, level.Top + 2, level.HalfZ * 2),
			CFrame.new(mountainCenter + Vector3.new(0, (level.Top - 2) / 2, 0)),
			({ VILLAGE.StoneDeep, VILLAGE.Stone, VILLAGE.StoneLight })[((index - 1) % 3) + 1],
			Enum.Material.Rock
		)
	end

	local groundTop = 0.2
	self:_mountainStairs(mountain, mountainCenter, groundTop, MOUNTAIN_LEVELS[1].Top, -MOUNTAIN_LEVELS[1].HalfZ)
	for index = 1, #MOUNTAIN_LEVELS - 1 do
		local below, above = MOUNTAIN_LEVELS[index], MOUNTAIN_LEVELS[index + 1]
		self:_mountainStairs(mountain, mountainCenter, below.Top, above.Top, -above.HalfZ)
	end

	local summit = MOUNTAIN_LEVELS[#MOUNTAIN_LEVELS]
	local summitMarker = part(mountain, "SummitMarker", Vector3.new(2, 1, 2), CFrame.new(mountainCenter + Vector3.new(0, summit.Top + 0.5, 0)), COLORS.Mint, Enum.Material.SmoothPlastic)
	summitMarker.CanCollide = false
	summitMarker.Transparency = 1
	summitMarker.CastShadow = false
	mountain:SetAttribute("Climbable", true)

	local mountainSign = part(mountain, "MountainSign", Vector3.new(14, 6, 1), CFrame.new(mountainCenter + Vector3.new(0, 3.5, -70)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	mountainSign.CanCollide = false
	carvedSignFace(mountainSign, "ภูเขาแสงตะวัน\nSUNRISE MOUNTAIN", ADVENTURE_COLORS.SoftYellow)
	-- Stone sits on the second terrace, beside the walkway you climb past.
	self:_adventureNode(mountain, "StonePile", mountainCenter + Vector3.new(-25, MOUNTAIN_LEVELS[2].Top + 2, -42), VILLAGE.StoneLight, "Mountain", "Stone", "Mine stone", "ขุดหิน")
	-- The crystal is the reward for the climb, so it sits out on the summit.
	local mountainCrystal = self:_adventureNode(mountain, "MountainCrystal", mountainCenter + Vector3.new(10, summit.Top + 2, 0), VILLAGE.WaterLight, "Mountain", "Crystal", "Find crystal", "หาคริสตัล")
	mountainCrystal.Material = Enum.Material.Neon

	local riverCenter = Config.Waypoints.RiverAdventure - Vector3.new(0, 4, 0)
	local river = Instance.new("Model")
	river.Name = "RiverAndLake"
	river.Parent = adventure
	local water = part(river, "AdventureRiver", Vector3.new(100, 1, 96), CFrame.new(riverCenter + Vector3.new(0, 0.1, 0)), ADVENTURE_COLORS.RiverBlue, Enum.Material.Glass)
	water.Transparency = 0.18
	local riverSign = part(river, "RiverSign", Vector3.new(14, 6, 1), CFrame.new(riverCenter + Vector3.new(0, 3.5, -54)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	riverSign.CanCollide = false
	carvedSignFace(riverSign, "แม่น้ำและทะเลสาบ\nRIVER & LAKE", ADVENTURE_COLORS.SoftYellow)
	for plank = -4, 4 do
		part(river, "BridgePlank", Vector3.new(9, 1, 6), CFrame.new(riverCenter + Vector3.new(plank * 8, 2, 0)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	end
	local boat = Instance.new("Model")
	boat.Name = "ExplorerBoat"
	boat.Parent = river
	part(boat, "Hull", Vector3.new(13, 2, 7), CFrame.new(riverCenter + Vector3.new(-18, 1.6, 24)) * CFrame.Angles(0, math.rad(18), 0), ADVENTURE_COLORS.SunsetOrange, Enum.Material.WoodPlanks)
	part(boat, "Seat", Vector3.new(5, 1, 4), CFrame.new(riverCenter + Vector3.new(-18, 3, 24)) * CFrame.Angles(0, math.rad(18), 0), ADVENTURE_COLORS.WarmBeige, Enum.Material.WoodPlanks)
	part(boat, "Mast", Vector3.new(0.7, 10, 0.7), CFrame.new(riverCenter + Vector3.new(-18, 7, 24)), ADVENTURE_COLORS.WoodBrown, Enum.Material.Wood)
	self:_adventureNode(river, "FishingSpot", riverCenter + Vector3.new(26, 2, -30), ADVENTURE_COLORS.RiverBlue, "RiverAdventure", "Fish", "Go fishing", "ตกปลา")
	self:_adventureNode(river, "RiverHerbs", riverCenter + Vector3.new(-30, 2, 35), ADVENTURE_COLORS.ForestGreen, "RiverAdventure", "Herbs", "Gather river herbs", "เก็บสมุนไพรริมน้ำ")

	-- The cave is a room, not a rock wall: the crystals and the rune puzzle are
	-- all inside, reached through a mouth in the front face.
	local caveCenter = Vector3.new(Config.Waypoints.MysteryCave.X, 0, Config.Waypoints.MysteryCave.Z + 40)
	local cave = Instance.new("Model")
	cave.Name = "MysteryCave"
	cave.Parent = adventure

	local caveRock = VILLAGE.StoneDeep
	local caveFloorTop = 1
	part(cave, "CaveFloor", Vector3.new(84, caveFloorTop, 56), CFrame.new(caveCenter + Vector3.new(0, caveFloorTop / 2, 0)), VILLAGE.Stone, Enum.Material.Slate)
	local caveBase = CFrame.new(caveCenter + Vector3.new(0, caveFloorTop, 0))
	self:_shell(cave, caveBase, {
		Width = 78,
		Depth = 50,
		Height = 18,
		Thickness = 4,
		DoorWidth = 16,
		DoorHeight = 13,
		Color = caveRock,
		Material = Enum.Material.Slate,
		CeilingColor = VILLAGE.NightSky,
		CeilingMaterial = Enum.Material.Slate,
		CeilingThickness = 4,
	})

	-- Boulders piled over the shell so it reads as a cave and not a stone box.
	for index = -3, 3 do
		local boulder = part(
			cave,
			"CaveRock",
			Vector3.new(24, 24, 24),
			CFrame.new(caveCenter + Vector3.new(index * 16, 18, 14 + math.abs(index) * 4)),
			caveRock,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		boulder.CanCollide = false
	end

	local caveSign = part(cave, "CaveSign", Vector3.new(13, 6, 1), CFrame.new(caveCenter + Vector3.new(0, 3.5, -34)), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	caveSign.CanCollide = false
	carvedSignFace(caveSign, "ถ้ำลึกลับ\nMYSTERY CAVE", ADVENTURE_COLORS.SoftYellow)

	local crystal = self:_adventureNode(cave, "CaveCrystal", caveCenter + Vector3.new(-26, 3, -5), VILLAGE.WaterLight, "MysteryCave", "Crystal", "Collect crystal", "เก็บคริสตัล")
	crystal.Material = Enum.Material.Neon
	self:_adventureNode(cave, "CaveStone", caveCenter + Vector3.new(27, 2, -3), VILLAGE.Stone, "MysteryCave", "Stone", "Collect cave stone", "เก็บหินถ้ำ")

	-- A sealed cave is a dark cave, so the crystal seams light the room.
	for _, glowOffset in ipairs({ Vector3.new(-22, 14, 12), Vector3.new(22, 14, 12), Vector3.new(0, 14, -10) }) do
		local seam = part(cave, "CrystalSeam", Vector3.new(3, 3, 3), CFrame.new(caveCenter + glowOffset), VILLAGE.WaterLight, Enum.Material.Neon, Enum.PartType.Ball)
		seam.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 1.4
		light.Range = 40
		light.Color = VILLAGE.Glass
		light.Parent = seam
	end

	self._caveRunes = {}
	local runeInfo = {
		{ Id = "Leaf", Thai = "ใบไม้", Color = ADVENTURE_COLORS.ForestGreen, X = -12 },
		{ Id = "River", Thai = "สายน้ำ", Color = ADVENTURE_COLORS.RiverBlue, X = 0 },
		{ Id = "Sun", Thai = "ดวงอาทิตย์", Color = ADVENTURE_COLORS.SoftYellow, X = 12 },
	}
	for _, info in ipairs(runeInfo) do
		local rune = part(cave, info.Id .. "Rune", Vector3.new(8, 8, 2), CFrame.new(caveCenter + Vector3.new(info.X, 5, 16)), info.Color, Enum.Material.Neon)
		local runePrompt = prompt(rune, bilingual("Touch " .. info.Id, "แตะรูน" .. info.Thai), bilingual("Cave puzzle", "ปริศนาถ้ำ"))
		self:_connectPrompt(runePrompt, "AdventurePuzzleRune", { rune = info.Id })
		table.insert(self._caveRunes, rune)
	end
end

-- Neutral server fallback. EnvironmentController replaces this on each client
-- with that computer's exact local hour, so players in different time zones can
-- see their own real-world daylight without fighting over replicated Lighting.
function WorldService:_applyLighting()
	Lighting.ClockTime = 12
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.15
	Lighting.Ambient = WildwoodStyle.Lighting.DayAmbient
	Lighting.OutdoorAmbient = WildwoodStyle.Lighting.DayOutdoor
	Lighting.ColorShift_Top = WildwoodStyle.Lighting.DayTop
	Lighting.ColorShift_Bottom = WildwoodStyle.Lighting.DayBottom
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.FogColor = WildwoodStyle.Lighting.DayFog
	Lighting.FogStart = 120
	Lighting.FogEnd = 620

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = WildwoodStyle.Lighting.DayFog
	atmosphere.Decay = VILLAGE.Cobble
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
end

--[[
	The cafe is still a normal enterable town building, so it keeps the same
	model name, waypoint and CafeSmart prompt used by the game systems. The
	fittings give it a Wildwood fantasy identity without blocking the clear
	centre aisle from the front door to the service counter.
]]
--[[ Builds one of Bakery Bay's overlapping dark-timber gables. ]]
function WorldService:_bakeryGableRoof(cafe, origin, roofWidth, roofDepth, eaveHeight, shadeOffset)
	local overhang = 1.5
	local halfWidth = roofWidth / 2 + overhang
	local rise = math.min(halfWidth * 0.57, 7.6)
	local slope = math.sqrt(halfWidth * halfWidth + rise * rise)
	local angle = math.atan2(rise, halfWidth)
	local fullDepth = roofDepth + overhang * 2

	for _, side in ipairs({ -1, 1 }) do
		local roof = clad(
			cafe,
			"RoofPlane",
			Vector3.new(slope, 0.9, fullDepth),
			origin * CFrame.new(side * halfWidth / 2, eaveHeight + rise / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			BAKERY_BAY.RoofTile,
			Enum.Material.Slate
		)
		for course = 1, 7 do
			local along = (course / 8 - 0.5) * slope
			clad(
				cafe,
				"BakeryRoofCourse",
				Vector3.new(0.55, 0.24, fullDepth + 0.12),
				roof.CFrame * CFrame.new(along, 0.55, 0),
				course % 2 == shadeOffset % 2 and BAKERY_BAY.RoofShadow or BAKERY_BAY.RoofHighlight,
				Enum.Material.Slate
			)
		end
		clad(cafe, "RoofFascia", Vector3.new(0.75, 1.25, fullDepth), origin * CFrame.new(side * halfWidth, eaveHeight - 0.25, 0), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	clad(cafe, "RoofRidge", Vector3.new(1.35, 1.2, fullDepth + 0.6), origin * CFrame.new(0, eaveHeight + rise + 0.25, 0), BAKERY_BAY.Brown, Enum.Material.Wood)

	for _, face in ipairs({ -1, 1 }) do
		for course = 0, 11 do
			local fraction = (course + 0.5) / 12
			local courseWidth = roofWidth * (1 - fraction)
			if courseWidth > 0.6 then
				clad(cafe, "GableCourse", Vector3.new(courseWidth, rise / 12 + 0.08, 0.7), origin * CFrame.new(0, eaveHeight + fraction * rise, face * roofDepth / 2), BAKERY_BAY.Mocha, Enum.Material.WoodPlanks)
			end
		end
		clad(cafe, "GablePost", Vector3.new(0.8, rise, 0.65), origin * CFrame.new(0, eaveHeight + rise / 2, face * (roofDepth / 2 + 0.15)), BAKERY_BAY.Brown, Enum.Material.Wood)
		for _, side in ipairs({ -1, 1 }) do
			clad(cafe, "GableBrace", Vector3.new(roofWidth * 0.34, 0.65, 0.6), origin * CFrame.new(side * roofWidth * 0.16, eaveHeight + rise * 0.42, face * (roofDepth / 2 + 0.2)) * CFrame.Angles(0, 0, -side * math.rad(29)), BAKERY_BAY.Hickory, Enum.Material.Wood)
		end
	end
end

--[[ Approved A exterior: asymmetrical gables, open bakery bay and display window. ]]
function WorldService:_buildBakeryBayExterior(cafe, cafeBase, spec)
	local width, depth, wallHeight = spec.Width, spec.Depth, spec.WallHeight
	local bakeryCream, bakeryTerracotta = spec.Cream, spec.Terracotta

	-- Stone plinth split around the central entrance.
	local frontLeftWidth = width / 2 + spec.DoorOffset - spec.DoorWidth / 2
	local frontRightWidth = width / 2 - spec.DoorOffset - spec.DoorWidth / 2
	part(cafe, "BakeryStoneFoundation", Vector3.new(width + 1.4, 3.1, 1.3), cafeBase * CFrame.new(0, 1.1, depth / 2 + 0.25), BAKERY_BAY.Stone, Enum.Material.Rock)
	for _, side in ipairs({ -1, 1 }) do
		part(cafe, "BakeryStoneFoundation", Vector3.new(1.3, 3.1, depth + 1.4), cafeBase * CFrame.new(side * (width / 2 + 0.25), 1.1, 0), BAKERY_BAY.Stone, Enum.Material.Rock)
	end
	part(cafe, "BakeryStoneFoundation", Vector3.new(frontLeftWidth, 3.1, 1.3), cafeBase * CFrame.new(-width / 2 + frontLeftWidth / 2, 1.1, -depth / 2 - 0.25), BAKERY_BAY.StoneLight, Enum.Material.Rock)
	part(cafe, "BakeryStoneFoundation", Vector3.new(frontRightWidth, 3.1, 1.3), cafeBase * CFrame.new(width / 2 - frontRightWidth / 2, 1.1, -depth / 2 - 0.25), BAKERY_BAY.StoneLight, Enum.Material.Rock)

	-- Exact five-brown timber skeleton, authored only for this cafe.
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			clad(cafe, "CornerPost", Vector3.new(1.3, wallHeight, 1.3), cafeBase * CFrame.new(x * width / 2, wallHeight / 2, z * depth / 2), BAKERY_BAY.Brown, Enum.Material.Wood)
		end
	end
	for _, y in ipairs({ 0.65, 7.8, 14.4 }) do
		for _, z in ipairs({ -1, 1 }) do
			-- The middle rail belongs only on the solid rear wall. It previously
			-- crossed both front shop windows at eye level.
			if y ~= 7.8 or z == 1 then
				clad(cafe, "WallRail", Vector3.new(width, 0.9, 0.75), cafeBase * CFrame.new(0, y, z * (depth / 2 + 0.35)), BAKERY_BAY.Hickory, Enum.Material.Wood)
			end
		end
		-- Side middle rails also sliced through the two service/display windows.
		if y ~= 7.8 then
			for _, x in ipairs({ -1, 1 }) do
				clad(cafe, "WallRail", Vector3.new(0.75, 0.9, depth), cafeBase * CFrame.new(x * (width / 2 + 0.35), y, 0), BAKERY_BAY.Hickory, Enum.Material.Wood)
			end
		end
	end
	for _, frameX in ipairs({ -17.8, -5.1, -2.3, 5.2, 18.2 }) do
		clad(cafe, "BakeryFacadePost", Vector3.new(0.8, 13.5, 0.95), cafeBase * CFrame.new(frameX, 7.3, -depth / 2 - 0.55), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	-- Braces stay on the solid rear elevation; the front pair used to cut
	-- diagonally across the open bakery and pastry windows.
	for _, face in ipairs({ 1 }) do
		for _, braceX in ipairs({ -13, 13 }) do
			clad(cafe, "WallBrace", Vector3.new(0.7, 8.4, 0.75), cafeBase * CFrame.new(braceX, 10.8, face * (depth / 2 + 0.55)) * CFrame.Angles(0, 0, math.rad(braceX < 0 and -39 or 39)), BAKERY_BAY.Brown, Enum.Material.Wood)
		end
	end

	-- Overlapping roof masses create the two-wing silhouette from concept A.
	self:_bakeryGableRoof(cafe, cafeBase * CFrame.new(-7, 0, 0), 26, 33, 15, 0)
	self:_bakeryGableRoof(cafe, cafeBase * CFrame.new(11, 0, 1.5), 18, 27, 14.2, 1)

	-- Warm dormers and roof cupola provide the upper-storey bakery identity.
	for _, dormerX in ipairs({ -8.5, 10.8 }) do
		clad(cafe, "BakeryDormerWall", Vector3.new(6.2, 4.6, 0.8), cafeBase * CFrame.new(dormerX, 17.2, -11.6), BAKERY_BAY.Mocha, Enum.Material.WoodPlanks)
		local dormerGlow = clad(cafe, "BakeryDormerWindow", Vector3.new(2.5, 2.9, 0.25), cafeBase * CFrame.new(dormerX, 17.15, -12.05), BAKERY_BAY.Window, Enum.Material.Neon)
		dormerGlow.Transparency = 0.12
		for _, side in ipairs({ -1, 1 }) do
			clad(cafe, "BakeryDormerRoof", Vector3.new(4.3, 0.55, 6.8), cafeBase * CFrame.new(dormerX + side * 1.8, 20.1, -11.1) * CFrame.Angles(0, 0, -side * math.rad(38)), BAKERY_BAY.RoofTile, Enum.Material.Slate)
		end
		clad(cafe, "BakeryFlowerBox", Vector3.new(4.6, 0.8, 1.3), cafeBase * CFrame.new(dormerX, 15.5, -12.65), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
		for flower = 1, 4 do
			local bloom = clad(cafe, "BakeryWindowFlower", Vector3.new(0.7, 0.7, 0.7), cafeBase * CFrame.new(dormerX - 1.5 + flower * 0.65, 16.15, -12.7), flower % 2 == 0 and BAKERY_BAY.Flower or bakeryTerracotta, Enum.Material.Grass)
			bloom.Shape = Enum.PartType.Ball
		end
	end
	for _, postX in ipairs({ -2, 2 }) do
		for _, postZ in ipairs({ -2, 2 }) do
			clad(cafe, "BakeryCupolaPost", Vector3.new(0.5, 3.6, 0.5), cafeBase * CFrame.new(-3 + postX, 23.2, 2 + postZ), BAKERY_BAY.Brown, Enum.Material.Wood)
		end
	end
	for _, faceZ in ipairs({ -1, 1 }) do
		local glow = clad(cafe, "BakeryCupolaGlow", Vector3.new(3.2, 2.4, 0.2), cafeBase * CFrame.new(-3, 23.2, 2 + faceZ * 2), BAKERY_BAY.Window, Enum.Material.Neon)
		glow.Transparency = 0.18
	end
	for _, side in ipairs({ -1, 1 }) do
		clad(cafe, "BakeryCupolaRoof", Vector3.new(4.6, 0.55, 6.1), cafeBase * CFrame.new(-3 + side * 1.9, 26.2, 2) * CFrame.Angles(0, 0, -side * math.rad(40)), BAKERY_BAY.RoofShadow, Enum.Material.Slate)
	end

	-- Left serving bay.
	local facadeZ = -depth / 2 - 0.72
	local serviceGlow = clad(cafe, "BakeryOpenServiceGlow", Vector3.new(10.4, 0.35, 0.35), cafeBase * CFrame.new(12, 10.15, -14.9), BAKERY_BAY.Window, Enum.Material.Neon)
	serviceGlow.Transparency = 0.18
	local serviceLight = Instance.new("PointLight")
	serviceLight.Color = VILLAGE.Lantern
	serviceLight.Brightness = 0.85
	serviceLight.Range = 13
	serviceLight.Parent = serviceGlow
	local serviceOpening = clad(cafe, "BakeryOpenServiceBay", Vector3.new(11.7, 6.7, 0.2), cafeBase * CFrame.new(12, 7, facadeZ - 0.22), BAKERY_BAY.Brown, Enum.Material.SmoothPlastic)
	serviceOpening.Transparency = 1
	serviceOpening.CastShadow = false
	local streetCounter = part(cafe, "BakeryStreetCounter", Vector3.new(13.2, 1.2, 3.1), cafeBase * CFrame.new(12, 3.45, -17.15), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
	streetCounter:SetAttribute("DecorativeOnly", true)
	for _, x in ipairs({ 5.5, 18.5 }) do
		clad(cafe, "BakeryServiceFrame", Vector3.new(0.85, 8.2, 1), cafeBase * CFrame.new(x, 7.1, facadeZ - 0.35), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	clad(cafe, "BakeryServiceFrame", Vector3.new(13.2, 0.8, 1), cafeBase * CFrame.new(12, 10.75, facadeZ - 0.35), BAKERY_BAY.Brown, Enum.Material.Wood)
	for _, shelfY in ipairs({ 5.2, 7.65 }) do
		clad(cafe, "BakeryServiceShelf", Vector3.new(9.8, 0.35, 1.25), cafeBase * CFrame.new(12, shelfY, -15.95), BAKERY_BAY.Peanut, Enum.Material.WoodPlanks)
	end
	-- The service window wraps around the screen-left corner while the wall
	-- remains solid above, below and behind the window opening.
	local sideOpening = clad(cafe, "BakeryOpenSideBay", Vector3.new(0.2, 5.5, 10.2), cafeBase * CFrame.new(width / 2 + 0.22, 6.85, -10), BAKERY_BAY.Brown, Enum.Material.SmoothPlastic)
	sideOpening.Transparency = 1
	sideOpening.CastShadow = false
	local sideCounter = part(cafe, "BakerySideCounter", Vector3.new(3.1, 1.2, 10.8), cafeBase * CFrame.new(width / 2 + 1.65, 3.45, -10), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
	sideCounter:SetAttribute("DecorativeOnly", true)
	for _, z in ipairs({ -15.05, -4.85 }) do
		clad(cafe, "BakeryServiceSideFrame", Vector3.new(0.9, 8.2, 0.9), cafeBase * CFrame.new(width / 2 + 0.42, 7.1, z), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	clad(cafe, "BakeryServiceSideFrame", Vector3.new(0.9, 0.8, 11.1), cafeBase * CFrame.new(width / 2 + 0.42, 10.05, -10), BAKERY_BAY.Brown, Enum.Material.Wood)
	clad(cafe, "BakerySideAwning", Vector3.new(5.2, 0.42, 11.4), cafeBase * CFrame.new(width / 2 + 2.25, 10.95, -10) * CFrame.Angles(0, 0, math.rad(13)), bakeryCream, Enum.Material.Fabric)

	-- Right full-height pastry display projects well beyond the main facade so
	-- it reads as its own glazed shop wing instead of a flat window overlay.
	local displayFrontZ = facadeZ - 4.05
	part(cafe, "BakeryDisplayWingFoundation", Vector3.new(14.7, 2.2, 7.3), cafeBase * CFrame.new(-11.5, 1.1, -18.45), BAKERY_BAY.StoneLight, Enum.Material.Rock)
	local displayFloor = part(cafe, "BakeryDisplayWingFloor", Vector3.new(13.8, 0.35, 6.5), cafeBase * CFrame.new(-11.5, 2.38, -18.35), BAKERY_BAY.Peanut, Enum.Material.WoodPlanks)
	displayFloor.CanCollide = false
	local displayGlow = clad(cafe, "BakeryDisplayGlow", Vector3.new(10.8, 0.25, 0.25), cafeBase * CFrame.new(-11.5, 10.55, displayFrontZ + 0.35), BAKERY_BAY.Window, Enum.Material.Neon)
	displayGlow.Transparency = 0.42
	local displayLight = Instance.new("PointLight")
	displayLight.Color = VILLAGE.Lantern
	displayLight.Brightness = 0.48
	displayLight.Range = 11
	displayLight.Parent = displayGlow
	local displayWindow = clad(cafe, "BakeryDisplayWindow", Vector3.new(12.4, 7.7, 0.18), cafeBase * CFrame.new(-11.5, 7.1, displayFrontZ), BAKERY_BAY.Glass, Enum.Material.Glass)
	displayWindow.Transparency = 0.72
	for _, x in ipairs({ -17.7, -13.55, -9.4, -5.25 }) do
		clad(cafe, "BakeryDisplayMullion", Vector3.new(0.48, 8.4, 0.72), cafeBase * CFrame.new(x, 7.15, displayFrontZ - 0.15), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	for _, y in ipairs({ 3.3, 6.3, 9.3, 11.2 }) do
		clad(cafe, "BakeryDisplayTransom", Vector3.new(13.6, 0.45, 0.72), cafeBase * CFrame.new(-11.5, y, displayFrontZ - 0.15), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	for _, sideX in ipairs({ -17.72, -5.28 }) do
		local sideGlass = clad(cafe, "BakeryDisplaySideGlass", Vector3.new(0.18, 7.7, 5.65), cafeBase * CFrame.new(sideX, 7.1, -18.05), BAKERY_BAY.Glass, Enum.Material.Glass)
		sideGlass.Transparency = 0.72
		for _, z in ipairs({ -20.65, -18.05, -15.45 }) do
			clad(cafe, "BakeryDisplaySideFrame", Vector3.new(0.72, 8.4, 0.48), cafeBase * CFrame.new(sideX, 7.15, z), BAKERY_BAY.Brown, Enum.Material.Wood)
		end
	end
	for _, shelfY in ipairs({ 4.25, 6.9 }) do
		clad(cafe, "BakeryWindowShelf", Vector3.new(11.2, 0.35, 2.2), cafeBase * CFrame.new(-11.5, shelfY, displayFrontZ + 0.95), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
	end
	for index, itemId in ipairs({ "MoonBerryTart", "StarCupcake", "MoonberryCake" }) do
		local displayModel = CafeModels.build(cafe, itemId, cafeBase * CFrame.new(-14.7 + (index - 1) * 3.2, 4.62, displayFrontZ + 0.78), 0.7)
		displayModel.Name = "BakeryWindow" .. itemId
		displayModel:SetAttribute("ExteriorDisplay", true)
	end

	-- The centre entrance is a permanently open arch. Bakery Bay's reference has
	-- an inviting walk-in opening, so no decorative door or glass door panel is
	-- placed across the doorway volume.
	-- Their top faces descend from the one-stud doorstep to the grass, with the
	-- lowest step resting directly on the ground instead of floating above it.
	for segment = -2, 2 do
		clad(cafe, "BakeryDoorArch", Vector3.new(0.65, 2, 0.85), cafeBase * CFrame.new(spec.DoorOffset + segment * 1.05, 9.35 - math.abs(segment) * 0.42, -depth / 2 - 0.9) * CFrame.Angles(0, 0, math.rad(-segment * 14)), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	for stepIndex = 1, 3 do
		local step = part(cafe, "BakeryDoorStep", Vector3.new(8 - stepIndex * 0.6, 0.5, 1.7), cafeBase * CFrame.new(spec.DoorOffset, -0.25 - (stepIndex - 1) * 0.25, -depth / 2 - 1.3 - stepIndex * 0.75), stepIndex % 2 == 0 and BAKERY_BAY.StoneLight or BAKERY_BAY.Stone, Enum.Material.Rock)
		step.CanCollide = false
	end

	-- Canvas awning over the open counter, tiled canopy over the display.
	for index, x in ipairs({ 5.5, 8, 10.5, 13, 15.5, 18 }) do
		local awning = clad(cafe, "BakeryCanvasAwning", Vector3.new(2.55, 0.42, 5.2), cafeBase * CFrame.new(x, 11.7, -18.1) * CFrame.Angles(math.rad(-13), 0, 0), index % 2 == 0 and bakeryCream or bakeryTerracotta, Enum.Material.Fabric)
		awning.Transparency = 0.02
		clad(cafe, "BakeryCanvasValance", Vector3.new(2.55, 0.85, 0.22), cafeBase * CFrame.new(x, 11.05, -20.55), index % 2 == 0 and bakeryCream or bakeryTerracotta, Enum.Material.Fabric)
	end
	clad(cafe, "BakeryDisplayCanopy", Vector3.new(15, 0.65, 7.4), cafeBase * CFrame.new(-11.5, 11.85, -18.45) * CFrame.Angles(math.rad(-11), 0, 0), BAKERY_BAY.RoofTile, Enum.Material.Slate)

	-- Keep the shop name compact and mounted over the screen-left striped
	-- awning. Pulling it in front of the roof overhang keeps every letter clear.
	local cafeSign = clad(cafe, "BakeryBaySign", Vector3.new(11.8, 2.6, 0.55), cafeBase * CFrame.new(12.2, 13.75, -20.85), BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
	carvedSignFace(cafeSign, "MOONLEAF CAFE", bakeryCream)
	clad(cafe, "BakerySignCrest", Vector3.new(2.8, 0.9, 0.6), cafeBase * CFrame.new(12.2, 15.35, -20.75), BAKERY_BAY.Coffee, Enum.Material.Wood)
	clad(cafe, "BakeryBladeBracket", Vector3.new(4.2, 0.35, 0.35), cafeBase * CFrame.new(21.2, 12.8, -17.2), BAKERY_BAY.Brown, Enum.Material.Metal)
	local moonSign = clad(cafe, "BakeryMoonBreadSign", Vector3.new(0.62, 5.1, 5.1), cafeBase * CFrame.new(22.7, 10.75, -17.2) * CFrame.Angles(0, math.rad(90), 0), BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
	moonSign.Shape = Enum.PartType.Cylinder
	local crescentOuter = clad(cafe, "BakeryCrescentOuter", Vector3.new(0.25, 2.75, 2.75), cafeBase * CFrame.new(22.7, 11.35, -17.58) * CFrame.Angles(0, math.rad(90), 0), bakeryCream, Enum.Material.SmoothPlastic)
	crescentOuter.Shape = Enum.PartType.Cylinder
	local crescentCutout = clad(cafe, "BakeryCrescentCutout", Vector3.new(0.27, 2.25, 2.25), cafeBase * CFrame.new(22.7, 11.62, -17.75) * CFrame.Angles(0, math.rad(90), 0), BAKERY_BAY.Hickory, Enum.Material.SmoothPlastic)
	crescentCutout.Shape = Enum.PartType.Cylinder
	local loaf = clad(cafe, "BakeryBreadLoaf", Vector3.new(2.55, 1.15, 0.28), cafeBase * CFrame.new(22.7, 9.55, -17.58), bakeryCream, Enum.Material.SmoothPlastic)
	for score = -1, 1 do
		clad(cafe, "BakeryBreadScore", Vector3.new(0.18, 0.72, 0.12), loaf.CFrame * CFrame.new(score * 0.55, 0.08, -0.19) * CFrame.Angles(0, 0, math.rad(-22)), BAKERY_BAY.Terracotta, Enum.Material.SmoothPlastic)
	end
	for _, lanternX in ipairs({ -18.5, -3.8, 5.3, 19 }) do
		self:_hangingLantern(cafe, cafeBase * CFrame.new(lanternX, 8.4, -17.35), 18)
	end
	-- Reference-A sidewalk menu: a true top-hinged A-frame. Both boards pivot
	-- from the same crossbar, their timber legs follow the splay, and four feet
	-- rest on the grass. The street board now leans down from the hinge instead
	-- of rotating around its centre and appearing to turn upward.
	local signYaw = cafeBase * CFrame.new(17.8, 5.2, -22.5) * CFrame.Angles(0, math.rad(188), 0)
	local signHeight = 5.4
	local signPitch = math.rad(12)
	local menuFace = signYaw * CFrame.Angles(-signPitch, 0, 0) * CFrame.new(0, -signHeight / 2, 0)
	local menuBack = signYaw * CFrame.Angles(signPitch, 0, 0) * CFrame.new(0, -signHeight / 2, 0)
	local sidewalkMenu = clad(cafe, "BakerySidewalkMenu", Vector3.new(4.9, signHeight, 0.5), menuFace, BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
	local sidewalkBack = clad(cafe, "BakerySidewalkMenuBack", Vector3.new(4.9, signHeight, 0.5), menuBack, BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
	for _, board in ipairs({ sidewalkMenu, sidewalkBack }) do
		for _, x in ipairs({ -2.25, 2.25 }) do
			clad(cafe, "BakerySidewalkSignLeg", Vector3.new(0.44, 6.45, 0.44), board.CFrame * CFrame.new(x, -0.05, 0), BAKERY_BAY.Coffee, Enum.Material.Wood)
		end
		for _, y in ipairs({ -1, 1 }) do
			clad(cafe, "BakerySidewalkSignRail", Vector3.new(4.75, 0.28, 0.24), board.CFrame * CFrame.new(0, y * 2.45, 0.3), BAKERY_BAY.Brown, Enum.Material.Wood)
		end
	end
	local hinge = clad(cafe, "BakerySidewalkHinge", Vector3.new(5.55, 0.38, 0.38), signYaw, BAKERY_BAY.Brown, Enum.Material.Metal)
	hinge.Shape = Enum.PartType.Cylinder
	for _, x in ipairs({ -2.85, 2.85 }) do
		local cap = clad(cafe, "BakerySidewalkHingeCap", Vector3.new(0.28, 0.58, 0.58), signYaw * CFrame.new(x, 0, 0), BAKERY_BAY.Peanut, Enum.Material.Metal)
		cap.Shape = Enum.PartType.Cylinder
	end
	local signBase = cafeBase * CFrame.new(17.8, 0, -22.5) * CFrame.Angles(0, math.rad(188), 0)
	for _, x in ipairs({ -2.25, 2.25 }) do
		for _, z in ipairs({ -1.15, 1.15 }) do
			clad(cafe, "BakerySidewalkSignFoot", Vector3.new(0.68, 0.4, 1.05), signBase * CFrame.new(x, -0.8, z), BAKERY_BAY.Coffee, Enum.Material.Wood)
		end
		clad(cafe, "BakerySidewalkChain", Vector3.new(0.12, 0.12, 2.35), signBase * CFrame.new(x, 0.15, 0), BAKERY_BAY.Slate, Enum.Material.Metal)
	end

	-- The street face carries only the raised, tapered coffee-cup emblem. The
	-- lettering was removed from both boards so it cannot show behind the cup.
	local iconDepth = 0.38
	clad(cafe, "BakeryCoffeeCupRim", Vector3.new(2.25, 0.2, 0.22), menuFace * CFrame.new(-0.15, -0.38, iconDepth), bakeryCream, Enum.Material.SmoothPlastic)
	clad(cafe, "BakeryCoffeeCupCoffee", Vector3.new(1.82, 0.1, 0.25), menuFace * CFrame.new(-0.15, -0.31, iconDepth + 0.02), BAKERY_BAY.Coffee, Enum.Material.SmoothPlastic)
	clad(cafe, "BakeryCoffeeCup", Vector3.new(1.95, 0.38, 0.22), menuFace * CFrame.new(-0.15, -0.65, iconDepth), bakeryCream, Enum.Material.SmoothPlastic)
	clad(cafe, "BakeryCoffeeCupBody", Vector3.new(1.68, 0.38, 0.22), menuFace * CFrame.new(-0.15, -1.0, iconDepth), bakeryCream, Enum.Material.SmoothPlastic)
	clad(cafe, "BakeryCoffeeCupBody", Vector3.new(1.4, 0.34, 0.22), menuFace * CFrame.new(-0.15, -1.34, iconDepth), bakeryCream, Enum.Material.SmoothPlastic)
	clad(cafe, "BakeryCoffeeCupBase", Vector3.new(2.65, 0.2, 0.24), menuFace * CFrame.new(-0.05, -1.65, iconDepth), bakeryCream, Enum.Material.SmoothPlastic)
	for _, handlePiece in ipairs({
		{ Vector3.new(0.62, 0.18, 0.22), Vector3.new(1.08, -0.68, iconDepth) },
		{ Vector3.new(0.18, 0.62, 0.22), Vector3.new(1.34, -0.96, iconDepth) },
		{ Vector3.new(0.62, 0.18, 0.22), Vector3.new(1.08, -1.25, iconDepth) },
	}) do
		clad(cafe, "BakeryCoffeeCupHandle", handlePiece[1], menuFace * CFrame.new(handlePiece[2]), bakeryCream, Enum.Material.SmoothPlastic)
	end
	for wispIndex, steamX in ipairs({ -0.62, 0.36 }) do
		for segment = 1, 3 do
			local bend = (segment + wispIndex) % 2 == 0 and -18 or 18
			clad(cafe, "BakeryCoffeeSteam", Vector3.new(0.18, 0.52, 0.2), menuFace * CFrame.new(steamX + (segment - 2) * 0.1, -0.05 + segment * 0.42, iconDepth + 0.02) * CFrame.Angles(0, 0, math.rad(bend)), bakeryCream, Enum.Material.Neon)
		end
	end

	-- Small hand grinder on the open counter.
	local grinderFrame = cafeBase * CFrame.new(15.2, 4.75, -17.55)
	clad(cafe, "HandCoffeeGrinderBody", Vector3.new(1.65, 1.5, 1.35), grinderFrame, BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
	local hopper = clad(cafe, "HandCoffeeGrinderHopper", Vector3.new(1.25, 1.05, 1.25), grinderFrame * CFrame.new(0, 1.18, 0), BAKERY_BAY.Slate, Enum.Material.Metal)
	hopper.Shape = Enum.PartType.Cylinder
	clad(cafe, "HandCoffeeGrinderDrawer", Vector3.new(1.05, 0.55, 0.18), grinderFrame * CFrame.new(0, -0.2, -0.77), BAKERY_BAY.Peanut, Enum.Material.Wood)
	clad(cafe, "HandCoffeeGrinderCrank", Vector3.new(2.15, 0.16, 0.16), grinderFrame * CFrame.new(0.75, 1.82, 0) * CFrame.Angles(0, 0, math.rad(18)), BAKERY_BAY.Slate, Enum.Material.Metal)
	local crankKnob = clad(cafe, "HandCoffeeGrinderKnob", Vector3.new(0.48, 0.48, 0.48), grinderFrame * CFrame.new(1.72, 2.12, 0), BAKERY_BAY.Coffee, Enum.Material.Wood)
	crankKnob.Shape = Enum.PartType.Ball

	-- Oak-barrel planters soften both front corners.
	for planterIndex, planterAt in ipairs({ Vector3.new(-20.2, 1.8, -21.4), Vector3.new(22.7, 1.8, -20.6) }) do
		local planterFrame = cafeBase * CFrame.new(planterAt) * CFrame.Angles(0, 0, math.rad(90))
		local barrel = clad(cafe, "BakeryOakBarrelPlanter", Vector3.new(3.5, 3.25, 3.25), planterFrame, BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
		barrel.Shape = Enum.PartType.Cylinder
		for hoopX = -1, 1, 2 do
			local hoop = clad(cafe, "BakeryBarrelHoop", Vector3.new(0.28, 3.42, 3.42), planterFrame * CFrame.new(hoopX * 1.12, 0, 0), BAKERY_BAY.Slate, Enum.Material.Metal)
			hoop.Shape = Enum.PartType.Cylinder
		end
		for flowerIndex = 1, 7 do
			local angle = flowerIndex * 2.4 + planterIndex
			local radius = 0.45 + (flowerIndex % 3) * 0.38
			local flowerBase = cafeBase * CFrame.new(planterAt + Vector3.new(math.cos(angle) * radius, 2 + (flowerIndex % 2) * 0.45, math.sin(angle) * radius))
			clad(cafe, "BakeryBarrelLeaf", Vector3.new(0.55, 1.7, 0.3), flowerBase * CFrame.Angles(math.rad(18), angle, math.rad(28)), BAKERY_BAY.FlowerLeaf, Enum.Material.Grass)
			local bloom = clad(cafe, "BakeryBarrelFlower", Vector3.new(0.7, 0.7, 0.7), flowerBase * CFrame.new(0, 0.9, 0), flowerIndex % 2 == 0 and BAKERY_BAY.Flower or BAKERY_BAY.Terracotta, Enum.Material.Grass)
			bloom.Shape = Enum.PartType.Ball
		end
	end
end

--[[ Warm bakery interior from A, preserving only the menu/food gameplay assets. ]]
function WorldService:_buildBakeryBayInterior(cafe, cafeBase, spec)
	-- Exposed beams and pendant lights replace the old floating fantasy orbs.
	for _, z in ipairs({ -10, -3.5, 3.5, 10 }) do
		clad(cafe, "BakeryCeilingBeam", Vector3.new(spec.Width - 2, 0.8, 0.8), cafeBase * CFrame.new(0, 14.1, z), BAKERY_BAY.Brown, Enum.Material.Wood)
	end
	for _, x in ipairs({ -15, -7.5, 0, 7.5, 15 }) do
		clad(cafe, "BakeryCeilingSlat", Vector3.new(0.7, 0.45, spec.Depth - 2), cafeBase * CFrame.new(x, 14.45, 0), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
	end
	for _, lampAt in ipairs({ Vector3.new(-15, 11.5, 3), Vector3.new(-9, 11.5, 3), Vector3.new(-3, 11.5, 3), Vector3.new(9, 11.5, -1), Vector3.new(15, 11.5, -1) }) do
		local pendant = clad(cafe, "BakeryPendantGlow", Vector3.new(1.35, 1.35, 1.35), cafeBase * CFrame.new(lampAt), BAKERY_BAY.Window, Enum.Material.Neon)
		pendant.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = VILLAGE.Lantern
		light.Brightness = 1.25
		light.Range = 21
		light.Parent = pendant
		clad(cafe, "BakeryPendantCord", Vector3.new(0.18, 2.5, 0.18), pendant.CFrame * CFrame.new(0, 1.85, 0), BAKERY_BAY.Brown, Enum.Material.Metal)
	end

	-- Authoritative back bar and CafeSmart interaction.
	local counter = part(cafe, "ServiceCounter", Vector3.new(23, 4.2, 4.4), cafeBase * CFrame.new(-3.5, 2.1, 10.2), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
	local cafePrompt = prompt(counter, bilingual("Open / serve", "เปิด / เสิร์ฟ"), bilingual("Moonleaf Cafe", "คาเฟ่ใบจันทร์"))
	self:_connectPrompt(cafePrompt, "CafeSmart", {})
	for index, x in ipairs({ -13, -8.5, -4, 0.5, 5 }) do
		clad(cafe, "BakeryCounterFront", Vector3.new(3.6, 3.1, 0.42), cafeBase * CFrame.new(x, 2.2, 7.82), index % 2 == 0 and BAKERY_BAY.Mocha or BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
		clad(cafe, "BakeryCounterTrim", Vector3.new(3.8, 0.3, 0.5), cafeBase * CFrame.new(x, 3.55, 7.58), BAKERY_BAY.Peanut, Enum.Material.Wood)
	end

	-- Preserve every detailed menu model and its exact item ID.
	local displayCase = clad(cafe, "PastryDisplayGlass", Vector3.new(10.5, 2.7, 2.6), cafeBase * CFrame.new(-8, 5.35, 9.35), VILLAGE.Glass, Enum.Material.Glass)
	displayCase.Transparency = 0.42
	local foodDisplay = Instance.new("Folder")
	foodDisplay.Name = "CafeFood3DDisplay"
	foodDisplay.Parent = cafe
	for index, itemId in ipairs(CafeMenu.Order) do
		local item = CafeMenu.Items[itemId]
		local x = -11.5 + (index - 1) * 2.35
		CafeModels.build(foodDisplay, itemId, cafeBase * CFrame.new(x, 4.2, 9.25), 0.88)
		local nameplate = clad(cafe, "CafeItemNameplate", Vector3.new(2.05, 0.58, 0.1), cafeBase * CFrame.new(x, 4.42, 7.9), spec.Cream, Enum.Material.SmoothPlastic)
		nameplate:SetAttribute("CafeItemId", itemId)
		local surface = Instance.new("SurfaceGui")
		surface.Name = "CafeItemName"
		surface.Face = Enum.NormalId.Front
		surface.CanvasSize = Vector2.new(340, 104)
		surface.LightInfluence = 0
		surface.Parent = nameplate
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Size = UDim2.fromScale(1, 1)
		nameLabel.Text = item.Name
		nameLabel.TextColor3 = BAKERY_BAY.Brown
		nameLabel.TextScaled = true
		nameLabel.TextWrapped = true
		nameLabel.Parent = surface
	end

	-- Menu, ingredient shelves and visible bakery storage fill the back wall.
	local menuBoard = clad(cafe, "BakeryInteriorMenu", Vector3.new(13.5, 6, 0.48), cafeBase * CFrame.new(8.5, 8.9, 15.05), spec.Slate, Enum.Material.Slate)
	carvedSignFace(menuBoard, "MOONLEAF MENU\nTART  CAKE  CUPCAKE  TEA", spec.Cream)
	for _, shelfY in ipairs({ 4.8, 7.8, 10.8 }) do
		clad(cafe, "BakeryBackShelf", Vector3.new(13, 0.5, 1.5), cafeBase * CFrame.new(-11, shelfY, 14.3), BAKERY_BAY.Peanut, Enum.Material.WoodPlanks)
		for jarIndex = 1, 5 do
			local jar = clad(cafe, "BakeryIngredientJar", Vector3.new(1.15, 1.5, 1.15), cafeBase * CFrame.new(-16.5 + jarIndex * 2.1, shelfY + 1, 14), jarIndex % 2 == 0 and spec.Cream or spec.Terracotta, Enum.Material.Glass)
			jar.Shape = Enum.PartType.Cylinder
			jar.Transparency = 0.18
		end
	end

	-- Three compact dining groups leave a broad route from the door to the bar.
	for _, tableAt in ipairs({ Vector3.new(-12.5, 0, -5), Vector3.new(11.5, 0, -4.5), Vector3.new(11.5, 0, 3.5) }) do
		part(cafe, "BakeryDiningTable", Vector3.new(5.2, 0.65, 4.4), cafeBase * CFrame.new(tableAt + Vector3.new(0, 3.1, 0)), BAKERY_BAY.Peanut, Enum.Material.WoodPlanks)
		part(cafe, "BakeryDiningTableLeg", Vector3.new(1.1, 2.8, 1.1), cafeBase * CFrame.new(tableAt + Vector3.new(0, 1.45, 0)), BAKERY_BAY.Brown, Enum.Material.Wood)
		for _, chairZ in ipairs({ -1, 1 }) do
			part(cafe, "BakeryChairSeat", Vector3.new(2.2, 0.55, 2.2), cafeBase * CFrame.new(tableAt + Vector3.new(0, 1.7, chairZ * 3.3)), BAKERY_BAY.Coffee, Enum.Material.WoodPlanks)
			part(cafe, "BakeryChairBack", Vector3.new(2.2, 3, 0.5), cafeBase * CFrame.new(tableAt + Vector3.new(0, 3, chairZ * 4.15)), BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		part(cafe, "BakeryWallBench", Vector3.new(7.5, 1.1, 2.4), cafeBase * CFrame.new(side * 15.4, 1.8, 5), spec.Terracotta, Enum.Material.Fabric)
		part(cafe, "BakeryWallBenchBack", Vector3.new(7.5, 3.3, 0.7), cafeBase * CFrame.new(side * 15.4, 3.8, 6.15), BAKERY_BAY.Hickory, Enum.Material.WoodPlanks)
	end
end

--[[ Full replacement of the old cafe, while keeping gameplay contracts. ]]
function WorldService:_buildFantasyCafe()
	local cafe = Instance.new("Model")
	cafe.Name = "FamilyCafe"
	cafe.Parent = self._townFolder
	cafe:SetAttribute("Theme", "Bakery Bay")
	cafe:SetAttribute("CafeName", "Moonleaf Cafe")
	cafe:SetAttribute("ExteriorStyle", "Bakery Bay")
	cafe:SetAttribute("InteriorStyle", "Bakery Bay")
	cafe:SetAttribute("StructureVersion", "Bakery Bay Full Rebuild")

	local spec = {
		Width = 40,
		Depth = 31,
		WallHeight = 15,
		DoorWidth = 6.5,
		DoorOffset = 1.5,
		DoorHeight = 9.5,
		Cream = BAKERY_BAY.Cream,
		Terracotta = BAKERY_BAY.Terracotta,
		Slate = BAKERY_BAY.Slate,
	}
	local position = Config.Waypoints.Cafe - Vector3.new(0, 4, 0)
	local floorTop = 1
	local doorstep = position + Vector3.new(0, floorTop, 0)
	local cafeBase = CFrame.lookAt(doorstep, Vector3.new(0, floorTop, 0))

	part(cafe, "BakeryFoundationSlab", Vector3.new(spec.Width + 6, floorTop, spec.Depth + 6), cafeBase * CFrame.new(0, -floorTop / 2, 0), BAKERY_BAY.Stone, Enum.Material.Cobblestone)
	local interiorFloor = part(cafe, "BakeryInteriorFloor", Vector3.new(spec.Width - 1, 0.35, spec.Depth - 1), cafeBase * CFrame.new(0, 0.18, 0), BAKERY_BAY.Peanut, Enum.Material.WoodPlanks)
	interiorFloor.CanCollide = false
	self:_shell(cafe, cafeBase, {
		Width = spec.Width,
		Depth = spec.Depth,
		Height = spec.WallHeight,
		Thickness = WALL_THICKNESS,
		DoorWidth = spec.DoorWidth,
		DoorOffset = spec.DoorOffset,
		DoorHeight = spec.DoorHeight,
		InteriorOffset = 2,
		Color = BAKERY_BAY.Mocha,
		Material = Enum.Material.WoodPlanks,
		Ceiling = false,
	})

	-- Replace _shell's two solid front panels with a real shopfront wall cut
	-- around the open service bay, narrow door and glazed pastry display. This is
	-- structural, not an overlay: players and cameras can genuinely see inside.
	for _, oldFront in ipairs({ "FrontLeft", "FrontRight", "DoorHeader", "RightWall" }) do
		local panel = cafe:FindFirstChild(oldFront)
		if panel then
			panel:Destroy()
		end
	end
	local frontZ = -spec.Depth / 2 + WALL_THICKNESS / 2
	local function facadeWall(size, offset)
		return part(cafe, "BakeryFacadeWall", size, cafeBase * CFrame.new(offset), BAKERY_BAY.Mocha, Enum.Material.WoodPlanks)
	end
	-- Full-height wall strips separating the three facade openings.
	facadeWall(Vector3.new(1.9, spec.WallHeight, WALL_THICKNESS), Vector3.new(-19.05, spec.WallHeight / 2, frontZ))
	facadeWall(Vector3.new(3.7, spec.WallHeight, WALL_THICKNESS), Vector3.new(-3.55, spec.WallHeight / 2, frontZ))
	facadeWall(Vector3.new(1.05, spec.WallHeight, WALL_THICKNESS), Vector3.new(5.28, spec.WallHeight / 2, frontZ))
	facadeWall(Vector3.new(1.8, spec.WallHeight, WALL_THICKNESS), Vector3.new(19.1, spec.WallHeight / 2, frontZ))
	-- Sills and headers define the left open bay and right display window.
	facadeWall(Vector3.new(12.2, 3.35, WALL_THICKNESS), Vector3.new(-11.5, 1.675, frontZ))
	facadeWall(Vector3.new(12.2, 4.2, WALL_THICKNESS), Vector3.new(-11.5, 12.9, frontZ))
	facadeWall(Vector3.new(12.4, 3.25, WALL_THICKNESS), Vector3.new(12, 1.625, frontZ))
	facadeWall(Vector3.new(12.4, 4.05, WALL_THICKNESS), Vector3.new(12, 12.975, frontZ))
	facadeWall(Vector3.new(spec.DoorWidth, spec.WallHeight - spec.DoorHeight, WALL_THICKNESS), Vector3.new(spec.DoorOffset, spec.DoorHeight + (spec.WallHeight - spec.DoorHeight) / 2, frontZ))
	-- Rebuild the screen-left side around a second serving opening. Local +X is
	-- screen-left for this cafe orientation, so only the rear portion stays solid.
	local sideX = spec.Width / 2 - WALL_THICKNESS / 2
	-- Solid side wall now continues all the way to the service window edge. The
	-- previous 10-stud gap between these pieces opened the entire wall.
	part(cafe, "BakeryServiceSideWall", Vector3.new(WALL_THICKNESS, spec.WallHeight, 20.4), cafeBase * CFrame.new(sideX, spec.WallHeight / 2, 5.3), BAKERY_BAY.Mocha, Enum.Material.WoodPlanks)
	part(cafe, "BakeryServiceSideWall", Vector3.new(WALL_THICKNESS, 4.1, 10.6), cafeBase * CFrame.new(sideX, 2.05, -10.2), BAKERY_BAY.Mocha, Enum.Material.WoodPlanks)
	part(cafe, "BakeryServiceSideWall", Vector3.new(WALL_THICKNESS, 5.3, 10.6), cafeBase * CFrame.new(sideX, 12.35, -10.2), BAKERY_BAY.Mocha, Enum.Material.WoodPlanks)
	self._cafeBase = cafeBase
	self:_addBlip("Building", "Family Cafe", "คาเฟ่ครอบครัว", position, spec.Width + 6, spec.Depth + 6, spec.Cream)
	self:_buildBakeryBayExterior(cafe, cafeBase, spec)
	self:_buildBakeryBayInterior(cafe, cafeBase, spec)
	return cafe, cafeBase
end

function WorldService:_buildWorld()
	local existing = workspace:FindFirstChild("CuteFamilyTown")
	if existing then
		existing:Destroy()
	end

	self:_applyLighting()

	local world = Instance.new("Folder")
	world.Name = "CuteFamilyTown"
	world.Parent = workspace
	self._world = world

	self._townFolder = Instance.new("Folder")
	self._townFolder.Name = "Town"
	self._townFolder.Parent = world
	self._decorFolder = Instance.new("Folder")
	self._decorFolder.Name = "Decor"
	self._decorFolder.Parent = world
	self._homesFolder = Instance.new("Folder")
	self._homesFolder.Name = "PlayerHomes"
	self._homesFolder.Parent = world
	self._petsFolder = Instance.new("Folder")
	self._petsFolder.Name = "Pets"
	self._petsFolder.Parent = world

	part(world, "Ground", Vector3.new(600, 2, 600), CFrame.new(0, -1, 0), COLORS.Grass, Enum.Material.Grass)
	-- The old ruler-straight cross has become a soft village loop. Short angled
	-- stretches preserve a handmade woodland silhouette and connect each district
	-- without forcing every view through one giant intersection.
	local villageLoop = {
		Vector3.new(-42, 0, -91),
		Vector3.new(0, 0, -112),
		Vector3.new(44, 0, -92),
		Vector3.new(92, 0, -48),
		Vector3.new(110, 0, 8),
		Vector3.new(92, 0, 68),
		Vector3.new(48, 0, 103),
		Vector3.new(0, 0, 114),
		Vector3.new(-48, 0, 103),
		Vector3.new(-92, 0, 68),
		Vector3.new(-110, 0, 8),
		Vector3.new(-92, 0, -49),
	}
	self:_pathChain(world, "VillageLoopPath", villageLoop, 20, true)

	-- District spurs: Market Lane, Family Lane, School Walk, Lake Walk and the
	-- two Home Groves. Each joins the loop instead of cutting across the square.
	self:_pathChain(world, "MarketLane", {
		Vector3.new(-91, 0, -48), Vector3.new(-118, 0, -70), Vector3.new(-141, 0, -84),
	}, 16, false)
	self:_pathChain(world, "FamilyLane", {
		Vector3.new(91, 0, -48), Vector3.new(118, 0, -70), Vector3.new(141, 0, -84),
	}, 16, false)
	self:_pathChain(world, "SchoolWalk", {
		Vector3.new(0, 0, -36), Vector3.new(0, 0, -82), Vector3.new(0, 0, -126),
	}, 16, false)
	self:_pathChain(world, "LakeWalk", {
		Vector3.new(0, 0, 36), Vector3.new(0, 0, 92), Vector3.new(0, 0, 151),
	}, 16, false)
	self:_pathChain(world, "WestHomeGrove", {
		Vector3.new(-104, 0, -62), Vector3.new(-140, 0, -86), Vector3.new(-146, 0, -42),
		Vector3.new(-146, 0, 10), Vector3.new(-143, 0, 62), Vector3.new(-111, 0, 92),
	}, 14, false)
	self:_pathChain(world, "EastHomeGrove", {
		Vector3.new(104, 0, -62), Vector3.new(140, 0, -86), Vector3.new(146, 0, -42),
		Vector3.new(146, 0, 10), Vector3.new(143, 0, 62), Vector3.new(111, 0, 92),
	}, 14, false)
	self:_pathChain(world, "ForestGatePath", {
		Vector3.new(-105, 0, 40), Vector3.new(-166, 0, 43), Vector3.new(-215, 0, 45),
	}, 14, false)
	self:_pathChain(world, "BeachPath", {
		Vector3.new(108, 0, 38), Vector3.new(160, 0, 32), Vector3.new(211, 0, 24),
	}, 14, false)

	-- Mossy rounded stones break up the clean edges at the loop's bends.
	for index, bend in ipairs(villageLoop) do
		for stoneIndex = 1, 3 do
			local angle = index * 0.83 + stoneIndex * 2.1
			local radius = 7 + stoneIndex * 2.4
			self:_mossyCobble(
				bend + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
				index * 3 + stoneIndex
			)
		end
	end
	for index, junction in ipairs({
		Vector3.new(-104, 0, -62), Vector3.new(104, 0, -62),
		Vector3.new(0, 0, -82), Vector3.new(0, 0, 92),
		Vector3.new(-105, 0, 40), Vector3.new(108, 0, 38),
	}) do
		self:_mossyCobble(junction + Vector3.new(index % 2 == 0 and 8 or -8, 0, 5), 36 + index)
	end

	local square = part(world, "TownPlaza", Vector3.new(72, 1, 72), CFrame.new(0, 0.45, 0), VILLAGE.Cobble, Enum.Material.Cobblestone)
	square:SetAttribute("DistrictName", "Guild Square")
	square:SetAttribute("LayoutStyle", "OrganicVillageLoop")
	local fountainBase = part(world, "Fountain", Vector3.new(22, 3, 22), CFrame.new(0, 1.5, 0), VILLAGE.Stone, Enum.Material.Rock, Enum.PartType.Cylinder)
	fountainBase.CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	local fountainTop = part(world, "FountainTop", Vector3.new(5, 8, 5), CFrame.new(0, 5, 0), VILLAGE.StoneLight, Enum.Material.Rock, Enum.PartType.Cylinder)
	fountainTop.CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90))
	billboard(fountainTop, "WILDWOOD GUILD SQUARE", VILLAGE.TimberDark, UDim2.fromOffset(280, 56))
	-- Lantern posts around the fountain: the plaza in the reference is ringed with them.
	local plazaLightPoints = {}
	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		local postPosition = Vector3.new(math.cos(angle) * 20, 6, math.sin(angle) * 20)
		local at = CFrame.new(postPosition + Vector3.new(0, 0.5, 0))
		part(world, "PlazaPost", Vector3.new(0.8, 12, 0.8), CFrame.new(math.cos(angle) * 20, 6, math.sin(angle) * 20), VILLAGE.TimberDark, Enum.Material.Wood)
		self:_hangingLantern(world, at * CFrame.new(0, 4, 0), 26)
		table.insert(plazaLightPoints, postPosition + Vector3.new(0, 6, 0))
	end
	for index = 1, #plazaLightPoints do
		self:_stringLightSpan(world, plazaLightPoints[index], plazaLightPoints[index % #plazaLightPoints + 1], index)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 1, 28)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	-- Every counter, bowl and crate now lives inside its shop, so the shops are
	-- places you walk into rather than facades you stand in front of. Fittings
	-- are placed in the building's own frame because the buildings are rotated
	-- to face the plaza: -Z is the door, +Z is the back of the room.
	-- Each shop keeps its identity through a banner colour and a plaster tint
	-- rather than a saturated wall, so the row still reads as one village.
	self:_buildFantasyCafe()

	local petShop, petShopBase = self:_building("Pet Shop", Config.Waypoints.PetShop - Vector3.new(0, 4, 0), COLORS.Mint, 32, 26, {
		Banner = VILLAGE.Water,
		RoofColor = VILLAGE.RoofShade,
		Thai = "ร้านสัตว์เลี้ยง",
	})
	local petBowl = part(petShop, "PetBowl", Vector3.new(5, 1, 5), petShopBase * CFrame.new(0, 0.6, 8) * CFrame.Angles(0, 0, math.rad(90)), COLORS.Blue, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local petPrompt = prompt(petBowl, bilingual("Feed Mochi", "ให้อาหารโมจิ"), bilingual("Pet snack - 5 coins", "ขนมสัตว์เลี้ยง - 5 เหรียญ"))
	self:_connectPrompt(petPrompt, "PetFeed", {})
	for _, side in ipairs({ -1, 1 }) do
		part(petShop, "PetShelf", Vector3.new(4, 5, 12), petShopBase * CFrame.new(side * 12, 2.5, 2), COLORS.Brown, Enum.Material.WoodPlanks)
	end

	local flowerShop, flowerShopBase = self:_building("Flower Shop", Config.Waypoints.FlowerShop - Vector3.new(0, 4, 0), VILLAGE.Plaster, 32, 26, {
		Banner = VILLAGE.RoofHighlight,
		RoofColor = VILLAGE.RoofTile,
		Thai = "ร้านดอกไม้",
	})
	local seedCrate = part(flowerShop, "SeedCrate", Vector3.new(7, 3, 5), flowerShopBase * CFrame.new(0, 1.5, 8), COLORS.Brown, Enum.Material.WoodPlanks)
	local seedPrompt = prompt(seedCrate, bilingual("Buy Daisy seed", "ซื้อเมล็ดเดซี่"), bilingual("15 coins", "15 เหรียญ"))
	self:_connectPrompt(seedPrompt, "BuySeed", { seed = "Daisy" })
	for index, color in ipairs({ COLORS.Pink, COLORS.Purple, COLORS.White, COLORS.Yellow }) do
		local shelfSide = index <= 2 and -1 or 1
		local row = ((index - 1) % 2) * 6
		part(flowerShop, "FlowerDisplay", Vector3.new(4, 3, 4), flowerShopBase * CFrame.new(shelfSide * 11, 1.5, -6 + row), color, Enum.Material.Grass)
	end

	self:_buildPlayground(Config.Waypoints.Playground - Vector3.new(0, 4, 0))

	local school, schoolBase = self:_building("Little School", Config.Waypoints.School - Vector3.new(0, 4, 0), COLORS.Blue, 48, 30, {
		Banner = VILLAGE.WaterLight,
		RoofColor = VILLAGE.RoofShade,
		Thai = "โรงเรียน",
	})
	local blackboard = part(school, "Blackboard", Vector3.new(20, 6, 0.6), schoolBase * CFrame.new(0, 5, 13.5), VILLAGE.Foliage, Enum.Material.Slate)
	blackboard.CanCollide = false
	-- Desks sit either side of a clear centre aisle from the door to the board.
	for index = 1, 8 do
		local column = ({ -17, -9, 9, 17 })[((index - 1) % 4) + 1]
		local row = math.floor((index - 1) / 4)
		part(school, "Desk", Vector3.new(6, 3, 4), schoolBase * CFrame.new(column, 1.5, -1 + row * 7), COLORS.Cream, Enum.Material.WoodPlanks)
	end

	local lake = part(world, "Lake", Vector3.new(80, 1, 45), CFrame.new(Config.Waypoints.Lake.X, 0.2, Config.Waypoints.Lake.Z), COLORS.Water, Enum.Material.Glass)
	lake.Transparency = 0.18
	billboard(lake, "SUNNY LAKE", VILLAGE.Water, UDim2.fromOffset(170, 42))
	part(world, "Beach", Vector3.new(65, 1, 95), CFrame.new(Config.Waypoints.Beach.X, 0.2, Config.Waypoints.Beach.Z), VILLAGE.Plaster, Enum.Material.Sand)

	for index = 1, 22 do
		local angle = index * 2.399
		local radius = 25 + (index % 4) * 13
		self:_flower(Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius), ({ COLORS.Pink, COLORS.Purple, COLORS.White })[(index % 3) + 1])
	end
	for index = 1, 14 do
		self:_tree(Vector3.new(-278 + (index % 4) * 17, 0, -15 + math.floor(index / 4) * 28), 0.85 + (index % 3) * 0.1)
	end
	for _, position in ipairs({
		Vector3.new(-28, 0, -28), Vector3.new(28, 0, -28), Vector3.new(-28, 0, 28), Vector3.new(28, 0, 28),
		Vector3.new(-70, 0, -78), Vector3.new(70, 0, -78), Vector3.new(-72, 0, 84), Vector3.new(72, 0, 84),
	}) do
		self:_lamp(position)
	end

	-- The minimap mirrors the new village loop and the two home groves rather
	-- than drawing the former cross-shaped highway.
	self:_addBlip("Road", "Village Loop", "ถนนวงแหวนหมู่บ้าน", Vector3.new(0, 0, -92), 184, 22, VILLAGE.Cobble)
	self:_addBlip("Road", "Village Loop", "ถนนวงแหวนหมู่บ้าน", Vector3.new(0, 0, 100), 184, 22, VILLAGE.Cobble)
	self:_addBlip("Road", "West Home Grove", "หมู่บ้านฝั่งตะวันตก", Vector3.new(-145, 0, 3), 16, 176, VILLAGE.Cobble)
	self:_addBlip("Road", "East Home Grove", "หมู่บ้านฝั่งตะวันออก", Vector3.new(145, 0, 3), 16, 176, VILLAGE.Cobble)
	self:_addBlip("Road", "Wildwood Trail", "ทางป่าไวลด์วูด", Vector3.new(0, 0, 465), 22, 390, VILLAGE.Cobble)
	self:_addBlip("Area", "Guild Square", "ลานกิลด์", Vector3.new(0, 0, 0), 72, 72, VILLAGE.StoneLight)
	self:_addBlip("Area", "Sunny Lake", "ทะเลสาบ", Config.Waypoints.Lake, 80, 45, COLORS.Water)
	self:_addBlip("Area", "Beach", "ชายหาด", Config.Waypoints.Beach, 65, 95, VILLAGE.Plaster)
	self:_addBlip("Area", "Park", "สวนสาธารณะ", Config.Waypoints.Park, 90, 70, COLORS.Grass)
	self:_addBlip("Area", "Forest", "ป่า", Config.Waypoints.Forest, 90, 110, COLORS.Leaf)
	self:_addBlip("Area", "Playground", "สนามเด็กเล่น", Config.Waypoints.Playground, 44, 44, COLORS.Yellow)

	self:_buildAdventureWorld()

	self:_addBlip("Zone", "Adventure Camp", "แคมป์ผจญภัย", Config.Waypoints.AdventureCamp, 40, 40, ADVENTURE_COLORS.SunsetOrange)
	self:_addBlip("Zone", "Wildwood Forest", "ป่าไวลด์วูด", Config.Waypoints.WildwoodForest, 90, 90, ADVENTURE_COLORS.ForestGreen)
	self:_addBlip("Zone", "Sunrise Mountain", "ภูเขาแสงตะวัน", Config.Waypoints.Mountain, 120, 112, VILLAGE.StoneLight)
	self:_addBlip("Zone", "River & Lake", "แม่น้ำและทะเลสาบ", Config.Waypoints.RiverAdventure, 100, 96, ADVENTURE_COLORS.RiverBlue)
	self:_addBlip("Zone", "Mystery Cave", "ถ้ำลึกลับ", Config.Waypoints.MysteryCave, 84, 56, VILLAGE.Stone)

	-- Eight family plots now form two friendly groves beside the village loop.
	-- Every cottage faces its local lane, so the approved wide porch greets the
	-- player instead of pointing toward an empty centre far across the map.
	local homePlots = {
		{ Position = Vector3.new(-177, 0, -119), Facing = Vector3.new(-141, 0, -84) },
		{ Position = Vector3.new(-184, 0, -48), Facing = Vector3.new(-146, 0, -42) },
		{ Position = Vector3.new(-184, 0, 52), Facing = Vector3.new(-143, 0, 58) },
		{ Position = Vector3.new(-160, 0, 123), Facing = Vector3.new(-111, 0, 92) },
		{ Position = Vector3.new(177, 0, -119), Facing = Vector3.new(141, 0, -84) },
		{ Position = Vector3.new(184, 0, -48), Facing = Vector3.new(146, 0, -42) },
		{ Position = Vector3.new(184, 0, 67), Facing = Vector3.new(143, 0, 62) },
		{ Position = Vector3.new(154, 0, 132), Facing = Vector3.new(111, 0, 92) },
	}
	for index, plot in ipairs(homePlots) do
		self:_buildHome(index, CFrame.lookAt(plot.Position, plot.Facing))
	end
end

function WorldService:AssignHome(player)
	if self._homeByPlayer[player] then
		return self._homeByPlayer[player]
	end
	for _, record in ipairs(self._homes) do
		if not record.Owner then
			record.Owner = player
			record.Model:SetAttribute("OwnerUserId", player.UserId)
			record.OwnerLabel.Text = string.format("%s's cozy home", player.DisplayName)
			player:SetAttribute("HomeIndex", record.Index)
			self._homeByPlayer[player] = record
			return record
		end
	end
	warn(string.format("No home plot available for %s", player.Name))
	return nil
end

function WorldService:ReleaseHome(player)
	local record = self._homeByPlayer[player]
	if record then
		record.Owner = nil
		record.Model:SetAttribute("OwnerUserId", 0)
		record.OwnerLabel.Text = "A cozy home"
		self:_applyHomePaint(record, Config.DefaultHomeColor)
		record.FurnitureFolder:ClearAllChildren()
		record.AdventureCampFolder:ClearAllChildren()
		for _, gardenPart in ipairs(record.GardenParts) do
			local visual = gardenPart:FindFirstChild("PlantVisual")
			if visual then
				visual:Destroy()
			end
			local interaction = gardenPart:FindFirstChild("TownPrompt")
			if interaction then
				interaction.ActionText = bilingual("Plant Daisy", "ปลูกเดซี่")
			end
		end
	end
	local pet = self._pets[player]
	if pet then
		pet:Destroy()
		self._pets[player] = nil
	end
	self._homeByPlayer[player] = nil
	player:SetAttribute("HomeIndex", nil)
end

function WorldService:_homeColor(name)
	for _, entry in ipairs(Config.HomeColors) do
		if entry.Name == name then
			return entry.Color
		end
	end
	for _, entry in ipairs(Config.HomeColors) do
		if entry.Name == Config.DefaultHomeColor then
			return entry.Color
		end
	end
	return PORCH_GABLE.Coffee
end

-- Applies one exact menu swatch only to structural walls and the two main roof
-- planes. Every other authored cottage colour remains intact to preserve depth.
function WorldService:_applyHomePaint(home, colorName)
	local homeColor = self:_homeColor(colorName)
	for _, surface in ipairs(home.PaintParts or {}) do
		if surface.Parent then
			surface.Color = homeColor
			surface:SetAttribute("ActiveHomePaint", colorName)
		end
	end
	home.Model:SetAttribute("PaintColor", colorName)
	home.Model:SetAttribute("PaintR", math.round(homeColor.R * 255))
	home.Model:SetAttribute("PaintG", math.round(homeColor.G * 255))
	home.Model:SetAttribute("PaintB", math.round(homeColor.B * 255))
end

--[[
	Builds one piece of furniture from its catalogue entry.

	Every item is a list of boxes in Furniture.lua, so there is a single builder
	here rather than a branch per item. `cframe` is where the item's floor sits,
	already rotated, so the offsets below need no rotation maths of their own.
]]
function WorldService:_makeFurniture(parent, itemId, cframe)
	local info = Furniture.get(itemId)
	if not info then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = itemId
	model:SetAttribute("ItemId", itemId)
	model.Parent = parent

	for _, piece in ipairs(info.Parts) do
		if piece.Light then
			-- A lamp is only a lamp if it actually lights the room.
			local anchor = part(model, "LightCore", Vector3.new(0.2, 0.2, 0.2), cframe * CFrame.new(piece.Offset), piece.Color, Enum.Material.Neon)
			anchor.CanCollide = false
			anchor.Transparency = 1
			local light = Instance.new("PointLight")
			light.Brightness = 1.2
			light.Range = piece.Range or 16
			light.Color = piece.Color
			light.Parent = anchor
		else
			local piecePart = part(model, "Piece", piece.Size, cframe * CFrame.new(piece.Offset), piece.Color, piece.Material, piece.Shape)
			-- Furniture is scenery: solid enough to look real, never solid enough
			-- to trap a child in a corner of their own bedroom.
			piecePart.CanCollide = false
		end
	end

	CollectionService:AddTag(model, FURNITURE_TAG)
	return model
end

--[[
	Redraws everything the player owns, from the authoritative profile.

	Indoor pieces stand on the floor of the house; garden pieces stand on the
	lawn outside it. Both are stored the same way, as a grid square and a
	quarter turn, so this is the only place that has to know the difference.
]]
function WorldService:RefreshHome(player, data)
	local home = self._homeByPlayer[player]
	if not home then
		return
	end
	self:_applyHomePaint(home, data.Home.Paint)
	home.FurnitureFolder:ClearAllChildren()

	for index, entry in ipairs(data.Home.Furniture) do
		if index > Config.MaxFurniture then
			break
		end
		local floorY = Furniture.isOutdoor(entry.Id) and 0 or HOME_FLOOR_TOP
		local placement = home.BaseCFrame
			* CFrame.new(entry.X, floorY, entry.Z)
			* CFrame.Angles(0, math.rad(entry.R or 0), 0)
		self:_makeFurniture(home.FurnitureFolder, entry.Id, placement)
	end
end

--[[
	The level badge over a player's head: a star, the level, and an XP bar.

	It is built on the server so every player sees everyone else's, which is what
	the brief asks for, and it is rebuilt in place rather than recreated on every
	XP tick so the bar can animate rather than snap.
]]
function WorldService:RefreshLevelBadge(player, data)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not data then
		return
	end

	local gui = head:FindFirstChild("LevelBadge")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "LevelBadge"
		gui.Adornee = head
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Size = UDim2.fromOffset(132, 42)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = Config.LabelFarDistance
		gui.Parent = head

		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.BackgroundColor3 = VILLAGE.CanvasLight
		plate.BackgroundTransparency = 0.06
		plate.Size = UDim2.fromScale(1, 1)
		plate.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = plate
		local stroke = Instance.new("UIStroke")
		stroke.Color = VILLAGE.Flower
		stroke.Thickness = 2
		stroke.Parent = plate

		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.Position = UDim2.fromOffset(0, 2)
		text.Size = UDim2.new(1, 0, 0, 22)
		text.TextColor3 = VILLAGE.TimberDeep
		text.TextScaled = true
		text.Parent = plate

		local track = Instance.new("Frame")
		track.Name = "Track"
		track.BackgroundColor3 = VILLAGE.Plaster
		track.BorderSizePixel = 0
		track.Position = UDim2.new(0, 10, 1, -12)
		track.Size = UDim2.new(1, -20, 0, 7)
		track.Parent = plate
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = VILLAGE.Lantern
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
	end

	local plate = gui:FindFirstChild("Plate")
	local text = plate and plate:FindFirstChild("Text")
	local track = plate and plate:FindFirstChild("Track")
	local fill = track and track:FindFirstChild("Fill")
	if text then
		text.Text = Progression.badgeText(data.Level)
	end
	if fill then
		local fraction = Progression.fraction(data.Level, data.XP)
		TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(fraction, 1),
		}):Play()
	end
end

--[[ The level-up moment: the badge pops, and "Level Up!" floats away. ]]
function WorldService:CelebrateLevelUp(player, level)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	local badge = head:FindFirstChild("LevelBadge")
	if badge then
		local plate = badge:FindFirstChild("Plate")
		if plate then
			-- A quick squash and stretch. It reads as a celebration without
			-- moving the badge somewhere the next XP tick would have to undo.
			plate.Size = UDim2.fromScale(1.35, 1.35)
			TweenService:Create(plate, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
		end
	end

	local floater = Instance.new("BillboardGui")
	floater.Name = "LevelUpText"
	floater.Adornee = head
	floater.AlwaysOnTop = true
	floater.LightInfluence = 0
	floater.Size = UDim2.fromOffset(190, 50)
	floater.StudsOffset = Vector3.new(0, 4.2, 0)
	floater.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.format("Level Up!  %d", level)
	label.TextColor3 = VILLAGE.Lantern
	label.TextScaled = true
	label.TextStrokeColor3 = VILLAGE.TimberDark
	label.TextStrokeTransparency = 0.15
	label.Parent = floater

	-- Rise and fade, then clean itself up. Debris guarantees it goes even if the
	-- player leaves mid-animation, so these cannot pile up on a long session.
	TweenService:Create(floater, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 8.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(floater, 1.8)

	self:PetCelebrate(player)
end

function WorldService:RefreshAdventureCamp(player, data)
	local home = self._homeByPlayer[player]
	if not home or not data.Adventure then
		return
	end
	local folder = home.AdventureCampFolder
	folder:ClearAllChildren()
	-- The camp sits clear of the house footprint so no camp building ever grows
	-- through a wall of the home it belongs to.
	local camp = home.BaseCFrame * CFrame.new(-34, 0, 5)
	local level = data.Adventure.CampLevel

	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		local rock = part(folder, "CampStone", Vector3.new(1.2, 0.8, 1.2), camp * CFrame.new(math.cos(angle) * 2.4, 0.6, math.sin(angle) * 2.4), VILLAGE.Stone, Enum.Material.Slate, Enum.PartType.Ball)
		rock.CanCollide = false
	end
	local flame = part(folder, "CampFlame", Vector3.new(2, 2.5, 2), camp * CFrame.new(0, 1.8, 0), ADVENTURE_COLORS.SunsetOrange, Enum.Material.Neon, Enum.PartType.Ball)
	flame.CanCollide = false
	part(folder, "CampTable", Vector3.new(12, 1, 6), camp * CFrame.new(0, 2.6, 12), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)

	if level >= 2 then
		self:_buildTreeHouse(folder, camp)
	end
	if level >= 3 then
		self:_buildCampCottage(folder, camp)
	end
	if level >= 4 then
		part(folder, "Workbench", Vector3.new(9, 1, 4), camp * CFrame.new(14, 2.5, -12), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
		for x = -1, 1 do
			part(folder, "Tool", Vector3.new(0.5, 4, 0.5), camp * CFrame.new(14 + x * 2, 4.5, -12), ADVENTURE_COLORS.SoftYellow, Enum.Material.Metal)
		end
	end
	if level >= 5 then
		-- An open lean-to: four posts and a roof, walk straight in from any side.
		for _, corner in ipairs({ Vector3.new(-6, 0, -4), Vector3.new(2, 0, -4), Vector3.new(-6, 0, 4), Vector3.new(2, 0, 4) }) do
			part(folder, "ShelterPost", Vector3.new(0.8, 6, 0.8), camp * CFrame.new(corner + Vector3.new(-2, 3, -12)), ADVENTURE_COLORS.WoodBrown, Enum.Material.Wood)
		end
		part(folder, "ShelterRoof", Vector3.new(10, 1, 10), camp * CFrame.new(-2, 6.5, -12), ADVENTURE_COLORS.ForestGreen, Enum.Material.WoodPlanks)
		part(folder, "ShelterBed", Vector3.new(7, 1, 5), camp * CFrame.new(-2, 0.5, -12), ADVENTURE_COLORS.WarmBeige, Enum.Material.Fabric)
	end
	if level >= 6 then
		self:_buildAdventureCenter(folder, camp)
	end
end

--[[
	Camp stage 2. The deck used to float ten studs off the ground with no way up,
	so it now gets a staircase and a walled cabin you can actually stand inside.
]]
function WorldService:_buildTreeHouse(folder, camp)
	local treeHouse = Instance.new("Model")
	treeHouse.Name = "TreeHouse"
	treeHouse.Parent = folder

	local deckTop = 9.5
	part(treeHouse, "TreeHouseTrunk", Vector3.new(3, deckTop, 3), camp * CFrame.new(-16, deckTop / 2, 8), ADVENTURE_COLORS.WoodBrown, Enum.Material.Wood)
	part(treeHouse, "TreeHouseDeck", Vector3.new(12, 1, 12), camp * CFrame.new(-16, deckTop - 0.5, 4), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)

	-- Ten steps of just under a stud each. A humanoid climbs anything under two.
	for step = 1, 10 do
		local top = step * (deckTop / 10)
		part(
			treeHouse,
			"TreeHouseStep",
			Vector3.new(5, top, 2),
			camp * CFrame.new(-16, top / 2, -3 - (10 - step) * 2),
			ADVENTURE_COLORS.WoodBrown,
			Enum.Material.WoodPlanks
		)
	end

	local base = camp * CFrame.new(-16, deckTop, 4)
	self:_shell(treeHouse, base, {
		Width = 12,
		Depth = 12,
		Height = 7,
		Thickness = WALL_THICKNESS,
		DoorWidth = 5,
		DoorHeight = 6,
		Color = ADVENTURE_COLORS.WarmBeige,
		Material = Enum.Material.WoodPlanks,
		CeilingColor = ADVENTURE_COLORS.ForestGreen,
		CeilingMaterial = Enum.Material.WoodPlanks,
	})
	self:_dressBuilding(treeHouse, base, {
		Width = 12,
		Depth = 12,
		Height = 7,
		DoorWidth = 5,
		DoorHeight = 6,
		Footing = false,
	})
	self:_interiorLamp(treeHouse, base, Vector3.new(0, 5.8, 0), 18)
end

--[[ Camp stage 3. Was a solid seven-stud block; now a one-room cabin. ]]
function WorldService:_buildCampCottage(folder, camp)
	local cottage = Instance.new("Model")
	cottage.Name = "CampCottage"
	cottage.Parent = folder

	local floorTop = 1
	-- Rotated so the door looks back at the campfire rather than out into the trees.
	local origin = camp * CFrame.new(14, 0, 4) * CFrame.Angles(0, math.rad(90), 0)
	part(cottage, "CottageFloor", Vector3.new(14, floorTop, 12), origin * CFrame.new(0, floorTop / 2, 0), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)

	local base = origin * CFrame.new(0, floorTop, 0)
	self:_shell(cottage, base, {
		Width = 12,
		Depth = 10,
		Height = 8,
		Thickness = WALL_THICKNESS,
		DoorWidth = 5,
		DoorHeight = 6.5,
		Color = ADVENTURE_COLORS.WarmBeige,
		Material = Enum.Material.WoodPlanks,
		CeilingColor = VILLAGE.TimberMid,
		CeilingMaterial = Enum.Material.WoodPlanks,
	})
	self:_dressBuilding(cottage, base, {
		Width = 12,
		Depth = 10,
		Height = 8,
		DoorWidth = 5,
		DoorHeight = 6.5,
	})
	self:_interiorLamp(cottage, base, Vector3.new(0, 6.8, 0), 18)
end

--[[ Camp stage 6. Was a lone signpost; now the hall the sign was advertising. ]]
function WorldService:_buildAdventureCenter(folder, camp)
	local center = Instance.new("Model")
	center.Name = "AdventureCenter"
	center.Parent = folder

	local floorTop = 1
	local origin = camp * CFrame.new(0, 0, -26) * CFrame.Angles(0, math.rad(180), 0)
	part(center, "CenterFloor", Vector3.new(20, floorTop, 16), origin * CFrame.new(0, floorTop / 2, 0), ADVENTURE_COLORS.WarmBeige, Enum.Material.WoodPlanks)

	local base = origin * CFrame.new(0, floorTop, 0)
	self:_shell(center, base, {
		Width = 18,
		Depth = 14,
		Height = 9,
		Thickness = WALL_THICKNESS,
		DoorWidth = 6,
		DoorHeight = 7.5,
		Color = ADVENTURE_COLORS.WarmBeige,
		Material = Enum.Material.WoodPlanks,
		CeilingColor = ADVENTURE_COLORS.ForestGreen,
		CeilingMaterial = Enum.Material.WoodPlanks,
	})
	self:_dressBuilding(center, base, {
		Width = 18,
		Depth = 14,
		Height = 9,
		DoorWidth = 6,
		DoorHeight = 7.5,
		Banner = VILLAGE.Banner,
	})
	self:_interiorLamp(center, base, Vector3.new(0, 7.8, 0), 22)

	local centerSign = part(center, "AdventureCenterSign", Vector3.new(13, 4, 0.6), base * CFrame.new(0, 8, -7.4), ADVENTURE_COLORS.WoodBrown, Enum.Material.WoodPlanks)
	centerSign.CanCollide = false
	billboard(centerSign, "ศูนย์ผจญภัย / ADVENTURE CENTER", ADVENTURE_COLORS.ForestGreen, UDim2.fromOffset(270, 48))
end

function WorldService:RefreshGarden(player, data)
	local home = self._homeByPlayer[player]
	if not home then
		return
	end
	for index, gardenPart in ipairs(home.GardenParts) do
		local old = gardenPart:FindFirstChild("PlantVisual")
		if old then
			old:Destroy()
		end
		local interaction = gardenPart:FindFirstChild("TownPrompt")
		local slot = data.Garden.Slots[index]
		if slot and slot.State == "Planted" and Catalog.Seeds[slot.Seed] then
			local seed = Catalog.Seeds[slot.Seed]
			local visual = Instance.new("Model")
			visual.Name = "PlantVisual"
			visual.Parent = gardenPart
			local stemHeight = slot.Watered and 3.5 or 1.5
			local stem = part(visual, "Stem", Vector3.new(0.45, stemHeight, 0.45), gardenPart.CFrame * CFrame.new(0, 0.5 + stemHeight / 2, 0), COLORS.Leaf, Enum.Material.Grass)
			stem.CanCollide = false
			local bloom = part(visual, "Bloom", Vector3.new(2.4, 2.4, 2.4), gardenPart.CFrame * CFrame.new(0, 1 + stemHeight, 0), seed.Color, slot.Watered and Enum.Material.Neon or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			bloom.CanCollide = false
			if interaction then
				if not slot.Watered then
					interaction.ActionText = bilingual("Water flower", "รดน้ำดอกไม้")
				elseif os.time() - slot.PlantedAt >= seed.GrowSeconds then
					interaction.ActionText = bilingual("Pick flower", "เก็บดอกไม้")
				else
					interaction.ActionText = bilingual("Check flower", "ดูดอกไม้")
				end
				interaction.ObjectText = bilingual(seed.DisplayName, seed.DisplayNameThai)
			end
		elseif interaction then
			interaction.ActionText = bilingual("Plant Daisy", "ปลูกเดซี่")
			interaction.ObjectText = bilingual(string.format("Garden patch %d", index), string.format("แปลงสวน %d", index))
		end
	end
end

-- Builds a real silhouette for each supplied companion sheet instead of
-- recolouring one generic cat. All coordinates use the same 5.25-stud authoring
-- envelope, so every species still obeys the 1:4 avatar/pet scale contract.
function WorldService:_buildCompanionGeometry(pet, companionId, petScale)
	local root = pet.PrimaryPart
	for _, child in ipairs(pet:GetChildren()) do
		if child:IsA("BasePart") and child ~= root then
			child:Destroy()
		end
	end
	local colors = WildwoodStyle.Pets[companionId] or WildwoodStyle.Pets.Cat
	root.Color = colors.Main
	-- Mochi's approved Voxel body is a cuboid. Other companions keep their
	-- original rounded body root when the player switches species.
	root.Shape = companionId == "Cat" and Enum.PartType.Block or Enum.PartType.Ball

	local function scaled(value)
		return value * petScale
	end
	local function petPart(name, size, offset, color, shape, material)
		local object = part(pet, name, scaled(size), root.CFrame * CFrame.new(scaled(offset)), color, material or Enum.Material.SmoothPlastic, shape)
		object.CanCollide = false
		object:SetAttribute("CompanionDetail", true)
		return object
	end
	local function petWedge(name, size, offset, color, rotation)
		local object = Instance.new("WedgePart")
		object.Name = name
		object.Size = scaled(size)
		object.CFrame = root.CFrame * CFrame.new(scaled(offset)) * (rotation or CFrame.new())
		object.Color = color
		object.Material = Enum.Material.SmoothPlastic
		object.Anchored = true
		object.CanCollide = false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.CastShadow = true
		object:SetAttribute("CompanionDetail", true)
		object:SetAttribute("TriangleFeature", true)
		object.Parent = pet
		return object
	end
	local function eyes(y, z, spacing, size, eyeColor)
		for _, side in ipairs({ -1, 1 }) do
			petPart("Eye", Vector3.new(size, size, size), Vector3.new(side * spacing, y, z), eyeColor or colors.Dark, Enum.PartType.Ball)
			petPart("EyeGlint", Vector3.new(size * 0.28, size * 0.28, size * 0.28), Vector3.new(side * spacing - 0.08, y + 0.08, z - size * 0.46), STYLE.White, Enum.PartType.Ball, Enum.Material.Neon)
		end
	end
	local function voxelEyes(y, z, spacing)
		for _, side in ipairs({ -1, 1 }) do
			local suffix = side < 0 and "Left" or "Right"
			petPart("CatEye" .. suffix, Vector3.new(0.68, 0.78, 0.18), Vector3.new(side * spacing, y, z), colors.Eye)
			petPart("CatPupil" .. suffix, Vector3.new(0.18, 0.5, 0.08), Vector3.new(side * spacing, y - 0.02, z - 0.13), colors.Dark)
			petPart("CatEyeGlint" .. suffix, Vector3.new(0.13, 0.13, 0.05), Vector3.new(side * spacing - 0.13, y + 0.17, z - 0.18), STYLE.White, nil, Enum.Material.Neon)
		end
	end

	if companionId == "Fox" then
		petPart("FoxHead", Vector3.new(3.2, 3.1, 3.1), Vector3.new(0, 1.35, -2), colors.Main, Enum.PartType.Ball)
		petPart("FoxEarLeft", Vector3.new(1.05, 1.5, 0.9), Vector3.new(-1, 3, -2), colors.Dark)
		petPart("FoxEarRight", Vector3.new(1.05, 1.5, 0.9), Vector3.new(1, 3, -2), colors.Dark)
		petPart("FoxMuzzle", Vector3.new(2.1, 1.2, 1.1), Vector3.new(0, 0.85, -3.15), colors.Light, Enum.PartType.Ball)
		petPart("FoxChest", Vector3.new(2.1, 2.3, 0.65), Vector3.new(0, 0, -2.05), colors.Light, Enum.PartType.Ball)
		petPart("FoxTail", Vector3.new(2.1, 2.1, 4.2), Vector3.new(1.1, 0.75, 2.8), colors.Main, Enum.PartType.Ball)
		petPart("FoxTailTip", Vector3.new(1.9, 1.9, 1.6), Vector3.new(1.1, 0.75, 4.7), colors.Light, Enum.PartType.Ball)
		petPart("Nose", Vector3.new(0.5, 0.45, 0.5), Vector3.new(0, 0.9, -3.72), colors.Dark, Enum.PartType.Ball)
		eyes(1.65, -3.35, 0.62, 0.48)
	elseif companionId == "Dog" then
		petPart("ShibaHead", Vector3.new(3.3, 3.15, 3.2), Vector3.new(0, 1.35, -2), colors.Main, Enum.PartType.Ball)
		petPart("ShibaEarLeft", Vector3.new(1.05, 1.45, 1), Vector3.new(-1, 3.02, -2), colors.Main)
		petPart("ShibaEarRight", Vector3.new(1.05, 1.45, 1), Vector3.new(1, 3.02, -2), colors.Main)
		petPart("ShibaMuzzle", Vector3.new(2.15, 1.25, 1.05), Vector3.new(0, 0.8, -3.2), colors.Light, Enum.PartType.Ball)
		petPart("ShibaChest", Vector3.new(2.3, 2.35, 0.7), Vector3.new(0, -0.05, -2.05), colors.Light, Enum.PartType.Ball)
		petPart("Bandana", Vector3.new(3.1, 0.55, 2.6), Vector3.new(0, 0.25, -1.45), colors.Accent, Enum.PartType.Ball, Enum.Material.Fabric)
		for index, offset in ipairs({ Vector3.new(1.3, 1.25, 2.8), Vector3.new(2.05, 1.7, 3.15), Vector3.new(1.7, 2.05, 3.75) }) do
			petPart("CurledTail" .. index, Vector3.new(1.25, 1.25, 1.25), offset, index == 3 and colors.Light or colors.Main, Enum.PartType.Ball)
		end
		petPart("Nose", Vector3.new(0.52, 0.45, 0.5), Vector3.new(0, 0.85, -3.75), colors.Dark, Enum.PartType.Ball)
		eyes(1.62, -3.4, 0.64, 0.5)
	elseif companionId == "Owl" then
		root.Color = colors.Main
		petPart("OwlHead", Vector3.new(3.5, 3.35, 3.1), Vector3.new(0, 1.35, -1.65), colors.Main, Enum.PartType.Ball)
		petPart("OwlTuftLeft", Vector3.new(0.9, 1.5, 0.8), Vector3.new(-1.1, 3, -1.6), colors.Dark)
		petPart("OwlTuftRight", Vector3.new(0.9, 1.5, 0.8), Vector3.new(1.1, 3, -1.6), colors.Dark)
		petPart("OwlWingLeft", Vector3.new(1.3, 2.8, 2.6), Vector3.new(-1.75, 0, 0.1), colors.Dark, Enum.PartType.Ball)
		petPart("OwlWingRight", Vector3.new(1.3, 2.8, 2.6), Vector3.new(1.75, 0, 0.1), colors.Dark, Enum.PartType.Ball)
		for _, side in ipairs({ -1, 1 }) do
			petPart("OwlEyeDisc", Vector3.new(1.45, 1.45, 0.55), Vector3.new(side * 0.78, 1.55, -3.05), colors.Light, Enum.PartType.Ball)
		end
		petPart("OwlBeak", Vector3.new(0.65, 0.75, 0.65), Vector3.new(0, 0.85, -3.5), colors.Accent)
		eyes(1.58, -3.4, 0.78, 0.5)
	elseif companionId == "Rabbit" then
		petPart("RabbitHead", Vector3.new(3.05, 2.9, 3), Vector3.new(0, 1.15, -1.9), colors.Main, Enum.PartType.Ball)
		petPart("RabbitEarLeft", Vector3.new(0.85, 2.2, 0.82), Vector3.new(-0.75, 2.65, -1.9), colors.Main, Enum.PartType.Ball)
		petPart("RabbitEarRight", Vector3.new(0.85, 2.2, 0.82), Vector3.new(0.75, 2.65, -1.9), colors.Main, Enum.PartType.Ball)
		petPart("InnerEarLeft", Vector3.new(0.36, 1.45, 0.85), Vector3.new(-0.75, 2.65, -2.22), colors.Accent, Enum.PartType.Ball)
		petPart("InnerEarRight", Vector3.new(0.36, 1.45, 0.85), Vector3.new(0.75, 2.65, -2.22), colors.Accent, Enum.PartType.Ball)
		petPart("CottonTail", Vector3.new(1.65, 1.65, 1.65), Vector3.new(0, 0.7, 2.75), colors.Light, Enum.PartType.Ball)
		petPart("RabbitMuzzle", Vector3.new(1.8, 1, 0.9), Vector3.new(0, 0.55, -3.15), colors.Light, Enum.PartType.Ball)
		petPart("PinkNose", Vector3.new(0.42, 0.38, 0.4), Vector3.new(0, 0.7, -3.65), colors.Accent, Enum.PartType.Ball)
		eyes(1.35, -3.25, 0.6, 0.46)
	else
		-- Approved design A: a toy-like Voxel cat built without spherical parts.
		-- The body root is the compact cuboid torso; every added face, leg, paw,
		-- eye and tail segment is a block or wedge with a readable planar edge.
		petPart("CatHead", Vector3.new(3.2, 2.8, 3.1), Vector3.new(0, 1.35, -2), colors.Main)
		-- A mirrored wedge exposes its triangular side toward the camera, giving
		-- Mochi a clear cat-ear silhouette instead of the old rectangular ears.
		petWedge("CatEarLeft", Vector3.new(0.55, 1.5, 1.15), Vector3.new(-1, 3, -2), colors.Main, CFrame.Angles(0, math.rad(90), 0))
		petWedge("CatEarRight", Vector3.new(0.55, 1.5, 1.15), Vector3.new(1, 3, -2), colors.Main, CFrame.Angles(0, math.rad(-90), 0))
		petWedge("CatInnerEarLeft", Vector3.new(0.24, 1.02, 0.62), Vector3.new(-1, 3, -2.31), colors.Light, CFrame.Angles(0, math.rad(90), 0))
		petWedge("CatInnerEarRight", Vector3.new(0.24, 1.02, 0.62), Vector3.new(1, 3, -2.31), colors.Light, CFrame.Angles(0, math.rad(-90), 0))
		petPart("CatMuzzle", Vector3.new(1.85, 0.82, 0.32), Vector3.new(0, 0.72, -3.62), colors.Light)
		petPart("CatChest", Vector3.new(1.8, 1.9, 0.28), Vector3.new(0, -0.05, -2.38), colors.Light)

		for _, leg in ipairs({
			{ "CatFrontLegLeft", Vector3.new(-0.88, -0.45, -1.55) },
			{ "CatFrontLegRight", Vector3.new(0.88, -0.45, -1.55) },
			{ "CatBackLegLeft", Vector3.new(-1.15, -0.45, 1.35) },
			{ "CatBackLegRight", Vector3.new(1.15, -0.45, 1.35) },
		}) do
			petPart(leg[1], Vector3.new(0.65, 1.4, 0.75), leg[2], colors.Main)
		end
		for _, paw in ipairs({
			{ "CatFrontPawLeft", Vector3.new(-0.88, -1.2, -1.72) },
			{ "CatFrontPawRight", Vector3.new(0.88, -1.2, -1.72) },
			{ "CatBackPawLeft", Vector3.new(-1.15, -1.2, 1.5) },
			{ "CatBackPawRight", Vector3.new(1.15, -1.2, 1.5) },
		}) do
			petPart(paw[1], Vector3.new(0.92, 0.6, 1.15), paw[2], colors.Main)
		end

		-- Four rising cuboids reproduce the stepped tail from concept A.
		petPart("CatTail", Vector3.new(0.68, 0.68, 1.25), Vector3.new(1.15, 0.35, 2.68), colors.Main)
		petPart("CatTailStep2", Vector3.new(0.68, 0.82, 0.68), Vector3.new(1.45, 0.9, 3.1), colors.Main)
		petPart("CatTailStep3", Vector3.new(0.68, 0.82, 0.68), Vector3.new(1.45, 1.58, 3.1), colors.Main)
		petPart("CatTailStep4", Vector3.new(0.68, 0.82, 0.68), Vector3.new(1.45, 2.26, 3.1), colors.Main)

		-- Draw the small facial marks on a plate that follows the 3D head. The
		-- down-pointing triangle is unambiguous at pet scale, while omega makes
		-- the familiar two-lobed cat mouth readable from normal play distance.
		local facePlate = petPart("CatFacePlate", Vector3.new(2.15, 1.25, 0.05), Vector3.new(0, 0.76, -3.81), colors.Main)
		facePlate.Transparency = 1
		facePlate.CastShadow = false
		local faceGui = Instance.new("SurfaceGui")
		faceGui.Name = "CatFace"
		faceGui.Adornee = facePlate
		faceGui.Face = Enum.NormalId.Front
		faceGui.AlwaysOnTop = false
		faceGui.LightInfluence = 0
		faceGui.CanvasSize = Vector2.new(220, 140)
		faceGui.Parent = facePlate

		local nose = Instance.new("TextLabel")
		nose.Name = "CatNose"
		nose.BackgroundTransparency = 1
		nose.Position = UDim2.fromScale(0.37, 0.24)
		nose.Size = UDim2.fromScale(0.26, 0.31)
		nose.Font = Enum.Font.GothamBold
		nose.Text = "▼"
		nose.TextColor3 = colors.Accent
		nose.TextScaled = true
		nose.Parent = faceGui

		local mouth = Instance.new("TextLabel")
		mouth.Name = "CatMouth"
		mouth.BackgroundTransparency = 1
		mouth.Position = UDim2.fromScale(0.28, 0.48)
		mouth.Size = UDim2.fromScale(0.44, 0.4)
		mouth.Font = Enum.Font.GothamBold
		mouth.Text = "ω"
		mouth.TextColor3 = colors.Mouth
		mouth.TextScaled = true
		mouth.Parent = faceGui

		voxelEyes(1.62, -3.62, 0.64)
	end

	if companionId ~= "Cat" then
		for _, side in ipairs({ -1, 1 }) do
			petPart("FrontPaw", Vector3.new(0.95, 0.65, 1.4), Vector3.new(side * 0.9, -1.15, -1.35), colors.Light, Enum.PartType.Ball)
		end
	end
	pet:SetAttribute("CompanionId", companionId)
	pet:SetAttribute("ReferenceAnimalSheet", true)
end

function WorldService:_createPet(player)
	local characterHeight, footOffset = characterBodyMetrics(player)
	local petHeight = characterHeight * Config.PetHeightRatio
	local petScale = petHeight / PET_CANONICAL_HEIGHT
	local function scaled(value)
		return value * petScale
	end

	local root = part(self._petsFolder, "BodyRoot", scaled(Vector3.new(3.5, 3, 4.5)), CFrame.new(0, -100, 0), WildwoodStyle.Pets.Cat.Main, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	root.CanCollide = false
	local pet = modelWithPrimary(string.format("%s_Pet", player.Name), self._petsFolder, root)
	billboard(root, "Mochi", STYLE.DarkEarth, UDim2.fromOffset(110, 32))
	self:_buildCompanionGeometry(pet, "Cat", petScale)
	pet:SetAttribute("CelebrateUntil", 0)
	pet:SetAttribute("CharacterHeight", characterHeight)
	pet:SetAttribute("CharacterFootOffset", footOffset)
	pet:SetAttribute("VisualHeight", petHeight)
	pet:SetAttribute("HeightRatio", Config.PetHeightRatio)
	pet:SetAttribute("PetScale", petScale)
	self._pets[player] = pet
	return pet
end

function WorldService:RefreshPet(player, data)
	local pet = self._pets[player]
	local characterHeight, footOffset = characterBodyMetrics(player)
	if pet and pet.Parent and math.abs((pet:GetAttribute("CharacterHeight") or 0) - characterHeight) > 0.01 then
		-- Respawning with a differently scaled avatar should resize the companion,
		-- not leave behind a pet sized for the previous body.
		pet:Destroy()
		pet = nil
	end
	if not pet or not pet.Parent then
		pet = self:_createPet(player)
	end
	pet:SetAttribute("CharacterFootOffset", footOffset)
	local root = pet.PrimaryPart
	local companionId = data.Adventure and data.Adventure.ActiveCompanion or "Cat"
	local companion = Catalog.Companions[companionId] or Catalog.Companions.Cat
	if pet:GetAttribute("CompanionId") ~= companionId then
		self:_buildCompanionGeometry(pet, companionId, pet:GetAttribute("PetScale") or (characterHeight * Config.PetHeightRatio / PET_CANONICAL_HEIGHT))
	end
	local labelGui = root and root:FindFirstChild("WorldLabel")
	local label = labelGui and labelGui:FindFirstChild("Text")
	if label then
		label.Text = string.format("%s / %s  Lv.%d", companion.DisplayNameThai, companion.DisplayName, data.Pet.Level)
	end
end

function WorldService:PulseMysteryCave()
	for _, rune in ipairs(self._caveRunes or {}) do
		rune.Material = Enum.Material.Neon
		rune.Transparency = 0
	end
	task.delay(2, function()
		for _, rune in ipairs(self._caveRunes or {}) do
			if rune.Parent then
				rune.Transparency = 0.15
			end
		end
	end)
end

function WorldService:PetCelebrate(player)
	local pet = self._pets[player]
	if pet then
		pet:SetAttribute("CelebrateUntil", os.clock() + 1.5)
	end
end

function WorldService:_startPetFollow()
	RunService.Heartbeat:Connect(function(deltaTime)
		self._followAccumulator += deltaTime
		if self._followAccumulator < 0.1 then
			return
		end
		self._followAccumulator = 0
		for player, pet in pairs(self._pets) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and pet.Parent and pet.PrimaryPart then
				local horizontal = root.Position - root.CFrame.LookVector * 5 + root.CFrame.RightVector * 3
				local feetY = root.Position.Y - (pet:GetAttribute("CharacterFootOffset") or Config.CharacterReferenceHeight * 0.6)
				local targetPosition = Vector3.new(horizontal.X, feetY + pet.PrimaryPart.Size.Y / 2, horizontal.Z)
				local celebrating = (pet:GetAttribute("CelebrateUntil") or 0) > os.clock()
				if celebrating then
					local bounceHeight = (pet:GetAttribute("VisualHeight") or Config.CharacterReferenceHeight * Config.PetHeightRatio) * 0.65
					targetPosition += Vector3.new(0, math.abs(math.sin(os.clock() * 10)) * bounceHeight, 0)
				end
				local target = CFrame.lookAt(targetPosition, root.Position)
				local current = pet:GetPivot()
				if (current.Position - targetPosition).Magnitude > 80 then
					pet:PivotTo(target)
				else
					pet:PivotTo(current:Lerp(target, 0.22))
				end
			end
		end
	end)
end

function WorldService:_styleExplorerCharacter(character, outfit)
	-- One shared full-body builder powers both the live character and the 3D
	-- models in the Style grid. It preserves the Humanoid/joints for movement.
	return AvatarModels.Apply(character, outfit)
end
function WorldService:ApplyOutfit(player, data)
	local character = player.Character
	if not character then
		return
	end
	if data.Wardrobe.Equipped == "Original" then
		AvatarModels.Clear(character)
		return
	end
	local outfit = Catalog.Outfits[data.Wardrobe.Equipped]
	if not outfit then
		AvatarModels.Clear(character)
		return
	end
	self:_styleExplorerCharacter(character, outfit)
end

function WorldService:Teleport(player, destination)
	local target = Config.Waypoints[destination]
	local character = player.Character
	if target and character then
		character:PivotTo(CFrame.new(target + Vector3.new(0, 3, 0)))
	end
end

function WorldService:TeleportHome(player)
	local home = self._homeByPlayer[player]
	local character = player.Character
	if home and character then
		local destination = home.InteriorSpawn or home.Spawn
		character:PivotTo(destination.CFrame + Vector3.new(0, 3, 0))
	end
end

function WorldService:ShowCafeCustomer(player, cafeItemId)
	-- Guests wait at the counter inside the cafe now that the cafe has an inside.
	local cafeItem = CafeMenu.get(CafeMenu.resolve(cafeItemId))
	local base = self._cafeBase * CFrame.new(math.random(-8, 8), 2, 4)
	local root = part(self._townFolder, "HappyGuest", Vector3.new(2.5, 4, 2.5), base, COLORS.Purple, Enum.Material.SmoothPlastic)
	root.CanCollide = false
	local guest = modelWithPrimary("CafeGuest", self._townFolder, root)
	local head = part(guest, "Head", Vector3.new(2.5, 2.5, 2.5), base * CFrame.new(0, 3, 0), Color3.fromRGB(255, 224, 189), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	head.CanCollide = false
	self:_styleExplorerCharacter(guest, {
		Torso = STYLE.ForestGreen,
		Arms = Color3.fromRGB(255, 224, 189),
		Legs = STYLE.EarthBrown,
	})
	local servedFood = CafeModels.build(guest, CafeMenu.resolve(cafeItemId), base * CFrame.new(1.75, 0.25, -0.8), 0.72)
	servedFood:SetAttribute("ServedItem", true)
	billboard(head, string.format("Thank you for the %s, %s!", cafeItem.Name, player.DisplayName), VILLAGE.WaterLight, UDim2.fromOffset(230, 48))
	Debris:AddItem(guest, 3)
end

return WorldService
