--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type ConnectionData = {
	Connected: boolean,
	_callback: (...any) -> (),
	_once: boolean,
	_signal: SignalData,
}

type SignalData = {
	_connections: { Connection },
	_firing: number,
	_dirty: boolean,
	_destroyed: boolean,
}

const Connection = {}
Connection.__index = Connection

const Signal = {}
Signal.__index = Signal

export type Signal<T... = ...any> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnectionCount: (self: Signal<T...>) -> number,
	Destroy: (self: Signal<T...>) -> (),
}

local report: (...any) -> () = if typeof(warn) == "function" then warn else print

const function handleError(message: any): string
	return debug.traceback(tostring(message), 2)
end

function Signal.SetErrorReporter(reporter: ((...any) -> ())?)
	report = reporter or (if typeof(warn) == "function" then warn else print)
end

function Connection.Disconnect(self: ConnectionData)
	if not self.Connected then
		return
	end

	self.Connected = false
	self._signal._dirty = true
end

function Signal.New(): Signal
	return setmetatable({
		_connections = {},
		_firing = 0,
		_dirty = false,
		_destroyed = false,
	}, Signal) :: any
end

function Signal.Connect(self: SignalData, callback: (...any) -> ()): Connection
	const connection: ConnectionData = setmetatable({
		Connected = not self._destroyed,
		_callback = callback,
		_once = false,
		_signal = self,
	}, Connection) :: any

	if not self._destroyed then
		table.insert(self._connections, connection :: any)
	end

	return connection :: any
end

function Signal.Once(self: SignalData, callback: (...any) -> ()): Connection
	const connection = Signal.Connect(self, callback)
	;(connection :: any)._once = true
	return connection
end

function Signal.Fire(self: SignalData, ...: any)
	const connections = self._connections
	const count = #connections
	if count == 0 then
		return
	end

	self._firing += 1
	for index = 1, count do
		const connection = connections[index] :: any
		if not connection.Connected then
			continue
		end

		if connection._once then
			connection.Connected = false
			self._dirty = true
		end

		const success, message = xpcall(connection._callback, handleError, ...)
		if not success then
			report(message)
		end
	end
	self._firing -= 1

	if self._dirty and self._firing == 0 then
		self._dirty = false

		local write = 0
		const length = #connections
		for read = 1, length do
			const connection = connections[read]
			if connection.Connected then
				write += 1
				connections[write] = connection
			end
		end

		for index = length, write + 1, -1 do
			connections[index] = nil :: any
		end
	end
end

function Signal.GetConnectionCount(self: SignalData): number
	local count = 0
	for _, connection in self._connections do
		if connection.Connected then
			count += 1
		end
	end

	return count
end

function Signal.DisconnectAll(self: SignalData)
	for _, connection in self._connections do
		connection.Connected = false
	end

	self._dirty = true
	if self._firing == 0 then
		table.clear(self._connections)
		self._dirty = false
	end
end

function Signal.Destroy(self: SignalData)
	Signal.DisconnectAll(self)
	self._destroyed = true
end

return Signal
