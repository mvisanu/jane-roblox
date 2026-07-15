local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WildwoodStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildwoodStyle"))
local W = WildwoodStyle.Colors
local WORLD = WildwoodStyle.World
local PETS = WildwoodStyle.Pets
local AVATARS = WildwoodStyle.Avatars
local Catalog = {}
-- Median lit face tone sampled from the approved six-character render.
local SKIN = Color3.fromRGB(238, 183, 123)

Catalog.Seeds = {
	Daisy = { DisplayName = "Daisy", DisplayNameThai = "เดซี่", GrowSeconds = 20, SellPrice = 30, Color = WORLD.Flower },
	Tulip = { DisplayName = "Tulip", DisplayNameThai = "ทิวลิป", GrowSeconds = 35, SellPrice = 50, Color = WORLD.RoofHighlight },
	Lavender = { DisplayName = "Lavender", DisplayNameThai = "ลาเวนเดอร์", GrowSeconds = 50, SellPrice = 75, Color = WORLD.WaterLight },
}

Catalog.SeedOrder = { "Daisy", "Tulip", "Lavender" }

-- Furniture now lives in its own module: see Shared/Furniture.lua. Keeping a
-- second copy here is exactly how the two drift apart.

Catalog.Outfits = {
	MaleTrailRanger = {
		DisplayName = "Trail Ranger",
		DisplayNameThai = "เรนเจอร์เส้นทางป่า",
		Style = "MaleTrailRanger",
		Gender = "Male",
		ConceptIndex = 1,
		Torso = AVATARS.TrailRanger.Primary,
		Arms = SKIN,
		Legs = AVATARS.TrailRanger.Deep,
		Palette = AVATARS.TrailRanger,
	},
	MaleRiverWarden = {
		DisplayName = "River Warden",
		DisplayNameThai = "ผู้พิทักษ์สายน้ำ",
		Style = "MaleRiverWarden",
		Gender = "Male",
		ConceptIndex = 2,
		Torso = AVATARS.RiverWarden.Primary,
		Arms = SKIN,
		Legs = AVATARS.RiverWarden.Deep,
		Palette = AVATARS.RiverWarden,
	},
	MaleAutumnArcher = {
		DisplayName = "Autumn Archer",
		DisplayNameThai = "นักธนูฤดูใบไม้ร่วง",
		Style = "MaleAutumnArcher",
		Gender = "Male",
		ConceptIndex = 3,
		Torso = AVATARS.AutumnArcher.Primary,
		Arms = SKIN,
		Legs = AVATARS.AutumnArcher.Deep,
		Palette = AVATARS.AutumnArcher,
	},
	FemaleWildflowerBotanist = {
		DisplayName = "Wildflower Botanist",
		DisplayNameThai = "นักพฤกษศาสตร์ดอกไม้ป่า",
		Style = "FemaleWildflowerBotanist",
		Gender = "Female",
		ConceptIndex = 4,
		Torso = AVATARS.WildflowerBotanist.Primary,
		Arms = SKIN,
		Legs = AVATARS.WildflowerBotanist.Deep,
		Palette = AVATARS.WildflowerBotanist,
	},
	FemaleFernGuardian = {
		DisplayName = "Fern Guardian",
		DisplayNameThai = "ผู้พิทักษ์เฟิร์น",
		Style = "FemaleFernGuardian",
		Gender = "Female",
		ConceptIndex = 5,
		Torso = AVATARS.FernGuardian.Primary,
		Arms = SKIN,
		Legs = AVATARS.FernGuardian.Deep,
		Palette = AVATARS.FernGuardian,
	},
	FemalePineScout = {
		DisplayName = "Pine Scout",
		DisplayNameThai = "นักสำรวจป่าสน",
		Style = "FemalePineScout",
		Gender = "Female",
		ConceptIndex = 6,
		Torso = AVATARS.PineScout.Primary,
		Arms = SKIN,
		Legs = AVATARS.PineScout.Deep,
		Palette = AVATARS.PineScout,
	},
}

Catalog.AvatarOrder = {
	"MaleTrailRanger",
	"MaleRiverWarden",
	"MaleAutumnArcher",
	"FemaleWildflowerBotanist",
	"FemaleFernGuardian",
	"FemalePineScout",
}

