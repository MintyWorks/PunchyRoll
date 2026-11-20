--!nocheck

const Harness = require("@tests/harness")
const KeyframeLoader = require("@src/roblox/KeyframeLoader")
const Player = require("@src/Player")
const Rig = require("@src/Rig")

const Test, Expect = Harness.Test, Harness.Expect

const function pose(name, x, style, direction, children)
	return {
		Name = name,
		CFrame = CFrame.new(x, 0, 0),
		EasingStyle = { Name = style or "Linear" },
		EasingDirection = { Name = direction or "In" },
		GetSubPoses = function()
			return children or {}
		end,
	}
end

const function keyframe(time, name, poses, markers)
	return {
		Name = name or "Keyframe",
		Time = time,
		GetPoses = function()
			return poses
		end,
		GetMarkers = function()
			return markers or {}
		end,
	}
end

const function sequence(keyframes)
	return {
		Name = "Punch",
		Loop = false,
		Priority = { Name = "Action" },
		GetKeyframes = function()
			return keyframes
		end,
	}
end

Test("markers and named keyframes become events", function()
	const clip = KeyframeLoader.Load(sequence({
		keyframe(1, "Land", { pose("Root", 0, nil, nil, { pose("B", 4) }) }),
		keyframe(0, nil, { pose("Root", 0, nil, nil, { pose("B", 0) }) }, { { Name = "hitreg", Value = "damage=12" } }),
	}))

	Expect.Equal(clip.Length, 1)
	Expect.Equal(clip.Priority, 3)
	Expect.True(clip:HasEvent("hitreg"))
	Expect.True(clip:HasEvent("Land"))
	Expect.Equal(clip:GetEvents()[1].Params.damage, 12)
end)

Test("loaded clips play on a rig", function()
	const identity = CFrame.new()
	const rig = Rig.New({
		Name = "Root",
		C0 = identity,
		C1 = identity,
		Children = { { Name = "B", C0 = identity, C1 = identity } },
	})
	const clip = KeyframeLoader.Load(sequence({
		keyframe(0, nil, { pose("Root", 0, nil, nil, { pose("B", 0) }) }),
		keyframe(1, nil, { pose("Root", 0, nil, nil, { pose("B", 4) }) }),
	}))

	const player = Player.New(rig)
	player:Play(clip)
	player:Update(0.5)
	Expect.Near(player.Pose.Positions[rig:GetIndex("B")].x, 2, 1e-6)
end)

Test("incoming easing mode shifts easing to the previous segment", function()
	const frames = {
		keyframe(0, nil, { pose("B", 0, "Linear") }),
		keyframe(1, nil, { pose("B", 10, "Cubic", "In") }),
	}

	const outgoing = KeyframeLoader.Load(sequence(frames))
	const incoming = KeyframeLoader.Load(sequence(frames), { EasingMode = "incoming" })
	const a = outgoing:SampleJoint("B", 0.5)
	const b = incoming:SampleJoint("B", 0.5)
	Expect.Near(a.x, 5, 1e-6)
	Expect.Near(b.x, 1.25, 1e-6)
end)

return nil
