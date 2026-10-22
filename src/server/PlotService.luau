--!strict
-- Gives every player their own plot around the shared hub for as long as they're in the server.
-- Ownership is server-only: the plot model's OwnerUserId attribute and the player's PlotId
-- attribute are published so clients can find "my plot" without remotes.

local Players = game:GetService("Players")

local SanctuaryBuilder = require(script.Parent.SanctuaryBuilder)

type Plot = SanctuaryBuilder.Plot

local PlotService = {}

local plots: { Plot } = {}
local owned: { [number]: Plot } = {} -- UserId → plot

local function showOwner(plot: Plot, displayName: string?)
	if displayName then
		plot.title.Text = `{displayName}'s Sanctuary`
		plot.income.Text = "$0/s" -- pen income arrives in P3
	else
		plot.title.Text = "Empty Plot"
		plot.income.Text = ""
	end
end

-- Claims the first free plot. Returns its id, or nil when every plot is taken.
-- Keyed by UserId (not Player) so the logic can be exercised in tests without a real second client.
function PlotService.claim(userId: number, displayName: string): number?
	local existing = owned[userId]
	if existing then
		return existing.id
	end
	for _, plot in plots do
		if plot.model:GetAttribute("OwnerUserId") == 0 then
			plot.model:SetAttribute("OwnerUserId", userId)
			owned[userId] = plot
			showOwner(plot, displayName)
			return plot.id
		end
	end
	return nil
end

function PlotService.release(userId: number)
	local plot = owned[userId]
	if not plot then
		return
	end
	owned[userId] = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	showOwner(plot, nil)
end

function PlotService.getPlot(player: Player): Model?
	local plot = owned[player.UserId]
	return if plot then plot.model else nil
end

local function onPlayerAdded(player: Player)
	local id = PlotService.claim(player.UserId, player.DisplayName)
	if id then
		player:SetAttribute("PlotId", id)
	else
		warn(`PlotService: no free plot for {player.Name} — server size exceeds {#plots} plots`)
	end
end

function PlotService.start(builtPlots: { Plot })
	plots = builtPlots
	for _, plot in plots do
		showOwner(plot, nil)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player.UserId)
	end)
end

return PlotService
