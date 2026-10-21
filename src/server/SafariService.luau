--!strict
-- Safari runs (D-016). The Safari Gate starts a run (never automatic); leaving, dying, or
-- disconnecting ends it. The server owns run state — course, start time, herd seed, current mount
-- species — and publishes it as player attributes. Mounts and herds are client-side visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

type Run = {
	courseId: string,
	startedAt: number,
	seed: number,
	connections: { RBXScriptConnection },
}

local SafariService = {}

local TELEPORT_HOLD = 0.3
local TUTORIAL_COURSE = "Tutorial"
local STARTING_SPECIES = "Zebra"

local runs: { [Player]: Run } = {}
local sanctuarySpawn: CFrame
local seedRng = Random.new()

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
	if player.Parent then
		player:SetAttribute("InSafari", false)
		player:SetAttribute("SafariCourse", nil)
		player:SetAttribute("SafariSeed", nil)
		player:SetAttribute("MountSpecies", nil)
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
	if runs[player] or not CourseConfig.courses[courseId] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local run: Run = {
		courseId = courseId,
		startedAt = os.clock(),
		seed = seedRng:NextInteger(1, 2 ^ 30),
		connections = {},
	}
	runs[player] = run
	player:SetAttribute("SafariCourse", courseId)
	player:SetAttribute("SafariSeed", run.seed)
	player:SetAttribute("MountSpecies", STARTING_SPECIES)
	player:SetAttribute("InSafari", true) -- set last: the client starts its ride when this flips

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
