local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local taskEvent = ReplicatedStorage:WaitForChild("TaskMinigameEvent")

local BAR_RIGHT_OFFSET = -24
local BAR_TOP_OFFSET = 24
local BAR_BOTTOM_OFFSET = -24
local BAR_SPACING = 36
local TIMING_PANEL_HEIGHT = 112
local TIMING_TRACK_HEIGHT = 18
local SPAM_PANEL_HEIGHT = 118

local function clamp(value, minValue, maxValue)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function getTaskTotalSegments()
	return math.max(1, player:GetAttribute("TaskTotalSegments") or 1)
end

local function getTimingTasksTotalCount()
	return math.max(1, player:GetAttribute("TimingTasksTotalCount") or 1)
end

local function getTimingTasksCompletedCount()
	return math.floor(clamp(player:GetAttribute("TimingTasksCompletedCount") or 0, 0, getTimingTasksTotalCount()))
end

local function getTaskProgressSegments()
	return math.floor(clamp(player:GetAttribute("TaskProgressSegments") or 0, 0, getTaskTotalSegments()))
end

local function getTaskMarkerWidthScale()
	return clamp(player:GetAttribute("TaskMarkerWidthScale") or 0.01, 0.01, 1)
end

local function getTaskSwingSpeed()
	return math.max(0, player:GetAttribute("TaskSwingSpeed") or 0)
end

local function getSpamTaskTotalStages()
	return math.max(1, player:GetAttribute("SpamTaskTotalStages") or 1)
end

local function getSpamTasksTotalCount()
	return math.max(1, player:GetAttribute("SpamTasksTotalCount") or 1)
end

local function getSpamTasksCompletedCount()
	return math.floor(clamp(player:GetAttribute("SpamTasksCompletedCount") or 0, 0, getSpamTasksTotalCount()))
end

local function getSpamTaskCompletedStages()
	return math.floor(clamp(player:GetAttribute("SpamTaskCompletedStages") or 0, 0, getSpamTaskTotalStages()))
end

local function getPuzzleTaskTotalStages()
	return math.max(1, player:GetAttribute("PuzzleTaskTotalStages") or 1)
end

local function getPuzzleTasksTotalCount()
	return math.max(1, player:GetAttribute("PuzzleTasksTotalCount") or 1)
end

local function getPuzzleTasksCompletedCount()
	return math.floor(clamp(player:GetAttribute("PuzzleTasksCompletedCount") or 0, 0, getPuzzleTasksTotalCount()))
end

local function getPuzzleTaskCompletedStages()
	return math.floor(clamp(player:GetAttribute("PuzzleTaskCompletedStages") or 0, 0, getPuzzleTaskTotalStages()))
end

local function getCodeTaskTotalStages()
	return math.max(1, player:GetAttribute("CodeTaskTotalStages") or 1)
end

local function getCodeTasksTotalCount()
	return math.max(1, player:GetAttribute("CodeTasksTotalCount") or 1)
end

local function getCodeTasksCompletedCount()
	return math.floor(clamp(player:GetAttribute("CodeTasksCompletedCount") or 0, 0, getCodeTasksTotalCount()))
end

local function getCodeTaskCompletedStages()
	return math.floor(clamp(player:GetAttribute("CodeTaskCompletedStages") or 0, 0, getCodeTaskTotalStages()))
end

local function ensureInstance(parent, className, name)
	local instance = parent:FindFirstChild(name)
	if instance then
		return instance
	end

	instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function styleBar(frame, fill, label, position, anchorPoint)
	frame.AnchorPoint = anchorPoint or Vector2.new(1, 1)
	frame.Position = position
	frame.Size = UDim2.fromOffset(280, 28)
	frame.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
	frame.BorderSizePixel = 0

	local frameCorner = ensureInstance(frame, "UICorner", "Corner")
	frameCorner.CornerRadius = UDim.new(0, 10)

	fill.Position = UDim2.fromScale(0, 0)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0

	local fillCorner = ensureInstance(fill, "UICorner", "Corner")
	fillCorner.CornerRadius = UDim.new(0, 10)

	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.TextStrokeTransparency = 0.7
end

local roleGui = ensureInstance(playerGui, "ScreenGui", "RoleGui")
roleGui.ResetOnSpawn = false

