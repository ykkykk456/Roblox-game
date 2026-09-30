-- ขยับชิ้นประดับของป้อมธาตุฝั่ง Client (เจ้าของ: Client_UI_Scripter) · ภาพล้วน ไม่มีผลกับเกม
-- Server (Services/TurretLook) ติด Attribute "Anim" ไว้บนชิ้นที่ต้องขยับ: ใบพัดหมุน · ปีกกระพือ · ลูกแก้วลอย · ฟองพิษ
--   · ประกายไฟกะพริบ · ปริซึมสีรุ้ง · วงแหวนตื่นพลังลอย → ไฟล์นี้ขยับให้ทุกเฟรม (ลื่น + Server ไม่ต้องส่งข้อมูลทุกเฟรม)
-- วิธีไม่ชนกับ Server: Server ย้ายชิ้นทุกครั้งที่ป้อมเล็ง (CFrame ใหม่) → เราจำ "ค่าที่เราตั้งล่าสุด" ไว้
--   ถ้าค่าบนชิ้นไม่ตรงกับที่เราตั้ง = Server เพิ่งย้าย → ใช้ค่านั้นเป็นฐานใหม่ แล้วค่อยบวกการขยับทับ
--
-- ชนิด Anim (ค่ามาจาก TurretLook):
--   Orbit = หมุนรอบแกน (AnimAxis) ผ่านจุด AnimPivot ด้วยความเร็ว AnimSpeed เรเดียน/วิ (ใบพัด, หินโคจร)
--   Flap  = แกว่งไปมารอบแกน ±AnimAmp เรเดียน (ปีกนก)
--   Bob   = ลอยขึ้นลง ±AnimAmp studs (ลูกแก้วน้ำ, วงแหวนตื่นพลัง)
--   Rise  = ลอยขึ้นจาก 0 → AnimAmp studs แล้ววนใหม่ (ฟองพิษ)
--   Blink = กะพริบ (ประกายไฟฟ้า, ปล่องไฟ) · Hue = สีรุ้งวน (ปริซึม)
--
-- อยากปรับ: ความเร็ว/ระยะ → ค่า anim ใน server/Services/TurretLook.luau · ระยะที่ยังขยับ → CULL_DISTANCE
-- ⚠️ ระวัง: ไฟล์นี้แค่ภาพ ห้ามคำนวณดาเมจ/เป้าที่นี่
--
-- 📖 อ่านตามลำดับนี้
--   1) Start — รอโฟลเดอร์ workspace.Turrets · เก็บชิ้นที่มี Anim (DescendantAdded) · ผูก RenderStepped → step
--   2) track — จดชิ้นใหม่ (ค่าตั้งต้น) · untrack — ลบเมื่อชิ้นถูกลบ
--   3) step — ทุกเฟรม: ข้ามป้อมที่ไกลกล้อง → หาค่าฐาน → คำนวณการขยับตามชนิด → ตั้ง CFrame/สี/ความใส

local RunService = game:GetService("RunService")

-- ===== ค่าคงที่ =====
local CULL_DISTANCE = 220 -- ไกลกล้องเกินนี้ไม่ขยับ (ประหยัดเครื่อง)

-- ข้อมูลชิ้นที่ขยับ 1 ชิ้น
type Entry = {
	part: BasePart,
	kind: string,
	speed: number,
	amp: number,
	phase: number,
	pivot: Vector3, -- จุดหมุนในพื้นที่ของชิ้น
	axis: Vector3, -- แกนหมุนในพื้นที่ของชิ้น
	base: CFrame, -- ตำแหน่งล่าสุดที่ Server ตั้ง
	written: CFrame?, -- ค่าที่เราตั้งเอง (อ่านกลับหลังตั้ง)
	visible: boolean?, -- Blink: สถานะล่าสุด
}

local entries: { [BasePart]: Entry } = {}

