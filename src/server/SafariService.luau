--!strict
-- Safari runs (D-016). The Safari Gate starts a run (never automatic); leaving, dying, or
-- disconnecting ends it. The server owns run state — course, start time, herd seed, current mount
-- species — and publishes it as player attributes. Mounts and herds are client-side visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local HerdSchedule = require(ReplicatedStorage.Shared.Herds.HerdSchedule)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

type HerdMemberInfo = { species: string, distance: number }

type Run = {
	courseId: string,
	startedAt: number,
	seed: number,
	-- Herd members this run's seed produces, rebuilt server-side to validate switches (D-016).
	herdMembers: { [string]: HerdMemberInfo },
	usedMembers: { [string]: boolean },
	switches: number,
	-- Taming (D-024): the herd animal currently ridden (nil = starting mount) and when the server
	-- accepted that switch. `tamed` survives "Ride again" (same seed, same herds), so a restart can
	-- never let the same animal be tamed twice.
	mountMember: string?,
	mountedAt: number,
	tamed: { [string]: boolean },
	connections: { RBXScriptConnection },
}

local SafariService = {}

local TELEPORT_HOLD = 0.3
local TUTORIAL_COURSE = "Tutorial"
local STARTING_SPECIES = "Zebra"
local MAX_PLAUSIBLE_SPEED = 70 -- studs/s, above any species' boosted cruise speed
local REACH_SLACK = 40 -- leap range plus margin

local function buildHerdMembers(course: CourseConfig.Course, seed: number): { [string]: HerdMemberInfo }
	local members = {}
	if course.herds then
		for _, herd in HerdSchedule.generate(course, seed) do
			for _, member in herd.members do
				members[member.id] = { species = member.species, distance = member.distance }
			end
		end
	end
	return members
end

local runs: { [Player]: Run } = {}
local sanctuarySpawn: CFrame
local seedRng = Random.new()

-- Read-only view of a player's active run, for reward validation: course, seconds since (re)start,
-- and how many validated animal switches happened.
function SafariService.getRun(player: Player): (string?, number?, number?)
	local run = runs[player]
	if not run then
		return nil, nil, nil
	end
	return run.courseId, os.clock() - run.startedAt, run.switches
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

	local seed = seedRng:NextInteger(1, 2 ^ 30)
	local run: Run = {
		courseId = courseId,
		startedAt = os.clock(),
		seed = seed,
		herdMembers = buildHerdMembers(CourseConfig.courses[courseId], seed),
		usedMembers = {},
		switches = 0,
		mountMember = nil,
		mountedAt = 0,
		tamed = {},
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

-- The client predicts leaps instantly; the server accepts one only if that herd animal exists in this
-- run's seeded schedule, hasn't been ridden yet, and could plausibly have been reached by now.
local function switchMount(player: Player, memberId: any)
	local run = runs[player]
	if not run or typeof(memberId) ~= "string" or #memberId > 16 then
		return
	end
	local member = run.herdMembers[memberId]
	local elapsed = os.clock() - run.startedAt
	if not member or run.usedMembers[memberId] or run.tamed[memberId] or member.distance - REACH_SLACK > elapsed * MAX_PLAUSIBLE_SPEED then
		warn(`SafariService: rejected switch from {player.Name} to "{memberId}"`)
		return
	end
	local data = PlayerDataService.get(player)
	if not data or data.stamina < AnimalConfig[member.species].requiredStamina then
		warn(`SafariService: rejected switch from {player.Name} to "{memberId}" (not enough stamina)`)
		return
	end
	if runs[player] ~= run then
		return -- the run ended while data was loading
	end
	run.usedMembers[memberId] = true
	run.switches += 1
	run.mountMember = memberId
	run.mountedAt = os.clock()
	player:SetAttribute("MountSpecies", member.species)
end

-- "Ride again" restarts the same course: fresh timer, herds and starting mount.
local function restartRun(player: Player)
	local run = runs[player]
	if not run then
		return
	end
	run.startedAt = os.clock()
	table.clear(run.usedMembers)
	run.switches = 0
	run.mountMember = nil
	player:SetAttribute("MountSpecies", STARTING_SPECIES)
end

-- The herd animal the player is riding (server-confirmed): member id, species, and os.clock() when
-- the switch was accepted. Nil while on the starting mount or off safari.
function SafariService.getMount(player: Player): (string?, string?, number?)
	local run = runs[player]
	local memberId = run and run.mountMember
	if not run or not memberId then
		return nil, nil, nil
	end
	return memberId, run.herdMembers[memberId].species, run.mountedAt
end

-- Marks the current mount tamed. Returns false if it was already tamed this run.
function SafariService.markTamed(player: Player, memberId: string): boolean
	local run = runs[player]
	if not run or run.mountMember ~= memberId or run.tamed[memberId] then
		return false
	end
	run.tamed[memberId] = true
	return true
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
	Net.on("SwitchMount", 0.3, switchMount)
	Net.on("RestartRun", 0.5, restartRun)
	Players.PlayerRemoving:Connect(cleanup)
end

return SafariService
