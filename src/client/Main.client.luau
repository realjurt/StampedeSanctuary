--!strict
-- Starts a ride when the server marks this player as on safari (InSafari, set only after they use
-- the Safari Gate) and stops it when the run ends. Also runs the sanctuary-side UI.

local Players = game:GetService("Players")

local CurrencyHud = require(script.Parent.CurrencyHud)
local FreeRide = require(script.Parent.FreeRide)
local HerdController = require(script.Parent.HerdController)
local LeapTutorial = require(script.Parent.LeapTutorial)
local MenuController = require(script.Parent.MenuController)
local OnboardingController = require(script.Parent.OnboardingController)
local PenView = require(script.Parent.PenView)
local RideController = require(script.Parent.RideController)
local SanctuaryView = require(script.Parent.SanctuaryView)
local TrainingView = require(script.Parent.TrainingView)
local TutorialDirector = require(script.Parent.TutorialDirector)

local player = Players.LocalPlayer
local current: RideController.RideController? = nil
local tutorial: TutorialDirector.TutorialDirector? = nil
local herds: HerdController.HerdController? = nil
local leapTutorial: LeapTutorial.LeapTutorial? = nil
local menuConnections: { RBXScriptConnection } = {}

local function stopRide()
	for _, connection in menuConnections do
		connection:Disconnect()
	end
	table.clear(menuConnections)
	if leapTutorial then
		leapTutorial:destroy()
		leapTutorial = nil
	end
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
	menuConnections = MenuController.bind({
		Index = ride.hud.indexButton,
		Shop = ride.hud.shopButton,
		Settings = ride.hud.settingsButton,
	})
	ride:setPaused(MenuController.isOpen())
	if ride.course.tutorial then
		tutorial = TutorialDirector.new(ride)
	end
	local seed = player:GetAttribute("SafariSeed")
	if ride.course.herds and typeof(seed) == "number" then
		local herdController = HerdController.new(ride, seed)
		herds = herdController
		ride.herds = herdController
		if player:GetAttribute("LeapTutorialDone") ~= true then
			leapTutorial = LeapTutorial.new(ride)
		end
	end
end

MenuController.changed:Connect(function(open: boolean)
	if current then
		current:setPaused(open)
	end
end)

player:GetAttributeChangedSignal("InSafari"):Connect(syncRide)
player.CharacterAdded:Connect(function(character)
	stopRide()
	character:WaitForChild("Humanoid")
	syncRide()
end)
if player.Character then
	task.spawn(syncRide)
end

task.spawn(CurrencyHud.start)
task.spawn(OnboardingController.start)
task.spawn(SanctuaryView.start)
task.spawn(PenView.start)
task.spawn(TrainingView.start)
task.spawn(FreeRide.start)
