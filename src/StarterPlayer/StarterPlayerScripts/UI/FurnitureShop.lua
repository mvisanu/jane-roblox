--[[
	Furniture shop and placement.

	Two tabs. SHOP browses the catalogue: search, filter by room, favourite, and a
	real rotating 3D preview of the piece before spending a coin on it. Buying
	first opens a placement ghost; coins are spent only after BUY & PLACE. MY HOME
	lists what is already placed, and lets each piece be moved, turned or packed
	away.

	The preview and the placement ghost are built from the same Furniture data the
	server builds the real thing from, so what you see is what you get. Placement
	uses the same Placement module the server validates with, which is why the
	ghost can turn red on exactly the squares the server would refuse - but the
	server still checks again, and its answer is the one that counts.

	Movement is by on-screen arrows rather than dragging in 3D. It is precise on a
	phone, needs no raycasting, and a child can understand it.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Furniture = require(Shared:WaitForChild("Furniture"))
local Placement = require(Shared:WaitForChild("Placement"))
local Config = require(Shared:WaitForChild("Config"))

local FurnitureShop = {}
FurnitureShop.__index = FurnitureShop

local CARD_HEIGHT = 92

--[[ Builds an item's model from catalogue data. Used by the preview and the ghost. ]]
local function buildModel(itemId)
	local info = Furniture.get(itemId)
	if not info then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = itemId

	for _, piece in ipairs(info.Parts) do
		if not piece.Light then
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
			part.Size = piece.Size
			part.CFrame = CFrame.new(piece.Offset)
			part.Color = piece.Color
			part.Material = piece.Material
			if piece.Shape then
				part.Shape = piece.Shape
			end
			part.Parent = model
			if not model.PrimaryPart then
				model.PrimaryPart = part
			end
		end
	end
	return model
end

function FurnitureShop.new(parent, theme, components, bilingual, onAction)
	local self = setmetatable({}, FurnitureShop)
	self._theme = theme
	self._components = components
	self._bilingual = bilingual
	self._onAction = onAction
	self._tab = "Shop"
	self._category = "All"
	self._search = ""
	self._state = nil
	self._ghost = nil
	self._purchaseStarting = false
	self._committing = false

	local panel = Instance.new("Frame")
	panel.Name = "FurnitureShop"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = theme.Colors.Surface
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.82, 0)
	panel.Visible = false
	panel.Parent = parent
	components.corner(panel)
	components.stroke(panel, theme.Colors.White, 3)
	components.shadow(panel)
	self._panel = panel

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 380)
	constraint.MaxSize = Vector2.new(720, 700)
	constraint.Parent = panel

	local title = components.label(panel, bilingual("FURNITURE", "เฟอร์นิเจอร์"), UDim2.new(1, -80, 0, 44), UDim2.fromOffset(18, 6), 18, true)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.AutoButtonColor = false
	close.BackgroundColor3 = theme.Colors.Primary
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(44, 44)
	close.Font = Enum.Font.GothamBold
	close.Text = "X"
	close.TextColor3 = theme.textOn(theme.Colors.Primary)
	close.TextSize = 19
	close.Parent = panel
	components.corner(close, UDim.new(1, 0))
	close.Activated:Connect(function()
		self:SetVisible(false)
	end)

	-- Tabs.
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(14, 52)
	tabs.Size = UDim2.new(1, -28, 0, 40)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs

	self._tabButtons = {}
	for _, entry in ipairs({
		{ Id = "Shop", Text = bilingual("SHOP", "ร้านค้า") },
		{ Id = "Home", Text = bilingual("MY HOME", "บ้านของฉัน") },
	}) do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = theme.Colors.White
		button.Size = UDim2.new(0.5, -3, 1, 0)
		button.Font = Enum.Font.GothamBold
		button.Text = entry.Text
		button.TextColor3 = theme.Colors.Ink
		button.TextSize = 11
		button.Parent = tabs
		components.corner(button, theme.SmallCorner)
		button.Activated:Connect(function()
			self._tab = entry.Id
			self:_render()
		end)
		self._tabButtons[entry.Id] = button
	end

	-- Search.
	local search = Instance.new("TextBox")
	search.BackgroundColor3 = theme.Colors.White
	search.ClearTextOnFocus = false
	search.Font = Enum.Font.Gotham
	search.PlaceholderText = "Search furniture..."
	search.Position = UDim2.fromOffset(14, 98)
	search.Size = UDim2.new(1, -28, 0, 38)
	search.Text = ""
	search.TextColor3 = theme.Colors.Ink
	search.TextSize = 12
	search.Parent = panel
	components.corner(search, theme.SmallCorner)
	self._searchBox = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		self._search = string.lower(search.Text)
		self:_render()
	end)

	-- Category filter.
	local filter = Instance.new("ScrollingFrame")
	filter.AutomaticCanvasSize = Enum.AutomaticSize.X
	filter.BackgroundTransparency = 1
	filter.BorderSizePixel = 0
	filter.CanvasSize = UDim2.fromOffset(0, 0)
	filter.Position = UDim2.fromOffset(14, 142)
	filter.ScrollBarThickness = 3
	filter.ScrollingDirection = Enum.ScrollingDirection.X
	filter.Size = UDim2.new(1, -28, 0, 36)
	filter.Parent = panel
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.Padding = UDim.new(0, 5)
	filterLayout.Parent = filter
	self._filter = filter
	self._filterButtons = {}

	local chips = { { Id = "All", Name = "All", NameThai = "ทั้งหมด" }, { Id = "Favorites", Name = "Favourites", NameThai = "รายการโปรด" } }
	for _, category in ipairs(Furniture.Categories) do
		table.insert(chips, category)
	end
	for _, chip in ipairs(chips) do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = theme.Colors.White
		button.Size = UDim2.fromOffset(96, 32)
		button.Font = Enum.Font.GothamBold
		button.Text = bilingual(chip.Name, chip.NameThai)
		button.TextColor3 = theme.Colors.Ink
		button.TextSize = 9
		button.TextWrapped = true
		button.Parent = filter
		self._components.corner(button, theme.SmallCorner)
		button.Activated:Connect(function()
			self._category = chip.Id
			self:_render()
		end)
		self._filterButtons[chip.Id] = button
	end

	local list = Instance.new("ScrollingFrame")
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Position = UDim2.fromOffset(14, 186)
	list.ScrollBarImageColor3 = theme.Colors.Water
	list.ScrollBarThickness = 5
	list.Size = UDim2.new(1, -28, 1, -200)
	list.Parent = panel
	components.list(list, 8)
	self._list = list

	self:_buildPlacementBar(parent)
	return self
end

--[[ The controls shown while a piece is being positioned. ]]
function FurnitureShop:_buildPlacementBar(parent)
	local theme = self._theme
	local bar = Instance.new("Frame")
	bar.Name = "PlacementBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundColor3 = theme.Colors.Surface
	bar.Position = UDim2.new(0.5, 0, 1, -92)
	bar.Size = UDim2.fromOffset(330, 148)
	bar.Visible = false
	bar.Parent = parent
	self._components.corner(bar, theme.SmallCorner)
	self._components.stroke(bar, theme.Colors.White, 3)
	self._components.shadow(bar)
	self._bar = bar

	local hint = self._components.label(bar, "", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 4), 11, true)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	self._hint = hint

	local function padButton(text, position, size, color, callback)
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = color
		button.Position = position
		button.Size = size
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextColor3 = theme.Colors.Ink
		button.TextSize = 13
		button.TextWrapped = true
		button.Parent = bar
		self._components.corner(button, theme.SmallCorner)
		button.Activated:Connect(callback)
		return button
	end

	-- A D-pad. One tap is one grid square, so placement is exact.
	padButton("^", UDim2.fromOffset(56, 38), UDim2.fromOffset(44, 34), theme.Colors.White, function() self:_nudge(0, -1) end)
	padButton("v", UDim2.fromOffset(56, 106), UDim2.fromOffset(44, 34), theme.Colors.White, function() self:_nudge(0, 1) end)
	padButton("<", UDim2.fromOffset(8, 72), UDim2.fromOffset(44, 34), theme.Colors.White, function() self:_nudge(-1, 0) end)
	padButton(">", UDim2.fromOffset(104, 72), UDim2.fromOffset(44, 34), theme.Colors.White, function() self:_nudge(1, 0) end)

	padButton(self._bilingual("TURN", "หมุน"), UDim2.fromOffset(158, 38), UDim2.fromOffset(72, 44), theme.Colors.Sun, function()
		if self._committing or not self._draft then
			return
		end
		self._draft.R = Placement.normaliseRotation((self._draft.R or 0) + 90)
		self:_updateGhost()
	end)
	self._okButton = padButton(self._bilingual("PLACE", "วาง"), UDim2.fromOffset(236, 38), UDim2.fromOffset(86, 44), theme.Colors.Leaf, function()
		self:_commit()
	end)
	padButton(self._bilingual("CANCEL", "ยกเลิก"), UDim2.fromOffset(158, 90), UDim2.fromOffset(164, 44), theme.Colors.White, function()
		self:_cancelPlacement()
	end)