local roleLabel = ensureInstance(roleGui, "TextLabel", "RoleLabel")
roleLabel.AnchorPoint = Vector2.new(0.5, 0)
roleLabel.Position = UDim2.fromScale(0.5, 0.06)
roleLabel.Size = UDim2.fromOffset(300, 46)
roleLabel.BackgroundTransparency = 1
roleLabel.Font = Enum.Font.GothamBlack
roleLabel.TextSize = 30
roleLabel.TextStrokeTransparency = 0.75

local invisGui = ensureInstance(playerGui, "ScreenGui", "InvisGui")
invisGui.ResetOnSpawn = false

local invisBar = ensureInstance(invisGui, "Frame", "InvisBar")
local invisFill = ensureInstance(invisBar, "Frame", "Fill")
local invisLabel = ensureInstance(invisBar, "TextLabel", "TextLabel")
styleBar(invisBar, invisFill, invisLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 1, BAR_BOTTOM_OFFSET - (BAR_SPACING * 2)))

local staminaGui = ensureInstance(playerGui, "ScreenGui", "StaminaGui")
staminaGui.ResetOnSpawn = false

local staminaBar = ensureInstance(staminaGui, "Frame", "StaminaBar")
local staminaFill = ensureInstance(staminaBar, "Frame", "Fill")
local staminaLabel = ensureInstance(staminaBar, "TextLabel", "TextLabel")
styleBar(staminaBar, staminaFill, staminaLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 1, BAR_BOTTOM_OFFSET - BAR_SPACING))

local shoveGui = ensureInstance(playerGui, "ScreenGui", "ShoveGui")
shoveGui.ResetOnSpawn = false

local shoveBar = ensureInstance(shoveGui, "Frame", "ShoveBar")
local shoveFill = ensureInstance(shoveBar, "Frame", "Fill")
local shoveLabel = ensureInstance(shoveBar, "TextLabel", "TextLabel")
styleBar(shoveBar, shoveFill, shoveLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 1, BAR_BOTTOM_OFFSET))

local taskGui = ensureInstance(playerGui, "ScreenGui", "TaskGui")
taskGui.ResetOnSpawn = false

local taskBar = ensureInstance(taskGui, "Frame", "TaskBar")
local taskFill = ensureInstance(taskBar, "Frame", "Fill")
local taskLabel = ensureInstance(taskBar, "TextLabel", "TextLabel")
styleBar(taskBar, taskFill, taskLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 0, BAR_TOP_OFFSET), Vector2.new(1, 0))

local spamTaskGui = ensureInstance(playerGui, "ScreenGui", "SpamTaskGui")
spamTaskGui.ResetOnSpawn = false

local spamTaskBar = ensureInstance(spamTaskGui, "Frame", "SpamTaskBar")
local spamTaskFill = ensureInstance(spamTaskBar, "Frame", "Fill")
local spamTaskLabel = ensureInstance(spamTaskBar, "TextLabel", "TextLabel")
styleBar(spamTaskBar, spamTaskFill, spamTaskLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 0, BAR_TOP_OFFSET + BAR_SPACING), Vector2.new(1, 0))

local puzzleTaskGui = ensureInstance(playerGui, "ScreenGui", "PuzzleTaskGui")
puzzleTaskGui.ResetOnSpawn = false

local puzzleTaskBar = ensureInstance(puzzleTaskGui, "Frame", "PuzzleTaskBar")
local puzzleTaskFill = ensureInstance(puzzleTaskBar, "Frame", "Fill")
local puzzleTaskLabel = ensureInstance(puzzleTaskBar, "TextLabel", "TextLabel")
styleBar(puzzleTaskBar, puzzleTaskFill, puzzleTaskLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 0, BAR_TOP_OFFSET + (BAR_SPACING * 2)), Vector2.new(1, 0))

local codeTaskGui = ensureInstance(playerGui, "ScreenGui", "CodeTaskGui")
codeTaskGui.ResetOnSpawn = false

local codeTaskBar = ensureInstance(codeTaskGui, "Frame", "CodeTaskBar")
local codeTaskFill = ensureInstance(codeTaskBar, "Frame", "Fill")
local codeTaskLabel = ensureInstance(codeTaskBar, "TextLabel", "TextLabel")
styleBar(codeTaskBar, codeTaskFill, codeTaskLabel, UDim2.new(1, BAR_RIGHT_OFFSET, 0, BAR_TOP_OFFSET + (BAR_SPACING * 3)), Vector2.new(1, 0))

local taskTimingGui = ensureInstance(playerGui, "ScreenGui", "TaskTimingGui")
taskTimingGui.ResetOnSpawn = false

