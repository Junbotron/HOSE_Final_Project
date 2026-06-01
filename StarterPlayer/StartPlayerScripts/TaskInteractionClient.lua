--====================================================
--              TASK INTERACTION CLIENT
--====================================================
--[[
Watches Workspace for BaseParts named "1" through "12".
For each found part, creates a client-side ProximityPrompt
(R key, RequiresLineOfSight = true).

When triggered, opens a panel for the task label while the
server decides which minigame type that numbered part uses.
The panel closes automatically when the player walks out of range.

Minigame distribution: the server randomly assigns 3 copies of
each minigame type across parts 1 through 12 per round.
====================================================]]

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local taskEvent = ReplicatedStorage:WaitForChild("TaskMinigameEvent")

local PROXIMITY_DIST = 10
local PANEL_DEFAULT_SIZE = UDim2.fromOffset(400, 170)
local PANEL_ACTION_SIZE = UDim2.fromOffset(540, 140)
local PANEL_PUZZLE_SIZE = UDim2.fromOffset(520, 580)
local PANEL_CODE_SIZE = UDim2.fromOffset(560, 188)
local CLICKER_BUTTON_COUNT = 10
local PUZZLE_BOARD_PIXEL_SIZE = 420
local PUZZLE_CELL_PADDING = 0
local ACTION_TRACK_HEIGHT = 18
local CODE_COMPLETED_LINE = "grant root://relay_core --bypass matrix --commit"

