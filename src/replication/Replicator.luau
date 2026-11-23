--!strict

const Clip = require("../Clip")
const Player = require("../Player")
const Track = require("../Track")
const ClipRegistry = require("./ClipRegistry")
const Codec = require("./Codec")

export type ReplicatorOptions = {
	Send: ((payload: buffer) -> ())?,
	Now: (() -> number)?,
	Immediate: boolean?,
	Sanitize: boolean?,
	Validate: ((command: Codec.Command) -> boolean)?,
	MaxLatency: number?,
}

export type ReplicatedPlayOptions = {
	FadeTime: number?,
	Weight: number?,
	Speed: number?,
	StartTime: number?,
	Priority: number?,
	LoopMode: string?,
}

type ReplicatorData = {
	Player: Player.Player,
	Registry: ClipRegistry.ClipRegistry,
	Send: ((payload: buffer) -> ())?,
	Now: () -> number,
	Immediate: boolean,
	Sanitize: boolean,
	Validate: ((command: Codec.Command) -> boolean)?,
	MaxLatency: number,
	_queue: { Codec.Command },
}

const Replicator = {}
Replicator.__index = Replicator

export type Replicator = typeof(setmetatable({} :: ReplicatorData, Replicator))

const function clean(value: number?, low: number, high: number, fallback: number?): number?
	if value == nil then
		return fallback
	end

	if value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end

	return math.clamp(value, low, high)
end

-- "1e4" Infinitez max timez ouu shi
const function sanitize(command: Codec.Command)
	command.FadeTime = clean(command.FadeTime, 0, 10, 0)
	command.Weight = clean(command.Weight, 0, 10, 1)
	command.Speed = clean(command.Speed, -10, 10, 1)
	command.StartTime = clean(command.StartTime, 0, 1e4, nil)
	command.Time = clean(command.Time, 0, 1e4, 0)
	command.Priority = clean(command.Priority, 0, 100, nil)
end

function Replicator.New(player: Player.Player, registry: ClipRegistry.ClipRegistry, options: ReplicatorOptions?): Replicator
	const opts: ReplicatorOptions = options or {}

	return setmetatable({
		Player = player,
		Registry = registry,
		Send = opts.Send,
		Now = opts.Now or os.clock,
		Immediate = opts.Immediate == true,
		Sanitize = opts.Sanitize ~= false,
		Validate = opts.Validate,
		MaxLatency = opts.MaxLatency or 1,
		_queue = {},
	}, Replicator)
end

const function resolve(self: Replicator, clip: Clip.Clip | string): (Clip.Clip, number)
	const id = self.Registry:GetId(clip)
	assert(id, `Clip '{if type(clip) == "string" then clip else clip.Name}' is not in the registry`)
	const resolved = self.Registry:GetClip(id)
	assert(resolved, "Registry is inconsistent")
	return resolved, id
end

const function trackFor(self: Replicator, clip: Clip.Clip | string): Track.Track?
	return self.Player:GetTrack(if type(clip) == "string" then clip else clip.Name)
end

const function queue(self: Replicator, command: Codec.Command)
	if not self.Send then
		return
	end

	table.insert(self._queue, command)
	if self.Immediate or #self._queue >= Codec.MaxCommands then
		self:Flush()
	end
end

const function applyPlay(self: Replicator, clip: Clip.Clip, command: Codec.Command, lag: number): Track.Track?
	const options: any = {}
	const base = self.Registry:GetOptions(clip)
	if base then
		for key, value in base :: any do
			options[key] = value
		end
	end

	options.Priority = command.Priority or options.Priority
	options.LoopMode = command.LoopMode or options.LoopMode
	options.FadeTime = command.FadeTime
	options.Weight = command.Weight
	options.Speed = command.Speed

	local start = command.StartTime
	if lag > 0 then
		const speed = command.Speed or 1
		const origin = start or (if speed < 0 then clip.Length else 0)
		const mode = options.LoopMode or (if clip.Loop then "loop" else "once")
		start = origin + lag * speed

		if mode == "once" and (start >= clip.Length or start < 0) then
			return nil
		elseif mode == "clamp" then
			start = math.clamp(start, 0, clip.Length)
		end
	end

	options.StartTime = start
	return self.Player:Play(clip, options)
end

function Replicator.Play(self: Replicator, clip: Clip.Clip | string, options: ReplicatedPlayOptions?): Track.Track
	const resolved, id = resolve(self, clip)
	const opts: ReplicatedPlayOptions = options or {}

	const command: Codec.Command = {
		Op = "Play",
		ClipId = id,
		FadeTime = opts.FadeTime,
		Weight = opts.Weight,
		Speed = opts.Speed,
		StartTime = opts.StartTime,
		Priority = opts.Priority,
		LoopMode = opts.LoopMode,
	}

	const track = applyPlay(self, resolved, command, 0)
	assert(track, "Play did not create a track")
	queue(self, command)
	return track
