--[[
	ProximityPrompt Custom UI
	- Bulat putih kecil muncul di mesh saat mendekat
	- Notif mengambang di sebelah kanan layar, sebaris
	- PC: teks "(Press E)", HP: "(Touch)"
	- Hanya menangani prompt dengan Style = Custom
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local inputHint = isTouch and "(Touch)" or "(Press E)"

-- // GUI utama: wadah notif di kanan layar
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ProximityNotifGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "NotifContainer"
container.AnchorPoint = Vector2.new(1, 0.5)
container.Position = UDim2.new(1, -20, 0.5, 0)
container.Size = UDim2.new(0, 280, 0, 400)
container.BackgroundTransparency = 1
container.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

-- // State
local activePrompts = {} -- [prompt] = {notif, marker}
local order = 0
local currentPrompt = nil -- prompt yang dikontrol tombol E

local function getLabelText(prompt)
	if prompt.ObjectText ~= "" then
		return prompt.ActionText .. " " .. prompt.ObjectText .. "... " .. inputHint
	end
	return prompt.ActionText .. "... " .. inputHint
end

-- // Bulat putih kecil di mesh
local function createMarker(prompt)
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then return nil end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PromptMarker"
	billboard.Size = UDim2.fromOffset(18, 18)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = part

	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundColor3 = Color3.new(1, 1, 1)
	circle.BackgroundTransparency = 0.15
	circle.BorderSizePixel = 0
	circle.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	return billboard
end

-- // Notif label di kanan layar (bisa diklik/disentuh di HP)
local function createNotif(prompt)
	order += 1

	local button = Instance.new("TextButton")
	button.Name = "PromptNotif"
	button.Size = UDim2.new(1, 0, 0, 38)
	button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	button.BackgroundTransparency = 0.25
	button.Text = getLabelText(prompt)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 15
	button.Font = Enum.Font.GothamMedium
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button
	
	-- Progress bar untuk HoldDuration
	local progressBackground = Instance.new("Frame")
	progressBackground.Name = "HoldProgressBackground"
	progressBackground.Size = UDim2.new(1, -24, 0, 3)
	progressBackground.Position = UDim2.new(0, 12, 1, -6)
	progressBackground.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	progressBackground.BorderSizePixel = 0
	progressBackground.Visible = prompt.HoldDuration > 0
	progressBackground.Parent = button

	local progressFill = Instance.new("Frame")
	progressFill.Name = "HoldProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.new(1, 1, 1)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBackground
	
	local progressConnection = nil

	local function updateProgress(progress)
		progress = math.clamp(progress, 0, 1)
		progressFill.Size = UDim2.new(progress, 0, 1, 0)
	end

	local function startProgress()
		if prompt.HoldDuration <= 0 then
			return
		end

		if progressConnection then
			progressConnection:Disconnect()
		end

		local startTime = os.clock()

		progressConnection = RunService.RenderStepped:Connect(function()
			if not prompt.Parent then
				progressConnection:Disconnect()
				progressConnection = nil
				return
			end

			local elapsed = os.clock() - startTime
			local progress = elapsed / prompt.HoldDuration

			updateProgress(progress)

			if progress >= 1 then
				progressConnection:Disconnect()
				progressConnection = nil
			end
		end)
	end

	local function stopProgress()
		if progressConnection then
			progressConnection:Disconnect()
			progressConnection = nil
		end

		updateProgress(0)
	end

	-- animasi muncul
	button.TextTransparency = 1
	button.BackgroundTransparency = 1
	TweenService:Create(button, TweenInfo.new(0.25), {
		TextTransparency = 0,
		BackgroundTransparency = 0.25,
	}):Play()

	-- Touch/klik HP: sistem asli
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if not prompt.Parent then
			return
		end

		prompt:InputHoldBegin()
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if not prompt.Parent then
			return
		end

		prompt:InputHoldEnd()
	end)

	return button

end

local function removePrompt(prompt)
	local data = activePrompts[prompt]
	if not data then return end
	activePrompts[prompt] = nil
	if data.actionConn then data.actionConn:Disconnect() end
	if data.notif then data.notif:Destroy() end
	if data.marker then data.marker:Destroy() end
	if currentPrompt == prompt then
		currentPrompt = nil
		for p in pairs(activePrompts) do
			currentPrompt = p
			break
		end
	end
end

-- // Event prompt
ProximityPromptService.PromptShown:Connect(function(prompt)
	-- hanya prompt Custom yang pakai UI ini, prompt Default biarkan native
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	if activePrompts[prompt] then return end

	activePrompts[prompt] = {
		notif = createNotif(prompt),
		marker = createMarker(prompt),
	}
	currentPrompt = prompt

	-- update teks notif saat ActionText berubah (Open <-> Close)
	local data = activePrompts[prompt]
	data.actionConn = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		if data.notif then
			data.notif.Text = getLabelText(prompt)
		end
	end)
end)

ProximityPromptService.PromptHidden:Connect(removePrompt)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	-- update teks notif karena ActionText berubah (Open <-> Close)
	local data = activePrompts[prompt]
	if data and data.notif then
		data.notif.Text = getLabelText(prompt)
	end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	local data = activePrompts[prompt]
	if not data or prompt.HoldDuration <= 0 then
		return
	end

	local progressBackground = data.notif:FindFirstChild("HoldProgressBackground")
	local progressFill = progressBackground and progressBackground:FindFirstChild("HoldProgressFill")

	if not progressFill then
		return
	end

	local startTime = os.clock()

	if data.progressConnection then
		data.progressConnection:Disconnect()
	end

	data.progressConnection = RunService.RenderStepped:Connect(function()
		if not prompt.Parent then
			data.progressConnection:Disconnect()
			data.progressConnection = nil
			return
		end

		local progress = math.clamp(
			(os.clock() - startTime) / prompt.HoldDuration,
			0,
			1
		)

		progressFill.Size = UDim2.new(progress, 0, 1, 0)

		if progress >= 1 then
			data.progressConnection:Disconnect()
			data.progressConnection = nil
		end
	end)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	local data = activePrompts[prompt]
	if not data then
		return
	end

	if data.progressConnection then
		data.progressConnection:Disconnect()
		data.progressConnection = nil
	end

	local progressBackground = data.notif:FindFirstChild("HoldProgressBackground")
	local progressFill = progressBackground and progressBackground:FindFirstChild("HoldProgressFill")

	if progressFill then
		progressFill.Size = UDim2.new(0, 0, 1, 0)
	end
end)

-- // Input keyboard E (PC)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E and currentPrompt then
		currentPrompt:InputHoldBegin()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E and currentPrompt then
		currentPrompt:InputHoldEnd()
	end
end)