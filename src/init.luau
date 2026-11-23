--!strict

const BlendTree = require("@self/BlendTree")
const Clip = require("@self/Clip")
const Easing = require("@self/Easing")
const EventRouter = require("@self/EventRouter")
const History = require("@self/History")
const Ik = require("@self/Ik")
const Mask = require("@self/Mask")
const Player = require("@self/Player")
const Pose = require("@self/Pose")
const Quat = require("@self/Quat")
const Rig = require("@self/Rig")
const Signal = require("@self/Signal")
const Solver = require("@self/Solver")
const StateMachine = require("@self/StateMachine")
const Timeline = require("@self/Timeline")
const Track = require("@self/Track")
const KeyframeLoader = require("@self/roblox/KeyframeLoader")
const ModelRig = require("@self/roblox/ModelRig")
const Net = require("@self/roblox/Net")
const ClipRegistry = require("@self/replication/ClipRegistry")
const Codec = require("@self/replication/Codec")
const Replicator = require("@self/replication/Replicator")

export type Clip = Clip.Clip
export type Event = Clip.Event
export type Rig = Rig.Rig
export type Pose = Pose.Pose
export type Mask = Mask.Mask
export type Track = Track.Track
export type Player = Player.Player
export type Layer = Solver.Layer
export type BlendTree = BlendTree.BlendTree
export type StateMachine = StateMachine.StateMachine
export type History = History.History
export type Replicator = Replicator.Replicator
export type ClipRegistry = ClipRegistry.ClipRegistry
export type LoopMode = Timeline.LoopMode

return {
	BlendTree = BlendTree,
	Clip = Clip,
	Easing = Easing,
	EventRouter = EventRouter,
	History = History,
	Ik = Ik,
	Mask = Mask,
	Player = Player,
	Pose = Pose,
	Quat = Quat,
	Rig = Rig,
	Signal = Signal,
	Solver = Solver,
	StateMachine = StateMachine,
	Timeline = Timeline,
	Track = Track,
	KeyframeLoader = KeyframeLoader,
	ModelRig = ModelRig,
	Net = Net,
	Replication = {
		ClipRegistry = ClipRegistry,
		Codec = Codec,
		Replicator = Replicator,
	},
}
