local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for GUI
local screenGui = playerGui:WaitForChild("LobbyGui")
local mainFrame = screenGui:WaitForChild("MainFrame")
local createFrame = screenGui:WaitForChild("CreateServerFrame")
local playServerBtn = screenGui:WaitForChild("PlayServer")

-- Main Frame Elements
local serverList = mainFrame:WaitForChild("ServerList")
local emptyLabel = serverList:WaitForChild("EmptyLabel")
local createButton = mainFrame:WaitForChild("CreateServerButton")
local refreshButton = mainFrame:WaitForChild("RefreshButton")
local statusLabel = mainFrame:WaitForChild("StatusLabel")

-- Create Server Frame Elements
local serverNameBox = createFrame:WaitForChild("ServerNameBox")
local maxPlayersBox = createFrame:WaitForChild("MaxPlayersBox")
local confirmCreateBtn = createFrame:WaitForChild("ConfirmCreateBtn")
local closeCreateBtn = createFrame:WaitForChild("CloseBtn")
local minusBtn = createFrame:WaitForChild("MinusBtn")
local plusBtn = createFrame:WaitForChild("PlusBtn")
local friendOnlyCheckbox = createFrame:WaitForChild("FriendOnlyCheckbox")

-- Server Detail Frame Elements
local serverDetailFrame = screenGui:WaitForChild("ServerDetailFrame")
local detailNameLabel = serverDetailFrame:WaitForChild("ServerNameLabel")
local detailHostLabel = serverDetailFrame:WaitForChild("HostLabel")
local detailPlayerCountLabel = serverDetailFrame:WaitForChild("PlayerCountLabel")
local detailPlayerListFrame = serverDetailFrame:WaitForChild("PlayerListFrame")
local detailStartBtn = serverDetailFrame:WaitForChild("StartBtn")
local detailLeaveBtn = serverDetailFrame:WaitForChild("LeaveBtn")

-- Max players state
local currentMaxPlayers = 4
local MIN_PLAYERS = 2
local MAX_PLAYERS = 10

-- Friend Only state
local friendOnly = false

-- Remote Events
local lobbyRemote = ReplicatedStorage:WaitForChild("LobbyRemote")

-- State
local currentServerId = nil
local servers = {}

-- Initially hide MainFrame, CreateServerFrame, and ServerDetailFrame
mainFrame.Visible = false
createFrame.Visible = false
serverDetailFrame.Visible = false

-- Toggle PlayServer button - Open/Close MainFrame
local isMainFrameOpen = false

playServerBtn.MouseButton1Click:Connect(function()
	if isMainFrameOpen then
		-- Close MainFrame
		mainFrame.Visible = false
		playServerBtn.Text = "PlayServer"
		isMainFrameOpen = false
	else
		-- Open MainFrame
		mainFrame.Visible = true
		playServerBtn.Text = "Tutup Server"
		isMainFrameOpen = true
		lobbyRemote:FireServer("GetServerList")
	end
end)

