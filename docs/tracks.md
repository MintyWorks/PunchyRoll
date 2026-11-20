# Tracks and players

`Player:Load(clip, options)` creates a track without starting it. `Player:Play(clipOrName, options)` loads if needed and plays.

## Track options

| Option | Default | Meaning |
| --- | --- | --- |
| `Name` | clip name | Name used by `Player:Play("name")` |
| `Priority` | clip priority | Higher tiers win blending |
| `Weight` | `1` | Base weight |
| `Speed` | `1` | Negative plays backwards |
| `LoopMode` | from clip | `once`, `clamp`, `loop` or `ping_pong` |
| `Mask` | none | Per-joint weights from `Mask` |
| `Additive` | clip setting | Applied on top of the base pose |
| `EndFade` | `0` | Fade out over the last seconds of a `once` clip |
| `FadeEasing` | linear | Easing applied to fades |

## Playing

```luau
track:Play({ FadeTime = 0.2, Weight = 1, Speed = 1, StartTime = 0 })
track:Stop(0.2)
track:Pause()
track:Resume()
track:Seek(0.5, true)
track:SetNormalizedTime(0.5)
track:SetWeight(0.5, 0.3)
track:SetSpeed(2, 0.3)
```

The last argument of `SetWeight` and `SetSpeed` is a ramp time in seconds.

## Signals

`Started`, `Stopped`, `Ended`, `DidLoop` and `EventReached`. `Ended` fires when a `once` or `clamp` track reaches its end. `once` tracks then stop, `clamp` tracks hold the last pose.

## Blending

Layers follow Roblox rules:

- Higher priority tiers take up to their total weight from what is left.
- Weight that is not taken falls through to lower tiers, then to the rest pose.
- Layers with the same priority are normalized against each other, so the order they were played in does not matter.
- Additive layers are applied after the base blend.
- Quaternions are blended along the shortest path.

## Root motion

Set `RootMotionJoint` on the player. After each update `player.RootMotion` fires with the accumulated translation, rotation vector and rotation scalar from all playing tracks, weighted by their fades. Apply it to your character yourself.

## Post solve hook

```luau
player.PostSolve:Connect(function(pose, dt)
	pose.Positions[index] += vector.create(0, 0.1, 0)
end)
```

The pose can be edited here before it is composed into CFrames.
