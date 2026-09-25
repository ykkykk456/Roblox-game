-- ค่าการต่อสู้ของป้อม/มอน/บอส (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy)
-- ปรับความยาก/จังหวะเกม = แก้ไฟล์นี้ · ตัวเลขเงิน/ราคา/รางวัลอยู่ที่ Economy.luau
-- [Proposed] ทุกค่าเป็นค่าชั่วคราวสำหรับ prototype (เวลาสั้นเพื่อให้ทดสอบใน Studio ได้เร็ว)

return table.freeze({
	TickRate = 10, -- รอบคำนวณการยิงต่อวินาทีฝั่ง Server

	Turret = table.freeze({
		-- ตำแหน่ง/จำนวนป้อมมาจากฐาน (Config/Map: BaseCount, Base.TurretDistance)
		Range = 60, -- ระยะยิง (studs) ต้องมากกว่า Map.Base.TurretDistance เพื่อให้ถึงบอสกลางหลุม · ยังไม่ได้ออกแบบใหม่ (ป้อมอาจยิงมอนฐานข้างๆ ได้)
		MaxLevel = 50,
		BaseDamage = 10,
		DamagePerLevel = 5,
		BaseFireRate = 1, -- นัดต่อวินาที
		FireRatePerLevel = 0.1,
	}),

	Monster = table.freeze({
		-- เกิดในสวนหลังบ้านของฐานที่มีเจ้าของ แล้วเดินสุ่มรอบฐาน (ผัง: Config/Map.MonsterWander)
		SpawnInterval = 2, -- วินาที (เกิดฐานละ 1 ตัวต่อรอบ)
		MaxAlivePerBase = 6,
		Lifetime = 90, -- วินาที · อยู่ครบแล้วหายไปเอง (ไม่มีรางวัล) เพื่อให้มอนใหม่เกิดแทน
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
