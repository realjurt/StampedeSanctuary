--!strict
-- Creates RemoteEvents under ReplicatedStorage.Remotes and wraps handlers with a per-player rate limit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local lastCall: { [string]: { [Player]: number } } = {}

Players.PlayerRemoving:Connect(function(player)
	for _, calls in lastCall do
		calls[player] = nil
	end
end)

-- Handler runs at most once per `cooldown` seconds per player. Extra arguments are passed through
-- untrusted — handlers must validate them.
function Net.on(name: string, cooldown: number, handler: (Player, ...any) -> ())
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	lastCall[name] = {}

	remote.OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		local previous = lastCall[name][player]
		if previous and now - previous < cooldown then
			return
		end
		lastCall[name][player] = now
		handler(player, ...)
	end)
	return remote
end

-- Server → client only (no handler). `unreliable` for cosmetic, droppable messages.
function Net.event(name: string, unreliable: boolean?): RemoteEvent | UnreliableRemoteEvent
	local remote = Instance.new(if unreliable then "UnreliableRemoteEvent" else "RemoteEvent") :: any
	remote.Name = name
	remote.Parent = folder
	return remote
end

return Net
