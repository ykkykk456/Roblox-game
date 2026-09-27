-- ประกอบแมพตอน Server เริ่ม (เจ้าของ: World_Builder)
-- พื้น/แอ่ง/ถนน/ขอบ = Workspace.MapGround (Rojo sync จาก map/ground.project.json · สร้างด้วย tools/gen_map.py)
--   → เห็นในโหมดแก้ไขของ Studio · โค้ดนี้แค่ติด tag LootZone ให้บล็อกในแอ่ง และเพิ่มกำแพงใสรอบขอบ
-- ฐาน (ลานฐาน บ้าน ป้าย spawn สวนหลังบ้าน) = สร้างตอนเกมรันตาม Config/Map · ของตกแต่งสร้างมือใน Studio ได้
-- ชิ้นที่ระบบอื่นต้องหาเจอ ติด tag จาก Config/Tags + Attribute "BaseSlot"
-- สไตล์บล็อก (ยืนยัน 2026-09-25/26): ผิวบน Studs + สีบล็อก · ใส่ texture ภาพได้ถ้าตั้ง Map.Style.TextureAssetId

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)

local COLORS = {
	Floor = Map.Style.Floor,
	PadFloor = Color3.fromRGB(233, 227, 211),
	Wall = Map.Style.House,
	Crate = Color3.fromRGB(154, 106, 60),
	Sell = Color3.fromRGB(245, 207, 69),
	Post = Color3.fromRGB(70, 74, 86),
	Altar = Color3.fromRGB(138, 60, 200),
}

local folder: Folder? = nil
local spawns: { [number]: SpawnLocation } = {}

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

local ALL_SIDES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

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
local LEGACY = { "Grass", "Baseplate" }

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

	local padTop = g + 0.45
	block(model, "PadEdge", Vector3.new(base.Size, 0.4, base.Size), at(base.Distance, 0, g + 0.2), color)
	local padFloor =
		block(model, "PadFloor", Vector3.new(base.Size - 4, 0.45, base.Size - 4), at(base.Distance, 0, g + 0.225), COLORS.PadFloor)
	padFloor.TopSurface = Enum.SurfaceType.Studs
	texture(padFloor, { Enum.NormalId.Top })

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

	tag(block(model, "SellPad", Vector3.new(8, 0.3, 8), atPad(-8, -12, padTop + 0.15), COLORS.Sell), Tags.SellPad, slot)
	tag(block(model, "AmmoCrate", Vector3.new(4, 3, 4), atPad(-19, -8, padTop + 1.5), COLORS.Crate), Tags.AmmoCrate, slot)
	block(model, "UpgradePost", Vector3.new(1, 5, 1), atPad(-16, -17, padTop + 2.5), COLORS.Post)
	tag(block(model, "UpgradeBoard", Vector3.new(5, 3.5, 0.6), atPad(-16, -17, padTop + 5.5), color), Tags.UpgradeBoard, slot)
	tag(block(model, "SummonAltar", Vector3.new(6, 2, 6), atPad(16, 3, padTop + 1), COLORS.Altar), Tags.SummonAltar, slot)

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

	local angle = MapMath.angle(slot)
	local yard = Map.Yard
	local yardColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
	for _, part in ring(model, "Yard", yard.Inner, yard.Outer, g + 0.05, 2, yardColor, angle - yard.HalfAngle, angle + yard.HalfAngle, 6) do
		tag(part, Tags.MonsterYard, slot)
		part.CanTouch = false
	end

	model.Parent = parent
end

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
	for slot = 1, math.min(Map.BaseCount, Map.MaxBases) do
		buildBase(root, slot)
	end
	root.Parent = workspace

	for _, other in workspace:GetDescendants() do
		if other:IsA("SpawnLocation") and not other:IsDescendantOf(root) then
			warn(`[MapService] เจอ SpawnLocation เก่าที่ {other:GetFullName()} — ผู้เล่นอาจเกิดผิดที่ ลบออกใน Studio ได้`)
		end
	end
end

function MapService.spawnOf(slot: number): SpawnLocation?
	MapService.ensureBuilt()
	return spawns[slot]
end

-- ล็อกแมพที่สร้างมือใน Studio ไม่ให้ร่วงตอนรัน (ตอนแก้งานฟิสิกส์ยังไม่ทำงาน ของที่ลืม Anchored จึงดูปกติ)
-- ข้าม: ตัวละคร/บอส/ริก (Humanoid, AnimationController, HumanoidRootPart, ข้อต่อ, ชื่อใน Combat.Boss.Rotation) · โฟลเดอร์ที่โค้ดสร้างเอง · attribute Physics = true
-- ยึดถาวรในไฟล์เกม: รัน tools/studio/anchor_map.lua ใน Command Bar
local RUNTIME_FOLDERS = { Map = true, Monsters = true, Turrets = true }

-- ริก = โมเดลที่ขยับได้ (ตัวละคร/บอส) ห้ามยึด
local function simpleName(name: string): string
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end

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

function MapService.Init()
	anchorMap()
	MapService.ensureBuilt()
end

return MapService
