--!strict
-- Shows this player's own sanctuary contents locally (the sanctuary hub is shared by everyone):
-- the habitat sign and a placeholder zebra that pops in once StarterZebraUnlocked is set.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SanctuaryConfig = require(ReplicatedStorage.Shared.Config.SanctuaryConfig)
local ZebraBuilder = require(ReplicatedStorage.Shared.Animals.ZebraBuilder)
local UiKit = require(script.Parent.UiKit)

local SanctuaryView = {}

local player = Players.LocalPlayer

local function habitatCFrame(): CFrame
	local origin = SanctuaryConfig.origin
	local offset = SanctuaryConfig.habitatOffset
	-- Face the path (toward -X) so the player sees the zebra from the side.
	return CFrame.new(origin.X + offset.X, SanctuaryConfig.groundY + 0.15, origin.Z + offset.Z) * CFrame.Angles(0, math.rad(90), 0)
end

local function spawnZebra(animate: boolean)
	local base = habitatCFrame()
	local zebra = ZebraBuilder.build(base)
	zebra.Name = "MyHabitatZebra"
	zebra.Parent = Workspace

	if animate then
		local scale = Instance.new("NumberValue")
		scale.Value = 0.05
		zebra:ScaleTo(scale.Value)
		scale.Changed:Connect(function(value)
			if zebra.Parent then
				zebra:ScaleTo(math.max(value, 0.05))
			end
		end)
		local tween = TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			scale:Destroy()
		end)
	end

	-- Gentle idle: slow look-around and breathing bob, relative to the zebra's current scale.
	local pivotStart = zebra:GetPivot()
	local offsetFromBase = base:ToObjectSpace(pivotStart)
	RunService.Heartbeat:Connect(function()
		if not zebra.Parent then
			return
		end
		local t = os.clock()
		local turn = CFrame.Angles(0, math.sin(t * 0.35) * 0.6, 0)
		local bob = CFrame.new(0, math.sin(t * 2) * 0.08 * zebra:GetScale(), 0)
		zebra:PivotTo(base * turn * bob * offsetFromBase)
	end)
end

-- Translucent "who will live here?" zebra plus a floating question mark for the empty habitat.
local function spawnGhost(): Model
	local ghost = ZebraBuilder.build(habitatCFrame())
	ghost.Name = "HabitatGhost"
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			part.Color = Color3.fromRGB(200, 200, 210)
			part.Transparency = 0.7
		end
	end
	ghost.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 80)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.Adornee = ghost.PrimaryPart
	billboard.Parent = ghost
	local mark = UiKit.label(billboard, "Mark", "?", 64)
	mark.Size = UDim2.fromScale(1, 1)
	mark.TextColor3 = Color3.fromRGB(255, 215, 80)
	return ghost
end

function SanctuaryView.start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local sanctuary = Workspace:WaitForChild("Sanctuary")
	local signPart = sanctuary:WaitForChild("HabitatSign")
	local signText = signPart:WaitForChild("Sign"):WaitForChild("Text") :: TextLabel

	local shown = false
	local ghost: Model? = nil
	-- `animate` is true when the unlock happens this session; the pop-in waits until the player
	-- is back in the sanctuary so they actually see their zebra arrive.
	local function refresh(animate: boolean)
		local unlocked = player:GetAttribute("StarterZebraUnlocked") == true
		local away = player:GetAttribute("InSafari") == true
		signText.Text = if unlocked then "ZEBRA HABITAT\nHome of your Zebra!" else "ZEBRA HABITAT\nEmpty — befriend a wild zebra on safari!"
		if not unlocked and not ghost then
			ghost = spawnGhost()
		elseif unlocked and not shown and not away then
			shown = true
			if ghost then
				ghost:Destroy()
				ghost = nil
			end
			spawnZebra(animate)
			if animate then
				UiKit.toast("Your zebra is home!", 4)
			end
		end
	end

	player:GetAttributeChangedSignal("StarterZebraUnlocked"):Connect(function()
		refresh(true)
	end)
	player:GetAttributeChangedSignal("InSafari"):Connect(function()
		refresh(true)
	end)
	refresh(false)
end

return SanctuaryView
