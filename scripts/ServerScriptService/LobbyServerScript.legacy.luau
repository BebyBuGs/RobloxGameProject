-- Lobby Server Script
-- Handles server creation, joining, and teleportation

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLACE_ID = 132537513627197 -- Target game place ID
local MAX_PLAYERS_LIMIT = 8-- Maximum players per server

local lobbyRemote = ReplicatedStorage:WaitForChild("LobbyRemote")

-- Server data storage
local servers = {} -- {id, name, host, hostName, maxPlayers, players}
local serverIdCounter = 0

-- Friend cache for filtering friend-only servers
local friendCache = {}
local friendCacheTime = {}
local CACHE_DURATION = 30

local function getFriendSet(player)
	local now = os.clock()
	local cached = friendCache[player.UserId]
	if cached and (now - friendCacheTime[player.UserId]) < CACHE_DURATION then
		return cached
	end

	local friendSet = {}
	local success, friendPages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)

	if success and friendPages then
		for _, item in ipairs(friendPages:GetCurrentPage()) do
			friendSet[item.Id] = true
		end
	end

	friendCache[player.UserId] = friendSet
	friendCacheTime[player.UserId] = now
	return friendSet
end

local function getFilteredServerList(player)
	local friendSet = nil
	local serverListData = {}

	for _, server in ipairs(servers) do
		local canSee = true
		if server.friendOnly and player ~= server.host then
			if not friendSet then
				friendSet = getFriendSet(player)
			end
			canSee = friendSet[server.host.UserId] == true
		end

		if canSee then
			table.insert(serverListData, {
				id = server.id,
				name = server.name,
				hostName = server.hostName,
				playerCount = #server.players,
				maxPlayers = server.maxPlayers,
				friendOnly = server.friendOnly
			})
		end
	end

	return serverListData
end

-- Helper function to get server by ID
local function getServerById(serverId)
	for _, server in ipairs(servers) do
		if server.id == serverId then
			return server
		end
	end
	return nil
end

-- Helper function to get server by player
local function getServerByPlayer(player)
	for _, server in ipairs(servers) do
		for _, p in ipairs(server.players) do
			if p == player then
				return server
			end
		end
	end
	return nil
end

-- Helper function to broadcast server list to all players
local function broadcastServerList()
	for _, player in ipairs(Players:GetPlayers()) do
		local filteredList = getFilteredServerList(player)
		lobbyRemote:FireClient(player, "UpdateServerList", filteredList)
	end
end

-- Helper function to update server detail for all players in server
local function updateServerDetail(server)
	local playerNames = {}
	for _, p in ipairs(server.players) do
		table.insert(playerNames, p.Name)
	end
	
	for _, player in ipairs(server.players) do
		local isHost = player == server.host
		lobbyRemote:FireClient(player, "UpdateServerDetail", {
			server = {
				name = server.name,
				hostName = server.hostName,
				maxPlayers = server.maxPlayers
			},
			players = playerNames,
			isHost = isHost
		})
	end
end

-- Safe teleport function with retry
local ATTEMPT_LIMIT = 5
local RETRY_DELAY = 1

local function safeTeleport(placeId, players)
	local attemptIndex = 0
	local success, result
	
	repeat
		success, result = pcall(function()
			local teleportOptions = Instance.new("TeleportOptions")
			teleportOptions.ShouldReserveServer = true
			return TeleportService:TeleportAsync(placeId, players, teleportOptions)
		end)
		attemptIndex += 1
		if not success then
			task.wait(RETRY_DELAY)
		end
	until success or attemptIndex == ATTEMPT_LIMIT
	
	if not success then
		warn("Teleport failed:", result)
	end
	
	return success, result
end

