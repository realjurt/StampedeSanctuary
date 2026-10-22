--!strict
-- One free-roaming mount (D-027): an AnimalAgent plus its world-space motion, driven by the
-- species' handling in FreeRideConfig (R1), and the placeholder body feedback — lean into turns,
-- walk → run gait blend with stride timing, nose up/down when speeding up or braking, airborne leg
-- tuck, and a springy squash on landing.
-- Input-agnostic: FreeRide feeds it a move direction and jump presses. A herd brain or a
-- server-owned animal can drive the same object later (multiplayer, R2+).
-- Arcade movement, no physics: a downward ray keeps it on the ground (steps up small ledges, falls
-- off edges), a forward sphere cast stops it at rocks and trees and slides along them. Species with
-- `pushesObstacles` ignore "Pushables" in those casts and report them in `move`'s result instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local FreeRideConfig = require(ReplicatedStorage.Shared.Config.FreeRideConfig)
local AnimalAgent = require(script.Parent.AnimalAgent)

local CAST_RADIUS = 1.2
local DIP_DAMPING = 0.7 -- landing spring damping ratio
local SHOVE_COOLDOWN = 0.4 -- per obstacle
local LEG_KEYS = { "FL", "FR", "BL", "BR" }
local TWO_PI = 2 * math.pi

local FreeRideMotion = {}
FreeRideMotion.__index = FreeRideMotion

-- Shared cast filters (rebuilt by `refreshFilter`): solid = everything except riders and animals;
-- pushThrough also ignores the Pushables folder.
local solidParams = RaycastParams.new()
solidParams.FilterType = Enum.RaycastFilterType.Exclude
solidParams.RespectCanCollide = true
local pushThroughParams = RaycastParams.new()
pushThroughParams.FilterType = Enum.RaycastFilterType.Exclude
pushThroughParams.RespectCanCollide = true
local pushOverlap = OverlapParams.new()
pushOverlap.FilterType = Enum.RaycastFilterType.Include

