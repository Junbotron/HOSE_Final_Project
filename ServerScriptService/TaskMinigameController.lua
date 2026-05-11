local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameplayConfig = require(script.Parent:WaitForChild("GameplayConfig"))

local TASK_EVENT_NAME = "TaskMinigameEvent"
local taskConfig = GameplayConfig.TaskMinigame
local spamConfig = taskConfig.Spam
local puzzleConfig = taskConfig.Puzzle
local codeConfig = taskConfig.Code
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
		codeDefinition = nil,
		codeRevealCount = 0,
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

local function getPuzzleCompletedStages(player)
	return clamp(player:GetAttribute("PuzzleTaskCompletedStages") or 0, 0, puzzleConfig.TotalStages)
end

local function getCodeCompletedStages(player)
	return clamp(player:GetAttribute("CodeTaskCompletedStages") or 0, 0, codeConfig.TotalStages)
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

local function getPuzzleStage(stageIndex)
	return puzzleConfig.Stages[stageIndex]
end

local function getCodeStage(stageIndex)
	return codeConfig.Stages[stageIndex]
end

local function encodePuzzleDefinition(stageIndex)
	local stage = getPuzzleStage(stageIndex)
	if not stage then
		return ""
	end

	return HttpService:JSONEncode({
		stage = stageIndex,
		size = stage.Size,
		pairs = stage.Pairs,
	})
end

local function encodeCodeDefinition(definition)
	if not definition then
		return ""
	end

	local lines = {}
	for _, line in ipairs(definition.lines) do
		table.insert(lines, {
			html = line.html,
			letters = line.letters,
		})
	end

	return HttpService:JSONEncode({
		stage = definition.stage,
		lines = lines,
		totalInputs = definition.totalInputs,
	})
end

