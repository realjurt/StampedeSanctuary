--!strict
-- Open-world riding (D-027). R1: each species handles differently. Placeholder values for playtesting.
-- Speeds in studs/s, turn rates in degrees/s, turn acceleration in degrees/s², times in seconds.

-- Leg phase offsets (radians) for a gait: front-left, front-right, back-left, back-right.
export type LegOffsets = { FL: number, FR: number, BL: number, BR: number }

export type Gait = {
	walk: LegOffsets, -- pattern at low speed
	run: LegOffsets, -- pattern at top speed (blended in by speed)
	walkStride: number, -- studs per stride cycle while walking
	runStride: number, -- studs per stride cycle at top speed
	swing: number, -- leg swing amplitude (radians)
	walkBob: number, -- body bob (studs), twice per walk cycle
	runBob: number, -- body bob (studs), once per run cycle
	runPitch: number, -- rocking-horse pitch at speed (radians)
	sway: number, -- side-to-side roll with the stride (radians)
}

export type Handling = {
	hint: string, -- shown when you get on
	topSpeed: number,
	acceleration: number, -- toward top speed while the stick is pushed
	braking: number, -- when pulling back
	coastDeceleration: number, -- when the stick is released
	reverseSpeed: number, -- slow back-up when pulling back from a standstill
	turnRateSlow: number, -- max turn rate at a standstill
	turnRateFast: number, -- max turn rate at top speed (lower = wider turns)
	turnAcceleration: number, -- how quickly a turn builds up and settles (lower = weightier)
	airControl: number, -- fraction of steering kept in the air
	hillSlowdown: number, -- fraction of top speed lost on the steepest climb
	jumpHeight: number,
	gravity: number, -- while rising
	fallGravity: number, -- while falling (lower = floatier)
	stepHeight: number, -- tallest ledge it walks up without jumping
	pushesObstacles: boolean, -- shoves "Pushable" crates and bushes aside instead of stopping
	pushSlowdown: number, -- fraction of speed lost per obstacle shoved
	-- Body feedback (placeholder animation)
	lean: number, -- roll into turns
	maxLean: number,
	accelPitch: number, -- nose up when speeding up, down when braking (radians per studs/s²)
	landingDip: number, -- body squash per stud/s of landing speed
	landingSpring: number, -- how fast the body springs back (higher = snappier)
	landingSpeedLoss: number, -- fraction of speed lost on a hard landing
	landingShake: number, -- camera shake per stud/s of landing speed
	cameraDistance: number,
	cameraHeight: number, -- extra camera height for tall animals
	gait: Gait,
}

local FreeRideConfig = {}

