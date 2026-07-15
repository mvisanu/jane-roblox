-- Responsive geometry for the top-left Quest menu. The open panel and its
-- collapsed header share one fixed corner, so opening never moves it to centre.

local QuestBoardLayout = {}

QuestBoardLayout.MARGIN = 16
QuestBoardLayout.TOP_SAFE = 82
QuestBoardLayout.BOTTOM_SAFE = 108
QuestBoardLayout.CLOSED_WIDTH = 220
QuestBoardLayout.CLOSED_HEIGHT = 58
QuestBoardLayout.OPEN_SCALE_FROM_ORIGINAL = 0.5
QuestBoardLayout.ORIGINAL_MAX_WIDTH = 620
QuestBoardLayout.ORIGINAL_MAX_HEIGHT = 620
QuestBoardLayout.ORIGINAL_WIDTH_SCALE = 0.76
QuestBoardLayout.ORIGINAL_HEIGHT_SCALE = 0.82
QuestBoardLayout.ORIGINAL_MIN_WIDTH = 300
QuestBoardLayout.ORIGINAL_MIN_HEIGHT = 180
QuestBoardLayout.OPEN_HEADER_HEIGHT = 42
QuestBoardLayout.BODY_PADDING = 8

-- Larger typography remains explicit and testable even though the window is
-- half-size. Content scrolls vertically instead of shrinking these values.
QuestBoardLayout.HEADER_TEXT_SIZE = 18
QuestBoardLayout.TOGGLE_TEXT_SIZE = 15
QuestBoardLayout.SECTION_TEXT_SIZE = 15
QuestBoardLayout.BODY_TEXT_SIZE = 16
QuestBoardLayout.PROMINENT_TEXT_SIZE = 18
QuestBoardLayout.TITLE_TEXT_SIZE = 20
QuestBoardLayout.STEP_TEXT_SIZE = 17
QuestBoardLayout.BUTTON_TEXT_SIZE = 15
QuestBoardLayout.SMALL_TEXT_SIZE = 14

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

function QuestBoardLayout.open(screenW, screenH)
	local availableW = math.max(1, screenW - QuestBoardLayout.MARGIN * 2)
	local availableH = math.max(1, screenH - QuestBoardLayout.TOP_SAFE - QuestBoardLayout.BOTTOM_SAFE)
	local originalWidth = math.min(
		QuestBoardLayout.ORIGINAL_MAX_WIDTH,
		availableW,
		math.max(QuestBoardLayout.ORIGINAL_MIN_WIDTH, math.floor(screenW * QuestBoardLayout.ORIGINAL_WIDTH_SCALE))
	)
	local originalHeight = math.min(
		QuestBoardLayout.ORIGINAL_MAX_HEIGHT,
		availableH,
		math.max(QuestBoardLayout.ORIGINAL_MIN_HEIGHT, math.floor(screenH * QuestBoardLayout.ORIGINAL_HEIGHT_SCALE))
	)
	return {
		X = QuestBoardLayout.MARGIN,
		Y = QuestBoardLayout.TOP_SAFE,
		Width = math.floor(originalWidth * QuestBoardLayout.OPEN_SCALE_FROM_ORIGINAL),
		Height = math.floor(originalHeight * QuestBoardLayout.OPEN_SCALE_FROM_ORIGINAL),
	}
end

function QuestBoardLayout.closed(screenW, screenH)
	local width = math.min(QuestBoardLayout.CLOSED_WIDTH, math.max(180, screenW - QuestBoardLayout.MARGIN * 2))
	local height = QuestBoardLayout.CLOSED_HEIGHT
	return {
		X = QuestBoardLayout.MARGIN,
		Y = QuestBoardLayout.TOP_SAFE,
		Width = math.floor(width),
		Height = height,
	}
end

function QuestBoardLayout.insideScreen(screenW, screenH, geometry)
	local left = geometry.X
	local right = geometry.X + geometry.Width
	local top = geometry.Y
	local bottom = geometry.Y + geometry.Height
	return left >= 0 and right <= screenW and top >= 0 and bottom <= screenH
end

return table.freeze(QuestBoardLayout)
