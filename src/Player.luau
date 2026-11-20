--!strict
--!optimize 2

const Clip = require("./Clip")
const EventRouter = require("./EventRouter")
const Pose = require("./Pose")
const Quat = require("./Quat")
const Rig = require("./Rig")
const Signal = require("./Signal")
const Solver = require("./Solver")
const Track = require("./Track")

export type PlayerOptions = {
	RootMotionJoint: string?,
	Speed: number?,
}

type PlayerData = {
	Rig: Rig.Rig,
	Speed: number,
	RootMotionJoint: string?,
	Pose: Pose.Pose,
	Tracks: { Track.Track },
	EventReached: Signal.Signal,
	PostSolve: Signal.Signal,
	RootMotion: Signal.Signal,
	_active: { Track.Track },
	_layers: { Solver.Layer },
	_scratch: Solver.Scratch,
	_router: EventRouter.EventRouter,
	_named: { [string]: Track.Track },
}

const Player = {}
Player.__index = Player

export type Player = typeof(setmetatable({} :: PlayerData, Player))

function Player.New(rig: Rig.Rig, options: PlayerOptions?): Player
	const opts: PlayerOptions = options or {}

	return setmetatable({
		Rig = rig,
		Speed = opts.Speed or 1,
		RootMotionJoint = opts.RootMotionJoint,
		Pose = rig:CreatePose(),
		Tracks = {},
		EventReached = Signal.New(),
		PostSolve = Signal.New(),
		RootMotion = Signal.New(),
		_active = {},
		_layers = {},
		_scratch = Solver.NewScratch(),
		_router = EventRouter.New(),
		_named = {},
	}, Player)
end

function Player._activate(self: Player, track: Track.Track)
	if track._inPlayer then
		return
	end

	track._inPlayer = true
	table.insert(self._active, track)
end

function Player._dispatch(self: Player, event: Clip.Event, track: Track.Track)
	self.EventReached:Fire(event, track)
	self._router:Dispatch(event.Name, event, track)
end

function Player.Load(self: Player, clip: Clip.Clip, options: Track.TrackOptions?): Track.Track
	clip:Bind(self.Rig)
	const track = Track.New(clip, self.Rig.Count, options, self :: any)
	table.insert(self.Tracks, track)
	self._named[track.Name] = track
	return track
end

function Player.GetTrack(self: Player, name: string): Track.Track?
	return self._named[name]
end

function Player.Play(self: Player, clip: Clip.Clip | string, options: (Track.TrackOptions & Track.PlayOptions)?): Track.Track
	local track: Track.Track?
	if type(clip) == "string" then
		track = self._named[clip]
		assert(track, `No track named {clip}`)
	else
		track = self._named[(options and options.Name) or clip.Name] or self:Load(clip, options)
	end

	const resolved = track :: Track.Track
	resolved:Play(options)
	return resolved
end

function Player.Stop(self: Player, name: string, fadeTime: number?)
	const track = self._named[name]
	if track then
		track:Stop(fadeTime)
	end
end

function Player.StopAll(self: Player, fadeTime: number?)
	for _, track in self._active do
		track:Stop(fadeTime)
	end
end

function Player.GetMarkerReachedSignal(self: Player, name: string): Signal.Signal
	return self._router:Get(name)
end

function Player.OnMarker(self: Player, name: string, callback: (event: Clip.Event, track: Track.Track) -> ()): Signal.Connection
	return self._router:Get(name):Connect(callback)
end

function Player.IsWindowActive(self: Player, name: string): boolean
	for _, track in self._active do
		if track.IsPlaying and not track.IsPaused and track:IsWindowActive(name) then
			return true
		end
	end

	return false
end

function Player.Update(self: Player, dt: number, root: CFrame?): { [string]: CFrame }
	const active = self._active
	const count = #active

	local rootPosition = vector.zero
	local rootRotation = vector.zero
	local rootScalar = 1

	for index = 1, count do
		const track = active[index]
		track:Advance(dt)

		if self.RootMotionJoint then
			const position, rotation, scalar = track:GetRootMotion()
			rootPosition += position * (if track.IsPlaying then track:GetEffectiveWeight() else track.Weight)
			rootRotation, rootScalar = Quat.Mul(rotation, scalar, rootRotation, rootScalar)
		end
	end

	local write = 0
	for read = 1, count do
		const track = active[read]
		if track.IsPlaying then
			write += 1
			active[write] = track
		else
			track._inPlayer = false
		end
	end

	for index = count, write + 1, -1 do
		active[index] = nil :: any
	end

	const layers = self._layers
	for index = 1, write do
		layers[index] = active[index]:GetLayer()
	end

	for index = #layers, write + 1, -1 do
		layers[index] = nil :: any
	end

	Solver.Solve(self.Rig, layers, self.Pose, self._scratch)

	if self.RootMotionJoint then
		self.RootMotion:Fire(rootPosition, rootRotation, rootScalar)
	end

	self.PostSolve:Fire(self.Pose, dt)

	self.Rig:Compose(self.Pose, root or CFrame.identity)

	return self.Rig.FramesByName
end

function Player.Destroy(self: Player)
	for _, track in self.Tracks do
		track:Destroy()
	end

	self.EventReached:Destroy()
	self.PostSolve:Destroy()
	self.RootMotion:Destroy()
	self._router:Destroy()
	table.clear(self.Tracks)
	table.clear(self._active)
	table.clear(self._named)
end

return Player
