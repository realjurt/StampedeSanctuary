--!strict
-- Training machines (P4, D-026). Each owner's machine is built on their plot's pad on the server, so
-- everyone sees it; clients animate it (TrainingView) while the plot's "Training" attribute is set.
--   • Only the plot owner can sit: the seat can't be sat on by touch, the server seats the owner
--     from the Train prompt, and anyone else who ends up in it is ejected.
--   • Stamina is added from server time only: every tick, for an owner seated on their own machine.
--   • BOOST (optional): the server opens a short window every few seconds of training; a hit on
--     "TrainingBoost" inside the window (server-checked, once per window) multiplies gains for a while.
-- Remote "TrainingBoost": server → client ("window", seconds) | ("boost", seconds) | ("miss");
-- client → server: () = BOOST pressed. "TrainingTick" (unreliable, cosmetic): (gain, boosted).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalBuilder = require(ReplicatedStorage.Shared.Animals.AnimalBuilder)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local TrainingConfig = require(ReplicatedStorage.Shared.Config.TrainingConfig)
local CourseBuilder = require(script.Parent.CourseBuilder)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)

type Plot = SanctuaryBuilder.Plot

type Session = {
	plot: Plot,
	windowStart: number,
	windowEnd: number,
	windowHit: boolean,
	boostUntil: number,
}

local MachineService = {}

local LEVEL_COLORS = {
	Color3.fromRGB(84, 140, 255),
	Color3.fromRGB(92, 200, 72),
	Color3.fromRGB(168, 110, 255),
	Color3.fromRGB(255, 170, 40),
}

local machines: { [Plot]: Model } = {}
local sessions: { [Player]: Session } = {}
local boostRemote: RemoteEvent
local tickRemote: UnreliableRemoteEvent

