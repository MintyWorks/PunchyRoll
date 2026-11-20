--!nocheck

const Harness = require("@tests/harness")
const Clip = require("@src/Clip")
const Rig = require("@src/Rig")
const Player = require("@src/Player")

const Test, Expect = Harness.Test, Harness.Expect

const function makeRig()
	const identity = CFrame.new()
	return Rig.New({
		Name = "A",
		C0 = identity,
		C1 = identity,
		Children = {
			{ Name = "B", C0 = CFrame.new(0, 1, 0), C1 = identity },
		},
	})
end

const function makeClip(extra)
	const input = {
		Name = "Slash",
		Length = 1,
		Joints = {
			B = {
				{ Time = 0, Position = vector.create(0, 0, 0) },
				{ Time = 1, Position = vector.create(10, 0, 0) },
			},
		},
		Events = {
			{ Time = 0.25, Name = "hitreg_start" },
			{ Time = 0.5, Name = "hitreg" },
			{ Time = 0.75, Name = "hitreg_end" },
			{ Time = 0.9, Name = "sound_whoosh" },
		},
	}

	if extra then
		for key, value in extra do
			input[key] = value
		end
	end

	return Clip.New(input)
end

const function collect(signal)
	const names = {}
	signal:Connect(function(event)
		table.insert(names, event.Name)
	end)

	return names
end

