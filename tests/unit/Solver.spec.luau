--!nocheck

const Harness = require("@tests/harness")
const Clip = require("@src/Clip")
const Mask = require("@src/Mask")
const Pose = require("@src/Pose")
const Quat = require("@src/Quat")
const Rig = require("@src/Rig")
const Solver = require("@src/Solver")

const Test, Expect = Harness.Test, Harness.Expect

const function makeRig()
	const identity = CFrame.new()
	return Rig.New({
		Name = "A",
		C0 = identity,
		C1 = identity,
		Children = {
			{ Name = "B", C0 = CFrame.new(0, 1, 0), C1 = identity },
			{ Name = "C", C0 = CFrame.new(1, 0, 0), C1 = identity },
		},
	})
end

const function pose(joints)
	const input = {}
	for name, position in joints do
		input[name] = { { Time = 0, Position = position } }
	end

	return Clip.New({ Joints = input })
end

const function layer(clip, weight, priority, extra)
	const result = { Clip = clip, Time = 0, Weight = weight, Priority = priority }
	if extra then
		for key, value in extra do
			result[key] = value
		end
	end

	return result
end

const function solve(rig, layers)
	const out = Pose.New(rig.Count)
	Solver.Solve(rig, layers, out)
	return out, function(name)
		return out.Positions[rig:GetIndex(name)]
	end
end

const X = vector.create(10, 0, 0)
const Y = vector.create(0, 10, 0)

Test("a single layer reproduces the clip", function()
	const rig = makeRig()
	const clip = Clip.New({
		Joints = {
			A = { { Time = 0, Position = vector.zero }, { Time = 2, Position = vector.create(4, 0, 0) } },
		},
	})

	const _, get = solve(rig, { layer(clip, 1, 0, { Time = 1 }) })
	Expect.VectorNear(get("A"), vector.create(2, 0, 0))
	Expect.VectorNear(get("B"), vector.zero)
end)

Test("untouched joints use the identity or rest pose", function()
	const rig = makeRig()
	const _, get = solve(rig, { layer(pose({ A = X }), 1, 0) })
	Expect.VectorNear(get("C"), vector.zero)

	const rest = Pose.New(rig.Count)
	rest:Set(rig:GetIndex("C"), vector.create(0, 0, 7), vector.zero, 1)
	rig:SetRestPose(rest)
	const _2, getWithRest = solve(rig, { layer(pose({ A = X }), 1, 0) })
	Expect.VectorNear(getWithRest("C"), vector.create(0, 0, 7))
	Expect.VectorNear(getWithRest("A"), X)
end)

Test("equal priority layers blend by weight", function()
	const rig = makeRig()
	const a = pose({ A = vector.zero })
	const b = pose({ A = X })

	const _, get = solve(rig, { layer(a, 1, 0), layer(b, 1, 0) })
	Expect.VectorNear(get("A"), vector.create(5, 0, 0))

	const _2, get2 = solve(rig, { layer(a, 3, 0), layer(b, 1, 0) })
	Expect.VectorNear(get2("A"), vector.create(2.5, 0, 0))
end)

Test("layer order does not matter inside a priority tier", function()
	const rig = makeRig()
	const a = pose({ A = vector.create(1, 0, 0) })
	const b = pose({ A = vector.create(5, 0, 0) })
	const c = pose({ A = vector.create(0, 9, 0) })

	const _, first = solve(rig, { layer(a, 1, 2), layer(b, 2, 2), layer(c, 0.5, 2) })
	const _2, second = solve(rig, { layer(c, 0.5, 2), layer(a, 1, 2), layer(b, 2, 2) })
	Expect.VectorNear(first("A"), second("A"))
end)

Test("a full weight higher priority layer overrides lower ones", function()
	const rig = makeRig()
	const low = pose({ A = X, B = Y })
	const high = pose({ A = vector.create(0, 0, 3) })

	const _, get = solve(rig, { layer(low, 1, 1), layer(high, 1, 5) })
	Expect.VectorNear(get("A"), vector.create(0, 0, 3))
	Expect.VectorNear(get("B"), Y)

	const _2, getReversed = solve(rig, { layer(high, 1, 5), layer(low, 1, 1) })
	Expect.VectorNear(getReversed("A"), vector.create(0, 0, 3))
	Expect.VectorNear(getReversed("B"), Y)
end)

