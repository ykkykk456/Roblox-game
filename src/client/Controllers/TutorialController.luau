-- ส่งคำขอ "เข้าใจแล้ว!" ของขั้นสุดท้ายในการฝึกสอน ไป Server (เจ้าของ: Client_UI_Scripter) · สเปก: design/tutorial.md
-- Client ส่งแค่ "เจตนา" (ไม่มี argument) · Server ตรวจเองว่าอยู่ขั้น 5 และอ่านครบ MinReadSeconds แล้ว
-- ผลลัพธ์ดูจาก Attribute TutorialStep / TutorialDone ที่ Server ตั้งกลับมาเท่านั้น
-- ใครใช้: UI/TutorialUI (ปุ่ม "เข้าใจแล้ว!") · ตัวรับฝั่ง Server: src/server/Network/ (ผ่าน Guard)
-- ⚠️ ไฟล์นี้ห้ามตั้ง Attribute เอง/ห้ามเดาว่าฝึกจบ

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TutorialController = {}

-- ส่ง TutorialAck · แยก thread เพราะ Remotes.get รอ Instance (ไม่ให้ปุ่มค้าง)
-- Remote ยังไม่ได้ประกาศ/ผิดชนิด → warn แล้วไม่ส่ง (ขั้น 5 ยังผ่านเองเมื่อครบ ReadSeconds)
function TutorialController.requestAck()
	task.spawn(function()
		local ok, remote = pcall(Remotes.get, "TutorialAck")
		if ok and typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
			remote:FireServer()
		else
			warn(`[TutorialController] ส่ง TutorialAck ไม่ได้: {remote}`)
		end
	end)
end

return TutorialController
