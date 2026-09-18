--[[
	LiftController v2 - Kontrol utama elevator.
	Logika sesuai permintaan:
	1. Pemain menekan tombol Call di panel lantai.
	   - Jika lift sudah di lantai itu -> pintu terbuka.
	   - Jika belum -> lift bergerak ke lantai itu, lalu pintu terbuka.
	2. Sebelum memilih nomor lantai, tombol Buka/Tutup pintu TIDAK berfungsi.
	3. Setelah memilih nomor lantai, Destination_Floor menampilkan tujuan.
	4. Tombol Tutup pintu baru berfungsi -> pintu tertutup.
	5. Setelah 3 detik, lift bergerak naik/turun.
	6. Floor_Indicator menampilkan lantai saat ini (hanya angka/nama).
	7. Door_Open_Button baru berfungsi SETELAH lift sampai di tujuan.

	Koordinat berhenti:
	- Lantai 1: 12.81, 6.5, -50.31
	- Lantai 5: 12.81, 54.5, -50.31
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiftAPI = require(ReplicatedStorage:WaitForChild("LiftAPI"))
local Remote = ReplicatedStorage:WaitForChild("LiftRemote")

-- ====== KONFIGURASI ======
local CONFIG = {
	ActiveFloors = { 1, 5 },
	BrokenFloors = { 2, 3, 4, 6, 7, 8, 9 },
	FloorHeights = { [1] = 6.5, [5] = 54.5 },
	DoorSlide = 5.1,
	DoorDuration = 1.0,
	CloseDelay = 3.0,
	MoveSpeed = 40,
	WarningMessage = "Pintu lift di lantai 2/3 sedang rusak. Hanya lantai 1 dan 5 yang aktif.",
}

-- ====== REFERENSI OBJEK ======
local lift = workspace:WaitForChild("Lift")
local elevator = lift:WaitForChild("Elevator")
local carControl = elevator:WaitForChild("Car_Controll")
local panelControl = lift:WaitForChild("Panel_Control")

local landingDoors = {}
for i = 1, 5 do
	local model = lift:FindFirstChild("Landing_Door_" .. i)
	if model then landingDoors[i] = model end
end

local landingPanels = {}
for i = 1, 5 do
	local panel = panelControl:FindFirstChild("LandingControll_" .. i)
	if panel then landingPanels[i] = panel end
end

-- ====== STATE ======
local state = {
	enabled = true,
	currentFloor = 1,
	targetFloor = nil,
	status = "idle",
	floorHeights = CONFIG.FloorHeights,
}
local busy = false
local doorOpen = false
local welds = {}

-- ====== FUNGSI BANTU ======
local function getFloorHeight(floor)
	return CONFIG.FloorHeights[floor]
end

local function isActiveFloor(floor)
	for _, f in ipairs(CONFIG.ActiveFloors) do
		if f == floor then return true end
	end
	return false
end

local function isBrokenFloor(floor)
	for _, f in ipairs(CONFIG.BrokenFloors) do
		if f == floor then return true end
	end
	return false
end

local function sendWarning(player, message)
	if player then
		Remote:FireClient(player, "Warning", message)
	end
	LiftAPI.OnWarning:Fire(message)
end

-- ====== INDICATOR (hanya angka/nama lantai, tanpa status) ======
local function ensureIndicator(part)
	if not part then return end
	local sg = part:FindFirstChildOfClass("SurfaceGui")
	if not sg then return end
	local label = sg:FindFirstChild("Label")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = ""
		label.Parent = sg
	end
end

local function setIndicatorText(part, text)
	local sg = part and part:FindFirstChildOfClass("SurfaceGui")
	local label = sg and sg:FindFirstChild("Label")
	if label then
		label.Text = text
	end
end

local function setupIndicators()
	ensureIndicator(carControl:FindFirstChild("Floor_Indicator"))
	ensureIndicator(carControl:FindFirstChild("Destination_Floor"))
	for _, panel in pairs(landingPanels) do
		ensureIndicator(panel:FindFirstChild("Floor_Indicator"))
		ensureIndicator(panel:FindFirstChild("Destination_Floor"))
	end
end

local function updateIndicators()
	local floorText = tostring(state.currentFloor)
	local destText = state.targetFloor and tostring(state.targetFloor) or "-"

	setIndicatorText(carControl:FindFirstChild("Floor_Indicator"), floorText)
	setIndicatorText(carControl:FindFirstChild("Destination_Floor"), destText)

	for _, panel in pairs(landingPanels) do
		setIndicatorText(panel:FindFirstChild("Floor_Indicator"), floorText)
		setIndicatorText(panel:FindFirstChild("Destination_Floor"), destText)
	end
end

-- ====== PINTU ======
local carDoorOffsets = {}
local landingDoorClosed = {}

local function recordDoors()
	local carPivot = elevator.PrimaryPart.CFrame
	for _, name in ipairs({ "Pintu_Kiri", "Pintu_Kanan" }) do
		local door = elevator:FindFirstChild(name)
		if door then
			carDoorOffsets[door] = carPivot:Inverse() * door.CFrame
		end
	end
	for _, model in pairs(landingDoors) do
		for _, name in ipairs({ "Pintu_Kiri", "Pintu_Kanan" }) do
			local door = model:FindFirstChild(name)
			if door then
				landingDoorClosed[door] = door.CFrame
			end
		end
	end
end

local function getCarDoorClosed(door)
	return elevator.PrimaryPart.CFrame * carDoorOffsets[door]
end

local function setDoors(open, duration)
	local tweens = {}

	local function tween(door, target)
		if not door then return end
		local t = TweenService:Create(door, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = target })
		t:Play()
		table.insert(tweens, t)
	end

	for _, name in ipairs({ "Pintu_Kiri", "Pintu_Kanan" }) do
		local door = elevator:FindFirstChild(name)
		if door then
			local closed = getCarDoorClosed(door)
			local target = closed
			if open then
				local dir = (name == "Pintu_Kiri") and -1 or 1
				target = CFrame.new(closed.Position + Vector3.new(dir * CONFIG.DoorSlide, 0, 0)) * closed.Rotation
			end
			tween(door, target)
		end
	end

	local landing = landingDoors[state.currentFloor]
	if landing then
		for _, name in ipairs({ "Pintu_Kiri", "Pintu_Kanan" }) do
			local door = landing:FindFirstChild(name)
			if door then
				local closed = landingDoorClosed[door]
				local target = closed
				if open then
					local dir = (name == "Pintu_Kiri") and -1 or 1
					target = CFrame.new(closed.Position + Vector3.new(dir * CONFIG.DoorSlide, 0, 0)) * closed.Rotation
				end
				tween(door, target)
			end
		end
	end

	for _, t in ipairs(tweens) do
		t.Completed:Wait()
	end
end

-- ====== PERGERAKAN KABIN ======
local function getMoveDuration(floor)
	local dist = math.abs(getFloorHeight(floor) - elevator.PrimaryPart.Position.Y)
	return math.clamp(dist / CONFIG.MoveSpeed, 1, 4)
end

local function moveCarToFloor(floor)
	local targetY = getFloorHeight(floor)
	local currentCFrame = elevator.PrimaryPart.CFrame
	local targetCFrame = CFrame.new(currentCFrame.Position.X, targetY, currentCFrame.Position.Z) * currentCFrame.Rotation

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = currentCFrame
	cframeValue.Changed:Connect(function(cf)
		elevator:PivotTo(cf)
	end)

	local tween = TweenService:Create(cframeValue, TweenInfo.new(getMoveDuration(floor), Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = targetCFrame })
	tween:Play()
	tween.Completed:Wait()
	cframeValue:Destroy()
end

-- ====== WELD PLAYER KE KABIN ======
local function weldPlayersToCar()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local p = hrp.Position
				local carPos = elevator.PrimaryPart.Position
				local inX = math.abs(p.X - carPos.X) < 7.5
				local inZ = math.abs(p.Z - carPos.Z) < 7.5
				local inY = p.Y > carPos.Y - 6.5 and p.Y < carPos.Y + 6.5
				if inX and inZ and inY then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.PlatformStand = true
					end
					local weld = Instance.new("Weld")
					weld.Name = "LiftWeld"
					weld.Part0 = elevator.PrimaryPart
					weld.Part1 = hrp
					weld.C0 = elevator.PrimaryPart.CFrame:Inverse() * hrp.CFrame
					weld.Parent = hrp
					table.insert(welds, weld)
				end
			end
		end
	end
end

local function unweldPlayers()
	for _, weld in ipairs(welds) do
		if weld and weld.Parent then
			local hrp = weld.Part1
			if hrp then
				local char = hrp.Parent
				local humanoid = char and char:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.PlatformStand = false
				end
			end
			weld:Destroy()
		end
	end
	welds = {}
end

-- ====== TOMBOL ======
local buttonColors = {}

local function recordButtonColors()
	for _, part in ipairs(carControl:GetChildren()) do
		if part:IsA("BasePart") then
			buttonColors[part] = part.Color
		end
	end
	for _, panel in pairs(landingPanels) do
		for _, part in ipairs(panel:GetChildren()) do
			if part:IsA("BasePart") then
				buttonColors[part] = part.Color
			end
		end
	end
end

local function setButtonLit(part, lit)
	if not part then return end
	if lit then
		part.Color = Color3.fromRGB(255, 215, 90)
	else
		part.Color = buttonColors[part] or Color3.new(1, 1, 1)
	end
end

local function addClickDetector(part, onClick)
	if not part then return end
	local cd = part:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.Parent = part
	end
	cd.MaxActivationDistance = 12
	cd.MouseClick:Connect(function(player)
		print("[LiftController] ClickDetector fired on: " .. part.Name .. " by " .. player.Name)
		onClick(player)
	end)
end

local function findChildCaseInsensitive(model, name)
	if not model then return nil end
	local lower = string.lower(name)
	for _, child in ipairs(model:GetChildren()) do
		if string.find(string.lower(child.Name), lower, 1, true) then
			return child
		end
	end
	return nil
end

-- ====== ALUR UTAMA ======

-- Panggil lift dari panel lantai
local function callElevator(floor, player)
	print("[LiftController] callElevator called for floor " .. floor .. " (busy=" .. tostring(busy) .. ", enabled=" .. tostring(state.enabled) .. ")")
	if busy then return end
	if not state.enabled then
		sendWarning(player, "Lift sedang dimatikan.")
		return
	end
	if not isActiveFloor(floor) then
		sendWarning(player, "Lantai " .. floor .. " tidak tersedia.")
		return
	end

	busy = true

	if floor == state.currentFloor then
		-- Lift sudah di lantai ini -> buka pintu
		if not doorOpen then
			setDoors(true, CONFIG.DoorDuration)
			doorOpen = true
		end
		busy = false
		return
	end

	-- Lift di lantai lain -> tutup pintu, gerak, buka pintu
	if doorOpen then
		setDoors(false, CONFIG.DoorDuration)
		doorOpen = false
	end

	state.targetFloor = floor
	state.status = "moving"
	updateIndicators()
	LiftAPI:_UpdateState(state)

	weldPlayersToCar()
	moveCarToFloor(floor)
	unweldPlayers()

	state.currentFloor = floor
	state.targetFloor = nil
	state.status = "idle"
	updateIndicators()
	LiftAPI:_UpdateState(state)

	-- Buka pintu otomatis agar pemain bisa masuk
	setDoors(true, CONFIG.DoorDuration)
	doorOpen = true

	busy = false
end

-- Pilih nomor lantai tujuan dari dalam kabin
local function selectFloor(floor, player)
	if busy then return end
	if not state.enabled then
		sendWarning(player, "Lift sedang dimatikan.")
		return
	end
	if not doorOpen then
		sendWarning(player, "Pintu masih tertutup. Tekan tombol Call dulu.")
		return
	end
	if isBrokenFloor(floor) then
		sendWarning(player, CONFIG.WarningMessage)
		return
	end
	if not isActiveFloor(floor) then
		sendWarning(player, "Lantai " .. floor .. " tidak tersedia.")
		return
	end
	if floor == state.currentFloor then
		sendWarning(player, "Lift sudah berada di lantai " .. floor .. ".")
		return
	end

	state.targetFloor = floor
	updateIndicators()
	LiftAPI:_UpdateState(state)
end

-- Tutup pintu lalu pindah ke tujuan (setelah 3 detik)
local function closeDoor(player)
	if busy then return end
	if not doorOpen then return end
	if not state.targetFloor then
		sendWarning(player, "Pilih nomor lantai dulu.")
		return
	end

	busy = true
	setDoors(false, CONFIG.DoorDuration)
	doorOpen = false

	state.status = "moving"
	updateIndicators()
	LiftAPI:_UpdateState(state)

	-- Jeda 3 detik sebelum bergerak
	task.wait(CONFIG.CloseDelay)

	weldPlayersToCar()
	moveCarToFloor(state.targetFloor)
	unweldPlayers()

	state.currentFloor = state.targetFloor
	state.status = "idle"
	updateIndicators()
	LiftAPI:_UpdateState(state)

	busy = false
end

-- Buka pintu (hanya berfungsi setelah sampai di tujuan)
local function openDoor(player)
	if busy then return end
	if doorOpen then return end
	if not state.targetFloor then return end
	if state.targetFloor ~= state.currentFloor then
		sendWarning(player, "Lift belum sampai di tujuan.")
		return
	end

	busy = true
	setDoors(true, CONFIG.DoorDuration)
	doorOpen = true
	busy = false

	state.targetFloor = nil
	updateIndicators()
	LiftAPI:_UpdateState(state)
end

-- ====== SETUP TOMBOL ======
local function setupButtons()
	-- Nomor lantai di dalam kabin
	for i = 1, 9 do
		local btn = carControl:FindFirstChild("Number" .. i)
		if btn then
			addClickDetector(btn, function(player)
				setButtonLit(btn, true)
				selectFloor(i, player)
				task.delay(2, function() setButtonLit(btn, false) end)
			end)
		end
	end

	-- Tombol Buka pintu (hanya setelah sampai tujuan)
	local openBtn = carControl:FindFirstChild("Door_Open_Button")
	if openBtn then
		addClickDetector(openBtn, function(player)
			openDoor(player)
		end)
	end

	-- Tombol Tutup pintu (hanya setelah memilih lantai)
	local closeBtn = carControl:FindFirstChild("Door_Close_Button")
	if closeBtn then
		addClickDetector(closeBtn, function(player)
			closeDoor(player)
		end)
	end

	-- Tombol Call di panel lantai 1 dan 5
	for floor, panel in pairs(landingPanels) do
		local call = findChildCaseInsensitive(panel, "Call_Elevator")
		if call then
			print("[LiftController] Registering Call button for floor " .. floor .. " (" .. call.Name .. ")")
			local function onCallClick(player)
				setButtonLit(call, true)
				callElevator(floor, player)
				task.delay(2, function() setButtonLit(call, false) end)
			end
			addClickDetector(call, onCallClick)

			-- Zona klik tak terlihat yang lebih besar di depan tombol agar klik lebih andal.
			-- Tombol asli sangat kecil (0.6x0.5), sehingga mudah terlewat saat diklik.
			local zone = panel:FindFirstChild("Call_ClickZone")
			if not zone then
				zone = Instance.new("Part")
				zone.Name = "Call_ClickZone"
				zone.Size = Vector3.new(1.5, 1.5, 0.5)
				zone.Transparency = 1
				zone.CanCollide = false
				zone.CanTouch = false
				zone.CanQuery = true
				zone.Anchored = true
				zone.CFrame = CFrame.new(call.Position + Vector3.new(0, 0, 0.4)) * call.CFrame.Rotation
				zone.Parent = panel
			end
			addClickDetector(zone, onCallClick)
		else
			print("[LiftController] WARNING: Call button NOT found for floor " .. floor)
		end
	end
end

-- ====== REMOTE (perintah dari client / script lain) ======
Remote.OnServerEvent:Connect(function(player, action, ...)
	if action == "SetEnabled" then
		local enabled = ...
		state.enabled = enabled
		LiftAPI:_UpdateState(state)
	elseif action == "RequestFloor" then
		local floor = ...
		callElevator(floor, player)
	elseif action == "SetFloorHeight" then
		local floor, height = ...
		if type(floor) == "number" and type(height) == "number" then
			CONFIG.FloorHeights[floor] = height
			LiftAPI:_UpdateState(state)
		end
	end
end)

-- ====== DAFTARKAN HANDLER KE API ======
LiftAPI:RegisterServer({
	SetEnabled = function(enabled)
		state.enabled = enabled
		LiftAPI:_UpdateState(state)
	end,
	RequestFloor = function(floor)
		callElevator(floor, nil)
	end,
	SetFloorHeight = function(floor, height)
		CONFIG.FloorHeights[floor] = height
		LiftAPI:_UpdateState(state)
	end,
})

-- ====== INIT ======
recordDoors()
recordButtonColors()
setupIndicators()
setupButtons()
updateIndicators()
LiftAPI:_UpdateState(state)

print("[LiftController] Elevator siap. Lantai aktif: 1 dan 5. Pintu mulai tertutup.")