local timingPanel = ensureInstance(taskTimingGui, "Frame", "TimingPanel")
timingPanel.AnchorPoint = Vector2.new(0.5, 1)
timingPanel.Position = UDim2.new(0.5, 0, 1, -42)
timingPanel.Size = UDim2.fromOffset(520, TIMING_PANEL_HEIGHT)
timingPanel.BackgroundColor3 = Color3.fromRGB(19, 24, 30)
timingPanel.BackgroundTransparency = 0.05
timingPanel.BorderSizePixel = 0
timingPanel.Visible = false

local timingPanelCorner = ensureInstance(timingPanel, "UICorner", "Corner")
timingPanelCorner.CornerRadius = UDim.new(0, 14)

local timingPanelStroke = ensureInstance(timingPanel, "UIStroke", "Stroke")
timingPanelStroke.Color = Color3.fromRGB(90, 173, 110)
timingPanelStroke.Transparency = 0.15

local timingTitle = ensureInstance(timingPanel, "TextLabel", "Title")
timingTitle.BackgroundTransparency = 1
timingTitle.Position = UDim2.fromOffset(18, 12)
timingTitle.Size = UDim2.new(1, -36, 0, 28)
timingTitle.Font = Enum.Font.GothamBold
timingTitle.TextColor3 = Color3.fromRGB(239, 244, 246)
timingTitle.TextSize = 18
timingTitle.TextXAlignment = Enum.TextXAlignment.Left
timingTitle.Text = "Timing Task"

local timingHint = ensureInstance(timingPanel, "TextLabel", "Hint")
timingHint.BackgroundTransparency = 1
timingHint.Position = UDim2.fromOffset(18, 38)
timingHint.Size = UDim2.new(1, -36, 0, 22)
timingHint.Font = Enum.Font.Gotham
timingHint.TextColor3 = Color3.fromRGB(180, 188, 194)
timingHint.TextSize = 13
timingHint.TextXAlignment = Enum.TextXAlignment.Left
timingHint.Text = "Press R to start"

local timingTrack = ensureInstance(timingPanel, "Frame", "Track")
timingTrack.Position = UDim2.fromOffset(18, 74)
timingTrack.Size = UDim2.new(1, -36, 0, TIMING_TRACK_HEIGHT)
timingTrack.BackgroundColor3 = Color3.fromRGB(146, 57, 57)
timingTrack.BorderSizePixel = 0

local timingTrackCorner = ensureInstance(timingTrack, "UICorner", "Corner")
timingTrackCorner.CornerRadius = UDim.new(1, 0)

local timingGreenZone = ensureInstance(timingTrack, "Frame", "GreenZone")
timingGreenZone.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
timingGreenZone.BorderSizePixel = 0

local timingGreenCorner = ensureInstance(timingGreenZone, "UICorner", "Corner")
timingGreenCorner.CornerRadius = UDim.new(1, 0)

local timingMarker = ensureInstance(timingTrack, "Frame", "Marker")
timingMarker.BackgroundColor3 = Color3.fromRGB(180, 186, 194)
timingMarker.BorderSizePixel = 0

local timingMarkerCorner = ensureInstance(timingMarker, "UICorner", "Corner")
timingMarkerCorner.CornerRadius = UDim.new(1, 0)

local timingMarkerStroke = ensureInstance(timingMarker, "UIStroke", "Stroke")
timingMarkerStroke.Color = Color3.fromRGB(30, 34, 40)
timingMarkerStroke.Thickness = 2

local spamTimingGui = ensureInstance(playerGui, "ScreenGui", "SpamTimingGui")
spamTimingGui.ResetOnSpawn = false

local spamPanel = ensureInstance(spamTimingGui, "Frame", "SpamPanel")
spamPanel.AnchorPoint = Vector2.new(0.5, 1)
spamPanel.Position = UDim2.new(0.5, 0, 1, -42)
spamPanel.Size = UDim2.fromOffset(520, SPAM_PANEL_HEIGHT)
spamPanel.BackgroundColor3 = Color3.fromRGB(19, 24, 30)
spamPanel.BackgroundTransparency = 0.05
spamPanel.BorderSizePixel = 0
spamPanel.Visible = false

local spamPanelCorner = ensureInstance(spamPanel, "UICorner", "Corner")
spamPanelCorner.CornerRadius = UDim.new(0, 14)

local spamPanelStroke = ensureInstance(spamPanel, "UIStroke", "Stroke")
spamPanelStroke.Color = Color3.fromRGB(87, 184, 98)
spamPanelStroke.Transparency = 0.15

