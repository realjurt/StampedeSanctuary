--!strict
-- Stampede Sanctuary design system — "Outlined Radiance" (D-022). Every screen builds from these
-- pieces so colors, contours, gloss and motion stay consistent. Visual reference:
-- Obsidian "Assets & References/Outlined Radiance - Plate I.png".
-- Sizes are authored for a 1280×720 reference screen; containers registered with autoScale grow or
-- shrink with the player's viewport.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiKit = {}

export type Swatch = { top: Color3, bottom: Color3 }

UiKit.FONT = Enum.Font.FredokaOne
UiKit.INK = Color3.fromRGB(11, 11, 14)
UiKit.PANEL = Color3.fromRGB(46, 47, 55)
UiKit.TRACK = Color3.fromRGB(16, 16, 20)
UiKit.INSET = Color3.fromRGB(26, 27, 32) -- darker sunken area inside windows
UiKit.QUIET = Color3.fromRGB(170, 172, 182)
UiKit.WHITE = Color3.fromRGB(250, 250, 252)

UiKit.PALETTE = {
	green = { top = Color3.fromRGB(92, 240, 72), bottom = Color3.fromRGB(28, 172, 40) },
	cyan = { top = Color3.fromRGB(60, 210, 255), bottom = Color3.fromRGB(24, 132, 232) },
	blue = { top = Color3.fromRGB(84, 140, 255), bottom = Color3.fromRGB(28, 62, 206) },
	purple = { top = Color3.fromRGB(168, 110, 255), bottom = Color3.fromRGB(88, 34, 200) },
	pink = { top = Color3.fromRGB(255, 112, 210), bottom = Color3.fromRGB(196, 24, 140) },
	yellow = { top = Color3.fromRGB(255, 222, 92), bottom = Color3.fromRGB(238, 150, 0) },
	red = { top = Color3.fromRGB(255, 98, 98), bottom = Color3.fromRGB(196, 20, 28) },
	gray = { top = Color3.fromRGB(150, 152, 164), bottom = Color3.fromRGB(84, 86, 98) },
} :: { [string]: Swatch }

local REFERENCE = Vector2.new(1280, 720)
local GLOSS_ROTATION = 25 -- degrees; gives the reference's forward-leaning stripes
-- { gap before, stripe width } in multiples of the frame height: thick, thin, thick, thin.
local GLOSS_STRIPES = { { 0, 0.45 }, { 0.25, 0.16 }, { 0.22, 0.75 }, { 0.3, 0.2 } }
local Z_OVERLAY = 2
local Z_CONTENT = 4

local function swatch(color: string | Color3): Swatch
	if typeof(color) == "Color3" then
		return { top = color:Lerp(Color3.new(1, 1, 1), 0.22), bottom = color:Lerp(Color3.new(0, 0, 0), 0.25) }
	end
	return UiKit.PALETTE[color] or UiKit.PALETTE.gray
end

function UiKit.corner(parent: GuiObject, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 8)
	c.Parent = parent
end

function UiKit.stroke(parent: GuiObject, thickness: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or UiKit.INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- Contour around a frame/button (not its text).
function UiKit.border(parent: GuiObject, thickness: number)
	local s = UiKit.stroke(parent, thickness)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

-- Responsive scale: one UIScale per registered container, sized from the viewport.
local scaled: { UIScale } = {}
local function viewportScale(): number
	local size = Workspace.CurrentCamera.ViewportSize
	local minimum = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 0.72 else 0.6
	return math.clamp(math.min(size.X / REFERENCE.X, size.Y / REFERENCE.Y), minimum, 1.25)
end
local function rescaleAll()
	local value = viewportScale()
	for i = #scaled, 1, -1 do
		if scaled[i].Parent then
			scaled[i].Scale = value
		else
			table.remove(scaled, i)
		end
	end
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleAll)

