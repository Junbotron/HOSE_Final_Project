--====================================================
--              TASK INTERACTION CLIENT
--====================================================
--[[
Watches Workspace for BaseParts named "1" through "12".
For each found part, creates a client-side ProximityPrompt
(R key, RequiresLineOfSight = true).

When triggered, opens a placeholder panel showing the task
name and which minigame slot it belongs to.
The panel closes automatically when the player walks out of range.

Minigame distribution (each used 3 times across 12 tasks):
  Minigame 1 → tasks 1, 5, 9
  Minigame 2 → tasks 2, 6, 10
  Minigame 3 → tasks 3, 7, 11
  Minigame 4 → tasks 4, 8, 12
====================================================]]

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local taskEvent = ReplicatedStorage:WaitForChild("TaskMinigameEvent")

local PROXIMITY_DIST = 10
local PANEL_DEFAULT_SIZE = UDim2.fromOffset(400, 170)
local PANEL_PUZZLE_SIZE = UDim2.fromOffset(520, 580)
local PANEL_CODE_SIZE = UDim2.fromOffset(560, 390)
local PUZZLE_BOARD_PIXEL_SIZE = 420
local PUZZLE_CELL_PADDING = 2

-- ── Task definitions ─────────────────────────────────────────────────
local TASK_CONFIG = {
	[1]  = { label = "Brew coffee",               minigame = 1 },
	[2]  = { label = "Replace catalyst filters",  minigame = 2 },
	[3]  = { label = "Mix reagents",              minigame = 3 },
	[4]  = { label = "Titrate acid",              minigame = 4 },
	[5]  = { label = "Restock hazard suits",      minigame = 1 },
	[6]  = { label = "Dispose chemical waste",    minigame = 2 },
	[7]  = { label = "Run security diagnostics",  minigame = 3 },
	[8]  = { label = "Calibrate sensors",         minigame = 4 },
	[9]  = { label = "Ventilate fumes",           minigame = 1 },
	[10] = { label = "Cool main laboratory",      minigame = 2 },
	[11] = { label = "Log chemical inventory",    minigame = 3 },
	[12] = { label = "Defrost cryo tubes",        minigame = 4 },
}

-- ── GUI construction ─────────────────────────────────────────────────
local taskPanelGui = Instance.new("ScreenGui")
taskPanelGui.Name = "TaskPanelGui"
taskPanelGui.ResetOnSpawn = false
taskPanelGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = PANEL_DEFAULT_SIZE
panel.BackgroundColor3 = Color3.fromRGB(19, 24, 30)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = taskPanelGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(94, 158, 214)
panelStroke.Transparency = 0.2
panelStroke.Parent = panel

-- Task name
local taskNameLabel = Instance.new("TextLabel")
taskNameLabel.Name = "TaskName"
taskNameLabel.Size = UDim2.new(1, -32, 0, 34)
taskNameLabel.Position = UDim2.fromOffset(16, 14)
taskNameLabel.BackgroundTransparency = 1
taskNameLabel.Font = Enum.Font.GothamBold
taskNameLabel.TextSize = 21
taskNameLabel.TextColor3 = Color3.fromRGB(239, 244, 246)
taskNameLabel.TextXAlignment = Enum.TextXAlignment.Left
taskNameLabel.Parent = panel

-- Placeholder bar (represents where the minigame will live)
local placeholderBar = Instance.new("Frame")
placeholderBar.Name = "MinigamePlaceholder"
placeholderBar.Size = UDim2.new(1, -32, 0, 56)
placeholderBar.Position = UDim2.fromOffset(16, 60)
placeholderBar.BackgroundColor3 = Color3.fromRGB(38, 48, 60)
placeholderBar.BorderSizePixel = 0
placeholderBar.Parent = panel

local placeholderCorner = Instance.new("UICorner")
placeholderCorner.CornerRadius = UDim.new(0, 9)
placeholderCorner.Parent = placeholderBar

local placeholderStroke = Instance.new("UIStroke")
placeholderStroke.Color = Color3.fromRGB(70, 90, 115)
placeholderStroke.Transparency = 0.4
placeholderStroke.Thickness = 1
placeholderStroke.Parent = placeholderBar