local spamTitle = ensureInstance(spamPanel, "TextLabel", "Title")
spamTitle.BackgroundTransparency = 1
spamTitle.Position = UDim2.fromOffset(18, 12)
spamTitle.Size = UDim2.new(1, -36, 0, 28)
spamTitle.Font = Enum.Font.GothamBold
spamTitle.TextColor3 = Color3.fromRGB(239, 244, 246)
spamTitle.TextSize = 18
spamTitle.TextXAlignment = Enum.TextXAlignment.Left
spamTitle.Text = "Spam Task"

local spamHint = ensureInstance(spamPanel, "TextLabel", "Hint")
spamHint.BackgroundTransparency = 1
spamHint.Position = UDim2.fromOffset(18, 38)
spamHint.Size = UDim2.new(1, -36, 0, 22)
spamHint.Font = Enum.Font.Gotham
spamHint.TextColor3 = Color3.fromRGB(180, 188, 194)
spamHint.TextSize = 13
spamHint.TextXAlignment = Enum.TextXAlignment.Left
spamHint.Text = "Press T to start"

local spamTrack = ensureInstance(spamPanel, "Frame", "Track")
spamTrack.Position = UDim2.fromOffset(18, 74)
spamTrack.Size = UDim2.new(1, -36, 0, TIMING_TRACK_HEIGHT)
spamTrack.BackgroundColor3 = Color3.fromRGB(56, 61, 69)
spamTrack.BorderSizePixel = 0

local spamTrackCorner = ensureInstance(spamTrack, "UICorner", "Corner")
spamTrackCorner.CornerRadius = UDim.new(1, 0)

local spamGoalZone = ensureInstance(spamTrack, "Frame", "GoalZone")
spamGoalZone.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
spamGoalZone.BorderSizePixel = 0

local spamGoalCorner = ensureInstance(spamGoalZone, "UICorner", "Corner")
spamGoalCorner.CornerRadius = UDim.new(1, 0)

local spamFillTrack = ensureInstance(spamTrack, "Frame", "FillTrack")
spamFillTrack.BackgroundColor3 = Color3.fromRGB(196, 201, 208)
spamFillTrack.BorderSizePixel = 0

local spamFillCorner = ensureInstance(spamFillTrack, "UICorner", "Corner")
spamFillCorner.CornerRadius = UDim.new(1, 0)

local function getTaskProgressRatio()
	return getTimingTasksCompletedCount() / getTimingTasksTotalCount()
end

local function getSpamTaskProgressRatio()
	return getSpamTasksCompletedCount() / getSpamTasksTotalCount()
end

local function getPuzzleTaskProgressRatio()
	return getPuzzleTasksCompletedCount() / getPuzzleTasksTotalCount()
end

local function getCodeTaskProgressRatio()
	return getCodeTasksCompletedCount() / getCodeTasksTotalCount()
end

local function setFill(fill, ratio)
	fill.Size = UDim2.fromScale(clamp(ratio, 0, 1), 1)
end

local function updateTaskProgressBar()
	local completedTaskCount = getTimingTasksCompletedCount()
	local totalTaskCount = getTimingTasksTotalCount()
	local taskRatio = getTaskProgressRatio()

	if completedTaskCount >= totalTaskCount then
		taskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		taskLabel.Text = "Timing Tasks Complete"
	else
		taskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		taskLabel.Text = string.format("Timing Tasks %d/%d", completedTaskCount, totalTaskCount)
	end

	setFill(taskFill, taskRatio)
end

local function updateSpamTaskProgressBar()
	local completedTaskCount = getSpamTasksCompletedCount()
	local totalTaskCount = getSpamTasksTotalCount()

	if completedTaskCount >= totalTaskCount then
		spamTaskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		spamTaskLabel.Text = "Spam Tasks Complete"
	else
		spamTaskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		spamTaskLabel.Text = string.format("Spam Tasks %d/%d", completedTaskCount, totalTaskCount)
	end

	setFill(spamTaskFill, getSpamTaskProgressRatio())
end

local function updatePuzzleTaskProgressBar()
	local completedTaskCount = getPuzzleTasksCompletedCount()
	local totalTaskCount = getPuzzleTasksTotalCount()

	if completedTaskCount >= totalTaskCount then
		puzzleTaskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		puzzleTaskLabel.Text = "Clicker Tasks Complete"
	else
		puzzleTaskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		puzzleTaskLabel.Text = string.format("Clicker Tasks %d/%d", completedTaskCount, totalTaskCount)
	end

	setFill(puzzleTaskFill, getPuzzleTaskProgressRatio())
