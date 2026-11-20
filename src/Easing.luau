--!strict
--!native
--!optimize 2

export type EasingFunction = (alpha: number) -> number

const PI = math.pi
const ELASTIC_C4 = (2 * PI) / 3
const ELASTIC_C5 = (2 * PI) / 4.5
const BACK_C1 = 1.70158
const BACK_C2 = BACK_C1 * 1.525
const BACK_C3 = BACK_C1 + 1

const function linear(a: number): number
	return a
end

const function constant(a: number): number
	return if a >= 1 then 1 else 0
end

const function quadIn(a: number): number
	return a * a
end

const function quadOut(a: number): number
	return 1 - (1 - a) * (1 - a)
end

const function quadInOut(a: number): number
	if a < 0.5 then
		return 2 * a * a
	end

	const b = -2 * a + 2
	return 1 - b * b * 0.5
end

const function cubicIn(a: number): number
	return a * a * a
end

const function cubicOut(a: number): number
	const b = 1 - a
	return 1 - b * b * b
end

const function cubicInOut(a: number): number
	if a < 0.5 then
		return 4 * a * a * a
	end

	const b = -2 * a + 2
	return 1 - b * b * b * 0.5
end

const function quartIn(a: number): number
	const b = a * a
	return b * b
end

const function quartOut(a: number): number
	const b = (1 - a) * (1 - a)
	return 1 - b * b
end

const function quartInOut(a: number): number
	if a < 0.5 then
		const b = a * a
		return 8 * b * b
	end

	const b = (-2 * a + 2) * (-2 * a + 2)
	return 1 - b * b * 0.5
end

const function quintIn(a: number): number
	const b = a * a
	return b * b * a
end

const function quintOut(a: number): number
	const b = 1 - a
	const c = b * b
	return 1 - c * c * b
end

const function quintInOut(a: number): number
	if a < 0.5 then
		const b = a * a
		return 16 * b * b * a
	end

	const b = -2 * a + 2
	const c = b * b
	return 1 - c * c * b * 0.5
end

const function sineIn(a: number): number
	return 1 - math.cos(a * PI * 0.5)
end

const function sineOut(a: number): number
	return math.sin(a * PI * 0.5)
end

const function sineInOut(a: number): number
	return -(math.cos(PI * a) - 1) * 0.5
end

const function expoIn(a: number): number
	return if a <= 0 then 0 else 2 ^ (10 * a - 10)
end

const function expoOut(a: number): number
	return if a >= 1 then 1 else 1 - 2 ^ (-10 * a)
end

const function expoInOut(a: number): number
	if a <= 0 then
		return 0
	elseif a >= 1 then
		return 1
	elseif a < 0.5 then
		return 2 ^ (20 * a - 10) * 0.5
	end

	return (2 - 2 ^ (-20 * a + 10)) * 0.5
end

const function circIn(a: number): number
	return 1 - math.sqrt(math.max(0, 1 - a * a))
end

const function circOut(a: number): number
	const b = a - 1
	return math.sqrt(math.max(0, 1 - b * b))
end

const function circInOut(a: number): number
	if a < 0.5 then
		return (1 - math.sqrt(math.max(0, 1 - 4 * a * a))) * 0.5
	end

	const b = -2 * a + 2
	return (math.sqrt(math.max(0, 1 - b * b)) + 1) * 0.5
end

const function backIn(a: number): number
	return BACK_C3 * a * a * a - BACK_C1 * a * a
end

const function backOut(a: number): number
	const b = a - 1
	return 1 + BACK_C3 * b * b * b + BACK_C1 * b * b
end

const function backInOut(a: number): number
	if a < 0.5 then
		const b = 2 * a
		return b * b * ((BACK_C2 + 1) * b - BACK_C2) * 0.5
	end

	const b = 2 * a - 2
	return (b * b * ((BACK_C2 + 1) * b + BACK_C2) + 2) * 0.5
end

const function elasticIn(a: number): number
	if a <= 0 then
		return 0
	elseif a >= 1 then
		return 1
	end

	return -(2 ^ (10 * a - 10)) * math.sin((a * 10 - 10.75) * ELASTIC_C4)
end

const function elasticOut(a: number): number
	if a <= 0 then
		return 0
	elseif a >= 1 then
		return 1
	end

	return 2 ^ (-10 * a) * math.sin((a * 10 - 0.75) * ELASTIC_C4) + 1
end

const function elasticInOut(a: number): number
	if a <= 0 then
		return 0
	elseif a >= 1 then
		return 1
	elseif a < 0.5 then
		return -(2 ^ (20 * a - 10) * math.sin((20 * a - 11.125) * ELASTIC_C5)) * 0.5
	end

	return 2 ^ (-20 * a + 10) * math.sin((20 * a - 11.125) * ELASTIC_C5) * 0.5 + 1
