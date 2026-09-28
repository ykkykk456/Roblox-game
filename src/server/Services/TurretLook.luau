-- หน้าตาป้อมตามคลาส/สายธาตุ (เจ้าของ: Gameplay_Scripter) · โมดูลช่วยของ TurretService (ไม่มี Init/Start)
-- สร้างจาก Part ล้วนด้วยโค้ด · Anchored ทุกชิ้น · ขยับด้วยการตั้ง CFrame ทุกครั้งที่เล็ง
-- กลุ่มชิ้นส่วน (ตำแหน่งเทียบกับจุดหมุน = หัวป้อม หันไป -Z):
--   head   = หมุนซ้าย-ขวาตามเป้า (yaw) อย่างเดียว
--   barrel = หมุนตามเป้าเต็มทิศ (yaw + pitch)
--   spin   = เหมือน barrel แต่หมุนรอบแกนลำกล้องทุกครั้งที่เล็ง (Gatling)
-- [Proposed] หน้าตาเป็นร่างแรก · ยังไม่ได้ดูใน Studio
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน =====
--   • สีหลักของคลาส/สาย (accent) → Color ใน src/shared/Config/Skill_class_default.luau
--   • รูปทรงป้อมแต่ละคลาส → ฟังก์ชัน buildMage / buildArcher / buildGatling / buildAssassin / buildCannon ในไฟล์นี้
--     (ขนาด = Vector3.new(กว้าง, สูง, ยาว) · ตำแหน่ง = CFrame.new(ขวา, ขึ้น, หน้า) · ค่า Z ติดลบ = ไปทางปากกระบอก)
--   • สีโลหะ/ไม้/ฐาน/สีตอนช็อต → ค่าคงที่ด้านล่าง
--
-- คุยกับไฟล์ไหนบ้าง: TurretService เรียก build / aim / setStunned / muzzleOf / keyOf · ClassMath ให้สีและสายที่ถูกต้อง
-- ไฟล์นี้แค่ "หน้าตา" ไม่มีผลกับดาเมจ → แก้รูปทรง/สีได้ปลอดภัย (ห้ามเปลี่ยนชื่อ "Head" และ query = true ของชิ้นหัว)
--
-- 📖 อ่านตามลำดับนี้
--   1) TurretLook.build (ท้ายไฟล์) — TurretService.luau:buildLook เรียกตอนสร้าง/เปลี่ยนป้อม
--        สร้างฐาน → ถาม Util/ClassMath.luau:stats ว่าสีอะไร → เลือกฟังก์ชันปั้นตามคลาส → ติดป้ายชื่อ → หันไปที่บอส
--   2) builder (ด้านบน) — "เครื่องปั้น" add(...) ที่ทุก build* ใช้ สร้างชิ้นส่วน + จดว่าชิ้นนี้หมุนกลุ่มไหน
--   3) buildMage / buildArcher / buildGatling / buildAssassin / buildCannon / buildUnchosen — หน้าตาแต่ละคลาส
--        ✏️ อยากเปลี่ยนรูปทรงป้อม → แก้ในฟังก์ชันเหล่านี้
--   4) TurretLook.aim — TurretService.luau:hit เรียกทุกครั้งที่ยิง · หมุนหัว/ลำกล้องตามกลุ่ม head / barrel / spin
--   5) setStunned / muzzleOf / keyOf — ตัวช่วยเล็กๆ (สีตอนช็อต · จุดปากกระบอก · คีย์บอกว่าต้องปั้นใหม่ไหม)
--
-- วิธีอ่านตัวเลขตำแหน่งชิ้นส่วน (ใช้ทั้งไฟล์):
--   Vector3.new(กว้าง X, สูง Y, ยาว Z) = ขนาดชิ้น (studs)
--   CFrame.new(x, y, z) = เลื่อนจากจุดหมุนหัวป้อม · x+ = ขวา · y+ = ขึ้น · z− = ไปข้างหน้า (ทางปากกระบอก)
--   CFrame.Angles(rx, ry, rz) = หมุนรอบแกน X/Y/Z หน่วยเรเดียน · math.pi = 180° · math.rad(25) = แปลง 25° เป็นเรเดียน
--   a * b = ทำ a ก่อน แล้วทำ b ต่อ "จากมุมมองของ a" (เช่น หมุนก่อนแล้วค่อยเลื่อน = เลื่อนไปในทิศที่หมุนแล้ว)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassMath = require(ReplicatedStorage.Shared.Util.ClassMath)

