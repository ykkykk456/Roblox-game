-- ประกอบแมพตอน Server เริ่ม (เจ้าของ: World_Builder)
-- พื้น/แอ่ง/ถนน/ขอบ = Workspace.MapGround (Rojo sync จาก map/ground.project.json · สร้างด้วย tools/gen_map.py)
--   → เห็นในโหมดแก้ไขของ Studio · โค้ดนี้แค่ติด tag LootZone ให้บล็อกในแอ่ง และเพิ่มกำแพงใสรอบขอบ
-- ฐาน (ลานฐาน บ้าน ป้าย spawn สวนหลังบ้าน) = สร้างตอนเกมรันตาม Config/Map · ของตกแต่งสร้างมือใน Studio ได้
-- ชิ้นที่ระบบอื่นต้องหาเจอ ติด tag จาก Config/Tags + Attribute "BaseSlot"
-- สไตล์บล็อก (ยืนยัน 2026-09-25/26): ผิวบน Studs + สีบล็อก · ใส่ texture ภาพได้ถ้าตั้ง Map.Style.TextureAssetId
--
-- มี 2 โหมด (เลือกเองอัตโนมัติ):
--   • แมพสร้างมือ (เจอ Tag BossSpawn/Turret1-6 → LayoutService.hasLayout()) → สร้างแค่จุดเกิดล่องหนหน้าบ้าน
--   • ผังวงกลมเดิม (ไม่เจอ Tag) → สร้างฐานครบชุดด้วย buildBase ตาม Config/Map
-- อยากปรับ:
--   • ขนาดแมพ / แอ่ง / ถนน → src/shared/Config/Map.luau (Radius / Pit / Road) แล้วรัน python3 tools/gen_map.py ให้พื้นตรงกัน
--   • ตำแหน่ง/ขนาดฐาน · จำนวนฐาน · สีฐาน → Config/Map.luau (Base / BaseCount / SlotColors)
--   • สีพื้น/บ้าน / ภาพลายบล็อก → Config/Map.luau (Style) · สีของชิ้นอื่นในฐาน → ตาราง COLORS ด้านล่าง
--   • ตำแหน่งของในฐาน (จุดขาย กล่องกระสุน ฯลฯ) → ตัวเลข atPad(...) ใน buildBase
-- คุยกับ: LayoutService (ผังจาก Tag) · BaseService (เรียก spawnOf) · Util/MapMath (คำนวณพิกัดฐาน) · Config/Tags (ชื่อ tag)
-- ห้ามแก้: ชื่อ tag / Attribute "BaseSlot" ที่ติดให้ชิ้นในฐาน — ระบบอื่น (ขายของ กระสุน อัปเกรด) หาชิ้นด้วยสิ่งนี้

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)
local LayoutService = require(script.Parent.LayoutService)

-- ===== ค่าคงที่ =====
-- สีของชิ้นในฐาน (ผังวงกลม) · แก้ได้ปลอดภัย · Color3.fromRGB(แดง, เขียว, น้ำเงิน) ค่า 0–255
local COLORS = {
	Floor = Map.Style.Floor,
	PadFloor = Color3.fromRGB(233, 227, 211),
	Wall = Map.Style.House,
	Crate = Color3.fromRGB(154, 106, 60),
	Sell = Color3.fromRGB(245, 207, 69),
	Post = Color3.fromRGB(70, 74, 86),
	Altar = Color3.fromRGB(138, 60, 200),
}

-- ===== สถานะ =====
-- folder = โฟลเดอร์ workspace.Map ที่สร้างแล้ว (nil = ยังไม่สร้าง) · spawns[ช่อง] = SpawnLocation ของช่องนั้น
local folder: Folder? = nil
local spawns: { [number]: SpawnLocation } = {}

