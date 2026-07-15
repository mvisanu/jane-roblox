--[[
	Minimap.

	A north-up map in the corner showing where the player is, which way they are
	facing, and what is around them. It can be zoomed, dragged around, shrunk to
	its title bar, or opened out to fill the screen.

	The landmarks are not hardcoded here: the server sends the layout of the town
	it actually built, so the map cannot drift out of step with the world.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Minimap = {}
Minimap.__index = Minimap

local MIN_SCALE = 0.1 -- pixels per stud: the whole world at once
local MAX_SCALE = 3.0 -- close enough to read the garden patches
local DEFAULT_SCALE = 0.55
local ZOOM_STEP = 1.4
local LABEL_SCALE = 0.5 -- labels appear once the map is zoomed in this far

local SMALL_SIZE = UDim2.fromOffset(200, 232)
local COLLAPSED_SIZE = UDim2.fromOffset(200, 36)
local LARGE_SIZE = UDim2.new(0.78, 0, 0.78, 0)

-- Painted back to front, so roads sit under places and places under buildings.
local LAYER = { Road = 1, Area = 2, Zone = 2, Building = 4, Home = 5 }

local function transparencyFor(kind)
	if kind == "Road" then
		return 0.35
	elseif kind == "Area" or kind == "Zone" then
		return 0.55
	end
	return 0.1
end

function Minimap.new(parent, theme, components, bilingual)
	local self = setmetatable({}, Minimap)
	self._theme = theme
	self._bilingual = bilingual
	self._scale = DEFAULT_SCALE
	self._pan = Vector2.new(0, 0)
	self._state = "normal"
	self._blips = {}
	self._clock = 0
	self._dragging = false

	local panel = Instance.new("Frame")
	panel.Name = "Minimap"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.BackgroundColor3 = theme.Colors.Surface
	panel.Position = UDim2.new(1, -12, 0, 132)
	panel.Size = SMALL_SIZE
	panel.Parent = parent
	components.corner(panel, theme.SmallCorner)
	components.stroke(panel, theme.Colors.White, 3)
	components.shadow(panel)
	self._panel = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 36)
	header.Parent = panel

	local title = components.label(header, bilingual("MAP", "แผนที่"), UDim2.new(1, -100, 1, 0), UDim2.fromOffset(10, 0), 11, true)
	title.TextColor3 = theme.Colors.Ink
	title.TextXAlignment = Enum.TextXAlignment.Left

	local function headerButton(text, offsetX)
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.AutoButtonColor = false
		button.BackgroundColor3 = theme.Colors.White
		button.Position = UDim2.new(1, offsetX, 0.5, 0)
		button.Size = UDim2.fromOffset(44, 28)
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextColor3 = theme.Colors.Ink
		button.TextSize = 11
		button.Parent = header
		components.corner(button, theme.SmallCorner)
		return button
	end

	self._sizeButton = headerButton("BIG", -50)
	self._foldButton = headerButton("HIDE", -6)

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundColor3 = theme.Colors.White
	canvas.ClipsDescendants = true
	canvas.Position = UDim2.fromOffset(6, 36)
	canvas.Size = UDim2.new(1, -12, 1, -42)
	canvas.Parent = panel
	components.corner(canvas, theme.SmallCorner)
	self._canvas = canvas

	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundTransparency = 1
	world.Size = UDim2.fromScale(1, 1)
	world.Parent = canvas
	self._world = world

	-- Which way is up. The map never rotates, so north stays put and the player
	-- arrow turns instead: easier to follow than a spinning map.
	local north = components.label(canvas, "N", UDim2.fromOffset(18, 18), UDim2.new(0.5, -9, 0, 4), 11, true)
	north.TextColor3 = theme.Colors.Muted
	north.ZIndex = 20

	-- The player arrow, built from plain frames rather than an image asset so it
	-- can never silently fail to render. It is the one thing on this map that
	-- must always be visible.
	local you = Instance.new("Frame")
	you.Name = "You"
	you.AnchorPoint = Vector2.new(0.5, 0.5)
	you.BackgroundTransparency = 1
	you.Size = UDim2.fromOffset(24, 24)
	you.ZIndex = 30
	you.Parent = canvas
	self._you = you

	local nose = Instance.new("Frame")
	nose.Name = "Nose"
	nose.AnchorPoint = Vector2.new(0.5, 0.5)
	nose.BackgroundColor3 = theme.Colors.Berry
	nose.BorderSizePixel = 0
	nose.Position = UDim2.fromScale(0.5, 0.16)
	nose.Rotation = 45
	nose.Size = UDim2.fromOffset(11, 11)
	nose.ZIndex = 30
	nose.Parent = you

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.BackgroundColor3 = theme.Colors.Berry
	body.Position = UDim2.fromScale(0.5, 0.6)
	body.Size = UDim2.fromOffset(12, 12)
	body.ZIndex = 31
	body.Parent = you
	components.corner(body, UDim.new(1, 0))
	components.stroke(body, theme.Colors.White, 2)

	local function controlButton(text, offsetX, callback)
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(0, 1)
		button.AutoButtonColor = false
		button.BackgroundColor3 = theme.Colors.Surface
		button.BackgroundTransparency = 0.08
		button.Position = UDim2.new(0, offsetX, 1, -6)
		button.Size = UDim2.fromOffset(44, 44)
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextColor3 = theme.Colors.Ink
		button.TextSize = 16
		button.ZIndex = 25
		button.Parent = canvas
		components.corner(button, theme.SmallCorner)
		components.stroke(button, theme.Colors.White, 2)
		button.Activated:Connect(callback)
		return button
	end

	controlButton("-", 6, function()
		self:_zoom(1 / ZOOM_STEP)
	end)
	controlButton("+", 54, function()
		self:_zoom(ZOOM_STEP)
	end)
	self._recenterButton = controlButton("ME", 102, function()
		self._pan = Vector2.new(0, 0)
		self:_refresh()
	end)

	self._sizeButton.Activated:Connect(function()
		self:_setState(self._state == "large" and "normal" or "large")
	end)
	self._foldButton.Activated:Connect(function()
		self:_setState(self._state == "folded" and "normal" or "folded")
	end)

	-- Drag to pan, wheel to zoom.
	canvas.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = true
			self._dragFrom = input.Position
		end
	end)
	canvas.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not self._dragging or not self._dragFrom then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - self._dragFrom
		self._dragFrom = input.Position
		-- Dragging the map right should bring what is left of you into view.
		self._pan -= Vector2.new(delta.X, delta.Y) / self._scale
		self:_refresh()
	end)
	canvas.MouseWheelForward:Connect(function()
		self:_zoom(ZOOM_STEP)
	end)
	canvas.MouseWheelBackward:Connect(function()
		self:_zoom(1 / ZOOM_STEP)
	end)

	RunService.RenderStepped:Connect(function(deltaTime)
		self._clock += deltaTime
		if self._clock < 0.06 or self._state == "folded" then
			return
		end
		self._clock = 0
		self:_refresh()
	end)

	return self
