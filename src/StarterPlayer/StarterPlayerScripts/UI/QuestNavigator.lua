local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestGuide = require(Shared:WaitForChild("QuestGuide"))

local QuestNavigator = {}
QuestNavigator.__index = QuestNavigator

local TARGET_REFRESH_SECONDS = 0.35
local ARRIVAL_DISTANCE = 10
local RESUME_DISTANCE = 16
local TRAIL_SEGMENT_LENGTH = 9
local MAX_TRAIL_SEGMENTS = 80

local function label(parent, name, text, size, position, font, textSize)
	local object = Instance.new("TextLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.Size = size
	object.Position = position or UDim2.fromOffset(0, 0)
	object.Font = font or Enum.Font.GothamBold
	object.Text = text
	object.TextColor3 = Color3.fromRGB(255, 255, 255)
	object.TextSize = textSize or 12
	object.TextWrapped = true
	object.Parent = parent
	return object
end

function QuestNavigator.new(parent, theme, catalog, config, bilingual)
	local self = setmetatable({}, QuestNavigator)
	self._player = Players.LocalPlayer
	self._theme = theme
	self._catalog = catalog
	self._config = config
	self._bilingual = bilingual
	self._state = nil
	self._pin = "Chain"
	self._target = nil
	self._action = nil
	self._refreshClock = 0
	self._arrived = false
	self._trailParts = {}
	self._trailSegments = 0
	self._trailVisible = false

	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "LocalQuestWaypoint"
	markerFolder.Parent = workspace
	self._markerFolder = markerFolder

	local trailFolder = Instance.new("Folder")
	trailFolder.Name = "GroundPath"
	trailFolder.Parent = markerFolder
	self._trailFolder = trailFolder

	local marker = Instance.new("Part")
	marker.Name = "Target"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Size = Vector3.new(1, 1, 1)
	marker.Transparency = 1
	marker.Parent = markerFolder
	self._marker = marker

	local column = Instance.new("Part")
	column.Name = "WaypointBeam"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.Color = theme.Colors.Sun
	column.Material = Enum.Material.Neon
	column.Size = Vector3.new(0.35, 12, 0.35)
	column.Transparency = 1
	column.Parent = markerFolder
	self._column = column

	local ring = Instance.new("Part")
	ring.Name = "WaypointRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = theme.Colors.Sun
	ring.Material = Enum.Material.Neon
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.18, 7, 7)
	ring.Transparency = 1
	ring.Parent = markerFolder
	self._ring = ring

	local navigationLight = Instance.new("PointLight")
	navigationLight.Name = "NavigationLight"
	navigationLight.Brightness = 0.75
	navigationLight.Color = theme.Colors.Sun
	navigationLight.Enabled = false
	navigationLight.Range = 18
	navigationLight.Shadows = false
	navigationLight.Parent = marker
	self._navigationLight = navigationLight

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QuestWaypointLabel"
	billboard.Adornee = marker
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 2200
	billboard.Size = UDim2.fromOffset(210, 70)
	billboard.StudsOffset = Vector3.new(0, 8.5, 0)
	billboard.Enabled = false
	billboard.Parent = marker
	self._billboard = billboard

	local markerText = label(billboard, "Text", "", UDim2.fromScale(1, 1), nil, Enum.Font.GothamBold, 15)
	markerText.BackgroundColor3 = theme.Colors.PrimaryDark
	markerText.BackgroundTransparency = 0.34
	markerText.TextColor3 = theme.Colors.Sun
	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0, 12)
	markerCorner.Parent = markerText
	local markerStroke = Instance.new("UIStroke")
	markerStroke.Color = Color3.fromRGB(255, 255, 255)
	markerStroke.Thickness = 2
	markerStroke.Transparency = 0.35
	markerStroke.Parent = markerText
	self._markerText = markerText

	self._connection = RunService.RenderStepped:Connect(function(deltaTime)
		self:_render(deltaTime)
	end)
	return self
end

function QuestNavigator:_ownedHome()
	local world = workspace:FindFirstChild("CuteFamilyTown")
	local homes = world and world:FindFirstChild("PlayerHomes")
	if not homes or not self._player then
		return nil
	end
	for _, home in ipairs(homes:GetChildren()) do
		if home:GetAttribute("OwnerUserId") == self._player.UserId then
			return home
		end
	end
	return nil
