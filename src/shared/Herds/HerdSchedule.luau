--!strict
-- Deterministic herd layout for a run: the same course + seed gives the same herds on every client
-- and on the server, so later milestones can validate switches/discoveries against it (D-016).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)

export type HerdMember = {
	id: string,
	species: string,
	distance: number,
	x: number,
	speedJitter: number,
	wanderPhase: number,
}

export type Herd = {
	distance: number,
	species: string,
	members: { HerdMember },
}

local HerdSchedule = {}

local FIRST_HERD = 140
local END_MARGIN = 120
local GAP_MIN, GAP_MAX = 110, 170
-- Members stay within this many studs of the herd centre, so (with wander) a herd never fills the
-- whole track — at least ~15 studs of a 44-stud track stays open.
local HERD_SPREAD = 9
local MEMBER_SPACING = 6
local EDGE_MARGIN = 3
local OBSTACLE_CLEARANCE_BEHIND = 8
local OBSTACLE_CLEARANCE_AHEAD = 22 -- room to steer around an obstacle the animal spawns in front of
local SPECIES_ORDER = { "Zebra", "Giraffe", "Elephant" } -- fixed order keeps picks deterministic

local function pickSpecies(rng: Random): string
	local total = 0
	for _, species in SPECIES_ORDER do
		total += AnimalConfig[species].herdWeight
	end
	local roll = rng:NextNumber(0, total)
	for _, species in SPECIES_ORDER do
		roll -= AnimalConfig[species].herdWeight
		if roll <= 0 then
			return species
		end
	end
	return SPECIES_ORDER[1]
end

local function nearObstacle(course: CourseConfig.Course, distance: number, x: number, halfWidth: number): boolean
	for _, placement in course.obstacles do
		local kind = CourseConfig.obstacleKinds[placement.kind]
		if not kind then
			continue
		end
		local ahead = placement.distance - distance
		local clearance = (if ahead >= 0 then OBSTACLE_CLEARANCE_AHEAD else OBSTACLE_CLEARANCE_BEHIND) + kind.size.Z / 2
		if math.abs(ahead) < clearance then
			if kind.fullWidth or math.abs(x - placement.x) < kind.size.X / 2 + halfWidth + 1 then
				return true
			end
		end
	end
	return false
end

function HerdSchedule.generate(course: CourseConfig.Course, seed: number): { Herd }
	local rng = Random.new(seed)
	local herds: { Herd } = {}
	local halfTrack = course.trackWidth / 2
	local distance = FIRST_HERD

	while distance < course.length - END_MARGIN do
		local species = pickSpecies(rng)
		local stats = AnimalConfig[species]
		local count = rng:NextInteger(stats.herdMin, stats.herdMax)
		local limit = halfTrack - stats.hitboxHalfWidth - EDGE_MARGIN
		local center = rng:NextNumber(-limit + HERD_SPREAD / 2, limit - HERD_SPREAD / 2)

		local members: { HerdMember } = {}
		local attempts = 0
		while #members < count and attempts < 30 do
			attempts += 1
			local memberDistance = distance + rng:NextNumber(-10, 10)
			local memberX = math.clamp(center + rng:NextNumber(-HERD_SPREAD, HERD_SPREAD), -limit, limit)
			local speedJitter = rng:NextNumber(-0.05, 0.05)
			local wanderPhase = rng:NextNumber(0, 2 * math.pi)
			local ok = not nearObstacle(course, memberDistance, memberX, stats.hitboxHalfWidth)
			for _, other in members do
				if Vector2.new(other.distance - memberDistance, other.x - memberX).Magnitude < MEMBER_SPACING then
					ok = false
				end
			end
			if ok then
				table.insert(members, {
					id = `{#herds + 1}-{#members + 1}`,
					species = species,
					distance = memberDistance,
					x = memberX,
					speedJitter = speedJitter,
					wanderPhase = wanderPhase,
				})
			end
		end
		if #members > 0 then
			table.insert(herds, { distance = distance, species = species, members = members })
		end
		distance += rng:NextNumber(GAP_MIN, GAP_MAX)
	end
	return herds
end

return HerdSchedule
