--!strict
-- Client-driven arcade riding (D-007, D-016): auto-run forward with a speed ramp, free horizontal
-- steering, jump, temper, obstacle checks, speed-reactive camera. The mount is a client-side
-- AnimalAgent with the rider welded on.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local AnimalAgent = require(script.Parent.AnimalAgent)
local CourseObstacles = require(script.Parent.CourseObstacles)
local RideHud = require(script.Parent.RideHud)

local RideController = {}
RideController.__index = RideController

local ACTION_LEFT = "RideSteerLeft"
local ACTION_RIGHT = "RideSteerRight"
local ACTION_JUMP = "RideJump"
local CAMERA_STEP = "RideCamera"
local JUMP_BUFFER = 0.15
local BASE_FOV = 70
local HINT_DURATION = 7
local GAMEPAD_DEADZONE = 0.2
local TAP_MAX_TIME = 0.25
local TAP_MAX_MOVE = 14 -- pixels
local TOUCH_SCREEN_SPAN = 1.1 -- a full-screen-width drag moves this many track widths
local LAUNCH_ACCELERATION = 60 -- studs/s² when leaving the start line
local END_PANEL_DELAY = 0.8
local RESPAWN_COUNTDOWN = 0.7

local STARTING_SPECIES = "Zebra"

local hintShown = false

local function damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function moveToward(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

local function makeDust(root: BasePart, rootHeight: number): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "DustAttachment"
	attachment.Position = Vector3.new(0, -rootHeight + 0.3, 1.5)
	attachment.Parent = root

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(214, 190, 140))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(40, 40)
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Acceleration = Vector3.new(0, 4, 0)
	dust.Rate = 0
	dust.Parent = attachment
	return dust
end

-- Welds the rider's character onto the mount's saddle. The mount exists only on this client; the
-- character is client-owned, so its movement still replicates to the server and others (D-016).
local function attachRider(agent: AnimalAgent.AnimalAgent, humanoid: Humanoid): WeldConstraint?
	local character = humanoid.Parent
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end
	humanoid.Sit = true
	rootPart.CFrame = agent.root.CFrame * CFrame.new(0, agent.riderOffset, 0.2)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RiderWeld"
	weld.Part0 = agent.root
	weld.Part1 = rootPart
	weld.Parent = agent.root
	return weld
end

function RideController.new(courseId: string, humanoid: Humanoid)
	local course = CourseConfig.courses[courseId] or CourseConfig.courses[CourseConfig.defaultCourse]
	local agent = AnimalAgent.new(STARTING_SPECIES, course, 0, 0, false)
	local root = agent.root
	local rootHeight = agent.rootHeight

	local self = setmetatable({}, RideController)
	self.agent = agent
	self.root = root
	self.humanoid = humanoid
	self.stats = agent.stats
	self.course = course
	self.speedMultiplier = course.speedMultiplier or 1
	self.temperEnabled = course.temperEnabled ~= false
	-- Optional hooks (used by TutorialDirector). Returning true from onCrash/onFinish means the hook
	-- handled it, so the default end-of-run panel is skipped.
	self.onCrash = nil :: (() -> boolean)?
	self.onFinish = nil :: (() -> boolean)?
	self.onStep = nil :: ((dt: number) -> ())?
	self.rootHeight = rootHeight
	self.obstacles = CourseObstacles.build(course)
	self.connections = {} :: { RBXScriptConnection }
	self.hud = RideHud.new()
	-- Ride inputs are bound at high priority and seated characters ignore walk input, so the only
	-- default control to suppress is the on-screen touch joystick/jump button.
	self.touchControlsWereEnabled = GuiService.TouchControlsEnabled
	self.camera = Workspace.CurrentCamera
	self.dust = makeDust(root, rootHeight)

	-- Input state
	self.leftHeld = false
	self.rightHeld = false
	self.gamepadAxis = 0
	self.touchInput = nil :: InputObject?
	self.touchStartX = 0
	self.touchStartTargetX = 0
	self.touchStartTime = 0
	self.touchMoved = false
	self.touchTargetX = nil :: number?

	-- Presentation state
	self.x = 0
	self.steerVelocity = 0
	self.cameraX = 0
	self.cameraY = CourseConfig.groundY + rootHeight + 9
	self.fov = BASE_FOV
	self.shake = 0

	self.riderWeld = attachRider(agent, humanoid)

	GuiService.TouchControlsEnabled = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self:bindInput()
	self:reset()

	if not hintShown and not course.tutorial then
		hintShown = true
		self.hud:showHint(UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled, HINT_DURATION)
	end

	self.camera.CameraType = Enum.CameraType.Scriptable
	table.insert(self.connections, RunService.PreSimulation:Connect(function(dt)
		self:step(dt)
	end))
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:updateCamera(dt)
	end)

	return self
