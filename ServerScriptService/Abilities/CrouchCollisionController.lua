local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local STANDING_GROUP = "StandingPlayers"
local CROUCHING_GROUP = "CrouchingPlayers"
local CRAWL_BLOCKER_GROUP = "CrawlBlocker"

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

local crouchStates = {}
local descendantConnections = {}
local attributeConnections = {}

local function getIsCrouching(player)
	return player:GetAttribute("IsCrouching") == true
end

local function applyPlayerState(player)
	crouchStates[player] = getIsCrouching(player)

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
			descendant.CollisionGroup = getIsCrouching(player) and CROUCHING_GROUP or STANDING_GROUP
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	crouchStates[player] = getIsCrouching(player)
	attributeConnections[player] = player:GetAttributeChangedSignal("IsCrouching"):Connect(function()
		applyPlayerState(player)
	end)
	player.CharacterAdded:Connect(function()
		applyPlayerState(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	crouchStates[player] = getIsCrouching(player)
	attributeConnections[player] = player:GetAttributeChangedSignal("IsCrouching"):Connect(function()
		applyPlayerState(player)
	end)
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

	if attributeConnections[player] then
		attributeConnections[player]:Disconnect()
		attributeConnections[player] = nil
	end

	crouchStates[player] = nil
end)