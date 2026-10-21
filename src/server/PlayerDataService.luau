--!strict
-- Loads and saves player progress. Progress flags are mirrored to player attributes so the client
-- can read them without extra remotes. If the DataStore is unavailable (e.g. Studio API access off),
-- play continues with defaults and nothing is saved — never overwrite real data with defaults.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type PlayerData = {
	version: number,
	tutorialCompleted: boolean,
	starterZebraUnlocked: boolean,
	onboardingDismissed: boolean,
	leapTutorialDone: boolean, -- first-time slow-motion leap lesson learned or skipped (D-021)
	discovered: { [string]: boolean },
}

type Profile = {
	data: PlayerData,
	canSave: boolean,
	saving: boolean,
	dirty: boolean,
}

local PlayerDataService = {}

-- Studio playtests use their own store so testing (including resets) never touches live player data.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_v1_Studio" else "PlayerData_v1"
local DATA_VERSION = 1
local LOAD_ATTEMPTS = 3

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}

local function defaults(): PlayerData
	return {
		version = DATA_VERSION,
		tutorialCompleted = false,
		starterZebraUnlocked = false,
		onboardingDismissed = false,
		leapTutorialDone = false,
		discovered = {},
	}
end

local function reconcile(saved: any): PlayerData
	local data = defaults()
	if typeof(saved) ~= "table" then
		return data
	end
	data.tutorialCompleted = saved.tutorialCompleted == true
	data.starterZebraUnlocked = saved.starterZebraUnlocked == true
	data.onboardingDismissed = saved.onboardingDismissed == true
	data.leapTutorialDone = saved.leapTutorialDone == true
	if typeof(saved.discovered) == "table" then
		for species, value in saved.discovered do
			if typeof(species) == "string" and value == true then
				data.discovered[species] = true
			end
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function publish(player: Player, data: PlayerData)
	player:SetAttribute("TutorialCompleted", data.tutorialCompleted)
	player:SetAttribute("StarterZebraUnlocked", data.starterZebraUnlocked)
	player:SetAttribute("OnboardingDismissed", data.onboardingDismissed)
	player:SetAttribute("LeapTutorialDone", data.leapTutorialDone)
	local discovered = {}
	for species in data.discovered do
		table.insert(discovered, species)
	end
	table.sort(discovered)
	player:SetAttribute("Discovered", table.concat(discovered, ","))
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	if profile.saving then
		profile.dirty = true
		return
	end
	profile.saving = true
	repeat
		profile.dirty = false
		local snapshot = table.clone(profile.data)
		snapshot.discovered = table.clone(profile.data.discovered)
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function()
				return snapshot
			end)
		end)
		if not ok then
			warn(`PlayerDataService: save failed for {player.Name}: {err}`)
		end
	until not profile.dirty
	profile.saving = false
end

local function load(player: Player)
	local data = defaults()
	local canSave = false
	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(player))
			end)
			if ok then
				data = reconcile(result)
				canSave = true
				break
			end
			warn(`PlayerDataService: load attempt {attempt} failed for {player.Name}: {result}`)
			task.wait(attempt)
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, canSave = canSave, saving = false, dirty = false }
	publish(player, data)
	player:SetAttribute("DataSaveDisabled", not canSave)
	player:SetAttribute("DataLoaded", true)
end

-- Yields until the player's data is loaded. Returns nil if they left first.
function PlayerDataService.get(player: Player): PlayerData?
	while player.Parent and not profiles[player] do
		task.wait()
	end
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- Applies a change, republishes attributes, and saves in the background.
function PlayerDataService.update(player: Player, mutator: (PlayerData) -> ())
	local profile = profiles[player]
	if not profile then
		return
	end
	mutator(profile.data)
	publish(player, profile.data)
	task.spawn(save, player)
end

-- Developer tool (see DevCommands). Replaces the in-memory profile with defaults *first*, so old
-- progress can never be saved back over the reset, then overwrites only this player's key.
function PlayerDataService.resetToDefaults(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	profile.data = defaults()
	publish(player, profile.data)
	while profile.saving do
		task.wait()
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return defaults()
		end)
	end)
	if not ok then
		warn(`PlayerDataService: reset failed for {player.Name}: {err}`)
	end
	return ok
end

function PlayerDataService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`PlayerDataService: DataStore unavailable, progress will not save: {result}`)
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return PlayerDataService
