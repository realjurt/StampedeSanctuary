--!strict
local CourseBuilder = require(script.Parent.CourseBuilder)
local RideService = require(script.Parent.RideService)

CourseBuilder.build()
RideService.start()
