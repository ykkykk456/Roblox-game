-- คลิก/แตะป้อมของตัวเองในโลก → เปิดแผงป้อม (อุปกรณ์ + อัปเกรด) · ปุ่ม "🛠 ป้อม" ลอยเหนือป้อม (เจ้าของ: Client_UI_Scripter · โครง: UX_Architect)
-- แสดงผล/รับ Input เท่านั้น: ไม่ส่งอะไรไป Server เลย (แค่เปิดแผง UI/TurretPanelUI) · ป้อมเป็นของใครอ่านจาก Attribute OwnerUserId ที่ Server ตั้ง
--
-- วิธีรู้ว่าคลิกโดนป้อม (ทำฝั่ง Client ทั้งหมด):
--   ⚠️ ชิ้นป้อมส่วนใหญ่ CanQuery = false (Server ตั้งใน TurretLook · มีแค่ "Head") → workspace:Raycast ชนไม่โดน
--   → ใช้คณิต: ลำแสงจากกล้องผ่านจุดที่แตะ (Camera:ScreenPointToRay) ตัดกับ "กล่องรอบป้อม" (Model:GetBoundingBox) ไหม
--   แตะ = กดแล้วปล่อยเร็ว (≤ TAP_MAX_SECONDS) และนิ้ว/เมาส์แทบไม่ขยับ (≤ TAP_MAX_MOVE) → ลากหมุนกล้องผ่านป้อมไม่เปิดแผง
--   ข้าม: แตะโดนปุ่ม/UI อยู่แล้ว (gameProcessed) · มีแผงอื่นเปิดอยู่ (ต้องปิดก่อน · กันแย่งกับหน้าเลือกธาตุขั้นฝึก 1)
--
-- ปุ่มลอย (BillboardGui ใน PlayerGui · ต้องอยู่ใน PlayerGui ปุ่มถึงกดได้): เห็นตลอด ทะลุกำแพง → ทางลัดสำหรับมือถือ/คนที่ไม่รู้ว่าคลิกป้อมได้
--   Gamepad: ปุ่มลอยเลือกด้วยจอยยาก → ใช้ RB (ผูกใน UI/TurretPanelUI) แทน
--
-- อยากปรับ:
--   ระยะ/เวลาที่ยังนับว่า "แตะ" → TAP_MAX_MOVE / TAP_MAX_SECONDS · กล่องป้อมใหญ่ขึ้น (กดง่ายขึ้น) → HIT_PADDING
--   ขนาด/ข้อความ/ความสูงปุ่มลอย → BUTTON_SIZE / BUTTON_TEXT / BUTTON_HEIGHT · มองเห็นไกลสุด → BUTTON_MAX_DISTANCE
--
-- 📖 อ่านตามลำดับนี้:
--   1) TurretTapUI.Init สร้างปุ่มลอย (ซ่อนไว้จนเจอป้อม)
--   2) TurretTapUI.Start ฟัง InputBegan/InputEnded (แตะ) + วนหาป้อมของเราทุก REFRESH_SECONDS → refreshButton
--   3) แตะจบ → tryOpenAt(จุดบนจอ) → ownTurret → rayHitsBox → TurretPanelUI.open()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local TurretPanelUI = require(script.Parent.TurretPanelUI)

local player = Players.LocalPlayer

