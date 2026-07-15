return table.freeze({
	Folder = "FamilyTownRemotes",
	Request = "Request",
	StateChanged = "StateChanged",
	Toast = "Toast",
	-- A central Guild prompt only asks the local UI to open; all travel remains
	-- server-authoritative through Request/Teleport.
	GuildAction = "GuildAction",
	-- CollectionService tag on every floating world label, so the client can
	-- fade them by distance and switch them off without hunting the workspace.
	LabelTag = "FamilyTownLabel",
	-- Every placed furniture model carries this, so the client can find, preview
	-- and highlight them without walking the whole workspace.
	FurnitureTag = "FamilyTownFurniture",
	-- Tagged lamp globes are switched on only when the local player's computer
	-- time is outside the 06:00-18:00 daylight window.
	LampTag = "FamilyTownNightLamp",
	-- Terrain supplies real swimming and buoyancy; these tags let the local
	-- river controller animate surface streaks and add a gentle downstream push
	-- without scanning the whole generated world every frame.
	RiverCurrentTag = "FamilyTownRiverCurrent",
	SwimmableWaterTag = "FamilyTownSwimmableWater",
})
