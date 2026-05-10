local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameplayConfig = require(script.Parent:WaitForChild("GameplayConfig"))

local TASK_EVENT_NAME = "TaskMinigameEvent"
local taskConfig = GameplayConfig.TaskMinigame
local spamConfig = taskConfig.Spam
local randomGenerator = Random.new()
local playerStates = {}

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

local taskEvent = ensureRemoteEvent(TASK_EVENT_NAME)

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	end

	if value > maximum then
		return maximum
	end

	return value
end

local function getSyncedTime()
	return Workspace:GetServerTimeNow()
end

local function getPlayerState(player)
	local state = playerStates[player]
	if state then
		return state
	end

	state = {
		roundStartedAt = 0,
		greenStart = 0,
		greenWidth = taskConfig.GreenWidthMax,
		spamFill = 0,
		spamLastUpdatedAt = 0,
	}

	playerStates[player] = state
	return state
end

local function getProgressSegments(player)
	return clamp(player:GetAttribute("TaskProgressSegments") or 0, 0, taskConfig.TotalSegments)
end

local function getSpamCompletedStages(player)
	return clamp(player:GetAttribute("SpamTaskCompletedStages") or 0, 0, spamConfig.TotalStages)
end

local function getSpamStageDecay(completedStages)
	return spamConfig.BaseDecayPerSecond + (completedStages * spamConfig.StageDecayIncrease)
end

local function getGreenWidth(progressSegments)
	local maxStepIndex = math.max(taskConfig.TotalSegments - 1, 1)
	local shrinkAlpha = clamp(progressSegments / maxStepIndex, 0, 1)
	return taskConfig.GreenWidthMax - ((taskConfig.GreenWidthMax - taskConfig.GreenWidthMin) * shrinkAlpha)
end

local function computeMarkerPosition(elapsedTime)
	local maxPosition = 1 - taskConfig.MarkerWidthScale
	if maxPosition <= 0 then
		return 0
	end

	local cycleLength = maxPosition * 2
	local traveled = (elapsedTime * taskConfig.SwingSpeed) % cycleLength

	if traveled > maxPosition then
		return cycleLength - traveled
	end

	return traveled
end

local function syncStaticAttributes(player, progressSegments)
	player:SetAttribute("TaskTotalSegments", taskConfig.TotalSegments)
	player:SetAttribute("TaskProgressSegments", progressSegments)
	player:SetAttribute("TaskMarkerWidthScale", taskConfig.MarkerWidthScale)
	player:SetAttribute("TaskSwingSpeed", taskConfig.SwingSpeed)
	player:SetAttribute("TaskGreenWidth", getGreenWidth(progressSegments))
	player:SetAttribute("TaskMinigameActive", false)
	player:SetAttribute("TaskAttemptStartedAt", 0)
	player:SetAttribute("TaskGreenStart", 0)
	player:SetAttribute("TaskLastResult", "Idle")
	player:SetAttribute("SpamTaskTotalStages", spamConfig.TotalStages)
	player:SetAttribute("SpamTaskCompletedStages", getSpamCompletedStages(player))
	player:SetAttribute("SpamTaskCurrentFill", 0)
	player:SetAttribute("SpamTaskGoalStart", spamConfig.GoalStartScale)
	player:SetAttribute("SpamTaskGoalWidth", spamConfig.GoalWidthScale)
	player:SetAttribute("SpamTaskActive", false)
	player:SetAttribute("SpamTaskCurrentStage", math.min(getSpamCompletedStages(player) + 1, spamConfig.TotalStages))
	player:SetAttribute("SpamTaskDecayPerSecond", getSpamStageDecay(getSpamCompletedStages(player)))
	player:SetAttribute("SpamTaskLastResult", "Idle")
end

local function initializePlayer(player)
	local progressSegments = getProgressSegments(player)
	getPlayerState(player)
	syncStaticAttributes(player, progressSegments)
end

local function startRound(player)
	if player:GetAttribute("TaskMinigameActive") == true then
		return
	end

	if player:GetAttribute("SpamTaskActive") == true then
		return
	end

	local progressSegments = getProgressSegments(player)
	if progressSegments >= taskConfig.TotalSegments then
		return
	end

	local state = getPlayerState(player)
	state.greenWidth = getGreenWidth(progressSegments)
	state.greenStart = randomGenerator:NextNumber(taskConfig.SidePaddingScale, 1 - state.greenWidth - taskConfig.SidePaddingScale)
	state.roundStartedAt = getSyncedTime()

	player:SetAttribute("TaskGreenStart", state.greenStart)
	player:SetAttribute("TaskGreenWidth", state.greenWidth)
	player:SetAttribute("TaskAttemptStartedAt", state.roundStartedAt)
	player:SetAttribute("TaskMinigameActive", true)
	player:SetAttribute("TaskLastResult", "Running")
end

