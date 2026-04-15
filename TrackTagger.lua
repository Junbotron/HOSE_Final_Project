
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

local tagEvent = ReplicatedStorage:WaitForChild("TagEvent")
local roleEvent = ReplicatedStorage:WaitForChild("RoleEvent")

--==================================================
--                 GAME CONSTANTS
--==================================================

local itPlayer = nil                         -- Current tagger
local MAX_TAG_DISTANCE = 5                   -- Max distance allowed for tagging
local TAG_COOLDOWN = 1                       -- Time before tagger can tag again
local NO_TAG_BACK_TIME = 3                   -- Prevent immediate tagback

local lastTagTime = {}                       -- Tracks tagger cooldown
local lastTagged = {}                        -- Tracks tagback protection

local ROLE_TAGGER = "Tagger"
local ROLE_SURVIVOR = "Survivor"

--==================================================
--               ROLE UPDATE FUNCTION
--==================================================

local function updateAllRoles()
	-- Sends each player their correct role
	for _, p in ipairs(Players:GetPlayers()) do
		if p == itPlayer then
			roleEvent:FireClient(p, ROLE_TAGGER)
		else
			roleEvent:FireClient(p, ROLE_SURVIVOR)
		end
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
	player.CharacterAdded:Wait() -- Ensures character exists before role assignment
	assignTaggerIfNeeded()
	updateAllRoles()
end)

Players.PlayerRemoving:Connect(function(player)
	task.defer(function()
		local players = Players:GetPlayers()

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

	-- Tag cooldown check
	if lastTagTime[player] and now - lastTagTime[player] < TAG_COOLDOWN then return end
	lastTagTime[player] = now

	-- No tagback check
	if lastTagged[targetPlayer] and now - lastTagged[targetPlayer] < NO_TAG_BACK_TIME then return end
	lastTagged[player] = now

	-- Successful tag → new tagger
	itPlayer = targetPlayer
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