end

local function updateCodeTaskProgressBar()
	local completedTaskCount = getCodeTasksCompletedCount()
	local totalTaskCount = getCodeTasksTotalCount()

	if completedTaskCount >= totalTaskCount then
		codeTaskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		codeTaskLabel.Text = "Override Tasks Complete"
	else
		codeTaskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		codeTaskLabel.Text = string.format("Override Tasks %d/%d", completedTaskCount, totalTaskCount)
	end

	setFill(codeTaskFill, getCodeTaskProgressRatio())
end

local function computeMarkerPosition(elapsedTime, markerWidthScale, swingSpeed)
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

local function updateTimingHint(isActive)
	local lastTaskResult = player:GetAttribute("TaskLastResult")

	if isActive then
		timingHint.Text = "Press R to stop fully inside green"
	elseif lastTaskResult == "Success" then
		timingHint.Text = "Success. Press R for next task"
	elseif lastTaskResult == "Fail" then
		timingHint.Text = "Missed. Press R to try again"
	else
		timingHint.Text = "Press R to start"
	end
end

local function updateSpamHint(isActive)
	local lastResult = player:GetAttribute("SpamTaskLastResult")
	local currentStage = math.min(player:GetAttribute("SpamTaskCurrentStage") or 1, getSpamTaskTotalStages())

	if isActive then
		spamHint.Text = string.format("Stage %d/%d  Spam T rapidly", currentStage, getSpamTaskTotalStages())
	elseif lastResult == "Success" then
		spamHint.Text = "Spam task complete"
	elseif lastResult == "StageClear" then
		spamHint.Text = string.format("Stage cleared. Press T for stage %d", currentStage)
	else
		spamHint.Text = "Press T to start"
	end
end

local function updateTimingMiniGame()
	timingPanel.Visible = false
end

local function updateSpamMiniGame()
	spamPanel.Visible = false
end

local function updateRoleLabel()
	local role = player:GetAttribute("CurrentRole")
	if role == "Tagger" then 
		roleLabel.Text = "YOU'RE IT!!!"
		roleLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
	elseif role == "Survivor" then
		roleLabel.Text = "Survivor"
		roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		roleLabel.Text = "Waiting..."
		roleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function updateInvisibilityBar(now)
	local activeEndsAt = player:GetAttribute("InvisibilityActiveEndsAt") or 0
	local cooldownEndsAt = player:GetAttribute("InvisibilityCooldownEndsAt") or 0
	local fillAmount = player:GetAttribute("InvisibilityBarRatio")
	if fillAmount == nil then
		fillAmount = 1
	end

	if now < activeEndsAt then
		invisFill.BackgroundColor3 = Color3.fromRGB(100, 190, 255)
		invisLabel.Text = string.format("Invisibility Q %.1fs", activeEndsAt - now)
	elseif now < cooldownEndsAt then
		invisFill.BackgroundColor3 = Color3.fromRGB(70, 95, 120)
		invisLabel.Text = string.format("Invisibility Cooldown %.1fs", cooldownEndsAt - now)
	else
		invisFill.BackgroundColor3 = Color3.fromRGB(94, 193, 255)
		invisLabel.Text = "Invisibility Q"
	end

	setFill(invisFill, fillAmount)
end

local function updateStaminaBar()
	local sprintEnergy = player:GetAttribute("SprintEnergy")
	if sprintEnergy == nil then
		sprintEnergy = 1
	end

	local sprintEnergyPercent = player:GetAttribute("SprintEnergyPercent")
	if sprintEnergyPercent == nil then
		sprintEnergyPercent = math.floor((sprintEnergy * 100) + 0.5)
	end

	local isSprinting = player:GetAttribute("IsSprinting")
	local isBurnedOut = player:GetAttribute("SprintBurnedOut")
	local isCrouching = player:GetAttribute("IsCrouching")
	local isSliding = player:GetAttribute("IsSliding")

	if isSliding then
		staminaFill.BackgroundColor3 = Color3.fromRGB(160, 175, 210)
		staminaLabel.Text = "Sliding C"
	elseif isCrouching then
		staminaFill.BackgroundColor3 = Color3.fromRGB(130, 150, 175)
		staminaLabel.Text = "Crouching C"
	elseif isSprinting then
		staminaFill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
		staminaLabel.Text = string.format("Sprint Shift %d%%", sprintEnergyPercent)
	elseif sprintEnergy < 1 then
		if isBurnedOut then
			staminaFill.BackgroundColor3 = Color3.fromRGB(180, 88, 88)
			staminaLabel.Text = "Sprint Recovering"
		else
			staminaFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
			staminaLabel.Text = "Sprint Recharging"
		end
	else
		staminaFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
		staminaLabel.Text = "Sprint Shift"
	end

	setFill(staminaFill, sprintEnergy)