end

function QuestNavigator:_gardenPart(home)
	local slots = self._state and self._state.Garden and self._state.Garden.Slots or {}
	local fallback = home:FindFirstChild("GardenSlot1")
	for index, slot in ipairs(slots) do
		local matches = self._action == "GardenPlant" and slot.State == "Empty"
			or self._action == "GardenWater" and slot.State == "Planted" and not slot.Watered
			or self._action == "GardenHarvest" and slot.State == "Planted" and (slot.Ready or slot.Watered)
		if matches then
			return home:FindFirstChild(string.format("GardenSlot%d", index)) or fallback
		end
	end
	return fallback
end

function QuestNavigator:_resolveTarget()
	local guide = QuestGuide.get(self._action)
	if not guide then
		return nil
	end
	if guide.Target == "Home" or guide.Target == "HomeGarden" then
		local home = self:_ownedHome()
		if not home then
			return nil
		end
		local targetPart = guide.Target == "HomeGarden" and self:_gardenPart(home)
			or home:FindFirstChild("InteriorSpawn")
			or home:FindFirstChild("Door")
		return targetPart and targetPart.Position or home:GetPivot().Position
	end
	return self._config.Waypoints[guide.Target]
end

function QuestNavigator:_hideTrail()
	for _, trailPart in ipairs(self._trailParts) do
		trailPart.Transparency = 1
	end
	self._trailSegments = 0
	self._trailVisible = false
end

function QuestNavigator:_setNavigationVisible(visible)
	self._billboard.Enabled = visible
	-- The destination glow is intentionally subtle: it remains readable at
	-- night without becoming an opaque wall during the day.
	self._column.Transparency = visible and 0.62 or 1
	self._ring.Transparency = visible and 0.52 or 1
	self._navigationLight.Enabled = visible
	if not visible then
		self:_hideTrail()
	end
end

function QuestNavigator:_trailPart(index)
	local trailPart = self._trailParts[index]
	if trailPart then
		return trailPart
	end
	trailPart = Instance.new("Part")
	trailPart.Name = string.format("GroundPath%02d", index)
	trailPart.Anchored = true
	trailPart.CanCollide = false
	trailPart.CanQuery = false
	trailPart.CanTouch = false
	trailPart.CastShadow = false
	trailPart.Color = self._theme.Colors.Sun
	trailPart.Material = Enum.Material.Neon
	trailPart.Transparency = 1
	trailPart.Parent = self._trailFolder
	self._trailParts[index] = trailPart
	return trailPart
end


function QuestNavigator:_groundPoint(sample, raycastParams)
	local origin = sample + Vector3.new(0, 60, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -180, 0), raycastParams)
	if result then
		return result.Position + Vector3.new(0, 0.12, 0)
	end
	return Vector3.new(sample.X, math.max(0.12, sample.Y - 3), sample.Z)
end

function QuestNavigator:_drawGroundTrail(startPosition)
	if not self._target or self._arrived then
		self:_hideTrail()
		return
	end
	local difference = self._target - startPosition
	local distance = difference.Magnitude
	if distance < 1 then
		self:_hideTrail()
		return
	end

	local segmentCount = math.clamp(math.ceil(distance / TRAIL_SEGMENT_LENGTH), 2, MAX_TRAIL_SEGMENTS)
	local exclusions = { self._markerFolder }
	local character = self._player and self._player.Character
	if character then
		table.insert(exclusions, character)
	end
	local world = workspace:FindFirstChild("CuteFamilyTown")
	if world then
		for _, folderName in ipairs({ "Town", "Decor", "PlayerHomes", "Pets" }) do
			local folder = world:FindFirstChild(folderName)
			if folder then
				table.insert(exclusions, folder)
			end
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = exclusions
	raycastParams.IgnoreWater = true

	local points = {}
	for index = 0, segmentCount do
		local sample = startPosition:Lerp(self._target, index / segmentCount)
		points[index + 1] = self:_groundPoint(sample, raycastParams)
	end
	for index = 1, segmentCount do
		local from = points[index]
		local to = points[index + 1]
		local length = (to - from).Magnitude
		local trailPart = self:_trailPart(index)
		trailPart.Size = Vector3.new(0.72, 0.08, length + 0.18)
		trailPart.CFrame = CFrame.lookAt((from + to) / 2, to)
		trailPart.Transparency = 0.43
	end
	for index = segmentCount + 1, #self._trailParts do
		self._trailParts[index].Transparency = 1
	end
	self._trailSegments = segmentCount
	self._trailVisible = true
