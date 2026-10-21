--!strict
-- Sunny Savannah test course. The course runs from `origin` toward -Z.
-- Obstacle `distance` is measured in studs from the start line; `lane` is -1 (left), 0, or 1 (right).

export type ObstacleKind = {
	size: Vector3, -- X = width, Y = height, Z = depth
	allLanes: boolean, -- spans the whole track (must jump)
	color: Color3,
}

export type ObstaclePlacement = {
	distance: number,
	lane: number,
	kind: string,
}

local CourseConfig = {
	origin = Vector3.new(0, 0, 0),
	groundY = 0.1,
	length = 950,
	laneCount = 3,
	laneWidth = 10,
	countdownTime = 1.2,
	restartDelay = 2.5,
	jumpForgiveness = 0.4, -- studs of overlap allowed when clearing an obstacle

	obstacleKinds = {
		Rock = { size = Vector3.new(6, 3, 4), allLanes = false, color = Color3.fromRGB(150, 142, 132) },
		Boulder = { size = Vector3.new(7, 9, 6), allLanes = false, color = Color3.fromRGB(128, 120, 112) },
		Log = { size = Vector3.new(30, 2.5, 2.5), allLanes = true, color = Color3.fromRGB(133, 94, 60) },
	} :: { [string]: ObstacleKind },

	obstacles = {
		{ distance = 110, lane = 0, kind = "Rock" },
		{ distance = 180, lane = -1, kind = "Rock" },
		{ distance = 240, lane = 0, kind = "Boulder" },
		{ distance = 300, lane = 0, kind = "Log" },
		{ distance = 370, lane = 1, kind = "Rock" },
		{ distance = 370, lane = 0, kind = "Rock" },
		{ distance = 440, lane = -1, kind = "Boulder" },
		{ distance = 440, lane = 1, kind = "Rock" },
		{ distance = 510, lane = 0, kind = "Log" },
		{ distance = 570, lane = 0, kind = "Boulder" },
		{ distance = 570, lane = 1, kind = "Boulder" },
		{ distance = 640, lane = -1, kind = "Rock" },
		{ distance = 640, lane = 0, kind = "Rock" },
		{ distance = 700, lane = -1, kind = "Boulder" },
		{ distance = 700, lane = 1, kind = "Boulder" },
		{ distance = 760, lane = 0, kind = "Log" },
		{ distance = 820, lane = 0, kind = "Rock" },
		{ distance = 820, lane = -1, kind = "Boulder" },
		{ distance = 880, lane = 1, kind = "Rock" },
		{ distance = 880, lane = -1, kind = "Rock" },
	} :: { ObstaclePlacement },
}

return CourseConfig
