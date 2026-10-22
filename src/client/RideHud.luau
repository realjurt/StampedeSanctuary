--!strict
-- Safari HUD in the Outlined Radiance style (D-022). Layout keeps the centre of the screen clear:
-- animal + grip + distance + ability (+ tame bar while taming) top-centre, menu buttons left, control hints bottom-left,
-- leap target chip bottom-centre, mobile JUMP/LEAP bottom-right.

local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)

local RideHud = {}
RideHud.__index = RideHud

-- Grip drains right-to-left, so the low end (left) is red and a full bar ends in green (D-024).
local GRIP_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, UiKit.PALETTE.red.top),
	ColorSequenceKeypoint.new(0.38, UiKit.PALETTE.yellow.top),
	ColorSequenceKeypoint.new(1, UiKit.PALETTE.green.top),
})
local TAME_COLORS = UiKit.verticalSequence("pink")

type InputKind = "keyboard" | "gamepad" | "touch"

local HINTS: { [InputKind]: { { keys: { string }, text: string } } } = {
	keyboard = { { keys = { "A", "D" }, text = "Steer" }, { keys = { "Space" }, text = "Jump" }, { keys = { "F" }, text = "Leap" } },
	gamepad = { { keys = { "LS" }, text = "Steer" }, { keys = { "A" }, text = "Jump" }, { keys = { "X" }, text = "Leap" } },
	touch = {},
}
local LEAP_KEY: { [InputKind]: string? } = { keyboard = "F", gamepad = "X", touch = nil }

local function inputKind(): InputKind
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif last.Name:find("Gamepad") then
		return "gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	return "keyboard"
end

