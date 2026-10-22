--!strict
-- Loads and saves player progress. Progress flags are mirrored to player attributes so the client
-- can read them without extra remotes. If the DataStore is unavailable (e.g. Studio API access off),
-- play continues with defaults and nothing is saved — never overwrite real data with defaults.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local TrainingConfig = require(ReplicatedStorage.Shared.Config.TrainingConfig)
local AnimalCollection = require(script.Parent.AnimalCollection)

-- Version history: 1 = progress flags + discovered; 2 = + coins, stamina (P1); 3 = + animals,
-- nextAnimalId (P2); 4 = + machineLevel, penLevel, starterRewardClaimed (P4). Older saves load through `reconcile`, which fills anything missing with
-- defaults — no separate migration step.
export type PlayerData = {
	version: number,
	tutorialCompleted: boolean,
	starterZebraUnlocked: boolean,
	onboardingDismissed: boolean,
	leapTutorialDone: boolean, -- first-time slow-motion leap lesson learned or skipped (D-021)
	discovered: { [string]: boolean },
	coins: number,
	stamina: number,
	animals: { AnimalCollection.AnimalRecord }, -- see AnimalCollection
	nextAnimalId: number,
	machineLevel: number, -- 0 = no training machine yet (TrainingConfig.levels)
	penLevel: number, -- 1.. (EconomyConfig.penLevels)
	starterRewardClaimed: boolean, -- one-time first-deposit coins already granted
}

type Profile = {
	data: PlayerData,
	canSave: boolean,
	saving: boolean,
	dirty: boolean, -- changed while a save was in flight: save again
	unsaved: boolean, -- changed with deferSave: the autosave loop writes it
	lastSaveOk: boolean,
}

local PlayerDataService = {}

-- Studio playtests use their own store so testing (including resets) never touches live player data.
-- The store name keeps "v1" on purpose: v2+ data lives in the same keys (see `reconcile`).
local STORE_NAME = if RunService:IsStudio() then "PlayerData_v1_Studio" else "PlayerData_v1"
local DATA_VERSION = 4
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
		coins = EconomyConfig.startingCoins,
		stamina = EconomyConfig.startingStamina,
		animals = {},
		nextAnimalId = 1,
		machineLevel = 0,
		penLevel = 1,
		starterRewardClaimed = false,
	}
end

-- A saved number is used only if it is a real, finite value; it is clamped into range.
local function sanitizeNumber(value: any, fallback: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
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
	data.coins = sanitizeNumber(saved.coins, data.coins, 0, EconomyConfig.maxCoins)
	data.stamina = sanitizeNumber(saved.stamina, data.stamina, 0, EconomyConfig.maxStamina)
	local owner = AnimalCollection.sanitize(saved.animals, saved.nextAnimalId)
	data.animals = owner.animals
	data.nextAnimalId = owner.nextAnimalId
	data.machineLevel = math.floor(sanitizeNumber(saved.machineLevel, 0, 0, #TrainingConfig.levels))
	data.penLevel = math.floor(sanitizeNumber(saved.penLevel, 1, 1, #EconomyConfig.penLevels))
	-- Saves from before P4 that already deposited have had their first deposit: no reward then.
	data.starterRewardClaimed = saved.starterRewardClaimed == true
		or (saved.starterRewardClaimed == nil and AnimalCollection.countInPen(data) > 0)
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
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("Stamina", data.stamina)
	player:SetAttribute("CarriedCount", AnimalCollection.countCarried(data))
	player:SetAttribute("CarriedSpecies", AnimalCollection.carriedSpecies(data))
	player:SetAttribute("MachineLevel", data.machineLevel)
	player:SetAttribute("PenLevel", data.penLevel)
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
		profile.unsaved = false
		local snapshot = table.clone(profile.data)
		snapshot.discovered = table.clone(profile.data.discovered)
		snapshot.animals = table.create(#profile.data.animals)
		for i, record in profile.data.animals do
			snapshot.animals[i] = table.clone(record)
		end
		local ok, err = pcall(function()
			-- Studio-only fault injection for tests, via attributes on this script: TestSaveDelay
			-- (seconds a write takes) and TestFailSaves (number of writes that fail).
			local delay = if RunService:IsStudio() then script:GetAttribute("TestSaveDelay") else nil
			if typeof(delay) == "number" and delay > 0 then
				task.wait(delay)
			end
			local failures = if RunService:IsStudio() then script:GetAttribute("TestFailSaves") else nil
			if typeof(failures) == "number" and failures > 0 then
				script:SetAttribute("TestFailSaves", failures - 1)
				error("simulated DataStore failure")
			end
			(store :: DataStore):UpdateAsync(keyFor(player), function()
				return snapshot
			end)
		end)
		profile.lastSaveOk = ok
		if not ok then
			-- The in-memory data stays authoritative; the autosave loop retries it.
			profile.unsaved = true
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
	profiles[player] = { data = data, canSave = canSave, saving = false, dirty = false, unsaved = false, lastSaveOk = true }
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

-- Like `get`, but never yields: nil until the player's data has loaded.
function PlayerDataService.peek(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- Saves now and yields until every pending write for this player has finished. Returns whether the
-- last write succeeded (false also when saving is unavailable). A failed write stays marked unsaved
-- so the autosave loop retries it.
function PlayerDataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	save(player)
	while profile.saving do
		task.wait()
	end
	return profile.lastSaveOk
end

-- Applies a change, republishes attributes, and saves in the background. Pass `deferSave` for
-- frequent small changes (income ticks, training): the autosave loop writes them instead.
function PlayerDataService.update(player: Player, mutator: (PlayerData) -> (), deferSave: boolean?)
	local profile = profiles[player]
	if not profile then
		return
	end
	mutator(profile.data)
	publish(player, profile.data)
	if deferSave then
		profile.unsaved = true
	else
		task.spawn(save, player)
	end
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
		-- Last chance to write this player's data: wait for any in-flight save and retry failures.
		local profile = profiles[player]
		if profile then
			for attempt = 1, LOAD_ATTEMPTS do
				save(player)
				while profile.saving do
					task.wait()
				end
				if profile.lastSaveOk then
					break
				end
				task.wait(attempt)
			end
		end
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(EconomyConfig.autosaveInterval)
			for player, profile in profiles do
				if profile.unsaved then
					task.spawn(save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				while profile.saving do -- a save already in flight (e.g. a deposit) must finish too
					task.wait()
				end
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
