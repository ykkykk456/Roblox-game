-- สกิลป้อม: คลังสกิล · กาชา · เลือกใช้ · อัปขั้น · คูลดาวน์ · ตั๋ว (เจ้าของ: Gameplay_Scripter)
-- ทุกการเปลี่ยนแปลงทำใน PlayerData.update เดียว (หักตั๋ว + ได้สกิล พร้อมกัน ไม่มีสถานะครึ่งๆ กลางๆ)
-- ข้อมูลจาก DataStore ไม่เชื่อตรงๆ: อ่านผ่าน ownedLevel/ownedCopies ที่ตรวจชนิดและช่วงค่าเสมอ
-- การสุ่มเกิดที่ Server เท่านั้น ด้วย Random ของ Server · Client ได้แค่ผลลัพธ์ไปแสดง
-- [Proposed] prototype: ตั๋วได้จากชนะบอสเท่านั้น · ยังไม่มีการซื้อตั๋วด้วย Robux
--
-- อยากปรับ:
--   • อัตราออกของแต่ละสกิล / ระดับความหายาก → src/shared/Config/Skills.luau (Rarities / List / Order)
--   • พลัง ระยะเวลา คูลดาวน์ของสกิล → Config/Skills.luau (List.<id>.Duration / Cooldown / Damage ...)
--   • จำนวนสกิลซ้ำที่ใช้อัปขั้น / เลเวลสูงสุด → Config/Skills.luau (CopiesToUpgrade / MaxLevel)
--   • ตั๋วต่อรอบบอส / เพดานตั๋ว / สุ่มครั้งละกี่ใบ → Config/Economy.luau (Gacha.*)
-- คุยกับ: Network/SkillHandler (รับคำขอ) · TurretService (เรียก equipped/isReady/activate/modifiers)
--   BossService (เรียก grantTickets) · Util/SkillMath (สูตรคำนวณ) · Remote "GachaResult" ส่งผลสุ่มให้ Client
-- ห้ามแก้: ห้ามย้ายการสุ่มไปฝั่ง Client · ห้ามแยกการหักตั๋วกับการให้สกิลออกเป็นสอง update

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local SkillMath = require(ReplicatedStorage.Shared.Util.SkillMath)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- สถานะสกิลที่กดใช้ล่าสุด (เวลาเป็นเวลา Server): ทำงานถึง activeUntil · กดใหม่ได้ตอน readyAt
type Cooldown = { activeUntil: number, readyAt: number, id: string, level: number }

-- ===== สถานะ =====
local rng = Random.new()
-- คูลดาวน์เก็บในหน่วยความจำเท่านั้น (ออกเกม = หาย ไม่บันทึก)
local cooldowns: { [Player]: Cooldown } = {}

-- ===== กาชา: สุ่ม =====
-- ตารางสะสมโอกาสสำหรับสุ่ม: { { id, upTo } } (upTo สะสมถึง 1)
-- เช่น A 0.6, B 0.3, C 0.1 → upTo = 0.6, 0.9, 1.0 · สุ่มเลข 0–1 แล้วดูว่าตกช่องไหน
local cumulative: { { id: string, upTo: number } } = {}
do
	local odds = SkillMath.odds()
	local sum = 0
	for _, id in Skills.Order do
		sum += odds[id]
		table.insert(cumulative, { id = id, upTo = sum })
	end
end

-- สุ่ม 1 ครั้ง คืน skillId
local function rollOne(): string
	local roll = rng:NextNumber()
	for _, entry in cumulative do
		if roll < entry.upTo then
			return entry.id
		end
	end
	return cumulative[#cumulative].id -- กันเศษทศนิยม
end

-- ===== อ่านข้อมูลอย่างปลอดภัย (ข้อมูลจาก DataStore อาจเสีย) =====
-- ช่องของสกิล id ในคลังผู้เล่น ({ Level, Copies }) หรือ nil ถ้ายังไม่มี/ข้อมูลเสีย/id ไม่มีใน Config
local function ownedEntry(data: any, id: string): any?
	local skills = data.Skills
	if type(skills) ~= "table" or not Skills.List[id] then
		return nil
	end
	local entry = skills[id]
	return if type(entry) == "table" then entry else nil
end

-- เลเวลของสกิล (บีบให้อยู่ในช่วงที่ถูกต้อง) หรือ nil ถ้ายังไม่มีสกิลนี้
local function ownedLevel(data: any, id: string): number?
	local entry = ownedEntry(data, id)
	return if entry then SkillMath.clampLevel(entry.Level) else nil
end

-- จำนวนสกิลซ้ำที่มี (จำนวนเต็ม 0 ถึง 1,000,000) · ค่าเสีย/ติดลบ → 0
local function ownedCopies(data: any, id: string): number
	local entry = ownedEntry(data, id)
	local copies = if entry then entry.Copies else 0
	if type(copies) ~= "number" or copies ~= copies or copies < 0 then
		return 0
	end
	return math.floor(math.min(copies, 1e6))
end

-- จำนวนตั๋วกาชา (จำนวนเต็ม ≥ 0) · ค่าเสีย → 0
local function tickets(data: any): number
	local value = data.GachaTickets
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.floor(value)
end

-- ===== API: ใช้สกิลในการต่อสู้ (TurretService เรียก) =====
local SkillService = {}

-- สกิลที่เลือกใช้อยู่: (id, def, level) หรือ nil
-- def = ตารางค่าของสกิลจาก Config/Skills.luau (List[id])
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

-- true ถ้าคูลดาวน์หมดแล้ว (serverNow = workspace:GetServerTimeNow())
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
-- คืน (ตัวคูณอัตรายิง, ตัวคูณดาเมจ, ตัวคูณดาเมจใส่บอส) · ไม่มีสกิลทำงาน = 1, 1, 1
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

-- ===== API: ตั๋ว / กาชา / คลังสกิล =====
-- ให้ตั๋วกาชา (ปัดลง ไม่เกิน Economy.Gacha.MaxTickets) · เรียกจากระบบรางวัลบอส
function SkillService.grantTickets(player: Player, amount: number)
	if amount <= 0 or not player.Parent then
		return
	end
	PlayerData.update(player, function(data)
		data.GachaTickets = math.min(tickets(data) + math.floor(amount), Economy.Gacha.MaxTickets)
	end)
end

-- เรียกจาก SkillHandler หลังผ่าน Guard (count ถูกตรวจว่าอยู่ใน RollSizes แล้ว)
-- ตั๋วไม่พอ = ไม่ทำอะไร · ได้สกิลใหม่ → เพิ่มเข้าคลัง Lv.1 · ได้ซ้ำ → Copies +1 · ส่งผลไปให้ Client ผ่าน "GachaResult"
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

-- สวมสกิล id (ต้องมีในคลังก่อน ไม่มี = ไม่ทำอะไร) · เรียกจาก SkillHandler
function SkillService.equip(player: Player, id: string)
	PlayerData.update(player, function(data)
		if ownedLevel(data, id) then
			data.EquippedSkill = id
		end
	end)
end

-- อัปขั้นสกิล id: ใช้สกิลซ้ำตาม Skills.CopiesToUpgrade[เลเวลปัจจุบัน] · เลเวลเต็ม (need = nil) หรือซ้ำไม่พอ = ไม่ทำอะไร
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

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ล้างคูลดาวน์เมื่อผู้เล่นออก
function SkillService.Init()
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return SkillService
