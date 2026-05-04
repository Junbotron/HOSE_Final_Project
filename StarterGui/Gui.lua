local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INVISIBILITY_DURATION = 3
local INVISIBILITY_COOLDOWN = 20
local SHOVE_COOLDOWN = 2
local BAR_RIGHT_OFFSET = -24
local BAR_BOTTOM_OFFSET = -24
local BAR_SPACING = 36

local function clamp(value, minValue, maxValue)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
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

local function styleBar(frame, fill, label, position)
	frame.AnchorPoint = Vector2.new(1, 1)
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

local function setFill(fill, ratio)
	fill.Size = UDim2.fromScale(clamp(ratio, 0, 1), 1)
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
	local fillAmount = 1

	if now < activeEndsAt then
		fillAmount = (activeEndsAt - now) / INVISIBILITY_DURATION
		invisFill.BackgroundColor3 = Color3.fromRGB(100, 190, 255)
		invisLabel.Text = string.format("Invisibility Q %.1fs", activeEndsAt - now)
	elseif now < cooldownEndsAt then
		fillAmount = 1 - ((cooldownEndsAt - now) / INVISIBILITY_COOLDOWN)
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

	local isSprinting = player:GetAttribute("IsSprinting")
	local isBurnedOut = player:GetAttribute("SprintBurnedOut")
	local isCrouching = player:GetAttribute("IsCrouching")

	if isCrouching then
		staminaFill.BackgroundColor3 = Color3.fromRGB(130, 150, 175)
		staminaLabel.Text = "Crouching C"
	elseif isSprinting then
		staminaFill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
		staminaLabel.Text = string.format("Sprint Shift %.1fs", sprintEnergy * 3)
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
	local canShoveInRange = player:GetAttribute("CanShoveInRange")
	local isHoveringShoveTarget = player:GetAttribute("IsHoveringShoveTarget")
	local isOnCooldown = now < cooldownEndsAt
	local fillAmount = 1

	if isOnCooldown then
		fillAmount = 1 - ((cooldownEndsAt - now) / SHOVE_COOLDOWN)
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
	elseif canShoveInRange == false then
		shoveFill.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
		if isOnCooldown then
			shoveLabel.Text = string.format("Shove F %.1fs", cooldownEndsAt - now)
		else
			shoveLabel.Text = "Shove F Out of Range"
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
player:GetAttributeChangedSignal("CurrentRole"):Connect(updateRoleLabel)

RunService.RenderStepped:Connect(function()
	local now = tick()
	updateInvisibilityBar(now)
	updateStaminaBar()
	updateShoveBar(now)
end)