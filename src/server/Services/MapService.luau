-- สร้างแมพหลุมอุกกาบาตจาก Config/Map ตอน Server เริ่ม (เจ้าของ: World_Builder)
-- โค้ดสร้างเฉพาะของที่วางตามกฎ (พื้น หลุม วงแหวน ฐาน) · ของตกแต่งฉากให้สร้างมือใน Studio ได้เลย
-- ชิ้นที่ระบบอื่นต้องหาเจอ ติด tag จาก Config/Tags + Attribute "BaseSlot"
-- [Proposed] greybox: บล็อกสีเรียบ SmoothPlastic ทั้งหมด ไม่มี texture

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)

local COLORS = {
	Grass = Color3.fromRGB(107, 191, 78),
	Loot = Color3.fromRGB(196, 232, 164),
	Rim = Color3.fromRGB(140, 125, 104),
	PitFloor = Color3.fromRGB(120, 106, 88),
	PadFloor = Color3.fromRGB(233, 227, 211),
	Wall = Color3.fromRGB(247, 241, 227),
	Lane = Color3.fromRGB(176, 138, 92),
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
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.Parent = parent
	return part
end

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

local function buildGround(parent: Instance)
	local g, half = Map.GroundY, Map.FloorSize / 2
	-- พื้นหญ้า 4 แผ่นเว้นช่องสี่เหลี่ยมตรงกลาง แล้วเติมด้วยวงแหวนหญ้าจนมุมสี่เหลี่ยม
	local hole = Map.LootRing.Outer + 6
	local side = half - hole
	local y = g - 1
	block(parent, "Floor", Vector3.new(Map.FloorSize, 2, side), CFrame.new(0, y, -(hole + side / 2)), COLORS.Grass)
	block(parent, "Floor", Vector3.new(Map.FloorSize, 2, side), CFrame.new(0, y, hole + side / 2), COLORS.Grass)
	block(parent, "Floor", Vector3.new(side, 2, hole * 2), CFrame.new(-(hole + side / 2), y, 0), COLORS.Grass)
	block(parent, "Floor", Vector3.new(side, 2, hole * 2), CFrame.new(hole + side / 2, y, 0), COLORS.Grass)
	ring(parent, "Floor", Map.LootRing.Outer, hole * math.sqrt(2) + 2, g, 2, COLORS.Grass)

	for _, part in ring(parent, "LootRing", Map.LootRing.Inner, Map.LootRing.Outer, g + 0.05, 2, COLORS.Loot) do
		tag(part, Tags.LootZone)
		part.CanTouch = false -- ใช้หาโซนเท่านั้น ไม่ต้องรับการชน
	end

	-- ขอบหินรอบปากหลุม ยาวลงไปถึงก้นหลุม = ผนังหลุม
	local pit = Map.Pit
	local rimTop = g + 0.25
	local bottom = g - pit.Depth
	ring(parent, "PitRim", pit.Radius, pit.Radius + pit.RimWidth, rimTop, rimTop - bottom, COLORS.Rim)

	local floor = block(
		parent,
		"PitFloor",
		Vector3.new(1, pit.Radius * 2 + 2, pit.Radius * 2 + 2),
		CFrame.new(0, bottom - 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.PitFloor
	)
	floor.Shape = Enum.PartType.Cylinder

	-- กำแพงใสกันผู้เล่นตกหลุม (ตกแล้วปีนขึ้นไม่ได้) · มอนกับบอสไม่ชนอยู่แล้ว
	for _, part in ring(parent, "PitBarrier", pit.Radius - 1, pit.Radius, rimTop + 10, 10, COLORS.Rim) do
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

	local padTop = g + 0.45
	block(model, "PadEdge", Vector3.new(base.Size, 0.4, base.Size), at(base.Distance, 0, g + 0.2), color)
	block(model, "PadFloor", Vector3.new(base.Size - 4, 0.45, base.Size - 4), at(base.Distance, 0, g + 0.225), COLORS.PadFloor)

	-- ทางมอน: จากปากสวนหลังบ้านเลียบข้างลานฐานไปถึงจุดที่มอนหายไป
	local lane = Map.MonsterLane
	local laneLength = Map.Yard.Inner - lane.End
	block(model, "MonsterLane", Vector3.new(8, 0.5, laneLength), at(lane.End + laneLength / 2, lane.Side, g + 0.25), COLORS.Lane)

	local house = block(model, "House", Vector3.new(14, 9, 14), at(90, -10, padTop + 4.5), COLORS.Wall)
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

	tag(block(model, "SellPad", Vector3.new(8, 0.3, 8), at(72, -12, padTop + 0.15), COLORS.Sell), Tags.SellPad, slot)
	tag(block(model, "AmmoCrate", Vector3.new(4, 3, 4), at(61, -8, padTop + 1.5), COLORS.Crate), Tags.AmmoCrate, slot)
	block(model, "UpgradePost", Vector3.new(1, 5, 1), at(64, -17, padTop + 2.5), COLORS.Post)
	tag(block(model, "UpgradeBoard", Vector3.new(5, 3.5, 0.6), at(64, -17, padTop + 5.5), color), Tags.UpgradeBoard, slot)
	tag(block(model, "SummonAltar", Vector3.new(6, 2, 6), at(96, 3, padTop + 1), COLORS.Altar), Tags.SummonAltar, slot)

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(6, 1, 6)
	spawnPad.CFrame = at(74, 3, padTop + 0.5)
	spawnPad.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
	spawnPad.Material = Enum.Material.SmoothPlastic
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

function MapService.Init()
	MapService.ensureBuilt()
end

return MapService
