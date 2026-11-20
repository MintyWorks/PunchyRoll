
type Matrix = { x: number, y: number, z: number, r00: number, r01: number, r02: number, r10: number, r11: number, r12: number, r20: number, r21: number, r22: number }

const Mock = {}
const methods = {}

const function make(m: Matrix)
	return setmetatable(m, Mock)
end

const function fromQuaternion(x: number, y: number, z: number, qx: number, qy: number, qz: number, qw: number)
	return make({
		x = x, y = y, z = z,
		r00 = 1 - 2 * (qy * qy + qz * qz), r01 = 2 * (qx * qy - qz * qw), r02 = 2 * (qx * qz + qy * qw),
		r10 = 2 * (qx * qy + qz * qw), r11 = 1 - 2 * (qx * qx + qz * qz), r12 = 2 * (qy * qz - qx * qw),
		r20 = 2 * (qx * qz - qy * qw), r21 = 2 * (qy * qz + qx * qw), r22 = 1 - 2 * (qx * qx + qy * qy),
	})
end

function Mock.new(x, y, z, a, b, c, d, e, f, g, h, i, j)
	if type(x) == "vector" then
		return make({ x = x.x, y = x.y, z = x.z, r00 = 1, r01 = 0, r02 = 0, r10 = 0, r11 = 1, r12 = 0, r20 = 0, r21 = 0, r22 = 1 })
	end

	if x == nil then
		return Mock.identity
	end

	if a == nil then
		return make({ x = x, y = y, z = z, r00 = 1, r01 = 0, r02 = 0, r10 = 0, r11 = 1, r12 = 0, r20 = 0, r21 = 0, r22 = 1 })
	elseif d ~= nil and e == nil then
		return fromQuaternion(x, y, z, a, b, c, d)
	end

	return make({ x = x, y = y, z = z, r00 = a, r01 = b, r02 = c, r10 = d, r11 = e, r12 = f, r20 = g, r21 = h, r22 = i })
end

function Mock.fromAxisAngle(axis, angle)
	const half = angle * 0.5
	const s = math.sin(half)
	const unit = vector.normalize(axis)
	return fromQuaternion(0, 0, 0, unit.x * s, unit.y * s, unit.z * s, math.cos(half))
end

function Mock.Angles(rx, ry, rz)
	return Mock.fromAxisAngle(vector.create(1, 0, 0), rx) * Mock.fromAxisAngle(vector.create(0, 1, 0), ry) * Mock.fromAxisAngle(vector.create(0, 0, 1), rz)
end

Mock.identity = make({ x = 0, y = 0, z = 0, r00 = 1, r01 = 0, r02 = 0, r10 = 0, r11 = 1, r12 = 0, r20 = 0, r21 = 0, r22 = 1 })

function Mock.__mul(a, b)
	if type(b) == "vector" then
		return vector.create(
			a.x + a.r00 * b.x + a.r01 * b.y + a.r02 * b.z,
			a.y + a.r10 * b.x + a.r11 * b.y + a.r12 * b.z,
			a.z + a.r20 * b.x + a.r21 * b.y + a.r22 * b.z
		)
	end

	return make({
		x = a.x + a.r00 * b.x + a.r01 * b.y + a.r02 * b.z,
		y = a.y + a.r10 * b.x + a.r11 * b.y + a.r12 * b.z,
		z = a.z + a.r20 * b.x + a.r21 * b.y + a.r22 * b.z,
		r00 = a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20,
		r01 = a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21,
		r02 = a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22,
		r10 = a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20,
		r11 = a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21,
		r12 = a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22,
		r20 = a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20,
		r21 = a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21,
		r22 = a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22,
	})
end

function Mock.__eq(a, b)
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end

	return true
end

function methods.Inverse(self)
	return make({
		x = -(self.r00 * self.x + self.r10 * self.y + self.r20 * self.z),
		y = -(self.r01 * self.x + self.r11 * self.y + self.r21 * self.z),
		z = -(self.r02 * self.x + self.r12 * self.y + self.r22 * self.z),
		r00 = self.r00, r01 = self.r10, r02 = self.r20,
		r10 = self.r01, r11 = self.r11, r12 = self.r21,
		r20 = self.r02, r21 = self.r12, r22 = self.r22,
	})
end

function methods.GetComponents(self)
	return self.x, self.y, self.z, self.r00, self.r01, self.r02, self.r10, self.r11, self.r12, self.r20, self.r21, self.r22
end

function methods.ToObjectSpace(self, other)
	return self:Inverse() * other
end

function methods.ToWorldSpace(self, other)
	return self * other
end

function methods.PointToObjectSpace(self, point)
	return self:Inverse() * point
end

function methods.VectorToWorldSpace(self, direction)
	return (self * direction) - vector.create(self.x, self.y, self.z)
end

function methods.FuzzyEq(self, other, epsilon)
	epsilon = epsilon or 1e-5
	for key, value in self do
		if math.abs(other[key] - value) > epsilon then
			return false
		end
	end

	return true
end

function methods.ToAxisAngle(self)
	const trace = self.r00 + self.r11 + self.r22
	const angle = math.acos(math.clamp((trace - 1) / 2, -1, 1))
	if angle < 1e-9 then
		return vector.create(1, 0, 0), 0
	end

	const axis = vector.create(self.r21 - self.r12, self.r02 - self.r20, self.r10 - self.r01)
	if vector.magnitude(axis) < 1e-9 then
		return vector.create(1, 0, 0), angle
	end

	return vector.normalize(axis), angle
end

function Mock.__index(self, key)
	if key == "Position" then
		return vector.create(self.x, self.y, self.z)
	elseif key == "X" then
		return self.x
	elseif key == "Y" then
		return self.y
	elseif key == "Z" then
		return self.z
	elseif key == "RightVector" then
		return vector.create(self.r00, self.r10, self.r20)
	elseif key == "UpVector" then
		return vector.create(self.r01, self.r11, self.r21)
	elseif key == "LookVector" then
		return vector.create(-self.r02, -self.r12, -self.r22)
	elseif key == "Rotation" then
		return make({ x = 0, y = 0, z = 0, r00 = self.r00, r01 = self.r01, r02 = self.r02, r10 = self.r10, r11 = self.r11, r12 = self.r12, r20 = self.r20, r21 = self.r21, r22 = self.r22 })
	end

	return methods[key]
end

function Mock.__tostring(self)
	return string.format("CFrame(%.3f, %.3f, %.3f)", self.x, self.y, self.z)
end

CFrame = Mock
