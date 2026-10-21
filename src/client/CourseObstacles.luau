--!strict
-- Obstacle boxes for a course in course-space (distance along the track, sideways x), shared by the
-- rider's crash checks and herd animals' avoidance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)

export type Obstacle = {
	kind: string,
	distance: number,
	x: number,
	dMin: number,
	dMax: number,
	xMin: number,
	xMax: number,
	height: number,
	fullWidth: boolean,
	smashed: boolean, -- broken by an elephant this run; no longer blocks
}

local CourseObstacles = {}

function CourseObstacles.build(course: CourseConfig.Course): { Obstacle }
	local list: { Obstacle } = {}
	for _, placement in course.obstacles do
		local kind = CourseConfig.obstacleKinds[placement.kind]
		if kind then
			local width = if kind.fullWidth then course.trackWidth else kind.size.X
			local x = if kind.fullWidth then 0 else placement.x
			table.insert(list, {
				kind = placement.kind,
				distance = placement.distance,
				x = x,
				dMin = placement.distance - kind.size.Z / 2,
				dMax = placement.distance + kind.size.Z / 2,
				xMin = x - width / 2,
				xMax = x + width / 2,
				height = kind.size.Y,
				fullWidth = kind.fullWidth,
				smashed = false,
			})
		end
	end
	return list
end

-- First obstacle a box at (distance, x) with the given half extents and feet height runs into.
function CourseObstacles.hit(list: { Obstacle }, distance: number, x: number, halfLength: number, halfWidth: number, feet: number): Obstacle?
	local dMin, dMax = distance - halfLength, distance + halfLength
	local xMin, xMax = x - halfWidth, x + halfWidth
	for _, obstacle in list do
		if not obstacle.smashed and dMax > obstacle.dMin and dMin < obstacle.dMax and xMax > obstacle.xMin and xMin < obstacle.xMax then
			if feet < obstacle.height - CourseConfig.jumpForgiveness then
				return obstacle
			end
		end
	end
	return nil
end

function CourseObstacles.reset(list: { Obstacle })
	for _, obstacle in list do
		obstacle.smashed = false
	end
end

return CourseObstacles
