--!strict
-- Builds the Sunny Savannah test course from CourseConfig at runtime.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)

local CourseBuilder = {}

local COLORS = {
	laneA = Color3.fromRGB(124, 190, 74),
	laneB = Color3.fromRGB(112, 178, 66),
	savannah = Color3.fromRGB(222, 196, 110),
	hill = Color3.fromRGB(160, 186, 90),
	trunk = Color3.fromRGB(120, 84, 52),
	canopy = Color3.fromRGB(92, 160, 62),
	bush = Color3.fromRGB(80, 150, 60),
	startLine = Color3.fromRGB(255, 255, 255),
	finish = Color3.fromRGB(255, 210, 70),
	post = Color3.fromRGB(150, 105, 65),
	flowers = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(170, 130, 255),
	},
}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

local function decor(part: Part)
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = true
end

-- Converts a distance along the course and a sideways offset into a world position at ground height.
local function courseCFrame(distance: number, xOffset: number, yOffset: number): CFrame
	local origin = CourseConfig.origin
	return CFrame.new(origin.X + xOffset, CourseConfig.groundY + yOffset, origin.Z - distance)
end

local function buildGround(parent: Instance)
	local length = CourseConfig.length
	local trackLength = length + 80
	local centerDistance = length / 2

	local savannah = makePart(parent, "Savannah", Vector3.new(500, 1, length + 500), courseCFrame(centerDistance, 0, -0.55), COLORS.savannah)
	savannah.CanTouch = false

	local width = CourseConfig.trackWidth
	local track = makePart(parent, "Track", Vector3.new(width, 1, trackLength), courseCFrame(centerDistance, 0, -0.5), COLORS.laneA)
	track.CanTouch = false

	-- Speed cues: cross bands on the track and grass tufts hugging both edges rush past the rider.
	local bands = Instance.new("Folder")
	bands.Name = "SpeedCues"
	bands.Parent = parent
	for distance = -40, length + 40, 12 do
		decor(makePart(bands, "Band", Vector3.new(width, 0.05, 5), courseCFrame(distance, 0, 0.01), COLORS.laneB))
	end

	local rng = Random.new(7)
	for distance = -40, length + 40, 5 do
		for _, side in { -1, 1 } do
			local x = side * (width / 2 + rng:NextNumber(0.5, 3.5))
			local height = rng:NextNumber(0.6, 1.4)
			decor(makePart(bands, "Tuft", Vector3.new(1.2, height, 1.2), courseCFrame(distance + rng:NextNumber(-2, 2), x, height / 2), COLORS.bush))
		end
	end
end

local function buildLines(parent: Instance)
	local width = CourseConfig.trackWidth
	decor(makePart(parent, "StartLine", Vector3.new(width, 0.1, 1.5), courseCFrame(0, 0, 0.02), COLORS.startLine))
	decor(makePart(parent, "FinishLine", Vector3.new(width, 0.1, 2), courseCFrame(CourseConfig.length, 0, 0.02), COLORS.finish))

	local postX = width / 2 + 2
	for _, side in { -1, 1 } do
		decor(makePart(parent, "FinishPost", Vector3.new(2, 14, 2), courseCFrame(CourseConfig.length, side * postX, 7), COLORS.post))
	end
	decor(makePart(parent, "FinishBanner", Vector3.new(width + 6, 3, 1.5), courseCFrame(CourseConfig.length, 0, 13), COLORS.finish))
end

local function buildObstacles(parent: Instance)
	for _, placement in CourseConfig.obstacles do
		local kind = CourseConfig.obstacleKinds[placement.kind]
		if not kind then
			warn(`CourseBuilder: unknown obstacle kind "{placement.kind}"`)
			continue
		end
		local x = if kind.fullWidth then 0 else placement.x
		local size = kind.size

		if placement.kind == "Log" then
			local log = makePart(parent, "Log", Vector3.new(CourseConfig.trackWidth, size.Y, size.Y), courseCFrame(placement.distance, x, size.Y / 2), kind.color)
			log.Shape = Enum.PartType.Cylinder
			decor(log)
		else
			local rock = makePart(parent, placement.kind, size, courseCFrame(placement.distance, x, size.Y / 2), kind.color)
			decor(rock)
			-- Smaller cap block gives the voxel rock a chunkier silhouette.
			local cap = makePart(parent, placement.kind .. "Cap", Vector3.new(size.X * 0.6, size.Y * 0.3, size.Z * 0.6), courseCFrame(placement.distance, x, size.Y + size.Y * 0.15 - 0.2), kind.color:Lerp(Color3.new(1, 1, 1), 0.12))
			decor(cap)
		end
	end
end

local function buildAcacia(parent: Instance, distance: number, x: number, scale: number)
	decor(makePart(parent, "Trunk", Vector3.new(1.6, 8, 1.6) * scale, courseCFrame(distance, x, 4 * scale), COLORS.trunk))
	decor(makePart(parent, "Canopy", Vector3.new(13, 2, 13) * scale, courseCFrame(distance, x, 8.5 * scale), COLORS.canopy))
	decor(makePart(parent, "CanopyTop", Vector3.new(8, 1.5, 8) * scale, courseCFrame(distance, x, 10 * scale), COLORS.canopy:Lerp(Color3.new(1, 1, 0.6), 0.1)))
end

local function buildScenery(parent: Instance)
	local rng = Random.new(42)
	local trackHalf = CourseConfig.trackWidth / 2

	for distance = -40, CourseConfig.length + 80, 45 do
		for _, side in { -1, 1 } do
			local x = side * rng:NextNumber(trackHalf + 12, trackHalf + 60)
			buildAcacia(parent, distance + rng:NextNumber(-15, 15), x, rng:NextNumber(0.8, 1.25))

			local bushX = side * rng:NextNumber(trackHalf + 3, trackHalf + 8)
			decor(makePart(parent, "Bush", Vector3.new(3, 2.4, 3), courseCFrame(distance + rng:NextNumber(0, 40), bushX, 1.2), COLORS.bush))

			for _ = 1, 3 do
				local flowerColor = COLORS.flowers[rng:NextInteger(1, #COLORS.flowers)]
				local flowerX = side * rng:NextNumber(trackHalf + 2, trackHalf + 20)
				decor(makePart(parent, "Flower", Vector3.new(0.9, 0.9, 0.9), courseCFrame(distance + rng:NextNumber(0, 45), flowerX, 0.45), flowerColor))
			end
		end
	end

	for i = 0, 6 do
		for _, side in { -1, 1 } do
			local hill = makePart(parent, "Hill", Vector3.one * rng:NextNumber(120, 190), courseCFrame(i * 170 - 50, side * rng:NextNumber(190, 240), -45), COLORS.hill)
			hill.Shape = Enum.PartType.Ball
			decor(hill)
		end
	end
end

local function applyLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 120)

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Haze = 1
		atmosphere.Color = Color3.fromRGB(220, 230, 255)
		atmosphere.Decay = Color3.fromRGB(255, 230, 190)
		atmosphere.Parent = Lighting
	end

	if not Lighting:FindFirstChild("SavannahColor") then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "SavannahColor"
		correction.Saturation = 0.15
		correction.Parent = Lighting
	end
end

function CourseBuilder.build(): Model
	local existing = Workspace:FindFirstChild("SafariCourse")
	if existing then
		existing:Destroy()
	end

	local course = Instance.new("Model")
	course.Name = "SafariCourse"

	buildGround(course)
	buildLines(course)
	buildObstacles(course)
	buildScenery(course)

	course.Parent = Workspace
	applyLighting()
	return course
end

return CourseBuilder
