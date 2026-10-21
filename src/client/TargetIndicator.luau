--!strict
-- Placeholder "you can leap onto this" marker: the target animal glows, with a ring underneath and a
-- label naming it and the button. Final visuals come from the ChatGPT UI pass (D-010).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local UiKit = require(script.Parent.UiKit)

local TargetIndicator = {}
TargetIndicator.__index = TargetIndicator

local TARGET_COLOR = Color3.fromRGB(255, 220, 70)

function TargetIndicator.new()
	local ring = Instance.new("Part")
	ring.Name = "TargetRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = TARGET_COLOR
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false

	local highlight = Instance.new("Highlight")
	highlight.Name = "TargetHighlight"
	highlight.FillColor = TARGET_COLOR
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TargetLabel"
	billboard.Size = UDim2.fromOffset(260, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Enabled = false
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = UiKit.label(billboard, "Label", "", 24)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = TARGET_COLOR

	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local self = setmetatable({}, TargetIndicator)
	self.ring = ring
	self.highlight = highlight
	self.billboard = billboard
	self.label = label
	self.buttonText = if isTouch then "LEAP" else "F to leap"
	return self
end

export type TargetIndicator = typeof(TargetIndicator.new())

function TargetIndicator.show(self: TargetIndicator, model: Model, displayName: string, radius: number, labelHeight: number)
	local root = model.PrimaryPart :: BasePart
	local position = root.Position
	local diameter = radius * 2
	self.ring.Size = Vector3.new(0.2, diameter, diameter)
	self.ring.CFrame = CFrame.new(position.X, CourseConfig.groundY + 0.12, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	self.ring.Transparency = 0.3 + math.sin(os.clock() * 8) * 0.15
	self.ring.Parent = Workspace
	if self.highlight.Parent ~= model then
		self.highlight.Parent = model
	end
	self.highlight.FillTransparency = 0.5 + math.sin(os.clock() * 8) * 0.1
	self.billboard.Adornee = root
	self.billboard.StudsOffset = Vector3.new(0, labelHeight, 0)
	self.label.Text = `▼ {displayName} — {self.buttonText}`
	self.billboard.Enabled = true
end

function TargetIndicator.hide(self: TargetIndicator)
	self.ring.Parent = nil
	self.highlight.Parent = nil
	self.billboard.Enabled = false
end

function TargetIndicator.destroy(self: TargetIndicator)
	self.ring:Destroy()
	self.highlight:Destroy()
	self.billboard:Destroy()
end

return TargetIndicator
