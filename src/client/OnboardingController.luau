--!strict
-- Sanctuary-side onboarding: short intro card for new players, a goal line, an arrow to the
-- Safari Gate, and the gate's Skip Tutorial prompt shown only to players who can use it.
-- Nothing here ever starts a safari — the player chooses via the gate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UiKit = require(script.Parent.UiKit)

local OnboardingController = {}

local player = Players.LocalPlayer

local function flag(name: string): boolean
	return player:GetAttribute(name) == true
end

local function isNewPlayer(): boolean
	return not flag("TutorialCompleted") and not flag("OnboardingDismissed") and not flag("StarterZebraUnlocked")
end

local function canSkip(): boolean
	return not flag("TutorialCompleted") and not flag("OnboardingDismissed")
end

local function goalText(): string
	if flag("StarterZebraUnlocked") then
		return "Goal: Ride the safari and discover new animals"
	end
	return "Goal: Enter the Safari Gate to find your first animal"
end

local function buildIntroCard(gui: ScreenGui, onGo: () -> (), onSkip: () -> ()): Frame
	local card = Instance.new("Frame")
	card.Name = "IntroCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(520, 300)
	card.BackgroundColor3 = UiKit.DARK
	card.BackgroundTransparency = 0.15
	card.Parent = gui
	UiKit.corner(card, UDim.new(0, 20))
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(520, 300)
	constraint.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = math.min(1, (Workspace.CurrentCamera.ViewportSize.X - 32) / 520)
	scale.Parent = card

	local title = UiKit.label(card, "Title", "Welcome to your Sanctuary!", 36)
	title.Position = UDim2.fromOffset(20, 18)
	title.Size = UDim2.new(1, -40, 0, 44)

	local body = UiKit.label(card, "Body", "Ride wild animals, discover new species, and build your own animal sanctuary.", 24)
	body.Position = UDim2.fromOffset(30, 72)
	body.Size = UDim2.new(1, -60, 0, 90)

	local go = UiKit.button(card, "Go", "Let's go!", UiKit.GREEN, 32)
	go.AnchorPoint = Vector2.new(0.5, 0)
	go.Position = UDim2.new(0.5, 0, 0, 176)
	go.Size = UDim2.fromOffset(240, 64)
	go.Activated:Connect(onGo)

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(0.5, 0)
	skip.Position = UDim2.new(0.5, 0, 0, 252)
	skip.Size = UDim2.fromOffset(200, 28)
	skip.BackgroundTransparency = 1
	skip.Font = UiKit.FONT
	skip.TextSize = 18
	skip.TextColor3 = Color3.fromRGB(190, 190, 195)
	skip.Text = "Skip tutorial"
	skip.Parent = card
	skip.Activated:Connect(onSkip)
	return card
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
	local goal = UiKit.label(gui, "Goal", goalText(), 22)
	goal.AnchorPoint = Vector2.new(0, 0)
	goal.Position = UDim2.fromOffset(16, 70)
	goal.Size = UDim2.fromOffset(0, 30)
	goal.AutomaticSize = Enum.AutomaticSize.X
	goal.TextWrapped = false
	goal.TextXAlignment = Enum.TextXAlignment.Left

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
		skipPrompt.Enabled = canSkip()
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
