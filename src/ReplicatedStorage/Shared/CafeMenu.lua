-- The complete Moonleaf Cafe menu. Visuals come from CafeModels so the food is
-- physical 3D geometry both in the display case and in menu ViewportFrames.

local CafeMenu = {}

CafeMenu.Items = {
	MoonBerryTart = {
		Name = "Moon Berry Tart",
		NameThai = "ทาร์ตมูนเบอร์รี",
		Description = "Golden tart with glowing moon berries",
		DescriptionThai = "ทาร์ตสีทองกับมูนเบอร์รีเรืองแสง",
	},
	MoonberryCake = {
		Name = "Moonberry Cake",
		NameThai = "เค้กมูนเบอร์รี",
		Description = "Soft cake with moon frosting and berries",
		DescriptionThai = "เค้กนุ่มแต่งครีมพระจันทร์และเบอร์รี",
	},
	StarCupcake = {
		Name = "Star Cupcake",
		NameThai = "คัพเค้กดาว",
		Description = "Vanilla cupcake with a golden star cookie",
		DescriptionThai = "คัพเค้กวานิลลากับคุกกี้ดาวสีทอง",
	},
	SunTea = {
		Name = "Sun Tea",
		NameThai = "ชาดวงอาทิตย์",
		Description = "Warm golden tea with lemon and herbs",
		DescriptionThai = "ชาสีทองอุ่น ๆ กับมะนาวและสมุนไพร",
	},
}

CafeMenu.Order = { "MoonBerryTart", "MoonberryCake", "StarCupcake", "SunTea" }

function CafeMenu.get(itemId)
	return type(itemId) == "string" and CafeMenu.Items[itemId] or nil
end

function CafeMenu.resolve(itemId)
	return CafeMenu.get(itemId) and itemId or "StarCupcake"
end

return table.freeze(CafeMenu)
