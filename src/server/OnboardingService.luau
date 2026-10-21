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

-- First-time leap lesson (D-021): "learned" requires a server-validated switch in the current run;
-- "skipped" just needs an active run on a course with herds. Saved separately from onboarding.
function OnboardingService.completeLeapTutorial(player: Player, reason: any)
	if reason ~= "learned" and reason ~= "skipped" then
		return
	end
	local data = PlayerDataService.get(player)
	if not data or data.leapTutorialDone then
		return
	end
	local courseId, _, switches = SafariService.getRun(player)
	local course = courseId and CourseConfig.courses[courseId]
	if not course or not course.herds or (reason == "learned" and (switches or 0) < 1) then
		warn(`OnboardingService: rejected leap tutorial ({reason}) from {player.Name}`)
		return
	end
	PlayerDataService.update(player, function(d)
		d.leapTutorialDone = true
	end)
end

function OnboardingService.start(skipPrompt: ProximityPrompt)
	Net.on("CompleteLeapTutorial", 1, OnboardingService.completeLeapTutorial)
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