-- ── Task definitions ─────────────────────────────────────────────────
local TASK_LABELS = {
	[1]  = "Brew coffee",
	[2]  = "Replace catalyst filters",
	[3]  = "Mix reagents",
	[4]  = "Titrate acid",
	[5]  = "Restock hazard suits",
	[6]  = "Dispose chemical waste",
	[7]  = "Run security diagnostics",
	[8]  = "Calibrate sensors",
	[9]  = "Ventilate fumes",
	[10] = "Cool main laboratory",
	[11] = "Log chemical inventory",
	[12] = "Defrost cryo tubes",
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

local panelFlash = Instance.new("Frame")
panelFlash.Name = "PanelFlash"
panelFlash.Size = UDim2.fromScale(1, 1)
panelFlash.BackgroundTransparency = 1
panelFlash.BorderSizePixel = 0
panelFlash.ZIndex = 20
panelFlash.Parent = panel

local panelFlashCorner = Instance.new("UICorner")
panelFlashCorner.CornerRadius = UDim.new(0, 14)
panelFlashCorner.Parent = panelFlash

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

local taskInstructionLabel = Instance.new("TextLabel")
taskInstructionLabel.Name = "TaskInstruction"
taskInstructionLabel.Size = UDim2.new(1, -32, 0, 18)
taskInstructionLabel.Position = UDim2.fromOffset(16, 46)
taskInstructionLabel.BackgroundTransparency = 1
taskInstructionLabel.Font = Enum.Font.Gotham
taskInstructionLabel.TextSize = 12
taskInstructionLabel.TextColor3 = Color3.fromRGB(170, 184, 202)
taskInstructionLabel.TextXAlignment = Enum.TextXAlignment.Left
taskInstructionLabel.Text = ""
taskInstructionLabel.Visible = false
taskInstructionLabel.Parent = panel

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
codeContainer.Size = UDim2.new(1, -32, 0, 78)
codeContainer.Position = UDim2.fromOffset(16, 70)
codeContainer.BackgroundTransparency = 1
codeContainer.Visible = false
codeContainer.Parent = panel

local codeStageLabel = Instance.new("TextLabel")
codeStageLabel.Name = "CodeStage"
codeStageLabel.Size = UDim2.new(1, 0, 0, 0)
codeStageLabel.BackgroundTransparency = 1
codeStageLabel.Font = Enum.Font.GothamBold
codeStageLabel.TextSize = 13
codeStageLabel.TextColor3 = Color3.fromRGB(160, 180, 204)
codeStageLabel.TextXAlignment = Enum.TextXAlignment.Left
codeStageLabel.Text = ""
codeStageLabel.Visible = false
codeStageLabel.Parent = codeContainer

local codeLinesFrame = Instance.new("Frame")
codeLinesFrame.Name = "CodeLines"
codeLinesFrame.Size = UDim2.new(1, 0, 0, 78)
codeLinesFrame.Position = UDim2.fromOffset(0, 0)
codeLinesFrame.BackgroundTransparency = 1
codeLinesFrame.Parent = codeContainer

local codeLinesLayout = Instance.new("UIListLayout")
codeLinesLayout.FillDirection = Enum.FillDirection.Vertical
codeLinesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
codeLinesLayout.Padding = UDim.new(0, 8)
codeLinesLayout.Parent = codeLinesFrame

local codeButtonRow = Instance.new("Frame")
codeButtonRow.Name = "CodeButtons"
codeButtonRow.AnchorPoint = Vector2.new(0.5, 0)
codeButtonRow.Position = UDim2.new(0.5, 0, 0, 0)
codeButtonRow.Size = UDim2.new(1, 0, 0, 0)
codeButtonRow.BackgroundTransparency = 1
codeButtonRow.Visible = false
codeButtonRow.Parent = codeContainer

local codeButtonLayout = Instance.new("UIListLayout")
codeButtonLayout.FillDirection = Enum.FillDirection.Horizontal
codeButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
codeButtonLayout.Padding = UDim.new(0, 10)
codeButtonLayout.Parent = codeButtonRow

local codeStatusLabel = Instance.new("TextLabel")
codeStatusLabel.Name = "CodeStatus"
codeStatusLabel.AnchorPoint = Vector2.new(0, 0)
codeStatusLabel.Position = UDim2.fromOffset(0, 56)
codeStatusLabel.Size = UDim2.new(1, 0, 0, 18)
codeStatusLabel.BackgroundTransparency = 1
codeStatusLabel.Font = Enum.Font.Gotham
codeStatusLabel.TextSize = 12
codeStatusLabel.TextColor3 = Color3.fromRGB(170, 184, 202)
codeStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
codeStatusLabel.Text = ""
codeStatusLabel.Visible = true
codeStatusLabel.Parent = codeContainer

local timingContainer = Instance.new("Frame")
timingContainer.Name = "TimingContainer"
timingContainer.Size = UDim2.new(1, -32, 0, 40)
timingContainer.Position = UDim2.fromOffset(16, 72)
timingContainer.BackgroundTransparency = 1
timingContainer.Visible = false
timingContainer.Parent = panel

local timingStageLabel = Instance.new("TextLabel")
timingStageLabel.Name = "TimingStage"
timingStageLabel.Size = UDim2.new(1, 0, 0, 0)
timingStageLabel.BackgroundTransparency = 1
timingStageLabel.Font = Enum.Font.GothamBold
timingStageLabel.TextSize = 13
timingStageLabel.TextColor3 = Color3.fromRGB(160, 180, 204)
timingStageLabel.TextXAlignment = Enum.TextXAlignment.Left
timingStageLabel.Text = ""
timingStageLabel.Visible = false
timingStageLabel.Parent = timingContainer

local timingInstructionLabel = Instance.new("TextLabel")
timingInstructionLabel.Name = "TimingInstruction"
timingInstructionLabel.Position = UDim2.fromOffset(0, 28)
timingInstructionLabel.Size = UDim2.new(1, 0, 0, 20)
timingInstructionLabel.BackgroundTransparency = 1
timingInstructionLabel.Font = Enum.Font.Gotham
timingInstructionLabel.TextSize = 12
timingInstructionLabel.TextColor3 = Color3.fromRGB(180, 188, 194)
timingInstructionLabel.TextXAlignment = Enum.TextXAlignment.Left
timingInstructionLabel.Text = ""
timingInstructionLabel.Visible = false
timingInstructionLabel.Parent = timingContainer

local timingTrack = Instance.new("Frame")
timingTrack.Name = "TimingTrack"
timingTrack.Position = UDim2.fromOffset(0, 0)
timingTrack.Size = UDim2.new(1, 0, 0, ACTION_TRACK_HEIGHT)
timingTrack.BackgroundColor3 = Color3.fromRGB(146, 57, 57)
timingTrack.BorderSizePixel = 0
timingTrack.Parent = timingContainer

local timingTrackCorner = Instance.new("UICorner")
timingTrackCorner.CornerRadius = UDim.new(1, 0)
timingTrackCorner.Parent = timingTrack

local timingGreenZone = Instance.new("Frame")
timingGreenZone.Name = "GreenZone"
timingGreenZone.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
timingGreenZone.BorderSizePixel = 0
timingGreenZone.Parent = timingTrack

local timingGreenCorner = Instance.new("UICorner")
timingGreenCorner.CornerRadius = UDim.new(1, 0)
timingGreenCorner.Parent = timingGreenZone

local timingMarker = Instance.new("Frame")
timingMarker.Name = "Marker"
timingMarker.BackgroundColor3 = Color3.fromRGB(180, 186, 194)
timingMarker.BorderSizePixel = 0
timingMarker.Parent = timingTrack

local timingMarkerCorner = Instance.new("UICorner")
timingMarkerCorner.CornerRadius = UDim.new(1, 0)
timingMarkerCorner.Parent = timingMarker

local timingMarkerStroke = Instance.new("UIStroke")
timingMarkerStroke.Color = Color3.fromRGB(30, 34, 40)
timingMarkerStroke.Thickness = 2
timingMarkerStroke.Parent = timingMarker

local timingStatusLabel = Instance.new("TextLabel")
timingStatusLabel.Name = "TimingStatus"
timingStatusLabel.AnchorPoint = Vector2.new(0, 0)
timingStatusLabel.Position = UDim2.fromOffset(0, 18)
timingStatusLabel.Size = UDim2.new(1, 0, 0, 20)
timingStatusLabel.BackgroundTransparency = 1
timingStatusLabel.Font = Enum.Font.Gotham
timingStatusLabel.TextSize = 12
timingStatusLabel.TextColor3 = Color3.fromRGB(170, 184, 202)
timingStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
timingStatusLabel.Text = "Press R to stop the marker inside the green zone."
timingStatusLabel.Parent = timingContainer

local spamContainer = Instance.new("Frame")
spamContainer.Name = "SpamContainer"
spamContainer.Size = UDim2.new(1, -32, 0, 40)
spamContainer.Position = UDim2.fromOffset(16, 72)
spamContainer.BackgroundTransparency = 1
spamContainer.Visible = false
spamContainer.Parent = panel

local spamStageLabel = Instance.new("TextLabel")
spamStageLabel.Name = "SpamStage"
spamStageLabel.Size = UDim2.new(1, 0, 0, 0)
spamStageLabel.BackgroundTransparency = 1
spamStageLabel.Font = Enum.Font.GothamBold
spamStageLabel.TextSize = 13
spamStageLabel.TextColor3 = Color3.fromRGB(160, 180, 204)
spamStageLabel.TextXAlignment = Enum.TextXAlignment.Left
spamStageLabel.Text = ""
spamStageLabel.Visible = false
spamStageLabel.Parent = spamContainer

local spamInstructionLabel = Instance.new("TextLabel")
spamInstructionLabel.Name = "SpamInstruction"
spamInstructionLabel.Position = UDim2.fromOffset(0, 28)
spamInstructionLabel.Size = UDim2.new(1, 0, 0, 20)
spamInstructionLabel.BackgroundTransparency = 1
spamInstructionLabel.Font = Enum.Font.Gotham
spamInstructionLabel.TextSize = 12
spamInstructionLabel.TextColor3 = Color3.fromRGB(180, 188, 194)
spamInstructionLabel.TextXAlignment = Enum.TextXAlignment.Left
spamInstructionLabel.Text = ""
spamInstructionLabel.Visible = false
spamInstructionLabel.Parent = spamContainer

local spamTrack = Instance.new("Frame")
spamTrack.Name = "SpamTrack"
spamTrack.Position = UDim2.fromOffset(0, 0)
spamTrack.Size = UDim2.new(1, 0, 0, ACTION_TRACK_HEIGHT)
spamTrack.BackgroundColor3 = Color3.fromRGB(56, 61, 69)
spamTrack.BorderSizePixel = 0
spamTrack.Parent = spamContainer

local spamTrackCorner = Instance.new("UICorner")
spamTrackCorner.CornerRadius = UDim.new(1, 0)
spamTrackCorner.Parent = spamTrack

local spamGoalZone = Instance.new("Frame")
spamGoalZone.Name = "GoalZone"
spamGoalZone.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
spamGoalZone.BorderSizePixel = 0
spamGoalZone.Parent = spamTrack

local spamGoalCorner = Instance.new("UICorner")
spamGoalCorner.CornerRadius = UDim.new(1, 0)
spamGoalCorner.Parent = spamGoalZone

local spamFillTrack = Instance.new("Frame")
spamFillTrack.Name = "FillTrack"
spamFillTrack.BackgroundColor3 = Color3.fromRGB(196, 201, 208)
spamFillTrack.BorderSizePixel = 0
spamFillTrack.Parent = spamTrack

local spamFillCorner = Instance.new("UICorner")
spamFillCorner.CornerRadius = UDim.new(1, 0)
spamFillCorner.Parent = spamFillTrack

local spamStatusLabel = Instance.new("TextLabel")
spamStatusLabel.Name = "SpamStatus"
spamStatusLabel.AnchorPoint = Vector2.new(0, 0)
spamStatusLabel.Position = UDim2.fromOffset(0, 18)
spamStatusLabel.Size = UDim2.new(1, 0, 0, 20)
spamStatusLabel.BackgroundTransparency = 1
spamStatusLabel.Font = Enum.Font.Gotham
spamStatusLabel.TextSize = 12
spamStatusLabel.TextColor3 = Color3.fromRGB(170, 184, 202)
spamStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
spamStatusLabel.Text = "Fill the bar into the green zone with T."
spamStatusLabel.Parent = spamContainer

local clickerContainer = Instance.new("Frame")
clickerContainer.Name = "ClickerContainer"
clickerContainer.Size = UDim2.new(1, -32, 0, 44)
clickerContainer.Position = UDim2.fromOffset(16, 70)
clickerContainer.BackgroundTransparency = 1
clickerContainer.Visible = false
clickerContainer.Parent = panel

local clickerGrid = Instance.new("Frame")
clickerGrid.Name = "ClickerGrid"
clickerGrid.Size = UDim2.fromScale(1, 1)
clickerGrid.BackgroundTransparency = 1
clickerGrid.Parent = clickerContainer

local clickerGridLayout = Instance.new("UIGridLayout")
clickerGridLayout.CellSize = UDim2.fromOffset(22, 22)
clickerGridLayout.CellPadding = UDim2.fromOffset(20, 6)
clickerGridLayout.FillDirectionMaxCells = 5
clickerGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
clickerGridLayout.Parent = clickerGrid

-- Hint
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -8)
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
local pendingSelectedTaskId = nil
local puzzleDefinition = nil
local puzzleCellsByKey = {}
local puzzleCellVisuals = {}
local puzzlePairsById = {}
local puzzleEndpointOwners = {}
local puzzlePaths = {}
local activeDragPairId = nil
local puzzleSubmitPending = false
local codeDefinition = nil
local codeDefinitionJson = ""
local codeLineViews = {}
local codeButtons = {}
local clickerButtons = {}
local hoveredClickerButtonId = 0
local timingTaskStateById = {}
local CODE_KEY_TO_LETTER = {
	[Enum.KeyCode.U] = "U",
	[Enum.KeyCode.H] = "H",
	[Enum.KeyCode.J] = "J",
	[Enum.KeyCode.K] = "K",
}

