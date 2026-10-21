--!strict
-- Animal Index (UI-2), laid out like the reference Pet Index: biome banner, card grid in a dark
-- inset, detail panel, and a collection bar. Discovered animals render in color in a ViewportFrame;
-- undiscovered ones as black silhouettes with "???". Stats come from AnimalConfig. Rarity is blank
-- until it is designed (D-022).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalBuilder = require(ReplicatedStorage.Shared.Animals.AnimalBuilder)
local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local UiKit = require(script.Parent.UiKit)

local AnimalIndex = {}

local SPECIES = { "Zebra", "Giraffe", "Elephant" }
local player = Players.LocalPlayer

local function discoveredSet(): { [string]: boolean }
	local set = {}
	local raw = player:GetAttribute("Discovered")
	if typeof(raw) == "string" then
		for species in string.gmatch(raw, "[^,]+") do
			set[species] = true
		end
	end
	return set
end

-- 3D portrait of the placeholder model; silhouette = viewport tinted black.
local function portrait(parent: Instance, species: string, size: UDim2, position: UDim2): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = size
	viewport.Position = position
	viewport.ZIndex = 4
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -0.5)
	viewport.Parent = parent
	local model = AnimalBuilder.build(species, CFrame.new(), true)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local center, extents = model:GetBoundingBox()
	local distance = extents.Magnitude * 1.25
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(-0.75, 0.3, -0.6).Unit * distance, center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function smallLabel(parent: Instance, name: string, text: string, size: number, y: number, height: number): TextLabel
	local l = UiKit.label(parent, name, text, size)
	l.Position = UDim2.fromOffset(6, y)
	l.Size = UDim2.new(1, -12, 0, height)
	return l
end

local function statRow(parent: Instance, y: number, text: string): (Frame, UiKit.Bar)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(8, y)
	holder.Size = UDim2.new(1, -16, 0, 18)
	holder.Parent = parent
	local l = UiKit.label(holder, "Name", text, 14)
	l.Size = UDim2.fromOffset(52, 18)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local bar = UiKit.bar(holder, "Bar", UiKit.verticalSequence("green"), 1)
	bar.frame.Position = UDim2.fromOffset(56, 2)
	bar.frame.Size = UDim2.new(1, -56, 0, 14)
	bar.label.Visible = false
	return holder, bar
end

