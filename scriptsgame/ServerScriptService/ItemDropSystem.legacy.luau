local Players = game:GetService("Players")

local function shouldDrop(tool)
	return tool:IsA("Tool")
		and tool:GetAttribute("DropOnDeath") == true
end

local function dropTool(tool, deathPosition)
	tool.Parent = workspace

	local handle = tool:FindFirstChild("Handle")

	if handle and handle:IsA("BasePart") then
		handle.CFrame = CFrame.new(deathPosition + Vector3.new(0, 1, 0))
		handle.CanCollide = true
		handle.Anchored = false
	end
end

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		if not rootPart then
			return
		end

		local deathPosition = rootPart.Position
		local player = Players:GetPlayerFromCharacter(character)

		if not player then
			return
		end

		-- Tool yang sedang dipakai
		for _, object in ipairs(character:GetChildren()) do
			if shouldDrop(object) then
				dropTool(object, deathPosition)
			end
		end

		-- Tool yang masih berada di Backpack
		local backpack = player:FindFirstChild("Backpack")

		if backpack then
			for _, object in ipairs(backpack:GetChildren()) do
				if shouldDrop(object) then
					dropTool(object, deathPosition)
				end
			end
		end
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)

	if player.Character then
		setupCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end