local function getActiveTaskNumber()
	if not activePrompt then
		return nil
	end

	local taskNumber = activePrompt:GetAttribute("TaskNumber")
	if type(taskNumber) == "number" then
		return taskNumber
	end

	return nil
end

local function shouldUseCachedTimingState(taskNumber)
	if type(taskNumber) ~= "number" then
		return false
	end

	return pendingSelectedTaskId == taskNumber and player:GetAttribute("SelectedTaskId") ~= taskNumber
end

local function cacheTimingTaskState(taskNumber, timingState)
	if type(taskNumber) ~= "number" or type(timingState) ~= "table" then
		return
	end

	timingTaskStateById[taskNumber] = {
		totalSegments = timingState.totalSegments,
		completedSegments = timingState.completedSegments,
		isActive = timingState.isActive,
		greenStart = timingState.greenStart,
		greenWidth = timingState.greenWidth,
		markerWidthScale = timingState.markerWidthScale,
		startedAt = timingState.startedAt,
	}
end

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
	puzzleCellVisuals = {}
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

	codeStageLabel.Text = ""
	codeStatusLabel.Text = ""
end

local function getDisplayedMinigameId()
	local selectedMinigameId = player:GetAttribute("SelectedTaskMinigameId")
	if type(selectedMinigameId) == "number" then
		return selectedMinigameId
	end

	if activePrompt then
		local promptMinigameId = activePrompt:GetAttribute("AssignedMinigameId")
		if type(promptMinigameId) == "number" then
			return promptMinigameId
		end

		local promptParent = activePrompt.Parent
		if promptParent and promptParent:IsA("BasePart") then
			local partMinigameId = promptParent:GetAttribute("AssignedMinigameId")
			if type(partMinigameId) == "number" then
				return partMinigameId
			end
		end
	end

	local activeMinigameId = player:GetAttribute("ActiveMinigameId")
	if type(activeMinigameId) == "number" then
		return activeMinigameId
	end

	return nil
end

local function isActiveTaskSelectionReady()
	if not activePrompt then
		return false
	end

	local taskNumber = activePrompt:GetAttribute("TaskNumber")
	local selectedTaskId = player:GetAttribute("SelectedTaskId")
	if selectedTaskId == taskNumber then
		return true
	end

	return pendingSelectedTaskId == taskNumber
end

local function updateTaskBodyVisibility()
	if not panel.Visible or not activePrompt then
		timingContainer.Visible = false
		spamContainer.Visible = false
		clickerContainer.Visible = false
		puzzleContainer.Visible = false
		codeContainer.Visible = false
		return false
	end

	local isReady = isActiveTaskSelectionReady()
	if not isReady then
		timingContainer.Visible = false
		spamContainer.Visible = false
		clickerContainer.Visible = false
		puzzleContainer.Visible = false
		codeContainer.Visible = false
		return false
	end

	local minigameId = getDisplayedMinigameId()
	timingContainer.Visible = minigameId == 1
	spamContainer.Visible = minigameId == 2
	clickerContainer.Visible = minigameId == 3
	puzzleContainer.Visible = false
	codeContainer.Visible = minigameId == 4
	return true
end

local panelFlashTween = nil
local panelFlashGeneration = 0

