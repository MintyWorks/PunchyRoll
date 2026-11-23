--!strict

const Replicator = require("../replication/Replicator")

export type ServerOptions = {
	MaxBytes: number?,
	MaxBatchesPerSecond: number?,
	Recipients: (() -> { Player })?,
}

type Entity = {
	Replicator: Replicator.Replicator,
	Owner: Player?,
}

type Bucket = {
	Tokens: number,
	Updated: number,
}

type ServerData = {
	Remote: RemoteEvent,
	MaxBytes: number,
	MaxBatchesPerSecond: number,
	Recipients: () -> { Player },
	_entities: { [number]: Entity },
	_buckets: { [Player]: Bucket },
	_connection: RBXScriptConnection?,
}

type ClientData = {
	Remote: RemoteEvent,
	_entities: { [number]: Replicator.Replicator },
	_pending: { [number]: { buffer } },
	_connection: RBXScriptConnection?,
}

const MAX_PENDING = 16

const Server = {}
Server.__index = Server

const Client = {}
Client.__index = Client

export type Server = typeof(setmetatable({} :: ServerData, Server))
export type Client = typeof(setmetatable({} :: ClientData, Client))

const Net = {
	Server = Server,
	Client = Client,
}

const function allowed(self: Server, sender: Player): boolean
	const now = os.clock()
	const limit = self.MaxBatchesPerSecond
	local bucket = self._buckets[sender]
	if not bucket then
		bucket = { Tokens = limit, Updated = now }
		self._buckets[sender] = bucket
	end

	const state = bucket :: Bucket
	state.Tokens = math.min(limit, state.Tokens + (now - state.Updated) * limit)
	state.Updated = now

	if state.Tokens < 1 then
		return false
	end

	state.Tokens -= 1
	return true
end

function Server.New(remote: RemoteEvent, options: ServerOptions?): Server
	const opts: ServerOptions = options or {}

	const self: Server = setmetatable({
		Remote = remote,
		MaxBytes = opts.MaxBytes or 1024,
		MaxBatchesPerSecond = opts.MaxBatchesPerSecond or 30,
		Recipients = opts.Recipients or function()
			return game:GetService("Players"):GetPlayers() :: { Player }
		end,
		_entities = {},
		_buckets = {},
		_connection = nil,
	}, Server)

	self._connection = remote.OnServerEvent:Connect(function(sender: any, id: any, payload: any)
		if typeof(id) ~= "number" or typeof(payload) ~= "buffer" then
			return
		end

		if buffer.len(payload) > self.MaxBytes then
			return
		end

		const entity = self._entities[id]
		if not entity or entity.Owner ~= sender then
			return
		end

		if not allowed(self, sender) then
			return
		end

		const accepted = entity.Replicator:Receive(payload)
		if not accepted then
			return
		end

		for _, recipient in self.Recipients() do
			if recipient ~= sender then
				remote:FireClient(recipient, id, payload)
			end
		end
	end)

	return self
end

function Server.Register(self: Server, id: number, replicator: Replicator.Replicator, owner: Player?)
	self._entities[id] = { Replicator = replicator, Owner = owner }

	if not owner then
		replicator.Send = function(payload: buffer)
			self.Remote:FireAllClients(id, payload)
		end
	end
end

function Server.Unregister(self: Server, id: number)
	const entity = self._entities[id]
	if entity and not entity.Owner then
		entity.Replicator.Send = nil
	end

	self._entities[id] = nil
end

function Server.SendSnapshots(self: Server, player: Player)
	for id, entity in self._entities do
		const snapshot = entity.Replicator:Snapshot()
		if snapshot then
			self.Remote:FireClient(player, id, snapshot)
		end
	end
end

function Server.ForgetPlayer(self: Server, player: Player)
	self._buckets[player] = nil
end

function Server.Destroy(self: Server)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	for id in self._entities do
		self:Unregister(id)
	end
end

function Client.New(remote: RemoteEvent): Client
	const self: Client = setmetatable({
		Remote = remote,
		_entities = {},
		_pending = {},
		_connection = nil,
	}, Client)

	self._connection = remote.OnClientEvent:Connect(function(id: any, payload: any)
		if typeof(id) ~= "number" or typeof(payload) ~= "buffer" then
			return
		end

		const replicator = self._entities[id]
		if replicator then
			replicator:Receive(payload)
			return
		end

		const list = self._pending[id] or {}
		self._pending[id] = list
		if #list < MAX_PENDING then
			table.insert(list, payload)
		end
	end)

	return self
end

function Client.Register(self: Client, id: number, replicator: Replicator.Replicator, isLocal: boolean?)
	self._entities[id] = replicator

	if isLocal then
		replicator.Send = function(payload: buffer)
			self.Remote:FireServer(id, payload)
		end
	end

	const pending = self._pending[id]
	if pending then
		self._pending[id] = nil
		for _, payload in pending do
			replicator:Receive(payload)
		end
	end
end

function Client.Unregister(self: Client, id: number)
	self._entities[id] = nil
	self._pending[id] = nil
end

function Client.Destroy(self: Client)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	table.clear(self._entities)
	table.clear(self._pending)
end

return Net
