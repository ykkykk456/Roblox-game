-- ธาตุป้อม 4 ธาตุ + สกิลธาตุ (แทนคลาสป้อม Skill_class_default เดิม) · สเปก: design/element-skills.md
-- เจ้าของรายชื่อ/กฎ: Systems_Designer · เจ้าของตัวเลข: Economy_Designer (ผ่าน /roblox-economy)
-- Client อ่านได้: ใช้แสดงชื่อ/คำอธิบาย/สี/สกิล ในหน้าเลือกธาตุ · Server ใช้คำนวณจริง (ห้ามมีความลับ)
-- [Proposed] ตัวเลขทุกตัวเป็นค่าจากสเปกฉบับร่าง (2026-09-30) · ยังไม่ได้ทดสอบใน Studio
-- ขอบเขตตอนนี้ (เจ้าของเกมสั่ง 2026-09-30): ทำแค่ธาตุพื้นฐาน 4 ธาตุ · วิวัฒนาการ/ตื่นพลัง = แผน ยังไม่ทำ (ดูสเปกหัวข้อ 3–4)
--
-- ความหมายค่า (ตัวคูณเทียบกับป้อมพื้นฐานใน Config/Combat.Turret):
--   D          = ดาเมจต่อนัดตามเลเวล (TurretMath.damage) × โบนัสเพื่อน · "ก่อน" คูณตัวคูณธาตุ
--   Damage     = ตัวคูณดาเมจต่อนัดของการยิงปกติ     FireRate = ตัวคูณอัตรายิง
--   Shot       = การยิงปกติ: Fx (ชนิดภาพ) · Splash (รัศมีระเบิด) · MonsterSlow (ช้าลง) · Knockback (ถอย) · Pierce (ทะลุ)
--   Passive    = ความสามารถติดตัว 1 อัน (Kind ดูด้านล่าง)
--   Skill      = สกิลกด 1 อัน (ปุ่ม Q / X / ปุ่มบนจอ) · Pattern = รูปแบบการยิง · Status = ผลที่ติดเป้า
--   ดาเมจสกิล  = Pattern.Damage × D × (อัตรายิงตามเลเวล ÷ BaseFireRate ถ้า ScaleWithFireRate)
--   ตัวอย่าง: Lv.1 ลูกไฟพัด ลูกละ 2.0 × D 10 × (1 ÷ 1) = 20 ต่อลูก · Lv.11 = 2.0 × 60 × (2 ÷ 1) = 240 ต่อลูก
--
-- Kind ที่มีโค้ดรองรับที่ Server (ตั้งชื่อใหม่ = ต้องเขียนโค้ดเพิ่ม):
--   Passive.Kind: Burn · Regen · SlamReduce · StunReduce  (+ เตรียมไว้ให้วิวัฒนาการ: Revive · EveryNth · ArmorBreak · Shock)
--   Status.Kind : Burn · Knockback                         (+ เตรียมไว้: Shock · ArmorBreak · BossSlamDelay)
--   Pattern.Kind: Volley · LaneWave                        (+ เตรียมไว้: Beam · Strikes · Zone · Buff) → Services/ElementSkillService
-- Fx = ชื่อภาพที่ Client วาด (Controllers/TurretController.DRAWERS) · ต้องลงทะเบียนใน Combat.Turret.Projectile ด้วย
--
-- 📖 อ่านตามลำดับนี้ (ค่าในไฟล์นี้ถูก "ค้นหา" ยังไง):
--   1) Server รู้ธาตุของผู้เล่นจาก PlayerData.Element (เช่น "Fire" · "" = ยังไม่เลือก)
--   2) Util/ElementMath.stats(ธาตุ, เลเวล) → ยังไม่เลือก = Unchosen · มีธาตุ = Elements.<ธาตุ>
--   3) Services/TurretService ยิงตาม Damage/FireRate/Shot/Passive · กดสกิล → Services/ElementSkillService ทำตาม Skill.Pattern
--   4) Services/TurretLook ปั้นหน้าตาป้อมตามธาตุ + ขั้นหน้าตา (LookTiers) หรือใช้โมเดลที่ import เอง (CustomModel)
--   5) UI/ElementUI อ่านไฟล์นี้เพื่อแสดงการ์ดเลือกธาตุ (แสดงผลเท่านั้น)
--
-- ⚠️ ชื่อคีย์ธาตุ (Fire, Water, Earth, Wind) ถูกบันทึกใน DataStore ของผู้เล่น → ห้ามเปลี่ยนชื่อคีย์หลังเปิดเกม
-- ⚠️ เปลี่ยน Kind / Fx เป็นชื่อใหม่ ต้องแก้โค้ด Server/Client ด้วย (แก้แค่ตัวเลขได้เลย)
-- 💡 table.freeze = ล็อกตารางไม่ให้โค้ดไหนแก้ค่าระหว่างเกม · Color3.fromRGB(แดง, เขียว, น้ำเงิน) ค่าละ 0–255