-- ===== ค่าคงที่ (สีปรับได้ปลอดภัย) =====
-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนสีวัสดุที่ใช้ร่วมกันทุกคลาส · Color3.fromRGB(แดง, เขียว, น้ำเงิน) ค่าละ 0–255
-- HEAD_HEIGHT: TurretService ใช้ด้วย · เพิ่ม = ป้อมสูงขึ้น (ฐานยาวขึ้น, จุดยิงสูงขึ้น) · ต้องมากกว่า 1
local HEAD_HEIGHT = 5 -- ความสูงจุดหมุนหัวป้อมจากฐาน (เท่าป้อมเดิม)
local PEDESTAL_COLOR = Color3.fromRGB(70, 74, 86)
local UNCHOSEN_HEAD = Color3.fromRGB(60, 160, 170)
local DARK_METAL = Color3.fromRGB(40, 42, 50)
local STEEL = Color3.fromRGB(190, 195, 205)
local WOOD = Color3.fromRGB(120, 80, 45)
local BRONZE = Color3.fromRGB(176, 120, 60)
local STUNNED_COLOR = Color3.fromRGB(110, 110, 116)
-- GATLING_SPIN_STEP: เพิ่ม = ลำกล้อง Gatling หมุนเร็วขึ้น · 0 = ไม่หมุน
local GATLING_SPIN_STEP = math.rad(40) -- องศาที่ลำกล้อง Gatling หมุนต่อการเล็งหนึ่งครั้ง

-- ===== ชนิดข้อมูล =====
-- Piece = ชิ้นส่วน 1 ชิ้น + ตำแหน่งเทียบหัวป้อม + กลุ่มการหมุน · Look = ข้อมูลหน้าตาป้อมทั้งตัว (TurretService ถือไว้)
-- type = คำใบ้ชนิดช่วยตัวตรวจโค้ด (ไม่มีผลตอนรัน) · `"head" | "barrel" | "spin"` = ต้องเป็นข้อความ 1 ใน 3 ตัวนี้
-- export type = ให้ไฟล์อื่นใช้ชื่อชนิดนี้ได้ (TurretService เขียน TurretLook.Look)
type Piece = { part: BasePart, offset: CFrame, group: "head" | "barrel" | "spin" }

export type Look = {
	model: Model,
	pedestal: BasePart,
	head: BasePart, -- ชิ้นหลักของหัว (ติดป้ายชื่อ)
	barrel: BasePart, -- ลำกล้องหลัก
	label: TextLabel,
	headPosition: Vector3, -- จุดหมุนสำหรับเล็ง
	muzzleDistance: number, -- ระยะจากจุดหมุนถึงปากกระบอก
	pieces: { Piece },
	tinted: { [BasePart]: Color3 }, -- ชิ้นที่เปลี่ยนเป็นสีเทาตอนช็อต → สีเดิม
	spinAngle: number,
	key: string, -- คลาส|สาย|ขั้นสีไฟ · เปลี่ยน = ต้องสร้างใหม่
}

