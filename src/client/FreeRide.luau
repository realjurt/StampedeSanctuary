--!strict
-- Open-world riding (D-027). Practice zebra, giraffe and elephant stand at the edge of the test
-- field (R1); press one's Ride prompt to mount, then ride freely in any direction:
--   • Steering comes from the standard Roblox move input (Humanoid.MoveDirection — WASD, touch
--     thumbstick, gamepad stick), camera-relative. Each species' motion and handling live in
--     FreeRideMotion / FreeRideConfig; this module owns input, camera, prompts and mounting.
--   • Jump = the standard jump input (Space / touch jump button / gamepad A) → the animal jumps.
--   • Chase camera behind the animal; drag it with right mouse / touch / right stick, and it eases
--     back behind after a moment. FOV widens with speed; hard landings shake it a little.
--   • The mount is a client-side AnimalAgent with the rider welded on, as in safari rides, so the
--     character's movement replicates (multiplayer-compatible, D-016).
--   • The elephant shoves "Pushables" aside; the server moves them (PushObstacle → PushableService).
-- Get off: E / gamepad B / GET OFF button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FreeRideConfig = require(ReplicatedStorage.Shared.Config.FreeRideConfig)
local FreeRideMotion = require(script.Parent.FreeRideMotion)
local UiKit = require(script.Parent.UiKit)

local FreeRide = {}

local player = Players.LocalPlayer
local CAMERA = FreeRideConfig.camera
local CAMERA_STEP = "FreeRideCamera"
local DISMOUNT_ACTION = "FreeRideDismount"

local forwardOf = FreeRideMotion.forwardOf
local wrapAngle = FreeRideMotion.wrapAngle

type Ride = {
	mount: FreeRideMotion.Mount,
	humanoid: Humanoid,
	weld: WeldConstraint?,
	connections: { RBXScriptConnection },
	gui: ScreenGui,
}

local mounts: { FreeRideMotion.Mount } = {}
local prompts: { [FreeRideMotion.Mount]: ProximityPrompt } = {}
local ride: Ride? = nil
local hintsShown: { [string]: boolean } = {}
local pushRemote: RemoteEvent? = nil

-- Camera state
local cameraYaw = 0
local cameraPitch = 14
local cameraZoom = 0 -- mouse-wheel offset from the species' distance
local cameraPosition: Vector3? = nil
local lastCameraInput = -math.huge
local fov = CAMERA.baseFov
local shake = 0
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
	FreeRideMotion.refreshFilter(exclude)
end

local function setPromptsEnabled(enabled: boolean)
	for _, prompt in prompts do
		prompt.Enabled = enabled
	end
end

-- ── Camera ────────────────────────────────────────────────────────────────────────────────────

local function updateCamera(dt: number)
	local current = ride
	local camera = Workspace.CurrentCamera
	if not current then
		return
	end
	local mount = current.mount
	local handling = mount.handling
	camera.CameraType = Enum.CameraType.Scriptable
	local speedFraction = math.clamp(math.abs(mount.speed) / handling.topSpeed, 0, 1)

	if gamepadLook.Magnitude > 0.2 then
		cameraYaw -= math.rad(gamepadLook.X * CAMERA.stickSensitivity * dt)
		cameraPitch = math.clamp(cameraPitch - gamepadLook.Y * CAMERA.stickSensitivity * 0.5 * dt, CAMERA.minPitch, CAMERA.maxPitch)
		lastCameraInput = os.clock()
	end
	if os.clock() - lastCameraInput > CAMERA.followDelay and math.abs(mount.speed) > 2 then
		local rate = CAMERA.followRate * (0.3 + speedFraction)
		cameraYaw = wrapAngle(cameraYaw + wrapAngle(mount.heading - cameraYaw) * math.min(rate * dt, 1))
	end

	local root = mount.agent.root.Position
	local focus = root + Vector3.new(0, 3 + handling.cameraHeight, 0) + forwardOf(mount.heading) * CAMERA.lookAhead * speedFraction
	local rotation = CFrame.Angles(0, cameraYaw, 0) * CFrame.Angles(-math.rad(cameraPitch), 0, 0)
	local distance = math.clamp(handling.cameraDistance + cameraZoom, 10, 34)
	local desired = focus + rotation:VectorToWorldSpace(Vector3.new(0, CAMERA.height * 0.3, distance))
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
	-- Landing shake: a quick decaying jitter, applied after smoothing so it stays crisp.
	shake *= math.exp(-dt * 12)
	local t = os.clock() * 40
	local jitter = Vector3.new(math.sin(t * 1.3), math.sin(t), math.sin(t * 0.7)) * shake
	camera.CFrame = CFrame.lookAt(smoothed + jitter, focus)
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
		cameraZoom = math.clamp(cameraZoom - input.Position.Z * 2, -8, 14)
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