end

function Minimap:_zoom(factor)
	self._scale = math.clamp(self._scale * factor, MIN_SCALE, MAX_SCALE)
	self:_refresh()
end

function Minimap:_setState(state)
	self._state = state
	if state == "folded" then
		self._panel.Size = COLLAPSED_SIZE
		self._canvas.Visible = false
		self._foldButton.Text = "SHOW"
		self._sizeButton.Visible = false
		return
	end

	self._canvas.Visible = true
	self._sizeButton.Visible = true
	self._foldButton.Text = "HIDE"
	if state == "large" then
		self._panel.AnchorPoint = Vector2.new(0.5, 0.5)
		self._panel.Position = UDim2.fromScale(0.5, 0.5)
		self._panel.Size = LARGE_SIZE
		self._sizeButton.Text = "SMALL"
	else
		self._panel.AnchorPoint = Vector2.new(1, 0)
		self._panel.Position = UDim2.new(1, -12, 0, 132)
		self._panel.Size = SMALL_SIZE
		self._sizeButton.Text = "BIG"
	end
	self:_refresh()
end

--[[ Takes the town layout the server built and draws one marker per landmark. ]]
function Minimap:SetMap(data)
	if type(data) ~= "table" or type(data.Blips) ~= "table" then
		return
	end
	for _, blip in ipairs(self._blips) do
		blip.Frame:Destroy()
	end
	self._blips = {}
	self._homeIndex = data.HomeIndex

	local ordered = table.clone(data.Blips)
	table.sort(ordered, function(a, b)
		return (LAYER[a.Kind] or 3) < (LAYER[b.Kind] or 3)
	end)

	for _, blip in ipairs(ordered) do
		local mine = blip.Kind == "Home" and blip.Index == data.HomeIndex

		local frame = Instance.new("Frame")
		frame.Name = blip.Name
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundColor3 = mine and self._theme.Colors.Leaf or blip.Color
		frame.BackgroundTransparency = transparencyFor(blip.Kind)
		frame.BorderSizePixel = 0
		frame.ZIndex = (LAYER[blip.Kind] or 3) + (mine and 1 or 0)
		frame.Parent = self._world

		if blip.Kind ~= "Road" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = frame
		end
		if mine then
			local stroke = Instance.new("UIStroke")
			stroke.Color = self._theme.Colors.White
			stroke.Thickness = 2
			stroke.Parent = frame
		end

		local label
		if blip.Kind ~= "Road" and blip.Kind ~= "Area" then
			label = Instance.new("TextLabel")
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromOffset(96, 24)
			label.Text = mine and self._bilingual("MY HOME", "บ้านของฉัน")
				or self._bilingual(blip.Name, blip.NameThai or blip.Name)
			label.TextColor3 = self._theme.Colors.Ink
			label.TextSize = 9
			label.TextStrokeColor3 = self._theme.Colors.White
			label.TextStrokeTransparency = 0.2
			label.TextWrapped = true
			label.ZIndex = 15
			label.Parent = frame
		end

		table.insert(self._blips, { Data = blip, Frame = frame, Label = label, Mine = mine })
	end

	self:_refresh()
