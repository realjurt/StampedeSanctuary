--!strict
-- Training machine presentation (P4, D-026). The server owns machines, seating, stamina and
-- purchases; this module only:
--   • animates every plot's machine (gallop + moving belt) while its owner trains, faster when boosted,
--   • shows the buy/upgrade and Train prompts on this player's own plot (hidden on everyone else's),
--   • shows the training panel while seated on their own machine: stamina, grip, progress to the
--     next animal unlock, the optional BOOST button (also Space / gamepad A during a window) and LEAVE,
--   • floats "+0.2⚡" gains, purchase results and "animal unlocked" toasts.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local TamingConfig = require(ReplicatedStorage.Shared.Config.TamingConfig)
local TrainingConfig = require(ReplicatedStorage.Shared.Config.TrainingConfig)
local UiKit = require(script.Parent.UiKit)

local TrainingView = {}

local player = Players.LocalPlayer

local BOOST_ACTION = "TrainingBoost"
local GALLOP_SPEED = 9 -- leg cycles (radians) per second
local BELT_SPEED = 7 -- studs per second

local REJECTION_TEXT: { [string]: string } = {
	notOwner = "That's not your plot!",
	notLoaded = "Still loading your sanctuary…",
	onSafari = "Finish your safari first!",
	tooFar = "Get closer to the sign!",
	maxLevel = "Already at max level!",
}

type Leg = { weld: Weld, base: CFrame, phase: number }
type Machine = { plot: Instance, legs: { Leg }, texture: Texture?, clock: number }
local machines: { [Model]: Machine } = {}

type Panel = {
	frame: Frame,
	header: TextLabel,
	stamina: TextLabel,
	grip: TextLabel,
	unlock: UiKit.Bar,
	boost: TextButton,
}

local myPlot: Instance? = nil
local panel: Panel? = nil
local seated = false
local windowUntil = 0
local pressedThisWindow = true
local boostedUntil = 0
local boostRemote: RemoteEvent
local refreshMyPrompts: (() -> ())? = nil

local function numberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else fallback
end

local function stamina(): number
	return numberAttribute(player, "Stamina", 0)
end

-- Species sorted by stamina requirement, for "next unlock" progress.
local unlockOrder: { { species: string, required: number } } = {}
for species, stats in AnimalConfig do
	table.insert(unlockOrder, { species = species, required = stats.requiredStamina })
end
table.sort(unlockOrder, function(a, b)
	return a.required < b.required
end)

-- ── Machine animation (every plot) ────────────────────────────────────────────────────────────

local function trackMachine(plot: Instance, model: Instance)
	if not model:IsA("Model") then
		return
	end
	local runner = model:WaitForChild("Runner", 5)
	local belt = model:WaitForChild("Belt", 5)
	local machine: Machine = { plot = plot, legs = {}, texture = nil, clock = 0 }
	if runner then
		for _, child in runner:GetChildren() do
			local weld = child:FindFirstChild("Hip")
			if child.Name:sub(1, 3) == "Leg" and weld and weld:IsA("Weld") then
				-- Diagonal pairs move together, like a trot.
				local phase = if child.Name == "LegFL" or child.Name == "LegBR" then 0 else math.pi
				table.insert(machine.legs, { weld = weld, base = weld.C0, phase = phase })
			end
		end
	end
	machine.texture = if belt then belt:FindFirstChildOfClass("Texture") else nil
	machines[model] = machine
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			machines[model] = nil
		end
	end)
end

local function animate(dt: number)
	for _, machine in machines do
		local training = machine.plot:GetAttribute("Training") == true
		if not training then
			continue
		end
		local speed = if machine.plot:GetAttribute("Boosted") == true then 1.8 else 1
		machine.clock += dt * speed
		for _, leg in machine.legs do
			leg.weld.C0 = leg.base * CFrame.Angles(math.sin(machine.clock * GALLOP_SPEED + leg.phase) * 0.6, 0, 0)
		end
		local texture = machine.texture
		if texture then
			texture.OffsetStudsV = (texture.OffsetStudsV + dt * BELT_SPEED * speed) % texture.StudsPerTileV
		end
	end
