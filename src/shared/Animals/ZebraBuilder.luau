--!strict
-- Placeholder blocky zebra built from parts (Decision D-004). Replaced by the real voxel model later.
-- Contract every animal model must follow so the ride code can swap models:
--   PrimaryPart "Root" (anchored until a rider takes control), Seat "RiderSeat",
--   attributes AnimalId and RootHeight (Root center height above the ground),
--   legs named Leg* each with a Weld "Hip" (Part0 = Root) for procedural gallop.

local ZebraBuilder = {}

local ROOT_HEIGHT = 4

local WHITE = Color3.fromRGB(246, 246, 240)
local BLACK = Color3.fromRGB(35, 35, 40)
local MUZZLE = Color3.fromRGB(70, 70, 75)

local function block(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function leg(model: Model, root: BasePart, name: string, hipX: number, hipZ: number)
	local legLength = ROOT_HEIGHT - 1.4
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.9, legLength, 0.9)
	part.Color = WHITE
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true

	local hip = Instance.new("Weld")
	hip.Name = "Hip"
	hip.Part0 = root
	hip.Part1 = part
	hip.C0 = CFrame.new(hipX, -1.4, hipZ)
	hip.C1 = CFrame.new(0, legLength / 2, 0)
	part.CFrame = root.CFrame * hip.C0 * hip.C1:Inverse()
	hip.Parent = part
	part.Parent = model

	local hoof = Instance.new("Part")
	hoof.Name = "Hoof"
	hoof.Size = Vector3.new(1, 0.5, 1)
	hoof.Color = BLACK
	hoof.Material = Enum.Material.SmoothPlastic
	hoof.CanCollide = false
	hoof.CanTouch = false
	hoof.CanQuery = false
	hoof.Massless = true
	hoof.CFrame = part.CFrame * CFrame.new(0, -legLength / 2 + 0.25, 0)
	local hoofWeld = Instance.new("WeldConstraint")
	hoofWeld.Part0 = part
	hoofWeld.Part1 = hoof
	hoofWeld.Parent = hoof
	hoof.Parent = model
end

-- groundCFrame: point on the ground where the zebra stands, facing its LookVector.
function ZebraBuilder.build(groundCFrame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Zebra"
	model:SetAttribute("AnimalId", "Zebra")
	model:SetAttribute("RootHeight", ROOT_HEIGHT)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 3, 6)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Anchored = true
	root.RootPriority = 10
	root.CFrame = groundCFrame * CFrame.new(0, ROOT_HEIGHT, 0)
	root.Parent = model
	model.PrimaryPart = root

	block(model, root, "Body", Vector3.new(3.2, 2.8, 5.6), CFrame.new(), WHITE)
	for i, z in { -1.7, -0.4, 0.9, 2.2 } do
		block(model, root, "Stripe" .. i, Vector3.new(3.3, 2.9, 0.45), CFrame.new(0, 0, z), BLACK)
	end

	local neckTilt = CFrame.Angles(-0.3, 0, 0)
	block(model, root, "Neck", Vector3.new(1.4, 2.6, 1.6), CFrame.new(0, 2.2, -2.4) * neckTilt, WHITE)
	block(model, root, "Mane", Vector3.new(0.6, 2.8, 0.5), CFrame.new(0, 2.4, -1.75) * neckTilt, BLACK)
	block(model, root, "Head", Vector3.new(2.2, 2, 3), CFrame.new(0, 3.7, -3.6), WHITE)
	block(model, root, "Muzzle", Vector3.new(2, 1.4, 1), CFrame.new(0, 3.4, -5.4), MUZZLE)
	for _, side in { -1, 1 } do
		block(model, root, "Eye", Vector3.new(0.2, 0.6, 0.6), CFrame.new(side * 1.11, 4, -4.1), BLACK)
		block(model, root, "Ear", Vector3.new(0.5, 1, 0.35), CFrame.new(side * 0.65, 5.1, -3), WHITE)
	end
	block(model, root, "Tail", Vector3.new(0.4, 1.8, 0.4), CFrame.new(0, 0.2, 2.95) * CFrame.Angles(0.4, 0, 0), BLACK)

	leg(model, root, "LegFL", -1, -2)
	leg(model, root, "LegFR", 1, -2)
	leg(model, root, "LegBL", -1, 2)
	leg(model, root, "LegBR", 1, 2)

	local seat = Instance.new("Seat")
	seat.Name = "RiderSeat"
	seat.Size = Vector3.new(2, 0.2, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false -- only the server seats riders, never by touch
	seat.Massless = true
	seat.CFrame = root.CFrame * CFrame.new(0, 1.5, 0.2)
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = root
	seatWeld.Part1 = seat
	seatWeld.Parent = seat
	seat.Parent = model

	return model
end

return ZebraBuilder
