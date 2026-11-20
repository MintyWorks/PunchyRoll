--!nocheck

const Harness = require("@tests/harness")
const Timeline = require("@src/Timeline")

const Test, Expect = Harness.Test, Harness.Expect

Test("once clamps and reports the end", function()
	const time, finished = Timeline.Resolve(0.5, 2, "once")
	Expect.Equal(time, 0.5)
	Expect.False(finished)

	const endTime, endFinished = Timeline.Resolve(2.5, 2, "once")
	Expect.Equal(endTime, 2)
	Expect.True(endFinished)

	const backTime, backFinished = Timeline.Resolve(-0.5, 2, "once")
	Expect.Equal(backTime, 0)
	Expect.True(backFinished)

	const startTime, startFinished = Timeline.Resolve(0, 2, "once")
	Expect.Equal(startTime, 0)
	Expect.False(startFinished)
end)

Test("loop wraps in both directions", function()
	Expect.Near(Timeline.Resolve(2.5, 2, "loop"), 0.5)
	Expect.Near(Timeline.Resolve(-0.5, 2, "loop"), 1.5)
	Expect.Near(Timeline.Resolve(6, 2, "loop"), 0)
end)

Test("ping_pong bounces", function()
	Expect.Near(Timeline.Resolve(0.5, 2, "ping_pong"), 0.5)
	Expect.Near(Timeline.Resolve(2.5, 2, "ping_pong"), 1.5)
	Expect.Near(Timeline.Resolve(4.5, 2, "ping_pong"), 0.5)
	Expect.Near(Timeline.Resolve(-0.5, 2, "ping_pong"), 0.5)
end)

Test("zero length clips are safe", function()
	const time, finished = Timeline.Resolve(5, 0, "loop")
	Expect.Equal(time, 0)
	Expect.False(finished)
end)

Test("FadeInfluence ramps in and out", function()
	Expect.Near(Timeline.FadeInfluence(0, 2, 0.5, 0), 0)
	Expect.Near(Timeline.FadeInfluence(0.25, 2, 0.5, 0), 0.5)
	Expect.Near(Timeline.FadeInfluence(1, 2, 0.5, 0.5), 1)
	Expect.Near(Timeline.FadeInfluence(1.75, 2, 0.5, 0.5), 0.5)
	Expect.Near(Timeline.FadeInfluence(2, 2, 0.5, 0.5), 0)
	Expect.Near(Timeline.FadeInfluence(0.5, 2, 0, 0), 1)
end)

const function pieces(from, to, length, mode, includeStart)
	const result = {}
	Timeline.Pieces(from, to, length, mode, includeStart, function(a, b, inclusive)
		table.insert(result, `{string.format("%.2f", a)}>{string.format("%.2f", b)}{if inclusive then "i" else "x"}`)
	end)

	return table.concat(result, " ")
end

Test("Pieces clamps once and clamp modes", function()
	Expect.Equal(pieces(0.5, 1.5, 2, "once", true), "0.50>1.50i")
	Expect.Equal(pieces(1.5, 3, 2, "once", false), "1.50>2.00x")
	Expect.Equal(pieces(2.5, 3, 2, "clamp", false), "2.00>2.00x")
	Expect.Equal(pieces(1, -1, 2, "once", false), "1.00>0.00x")
	Expect.Equal(pieces(1, 1, 2, "once", true), "")
end)

Test("Pieces splits loops at the seam", function()
	Expect.Equal(pieces(0.5, 1.5, 2, "loop", false), "0.50>1.50x")
	Expect.Equal(pieces(1.5, 2.5, 2, "loop", false), "1.50>2.00x 0.00>0.50i")
	Expect.Equal(pieces(1.5, 4.5, 2, "loop", true), "1.50>2.00i 0.00>2.00i 0.00>0.50i")
	Expect.Equal(pieces(1.5, 2, 2, "loop", false), "1.50>2.00x")
	Expect.Equal(pieces(1.5, 2.25, 2, "loop", false), "1.50>2.00x 0.00>0.25i")
end)

Test("Pieces walks loops backwards", function()
	Expect.Equal(pieces(1.5, 0.5, 2, "loop", false), "1.50>0.50x")
	Expect.Equal(pieces(0.5, -0.5, 2, "loop", false), "0.50>0.00x 2.00>1.50i")
	Expect.Equal(pieces(2, 1, 2, "loop", false), "2.00>1.00x")
end)

Test("Pieces reflects ping pong legs", function()
	Expect.Equal(pieces(1.5, 2.5, 2, "ping_pong", false), "1.50>2.00x 2.00>1.50x")
	Expect.Equal(pieces(0.5, 4.5, 2, "ping_pong", true), "0.50>2.00i 2.00>0.00x 0.00>0.50x")
	Expect.Equal(pieces(0.5, -0.5, 2, "ping_pong", false), "0.50>0.00x 0.00>0.50x")
end)

Test("Pieces caps the number of legs for huge steps", function()
	local count = 0
	Timeline.Pieces(0, 10000, 1, "loop", true, function()
		count += 1
	end)

	Expect.True(count <= 33)
	Expect.True(count >= 32)
end)

Test("Pieces handles empty clips", function()
	Expect.Equal(pieces(0, 1, 0, "loop", true), "0.00>0.00i")
end)

return nil