end

-- ── Training panel ────────────────────────────────────────────────────────────────────────────

local function setBoostLook(state: "idle" | "ready" | "boosted")
	local p = panel
	if not p then
		return
	end
	if state == "ready" then
		UiKit.recolor(p.boost, "yellow")
		UiKit.setButtonEnabled(p.boost, true)
		local keyboard = game:GetService("UserInputService").KeyboardEnabled
		UiKit.setButtonText(p.boost, if keyboard then "BOOST! [Space]" else "BOOST!")
	elseif state == "boosted" then
		UiKit.recolor(p.boost, "green")
		UiKit.setButtonEnabled(p.boost, false)
		UiKit.setButtonText(p.boost, `×{TrainingConfig.boostMultiplier} BOOSTED!`)
	else
		UiKit.recolor(p.boost, "gray")
		UiKit.setButtonEnabled(p.boost, false)
		UiKit.setButtonText(p.boost, "BOOST")
	end
end

local function pressBoost()
	if os.clock() > windowUntil or pressedThisWindow then
		return
	end
	pressedThisWindow = true
	boostRemote:FireServer()
end

local function bindBoostKeys(on: boolean)
	if on then
		-- Above the default jump binding, so Space boosts instead of leaving during a window.
		ContextActionService:BindActionAtPriority(BOOST_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				pressBoost()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction(BOOST_ACTION)
	end
end

local function refreshPanel()
	local p = panel
	if not p or not myPlot then
		return
	end
	local level = math.max(numberAttribute(myPlot, "MachineLevel", 1), 1)
	local stats = TrainingConfig.levels[math.min(level, #TrainingConfig.levels)]
	p.header.Text = `TRAINING  ·  Lv {level}  ·  +{stats.gain}⚡`
	local value = stamina()
	p.stamina.Text = `⚡ {Format.stamina(value)}`
	p.grip.Text = `Grip ×{string.format("%.2f", TamingConfig.gripScale(value))}`

	local previous = 0
	for _, entry in unlockOrder do
		if value < entry.required then
			local name = AnimalConfig[entry.species].displayName
			local fraction = (value - previous) / math.max(entry.required - previous, 0.001)
			p.unlock.set(math.clamp(fraction, 0, 1), `Next: {name} ⚡{entry.required} — {Format.stamina(entry.required - value)} to go`)
			return
		end
		previous = entry.required
	end
	p.unlock.set(1, "All animals unlocked! Training boosts your Grip")
end

local function buildPanel(): Panel
	local gui = UiKit.screen("TrainingPanel", 5)
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(470, 212)
	frame.BackgroundColor3 = UiKit.PANEL
	frame.Visible = false
	frame.Parent = gui
	UiKit.corner(frame, UDim.new(0, 8))
	UiKit.border(frame, 4)
	UiKit.studs(frame, 0.8, 22)
	UiKit.autoScale(frame)

	local headerBar = Instance.new("Frame")
	headerBar.Name = "Header"
	headerBar.Size = UDim2.new(1, 0, 0, 44)
	headerBar.Parent = frame
	UiKit.surface(headerBar, "cyan", 8, 0)
	local header = UiKit.label(headerBar, "Title", "TRAINING", 26)
	header.Size = UDim2.fromScale(1, 1)
	header.TextWrapped = false

	local staminaLabel = UiKit.label(frame, "Stamina", "⚡ 0", 34)
	staminaLabel.Position = UDim2.fromOffset(18, 50)
	staminaLabel.Size = UDim2.fromOffset(220, 44)
	staminaLabel.TextXAlignment = Enum.TextXAlignment.Left
	staminaLabel.TextColor3 = UiKit.PALETTE.cyan.top
	local grip = UiKit.label(frame, "Grip", "Grip ×1.00", 24)
	grip.AnchorPoint = Vector2.new(1, 0)
	grip.Position = UDim2.new(1, -18, 0, 54)
	grip.Size = UDim2.fromOffset(200, 36)
	grip.TextXAlignment = Enum.TextXAlignment.Right

	local unlock = UiKit.bar(frame, "Unlock", UiKit.verticalSequence("purple"), 18)
	unlock.frame.Position = UDim2.fromOffset(16, 98)
	unlock.frame.Size = UDim2.new(1, -32, 0, 32)

	local boost = UiKit.button(frame, "Boost", "BOOST", "gray", 28)
	boost.Position = UDim2.fromOffset(16, 142)
	boost.Size = UDim2.new(1, -170, 0, 56)
	boost.Activated:Connect(pressBoost)
	local leave = UiKit.button(frame, "Leave", "LEAVE", "red", 26)
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -16, 0, 142)
	leave.Size = UDim2.fromOffset(136, 56)
	leave.Activated:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Jump = true
		end
	end)

	return { frame = frame, header = header, stamina = staminaLabel, grip = grip, unlock = unlock, boost = boost }
end

local function mySeat(): Instance?
	local plot = myPlot
	local machine = plot and plot:FindFirstChild("Machine")
	local model = machine and machine:FindFirstChild("TrainingMachine")
	return model and model:FindFirstChild("Seat")
end

local function setSeated(on: boolean)
	if on == seated then
		return
	end
	seated = on
	local p = panel or buildPanel()
	panel = p
	if on then
		refreshPanel()
		setBoostLook("idle")
		UiKit.popIn(p.frame)
	else
		windowUntil = 0
		bindBoostKeys(false)
		UiKit.popOut(p.frame)
	end
	if refreshMyPrompts then
		refreshMyPrompts()
	end
end

local function watchSeat(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function sync()
		local seatPart = humanoid.SeatPart
		setSeated(seatPart ~= nil and seatPart == mySeat())
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(sync)
	sync()
end

-- ── Remotes ───────────────────────────────────────────────────────────────────────────────────

local function onBoostEvent(kind: string, seconds: number?)
	if not seated then
		return
	end
	local duration = if typeof(seconds) == "number" then seconds else 0
	if kind == "window" then
		windowUntil = os.clock() + duration
		pressedThisWindow = false
		setBoostLook("ready")
		bindBoostKeys(true)
		local until_ = windowUntil
		task.delay(duration, function()
			if windowUntil == until_ then
				bindBoostKeys(false)
				if os.clock() > boostedUntil then
					setBoostLook("idle")
				end
			end
		end)
	elseif kind == "boost" then
		boostedUntil = os.clock() + duration
		windowUntil = 0
		bindBoostKeys(false)
		setBoostLook("boosted")
		local until_ = boostedUntil
		task.delay(duration, function()
			if boostedUntil == until_ and os.clock() > windowUntil then
				setBoostLook("idle")
			end
		end)
	elseif kind == "miss" and panel and os.clock() > boostedUntil then
		UiKit.setButtonText(panel.boost, "Too late!")
	end
end

local function onTrainingTick(gain: number, boosted: boolean)
	local seat = mySeat()
	local console = seat and seat.Parent and seat.Parent:FindFirstChild("Console")
	if typeof(gain) ~= "number" or not console or not console:IsA("BasePart") then
		return
	end
	local color = if boosted then UiKit.PALETTE.yellow.top else UiKit.PALETTE.cyan.top
	local text = `+{Format.stamina(gain)}⚡` .. (if boosted then " ×2" else "")
	UiKit.floatText(console, text, color, 3.5 + math.random() * 1.2)
end

local function onPurchase(ok: boolean, kind: string, levelOrReason: any, price: number?)
	if ok then
		if kind == "machine" then
			local stats = TrainingConfig.levels[levelOrReason]
			UiKit.toast(if levelOrReason == 1
				then "🎉 Training Machine bought! Press E on it to train ⚡"
				else `⬆ Machine Lv {levelOrReason}! +{stats and stats.gain or 0}⚡ per tick`, 4)
		else
			UiKit.toast(`⬆ Pen upgraded! {numberAttribute(myPlot or player, "PenCapacity", 0)} slots`, 4)
		end
	elseif levelOrReason == "coins" and typeof(price) == "number" then
		local missing = math.max(price - numberAttribute(player, "Coins", 0), 0)
		UiKit.toast(`Need {Format.money(math.ceil(missing))} more!`, 3)
	elseif REJECTION_TEXT[levelOrReason] then
		UiKit.toast(REJECTION_TEXT[levelOrReason], 3)
	end
end

-- ── Prompts on the player's own plot ──────────────────────────────────────────────────────────

local function bindPrompts(plots: Instance, myPlotId: number?)
	for _, plot in plots:GetChildren() do
		local kioskPrompt = plot:WaitForChild("MachineKiosk"):WaitForChild("MachinePrompt") :: ProximityPrompt
		local machineFolder = plot:WaitForChild("Machine")
		local mine = plot:GetAttribute("PlotId") == myPlotId
		local function trainPrompt(): ProximityPrompt?
			local model = machineFolder:FindFirstChild("TrainingMachine")
			local platform = model and model:FindFirstChild("Platform")
			return platform and platform:FindFirstChild("TrainPrompt") :: ProximityPrompt?
		end
		local function refresh()
			local onSafari = player:GetAttribute("InSafari") == true
			kioskPrompt.Enabled = mine and not onSafari and kioskPrompt.ObjectText ~= ""
			local train = trainPrompt()
			if train then
				train.Enabled = mine and not onSafari and not seated
			end
		end
		kioskPrompt:GetPropertyChangedSignal("ObjectText"):Connect(refresh)
		player:GetAttributeChangedSignal("InSafari"):Connect(refresh)
		machineFolder.ChildAdded:Connect(function(child)
			child:WaitForChild("Platform"):WaitForChild("TrainPrompt")
			refresh()
			trackMachine(plot, child)
		end)
		for _, child in machineFolder:GetChildren() do
			task.spawn(trackMachine, plot, child)
		end
		if mine then
			refreshMyPrompts = refresh
		end
		refresh()
	end
end

function TrainingView.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	boostRemote = remotes:WaitForChild("TrainingBoost") :: RemoteEvent
	boostRemote.OnClientEvent:Connect(onBoostEvent)
	;(remotes:WaitForChild("TrainingTick") :: UnreliableRemoteEvent).OnClientEvent:Connect(onTrainingTick)
	;(remotes:WaitForChild("PurchaseResult") :: RemoteEvent).OnClientEvent:Connect(onPurchase)

	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	local plots = Workspace:WaitForChild("Sanctuary"):WaitForChild("Plots")
	local plotId = player:GetAttribute("PlotId")
	local myPlotId = if typeof(plotId) == "number" then plotId else nil
	myPlot = if myPlotId then plots:WaitForChild(`Plot{myPlotId}`) else nil
	task.spawn(bindPrompts, plots, myPlotId)
	RunService.Heartbeat:Connect(animate)

	-- Stamina display + "unlocked" toasts when training crosses a requirement.
	local last = stamina()
	player:GetAttributeChangedSignal("Stamina"):Connect(function()
		local value = stamina()
		for _, entry in unlockOrder do
			if last < entry.required and value >= entry.required then
				UiKit.toast(`🔓 {AnimalConfig[entry.species].displayName} unlocked! Tame one on safari`, 4)
			end
		end
		last = value
		refreshPanel()
	end)
	if myPlot then
		myPlot:GetAttributeChangedSignal("MachineLevel"):Connect(refreshPanel)
	end

	player.CharacterAdded:Connect(function(character)
		setSeated(false)
		watchSeat(character)
	end)
	if player.Character then
		task.spawn(watchSeat, player.Character)
	end
end

return TrainingView
