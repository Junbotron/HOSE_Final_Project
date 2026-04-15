--====================================================
--                 ROLE UI CONTROLLER
--====================================================
--[[
This script:
• Updates the player's on-screen role label
• Stores whether the player is the tagger (_G.isIt)
====================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local roleEvent = ReplicatedStorage:WaitForChild("RoleEvent")

local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("ScreenGui")
local label = screenGui:WaitForChild("RoleLabel")

_G.isIt = false -- Global flag used by other scripts

--==================================================
--              ROLE UPDATE LISTENER
--==================================================

roleEvent.OnClientEvent:Connect(function(role)
	if role == "Tagger" then
		_G.isIt = true
		label.Text = "YOU'RE IT!!!"
		label.TextColor3 = Color3.fromRGB(255,0,0)
	else
		_G.isIt = false
		label.Text = "Survivor"
		label.TextColor3 = Color3.fromRGB(255,255,255)
	end
end)
