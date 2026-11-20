--!nocheck

const Harness = require("@tests/harness")
const Mask = require("@src/Mask")
const Pose = require("@src/Pose")
const Quat = require("@src/Quat")
const Rig = require("@src/Rig")

const Test, Expect = Harness.Test, Harness.Expect

const function makeRig()
	return Rig.New({
		Name = "Torso",
		C0 = CFrame.new(0, 1, 0),
		C1 = CFrame.new(0, 0, 0),
		Children = {
			{ Name = "Head", C0 = CFrame.new(0, 1.5, 0), C1 = CFrame.new(0, -0.5, 0) },
			{
				Name = "Left Arm",
				C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
				C1 = CFrame.new(0, 0.5, 0),
				Children = { { Name = "Left Hand", C0 = CFrame.new(0, -1, 0), C1 = CFrame.new(0, 0, 0) } },
			},
			{ Name = "Right Arm", C0 = CFrame.new(1, 0.5, 0), C1 = CFrame.new(0, 0.5, 0) },
		},
	})
end

Test("Rig.New orders limbs parents first", function()
	const rig = makeRig()
	Expect.Equal(rig.Count, 5)
	for index = 1, rig.Count do
		Expect.True(rig.Parents[index] < index)
	end

	Expect.Equal(rig.Parents[rig:GetIndex("Torso")], 0)
	Expect.Equal(rig.Names[rig.Parents[rig:GetIndex("Left Hand")]], "Left Arm")
	Expect.True(rig:Has("Head"))
	Expect.False(rig:Has("Tail"))
end)

Test("Rig.FromLimbs accepts any order and rejects bad input", function()
	const rig = Rig.FromLimbs({
		{ Name = "Hand", Parent = "Arm", C0 = CFrame.new(), C1 = CFrame.new() },
		{ Name = "Arm", Parent = "Torso", C0 = CFrame.new(), C1 = CFrame.new() },
		{ Name = "Torso", C0 = CFrame.new(), C1 = CFrame.new() },
	})

	Expect.Equal(rig.Names[1], "Torso")
	Expect.True(rig:GetIndex("Arm") < rig:GetIndex("Hand"))

	Expect.Throws(function()
		Rig.FromLimbs({ { Name = "A", Parent = "B", C0 = CFrame.new(), C1 = CFrame.new() } })
	end, "unknown limb")

	Expect.Throws(function()
		Rig.FromLimbs({
			{ Name = "A", C0 = CFrame.new(), C1 = CFrame.new() },
			{ Name = "A", C0 = CFrame.new(), C1 = CFrame.new() },
		})
	end, "Duplicate")

	Expect.Throws(function()
		Rig.FromLimbs({
			{ Name = "A", Parent = "B", C0 = CFrame.new(), C1 = CFrame.new() },
			{ Name = "B", Parent = "A", C0 = CFrame.new(), C1 = CFrame.new() },
		})
	end, "cycle")
end)

Test("identity pose composes to the bind pose", function()
	const rig = makeRig()
	const root = CFrame.new(5, 2, -3) * CFrame.Angles(0, 0.7, 0)
	rig:Compose(rig:CreatePose(), root)

	const torso = root * CFrame.new(0, 1, 0) * CFrame.new(0, 0, 0):Inverse()
	Expect.CFrameNear(rig.FramesByName.Torso, torso)

	const head = torso * CFrame.new(0, 1.5, 0) * CFrame.new(0, -0.5, 0):Inverse()
	Expect.CFrameNear(rig.FramesByName.Head, head)
	Expect.CFrameNear(rig.FramesByName.root, root)
	Expect.CFrameNear(rig.Frames[rig:GetIndex("Head")], head)
end)

Test("Compose applies the joint transform between c0 and c1", function()
	const rig = makeRig()
	const pose = rig:CreatePose()
	const headIndex = rig:GetIndex("Head")
	const axis = vector.create(1, 0, 0)
	const qv, qw = Quat.FromAxisAngle(axis, 0.9)
	pose:Set(headIndex, vector.create(0.1, 0.2, 0.3), qv, qw)

	const root = CFrame.new(1, 2, 3)
	rig:Compose(pose, root)

	const transform = CFrame.new(0.1, 0.2, 0.3) * CFrame.fromAxisAngle(axis, 0.9)
	const torso = root * CFrame.new(0, 1, 0)
	const expected = torso * CFrame.new(0, 1.5, 0) * transform * CFrame.new(0, -0.5, 0):Inverse()
	Expect.CFrameNear(rig.FramesByName.Head, expected)
	Expect.CFrameNear(rig.Transforms[headIndex], transform)
end)

Test("children follow parent transforms", function()
	const rig = makeRig()
	const pose = rig:CreatePose()
	const qv, qw = Quat.FromAxisAngle(vector.create(0, 0, 1), 1)
	pose:Set(rig:GetIndex("Left Arm"), vector.zero, qv, qw)
	rig:Compose(pose, CFrame.new())

	const armFrame = rig.FramesByName["Left Arm"]
	const handFrame = rig.FramesByName["Left Hand"]
	const expectedHand = armFrame * CFrame.new(0, 0, 0):Inverse()
	Expect.CFrameNear(handFrame, armFrame * rig.C0[rig:GetIndex("Left Hand")] * rig.C1Inverse[rig:GetIndex("Left Hand")])
	Expect.True(not handFrame:FuzzyEq(rig.Frames[1], 0.01))
	Expect.True(expectedHand ~= nil)
end)

