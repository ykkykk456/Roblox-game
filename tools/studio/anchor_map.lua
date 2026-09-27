-- ล็อกแมพไม่ให้ร่วงตอนกด Play (ใช้ในหน้าแก้งาน ไม่เข้าเกม)
-- วิธีใช้: Studio → กด Stop ก่อน → View → Command Bar → คัดลอกทั้งไฟล์นี้ไปวาง → Enter → ดูผลใน Output → Ctrl + S
-- ยึด (Anchored = true) ทุกชิ้นใน Workspace ที่ยังไม่ได้ยึด
-- ข้าม: ตัวละคร/บอส (Model ที่มี Humanoid หรือ HumanoidRootPart) และชิ้นที่ตั้ง attribute Physics = true (อยากให้ร่วงได้)
-- กด Ctrl + Z ย้อนได้

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function isCharacterPart(part)
	local node = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and (node:FindFirstChildOfClass("Humanoid") or node:FindFirstChild("HumanoidRootPart")) then
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
