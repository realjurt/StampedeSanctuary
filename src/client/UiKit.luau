--!strict
-- Placeholder UI building blocks. Deliberately plain: replaced by approved ChatGPT designs later (D-010).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.FONT = Enum.Font.FredokaOne
UiKit.DARK = Color3.fromRGB(30, 30, 35)
UiKit.GREEN = Color3.fromRGB(90, 190, 80)

function UiKit.corner(parent: GuiObject, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = parent
end

function UiKit.stroke(parent: GuiObject, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = UiKit.DARK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

function UiKit.screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function UiKit.label(parent: Instance, name: string, text: string, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = UiKit.FONT
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	UiKit.stroke(l, 2)
	return l
end

function UiKit.button(parent: Instance, name: string, text: string, color: Color3, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = color
	b.Font = UiKit.FONT
	b.TextSize = textSize
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	UiKit.corner(b)
	UiKit.stroke(b, 2)
	return b
end

local toastGui: ScreenGui? = nil

-- Brief message near the top of the screen.
function UiKit.toast(text: string, duration: number?)
	if not toastGui then
		toastGui = UiKit.screen("Toasts", 10)
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 110)
	frame.Size = UDim2.fromOffset(460, 54)
	frame.BackgroundColor3 = UiKit.DARK
	frame.BackgroundTransparency = 0.2
	frame.Parent = toastGui
	UiKit.corner(frame)

	local label = UiKit.label(frame, "Text", text, 24)
	label.Size = UDim2.fromScale(1, 1)

	task.delay(duration or 3, function()
		local tween = TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		tween:Play()
		tween.Completed:Wait()
		frame:Destroy()
	end)
end

return UiKit
