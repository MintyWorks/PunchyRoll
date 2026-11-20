--!strict
--!native
--!optimize 2

const Quat = require("./Quat")

type PoseData = {
	Count: number,
	Positions: { vector },
	QuatV: { vector },
	QuatW: { number },
}

const Pose = {}
Pose.__index = Pose

export type Pose = typeof(setmetatable({} :: PoseData, Pose))

function Pose.New(count: number): Pose
	const positions = table.create(count, vector.zero)
	const quatV = table.create(count, vector.zero)
	const quatW = table.create(count, 1)

	return setmetatable({
		Count = count,
		Positions = positions,
		QuatV = quatV,
		QuatW = quatW,
	}, Pose)
end

function Pose.Reset(self: Pose)
	for index = 1, self.Count do
		self.Positions[index] = vector.zero
		self.QuatV[index] = vector.zero
		self.QuatW[index] = 1
	end
end

function Pose.Clone(self: Pose): Pose
	const copy = Pose.New(self.Count)
	copy:CopyFrom(self)
	return copy
end

function Pose.CopyFrom(self: Pose, other: Pose)
	assert(self.Count == other.Count, "Pose:CopyFrom expects poses with the same joint count")

	for index = 1, self.Count do
		self.Positions[index] = other.Positions[index]
		self.QuatV[index] = other.QuatV[index]
		self.QuatW[index] = other.QuatW[index]
	end
end

function Pose.Set(self: Pose, index: number, position: vector, quatV: vector, quatW: number)
	self.Positions[index] = position
	self.QuatV[index] = quatV
	self.QuatW[index] = quatW
end

function Pose.Get(self: Pose, index: number): (vector, vector, number)
	return self.Positions[index], self.QuatV[index], self.QuatW[index]
end

function Pose.Lerp(out: Pose, a: Pose, b: Pose, alpha: number, weights: { number }?)
	assert(out.Count == a.Count and a.Count == b.Count, "Pose.Lerp expects poses with the same joint count")

	for index = 1, out.Count do
		const t = if weights then alpha * weights[index] else alpha
		if t <= 0 then
			out.Positions[index] = a.Positions[index]
			out.QuatV[index] = a.QuatV[index]
			out.QuatW[index] = a.QuatW[index]
			continue
		end

		const pa = a.Positions[index]
		out.Positions[index] = pa + (b.Positions[index] - pa) * t
		out.QuatV[index], out.QuatW[index] =
			Quat.Nlerp(a.QuatV[index], a.QuatW[index], b.QuatV[index], b.QuatW[index], t)
	end
end

function Pose.Compose(out: Pose, base: Pose, delta: Pose, weight: number, weights: { number }?)
	assert(out.Count == base.Count and base.Count == delta.Count, "Pose.Compose expects poses with the same joint count")

	for index = 1, out.Count do
		const w = if weights then weight * weights[index] else weight
		if w <= 0 then
			out.Positions[index] = base.Positions[index]
			out.QuatV[index] = base.QuatV[index]
			out.QuatW[index] = base.QuatW[index]
			continue
		end

		out.Positions[index] = base.Positions[index] + delta.Positions[index] * w
		const scaledV, scaledW = Quat.Nlerp(vector.zero, 1, delta.QuatV[index], delta.QuatW[index], w)
		out.QuatV[index], out.QuatW[index] = Quat.Mul(scaledV, scaledW, base.QuatV[index], base.QuatW[index])
	end
end

return Pose
