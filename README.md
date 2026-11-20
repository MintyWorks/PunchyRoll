# PunchyRoll

An animation library for Roblox that plays animations without an `Animator`. It is a fork of [CrunchyRoll](https://github.com/ffrostfall/crunchyroll) by ffrostfall, reworked around named animation events and with a faster solver.

## Features

- Animation events by name, such as `hitreg`, with wildcards, parameters (`damage=25;crit`) and `_start`/`_end` windows
- Loop-safe event timing that does not skip or repeat events at large `dt`
- Tracks with fades, speed and weight ramps, `once`, `clamp`, `loop` and `ping_pong` modes
- Roblox priority blending, additive layers and per-joint masks
- Root motion extraction
- Clip tools: reverse, slice, retime, additive, joint remap
- Many easing styles
- Loader for `KeyframeSequence` and a rig builder for `Motor6D` models
- Written in strict Luau with `vector` math and no per-frame allocations in the solver

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

See [docs](docs/getting-started.md), [events](docs/events.md), [tracks](docs/tracks.md) and [clips and rigs](docs/clips-and-rigs.md).

## License

MIT. Original work by ffrostfall, modifications by the PunchyRoll authors. See [LICENSE](LICENSE).