end

function Replicator.Stop(self: Replicator, clip: Clip.Clip | string, fadeTime: number?)
	const _, id = resolve(self, clip)
	const track = trackFor(self, clip)
	if track then
		track:Stop(fadeTime)
	end

	queue(self, { Op = "Stop", ClipId = id, FadeTime = fadeTime })
end

function Replicator.StopAll(self: Replicator, fadeTime: number?)
	self.Player:StopAll(fadeTime)
	queue(self, { Op = "StopAll", FadeTime = fadeTime })
end

function Replicator.Pause(self: Replicator, clip: Clip.Clip | string)
	const _, id = resolve(self, clip)
	const track = trackFor(self, clip)
	if track then
		track:Pause()
	end

	queue(self, { Op = "Pause", ClipId = id })
end

function Replicator.Resume(self: Replicator, clip: Clip.Clip | string)
	const _, id = resolve(self, clip)
	const track = trackFor(self, clip)
	if track then
		track:Resume()
	end

	queue(self, { Op = "Resume", ClipId = id })
end

function Replicator.Seek(self: Replicator, clip: Clip.Clip | string, time: number)
	const _, id = resolve(self, clip)
	const track = trackFor(self, clip)
	if track then
		track:Seek(time)
	end

	queue(self, { Op = "Seek", ClipId = id, Time = time })
end

function Replicator.SetWeight(self: Replicator, clip: Clip.Clip | string, weight: number, rampTime: number?)
	const _, id = resolve(self, clip)
	const track = trackFor(self, clip)
	if track then
		track:SetWeight(weight, rampTime)
	end

	queue(self, { Op = "SetWeight", ClipId = id, Weight = weight, FadeTime = rampTime })
end

function Replicator.SetSpeed(self: Replicator, clip: Clip.Clip | string, speed: number, rampTime: number?)
	const _, id = resolve(self, clip)
	const track = trackFor(self, clip)
	if track then
		track:SetSpeed(speed, rampTime)
	end

	queue(self, { Op = "SetSpeed", ClipId = id, Speed = speed, FadeTime = rampTime })
end

function Replicator.Flush(self: Replicator)
	const send = self.Send
	const pending = self._queue
	if not send or #pending == 0 then
		return
	end

	self._queue = {}
	send(Codec.Encode(pending, self.Now()))
end

function Replicator.Snapshot(self: Replicator): buffer?
	const commands: { Codec.Command } = {}

	for _, track in self.Player.Tracks do
		if not track.IsPlaying or track.IsStopping then
			continue
		end

		const id = self.Registry:GetId(track.Clip)
		if not id then
			continue
		end

		table.insert(commands, {
			Op = "Play" :: Codec.Op,
			ClipId = id,
			FadeTime = 0,
			Weight = track.Weight,
			Speed = track.Speed,
			StartTime = track.TimePosition,
			Priority = track.Priority,
			LoopMode = track.LoopMode,
		})

		if track.IsPaused then
			table.insert(commands, { Op = "Pause" :: Codec.Op, ClipId = id })
		end
	end

	if #commands == 0 then
		return nil
	end

	return Codec.Encode(commands, self.Now())
end

function Replicator.Receive(self: Replicator, payload: buffer, lag: number?): (boolean, string?)
	const timestamp, commands, reason = Codec.Decode(payload, self.Registry.Count)
	if not timestamp or not commands then
		return false, reason
	end

	const delay = lag or math.clamp(self.Now() - timestamp, 0, self.MaxLatency)
	const validate = self.Validate

	for _, command in commands do
		if self.Sanitize then
			sanitize(command)
		end

		if validate and not validate(command) then
			continue
		end

		const id = command.ClipId
		const clip = if id then self.Registry:GetClip(id) else nil
		const op = command.Op

		if op == "Play" then
			if clip then
				applyPlay(self, clip, command, delay)
			end
			continue
		elseif op == "StopAll" then
			self.Player:StopAll(command.FadeTime)
			continue
		end

		const track = if clip then trackFor(self, clip) else nil
		if not track then
			continue
		end

		if op == "Stop" then
			track:Stop(command.FadeTime)
		elseif op == "Pause" then
			track:Pause()
		elseif op == "Resume" then
			track:Resume()
		elseif op == "Seek" then
			track:Seek(command.Time or 0)
		elseif op == "SetWeight" then
			track:SetWeight(command.Weight or 1, command.FadeTime)
		elseif op == "SetSpeed" then
			track:SetSpeed(command.Speed or 1, command.FadeTime)
		end
	end

	return true, nil
end

function Replicator.Update(self: Replicator, dt: number, root: CFrame?): { [string]: CFrame }
	self:Flush()
	return self.Player:Update(dt, root)
end

function Replicator.Destroy(self: Replicator)
	table.clear(self._queue)
	self.Send = nil
end

return Replicator
