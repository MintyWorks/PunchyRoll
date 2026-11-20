--!strict
--!native
--!optimize 2

const EPSILON = 1e-9

const Quat = {}

function Quat.Mul(av: vector, aw: number, bv: vector, bw: number): (vector, number)
	return bv * aw + av * bw + vector.cross(av, bv), aw * bw - vector.dot(av, bv)
end

function Quat.Conjugate(v: vector, w: number): (vector, number)
	return -v, w
end

function Quat.Dot(av: vector, aw: number, bv: vector, bw: number): number
	return vector.dot(av, bv) + aw * bw
end

function Quat.Normalize(v: vector, w: number): (vector, number)
	const magnitude = math.sqrt(vector.dot(v, v) + w * w)
	if magnitude < EPSILON then
		return vector.zero, 1
	end

	const inverse = 1 / magnitude
	return v * inverse, w * inverse
end

function Quat.NlerpFixed(av: vector, aw: number, bv: vector, bw: number, t: number): (vector, number)
	const v = av + (bv - av) * t
	const w = aw + (bw - aw) * t
	const magnitude = math.sqrt(vector.dot(v, v) + w * w)
	if magnitude < EPSILON then
		return vector.zero, 1
	end

	const inverse = 1 / magnitude
	return v * inverse, w * inverse
end

function Quat.Nlerp(av: vector, aw: number, bv: vector, bw: number, t: number): (vector, number)
	if vector.dot(av, bv) + aw * bw < 0 then
		return Quat.NlerpFixed(av, aw, -bv, -bw, t)
	end

	return Quat.NlerpFixed(av, aw, bv, bw, t)
end

function Quat.Slerp(av: vector, aw: number, bv: vector, bw: number, t: number): (vector, number)
	local cosine = vector.dot(av, bv) + aw * bw
	if cosine < 0 then
		bv, bw = -bv, -bw
		cosine = -cosine
	end

	if cosine > 0.9995 then
		return Quat.NlerpFixed(av, aw, bv, bw, t)
	end

	const theta = math.acos(cosine)
	const sinTheta = math.sin(theta)
	const scaleA = math.sin((1 - t) * theta) / sinTheta
	const scaleB = math.sin(t * theta) / sinTheta

	return av * scaleA + bv * scaleB, aw * scaleA + bw * scaleB
end

function Quat.Rotate(qv: vector, qw: number, point: vector): vector
	const cross = vector.cross(qv, point)
	return point + (cross * qw + vector.cross(qv, cross)) * 2
end

function Quat.FromAxisAngle(axis: vector, angle: number): (vector, number)
	const half = angle * 0.5
	return axis * math.sin(half), math.cos(half)
end

function Quat.ToAxisAngle(v: vector, w: number): (vector, number)
	if w < 0 then
		v, w = -v, -w
	end

	const sinHalf = vector.magnitude(v)
	if sinHalf < EPSILON then
		return vector.create(1, 0, 0), 0
	end

	return v / sinHalf, 2 * math.atan2(sinHalf, w)
end

function Quat.FromTo(from: vector, to: vector): (vector, number)
	const cosine = vector.dot(from, to)

	if cosine < -1 + 1e-7 then
		local axis = vector.cross(vector.create(1, 0, 0), from)
		if vector.dot(axis, axis) < 1e-6 then
			axis = vector.cross(vector.create(0, 1, 0), from)
		end

		return vector.normalize(axis), 0
	end

	return Quat.Normalize(vector.cross(from, to), 1 + cosine)
end

function Quat.AngleBetween(av: vector, aw: number, bv: vector, bw: number): number
	const deltaV, deltaW = Quat.Mul(av, aw, Quat.Conjugate(bv, bw))
	return 2 * math.atan2(vector.magnitude(deltaV), math.abs(deltaW))
end

function Quat.ScaleAngle(v: vector, w: number, factor: number): (vector, number)
	const axis, angle = Quat.ToAxisAngle(v, w)
	return Quat.FromAxisAngle(axis, (if angle > math.pi then angle - 2 * math.pi else angle) * factor)
end

function Quat.FromMatrix(
	r00: number,
	r01: number,
	r02: number,
	r10: number,
	r11: number,
	r12: number,
	r20: number,
	r21: number,
	r22: number
): (vector, number)
	const trace = r00 + r11 + r22

	local x, y, z, w
	if trace > 0 then
		const s = math.sqrt(trace + 1) * 2
		w = 0.25 * s
		x = (r21 - r12) / s
		y = (r02 - r20) / s
		z = (r10 - r01) / s
	elseif r00 > r11 and r00 > r22 then
		const s = math.sqrt(1 + r00 - r11 - r22) * 2
		w = (r21 - r12) / s
		x = 0.25 * s
		y = (r01 + r10) / s
		z = (r02 + r20) / s
	elseif r11 > r22 then
		const s = math.sqrt(1 + r11 - r00 - r22) * 2
		w = (r02 - r20) / s
		x = (r01 + r10) / s
		y = 0.25 * s
		z = (r12 + r21) / s
	else
		const s = math.sqrt(1 + r22 - r00 - r11) * 2
		w = (r10 - r01) / s
		x = (r02 + r20) / s
		y = (r12 + r21) / s
		z = 0.25 * s
	end

	return Quat.Normalize(vector.create(x, y, z), w)
end

function Quat.ToMatrix(
	v: vector,
	w: number
): (number, number, number, number, number, number, number, number, number)
	const x, y, z = v.x, v.y, v.z
	const xx, yy, zz = x * x, y * y, z * z
	const xy, xz, yz = x * y, x * z, y * z
	const wx, wy, wz = w * x, w * y, w * z

	return 1 - 2 * (yy + zz),
		2 * (xy - wz),
		2 * (xz + wy),
		2 * (xy + wz),
		1 - 2 * (xx + zz),
		2 * (yz - wx),
		2 * (xz - wy),
		2 * (yz + wx),
		1 - 2 * (xx + yy)
end

return Quat