local function numberAttr(part: Instance, name: string, fallback: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" and value == value then value else fallback
end

local function vectorAttr(part: Instance, name: string, fallback: Vector3): Vector3
	local value = part:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else fallback
end

-- จดชิ้นที่มี Attribute "Anim"
local function track(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	local kind = item:GetAttribute("Anim")
	if type(kind) ~= "string" or entries[item] then
		return
	end
	local axis = vectorAttr(item, "AnimAxis", Vector3.new(0, 0, 1))
	entries[item] = {
		part = item,
		kind = kind,
		speed = numberAttr(item, "AnimSpeed", 1),
		amp = numberAttr(item, "AnimAmp", 0),
		phase = numberAttr(item, "AnimPhase", 0),
		pivot = vectorAttr(item, "AnimPivot", Vector3.zero),
		axis = if axis.Magnitude > 0.01 then axis.Unit else Vector3.new(0, 0, 1),
		base = item.CFrame,
		written = nil,
		visible = nil,
	}
end

local function untrack(item: Instance)
	if item:IsA("BasePart") then
		entries[item] = nil
	end
end

-- การหมุนรอบแกน axis ผ่านจุด pivot (ทั้งคู่อยู่ในพื้นที่ของชิ้น) มุม angle
local function rotateAbout(entry: Entry, angle: number): CFrame
	return entry.base * CFrame.new(entry.pivot) * CFrame.fromAxisAngle(entry.axis, angle) * CFrame.new(-entry.pivot)
end

-- ทุกเฟรม: ขยับชิ้นทั้งหมดที่อยู่ใกล้กล้อง
local function step()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	local t = os.clock()
	for part, entry in entries do
		if not part.Parent then
			entries[part] = nil
			continue
		end
		-- Server ย้ายชิ้นแล้ว (ค่าไม่ตรงกับที่เราตั้ง) → ใช้เป็นฐานใหม่
		if entry.written == nil or part.CFrame ~= entry.written then
			entry.base = part.CFrame
		end
		if eye and (entry.base.Position - eye).Magnitude > CULL_DISTANCE then
			continue
		end
		local kind = entry.kind
		local goal: CFrame? = nil
		if kind == "Orbit" then
			goal = rotateAbout(entry, t * entry.speed + entry.phase)
		elseif kind == "Flap" then
			goal = rotateAbout(entry, math.sin(t * entry.speed + entry.phase) * entry.amp)
		elseif kind == "Bob" then
			goal = entry.base * CFrame.new(entry.base:VectorToObjectSpace(Vector3.new(0, math.sin(t * entry.speed + entry.phase) * entry.amp, 0)))
		elseif kind == "Rise" then
			local rise = ((t * entry.speed + entry.phase) % 1) * entry.amp
			goal = entry.base * CFrame.new(entry.base:VectorToObjectSpace(Vector3.new(0, rise, 0)))
		elseif kind == "Blink" then
			local visible = math.sin(t * entry.speed + entry.phase) > -0.2
			if visible ~= entry.visible then
				entry.visible = visible
				part.Transparency = if visible then 0 else 0.85
			end
		elseif kind == "Hue" then
			part.Color = Color3.fromHSV((t * entry.speed + entry.phase) % 1, 0.55, 1)
		end
		if goal then
			part.CFrame = goal
			entry.written = part.CFrame -- อ่านกลับ (ค่าที่เก็บจริงอาจปัดทศนิยม) ไว้เทียบเฟรมหน้า
		end
	end
end

local TurretAnimController = {}

function TurretAnimController.Start()
	-- workspace.Turrets สร้างโดย Server (TurretService) · รอจนมา
	local folder = workspace:WaitForChild("Turrets")
	for _, item in folder:GetDescendants() do
		track(item)
	end
	folder.DescendantAdded:Connect(track)
	folder.DescendantRemoving:Connect(untrack)
	RunService.RenderStepped:Connect(step)
end

return TurretAnimController
