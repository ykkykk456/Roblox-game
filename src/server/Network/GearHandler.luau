-- รับคำขอเรื่องอุปกรณ์ป้อมจาก Client (เจ้าของ: Networking_Specialist) · สเปก: design/equipment.md หัวข้อ 8
-- แทน SkillHandler เดิม (RollGacha / EquipSkill / UpgradeSkill ถูกลบพร้อมระบบกาชา)
-- ตรวจที่นี่: ชนิด + จำนวน argument + ความถี่ (Guard) · id/ช่อง/ระดับต้องมีจริงใน Config · จำนวนต้องเป็นจำนวนเต็มในช่วง
-- ตรวจใน GearService (ข้างใน PlayerData.update): มีของพอไหม · ใส่อยู่ไหม · ช่องเปิดไหม · เงินพอไหม · บอสอยู่ไหม
--
-- อยากปรับความถี่ที่ยอมให้กด → rate/per ของ Remote นั้นด้านล่าง · ตัวเลขเกม → src/shared/Config/Equipment.luau
-- คุยกับ: Guard · Services/GearService (ทำงานจริง) · Remotes
-- ⚠️ ห้ามแก้: ห้ามเอา args ออก และห้ามตัดการเช็ก id กับ Config ก่อนส่งต่อ (Client ส่ง string/ตัวเลขอะไรมาก็ได้)
--   ห้ามต่อ OnServerEvent ตรงๆ (ต้องผ่าน Guard.connect เท่านั้น)
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์สั้น)
--   1) Init — init.server.luau เรียกให้ตอนเซิร์ฟเริ่ม · ผูก 6 Remote เข้ากับ Guard
--   2) ผู้เล่นกดปุ่มในหน้าอุปกรณ์ (Client) → ส่ง Remote มาที่นี่ → Guard (Network/Guard.luau:connect) ตรวจชนิด + ความถี่
--   3) ผ่านแล้ว → เช็ก id/ช่อง/ระดับ/จำนวน กับ Config → ส่งต่อ Services/GearService.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local GearService = require(script.Parent.Parent.Services.GearService)

local GearHandler = {}

function GearHandler.Init()
	-- ใส่ชิ้น: (itemKey: string) · 4 ครั้ง/วิ
	Guard.connect(Remotes.get("EquipGear"), { rate = 4, per = 1, args = { "string" } }, function(player, key)
		if GearMath.isKey(key) then
			GearService.equip(player, key)
		end
	end)
	-- ถอดช่อง: (slot: string) · 4 ครั้ง/วิ
	Guard.connect(Remotes.get("UnequipGear"), { rate = 4, per = 1, args = { "string" } }, function(player, slot)
		if GearMath.slotIndex(slot) then
			GearService.unequip(player, slot)
		end
	end)
	-- เปิดช่องถัดไป: ไม่มี argument · 2 ครั้ง/วิ
	Guard.connect(Remotes.get("UnlockGearSlot"), { rate = 2, per = 1, args = {} }, function(player)
		GearService.unlockSlot(player)
	end)
	-- ย่อย: (itemKey: string, count: number) · count ต้องเป็นจำนวนเต็ม 1..StackCap · 5 ครั้ง/วิ
	Guard.connect(Remotes.get("SalvageGear"), { rate = 5, per = 1, args = { "string", "number" } }, function(player, key, count)
		if GearMath.isKey(key) and Guard.isInteger(count, 1, Equipment.StackCap) then
			GearService.salvage(player, key, count)
		end
	end)
	-- ย่อยทั้งระดับ: (rarity: string) · ไม่รับ Legendary · 1 ครั้ง/วิ
	Guard.connect(Remotes.get("SalvageRarity"), { rate = 1, per = 1, args = { "string" } }, function(player, rarity)
		if GearMath.rarityIndex(rarity) and rarity ~= "Legendary" then
			GearService.salvageRarity(player, rarity)
		end
	end)
	-- รวม 3→1: (itemKey: string) · 3 ครั้ง/วิ
	Guard.connect(Remotes.get("MergeGear"), { rate = 3, per = 1, args = { "string" } }, function(player, key)
		if GearMath.isKey(key) then
			GearService.merge(player, key)
		end
	end)
end

return GearHandler
