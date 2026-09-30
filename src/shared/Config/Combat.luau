-- ค่าการต่อสู้ของป้อม/มอน/บอส (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy)
-- ปรับความยาก/จังหวะเกม = แก้ไฟล์นี้ · ตัวเลขเงิน/ราคา/รางวัลอยู่ที่ Economy.luau
-- [Proposed] ทุกค่าเป็นค่าชั่วคราวสำหรับ prototype (เวลาสั้นเพื่อให้ทดสอบใน Studio ได้เร็ว)
--
-- อยากปรับ:
--   ป้อมแรง/ยิงเร็วขึ้น → Turret (BaseDamage, DamagePerLevel, BaseFireRate, FireRatePerLevel)
--   มอนเยอะ/ถี่/อึดขึ้น → Monster (WaveSize, SpawnGap, WaveDelay, Types)
--   บอสมาบ่อย/อยู่นาน/ทุบแรง → Boss (FirstDelay, Interval, Duration, SlamInterval, SlamDamage)
-- ใครใช้: Server = Services/TurretService, MonsterService, BossService, MapService · Util/TurretMath
--   Client = UI/CombatUI (อ่านไปแสดงตัวเลขเท่านั้น ไม่ได้ตัดสินดาเมจ)
-- ⚠️ ไฟล์ shared = ผู้เล่นอ่านได้ ห้ามใส่ความลับ · ดาเมจจริงคำนวณที่ Server เท่านั้น

