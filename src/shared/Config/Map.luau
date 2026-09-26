-- ผังแมพหลุมอุกกาบาต (เจ้าของ: World_Builder) · รายละเอียด design/crater-map.md
-- หน่วย studs · กลางแมพ = (0, 0)
-- พื้น/แอ่ง/ถนน/ขอบ = Workspace.MapGround สร้างจาก tools/gen_map.py → map/ground.project.json (เห็นใน Studio ตอนแก้แมพ)
--   ⚠️ แก้ค่าในหมวด "พื้น" ต้องแก้ใน tools/gen_map.py ให้ตรงกัน แล้วรัน python3 tools/gen_map.py
-- ฐาน/ป้าย/spawn/tag = MapService สร้างตอนเกมรัน
-- ของในฐานใช้พิกัดท้องถิ่น (ดู Util/MapMath): u = ระยะจากกลางแมพ · v = ระยะไปทางขวาเมื่อยืนหันหลังให้หลุม
-- [Proposed] ค่าชุดแรกของ prototype

return table.freeze({
	GroundY = 1, -- ผิวบนของพื้น
	-- พื้น (ค่าเดียวกับ tools/gen_map.py)
	Radius = 160, -- แมพวงกลม (ยืนยัน 2026-09-25) · ลดจาก 181 ให้พอดีกับสวนหลังบ้าน (2026-09-26)
	Tile = 8, -- ขนาดบล็อกพื้น 1 ก้อน · ผิวบนเป็นปุ่ม Studs
	EdgeHeight = 3, -- กำแพงเตี้ยรอบขอบแมพ

	-- แอ่งกลางแมพ = จุดบอสเกิด + ที่เก็บของ (ยืนยัน 2026-09-26) · เดินลงได้ทุกทิศ ขั้นละ 1 stud
	Pit = table.freeze({
		Radius = 40,
		Steps = table.freeze({ -- จากนอกเข้าใน: ภายในรัศมี Outer ลึก Depth
			table.freeze({ Outer = 40, Depth = 1 }),
			table.freeze({ Outer = 30, Depth = 2 }),
			table.freeze({ Outer = 18, Depth = 3 }),
		}),
		WarnSeconds = 10, -- เตือนก่อนบอสมา → ปิดแอ่ง (ของหยุดเกิด) · บอสอยู่ = ดันผู้เล่นออก
	}),

	-- ถนนวงแหวนรอบแอ่ง (บล็อกสีเข้ม) · ผู้เล่นที่ถูกดันออกจากแอ่งจะมายืนตรงนี้
	Road = table.freeze({ Inner = 40, Outer = 52 }),

	-- สไตล์บล็อก (ยืนยัน 2026-09-25): พื้นและบ้านใช้ texture ลายบล็อกสีส้ม
	-- TextureAssetId = 0 → ยังไม่อัปโหลดภาพ ใช้สีเรียบแทน · ภาพต้นฉบับ assets/textures/block_tile.png
	Style = table.freeze({
		TextureAssetId = 0,
		StudsPerTile = 12, -- 1 แผ่นภาพ = 6 x 6 ช่อง → ช่องละ 2 studs
		Floor = Color3.fromRGB(236, 150, 60),
		House = Color3.fromRGB(245, 178, 96),
	}),
	Segments = 48, -- จำนวนชิ้นที่ใช้ต่อวงกลมหนึ่งวง (มากขึ้น = กลมขึ้นแต่ Part มากขึ้น)

	MaxBases = 8, -- จุดฐานรอบหลุม ทุก 45° (ฐาน 1 อยู่ทิศเหนือ −Z)
	BaseCount = 1, -- prototype: สร้างฐานเดียวก่อนเพื่อดูระบบ แล้วค่อยเพิ่มถึง MaxBases

	Base = table.freeze({
		Distance = 80, -- ระยะจากกลางแมพถึงกลางลานฐาน
		Size = 44,
		TurretDistance = 56, -- ป้อมเริ่มต้นอยู่หน้าฐาน ระหว่างทุ่งเก็บของกับลานฐาน
	}),

	-- สวนหลังบ้าน: มอนเล็ก/กลางของฐานนั้นเกิดในพื้นที่รูปพัดนี้
	Yard = table.freeze({ Inner = 104, Outer = 140, HalfAngle = math.rad(18) }),

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
