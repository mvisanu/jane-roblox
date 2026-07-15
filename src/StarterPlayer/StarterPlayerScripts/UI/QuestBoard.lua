--[[
	Quest board.

	Stays at the upper-left in both states: a compact header while hidden and a
	half-size scrolling window while open. It never jumps into the screen centre. It
	shows the daily quest, then the chain the player is
	working through: every step in order, which one is live, and what each pays.

	When a chain's last step lands the server banks a chest, and the board turns
	gold until the player opens it. That press is the point of the whole chain,
	so it is the loudest thing on the board.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CampPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CampPlan"))
local QuestBoardLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestBoardLayout"))
local Iconography = require(script.Parent:WaitForChild("Iconography"))

local QuestBoard = {}
QuestBoard.__index = QuestBoard

local CLOSED_HEIGHT = QuestBoardLayout.CLOSED_HEIGHT

function QuestBoard.new(parent, theme, components, catalog, config, bilingual, onAction, onNavigate, onOpenChanged)
	local self = setmetatable({}, QuestBoard)
	self._theme = theme
	self._components = components
	self._catalog = catalog
	self._config = config
	self._bilingual = bilingual
	self._onAction = onAction
	self._onNavigate = onNavigate
	self._onOpenChanged = onOpenChanged
	self._open = false
	self._stepRows = {}
	self._parent = parent

	local panel = Instance.new("Frame")
	panel.Name = "QuestBoard"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.BackgroundColor3 = theme.Colors.Surface
	panel.Position = UDim2.fromOffset(QuestBoardLayout.MARGIN, QuestBoardLayout.TOP_SAFE)
	panel.Size = UDim2.fromOffset(QuestBoardLayout.CLOSED_WIDTH, CLOSED_HEIGHT)
	panel.Parent = parent
	components.corner(panel, theme.SmallCorner)
	components.stroke(panel, theme.Colors.Border, 1)
	components.shadow(panel)
	self._panel = panel

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.AutoButtonColor = false
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)
	header.Text = ""
	header.Parent = panel
	self._header = header

	local questIcon = Iconography.create(header, "Quest", theme.Colors.Primary, 32)
	questIcon.Position = UDim2.fromOffset(14, 13)
	self._questIcon = questIcon

	local title = components.label(header, bilingual("QUESTS", "ภารกิจ"), UDim2.new(1, -160, 1, 0), UDim2.fromOffset(54, 0), QuestBoardLayout.HEADER_TEXT_SIZE, true)
	title.TextColor3 = theme.Colors.Ink
	title.TextXAlignment = Enum.TextXAlignment.Left
	self._title = title

	local toggle = Instance.new("TextLabel")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.BackgroundColor3 = theme.Colors.White
	toggle.Position = UDim2.new(1, -12, 0.5, 0)
	toggle.Size = UDim2.fromOffset(92, 42)
	toggle.Font = Enum.Font.GothamBold
	toggle.Text = bilingual("OPEN", "เปิด")
	toggle.TextColor3 = theme.Colors.Ink
	toggle.TextSize = QuestBoardLayout.TOGGLE_TEXT_SIZE
	toggle.Parent = header
	components.corner(toggle, theme.SmallCorner)
	components.stroke(toggle, theme.Colors.Border, 1)
	self._toggle = toggle

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Active = true
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.Position = UDim2.fromOffset(QuestBoardLayout.BODY_PADDING, CLOSED_HEIGHT)
	body.ScrollBarImageColor3 = theme.Colors.Water
	body.ScrollBarThickness = 7
	body.Size = UDim2.new(1, -QuestBoardLayout.BODY_PADDING * 2, 1, -CLOSED_HEIGHT - QuestBoardLayout.BODY_PADDING)
	body.Visible = false
	body.Parent = panel
	self._body = body
	components.list(body, 12)

	header.Activated:Connect(function()
		self:SetOpen(not self._open)
	end)
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout(false)
	end)
	self:_layout(false)

	return self
end

