--!strict
-- Open-world riding prototype (D-027, R0). A practice zebra stands at the edge of the test field;
-- press its Ride prompt to mount, then ride freely in any direction:
--   • Steering comes from the standard Roblox move input (Humanoid.MoveDirection — WASD, touch
--     thumbstick, gamepad stick), camera-relative. The animal turns toward it at its own turn rate
--     with acceleration and momentum; pulling back brakes, then backs up slowly.
--   • Jump = the standard jump input (Space / touch jump button / gamepad A) → the animal jumps.
--   • Arcade movement, no physics: a downward ray keeps it on the ground (steps up small ledges,
--     falls off edges), a forward sphere cast stops it at rocks and trees and slides along them.
--   • Chase camera behind the animal; drag it with right mouse / touch / right stick, and it eases
--     back behind after a moment. FOV widens with speed.
--   • The mount is a client-side AnimalAgent with the rider welded on, as in safari rides, so the
--     character's movement replicates (multiplayer-compatible, D-016).
-- Get off: E / gamepad B / GET OFF button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FreeRideConfig = require(ReplicatedStorage.Shared.Config.FreeRideConfig)
local AnimalAgent = require(script.Parent.AnimalAgent)
local UiKit = require(script.Parent.UiKit)

local FreeRide = {}

local player = Players.LocalPlayer
local CAMERA = FreeRideConfig.camera
local CAMERA_STEP = "FreeRideCamera"
local DISMOUNT_ACTION = "FreeRideDismount"
local CAST_RADIUS = 1.2
local BODY_HALF_LENGTH = 3

type Ride = {
	humanoid: Humanoid,
	weld: WeldConstraint?,
	connections: { RBXScriptConnection },
	gui: ScreenGui,
}

local agent: AnimalAgent.AnimalAgent? = nil
local handling: FreeRideConfig.Handling = FreeRideConfig.handling.Zebra
local prompt: ProximityPrompt? = nil
local ride: Ride? = nil
local hintShown = false

-- Motion state (world space). `position` = feet; heading 0 faces -Z.
local position = Vector3.zero
local heading = 0
local speed = 0
local verticalSpeed = 0
local grounded = true
local travelled = 0
local turnSpeed = 0
local lean = 0
local slope = 0
local jumpRequested = false

-- Camera state
local cameraYaw = 0
local cameraPitch = 14
local cameraDistance = CAMERA.distance
local cameraPosition: Vector3? = nil
local lastCameraInput = -math.huge
local fov = CAMERA.baseFov
local gamepadLook = Vector2.zero
local touchLooks: { [InputObject]: Vector3 } = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function refreshFilter()
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local localAnimals = Workspace:FindFirstChild("LocalAnimals")
	if localAnimals then
		table.insert(exclude, localAnimals)
	end
	params.FilterDescendantsInstances = exclude
end

