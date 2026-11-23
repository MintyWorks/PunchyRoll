# PunchyRoll

An animation library for Roblox that plays animations without an `Animator`. It is a fork of [CrunchyRoll](https://github.com/ffrostfall/crunchyroll) by ffrostfall, reworked around named animation events, replication and a faster solver.

## Features

- Replication: animations show up for the server and every other player, with batching, latency compensation, late joiner snapshots and server side validation
- Animation events by name, such as `hitreg`, with wildcards, parameters (`damage=25;crit`) and `_start`/`_end` windows
- Loop-safe event timing that does not skip or repeat events at large `dt`
- Tracks with fades, speed and weight ramps, `once`, `clamp`, `loop` and `ping_pong` modes
- Roblox priority blending, additive layers and per-joint masks
- Root motion extraction
- State machine and 1D/2D blend trees
- Two-bone IK and look-at constraints
- Rewind history for server side hit checks
- Clip tools: reverse, slice, retime, additive, joint remap
- Many easing styles
- Loader for `KeyframeSequence` and a rig builder for `Motor6D` models
- Written in strict Luau with `vector` math and no per-frame allocations in the solver

https://github.com/user-attachments/assets/d46ec087-912b-438c-83a9-afe2a398febd

## Example

```luau
const player = PunchyRoll.Player.New(rig)
const track = player:Play(PunchyRoll.KeyframeLoader.Load(sequence), { FadeTime = 0.1 })

track:OnWindow("hitreg", function()
	hitbox:Enable()
end, function()
	hitbox:Disable()
end)
```

Docs: [getting started](docs/getting-started.md), [replication](docs/replication.md), [events](docs/events.md), [tracks](docs/tracks.md), [clips and rigs](docs/clips-and-rigs.md) and [more features](docs/features.md).

## License

MIT. Original work by ffrostfall, modifications by the PunchyRoll authors. See [LICENSE](LICENSE).
