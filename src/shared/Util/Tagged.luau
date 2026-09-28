-- เรียก callback กับทุก Instance ที่ติด tag ทั้งที่มีอยู่แล้วและที่เพิ่มเข้ามาทีหลัง
-- ใช้ได้ทั้ง Server และ Client (Client เห็นเฉพาะของที่ replicate มาแล้ว)
--
-- ตัวอย่าง:
--   Tagged.each(Tags.KillZone, function(part)
--       -- ตั้งค่าให้ชิ้นนี้ · คืนฟังก์ชันล้างค่าได้ (ถูกเรียกเมื่อ tag ถูกถอดหรือชิ้นถูกลบ)
--   end)
-- คืนค่า: ฟังก์ชัน "เลิกติดตาม" (เรียกแล้วหยุดฟัง + ล้างค่าทุกชิ้น)
-- ใครใช้: ยังไม่มีไฟล์ไหนเรียก (เตรียมไว้ให้ระบบที่อ่าน Tag จาก Config/Tags)

local CollectionService = game:GetService("CollectionService")

local Tagged = {}

function Tagged.each(tag: string, onAdded: (Instance) -> (() -> ())?): () -> ()
	assert(type(tag) == "string", "tag ต้องเป็น string (ใช้ค่าจาก Config/Tags.luau)")
	local cleanups: { [Instance]: () -> () } = {}

	-- ชิ้นใหม่ได้ tag → เรียก onAdded แล้วเก็บฟังก์ชันล้างไว้
	local function add(instance: Instance)
		if cleanups[instance] then
			return
		end
		local ok, cleanup = pcall(onAdded, instance)
		if not ok then
			warn(`[Tagged] {tag} ที่ {instance:GetFullName()}: {cleanup}`)
			return
		end
		local cleanupFn = if type(cleanup) == "function" then cleanup else function() end
		-- tag อาจถูกถอดระหว่างที่ onAdded ยังทำงาน (yield) → ล้างทันทีแทนการเก็บไว้
		if not CollectionService:HasTag(instance, tag) then
			pcall(cleanupFn)
			return
		end
		cleanups[instance] = cleanupFn
	end

	-- ชิ้นถูกถอด tag/ถูกลบ → เรียกฟังก์ชันล้างของชิ้นนั้น
	local function remove(instance: Instance)
		local cleanup = cleanups[instance]
		if cleanup then
			cleanups[instance] = nil
			pcall(cleanup)
		end
	end

	-- ฟังชิ้นที่ได้/เสีย tag ต่อจากนี้ แล้วจัดการชิ้นที่มีอยู่แล้วตอนนี้
	local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	local removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(add, instance)
	end

	return function()
		addedConnection:Disconnect()
		removedConnection:Disconnect()
		for instance in cleanups do
			remove(instance)
		end
	end
end

return Tagged
