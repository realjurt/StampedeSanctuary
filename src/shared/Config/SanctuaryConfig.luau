--!strict
-- Placeholder starter sanctuary layout. Offsets are relative to `origin`; the path runs
-- from the spawn (+Z) north to the Safari Gate (-Z).

return {
	origin = Vector3.new(-400, 0, 0),
	groundY = 0.1,
	size = 140,
	spawnOffset = Vector3.new(0, 0, 50),
	entranceOffset = Vector3.new(0, 0, 40),
	gateOffset = Vector3.new(0, 0, -10), -- 60 studs from spawn: ~4 s straight walk, habitat alongside
	habitatOffset = Vector3.new(32, 0, 0),
	habitatSize = 30,
	pathWidth = 8,
	gateActivationDistance = 14,

	-- Player plots (P1): one per player, three on each side of the shared hub, each facing it.
	-- Offsets are plot centres relative to `origin`. Server size should be at most #plotOffsets.
	plotOffsets = {
		Vector3.new(-94, 0, -45),
		Vector3.new(-94, 0, 0),
		Vector3.new(-94, 0, 45),
		Vector3.new(94, 0, -45),
		Vector3.new(94, 0, 0),
		Vector3.new(94, 0, 45),
	},
	plotSize = Vector2.new(45, 48), -- width (along the hub edge) × depth (away from the hub)
	penSize = 28, -- fits 8 animals (4 × 2) up to elephant size
}
