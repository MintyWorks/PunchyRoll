--!strict
--!optimize 2

const BlendTree = require("./BlendTree")
const Clip = require("./Clip")
const Player = require("./Player")
const Signal = require("./Signal")
const Track = require("./Track")

export type StateConfig = {
	Clip: Clip.Clip?,
	Tree: BlendTree.BlendTree?,
	Speed: number?,
	Weight: number?,
	LoopMode: string?,
	Fade: number?,
	Next: string?,
	NextFade: number?,
	OnEnter: ((from: string?) -> ())?,
	OnExit: ((to: string) -> ())?,
}

export type TransitionConfig = {
	Condition: ((params: { [string]: number | boolean }) -> boolean)?,
	Trigger: string?,
	Fade: number?,
	ExitTime: number?,
	Priority: number?,
}

type State = {
	Name: string,
	Config: StateConfig,
	Track: Track.Track?,
	Ended: Signal.Connection?,
}

type Transition = {
	To: string,
	Config: TransitionConfig,
	Order: number,
}

type MachineData = {
	Player: Player.Player,
	Current: string?,
	Params: { [string]: number | boolean },
	StateChanged: Signal.Signal,
	_states: { [string]: State },
	_transitions: { [string]: { Transition } },
	_triggers: { [string]: boolean },
	_counter: number,
}

const ANY = "*"

const StateMachine = {}
StateMachine.__index = StateMachine

export type StateMachine = typeof(setmetatable({} :: MachineData, StateMachine))

function StateMachine.New(player: Player.Player): StateMachine
	return setmetatable({
		Player = player,
		Current = nil,
		Params = {},
		StateChanged = Signal.New(),
		_states = {},
		_transitions = {},
		_triggers = {},
		_counter = 0,
	}, StateMachine)
end

function StateMachine.AddState(self: StateMachine, name: string, config: StateConfig)
	assert(self._states[name] == nil, `State '{name}' already exists`)
	assert(config.Clip or config.Tree, `State '{name}' needs a Clip or a Tree`)
	assert(not (config.Clip and config.Tree), `State '{name}' cannot have both a Clip and a Tree`)

	self._states[name] = { Name = name, Config = config, Track = nil, Ended = nil }
end

function StateMachine.AddTransition(self: StateMachine, from: string, to: string, config: TransitionConfig?)
	assert(from == ANY or self._states[from], `Unknown state '{from}'`)
	assert(self._states[to], `Unknown state '{to}'`)

	const list = self._transitions[from] or {}
	self._transitions[from] = list

	self._counter += 1
	table.insert(list, { To = to, Config = config or {}, Order = self._counter })
	table.sort(list, function(left: Transition, right: Transition)
		const a, b = left.Config.Priority or 0, right.Config.Priority or 0
		if a ~= b then
			return a > b
		end

		return left.Order < right.Order
	end)
end

function StateMachine.SetParam(self: StateMachine, name: string, value: number | boolean)
	self.Params[name] = value
end

function StateMachine.GetParam(self: StateMachine, name: string): (number | boolean)?
	return self.Params[name]
end

function StateMachine.SetTrigger(self: StateMachine, name: string)
	self._triggers[name] = true
end

function StateMachine.ResetTrigger(self: StateMachine, name: string)
	self._triggers[name] = nil
end

function StateMachine.GetTrack(self: StateMachine): Track.Track?
	const current = if self.Current then self._states[self.Current] else nil
	return if current then current.Track else nil
end

const function enter(self: StateMachine, state: State, fade: number)
	const config = state.Config

	if config.Clip then
		const track = self.Player:Play(config.Clip, {
			FadeTime = fade,
			Speed = config.Speed,
			Weight = config.Weight,
			LoopMode = config.LoopMode,
			StartTime = 0,
		} :: any)

		state.Track = track

		if config.Next then
			const nextName = config.Next
			const nextFade = config.NextFade
			state.Ended = track.Ended:Once(function()
				if self.Current == state.Name then
					self:Go(nextName, nextFade)
				end
			end)
		end
	elseif config.Tree then
		config.Tree:Play(fade)
		state.Track = config.Tree:GetLead()
	end
end

const function leave(self: StateMachine, state: State, fade: number, keep: Clip.Clip?)
	const config = state.Config

	if state.Ended then
		state.Ended:Disconnect()
		state.Ended = nil
	end

	if config.Clip and config.Clip ~= keep then
		self.Player:Stop(config.Clip.Name, fade)
	elseif config.Tree then
		config.Tree:Stop(fade)
	end

	state.Track = nil
end

function StateMachine.Go(self: StateMachine, name: string, fade: number?)
	const target = self._states[name]
	assert(target, `Unknown state '{name}'`)

	const previousName = self.Current
	const previous = if previousName then self._states[previousName] else nil
	const duration = fade or target.Config.Fade or 0.1

	if previous then
		if previous.Config.OnExit then
			previous.Config.OnExit(name)
		end

		leave(self, previous, duration, target.Config.Clip)
	end

	self.Current = name
	enter(self, target, duration)

	if target.Config.OnEnter then
		target.Config.OnEnter(previousName)
	end

	self.StateChanged:Fire(previousName, name)
end

function StateMachine.Start(self: StateMachine, name: string, fade: number?)
	self:Go(name, fade or 0)
end

const function ready(self: StateMachine, transition: Transition, state: State): boolean
	const config = transition.Config

	if config.ExitTime then
		const track = state.Track
		if not track or track:GetNormalizedTime() < config.ExitTime then
			return false
		end
	end

	if config.Trigger and not self._triggers[config.Trigger] then
		return false
	end

	if config.Condition and not config.Condition(self.Params) then
		return false
	end

	return true
end

function StateMachine.Update(self: StateMachine, dt: number)
	const currentName = self.Current
	if currentName then
		const state = self._states[currentName]

		for _, source in { currentName, ANY } do
			const list = self._transitions[source]
			if not list then
				continue
			end

			local taken: Transition? = nil
			for _, transition in list do
				if transition.To ~= currentName and ready(self, transition, state) then
					taken = transition
					break
				end
			end

			if taken then
				if taken.Config.Trigger then
					self._triggers[taken.Config.Trigger] = nil
				end

				self:Go(taken.To, taken.Config.Fade)
				break
			end
		end
	end

	for _, state in self._states do
		const tree = state.Config.Tree
		if tree then
			tree:Update(dt)
		end
	end
end

function StateMachine.Destroy(self: StateMachine)
	if self.Current then
		const state = self._states[self.Current]
		if state then
			leave(self, state, 0, nil)
		end
	end

	self.StateChanged:Destroy()
	table.clear(self._states)
	table.clear(self._transitions)
end

return StateMachine