-- Style is now an avatar selector, not the former color-only outfit closet.
-- Only these six full character presets can be selected or saved.
Catalog.OutfitOrder = {
	"MaleTrailRanger",
	"MaleRiverWarden",
	"MaleAutumnArcher",
	"FemaleWildflowerBotanist",
	"FemaleFernGuardian",
	"FemalePineScout",
}

--[[
	The five things you can carry.

	`Icon` and `FoundIn` are not decoration. This game is played by five-year-olds,
	many of whom cannot yet read "Cave Crystal" - so every place an amount is shown
	(the bag, the quest board, the camp checklist) shows the picture beside it, and
	says where the thing comes from. A child who cannot read the word can still
	match the picture to the one on the quest.
]]
Catalog.AdventureResources = {
	Wood = { DisplayName = "Wildwood", DisplayNameThai = "ไม้ป่า", Icon = "🪵", Color = WORLD.TimberWarm, FoundIn = "Wildwood Forest", FoundInThai = "ป่าไวลด์วูด" },
	Stone = { DisplayName = "Mountain Stone", DisplayNameThai = "หินภูเขา", Icon = "🪨", Color = WORLD.Stone, FoundIn = "Sunrise Mountain", FoundInThai = "ภูเขาแสงตะวัน" },
	Herbs = { DisplayName = "Forest Herbs", DisplayNameThai = "สมุนไพรป่า", Icon = "🌿", Color = WORLD.FoliageLight, FoundIn = "Wildwood Forest and the River", FoundInThai = "ป่าไวลด์วูดและแม่น้ำ" },
	Fish = { DisplayName = "River Fish", DisplayNameThai = "ปลาจากแม่น้ำ", Icon = "🐟", Color = WORLD.Water, FoundIn = "River & Lake", FoundInThai = "แม่น้ำและทะเลสาบ" },
	Crystal = { DisplayName = "Cave Crystal", DisplayNameThai = "คริสตัลถ้ำ", Icon = "💎", Color = WORLD.WaterLight, FoundIn = "Mystery Cave", FoundInThai = "ถ้ำลึกลับ" },
}

Catalog.AdventureResourceOrder = { "Wood", "Stone", "Herbs", "Fish", "Crystal" }

Catalog.AdventureZones = {
	WildwoodForest = { DisplayName = "Wildwood Forest", DisplayNameThai = "ป่าไวลด์วูด", Resource = "Wood" },
	Mountain = { DisplayName = "Sunrise Mountain", DisplayNameThai = "ภูเขาแสงตะวัน", Resource = "Stone" },
	RiverAdventure = { DisplayName = "River & Lake", DisplayNameThai = "แม่น้ำและทะเลสาบ", Resource = "Fish" },
	MysteryCave = { DisplayName = "Mystery Cave", DisplayNameThai = "ถ้ำลึกลับ", Resource = "Crystal" },
}

Catalog.AdventureZoneOrder = { "WildwoodForest", "Mountain", "RiverAdventure", "MysteryCave" }

Catalog.Companions = {
	Cat = { DisplayName = "Mochi the Cat", DisplayNameThai = "โมจิแมวคู่ใจ", Ability = "Cozy friend", AbilityThai = "เพื่อนแสนอบอุ่น", Color = PETS.Cat.Main, Cost = {} },
	Fox = { DisplayName = "Fern the Redwood Fox", DisplayNameThai = "เฟิร์นจิ้งจอก", Ability = "Finds extra forest items", AbilityThai = "ค้นหาของป่าเพิ่ม", Color = PETS.Fox.Main, Cost = { Wood = 4, Herbs = 2 } },
	Owl = { DisplayName = "Twilight the Wise Owl", DisplayNameThai = "ทไวไลท์นกฮูก", Ability = "Reveals cave clues", AbilityThai = "เผยคำใบ้ในถ้ำ", Color = PETS.Owl.Main, Cost = { Crystal = 2, Wood = 2 } },
	Dog = { DisplayName = "Scout the Shiba", DisplayNameThai = "สเกาต์สุนัข", Ability = "Tracks extra mountain items", AbilityThai = "ตามหาของบนภูเขาเพิ่ม", Color = PETS.Dog.Main, Cost = { Stone = 4, Herbs = 2 } },
	Rabbit = { DisplayName = "Clover the Cotton Rabbit", DisplayNameThai = "โคลเวอร์กระต่าย", Ability = "Finds bonus garden seeds", AbilityThai = "หาเมล็ดสวนเพิ่ม", Color = PETS.Rabbit.Main, Cost = { Herbs = 4, Wood = 2 } },
}

