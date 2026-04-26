--====================================================
--                 ROLE UI CONTROLLER
--====================================================
--[[
This script:
• Stores whether the player is the tagger (_G.isIt)
• Publishes the current role for Gui.lua
====================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local roleEvent = ReplicatedStorage:WaitForChild("RoleEvent")

_G.isIt = false -- Global flag used by other scripts

--==================================================
--              ROLE UPDATE LISTENER
--==================================================

roleEvent.OnClientEvent:Connect(function(role)
	player:SetAttribute("CurrentRole", role)

	if role == "Tagger" then
		_G.isIt = true
	else
		_G.isIt = false
	end
end)
