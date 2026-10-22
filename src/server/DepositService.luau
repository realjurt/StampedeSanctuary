--!strict
-- Deposits carried animals into the owner's pen (P3, D-025). Triggered by the pen's server-side
-- ProximityPrompt, so no client data is trusted: the server checks ownership, distance and state,
-- flips the records in one non-yielding update, saves, and only then starts the reveal.
-- Replies to the depositor on "DepositResult": (ok, count | reason, incomeAdded, totalIncome).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local AnimalCollection = require(script.Parent.AnimalCollection)
local Net = require(script.Parent.Net)
local PenService = require(script.Parent.PenService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)

export type Rejection = "busy" | "notOwner" | "notLoaded" | "onSafari" | "tooFar" | "nothingCarried" | "full"

local DepositService = {}

local busy: { [Player]: boolean } = {} -- one deposit at a time per player
local result: RemoteEvent

-- Runs every check without changing anything.
function DepositService.check(player: Player, plot: SanctuaryBuilder.Plot): Rejection?
	if busy[player] then
		return "busy"
	end
	if PlotService.getPlot(player) ~= plot or plot.model:GetAttribute("OwnerUserId") ~= player.UserId then
		return "notOwner"
	end
	local data = PlayerDataService.peek(player)
	if not data then
		return "notLoaded"
	end
	if player:GetAttribute("InSafari") == true then
		return "onSafari"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - plot.penCFrame.Position).Magnitude > EconomyConfig.depositRange then
		return "tooFar"
	end
	if AnimalCollection.countCarried(data) == 0 then
		return "nothingCarried"
	end
	if AnimalCollection.countInPen(data) >= EconomyConfig.penCapacity then
		return "full"
	end
	return nil
end

function DepositService.deposit(player: Player, plot: SanctuaryBuilder.Plot)
	local rejection = DepositService.check(player, plot)
	if rejection then
		if rejection ~= "busy" then
			warn(`DepositService: rejected deposit from {player.Name} ({rejection})`)
		end
		result:FireClient(player, false, rejection)
		return
	end

	busy[player] = true
	local ok, err = pcall(function()
		local deposited: { AnimalCollection.AnimalRecord } = {}
		-- Nothing yields inside the mutator, so the records can't change between check and flip.
		PlayerDataService.update(player, function(data)
			deposited = AnimalCollection.depositCarried(data, EconomyConfig.penCapacity)
		end, true)
		-- Write it before showing anything. If the write fails the in-memory data stays authoritative
		-- and is retried by the autosave and on leave; the deposit itself is never undone or repeated.
		local saved = PlayerDataService.saveNow(player)
		if not saved and not player:GetAttribute("DataSaveDisabled") then
			warn(`DepositService: deposit for {player.Name} not saved yet — will retry`)
		end

		local data = PlayerDataService.peek(player)
		if player.Parent and data and #deposited > 0 then
			local added = 0
			for _, record in deposited do
				added += AnimalCollection.incomeOf(record.species)
			end
			PenService.reveal(player, deposited)
			result:FireClient(player, true, #deposited, added, AnimalCollection.penIncome(data))
		end
	end)
	busy[player] = nil
	if not ok then
		warn(`DepositService: deposit error for {player.Name}: {err}`)
	end
end

function DepositService.start(plots: { SanctuaryBuilder.Plot })
	result = Net.event("DepositResult") :: RemoteEvent
	for _, plot in plots do
		plot.depositPrompt.Triggered:Connect(function(player)
			DepositService.deposit(player, plot)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return DepositService
