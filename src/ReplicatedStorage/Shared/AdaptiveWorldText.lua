--[[
	Keeps background-free world text readable while the camera moves.

	A BillboardGui cannot sample the final rendered pixel behind itself, but it
	can cast a ray from the label away from the camera and inspect the first world
	surface behind the words. The module then chooses approved light or dark ink
	by measured WCAG contrast. If the ray sees only sky, local day/night lighting
	provides the backdrop instead.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WildwoodStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildwoodStyle"))

local AdaptiveWorldText = {
	DarkText = WildwoodStyle.Colors.Ink,
	LightText = WildwoodStyle.Colors.White,
	MinContrast = 4.5,
}

local function channel(value)
	if value <= 0.04045 then
		return value / 12.92
	end
	return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

local function contrast(first, second)
	local high, low = luminance(first), luminance(second)
	if high < low then
		high, low = low, high
	end
	return (high + 0.05) / (low + 0.05)
end

AdaptiveWorldText.contrast = contrast

function AdaptiveWorldText.textFor(background)
	if contrast(AdaptiveWorldText.DarkText, background) >= contrast(AdaptiveWorldText.LightText, background) then
		return AdaptiveWorldText.DarkText
	end
	return AdaptiveWorldText.LightText
end

function AdaptiveWorldText.defaultBackdrop()
	local hour = Lighting.ClockTime or 12
	if hour < 6 or hour >= 18 then
		return WildwoodStyle.World.NightSky
	end
	return WildwoodStyle.World.DaySky
end

function AdaptiveWorldText.backdropAt(camera, worldPosition, exclusions)
	if not camera or not worldPosition then
		return AdaptiveWorldText.defaultBackdrop()
	end
	local throughLabel = worldPosition - camera.CFrame.Position
	if throughLabel.Magnitude < 0.1 then
		return AdaptiveWorldText.defaultBackdrop()
	end

	local direction = throughLabel.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions or {}
	params.IgnoreWater = false
	local result = workspace:Raycast(worldPosition + direction * 0.75, direction * 500, params)
	local instance = result and result.Instance
	if instance and instance:IsA("BasePart") then
		return instance.Color
	end
	return AdaptiveWorldText.defaultBackdrop()
end

function AdaptiveWorldText.apply(label, background)
	local textColor = AdaptiveWorldText.textFor(background)
	local lightText = textColor == AdaptiveWorldText.LightText
	label.TextColor3 = textColor
	label.TextStrokeColor3 = lightText and AdaptiveWorldText.DarkText or AdaptiveWorldText.LightText
	label.TextStrokeTransparency = 0.08
	label:SetAttribute("AdaptiveWorldText", true)
	label:SetAttribute("MeasuredContrast", contrast(textColor, background))
	return textColor
end

function AdaptiveWorldText.update(label, camera, worldPosition, exclusions)
	return AdaptiveWorldText.apply(label, AdaptiveWorldText.backdropAt(camera, worldPosition, exclusions))
end

return table.freeze(AdaptiveWorldText)
