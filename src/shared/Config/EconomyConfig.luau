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
	incomeInterval = 1, -- seconds between income ticks
	depositRevealInterval = 0.6, -- seconds between deposited animals appearing in the pen
	depositRange = 16, -- max studs from the DEPOSIT sign the server accepts a deposit from

	-- Pen upgrades (P4, D-026). Level 1 is free; `price` is the cost of reaching that level.
	-- The pen is built to fit the last level from the start.
	penLevels = {
		{ price = 0, capacity = 8 },
		{ price = 1000, capacity = 10 },
		{ price = 4000, capacity = 12 },
	} :: { { price: number, capacity: number } },

	-- One-time coins on a player's first ever deposit (P4), so they can buy the first machine quickly.
	starterDepositReward = 300,
	purchaseRange = 14, -- max studs from a purchase sign the server accepts a purchase from
}
