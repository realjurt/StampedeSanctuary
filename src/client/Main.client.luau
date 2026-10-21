--!strict
-- Starts a ride whenever the local character is seated on an animal's RiderSeat
-- (only happens after the player uses the Safari Gate), and runs the sanctuary-side UI.

local Players = game:GetService("Players")

local OnboardingController = require(script.Parent.OnboardingController)
local RideController = require(script.Parent.RideController)
local SanctuaryView = require(script.Parent.SanctuaryView)

local player = Players.LocalPlayer
local current: RideController.RideController? = nil

local function stopRide()
	if current then
		current:destroy()
		current = nil
	end
end

local function onSeatChanged(humanoid: Humanoid)
	local seat = humanoid.SeatPart
	stopRide()
	if seat and seat.Name == "RiderSeat" and seat.Parent and seat.Parent:IsA("Model") then
		current = RideController.new(seat.Parent, humanoid)
	end
end

local function onCharacterAdded(character: Model)
	stopRide()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		onSeatChanged(humanoid)
	end)
	if humanoid.SeatPart then
		onSeatChanged(humanoid)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

task.spawn(OnboardingController.start)
task.spawn(SanctuaryView.start)