function QuestBoard:_layout(animate)
	local screen = self._parent.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	local geometry = self._open and QuestBoardLayout.open(screen.X, screen.Y)
		or QuestBoardLayout.closed(screen.X, screen.Y)
	local headerHeight = self._open and QuestBoardLayout.OPEN_HEADER_HEIGHT or CLOSED_HEIGHT
	local compactHeader = self._open and geometry.Width < 260
	self._header.Size = UDim2.new(1, 0, 0, headerHeight)
	self._body.Position = UDim2.fromOffset(QuestBoardLayout.BODY_PADDING, headerHeight)
	self._body.Size = UDim2.new(
		1,
		-QuestBoardLayout.BODY_PADDING * 2,
		1,
		-headerHeight - QuestBoardLayout.BODY_PADDING
	)
	self._questIcon.Visible = not compactHeader
	if compactHeader then
		self._title.Position = UDim2.fromOffset(8, 0)
		self._title.Size = UDim2.new(1, -72, 1, 0)
		self._toggle.Position = UDim2.new(1, -6, 0.5, 0)
		self._toggle.Size = UDim2.fromOffset(56, 34)
	else
		self._title.Position = UDim2.fromOffset(54, 0)
		self._title.Size = UDim2.new(1, -160, 1, 0)
		self._toggle.Position = UDim2.new(1, -12, 0.5, 0)
		self._toggle.Size = UDim2.fromOffset(92, 42)
	end
	local properties = {
		Position = UDim2.fromOffset(geometry.X, geometry.Y),
		Size = UDim2.fromOffset(geometry.Width, geometry.Height),
	}
	if animate then
		TweenService:Create(self._panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
	else
		self._panel.Position = properties.Position
		self._panel.Size = properties.Size
	end
end

function QuestBoard:SetOpen(open)
	self._open = open
	self._body.Visible = open
	self._toggle.Text = open and self._bilingual("CLOSE", "ปิด") or self._bilingual("OPEN", "เปิด")
	self:_layout(true)
	if self._onOpenChanged then
		self._onOpenChanged(open)
	end
end

function QuestBoard:_card(color)
	local card = Instance.new("Frame")
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = color or self._theme.Colors.White
	card.Size = UDim2.new(1, 0, 0, 0)
	card.Parent = self._body
	self._components.corner(card, self._theme.SmallCorner)
	self._components.stroke(card, self._theme.Colors.Border, 1)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = card
	return card
end

function QuestBoard:_text(parent, text, size, bold, color)
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Size = UDim2.new(1, 0, 0, 0)
	label.Text = text
	label.TextColor3 = color or self._theme.Colors.Ink
	label.TextSize = size or QuestBoardLayout.BODY_TEXT_SIZE
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

--[[ A progress bar, so a step reads at a glance rather than as a fraction. ]]
function QuestBoard:_bar(parent, fraction, color)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = self._theme.Colors.Surface
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Parent = parent
	self._components.corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color or self._theme.Colors.Leaf
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.Parent = track
	self._components.corner(fill, UDim.new(1, 0))
	return track
end

function QuestBoard:_navigateButton(parent, kind)
	if not self._onNavigate then
		return nil
	end
	local button = Instance.new("TextButton")
	button.Name = kind .. "WaypointButton"
	button.AutoButtonColor = true
	button.BackgroundColor3 = self._theme.Colors.PrimaryDark
	button.Font = Enum.Font.GothamBold
	button.Size = UDim2.new(1, 0, 0, 50)
	button.Text = self._bilingual("SHOW GROUND PATH", "แสดงเส้นทางบนพื้น")
	button.TextColor3 = self._theme.textOn(button.BackgroundColor3)
	button.TextSize = QuestBoardLayout.BUTTON_TEXT_SIZE
	button.TextWrapped = true
	button.Parent = parent
	self._components.corner(button, self._theme.SmallCorner)
	button.Activated:Connect(function()
		self._onNavigate(kind)
	end)
	return button
end

--[[
	One line of the camp shopping list: picture, name, and how many of it.

	The picture is the point. A five-year-old who cannot read "Cave Crystal" can
	still see that the quest wants the same sparkly thing that is sitting in their
	bag, and that they have 4 of the 6 it asks for.
]]
function QuestBoard:_requirementRow(parent, item, order)
	local theme = self._theme

	local row = Instance.new("Frame")
	row.BackgroundColor3 = item.Met and theme.Colors.Leaf or theme.Colors.White
	row.BackgroundTransparency = item.Met and 0.82 or 0
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 46)
	row.Parent = parent
	self._components.corner(row, theme.SmallCorner)

	-- The icon sits on a tile of the resource's own colour, so the same wood-brown
	-- chip means "wood" on the quest, in the bag, and on the camp button.
	local tile = Instance.new("TextLabel")
	tile.BackgroundColor3 = item.Color
	tile.Font = Enum.Font.GothamBold
	tile.Position = UDim2.fromOffset(6, 6)
	tile.Size = UDim2.fromOffset(34, 34)
	tile.Text = item.Icon
	tile.TextColor3 = theme.textOn(item.Color)
	tile.TextSize = 22
	tile.Parent = row
	self._components.corner(tile, UDim.new(0, 8))

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamMedium
	name.Position = UDim2.fromOffset(48, 0)
	name.Size = UDim2.new(1, -126, 1, 0)
	name.Text = self._bilingual(item.Name, item.NameThai)
	name.TextColor3 = theme.Colors.Ink
	name.TextSize = QuestBoardLayout.SMALL_TEXT_SIZE
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	-- "6 / 6 ✓" when it is done, "4 / 6" while it is not: the same two numbers in
	-- the same place either way, so the child watches one of them climb.
	local count = Instance.new("TextLabel")
	count.AnchorPoint = Vector2.new(1, 0.5)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.Position = UDim2.new(1, -8, 0.5, 0)
	count.Size = UDim2.fromOffset(74, 28)
	count.Text = item.Met
		and string.format("%d / %d  ✓", item.Have, item.Need)
		or string.format("%d / %d", item.Have, item.Need)
	count.TextColor3 = item.Met and theme.Colors.Primary or theme.Colors.Ink
	count.TextSize = QuestBoardLayout.BUTTON_TEXT_SIZE
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = row

	return row