-- ===== ค่าที่ปรับได้ =====
local TAP_MAX_MOVE = 12 -- พิกเซล: ขยับเกินนี้ระหว่างกด = ลาก (หมุนกล้อง) ไม่ใช่แตะ
local TAP_MAX_SECONDS = 0.5 -- วินาที: กดค้างนานกว่านี้ = ไม่นับว่าแตะ
local RAY_LENGTH = 1000 -- studs: ป้อมไกลกว่านี้จากกล้อง = คลิกไม่ติด
local HIT_PADDING = 1 -- studs: ขยายกล่องรอบป้อมทุกด้าน (กดง่ายขึ้นบนจอเล็ก)
local REFRESH_SECONDS = 2 -- วินาที: หาป้อมของเราซ้ำ (ป้อมถูกสร้างใหม่ตอนเปลี่ยนธาตุ/ขั้นหน้าตา)
-- ✏️ ปุ่มลอยเหนือป้อม: ปิดไว้ตามที่เจ้าของเกมสั่ง (2026-10-01: เอาออก ให้คลิกที่ป้อมอย่างเดียว) · true = แสดงกลับมา
local SHOW_FLOAT_BUTTON = false
local BUTTON_SIZE = Vector2.new(96, 44) -- สูง ≥ 44 กดบนมือถือสบาย
local BUTTON_TEXT = "🛠 ป้อม"
local BUTTON_HEIGHT = 2.5 -- studs เหนือยอดป้อม
local BUTTON_MAX_DISTANCE = 250 -- studs: ไกลกว่านี้ไม่โชว์ปุ่มลอย
local ELEMENT_PANEL = "Element" -- ⚠️ ต้องตรงกับ PANEL_NAME ใน UI/ElementUI

-- ===== สถานะ =====
local buttonGui: BillboardGui
-- จุดเริ่มกดของแต่ละนิ้ว (Touch = InputObject ของนิ้วนั้น) / เมาส์ (คีย์ "Mouse")
local pressed: { [any]: { position: Vector2, at: number } } = {}

-- ป้อมของเรา: workspace.Turrets → Model ที่ Attribute OwnerUserId = UserId ของเรา (Server/TurretService ตั้ง)
local function ownTurret(): Model?
	local folder = workspace:FindFirstChild("Turrets")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == player.UserId then
			return child
		end
	end
	return nil
end

-- ลำแสง origin + direction × t (0 ≤ t ≤ 1) ผ่านกล่อง (cframe, size) ไหม · วิธี "slab": ตัดทีละแกนในพิกัดของกล่อง
local function rayHitsBox(origin: Vector3, direction: Vector3, cframe: CFrame, size: Vector3): boolean
	local o = cframe:PointToObjectSpace(origin)
	local d = cframe:VectorToObjectSpace(direction)
	local half = size / 2 + Vector3.one * HIT_PADDING
	local origins = { o.X, o.Y, o.Z }
	local dirs = { d.X, d.Y, d.Z }
	local halves = { half.X, half.Y, half.Z }
	local tMin, tMax = 0, 1
	for axis = 1, 3 do
		local oa, da, ha = origins[axis], dirs[axis], halves[axis]
		if math.abs(da) < 1e-8 then
			-- ลำแสงขนานแกนนี้: ต้องอยู่ในช่วงกล่องอยู่แล้ว
			if math.abs(oa) > ha then
				return false
			end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end
	return true
end

-- แตะที่จุด position บนจอ → ถ้าโดนป้อมเรา = เปิดแผงป้อม
-- [Inferred] InputObject.Position ของเมาส์/นิ้ว = พิกัดจอแบบไม่รวมแถบบน (GUI inset) → ใช้ ScreenPointToRay (ไม่ใช่ ViewportPointToRay)
local function tryOpenAt(position: Vector2)
	if Panels.current() ~= nil then
		return -- มีแผงเปิดอยู่ (รวมแผงป้อมเอง) → ไม่ทำอะไร
	end
	local turret = ownTurret()
	local camera = workspace.CurrentCamera
	if not turret or not camera then
		return
	end
	local ok, cframe, size = pcall(turret.GetBoundingBox, turret)
	if not ok then
		return
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	if rayHitsBox(ray.Origin, ray.Direction * RAY_LENGTH, cframe, size) then
		TurretPanelUI.open()
	end
end

-- ชิ้นที่ปุ่มลอยเกาะ: "Head" (ป้อมโค้ด/โมเดล import มีเสมอ) → PrimaryPart → ชิ้นแรกที่เจอ
local function anchorPart(turret: Model): BasePart?
	local head = turret:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		return head
	end
	if turret.PrimaryPart then
		return turret.PrimaryPart
	end
	return turret:FindFirstChildWhichIsA("BasePart", true)
end