Catalog.CompanionOrder = { "Cat", "Fox", "Owl", "Dog", "Rabbit" }

Catalog.CampLevels = {
	{ Name = "Campsite", NameThai = "แคมป์เล็ก", Cost = {} },
	{ Name = "Tree House", NameThai = "บ้านต้นไม้", Cost = { Wood = 8, Herbs = 3 } },
	{ Name = "Wooden Cottage", NameThai = "กระท่อมไม้", Cost = { Wood = 12, Stone = 6 } },
	{ Name = "Workshop", NameThai = "เวิร์กช็อป", Cost = { Wood = 15, Stone = 10, Crystal = 2 } },
	{ Name = "Animal Shelter", NameThai = "ศูนย์พักพิงสัตว์", Cost = { Wood = 18, Herbs = 10, Stone = 8 } },
	{ Name = "Adventure Center", NameThai = "ศูนย์ผจญภัย", Cost = { Wood = 25, Stone = 15, Crystal = 6, Fish = 5 } },
}

--[[
	Quest chains.

	Each chain is a run of steps that must be done in order, and the reward grows
	as you get deeper in. Finishing the last step banks a much larger chest bonus
	that the player claims by hand, which is the moment the whole chain is built
	around. Chains unlock one after another, so there is always a next thing.

	Every Action here is one the server already validates, so a chain can never
	be advanced by a client that simply asks nicely.
]]
-- Increment this whenever the authored story is replaced. DataService uses it
-- to restart only the quest journal, without taking away a player's home,
-- cafe, companions, resources, coins, or purchases.
Catalog.QuestlineVersion = 2

