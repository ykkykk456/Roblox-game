-- ผังแมพจากบล็อกที่ติด Tag ใน Studio (เจ้าของ: World_Builder) · ยืนยัน 2026-09-27
-- Tag: BossSpawn = จุดบอส · Turret1..6 = แท่นป้อม · House1..6 = บ้าน (เลขเดียวกันคู่กัน) · ไม่มี Tag แต่ชื่อบล็อกตรงก็ใช้ได้
-- อ่านอย่างเดียว ไม่แก้บล็อกของแมพ (ยกเว้น Map.Layout.HideBossMarker ทำ BossSpawn โปร่งใสตอนรัน)
-- ไม่เจอ Tag → hasLayout() = false → ระบบอื่นใช้ผังวงกลมเดิมจาก Config/Map
-- โหลดครั้งแรกที่มีคนเรียก (ไม่พึ่งลำดับ Init)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)

local loaded = false
local bossMarker: Instance? = nil
local turretMarkers: { [number]: Instance } = {}
local houseMarkers: { [number]: Instance } = {}
local slotList: { number } = {}

-- กล่องครอบ (ใช้ได้ทั้ง Part และ Model)
local function boxOf(item: Instance): (CFrame, Vector3)
	if item:IsA("BasePart") then
		return item.CFrame, item.Size
	elseif item:IsA("Model") then
		return item:GetBoundingBox()
	end
	return CFrame.new(), Vector3.zero
end

local function topY(item: Instance): number
	local cf, size = boxOf(item)
	local half = size / 2
	local highest = -math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				highest = math.max(highest, (cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
			end
		end
	end
	return highest
end

local function find(name: string): Instance?
	local found = {}
	for _, item in CollectionService:GetTagged(name) do
		if item:IsDescendantOf(workspace) then
			table.insert(found, item)
		end
	end
	if #found == 0 then
		local byName = workspace:FindFirstChild(name, true)
		if byName then
			table.insert(found, byName)
		end
	end
	if #found > 1 then
		warn(`[LayoutService] Tag {name} ติดอยู่ {#found} ชิ้น — ใช้ชิ้นแรก ({found[1]:GetFullName()}) ควรติดชิ้นเดียว`)
	end
	return found[1]
end

local function load()
	if loaded then
		return
	end
	loaded = true
	bossMarker = find(Tags.BossSpawn)
	for n = 1, Map.Layout.MaxSlots do
		turretMarkers[n] = find(`{Tags.TurretPrefix}{n}`) :: any
		houseMarkers[n] = find(`{Tags.HousePrefix}{n}`) :: any
		if turretMarkers[n] then
			table.insert(slotList, n)
		end
	end

	if not bossMarker and #slotList == 0 then
		print("[LayoutService] ไม่เจอ Tag BossSpawn / Turret1-6 — ใช้ผังวงกลมเดิม")
		return
	end
	if not bossMarker then
		warn("[LayoutService] ไม่เจอ Tag BossSpawn — ใช้ผังวงกลมเดิม (ติด Tag BossSpawn ให้บล็อกจุดบอส)")
		return
	end
	if #slotList == 0 then
		warn("[LayoutService] ไม่เจอ Tag Turret1-6 — ใช้ผังวงกลมเดิม (ติด Tag Turret1..Turret6 ให้แท่นป้อม)")
		return
	end
	local missingHouses = {}
	for _, n in slotList do
		if not houseMarkers[n] then
			table.insert(missingHouses, `House{n}`)
		end
	end
	print(
		`[LayoutService] ใช้ผังจากแมพ: BossSpawn = {(bossMarker :: Instance):GetFullName()} · ป้อม {#slotList} จุด ({table.concat(slotList, ", ")})`
	)
	if #missingHouses > 0 then
		warn(`[LayoutService] ยังไม่มี Tag {table.concat(missingHouses, ", ")} — ผู้เล่นช่องนั้นจะเกิดข้างป้อมแทน`)
	end

	if Map.Layout.HideBossMarker then
		local parts = if (bossMarker :: Instance):IsA("BasePart") then { bossMarker } else (bossMarker :: Instance):GetDescendants()
		for _, part in parts do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
				part.CanQuery = false
			end
		end
	end
end

local LayoutService = {}

-- มีผังจากแมพครบ (BossSpawn + ป้อมอย่างน้อย 1 จุด)
function LayoutService.hasLayout(): boolean
	load()
	return bossMarker ~= nil and #slotList > 0
end

-- เลขช่องที่มีแท่นป้อม เรียงน้อยไปมาก
function LayoutService.slots(): { number }
	load()
	return slotList
end

-- ความสูงผิวพื้นใต้จุด (x, z) · ยิงลำแสงลงมา ข้ามตัวละคร/มอน/ป้อม/ของที่ระบุ
function LayoutService.floorAt(position: Vector3, ignore: { Instance }?): number
	load()
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for _, name in { "Monsters", "Turrets", "Map" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	if bossMarker and Map.Layout.HideBossMarker then
		table.insert(exclude, bossMarker)
	end
	for _, item in ignore or {} do
		table.insert(exclude, item)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local origin = Vector3.new(position.X, 1000, position.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
	return if hit then hit.Position.Y else Map.GroundY
end

-- จุดบอส (บนพื้น)
function LayoutService.bossCenter(): Vector3
	load()
	local cf = boxOf(bossMarker :: Instance)
	local flat = Vector3.new(cf.Position.X, 0, cf.Position.Z)
	return Vector3.new(flat.X, LayoutService.floorAt(flat), flat.Z)
end

-- กลางผิวบนของแท่นป้อม
function LayoutService.turretTop(slot: number): Vector3
	load()
	local marker = turretMarkers[slot]
	local cf = boxOf(marker)
	return Vector3.new(cf.Position.X, topY(marker), cf.Position.Z)
end

-- จุดเกิดผู้เล่นหน้าบ้าน (ฝั่งที่หันไปทางป้อม) · ไม่มีบ้าน → ข้างป้อมฝั่งตรงข้ามบอส
function LayoutService.spawnPoint(slot: number): Vector3
	load()
	local turret = LayoutService.turretTop(slot)
	local house = houseMarkers[slot]
	local point: Vector3
	if house then
		local cf, size = boxOf(house)
		local center = Vector3.new(cf.Position.X, 0, cf.Position.Z)
		local toward = Vector3.new(turret.X, 0, turret.Z) - center
		local dir = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
		local reach = math.abs(cf.RightVector:Dot(dir)) * size.X / 2 + math.abs(cf.LookVector:Dot(dir)) * size.Z / 2
		point = center + dir * (reach + Map.Layout.SpawnGap)
	else
		local boss = LayoutService.bossCenter()
		local away = Vector3.new(turret.X - boss.X, 0, turret.Z - boss.Z)
		local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
		point = Vector3.new(turret.X, 0, turret.Z) + dir * 10
	end
	return Vector3.new(point.X, LayoutService.floorAt(point), point.Z)
end

function LayoutService.Init()
	load()
end

return LayoutService
