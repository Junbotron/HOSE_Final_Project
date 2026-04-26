local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CROUCH_EVENT_NAME = "CrouchStateEvent"
local STANDING_GROUP = "StandingPlayers"
local CROUCHING_GROUP = "CrouchingPlayers"
local CRAWL_BLOCKER_GROUP = "CrawlBlocker"

local function ensureRemoteEvent(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local function ensureCollisionGroup(name)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function setCharacterCollisionGroup(character, groupName)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

ensureCollisionGroup(STANDING_GROUP)
ensureCollisionGroup(CROUCHING_GROUP)
ensureCollisionGroup(CRAWL_BLOCKER_GROUP)

PhysicsService:CollisionGroupSetCollidable(STANDING_GROUP, CRAWL_BLOCKER_GROUP, true)
PhysicsService:CollisionGroupSetCollidable(CROUCHING_GROUP, CRAWL_BLOCKER_GROUP, false)

local crouchStateEvent = ensureRemoteEvent(CROUCH_EVENT_NAME)
local crouchStates = {}
local descendantConnections = {}

local function applyPlayerState(player)
	local character = player.Character
	if not character then
		return
	end

	local isCrouching = crouchStates[player] == true
	setCharacterCollisionGroup(character, isCrouching and CROUCHING_GROUP or STANDING_GROUP)

	if descendantConnections[player] then
		descendantConnections[player]:Disconnect()
		descendantConnections[player] = nil
	end

	descendantConnections[player] = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = crouchStates[player] and CROUCHING_GROUP or STANDING_GROUP
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	crouchStates[player] = false
	player.CharacterAdded:Connect(function()
		applyPlayerState(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	crouchStates[player] = false
	if player.Character then
		applyPlayerState(player)
	end
	player.CharacterAdded:Connect(function()
		applyPlayerState(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	if descendantConnections[player] then
		descendantConnections[player]:Disconnect()
		descendantConnections[player] = nil
	end

	crouchStates[player] = nil
end)

crouchStateEvent.OnServerEvent:Connect(function(player, isCrouching)
	crouchStates[player] = isCrouching == true
	applyPlayerState(player)
end)