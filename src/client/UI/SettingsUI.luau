-- หน้าตั้งค่า: เสียง · ภาพ · หน้าจอ · รีเซ็ต
-- เปิดจากปุ่มใน HUD หรือกด M (คีย์บอร์ด) / Select (Gamepad)
-- ค่าจริงเก็บ/ใช้ที่ Controllers/SettingsController · ไฟล์นี้แค่สร้างปุ่ม/แถบเลื่อน
-- อยากเพิ่มตัวเลือก → เพิ่มค่าใน SettingsController ก่อน แล้วเพิ่ม Components.slider/toggle ในหมวดที่ต้องการ
--   ช่วงแถบเลื่อน = { min, max, step } · ลำดับบนจอ = ลำดับบรรทัดในโค้ด (nextOrder)
-- อยากเปลี่ยนปุ่มลัด → Enum.KeyCode ใน SettingsUI.Start · ขนาด/ตำแหน่งแผงกำหนดใน Components.panel

local ContextActionService = game:GetService("ContextActionService")

local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Parent.Controllers.SettingsController)

local PANEL_NAME = "Settings"

local SettingsUI = {}

-- สร้างหน้าตั้งค่าทั้งหมดตอนเริ่มเกม (ซ่อนไว้จนกดเปิด)
function SettingsUI.Init()
	local gui = Components.screen("SettingsGui", 10)
	local frame, content, closeButton = Components.panel(gui, "ตั้งค่า", Panels.close)

	-- ตัวช่วย: นับลำดับบนจอ · หัวข้อหมวด · ผูกตัวควบคุมกับค่า key
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function section(title: string)
		Components.label(content, title, { bold = true, color = Theme.Colors.Accent, order = nextOrder() })
	end
	local function bind(key: string): (any) -> ()
		return function(value)
			Settings.set(key, value)
		end
	end

	local setters: { [string]: (any) -> () } = {}

	-- ===== หมวดเสียง =====
	section("🔊 เสียง")
	setters.MusicVolume = Components.slider(
		content,
		"เพลง",
		{ min = 0, max = 100, step = 10 },
		Settings.get("MusicVolume"),
		bind("MusicVolume"),
		nextOrder()
	)
	setters.SfxVolume = Components.slider(
		content,
		"เอฟเฟกต์",
		{ min = 0, max = 100, step = 10 },
		Settings.get("SfxVolume"),
		bind("SfxVolume"),
		nextOrder()
	)

	-- ===== หมวดภาพ =====
	section("🖥 ภาพ")
	setters.Shadows = Components.toggle(content, "เงา", Settings.get("Shadows"), bind("Shadows"), nextOrder())
	setters.FieldOfView = Components.slider(
		content,
		"มุมกล้อง (FOV)",
		{ min = 70, max = 100, step = 5 },
		Settings.get("FieldOfView"),
		bind("FieldOfView"),
		nextOrder()
	)

	-- ===== หมวดหน้าจอ =====
	section("📊 หน้าจอ")
	setters.ShowFps = Components.toggle(content, "แสดง FPS", Settings.get("ShowFps"), bind("ShowFps"), nextOrder())

	-- ===== ปุ่มคืนค่าเริ่มต้น (สีแดง = Theme.Colors.Danger · กว้างเต็มแผง) =====
	Components.button(content, "คืนค่าเริ่มต้น", {
		size = UDim2.new(1, -10, 0, Theme.ButtonHeight),
		color = Theme.Colors.Danger,
		order = nextOrder(),
	}, Settings.reset)

	-- ค่าเปลี่ยนจากที่อื่น (เช่น ปุ่มรีเซ็ต) → อัปเดตตัวควบคุมบนจอให้ตรง
	Settings.Changed:Connect(function(key: string, value: any)
		local set = setters[key]
		if set then
			set(value)
		end
	end)

	Panels.register(PANEL_NAME, frame, closeButton)
end

-- ผูกปุ่มลัด M / Select ให้เปิด-ปิดหน้าตั้งค่า
function SettingsUI.Start()
	ContextActionService:BindAction("ToggleSettings", function(_, state)
		if state == Enum.UserInputState.Begin then
			Panels.toggle(PANEL_NAME)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
end

return SettingsUI
