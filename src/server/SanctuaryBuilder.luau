--!strict
-- Placeholder starter sanctuary: spawn, entrance arch, path, empty Zebra habitat, Safari Gate.
-- Shared by everyone in the server; per-player contents (e.g. the habitat zebra) are shown client-side.

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
}

export type Sanctuary = {
	model: Model,
	spawnCFrame: CFrame,
	startPrompt: ProximityPrompt,
	skipPrompt: ProximityPrompt,
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

	model.Parent = Workspace

	return {
		model = model,
		spawnCFrame = spawnLocation.CFrame * CFrame.new(0, 3, 0),
		startPrompt = startPrompt,
		skipPrompt = skipPrompt,
	}
end

return SanctuaryBuilder
