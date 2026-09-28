-- คลาสป้อมเริ่มต้น + สายธาตุ (แยกจากสกิลกาชาใน Config/Skills.luau · ใช้ซ้อนกันได้)
-- เจ้าของรายชื่อ/กฎ: Systems_Designer · เจ้าของตัวเลข: Economy_Designer (ผ่าน /roblox-economy)
-- Client อ่านได้: ใช้แสดงชื่อ/คำอธิบาย/สี ในหน้าเลือกคลาส · Server ใช้คำนวณจริง (ห้ามมีความลับ)
-- สเปกเต็ม: design/turret-classes.md
-- [Proposed] ตัวเลขทุกตัวเป็นค่าชั่วคราว รอผู้ใช้ส่งเอกสารระบบธาตุ (ผู้ใช้แจ้ง 2026-09-28 ว่ามีเขียนไว้แล้ว)
--
-- ความหมายค่า (ตัวคูณเทียบกับป้อมพื้นฐานใน Config/Combat.Turret):
--   Damage   = ตัวคูณดาเมจต่อนัด       FireRate = ตัวคูณอัตรายิง
--   Fx       = ชนิดเอฟเฟกต์ที่ Client วาด (ดู TurretFx ใน Remotes.luau)
--   Color    = สีหลักของป้อม/กระสุน
--   Effect   = ความสามารถพิเศษของสายธาตุ (ใส่เฉพาะที่ใช้ · ดูรายละเอียดในแต่ละสาย)
--   Name/Description = ข้อความที่ผู้เล่นเห็นในหน้าเลือกคลาส (แก้ได้อิสระ)
--   ตัวอย่าง: Damage = 1.2 → แรงกว่าป้อมพื้นฐาน 20% · FireRate = 0.5 → ยิงช้าลงครึ่งหนึ่ง
--
-- อยากปรับ: ความแรงคลาส → Classes.<คลาส> · ความแรงสาย/ความสามารถ → Branches.<สาย>
--   เลเวลที่เลือกสายได้ → BranchLevel · สีบอลไฟตามเลเวล → FireColors
--   ⚠️ เปลี่ยน Kind ใน Effect หรือ Fx เป็นชื่อใหม่ ต้องแก้โค้ด Server/Client ด้วย (แก้แค่ตัวเลขได้เลย)
-- ใครใช้: Util/ClassMath · Server = Network/TurretClassHandler (ผ่าน ClassMath: TurretService, TurretClassService, TurretLook)
--   Client = UI/ClassUI (แสดงผลเท่านั้น)
--
-- 📖 อ่านตามลำดับนี้ (ค่าในไฟล์นี้ถูก "ค้นหา" ยังไง):
--   1) Server รู้ว่าผู้เล่นเป็นคลาสอะไร จาก Attribute TurretClass เช่น "Mage"
--   2) เปิดตาราง Classes.Mage → ได้ Name/Color/Damage/FireRate/Fx และรายชื่อสาย Branches = { "Lightning", "Alchemist" }
--   3) ถ้ามีสายแล้ว (TurretBranch เช่น "Lightning") → เปิด Branches.Lightning → ได้ค่าของสาย + Effect
--   4) Util/ClassMath.stats(classId, branchId, level) เลือกชั้นที่ใช้: ยังไม่มีคลาส → Unchosen · มีแต่คลาส → ค่าคลาส
--      · มีสาย → ค่าของสาย "แทน" ค่าคลาส (Damage/FireRate/Fx/Color + Effect)
--      สายไฟ (Effect.Kind = "FireColor") → ClassMath.fireColor(level) เลือกสีจาก FireColors
--   5) Server/TurretService ใช้สถิตินั้นยิงจริง แล้วส่ง Fx + Color ไปให้ Client วาด (Controllers/TurretController)
--   6) UI/ClassUI อ่านไฟล์นี้แค่เพื่อแสดงชื่อ/คำอธิบาย/สี/แถบตัวคูณในการ์ด
--
-- 📖 วิธีเพิ่มคลาส/สายใหม่ (ทีละขั้น):
--   ก) แก้แค่ Config (ไฟล์นี้) ก็พอ เมื่อ: ใช้ Fx ที่มีอยู่แล้ว และใช้ Effect.Kind ที่มีอยู่แล้ว (หรือไม่มี Effect)
--      1. เพิ่มคลาส: ใส่ก้อนใหม่ใน Classes (ชื่อคีย์ภาษาอังกฤษ เช่น Healer) + ใส่ชื่อนั้นใน ClassOrder
--      2. เพิ่มสาย: ใส่ก้อนใหม่ใน Branches (Class = คลาสเจ้าของ) + ใส่ชื่อสายใน Classes.<คลาส>.Branches
--   ข) ต้องแก้โค้ดด้วย เมื่อ:
--      • อยากให้ป้อมหน้าตาใหม่ → server/Services/TurretLook.luau (เพิ่มฟังก์ชัน buildXxx และเงื่อนไข branchId ==)
--        ถ้าไม่แก้ คลาสใหม่จะไม่มีรูปทรงของตัวเอง [Inferred]
--      • ตั้ง Fx เป็นชื่อใหม่ → client/Controllers/TurretController.luau (เขียน drawXxx + ใส่ใน DRAWERS)
--        ถ้าไม่แก้ Client จะวาดเป็น Tracer ธรรมดา
--      • ตั้ง Effect.Kind เป็นชื่อใหม่ → server/Services/TurretService.luau (จุดที่เช็ก effect.Kind ==)
--        + server/Services/TurretClassService.luau (ตัวทำงานของความสามารถ) · ถ้าไม่แก้ ความสามารถจะไม่ทำงาน
--   ⚠️ ชื่อคีย์ (Mage, Lightning, ...) ถูกบันทึกใน DataStore ของผู้เล่น → อย่าเปลี่ยนชื่อคีย์ที่มีอยู่แล้ว
--      (เปลี่ยนได้แค่ Name ที่ผู้เล่นเห็น) ไม่งั้นผู้เล่นเก่าจะหลุดคลาส [Inferred]
--
-- 💡 table.freeze(ตาราง) = ล็อกตารางไม่ให้โค้ดไหนแก้ค่าระหว่างเกม (แก้ = error) → ค่าคงที่ปลอดภัย
--    Color3.fromRGB(แดง, เขียว, น้ำเงิน) = สี แต่ละช่อง 0–255

