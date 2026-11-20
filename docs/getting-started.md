# Getting started

PunchyRoll plays animations without an `Animator`. Clips are sampled into a pose, layered with Roblox priority rules, then composed into CFrames.

```luau
const PunchyRoll = require("@packages/punchyroll")

const rig = PunchyRoll.ModelRig.FromModel(character)
const player = PunchyRoll.Player.New(rig.Rig, { RootMotionJoint = "LowerTorso" })

const slash = PunchyRoll.KeyframeLoader.Load(slashSequence)
const track = player:Play(slash, { FadeTime = 0.1 })

track:GetMarkerReachedSignal("hitreg"):Connect(function(event)
	print("hit window", event.Time, event.Params.damage)
end)

RunService.PreSimulation:Connect(function(dt)
	player:Update(dt, character.PrimaryPart.CFrame)
	PunchyRoll.ModelRig.WriteTransforms(rig)
end)
```

`Player:Update` returns the composed CFrames by joint name. `ModelRig.WriteTransforms` copies each joint's transform into its `Motor6D`, and `ModelRig.WriteParts` moves the parts directly with `BulkMoveTo`.

## Building clips in code

```luau
const clip = PunchyRoll.Clip.New({
	Name = "Slash",
	Length = 0.8,
	Joints = {
		RightArm = {
			{ Time = 0, Position = vector.zero, Easing = "cubic_out" },
			{ Time = 0.8, Position = vector.create(0, 1, 0) },
		},
	},
	Events = {
		{ Time = 0.3, Name = "hitreg", Value = "damage=25;knockback=true" },
	},
})
```
