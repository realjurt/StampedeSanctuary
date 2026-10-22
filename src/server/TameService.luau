--!strict
-- Validates tames (D-024). The client fills the tame bar locally and asks to tame its current mount;
-- the server accepts only if every check passes, then records one carried animal and saves at once.
-- Switching alone never collects anything. Replies on the same remote: (memberId, ok, reason).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local TamingConfig = require(ReplicatedStorage.Shared.Config.TamingConfig)
local AnimalCollection = require(script.Parent.AnimalCollection)
local Net = require(script.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SafariService = require(script.Parent.SafariService)

export type Rejection = "invalid" | "notMounted" | "alreadyTamed" | "stamina" | "tooSoon" | "full"

local TameService = {}

-- Runs every check without changing anything. Returns the species on success.
function TameService.check(player: Player, memberId: any): (string?, Rejection?)
	if typeof(memberId) ~= "string" or #memberId > 16 then
		return nil, "invalid"
	end
	local data = PlayerDataService.get(player)
	if not data then
		return nil, "invalid"
	end
	local mountMember, species, mountedAt = SafariService.getMount(player)
	if mountMember ~= memberId or not species or not mountedAt then
		return nil, "notMounted"
	end
	local stats = AnimalConfig[species]
	if data.stamina < stats.requiredStamina then
		return nil, "stamina"
	end
	if os.clock() - mountedAt < stats.tameTime - TamingConfig.tameTimeTolerance then
		return nil, "tooSoon"
	end
	if AnimalCollection.countCarried(data) >= TamingConfig.carryCapacity then
		return nil, "full"
	end
	return species, nil
end

local remote: RemoteEvent

local function onTame(player: Player, memberId: any)
	local species, rejection = TameService.check(player, memberId)
	-- markTamed is the single gate against duplicates: nothing yields between it and the record.
	if species and not SafariService.markTamed(player, memberId) then
		species, rejection = nil, "alreadyTamed"
	end
	if not species then
		warn(`TameService: rejected tame from {player.Name} ({rejection})`)
		remote:FireClient(player, if typeof(memberId) == "string" then memberId else "", false, rejection)
		return
	end
	PlayerDataService.update(player, function(data)
		AnimalCollection.addCarried(data, species)
		data.discovered[species] = true
	end)
	remote:FireClient(player, memberId, true, species)
end

function TameService.start()
	remote = Net.on("TameAnimal", 0.5, onTame)
end

return TameService
