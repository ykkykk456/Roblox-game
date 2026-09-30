-- ค่าทั้งหมดของ "อุปกรณ์ป้อม" (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy) · สเปก: design/equipment.md
-- แทนระบบกาชาสกิล + ตั๋วกาชาเดิม (ถอดออกตามคำสั่งเจ้าของเกม 2026-09-30) · ตัวเลขทุกตัว [Proposed]
-- ไฟล์นี้ Client อ่านได้ (ตารางโอกาส/ราคา/ชื่อ ใช้แสดงบน UI) → ห้ามใส่ความลับ · ความจริงทั้งหมดคำนวณที่ Server
--
-- ศัพท์:
--   ช่อง (Slot)   = Barrel ลำกล้อง · Mechanism กลไกยิง · Core แกนพลัง · Plating เกราะ
--   แบบ (Variant) = Fire · Water · Earth · Wind (ชิ้นธาตุ) · Neutral (ชิ้นกลาง ไม่มีธาตุ)
--   ระดับ (Rarity) = Common · Rare · Epic · Legendary
--   id ในกระเป๋า  = "<ช่อง>_<แบบ>_<ระดับ>" เช่น "Barrel_Fire_Rare" (สร้าง/แยกด้วย Util/GearMath.keyOf / parseKey)
--   ค่าเป็น "สัดส่วน" เสมอ: 0.04 = 4%
--
-- ===== อยากปรับอะไร → แก้ตรงไหน (ไม่ต้องแตะโค้ด) =====
--   • ราคาเปิดช่อง 3/4 → SlotPrices                     • ค่าหลักต่อช่อง/ระดับ → MainStat (ชิ้นธาตุ) / NeutralMainStat (ชิ้นกลาง)
--   • โบนัสธาตุตรง → MatchBonus                          • โบนัสชุดธาตุครบ 4 ช่อง → FullSetBonus
--   • เพดานโบนัสรวม → Caps                               • เหรียญจากการย่อย / ค่ารวม 3→1 → Rarities.<ระดับ>.Salvage / MergeCost
--   • จำนวนดรอปจากบอส / ตารางโอกาส / pity → Drops       • ขนาดกระเป๋า → InventoryCap / StackCap
-- ใครใช้: Util/GearMath (สูตร) · Server = Services/GearService, Network/GearHandler, Data/PlayerData (migration/ล้างข้อมูลตอนโหลด),
--   Services/TurretLook (สีตามระดับ) · Client = UI อุปกรณ์ (แสดงผลเท่านั้น)
-- ⚠️ ห้ามแก้: ชื่อ key ใน SlotOrder / Variants / RarityOrder (เป็นส่วนหนึ่งของ id ที่ "เซฟอยู่ในข้อมูลผู้เล่น" → เปลี่ยน = ของผู้เล่นหาย)
--   อยากเปลี่ยนชื่อที่ "โชว์" → แก้ Name / Names แทน

local f = table.freeze

