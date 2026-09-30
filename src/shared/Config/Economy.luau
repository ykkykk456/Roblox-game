-- ตัวเลขเศรษฐกิจทั้งหมดของเกมอยู่ที่นี่ที่เดียว (เจ้าของค่า: Economy_Designer)
-- Server ใช้ค่าชุดนี้ทั้งตอนคำนวณและตอน validate คำขอจาก Client → ปรับ Balance = แก้ไฟล์นี้ไฟล์เดียว
-- ไฟล์นี้ Client อ่านได้ (ใช้แสดงราคาบน UI ได้) ห้ามใส่ข้อมูลลับ
--
-- อยากปรับ:
--   ราคาอัปป้อม → Turret · เงินจากมอน → MonsterReward / MonsterRewardMultiplier
--   รางวัลบอส (เหรียญ) → Boss · โบนัสเพื่อน → FriendBoost
--   ✏️ ของดรอปจากบอส / ราคาเปิดช่องอุปกรณ์ / เหรียญจากย่อย → src/shared/Config/Equipment.luau (ระบบกาชาถูกถอดแล้ว)
-- ใครใช้: Server = Services/Wallet, MonsterService, BossService, GearService, FriendBoostService ·
--   Data/PlayerData · Util/TurretMath · Client = UI (แสดงราคาเท่านั้น)
-- ⚠️ Client ห้ามตัดสินเรื่องเงินเอง · แก้ตัวเลขเงินควรทำผ่าน /roblox-economy

return table.freeze({
	-- ===== เงินผู้เล่น (หน่วย: เหรียญ) =====
	StartingCoins = 0, -- [Proposed] ค่าตั้งต้น รอ Economy_Designer กำหนด
	MaxCoins = 1_000_000_000, -- [Proposed] เพดานกันค่าล้น/เงินเฟ้อ

	-- [Proposed] ค่าชั่วคราวของ prototype ระบบป้อม
	-- ===== ราคาอัปป้อม =====
	Turret = table.freeze({
		UpgradeBaseCost = 25, -- ราคาอัปจาก Lv.1 → Lv.2
		-- ราคาเลเวลถัดไป = ราคาเดิม × ค่านี้ · เพิ่ม = เลเวลสูงแพงขึ้นเร็วมาก (ทวีคูณ)
		UpgradeCostGrowth = 1.5,
	}),

	-- ===== รางวัลมอน =====
	MonsterReward = 5, -- เงินต่อมอน 1 ตัว แบ่งให้ผู้ตีตามสัดส่วนดาเมจ (ขั้นต่ำ 1 ต่อคน)
	MonsterRewardMultiplier = table.freeze({ Small = 1, Medium = 3 }), -- [Proposed] ตัวกลาง HP 3 เท่า ได้เงิน 3 เท่า

	-- ===== รางวัลบอส (หน่วย: เหรียญ) =====
	Boss = table.freeze({
		-- แจกตอนบอสจากไป (ครบ Combat.Boss.Duration)
		BaseReward = 50, -- ทุกคนที่มีดาเมจ > 0 ได้เท่ากัน
		DamageRewardPool = 300, -- แบ่งตามสัดส่วนดาเมจ
	}),

	-- ===== โบนัสเพื่อน (สัดส่วน: 0.1 = 10%) =====
	-- เพดานรวมคุมไว้ที่ Max เพื่อไม่ให้ตัวคูณซ้อนกันพุ่งเกิน
	FriendBoost = table.freeze({
		PerFriend = 0.1, -- +10% ต่อเพื่อน 1 คนในเซิร์ฟเดียวกัน
		Max = 0.4, -- สูงสุด +40%
	}),
})
