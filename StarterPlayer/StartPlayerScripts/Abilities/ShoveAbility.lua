local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local shoveEvent = ReplicatedStorage:WaitForChild("ShoveEvent")

local ABILITY_KEY = Enum.KeyCode.F

local function getHoveredPlayer()
	local target = mouse.Target
	if not target then return nil end

	local character = target:FindFirstAncestorOfClass("Model")
	if not character then return nil end

	local targetPlayer = Players:GetPlayerFromCharacter(character)
	if not targetPlayer or targetPlayer == player then return nil end

	return targetPlayer
end

local function updateShoveState()
	local isTagger = player:GetAttribute("CurrentRole") == "Tagger"
	local hoveredPlayer = getHoveredPlayer()
	local isHoveringTarget = hoveredPlayer ~= nil

	player:SetAttribute("IsHoveringShoveTarget", isHoveringTarget)
	player:SetAttribute("CanShoveAtAll", not isTagger)
end

updateShoveState()

RunService.RenderStepped:Connect(updateShoveState)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode ~= ABILITY_KEY then return end
	if player:GetAttribute("CurrentRole") == "Tagger" then return end
	if tick() < (player:GetAttribute("ShoveCooldownEndsAt") or 0) then return end

	local targetPlayer = getHoveredPlayer()
	if not targetPlayer then return end

	shoveEvent:FireServer(targetPlayer)
	updateShoveState()
end)
