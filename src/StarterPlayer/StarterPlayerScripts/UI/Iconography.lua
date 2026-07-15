-- Clean code-native pictograms. These are built from Roblox UI primitives, so
-- they stay sharp at every resolution and never depend on an uploaded image.
local Iconography = {}

local function tint(instance)
	instance:SetAttribute("IconTint", true)
	return instance
end

local function corner(parent, radius)
	local object = Instance.new("UICorner")
	object.CornerRadius = UDim.new(radius or 1, 0)
	object.Parent = parent
	return object
end

local function shape(parent, name, x, y, width, height, color, rotation, radius, transparency)
	local object = tint(Instance.new("Frame"))
	object.Name = name
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.BackgroundColor3 = color
	object.BackgroundTransparency = transparency or 0
	object.BorderSizePixel = 0
	object.Position = UDim2.fromScale(x, y)
	object.Rotation = rotation or 0
	object.Size = UDim2.fromScale(width, height)
	object.Parent = parent
	if radius then
		corner(object, radius)
	end
	return object
end

local function outline(parent, name, x, y, width, height, color, radius, thickness)
	local object = Instance.new("Frame")
	object.Name = name
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.BackgroundTransparency = 1
	object.Position = UDim2.fromScale(x, y)
	object.Size = UDim2.fromScale(width, height)
	object.Parent = parent
	corner(object, radius or 0.18)
	local line = tint(Instance.new("UIStroke"))
	line.Color = color
	line.Thickness = thickness or 2
	line.Parent = object
	return object
end

local function home(icon, color)
	shape(icon, "RoofLeft", 0.34, 0.3, 0.55, 0.14, color, -38, 0.08)
	shape(icon, "RoofRight", 0.66, 0.3, 0.55, 0.14, color, 38, 0.08)
	shape(icon, "House", 0.5, 0.65, 0.58, 0.5, color, 0, 0.1)
	shape(icon, "Door", 0.5, 0.73, 0.16, 0.34, color, 0, 0.08, 0.45)
end

local function garden(icon, color)
	shape(icon, "Stem", 0.5, 0.67, 0.1, 0.5, color, 0, 0.08)
	shape(icon, "LeafLeft", 0.36, 0.65, 0.3, 0.16, color, -28, 0.5)
	shape(icon, "LeafRight", 0.64, 0.57, 0.3, 0.16, color, 28, 0.5)
	for index, at in ipairs({ { 0.5, 0.23 }, { 0.33, 0.34 }, { 0.67, 0.34 }, { 0.4, 0.47 }, { 0.6, 0.47 } }) do
		shape(icon, "Petal" .. index, at[1], at[2], 0.3, 0.3, color, 0, 1)
	end
	shape(icon, "FlowerCenter", 0.5, 0.36, 0.24, 0.24, color, 0, 1, 0.35)
end

local function pet(icon, color)
	shape(icon, "PawPad", 0.5, 0.66, 0.52, 0.42, color, 0, 0.5)
	for index, at in ipairs({ { 0.24, 0.38 }, { 0.42, 0.24 }, { 0.62, 0.24 }, { 0.78, 0.4 } }) do
		shape(icon, "Toe" .. index, at[1], at[2], 0.23, 0.28, color, (index - 2.5) * 8, 1)
	end
end

local function cafe(icon, color)
	shape(icon, "Cup", 0.43, 0.54, 0.58, 0.42, color, 0, 0.15)
	outline(icon, "Handle", 0.78, 0.52, 0.3, 0.3, color, 1, 3)
	shape(icon, "Saucer", 0.5, 0.82, 0.84, 0.09, color, 0, 1)
	for index, x in ipairs({ 0.37, 0.58 }) do
		shape(icon, "Steam" .. index, x, 0.19, 0.09, 0.3, color, index == 1 and 15 or -15, 1, 0.2)
	end
end

local function adventure(icon, color)
	outline(icon, "CompassRing", 0.5, 0.5, 0.78, 0.78, color, 1, 3)
	shape(icon, "NeedleNorth", 0.44, 0.39, 0.16, 0.5, color, 32, 0.2)
	shape(icon, "NeedleSouth", 0.58, 0.62, 0.13, 0.4, color, 32, 0.2, 0.45)
	shape(icon, "CompassDot", 0.5, 0.5, 0.14, 0.14, color, 0, 1)
end

local function bag(icon, color)
	shape(icon, "BagBody", 0.5, 0.62, 0.68, 0.55, color, 0, 0.2)
	outline(icon, "BagHandle", 0.5, 0.31, 0.4, 0.34, color, 1, 3)
	shape(icon, "BagFlap", 0.5, 0.48, 0.46, 0.1, color, 0, 1, 0.38)
end

