--!strict
-- Gives each player a zebra at the start line and seats them on it.
-- Movement is client-driven (Decision D-002); the server only spawns and hands over physics ownership.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local ZebraBuilder = require(script.Parent.ZebraBuilder)

local RideService = {}

local SEAT_DELAY = 0.5

local animalsFolder: Folder

local function startCFrame(): CFrame
	local origin = CourseConfig.origin
	return CFrame.new(origin.X, CourseConfig.groundY, origin.Z)
end

local function spawnRide(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not rootPart then
		return
	end

	task.wait(SEAT_DELAY)
	if not character:IsDescendantOf(Workspace) or humanoid.Health <= 0 then
		return
	end

	local zebra = ZebraBuilder.build(startCFrame())
	zebra.Name = player.Name .. "_Zebra"
	zebra.Parent = animalsFolder

	local seat = zebra:FindFirstChild("RiderSeat") :: Seat
	seat:Sit(humanoid)

	local root = zebra.PrimaryPart :: BasePart
	root.Anchored = false
	local ok, err = pcall(function()
		root:SetNetworkOwner(player)
	end)
	if not ok then
		warn(`RideService: could not give {player.Name} ownership of their zebra: {err}`)
	end

	local connection: RBXScriptConnection
	connection = character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			connection:Disconnect()
			zebra:Destroy()
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		spawnRide(player, character)
	end)
	if player.Character then
		task.spawn(spawnRide, player, player.Character)
	end
end

function RideService.start()
	animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "ActiveAnimals"
	animalsFolder.Parent = Workspace

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RideService
