--!strict
-- Wild herds for one run: spawns AnimalAgents from the seeded HerdSchedule as the rider approaches,
-- moves them with a simple herd brain, despawns them behind the rider, and picks the best leap
-- target (shown by TargetIndicator; Milestone 5 will make it leapable). Herd animals never crash
-- the rider and only sidestep when actually overlapping, so they stay catchable (D-017).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HerdSchedule = require(ReplicatedStorage.Shared.Herds.HerdSchedule)
local AnimalAgent = require(script.Parent.AnimalAgent)
local CourseObstacles = require(script.Parent.CourseObstacles)
local TargetIndicator = require(script.Parent.TargetIndicator)

export type Wild = {
	agent: AnimalAgent.AnimalAgent,
	id: string,
	homeX: number,
	wanderPhase: number,
	speedJitter: number,
}

local HerdController = {}
HerdController.__index = HerdController

local ACTIVATE_AHEAD = 160
local DESPAWN_BEHIND = 60
local MAX_ACTIVE = 12
local LOOK_AHEAD_BASE = 10
local LOOK_AHEAD_SECONDS = 1.3
local PACE_FAR = 45 -- beyond this gap ahead of the rider, herds amble at their minimum speed
local PACE_NEAR = 15 -- within this gap, herds fully match their share of the rider's speed
local TARGET_MIN_AHEAD = 6
local TARGET_MAX_AHEAD = 30
local TARGET_MAX_SIDE = 14
local RIDER_AVOID_SHIFT = 3
local SEPARATION_LENGTH = 5
local SEPARATION_WIDTH = 3.5
local RESET_THRESHOLD = 20 -- rider distance jumping back this far means "Ride again"