-- ===== ตัวช่วยสร้างชิ้นส่วน =====
-- สร้าง Part ยึดอยู่กับที่ ใส่ใน parent · คืน Part
local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- ตัวช่วยสร้างหัวป้อม: add(...) = ชิ้นประดับ (ชนไม่ได้ ยิง ray ไม่โดน)
--   opts: shape = รูปทรง (Ball/Cylinder) · material = วัสดุ · tint = เปลี่ยนเป็นเทาตอนช็อต · query = ให้ ray ชนได้ (ใช้กับชิ้นหัว)
-- เทคนิค: builder "คืนฟังก์ชัน" ที่จำ model / pieces / tinted ไว้ข้างใน (เรียกว่า closure)
--   ผลคือ build* ทุกตัวเรียกแค่ add(กลุ่ม, ชื่อ, ขนาด, สี, ตำแหน่ง, ตัวเลือก) ไม่ต้องส่ง model ซ้ำทุกครั้ง
-- ตัวอย่างการเรียก: add("barrel", "Barrel", Vector3.new(0.8, 0.8, 4), DARK_METAL, CFrame.new(0, 0, -3))
--   = ลำกล้องหนา 0.8 ยาว 4 สีเหล็กเข้ม อยู่หน้าจุดหมุน 3 studs หมุนตามเป้าเต็มทิศ
local function builder(model: Model, pieces: { Piece }, tinted: { [BasePart]: Color3 })
	return function(
		group: "head" | "barrel" | "spin",
		name: string,
		size: Vector3,
		color: Color3,
		offset: CFrame,
		opts: { shape: Enum.PartType?, material: Enum.Material?, tint: boolean?, query: boolean? }?
	): Part
		-- `opts or {}` = ไม่ได้ส่งตัวเลือกมา (nil) → ใช้ตารางว่างแทน จะได้อ่าน o.shape ได้โดยไม่ error
		-- CanCollide = false → คน/ของเดินทะลุได้ · CanQuery = ให้ raycast ชนได้ไหม (เปิดเฉพาะชิ้นหัว)
		local o = opts or {}
		local part = newPart(name, size, color, model)
		part.CanCollide = false
		part.CanQuery = o.query == true
		if o.shape then
			part.Shape = o.shape
		end
		if o.material then
			part.Material = o.material
		end
		-- tint = จำสีเดิมไว้ (ตอนช็อตเปลี่ยนเป็นเทา ฟื้นแล้วคืนสีนี้)
		if o.tint then
			tinted[part] = color
		end
		-- table.insert = ต่อท้ายรายการ pieces · aim จะวนรายการนี้เพื่อหมุนทุกชิ้นตามกลุ่ม
		table.insert(pieces, { part = part, offset = offset, group = group })
		return part
	end
end

-- ทรงกระบอกของ Roblox ยาวตามแกน X → หมุนให้ยาวตามแกน Z (ทิศยิง) [Verified: Cylinder shape axis = X]
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

-- ใส่แสงเรืองรอบชิ้น part (range = รัศมีแสงเป็น studs)
local function glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 2
	light.Parent = part
end

-- Add = ชนิดของฟังก์ชัน add · Built = ผลของ build* แต่ละแบบ (หัว, ลำกล้อง, muzzle = ระยะจุดหมุนถึงปากกระบอก)
-- typeof(...) ในบรรทัด type = ให้ตัวตรวจโค้ด "ดูเอาเอง" ว่า add หน้าตาเป็นยังไง (ไม่ได้สร้าง Model จริงตอนเกมรัน)
type Add = typeof(builder(Instance.new("Model"), {}, {}))
type Built = { head: BasePart, barrel: BasePart, muzzle: number }

-- ===== หน้าตาแต่ละแบบ (accent = สีหลักของคลาส/สายจาก Config) =====
-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนรูปทรงป้อม: ทุกฟังก์ชันด้านล่างทำแบบเดียวกัน
--   (1) สร้างชิ้น "Head" (ต้องมี query = true) (2) สร้างชิ้น "Barrel" (3) ชิ้นประดับ (4) คืน { head, barrel, muzzle }
--   muzzle = ระยะจากจุดหมุนถึงปากกระบอก (กระสุนเริ่มวาดตรงนั้น) · ยืดลำกล้องยาวขึ้น → เพิ่ม muzzle ตาม
--   เพิ่มชิ้นใหม่: ก๊อปบรรทัด add(...) มาแก้ขนาด/ตำแหน่ง/สี ได้เลย

-- ยังไม่เลือกคลาส: หัวกล่องสีฟ้าอมเขียว + ลำกล้องธรรมดา
local function buildUnchosen(add: Add): Built
	local head = add("head", "Head", Vector3.new(3, 2.5, 3), UNCHOSEN_HEAD, CFrame.new(), { tint = true, query = true })
	local barrel = add("barrel", "Barrel", Vector3.new(0.8, 0.8, 4), DARK_METAL, CFrame.new(0, 0, -3))
	return { head = head, barrel = barrel, muzzle = 5 }