-- ── Per-frame update ──────────────────────────────────────────────────────────────────────────

local dismount: () -> ()

local function onStep(dt: number)
	local current = ride
	for _, animal in mounts do
		if current and current.mount == animal then
			animal:steer(dt, current.humanoid.MoveDirection, cameraYaw)
			local result = animal:move(dt)
			if result.landed then
				shake = math.max(shake, result.landed * animal.handling.landingShake)
			end
			local remote = pushRemote
			if remote then
				for _, part in result.pushed do
					remote:FireServer(part, forwardOf(animal.heading))
				end
			end
		end
		animal:pose(dt) -- a standing animal just breathes
	end
	if current and current.mount.position.Y < -60 then
		local fallen = current.mount
		dismount() -- fell off the world
		fallen:reset()
	end
end

-- ── Mount / dismount ──────────────────────────────────────────────────────────────────────────

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

local function mount(target: FreeRideMotion.Mount)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if ride or not humanoid or humanoid.Health <= 0 or player:GetAttribute("InSafari") == true then
		return
	end
	refreshFilter()
	local agent = target.agent
	agent:setRidden(true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	local weld = agent:attachRider(humanoid)
	local connections: { RBXScriptConnection } = {}
	ride = { mount = target, humanoid = humanoid, weld = weld, connections = connections, gui = buildGui() }

	target:settle()
	cameraYaw, cameraPitch, cameraPosition, lastCameraInput, shake = target.heading, 14, nil, -math.huge, 0
	fov = Workspace.CurrentCamera.FieldOfView
	setPromptsEnabled(false)

	table.insert(connections, humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump then
			humanoid.Jump = false
			target:requestJump()
		end
	end))
	table.insert(connections, humanoid.Died:Connect(dismount))
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, updateCamera)
	ContextActionService:BindActionAtPriority(DISMOUNT_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			dismount()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonB)

	if not hintsShown[target.species] then
		local first = next(hintsShown) == nil
		hintsShown[target.species] = true
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local controls = if touch
			then "Thumbstick to ride · JUMP to jump · drag to look around"
			else "WASD to ride · Space to jump · right-drag to look · E to get off"
		UiKit.toast(if first then `{target.handling.hint}\n{controls}` else target.handling.hint, 6)
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
	local animal = current.mount
	animal.agent:setRidden(false)
	animal:settle()
	if rootPart and humanoid.Health > 0 then
		-- Step off to the animal's right side, clear of its body.
		local side = CFrame.Angles(0, animal.heading, 0):VectorToWorldSpace(Vector3.new(animal.halfWidth + 2.5, 0, 0))
		rootPart.CFrame = CFrame.new(animal.position + side + Vector3.new(0, 3, 0)) * CFrame.Angles(0, animal.heading, 0)
		rootPart.AssemblyLinearVelocity = Vector3.zero
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	camera.FieldOfView = CAMERA.baseFov
	setPromptsEnabled(player:GetAttribute("InSafari") ~= true)
end

-- ── Practice animals ──────────────────────────────────────────────────────────────────────────

local function spawnPracticeAnimal(species: string, home: CFrame)
	local animal = FreeRideMotion.new(species, home)
	animal.agent.model.Name = "Practice" .. species
	table.insert(mounts, animal)

	local ridePrompt = Instance.new("ProximityPrompt")
	ridePrompt.Name = "RidePrompt"
	ridePrompt.ActionText = "Ride"
	ridePrompt.ObjectText = "Practice " .. species
	ridePrompt.KeyboardKeyCode = Enum.KeyCode.E
	ridePrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	ridePrompt.HoldDuration = 0
	ridePrompt.MaxActivationDistance = 10
	ridePrompt.RequiresLineOfSight = false
	ridePrompt.Parent = animal.agent.root
	ridePrompt.Triggered:Connect(function()
		mount(animal)
	end)
	prompts[animal] = ridePrompt
end

function FreeRide.isRiding(): boolean
	return ride ~= nil
end

function FreeRide.start()
	Workspace:WaitForChild("OpenWorld")
	pushRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PushObstacle") :: RemoteEvent
	refreshFilter()
	for _, entry in FreeRideConfig.field.practiceAnimals do
		spawnPracticeAnimal(entry.species, entry.spawn)
	end
	refreshFilter() -- LocalAnimals exists now
	RunService.PreSimulation:Connect(onStep)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	player:GetAttributeChangedSignal("InSafari"):Connect(function()
		local inSafari = player:GetAttribute("InSafari") == true
		if inSafari then
			dismount()
		end
		setPromptsEnabled(not inSafari and not ride)
	end)
	player.CharacterRemoving:Connect(function()
		dismount()
	end)
end

return FreeRide
