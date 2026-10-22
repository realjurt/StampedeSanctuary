--!strict
-- Taming balance (P2, D-024). Per-species requirement and tame time live in AnimalConfig.
-- Placeholder values for playtesting, not formulas observed in the reference.

local TamingConfig = {}

-- Animals a player can carry before depositing them at their pen (P3).
TamingConfig.carryCapacity = 7

-- Grip = how long you can stay on before being bucked off (formerly "temper").
-- Grip seconds = species base × gripScale(stamina). The scale is read off `gripCurve`, a list of
-- { stamina, scale } points joined by straight lines (approved P4 targets, D-026): diminishing
-- returns after 40, capped at the last point. Stamina itself keeps growing past 100 and is saved.
-- Edit the points to rebalance; keep them sorted by stamina.
TamingConfig.gripCurve = {
	{ 0, 0.5 },
	{ 20, 1.0 }, -- starting stamina: unchanged feel
	{ 40, 1.5 },
	{ 60, 1.7 },
	{ 80, 1.85 },
	{ 100, 2.0 }, -- cap
} :: { { number } }

-- Tame bar shows "almost tamed" from this fraction.
TamingConfig.almostTamedAt = 0.75

-- Server: a tame request may arrive this much sooner than tameTime after the server accepted the
-- switch (network timing). The client also spends the leap arc (~0.45 s) before taming starts.
TamingConfig.tameTimeTolerance = 0.25

function TamingConfig.gripScale(stamina: number): number
	local curve = TamingConfig.gripCurve
	if stamina <= curve[1][1] then
		return curve[1][2]
	end
	for i = 2, #curve do
		local low, high = curve[i - 1], curve[i]
		if stamina <= high[1] then
			return low[2] + (high[2] - low[2]) * (stamina - low[1]) / (high[1] - low[1])
		end
	end
	return curve[#curve][2]
end

function TamingConfig.gripSeconds(baseSeconds: number, stamina: number): number
	return baseSeconds * TamingConfig.gripScale(stamina)
end

return TamingConfig
