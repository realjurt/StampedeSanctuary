--!strict
-- Training machine and pen purchases (P4, D-026), bought with coins at the plot's server-side
-- prompts, so no client data is trusted. Every purchase checks owner, range, safari, level and
-- coins; one purchase at a time per player; coins and level change in one update and are saved at
-- once. Also publishes each owner's levels to their plot (attributes + sign text) on join and resets
-- the plot when they leave.
-- Replies on "PurchaseResult": (ok, kind, newLevel | reason, price).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local TrainingConfig = require(ReplicatedStorage.Shared.Config.TrainingConfig)
local AnimalCollection = require(script.Parent.AnimalCollection)
local MachineService = require(script.Parent.MachineService)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)

type Plot = SanctuaryBuilder.Plot
export type Kind = "machine" | "pen"
export type Rejection = "busy" | "notOwner" | "notLoaded" | "onSafari" | "tooFar" | "maxLevel" | "coins"

local UpgradeService = {}

local busy: { [Player]: boolean } = {}
local plotOf: { [number]: Plot } = {} -- UserId → plot we published to
local result: RemoteEvent

local function levelOf(data: PlayerDataService.PlayerData, kind: Kind): number
	return if kind == "machine" then data.machineLevel else data.penLevel
end

-- Price of the next level, or nil at max level.
function UpgradeService.nextPrice(kind: Kind, level: number): number?
	local levels = if kind == "machine" then TrainingConfig.levels else EconomyConfig.penLevels
	local nextLevel = levels[level + 1]
	return if nextLevel then nextLevel.price else nil
end

local function promptOf(plot: Plot, kind: Kind): ProximityPrompt
	return if kind == "machine" then plot.machinePrompt else plot.penUpgradePrompt
end

-- Plot attributes and sign text everyone sees for this owner's levels.
local function publish(plot: Plot, data: PlayerDataService.PlayerData?)
	local machineLevel = if data then data.machineLevel else 0
	local penLevel = if data then data.penLevel else 1
	plot.model:SetAttribute("MachineLevel", machineLevel)
	plot.model:SetAttribute("PenLevel", penLevel)
	plot.model:SetAttribute("PenCapacity", AnimalCollection.penCapacity(penLevel))
	MachineService.show(plot, machineLevel)
	if not data then
		plot.machineText.Text = ""
		plot.penUpgradeText.Text = ""
		return
	end

	local machinePrice = UpgradeService.nextPrice("machine", machineLevel)
	plot.machineText.Text = if not machinePrice
		then "MAX LEVEL"
		elseif machineLevel == 0 then `BUY · {Format.money(machinePrice)}`
		else `Lv {machineLevel} → {machineLevel + 1} · {Format.money(machinePrice)}`
	plot.machinePrompt.ActionText = if machineLevel == 0 then "Buy training machine" else `Upgrade machine to Lv {machineLevel + 1}`
	plot.machinePrompt.ObjectText = if machinePrice then Format.money(machinePrice) else ""

	local penPrice = UpgradeService.nextPrice("pen", penLevel)
	local capacity = AnimalCollection.penCapacity(penLevel)
	plot.penUpgradeText.Text = if penPrice
		then `{capacity} → {AnimalCollection.penCapacity(penLevel + 1)} slots · {Format.money(penPrice)}`
		else `MAX · {capacity} slots`
	plot.penUpgradePrompt.ActionText = if penPrice then `Upgrade pen to {AnimalCollection.penCapacity(penLevel + 1)} slots` else "Pen fully upgraded"
	plot.penUpgradePrompt.ObjectText = if penPrice then Format.money(penPrice) else ""
end

-- Runs every check without changing anything. Returns the price on success.
function UpgradeService.check(player: Player, plot: Plot, kind: Kind): (number?, Rejection?)
	if busy[player] then
		return nil, "busy"
	end
	if PlotService.getPlot(player) ~= plot or plot.model:GetAttribute("OwnerUserId") ~= player.UserId then
		return nil, "notOwner"
	end
	local data = PlayerDataService.peek(player)
	if not data then
		return nil, "notLoaded"
	end
	if player:GetAttribute("InSafari") == true then
		return nil, "onSafari"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local sign = promptOf(plot, kind).Parent :: BasePart
	if not root or (root.Position - sign.Position).Magnitude > EconomyConfig.purchaseRange then
		return nil, "tooFar"
	end
	local price = UpgradeService.nextPrice(kind, levelOf(data, kind))
	if not price then
		return nil, "maxLevel"
	end
	if data.coins < price then
		return price, "coins"
	end
	return price, nil
end

function UpgradeService.purchase(player: Player, plot: Plot, kind: Kind)
	local price, rejection = UpgradeService.check(player, plot, kind)
	if rejection or not price then
		if rejection ~= "busy" then
			warn(`UpgradeService: rejected {kind} purchase from {player.Name} ({rejection})`)
		end
		result:FireClient(player, false, kind, rejection, price)
		return
	end

	busy[player] = true
	local ok, err = pcall(function()
		local newLevel = 0
		-- Doesn't yield: level and coins are re-checked and changed together.
		PlayerDataService.update(player, function(data)
			local level = levelOf(data, kind)
			if UpgradeService.nextPrice(kind, level) ~= price or data.coins < price then
				return
			end
			data.coins -= price
			newLevel = level + 1
			if kind == "machine" then
				data.machineLevel = newLevel
			else
				data.penLevel = newLevel
			end
		end, true)
		if newLevel == 0 then
			result:FireClient(player, false, kind, "coins", price)
			return
		end
		-- Like deposits: a failed write keeps the in-memory purchase and is retried by autosave/leave.
		if not PlayerDataService.saveNow(player) and not player:GetAttribute("DataSaveDisabled") then
			warn(`UpgradeService: {kind} purchase for {player.Name} not saved yet — will retry`)
		end
		if player.Parent then
			publish(plot, PlayerDataService.peek(player))
			result:FireClient(player, true, kind, newLevel, price)
		end
	end)
	busy[player] = nil
	if not ok then
		warn(`UpgradeService: {kind} purchase error for {player.Name}: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	local data = PlayerDataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot or not player.Parent then
		return
	end
	plotOf[player.UserId] = plot
	publish(plot, data)
end

function UpgradeService.start(plots: { Plot })
	result = Net.event("PurchaseResult") :: RemoteEvent
	for _, plot in plots do
		publish(plot, nil)
		plot.machinePrompt.Triggered:Connect(function(player)
			UpgradeService.purchase(player, plot, "machine")
		end)
		plot.penUpgradePrompt.Triggered:Connect(function(player)
			UpgradeService.purchase(player, plot, "pen")
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		local plot = plotOf[player.UserId]
		plotOf[player.UserId] = nil
		if plot then
			publish(plot, nil)
		end
	end)
end

return UpgradeService
