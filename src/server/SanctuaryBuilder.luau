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
}

-- A player plot's shared parts. PlotService owns who it belongs to and what the sign says.
export type Plot = {
	id: number,
	model: Model,
	title: TextLabel,
	income: TextLabel,
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

local function fence(parent: Instance, center: Vector3, size: number)
	local half = size / 2
	local sides = {
		{ offset = Vector3.new(0, 0, -half), size = Vector3.new(size, 0.6, 0.6) },
		{ offset = Vector3.new(0, 0, half), size = Vector3.new(size, 0.6, 0.6) },
		{ offset = Vector3.new(half, 0, 0), size = Vector3.new(0.6, 0.6, size) },
		{ offset = Vector3.new(-half, 0, 0), size = Vector3.new(0.6, 0.6, size) },
	}
	for _, side in sides do
		for _, height in { 1.2, 2.6 } do
			makePart(parent, "FenceRail", side.size, at(center + side.offset, height), COLORS.fence)
		end
	end
	for i = -2, 2 do
		local step = i * half / 2
		for _, offset in { Vector3.new(step, 0, -half), Vector3.new(step, 0, half), Vector3.new(-half, 0, step), Vector3.new(half, 0, step) } do
			makePart(parent, "FencePost", Vector3.new(0.9, 3.4, 0.9), at(center + offset, 1.7), COLORS.fence)
		end
	end
end

-- Plot-local position (local -Z faces the hub) → world CFrame with the plot's rotation.
local function plotAt(frame: CFrame, localPosition: Vector3, y: number): CFrame
	return at(frame * localPosition, y) * frame.Rotation
end

-- Placeholder plot: ground, owner sign facing the hub, empty fenced pen (animals arrive in P3) and a
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
	local board = makePart(model, "OwnerSign", Vector3.new(14, 4.5, 0.6), plotAt(frame, Vector3.new(0, 0, -depth / 2 + 3), 6.5), COLORS.sign)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local function line(name: string, y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Parent = gui
		return label
	end
	local title = line("Title", 0.06, 0.56, Color3.fromRGB(90, 60, 30))
	local income = line("Income", 0.64, 0.3, Color3.fromRGB(40, 140, 50))

	-- Empty pen
	local penCenter = frame * Vector3.new(7, 0, 6)
	decor(makePart(model, "PenGround", Vector3.new(SanctuaryConfig.penSize, 0.2, SanctuaryConfig.penSize), at(penCenter, 0.05), COLORS.habitat))
	fence(model, penCenter, SanctuaryConfig.penSize)

	-- Training machine pad
	local pad = makePart(model, "MachinePad", Vector3.new(0.4, 10, 10), plotAt(frame, Vector3.new(-14, 0, 6), 0.2) * CFrame.Angles(0, 0, math.rad(90)), COLORS.machinePad)
	pad.Shape = Enum.PartType.Cylinder
	decor(pad)
	local padLabel = Instance.new("BillboardGui")
	padLabel.Name = "Label"
	padLabel.Size = UDim2.fromOffset(200, 50)
	padLabel.StudsOffset = Vector3.new(0, 3, 0)
	padLabel.MaxDistance = 60
	padLabel.Parent = pad
	local padText = Instance.new("TextLabel")
	padText.BackgroundTransparency = 1
	padText.Size = UDim2.fromScale(1, 1)
	padText.Font = Enum.Font.FredokaOne
	padText.TextScaled = true
	padText.TextColor3 = Color3.new(1, 1, 1)
	padText.TextStrokeTransparency = 0
	padText.Text = "Training Machine\ncoming soon"
	padText.Parent = padLabel

	model.Parent = parent
	return { id = id, model = model, title = title, income = income }
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
	fence(model, habitatCenter, SanctuaryConfig.habitatSize)
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
