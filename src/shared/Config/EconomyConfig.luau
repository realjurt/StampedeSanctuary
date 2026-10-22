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

	-- Pen & income (P3, D-025). Only animals in the pen earn; carried ones never do. No offline earnings.
	incomePerSecond = {
		Zebra = 1,
		Giraffe = 2,
		Elephant = 5,
	} :: { [string]: number },
	penCapacity = 8,
	incomeInterval = 1, -- seconds between income ticks
	depositRevealInterval = 0.6, -- seconds between deposited animals appearing in the pen
	depositRange = 22, -- max studs from the pen centre the server accepts a deposit from
}