return f({
	-- ===== ช่อง =====
	-- ลำดับช่อง = ลำดับการปลดล็อก (เปิด 2 ช่องแรกตั้งแต่เริ่ม · ช่อง 3 = Core · ช่อง 4 = Plating)
	SlotOrder = f({ "Barrel", "Mechanism", "Core", "Plating" }),
	StartSlots = 2,
	MaxSlots = 4,
	-- ราคาเปิดช่องที่ n (หน่วย: เหรียญ) · ปลดทีละช่องตามลำดับ [Proposed]
	SlotPrices = f({ [3] = 2500, [4] = 15000 }),
	-- Main = ชนิดค่าหลักของช่อง (ต้องเป็นชื่อใน Bonus ของ GearMath)
	Slots = f({
		Barrel = f({ Name = "ลำกล้อง", Icon = "🔫", Main = "Damage" }),
		Mechanism = f({ Name = "กลไกยิง", Icon = "⚙️", Main = "FireRate" }),
		Core = f({ Name = "แกนพลัง", Icon = "🔮", Main = "SkillCooldown" }),
		Plating = f({ Name = "เกราะ", Icon = "🛡️", Main = "TurretHp" }),
	}),

	-- ===== แบบ =====
	-- 4 ธาตุ (ต้องตรงกับ id ใน Config/Elements) + Neutral
	Variants = f({ "Fire", "Water", "Earth", "Wind", "Neutral" }),
	-- สีตัวชิ้นแบบกลาง (ชิ้นธาตุใช้สีธาตุจาก Config/Elements)
	NeutralColor = Color3.fromRGB(150, 155, 165),

	-- ===== ระดับ =====
	RarityOrder = f({ "Common", "Rare", "Epic", "Legendary" }),
	-- Salvage = เหรียญต่อชิ้นเมื่อย่อย · MergeCost = ค่ารวม 3 ชิ้นระดับนี้ → 1 ชิ้นระดับถัดไป (Legendary รวมต่อไม่ได้)
	-- ⚠️ กันปั๊มเงิน: Salvage × 3 ต้อง > Salvage ระดับถัดไป − MergeCost เสมอ (45 > 30 · 180 > 100 · 750 > 400)
	Rarities = f({
		Common = f({ Name = "ธรรมดา", Color = Color3.fromRGB(170, 170, 170), Salvage = 15, MergeCost = 30 }),
		Rare = f({ Name = "หายาก", Color = Color3.fromRGB(70, 140, 255), Salvage = 60, MergeCost = 150 }),
		Epic = f({ Name = "มหากาพย์", Color = Color3.fromRGB(170, 80, 255), Salvage = 250, MergeCost = 600 }),
		Legendary = f({ Name = "ตำนาน", Color = Color3.fromRGB(255, 200, 50), Salvage = 1000 }),
	}),
	-- ชิ้นบนป้อมใหญ่ขึ้นกี่ % ต่อระดับ (Common = 1 · Legendary = 1.15) · หน้าตาเท่านั้น
	LookScalePerRarity = 0.05,

	-- ===== ค่าหลัก (ทุกชิ้นในช่องมี) =====
	-- ชิ้นธาตุ
	MainStat = f({
		Barrel = f({ Common = 0.04, Rare = 0.08, Epic = 0.14, Legendary = 0.22 }), -- ดาเมจ +%
		Mechanism = f({ Common = 0.03, Rare = 0.06, Epic = 0.10, Legendary = 0.16 }), -- อัตรายิง +%
		Core = f({ Common = 0.03, Rare = 0.06, Epic = 0.10, Legendary = 0.15 }), -- คูลดาวน์สกิล −%
		Plating = f({ Common = 0.10, Rare = 0.20, Epic = 0.35, Legendary = 0.50 }), -- เลือดป้อม +%
	}),
	-- ชิ้นกลาง = ค่าหลัก × 1.25 ปัดขึ้น (เขียนตัวเลขตรงๆ กันปัดเศษเพี้ยน · สเปกหัวข้อ 3.1)
	NeutralMainStat = f({
		Barrel = f({ Common = 0.05, Rare = 0.10, Epic = 0.18, Legendary = 0.28 }),
		Mechanism = f({ Common = 0.04, Rare = 0.08, Epic = 0.13, Legendary = 0.20 }),
		Core = f({ Common = 0.04, Rare = 0.08, Epic = 0.13, Legendary = 0.19 }),
		Plating = f({ Common = 0.13, Rare = 0.25, Epic = 0.44, Legendary = 0.63 }),
	}),

	-- ===== โบนัสธาตุตรง (ธาตุชิ้น = ธาตุป้อม เท่านั้น) =====
	-- ธาตุเดียวกันให้ค่ารองชนิดเดียวกันทุกช่อง ("ไฟ = สกิลแรง")
	MatchBonus = f({
		Fire = f({ Stat = "SkillDamage", Common = 0.05, Rare = 0.10, Epic = 0.16, Legendary = 0.25 }),
		Water = f({ Stat = "TurretHp", Common = 0.08, Rare = 0.15, Epic = 0.25, Legendary = 0.40 }),
		Earth = f({ Stat = "BossDamage", Common = 0.03, Rare = 0.06, Epic = 0.10, Legendary = 0.15 }),
		Wind = f({ Stat = "StunReduce", Common = 0.05, Rare = 0.08, Epic = 0.12, Legendary = 0.16 }),
	}),
	-- ใส่ชิ้นธาตุตรงครบ 4 ช่อง → ดาเมจเพิ่มอีก
	FullSetBonus = f({ Stat = "Damage", Value = 0.05 }),
	-- เพดานโบนัสรวม (หลังบวกทุกชิ้น) · StunReduceTotal = รวม Passive ลม (ตัวเบา) แล้วไม่เกินนี้
	Caps = f({ BossDamage = 0.5, SkillCooldown = 0.4, TurretHp = 1.0, StunReduceTotal = 0.7 }),

	-- ===== ชื่อบน UI (20 ชิ้น · id ชิ้น = "<ช่อง>_<แบบ>") =====
	Names = f({
		Barrel_Fire = "ลำกล้องลาวา",
		Barrel_Water = "ลำกล้องธารา",
		Barrel_Earth = "ลำกล้องหินผา",
		Barrel_Wind = "ลำกล้องวายุ",
		Barrel_Neutral = "ลำกล้องเหล็กกล้า",
		Mechanism_Fire = "กลไกเพลิง",
		Mechanism_Water = "กลไกธารา",
		Mechanism_Earth = "กลไกหินผา",
		Mechanism_Wind = "กลไกวายุ",
		Mechanism_Neutral = "กลไกเหล็ก",
		Core_Fire = "แกนเพลิง",
		Core_Water = "แกนธารา",
		Core_Earth = "แกนหินผา",
		Core_Wind = "แกนวายุ",
		Core_Neutral = "แกนเหล็ก",
		Plating_Fire = "เกราะเพลิง",
		Plating_Water = "เกราะธารา",
		Plating_Earth = "เกราะหินผา",
		Plating_Wind = "เกราะวายุ",
		Plating_Neutral = "เกราะเหล็ก",
	}),

	-- ===== ดรอปจากบอส (แทนตั๋วกาชา) · สเปกหัวข้อ 4 =====
	Drops = f({
		BaseRolls = 1, -- ทุกคนที่ตีบอส (ดาเมจ > 0) ได้อย่างน้อยเท่านี้
		ShareRolls = f({ 0.10, 0.25 }), -- share (ดาเมจตัวเอง ÷ รวม) ถึงแต่ละค่า → +1 roll
		TopRollRank = 1, -- อันดับนี้ได้ +1 roll จากตาราง Top (การันตี Rare+)
		RankRolls = f({ 2, 3 }), -- อันดับเหล่านี้ได้ +1 roll จากตารางปกติ
		MaxRolls = 4, -- เพดานต่อคนต่อบอส
		-- ตารางโอกาส (น้ำหนัก รวม 100) · A: share < 10% · B: 10–25% · C: ≥ 25% · Top: roll โบนัสอันดับ 1
		Tables = f({
			A = f({ Common = 72, Rare = 23, Epic = 4.5, Legendary = 0.5 }),
			B = f({ Common = 60, Rare = 30, Epic = 8.5, Legendary = 1.5 }),
			C = f({ Common = 50, Rare = 34, Epic = 13, Legendary = 3 }),
			Top = f({ Common = 0, Rare = 75, Epic = 21, Legendary = 4 }),
		}),
		-- น้ำหนักสุ่มแบบของชิ้น: ธาตุป้อมตัวเอง 2 · ธาตุอื่น 1 · กลาง 1 (ยังไม่เลือกธาตุ = ทุกแบบ 1)
		OwnElementWeight = 2,
		OtherWeight = 1,
		NeutralWeight = 1,
		-- สุ่มครบ PityRolls ครั้งติดโดยไม่ได้ PityRarity ขึ้นไป → ครั้งถัดไปได้ PityRarity แน่นอน (นับข้ามบอส เก็บใน data)
		PityRolls = 30,
		PityRarity = "Epic",
	}),

	-- ===== กระเป๋า =====
	InventoryCap = 150, -- นับทุกสำเนา (รวมชิ้นที่ใส่) · เต็มตอนได้ดรอป → ย่อยเป็นเหรียญอัตโนมัติ
	StackCap = 99, -- 1 id เก็บได้ไม่เกินนี้

	-- ตั๋วกาชาเก่า 1 ใบ = กี่เหรียญ · ใช้ใน migration v6 → v7 (Data/PlayerData) เท่านั้น ⚠️ ห้ามแก้หลังปล่อยเกม
	TicketToCoins = 50,
})