local function container(parent: Instance, name: string, anchor: Vector2, position: UDim2, size: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.Parent = parent
	UiKit.autoScale(f)
	return f
end

local function row(parent: Instance, name: string, padding: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = f
	return f
end

local function autoLabel(parent: Instance, name: string, text: string, size: number): TextLabel
	local l = UiKit.label(parent, name, text, size)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	l.TextWrapped = false
	return l
end

function RideHud.new()
	local gui = UiKit.screen("RideHud")
	local self = setmetatable({}, RideHud)
	self.gui = gui
	self.connections = {} :: { RBXScriptConnection }
	self.messageToken = 0
	self.befriending = false
	self.leapReady = nil :: boolean?
	self.leapTargetName = nil :: string?

	-- Top-centre: current animal, grip, distance, ability, tame progress
	local top = container(gui, "Status", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 10), Vector2.new(460, 186))
	local animalRow = row(top, "Animal", 10)
	animalRow.AnchorPoint = Vector2.new(0.5, 0)
	animalRow.Position = UDim2.fromScale(0.5, 0)
	animalRow.Size = UDim2.fromOffset(0, 40)
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Size = UDim2.fromOffset(40, 40)
	tile.Parent = animalRow
	UiKit.surface(tile, "cyan", 8, 3)
	local tileIcon = Instance.new("TextLabel")
	tileIcon.BackgroundTransparency = 1
	tileIcon.Size = UDim2.fromScale(1, 1)
	tileIcon.TextSize = 26
	tileIcon.ZIndex = 4
	tileIcon.Parent = tile
	self.animalTile = tile
	self.animalIcon = tileIcon
	self.animalName = autoLabel(animalRow, "Name", "", 30)

	local temper = UiKit.bar(top, "Grip", GRIP_COLORS, 18)
	temper.frame.Position = UDim2.fromOffset(0, 48)
	temper.frame.Size = UDim2.fromOffset(460, 32)
	self.temper = temper

	local distance = UiKit.bar(top, "Distance", UiKit.verticalSequence("cyan"), 14)
	distance.frame.Position = UDim2.fromOffset(0, 88)
	distance.frame.Size = UDim2.fromOffset(460, 20)
	self.distance = distance

	local ability = Instance.new("Frame")
	ability.Name = "Ability"
	ability.AnchorPoint = Vector2.new(0.5, 0)
	ability.Position = UDim2.new(0.5, 0, 0, 116)
	ability.AutomaticSize = Enum.AutomaticSize.X
	ability.Size = UDim2.fromOffset(0, 30)
	ability.BackgroundTransparency = 1 -- floating outlined text, like the reference HUD
	ability.Parent = top
	local abilityPadding = Instance.new("UIPadding")
	abilityPadding.PaddingLeft = UDim.new(0, 12)
	abilityPadding.PaddingRight = UDim.new(0, 12)
	abilityPadding.Parent = ability
	self.ability = autoLabel(ability, "Text", "", 22)
	self.ability.TextColor3 = UiKit.PALETTE.yellow.top

	local tame = UiKit.bar(top, "Tame", TAME_COLORS, 16)
	tame.frame.AnchorPoint = Vector2.new(0.5, 0)
	tame.frame.Position = UDim2.new(0.5, 0, 0, 152)
	tame.frame.Size = UDim2.fromOffset(340, 28)
	tame.frame.Visible = false
	self.tame = tame

	-- Left: menu buttons
	local nav = container(gui, "Menu", Vector2.new(0, 0.5), UDim2.new(0, 14, 0.5, 0), Vector2.new(160, 222))
	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 10)
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Parent = nav
	self.leaveButton = UiKit.sideButton(nav, "Sanctuary", "🏠", "Sanctuary", "green")
	self.indexButton = UiKit.sideButton(nav, "Index", "📖", "Index", "cyan")
	self.shopButton = UiKit.sideButton(nav, "Shop", "🛍️", "Shop", "pink")
	self.settingsButton = UiKit.sideButton(nav, "Settings", "⚙️", "Settings", "gray")
	for i, b in { self.leaveButton, self.indexButton, self.shopButton, self.settingsButton } do
		b.LayoutOrder = i
	end

	-- Bottom-left: control hints for the active input device
	local hints = container(gui, "Hints", Vector2.new(0, 1), UDim2.new(0, 14, 1, -14), Vector2.new(620, 30))
	self.hints = row(hints, "Row", 18)
	self.hints.Size = UDim2.fromOffset(0, 30)

	-- Bottom-centre: leap target
	local targetHolder = container(gui, "Target", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -86), Vector2.new(10, 46))
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.fromScale(0.5, 0)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 46)
	chip.BackgroundColor3 = UiKit.PANEL
	chip.Visible = false
	chip.Parent = targetHolder
	UiKit.corner(chip, UDim.new(0, 8))
	UiKit.border(chip, 3)
	local chipPadding = Instance.new("UIPadding")
	chipPadding.PaddingLeft = UDim.new(0, 14)
	chipPadding.PaddingRight = UDim.new(0, 14)
	chipPadding.Parent = chip
	local chipRow = row(chip, "Row", 10)
	chipRow.Size = UDim2.fromScale(0, 1)
	self.targetText = autoLabel(chipRow, "Text", "", 24)
	self.targetText.TextColor3 = UiKit.PALETTE.yellow.top
	self.targetText.LayoutOrder = 1
	self.targetChip = chip
	self.targetKey = nil :: Frame?
	self.chipRow = chipRow

	-- Bottom-right: mobile action buttons (touch only)
	local isTouch = UserInputService.TouchEnabled
	local actions = container(gui, "Actions", Vector2.new(1, 1), UDim2.new(1, -16, 1, -16), Vector2.new(244, 118))
	actions.Visible = isTouch
	self.leapButton = UiKit.button(actions, "Leap", "LEAP", "yellow", 28)
	self.leapButton.AnchorPoint = Vector2.new(0, 1)
	self.leapButton.Position = UDim2.fromScale(0, 1)
	self.leapButton.Size = UDim2.fromOffset(108, 92)
	self.jumpButton = UiKit.button(actions, "Jump", "JUMP", "blue", 30)
	self.jumpButton.AnchorPoint = Vector2.new(1, 1)
	self.jumpButton.Position = UDim2.fromScale(1, 1)
	self.jumpButton.Size = UDim2.fromOffset(122, 118)
	self.actions = actions

	-- Centre: big messages (Ready / Go / Crashed)
	local message = UiKit.label(gui, "Message", "", 64)
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.34)
	message.Size = UDim2.new(0.8, 0, 0, 80)
	message.Visible = false
	self.message = message

	-- End of run
	local endPanel = container(gui, "EndPanel", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.44), Vector2.new(470, 72))
	endPanel.Visible = false
	self.againButton = UiKit.button(endPanel, "RideAgain", "Ride Again", "green", 30)
	self.againButton.Size = UDim2.fromOffset(225, 70)
	self.returnButton = UiKit.button(endPanel, "Return", "Sanctuary", "blue", 30)
	self.returnButton.AnchorPoint = Vector2.new(1, 0)
	self.returnButton.Position = UDim2.fromScale(1, 0)
	self.returnButton.Size = UDim2.fromOffset(225, 70)
	self.endPanel = endPanel

	self.inputKind = inputKind()
	self:refreshInputHints()
	table.insert(self.connections, UserInputService.LastInputTypeChanged:Connect(function()
		local kind = inputKind()
		if kind ~= self.inputKind then
			self.inputKind = kind
			self:refreshInputHints()
			self.leapTargetName = nil -- re-render the chip text for the new device
		end
	end))

	self:setLeapReady(false, nil)
	return self