-- ===== ตัวช่วยสร้างชิ้น =====
-- สร้าง Part ยึดอยู่กับที่ (Anchored) ขนาด/ตำแหน่ง/สีตามที่ส่งมา แล้วใส่ใน parent · คืน Part นั้น
-- CanTouch = false ไว้ก่อน (ประหยัดการคำนวณ) · ชิ้นที่ต้องแตะได้ให้เรียก tag() เพิ่ม
local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- ใส่ texture ลายบล็อกบนหน้าที่ระบุ (ข้ามเมื่อยังไม่ได้ตั้ง TextureAssetId)
local function texture(part: BasePart, faces: { Enum.NormalId })
	local style = Map.Style
	if style.TextureAssetId == 0 then
		return
	end
	for _, face in faces do
		local decal = Instance.new("Texture")
		decal.Texture = `rbxassetid://{style.TextureAssetId}`
		decal.Face = face
		decal.StudsPerTileU = style.StudsPerTile
		decal.StudsPerTileV = style.StudsPerTile
		decal.Parent = part
	end
end

-- ทุกหน้ายกเว้นด้านล่าง (ใช้กับบ้าน)
local ALL_SIDES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- ติด tag ให้ระบบอื่นหาเจอ + เปิดให้แตะได้ + จดว่าเป็นของฐานไหน (Attribute "BaseSlot")
local function tag(part: BasePart, tagName: string, slot: number?)
	CollectionService:AddTag(part, tagName)
	part.CanTouch = true
	if slot then
		part:SetAttribute("BaseSlot", slot)
	end
end

-- แถบวงแหวน (หรือบางส่วนของวง a0..a1) จากชิ้นสี่เหลี่ยมเรียงรอบกลางแมพ · ผิวบนอยู่ที่ topY
local function ring(
	parent: Instance,
	name: string,
	r0: number,
	r1: number,
	topY: number,
	height: number,
	color: Color3,
	a0: number?,
	a1: number?,
	count: number?
): { Part }
	local from = a0 or 0
	local to = a1 or 2 * math.pi
	local pieces = count or Map.Segments
	local step = (to - from) / pieces
	local length = 2 * r1 * math.tan(step / 2) + 0.2 -- ชนกันพอดีที่ขอบนอก ไม่มีช่องว่าง
	local parts = {}
	for k = 0, pieces - 1 do
		local out = MapMath.polar(from + (k + 0.5) * step, 1)
		local center = out * ((r0 + r1) / 2) + Vector3.new(0, topY - height / 2, 0)
		local size = Vector3.new(length, height, r1 - r0)
		table.insert(parts, block(parent, name, size, CFrame.lookAt(center, center + out), color))
	end
	return parts
end

-- ชิ้นที่ค้างจาก Rojo รุ่นเก่า (หญ้า/Baseplate) — ลบตอนเกมรัน · ต้องลบใน Studio เองด้วยถึงจะหายถาวร
-- ===== พื้นแมพ =====
local LEGACY = { "Grass", "Baseplate" }

-- ลบชิ้นเก่าในรายการ LEGACY ออกจาก workspace ตอนรัน (พร้อมเตือนให้ลบใน Studio)
local function cleanupLegacy()
	for _, name in LEGACY do
		local old = workspace:FindFirstChild(name)
		if old and old:IsA("BasePart") then
			warn(`[MapService] ลบชิ้นเก่า workspace.{name} (ลบใน Studio ด้วย: Explorer → Workspace → {name} → Delete แล้ว Save)`)
			old:Destroy()
		end
	end
end

-- พื้นสำรองเมื่อไม่มี MapGround (เช่น ลืม sync Rojo) — แผ่นเรียบแผ่นเดียว กันผู้เล่นตก
local function buildFallbackFloor(parent: Instance)
	warn("[MapService] ไม่พบ workspace.MapGround — ใช้พื้นเรียบชั่วคราว (เปิด rojo serve แล้ว Connect ใหม่)")
	local size = Map.Radius * 2
	block(parent, "FallbackFloor", Vector3.new(size, 2, size), CFrame.new(0, Map.GroundY - 1, 0), COLORS.Floor)
end

