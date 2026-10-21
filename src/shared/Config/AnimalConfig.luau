--!strict
-- Tuning values for rideable animals. Distances in studs, times in seconds.

export type AnimalStats = {
	displayName: string,
	-- Forward speed: starts at startSpeed and eases up to cruiseSpeed over speedRampTime.
	startSpeed: number,
	cruiseSpeed: number,
	speedRampTime: number,
	-- Sideways steering
	maxSteerSpeed: number,
	steerAcceleration: number, -- studs/s² toward the desired sideways speed
	touchFollowGain: number, -- how hard the animal chases the thumb's target position
	-- Jump
	jumpHeight: number,
	jumpDuration: number,
	-- Temper
	temperDuration: number, -- seconds of riding until fully restless
	temperWarningAt: number, -- 0..1 fraction where warnings start
	-- Collision box
	hitboxHalfWidth: number,
	hitboxHalfLength: number,
	-- Gait (tied to distance so feet match the ground)
	strideLength: number, -- studs per full gallop cycle
	gallopAmplitude: number, -- leg swing in radians
	bobHeight: number,
	pitchAmplitude: number, -- body rocking in radians
	turnYaw: number, -- how much the body turns toward its sideways movement
	turnLean: number, -- body lean per stud/s of sideways speed
}

local AnimalConfig: { [string]: AnimalStats } = {
	Zebra = {
		displayName = "Zebra",
		startSpeed = 28,
		cruiseSpeed = 50,
		speedRampTime = 10,
		maxSteerSpeed = 34,
		steerAcceleration = 240,
		touchFollowGain = 9,
		jumpHeight = 7,
		jumpDuration = 0.6,
		temperDuration = 30,
		temperWarningAt = 0.7,
		hitboxHalfWidth = 1.4,
		hitboxHalfLength = 2.6,
		strideLength = 11,
		gallopAmplitude = 0.75,
		bobHeight = 0.45,
		pitchAmplitude = 0.07,
		turnYaw = 0.8,
		turnLean = 0.006,
	},
}

return AnimalConfig
