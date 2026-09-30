-- หน้าตาป้อมตามธาตุ + ขั้นเลเวล (เจ้าของ: Gameplay_Scripter) · โมดูลช่วยของ TurretService (ไม่มี Init/Start)
-- สเปก: design/element-skills.md หัวข้อ 2.2 · หน้าตาอัปทุก 10 เลเวล (Config/Elements.LookTiers: Lv.1/10/20/30/40/50)
-- ป้อมมี 2 แบบ:
--   (ก) ป้อมโค้ด (prototype) — ปั้นจาก Part ล้วนในไฟล์นี้ (buildFire / buildWater / buildEarth / buildWind)
--   (ข) โมเดลที่ import เอง — ถ้ามีใน ServerStorage > TurretModels จะใช้แทนป้อมโค้ดทันที (ดู "วิธีทำโมเดลเอง" ด้านล่าง)
-- ทุกชิ้น Anchored · ขยับด้วยการตั้ง CFrame ทุกครั้งที่เล็ง · กลุ่มชิ้นส่วน (ตำแหน่งเทียบจุดหมุน = หัวป้อม หันไป -Z):
--   base   = ฐาน/ของตกแต่ง วางครั้งเดียว ไม่หมุนตามเป้า
--   head   = หมุนซ้าย-ขวาตามเป้า (yaw) อย่างเดียว
--   barrel = หมุนตามเป้าเต็มทิศ (yaw + pitch = ก้ม/เงย)
--   spin   = เหมือน barrel แต่หมุนรอบแกนลำกล้องทุกครั้งที่ยิง (ลำกล้องหมุนแบบปืนกล)
-- ชิ้นที่ "ขยับเอง" (ใบพัดหมุน ลูกแก้วลอย ประกายกะพริบ วงแหวนลอย) = ติด Attribute "Anim" → Client ขยับเอง
--   (Controllers/TurretAnimController) ลื่นกว่าและ Server ไม่ต้องส่งข้อมูลทุกเฟรม
--
-- ===== 📦 วิธีทำโมเดลป้อมเอง (import แทนป้อมโค้ด) =====
--   1) ใน Studio สร้างโฟลเดอร์ ServerStorage > TurretModels (ชื่อโฟลเดอร์ตั้งได้ที่ Elements.CustomModel.Folder)
--   2) ใส่ Model ชื่อ "<ธาตุ>_<เลเวลขั้น>" เช่น Fire_1, Fire_10, Fire_20, Fire_30, Fire_40, Fire_50
--        ไม่มีขั้นที่ตรง → ใช้ขั้นต่ำกว่าที่ใกล้ที่สุด → ไม่มีเลย ใช้ชื่อ "<ธาตุ>" เฉยๆ (เช่น "Fire") → ไม่มีอีก = ป้อมโค้ด
--        ป้อมที่ยังไม่เลือกธาตุ ใช้ชื่อ "Unchosen" / "Unchosen_1" ได้
--   3) ตั้งชื่อชิ้นส่วนตามหน้าที่ (ชิ้นที่อยู่ใน Model/Folder ชื่อเหล่านี้ก็นับด้วย):
--        Base   = ฐาน อยู่นิ่ง (ชนได้)            Head   = หัว หมุนซ้าย-ขวาตามเป้า
--        Barrel = ลำกล้อง ก้ม/เงย + หมุนตามเป้า   Spin   = (ไม่ใส่ก็ได้) หมุนรอบลำกล้องทุกนัด
--        Glow   = (ไม่ใส่ก็ได้) เปลี่ยนเป็นสีธาตุ + Neon อัตโนมัติ
--        Attachment ชื่อ Muzzle (ไม่ใส่ก็ได้) ไว้ใต้ชิ้น Barrel ที่ปากกระบอก = จุดที่กระสุนออก
--        ชิ้นชื่ออื่น = นับเป็น Base (อยู่นิ่ง)
--   4) Pivot ของ Model (Model > Edit Pivot) ต้อง "ตั้งตรง" และลูกศรหน้า (-Z / LookVector) ชี้ไปทางปากกระบอก
--      เกมวาง "ก้นโมเดล" (ด้านล่างสุดของกล่องครอบ) ลงบนแท่น TurretN แล้วหันหน้าไปทางบอสเอง
--   5) จุดหมุนตอนเล็ง = ตำแหน่งชิ้น Head (ไม่มี Head = สูง 75% ของโมเดล)
--   6) เกมตั้งให้เอง: Anchored ทุกชิ้น · ชิ้นที่ไม่ใช่ Base ไม่ชน (CanCollide = false) · ลบ Script ในโมเดลทิ้ง (กันโค้ดแปลกปลอม)
--   7) ขนาด: Elements.CustomModel.Height = ตัวเลข → ย่อ/ขยายให้สูงเท่านั้น (studs) · nil = ใช้ขนาดตามที่ปั้น
--   ⚠️ โมเดลที่ใช้ MeshPart + Texture จะไม่เปลี่ยนเป็นสีเทาตอนช็อตชัดเจน (สีเปลี่ยนแค่ส่วนที่ไม่มีลายผิว) [Inferred]
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน =====
--   • สีหลักของธาตุ (accent) → Color ใน src/shared/Config/Elements.luau (ไฟ: FireColors ตามเลเวล)
--   • เลเวลที่หน้าตาเปลี่ยน / ขนาดที่โตต่อขั้น → Elements.LookTiers / LookScalePerTier
--   • รูปทรงป้อมโค้ดแต่ละธาตุ → buildFire / buildWater / buildEarth / buildWind · ของแต่งตามขั้น → tierDecor
--     (ขนาด = Vector3.new(กว้าง, สูง, ยาว) · ตำแหน่ง = CFrame.new(ขวา, ขึ้น, หน้า) · ค่า Z ติดลบ = ไปทางปากกระบอก)
--   • ความเร็วใบพัด/ลูกแก้ว/วงแหวน → ค่า anim = { Speed, Amp } ในแต่ละชิ้น · สีตอนช็อต → STUNNED_COLOR
--
-- คุยกับไฟล์ไหนบ้าง: TurretService เรียก build / aim / setStunned / setShield / muzzleOf / keyOf · ElementMath ให้สี/ขั้น
-- ไฟล์นี้แค่ "หน้าตา" ไม่มีผลกับดาเมจ → แก้รูปทรง/สีได้ปลอดภัย (ป้อมโค้ด: ห้ามเปลี่ยนชื่อ "Head" และ query = true ของชิ้นหัว)
--
-- 📖 อ่านตามลำดับนี้
--   1) TurretLook.build (ท้ายไฟล์) — TurretService.luau:buildLook เรียกตอนสร้าง/เปลี่ยนป้อม
--        หาโมเดล import (findTemplate) → มี = buildCustom · ไม่มี = buildPrototype (ปั้นด้วยโค้ด)
--   2) builder — "เครื่องปั้น" add(...) ที่ป้อมโค้ดทุกตัวใช้ (สร้างชิ้น + จดกลุ่มการหมุน + ขยายตามขั้น)
--   3) buildUnchosen / buildFire / buildWater / buildEarth / buildWind + tierDecor (ของแต่งตามขั้นเลเวล)
--   4) buildCustom — ใช้โมเดล import: วางบนแท่น · แบ่งกลุ่มตามชื่อชิ้น · หาปากกระบอก
--   5) TurretLook.aim — TurretService.luau:hit เรียกทุกครั้งที่ยิง · หมุนชิ้นตามกลุ่ม head / barrel / spin
--   6) setStunned / setShield / muzzleOf / keyOf — ตัวช่วยเล็กๆ

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)

