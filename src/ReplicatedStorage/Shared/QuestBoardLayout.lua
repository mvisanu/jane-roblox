-- Responsive geometry for the top-left Quest menu. The open panel and its
-- collapsed header share one fixed corner, so opening never moves it to centre.

local QuestBoardLayout = {}

QuestBoardLayout.MARGIN = 16
QuestBoardLayout.TOP_SAFE = 82
QuestBoardLayout.BOTTOM_SAFE = 108
QuestBoardLayout.CLOSED_WIDTH = 220
QuestBoardLayout.CLOSED_HEIGHT = 58
QuestBoardLayout.MAX_WIDTH = 620
QuestBoardLayout.MAX_HEIGHT = 620
QuestBoardLayout.WIDTH_SCALE = 0.76
QuestBoardLayout.HEIGHT_SCALE = 0.82

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
	local width = math.min(
		QuestBoardLayout.MAX_WIDTH,
		availableW,
		math.max(300, math.floor(screenW * QuestBoardLayout.WIDTH_SCALE))
	)
	local height = math.min(
		QuestBoardLayout.MAX_HEIGHT,
		availableH,
		math.max(180, math.floor(screenH * QuestBoardLayout.HEIGHT_SCALE))
	)
	return {
		X = QuestBoardLayout.MARGIN,
		Y = QuestBoardLayout.TOP_SAFE,
		Width = math.floor(width),
		Height = math.floor(height),
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
