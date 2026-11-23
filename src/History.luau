--!strict
--!optimize 2

const Player = require("./Player")
const Pose = require("./Pose")
const Rig = require("./Rig")

export type HistoryOptions = {
	Duration: number?,
	Rate: number?,
	Windows: { string }?,
}

type HistoryData = {
	Player: Player.Player,
	Capacity: number,
	Count: number,
	Windows: { string },
	_head: number,
	_times: { number },
	_poses: { Pose.Pose },
	_bits: { number },
	_windowIndex: { [string]: number },
}

const History = {}
History.__index = History

export type History = typeof(setmetatable({} :: HistoryData, History))

function History.New(player: Player.Player, options: HistoryOptions?): History
	const opts: HistoryOptions = options or {}
	const duration = opts.Duration or 1
	const rate = opts.Rate or 60
	const windows = opts.Windows or {}
	assert(#windows <= 31, "At most 31 windows can be tracked")

	const capacity = math.ceil(duration * rate) + 2
	const poses: { Pose.Pose } = {}
	const times: { number } = {}
	const bits: { number } = {}
	for index = 1, capacity do
		poses[index] = Pose.New(player.Rig.Count)
		times[index] = 0
		bits[index] = 0
	end

	const windowIndex: { [string]: number } = {}
	for index, name in windows do
		windowIndex[name] = index - 1
	end

	return setmetatable({
		Player = player,
		Capacity = capacity,
		Count = 0,
		Windows = windows,
		_head = 1,
		_times = times,
		_poses = poses,
		_bits = bits,
		_windowIndex = windowIndex,
	}, History)
end

const function slot(self: History, position: number): number
	return (self._head - self.Count + position - 2) % self.Capacity + 1
end

function History.Record(self: History, time: number)
	const newest = if self.Count > 0 then self._times[slot(self, self.Count)] else nil
	assert(newest == nil or time >= newest, "History must be recorded in time order")

	const index = self._head
	self._poses[index]:CopyFrom(self.Player.Pose)
	self._times[index] = time

	local bitsValue = 0
	for position, name in self.Windows do
		if self.Player:IsWindowActive(name) then
			bitsValue = bit32.bor(bitsValue, bit32.lshift(1, position - 1))
		end
	end

	self._bits[index] = bitsValue
	self._head = index % self.Capacity + 1
	self.Count = math.min(self.Count + 1, self.Capacity)
end

function History.GetRange(self: History): (number?, number?)
	if self.Count == 0 then
		return nil, nil
	end

	return self._times[slot(self, 1)], self._times[slot(self, self.Count)]
end

const function locate(self: History, time: number): number
	local low, high = 1, self.Count
	while low < high do
		const middle = (low + high + 1) // 2
		if self._times[slot(self, middle)] <= time then
			low = middle
		else
			high = middle - 1
		end
	end

	return low
end

function History.Sample(self: History, time: number, out: Pose.Pose): boolean
	const oldest, newest = self:GetRange()
	if not oldest or not newest or time < oldest then
		return false
	end

	if time >= newest then
		out:CopyFrom(self._poses[slot(self, self.Count)])
		return true
	end

	const position = locate(self, time)
	const lowSlot, highSlot = slot(self, position), slot(self, position + 1)
	const span = self._times[highSlot] - self._times[lowSlot]
	const alpha = if span > 1e-9 then (time - self._times[lowSlot]) / span else 0

	Pose.Lerp(out, self._poses[lowSlot], self._poses[highSlot], alpha)
	return true
end

function History.WasWindowActive(self: History, name: string, time: number): boolean
	const offset = self._windowIndex[name]
	const oldest = self:GetRange()
	if offset == nil or not oldest or time < oldest then
		return false
	end

	const stored = self._bits[slot(self, locate(self, time))]
	return bit32.band(stored, bit32.lshift(1, offset)) ~= 0
end

function History.Evaluate(self: History, time: number, root: CFrame, rig: Rig.Rig?): { [string]: CFrame }?
	const target = rig or self.Player.Rig
	const scratch = Pose.New(target.Count)
	if not self:Sample(time, scratch) then
		return nil
	end

	target:Compose(scratch, root)
	return target.FramesByName
end

function History.Clear(self: History)
	self.Count = 0
	self._head = 1
end

return History
