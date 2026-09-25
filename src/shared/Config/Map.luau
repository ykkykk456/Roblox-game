-- ผังแมพหลุมอุกกาบาต (เจ้าของ: World_Builder) · รายละเอียด design/crater-map.md
-- หน่วย studs · กลางแมพ = (0, 0) · MapService สร้างแมพจากค่าชุดนี้ตอน Server เริ่ม
-- ของในฐานใช้พิกัดท้องถิ่น (ดู Util/MapMath): u = ระยะจากกลางแมพ · v = ระยะไปทางขวาเมื่อยืนหันหลังให้หลุม
-- [Proposed] ค่าชุดแรกของ prototype

return table.freeze({
	GroundY = 1, -- ผิวบนของพื้น
	Radius = 181, -- แมพวงกลม (ยืนยัน 2026-09-25) · ขอบนอกสุดของพื้น
	FloorSize = 362, -- เส้นผ่านศูนย์กลาง (ใช้เฉพาะพื้นสำรองแบบสี่เหลี่ยมเมื่อสร้างวงกลมไม่สำเร็จ)
	EdgeHeight = 3, -- กำแพงเตี้ยรอบขอบแมพ

	-- สไตล์บล็อก (ยืนยัน 2026-09-25): พื้นและบ้านใช้ texture ลายบล็อกสีส้ม
	-- TextureAssetId = 0 → ยังไม่อัปโหลดภาพ ใช้สีเรียบแทน · ภาพต้นฉบับ assets/textures/block_tile.png
	Style = table.freeze({
		TextureAssetId = 0,
		StudsPerTile = 12, -- 1 แผ่นภาพ = 6 x 6 ช่อง → ช่องละ 2 studs
		Floor = Color3.fromRGB(236, 150, 60),
		House = Color3.fromRGB(245, 178, 96),
	}),
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

	-- มอนเดินสุ่มในพื้นที่รูปพัดของฐานตัวเอง (ยืนยัน 2026-09-25) · ไม่เข้าลานฐาน/บ้าน ไม่เข้าฐานข้างๆ
	-- เกิดในสวนหลังบ้าน (≥ Yard.Inner) · Outer ≈ ระยะที่ป้อมยังยิงถึงเป็นส่วนใหญ่
	MonsterWander = table.freeze({
		Inner = 60,
		Outer = 124,
		HalfAngle = math.rad(20), -- ต้องน้อยกว่าครึ่งช่องฐาน (22.5°) เพื่อไม่ล้ำฐานข้างๆ
		PadMargin = 3, -- ระยะกันห่างจากขอบลานฐาน
		PauseMin = 0.5, -- หยุดยืนก่อนเดินต่อ (วินาที)
		PauseMax = 2,
	}),

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