local function moveToward(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function forwardOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function groundAt(point: Vector3, above: number): number?
	local result = Workspace:Raycast(point + Vector3.new(0, above, 0), Vector3.new(0, -(above + 60), 0), params)
	return if result then result.Position.Y else nil
end

-- ── Motion ────────────────────────────────────────────────────────────────────────────────────

local function steer(dt: number, humanoid: Humanoid)
	local move = humanoid.MoveDirection
	local flat = Vector3.new(move.X, 0, move.Z)
	local amount = math.min(flat.Magnitude, 1)
	local speedFraction = math.clamp(math.abs(speed) / handling.topSpeed, 0, 1)
	turnSpeed = 0
	if amount < 0.1 then
		speed = moveToward(speed, 0, handling.coastDeceleration * dt)
		return
	end
	local direction = flat.Unit
	if direction:Dot(forwardOf(cameraYaw)) < -0.9 then
		-- Pulling straight back (toward the camera): brake, then back up slowly. Diagonally back
		-- turns the animal round instead.
		if speed > 1 then
			speed = moveToward(speed, 0, handling.braking * dt)
		else
			speed = moveToward(speed, -handling.reverseSpeed * amount, handling.acceleration * dt)
		end
		return
	end
	local desired = math.atan2(-direction.X, -direction.Z)
	local difference = wrapAngle(desired - heading)
	local turnRate = math.rad(handling.turnRateSlow + (handling.turnRateFast - handling.turnRateSlow) * speedFraction)
	local turn = math.clamp(difference, -turnRate * dt, turnRate * dt)
	heading = wrapAngle(heading + turn)
	turnSpeed = turn / dt
	-- Sharp turns slow it down, so it swings round instead of drifting wide.
	local target = handling.topSpeed * amount * math.max(math.cos(difference), 0.3)
	speed = moveToward(speed, target, (if speed < target then handling.acceleration else handling.braking) * dt)
end

local function move(dt: number)
	local forward = forwardOf(heading)
	local delta = forward * speed * dt
	if delta.Magnitude > 1e-4 then
		-- Anything taller than a step (relative to the current jump height) blocks; slide along it.
		local origin = position + Vector3.new(0, handling.stepHeight + CAST_RADIUS + 0.1, 0)
		local direction = delta.Unit * (delta.Magnitude + BODY_HALF_LENGTH)
		local hit = Workspace:Spherecast(origin, CAST_RADIUS, direction, params)
		-- Walls, and anything whose surface is above step height (e.g. the rounded top of a log).
		if hit and (hit.Normal.Y < 0.6 or hit.Position.Y - position.Y > handling.stepHeight) then
			local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			normal = if normal.Magnitude > 0.3 then normal.Unit else -delta.Unit
			local into = delta:Dot(normal)
			if into < 0 then
				local before = delta.Magnitude
				delta -= normal * into
				speed *= if before > 1e-4 then delta.Magnitude / before else 0
			end
			-- Never step closer than the body length.
			if hit.Distance < BODY_HALF_LENGTH * 0.6 then
				delta += normal * (BODY_HALF_LENGTH * 0.6 - hit.Distance)
			end
		end
	end
	local groundY = groundAt(position + delta, handling.stepHeight + 0.5)
	if not groundY and delta.Magnitude > 1e-4 then
		-- The edge of the world: don't go where there is no ground at all.
		delta = Vector3.zero
		speed = 0
		groundY = groundAt(position, handling.stepHeight + 0.5)
	end
	local nextPosition = position + delta

	if grounded and jumpRequested then
		verticalSpeed = math.sqrt(2 * handling.gravity * handling.jumpHeight)
		grounded = false
	end
	jumpRequested = false

	if grounded then
		if groundY and groundY > nextPosition.Y + handling.stepHeight then
			-- A ledge too tall to step onto that the cast missed: stay put.
			nextPosition = position
			speed = 0
		elseif groundY and groundY >= nextPosition.Y - 1.5 then
			nextPosition = Vector3.new(nextPosition.X, groundY, nextPosition.Z)
			verticalSpeed = 0
		else
			grounded = false -- ran off an edge
		end
	end
	if not grounded then
		verticalSpeed -= handling.gravity * dt
		nextPosition += Vector3.new(0, verticalSpeed * dt, 0)
		-- Land only on ground within a step of the feet (never pop up onto something tall).
		if groundY and nextPosition.Y <= groundY and groundY - nextPosition.Y <= handling.stepHeight then
			nextPosition = Vector3.new(nextPosition.X, groundY, nextPosition.Z)
			verticalSpeed = 0
			grounded = true
		end
	end
	travelled += delta.Magnitude
	position = nextPosition
end

local function pose(dt: number)
	local current = agent
	if not current then
		return
	end
	local forward = forwardOf(heading)
	local groundY = groundAt(position, 1) or position.Y
	local front = groundAt(position + forward * 2, handling.stepHeight)
	local back = groundAt(position - forward * 2, handling.stepHeight)
	local targetSlope = if grounded and front and back then math.atan((front - back) / 4) else 0
	slope += (math.clamp(targetSlope, -0.5, 0.5) - slope) * math.min(dt * 10, 1)
	local speedFraction = math.clamp(math.abs(speed) / handling.topSpeed, 0, 1)
	lean += (math.clamp(-turnSpeed * speedFraction * 0.12, -0.22, 0.22) - lean) * math.min(dt * 8, 1)
	local ground = Vector3.new(position.X, math.min(groundY, position.Y), position.Z)
	current:poseFree(ground, heading, math.abs(speed), travelled, position.Y - ground.Y, slope, lean, forward * speed + Vector3.new(0, verticalSpeed, 0))
end

-- ── Camera ────────────────────────────────────────────────────────────────────────────────────

local function updateCamera(dt: number)
	local current = agent
	local camera = Workspace.CurrentCamera
	if not current or not ride then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local speedFraction = math.clamp(math.abs(speed) / handling.topSpeed, 0, 1)

	if gamepadLook.Magnitude > 0.2 then
		cameraYaw -= math.rad(gamepadLook.X * CAMERA.stickSensitivity * dt)
		cameraPitch = math.clamp(cameraPitch - gamepadLook.Y * CAMERA.stickSensitivity * 0.5 * dt, CAMERA.minPitch, CAMERA.maxPitch)
		lastCameraInput = os.clock()
	end
	if os.clock() - lastCameraInput > CAMERA.followDelay and math.abs(speed) > 2 then
		local rate = CAMERA.followRate * (0.3 + speedFraction)
		cameraYaw = wrapAngle(cameraYaw + wrapAngle(heading - cameraYaw) * math.min(rate * dt, 1))
	end

	local focus = current.root.Position + Vector3.new(0, 3, 0) + forwardOf(heading) * CAMERA.lookAhead * speedFraction
	local rotation = CFrame.Angles(0, cameraYaw, 0) * CFrame.Angles(-math.rad(cameraPitch), 0, 0)
	local desired = focus + rotation:VectorToWorldSpace(Vector3.new(0, CAMERA.height * 0.3, cameraDistance))
	-- Keep the camera out of hills and trees.
	local blocked = Workspace:Raycast(focus, desired - focus, params)
	if blocked then
		desired = blocked.Position + (focus - desired).Unit * 0.8
	end
	local previous = cameraPosition or desired
	local smoothed = previous:Lerp(desired, math.min(dt * 14, 1))
	cameraPosition = smoothed
	fov += (CAMERA.baseFov + CAMERA.speedFov * speedFraction - fov) * math.min(dt * 4, 1)
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(smoothed, focus)
end

local function onInputChanged(input: InputObject, processed: boolean)
	if not ride then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		cameraYaw -= math.rad(input.Delta.X * CAMERA.dragSensitivity)
		cameraPitch = math.clamp(cameraPitch + input.Delta.Y * CAMERA.dragSensitivity, CAMERA.minPitch, CAMERA.maxPitch)
		lastCameraInput = os.clock()
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		cameraDistance = math.clamp(cameraDistance - input.Position.Z * 2, 10, 32)
	elseif input.UserInputType == Enum.UserInputType.Touch and touchLooks[input] then
		local delta = input.Position - touchLooks[input]
		touchLooks[input] = input.Position
		cameraYaw -= math.rad(delta.X * CAMERA.dragSensitivity)
		cameraPitch = math.clamp(cameraPitch + delta.Y * CAMERA.dragSensitivity, CAMERA.minPitch, CAMERA.maxPitch)
		lastCameraInput = os.clock()
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if not ride then
		return
	end
	-- Touches the thumbstick / buttons don't claim drag the camera.
	if input.UserInputType == Enum.UserInputType.Touch and not processed then
		touchLooks[input] = input.Position
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end

local function onInputEnded(input: InputObject)
	touchLooks[input] = nil
	if input.UserInputType == Enum.UserInputType.MouseButton2 and ride then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- ── Mount / dismount ──────────────────────────────────────────────────────────────────────────

local dismount: () -> ()

local function buildGui(): ScreenGui
	local gui = UiKit.screen("FreeRideHud", 4)
	local button = UiKit.button(gui, "GetOff", "GET OFF", "red", 24)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -22)
	button.Size = UDim2.fromOffset(170, 52)
	UiKit.autoScale(button)
	button.Activated:Connect(function()
		dismount()
	end)
	return gui
