--[[
	Furniture catalogue.

	Every item is data, not code: a footprint, a price, a rarity, and a list of
	boxes to build it from. WorldService has one builder that reads this, so
	adding a sofa is a table entry rather than a new function, and there is no
	per-item drawing code to keep in step.

	Sizes are in studs. `W` and `D` are the footprint used for grid snapping and
	for checking the item does not overlap another one or clip a wall, so they
	must cover the whole shape, not just its base.

	The look is Woodland Canopy: forest greens, lichen, river stone, mushroom,
	reed linen and restrained wildflower accents. Brown timber is reserved for
	legs, frames and trim so furniture stays distinct from the buildings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WildwoodStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildwoodStyle"))
local WOODLAND = WildwoodStyle.Furniture
local Furniture = {}

-- Semantic aliases keep the catalogue readable while every placed part resolves
-- to the approved Woodland Canopy palette. Rarity stripes below remain UI-only.
local C = {
	Wood = WOODLAND.TimberTrim,
	WoodDark = WOODLAND.PineNeedle,
	WoodLight = WOODLAND.Mushroom,
	White = WOODLAND.YarrowCream,
	Cream = WOODLAND.ReedLinen,
	Blush = WOODLAND.ForestFern,
	Rose = WOODLAND.Goldenrod,
	Sky = WOODLAND.Eucalyptus,
	Blue = WOODLAND.RiverSlate,
	Mint = WOODLAND.PaleLichen,
	Sage = WOODLAND.WoodlandMoss,
	Butter = WOODLAND.Goldenrod,
	Lilac = WOODLAND.FoxgloveBerry,
	Grey = WOODLAND.Mushroom,
	Charcoal = WOODLAND.PineNeedle,
	Leaf = WOODLAND.ForestFern,
	Water = WOODLAND.RiverSlate,
	Sand = WOODLAND.ReedLinen,
}

Furniture.Palette = C

--[[
	Rarity drives the colour of the stripe down the edge of the shop card, and
	nothing else.

	These are deeper than the pastels they replaced. The stripe is a thin band on a
	white card, so a pale colour simply is not visible: the old Legendary gold sat
	at 2.09:1 against the card, where 3:1 is the floor for a graphic that carries
	meaning. Each keeps its identity - grey, blue, purple, gold - but dark enough
	to actually be seen. `scripts/contrast_test.py` holds them to that.
]]
Furniture.Rarities = {
	Common = { Order = 1, Name = "Common", NameThai = "ธรรมดา", Color = Color3.fromRGB(110, 120, 126) },
	Rare = { Order = 2, Name = "Rare", NameThai = "หายาก", Color = Color3.fromRGB(46, 116, 181) },
	Epic = { Order = 3, Name = "Epic", NameThai = "อีพิค", Color = Color3.fromRGB(124, 77, 178) },
	Legendary = { Order = 4, Name = "Legendary", NameThai = "ตำนาน", Color = Color3.fromRGB(176, 118, 20) },
}

Furniture.Categories = {
	{ Id = "LivingRoom", Name = "Living Room", NameThai = "ห้องนั่งเล่น" },
	{ Id = "Bedroom", Name = "Bedroom", NameThai = "ห้องนอน" },
	{ Id = "Kitchen", Name = "Kitchen", NameThai = "ห้องครัว" },
	{ Id = "Bathroom", Name = "Bathroom", NameThai = "ห้องน้ำ" },
	{ Id = "Garden", Name = "Garden", NameThai = "สวน" },
	{ Id = "Decoration", Name = "Decoration", NameThai = "ของตกแต่ง" },
}

-- Items in the Garden category are placed outside the house, on the lawn.
Furniture.OutdoorCategory = "Garden"

--[[ One box of an item. Offsets are from the item's centre, on its own floor. ]]
local function box(size, offset, color, material, shape)
	return {
		Size = size,
		Offset = offset,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Shape = shape,
	}
end

local WOOD = Enum.Material.WoodPlanks
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass
local BALL = Enum.PartType.Ball

--[[ Four legs under a top: used by most tables, chairs and cabinets. ]]
local function legs(width, depth, height, color)
	local parts = {}
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			table.insert(parts, box(
				Vector3.new(0.4, height, 0.4),
				Vector3.new(x * (width / 2 - 0.4), height / 2, z * (depth / 2 - 0.4)),
				color,
				WOOD
			))
		end
	end
	return parts
end

local function append(target, extra)
	for _, entry in ipairs(extra) do
		table.insert(target, entry)
	end
	return target
end

--[[ A lamp: post, shade, and a real light so it works at dusk. ]]
local function lamp(height, shadeColor, range)
	return {
		box(Vector3.new(1.6, 0.3, 1.6), Vector3.new(0, 0.15, 0), C.WoodDark, WOOD),
		box(Vector3.new(0.25, height, 0.25), Vector3.new(0, height / 2, 0), C.WoodDark, METAL),
		box(Vector3.new(1.8, 1.4, 1.8), Vector3.new(0, height + 0.6, 0), shadeColor, NEON),
		{ Light = true, Offset = Vector3.new(0, height + 0.6, 0), Range = range or 16, Color = shadeColor },
	}
end

Furniture.Items = {
	-- Living room ------------------------------------------------------------
	Sofa = {
		Category = "LivingRoom", Name = "Cloud Sofa", NameThai = "โซฟาก้อนเมฆ",
		Price = 220, Rarity = "Rare", W = 8, D = 4,
		Parts = {
			box(Vector3.new(8, 1.2, 4), Vector3.new(0, 1.4, 0), C.Blush, FABRIC),
			box(Vector3.new(8, 2.4, 0.9), Vector3.new(0, 2.6, 1.6), C.Blush, FABRIC),
			box(Vector3.new(0.9, 2, 4), Vector3.new(-3.6, 2.4, 0), C.Rose, FABRIC),
			box(Vector3.new(0.9, 2, 4), Vector3.new(3.6, 2.4, 0), C.Rose, FABRIC),
			box(Vector3.new(7.4, 0.8, 0.8), Vector3.new(0, 0.4, 0), C.Wood, WOOD),
		},
	},
	CoffeeTable = {
		Category = "LivingRoom", Name = "Coffee Table", NameThai = "โต๊ะกาแฟ",
		Price = 110, Rarity = "Common", W = 5, D = 3,
		Parts = append({ box(Vector3.new(5, 0.5, 3), Vector3.new(0, 2.2, 0), C.WoodLight, WOOD) }, legs(5, 3, 2.2, C.Wood)),
	},
	TVStand = {
		Category = "LivingRoom", Name = "TV Stand", NameThai = "ตู้วางทีวี",
		Price = 130, Rarity = "Common", W = 6, D = 2,
		Parts = {
			box(Vector3.new(6, 2.2, 2), Vector3.new(0, 1.1, 0), C.WoodLight, WOOD),
			box(Vector3.new(2.6, 1.4, 0.2), Vector3.new(-1.5, 1.2, -1.05), C.Wood, WOOD),
			box(Vector3.new(2.6, 1.4, 0.2), Vector3.new(1.5, 1.2, -1.05), C.Wood, WOOD),
		},
	},
	Television = {
		Category = "LivingRoom", Name = "Television", NameThai = "โทรทัศน์",
		Price = 260, Rarity = "Epic", W = 5, D = 2,
		Parts = {
			box(Vector3.new(1.6, 0.4, 1.2), Vector3.new(0, 0.2, 0), C.Charcoal, METAL),
			box(Vector3.new(0.4, 1, 0.4), Vector3.new(0, 0.9, 0), C.Charcoal, METAL),
			box(Vector3.new(5, 3, 0.4), Vector3.new(0, 3, 0), C.Charcoal, METAL),
			box(Vector3.new(4.6, 2.6, 0.1), Vector3.new(0, 3, -0.25), C.Sky, NEON),
		},
	},
	Bookshelf = {
		Category = "LivingRoom", Name = "Bookshelf", NameThai = "ชั้นหนังสือ",
		Price = 180, Rarity = "Common", W = 4, D = 2,
		Parts = {
			box(Vector3.new(4, 7, 2), Vector3.new(0, 3.5, 0), C.Wood, WOOD),
			box(Vector3.new(3.4, 0.3, 1.6), Vector3.new(0, 2.4, -0.1), C.WoodLight, WOOD),
			box(Vector3.new(3.4, 0.3, 1.6), Vector3.new(0, 4.6, -0.1), C.WoodLight, WOOD),
			box(Vector3.new(2.6, 1.4, 1), Vector3.new(-0.3, 3.2, -0.3), C.Rose, FABRIC),
			box(Vector3.new(2.2, 1.4, 1), Vector3.new(0.4, 5.4, -0.3), C.Mint, FABRIC),
		},
	},
	FloorLamp = {
		Category = "LivingRoom", Name = "Floor Lamp", NameThai = "โคมไฟตั้งพื้น",
		Price = 90, Rarity = "Common", W = 2, D = 2,
		Parts = lamp(5.4, C.Butter, 18),
	},
	Rug = {
		Category = "LivingRoom", Name = "Soft Rug", NameThai = "พรมนุ่ม",
		Price = 70, Rarity = "Common", W = 8, D = 6, Flat = true,
		Parts = {
			box(Vector3.new(8, 0.2, 6), Vector3.new(0, 0.1, 0), C.Cream, FABRIC),
			box(Vector3.new(6.4, 0.24, 4.6), Vector3.new(0, 0.12, 0), C.Blush, FABRIC),
		},
	},
	Plant = {
		Category = "LivingRoom", Name = "Happy Plant", NameThai = "ต้นไม้อารมณ์ดี",
		Price = 50, Rarity = "Common", W = 2, D = 2,
		Parts = {
			box(Vector3.new(1.8, 1.6, 1.8), Vector3.new(0, 0.8, 0), C.Rose, Enum.Material.Sand),
			box(Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 2.9, 0), C.Leaf, GRASS, BALL),
		},
	},
	WallShelf = {
		Category = "LivingRoom", Name = "Wall Shelf", NameThai = "ชั้นติดผนัง",
		Price = 60, Rarity = "Common", W = 4, D = 1,
		Parts = {
			box(Vector3.new(4, 0.4, 1.2), Vector3.new(0, 4.5, 0), C.WoodLight, WOOD),
			box(Vector3.new(0.4, 0.8, 0.8), Vector3.new(-1.6, 4.1, 0), C.Wood, WOOD),
			box(Vector3.new(0.4, 0.8, 0.8), Vector3.new(1.6, 4.1, 0), C.Wood, WOOD),
			box(Vector3.new(1, 1.2, 0.8), Vector3.new(0.6, 5.3, 0), C.Mint, FABRIC),
		},
	},
	PictureFrames = {
		Category = "LivingRoom", Name = "Picture Frames", NameThai = "กรอบรูป",
		Price = 55, Rarity = "Common", W = 3, D = 1,
		Parts = {
			box(Vector3.new(2.2, 2.6, 0.3), Vector3.new(-0.7, 5, 0), C.Wood, WOOD),
			box(Vector3.new(1.6, 2, 0.1), Vector3.new(-0.7, 5, -0.2), C.Sky, Enum.Material.SmoothPlastic),
			box(Vector3.new(1.6, 1.8, 0.3), Vector3.new(1.1, 4.2, 0), C.Wood, WOOD),
			box(Vector3.new(1.1, 1.3, 0.1), Vector3.new(1.1, 4.2, -0.2), C.Blush, Enum.Material.SmoothPlastic),
		},
	},

	-- Bedroom ----------------------------------------------------------------
	Bed = {
		Category = "Bedroom", Name = "Cloud Bed", NameThai = "เตียงก้อนเมฆ",
		Price = 240, Rarity = "Epic", W = 6, D = 8,
		Parts = {
			box(Vector3.new(6, 1, 8), Vector3.new(0, 1, 0), C.Wood, WOOD),
			box(Vector3.new(5.6, 0.9, 7.4), Vector3.new(0, 1.9, 0), C.Sky, FABRIC),
			box(Vector3.new(5.6, 0.5, 3), Vector3.new(0, 2.4, 1.8), C.White, FABRIC),
			box(Vector3.new(4.4, 0.9, 1.6), Vector3.new(0, 2.6, -2.8), C.White, FABRIC),
			box(Vector3.new(6, 3, 0.6), Vector3.new(0, 2.5, -4), C.WoodLight, WOOD),
		},
	},
	PillowSet = {
		Category = "Bedroom", Name = "Pillow Set", NameThai = "ชุดหมอน",
		Price = 45, Rarity = "Common", W = 3, D = 2,
		Parts = {
			box(Vector3.new(2.4, 0.8, 1.4), Vector3.new(-0.4, 0.4, 0), C.Blush, FABRIC),
			box(Vector3.new(2.2, 0.8, 1.3), Vector3.new(0.6, 1, 0.2), C.Lilac, FABRIC),
		},
	},
	Wardrobe = {
		Category = "Bedroom", Name = "Wardrobe", NameThai = "ตู้เสื้อผ้า",
		Price = 200, Rarity = "Epic", W = 5, D = 3,
		Parts = {
			box(Vector3.new(5, 8, 3), Vector3.new(0, 4, 0), C.WoodLight, WOOD),
			box(Vector3.new(0.2, 7, 0.2), Vector3.new(0, 4, -1.6), C.WoodDark, WOOD),
			box(Vector3.new(0.5, 0.5, 0.4), Vector3.new(-0.6, 4, -1.7), C.Butter, METAL),
			box(Vector3.new(0.5, 0.5, 0.4), Vector3.new(0.6, 4, -1.7), C.Butter, METAL),
		},
	},
	Desk = {
		Category = "Bedroom", Name = "Study Desk", NameThai = "โต๊ะเรียน",
		Price = 140, Rarity = "Common", W = 6, D = 3,
		Parts = append({
			box(Vector3.new(6, 0.5, 3), Vector3.new(0, 3.2, 0), C.WoodLight, WOOD),
			box(Vector3.new(2, 1.6, 2.4), Vector3.new(1.8, 2.2, 0), C.Wood, WOOD),
		}, legs(6, 3, 3.2, C.Wood)),
	},
	Chair = {
		Category = "Bedroom", Name = "Cozy Chair", NameThai = "เก้าอี้แสนสบาย",
		Price = 75, Rarity = "Common", W = 3, D = 3,
		Parts = append({
			box(Vector3.new(3, 0.6, 3), Vector3.new(0, 2.2, 0), C.Blush, FABRIC),
			box(Vector3.new(3, 3, 0.6), Vector3.new(0, 3.9, 1.2), C.Blush, FABRIC),
		}, legs(3, 3, 2.2, C.Wood)),
	},
	Nightstand = {
		Category = "Bedroom", Name = "Nightstand", NameThai = "โต๊ะข้างเตียง",
		Price = 80, Rarity = "Common", W = 3, D = 2,
		Parts = {
			box(Vector3.new(3, 3, 2), Vector3.new(0, 1.5, 0), C.WoodLight, WOOD),
			box(Vector3.new(2.4, 0.2, 0.2), Vector3.new(0, 2.2, -1.05), C.Butter, METAL),
			box(Vector3.new(2.4, 0.2, 0.2), Vector3.new(0, 1, -1.05), C.Butter, METAL),
		},
	},
	TableLamp = {
		Category = "Bedroom", Name = "Table Lamp", NameThai = "โคมไฟตั้งโต๊ะ",
		Price = 65, Rarity = "Common", W = 2, D = 2,
		Parts = lamp(2.2, C.Blush, 12),
	},
	PlushToys = {
		Category = "Bedroom", Name = "Plush Toys", NameThai = "ตุ๊กตาผ้า",
		Price = 55, Rarity = "Rare", W = 3, D = 2,
		Parts = {
			box(Vector3.new(1.6, 1.6, 1.6), Vector3.new(-0.7, 0.8, 0), C.Butter, FABRIC, BALL),
			box(Vector3.new(1, 1, 1), Vector3.new(-0.7, 1.9, 0), C.Butter, FABRIC, BALL),
			box(Vector3.new(1.4, 1.4, 1.4), Vector3.new(0.9, 0.7, 0.2), C.Mint, FABRIC, BALL),
			box(Vector3.new(0.9, 0.9, 0.9), Vector3.new(0.9, 1.6, 0.2), C.Mint, FABRIC, BALL),
		},
	},

	-- Kitchen ----------------------------------------------------------------
	Refrigerator = {
		Category = "Kitchen", Name = "Refrigerator", NameThai = "ตู้เย็น",
		Price = 230, Rarity = "Epic", W = 3, D = 3,
		Parts = {
			box(Vector3.new(3, 7, 3), Vector3.new(0, 3.5, 0), C.White, METAL),
			box(Vector3.new(2.8, 0.2, 0.2), Vector3.new(0, 4.6, -1.55), C.Grey, METAL),
			box(Vector3.new(0.3, 2, 0.3), Vector3.new(1, 5.4, -1.7), C.Grey, METAL),
			box(Vector3.new(0.3, 2, 0.3), Vector3.new(1, 2.8, -1.7), C.Grey, METAL),
		},
	},
	KitchenCounter = {
		Category = "Kitchen", Name = "Kitchen Counter", NameThai = "เคาน์เตอร์ครัว",
		Price = 150, Rarity = "Common", W = 6, D = 3,
		Parts = {
			box(Vector3.new(6, 3.2, 3), Vector3.new(0, 1.6, 0), C.Cream, WOOD),
			box(Vector3.new(6.3, 0.4, 3.3), Vector3.new(0, 3.4, 0), C.WoodDark, WOOD),
			box(Vector3.new(2.6, 0.2, 0.2), Vector3.new(-1.4, 2.2, -1.55), C.Grey, METAL),
			box(Vector3.new(2.6, 0.2, 0.2), Vector3.new(1.4, 2.2, -1.55), C.Grey, METAL),
		},
	},
	Stove = {
		Category = "Kitchen", Name = "Stove", NameThai = "เตา",
		Price = 190, Rarity = "Rare", W = 4, D = 3,
		Parts = {
			box(Vector3.new(4, 3.2, 3), Vector3.new(0, 1.6, 0), C.White, METAL),
			box(Vector3.new(4.2, 0.3, 3.2), Vector3.new(0, 3.4, 0), C.Charcoal, METAL),
			box(Vector3.new(1.2, 0.1, 1.2), Vector3.new(-1, 3.6, -0.6), C.Rose, NEON, Enum.PartType.Cylinder),
			box(Vector3.new(1.2, 0.1, 1.2), Vector3.new(1, 3.6, -0.6), C.Rose, NEON, Enum.PartType.Cylinder),
			box(Vector3.new(3.4, 1.6, 0.2), Vector3.new(0, 1.8, -1.55), C.Sky, GLASS),
		},
	},
	Sink = {
		Category = "Kitchen", Name = "Kitchen Sink", NameThai = "อ่างล้างจาน",
		Price = 120, Rarity = "Common", W = 4, D = 3,
		Parts = {
			box(Vector3.new(4, 3.2, 3), Vector3.new(0, 1.6, 0), C.Cream, WOOD),
			box(Vector3.new(4.2, 0.4, 3.2), Vector3.new(0, 3.4, 0), C.White, METAL),
			box(Vector3.new(2.4, 0.5, 1.8), Vector3.new(0, 3.4, 0.2), C.Grey, METAL),
			box(Vector3.new(0.25, 1.6, 0.25), Vector3.new(0, 4.4, -1), C.Grey, METAL),
		},
	},
	DiningTable = {
		Category = "Kitchen", Name = "Dining Table", NameThai = "โต๊ะอาหาร",
		Price = 170, Rarity = "Common", W = 7, D = 4,
		Parts = append({ box(Vector3.new(7, 0.5, 4), Vector3.new(0, 3.2, 0), C.WoodLight, WOOD) }, legs(7, 4, 3.2, C.Wood)),
	},
	DiningChairs = {
		Category = "Kitchen", Name = "Dining Chairs", NameThai = "เก้าอี้อาหาร",
		Price = 95, Rarity = "Common", W = 5, D = 3,
		Parts = {
			box(Vector3.new(2, 0.4, 2), Vector3.new(-1.4, 2, 0), C.Mint, WOOD),
			box(Vector3.new(2, 2.4, 0.4), Vector3.new(-1.4, 3.2, 0.8), C.Mint, WOOD),
			box(Vector3.new(0.3, 2, 0.3), Vector3.new(-2.2, 1, -0.8), C.Wood, WOOD),
			box(Vector3.new(0.3, 2, 0.3), Vector3.new(-0.6, 1, -0.8), C.Wood, WOOD),
			box(Vector3.new(2, 0.4, 2), Vector3.new(1.4, 2, 0), C.Butter, WOOD),
			box(Vector3.new(2, 2.4, 0.4), Vector3.new(1.4, 3.2, 0.8), C.Butter, WOOD),
			box(Vector3.new(0.3, 2, 0.3), Vector3.new(0.6, 1, -0.8), C.Wood, WOOD),
			box(Vector3.new(0.3, 2, 0.3), Vector3.new(2.2, 1, -0.8), C.Wood, WOOD),
		},
	},
	Microwave = {
		Category = "Kitchen", Name = "Microwave", NameThai = "ไมโครเวฟ",
		Price = 100, Rarity = "Common", W = 3, D = 2,
		Parts = {
			box(Vector3.new(3, 1.8, 2), Vector3.new(0, 0.9, 0), C.White, METAL),
			box(Vector3.new(2, 1.2, 0.15), Vector3.new(-0.3, 0.9, -1.05), C.Charcoal, GLASS),
		},
	},
	KitchenShelf = {
		Category = "Kitchen", Name = "Kitchen Shelf", NameThai = "ชั้นวางครัว",
		Price = 70, Rarity = "Common", W = 4, D = 1,
		Parts = {
			box(Vector3.new(4, 0.4, 1.2), Vector3.new(0, 4.2, 0), C.WoodLight, WOOD),
			box(Vector3.new(4, 0.4, 1.2), Vector3.new(0, 5.8, 0), C.WoodLight, WOOD),
			box(Vector3.new(1, 1, 0.8), Vector3.new(-1.2, 4.9, 0), C.Sky, Enum.Material.SmoothPlastic),
			box(Vector3.new(0.9, 0.9, 0.7), Vector3.new(0.2, 6.4, 0), C.Rose, Enum.Material.SmoothPlastic),
		},
	},

	-- Bathroom ---------------------------------------------------------------
	Bathtub = {
		Category = "Bathroom", Name = "Bathtub", NameThai = "อ่างอาบน้ำ",
		Price = 210, Rarity = "Epic", W = 6, D = 3,
		Parts = {
			box(Vector3.new(6, 2.4, 3), Vector3.new(0, 1.2, 0), C.White, Enum.Material.SmoothPlastic),
			box(Vector3.new(5.2, 0.6, 2.2), Vector3.new(0, 2.3, 0), C.Water, GLASS),
			box(Vector3.new(0.25, 1.4, 0.25), Vector3.new(2.4, 3, 0), C.Grey, METAL),
		},
	},
	Toilet = {
		Category = "Bathroom", Name = "Toilet", NameThai = "โถสุขภัณฑ์",
		Price = 110, Rarity = "Common", W = 2, D = 3,
		Parts = {
			box(Vector3.new(2, 1.8, 2.4), Vector3.new(0, 0.9, 0), C.White, Enum.Material.SmoothPlastic),
			box(Vector3.new(1.8, 0.3, 2), Vector3.new(0, 1.9, 0), C.White, Enum.Material.SmoothPlastic),
			box(Vector3.new(2, 2.6, 0.8), Vector3.new(0, 2, 1.2), C.White, Enum.Material.SmoothPlastic),
		},
	},
	SinkCabinet = {
		Category = "Bathroom", Name = "Sink Cabinet", NameThai = "ตู้อ่างล้างหน้า",
		Price = 130, Rarity = "Common", W = 4, D = 2,
		Parts = {
			box(Vector3.new(4, 3, 2), Vector3.new(0, 1.5, 0), C.Sky, WOOD),
			box(Vector3.new(4.2, 0.4, 2.2), Vector3.new(0, 3.2, 0), C.White, Enum.Material.SmoothPlastic),
			box(Vector3.new(1.8, 0.4, 1.4), Vector3.new(0, 3.3, 0), C.Grey, METAL),
			box(Vector3.new(0.2, 1.2, 0.2), Vector3.new(0, 4, 0.6), C.Grey, METAL),
		},
	},
	Mirror = {
		Category = "Bathroom", Name = "Mirror", NameThai = "กระจก",
		Price = 85, Rarity = "Common", W = 3, D = 1,
		Parts = {
			box(Vector3.new(3, 3.6, 0.4), Vector3.new(0, 5, 0), C.WoodLight, WOOD),
			box(Vector3.new(2.4, 3, 0.15), Vector3.new(0, 5, -0.2), C.Sky, GLASS),
		},
	},
	TowelRack = {
		Category = "Bathroom", Name = "Towel Rack", NameThai = "ราวแขวนผ้า",
		Price = 50, Rarity = "Common", W = 3, D = 1,
		Parts = {
			box(Vector3.new(3, 0.2, 0.2), Vector3.new(0, 4.4, 0), C.Grey, METAL),
			box(Vector3.new(1, 2.2, 0.3), Vector3.new(-0.7, 3.4, 0), C.Blush, FABRIC),
			box(Vector3.new(0.9, 2, 0.3), Vector3.new(0.7, 3.5, 0), C.Mint, FABRIC),
		},
	},
	LaundryBasket = {
		Category = "Bathroom", Name = "Laundry Basket", NameThai = "ตะกร้าผ้า",
		Price = 45, Rarity = "Common", W = 2, D = 2,
		Parts = {
			box(Vector3.new(2, 2.4, 2), Vector3.new(0, 1.2, 0), C.Sand, Enum.Material.Fabric),
			box(Vector3.new(2.2, 0.3, 2.2), Vector3.new(0, 2.5, 0), C.WoodLight, WOOD),
		},
	},

	-- Garden (placed outside, on the lawn) ------------------------------------
	FlowerPots = {
		Category = "Garden", Name = "Flower Pots", NameThai = "กระถางดอกไม้",
		Price = 40, Rarity = "Common", W = 3, D = 2,
		Parts = {
			box(Vector3.new(1.6, 1.4, 1.6), Vector3.new(-0.8, 0.7, 0), C.Rose, Enum.Material.Sand),
			box(Vector3.new(1.6, 1.6, 1.6), Vector3.new(-0.8, 2.1, 0), C.Blush, NEON, BALL),
			box(Vector3.new(1.4, 1.2, 1.4), Vector3.new(0.9, 0.6, 0.2), C.Sky, Enum.Material.Sand),
			box(Vector3.new(1.4, 1.4, 1.4), Vector3.new(0.9, 1.8, 0.2), C.Butter, NEON, BALL),
		},
	},
	GardenTree = {
		Category = "Garden", Name = "Little Tree", NameThai = "ต้นไม้เล็ก",
		Price = 120, Rarity = "Common", W = 4, D = 4,
		Parts = {
			box(Vector3.new(1.4, 5, 1.4), Vector3.new(0, 2.5, 0), C.WoodDark, Enum.Material.Wood),
			box(Vector3.new(5, 5, 5), Vector3.new(0, 6, 0), C.Leaf, GRASS, BALL),
		},
	},
	Bushes = {
		Category = "Garden", Name = "Bushes", NameThai = "พุ่มไม้",
		Price = 55, Rarity = "Common", W = 5, D = 2,
		Parts = {
			box(Vector3.new(2.6, 2.2, 2.2), Vector3.new(-1.2, 1.1, 0), C.Sage, GRASS, BALL),
			box(Vector3.new(2.2, 1.8, 2), Vector3.new(1.2, 0.9, 0.2), C.Leaf, GRASS, BALL),
		},
	},
	GardenBench = {
		Category = "Garden", Name = "Garden Bench", NameThai = "ม้านั่งสวน",
		Price = 130, Rarity = "Common", W = 6, D = 2,
		Parts = {
			box(Vector3.new(6, 0.4, 2), Vector3.new(0, 2, 0), C.Wood, WOOD),
			box(Vector3.new(6, 2.2, 0.4), Vector3.new(0, 3, 0.8), C.Wood, WOOD),
			box(Vector3.new(0.4, 2, 0.4), Vector3.new(-2.6, 1, -0.6), C.WoodDark, WOOD),
			box(Vector3.new(0.4, 2, 0.4), Vector3.new(2.6, 1, -0.6), C.WoodDark, WOOD),
		},
	},
	GardenFountain = {
		Category = "Garden", Name = "Garden Fountain", NameThai = "น้ำพุสวน",
		Price = 480, Rarity = "Legendary", W = 6, D = 6,
		Parts = {
			box(Vector3.new(6, 1.6, 6), Vector3.new(0, 0.8, 0), C.Grey, Enum.Material.Rock, Enum.PartType.Cylinder),
			box(Vector3.new(5, 0.4, 5), Vector3.new(0, 1.6, 0), C.Water, GLASS, Enum.PartType.Cylinder),
			box(Vector3.new(1, 3, 1), Vector3.new(0, 3, 0), C.Grey, Enum.Material.Rock, Enum.PartType.Cylinder),
			box(Vector3.new(2.6, 0.4, 2.6), Vector3.new(0, 4.4, 0), C.Water, GLASS, Enum.PartType.Cylinder),
			{ Light = true, Offset = Vector3.new(0, 3, 0), Range = 14, Color = C.Water },
		},
	},
	GardenMailbox = {
		Category = "Garden", Name = "Mailbox", NameThai = "ตู้จดหมาย",
		Price = 60, Rarity = "Common", W = 2, D = 2,
		Parts = {
			box(Vector3.new(0.5, 3.4, 0.5), Vector3.new(0, 1.7, 0), C.WoodDark, WOOD),
			box(Vector3.new(1.8, 1.4, 2.4), Vector3.new(0, 4.1, 0), C.Rose, METAL),
			box(Vector3.new(0.3, 1, 0.3), Vector3.new(1, 4.8, 0), C.White, METAL),
		},
	},
	Fence = {
		Category = "Garden", Name = "Picket Fence", NameThai = "รั้วไม้",
		Price = 65, Rarity = "Common", W = 8, D = 1,
		Parts = {
			box(Vector3.new(8, 0.3, 0.3), Vector3.new(0, 1.6, 0), C.White, WOOD),
			box(Vector3.new(8, 0.3, 0.3), Vector3.new(0, 2.6, 0), C.White, WOOD),
			box(Vector3.new(0.5, 3.4, 0.5), Vector3.new(-3.4, 1.7, 0), C.White, WOOD),
			box(Vector3.new(0.5, 3.4, 0.5), Vector3.new(-1.1, 1.7, 0), C.White, WOOD),
			box(Vector3.new(0.5, 3.4, 0.5), Vector3.new(1.1, 1.7, 0), C.White, WOOD),
			box(Vector3.new(0.5, 3.4, 0.5), Vector3.new(3.4, 1.7, 0), C.White, WOOD),
		},
	},
	PlaygroundSet = {
		Category = "Garden", Name = "Playground Set", NameThai = "ชุดเครื่องเล่น",
		Price = 620, Rarity = "Legendary", W = 8, D = 8,
		Parts = {
			box(Vector3.new(5, 0.6, 5), Vector3.new(-1, 4.4, 1.5), C.Lilac, WOOD),
			box(Vector3.new(0.6, 4.4, 0.6), Vector3.new(-3, 2.2, -0.6), C.Mint, METAL),
			box(Vector3.new(0.6, 4.4, 0.6), Vector3.new(1, 2.2, -0.6), C.Mint, METAL),
			box(Vector3.new(0.6, 4.4, 0.6), Vector3.new(-3, 2.2, 3.6), C.Mint, METAL),
			box(Vector3.new(0.6, 4.4, 0.6), Vector3.new(1, 2.2, 3.6), C.Mint, METAL),
			box(Vector3.new(3, 0.5, 7), Vector3.new(-1, 2.6, -3), C.Blush, Enum.Material.SmoothPlastic),
			box(Vector3.new(5.4, 0.5, 5.4), Vector3.new(-1, 7.2, 1.5), C.Rose, Enum.Material.SmoothPlastic),
		},
	},
	Swing = {
		Category = "Garden", Name = "Swing", NameThai = "ชิงช้า",
		Price = 260, Rarity = "Epic", W = 6, D = 3,
		Parts = {
			box(Vector3.new(0.5, 6, 0.5), Vector3.new(-2.6, 3, 0), C.Sky, METAL),
			box(Vector3.new(0.5, 6, 0.5), Vector3.new(2.6, 3, 0), C.Sky, METAL),
			box(Vector3.new(6, 0.5, 0.5), Vector3.new(0, 6, 0), C.Sky, METAL),
			box(Vector3.new(0.15, 3.4, 0.15), Vector3.new(-1, 4.2, 0), C.Grey, METAL),
			box(Vector3.new(0.15, 3.4, 0.15), Vector3.new(1, 4.2, 0), C.Grey, METAL),
			box(Vector3.new(2.6, 0.35, 1.2), Vector3.new(0, 2.4, 0), C.Butter, WOOD),
		},
	},
	Sandbox = {
		Category = "Garden", Name = "Sandbox", NameThai = "บ่อทราย",
		Price = 150, Rarity = "Common", W = 6, D = 6, Flat = true,
		Parts = {
			box(Vector3.new(6, 0.8, 6), Vector3.new(0, 0.4, 0), C.Sand, Enum.Material.Sand),
			box(Vector3.new(6.4, 1, 0.6), Vector3.new(0, 0.5, -3), C.Wood, WOOD),
			box(Vector3.new(6.4, 1, 0.6), Vector3.new(0, 0.5, 3), C.Wood, WOOD),
			box(Vector3.new(0.6, 1, 6.4), Vector3.new(-3, 0.5, 0), C.Wood, WOOD),
			box(Vector3.new(0.6, 1, 6.4), Vector3.new(3, 0.5, 0), C.Wood, WOOD),
		},
	},

	-- Decoration --------------------------------------------------------------
	WallClock = {
		Category = "Decoration", Name = "Wall Clock", NameThai = "นาฬิกาแขวน",
		Price = 55, Rarity = "Common", W = 2, D = 1,
		Parts = {
			box(Vector3.new(2.4, 2.4, 0.3), Vector3.new(0, 5.4, 0), C.Wood, WOOD, Enum.PartType.Cylinder),
			box(Vector3.new(2, 2, 0.15), Vector3.new(0, 5.4, -0.2), C.White, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder),
			box(Vector3.new(0.15, 0.8, 0.1), Vector3.new(0, 5.7, -0.3), C.Charcoal, Enum.Material.SmoothPlastic),
		},
	},
	Curtains = {
		Category = "Decoration", Name = "Curtains", NameThai = "ผ้าม่าน",
		Price = 75, Rarity = "Common", W = 6, D = 1,
		Parts = {
			box(Vector3.new(6.4, 0.3, 0.3), Vector3.new(0, 7, 0), C.WoodDark, METAL),
			box(Vector3.new(1.8, 5.4, 0.4), Vector3.new(-2.2, 4.2, 0), C.Blush, FABRIC),
			box(Vector3.new(1.8, 5.4, 0.4), Vector3.new(2.2, 4.2, 0), C.Blush, FABRIC),
		},
	},
	CeilingLamp = {
		Category = "Decoration", Name = "Ceiling Lamp", NameThai = "โคมไฟเพดาน",
		Price = 110, Rarity = "Rare", W = 2, D = 2,
		Parts = {
			box(Vector3.new(0.2, 2.4, 0.2), Vector3.new(0, 7.6, 0), C.Charcoal, METAL),
			box(Vector3.new(2.6, 1.4, 2.6), Vector3.new(0, 6.2, 0), C.Butter, NEON),
			{ Light = true, Offset = Vector3.new(0, 6.2, 0), Range = 22, Color = C.Butter },
		},
	},
	Candles = {
		Category = "Decoration", Name = "Candles", NameThai = "เทียนหอม",
		Price = 40, Rarity = "Common", W = 2, D = 2,
		Parts = {
			box(Vector3.new(0.6, 1.4, 0.6), Vector3.new(-0.5, 0.7, 0), C.Cream, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder),
			box(Vector3.new(0.4, 0.5, 0.4), Vector3.new(-0.5, 1.6, 0), C.Butter, NEON, BALL),
			box(Vector3.new(0.6, 1, 0.6), Vector3.new(0.6, 0.5, 0.3), C.Blush, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder),
			box(Vector3.new(0.4, 0.5, 0.4), Vector3.new(0.6, 1.2, 0.3), C.Butter, NEON, BALL),
			{ Light = true, Offset = Vector3.new(0, 1.4, 0), Range = 8, Color = C.Butter },
		},
	},
	Paintings = {
		Category = "Decoration", Name = "Paintings", NameThai = "ภาพวาด",
		Price = 90, Rarity = "Rare", W = 4, D = 1,
		Parts = {
			box(Vector3.new(3.6, 2.8, 0.3), Vector3.new(0, 5.2, 0), C.WoodDark, WOOD),
			box(Vector3.new(3, 2.2, 0.1), Vector3.new(0, 5.2, -0.2), C.Mint, Enum.Material.SmoothPlastic),
			box(Vector3.new(1, 1, 0.05), Vector3.new(-0.6, 5.4, -0.3), C.Butter, Enum.Material.SmoothPlastic, BALL),
		},
	},
	PlushAnimals = {
		Category = "Decoration", Name = "Plush Animals", NameThai = "ตุ๊กตาสัตว์",
		Price = 70, Rarity = "Rare", W = 3, D = 2,
		Parts = {
			box(Vector3.new(1.8, 1.6, 1.6), Vector3.new(0, 0.8, 0), C.Lilac, FABRIC, BALL),
			box(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2, 0), C.Lilac, FABRIC, BALL),
			box(Vector3.new(0.5, 0.7, 0.4), Vector3.new(-0.4, 2.7, 0), C.Rose, FABRIC),
			box(Vector3.new(0.5, 0.7, 0.4), Vector3.new(0.4, 2.7, 0), C.Rose, FABRIC),
		},
	},
	IndoorPlants = {
		Category = "Decoration", Name = "Indoor Plants", NameThai = "ต้นไม้ในบ้าน",
		Price = 80, Rarity = "Common", W = 3, D = 3,
		Parts = {
			box(Vector3.new(2.2, 2, 2.2), Vector3.new(0, 1, 0), C.Cream, Enum.Material.Sand, Enum.PartType.Cylinder),
			box(Vector3.new(0.4, 3, 0.4), Vector3.new(0, 3, 0), C.Sage, Enum.Material.Wood),
			box(Vector3.new(2.6, 1.4, 2.6), Vector3.new(-0.6, 4.4, 0), C.Leaf, GRASS, BALL),
			box(Vector3.new(2.2, 1.2, 2.2), Vector3.new(0.7, 5.2, 0.2), C.Sage, GRASS, BALL),
		},
	},
	Carpets = {
		Category = "Decoration", Name = "Patterned Carpet", NameThai = "พรมลาย",
		Price = 95, Rarity = "Rare", W = 6, D = 6, Flat = true,
		Parts = {
			box(Vector3.new(6, 0.2, 6), Vector3.new(0, 0.1, 0), C.Lilac, FABRIC),
			box(Vector3.new(4.4, 0.24, 4.4), Vector3.new(0, 0.12, 0), C.Cream, FABRIC),
			box(Vector3.new(2.4, 0.28, 2.4), Vector3.new(0, 0.14, 0), C.Rose, FABRIC),
		},
	},
	GoldenChandelier = {
		Category = "Decoration", Name = "Golden Chandelier", NameThai = "โคมระย้าทองคำ",
		Price = 900, Rarity = "Legendary", W = 4, D = 4,
		Parts = {
			box(Vector3.new(0.25, 1.6, 0.25), Vector3.new(0, 7.8, 0), C.Butter, METAL),
			box(Vector3.new(3.4, 0.4, 3.4), Vector3.new(0, 6.8, 0), C.Butter, METAL, Enum.PartType.Cylinder),
			box(Vector3.new(0.6, 1.2, 0.6), Vector3.new(-1.2, 6.2, 0), C.Butter, NEON),
			box(Vector3.new(0.6, 1.2, 0.6), Vector3.new(1.2, 6.2, 0), C.Butter, NEON),
			box(Vector3.new(0.6, 1.2, 0.6), Vector3.new(0, 6.2, -1.2), C.Butter, NEON),
			box(Vector3.new(0.6, 1.2, 0.6), Vector3.new(0, 6.2, 1.2), C.Butter, NEON),
			{ Light = true, Offset = Vector3.new(0, 6.4, 0), Range = 30, Color = C.Butter },
		},
	},
}

--[[
	Old save files used a smaller catalogue. These map the retired ids onto their
	closest replacement so nobody loses furniture they already paid for.
]]
Furniture.Legacy = {
	Lamp = "FloorLamp",
	Table = "CoffeeTable",
}

function Furniture.resolve(itemId)
	if type(itemId) ~= "string" then
		return nil
	end
	if Furniture.Items[itemId] then
		return itemId
	end
	local replacement = Furniture.Legacy[itemId]
	if replacement and Furniture.Items[replacement] then
		return replacement
	end
	return nil
end

--[[ A stable display order: category, then rarity, then price. ]]
Furniture.Order = {}
do
	local categoryOrder = {}
	for index, category in ipairs(Furniture.Categories) do
		categoryOrder[category.Id] = index
	end
	for id in pairs(Furniture.Items) do
		table.insert(Furniture.Order, id)
	end
	table.sort(Furniture.Order, function(a, b)
		local left, right = Furniture.Items[a], Furniture.Items[b]
		if left.Category ~= right.Category then
			return categoryOrder[left.Category] < categoryOrder[right.Category]
		end
		local leftRarity = Furniture.Rarities[left.Rarity].Order
		local rightRarity = Furniture.Rarities[right.Rarity].Order
		if leftRarity ~= rightRarity then
			return leftRarity < rightRarity
		end
		return left.Price < right.Price
	end)
end

function Furniture.get(itemId)
	return type(itemId) == "string" and Furniture.Items[itemId] or nil
end

function Furniture.isOutdoor(itemId)
	local item = Furniture.get(itemId)
	return item ~= nil and item.Category == Furniture.OutdoorCategory
end

--[[
	Footprint after rotation. Quarter turns swap width and depth, which is the
	whole reason rotation has to be validated on the server and not just drawn.
]]
function Furniture.footprint(itemId, rotation)
	local item = Furniture.get(itemId)
	if not item then
		return 0, 0
	end
	local turns = (math.floor(tonumber(rotation) or 0) % 360) / 90
	if turns % 2 == 1 then
		return item.D, item.W
	end
	return item.W, item.D
end

return Furniture