local function moveToward(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

function HerdController.new(ride: any, seed: number)
	local self = setmetatable({}, HerdController)
	self.ride = ride
	self.course = ride.course
	self.schedule = HerdSchedule.generate(ride.course, seed)
	self.obstacles = CourseObstacles.build(ride.course)
	self.nextHerd = 1
	self.wild = {} :: { Wild }
	self.target = nil :: Wild?
	self.indicator = TargetIndicator.new()
	self.lastRiderDistance = ride.distance
	self.connection = RunService.PreSimulation:Connect(function(dt)
		self:step(dt)
	end)
	return self
end

export type HerdController = typeof(HerdController.new(nil :: any, 0))

function HerdController.clear(self: HerdController)
	for _, wild in self.wild do
		wild.agent:destroy()
	end
	table.clear(self.wild)
	self.target = nil
	self.indicator:hide()
end

function HerdController.spawnHerd(self: HerdController, herd: HerdSchedule.Herd)
	for _, member in herd.members do
		local agent = AnimalAgent.new(member.species, self.course, member.distance, member.x, true)
		agent.speed = agent.stats.herdMinSpeed
		table.insert(self.wild, {
			agent = agent,
			id = member.id,
			homeX = member.x,
			wanderPhase = member.wanderPhase,
			speedJitter = member.speedJitter,
		})
	end
end

function HerdController.think(self: HerdController, wild: Wild, dt: number)
	local agent = wild.agent
	local stats = agent.stats
	local ride = self.ride
	local halfWidth = stats.hitboxHalfWidth
	local limit = self.course.trackWidth / 2 - halfWidth - 0.5

	-- Far ahead, herds amble so the rider closes in within a few seconds; once near, they match a
	-- species fraction of the rider's speed so they stay alongside long enough to target.
	local gap = agent.distance - ride.distance
	local pacing = math.max(stats.herdMinSpeed, ride.speed * stats.herdSpeedFactor)
	local closeness = math.clamp((PACE_FAR - gap) / (PACE_FAR - PACE_NEAR), 0, 1)
	local desiredSpeed = (stats.herdMinSpeed + (pacing - stats.herdMinSpeed) * closeness) * (1 + wild.speedJitter)
	agent.speed = moveToward(agent.speed, desiredSpeed, 30 * dt)
	agent.distance += agent.speed * dt

	local target = wild.homeX + math.sin(os.clock() * stats.wanderFrequency * 2 * math.pi + wild.wanderPhase) * stats.wanderAmplitude

	-- Gentle sidestep only while actually overlapping the rider (never when merely ahead).
	local riderHalfLength = ride.stats.hitboxHalfLength
	if math.abs(agent.distance - ride.distance) < stats.hitboxHalfLength + riderHalfLength
		and math.abs(agent.x - ride.x) < halfWidth + ride.stats.hitboxHalfWidth + 1
	then
		local away = if agent.x >= ride.x then 1 else -1
		target = agent.x + away * RIDER_AVOID_SHIFT
	end

	-- Keep a little space from herd-mates.
	for _, other in self.wild do
		if other ~= wild and math.abs(other.agent.distance - agent.distance) < SEPARATION_LENGTH and math.abs(other.agent.x - target) < SEPARATION_WIDTH then
			target += if target >= other.agent.x then 1.5 else -1.5
		end
	end
	target = math.clamp(target, -limit, limit)

	-- Obstacles last, so nothing above can steer an animal into one. Jump logs, sidestep rocks;
	-- look further ahead at speed so there's time to turn.
	local lookAhead = LOOK_AHEAD_BASE + agent.speed * LOOK_AHEAD_SECONDS
	for _, obstacle in self.obstacles do
		local center = (obstacle.dMin + obstacle.dMax) / 2
		local ahead = center - agent.distance
		if ahead > -stats.hitboxHalfLength - 2 and ahead < lookAhead then
			if obstacle.fullWidth then
				if agent.jumpTime == nil and ahead > 0 and ahead <= agent.speed * stats.jumpDuration * 0.5 then
					agent.jumpTime = 0
				end
			elseif target + halfWidth + 1 > obstacle.xMin and target - halfWidth - 1 < obstacle.xMax then
				local left = obstacle.xMin - halfWidth - 1.5
				local right = obstacle.xMax + halfWidth + 1.5
				local preferLeft = math.abs(left - agent.x) < math.abs(right - agent.x)
				if left < -limit then
					preferLeft = false
				elseif right > limit then
					preferLeft = true
				end
				target = math.clamp(if preferLeft then left else right, -limit, limit)
			end
		end
	end

	local desiredVelocity = math.clamp((target - agent.x) * 2.5, -stats.herdSteerSpeed, stats.herdSteerSpeed)
	agent.steerVelocity = moveToward(agent.steerVelocity, desiredVelocity, stats.herdSteerSpeed * 8 * dt)
	agent.x = math.clamp(agent.x + agent.steerVelocity * dt, -limit, limit)
	agent:updateJump(dt)
	agent:pose(0)
end

-- Best rideable animal ahead: within reach, biased toward where the rider is steering.
function HerdController.updateTarget(self: HerdController)
	local ride = self.ride
	local best: Wild? = nil
	if ride.state == "running" then
		local bias = ride.steerVelocity * 0.25
		local bestScore = math.huge
		for _, wild in self.wild do
			local ahead = wild.agent.distance - ride.distance
			local side = wild.agent.x - ride.x
			if ahead >= TARGET_MIN_AHEAD and ahead <= TARGET_MAX_AHEAD and math.abs(side) <= TARGET_MAX_SIDE then
				local score = math.abs(side - bias) + ahead * 0.3
				if score < bestScore then
					best, bestScore = wild, score
				end
			end
		end
	end
	self.target = best
	if best then
		local agent = best.agent
		self.indicator:show(agent.root, agent.stats.displayName, agent.stats.hitboxHalfLength + 1, agent.rootHeight + 1)
	else
		self.indicator:hide()
	end
end

function HerdController.step(self: HerdController, dt: number)
	local ride = self.ride
	if ride.distance < self.lastRiderDistance - RESET_THRESHOLD then
		self:clear()
		self.nextHerd = 1
	end
	self.lastRiderDistance = ride.distance

	while self.nextHerd <= #self.schedule do
		local herd = self.schedule[self.nextHerd]
		if herd.distance - ride.distance > ACTIVATE_AHEAD then
			break
		end
		if #self.wild + #herd.members > MAX_ACTIVE then
			break
		end
		if herd.distance > ride.distance - DESPAWN_BEHIND then
			self:spawnHerd(herd)
		end
		self.nextHerd += 1
	end

	for i = #self.wild, 1, -1 do
		local wild = self.wild[i]
		self:think(wild, dt)
		local agent = wild.agent
		if agent.distance < ride.distance - DESPAWN_BEHIND or agent.distance > self.course.length + 30 then
			agent:destroy()
			table.remove(self.wild, i)
		end
	end

	self:updateTarget()
end

function HerdController.destroy(self: HerdController)
	self.connection:Disconnect()
	self:clear()
	self.indicator:destroy()
end

return HerdController
