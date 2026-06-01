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
local taskAssignments = {}
local TASK_MINIGAME_IDS = { 1, 2, 3, 4 }
local TASK_PART_COUNT = 12
local getSpamStageDecay
local getGreenWidth
local getClickerPressCount

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
		clickerStageIndex = 0,
		clickerHitsCompleted = 0,
		clickerActiveButtonId = 0,
		clickerButtonStartedAt = 0,
		clickerButtonEndsAt = 0,
		clickerNextButtonAt = 0,
		clickerLastButtonId = 0,
		puzzleStage = nil,
		codeDefinition = nil,
		codeRevealCount = 0,
		flashSequence = 0,
		selectedTaskId = nil,
		taskProgressById = {},
	}

	playerStates[player] = state
	return state
end

local function buildTaskAssignments()
	local minigamePool = {}

	for _, minigameId in ipairs(TASK_MINIGAME_IDS) do
		for _ = 1, math.floor(TASK_PART_COUNT / #TASK_MINIGAME_IDS) do
			table.insert(minigamePool, minigameId)
		end
	end

	for index = #minigamePool, 2, -1 do
		local swapIndex = randomGenerator:NextInteger(1, index)
		minigamePool[index], minigamePool[swapIndex] = minigamePool[swapIndex], minigamePool[index]
	end

	for taskId = 1, TASK_PART_COUNT do
		taskAssignments[taskId] = minigamePool[taskId]
	end
end

local function getAssignedMinigame(taskId)
	return taskAssignments[taskId]
end

local function getProgressTargetForMinigame(minigameId)
	if minigameId == 1 then
		return taskConfig.TotalSegments
	elseif minigameId == 2 then
		return spamConfig.TotalStages
	elseif minigameId == 3 then
		return puzzleConfig.TotalStages
	elseif minigameId == 4 then
		return codeConfig.TotalStages
	end

	return 0
end

local function getSelectedTaskId(player)
	return getPlayerState(player).selectedTaskId
end

local function getTaskProgress(player, taskId)
	if type(taskId) ~= "number" or not getAssignedMinigame(taskId) then
		return 0
	end

	local state = getPlayerState(player)
	local progress = state.taskProgressById[taskId]
	if progress == nil then
		progress = 0
		state.taskProgressById[taskId] = progress
	end

	return progress
end

local function setTaskProgress(player, taskId, progress)
	local minigameId = getAssignedMinigame(taskId)
	if not minigameId then
		return
	end

	getPlayerState(player).taskProgressById[taskId] = clamp(progress, 0, getProgressTargetForMinigame(minigameId))
end

local function getSelectedTaskProgress(player, minigameId)
	local selectedTaskId = getSelectedTaskId(player)
	if not selectedTaskId or getAssignedMinigame(selectedTaskId) ~= minigameId then
		return 0
	end

	return getTaskProgress(player, selectedTaskId)
end

local function isSelectedTaskMinigame(player, minigameId)
	local selectedTaskId = getSelectedTaskId(player)
	return selectedTaskId ~= nil and getAssignedMinigame(selectedTaskId) == minigameId
end

local function getMinigameTaskCount(minigameId)
	local taskCount = 0
	for _, assignedMinigameId in pairs(taskAssignments) do
		if assignedMinigameId == minigameId then
			taskCount = taskCount + 1
		end
	end

	return taskCount
end

local function getCompletedTaskCount(player, minigameId)
	local completedTaskCount = 0
	local requiredProgress = getProgressTargetForMinigame(minigameId)

	for taskId, assignedMinigameId in pairs(taskAssignments) do
		if assignedMinigameId == minigameId and getTaskProgress(player, taskId) >= requiredProgress then
			completedTaskCount = completedTaskCount + 1
		end
	end

	return completedTaskCount
end

local function syncTaskSummaryAttributes(player)
	player:SetAttribute("TimingTasksCompletedCount", getCompletedTaskCount(player, 1))
	player:SetAttribute("TimingTasksTotalCount", getMinigameTaskCount(1))
	player:SetAttribute("SpamTasksCompletedCount", getCompletedTaskCount(player, 2))
	player:SetAttribute("SpamTasksTotalCount", getMinigameTaskCount(2))
	player:SetAttribute("PuzzleTasksCompletedCount", getCompletedTaskCount(player, 3))
	player:SetAttribute("PuzzleTasksTotalCount", getMinigameTaskCount(3))
	player:SetAttribute("CodeTasksCompletedCount", getCompletedTaskCount(player, 4))
	player:SetAttribute("CodeTasksTotalCount", getMinigameTaskCount(4))
end

local function emitFlashEvent(player, attributeName, result)
	local state = getPlayerState(player)
	state.flashSequence = state.flashSequence + 1
	player:SetAttribute(attributeName, string.format("%s:%d", result, state.flashSequence))
end

local function syncSelectedTaskAttributes(player)
	local selectedTaskId = getSelectedTaskId(player)
	local selectedMinigameId = selectedTaskId and getAssignedMinigame(selectedTaskId) or nil

	local timingProgress = selectedMinigameId == 1 and getTaskProgress(player, selectedTaskId) or 0
	local spamProgress = selectedMinigameId == 2 and getTaskProgress(player, selectedTaskId) or 0
	local puzzleProgress = selectedMinigameId == 3 and getTaskProgress(player, selectedTaskId) or 0
	local codeProgress = selectedMinigameId == 4 and getTaskProgress(player, selectedTaskId) or 0

	player:SetAttribute("TaskTotalSegments", taskConfig.TotalSegments)
	player:SetAttribute("TaskProgressSegments", timingProgress)
	player:SetAttribute("TaskGreenWidth", getGreenWidth(timingProgress))
	player:SetAttribute("SpamTaskTotalStages", spamConfig.TotalStages)
	player:SetAttribute("SpamTaskCompletedStages", spamProgress)
	player:SetAttribute("SpamTaskCurrentStage", math.min(spamProgress + 1, spamConfig.TotalStages))
	player:SetAttribute("SpamTaskDecayPerSecond", getSpamStageDecay(spamProgress))
	player:SetAttribute("PuzzleTaskTotalStages", puzzleConfig.TotalStages)
	player:SetAttribute("PuzzleTaskCompletedStages", puzzleProgress)
	player:SetAttribute("PuzzleTaskCurrentStage", math.min(puzzleProgress + 1, puzzleConfig.TotalStages))
	player:SetAttribute("PuzzleTaskStageTargetCount", getClickerPressCount(math.min(puzzleProgress + 1, puzzleConfig.TotalStages)))
	player:SetAttribute("PuzzleTaskStageHitCount", selectedMinigameId == 3 and getPlayerState(player).clickerHitsCompleted or 0)
	player:SetAttribute("PuzzleTaskActiveButtonId", selectedMinigameId == 3 and getPlayerState(player).clickerActiveButtonId or 0)
	player:SetAttribute("PuzzleTaskButtonStartedAt", selectedMinigameId == 3 and getPlayerState(player).clickerButtonStartedAt or 0)
	player:SetAttribute("PuzzleTaskButtonEndsAt", selectedMinigameId == 3 and getPlayerState(player).clickerButtonEndsAt or 0)
	player:SetAttribute("PuzzleTaskButtonDelayEndsAt", selectedMinigameId == 3 and getPlayerState(player).clickerNextButtonAt or 0)
	player:SetAttribute("CodeTaskTotalStages", codeConfig.TotalStages)
	player:SetAttribute("CodeTaskCompletedStages", codeProgress)
	player:SetAttribute("CodeTaskCurrentStage", math.min(codeProgress + 1, codeConfig.TotalStages))
	player:SetAttribute("SelectedTaskId", selectedTaskId)
	player:SetAttribute("SelectedTaskMinigameId", selectedMinigameId)
end

local function selectTask(player, taskId)
	if type(taskId) ~= "number" then
		return
	end

	taskId = math.floor(taskId)
	if not getAssignedMinigame(taskId) then
		return
	end

	local state = getPlayerState(player)
	state.selectedTaskId = taskId

	if player:GetAttribute("TaskMinigameActive") ~= true then
		player:SetAttribute("TaskLastResult", "Idle")
	end
	if player:GetAttribute("SpamTaskActive") ~= true then
		player:SetAttribute("SpamTaskLastResult", "Idle")
	end
	if player:GetAttribute("PuzzleTaskActive") ~= true then
		player:SetAttribute("PuzzleTaskLastResult", "Idle")
	end
	if player:GetAttribute("CodeTaskActive") ~= true then
		player:SetAttribute("CodeTaskLastResult", "Idle")
	end

	syncSelectedTaskAttributes(player)
end

local function clearSelectedTask(player)
	getPlayerState(player).selectedTaskId = nil
	syncSelectedTaskAttributes(player)
end

local function trackTaskPart(part)
	if not part:IsA("BasePart") then
		return
	end

	local taskId = tonumber(part.Name)
	local assignedMinigameId = taskId and getAssignedMinigame(taskId) or nil
	if not assignedMinigameId then
		return
	end

	part:SetAttribute("TaskNumber", taskId)
	part:SetAttribute("AssignedMinigameId", assignedMinigameId)
end

local function getProgressSegments(player)
	return clamp(getSelectedTaskProgress(player, 1), 0, taskConfig.TotalSegments)
end

local function getSpamCompletedStages(player)
	return clamp(getSelectedTaskProgress(player, 2), 0, spamConfig.TotalStages)
end

local function getPuzzleCompletedStages(player)
	return clamp(getSelectedTaskProgress(player, 3), 0, puzzleConfig.TotalStages)
end

local function getCodeCompletedStages(player)
	return clamp(getSelectedTaskProgress(player, 4), 0, codeConfig.TotalStages)
end

getSpamStageDecay = function(completedStages)
	return spamConfig.BaseDecayPerSecond + (completedStages * spamConfig.StageDecayIncrease)
end

getGreenWidth = function(progressSegments)
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

local function getPuzzleGridSize()
	return math.max(2, math.floor(tonumber(puzzleConfig.GridSize) or 6))
end

local function getPuzzlePairCount(stageIndex)
	local pairCounts = puzzleConfig.PairCountsByStage
	if type(pairCounts) == "table" then
		local pairCount = tonumber(pairCounts[stageIndex])
		if pairCount then
			return clamp(math.floor(pairCount), 1, math.floor((getPuzzleGridSize() * getPuzzleGridSize()) / 2))
		end
	end

	local stage = getPuzzleStage(stageIndex)
	if stage and type(stage.Pairs) == "table" then
		return math.max(1, #stage.Pairs)
	end

	return 5
end

local function getClickerStageValue(values, stageIndex, fallbackValue)
	if type(values) == "table" then
		local configuredValue = tonumber(values[stageIndex])
		if configuredValue then
			return configuredValue
		end
	end

	return fallbackValue
end

local function getClickerButtonCount()
	return math.max(1, math.floor(tonumber(puzzleConfig.ButtonCount) or 10))
end

local function getClickerPressCount(stageIndex)
	return math.max(1, math.floor(getClickerStageValue(puzzleConfig.StagePressTargets, stageIndex, 6)))
end

local function getClickerShowDuration(stageIndex)
	return math.max(0.1, getClickerStageValue(puzzleConfig.StageActiveDurations, stageIndex, 1))
end

local function getClickerDelayDuration(stageIndex)
	return math.max(0, getClickerStageValue(puzzleConfig.StageDelayDurations, stageIndex, 1))
end

local function getPuzzleSegmentLengths(stageIndex)
	local pathLengthsByStage = puzzleConfig.PathLengthsByStage
	if type(pathLengthsByStage) ~= "table" then
		return nil
	end

	local stageLengths = pathLengthsByStage[stageIndex]
	if type(stageLengths) ~= "table" or #stageLengths == 0 then
		return nil
	end

	return stageLengths
end

local function getCodeStage(stageIndex)
	return codeConfig.Stages[stageIndex]
end

local function getPuzzleRequiredCoverage(stageIndex)
	local coverageByStage = puzzleConfig.RequiredCoverageByStage
	if type(coverageByStage) == "table" then
		local stageCoverage = tonumber(coverageByStage[stageIndex])
		if stageCoverage then
			return clamp(stageCoverage, 0, 1)
		end
	end

	local defaultCoverage = tonumber(puzzleConfig.RequiredCoverage)
	if defaultCoverage then
		return clamp(defaultCoverage, 0, 1)
	end

	return 0
end

local function transformPuzzleCoordinate(size, row, column, variant)
	if variant == 1 then
		return row, column
	elseif variant == 2 then
		return column, (size - row + 1)
	elseif variant == 3 then
		return (size - row + 1), (size - column + 1)
	elseif variant == 4 then
		return (size - column + 1), row
	elseif variant == 5 then
		return row, (size - column + 1)
	elseif variant == 6 then
		return (size - row + 1), column
	elseif variant == 7 then
		return column, row
	else
		return (size - column + 1), (size - row + 1)
	end
end

local function buildPuzzleSnakeCells(size)
	local cells = {}
	for row = 1, size do
		if row % 2 == 1 then
			for column = 1, size do
				table.insert(cells, { row, column })
			end
		else
			for column = size, 1, -1 do
				table.insert(cells, { row, column })
			end
		end
	end

	return cells
end

local function buildGeneratedPuzzleStage(stageIndex)
	local size = getPuzzleGridSize()
	local segmentLengths = getPuzzleSegmentLengths(stageIndex)
	if not segmentLengths then
		return nil
	end

	local pairCount = #segmentLengths
	local colors = type(puzzleConfig.Colors) == "table" and puzzleConfig.Colors or { "#FF6B6B", "#4D96FF", "#6BCB77", "#FFD93D", "#B980F0" }
	local snakeCells = buildPuzzleSnakeCells(size)
	local cursor = 1
	local pairs = {}
	local solutionPaths = {}

	for pairId = 1, pairCount do
		local segmentLength = math.max(2, math.floor(tonumber(segmentLengths[pairId]) or 2))
		local pathCells = {}
		for offset = 0, segmentLength - 1 do
			local sourceCell = snakeCells[cursor + offset]
			if not sourceCell then
				return nil
			end
			table.insert(pathCells, { sourceCell[1], sourceCell[2] })
		end

		local startCell = pathCells[1]
		local endCell = pathCells[#pathCells]
		table.insert(pairs, {
			Id = pairId,
			Color = colors[((pairId - 1) % #colors) + 1],
			Endpoints = {
				{ startCell[1], startCell[2] },
				{ endCell[1], endCell[2] },
			},
		})
		solutionPaths[pairId] = pathCells

		cursor = cursor + segmentLength
	end

	if cursor - 1 ~= #snakeCells then
		return nil
	end

	return {
		StageIndex = stageIndex,
		Size = size,
		Pairs = pairs,
		SolutionPaths = solutionPaths,
		RequiredCoverage = getPuzzleRequiredCoverage(stageIndex),
	}
end

local function buildRuntimePuzzleStage(stageIndex)
	local generatedStage = buildGeneratedPuzzleStage(stageIndex)
	if generatedStage then
		return generatedStage
	end

	local baseStage = getPuzzleStage(stageIndex)
	if not baseStage then
		return nil
	end

	local runtimeStage = {
		StageIndex = stageIndex,
		Size = baseStage.Size,
		Pairs = baseStage.Pairs,
		SolutionPaths = baseStage.SolutionPaths,
		RequiredCoverage = getPuzzleRequiredCoverage(stageIndex),
	}

	return runtimeStage
end

local function encodePuzzleDefinition(stage)
	if not stage then
		return ""
	end

	return HttpService:JSONEncode({
		stage = stage.StageIndex,
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

	local letterCounts = {}
	for _, letter in ipairs(codeConfig.Letters) do
		letterCounts[letter] = 0
	end

	local function chooseNextCodeLetter(currentSequence)
		local eligibleLetters = {}
		local lastLetter = currentSequence[#currentSequence]
		local secondLastLetter = currentSequence[#currentSequence - 1]

		for _, letter in ipairs(codeConfig.Letters) do
			local wouldCreateTriple = lastLetter == letter and secondLastLetter == letter
			local underSoftCap = letterCounts[letter] < 3
			if not wouldCreateTriple and underSoftCap then
				table.insert(eligibleLetters, letter)
			end
		end

		if #eligibleLetters == 0 then
			for _, letter in ipairs(codeConfig.Letters) do
				local wouldCreateTriple = lastLetter == letter and secondLastLetter == letter
				if not wouldCreateTriple then
					table.insert(eligibleLetters, letter)
				end
			end
		end

		local lowestCount = math.huge
		for _, letter in ipairs(eligibleLetters) do
			lowestCount = math.min(lowestCount, letterCounts[letter])
		end

		local balancedLetters = {}
		for _, letter in ipairs(eligibleLetters) do
			if letterCounts[letter] == lowestCount then
				table.insert(balancedLetters, letter)
			end
		end

		local choicePool = #balancedLetters > 0 and balancedLetters or eligibleLetters
		return choicePool[randomGenerator:NextInteger(1, #choicePool)]
	end

	for _, lineConfig in ipairs(stage.Lines) do
		local letters = {}
		for _ = 1, lineConfig.SequenceLength do
			local letter = chooseNextCodeLetter(definition.sequence)
			table.insert(letters, letter)
			table.insert(definition.sequence, letter)
			letterCounts[letter] = (letterCounts[letter] or 0) + 1
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
		local normalizedCells = {}

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
			normalizedCells[index] = cell
			previousCell = cell
		end

		local solutionPaths = stage.SolutionPaths
		local solutionCells = solutionPaths and solutionPaths[pairId]
		if solutionCells then
			if #normalizedCells ~= #solutionCells then
				return false
			end

			local matchesForward = true
			local matchesReverse = true
			for index, cell in ipairs(normalizedCells) do
				local forwardCell = solutionCells[index]
				local reverseCell = solutionCells[#solutionCells - index + 1]

				if not forwardCell or cell.row ~= forwardCell[1] or cell.column ~= forwardCell[2] then
					matchesForward = false
				end

				if not reverseCell or cell.row ~= reverseCell[1] or cell.column ~= reverseCell[2] then
					matchesReverse = false
				end
			end

			if not matchesForward and not matchesReverse then
				return false
			end
		end

		seenPairs[pairId] = true
		validatedCount = validatedCount + 1
	end

	local occupiedCount = 0
	for _ in pairs(occupiedCells) do
		occupiedCount = occupiedCount + 1
	end

	local gridCellCount = stage.Size * stage.Size
	local requiredCoverage = clamp(stage.RequiredCoverage or 0, 0, 1)
	local requiredCells = math.ceil(gridCellCount * requiredCoverage)
	if occupiedCount < requiredCells then
		return false
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
	player:SetAttribute("TaskFlashEvent", "")
	player:SetAttribute("SpamTaskTotalStages", spamConfig.TotalStages)
	player:SetAttribute("SpamTaskCompletedStages", getSpamCompletedStages(player))
	player:SetAttribute("SpamTaskCurrentFill", 0)
	player:SetAttribute("SpamTaskGoalStart", math.max(0, 1 - spamConfig.GoalWidthScale))
	player:SetAttribute("SpamTaskGoalWidth", spamConfig.GoalWidthScale)
	player:SetAttribute("SpamTaskActive", false)
	player:SetAttribute("SpamTaskCurrentStage", math.min(getSpamCompletedStages(player) + 1, spamConfig.TotalStages))
	player:SetAttribute("SpamTaskDecayPerSecond", getSpamStageDecay(getSpamCompletedStages(player)))
	player:SetAttribute("SpamTaskLastResult", "Idle")
	player:SetAttribute("SpamTaskFlashEvent", "")
	player:SetAttribute("PuzzleTaskTotalStages", puzzleConfig.TotalStages)
	player:SetAttribute("PuzzleTaskCompletedStages", getPuzzleCompletedStages(player))
	player:SetAttribute("PuzzleTaskCurrentStage", math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages))
	player:SetAttribute("PuzzleTaskGridSize", 0)
	player:SetAttribute("PuzzleTaskActive", false)
	player:SetAttribute("PuzzleTaskDefinitionJson", "")
	player:SetAttribute("PuzzleTaskLastResult", "Idle")
	player:SetAttribute("PuzzleTaskFlashEvent", "")
	player:SetAttribute("PuzzleTaskStageTargetCount", getClickerPressCount(1))
	player:SetAttribute("PuzzleTaskStageHitCount", 0)
	player:SetAttribute("PuzzleTaskActiveButtonId", 0)
	player:SetAttribute("PuzzleTaskButtonStartedAt", 0)
	player:SetAttribute("PuzzleTaskButtonEndsAt", 0)
	player:SetAttribute("PuzzleTaskButtonDelayEndsAt", 0)
	player:SetAttribute("CodeTaskTotalStages", codeConfig.TotalStages)
	player:SetAttribute("CodeTaskCompletedStages", getCodeCompletedStages(player))
	player:SetAttribute("CodeTaskCurrentStage", math.min(getCodeCompletedStages(player) + 1, codeConfig.TotalStages))
	player:SetAttribute("CodeTaskActive", false)
	player:SetAttribute("CodeTaskDefinitionJson", "")
	player:SetAttribute("CodeTaskRevealCount", 0)
	player:SetAttribute("CodeTaskTotalInputs", 0)
	player:SetAttribute("CodeTaskLastResult", "Idle")
	player:SetAttribute("CodeTaskFlashEvent", "")
	player:SetAttribute("SelectedTaskId", nil)
	player:SetAttribute("SelectedTaskMinigameId", nil)
	syncSelectedTaskAttributes(player)
	syncTaskSummaryAttributes(player)
end

local function initializePlayer(player)
	getPlayerState(player)
	syncStaticAttributes(player, 0)
end

local function startRound(player)
	if not isSelectedTaskMinigame(player, 1) then
		return
	end

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

	local selectedTaskId = getSelectedTaskId(player)
	if not selectedTaskId or getAssignedMinigame(selectedTaskId) ~= 1 then
		return
	end

	local state = getPlayerState(player)
	local elapsedTime = math.max(0, getSyncedTime() - state.roundStartedAt)
	local markerStart = computeMarkerPosition(elapsedTime)
	local markerEnd = markerStart + taskConfig.MarkerWidthScale
	local greenStart = state.greenStart
	local greenEnd = greenStart + state.greenWidth
	local overlapStart = math.max(markerStart, greenStart)
	local overlapEnd = math.min(markerEnd, greenEnd)
	local overlapWidth = math.max(0, overlapEnd - overlapStart)
	local requiredOverlap = clamp(tonumber(taskConfig.RequiredMarkerOverlap) or 1, 0, 1)
	local success = (overlapWidth / math.max(taskConfig.MarkerWidthScale, 0.0001)) >= requiredOverlap

	local progressSegments = getProgressSegments(player)
	if success then
		progressSegments = math.min(taskConfig.TotalSegments, progressSegments + taskConfig.SuccessStep)
	else
		progressSegments = math.max(0, progressSegments - taskConfig.FailureStep)
	end

	state.greenWidth = getGreenWidth(progressSegments)
	state.roundStartedAt = 0
	setTaskProgress(player, selectedTaskId, progressSegments)
	syncTaskSummaryAttributes(player)

	player:SetAttribute("TaskProgressSegments", progressSegments)
	player:SetAttribute("TaskGreenWidth", state.greenWidth)
	player:SetAttribute("TaskMinigameActive", false)
	player:SetAttribute("TaskAttemptStartedAt", 0)
	player:SetAttribute("TaskLastResult", success and "Success" or "Fail")
	emitFlashEvent(player, "TaskFlashEvent", success and "Success" or "Fail")

	if progressSegments < taskConfig.TotalSegments and isSelectedTaskMinigame(player, 1) then
		task.defer(function()
			if isSelectedTaskMinigame(player, 1) then
				startRound(player)
			end
		end)
	end
end

local function cancelRound(player)
	if player:GetAttribute("TaskMinigameActive") ~= true then
		return
	end

	local progressSegments = getProgressSegments(player)
	local state = getPlayerState(player)
	state.roundStartedAt = 0
	state.greenWidth = getGreenWidth(progressSegments)

	player:SetAttribute("TaskGreenWidth", state.greenWidth)
	player:SetAttribute("TaskMinigameActive", false)
	player:SetAttribute("TaskAttemptStartedAt", 0)
	player:SetAttribute("TaskLastResult", "Idle")
end

local function updateSpamStageAttributes(player, completedStages, currentFill)
	player:SetAttribute("SpamTaskCompletedStages", completedStages)
	player:SetAttribute("SpamTaskCurrentFill", currentFill)
	player:SetAttribute("SpamTaskCurrentStage", math.min(completedStages + 1, spamConfig.TotalStages))
	player:SetAttribute("SpamTaskDecayPerSecond", getSpamStageDecay(completedStages))
end

local function startSpamRound(player)
	if not isSelectedTaskMinigame(player, 2) then
		return
	end

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

	local selectedTaskId = getSelectedTaskId(player)
	if not selectedTaskId or getAssignedMinigame(selectedTaskId) ~= 2 then
		return
	end

	local state = getPlayerState(player)
	local now = getSyncedTime()
	local completedStages = select(1, applySpamDecay(player, state, now))
	state.spamFill = math.min(1, state.spamFill + spamConfig.FillPerTap)

	if state.spamFill >= math.max(0, 1 - spamConfig.GoalWidthScale) then
		completedStages = math.min(spamConfig.TotalStages, completedStages + 1)
		state.spamFill = 0
		player:SetAttribute("SpamTaskLastResult", completedStages >= spamConfig.TotalStages and "Success" or "StageClear")
		emitFlashEvent(player, "SpamTaskFlashEvent", completedStages >= spamConfig.TotalStages and "Success" or "StageClear")

		if completedStages >= spamConfig.TotalStages then
			player:SetAttribute("SpamTaskActive", false)
			state.spamLastUpdatedAt = 0
		else
			state.spamLastUpdatedAt = now
		end
	else
		player:SetAttribute("SpamTaskLastResult", "Running")
	end

	setTaskProgress(player, selectedTaskId, completedStages)
	syncTaskSummaryAttributes(player)
	updateSpamStageAttributes(player, completedStages, state.spamFill)
end

local function startPuzzleStage(player, stageIndex)
	local state = getPlayerState(player)
	local now = getSyncedTime()
	state.puzzleStage = nil
	state.clickerStageIndex = stageIndex
	state.clickerHitsCompleted = 0
	state.clickerActiveButtonId = 0
	state.clickerButtonStartedAt = 0
	state.clickerButtonEndsAt = 0
	state.clickerNextButtonAt = now
	state.clickerLastButtonId = 0

	player:SetAttribute("PuzzleTaskCurrentStage", stageIndex)
	player:SetAttribute("PuzzleTaskGridSize", 0)
	player:SetAttribute("PuzzleTaskDefinitionJson", "")
	player:SetAttribute("PuzzleTaskActive", true)
	player:SetAttribute("PuzzleTaskLastResult", "Running")
	player:SetAttribute("PuzzleTaskStageTargetCount", getClickerPressCount(stageIndex))
	player:SetAttribute("PuzzleTaskStageHitCount", 0)
	player:SetAttribute("PuzzleTaskActiveButtonId", 0)
	player:SetAttribute("PuzzleTaskButtonStartedAt", 0)
	player:SetAttribute("PuzzleTaskButtonEndsAt", 0)
	player:SetAttribute("PuzzleTaskButtonDelayEndsAt", now)
	return true
end

local function failPuzzleStage(player)
	local stageIndex = math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages)
	if stageIndex < 1 then
		return
	end

	startPuzzleStage(player, stageIndex)
	player:SetAttribute("PuzzleTaskLastResult", "Fail")
	emitFlashEvent(player, "PuzzleTaskFlashEvent", "Fail")
end

local function completePuzzleStage(player)
	local selectedTaskId = getSelectedTaskId(player)
	if not selectedTaskId or getAssignedMinigame(selectedTaskId) ~= 3 then
		return
	end

	local completedStages = math.min(puzzleConfig.TotalStages, getPuzzleCompletedStages(player) + 1)
	setTaskProgress(player, selectedTaskId, completedStages)
	syncTaskSummaryAttributes(player)
	player:SetAttribute("PuzzleTaskCompletedStages", completedStages)

	local state = getPlayerState(player)
	state.clickerActiveButtonId = 0
	state.clickerButtonStartedAt = 0
	state.clickerButtonEndsAt = 0
	state.clickerNextButtonAt = 0
	player:SetAttribute("PuzzleTaskActiveButtonId", 0)
	player:SetAttribute("PuzzleTaskButtonStartedAt", 0)
	player:SetAttribute("PuzzleTaskButtonEndsAt", 0)
	player:SetAttribute("PuzzleTaskButtonDelayEndsAt", 0)

	if completedStages >= puzzleConfig.TotalStages then
		state.clickerStageIndex = 0
		state.clickerHitsCompleted = 0
		player:SetAttribute("PuzzleTaskActive", false)
		player:SetAttribute("PuzzleTaskCurrentStage", puzzleConfig.TotalStages)
		player:SetAttribute("PuzzleTaskLastResult", "Success")
		player:SetAttribute("PuzzleTaskStageHitCount", getClickerPressCount(puzzleConfig.TotalStages))
		emitFlashEvent(player, "PuzzleTaskFlashEvent", "Success")
	else
		startPuzzleStage(player, completedStages + 1)
		player:SetAttribute("PuzzleTaskLastResult", "StageClear")
		emitFlashEvent(player, "PuzzleTaskFlashEvent", "StageClear")
	end
end

local function queuePuzzleButton(player, now)
	if player:GetAttribute("PuzzleTaskActive") ~= true then
		return
	end

	local state = getPlayerState(player)
	local stageIndex = state.clickerStageIndex
	if stageIndex <= 0 then
		stageIndex = math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages)
		state.clickerStageIndex = stageIndex
	end

	if state.clickerHitsCompleted >= getClickerPressCount(stageIndex) then
		completePuzzleStage(player)
		return
	end

	local buttonCount = getClickerButtonCount()
	local buttonId = randomGenerator:NextInteger(1, buttonCount)
	if buttonCount > 1 and buttonId == state.clickerLastButtonId then
		buttonId = ((buttonId) % buttonCount) + 1
	end

	state.clickerLastButtonId = buttonId
	state.clickerActiveButtonId = buttonId
	state.clickerButtonStartedAt = now
	state.clickerButtonEndsAt = now + getClickerShowDuration(stageIndex)
	state.clickerNextButtonAt = now + getClickerDelayDuration(stageIndex)

	player:SetAttribute("PuzzleTaskActiveButtonId", buttonId)
	player:SetAttribute("PuzzleTaskButtonStartedAt", state.clickerButtonStartedAt)
	player:SetAttribute("PuzzleTaskButtonEndsAt", state.clickerButtonEndsAt)
	player:SetAttribute("PuzzleTaskButtonDelayEndsAt", state.clickerNextButtonAt)
	player:SetAttribute("PuzzleTaskLastResult", "Running")
end

local function startPuzzleRound(player)
	if not isSelectedTaskMinigame(player, 3) then
		return
	end

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

	local state = getPlayerState(player)
	state.puzzleStage = nil
	state.clickerStageIndex = 0
	state.clickerHitsCompleted = 0
	state.clickerActiveButtonId = 0
	state.clickerButtonStartedAt = 0
	state.clickerButtonEndsAt = 0
	state.clickerNextButtonAt = 0
	state.clickerLastButtonId = 0

	player:SetAttribute("PuzzleTaskActive", false)
	player:SetAttribute("PuzzleTaskGridSize", 0)
	player:SetAttribute("PuzzleTaskDefinitionJson", "")
	player:SetAttribute("PuzzleTaskLastResult", "Idle")
	player:SetAttribute("PuzzleTaskCurrentStage", math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages))
	player:SetAttribute("PuzzleTaskStageTargetCount", getClickerPressCount(math.min(getPuzzleCompletedStages(player) + 1, puzzleConfig.TotalStages)))
	player:SetAttribute("PuzzleTaskStageHitCount", 0)
	player:SetAttribute("PuzzleTaskActiveButtonId", 0)
	player:SetAttribute("PuzzleTaskButtonStartedAt", 0)
	player:SetAttribute("PuzzleTaskButtonEndsAt", 0)
	player:SetAttribute("PuzzleTaskButtonDelayEndsAt", 0)
end

local function pressPuzzleButton(player, buttonId)
	if player:GetAttribute("PuzzleTaskActive") ~= true or type(buttonId) ~= "number" then
		return
	end

	local selectedTaskId = getSelectedTaskId(player)
	if not selectedTaskId or getAssignedMinigame(selectedTaskId) ~= 3 then
		return
	end

	local state = getPlayerState(player)
	local activeButtonId = state.clickerActiveButtonId
	if activeButtonId <= 0 then
		return
	end

	buttonId = math.floor(buttonId)
	if buttonId ~= activeButtonId then
		failPuzzleStage(player)
		return
	end

	local now = getSyncedTime()
	state.clickerHitsCompleted = state.clickerHitsCompleted + 1
	state.clickerActiveButtonId = 0
	state.clickerButtonStartedAt = 0
	state.clickerButtonEndsAt = 0
	player:SetAttribute("PuzzleTaskActiveButtonId", 0)
	player:SetAttribute("PuzzleTaskButtonStartedAt", 0)
	player:SetAttribute("PuzzleTaskButtonEndsAt", 0)
	player:SetAttribute("PuzzleTaskStageHitCount", state.clickerHitsCompleted)

	if state.clickerHitsCompleted >= getClickerPressCount(state.clickerStageIndex) then
		completePuzzleStage(player)
	else
		if state.clickerNextButtonAt <= 0 then
			state.clickerNextButtonAt = now
		end
		player:SetAttribute("PuzzleTaskButtonDelayEndsAt", state.clickerNextButtonAt)
		player:SetAttribute("PuzzleTaskLastResult", "Running")
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
	if lastResult == "Fail" or lastResult == "StageClear" then
		emitFlashEvent(player, "CodeTaskFlashEvent", lastResult)
	end
	return true
end

local function startCodeRound(player)
	if not isSelectedTaskMinigame(player, 4) then
		return
	end

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

	local selectedTaskId = getSelectedTaskId(player)
	if not selectedTaskId or getAssignedMinigame(selectedTaskId) ~= 4 then
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
	setTaskProgress(player, selectedTaskId, completedStages)
	syncTaskSummaryAttributes(player)
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
		emitFlashEvent(player, "CodeTaskFlashEvent", "Success")
	else
		startCodeStage(player, completedStages + 1, "StageClear")
		player:SetAttribute("CodeTaskCompletedStages", completedStages)
	end
end

taskEvent.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" then
		return
	end

	if action == "SelectTask" then
		selectTask(player, payload)
	elseif action == "ClearTaskSelection" then
		clearSelectedTask(player)
	elseif action == "Start" then
		startRound(player)
	elseif action == "Cancel" then
		cancelRound(player)
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
	elseif action == "PuzzlePress" then
		pressPuzzleButton(player, payload)
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

buildTaskAssignments()

for _, obj in ipairs(Workspace:GetDescendants()) do
	trackTaskPart(obj)
end

Workspace.DescendantAdded:Connect(trackTaskPart)

RunService.Heartbeat:Connect(function()
	local now = getSyncedTime()

	for player, state in pairs(playerStates) do
		if player.Parent == Players and player:GetAttribute("SpamTaskActive") == true then
			local completedStages, currentFill = applySpamDecay(player, state, now)
			updateSpamStageAttributes(player, completedStages, currentFill)
		end

		if player.Parent == Players and player:GetAttribute("PuzzleTaskActive") == true then
			if state.clickerActiveButtonId > 0 and now >= state.clickerButtonEndsAt then
				failPuzzleStage(player)
			elseif state.clickerActiveButtonId <= 0 and state.clickerNextButtonAt > 0 and now >= state.clickerNextButtonAt then
				queuePuzzleButton(player, now)
			end
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