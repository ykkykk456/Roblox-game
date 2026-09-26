-- ตัวช่วยเล่นอนิเมชันกับ Model ใดก็ได้ที่มี Humanoid หรือ AnimationController (บอส, NPC, ของในฉาก)
-- โหลดแต่ละท่าครั้งเดียวแล้ว cache · ID ว่าง/ผิด = warn แล้วข้าม ไม่ error
-- เล่นที่ Server กับ NPC → replicate ไปทุก Client เอง [Verified]
--
-- ตัวอย่าง:
--   local anim = AnimPlayer.new(model, { Idle = "rbxassetid://123", Attack = "rbxassetid://456" })
--   anim:Play("Idle")
--   anim:Play("Attack", 0.1)
--   anim:Destroy()

local AnimPlayer = {}
AnimPlayer.__index = AnimPlayer

export type AnimPlayer = typeof(setmetatable(
	{} :: {
		_name: string,
		_ids: { [string]: string },
		_animator: Animator,
		_tracks: { [string]: AnimationTrack },
		_failed: { [string]: boolean },
		_destroyed: boolean,
	},
	AnimPlayer
))

local DEFAULT_FADE = 0.2

local function isValidId(id: any): boolean
	return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil and id ~= "rbxassetid://0"
end

function AnimPlayer.new(model: Model, ids: { [string]: string }): AnimPlayer?
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		warn(`[AnimPlayer] {model:GetFullName()} ไม่มี Humanoid หรือ AnimationController`)
		return nil
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return setmetatable({
		_name = model:GetFullName(),
		_ids = ids,
		_animator = animator :: Animator,
		_tracks = {},
		_failed = {},
		_destroyed = false,
	}, AnimPlayer)
end

-- คืน AnimationTrack ของท่า (โหลดครั้งแรกที่ขอ) หรือ nil ถ้าไม่มี/ID ผิด
function AnimPlayer.GetTrack(self: AnimPlayer, name: string): AnimationTrack?
	if self._destroyed or self._failed[name] then
		return nil
	end
	local track = self._tracks[name]
	if track then
		return track
	end

	local id = self._ids[name]
	if not isValidId(id) then
		self._failed[name] = true
		warn(
			`[AnimPlayer] {self._name}: ท่า "{name}" ยังไม่มี AnimationId ที่ถูกต้อง ({id})`
		)
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, result = pcall(function()
		return self._animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		self._failed[name] = true
		warn(`[AnimPlayer] {self._name}: โหลดท่า "{name}" ไม่สำเร็จ: {result}`)
		return nil
	end
	self._tracks[name] = result
	return result
end

function AnimPlayer.IsPlaying(self: AnimPlayer, name: string): boolean
	local track = self._tracks[name]
	return track ~= nil and track.IsPlaying
end

-- เล่นท่า · holdLastFrame = true ค้างท่าเฟรมสุดท้ายไว้ (ใช้กับท่าตาย)
function AnimPlayer.Play(
	self: AnimPlayer,
	name: string,
	fadeTime: number?,
	speed: number?,
	holdLastFrame: boolean?
): AnimationTrack?
	local track = self:GetTrack(name)
	if not track then
		return nil
	end
	track:Play(fadeTime or DEFAULT_FADE, 1, speed or 1)

	if holdLastFrame then
		-- ท่าไม่ loop เมื่อจบจะกลับท่าเดิม → หยุดความเร็วเป็น 0 ก่อนถึงเฟรมสุดท้ายเล็กน้อย [Inferred]
		task.spawn(function()
			while track.IsPlaying and track.Length == 0 do
				task.wait()
			end
			while track.IsPlaying and track.TimePosition < track.Length - 0.05 do
				task.wait()
			end
			if track.IsPlaying then
				track:AdjustSpeed(0)
			end
		end)
	end
	return track
end

function AnimPlayer.Stop(self: AnimPlayer, name: string, fadeTime: number?)
	local track = self._tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeTime or DEFAULT_FADE)
	end
end

function AnimPlayer.StopAll(self: AnimPlayer, fadeTime: number?)
	for _, track in self._tracks do
		if track.IsPlaying then
			track:Stop(fadeTime or DEFAULT_FADE)
		end
	end
end

function AnimPlayer.Destroy(self: AnimPlayer)
	if self._destroyed then
		return
	end
	self:StopAll(0)
	for _, track in self._tracks do
		track:Destroy()
	end
	table.clear(self._tracks)
	self._destroyed = true
end

return AnimPlayer
