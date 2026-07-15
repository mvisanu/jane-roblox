local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local BagInventory = require(Shared:WaitForChild("BagInventory"))
local CampPlan = require(Shared:WaitForChild("CampPlan"))
local CafeMenu = require(Shared:WaitForChild("CafeMenu"))
local CafeModels = require(Shared:WaitForChild("CafeModels"))
local Config = require(Shared:WaitForChild("Config"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local UI = script.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components"))
local AvatarGrid = require(UI:WaitForChild("AvatarGrid"))
local BagGrid = require(UI:WaitForChild("BagGrid"))
local EnvironmentController = require(UI:WaitForChild("EnvironmentController"))
local Iconography = require(UI:WaitForChild("Iconography"))
local Theme = require(UI:WaitForChild("Theme"))
local Minimap = require(UI:WaitForChild("Minimap"))
local QuestBoard = require(UI:WaitForChild("QuestBoard"))
local QuestNavigator = require(UI:WaitForChild("QuestNavigator"))
local FurnitureShop = require(UI:WaitForChild("FurnitureShop"))
local HomePalette = require(UI:WaitForChild("HomePalette"))

local remoteFolder = ReplicatedStorage:WaitForChild(RemoteNames.Folder)
local requestRemote = remoteFolder:WaitForChild(RemoteNames.Request)
local stateChanged = remoteFolder:WaitForChild(RemoteNames.StateChanged)
local toastRemote = remoteFolder:WaitForChild(RemoteNames.Toast)

local state
local currentMenu = "Home"
local requestBusy = false
local navButtons = {}
local questBoard
local questNavigator
local furnitureShop
local environmentController = EnvironmentController.new()

local function bilingual(english, thai)
	return string.format("%s\n%s", thai, english)
end

local NAV_THAI = {
	Home = "บ้าน",
	Garden = "สวน",
	Pet = "สัตว์เลี้ยง",
	Cafe = "คาเฟ่",
	Style = "แต่งตัว",
	Map = "แผนที่",
	Adventure = "ผจญภัย",
	Bag = "กระเป๋า",
}

local DESTINATION_THAI = {
	Town = "กลางเมือง",
	Cafe = "คาเฟ่",
	PetShop = "ร้านสัตว์เลี้ยง",
	FlowerShop = "ร้านดอกไม้",
	Playground = "สนามเด็กเล่น",
	School = "โรงเรียน",
	Park = "สวนสาธารณะ",
	Lake = "ทะเลสาบ",
	Beach = "ชายหาด",
	Forest = "ป่า",
	AdventureCamp = "แคมป์ผจญภัย",
	WildwoodForest = "ป่าไวลด์วูด",
	Mountain = "ภูเขาแสงตะวัน",
	RiverAdventure = "แม่น้ำผจญภัย",
	MysteryCave = "ถ้ำลึกลับ",
}

local function homeColorInfo(name)
	for _, entry in ipairs(Config.HomeColors) do
		if entry.Name == name then
			return entry
		end
	end
	return Config.HomeColors[1]
end

local gui = Instance.new("ScreenGui")
gui.Name = "FamilyTownUI"
gui.DisplayOrder = 10
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.BackgroundTransparency = 1
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.new(1, -24, 0, 58)
topBar.Parent = gui

local coinsPill = Instance.new("Frame")
coinsPill.Name = "Coins"
coinsPill.BackgroundColor3 = Theme.Colors.White
coinsPill.Size = UDim2.fromOffset(140, 48)
coinsPill.Parent = topBar
Components.corner(coinsPill, Theme.SmallCorner)
Components.stroke(coinsPill, Theme.Colors.Border, 1)

local coinIcon = Iconography.create(coinsPill, "Coin", Theme.Colors.Sun, 30)
coinIcon.Position = UDim2.fromOffset(10, 9)
local coinsLabel = Components.label(coinsPill, "เหรียญ 500\nCoins 500", UDim2.new(1, -50, 1, 0), UDim2.fromOffset(46, 0), 11, true)
coinsLabel.TextColor3 = Theme.Colors.Ink

local giftButton = Instance.new("TextButton")
giftButton.Name = "DailyGift"
giftButton.AnchorPoint = Vector2.new(1, 0)
giftButton.AutoButtonColor = false
giftButton.BackgroundColor3 = Theme.Colors.White
giftButton.Position = UDim2.fromScale(1, 0)
giftButton.Size = UDim2.fromOffset(148, 48)
giftButton.Text = ""
giftButton.Parent = topBar
Components.corner(giftButton, Theme.SmallCorner)
local giftStroke = Components.stroke(giftButton, Theme.Colors.Border, 1)
local giftIcon = Iconography.create(giftButton, "Gift", Theme.Colors.PrimaryDark, 30)
giftIcon.Position = UDim2.fromOffset(10, 9)
local giftLabel = Components.label(giftButton, bilingual("DAILY GIFT", "ของขวัญรายวัน"), UDim2.new(1, -52, 1, 0), UDim2.fromOffset(46, 0), 9, true)
giftLabel.TextColor3 = Theme.Colors.Ink
giftLabel.TextXAlignment = Enum.TextXAlignment.Center

local labelsButton = Instance.new("TextButton")
labelsButton.Name = "LabelsToggle"
labelsButton.AnchorPoint = Vector2.new(0.5, 0)
labelsButton.AutoButtonColor = false
labelsButton.BackgroundColor3 = Theme.Colors.White
labelsButton.Position = UDim2.fromScale(0.5, 0)
labelsButton.Size = UDim2.fromOffset(116, 48)
labelsButton.Text = ""
labelsButton.Parent = topBar
Components.corner(labelsButton, Theme.SmallCorner)
local labelsStroke = Components.stroke(labelsButton, Theme.Colors.Border, 1)
local labelsIcon = Iconography.create(labelsButton, "Location", Theme.Colors.Primary, 28)
labelsIcon.Position = UDim2.fromOffset(9, 10)
local labelsLabel = Components.label(labelsButton, bilingual("NAMES", "ชื่อสถานที่"), UDim2.new(1, -46, 1, 0), UDim2.fromOffset(42, 0), 8, true)
labelsLabel.TextColor3 = Theme.Colors.Ink
labelsLabel.TextXAlignment = Enum.TextXAlignment.Center

-- The quest banner used to sit across the middle of the screen. Quests now live
-- on the compact board, which the player opens and closes.

--[[
	The activity panel opens from the bottom tab bar. Its requested home is the
	centre of the usable screen, with a larger reading width for Thai and English.
	It can still be dragged by its header when the player wants to see behind it.

	Every number behind that lives in Shared/HudLayout, which is plain Lua with no
	Roblox API in it, so `scripts/hud_layout_test.py` can prove across every
	viewport size that the panel stays centred and clear of both bars. This file
	does no layout arithmetic of its own; it just asks HudLayout and applies the
	answer, so what ships cannot drift from what the test checks.
]]
local panel = Instance.new("Frame")
panel.Name = "ActivityPanel"
panel.Active = true
panel.AnchorPoint = Vector2.new(0, 0)
panel.BackgroundColor3 = Theme.Colors.Surface
panel.Position = UDim2.fromOffset(HudLayout.MARGIN, HudLayout.TOP_SAFE)
panel.Size = UDim2.fromOffset(HudLayout.MIN_W, HudLayout.MIN_H)
panel.Visible = false
panel.Parent = gui
Components.corner(panel)
Components.stroke(panel, Theme.Colors.White, 3)
Components.shadow(panel)

-- Where the player has dragged the panel to, in pixels. Nil keeps the default
-- position responsive and centred as the viewport changes.
local panelOffset = nil

--[[ The panel's size on this screen, and the clamp, both straight from HudLayout. ]]
local function panelSize()
	local screen = gui.AbsoluteSize
	return HudLayout.panelSize(screen.X, screen.Y)
end

local function clampPanel(x, y)
	local screen = gui.AbsoluteSize
	local width, height = panelSize()
	return HudLayout.clamp(screen.X, screen.Y, width, height, x, y)
end


local function layoutPanel()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end

	local width, height = HudLayout.panelSize(screen.X, screen.Y)
	local x, y
	if panelOffset then
		x, y = HudLayout.clamp(screen.X, screen.Y, width, height, panelOffset.X, panelOffset.Y)
		panelOffset = Vector2.new(x, y)
	else
		x, y = HudLayout.center(screen.X, screen.Y, width, height)
	end

	panel.Size = UDim2.fromOffset(width, height)
	panel.Position = UDim2.fromOffset(x, y)

end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPanel)
layoutPanel()

local panelIcon = Iconography.create(panel, "Home", Theme.Colors.Primary, 32)
panelIcon.Position = UDim2.fromOffset(20, 17)
local panelTitle = Components.label(panel, "MY HOME", UDim2.new(1, -126, 0, 62), UDim2.fromOffset(62, 0), HudLayout.TITLE_TEXT_SIZE, true)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.AutoButtonColor = false
closeButton.BackgroundColor3 = Theme.Colors.White
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.fromOffset(44, 44)
closeButton.Text = ""
closeButton.Parent = panel
closeButton.ZIndex = 3
Components.corner(closeButton, UDim.new(1, 0))
Components.stroke(closeButton, Theme.Colors.Border, 1)
local closeIcon = Iconography.create(closeButton, "Close", Theme.Colors.Muted, 20)
closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
closeIcon.Position = UDim2.fromScale(0.5, 0.5)
closeIcon.ZIndex = 4

--[[
	Drag by the header.

	The handle is a transparent strip over the title only: it stops short of the
	close button, and it deliberately does not cover the body, because the body
	is a ScrollingFrame and a drag that started there would fight the scroll.

	`Active` makes the strip swallow the click so dragging the panel cannot also
	steer the camera behind it.
]]
local dragHandle = Instance.new("TextButton")
dragHandle.Name = "DragHandle"
dragHandle.Active = true
dragHandle.AutoButtonColor = false
dragHandle.BackgroundTransparency = 1
dragHandle.Text = ""
dragHandle.Position = UDim2.fromOffset(0, 0)
dragHandle.Size = UDim2.new(1, -76, 0, 60)
dragHandle.ZIndex = 2
dragHandle.Parent = panel

-- The little pill that says "you can move me".
local grip = Instance.new("Frame")
grip.Name = "Grip"
grip.AnchorPoint = Vector2.new(0.5, 0)
grip.BackgroundColor3 = Theme.Colors.Slate
grip.BackgroundTransparency = 0.55
grip.BorderSizePixel = 0
grip.Position = UDim2.new(0.5, 0, 0, 7)
grip.Size = UDim2.fromOffset(46, 5)
grip.ZIndex = 2
grip.Parent = panel
Components.corner(grip, UDim.new(1, 0))

local dragging = false
local dragFrom = nil
local dragStart = nil

dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	dragging = true
	dragFrom = input.Position
	dragStart = panel.AbsolutePosition
	TweenService:Create(grip, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
end)

local function endDrag()
	if not dragging then
		return
	end
	dragging = false
	dragFrom = nil
	TweenService:Create(grip, TweenInfo.new(0.16), { BackgroundTransparency = 0.55 }):Play()
end

dragHandle.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		endDrag()
	end
end)

-- Listening on the service, not the handle, so a fast drag that outruns the
-- pointer and leaves the strip does not drop the panel mid-move.
UserInputService.InputChanged:Connect(function(input)
	if not dragging or not dragFrom or not dragStart then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local delta = input.Position - dragFrom
	local x, y = clampPanel(dragStart.X + delta.X, dragStart.Y + delta.Y)
	panelOffset = Vector2.new(x, y)
	panel.Position = UDim2.fromOffset(x, y)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		endDrag()
	end
end)

-- Double-tap the header to send the panel back to the responsive centre.
local lastGripTap = 0
dragHandle.Activated:Connect(function()
	local now = os.clock()
	if now - lastGripTap < 0.35 then
		panelOffset = nil
		layoutPanel()
	end
	lastGripTap = now
end)

local divider = Instance.new("Frame")
divider.BackgroundColor3 = Theme.Colors.Slate
divider.BackgroundTransparency = 0.72
divider.BorderSizePixel = 0
divider.Position = UDim2.fromOffset(18, 60)
divider.Size = UDim2.new(1, -36, 0, 2)
divider.Parent = panel

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.CanvasSize = UDim2.fromOffset(0, 0)
body.Position = UDim2.fromOffset(18, 72)
body.ScrollBarImageColor3 = Theme.Colors.Slate
body.ScrollBarThickness = HudLayout.SCROLLBAR_THICKNESS
body.Size = UDim2.new(1, -36, 1, -88)
body.Parent = panel

local nav = Instance.new("ScrollingFrame")
nav.Name = "Navigation"
nav.AnchorPoint = Vector2.new(0.5, 1)
nav.AutomaticCanvasSize = Enum.AutomaticSize.X
nav.BackgroundColor3 = Theme.Colors.Surface
nav.BorderSizePixel = 0
nav.CanvasSize = UDim2.fromOffset(0, 0)
nav.Position = UDim2.new(0.5, 0, 1, -12)
nav.ScrollBarImageColor3 = Theme.Colors.Water
nav.ScrollBarThickness = 3
nav.ScrollingDirection = Enum.ScrollingDirection.X
nav.Size = UDim2.new(1, -24, 0, 82)
nav.Parent = gui
Components.corner(nav)
Components.stroke(nav, Theme.Colors.Border, 1)

local navConstraint = Instance.new("UISizeConstraint")
navConstraint.MaxSize = Vector2.new(840, 82)
navConstraint.Parent = nav

local navPadding = Instance.new("UIPadding")
navPadding.PaddingLeft = UDim.new(0, 8)
navPadding.PaddingRight = UDim.new(0, 8)
navPadding.PaddingTop = UDim.new(0, 7)
navPadding.PaddingBottom = UDim.new(0, 7)
navPadding.Parent = nav

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 6)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = nav

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.BackgroundColor3 = Theme.Colors.Ink
toast.BackgroundTransparency = 1
toast.Position = UDim2.new(0.5, 0, 1, -92)
toast.Size = UDim2.new(0.8, 0, 0, 52)
toast.Font = Enum.Font.GothamBold
toast.Text = ""
toast.TextColor3 = Theme.textOn(Theme.Colors.Ink)
toast.TextSize = 17
toast.TextTransparency = 1
toast.TextWrapped = true
toast.Visible = false
toast.ZIndex = 50
toast.Parent = gui
Components.corner(toast)
local toastConstraint = Instance.new("UISizeConstraint")
toastConstraint.MaxSize = Vector2.new(500, 52)
toastConstraint.Parent = toast

local loading = Components.label(gui, "กำลังโหลดเมืองแสนอบอุ่น...\nLoading your cozy town...", UDim2.new(1, -40, 0, 70), UDim2.new(0, 20, 0.5, -35), 16, true)
loading.TextXAlignment = Enum.TextXAlignment.Center
loading.ZIndex = 80

local onboarding = Instance.new("Frame")
onboarding.Name = "Welcome"
onboarding.BackgroundColor3 = Theme.Colors.Ink
onboarding.BackgroundTransparency = 0.28
onboarding.Size = UDim2.fromScale(1, 1)
onboarding.Visible = false
onboarding.ZIndex = 100
onboarding.Parent = gui

local welcomeCard = Instance.new("Frame")
welcomeCard.AnchorPoint = Vector2.new(0.5, 0.5)
welcomeCard.BackgroundColor3 = Theme.Colors.Surface
welcomeCard.Position = UDim2.fromScale(0.5, 0.5)
welcomeCard.Size = UDim2.new(0.86, 0, 0, 390)
welcomeCard.ZIndex = 101
welcomeCard.Parent = onboarding
Components.corner(welcomeCard, UDim.new(0, 24))
Components.stroke(welcomeCard, Theme.Colors.White, 4)
local welcomeConstraint = Instance.new("UISizeConstraint")
welcomeConstraint.MaxSize = Vector2.new(480, 390)
welcomeConstraint.Parent = welcomeCard

local welcomeTitle = Components.label(welcomeCard, "ยินดีต้อนรับสู่ Family Town!\nWelcome to Family Town!", UDim2.new(1, -40, 0, 74), UDim2.fromOffset(20, 16), 20, true)
welcomeTitle.TextColor3 = Theme.Colors.PrimaryDark
welcomeTitle.TextXAlignment = Enum.TextXAlignment.Center
local welcomeText = Components.label(
	welcomeCard,
	"1. เลือกสีบ้านและทำความรู้จักโมจิ\nChoose your cottage colour and meet Mochi.\n\n2. ปลูกสวนและเปิดคาเฟ่ใบจันทร์\nGrow a garden and open Moonleaf Cafe.\n\n3. ตามทางโคมไฟไปสร้างศูนย์ผจญภัย\nFollow the lantern trail to build the Adventure Center.",
	UDim2.new(1, -56, 0, 210),
	UDim2.fromOffset(28, 92),
	14,
	false
)
welcomeText.TextYAlignment = Enum.TextYAlignment.Top
welcomeText.ZIndex = 102

local startButton = Instance.new("TextButton")
startButton.AnchorPoint = Vector2.new(0.5, 1)
startButton.AutoButtonColor = false
startButton.BackgroundColor3 = Theme.Colors.Leaf
startButton.Position = UDim2.new(0.5, 0, 1, -24)
startButton.Size = UDim2.new(1, -56, 0, 62)
startButton.Font = Enum.Font.GothamBold
startButton.Text = bilingual("LET'S PLAY!", "เริ่มเล่น!")
startButton.TextColor3 = Theme.textOn(Theme.Colors.Leaf)
startButton.TextSize = 15
startButton.TextWrapped = true
startButton.ZIndex = 102
startButton.Parent = welcomeCard
Components.corner(startButton)
Components.stroke(startButton, Theme.Colors.White, 3)

local toastSequence = 0
local function showToast(message, good)
	if type(message) ~= "string" or message == "" or message == "Ready" then
		return
	end
	toastSequence += 1
	local sequence = toastSequence
	toast.Text = message
	toast.BackgroundColor3 = good == false and Theme.Colors.Berry or Theme.Colors.Ink
	toast.TextColor3 = Theme.textOn(toast.BackgroundColor3)
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.08, TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		if toastSequence == sequence and toast.Parent then
			local hide = TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextTransparency = 1 })
			hide:Play()
			hide.Completed:Wait()
			if toastSequence == sequence then
				toast.Visible = false
			end
		end
	end)
