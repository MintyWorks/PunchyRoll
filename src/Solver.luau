--!strict
--!optimize 2

const Clip = require("./Clip")
const Mask = require("./Mask")
const Pose = require("./Pose")
const Quat = require("./Quat")
const Rig = require("./Rig")
const Timeline = require("./Timeline")

export type Layer = {
	Clip: Clip.Clip,
	Time: number,
	Weight: number,
	Priority: number,
	Additive: boolean?,
	Mask: Mask.Mask?,
	FadeIn: number?,
	FadeOut: number?,
	Cursors: { number }?,
}

type Entry = {
	Channels: { Clip.Channel | false },
	Weight: number,
	Time: number,
	Priority: number,
	Order: number,
	MaskWeights: { number }?,
	Cursors: { number }?,
}

export type Scratch = {
	Entries: { Entry },
	Base: { Entry },
	Additive: { Entry },
}

const EPSILON = 1e-4

const sampleChannel = Clip.SampleChannel

const Solver = {}

function Solver.NewScratch(): Scratch
	return {
		Entries = {},
		Base = {},
		Additive = {},
	}
end

const function acquire(scratch: Scratch, index: number): Entry
	const existing = scratch.Entries[index]
	if existing then
		return existing
	end

	const entry: Entry = {
		Channels = {},
		Weight = 0,
		Time = 0,
		Priority = 0,
		Order = 0,
		MaskWeights = nil,
		Cursors = nil,
	}

	scratch.Entries[index] = entry
	return entry
end

const function before(a: Entry, b: Entry): boolean
	if a.Priority ~= b.Priority then
		return a.Priority > b.Priority
	end

	return a.Order < b.Order
end

const function sortEntries(list: { Entry }, count: number)
	for index = 2, count do
		const entry = list[index]
		local position = index - 1
		while position >= 1 and before(entry, list[position]) do
			list[position + 1] = list[position]
			position -= 1
		end

		list[position + 1] = entry
	end
end

function Solver.Solve(rig: Rig.Rig, layers: { Layer }, out: Pose.Pose, scratch: Scratch?)
	const state = scratch or Solver.NewScratch()
	const base = state.Base
	const additive = state.Additive

	local baseCount = 0
	local additiveCount = 0
	local used = 0

	for order, layer in layers do
		local weight = layer.Weight
		if weight <= EPSILON then
			continue
		end

		const clip = layer.Clip
		const fadeIn = layer.FadeIn or 0
		const fadeOut = layer.FadeOut or 0
		if fadeIn > 0 or fadeOut > 0 then
			weight *= Timeline.FadeInfluence(layer.Time, clip.Length, fadeIn, fadeOut)
			if weight <= EPSILON then
				continue
			end
		end

		used += 1
		const entry = acquire(state, used)
		const binding = clip:Bind(rig)
		entry.Channels = binding.Channels
		entry.Weight = weight
		entry.Time = layer.Time
		entry.Priority = layer.Priority
		entry.Order = order
		entry.MaskWeights = if layer.Mask then layer.Mask.Weights else nil
		entry.Cursors = layer.Cursors

		const isAdditive = if layer.Additive ~= nil then layer.Additive else clip.Additive
		if isAdditive then
			additiveCount += 1
			additive[additiveCount] = entry
		else
			baseCount += 1
			base[baseCount] = entry
		end
	end

	sortEntries(base, baseCount)

	const count = rig.Count
	const rest = rig.Rest
	const positions = out.Positions
	const quatV = out.QuatV
	const quatW = out.QuatW

	for joint = 1, count do
		local remaining = 1
		local accumulatedWeight = 0
		local position = vector.zero
		local rotation = vector.zero
		local scalar = 1

		local cursor = 1
		while cursor <= baseCount and remaining > EPSILON do
			const priority = base[cursor].Priority

			local tierWeight = 0
			local tierPosition = vector.zero
			local tierRotation = vector.zero
			local tierScalar = 1

			local next = cursor
			while next <= baseCount and base[next].Priority == priority do
				const entry = base[next]
				const channel = entry.Channels[joint]
				if channel then
					local weight = entry.Weight
					const maskWeights = entry.MaskWeights
					if maskWeights then
						weight *= maskWeights[joint]
					end

					if weight > EPSILON then
						const cursors = entry.Cursors
						const p, v, s, found = sampleChannel(channel, entry.Time, if cursors then cursors[joint] or 1 else 1)
						if cursors then
							cursors[joint] = found
						end

						if tierWeight == 0 then
							tierPosition, tierRotation, tierScalar = p, v, s
						else
							const t = weight / (tierWeight + weight)
							tierPosition += (p - tierPosition) * t
							tierRotation, tierScalar = Quat.Nlerp(tierRotation, tierScalar, v, s, t)
						end

						tierWeight += weight
					end
				end

				next += 1
			end

			cursor = next

			if tierWeight > 0 then
				const share = remaining * math.min(1, tierWeight)
				if accumulatedWeight == 0 then
					position, rotation, scalar = tierPosition, tierRotation, tierScalar
				else
					const t = share / (accumulatedWeight + share)
					position += (tierPosition - position) * t
					rotation, scalar = Quat.Nlerp(rotation, scalar, tierRotation, tierScalar, t)
				end

				accumulatedWeight += share
				remaining -= share
			end
		end

		if remaining > EPSILON or accumulatedWeight == 0 then
			const restPosition = if rest then rest.Positions[joint] else vector.zero
			const restRotation = if rest then rest.QuatV[joint] else vector.zero
			const restScalar = if rest then rest.QuatW[joint] else 1

			if accumulatedWeight == 0 then
				position, rotation, scalar = restPosition, restRotation, restScalar
			else
				const t = remaining / (accumulatedWeight + remaining)
				position += (restPosition - position) * t
				rotation, scalar = Quat.Nlerp(rotation, scalar, restRotation, restScalar, t)
			end
		end

		positions[joint] = position
		quatV[joint] = rotation
		quatW[joint] = scalar
	end

	for index = 1, additiveCount do
		const entry = additive[index]
		const maskWeights = entry.MaskWeights
		const cursors = entry.Cursors

		for joint = 1, count do
			const channel = entry.Channels[joint]
			if not channel then
				continue
			end

			local weight = entry.Weight
			if maskWeights then
				weight *= maskWeights[joint]
			end

			if weight <= EPSILON then
				continue
			end

			const p, v, s, found = sampleChannel(channel, entry.Time, if cursors then cursors[joint] or 1 else 1)
			if cursors then
				cursors[joint] = found
			end

			const conjugateV, conjugateW = Quat.Conjugate(channel.RefQuatV, channel.RefQuatW)
			const deltaV, deltaW = Quat.Mul(v, s, conjugateV, conjugateW)
			const scaledV, scaledW = Quat.Nlerp(vector.zero, 1, deltaV, deltaW, weight)

			positions[joint] += (p - channel.RefPosition) * weight
			quatV[joint], quatW[joint] = Quat.Mul(scaledV, scaledW, quatV[joint], quatW[joint])
		end
	end
end

function Solver.SolveAndCompose(
	rig: Rig.Rig,
	layers: { Layer },
	root: CFrame,
	out: Pose.Pose?,
	scratch: Scratch?
): Pose.Pose
	const pose = out or Pose.New(rig.Count)
	Solver.Solve(rig, layers, pose, scratch)
	rig:Compose(pose, root)
	return pose
end

return Solver