-- วางปุ่มลอยเหนือยอดป้อมของเรา · ไม่เจอป้อม = ซ่อน
local function refreshButton()
	local turret = ownTurret()
	local part = if turret then anchorPart(turret) else nil
	if not SHOW_FLOAT_BUTTON or not turret or not part then
		buttonGui.Enabled = false
		buttonGui.Adornee = nil
		return
	end
	local ok, cframe, size = pcall(turret.GetBoundingBox, turret)
	local top = if ok then cframe.Position.Y + size.Y / 2 else part.Position.Y
	buttonGui.Adornee = part
	-- StudsOffsetWorldSpace = ขึ้นฟ้าตรงๆ ไม่หมุนตามหัวป้อมที่หันเล็ง
	buttonGui.StudsOffsetWorldSpace = Vector3.new(0, top - part.Position.Y + BUTTON_HEIGHT, 0)
	buttonGui.Enabled = true
end

local TurretTapUI = {}

-- สร้างปุ่มลอย (ซ่อนไว้จนกว่าจะเจอป้อม)
function TurretTapUI.Init()
	buttonGui = Instance.new("BillboardGui")
	buttonGui.Name = "TurretButtonGui"
	buttonGui.ResetOnSpawn = false
	buttonGui.AlwaysOnTop = true
	buttonGui.LightInfluence = 0
	buttonGui.Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
	buttonGui.MaxDistance = BUTTON_MAX_DISTANCE
	buttonGui.Active = true
	buttonGui.Enabled = false
	-- ⚠️ ต้องอยู่ใน PlayerGui (+ Adornee) ปุ่มถึงกดได้ · อยู่ใน workspace = เห็นแต่กดไม่ได้
	buttonGui.Parent = player:WaitForChild("PlayerGui")

	local button = Components.button(buttonGui, BUTTON_TEXT, {
		size = UDim2.fromScale(1, 1),
		color = Theme.Colors.Accent,
		hoverColor = Theme.Colors.AccentHover,
		textSize = 18,
	}, function()
		-- ขั้นฝึก 1 (หน้าเลือกธาตุถูกบังคับเปิด) → ไม่แย่ง · หลังเลือกธาตุแล้วเปิดแผงป้อมทับได้
		if Panels.current() == ELEMENT_PANEL and player:GetAttribute("Element") == "" then
			return
		end
		TurretPanelUI.open()
	end)
	button.Name = "TurretButton"
	button.Selectable = false -- Gamepad ใช้ RB แทน (กันโฟกัสกระโดดมาที่ปุ่มในโลก)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Colors.Text
	stroke.Thickness = 2
	stroke.Parent = button
end

-- เริ่มฟังการแตะ + วนหาป้อมของเรา
function TurretTapUI.Start()
	-- คีย์ของการกด: นิ้ว = InputObject ของนิ้วนั้น (ใช้ตัวเดิมตั้งแต่กดจนปล่อย) · เมาส์ = "Mouse"
	local function keyOf(input: InputObject): any
		return if input.UserInputType == Enum.UserInputType.Touch then input else "Mouse"
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if gameProcessed then
			return -- แตะโดนปุ่ม/UI/จอยบนจอ
		end
		pressed[keyOf(input)] = { position = Vector2.new(input.Position.X, input.Position.Y), at = os.clock() }
	end)

	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local key = keyOf(input)
		local start = pressed[key]
		pressed[key] = nil
		if not start or os.clock() - start.at > TAP_MAX_SECONDS then
			return
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if (position - start.position).Magnitude > TAP_MAX_MOVE then
			return
		end
		tryOpenAt(position)
	end)

	-- ป้อมถูกสร้างใหม่บ่อย (เลือก/เปลี่ยนธาตุ · ขั้นหน้าตา · เข้าเกม) → ฟังโฟลเดอร์ + วนเช็กเป็นระยะกันพลาด
	task.spawn(function()
		local folder = workspace:WaitForChild("Turrets", 60)
		if folder then
			local function onChanged()
				task.defer(refreshButton) -- รอ Server ใส่ลูกในโมเดลครบก่อนค่อยวัดกล่อง
			end
			folder.ChildAdded:Connect(onChanged)
			folder.ChildRemoved:Connect(onChanged)
		end
	end)
	while true do
		refreshButton()
		task.wait(REFRESH_SECONDS)
	end
end

return TurretTapUI
