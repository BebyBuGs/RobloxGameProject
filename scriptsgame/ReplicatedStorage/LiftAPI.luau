--[[
	LiftAPI - API publik untuk sistem elevator.
	Bisa di-require dari script server MAUPUN script client.

	Contoh penggunaan dari script lain:

	local LiftAPI = require(game.ReplicatedStorage.LiftAPI)

	-- Aktifkan / matikan lift
	LiftAPI:SetEnabled(false)   -- matikan lift
	LiftAPI:SetEnabled(true)    -- aktifkan lift

	-- Panggil lift ke lantai tertentu (1 atau 5)
	LiftAPI:RequestFloor(5)

	-- Baca kondisi lift
	print(LiftAPI:IsEnabled())
	print(LiftAPI:GetCurrentFloor())
	print(LiftAPI:GetStatus())  -- "idle" | "moving" | "door_open"

	-- Atur ketinggian lantai (Y posisi tengah kabin) -- untuk kalibrasi lantai 5 nanti
	LiftAPI:SetFloorHeight(5, 54.5)

	-- Subscribe event
	LiftAPI.OnFloorChanged.Event:Connect(function(floor) print("Lift di lantai", floor) end)
	LiftAPI.OnStateChanged.Event:Connect(function(status) print("Status:", status) end)

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiftAPI = {}

-- RemoteEvent untuk komunikasi client <-> server
local Remote = ReplicatedStorage:FindFirstChild("LiftRemote")
if not Remote then
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "LiftRemote"
	Remote.Parent = ReplicatedStorage
end

-- Event publik yang bisa di-subscribe script lain
LiftAPI.OnFloorChanged = Instance.new("BindableEvent")
LiftAPI.OnFloorChanged.Name = "OnFloorChanged"
LiftAPI.OnStateChanged = Instance.new("BindableEvent")
LiftAPI.OnStateChanged.Name = "OnStateChanged"
LiftAPI.OnWarning = Instance.new("BindableEvent")
LiftAPI.OnWarning.Name = "OnWarning"

-- State internal (di-update oleh LiftController di server)
local state = {
    enabled = true,
    currentFloor = 1,
    targetFloor = nil,
    status = "idle", -- idle | moving | door_open
    floorHeights = { [1] = 6.5, [5] = 54.5 },
    activeFloors = { 1, 5 },
}

-- Handler yang didaftarkan oleh LiftController (server)
local serverHandler = nil

local isServer = game:GetService("RunService"):IsServer()

function LiftAPI:RegisterServer(handler)
    serverHandler = handler
end

-- Internal: sinkronkan state (dipanggil controller server)
function LiftAPI:_UpdateState(newState)
    local floorChanged = state.currentFloor ~= newState.currentFloor
    local statusChanged = state.status ~= newState.status
    state.enabled = newState.enabled
    state.currentFloor = newState.currentFloor
    state.targetFloor = newState.targetFloor
    state.status = newState.status
    if newState.floorHeights then
        state.floorHeights = newState.floorHeights
    end
    if floorChanged then
        LiftAPI.OnFloorChanged:Fire(state.currentFloor)
    end
    if statusChanged then
        LiftAPI.OnStateChanged:Fire(state.status)
    end
end

-- ====== PUBLIC API ======

-- Aktifkan / matikan lift (dari script lain)
function LiftAPI:SetEnabled(enabled)
    if isServer then
        if serverHandler then serverHandler.SetEnabled(enabled) end
    else
        Remote:FireServer("SetEnabled", enabled)
    end
end

function LiftAPI:IsEnabled()
    return state.enabled
end

-- Panggil lift ke lantai tertentu
function LiftAPI:RequestFloor(floor)
    if isServer then
        if serverHandler then serverHandler.RequestFloor(floor) end
    else
        Remote:FireServer("RequestFloor", floor)
    end
end

function LiftAPI:GetCurrentFloor()
    return state.currentFloor
end

function LiftAPI:GetTargetFloor()
    return state.targetFloor
end

function LiftAPI:GetStatus()
    return state.status
end

-- Atur ketinggian lantai (Y posisi tengah kabin). Berguna untuk kalibrasi lantai 5 nanti.
function LiftAPI:SetFloorHeight(floor, height)
    if isServer then
        if serverHandler then serverHandler.SetFloorHeight(floor, height) end
    else
        Remote:FireServer("SetFloorHeight", floor, height)
    end
end

function LiftAPI:GetFloorHeight(floor)
    return state.floorHeights[floor]
end

function LiftAPI:GetActiveFloors()
    return state.activeFloors
end

return LiftAPI