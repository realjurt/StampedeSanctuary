--!strict
-- Client-driven arcade riding (Decision D-002): auto-run forward, lane steering, jump,
-- temper, obstacle checks, follow camera, procedural gallop.

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

local hintShown = false

local function buildObstacles(): { Obstacle }
	local list: { Obstacle } = {}
	local half = (CourseConfig.laneCount - 1) / 2
	for _, placement in CourseConfig.obstacles do
		local kind = CourseConfig.obstacleKinds[placement.kind]
		if kind then
			local width = if kind.allLanes then CourseConfig.laneCount * CourseConfig.laneWidth else kind.size.X
			local x = if kind.allLanes then 0 else math.clamp(placement.lane, -half, half) * CourseConfig.laneWidth
			local depth = kind.size.Z
			table.insert(list, {
				dMin = placement.distance - depth / 2,
				dMax = placement.distance + depth / 2,
				xMin = x - width / 2,
				xMax = x + width / 2,
				height = kind.size.Y,
			})
		end
	end
	return list
end

local function getControls(): any?
	local player = Players.LocalPlayer
	local playerScripts = player:WaitForChild("PlayerScripts")
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

function RideController.new(model: Model, humanoid: Humanoid)
	local animalId = model:GetAttribute("AnimalId")
	local stats = AnimalConfig[if typeof(animalId) == "string" then animalId else "Zebra"]
	local rootHeight = model:GetAttribute("RootHeight")

	local self = setmetatable({}, RideController)
	self.model = model
	self.root = model.PrimaryPart :: BasePart
	self.humanoid = humanoid
	self.stats = stats :: AnimalStats
	self.rootHeight = if typeof(rootHeight) == "number" then rootHeight else 4
	self.obstacles = buildObstacles()
	self.legs = {} :: { Leg }
	self.connections = {} :: { RBXScriptConnection }
	self.hud = RideHud.new()
	self.controls = getControls()
	self.camera = Workspace.CurrentCamera
	self.shake = 0
	self.gallopPhase = 0
	self.x = 0

	for _, legName in { "LegFL", "LegFR", "LegBL", "LegBR" } do
		local legPart = model:FindFirstChild(legName)
		local weld = legPart and legPart:FindFirstChild("Hip")
		if weld and weld:IsA("Weld") then
			local diagonal = legName == "LegFL" or legName == "LegBR"
			table.insert(self.legs, { weld = weld, baseC0 = weld.C0, phaseOffset = if diagonal then 0 else math.pi })
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
	self.lane = 0
	self.speed = 0
	self.jumpTime = nil :: number?
	self.jumpBufferedAt = nil :: number?
	self.temper = 0
	self.elapsed = 0
	self.state = "countdown"
	self.timer = CourseConfig.countdownTime
	self.hud:showMessage("Ready...")
	self.hud:setTemper(0, self.stats.temperWarningAt)
	self.hud:setProgress(0)
end

function RideController.steer(self: RideController, direction: number)
	if self.state == "ended" then
		return
	end
	local half = (CourseConfig.laneCount - 1) / 2
	self.lane = math.clamp(self.lane + direction, -half, half)
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
		if inputState == Enum.UserInputState.Begin then
			if actionName == ACTION_LEFT then
				self:steer(-1)
			elseif actionName == ACTION_RIGHT then
				self:steer(1)
			elseif actionName == ACTION_JUMP then
				self:jump()
			end
		end
		return Enum.ContextActionResult.Sink
	end

	local priority = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority(ACTION_LEFT, handler, false, priority, Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft)
	ContextActionService:BindActionAtPriority(ACTION_RIGHT, handler, false, priority, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)
	ContextActionService:BindActionAtPriority(ACTION_JUMP, handler, false, priority, Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.ButtonA)

	table.insert(self.connections, UserInputService.TouchSwipe:Connect(function(direction, _touches, gameProcessed)
		if gameProcessed then
			return
		end
		if direction == Enum.SwipeDirection.Left then
			self:steer(-1)
		elseif direction == Enum.SwipeDirection.Right then
			self:steer(1)
		elseif direction == Enum.SwipeDirection.Up then
			self:jump()
		end
	end))
	table.insert(self.connections, UserInputService.TouchTap:Connect(function(_positions, gameProcessed)
		if not gameProcessed then
			self:jump()
		end
	end))
