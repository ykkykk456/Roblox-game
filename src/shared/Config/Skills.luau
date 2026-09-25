-- สกิลป้อม + กาชา (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy · รายชื่อสกิล: Systems_Designer)
-- Client อ่านได้: ใช้แสดงรายชื่อสกิลและ "โอกาสได้" ในหน้ากาชา (โปร่งใสตามแนวทางกาชาของ IDEA.md)
-- [Proposed] ทุกค่าเป็นค่าชั่วคราวสำหรับ prototype
--
-- ผลของสกิล (ใส่เฉพาะที่ใช้):
--   FireRate / Damage / BossDamage = ตัวคูณระหว่างสกิลทำงาน (BossDamage ใช้เฉพาะตอนยิงบอส)
--   Burst = ยิงทันที 1 ครั้งแรงเท่ากับ ดาเมจป้อม × Burst (ต้องมีเป้าในระยะถึงจะกดได้)
-- เลเวลสกิลเพิ่ม "ส่วนที่เกิน 1" ของตัวคูณ และ Burst ทีละ PowerPerLevel (ดู Util/SkillMath)

return table.freeze({
	StarterSkill = "Overdrive", -- ผู้เล่นทุกคนมีตั้งแต่เริ่ม
	MaxLevel = 5,
	PowerPerLevel = 0.25, -- +25% ของพลังสกิลต่อเลเวล
	CopiesToUpgrade = table.freeze({ 1, 2, 3, 4 }), -- [เลเวลปัจจุบัน] = จำนวนสกิลซ้ำที่ใช้อัปไปเลเวลถัดไป

	-- น้ำหนักรวม = 100 → เท่ากับ % โดยตรง · ในระดับเดียวกันแบ่งโอกาสเท่ากัน
	Rarities = table.freeze({
		table.freeze({ Id = "Common", Name = "ธรรมดา", Weight = 60, Color = Color3.fromRGB(170, 176, 190) }),
		table.freeze({ Id = "Rare", Name = "หายาก", Weight = 28, Color = Color3.fromRGB(80, 160, 255) }),
		table.freeze({
			Id = "Epic",
			Name = "มหากาพย์",
			Weight = 10,
			Color = Color3.fromRGB(180, 100, 255),
		}),
		table.freeze({ Id = "Legendary", Name = "ตำนาน", Weight = 2, Color = Color3.fromRGB(255, 196, 60) }),
	}),

	-- ลำดับการแสดงผล
	Order = table.freeze({ "Overdrive", "HeavyRounds", "BossBreaker", "Barrage", "Overload" }),

	List = table.freeze({
		Overdrive = table.freeze({
			Name = "Overdrive",
			Rarity = "Common",
			Description = "ยิงเร็วขึ้น",
			Duration = 5,
			Cooldown = 30,
			FireRate = 3,
		}),
		HeavyRounds = table.freeze({
			Name = "กระสุนหนัก",
			Rarity = "Common",
			Description = "ดาเมจแรงขึ้น",
			Duration = 6,
			Cooldown = 35,
			Damage = 2,
		}),
		BossBreaker = table.freeze({
			Name = "ทุบบอส",
			Rarity = "Rare",
			Description = "ดาเมจใส่บอสแรงขึ้นมาก",
			Duration = 6,
			Cooldown = 40,
			BossDamage = 3,
		}),
		Barrage = table.freeze({
			Name = "ระดมยิง",
			Rarity = "Epic",
			Description = "ยิงนัดใหญ่ทันที",
			Duration = 0,
			Cooldown = 45,
			Burst = 30,
		}),
		Overload = table.freeze({
			Name = "โอเวอร์โหลด",
			Rarity = "Legendary",
			Description = "ยิงเร็วและแรงขึ้นพร้อมกัน",
			Duration = 6,
			Cooldown = 60,
			FireRate = 3,
			Damage = 2,
		}),
	}),
})
