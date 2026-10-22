--!strict
-- Client-driven arcade riding (D-007, D-016): auto-run forward with a speed ramp, free horizontal
-- steering, jump, grip, obstacle checks, speed-reactive camera, leaping between animals, and taming.
-- The mount is a client-side AnimalAgent with the rider welded on; leaps are predicted instantly
-- here and validated by the server (SwitchMount). Taming (D-024): staying on a wild herd animal
-- fills a tame bar; when full the server validates the tame (TameAnimal) - switching alone never
-- collects anything.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AnimalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
local CourseConfig = require(ReplicatedStorage.Shared.Config.CourseConfig)
local TamingConfig = require(ReplicatedStorage.Shared.Config.TamingConfig)
local AnimalAgent = require(script.Parent.AnimalAgent)
local CourseObstacles = require(script.Parent.CourseObstacles)
local RideHud = require(script.Parent.RideHud)
local UiKit = require(script.Parent.UiKit)

type Leap = {
	target: AnimalAgent.AnimalAgent,
	memberId: string,
	elapsed: number,
	fromPosition: Vector3,
	lastPosition: Vector3,
	fromDistance: number,
	fromX: number,
	height: number,
}

local RideController = {}
RideController.__index = RideController

local ACTION_LEFT = "RideSteerLeft"
local ACTION_RIGHT = "RideSteerRight"
local ACTION_JUMP = "RideJump"
local ACTION_LEAP = "RideLeap"
local CAMERA_STEP = "RideCamera"
local JUMP_BUFFER = 0.15
local BASE_FOV = 70
local HINT_DURATION = 7
local GAMEPAD_DEADZONE = 0.2
local TAP_MAX_MOVE = 14 -- pixels a touch must move before it counts as steering
local TOUCH_SCREEN_SPAN = 1.1 -- a full-screen-width drag moves this many track widths
local LAUNCH_ACCELERATION = 60 -- studs/s² when leaving the start line
local END_PANEL_DELAY = 0.8
local RESPAWN_COUNTDOWN = 0.7
local STARTING_SPECIES = "Zebra"

-- Leaping (Milestone 5)
local LEAP_DURATION = 0.45
local LEAP_BASE_HEIGHT = 4
local LEAP_HEIGHT_PER_STUD = 0.12
local LEAP_BOOST = 1.2 -- speed multiplier right after landing
local LEAP_BOOST_TIME = 1.5
local LAND_GRACE = 0.5 -- seconds after landing with no crashes
local LEAP_RESUME_TIME = 0.25 -- real seconds to return to normal speed when a leap starts

-- Taming (D-024)
type TameState = "none" | "taming" | "pending" | "tamed" | "failed"
local TAME_REPLY_TIMEOUT = 3 -- real seconds to wait for the server before giving up on a tame
local STAMINA_MESSAGE_COOLDOWN = 1

local TAME_FAILURES: { [string]: string } = {
	full = "Hands full! Carrying 7 animals",
	stamina = "Not enough stamina!",
}

-- Simulation clock (D-019): one time scale for the whole local safari (rider, herds, grip, jumps).
-- Steering keeps at least this fraction of real time so players can line up during slow motion.
local STEER_MIN_SCALE = 0.6

local hintShown = false

local function playerStamina(): number
	local value = Players.LocalPlayer:GetAttribute("Stamina")
	return if typeof(value) == "number" then value else 0
end

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