Catalog.QuestChains = {
	{
		Id = "WelcomeToWildwood",
		Name = "A Home in Wildwood",
		NameThai = "บ้านใหม่ในไวลด์วูด",
		Blurb = "Arrive in town, make the cottage yours, and meet Mochi.",
		BlurbThai = "เดินทางถึงเมือง จัดบ้านให้น่าอยู่ และทำความรู้จักโมจิ",
		Bonus = 250,
		Steps = {
			{ Action = "FinishOnboarding", Target = 1, Reward = 40, Description = "Open your Wildwood journal", DescriptionThai = "เปิดสมุดบันทึกไวลด์วูด", Hint = "Press LET'S PLAY on the welcome card.", HintThai = "กด เริ่มเล่น บนการ์ดต้อนรับ" },
			{ Action = "PaintHome", Target = 1, Reward = 60, Description = "Choose a colour for your cottage", DescriptionThai = "เลือกสีให้บ้านของคุณ", Hint = "Open Home and tap a color swatch.", HintThai = "เปิดเมนูบ้าน แล้วแตะช่องสีที่ชอบ" },
			{ Action = "Decorate", Target = 1, Reward = 80, Description = "Place your first cosy chair", DescriptionThai = "วางเก้าอี้แสนสบายชิ้นแรก", Hint = "Your furniture box already has a chair.", HintThai = "ในกล่องเฟอร์นิเจอร์มีเก้าอี้อยู่แล้ว" },
			{ Action = "PetPlay", Target = 1, Reward = 90, Description = "Play with Mochi", DescriptionThai = "เล่นกับโมจิ", Hint = "Open Pet and choose Play.", HintThai = "เปิดเมนูสัตว์เลี้ยง แล้วเลือกเล่น" },
		},
	},
	{
		Id = "GardenPromise",
		Name = "The Garden Promise",
		NameThai = "คำสัญญาในสวน",
		Blurb = "Grow the first flowers and care for the friend beside you.",
		BlurbThai = "ปลูกดอกไม้ชุดแรกและดูแลเพื่อนตัวน้อยข้างกาย",
		Bonus = 450,
		Steps = {
			{ Action = "GardenPlant", Target = 2, Reward = 70, Description = "Plant 2 Daisy seeds", DescriptionThai = "ปลูกเมล็ดเดซี่ 2 เมล็ด", Hint = "Your garden starts with 5 Daisy seeds.", HintThai = "สวนของคุณมีเมล็ดเดซี่เริ่มต้น 5 เมล็ด" },
			{ Action = "GardenWater", Target = 2, Reward = 80, Description = "Water both flowers", DescriptionThai = "รดน้ำดอกไม้ทั้ง 2 ต้น" },
			{ Action = "GardenHarvest", Target = 2, Reward = 120, Description = "Pick the 2 grown flowers", DescriptionThai = "เก็บดอกไม้ที่โตแล้ว 2 ดอก", Hint = "Watered Daisies bloom after 20 seconds.", HintThai = "เดซี่ที่รดน้ำแล้วจะบานใน 20 วินาที" },
			{ Action = "PetFeed", Target = 1, Reward = 100, Description = "Share a snack with Mochi", DescriptionThai = "ให้ขนมโมจิ 1 ครั้ง" },
			{ Action = "PetBath", Target = 1, Reward = 120, Description = "Give Mochi a bubble bath", DescriptionThai = "อาบน้ำฟองสบู่ให้โมจิ" },
		},
	},
	{
		Id = "MoonleafOpening",
		Name = "Moonleaf Opening Day",
		NameThai = "วันเปิดคาเฟ่ใบจันทร์",
		Blurb = "Turn the quiet bakery into the warm heart of town.",
		BlurbThai = "เปลี่ยนร้านขนมเงียบ ๆ ให้เป็นหัวใจอันอบอุ่นของเมือง",
		Bonus = 700,
		Steps = {
			{ Action = "CafeUnlock", Target = 1, Reward = 130, CafeUnlocked = true, Description = "Open Moonleaf Family Cafe", DescriptionThai = "เปิดคาเฟ่ครอบครัวใบจันทร์" },
			{ Action = "CafeServeMoonBerryTart", Target = 3, Reward = 180, Description = "Serve 3 Moon Berry Tarts", DescriptionThai = "เสิร์ฟทาร์ตมูนเบอร์รี 3 ชิ้น", Hint = "Choose the glowing blue-berry tart on the Cafe menu.", HintThai = "เลือกทาร์ตเบอร์รีสีฟ้าเรืองแสงในเมนูคาเฟ่" },
			{ Action = "CafeServe", Target = 2, Reward = 140, Description = "Serve 2 more cafe guests", DescriptionThai = "เสิร์ฟลูกค้าคาเฟ่อีก 2 คน" },
			{ Action = "CafeUpgrade", Target = 1, Reward = 220, CafeLevel = 2, Description = "Upgrade the busy cafe", DescriptionThai = "อัปเกรดคาเฟ่ที่กำลังคึกคัก", Hint = "Five served guests unlock the first upgrade.", HintThai = "เสิร์ฟครบ 5 คนเพื่อปลดล็อกการอัปเกรดแรก" },
			{ Action = "HireCafeStaff", Target = 1, Reward = 260, CafeStaff = 1, Description = "Welcome your first cafe helper", DescriptionThai = "ต้อนรับผู้ช่วยคาเฟ่คนแรก" },
		},
	},
	{
		Id = "FirstForestLight",
		Name = "First Light in the Forest",
		NameThai = "แสงแรกในผืนป่า",
		Blurb = "Follow the lantern trail, raise a tree house, and find a forest friend.",
		BlurbThai = "ตามทางโคมไฟ สร้างบ้านต้นไม้ และพบเพื่อนจากผืนป่า",
		Bonus = 900,
		Steps = {
			{ Action = "AdventureWood", Target = 8, Reward = 120, Description = "Gather 8 Wildwood", DescriptionThai = "เก็บไม้ป่า 8 ชิ้น" },
			{ Action = "AdventureHerbs", Target = 3, Reward = 100, Description = "Gather 3 Forest Herbs", DescriptionThai = "เก็บสมุนไพรป่า 3 ชิ้น" },
			{ Action = "AdventureUpgradeCamp", Target = 1, Reward = 250, CampLevel = 2, Description = "Build the Tree House", DescriptionThai = "สร้างบ้านต้นไม้" },
			{ Action = "AdventureWood", Target = 4, Reward = 100, Description = "Gather 4 Wildwood for a friend", DescriptionThai = "เก็บไม้ป่า 4 ชิ้นให้เพื่อนใหม่" },
			{ Action = "AdventureHerbs", Target = 2, Reward = 100, Description = "Gather 2 Forest Herbs for a friend", DescriptionThai = "เก็บสมุนไพรป่า 2 ชิ้นให้เพื่อนใหม่" },
			{ Action = "AdventureUnlockCompanion", Target = 1, Reward = 260, Companion = "Fox", Description = "Befriend Fern the Fox", DescriptionThai = "ผูกมิตรกับเฟิร์นจิ้งจอก", Hint = "Fern is waiting in the Adventure menu.", HintThai = "เฟิร์นรออยู่ในเมนูผจญภัย" },
		},
	},
	{
		Id = "RiverMountainMoon",
		Name = "River, Mountain, Moon",
		NameThai = "สายน้ำ ภูเขา และแสงจันทร์",
		Blurb = "Carry the trail beyond the forest and uncover the cave's song.",
		BlurbThai = "เดินทางพ้นผืนป่าและค้นพบบทเพลงของถ้ำลึกลับ",
		Bonus = 1200,
		Steps = {
			{ Action = "AdventureWood", Target = 12, Reward = 180, Description = "Gather 12 Wildwood", DescriptionThai = "เก็บไม้ป่า 12 ชิ้น" },
			{ Action = "AdventureStone", Target = 6, Reward = 180, Description = "Gather 6 Mountain Stone", DescriptionThai = "เก็บหินภูเขา 6 ก้อน" },
			{ Action = "AdventureUpgradeCamp", Target = 1, Reward = 320, CampLevel = 3, Description = "Build the Wooden Cottage", DescriptionThai = "สร้างกระท่อมไม้" },
			{ Action = "AdventureFish", Target = 5, Reward = 200, Description = "Catch 5 River Fish for later", DescriptionThai = "จับปลาจากแม่น้ำเก็บไว้ 5 ตัว", Hint = "Keep these fish for the final Adventure Center.", HintThai = "เก็บปลาไว้ใช้สร้างศูนย์ผจญภัยในตอนสุดท้าย" },
			{ Action = "AdventureCrystal", Target = 2, Reward = 220, Description = "Find 2 Cave Crystals", DescriptionThai = "หาคริสตัลถ้ำ 2 ชิ้น" },
			{ Action = "AdventurePuzzleSolved", Target = 1, Reward = 380, Description = "Wake the Mystery Cave runes", DescriptionThai = "ปลุกรูนในถ้ำลึกลับ", Hint = "Touch Leaf, River, then Sun.", HintThai = "แตะรูน ใบไม้ สายน้ำ แล้วดวงอาทิตย์" },
		},
	},
	{
		Id = "WorkshopStars",
		Name = "A Workshop Under the Stars",
		NameThai = "เวิร์กช็อปใต้แสงดาว",
		Blurb = "Build a place where every strange forest treasure has a purpose.",
		BlurbThai = "สร้างที่ซึ่งสมบัติแปลกตาจากป่าทุกชิ้นมีประโยชน์",
		Bonus = 1600,
		Steps = {
			{ Action = "AdventureWood", Target = 15, Reward = 220, Description = "Gather 15 Wildwood", DescriptionThai = "เก็บไม้ป่า 15 ชิ้น" },
			{ Action = "AdventureStone", Target = 10, Reward = 240, Description = "Gather 10 Mountain Stone", DescriptionThai = "เก็บหินภูเขา 10 ก้อน" },
			{ Action = "AdventureUpgradeCamp", Target = 1, Reward = 450, CampLevel = 4, Description = "Build the Workshop", DescriptionThai = "สร้างเวิร์กช็อป" },
			{ Action = "AdventureWood", Target = 2, Reward = 100, Description = "Gather 2 Wildwood for Twilight", DescriptionThai = "เก็บไม้ป่า 2 ชิ้นให้ทไวไลท์" },
			{ Action = "AdventureUnlockCompanion", Target = 1, Reward = 400, Companion = "Owl", Description = "Befriend Twilight the Owl", DescriptionThai = "ผูกมิตรกับทไวไลท์นกฮูก", Hint = "The two spare cave crystals are Twilight's gift.", HintThai = "คริสตัลถ้ำที่เหลือ 2 ชิ้นคือของขวัญให้ทไวไลท์" },
		},
	},
	{
		Id = "ShelterManyPaws",
		Name = "A Shelter for Many Paws",
		NameThai = "บ้านพักของเพื่อนตัวน้อย",
		Blurb = "Make the camp safe and warm for every woodland companion.",
		BlurbThai = "ทำให้แคมป์ปลอดภัยและอบอุ่นสำหรับเพื่อนจากผืนป่าทุกตัว",
		Bonus = 2000,
		Steps = {
			{ Action = "AdventureWood", Target = 18, Reward = 260, Description = "Gather 18 Wildwood", DescriptionThai = "เก็บไม้ป่า 18 ชิ้น" },
			{ Action = "AdventureHerbs", Target = 10, Reward = 240, Description = "Gather 10 Forest Herbs", DescriptionThai = "เก็บสมุนไพรป่า 10 ชิ้น" },
			{ Action = "AdventureStone", Target = 8, Reward = 240, Description = "Gather 8 Mountain Stone", DescriptionThai = "เก็บหินภูเขา 8 ก้อน" },
			{ Action = "AdventureUpgradeCamp", Target = 1, Reward = 600, CampLevel = 5, Description = "Build the Animal Shelter", DescriptionThai = "สร้างศูนย์พักพิงสัตว์" },
		},
	},
	{
		Id = "HeartOfWildwood",
		Name = "The Heart of Wildwood",
		NameThai = "หัวใจแห่งไวลด์วูด",
		Blurb = "Finish the Adventure Center, then bring everyone home for a feast.",
		BlurbThai = "สร้างศูนย์ผจญภัยให้เสร็จ แล้วพาทุกคนกลับมาฉลองด้วยกัน",
		Bonus = 3000,
		Steps = {
			{ Action = "AdventureWood", Target = 25, Reward = 320, Description = "Gather 25 Wildwood", DescriptionThai = "เก็บไม้ป่า 25 ชิ้น" },
			{ Action = "AdventureStone", Target = 15, Reward = 320, Description = "Gather 15 Mountain Stone", DescriptionThai = "เก็บหินภูเขา 15 ก้อน" },
			{ Action = "AdventureCrystal", Target = 4, Reward = 360, Description = "Find 4 Cave Crystals", DescriptionThai = "หาคริสตัลถ้ำ 4 ชิ้น" },
			{ Action = "AdventurePuzzleSolved", Target = 1, Reward = 500, Description = "Ask the cave for its final 2 crystals", DescriptionThai = "ขอคริสตัล 2 ชิ้นสุดท้ายจากถ้ำ" },
			{ Action = "AdventureUpgradeCamp", Target = 1, Reward = 900, CampLevel = 6, Description = "Build the Adventure Center", DescriptionThai = "สร้างศูนย์ผจญภัย", Hint = "Use the 5 fish saved from your river journey.", HintThai = "ใช้ปลา 5 ตัวที่เก็บไว้จากการเดินทางริมแม่น้ำ" },
			{ Action = "CafeServeMoonBerryTart", Target = 5, Reward = 600, Description = "Serve 5 Moon Berry Tarts at the celebration", DescriptionThai = "เสิร์ฟทาร์ตมูนเบอร์รี 5 ชิ้นในงานฉลอง" },
		},
	},
}

Catalog.SeasonEvents = {
	Spring = { Name = "Garden Adventure", NameThai = "ผจญภัยในสวน", Description = "Discover new herbs and flowers.", DescriptionThai = "ค้นพบสมุนไพรและดอกไม้ใหม่" },
	Summer = { Name = "Wild Camp", NameThai = "แคมป์กลางป่า", Description = "Build and explore beneath warm lanterns.", DescriptionThai = "สร้างแคมป์และสำรวจใต้แสงโคมไฟอุ่น" },
	Autumn = { Name = "Forest Festival", NameThai = "เทศกาลป่า", Description = "Collect forest treasures with friends.", DescriptionThai = "เก็บสมบัติป่ากับเพื่อน ๆ" },
	Winter = { Name = "Snow Village", NameThai = "หมู่บ้านหิมะ", Description = "Turn the adventure camp into a winter village.", DescriptionThai = "เปลี่ยนแคมป์ผจญภัยเป็นหมู่บ้านฤดูหนาว" },
}

return table.freeze(Catalog)