-- เตรียมพื้น: ติด tag LootZone ให้บล็อกในแอ่ง · ไม่มี MapGround → ใช้พื้นสำรอง · เพิ่มกำแพงใสรอบขอบ
local function buildGround(parent: Instance)
	cleanupLegacy()
	local ground = workspace:FindFirstChild("MapGround")
	if ground then
		-- บล็อกในแอ่งกลางแมพ = พื้นที่เก็บของ (ชื่อขึ้นต้น "Pit_" จาก tools/gen_map.py)
		local farthest = 0
		for _, part in ground:GetChildren() do
			if part:IsA("BasePart") then
				farthest = math.max(farthest, Vector3.new(part.Position.X, 0, part.Position.Z).Magnitude)
				if string.sub(part.Name, 1, 4) == "Pit_" then
					CollectionService:AddTag(part, Tags.LootZone)
				end
			end
		end
		-- พื้นใน Studio ไม่ตรงกับ Config (ยังไม่ได้ sync รุ่นใหม่) → เตือนให้รีสตาร์ท Rojo
		if math.abs(farthest - Map.Radius) > Map.Tile * 2 then
			warn(
				`[MapService] MapGround ใน Studio ขอบไกลสุด {math.floor(farthest)} แต่ Config/Map.Radius = {Map.Radius} — พื้นยังเป็นรุ่นเก่า: ปิด rojo serve แล้วเปิดใหม่ + กด Connect`
			)
		end
	else
		buildFallbackFloor(parent)
	end

	-- กำแพงใสสูงรอบขอบแมพ กันผู้เล่นกระโดดข้ามกำแพงเตี้ยตกขอบ
	for _, part in ring(parent, "EdgeBarrier", Map.Radius - 2, Map.Radius, Map.GroundY + 30, 30, COLORS.Floor) do
		part.Transparency = 1
		part.CanQuery = false
		part.CastShadow = false
	end
end

