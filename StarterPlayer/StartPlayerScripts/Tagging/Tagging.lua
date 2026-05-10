--====================================================
--                 TAG CLICK HANDLER
--====================================================
--[[
This script:
• Detects when the player clicks another player
• Sends a tag request to the server
• Only works if YOU are the tagger
====================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tagEvent = ReplicatedStorage:WaitForChild("TagEvent")

--==================================================
--                CLICK TAGGING LOGIC
--==================================================

mouse.Button1Down:Connect(function()
	-- Must be the tagger
	if not _G.isIt then return end

	local target = mouse.Target
	if not target then return end

	local character = target:FindFirstAncestorOfClass("Model")
	if not character then return end

	local targetPlayer = Players:GetPlayerFromCharacter(character)
	if not targetPlayer or targetPlayer == player then return end

	-- Send tag attempt to server
	tagEvent:FireServer(targetPlayer)
end)
