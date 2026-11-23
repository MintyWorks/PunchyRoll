# Changelog

## 0.3.0

- Added replication. `Replication.Replicator` sends play, stop, pause, seek, weight and speed commands as compact buffers, so animations reach the server and other clients. Includes batching, latency compensation, late joiner snapshots, input clamping and a validation hook
- Added `Net.Server` and `Net.Client` for a RemoteEvent, with owner checks, size limits and rate limiting
- Added `ClipRegistry` so every machine agrees on clip ids and track options
- Added `StateMachine` with conditions, triggers, exit times, any-state transitions and automatic next states
- Added `BlendTree` for 1D and 2D blending with phase sync
- Added `Ik.TwoBone` and `Ik.LookAt` constraints
- Added `History` for rewinding poses and event windows on the server
- Added a docs site built from `docs/` and deployed to GitHub Pages

## 0.2.0

Fork of CrunchyRoll 0.1.1 as PunchyRoll. The API is new and does not match the original.

- Added named animation events, wildcard listeners, parameters and windows
- Added `Player` and `Track` with fades, speed, weight ramps and loop modes
- Added root motion, masks, additive layers and clip editing
- Rewrote the solver to use priority tiers, order-independent blending and shortest-path quaternions
- Fixed the elastic and bounce easings
- Added `KeyframeLoader` and `ModelRig` for Roblox instances
- Replaced the test setup with a plain Luau runner
