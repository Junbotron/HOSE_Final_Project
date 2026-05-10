local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local movementInputEvent = ReplicatedStorage:WaitForChild("MovementInputEvent")

local SPRINT_KEY = Enum.KeyCode.LeftShift
local CROUCH_KEY = Enum.KeyCode.C
local CROUCH_ANIMATION_ID = "rbxassetid://78278415495111"
local SLIDE_ANIMATION_ID = "rbxassetid://128196899539056"

local sprintHeld = false
local crouchHeld = false
local lastIsSliding = false
local crouchAnimation = Instance.new("Animation")
local slideAnimation = Instance.new("Animation")
local crouchTrack = nil
local slideTrack = nil

crouchAnimation.AnimationId = CROUCH_ANIMATION_ID
slideAnimation.AnimationId = SLIDE_ANIMATION_ID

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getAnimator(humanoid)
	return humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
end

local function stopCrouchAnimation()
	if crouchTrack then
		crouchTrack:Stop(0.15)
	end
end

local function stopSlideAnimation()
	if slideTrack then
		slideTrack:Stop(0.1)
	end
end

local function ensureCrouchTrack(humanoid)
	if crouchTrack then
		return crouchTrack
	end

	local animator = getAnimator(humanoid)
	crouchTrack = animator:LoadAnimation(crouchAnimation)
	crouchTrack.Priority = Enum.AnimationPriority.Movement
	crouchTrack.Looped = true
	return crouchTrack
end

local function ensureSlideTrack(humanoid)
	if slideTrack then
		return slideTrack
	end

	local animator = getAnimator(humanoid)
	slideTrack = animator:LoadAnimation(slideAnimation)
	slideTrack.Priority = Enum.AnimationPriority.Action
	slideTrack.Looped = false
	return slideTrack
end

local function resetAnimationState()
	stopCrouchAnimation()
	stopSlideAnimation()
	crouchTrack = nil
	slideTrack = nil
	lastIsSliding = false
end

local function playSlideAnimation(humanoid)
	if not humanoid then
		return
	end

	local track = ensureSlideTrack(humanoid)
	stopCrouchAnimation()
	track:Stop(0)
	track.TimePosition = 0
	track:Play(0.05)
end

local function updateAnimationState()
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		resetAnimationState()
		return
	end

	local isSliding = player:GetAttribute("IsSliding") == true
	local isCrouching = player:GetAttribute("IsCrouching") == true

	if isSliding and not lastIsSliding then
		playSlideAnimation(humanoid)
	elseif not isSliding and lastIsSliding then
		stopSlideAnimation()
	end

	if isSliding then
		stopCrouchAnimation()
	elseif isCrouching then
		local track = ensureCrouchTrack(humanoid)
		if not track.IsPlaying then
			track:Play(0.15)
		end
	else
		stopCrouchAnimation()
	end

	lastIsSliding = isSliding
end

local function initializeCharacter(character)
	sprintHeld = false
	crouchHeld = false
	resetAnimationState()
	character:WaitForChild("Humanoid")
	movementInputEvent:FireServer("Sprint", false)
	movementInputEvent:FireServer("Crouch", false)
	updateAnimationState()
end

player.CharacterAdded:Connect(initializeCharacter)

if player.Character then
	initializeCharacter(player.Character)
else
	updateAnimationState()
end

player:GetAttributeChangedSignal("IsCrouching"):Connect(updateAnimationState)
player:GetAttributeChangedSignal("IsSliding"):Connect(updateAnimationState)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == SPRINT_KEY and not sprintHeld then
		sprintHeld = true
		movementInputEvent:FireServer("Sprint", true)
	elseif input.KeyCode == CROUCH_KEY and not crouchHeld then
		crouchHeld = true
		movementInputEvent:FireServer("Crouch", true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == SPRINT_KEY and sprintHeld then
		sprintHeld = false
		movementInputEvent:FireServer("Sprint", false)
	elseif input.KeyCode == CROUCH_KEY and crouchHeld then
		crouchHeld = false
		movementInputEvent:FireServer("Crouch", false)
	end
end)