-- Handle client requests
lobbyRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "GetServerList" then
		-- Send filtered server list to requesting player
		local serverListData = getFilteredServerList(player)
		lobbyRemote:FireClient(player, "UpdateServerList", serverListData)
		
	elseif action == "CreateServer" then
		-- Check if player is already in a server
		local existingServer = getServerByPlayer(player)
		if existingServer then
			lobbyRemote:FireClient(player, "CreateServerResult", {
				success = false,
				message = "Anda sudah berada di server!"
			})
			return
		end
		
		-- Validate max players
		local maxPlayers = math.clamp(data.maxPlayers or 4, 2, MAX_PLAYERS_LIMIT)
		
		-- Create new server
		serverIdCounter += 1
		local newServer = {
			id = serverIdCounter,
			name = data.serverName or "Server " .. serverIdCounter,
			host = player,
			hostName = player.Name,
			maxPlayers = maxPlayers,
			friendOnly = data.friendOnly == true,
			players = {player}
		}
		table.insert(servers, newServer)
		
		lobbyRemote:FireClient(player, "CreateServerResult", {
			success = true,
			message = "Server berhasil dibuat!"
		})
		
		broadcastServerList()
		updateServerDetail(newServer)
		
	elseif action == "JoinServer" then
		-- Check if player is already in a server
		local existingServer = getServerByPlayer(player)
		if existingServer then
			lobbyRemote:FireClient(player, "JoinServerResult", {
				success = false,
				message = "Anda sudah berada di server!"
			})
			return
		end
		
		local server = getServerById(data.serverId)
		if not server then
			lobbyRemote:FireClient(player, "JoinServerResult", {
				success = false,
				message = "Server tidak ditemukan!"
			})
			return
		end
		
		if #server.players >= server.maxPlayers then
			lobbyRemote:FireClient(player, "JoinServerResult", {
				success = false,
				message = "Server sudah penuh!"
			})
			return
		end
		
		table.insert(server.players, player)
		
		lobbyRemote:FireClient(player, "JoinServerResult", {
			success = true,
			message = "Berhasil bergabung ke " .. server.name
		})
		
		broadcastServerList()
		updateServerDetail(server)
		
	elseif action == "LeaveServer" then
		local server = getServerByPlayer(player)
		if not server then
			lobbyRemote:FireClient(player, "LeaveServerResult", {
				success = false,
				message = "Anda tidak berada di server manapun!"
			})
			return
		end
		
		-- Remove player from server
		for i, p in ipairs(server.players) do
			if p == player then
				table.remove(server.players, i)
				break
			end
		end
		
		-- If host left, assign new host or delete server
		if server.host == player then
			if #server.players > 0 then
				server.host = server.players[1]
				server.hostName = server.players[1].Name
			else
				-- Remove empty server
				for i, s in ipairs(servers) do
					if s.id == server.id then
						table.remove(servers, i)
						break
					end
				end
			end
		end
		
		lobbyRemote:FireClient(player, "LeaveServerResult", {
			success = true,
			message = "Berhasil keluar dari server"
		})
		
		broadcastServerList()
		
		-- Update remaining players
		if #server.players > 0 then
			updateServerDetail(server)
		end
		
	elseif action == "StartGame" then
		local server = getServerByPlayer(player)
		if not server then
			lobbyRemote:FireClient(player, "StartGameResult", {
				success = false,
				message = "Anda tidak berada di server!"
			})
			return
		end
		
		if server.host ~= player then
			lobbyRemote:FireClient(player, "StartGameResult", {
				success = false,
				message = "Hanya host yang bisa memulai game!"
			})
			return
		end
		
		-- Notify all players about teleport
		for _, p in ipairs(server.players) do
			lobbyRemote:FireClient(p, "Teleporting", {})
		end
		
		-- Teleport all players
		local success, result = safeTeleport(PLACE_ID, server.players)
		
		if success then
			for _, p in ipairs(server.players) do
				lobbyRemote:FireClient(p, "TeleportSuccess", "Teleport berhasil!")
			end
			
			-- Remove server after successful teleport
			for i, s in ipairs(servers) do
				if s.id == server.id then
					table.remove(servers, i)
					break
				end
			end
			broadcastServerList()
		else
			for _, p in ipairs(server.players) do
				lobbyRemote:FireClient(p, "TeleportFailed", "Teleport gagal. Coba lagi!")
			end
		end
	end
end)

-- Handle player leaving the game
Players.PlayerRemoving:Connect(function(player)
	-- Clean up friend cache
	friendCache[player.UserId] = nil
	friendCacheTime[player.UserId] = nil

	local server = getServerByPlayer(player)
	if server then
		-- Remove player from server
		for i, p in ipairs(server.players) do
			if p == player then
				table.remove(server.players, i)
				break
			end
		end
		
		-- If host left, assign new host or delete server
		if server.host == player then
			if #server.players > 0 then
				server.host = server.players[1]
				server.hostName = server.players[1].Name
				updateServerDetail(server)
			else
				-- Remove empty server
				for i, s in ipairs(servers) do
					if s.id == server.id then
						table.remove(servers, i)
						break
					end
				end
			end
		end
		
		broadcastServerList()
	end
end)

print("Lobby Server Script loaded successfully!")