--!strict
-- Placeholder starter sanctuary: spawn, entrance arch, path, empty Zebra habitat, Safari Gate, and
-- the player plots around the hub. Shared by everyone in the server; per-player contents (e.g. the
-- habitat zebra) are shown client-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SanctuaryConfig = require(ReplicatedStorage.Shared.Config.SanctuaryConfig)
local CourseBuilder = require(script.Parent.CourseBuilder)

local makePart = CourseBuilder.makePart
local decor = CourseBuilder.decor

local COLORS = {
	grass = Color3.fromRGB(118, 186, 82),
	path = Color3.fromRGB(226, 204, 150),
	habitat = Color3.fromRGB(150, 205, 95),
	fence = Color3.fromRGB(160, 112, 70),
	sign = Color3.fromRGB(250, 240, 210),
	gate = Color3.fromRGB(255, 150, 60),
	gatePad = Color3.fromRGB(255, 210, 90),
	plot = Color3.fromRGB(104, 168, 74),
	machinePad = Color3.fromRGB(120, 124, 136),
	depositSign = Color3.fromRGB(255, 196, 60),
	upgradeSign = Color3.fromRGB(84, 140, 255),
}

-- A player plot's shared parts. PlotService owns who it belongs to and what the sign says.
export type Plot = {
	id: number,
	model: Model,
	title: TextLabel,
	income: TextLabel,
	penCFrame: CFrame, -- pen floor centre (ground level), facing the hub
	depositPrompt: ProximityPrompt, -- on the DEPOSIT ANIMALS sign
	penAnimals: Folder, -- PenService's server-built animals, seen by everyone
	penUpgradePrompt: ProximityPrompt,
	penUpgradeText: TextLabel,
	machineCFrame: CFrame, -- machine pad top centre, facing the hub
	machinePrompt: ProximityPrompt, -- buy / upgrade, on the machine kiosk
	machineText: TextLabel, -- kiosk sign
	machineFolder: Folder, -- MachineService's server-built machine
}

export type Sanctuary = {
	model: Model,
	spawnCFrame: CFrame,
	startPrompt: ProximityPrompt,
	skipPrompt: ProximityPrompt,
	plots: { Plot },
}

local SanctuaryBuilder = {}

local function at(offset: Vector3, y: number): CFrame
	local origin = SanctuaryConfig.origin
	return CFrame.new(origin.X + offset.X, SanctuaryConfig.groundY + y, origin.Z + offset.Z)
end

