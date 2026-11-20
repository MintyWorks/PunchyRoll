--!strict
--!native
--!optimize 2

export type LoopMode = "once" | "clamp" | "loop" | "ping_pong"

const MAX_LEGS = 32
const MAX_ITERATIONS = 4096

const Timeline = {}

function Timeline.Resolve(clock: number, length: number, mode: LoopMode): (number, boolean)
	if length <= 0 then
		return 0, mode == "once" or mode == "clamp"
	end

	if mode == "loop" then
		return clock % length, false
	elseif mode == "ping_pong" then
		const period = length * 2
		const phase = clock % period
		return if phase > length then period - phase else phase, false
	end

	if clock >= length then
		return length, true
	elseif clock <= 0 then
		return 0, clock < 0
	end

	return clock, false
end

function Timeline.FadeInfluence(time: number, length: number, fadeIn: number, fadeOut: number): number
	local influence = 1

	if fadeIn > 0 and time < fadeIn then
		influence = math.max(0, time / fadeIn)
	end

	if fadeOut > 0 then
		const remaining = length - time
		if remaining < fadeOut then
			influence = math.min(influence, math.max(0, remaining / fadeOut))
		end
	end

	return influence
end

function Timeline.Pieces(
	from: number,
	to: number,
	length: number,
	mode: LoopMode,
	includeStart: boolean,
	callback: (a: number, b: number, startInclusive: boolean) -> ()
)
	if from == to then
		return
	end

	if length <= 0 then
		callback(0, 0, includeStart)
		return
	end

	if mode == "once" or mode == "clamp" then
		callback(math.clamp(from, 0, length), math.clamp(to, 0, length), includeStart)
		return
	end

	const direction = if to > from then 1 else -1
	local cursor = from
	local first = true

	if math.abs(to - from) > MAX_LEGS * length then
		cursor = to - direction * MAX_LEGS * length
		first = false
	end

	const pingPong = mode == "ping_pong"
	for _ = 1, MAX_ITERATIONS do
		if cursor == to then
			break
		end

		local leg, stop
		if direction == 1 then
			leg = math.floor(cursor / length)
			stop = math.min(to, (leg + 1) * length)
		else
			leg = math.ceil(cursor / length) - 1
			stop = math.max(to, leg * length)
		end

		local a = cursor - leg * length
		local b = stop - leg * length
		if pingPong and leg % 2 ~= 0 then
			a, b = length - a, length - b
		end

		callback(math.clamp(a, 0, length), math.clamp(b, 0, length), if first then includeStart else not pingPong)
		first = false
		cursor = stop
	end
end

return Timeline