local function flashPanel(color)
	if not panel.Visible then
		return
	end

	local minigameId = getDisplayedMinigameId()
	if minigameId ~= 1 and minigameId ~= 2 and minigameId ~= 3 and minigameId ~= 4 then
		return
	end

	panelFlashGeneration = panelFlashGeneration + 1
	local generation = panelFlashGeneration

	if panelFlashTween then
		panelFlashTween:Cancel()
	end

	panelFlash.BackgroundColor3 = color
	panelFlash.BackgroundTransparency = 0.42
	panelFlashTween = TweenService:Create(
		panelFlash,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	panelFlashTween:Play()
	panelFlashTween.Completed:Connect(function()
		if panelFlashGeneration == generation then
			panelFlashTween = nil
		end
	end)
end

local function flashSuccess()
	flashPanel(Color3.fromRGB(87, 184, 98))
end

local function flashFailure()
	flashPanel(Color3.fromRGB(196, 74, 74))
end

local function triggerTimingFlash()
	local flashEvent = player:GetAttribute("TaskFlashEvent") or ""
	local result = string.match(flashEvent, "^([^:]+):") or flashEvent
	if result == "Success" then
		flashSuccess()
	elseif result == "Fail" then
		flashFailure()
	end
end

local function triggerSpamFlash()
	local flashEvent = player:GetAttribute("SpamTaskFlashEvent") or ""
	local result = string.match(flashEvent, "^([^:]+):") or flashEvent
	if result == "StageClear" or result == "Success" then
		flashSuccess()
	end
end

local function triggerCodeFlash()
	local flashEvent = player:GetAttribute("CodeTaskFlashEvent") or ""
	local result = string.match(flashEvent, "^([^:]+):") or flashEvent
	if result == "StageClear" or result == "Success" then
		flashSuccess()
	elseif result == "Fail" then
		flashFailure()
	end
end

local function triggerPuzzleFlash()
	local flashEvent = player:GetAttribute("PuzzleTaskFlashEvent") or ""
	local result = string.match(flashEvent, "^([^:]+):") or flashEvent
	if result == "StageClear" or result == "Success" then
		flashSuccess()
	elseif result == "Fail" then
		flashFailure()
	end
end

local function getTaskInstructionText(minigameId)
	if minigameId == 1 then
		return "Press R when most of the marker is inside green."
	elseif minigameId == 2 then
		return "Spam T until the fill reaches the green zone."
	elseif minigameId == 3 then
		return "Click the lit button while it is green."
	elseif minigameId == 4 then
		return "Type the shown letters in order."
	end

	return ""
end

local function applyPanelLayout(minigameId)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -42)
	taskInstructionLabel.Visible = true
	taskInstructionLabel.Text = getTaskInstructionText(minigameId)
end

local function getTimingHintText(isActive)
	if isActive then
		return "Press R when most of the marker is inside green"
	end

	return "Line up the marker and press R"
end

local function getSpamHintText(isActive)
	local currentStage = math.min(player:GetAttribute("SpamTaskCurrentStage") or 1, math.max(player:GetAttribute("SpamTaskTotalStages") or 1, 1))
	local totalStages = math.max(player:GetAttribute("SpamTaskTotalStages") or 1, 1)

	if isActive then
		return string.format("Task completion: %d/%d", currentStage, totalStages)
	end

	return string.format("Task completion: %d/%d", currentStage, totalStages)
end

local function computeTimingMarkerPosition(elapsedTime)
	local markerWidthScale = math.clamp(player:GetAttribute("TaskMarkerWidthScale") or 0.01, 0.01, 1)
	local swingSpeed = math.max(0, player:GetAttribute("TaskSwingSpeed") or 0)
	local maxPosition = 1 - markerWidthScale
	if maxPosition <= 0 then
		return 0
	end

	local cycleLength = maxPosition * 2
	local traveled = (elapsedTime * swingSpeed) % cycleLength
	if traveled > maxPosition then
		return cycleLength - traveled
	end

	return traveled
end

local function updateTimingPanel()
	local shouldShowTiming = panel.Visible and getDisplayedMinigameId() == 1
	shouldShowTiming = shouldShowTiming and isActiveTaskSelectionReady()
	timingContainer.Visible = shouldShowTiming
	if not shouldShowTiming then
		return
	end

	local taskNumber = getActiveTaskNumber()
	local cachedTimingState = shouldUseCachedTimingState(taskNumber) and timingTaskStateById[taskNumber] or nil
	local totalSegments = math.max((cachedTimingState and cachedTimingState.totalSegments) or player:GetAttribute("TaskTotalSegments") or 1, 1)
	local completedSegments = math.clamp((cachedTimingState and cachedTimingState.completedSegments) or player:GetAttribute("TaskProgressSegments") or 0, 0, totalSegments)
	local isActive = cachedTimingState and cachedTimingState.isActive or (player:GetAttribute("TaskMinigameActive") == true)
	local greenStart = math.clamp((cachedTimingState and cachedTimingState.greenStart) or player:GetAttribute("TaskGreenStart") or 0, 0, 1)
	local greenWidth = math.clamp((cachedTimingState and cachedTimingState.greenWidth) or player:GetAttribute("TaskGreenWidth") or 0.2, 0, 1)
	local markerWidthScale = math.clamp((cachedTimingState and cachedTimingState.markerWidthScale) or player:GetAttribute("TaskMarkerWidthScale") or 0.08, 0.01, 1)
	local startedAt = (cachedTimingState and cachedTimingState.startedAt) or player:GetAttribute("TaskAttemptStartedAt") or 0
	local elapsedTime = isActive and math.max(0, Workspace:GetServerTimeNow() - startedAt) or 0
	local isCompleted = completedSegments >= totalSegments
	local currentStage = math.min(completedSegments + 1, totalSegments)

	if player:GetAttribute("SelectedTaskId") == taskNumber then
		cacheTimingTaskState(taskNumber, {
			totalSegments = totalSegments,
			completedSegments = completedSegments,
			isActive = isActive,
			greenStart = greenStart,
			greenWidth = greenWidth,
			markerWidthScale = markerWidthScale,
			startedAt = startedAt,
		})
	end

	timingStageLabel.Text = ""
	timingStatusLabel.Text = isCompleted and "Task completed" or string.format("Task completion: %d/%d", currentStage, totalSegments)
	timingTrack.BackgroundColor3 = isCompleted and Color3.fromRGB(87, 184, 98) or Color3.fromRGB(146, 57, 57)
	timingGreenZone.Visible = not isCompleted
	timingMarker.Visible = not isCompleted
	timingGreenZone.Position = UDim2.fromScale(greenStart, 0)
	timingGreenZone.Size = UDim2.fromScale(greenWidth, 1)
	timingMarker.Position = UDim2.fromScale(computeTimingMarkerPosition(elapsedTime), 0)
	timingMarker.Size = UDim2.fromScale(markerWidthScale, 1)
end

