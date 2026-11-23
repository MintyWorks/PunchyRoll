--!strict
--!optimize 2

const Clip = require("./Clip")
const Mask = require("./Mask")
const Player = require("./Player")
const Track = require("./Track")

export type Entry = {
	Clip: Clip.Clip,
	Position: number | vector,
}

export type TreeOptions = {
	Name: string?,
	Mode: ("1D" | "2D")?,
	Entries: { Entry },
	Priority: number?,
	Speed: number?,
	Sharpness: number?,
	Mask: Mask.Mask?,
}

type TreeData = {
	Name: string,
	Mode: "1D" | "2D",
	Speed: number,
	Sharpness: number,
	Player: Player.Player,
	Tracks: { Track.Track },
	Weights: { number },
	IsPlaying: boolean,
	_positions: { number },
	_points: { vector },
	_order: { number },
	_x: number,
	_y: number,
	_lengths: { number },
}

const EPSILON = 1e-9

const BlendTree = {}
BlendTree.__index = BlendTree

export type BlendTree = typeof(setmetatable({} :: TreeData, BlendTree))

function BlendTree.Weights1D(positions: { number }, order: { number }, value: number, out: { number }): { number }
	const count = #order
	for index = 1, count do
		out[index] = 0
	end

	if count == 0 then
		return out
	elseif count == 1 or value <= positions[order[1]] then
		out[order[1]] = 1
		return out
	elseif value >= positions[order[count]] then
		out[order[count]] = 1
		return out
	end

	for step = 1, count - 1 do
		const low, high = order[step], order[step + 1]
		const a, b = positions[low], positions[high]
		if value >= a and value <= b then
			const span = b - a
			const alpha = if span < EPSILON then 1 else (value - a) / span
			out[low] = 1 - alpha
			out[high] = alpha
			break
		end
	end

	return out
end

function BlendTree.Weights2D(points: { vector }, x: number, y: number, sharpness: number, out: { number }): { number }
	const count = #points
	local total = 0

	for index = 1, count do
		const point = points[index]
		const dx, dy = x - point.x, y - point.y
		const squared = dx * dx + dy * dy

		if squared < EPSILON then
			for other = 1, count do
				out[other] = if other == index then 1 else 0
			end

			return out
		end

		const weight = 1 / squared ^ (sharpness * 0.5)
		out[index] = weight
		total += weight
	end

	for index = 1, count do
		out[index] /= total
	end

	return out
end

function BlendTree.New(player: Player.Player, options: TreeOptions): BlendTree
	const mode = options.Mode or "1D"
	const entries = options.Entries
	assert(#entries > 0, "A blend tree needs at least one entry")

	const name = options.Name or "BlendTree"
	const tracks: { Track.Track } = {}
	const positions: { number } = {}
	const points: { vector } = {}
	const lengths: { number } = {}

	for index, entry in entries do
		const position = entry.Position
		if mode == "1D" then
			assert(type(position) == "number", "1D entries need a number Position")
			positions[index] = position
		else
			assert(type(position) == "vector", "2D entries need a vector Position")
			points[index] = position
		end

		lengths[index] = math.max(entry.Clip.Length, 1e-3)
		tracks[index] = player:Load(entry.Clip, {
			Name = `{name}:{entry.Clip.Name}:{index}`,
			Priority = options.Priority,
			Weight = 0,
			LoopMode = "loop",
			Mask = options.Mask,
		})
	end

	const order: { number } = {}
	for index = 1, #entries do
		order[index] = index
	end

	if mode == "1D" then
		table.sort(order, function(left: number, right: number)
			return positions[left] < positions[right]
		end)
	end

	const self: BlendTree = setmetatable({
		Name = name,
		Mode = mode,
		Speed = options.Speed or 1,
		Sharpness = options.Sharpness or 2,
		Player = player,
		Tracks = tracks,
		Weights = table.create(#entries, 0),
		IsPlaying = false,
		_positions = positions,
		_points = points,
		_order = order,
		_x = 0,
		_y = 0,
		_lengths = lengths,
	}, BlendTree)

	self:SetValue(0, 0)
	return self
end

function BlendTree.SetValue(self: BlendTree, x: number, y: number?)
	self._x = x
	self._y = y or self._y

	if self.Mode == "1D" then
		BlendTree.Weights1D(self._positions, self._order, x, self.Weights)
	else
		BlendTree.Weights2D(self._points, self._x, self._y, self.Sharpness, self.Weights)
	end

	if self.IsPlaying then
		for index, track in self.Tracks do
			track:SetWeight(self.Weights[index])
		end
	end
end

function BlendTree.GetWeights(self: BlendTree): { number }
	return table.clone(self.Weights)
end

function BlendTree.GetLead(self: BlendTree): Track.Track
	local best = 1
	for index = 2, #self.Tracks do
		if self.Weights[index] > self.Weights[best] then
			best = index
		end
	end

	return self.Tracks[best]
end

function BlendTree.Play(self: BlendTree, fadeTime: number?)
	self.IsPlaying = true

	for index, track in self.Tracks do
		track:Play({ FadeTime = fadeTime, Weight = self.Weights[index], Speed = 1, StartTime = 0 })
	end
end

function BlendTree.Stop(self: BlendTree, fadeTime: number?)
	self.IsPlaying = false

	for _, track in self.Tracks do
		track:Stop(fadeTime)
	end
end

function BlendTree.Update(self: BlendTree, _dt: number)
	if not self.IsPlaying then
		return
	end

	local averageLength = 0
	for index, length in self._lengths do
		averageLength += self.Weights[index] * length
	end

	if averageLength < 1e-3 then
		averageLength = self._lengths[1]
	end

	const lead = self:GetLead()
	const phase = lead:GetNormalizedTime()

	for index, track in self.Tracks do
		if track ~= lead then
			track:SetNormalizedTime(phase)
		end

		track:SetSpeed(self._lengths[index] / averageLength * self.Speed)
	end
end

function BlendTree.Destroy(self: BlendTree)
	self:Stop()
end

return BlendTree
