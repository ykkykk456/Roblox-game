-- สกิลป้อม: คลังสกิล · กาชา · เลือกใช้ · อัปขั้น · คูลดาวน์ · ตั๋ว (เจ้าของ: Gameplay_Scripter)
-- ทุกการเปลี่ยนแปลงทำใน PlayerData.update เดียว (หักตั๋ว + ได้สกิล พร้อมกัน ไม่มีสถานะครึ่งๆ กลางๆ)
-- ข้อมูลจาก DataStore ไม่เชื่อตรงๆ: อ่านผ่าน ownedLevel/ownedCopies ที่ตรวจชนิดและช่วงค่าเสมอ
-- การสุ่มเกิดที่ Server เท่านั้น ด้วย Random ของ Server · Client ได้แค่ผลลัพธ์ไปแสดง
-- [Proposed] prototype: ตั๋วได้จากชนะบอสเท่านั้น · ยังไม่มีการซื้อตั๋วด้วย Robux

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local SkillMath = require(ReplicatedStorage.Shared.Util.SkillMath)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

type Cooldown = { activeUntil: number, readyAt: number, id: string, level: number }

local rng = Random.new()
local cooldowns: { [Player]: Cooldown } = {}

-- ตารางสะสมโอกาสสำหรับสุ่ม: { { id, upTo } } (upTo สะสมถึง 1)
local cumulative: { { id: string, upTo: number } } = {}
do
	local odds = SkillMath.odds()
	local sum = 0
	for _, id in Skills.Order do
		sum += odds[id]
		table.insert(cumulative, { id = id, upTo = sum })
	end
end

local function rollOne(): string
	local roll = rng:NextNumber()
	for _, entry in cumulative do
		if roll < entry.upTo then
			return entry.id
		end
	end
	return cumulative[#cumulative].id -- กันเศษทศนิยม
end

local function ownedEntry(data: any, id: string): any?
	local skills = data.Skills
	if type(skills) ~= "table" or not Skills.List[id] then
		return nil
	end
	local entry = skills[id]
	return if type(entry) == "table" then entry else nil
end

local function ownedLevel(data: any, id: string): number?
	local entry = ownedEntry(data, id)
	return if entry then SkillMath.clampLevel(entry.Level) else nil
end

local function ownedCopies(data: any, id: string): number
	local entry = ownedEntry(data, id)
	local copies = if entry then entry.Copies else 0
	if type(copies) ~= "number" or copies ~= copies or copies < 0 then
		return 0
	end
	return math.floor(math.min(copies, 1e6))
end

local function tickets(data: any): number
	local value = data.GachaTickets
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.floor(value)
end

local SkillService = {}

-- สกิลที่เลือกใช้อยู่: (id, def, level) หรือ nil
function SkillService.equipped(player: Player): (string?, any?, number?)
	local data = PlayerData.get(player)
	if not data then
		return nil, nil, nil
	end
	local id = data.EquippedSkill
	if type(id) ~= "string" then
		return nil, nil, nil
	end
	local level = ownedLevel(data, id)
	if not level then
		return nil, nil, nil
	end
	return id, Skills.List[id], level
end

function SkillService.isReady(player: Player, serverNow: number): boolean
	local cooldown = cooldowns[player]
	return cooldown == nil or serverNow >= cooldown.readyAt
end

-- เริ่มสกิล (ผู้เรียกตรวจ isReady แล้ว) · คูลดาวน์เป็นของผู้เล่น เปลี่ยนสกิลไม่ได้ช่วยรีเซ็ต
function SkillService.activate(player: Player, id: string, def: any, level: number, serverNow: number)
	local cooldown = {
		activeUntil = serverNow + def.Duration,
		readyAt = serverNow + def.Cooldown,
		id = id,
		level = level,
	}
	cooldowns[player] = cooldown
	-- ให้ Client แสดงเวลานับถอยหลัง (ค่าจริงอยู่ในตาราง cooldowns ฝั่ง Server)
	player:SetAttribute("SkillActiveUntil", cooldown.activeUntil)
	player:SetAttribute("SkillReadyAt", cooldown.readyAt)
end

-- ตัวคูณจากสกิลที่กำลังทำงาน (ใช้ค่า ณ ตอนกด เปลี่ยนสกิลกลางทางไม่มีผล)
function SkillService.modifiers(player: Player, serverNow: number): (number, number, number)
	local cooldown = cooldowns[player]
	if not cooldown or serverNow >= cooldown.activeUntil then
		return 1, 1, 1
	end
	local def = Skills.List[cooldown.id]
	return SkillMath.multiplier(def.FireRate, cooldown.level),
		SkillMath.multiplier(def.Damage, cooldown.level),
		SkillMath.multiplier(def.BossDamage, cooldown.level)
end

function SkillService.grantTickets(player: Player, amount: number)
	if amount <= 0 or not player.Parent then
		return
	end
	PlayerData.update(player, function(data)
		data.GachaTickets = math.min(tickets(data) + math.floor(amount), Economy.Gacha.MaxTickets)
	end)
end

-- เรียกจาก SkillHandler หลังผ่าน Guard (count ถูกตรวจว่าอยู่ใน RollSizes แล้ว)
function SkillService.roll(player: Player, count: number)
	local results = {}
	PlayerData.update(player, function(data)
		local have = tickets(data)
		if have < count then
			return
		end
		data.GachaTickets = have - count
		if type(data.Skills) ~= "table" then
			data.Skills = {}
		end
		for _ = 1, count do
			local id = rollOne()
			local entry = ownedEntry(data, id)
			if entry then
				entry.Copies = ownedCopies(data, id) + 1
				table.insert(results, { id = id, new = false })
			else
				data.Skills[id] = { Level = 1, Copies = 0 }
				table.insert(results, { id = id, new = true })
			end
		end
	end)
	if #results > 0 then
		local remote = Remotes.get("GachaResult") :: RemoteEvent
		remote:FireClient(player, results)
	end
end

function SkillService.equip(player: Player, id: string)
	PlayerData.update(player, function(data)
		if ownedLevel(data, id) then
			data.EquippedSkill = id
		end
	end)
end

function SkillService.upgrade(player: Player, id: string)
	PlayerData.update(player, function(data)
		local level = ownedLevel(data, id)
		if not level then
			return
		end
		local need = SkillMath.copiesToUpgrade(level)
		local copies = ownedCopies(data, id)
		if not need or copies < need then
			return
		end
		local entry = data.Skills[id]
		entry.Copies = copies - need
		entry.Level = level + 1
	end)
end

function SkillService.Init()
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return SkillService