-- ===== ค่าคงที่ (สีปรับได้ปลอดภัย) =====
-- HEAD_HEIGHT: TurretService ใช้ด้วย (ป้อมว่าง) · เพิ่ม = ป้อมสูงขึ้น · ต้องมากกว่า 1
local HEAD_HEIGHT = 5
local PEDESTAL_COLOR = Color3.fromRGB(70, 74, 86)
local UNCHOSEN_HEAD = Color3.fromRGB(60, 160, 170)
local DARK_METAL = Color3.fromRGB(40, 42, 50)
local SILVER = Color3.fromRGB(205, 210, 220)
local BASALT = Color3.fromRGB(48, 46, 50)
local STONE = Color3.fromRGB(120, 92, 64)
local MOSS = Color3.fromRGB(80, 140, 60)
local AMBER = Color3.fromRGB(255, 190, 60)
local WHITE = Color3.new(1, 1, 1)
local STUNNED_COLOR = Color3.fromRGB(110, 110, 116)
local SHIELD_COLOR = Color3.fromRGB(150, 120, 85)
-- SPIN_STEP: เพิ่ม = กลุ่ม spin หมุนเร็วขึ้นต่อการยิง 1 ครั้ง · 0 = ไม่หมุน
local SPIN_STEP = math.rad(40)

-- ===== ชนิดข้อมูล =====
type Group = "base" | "head" | "barrel" | "spin"
type Piece = { part: BasePart, offset: CFrame, group: Group }
-- Anim = การขยับฝั่ง Client: Kind (Orbit/Flap/Bob/Rise/Blink/Hue) · Speed · Amp · PivotAt/Axis (ตำแหน่ง/แกนในพื้นที่ของกลุ่ม)
type Anim = { Kind: string, Speed: number?, Amp: number?, PivotAt: Vector3?, Axis: Vector3?, Phase: number? }
type Opts = {
	shape: Enum.PartType?,
	material: Enum.Material?,
	tint: boolean?, -- ช็อตแล้วเปลี่ยนเป็นสีเทา
	query: boolean?, -- ให้ raycast ชนได้ (ใช้กับชิ้นหัว)
	transparency: number?,
	anim: Anim?,
}

export type Look = {
	model: Model,
	pedestal: BasePart,
	head: BasePart, -- ชิ้นหลักของหัว (ติดป้ายชื่อ)
	barrel: BasePart, -- ลำกล้องหลัก
	label: TextLabel,
	headPosition: Vector3, -- จุดหมุนสำหรับเล็ง
	foot: Vector3, -- ฐานป้อมบนพื้น
	scale: number, -- ขนาดเทียบป้อมขั้น 1 (ใช้วางเกราะหิน)
	muzzleDistance: number, -- ระยะจากจุดหมุนถึงปากกระบอก
	pieces: { Piece },
	tinted: { [BasePart]: Color3 }, -- ชิ้นที่เปลี่ยนเป็นสีเทาตอนช็อต → สีเดิม
	spinAngle: number,
	shield: BasePart?, -- เกราะหิน (มีเมื่อ setShield true)
	custom: boolean, -- true = โมเดลที่ import เอง
	key: string, -- คีย์หน้าตา · เปลี่ยน = ต้องสร้างใหม่
}

-- ===== ตัวช่วยสร้างชิ้นส่วน =====
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