end

--[[
	World labels.

	Every floating place name is tagged by the server. Here they are faded in as
	the player walks up to them and hidden again on the way out, so the town does
	not read as a wall of text from across the map. The player can also switch
	them off entirely, and that choice is saved on their profile.
]]
local labelsEnabled = true
local trackedLabels = {}
local labelClock = 0

local function trackLabel(labelGui)
	local text = labelGui:FindFirstChild("Text")
	if text then
		trackedLabels[labelGui] = { Text = text, Stroke = text:FindFirstChildOfClass("UIStroke") }
	end
end

for _, labelGui in ipairs(CollectionService:GetTagged(RemoteNames.LabelTag)) do
	trackLabel(labelGui)
end
CollectionService:GetInstanceAddedSignal(RemoteNames.LabelTag):Connect(trackLabel)
CollectionService:GetInstanceRemovedSignal(RemoteNames.LabelTag):Connect(function(labelGui)
	trackedLabels[labelGui] = nil
end)

local function refreshLabels()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local near, far = Config.LabelNearDistance, Config.LabelFarDistance

	for labelGui, parts in pairs(trackedLabels) do
		local adornee = labelGui.Adornee
		if not labelGui.Parent or not adornee then
			trackedLabels[labelGui] = nil
		elseif not labelsEnabled then
			labelGui.Enabled = false
		else
			local distance = (adornee.Position - eye).Magnitude
			if distance >= far then
				labelGui.Enabled = false
			else
				-- 0 right up close, 1 at the far edge, so the label thins out
				-- as the player backs away instead of blinking off.
				local fade = math.clamp((distance - near) / math.max(far - near, 1), 0, 1)
				labelGui.Enabled = true
				parts.Text.TextTransparency = fade
				parts.Text.BackgroundTransparency = 0.08 + fade * 0.92
				if parts.Stroke then
					parts.Stroke.Transparency = fade
				end
			end
		end
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	labelClock += deltaTime
	if labelClock < 0.1 then
		return
	end
	labelClock = 0
	refreshLabels()
