-- Permanent FPS + R Mouse Lock/Unlock
-- Kamera memakai sistem bawaan Roblox (default)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 0.5
local camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local mouseLocked = true
local touchCameraInput = nil

local touchCameraInput = nil

local yaw = 0
local pitch = 0
local maxPitch = math.rad(80)

local character = nil
local rootPart = nil
local waist = nil

local function getSensitivityMultiplier()
	local sensitivityValue = 30

	local playerGui = player:FindFirstChild("PlayerGui")

	if playerGui then
		local settingsGui = playerGui:FindFirstChild("SettingsGui")
		local settingsPanel = settingsGui and settingsGui:FindFirstChild("SettingsPanel")
		local content = settingsPanel and settingsPanel:FindFirstChild("Content")
		local cameraSettings = content and content:FindFirstChild("CameraSettings")

		if cameraSettings then
			local savedSensitivity =
				cameraSettings:GetAttribute("Sensitivity")

			if typeof(savedSensitivity) == "number" then
				sensitivityValue = math.clamp(savedSensitivity, 1, 100)
			end
		end
	end

	return 0.0025 * (sensitivityValue / 30)
end

local function setupCharacter(newCharacter)
	character = newCharacter
	rootPart = character:WaitForChild("HumanoidRootPart")
	local upperTorso = character:WaitForChild("UpperTorso")
	waist = upperTorso:WaitForChild("Waist")

	-- Permanent FPS
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	-- FPS dimulai dalam keadaan mouse terkunci
	mouseLocked = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	-- Ambil arah awal karakter sebagai arah kamera
	local lookVector = rootPart.CFrame.LookVector

	yaw = math.atan2(-lookVector.X, -lookVector.Z)
	pitch = 0
end

local function lockMouse()
	mouseLocked = true

	player.CameraMode = Enum.CameraMode.LockFirstPerson

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

local function unlockMouse()
	mouseLocked = false

	-- Mouse bebas untuk UI/menu
	-- Kamera tetap berada pada jarak FPS
	player.CameraMode = Enum.CameraMode.Classic

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

-- R = toggle mouse lock/unlock

-- Blok klik kanan singkat, tetapi tahan klik kanan tetap berfungsi
local RIGHT_CLICK_HOLD_TIME = 0.2
local rightMouseDown = false
local rightMouseDownTime = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
		return
	end

	rightMouseDown = true
	rightMouseDownTime = os.clock()

	task.delay(RIGHT_CLICK_HOLD_TIME, function()
		if rightMouseDown then
			-- Sudah ditahan cukup lama.
			-- Jangan ganggu fungsi klik kanan bawaan Roblox.
			return
		end
	end)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
		return
	end

	local holdTime = os.clock() - rightMouseDownTime
	rightMouseDown = false

	if holdTime < RIGHT_CLICK_HOLD_TIME then
		-- Klik kanan singkat.
		-- Tidak menjalankan fungsi apa pun dari FPS kita.
		return
	end

	-- Tahan klik kanan dilepas.
	-- Tidak kita ganggu.
end)


UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		if mouseLocked then
			unlockMouse()
		else
			lockMouse()
		end
	end
end)

-- Touch camera untuk HP
UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
	if gameProcessed then
		return
	end

	-- Hanya sentuhan sisi kanan layar yang menjadi kamera.
	local viewportWidth = camera.ViewportSize.X

	if touch.Position.X >= viewportWidth * 0.5 then
		touchCameraInput = touch
	end
end)

UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
	if touch ~= touchCameraInput then
		return
	end

	if not mouseLocked then
		return
	end

	local delta = touch.Delta
	local currentSensitivity = getSensitivityMultiplier()
	
	print("Touch Sensitivity:", currentSensitivity)

	yaw -= delta.X * currentSensitivity
	pitch -= delta.Y * currentSensitivity

	pitch = math.clamp(pitch, -maxPitch, maxPitch)

	if rootPart then
		rootPart.CFrame =
			CFrame.new(rootPart.Position)
			* CFrame.Angles(0, yaw, 0)
	end
end)

UserInputService.TouchEnded:Connect(function(touch)
	if touch == touchCameraInput then
		touchCameraInput = nil
	end
end)

RunService.PreSimulation:Connect(function()
	if not character or not character.Parent then
		return
	end

	if not waist then
		return
	end

	local lookVector = camera.CFrame.LookVector

	local cameraPitch =
		math.asin(math.clamp(lookVector.Y, -1, 1))

	cameraPitch = math.clamp(
		cameraPitch,
		-math.rad(80),
		math.rad(80)
	)

	waist.Transform =
		CFrame.Angles(cameraPitch, 0, 0)
end)

local ContextActionService = game:GetService("ContextActionService")


player.CharacterAdded:Connect(setupCharacter)


if player.Character then
	setupCharacter(player.Character)
end