-- เครื่องปั้น: คืนฟังก์ชัน add(กลุ่ม, ชื่อ, ขนาด, สี, ตำแหน่ง, ตัวเลือก) ที่จำ model/pieces/tinted/scale ไว้ข้างใน (closure)
-- scale = ขยายทุกชิ้น (ขนาด + ระยะจากจุดหมุน) ตามขั้นเลเวล · anim = ติด Attribute ให้ Client ขยับเอง
-- ตัวอย่าง: add("barrel", "Barrel", Vector3.new(0.8, 0.8, 4), DARK_METAL, CFrame.new(0, 0, -3))
local function builder(model: Model, pieces: { Piece }, tinted: { [BasePart]: Color3 }, scale: number)
	return function(group: Group, name: string, size: Vector3, color: Color3, offset: CFrame, opts: Opts?): Part
		local o: Opts = opts or {}
		local part = newPart(name, size * scale, color, model)
		part.CanCollide = false
		part.CanQuery = o.query == true
		part.CastShadow = o.material ~= Enum.Material.Neon -- ชิ้นเรืองแสงไม่ทำเงา (เบาเครื่อง + ดูสว่าง)
		if o.shape then
			part.Shape = o.shape
		end
		if o.material then
			part.Material = o.material
		end
		if o.transparency then
			part.Transparency = o.transparency
		end
		if o.tint then
			tinted[part] = color
		end
		-- ขยายระยะจากจุดหมุนตาม scale แต่คงการหมุนเดิม
		local scaled = CFrame.new(offset.Position * scale) * offset.Rotation
		local anim = o.anim
		if anim then
			-- แปลงจุดหมุน/แกน (ในพื้นที่ของกลุ่ม) → พื้นที่ของชิ้นนี้ ให้ Client คำนวณง่าย
			local amp = anim.Amp or 0
			if anim.Kind == "Bob" or anim.Kind == "Rise" then
				amp *= scale
			end
			part:SetAttribute("Anim", anim.Kind)
			part:SetAttribute("AnimSpeed", anim.Speed or 1)
			part:SetAttribute("AnimAmp", amp)
			part:SetAttribute("AnimPhase", anim.Phase or 0)
			local pivotAt = if anim.PivotAt then anim.PivotAt * scale else scaled.Position
			part:SetAttribute("AnimPivot", scaled:PointToObjectSpace(pivotAt))
			part:SetAttribute("AnimAxis", scaled:VectorToObjectSpace(anim.Axis or Vector3.new(0, 0, 1)).Unit)
		end
		table.insert(pieces, { part = part, offset = scaled, group = group })
		return part
	end
end

-- ทรงกระบอกของ Roblox ยาวตามแกน X → หมุนให้ยาวตามแกน Z (ทิศยิง) [Verified: Cylinder shape axis = X]
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
-- ทรงกระบอกตั้งขึ้น (แกน X ชี้ฟ้า) = แผ่นกลม/เสาตั้ง
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- ใส่แสงเรืองรอบชิ้น (range = รัศมีแสง studs)
local function glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 2
	light.Parent = part
end

type Add = typeof(builder(Instance.new("Model"), {}, {}, 1))
-- head = ชิ้นหัว (ติดป้าย) · barrel = ลำกล้องหลัก · muzzle = ระยะจุดหมุนถึงปากกระบอก (ก่อนขยาย) · accentPart = ชิ้นที่ใส่แสงตามขั้น
type Built = { head: BasePart, barrel: BasePart, muzzle: number, accentPart: BasePart? }
-- ทรงแท่นฐาน (Pedestal) ของแต่ละธาตุ · width = กว้าง/เส้นผ่านศูนย์กลาง (studs)
type Base = { shape: Enum.PartType, width: number, color: Color3, material: Enum.Material }

-- ===== ป้อมโค้ด: หน้าตาแต่ละธาตุ (accent = สีธาตุ / สีบอลไฟตามเลเวล · tier = ขั้นหน้าตา 1..6) =====
-- ✏️ ทุกฟังก์ชันทำแบบเดียวกัน: (1) ชิ้น "Head" (query = true) (2) ชิ้น "Barrel" (3) ของประดับ (4) คืน { head, barrel, muzzle }
-- ขั้นสูงขึ้น = มีชิ้นเพิ่ม (if tier >= N then ...) + tierDecor ใส่ของแต่งกลางๆ ให้ทุกธาตุ

-- ยังไม่เลือกธาตุ: หัวกล่องสีฟ้าอมเขียว + ลำกล้องธรรมดา
local function buildUnchosen(add: Add, _accent: Color3, _tier: number): Built
	local head = add("head", "Head", Vector3.new(3, 2.5, 3), UNCHOSEN_HEAD, CFrame.new(), { tint = true, query = true })
	local barrel = add("barrel", "Barrel", Vector3.new(0.8, 0.8, 4), DARK_METAL, CFrame.new(0, 0, -3))
	return { head = head, barrel = barrel, muzzle = 5 }
end

