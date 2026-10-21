--!strict
-- Placeholder blocky animals built from parts (D-004). Replaced by Claude 3D Design models later.
-- Contract every animal model follows so riding/herd code can swap models:
--   PrimaryPart "Root"; attributes AnimalId, RootHeight (Root center above ground) and
--   RiderOffset (rider HumanoidRootPart above Root when seated);
--   legs named Leg* (FL, FR, BL, BR) each with a Weld "Hip" (Part0 = Root) for procedural gait.
-- Only Root may be anchored; every other part is welded to it.

local AnimalBuilder = {}

type Spec = {
	rootHeight: number,
	riderOffset: number,
	build: (model: Model, root: BasePart) -> (),
}

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

local function leg(model: Model, root: BasePart, name: string, hip: Vector3, thickness: number, length: number, color: Color3, hoofColor: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(thickness, length, thickness)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true

	local weld = Instance.new("Weld")
	weld.Name = "Hip"
	weld.Part0 = root
	weld.Part1 = part
	weld.C0 = CFrame.new(hip)
	weld.C1 = CFrame.new(0, length / 2, 0)
	part.CFrame = root.CFrame * weld.C0 * weld.C1:Inverse()
	weld.Parent = part
	part.Parent = model

	local hoof = Instance.new("Part")
	hoof.Name = "Hoof"
	hoof.Size = Vector3.new(thickness + 0.1, 0.5, thickness + 0.1)
	hoof.Color = hoofColor
	hoof.Material = Enum.Material.SmoothPlastic
	hoof.CanCollide = false
	hoof.CanTouch = false
	hoof.CanQuery = false
	hoof.Massless = true
	hoof.CFrame = part.CFrame * CFrame.new(0, -length / 2 + 0.25, 0)
	local hoofWeld = Instance.new("WeldConstraint")
	hoofWeld.Part0 = part
	hoofWeld.Part1 = hoof
	hoofWeld.Parent = hoof
	hoof.Parent = model
end

local function fourLegs(model: Model, root: BasePart, bodyBottom: number, rootHeight: number, spreadX: number, spreadZ: number, thickness: number, color: Color3, hoofColor: Color3)
	local length = rootHeight - bodyBottom
	leg(model, root, "LegFL", Vector3.new(-spreadX, -bodyBottom, -spreadZ), thickness, length, color, hoofColor)
	leg(model, root, "LegFR", Vector3.new(spreadX, -bodyBottom, -spreadZ), thickness, length, color, hoofColor)
	leg(model, root, "LegBL", Vector3.new(-spreadX, -bodyBottom, spreadZ), thickness, length, color, hoofColor)
	leg(model, root, "LegBR", Vector3.new(spreadX, -bodyBottom, spreadZ), thickness, length, color, hoofColor)
end

local SPECS: { [string]: Spec } = {
	Zebra = {
		rootHeight = 4,
		riderOffset = 3.1,
		build = function(model, root)
			local white, black, muzzle = Color3.fromRGB(246, 246, 240), Color3.fromRGB(35, 35, 40), Color3.fromRGB(70, 70, 75)
			block(model, root, "Body", Vector3.new(3.2, 2.8, 5.6), CFrame.new(), white)
			for i, z in { -1.7, -0.4, 0.9, 2.2 } do
				block(model, root, "Stripe" .. i, Vector3.new(3.3, 2.9, 0.45), CFrame.new(0, 0, z), black)
			end
			local tilt = CFrame.Angles(-0.3, 0, 0)
			block(model, root, "Neck", Vector3.new(1.4, 2.6, 1.6), CFrame.new(0, 2.2, -2.4) * tilt, white)
			block(model, root, "Mane", Vector3.new(0.6, 2.8, 0.5), CFrame.new(0, 2.4, -1.75) * tilt, black)
			block(model, root, "Head", Vector3.new(2.2, 2, 3), CFrame.new(0, 3.7, -3.6), white)
			block(model, root, "Muzzle", Vector3.new(2, 1.4, 1), CFrame.new(0, 3.4, -5.4), muzzle)
			for _, side in { -1, 1 } do
				block(model, root, "Eye", Vector3.new(0.2, 0.6, 0.6), CFrame.new(side * 1.11, 4, -4.1), black)
				block(model, root, "Ear", Vector3.new(0.5, 1, 0.35), CFrame.new(side * 0.65, 5.1, -3), white)
			end
			block(model, root, "Tail", Vector3.new(0.4, 1.8, 0.4), CFrame.new(0, 0.2, 2.95) * CFrame.Angles(0.4, 0, 0), black)
			fourLegs(model, root, 1.4, 4, 1, 2, 0.9, white, black)
		end,
	},
	Elephant = {
		rootHeight = 5.2,
		riderOffset = 3.9,
		build = function(model, root)
			local grey, dark, tusk = Color3.fromRGB(150, 152, 162), Color3.fromRGB(110, 112, 122), Color3.fromRGB(245, 240, 225)
			block(model, root, "Body", Vector3.new(5, 4.6, 7), CFrame.new(), grey)
			block(model, root, "Head", Vector3.new(3.6, 3.4, 2.6), CFrame.new(0, 1.4, -4.6), grey)
			block(model, root, "Trunk", Vector3.new(1, 3.4, 1), CFrame.new(0, -0.4, -6.2) * CFrame.Angles(0.25, 0, 0), dark)
			for _, side in { -1, 1 } do
				block(model, root, "Ear", Vector3.new(0.4, 3.2, 2.8), CFrame.new(side * 2.2, 1.6, -4) * CFrame.Angles(0, side * 0.5, 0), dark)
				block(model, root, "Eye", Vector3.new(0.2, 0.6, 0.6), CFrame.new(side * 1.81, 2, -5.4), Color3.fromRGB(30, 30, 35))
				block(model, root, "Tusk", Vector3.new(0.35, 0.35, 1.4), CFrame.new(side * 0.9, 0.2, -6.2), tusk)
			end
			block(model, root, "Tail", Vector3.new(0.35, 2, 0.35), CFrame.new(0, 0.6, 3.6) * CFrame.Angles(0.3, 0, 0), dark)
			fourLegs(model, root, 2.3, 5.2, 1.7, 2.4, 1.6, grey, dark)
		end,
	},
	Giraffe = {
		rootHeight = 6.5,
		riderOffset = 3.1,
		build = function(model, root)
			local yellow, spot, dark = Color3.fromRGB(240, 200, 95), Color3.fromRGB(160, 100, 45), Color3.fromRGB(90, 60, 35)
			block(model, root, "Body", Vector3.new(3, 3, 5), CFrame.new(), yellow)
			for i, offset in { Vector3.new(1.51, 0.5, -1.2), Vector3.new(-1.51, -0.3, 0.4), Vector3.new(1.51, -0.4, 1.4), Vector3.new(0, 1.51, 0.8), Vector3.new(-1.51, 0.6, -1.5) } do
				local size = if math.abs(offset.Y) > 1.5 then Vector3.new(1.2, 0.1, 1.2) else Vector3.new(0.1, 1, 1.1)
				block(model, root, "Spot" .. i, size, CFrame.new(offset), spot)
			end
			local tilt = CFrame.Angles(-0.25, 0, 0)
			block(model, root, "Neck", Vector3.new(1.2, 6.4, 1.2), CFrame.new(0, 4.1, -2.4) * tilt, yellow)
			block(model, root, "Head", Vector3.new(1.4, 1.4, 2.6), CFrame.new(0, 7.4, -3.9), yellow)
			for _, side in { -1, 1 } do
				block(model, root, "Ossicone", Vector3.new(0.3, 0.9, 0.3), CFrame.new(side * 0.4, 8.4, -3.5), dark)
				block(model, root, "Eye", Vector3.new(0.2, 0.4, 0.4), CFrame.new(side * 0.71, 7.6, -4.3), Color3.fromRGB(30, 30, 35))
			end
			block(model, root, "Tail", Vector3.new(0.3, 2, 0.3), CFrame.new(0, 0, 2.6) * CFrame.Angles(0.3, 0, 0), dark)
			fourLegs(model, root, 1.5, 6.5, 0.9, 1.8, 0.7, yellow, dark)
		end,
	},
}

-- groundCFrame: point on the ground where the animal stands, facing its LookVector.
-- anchored: true for display/herd animals moved by CFrame; false when a rider is welded on.
function AnimalBuilder.build(species: string, groundCFrame: CFrame, anchored: boolean): Model
	local spec = SPECS[species]
	assert(spec, `AnimalBuilder: unknown species "{species}"`)

	local model = Instance.new("Model")
	model.Name = species
	model:SetAttribute("AnimalId", species)
	model:SetAttribute("RootHeight", spec.rootHeight)
	model:SetAttribute("RiderOffset", spec.riderOffset)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 3, 6)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Anchored = anchored
	root.RootPriority = 10
	root.CFrame = groundCFrame * CFrame.new(0, spec.rootHeight, 0)
	root.Parent = model
	model.PrimaryPart = root

	spec.build(model, root)
	return model
end

return AnimalBuilder