local function moveToward(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % TWO_PI - math.pi
end

local function forwardOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function smoothing(dt: number, rate: number): number
	return math.min(dt * rate, 1)
end

local function groundAt(point: Vector3, above: number, params: RaycastParams): number?
	local result = Workspace:Raycast(point + Vector3.new(0, above, 0), Vector3.new(0, -(above + 60), 0), params)
	return if result then result.Position.Y else nil
end

FreeRideMotion.forwardOf = forwardOf
FreeRideMotion.wrapAngle = wrapAngle

-- `exclude`: riders' characters, the LocalAnimals folder, etc.
function FreeRideMotion.refreshFilter(exclude: { Instance })
	solidParams.FilterDescendantsInstances = exclude
	local through = table.clone(exclude)
	local openWorld = Workspace:FindFirstChild("OpenWorld")
	local pushables = openWorld and openWorld:FindFirstChild("Pushables")
	if pushables then
		table.insert(through, pushables)
		pushOverlap.FilterDescendantsInstances = { pushables }
	end
	pushThroughParams.FilterDescendantsInstances = through
end

export type StepResult = {
	landed: number?, -- landing speed (studs/s) on the frame it touches down
	pushed: { BasePart }, -- obstacles shoved this frame
}

function FreeRideMotion.new(species: string, home: CFrame)
	local handling = FreeRideConfig.handling[species]
	assert(handling, `FreeRideMotion: no handling for "{species}"`)
	local stats = AnimalConfig[species]
	local self = setmetatable({}, FreeRideMotion)
	self.species = species
	self.handling = handling
	self.home = home
	self.agent = AnimalAgent.newAt(species, home, true)
	self.halfLength = stats.hitboxHalfLength + 0.4
	self.halfWidth = stats.hitboxHalfWidth
	-- Motion (world space). `position` = feet; heading 0 faces -Z.
	self.position = home.Position
	self.heading = 0
	self.speed = 0
	self.verticalSpeed = 0
	self.yawRate = 0
	self.grounded = true
	self.airTime = 0
	self.jumped = false
	self.jumpTimer = 0
	self.slope = 0
	self.stepDistance = 0
	-- Body feedback
	self.phase = 0
	self.gaitBlend = 0
	self.airBlend = 0
	self.lean = 0
	self.accelPitch = 0
	self.lastSpeed = 0
	self.dip = 0
	self.dipVelocity = 0
	self.clock = math.random() * 10
	self.legAngles = { FL = 0, FR = 0, BL = 0, BR = 0 } :: { [string]: number }
	self.shovedAt = setmetatable({}, { __mode = "k" }) :: { [BasePart]: number }
	self.result = { landed = nil, pushed = {} } :: StepResult
	FreeRideMotion.reset(self :: any)
	return self
end

export type Mount = typeof(FreeRideMotion.new("Zebra", CFrame.new()))

-- Back to its home spot, standing still.
function FreeRideMotion.reset(self: Mount)
	local _, yaw = self.home:ToOrientation()
	self.heading = yaw
	self.position = self.home.Position
	self.position = Vector3.new(self.position.X, groundAt(self.position, 5, solidParams) or self.position.Y, self.position.Z)
	self:settle()
end

-- Stops dead on the ground with no body motion (spawn, dismount).
function FreeRideMotion.settle(self: Mount)
	self.speed, self.verticalSpeed, self.yawRate, self.lastSpeed = 0, 0, 0, 0
	self.lean, self.accelPitch, self.dip, self.dipVelocity, self.airBlend = 0, 0, 0, 0, 0
	self.jumpTimer = 0
	if not self.grounded then
		local params = if self.handling.pushesObstacles then pushThroughParams else solidParams
		self.position = Vector3.new(self.position.X, groundAt(self.position, 1, params) or self.position.Y, self.position.Z)
		self.grounded = true
	end
	FreeRideMotion.pose(self, 0)
end

function FreeRideMotion.requestJump(self: Mount)
	self.jumpTimer = FreeRideConfig.jumpBuffer
end

-- ── Steering ──────────────────────────────────────────────────────────────────────────────────

-- `move` = world-space move direction (Humanoid.MoveDirection: camera-relative WASD / stick / touch).
-- Pulling straight back toward the camera brakes, then backs up slowly.
function FreeRideMotion.steer(self: Mount, dt: number, move: Vector3, cameraYaw: number)
	local h = self.handling
	local flat = Vector3.new(move.X, 0, move.Z)
	local amount = math.min(flat.Magnitude, 1)
	local control = if self.grounded then 1 else h.airControl
	local speedFraction = math.clamp(math.abs(self.speed) / h.topSpeed, 0, 1)
	local desiredYawRate = 0
	if amount < 0.1 then
		self.speed = moveToward(self.speed, 0, h.coastDeceleration * control * dt)
	else
		local direction = flat.Unit
		if direction:Dot(forwardOf(cameraYaw)) < -0.9 then
			-- Straight back: brake, then back up. Diagonally back turns the animal round instead.
			if self.speed > 1 then
				self.speed = moveToward(self.speed, 0, h.braking * control * dt)
			else
				self.speed = moveToward(self.speed, -h.reverseSpeed * amount, h.acceleration * control * dt)
			end
		else
			local desired = math.atan2(-direction.X, -direction.Z)
			local difference = wrapAngle(desired - self.heading)
			local maxRate = math.rad(lerp(h.turnRateSlow, h.turnRateFast, speedFraction)) * control
			-- Turn toward the stick, but never faster than the turn can settle without overshooting.
			local rate = math.min(maxRate, math.sqrt(2 * math.rad(h.turnAcceleration) * math.abs(difference)), math.abs(difference) * 10)
			desiredYawRate = math.sign(difference) * rate
			-- Sharp turns and climbs slow it down, so it swings round instead of drifting wide.
			local climb = math.clamp(self.slope / 0.5, 0, 1)
			local target = h.topSpeed * amount * math.max(math.cos(difference), 0.3) * (1 - h.hillSlowdown * climb)
			local rateOfChange = if self.speed < target then h.acceleration else h.braking
			self.speed = moveToward(self.speed, target, rateOfChange * control * dt)
		end
	end
	-- Turning builds up and dies away at the species' turn acceleration (heavy animals keep turning briefly).
	self.yawRate = moveToward(self.yawRate, desiredYawRate, math.rad(h.turnAcceleration) * dt)
	self.heading = wrapAngle(self.heading + self.yawRate * dt)
end

-- ── Movement ──────────────────────────────────────────────────────────────────────────────────

local function shove(self: Mount, forward: Vector3, pushed: { BasePart })
	local center = self.position + forward * (self.halfLength + 1.5) + Vector3.new(0, 2, 0)
	local box = CFrame.new(center) * CFrame.Angles(0, self.heading, 0)
	local now = os.clock()
	for _, part in Workspace:GetPartBoundsInBox(box, Vector3.new(self.halfWidth * 2 + 1, 4, 3), pushOverlap) do
		if now - (self.shovedAt[part] or -math.huge) > SHOVE_COOLDOWN then
			self.shovedAt[part] = now
			table.insert(pushed, part)
			self.speed *= 1 - self.handling.pushSlowdown
		end
	end
end

function FreeRideMotion.move(self: Mount, dt: number): StepResult
	local h = self.handling
	local params = if h.pushesObstacles then pushThroughParams else solidParams
	local result = self.result
	result.landed = nil
	table.clear(result.pushed)

	local position = self.position
	local forward = forwardOf(self.heading)
	local delta = forward * self.speed * dt
	if delta.Magnitude > 1e-4 then
		-- Anything taller than a step (relative to the current jump height) blocks; slide along it.
		local origin = position + Vector3.new(0, h.stepHeight + CAST_RADIUS + 0.1, 0)
		local direction = delta.Unit * (delta.Magnitude + self.halfLength)
		local hit = Workspace:Spherecast(origin, CAST_RADIUS, direction, params)
		-- Walls, and anything whose surface is above step height (e.g. the rounded top of a log).
		if hit and (hit.Normal.Y < 0.6 or hit.Position.Y - position.Y > h.stepHeight) then
			local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			normal = if normal.Magnitude > 0.3 then normal.Unit else -delta.Unit
			local into = delta:Dot(normal)
			if into < 0 then
				local before = delta.Magnitude
				delta -= normal * into
				self.speed *= if before > 1e-4 then delta.Magnitude / before else 0
			end
			-- Never step closer than the body length.
			if hit.Distance < self.halfLength * 0.6 then
				delta += normal * (self.halfLength * 0.6 - hit.Distance)
			end
		end
	end
	if h.pushesObstacles and math.abs(self.speed) > 3 then
		shove(self, if self.speed >= 0 then forward else -forward, result.pushed)
	end
	local groundY = groundAt(position + delta, h.stepHeight + 0.5, params)
	if not groundY and delta.Magnitude > 1e-4 then
		-- The edge of the world: don't go where there is no ground at all.
		delta = Vector3.zero
		self.speed = 0
		groundY = groundAt(position, h.stepHeight + 0.5, params)
	end
	local nextPosition = position + delta

	-- Jump: buffered presses and a short grace period after running off an edge.
	self.jumpTimer -= dt
	if not self.grounded then
		self.airTime += dt
	end
	if self.jumpTimer > 0 and (self.grounded or (not self.jumped and self.airTime < FreeRideConfig.coyoteTime)) then
		self.verticalSpeed = math.sqrt(2 * h.gravity * h.jumpHeight)
		self.grounded = false
		self.jumped = true
		self.airTime = 0
		self.jumpTimer = 0
		self.dipVelocity += 3 -- small stretch on take-off
	end

	if self.grounded then
		if groundY and groundY > nextPosition.Y + h.stepHeight then
			-- A ledge too tall to step onto that the cast missed: stay put.
			nextPosition = position
			self.speed = 0
		elseif groundY and groundY >= nextPosition.Y - 1.5 then
			nextPosition = Vector3.new(nextPosition.X, groundY, nextPosition.Z)
			self.verticalSpeed = 0
		else
			-- Ran off an edge.
			self.grounded = false
			self.jumped = false
			self.airTime = 0
		end
	end
	if not self.grounded then
		local gravity = if self.verticalSpeed > 0 then h.gravity else h.fallGravity
		self.verticalSpeed -= gravity * dt
		nextPosition += Vector3.new(0, self.verticalSpeed * dt, 0)
		-- Land only on ground within a step of the feet (never pop up onto something tall).
		if groundY and nextPosition.Y <= groundY and groundY - nextPosition.Y <= h.stepHeight then
			local impact = math.max(-self.verticalSpeed, 0)
			nextPosition = Vector3.new(nextPosition.X, groundY, nextPosition.Z)
			self.verticalSpeed = 0
			self.grounded = true
			self.jumped = false
			result.landed = impact
			-- Squash, and hard landings cost some speed.
			self.dipVelocity -= impact * h.landingDip * h.landingSpring
			self.speed *= 1 - h.landingSpeedLoss * math.clamp(impact / 40, 0, 1)
		end
	end
	self.stepDistance = (nextPosition - position).Magnitude
	self.position = nextPosition
	return result
end

-- ── Body pose (placeholder animation) ─────────────────────────────────────────────────────────

function FreeRideMotion.pose(self: Mount, dt: number)
	local h = self.handling
	local g = h.gait
	local params = if h.pushesObstacles then pushThroughParams else solidParams
	local position = self.position
	local forward = forwardOf(self.heading)

	local groundY = groundAt(position, 1, params) or position.Y
	local front = groundAt(position + forward * 2, h.stepHeight, params)
	local back = groundAt(position - forward * 2, h.stepHeight, params)
	local targetSlope = if self.grounded and front and back then math.atan((front - back) / 4) else 0
	self.slope += (math.clamp(targetSlope, -0.5, 0.5) - self.slope) * smoothing(dt, 10)

	local speedFraction = math.clamp(math.abs(self.speed) / h.topSpeed, 0, 1)
	local legScale = math.clamp(math.abs(self.speed) / (h.topSpeed * 0.2), 0, 1)
	local airborne = not self.grounded
	self.clock += dt
	self.airBlend += ((if airborne then 1 else 0) - self.airBlend) * smoothing(dt, 10)
	local ground = 1 - self.airBlend

	-- Gait: walk pattern blends into the run pattern with speed; strides lengthen as it speeds up,
	-- and the phase advances with real distance so hooves keep pace with the ground.
	self.gaitBlend += (math.clamp((speedFraction - 0.25) / 0.5, 0, 1) - self.gaitBlend) * smoothing(dt, 4)
	local blend = self.gaitBlend
	if not airborne then
		local stride = lerp(g.walkStride, g.runStride, blend)
		self.phase = (self.phase + self.stepDistance / stride * TWO_PI) % TWO_PI
	end
	local phase = self.phase
	for _, key in LEG_KEYS do
		local walkOffset: number = (g.walk :: any)[key]
		local runOffset: number = (g.run :: any)[key]
		local swing = lerp(math.sin(phase + walkOffset), math.sin(phase + runOffset), blend) * g.swing * legScale
		local tuck = if key == "FL" or key == "FR" then -0.8 else 0.8
		self.legAngles[key] = lerp(swing, tuck, self.airBlend)
	end
	local bob = lerp(g.walkBob * math.abs(math.sin(phase)), g.runBob * (math.sin(phase) * 0.5 + 0.5), blend) * legScale * ground
	local rock = math.sin(phase + math.pi / 2) * g.runPitch * blend * legScale * ground
	local sway = math.sin(phase) * g.sway * legScale * ground
	local breathe = math.sin(self.clock * 2) * 0.05 * (1 - legScale)

	if dt > 0 then
		-- Nose up while speeding up, down while braking.
		local acceleration = (self.speed - self.lastSpeed) / dt
		self.accelPitch += (math.clamp(acceleration * h.accelPitch, -0.12, 0.12) - self.accelPitch) * smoothing(dt, 6)
		-- Landing spring (critically-ish damped), stepped in small slices so big frames stay stable.
		local k = h.landingSpring
		local remaining = math.min(dt, 0.1)
		while remaining > 0 do
			local step = math.min(remaining, 1 / 120)
			self.dipVelocity += (-k * k * self.dip - 2 * DIP_DAMPING * k * self.dipVelocity) * step
			self.dip += self.dipVelocity * step
			remaining -= step
		end
		self.dip = math.clamp(self.dip, -1.5, 1)
		self.lean += (math.clamp(-self.yawRate * speedFraction * h.lean, -h.maxLean, h.maxLean) - self.lean) * smoothing(dt, 8)
	end
	self.lastSpeed = self.speed
	local airPitch = math.clamp(self.verticalSpeed * 0.012, -0.25, 0.25) * self.airBlend
	local pitch = self.slope + rock + self.accelPitch + airPitch + self.dip * 0.1

	local agent = self.agent
	local feet = Vector3.new(position.X, math.min(groundY, position.Y), position.Z)
	local height = position.Y - feet.Y
	local rootPosition = feet + Vector3.new(0, agent.rootHeight + height + bob + self.dip + breathe, 0)
	local rootCFrame = CFrame.new(rootPosition) * CFrame.Angles(0, self.heading, 0) * CFrame.Angles(pitch, 0, self.lean + sway)
	agent:poseFree(rootCFrame, self.legAngles, forward * self.speed + Vector3.new(0, self.verticalSpeed, 0))
end

function FreeRideMotion.destroy(self: Mount)
	self.agent:destroy()
end

return FreeRideMotion
