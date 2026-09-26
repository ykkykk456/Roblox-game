-- เล่นอนิเมชันให้บอสทุกตัวที่ติด tag Boss (เจ้าของ: Gameplay_Scripter)
-- ตั้งค่าใน Studio: Model บอส → Tag "Boss" + Attribute BossId (เช่น "Boss1") → ID ท่าอยู่ใน Config/BossAnimations.luau
-- อัตโนมัติ: Idle ↔ Walk ตามการเดินของ Humanoid · Death เมื่อตาย
-- ระบบอื่นเรียกท่าพิเศษ: BossAnimationService.PlayAction(model, "Attack")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimPlayer = require(Shared.Util.AnimPlayer)
local BossAnimations = require(Shared.Config.BossAnimations)
local Tags = require(Shared.Config.Tags)
local Tagged = require(Shared.Util.Tagged)

local WALK_SPEED_THRESHOLD = 0.5 -- ความเร็วต่ำกว่านี้ถือว่ายืนนิ่ง

local players: { [Model]: AnimPlayer.AnimPlayer } = {}

local function setupBoss(instance: Instance): (() -> ())?
	if not instance:IsA("Model") then
		warn(`[BossAnimation] tag Boss ต้องติดที่ Model: {instance:GetFullName()}`)
		return nil
	end
	local bossId = instance:GetAttribute("BossId")
	local ids = BossAnimations[bossId]
	if not ids then
		warn(`[BossAnimation] {instance:GetFullName()} BossId "{bossId}" ไม่มีใน Config/BossAnimations`)
		return nil
	end
	local anim = AnimPlayer.new(instance, ids)
	if not anim then
		return nil
	end
	players[instance] = anim
	anim:Play("Idle")

	local connections: { RBXScriptConnection } = {}
	local humanoid = instance:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- ไม่ให้ข้อต่อหลุดตอนตาย เพื่อให้ท่า Death เล่นได้ [Inferred]
		humanoid.BreakJointsOnDeath = false
		-- ให้ Server คุมฟิสิกส์บอส ไม่งั้นเมื่อผู้เล่นเข้าใกล้ ownership ย้ายไป Client แล้ว Running ฝั่ง Server อาจไม่ยิง [Inferred]
		local root = instance.PrimaryPart or humanoid.RootPart
		if root and not root.Anchored then
			pcall(root.SetNetworkOwner, root, nil)
		end
		local dead = false

		table.insert(
			connections,
			humanoid.Running:Connect(function(speed: number)
				if dead then
					return
				end
				if speed > WALK_SPEED_THRESHOLD then
					if not anim:IsPlaying("Walk") then
						anim:Stop("Idle")
						anim:Play("Walk")
					end
				elseif not anim:IsPlaying("Idle") then
					anim:Stop("Walk")
					anim:Play("Idle")
				end
			end)
		)
		table.insert(
			connections,
			humanoid.Died:Connect(function()
				dead = true
				anim:StopAll(0.1)
				anim:Play("Death", 0.1, 1, true)
			end)
		)
	end

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if players[instance] == anim then
			players[instance] = nil
		end
		anim:Destroy()
	end
end

local BossAnimationService = {}

-- เล่นท่าครั้งเดียว (Attack, Hit, ...) · คืน AnimationTrack (ใช้รอ .Stopped หรือ marker ได้) หรือ nil
function BossAnimationService.PlayAction(model: Model, name: string, speed: number?): AnimationTrack?
	local anim = players[model]
	if not anim then
		return nil
	end
	return anim:Play(name, 0.1, speed)
end

function BossAnimationService.Start()
	Tagged.each(Tags.Boss, setupBoss)
end

return BossAnimationService