return table.freeze({
	-- รอบคำนวณการยิงต่อวินาทีฝั่ง Server · มากขึ้น = ยิงแม่นจังหวะขึ้นแต่เซิร์ฟทำงานหนักขึ้น
	TickRate = 10,

	-- ===== ป้อม =====

	Turret = table.freeze({
		-- ตำแหน่ง/จำนวนป้อมมาจากฐาน (Config/Map: BaseCount, Base.TurretDistance)
		Range = 260, -- ระยะยิง (studs) · เพิ่มชั่วคราวจาก 150 ให้ถึงบอส Slambot ตัวสูง (ขอ 2026-09-27 "เพิ่มไปก่อนค่อยแก้ทีหลัง") · ยังไม่ได้ออกแบบใหม่ · มอน: ยิงเฉพาะเลนของป้อมตัวเอง (แก้ 2026-09-30) · บอส: ยิงได้ในระยะนี้
		-- เลเวลสูงสุดของป้อม (อัปเกินนี้ไม่ได้)
		MaxLevel = 50,
		-- ดาเมจต่อนัดตอน Lv.1 · เพิ่ม = ป้อมแรงขึ้นตั้งแต่ต้นเกม
		BaseDamage = 10,
		-- ดาเมจที่เพิ่มต่อ 1 เลเวล (ดาเมจ = BaseDamage + DamagePerLevel × (เลเวล−1) · ดู Util/TurretMath)
		DamagePerLevel = 5,
		BaseFireRate = 1, -- นัดต่อวินาที
		-- นัดต่อวินาทีที่เพิ่มต่อ 1 เลเวล · เพิ่ม = เลเวลสูงยิงรัวขึ้น
		FireRatePerLevel = 0.1,
		-- เลือดป้อม: ลดเมื่อโดนบอสทุบ (Slam) · หมด = ช็อต หยุดยิง StunSeconds แล้วฟื้นเต็ม · บอสจบ = เต็มทันที (ยืนยัน 2026-09-26)
		-- เลือดเต็มของป้อม (หน่วยเดียวกับ SlamDamage) · เพิ่ม = ทนทุบได้หลายครั้งขึ้น
		MaxHp = 100,
		-- วินาทีที่ป้อมหยุดยิงเมื่อเลือดหมด · เพิ่ม = โดนลงโทษนานขึ้น
		StunSeconds = 6,
		-- ความเร็วกระสุน (แก้บั๊ก 2026-09-30: ดาเมจเข้าก่อนกระสุนถึงเป้า) · ใช้ทั้ง Server (เวลาทำดาเมจ) และ Client (ภาพกระสุนวิ่ง)
		-- สูตรเดียวกันที่ Util/TurretMath.travelTime: เวลาเดินทาง = ระยะ ÷ ความเร็ว แล้วบีบให้อยู่ในช่วง MinTravel..MaxTravel
		-- ดาเมจ/effect ของกระสุนวิ่งเข้าตอน "ถึงเป้า" · ชนิดใน Instant = โดนทันทีตอนยิง (เส้น/ลำแสง/สายฟ้า)
		-- ⚠️ เพิ่ม Fx ชื่อใหม่: เป็นเส้น/ลำแสง → ใส่ใน Instant · เป็นลูกกระสุน → ใส่ความเร็วใน Speeds (ไม่ใส่ = ใช้ Speed)
		Projectile = table.freeze({
			Speed = 150, -- ความเร็วพื้นฐาน (studs/วินาที) ของ Fx ที่ไม่มีใน Speeds และไม่ใช่ Instant
			MinTravel = 0.04, -- วินาทีเดินทางน้อยสุด (เป้าใกล้มาก)
			MaxTravel = 0.6, -- วินาทีเดินทางมากสุด (เป้าไกล กระสุนจะวิ่งเร็วขึ้นให้ถึงภายในเวลานี้)
			-- ความเร็วต่อชนิด Fx (studs/วินาที) · ธาตุป้อม (design/element-skills.md · Config/Elements.luau) [Proposed]
			-- ⚠️ ระยะไกลจะโดนบีบด้วย MaxTravel (0.6 วิ) → กระสุนช้าวิ่งเร็วขึ้นเมื่อเป้าไกล (คงพฤติกรรมเดิม)
			Speeds = table.freeze({
				-- ยิงปกติ
				Fireball = 90, -- 🔥 ไฟ
				WaterBolt = 140, -- 💧 น้ำ
				Rock = 70, -- 🪨 ดิน (โค้งลง)
				WindBlade = 250, -- 🌪️ ลม
				-- กระสุนสกิล: Server ส่งเวลาเดินทางจริงมาใน TurretFx.Travel เสมอ (ElementMath.skillTravel) · ค่านี้ใช้สำรองเท่านั้น
				FireVolley = 90, -- ลูกไฟพัด
				Boulder = 60, -- หินถล่ม
				GaleBlade = 250, -- ลมกรด 5 ดาบ
				Wave = 40, -- คลื่นยักษ์
			}),
			-- เวลาเดินทางน้อยสุดเฉพาะชนิด (แทน MinTravel) · กระสุนโค้งต้องมีเวลาให้เห็นโค้ง
			MinTravelBy = table.freeze({
				Rock = 0.25,
			}),
			-- ชนิดที่โดนทันที/ไม่ใช่กระสุนวิ่ง (เส้น ลำแสง ภาพชาร์จ ฯลฯ) · ⚠️ Fx ใหม่แบบนี้ต้องใส่ที่นี่
			Instant = table.freeze({
				Tracer = true, -- ป้อมยังไม่เลือกธาตุ
				WindCharge = true, -- ภาพชาร์จของลมกรด 5 ดาบ (อยู่ที่ปากกระบอก)
			}),
		}),
	}),

	-- ===== มอนสเตอร์ =====
	Monster = table.freeze({
		-- แบบ Tower Defense (ยืนยัน 2026-09-26): เกิดกลางแอ่ง เดินตามเลนไปหาป้อมของฐานที่มีเจ้าของ (ผัง: Config/Map.Lane)
		WaveSize = 15, -- มอนต่อ wave ต่อเลน
		AllLanesForTest = true, -- เทส (2026-09-27): มอนออกทุกเลนแม้บ้านไม่มีเจ้าของ · เกมจริงตั้ง false = ออกเฉพาะเลนที่มีผู้เล่น
		SpawnGap = 0.8, -- วินาทีระหว่างมอนแต่ละตัวใน wave (ทยอยออกเป็นแถว)
		WaveDelay = 10, -- วินาทีพักหลังมอนทั้ง wave ตาย/ถึงปลายทางหมด ก่อนปล่อย wave ถัดไป
		-- ลำดับชนิดมอน (ต้องตรงกับชื่อใน Types ด้านล่าง) · เพิ่มชนิดใหม่ = เพิ่มทั้งที่นี่และใน Types
		TypeOrder = table.freeze({ "Small", "Medium" }),
		-- Weight = โอกาสเกิดเทียบกัน · Speed = studs ต่อวินาที · Size = เส้นผ่านศูนย์กลาง · เงินอยู่ที่ Economy.MonsterRewardMultiplier
		Types = table.freeze({
			-- Hp = เลือด (เพิ่ม = ตายยากขึ้น) · Color = สีตัวมอน
			Small = table.freeze({ Hp = 30, Speed = 8, Size = 3, Weight = 3, Color = Color3.fromRGB(205, 72, 72) }),
			Medium = table.freeze({ Hp = 90, Speed = 5, Size = 5, Weight = 1, Color = Color3.fromRGB(240, 138, 58) }),
		}),
	}),

	-- ===== บอส =====
	Boss = table.freeze({
		FirstDelay = 45, -- วินาทีหลังเซิร์ฟเริ่ม (บอสแรกมาเร็ว)
		Interval = 180, -- วินาทีหลังบอสตัวก่อนจบ
		Duration = 300, -- บอสอยู่ 5 นาที · ไม่มีเลือด ครบเวลาแล้วจากไป แจกเงิน + ตั๋วตามดาเมจ (ยืนยัน 2026-09-27)
		Height = 14, -- ความสูงของบอสลูกบอลสำรอง (ใช้เมื่อยังไม่มีโมเดล)

		-- ----- โมเดล + ลำดับบอส -----
		-- โมเดลบอส: วางเองใน Studio ที่ ServerStorage > Bosses (หรือ Workspace ก็ได้ เกมย้ายให้) · Rojo ไม่ยุ่งกับ ServerStorage
		-- บอสสลับกันตามลำดับนี้ วนไปเรื่อยๆ (ยืนยัน 2026-09-27: กระต่ายก่อน → โรบอท) · ทุกตัวเกิดกลางแอ่ง
		-- Animate = false → ยืนเฉย ไม่เล่นท่า · Animate = true → ใช้ท่าใน Animations ของแถวนั้น (ไม่ใส่ = ใช้ Animations ด้านล่าง = ท่าโรบอท)
		-- หาโมเดลตัวไหนไม่เจอ → ข้ามไปตัวถัดไป · ไม่เจอเลย → ลูกบอลสำรอง
		Rotation = table.freeze({
			-- กระต่าย: ท่าของตัวเอง (Motion Capture 2026-09-27) · Walk/Slam = 0 ยังไม่มี
			table.freeze({
				Model = "Boss_rabbit",
				Animate = true,
				Animations = table.freeze({ Idle = 133467149182708, Walk = 0, Slam = 0 }), -- Idle เปลี่ยน 2026-09-29 (เดิม 99370436873239)
				-- เท้าติดพื้นตลอดท่า: ท่า Motion Capture ที่งอเข่าแต่สะโพกไม่ลด → เกมเลื่อนทั้งตัวลงให้เท้าแตะพื้น (BossService.plantFeet)
				PlantFeet = true,
			}),
			table.freeze({ Model = "boss_slambot", Animate = true }), -- โรบอท Slambot (ท่าเต้น) · ส่วนนี้ล็อกไว้
		}),
		-- ท่าของบอสที่ Animate = true (ตอนนี้ = โรบอท) · เลข Animation ID หลัง Publish (ตัวเลขล้วน) · 0 = ใช้ค่าจากโมเดลแทน
		-- ใส่ได้ 2 ที่ (ที่นี่ชนะถ้าไม่ใช่ 0): ที่นี่ หรือ AnimationId ของ ServerStorage > Bosses > boss_slambot > Animations > <ท่า> ใน Studio
		-- สร้างโฟลเดอร์ Animations ให้อัตโนมัติด้วย tools/studio/setup_slambot.lua (วางใน Command Bar)
		-- ทดสอบใน Studio: ท่าที่กด Save ใน Animation Editor (ชื่อมี Idle/Walk/Slam) ถูกใช้ก่อน ไม่ต้อง Publish · เกมจริงใช้เลขที่นี่
		Animations = table.freeze({
			Idle = 84868529983536, -- ท่ายืนเล่นวน · ตอนนี้ใช้ท่าเต้นจาก Motion Capture (Publish ใหม่ 2026-09-27 แทน 93277664050065)
			Walk = 0, -- เดินหนักๆ เล่นวนตอนเปิดตัว
			Slam = 0, -- ยกแขนทุบพื้น เล่นครั้งเดียว · ใส่ Marker ชื่อ "Hit" ตรงจังหวะมือกระแทกพื้นได้
		}),
		-- ----- การวางตัว + ท่าทุบ (ส่วนของ Slambot ล็อกไว้ ดู docs/boss-slambot-known-good.md ก่อนแก้) -----
		RepairJoints = true, -- สร้างข้อต่อให้ชิ้นที่ไม่ได้ต่อกับตัวราก (ตามโครงของท่า) · false = แค่เชื่อมชิ้นให้ติดกัน (ลองเมื่อบอสล้ม/ท่าบิด)
		GroundOffset = 0, -- ปรับความสูงบอส (studs): บวก = ยกขึ้น · ลบ = กดลง · ใช้เมื่อยังจมพื้น/ลอยหลังวางอัตโนมัติ
		-- เปิดตัว: เดินจากขอบแอ่งเข้ามากลาง (วินาที) · เพิ่ม = เดินช้าลง
		EntranceSeconds = 5,
		-- ระยะจุดเริ่มเดินจากกลางแมพ (studs)
		EntranceFrom = 90,
		-- ทุบทุกกี่วินาที (นับหลังเปิดตัว) · ลด = ทุบถี่ขึ้น เกมยากขึ้น
		SlamInterval = 10,
		SlamHitDelay = 1.2, -- วินาทีจากเริ่มท่าถึงจังหวะกระแทก (ใช้เมื่อท่าไม่มี Marker "Hit")
		-- ดาเมจต่อป้อมทุกตัวต่อการทุบ 1 ครั้ง (เทียบกับ Turret.MaxHp: 40 จาก 100 = ทุบ 3 ครั้งป้อมช็อต)
		SlamDamage = 40,
	}),
})
