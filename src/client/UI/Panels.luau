-- เปิด/ปิดแผงหน้าต่าง · เปิดได้ทีละแผง (เปิดแผงใหม่ = ปิดแผงเดิม)
-- โมดูล helper: ไม่มี Init/Start

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

type Entry = { frame: GuiObject, focus: GuiObject?, scale: UIScale }

local entries: { [string]: Entry } = {}
local currentName: string? = nil

local Panels = {}

-- focus = ปุ่มที่ Gamepad จะเลือกเป็นอันแรกเมื่อแผงเปิด
function Panels.register(name: string, frame: GuiObject, focus: GuiObject?)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	entries[name] = { frame = frame, focus = focus, scale = scale }
	frame.Visible = false
end

function Panels.close()
	if not currentName then
		return
	end
	local entry = entries[currentName]
	currentName = nil
	entry.frame.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(entry.frame) then
		GuiService.SelectedObject = nil
	end
end

function Panels.open(name: string)
	local entry = entries[name]
	if not entry then
		warn(`[Panels] ไม่มีแผงชื่อ {name}`)
		return
	end
	Panels.close()
	currentName = name
	entry.scale.Scale = 0.92
	entry.frame.Visible = true
	TweenService:Create(entry.scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if UserInputService.GamepadEnabled and entry.focus then
		GuiService.SelectedObject = entry.focus
	end
end

function Panels.toggle(name: string)
	if currentName == name then
		Panels.close()
	else
		Panels.open(name)
	end
end

function Panels.current(): string?
	return currentName
end

return Panels
