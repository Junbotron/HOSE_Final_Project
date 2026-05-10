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
local JUMP_REDUCTION_MULTIPLIER = 0.9
local SLIDE_SPEED_MULTIPLIER = 2.1
local SLIDE_BURST_SPEED_MULTIPLIER = math.max(SLIDE_SPEED_MULTIPLIER + 0.5, SPRINT_SPEED_MULTIPLIER + 0.25)
local SLIDE_DURATION = 1.5
local SLIDE_BURST_DURATION = 0.18
local SLIDE_SPRINT_ENERGY_PENALTY = 0.5
local CROUCH_ANIMATION_ID = "rbxassetid://78278415495111"
local SLIDE_ANIMATION_ID = "rbxassetid://128196899539056"
local crouchStateEvent = ReplicatedStorage:WaitForChild("CrouchStateEvent")

local sprintHeld = false
local crouchHeld = false
local sprintEnergy = 1
local sprintBurnedOut = false
local isCrouching = false
local isSliding = false
local lastSentCrouchState = nil
local baseWalkSpeed = 16
local crouchAnimation = Instance.new("Animation")
local slideAnimation = Instance.new("Animation")
local crouchTrack = nil
local slideTrack = nil
local slideEndsAt = 0
local slideDirection = Vector3.new(0, 0, -1)

crouchAnimation.AnimationId = CROUCH_ANIMATION_ID
slideAnimation.AnimationId = SLIDE_ANIMATION_ID

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	end

	if value > maximum then
		return maximum
	end

	return value
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

local function getAnimator(humanoid)
	return humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
end

local function updateCrouchAnimation(humanoid)
	if not humanoid then
		stopCrouchAnimation()
		return
	end

	if isSliding then
		stopCrouchAnimation()
		return
	end

	local animator = getAnimator(humanoid)
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

local function playSlideAnimation(humanoid)
	if not humanoid then
		return
	end

	local animator = getAnimator(humanoid)
	if not slideTrack then
		slideTrack = animator:LoadAnimation(slideAnimation)
		slideTrack.Priority = Enum.AnimationPriority.Action
		slideTrack.Looped = false
	end

	stopCrouchAnimation()
	slideTrack:Stop(0)
	slideTrack.TimePosition = 0
	slideTrack:Play(0.05)
end

local function syncAttributes(isSprinting)
	player:SetAttribute("SprintEnergy", sprintEnergy)
	player:SetAttribute("SprintBurnedOut", sprintBurnedOut)
	player:SetAttribute("IsSprinting", isSprinting)
	player:SetAttribute("IsCrouching", isCrouching)
	player:SetAttribute("IsSliding", isSliding)
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

	if isSliding then
		humanoid.WalkSpeed = baseWalkSpeed * CROUCH_SPEED_MULTIPLIER
	elseif isCrouching then
		humanoid.WalkSpeed = baseWalkSpeed * CROUCH_SPEED_MULTIPLIER
	elseif isSprinting then
		humanoid.WalkSpeed = baseWalkSpeed * SPRINT_SPEED_MULTIPLIER
	else
		humanoid.WalkSpeed = baseWalkSpeed
	end
end

local function applyJumpReduction(humanoid)
	if humanoid.UseJumpPower then
		humanoid.JumpPower = humanoid.JumpPower * JUMP_REDUCTION_MULTIPLIER
	else
		humanoid.JumpHeight = humanoid.JumpHeight * JUMP_REDUCTION_MULTIPLIER
	end
end

local function applySlideSprintCooldown()
	sprintEnergy = math.max(0, sprintEnergy - SLIDE_SPRINT_ENERGY_PENALTY)
	if sprintEnergy <= 0 then
		sprintBurnedOut = true
	end
end

local function finishSlide()
	local keepCrouching = crouchHeld
	if not isSliding then
		return
	end

	isSliding = false
	isCrouching = keepCrouching
	applySlideSprintCooldown()
	stopSlideAnimation()
	syncCrouchStateToServer()
end

local function cancelSlide()
	if not isSliding then
		return
	end

	isSliding = false
	isCrouching = false
	stopSlideAnimation()
	syncCrouchStateToServer()
end

local function canStartSlide(humanoid, isSprinting)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if isSliding or not isSprinting or sprintBurnedOut or sprintEnergy <= 0 then
		return false
	end

	if humanoid.MoveDirection.Magnitude <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	return true
