--!strict
-- Safari runs: the Safari Gate starts a run (never automatic); leaving, dying, or disconnecting ends it.
-- Movement is client-driven (D-002): the server spawns the animal, seats the rider, hands over physics
-- ownership, and returns the player to the sanctuary afterwards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local ZebraBuilder = require(ReplicatedStorage.Shared.Animals.ZebraBuilder)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

type Run = {
	courseId: string,
	animal: Model,
	startedAt: number,
	connections: { RBXScriptConnection },
}

local SafariService = {}

local TELEPORT_HOLD = 0.3
local TUTORIAL_COURSE = "Tutorial"

local runs: { [Player]: Run } = {}
local animalsFolder: Folder
local sanctuarySpawn: CFrame

-- Read-only view of a player's active run, for reward validation.
function SafariService.getRun(player: Player): (string?, number?)
	local run = runs[player]
	if not run then
		return nil, nil
	end
	return run.courseId, os.clock() - run.startedAt
end

local function cleanup(player: Player): boolean
	local run = runs[player]
	if not run then
		return false
	end
	runs[player] = nil
	for _, connection in run.connections do
		connection:Disconnect()
	end
	run.animal:Destroy()
	if player.Parent then
		player:SetAttribute("InSafari", false)
	end
	return true
end

local function returnToSanctuary(player: Player)
	if not cleanup(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	humanoid.Sit = false
	-- The client owns its character's physics and would overwrite a plain server teleport with its
	-- next position update, so hold ownership on the server until the teleport has replicated.
	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)
	character:PivotTo(sanctuarySpawn)
	task.delay(TELEPORT_HOLD, function()
		if rootPart.Parent and player.Parent then
			pcall(function()
				rootPart:SetNetworkOwner(player)
			end)
		end
	end)
end

function SafariService.startRun(player: Player, courseId: string)
	if runs[player] then
		return
	end
	local course = CourseConfig.courses[courseId]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not course or not character or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	if not PlayerDataService.get(player) then
		return
	end

	local animal = ZebraBuilder.build(CFrame.new(course.origin.X, CourseConfig.groundY, course.origin.Z))
	animal.Name = player.Name .. "_Mount"
	animal:SetAttribute("CourseId", courseId)
	animal:SetAttribute("RiderUserId", player.UserId)
	animal.Parent = animalsFolder

	local run: Run = { courseId = courseId, animal = animal, startedAt = os.clock(), connections = {} }
	runs[player] = run
	player:SetAttribute("InSafari", true)

	local seat = animal:FindFirstChild("RiderSeat") :: Seat
	seat:Sit(humanoid)
	local root = animal.PrimaryPart :: BasePart
	root.Anchored = false
	local ok, err = pcall(function()
		root:SetNetworkOwner(player)
	end)
	if not ok then
		warn(`SafariService: could not give {player.Name} ownership of their mount: {err}`)
	end

	table.insert(run.connections, humanoid.Died:Connect(function()
		cleanup(player)
	end))
	table.insert(run.connections, character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cleanup(player)
		end
	end))
end

function SafariService.start(startPrompt: ProximityPrompt, spawnCFrame: CFrame)
	sanctuarySpawn = spawnCFrame
	animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "ActiveAnimals"
	animalsFolder.Parent = Workspace

	startPrompt.Triggered:Connect(function(player)
		local data = PlayerDataService.get(player)
		if not data then
			return
		end
		local tutorialNext = not data.tutorialCompleted and not data.onboardingDismissed
		SafariService.startRun(player, if tutorialNext then TUTORIAL_COURSE else CourseConfig.defaultCourse)
	end)
	Net.on("ReturnToSanctuary", 0.5, returnToSanctuary)
	Players.PlayerRemoving:Connect(cleanup)
end

return SafariService
