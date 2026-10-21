--!strict
-- Tuning values for rideable animals. Distances in studs, times in seconds.

export type AnimalStats = {
	displayName: string,
	forwardSpeed: number,
	accelerationTime: number,
	laneSmoothing: number, -- time constant for sliding between lanes (lower = snappier)
	jumpHeight: number,
	jumpDuration: number,
	temperDuration: number, -- seconds of riding until fully restless
	temperWarningAt: number, -- 0..1 fraction where warnings start
	hitboxHalfWidth: number,
	hitboxHalfLength: number,
	gallopFrequency: number, -- strides per second at full speed
	gallopAmplitude: number, -- leg swing in radians
	bobHeight: number,
}

local AnimalConfig: { [string]: AnimalStats } = {
	Zebra = {
		displayName = "Zebra",
		forwardSpeed = 45,
		accelerationTime = 0.8,
		laneSmoothing = 0.06,
		jumpHeight = 7,
		jumpDuration = 0.6,
		temperDuration = 30,
		temperWarningAt = 0.7,
		hitboxHalfWidth = 1.4,
		hitboxHalfLength = 2.6,
		gallopFrequency = 2.6,
		gallopAmplitude = 0.6,
		bobHeight = 0.35,
	},
}

return AnimalConfig
