--[[
	HudLayout: responsive geometry for the activity panel opened by the bottom
	tab bar (HOME, GARDEN, PET, CAFE, ADVENTURE, BAG, STYLE and MAP).

	The panel opens in the visual centre of the usable screen, between the top
	status controls and the bottom navigation bar. All values are pixels and this
	module deliberately uses plain Lua so scripts/hud_layout_test.py can exercise
	the exact shipping geometry without Roblox Studio.
]]

local HudLayout = {}

HudLayout.MARGIN = 16
HudLayout.TOP_SAFE = 92
HudLayout.BOTTOM_SAFE = 112

HudLayout.WIDTH_SCALE = 0.78
HudLayout.HEIGHT_SCALE = 0.72
HudLayout.MIN_W = 360
HudLayout.MAX_W = 680
HudLayout.MIN_H = 140
HudLayout.MAX_H = 620

-- Activity-panel typography contracts. Keeping these beside the geometry lets
-- both the client and the real-engine smoke test read the same values.
HudLayout.TITLE_TEXT_SIZE = 20
HudLayout.HEADING_TEXT_SIZE = 17
HudLayout.BODY_TEXT_SIZE = 15
HudLayout.CONTROL_TEXT_SIZE = 15
HudLayout.SCROLLBAR_THICKNESS = 8

-- Approved character sheet: three male models in the first row and three
-- female models in the second. Group headers keep the separation explicit.
HudLayout.AVATAR_GRID_COLUMNS = 3
HudLayout.AVATAR_GRID_GAP = 12
HudLayout.AVATAR_CARD_HEIGHT = 220
HudLayout.AVATAR_PREVIEW_HEIGHT = 154
HudLayout.AVATAR_GENDER_HEADER_HEIGHT = 40
HudLayout.AVATAR_GENDER_GAP = 14
HudLayout.AVATAR_GENDER_GROUP_HEIGHT = HudLayout.AVATAR_GENDER_HEADER_HEIGHT + HudLayout.AVATAR_CARD_HEIGHT
HudLayout.AVATAR_GRID_HEIGHT = HudLayout.AVATAR_GENDER_GROUP_HEIGHT * 2 + HudLayout.AVATAR_GENDER_GAP

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

-- Size the panel generously for bilingual copy while keeping it inside the
-- safe rectangle. On a short landscape phone, the lower bound yields to the
-- available height so the bottom navigation can never be covered.
function HudLayout.panelSize(screenW, screenH)
	local availableWidth = math.max(1, screenW - HudLayout.MARGIN * 2)
	local availableHeight = math.max(1, screenH - HudLayout.TOP_SAFE - HudLayout.BOTTOM_SAFE)

	local width = math.min(HudLayout.WIDTH_SCALE * screenW, HudLayout.MAX_W, availableWidth)
	width = clamp(width, math.min(HudLayout.MIN_W, availableWidth), HudLayout.MAX_W)

	local height = math.min(HudLayout.HEIGHT_SCALE * screenH, HudLayout.MAX_H, availableHeight)
	height = clamp(height, math.min(HudLayout.MIN_H, availableHeight), HudLayout.MAX_H)

	return math.floor(width), math.floor(height)
end

-- Keep a dragged panel completely inside the same safe rectangle.
function HudLayout.clamp(screenW, screenH, width, height, x, y)
	local maxX = math.max(HudLayout.MARGIN, screenW - width - HudLayout.MARGIN)
	local maxY = math.max(HudLayout.TOP_SAFE, screenH - height - HudLayout.BOTTOM_SAFE)
	return clamp(x, HudLayout.MARGIN, maxX), clamp(y, HudLayout.TOP_SAFE, maxY)
end

-- Default position: centred horizontally and vertically in the usable band.
function HudLayout.center(screenW, screenH, width, height)
	local x = (screenW - width) / 2
	local usableHeight = screenH - HudLayout.TOP_SAFE - HudLayout.BOTTOM_SAFE
	local y = HudLayout.TOP_SAFE + (usableHeight - height) / 2
	return HudLayout.clamp(screenW, screenH, width, height, math.floor(x), math.floor(y))
end

-- Kept as a compatibility alias for older callers; its home is now the centre.
function HudLayout.dock(screenW, screenH, width, height)
	return HudLayout.center(screenW, screenH, width, height)
end

function HudLayout.coversCentre(screenW, screenH, width, height, x, y)
	local cx, cy = screenW / 2, screenH / 2
	return x <= cx and cx <= x + width and y <= cy and cy <= y + height
end

return HudLayout
