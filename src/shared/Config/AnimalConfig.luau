--!strict
-- Tuning values per species. Distances in studs, times in seconds.

export type AnimalStats = {
	displayName: string,
	abilityHint: string, -- shown the first time the player lands on this species
	smashesRocks: boolean?, -- rides straight through "Rock" obstacles instead of crashing
	-- Riding: forward speed starts at startSpeed and eases up to cruiseSpeed over speedRampTime.
	startSpeed: number,
	cruiseSpeed: number,
	speedRampTime: number,
	maxSteerSpeed: number,
	steerAcceleration: number, -- studs/s² toward the desired sideways speed
	touchFollowGain: number, -- how hard the animal chases the thumb's target position
	jumpHeight: number,
	jumpDuration: number,
	temperDuration: number, -- seconds of riding until fully restless
	temperWarningAt: number, -- 0..1 fraction where warnings start
	hitboxHalfWidth: number,
	hitboxHalfLength: number,
	-- Gait (tied to distance so feet match the ground)
	strideLength: number,
	gallopAmplitude: number,
	bobHeight: number,
	pitchAmplitude: number,
	turnYaw: number,
	turnLean: number,
	-- Herd behaviour (wild animals)
	herdWeight: number, -- relative chance a herd is this species
	herdMin: number,
	herdMax: number,
	herdSpeedFactor: number, -- fraction of the rider's current speed
	herdMinSpeed: number,
	herdSteerSpeed: number,
	wanderAmplitude: number, -- studs of side-to-side drift
	wanderFrequency: number, -- drift cycles per second
}

local AnimalConfig: { [string]: AnimalStats } = {
	Zebra = {
		displayName = "Zebra",
		abilityHint = "Zebra — quick and nimble!",
		startSpeed = 28,
		cruiseSpeed = 50,
		speedRampTime = 10,
		maxSteerSpeed = 34,
		steerAcceleration = 260,
		touchFollowGain = 9,
		jumpHeight = 7,
		jumpDuration = 0.6,
		temperDuration = 20,
		temperWarningAt = 0.7,
		hitboxHalfWidth = 1.4,
		hitboxHalfLength = 2.6,
		strideLength = 11,
		gallopAmplitude = 0.75,
		bobHeight = 0.45,
		pitchAmplitude = 0.07,
		turnYaw = 0.8,
		turnLean = 0.006,
		herdWeight = 5,
		herdMin = 3,
		herdMax = 5,
		herdSpeedFactor = 0.88,
		herdMinSpeed = 16,
		herdSteerSpeed = 14,
		wanderAmplitude = 3,
		wanderFrequency = 0.35,
	},
	Elephant = {
		displayName = "Elephant",
		abilityHint = "Elephant — heavy, but smashes small rocks!",
		smashesRocks = true,
		startSpeed = 24,
		cruiseSpeed = 40,
		speedRampTime = 8,
		maxSteerSpeed = 20,
		steerAcceleration = 110,
		touchFollowGain = 6,
		jumpHeight = 4.5,
		jumpDuration = 0.7,
		temperDuration = 16,
		temperWarningAt = 0.7,
		hitboxHalfWidth = 2.6,
		hitboxHalfLength = 3.5,
		strideLength = 9,
		gallopAmplitude = 0.45,
		bobHeight = 0.35,
		pitchAmplitude = 0.04,
		turnYaw = 0.5,
		turnLean = 0.004,
		herdWeight = 2,
		herdMin = 1,
		herdMax = 2,
		herdSpeedFactor = 0.68,
		herdMinSpeed = 12,
		herdSteerSpeed = 7,
		wanderAmplitude = 1.5,
		wanderFrequency = 0.15,
	},
	Giraffe = {
		displayName = "Giraffe",
		abilityHint = "Giraffe — huge jumps clear even boulders!",
		startSpeed = 26,
		cruiseSpeed = 46,
		speedRampTime = 9,
		maxSteerSpeed = 24,
		steerAcceleration = 140,
		touchFollowGain = 7,
		jumpHeight = 9.8,
		jumpDuration = 0.85,
		temperDuration = 18,
		temperWarningAt = 0.7,
		hitboxHalfWidth = 1.5,
		hitboxHalfLength = 2.5,
		strideLength = 14,
		gallopAmplitude = 0.55,
		bobHeight = 0.3,
		pitchAmplitude = 0.05,
		turnYaw = 0.6,
		turnLean = 0.005,
		herdWeight = 3,
		herdMin = 2,
		herdMax = 3,
		herdSpeedFactor = 0.8,
		herdMinSpeed = 14,
		herdSteerSpeed = 10,
		wanderAmplitude = 2.5,
		wanderFrequency = 0.2,
	},
}

return AnimalConfig
