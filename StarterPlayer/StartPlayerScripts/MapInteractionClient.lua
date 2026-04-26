local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local activePrompt = nil
local holdStartedAt = 0
local gui
local fillBar
local titleLabel

local function createLoadingGui()
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MapInteractionGui"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "LoaderFrame"
	frame.Size = UDim2.fromOffset(260, 72)
	frame.Position = UDim2.new(0.5, -130, 0.82, 0)
	frame.BackgroundColor3 = Color3.fromRGB(19, 24, 30)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(83, 157, 194)
	stroke.Transparency = 0.2
	stroke.Parent = frame

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -24, 0, 22)
	titleLabel.Position = UDim2.fromOffset(12, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = Color3.fromRGB(228, 235, 239)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -24, 0, 14)
	track.Position = UDim2.fromOffset(12, 42)
	track.BackgroundColor3 = Color3.fromRGB(45, 54, 64)
	track.BorderSizePixel = 0
	track.Parent = frame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	fillBar = Instance.new("Frame")
	fillBar.Name = "Fill"
	fillBar.Size = UDim2.fromScale(0, 1)
	fillBar.BackgroundColor3 = Color3.fromRGB(83, 157, 194)
	fillBar.BorderSizePixel = 0
	fillBar.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fillBar

	return gui
end

local function setLoaderVisible(visible)
	createLoadingGui()
	gui.LoaderFrame.Visible = visible
	if not visible then
		fillBar.Size = UDim2.fromScale(0, 1)
	end
end

local function shouldUseLoadingGui(prompt)
	return prompt and prompt:GetAttribute("UseLoadingGui") == true and prompt.HoldDuration > 0
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if not shouldUseLoadingGui(prompt) then
		return
	end

	activePrompt = prompt
	holdStartedAt = tick()
	createLoadingGui()
	titleLabel.Text = string.upper(prompt:GetAttribute("LoaderText") or prompt.ActionText or "INTERACTING")
	setLoaderVisible(true)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt ~= activePrompt then
		return
	end

	activePrompt = nil
	setLoaderVisible(false)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt ~= activePrompt then
		return
	end

	activePrompt = nil
	setLoaderVisible(false)
end)

RunService.RenderStepped:Connect(function()
	if not activePrompt or not gui or not gui.LoaderFrame.Visible then
		return
	end

	local duration = activePrompt.HoldDuration
	if duration <= 0 then
		fillBar.Size = UDim2.fromScale(1, 1)
		return
	end

	local alpha = math.clamp((tick() - holdStartedAt) / duration, 0, 1)
	fillBar.Size = UDim2.fromScale(alpha, 1)
	if alpha >= 1 then
		activePrompt = nil
		setLoaderVisible(false)
	end
end)