end

local function startSlide(humanoid)
	local rootPart = getRootPart()
	if not humanoid or not rootPart then
		return false
	end

	local lookVector = rootPart.CFrame.LookVector
	local horizontalDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
	if horizontalDirection.Magnitude <= 0 then
		return false
	end

	slideDirection = horizontalDirection.Unit
	isSliding = true
	isCrouching = true
	slideEndsAt = os.clock() + SLIDE_DURATION

	syncCrouchStateToServer()
	playSlideAnimation(humanoid)
	return true
end

local function updateSlideVelocity()
	if not isSliding then
		return
	end

	local rootPart = getRootPart()
	if not rootPart then
		finishSlide()
		return
	end

	local timeRemaining = slideEndsAt - os.clock()
	if timeRemaining <= 0 then
		finishSlide()
		return
	end

	local elapsedTime = SLIDE_DURATION - timeRemaining
	local speedMultiplier = SLIDE_SPEED_MULTIPLIER

	if elapsedTime < SLIDE_BURST_DURATION then
		local burstProgress = clamp(elapsedTime / SLIDE_BURST_DURATION, 0, 1)
		speedMultiplier = SLIDE_BURST_SPEED_MULTIPLIER + ((SLIDE_SPEED_MULTIPLIER - SLIDE_BURST_SPEED_MULTIPLIER) * burstProgress)
	else
		local slowdownDuration = math.max(SLIDE_DURATION - SLIDE_BURST_DURATION, 0.001)
		local slowdownProgress = clamp((elapsedTime - SLIDE_BURST_DURATION) / slowdownDuration, 0, 1)
		speedMultiplier = SLIDE_SPEED_MULTIPLIER + ((CROUCH_SPEED_MULTIPLIER - SLIDE_SPEED_MULTIPLIER) * slowdownProgress)
	end

	local horizontalSpeed = baseWalkSpeed * speedMultiplier
	rootPart.AssemblyLinearVelocity = Vector3.new(
		slideDirection.X * horizontalSpeed,
		rootPart.AssemblyLinearVelocity.Y,
		slideDirection.Z * horizontalSpeed
	)
end

local function initializeCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	baseWalkSpeed = humanoid.WalkSpeed
	crouchHeld = false
	isCrouching = false
	isSliding = false
	sprintHeld = false
	lastSentCrouchState = nil
	crouchTrack = nil
	slideTrack = nil
	slideEndsAt = 0
	slideDirection = Vector3.new(0, 0, -1)
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
		crouchHeld = true
		local humanoid = getHumanoid()
		local isSprinting = sprintHeld and not isCrouching and humanoid and humanoid.MoveDirection.Magnitude > 0 and sprintEnergy > 0 and not sprintBurnedOut
		if not canStartSlide(humanoid, isSprinting) then
			isCrouching = true
			syncCrouchStateToServer()
		else
			startSlide(humanoid)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == SPRINT_KEY then
		sprintHeld = false
	elseif input.KeyCode == CROUCH_KEY then
		crouchHeld = false
		if not isSliding then
			isCrouching = false
			syncCrouchStateToServer()
		end
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		finishSlide()
		stopCrouchAnimation()
		stopSlideAnimation()
		syncAttributes(false)
		return
	end

	if sprintBurnedOut and sprintEnergy >= 1 then
		sprintBurnedOut = false
	end

	local canSprint = sprintHeld and not isCrouching and not isSliding and humanoid.MoveDirection.Magnitude > 0 and sprintEnergy > 0 and not sprintBurnedOut

	if canSprint then
		sprintEnergy = math.max(0, sprintEnergy - (deltaTime / MAX_SPRINT_DURATION))
		if sprintEnergy <= 0 then
			sprintEnergy = 0
			sprintBurnedOut = true
			canSprint = false
		end
	elseif not isSliding then
		local recoveryDuration = sprintBurnedOut and EXHAUSTED_RECOVERY_DURATION or NORMAL_RECOVERY_DURATION
		if sprintEnergy < 1 then
			sprintEnergy = math.min(1, sprintEnergy + (deltaTime / recoveryDuration))
		end
	end

	updateSlideVelocity()
	updateWalkSpeed(humanoid, canSprint)
	updateCrouchAnimation(humanoid)
	syncAttributes(canSprint)
end)