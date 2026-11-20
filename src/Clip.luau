--!strict
--!optimize 2

const Easing = require("./Easing")
const Quat = require("./Quat")
const Rig = require("./Rig")

export type Params = { [string]: string | number | boolean }

export type Event = {
	Time: number,
	Name: string,
	Value: string,
	Kind: "marker" | "keyframe",
	Params: Params,
}

export type EventInput = {
	Time: number,
	Name: string,
	Value: string?,
	Kind: ("marker" | "keyframe")?,
}

export type Window = {
	Start: number,
	Stop: number,
}

export type Channel = {
	Count: number,
	Times: { number },
	Positions: { vector },
	QuatV: { vector },
	QuatW: { number },
	Easings: { Easing.EasingFunction },
	RefPosition: vector,
	RefQuatV: vector,
	RefQuatW: number,
}

export type KeyframeInput = {
	Time: number,
	Position: vector?,
	Quaternion: { number }?,
	Easing: (string | Easing.EasingFunction)?,
}

export type ClipInput = {
	Name: string?,
	Length: number?,
	Loop: boolean?,
	Priority: number?,
	Additive: boolean?,
	AdditiveRefTime: number?,
	Joints: { [string]: { KeyframeInput } },
	Events: { EventInput }?,
}

export type Binding = {
	Rig: Rig.Rig,
	Channels: { Channel | false },
	Matched: number,
	Unmatched: { string },
}

type ClipData = {
	Id: number,
	Name: string,
	Length: number,
	Loop: boolean,
	Priority: number,
	Additive: boolean,
	AdditiveRefTime: number,
	Channels: { [string]: Channel },
	JointNames: { string },
	Events: { Event },
	EventsByName: { [string]: { Event } },
	Windows: { [string]: { Window } },
	_bindings: { [Rig.Rig]: Binding },
}

const START_SUFFIX = "_start"
const END_SUFFIX = "_end"
const EMPTY_PARAMS: Params = table.freeze({} :: Params)

local nextId = 0

const Clip = {}
Clip.__index = Clip

export type Clip = typeof(setmetatable({} :: ClipData, Clip))

const function parseValue(text: string): string | number | boolean
	if text == "true" then
		return true
	elseif text == "false" then
		return false
	end

	return tonumber(text) or text
end

const function parseParams(value: string): Params
	if value == "" then
		return EMPTY_PARAMS
	end

	const params: Params = {}
	for entry in string.gmatch(value, "[^;,]+") do
		const key, text = string.match(entry, "^%s*([^=]-)%s*=%s*(.-)%s*$")
		if key and key ~= "" then
			params[key] = parseValue(text :: string)
		else
			const flag = string.match(entry, "^%s*(.-)%s*$") :: string
			if flag ~= "" then
				params[flag] = true
			end
		end
	end

	return params
end

const function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

