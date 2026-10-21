--!strict
-- Client-driven arcade riding (Decisions D-002, D-007): auto-run forward with a speed ramp,
-- free horizontal steering, jump, temper, obstacle checks, speed-reactive camera, distance-tied gallop.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local RideHud = require(script.Parent.RideHud)

type AnimalStats = AnimalConfig.AnimalStats

type Obstacle = {
	dMin: number,
	dMax: number,
	xMin: number,
	xMax: number,
	height: number,
}

type Leg = {
	weld: Weld,
	baseC0: CFrame,
	phaseOffset: number,
	isFront: boolean,
}

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

local LEG_PHASES = {
	-- Bounding gallop: front pair together, back pair half a cycle later, with a slight left/right offset.
	LegFL = { offset = 0, front = true },
	LegFR = { offset = 0.35, front = true },
	LegBL = { offset = math.pi, front = false },
	LegBR = { offset = math.pi + 0.35, front = false },
}

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

local function buildObstacles(): { Obstacle }
	local list: { Obstacle } = {}
	for _, placement in CourseConfig.obstacles do
		local kind = CourseConfig.obstacleKinds[placement.kind]
		if kind then
			local width = if kind.fullWidth then CourseConfig.trackWidth else kind.size.X
			local x = if kind.fullWidth then 0 else placement.x
			table.insert(list, {
				dMin = placement.distance - kind.size.Z / 2,
				dMax = placement.distance + kind.size.Z / 2,
				xMin = x - width / 2,
				xMax = x + width / 2,
				height = kind.size.Y,
			})
		end
	end
	return list
end

local function getControls(): any?
	local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local module = playerScripts:WaitForChild("PlayerModule", 5)
	if not module then
		return nil
	end
	local ok, playerModule = pcall(require, module)
	if not ok then
		return nil
	end
	return (playerModule :: any):GetControls()
end

local function makeDust(root: BasePart, rootHeight: number): (Attachment, ParticleEmitter)
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
	return attachment, dust
end

function RideController.new(model: Model, humanoid: Humanoid)
	local animalId = model:GetAttribute("AnimalId")
	local stats = AnimalConfig[if typeof(animalId) == "string" then animalId else "Zebra"]
	local rootHeightAttr = model:GetAttribute("RootHeight")
	local rootHeight = if typeof(rootHeightAttr) == "number" then rootHeightAttr else 4
	local root = model.PrimaryPart :: BasePart

	local self = setmetatable({}, RideController)
	self.model = model
	self.root = root
	self.humanoid = humanoid
	self.stats = stats :: AnimalStats
	self.rootHeight = rootHeight
	self.obstacles = buildObstacles()
	self.legs = {} :: { Leg }
	self.connections = {} :: { RBXScriptConnection }
	self.hud = RideHud.new()
	self.controls = getControls()
	self.camera = Workspace.CurrentCamera
	self.dustAttachment, self.dust = makeDust(root, rootHeight)

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

	for _, legPart in model:GetChildren() do
		local phase = LEG_PHASES[legPart.Name]
		local weld = legPart:FindFirstChild("Hip")
		if phase and weld and weld:IsA("Weld") then
			table.insert(self.legs, { weld = weld, baseC0 = weld.C0, phaseOffset = phase.offset, isFront = phase.front })
		end
	end

	if self.controls then
		self.controls:Disable()
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self:bindInput()
	self:reset()

	if not hintShown then
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

