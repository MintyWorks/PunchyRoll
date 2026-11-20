# Changelog

## 0.2.0

Fork of CrunchyRoll 0.1.1 as PunchyRoll. The API is new and does not match the original.

- Added named animation events, wildcard listeners, parameters and windows
- Added `Player` and `Track` with fades, speed, weight ramps and loop modes
- Added root motion, masks, additive layers and clip editing
- Rewrote the solver to use priority tiers, order-independent blending and shortest-path quaternions
- Fixed the elastic and bounce easings
- Added `KeyframeLoader` and `ModelRig` for Roblox instances
- Replaced the test setup with a plain Luau runner