-- 🔥 ไฟ: ฐานกล่องเตี้ยกว้างหินบะซอลต์ + ช่องระบายไฟ 4 ด้าน · ลำกล้องครกสั้นอ้วนเหล็กแดงเข้ม · แกนลูกบาศก์ Neon
-- ขั้น 3+: ลำกล้องมีวงเรืองแสงเพิ่ม · ขั้น 5+: ไฟลุกบนช่องระบาย (กะพริบ)
local function buildFire(add: Add, accent: Color3, tier: number): Built
	for index = 0, 3 do
		local turn = CFrame.Angles(0, index * math.pi / 2, 0)
		add("base", "Vent", Vector3.new(2.2, 0.8, 0.3), accent, turn * CFrame.new(0, 1.6, -3.05), { material = Enum.Material.Neon })
		if tier >= 5 then
			add("base", "Flame", Vector3.new(1.2, 1.2, 0.3), accent:Lerp(WHITE, 0.3), turn * CFrame.new(0, 4.4, -2.7), {
				material = Enum.Material.Neon,
				anim = { Kind = "Blink", Speed = 7, Phase = index * 1.3 },
			})
		end
	end
	local head = add("head", "Head", Vector3.new(3.2, 2, 3.2), BASALT, CFrame.new(0, -0.2, 0.3), {
		material = Enum.Material.Slate,
		tint = true,
		query = true,
	})
	local core = add("head", "Core", Vector3.new(1.1, 1.1, 1.1), accent, CFrame.new(0, 1.2, 0.4) * CFrame.Angles(math.rad(35), math.rad(45), 0), {
		material = Enum.Material.Neon,
	})
	local barrel = add("barrel", "Barrel", Vector3.new(3, 2.2, 2.2), Color3.fromRGB(110, 40, 35), CFrame.new(0, 0, -1.6) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
		tint = true,
	})
	add("barrel", "Rim", Vector3.new(0.4, 2.6, 2.6), DARK_METAL, CFrame.new(0, 0, -3) * ALONG_Z, { shape = Enum.PartType.Cylinder })
	add("barrel", "Ember", Vector3.new(0.2, 1.6, 1.6), accent, CFrame.new(0, 0, -3.2) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
	})
	if tier >= 3 then
		add("barrel", "HeatBand", Vector3.new(0.3, 2.35, 2.35), accent, CFrame.new(0, 0, -0.9) * ALONG_Z, {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon,
		})
	end
	return { head = head, barrel = barrel, muzzle = 3.4, accentPart = core }
end

-- 💧 น้ำ: ฐานกลมขาวน้ำเงิน · ลำกล้องยาวเรียว Glass ฟ้าใส · ลูกแก้วน้ำลอยเหนือหัว (ลอยขึ้นลงช้าๆ ฝั่ง Client)
-- ขั้น 3+: ครีบน้ำ 2 ข้าง · ขั้น 5+: ลูกแก้วเล็ก 3 ลูกโคจรรอบลูกแก้วใหญ่
local function buildWater(add: Add, accent: Color3, tier: number): Built
	add("base", "Stripe", Vector3.new(0.4, 6.2, 6.2), accent, CFrame.new(0, 3, 0) * UPRIGHT, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
	})
	local head = add("head", "Head", Vector3.new(1.6, 2.8, 2.8), Color3.fromRGB(225, 238, 250), CFrame.new(0, -0.3, 0.2) * UPRIGHT, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.SmoothPlastic,
		tint = true,
		query = true,
	})
	local orb = add("head", "Orb", Vector3.new(2, 2, 2), accent:Lerp(WHITE, 0.3), CFrame.new(0, 2, 0.3), {
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
		transparency = 0.3,
		anim = { Kind = "Bob", Speed = 1.5, Amp = 0.35 },
	})
	if tier >= 5 then
		for index = 0, 2 do
			local turn = CFrame.Angles(0, index * math.pi * 2 / 3, 0)
			add("head", "Droplet", Vector3.new(0.5, 0.5, 0.5), accent, CFrame.new(0, 2, 0.3) * turn * CFrame.new(0, 0, -1.8), {
				shape = Enum.PartType.Ball,
				material = Enum.Material.Neon,
				anim = { Kind = "Orbit", Speed = 2.5, PivotAt = Vector3.new(0, 2, 0.3), Axis = Vector3.new(0, 1, 0) },
			})
		end
	end
	local barrel = add("barrel", "Barrel", Vector3.new(5, 1, 1), accent:Lerp(WHITE, 0.4), CFrame.new(0, 0, -2.6) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Glass,
		transparency = 0.4,
	})
	add("barrel", "Ring", Vector3.new(0.3, 1.4, 1.4), accent, CFrame.new(0, 0, -4.9) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
	})
	if tier >= 3 then
		for side = -1, 1, 2 do
			add("barrel", "Fin", Vector3.new(0.15, 1, 2.2), accent, CFrame.new(side * 0.7, 0, -2) * CFrame.Angles(0, 0, side * 0.5), {
				material = Enum.Material.Neon,
				transparency = 0.2,
			})
		end
	end
	return { head = head, barrel = barrel, muzzle = 5.2, accentPart = orb }
end