end

export type RideHud = typeof(RideHud.new())

function RideHud.refreshInputHints(self: RideHud)
	for _, child in self.hints:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, hint in HINTS[self.inputKind] do
		local group = row(self.hints, "Hint" .. i, 5)
		group.LayoutOrder = i
		group.Size = UDim2.fromOffset(0, 30)
		for j, key in hint.keys do
			UiKit.keycap(group, key).LayoutOrder = j
		end
		autoLabel(group, "Text", hint.text, 18).LayoutOrder = #hint.keys + 1
	end
	if self.targetKey then
		self.targetKey:Destroy()
		self.targetKey = nil
	end
	local leapKey = LEAP_KEY[self.inputKind]
	if leapKey then
		local key = UiKit.keycap(self.chipRow, leapKey)
		key.LayoutOrder = 2
		self.targetKey = key
	end
end

function RideHud.setAnimal(self: RideHud, species: string, stats: any)
	local style = UiKit.SPECIES[species] or UiKit.SPECIES.Zebra
	UiKit.recolor(self.animalTile, style.color)
	self.animalIcon.Text = style.icon
	self.animalName.Text = stats.displayName
	local ability = string.match(stats.abilityHint, "—%s*(.+)$") or stats.abilityHint
	self.ability.Text = string.upper(string.sub(ability, 1, 1)) .. string.sub(ability, 2)
end

-- `used` is the fraction of grip spent (0 = fresh mount, 1 = bucked off); the bar shows what's left.
function RideHud.setGrip(self: RideHud, used: number, warningAt: number)
	if self.befriending then
		self.befriending = false
		self.temper.setColor(GRIP_COLORS)
	end
	local text = if used >= 0.9 then "HOLD ON!" elseif used >= warningAt then "SLIPPING!" else "GRIP"
	self.temper.set(1 - used, text)
end

-- Tame progress under the status block; hidden when `fraction` is nil.
function RideHud.setTame(self: RideHud, fraction: number?, text: string?)
	self.tame.frame.Visible = fraction ~= nil
	if fraction then
		self.tame.set(fraction, text)
	end
end

-- Tutorial variant of the top meter: befriending progress instead of grip.
function RideHud.setBefriending(self: RideHud, fraction: number, animalName: string)
	if not self.befriending then
		self.befriending = true
		self.temper.setColor(UiKit.verticalSequence("pink"))
	end
	self.temper.set(fraction, string.format("BEFRIENDING %s  %d%%", string.upper(animalName), math.floor(fraction * 100 + 0.5)))
end

function RideHud.setDistance(self: RideHud, distance: number, length: number)
	self.distance.set(distance / length, string.format("%d / %d m", math.floor(math.max(distance, 0)), length))
end

-- Shows "LEAP → Giraffe [F]" and enables the mobile LEAP button only while an animal is targeted.
function RideHud.setLeapReady(self: RideHud, ready: boolean, targetName: string?)
	if ready == self.leapReady and targetName == self.leapTargetName then
		return -- called every frame; only touch the UI on change
	end
	self.leapReady = ready
	self.leapTargetName = targetName
	UiKit.setButtonEnabled(self.leapButton, ready)
	self.targetChip.Visible = ready
	if ready and targetName then
		self.targetText.Text = if self.inputKind == "touch" then `Tap LEAP → {targetName}` else `LEAP → {targetName}`
	end
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

-- First-ride hint. Keyboard/gamepad players already see the hints row, so only touch gets a toast.
function RideHud.showHint(self: RideHud, isTouch: boolean, duration: number)
	if isTouch then
		UiKit.toast("Drag to steer  ·  JUMP to hop  ·  LEAP onto glowing animals", duration)
	end
end

function RideHud.setEndPanelVisible(self: RideHud, visible: boolean)
	if visible and not self.endPanel.Visible then
		UiKit.popIn(self.endPanel)
	elseif not visible then
		self.endPanel.Visible = false
	end
end

function RideHud.destroy(self: RideHud)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.gui:Destroy()
end

return RideHud
