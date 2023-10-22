local gunModule = require(game.ReplicatedStorage.GunModule)

local dropBombRemote = game.ReplicatedStorage.DropBomb
local loadBombRemote = game.ReplicatedStorage.LoadBombs
local bombHitRemote = game.ReplicatedStorage.BombHit
local decreaseFuelRemote = game.ReplicatedStorage.DecreaseFuel

local contextActionService = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

local fire = game.ReplicatedStorage.Fire

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local cam = workspace.CurrentCamera

local jet = script:WaitForChild("Jet").Value
local stop = script:WaitForChild("Stop")

local engine = jet.MainParts.Engine
local seat = jet.MainParts.VehicleSeat
local turret = jet.Turret
local turretHinge = jet.MainParts.TurretPos.HingeConstraint
local turretMotor = jet.MainParts.TurretPos.Motor6D
local turretOffset = turretMotor.C0

local fireL = jet.MainParts.G1.Fire
local fireR = jet.MainParts.G2.Fire

local bombSpawnL = jet.Weapons.BombSpawnL
local bombSpawnR = jet.Weapons.BombSpawnR
local bombL
local bombR
local bombWeldL
local bombWeldR
local kMaxBombLife = 20

local direction = engine:WaitForChild("Direction")
local thrust = engine:WaitForChild("Thrust")

local screenGui
local throttleui
local statsui

local kMaxSpeed = 400
local kMinSpeed = -10
local kMinSpeedToTurn = 70
local kMinFlySpeed = 70
local jetFalling = false

local holdingMouse = false
local lastFired = 0
local fireRate = game.ReplicatedStorage.BulletInfo.FireRate.Value

local lastFuelDecrease
local fuelDecreaseRate = 2

local trails = {
	jet.MainParts.WingTrails.TrailL,
	jet.MainParts.WingTrails.TrailR,
	jet.MainParts.TailTrails.TrailL,
	jet.MainParts.TailTrails.TrailR
}

local heartbeat

