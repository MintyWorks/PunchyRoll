--!strict
--!optimize 2

const Clip = require("./Clip")
const Easing = require("./Easing")
const EventRouter = require("./EventRouter")
const Mask = require("./Mask")
const Quat = require("./Quat")
const Signal = require("./Signal")
const Solver = require("./Solver")
const Timeline = require("./Timeline")

export type TrackOptions = {
	Name: string?,
	Priority: number?,
	Weight: number?,
	Speed: number?,
	LoopMode: Timeline.LoopMode?,
	Looped: boolean?,
	Mask: Mask.Mask?,
	Additive: boolean?,
	EndFade: number?,
	FadeEasing: Easing.EasingFunction?,
}

export type PlayOptions = {
	FadeTime: number?,
	Weight: number?,
	Speed: number?,
	StartTime: number?,
}

export type Owner = {
	Speed: number,
	RootMotionJoint: string?,
	_activate: (self: any, track: any) -> (),
	_dispatch: (self: any, event: Clip.Event, track: any) -> (),
}

type TrackData = {
	Clip: Clip.Clip,
	Name: string,
	Priority: number,
	Weight: number,
	Speed: number,
	LoopMode: Timeline.LoopMode,
	Mask: Mask.Mask?,
	Additive: boolean?,
	EndFade: number,
	FadeEasing: Easing.EasingFunction,
	Length: number,
	TimePosition: number,
	IsPlaying: boolean,
	IsPaused: boolean,
	IsStopping: boolean,
	Started: Signal.Signal,
	Stopped: Signal.Signal,
	Ended: Signal.Signal,
	DidLoop: Signal.Signal,
	EventReached: Signal.Signal,
	_clock: number,
	_time: number,
	_fade: number,
	_fadeTarget: number,
	_fadeRate: number,
	_weightTarget: number,
	_weightRate: number,
	_speedTarget: number,
	_speedRate: number,
	_includeStart: boolean,
	_finished: boolean,
	_layer: Solver.Layer,
	_owner: Owner?,
	_router: EventRouter.EventRouter,
	_rootJoint: string?,
	_rootPosition: vector,
	_rootRotation: vector,
	_rootScalar: number,
	_onPiece: (a: number, b: number, startInclusive: boolean) -> (),
	_dispatch: (event: Clip.Event) -> (),
	_inPlayer: boolean,
}

const MAX_LOOP_SIGNALS = 8

const Track = {}
Track.__index = Track

export type Track = typeof(setmetatable({} :: TrackData, Track))

const function finalizeStop(self: Track)
	self.IsPlaying = false
	self.IsStopping = false
	self.IsPaused = false
	self._fade = 0
	self._fadeTarget = 0
	self.Stopped:Fire(self)
end

function Track.New(clip: Clip.Clip, cursorCount: number, options: TrackOptions?, owner: Owner?): Track
	const opts: TrackOptions = options or {}
	const priority = opts.Priority or clip.Priority
	const mode: Timeline.LoopMode = opts.LoopMode
		or (if opts.Looped ~= nil then (if opts.Looped then "loop" else "once") else (if clip.Loop then "loop" else "once"))

	const layer: Solver.Layer = {
		Clip = clip,
		Time = 0,
		Weight = 0,
		Priority = priority,
		Additive = opts.Additive,
		Mask = opts.Mask,
		FadeIn = nil,
		FadeOut = nil,
		Cursors = table.create(cursorCount, 1),
	}

	const weight = opts.Weight or 1
	const speed = opts.Speed or 1

	const self: Track = setmetatable({
		Clip = clip,
		Name = opts.Name or clip.Name,
		Priority = priority,
		Weight = weight,
		Speed = speed,
		LoopMode = mode,
		Mask = opts.Mask,
		Additive = opts.Additive,
		EndFade = opts.EndFade or 0,
		FadeEasing = opts.FadeEasing or Easing.Linear,
		Length = clip.Length,
		TimePosition = 0,
		IsPlaying = false,
		IsPaused = false,
		IsStopping = false,
		Started = Signal.New(),
		Stopped = Signal.New(),
		Ended = Signal.New(),
		DidLoop = Signal.New(),
		EventReached = Signal.New(),
		_clock = 0,
		_time = 0,
		_fade = 1,
		_fadeTarget = 1,
		_fadeRate = 0,
		_weightTarget = weight,
		_weightRate = 0,
		_speedTarget = speed,
		_speedRate = 0,
		_includeStart = true,
		_finished = false,
		_layer = layer,
		_owner = owner,
		_router = EventRouter.New(),
		_rootJoint = nil,
		_rootPosition = vector.zero,
		_rootRotation = vector.zero,
		_rootScalar = 1,
		_onPiece = nil :: any,
		_dispatch = nil :: any,
		_inPlayer = false,
	}, Track)

	self._dispatch = function(event: Clip.Event)
		self.EventReached:Fire(event, self)
		self._router:Dispatch(event.Name, event, self)
		if self._owner then
			self._owner:_dispatch(event, self)
		end
	end

	self._onPiece = function(a: number, b: number, startInclusive: boolean)
		if #clip.Events > 0 then
			if b >= a then
				clip:ForEachEvent(a, b, startInclusive, true, false, self._dispatch)
			else
				clip:ForEachEvent(b, a, true, startInclusive, true, self._dispatch)
			end
		end

		const joint = self._rootJoint
		if joint then
			const position, rotation, scalar = clip:GetRootMotion(joint, a, b, false)
			self._rootPosition += position
			self._rootRotation, self._rootScalar = Quat.Mul(rotation, scalar, self._rootRotation, self._rootScalar)
		end
	end

	return self