end

function FurnitureShop:SetVisible(visible)
	-- A pending purchase owns the interaction until the player confirms or uses
	-- CANCEL. Reopening the shop cannot expose another BUY button underneath it.
	if visible and self._draft then
		self._panel.Visible = false
		self._bar.Visible = true
		return
	end
	self._panel.Visible = visible
	if visible then
		self:_render()
	else
		self:_cancelPlacement()
	end
end

function FurnitureShop:IsVisible()
	return self._panel.Visible
end

function FurnitureShop:Update(state)
	self._state = state
	if self._panel.Visible then
		self:_render()
	end
	if self._draft then
		self:_updateGhost()
	end
end

--[[ Placement ---------------------------------------------------------------- ]]

function FurnitureShop:_homeCFrame()
	-- The player's own house is the one tagged with their user id.
	local town = workspace:FindFirstChild("CuteFamilyTown")
	local homes = town and town:FindFirstChild("PlayerHomes")
	if not homes then
		return nil
	end
	for _, home in ipairs(homes:GetChildren()) do
		if home:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			local floor = home:FindFirstChild("Floor")
			if floor then
				-- Floor is centred on the house, one stud thick: its top is the
				-- surface furniture stands on.
				return floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
			end
		end
	end
	return nil
end

--[[ Starts positioning a piece. `purchase` means BUY waits for this confirmation. ]]
function FurnitureShop:BeginPlacement(itemId, index, purchase)
	if self._draft or self._committing then
		return false
	end
	local placed = self._state and self._state.Home and self._state.Home.Furniture
	if not placed then
		return false
	end

	local x, z, rotation
	if index then
		local entry = placed[index]
		x, z, rotation = entry.X, entry.Z, entry.R
	else
		x, z, rotation = Placement.findFreeSpot(placed, itemId)
		if not x then
			local region = Placement.regionFor(itemId)
			x, z, rotation = 0, (region.MinZ + region.MaxZ) / 2, 0
		end
	end

	self._draft = { Id = itemId, X = x, Z = z, R = rotation, Index = index, Purchase = purchase == true }
	self._panel.Visible = false
	self._bar.Visible = true
	self._okButton.Text = purchase
		and self._bilingual("BUY & PLACE", "ซื้อและวาง")
		or self._bilingual(index and "SAVE MOVE" or "PLACE", index and "บันทึกตำแหน่ง" or "วาง")
	self:_updateGhost()
	return true
