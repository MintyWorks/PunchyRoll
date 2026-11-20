--!nocheck

const Harness = require("@tests/harness")
const Clip = require("@src/Clip")
const Easing = require("@src/Easing")
const Quat = require("@src/Quat")
const Rig = require("@src/Rig")

const Test, Expect = Harness.Test, Harness.Expect

const function quaternion(axis: vector, angle: number)
	const v, w = Quat.FromAxisAngle(axis, angle)
	return { v.x, v.y, v.z, w }
end

const Y = vector.create(0, 1, 0)

const function makeClip(extra)
	const input = {
		Name = "walk",
		Joints = {
			Torso = {
				{ Time = 0, Position = vector.create(0, 0, 0), Quaternion = quaternion(Y, 0) },
				{ Time = 1, Position = vector.create(2, 0, 0), Quaternion = quaternion(Y, 1) },
				{ Time = 2, Position = vector.create(2, 4, 0), Quaternion = quaternion(Y, 1) },
			},
			Head = {
				{ Time = 0.5, Position = vector.create(0, 1, 0) },
			},
		},
	}

	if extra then
		for key, value in extra do
			input[key] = value
		end
	end

	return Clip.New(input)
end

Test("Clip.New derives the length from the last keyframe", function()
	const clip = makeClip()
	Expect.Equal(clip.Length, 2)
	Expect.Equal(#clip.JointNames, 2)
	Expect.Equal(clip.JointNames[1], "Head")
	Expect.Equal(makeClip({ Length = 5 }).Length, 5)
end)

Test("Clip.New sorts and de-duplicates keyframes", function()
	const clip = Clip.New({
		Joints = {
			Torso = {
				{ Time = 1, Position = vector.create(1, 0, 0) },
				{ Time = 0, Position = vector.create(0, 0, 0) },
				{ Time = 1, Position = vector.create(9, 0, 0) },
			},
		},
	})

	const channel = clip.Channels.Torso
	Expect.Equal(channel.Count, 2)
	Expect.Equal(channel.Times[1], 0)
	Expect.Equal(channel.Positions[2].x, 9)
end)

Test("Clip.New fixes quaternion hemispheres", function()
	const clip = Clip.New({
		Joints = {
			Torso = {
				{ Time = 0, Quaternion = { 0, 0, 0, 1 } },
				{ Time = 1, Quaternion = { 0, 0, 0, -1 } },
			},
		},
	})

	const channel = clip.Channels.Torso
	Expect.True(Quat.Dot(channel.QuatV[1], channel.QuatW[1], channel.QuatV[2], channel.QuatW[2]) > 0)
end)

Test("Clip.New validates its input", function()
	Expect.Throws(function()
		Clip.New({ Joints = { Torso = {} } })
	end, "at least one keyframe")

	Expect.Throws(function()
		Clip.New({ Joints = { Torso = { { Time = -1 } } } })
	end, "invalid keyframe time")

	Expect.Throws(function()
		Clip.New({ Joints = { Torso = { { Time = 0, Easing = "nope" } } } })
	end, "Unknown easing")

	Expect.Throws(function()
		Clip.New({ Joints = { Torso = { { Time = 0, Quaternion = { 1, 2 } } } } })
	end, "quaternion")

	Expect.Throws(function()
		Clip.New({ Joints = {}, Events = { { Time = 0, Name = "" } } })
	end, "name")
end)

Test("SampleJoint interpolates linearly", function()
	const clip = makeClip()
	const position, rotationV, rotationW = clip:SampleJoint("Torso", 0.5)
	Expect.VectorNear(position, vector.create(1, 0, 0))
	const expectedV, expectedW = Quat.FromAxisAngle(Y, 0.5)
	Expect.QuatNear(rotationV, rotationW, expectedV, expectedW, 1e-3)

	const endPosition = clip:SampleJoint("Torso", 1.5)
	Expect.VectorNear(endPosition, vector.create(2, 2, 0))
end)

Test("SampleJoint clamps outside of the keyframes", function()
	const clip = makeClip()
	Expect.VectorNear(clip:SampleJoint("Torso", -5), vector.create(0, 0, 0))
	Expect.VectorNear(clip:SampleJoint("Torso", 50), vector.create(2, 4, 0))
	Expect.VectorNear(clip:SampleJoint("Head", 0), vector.create(0, 1, 0))
	Expect.VectorNear(clip:SampleJoint("Head", 3), vector.create(0, 1, 0))
	Expect.Equal(clip:SampleJoint("Missing", 0), nil)
end)

Test("segment easing comes from the outgoing keyframe", function()
	const clip = Clip.New({
		Joints = {
			Torso = {
				{ Time = 0, Position = vector.zero, Easing = "cubic_in" },
				{ Time = 1, Position = vector.create(1, 0, 0), Easing = "constant" },
				{ Time = 2, Position = vector.create(1, 5, 0) },
			},
		},
	})

	Expect.Near(clip:SampleJoint("Torso", 0.5).x, Easing.Get("cubic_in")(0.5))
	Expect.Near(clip:SampleJoint("Torso", 1.5).y, 0)
	Expect.Near(clip:SampleJoint("Torso", 2).y, 5)
end)

Test("custom easing functions are accepted", function()
	const clip = Clip.New({
		Joints = {
			Torso = {
				{ Time = 0, Position = vector.zero, Easing = function(a)
					return a * a
				end },
				{ Time = 1, Position = vector.create(1, 0, 0) },
			},
		},
	})

	Expect.Near(clip:SampleJoint("Torso", 0.5).x, 0.25)
end)

Test("cursor hints never change the sampled value", function()
	const keys = {}
	for index = 0, 20 do
		table.insert(keys, { Time = index * 0.5 + (index % 3) * 0.01, Position = vector.create(index, index * index, 0) })
	end

	const clip = Clip.New({ Joints = { Torso = keys } })
	const channel = clip.Channels.Torso

	for step = 0, 400 do
		const time = step * 0.025
		const reference = Clip.SampleChannel(channel, time, 1)
		for hint = 1, channel.Count do
			Expect.VectorNear(Clip.SampleChannel(channel, time, hint), reference, 1e-9, `t={time} hint={hint}`)
		end
	end

	local cursor = 1
	for step = 0, 400 do
		const time = step * 0.025
		const position, _, _, found = Clip.SampleChannel(channel, time, cursor)
		Expect.VectorNear(position, (Clip.SampleChannel(channel, time, 1)), 1e-9)
		cursor = found
	end
end)

Test("events are sorted and parse their parameters", function()
	const clip = makeClip({
		Events = {
			{ Time = 1.5, Name = "land" },
			{ Time = 0.5, Name = "hitreg", Value = "damage=12; knockback = 3.5, heavy=true, name=slash, flag" },
			{ Time = 0.5, Name = "swing" },
		},
	})

	Expect.Equal(#clip.Events, 3)
	Expect.Equal(clip.Events[1].Name, "hitreg")
	Expect.Equal(clip.Events[2].Name, "swing")
	Expect.Equal(clip.Events[3].Name, "land")

	const params = clip:GetEvents("hitreg")[1].Params
	Expect.Equal(params.damage, 12)
	Expect.Equal(params.knockback, 3.5)
	Expect.Equal(params.heavy, true)
	Expect.Equal(params.name, "slash")
	Expect.Equal(params.flag, true)
	Expect.Equal(clip:GetEvents("land")[1].Value, "")
end)

Test("event queries", function()
	const clip = makeClip({
		Events = {
			{ Time = 0.25, Name = "step" },
			{ Time = 0.75, Name = "step" },
			{ Time = 1, Name = "hitreg" },
		},
	})

	Expect.True(clip:HasEvent("step"))
	Expect.False(clip:HasEvent("nope"))
	Expect.Equal(clip:GetEventTime("step"), 0.25)
	Expect.Equal(clip:GetEventTime("step", 2), 0.75)
	Expect.Equal(clip:GetEventTime("step", 3), nil)
	Expect.Equal(clip:GetEventTime("nope"), nil)
	Expect.Equal(#clip:GetEventTimes("step"), 2)
	Expect.Equal(#clip:GetEvents(), 3)
	Expect.Equal(#clip:GetEvents("nope"), 0)
end)

Test("GetEventsBetween uses half open ranges", function()
	const clip = makeClip({
		Events = {
			{ Time = 0, Name = "a" },
			{ Time = 0.5, Name = "b" },
			{ Time = 1, Name = "c" },
			{ Time = 2, Name = "d" },
		},
	})

	const function names(list)
		const result = {}
		for _, event in list do
			table.insert(result, event.Name)
		end

		return table.concat(result)
	end

	Expect.Equal(names(clip:GetEventsBetween(0, 1)), "bc")
	Expect.Equal(names(clip:GetEventsBetween(0, 1, true)), "abc")
	Expect.Equal(names(clip:GetEventsBetween(0.5, 2)), "cd")
	Expect.Equal(names(clip:GetEventsBetween(2, 0.5)), "cb")
	Expect.Equal(names(clip:GetEventsBetween(2, 0.5, true)), "dcb")
	Expect.Equal(names(clip:GetEventsBetween(0.6, 0.9)), "")
	Expect.Equal(names(clip:GetEventsBetween(1, 1)), "")
	Expect.Equal(names(clip:GetEventsBetween(1, 1, true)), "c")
end)

Test("windows pair start and end events", function()
	const clip = makeClip({
		Events = {
			{ Time = 0.2, Name = "hitreg_start" },
			{ Time = 0.6, Name = "hitreg_end" },
			{ Time = 1, Name = "hitreg_start" },
			{ Time = 1.4, Name = "hitreg_end" },
			{ Time = 1.6, Name = "block_start" },
			{ Time = 0.1, Name = "guard_end" },
		},
	})

	const windows = clip:GetWindows("hitreg")
	Expect.Equal(#windows, 2)
	Expect.Equal(windows[1].Start, 0.2)
	Expect.Equal(windows[1].Stop, 0.6)
	Expect.Equal(windows[2].Start, 1)

	Expect.True(clip:IsWindowActive("hitreg", 0.4))
	Expect.False(clip:IsWindowActive("hitreg", 0.8))
	Expect.True(clip:IsWindowActive("hitreg", 1.2))
	Expect.False(clip:IsWindowActive("hitreg", 1.9))

	Expect.True(clip:IsWindowActive("block", 1.9))
	Expect.Equal(clip:GetWindows("block")[1].Stop, 2)
	Expect.True(clip:IsWindowActive("guard", 0.05))
	Expect.False(clip:IsWindowActive("guard", 0.5))
	Expect.False(clip:IsWindowActive("missing", 0))
end)

Test("AddEvent and RemoveEvents rebuild the indexes", function()
	const clip = makeClip()
	clip:AddEvent(0.5, "swing_start")
	clip:AddEvent(1, "swing_end")
	Expect.Equal(#clip:GetWindows("swing"), 1)
	Expect.Equal(clip:RemoveEvents("swing_start"), 1)
	Expect.False(clip:HasEvent("swing_start"))
	Expect.Equal(clip:RemoveEvents("swing_start"), 0)
end)

Test("GetRootMotion returns the delta between two times", function()
	const clip = makeClip()
	const delta, rotationV, rotationW = clip:GetRootMotion("Torso", 0.5, 1.5)
	Expect.VectorNear(delta, vector.create(1, 2, 0))
	const expectedV, expectedW = Quat.FromAxisAngle(Y, 0.5)
	Expect.QuatNear(rotationV, rotationW, expectedV, expectedW, 2e-3)

	const empty = clip:GetRootMotion("Missing", 0, 1)
	Expect.VectorNear(empty, vector.zero)
end)

Test("GetRootMotion handles loop wraparound", function()
	const clip = Clip.New({
		Joints = { Root = { { Time = 0, Position = vector.zero }, { Time = 2, Position = vector.create(4, 0, 0) } } },
	})

	const wrapped = clip:GetRootMotion("Root", 1.5, 0.5, true)
	Expect.VectorNear(wrapped, vector.create(2, 0, 0))
	const plain = clip:GetRootMotion("Root", 1.5, 0.5, false)
	Expect.VectorNear(plain, vector.create(-2, 0, 0))
end)

Test("Reverse mirrors sampling and easing", function()
	const clip = Clip.New({
		Joints = {
			Torso = {
				{ Time = 0, Position = vector.zero, Quaternion = quaternion(Y, 0), Easing = "cubic_in" },
				{ Time = 1, Position = vector.create(1, 0, 0), Quaternion = quaternion(Y, 1), Easing = "bounce_out" },
				{ Time = 3, Position = vector.create(1, 6, 0), Quaternion = quaternion(Y, 0.2) },
			},
		},
		Events = {
			{ Time = 0.5, Name = "swing_start" },
			{ Time = 2, Name = "swing_end" },
			{ Time = 3, Name = "end" },
		},
	})

	const reversed = clip:Reverse()
	for step = 0, 30 do
		const time = step * 0.1
		const original, originalV, originalW = clip:SampleJoint("Torso", time)
		const mirrored, mirroredV, mirroredW = reversed:SampleJoint("Torso", clip.Length - time)
		Expect.VectorNear(mirrored, original, 1e-6, `t={time}`)
		Expect.QuatNear(mirroredV, mirroredW, originalV, originalW, 1e-6, `t={time}`)
	end

	Expect.Equal(reversed:GetEventTime("end"), 0)
	Expect.Near(reversed:GetEventTime("swing_end"), 2.5)
	Expect.Near(reversed:GetEventTime("swing_start"), 1)
	Expect.True(reversed:IsWindowActive("swing", 1.5))
	Expect.False(reversed:IsWindowActive("swing", 0.5))
end)

Test("ScaleTime speeds a clip up", function()
	const clip = makeClip({ Events = { { Time = 1, Name = "mid" } } })
	const fast = clip:ScaleTime(2)
	Expect.Equal(fast.Length, 1)
	Expect.Equal(fast:GetEventTime("mid"), 0.5)
	Expect.VectorNear(fast:SampleJoint("Torso", 0.25), (clip:SampleJoint("Torso", 0.5)))
	Expect.Throws(function()
		clip:ScaleTime(0)
	end)
end)

Test("Slice keeps linear motion exact", function()
	const clip = Clip.New({
		Joints = { Torso = { { Time = 0, Position = vector.zero }, { Time = 4, Position = vector.create(8, 0, 0) } } },
		Events = { { Time = 1, Name = "before" }, { Time = 2, Name = "inside" }, { Time = 3.5, Name = "after" } },
	})

	const piece = clip:Slice(1.5, 3)
	Expect.Near(piece.Length, 1.5)
	Expect.VectorNear(piece:SampleJoint("Torso", 0), vector.create(3, 0, 0))
	Expect.VectorNear(piece:SampleJoint("Torso", 0.75), vector.create(4.5, 0, 0))
	Expect.VectorNear(piece:SampleJoint("Torso", 1.5), vector.create(6, 0, 0))
	Expect.Equal(#piece.Events, 1)
	Expect.Near(piece:GetEventTime("inside"), 0.5)
end)

Test("Slice follows eased segments", function()
	const clip = Clip.New({
		Joints = {
			Torso = {
				{ Time = 0, Position = vector.zero, Easing = "cubic_in_out" },
				{ Time = 2, Position = vector.create(10, 0, 0), Easing = "quad_out" },
				{ Time = 4, Position = vector.create(10, 6, 0) },
			},
		},
	})

	const piece = clip:Slice(0.5, 3.2)
	for step = 0, 27 do
		const local_time = step * 0.1
		Expect.VectorNear(piece:SampleJoint("Torso", local_time), clip:SampleJoint("Torso", local_time + 0.5), 1e-5, `t={local_time}`)
	end
end)

Test("Slice of a single point makes a pose clip", function()
	const clip = makeClip()
	const piece = clip:Slice(1, 1)
	Expect.Equal(piece.Length, 0)
	Expect.VectorNear(piece:SampleJoint("Torso", 0), (clip:SampleJoint("Torso", 1)))
end)

Test("MakeAdditive records the reference pose", function()
	const clip = makeClip()
	const additive = clip:MakeAdditive(1)
	Expect.True(additive.Additive)
	Expect.False(clip.Additive)
	Expect.VectorNear(additive.Channels.Torso.RefPosition, vector.create(2, 0, 0))
	Expect.VectorNear(clip.Channels.Torso.RefPosition, vector.create(0, 0, 0))
end)

Test("joint filters and remapping", function()
	const clip = makeClip()
	Expect.Equal(#clip:KeepJoints({ "Torso" }).JointNames, 1)
	Expect.Equal(clip:RemoveJoints({ "Torso" }).JointNames[1], "Head")

	const remapped = clip:RemapJoints({ Torso = "UpperTorso" })
	Expect.True(remapped.Channels.UpperTorso ~= nil)
	Expect.Equal(remapped.Channels.Torso, nil)
	Expect.Throws(function()
		clip:RemapJoints({ Torso = "Head" })
	end, "maps two joints")
end)

Test("Bind caches per rig and reports unmatched joints", function()
	const rig = Rig.New({
		Name = "Torso",
		C0 = CFrame.new(0, 0, 0),
		C1 = CFrame.new(0, 0, 0),
		Children = { { Name = "Arm", C0 = CFrame.new(1, 0, 0), C1 = CFrame.new(0, 0, 0) } },
	})

	const clip = makeClip()
	const binding = clip:Bind(rig)
	Expect.Equal(clip:Bind(rig), binding)
	Expect.Equal(binding.Matched, 1)
	Expect.Equal(binding.Unmatched[1], "Head")
	Expect.True(binding.Channels[1] ~= false)
	Expect.Equal(binding.Channels[2], false)
end)

Test("clips have unique ids", function()
	Expect.True(makeClip().Id ~= makeClip().Id)
end)

Test("Describe lists events", function()
	const text = makeClip({ Events = { { Time = 0.5, Name = "hitreg", Value = "damage=3" } } }):Describe()
	Expect.True(string.find(text, "hitreg = damage=3", 1, true))
	Expect.True(string.find(text, "walk", 1, true))
end)

return nil