local minigameLabel = Instance.new("TextLabel")
minigameLabel.Name = "MinigameLabel"
minigameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
minigameLabel.Position = UDim2.fromScale(0.5, 0.5)
minigameLabel.Size = UDim2.fromScale(1, 1)
minigameLabel.BackgroundTransparency = 1
minigameLabel.Font = Enum.Font.GothamBold
minigameLabel.TextSize = 15
minigameLabel.TextColor3 = Color3.fromRGB(150, 168, 190)
minigameLabel.Parent = placeholderBar

local puzzleContainer = Instance.new("Frame")
puzzleContainer.Name = "PuzzleContainer"
puzzleContainer.Size = UDim2.new(1, -32, 0, 470)
puzzleContainer.Position = UDim2.fromOffset(16, 60)
puzzleContainer.BackgroundTransparency = 1
puzzleContainer.Visible = false
puzzleContainer.Parent = panel

local puzzleStageLabel = Instance.new("TextLabel")
puzzleStageLabel.Name = "PuzzleStage"
puzzleStageLabel.Size = UDim2.new(1, 0, 0, 22)
puzzleStageLabel.BackgroundTransparency = 1
puzzleStageLabel.Font = Enum.Font.GothamBold
puzzleStageLabel.TextSize = 14
puzzleStageLabel.TextColor3 = Color3.fromRGB(160, 180, 204)
puzzleStageLabel.TextXAlignment = Enum.TextXAlignment.Left
puzzleStageLabel.Text = "Grid Task"
puzzleStageLabel.Parent = puzzleContainer

local puzzleBoard = Instance.new("Frame")
puzzleBoard.Name = "PuzzleBoard"
puzzleBoard.Size = UDim2.fromOffset(PUZZLE_BOARD_PIXEL_SIZE, PUZZLE_BOARD_PIXEL_SIZE)
puzzleBoard.Position = UDim2.new(0.5, -(PUZZLE_BOARD_PIXEL_SIZE / 2), 0, 30)
puzzleBoard.BackgroundColor3 = Color3.fromRGB(28, 34, 42)
puzzleBoard.BorderSizePixel = 0
puzzleBoard.Parent = puzzleContainer

local puzzleBoardCorner = Instance.new("UICorner")
puzzleBoardCorner.CornerRadius = UDim.new(0, 10)
puzzleBoardCorner.Parent = puzzleBoard

local puzzleBoardStroke = Instance.new("UIStroke")
puzzleBoardStroke.Color = Color3.fromRGB(70, 90, 115)
puzzleBoardStroke.Transparency = 0.2
puzzleBoardStroke.Parent = puzzleBoard

local puzzleStatusLabel = Instance.new("TextLabel")
puzzleStatusLabel.Name = "PuzzleStatus"
puzzleStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
puzzleStatusLabel.Position = UDim2.new(0.5, 0, 0, 462)
puzzleStatusLabel.Size = UDim2.new(1, 0, 0, 20)
puzzleStatusLabel.BackgroundTransparency = 1
puzzleStatusLabel.Font = Enum.Font.Gotham
puzzleStatusLabel.TextSize = 12
puzzleStatusLabel.TextColor3 = Color3.fromRGB(170, 184, 202)
puzzleStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
puzzleStatusLabel.Text = "Drag between matching numbers. Lines cannot cross."
puzzleStatusLabel.Parent = puzzleContainer

local codeContainer = Instance.new("Frame")
codeContainer.Name = "CodeContainer"
codeContainer.Size = UDim2.new(1, -32, 0, 304)
codeContainer.Position = UDim2.fromOffset(16, 60)
codeContainer.BackgroundTransparency = 1
codeContainer.Visible = false
codeContainer.Parent = panel

local codeStageLabel = Instance.new("TextLabel")
codeStageLabel.Name = "CodeStage"
codeStageLabel.Size = UDim2.new(1, 0, 0, 22)
codeStageLabel.BackgroundTransparency = 1
codeStageLabel.Font = Enum.Font.GothamBold
codeStageLabel.TextSize = 14
codeStageLabel.TextColor3 = Color3.fromRGB(160, 180, 204)
codeStageLabel.TextXAlignment = Enum.TextXAlignment.Left
codeStageLabel.Text = "Manual Override"
codeStageLabel.Parent = codeContainer

local codeLinesFrame = Instance.new("Frame")
codeLinesFrame.Name = "CodeLines"
codeLinesFrame.Size = UDim2.new(1, 0, 0, 188)
codeLinesFrame.Position = UDim2.fromOffset(0, 30)
codeLinesFrame.BackgroundTransparency = 1
codeLinesFrame.Parent = codeContainer