local f = table.freeze

return f({
	-- ===== กฎรวม =====
	-- ✏️ ราคาเปลี่ยนธาตุ (ตัวเลขเงิน → /roblox-economy)
	-- [Proposed] เงินที่ใช้เปลี่ยนธาตุ (เลือกครั้งแรกฟรี) · ห้ามเปลี่ยนระหว่างบอสอยู่ · เลเวลป้อมคงเดิม
	ChangeElementCost = 5000,
	-- [Proposed] เวลาเดินทางนานสุดของกระสุนสกิล (วินาที) · กระสุนปกติใช้ Combat.Turret.Projectile.MaxTravel
	SkillMaxTravel = 2,
	-- [Proposed] แผนวิวัฒนาการที่ Lv.20 (เจ้าของเกมปักไว้ 2026-09-30) · ⚠️ ยังไม่ใช้ในโค้ด (ยังไม่ทำวิวัฒนาการ)
	EvolveLevel = 20,

	-- ===== หน้าตาป้อมตามเลเวล (อัปทุก 10 เลเวล) =====
	-- ✏️ LookTiers = เลเวลที่หน้าตาป้อมเปลี่ยนขั้น (เรียงน้อย → มาก · ขั้นที่ 1 ต้องเป็น 1) · ถึงเลเวลไหน = ปั้นป้อมใหม่
	--   ตัวอย่าง: Lv.1–9 = ขั้น 1 · Lv.10–19 = ขั้น 2 · ... · Lv.50 = ขั้น 6
	LookTiers = f({ 1, 10, 20, 30, 40, 50 }),
	-- ป้อมโค้ด (prototype) ใหญ่ขึ้นขั้นละเท่าไร · 0.06 = ขั้น 6 ใหญ่กว่าขั้น 1 อยู่ 30%
	LookScalePerTier = 0.06,

	-- ===== โมเดลป้อมที่ import เอง (แทนป้อมโค้ด) · รายละเอียดวิธีทำ → หัวไฟล์ server/Services/TurretLook.luau =====
	-- วางโมเดลไว้ที่ ServerStorage > TurretModels ชื่อ "<ธาตุ>_<เลเวลขั้น>" เช่น Fire_1, Fire_10 … (หรือ "Fire" ใช้ทุกขั้น)
	-- Height = ย่อ/ขยายโมเดลให้สูงเท่านี้ (studs) · nil = ใช้ขนาดตามที่ปั้นมา
	CustomModel = f({
		Folder = "TurretModels",
		Height = nil,
	}),

	-- ลำดับธาตุในหน้าเลือกธาตุ (ต้องตรงกับชื่อใน Elements)
	Order = f({ "Fire", "Water", "Earth", "Wind" }),

	-- ป้อมที่ยังไม่เลือกธาตุ (ผู้เล่นใหม่/ข้อมูลเก่า) ยิงแบบนี้จนกว่าจะเลือก · ไม่มีสกิล
	Unchosen = f({ Damage = 1, FireRate = 1, Fx = "Tracer", Color = Color3.fromRGB(255, 220, 90) }),

	-- สีบอลไฟตามเลเวลป้อม (ใช้แถวสุดท้ายที่ Level ≤ เลเวล · ต่ำกว่าแถวแรก = แถวแรก) · ใช้กับธาตุที่ UseFireColors = true
	FireColors = f({
		f({ Level = 10, Name = "ส้ม", Color = Color3.fromRGB(255, 140, 40) }),
		f({ Level = 20, Name = "แดง", Color = Color3.fromRGB(235, 50, 40) }),
		f({ Level = 30, Name = "ม่วง", Color = Color3.fromRGB(190, 70, 255) }),
		f({ Level = 40, Name = "น้ำเงิน", Color = Color3.fromRGB(60, 140, 255) }),
		f({ Level = 50, Name = "ขาว", Color = Color3.fromRGB(245, 245, 255) }),
	}),

	-- ===== ธาตุพื้นฐาน 4 ธาตุ =====
	-- ✏️ แก้ตัวเลขในแต่ละก้อนได้เลย · ห้ามเปลี่ยนคำใน Kind/Fx ถ้าไม่แก้โค้ดด้วย
	Elements = f({
		-- ================= 🔥 ไฟ =================
		Fire = f({
			Name = "ไฟ",
			Icon = "🔥",
			Description = "ลูกไฟระเบิดโดนหลายตัว · เป้าติดไฟ",
			Color = Color3.fromRGB(255, 120, 40),
			UseFireColors = true, -- สีบอลไฟเปลี่ยนตามเลเวล (FireColors)
			Damage = 1.4,
			FireRate = 0.7,
			-- Splash = รัศมีระเบิดรอบจุดโดน (มอนตัวอื่นในวงโดนดาเมจเท่านัดปกติ)
			Shot = f({ Fx = "Fireball", Splash = 6 }),
			-- เผาไหม้: DoT = D × DotPerSecond ต่อวิ นาน Seconds · ยิงซ้ำ = รีเซ็ตเวลา ไม่ซ้อน
			Passive = f({ Kind = "Burn", DotPerSecond = 0.1, Seconds = 3, Name = "เผาไหม้", Text = "เป้าติดไฟ 0.1D/วิ 3 วิ" }),
			Skill = f({
				Name = "ลูกไฟพัด",
				Description = "ยิงลูกไฟ 5 ลูกเป็นพัด ติดไฟแรง",
				Cooldown = 25,
				ScaleWithFireRate = true,
				Fx = "FireVolley",
				-- Volley: Count ลูก ห่างกัน Interval วิ · Spread = มุมพัด (ภาพ) · Damage/SplashDamage = ×D
				Pattern = f({ Kind = "Volley", Count = 5, Spread = 30, Interval = 0.15, Speed = 90, Damage = 2.0, Splash = 6, SplashDamage = 2.0 }),
				Status = f({ Kind = "Burn", DotPerSecond = 0.3, Seconds = 4 }),
			}),
		}),

		-- ================= 💧 น้ำ =================
		Water = f({
			Name = "น้ำ",
			Icon = "💧",
			Description = "ยิงต่อเนื่อง มอนช้าลง · ป้อมฟื้นเลือดเอง",
			Color = Color3.fromRGB(80, 170, 255),
			Damage = 0.8,
			FireRate = 1.3,
			-- MonsterSlow: มอนเดินช้าลง Amount (0.2 = 20%) นาน Seconds
			Shot = f({ Fx = "WaterBolt", MonsterSlow = f({ Amount = 0.2, Seconds = 1.5 }) }),
			Passive = f({ Kind = "Regen", HpPerSecond = 2, Name = "ชุ่มชื่น", Text = "ป้อมฟื้นเลือด 2/วิ (ไม่ฟื้นตอนช็อต)" }),
			Skill = f({
				Name = "คลื่นยักษ์",
				Description = "คลื่นวิ่งตามเลนชนมอนทุกตัว แล้วซัดบอส · ป้อมฟื้นเลือด 30",
				Cooldown = 25,
				ScaleWithFireRate = true,
				Fx = "Wave",
				-- LaneWave: วิ่งจากป้อมไปหาบอสด้วย Speed · Damage = ใส่มอนที่ผ่าน · EndDamage = ใส่บอสตอนถึง
				Pattern = f({ Kind = "LaneWave", Speed = 40, Damage = 3, EndDamage = 9 }),
				-- Knockback: มอนถอย Studs + ช้าลง Slow นาน SlowSeconds
				Status = f({ Kind = "Knockback", Studs = 12, Slow = 0.4, SlowSeconds = 3 }),
				SelfHeal = 30, -- ป้อมฟื้นเลือดทันทีตอนกด
			}),
		}),

		-- ================= 🪨 ดิน =================
		Earth = f({
			Name = "ดิน",
			Icon = "🪨",
			Description = "หินหนัก ยิงช้า กระแทกมอนถอย · ทนทุบ",
			Color = Color3.fromRGB(150, 110, 70),
			Damage = 2.0,
			FireRate = 0.5,
			Shot = f({ Fx = "Rock", Knockback = 4 }), -- Knockback = มอนถอยกี่ studs ต่อนัด
			Passive = f({ Kind = "SlamReduce", Amount = 0.3, Name = "ผิวหิน", Text = "ดาเมจจากบอสทุบ −30%" }),
			Skill = f({
				Name = "หินถล่ม",
				Description = "โยนหินยักษ์ เกิดวงแรงกระแทก · ป้อมได้เกราะหินกันทุบ 1 ครั้ง",
				Cooldown = 30,
				ScaleWithFireRate = true,
				Fx = "Boulder",
				-- TravelTime = เวลาบินคงที่ (แทน Speed) · Arc = ความสูงโค้ง (ภาพ)
				Pattern = f({ Kind = "Volley", Count = 1, TravelTime = 1.2, Arc = 20, Damage = 11, Splash = 16, SplashDamage = 4 }),
				Status = f({ Kind = "Knockback", Studs = 6 }),
				SelfShield = f({ Blocks = 1, Seconds = 12 }), -- กันการทุบได้ Blocks ครั้ง ภายใน Seconds วิ
			}),
		}),

		-- ================= 🌪️ ลม =================
		Wind = f({
			Name = "ลม",
			Icon = "🌪️",
			Description = "ใบมีดลมเร็วมาก ทะลุมอน · ช็อตสั้นลง",
			Color = Color3.fromRGB(170, 240, 210),
			Damage = 0.55,
			FireRate = 1.9,
			Shot = f({ Fx = "WindBlade", Pierce = 2 }), -- Pierce = โดนมอนตัวถัดไปในเลนเพิ่มกี่ตัว
			Passive = f({ Kind = "StunReduce", Amount = 0.4, Name = "ตัวเบา", Text = "เวลาช็อต −40%" }),
			Skill = f({
				Name = "ลมกรด 5 ดาบ",
				Description = "ชาร์จ 1 วิ แล้วยิงใบลม 5 ดาบ ทะลุทุกตัวในเลน",
				Cooldown = 24,
				ScaleWithFireRate = true,
				Fx = "GaleBlade",
				ChargeFx = "WindCharge", -- ภาพตอนชาร์จ
				-- Pierce = 99 → ทะลุมอนทุกตัวในเลนตัวเอง
				Pattern = f({ Kind = "Volley", Charge = 1.0, Count = 5, Spread = 0, Interval = 0.12, Speed = 250, Damage = 2.0, Pierce = 99 }),
			}),
		}),
	}),
})