end

const function bounceOut(a: number): number
	if a < 0.36363636363636365 then
		return 7.5625 * a * a
	elseif a < 0.7272727272727273 then
		const b = a - 0.5454545454545454
		return 7.5625 * b * b + 0.75
	elseif a < 0.9090909090909091 then
		const b = a - 0.8181818181818182
		return 7.5625 * b * b + 0.9375
	end

	const b = a - 0.9545454545454546
	return 7.5625 * b * b + 0.984375
end

const function bounceIn(a: number): number
	return 1 - bounceOut(1 - a)
end

const function bounceInOut(a: number): number
	if a < 0.5 then
		return (1 - bounceOut(1 - 2 * a)) * 0.5
	end

	return (1 + bounceOut(2 * a - 1)) * 0.5
end

const functions: { [string]: EasingFunction } = {
	linear = linear,
	constant = constant,
	quad_in = quadIn,
	quad_out = quadOut,
	quad_in_out = quadInOut,
	cubic_in = cubicIn,
	cubic_out = cubicOut,
	cubic_in_out = cubicInOut,
	quart_in = quartIn,
	quart_out = quartOut,
	quart_in_out = quartInOut,
	quint_in = quintIn,
	quint_out = quintOut,
	quint_in_out = quintInOut,
	sine_in = sineIn,
	sine_out = sineOut,
	sine_in_out = sineInOut,
	expo_in = expoIn,
	expo_out = expoOut,
	expo_in_out = expoInOut,
	circ_in = circIn,
	circ_out = circOut,
	circ_in_out = circInOut,
	back_in = backIn,
	back_out = backOut,
	back_in_out = backInOut,
	elastic_in = elasticIn,
	elastic_out = elasticOut,
	elastic_in_out = elasticInOut,
	bounce_in = bounceIn,
	bounce_out = bounceOut,
	bounce_in_out = bounceInOut,
}

const Easing = {
	Functions = functions,
	Linear = linear,
	Constant = constant,
}

function Easing.Get(name: string): EasingFunction?
	return functions[name]
end

function Easing.Names(): { string }
	const names = {}
	for name in functions do
		table.insert(names, name)
	end

	table.sort(names)
	return names
end

function Easing.FromRoblox(style: string, direction: string): EasingFunction
	const suffix = if direction == "In" then "_in" elseif direction == "Out" then "_out" else "_in_out"

	if style == "Constant" then
		return constant
	elseif style == "Cubic" or style == "CubicV2" then
		return functions["cubic" .. suffix] or linear
	elseif style == "Elastic" then
		return functions["elastic" .. suffix] or linear
	elseif style == "Bounce" then
		return functions["bounce" .. suffix] or linear
	end

	return linear
end

function Easing.Bezier(x1: number, y1: number, x2: number, y2: number): EasingFunction
	x1 = math.clamp(x1, 0, 1)
	x2 = math.clamp(x2, 0, 1)

	if x1 == y1 and x2 == y2 then
		return linear
	end

	const ax = 1 - 3 * x2 + 3 * x1
	const bx = 3 * x2 - 6 * x1
	const cx = 3 * x1
	const ay = 1 - 3 * y2 + 3 * y1
	const by = 3 * y2 - 6 * y1
	const cy = 3 * y1

	return function(alpha: number): number
		if alpha <= 0 then
			return 0
		elseif alpha >= 1 then
			return 1
		end

		local t = alpha
		for _ = 1, 8 do
			const delta = ((ax * t + bx) * t + cx) * t - alpha
			if math.abs(delta) < 1e-7 then
				return ((ay * t + by) * t + cy) * t
			end

			const slope = (3 * ax * t + 2 * bx) * t + cx
			if math.abs(slope) < 1e-6 then
				break
			end

			t -= delta / slope
		end

		local low, high = 0, 1
		t = alpha
		for _ = 1, 32 do
			const x = ((ax * t + bx) * t + cx) * t
			if math.abs(x - alpha) < 1e-7 then
				break
			end

			if x < alpha then
				low = t
			else
				high = t
			end

			t = (low + high) * 0.5
		end

		return ((ay * t + by) * t + cy) * t
	end
end

function Easing.Reversed(ease: EasingFunction): EasingFunction
	if ease == linear then
		return linear
	end

	return function(alpha: number): number
		return 1 - ease(1 - alpha)
	end
end

function Easing.Subrange(ease: EasingFunction, from: number, to: number): EasingFunction
	if ease == linear then
		return linear
	end

	const startValue = ease(from)
	const span = ease(to) - startValue
	if math.abs(span) < 1e-9 then
		return constant
	end

	const width = to - from
	return function(alpha: number): number
		return (ease(from + alpha * width) - startValue) / span
	end
end

return Easing
