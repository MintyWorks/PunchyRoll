# Clips, rigs, masks

## Rig

```luau
const rig = Rig.New({
	Name = "Torso", C0 = CFrame.new(), C1 = CFrame.new(),
	Children = { { Name = "Head", C0 = headC0, C1 = headC1 } },
})

const rig2 = Rig.FromLimbs({
	{ Name = "Torso", Parent = nil, C0 = a, C1 = b },
	{ Name = "Head", Parent = "Torso", C0 = c, C1 = d },
})
```

`FromLimbs` accepts any order and sorts parents first. It errors on duplicate names, unknown parents and cycles or unreachable limbs. Joint names must match pose names in your animations. `ModelRig.FromModel` names each joint after the `Part1` of its `Motor6D`, which is what Roblox uses for poses.

## Clip editing

All of these return a new clip: `Reverse`, `ScaleTime`, `Slice`, `MakeAdditive`, `KeepJoints`, `RemoveJoints`, `RemapJoints`. `Reverse` also swaps `_start` and `_end` event names. `Clip:Describe()` prints a summary.

`Clip:Bind(rig)` is cached per rig. `GetUnmatchedJoints` lists joints in the clip that the rig does not have.

## Masks

```luau
const upperBody = Mask.FromSubtree(rig, "Torso")
const armsOnly = Mask.FromJoints(rig, { "LeftArm", "RightArm" })
const feathered = Mask.New(rig, 0):Falloff("Torso", 1, 0.25)
```

## Easing

Names look like `cubic_in_out`. Families are `quad`, `cubic`, `quart`, `quint`, `sine`, `expo`, `circ`, `back`, `elastic` and `bounce`, each with `_in`, `_out` and `_in_out`, plus `linear` and `constant`. A keyframe's `Easing` controls the segment that starts at that keyframe.

## Loading Roblox animations

```luau
KeyframeLoader.Load(sequence, { EasingMode = "outgoing" })
```

`outgoing` is the behavior of the original CrunchyRoll. `incoming` shifts each pose's easing onto the segment that leads into it for animations authored with the easing of the pose you are moving toward.
