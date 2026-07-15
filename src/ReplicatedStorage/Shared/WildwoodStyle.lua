--[[
	Wildwood visual system.

	These values are transcribed from:
	theme/stitch_roblox_color_code_extractor/wildwood_adventure/DESIGN.md
	and the supplied mood, architecture, environment, character and animal sheets.

	The web references specify Plus Jakarta Sans for display text and Quicksand
	for body copy. Roblox cannot load a local Google-font file into a place, so
	GothamBold/GothamMedium are the bundled, game-safe equivalents with the same
	friendly geometric/rounded roles. Carved signs use FredokaOne for the chunky
	hand-lettered silhouette shown on the reference boards.
]]

local WildwoodStyle = {}

WildwoodStyle.Reference = "stitch_roblox_color_code_extractor"
WildwoodStyle.FontNames = {
	Headline = "Plus Jakarta Sans",
	Body = "Quicksand",
	Sign = "Wildwood carved display",
}
WildwoodStyle.Fonts = {
	Headline = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Sign = Enum.Font.FredokaOne,
}

WildwoodStyle.Colors = {
	Surface = Color3.fromRGB(255, 248, 240), -- #FFF8F0
	SurfaceLow = Color3.fromRGB(255, 243, 216), -- #FFF3D8
	Parchment = Color3.fromRGB(235, 217, 171), -- #EBD9AB
	ParchmentLight = Color3.fromRGB(240, 222, 179), -- #F0DEB3
	Ink = Color3.fromRGB(35, 27, 0), -- #231B00
	MutedInk = Color3.fromRGB(67, 72, 64), -- #434840
	ForestGreen = Color3.fromRGB(79, 107, 69), -- #4F6B45
	ForestDark = Color3.fromRGB(56, 83, 47), -- #38532F
	ForestLight = Color3.fromRGB(176, 208, 162), -- #B0D0A2
	EarthBrown = Color3.fromRGB(107, 94, 60), -- #6B5E3C
	DarkEarth = Color3.fromRGB(74, 63, 41), -- #4A3F29
	MutedOrange = Color3.fromRGB(217, 128, 72), -- #D98048
	GoldenYellow = Color3.fromRGB(246, 215, 122), -- #F6D77A
	SlateBlue = Color3.fromRGB(111, 160, 177), -- #6FA0B1
	Stone = Color3.fromRGB(116, 121, 111), -- #74796F
	StoneLight = Color3.fromRGB(195, 200, 189), -- #C3C8BD
	White = Color3.fromRGB(255, 255, 255),
	Error = Color3.fromRGB(186, 26, 26),
}

-- Approved A — Bakery Bay town palette. Every visible world surface resolves
-- through these sampled or companion-designed swatches. UI colours and the
-- character/pet palettes below remain independent by explicit user request.
WildwoodStyle.World = {
	TimberDeep = Color3.fromRGB(29, 17, 8), -- #1D1108
	TimberDark = Color3.fromRGB(42, 31, 20), -- #2A1F14
	TimberMid = Color3.fromRGB(69, 44, 23), -- #452C17
	TimberWarm = Color3.fromRGB(89, 58, 32), -- #593A20
	TimberLight = Color3.fromRGB(147, 103, 63), -- #93673F
	RoofShadow = Color3.fromRGB(59, 35, 21), -- #3B2315
	RoofTile = Color3.fromRGB(130, 78, 48), -- #824E30
	RoofHighlight = Color3.fromRGB(149, 98, 59), -- #95623B
	StoneDeep = Color3.fromRGB(45, 41, 35), -- #2D2923
	Stone = Color3.fromRGB(75, 67, 58), -- #4B433A
	StoneLight = Color3.fromRGB(126, 112, 97), -- #7E7061
	Cobble = Color3.fromRGB(95, 83, 71), -- #5F5347
	Plaster = Color3.fromRGB(197, 160, 117), -- #C5A075
	CanvasLight = Color3.fromRGB(224, 200, 165), -- #E0C8A5
	Terracotta = Color3.fromRGB(129, 68, 39), -- #814427
	FoliageDeep = Color3.fromRGB(32, 34, 19), -- #202213
	Foliage = Color3.fromRGB(52, 56, 27), -- #34381B
	Grass = Color3.fromRGB(69, 72, 34), -- #454822
	FoliageLight = Color3.fromRGB(91, 93, 45), -- #5B5D2D
	Soil = Color3.fromRGB(54, 39, 25), -- #362719
	Water = Color3.fromRGB(79, 103, 96), -- #4F6760
	WaterLight = Color3.fromRGB(130, 150, 138), -- #82968A
	-- User-approved clear river pair. Kept separate from the muted architectural
	-- water roles so changing the river does not recolour windows, flowers, UI,
	-- café food or the River Warden outfit.
	ClearWater = Color3.fromRGB(68, 169, 226), -- #44A9E2
	ClearWaterLight = Color3.fromRGB(188, 235, 250), -- #BCEBFA
	Window = Color3.fromRGB(217, 162, 90), -- #D9A25A
	Lantern = Color3.fromRGB(240, 184, 90), -- #F0B85A
	Glass = Color3.fromRGB(215, 187, 149), -- #D7BB95
	Flower = Color3.fromRGB(224, 200, 165), -- #E0C8A5
	DaySky = Color3.fromRGB(215, 187, 149), -- #D7BB95
	DayFog = Color3.fromRGB(198, 168, 131), -- #C6A883
	NightSky = Color3.fromRGB(27, 27, 32), -- #1B1B20
}

