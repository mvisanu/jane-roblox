return table.freeze({
	Folder = "FamilyTownRemotes",
	Request = "Request",
	StateChanged = "StateChanged",
	Toast = "Toast",
	-- CollectionService tag on every floating world label, so the client can
	-- fade them by distance and switch them off without hunting the workspace.
	LabelTag = "FamilyTownLabel",
	-- Every placed furniture model carries this, so the client can find, preview
	-- and highlight them without walking the whole workspace.
	FurnitureTag = "FamilyTownFurniture",
	-- Tagged lamp globes are switched on only when the local player's computer
	-- time is outside the 06:00-18:00 daylight window.
	LampTag = "FamilyTownNightLamp",
})