local function updateSpamPanel()
	local shouldShowSpam = panel.Visible and getDisplayedMinigameId() == 2
	shouldShowSpam = shouldShowSpam and isActiveTaskSelectionReady()
	spamContainer.Visible = shouldShowSpam
	if not shouldShowSpam then
		return
	end

	local totalStages = math.max(player:GetAttribute("SpamTaskTotalStages") or 1, 1)
	local currentStage = math.min(player:GetAttribute("SpamTaskCurrentStage") or 1, totalStages)
	local completedStages = math.clamp(player:GetAttribute("SpamTaskCompletedStages") or 0, 0, totalStages)
	local isActive = player:GetAttribute("SpamTaskActive") == true
	local goalStart = math.clamp(player:GetAttribute("SpamTaskGoalStart") or 1, 0, 1)
	local goalWidth = math.clamp(player:GetAttribute("SpamTaskGoalWidth") or 0, 0, 1)
	local currentFill = math.clamp(player:GetAttribute("SpamTaskCurrentFill") or 0, 0, 1)
	local isCompleted = completedStages >= totalStages

	spamStageLabel.Text = ""
	spamStatusLabel.Text = isCompleted and "Task completed" or getSpamHintText(isActive)
	spamTrack.BackgroundColor3 = isCompleted and Color3.fromRGB(87, 184, 98) or Color3.fromRGB(56, 61, 69)
	spamGoalZone.Visible = not isCompleted
	spamFillTrack.Visible = not isCompleted
	spamGoalZone.Position = UDim2.fromScale(goalStart, 0)
	spamGoalZone.Size = UDim2.fromScale(goalWidth, 1)
	spamFillTrack.Position = UDim2.fromScale(0, 0)
	spamFillTrack.Size = UDim2.fromScale(currentFill, 1)
end

local function updateClickerPanel()
	local shouldShowClicker = panel.Visible and getDisplayedMinigameId() == 3
	shouldShowClicker = shouldShowClicker and isActiveTaskSelectionReady()
	clickerContainer.Visible = shouldShowClicker
	puzzleContainer.Visible = false
	if not shouldShowClicker then
		return
	end

	local totalStages = math.max(player:GetAttribute("PuzzleTaskTotalStages") or 1, 1)
	local completedStages = math.clamp(player:GetAttribute("PuzzleTaskCompletedStages") or 0, 0, totalStages)
	local currentStage = math.min(player:GetAttribute("PuzzleTaskCurrentStage") or 1, totalStages)
	local stageTargetCount = math.max(player:GetAttribute("PuzzleTaskStageTargetCount") or 0, 0)
	local stageHitCount = math.clamp(player:GetAttribute("PuzzleTaskStageHitCount") or 0, 0, math.max(stageTargetCount, 0))
	local activeButtonId = player:GetAttribute("PuzzleTaskActiveButtonId") or 0
	local buttonStartedAt = player:GetAttribute("PuzzleTaskButtonStartedAt") or 0
	local buttonEndsAt = player:GetAttribute("PuzzleTaskButtonEndsAt") or 0
	local isCompleted = completedStages >= totalStages

	if isCompleted then
		taskInstructionLabel.Text = "Clicker task complete."
	else
		taskInstructionLabel.Text = string.format("Click the lit green button. Level %d/%d  %d/%d", currentStage, totalStages, stageHitCount, stageTargetCount)
	end

	for index, button in ipairs(clickerButtons) do
		local stroke = button:FindFirstChild("Stroke")
		local isActive = not isCompleted and activeButtonId == index and buttonEndsAt > buttonStartedAt
		local isHovered = not isCompleted and hoveredClickerButtonId == index
		if isActive then
			button.BackgroundColor3 = isHovered and Color3.fromRGB(104, 205, 114) or Color3.fromRGB(87, 184, 98)
			button.BackgroundTransparency = 0.08
			if stroke then
				stroke.Color = isHovered and Color3.fromRGB(234, 255, 236) or Color3.fromRGB(206, 245, 210)
				stroke.Transparency = 0.08
				stroke.Thickness = isHovered and 2 or 1
			end
		else
			button.BackgroundColor3 = isHovered and Color3.fromRGB(80, 91, 106) or Color3.fromRGB(58, 66, 78)
			button.BackgroundTransparency = isHovered and 0.02 or 0.1
			if stroke then
				stroke.Color = isHovered and Color3.fromRGB(170, 188, 212) or Color3.fromRGB(97, 112, 132)
				stroke.Transparency = 0.15
				stroke.Thickness = isHovered and 2 or 1
			end
		end
		button.Active = not isCompleted
	end
end

local function getPromptMinigameId(prompt)
	if not prompt then
		return nil
	end

	local promptMinigameId = prompt:GetAttribute("AssignedMinigameId")
	if type(promptMinigameId) == "number" then
		return promptMinigameId
	end

	local promptParent = prompt.Parent
	if promptParent and promptParent:IsA("BasePart") then
		local partMinigameId = promptParent:GetAttribute("AssignedMinigameId")
		if type(partMinigameId) == "number" then
			return partMinigameId
		end
	end

	return nil
end

local function isCodeSelected()
	return getDisplayedMinigameId() == 4 and panel.Visible
end

local function getLettersText(letters)
	local groups = {}
	local group = {}

	for index, letter in ipairs(letters) do
		table.insert(group, letter)
		if index % 5 == 0 then
			table.insert(groups, table.concat(group, " "))
			group = {}
		end
	end

	if #group > 0 then
		table.insert(groups, table.concat(group, " "))
	end

	return table.concat(groups, "   ")
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

	codeStatusLabel.Text = string.format("Task completion: %d/%d", math.min(player:GetAttribute("CodeTaskCurrentStage") or 1, math.max(player:GetAttribute("CodeTaskTotalStages") or 1, 1)), math.max(player:GetAttribute("CodeTaskTotalStages") or 1, 1))
	if not isActive and lastResult == "Success" then
		codeStatusLabel.Text = string.format("Task completion: %d/%d", math.max(player:GetAttribute("CodeTaskCompletedStages") or 0, 0), math.max(player:GetAttribute("CodeTaskTotalStages") or 1, 1))
	end

	setCodeButtonsEnabled(isActive)
end

