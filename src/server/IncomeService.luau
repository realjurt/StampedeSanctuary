--!strict
-- Passive income (P3, D-025): every tick each player earns their pen animals' coins per second.
-- Computed only from server data; carried animals never earn; nothing is earned while offline.
-- Coin changes use deferSave (autosave + save on leave), as planned in D-023.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local AnimalCollection = require(script.Parent.AnimalCollection)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

local IncomeService = {}

function IncomeService.start()
	local incomeTick = Net.event("IncomeTick", true) :: UnreliableRemoteEvent -- cosmetic "+$N" pops
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.incomeInterval)
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.peek(player)
				local earned = if data then AnimalCollection.penIncome(data) * EconomyConfig.incomeInterval else 0
				if earned > 0 then
					PlayerDataService.update(player, function(current)
						current.coins = math.min(current.coins + earned, EconomyConfig.maxCoins)
					end, true)
					incomeTick:FireClient(player, earned)
				end
			end
		end
	end)
end

return IncomeService