-- 🪨 ดิน: หินกองซ้อน + มอสส์ + รอยแตก Neon อำพัน · ลำกล้องหินเหลี่ยม 2×2×4
-- ขั้น 3+: หินก้อนที่ 3 บนกอง · ขั้น 5+: หินลอย 3 ก้อนโคจรรอบหัว
local function buildEarth(add: Add, accent: Color3, tier: number): Built
	add("base", "Rock1", Vector3.new(6.2, 1.8, 6.2), STONE, CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(12), 0), {
		material = Enum.Material.Slate,
	})
	add("base", "Rock2", Vector3.new(4.8, 1.6, 4.8), STONE:Lerp(Color3.new(0, 0, 0), 0.12), CFrame.new(0.2, 2.5, -0.1) * CFrame.Angles(0, math.rad(-20), 0), {
		material = Enum.Material.Slate,
	})
	add("base", "Moss", Vector3.new(4.4, 0.3, 4.4), MOSS, CFrame.new(0.2, 3.4, -0.1) * CFrame.Angles(0, math.rad(-20), 0), {
		material = Enum.Material.Grass,
	})
	for index = 0, 2 do
		local turn = CFrame.Angles(0, index * math.pi * 2 / 3, 0)
		add("base", "Crack", Vector3.new(0.15, 1.4, 0.15), AMBER, turn * CFrame.new(0, 1.2, -3.12) * CFrame.Angles(0, 0, math.rad(20)), {
			material = Enum.Material.Neon,
		})
	end
	if tier >= 3 then
		add("base", "Rock3", Vector3.new(1.8, 1.4, 1.8), STONE, CFrame.new(-2, 4.1, 1.6) * CFrame.Angles(math.rad(10), math.rad(30), 0), {
			material = Enum.Material.Slate,
		})
	end
	local head = add("head", "Head", Vector3.new(3, 2.2, 3), STONE, CFrame.new(0, 0, 0.3) * CFrame.Angles(0, math.rad(8), 0), {
		material = Enum.Material.Slate,
		tint = true,
		query = true,
	})
	local crack = add("head", "Crack", Vector3.new(0.15, 1.6, 0.15), AMBER, CFrame.new(1.52, 0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), {
		material = Enum.Material.Neon,
	})
	if tier >= 5 then
		for index = 0, 2 do
			local turn = CFrame.Angles(0, index * math.pi * 2 / 3, 0)
			add("head", "Boulder", Vector3.new(0.9, 0.9, 0.9), accent, turn * CFrame.new(0, 1.6, -2.4), {
				material = Enum.Material.Slate,
				anim = { Kind = "Orbit", Speed = 1.2, PivotAt = Vector3.new(0, 1.6, 0), Axis = Vector3.new(0, 1, 0) },
			})
		end
	end
	local barrel = add("barrel", "Barrel", Vector3.new(2, 2, 4), Color3.fromRGB(105, 95, 85), CFrame.new(0, 0, -2.4), {
		material = Enum.Material.Rock,
		tint = true,
	})
	add("barrel", "Crack", Vector3.new(2.05, 0.15, 0.15), AMBER, CFrame.new(0, 0.3, -3.2), { material = Enum.Material.Neon })
	return { head = head, barrel = barrel, muzzle = 4.4, accentPart = crack }
end

-- 🌪️ ลม: ฐานสามเหลี่ยมบาง (Wedge 3 ชิ้น) โลหะเงิน · ลำกล้องคู่เรียวยาว · ใบพัด Neon เขียวมิ้นต์หมุนรอบลำกล้อง (Client)
-- ขั้น 3+: ใบพัดชุดที่ 2 ที่ปลายลำกล้อง · ขั้น 5+: ใบพัดชุดแรกเพิ่มเป็น 5 ใบ
local function buildWind(add: Add, accent: Color3, tier: number): Built
	for index = 0, 2 do
		local turn = CFrame.Angles(0, index * math.pi * 2 / 3, 0)
		add("base", "Fin", Vector3.new(0.4, 2.6, 3.2), SILVER, turn * CFrame.new(0, 1.3, -3.4) * CFrame.Angles(0, math.pi, 0), {
			shape = Enum.PartType.Wedge,
			material = Enum.Material.Metal,
		})
	end
	local head = add("head", "Head", Vector3.new(2, 1.4, 2.4), SILVER, CFrame.new(0, 0, 0.4), {
		material = Enum.Material.Metal,
		tint = true,
		query = true,
	})
	local barrel = add("barrel", "Barrel", Vector3.new(4.5, 0.6, 0.6), SILVER, CFrame.new(-0.4, 0, -2.4) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
		tint = true,
	})
	add("barrel", "Barrel2", Vector3.new(4.5, 0.6, 0.6), SILVER, CFrame.new(0.4, 0, -2.4) * ALONG_Z, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
		tint = true,
	})
	-- ใบพัด: วางรอบแกนลำกล้องที่ z = -1.2 · Orbit = หมุนรอบแกนนั้น (PivotAt = จุดบนแกน)
	local function propeller(z: number, blades: number, speed: number): BasePart?
		local first: BasePart? = nil
		for index = 0, blades - 1 do
			local turn = CFrame.Angles(0, 0, index * math.pi * 2 / blades)
			local blade = add("barrel", "Blade", Vector3.new(0.15, 1.5, 0.5), accent, CFrame.new(0, 0, z) * turn * CFrame.new(0, 1.1, 0), {
				material = Enum.Material.Neon,
				anim = { Kind = "Orbit", Speed = speed, PivotAt = Vector3.new(0, 0, z), Axis = Vector3.new(0, 0, 1) },
			})
			first = first or blade
		end
		return first
	end
	local blade = propeller(-1.2, if tier >= 5 then 5 else 3, 9)
	if tier >= 3 then
		propeller(-4, 3, -12)
	end
	return { head = head, barrel = barrel, muzzle = 4.8, accentPart = blade }
end

