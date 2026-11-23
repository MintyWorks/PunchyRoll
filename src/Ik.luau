--!strict
--!optimize 2

const Quat = require("./Quat")
const Rig = require("./Rig")

export type Target = vector | (() -> vector?)

export type TwoBoneOptions = {
	Upper: string,
	Mid: string,
	Tip: string,
	Target: Target?,
	Pole: Target?,
	Weight: number?,
	Enabled: boolean?,
}

export type LookAtOptions = {
	Joint: string,
	Axis: vector?,
	Target: Target?,
	Weight: number?,
	MaxAngle: number?,
	Enabled: boolean?,
}

export type TwoBone = {
	Enabled: boolean,
	Weight: number,
	Target: Target?,
	Pole: Target?,
	Upper: number,
	Mid: number,
	Tip: number,
	Apply: (self: TwoBone, rig: any) -> (),
}

export type LookAt = {
	Enabled: boolean,
	Weight: number,
	MaxAngle: number?,
	Target: Target?,
	Axis: vector,
	Joint: number,
	Apply: (self: LookAt, rig: any) -> (),
}

const EPSILON = 1e-4

const Ik = {}

const function resolve(target: Target?): vector?
	if target == nil then
		return nil
	end

	if type(target) == "function" then
		return target()
	end

	return target
end

const function indexOf(rig: Rig.Rig, name: string): number
	const index = rig:GetIndex(name)
	assert(index, `Unknown joint '{name}'`)
	return index
end

const function pivot(rig: Rig.Rig, index: number): vector
	return (rig:GetParentFrame(index) * rig.C0[index]).Position :: any
end

const function rotateAbout(frame: CFrame, center: vector, qv: vector, qw: number): CFrame
	const rotation = CFrame.new(0, 0, 0, qv.x, qv.y, qv.z, qw)
	return CFrame.new(center.x, center.y, center.z) * rotation * CFrame.new(-center.x, -center.y, -center.z) * frame
end

const function perpendicular(direction: vector): vector
	const helper = if math.abs(direction.y) < 0.9 then vector.create(0, 1, 0) else vector.create(1, 0, 0)
	return vector.normalize(vector.cross(direction, helper))
end

const function safeNormalize(value: vector, fallback: vector): vector
	const length = vector.magnitude(value)
	if length < EPSILON then
		return fallback
	end

	return value / length
end

const function weighted(qv: vector, qw: number, weight: number): (vector, number)
	if weight >= 1 then
		return qv, qw
	end

	return Quat.Nlerp(vector.zero, 1, qv, qw, weight)
end

const function applyTwoBone(self: TwoBone, rig: Rig.Rig)
	const weight = math.clamp(self.Weight, 0, 1)
	const target = resolve(self.Target)
	if not target or weight <= 0 then
		return
	end

	const upper, mid, tip = self.Upper, self.Mid, self.Tip
	const origin = pivot(rig, upper)
	const elbow = pivot(rig, mid)
	const hand = pivot(rig, tip)

	const upperLength = vector.magnitude(elbow - origin)
	const lowerLength = vector.magnitude(hand - elbow)
	if upperLength < EPSILON or lowerLength < EPSILON then
		return
	end

	const toTarget = target - origin
	const reach = vector.magnitude(toTarget)
	const direction = safeNormalize(toTarget, vector.normalize(hand - origin))
	const maximum = upperLength + lowerLength - EPSILON
	const minimum = math.abs(upperLength - lowerLength) + EPSILON
	const distance = math.clamp(reach, minimum, maximum)

	const along = (upperLength * upperLength - lowerLength * lowerLength + distance * distance) / (2 * distance)
	const height = math.sqrt(math.max(upperLength * upperLength - along * along, 0))

	local bend = elbow - origin
	const pole = resolve(self.Pole)
	if pole then
		bend = pole - origin
	end

	bend -= direction * vector.dot(bend, direction)
	bend = safeNormalize(bend, perpendicular(direction))

	const newElbow = origin + direction * along + bend * height
	const reached = origin + direction * distance

	const firstV, firstW = Quat.FromTo(vector.normalize(elbow - origin), vector.normalize(newElbow - origin))
	const blendedFirstV, blendedFirstW = weighted(firstV, firstW, weight)
	rig:OverrideFrame(upper, rotateAbout(rig.Frames[upper], origin, blendedFirstV, blendedFirstW))

	const currentElbow = pivot(rig, mid)
	const currentHand = pivot(rig, tip)
	const goal = if weight >= 1 then reached else currentHand + (reached - currentHand) * weight
	const secondV, secondW = Quat.FromTo(
		safeNormalize(currentHand - currentElbow, vector.create(0, 1, 0)),
		safeNormalize(goal - currentElbow, vector.create(0, 1, 0))
	)
	rig:OverrideFrame(mid, rotateAbout(rig.Frames[mid], currentElbow, secondV, secondW))
end

const function applyLookAt(self: LookAt, rig: Rig.Rig)
	const weight = math.clamp(self.Weight, 0, 1)
	const target = resolve(self.Target)
	if not target or weight <= 0 then
		return
	end

	const index = self.Joint
	const frame = rig.Frames[index]
	const position: vector = frame.Position :: any
	const current = vector.normalize(frame:VectorToWorldSpace(self.Axis :: any) :: any)
	const wanted = safeNormalize(target - position, current)

	local qv, qw = Quat.FromTo(current, wanted)

	const limit = self.MaxAngle
	if limit then
		const axis, angle = Quat.ToAxisAngle(qv, qw)
		if angle > limit then
			qv, qw = Quat.FromAxisAngle(axis, limit)
		end
	end

	qv, qw = weighted(qv, qw, weight)
	rig:OverrideFrame(index, rotateAbout(frame, position, qv, qw))
end

function Ik.TwoBone(rig: Rig.Rig, options: TwoBoneOptions): TwoBone
	const constraint: TwoBone = {
		Enabled = options.Enabled ~= false,
		Weight = options.Weight or 1,
		Target = options.Target,
		Pole = options.Pole,
		Upper = indexOf(rig, options.Upper),
		Mid = indexOf(rig, options.Mid),
		Tip = indexOf(rig, options.Tip),
		Apply = applyTwoBone :: any,
	}

	assert(rig.Parents[constraint.Mid] == constraint.Upper, "Mid must be a child of Upper")
	assert(rig.Parents[constraint.Tip] == constraint.Mid, "Tip must be a child of Mid")

	rig:AddConstraint(constraint)
	return constraint
end

function Ik.LookAt(rig: Rig.Rig, options: LookAtOptions): LookAt
	const constraint: LookAt = {
		Enabled = options.Enabled ~= false,
		Weight = options.Weight or 1,
		MaxAngle = options.MaxAngle,
		Target = options.Target,
		Axis = options.Axis or vector.create(0, 0, -1),
		Joint = indexOf(rig, options.Joint),
		Apply = applyLookAt :: any,
	}

	rig:AddConstraint(constraint)
	return constraint
end

return Ik