end

--[[ Places every marker for the current zoom, pan and player position. ]]
function Minimap:_refresh()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local scale = self._scale
	local focusX = root.Position.X + self._pan.X
	local focusZ = root.Position.Z + self._pan.Y
	local canvasSize = self._canvas.AbsoluteSize
	local halfX, halfZ = canvasSize.X / 2, canvasSize.Y / 2
	local showLabels = scale >= LABEL_SCALE or self._state == "large"

	for _, blip in ipairs(self._blips) do
		local data = blip.Data
		local x = (data.X - focusX) * scale
		local z = (data.Z - focusZ) * scale
		local width = math.max(data.W * scale, 3)
		local depth = math.max(data.D * scale, 3)

		-- Skip anything off the edge of the canvas rather than laying it out.
		if math.abs(x) - width / 2 > halfX or math.abs(z) - depth / 2 > halfZ then
			blip.Frame.Visible = false
		else
			blip.Frame.Visible = true
			blip.Frame.Position = UDim2.new(0.5, x, 0.5, z)
			blip.Frame.Size = UDim2.fromOffset(width, depth)
			if blip.Label then
				blip.Label.Visible = showLabels or blip.Mine
			end
		end
	end

	-- The arrow points the way the player is facing, so the map answers "which
	-- way am I going", not just "where am I".
	local look = root.CFrame.LookVector
	self._you.Position = UDim2.new(0.5, -self._pan.X * scale, 0.5, -self._pan.Y * scale)
	self._you.Rotation = math.deg(math.atan2(look.X, -look.Z))
	self._recenterButton.BackgroundColor3 = (self._pan.Magnitude > 1)
		and self._theme.Colors.Sun
		or self._theme.Colors.Surface
end

return Minimap
