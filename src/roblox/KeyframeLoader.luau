--!strict

const Clip = require("../Clip")
const Easing = require("../Easing")
const Quat = require("../Quat")

export type EasingMode = "outgoing" | "incoming"

export type LoadOptions = {
	Name: string?,
	EasingMode: EasingMode?,
	Priority: number?,
	Loop: boolean?,
	KeyframeNamesAsEvents: boolean?,
}

const PRIORITIES: { [string]: number } = {
	Core = 0,
	Idle = 1,
	Movement = 2,
	Action = 3,
	Action2 = 4,
	Action3 = 5,
	Action4 = 6,
}

const DEFAULT_KEYFRAME_NAME = "Keyframe"

const KeyframeLoader = {}

const function collectPoses(
	pose: Pose,
	time: number,
	easing: Easing.EasingFunction,
	joints: { [string]: { Clip.KeyframeInput } }
)
	for _, child in pose:GetSubPoses() do
		collectPoses(child :: Pose, time, easing, joints)
	end

	const frame = pose.CFrame
	const axis, angle = frame:ToAxisAngle()
	const quatV, quatW = Quat.FromAxisAngle(axis :: any, angle)
	const list = joints[pose.Name] or {}
	joints[pose.Name] = list

	table.insert(list, {
		Time = time,
		Position = frame.Position :: any,
		Quaternion = { quatV.x, quatV.y, quatV.z, quatW },
		Easing = Easing.FromRoblox(pose.EasingStyle.Name, pose.EasingDirection.Name),
	})
end

function KeyframeLoader.Load(sequence: KeyframeSequence, options: LoadOptions?): Clip.Clip
	const opts: LoadOptions = options or {}
	const incoming = opts.EasingMode == "incoming"
	const keyframeEvents = opts.KeyframeNamesAsEvents ~= false

	const keyframes = sequence:GetKeyframes() :: { Instance }
	table.sort(keyframes, function(left: Instance, right: Instance)
		return (left :: Keyframe).Time < (right :: Keyframe).Time
	end)

	const joints: { [string]: { Clip.KeyframeInput } } = {}
	const events: { Clip.EventInput } = {}
	local length = 0

	for _, instance in keyframes do
		const keyframe = instance :: Keyframe
		length = math.max(length, keyframe.Time)

		for _, poseInstance in keyframe:GetPoses() do
			collectPoses(poseInstance :: Pose, keyframe.Time, Easing.Linear, joints)
		end

		for _, markerInstance in keyframe:GetMarkers() do
			table.insert(events, {
				Time = keyframe.Time,
				Name = markerInstance.Name,
				Value = (markerInstance :: KeyframeMarker).Value,
				Kind = "marker" :: "marker",
			})
		end

		if keyframeEvents and keyframe.Name ~= DEFAULT_KEYFRAME_NAME and keyframe.Name ~= "" then
			table.insert(events, {
				Time = keyframe.Time,
				Name = keyframe.Name,
				Kind = "keyframe" :: "keyframe",
			})
		end
	end

	if incoming then
		for _, list in joints do
			for index = 1, #list - 1 do
				list[index].Easing = list[index + 1].Easing
			end
		end
	end

	return Clip.New({
		Name = opts.Name or sequence.Name,
		Length = length,
		Loop = if opts.Loop ~= nil then opts.Loop else sequence.Loop,
		Priority = opts.Priority or PRIORITIES[sequence.Priority.Name] or 0,
		Joints = joints,
		Events = events,
	})
end

return KeyframeLoader