end

local function mount()
	local current = agent
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if ride or not current or not humanoid or humanoid.Health <= 0 or player:GetAttribute("InSafari") == true then
		return
	end
	refreshFilter()
	current:setRidden(true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	local weld = current:attachRider(humanoid)
	local connections: { RBXScriptConnection } = {}
	ride = { humanoid = humanoid, weld = weld, connections = connections, gui = buildGui() }

	speed, verticalSpeed, grounded, turnSpeed = 0, 0, true, 0
	cameraYaw, cameraPitch, cameraPosition, lastCameraInput = heading, 14, nil, -math.huge
	fov = Workspace.CurrentCamera.FieldOfView
	if prompt then
		prompt.Enabled = false
	end

	table.insert(connections, humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump then
			humanoid.Jump = false
			jumpRequested = true
		end
	end))
	table.insert(connections, humanoid.Died:Connect(dismount))
	table.insert(connections, RunService.PreSimulation:Connect(function(dt)
		if not ride then
			return
		end
		steer(dt, humanoid)
		move(dt)
		pose(dt)
		if position.Y < -60 then
			dismount() -- fell off the world
		end
	end))
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, updateCamera)
	ContextActionService:BindActionAtPriority(DISMOUNT_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			dismount()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonB)

	if not hintShown then
		hintShown = true
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		UiKit.toast(if touch
			then "Thumbstick to ride · JUMP to jump · drag to look around"
			else "WASD to ride · Space to jump · right-drag to look · E to get off", 6)
	end
