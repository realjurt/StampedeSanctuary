--!strict
-- Placeholder riding HUD (temper meter, progress, messages). Plain on purpose:
-- replaced by the approved ChatGPT designs in Phase 5.

local Players = game:GetService("Players")

local RideHud = {}
RideHud.__index = RideHud

export type RideHud = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		temperLabel: TextLabel,
		temperFill: Frame,
		progressFill: Frame,
		message: TextLabel,
		hint: TextLabel,
		messageToken: number,
	},
	RideHud
))

local FONT = Enum.Font.FredokaOne
local CALM = Color3.fromRGB(110, 200, 90)
local WARN = Color3.fromRGB(255, 170, 50)
local DANGER = Color3.fromRGB(235, 70, 60)

local function stroke(parent: GuiObject, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = Color3.fromRGB(30, 30, 35)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function corner(parent: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = parent
end

local function bar(parent: Instance, name: string, y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Name = name
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, y)
	back.Size = UDim2.new(0.4, 0, 0, height)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	back.BackgroundTransparency = 0.35
	back.Parent = parent
	corner(back)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill)
	return fill
end

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = position
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = ""
	l.Parent = parent
	stroke(l, 2)
	return l
end

function RideHud.new(): RideHud
	local gui = Instance.new("ScreenGui")
	gui.Name = "RideHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local temperLabel = label(gui, "TemperLabel", UDim2.new(0.5, 0, 0, 40), UDim2.new(0.4, 0, 0, 24), 22)
	temperLabel.Text = "TEMPER"
	local temperFill = bar(gui, "Temper", 54, 22, CALM)
	local progressFill = bar(gui, "Progress", 84, 8, Color3.fromRGB(255, 210, 70))

	local message = label(gui, "Message", UDim2.fromScale(0.5, 0.35), UDim2.new(0.8, 0, 0, 80), 64)
	message.Visible = false

	local hint = label(gui, "Hint", UDim2.new(0.5, 0, 1, -50), UDim2.new(0.9, 0, 0, 30), 24)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return setmetatable({
		gui = gui,
		temperLabel = temperLabel,
		temperFill = temperFill,
		progressFill = progressFill,
		message = message,
		hint = hint,
		messageToken = 0,
	}, RideHud)
end

function RideHud.setTemper(self: RideHud, fraction: number, warningAt: number)
	fraction = math.clamp(fraction, 0, 1)
	self.temperFill.Size = UDim2.fromScale(fraction, 1)
	if fraction >= 0.9 then
		self.temperFill.BackgroundColor3 = DANGER
		self.temperLabel.Text = "TEMPER — HOLD ON!"
	elseif fraction >= warningAt then
		self.temperFill.BackgroundColor3 = WARN
		self.temperLabel.Text = "TEMPER — GETTING RESTLESS"
	else
		self.temperFill.BackgroundColor3 = CALM
		self.temperLabel.Text = "TEMPER"
	end
end

function RideHud.setProgress(self: RideHud, fraction: number)
	self.progressFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

-- Shows a centered message; hides it after `duration` seconds if given.
function RideHud.showMessage(self: RideHud, text: string, duration: number?)
	self.messageToken += 1
	local token = self.messageToken
	self.message.Text = text
	self.message.Visible = true
	if duration then
		task.delay(duration, function()
			if self.messageToken == token then
				self.message.Visible = false
			end
		end)
	end
end

function RideHud.showHint(self: RideHud, isTouch: boolean, duration: number)
	self.hint.Text = if isTouch
		then "Swipe left/right to steer  ·  Tap or swipe up to jump"
		else "A / D or ← / → to steer  ·  Space to jump"
	self.hint.Visible = true
	task.delay(duration, function()
		if self.hint.Parent then
			self.hint.Visible = false
		end
	end)
end

function RideHud.destroy(self: RideHud)
	self.gui:Destroy()
end

return RideHud