end

function RideController.endRun(self: RideController, text: string)
	self.state = "ended"
	self.timer = CourseConfig.restartDelay
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
		self.speed = math.min(stats.forwardSpeed, self.speed + stats.forwardSpeed / stats.accelerationTime * dt)
		self.distance += self.speed * dt
		self.temper += dt / stats.temperDuration

		local jumpTime = self.jumpTime
		if jumpTime ~= nil then
			jumpTime += dt
			if jumpTime >= stats.jumpDuration then
				self.jumpTime = nil
				local buffered = self.jumpBufferedAt
				self.jumpBufferedAt = nil
				if buffered and os.clock() - buffered <= JUMP_BUFFER then
					self.jumpTime = 0
				end
			else
				self.jumpTime = jumpTime
			end
		end

		if self:checkCollisions() then
			self.shake = 0.35
			self:endRun("Crashed!")
		elseif self.distance >= CourseConfig.length then
			self:endRun(string.format("Finished!  %.1fs", self.elapsed))
		elseif self.temper >= 1 then
			self.shake = 0.25
			self:endRun("Bucked off!")
		end
	else
		self.speed = math.max(0, self.speed - 70 * dt)
		self.distance += self.speed * dt
		self.jumpTime = nil
		self.timer -= dt
		if self.timer <= 0 then
			self:reset()
		end
	end

	-- Sideways: ease toward the target lane.
	local targetX = self.lane * CourseConfig.laneWidth
	local previousX = self.x
	self.x += (targetX - self.x) * (1 - math.exp(-dt / stats.laneSmoothing))
	local xVelocity = (self.x - previousX) / math.max(dt, 1e-3)

	-- Gallop: legs swing in diagonal pairs, body bobs; legs tuck while airborne.
	local speedFraction = self.speed / stats.forwardSpeed
	self.gallopPhase += dt * stats.gallopFrequency * 2 * math.pi * speedFraction
	local airborne = self.jumpTime ~= nil
	for _, leg in self.legs do
		local angle = if airborne
			then (if leg.phaseOffset == 0 then -0.7 else 0.7)
			else math.sin(self.gallopPhase + leg.phaseOffset) * stats.gallopAmplitude * speedFraction
		leg.weld.C0 = leg.baseC0 * CFrame.Angles(angle, 0, 0)
	end
	local bob = if airborne then 0 else math.abs(math.sin(self.gallopPhase)) * stats.bobHeight * speedFraction

	local lean = math.clamp((targetX - self.x) * -0.04, -0.25, 0.25)
	local yaw = 0
	if self.state == "running" and self.temper >= stats.temperWarningAt then
		local restless = (self.temper - stats.temperWarningAt) / (1 - stats.temperWarningAt)
		yaw = math.sin(self.elapsed * 35) * 0.08 * restless
	end

	local origin = CourseConfig.origin
	local position = Vector3.new(origin.X + self.x, CourseConfig.groundY + self.rootHeight + self:jumpHeight() + bob, origin.Z - self.distance)
	self.root.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, lean)
	self.root.AssemblyLinearVelocity = Vector3.new(xVelocity, 0, -self.speed)
	self.root.AssemblyAngularVelocity = Vector3.zero

	self.hud:setTemper(self.temper, stats.temperWarningAt)
	self.hud:setProgress(self.distance / CourseConfig.length)
end

function RideController.updateCamera(self: RideController, dt: number)
	local camera = self.camera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local rootPosition = self.root.Position
	local speedFraction = self.speed / self.stats.forwardSpeed

	local desired = Vector3.new(CourseConfig.origin.X + self.x * 0.6, rootPosition.Y + 11 - self:jumpHeight() * 0.5, rootPosition.Z + 20)
	local current = camera.CFrame.Position
	local alpha = 1 - math.exp(-dt * 10)
	local position = if (current - desired).Magnitude > 60 then desired else current:Lerp(desired, alpha)

	if self.shake > 0 then
		self.shake -= dt
		local strength = math.max(self.shake, 0) * 2.5
		position += Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end

	local lookAt = Vector3.new(position.X * 0.5 + rootPosition.X * 0.5, rootPosition.Y, rootPosition.Z - 30)
	camera.CFrame = CFrame.lookAt(position, lookAt)
	camera.FieldOfView = BASE_FOV + 8 * speedFraction
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
