local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local gameplayConfigModule = script.Parent:FindFirstChild("GameplayConfig")
	or script.Parent.Parent:WaitForChild("GameplayConfig")
local GameplayConfig = require(gameplayConfigModule)

local function getOrCreateRemoteEvent(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local requestEvent = getOrCreateRemoteEvent("InvisibilityRequestEvent")

local INVISIBILITY_DURATION = GameplayConfig.Invisibility.Duration
local INVISIBILITY_COOLDOWN = GameplayConfig.Invisibility.Cooldown
local activeTokens = {}
local originalDisplayDistanceType = {}
local originalHealthDisplayType = {}

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	end

	if value > maximum then
		return maximum
	end

	return value
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function hideIdentity(player)
	local humanoid = getHumanoid(player)
	if not humanoid then return end

	if originalDisplayDistanceType[player] == nil then
		originalDisplayDistanceType[player] = humanoid.DisplayDistanceType
	end

	if originalHealthDisplayType[player] == nil then
		originalHealthDisplayType[player] = humanoid.HealthDisplayType
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
end

local function restoreIdentity(player)
	local humanoid = getHumanoid(player)
	if not humanoid then return end

	if originalDisplayDistanceType[player] ~= nil then
		humanoid.DisplayDistanceType = originalDisplayDistanceType[player]
	end

	if originalHealthDisplayType[player] ~= nil then
		humanoid.HealthDisplayType = originalHealthDisplayType[player]
	end

	originalDisplayDistanceType[player] = nil
	originalHealthDisplayType[player] = nil
end

local function clearInvisibility(player, token)
	if token ~= nil and activeTokens[player] ~= token then return end
	activeTokens[player] = nil

	if player.Parent == Players then
		player:SetAttribute("IsInvisible", false)
		player:SetAttribute("InvisibilityActiveEndsAt", 0)
		restoreIdentity(player)
	end
end

local function initializePlayer(player)
	player:SetAttribute("IsInvisible", false)
	player:SetAttribute("InvisibilityActiveEndsAt", 0)
	player:SetAttribute("InvisibilityCooldownEndsAt", 0)
	player:SetAttribute("InvisibilityBarRatio", 1)
	player.CharacterAdded:Connect(function()
		if player:GetAttribute("IsInvisible") then
			hideIdentity(player)
		end
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if player:GetAttribute("Role") == "Tagger" and player:GetAttribute("IsInvisible") then
			clearInvisibility(player)
		end
	end)
end

local function updateBarRatio(player, now)
	local activeEndsAt = player:GetAttribute("InvisibilityActiveEndsAt") or 0
	local cooldownEndsAt = player:GetAttribute("InvisibilityCooldownEndsAt") or 0
	local ratio = 1

	if now < activeEndsAt then
		ratio = clamp((activeEndsAt - now) / INVISIBILITY_DURATION, 0, 1)
	elseif now < cooldownEndsAt then
		ratio = 1 - clamp((cooldownEndsAt - now) / INVISIBILITY_COOLDOWN, 0, 1)
	end

	player:SetAttribute("InvisibilityBarRatio", ratio)
end

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

Players.PlayerAdded:Connect(initializePlayer)

Players.PlayerRemoving:Connect(function(player)
	activeTokens[player] = nil
	originalDisplayDistanceType[player] = nil
	originalHealthDisplayType[player] = nil
end)

requestEvent.OnServerEvent:Connect(function(player)
	if activeTokens[player] then return end
	if tick() < (player:GetAttribute("InvisibilityCooldownEndsAt") or 0) then return end

	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then return end

	local now = tick()
	local activeEndsAt = now + INVISIBILITY_DURATION
	local cooldownEndsAt = activeEndsAt + INVISIBILITY_COOLDOWN
	local token = (activeTokens[player] or 0) + 1
	activeTokens[player] = token
	hideIdentity(player)
	player:SetAttribute("IsInvisible", true)
	player:SetAttribute("InvisibilityActiveEndsAt", activeEndsAt)
	player:SetAttribute("InvisibilityCooldownEndsAt", cooldownEndsAt)

	task.delay(INVISIBILITY_DURATION, function()
		clearInvisibility(player, token)
	end)
end)

RunService.Heartbeat:Connect(function()
	local now = tick()
	for _, player in ipairs(Players:GetPlayers()) do
		updateBarRatio(player, now)
	end
end)