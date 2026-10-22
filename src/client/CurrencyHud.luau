--!strict
-- Coins, stamina and carried-animal pills (top-right), shown in the sanctuary and on safari.
-- Read-only: values come from the server-published Coins / Stamina / CarriedCount attributes
-- (P1, P2 — D-023, D-024).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TamingConfig = require(ReplicatedStorage.Shared.Config.TamingConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local UiKit = require(script.Parent.UiKit)

local CurrencyHud = {}

local player = Players.LocalPlayer

local SUFFIXES = { "K", "M", "B", "T", "Qa" }

-- 950 → "950", 12_400 → "12.4K", 3_000_000 → "3M".
function CurrencyHud.format(value: number): string
	local whole = math.floor(value)
	if whole < 1000 then
		return tostring(whole)
	end
	local tier = 0
	local scaled = whole
	while scaled >= 1000 and tier < #SUFFIXES do
		scaled /= 1000
		tier += 1
	end
	local text = if scaled < 100 then string.format("%.1f", math.floor(scaled * 10) / 10) else tostring(math.floor(scaled))
	return (string.gsub(text, "%.0$", "")) .. SUFFIXES[tier]
end

local function pill(parent: Instance, name: string, icon: string, color: string, order: number): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(170, 44)
	frame.Parent = parent
	UiKit.surface(frame, color, 10, 3)

	local iconLabel = UiKit.label(frame, "Icon", icon, 26)
	iconLabel.Position = UDim2.fromOffset(6, 0)
	iconLabel.Size = UDim2.fromOffset(36, 44)

	local value = UiKit.label(frame, "Value", "0", 26)
	value.Position = UDim2.fromOffset(44, 0)
	value.Size = UDim2.new(1, -54, 1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextWrapped = false
	return value
end

local function bump(label: TextLabel)
	local scale = label:FindFirstChild("Bump") :: UIScale? or Instance.new("UIScale")
	scale.Name = "Bump"
	scale.Parent = label
	scale.Scale = 1.2
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function CurrencyHud.start()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	local gui = UiKit.screen("CurrencyHud", 1)
	local stack = Instance.new("Frame")
	stack.Name = "Wallet"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.new(1, -14, 0, 64) -- below Roblox's top bar
	stack.Size = UDim2.fromOffset(170, 152)
	stack.Parent = gui
	UiKit.autoScale(stack)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack

	local labels = {
		Coins = pill(stack, "Coins", "💰", "yellow", 1),
		Stamina = pill(stack, "Stamina", "⚡", "cyan", 2),
		CarriedCount = pill(stack, "Carried", "🐾", "green", 3),
	}
	for attribute, label in labels do
		local function refresh(animate: boolean)
			local value = player:GetAttribute(attribute)
			local number = if typeof(value) == "number" then value else 0
			-- Stamina trains in fractions (P4), so it shows one decimal until it gets large.
			local text = if attribute == "CarriedCount"
				then `{number}/{TamingConfig.carryCapacity}`
				elseif attribute == "Stamina" and number < 1000 then Format.stamina(number)
				else CurrencyHud.format(number)
			if text ~= label.Text and animate then
				bump(label)
			end
			label.Text = text
		end
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(true)
		end)
		refresh(false)
	end
end

return CurrencyHud