const function buildChannel(joint: string, input: { KeyframeInput }): Channel
	assert(#input > 0, `Joint '{joint}' needs at least one keyframe`)

	const sorted = table.clone(input)
	table.sort(sorted, function(a: KeyframeInput, b: KeyframeInput)
		return a.Time < b.Time
	end)

	const times: { number } = {}
	const positions: { vector } = {}
	const quatV: { vector } = {}
	const quatW: { number } = {}
	const easings: { Easing.EasingFunction } = {}

	for _, key in sorted do
		assert(isFinite(key.Time) and key.Time >= 0, `Joint '{joint}' has an invalid keyframe time`)

		const position = key.Position or vector.zero
		local rotationV, rotationW = vector.zero, 1
		if key.Quaternion then
			const q = key.Quaternion
			assert(#q == 4, `Joint '{joint}' has a quaternion that is not \{x, y, z, w}`)
			rotationV, rotationW = Quat.Normalize(vector.create(q[1], q[2], q[3]), q[4])
		end

		local ease: Easing.EasingFunction = Easing.Linear
		const requested = key.Easing
		if type(requested) == "string" then
			ease = Easing.Get(requested) or error(`Unknown easing '{requested}'`)
		elseif requested ~= nil then
			ease = requested
		end

		const count = #times
		if count > 0 and times[count] == key.Time then
			positions[count] = position
			quatV[count] = rotationV
			quatW[count] = rotationW
			easings[count] = ease
			continue
		end

		table.insert(times, key.Time)
		table.insert(positions, position)
		table.insert(quatV, rotationV)
		table.insert(quatW, rotationW)
		table.insert(easings, ease)
	end

	for index = 2, #times do
		if Quat.Dot(quatV[index - 1], quatW[index - 1], quatV[index], quatW[index]) < 0 then
			quatV[index] = -quatV[index]
			quatW[index] = -quatW[index]
		end
	end

	return {
		Count = #times,
		Times = times,
		Positions = positions,
		QuatV = quatV,
		QuatW = quatW,
		Easings = easings,
		RefPosition = positions[1],
		RefQuatV = quatV[1],
		RefQuatW = quatW[1],
	}
end

const function findSegment(times: { number }, count: number, time: number, hint: number): number
	if hint >= 1 and hint < count then
		if time >= times[hint] then
			if time < times[hint + 1] then
				return hint
			elseif hint + 1 < count and time < times[hint + 2] then
				return hint + 1
			end
		elseif hint > 1 and time >= times[hint - 1] then
			return hint - 1
		end
	end

	local low, high = 1, count
	while high - low > 1 do
		const middle = (low + high) // 2
		if times[middle] <= time then
			low = middle
		else
			high = middle
		end
	end

	return low
end

const function sampleChannel(channel: Channel, time: number, hint: number): (vector, vector, number, number)
	const count = channel.Count
	const times = channel.Times

	if time <= times[1] then
		return channel.Positions[1], channel.QuatV[1], channel.QuatW[1], 1
	elseif time >= times[count] then
		return channel.Positions[count], channel.QuatV[count], channel.QuatW[count], count
	end

	const index = findSegment(times, count, time, hint)
	const start = times[index]
	const alpha = channel.Easings[index]((time - start) / (times[index + 1] - start))

	const position = channel.Positions[index]
	const rotation, scalar = Quat.NlerpFixed(
		channel.QuatV[index],
		channel.QuatW[index],
		channel.QuatV[index + 1],
		channel.QuatW[index + 1],
		alpha
	)

	return position + (channel.Positions[index + 1] - position) * alpha, rotation, scalar, index
end

const function sortEvents(events: { Event })
	const order: { [Event]: number } = {}
	for index, event in events do
		order[event] = index
	end

	table.sort(events, function(a: Event, b: Event)
		if a.Time == b.Time then
			return order[a] < order[b]
		end

		return a.Time < b.Time
	end)
end

const function buildWindows(events: { Event }, length: number): { [string]: { Window } }
	const windows: { [string]: { Window } } = {}
	const open: { [string]: number } = {}

	for _, event in events do
		const name = event.Name
		if string.sub(name, -#START_SUFFIX) == START_SUFFIX then
			const base = string.sub(name, 1, -#START_SUFFIX - 1)
			if open[base] == nil then
				open[base] = event.Time
			end
		elseif string.sub(name, -#END_SUFFIX) == END_SUFFIX then
			const base = string.sub(name, 1, -#END_SUFFIX - 1)
			const list = windows[base] or {}
			windows[base] = list
			table.insert(list, { Start = open[base] or 0, Stop = event.Time })
			open[base] = nil
		end
	end

	for base, start in open do
		const list = windows[base] or {}
		windows[base] = list
		table.insert(list, { Start = start, Stop = length })
	end

	return windows
end

const function indexEvents(self: Clip)
	sortEvents(self.Events)

	const byName: { [string]: { Event } } = {}
	for _, event in self.Events do
		const list = byName[event.Name]
		if list then
			table.insert(list, event)
		else
			byName[event.Name] = { event }
		end
	end

	self.EventsByName = byName
	self.Windows = buildWindows(self.Events, self.Length)
end

const function assemble(
	name: string,
	length: number,
	loop: boolean,
	priority: number,
	channels: { [string]: Channel },
	events: { Event },
	additive: boolean,
	additiveRefTime: number
): Clip
	nextId += 1

	const jointNames = {}
	for joint in channels do
		table.insert(jointNames, joint)
	end
	table.sort(jointNames)

	const self: Clip = setmetatable({
		Id = nextId,
		Name = name,
		Length = length,
		Loop = loop,
		Priority = priority,
		Additive = additive,
		AdditiveRefTime = additiveRefTime,
		Channels = channels,
		JointNames = jointNames,
		Events = events,
		EventsByName = {},
		Windows = {},
		_bindings = setmetatable({}, { __mode = "k" }) :: any,
	}, Clip)

	indexEvents(self)
	return self
end

const function makeEvent(input: EventInput): Event
	assert(type(input.Name) == "string" and input.Name ~= "", "Event needs a name")
	assert(isFinite(input.Time) and input.Time >= 0, `Event '{input.Name}' has an invalid time`)

	const value = input.Value or ""
	return {
		Time = input.Time,
		Name = input.Name,
		Value = value,
		Kind = input.Kind or "marker",
		Params = parseParams(value),
	}
end

function Clip.New(input: ClipInput): Clip
	const channels: { [string]: Channel } = {}
	local length = input.Length or 0

	for joint, keys in input.Joints do
		const channel = buildChannel(joint, keys)
		channels[joint] = channel
		length = math.max(length, channel.Times[channel.Count])
	end

	const events: { Event } = {}
	if input.Events then
		for _, eventInput in input.Events do
			table.insert(events, makeEvent(eventInput))
		end
	end

	const refTime = input.AdditiveRefTime or 0
	const additive = input.Additive == true
	if additive then
		for _, channel in channels do
			const position, rotation, scalar = sampleChannel(channel, refTime, 1)
			channel.RefPosition, channel.RefQuatV, channel.RefQuatW = position, rotation, scalar
		end
	end

	return assemble(
		input.Name or "Clip",
		length,
		input.Loop == true,
		input.Priority or 0,
		channels,
		events,
		additive,
		refTime
	)
end

function Clip.SampleChannel(channel: Channel, time: number, hint: number): (vector, vector, number, number)
	return sampleChannel(channel, time, hint)
end

function Clip.Bind(self: Clip, rig: Rig.Rig): Binding
	const cached = self._bindings[rig]
	if cached then
		return cached
	end

	const channels: { Channel | false } = {}
	const matched = {}
	for index = 1, rig.Count do
		const channel = self.Channels[rig.Names[index]]
		channels[index] = channel or false
		if channel then
			table.insert(matched, rig.Names[index])
		end
	end

	const unmatched = {}
	for _, joint in self.JointNames do
		if not rig.NameToIndex[joint] then
			table.insert(unmatched, joint)
		end
	end

	const binding: Binding = {
		Rig = rig,
		Channels = channels,
		Matched = #matched,
		Unmatched = unmatched,
	}

	self._bindings[rig] = binding
	return binding
end

function Clip.GetUnmatchedJoints(self: Clip, rig: Rig.Rig): { string }
	return self:Bind(rig).Unmatched
end

function Clip.SampleJoint(self: Clip, joint: string, time: number): (vector?, vector?, number?)
	const channel = self.Channels[joint]
	if not channel then
		return nil, nil, nil
	end

	const position, rotation, scalar = sampleChannel(channel, time, 1)
	return position, rotation, scalar
end

function Clip.SampleIntoPose(self: Clip, rig: Rig.Rig, pose: any, time: number)
	const binding = self:Bind(rig)
	const rest = rig.Rest

	for index = 1, rig.Count do
		const channel = binding.Channels[index]
		if channel then
			const position, rotation, scalar = sampleChannel(channel, time, 1)
			pose.Positions[index], pose.QuatV[index], pose.QuatW[index] = position, rotation, scalar
		elseif rest then
			pose.Positions[index], pose.QuatV[index], pose.QuatW[index] =
				rest.Positions[index], rest.QuatV[index], rest.QuatW[index]
		else
			pose.Positions[index], pose.QuatV[index], pose.QuatW[index] = vector.zero, vector.zero, 1
		end
	end
end

function Clip.GetEvents(self: Clip, name: string?): { Event }
	if name == nil then
		return self.Events
	end

	return self.EventsByName[name] or {}
end

function Clip.HasEvent(self: Clip, name: string): boolean
	return self.EventsByName[name] ~= nil
end

function Clip.GetEventTime(self: Clip, name: string, occurrence: number?): number?
	const list = self.EventsByName[name]
	const event = if list then list[occurrence or 1] else nil
	return if event then event.Time else nil
end

function Clip.GetEventTimes(self: Clip, name: string): { number }
	const times = {}
	const list = self.EventsByName[name]
	if list then
		for _, event in list do
			table.insert(times, event.Time)
		end
	end

	return times
end

function Clip.GetWindows(self: Clip, name: string): { Window }
	return self.Windows[name] or {}
end

function Clip.IsWindowActive(self: Clip, name: string, time: number): boolean
	const list = self.Windows[name]
	if not list then
		return false
	end

	for _, window in list do
		if time >= window.Start and time <= window.Stop then
			return true
		end
	end

	return false
end

function Clip.ForEachEvent(
	self: Clip,
	low: number,
	high: number,
	lowInclusive: boolean,
	highInclusive: boolean,
	descending: boolean,
	callback: (event: Event) -> ()
)
	const events = self.Events
	const count = #events
	if count == 0 or low > high then
		return
	end

	local first, last = 1, count
	while first <= last do
		const middle = (first + last) // 2
		const time = events[middle].Time
		if time < low or (time == low and not lowInclusive) then
			first = middle + 1
		else
			last = middle - 1
		end
	end

	local stop = first - 1
	local lo, hi = first, count
	while lo <= hi do
		const middle = (lo + hi) // 2
		const time = events[middle].Time
		if time < high or (time == high and highInclusive) then
			stop = middle
			lo = middle + 1
		else
			hi = middle - 1
		end
	end

	if descending then
		for index = stop, first, -1 do
			callback(events[index])
		end
	else
		for index = first, stop do
			callback(events[index])
		end
	end
end

function Clip.GetEventsBetween(self: Clip, from: number, to: number, includeStart: boolean?): { Event }
	const result: { Event } = {}
	const include = includeStart == true
	const collect = function(event: Event)
		table.insert(result, event)
	end

	if to >= from then
		self:ForEachEvent(from, to, include, true, false, collect)
	else
		self:ForEachEvent(to, from, true, include, true, collect)
	end

	return result
end

function Clip.AddEvent(self: Clip, time: number, name: string, value: string?, kind: ("marker" | "keyframe")?): Event
	const event = makeEvent({ Time = time, Name = name, Value = value, Kind = kind })
	table.insert(self.Events, event)
	indexEvents(self)
	return event
end

function Clip.RemoveEvents(self: Clip, name: string): number
	local removed = 0
	for index = #self.Events, 1, -1 do
		if self.Events[index].Name == name then
			table.remove(self.Events, index)
			removed += 1
		end
	end

	if removed > 0 then
		indexEvents(self)
	end

	return removed
end

function Clip.GetRootMotion(
	self: Clip,
	joint: string,
	from: number,
	to: number,
	looped: boolean?
): (vector, vector, number)
	const channel = self.Channels[joint]
	if not channel then
		return vector.zero, vector.zero, 1
	end

	const startPosition, startV, startW = sampleChannel(channel, from, 1)

	if looped and to < from then
		const endPosition, endV, endW = sampleChannel(channel, self.Length, 1)
		const zeroPosition, zeroV, zeroW = sampleChannel(channel, 0, 1)
		const toPosition, toV, toW = sampleChannel(channel, to, 1)

		const firstV, firstW = Quat.Mul(endV, endW, Quat.Conjugate(startV, startW))
		const secondV, secondW = Quat.Mul(toV, toW, Quat.Conjugate(zeroV, zeroW))
		const totalV, totalW = Quat.Mul(secondV, secondW, firstV, firstW)

		return (endPosition - startPosition) + (toPosition - zeroPosition), totalV, totalW
	end

	const endPosition, endV, endW = sampleChannel(channel, to, 1)
	const deltaV, deltaW = Quat.Mul(endV, endW, Quat.Conjugate(startV, startW))
	return endPosition - startPosition, deltaV, deltaW
end

const function cloneEvents(events: { Event }, map: (Event) -> Event?): { Event }
	const result: { Event } = {}
	for _, event in events do
		const mapped = map(event)
		if mapped then
			table.insert(result, mapped)
		end
	end

	return result
end

const function withTime(event: Event, time: number): Event
	const copy = table.clone(event)
	copy.Time = time
	return copy
end

function Clip.Reverse(self: Clip, name: string?): Clip
	const channels: { [string]: Channel } = {}

	for joint, channel in self.Channels do
		const count = channel.Count
		const times: { number } = {}
		const positions: { vector } = {}
		const quatV: { vector } = {}
		const quatW: { number } = {}
		const easings: { Easing.EasingFunction } = {}

		for index = 1, count do
			const source = count + 1 - index
			times[index] = self.Length - channel.Times[source]
			positions[index] = channel.Positions[source]
			quatV[index] = channel.QuatV[source]
			quatW[index] = channel.QuatW[source]
			easings[index] = if index < count then Easing.Reversed(channel.Easings[count - index]) else Easing.Linear
		end

		channels[joint] = {
			Count = count,
			Times = times,
			Positions = positions,
			QuatV = quatV,
			QuatW = quatW,
			Easings = easings,
			RefPosition = channel.RefPosition,
			RefQuatV = channel.RefQuatV,
			RefQuatW = channel.RefQuatW,
		}
	end

	const events = cloneEvents(self.Events, function(event)
		const copy = withTime(event, self.Length - event.Time)
		if string.sub(copy.Name, -#START_SUFFIX) == START_SUFFIX then
			copy.Name = string.sub(copy.Name, 1, -#START_SUFFIX - 1) .. END_SUFFIX
		elseif string.sub(copy.Name, -#END_SUFFIX) == END_SUFFIX then
			copy.Name = string.sub(copy.Name, 1, -#END_SUFFIX - 1) .. START_SUFFIX
		end

		return copy
	end)

	return assemble(
		name or `{self.Name}_reversed`,
		self.Length,
		self.Loop,
		self.Priority,
		channels,
		events,
		self.Additive,
		self.AdditiveRefTime
	)
end

function Clip.ScaleTime(self: Clip, factor: number, name: string?): Clip
	assert(factor > 0 and isFinite(factor), "Clip:ScaleTime expects a positive factor")

	const channels: { [string]: Channel } = {}
	for joint, channel in self.Channels do
		const times: { number } = table.create(channel.Count, 0)
		for index = 1, channel.Count do
			times[index] = channel.Times[index] / factor
		end

		const copy = table.clone(channel)
		copy.Times = times
		channels[joint] = copy
	end

	const events = cloneEvents(self.Events, function(event)
		return withTime(event, event.Time / factor)
	end)

	return assemble(
		name or self.Name,
		self.Length / factor,
		self.Loop,
		self.Priority,
		channels,
		events,
		self.Additive,
		self.AdditiveRefTime / factor
	)
end

function Clip.Slice(self: Clip, from: number, to: number, name: string?): Clip
	assert(isFinite(from) and isFinite(to) and to >= from, "Clip:Slice expects from <= to")

	const start = math.max(0, from)
	const stop = math.min(self.Length, to)
	assert(stop >= start, "Clip:Slice range lies outside of the clip")

	const channels: { [string]: Channel } = {}
	for joint, channel in self.Channels do
		const cuts = { start }
		for index = 1, channel.Count do
			const time = channel.Times[index]
			if time > start and time < stop then
				table.insert(cuts, time)
			end
		end

		if stop > start then
			table.insert(cuts, stop)
		end

		const keys: { KeyframeInput } = {}
		for index, time in cuts do
			const position, rotationV, rotationW = sampleChannel(channel, time, 1)

			local ease: Easing.EasingFunction = Easing.Linear
			const nextTime = cuts[index + 1]
			if nextTime then
				const middle = (time + nextTime) * 0.5
				if middle > channel.Times[1] and middle < channel.Times[channel.Count] then
					const segment = findSegment(channel.Times, channel.Count, middle, 1)
					const segmentStart = channel.Times[segment]
					const segmentSpan = channel.Times[segment + 1] - segmentStart
					ease = Easing.Subrange(
						channel.Easings[segment],
						(time - segmentStart) / segmentSpan,
						(nextTime - segmentStart) / segmentSpan
					)
				end
			end

			table.insert(keys, {
				Time = time - start,
				Position = position,
				Quaternion = { rotationV.x, rotationV.y, rotationV.z, rotationW },
				Easing = ease,
			})
		end

		channels[joint] = buildChannel(joint, keys)
	end

	const events = cloneEvents(self.Events, function(event)
		if event.Time >= start and event.Time <= stop then
			return withTime(event, event.Time - start)
		end

		return nil
	end)

	const clip = assemble(
		name or `{self.Name}_slice`,
		stop - start,
		false,
		self.Priority,
		channels,
		events,
		self.Additive,
		math.max(0, self.AdditiveRefTime - start)
	)

	return clip
end

function Clip.MakeAdditive(self: Clip, refTime: number?, name: string?): Clip
	const reference = refTime or 0
	const channels: { [string]: Channel } = {}

	for joint, channel in self.Channels do
		const copy = table.clone(channel)
		copy.RefPosition, copy.RefQuatV, copy.RefQuatW = sampleChannel(channel, reference, 1)
		channels[joint] = copy
	end

	return assemble(
		name or `{self.Name}_additive`,
		self.Length,
		self.Loop,
		self.Priority,
		channels,
		cloneEvents(self.Events, function(event)
			return event
		end),
		true,
		reference
	)
end

const function filterJoints(self: Clip, keep: (string) -> boolean, name: string): Clip
	const channels: { [string]: Channel } = {}
	for joint, channel in self.Channels do
		if keep(joint) then
			channels[joint] = channel
		end
	end

	return assemble(
		name,
		self.Length,
		self.Loop,
		self.Priority,
		channels,
		cloneEvents(self.Events, function(event)
			return event
		end),
		self.Additive,
		self.AdditiveRefTime
	)
end

function Clip.KeepJoints(self: Clip, joints: { string }, name: string?): Clip
	const set: { [string]: boolean } = {}
	for _, joint in joints do
		set[joint] = true
	end

	return filterJoints(self, function(joint)
		return set[joint] == true
	end, name or self.Name)
end

function Clip.RemoveJoints(self: Clip, joints: { string }, name: string?): Clip
	const set: { [string]: boolean } = {}
	for _, joint in joints do
		set[joint] = true
	end

	return filterJoints(self, function(joint)
		return set[joint] ~= true
	end, name or self.Name)
end

function Clip.RemapJoints(self: Clip, map: { [string]: string }, name: string?): Clip
	const channels: { [string]: Channel } = {}
	for joint, channel in self.Channels do
		const target = map[joint] or joint
		assert(channels[target] == nil, `Clip:RemapJoints maps two joints onto '{target}'`)
		channels[target] = channel
	end

	return assemble(
		name or self.Name,
		self.Length,
		self.Loop,
		self.Priority,
		channels,
		cloneEvents(self.Events, function(event)
			return event
		end),
		self.Additive,
		self.AdditiveRefTime
	)
end

function Clip.Describe(self: Clip): string
	const lines = {
		`{self.Name}: {string.format("%.3f", self.Length)}s, {#self.JointNames} joints, {#self.Events} events`
			.. (if self.Loop then ", looped" else "")
			.. (if self.Additive then ", additive" else ""),
	}

	for _, event in self.Events do
		table.insert(lines, `  {string.format("%.3f", event.Time)}s {event.Kind} {event.Name}`
			.. (if event.Value ~= "" then ` = {event.Value}` else ""))
	end

	return table.concat(lines, "\n")
end

return Clip