Test("named marker signal fires once when time crosses it", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	const hits = {}
	track:GetMarkerReachedSignal("hitreg"):Connect(function(event)
		table.insert(hits, event.Time)
	end)

	player:Update(0.4)
	Expect.Equal(#hits, 0)
	player:Update(0.2)
	Expect.Equal(#hits, 1)
	Expect.Equal(hits[1], 0.5)
	player:Update(0.2)
	Expect.Equal(#hits, 1)
end)

Test("an event at time zero fires on the first update only", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({ Events = { { Time = 0, Name = "begin" } } }))
	const names = collect(track.EventReached)

	player:Update(0.1)
	player:Update(0.1)
	Expect.Equal(#names, 1)
end)

Test("wildcard patterns match marker names", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	const prefixed = collect(track:GetMarkerReachedSignal("hitreg*"))
	const suffixed = collect(track:GetMarkerReachedSignal("*_end"))
	const all = collect(track:GetMarkerReachedSignal("*"))

	player:Update(0.99)
	Expect.Equal(#prefixed, 3)
	Expect.Equal(#suffixed, 1)
	Expect.Equal(#all, 4)
end)

Test("player level markers see every track", function()
	const player = Player.New(makeRig())
	const names = collect(player:GetMarkerReachedSignal("hitreg"))
	player:Play(makeClip())
	player:Update(0.6)
	Expect.Equal(#names, 1)
end)

Test("looping fires events each cycle including across the seam", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({ Loop = true }))
	const names = collect(track:GetMarkerReachedSignal("hitreg"))

	for _ = 1, 30 do
		player:Update(0.1)
	end

	Expect.Equal(#names, 3)
end)

Test("one large step over several loops fires each cycle", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({ Loop = true }))
	const names = collect(track:GetMarkerReachedSignal("hitreg"))
	const loops = {}
	track.DidLoop:Connect(function()
		table.insert(loops, true)
	end)

	player:Update(2.6)
	Expect.Equal(#names, 3)
	Expect.Equal(#loops, 2)
end)

Test("window helpers report open state", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	local opened, closed = 0, 0
	track:OnWindow("hitreg", function()
		opened += 1
	end, function()
		closed += 1
	end)

	player:Update(0.3)
	Expect.True(track:IsWindowActive("hitreg"))
	Expect.True(player:IsWindowActive("hitreg"))
	Expect.Equal(opened, 1)
	Expect.Equal(closed, 0)
	player:Update(0.5)
	Expect.False(track:IsWindowActive("hitreg"))
	Expect.Equal(closed, 1)
end)

Test("stopping an open window closes it", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	local closed = 0
	track:OnWindow("hitreg", function() end, function()
		closed += 1
	end)

	player:Update(0.3)
	track:Stop()
	Expect.Equal(closed, 1)
end)

Test("once tracks end and stop at the clip length", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	local ended, stopped = 0, 0
	track.Ended:Connect(function()
		ended += 1
	end)
	track.Stopped:Connect(function()
		stopped += 1
	end)

	player:Update(0.6)
	Expect.True(track.IsPlaying)
	player:Update(0.6)
	Expect.False(track.IsPlaying)
	Expect.Equal(ended, 1)
	Expect.Equal(stopped, 1)
end)

Test("clamp tracks hold the last frame", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({}), { LoopMode = "clamp" })
	player:Update(2)
	Expect.True(track.IsPlaying)
	Expect.Equal(track.TimePosition, 1)
end)

Test("fade in ramps the effective weight", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({ Events = {} }), { FadeTime = 0.5 })
	Expect.Near(track:GetEffectiveWeight(), 0, 1e-9)
	player:Update(0.25)
	Expect.Near(track:GetEffectiveWeight(), 0.5, 1e-9)
	player:Update(0.25)
	Expect.Near(track:GetEffectiveWeight(), 1, 1e-9)
end)

Test("fade out stops the track once weight reaches zero", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({ Loop = true, Events = {} }))
	player:Update(0.1)
	track:Stop(0.4)
	Expect.True(track.IsPlaying)
	player:Update(0.2)
	Expect.True(track.IsPlaying)
	player:Update(0.3)
	Expect.False(track.IsPlaying)
end)

Test("speed scales playback and negative speed runs backwards", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip({ Loop = true, Events = {} }), { Speed = 2 })
	player:Update(0.25)
	Expect.Near(track.TimePosition, 0.5, 1e-9)

	const reverse = player:Play(makeClip({ Name = "Rev", Events = {} }), { Speed = -1, LoopMode = "clamp" })
	Expect.Near(reverse.TimePosition, 1, 1e-9)
	player:Update(0.25)
	Expect.Near(reverse.TimePosition, 0.75, 1e-9)
end)

Test("paused tracks do not advance or fire", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	const names = collect(track.EventReached)
	track:Pause()
	player:Update(1)
	Expect.Equal(#names, 0)
	track:Resume()
	player:Update(0.3)
	Expect.Equal(#names, 1)
end)

Test("seek can fire the events it skips over", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	const names = collect(track.EventReached)
	track:Seek(0.6, true)
	Expect.Equal(#names, 2)
	track:Seek(0.0)
	Expect.Equal(#names, 2)
end)

Test("player pose follows the animation", function()
	const player = Player.New(makeRig())
	player:Play(makeClip({ Events = {} }))
	player:Update(0.5)
	Expect.Near(player.Pose.Positions[player.Rig:GetIndex("B")].x, 5, 1e-6)
end)

Test("finished tracks leave the active list", function()
	const player = Player.New(makeRig())
	player:Play(makeClip({ Events = {} }))
	player:Update(2)
	player:Update(0.1)
	Expect.Equal(#player._active, 0)
end)

Test("root motion accumulates the joint delta", function()
	const player = Player.New(makeRig(), { RootMotionJoint = "B" })
	player:Play(makeClip({ Events = {} }))
	local total = vector.zero
	player.RootMotion:Connect(function(position)
		total += position
	end)

	player:Update(0.5)
	player:Update(0.5)
	Expect.Near(total.x, 10, 1e-6)
end)

Test("a throwing handler does not break playback", function()
	const player = Player.New(makeRig())
	const track = player:Play(makeClip())
	require("@src/Signal").SetErrorReporter(function() end)
	track:GetMarkerReachedSignal("hitreg"):Connect(function()
		error("boom")
	end)
	const names = collect(track.EventReached)

	player:Update(0.99)
	Expect.Equal(#names, 4)
	require("@src/Signal").SetErrorReporter(nil)
end)

return nil
