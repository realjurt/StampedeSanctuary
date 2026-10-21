--!strict
-- Placeholder riding HUD: temper meter, progress, messages, leave button, end-of-run panel.

local UiKit = require(script.Parent.UiKit)

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
		leaveButton: TextButton,
		endPanel: Frame,
		againButton: TextButton,
		returnButton: TextButton,
		messageToken: number,
	},
	RideHud
))

local CALM = Color3.fromRGB(110, 200, 90)
local WARN = Color3.fromRGB(255, 170, 50)
local DANGER = Color3.fromRGB(235, 70, 60)

local function bar(parent: Instance, name: string, y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Name = name
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, y)
	back.Size = UDim2.new(0.4, 0, 0, height)
	back.BackgroundColor3 = UiKit.DARK
	back.BackgroundTransparency = 0.35
	back.Parent = parent
	UiKit.corner(back, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	UiKit.corner(fill, UDim.new(1, 0))
	return fill
end

function RideHud.new(): RideHud
	local gui = UiKit.screen("RideHud")

	local temperLabel = UiKit.label(gui, "TemperLabel", "TEMPER", 22)
	temperLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	temperLabel.Position = UDim2.new(0.5, 0, 0, 40)
	temperLabel.Size = UDim2.new(0.4, 0, 0, 24)
	local temperFill = bar(gui, "Temper", 54, 22, CALM)
	local progressFill = bar(gui, "Progress", 84, 8, Color3.fromRGB(255, 210, 70))

	local message = UiKit.label(gui, "Message", "", 64)
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.33)
	message.Size = UDim2.new(0.8, 0, 0, 80)
	message.Visible = false

	local hint = UiKit.label(gui, "Hint", "", 24)
	hint.AnchorPoint = Vector2.new(0.5, 0.5)
	hint.Position = UDim2.new(0.5, 0, 1, -50)
	hint.Size = UDim2.new(0.9, 0, 0, 30)

	local leaveButton = UiKit.button(gui, "Leave", "◀ Sanctuary", UiKit.DARK, 20)
	leaveButton.Position = UDim2.fromOffset(16, 70)
	leaveButton.Size = UDim2.fromOffset(150, 40)
	leaveButton.BackgroundTransparency = 0.3

	local endPanel = Instance.new("Frame")
	endPanel.Name = "EndPanel"
	endPanel.AnchorPoint = Vector2.new(0.5, 0)
	endPanel.Position = UDim2.fromScale(0.5, 0.45)
	endPanel.Size = UDim2.fromOffset(440, 70)
	endPanel.BackgroundTransparency = 1
	endPanel.Visible = false
	endPanel.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 20)
	layout.Parent = endPanel

	local againButton = UiKit.button(endPanel, "RideAgain", "Ride again", UiKit.GREEN, 28)
	againButton.Size = UDim2.fromOffset(200, 64)
	local returnButton = UiKit.button(endPanel, "Return", "Back to Sanctuary", Color3.fromRGB(80, 140, 210), 24)
	returnButton.Size = UDim2.fromOffset(200, 64)

	return setmetatable({
		gui = gui,
		temperLabel = temperLabel,
		temperFill = temperFill,
		progressFill = progressFill,
		message = message,
		hint = hint,
		leaveButton = leaveButton,
		endPanel = endPanel,
		againButton = againButton,
		returnButton = returnButton,
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

-- Tutorial variant of the top meter: shows befriending progress instead of temper.
function RideHud.setBefriending(self: RideHud, fraction: number, animalName: string)
	fraction = math.clamp(fraction, 0, 1)
	self.temperFill.Size = UDim2.fromScale(fraction, 1)
	self.temperFill.BackgroundColor3 = Color3.fromRGB(255, 140, 180)
	self.temperLabel.Text = string.format("BEFRIENDING %s  %d%%", string.upper(animalName), math.floor(fraction * 100 + 0.5))
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
		then "Drag left/right to steer  ·  Tap to jump"
		else "Hold A / D or ← / → to steer  ·  Space to jump"
	self.hint.Visible = true
	task.delay(duration, function()
		if self.hint.Parent then
			self.hint.Visible = false
		end
	end)
end

function RideHud.setEndPanelVisible(self: RideHud, visible: boolean)
	self.endPanel.Visible = visible
	self.leaveButton.Visible = not visible
end

function RideHud.destroy(self: RideHud)
	self.gui:Destroy()
end

return RideHud