local function riderRootPart(humanoid: Humanoid): BasePart?
	local character = humanoid.Parent
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Welds the rider's character onto the mount's saddle. The mount exists only on this client; the
-- character is client-owned, so its movement still replicates to the server and others (D-016).
local function attachRider(agent: AnimalAgent.AnimalAgent, humanoid: Humanoid): WeldConstraint?
	local rootPart = riderRootPart(humanoid)
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
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local self = setmetatable({}, RideController)
	self.courseId = courseId
	self.course = course
	self.humanoid = humanoid
	self.speedMultiplier = course.speedMultiplier or 1
	self.temperEnabled = course.temperEnabled ~= false
	-- Optional hooks (used by TutorialDirector). Returning true from onCrash/onFinish means the hook
	-- handled it, so the default end-of-run panel is skipped.
	self.onCrash = nil :: (() -> boolean)?
	self.onFinish = nil :: (() -> boolean)?
	self.onStep = nil :: ((dt: number) -> ())?
	-- Set by Main when the course has herds; provides `target`, `take`, `release`.
	self.herds = nil :: any
	self.obstacles = CourseObstacles.build(course)
	self.hiddenParts = {} :: { BasePart }
	self.seenSpecies = {} :: { [string]: boolean }
	self.connections = {} :: { RBXScriptConnection }
	self.hud = RideHud.new()
	if not course.herds then
		self.hud.leapButton.Visible = false
	end
	self.returnRemote = remotes:WaitForChild("ReturnToSanctuary") :: RemoteEvent
	self.restartRemote = remotes:WaitForChild("RestartRun") :: RemoteEvent
	self.switchRemote = remotes:WaitForChild("SwitchMount") :: RemoteEvent
	self.tameRemote = remotes:WaitForChild("TameAnimal") :: RemoteEvent
	-- Ride inputs are bound at high priority and seated characters ignore walk input, so the only
	-- default control to suppress is the on-screen touch joystick/jump button.
	self.touchControlsWereEnabled = GuiService.TouchControlsEnabled
	self.camera = Workspace.CurrentCamera

	-- Input state
	self.leftHeld = false
	self.rightHeld = false
	self.gamepadAxis = 0
	self.touchInput = nil :: InputObject?
	self.touchStartX = 0
	self.touchStartTargetX = 0
	self.touchMoved = false
	self.touchTargetX = nil :: number?

	-- Simulation clock
	self.paused = false
	self.timeScale = 1
	self.timeScaleTarget = 1
	self.timeScaleRate = 0

	-- Mount + presentation state
	self.leap = nil :: Leap?
	self.leapHeight = 0
	self.boostTime = 0
	self.graceTime = 0
	self.x = 0
	self.steerVelocity = 0
	-- Taming. `tamedMembers` lasts the whole safari (Ride again replays the same herds), so a tamed
	-- animal never respawns; `secured` counts tames since the last (re)start for the run summary.
	self.mountMember = nil :: string?
	self.tameState = "none" :: TameState
	self.tameProgress = 0
	self.tameSentAt = 0
	self.tamedMembers = {} :: { [string]: boolean }
	self.secured = 0
	self.lastStaminaMessage = 0
	self.gripSeconds = 1
	self:setMount(AnimalAgent.new(STARTING_SPECIES, course, 0, 0, false), nil)
	self.seenSpecies[STARTING_SPECIES] = true
	self.cameraX = 0
	self.cameraY = CourseConfig.groundY + self.rootHeight + 9
	self.fov = BASE_FOV
	self.shake = 0

	GuiService.TouchControlsEnabled = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self:bindInput()
	table.insert(self.connections, self.tameRemote.OnClientEvent:Connect(function(memberId: string, ok: boolean, detail: string?)
		self:onTameResult(memberId, ok, detail)
	end))
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

-- Makes `agent` the ridden mount: welds the rider on and adopts its stats. `memberId` is the herd
-- animal's id (nil for the starting mount, which is already yours and can't be tamed).
function RideController.setMount(self: RideController, agent: AnimalAgent.AnimalAgent, memberId: string?)
	agent:setRidden(true)
	self.agent = agent
	self.root = agent.root
	self.stats = agent.stats
	self.rootHeight = agent.rootHeight
	-- Grip (formerly temper): seconds before being bucked off, scaled by stamina (TamingConfig).
	self.gripSeconds = TamingConfig.gripSeconds(agent.stats.temperDuration, playerStamina())
	self.dust = makeDust(agent.root, agent.rootHeight)
	self.riderWeld = attachRider(agent, self.humanoid)
	self.hud:setAnimal(agent.species, agent.stats)
	local requirement = agent.model:FindFirstChild("StaminaLabel")
	if requirement then
		requirement:Destroy()
	end

	self.mountMember = memberId
	self.tameProgress = 0
	if memberId and not self.tamedMembers[memberId] then
		self.tameState = "taming"
		self.hud:setTame(0, "STAY ON TO TAME IT!")
	else
		self.tameState = "none"
		self.hud:setTame(nil)
	end
end

