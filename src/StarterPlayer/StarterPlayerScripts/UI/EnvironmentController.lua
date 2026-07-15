local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnvironmentClock = require(Shared:WaitForChild("EnvironmentClock"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local WildwoodStyle = require(Shared:WaitForChild("WildwoodStyle"))
local L = WildwoodStyle.Lighting
local WORLD = WildwoodStyle.World

local EnvironmentController = {}
EnvironmentController.__index = EnvironmentController

local DAY = {
	Ambient = L.DayAmbient,
	OutdoorAmbient = L.DayOutdoor,
	Top = L.DayTop,
	Bottom = L.DayBottom,
	Fog = L.DayFog,
	Atmosphere = WORLD.DayFog,
	Decay = WORLD.Cobble,
}

local NIGHT = {
	Ambient = L.NightAmbient,
	OutdoorAmbient = L.NightOutdoor,
	Top = L.NightTop,
	Bottom = L.NightBottom,
	Fog = L.NightFog,
	Atmosphere = WORLD.Water,
	Decay = WORLD.NightSky,
}

local function mix(nightValue, dayValue, daylight)
	return nightValue:Lerp(dayValue, daylight)
end

local function applyLamp(glow, night)
	if not glow:IsA("BasePart") then
		return
	end
	glow.Material = night and Enum.Material.Neon or Enum.Material.Glass
	glow.Transparency = night and 0.05 or 0.48
	for _, child in ipairs(glow:GetChildren()) do
		if child:IsA("Light") then
			child.Enabled = night
		end
	end
end

function EnvironmentController.new()
	local self = setmetatable({}, EnvironmentController)
	self._elapsed = 0
	self._night = false
	self._connections = {}

	table.insert(self._connections, CollectionService:GetInstanceAddedSignal(RemoteNames.LampTag):Connect(function(glow)
		applyLamp(glow, self._night)
	end))
	table.insert(self._connections, RunService.Heartbeat:Connect(function(deltaTime)
		self._elapsed += deltaTime
		if self._elapsed >= 20 then
			self._elapsed = 0
			self:UpdateFromComputer()
		end
	end))

	self:UpdateFromComputer()
	return self
end

function EnvironmentController:ApplyAtHour(hour)
	hour = EnvironmentClock.normalize(hour)
	local daylight = EnvironmentClock.daylight(hour)
	local night = not EnvironmentClock.isDay(hour)
	self._night = night

	-- ClockTime drives the actual sun and moon position. The remaining values
	-- make midday visibly bright and local night visibly dark rather than merely
	-- moving the sun below an unchanged bright environment.
	Lighting.ClockTime = hour
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 0.55 + 2.05 * daylight
	Lighting.ExposureCompensation = -0.38 + 0.5 * daylight
	Lighting.Ambient = mix(NIGHT.Ambient, DAY.Ambient, daylight)
	Lighting.OutdoorAmbient = mix(NIGHT.OutdoorAmbient, DAY.OutdoorAmbient, daylight)
	Lighting.ColorShift_Top = mix(NIGHT.Top, DAY.Top, daylight)
	Lighting.ColorShift_Bottom = mix(NIGHT.Bottom, DAY.Bottom, daylight)
	Lighting.EnvironmentDiffuseScale = 0.18 + 0.5 * daylight
	Lighting.EnvironmentSpecularScale = 0.2 + 0.22 * daylight
	Lighting.FogColor = mix(NIGHT.Fog, DAY.Fog, daylight)
	Lighting.FogStart = night and 85 or 130
	Lighting.FogEnd = night and 470 or 680

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "LocalTimeAtmosphere"
	atmosphere.Density = 0.4 - 0.12 * daylight
	atmosphere.Offset = 0.18
	atmosphere.Color = mix(NIGHT.Atmosphere, DAY.Atmosphere, daylight)
	atmosphere.Decay = mix(NIGHT.Decay, DAY.Decay, daylight)
	atmosphere.Glare = 0.32 * daylight
	atmosphere.Haze = 2.1 - 0.8 * daylight
	atmosphere.Parent = Lighting

	for _, glow in ipairs(CollectionService:GetTagged(RemoteNames.LampTag)) do
		applyLamp(glow, night)
	end
	return daylight, night
end

function EnvironmentController:UpdateFromComputer()
	local localDate = DateTime.now():ToLocalTime()
	local hour = EnvironmentClock.fromLocalDate(localDate)
	self:ApplyAtHour(hour)
	return hour
end

function EnvironmentController:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return EnvironmentController
