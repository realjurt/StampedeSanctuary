--!strict
-- Sanctuary-side onboarding: short intro card for new players, a goal line, an arrow to the
-- Safari Gate, and the gate's Skip Tutorial prompt shown only to players who can use it.
-- Nothing here ever starts a safari — the player chooses via the gate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MenuController = require(script.Parent.MenuController)
local UiKit = require(script.Parent.UiKit)

local OnboardingController = {}

local player = Players.LocalPlayer

local function flag(name: string): boolean
	return player:GetAttribute(name) == true
end

local function isNewPlayer(): boolean
	return not flag("TutorialCompleted") and not flag("OnboardingDismissed") and not flag("StarterZebraUnlocked")
end

local function tutorialIsNext(): boolean
	return not flag("TutorialCompleted") and not flag("OnboardingDismissed")
end

local function goalText(): string
	if flag("StarterZebraUnlocked") then
		return "Goal: Ride the safari and discover new animals"
	end
	return "▶ 1. Enter the Safari Gate\n    2. Befriend a wild zebra\n    3. Bring it home to your empty habitat"
end

-- Welcome window (D-022 style). Returns the window's holder frame, which closes by destroying it.
local function buildIntroCard(gui: ScreenGui, onGo: () -> (), onSkip: () -> ()): Frame
	local window = UiKit.window(gui, "Welcome!", "green", Vector2.new(540, 330), false)
	window.holder.Name = "IntroCard"
	local body = window.body

	local text = UiKit.label(body, "Body", "Ride wild animals, befriend them, and bring them home. Your first habitat is empty — let's find it a zebra!", 24)
	text.Size = UDim2.new(1, 0, 0, 104)

	local go = UiKit.button(body, "Go", "Let's go!", "green", 32)
	go.AnchorPoint = Vector2.new(0.5, 0)
	go.Position = UDim2.new(0.5, 0, 0, 118)
	go.Size = UDim2.fromOffset(250, 64)
	go.Activated:Connect(onGo)

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(0.5, 0)
	skip.Position = UDim2.new(0.5, 0, 0, 196)
	skip.Size = UDim2.fromOffset(200, 26)
	skip.BackgroundTransparency = 1
	skip.Font = UiKit.FONT
	skip.TextSize = 18
	skip.TextColor3 = UiKit.QUIET
	skip.Text = "Skip tutorial"
	skip.Parent = body
	skip.Activated:Connect(onSkip)

	window.open()
	return window.holder
end

local function buildSideMenu(gui: ScreenGui)
	local nav = Instance.new("Frame")
	nav.Name = "Menu"
	nav.BackgroundTransparency = 1
	nav.AnchorPoint = Vector2.new(0, 0.5)
	nav.Position = UDim2.new(0, 14, 0.5, 0)
	nav.Size = UDim2.fromOffset(160, 164)
	nav.Parent = gui
	UiKit.autoScale(nav)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = nav
	local buttons = {
		Index = UiKit.sideButton(nav, "Index", "📖", "Index", "cyan"),
		Shop = UiKit.sideButton(nav, "Shop", "🛍️", "Shop", "pink"),
		Settings = UiKit.sideButton(nav, "Settings", "⚙️", "Settings", "gray"),
	}
	buttons.Index.LayoutOrder, buttons.Shop.LayoutOrder, buttons.Settings.LayoutOrder = 1, 2, 3
	MenuController.bind(buttons)
end

local function buildGateArrow(anchor: BasePart): (BillboardGui, RBXScriptConnection)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GateArrow"
	billboard.Size = UDim2.fromOffset(160, 110)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = anchor
	billboard.Parent = player:WaitForChild("PlayerGui")

	local arrow = UiKit.label(billboard, "Arrow", "SAFARI\n▼", 34)
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.TextColor3 = Color3.fromRGB(255, 215, 80)

	local bounce = RunService.RenderStepped:Connect(function()
		billboard.StudsOffset = Vector3.new(0, 9 + math.sin(os.clock() * 4) * 0.8, 0)
	end)
	return billboard, bounce
end

function OnboardingController.start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local sanctuary = Workspace:WaitForChild("Sanctuary")
	local anchor = sanctuary:WaitForChild("GatePromptAnchor") :: BasePart
	local skipPrompt = anchor:WaitForChild("SkipPrompt") :: ProximityPrompt
	local skipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkipTutorial") :: RemoteEvent

	local gui = UiKit.screen("SanctuaryHud")
	buildSideMenu(gui)
	local goal = UiKit.label(gui, "Goal", goalText(), 22)
	goal.AnchorPoint = Vector2.new(0, 0)
	goal.Position = UDim2.fromOffset(16, 70)
	goal.Size = UDim2.fromOffset(0, 30)
	goal.AutomaticSize = Enum.AutomaticSize.XY
	goal.TextWrapped = false
	goal.TextXAlignment = Enum.TextXAlignment.Left
	goal.TextYAlignment = Enum.TextYAlignment.Top
	local startPrompt = anchor:WaitForChild("StartPrompt") :: ProximityPrompt

	local arrow: BillboardGui? = nil
	local bounce: RBXScriptConnection? = nil
	local card: Frame? = nil
	local function refresh()
		goal.Text = goalText()
		-- The intro has done its job once the player skips (by any route) or heads out on safari.
		if card and (not isNewPlayer() or flag("InSafari")) then
			card:Destroy()
			card = nil
		end
		-- Client-side only: hides the prompt for players who can't use it (the server re-checks anyway).
		skipPrompt.Enabled = tutorialIsNext()
		startPrompt.ActionText = if tutorialIsNext() then "Start Tutorial Safari" else "Start Safari"
		startPrompt.ObjectText = if tutorialIsNext() then "Befriend your first zebra" else "Safari Gate"
		local wantArrow = not flag("StarterZebraUnlocked") and not flag("InSafari")
		if wantArrow and not arrow then
			arrow, bounce = buildGateArrow(anchor)
		elseif not wantArrow and arrow then
			arrow:Destroy();
			(bounce :: RBXScriptConnection):Disconnect()
			arrow, bounce = nil, nil
		end
		gui.Enabled = not flag("InSafari")
	end

	for _, name in { "TutorialCompleted", "OnboardingDismissed", "StarterZebraUnlocked", "InSafari" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	if player:GetAttribute("DataSaveDisabled") == true then
		UiKit.toast("Progress can't be saved right now", 5)
	end

	if isNewPlayer() then
		local function close()
			if card then
				card:Destroy()
				card = nil
			end
		end
		card = buildIntroCard(gui, function()
			close()
			UiKit.toast("Head to the Safari Gate!", 3)
		end, function()
			close()
			skipRemote:FireServer()
		end)
	else
		UiKit.toast("Welcome back!", 3)
	end
end

return OnboardingController
