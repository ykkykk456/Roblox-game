-- บอสอีเวนต์: เกิดตามเวลา ทั้งเซิร์ฟช่วยกันตี แบ่งรางวัล "ขั้นต่ำ + ตามดาเมจ" (เจ้าของ: Gameplay_Scripter)
-- สถานะส่งให้ Client ผ่าน Attribute ของ ReplicatedStorage.BossState (อ่านอย่างเดียว ใช้แสดงผล):
--   Active: boolean · Hp / MaxHp: number · EndsAt / NextAt: เวลา workspace:GetServerTimeNow()
--   Top: JSON [{ n = ชื่อ, d = ดาเมจ }] 5 อันดับ · Result: ข้อความผลรอบล่าสุด
-- ดาเมจของตัวเองส่งผ่าน Player Attribute "BossDamage"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Wallet = require(script.Parent.Wallet)

local PUBLISH_INTERVAL = 0.2
local TOP_COUNT = 5

type Entry = { name: string, damage: number }
type Boss = {
	part: BasePart,
	hp: number,
	maxHp: number,
	endsAt: number,
	damageBy: { [number]: Entry }, -- key = UserId (คนที่ออกไปแล้วยังอยู่ในตาราง แต่ไม่ได้รางวัล)
}

local state: Folder
local boss: Boss? = nil
local dirty = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function makeBody(): BasePart
	local part = Instance.new("Part")
	part.Name = "Boss"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(14, 14, 14)
	part.Color = Color3.fromRGB(130, 60, 200)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(0, Combat.Boss.Height, 0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "👹 BOSS"
	label.Parent = gui
	return part
end

local function sortedEntries(current: Boss): { Entry }
	local list = {}
	for _, entry in current.damageBy do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.damage > b.damage
	end)
	return list
end

local function publish(current: Boss)
	state:SetAttribute("Hp", math.ceil(current.hp))
	local top = {}
	for index, entry in sortedEntries(current) do
		if index > TOP_COUNT then
			break
		end
		table.insert(top, { n = entry.name, d = math.floor(entry.damage) })
	end
	state:SetAttribute("Top", HttpService:JSONEncode(top))
	for userId, entry in current.damageBy do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("BossDamage", math.floor(entry.damage))
		end
	end
end

local function spawnBoss()
	local maxHp = Combat.Boss.BaseHp + Combat.Boss.HpPerPlayer * #Players:GetPlayers()
	local part = makeBody()
	part.Parent = workspace
	boss = { part = part, hp = maxHp, maxHp = maxHp, endsAt = now() + Combat.Boss.Duration, damageBy = {} }
	for _, player in Players:GetPlayers() do
		player:SetAttribute("BossDamage", 0)
	end
	state:SetAttribute("MaxHp", maxHp)
	state:SetAttribute("Hp", maxHp)
	state:SetAttribute("EndsAt", boss.endsAt)
	state:SetAttribute("Top", "[]")
	state:SetAttribute("Result", "")
	state:SetAttribute("Active", true)
end

local function finish(current: Boss, killed: boolean)
	boss = nil
	current.part:Destroy()
	publish(current)

	local ranking = sortedEntries(current)
	if killed then
		local total = 0
		for _, entry in ranking do
			total += entry.damage
		end
		for userId, entry in current.damageBy do
			local player = Players:GetPlayerByUserId(userId)
			if player and total > 0 then
				Wallet.earn(player, Economy.Boss.BaseReward + Economy.Boss.DamageRewardPool * entry.damage / total)
			end
		end
		local mvp = if ranking[1] then ranking[1].name else "-"
		state:SetAttribute("Result", `ชนะบอสแล้ว! 🏆 ดาเมจสูงสุด: {mvp}`)
	else
		-- [Proposed] บอสหนี = ไม่มีรางวัล (รอเจ้าของเกมยืนยัน)
		state:SetAttribute(
			"Result",
			"บอสหนีไปแล้ว… รอบหน้าต้องตีให้แรงขึ้น"
		)
	end
	state:SetAttribute("Active", false)
	state:SetAttribute("NextAt", now() + Combat.Boss.Interval)
end

local BossService = {}

-- บอสที่ตีได้ตอนนี้ (nil ถ้าไม่มี)
function BossService.getTarget(): Vector3?
	if boss and boss.hp > 0 then
		return boss.part.Position
	end
	return nil
end

function BossService.damage(player: Player, amount: number)
	local current = boss
	if not current or current.hp <= 0 then
		return
	end
	local applied = math.min(amount, current.hp)
	current.hp -= applied
	local entry = current.damageBy[player.UserId]
	if not entry then
		entry = { name = player.DisplayName, damage = 0 }
		current.damageBy[player.UserId] = entry
	end
	entry.damage += applied
	dirty = true
end

function BossService.Init()
	state = Instance.new("Folder")
	state.Name = "BossState"
	state:SetAttribute("Active", false)
	state:SetAttribute("NextAt", now() + Combat.Boss.FirstDelay)
	state:SetAttribute("Top", "[]")
	state:SetAttribute("Result", "")
	state.Parent = ReplicatedStorage
end

function BossService.Start()
	while true do
		task.wait(PUBLISH_INTERVAL)
		local current = boss
		if current then
			if current.hp <= 0 then
				finish(current, true)
			elseif now() >= current.endsAt then
				finish(current, false)
			elseif dirty then
				dirty = false
				publish(current)
			end
		elseif now() >= state:GetAttribute("NextAt") then
			if #Players:GetPlayers() > 0 then
				spawnBoss()
			else
				state:SetAttribute("NextAt", now() + 5)
			end
		end
	end
end

return BossService