function RideController.updateTame(self: RideController, dt: number)
	if self.tameState == "taming" then
		self.tameProgress = math.min(self.tameProgress + dt / self.stats.tameTime, 1)
		local almost = self.tameProgress >= TamingConfig.almostTamedAt
		local text = if almost then "Hold on! It's almost tamed!" else string.format("TAMING %d%%", math.floor(self.tameProgress * 100))
		self.hud:setTame(self.tameProgress, text)
		if self.tameProgress >= 1 then
			self.tameState = "pending"
			self.tameSentAt = os.clock()
			self.hud:setTame(1, "SECURING...")
			self.tameRemote:FireServer(self.mountMember)
		end
	elseif self.tameState == "pending" and os.clock() - self.tameSentAt > TAME_REPLY_TIMEOUT then
		self.tameState = "failed"
		self.hud:setTame(nil)
	end
end

-- Server reply to a tame request. Only a confirmed tame counts, even if the rider has moved on.
function RideController.onTameResult(self: RideController, memberId: string, ok: boolean, detail: string?)
	local current = memberId == self.mountMember
	if ok then
		self.tamedMembers[memberId] = true
		self.secured += 1
		if current then
			local stats = AnimalConfig[detail or ""]
			self.tameState = "tamed"
			self.temper = 0 -- a tamed animal calms down
			self.hud:setTame(1, `{string.upper(if stats then stats.displayName else "animal")} TAMED!`)
			self.hud:showMessage("IT'S YOURS!", 1.2)
			self.shake = 0.2
		end
	elseif current then
		self.tameState = "failed"
		self.hud:setTame(nil)
		self.hud:showMessage(TAME_FAILURES[detail or ""] or "It got away!", 1.5)
	end
end

-- Menus pause the local safari (D-022). Safe with the shared simulation clock (D-019): the server
-- only checks wall-clock plausibility, which a pause can only make easier to pass.
function RideController.setPaused(self: RideController, paused: boolean)
	if paused == self.paused then
		return
	end
	self.paused = paused
	if not paused and self.state == "running" then
		self.hud:showMessage("Go!", 0.6)
	end
end

function RideController.detachRider(self: RideController)
	if self.riderWeld then
		self.riderWeld:Destroy()
		self.riderWeld = nil
	end
	local attachment = self.dust.Parent
	if attachment then
		attachment:Destroy()
	end
end

function RideController.reset(self: RideController)
	-- Abort a leap in progress; its target was already taken out of the herd.
	local leap = self.leap
	if leap then
		leap.target:destroy()
		self.leap = nil
	end
	-- "Ride again" always starts on the starting mount (not a wild animal of the same species).
	if self.agent.species ~= STARTING_SPECIES or self.mountMember ~= nil or not self.agent.model.Parent then
		self:detachRider()
		if self.agent.model.Parent then
			self.agent:destroy()
		end
		self:setMount(AnimalAgent.new(STARTING_SPECIES, self.course, 0, 0, false), nil)
	end
	self.secured = 0
	CourseObstacles.reset(self.obstacles)
	for _, part in self.hiddenParts do
		part.LocalTransparencyModifier = 0
	end
	table.clear(self.hiddenParts)

	self.distance = 0
	self.x = 0
	self.steerVelocity = 0
	self.speed = 0
	self.jumpTime = nil :: number?
	self.jumpBufferedAt = nil :: number?
	self.temper = 0
	self.elapsed = 0
	self.leapHeight = 0
	self.boostTime = 0
	self.graceTime = 0
	self:setTimeScale(1, 0)
	self.state = "countdown"
	self.timer = CourseConfig.countdownTime
	self.touchTargetX = nil
	self.hud:setEndPanelVisible(false)
	self.hud:showMessage("Ready...")
	self.hud:setGrip(0, self.stats.temperWarningAt)
	self.hud:setDistance(0, self.course.length)
	self.restartRemote:FireServer()
end

-- Changes the local simulation speed. rampSeconds is real time; 0 applies immediately.
function RideController.setTimeScale(self: RideController, target: number, rampSeconds: number)
	self.timeScaleTarget = target
	if rampSeconds <= 0 then
		self.timeScale = target
		self.timeScaleRate = 0
	else
		self.timeScaleRate = math.abs(target - self.timeScale) / rampSeconds
	end
end

