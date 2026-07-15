local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local RiverController = {}
RiverController.__index = RiverController

local function insideVolume(volume, worldPosition)
	local localPosition = volume.CFrame:PointToObjectSpace(worldPosition)
	local half = volume.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y + 2
		and math.abs(localPosition.Z) <= half.Z
end

local function flowDirection(volume)
	local direction = Vector3.new(
		volume:GetAttribute("FlowX") or 0,
		0,
		volume:GetAttribute("FlowZ") or 0
	)
	return direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, 1)
end

function RiverController.new(player)
	local self = setmetatable({}, RiverController)
	self._player = player or Players.LocalPlayer
	self._time = 0
	self._ribbons = {}
	self._volumes = {}
	self._connections = {}

	for _, ribbon in ipairs(CollectionService:GetTagged(RemoteNames.RiverCurrentTag)) do
		self:_trackRibbon(ribbon)
	end
	for _, volume in ipairs(CollectionService:GetTagged(RemoteNames.SwimmableWaterTag)) do
		self._volumes[volume] = true
	end

	table.insert(self._connections, CollectionService:GetInstanceAddedSignal(RemoteNames.RiverCurrentTag):Connect(function(ribbon)
		self:_trackRibbon(ribbon)
	end))
	table.insert(self._connections, CollectionService:GetInstanceRemovedSignal(RemoteNames.RiverCurrentTag):Connect(function(ribbon)
		self._ribbons[ribbon] = nil
	end))
	table.insert(self._connections, CollectionService:GetInstanceAddedSignal(RemoteNames.SwimmableWaterTag):Connect(function(volume)
		self._volumes[volume] = true
	end))
	table.insert(self._connections, CollectionService:GetInstanceRemovedSignal(RemoteNames.SwimmableWaterTag):Connect(function(volume)
		self._volumes[volume] = nil
	end))
	table.insert(self._connections, RunService.RenderStepped:Connect(function(deltaTime)
		self:Step(deltaTime)
	end))

	return self
end

function RiverController:_trackRibbon(ribbon)
	if not ribbon:IsA("BasePart") then
		return
	end
	self._ribbons[ribbon] = {
		CFrame = ribbon.CFrame,
		Transparency = ribbon.Transparency,
	}
end

function RiverController:_animateSurface(deltaTime)
	self._time += deltaTime
	for ribbon, base in pairs(self._ribbons) do
		if not ribbon.Parent then
			self._ribbons[ribbon] = nil
		else
			local span = ribbon:GetAttribute("FlowSpan") or 72
			local speed = ribbon:GetAttribute("FlowSpeed") or 5
			local phase = ribbon:GetAttribute("FlowPhase") or 0
			local drift = ribbon:GetAttribute("LateralDrift") or 0.3
			local cycle = self._time * speed + phase * span
			local downstream = cycle % span - span / 2
			local ripple = self._time * 1.7 + phase * math.pi * 2
			ribbon.CFrame = base.CFrame * CFrame.new(
				math.sin(ripple * 0.73) * drift,
				math.sin(ripple) * 0.045,
				downstream
			)
			ribbon.Transparency = math.clamp(base.Transparency + math.sin(ripple) * 0.07, 0.56, 0.88)
		end
	end
end

function RiverController:_applySwimmingCurrent(deltaTime)
	local character = self._player and self._player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		return
	end

	for volume in pairs(self._volumes) do
		if volume.Parent and insideVolume(volume, root.Position) then
			local direction = flowDirection(volume)
			local targetSpeed = volume:GetAttribute("FlowSpeed") or 5.5
			local acceleration = volume:GetAttribute("FlowAcceleration") or 2.4
			if targetSpeed <= 0 or acceleration <= 0 then
				-- Lakes animate visually but have no directional current; normal
				-- Humanoid swimming remains completely player-controlled.
				return
			end
			local velocity = root.AssemblyLinearVelocity
			local downstreamSpeed = velocity:Dot(direction)
			if downstreamSpeed < targetSpeed then
				local addition = math.min(targetSpeed - downstreamSpeed, acceleration * deltaTime)
				-- Only the downstream component changes. Vertical buoyancy and the
				-- player's sideways/upstream input remain under Humanoid control.
				root.AssemblyLinearVelocity = velocity + direction * addition
			end
			return
		end
	end
end

function RiverController:Step(deltaTime)
	deltaTime = math.min(math.max(deltaTime or 0, 0), 0.1)
	self:_animateSurface(deltaTime)
	self:_applySwimmingCurrent(deltaTime)
end

function RiverController:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for ribbon, base in pairs(self._ribbons) do
		if ribbon.Parent then
			ribbon.CFrame = base.CFrame
			ribbon.Transparency = base.Transparency
		end
	end
	table.clear(self._ribbons)
	table.clear(self._volumes)
end

return RiverController
