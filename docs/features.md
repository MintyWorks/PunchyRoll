# More features

## State machine

```luau
const machine = PunchyRoll.StateMachine.New(player)

machine:AddState("Idle", { Clip = idle })
machine:AddState("Run", { Tree = runTree })
machine:AddState("Slash", { Clip = slash, Next = "Idle", NextFade = 0.15 })

machine:AddTransition("Idle", "Run", {
	Condition = function(params)
		return (params.speed :: number) > 0.5
	end,
	Fade = 0.15,
})
machine:AddTransition("*", "Slash", { Trigger = "attack", Fade = 0.05, Priority = 10 })

machine:Start("Idle")
machine:SetParam("speed", 12)
machine:SetTrigger("attack")

RunService.PreSimulation:Connect(function(dt)
	machine:Update(dt)
	player:Update(dt, root)
end)
```

- A state is eitther a `Clip` or a `Tree`. States can set `Speed`, `Weight`, `LoopMode`, `Fade`, `OnEnter(from)` and `OnExit(to)`.
- `Next` moves to another state when a one shot clip ends.
- `"*"` as the source state means any state. Higher `Priority` transitions are tested first.
- `ExitTime` waits until the state has played that fraction (0 to 1) of its clip.
- Triggers stay set until a transition uses them. `ResetTrigger(name)` clears one.
- `machine.StateChanged` fires with the old and new state names.

## Blend trees

```luau
const tree = PunchyRoll.BlendTree.New(player, {
	Name = "Locomotion",
	Entries = {
		{ Clip = idle, Position = 0 },
		{ Clip = walk, Position = 8 },
		{ Clip = run, Position = 16 },
	},
})

tree:Play(0.2)
tree:SetValue(humanoidSpeed)
tree:Update(dt)
```

A 1D tree interpolates between the two nearest entries. A 2D tree (`Mode = "2D"`, `Position = vector.create(x, y, 0)`, then `SetValue(x, y)`) weights every entry by inverse distance. `Sharpness` (default 2) makes the nearest entries dominate.

The clips are kept in phase and their speeds are scaled to the blended length, so feet do not slide between a walk and a run of different lengths. Tree clips always loop.

## Inverse kinematics

```luau
const ik = PunchyRoll.Ik.TwoBone(rig, {
	Upper = "RightUpperArm",
	Mid = "RightLowerArm",
	Tip = "RightHand",
	Target = function()
		return handle.Position
	end,
	Pole = vector.create(0, 0, -5),
	Weight = 1,
})

PunchyRoll.Ik.LookAt(rig, {
	Joint = "Head",
	Axis = vector.create(0, 0, -1),
	Target = function()
		return target.Position
	end,
	MaxAngle = math.rad(60),
	Weight = 0.8,
})
```

Constraints run after the animation is composed. `Target` can be a vector or a function (return `nil` to skip). Set `ik.Weight` between 0 and 1 to blend in and out, or `ik.Enabled = false`. Names are joint names, so for a `ModelRig` they are `Part1` names. A target out of reach stretches the limb straight toward it.

## Rewind history

Records poses so the server can check a hit against what the animation looked like a moment ago.

```luau
const history = PunchyRoll.History.New(player, {
	Duration = 1,
	Rate = 60,
	Windows = { "hitreg" },
})

RunService.Heartbeat:Connect(function(dt)
	player:Update(dt, root)
	history:Record(workspace:GetServerTimeNow())
end)

if history:WasWindowActive("hitreg", clientTime) then
	const frames = history:Evaluate(clientTime, root)
end
```

`Sample(time, outPose)` blends the two nearest recorded poses. `Evaluate` composes that pose into CFrames on the rig, so use a separate rig if you need the live one untouched. Memory is allocated once up front and recording does not allocate.