end)

local renderMenu
local function applyState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	loading.Visible = false
	coinsLabel.Text = string.format("เหรียญ %d\nCoins %d", state.Coins or 0, state.Coins or 0)
	local daily = state.Daily or {}
	giftLabel.Text = daily.CanClaim
		and bilingual("DAILY GIFT!", "รับของขวัญ!")
		or bilingual(string.format("STREAK %d", daily.Streak or 0), string.format("ต่อเนื่อง %d วัน", daily.Streak or 0))
	giftButton.BackgroundColor3 = daily.CanClaim and Theme.Colors.Sun:Lerp(Theme.Colors.White, 0.78) or Theme.Colors.White
	giftStroke.Color = daily.CanClaim and Theme.Colors.Sun or Theme.Colors.Border
	Iconography.setColor(giftIcon, daily.CanClaim and Theme.Colors.PrimaryDark or Theme.Colors.Muted)
	if questBoard then
		questBoard:Update(state)
	end
	if questNavigator then
		questNavigator:Update(state)
	end
	if furnitureShop then
		furnitureShop:Update(state)
	end
	if panel.Visible and renderMenu then
		renderMenu(currentMenu)
	end
	if state.Settings and not state.Settings.Onboarded then
		onboarding.Visible = true
	end

	labelsEnabled = not state.Settings or state.Settings.ShowLabels ~= false
	labelsLabel.Text = labelsEnabled and bilingual("NAMES ON", "ชื่อสถานที่ เปิด")
		or bilingual("NAMES OFF", "ชื่อสถานที่ ปิด")
	labelsButton.BackgroundColor3 = labelsEnabled and Theme.Colors.Selected or Theme.Colors.White
	labelsStroke.Color = labelsEnabled and Theme.Colors.Primary or Theme.Colors.Border
	Iconography.setColor(labelsIcon, labelsEnabled and Theme.Colors.Primary or Theme.Colors.Muted)
	refreshLabels()
