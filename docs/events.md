# Animation events

Events come from `KeyframeMarker` instances (kind `marker`) and from keyframes with a custom name (kind `keyframe`). Keyframes still called `Keyframe` are ignored.

## Listening by name

```luau
track:GetMarkerReachedSignal("hitreg"):Connect(function(event, track) end)
player:GetMarkerReachedSignal("footstep"):Connect(function(event, track) end)
```

Track signals only see that track. Player signals see every track the player owns.

Names can use a leading and/or trailing `*`:

| Pattern | Matches |
| --- | --- |
| `hitreg*` | `hitreg`, `hitreg_start`, `hitreg_end` |
| `*_end` | any name ending in `_end` |
| `*sound*` | any name containing `sound` |
| `*` | everything |

## Parameters

The marker `Value` is parsed as `key=value` pairs separated by `;` or `,`. Numbers and booleans are converted, and a bare word becomes `true`.

`damage=25;knockback=true;crit` gives `{ damage = 25, knockback = true, crit = true }` in `event.Params`.

## Windows

A pair named `<name>_start` and `<name>_end` forms a window.

```luau
track:OnWindow("hitreg", function(event)
	hitbox:Enable()
end, function(event)
	hitbox:Disable()
end)

if track:IsWindowActive("hitreg") then end
if player:IsWindowActive("hitreg") then end
```

The close callback also runs if the track stops while the window is open, with `nil` as the event.

## Timing rules

- A frame covers the half-open range from the previous time up to the current one, so an event is never fired twice and never skipped when `dt` is large.
- Looping tracks fire events on every cycle, including a big step that spans several loops. A single update handles at most 32 loop legs.
- `ping_pong` fires an event at the turning point once.
- Events at time `0` fire on the first update after `Play`.
- `Seek(time, true)` fires the events it passes over. `Seek(time)` does not.
- A handler that errors is reported with `warn` and does not stop the other handlers or the animation.

## Reading events from a clip

```luau
clip:HasEvent("hitreg")
clip:GetEventTime("hitreg", 1)
clip:GetEventTimes("hitreg")
clip:GetWindows("hitreg")
clip:GetEventsBetween(0.2, 0.6, true)
```
