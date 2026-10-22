--!strict
-- Persistent animal records (data v3, D-024). Pure functions on a player's data table, so they can
-- be tested without a live profile. Every owned animal is one record with a unique id:
--   "carried" — tamed on safari, held until deposited (P2)
--   "pen"     — deposited in the player's pen; only these earn income (P3)
-- The collection inventory (P6) and selling read these same records.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

export type AnimalState = "carried" | "pen"

export type AnimalRecord = {
	id: string,
	species: string,
	state: AnimalState,
	caughtAt: number, -- os.time()
}

-- The fields of PlayerData this module owns.
export type Owner = {
	animals: { AnimalRecord },
	nextAnimalId: number,
}

local AnimalCollection = {}

-- Hard ceiling on stored records so a bug can't grow a save past DataStore limits.
AnimalCollection.MAX_RECORDS = 500

local VALID_STATES: { [string]: boolean } = { carried = true, pen = true }

function AnimalCollection.countCarried(owner: Owner): number
	local count = 0
	for _, record in owner.animals do
		if record.state == "carried" then
			count += 1
		end
	end
	return count
end

function AnimalCollection.countInPen(owner: Owner): number
	local count = 0
	for _, record in owner.animals do
		if record.state == "pen" then
			count += 1
		end
	end
	return count
end

function AnimalCollection.incomeOf(species: string): number
	return EconomyConfig.incomePerSecond[species] or 0
end

-- Coins per second from pen animals only (D-024: carried animals never earn).
function AnimalCollection.penIncome(owner: Owner): number
	local total = 0
	for _, record in owner.animals do
		if record.state == "pen" then
			total += AnimalCollection.incomeOf(record.species)
		end
	end
	return total
end

-- Pen records in deposit order; a record's index is its slot in the pen.
function AnimalCollection.penRecords(owner: Owner): { AnimalRecord }
	local list = {}
	for _, record in owner.animals do
		if record.state == "pen" then
			table.insert(list, record)
		end
	end
	return list
end

-- Moves carried animals into the pen, oldest first, until it holds `capacity`. Each record only
-- changes state in place, so a deposit can never create or duplicate a record. Returns the moved
-- records (empty when nothing was carried or the pen is full). Doesn't yield.
function AnimalCollection.depositCarried(owner: Owner, capacity: number): { AnimalRecord }
	local space = capacity - AnimalCollection.countInPen(owner)
	local moved = {}
	for _, record in owner.animals do
		if #moved >= space then
			break
		end
		if record.state == "carried" then
			record.state = "pen"
			table.insert(moved, record)
		end
	end
	return moved
end

-- Adds a carried animal and returns it. The caller has already validated the capture.
function AnimalCollection.addCarried(owner: Owner, species: string): AnimalRecord
	local record: AnimalRecord = {
		id = tostring(owner.nextAnimalId),
		species = species,
		state = "carried",
		caughtAt = os.time(),
	}
	owner.nextAnimalId += 1
	table.insert(owner.animals, record)
	return record
end

-- Rebuilds records from saved data: unknown species, bad states and duplicate ids are dropped, and
-- nextAnimalId is kept above every existing id so new ids can never collide.
function AnimalCollection.sanitize(savedAnimals: any, savedNextId: any): Owner
	local owner: Owner = { animals = {}, nextAnimalId = 1 }
	local seen: { [string]: boolean } = {}
	local highest = 0
	if typeof(savedAnimals) == "table" then
		for _, saved in savedAnimals do
			if #owner.animals >= AnimalCollection.MAX_RECORDS then
				break
			end
			if typeof(saved) == "table"
				and typeof(saved.id) == "string"
				and not seen[saved.id]
				and typeof(saved.species) == "string"
				and AnimalConfig[saved.species] ~= nil
				and typeof(saved.state) == "string"
				and VALID_STATES[saved.state]
			then
				seen[saved.id] = true
				local caughtAt = if typeof(saved.caughtAt) == "number" and saved.caughtAt == saved.caughtAt then saved.caughtAt else 0
				table.insert(owner.animals, {
					id = saved.id,
					species = saved.species,
					state = saved.state :: AnimalState,
					caughtAt = caughtAt,
				})
				highest = math.max(highest, tonumber(saved.id) or 0)
			end
		end
	end
	local nextId = if typeof(savedNextId) == "number" and savedNextId == savedNextId and savedNextId < 2 ^ 50 then math.floor(savedNextId) else 1
	owner.nextAnimalId = math.max(nextId, highest + 1, 1)
	return owner
end

-- Comma-separated species of carried animals, in catch order (for the client HUD).
function AnimalCollection.carriedSpecies(owner: Owner): string
	local list = {}
	for _, record in owner.animals do
		if record.state == "carried" then
			table.insert(list, record.species)
		end
	end
	return table.concat(list, ",")
end

return AnimalCollection