end

-- นักเวท: ลูกแก้วคริสตัลลอย + หนามคริสตัลรอบๆ · ลำกล้อง = แท่งคริสตัล
local function buildMage(add: Add, accent: Color3, branchId: string): Built
	local collarAt = CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, math.pi / 2) -- แผ่นกลมแนวราบใต้ลูกแก้ว
	add("head", "Collar", Vector3.new(0.6, 3.2, 3.2), DARK_METAL, collarAt, { shape = Enum.PartType.Cylinder })
	local head = add("head", "Head", Vector3.new(2.6, 2.6, 2.6), accent, CFrame.new(0, 0.3, 0), {
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
		tint = true,
		query = true,
	})
	-- `for index = 0, 3 do` = วนนับ 0,1,2,3 (4 รอบ) → หนามคริสตัล 4 อัน รอบลูกแก้ว
	-- มุม = index × 90° + 45° → 45°, 135°, 225°, 315° (เฉียงสี่มุม)
	-- วิธีวาง: หมุนรอบแกนตั้งไปที่มุมนั้น → เลื่อนออกไป 1.7 → เอียงหนาม · accent:Lerp(ขาว, 0.4) = ผสมสีหลักกับขาว 40% (สีอ่อนลง)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		add(
			"head",
			"Crystal",
			Vector3.new(0.5, 1.8, 0.5),
			accent:Lerp(Color3.new(1, 1, 1), 0.4),
			CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.2, -1.7) * CFrame.Angles(math.rad(-25), 0, math.rad(45)),
			{ material = Enum.Material.Glass, tint = true }
		)
	end
	local barrel = add(
		"barrel",
		"Barrel",
		Vector3.new(0.6, 0.6, 3),
		accent:Lerp(Color3.new(1, 1, 1), 0.5),
		CFrame.new(0, 0.3, -2.6) * CFrame.Angles(0, 0, math.pi / 4),
		{ material = Enum.Material.Glass }
	)
	if branchId == "Lightning" then
		-- สายฟ้า: หนามฟ้าแหลมด้านบน
		-- `for index = -1, 1, 2` = เริ่ม −1 ไปถึง 1 ก้าวละ 2 → ได้แค่ −1 กับ 1 = ซ้าย/ขวา (ทริคสร้างของคู่สมมาตร)
		for index = -1, 1, 2 do
			local at = CFrame.new(index * 0.7, 1.9, 0) * CFrame.Angles(0, 0, index * 0.4)
			add("head", "Bolt", Vector3.new(0.3, 1.6, 0.3), accent, at, { material = Enum.Material.Neon })
		end
	elseif branchId == "Alchemist" then
		-- นักแปรธาตุ: วงแหวนรุ้งรอบลูกแก้ว
		local ring = {
			Color3.fromRGB(255, 90, 90),
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(90, 220, 120),
			Color3.fromRGB(90, 150, 255),
		}
		for index, color in ring do
			local angle = (index - 1) * math.pi / 2
			local at = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.3, -2.1)
			add("head", "Rune", Vector3.new(0.5, 0.5, 0.5), color, at, {
				shape = Enum.PartType.Ball,
				material = Enum.Material.Neon,
			})
		end
	end
	return { head = head, barrel = barrel, muzzle = 4.2 }
end