return table.freeze({
	BranchLevel = 10, -- เลเวลป้อม (TurretLevel) ที่ปลดล็อกการเลือกสายธาตุ [Proposed]
	-- ลำดับคลาสที่แสดงในหน้าเลือกคลาส (ต้องตรงกับชื่อใน Classes)
	ClassOrder = table.freeze({ "Mage", "Archer", "Assassin", "Cannon" }),

	-- ป้อมที่ยังไม่เลือกคลาส (ผู้เล่นใหม่/ข้อมูลเก่า) ยิงแบบนี้จนกว่าจะเลือก
	Unchosen = table.freeze({ Damage = 1, FireRate = 1, Fx = "Tracer", Color = Color3.fromRGB(255, 220, 90) }),

	-- ===== คลาสป้อม (เลือกได้ 1 คลาส) =====
	-- Branches = สายธาตุที่คลาสนี้เลือกต่อได้ (ชื่อต้องตรงกับใน Branches ด้านล่าง)
	-- ✏️ แก้ตรงนี้ถ้าอยากปรับความแรง/สี/ข้อความของคลาส (ตัวเลขแก้ได้เลย · ชื่อ Fx ต้องมีใน TurretController.DRAWERS)
	-- ⚠️ เปลี่ยนตัวเลข Balance ควรผ่าน /roblox-economy
	Classes = table.freeze({
		Mage = table.freeze({
			Name = "นักเวท",
			Description = "ป้อมคริสตัล ยิงลูกเวทสมดุล",
			Color = Color3.fromRGB(120, 90, 230),
			Damage = 1.2,
			FireRate = 0.9,
			Fx = "Bolt",
			Branches = table.freeze({ "Lightning", "Alchemist" }),
		}),
		Archer = table.freeze({
			Name = "นักธนู",
			Description = "ป้อมหน้าไม้ ยิงเร็ว ดาเมจเบา",
			Color = Color3.fromRGB(70, 170, 90),
			Damage = 0.7,
			FireRate = 1.6,
			Fx = "Arrow",
			Branches = table.freeze({ "Wind", "Gatling" }),
		}),
		Assassin = table.freeze({
			Name = "นักฆ่า",
			Description = "ป้อมเงา ปามีดสั้น ดาเมจแรงต่อนัด",
			Color = Color3.fromRGB(60, 60, 75),
			Damage = 1.4,
			FireRate = 0.8,
			Fx = "Dagger",
			Branches = table.freeze({ "Poison", "Dark" }),
		}),
		Cannon = table.freeze({
			Name = "ปืนใหญ่",
			Description = "ป้อมปืนใหญ่ (อิงนักดาบ) ยิงช้ามาก แต่แรงที่สุด",
			Color = Color3.fromRGB(150, 95, 55),
			Damage = 3.5,
			FireRate = 0.3,
			Fx = "Shell",
			Branches = table.freeze({ "Fire" }), -- มีสายเดียว · การเติบโต = สีบอลไฟเปลี่ยนตามเลเวล (FireColors)
		}),
	}),

	-- ===== สายธาตุ (เลือกได้เมื่อป้อมถึง BranchLevel) =====
	-- Class = คลาสที่เป็นเจ้าของสายนี้ · Damage/FireRate = ตัวคูณทับของคลาส
	-- "ทับ" = ใช้ค่าของสายแทนค่าคลาส (ไม่คูณกัน) เช่น นักเวทที่เลือกสายฟ้า → Damage = 1.3 ไม่ใช่ 1.2 × 1.3
	--   (ดู ClassMath.stats: มีสาย → คืนค่า Damage/FireRate/Fx ของสาย) [Verified: อ่านโค้ด ClassMath]
	-- ✏️ แก้ตรงนี้ถ้าอยากปรับตัวเลขใน Effect (เวลา/รัศมี/ตัวคูณ) · ห้ามเปลี่ยนคำใน Kind ถ้าไม่แก้โค้ด Server ด้วย
	Branches = table.freeze({
		-- นักเวท
		Lightning = table.freeze({
			Class = "Mage",
			Name = "ธาตุสายฟ้า",
			Description = "สายฟ้าช็อต ติดดาเมจต่อเนื่อง",
			Color = Color3.fromRGB(120, 200, 255),
			Damage = 1.3,
			FireRate = 1,
			Fx = "Lightning",
			-- ดาเมจต่อเนื่อง: ต่อวินาที = ดาเมจต่อนัด × DotPerSecond นาน DotSeconds (ยิงซ้ำ = รีเซ็ตเวลา ไม่ซ้อน)
			Effect = table.freeze({ Kind = "Dot", DotPerSecond = 0.4, DotSeconds = 3 }),
		}),
		Alchemist = table.freeze({
			Class = "Mage",
			Name = "นักแปรธาตุ",
			Description = "ลำแสงรุ้งรวมพลังทุกธาตุ แรงพิเศษใส่บอส",
			Color = Color3.fromRGB(255, 120, 200),
			Damage = 1.2,
			FireRate = 1,
			Fx = "Beam",
			Effect = table.freeze({ Kind = "BossBonus", BossDamage = 1.8 }), -- ตัวคูณเพิ่มเฉพาะตอนยิงบอส
		}),
		-- นักธนู
		Wind = table.freeze({
			Class = "Archer",
			Name = "ธาตุลม",
			Description = "ชาร์จพลังแล้วยิงรัว 5 ดอกติด",
			Color = Color3.fromRGB(170, 240, 210),
			Damage = 1.1,
			FireRate = 1, -- ไม่ใช้ยิงปกติ: ยิงเป็นชุดตาม Effect แทน
			Fx = "Wind",
			-- ชาร์จ ChargeSeconds → ยิง BurstCount ดอก ห่างกัน BurstGap วินาที → ชาร์จใหม่
			Effect = table.freeze({ Kind = "ChargeBurst", ChargeSeconds = 2.5, BurstCount = 5, BurstGap = 0.12 }),
		}),
		Gatling = table.freeze({
			Class = "Archer",
			Name = "ปืนกล Gatling",
			Description = "ป้อมเปลี่ยนร่างเป็นปืนกลหมุน ยิงรัวไม่หยุด",
			Color = Color3.fromRGB(200, 200, 210),
			Damage = 0.45,
			FireRate = 5,
			Fx = "Gatling",
		}),
		-- นักฆ่า
		Poison = table.freeze({
			Class = "Assassin",
			Name = "ธาตุพิษ",
			Description = "โยนพิษใส่บอส ลดเกราะ ทุกป้อมตีบอสแรงขึ้น",
			Color = Color3.fromRGB(140, 230, 60),
			Damage = 1.2,
			FireRate = 0.8,
			Fx = "Poison",
			-- ลดเกราะบอส: ดาเมจที่บอสได้รับจาก "ทุกผู้เล่น" × (1 + ArmorBreak) นาน ArmorSeconds (หลายคนโยน = ไม่ซ้อน ใช้ค่าสูงสุด)
			Effect = table.freeze({ Kind = "ArmorBreak", ArmorBreak = 0.25, ArmorSeconds = 5 }),
		}),
		Dark = table.freeze({
			Class = "Assassin",
			Name = "ธาตุมืด",
			Description = "ยิงบอลมืด เกิดหลุมดำดูดกลืน ดาเมจต่อเนื่อง",
			Color = Color3.fromRGB(130, 50, 200),
			Damage = 1,
			FireRate = 0.5,
			Fx = "BlackHole",
			-- หลุมดำที่จุดเป้า: ดาเมจต่อวินาที = ดาเมจต่อนัด × DotPerSecond ใส่ทุกเป้าในรัศมี Radius นาน Seconds (ต่อป้อมมีได้ 1 หลุม)
			Effect = table.freeze({ Kind = "BlackHole", Radius = 14, Seconds = 4, DotPerSecond = 0.8 }),
		}),
		-- ปืนใหญ่
		Fire = table.freeze({
			Class = "Cannon",
			Name = "ธาตุไฟ",
			Description = "บอลเพลิงแรงที่สุด ยิงช้ามาก · สีไฟเปลี่ยนตามเลเวล",
			Color = Color3.fromRGB(255, 120, 40),
			Damage = 5,
			FireRate = 0.25,
			Fx = "Fireball",
			Effect = table.freeze({ Kind = "FireColor" }),
		}),
	}),

	-- สีบอลไฟของสายไฟตามเลเวลป้อม (ใช้แถวสุดท้ายที่ Level ≤ เลเวลป้อม) [Proposed]
	-- ตัวอย่าง: ป้อม Lv.27 → แถว Level 20 (แดง) เพราะเป็นแถวสุดท้ายที่ ≤ 27
	-- ✏️ แก้ตรงนี้ถ้าอยากเพิ่มขั้นสี: เพิ่มแถวใหม่ เรียง Level จากน้อยไปมาก (UI แบ่งช่องตามจำนวนแถวเอง)
	FireColors = table.freeze({
		table.freeze({ Level = 10, Name = "ส้ม", Color = Color3.fromRGB(255, 140, 40) }),
		table.freeze({ Level = 20, Name = "แดง", Color = Color3.fromRGB(235, 50, 40) }),
		table.freeze({ Level = 30, Name = "ม่วง", Color = Color3.fromRGB(190, 70, 255) }),
		table.freeze({ Level = 40, Name = "น้ำเงิน", Color = Color3.fromRGB(60, 140, 255) }),
		table.freeze({ Level = 50, Name = "ขาว", Color = Color3.fromRGB(245, 245, 255) }),
	}),
})
