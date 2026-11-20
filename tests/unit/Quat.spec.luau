--!nocheck

const Harness = require("@tests/harness")
const Quat = require("@src/Quat")

const Test, Expect = Harness.Test, Harness.Expect

const function matrixOf(cframe)
	const _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
	return r00, r01, r02, r10, r11, r12, r20, r21, r22
end

Test("Quat.Mul with identity returns the same rotation", function()
	const v, w = Quat.FromAxisAngle(vector.create(0, 1, 0), 0.7)
	const rv, rw = Quat.Mul(vector.zero, 1, v, w)
	Expect.QuatNear(rv, rw, v, w)
	const lv, lw = Quat.Mul(v, w, vector.zero, 1)
	Expect.QuatNear(lv, lw, v, w)
end)

Test("Quat.Mul composes rotations like matrices", function()
	const av, aw = Quat.FromAxisAngle(vector.create(1, 0, 0), 0.4)
	const bv, bw = Quat.FromAxisAngle(vector.create(0, 0, 1), 1.1)
	const cv, cw = Quat.Mul(av, aw, bv, bw)

	const expected = CFrame.fromAxisAngle(vector.create(1, 0, 0), 0.4) * CFrame.fromAxisAngle(vector.create(0, 0, 1), 1.1)
	const point = vector.create(1, 2, 3)
	Expect.VectorNear(Quat.Rotate(cv, cw, point), expected * point)
end)

Test("Quat.Conjugate is the inverse", function()
	const v, w = Quat.Normalize(vector.create(0.3, -0.2, 0.5), 0.8)
	const cv, cw = Quat.Conjugate(v, w)
	const rv, rw = Quat.Mul(v, w, cv, cw)
	Expect.VectorNear(rv, vector.zero)
	Expect.Near(rw, 1)
end)

Test("Quat.Normalize handles zero quaternions", function()
	const v, w = Quat.Normalize(vector.zero, 0)
	Expect.VectorNear(v, vector.zero)
	Expect.Equal(w, 1)
end)

Test("Quat.Nlerp takes the shortest path", function()
	const av, aw = Quat.FromAxisAngle(vector.create(0, 1, 0), 0.2)
	const bv, bw = Quat.FromAxisAngle(vector.create(0, 1, 0), 0.6)
	const rv, rw = Quat.Nlerp(av, aw, -bv, -bw, 0.5)
	const expectedV, expectedW = Quat.FromAxisAngle(vector.create(0, 1, 0), 0.4)
	Expect.QuatNear(rv, rw, expectedV, expectedW, 1e-3)
end)

Test("Quat.Slerp matches half angle", function()
	const av, aw = Quat.FromAxisAngle(vector.create(1, 0, 0), 0)
	const bv, bw = Quat.FromAxisAngle(vector.create(1, 0, 0), 2)
	const rv, rw = Quat.Slerp(av, aw, bv, bw, 0.5)
	const expectedV, expectedW = Quat.FromAxisAngle(vector.create(1, 0, 0), 1)
	Expect.QuatNear(rv, rw, expectedV, expectedW)
end)

Test("Quat.Rotate matches CFrame rotation", function()
	const axis = vector.normalize(vector.create(1, 2, 3))
	const v, w = Quat.FromAxisAngle(axis, 1.3)
	const point = vector.create(-2, 0.5, 4)
	Expect.VectorNear(Quat.Rotate(v, w, point), CFrame.fromAxisAngle(axis, 1.3) * point)
end)

Test("Quat.ToAxisAngle round trips", function()
	const axis = vector.normalize(vector.create(0.2, 1, -0.4))
	const v, w = Quat.FromAxisAngle(axis, 2.2)
	const outAxis, angle = Quat.ToAxisAngle(v, w)
	Expect.VectorNear(outAxis, axis)
	Expect.Near(angle, 2.2)

	const identityAxis, identityAngle = Quat.ToAxisAngle(vector.zero, 1)
	Expect.Equal(identityAngle, 0)
	Expect.VectorNear(identityAxis, vector.create(1, 0, 0))
end)

Test("Quat.FromTo rotates one direction onto another", function()
	const from = vector.normalize(vector.create(1, 0, 0))
	const to = vector.normalize(vector.create(0.2, 0.9, -0.3))
	const v, w = Quat.FromTo(from, to)
	Expect.VectorNear(Quat.Rotate(v, w, from), to, 1e-5)
end)

Test("Quat.FromTo handles opposite directions", function()
	const from = vector.create(0, 0, 1)
	const to = vector.create(0, 0, -1)
	const v, w = Quat.FromTo(from, to)
	Expect.VectorNear(Quat.Rotate(v, w, from), to, 1e-5)
	const fromX = vector.create(1, 0, 0)
	const vx, wx = Quat.FromTo(fromX, vector.create(-1, 0, 0))
	Expect.VectorNear(Quat.Rotate(vx, wx, fromX), vector.create(-1, 0, 0), 1e-5)
end)

Test("Quat.AngleBetween measures the angular distance", function()
	const av, aw = Quat.FromAxisAngle(vector.create(0, 1, 0), 0.3)
	const bv, bw = Quat.FromAxisAngle(vector.create(0, 1, 0), 1.1)
	Expect.Near(Quat.AngleBetween(av, aw, bv, bw), 0.8, 1e-5)
	Expect.Near(Quat.AngleBetween(av, aw, -av, -aw), 0, 1e-6)
end)

Test("Quat.ScaleAngle scales the rotation", function()
	const v, w = Quat.FromAxisAngle(vector.create(0, 0, 1), 1.2)
	const sv, sw = Quat.ScaleAngle(v, w, 0.5)
	const expectedV, expectedW = Quat.FromAxisAngle(vector.create(0, 0, 1), 0.6)
	Expect.QuatNear(sv, sw, expectedV, expectedW)
end)

Test("Quat.FromMatrix matches CFrame matrices for many rotations", function()
	for _, axis in { vector.create(1, 0, 0), vector.create(0, 1, 0), vector.create(0, 0, 1), vector.normalize(vector.create(1, 1, 1)), vector.normalize(vector.create(-1, 2, 0.5)) } do
		for _, angle in { 0.1, 1, 2, 3, 3.1415, -2.5, 4.5 } do
			const cframe = CFrame.fromAxisAngle(axis, angle)
			const v, w = Quat.FromMatrix(matrixOf(cframe))
			const point = vector.create(0.3, -1.2, 2)
			Expect.VectorNear(Quat.Rotate(v, w, point), cframe * point, 1e-4, `axis {axis} angle {angle}`)
		end
	end
end)

Test("Quat.ToMatrix is the inverse of FromMatrix", function()
	const v, w = Quat.FromAxisAngle(vector.normalize(vector.create(0.4, 0.1, -0.9)), 2.7)
	const matrix = { Quat.ToMatrix(v, w) }
	const rv, rw = Quat.FromMatrix(table.unpack(matrix))
	Expect.QuatNear(rv, rw, v, w)
end)

return nil
