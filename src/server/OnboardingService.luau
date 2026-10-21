--!strict
-- First-time player state: skipping the tutorial grants the starter zebra without marking the
-- tutorial completed (TutorialCompleted, StarterZebraUnlocked and OnboardingDismissed are separate).

local PlayerDataService = require(script.Parent.PlayerDataService)
local Net = require(script.Parent.Net)

local OnboardingService = {}

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

function OnboardingService.start(skipPrompt: ProximityPrompt)
	Net.on("SkipTutorial", 1, function(player)
		OnboardingService.skipTutorial(player)
	end)
	skipPrompt.Triggered:Connect(function(player)
		OnboardingService.skipTutorial(player)
	end)
end

return OnboardingService
