--!strict
-- Placeholder starter sanctuary layout. Offsets are relative to `origin`; the path runs
-- from the spawn (+Z) north to the Safari Gate (-Z).

return {
	origin = Vector3.new(-400, 0, 0),
	groundY = 0.1,
	size = 140,
	spawnOffset = Vector3.new(0, 0, 50),
	entranceOffset = Vector3.new(0, 0, 40),
	gateOffset = Vector3.new(0, 0, -50),
	habitatOffset = Vector3.new(32, 0, 0),
	habitatSize = 30,
	pathWidth = 8,
	gateActivationDistance = 14,
}