export type RideController = typeof(RideController.new(Instance.new("Model"), Instance.new("Humanoid")))

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
			local studsPerPixel = CourseConfig.trackWidth * TOUCH_SCREEN_SPAN / self.camera.ViewportSize.X
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
	self.timer = CourseConfig.restartDelay
	self.shake = shake
	self.hud:showMessage(text)
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
	local dMin, dMax = self.distance - stats.hitboxHalfLength, self.distance + stats.hitboxHalfLength
	local xMin, xMax = self.x - stats.hitboxHalfWidth, self.x + stats.hitboxHalfWidth
	local feet = self:jumpHeight()
	for _, obstacle in self.obstacles do
		if dMax > obstacle.dMin and dMin < obstacle.dMax and xMax > obstacle.xMin and xMin < obstacle.xMax then
			if feet < obstacle.height - CourseConfig.jumpForgiveness then
				return true
			end
		end
	end
	return false
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

	local limit = CourseConfig.trackWidth / 2 - stats.hitboxHalfWidth - 0.5
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
		local targetSpeed = stats.startSpeed + (stats.cruiseSpeed - stats.startSpeed) * eased
		self.speed = moveToward(self.speed, targetSpeed, LAUNCH_ACCELERATION * dt)
		self.distance += self.speed * dt
		self.temper += dt / stats.temperDuration
		self:updateJump(dt)

		if self:checkCollisions() then
			self.speed = 0
			self.dust:Emit(25)
			self:endRun("Crashed!", 0.4)
		elseif self.distance >= CourseConfig.length then
			self:endRun(string.format("Finished!  %.1fs", self.elapsed), 0)
		elseif self.temper >= 1 then
			self.speed = 0
			self:endRun("Bucked off!", 0.3)
		end
	else
		self.speed = moveToward(self.speed, 0, 80 * dt)
		self.distance += self.speed * dt
		self.jumpTime = nil
		self.timer -= dt
		if self.timer <= 0 then
			self:reset()
		end
	end

	self:updateSteering(dt)
	self:applyPose()

	self.hud:setTemper(self.temper, stats.temperWarningAt)
	self.hud:setProgress(self.distance / CourseConfig.length)
end

-- Places the animal and animates the gait. The gait phase comes from distance travelled,
-- so the hooves keep pace with the ground instead of sliding.
function RideController.applyPose(self: RideController)
	local stats = self.stats
	local speedFraction = math.clamp(self.speed / stats.cruiseSpeed, 0, 1.2)
	local phase = self.distance / stats.strideLength * 2 * math.pi
	local airborne = self.jumpTime ~= nil

	for _, leg in self.legs do
		local angle
		if airborne then
			angle = if leg.isFront then -0.8 else 0.8
		else
			angle = math.sin(phase + leg.phaseOffset) * stats.gallopAmplitude * math.min(speedFraction * 1.5, 1)
		end
		leg.weld.C0 = leg.baseC0 * CFrame.Angles(angle, 0, 0)
	end

	local bob = if airborne then 0 else (math.sin(phase) * 0.5 + 0.5) * stats.bobHeight * math.min(speedFraction, 1)
	local pitch = if airborne then 0.12 else math.sin(phase + math.pi / 2) * stats.pitchAmplitude * math.min(speedFraction, 1)

	local yaw = -math.atan2(self.steerVelocity, math.max(self.speed, 10)) * stats.turnYaw
	local roll = -self.steerVelocity * stats.turnLean
	if self.state == "running" and self.temper >= stats.temperWarningAt then
		local restless = (self.temper - stats.temperWarningAt) / (1 - stats.temperWarningAt)
		yaw += math.sin(self.elapsed * 35) * 0.08 * restless
	end

	local origin = CourseConfig.origin
	local position = Vector3.new(origin.X + self.x, CourseConfig.groundY + self.rootHeight + self:jumpHeight() + bob, origin.Z - self.distance)
	self.root.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
	self.root.AssemblyLinearVelocity = Vector3.new(self.steerVelocity, 0, -self.speed)
	self.root.AssemblyAngularVelocity = Vector3.zero

	self.dust.Rate = if airborne or self.state ~= "running" then 0 else 40 * speedFraction
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
	local position = Vector3.new(CourseConfig.origin.X + self.cameraX, self.cameraY, rootPosition.Z + back)

	-- Small rhythmic rumble at speed plus crash shake.
	local phase = self.distance / stats.strideLength * 2 * math.pi
	position += Vector3.new(0, math.sin(phase * 2) * 0.06 * speedFraction, 0)
	if self.shake > 0 then
		self.shake -= dt
		local strength = math.max(self.shake, 0) * 3
		position += Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end

	local lookAhead = 28 + 10 * speedFraction
	local lookAt = Vector3.new(CourseConfig.origin.X + self.cameraX * 0.6 + self.x * 0.4, baseY + 1, rootPosition.Z - lookAhead)
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

	for _, leg in self.legs do
		if leg.weld.Parent then
			leg.weld.C0 = leg.baseC0
		end
	end
	self.dustAttachment:Destroy()

	self.camera.CameraType = Enum.CameraType.Custom
	self.camera.FieldOfView = BASE_FOV
	if self.controls then
		self.controls:Enable()
	end
	if self.humanoid.Parent then
		self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	self.hud:destroy()
end

return RideController
