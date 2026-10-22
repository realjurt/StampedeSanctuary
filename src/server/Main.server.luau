--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local CourseBuilder = require(script.Parent.CourseBuilder)
local DevCommands = require(script.Parent.DevCommands)
local OnboardingService = require(script.Parent.OnboardingService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local SafariService = require(script.Parent.SafariService)
local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)
local TameService = require(script.Parent.TameService)

CourseBuilder.applyLighting()
for courseId in CourseConfig.courses do
	CourseBuilder.build(courseId)
end
local sanctuary = SanctuaryBuilder.build()

PlayerDataService.start()
PlotService.start(sanctuary.plots)
DevCommands.start()
OnboardingService.start(sanctuary.skipPrompt)
SafariService.start(sanctuary.startPrompt, sanctuary.spawnCFrame)
TameService.start()