end

export type RideController = typeof(RideController.new("", Instance.new("Humanoid")))

function RideController.reset(self: RideController)
	self.distance = 0
	self.x = 0
	self.steerVelocity = 0
	self.speed = 0
	self.jumpTime = nil :: number?
	self.jumpBufferedAt = nil :: number?
	self.temper = 0
	self.elapsed = 0
	self.state = "countdown"
	self.timer = CourseConfig.countdownTime
	self.touchTargetX = nil
	self.hud:setEndPanelVisible(false)
	self.hud:showMessage("Ready...")
	self.hud:setTemper(0, self.stats.temperWarningAt)
	self.hud:setProgress(0)
end

function RideController.jump(self: RideController)
	if self.state ~= "running" then
		return
	end
	if self.jumpTime == nil then
		self.jumpTime = 0
	else
		self.jumpBufferedAt = os.clock()
	end
end

function RideController.bindInput(self: RideController)
	local function handler(actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
		local pressed = inputState == Enum.UserInputState.Begin
		if actionName == ACTION_LEFT then
			self.leftHeld = pressed
		elseif actionName == ACTION_RIGHT then
			self.rightHeld = pressed
		elseif actionName == ACTION_JUMP and pressed then
			self:jump()
		end
		return Enum.ContextActionResult.Sink
	end

	local returnRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReturnToSanctuary") :: RemoteEvent
	local function leave()
		returnRemote:FireServer()
	end
	table.insert(self.connections, self.hud.leaveButton.Activated:Connect(leave))
	table.insert(self.connections, self.hud.returnButton.Activated:Connect(leave))
	table.insert(self.connections, self.hud.againButton.Activated:Connect(function()
		if self.state == "ended" then
			self:reset()
		end
	end))
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.R and self.state == "ended" then
			self:reset()
		end
	end))

	local priority = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority(ACTION_LEFT, handler, false, priority, Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft)
	ContextActionService:BindActionAtPriority(ACTION_RIGHT, handler, false, priority, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)
	ContextActionService:BindActionAtPriority(ACTION_JUMP, handler, false, priority, Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.ButtonA)

	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local axis = input.Position.X
			self.gamepadAxis = if math.abs(axis) > GAMEPAD_DEADZONE then axis else 0
		end
	end))

	-- Touch: drag anywhere to steer (animal follows the thumb's sideways offset); quick tap = jump.
	table.insert(self.connections, UserInputService.TouchStarted:Connect(function(input, gameProcessed)
		if gameProcessed or self.touchInput then
			return
		end
		self.touchInput = input
		self.touchStartX = input.Position.X
		self.touchStartTargetX = self.x
		self.touchStartTime = os.clock()
		self.touchMoved = false
	end))
	table.insert(self.connections, UserInputService.TouchMoved:Connect(function(input)
		if input ~= self.touchInput then
			return
		end
		local dx = input.Position.X - self.touchStartX
		if math.abs(dx) > TAP_MAX_MOVE then
			self.touchMoved = true
		end
		if self.touchMoved then
			local studsPerPixel = self.course.trackWidth * TOUCH_SCREEN_SPAN / self.camera.ViewportSize.X
			self.touchTargetX = self.touchStartTargetX + dx * studsPerPixel
		end
	end))
	table.insert(self.connections, UserInputService.TouchEnded:Connect(function(input)
		if input ~= self.touchInput then
			return
		end
		if not self.touchMoved and os.clock() - self.touchStartTime <= TAP_MAX_TIME then
			self:jump()
		end
		self.touchInput = nil
		self.touchTargetX = nil
	end))
end

function RideController.endRun(self: RideController, text: string, shake: number)
	self.state = "ended"
	self.shake = shake
	self.hud:showMessage(text)
	task.delay(END_PANEL_DELAY, function()
		if self.state == "ended" and self.hud.gui.Parent then
			self.hud:setEndPanelVisible(true)
		end
	end)
end

function RideController.jumpHeight(self: RideController): number
	local jumpTime = self.jumpTime
	if jumpTime == nil then
		return 0
	end
	local t = jumpTime / self.stats.jumpDuration
	return 4 * self.stats.jumpHeight * t * (1 - t)
end

function RideController.checkCollisions(self: RideController): boolean
	local stats = self.stats
	return CourseObstacles.hits(self.obstacles, self.distance, self.x, stats.hitboxHalfLength, stats.hitboxHalfWidth, self:jumpHeight())
end

function RideController.updateSteering(self: RideController, dt: number)
	local stats = self.stats
	local desired = 0
	if self.state ~= "ended" then
		local touchTarget = self.touchTargetX
		if touchTarget then
			desired = math.clamp((touchTarget - self.x) * stats.touchFollowGain, -stats.maxSteerSpeed, stats.maxSteerSpeed)
		else
			local axis = (if self.rightHeld then 1 else 0) - (if self.leftHeld then 1 else 0) + self.gamepadAxis
			desired = math.clamp(axis, -1, 1) * stats.maxSteerSpeed
		end
	end

	-- Reversing direction is snappier than speeding up, so dodges feel responsive.
	local reversing = desired * self.steerVelocity < 0
	local acceleration = stats.steerAcceleration * (if reversing then 1.6 else 1)
	self.steerVelocity = moveToward(self.steerVelocity, desired, acceleration * dt)
	self.x += self.steerVelocity * dt

	local limit = self.course.trackWidth / 2 - stats.hitboxHalfWidth - 0.5
	if math.abs(self.x) > limit then
		self.x = math.clamp(self.x, -limit, limit)
		self.steerVelocity = 0
	end
end

function RideController.updateJump(self: RideController, dt: number)
	local jumpTime = self.jumpTime
	if jumpTime == nil then
		return
	end
	jumpTime += dt
	if jumpTime < self.stats.jumpDuration then
		self.jumpTime = jumpTime
		return
	end
	self.jumpTime = nil
	local buffered = self.jumpBufferedAt
	self.jumpBufferedAt = nil
	if buffered and os.clock() - buffered <= JUMP_BUFFER then
		self.jumpTime = 0
	end
end

function RideController.step(self: RideController, dt: number)
	local stats = self.stats

	if self.state == "countdown" then
		self.timer -= dt
		if self.timer <= 0 then
			self.state = "running"
			self.hud:showMessage("Go!", 0.6)
		end
	elseif self.state == "running" then
		self.elapsed += dt
		local ramp = math.min(self.elapsed / stats.speedRampTime, 1)
		local eased = 1 - (1 - ramp) ^ 2
		local targetSpeed = (stats.startSpeed + (stats.cruiseSpeed - stats.startSpeed) * eased) * self.speedMultiplier
		self.speed = moveToward(self.speed, targetSpeed, LAUNCH_ACCELERATION * dt)
		self.distance += self.speed * dt
		if self.temperEnabled then
			self.temper += dt / stats.temperDuration
		end
		self:updateJump(dt)

		if self:checkCollisions() then
			self.speed = 0
			self.dust:Emit(25)
			if self.onCrash and self.onCrash() then
				self.state = "ended"
				self.shake = 0.4
			else
				self:endRun("Crashed!", 0.4)
			end
		elseif self.distance >= self.course.length then
			if self.onFinish and self.onFinish() then
				self.state = "ended"
			else
				self:endRun(string.format("Finished!  %.1fs", self.elapsed), 0)
			end
		elseif self.temper >= 1 then
			self.speed = 0
			self:endRun("Bucked off!", 0.3)
		end
	else
		self.speed = moveToward(self.speed, 0, 80 * dt)
		self.distance += self.speed * dt
		self.jumpTime = nil
	end

	self:updateSteering(dt)
	self:applyPose()

	if self.temperEnabled then
		self.hud:setTemper(self.temper, stats.temperWarningAt)
	end
	self.hud:setProgress(self.distance / self.course.length)
	if self.onStep then
		self.onStep(dt)
	end
end

-- Restart from a checkpoint distance after a short "Ready" beat; elapsed time keeps counting.
function RideController.respawnAt(self: RideController, distance: number, message: string)
	self.distance = distance
	self.x = 0
	self.steerVelocity = 0
	self.speed = 0
	self.jumpTime = nil
	self.jumpBufferedAt = nil
	self.state = "countdown"
	self.timer = RESPAWN_COUNTDOWN
	self.hud:setEndPanelVisible(false)
	self.hud:showMessage(message)
end

-- Hands the rider's movement state to the mount's AnimalAgent, which poses the model.
function RideController.applyPose(self: RideController)
	local stats = self.stats
	local agent = self.agent
	agent.distance = self.distance
	agent.x = self.x
	agent.speed = self.speed
	agent.steerVelocity = self.steerVelocity
	agent.jumpTime = self.jumpTime

	local restlessYaw = 0
	if self.state == "running" and self.temper >= stats.temperWarningAt then
		local restless = (self.temper - stats.temperWarningAt) / (1 - stats.temperWarningAt)
		restlessYaw = math.sin(self.elapsed * 35) * 0.08 * restless
	end
	agent:pose(restlessYaw)

	local speedFraction = math.clamp(self.speed / stats.cruiseSpeed, 0, 1.2)
	self.dust.Rate = if self.jumpTime ~= nil or self.state ~= "running" then 0 else 40 * speedFraction
end

function RideController.updateCamera(self: RideController, dt: number)
	local camera = self.camera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local stats = self.stats
	local speedFraction = math.clamp(self.speed / stats.cruiseSpeed, 0, 1.2)
	local rootPosition = self.root.Position
	local baseY = CourseConfig.groundY + self.rootHeight

	-- Sideways and height follow with a little lag; distance behind grows with speed.
	self.cameraX += (self.x * 0.65 - self.cameraX) * damp(6, dt)
	local targetY = baseY + 9 + 1.5 * speedFraction + self:jumpHeight() * 0.45
	self.cameraY += (targetY - self.cameraY) * damp(8, dt)
	self.fov += (68 + 16 * speedFraction - self.fov) * damp(3, dt)

	local back = 17 + 6 * speedFraction
	local position = Vector3.new(self.course.origin.X + self.cameraX, self.cameraY, rootPosition.Z + back)

	-- Small rhythmic rumble at speed plus crash shake.
	local phase = self.distance / stats.strideLength * 2 * math.pi
	position += Vector3.new(0, math.sin(phase * 2) * 0.06 * speedFraction, 0)
	if self.shake > 0 then
		self.shake -= dt
		local strength = math.max(self.shake, 0) * 3
		position += Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end

	local lookAhead = 28 + 10 * speedFraction
	local lookAt = Vector3.new(self.course.origin.X + self.cameraX * 0.6 + self.x * 0.4, baseY + 1, rootPosition.Z - lookAhead)
	camera.CFrame = CFrame.lookAt(position, lookAt) * CFrame.Angles(0, 0, -self.steerVelocity * 0.0035)
	camera.FieldOfView = self.fov
end

function RideController.destroy(self: RideController)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	ContextActionService:UnbindAction(ACTION_LEFT)
	ContextActionService:UnbindAction(ACTION_RIGHT)
	ContextActionService:UnbindAction(ACTION_JUMP)
	RunService:UnbindFromRenderStep(CAMERA_STEP)

	if self.riderWeld then
		self.riderWeld:Destroy()
	end
	self.agent:destroy()

	self.camera.CameraType = Enum.CameraType.Custom
	self.camera.FieldOfView = BASE_FOV
	GuiService.TouchControlsEnabled = self.touchControlsWereEnabled
	if self.humanoid.Parent then
		self.humanoid.Sit = false
		self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	self.hud:destroy()
end

return RideController
