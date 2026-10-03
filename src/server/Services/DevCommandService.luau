-- คำสั่งโกงสำหรับเทส (พิมพ์ในแชท) — ใช้ได้เฉพาะใน Studio (หรือเจ้าของเกมถ้าเปิด AllowOwnerInLive) (เจ้าของ: Gameplay_Scripter)
-- เหตุผล: อยากเทสระบบที่ใช้เงิน / อุปกรณ์ / เลเวลป้อม โดยไม่ต้องฟาร์มนาน
--
-- 📖 วิธีใช้ (กด Play ใน Studio แล้วพิมพ์ในช่องแชท):
--   /help                         ดูคำสั่งทั้งหมด
--   /money 100000                 เพิ่มเงิน (ไม่เกิน Economy.MaxCoins)
--   /setmoney 0                   ตั้งเงินเป็นค่านี้
--   /level 50                     ตั้งเลเวลป้อม (1..MaxLevel) · หน้าตาป้อมเปลี่ยนตามเลเวลให้เอง
--   /gear Legendary               ได้อุปกรณ์ระดับนั้นครบทุกช่องทุกธาตุ ช่องละ 3 ชิ้น (ไว้ลองรวม/ใส่/แยก)
--   /gear Barrel Fire Epic 5      ได้ชิ้นที่ระบุ (ช่อง ธาตุ ระดับ จำนวน)
--   /slots                        ปลดช่องอุปกรณ์ครบทุกช่อง
--   /skiptut                      ข้ามการฝึกสอน (ถือว่าฝึกจบ)
--   /resettut                     เริ่มฝึกสอนใหม่ตั้งแต่ขั้น 1
--
-- ⚠️ ความปลอดภัย: Server ตรวจสิทธิ์เองทุกครั้ง (ไม่มี Remote ให้ Client เรียก) · นอก Studio ปิดอยู่ (AllowOwnerInLive = false)
--   ข้อมูลที่เปลี่ยนจะถูกเซฟจริงถ้าเปิด API Services ใน Studio → เทสเสร็จใช้ /setmoney 0 หรือใช้บัญชีเทส
-- [Inferred] Player.Chatted ยิงฝั่ง Server ทั้งแชทแบบเก่าและ TextChatService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)
local GearService = require(script.Parent.GearService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local ENABLED_IN_STUDIO = true -- ✏️ false = ปิดคำสั่งเทสแม้ใน Studio
local ALLOW_OWNER_IN_LIVE = false -- ✏️ true = เจ้าของเกม (game.CreatorId) ใช้ได้ในเซิร์ฟจริงด้วย · ⚠️ ปิดก่อนเปิดเกมให้คนเล่น
local MAX_PER_STACK = 99 -- ชิ้นซ้ำสูงสุดต่อชนิด (ตรงกับกฎกระเป๋า)

local DevCommandService = {}

local function allowed(player: Player): boolean
	if RunService:IsStudio() then
		return ENABLED_IN_STUDIO
	end
	return ALLOW_OWNER_IN_LIVE and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- แจ้งผลให้ผู้เล่น (ขึ้นใน Output ของ Studio) · ไม่ส่งผ่านแชทเพื่อไม่ต้องเพิ่ม Remote
local function reply(player: Player, text: string)
	print(`[Dev] {player.Name}: {text}`)
end

-- หาชื่อในรายการแบบไม่สนตัวเล็ก/ใหญ่ เช่น "legendary" → "Legendary"
local function pick(list: { string }, word: string?): string?
	if not word then
		return nil
	end
	for _, name in list do
		if string.lower(name) == string.lower(word) then
			return name
		end
	end
	return nil
end

local function addItem(gear: any, key: string, count: number)
	gear.Items = if type(gear.Items) == "table" then gear.Items else {}
	gear.Items[key] = math.min((gear.Items[key] or 0) + count, MAX_PER_STACK)
end

local commands: { [string]: (Player, { string }) -> () } = {}

commands.help = function(player)
	reply(player, "คำสั่ง: /money N · /setmoney N · /level N · /gear <Rarity> · /gear <Slot> <Element> <Rarity> [N] · /slots · /skiptut · /resettut")
end

commands.money = function(player, args)
	local amount = tonumber(args[1]) or 100000
	PlayerData.update(player, function(data)
		data.Coins = math.clamp(math.floor((data.Coins or 0) + amount), 0, Economy.MaxCoins)
	end)
	reply(player, `เพิ่มเงิน {amount}`)
end

commands.setmoney = function(player, args)
	local amount = tonumber(args[1]) or 0
	PlayerData.update(player, function(data)
		data.Coins = math.clamp(math.floor(amount), 0, Economy.MaxCoins)
	end)
	reply(player, `ตั้งเงิน = {amount}`)
end

commands.level = function(player, args)
	local level = math.clamp(math.floor(tonumber(args[1]) or Combat.Turret.MaxLevel), 1, Combat.Turret.MaxLevel)
	PlayerData.update(player, function(data)
		data.TurretLevel = level
	end)
	reply(player, `เลเวลป้อม = {level}`)
end

commands.gear = function(player, args)
	local data = PlayerData.get(player)
	if not data or type(data.Gear) ~= "table" then
		return
	end
	local onlyRarity = pick(Equipment.RarityOrder, args[1])
	PlayerData.update(player, function(d)
		if onlyRarity then
			-- /gear Legendary → ครบทุกช่อง × ทุกธาตุ ชิ้นละ 3
			for _, slot in Equipment.SlotOrder do
				for _, variant in Equipment.Variants do
					addItem(d.Gear, GearMath.keyOf(slot, variant, onlyRarity), 3)
				end
			end
		else
			local slot = pick(Equipment.SlotOrder, args[1])
			local variant = pick(Equipment.Variants, args[2])
			local rarity = pick(Equipment.RarityOrder, args[3])
			if slot and variant and rarity then
				addItem(d.Gear, GearMath.keyOf(slot, variant, rarity), math.max(1, math.floor(tonumber(args[4]) or 1)))
			end
		end
	end)
	GearService.devRefresh(player)
	reply(player, `เพิ่มอุปกรณ์ ({table.concat(args, " ")})`)
end

commands.slots = function(player)
	PlayerData.update(player, function(data)
		if type(data.Gear) == "table" then
			data.Gear.Slots = Equipment.MaxSlots
		end
	end)
	GearService.devRefresh(player)
	reply(player, "ปลดช่องอุปกรณ์ครบ")
end

commands.skiptut = function(player)
	PlayerData.update(player, function(data)
		data.TutorialStep = 6
		data.TutorialDone = true
	end)
	reply(player, "ข้ามการฝึกสอนแล้ว")
end

commands.resettut = function(player)
	PlayerData.update(player, function(data)
		data.TutorialStep = 1
		data.TutorialDone = false
	end)
	reply(player, "เริ่มฝึกสอนใหม่ (ออกแล้วเข้าเกมใหม่เพื่อเริ่มขั้น 1)")
end

local function onChatted(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "/" or not allowed(player) then
		return
	end
	local words = string.split(string.sub(message, 2), " ")
	local name = string.lower(table.remove(words, 1) or "")
	local args = {}
	for _, word in words do
		if word ~= "" then
			table.insert(args, word)
		end
	end
	local command = commands[name]
	if command then
		local ok, err = pcall(command, player, args)
		if not ok then
			warn(`[Dev] คำสั่ง /{name} ผิดพลาด: {err}`)
		end
	end
end

function DevCommandService.Init()
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return DevCommandService
