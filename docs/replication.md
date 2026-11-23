# Replication

PunchyRoll writes `Motor6D.Transform` on whichever machine runs the player. Roblox does not replicate `Transform`, so an animation played only on one client is invisible to the server and to everyone else.

The replication option fixes that by sending animation commands instead of poses. Each machine, server included, runs its own `Player` and plays the same clips from the same commands. The commands are tiny (a play is 21 bytes) and are batched into one buffer per flush.

Because the server runs the animation too, named events such as `hitreg` fire on the server, so hit detection can live there.

## What is sent

`Play`, `Stop`, `StopAll`, `Pause`, `Resume`, `Seek`, `SetWeight` and `SetSpeed`. Priority and loop mode can be overridden per play. Everything else about a track comes from the clip registry, which both sides build the same way.

Not sent: IK, `PostSolve` edits, root motion results and anything else computed locally. Each machine computes those itself from the same animation.

## Setup

Make one `RemoteEvent` in ReplicatedStorage, for example `AnimationRemote`. Both sides build the same registry. Clip names must be unique, and ids are assigned by sorted name, so the order you pass the clips in does not matter.

```luau
const registry = PunchyRoll.Replication.ClipRegistry.New({ idle, run, slash }, {
	Slash = { Priority = 3, EndFade = 0.1 },
})
```

The second argument holds per-clip track options (priority, mask, end fade and so on). It must be the same on every machine.

### Server

```luau
const Replicator = PunchyRoll.Replication.Replicator

const net = PunchyRoll.Net.Server.New(ReplicatedStorage.AnimationRemote)

const function now()
	return workspace:GetServerTimeNow()
end

const entities = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		const rig = PunchyRoll.ModelRig.FromModel(character)
		const animator = PunchyRoll.Player.New(rig.Rig)
		const replicator = Replicator.New(animator, registry, { Now = now })

		entities[player.UserId] = { Replicator = replicator, Character = character }
		net:Register(player.UserId, replicator, player)
		net:SendSnapshots(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	entities[player.UserId] = nil
	net:Unregister(player.UserId)
	net:ForgetPlayer(player)
end)

RunService.Heartbeat:Connect(function(dt)
	for _, entity in entities do
		const root = entity.Character:GetPivot()
		entity.Replicator:Update(dt, root)
	end
end)
```

The server never needs to write `Transform` for these players. It only runs the animation so events fire and history can be recorded.

Only the owner passed to `Register` can drive that entity. Anyone else sending commands for it is ignored.

For something the server controls, such as an NPC, leave out the owner. Its commands are broadcast to every client automatically.

```luau
net:Register(npcId, npcReplicator)
npcReplicator:Play("Slash")
```

### Client

```luau
const net = PunchyRoll.Net.Client.New(ReplicatedStorage.AnimationRemote)

const function now()
	return workspace:GetServerTimeNow()
end

const mine = Replicator.New(PunchyRoll.Player.New(rig.Rig), registry, { Now = now })
net:Register(localPlayer.UserId, mine, true)

const theirs = Replicator.New(PunchyRoll.Player.New(otherRig.Rig), registry, { Now = now })
net:Register(otherPlayer.UserId, theirs)

mine:Play("Slash", { FadeTime = 0.1 })

RunService.PreSimulation:Connect(function(dt)
	mine:Update(dt, root)
	PunchyRoll.ModelRig.WriteTransforms(myModelRig)
end)
```

Call `Register` with `true` only for the character this client controls. Other entries only receive. Messages that arrive before `Register` is called are kept and applied when it is.

Use the replicator's own methods (`Play`, `Stop`, `Seek` and so on) instead of the player's. They apply the change locally and queue it for sending. `Update` flushes the queue and then updates the player. Set `Immediate = true` in the options to send every command at once instead of batching.

## Latency

Every batch carries a timestamp. The receiver advances a newly started animation by the time the message spent in transit, scaled by speed, up to `MaxLatency` seconds (default 1). A one shot clip that would already have finished is skipped. Use `workspace:GetServerTimeNow()` for `Now` on both sides so the clocks agree.

## Late joiners

`net:SendSnapshots(player)` sends the state of every registered entity that is currently playing: clip, time, speed, weight and whether it is paused.

## Safety

The server checks every message before it applies or forwards it:

- argument types, and buffer size (`MaxBytes`, default 1024)
- the sender owns the entity
- a per-player rate limit (`MaxBatchesPerSecond`, default 30)
- the buffer decodes cleanly, with known clip ids and at most 64 commands

Values are clamped on receive: fade 0 to 10 seconds, weight 0 to 10, speed -10 to 10, times 0 to 10000. `NaN` is replaced with a default. Pass `Validate = function(command) return ... end` to `Replicator.New` to reject commands yourself, for example to stop clients playing clips a character should not have.

## Limits

- One track per clip per player. Tracks are identified by clip name.
- If you need to send an entire pose instead of commands, this is not the tool for it.