local codeLinesLayout = Instance.new("UIListLayout")
codeLinesLayout.FillDirection = Enum.FillDirection.Vertical
codeLinesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
codeLinesLayout.Padding = UDim.new(0, 10)
codeLinesLayout.Parent = codeLinesFrame

local codeButtonRow = Instance.new("Frame")
codeButtonRow.Name = "CodeButtons"
codeButtonRow.AnchorPoint = Vector2.new(0.5, 0)
codeButtonRow.Position = UDim2.new(0.5, 0, 0, 228)
codeButtonRow.Size = UDim2.new(1, 0, 0, 44)
codeButtonRow.BackgroundTransparency = 1
codeButtonRow.Parent = codeContainer

local codeButtonLayout = Instance.new("UIListLayout")
codeButtonLayout.FillDirection = Enum.FillDirection.Horizontal
codeButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
codeButtonLayout.Padding = UDim.new(0, 10)
codeButtonLayout.Parent = codeButtonRow

local codeStatusLabel = Instance.new("TextLabel")
codeStatusLabel.Name = "CodeStatus"
codeStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
codeStatusLabel.Position = UDim2.new(0.5, 0, 0, 276)
codeStatusLabel.Size = UDim2.new(1, 0, 0, 20)
codeStatusLabel.BackgroundTransparency = 1
codeStatusLabel.Font = Enum.Font.Gotham
codeStatusLabel.TextSize = 12
codeStatusLabel.TextColor3 = Color3.fromRGB(170, 184, 202)
codeStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
codeStatusLabel.Text = "Press the letters in order with no mistakes."
codeStatusLabel.Parent = codeContainer

-- Hint
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -10)
hintLabel.Size = UDim2.new(1, -32, 0, 20)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 12
hintLabel.TextColor3 = Color3.fromRGB(110, 120, 135)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.Text = "Move away to close"
hintLabel.Parent = panel

-- ── State ─────────────────────────────────────────────────────────────
local activePrompt = nil
local activePart   = nil
local activeConfig = nil
local puzzleDefinition = nil
local puzzleCellsByKey = {}
local puzzlePairsById = {}
local puzzleEndpointOwners = {}
local puzzlePaths = {}
local activeDragPairId = nil
local puzzleSubmitPending = false
local codeDefinition = nil
local codeDefinitionJson = ""
local codeLineViews = {}
local codeButtons = {}
local CODE_KEY_TO_LETTER = {
	[Enum.KeyCode.U] = "U",
	[Enum.KeyCode.H] = "H",
	[Enum.KeyCode.J] = "J",
	[Enum.KeyCode.K] = "K",
}

local function cellKey(row, column)
	return string.format("%d:%d", row, column)
end

local function hexToColor3(hexColor)
	local normalized = string.gsub(hexColor or "#FFFFFF", "#", "")
	if #normalized ~= 6 then
		return Color3.fromRGB(255, 255, 255)
	end

	return Color3.fromRGB(
		tonumber(string.sub(normalized, 1, 2), 16) or 255,
		tonumber(string.sub(normalized, 3, 4), 16) or 255,
		tonumber(string.sub(normalized, 5, 6), 16) or 255
	)
end