Test("a partial weight higher priority layer lets the lower tier through", function()
	const rig = makeRig()
	const low = pose({ A = X })
	const high = pose({ A = Y })

	const _, get = solve(rig, { layer(low, 1, 1), layer(high, 0.25, 5) })
	Expect.VectorNear(get("A"), vector.create(7.5, 2.5, 0))
end)

Test("weights below one fade toward the rest pose", function()
	const rig = makeRig()
	const _, get = solve(rig, { layer(pose({ A = X }), 0.5, 0) })
	Expect.VectorNear(get("A"), vector.create(5, 0, 0))

	const rest = Pose.New(rig.Count)
	rest:Set(rig:GetIndex("A"), vector.create(0, 0, 10), vector.zero, 1)
	rig:SetRestPose(rest)
	const _2, getRest = solve(rig, { layer(pose({ A = X }), 0.5, 0) })
	Expect.VectorNear(getRest("A"), vector.create(5, 0, 5))
end)

Test("weights above one are normalized inside a tier", function()
	const rig = makeRig()
	const _, get = solve(rig, { layer(pose({ A = X }), 4, 0) })
	Expect.VectorNear(get("A"), X)
end)

Test("results do not depend on earlier solves", function()
	const rig = makeRig()
	const out = Pose.New(rig.Count)
	const scratch = Solver.NewScratch()

	Solver.Solve(rig, { layer(pose({ A = vector.create(99, 99, 99) }), 1, 0) }, out, scratch)
	Solver.Solve(rig, { layer(pose({ B = Y }), 1, 0), layer(pose({ B = X }), 1, 0) }, out, scratch)

	Expect.VectorNear(out.Positions[rig:GetIndex("A")], vector.zero)
	Expect.VectorNear(out.Positions[rig:GetIndex("B")], vector.create(5, 5, 0))
end)

Test("zero weight layers are ignored", function()
	const rig = makeRig()
	const _, get = solve(rig, { layer(pose({ A = X }), 0, 9), layer(pose({ A = Y }), 1, 0) })
	Expect.VectorNear(get("A"), Y)
end)

Test("masks scale a layer per joint", function()
	const rig = makeRig()
	const low = pose({ A = X, B = X })
	const high = pose({ A = Y, B = Y })
	const mask = Mask.FromJoints(rig, { "B" })

	const _, get = solve(rig, { layer(low, 1, 0), layer(high, 1, 5, { Mask = mask }) })
	Expect.VectorNear(get("A"), X)
	Expect.VectorNear(get("B"), Y)

	const half = Mask.FromJoints(rig, { B = 0.5 })
	const _2, getHalf = solve(rig, { layer(low, 1, 0), layer(high, 1, 5, { Mask = half }) })
	Expect.VectorNear(getHalf("B"), vector.create(5, 5, 0))
end)

Test("static fades reduce the weight near the clip edges", function()
	const rig = makeRig()
	const clip = Clip.New({
		Length = 2,
		Joints = { A = { { Time = 0, Position = X } } },
	})

	const _, atStart = solve(rig, { layer(clip, 1, 0, { Time = 0.25, FadeIn = 0.5 }) })
	Expect.VectorNear(atStart("A"), vector.create(5, 0, 0))

	const _2, atEnd = solve(rig, { layer(clip, 1, 0, { Time = 1.75, FadeOut = 0.5 }) })
	Expect.VectorNear(atEnd("A"), vector.create(5, 0, 0))

	const _3, middle = solve(rig, { layer(clip, 1, 0, { Time = 1, FadeIn = 0.5, FadeOut = 0.5 }) })
	Expect.VectorNear(middle("A"), X)

	const _4, gone = solve(rig, { layer(clip, 1, 0, { Time = 0, FadeIn = 0.5 }) })
	Expect.VectorNear(gone("A"), vector.zero)
end)

Test("cursors do not change results", function()
	const rig = makeRig()
	const keys = {}
	for index = 0, 15 do
		table.insert(keys, { Time = index * 0.3, Position = vector.create(index * index, 0, 0) })
	end

	const clip = Clip.New({ Joints = { A = keys, B = keys } })
	const cursors = {}
	for time = 0, 5, 0.07 do
		const _, plain = solve(rig, { layer(clip, 1, 0, { Time = time }) })
		const _2, cached = solve(rig, { layer(clip, 1, 0, { Time = time, Cursors = cursors }) })
		Expect.VectorNear(plain("A"), cached("A"), 1e-9)
		Expect.VectorNear(plain("B"), cached("B"), 1e-9)
	end
end)