-- นักธนู: ตัวหน้าไม้ไม้ + แขนคันศรสองข้าง + สาย · ลำกล้อง = ราง
local function buildArcher(add: Add, accent: Color3, branchId: string): Built
	local head = add("head", "Head", Vector3.new(2.4, 1.8, 2.6), WOOD, CFrame.new(0, -0.2, 0.3), {
		tint = true,
		query = true,
	})
	add("head", "Trim", Vector3.new(2.5, 0.3, 2.7), accent, CFrame.new(0, 0.75, 0.3), { tint = true })
	local barrel = add("barrel", "Barrel", Vector3.new(0.6, 0.5, 4.2), WOOD, CFrame.new(0, 0.2, -1.6), { tint = true })
	for side = -1, 1, 2 do
		add(
			"barrel",
			"Arm",
			Vector3.new(2.2, 0.35, 0.35),
			accent,
			CFrame.new(side * 1.2, 0.2, -3.1) * CFrame.Angles(0, side * math.rad(-20), 0),
			{ tint = true }
		)
	end
	add("barrel", "String", Vector3.new(4.2, 0.08, 0.08), Color3.fromRGB(235, 230, 210), CFrame.new(0, 0.2, -2.3))
	add("barrel", "Bolt", Vector3.new(0.15, 0.15, 3.2), STEEL, CFrame.new(0, 0.5, -2.6), {
		material = Enum.Material.Metal,
	})
	if branchId == "Wind" then
		-- ลม: วงแหวนลมหน้าหน้าไม้
		add("barrel", "WindRing", Vector3.new(0.25, 2.4, 2.4), accent, CFrame.new(0, 0.2, -4) * ALONG_Z, {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon,
		})
		add("head", "Fin", Vector3.new(0.2, 1.4, 1.6), accent, CFrame.new(0, 1.3, 1), { material = Enum.Material.Neon })
	end
	return { head = head, barrel = barrel, muzzle = 4.2 }
end

-- Gatling (สายของนักธนู): เปลี่ยนร่างเป็นปืนกลหกลำกล้องหมุน
local function buildGatling(add: Add, accent: Color3): Built
	local head = add("head", "Head", Vector3.new(2.8, 2.2, 2.8), Color3.fromRGB(90, 94, 104), CFrame.new(0, 0, 0.4), {
		material = Enum.Material.DiamondPlate,
		tint = true,
		query = true,
	})
	add("head", "Ammo", Vector3.new(0.8, 1.4, 1.6), Color3.fromRGB(150, 120, 60), CFrame.new(1.8, -0.2, 0.6))
	local barrel = add("barrel", "Barrel", Vector3.new(1.4, 1.4, 1.4), DARK_METAL, CFrame.new(0, 0, -1.2) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
	})
	-- ลำกล้องหมุน 6 ท่อ วางเป็นวงกลมรัศมี 0.65 · มุมห่างกัน 60° (math.pi / 3)
	-- จุดบนวงกลม: x = cos(มุม) × รัศมี, y = sin(มุม) × รัศมี · กลุ่ม "spin" = aim จะหมุนท่อพวกนี้ทุกครั้งที่ยิง
	for index = 0, 5 do
		local angle = index * math.pi / 3
		add(
			"spin",
			"Tube",
			Vector3.new(4.2, 0.4, 0.4),
			accent,
			CFrame.new(math.cos(angle) * 0.65, math.sin(angle) * 0.65, -3.2) * ALONG_Z,
			{ shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, tint = true }
		)
	end
	for _, z in { -2, -4.8 } do
		add("spin", "Clamp", Vector3.new(0.3, 1.9, 1.9), DARK_METAL, CFrame.new(0, 0, z) * ALONG_Z, {
			shape = Enum.PartType.Cylinder,
		})
	end
	return { head = head, barrel = barrel, muzzle = 5.5 }
end

-- นักฆ่า: หัวเหลี่ยมคม (ข้าวหลามตัด) สีเข้ม + ใบมีดสองข้าง · ลำกล้อง = มีดสั้นกลาง
local function buildAssassin(add: Add, accent: Color3, branchId: string, classColor: Color3): Built
	local head = add(
		"head",
		"Head",
		Vector3.new(2.3, 1.8, 2.3),
		classColor,
		CFrame.Angles(0, math.pi / 4, 0),
		{ material = Enum.Material.Slate, tint = true, query = true }
	)
	local hoodAt = CFrame.new(0, 1.2, 0.2) * CFrame.Angles(0, math.pi / 4, 0)
	add("head", "Hood", Vector3.new(1.4, 1.2, 1.4), classColor, hoodAt, { tint = true })
	add("head", "Eye", Vector3.new(1.2, 0.2, 0.2), accent, CFrame.new(0, 0.3, -1.65), { material = Enum.Material.Neon })
	local barrel = add("barrel", "Barrel", Vector3.new(0.3, 0.6, 3.2), STEEL, CFrame.new(0, 0, -2.4), {
		material = Enum.Material.Metal,
	})
	-- ยังไม่มีสาย → ใบมีดเหล็กธรรมดา · มีสาย → ใบมีดเรืองแสงสีของสาย
	local bladeColor = if branchId == "" then STEEL else accent
	for side = -1, 1, 2 do
		add(
			"barrel",
			"Blade",
			Vector3.new(0.2, 0.7, 3.2),
			bladeColor,
			CFrame.new(side * 1.5, 0, -1.4) * CFrame.Angles(0, side * math.rad(12), 0),
			{ material = if branchId == "" then Enum.Material.Metal else Enum.Material.Neon }
		)
	end
	if branchId == "Poison" then
		add("head", "Vial", Vector3.new(0.9, 0.9, 0.9), accent, CFrame.new(0, 1.3, 1.2), {
			shape = Enum.PartType.Ball,
			material = Enum.Material.Glass,
		})
	elseif branchId == "Dark" then
		local orb = add("head", "Void", Vector3.new(1.1, 1.1, 1.1), accent, CFrame.new(0, 2.2, 0.2), {
			shape = Enum.PartType.Ball,
			material = Enum.Material.Neon,
		})
		glow(orb, accent, 8)
	end
	return { head = head, barrel = barrel, muzzle = 4 }
