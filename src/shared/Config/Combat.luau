-- ค่าการต่อสู้ของป้อม/มอน/บอส (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy)
-- ปรับความยาก/จังหวะเกม = แก้ไฟล์นี้ · ตัวเลขเงิน/ราคา/รางวัลอยู่ที่ Economy.luau
-- [Proposed] ทุกค่าเป็นค่าชั่วคราวสำหรับ prototype (เวลาสั้นเพื่อให้ทดสอบใน Studio ได้เร็ว)

return table.freeze({
	TickRate = 10, -- รอบคำนวณการยิงต่อวินาทีฝั่ง Server

	Turret = table.freeze({
		-- ตำแหน่ง/จำนวนป้อมมาจากฐาน (Config/Map: BaseCount, Base.TurretDistance)
		Range = 150, -- ระยะยิง (studs) ต้องมากกว่า Map.Base.TurretDistance เพื่อให้ถึงบอสกลางหลุม · ×2.5 ตามแมพ (2026-09-26) · ยังไม่ได้ออกแบบใหม่ (ป้อมอาจยิงมอนฐานข้างๆ ได้)
		MaxLevel = 50,
		BaseDamage = 10,
		DamagePerLevel = 5,
		BaseFireRate = 1, -- นัดต่อวินาที
		FireRatePerLevel = 0.1,
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
		Height = 14, -- ลอยเหนือกลางแมพ ผู้เล่นเดินลอดได้
	}),
})