end

local function invoke(action, payload, silent, onComplete)
	if requestBusy and not silent then
		if onComplete then
			onComplete(false, nil)
		end
		return
	end
	if not silent then
		requestBusy = true
	end
	task.spawn(function()
		local success, response = pcall(function()
			return requestRemote:InvokeServer(action, payload or {})
		end)
		if not silent then
			requestBusy = false
		end
		if success and type(response) == "table" then
			if response.state then
				applyState(response.state)
			end
			if not silent then
				showToast(response.message, response.ok)
			end
		elseif not silent then
			showToast("The town is taking a little nap. Try again!", false)
		end
		if onComplete then
			onComplete(success and type(response) == "table" and response.ok == true, response)
		end
	end)
end

local function resetBody()
	body:ClearAllChildren()
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent = body
	local layout = Components.list(body, 12)
	return layout
end

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function addHeading(text)
	local label = Components.label(body, text, UDim2.new(1, 0, 0, 50), nil, HudLayout.HEADING_TEXT_SIZE, true)
	label.LayoutOrder = nextOrder()
	label.TextColor3 = Theme.Colors.PrimaryDark
	return label
end

local function addText(text, height)
	local label = Components.label(body, text, UDim2.new(1, 0, 0, height or 64), nil, HudLayout.BODY_TEXT_SIZE, false)
	label.LayoutOrder = nextOrder()
	label.TextColor3 = Theme.Colors.Muted
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function addButton(text, color, action, payload)
	local button = Components.button(body, text, color, function()
		invoke(action, payload)
	end)
	button.LayoutOrder = nextOrder()
	button.TextSize = HudLayout.CONTROL_TEXT_SIZE
	return button
end

local function addHomePalette(currentName)
	local palette = HomePalette.create(body, Config.HomeColors, currentName, Theme, Components, bilingual, function(colorName)
		invoke("PaintHome", { color = colorName })
	end)
	palette.LayoutOrder = nextOrder()
	return palette
end

local function addCafeItem(itemId)
	local item = CafeMenu.get(itemId)
	if not item then
		return nil
	end
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = Theme.Colors.White
	button.LayoutOrder = nextOrder()
	button.Size = UDim2.new(1, 0, 0, 104)
	button.Text = ""
	button.Parent = body
	Components.corner(button, Theme.SmallCorner)
	Components.stroke(button, Theme.Colors.Surface, 2, 0)

	-- A ViewportFrame renders the same real 3D model that sits in the cafe case.
	-- This keeps the selector tactile and readable without falling back to a flat
	-- food picture.
	local preview = Instance.new("ViewportFrame")
	preview.Name = itemId .. "3DPreview"
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(195, 179, 170)
	preview.LightColor = Color3.fromRGB(255, 241, 212)
	preview.LightDirection = Vector3.new(-1, -1, -1)
	preview.Position = UDim2.fromOffset(8, 8)
	preview.Size = UDim2.fromOffset(70, 70)
	preview.Parent = button

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.CFrame = CFrame.lookAt(Vector3.new(3.6, 2.6, 4.7), Vector3.new(0, 0.82, 0))
	camera.Parent = preview
	preview.CurrentCamera = camera

	local previewWorld = Instance.new("WorldModel")
	previewWorld.Name = "CafePreviewWorld"
	previewWorld.Parent = preview
	local previewModel = CafeModels.build(previewWorld, itemId, CFrame.new(), 1)
	previewModel:SetAttribute("MenuPreview", true)

	local name = Components.label(button, bilingual(item.Name, item.NameThai), UDim2.new(1, -92, 0, 42), UDim2.fromOffset(86, 8), 15, true)
	name.TextColor3 = Theme.Colors.Ink
	name.TextXAlignment = Enum.TextXAlignment.Left
	local description = Components.label(button, bilingual(item.Description, item.DescriptionThai), UDim2.new(1, -92, 0, 46), UDim2.fromOffset(86, 52), 13, false)
	description.TextColor3 = Theme.Colors.Muted
	description.TextXAlignment = Enum.TextXAlignment.Left

	button.Activated:Connect(function()
		invoke("CafeServe", { item = itemId })
	end)
	return button
end

local function formatResourceCost(cost, thai)
	local pieces = {}
	for _, resourceId in ipairs(Catalog.AdventureResourceOrder) do
		local amount = cost[resourceId]
		if amount and amount > 0 then
			local resource = Catalog.AdventureResources[resourceId]
			table.insert(pieces, string.format("%s %d", thai and resource.DisplayNameThai or resource.DisplayName, amount))
		end
	end
	return table.concat(pieces, ", ")
end