end

-- ปืนใหญ่: ป้อมทองเหลืองลำกล้องอ้วน · สายไฟ = มีบอลไฟเรืองแสงที่ปากกระบอกตามสีเลเวล
local function buildCannon(add: Add, accent: Color3, branchId: string, classColor: Color3): Built
	local head = add("head", "Head", Vector3.new(3.2, 3.2, 3.2), classColor, CFrame.new(0, 0, 0.4), {
		shape = Enum.PartType.Ball,
		material = Enum.Material.Metal,
		tint = true,
		query = true,
	})
	for side = -1, 1, 2 do
		add("head", "Wheel", Vector3.new(0.4, 2.2, 2.2), WOOD, CFrame.new(side * 1.7, -0.6, 0.4), {
			shape = Enum.PartType.Cylinder,
		})
	end
	local barrel = add("barrel", "Barrel", Vector3.new(4.4, 1.9, 1.9), BRONZE, CFrame.new(0, 0, -2.4) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
		tint = true,
	})
	add("barrel", "Rim", Vector3.new(0.5, 2.4, 2.4), DARK_METAL, CFrame.new(0, 0, -4.5) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
	})
	-- สายไฟ: accent = สีตามขั้นเลเวล (ClassMath.fireColor) · ข้ามขั้นสี → keyOf เปลี่ยน → TurretService ปั้นใหม่ให้เอง
	if branchId == "Fire" then
		add("barrel", "Band", Vector3.new(0.3, 2.1, 2.1), accent, CFrame.new(0, 0, -1.4) * ALONG_Z, {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon,
		})
		local fireball = add("barrel", "Fireball", Vector3.new(1.4, 1.4, 1.4), accent, CFrame.new(0, 0, -4.9), {
			shape = Enum.PartType.Ball,
			material = Enum.Material.Neon,
		})
		glow(fireball, accent, 12)
	end
	return { head = head, barrel = barrel, muzzle = 5.2 }
end

-- ===== API ให้ TurretService เรียก =====
local TurretLook = {}

TurretLook.HEAD_HEIGHT = HEAD_HEIGHT

-- คีย์หน้าตา: เปลี่ยนเมื่อคลาส/สายเปลี่ยน หรือสายไฟข้ามขั้นสีใน FireColors
function TurretLook.keyOf(classId: string, branchId: string, level: number): string
	-- คีย์ = "คลาส|สาย|ขั้นสีไฟ" · ขั้นสีไฟนับเฉพาะสายไฟ (สายอื่น = 0 เพราะเลเวลไม่เปลี่ยนหน้าตา)
	-- ตัวอย่าง: นักเวทสายฟ้า → "Mage|Lightning|0" · ปืนใหญ่สายไฟ Lv.25 → "Cannon|Fire|2"
	-- ⚠️ ระวัง: ถ้าเพิ่มสิ่งที่ทำให้หน้าตาเปลี่ยน (เช่น ตามเลเวล) ต้องใส่ลงคีย์นี้ด้วย ไม่งั้นป้อมไม่ถูกปั้นใหม่
	local stats = ClassMath.stats(classId, branchId, level)
	local tier = if stats.Effect and stats.Effect.Kind == "FireColor" then ClassMath.fireTier(level) else 0
	local class = if ClassMath.isClass(classId) then classId else ""
	return `{class}|{ClassMath.validBranch(classId, branchId)}|{tier}`
