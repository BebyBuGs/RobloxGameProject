-- CameraSettings
-- Mengatur FOV dari SettingsGui

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local DEFAULT_FOV = 75
local MIN_FOV = 50
local MAX_FOV = 120

local function getCameraSettings()
	local playerGui = player:WaitForChild("PlayerGui")
	local settingsGui = playerGui:WaitForChild("SettingsGui")
	local settingsPanel = settingsGui:WaitForChild("SettingsPanel")
	local content = settingsPanel:WaitForChild("Content")
	local cameraSettings = content:WaitForChild("CameraSettings")

	return cameraSettings
end

local cameraSettings = getCameraSettings()

local DEFAULT_SENSITIVITY = 30

local function getSensitivity()
	local value = cameraSettings:GetAttribute("Sensitivity")

	if typeof(value) ~= "number" then
		return DEFAULT_SENSITIVITY
	end

	return math.clamp(value, 1, 100)
end

local function updateSensitivity()
	local value = getSensitivity()

	-- 30 = baseline/native
	-- 1  = sangat lambat
	-- 100 = sangat cepat
	UserInputService.MouseDeltaSensitivity =
		value / DEFAULT_SENSITIVITY
end

cameraSettings:GetAttributeChangedSignal("Sensitivity"):Connect(
	updateSensitivity
)

updateSensitivity()

local function getFOV()
	local savedFOV = cameraSettings:GetAttribute("CameraFOV")

	if typeof(savedFOV) == "number" then
		return math.clamp(savedFOV, MIN_FOV, MAX_FOV)
	end

	return DEFAULT_FOV
end

local function updateFOV()
	camera.FieldOfView = getFOV()
end

cameraSettings:GetAttributeChangedSignal("CameraFOV"):Connect(updateFOV)

cameraSettings:GetAttributeChangedSignal("Sensitivity"):Connect(function()
	local sensitivity = cameraSettings:GetAttribute("Sensitivity")

	if typeof(sensitivity) == "number" then
		print("[CameraSettings] Sensitivity:", sensitivity)
	end
end)

local UserGameSettings = UserSettings():GetService("UserGameSettings")

print("[Roblox Sensitivity]", UserGameSettings.MouseSensitivity)

updateFOV()