end

--[[
	The camp shopping list, drawn under the "Upgrade your camp" step.

	This is the whole reason the board exists in this shape: the step used to say
	"Upgrade your camp" and stop, so a player at Level 5 could not find out what
	the Adventure Center wanted without failing the build and reading the error.
]]
function QuestBoard:_campRequirements(card, state, order)
	local adventure = state.Adventure
	if not adventure then
		return
	end
	local plan = CampPlan.requirements(adventure.CampLevel, adventure.Resources)
	if not plan then
		return
	end
	local theme = self._theme

	self:_text(card, self._bilingual(
		string.format("Bring these to build the %s:", plan.Name),
		string.format("เก็บของเหล่านี้เพื่อสร้าง%s:", plan.NameThai)
	), QuestBoardLayout.SECTION_TEXT_SIZE, true, theme.Colors.Muted).LayoutOrder = order

	local list = Instance.new("Frame")
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.LayoutOrder = order + 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, item in ipairs(plan.Items) do
		self:_requirementRow(list, item, index)
	end

	-- Where the missing thing comes from, so "go and get it" has an address.
	for _, item in ipairs(plan.Items) do
		if not item.Met then
			self:_text(card, self._bilingual(
				string.format("Find %s in the %s.", item.Name, item.FoundIn),
				string.format("หา%sได้ที่%s", item.NameThai, item.FoundInThai)
			), QuestBoardLayout.SMALL_TEXT_SIZE, false, theme.Colors.Muted).LayoutOrder = order + 2
			break
		end
	end

	if plan.Ready then
		self:_text(card, self._bilingual(
			"You have everything! Open Adventure and build it.",
			"คุณมีของครบแล้ว! เปิดเมนูผจญภัยแล้วสร้างได้เลย"
		), QuestBoardLayout.SECTION_TEXT_SIZE, true, theme.Colors.Primary).LayoutOrder = order + 3
	end
end