end

function FurnitureShop:_nudge(dx, dz)
	if not self._draft or self._committing then
		return
	end
	self._draft.X += dx * Placement.GRID
	self._draft.Z += dz * Placement.GRID
	self:_updateGhost()
end

--[[
	Redraws the ghost and colours it by whether the square is legal.

	This asks the same Placement module the server will ask, so the preview and
	the verdict agree. The server is still the authority: it re-checks on commit.
]]
function FurnitureShop:_updateGhost()
	local draft = self._draft
	local base = self:_homeCFrame()
	if not draft or not base then
		return
	end

	if not self._ghost or self._ghost.Name ~= draft.Id then
		if self._ghost then
			self._ghost:Destroy()
		end
		self._ghost = buildModel(draft.Id)
		if self._ghost then
			self._ghost.Parent = workspace
		end
	end
	if not self._ghost then
		return
	end

	local placed = self._state.Home.Furniture
	local ok, reason = Placement.canPlace(placed, draft.Id, draft.X, draft.Z, draft.R, draft.Index)

	local floorY = Furniture.isOutdoor(draft.Id) and -1 or 0
	self._ghost:PivotTo(base * CFrame.new(draft.X, floorY, draft.Z) * CFrame.Angles(0, math.rad(draft.R), 0))

	local tint = ok and Color3.fromRGB(120, 220, 150) or Color3.fromRGB(235, 120, 120)
	for _, part in ipairs(self._ghost:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.45
			part.Color = tint
			part.Material = Enum.Material.Neon
		end
	end

	local item = Furniture.get(draft.Id)
	local confirmEnglish = draft.Purchase and "tap BUY & PLACE" or "tap PLACE"
	local confirmThai = draft.Purchase and "แตะ ซื้อและวาง" or "แตะ วาง"
	self._hint.Text = ok
		and self._bilingual(string.format("%s  -  %s", item.Name, confirmEnglish), string.format("%s  -  %s", item.NameThai, confirmThai))
		or self._bilingual(reason or "Cannot go there", "วางตรงนี้ไม่ได้")
	self._okButton.BackgroundColor3 = ok and self._theme.Colors.Leaf or self._theme.Colors.White
	self._okActive = ok
end

function FurnitureShop:_commit()
	local draft = self._draft
	if not draft or not self._okActive or self._committing then
		return
	end
	local action
	local payload
	if draft.Index then
		action = "MoveFurniture"
		payload = { index = draft.Index, x = draft.X, z = draft.Z, r = draft.R }
	elseif draft.Purchase then
		action = "BuyFurniture"
		payload = { item = draft.Id, x = draft.X, z = draft.Z, r = draft.R }
	else
		action = "PlaceFurniture"
		payload = { item = draft.Id, x = draft.X, z = draft.Z, r = draft.R }
	end

	self._committing = true
	self._okActive = false
	self._okButton.BackgroundColor3 = self._theme.Colors.White
	self._hint.Text = self._bilingual("Confirming...", "กำลังยืนยัน...")
	self._onAction(action, payload, function(ok)
		self._committing = false
		if ok then
			self:_endPlacement()
		else
			self:_updateGhost()
		end
	end)
end

--[[ Always tears the ghost down: a leaked ghost is a part that never goes away. ]]
function FurnitureShop:_endPlacement()
	self._draft = nil
	self._okActive = false
	self._committing = false
	if self._ghost then
		self._ghost:Destroy()
		self._ghost = nil
	end
	if self._bar then
		self._bar.Visible = false
	end
end

function FurnitureShop:_cancelPlacement()
	if self._committing then
		return
	end
	local draft = self._draft
	local wasPurchase = draft and draft.Purchase
	local itemId = draft and draft.Id
	self:_endPlacement()
	if wasPurchase then
		self._onAction("CancelFurniturePurchase", { item = itemId })
	end
end

--[[ Reserve one purchase flow, then show the ghost without spending coins. ]]
function FurnitureShop:_startPurchase(itemId)
	if self._draft or self._purchaseStarting or self._committing then
		return
	end
	self._purchaseStarting = true
	self._onAction("BeginFurniturePurchase", { item = itemId }, function(ok)
		self._purchaseStarting = false
		if ok and not self:BeginPlacement(itemId, nil, true) then
			self._onAction("CancelFurniturePurchase", { item = itemId })
		end
	end)
end

--[[ Cards ------------------------------------------------------------------- ]]

--[[ A rotating 3D preview of the real model, so nobody buys a surprise. ]]
function FurnitureShop:_preview(parent, itemId)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundColor3 = Color3.fromRGB(250, 247, 241)
	viewport.Position = UDim2.fromOffset(8, 8)
	viewport.Size = UDim2.fromOffset(76, 76)
	viewport.Parent = parent
	self._components.corner(viewport, self._theme.SmallCorner)

	local model = buildModel(itemId)
	if not model then
		return viewport
	end
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local _, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z) * 1.7 + 3

	-- Turn slowly so the shape reads. One connection per card, dropped with the card.
	local angle = 0
	local spin
	spin = RunService.RenderStepped:Connect(function(deltaTime)
		if not viewport.Parent then
			spin:Disconnect()
			return
		end
		angle += deltaTime * 0.7
		local centre = model:GetBoundingBox()
		camera.CFrame = CFrame.new(centre.Position + Vector3.new(math.sin(angle) * reach, reach * 0.55, math.cos(angle) * reach))
		camera.CFrame = CFrame.lookAt(camera.CFrame.Position, centre.Position)
	end)
	return viewport