local function buildCodeDefinition(stageIndex)
	local stage = getCodeStage(stageIndex)
	if not stage then
		return nil
	end

	local definition = {
		stage = stageIndex,
		lines = {},
		sequence = {},
		totalInputs = 0,
	}

	for _, lineConfig in ipairs(stage.Lines) do
		local letters = {}
		for _ = 1, lineConfig.SequenceLength do
			local letterIndex = randomGenerator:NextInteger(1, #codeConfig.Letters)
			local letter = codeConfig.Letters[letterIndex]
			table.insert(letters, letter)
			table.insert(definition.sequence, letter)
		end

		table.insert(definition.lines, {
			html = lineConfig.Html,
			letters = letters,
		})
	end

	definition.totalInputs = #definition.sequence
	return definition
end

local function cellKey(row, column)
	return string.format("%d:%d", row, column)
end

local function normalizeCell(cellData)
	if type(cellData) ~= "table" then
		return nil
	end

	local row = tonumber(cellData.row or cellData[1])
	local column = tonumber(cellData.column or cellData.col or cellData[2])
	if not row or not column then
		return nil
	end

	return {
		row = math.floor(row),
		column = math.floor(column),
	}
end

local function matchesEndpoint(cell, endpoint)
	return cell.row == endpoint[1] and cell.column == endpoint[2]
end

local function buildPuzzlePairMaps(stage)
	local pairMap = {}
	local endpointOwners = {}

	for _, pair in ipairs(stage.Pairs) do
		pairMap[pair.Id] = pair
		endpointOwners[cellKey(pair.Endpoints[1][1], pair.Endpoints[1][2])] = pair.Id
		endpointOwners[cellKey(pair.Endpoints[2][1], pair.Endpoints[2][2])] = pair.Id
	end

	return pairMap, endpointOwners
end

local function validatePuzzleSubmission(stage, submission)
	if type(submission) ~= "table" or type(submission.paths) ~= "table" then
		return false
	end

	local pairMap, endpointOwners = buildPuzzlePairMaps(stage)
	local occupiedCells = {}
	local seenPairs = {}
	local validatedCount = 0

	for _, pathData in ipairs(submission.paths) do
		if type(pathData) ~= "table" then
			return false
		end

		local pairId = tonumber(pathData.id)
		if not pairId then
			return false
		end

		local pair = pairMap[pairId]
		local cells = pathData.cells
		if not pair or seenPairs[pairId] or type(cells) ~= "table" or #cells < 2 then
			return false
		end

		local firstCell = normalizeCell(cells[1])
		local lastCell = normalizeCell(cells[#cells])
		if not firstCell or not lastCell then
			return false
		end

		local endpoints = pair.Endpoints
		local connectsBothEnds = (
			(matchesEndpoint(firstCell, endpoints[1]) and matchesEndpoint(lastCell, endpoints[2]))
			or (matchesEndpoint(firstCell, endpoints[2]) and matchesEndpoint(lastCell, endpoints[1]))
		)
		if not connectsBothEnds then
			return false
		end

		local localSeen = {}
		local previousCell = nil

		for index, rawCell in ipairs(cells) do
			local cell = normalizeCell(rawCell)
			if not cell then
				return false
			end

			if cell.row < 1 or cell.row > stage.Size or cell.column < 1 or cell.column > stage.Size then
				return false
			end

			local key = cellKey(cell.row, cell.column)
			if localSeen[key] or occupiedCells[key] then
				return false
			end

			local endpointOwner = endpointOwners[key]
			if endpointOwner and endpointOwner ~= pairId then
				return false
			end

			if previousCell then
				local manhattanDistance = math.abs(cell.row - previousCell.row) + math.abs(cell.column - previousCell.column)
				if manhattanDistance ~= 1 then
					return false
				end
			end

			if index > 1 and index < #cells and endpointOwner == pairId then
				return false
			end

			localSeen[key] = true
			occupiedCells[key] = pairId
			previousCell = cell
		end

		seenPairs[pairId] = true
		validatedCount = validatedCount + 1
	end

	return validatedCount == #stage.Pairs
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
	player:SetAttribute("PuzzleTaskTotalStages", puzzleConfig.TotalStages)
	player:SetAttribute("PuzzleTaskCompletedStages", getPuzzleCompletedStages(player))
	player:SetAttribute("PuzzleTaskCurrentStage", math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages))
	player:SetAttribute("PuzzleTaskGridSize", 0)
	player:SetAttribute("PuzzleTaskActive", false)
	player:SetAttribute("PuzzleTaskDefinitionJson", "")
	player:SetAttribute("PuzzleTaskLastResult", "Idle")
	player:SetAttribute("CodeTaskTotalStages", codeConfig.TotalStages)
	player:SetAttribute("CodeTaskCompletedStages", getCodeCompletedStages(player))
	player:SetAttribute("CodeTaskCurrentStage", math.min(getCodeCompletedStages(player) + 1, codeConfig.TotalStages))
	player:SetAttribute("CodeTaskActive", false)
	player:SetAttribute("CodeTaskDefinitionJson", "")
	player:SetAttribute("CodeTaskRevealCount", 0)
	player:SetAttribute("CodeTaskTotalInputs", 0)
	player:SetAttribute("CodeTaskLastResult", "Idle")
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

	if player:GetAttribute("PuzzleTaskActive") == true then
		return
	end

	if player:GetAttribute("CodeTaskActive") == true then
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

	if player:GetAttribute("PuzzleTaskActive") == true then
		return
	end

	if player:GetAttribute("CodeTaskActive") == true then
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

local function startPuzzleStage(player, stageIndex)
	local stage = getPuzzleStage(stageIndex)
	if not stage then
		return false
	end

	player:SetAttribute("PuzzleTaskCurrentStage", stageIndex)
	player:SetAttribute("PuzzleTaskGridSize", stage.Size)
	player:SetAttribute("PuzzleTaskDefinitionJson", encodePuzzleDefinition(stageIndex))
	player:SetAttribute("PuzzleTaskActive", true)
	player:SetAttribute("PuzzleTaskLastResult", "Running")
	return true
end

local function startPuzzleRound(player)
	if player:GetAttribute("PuzzleTaskActive") == true then
		return
	end

	if player:GetAttribute("TaskMinigameActive") == true or player:GetAttribute("SpamTaskActive") == true then
		return
	end

	if player:GetAttribute("CodeTaskActive") == true then
		return
	end

	local completedStages = getPuzzleCompletedStages(player)
	if completedStages >= puzzleConfig.TotalStages then
		return
	end

	startPuzzleStage(player, completedStages + 1)
end

local function cancelPuzzleRound(player)
	if player:GetAttribute("PuzzleTaskActive") ~= true then
		return
	end

	player:SetAttribute("PuzzleTaskActive", false)
	player:SetAttribute("PuzzleTaskGridSize", 0)
	player:SetAttribute("PuzzleTaskDefinitionJson", "")
	player:SetAttribute("PuzzleTaskLastResult", "Idle")
	player:SetAttribute("PuzzleTaskCurrentStage", math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages))
end

local function submitPuzzleRound(player, submissionJson)
	if player:GetAttribute("PuzzleTaskActive") ~= true or type(submissionJson) ~= "string" then
		return
	end

	local currentStage = math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages)
	local stage = getPuzzleStage(currentStage)
	if not stage then
		return
	end

	local decodedSubmission = nil
	local success, decodedOrError = pcall(HttpService.JSONDecode, HttpService, submissionJson)
	if success then
		decodedSubmission = decodedOrError
	else
		player:SetAttribute("PuzzleTaskLastResult", "Fail")
		return
	end

	if not validatePuzzleSubmission(stage, decodedSubmission) then
		player:SetAttribute("PuzzleTaskLastResult", "Fail")
		return
	end

	local completedStages = math.min(puzzleConfig.TotalStages, getPuzzleCompletedStages(player) + 1)
	player:SetAttribute("PuzzleTaskCompletedStages", completedStages)

	if completedStages >= puzzleConfig.TotalStages then
		player:SetAttribute("PuzzleTaskActive", false)
		player:SetAttribute("PuzzleTaskGridSize", 0)
		player:SetAttribute("PuzzleTaskDefinitionJson", "")
		player:SetAttribute("PuzzleTaskCurrentStage", puzzleConfig.TotalStages)
		player:SetAttribute("PuzzleTaskLastResult", "Success")
	else
		startPuzzleStage(player, completedStages + 1)
	end
