local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Components = {}

function Components.corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corner
	corner.Parent = parent
	return corner
end

function Components.stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.White
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Components.shadow(parent)
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageColor3 = Theme.Colors.Shadow
	shadow.ImageTransparency = 0.75
	shadow.Position = UDim2.fromScale(0.5, 0.54)
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.Size = UDim2.new(1, 24, 1, 24)
	shadow.ZIndex = math.max(0, parent.ZIndex - 1)
	shadow.Parent = parent
	return shadow
end

function Components.label(parent, text, size, position, textSize, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.fromOffset(0, 0)
	label.Font = bold and Theme.Fonts.Headline or Theme.Fonts.Body
	label.Text = text
	label.TextColor3 = Theme.Colors.Ink
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function Components.button(parent, text, color, callback)
	local fill = color or Theme.Colors.Primary
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = fill
	button.Size = UDim2.new(1, 0, 0, Theme.TouchHeight)
	button.Font = Theme.Fonts.Headline
	-- Ink or white, whichever can be read on this fill. Seed buttons are painted
	-- the flower's colour, and a daisy is nearly white, so this cannot be assumed.
	button.TextColor3 = Theme.textOn(fill)
	button.Text = text
	button.TextSize = 12
	button.TextWrapped = true
	button.Parent = parent
	Components.corner(button, Theme.SmallCorner)
	-- A white outline vanishes on a pale button; outline against the text instead.
	Components.stroke(button, Theme.textOn(fill), 2, 0.55)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = fill:Lerp(Theme.Colors.Ink, 0.12) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = fill }):Play()
	end)
	button.Activated:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08), { Size = UDim2.new(1, -6, 0, Theme.TouchHeight - 3) }):Play()
		task.delay(0.09, function()
			if button.Parent then
				TweenService:Create(button, TweenInfo.new(0.1), { Size = UDim2.new(1, 0, 0, Theme.TouchHeight) }):Play()
			end
		end)
		callback()
	end)
	return button
end

function Components.list(parent, padding)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = parent
	return layout
end

return table.freeze(Components)
