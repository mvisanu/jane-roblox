local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AvatarModels = require(Shared:WaitForChild("AvatarModels"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))

local AvatarGrid = {}

local function addPreview(card, avatarId, outfit)
	local preview = Instance.new("ViewportFrame")
	preview.Name = avatarId .. "3DPreview"
	-- The approved sheet uses one warm neutral studio, not six tinted cards.
	preview.BackgroundColor3 = Color3.fromRGB(238, 235, 231)
	preview.BorderSizePixel = 0
	preview.ClipsDescendants = true
	preview.Size = UDim2.new(1, 0, 0, HudLayout.AVATAR_PREVIEW_HEIGHT)
	preview.Ambient = Color3.fromRGB(185, 180, 165)
	preview.LightColor = Color3.fromRGB(255, 245, 218)
	preview.LightDirection = Vector3.new(-1, -1, -1)
	preview.Parent = card

	local camera = Instance.new("Camera")
	camera.Name = "AvatarPreviewCamera"
	camera.FieldOfView = 28
	camera.CFrame = AvatarModels.PreviewCameraCFrame
	camera.Parent = preview
	preview.CurrentCamera = camera

	local world = Instance.new("WorldModel")
	world.Name = "AvatarPreviewWorld"
	world.Parent = preview
	AvatarModels.BuildPreview(world, avatarId)

	local ground = Instance.new("Part")
	ground.Name = "PreviewGround"
	ground.Anchored = true
	ground.CanCollide = false
	ground.Color = Color3.fromRGB(83, 78, 72)
	ground.Material = Enum.Material.SmoothPlastic
	ground.Shape = Enum.PartType.Cylinder
	ground.Size = Vector3.new(0.08, 3.5, 3.5)
	ground.CFrame = CFrame.new(0, -0.42, 0) * CFrame.Angles(0, 0, math.rad(90))
	ground.Transparency = 0.72
	ground.Parent = world
	return preview
end

local function addCard(row, index, avatarId, equippedId, theme, components, bilingual, onSelect)
	local outfit = Catalog.Outfits[avatarId]
	local selected = avatarId == equippedId
	local card = Instance.new("TextButton")
	card.Name = "AvatarSlot" .. index .. "_" .. avatarId
	card.AutoButtonColor = true
	card.BackgroundColor3 = selected and theme.Colors.Selected or theme.Colors.White
	card.LayoutOrder = index
	card.Text = ""
	card:SetAttribute("AvatarId", avatarId)
	card:SetAttribute("Gender", outfit.Gender)
	card:SetAttribute("Selected", selected)
	card.Parent = row
	components.corner(card, theme.SmallCorner)
	components.stroke(card, selected and outfit.Palette.Accent or theme.Colors.Border, selected and 4 or 2, 0)

	addPreview(card, avatarId, outfit)

	local label = components.label(
		card,
		bilingual(outfit.DisplayName, outfit.DisplayNameThai),
		UDim2.new(1, -10, 0, HudLayout.AVATAR_CARD_HEIGHT - HudLayout.AVATAR_PREVIEW_HEIGHT - 5),
		UDim2.fromOffset(5, HudLayout.AVATAR_PREVIEW_HEIGHT + 3),
		11,
		true
	)
	label.Name = "AvatarName"
	label.TextColor3 = theme.Colors.Ink
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 4

	if selected then
		local badge = Instance.new("TextLabel")
		badge.Name = "SelectedBadge"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.BackgroundColor3 = outfit.Palette.Accent
		badge.Position = UDim2.new(1, -6, 0, 6)
		badge.Size = UDim2.fromOffset(28, 28)
		badge.Font = theme.Fonts.Headline
		badge.Text = "✓"
		badge.TextColor3 = theme.textOn(outfit.Palette.Accent)
		badge.TextSize = 17
		badge.ZIndex = 6
		badge.Parent = card
		components.corner(badge, UDim.new(1, 0))
	end

	card.Activated:Connect(function()
		if not selected then
			onSelect(avatarId)
		end
	end)
	return card
end

local function addGenderGroup(grid, gender, order, equippedId, theme, components, bilingual, onSelect)
	local group = Instance.new("Frame")
	group.Name = gender .. "AvatarGroup"
	group.BackgroundTransparency = 1
	group.LayoutOrder = order
	group.Size = UDim2.new(1, 0, 0, HudLayout.AVATAR_GENDER_GROUP_HEIGHT)
	group.Parent = grid

	local heading = components.label(
		group,
		gender == "Male" and bilingual("MALE AVATARS", "อวาตารชาย") or bilingual("FEMALE AVATARS", "อวาตารหญิง"),
		UDim2.new(1, 0, 0, HudLayout.AVATAR_GENDER_HEADER_HEIGHT),
		UDim2.fromOffset(0, 0),
		14,
		true
	)
	heading.Name = gender .. "Header"
	heading.TextColor3 = theme.Colors.PrimaryDark
	heading.TextXAlignment = Enum.TextXAlignment.Left

	local row = Instance.new("Frame")
	row.Name = gender .. "AvatarRow"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, HudLayout.AVATAR_GENDER_HEADER_HEIGHT)
	row.Size = UDim2.new(1, 0, 0, HudLayout.AVATAR_CARD_HEIGHT)
	row.Parent = group

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(HudLayout.AVATAR_GRID_GAP, 0)
	layout.CellSize = UDim2.new(1 / HudLayout.AVATAR_GRID_COLUMNS, -HudLayout.AVATAR_GRID_GAP * 2 / 3, 1, 0)
	layout.FillDirectionMaxCells = HudLayout.AVATAR_GRID_COLUMNS
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local slot = 0
	for index, avatarId in ipairs(Catalog.AvatarOrder) do
		if Catalog.Outfits[avatarId].Gender == gender then
			slot += 1
			addCard(row, index, avatarId, equippedId, theme, components, bilingual, onSelect).LayoutOrder = slot
		end
	end
	return group
end

function AvatarGrid.create(parent, equippedId, theme, components, bilingual, onSelect)
	local grid = Instance.new("Frame")
	grid.Name = "ApprovedAvatarGrid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, HudLayout.AVATAR_GRID_HEIGHT)
	grid.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, HudLayout.AVATAR_GENDER_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	addGenderGroup(grid, "Male", 1, equippedId, theme, components, bilingual, onSelect)
	addGenderGroup(grid, "Female", 2, equippedId, theme, components, bilingual, onSelect)
	return grid
end

return table.freeze(AvatarGrid)
