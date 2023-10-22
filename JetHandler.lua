local proxPromptService = game:GetService("ProximityPromptService")
local physicsService = game:GetService("PhysicsService")

local jet = script.Parent
local seat = jet.MainParts.VehicleSeat
local enterPrompt = seat.EnterPrompt

local jetClientScript = script.JetClientScript

local occupiedClientScript
local occupiedPlayer

local healthDamage = {
	[jet.FireSpawns.WingR.Fire] = 300,
	[jet.FireSpawns.BaseL.Fire] = 150,
	[jet.FireSpawns.Front.Fire] = 50
}

local function setCharMassless(character, massless)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Massless = massless
		end
	end
end

proxPromptService.PromptTriggered:Connect(function(prompt, player)
	
	if prompt == enterPrompt then
		
		if seat.Occupant then return end

		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

		if not humanoid then return end

		seat:Sit(humanoid)
		enterPrompt.Enabled = false
		setCharMassless(player.Character, true)
		jet.PrimaryPart:SetNetworkOwner(player)
		occupiedClientScript = jetClientScript:Clone()
		occupiedClientScript.Jet.Value = jet
		occupiedClientScript.Parent = player.Backpack
		occupiedPlayer = player
	end
end)

seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	if not seat then return end
	if seat.Occupant then return end
	
	if occupiedPlayer.Character then
		setCharMassless(occupiedPlayer, false)
	end

	if occupiedClientScript.Parent then
		occupiedClientScript.Stop.Value = true

		local client = occupiedClientScript
		delay(3, function()
			client:Destroy()
		end)
	end
	
	if jet.PrimaryPart then
		enterPrompt.Enabled = true
		jet.PrimaryPart:SetNetworkOwnershipAuto()
	end
	
	occupiedClientScript = nil
	occupiedPlayer = nil
end)

jet.Stats.Health.Changed:Connect(function()
	local health = jet.Stats.Health.Value
	
	for fire, h in healthDamage do
		if health > h then
			fire.Enabled = false
		else
			fire.Enabled = true
		end
	end
end)