local function buildCompletedCodePanel(completedStages, totalStages)
	resetCodeState()

	local lineCard = Instance.new("Frame")
	lineCard.Name = "CompletedCodeLine"
	lineCard.Size = UDim2.new(1, 0, 0, 48)
	lineCard.BackgroundColor3 = Color3.fromRGB(20, 42, 28)
	lineCard.BorderSizePixel = 0
	lineCard.Parent = codeLinesFrame

	local lineCardCorner = Instance.new("UICorner")
	lineCardCorner.CornerRadius = UDim.new(0, 10)
	lineCardCorner.Parent = lineCard

	local lineCardStroke = Instance.new("UIStroke")
	lineCardStroke.Color = Color3.fromRGB(87, 184, 98)
	lineCardStroke.Transparency = 0.1
	lineCardStroke.Parent = lineCard

	local revealLabel = Instance.new("TextLabel")
	revealLabel.Name = "Reveal"
	revealLabel.BackgroundTransparency = 1
	revealLabel.Position = UDim2.fromOffset(14, 14)
	revealLabel.Size = UDim2.new(1, -28, 0, 20)
	revealLabel.Font = Enum.Font.Code
	revealLabel.TextSize = 15
	revealLabel.TextColor3 = Color3.fromRGB(152, 230, 164)
	revealLabel.TextXAlignment = Enum.TextXAlignment.Left
	revealLabel.Text = CODE_COMPLETED_LINE
	revealLabel.Parent = lineCard

	codeStatusLabel.Text = string.format("Task completion: %d/%d", completedStages, totalStages)
end

local function buildCodePanel(definition, definitionJsonValue)
	resetCodeState()
	codeDefinition = definition
	codeDefinitionJson = definitionJsonValue or ""

	if not definition then
		return
	end

	codeStageLabel.Text = ""

	for _, line in ipairs(definition.lines) do
		local lineCard = Instance.new("Frame")
		lineCard.Name = "CodeLine"
		lineCard.Size = UDim2.new(1, 0, 0, 48)
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
		hiddenLabel.TextSize = 15
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
		revealLabel.TextSize = 15
		revealLabel.TextColor3 = Color3.fromRGB(152, 230, 164)
		revealLabel.TextXAlignment = Enum.TextXAlignment.Left
		revealLabel.Text = ""
		revealLabel.Parent = lineCard

		local lettersLabel = Instance.new("TextLabel")
		lettersLabel.Name = "Letters"
		lettersLabel.BackgroundTransparency = 1
		lettersLabel.Position = UDim2.fromOffset(14, 24)
		lettersLabel.Size = UDim2.new(1, -28, 0, 20)
		lettersLabel.Font = Enum.Font.Code
		lettersLabel.TextSize = 15
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
	local shouldShowCode = panel.Visible and getDisplayedMinigameId() == 4
	shouldShowCode = shouldShowCode and isActiveTaskSelectionReady()
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
		if completedStages >= totalStages and totalStages > 0 then
			buildCompletedCodePanel(completedStages, totalStages)
		else
			resetCodeState()
			codeStatusLabel.Text = string.format("Task completion: %d/%d", math.min((player:GetAttribute("CodeTaskCurrentStage") or 1), math.max(totalStages, 1)), math.max(totalStages, 1))
		end
		setCodeButtonsEnabled(false)
	end
end

