--!strict
-- Open-world riding (D-027, R0 prototype). Placeholder handling values for playtesting.
-- Speeds in studs/s, turn rates in degrees/s, times in seconds.

export type Handling = {
	topSpeed: number,
	acceleration: number, -- toward top speed while the stick is pushed
	braking: number, -- when pulling back
	coastDeceleration: number, -- when the stick is released
	reverseSpeed: number, -- slow back-up when pulling back from a standstill
	turnRateSlow: number, -- at a standstill
	turnRateFast: number, -- at top speed
	jumpHeight: number,
	gravity: number,
	stepHeight: number, -- tallest ledge it walks up without jumping
}

local FreeRideConfig = {}

FreeRideConfig.handling = {
	Zebra = {
		topSpeed = 46,
		acceleration = 32,
		braking = 70,
		coastDeceleration = 22,
		reverseSpeed = 8,
		turnRateSlow = 240,
		turnRateFast = 120,
		jumpHeight = 7,
		gravity = 110,
		stepHeight = 2.5,
	},
} :: { [string]: Handling }

-- R0 test field, north of the sanctuary (sanctuary origin is -400, 0, 0).
FreeRideConfig.field = {
	center = Vector3.new(-400, 0, -170),
	size = 200,
	-- Practice zebra: right at the field's edge, ~8 s walk from the spawn.
	practiceSpawn = CFrame.new(-400, 0.1, -84),
}

-- Chase camera
FreeRideConfig.camera = {
	distance = 17, -- behind the animal
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