-- ของแต่งตามขั้นเลเวล (ทุกธาตุ): ขั้น 2+ วงแหวนสีธาตุที่ลำกล้อง · ขั้น 3+ แสงเรือง · ขั้น 4+ วงแหวนลอยรอบฐาน
--   · ขั้น 6 (Lv.50) มงกุฎเรืองแสงลอยเหนือหัว
-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนว่าขั้นไหนได้อะไร (ตัวเลข tier = ลำดับใน Elements.LookTiers)
local function tierDecor(add: Add, accent: Color3, tier: number, built: Built)
	if tier >= 2 then
		add("barrel", "TierBand", Vector3.new(0.25, 1.9, 1.9), accent, CFrame.new(0, 0, -0.4) * ALONG_Z, {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon,
			transparency = 0.1,
		})
	end
	if tier >= 3 and built.accentPart then
		glow(built.accentPart, accent, 6 + tier * 2)
	end
	if tier >= 4 then
		add("base", "TierRing", Vector3.new(0.25, 8.5, 8.5), accent, CFrame.new(0, 1.2, 0) * UPRIGHT, {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Neon,
			transparency = 0.35,
			anim = { Kind = "Bob", Speed = 1.2, Amp = 0.6 },
		})
	end
	if tier >= 6 then
		for index = 0, 4 do
			local turn = CFrame.Angles(0, index * math.pi * 2 / 5, 0)
			add("head", "Crown", Vector3.new(0.3, 0.9, 0.3), accent:Lerp(WHITE, 0.4), turn * CFrame.new(0, 2.9, -0.9), {
				material = Enum.Material.Neon,
				anim = { Kind = "Orbit", Speed = 0.8, PivotAt = Vector3.new(0, 2.9, 0), Axis = Vector3.new(0, 1, 0) },
			})
		end
	end
end

-- ===== ตารางจับคู่ ธาตุ → ฟังก์ชันปั้น + ทรงฐาน =====
-- ✏️ เพิ่มธาตุใหม่: เขียน buildXxx แล้วเพิ่มแถวที่นี่ (ชื่อ = id ใน Config/Elements) · ไม่มีแถว = ได้หน้าตา "ยังไม่เลือก"
local BUILDERS: { [string]: (Add, Color3, number) -> Built } = {
	Fire = buildFire,
	Water = buildWater,
	Earth = buildEarth,
	Wind = buildWind,
}
local BASES: { [string]: Base } = {
	Fire = { shape = Enum.PartType.Block, width = 6, color = BASALT, material = Enum.Material.Basalt },
	Water = { shape = Enum.PartType.Cylinder, width = 6, color = Color3.fromRGB(215, 232, 250), material = Enum.Material.SmoothPlastic },
	Earth = { shape = Enum.PartType.Block, width = 2.5, color = STONE, material = Enum.Material.Slate },
	Wind = { shape = Enum.PartType.Cylinder, width = 2.2, color = SILVER, material = Enum.Material.Metal },
}
local DEFAULT_BASE: Base = { shape = Enum.PartType.Cylinder, width = 6, color = PEDESTAL_COLOR, material = Enum.Material.Plastic }

-- ===== ป้ายชื่อ =====
-- ป้ายชื่อเหนือหัว (ข้อความ TurretService ใส่ใน refreshLabel) · ไกลเกิน 150 studs ไม่แสดง
local function makeLabel(parent: BasePart, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 28)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return label
end

-- ทิศหันเริ่มต้น (แนวราบไปทางบอส) ที่ตำแหน่ง at
local function facingFrame(at: Vector3, facing: Vector3): CFrame
	local flat = Vector3.new(facing.X, at.Y, facing.Z)
	return if (flat - at).Magnitude > 0.01 then CFrame.lookAt(at, flat) else CFrame.new(at)
end

-- ===== (ก) ป้อมโค้ด =====
local function buildPrototype(foot: Vector3, id: string, accent: Color3, tier: number, facing: Vector3): Look
	-- ขนาดโตตามขั้น: ขั้น 1 = 1 · ขั้น 6 = 1 + 0.06 × 5 = 1.3
	local scale = 1 + Elements.LookScalePerTier * (tier - 1)
	local model = Instance.new("Model")
	local pieces: { Piece } = {}
	local tinted: { [BasePart]: Color3 } = {}
	local add = builder(model, pieces, tinted, scale)

	-- แท่นฐาน (Pedestal) ทรงตามธาตุ · สูง (HEAD_HEIGHT − 1) × scale · ฐานแตะพื้นพอดี
	local base = BASES[id] or DEFAULT_BASE
	local height = (HEAD_HEIGHT - 1) * scale
	local width = base.width * scale
	local pedestal: Part
	if base.shape == Enum.PartType.Block then
		pedestal = newPart("Pedestal", Vector3.new(width, height, width), base.color, model)
		pedestal.CFrame = CFrame.new(foot + Vector3.new(0, height / 2, 0))
	else
		pedestal = newPart("Pedestal", Vector3.new(height, width, width), base.color, model)
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.CFrame = CFrame.new(foot + Vector3.new(0, height / 2, 0)) * UPRIGHT
	end
	pedestal.Material = base.material

	-- ปั้นตามธาตุ · ไม่รู้จัก → ป้อม "ยังไม่เลือก" (ไม่มีของแต่งตามขั้น)
	local build = BUILDERS[id]
	local built = if build then build(add, accent, tier) else buildUnchosen(add, accent, tier)
	if build then
		tierDecor(add, accent, tier, built)
	end

	-- วางชิ้นกลุ่ม base ครั้งเดียว (หันตามทิศบอสแนวราบ)
	local baseFrame = facingFrame(foot, facing)
	for _, piece in pieces do
		if piece.group == "base" then
			piece.part.CFrame = baseFrame * piece.offset
		end
	end

	model.PrimaryPart = pedestal
	return {
		model = model,
		pedestal = pedestal,
		head = built.head,
		barrel = built.barrel,
		label = makeLabel(built.head, 3.5 * scale),
		headPosition = foot + Vector3.new(0, HEAD_HEIGHT * scale, 0),
		foot = foot,
		scale = scale,
		muzzleDistance = built.muzzle * scale,
		pieces = pieces,
		tinted = tinted,
		spinAngle = 0,
		shield = nil,
		custom = false,
		key = "",
	}