-- Jump is only ever a hop; leaping has its own control (D-020), so jumping can't switch animals.
function RideController.jump(self: RideController)
	if self.state ~= "running" or self.paused then
		return
	end
	if self.jumpTime == nil then
		self.jumpTime = 0
	else
		self.jumpBufferedAt = os.clock()
	end
end

-- Leaps onto the highlighted herd animal; does nothing without a valid target.
function RideController.leapToTarget(self: RideController)
	if self.state ~= "running" or self.paused then
		return
	end
	local herds = self.herds
	local target = herds and herds.target
	if target then
		self:startLeap(target)
	elseif herds and herds.lockedTarget and os.clock() - self.lastStaminaMessage > STAMINA_MESSAGE_COOLDOWN then
		self.lastStaminaMessage = os.clock()
		local stats = herds.lockedTarget.agent.stats
		self.hud:showMessage(`Not enough stamina! Need ⚡{stats.requiredStamina}`, 1.5)
	end
end

function RideController.startLeap(self: RideController, wild: any)
	local rootPart = riderRootPart(self.humanoid)
	if not rootPart then
		return
	end
	local target = wild.agent :: AnimalAgent.AnimalAgent
	self.herds:take(wild)

	-- The old mount rejoins the herd as a wild animal and drifts away - unless it was tamed: then
	-- it's yours and heads home (carried) instead.
	local oldMount = self.agent
	self:detachRider()
	if self.mountMember and self.tamedMembers[self.mountMember] then
		oldMount:destroy()
	else
		self.herds:release(oldMount)
	end
	self.mountMember = nil
	self.tameState = "none"
	self.hud:setTame(nil)

	local gap = target.distance - self.distance
	self.leap = {
		target = target,
		memberId = wild.id,
		elapsed = 0,
		fromPosition = rootPart.Position,
		lastPosition = rootPart.Position,
		fromDistance = self.distance,
		fromX = self.x,
		height = LEAP_BASE_HEIGHT + gap * LEAP_HEIGHT_PER_STUD,
	}
	self.jumpTime = nil
	self.jumpBufferedAt = nil
	self.state = "leaping"
	self:setTimeScale(1, LEAP_RESUME_TIME)
	self.switchRemote:FireServer(wild.id)
end

-- Arcs the rider toward the target's saddle; the arc re-aims at the moving target every frame, so a
-- leap that has started always lands (forgiving by design).
function RideController.updateLeap(self: RideController, dt: number)
	local leap = self.leap :: Leap
	local target = leap.target
	local rootPart = riderRootPart(self.humanoid)
	leap.elapsed += dt

	target.distance += target.speed * dt
	target.steerVelocity = moveToward(target.steerVelocity, 0, 60 * dt)
	target:pose(0)

	local t = math.min(leap.elapsed / LEAP_DURATION, 1)
	local eased = t * t * (3 - 2 * t)
	local saddle = target.root.CFrame * CFrame.new(0, target.riderOffset, 0.2)
	self.leapHeight = 4 * leap.height * t * (1 - t)
	local position = leap.fromPosition:Lerp(saddle.Position, eased) + Vector3.new(0, self.leapHeight, 0)
	if rootPart then
		rootPart.CFrame = CFrame.new(position) * saddle.Rotation
		rootPart.AssemblyLinearVelocity = (position - leap.lastPosition) / math.max(dt, 1e-3)
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
	leap.lastPosition = position
	self.distance = leap.fromDistance + (target.distance - leap.fromDistance) * eased
	self.x = leap.fromX + (target.x - leap.fromX) * eased

	if t >= 1 then
		self:land()
	end
end