local function resolveRound(player)
	if player:GetAttribute("TaskMinigameActive") ~= true then
		return
	end

	local state = getPlayerState(player)
	local elapsedTime = math.max(0, getSyncedTime() - state.roundStartedAt)
	local markerStart = computeMarkerPosition(elapsedTime)
	local markerEnd = markerStart + taskConfig.MarkerWidthScale
	local greenStart = state.greenStart
	local greenEnd = greenStart + state.greenWidth
	local success = markerStart >= greenStart and markerEnd <= greenEnd

	local progressSegments = getProgressSegments(player)
	if success then
		progressSegments = math.min(taskConfig.TotalSegments, progressSegments + taskConfig.SuccessStep)
	else
		progressSegments = math.max(0, progressSegments - taskConfig.FailureStep)
	end

	state.greenWidth = getGreenWidth(progressSegments)
	state.roundStartedAt = 0

	player:SetAttribute("TaskProgressSegments", progressSegments)
	player:SetAttribute("TaskGreenWidth", state.greenWidth)
	player:SetAttribute("TaskMinigameActive", false)
	player:SetAttribute("TaskAttemptStartedAt", 0)
	player:SetAttribute("TaskLastResult", success and "Success" or "Fail")
end

local function updateSpamStageAttributes(player, completedStages, currentFill)
	player:SetAttribute("SpamTaskCompletedStages", completedStages)
	player:SetAttribute("SpamTaskCurrentFill", currentFill)
	player:SetAttribute("SpamTaskCurrentStage", math.min(completedStages + 1, spamConfig.TotalStages))
	player:SetAttribute("SpamTaskDecayPerSecond", getSpamStageDecay(completedStages))
end

local function startSpamRound(player)
	if player:GetAttribute("SpamTaskActive") == true then
		return
	end

	if player:GetAttribute("TaskMinigameActive") == true then
		return
	end

	local completedStages = getSpamCompletedStages(player)
	if completedStages >= spamConfig.TotalStages then
		return
	end

	local state = getPlayerState(player)
	state.spamFill = 0
	state.spamLastUpdatedAt = getSyncedTime()

	player:SetAttribute("SpamTaskActive", true)
	player:SetAttribute("SpamTaskLastResult", "Running")
	updateSpamStageAttributes(player, completedStages, state.spamFill)
end

local function cancelSpamRound(player)
	if player:GetAttribute("SpamTaskActive") ~= true then
		return
	end

	local state = getPlayerState(player)
	state.spamFill = 0
	state.spamLastUpdatedAt = 0

	player:SetAttribute("SpamTaskActive", false)
	player:SetAttribute("SpamTaskLastResult", "Idle")
	updateSpamStageAttributes(player, getSpamCompletedStages(player), state.spamFill)
end

local function applySpamDecay(player, state, now)
	if player:GetAttribute("SpamTaskActive") ~= true then
		return getSpamCompletedStages(player), state.spamFill
	end

	if state.spamLastUpdatedAt <= 0 then
		state.spamLastUpdatedAt = now
		return getSpamCompletedStages(player), state.spamFill
	end

	local deltaTime = math.max(0, now - state.spamLastUpdatedAt)
	state.spamLastUpdatedAt = now

	local completedStages = getSpamCompletedStages(player)
	local decay = getSpamStageDecay(completedStages)
	state.spamFill = math.max(0, state.spamFill - (deltaTime * decay))
	return completedStages, state.spamFill
end

local function tapSpamRound(player)
	if player:GetAttribute("SpamTaskActive") ~= true then
		return
	end

	local state = getPlayerState(player)
	local now = getSyncedTime()
	local completedStages = select(1, applySpamDecay(player, state, now))
	state.spamFill = math.min(1, state.spamFill + spamConfig.FillPerTap)

	if state.spamFill >= spamConfig.GoalStartScale then
		completedStages = math.min(spamConfig.TotalStages, completedStages + 1)
		state.spamFill = 0
		player:SetAttribute("SpamTaskLastResult", completedStages >= spamConfig.TotalStages and "Success" or "StageClear")

		if completedStages >= spamConfig.TotalStages then
			player:SetAttribute("SpamTaskActive", false)
			state.spamLastUpdatedAt = 0
		else
			state.spamLastUpdatedAt = now
		end
	else
		player:SetAttribute("SpamTaskLastResult", "Running")
	end

	updateSpamStageAttributes(player, completedStages, state.spamFill)
end

taskEvent.OnServerEvent:Connect(function(player, action)
	if type(action) ~= "string" then
		return
	end

	if action == "Start" then
		startRound(player)
	elseif action == "Resolve" then
		resolveRound(player)
	elseif action == "SpamStart" then
		startSpamRound(player)
	elseif action == "SpamTap" then
		tapSpamRound(player)
	elseif action == "SpamCancel" then
		cancelSpamRound(player)
	end
end)

RunService.Heartbeat:Connect(function()
	local now = getSyncedTime()

	for player, state in pairs(playerStates) do
		if player.Parent == Players and player:GetAttribute("SpamTaskActive") == true then
			local completedStages, currentFill = applySpamDecay(player, state, now)
			updateSpamStageAttributes(player, completedStages, currentFill)
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

Players.PlayerAdded:Connect(initializePlayer)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)