end

function Track.Play(self: Track, options: PlayOptions?)
	const opts: PlayOptions = options or {}

	if opts.Weight then
		self.Weight = opts.Weight
		self._weightTarget = opts.Weight
		self._weightRate = 0
	end

	if opts.Speed then
		self.Speed = opts.Speed
		self._speedTarget = opts.Speed
		self._speedRate = 0
	end

	const fadeTime = opts.FadeTime or 0

	if self.IsPlaying then
		if self.IsStopping then
			self.IsStopping = false
			self._fadeTarget = 1
			self._fadeRate = if fadeTime > 0 then 1 / fadeTime else 0
		end

		return
	end

	self.IsPlaying = true
	self.IsPaused = false
	self.IsStopping = false
	self._finished = false
	self._includeStart = true
	self._clock = opts.StartTime or (if self.Speed < 0 then self.Length else 0)
	self._time = Timeline.Resolve(self._clock, self.Length, self.LoopMode)
	self.TimePosition = self._time
	self._fade = if fadeTime > 0 then 0 else 1
	self._fadeTarget = 1
	self._fadeRate = if fadeTime > 0 then 1 / fadeTime else 0

	const cursors = self._layer.Cursors :: { number }
	for index = 1, #cursors do
		cursors[index] = 1
	end

	if self._owner then
		self._owner:_activate(self)
	end

	self.Started:Fire(self)
end

function Track.Stop(self: Track, fadeTime: number?)
	if not self.IsPlaying then
		return
	end

	const duration = fadeTime or 0
	if duration > 0 then
		self.IsStopping = true
		self._fadeTarget = 0
		self._fadeRate = 1 / duration
		return
	end

	finalizeStop(self)
end

function Track.Pause(self: Track)
	if self.IsPlaying then
		self.IsPaused = true
	end
end

function Track.Resume(self: Track)
	self.IsPaused = false
end

function Track.Seek(self: Track, time: number, fireEvents: boolean?)
	const target = math.clamp(time, 0, self.Length)

	if fireEvents then
		const owner = self._owner
		self._rootJoint = if owner then owner.RootMotionJoint else nil
		Timeline.Pieces(self._time, target, self.Length, "once", false, self._onPiece)
	end

	self._clock = target
	self._time = target
	self.TimePosition = target
	self._includeStart = false
	self._finished = false
end

function Track.SetNormalizedTime(self: Track, alpha: number, fireEvents: boolean?)
	self:Seek(alpha * self.Length, fireEvents)
end

function Track.GetNormalizedTime(self: Track): number
	return if self.Length > 0 then self._time / self.Length else 0
end

function Track.SetWeight(self: Track, weight: number, fadeTime: number?)
	self._weightTarget = weight
	const duration = fadeTime or 0
	if duration > 0 then
		self._weightRate = math.abs(weight - self.Weight) / duration
	else
		self.Weight = weight
		self._weightRate = 0
	end
end

function Track.SetSpeed(self: Track, speed: number, rampTime: number?)
	self._speedTarget = speed
	const duration = rampTime or 0
	if duration > 0 then
		self._speedRate = math.abs(speed - self.Speed) / duration
	else
		self.Speed = speed
		self._speedRate = 0
	end
end

function Track.GetEffectiveWeight(self: Track): number
	return self.Weight * self.FadeEasing(self._fade)
end

function Track.GetMarkerReachedSignal(self: Track, name: string): Signal.Signal
	return self._router:Get(name)
