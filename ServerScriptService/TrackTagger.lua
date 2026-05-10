
--====================================================
--               TAG SYSTEM (SERVER)
--====================================================
--[[
This script manages:
• Assigning the tagger
• Updating roles for all players
• Validating tag attempts
• Enforcing distance checks and anti-cheat
• Preventing tagbacks and tag spamming
====================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayConfig = require(script.Parent:WaitForChild("GameplayConfig"))

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

local tagEvent = getOrCreateRemoteEvent("TagEvent")
local roleEvent = getOrCreateRemoteEvent("RoleEvent")
local cooldownEvent = getOrCreateRemoteEvent("CooldownEvent")

--==================================================
--                 GAME CONSTANTS
--==================================================

local itPlayer = nil                         -- Current tagger
local MAX_TAG_DISTANCE = GameplayConfig.Tag.MaxDistance                   -- Max distance allowed for tagging
local NO_TAG_BACK_TIME = GameplayConfig.Tag.NoTagBackTime                -- Prevent immediate tagback

local lastTagged = {}                        -- Tracks tagback protection

local ROLE_TAGGER = GameplayConfig.Roles.Tagger
local ROLE_SURVIVOR = GameplayConfig.Roles.Survivor

local function getTagCooldownEndsAt(player)
	return player:GetAttribute("TagCooldownEndsAt") or 0
end

local function getNoTagBackEndsAt(player)
	return player:GetAttribute("NoTagBackEndsAt") or 0
end

local function setTagCooldownEndsAt(player, expiresAt)
	player:SetAttribute("TagCooldownEndsAt", expiresAt)
end

local function setNoTagBackEndsAt(player, expiresAt)
	player:SetAttribute("NoTagBackEndsAt", expiresAt)
end

local function resetTagState(player)
	lastTagged[player] = nil
	setTagCooldownEndsAt(player, 0)
	setNoTagBackEndsAt(player, 0)
end

local function sendCooldownStatus(player)
	cooldownEvent:FireClient(player, {
		cooldownEndsAt = getTagCooldownEndsAt(player),
		noTagBackEndsAt = getNoTagBackEndsAt(player),
	})
end

--==================================================
--               ROLE UPDATE FUNCTION
--==================================================

local function updateAllRoles()
	-- Sends each player their correct role
	for _, p in ipairs(Players:GetPlayers()) do
		if p == itPlayer then
			p:SetAttribute("Role", ROLE_TAGGER)
			roleEvent:FireClient(p, ROLE_TAGGER)
		else
			p:SetAttribute("Role", ROLE_SURVIVOR)
			roleEvent:FireClient(p, ROLE_SURVIVOR)
		end

		sendCooldownStatus(p)
	end
end

--==================================================
--         ASSIGN TAGGER WHEN GAME STARTS
--==================================================

local function assignTaggerIfNeeded()
	local players = Players:GetPlayers()

	-- Only assign if 2+ players exist and no tagger yet
	if #players >= 2 and not itPlayer then
		itPlayer = players[math.random(1, #players)]
		updateAllRoles()
	end
end

--==================================================
--            PLAYER JOIN / LEAVE HANDLING
--==================================================

Players.PlayerAdded:Connect(function(player)
	setTagCooldownEndsAt(player, 0)
	setNoTagBackEndsAt(player, 0)
	player.CharacterAdded:Wait() -- Ensures character exists before role assignment
	assignTaggerIfNeeded()
	updateAllRoles()
end)

Players.PlayerRemoving:Connect(function(player)
	task.defer(function()
		local players = Players:GetPlayers()
		resetTagState(player)

		-- If the tagger leaves, choose a new one (if enough players remain)
		if player == itPlayer then
			if #players >= 2 then
				itPlayer = players[math.random(1, #players)]
			else
				itPlayer = nil
			end
		end

		updateAllRoles()
	end)
end)

--==================================================
--                TAGGING LOGIC
--==================================================

tagEvent.OnServerEvent:Connect(function(player, targetPlayer)
	-- Must be the tagger
	if player ~= itPlayer then return end

	-- Must have a valid target
	if not targetPlayer then return end
	if not player.Character or not targetPlayer.Character then return end

	local pRoot = player.Character:FindFirstChild("HumanoidRootPart")
	local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not pRoot or not tRoot then return end

	-- Distance check (anti-cheat)
	local distance = (pRoot.Position - tRoot.Position).Magnitude
	if distance > MAX_TAG_DISTANCE then return end

	local now = tick()

	-- No tagback check
	if now < getNoTagBackEndsAt(targetPlayer) then return end

	local previousTagger = player
	local newTagger = targetPlayer

	resetTagState(previousTagger)
	resetTagState(newTagger)
	lastTagged[previousTagger] = now
	setNoTagBackEndsAt(previousTagger, now + NO_TAG_BACK_TIME)

	-- Successful tag → new tagger
	itPlayer = newTagger
	updateAllRoles()
end)

--[[
local function sendCooldownStatus()
	local now = tick()

	for _, p in ipairs(Players:GetPlayers()) do
		local cooldownReady = true
		local tagbackReady = true

		if lastTagTime[p] and now - lastTagTime[p] < TAG_COOLDOWN then
			cooldownReady = false
		end

		if lastTagged[p] and now - lastTagged[p] < NO_TAG_BACK_TIME then
			tagbackReady = false
		end

		cooldownEvent:FireClient(p, {
			cooldown = cooldownReady,
			tagback = tagbackReady
		})
	end
end
-- Update cooldowns every frame
game:GetService("RunService").Heartbeat:Connect(sendCooldownStatus)]]