--!strict
--!optimize 2

const Pose = require("./Pose")

export type LimbInfo = {
	Name: string,
	C0: CFrame,
	C1: CFrame,
	Children: { LimbInfo }?,
}

export type Limb = {
	Name: string,
	Parent: string?,
	C0: CFrame,
	C1: CFrame,
}

export type Constraint = {
	Enabled: boolean,
	Apply: (self: any, rig: any) -> (),
}

type RigData = {
	Count: number,
	Names: { string },
	Parents: { number },
	NameToIndex: { [string]: number },
	C0: { CFrame },
	C1: { CFrame },
	C1Inverse: { CFrame },
	Frames: { CFrame },
	Relative: { CFrame },
	Transforms: { CFrame },
	FramesByName: { [string]: CFrame },
	Root: CFrame,
	Rest: Pose.Pose?,
	Constraints: { Constraint },
	_subtrees: { [number]: { number } },
}

const Rig = {}
Rig.__index = Rig

export type Rig = typeof(setmetatable({} :: RigData, Rig))

const function flatten(limbs: { Limb }, node: LimbInfo, parent: string?)
	table.insert(limbs, {
		Name = node.Name,
		Parent = parent,
		C0 = node.C0,
		C1 = node.C1,
	})

	if node.Children then
		for _, child in node.Children do
			flatten(limbs, child, node.Name)
		end
	end
end

function Rig.New(root: LimbInfo): Rig
	const limbs: { Limb } = {}
	flatten(limbs, root, nil)
	return Rig.FromLimbs(limbs)
end

