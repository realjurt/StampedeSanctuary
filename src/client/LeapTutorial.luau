--!strict
-- First-time leap lesson (D-021). The first time a herd animal becomes targetable, the local safari
-- slows to ~20% via the ride's simulation clock (D-019), the target is already highlighted, and a
-- device-specific prompt explains the leap. Leaping, skipping, timeouts, losing the target, crashes,
-- restarts and leaving all restore normal speed. Learned/skipped is saved by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)

local LeapTutorial = {}
LeapTutorial.__index = LeapTutorial

local SLOW_SCALE = 0.2
local SLOW_IN_TIME = 0.3 -- real seconds to ease into slow motion
local RESTORE_TIME = 0.25
local TIMEOUT = 8 -- real seconds before giving up for this attempt
local LOST_TARGET_GRACE = 1.5 -- real seconds without a target before giving up for this attempt
local RETRY_COOLDOWN = 3 -- real seconds before trying again after a failed attempt
local SKIP_KEY = Enum.KeyCode.Backspace

function LeapTutorial.new(ride: any)
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local self = setmetatable({}, LeapTutorial)
	self.ride = ride
	self.isTouch = isTouch
	self.state = "waiting" -- waiting | active | done
	self.activeTime = 0
	self.lostTime = 0
	self.cooldown = 0
	self.remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CompleteLeapTutorial") :: RemoteEvent

	local gui = UiKit.screen("LeapTutorialHud", 6)
	gui.Enabled = false
	local prompt = UiKit.label(gui, "Prompt", "", 40)
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.Position = UDim2.fromScale(0.5, 0.2)
	prompt.Size = UDim2.new(0.9, 0, 0, 56)
	prompt.TextColor3 = Color3.fromRGB(255, 225, 90)
	local sub = UiKit.label(gui, "Sub", "Steer to keep it glowing", 24)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.new(0.5, 0, 0.2, 44)
	sub.Size = UDim2.new(0.9, 0, 0, 30)
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(0.5, 0)
	skip.Position = UDim2.new(0.5, 0, 0.2, 76)
	skip.Size = UDim2.fromOffset(220, 30)
	skip.BackgroundTransparency = 1
	skip.Font = UiKit.FONT
	skip.TextSize = 18
	skip.TextColor3 = Color3.fromRGB(200, 200, 205)
	skip.Text = if isTouch then "Skip" else "Skip (Backspace)"
	skip.Parent = gui
	self.gui = gui
	self.prompt = prompt

	self.connections = {} :: { RBXScriptConnection }
	table.insert(self.connections, skip.Activated:Connect(function()
		self:skip()
	end))
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == SKIP_KEY then
			self:skip()
		end
	end))
	-- Real time, not simulation time: the lesson's own timers must keep running during slow motion.
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self:update(dt)
	end))
	return self
end

export type LeapTutorial = typeof(LeapTutorial.new(nil :: any))

function LeapTutorial.begin(self: LeapTutorial, speciesName: string)
	self.state = "active"
	self.activeTime = 0
	self.lostTime = 0
	self.prompt.Text = if self.isTouch
		then `Tap LEAP to jump onto the {speciesName}!`
		else `Press F to leap onto the {speciesName}!`
	self.gui.Enabled = true
	self.ride:setTimeScale(SLOW_SCALE, SLOW_IN_TIME)
end

-- Ends the current attempt without teaching; tries again on a later target.
function LeapTutorial.abandon(self: LeapTutorial, message: string?)
	self.state = "waiting"
	self.cooldown = RETRY_COOLDOWN
	self.gui.Enabled = false
	if self.ride.state == "running" then
		self.ride:setTimeScale(1, RESTORE_TIME)
	end
	if message then
		UiKit.toast(message, 2)
	end
end

function LeapTutorial.finish(self: LeapTutorial, reason: string)
	self.state = "done"
	self.gui.Enabled = false
	self.ride:setTimeScale(1, RESTORE_TIME)
	self.remote:FireServer(reason)
end

function LeapTutorial.skip(self: LeapTutorial)
	if self.state == "active" then
		self:finish("skipped")
	end
end

function LeapTutorial.update(self: LeapTutorial, dt: number)
	if self.state == "done" then
		return
	end
	local ride = self.ride
	local herds = ride.herds
	if self.state == "waiting" then
		self.cooldown = math.max(self.cooldown - dt, 0)
		if self.cooldown <= 0 and ride.state == "running" and herds and herds.target then
			self:begin(herds.target.agent.stats.displayName)
		end
		return
	end

	-- Active
	self.activeTime += dt
	if ride.state == "leaping" then
		-- The ride already resumes normal speed when a leap starts.
		self:finish("learned")
		UiKit.toast("Nice leap! Leap again whenever an animal glows.", 3)
	elseif ride.state ~= "running" then
		self:abandon(nil) -- crashed, finished or restarting: the ride restores its own speed
	elseif self.activeTime > TIMEOUT then
		self:abandon("Next time!")
	elseif not (herds and herds.target) then
		self.lostTime += dt
		if self.lostTime > LOST_TARGET_GRACE then
			self:abandon("Next time!")
		end
	else
		self.lostTime = 0
	end
end

function LeapTutorial.destroy(self: LeapTutorial)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	if self.state == "active" and self.ride.state ~= "ended" then
		self.ride:setTimeScale(1, 0)
	end
	self.gui:Destroy()
end

return LeapTutorial
