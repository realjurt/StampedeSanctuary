--!strict
-- Open-world test field (D-027, R0): a small flat-ish area north of the sanctuary for directional
-- riding — gentle hills and ramps (ground following), small ledges (step up), logs (jump), rocks
-- and trees (blocking), and crates / bushes only the elephant can shove aside (R1, "Pushables").
-- Placeholder parts only; replaced by the R2 savannah.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FreeRideConfig = require(ReplicatedStorage.Shared.Config.FreeRideConfig)
local CourseBuilder = require(script.Parent.CourseBuilder)

local makePart = CourseBuilder.makePart

local COLORS = {
	ground = Color3.fromRGB(176, 196, 92),
	hill = Color3.fromRGB(150, 182, 78),
	rock = Color3.fromRGB(140, 134, 128),
	log = Color3.fromRGB(132, 90, 52),
	ledge = Color3.fromRGB(196, 170, 110),
	sign = Color3.fromRGB(250, 240, 210),
	crate = Color3.fromRGB(196, 140, 80),
	bush = Color3.fromRGB(96, 150, 64),
}

local OpenWorldBuilder = {}

local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Mound with ramps on both sides along Z: rises `height` over `rampLength`, flat top `topLength`.
local function hill(parent: Instance, center: Vector3, width: number, height: number, rampLength: number, topLength: number)
	makePart(parent, "HillTop", Vector3.new(width, height, topLength), CFrame.new(center + Vector3.new(0, height / 2, 0)), COLORS.hill)
	local offset = topLength / 2 + rampLength / 2
	-- A WedgePart is tallest at its +Z end, so the +Z ramp is turned round to rise toward the top.
	wedge(parent, "HillRamp", Vector3.new(width, height, rampLength), CFrame.new(center + Vector3.new(0, height / 2, offset)) * CFrame.Angles(0, math.pi, 0), COLORS.hill)
	wedge(parent, "HillRamp", Vector3.new(width, height, rampLength), CFrame.new(center + Vector3.new(0, height / 2, -offset)), COLORS.hill)
end

function OpenWorldBuilder.build(): Folder
	local existing = Workspace:FindFirstChild("OpenWorld")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "OpenWorld"

	local field = FreeRideConfig.field
	local c = field.center
	local ground = makePart(folder, "FieldGround", Vector3.new(field.size, 1, field.size), CFrame.new(c + Vector3.new(0, -0.4, 0)), COLORS.ground)
	ground.CanTouch = false

	local function at(x: number, z: number): Vector3
		return Vector3.new(c.X + x, 0.1, c.Z + z)
	end

	-- Gentle hill (ground following) and a steeper ramp onto a plateau with a drop-off (airtime).
	hill(folder, at(-45, -20), 26, 6, 30, 16)
	hill(folder, at(50, -55), 18, 4, 14, 10)
	makePart(folder, "Plateau", Vector3.new(20, 5, 20), CFrame.new(at(55, 30) + Vector3.new(0, 2.5, 0)), COLORS.hill)
	wedge(folder, "PlateauRamp", Vector3.new(14, 5, 16), CFrame.new(at(55, 48) + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.pi, 0), COLORS.hill)

	-- Low ledges: 1.5 and 2 studs (walk up), 4 studs (needs a jump).
	makePart(folder, "Ledge", Vector3.new(16, 1.5, 8), CFrame.new(at(-10, 40) + Vector3.new(0, 0.75, 0)), COLORS.ledge)
	makePart(folder, "Ledge", Vector3.new(16, 2, 8), CFrame.new(at(-10, 32) + Vector3.new(0, 1, 0)), COLORS.ledge)
	makePart(folder, "Ledge", Vector3.new(16, 4, 8), CFrame.new(at(-10, 24) + Vector3.new(0, 2, 0)), COLORS.ledge)

	-- Logs to jump (3 studs tall: taller than a step).
	for _, spot in { { 0, -10, 0 }, { 20, -70, 1 }, { -60, 45, 0.5 } } do
		local log = makePart(folder, "Log", Vector3.new(3, 12, 3), CFrame.new(at(spot[1], spot[2]) + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, spot[3], math.rad(90)), COLORS.log)
		log.Shape = Enum.PartType.Cylinder
	end

	-- Rocks (block; slide along them).
	local rng = Random.new(27)
	for _, spot in { { 25, 15 }, { -30, 70 }, { 70, -10 }, { -75, -60 }, { 5, -60 }, { -20, -80 } } do
		local size = Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(4, 6), rng:NextNumber(4, 7))
		makePart(folder, "Rock", size, CFrame.new(at(spot[1], spot[2]) + Vector3.new(0, size.Y / 2 - 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), COLORS.rock)
	end

	-- Trees: canopies are decoration; trunks block.
	for _, spot in { { -70, 10 }, { 35, -30 }, { -40, -70 }, { 80, 70 }, { -85, 80 } } do
		local tree = Instance.new("Model")
		tree.Name = "Acacia"
		CourseBuilder.buildAcacia(tree, CFrame.new(at(spot[1], spot[2])), 1)
		local trunk = tree:FindFirstChild("Trunk") :: BasePart?
		if trunk then
			trunk.CanCollide = true
		end
		tree.Parent = folder
	end

	-- Pushables: unanchored, server-owned (PushableService moves them). A row across the path
	-- straight ahead of the practice animals, and a cluster to plough through.
	local pushables = Instance.new("Folder")
	pushables.Name = "Pushables"
	pushables.Parent = folder
	-- Blocks, not balls: they tumble and stop instead of rolling away.
	local function pushable(name: string, size: Vector3, position: Vector3, color: Color3)
		local part = makePart(pushables, name, size, CFrame.new(position + Vector3.new(0, size.Y / 2, 0)), color)
		part.Anchored = false
		part.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.6, 0.1)
		part:SetAttribute("Home", part.CFrame)
		return part
	end
	for i = -2, 2 do
		local spot = at(20 + i * 4, 60)
		if i % 2 == 0 then
			pushable("Crate", Vector3.new(3.5, 3.5, 3.5), spot, COLORS.crate)
		else
			pushable("Bush", Vector3.new(4, 3, 4), spot, COLORS.bush)
		end
	end
	for _, spot in { { -40, 20 }, { -36, 24 }, { -44, 25 }, { -40, 29 }, { -35, 30 }, { -45, 32 } } do
		pushable("Crate", Vector3.new(3, 3, 3), at(spot[1], spot[2]), COLORS.crate)
	end

	-- Sign at the entrance, facing the sanctuary.
	local sign = makePart(folder, "FieldSign", Vector3.new(14, 3, 0.5), CFrame.new(at(-16, 92) + Vector3.new(0, 4, 0)), COLORS.sign)
	CourseBuilder.decor(sign)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(90, 60, 30)
	text.Text = "RIDING TEST FIELD"
	text.Parent = gui
	for _, side in { -1, 1 } do
		makePart(folder, "FieldSignPost", Vector3.new(0.6, 4, 0.6), CFrame.new(at(-16 + side * 6, 92.4) + Vector3.new(0, 2, 0)), COLORS.log)
	end

	folder.Parent = Workspace
	return folder
end

return OpenWorldBuilder
