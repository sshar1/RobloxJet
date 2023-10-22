local tweenService = game:GetService("TweenService")

local damageHum = game.ReplicatedStorage:WaitForChild("DamageHum")
local damageVehicle = game.ReplicatedStorage:WaitForChild("DamageVehicle")
local fire = game.ReplicatedStorage:WaitForChild("Fire")
local dropBomb = game.ReplicatedStorage:WaitForChild("DropBomb")
local loadBombs = game.ReplicatedStorage:WaitForChild("LoadBombs")
local bombHit = game.ReplicatedStorage:WaitForChild("BombHit")
local decreaseFuel = game.ReplicatedStorage:WaitForChild("DecreaseFuel")

damageHum.OnServerEvent:Connect(function(client, humanoid, damage)
	if humanoid and (humanoid ~= client.Character.Humanoid) then
		humanoid:TakeDamage(damage)
	end
end)

damageVehicle.OnServerEvent:Connect(function(client, hitbox, damage)
	hitbox.Health.Value -= damage * 2
end)

fire.OnServerEvent:Connect(function(client, bulletSpawn, ammo)
	if ammo ~= nil then
		ammo.Value -= 1
	end
	
	fire:FireAllClients(client, bulletSpawn)
end)

local function onBombLoad(client, jet, bombSpawnL, bombSpawnR)
	local bomb = game.ReplicatedStorage.Bomb
	local bombL
	local bombR
	local bombWeldL
	local bombWeldR

	bombL = bomb:Clone()
	bombL.Name = "BombL"
	bombL.Body.CFrame = bombSpawnL.CFrame * CFrame.Angles(0, 0, math.rad(270))
	bombWeldL = Instance.new("WeldConstraint", bombL)
	bombWeldL.Part0 = bombL.Body
	bombWeldL.Part1 = bombSpawnL
	bombL.Parent = jet.Weapons

	bombR = bomb:Clone()
	bombR.Name = "BombR"
	bombR.Body.CFrame = bombSpawnR.CFrame * CFrame.Angles(0, 0, math.rad(270))
	bombWeldR = Instance.new("WeldConstraint", bombR)
	bombWeldR.Part0 = bombR.Body
	bombWeldR.Part1 = bombSpawnR
	bombR.Parent = jet.Weapons

	return bombL, bombR, bombWeldL, bombWeldR
end

loadBombs.OnServerInvoke = onBombLoad

dropBomb.OnServerEvent:Connect(function(client, bomb, bombWeld, bombLife, ammo)
	
	if ammo ~= nil then
		ammo.Value -= 1
	end
	
	bombWeld:Destroy()
	bomb.Parent = workspace
	bomb.Body.AlignOrientation.CFrame = CFrame.Angles(0, 0, math.rad(90))
	bomb.Body.AlignOrientation.Enabled = true
	bomb.Body.LinearVelocity.Enabled = true
	bomb.Body.Beam.Enabled = true
	bomb.Dropped.Value = true

	delay(bombLife, function()
		if bomb then
			bomb:Destroy()
		end
	end)
end)

local function destroyJet(j)
	if j.Destroyed.Value then return end
	
	j.JetHandler.JetClientScript.Stop.Value = true
	j.Destroyed.Value = true
	task.wait(0.1)
	
	j.MainParts.Engine:Destroy()

	for _, v in ipairs(j:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Massless = false
			v.CanCollide = false
			v.CanTouch = false
			tweenService:Create(v, TweenInfo.new(10, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
		elseif v:IsA("Weld") or v:IsA("WeldConstraint") then
			v:Destroy()
		end
	end

	j.MainParts.VehicleSeat:Destroy()

	delay(10, function()
		j:Destroy()
	end)
end

bombHit.OnServerEvent:Connect(function(client, jet, bomb, hit)
	--print('bomb hit')
	if hit:IsDescendantOf(jet) or not bomb.Dropped.Value then return end
	print('running hit')

	local hitBoxTouched = hit:IsA("BasePart") and hit.Name == "Hitbox"
	local charTouched = hit.Parent:FindFirstChildOfClass("Humanoid")
	
	bomb.Body.CanTouch = false

	if hitBoxTouched or charTouched then
		print('touched')
		bomb.Body.CanTouch = false
		bomb.Body.Beam:Destroy()
		bomb.Body.LinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
		bomb.Front.ExplosionParticles.Enabled = true
		bomb.Body.Transparency = 1

		bomb.Body.Anchored = true
		bomb.Front.Anchored = true
		bomb.Back.Anchored = true

		local expl = Instance.new("Explosion")
		expl.Position = bomb.Body.Position
		expl.BlastRadius = 50
		expl.ExplosionType = Enum.ExplosionType.NoCraters
		expl.Parent = workspace

		expl.Hit:Connect(function(part)
			if part:IsA("BasePart") and part.Name == "Hitbox" and part:FindFirstAncestor("Jet") == jet then -- if hit own jet

				if jet.MainParts.VehicleSeat.Occupant then -- Kill anyone in the jet
					jet.MainParts.VehicleSeat.Occupant:TakeDamage(100)
				end

				destroyJet(jet)
			end
		end)

		if hitBoxTouched then
			hit.Parent.Parent.Stats.Health.Value -= 100
		end

		delay(5, function()
			bomb.Front.ExplosionParticles.Enabled = false
			task.wait(3)
			bomb:Destroy()
		end)

	elseif hit:IsA("BasePart") and (not (hit:IsDescendantOf(jet))) then -- hit some random part
		bomb.Body.CanTouch = false
		bomb.Body.Beam:Destroy()
		bomb.Body.LinearVelocity:Destroy()
		bomb.Body.AlignOrientation:Destroy()
		bomb.Body.CanCollide = true
		bomb.Body.Massless = false

		tweenService:Create(bomb.Body, TweenInfo.new(10, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
		delay(10, function()
			bomb:Destroy()
		end)
	end
end)

decreaseFuel.OnServerEvent:Connect(function(client, fuel) 
	fuel.Value -= 1
end)
