-- ผังแมพจากบล็อกที่ติด Tag ใน Studio (เจ้าของ: World_Builder) · ยืนยัน 2026-09-27
-- Tag: BossSpawn = จุดบอส · Turret1..6 = แท่นป้อม · House1..6 = บ้าน (เลขเดียวกันคู่กัน) · ไม่มี Tag แต่ชื่อบล็อกตรงก็ใช้ได้
-- อ่านอย่างเดียว ไม่แก้บล็อกของแมพ (ยกเว้น Map.Layout.HideBossMarker ทำ BossSpawn โปร่งใสตอนรัน)
-- ไม่เจอ Tag → hasLayout() = false → ระบบอื่นใช้ผังวงกลมเดิมจาก Config/Map
-- โหลดครั้งแรกที่มีคนเรียก (ไม่พึ่งลำดับ Init)
--
-- อยากปรับ:
--   • ย้ายจุดบอส/ป้อม/บ้าน → ย้ายบล็อกที่ติด Tag ใน Studio เลย ไม่ต้องแก้โค้ด (ใช้ tools/studio/check_layout.lua ตรวจ)
--   • จำนวนช่องสูงสุด / ระยะจุดเกิดจากบ้าน / ซ่อนบล็อกบอส → src/shared/Config/Map.luau (Layout.MaxSlots / SpawnGap / HideBossMarker)
--   • ชื่อ Tag → src/shared/Config/Tags.luau (BossSpawn / TurretPrefix / HousePrefix)
-- คุยกับ: BaseService, MapService, PitService, TurretService, MonsterService, BossService (อ่านตำแหน่งจากที่นี่)
-- ดูข้อความ [LayoutService] ใน Output เพื่อรู้ว่าเกมใช้ผังจากแมพหรือผังวงกลม

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)

-- ===== สถานะ (เติมครั้งเดียวใน load) =====
local loaded = false
-- บล็อก BossSpawn (nil = ไม่เจอ)
local bossMarker: Instance? = nil
-- [เลขช่อง] = บล็อกแท่นป้อม / บล็อกบ้าน
local turretMarkers: { [number]: Instance } = {}
local houseMarkers: { [number]: Instance } = {}
-- เลขช่องที่มีแท่นป้อมจริง เช่น { 1, 2, 4 }
local slotList: { number } = {}

-- ===== ตัวช่วยเรขาคณิต =====
-- กล่องครอบ (ใช้ได้ทั้ง Part และ Model)
local function boxOf(item: Instance): (CFrame, Vector3)
	if item:IsA("BasePart") then
		return item.CFrame, item.Size
	elseif item:IsA("Model") then
		return item:GetBoundingBox()
	end
	return CFrame.new(), Vector3.zero
end

-- ความสูงผิวบนสุดของบล็อก (ไล่ดูมุมกล่องทั้ง 8 มุม จึงถูกต้องแม้บล็อกถูกหมุน/เอียง)
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

-- ===== หาบล็อกจาก Tag =====
-- หาบล็อกที่ติด Tag ชื่อ name ใน workspace · ไม่มี Tag → หาจากชื่อบล็อกแทน · เจอหลายชิ้น → ใช้ชิ้นแรกและเตือน
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

-- อ่านผังจากแมพครั้งเดียว (เรียกซ้ำได้ ครั้งถัดไปจะข้าม) · พิมพ์สรุป/คำเตือนลง Output
-- ถ้าตั้ง HideBossMarker → ทำบล็อกจุดบอสโปร่งใส ไม่ชน และไม่โดน Raycast
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

	-- ต้องมีทั้ง BossSpawn และป้อมอย่างน้อย 1 จุด ไม่งั้นใช้ผังวงกลมเดิม
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
		print(
			`[LayoutService] ยังไม่มี Tag {table.concat(missingHouses, ", ")} — ผู้เล่นเกิดข้างป้อมของตัวเอง (ติด Tag House ทีหลังได้)`
		)
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

-- ===== API (ทุกฟังก์ชันเรียก load() เองก่อน จึงเรียกเมื่อไรก็ได้) =====
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
-- ยิงจากความสูง 1000 ลงไป 2000 studs · ไม่โดนอะไรเลย → คืน Map.GroundY
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
-- ต้องเช็ก hasLayout() ก่อนเรียก (ไม่มี BossSpawn แล้วเรียก = error)
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
-- MapService ใช้วาง SpawnLocation ของแต่ละช่อง
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
		-- reach = ระยะจากกลางบ้านถึงขอบบ้านในทิศ dir (คิดการหมุนของบ้านด้วย) แล้วเว้นอีก SpawnGap
		local reach = math.abs(cf.RightVector:Dot(dir)) * size.X / 2 + math.abs(cf.LookVector:Dot(dir)) * size.Z / 2
		point = center + dir * (reach + Map.Layout.SpawnGap)
	else
		local boss = LayoutService.bossCenter()
		local away = Vector3.new(turret.X - boss.X, 0, turret.Z - boss.Z)
		local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
		-- 10 studs ถัดจากป้อม ออกไปฝั่งที่หันหลังให้บอส
		point = Vector3.new(turret.X, 0, turret.Z) + dir * 10
	end
	return Vector3.new(point.X, LayoutService.floorAt(point), point.Z)
end

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · อ่านผังทันทีเพื่อให้ข้อความสรุปขึ้น Output ตั้งแต่ต้น
function LayoutService.Init()
	load()
end

return LayoutService
