--!strict
-- Economy and stat values (server-authoritative). Starting values are playtest placeholders —
-- see Obsidian "17 - Reference Game Analysis" §4.

return {
	startingCoins = 0,
	startingStamina = 20,
	-- Sanity caps applied when loading saved data, so a corrupted value can't break the economy.
	maxCoins = 1e15,
	maxStamina = 1e6,
	-- Frequent changes (e.g. income ticks) mark data unsaved instead of saving at once; this loop
	-- writes them out. Leaving the game and server shutdown always save.
	autosaveInterval = 60,
}