function Rig.FromLimbs(limbs: { Limb }): Rig
	const byName: { [string]: Limb } = {}
	const children: { [string]: { Limb } } = {}
	const roots: { Limb } = {}

	for _, limb in limbs do
		assert(byName[limb.Name] == nil, `Duplicate limb name '{limb.Name}'`)
		byName[limb.Name] = limb
	end

	for _, limb in limbs do
		const parent = limb.Parent
		if parent == nil then
			table.insert(roots, limb)
			continue
		end

		assert(byName[parent] ~= nil, `Limb '{limb.Name}' depends on unknown limb '{parent}'`)
		const list = children[parent]
		if list then
			table.insert(list, limb)
		else
			children[parent] = { limb }
		end
	end

	const names: { string } = {}
	const parents: { number } = {}
	const nameToIndex: { [string]: number } = {}
	const c0: { CFrame } = {}
	const c1: { CFrame } = {}
	const c1Inverse: { CFrame } = {}

	const function visit(limb: Limb, parentIndex: number)
		const index = #names + 1
		names[index] = limb.Name
		parents[index] = parentIndex
		nameToIndex[limb.Name] = index
		c0[index] = limb.C0
		c1[index] = limb.C1
		c1Inverse[index] = limb.C1:Inverse()

		const list = children[limb.Name]
		if list then
			for _, child in list do
				visit(child, index)
			end
		end
	end

	for _, limb in roots do
		visit(limb, 0)
	end

	assert(#names == #limbs, "Rig contains a cycle or limbs that cannot be reached from the root")

	const count = #names
	return setmetatable({
		Count = count,
		Names = names,
		Parents = parents,
		NameToIndex = nameToIndex,
		C0 = c0,
		C1 = c1,
		C1Inverse = c1Inverse,
		Frames = table.create(count, CFrame.identity),
		Relative = table.create(count, CFrame.identity),
		Transforms = table.create(count, CFrame.identity),
		FramesByName = { root = CFrame.identity },
		Root = CFrame.identity,
		Rest = nil,
		Constraints = {},
		_subtrees = {},
	}, Rig)
end

function Rig.GetIndex(self: Rig, name: string): number?
	return self.NameToIndex[name]
end

function Rig.Has(self: Rig, name: string): boolean
	return self.NameToIndex[name] ~= nil
end

function Rig.CreatePose(self: Rig): Pose.Pose
	if self.Rest then
		return self.Rest:Clone()
	end

	return Pose.New(self.Count)
end

function Rig.SetRestPose(self: Rig, pose: Pose.Pose?)
	if pose then
		assert(pose.Count == self.Count, "Rest pose joint count does not match the rig")
		self.Rest = pose:Clone()
	else
		self.Rest = nil
	end
end

function Rig.GetSubtree(self: Rig, joint: string | number): { number }
	const root = if type(joint) == "string" then self.NameToIndex[joint] else joint
	assert(root ~= nil and root >= 1 and root <= self.Count, `Unknown joint '{joint}'`)

	const cached = self._subtrees[root]
	if cached then
		return cached
	end

	const inside: { [number]: boolean } = { [root] = true }
	const list = { root }
	for index = root + 1, self.Count do
		if inside[self.Parents[index]] then
			inside[index] = true
			table.insert(list, index)
		end
	end

	self._subtrees[root] = list
	return list
end

function Rig.GetAncestors(self: Rig, joint: string | number): { number }
	local index = if type(joint) == "string" then self.NameToIndex[joint] else joint
	assert(index ~= nil, `Unknown joint '{joint}'`)

	const chain = {}
	while index ~= nil and index > 0 do
		table.insert(chain, index)
		index = self.Parents[index]
	end

	return chain
end

function Rig.Compose(self: Rig, pose: Pose.Pose, root: CFrame)
	const count = self.Count
	const parents = self.Parents
	const c0 = self.C0
	const c1Inverse = self.C1Inverse
	const frames = self.Frames
	const relative = self.Relative
	const transforms = self.Transforms
	const names = self.Names
	const byName = self.FramesByName
	const positions = pose.Positions
	const quatV = pose.QuatV
	const quatW = pose.QuatW

	for index = 1, count do
		const position = positions[index]
		const rotation = quatV[index]

		const transform =
			CFrame.new(position.x, position.y, position.z, rotation.x, rotation.y, rotation.z, quatW[index])
		const localFrame = c0[index] * transform * c1Inverse[index]
		const parent = parents[index]
		const frame = (if parent == 0 then root else frames[parent]) * localFrame

		transforms[index] = transform
		relative[index] = localFrame
		frames[index] = frame
		byName[names[index]] = frame
	end

	self.Root = root
	byName.root = root

	for _, constraint in self.Constraints do
		if constraint.Enabled then
			constraint:Apply(self)
		end
	end
end

function Rig.GetParentFrame(self: Rig, index: number): CFrame
	const parent = self.Parents[index]
	return if parent == 0 then self.Root else self.Frames[parent]
end

function Rig.OverrideFrame(self: Rig, index: number, frame: CFrame)
	const parentFrame = self:GetParentFrame(index)
	const localFrame = parentFrame:Inverse() * frame

	self.Frames[index] = frame
	self.Relative[index] = localFrame
	self.Transforms[index] = self.C0[index]:Inverse() * localFrame * self.C1[index]
	self.FramesByName[self.Names[index]] = frame

	const subtree = self:GetSubtree(index)
	for position = 2, #subtree do
		const child = subtree[position]
		const childFrame = self.Frames[self.Parents[child]] * self.Relative[child]
		self.Frames[child] = childFrame
		self.FramesByName[self.Names[child]] = childFrame
	end
end

function Rig.AddConstraint(self: Rig, constraint: Constraint)
	table.insert(self.Constraints, constraint)
end

function Rig.RemoveConstraint(self: Rig, constraint: Constraint)
	const index = table.find(self.Constraints, constraint)
	if index then
		table.remove(self.Constraints, index)
	end
end

function Rig.Describe(self: Rig): string
	const lines = {}
	const depth: { number } = {}
	for index = 1, self.Count do
		const parent = self.Parents[index]
		depth[index] = if parent == 0 then 0 else depth[parent] + 1
		table.insert(lines, string.rep("  ", depth[index]) .. self.Names[index])
	end

	return table.concat(lines, "\n")
end

return Rig
