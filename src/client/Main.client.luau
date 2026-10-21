--!strict
-- Starts a ride when the server marks this player as on safari (InSafari, set only after they use
-- the Safari Gate) and stops it when the run ends. Also runs the sanctuary-side UI.

local Players = game:GetService("Players")

local HerdController = require(script.Parent.HerdController)
local OnboardingController = require(script.Parent.OnboardingController)
local RideController = require(script.Parent.RideController)
local SanctuaryView = require(script.Parent.SanctuaryView)
local TutorialDirector = require(script.Parent.TutorialDirector)

local player = Players.LocalPlayer
local current: RideController.RideController? = nil
local tutorial: TutorialDirector.TutorialDirector? = nil
local herds: HerdController.HerdController? = nil

local function stopRide()
	if herds then
		herds:destroy()
		herds = nil
	end
	if tutorial then
		tutorial:destroy()
		tutorial = nil
	end
	if current then
		current:destroy()
		current = nil
	end
end

local function syncRide()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local inSafari = player:GetAttribute("InSafari") == true
	local courseId = player:GetAttribute("SafariCourse")
	if not inSafari or not humanoid or humanoid.Health <= 0 or typeof(courseId) ~= "string" then
		stopRide()
		return
	end
	if current then
		return
	end
	local ride = RideController.new(courseId, humanoid)
	current = ride
	if ride.course.tutorial then
		tutorial = TutorialDirector.new(ride)
	end
	local seed = player:GetAttribute("SafariSeed")
	if ride.course.herds and typeof(seed) == "number" then
		local herdController = HerdController.new(ride, seed)
		herds = herdController
		ride.herds = herdController
	end
end

player:GetAttributeChangedSignal("InSafari"):Connect(syncRide)
player.CharacterAdded:Connect(function(character)
	stopRide()
	character:WaitForChild("Humanoid")
	syncRide()
end)
if player.Character then
	task.spawn(syncRide)
end

task.spawn(OnboardingController.start)
task.spawn(SanctuaryView.start)