local function ownerOf(plot: Plot): Player?
	local userId = plot.model:GetAttribute("OwnerUserId")
	local player = if typeof(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
	return if player and PlotService.getPlot(player) == plot then player else nil
end

local function seatOf(plot: Plot): Seat?
	local machine = machines[plot]
	return if machine then machine:FindFirstChild("Seat") :: Seat? else nil
end

local function eject(seat: Seat)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local occupant = seat.Occupant
	if occupant then
		occupant.Sit = false
	end
end

local function endSession(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	session.plot.model:SetAttribute("Training", false)
	session.plot.model:SetAttribute("Boosted", false)
end

-- Opens a BOOST window every boostInterval seconds while this session lasts.
local function runBoostWindows(player: Player, session: Session)
	while sessions[player] == session do
		task.wait(TrainingConfig.boostInterval)
		if sessions[player] ~= session then
			return
		end
		session.windowStart = os.clock()
		session.windowEnd = session.windowStart + TrainingConfig.boostWindow
		session.windowHit = false
		boostRemote:FireClient(player, "window", TrainingConfig.boostWindow)
	end
end

local function onOccupantChanged(plot: Plot, seat: Seat)
	local occupant = seat.Occupant
	local owner = ownerOf(plot)
	if not occupant then
		if owner then
			endSession(owner)
		end
		return
	end
	local rider = Players:GetPlayerFromCharacter(occupant.Parent)
	if not rider or rider ~= owner or rider:GetAttribute("InSafari") == true then
		warn(`MachineService: ejected {if rider then rider.Name else occupant.Parent} from plot {plot.id}'s machine`)
		eject(seat)
		return
	end
	endSession(rider)
	local session: Session = { plot = plot, windowStart = 0, windowEnd = 0, windowHit = true, boostUntil = 0 }
	sessions[rider] = session
	plot.model:SetAttribute("Training", true)
	task.spawn(runBoostWindows, rider, session)
end

local function onTrainPrompt(plot: Plot, player: Player)
	local seat = seatOf(plot)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not seat or ownerOf(plot) ~= player or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("InSafari") == true or seat.Occupant ~= nil then
		return
	end
	if (root.Position - seat.Position).Magnitude > EconomyConfig.purchaseRange then
		return
	end
	seat:Sit(humanoid)
end

local function onBoostHit(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	if not session.windowHit and now >= session.windowStart and now <= session.windowEnd + TrainingConfig.boostLatency then
		session.windowHit = true
		session.boostUntil = now + TrainingConfig.boostDuration
		session.plot.model:SetAttribute("Boosted", true)
		boostRemote:FireClient(player, "boost", TrainingConfig.boostDuration)
	else
		boostRemote:FireClient(player, "miss")
	end
end

-- Placeholder machine: platform, treadmill belt with rails, a zebra running on it, and the seat on
-- its back. Faces the hub like the plot.
local function build(plot: Plot, level: number): Model
	local model = Instance.new("Model")
	model.Name = "TrainingMachine"
	local base = plot.machineCFrame
	local platform = CourseBuilder.makePart(model, "Platform", Vector3.new(7, 1, 10), base * CFrame.new(0, 0.5, 0), Color3.fromRGB(70, 72, 82))
	local belt = CourseBuilder.makePart(model, "Belt", Vector3.new(4.6, 0.3, 9.6), base * CFrame.new(0, 1.15, 0), Color3.fromRGB(32, 33, 38))
	CourseBuilder.decor(belt)
	local texture = Instance.new("Texture")
	texture.Name = "Stripes"
	texture.Face = Enum.NormalId.Top
	texture.Texture = "rbxassetid://115925519940442"
	texture.StudsPerTileU = 1.5
	texture.StudsPerTileV = 1.5
	texture.Transparency = 0.6
	texture.Parent = belt
	for _, side in { -1, 1 } do
		local rail = CourseBuilder.makePart(model, "Rail", Vector3.new(0.5, 2.6, 9.6), base * CFrame.new(side * 2.8, 2.3, 0), LEVEL_COLORS[level] or LEVEL_COLORS[1])
		CourseBuilder.decor(rail)
		rail.Name = "Rail"
	end
	local console = CourseBuilder.makePart(model, "Console", Vector3.new(6, 3.4, 0.8), base * CFrame.new(0, 2.7, -4.4), LEVEL_COLORS[level] or LEVEL_COLORS[1])
	CourseBuilder.decor(console)

	local animal = AnimalBuilder.build("Zebra", base * CFrame.new(0, 1.3, 0.5), true)
	animal.Name = "Runner"
	animal.Parent = model

	local animalRoot = animal.PrimaryPart :: BasePart
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Disabled = true -- no sitting by touch: only the server seats the owner (Train prompt)
	seat.CFrame = animalRoot.CFrame * CFrame.new(0, (animal:GetAttribute("RiderOffset") :: number) - 2.2, 0)
	seat.Anchored = true
	seat.Parent = model

	local trainPrompt = Instance.new("ProximityPrompt")
	trainPrompt.Name = "TrainPrompt"
	trainPrompt.ActionText = "Train"
	trainPrompt.ObjectText = "Training machine"
	trainPrompt.KeyboardKeyCode = Enum.KeyCode.E
	trainPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	trainPrompt.HoldDuration = 0
	trainPrompt.MaxActivationDistance = 10
	trainPrompt.RequiresLineOfSight = false
	trainPrompt.Parent = platform
	trainPrompt.Triggered:Connect(function(player)
		onTrainPrompt(plot, player)
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelLabel"
	billboard.Size = UDim2.fromOffset(190, 40)
	billboard.StudsOffset = Vector3.new(0, 4.4, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = console
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(250, 250, 252)
	text.TextStrokeTransparency = 0
	text.Parent = billboard

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(plot, seat)
	end)
	model.Parent = plot.machineFolder
	return model
end

local function paint(model: Model, level: number)
	local color = LEVEL_COLORS[level] or LEVEL_COLORS[1]
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Rail" or child.Name == "Console") then
			child.Color = color
		end
	end
	local label = (model:FindFirstChild("Console") :: BasePart):FindFirstChild("LevelLabel") :: BillboardGui
	local stats = TrainingConfig.levels[level];
	(label:FindFirstChild("Text") :: TextLabel).Text = `Lv {level}  ·  +{stats.gain}⚡`
end

-- Shows the plot's machine at `level` (0 = none). Upgrading repaints in place, so a seated owner
-- keeps training.
function MachineService.show(plot: Plot, level: number)
	local machine = machines[plot]
	if level <= 0 then
		if machine then
			local seat = machine:FindFirstChild("Seat") :: Seat?
			if seat then
				eject(seat)
			end
			machine:Destroy()
			machines[plot] = nil
		end
		plot.model:SetAttribute("Training", false)
		plot.model:SetAttribute("Boosted", false)
		return
	end
	if not machine then
		machine = build(plot, level)
		machines[plot] = machine
	end
	paint(machine :: Model, level)
end

-- One training tick for one player (exposed for tests). Returns the stamina gained.
function MachineService.trainTick(player: Player): number
	local session = sessions[player]
	local data = PlayerDataService.peek(player)
	if not session or not data or data.machineLevel <= 0 then
		return 0
	end
	local seat = seatOf(session.plot)
	local character = player.Character
	local occupant = seat and seat.Occupant
	if not occupant or occupant.Parent ~= character or ownerOf(session.plot) ~= player or player:GetAttribute("InSafari") == true then
		endSession(player)
		return 0
	end
	local now = os.clock()
	local boosted = session.boostUntil > now
	session.plot.model:SetAttribute("Boosted", boosted)
	local stats = TrainingConfig.levels[math.min(data.machineLevel, #TrainingConfig.levels)]
	local gain = stats.gain * (if boosted then TrainingConfig.boostMultiplier else 1)
	PlayerDataService.update(player, function(current)
		current.stamina = math.min(math.round((current.stamina + gain) * 100) / 100, EconomyConfig.maxStamina)
	end, true)
	tickRemote:FireClient(player, gain, boosted)
	return gain
end

function MachineService.start()
	boostRemote = Net.on("TrainingBoost", 0.2, onBoostHit) :: RemoteEvent
	tickRemote = Net.event("TrainingTick", true) :: UnreliableRemoteEvent
	Players.PlayerRemoving:Connect(endSession)
	task.spawn(function()
		while true do
			task.wait(TrainingConfig.tickInterval)
			for player in sessions do
				MachineService.trainTick(player)
			end
		end
	end)
end

return MachineService