Test("subtrees and ancestors", function()
	const rig = makeRig()
	const arm = rig:GetIndex("Left Arm")
	const subtree = rig:GetSubtree("Left Arm")
	Expect.Equal(#subtree, 2)
	Expect.Equal(subtree[1], arm)
	Expect.Equal(rig:GetSubtree(arm), subtree)
	Expect.Equal(#rig:GetSubtree("Torso"), 5)
	Expect.Equal(#rig:GetAncestors("Left Hand"), 3)
	Expect.Throws(function()
		rig:GetSubtree("Nope")
	end)
end)

Test("OverrideFrame moves joints and their descendants", function()
	const rig = makeRig()
	rig:Compose(rig:CreatePose(), CFrame.new())

	const arm = rig:GetIndex("Left Arm")
	const hand = rig:GetIndex("Left Hand")
	const originalArm = rig.Frames[arm]
	const originalHand = rig.Frames[hand]
	const shift = CFrame.new(0, 3, 0)

	rig:OverrideFrame(arm, shift * originalArm)
	Expect.CFrameNear(rig.Frames[hand], shift * originalHand)
	Expect.CFrameNear(rig.FramesByName["Left Hand"], shift * originalHand)

	const transform = rig.Transforms[arm]
	const parentFrame = rig:GetParentFrame(arm)
	Expect.CFrameNear(parentFrame * rig.C0[arm] * transform * rig.C1Inverse[arm], shift * originalArm)
end)

Test("constraints run after composing and can be toggled", function()
	const rig = makeRig()
	local calls = 0
	const constraint = {
		Enabled = true,
		Apply = function(self, target)
			calls += 1
			Expect.Equal(target, rig)
		end,
	}

	rig:AddConstraint(constraint)
	rig:Compose(rig:CreatePose(), CFrame.new())
	Expect.Equal(calls, 1)

	constraint.Enabled = false
	rig:Compose(rig:CreatePose(), CFrame.new())
	Expect.Equal(calls, 1)

	rig:RemoveConstraint(constraint)
	constraint.Enabled = true
	rig:Compose(rig:CreatePose(), CFrame.new())
	Expect.Equal(calls, 1)
end)

Test("rest pose is used by CreatePose", function()
	const rig = makeRig()
	const rest = Pose.New(rig.Count)
	rest:Set(1, vector.create(0, 5, 0), vector.zero, 1)
	rig:SetRestPose(rest)
	Expect.VectorNear(rig:CreatePose().Positions[1], vector.create(0, 5, 0))
	rig:SetRestPose(nil)
	Expect.VectorNear(rig:CreatePose().Positions[1], vector.zero)

	Expect.Throws(function()
		rig:SetRestPose(Pose.New(2))
	end, "joint count")
end)

Test("Describe prints the hierarchy", function()
	const text = makeRig():Describe()
	Expect.True(string.find(text, "Torso\n  Head", 1, true))
	Expect.True(string.find(text, "    Left Hand", 1, true))
end)

Test("masks target joints and subtrees", function()
	const rig = makeRig()
	const mask = Mask.FromSubtree(rig, "Left Arm")
	Expect.Equal(mask:Get("Left Arm"), 1)
	Expect.Equal(mask:Get("Left Hand"), 1)
	Expect.Equal(mask:Get("Head"), 0)

	const inverted = mask:Invert()
	Expect.Equal(inverted:Get("Head"), 1)
	Expect.Equal(inverted:Get("Left Hand"), 0)

	const byList = Mask.FromJoints(rig, { "Head", "Torso" })
	Expect.Equal(byList:Get("Torso"), 1)
	Expect.Equal(byList:Get("Right Arm"), 0)

	const byWeights = Mask.FromJoints(rig, { Head = 0.25 })
	Expect.Equal(byWeights:Get("Head"), 0.25)

	const product = byList:Multiply(byWeights)
	Expect.Equal(product:Get("Head"), 0.25)
	Expect.Equal(product:Get("Torso"), 0)

	const copy = mask:Clone()
	copy:Set("Head", 0.5)
	Expect.Equal(mask:Get("Head"), 0)
	Expect.Equal(copy:Get("Head"), 0.5)

	Expect.Throws(function()
		mask:Get("Nope")
	end, "unknown joint")
end)

Test("mask falloff fades with depth", function()
	const rig = makeRig()
	const mask = Mask.New(rig, 0):Falloff("Left Arm", 1, 0.25)
	Expect.Equal(mask:Get("Left Arm"), 1)
	Expect.Equal(mask:Get("Left Hand"), 0.75)
	Expect.Equal(mask:Get("Head"), 0)
end)

return nil