FreeRideConfig.handling = {
	-- Quick and nimble: fast off the mark, tight turns, snappy hops.
	Zebra = {
		hint = "Zebra — quick, nimble, tight turns",
		topSpeed = 46,
		acceleration = 44,
		braking = 80,
		coastDeceleration = 26,
		reverseSpeed = 9,
		turnRateSlow = 260,
		turnRateFast = 140,
		turnAcceleration = 1400,
		airControl = 0.6,
		hillSlowdown = 0.3,
		jumpHeight = 7,
		gravity = 120,
		fallGravity = 140,
		stepHeight = 2.5,
		pushesObstacles = false,
		pushSlowdown = 0,
		lean = 0.14,
		maxLean = 0.26,
		accelPitch = 0.0025,
		landingDip = 0.025,
		landingSpring = 18,
		landingSpeedLoss = 0.05,
		landingShake = 0.01,
		cameraDistance = 17,
		cameraHeight = 0,
		gait = {
			walk = { FL = 0, FR = math.pi, BL = math.pi * 1.5, BR = math.pi * 0.5 },
			run = { FL = 0, FR = 0.35, BL = math.pi, BR = math.pi + 0.35 },
			walkStride = 6,
			runStride = 11,
			swing = 0.75,
			walkBob = 0.15,
			runBob = 0.5,
			runPitch = 0.07,
			sway = 0.02,
		},
	},
	-- Long legs: builds speed slowly but reaches the highest top speed; wide turns; high, floaty jumps.
	Giraffe = {
		hint = "Giraffe — long strides, wide turns, floaty jumps",
		topSpeed = 52,
		acceleration = 20,
		braking = 50,
		coastDeceleration = 14,
		reverseSpeed = 7,
		turnRateSlow = 150,
		turnRateFast = 62,
		turnAcceleration = 500,
		airControl = 0.35,
		hillSlowdown = 0.25,
		jumpHeight = 10,
		gravity = 60,
		fallGravity = 42,
		stepHeight = 3,
		pushesObstacles = false,
		pushSlowdown = 0,
		lean = 0.1,
		maxLean = 0.2,
		accelPitch = 0.003,
		landingDip = 0.02,
		landingSpring = 9,
		landingSpeedLoss = 0.08,
		landingShake = 0.008,
		cameraDistance = 21,
		cameraHeight = 3,
		gait = {
			-- Giraffes pace: both legs on one side move together, then a long rocking gallop.
			walk = { FL = 0, FR = math.pi, BL = 0.3, BR = math.pi + 0.3 },
			run = { FL = 0, FR = 0.5, BL = math.pi, BR = math.pi + 0.5 },
			walkStride = 10,
			runStride = 17,
			swing = 0.6,
			walkBob = 0.2,
			runBob = 0.55,
			runPitch = 0.1,
			sway = 0.05,
		},
	},
	-- Heavy: slow to get going and slow to stop, weighty steering, low thudding jumps, shoves crates.
	Elephant = {
		hint = "Elephant — heavy and strong: shove crates out of the way",
		topSpeed = 36,
		acceleration = 11,
		braking = 30,
		coastDeceleration = 9,
		reverseSpeed = 6,
		turnRateSlow = 110,
		turnRateFast = 60,
		turnAcceleration = 160,
		airControl = 0.2,
		hillSlowdown = 0.1,
		jumpHeight = 4.5,
		gravity = 120,
		fallGravity = 150,
		stepHeight = 2.5,
		pushesObstacles = true,
		pushSlowdown = 0.12,
		lean = 0.06,
		maxLean = 0.1,
		accelPitch = 0.004,
		landingDip = 0.05,
		landingSpring = 11,
		landingSpeedLoss = 0.2,
		landingShake = 0.03,
		cameraDistance = 20,
		cameraHeight = 1.5,
		gait = {
			-- Four-beat amble at every speed (elephants never gallop); heavy side-to-side roll.
			walk = { FL = 0, FR = math.pi, BL = math.pi * 1.5, BR = math.pi * 0.5 },
			run = { FL = 0, FR = math.pi, BL = math.pi * 1.5, BR = math.pi * 0.5 },
			walkStride = 7,
			runStride = 10,
			swing = 0.42,
			walkBob = 0.25,
			runBob = 0.3,
			runPitch = 0.03,
			sway = 0.07,
		},
	},
} :: { [string]: Handling }

-- Shared input feel
FreeRideConfig.jumpBuffer = 0.15 -- a jump pressed this long before landing still happens
FreeRideConfig.coyoteTime = 0.1 -- a jump this long after running off an edge still happens

-- Test field, north of the sanctuary (sanctuary origin is -400, 0, 0).
FreeRideConfig.field = {
	center = Vector3.new(-400, 0, -170),
	size = 200,
	-- Practice animals in a row at the field's edge, ~8 s walk from the spawn, facing into the field.
	practiceAnimals = {
		{ species = "Giraffe", spawn = CFrame.new(-416, 0.1, -84) },
		{ species = "Zebra", spawn = CFrame.new(-400, 0.1, -84) },
		{ species = "Elephant", spawn = CFrame.new(-384, 0.1, -84) },
	},
}

-- Crates and bushes only the elephant can shove (validated on the server: PushableService).
FreeRideConfig.pushables = {
	pushSpeed = 26, -- studs/s the obstacle is knocked away at
	pushLift = 9, -- upward kick
	maxReach = 14, -- server: max distance from the rider to the obstacle's surface
	resetDistance = 3, -- knocked further than this from home → goes back once untouched for resetDelay
	resetDelay = 10,
}

-- Chase camera
FreeRideConfig.camera = {
	height = 7, -- above the animal's root
	lookAhead = 6, -- aims slightly in front of the animal
	baseFov = 70,
	speedFov = 14, -- extra FOV at top speed
	followDelay = 1, -- seconds after a manual camera drag before it eases back behind the animal
	followRate = 3, -- how fast it eases back (per second, scaled by speed)
	dragSensitivity = 0.4, -- degrees per pixel (mouse / touch)
	stickSensitivity = 160, -- degrees per second at full right stick
	minPitch = -10,
	maxPitch = 50,
}

return FreeRideConfig