end

function FurnitureShop:_render()
	local state = self._state
	if not state or not state.Home then
		return
	end

	for _, child in ipairs(self._list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local theme = self._theme
	for id, button in pairs(self._tabButtons) do
		button.BackgroundColor3 = (id == self._tab) and theme.Colors.Water or theme.Colors.White
		button.TextColor3 = theme.textOn(button.BackgroundColor3)
	end
	for id, button in pairs(self._filterButtons) do
		button.BackgroundColor3 = (id == self._category) and theme.Colors.Leaf or theme.Colors.White
	end
	self._searchBox.Visible = self._tab == "Shop"
	self._filter.Visible = self._tab == "Shop"
	self._list.Position = UDim2.fromOffset(14, self._tab == "Shop" and 186 or 100)
	self._list.Size = UDim2.new(1, -28, 1, self._tab == "Shop" and -200 or -114)

	if self._tab == "Shop" then
		self:_renderShop(state)
	else
		self:_renderHome(state)
	end
end

function FurnitureShop:_renderShop(state)
	local theme = self._theme
	local favorites = state.Home.Favorites or {}
	local shown = 0

	for _, itemId in ipairs(Furniture.Order) do
		local item = Furniture.Items[itemId]
		local matchesCategory = self._category == "All"
			or (self._category == "Favorites" and favorites[itemId])
			or item.Category == self._category
		local matchesSearch = self._search == ""
			or string.find(string.lower(item.Name), self._search, 1, true) ~= nil
			or string.find(string.lower(item.NameThai), self._search, 1, true) ~= nil

		if matchesCategory and matchesSearch then
			shown += 1
			self:_itemCard(state, itemId, item, favorites[itemId] == true)
		end
	end

	if shown == 0 then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.Parent = self._list
		self._components.label(empty, self._bilingual("Nothing matches that.", "ไม่พบสิ่งที่ค้นหา"), UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 12, true)
	end
end

function FurnitureShop:_itemCard(state, itemId, item, favorite)
	local theme = self._theme
	local rarity = Furniture.Rarities[item.Rarity]
	local owned = (state.Home.OwnedFurniture and state.Home.OwnedFurniture[itemId]) or 0
	local affordable = (state.Coins or 0) >= item.Price

	local card = Instance.new("Frame")
	card.BackgroundColor3 = theme.Colors.White
	card.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
	card.Parent = self._list
	self._components.corner(card, theme.SmallCorner)

	-- Rarity is a stripe down the edge of the card.
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = rarity.Color
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(0, 6, 1, 0)
	stripe.Parent = card
	self._components.corner(stripe, theme.SmallCorner)

	self:_preview(card, itemId)

	local name = self._components.label(card, self._bilingual(item.Name, item.NameThai), UDim2.new(1, -230, 0, 34), UDim2.fromOffset(92, 6), 12, true)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local detail = self._components.label(
		card,
		string.format("%s  -  %d coins%s", rarity.Name, item.Price, owned > 0 and string.format("  -  owned %d", owned) or ""),
		UDim2.new(1, -230, 0, 20),
		UDim2.fromOffset(92, 40),
		10,
		false
	)
	detail.TextColor3 = rarity.Color
	detail.TextXAlignment = Enum.TextXAlignment.Left

	local star = Instance.new("TextButton")
	star.AnchorPoint = Vector2.new(1, 0)
	star.AutoButtonColor = false
	star.BackgroundColor3 = favorite and theme.Colors.Sun or theme.Colors.Surface
	star.Position = UDim2.new(1, -8, 0, 8)
	star.Size = UDim2.fromOffset(40, 34)
	star.Font = Enum.Font.GothamBold
	star.Text = "\u{2605}"
	-- A favourited star sits on amber, which white cannot be read on.
	star.TextColor3 = favorite and theme.textOn(theme.Colors.Sun) or theme.Colors.Muted
	star.TextSize = 16
	star.Parent = card
	self._components.corner(star, theme.SmallCorner)
	star.Activated:Connect(function()
		self._onAction("FavoriteFurniture", { item = itemId })
	end)

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.AutoButtonColor = false
	buy.BackgroundColor3 = affordable and theme.Colors.Leaf or theme.Colors.Surface
	buy.Position = UDim2.new(1, -8, 1, -8)
	buy.Size = UDim2.fromOffset(114, 38)
	buy.Font = Enum.Font.GothamBold
	buy.Text = affordable
		and self._bilingual("BUY & PLACE", "ซื้อและวาง")
		or self._bilingual("NEED COINS", "เหรียญไม่พอ")
	buy.TextColor3 = affordable and theme.textOn(theme.Colors.Leaf) or theme.Colors.Muted
	buy.TextSize = 10
	buy.TextWrapped = true
	buy.Parent = card
	self._components.corner(buy, theme.SmallCorner)
	if affordable then
		buy.Activated:Connect(function()
			self:_startPurchase(itemId)
		end)
	end
end

--[[ MY HOME: what is placed, and what is still boxed up. ]]
function FurnitureShop:_renderHome(state)
	local theme = self._theme
	local placed = state.Home.Furniture or {}

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 26)
	header.Parent = self._list
	local headerLabel = self._components.label(header, self._bilingual(
		string.format("Placed: %d / %d", #placed, Config.MaxFurniture),
		string.format("วางแล้ว: %d / %d", #placed, Config.MaxFurniture)
	), UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 11, true)
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left

	for index, entry in ipairs(placed) do
		local item = Furniture.get(entry.Id)
		if item then
			local row = Instance.new("Frame")
			row.BackgroundColor3 = theme.Colors.White
			row.Size = UDim2.new(1, 0, 0, 58)
			row.Parent = self._list
			self._components.corner(row, theme.SmallCorner)

			local label = self._components.label(row, self._bilingual(item.Name, item.NameThai), UDim2.new(1, -200, 1, 0), UDim2.fromOffset(12, 0), 11, true)
			label.TextXAlignment = Enum.TextXAlignment.Left

			local function rowButton(text, offsetX, color, callback)
				local button = Instance.new("TextButton")
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.AutoButtonColor = false
				button.BackgroundColor3 = color
				button.Position = UDim2.new(1, offsetX, 0.5, 0)
				button.Size = UDim2.fromOffset(58, 40)
				button.Font = Enum.Font.GothamBold
				button.Text = text
				button.TextColor3 = theme.Colors.Ink
				button.TextSize = 10
				button.Parent = row
				self._components.corner(button, theme.SmallCorner)
				button.Activated:Connect(callback)
			end

			rowButton(self._bilingual("MOVE", "ย้าย"), -128, theme.Colors.Sun, function()
				self:BeginPlacement(entry.Id, index)
			end)
			rowButton(self._bilingual("TURN", "หมุน"), -68, theme.Colors.Leaf, function()
				self._onAction("MoveFurniture", {
					index = index,
					x = entry.X,
					z = entry.Z,
					r = Placement.normaliseRotation((entry.R or 0) + 90),
				})
			end)
			rowButton(self._bilingual("PACK", "เก็บ"), -8, theme.Colors.Primary, function()
				self._onAction("RemoveFurniture", { index = index })
			end)
		end
	end

	-- Anything owned but not out yet can be placed by hand.
	local boxed = {}
	for itemId, count in pairs(state.Home.OwnedFurniture or {}) do
		local out = 0
		for _, entry in ipairs(placed) do
			if entry.Id == itemId then
				out += 1
			end
		end
		if count > out then
			boxed[itemId] = count - out
		end
	end

	for itemId, spare in pairs(boxed) do
		local item = Furniture.get(itemId)
		if item then
			local row = Instance.new("Frame")
			row.BackgroundColor3 = theme.Colors.Surface
			row.Size = UDim2.new(1, 0, 0, 52)
			row.Parent = self._list
			self._components.corner(row, theme.SmallCorner)

			local label = self._components.label(row, self._bilingual(
				string.format("%s  (%d in your box)", item.Name, spare),
				string.format("%s  (ในกล่อง %d ชิ้น)", item.NameThai, spare)
			), UDim2.new(1, -110, 1, 0), UDim2.fromOffset(12, 0), 11, true)
			label.TextXAlignment = Enum.TextXAlignment.Left

			local place = Instance.new("TextButton")
			place.AnchorPoint = Vector2.new(1, 0.5)
			place.AutoButtonColor = false
			place.BackgroundColor3 = theme.Colors.Leaf
			place.Position = UDim2.new(1, -8, 0.5, 0)
			place.Size = UDim2.fromOffset(90, 38)
			place.Font = Enum.Font.GothamBold
			place.Text = self._bilingual("PLACE", "วาง")
			place.TextColor3 = theme.textOn(theme.Colors.Leaf)
			place.TextSize = 11
			place.Parent = row
			self._components.corner(place, theme.SmallCorner)
			place.Activated:Connect(function()
				self:BeginPlacement(itemId, nil)
			end)
		end
	end
end

return FurnitureShop