-- Compatibility roles still name the architectural function, but point only
-- at the approved Bakery Bay palette above—no legacy village swatches remain.
WildwoodStyle.World.PlasterShade = WildwoodStyle.World.CanvasLight
WildwoodStyle.World.RoofShade = WildwoodStyle.World.RoofShadow
WildwoodStyle.World.Moss = WildwoodStyle.World.FoliageDeep
WildwoodStyle.World.FoliageDark = WildwoodStyle.World.FoliageDeep
WildwoodStyle.World.Banner = WildwoodStyle.World.Terracotta
WildwoodStyle.World.Brown = WildwoodStyle.World.TimberDeep
WildwoodStyle.World.Hickory = WildwoodStyle.World.TimberDark
WildwoodStyle.World.Mocha = WildwoodStyle.World.TimberMid
WildwoodStyle.World.Coffee = WildwoodStyle.World.TimberWarm
WildwoodStyle.World.Peanut = WildwoodStyle.World.TimberLight
WildwoodStyle.World.Cream = WildwoodStyle.World.Plaster
WildwoodStyle.World.Slate = WildwoodStyle.World.StoneDeep
WildwoodStyle.World.FlowerLeaf = WildwoodStyle.World.FoliageLight
WildwoodStyle.World.Shutter = WildwoodStyle.World.Foliage

-- Approved Woodland Canopy furniture palette. These colours intentionally
-- separate movable furniture from the brown Bakery Bay architecture while
-- keeping every surface rooted in the surrounding forest: canopy, moss,
-- lichen, water, stone, mushroom, reeds and small wildflower accents.
WildwoodStyle.Furniture = {
	PineNeedle = Color3.fromRGB(38, 53, 31), -- #26351F
	ForestFern = Color3.fromRGB(67, 90, 50), -- #435A32
	WoodlandMoss = Color3.fromRGB(104, 115, 74), -- #68734A
	PaleLichen = Color3.fromRGB(164, 167, 122), -- #A4A77A
	Eucalyptus = Color3.fromRGB(126, 146, 133), -- #7E9285
	RiverSlate = Color3.fromRGB(89, 106, 100), -- #596A64
	Mushroom = Color3.fromRGB(154, 136, 112), -- #9A8870
	ReedLinen = Color3.fromRGB(201, 180, 143), -- #C9B48F
	Goldenrod = Color3.fromRGB(199, 146, 62), -- #C7923E
	YarrowCream = Color3.fromRGB(216, 198, 155), -- #D8C69B
	FoxgloveBerry = Color3.fromRGB(139, 90, 91), -- #8B5A5B
	TimberTrim = Color3.fromRGB(89, 58, 32), -- #593A20; legs, frames and trim only
}

