--!strict
-- Menu windows opened from the side buttons (D-022). One window at a time. While a menu is open the
-- `changed` event fires true so an active ride can pause. Index is the Animal Index (UI-2); Shop and
-- Settings are deliberately "Coming soon" — no purchases or settings are built yet.

local AnimalIndex = require(script.Parent.AnimalIndex)
local UiKit = require(script.Parent.UiKit)

type Entry = { window: UiKit.Window }

local MenuController = {}

local changedEvent = Instance.new("BindableEvent")
MenuController.changed = changedEvent.Event

local MENUS = {
	Index = { title = "Animal Index", color = "cyan", icon = "📖", line = "" },
	Shop = { title = "Shop", color = "green", icon = "🛍️", line = "The Shop opens in a future update." },
	Settings = { title = "Settings", color = "blue", icon = "⚙️", line = "Settings are coming in a future update." },
}

local gui: ScreenGui? = nil
local entries: { [string]: Entry } = {}
local openName: string? = nil

local function comingSoon(window: UiKit.Window, icon: string, line: string)
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = window.body

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.fromOffset(80, 70)
	iconLabel.Text = icon
	iconLabel.TextSize = 56
	iconLabel.LayoutOrder = 1
	iconLabel.Parent = window.body

	local title = UiKit.sectionTitle(window.body, "Coming soon", 40)
	title.Size = UDim2.new(1, 0, 0, 48)
	title.LayoutOrder = 2

	local sub = UiKit.label(window.body, "Line", line, 20)
	sub.Size = UDim2.new(1, 0, 0, 52)
	sub.LayoutOrder = 3
end

local function ensure(name: string): Entry?
	local spec = MENUS[name]
	if not spec then
		return nil
	end
	if not gui then
		gui = UiKit.screen("Menus", 20)
	end
	local entry = entries[name]
	if not entry then
		local window
		if name == "Index" then
			window = UiKit.window(gui :: ScreenGui, spec.title, spec.color, Vector2.new(780, 470))
			AnimalIndex.build(window)
		else
			window = UiKit.window(gui :: ScreenGui, spec.title, spec.color, Vector2.new(640, 400))
			comingSoon(window, spec.icon, spec.line)
		end
		local close = window.closeButton :: TextButton
		close.Activated:Connect(function()
			MenuController.close()
		end)
		entry = { window = window }
		entries[name] = entry
	end
	return entry
end

function MenuController.open(name: string)
	if openName == name then
		MenuController.close()
		return
	end
	local entry = ensure(name)
	if not entry then
		return
	end
	if openName then
		entries[openName].window.hide()
	end
	local wasClosed = openName == nil
	openName = name
	entry.window.open()
	if wasClosed then
		changedEvent:Fire(true)
	end
end

function MenuController.close()
	if not openName then
		return
	end
	entries[openName].window.hide()
	openName = nil
	changedEvent:Fire(false)
end

function MenuController.isOpen(): boolean
	return openName ~= nil
end

-- Connects a set of side buttons (Index / Shop / Settings) to their menus.
function MenuController.bind(buttons: { [string]: GuiButton }): { RBXScriptConnection }
	local connections = {}
	for name, button in buttons do
		table.insert(connections, button.Activated:Connect(function()
			MenuController.open(name)
		end))
	end
	return connections
end

return MenuController
