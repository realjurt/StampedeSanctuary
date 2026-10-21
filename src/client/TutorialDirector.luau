--!strict
-- Runs the tutorial safari on top of a RideController: section prompts, optional treats,
-- a befriending meter earned through steering / dodging / jumping / finishing, crash checkpoints,
-- and the first-zebra reward. Free-steering itself is untouched (hooks only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local UiKit = require(script.Parent.UiKit)

type Award = { distance: number, points: number, text: string }
type Treat = { distance: number, x: number, part: Part? }

local TutorialDirector = {}
TutorialDirector.__index = TutorialDirector

local RETRY_DELAY = 1.0
local STEER_DETECT = 6 -- studs off-center that counts as "steered"
local PROMPT_TIME = 3.5
local TREAT_RADIUS_X = 2.8
local TREAT_RADIUS_D = 2.6
local MAX_BEFORE_FINISH = 99 -- the finish line always completes the meter
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 215, 80),
	Color3.fromRGB(120, 210, 120),
	Color3.fromRGB(120, 170, 255),
}

function TutorialDirector.new(controller: any)
	local course = controller.course :: CourseConfig.Course
	local spec = course.tutorial :: CourseConfig.TutorialSpec

	local self = setmetatable({}, TutorialDirector)
	self.controller = controller
	self.course = course
	self.spec = spec
	self.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	self.remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.destroyed = false
	self.finished = false
	self.points = 0
	self.steered = false
	self.treatsCollected = 0
	self.promptToken = 0

	self.sections = {}
	for _, section in spec.sections do
		if section.enabled ~= false then
			table.insert(self.sections, section)
		end
	end
	self.sectionIndex = 0

	-- Each obstacle pays out once, the first time the rider gets past it.
	self.awards = {} :: { Award }
	for _, placement in course.obstacles do
		local kind = CourseConfig.obstacleKinds[placement.kind]
		local points = spec.points.obstacle[placement.kind]
		if kind and points then
			table.insert(self.awards, {
				distance = placement.distance + kind.size.Z / 2 + 3,
				points = points,
				text = if kind.fullWidth then "Great jump!" else "Nice dodge!",
			})
		end
	end

	self.gui = UiKit.screen("TutorialHud", 5)
	self.prompt = UiKit.label(self.gui, "Prompt", "", 34)
	self.prompt.AnchorPoint = Vector2.new(0.5, 1)
	self.prompt.Position = UDim2.new(0.5, 0, 1, -90)
	self.prompt.Size = UDim2.new(0.9, 0, 0, 44)
	self.popup = UiKit.label(self.gui, "Popup", "", 30)
	self.popup.AnchorPoint = Vector2.new(0.5, 0.5)
	self.popup.Position = UDim2.fromScale(0.5, 0.22)
	self.popup.Size = UDim2.new(0.6, 0, 0, 40)
	self.popup.TextColor3 = Color3.fromRGB(255, 225, 120)
	self.treatLabel = UiKit.label(self.gui, "Treats", "", 22)
	self.treatLabel.Position = UDim2.fromOffset(16, 118)
	self.treatLabel.Size = UDim2.fromOffset(220, 28)
	self.treatLabel.TextXAlignment = Enum.TextXAlignment.Left

	self.treatFolder = Instance.new("Folder")
	self.treatFolder.Name = "TutorialTreats"
	self.treatFolder.Parent = Workspace
	self.treats = {} :: { Treat }
	for _, spot in spec.treats do
		local part = Instance.new("Part")
		part.Name = "Treat"
		part.Size = Vector3.new(1.4, 1.4, 1.4)
		part.Color = Color3.fromRGB(255, 150, 40)
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CFrame = CFrame.new(course.origin.X + spot.x, CourseConfig.groundY + 2.5, course.origin.Z - spot.distance)
		part.Parent = self.treatFolder
		table.insert(self.treats, { distance = spot.distance, x = spot.x, part = part })
	end
	self:updateTreatLabel()

	controller.onCrash = function()
		return self:handleCrash()
	end
	controller.onFinish = function()
		return self:handleFinish()
	end
	controller.onStep = function(dt)
		self:update(dt)
	end
	self:setMeter()
	return self
end

