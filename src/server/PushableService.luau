--!strict
-- Shoves the test field's "Pushables" (crates, bushes) when a rider's elephant ploughs into them
-- (R1). The mount is client-side, so the client asks; the server owns the parts and checks the
-- part is a pushable, the rider is seated and close enough, and the push direction is sane before
-- moving it — everyone sees the same result. Knocked-away pushables go back home after a while.
-- TODO(R2): once mounts are server-known, also check the rider's species can push.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FreeRideConfig = require(ReplicatedStorage.Shared.Config.FreeRideConfig)
local Net = require(script.Parent.Net)

local PUSH = FreeRideConfig.pushables
local PART_COOLDOWN = 0.25

local PushableService = {}

local folder: Folder? = nil
local movedAt: { [BasePart]: number } = {}

local function onPush(player: Player, part: any, direction: any)
	local pushables = folder
	if not pushables or typeof(part) ~= "Instance" or not part:IsA("BasePart") or part.Parent ~= pushables then
		return
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude ~= direction.Magnitude or direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return
	end
	if os.clock() - (movedAt[part] or -math.huge) < PART_COOLDOWN then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or not humanoid.Sit or humanoid.Health <= 0 then
		return
	end
	local offset = part.Position - rootPart.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	if flatOffset.Magnitude - part.Size.Magnitude / 2 > PUSH.maxReach then
		return
	end
	-- Mostly forward, partly away from the rider, so obstacles scatter to the sides.
	local forward = Vector3.new(direction.X, 0, direction.Z).Unit
	local away = if flatOffset.Magnitude > 0.1 then flatOffset.Unit else forward
	local push = (forward + away * 0.6).Unit
	part.AssemblyLinearVelocity = push * PUSH.pushSpeed + Vector3.new(0, PUSH.pushLift, 0)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8
	movedAt[part] = os.clock()
end

-- Knocked-over pushables (or ones fallen off the world) go back once nobody has touched them for a bit.
local function resetLoop()
	while true do
		task.wait(2)
		local pushables = folder
		if pushables then
			local now = os.clock()
			for _, part in pushables:GetChildren() do
				local home = part:GetAttribute("Home")
				if part:IsA("BasePart") and typeof(home) == "CFrame" then
					local far = (part.Position - home.Position).Magnitude > PUSH.resetDistance or part.Position.Y < -20
					if far and now - (movedAt[part] or 0) > PUSH.resetDelay then
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
						part.CFrame = home
						movedAt[part] = nil
					end
				end
			end
		end
	end
end

function PushableService.start()
	local openWorld = Workspace:WaitForChild("OpenWorld")
	local pushables = openWorld:WaitForChild("Pushables") :: Folder
	folder = pushables
	for _, part in pushables:GetChildren() do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil) -- server-simulated, so a client can't move them directly
		end
	end
	-- No per-player cooldown: one shove can hit several crates in the same frame. Each part is
	-- limited instead (PART_COOLDOWN), and only parts right next to the rider are accepted.
	Net.on("PushObstacle", 0, onPush)
	task.spawn(resetLoop)
end

return PushableService
