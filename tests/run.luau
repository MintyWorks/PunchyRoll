--!nocheck

const Harness = require("@tests/harness")

require("@tests/unit/Quat.spec")
require("@tests/unit/Easing.spec")
require("@tests/unit/Timeline.spec")
require("@tests/unit/Signal.spec")
require("@tests/unit/Rig.spec")
require("@tests/unit/Clip.spec")
require("@tests/unit/Solver.spec")
require("@tests/unit/Track.spec")
require("@tests/unit/KeyframeLoader.spec")

const filter = ...
if not Harness.Run(filter) then
	error("tests failed")
end
