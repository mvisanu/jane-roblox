-- The material bag's reusable four-column grid. The taller cells and larger
-- bilingual labels match the centred activity panel's readable typography.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagInventory = require(Shared:WaitForChild("BagInventory"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local BagGrid = {}

function BagGrid.create(parent, resources, capacity, theme, components, bilingual)
	local stacks = BagInventory.stacks(resources)
	local visibleSlots = math.max(capacity, #stacks) -- legacy overflow stays visible
	local columns = 4
	local cellHeight = 84
	local gap = 6
	local rows = math.ceil(visibleSlots / columns)

	local grid = Instance.new("Frame")
	grid.Name = "BagGrid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, rows * cellHeight + math.max(0, rows - 1) * gap)
	grid.Parent = parent

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.CellSize = UDim2.new(0.25, -5, 0, cellHeight)
	layout.FillDirectionMaxCells = columns
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for index = 1, visibleSlots do
		local stack = stacks[index]
		local resource = stack and Catalog.AdventureResources[stack.Resource]
		local cell = Instance.new("Frame")
		cell.Name = stack and string.format("BagSlot%02d_%s", index, stack.Resource) or string.format("BagSlot%02d_Empty", index)
		cell.BackgroundColor3 = resource and resource.Color or theme.Colors.White
		cell.BackgroundTransparency = resource and 0 or 0.35
		cell.LayoutOrder = index
		cell.Parent = grid
		cell:SetAttribute("SlotIndex", index)
		cell:SetAttribute("ResourceId", stack and stack.Resource or "")
		cell:SetAttribute("StackCount", stack and stack.Count or 0)
		components.corner(cell, theme.SmallCorner)
		components.stroke(cell, resource and resource.Color:Lerp(theme.Colors.Ink, 0.28) or theme.Colors.Border, resource and 2 or 1, 0)

		local icon = Instance.new("TextLabel")
		icon.Name = "ItemIcon"
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBold
		icon.Position = UDim2.fromOffset(3, 3)
		icon.Size = UDim2.new(1, -6, 0, 38)
		icon.Text = resource and resource.Icon or "+"
		icon.TextColor3 = resource and theme.textOn(resource.Color) or theme.Colors.Muted
		icon.TextSize = resource and 25 or 18
		icon.Parent = cell

		local label = Instance.new("TextLabel")
		label.Name = "ItemName"
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Position = UDim2.fromOffset(3, 43)
		label.Size = UDim2.new(1, -6, 0, 37)
		label.Text = resource and bilingual(resource.DisplayName, resource.DisplayNameThai) or string.format("SLOT %02d\nช่อง %02d", index, index)
		label.TextColor3 = resource and theme.textOn(resource.Color) or theme.Colors.Muted
		label.TextSize = resource and 12 or 11
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = cell

		if stack then
			local count = Instance.new("TextLabel")
			count.Name = "StackCount"
			count.AnchorPoint = Vector2.new(1, 0)
			count.BackgroundColor3 = theme.Colors.Ink
			count.Position = UDim2.new(1, -4, 0, 4)
			count.Size = UDim2.fromOffset(26, 22)
			count.Font = Enum.Font.GothamBold
			count.Text = tostring(stack.Count)
			count.TextColor3 = theme.textOn(theme.Colors.Ink)
			count.TextSize = 13
			count.Parent = cell
			components.corner(count, UDim.new(1, 0))
		end
	end

	return grid
end

return BagGrid
