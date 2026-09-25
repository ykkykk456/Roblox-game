-- ผังแมพหลุมอุกกาบาต (เจ้าของ: World_Builder) · รายละเอียด design/crater-map.md
-- หน่วย studs · กลางแมพ = (0, 0) · MapService สร้างแมพจากค่าชุดนี้ตอน Server เริ่ม
-- ของในฐานใช้พิกัดท้องถิ่น (ดู Util/MapMath): u = ระยะจากกลางแมพ · v = ระยะไปทางขวาเมื่อยืนหันหลังให้หลุม
-- [Proposed] ค่าชุดแรกของ prototype

return table.freeze({
	GroundY = 1, -- ผิวบนของพื้นหญ้า
	FloorSize = 362,
	Segments = 48, -- จำนวนชิ้นที่ใช้ต่อวงกลมหนึ่งวง (มากขึ้น = กลมขึ้นแต่ Part มากขึ้น)

	Pit = table.freeze({
		Radius = 38, -- หลุมกลางแมพ = จุดบอสเกิดอย่างเดียว
		Depth = 10,
		RimWidth = 4, -- ขอบหินรอบปากหลุม
	}),

	-- ทุ่งเก็บของร่วม ล้อมรอบหลุมบอส (แย่งกันเก็บ)
	LootRing = table.freeze({ Inner = 42, Outer = 54 }),

	MaxBases = 8, -- จุดฐานรอบหลุม ทุก 45° (ฐาน 1 อยู่ทิศเหนือ −Z)
	BaseCount = 1, -- prototype: สร้างฐานเดียวก่อนเพื่อดูระบบ แล้วค่อยเพิ่มถึง MaxBases

	Base = table.freeze({
		Distance = 80, -- ระยะจากกลางแมพถึงกลางลานฐาน
		Size = 44,
		TurretDistance = 56, -- ป้อมเริ่มต้นอยู่หน้าฐาน ระหว่างทุ่งเก็บของกับลานฐาน
	}),

	-- สวนหลังบ้าน: มอนเล็ก/กลางของฐานนั้นเกิดในพื้นที่รูปพัดนี้
	Yard = table.freeze({ Inner = 104, Outer = 150, HalfAngle = math.rad(18) }),

	-- ทางมอน: จากปากสวน (Yard.Inner) เดินเลียบข้างลานฐานเข้าหาหลุม แล้วหายไปที่ End
	MonsterLane = table.freeze({ Side = 12, End = 58 }),

	-- สีประจำฐาน 1–8
	SlotColors = table.freeze({
		Color3.fromRGB(224, 86, 74),
		Color3.fromRGB(63, 143, 217),
		Color3.fromRGB(77, 184, 96),
		Color3.fromRGB(242, 194, 58),
		Color3.fromRGB(154, 107, 216),
		Color3.fromRGB(242, 140, 58),
		Color3.fromRGB(232, 111, 168),
		Color3.fromRGB(52, 181, 176),
	}),
})
