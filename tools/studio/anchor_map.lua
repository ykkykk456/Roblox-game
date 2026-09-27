-- ล็อกแมพไม่ให้ร่วงตอนกด Play (ใช้ในหน้าแก้งาน ไม่เข้าเกม)
-- วิธีใช้: Studio → กด Stop ก่อน → View → Command Bar → คัดลอกทั้งไฟล์นี้ไปวาง → Enter → ดูผลใน Output → Ctrl + S
-- ยึด (Anchored = true) ทุกชิ้นใน Workspace ที่ยังไม่ได้ยึด
-- ข้าม: ตัวละคร/บอส/ริก (Model ที่มี Humanoid, AnimationController, HumanoidRootPart, Motor6D, Bone หรือชื่อบอส) และชิ้นที่ตั้ง attribute Physics = true
-- กด Ctrl + Z ย้อนได้

local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ริก = โมเดลที่ขยับได้ (ตัวละคร/บอส) ห้ามยึด ไม่งั้นทำท่าใน Animation Editor ไม่ได้
local BOSS_NAMES = { "Boss_rabbit", "boss_slambot" }
local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end
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

local _, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Anchor map")
end)

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
