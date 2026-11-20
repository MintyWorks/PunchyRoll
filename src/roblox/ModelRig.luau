--!strict

const Rig = require("../Rig")

export type ModelRig = {
	Rig: Rig.Rig,
	Motors: { [string]: Motor6D },
	Parts: { [string]: BasePart },
}

const ModelRig = {}

function ModelRig.FromModel(model: Model): ModelRig
	const motors: { [string]: Motor6D } = {}
	const parts: { [string]: BasePart } = {}
	const limbs: { Rig.Limb } = {}
	const byPart1: { [string]: boolean } = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			const motor = descendant :: Motor6D
			const part0, part1 = motor.Part0, motor.Part1
			if part0 and part1 then
				byPart1[part1.Name] = true
			end
		end
	end

	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("Motor6D") then
			continue
		end

		const motor = descendant :: Motor6D
		const part0, part1 = motor.Part0, motor.Part1
		if not part0 or not part1 then
			continue
		end

		assert(motors[part1.Name] == nil, `Part '{part1.Name}' is driven by more than one Motor6D`)

		motors[part1.Name] = motor
		parts[part1.Name] = part1
		parts[part0.Name] = part0

		table.insert(limbs, {
			Name = part1.Name,
			Parent = if byPart1[part0.Name] then part0.Name else nil,
			C0 = motor.C0,
			C1 = motor.C1,
		})
	end

	const rig = Rig.FromLimbs(limbs)
	return { Rig = rig, Motors = motors, Parts = parts }
end

function ModelRig.WriteTransforms(modelRig: ModelRig)
	const rig = modelRig.Rig
	const transforms = rig.Transforms
	for name, motor in modelRig.Motors do
		const index = rig.NameToIndex[name]
		if index then
			motor.Transform = transforms[index]
		end
	end
end

function ModelRig.WriteParts(modelRig: ModelRig)
	const rig = modelRig.Rig
	const list: { BasePart } = {}
	const frames: { CFrame } = {}

	for index = 1, rig.Count do
		const part = modelRig.Parts[rig.Names[index]]
		if part then
			table.insert(list, part)
			table.insert(frames, rig.Frames[index])
		end
	end

	workspace:BulkMoveTo(list, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

return ModelRig
