--!strict
-- Placeholder "you could ride this" marker: a glowing ring under the target animal plus its name.
-- Final visuals come from the ChatGPT UI pass (D-010).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local UiKit = require(script.Parent.UiKit)

local TargetIndicator = {}
TargetIndicator.__index = TargetIndicator

local RING_COLOR = Color3.fromRGB(255, 220, 70)

function TargetIndicator.new()
	local ring = Instance.new("Part")
	ring.Name = "TargetRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = RING_COLOR
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TargetLabel"
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Enabled = false
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = UiKit.label(billboard, "Label", "", 24)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = RING_COLOR

	local self = setmetatable({}, TargetIndicator)
	self.ring = ring
	self.billboard = billboard
	self.label = label
	return self
end

export type TargetIndicator = typeof(TargetIndicator.new())

function TargetIndicator.show(self: TargetIndicator, root: BasePart, displayName: string, radius: number, labelHeight: number)
	local position = root.Position
	local diameter = radius * 2
	self.ring.Size = Vector3.new(0.2, diameter, diameter)
	self.ring.CFrame = CFrame.new(position.X, CourseConfig.groundY + 0.12, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	self.ring.Transparency = 0.3 + math.sin(os.clock() * 8) * 0.15
	self.ring.Parent = Workspace
	self.billboard.Adornee = root
	self.billboard.StudsOffset = Vector3.new(0, labelHeight, 0)
	self.label.Text = "▼ " .. displayName
	self.billboard.Enabled = true
end

function TargetIndicator.hide(self: TargetIndicator)
	self.ring.Parent = nil
	self.billboard.Enabled = false
end

function TargetIndicator.destroy(self: TargetIndicator)
	self.ring:Destroy()
	self.billboard:Destroy()
end

return TargetIndicator