local function isPuzzleSelected()
	return getDisplayedMinigameId() == 3 and panel.Visible
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
		local visuals = puzzleCellVisuals[key]
		local row = button:GetAttribute("Row")
		local column = button:GetAttribute("Column")
		local endpointPairId = puzzleEndpointOwners[key]
		local occupiedPairId = getPuzzleOccupant(row, column)
		local displayPairId = occupiedPairId or endpointPairId
		local pathCells = displayPairId and puzzlePaths[displayPairId] or nil
		local pathIndex = pathCells and findCellIndex(pathCells, row, column) or nil
		local previousCell = pathIndex and pathCells[pathIndex - 1] or nil
		local nextCell = pathIndex and pathCells[pathIndex + 1] or nil
		local connectUp = false
		local connectDown = false
		local connectLeft = false
		local connectRight = false

		button.Text = ""
		button.TextColor3 = Color3.fromRGB(17, 20, 26)
		button.BackgroundColor3 = Color3.fromRGB(45, 54, 64)

		if previousCell then
			connectUp = connectUp or (previousCell.row == row - 1 and previousCell.column == column)
			connectDown = connectDown or (previousCell.row == row + 1 and previousCell.column == column)
			connectLeft = connectLeft or (previousCell.row == row and previousCell.column == column - 1)
			connectRight = connectRight or (previousCell.row == row and previousCell.column == column + 1)
		end

		if nextCell then
			connectUp = connectUp or (nextCell.row == row - 1 and nextCell.column == column)
			connectDown = connectDown or (nextCell.row == row + 1 and nextCell.column == column)
			connectLeft = connectLeft or (nextCell.row == row and nextCell.column == column - 1)
			connectRight = connectRight or (nextCell.row == row and nextCell.column == column + 1)
		end

		if visuals then
			visuals.Up.Visible = false
			visuals.Down.Visible = false
			visuals.Left.Visible = false
			visuals.Right.Visible = false
			visuals.Center.Visible = false
			visuals.Endpoint.Visible = false
		end

		if displayPairId and visuals then
			local color = hexToColor3(puzzlePairsById[displayPairId].Color)
			visuals.Up.BackgroundColor3 = color
			visuals.Down.BackgroundColor3 = color
			visuals.Left.BackgroundColor3 = color
			visuals.Right.BackgroundColor3 = color
			visuals.Center.BackgroundColor3 = color
			visuals.Endpoint.BackgroundColor3 = color

			visuals.Up.Visible = pathIndex ~= nil and connectUp
			visuals.Down.Visible = pathIndex ~= nil and connectDown
			visuals.Left.Visible = pathIndex ~= nil and connectLeft
			visuals.Right.Visible = pathIndex ~= nil and connectRight
			visuals.Center.Visible = pathIndex ~= nil and endpointPairId == nil
			visuals.Endpoint.Visible = endpointPairId ~= nil
		end

		if endpointPairId then
			button.Text = tostring(endpointPairId)
		end
	end

	if allPuzzlePathsComplete() then
		puzzleStatusLabel.Text = "Release mouse to submit this board"
	elseif player:GetAttribute("PuzzleTaskLastResult") == "Fail" then
		puzzleStatusLabel.Text = "Invalid layout. Keep trying."
	else
		puzzleStatusLabel.Text = "Connect matching numbers. Click a number to reset that cable or a wire tile to rewind it."
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

	if existingPath and #existingPath >= 1 then
		local clickedIndex = findCellIndex(existingPath, row, column)
		if clickedIndex then
			for index = #existingPath, clickedIndex + 1, -1 do
				table.remove(existingPath, index)
			end

			if clickedIndex == 1 then
				puzzlePaths[pairId] = { { row = row, column = column } }
			end
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
	local wireThickness = math.max(5, math.floor(cellPixelSize * 0.18))
	local centerSize = math.max(wireThickness, math.floor(cellPixelSize * 0.24))
	local endpointSize = math.max(centerSize + 8, math.floor(cellPixelSize * 0.54))
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
			button.BackgroundColor3 = Color3.fromRGB(45, 54, 64)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = math.max(12, math.floor(cellPixelSize * 0.34))
			button.TextColor3 = Color3.fromRGB(17, 20, 26)
			button.TextStrokeTransparency = 0.75
			button.ZIndex = 4
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

			local function createConnector(name, sizeValue, positionValue, zIndex)
				local connector = Instance.new("Frame")
				connector.Name = name
				connector.Size = sizeValue
				connector.Position = positionValue
				connector.BackgroundTransparency = 0
				connector.BorderSizePixel = 0
				connector.Visible = false
				connector.ZIndex = zIndex
				connector.Parent = button
				return connector
			end

			local upConnector = createConnector("Up", UDim2.fromOffset(wireThickness, math.ceil(cellPixelSize * 0.5)), UDim2.new(0.5, math.floor(-wireThickness / 2), 0, 0), 2)
			local downConnector = createConnector("Down", UDim2.fromOffset(wireThickness, math.ceil(cellPixelSize * 0.5)), UDim2.new(0.5, math.floor(-wireThickness / 2), 0.5, 0), 2)
			local leftConnector = createConnector("Left", UDim2.fromOffset(math.ceil(cellPixelSize * 0.5), wireThickness), UDim2.new(0, 0, 0.5, math.floor(-wireThickness / 2)), 2)
			local rightConnector = createConnector("Right", UDim2.fromOffset(math.ceil(cellPixelSize * 0.5), wireThickness), UDim2.new(0.5, 0, 0.5, math.floor(-wireThickness / 2)), 2)

			local centerDot = Instance.new("Frame")
			centerDot.Name = "Center"
			centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
			centerDot.Position = UDim2.fromScale(0.5, 0.5)
			centerDot.Size = UDim2.fromOffset(centerSize, centerSize)
			centerDot.BorderSizePixel = 0
			centerDot.Visible = false
			centerDot.ZIndex = 3
			centerDot.Parent = button

			local centerCorner = Instance.new("UICorner")
			centerCorner.CornerRadius = UDim.new(1, 0)
			centerCorner.Parent = centerDot

			local endpointDot = Instance.new("Frame")
			endpointDot.Name = "Endpoint"
			endpointDot.AnchorPoint = Vector2.new(0.5, 0.5)
			endpointDot.Position = UDim2.fromScale(0.5, 0.5)
			endpointDot.Size = UDim2.fromOffset(endpointSize, endpointSize)
			endpointDot.BorderSizePixel = 0
			endpointDot.Visible = false
			endpointDot.ZIndex = 3
			endpointDot.Parent = button

			local endpointCorner = Instance.new("UICorner")
			endpointCorner.CornerRadius = UDim.new(1, 0)
			endpointCorner.Parent = endpointDot

			local endpointStroke = Instance.new("UIStroke")
			endpointStroke.Color = Color3.fromRGB(18, 22, 26)
			endpointStroke.Transparency = 0.3
			endpointStroke.Thickness = 1.5
			endpointStroke.Parent = endpointDot

			local key = cellKey(row, column)
			button.MouseButton1Down:Connect(function()
				local pairId = puzzleEndpointOwners[key]
				if pairId then
					beginPathDrag(pairId, row, column)
					return
				end

				local occupiedPairId = getPuzzleOccupant(row, column)
				if occupiedPairId then
					beginPathDrag(occupiedPairId, row, column)
				end
			end)

			button.MouseEnter:Connect(function()
				extendActivePath(row, column)
			end)

			puzzleCellsByKey[key] = button
			puzzleCellVisuals[key] = {
				Up = upConnector,
				Down = downConnector,
				Left = leftConnector,
				Right = rightConnector,
				Center = centerDot,
				Endpoint = endpointDot,
			}
		end
	end

	updatePuzzleBoardVisuals()
end

local function updatePuzzlePanel()
	puzzleContainer.Visible = false
	resetPuzzleState()
end

local function openTaskPanel(prompt)
	local taskNum = prompt:GetAttribute("TaskNumber")
	local taskLabel = TASK_LABELS[taskNum]
	local minigameId = getPromptMinigameId(prompt)
	if not taskLabel or not minigameId then return end

	applyPanelLayout(minigameId)
	activeConfig = { label = taskLabel, minigame = minigameId }
	activePart   = prompt.Parent
	activePrompt = prompt
	pendingSelectedTaskId = taskNum
	prompt.Enabled = false
	player:SetAttribute("ActiveTaskId", taskNum)
	player:SetAttribute("ActiveMinigameId", minigameId)
	taskEvent:FireServer("SelectTask", taskNum)

	taskNameLabel.Text = taskLabel
	local isClicker = minigameId == 3
	local isCode = minigameId == 4
	local isPlaceholder = false
	taskInstructionLabel.Visible = true
	placeholderBar.Visible = isPlaceholder
	timingContainer.Visible = false
	spamContainer.Visible = false
	clickerContainer.Visible = false
	puzzleContainer.Visible = false
	codeContainer.Visible = false
	if isCode then
		panel.Size = PANEL_CODE_SIZE
	elseif minigameId == 1 or minigameId == 2 or minigameId == 3 then
		panel.Size = PANEL_ACTION_SIZE
	else
		panel.Size = PANEL_DEFAULT_SIZE
	end
	if isPlaceholder then
		minigameLabel.Text = string.format("[ Minigame %d  —  Placeholder ]", minigameId)
	end
	if isClicker then
		taskInstructionLabel.Text = "Click the lit green button."
		hintLabel.Text = "Move away to close task"
		hintLabel.Position = UDim2.new(0.5, 0, 1, -2)
		taskEvent:FireServer("PuzzleStart")
	elseif isCode then
		taskInstructionLabel.Text = "Type the shown letters in order."
		hintLabel.Text = "Move away to close task"
		hintLabel.Position = UDim2.new(0.5, 0, 1, -20)
		taskEvent:FireServer("CodeStart")
	elseif minigameId == 2 then
		taskInstructionLabel.Text = "Spam T until the fill reaches green."
		hintLabel.Text = "Move away to close task"
		hintLabel.Position = UDim2.new(0.5, 0, 1, -8)
		taskEvent:FireServer("SpamStart")
	elseif minigameId == 1 then
		taskInstructionLabel.Text = "Stop when most of the marker is inside green."
		hintLabel.Text = "Move away to close task"
		hintLabel.Position = UDim2.new(0.5, 0, 1, -8)
		taskEvent:FireServer("Start")
	else
		taskInstructionLabel.Text = ""
		hintLabel.Text = "Move away to close"
		hintLabel.Position = UDim2.new(0.5, 0, 1, -8)
	end
	panel.Visible = true
	updateTaskBodyVisibility()
	if isActiveTaskSelectionReady() then
		updateTimingPanel()
		updateSpamPanel()
		updateClickerPanel()
		updateCodePanel()
	end