--[[ Redraws the board from the authoritative state the server sent. ]]
function QuestBoard:Update(state)
	if type(state) ~= "table" or type(state.Quests) ~= "table" then
		return
	end
	local quests = state.Quests
	local theme = self._theme

	for _, child in ipairs(self._body:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- A waiting chest turns the whole board gold, even while it is closed.
	local chestReady = (quests.PendingBonus or 0) > 0
	self._panel.BackgroundColor3 = chestReady and theme.Colors.Sun or theme.Colors.Surface
	self._title.Text = chestReady
		and self._bilingual("CHEST READY!", "หีบรางวัลพร้อมแล้ว!")
		or self._bilingual("QUESTS", "ภารกิจ")

	if chestReady then
		local chest = self:_card(theme.Colors.Sun)
		self:_text(chest, self._bilingual(
			string.format("A %d coin chest is waiting!", quests.PendingBonus),
			string.format("หีบรางวัล %d เหรียญรออยู่!", quests.PendingBonus)
		), QuestBoardLayout.PROMINENT_TEXT_SIZE, true)

		local claim = Instance.new("TextButton")
		claim.AutoButtonColor = false
		claim.BackgroundColor3 = theme.Colors.Leaf
		claim.Font = Enum.Font.GothamBold
		claim.Size = UDim2.new(1, 0, 0, theme.TouchHeight)
		claim.Text = self._bilingual("OPEN THE CHEST", "เปิดหีบรางวัล")
		claim.TextColor3 = theme.textOn(theme.Colors.Leaf)
		claim.TextSize = QuestBoardLayout.PROMINENT_TEXT_SIZE
		claim.Parent = chest
		self._components.corner(claim, theme.SmallCorner)
		claim.Activated:Connect(function()
			self._onAction("ClaimChainBonus", {})
		end)
	end

	-- Today's quest.
	local daily = state.Daily and state.Daily.Quest
	if daily then
		local card = self:_card()
		self:_text(card, self._bilingual("TODAY", "วันนี้"), QuestBoardLayout.SECTION_TEXT_SIZE, true, theme.Colors.Muted)
		self:_text(card, self._bilingual(daily.Description, daily.DescriptionThai or daily.Description), QuestBoardLayout.PROMINENT_TEXT_SIZE, true)
		self:_bar(card, (daily.Progress or 0) / math.max(daily.Target or 1, 1), theme.Colors.Water)
		self:_text(card, daily.Completed
			and self._bilingual("Done!", "สำเร็จแล้ว!")
			or string.format("%d / %d", daily.Progress or 0, daily.Target or 1), QuestBoardLayout.SECTION_TEXT_SIZE, false, theme.Colors.Muted)
		if not daily.Completed then
			self:_navigateButton(card, "Daily")
		end
	end

	local chain = self._catalog.QuestChains[quests.ChainIndex]
	if not chain then
		local done = self:_card(theme.Colors.Leaf)
		self:_text(done, self._bilingual("The Wildwood story is complete!", "เรื่องราวแห่งไวลด์วูดสำเร็จแล้ว!"), QuestBoardLayout.PROMINENT_TEXT_SIZE, true, theme.Colors.White)
		self:_text(done, self._bilingual(
			string.format("You earned %d coins from quests.", quests.TotalEarned or 0),
			string.format("คุณได้รับ %d เหรียญจากภารกิจ", quests.TotalEarned or 0)
		), QuestBoardLayout.BODY_TEXT_SIZE, false, theme.Colors.White)
		return
	end

	local card = self:_card()
	self:_text(card, self._bilingual(
		string.format("CHAPTER %d OF %d", quests.ChainIndex, #self._catalog.QuestChains),
		string.format("บทที่ %d จาก %d", quests.ChainIndex, #self._catalog.QuestChains)
	), QuestBoardLayout.SECTION_TEXT_SIZE, true, theme.Colors.Muted)
	self:_text(card, self._bilingual(chain.Name, chain.NameThai), QuestBoardLayout.TITLE_TEXT_SIZE, true, theme.Colors.PrimaryDark)
	self:_text(card, self._bilingual(chain.Blurb, chain.BlurbThai), QuestBoardLayout.BODY_TEXT_SIZE, false, theme.Colors.Muted)

	-- Every step, so the player can see what is coming and what it pays.
	for index, step in ipairs(chain.Steps) do
		local done = index < quests.Step
		local active = index == quests.Step
		local row = Instance.new("Frame")
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = active and theme.Colors.Surface or theme.Colors.White
		row.BackgroundTransparency = active and 0 or 0.45
		row.LayoutOrder = index + 10
		row.Size = UDim2.new(1, 0, 0, 0)
		row.Parent = card
		self._components.corner(row, theme.SmallCorner)

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.Parent = row
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 10)
		padding.PaddingBottom = UDim.new(0, 10)
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)
		padding.Parent = row

		local mark = done and "[x]" or (active and "[>]" or "[ ]")
		local tone = done and theme.Colors.Leaf or (active and theme.Colors.Ink or theme.Colors.Muted)
		self:_text(row, string.format("%s  %s", mark, self._bilingual(step.Description, step.DescriptionThai)), QuestBoardLayout.STEP_TEXT_SIZE, active, tone)
		self:_text(row, self._bilingual(
			string.format("Reward %d coins", step.Reward),
			string.format("รางวัล %d เหรียญ", step.Reward)
		), QuestBoardLayout.SECTION_TEXT_SIZE, false, theme.Colors.Muted)

		if active then
			self:_bar(row, (quests.Progress or 0) / math.max(step.Target, 1), theme.Colors.Leaf)
			self:_text(row, string.format("%d / %d", quests.Progress or 0, step.Target), QuestBoardLayout.SECTION_TEXT_SIZE, true, theme.Colors.Muted)
			if step.Hint then
				self:_text(row, self._bilingual(
					string.format("TIP: %s", step.Hint),
					string.format("คำใบ้: %s", step.HintThai or step.Hint)
				), QuestBoardLayout.SECTION_TEXT_SIZE, false, theme.Colors.PrimaryDark)
			end
			self:_navigateButton(row, "Chain")
			-- "Upgrade your camp" is the one step whose work happens somewhere else
			-- entirely: it is not done by tapping this board, it is done by carrying
			-- the right things home. So this is where the list of them belongs.
			if step.Action == "AdventureUpgradeCamp" then
				self:_campRequirements(row, state, 20)
			end
		end
	end

	local prize = self:_card(theme.Colors.White)
	self:_text(prize, self._bilingual(
		string.format("Finish the chapter: %d coin chest", chain.Bonus),
		string.format("จบบท: หีบรางวัล %d เหรียญ", chain.Bonus)
	), QuestBoardLayout.STEP_TEXT_SIZE, true, theme.Colors.PrimaryDark)
	self:_text(prize, self._bilingual(
		string.format("Earned from quests so far: %d coins", quests.TotalEarned or 0),
		string.format("ได้รับจากภารกิจแล้ว: %d เหรียญ", quests.TotalEarned or 0)
	), QuestBoardLayout.SECTION_TEXT_SIZE, false, theme.Colors.Muted)

	self:_shop(state)
end

--[[
	The Robux shop.

	Nothing here sells quest progress: coins buy furniture and seeds, and the
	supporter pass is a golden lantern. A chest still has to be earned. The whole
	section stays hidden until real product ids are set in Config.Monetization.
]]
function QuestBoard:_shop(state)
	local monetization = self._config.Monetization
	local theme = self._theme
	local player = Players.LocalPlayer

	local packs = {}
	for _, pack in ipairs(monetization.CoinPacks) do
		if pack.ProductId > 0 then
			table.insert(packs, pack)
		end
	end
	local supporterId = monetization.SupporterPassId
	if #packs == 0 and supporterId <= 0 then
		return
	end

	local card = self:_card(theme.Colors.White)
	self:_text(card, self._bilingual("COIN SHOP", "ร้านค้าเหรียญ"), QuestBoardLayout.SECTION_TEXT_SIZE, true, theme.Colors.Muted)

	for index, pack in ipairs(packs) do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = theme.Colors.Sun
		button.Font = Enum.Font.GothamBold
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 54)
		button.Text = self._bilingual(
			string.format("%s  +%d coins  -  R$%d", pack.Name, pack.Coins, pack.Robux),
			string.format("%s  +%d เหรียญ  -  R$%d", pack.NameThai, pack.Coins, pack.Robux)
		)
		button.TextColor3 = theme.Colors.Ink
		button.TextSize = QuestBoardLayout.BUTTON_TEXT_SIZE
		button.TextWrapped = true
		button.Parent = card
		self._components.corner(button, theme.SmallCorner)
		button.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, pack.ProductId)
		end)
	end

	if supporterId > 0 then
		local owned = state.Shop and state.Shop.Supporter
		local pass = Instance.new("TextButton")
		pass.AutoButtonColor = false
		pass.BackgroundColor3 = owned and theme.Colors.Leaf or theme.Colors.PrimaryDark
		pass.Font = Enum.Font.GothamBold
		pass.LayoutOrder = 50
		pass.Size = UDim2.new(1, 0, 0, 54)
		pass.Text = owned
			and self._bilingual(
				string.format("%s  -  yours!", monetization.SupporterName),
				string.format("%s  -  เป็นของคุณแล้ว!", monetization.SupporterNameThai)
			)
			or self._bilingual(
				string.format("%s  -  R$%d", monetization.SupporterName, monetization.SupporterRobux),
				string.format("%s  -  R$%d", monetization.SupporterNameThai, monetization.SupporterRobux)
			)
		pass.TextColor3 = theme.textOn(pass.BackgroundColor3)
		pass.TextSize = QuestBoardLayout.BUTTON_TEXT_SIZE
		pass.TextWrapped = true
		pass.Parent = card
		self._components.corner(pass, theme.SmallCorner)
		if not owned then
			pass.Activated:Connect(function()
				MarketplaceService:PromptGamePassPurchase(player, supporterId)
			end)
		end
	end

	self:_text(card, self._bilingual(
		"Coins buy furniture and seeds. Quests are always earned, never bought.",
		"เหรียญใช้ซื้อเฟอร์นิเจอร์และเมล็ดพันธุ์ ภารกิจต้องทำเองเสมอ"
	), QuestBoardLayout.SMALL_TEXT_SIZE, false, theme.Colors.Muted)
end

return QuestBoard
