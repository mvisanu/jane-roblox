-- Every quest action has one useful physical destination. Dynamic targets are
-- resolved by QuestNavigator because each player owns a different home.
local QuestGuide = {}

local GUIDES = {
	FinishOnboarding = { Target = "Town", Name = "Wildwood welcome", NameThai = "จุดต้อนรับไวลด์วูด" },
	PaintHome = { Target = "Home", Name = "Your cottage", NameThai = "บ้านของคุณ" },
	GardenPlant = { Target = "HomeGarden", Name = "Your garden", NameThai = "สวนของคุณ" },
	GardenWater = { Target = "HomeGarden", Name = "Your garden", NameThai = "สวนของคุณ" },
	GardenHarvest = { Target = "HomeGarden", Name = "Your garden", NameThai = "สวนของคุณ" },
	Decorate = { Target = "Home", Name = "Inside your home", NameThai = "ในบ้านของคุณ" },
	CafeUnlock = { Target = "Cafe", Name = "Family Cafe", NameThai = "คาเฟ่ครอบครัว" },
	CafeServe = { Target = "Cafe", Name = "Family Cafe", NameThai = "คาเฟ่ครอบครัว" },
	CafeServeMoonBerryTart = { Target = "Cafe", Name = "Moonleaf Family Cafe", NameThai = "คาเฟ่ครอบครัวใบจันทร์" },
	CafeUpgrade = { Target = "Cafe", Name = "Family Cafe", NameThai = "คาเฟ่ครอบครัว" },
	HireCafeStaff = { Target = "Cafe", Name = "Family Cafe", NameThai = "คาเฟ่ครอบครัว" },
	PetFeed = { Target = "PetShop", Name = "Pet Shop", NameThai = "ร้านสัตว์เลี้ยง" },
	PetPlay = { Target = "PetShop", Name = "Mochi", NameThai = "โมจิ" },
	PetBath = { Target = "PetShop", Name = "Mochi", NameThai = "โมจิ" },
	AdventureCollect = { Target = "WildwoodForest", Name = "Wildwood Forest", NameThai = "ป่าไวลด์วูด" },
	AdventureWood = { Target = "WildwoodForest", Name = "Wildwood timber", NameThai = "ไม้ในป่าไวลด์วูด" },
	AdventureHerbs = { Target = "WildwoodForest", Name = "Forest herbs", NameThai = "สมุนไพรในป่าไวลด์วูด" },
	AdventureStone = { Target = "Mountain", Name = "Sunrise Mountain stone", NameThai = "หินบนภูเขาแสงตะวัน" },
	AdventureFish = { Target = "RiverAdventure", Name = "River fishing spots", NameThai = "จุดตกปลาริมแม่น้ำ" },
	AdventureUpgradeCamp = { Target = "AdventureCamp", Name = "Adventure Camp", NameThai = "แคมป์ผจญภัย" },
	AdventureCrystal = { Target = "MysteryCave", Name = "Mystery Cave crystals", NameThai = "คริสตัลในถ้ำลึกลับ" },
	AdventurePuzzleSolved = { Target = "MysteryCave", Name = "Mystery Cave runes", NameThai = "รูนในถ้ำลึกลับ" },
	AdventureUnlockCompanion = { Target = "AdventureCamp", Name = "Adventure companions", NameThai = "เพื่อนที่แคมป์ผจญภัย" },
}

function QuestGuide.get(action)
	return type(action) == "string" and GUIDES[action] or nil
end

function QuestGuide.destination(action)
	local guide = QuestGuide.get(action)
	return guide and guide.Target or nil
end

return table.freeze(QuestGuide)