end

dismount = function()
	local current = ride
	if not current then
		return
	end
	ride = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	RunService:UnbindFromRenderStep(CAMERA_STEP)
	ContextActionService:UnbindAction(DISMOUNT_ACTION)
	current.gui:Destroy()
	table.clear(touchLooks)
	gamepadLook = Vector2.zero
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	local humanoid = current.humanoid
	if current.weld then
		current.weld:Destroy()
	end
	humanoid.Sit = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	local character = humanoid.Parent
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local animal = agent
	if animal then
		animal:setRidden(false)
		speed, verticalSpeed, turnSpeed, lean = 0, 0, 0, 0
		if not grounded then
			position = Vector3.new(position.X, groundAt(position, 1) or position.Y, position.Z)
			grounded = true
		end
		pose(1)
		if rootPart and humanoid.Health > 0 then
			-- Step off to the animal's right side.
			local side = CFrame.Angles(0, heading, 0):VectorToWorldSpace(Vector3.new(4, 0, 0))
			rootPart.CFrame = CFrame.new(position + side + Vector3.new(0, 3, 0)) * CFrame.Angles(0, heading, 0)
			rootPart.AssemblyLinearVelocity = Vector3.zero
		end
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	camera.FieldOfView = CAMERA.baseFov
	if prompt then
		prompt.Enabled = player:GetAttribute("InSafari") ~= true
	end
end

-- ── Practice zebra ────────────────────────────────────────────────────────────────────────────

local function spawnPracticeZebra()
	local spawn = FreeRideConfig.field.practiceSpawn
	refreshFilter()
	local animal = AnimalAgent.newAt("Zebra", spawn, true)
	animal.model.Name = "PracticeZebra"
	agent = animal
	position = spawn.Position
	heading = 0
	position = Vector3.new(position.X, groundAt(position, 5) or position.Y, position.Z)
	pose(1)

	local ridePrompt = Instance.new("ProximityPrompt")
	ridePrompt.Name = "RidePrompt"
	ridePrompt.ActionText = "Ride"
	ridePrompt.ObjectText = "Practice Zebra"
	ridePrompt.KeyboardKeyCode = Enum.KeyCode.E
	ridePrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	ridePrompt.HoldDuration = 0
	ridePrompt.MaxActivationDistance = 10
	ridePrompt.RequiresLineOfSight = false
	ridePrompt.Parent = animal.root
	ridePrompt.Triggered:Connect(mount)
	prompt = ridePrompt
end

function FreeRide.isRiding(): boolean
	return ride ~= nil
end

function FreeRide.start()
	Workspace:WaitForChild("OpenWorld")
	spawnPracticeZebra()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	player:GetAttributeChangedSignal("InSafari"):Connect(function()
		local inSafari = player:GetAttribute("InSafari") == true
		if inSafari then
			dismount()
		end
		if prompt then
			prompt.Enabled = not inSafari and not ride
		end
	end)
	player.CharacterRemoving:Connect(function()
		dismount()
	end)
end

return FreeRide