Test("rotations blend on the shortest path", function()
	const rig = makeRig()
	const function rotated(w)
		return Clip.New({ Joints = { A = { { Time = 0, Quaternion = { 0, w * math.sin(0.2), 0, w * math.cos(0.2) } } } } })
	end

	const out = Pose.New(rig.Count)
	Solver.Solve(rig, { layer(rotated(1), 1, 0), layer(rotated(-1), 1, 0) }, out)
	const expectedV, expectedW = Quat.Normalize(vector.create(0, math.sin(0.2), 0), math.cos(0.2))
	Expect.QuatNear(out.QuatV[1], out.QuatW[1], expectedV, expectedW, 1e-6)
	Expect.True(vector.magnitude(out.QuatV[1]) > 0.1)
end)

Test("additive layers apply deltas on top of the base", function()
	const rig = makeRig()
	const base = pose({ A = X })
	const motion = Clip.New({
		Joints = {
			A = { { Time = 0, Position = vector.zero }, { Time = 1, Position = vector.create(0, 0, 4) } },
		},
	}):MakeAdditive(0)

	const _, full = solve(rig, { layer(base, 1, 0), layer(motion, 1, 9, { Time = 1 }) })
	Expect.VectorNear(full("A"), vector.create(10, 0, 4))

	const _2, half = solve(rig, { layer(base, 1, 0), layer(motion, 0.5, 9, { Time = 1 }) })
	Expect.VectorNear(half("A"), vector.create(10, 0, 2))

	const _3, atReference = solve(rig, { layer(base, 1, 0), layer(motion, 1, 9, { Time = 0 }) })
	Expect.VectorNear(atReference("A"), X)
end)

Test("additive layers rotate relative to the base", function()
	const rig = makeRig()
	const function rotation(angle)
		const v, w = Quat.FromAxisAngle(vector.create(0, 0, 1), angle)
		return { v.x, v.y, v.z, w }
	end

	const base = Clip.New({ Joints = { A = { { Time = 0, Quaternion = rotation(0.5) } } } })
	const lean = Clip.New({
		Joints = { A = { { Time = 0, Quaternion = rotation(0.1) }, { Time = 1, Quaternion = rotation(0.4) } } },
	}):MakeAdditive(0)

	const out = Pose.New(rig.Count)
	Solver.Solve(rig, { layer(base, 1, 0), layer(lean, 1, 1, { Time = 1 }) }, out)

	const expectedV, expectedW = Quat.FromAxisAngle(vector.create(0, 0, 1), 0.8)
	Expect.QuatNear(out.QuatV[1], out.QuatW[1], expectedV, expectedW, 1e-4)
end)

Test("the Additive flag on a layer overrides the clip", function()
	const rig = makeRig()
	const clip = pose({ A = X })
	const _, get = solve(rig, { layer(clip, 1, 0), layer(clip, 1, 5, { Additive = true }) })
	Expect.VectorNear(get("A"), X)
end)

Test("SolveAndCompose writes composed frames", function()
	const rig = makeRig()
	const clip = pose({ B = vector.create(0, 0, 2) })
	const root = CFrame.new(10, 0, 0)
	Solver.SolveAndCompose(rig, { layer(clip, 1, 0) }, root)

	Expect.CFrameNear(rig.FramesByName.A, root)
	Expect.CFrameNear(rig.FramesByName.B, root * CFrame.new(0, 1, 0) * CFrame.new(0, 0, 2))
	Expect.CFrameNear(rig.FramesByName.C, root * CFrame.new(1, 0, 0))
end)

Test("many layers stay allocation stable and correct", function()
	const rig = makeRig()
	const scratch = Solver.NewScratch()
	const out = Pose.New(rig.Count)
	const layers = {}
	for index = 1, 12 do
		table.insert(layers, layer(pose({ A = vector.create(index, 0, 0) }), 1, index % 3))
	end

	Solver.Solve(rig, layers, out, scratch)
	const first = out.Positions[1]
	for _ = 1, 50 do
		Solver.Solve(rig, layers, out, scratch)
	end

	Expect.VectorNear(out.Positions[1], first)
	Expect.Equal(#scratch.Entries, 12)
end)

return nil