end

-- ===== (ข) โมเดลที่ import เอง =====
-- หาโมเดลใน ServerStorage > TurretModels: "<ธาตุ>_<ขั้นนี้>" → ขั้นต่ำกว่าที่ใกล้สุด → "<ธาตุ>" · ไม่มี = nil
local function findTemplate(id: string, tier: number): Model?
	local folder = ServerStorage:FindFirstChild(Elements.CustomModel.Folder)
	if not folder then
		return nil
	end
	local name = if id ~= "" then id else "Unchosen"
	for index = tier, 1, -1 do
		local found = folder:FindFirstChild(`{name}_{Elements.LookTiers[index]}`)
		if found and found:IsA("Model") then
			return found
		end
	end
	local plain = folder:FindFirstChild(name)
	return if plain and plain:IsA("Model") then plain else nil
end

-- กลุ่มของชิ้นในโมเดล import: ดูชื่อตัวเองและชั้นแม่ (Model/Folder) ขึ้นไปจนถึงตัวโมเดล · ไม่ตรงชื่อไหน = base
local GROUP_NAMES: { [string]: Group } = { Base = "base", Head = "head", Barrel = "barrel", Spin = "spin" }
local function groupOf(part: Instance, root: Instance): Group
	local node: Instance? = part
	while node and node ~= root do
		local group = GROUP_NAMES[node.Name]
		if group then
			return group
		end
		node = node.Parent
	end
	return "base"
end

-- ชิ้น BasePart แรกที่ชื่อ name (ค้นทุกชั้น) หรือ BasePart แรกใน Model/Folder ชื่อ name
local function findPart(root: Instance, name: string): BasePart?
	for _, item in root:GetDescendants() do
		if item.Name == name then
			if item:IsA("BasePart") then
				return item
			end
			local inner = item:FindFirstChildWhichIsA("BasePart", true)
			if inner then
				return inner
			end
		end
	end
	return nil
end

local function buildCustom(template: Model, foot: Vector3, accent: Color3, facing: Vector3): Look?
	local model = template:Clone()
	-- ขั้น 1: ตั้งค่าความปลอดภัย/ฟิสิกส์ · ลบสคริปต์ที่ติดมากับโมเดล (กันโค้ดแปลกปลอมรันในเกม)
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ModuleScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanTouch = false
			item.CanQuery = false
			if groupOf(item, model) ~= "base" then
				item.CanCollide = false
			end
			-- Glow = สีธาตุ + เรืองแสง
			if item.Name == "Glow" then
				item.Color = accent
				item.Material = Enum.Material.Neon
			end
		end
	end
	local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
	if not anyPart then
		model:Destroy()
		warn(`[TurretLook] โมเดล {template.Name} ไม่มีชิ้นส่วน (BasePart) → ใช้ป้อมโค้ดแทน`)
		return nil
	end

	-- ขั้น 2: ย่อ/ขยายให้สูงเท่า CustomModel.Height (ถ้าตั้งไว้) · ScaleTo = ย่อขยายทั้งโมเดลพร้อมกัน [Inferred: API ปี 2023+]
	local wanted = Elements.CustomModel.Height
	if type(wanted) == "number" and wanted > 0 then
		local _, size = model:GetBoundingBox()
		if size.Y > 0.01 then
			local ok, err = pcall(function()
				model:ScaleTo(model:GetScale() * wanted / size.Y)
			end)
			if not ok then
				warn(`[TurretLook] ย่อ/ขยายโมเดล {template.Name} ไม่ได้: {err}`)
			end
		end
	end

	-- ขั้น 3: วาง "ก้นโมเดล" ลงบนแท่น · หันหน้า (-Z ของ Pivot) ไปทางบอสแนวราบ
	-- rel = ก้นโมเดลเทียบกับ Pivot · Pivot ใหม่ = จุดวาง × เลื่อนกลับ rel → ก้นโมเดลอยู่ที่ foot พอดี
	local pivot = model:GetPivot()
	local boxFrame, boxSize = model:GetBoundingBox()
	local bottom = (boxFrame * CFrame.new(0, -boxSize.Y / 2, 0)).Position
	local rel = pivot:PointToObjectSpace(bottom)
	local placed = facingFrame(foot, facing)
	model:PivotTo(placed * CFrame.new(-rel))

	-- ขั้น 4: จุดหมุนเล็ง = ชิ้น Head (ไม่มี = สูง 75% ของโมเดล) · จดทุกชิ้นที่หมุนเทียบกับจุดหมุนนั้น
	local head = findPart(model, "Head")
	local barrel = findPart(model, "Barrel")
	local pedestal = findPart(model, "Base") or model.PrimaryPart or anyPart
	local pivotPosition = if head then head.Position else foot + Vector3.new(0, boxSize.Y * 0.75, 0)
	local frame0 = CFrame.lookAt(pivotPosition, pivotPosition + placed.LookVector)
	local pieces: { Piece } = {}
	local tinted: { [BasePart]: Color3 } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local group = groupOf(item, model)
			if group ~= "base" then
				table.insert(pieces, { part = item, offset = frame0:ToObjectSpace(item.CFrame), group = group })
				if item.Name ~= "Glow" then
					tinted[item] = item.Color
				end
			end
		end
	end
	if head then
		head.CanQuery = true
	end

	-- ขั้น 5: ปากกระบอก = Attachment "Muzzle" · ไม่มี = ปลายชิ้น Barrel (ประมาณ) · ไม่มี Barrel = 4 studs
	local muzzleDistance = 4
	local muzzle = model:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		muzzleDistance = (muzzle.WorldPosition - pivotPosition).Magnitude
	elseif barrel then
		local longest = math.max(barrel.Size.X, barrel.Size.Y, barrel.Size.Z)
		muzzleDistance = (barrel.Position - pivotPosition).Magnitude + longest / 2
	end

	model.PrimaryPart = pedestal
	local labelOn = head or pedestal
	return {
		model = model,
		pedestal = pedestal,
		head = labelOn,
		barrel = barrel or labelOn,
		label = makeLabel(labelOn, 3.5),
		headPosition = pivotPosition,
		foot = foot,
		scale = math.max((pivotPosition.Y - foot.Y) / HEAD_HEIGHT, 0.5),
		muzzleDistance = math.max(muzzleDistance, 0.5),
		pieces = pieces,
		tinted = tinted,
		spinAngle = 0,
		shield = nil,
		custom = true,
		key = "",
	}