local function onGround()
	local origin = jet.MainParts.Engine.Position
	local direction = Vector3.new(0, -10, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {jet}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	
	return raycastResult
end

local function makeMassless(massless)
	for _, part in ipairs(jet:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Massless = massless
		end
	end
end

local function dropBomb(actionName, inputState, inputObject)
	if not (inputState == Enum.UserInputState.Begin) then return end
	
	if jet.Weapons:FindFirstChild("BombL") then
		dropBombRemote:FireServer(bombL, bombWeldL, kMaxBombLife, jet.Stats.Missiles)
		
	elseif jet.Weapons:FindFirstChild("BombR") then
		dropBombRemote:FireServer(bombR, bombWeldR, kMaxBombLife, jet.Stats.Missiles)
	end
end

local function mousePressed(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		holdingMouse = true
	elseif inputState == Enum.UserInputState.End then
		holdingMouse = false
	end
end

local function FOV(speed)
	return math.max((0.05 * speed) + 70, 85)
end

local function fireLife(speed)
	return NumberRange.new(0.002 * speed, 0.002 * speed)
end

local function updateStatUi()
	for frame, val in pairs(statsui) do
		frame.Bar.Size = UDim2.new(val.Value / val:GetAttribute("MAX"), 0, 1, 0)
		frame.TextLabel.Text = val.Value
	end
end

local function enableTrails(enabled)
	for _, trail in ipairs(trails) do
		trail.Enabled = enabled
	end
end

local function worldCFrameToC0ObjectSpace(motor6DJoint,worldCFrame) -- For rotating the turret
	local part1CF = motor6DJoint.Part1.CFrame
	local c1Store = motor6DJoint.C1
	local c0Store = motor6DJoint.C0
	local relativeToPart1 =c0Store*c1Store:Inverse()*part1CF:Inverse()*worldCFrame*c1Store
	relativeToPart1 -= relativeToPart1.Position

	local goalC0CFrame = relativeToPart1+c0Store.Position--New orientation but keep old C0 joint position
	return goalC0CFrame
end

-- TODO WORK ON FREE FALLING ORIENTATION (use hitboxes of the jet to detect if on ground or not)

local function Update(dt)
	-- Thrust
	local speed = math.floor(seat.CFrame.LookVector:Dot(seat.Velocity))

	if seat.Throttle == 1 and speed < kMaxSpeed then
		thrust.VectorVelocity += Vector3.new(1, 0, 0)
	elseif seat.Throttle == -1 and speed > kMinSpeed then
		thrust.VectorVelocity -= Vector3.new(2, 0, 0)
	end

	-- Direction
	if speed > kMinSpeedToTurn then
		direction.CFrame = CFrame.new(engine.Position, engine.Position + cam.CFrame.LookVector.Unit * 1e8) * CFrame.Angles(0, math.rad(90), 0)
	end
	
	-- Free fall
	if not onGround() and speed < kMinFlySpeed then
		if not jetFalling then
			direction.CFrame = CFrame.new(0, 0, 0)
			thrust.VectorVelocity = Vector3.new(0, -120, 0)
			jetFalling = true
		end
	else
		thrust.VectorVelocity *= Vector3.new(1, 0, 1)
		jetFalling = false
	end

	-- GUI
	throttleui.Back.Frame.Size = UDim2.new(1, 0, (speed / kMaxSpeed), 0)
	throttleui.Speed.Text = math.ceil(speed)
	updateStatUi()

	-- Particles
	fireL.Lifetime = fireLife(speed)
	fireR.Lifetime = fireLife(speed)
	if speed > kMinFlySpeed or jetFalling then
		enableTrails(true)
	else
		enableTrails(false)
	end
	
	-- FOV
	cam.FieldOfView = FOV(speed)
		
	-- Turret	
	local goalCF = CFrame.lookAt(turret.Stand.Position, mouse.Hit.Position, turretMotor.Part0.CFrame.UpVector)
	turretMotor.C0 = worldCFrameToC0ObjectSpace(turretMotor, goalCF) * CFrame.Angles(0, math.rad(90), 0)
	
	
	if holdingMouse and tick() - lastFired > fireRate and jet.Stats.Ammo.Value > 0 then
		gunModule.simulateProjectile(player, jet.Turret, game.ReplicatedStorage.BulletInfo.Damage.Value)
		fire:FireServer(jet.Turret.BulletSpawn, jet.Stats.Ammo)
		lastFired = tick()
	end
	
	-- Fuel
	if tick() - lastFuelDecrease > fuelDecreaseRate then
		decreaseFuelRemote:FireServer(jet.Stats.Fuel)
		lastFuelDecrease = tick()
	end
end

local function Start()
	makeMassless(true)
	
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	mouse.Icon = "http://www.roblox.com/asset/?id=534716960"

	fireL.Enabled = true
	fireR.Enabled = true

	screenGui = jet.StatsGui:Clone()
	screenGui.Parent = player.PlayerGui
	throttleui = screenGui.Throttle
	statsui = {
		[screenGui.Stats.AmmoBack] = jet.Stats.Ammo,
		[screenGui.Stats.FuelBack] = jet.Stats.Fuel,
		[screenGui.Stats.HealthBack] = jet.Stats.Health,
		[screenGui.Stats.MissileBack] = jet.Stats.Missiles
	}

	direction.Enabled = true
	thrust.Enabled = true
	
	bombL, bombR, bombWeldL, bombWeldR = loadBombRemote:InvokeServer(jet, bombSpawnL, bombSpawnR)
	
	bombL.Body.Touched:Connect(function(hit)
		print(hit.Name)
		bombHitRemote:FireServer(jet, bombL, hit)
	end)
	bombR.Body.Touched:Connect(function(hit)
		print(hit.Name)
		bombHitRemote:FireServer(jet, bombR, hit)
	end)
	
	contextActionService:BindAction(
		"Fire", 
		mousePressed,
		true,
		Enum.UserInputType.MouseButton1
	)
	
	contextActionService:BindAction(
		"Bomb",
		dropBomb,
		true,
		Enum.UserInputType.MouseButton2
	)
	
	lastFuelDecrease = tick()
		
	heartbeat = game:GetService("RunService").Heartbeat:Connect(Update)
end

local function Stop()
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	mouse.Icon = ""

	fireL.Enabled = false
	fireR.Enabled = false
	direction.Enabled = false
	thrust.Enabled = false
	thrust.VectorVelocity = Vector3.new(0, 0, 0)
	
	makeMassless(false)
	
	contextActionService:UnbindAction("Fire")
	contextActionService:UnbindAction("Bomb")
	
	cam.FieldOfView = 70

	player.PlayerGui.StatsGui:Destroy()
	heartbeat:Disconnect()
	script:Destroy()
end

Start()

if stop.Value then Stop() return end

stop.Changed:Connect(function(shouldStop)
	if not shouldStop then return end
	Stop()
end)
