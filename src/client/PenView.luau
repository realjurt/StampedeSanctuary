--!strict
-- Pen presentation (P3, D-025). The server owns the pen animals and all data; this module only:
--   • shows the deposit prompt on this player's own pen (hidden on everyone else's),
--   • pops in freshly deposited animals with a "+$X/s" tag and idles every pen animal,
--   • shows the deposit confirmation card and "+$N" income pops over the player's own pen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local UiKit = require(script.Parent.UiKit)

local PenView = {}

local player = Players.LocalPlayer

local REJECTION_TEXT: { [string]: string } = {
	notOwner = "That's not your pen!",
	notLoaded = "Still loading your sanctuary…",
	onSafari = "Finish your safari first!",
	tooFar = "Get closer — walk up to your pen!",
	nothingCarried = "Tame animals on safari, then bring them here!",
	full = `Your pen is full! ({EconomyConfig.penCapacity}/{EconomyConfig.penCapacity})`,
}

type Idler = { model: Model, base: CFrame, phase: number }
local idlers: { [Model]: Idler } = {}

-- Floating text that rises and fades, then cleans itself up.
local function floatText(adornee: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = true
	billboard.Adornee = adornee
	billboard.Parent = player:WaitForChild("PlayerGui")
	local label = UiKit.label(billboard, "Text", text, 30)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = color
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, height + 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
	task.delay(1.25, function()
		billboard:Destroy()
	end)
end

-- Grows the animal from nothing with a bounce, then shows its income.
local function reveal(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local scale = Instance.new("NumberValue")
	scale.Value = 0.05
	model:ScaleTo(scale.Value)
	scale.Changed:Connect(function(value)
		if model.Parent then
			model:ScaleTo(math.max(value, 0.05))
		end
	end)
	local tween = TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
	tween.Completed:Connect(function()
		scale:Destroy()
	end)
	tween:Play()
	local income = model:GetAttribute("Income")
	local rootHeight = model:GetAttribute("RootHeight")
	floatText(root, `+${income}/s`, UiKit.PALETTE.green.top, (if typeof(rootHeight) == "number" then rootHeight else 3) + 4)
end

local function track(model: Model)
	if not model:IsA("Model") then
		return
	end
	idlers[model] = { model = model, base = model:GetPivot(), phase = math.random() * 10 }
	if model:GetAttribute("Fresh") == true then
		reveal(model)
	end
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			idlers[model] = nil
		end
	end)
end

local function watchPlot(plot: Instance)
	local folder = plot:WaitForChild("PenAnimals")
	for _, child in folder:GetChildren() do
		track(child :: Model)
	end
	folder.ChildAdded:Connect(function(child)
		track(child :: Model)
	end)
end

-- Big centred confirmation in the reference style.
local function showConfirmation(count: number, added: number, total: number)
	local gui = UiKit.screen("DepositConfirm", 20)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 215) -- below toasts
	card.Size = UDim2.fromOffset(440, 118)
	card.Parent = gui
	UiKit.surface(card, "green", 12, 4)
	UiKit.autoScale(card)
	local title = UiKit.label(card, "Title", if count == 1 then "1 ANIMAL DEPOSITED!" else `{count} ANIMALS DEPOSITED!`, 36)
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 50)
	local detail = UiKit.label(card, "Detail", `+${added}/s  ·  Pen total ${total}/s`, 24)
	detail.Position = UDim2.fromOffset(0, 64)
	detail.Size = UDim2.new(1, 0, 0, 36)
	detail.TextColor3 = UiKit.PALETTE.yellow.top
	UiKit.popIn(card)
	local hold = count * EconomyConfig.depositRevealInterval + 1.8
	task.delay(hold, function()
		UiKit.popOut(card)
		task.delay(0.2, function()
			gui:Destroy()
		end)
	end)
end

-- Own pen: the prompt is visible only while carrying animals and not on safari; others' are hidden.
local function bindPrompts(plots: Instance, myPlotId: number?)
	for _, plot in plots:GetChildren() do
		local prompt = plot:WaitForChild("PenGround"):WaitForChild("DepositPrompt") :: ProximityPrompt
		if plot:GetAttribute("PlotId") ~= myPlotId then
			prompt.Enabled = false
			continue
		end
		local function refresh()
			local carried = player:GetAttribute("CarriedCount")
			local count = if typeof(carried) == "number" then carried else 0
			local inPen = plot:GetAttribute("PenCount")
			local penCount = if typeof(inPen) == "number" then inPen else 0
			prompt.Enabled = count > 0 and player:GetAttribute("InSafari") ~= true
			prompt.ActionText = if count == 1 then "Deposit 1 animal" else `Deposit {count} animals`
			prompt.ObjectText = `Your pen {penCount}/{EconomyConfig.penCapacity}`
		end
		player:GetAttributeChangedSignal("CarriedCount"):Connect(refresh)
		player:GetAttributeChangedSignal("InSafari"):Connect(refresh)
		plot:GetAttributeChangedSignal("PenCount"):Connect(refresh)
		refresh()
	end
end

function PenView.start()
	-- Connect remotes first so early income ticks aren't dropped while data loads.
	local penGround: BasePart? = nil
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local result = remotes:WaitForChild("DepositResult") :: RemoteEvent
	result.OnClientEvent:Connect(function(ok: boolean, countOrReason: any, added: number?, total: number?)
		if ok then
			showConfirmation(countOrReason, added or 0, total or 0)
		elseif REJECTION_TEXT[countOrReason] then
			UiKit.toast(REJECTION_TEXT[countOrReason], 3)
		end
	end)
	local incomeTick = remotes:WaitForChild("IncomeTick") :: UnreliableRemoteEvent
	incomeTick.OnClientEvent:Connect(function(amount: number)
		if penGround and typeof(amount) == "number" then
			floatText(penGround, `+${amount}`, UiKit.PALETTE.yellow.top, 7)
		end
	end)

	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	local plots = Workspace:WaitForChild("Sanctuary"):WaitForChild("Plots")
	local plotId = player:GetAttribute("PlotId")
	local myPlotId = if typeof(plotId) == "number" then plotId else nil
	bindPrompts(plots, myPlotId)
	for _, plot in plots:GetChildren() do
		task.spawn(watchPlot, plot)
	end

	-- Gentle idle for every pen animal: slow look-around plus a breathing bob.
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for model, idler in idlers do
			local turn = CFrame.Angles(0, math.sin(t * 0.4 + idler.phase) * 0.35, 0)
			local bob = CFrame.new(0, math.sin(t * 2 + idler.phase) * 0.06 * model:GetScale(), 0)
			model:PivotTo(idler.base * bob * turn)
		end
	end)

	if myPlotId then
		penGround = plots:WaitForChild(`Plot{myPlotId}`):WaitForChild("PenGround") :: BasePart
	end
end

return PenView
