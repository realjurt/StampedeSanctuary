--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local CourseBuilder = require(script.Parent.CourseBuilder)
local OnboardingService = require(script.Parent.OnboardingService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SafariService = require(script.Parent.SafariService)
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)

CourseBuilder.applyLighting()
for courseId in CourseConfig.courses do
	CourseBuilder.build(courseId)
end
local sanctuary = SanctuaryBuilder.build()

PlayerDataService.start()
OnboardingService.start(sanctuary.skipPrompt)
SafariService.start(sanctuary.startPrompt, sanctuary.spawnCFrame)