local function resetPuzzleState()
	puzzleDefinition = nil
	puzzleCellsByKey = {}
	puzzlePairsById = {}
	puzzleEndpointOwners = {}
	puzzlePaths = {}
	activeDragPairId = nil
	puzzleSubmitPending = false

	for _, child in ipairs(puzzleBoard:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

local function resetCodeState()
	codeDefinition = nil
	codeDefinitionJson = ""
	codeLineViews = {}

	for _, child in ipairs(codeLinesFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	codeStageLabel.Text = "Manual Override"
	codeStatusLabel.Text = "Press the letters in order with no mistakes."
end

local function isCodeSelected()
	return player:GetAttribute("ActiveMinigameId") == 4 and panel.Visible
end

local function getLettersText(letters)
	return table.concat(letters, "  ")
end

local function setCodeButtonsEnabled(isEnabled)
	for _, button in pairs(codeButtons) do
		button.Active = false
		button.AutoButtonColor = false
		button.BackgroundColor3 = isEnabled and Color3.fromRGB(94, 158, 214) or Color3.fromRGB(60, 70, 82)
		button.TextColor3 = isEnabled and Color3.fromRGB(244, 247, 249) or Color3.fromRGB(170, 178, 188)
		local stroke = button:FindFirstChild("Stroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = isEnabled and Color3.fromRGB(138, 196, 246) or Color3.fromRGB(86, 97, 112)
		end
	end
end

local function updateCodeVisuals()
	if not codeDefinition then
		return
	end

	local revealCount = math.max(0, player:GetAttribute("CodeTaskRevealCount") or 0)
	local lastResult = player:GetAttribute("CodeTaskLastResult")
	local isActive = player:GetAttribute("CodeTaskActive") == true
	local consumedInputs = 0

	for _, lineView in ipairs(codeLineViews) do
		local lineRevealCount = math.clamp(revealCount - consumedInputs, 0, lineView.sequenceLength)
		consumedInputs = consumedInputs + lineView.sequenceLength

		local revealCharacters = 0
		if lineView.sequenceLength > 0 then
			revealCharacters = math.floor((#lineView.html * lineRevealCount) / lineView.sequenceLength)
		end
		if lineRevealCount > 0 and revealCharacters <= 0 then
			revealCharacters = 1
		end
		if lineRevealCount >= lineView.sequenceLength then
			revealCharacters = #lineView.html
		end

		lineView.revealLabel.Text = string.sub(lineView.html, 1, revealCharacters)
	end

	if not isActive then
		if (player:GetAttribute("CodeTaskCompletedStages") or 0) >= (player:GetAttribute("CodeTaskTotalStages") or 0) then
			codeStatusLabel.Text = "Manual override complete"
		else
			codeStatusLabel.Text = "Loading override..."
		end
	elseif lastResult == "Fail" then
		codeStatusLabel.Text = "Wrong key. Pattern rerolled for this level."
	elseif lastResult == "StageClear" then
		codeStatusLabel.Text = "Stage clear. Continue the override."
	else
		codeStatusLabel.Text = "Press U, H, J, K in order with no mistakes."
	end

	setCodeButtonsEnabled(isActive)
end

local function buildCodePanel(definition, definitionJsonValue)
	resetCodeState()
	codeDefinition = definition
	codeDefinitionJson = definitionJsonValue or ""

	if not definition then
		return
	end

	codeStageLabel.Text = string.format("Manual Override %d/%d", definition.stage, player:GetAttribute("CodeTaskTotalStages") or definition.stage)

	for _, line in ipairs(definition.lines) do
		local lineCard = Instance.new("Frame")
		lineCard.Name = "CodeLine"
		lineCard.Size = UDim2.new(1, 0, 0, 54)
		lineCard.BackgroundColor3 = Color3.fromRGB(26, 32, 40)
		lineCard.BorderSizePixel = 0
		lineCard.Parent = codeLinesFrame

		local lineCardCorner = Instance.new("UICorner")
		lineCardCorner.CornerRadius = UDim.new(0, 10)
		lineCardCorner.Parent = lineCard

		local lineCardStroke = Instance.new("UIStroke")
		lineCardStroke.Color = Color3.fromRGB(58, 69, 83)
		lineCardStroke.Transparency = 0.25
		lineCardStroke.Parent = lineCard

		local hiddenLabel = Instance.new("TextLabel")
		hiddenLabel.Name = "Hidden"
		hiddenLabel.BackgroundTransparency = 1
		hiddenLabel.Position = UDim2.fromOffset(14, 6)
		hiddenLabel.Size = UDim2.new(1, -28, 0, 20)
		hiddenLabel.Font = Enum.Font.Code
		hiddenLabel.TextSize = 16
		hiddenLabel.TextColor3 = Color3.fromRGB(88, 96, 108)
		hiddenLabel.TextXAlignment = Enum.TextXAlignment.Left
		hiddenLabel.Text = line.html
		hiddenLabel.Parent = lineCard

		local revealLabel = Instance.new("TextLabel")
		revealLabel.Name = "Reveal"
		revealLabel.BackgroundTransparency = 1
		revealLabel.Position = UDim2.fromOffset(14, 6)
		revealLabel.Size = UDim2.new(1, -28, 0, 20)
		revealLabel.Font = Enum.Font.Code
		revealLabel.TextSize = 16
		revealLabel.TextColor3 = Color3.fromRGB(152, 230, 164)
		revealLabel.TextXAlignment = Enum.TextXAlignment.Left
		revealLabel.Text = ""
		revealLabel.Parent = lineCard

		local lettersLabel = Instance.new("TextLabel")
		lettersLabel.Name = "Letters"
		lettersLabel.BackgroundTransparency = 1
		lettersLabel.Position = UDim2.fromOffset(14, 30)
		lettersLabel.Size = UDim2.new(1, -28, 0, 16)
		lettersLabel.Font = Enum.Font.Gotham
		lettersLabel.TextSize = 12
		lettersLabel.TextColor3 = Color3.fromRGB(178, 184, 194)
		lettersLabel.TextXAlignment = Enum.TextXAlignment.Left
		lettersLabel.Text = getLettersText(line.letters)
		lettersLabel.Parent = lineCard

		table.insert(codeLineViews, {
			html = line.html,
			sequenceLength = #line.letters,
			revealLabel = revealLabel,
		})
	end

	updateCodeVisuals()
end

local function updateCodePanel()
	local shouldShowCode = panel.Visible and player:GetAttribute("ActiveMinigameId") == 4
	local activeDefinitionJson = player:GetAttribute("CodeTaskDefinitionJson") or ""
	local codeIsActive = player:GetAttribute("CodeTaskActive") == true
	local completedStages = player:GetAttribute("CodeTaskCompletedStages") or 0
	local totalStages = player:GetAttribute("CodeTaskTotalStages") or 0

	codeContainer.Visible = shouldShowCode
	if not shouldShowCode then
		resetCodeState()
		setCodeButtonsEnabled(false)
		return
	end

	if activeDefinitionJson ~= "" and codeIsActive then
		if activeDefinitionJson ~= codeDefinitionJson then
			local success, decodedDefinition = pcall(function()
				return HttpService:JSONDecode(activeDefinitionJson)
			end)

			if success then
				buildCodePanel(decodedDefinition, activeDefinitionJson)
			end
		end

		updateCodeVisuals()
	else
		resetCodeState()
		setCodeButtonsEnabled(false)
		if completedStages >= totalStages and totalStages > 0 then
			codeStatusLabel.Text = "Manual override complete"
		else
			codeStageLabel.Text = string.format("Manual Override %d/%d", math.min((player:GetAttribute("CodeTaskCurrentStage") or 1), math.max(totalStages, 1)), math.max(totalStages, 1))
			codeStatusLabel.Text = "Loading override..."
		end
	end
end

local function isPuzzleSelected()
	return player:GetAttribute("ActiveMinigameId") == 3 and panel.Visible
end

local function matchesEndpoint(cell, endpoint)
	return cell.row == endpoint[1] and cell.column == endpoint[2]
end

local function getPuzzleOccupant(row, column)
	for pairId, cells in pairs(puzzlePaths) do
		for _, cell in ipairs(cells) do
			if cell.row == row and cell.column == column then
				return pairId
			end
		end
	end

	return nil
end

local function findCellIndex(pathCells, row, column)
	for index, cell in ipairs(pathCells) do
		if cell.row == row and cell.column == column then
			return index
		end
	end

	return nil
end

local function isPathComplete(pairId)
	local pair = puzzlePairsById[pairId]
	local pathCells = puzzlePaths[pairId]
	if not pair or not pathCells or #pathCells < 2 then
		return false
	end

	local firstCell = pathCells[1]
	local lastCell = pathCells[#pathCells]
	local endpoints = pair.Endpoints

	return (
		(matchesEndpoint(firstCell, endpoints[1]) and matchesEndpoint(lastCell, endpoints[2]))
		or (matchesEndpoint(firstCell, endpoints[2]) and matchesEndpoint(lastCell, endpoints[1]))
	)
end

local function allPuzzlePathsComplete()
	for pairId in pairs(puzzlePairsById) do
		if not isPathComplete(pairId) then
			return false
		end
	end

	return next(puzzlePairsById) ~= nil
end

local function serializePuzzlePaths()
	local serialized = { paths = {} }

	for _, pair in ipairs(puzzleDefinition.pairs) do
		local pathCells = puzzlePaths[pair.Id]
		local serializedCells = {}
		for _, cell in ipairs(pathCells or {}) do
			table.insert(serializedCells, { row = cell.row, column = cell.column })
		end

		table.insert(serialized.paths, {
			id = pair.Id,
			cells = serializedCells,
		})
	end

	return HttpService:JSONEncode(serialized)
end

local function updatePuzzleBoardVisuals()
	if not puzzleDefinition then
		return
	end

	for key, button in pairs(puzzleCellsByKey) do
		local row = button:GetAttribute("Row")
		local column = button:GetAttribute("Column")
		local endpointPairId = puzzleEndpointOwners[key]
		local occupiedPairId = getPuzzleOccupant(row, column)

		button.Text = ""
		button.TextColor3 = Color3.fromRGB(17, 20, 26)
		button.BackgroundColor3 = Color3.fromRGB(45, 54, 64)

		if occupiedPairId then
			button.BackgroundColor3 = hexToColor3(puzzlePairsById[occupiedPairId].Color)
		end

		if endpointPairId then
			button.BackgroundColor3 = hexToColor3(puzzlePairsById[endpointPairId].Color)
			button.Text = tostring(endpointPairId)
		end
	end

	if allPuzzlePathsComplete() then
		puzzleStatusLabel.Text = "Release mouse to submit this board"
	elseif player:GetAttribute("PuzzleTaskLastResult") == "Fail" then
		puzzleStatusLabel.Text = "Invalid layout. Keep trying."
	else
		puzzleStatusLabel.Text = "Drag between matching numbers. Lines cannot cross."
	end
end

local function trySubmitPuzzle()
	if not isPuzzleSelected() or puzzleSubmitPending or player:GetAttribute("PuzzleTaskActive") ~= true then
		return
	end

	if not allPuzzlePathsComplete() then
		return
	end

	puzzleSubmitPending = true
	taskEvent:FireServer("PuzzleSubmit", serializePuzzlePaths())
end

local function extendActivePath(row, column)
	if not activeDragPairId or not puzzleDefinition then
		return
	end

	local pathCells = puzzlePaths[activeDragPairId]
	if not pathCells or #pathCells == 0 then
		return
	end

	local lastCell = pathCells[#pathCells]
	if lastCell.row == row and lastCell.column == column then
		return
	end

	local manhattanDistance = math.abs(lastCell.row - row) + math.abs(lastCell.column - column)
	if manhattanDistance ~= 1 then
		return
	end

	local existingIndex = findCellIndex(pathCells, row, column)
	if existingIndex then
		-- Retract path back to this cell (standard flow-puzzle behaviour)
		for index = #pathCells, existingIndex + 1, -1 do
			table.remove(pathCells, index)
		end
		updatePuzzleBoardVisuals()
		return
	end

	if isPathComplete(activeDragPairId) then
		return
	end

	local targetKey = cellKey(row, column)
	local endpointOwner = puzzleEndpointOwners[targetKey]
	local occupant = getPuzzleOccupant(row, column)

	if occupant and occupant ~= activeDragPairId then
		return
	end

	if endpointOwner and endpointOwner ~= activeDragPairId then
		return
	end

	table.insert(pathCells, { row = row, column = column })
	updatePuzzleBoardVisuals()
	-- Auto-submit the moment every pair is connected
	if allPuzzlePathsComplete() then
		trySubmitPuzzle()
	end
end

local function beginPathDrag(pairId, row, column)
	if not isPuzzleSelected() or player:GetAttribute("PuzzleTaskActive") ~= true then
		return
	end

	activeDragPairId = pairId
	local existingPath = puzzlePaths[pairId]

	if existingPath and #existingPath >= 2 then
		local firstCell = existingPath[1]
		local lastCell = existingPath[#existingPath]
		if lastCell.row == row and lastCell.column == column then
			-- Already at the tip end – resume drag without resetting
		elseif firstCell.row == row and firstCell.column == column then
			-- Clicked the origin end – reverse so dragging starts from here
			local reversed = {}
			for i = #existingPath, 1, -1 do
				table.insert(reversed, existingPath[i])
			end
			puzzlePaths[pairId] = reversed
		else
			puzzlePaths[pairId] = { { row = row, column = column } }
		end
	else
		puzzlePaths[pairId] = { { row = row, column = column } }
	end

	updatePuzzleBoardVisuals()
end

local function buildPuzzleBoard(definition)
	resetPuzzleState()
	puzzleDefinition = definition

	if not definition then
		return
	end

	local size = definition.size
	local cellPixelSize = math.floor(PUZZLE_BOARD_PIXEL_SIZE / size)
	local boardPixelSize = cellPixelSize * size
	puzzleBoard.Size = UDim2.fromOffset(boardPixelSize, boardPixelSize)
	puzzleBoard.Position = UDim2.new(0.5, -(boardPixelSize / 2), 0, 30)
	puzzleStageLabel.Text = string.format("Grid Task %dx%d", size, size)

	for _, pair in ipairs(definition.pairs) do
		puzzlePairsById[pair.Id] = pair
		puzzleEndpointOwners[cellKey(pair.Endpoints[1][1], pair.Endpoints[1][2])] = pair.Id
		puzzleEndpointOwners[cellKey(pair.Endpoints[2][1], pair.Endpoints[2][2])] = pair.Id
	end

	for row = 1, size do
		for column = 1, size do
			local button = Instance.new("TextButton")
			button.Name = string.format("Cell_%d_%d", row, column)
			button.Size = UDim2.fromOffset(cellPixelSize - PUZZLE_CELL_PADDING, cellPixelSize - PUZZLE_CELL_PADDING)
			button.Position = UDim2.fromOffset((column - 1) * cellPixelSize, (row - 1) * cellPixelSize)
			button.AutoButtonColor = false
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = math.max(12, math.floor(cellPixelSize * 0.34))
			button.Text = ""
			button.Parent = puzzleBoard
			button:SetAttribute("Row", row)
			button:SetAttribute("Column", column)

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, math.max(4, math.floor(cellPixelSize * 0.18)))
			corner.Parent = button

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(23, 28, 34)
			stroke.Thickness = 1
			stroke.Parent = button

			local key = cellKey(row, column)
			button.MouseButton1Down:Connect(function()
				local pairId = puzzleEndpointOwners[key]
				if not pairId then
					return
				end

				beginPathDrag(pairId, row, column)
			end)

			button.MouseEnter:Connect(function()
				extendActivePath(row, column)
			end)

			puzzleCellsByKey[key] = button
		end
	end

	updatePuzzleBoardVisuals()
end

local function updatePuzzlePanel()
	local shouldShowPuzzle = panel.Visible and player:GetAttribute("ActiveMinigameId") == 3
	local definitionJson = player:GetAttribute("PuzzleTaskDefinitionJson") or ""
	local puzzleIsActive = player:GetAttribute("PuzzleTaskActive") == true
	local completedStages = player:GetAttribute("PuzzleTaskCompletedStages") or 0
	local totalStages = player:GetAttribute("PuzzleTaskTotalStages") or 0

	puzzleContainer.Visible = shouldShowPuzzle
	if not shouldShowPuzzle then
		resetPuzzleState()
		return
	end

	puzzleSubmitPending = false

	if definitionJson ~= "" and puzzleIsActive then
		local success, decodedDefinition = pcall(function()
			return HttpService:JSONDecode(definitionJson)
		end)

		if success then
			if not puzzleDefinition or puzzleDefinition.stage ~= decodedDefinition.stage then
				buildPuzzleBoard(decodedDefinition)
			else
				puzzleSubmitPending = false
				updatePuzzleBoardVisuals()
			end
		end
	else
		resetPuzzleState()
		if completedStages >= totalStages and totalStages > 0 then
			puzzleStatusLabel.Text = "Grid task complete"
		else
			puzzleStatusLabel.Text = "Loading grid task..."
		end
	end
end

local function openTaskPanel(prompt)
	local taskNum = prompt:GetAttribute("TaskNumber")
	local config = TASK_CONFIG[taskNum]
	if not config then return end

	activeConfig = config
	activePart   = prompt.Parent
	activePrompt = prompt
	prompt.Enabled = false
	player:SetAttribute("ActiveTaskId", taskNum)
	player:SetAttribute("ActiveMinigameId", config.minigame)

	taskNameLabel.Text = config.label
	local isPuzzle = config.minigame == 3
	local isCode = config.minigame == 4
	local isPlaceholder = config.minigame >= 5
	placeholderBar.Visible = isPlaceholder
	puzzleContainer.Visible = isPuzzle
	codeContainer.Visible = isCode
	if isPuzzle then
		panel.Size = PANEL_PUZZLE_SIZE
	elseif isCode then
		panel.Size = PANEL_CODE_SIZE
	else
		panel.Size = PANEL_DEFAULT_SIZE
	end
	if isPlaceholder then
		minigameLabel.Text = string.format("[ Minigame %d  —  Placeholder ]", config.minigame)
	end
	if isPuzzle then
		hintLabel.Text = "Drag to connect matching numbers. Move away to close"
		taskEvent:FireServer("PuzzleStart")
	elseif isCode then
		hintLabel.Text = "Press U, H, J, and K in order. Wrong input rerolls the stage"
		taskEvent:FireServer("CodeStart")
	else
		hintLabel.Text = "Move away to close"
	end
	panel.Visible = true
	updatePuzzlePanel()
	updateCodePanel()
end

local function closeTaskPanel()
	if not panel.Visible then return end
	panel.Visible = false
	-- cancel any in-progress minigame so panels clear
	if player:GetAttribute("TaskMinigameActive") == true then
		taskEvent:FireServer("Resolve")
	end
	if player:GetAttribute("SpamTaskActive") == true then
		taskEvent:FireServer("SpamCancel")
	end
	if player:GetAttribute("PuzzleTaskActive") == true then
		taskEvent:FireServer("PuzzleCancel")
	end
	if player:GetAttribute("CodeTaskActive") == true then
		taskEvent:FireServer("CodeCancel")
	end
	player:SetAttribute("ActiveTaskId", nil)
	player:SetAttribute("ActiveMinigameId", nil)
	activeConfig = nil
	activePart = nil
	panel.Size = PANEL_DEFAULT_SIZE
	puzzleContainer.Visible = false
	codeContainer.Visible = false
	hintLabel.Text = "Move away to close"
	resetPuzzleState()
	resetCodeState()
	setCodeButtonsEnabled(false)
	if activePrompt then
		activePrompt.Enabled = true
		activePrompt = nil
	end
end

player:GetAttributeChangedSignal("PuzzleTaskDefinitionJson"):Connect(updatePuzzlePanel)
player:GetAttributeChangedSignal("PuzzleTaskActive"):Connect(updatePuzzlePanel)
player:GetAttributeChangedSignal("PuzzleTaskCompletedStages"):Connect(updatePuzzlePanel)
player:GetAttributeChangedSignal("PuzzleTaskLastResult"):Connect(updatePuzzlePanel)
player:GetAttributeChangedSignal("CodeTaskDefinitionJson"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskActive"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskRevealCount"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskCompletedStages"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskLastResult"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updatePuzzlePanel)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updateCodePanel)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	if activeDragPairId then
		activeDragPairId = nil
		trySubmitPuzzle()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if not isCodeSelected() or player:GetAttribute("CodeTaskActive") ~= true then
		return
	end

	local letter = CODE_KEY_TO_LETTER[input.KeyCode]
	if not letter then
		return
	end

	taskEvent:FireServer("CodeInput", letter)
end)

for _, letter in ipairs({ "U", "H", "J", "K" }) do
	local button = Instance.new("TextButton")
	button.Name = string.format("Button%s", letter)
	button.Size = UDim2.fromOffset(84, 40)
	button.BackgroundColor3 = Color3.fromRGB(94, 158, 214)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(244, 247, 249)
	button.Text = letter
	button.Parent = codeButtonRow

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Name = "Stroke"
	buttonStroke.Color = Color3.fromRGB(138, 196, 246)
	buttonStroke.Transparency = 0.2
	buttonStroke.Parent = button

	codeButtons[letter] = button
end

setCodeButtonsEnabled(false)

-- ── ProximityPrompt setup ─────────────────────────────────────────────
local function setupTaskPart(part, taskNum)
	if part:FindFirstChild("TaskPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TaskPrompt"
	prompt.ActionText = TASK_CONFIG[taskNum].label
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = true
	prompt.MaxActivationDistance = PROXIMITY_DIST
	prompt:SetAttribute("TaskNumber", taskNum)
	prompt.Parent = part

	prompt.Triggered:Connect(function()
		openTaskPanel(prompt)
	end)
end

local function checkDescendant(obj)
	if not obj:IsA("BasePart") then return end
	local num = tonumber(obj.Name)
	if num and TASK_CONFIG[num] then
		setupTaskPart(obj, num)
	end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	checkDescendant(obj)
end

Workspace.DescendantAdded:Connect(checkDescendant)

-- ── Auto-close when player walks out of range ───────────────────────
RunService.Heartbeat:Connect(function()
	if not panel.Visible or not activePart then return end
	local character = player.Character
	if not character then
		closeTaskPanel()
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		closeTaskPanel()
		return
	end
	if (root.Position - activePart.Position).Magnitude > PROXIMITY_DIST then
		closeTaskPanel()
	end
end)