end

local function updateShoveBar(now)
	local cooldownEndsAt = player:GetAttribute("ShoveCooldownEndsAt") or 0
	local canShoveAtAll = player:GetAttribute("CanShoveAtAll")
	local isHoveringShoveTarget = player:GetAttribute("IsHoveringShoveTarget")
	local isOnCooldown = now < cooldownEndsAt
	local fillAmount = player:GetAttribute("ShoveBarRatio")
	if fillAmount == nil then
		fillAmount = isOnCooldown and 0 or 1
	end

	setFill(shoveFill, fillAmount)

	if canShoveAtAll == false then
		shoveFill.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
		shoveLabel.Text = "Shove F Disabled"
	elseif not isHoveringShoveTarget then
		shoveFill.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
		if isOnCooldown then
			shoveLabel.Text = string.format("Shove F %.1fs", cooldownEndsAt - now)
		else
			shoveLabel.Text = "Shove F No Target"
		end
	elseif isOnCooldown then
		shoveFill.BackgroundColor3 = Color3.fromRGB(255, 155, 90)
		shoveLabel.Text = string.format("Shove F %.1fs", cooldownEndsAt - now)
	else
		shoveFill.BackgroundColor3 = Color3.fromRGB(255, 155, 90)
		shoveLabel.Text = "Shove F"
	end
end

updateRoleLabel()
updateTaskProgressBar()
updateSpamTaskProgressBar()
updatePuzzleTaskProgressBar()
updateCodeTaskProgressBar()
updateTimingMiniGame()
updateSpamMiniGame()
player:GetAttributeChangedSignal("CurrentRole"):Connect(updateRoleLabel)
player:GetAttributeChangedSignal("TimingTasksCompletedCount"):Connect(updateTaskProgressBar)
player:GetAttributeChangedSignal("TimingTasksTotalCount"):Connect(updateTaskProgressBar)
player:GetAttributeChangedSignal("TaskMinigameActive"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("TaskGreenStart"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("TaskGreenWidth"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("TaskAttemptStartedAt"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("SpamTasksCompletedCount"):Connect(updateSpamTaskProgressBar)
player:GetAttributeChangedSignal("SpamTasksTotalCount"):Connect(updateSpamTaskProgressBar)
player:GetAttributeChangedSignal("PuzzleTasksCompletedCount"):Connect(updatePuzzleTaskProgressBar)
player:GetAttributeChangedSignal("PuzzleTasksTotalCount"):Connect(updatePuzzleTaskProgressBar)
player:GetAttributeChangedSignal("CodeTasksCompletedCount"):Connect(updateCodeTaskProgressBar)
player:GetAttributeChangedSignal("CodeTasksTotalCount"):Connect(updateCodeTaskProgressBar)
player:GetAttributeChangedSignal("SpamTaskActive"):Connect(updateSpamMiniGame)
player:GetAttributeChangedSignal("ActiveMinigameId"):Connect(updateSpamMiniGame)
player:GetAttributeChangedSignal("SpamTaskCurrentFill"):Connect(updateSpamMiniGame)
player:GetAttributeChangedSignal("SpamTaskCurrentStage"):Connect(updateSpamMiniGame)
player:GetAttributeChangedSignal("SpamTaskGoalStart"):Connect(updateSpamMiniGame)
player:GetAttributeChangedSignal("SpamTaskGoalWidth"):Connect(updateSpamMiniGame)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.T then
		if player:GetAttribute("ActiveMinigameId") ~= 2 then return end
		if player:GetAttribute("SpamTaskActive") == true then
			taskEvent:FireServer("SpamTap")
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		if player:GetAttribute("ActiveMinigameId") ~= 1 then return end
		if player:GetAttribute("TaskMinigameActive") == true then
			taskEvent:FireServer("Resolve")
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local now = tick()
	updateInvisibilityBar(now)
	updateStaminaBar()
	updateShoveBar(now)
	updateTimingMiniGame()
	updateSpamMiniGame()
end)