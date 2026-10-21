--!strict
-- Starts a ride whenever the local character is seated on an animal's RiderSeat.

local Players = game:GetService("Players")

local RideController = require(script.Parent.RideController)

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
	if seat and seat.Name == "RiderSeat" and seat.Parent and seat.Parent:IsA("Model") then
		stopRide()
		current = RideController.new(seat.Parent, humanoid)
	else
		stopRide()
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
	onCharacterAdded(player.Character)
end
