--!strict
-- First-time player state. TutorialCompleted, StarterZebraUnlocked and OnboardingDismissed are
-- separate (D-012): skipping grants the starter zebra without marking the tutorial completed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SafariService = require(script.Parent.SafariService)

local OnboardingService = {}

local TUTORIAL_COURSE = "Tutorial"
local MIN_TIME_FACTOR = 0.85 -- allow some slack below the fastest possible ride time

-- Fastest plausible tutorial time: whole course at top speed (ignores countdown and acceleration).
local function minimumTutorialTime(): number
	local course = CourseConfig.courses[TUTORIAL_COURSE]
	local zebra = AnimalConfig.Zebra
	local topSpeed = zebra.cruiseSpeed * (course.speedMultiplier or 1)
	return course.length / topSpeed * MIN_TIME_FACTOR
end

function OnboardingService.skipTutorial(player: Player)
	local data = PlayerDataService.get(player)
	if not data or data.tutorialCompleted or data.onboardingDismissed then
		return
	end
	PlayerDataService.update(player, function(d)
		d.onboardingDismissed = true
		d.starterZebraUnlocked = true
		d.discovered.Zebra = true
	end)
end

-- The client only says "I finished"; the server checks it was a real tutorial run of plausible length.
function OnboardingService.completeTutorial(player: Player)
	local data = PlayerDataService.get(player)
	if not data or data.tutorialCompleted then
		return
	end
	local courseId, elapsed = SafariService.getRun(player)
	if courseId ~= TUTORIAL_COURSE or not elapsed or elapsed < minimumTutorialTime() then
		warn(`OnboardingService: rejected tutorial completion from {player.Name} (course={courseId}, elapsed={elapsed})`)
		return
	end
	PlayerDataService.update(player, function(d)
		d.tutorialCompleted = true
		d.starterZebraUnlocked = true
		d.discovered.Zebra = true
	end)
end

function OnboardingService.start(skipPrompt: ProximityPrompt)
	Net.on("SkipTutorial", 1, function(player)
		OnboardingService.skipTutorial(player)
	end)
	Net.on("CompleteTutorial", 2, function(player)
		OnboardingService.completeTutorial(player)
	end)
	skipPrompt.Triggered:Connect(function(player)
		OnboardingService.skipTutorial(player)
	end)
end

return OnboardingService
