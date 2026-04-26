local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local SPRINT_KEY = Enum.KeyCode.LeftShift
local CROUCH_KEY = Enum.KeyCode.C
local MAX_SPRINT_DURATION = 3
local NORMAL_RECOVERY_DURATION = 5
local EXHAUSTED_RECOVERY_DURATION = 10
local SPRINT_SPEED_MULTIPLIER = 1.5
local CROUCH_SPEED_MULTIPLIER = 0.55
local CROUCH_ANIMATION_ID = "rbxassetid://78278415495111"
local crouchStateEvent = ReplicatedStorage:WaitForChild("CrouchStateEvent")

local sprintHeld = false
local sprintEnergy = 1
local sprintBurnedOut = false
local isCrouching = false
local lastSentCrouchState = nil
local baseWalkSpeed = 16
local crouchAnimation = Instance.new("Animation")
local crouchTrack = nil

crouchAnimation.AnimationId = CROUCH_ANIMATION_ID

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function stopCrouchAnimation()
	if crouchTrack then
		crouchTrack:Stop(0.15)
	end
end

local function updateCrouchAnimation(humanoid)
	if not humanoid then
		stopCrouchAnimation()
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
	if not crouchTrack then
		crouchTrack = animator:LoadAnimation(crouchAnimation)
		crouchTrack.Priority = Enum.AnimationPriority.Movement
		crouchTrack.Looped = true
	end

	if isCrouching then
		if not crouchTrack.IsPlaying then
			crouchTrack:Play(0.15)
		end
	else
		stopCrouchAnimation()
	end
end

local function syncAttributes(isSprinting)
	player:SetAttribute("SprintEnergy", sprintEnergy)
	player:SetAttribute("SprintBurnedOut", sprintBurnedOut)
	player:SetAttribute("IsSprinting", isSprinting)
	player:SetAttribute("IsCrouching", isCrouching)
end

local function syncCrouchStateToServer()
	if lastSentCrouchState == isCrouching then
		return
	end

	lastSentCrouchState = isCrouching
	crouchStateEvent:FireServer(isCrouching)
end

local function updateWalkSpeed(humanoid, isSprinting)
	if not humanoid then return end

	if isCrouching then
		humanoid.WalkSpeed = baseWalkSpeed * CROUCH_SPEED_MULTIPLIER
	elseif isSprinting then
		humanoid.WalkSpeed = baseWalkSpeed * SPRINT_SPEED_MULTIPLIER
	else
		humanoid.WalkSpeed = baseWalkSpeed
	end
end

local function initializeCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	baseWalkSpeed = humanoid.WalkSpeed
	isCrouching = false
	sprintHeld = false
	lastSentCrouchState = nil
	crouchTrack = nil
	updateWalkSpeed(humanoid, false)
	updateCrouchAnimation(humanoid)
	syncAttributes(false)
	syncCrouchStateToServer()
end

player.CharacterAdded:Connect(initializeCharacter)

if player.Character then
	initializeCharacter(player.Character)
else
	syncAttributes(false)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == SPRINT_KEY then
		sprintHeld = true
	elseif input.KeyCode == CROUCH_KEY then
		isCrouching = true
		syncCrouchStateToServer()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == SPRINT_KEY then
		sprintHeld = false
	elseif input.KeyCode == CROUCH_KEY then
		isCrouching = false
		syncCrouchStateToServer()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		stopCrouchAnimation()
		syncAttributes(false)
		return
	end

	if sprintBurnedOut and sprintEnergy >= 1 then
		sprintBurnedOut = false
	end

	local canSprint = sprintHeld and not isCrouching and humanoid.MoveDirection.Magnitude > 0 and sprintEnergy > 0 and not sprintBurnedOut

	if canSprint then
		sprintEnergy = math.max(0, sprintEnergy - (deltaTime / MAX_SPRINT_DURATION))
		if sprintEnergy <= 0 then
			sprintEnergy = 0
			sprintBurnedOut = true
			canSprint = false
		end
	else
		local recoveryDuration = sprintBurnedOut and EXHAUSTED_RECOVERY_DURATION or NORMAL_RECOVERY_DURATION
		if sprintEnergy < 1 then
			sprintEnergy = math.min(1, sprintEnergy + (deltaTime / recoveryDuration))
		end
	end

	updateWalkSpeed(humanoid, canSprint)
	updateCrouchAnimation(humanoid)
	syncAttributes(canSprint)
end)