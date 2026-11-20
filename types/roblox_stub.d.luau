-- Minimal Roblox API surface used by this library, for type-checking with a stock
-- `luau-analyze` (see tools/check.sh). Signatures are copied from luau-lsp's generated
-- Roblox definitions. For the full API use luau-lsp with its own globalTypes file.

declare extern type EnumItem with
	Name: string
	Value: number
	EnumType: any
end

declare extern type EnumPoseEasingStyle extends EnumItem with end
declare extern type EnumPoseEasingDirection extends EnumItem with end
declare extern type EnumBulkMoveMode extends EnumItem with end

declare extern type EnumPoseEasingStyle_INTERNAL with
	Bounce: EnumPoseEasingStyle
	Constant: EnumPoseEasingStyle
	Cubic: EnumPoseEasingStyle
	CubicV2: EnumPoseEasingStyle
	Elastic: EnumPoseEasingStyle
	Linear: EnumPoseEasingStyle
	function GetEnumItems(self): { EnumPoseEasingStyle }
	function FromName(self, Name: string): EnumPoseEasingStyle?
end

declare extern type EnumPoseEasingDirection_INTERNAL with
	In: EnumPoseEasingDirection
	InOut: EnumPoseEasingDirection
	Out: EnumPoseEasingDirection
	function GetEnumItems(self): { EnumPoseEasingDirection }
	function FromName(self, Name: string): EnumPoseEasingDirection?
end

declare extern type EnumBulkMoveMode_INTERNAL with
	FireAllEvents: EnumBulkMoveMode
	FireCFrameChanged: EnumBulkMoveMode
end

declare Enum: {
	PoseEasingStyle: EnumPoseEasingStyle_INTERNAL,
	PoseEasingDirection: EnumPoseEasingDirection_INTERNAL,
	BulkMoveMode: EnumBulkMoveMode_INTERNAL,
}

declare extern type Vector3 with
	Magnitude: number
	Unit: Vector3
	X: number
	Y: number
	Z: number
	function Cross(self, other: Vector3): Vector3
	function Dot(self, other: Vector3): number
	function Lerp(self, goal: Vector3, alpha: number): Vector3
	function __add(self, other: Vector3): Vector3
	function __div(self, other: Vector3 | number): Vector3
	function __mul(self, other: Vector3 | number): Vector3
	function __sub(self, other: Vector3): Vector3
	function __unm(self): Vector3
end

declare Vector3: {
	zero: Vector3,
	one: Vector3,
	xAxis: Vector3,
	yAxis: Vector3,
	zAxis: Vector3,
	new: ((x: number?, y: number?, z: number?) -> Vector3),
}

declare extern type CFrame with
	LookVector: Vector3
	Position: Vector3
	RightVector: Vector3
	Rotation: CFrame
	UpVector: Vector3
	X: number
	Y: number
	Z: number
	function FuzzyEq(self, other: CFrame, epsilon: number?): boolean
	function GetComponents(self): (number, number, number, number, number, number, number, number, number, number, number, number)
	function Inverse(self): CFrame
	function Lerp(self, goal: CFrame, alpha: number): CFrame
	function Orthonormalize(self): CFrame
	function PointToObjectSpace(self, ...: Vector3): ...Vector3
	function PointToWorldSpace(self, ...: Vector3): ...Vector3
	function ToAxisAngle(self): (Vector3, number)
	function ToObjectSpace(self, ...: CFrame): ...CFrame
	function ToWorldSpace(self, ...: CFrame): ...CFrame
	function VectorToObjectSpace(self, ...: Vector3): ...Vector3
	function VectorToWorldSpace(self, ...: Vector3): ...Vector3
	function __add(self, other: Vector3): CFrame
	function __mul(self, other: CFrame): CFrame
	function __mul(self, other: Vector3): Vector3
	function __sub(self, other: Vector3): CFrame
end

declare CFrame: {
	identity: CFrame,
	fromAxisAngle: ((v: Vector3, r: number) -> CFrame),
	fromMatrix: ((pos: Vector3, vX: Vector3, vY: Vector3, vZ: Vector3?) -> CFrame),
	lookAt: ((at: Vector3, target: Vector3, up: Vector3?) -> CFrame),
	lookAlong: ((at: Vector3, direction: Vector3, up: Vector3?) -> CFrame),
	fromRotationBetweenVectors: ((from: Vector3, to: Vector3) -> CFrame),
	new: (() -> CFrame) & ((pos: Vector3) -> CFrame) & ((pos: Vector3, lookAt: Vector3) -> CFrame) & ((x: number, y: number, z: number) -> CFrame) & ((x: number, y: number, z: number, qX: number, qY: number, qZ: number, qW: number) -> CFrame) & ((x: number, y: number, z: number, R00: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number) -> CFrame),
}

declare extern type Instance with
	Name: string
	ClassName: string
	Parent: Instance?
	function GetChildren(self): { Instance }
	function GetDescendants(self): { Instance }
	function FindFirstChild(self, name: string, recursive: boolean?): Instance?
	function IsA(self, className: string): boolean
end

declare extern type BasePart extends Instance with
	CFrame: CFrame
end

declare extern type Model extends Instance with
	PrimaryPart: BasePart?
end

declare extern type JointInstance extends Instance with
	C0: CFrame
	C1: CFrame
	Part0: BasePart?
	Part1: BasePart?
end

declare extern type Motor6D extends JointInstance with
	Transform: CFrame
end

declare extern type PoseBase extends Instance with
	EasingDirection: EnumPoseEasingDirection
	EasingStyle: EnumPoseEasingStyle
	Weight: number
end

declare extern type Pose extends PoseBase with
	CFrame: CFrame
	function GetSubPoses(self): { Instance }
end

declare extern type KeyframeMarker extends Instance with
	Value: string
end

declare extern type Keyframe extends Instance with
	Time: number
	function GetMarkers(self): { Instance }
	function GetPoses(self): { Instance }
end

declare extern type KeyframeSequence extends Instance with
	Loop: boolean
	Priority: EnumItem
	AuthoredHipHeight: number
	function GetKeyframes(self): { Instance }
end

declare extern type Workspace extends Instance with
	function BulkMoveTo(self, partList: { BasePart }, cframeList: { CFrame }, eventMode: EnumBulkMoveMode?): nil
end

declare workspace: Workspace

declare function warn(...: any): ()