end

local function closeTaskPanel()
	if not panel.Visible then return end
	panel.Visible = false
	-- cancel any in-progress minigame so panels clear
	if player:GetAttribute("TaskMinigameActive") == true then
		taskEvent:FireServer("Cancel")
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
	taskEvent:FireServer("ClearTaskSelection")
	player:SetAttribute("ActiveTaskId", nil)
	player:SetAttribute("ActiveMinigameId", nil)
	activeConfig = nil
	activePart = nil
	hoveredClickerButtonId = 0
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = PANEL_DEFAULT_SIZE
	hintLabel.Position = UDim2.new(0.5, 0, 1, -8)
	taskInstructionLabel.Visible = false
	taskInstructionLabel.Text = ""
	timingContainer.Visible = false
	spamContainer.Visible = false
	clickerContainer.Visible = false
	puzzleContainer.Visible = false
	codeContainer.Visible = false
	hintLabel.Text = "Move away to close task"
	resetPuzzleState()
	resetCodeState()
	setCodeButtonsEnabled(false)
	pendingSelectedTaskId = nil
	if activePrompt then
		activePrompt.Enabled = getPromptMinigameId(activePrompt) ~= nil
		activePrompt = nil
	end
end

local function setupTaskPart(part, taskNum)
	if part:FindFirstChild("TaskPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TaskPrompt"
	prompt.ActionText = TASK_LABELS[taskNum]
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = true
	prompt.MaxActivationDistance = PROXIMITY_DIST
	prompt.Enabled = part:GetAttribute("AssignedMinigameId") ~= nil
	prompt:SetAttribute("TaskNumber", taskNum)
	prompt:SetAttribute("AssignedMinigameId", part:GetAttribute("AssignedMinigameId"))
	prompt.Parent = part

	part:GetAttributeChangedSignal("AssignedMinigameId"):Connect(function()
		local assignedMinigameId = part:GetAttribute("AssignedMinigameId")
		prompt:SetAttribute("AssignedMinigameId", assignedMinigameId)
		if activePrompt ~= prompt then
			prompt.Enabled = assignedMinigameId ~= nil
		end
	end)

	prompt.Triggered:Connect(function()
		openTaskPanel(prompt)
	end)
end

local function checkDescendant(obj)
	if not obj:IsA("BasePart") then return end
	local num = tonumber(obj.Name)
	if num and TASK_LABELS[num] then
		setupTaskPart(obj, num)
	end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	checkDescendant(obj)
end

Workspace.DescendantAdded:Connect(checkDescendant)

player:GetAttributeChangedSignal("PuzzleTaskDefinitionJson"):Connect(updatePuzzlePanel)
player:GetAttributeChangedSignal("TaskMinigameActive"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskGreenStart"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskGreenWidth"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskAttemptStartedAt"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskLastResult"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskFlashEvent"):Connect(triggerTimingFlash)
player:GetAttributeChangedSignal("TaskProgressSegments"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskTotalSegments"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskMarkerWidthScale"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("TaskSwingSpeed"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("SpamTaskActive"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("SpamTaskCurrentFill"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("SpamTaskCurrentStage"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("SpamTaskGoalStart"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("SpamTaskGoalWidth"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("SpamTaskLastResult"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("SpamTaskFlashEvent"):Connect(triggerSpamFlash)
player:GetAttributeChangedSignal("SpamTaskTotalStages"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("PuzzleTaskActive"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskCompletedStages"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskCurrentStage"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskLastResult"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskStageTargetCount"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskStageHitCount"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskActiveButtonId"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskButtonStartedAt"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskButtonEndsAt"):Connect(updateClickerPanel)
player:GetAttributeChangedSignal("PuzzleTaskFlashEvent"):Connect(triggerPuzzleFlash)
player:GetAttributeChangedSignal("CodeTaskDefinitionJson"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskActive"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskRevealCount"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskCompletedStages"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskLastResult"):Connect(updateCodePanel)
player:GetAttributeChangedSignal("CodeTaskFlashEvent"):Connect(triggerCodeFlash)
player:GetAttributeChangedSignal("SelectedTaskId"):Connect(function()
	if not panel.Visible then
		return
	end

	if updateTaskBodyVisibility() then
		pendingSelectedTaskId = nil
		updateTimingPanel()
		updateSpamPanel()
		updateClickerPanel()
		updateCodePanel()
	end
end)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updateTimingPanel)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updateSpamPanel)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updateClickerPanel)
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
	button.Size = UDim2.fromOffset(74, 34)
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

for buttonIndex = 1, CLICKER_BUTTON_COUNT do
	local button = Instance.new("TextButton")
	button.Name = string.format("ClickerButton%d", buttonIndex)
	button.Size = UDim2.fromOffset(22, 22)
	button.BackgroundColor3 = Color3.fromRGB(58, 66, 78)
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = clickerGrid

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Name = "Stroke"
	buttonStroke.Color = Color3.fromRGB(97, 112, 132)
	buttonStroke.Transparency = 0.15
	buttonStroke.Parent = button

	button.MouseButton1Click:Connect(function()
		if panel.Visible and getDisplayedMinigameId() == 3 and isActiveTaskSelectionReady() then
			taskEvent:FireServer("PuzzlePress", buttonIndex)
		end
	end)

	button.MouseEnter:Connect(function()
		hoveredClickerButtonId = buttonIndex
		updateClickerPanel()
	end)

	button.MouseLeave:Connect(function()
		if hoveredClickerButtonId == buttonIndex then
			hoveredClickerButtonId = 0
			updateClickerPanel()
		end
	end)

	clickerButtons[buttonIndex] = button
end

setCodeButtonsEnabled(false)

-- ── Auto-close when player walks out of range ───────────────────────
RunService.Heartbeat:Connect(function()
	if panel.Visible then
		updateTimingPanel()
		updateSpamPanel()
		updateClickerPanel()
	end

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