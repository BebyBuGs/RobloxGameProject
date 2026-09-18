-- Button Top Bar Dance

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ambil GUI kamu
local animationGui = playerGui:WaitForChild("SettingsGui")
local animationFrame = animationGui:WaitForChild("SettingsPanel")

-- Buat icon baru
local icon = Icon.new()
	:setLabel("", "Deselected")
	:setLabel("", "Selected")
	:setImage("rbxassetid://128956208959013", "Deselected") -- ganti nanti kalau mau
	:setImage("rbxassetid://86819747298004", "Selected")
	:setImageScale(.6)
	:bindEvent("selected", function()
		animationFrame.Visible = true
	end)
	:bindEvent("deselected", function()
		animationFrame.Visible = false
	end)

-- Tambahkan ke top bar
icon:align("Left") -- atau "Left" sesuai keinginan