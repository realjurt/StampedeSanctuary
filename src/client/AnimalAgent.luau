--!strict
-- One animal on a course: model + course-space state (distance, x, speed, sideways velocity, jump)
-- and its procedural pose. Driven either by the player (RideController) or by a herd brain
-- (HerdController); switching control later doesn't change this module (D-016).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimalBuilder = require(ReplicatedStorage.Shared.Animals.AnimalBuilder)
local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)

type Leg = { weld: Weld, baseC0: CFrame, phaseOffset: number, isFront: boolean }

local AnimalAgent = {}
AnimalAgent.__index = AnimalAgent

local LEG_PHASES = {
	-- Bounding gallop: front pair together, back pair half a cycle later, slight left/right offset.
	LegFL = { offset = 0, front = true },
	LegFR = { offset = 0.35, front = true },
	LegBL = { offset = math.pi, front = false },
	LegBR = { offset = math.pi + 0.35, front = false },
}

local localFolder: Folder? = nil
local function getFolder(): Folder
	if not localFolder or not localFolder.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "LocalAnimals"
		folder.Parent = Workspace
		localFolder = folder
	end
	return localFolder :: Folder
end

-- anchored = true for herd animals (moved purely by CFrame); false for a ridden mount, so the
-- welded rider's character keeps simulating and replicating.
function AnimalAgent.new(species: string, course: CourseConfig.Course, distance: number, x: number, anchored: boolean)
	local stats = AnimalConfig[species]
	assert(stats, `AnimalAgent: unknown species "{species}"`)
	local ground = CFrame.new(course.origin.X + x, CourseConfig.groundY, course.origin.Z - distance)
	local model = AnimalBuilder.build(species, ground, true)
	model.Parent = getFolder()

	local self = setmetatable({}, AnimalAgent)
	self.species = species
	self.stats = stats
	self.course = course
	self.model = model
	self.root = model.PrimaryPart :: BasePart
	self.anchored = true
	self.rootHeight = model:GetAttribute("RootHeight") :: number
	self.riderOffset = model:GetAttribute("RiderOffset") :: number
	self.distance = distance
	self.x = x
	self.speed = 0
	self.steerVelocity = 0
	self.jumpTime = nil :: number?
	self.legs = {} :: { Leg }
	for _, child in model:GetChildren() do
		local phase = LEG_PHASES[child.Name]
		local weld = child:FindFirstChild("Hip")
		if phase and weld and weld:IsA("Weld") then
			table.insert(self.legs, { weld = weld, baseC0 = weld.C0, phaseOffset = phase.offset, isFront = phase.front })
		end
	end
	if not anchored then
		AnimalAgent.setRidden(self :: any, true)
	end
	return self
end

export type AnimalAgent = typeof(AnimalAgent.new("Zebra", nil :: any, 0, 0, true))

-- Ridden: unanchored so the welded rider keeps simulating, and the lowest RootPriority so the rider's
-- HumanoidRootPart stays the assembly root — physics replication is sent relative to the root, and
-- this client-only part doesn't exist on the server (BUG-003). Wild: anchored, moved by CFrame.
function AnimalAgent.setRidden(self: AnimalAgent, ridden: boolean)
	self.anchored = not ridden
	self.root.Anchored = not ridden
	self.root.RootPriority = if ridden then -127 else 0
end

function AnimalAgent.jumpHeight(self: AnimalAgent): number
	local jumpTime = self.jumpTime
	if jumpTime == nil then
		return 0
	end
	local t = jumpTime / self.stats.jumpDuration
	return 4 * self.stats.jumpHeight * t * (1 - t)
end

-- Advances an active jump; returns true on the frame it lands.
function AnimalAgent.updateJump(self: AnimalAgent, dt: number): boolean
	local jumpTime = self.jumpTime
	if jumpTime == nil then
		return false
	end
	jumpTime += dt
	if jumpTime >= self.stats.jumpDuration then
		self.jumpTime = nil
		return true
	end
	self.jumpTime = jumpTime
	return false
end

-- Places the model from course-space state. The gait phase comes from distance travelled,
-- so hooves keep pace with the ground instead of sliding.
function AnimalAgent.pose(self: AnimalAgent, extraYaw: number)
	local stats = self.stats
	local speedFraction = math.clamp(self.speed / stats.cruiseSpeed, 0, 1.2)
	local phase = self.distance / stats.strideLength * 2 * math.pi
	local airborne = self.jumpTime ~= nil

	for _, leg in self.legs do
		local angle
		if airborne then
			angle = if leg.isFront then -0.8 else 0.8
		else
			angle = math.sin(phase + leg.phaseOffset) * stats.gallopAmplitude * math.min(speedFraction * 1.5, 1)
		end
		leg.weld.C0 = leg.baseC0 * CFrame.Angles(angle, 0, 0)
	end

	local bob = if airborne then 0 else (math.sin(phase) * 0.5 + 0.5) * stats.bobHeight * math.min(speedFraction, 1)
	local pitch = if airborne then 0.12 else math.sin(phase + math.pi / 2) * stats.pitchAmplitude * math.min(speedFraction, 1)
	local yaw = -math.atan2(self.steerVelocity, math.max(self.speed, 10)) * stats.turnYaw + extraYaw
	local roll = -self.steerVelocity * stats.turnLean

	local origin = self.course.origin
	local position = Vector3.new(origin.X + self.x, CourseConfig.groundY + self.rootHeight + self:jumpHeight() + bob, origin.Z - self.distance)
	self.root.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
	if not self.anchored then
		self.root.AssemblyLinearVelocity = Vector3.new(self.steerVelocity, 0, -self.speed)
		self.root.AssemblyAngularVelocity = Vector3.zero
	end
end

function AnimalAgent.destroy(self: AnimalAgent)
	self.model:Destroy()
end

return AnimalAgent