end

-- เล็งเป้า: หัวหมุนแนวราบ · ลำกล้องหันตรงไปที่เป้า · Gatling หมุนลำกล้องเพิ่มทีละขั้น
function TurretLook.aim(look: Look, target: Vector3)
	-- CFrame.lookAt(จุดวาง, จุดที่มอง) = ท่าทางที่ "ยืนที่จุดวางแล้วหันหน้าไปหาจุดที่มอง"
	-- yaw  = หันแนวราบอย่างเดียว (ใช้ความสูงของหัวป้อมเองแทนความสูงเป้า → ไม่ก้ม/เงย) ใช้กับกลุ่ม head
	-- full = หันตรงไปที่เป้าเต็มทิศ (ก้ม/เงยด้วย) ใช้กับกลุ่ม barrel / spin
	-- เช็ก > 0.01 กันกรณีเป้าอยู่ตรงจุดหมุนพอดี (หาทิศไม่ได้ lookAt จะเพี้ยน) → nil = ไม่ขยับ
	local pivot = look.headPosition
	local flat = Vector3.new(target.X, pivot.Y, target.Z)
	local yaw = if (flat - pivot).Magnitude > 0.01 then CFrame.lookAt(pivot, flat) else nil
	local full = if (target - pivot).Magnitude > 0.01 then CFrame.lookAt(pivot, target) else yaw
	-- มุมหมุนของ Gatling เพิ่มทีละ 40° ทุกครั้งที่เล็ง · % (2π) = วนกลับเป็น 0 เมื่อครบรอบ 360° (ตัวเลขไม่โตไปเรื่อยๆ)
	look.spinAngle = (look.spinAngle + GATLING_SPIN_STEP) % (2 * math.pi)
	local roll = CFrame.Angles(0, 0, look.spinAngle)
	-- วางทุกชิ้นใหม่: ท่าทางของกลุ่ม × offset ของชิ้น (ตำแหน่งเทียบหัวที่จดไว้ตอน add) = ตำแหน่งจริงในโลก
	for _, piece in look.pieces do
		if piece.group == "head" then
			if yaw then
				piece.part.CFrame = yaw * piece.offset
			end
		elseif full then
			piece.part.CFrame = if piece.group == "spin" then full * roll * piece.offset else full * piece.offset
		end
	end
end

-- ช็อต = ชิ้นหลักกลายเป็นสีเทา · ฟื้น = สีเดิม
function TurretLook.setStunned(look: Look, stunned: boolean)
	for part, color in look.tinted do
		part.Color = if stunned then STUNNED_COLOR else color
	end
end

-- จุดปากกระบอกในโลก (จุดเริ่มกระสุนที่ส่งให้ Client วาด): จากหัวป้อมไปทางเป้า muzzleDistance studs
function TurretLook.muzzleOf(look: Look, target: Vector3): Vector3
	-- direction = ลูกศรจากหัวป้อมไปเป้า · .Unit = ลูกศรทิศเดิมแต่ยาว 1 · × muzzleDistance = ยาวเท่าลำกล้อง
	-- ตัวอย่าง: หัวอยู่ (0,5,0) เป้าอยู่ (0,5,−100) muzzle 4.2 → ปากกระบอก = (0,5,−4.2)
	local direction = target - look.headPosition
	if direction.Magnitude < 0.01 then
		return look.headPosition
	end
	return look.headPosition + direction.Unit * look.muzzleDistance
end

