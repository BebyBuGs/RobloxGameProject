--[[
	LiftWarningClient - Menampilkan peringatan di layar player
	(misal: tombol lantai rusak ditekan, lift dimatikan, dll).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Remote = ReplicatedStorage:WaitForChild("LiftRemote")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Bangun GUI peringatan
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LiftWarningGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "WarningFrame"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0.12, 0)
frame.Size = UDim2.new(0, 480, 0, 64)
frame.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local label = Instance.new("TextLabel")
label.Name = "Message"
label.Size = UDim2.new(1, -24, 1, 0)
label.Position = UDim2.new(0, 12, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextWrapped = true
label.Text = ""
label.Parent = frame

local currentHideTask = nil
local currentFadeTween = nil

local function showWarning(message)
	label.Text = message
	frame.Visible = true
	frame.BackgroundTransparency = 0.1

	-- Batalkan tugas sembunyi & fade lama agar tidak menimpa peringatan baru
	if currentHideTask then
		currentHideTask:Cancel()
		currentHideTask = nil
	end
	if currentFadeTween then
		currentFadeTween:Cancel()
		currentFadeTween = nil
	end

	currentHideTask = task.delay(3.5, function()
		local fadeOut = TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		currentFadeTween = fadeOut
		fadeOut:Play()
		fadeOut.Completed:Wait()
		-- Hanya sembunyikan jika tween ini masih yang terbaru
		if currentFadeTween == fadeOut then
			frame.Visible = false
			currentFadeTween = nil
		end
	end)
end

Remote.OnClientEvent:Connect(function(action, ...)
	if action == "Warning" then
		showWarning(...)
	end
end)