--[[
	A storage slot: the picture of a thing, its name, how many you carry, and - when
	a camp is asking for it - how many you still need.

	Every one of the five is drawn every time, including the ones you have none of.
	An empty slot showing "0" tells a child there is something they have not found
	yet; hiding it tells them nothing at all.
]]
local function addSlot(resourceId, count, need)
	local resource = Catalog.AdventureResources[resourceId]
	local wanted = need and need > 0
	local met = wanted and count >= need

	-- Every label here is bilingual, which means every label is two lines. The
	-- heights below are sized for that: a 16px row would quietly clip the Thai.
	local slot = Instance.new("Frame")
	slot.BackgroundColor3 = Theme.Colors.White
	slot.BackgroundTransparency = count > 0 and 0 or 0.5
	slot.LayoutOrder = nextOrder()
	slot.Size = UDim2.new(1, 0, 0, 84)
	slot.Parent = body
	Components.corner(slot, Theme.SmallCorner)
	Components.stroke(slot, met and Theme.Colors.Primary or Theme.Colors.Surface, met and 3 or 2, 0)

	local tile = Instance.new("TextLabel")
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.BackgroundColor3 = resource.Color
	tile.Position = UDim2.new(0, 8, 0.5, 0)
	tile.Size = UDim2.fromOffset(44, 44)
	tile.Font = Enum.Font.GothamBold
	tile.Text = resource.Icon
	-- The tile is painted the resource's own colour and a cave crystal is nearly
	-- white, so the glyph colour has to be asked for, never assumed.
	tile.TextColor3 = Theme.textOn(resource.Color)
	tile.TextSize = 24
	tile.Parent = slot
	Components.corner(tile, Theme.SmallCorner)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Position = UDim2.fromOffset(60, 7)
	name.Size = UDim2.new(1, -136, 0, 36)
	name.Text = bilingual(resource.DisplayName, resource.DisplayNameThai)
	name.TextColor3 = Theme.Colors.Ink
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.Parent = slot

	local where = Instance.new("TextLabel")
	where.BackgroundTransparency = 1
	where.Font = Enum.Font.Gotham
	where.Position = UDim2.fromOffset(60, 45)
	where.Size = UDim2.new(1, -136, 0, 32)
	where.Text = wanted and not met
		and bilingual(string.format("Still need %d more", need - count), string.format("ต้องเก็บอีก %d", need - count))
		or bilingual(string.format("Found in %s", resource.FoundIn), string.format("หาได้ที่%s", resource.FoundInThai))
	where.TextColor3 = wanted and not met and Theme.Colors.Berry or Theme.Colors.Muted
	where.TextSize = 13
	where.TextWrapped = true
	where.TextXAlignment = Enum.TextXAlignment.Left
	where.TextYAlignment = Enum.TextYAlignment.Top
	where.Parent = slot

	-- The number you own, big. When a camp wants some, it becomes "have / need" so
	-- the two numbers a child is comparing sit next to each other.
	local amount = Instance.new("TextLabel")
	amount.AnchorPoint = Vector2.new(1, 0.5)
	amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.GothamBold
	amount.Position = UDim2.new(1, -10, 0.5, 0)
	amount.Size = UDim2.fromOffset(70, 34)
	amount.Text = wanted and string.format("%d / %d%s", count, need, met and "  ✓" or "") or tostring(count)
	amount.TextColor3 = met and Theme.Colors.Primary or Theme.Colors.Ink
	amount.TextSize = wanted and 13 or 18
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.Parent = slot

	return slot
end

local MENU_COLORS = {
	Home = Theme.Colors.Primary,
	Garden = Theme.Colors.Leaf,
	Pet = Theme.Colors.Slate,
	Cafe = Theme.Colors.Sun,
	Style = Theme.Colors.Water,
	Map = Theme.Colors.Leaf,
	Adventure = Config.AdventurePalette.ForestGreen,
	Bag = Config.AdventurePalette.SunsetOrange,
}