-- สร้างป้อมที่ฐาน foot (ระดับพื้น) · หันไปที่ facing · ยังไม่ใส่ Parent (TurretService ใส่เอง)
function TurretLook.build(foot: Vector3, classId: string, branchId: string, level: number, facing: Vector3): Look
	-- ขั้น 1: เตรียมกล่อง Model + รายการชิ้น + "เครื่องปั้น" add ที่ผูกกับ model นี้
	local model = Instance.new("Model")
	local pieces: { Piece } = {}
	local tinted: { [BasePart]: Color3 } = {}
	local add = builder(model, pieces, tinted)

	-- ขั้น 2: ฐานทรงกระบอก (ไม่หมุนตามเป้า จึงไม่ใช้ add) · Cylinder ยาวตามแกน X → หมุน 90° ให้ตั้งขึ้น
	-- สูง HEAD_HEIGHT − 1 = 4 · ศูนย์กลางอยู่ที่ครึ่งความสูง (2) → ฐานแตะพื้นพอดี
	local pedestal = newPart("Pedestal", Vector3.new(HEAD_HEIGHT - 1, 6, 6), PEDESTAL_COLOR, model)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CFrame = CFrame.new(foot + Vector3.new(0, (HEAD_HEIGHT - 1) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)

	-- ขั้น 3: ถาม ClassMath ว่าสีหลักคืออะไร (สีสาย ถ้ามีสาย · สีคลาส ถ้ายังไม่มี · สายไฟ = สีตามเลเวล)
	local stats = ClassMath.stats(classId, branchId, level)
	local class = if ClassMath.isClass(classId) then classId else ""
	local branch = ClassMath.validBranch(classId, branchId) -- ไม่ตรงคลาส/ข้อมูลเสีย = ไม่มีสาย
	local accent = stats.Color

	-- เลือกหน้าตาตามคลาส · ชื่อคลาส/สายต้องตรงกับ Config (สะกดผิด = ได้หน้าตา "ยังไม่เลือก")
	-- ขั้น 4: เรียกฟังก์ชันปั้นตามคลาส · นักธนูสาย Gatling เปลี่ยนร่างทั้งตัว จึงแยกไป buildGatling
	--   นักฆ่า/ปืนใหญ่ ส่งสีคลาส (stats ของคลาสแบบไม่มีสาย) ไปด้วย เพราะตัวป้อมใช้สีคลาส ส่วนประดับใช้สีสาย
	-- ✏️ แก้ตรงนี้ถ้าเพิ่มคลาสใหม่ (เพิ่ม elseif class == "ชื่อคลาส" then built = buildชื่อใหม่(...))
	local built: Built
	if class == "Mage" then
		built = buildMage(add, accent, branch)
	elseif class == "Archer" then
		built = if branch == "Gatling" then buildGatling(add, accent) else buildArcher(add, accent, branch)
	elseif class == "Assassin" then
		built = buildAssassin(add, accent, branch, ClassMath.stats(class, "", level).Color)
	elseif class == "Cannon" then
		built = buildCannon(add, accent, branch, ClassMath.stats(class, "", level).Color)
	else
		built = buildUnchosen(add)
	end

	-- ป้ายชื่อเหนือหัว (ข้อความ TurretService ใส่ให้ใน refreshLabel) · ไกลเกิน 150 studs ไม่แสดง
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 28)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 150
	gui.Parent = built.head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	-- PrimaryPart = ชิ้นหลักของ Model (ใช้อ้างตำแหน่งทั้งโมเดล)
	model.PrimaryPart = pedestal

	-- ขั้น 5: รวมข้อมูลทั้งหมดเป็น Look ให้ TurretService เก็บไว้ · จุดหมุนหัว = ฐาน + สูงขึ้น HEAD_HEIGHT (5)
	-- แล้วเล็งไปทางบอสครั้งแรก (aim จะจัดทุกชิ้นให้อยู่ที่ของมัน · ก่อนหน้านี้ชิ้นยังกองอยู่ที่จุดศูนย์)
	local look: Look = {
		model = model,
		pedestal = pedestal,
		head = built.head,
		barrel = built.barrel,
		label = label,
		headPosition = foot + Vector3.new(0, HEAD_HEIGHT, 0),
		muzzleDistance = built.muzzle,
		pieces = pieces,
		tinted = tinted,
		spinAngle = 0,
		key = TurretLook.keyOf(classId, branchId, level),
	}
	TurretLook.aim(look, Vector3.new(facing.X, look.headPosition.Y, facing.Z))
	return look
end

return TurretLook