function TutorialDirector.updateTreatLabel(self: any)
	self.treatLabel.Text = string.format("Treats  %d / %d", self.treatsCollected, #self.treats)
end

function TutorialDirector.setMeter(self: any)
	self.controller.hud:setBefriending(self.points / 100, "Zebra")
end

function TutorialDirector.addPoints(self: any, points: number, text: string?)
	self.points = math.min(self.points + points, MAX_BEFORE_FINISH)
	self:setMeter()
	if text then
		self:flash(string.format("%s  +%d%%", text, math.floor(points + 0.5)))
	end
end

function TutorialDirector.flash(self: any, text: string)
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local stroke = self.popup:FindFirstChildOfClass("UIStroke") :: UIStroke
	self.popup.Text = text
	self.popup.TextTransparency = 0
	stroke.Transparency = 0
	TweenService:Create(self.popup, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
end

function TutorialDirector.showPrompt(self: any, text: string, duration: number?)
	self.promptToken += 1
	local token = self.promptToken
	self.prompt.Text = text
	self.prompt.Visible = true
	if duration then
		task.delay(duration, function()
			if self.promptToken == token and not self.destroyed then
				self.prompt.Visible = false
			end
		end)
	end
end

function TutorialDirector.currentSection(self: any): CourseConfig.TutorialSection
	return self.sections[math.max(self.sectionIndex, 1)]
end

function TutorialDirector.update(self: any, _dt: number)
	local controller = self.controller
	local distance = controller.distance

	-- Advance sections and show each one's prompt once.
	local nextSection = self.sections[self.sectionIndex + 1]
	if nextSection and distance >= nextSection.start then
		self.sectionIndex += 1
		local text = if self.isTouch and nextSection.touchPrompt then nextSection.touchPrompt else nextSection.prompt
		-- The steering prompt stays up until the player actually steers.
		self:showPrompt(text, if nextSection.id == "Steer" then nil else PROMPT_TIME)
	end

	if controller.state ~= "running" then
		return
	end

	if not self.steered and math.abs(controller.x) >= STEER_DETECT then
		self.steered = true
		self:addPoints(self.spec.points.steer, "Nice steering!")
		self:showPrompt("Grab treats if you like — they're a bonus!", PROMPT_TIME)
	end

	for _, treat in self.treats do
		local part = treat.part
		if part then
			part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, os.clock() * 2, 0.4)
			if math.abs(distance - treat.distance) < TREAT_RADIUS_D and math.abs(controller.x - treat.x) < TREAT_RADIUS_X then
				part:Destroy()
				treat.part = nil
				self.treatsCollected += 1
				self:updateTreatLabel()
				self:addPoints(self.spec.points.treat, nil)
				self:flash("Yum! Treat")
			end
		end
	end

	for _, award in self.awards do
		if award.points > 0 and distance >= award.distance then
			self:addPoints(award.points, award.text)
			award.points = 0
		end
	end
end

function TutorialDirector.handleCrash(self: any): boolean
	if self.finished then
		return false
	end
	self:showPrompt("Oops — try that again!", RETRY_DELAY + 0.5)
	local checkpoint = self:currentSection().start
	task.delay(RETRY_DELAY, function()
		if not self.destroyed then
			self.controller:respawnAt(checkpoint, "Ready...")
		end
	end)
	return true
end

function TutorialDirector.confetti(self: any)
	local camera = Workspace.CurrentCamera
	local width = camera.ViewportSize.X
	for i = 1, 40 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(10, 16)
		piece.BackgroundColor3 = CONFETTI_COLORS[(i % #CONFETTI_COLORS) + 1]
		piece.BorderSizePixel = 0
		piece.Position = UDim2.fromOffset(math.random(0, math.floor(width)), -20)
		piece.Rotation = math.random(0, 360)
		piece.Parent = self.gui
		local tween = TweenService:Create(piece, TweenInfo.new(math.random(15, 28) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, piece.Position.X.Offset + math.random(-80, 80), 1, 20),
			Rotation = piece.Rotation + math.random(-360, 360),
		})
		tween:Play()
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
	end
end

function TutorialDirector.showReward(self: any)
	local window = UiKit.window(self.gui, "New Friend!", "green", Vector2.new(500, 320), false)
	window.holder.Name = "RewardCard"
	local body = window.body

	local title = UiKit.label(body, "Title", "You befriended a Zebra!", 36)
	title.TextColor3 = UiKit.PALETTE.yellow.top
	title.Size = UDim2.new(1, 0, 0, 46)
	local text = UiKit.label(body, "Body", string.format("It's ready to move into your sanctuary.\nTreats shared: %d / %d", self.treatsCollected, #self.treats), 22)
	text.Position = UDim2.fromOffset(0, 52)
	text.Size = UDim2.new(1, 0, 0, 64)

	local home = UiKit.button(body, "Home", "Take it home", "green", 30)
	home.AnchorPoint = Vector2.new(0.5, 0)
	home.Position = UDim2.new(0.5, 0, 0, 132)
	home.Size = UDim2.fromOffset(260, 64)
	window.open()
	home.Activated:Connect(function()
		home.Active = false
		self.remotes.ReturnToSanctuary:FireServer()
	end)
end

function TutorialDirector.handleFinish(self: any): boolean
	if self.finished then
		return true
	end
	self.finished = true
	self.points = 100
	self:setMeter()
	self.prompt.Visible = false
	self.treatLabel.Visible = false
	self.controller.hud.leaveButton.Visible = false
	self.remotes.CompleteTutorial:FireServer()
	self:confetti()
	task.delay(0.4, function()
		if not self.destroyed then
			self:showReward()
		end
	end)
	return true
end

function TutorialDirector.destroy(self: any)
	self.destroyed = true
	self.controller.onCrash = nil
	self.controller.onFinish = nil
	self.controller.onStep = nil
	self.treatFolder:Destroy()
	self.gui:Destroy()
end

export type TutorialDirector = typeof(TutorialDirector.new(nil :: any))

return TutorialDirector