-- ===== ฐานผู้เล่น (ผังวงกลม ใช้เมื่อแมพไม่มี Tag) =====
-- สร้างฐานช่อง slot ครบชุด: ลาน · บ้าน+หลังคา+ป้ายชื่อ · จุดขาย · กล่องกระสุน · ป้ายอัปเกรด · แท่นเรียก · จุดเกิด · สวนหลังบ้าน
-- out = ทิศพุ่งออกจากกลางแมพไปทางฐานนี้
local function buildBase(parent: Instance, slot: number)
	local color = Map.SlotColors[slot]
	local base, g = Map.Base, Map.GroundY
	local out = MapMath.axes(slot)
	local model = Instance.new("Model")
	model.Name = `Base_{slot}`
	model:SetAttribute("BaseSlot", slot)

	-- ตำแหน่งในฐาน หันหน้าเข้าหาหลุม (แกน Z ของชิ้น = แนวรัศมี)
	local function at(u: number, v: number, y: number): CFrame
		local position = MapMath.point(slot, u, v, y)
		return CFrame.lookAt(position, position - out)
	end

	-- ตำแหน่งของในฐาน วัดจากกลางลานฐาน (du = ไปทางหลุม −/ออกนอก + · dv = ขวา) · ระยะขยายตามขนาดลาน (ออกแบบไว้ที่ลาน 44)
	local layoutScale = base.Size / 44
	local function atPad(du: number, dv: number, y: number): CFrame
		return at(base.Distance + du * layoutScale, dv * layoutScale, y)
	end

	-- ลานฐาน: ขอบสีประจำฐาน + พื้นลานสีอ่อนทับด้านบน · padTop = ความสูงผิวลาน (ใช้วางของทุกชิ้นด้านล่าง)
	local padTop = g + 0.45
	block(model, "PadEdge", Vector3.new(base.Size, 0.4, base.Size), at(base.Distance, 0, g + 0.2), color)
	local padFloor =
		block(model, "PadFloor", Vector3.new(base.Size - 4, 0.45, base.Size - 4), at(base.Distance, 0, g + 0.225), COLORS.PadFloor)
	padFloor.TopSurface = Enum.SurfaceType.Studs
	texture(padFloor, { Enum.NormalId.Top })

	-- บ้าน + หลังคาสีฐาน + ป้าย "ฐาน N" ลอยเหนือหลังคา (เห็นไม่เกิน 250 studs)
	local house = block(model, "House", Vector3.new(14, 9, 14), atPad(10, -10, padTop + 4.5), COLORS.Wall)
	house.TopSurface = Enum.SurfaceType.Studs
	house.FrontSurface = Enum.SurfaceType.Studs
	house.BackSurface = Enum.SurfaceType.Studs
	house.LeftSurface = Enum.SurfaceType.Studs
	house.RightSurface = Enum.SurfaceType.Studs
	texture(house, ALL_SIDES)
	local roof = block(model, "Roof", Vector3.new(16, 3, 16), house.CFrame + Vector3.new(0, 6, 0), color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 250
	gui.Parent = roof
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = `ฐาน {slot}`
	label.Parent = gui

	-- ของที่ระบบอื่นใช้ (ติด tag): จุดขาย · กล่องกระสุน · ป้ายอัปเกรด (เสา + ป้าย) · แท่นเรียก
	tag(block(model, "SellPad", Vector3.new(8, 0.3, 8), atPad(-8, -12, padTop + 0.15), COLORS.Sell), Tags.SellPad, slot)
	tag(block(model, "AmmoCrate", Vector3.new(4, 3, 4), atPad(-19, -8, padTop + 1.5), COLORS.Crate), Tags.AmmoCrate, slot)
	block(model, "UpgradePost", Vector3.new(1, 5, 1), atPad(-16, -17, padTop + 2.5), COLORS.Post)
	tag(block(model, "UpgradeBoard", Vector3.new(5, 3.5, 0.6), atPad(-16, -17, padTop + 5.5), color), Tags.UpgradeBoard, slot)
	tag(block(model, "SummonAltar", Vector3.new(6, 2, 6), atPad(16, 3, padTop + 1), COLORS.Altar), Tags.SummonAltar, slot)

	-- จุดเกิดของฐานนี้ · Duration = 0 = ไม่มีเกราะกันดาเมจตอนเกิด · Neutral = ทุกคนเกิดได้ (BaseService ตั้ง RespawnLocation ให้เอง)
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(6, 1, 6)
	spawnPad.CFrame = atPad(-6, 3, padTop + 0.5)
	spawnPad.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
	spawnPad.Material = Enum.Material.Plastic
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Duration = 0
	spawnPad.Neutral = true
	spawnPad.Parent = model
	spawns[slot] = spawnPad

	-- สวนหลังบ้าน: วงแหวนบางส่วนหลังฐาน กว้าง ±Yard.HalfAngle
	local angle = MapMath.angle(slot)
	local yard = Map.Yard
	local yardColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
	for _, part in ring(model, "Yard", yard.Inner, yard.Outer, g + 0.05, 2, yardColor, angle - yard.HalfAngle, angle + yard.HalfAngle, 6) do
		tag(part, Tags.MonsterYard, slot)
		part.CanTouch = false
	end

	model.Parent = parent
end

-- ===== API =====
local MapService = {}

-- สร้างแมพครั้งเดียว (เรียกซ้ำได้) · ระบบอื่นเรียกก่อนใช้ตำแหน่งในแมพ
function MapService.ensureBuilt()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	folder = root
	buildGround(root)
	if LayoutService.hasLayout() then
		-- แมพสร้างมือ (Tag): ไม่สร้างฐานเก่า · มีแค่จุดเกิดล่องหนหน้าบ้านแต่ละหลัง (ยืนยัน 2026-09-27)
		for _, slot in LayoutService.slots() do
			local spawnPad = Instance.new("SpawnLocation")
			spawnPad.Name = `Spawn{slot}`
			spawnPad.Anchored = true
			spawnPad.CanCollide = false
			spawnPad.CanTouch = false
			spawnPad.CanQuery = false
			spawnPad.Transparency = 1
			spawnPad.Size = Vector3.new(6, 1, 6)
			spawnPad.Position = LayoutService.spawnPoint(slot) + Vector3.new(0, 0.5, 0)
			spawnPad.Duration = 0
			spawnPad.Neutral = true
			spawnPad.Parent = root
			spawns[slot] = spawnPad
		end
	else
		for slot = 1, math.min(Map.BaseCount, Map.MaxBases) do
			buildBase(root, slot)
		end
	end
	root.Parent = workspace

	-- เช็ก SpawnLocation ที่ไม่ได้มาจากโค้ดนี้ (เช่น ที่ Studio ใส่มาให้) — อาจทำให้เกิดผิดที่
	for _, other in workspace:GetDescendants() do
		if other:IsA("SpawnLocation") and not other:IsDescendantOf(root) then
			warn(`[MapService] เจอ SpawnLocation เก่าที่ {other:GetFullName()} — ผู้เล่นอาจเกิดผิดที่ ลบออกใน Studio ได้`)
		end
	end
end

-- คืน SpawnLocation ของช่อง slot (สร้างแมพให้ก่อนถ้ายัง) · nil ถ้าช่องนั้นไม่มี · BaseService เรียกตอนแจกบ้าน
function MapService.spawnOf(slot: number): SpawnLocation?
	MapService.ensureBuilt()
	return spawns[slot]
end

-- ===== ยึดแมพกันร่วง (Anchored) =====
-- ล็อกแมพที่สร้างมือใน Studio ไม่ให้ร่วงตอนรัน (ตอนแก้งานฟิสิกส์ยังไม่ทำงาน ของที่ลืม Anchored จึงดูปกติ)
-- ข้าม: ตัวละคร/บอส/ริก (Humanoid, AnimationController, HumanoidRootPart, ข้อต่อ, ชื่อใน Combat.Boss.Rotation) · โฟลเดอร์ที่โค้ดสร้างเอง · attribute Physics = true
-- ยึดถาวรในไฟล์เกม: รัน tools/studio/anchor_map.lua ใน Command Bar
-- โฟลเดอร์ที่โค้ดสร้างเองตอนรัน → ไม่ต้องยึด (มีทั้งของที่ต้องขยับได้)
local RUNTIME_FOLDERS = { Map = true, Monsters = true, Turrets = true }

-- ริก = โมเดลที่ขยับได้ (ตัวละคร/บอส) ห้ามยึด
-- ทำชื่อให้เทียบง่าย: ตัวเล็ก ตัดสัญลักษณ์/ช่องว่าง ตัดคำว่า "boss" (เช่น "Boss_Slambot" → "slambot")
local function simpleName(name: string): string
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end

-- true ถ้าโมเดลเป็นตัวละคร/บอส/ริก: ชื่อตรงกับบอสใน Combat.Boss.Rotation · มี Humanoid/AnimationController/HumanoidRootPart · มีข้อต่อ
local function isRig(model: Model): boolean
	for _, entry in Combat.Boss.Rotation do
		if simpleName(model.Name) == simpleName(entry.Model) then
			return true
		end
	end
	if
		model:FindFirstChildWhichIsA("Humanoid", true)
		or model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChild("HumanoidRootPart", true)
	then
		return true
	end
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("Bone") or item:IsA("AnimationConstraint") then
			return true
		end
	end
	return false
end

-- true ถ้าชิ้นนี้อยู่ในโมเดลที่เป็นริก (ไล่ขึ้นไปทีละชั้นจนถึง workspace)
local function isCharacterPart(part: BasePart): boolean
	local node = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and isRig(node) then
			return true
		end
		node = node.Parent
	end
	return false
end

-- ยึดทุกชิ้นใน workspace ที่ยังไม่ Anchored ยกเว้น: โฟลเดอร์ runtime · Attribute Physics = true · ชิ้นของริก
-- top = โฟลเดอร์/โมเดลชั้นบนสุดใต้ workspace ที่ชิ้นนี้อยู่
local function anchorMap()
	local count = 0
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") and not item.Anchored and not item:IsA("Terrain") then
			local top = item
			while top.Parent and top.Parent ~= workspace do
				top = top.Parent
			end
			if not RUNTIME_FOLDERS[top.Name] and item:GetAttribute("Physics") ~= true and not isCharacterPart(item) then
				item.Anchored = true
				count += 1
			end
		end
	end
	if count > 0 then
		print(
			`[MapService] ยึด (Anchored) ชิ้นในแมพที่ยังไม่ได้ยึด {count} ชิ้น กันร่วงตอนรัน · ยึดถาวรได้ด้วย tools/studio/anchor_map.lua`
		)
	end
end

-- เรียกตอนเซิร์ฟเวอร์เริ่ม: ยึดแมพก่อน แล้วสร้างพื้น/ฐาน/จุดเกิด
function MapService.Init()
	anchorMap()
	MapService.ensureBuilt()
end

return MapService
