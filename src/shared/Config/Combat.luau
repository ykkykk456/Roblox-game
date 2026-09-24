-- ค่าการต่อสู้ของป้อม/มอน/บอส (เจ้าของค่า: Economy_Designer ผ่าน /roblox-economy)
-- ปรับความยาก/จังหวะเกม = แก้ไฟล์นี้ · ตัวเลขเงิน/ราคา/รางวัลอยู่ที่ Economy.luau
-- [Proposed] ทุกค่าเป็นค่าชั่วคราวสำหรับ prototype (เวลาสั้นเพื่อให้ทดสอบใน Studio ได้เร็ว)

return table.freeze({
	TickRate = 10, -- รอบคำนวณการยิงต่อวินาทีฝั่ง Server

	Turret = table.freeze({
		Slots = 12, -- จำนวนจุดวางป้อมรอบวง (ผู้เล่นเกินนี้จะยังไม่มีป้อม)
		RingRadius = 40, -- ระยะจากกลางแมพถึงป้อม (studs)
		Range = 60, -- ระยะยิง (studs) ต้องมากกว่า RingRadius เพื่อให้ถึงบอสกลางแมพ
		MaxLevel = 50,
		BaseDamage = 10,
		DamagePerLevel = 5,
		BaseFireRate = 1, -- นัดต่อวินาที
		FireRatePerLevel = 0.1,
	}),

	Monster = table.freeze({
		SpawnInterval = 2, -- วินาที
		MaxAlive = 15,
		Hp = 30,
		Speed = 8, -- studs ต่อวินาที
		SpawnRadius = 80, -- เกิดที่ขอบวงนี้แล้วเดินผ่านกลางแมพไปอีกฝั่ง
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