-- Signs face +Z (toward the spawn), i.e. their Back face.
local function sign(part: BasePart, name: string, text: string, textColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
end

-- Axis-aligned rectangular fence; `size` is world X × Z.
local function fence(parent: Instance, center: Vector3, size: Vector2)
	local halfX, halfZ = size.X / 2, size.Y / 2
	local sides = {
		{ offset = Vector3.new(0, 0, -halfZ), size = Vector3.new(size.X, 0.6, 0.6) },
		{ offset = Vector3.new(0, 0, halfZ), size = Vector3.new(size.X, 0.6, 0.6) },
		{ offset = Vector3.new(halfX, 0, 0), size = Vector3.new(0.6, 0.6, size.Y) },
		{ offset = Vector3.new(-halfX, 0, 0), size = Vector3.new(0.6, 0.6, size.Y) },
	}
	for _, side in sides do
		for _, height in { 1.2, 2.6 } do
			makePart(parent, "FenceRail", side.size, at(center + side.offset, height), COLORS.fence)
		end
	end
	for i = -2, 2 do
		local stepX, stepZ = i * halfX / 2, i * halfZ / 2
		for _, offset in { Vector3.new(stepX, 0, -halfZ), Vector3.new(stepX, 0, halfZ), Vector3.new(-halfX, 0, stepZ), Vector3.new(halfX, 0, stepZ) } do
			makePart(parent, "FencePost", Vector3.new(0.9, 3.4, 0.9), at(center + offset, 1.7), COLORS.fence)
		end
	end
end

-- Plot-local position (local -Z faces the hub) → world CFrame with the plot's rotation.
local function plotAt(frame: CFrame, localPosition: Vector3, y: number): CFrame
	return at(frame * localPosition, y) * frame.Rotation
end

-- Board whose Front face points at the hub, with a SurfaceGui for text lines.
local function board(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): (BasePart, SurfaceGui)
	local part = makePart(parent, name, size, cframe, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = part
	return part, gui
end

local function line(gui: SurfaceGui, name: string, y: number, height: number, color: Color3, outlined: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromScale(0.04, y)
	label.Size = UDim2.fromScale(0.92, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = if outlined then 0 else 1
	label.Text = ""
	label.Parent = gui
	return label
end

-- Server-side prompt: the owner's client shows it and sets its text; triggers are validated on the server.
local function prompt(parent: Instance, name: string, action: string, key: Enum.KeyCode, hold: number, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = if key == Enum.KeyCode.E then Enum.KeyCode.ButtonX else Enum.KeyCode.ButtonY
	p.HoldDuration = hold
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Placeholder plot: ground, owner sign facing the hub, fenced pen with a deposit prompt and a
-- pad where the training machine will stand (P4).
local function buildPlot(parent: Instance, id: number, offset: Vector3): Plot
	local model = Instance.new("Model")
	model.Name = `Plot{id}`
	model:SetAttribute("PlotId", id)
	model:SetAttribute("OwnerUserId", 0)

	local frame = CFrame.lookAt(offset, Vector3.new(0, 0, offset.Z))
	local width, depth = SanctuaryConfig.plotSize.X, SanctuaryConfig.plotSize.Y
	local ground = makePart(model, "PlotGround", Vector3.new(width, 1, depth), plotAt(frame, Vector3.zero, -0.5), COLORS.plot)
	ground.CanTouch = false

	-- Owner sign at the front edge. Its Front face points at the hub.
	for _, side in { -1, 1 } do
		makePart(model, "SignPost", Vector3.new(0.8, 6, 0.8), plotAt(frame, Vector3.new(side * 6, 0, -depth / 2 + 3), 3), COLORS.fence)
	end
	local _, ownerGui = board(model, "OwnerSign", Vector3.new(14, 4.5, 0.6), plotAt(frame, Vector3.new(0, 0, -depth / 2 + 3), 6.5), COLORS.sign)
	local title = line(ownerGui, "Title", 0.06, 0.56, Color3.fromRGB(90, 60, 30))
	local income = line(ownerGui, "Income", 0.64, 0.3, Color3.fromRGB(40, 140, 50))

	-- Pen (P3, P4): deposited animals stand here, 4 across × 3 deep (room for the last pen level).
	local penSize = SanctuaryConfig.penSize
	local penLocal = Vector3.new(7, 0, 4.5)
	local penGround = makePart(model, "PenGround", Vector3.new(penSize.X, 0.2, penSize.Y), plotAt(frame, penLocal, 0.05), COLORS.habitat)
	decor(penGround)
	-- Plots face ±X, so the pen's width runs along world Z.
	fence(model, frame * penLocal, Vector2.new(penSize.Y, penSize.X))
	local penAnimals = Instance.new("Folder")
	penAnimals.Name = "PenAnimals"
	penAnimals.Parent = model

	-- Tall DEPOSIT ANIMALS sign at the pen front (clear of the owner sign), with the pen upgrade
	-- plaque on the same posts below it.
	local signLocal = Vector3.new(14, 0, penLocal.Z - penSize.Y / 2 - 2)
	for _, side in { -1, 1 } do
		makePart(model, "DepositSignPost", Vector3.new(0.8, 11, 0.8), plotAt(frame, signLocal + Vector3.new(side * 4.6, 0, 0.6), 5.5), COLORS.fence)
	end
	local depositBoard, depositGui = board(model, "DepositSign", Vector3.new(10, 4, 0.6), plotAt(frame, signLocal, 9), COLORS.depositSign)
	decor(depositBoard)
	line(depositGui, "Title", 0.05, 0.58, Color3.fromRGB(90, 50, 10)).Text = "DEPOSIT ANIMALS"
	line(depositGui, "Status", 0.64, 0.3, Color3.fromRGB(255, 255, 255), true)
	local depositPrompt = prompt(depositBoard, "DepositPrompt", "Deposit animals", Enum.KeyCode.E, 0, 14)
	local upgradeBoard, upgradeGui = board(model, "PenUpgradeSign", Vector3.new(7, 2.6, 0.5), plotAt(frame, signLocal, 4.4), COLORS.upgradeSign)
	decor(upgradeBoard)
	line(upgradeGui, "Title", 0.06, 0.44, Color3.fromRGB(255, 255, 255), true).Text = "UPGRADE PEN"
	local penUpgradeText = line(upgradeGui, "Status", 0.54, 0.4, Color3.fromRGB(255, 230, 120), true)
	local penUpgradePrompt = prompt(upgradeBoard, "PenUpgradePrompt", "Upgrade pen", Enum.KeyCode.F, 0.5, 10)

	-- Training machine pad (P4): MachineService builds the machine on it once bought.
	local machineLocal = Vector3.new(-14, 0, 6)
	local pad = makePart(model, "MachinePad", Vector3.new(0.4, 10, 10), plotAt(frame, machineLocal, 0.2) * CFrame.Angles(0, 0, math.rad(90)), COLORS.machinePad)
	pad.Shape = Enum.PartType.Cylinder
	decor(pad)
	local machineFolder = Instance.new("Folder")
	machineFolder.Name = "Machine"
	machineFolder.Parent = model
	-- Kiosk in front of the pad: buy / upgrade prompt and price.
	makePart(model, "MachineKioskPost", Vector3.new(0.8, 4, 0.8), plotAt(frame, machineLocal + Vector3.new(0, 0, -6.9), 2), COLORS.fence)
	local kiosk, kioskGui = board(model, "MachineKiosk", Vector3.new(7, 3.2, 0.5), plotAt(frame, machineLocal + Vector3.new(0, 0, -7.4), 4.6), COLORS.upgradeSign)
	decor(kiosk)
	line(kioskGui, "Title", 0.05, 0.42, Color3.fromRGB(255, 255, 255), true).Text = "TRAINING MACHINE"
	local machineText = line(kioskGui, "Status", 0.52, 0.42, Color3.fromRGB(255, 230, 120), true)
	local machinePrompt = prompt(kiosk, "MachinePrompt", "Buy machine", Enum.KeyCode.F, 0.5, 10)

	model.Parent = parent
	return {
		id = id,
		model = model,
		title = title,
		income = income,
		penCFrame = plotAt(frame, penLocal, 0.15),
		depositPrompt = depositPrompt,
		penAnimals = penAnimals,
		penUpgradePrompt = penUpgradePrompt,
		penUpgradeText = penUpgradeText,
		machineCFrame = plotAt(frame, machineLocal, 0.4),
		machinePrompt = machinePrompt,
		machineText = machineText,
		machineFolder = machineFolder,
	}
end

function SanctuaryBuilder.build(): Sanctuary
	local existing = Workspace:FindFirstChild("Sanctuary")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Sanctuary"

	local ground = makePart(model, "Ground", Vector3.new(SanctuaryConfig.size, 1, SanctuaryConfig.size), at(Vector3.zero, -0.5), COLORS.grass)
	ground.CanTouch = false
	local pathLength = SanctuaryConfig.spawnOffset.Z - SanctuaryConfig.gateOffset.Z + 10
	local pathCenter = Vector3.new(0, 0, (SanctuaryConfig.spawnOffset.Z + SanctuaryConfig.gateOffset.Z) / 2)
	decor(makePart(model, "Path", Vector3.new(SanctuaryConfig.pathWidth, 0.1, pathLength), at(pathCenter, 0.02), COLORS.path))

	-- Spawn
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SanctuarySpawn"
	spawnLocation.Size = Vector3.new(8, 0.2, 8)
	spawnLocation.CFrame = at(SanctuaryConfig.spawnOffset, 0.1)
	spawnLocation.Color = COLORS.path
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = model

	-- Entrance arch
	local entrance = SanctuaryConfig.entranceOffset
	for _, side in { -1, 1 } do
		makePart(model, "EntrancePost", Vector3.new(1.6, 9, 1.6), at(entrance + Vector3.new(side * 8, 0, 0), 4.5), COLORS.fence)
	end
	-- Low enough that the Safari Gate sign stays visible over it from the spawn; sits slightly in
	-- front of the posts so they don't cover the text.
	local banner = makePart(model, "EntranceBanner", Vector3.new(18, 3, 1), at(entrance + Vector3.new(0, 0, 1.2), 7.5), COLORS.sign)
	sign(banner, "Sign", "STAMPEDE SANCTUARY", Color3.fromRGB(90, 60, 30))

	-- Empty Zebra habitat
	local habitatCenter = SanctuaryConfig.habitatOffset
	decor(makePart(model, "HabitatGround", Vector3.new(SanctuaryConfig.habitatSize, 0.2, SanctuaryConfig.habitatSize), at(habitatCenter, 0.05), COLORS.habitat))
	fence(model, habitatCenter, Vector2.new(SanctuaryConfig.habitatSize, SanctuaryConfig.habitatSize))
	local signOffset = habitatCenter + Vector3.new(-SanctuaryConfig.habitatSize / 2 + 4, 0, SanctuaryConfig.habitatSize / 2 + 2)
	makePart(model, "HabitatSignPost", Vector3.new(0.6, 4, 0.6), at(signOffset, 2), COLORS.fence)
	local habitatSign = makePart(model, "HabitatSign", Vector3.new(8, 3, 0.4), at(signOffset, 5), COLORS.sign)
	sign(habitatSign, "Sign", "ZEBRA HABITAT\nEmpty", Color3.fromRGB(90, 60, 30))

	-- Safari Gate
	local gate = SanctuaryConfig.gateOffset
	for _, side in { -1, 1 } do
		makePart(model, "GatePost", Vector3.new(3, 16, 3), at(gate + Vector3.new(side * 9, 0, 0), 8), COLORS.gate)
	end
	local gateBanner = makePart(model, "GateBanner", Vector3.new(24, 4, 2), at(gate, 15), COLORS.gate)
	sign(gateBanner, "Sign", "SAFARI", Color3.new(1, 1, 1))
	local pad = makePart(model, "GatePad", Vector3.new(14, 0.2, 6), at(gate, 0.1), COLORS.gatePad)
	pad.Material = Enum.Material.Neon

	local anchor = makePart(model, "GatePromptAnchor", Vector3.new(1, 1, 1), at(gate, 4), COLORS.gate)
	anchor.Transparency = 1
	decor(anchor)

	local startPrompt = Instance.new("ProximityPrompt")
	startPrompt.Name = "StartPrompt"
	startPrompt.ActionText = "Start Safari"
	startPrompt.ObjectText = "Safari Gate"
	startPrompt.KeyboardKeyCode = Enum.KeyCode.E
	startPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	startPrompt.HoldDuration = 0
	startPrompt.RequiresLineOfSight = false
	startPrompt.MaxActivationDistance = SanctuaryConfig.gateActivationDistance
	startPrompt.Parent = anchor

	local skipPrompt = Instance.new("ProximityPrompt")
	skipPrompt.Name = "SkipPrompt"
	skipPrompt.ActionText = "Skip Tutorial"
	skipPrompt.ObjectText = "Get your starter zebra"
	skipPrompt.KeyboardKeyCode = Enum.KeyCode.F
	skipPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	skipPrompt.HoldDuration = 0.6 -- small hold so it isn't triggered by accident
	skipPrompt.RequiresLineOfSight = false
	skipPrompt.MaxActivationDistance = SanctuaryConfig.gateActivationDistance
	skipPrompt.Parent = anchor

	-- A few placeholder trees for a homely feel.
	for _, offset in { Vector3.new(-40, 0, 35), Vector3.new(-45, 0, -30), Vector3.new(55, 0, 45), Vector3.new(-25, 0, -55), Vector3.new(50, 0, -45) } do
		CourseBuilder.buildAcacia(model, at(offset, 0), 1)
	end

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plots"
	plotFolder.Parent = model
	local plots = {}
	for id, offset in SanctuaryConfig.plotOffsets do
		table.insert(plots, buildPlot(plotFolder, id, offset))
	end

	model.Parent = Workspace

	return {
		model = model,
		spawnCFrame = spawnLocation.CFrame * CFrame.new(0, 3, 0),
		startPrompt = startPrompt,
		skipPrompt = skipPrompt,
		plots = plots,
	}
end

return SanctuaryBuilder
