--!strict
-- Taming balance (P2, D-024). Per-species requirement and tame time live in AnimalConfig.
-- Placeholder values for playtesting, not formulas observed in the reference.

local TamingConfig = {}

-- Animals a player can carry before depositing them at their pen (P3).
TamingConfig.carryCapacity = 7

-- Grip = how long you can stay on before being bucked off (formerly "temper").
-- Grip seconds = species base × scale, where scale = gripBaseScale + stamina × gripPerStamina,
-- clamped to [gripMinScale, gripMaxScale]. Starting stamina 20 → ×1.0 (today's feel); the cap is
-- reached at stamina 40 (×1.5), so training beyond that unlocks animals but doesn't trivialize grip.
TamingConfig.gripBaseScale = 0.5
TamingConfig.gripPerStamina = 0.025
TamingConfig.gripMinScale = 0.5
TamingConfig.gripMaxScale = 1.5

-- Tame bar shows "almost tamed" from this fraction.
TamingConfig.almostTamedAt = 0.75

-- Server: a tame request may arrive this much sooner than tameTime after the server accepted the
-- switch (network timing). The client also spends the leap arc (~0.45 s) before taming starts.
TamingConfig.tameTimeTolerance = 0.25

function TamingConfig.gripSeconds(baseSeconds: number, stamina: number): number
	local scale = math.clamp(
		TamingConfig.gripBaseScale + stamina * TamingConfig.gripPerStamina,
		TamingConfig.gripMinScale,
		TamingConfig.gripMaxScale
	)
	return baseSeconds * scale
end

return TamingConfig