local function style(icon, color)
	shape(icon, "ShirtBody", 0.5, 0.58, 0.48, 0.62, color, 0, 0.1)
	shape(icon, "SleeveLeft", 0.25, 0.36, 0.38, 0.24, color, -28, 0.12)
	shape(icon, "SleeveRight", 0.75, 0.36, 0.38, 0.24, color, 28, 0.12)
	shape(icon, "Neck", 0.5, 0.27, 0.2, 0.15, color, 0, 1, 0.45)
end

local function map(icon, color)
	shape(icon, "MapLeft", 0.25, 0.53, 0.3, 0.66, color, -6, 0.08)
	shape(icon, "MapMiddle", 0.5, 0.47, 0.3, 0.66, color, 6, 0.08, 0.22)
	shape(icon, "MapRight", 0.75, 0.53, 0.3, 0.66, color, -6, 0.08)
	for index, at in ipairs({ { 0.27, 0.64 }, { 0.48, 0.48 }, { 0.7, 0.35 } }) do
		shape(icon, "RouteDot" .. index, at[1], at[2], 0.1, 0.1, color, 0, 1, 0.46)
	end
end

local function coin(icon, color)
	shape(icon, "Coin", 0.5, 0.5, 0.82, 0.82, color, 0, 1)
	local mark = tint(Instance.new("TextLabel"))
	mark.Name = "CoinMark"
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.GothamBlack
	mark.Position = UDim2.fromScale(0.2, 0.16)
	mark.Size = UDim2.fromScale(0.6, 0.68)
	mark.Text = "C"
	mark.TextColor3 = color
	mark.TextSize = 18
	mark.TextTransparency = 0.42
	mark.Parent = icon
end

local function gift(icon, color)
	shape(icon, "GiftBox", 0.5, 0.64, 0.76, 0.48, color, 0, 0.1)
	shape(icon, "GiftLid", 0.5, 0.4, 0.88, 0.18, color, 0, 0.08)
	shape(icon, "RibbonVertical", 0.5, 0.6, 0.14, 0.58, color, 0, 0.04, 0.35)
	shape(icon, "RibbonLeft", 0.39, 0.24, 0.34, 0.2, color, -28, 1)
	shape(icon, "RibbonRight", 0.61, 0.24, 0.34, 0.2, color, 28, 1)
end

local function location(icon, color)
	shape(icon, "PinHead", 0.5, 0.38, 0.58, 0.58, color, 0, 1)
	shape(icon, "PinTail", 0.5, 0.67, 0.34, 0.34, color, 45, 0.08)
	shape(icon, "PinCenter", 0.5, 0.38, 0.2, 0.2, color, 0, 1, 0.5)
end

local function quest(icon, color)
	outline(icon, "Clipboard", 0.5, 0.56, 0.68, 0.7, color, 0.14, 3)
	shape(icon, "Clip", 0.5, 0.2, 0.34, 0.16, color, 0, 0.3)
	shape(icon, "CheckShort", 0.32, 0.53, 0.22, 0.09, color, 45, 0.08)
	shape(icon, "CheckLong", 0.48, 0.47, 0.36, 0.09, color, -42, 0.08)
	shape(icon, "Line", 0.58, 0.72, 0.38, 0.08, color, 0, 1, 0.25)
end

local function close(icon, color)
	shape(icon, "SlashOne", 0.5, 0.5, 0.72, 0.12, color, 45, 1)
	shape(icon, "SlashTwo", 0.5, 0.5, 0.72, 0.12, color, -45, 1)
end

local BUILDERS = {
	Home = home,
	Garden = garden,
	Pet = pet,
	Cafe = cafe,
	Adventure = adventure,
	Bag = bag,
	Style = style,
	Map = map,
	Coin = coin,
	Gift = gift,
	Location = location,
	Quest = quest,
	Close = close,
}

function Iconography.create(parent, kind, color, size)
	local builder = BUILDERS[kind]
	assert(builder, string.format("Unknown icon kind: %s", tostring(kind)))
	local icon = Instance.new("Frame")
	icon.Name = kind .. "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(size or 28, size or 28)
	icon:SetAttribute("CleanIcon", true)
	icon:SetAttribute("IconKind", kind)
	icon.Parent = parent
	builder(icon, color)
	return icon
end

function Iconography.setColor(icon, color)
	for _, descendant in ipairs(icon:GetDescendants()) do
		if descendant:GetAttribute("IconTint") then
			if descendant:IsA("UIStroke") then
				descendant.Color = color
			elseif descendant:IsA("TextLabel") then
				descendant.TextColor3 = color
			else
				descendant.BackgroundColor3 = color
			end
		end
	end
end

Iconography.Kinds = table.freeze({
	"Home", "Garden", "Pet", "Cafe", "Adventure", "Bag", "Style", "Map",
	"Coin", "Gift", "Location", "Quest", "Close",
})

return table.freeze(Iconography)