-- Update server list UI
local function updateServerListUI(serverListData)
	servers = serverListData
	
	-- Clear existing server cards
	for _, child in pairs(serverList:GetChildren()) do
		if child.Name ~= "EmptyLabel" and child.Name ~= "UIListLayout" then
			child.Parent = nil
		end
	end
	
	-- Show/hide empty label
	emptyLabel.Visible = #serverListData == 0
	
	-- Create server cards
	for _, serverData in pairs(serverListData) do
		local serverCard = Instance.new("Frame")
		serverCard.Name = "ServerCard_" .. serverData.id
		serverCard.Size = UDim2.new(1, 0, 0, 80)
		serverCard.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
		serverCard.BorderSizePixel = 0
		serverCard.Parent = serverList
		
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = serverCard
		
		-- Server name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 0, 30)
		nameLabel.Position = UDim2.new(0, 10, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = serverData.name
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = serverCard
		
		-- Host indicator
		local hostLabel = Instance.new("TextLabel")
		hostLabel.Size = UDim2.new(0.4, 0, 0, 20)
		hostLabel.Position = UDim2.new(0, 10, 0, 35)
		hostLabel.BackgroundTransparency = 1
		hostLabel.Text = "👑 Host: " .. serverData.hostName
		hostLabel.TextColor3 = Color3.new(1, 0.8, 0.2)
		hostLabel.TextScaled = true
		hostLabel.Font = Enum.Font.Gotham
		hostLabel.Parent = serverCard
		
		-- Player count
		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0.4, 0, 0, 20)
		countLabel.Position = UDim2.new(0, 10, 0, 55)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "👥 " .. serverData.playerCount .. "/" .. serverData.maxPlayers .. " players"
		countLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
		countLabel.TextScaled = true
		countLabel.Font = Enum.Font.Gotham
		countLabel.Parent = serverCard
		
		-- Friend Only badge
		if serverData.friendOnly then
			local friendBadge = Instance.new("TextLabel")
			friendBadge.Size = UDim2.new(0, 100, 0, 20)
			friendBadge.Position = UDim2.new(0.6, 0, 0, 35)
			friendBadge.BackgroundTransparency = 1
			friendBadge.Text = "🔒 Friend Only"
			friendBadge.TextColor3 = Color3.new(0.6, 0.8, 1)
			friendBadge.TextScaled = true
			friendBadge.Font = Enum.Font.Gotham
			friendBadge.Parent = serverCard
		end
		
		-- Join button
		local joinBtn = Instance.new("TextButton")
		joinBtn.Name = "JoinBtn"
		joinBtn.Size = UDim2.new(0, 100, 0, 35)
		joinBtn.Position = UDim2.new(1, -110, 0.5, -17)
		joinBtn.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
		joinBtn.Text = "JOIN"
		joinBtn.TextColor3 = Color3.new(1, 1, 1)
		joinBtn.TextScaled = true
		joinBtn.Font = Enum.Font.GothamBold
		joinBtn.Parent = serverCard
		
		local joinCorner = Instance.new("UICorner")
		joinCorner.CornerRadius = UDim.new(0, 6)
		joinCorner.Parent = joinBtn
		
		-- Join button click
		joinBtn.MouseButton1Click:Connect(function()
			currentServerId = serverData.id
			lobbyRemote:FireServer("JoinServer", {serverId = currentServerId})
		end)
	end
	
	-- Update canvas size
	serverList.CanvasSize = UDim2.new(0, 0, 0, #serverListData * 88)
end

-- Show server detail view (when player joins a server)
local function showServerDetailView(data)
	-- Hide main frame and reset button
	mainFrame.Visible = false
	playServerBtn.Text = "PlayServer"
	isMainFrameOpen = false
	createFrame.Visible = false
	
	-- Update server name
	detailNameLabel.Text = data.server.name
	
	-- Update host indicator
	if data.isHost then
		detailHostLabel.Text = "👑 Anda adalah HOST"
		detailHostLabel.TextColor3 = Color3.new(1, 0.8, 0.2)
	else
		detailHostLabel.Text = "👑 Host: " .. data.server.hostName
		detailHostLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	end
	
	-- Update player count
	detailPlayerCountLabel.Text = "Players (" .. #data.players .. "/" .. data.server.maxPlayers .. "):"
	
	-- Clear existing player list
	for _, child in pairs(detailPlayerListFrame:GetChildren()) do
		if child.Name ~= "UIListLayout" then
			child.Parent = nil
		end
	end
	
	-- Populate player list
	for _, playerName in pairs(data.players) do
		local playerLabel = Instance.new("TextLabel")
		playerLabel.Size = UDim2.new(1, 0, 0, 25)
		playerLabel.BackgroundTransparency = 1
		playerLabel.Text = playerName
		playerLabel.TextColor3 = Color3.new(1, 1, 1)
		playerLabel.TextScaled = true
		playerLabel.Font = Enum.Font.Gotham
		playerLabel.Parent = detailPlayerListFrame
	end
	
	-- Show/hide start button based on host status
	detailStartBtn.Visible = data.isHost
	
	-- Show the detail frame
	serverDetailFrame.Visible = true
end

-- Start Game button (host only)
detailStartBtn.MouseButton1Click:Connect(function()
	lobbyRemote:FireServer("StartGame")
end)

-- Leave Server button
detailLeaveBtn.MouseButton1Click:Connect(function()
	lobbyRemote:FireServer("LeaveServer")
	serverDetailFrame.Visible = false
	mainFrame.Visible = true
	playServerBtn.Text = "Tutup Server"
	isMainFrameOpen = true
end)

-- Create Server Button
createButton.MouseButton1Click:Connect(function()
	createFrame.Visible = true
	mainFrame.Visible = false
end)

-- Close Create Server
closeCreateBtn.MouseButton1Click:Connect(function()
	createFrame.Visible = false
	mainFrame.Visible = true
end)

-- Minus button - decrease max players
minusBtn.MouseButton1Click:Connect(function()
	if currentMaxPlayers > MIN_PLAYERS then
		currentMaxPlayers -= 1
		maxPlayersBox.Text = tostring(currentMaxPlayers)
	end
end)

-- Plus button - increase max players
plusBtn.MouseButton1Click:Connect(function()
	if currentMaxPlayers < MAX_PLAYERS then
		currentMaxPlayers += 1
		maxPlayersBox.Text = tostring(currentMaxPlayers)
	end
end)

-- Friend Only checkbox toggle
friendOnlyCheckbox.MouseButton1Click:Connect(function()
	friendOnly = not friendOnly
	if friendOnly then
		friendOnlyCheckbox.BackgroundColor3 = Color3.new(0.2, 0.6, 0.3)
		friendOnlyCheckbox.Text = "✓"
	else
		friendOnlyCheckbox.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
		friendOnlyCheckbox.Text = ""
	end
end)

-- Confirm Create Server
confirmCreateBtn.MouseButton1Click:Connect(function()
	lobbyRemote:FireServer("CreateServer", {
		serverName = serverNameBox.Text,
		maxPlayers = currentMaxPlayers,
		friendOnly = friendOnly
	})
end)

-- Refresh Button
refreshButton.MouseButton1Click:Connect(function()
	lobbyRemote:FireServer("GetServerList")
end)

-- Handle server events
lobbyRemote.OnClientEvent:Connect(function(action, data)
	if action == "UpdateServerList" then
		updateServerListUI(data)
		
	elseif action == "CreateServerResult" then
		if data.success then
			statusLabel.Text = "Server berhasil dibuat!"
			statusLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
			createFrame.Visible = false
		else
			statusLabel.Text = data.message
			statusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
		end
		
	elseif action == "JoinServerResult" then
		if data.success then
			statusLabel.Text = data.message
			statusLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
		else
			statusLabel.Text = data.message
			statusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
		end
		
	elseif action == "UpdateServerDetail" then
		showServerDetailView(data)
		
	elseif action == "LeaveServerResult" then
		-- Hide detail frame
		serverDetailFrame.Visible = false
		mainFrame.Visible = true
		playServerBtn.Text = "Tutup Server"
		isMainFrameOpen = true
		statusLabel.Text = data.message
		statusLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
		
	elseif action == "StartGameResult" then
		if not data.success then
			statusLabel.Text = data.message
			statusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
		end
		
	elseif action == "Teleporting" then
		statusLabel.Text = "Teleporting ke game..."
		statusLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
		
	elseif action == "TeleportSuccess" then
		statusLabel.Text = data
		statusLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
		
	elseif action == "TeleportFailed" then
		statusLabel.Text = data
		statusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
	end
end)

-- Don't request server list on start - wait for PlayServer button click

print("Lobby Client Script loaded successfully!")