end

-- ===== API ให้ TurretService เรียก =====
local TurretLook = {}

TurretLook.HEAD_HEIGHT = HEAD_HEIGHT

-- คีย์หน้าตา: "ธาตุ|ขั้นหน้าตา|ขั้นสีไฟ" (ElementMath.lookKey) · ต่าง = TurretService ปั้นใหม่
function TurretLook.keyOf(element: string, level: number): string
	return ElementMath.lookKey(element, level)
end

-- เล็งเป้า: หัวหมุนแนวราบ · ลำกล้องหันตรงไปที่เป้า · กลุ่ม spin หมุนเพิ่มทีละขั้น · กลุ่ม base ไม่ขยับ
function TurretLook.aim(look: Look, target: Vector3)
	local pivot = look.headPosition
	local flat = Vector3.new(target.X, pivot.Y, target.Z)
	local yaw = if (flat - pivot).Magnitude > 0.01 then CFrame.lookAt(pivot, flat) else nil
	local full = if (target - pivot).Magnitude > 0.01 then CFrame.lookAt(pivot, target) else yaw
	-- % (2π) = วนกลับเป็น 0 เมื่อครบรอบ (ตัวเลขไม่โตไปเรื่อยๆ)
	look.spinAngle = (look.spinAngle + SPIN_STEP) % (2 * math.pi)
	local roll = CFrame.Angles(0, 0, look.spinAngle)
	for _, piece in look.pieces do
		if piece.group == "head" then
			if yaw then
				piece.part.CFrame = yaw * piece.offset
			end
		elseif piece.group == "barrel" or piece.group == "spin" then
			if full then
				piece.part.CFrame = if piece.group == "spin" then full * roll * piece.offset else full * piece.offset
			end
		end
	end
end

-- ช็อต = ชิ้นหลักกลายเป็นสีเทา · ฟื้น = สีเดิม
function TurretLook.setStunned(look: Look, stunned: boolean)
	for part, color in look.tinted do
		part.Color = if stunned then STUNNED_COLOR else color
	end
end

-- เกราะหิน (สกิลดิน): กล่องหินโปร่งครอบป้อม · on = false → ลบ
function TurretLook.setShield(look: Look, on: boolean)
	if on and not look.shield then
		local height = HEAD_HEIGHT * look.scale + 3
		local box = newPart("StoneShield", Vector3.new(8, 0, 8) * math.max(look.scale, 1) + Vector3.new(0, height, 0), SHIELD_COLOR, look.model)
		box.Material = Enum.Material.Slate
		box.Transparency = 0.6
		box.CanCollide = false
		box.CanQuery = false
		box.CastShadow = false
		box.CFrame = CFrame.new(look.foot + Vector3.new(0, height / 2, 0))
		look.shield = box
	elseif not on and look.shield then
		look.shield:Destroy()
		look.shield = nil
	end
end

-- จุดปากกระบอกในโลก: จากหัวป้อมไปทางเป้า muzzleDistance studs
function TurretLook.muzzleOf(look: Look, target: Vector3): Vector3
	local direction = target - look.headPosition
	if direction.Magnitude < 0.01 then
		return look.headPosition
	end
	return look.headPosition + direction.Unit * look.muzzleDistance
end

-- สร้างป้อมที่ฐาน foot (ระดับพื้น) · หันไปที่ facing · ยังไม่ใส่ Parent (TurretService ใส่เอง)
function TurretLook.build(foot: Vector3, element: string, level: number, facing: Vector3): Look
	-- ขั้น 1: ธาตุที่ใช้ได้จริง · สี · ขั้นหน้าตา (1..6)
	local stats = ElementMath.stats(element, level)
	local tier = ElementMath.lookTier(level)
	-- ขั้น 2: มีโมเดล import → ใช้ · ไม่มี/ใช้ไม่ได้ → ป้อมโค้ด
	local template = findTemplate(stats.Id, tier)
	local look = if template then buildCustom(template, foot, stats.Color, facing) else nil
	if not look then
		look = buildPrototype(foot, stats.Id, stats.Color, tier, facing)
	end
	local result = look :: Look
	result.key = TurretLook.keyOf(element, level)
	-- ขั้น 3: เล็งไปทางบอสครั้งแรก (จัดทุกชิ้นให้เข้าที่)
	TurretLook.aim(result, Vector3.new(facing.X, result.headPosition.Y, facing.Z))
	return result
end

return TurretLook
