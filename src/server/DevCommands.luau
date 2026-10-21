--!strict
-- TEMPORARY developer tool — remove before public release.
-- Chat "/resetmydata confirm" to reset YOUR OWN saved progress to a brand-new player.
-- Only AUTHORIZED_USER_IDS can use it; it never touches other players' data or the whole store.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local PlayerDataService = require(script.Parent.PlayerDataService)

local AUTHORIZED_USER_IDS: { [number]: boolean } = {
	[1029050237] = true, -- realjurt
}

local CONFIRM_TEXT = "/resetmydata confirm"

local DevCommands = {}

function DevCommands.start()
	local command = Instance.new("TextChatCommand")
	command.Name = "ResetMyDataCommand"
	command.PrimaryAlias = "/resetmydata"
	command.Parent = TextChatService

	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player or not AUTHORIZED_USER_IDS[player.UserId] then
			warn(`DevCommands: /resetmydata denied for UserId {source.UserId}`)
			return
		end
		local normalized = string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1")))
		if normalized ~= CONFIRM_TEXT then
			print(`DevCommands: type "{CONFIRM_TEXT}" to reset your saved progress.`)
			return
		end
		if PlayerDataService.resetToDefaults(player) then
			print(`DevCommands: reset saved progress for {player.Name} ({player.UserId}).`)
			player:Kick("Your Stampede Sanctuary progress was reset. Rejoin to play as a new player.")
		else
			warn(`DevCommands: reset failed for {player.Name} — data not loaded or saving unavailable.`)
		end
	end)
end

return DevCommands
