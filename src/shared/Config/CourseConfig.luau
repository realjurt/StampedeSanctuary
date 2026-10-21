--!strict
-- Safari courses. Each course runs from its `origin` toward -Z.
-- Obstacle `distance` is studs from the start line; `x` is studs from the track center (+ = right).

export type ObstacleKind = {
	size: Vector3, -- X = width, Y = height, Z = depth
	fullWidth: boolean, -- spans the whole track (must jump)
	color: Color3,
}

export type ObstaclePlacement = {
	distance: number,
	x: number,
	kind: string,
}

export type Course = {
	origin: Vector3,
	length: number,
	trackWidth: number,
	obstacles: { ObstaclePlacement },
}

local CourseConfig = {
	groundY = 0.1,
	countdownTime = 1.2,
	jumpForgiveness = 0.4, -- studs of overlap allowed when clearing an obstacle
	defaultCourse = "Savannah",

	obstacleKinds = {
		Rock = { size = Vector3.new(6, 3, 4), fullWidth = false, color = Color3.fromRGB(150, 142, 132) },
		Boulder = { size = Vector3.new(7, 9, 6), fullWidth = false, color = Color3.fromRGB(128, 120, 112) },
		Log = { size = Vector3.new(1, 2.5, 2.5), fullWidth = true, color = Color3.fromRGB(133, 94, 60) },
	} :: { [string]: ObstacleKind },

	courses = {
		Savannah = {
			origin = Vector3.new(0, 0, 0),
			length = 950,
			trackWidth = 44,
			obstacles = {
				-- Warm-up: single rocks
				{ distance = 120, x = 0, kind = "Rock" },
				{ distance = 170, x = -12, kind = "Rock" },
				{ distance = 170, x = 12, kind = "Rock" },
				-- Thread the middle gap or go wide
				{ distance = 230, x = -6, kind = "Boulder" },
				{ distance = 230, x = 8, kind = "Boulder" },
				{ distance = 290, x = 0, kind = "Log" },
				-- Wall with two gaps
				{ distance = 340, x = -16, kind = "Boulder" },
				{ distance = 340, x = -2, kind = "Rock" },
				{ distance = 340, x = 14, kind = "Boulder" },
				-- Staggered
				{ distance = 400, x = 0, kind = "Boulder" },
				{ distance = 415, x = -14, kind = "Rock" },
				{ distance = 430, x = 14, kind = "Rock" },
				{ distance = 480, x = 0, kind = "Log" },
				-- Slalom
				{ distance = 530, x = -10, kind = "Boulder" },
				{ distance = 555, x = 8, kind = "Boulder" },
				{ distance = 580, x = -6, kind = "Boulder" },
				{ distance = 630, x = -16, kind = "Rock" },
				{ distance = 630, x = 0, kind = "Rock" },
				{ distance = 630, x = 16, kind = "Rock" },
				{ distance = 680, x = 0, kind = "Log" },
				-- Boulder line: jump the rock or squeeze the edge
				{ distance = 730, x = -12, kind = "Boulder" },
				{ distance = 730, x = 0, kind = "Boulder" },
				{ distance = 730, x = 12, kind = "Rock" },
				-- Fast slalom
				{ distance = 790, x = 8, kind = "Boulder" },
				{ distance = 810, x = -8, kind = "Boulder" },
				{ distance = 830, x = 8, kind = "Boulder" },
				{ distance = 870, x = 0, kind = "Log" },
				{ distance = 910, x = -6, kind = "Rock" },
				{ distance = 910, x = 6, kind = "Rock" },
			},
		},
	} :: { [string]: Course },
}

return CourseConfig