-- Approved six-character sheet. The first three palettes belong to the male
-- row and the last three to the female row. Clothing stays independent from
-- the town palette so each block avatar remains readable in Bakery Bay.
WildwoodStyle.Avatars = {
	TrailRanger = {
		Primary = Color3.fromRGB(77, 88, 52), -- #4D5834
		Secondary = Color3.fromRGB(109, 113, 68), -- #6D7144
		Leather = Color3.fromRGB(75, 53, 37), -- #4B3525
		Accent = Color3.fromRGB(193, 164, 91), -- #C1A45B
		Light = Color3.fromRGB(215, 206, 171), -- #D7CEAB
		Deep = Color3.fromRGB(45, 42, 32), -- #2D2A20
		Hair = Color3.fromRGB(59, 42, 32), -- #3B2A20
	},
	RiverWarden = {
		Primary = Color3.fromRGB(18, 63, 58), -- #123F3A
		Secondary = Color3.fromRGB(38, 94, 85), -- #265E55
		Leather = Color3.fromRGB(75, 52, 38), -- #4B3426
		Accent = Color3.fromRGB(214, 168, 79), -- #D6A84F
		Light = Color3.fromRGB(216, 214, 190), -- #D8D6BE
		Deep = Color3.fromRGB(16, 46, 44), -- #102E2C
		Hair = Color3.fromRGB(21, 26, 27), -- #151A1B
	},
	AutumnArcher = {
		Primary = Color3.fromRGB(55, 71, 45), -- #37472D
		Secondary = Color3.fromRGB(125, 67, 38), -- #7D4326
		Leather = Color3.fromRGB(86, 55, 36), -- #563724
		Accent = Color3.fromRGB(197, 139, 69), -- #C58B45
		Light = Color3.fromRGB(216, 202, 168), -- #D8CAA8
		Deep = Color3.fromRGB(35, 46, 34), -- #232E22
		Hair = Color3.fromRGB(138, 73, 40), -- #8A4928
	},
	WildflowerBotanist = {
		Primary = Color3.fromRGB(86, 99, 58), -- #56633A
		Secondary = Color3.fromRGB(124, 128, 82), -- #7C8052
		Leather = Color3.fromRGB(80, 55, 40), -- #503728
		Accent = Color3.fromRGB(193, 122, 103), -- #C17A67
		Light = Color3.fromRGB(231, 217, 185), -- #E7D9B9
		Deep = Color3.fromRGB(48, 54, 37), -- #303625
		Hair = Color3.fromRGB(90, 64, 50), -- #5A4032
	},
	FernGuardian = {
		Primary = Color3.fromRGB(50, 74, 53), -- #324A35
		Secondary = Color3.fromRGB(107, 123, 77), -- #6B7B4D
		Leather = Color3.fromRGB(80, 55, 42), -- #50372A
		Accent = Color3.fromRGB(191, 194, 177), -- #BFC2B1
		Light = Color3.fromRGB(208, 209, 198), -- #D0D1C6
		Deep = Color3.fromRGB(39, 48, 42), -- #27302A
		Hair = Color3.fromRGB(141, 76, 45), -- #8D4C2D
	},
	PineScout = {
		Primary = Color3.fromRGB(23, 72, 63), -- #17483F
		Secondary = Color3.fromRGB(49, 92, 82), -- #315C52
		Leather = Color3.fromRGB(74, 52, 39), -- #4A3427
		Accent = Color3.fromRGB(197, 164, 95), -- #C5A45F
		Light = Color3.fromRGB(215, 213, 193), -- #D7D5C1
		Deep = Color3.fromRGB(16, 47, 44), -- #102F2C
		Hair = Color3.fromRGB(37, 38, 40), -- #252628
	},
}

WildwoodStyle.Pets = {
	Cat = {
		-- Mochi is the player's first companion: a black cat with subtle
		-- charcoal face planes, amber eyes and a pale-pink nose.
		Main = Color3.fromRGB(17, 18, 20),
		Light = Color3.fromRGB(37, 39, 43),
		Dark = Color3.fromRGB(5, 6, 8),
		Accent = Color3.fromRGB(244, 188, 198),
		Eye = Color3.fromRGB(235, 184, 73),
		Mouth = Color3.fromRGB(147, 91, 101),
	},
	Fox = {
		Main = Color3.fromRGB(217, 112, 48),
		Light = Color3.fromRGB(255, 230, 184),
		Dark = Color3.fromRGB(83, 49, 35),
		Accent = WildwoodStyle.Colors.ForestGreen,
	},
	Dog = {
		Main = Color3.fromRGB(218, 137, 67),
		Light = Color3.fromRGB(250, 226, 180),
		Dark = Color3.fromRGB(76, 53, 39),
		Accent = WildwoodStyle.Colors.ForestGreen,
	},
	Owl = {
		Main = Color3.fromRGB(107, 80, 58),
		Light = Color3.fromRGB(235, 215, 170),
		Dark = Color3.fromRGB(52, 42, 34),
		Accent = WildwoodStyle.Colors.GoldenYellow,
	},
	Rabbit = {
		Main = Color3.fromRGB(239, 226, 207),
		Light = Color3.fromRGB(255, 246, 228),
		Dark = Color3.fromRGB(111, 91, 79),
		Accent = Color3.fromRGB(218, 150, 143),
	},
}

WildwoodStyle.Lighting = {
	DayAmbient = WildwoodStyle.World.StoneLight,
	DayOutdoor = WildwoodStyle.World.Plaster,
	DayTop = WildwoodStyle.World.DaySky,
	DayBottom = WildwoodStyle.World.Stone,
	DayFog = WildwoodStyle.World.DayFog,
	NightAmbient = WildwoodStyle.World.NightSky,
	NightOutdoor = WildwoodStyle.World.StoneDeep,
	NightTop = WildwoodStyle.World.Water,
	NightBottom = WildwoodStyle.World.NightSky,
	NightFog = WildwoodStyle.World.Stone,
}

return table.freeze(WildwoodStyle)
