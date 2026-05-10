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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local taskEvent = ReplicatedStorage:WaitForChild("TaskMinigameEvent")

local PROXIMITY_DIST = 10

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
panel.Size = UDim2.fromOffset(400, 170)
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

local function openTaskPanel(prompt)
	local taskNum = prompt:GetAttribute("TaskNumber")
	local config = TASK_CONFIG[taskNum]
	if not config then return end

	activePart   = prompt.Parent
	activePrompt = prompt
	prompt.Enabled = false
	player:SetAttribute("ActiveTaskId", taskNum)
	player:SetAttribute("ActiveMinigameId", config.minigame)

	taskNameLabel.Text = config.label
	-- minigame 1 (timing) and 2 (spam) use their own panels; hide placeholder for those
	local isPlaceholder = config.minigame >= 3
	placeholderBar.Visible = isPlaceholder
	if isPlaceholder then
		minigameLabel.Text = string.format("[ Minigame %d  —  Placeholder ]", config.minigame)
	end
	panel.Visible = true
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
	player:SetAttribute("ActiveTaskId", nil)
	player:SetAttribute("ActiveMinigameId", nil)
	activePart = nil
	if activePrompt then
		activePrompt.Enabled = true
		activePrompt = nil
	end
end

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