function RideController.land(self: RideController)
	local leap = self.leap :: Leap
	local target = leap.target
	self.leap = nil
	self.leapHeight = 0
	self:setMount(target, leap.memberId)

	self.distance = target.distance
	self.x = target.x
	self.steerVelocity = 0
	self.speed = math.max(self.speed, target.speed)
	-- Immediate benefits: a calm mount, a burst of speed, and a moment where nothing can crash you.
	self.temper = 0
	self.boostTime = LEAP_BOOST_TIME
	self.graceTime = LAND_GRACE
	self.state = "running"
	self.shake = 0.15
	self.dust:Emit(20)

	local stats = self.stats
	if self.seenSpecies[target.species] then
		self.hud:showMessage(stats.displayName .. "!", 0.7)
	else
		self.seenSpecies[target.species] = true
		self.hud:showMessage(stats.abilityHint, 1.8)
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
		elseif actionName == ACTION_LEAP and pressed then
			self:leapToTarget()
		end
		return Enum.ContextActionResult.Sink
	end

	local function leave()
		self.returnRemote:FireServer()
	end
	table.insert(self.connections, self.hud.leaveButton.Activated:Connect(leave))
	table.insert(self.connections, self.hud.returnButton.Activated:Connect(leave))
	table.insert(self.connections, self.hud.jumpButton.Activated:Connect(function()
		self:jump()
	end))
	table.insert(self.connections, self.hud.leapButton.Activated:Connect(function()
		self:leapToTarget()
	end))
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
	ContextActionService:BindActionAtPriority(ACTION_LEAP, handler, false, priority, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local axis = input.Position.X
			self.gamepadAxis = if math.abs(axis) > GAMEPAD_DEADZONE then axis else 0
		end
	end))

	-- Touch: drag anywhere to steer (animal follows the thumb's sideways offset). Jumping and leaping
	-- use the on-screen JUMP / LEAP buttons only; touches on buttons are gameProcessed and ignored here.
	table.insert(self.connections, UserInputService.TouchStarted:Connect(function(input, gameProcessed)
		if gameProcessed or self.touchInput then
			return
		end
		self.touchInput = input
		self.touchStartX = input.Position.X
		self.touchStartTargetX = self.x
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
		self.touchInput = nil
		self.touchTargetX = nil
	end))
end

function RideController.endRun(self: RideController, text: string, shake: number)
	self.state = "ended"
	self:setTimeScale(1, 0.15)
	self.shake = shake
	self.hud:showMessage(text)
	if self.tameState == "taming" then
		self.tameState = "failed" -- the tame bar never filled: nothing is collected
		self.hud:setTame(nil)
	end
	if self.secured > 0 then
		UiKit.toast(`GREAT RUN! You caught {self.secured} animal{if self.secured == 1 then "" else "s"}!`, 4)
	end
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

-- Elephants break small rocks: the rock stops blocking and is hidden locally for this run.
function RideController.smash(self: RideController, obstacle: CourseObstacles.Obstacle)
	obstacle.smashed = true
	local courseModel = Workspace:FindFirstChild("Course_" .. self.courseId)
	if courseModel then
		local center = Vector3.new(self.course.origin.X + obstacle.x, 0, self.course.origin.Z - obstacle.distance)
		for _, part in courseModel:GetChildren() do
			if part:IsA("BasePart") and (part.Name == obstacle.kind or part.Name == obstacle.kind .. "Cap") then
				local flat = Vector3.new(part.Position.X, 0, part.Position.Z)
				if (flat - center).Magnitude < 1 then
					part.LocalTransparencyModifier = 1
					table.insert(self.hiddenParts, part)
				end
			end
		end
	end
	self.speed *= 0.9
	self.shake = 0.25
	self.dust:Emit(30)
	self.hud:showMessage("SMASH!", 0.5)
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

function RideController.updateRunning(self: RideController, dt: number)
	local stats = self.stats
	self.elapsed += dt
	local ramp = math.min(self.elapsed / stats.speedRampTime, 1)
	local eased = 1 - (1 - ramp) ^ 2
	local targetSpeed = (stats.startSpeed + (stats.cruiseSpeed - stats.startSpeed) * eased) * self.speedMultiplier
	if self.boostTime > 0 then
		self.boostTime -= dt
		targetSpeed *= LEAP_BOOST
	end
	self.speed = moveToward(self.speed, targetSpeed, LAUNCH_ACCELERATION * dt)
	self.distance += self.speed * dt
	if self.temperEnabled then
		self.temper += dt / self.gripSeconds
	end
	self:updateTame(dt)
	self:updateJump(dt)
	self.graceTime = math.max(self.graceTime - dt, 0)

	local obstacle = if self.graceTime > 0
		then nil
		else CourseObstacles.hit(self.obstacles, self.distance, self.x, stats.hitboxHalfLength, stats.hitboxHalfWidth, self:jumpHeight())
	if obstacle and stats.smashesRocks and obstacle.kind == "Rock" then
		self:smash(obstacle)
	elseif obstacle then
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
end

-- realDt is wall-clock frame time; everything in the safari simulation uses the scaled dt.
function RideController.step(self: RideController, realDt: number)
	if self.paused then
		-- Hold the pose so the welded rider doesn't drift while the safari is frozen.
		self.root.AssemblyLinearVelocity = Vector3.zero
		self:applyPose()
		return
	end
	self.timeScale = moveToward(self.timeScale, self.timeScaleTarget, self.timeScaleRate * realDt)
	local dt = realDt * self.timeScale

	if self.state == "countdown" then
		self.timer -= dt
		if self.timer <= 0 then
			self.state = "running"
			self.hud:showMessage("Go!", 0.6)
		end
	elseif self.state == "running" then
		self:updateRunning(dt)
	elseif self.state == "leaping" then
		self.elapsed += dt
		self:updateLeap(dt)
	else
		self.speed = moveToward(self.speed, 0, 80 * dt)
		self.distance += self.speed * dt
		self.jumpTime = nil
	end

	if self.state ~= "leaping" then
		self:updateSteering(realDt * math.max(self.timeScale, STEER_MIN_SCALE))
		self:applyPose()
	end

	local herds = self.herds
	if herds then
		herds:step(dt)
	end

	if self.temperEnabled then
		self.hud:setGrip(self.temper, self.stats.temperWarningAt)
	end
	self.hud:setDistance(self.distance, self.course.length)
	local target = herds and herds.target
	local canLeap = self.state == "running" and target ~= nil
	self.hud:setLeapReady(canLeap, if canLeap then target.agent.stats.displayName else nil)
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

-- Follows course-space distance (not the mount part), so the camera stays smooth mid-leap.
function RideController.updateCamera(self: RideController, dt: number)
	local camera = self.camera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local stats = self.stats
	local speedFraction = math.clamp(self.speed / stats.cruiseSpeed, 0, 1.2)
	local baseY = CourseConfig.groundY + self.rootHeight
	local worldZ = self.course.origin.Z - self.distance
	local leaping = self.state == "leaping"

	-- Sideways and height follow with a little lag; distance behind grows with speed.
	self.cameraX += (self.x * 0.65 - self.cameraX) * damp(6, dt)
	local targetY = baseY + 9 + 1.5 * speedFraction + self:jumpHeight() * 0.45 + self.leapHeight * 0.5
	self.cameraY += (targetY - self.cameraY) * damp(8, dt)
	local targetFov = 68 + 16 * speedFraction + (if leaping then 8 else 0) + (if self.boostTime > 0 then 5 else 0)
	self.fov += (targetFov - self.fov) * damp(if leaping then 6 else 3, dt)

	local back = 17 + 6 * speedFraction
	local position = Vector3.new(self.course.origin.X + self.cameraX, self.cameraY, worldZ + back)

	-- Small rhythmic rumble at speed plus crash shake.
	local phase = self.distance / stats.strideLength * 2 * math.pi
	position += Vector3.new(0, math.sin(phase * 2) * 0.06 * speedFraction, 0)
	if self.shake > 0 then
		self.shake -= dt
		local strength = math.max(self.shake, 0) * 3
		position += Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	end

	local lookAhead = 28 + 10 * speedFraction
	local lookAt = Vector3.new(self.course.origin.X + self.cameraX * 0.6 + self.x * 0.4, baseY + 1, worldZ - lookAhead)
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
	ContextActionService:UnbindAction(ACTION_LEAP)
	RunService:UnbindFromRenderStep(CAMERA_STEP)

	local leap = self.leap
	if leap then
		leap.target:destroy()
	end
	self:detachRider()
	self.agent:destroy()
	for _, part in self.hiddenParts do
		part.LocalTransparencyModifier = 0
	end

	self.camera.CameraType = Enum.CameraType.Custom
	self.camera.CameraSubject = self.humanoid
	self.camera.FieldOfView = BASE_FOV
	GuiService.TouchControlsEnabled = self.touchControlsWereEnabled
	if self.humanoid.Parent then
		self.humanoid.Sit = false
		self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	self.hud:destroy()
end

return RideController