end

function Track.OnMarker(self: Track, name: string, callback: (event: Clip.Event, track: Track) -> ()): Signal.Connection
	return self._router:Get(name):Connect(callback)
end

function Track.IsWindowActive(self: Track, name: string): boolean
	return self.Clip:IsWindowActive(name, self._time)
end

function Track.OnWindow(
	self: Track,
	name: string,
	onOpen: (event: Clip.Event?, track: Track) -> (),
	onClose: (event: Clip.Event?, track: Track) -> ()
): Signal.Connection
	local open = false

	const openConnection = self._router:Get(name .. "_start"):Connect(function(event: Clip.Event)
		open = true
		onOpen(event, self)
	end)

	const closeConnection = self._router:Get(name .. "_end"):Connect(function(event: Clip.Event)
		if open then
			open = false
			onClose(event, self)
		end
	end)

	const stopConnection = self.Stopped:Connect(function()
		if open then
			open = false
			onClose(nil, self)
		end
	end)

	const connection = {
		Connected = true,
		Disconnect = function(me: Signal.Connection)
			openConnection:Disconnect()
			closeConnection:Disconnect()
			stopConnection:Disconnect()
			me.Connected = false
		end,
	}

	return connection
end

function Track.GetLayer(self: Track): Solver.Layer
	const layer = self._layer
	layer.Time = self._time
	layer.Weight = self.Weight * self.FadeEasing(self._fade)
	layer.Priority = self.Priority
	layer.Additive = self.Additive
	layer.Mask = self.Mask
	layer.FadeOut = if self.LoopMode == "once" and self.EndFade > 0 then self.EndFade else nil
	return layer
end

function Track.GetRootMotion(self: Track): (vector, vector, number)
	return self._rootPosition, self._rootRotation, self._rootScalar
end

function Track.Advance(self: Track, dt: number)
	if not self.IsPlaying then
		return
	end

	self._rootPosition = vector.zero
	self._rootRotation = vector.zero
	self._rootScalar = 1

	if self._weightRate > 0 and self.Weight ~= self._weightTarget then
		const step = self._weightRate * dt
		const difference = self._weightTarget - self.Weight
		self.Weight = if math.abs(difference) <= step then self._weightTarget else self.Weight + math.sign(difference) * step
	end

	if self._speedRate > 0 and self.Speed ~= self._speedTarget then
		const step = self._speedRate * dt
		const difference = self._speedTarget - self.Speed
		self.Speed = if math.abs(difference) <= step then self._speedTarget else self.Speed + math.sign(difference) * step
	end

	if self._fade ~= self._fadeTarget then
		if self._fadeRate <= 0 then
			self._fade = self._fadeTarget
		else
			const step = self._fadeRate * dt
			const difference = self._fadeTarget - self._fade
			self._fade = if math.abs(difference) <= step then self._fadeTarget else self._fade + math.sign(difference) * step
		end

		if self._fade <= 0 and self._fadeTarget == 0 then
			finalizeStop(self)
			return
		end
	end

	if self.IsPaused then
		return
	end

	const owner = self._owner
	const scale = if owner then owner.Speed else 1
	const delta = dt * self.Speed * scale
	if delta == 0 then
		return
	end

	const length = self.Length
	const mode = self.LoopMode
	const from = self._clock
	const to = from + delta

	self._rootJoint = if owner then owner.RootMotionJoint else nil
	Timeline.Pieces(from, to, length, mode, self._includeStart, self._onPiece)
	self._includeStart = false

	if not self.IsPlaying then
		return
	end

	self._clock = to
	self._time = Timeline.Resolve(to, length, mode)
	self.TimePosition = self._time

	if mode == "loop" and length > 0 then
		const cycles = math.abs(math.floor(to / length) - math.floor(from / length))
		for _ = 1, math.min(cycles, MAX_LOOP_SIGNALS) do
			self.DidLoop:Fire(self)
		end
	end

	if (mode == "once" or mode == "clamp") and not self._finished then
		const finished = if delta > 0 then to >= length else to <= 0
		if finished then
			self._finished = true
			self.Ended:Fire(self)
			if mode == "once" and self.IsPlaying then
				finalizeStop(self)
			end
		end
	end
end

function Track.Destroy(self: Track)
	if self.IsPlaying then
		finalizeStop(self)
	end

	self.Started:Destroy()
	self.Stopped:Destroy()
	self.Ended:Destroy()
	self.DidLoop:Destroy()
	self.EventReached:Destroy()
	self._router:Destroy()
end

return Track
