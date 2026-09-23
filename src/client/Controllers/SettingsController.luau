-- ค่าตั้งค่าของผู้เล่น (ความชอบส่วนตัว ไม่มีผลต่อผลเกม จึงเก็บที่ Client ได้)
-- ใช้ค่ากับเกมทันทีเมื่อเปลี่ยน · UI อ่าน/เขียนผ่าน get / set / reset
-- [Proposed] ตอนนี้ค่าหายเมื่อออกเกม — ถ้าต้องการจำค่า ต้องเพิ่ม Remote + field ใน PlayerData (งาน Full Workflow)

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

export type Settings = {
	MusicVolume: number, -- 0–100
	SfxVolume: number, -- 0–100
	Shadows: boolean,
	FieldOfView: number, -- 70–100
	ShowFps: boolean,
}

local DEFAULTS: Settings = table.freeze({
	MusicVolume = 50,
	SfxVolume = 70,
	Shadows = true,
	FieldOfView = 70, -- ค่าเริ่มต้นของกล้อง Roblox [Verified: Camera.FieldOfView default]
	ShowFps = false,
})

local values: Settings = table.clone(DEFAULTS)
local changedEvent = Instance.new("BindableEvent")

local function setSoundGroupVolume(groupName: string, percent: number)
	-- [Proposed] ต้องสร้าง SoundGroup ชื่อ "Music" / "Sfx" ใน SoundService และผูกเสียงเข้ากลุ่มก่อน ค่านี้ถึงมีผล
	local group = SoundService:FindFirstChild(groupName)
	if group and group:IsA("SoundGroup") then
		group.Volume = percent / 100
	end
end

local function apply(key: string)
	if key == "MusicVolume" then
		setSoundGroupVolume("Music", values.MusicVolume)
	elseif key == "SfxVolume" then
		setSoundGroupVolume("Sfx", values.SfxVolume)
	elseif key == "Shadows" then
		Lighting.GlobalShadows = values.Shadows -- เปลี่ยนเฉพาะเครื่องผู้เล่นคนนี้ [Inferred]
	elseif key == "FieldOfView" then
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = values.FieldOfView
		end
	end
	-- ShowFps: HudUI ฟัง Changed แล้วแสดง/ซ่อนเอง
end

local SettingsController = {}

SettingsController.Defaults = DEFAULTS
SettingsController.Changed = changedEvent.Event -- (key: string, value: any)

function SettingsController.get(key: string): any
	return (values :: any)[key]
end

function SettingsController.set(key: string, value: any)
	local default = (DEFAULTS :: any)[key]
	if default == nil or type(value) ~= type(default) then
		warn(`[Settings] ค่า {key} ไม่ถูกต้อง`)
		return
	end
	local current = values :: any
	if current[key] == value then
		return
	end
	current[key] = value
	apply(key)
	changedEvent:Fire(key, value)
end

function SettingsController.reset()
	for key, value in DEFAULTS :: any do
		SettingsController.set(key, value)
	end
end

function SettingsController.Init()
	for key in DEFAULTS :: any do
		apply(key)
	end
	-- กล้องอาจถูกสร้างใหม่ → ใส่ค่า FOV ให้กล้องตัวใหม่
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		apply("FieldOfView")
	end)
end

return SettingsController
