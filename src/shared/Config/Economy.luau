-- ตัวเลขเศรษฐกิจทั้งหมดของเกมอยู่ที่นี่ที่เดียว (เจ้าของค่า: Economy_Designer)
-- Server ใช้ค่าชุดนี้ทั้งตอนคำนวณและตอน validate คำขอจาก Client → ปรับ Balance = แก้ไฟล์นี้ไฟล์เดียว
-- ไฟล์นี้ Client อ่านได้ (ใช้แสดงราคาบน UI ได้) ห้ามใส่ข้อมูลลับ

return table.freeze({
	StartingCoins = 0, -- [Proposed] ค่าตั้งต้น รอ Economy_Designer กำหนด
	MaxCoins = 1_000_000_000, -- [Proposed] เพดานกันค่าล้น/เงินเฟ้อ

	-- ตัวอย่างรายการสินค้า:
	-- Items = table.freeze({
	--     Sword = table.freeze({ Price = 100 }),
	-- }),
})
