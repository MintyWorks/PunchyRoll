--!strict

const Signal = require("./Signal")

type PatternEntry = {
	Pattern: string,
	Signal: Signal.Signal,
}

type RouterData = {
	_exact: { [string]: Signal.Signal },
	_patterns: { PatternEntry },
}

const EventRouter = {}
EventRouter.__index = EventRouter

export type EventRouter = typeof(setmetatable({} :: RouterData, EventRouter))

const function matches(pattern: string, name: string): boolean
	if pattern == "*" then
		return true
	end

	const leading = string.sub(pattern, 1, 1) == "*"
	const trailing = string.sub(pattern, -1) == "*"
	const core = string.sub(pattern, if leading then 2 else 1, if trailing then -2 else -1)

	if leading and trailing then
		return string.find(name, core, 1, true) ~= nil
	elseif leading then
		return core == "" or string.sub(name, -#core) == core
	end

	return string.sub(name, 1, #core) == core
end

function EventRouter.New(): EventRouter
	return setmetatable({
		_exact = {},
		_patterns = {},
	}, EventRouter)
end

function EventRouter.Get(self: EventRouter, name: string): Signal.Signal
	if string.find(name, "*", 1, true) then
		for _, entry in self._patterns do
			if entry.Pattern == name then
				return entry.Signal
			end
		end

		const signal = Signal.New()
		table.insert(self._patterns, { Pattern = name, Signal = signal })
		return signal
	end

	const existing = self._exact[name]
	if existing then
		return existing
	end

	const signal = Signal.New()
	self._exact[name] = signal
	return signal
end

function EventRouter.Dispatch(self: EventRouter, name: string, ...: any)
	const exact = self._exact[name]
	if exact then
		exact:Fire(...)
	end

	for _, entry in self._patterns do
		if matches(entry.Pattern, name) then
			entry.Signal:Fire(...)
		end
	end
end

function EventRouter.Destroy(self: EventRouter)
	for _, signal in self._exact do
		signal:Destroy()
	end

	for _, entry in self._patterns do
		entry.Signal:Destroy()
	end

	table.clear(self._exact)
	table.clear(self._patterns)
end

return EventRouter