end

local function startCodeStage(player, stageIndex, lastResult)
	local state = getPlayerState(player)
	local definition = buildCodeDefinition(stageIndex)
	if not definition then
		return false
	end

	state.codeDefinition = definition
	state.codeRevealCount = 0

	player:SetAttribute("CodeTaskCurrentStage", stageIndex)
	player:SetAttribute("CodeTaskDefinitionJson", encodeCodeDefinition(definition))
	player:SetAttribute("CodeTaskRevealCount", 0)
	player:SetAttribute("CodeTaskTotalInputs", definition.totalInputs)
	player:SetAttribute("CodeTaskActive", true)
	player:SetAttribute("CodeTaskLastResult", lastResult or "Running")
	return true
end

local function startCodeRound(player)
	if player:GetAttribute("CodeTaskActive") == true then
		return
	end

	if player:GetAttribute("TaskMinigameActive") == true or player:GetAttribute("SpamTaskActive") == true or player:GetAttribute("PuzzleTaskActive") == true then
		return
	end

	local completedStages = getCodeCompletedStages(player)
	if completedStages >= codeConfig.TotalStages then
		return
	end

	startCodeStage(player, completedStages + 1)
end

local function cancelCodeRound(player)
	if player:GetAttribute("CodeTaskActive") ~= true then
		return
	end

	local state = getPlayerState(player)
	state.codeDefinition = nil
	state.codeRevealCount = 0

	player:SetAttribute("CodeTaskActive", false)
	player:SetAttribute("CodeTaskDefinitionJson", "")
	player:SetAttribute("CodeTaskRevealCount", 0)
	player:SetAttribute("CodeTaskTotalInputs", 0)
	player:SetAttribute("CodeTaskLastResult", "Idle")
	player:SetAttribute("CodeTaskCurrentStage", math.min(getCodeCompletedStages(player) + 1, codeConfig.TotalStages))
end

local function inputCodeRound(player, inputLetter)
	if player:GetAttribute("CodeTaskActive") ~= true or type(inputLetter) ~= "string" then
		return
	end

	local state = getPlayerState(player)
	local definition = state.codeDefinition
	if not definition then
		startCodeStage(player, math.min(getCodeCompletedStages(player) + 1, codeConfig.TotalStages), "Running")
		return
	end

	local normalizedInput = string.upper(inputLetter)
	local expectedLetter = definition.sequence[state.codeRevealCount + 1]
	if normalizedInput ~= expectedLetter then
		startCodeStage(player, definition.stage, "Fail")
		return
	end

	state.codeRevealCount = state.codeRevealCount + 1
	player:SetAttribute("CodeTaskRevealCount", state.codeRevealCount)
	player:SetAttribute("CodeTaskLastResult", "Running")

	if state.codeRevealCount < definition.totalInputs then
		return
	end

	local completedStages = math.min(codeConfig.TotalStages, getCodeCompletedStages(player) + 1)
	player:SetAttribute("CodeTaskCompletedStages", completedStages)

	if completedStages >= codeConfig.TotalStages then
		state.codeDefinition = nil
		state.codeRevealCount = 0
		player:SetAttribute("CodeTaskActive", false)
		player:SetAttribute("CodeTaskDefinitionJson", "")
		player:SetAttribute("CodeTaskRevealCount", 0)
		player:SetAttribute("CodeTaskTotalInputs", 0)
		player:SetAttribute("CodeTaskCurrentStage", codeConfig.TotalStages)
		player:SetAttribute("CodeTaskLastResult", "Success")
	else
		startCodeStage(player, completedStages + 1, "StageClear")
		player:SetAttribute("CodeTaskCompletedStages", completedStages)
	end
end

taskEvent.OnServerEvent:Connect(function(player, action, payload)
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
	elseif action == "PuzzleStart" then
		startPuzzleRound(player)
	elseif action == "PuzzleSubmit" then
		submitPuzzleRound(player, payload)
	elseif action == "PuzzleCancel" then
		cancelPuzzleRound(player)
	elseif action == "CodeStart" then
		startCodeRound(player)
	elseif action == "CodeInput" then
		inputCodeRound(player, payload)
	elseif action == "CodeCancel" then
		cancelCodeRound(player)
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