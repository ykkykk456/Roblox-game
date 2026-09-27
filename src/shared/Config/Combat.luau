-- ค่าการต่อสู้ของป้อม/มอน/บอส (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy)
-- ปรับความยาก/จังหวะเกม = แก้ไฟล์นี้ · ตัวเลขเงิน/ราคา/รางวัลอยู่ที่ Economy.luau
-- [Proposed] ทุกค่าเป็นค่าชั่วคราวสำหรับ prototype (เวลาสั้นเพื่อให้ทดสอบใน Studio ได้เร็ว)

return table.freeze({
	TickRate = 10, -- รอบคำนวณการยิงต่อวินาทีฝั่ง Server

	Turret = table.freeze({
		-- ตำแหน่ง/จำนวนป้อมมาจากฐาน (Config/Map: BaseCount, Base.TurretDistance)
		Range = 260, -- ระยะยิง (studs) · เพิ่มชั่วคราวจาก 150 ให้ถึงบอส Slambot ตัวสูง (ขอ 2026-09-27 "เพิ่มไปก่อนค่อยแก้ทีหลัง") · ยังไม่ได้ออกแบบใหม่ (ป้อมยิงมอนเลนข้างๆ ได้)
		MaxLevel = 50,
		BaseDamage = 10,
		DamagePerLevel = 5,
		BaseFireRate = 1, -- นัดต่อวินาที
		FireRatePerLevel = 0.1,
		-- เลือดป้อม: ลดเมื่อโดนบอสทุบ (Slam) · หมด = ช็อต หยุดยิง StunSeconds แล้วฟื้นเต็ม · บอสจบ = เต็มทันที (ยืนยัน 2026-09-26)
		MaxHp = 100,
		StunSeconds = 6,
	}),

	Monster = table.freeze({
		-- แบบ Tower Defense (ยืนยัน 2026-09-26): เกิดกลางแอ่ง เดินตามเลนไปหาป้อมของฐานที่มีเจ้าของ (ผัง: Config/Map.Lane)
		WaveSize = 15, -- มอนต่อ wave ต่อเลน
		SpawnGap = 0.8, -- วินาทีระหว่างมอนแต่ละตัวใน wave (ทยอยออกเป็นแถว)
		WaveDelay = 10, -- วินาทีพักหลังมอนทั้ง wave ตาย/ถึงปลายทางหมด ก่อนปล่อย wave ถัดไป
		TypeOrder = table.freeze({ "Small", "Medium" }),
		-- Weight = โอกาสเกิดเทียบกัน · Speed = studs ต่อวินาที · Size = เส้นผ่านศูนย์กลาง · เงินอยู่ที่ Economy.MonsterRewardMultiplier
		Types = table.freeze({
			Small = table.freeze({ Hp = 30, Speed = 8, Size = 3, Weight = 3, Color = Color3.fromRGB(205, 72, 72) }),
			Medium = table.freeze({ Hp = 90, Speed = 5, Size = 5, Weight = 1, Color = Color3.fromRGB(240, 138, 58) }),
		}),
	}),

	Boss = table.freeze({
		FirstDelay = 45, -- วินาทีหลังเซิร์ฟเริ่ม (บอสแรกมาเร็ว)
		Interval = 180, -- วินาทีหลังบอสตัวก่อนจบ
		Duration = 60, -- ตีไม่ตายในเวลานี้ = บอสหนี
		BaseHp = 300,
		HpPerPlayer = 400, -- HP เพิ่มตามจำนวนผู้เล่นในเซิร์ฟตอนบอสเกิด
		Height = 14, -- ความสูงของบอสลูกบอลสำรอง (ใช้เมื่อยังไม่มีโมเดล)

		-- โมเดลบอส: วางเองใน Studio ที่ ServerStorage > Bosses > <Model> (Rojo ไม่ยุ่งกับ ServerStorage)
		-- ไม่มีโมเดล → ใช้ลูกบอลสำรอง · บอสยืนกลางแอ่ง (ยืนยัน 2026-09-26)
		Model = "boss_slambot", -- ชื่อจริงของโมเดลที่ Import จาก boss_slambot.fbx (ชื่ออื่นที่คล้ายกัน เช่น Slambot ก็หาเจอ)
		-- เลข Animation ID หลัง Publish (ตัวเลขล้วน เช่น 1234567890) · 0 = ใช้ค่าจากโมเดลแทน
		-- ใส่ได้ 2 ที่ (ที่นี่ชนะถ้าไม่ใช่ 0): ที่นี่ หรือ AnimationId ของ ServerStorage > Bosses > boss_slambot > Animations > <ท่า> ใน Studio
		-- สร้างโฟลเดอร์ Animations ให้อัตโนมัติด้วย tools/studio/setup_slambot.lua (วางใน Command Bar)
		-- ทดสอบใน Studio: ท่าที่กด Save ใน Animation Editor (ชื่อมี Idle/Walk/Slam) ถูกใช้ก่อน ไม่ต้อง Publish · เกมจริงใช้เลขที่นี่
		Animations = table.freeze({
			Idle = 84868529983536, -- ท่ายืนเล่นวน · ตอนนี้ใช้ท่าเต้นจาก Motion Capture (Publish ใหม่ 2026-09-27 แทน 93277664050065)
			Walk = 0, -- เดินหนักๆ เล่นวนตอนเปิดตัว
			Slam = 0, -- ยกแขนทุบพื้น เล่นครั้งเดียว · ใส่ Marker ชื่อ "Hit" ตรงจังหวะมือกระแทกพื้นได้
		}),
		GroundOffset = 0, -- ปรับความสูงบอส (studs): บวก = ยกขึ้น · ลบ = กดลง · ใช้เมื่อยังจมพื้น/ลอยหลังวางอัตโนมัติ
		EntranceSeconds = 5, -- เปิดตัว: เดินจากขอบแอ่งเข้ามากลาง
		EntranceFrom = 90, -- ระยะจุดเริ่มเดินจากกลางแมพ (studs)
		SlamInterval = 10, -- ทุบทุกกี่วินาที (นับหลังเปิดตัว)
		SlamHitDelay = 1.2, -- วินาทีจากเริ่มท่าถึงจังหวะกระแทก (ใช้เมื่อท่าไม่มี Marker "Hit")
		SlamDamage = 40, -- ดาเมจต่อป้อมทุกตัวต่อการทุบ 1 ครั้ง
	}),
})
