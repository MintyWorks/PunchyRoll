--!nocheck

const Harness = require("@tests/harness")
const Easing = require("@src/Easing")

const Test, Expect = Harness.Test, Harness.Expect

Test("every easing starts at 0 and ends at 1", function()
	for _, name in Easing.Names() do
		const ease = Easing.Get(name)
		if name == "constant" then
			Expect.Equal(ease(0), 0, name)
			Expect.Equal(ease(1), 1, name)
			continue
		end

		Expect.Near(ease(0), 0, 1e-9, `{name}(0)`)
		Expect.Near(ease(1), 1, 1e-9, `{name}(1)`)
	end
end)

Test("in_out easings pass through the midpoint", function()
	for _, family in { "quad", "cubic", "quart", "quint", "sine", "expo", "circ", "back", "bounce" } do
		Expect.Near(Easing.Get(family .. "_in_out")(0.5), 0.5, 1e-6, family)
	end
end)

Test("in_out easings are continuous around the midpoint", function()
	for _, name in Easing.Names() do
		if not string.find(name, "_in_out", 1, true) or name == "constant" then
			continue
		end

		const ease = Easing.Get(name)
		Expect.Near(ease(0.5 - 1e-7), ease(0.5 + 1e-7), 1e-3, name)
	end
end)

Test("in and out are mirror images", function()
	for _, family in { "quad", "cubic", "quart", "quint", "sine", "expo", "circ", "back", "bounce", "elastic" } do
		const easeIn = Easing.Get(family .. "_in")
		const easeOut = Easing.Get(family .. "_out")
		for step = 1, 9 do
			const t = step / 10
			Expect.Near(easeIn(t), 1 - easeOut(1 - t), 1e-6, `{family} at {t}`)
		end
	end
end)

Test("bounce_in follows the bounce_out identity across all segments", function()
	const bounceIn = Easing.Get("bounce_in")
	const bounceOut = Easing.Get("bounce_out")
	for step = 0, 100 do
		const t = step / 100
		Expect.Near(bounceIn(t), 1 - bounceOut(1 - t), 1e-9, `t = {t}`)
	end
end)

Test("elastic_in_out is continuous and ends correctly", function()
	const ease = Easing.Get("elastic_in_out")
	Expect.Near(ease(0.5), 0.5, 1e-6)
	Expect.Near(ease(0.999999), 1, 1e-3)
	Expect.Near(ease(0.000001), 0, 1e-3)
	Expect.Near(ease(0.5 - 1e-9), ease(0.5 + 1e-9), 1e-5)
end)

Test("non overshooting easings stay monotonic", function()
	for _, family in { "quad", "cubic", "quart", "quint", "sine", "expo", "circ" } do
		for _, suffix in { "_in", "_out", "_in_out" } do
			const ease = Easing.Get(family .. suffix)
			local previous = ease(0)
			for step = 1, 200 do
				const value = ease(step / 200)
				if value < previous - 1e-9 then
					error(`{family}{suffix} decreases at {step / 200}`)
				end

				previous = value
			end
		end
	end
end)

Test("back and elastic overshoot", function()
	Expect.True(Easing.Get("back_out")(0.8) > 1)
	Expect.True(Easing.Get("back_in")(0.2) < 0)
	Expect.True(Easing.Get("elastic_out")(0.1) > 1)
end)

Test("constant holds until the end", function()
	Expect.Equal(Easing.Constant(0.5), 0)
	Expect.Equal(Easing.Constant(0.999), 0)
	Expect.Equal(Easing.Constant(1), 1)
end)

Test("FromRoblox maps styles and directions", function()
	Expect.Equal(Easing.FromRoblox("Linear", "In"), Easing.Linear)
	Expect.Equal(Easing.FromRoblox("Constant", "Out"), Easing.Constant)
	Expect.Equal(Easing.FromRoblox("Cubic", "In"), Easing.Get("cubic_in"))
	Expect.Equal(Easing.FromRoblox("CubicV2", "InOut"), Easing.Get("cubic_in_out"))
	Expect.Equal(Easing.FromRoblox("Elastic", "Out"), Easing.Get("elastic_out"))
	Expect.Equal(Easing.FromRoblox("Bounce", "InOut"), Easing.Get("bounce_in_out"))
	Expect.Equal(Easing.FromRoblox("Whatever", "In"), Easing.Linear)
end)

Test("Bezier matches CSS reference points", function()
	const ease = Easing.Bezier(0.25, 0.1, 0.25, 1)
	Expect.Near(ease(0), 0)
	Expect.Near(ease(1), 1)
	Expect.Near(ease(0.5), 0.8024, 1e-3)

	const linear = Easing.Bezier(0, 0, 1, 1)
	Expect.Near(linear(0.37), 0.37, 1e-9)
end)

Test("Reversed mirrors an easing", function()
	const ease = Easing.Get("cubic_in")
	const reversed = Easing.Reversed(ease)
	for step = 0, 10 do
		const t = step / 10
		Expect.Near(reversed(t), 1 - ease(1 - t), 1e-12)
	end
end)

Test("Subrange renormalizes to a partial segment", function()
	const ease = Easing.Get("quad_in")
	const sub = Easing.Subrange(ease, 0.5, 1)
	Expect.Near(sub(0), 0, 1e-9)
	Expect.Near(sub(1), 1, 1e-9)
	Expect.Near(sub(0.5), (ease(0.75) - ease(0.5)) / (1 - ease(0.5)), 1e-9)
end)

return nil