function UiKit.autoScale(object: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Name = "AutoScale"
	scale.Scale = viewportScale()
	scale.Parent = object
	table.insert(scaled, scale)
end

function UiKit.screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- Bold white text with a black outline, sized to the font.
function UiKit.label(parent: Instance, name: string, text: string, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = UiKit.FONT
	l.TextSize = textSize
	l.TextColor3 = UiKit.WHITE
	l.TextWrapped = true
	l.Text = text
	l.ZIndex = Z_CONTENT
	l.Parent = parent
	UiKit.stroke(l, math.max(2, math.floor(textSize / 6.5 + 0.5)))
	return l
end

-- Diagonal gloss stripes at one fixed on-screen angle, plus the top light band.
function UiKit.gloss(frame: GuiObject, strength: number?)
	local alpha = 1 - (strength or 0.3)
	local frameCorner = frame:FindFirstChildOfClass("UICorner")
	local radius = if frameCorner then frameCorner.CornerRadius else UDim.new(0, 8)
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundColor3 = Color3.new(1, 1, 1)
	highlight.BackgroundTransparency = 0.84
	highlight.BorderSizePixel = 0
	highlight.Size = UDim2.fromScale(1, 0.45)
	highlight.ZIndex = Z_OVERLAY
	highlight.Parent = frame
	UiKit.corner(highlight, radius)

	-- Stripes are real rotated frames; a CanvasGroup clips them to the frame's rounded shape.
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Gloss"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = Z_OVERLAY
	clip.Parent = frame
	UiKit.corner(clip, radius)

	local bars: { Frame } = {}
	for _ = 1, #GLOSS_STRIPES do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BackgroundTransparency = alpha
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Rotation = GLOSS_ROTATION
		bar.Parent = clip
		table.insert(bars, bar)
	end

	-- Sized in multiples of the frame height so headers and small buttons get the same chunky stripes.
	local function layout()
		local size = frame.AbsoluteSize
		if size.Y <= 0 then
			return
		end
		-- AbsoluteSize includes every UIScale above; child offsets are pre-scale, so divide it out.
		local scale = 1
		local node: Instance? = frame
		while node and node:IsA("GuiObject") do
			for _, child in node:GetChildren() do
				if child:IsA("UIScale") then
					scale *= child.Scale
				end
			end
			node = node.Parent
		end
		local width, height = size.X / scale, size.Y / scale
		-- Stripes sit in the right half; on wide headers keep them clear of the close button.
		local cursor = if width / height > 5 then width * 0.5 else math.max(width * 0.5, width - height * 3.1)
		for i, stripe in GLOSS_STRIPES do
			cursor += stripe[1] * height
			bars[i].Position = UDim2.new(0, cursor, 0.5, 0)
			bars[i].Size = UDim2.fromOffset(stripe[2] * height, height * 2.4)
			cursor += stripe[2] * height
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
end

-- Colored field: top-light vertical gradient, gloss, contour, small radius.
function UiKit.surface(frame: GuiObject, color: string | Color3, radius: number?, contour: number?, glossy: boolean?)
	local sw = swatch(color)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	local existing = frame:FindFirstChild("Fill")
	if existing then
		existing:Destroy()
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Fill"
	gradient.Color = ColorSequence.new(sw.top, sw.bottom)
	gradient.Rotation = 90
	gradient.Parent = frame
	if not frame:FindFirstChildOfClass("UICorner") then
		UiKit.corner(frame, UDim.new(0, radius or 8))
	end
	if (contour or 3) > 0 and not frame:FindFirstChildOfClass("UIStroke") then
		UiKit.border(frame, contour or 3)
	end
	if glossy ~= false and not frame:FindFirstChild("Gloss") then
		UiKit.gloss(frame)
	end
end

-- Recolor an existing surface without rebuilding it.
function UiKit.recolor(frame: GuiObject, color: string | Color3)
	local gradient = frame:FindFirstChild("Fill")
	if gradient and gradient:IsA("UIGradient") then
		local sw = swatch(color)
		gradient.Color = ColorSequence.new(sw.top, sw.bottom)
	end
end

local function interactive(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Name = "Press"
	scale.Parent = button
	local hovered = false
	local function to(value: number, time: number)
		TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		hovered = true
		to(1.05, 0.08)
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		to(1, 0.1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.93, 0.05)
	end)
	button.MouseButton1Up:Connect(function()
		to(if hovered then 1.05 else 1, 0.08)
	end)
end

-- Glossy button. color: palette name ("green", "blue", ...) or a Color3.
function UiKit.button(parent: Instance, name: string, text: string, color: string | Color3, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.Parent = parent
	UiKit.surface(b, color, 8, 3)
	local l = UiKit.label(b, "Text", text, textSize)
	l.Size = UDim2.fromScale(1, 1)
	l.TextWrapped = false
	interactive(b)
	return b
end

-- Compact navigation button with an icon tile and label (left-side menu in the reference style).
-- Icons are emoji placeholders until the ChatGPT icon set exists (D-022).
function UiKit.sideButton(parent: Instance, name: string, icon: string, text: string, color: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(160, 48)
	b.Parent = parent
	UiKit.surface(b, color, 8, 3)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.BackgroundTransparency = 1
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.Position = UDim2.new(0, 8, 0.5, 0)
	iconLabel.Size = UDim2.fromOffset(34, 34)
	iconLabel.Text = icon
	iconLabel.TextSize = 26
	iconLabel.ZIndex = Z_CONTENT
	iconLabel.Parent = b
	local l = UiKit.label(b, "Text", text, 22)
	l.Position = UDim2.fromOffset(48, 0)
	l.Size = UDim2.new(1, -54, 1, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = false
	interactive(b)
	return b
end

-- Per-species icon + color used across HUD and Index (placeholder icons).
UiKit.SPECIES = {
	Zebra = { icon = "🦓", color = "cyan" },
	Giraffe = { icon = "🦒", color = "yellow" },
	Elephant = { icon = "🐘", color = "purple" },
} :: { [string]: { icon: string, color: string } }

function UiKit.setButtonText(button: GuiButton, text: string)
	local l = button:FindFirstChild("Text")
	if l and l:IsA("TextLabel") then
		l.Text = text
	end
end

-- Dims a button and makes it ignore clicks (e.g. LEAP with no target).
function UiKit.setButtonEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	local gradient = button:FindFirstChild("Fill")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Transparency = NumberSequence.new(if enabled then 0 else 0.55)
	end
	local l = button:FindFirstChild("Text")
	if l and l:IsA("TextLabel") then
		l.TextTransparency = if enabled then 0 else 0.45
	end
end

function UiKit.closeButton(parent: Instance): TextButton
	local b = UiKit.button(parent, "Close", "X", "red", 34)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -9, 0.5, 0)
	b.Size = UDim2.fromOffset(50, 50)
	return b
end

-- Small keyboard/gamepad key, e.g. [F].
function UiKit.keycap(parent: Instance, key: string): Frame
	local cap = Instance.new("Frame")
	cap.Name = "Key"
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.Size = UDim2.fromOffset(28, 28)
	cap.BackgroundColor3 = Color3.fromRGB(56, 58, 68)
	cap.Parent = parent
	UiKit.corner(cap, UDim.new(0, 5))
	UiKit.border(cap, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 7)
	padding.PaddingRight = UDim.new(0, 7)
	padding.Parent = cap
	local l = UiKit.label(cap, "Text", key, 16)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	l.TextWrapped = false
	return cap
end

-- Darker sunken area inside a window (grids, lists), as in the reference.
function UiKit.inset(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = UiKit.INSET
	f.Parent = parent
	UiKit.corner(f, UDim.new(0, 6))
	UiKit.border(f, 3)
	return f
end

-- Centered "-- TITLE --" section heading in yellow.
function UiKit.sectionTitle(parent: Instance, text: string, size: number?): TextLabel
	local l = UiKit.label(parent, "Section", `-- {string.upper(text)} --`, size or 34)
	l.TextColor3 = UiKit.PALETTE.yellow.top
	l.TextWrapped = false
	return l
end

export type Bar = {
	frame: Frame,
	label: TextLabel,
	set: (fraction: number, text: string?) -> (),
	setColor: (colors: ColorSequence) -> (),
}

-- Progress bar: dark track, contour, gradient fill anchored to the track (so multi-color fills keep
-- their stops as the bar fills), optional centered outlined text.
function UiKit.bar(parent: Instance, name: string, colors: ColorSequence, textSize: number?): Bar
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = UiKit.TRACK
	track.Parent = parent
	UiKit.corner(track, UDim.new(0, 6))
	UiKit.border(track, 3)

	local clip = Instance.new("Frame")
	clip.Name = "FillClip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(0, 1)
	clip.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = clip
	UiKit.corner(fill, UDim.new(0, 6))
	local gradient = Instance.new("UIGradient")
	gradient.Color = colors
	gradient.Parent = fill
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.8
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 0.45)
	shine.Parent = fill
	UiKit.corner(shine, UDim.new(0, 6))

	local l = UiKit.label(track, "Text", "", textSize or 18)
	l.Size = UDim2.fromScale(1, 1)
	l.TextWrapped = false

	return {
		frame = track,
		label = l,
		set = function(fraction: number, text: string?)
			fraction = math.clamp(fraction, 0, 1)
			clip.Size = UDim2.fromScale(fraction, 1)
			fill.Size = UDim2.fromScale(if fraction > 0.001 then 1 / fraction else 1, 1)
			if text then
				l.Text = text
			end
		end,
		setColor = function(newColors: ColorSequence)
			gradient.Color = newColors
		end,
	}
end

function UiKit.verticalSequence(color: string): ColorSequence
	local sw = swatch(color)
	return ColorSequence.new(sw.top:Lerp(sw.bottom, 0.25), sw.bottom)
end

-- Opening / closing motion for windows and popups.
local function popScale(object: GuiObject): UIScale
	local existing = object:FindFirstChild("Pop")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = object
	return scale
end

function UiKit.popIn(object: GuiObject)
	local scale = popScale(object)
	scale.Scale = 0.8
	object.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function UiKit.popOut(object: GuiObject)
	local scale = popScale(object)
	local tween = TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and scale.Scale <= 0.86 then
			object.Visible = false
		end
	end)
	tween:Play()
end

export type Window = {
	holder: Frame,
	root: Frame,
	body: Frame,
	closeButton: TextButton?,
	open: () -> (),
	hide: () -> (),
}

local HEADER_HEIGHT = 64

-- Dark window with a glossy colored header, outlined title and red X (D-022).
function UiKit.window(parent: Instance, title: string, color: string, size: Vector2, closable: boolean?): Window
	local holder = Instance.new("Frame")
	holder.Name = title:gsub("%W", "") .. "Window"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = parent
	UiKit.autoScale(holder)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = UiKit.PANEL
	root.Parent = holder
	UiKit.corner(root, UDim.new(0, 8))
	UiKit.border(root, 4)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.Parent = root
	UiKit.surface(header, color, 8, 0)
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BackgroundColor3 = UiKit.INK
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT - 2)
	divider.Size = UDim2.new(1, 0, 0, 4)
	divider.ZIndex = Z_CONTENT
	divider.Parent = root
	local titleLabel = UiKit.label(header, "Title", title, 42)
	titleLabel.Position = UDim2.fromOffset(18, 0)
	titleLabel.Size = UDim2.new(1, -80, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextWrapped = false

	local closeButton = if closable ~= false then UiKit.closeButton(header) else nil

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT + 2)
	body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 2))
	body.Parent = root
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent = body

	return {
		holder = holder,
		root = root,
		body = body,
		closeButton = closeButton,
		open = function()
			UiKit.popIn(holder)
		end,
		hide = function()
			UiKit.popOut(holder)
		end,
	}
end

local toastGui: ScreenGui? = nil

-- Brief notification near the top of the screen.
function UiKit.toast(text: string, duration: number?)
	if not toastGui then
		toastGui = UiKit.screen("Toasts", 30)
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 150)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.fromOffset(0, 50)
	frame.BackgroundColor3 = UiKit.PANEL
	frame.Parent = toastGui
	UiKit.corner(frame, UDim.new(0, 8))
	UiKit.border(frame, 3)
	UiKit.autoScale(frame)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 22)
	padding.PaddingRight = UDim.new(0, 22)
	padding.Parent = frame
	local label = UiKit.label(frame, "Text", text, 24)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.TextWrapped = false
	UiKit.popIn(frame)

	task.delay(duration or 3, function()
		UiKit.popOut(frame)
		task.delay(0.2, function()
			frame:Destroy()
		end)
	end)
end

return UiKit
