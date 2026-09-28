-- ปลด Anchored ให้โมเดลบอส เพื่อทำท่าใน Animation Editor / Motion Capture ได้ (ใช้ในหน้าแก้งาน ไม่เข้าเกม)
-- แก้ Error: "All of the parts on this model are anchored, making it non-animatable"
-- วิธีใช้: กด Stop ก่อน → คลิกเลือกโมเดลใน Explorer (เช่น Boss_rabbit) → View → Command Bar → วางทั้งไฟล์นี้ → Enter → Ctrl + S
--   ไม่ได้เลือกอะไร = หาโมเดลชื่อ Boss_rabbit / boss_slambot ให้เอง
-- ปลดทุกชิ้น ยกเว้น "ตัวราก" 1 ชิ้น (HumanoidRootPart → PrimaryPart → ชิ้นใหญ่สุด) ที่ยังยึดไว้ ตัวจะได้ไม่ร่วงตอนพรีวิว · Ctrl + Z ย้อนได้
-- ไฟล์นี้อยู่นอก src/ → Rojo ไม่ sync เข้าเกม ต้องคัดลอกไปวางเองทุกครั้ง
-- ⚠️ ถ้าเป็นบอส Slambot อ่าน docs/boss-slambot-known-good.md ก่อน (บอสตัวนี้ถูกล็อกไว้)

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ชื่อโมเดลที่หาให้อัตโนมัติเมื่อไม่ได้เลือกอะไร · มีบอสใหม่ → เพิ่มชื่อที่นี่
local NAMES = { "Boss_rabbit", "boss_slambot" }

-- ทำชื่อให้เทียบง่าย: ตัวเล็ก ตัดสัญลักษณ์ ตัดคำว่า "boss"
local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end

-- หาโมเดลเป้าหมาย: ดูสิ่งที่เลือกใน Explorer ก่อน (เลือกชิ้นลูกก็ได้ จะใช้โมเดลที่ครอบอยู่) · ไม่ได้เลือก → หาตามชื่อใน NAMES
local function findModel()
	for _, item in Selection:Get() do
		local model = if item:IsA("Model") then item else item:FindFirstAncestorOfClass("Model")
		if model then
			return model
		end
	end
	for _, container in { workspace, ServerStorage } do
		for _, item in container:GetDescendants() do
			if item:IsA("Model") then
				for _, name in NAMES do
					if simple(item.Name) == simple(name) then
						return item
					end
				end
			end
		end
	end
	return nil
end

local model = findModel()
if not model then
	warn("❌ ไม่เจอโมเดล — คลิกเลือกโมเดลใน Explorer ก่อนแล้วรันใหม่")
	return
end

-- ===== สำรวจโมเดล =====
-- เก็บทุกชิ้น · หาตัวราก · นับชิ้นส่วนริก (counts) ไว้รายงานว่าทำท่าได้ไหม
local parts, root, biggest = {}, nil, nil
local counts = { Humanoid = 0, AnimationController = 0, Motor6D = 0, Bone = 0, AnimationConstraint = 0 }
for _, item in model:GetDescendants() do
	if counts[item.ClassName] then
		counts[item.ClassName] += 1
	end
	if item:IsA("BasePart") then
		table.insert(parts, item)
		if item.Name == "HumanoidRootPart" and not root then
			root = item
		end
		if not biggest or item.Size.Magnitude > biggest.Size.Magnitude then
			biggest = item
		end
	end
end
root = root or model.PrimaryPart or biggest

-- ===== ปลด Anchored (บันทึกประวัติไว้ให้ Ctrl + Z ย้อนได้) =====
local _, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Unanchor rig")
end)
local freed = 0
for _, part in parts do
	if part == root then
		part.Anchored = true
	elseif part.Anchored then
		part.Anchored = false
		freed += 1
	end
end
if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
end

-- ===== สรุปผล + เตือนถ้าริกไม่พร้อมทำท่า =====
print(`✅ {model:GetFullName()}: ปลด Anchored {freed} ชิ้น · ตัวรากที่ยังยึดไว้ = {if root then root.Name else "-"}`)
print(
	`ℹ️ ริก: Humanoid {counts.Humanoid} · AnimationController {counts.AnimationController} · Motor6D {counts.Motor6D}`
		.. ` · Bone {counts.Bone} · AnimationConstraint {counts.AnimationConstraint}`
)
if counts.Motor6D + counts.Bone + counts.AnimationConstraint == 0 then
	warn("⚠️ โมเดลนี้ไม่มีข้อต่อเลย — ทำท่าไม่ได้ ต้องทำโครงกระดูก (Armature) ใน Blender แล้ว Export/Import ใหม่ หรือใช้ Rig Builder")
end
if counts.Humanoid + counts.AnimationController == 0 then
	warn("⚠️ ไม่มี Humanoid หรือ AnimationController — Animation Editor อาจเลือกโมเดลไม่ได้ ให้ Insert Object → AnimationController ใส่ในโมเดล")
end
print("กด Ctrl + S เพื่อบันทึก แล้วเปิด Avatar → Clip Editor ได้เลย")