renderMenu = function(menu)
	if not state then
		return
	end
	if questBoard then
		questBoard:SetOpen(false)
	end
	currentMenu = menu
	panel.Visible = true
	layoutPanel()
	local englishTitle = menu == "Style" and "DRESS UP" or string.upper(menu)
	panelTitle.Text = bilingual(englishTitle, NAV_THAI[menu])
	panelTitle.TextSize = HudLayout.TITLE_TEXT_SIZE
	panelIcon:Destroy()
	panelIcon = Iconography.create(panel, menu, MENU_COLORS[menu], 32)
	panelIcon.Position = UDim2.fromOffset(20, 17)
	order = 0
	resetBody()
	for name, entry in pairs(navButtons) do
		local selected = name == menu
		local accent = MENU_COLORS[name]
		entry.Button.BackgroundColor3 = selected and Theme.Colors.Selected or Theme.Colors.White
		entry.Label.TextColor3 = selected and Theme.Colors.Ink or Theme.Colors.Muted
		entry.Indicator.Visible = selected
		entry.Indicator.BackgroundColor3 = accent
		entry.Stroke.Color = selected and accent or Theme.Colors.Border
		Iconography.setColor(entry.Icon, selected and accent:Lerp(Theme.Colors.Ink, 0.28) or Theme.Colors.Muted)
	end

	if menu == "Home" then
		local paint = homeColorInfo(state.Home.Paint)
		addHeading(bilingual(string.format("Your %s cottage", paint.DisplayName), string.format("บ้านสี%sของคุณ", paint.NameThai)))
		addText(bilingual("Choose a real color swatch below. The check mark shows the color on your cottage now.", "เลือกช่องสีจริงด้านล่าง เครื่องหมายถูกคือสีที่บ้านกำลังใช้อยู่"))
		addHomePalette(state.Home.Paint)
		addHeading(bilingual(
			string.format("Furniture (%d/%d placed)", #state.Home.Furniture, Config.MaxFurniture),
			string.format("เฟอร์นิเจอร์ (วางแล้ว %d/%d)", #state.Home.Furniture, Config.MaxFurniture)
		))
		addText(bilingual(
			"Choose a piece, arrange its ghost, then confirm BUY & PLACE at your chosen spot.",
			"เลือกเฟอร์นิเจอร์ จัดตำแหน่งตัวอย่าง แล้วกดยืนยันซื้อและวางตรงจุดที่เลือก"
		))
		local shopButton = Components.button(body, bilingual("OPEN FURNITURE SHOP", "เปิดร้านเฟอร์นิเจอร์"), Theme.Colors.Leaf, function()
			panel.Visible = false
			if furnitureShop then
				furnitureShop:SetVisible(true)
			end
		end)
		shopButton.TextSize = HudLayout.CONTROL_TEXT_SIZE
		shopButton.LayoutOrder = nextOrder()
	elseif menu == "Garden" then
		addHeading(bilingual("Your flower patches", "แปลงดอกไม้ของคุณ"))
		addText(bilingual("Plant, water, wait, then pick flowers for coins.", "ปลูก รดน้ำ รอสักครู่ แล้วเก็บดอกไม้เพื่อรับเหรียญ"))
		for index, slot in ipairs(state.Garden.Slots) do
			if slot.State == "Empty" then
				addHeading(bilingual(string.format("Patch %d is ready", index), string.format("แปลง %d พร้อมปลูก", index)))
				local hasSeed = false
				for _, seedId in ipairs(Catalog.SeedOrder) do
					local count = state.Garden.Seeds[seedId] or 0
					if count > 0 then
						hasSeed = true
						local seed = Catalog.Seeds[seedId]
						addButton(
							bilingual(
								string.format("Plant %s (%d seeds)", seed.DisplayName, count),
								string.format("ปลูก%s (มี %d เมล็ด)", seed.DisplayNameThai, count)
							),
							seed.Color,
							"GardenPlant",
							{ slot = index, seed = seedId }
						)
					end
				end
				if not hasSeed then
					addText(bilingual("Buy a seed below to use this patch.", "ซื้อเมล็ดด้านล่างเพื่อใช้แปลงนี้"), 46)
				end
			elseif not slot.Watered then
				local seed = Catalog.Seeds[slot.Seed]
				addButton(
					bilingual(
						string.format("Patch %d: Water %s", index, seed.DisplayName),
						string.format("แปลง %d: รดน้ำ%s", index, seed.DisplayNameThai)
					),
					Theme.Colors.Water,
					"GardenWater",
					{ slot = index }
				)
			elseif slot.Ready then
				local seed = Catalog.Seeds[slot.Seed]
				addButton(
					bilingual(
						string.format("Patch %d: Pick %s!", index, seed.DisplayName),
						string.format("แปลง %d: เก็บ%s!", index, seed.DisplayNameThai)
					),
					Theme.Colors.Sun,
					"GardenHarvest",
					{ slot = index }
				)
			else
				local seed = Catalog.Seeds[slot.Seed]
				local seconds = math.ceil(slot.SecondsLeft or 0)
				addButton(
					bilingual(
						string.format("Patch %d: %s grows for %ds", index, seed.DisplayName, seconds),
						string.format("แปลง %d: %sโตอีก %d วินาที", index, seed.DisplayNameThai, seconds)
					),
					Theme.Colors.Slate,
					"GardenHarvest",
					{ slot = index }
				)
			end
		end
		addHeading(bilingual("Seed basket", "ตะกร้าเมล็ดพันธุ์"))
		local prices = { Daisy = 15, Tulip = 25, Lavender = 40 }
		for _, seedId in ipairs(Catalog.SeedOrder) do
			local seed = Catalog.Seeds[seedId]
			local seedCount = state.Garden.Seeds[seedId] or 0
			addButton(
				bilingual(
					string.format("Buy %s seed - %d coins (have %d)", seed.DisplayName, prices[seedId], seedCount),
					string.format("ซื้อเมล็ด%s - %d เหรียญ (มี %d)", seed.DisplayNameThai, prices[seedId], seedCount)
				),
				seed.Color,
				"BuySeed",
				{ seed = seedId }
			)
		end
	elseif menu == "Pet" then
		local activeCompanion = state.Adventure and Catalog.Companions[state.Adventure.ActiveCompanion] or Catalog.Companions.Cat
		addHeading(bilingual(
			string.format("%s - Level %d", activeCompanion.DisplayName, state.Pet.Level),
			string.format("%s - เลเวล %d", activeCompanion.DisplayNameThai, state.Pet.Level)
		))
		addText(bilingual(
			string.format("Hunger: %d/100  Clean: %d/100  XP: %d/%d", state.Pet.Hunger, state.Pet.Cleanliness, state.Pet.XP, state.Pet.Level * 25),
			string.format("ความหิว: %d/100  ความสะอาด: %d/100  XP: %d/%d", state.Pet.Hunger, state.Pet.Cleanliness, state.Pet.XP, state.Pet.Level * 25)
		), 64)
		addButton(bilingual("Give a snack - 5 coins", "ให้ขนม - 5 เหรียญ"), Theme.Colors.Primary, "PetFeed", {})
		addButton(bilingual("Play together", "เล่นด้วยกัน"), Theme.Colors.Slate, "PetPlay", {})
		addButton(bilingual("Bubble bath", "อาบน้ำฟองสบู่"), Theme.Colors.Water, "PetBath", {})
		addButton(bilingual("Visit the Pet Shop", "ไปร้านสัตว์เลี้ยง"), Theme.Colors.Water, "Teleport", { destination = "PetShop" })
	elseif menu == "Cafe" then
		if not state.Cafe.Unlocked then
			addHeading(bilingual("Open your family cafe", "เปิดคาเฟ่ครอบครัวของคุณ"))
			addText(bilingual("Serve friendly town guests and earn coins.", "เสิร์ฟลูกค้าในเมืองและรับเหรียญ"))
			addButton(
				bilingual(
					string.format("Open cafe - %d coins", Config.CafeUnlockCost),
					string.format("เปิดคาเฟ่ - %d เหรียญ", Config.CafeUnlockCost)
				),
				Theme.Colors.Primary,
				"CafeUnlock",
				{}
			)
		else
			addHeading(bilingual(string.format("Family Cafe - Level %d", state.Cafe.Level), string.format("คาเฟ่ครอบครัว - เลเวล %d", state.Cafe.Level)))
			addText(bilingual(
				string.format("Served %d happy guests. Helpers: %d/3", state.Cafe.Served, state.Cafe.Staff or 0),
				string.format("เสิร์ฟลูกค้าแล้ว %d คน ผู้ช่วย: %d/3", state.Cafe.Served, state.Cafe.Staff or 0)
			))
			addHeading(bilingual("Choose what to serve", "เลือกเมนูที่จะเสิร์ฟ"))
			for _, itemId in ipairs(CafeMenu.Order) do
				addCafeItem(itemId)
			end
			local upgradeCost = state.Cafe.Level * 180
			addButton(
				bilingual(
					string.format("Upgrade cafe - %d coins", upgradeCost),
					string.format("อัปเกรดคาเฟ่ - %d เหรียญ", upgradeCost)
				),
				Theme.Colors.Leaf,
				"CafeUpgrade",
				{}
			)
			if (state.Cafe.Staff or 0) < 3 then
				local helperCost = 250 + (state.Cafe.Staff or 0) * 200
				addButton(
					bilingual(
						string.format("Hire NPC helper - %d coins", helperCost),
						string.format("จ้างผู้ช่วย NPC - %d เหรียญ", helperCost)
					),
					Theme.Colors.Slate,
					"HireCafeStaff",
					{}
				)
			end
		end
		addButton(bilingual("Go to the Cafe", "ไปคาเฟ่"), Theme.Colors.Sun, "Teleport", { destination = "Cafe" })
	elseif menu == "Adventure" then
		local adventure = state.Adventure
		local camp = Catalog.CampLevels[adventure.CampLevel]
		addHeading(bilingual(string.format("%s - Level %d", camp.Name, adventure.CampLevel), string.format("%s - เลเวล %d", camp.NameThai, adventure.CampLevel)))
		if adventure.SeasonEvent then
			addText(bilingual(
				string.format("Season: %s - %s", adventure.SeasonEvent.Name, adventure.SeasonEvent.Description),
				string.format("กิจกรรมฤดูกาล: %s - %s", adventure.SeasonEvent.NameThai, adventure.SeasonEvent.DescriptionThai)
			), 62)
		end
		addButton(bilingual("Go to Adventure Camp", "ไปแคมป์ผจญภัย"), Config.AdventurePalette.SunsetOrange, "Teleport", { destination = "AdventureCamp" })

		-- What the next camp wants, item by item, with what is already in the bag
		-- beside it. This used to be a single line of text listing the cost and a
		-- separate line listing the bag, leaving the child to do the subtraction.
		local plan = CampPlan.requirements(adventure.CampLevel, adventure.Resources)
		if plan then
			addHeading(bilingual(
				string.format("Build the %s", plan.Name),
				string.format("สร้าง%s", plan.NameThai)
			))
			for _, item in ipairs(plan.Items) do
				addSlot(item.Id, item.Have, item.Need)
			end
			if plan.Ready then
				addButton(
					bilingual(
						string.format("Build %s - you have everything!", plan.Name),
						string.format("สร้าง%s - ของครบแล้ว!", plan.NameThai)
					),
					Config.AdventurePalette.ForestGreen,
					"AdventureUpgradeCamp",
					{}
				)
			else
				-- The button stays, because a locked door a child cannot even see is
				-- worse than one that says what the key is. It names what is missing.
				addButton(
					bilingual(
						string.format("Build %s - still need %s", plan.Name, CampPlan.missingText(adventure.CampLevel, adventure.Resources, false)),
						string.format("สร้าง%s - ยังต้องการ %s", plan.NameThai, CampPlan.missingText(adventure.CampLevel, adventure.Resources, true))
					),
					Theme.Colors.Slate,
					"AdventureUpgradeCamp",
					{}
				)
			end
		else
			addText(bilingual("Adventure Center complete!", "ศูนย์ผจญภัยสร้างเสร็จแล้ว!"), 42)
		end

		addHeading(bilingual("Adventure zones", "เขตผจญภัย"))
		for _, zoneId in ipairs(Catalog.AdventureZoneOrder) do
			local zone = Catalog.AdventureZones[zoneId]
			local discovered = adventure.Discoveries[zoneId]
			local englishStatus = discovered and "Discovered" or "Explore"
			local thaiStatus = discovered and "ค้นพบแล้ว" or "ออกสำรวจ"
			addButton(
				bilingual(string.format("%s: %s", englishStatus, zone.DisplayName), string.format("%s: %s", thaiStatus, zone.DisplayNameThai)),
				zoneId == "RiverAdventure" and Config.AdventurePalette.RiverBlue or Config.AdventurePalette.ForestGreen,
				"Teleport",
				{ destination = zoneId }
			)
		end

		addHeading(bilingual("Animal adventure partners", "สัตว์คู่หูผจญภัย"))
		for _, companionId in ipairs(Catalog.CompanionOrder) do
			local companion = Catalog.Companions[companionId]
			local owned = table.find(adventure.OwnedCompanions, companionId) ~= nil
			if companionId == adventure.ActiveCompanion then
				addText(bilingual(
					string.format("Active: %s - %s", companion.DisplayName, companion.Ability),
					string.format("กำลังร่วมทาง: %s - %s", companion.DisplayNameThai, companion.AbilityThai)
				), 58)
			elseif owned then
				addButton(
					bilingual(string.format("Explore with %s", companion.DisplayName), string.format("ออกสำรวจกับ%s", companion.DisplayNameThai)),
					companion.Color,
					"AdventureSelectCompanion",
					{ companion = companionId }
				)
			elseif companionId ~= "Cat" then
				addButton(
					bilingual(
						string.format("Befriend %s - %s", companion.DisplayName, formatResourceCost(companion.Cost, false)),
						string.format("ผูกมิตรกับ%s - %s", companion.DisplayNameThai, formatResourceCost(companion.Cost, true))
					),
					companion.Color,
					"AdventureUnlockCompanion",
					{ companion = companionId }
				)
			end
		end

		addHeading(bilingual("Mystery Cave runes", "รูนถ้ำลึกลับ"))
		if adventure.PuzzleHint then
			local hintThai = { Leaf = "ใบไม้", River = "สายน้ำ", Sun = "ดวงอาทิตย์" }
			addText(bilingual(string.format("Owl hint: choose %s", adventure.PuzzleHint), string.format("คำใบ้นกฮูก: เลือก%s", hintThai[adventure.PuzzleHint])), 44)
		else
			addText(bilingual("Find the three-rune order, or bring the Owl for a hint.", "ค้นหาลำดับรูนสามอัน หรือพานกฮูกมารับคำใบ้"), 58)
		end
		addButton(bilingual("Leaf rune", "รูนใบไม้"), Config.AdventurePalette.ForestGreen, "AdventurePuzzleRune", { rune = "Leaf" })
		addButton(bilingual("River rune", "รูนสายน้ำ"), Config.AdventurePalette.RiverBlue, "AdventurePuzzleRune", { rune = "River" })
		addButton(bilingual("Sun rune", "รูนดวงอาทิตย์"), Config.AdventurePalette.SoftYellow, "AdventurePuzzleRune", { rune = "Sun" })

		addHeading(bilingual("Teamwork supplies", "แบ่งปันของกับเพื่อน"))
		addText(bilingual("Stand near another explorer, then share one supply.", "ยืนใกล้นักสำรวจคนอื่น แล้วแบ่งของให้เพื่อน 1 ชิ้น"), 54)
		for _, resourceId in ipairs(Catalog.AdventureResourceOrder) do
			local resource = Catalog.AdventureResources[resourceId]
			local count = adventure.Resources[resourceId]
			if count > 0 then
				addButton(
					bilingual(string.format("Share 1 %s (%d owned)", resource.DisplayName, count), string.format("แบ่ง%s 1 ชิ้น (มี %d)", resource.DisplayNameThai, count)),
					resource.Color,
					"AdventureShare",
					{ resource = resourceId }
				)
			end
		end
	elseif menu == "Bag" then
		local adventure = state.Adventure
		local plan = CampPlan.requirements(adventure.CampLevel, adventure.Resources)
		local capacity = adventure.BagSlots or Config.Bag.StartingSlots
		local used = BagInventory.usedSlots(adventure.Resources)
		local carried = BagInventory.itemCount(adventure.Resources)

		addHeading(bilingual(
			string.format("My bag - %d / %d slots", used, capacity),
			string.format("กระเป๋าของฉัน - %d / %d ช่อง", used, capacity)
		))
		addText(bilingual(
			string.format("%d supplies carried. Each slot stacks up to %d.", carried, Config.Bag.StackSize),
			string.format("มีของ %d ชิ้น แต่ละช่องซ้อนได้สูงสุด %d ชิ้น", carried, Config.Bag.StackSize)
		), 44)

		if used > capacity then
			addText(bilingual(
				"Your old supplies are safe, but the bag is over capacity. Spend supplies or expand it.",
				"ของเดิมยังอยู่ครบ แต่กระเป๋าเกินความจุ ใช้ของหรือซื้อช่องเพิ่ม"
			), 44)
		end

		local bagGrid = BagGrid.create(body, adventure.Resources, capacity, Theme, Components, bilingual)
		bagGrid.LayoutOrder = nextOrder()

		local upgrade = BagInventory.nextUpgrade(capacity)
		if upgrade then
			addButton(
				bilingual(
					string.format("BUY +%d SLOTS - %d COINS", upgrade.Added, upgrade.Cost),
					string.format("ซื้อเพิ่ม %d ช่อง - %d เหรียญ", upgrade.Added, upgrade.Cost)
				),
				Config.AdventurePalette.SunsetOrange,
				"BagUpgrade",
				{}
			)
		else
			addText(bilingual("Maximum bag size reached: 60 slots.", "กระเป๋าเต็มขนาดสูงสุดแล้ว: 60 ช่อง"), 40)
		end

		if plan then
			local missing = CampPlan.missingText(adventure.CampLevel, adventure.Resources, false)
			local missingThai = CampPlan.missingText(adventure.CampLevel, adventure.Resources, true)
			addText(plan.Ready and bilingual(
				string.format("Ready to build the %s!", plan.Name),
				string.format("พร้อมสร้าง%sแล้ว!", plan.NameThai)
			) or bilingual(
				string.format("For %s, still collect: %s", plan.Name, missing),
				string.format("สำหรับ%s ยังต้องเก็บ: %s", plan.NameThai, missingThai)
			), 54)
		else
			addText(bilingual("Everything is built. Keep exploring!", "สร้างครบทุกอย่างแล้ว ออกสำรวจต่อได้เลย!"), 44)
		end

		addHeading(bilingual("Go and find more", "ออกไปเก็บของเพิ่ม"))
		for _, zoneId in ipairs(Catalog.AdventureZoneOrder) do
			local zone = Catalog.AdventureZones[zoneId]
			local resource = Catalog.AdventureResources[zone.Resource]
			addButton(
				bilingual(
					string.format("%s  %s - find %s", resource.Icon, zone.DisplayName, resource.DisplayName),
					string.format("%s  %s - หา%s", resource.Icon, zone.DisplayNameThai, resource.DisplayNameThai)
				),
				zoneId == "RiverAdventure" and Config.AdventurePalette.RiverBlue or Config.AdventurePalette.ForestGreen,
				"Teleport",
				{ destination = zoneId }
			)
		end
	elseif menu == "Style" then
		addHeading(bilingual("Choose an approved 3D avatar", "เลือกอวาตาร 3D ที่อนุมัติ"))
		local equippedId = Catalog.Outfits[state.Wardrobe.Equipped] and state.Wardrobe.Equipped or "Original"
		local equipped = Catalog.Outfits[equippedId]
		if equipped then
			addText(bilingual(
				string.format("Playing as: %s. Choose Original at any time to restore your Roblox avatar.", equipped.DisplayName),
				string.format("กำลังเล่นเป็น: %s เลือกตัวเดิมได้ทุกเมื่อเพื่อกลับสู่อวาตาร Roblox ของคุณ", equipped.DisplayNameThai)
			), 58)
		else
			addText(bilingual(
				"You are using your original Roblox avatar. Choose a model below only when you are ready.",
				"ตอนนี้คุณใช้อวาตาร Roblox เดิม เลือกโมเดลด้านล่างเมื่อพร้อม"
			), 58)
		end
		addButton(
			equippedId == "Original"
				and bilingual("✓ USING MY ORIGINAL ROBLOX AVATAR", "✓ กำลังใช้อวาตาร Roblox เดิม")
				or bilingual("RESTORE MY ORIGINAL ROBLOX AVATAR", "กลับไปใช้อวาตาร Roblox เดิม"),
			Theme.Colors.White,
			"EquipAvatar",
			{ avatar = "Original" }
		)
		local avatarGrid = AvatarGrid.create(body, equippedId, Theme, Components, bilingual, function(avatarId)
			invoke("EquipAvatar", { avatar = avatarId })
		end)
		avatarGrid.LayoutOrder = nextOrder()
	elseif menu == "Map" then
		addHeading(bilingual("Where shall we go?", "อยากไปที่ไหน?"))
		addText(bilingual("Tap a place to travel there safely.", "แตะสถานที่เพื่อเดินทางอย่างปลอดภัย"))
		addButton(bilingual("My Home", "บ้านของฉัน"), Theme.Colors.Primary, "Teleport", { destination = "Home" })
		for _, destination in ipairs({ "Town", "Cafe", "PetShop", "FlowerShop", "Playground", "School", "Park", "Lake", "Beach", "Forest", "AdventureCamp", "WildwoodForest", "Mountain", "RiverAdventure", "MysteryCave" }) do
			local english = destination:gsub("(%l)(%u)", "%1 %2")
			addButton(bilingual(english, DESTINATION_THAI[destination]), Theme.Colors.Water, "Teleport", { destination = destination })
		end
	end
end

for index, name in ipairs({ "Home", "Garden", "Pet", "Cafe", "Adventure", "Bag", "Style", "Map" }) do
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Colors.White
	button.Size = UDim2.fromOffset(92, 64)
	button.LayoutOrder = index
	button.Text = ""
	button.Parent = nav
	Components.corner(button, Theme.SmallCorner)
	local buttonStroke = Components.stroke(button, Theme.Colors.Border, 1)

	local icon = Iconography.create(button, name, Theme.Colors.Muted, 27)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 4)

	local text = Components.label(button, bilingual(string.upper(name), NAV_THAI[name]), UDim2.new(1, -6, 0, 28), UDim2.fromOffset(3, 34), 8, true)
	text.TextColor3 = Theme.Colors.Muted
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center

	local indicator = Instance.new("Frame")
	indicator.Name = "SelectedIndicator"
	indicator.AnchorPoint = Vector2.new(0.5, 1)
	indicator.BackgroundColor3 = MENU_COLORS[name]
	indicator.BorderSizePixel = 0
	indicator.Position = UDim2.new(0.5, 0, 1, -2)
	indicator.Size = UDim2.new(0.56, 0, 0, 3)
	indicator.Visible = false
	indicator.Parent = button
	Components.corner(indicator, UDim.new(1, 0))
	button.Activated:Connect(function()
		panelOffset = nil
		renderMenu(name)
	end)
	navButtons[name] = {
		Button = button,
		Icon = icon,
		Label = text,
		Indicator = indicator,
		Stroke = buttonStroke,
	}
end

closeButton.Activated:Connect(function()
	panel.Visible = false
end)

labelsButton.Activated:Connect(function()
	-- Flip locally so the labels react on the tap, then let the saved profile
	-- come back and confirm it.
	labelsEnabled = not labelsEnabled
	refreshLabels()
	invoke("ToggleLabels", {})
end)

giftButton.Activated:Connect(function()
	if state and state.Daily and state.Daily.CanClaim then
		invoke("ClaimDaily", {})
	else
		showToast("Come back tomorrow for another gift!")
	end
end)

startButton.Activated:Connect(function()
	onboarding.Visible = false
	invoke("FinishOnboarding", {})
	renderMenu("Home")
end)

stateChanged.OnClientEvent:Connect(applyState)
toastRemote.OnClientEvent:Connect(showToast)

-- The ground path and translucent waypoint follow the active chain step.
-- Buttons on the quest board can temporarily pin the daily quest instead.
questNavigator = QuestNavigator.new(gui, Theme, Catalog, Config, bilingual)

-- The quest board stays in the upper-left: a compact header while hidden and
-- the same large reading panel while open. Opening it dismisses the activity panel.
questBoard = QuestBoard.new(gui, Theme, Components, Catalog, Config, bilingual, function(action, payload)
	invoke(action, payload)
end, function(kind)
	questNavigator:Pin(kind)
end, function(open)
	if open then
		panel.Visible = false
	end
end)
if state then
	questBoard:Update(state)
	questNavigator:Update(state)
end

-- The furniture shop: browsing, previewing, buying, and placing.
furnitureShop = FurnitureShop.new(gui, Theme, Components, bilingual, function(action, payload, onComplete)
	invoke(action, payload, false, onComplete)
end)
if state then
	furnitureShop:Update(state)
end

-- The minimap draws the town the server actually built, so ask for that layout
-- once rather than keeping a second copy of it here that could drift.
local minimap = Minimap.new(gui, Theme, Components, bilingual)
task.spawn(function()
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	for _ = 1, 10 do
		local ok, response = pcall(function()
			return requestRemote:InvokeServer("GetMap", {})
		end)
		if ok and type(response) == "table" and response.map then
			minimap:SetMap(response.map)
			return
		end
		task.wait(1)
	end
	warn("Minimap could not load the town layout")
end)

invoke("GetState", {}, true)

task.spawn(function()
	while gui.Parent do
		task.wait(5)
		invoke("GetState", {}, true)
	end
end)
