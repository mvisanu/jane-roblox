--[[
	Theme: the green palette, and the rule that keeps text readable on it.

	The garden's "Plant Daisy" button used to be unreadable. Not because the green
	was wrong, but because every button painted its text white regardless of what
	colour it sat on - and a seed button is painted the flower's own colour. A
	daisy is pale yellow, so it was white text on near-white: a contrast ratio of
	about 1.1 to 1, where 4.5 is the readable minimum.

	Painting the buttons darker would have papered over that. The real fix is
	`Theme.textOn`: ask what colour a background needs its text to be, and get
	back ink or white - whichever a reader can actually see. That holds for every
	colour in this file *and* for the flower colours in Catalog, which the theme
	does not control and should not have to.

	`scripts/contrast_test.py` checks every pairing this game can produce against
	WCAG AA (4.5:1), so "can you read it" is a test rather than an opinion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WildwoodStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildwoodStyle"))
local W = WildwoodStyle.Colors

local Colors = {
	-- Surfaces
	Surface = W.Surface,
	White = W.White,
	Border = W.StoneLight,
	Selected = W.ParchmentLight,

	-- Text
	Ink = W.Ink,
	Muted = W.MutedInk,

	-- The greens that carry the scheme
	Primary = W.ForestGreen,
	PrimaryDark = W.ForestDark,
	Leaf = Color3.fromRGB(95, 123, 75),
	Water = W.SlateBlue,
	Slate = W.EarthBrown,

	-- Warm accents, kept for meaning (harvest, reward, danger), not decoration
	Sun = W.GoldenYellow,
	Berry = W.MutedOrange,

	Shadow = W.DarkEarth,
}

--[[
	WCAG relative luminance, then contrast ratio. Straight from the spec: this is
	the same arithmetic a browser accessibility checker runs.
]]
local function channel(value)
	if value <= 0.03928 then
		return value / 12.92
	end
	return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

local function contrast(a, b)
	local high, low = luminance(a), luminance(b)
	if high < low then
		high, low = low, high
	end
	return (high + 0.05) / (low + 0.05)
end

local Theme = {
	Colors = Colors,
	Fonts = WildwoodStyle.Fonts,
	FontNames = WildwoodStyle.FontNames,
	Corner = UDim.new(0, 18),
	SmallCorner = UDim.new(0, 12),
	TouchHeight = 62,
	MinContrast = 4.5, -- WCAG AA for normal text
}

Theme.contrast = contrast

--[[
	The readable text colour for this background: ink or white, whichever a
	player can actually see. Any colour may be passed, including the flower
	colours from Catalog that this file knows nothing about.
]]
function Theme.textOn(background)
	if contrast(Colors.Ink, background) >= contrast(Colors.White, background) then
		return Colors.Ink
	end
	return Colors.White
end

return table.freeze(Theme)