end

function QuestNavigator:_setTarget(position)
	local changed = (self._target == nil and position ~= nil)
		or (self._target ~= nil and position == nil)
		or (self._target and position and (self._target - position).Magnitude > 1)
	self._target = position
	if changed then
		self._arrived = false
	end
	local visible = position ~= nil and self._action ~= nil and not self._arrived
	self:_setNavigationVisible(visible)
	if not position then
		return
	end
	self._marker.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	self._column.CFrame = CFrame.new(position + Vector3.new(0, 6, 0))
	self._ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

function QuestNavigator:Track(action, description, descriptionThai)
	local guide = QuestGuide.get(action)
	if not guide then
		self:Clear()
		return false
	end
	self._action = action
	self._description = description or guide.Name
	self._descriptionThai = descriptionThai or guide.NameThai
	self._markerText.Text = self._bilingual(guide.Name, guide.NameThai)
	self:_setTarget(self:_resolveTarget())
	return true
end

function QuestNavigator:Clear()
	self._action = nil
	self._target = nil
	self._arrived = false
	self:_setNavigationVisible(false)
end

function QuestNavigator:Pin(kind)
	self._pin = kind == "Daily" and "Daily" or "Chain"
	if self._state then
		self:Update(self._state)
	end
end

function QuestNavigator:Update(state)
	self._state = state
	local daily = state.Daily and state.Daily.Quest
	local quests = state.Quests
	local chain = quests and self._catalog.QuestChains[quests.ChainIndex]
	local step = chain and chain.Steps[quests.Step]

	if self._pin == "Daily" and daily and not daily.Completed then
		self:Track(daily.Action, daily.Description, daily.DescriptionThai)
	elseif step then
		self._pin = "Chain"
		self:Track(step.Action, step.Description, step.DescriptionThai)
	elseif daily and not daily.Completed then
		self._pin = "Daily"
		self:Track(daily.Action, daily.Description, daily.DescriptionThai)
	else
		self:Clear()
	end
end

function QuestNavigator:_render(deltaTime)
	if not self._action then
		return
	end
	self._refreshClock += deltaTime
	if self._refreshClock < TARGET_REFRESH_SECONDS then
		return
	end
	self._refreshClock = 0
	self:_setTarget(self:_resolveTarget())
	local character = self._player and self._player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		self:UpdatePathFrom(root.Position)
	end
end

-- Public so the same arrival and path behavior can be exercised in a Studio
-- smoke test without fabricating a LocalPlayer character.
function QuestNavigator:UpdatePathFrom(playerPosition)
	if not self._target then
		self:_setNavigationVisible(false)
		return nil
	end
	local distance = (playerPosition - self._target).Magnitude
	if not self._arrived and distance <= ARRIVAL_DISTANCE then
		self._arrived = true
	elseif self._arrived and distance >= RESUME_DISTANCE then
		self._arrived = false
	end

	local visible = self._action ~= nil and not self._arrived
	self:_setNavigationVisible(visible)
	if visible then
		self:_drawGroundTrail(playerPosition - Vector3.new(0, 3, 0))
	end
	return distance
end

function QuestNavigator:GetDebugState()
	return {
		Action = self._action,
		Target = self._target,
		Arrived = self._arrived,
		GroundLineVisible = self._trailVisible,
		TrailSegments = self._trailSegments,
		WaypointVisible = self._billboard.Enabled,
		NavigationLightEnabled = self._navigationLight.Enabled,
		WaypointTransparency = self._column.Transparency,
	}
end

function QuestNavigator:Destroy()
	if self._connection then
		self._connection:Disconnect()
	end
	self._markerFolder:Destroy()
end

return QuestNavigator
