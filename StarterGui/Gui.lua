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
local DEFAULT_TASK_SEGMENTS = 3
local DEFAULT_MARKER_WIDTH_SCALE = 0.08
local DEFAULT_SWING_SPEED = 0.9
local TIMING_PANEL_HEIGHT = 112
local TIMING_TRACK_HEIGHT = 18

local function clamp(value, minValue, maxValue)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function getTaskTotalSegments()
	return math.max(1, player:GetAttribute("TaskTotalSegments") or DEFAULT_TASK_SEGMENTS)
end

local function getTaskProgressSegments()
	return math.floor(clamp(player:GetAttribute("TaskProgressSegments") or 0, 0, getTaskTotalSegments()))
end

local function getTaskMarkerWidthScale()
	return clamp(player:GetAttribute("TaskMarkerWidthScale") or DEFAULT_MARKER_WIDTH_SCALE, 0.01, 1)
end

local function getTaskSwingSpeed()
	return math.max(0, player:GetAttribute("TaskSwingSpeed") or DEFAULT_SWING_SPEED)
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

local function getTaskProgressRatio()
	return getTaskProgressSegments() / getTaskTotalSegments()
end

local function setFill(fill, ratio)
	fill.Size = UDim2.fromScale(clamp(ratio, 0, 1), 1)
end

local function updateTaskProgressBar()
	local taskSegmentsCompleted = getTaskProgressSegments()
	local taskTotalSegments = getTaskTotalSegments()
	local lastTaskResult = player:GetAttribute("TaskLastResult")
	local taskRatio = getTaskProgressRatio()

	if taskSegmentsCompleted >= taskTotalSegments then
		taskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		taskLabel.Text = "Task Progress Complete"
	elseif lastTaskResult == "Fail" then
		taskFill.BackgroundColor3 = Color3.fromRGB(201, 110, 110)
		taskLabel.Text = string.format("Task Progress %d/%d", taskSegmentsCompleted, taskTotalSegments)
	else
		taskFill.BackgroundColor3 = Color3.fromRGB(87, 184, 98)
		taskLabel.Text = string.format("Task Progress %d/%d", taskSegmentsCompleted, taskTotalSegments)
	end

	setFill(taskFill, taskRatio)
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

local function updateTimingMiniGame()
	local isActive = player:GetAttribute("TaskMinigameActive") == true
	timingPanel.Visible = isActive
	updateTimingHint(isActive)

	if not isActive then
		return
	end

	local greenStart = clamp(player:GetAttribute("TaskGreenStart") or 0, 0, 1)
	local greenWidth = clamp(player:GetAttribute("TaskGreenWidth") or 0.2, 0, 1)
	local markerWidthScale = getTaskMarkerWidthScale()
	local swingSpeed = getTaskSwingSpeed()
	local startedAt = player:GetAttribute("TaskAttemptStartedAt") or 0
	local elapsedTime = math.max(0, Workspace:GetServerTimeNow() - startedAt)
	local markerPosition = computeMarkerPosition(elapsedTime, markerWidthScale, swingSpeed)

	timingGreenZone.Position = UDim2.fromScale(greenStart, 0)
	timingGreenZone.Size = UDim2.fromScale(greenWidth, 1)
	timingMarker.Position = UDim2.fromScale(markerPosition, 0)
	timingMarker.Size = UDim2.fromScale(markerWidthScale, 1)
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
updateTimingMiniGame()
player:GetAttributeChangedSignal("CurrentRole"):Connect(updateRoleLabel)
player:GetAttributeChangedSignal("TaskProgressSegments"):Connect(updateTaskProgressBar)
player:GetAttributeChangedSignal("TaskTotalSegments"):Connect(updateTaskProgressBar)
player:GetAttributeChangedSignal("TaskLastResult"):Connect(updateTaskProgressBar)
player:GetAttributeChangedSignal("TaskMinigameActive"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("TaskGreenStart"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("TaskGreenWidth"):Connect(updateTimingMiniGame)
player:GetAttributeChangedSignal("TaskAttemptStartedAt"):Connect(updateTimingMiniGame)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		if player:GetAttribute("TaskMinigameActive") == true then
			taskEvent:FireServer("Resolve")
		else
			taskEvent:FireServer("Start")
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local now = tick()
	updateInvisibilityBar(now)
	updateStaminaBar()
	updateShoveBar(now)
	updateTimingMiniGame()
end)