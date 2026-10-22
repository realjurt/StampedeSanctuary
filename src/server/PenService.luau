--!strict
-- Shows each player's pen animals in their plot (P3, D-025). Models are built on the server so
-- everyone in the server sees them; they are rebuilt from saved `pen` records when the owner joins
-- and removed when they leave. Clients animate them (PenView) — the server only places them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalBuilder = require(ReplicatedStorage.Shared.Animals.AnimalBuilder)
local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local AnimalCollection = require(script.Parent.AnimalCollection)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)

type Plot = SanctuaryBuilder.Plot

local PenService = {}

-- Slot grid inside the 28-stud pen: 4 across, 2 deep (capacity 8), in pen-local studs. Sized for
-- the widest (elephant ~6) and longest (~11) placeholder.
local COLUMNS = 4
local SPACING_X = 6.5
local SPACING_Z = 13

local penOf: { [number]: Plot } = {} -- UserId → plot whose pen we filled
local generation: { [Plot]: number } = {} -- bumped on clear so pending reveals stop

local function slotCFrame(plot: Plot, slot: number): CFrame
	local column = (slot - 1) % COLUMNS
	local row = math.floor((slot - 1) / COLUMNS) % 2
	local x = (column - (COLUMNS - 1) / 2) * SPACING_X
	local z = (row - 0.5) * SPACING_Z
	-- Faces the hub, so visitors walking past see each animal head-on.
	return plot.penCFrame * CFrame.new(x, 0, z)
end

local function label(model: Model, species: string, income: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PenLabel"
	billboard.Size = UDim2.fromOffset(150, 34)
	billboard.StudsOffset = Vector3.new(0, (model:GetAttribute("RootHeight") :: number) + 2.5, 0)
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.Adornee = model.PrimaryPart
	billboard.Parent = model
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(250, 250, 252)
	text.TextStrokeTransparency = 0
	text.Text = `{AnimalConfig[species].displayName} · ${income}/s`
	text.Parent = billboard
end

local function spawnAnimal(plot: Plot, record: AnimalCollection.AnimalRecord, slot: number, fresh: boolean)
	local income = AnimalCollection.incomeOf(record.species)
	local model = AnimalBuilder.build(record.species, slotCFrame(plot, slot), true)
	model.Name = `PenAnimal_{record.id}`
	model:SetAttribute("Income", income)
	model:SetAttribute("Fresh", fresh) -- just deposited: clients play the reveal
	label(model, record.species, income)
	model.Parent = plot.penAnimals
end

local function publishIncome(plot: Plot, data: PlayerDataService.PlayerData)
	local income = AnimalCollection.penIncome(data)
	plot.model:SetAttribute("IncomePerSecond", income)
	plot.model:SetAttribute("PenCount", AnimalCollection.countInPen(data))
	plot.income.Text = `${income}/s`
end

local function clear(plot: Plot)
	generation[plot] = (generation[plot] or 0) + 1
	plot.penAnimals:ClearAllChildren()
	plot.model:SetAttribute("IncomePerSecond", 0)
	plot.model:SetAttribute("PenCount", 0)
end

-- Builds the whole pen from saved data (on join).
local function rebuild(player: Player)
	local data = PlayerDataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot or not player.Parent then
		return
	end
	clear(plot)
	penOf[player.UserId] = plot
	for slot, record in AnimalCollection.penRecords(data) do
		spawnAnimal(plot, record, slot, false)
	end
	publishIncome(plot, data)
end

-- Called after a deposit has been applied to the server data. Adds the new animals one at a time
-- (the saved data already holds all of them). Returns the reveal's length in seconds.
function PenService.reveal(player: Player, deposited: { AnimalCollection.AnimalRecord }): number
	local data = PlayerDataService.peek(player)
	local plot = penOf[player.UserId]
	if not data or not plot then
		return 0
	end
	local firstSlot = AnimalCollection.countInPen(data) - #deposited + 1
	local token = generation[plot]
	for i, record in deposited do
		task.delay((i - 1) * EconomyConfig.depositRevealInterval, function()
			if generation[plot] ~= token then
				return -- owner left; the plot was cleared
			end
			spawnAnimal(plot, record, firstSlot + i - 1, true)
			if i == #deposited then
				publishIncome(plot, data)
			end
		end)
	end
	return #deposited * EconomyConfig.depositRevealInterval
end

function PenService.start()
	Players.PlayerAdded:Connect(rebuild)
	for _, player in Players:GetPlayers() do
		task.spawn(rebuild, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local plot = penOf[player.UserId]
		penOf[player.UserId] = nil
		if plot then
			clear(plot)
		end
	end)
end

return PenService