function AnimalIndex.build(window: UiKit.Window)
	local body = window.body

	-- Biome banner
	local banner = Instance.new("Frame")
	banner.Name = "Biome"
	banner.Size = UDim2.fromOffset(150, 300)
	banner.Parent = body
	UiKit.surface(banner, "cyan", 6, 3, false)
	local grass = Instance.new("Frame")
	grass.BackgroundColor3 = Color3.new(1, 1, 1)
	grass.Position = UDim2.fromScale(0, 0.58)
	grass.Size = UDim2.fromScale(1, 0.42)
	grass.ZIndex = 2
	grass.Parent = banner
	UiKit.corner(grass, UDim.new(0, 6))
	local grassFill = Instance.new("UIGradient")
	grassFill.Color = ColorSequence.new(Color3.fromRGB(150, 220, 70), Color3.fromRGB(60, 150, 40))
	grassFill.Rotation = 90
	grassFill.Parent = grass
	local tree = Instance.new("TextLabel")
	tree.BackgroundTransparency = 1
	tree.Position = UDim2.fromScale(0.1, 0.42)
	tree.Size = UDim2.fromScale(0.8, 0.3)
	tree.Text = "🌳🦓🌳"
	tree.TextScaled = true
	tree.ZIndex = 3
	tree.Parent = banner
	local bannerTitle = UiKit.label(banner, "Title", "Savannah", 26)
	bannerTitle.Position = UDim2.fromOffset(0, 10)
	bannerTitle.Size = UDim2.new(1, 0, 0, 34)

	-- Card grid
	local grid = UiKit.inset(body, "Grid")
	grid.Position = UDim2.fromOffset(162, 0)
	grid.Size = UDim2.fromOffset(380, 300)
	local hint = UiKit.label(grid, "Hint", "Ride the safari and leap onto wild animals to meet them!", 16)
	hint.TextColor3 = UiKit.QUIET
	hint.Position = UDim2.fromOffset(16, 160)
	hint.Size = UDim2.new(1, -32, 0, 60)
	local areaBar = UiKit.bar(grid, "Area", UiKit.verticalSequence("green"), 24)
	areaBar.frame.Position = UDim2.fromOffset(12, 250)
	areaBar.frame.Size = UDim2.new(1, -24, 0, 38)

	-- Detail panel
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.Position = UDim2.fromOffset(554, 0)
	detail.Size = UDim2.fromOffset(194, 300)
	detail.Parent = body
	UiKit.surface(detail, Color3.fromRGB(96, 98, 110), 6, 3, false)
	local detailName = smallLabel(detail, "Name", "", 24, 140, 30)
	local detailRarity = smallLabel(detail, "Rarity", "Rarity: —", 16, 170, 20)
	detailRarity.TextColor3 = UiKit.QUIET
	local detailAbility = smallLabel(detail, "Ability", "", 14, 192, 34)
	local statBars: { UiKit.Bar } = {}
	for i, statName in { "Speed", "Steer", "Jump" } do
		local _, bar = statRow(detail, 228 + (i - 1) * 22, statName)
		statBars[i] = bar
	end
	local detailPortrait: ViewportFrame? = nil

	-- Collection bar
	local book = Instance.new("TextLabel")
	book.BackgroundTransparency = 1
	book.Position = UDim2.fromOffset(0, 312)
	book.Size = UDim2.fromOffset(50, 48)
	book.Text = "📘"
	book.TextSize = 40
	book.Parent = body
	local collection = UiKit.bar(body, "Collection", UiKit.verticalSequence("cyan"), 28)
	collection.frame.Position = UDim2.fromOffset(56, 316)
	collection.frame.Size = UDim2.fromOffset(692, 42)

	local cards: { [string]: TextButton } = {}
	local selected = SPECIES[1]

	local function showDetail(species: string, known: boolean)
		local stats = AnimalConfig[species]
		if detailPortrait then
			detailPortrait:Destroy()
		end
		local view = portrait(detail, species, UDim2.new(1, -16, 0, 128), UDim2.fromOffset(8, 8))
		view.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		detailPortrait = view
		detailName.Text = if known then stats.displayName else "???"
		local ability = string.match(stats.abilityHint, "—%s*(.+)$") or ""
		detailAbility.Text = if known then string.upper(string.sub(ability, 1, 1)) .. string.sub(ability, 2) else "???"
		local values = { stats.cruiseSpeed / 55, stats.maxSteerSpeed / 36, stats.jumpHeight / 10 }
		for i, bar in statBars do
			bar.set(if known then values[i] else 0)
		end
	end

	local function refresh()
		local found = discoveredSet()
		local count = 0
		for i, species in SPECIES do
			local known = found[species] == true
			if known then
				count += 1
			end
			local card = cards[species]
			if card then
				card:Destroy()
			end
			local style = UiKit.SPECIES[species]
			card = Instance.new("TextButton")
			card.Name = species
			card.Text = ""
			card.AutoButtonColor = false
			card.Position = UDim2.fromOffset(14 + (i - 1) * 120, 14)
			card.Size = UDim2.fromOffset(110, 130)
			card.Parent = grid
			UiKit.surface(card, style.color, 6, 3)
			local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
			if species == selected then
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Thickness = 4
			end
			local title = smallLabel(card, "Name", if known then species else "???", 18, 4, 22)
			title.ZIndex = 5
			local view = portrait(card, species, UDim2.new(1, -10, 0, 96), UDim2.fromOffset(5, 28))
			view.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			card.Activated:Connect(function()
				selected = species
				refresh()
			end)
			cards[species] = card
		end
		areaBar.set(count / #SPECIES, `{count}/{#SPECIES}`)
		collection.set(count / #SPECIES, `Discovered: {count}/{#SPECIES}`)
		showDetail(selected, found[selected] == true)
	end

	player:GetAttributeChangedSignal("Discovered"):Connect(refresh)
	refresh()
end

return AnimalIndex
