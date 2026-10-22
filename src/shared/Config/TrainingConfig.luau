--!strict
-- Training machine balance (P4, D-026). Stamina is only ever changed by the server; see MachineService.

return {
	-- Machine levels: `price` is the cost of reaching that level (L1 = buying the machine),
	-- `gain` is stamina added per tick while the owner sits on it.
	levels = {
		{ price = 300, gain = 0.2 },
		{ price = 1500, gain = 0.3 },
		{ price = 5000, gain = 0.4 },
		{ price = 15000, gain = 0.5 },
	} :: { { price: number, gain: number } },
	tickInterval = 0.5, -- seconds between stamina gains

	-- Optional BOOST rhythm: every `boostInterval` seconds of training the server opens a window of
	-- `boostWindow` seconds; pressing BOOST inside it multiplies gains for `boostDuration` seconds.
	boostInterval = 6,
	boostWindow = 1.2,
	boostLatency = 0.35, -- extra seconds a hit may arrive after the window closes (network delay)
	boostDuration = 3,
	boostMultiplier = 2,
}
