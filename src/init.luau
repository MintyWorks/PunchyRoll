--!strict

const Clip = require("@self/Clip")
const Easing = require("@self/Easing")
const EventRouter = require("@self/EventRouter")
const Mask = require("@self/Mask")
const Player = require("@self/Player")
const Pose = require("@self/Pose")
const Quat = require("@self/Quat")
const Rig = require("@self/Rig")
const Signal = require("@self/Signal")
const Solver = require("@self/Solver")
const Timeline = require("@self/Timeline")
const Track = require("@self/Track")
const KeyframeLoader = require("@self/roblox/KeyframeLoader")
const ModelRig = require("@self/roblox/ModelRig")

export type Clip = Clip.Clip
export type Event = Clip.Event
export type Rig = Rig.Rig
export type Pose = Pose.Pose
export type Mask = Mask.Mask
export type Track = Track.Track
export type Player = Player.Player
export type Layer = Solver.Layer
export type LoopMode = Timeline.LoopMode

return {
	Clip = Clip,
	Easing = Easing,
	EventRouter = EventRouter,
	Mask = Mask,
	Player = Player,
	Pose = Pose,
	Quat = Quat,
	Rig = Rig,
	Signal = Signal,
	Solver = Solver,
	Timeline = Timeline,
	Track = Track,
	KeyframeLoader = KeyframeLoader,
	ModelRig = ModelRig,
}
