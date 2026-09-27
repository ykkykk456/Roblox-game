-- ตรวจ Tag ผังแมพ (ใช้ในหน้าแก้งาน ไม่เข้าเกม · ไม่แก้อะไรในแมพ)
-- วิธีใช้: View → Command Bar → วางทั้งไฟล์นี้ → Enter → ดูผลใน Output
-- ตรวจว่าเจอ Tag BossSpawn / Turret1-6 / House1-6 ครบไหม ติดซ้ำหลายชิ้นไหม และอยู่ตรงไหน

local CollectionService = game:GetService("CollectionService")
local MAX_SLOTS = 6
local problems = 0

local function where(item)
	local cf
	if item:IsA("BasePart") then
		cf = item.CFrame
	elseif item:IsA("Model") then
		cf = item:GetBoundingBox()
	else
		return "(ไม่ใช่ Part/Model)"
	end
	local p = cf.Position
	return string.format("(%.0f, %.0f, %.0f)", p.X, p.Y, p.Z)
end

local function check(tag, required)
	local found = {}
	for _, item in CollectionService:GetTagged(tag) do
		if item:IsDescendantOf(workspace) then
			table.insert(found, item)
		end
	end
	if #found == 0 then
		local byName = workspace:FindFirstChild(tag, true)
		if byName then
			print("🟡 " .. tag .. ": ไม่มี Tag แต่เจอชิ้นชื่อตรง " .. byName:GetFullName() .. " " .. where(byName))
			return true
		end
		if required then
			problems += 1
			warn("❌ " .. tag .. ": ยังไม่ได้ติด Tag")
		else
			print("⚪ " .. tag .. ": ไม่มี (ไม่เป็นไร ถ้าแมพมีน้อยกว่า " .. MAX_SLOTS .. " ช่อง)")
		end
		return false
	end
	if #found > 1 then
		problems += 1
		warn("❌ " .. tag .. ": ติดอยู่ " .. #found .. " ชิ้น ควรติดชิ้นเดียว")
	end
	print("✅ " .. tag .. " → " .. found[1]:GetFullName() .. " " .. where(found[1]))
	return true
end

print("—— ตรวจผังแมพ ——")
check("BossSpawn", true)
local turrets = 0
for n = 1, MAX_SLOTS do
	if check("Turret" .. n, false) then
		turrets += 1
		if not check("House" .. n, false) then
			print("   ↳ ไม่มี House" .. n .. " → ผู้เล่นช่อง " .. n .. " จะเกิดข้างป้อมแทนหน้าบ้าน")
		end
	end
end
if turrets == 0 then
	problems += 1
	warn("❌ ไม่เจอ Turret1-6 เลย — เกมจะใช้ผังวงกลมเดิม")
end
print(if problems == 0
	then "🎉 ผังครบ: ป้อม " .. turrets .. " จุด — กด Play ได้เลย"
	else "⚠️ มีปัญหา " .. problems .. " ข้อ (บรรทัดสีแดงด้านบน)")
