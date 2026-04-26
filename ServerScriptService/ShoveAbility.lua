local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local shoveEvent = getOrCreateRemoteEvent("ShoveEvent")

local MAX_SHOVE_DISTANCE = 6
local SHOVE_COOLDOWN = 2
local RAGDOLL_DURATION = 2
local SHOVE_DISTANCE = 10
local SHOVE_TRAVEL_TIME = 0.2

local ROLE_TAGGER = "Tagger"
local ROLE_SURVIVOR = "Survivor"

local lastShoveTime = {}
local ragdollTokens = {}

local function initializePlayer(player)
	player:SetAttribute("ShoveCooldownEndsAt", 0)
end

local function getCharacterRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function ragdollAndShove(targetPlayer, pushDirection)
	local character = targetPlayer.Character
	local humanoid = getHumanoid(character)
	local root = getCharacterRoot(character)
	if not humanoid or not root or humanoid.Health <= 0 then return end

	local token = (ragdollTokens[targetPlayer] or 0) + 1
	ragdollTokens[targetPlayer] = token

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = Vector3.new(
		(pushDirection.X * SHOVE_DISTANCE) / SHOVE_TRAVEL_TIME,
		2,
		(pushDirection.Z * SHOVE_DISTANCE) / SHOVE_TRAVEL_TIME
	)

	task.delay(RAGDOLL_DURATION, function()
		if ragdollTokens[targetPlayer] ~= token then return end
		ragdollTokens[targetPlayer] = nil

		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

shoveEvent.OnServerEvent:Connect(function(player, targetPlayer)
	if player:GetAttribute("Role") ~= ROLE_SURVIVOR then return end
	if not targetPlayer or targetPlayer == player or targetPlayer.Parent ~= Players then return end
	if targetPlayer:GetAttribute("Role") ~= ROLE_SURVIVOR and targetPlayer:GetAttribute("Role") ~= ROLE_TAGGER then return end
	if not player.Character or not targetPlayer.Character then return end

	local playerHumanoid = getHumanoid(player.Character)
	local targetHumanoid = getHumanoid(targetPlayer.Character)
	local pRoot = getCharacterRoot(player.Character)
	local tRoot = getCharacterRoot(targetPlayer.Character)
	if not playerHumanoid or not targetHumanoid or not pRoot or not tRoot then return end
	if playerHumanoid.Health <= 0 or targetHumanoid.Health <= 0 then return end

	local offset = tRoot.Position - pRoot.Position
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
	if horizontalOffset.Magnitude > MAX_SHOVE_DISTANCE then return end

	local now = tick()
	if now < (player:GetAttribute("ShoveCooldownEndsAt") or 0) then return end
	lastShoveTime[player] = now
	player:SetAttribute("ShoveCooldownEndsAt", now + SHOVE_COOLDOWN)

	local pushDirection = horizontalOffset.Magnitude > 0 and horizontalOffset.Unit or pRoot.CFrame.LookVector
	ragdollAndShove(targetPlayer, pushDirection)
end)

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

Players.PlayerAdded:Connect(initializePlayer)

Players.PlayerRemoving:Connect(function(player)
	lastShoveTime[player] = nil
	ragdollTokens[player] = nil
end)