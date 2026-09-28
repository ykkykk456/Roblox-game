-- ล็อกแมพไม่ให้ร่วงตอนกด Play (ใช้ในหน้าแก้งาน ไม่เข้าเกม)
-- วิธีใช้: Studio → กด Stop ก่อน → View → Command Bar → คัดลอกทั้งไฟล์นี้ไปวาง → Enter → ดูผลใน Output → Ctrl + S
-- ยึด (Anchored = true) ทุกชิ้นใน Workspace ที่ยังไม่ได้ยึด
-- ข้าม: ตัวละคร/บอส/ริก (Model ที่มี Humanoid, AnimationController, HumanoidRootPart, Motor6D, Bone หรือชื่อบอส) และชิ้นที่ตั้ง attribute Physics = true
-- กด Ctrl + Z ย้อนได้
-- ไฟล์นี้อยู่นอก src/ → Rojo ไม่ sync เข้าเกม ต้องคัดลอกไปวางเองทุกครั้ง
-- ใช้เมื่อ: กด Play แล้วของในแมพร่วง/หล่น · เกมก็ยึดให้ชั่วคราวตอนรัน (MapService) แต่สคริปต์นี้ยึดถาวรในไฟล์เกม
-- อยากให้ชิ้นไหนขยับได้ (ไม่ถูกยึด) → เลือกชิ้นนั้น → Properties → Attributes → เพิ่ม Physics (boolean) = true

local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ริก = โมเดลที่ขยับได้ (ตัวละคร/บอส) ห้ามยึด ไม่งั้นทำท่าใน Animation Editor ไม่ได้
-- มีบอสใหม่ → เพิ่มชื่อโมเดลในรายการนี้ (ตัวเล็ก/ใหญ่ ขีด ช่องว่าง และคำว่า boss ไม่มีผล)
local BOSS_NAMES = { "Boss_rabbit", "boss_slambot" }
-- ทำชื่อให้เทียบง่าย: ตัวเล็ก ตัดสัญลักษณ์ ตัดคำว่า "boss" (เช่น "Boss_rabbit" → "rabbit")
local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end
-- true ถ้าโมเดลเป็นตัวละคร/บอส (ชื่อตรง BOSS_NAMES หรือมี Humanoid / AnimationController / ข้อต่อ)
local function isRig(model)
	for _, name in BOSS_NAMES do
		if simple(model.Name) == simple(name) then
			return true
		end
	end
	if model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChild("HumanoidRootPart", true) then
		return true
	end
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("Bone") or item:IsA("AnimationConstraint") then
			return true
		end
	end
	return false
end

-- true ถ้าชิ้นนี้อยู่ในโมเดลที่เป็นริก (ไล่ขึ้นไปทีละชั้นจนถึง workspace)
local function isCharacterPart(part)
	local node = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and isRig(node) then
			return true
		end
		node = node.Parent
	end
	return false
end

-- ===== เริ่มทำงาน =====
-- เริ่มบันทึกประวัติ เพื่อให้ Ctrl + Z ย้อนได้ในครั้งเดียว (Studio ไม่รองรับก็ข้าม)
local _, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Anchor map")
end)

-- count = จำนวนที่ยึดไป · skipped = จำนวนที่ข้าม (ตัวละคร/บอส/Physics)
local count, skipped = 0, 0
for _, item in workspace:GetDescendants() do
	if item:IsA("BasePart") and not item:IsA("Terrain") and not item.Anchored then
		if item:GetAttribute("Physics") == true or isCharacterPart(item) then
			skipped += 1
		else
			item.Anchored = true
			count += 1
		end
	end
end

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
end
print("✅ ยึดชิ้นในแมพแล้ว " .. count .. " ชิ้น · ข้ามตัวละคร/บอส/ชิ้น Physics " .. skipped .. " ชิ้น — กด Ctrl + S เพื่อบันทึก")
