-- Direct-select cottage paint palette. Every button uses the real
-- server-approved color so all choices are visible before repainting.

local HomePalette = {}

function HomePalette.create(parent, colors, currentName, theme, components, bilingual, onChoose)
	local palette = Instance.new("Frame")
	palette.Name = "HomeColorPalette"
	palette.BackgroundTransparency = 1
	palette.Size = UDim2.new(1, 0, 0, 266)
	palette.Parent = parent

	local heading = Instance.new("TextLabel")
	heading.Name = "PaletteHeading"
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, 0, 0, 22)
	heading.Font = theme.Fonts.Headline
	heading.Text = "สีผนังและหลังคาหลัก / WALLS & MAIN ROOF"
	heading.TextColor3 = theme.Colors.PrimaryDark
	heading.TextSize = 15
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = palette

	local current = colors[1]
	for _, entry in ipairs(colors) do
		if entry.Name == currentName then
			current = entry
			break
		end
	end

	local selectedPreview = Instance.new("Frame")
	selectedPreview.Name = "SelectedColorPreview"
	selectedPreview.BackgroundColor3 = theme.Colors.Selected
	selectedPreview.Position = UDim2.fromOffset(0, 28)
	selectedPreview.Size = UDim2.new(1, 0, 0, 42)
	selectedPreview.Parent = palette
	components.corner(selectedPreview, theme.SmallCorner)
	components.stroke(selectedPreview, theme.Colors.Sun, 2, 0.12)

	local selectedCaption = Instance.new("TextLabel")
	selectedCaption.Name = "Caption"
	selectedCaption.BackgroundTransparency = 1
	selectedCaption.Position = UDim2.fromOffset(12, 0)
	selectedCaption.Size = UDim2.new(0.48, -12, 1, 0)
	selectedCaption.Font = theme.Fonts.Headline
	selectedCaption.Text = "สีที่เลือก / SELECTED COLOR"
	selectedCaption.TextColor3 = theme.Colors.Ink
	selectedCaption.TextSize = 11
	selectedCaption.TextXAlignment = Enum.TextXAlignment.Left
	selectedCaption.Parent = selectedPreview

	local colorChip = Instance.new("Frame")
	colorChip.Name = "ColorChip"
	colorChip.AnchorPoint = Vector2.new(0, 0.5)
	colorChip.BackgroundColor3 = current.Color
	colorChip.Position = UDim2.new(0.5, 0, 0.5, 0)
	colorChip.Size = UDim2.fromOffset(36, 26)
	colorChip:SetAttribute("PaintColor", current.Name)
	colorChip:SetAttribute("Hex", current.Hex)
	colorChip.Parent = selectedPreview
	components.corner(colorChip, UDim.new(0, 5))
	components.stroke(colorChip, theme.Colors.White, 2, 0.18)

	local selectedName = Instance.new("TextLabel")
	selectedName.Name = "ColorName"
	selectedName.BackgroundTransparency = 1
	selectedName.Position = UDim2.new(0.5, 44, 0, 0)
	selectedName.Size = UDim2.new(0.5, -52, 1, 0)
	selectedName.Font = theme.Fonts.Headline
	selectedName.Text = bilingual(current.DisplayName, current.NameThai)
	selectedName.TextColor3 = theme.Colors.Ink
	selectedName.TextSize = 10
	selectedName.TextWrapped = true
	selectedName.TextXAlignment = Enum.TextXAlignment.Left
	selectedName.Parent = selectedPreview

	local swatches = Instance.new("Frame")
	swatches.Name = "Swatches"
	swatches.BackgroundTransparency = 1
	swatches.Position = UDim2.fromOffset(0, 82)
	swatches.Size = UDim2.new(1, 0, 0, 176)
	swatches.Parent = palette

	local positions = {
		UDim2.new(0, 0, 0, 0),
		UDim2.new(1 / 3, 3, 0, 0),
		UDim2.new(2 / 3, 6, 0, 0),
		UDim2.new(1 / 6, -2, 0, 92),
		UDim2.new(1 / 2, 2, 0, 92),
	}

	for index, entry in ipairs(colors) do
		local selected = entry.Name == currentName
		local button = Instance.new("TextButton")
		button.Name = "Paint_" .. entry.Name
		button.AutoButtonColor = false
		button.BackgroundColor3 = entry.Color
		button.Font = theme.Fonts.Headline
		button.LayoutOrder = index
		button.Position = positions[index]
		button.Size = UDim2.new(1 / 3, -6, 0, 84)
		button.Text = string.format("%s\n%s", string.upper(entry.DisplayName), entry.Hex)
		button.TextColor3 = theme.textOn(entry.Color)
		button.TextSize = 13
		button.TextWrapped = true
		button:SetAttribute("PaintColor", entry.Name)
		button:SetAttribute("Hex", entry.Hex)
		button:SetAttribute("Selected", selected)
		button:SetAttribute("SwatchR", math.round(entry.Color.R * 255))
		button:SetAttribute("SwatchG", math.round(entry.Color.G * 255))
		button:SetAttribute("SwatchB", math.round(entry.Color.B * 255))
		button.Parent = swatches
		components.corner(button, theme.SmallCorner)
		components.stroke(button, selected and theme.Colors.Sun or theme.Colors.Selected, selected and 4 or 2, selected and 0 or 0.08)

		if selected then
			local badge = Instance.new("TextLabel")
			badge.Name = "SelectedBadge"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.BackgroundColor3 = theme.Colors.Selected
			badge.Position = UDim2.new(1, -6, 0, 6)
			badge.Size = UDim2.fromOffset(28, 28)
			badge.Font = theme.Fonts.Headline
			badge.Text = "✓"
			badge.TextColor3 = theme.Colors.Ink
			badge.TextSize = 16
			badge.Parent = button
			components.corner(badge, UDim.new(1, 0))
		end

		button.Activated:Connect(function()
			if not selected then
				onChoose(entry.Name)
			end
		end)
	end

	return palette
end

return HomePalette
