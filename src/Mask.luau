--!strict

const Rig = require("./Rig")

type MaskData = {
	Rig: Rig.Rig,
	Weights: { number },
}

const Mask = {}
Mask.__index = Mask

export type Mask = typeof(setmetatable({} :: MaskData, Mask))

const function resolve(rig: Rig.Rig, joint: string | number): number
	const index = if type(joint) == "string" then rig.NameToIndex[joint] else joint
	assert(index ~= nil and index >= 1 and index <= rig.Count, `Mask: unknown joint '{joint}'`)
	return index
end

function Mask.New(rig: Rig.Rig, default: number?): Mask
	return setmetatable({
		Rig = rig,
		Weights = table.create(rig.Count, default or 1),
	}, Mask)
end

function Mask.FromJoints(rig: Rig.Rig, joints: { string } | { [string]: number }, weight: number?): Mask
	const mask = Mask.New(rig, 0)
	for key, value in joints :: any do
		if type(key) == "number" then
			mask:Set(value, weight or 1)
		else
			mask:Set(key, value)
		end
	end

	return mask
end

function Mask.FromSubtree(rig: Rig.Rig, joint: string | number, weight: number?): Mask
	const mask = Mask.New(rig, 0)
	mask:SetSubtree(joint, weight or 1)
	return mask
end

function Mask.Set(self: Mask, joint: string | number, weight: number): Mask
	self.Weights[resolve(self.Rig, joint)] = math.clamp(weight, 0, 1)
	return self
end

function Mask.SetSubtree(self: Mask, joint: string | number, weight: number): Mask
	const clamped = math.clamp(weight, 0, 1)
	for _, index in self.Rig:GetSubtree(joint) do
		self.Weights[index] = clamped
	end

	return self
end

function Mask.Get(self: Mask, joint: string | number): number
	return self.Weights[resolve(self.Rig, joint)]
end

function Mask.Falloff(self: Mask, joint: string | number, weight: number, depthStep: number): Mask
	const root = resolve(self.Rig, joint)
	const depth: { [number]: number } = { [root] = 0 }

	for _, index in self.Rig:GetSubtree(root) do
		if index ~= root then
			depth[index] = depth[self.Rig.Parents[index]] + 1
		end

		self.Weights[index] = math.clamp(weight - depth[index] * depthStep, 0, 1)
	end

	return self
end

function Mask.Invert(self: Mask): Mask
	const result = Mask.New(self.Rig, 0)
	for index = 1, self.Rig.Count do
		result.Weights[index] = 1 - self.Weights[index]
	end

	return result
end

function Mask.Multiply(self: Mask, other: Mask): Mask
	assert(self.Rig == other.Rig, "Mask:Multiply expects masks made for the same rig")

	const result = Mask.New(self.Rig, 0)
	for index = 1, self.Rig.Count do
		result.Weights[index] = self.Weights[index] * other.Weights[index]
	end

	return result
end

function Mask.Clone(self: Mask): Mask
	const copy = Mask.New(self.Rig, 0)
	table.move(self.Weights, 1, self.Rig.Count, 1, copy.Weights)
	return copy
end

return Mask
