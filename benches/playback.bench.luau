--!nocheck

const Clip = require("@src/Clip")
const Player = require("@src/Player")
const Rig = require("@src/Rig")

const JOINTS = 24
const STEPS = 20000

const identity = CFrame.new()
const limbs = { { Name = "J1", C0 = identity, C1 = identity } }
for index = 2, JOINTS do
	table.insert(limbs, { Name = `J{index}`, Parent = `J{index - 1}`, C0 = CFrame.new(0, 1, 0), C1 = identity })
end

const rig = Rig.FromLimbs(limbs)

const function makeClip(name, keys)
	const joints = {}
	for index = 1, JOINTS do
		const frames = {}
		for key = 0, keys do
			table.insert(frames, {
				Time = key / keys,
				Position = vector.create(math.sin(index + key), 0, 0),
				Quaternion = { 0, math.sin(key * 0.3) * 0.2, 0, math.cos(key * 0.3) * 0.2 + 0.9 },
			})
		end
		joints[`J{index}`] = frames
	end

	return Clip.New({
		Name = name,
		Length = 1,
		Loop = true,
		Joints = joints,
		Events = { { Time = 0.5, Name = "hitreg" } },
	})
end

const function run(label, tracks, compose)
	const player = Player.New(rig)
	for index = 1, tracks do
		player:Play(makeClip(`clip{index}`, 16), { Priority = index % 2 })
	end

	local hits = 0
	player:GetMarkerReachedSignal("hitreg"):Connect(function()
		hits += 1
	end)

	for _ = 1, 200 do
		player:Update(1 / 60)
	end

	const started = os.clock()
	for _ = 1, STEPS do
		player:Update(1 / 60, identity)
	end
	const elapsed = os.clock() - started
	print(string.format("%-28s %8.2f us/update  (%d events)", label, elapsed / STEPS * 1e6, hits))
end

run("1 track, 24 joints", 1)
run("3 tracks, 24 joints", 3)
run("6 tracks, 24 joints", 6)
