local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local gameplayConfigModule = script.Parent:FindFirstChild("GameplayConfig")
	or script.Parent.Parent:WaitForChild("GameplayConfig")
local GameplayConfig = require(gameplayConfigModule)

local MOVEMENT_INPUT_EVENT_NAME = "MovementInputEvent"
local movementConfig = GameplayConfig.Movement

local function ensureRemoteEvent(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local movementInputEvent = ensureRemoteEvent(MOVEMENT_INPUT_EVENT_NAME)
local movementStates = {}

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	end

	if value > maximum then
		return maximum
	end

	return value
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getState(player)
	local state = movementStates[player]
	if state then
		return state
	end

	state = {
		sprintHeld = false,
		crouchHeld = false,
		sprintEnergy = 1,
		sprintBurnedOut = false,
		isCrouching = false,
		isSliding = false,
		slideEndsAt = 0,
		slideDirection = Vector3.new(0, 0, -1),
		baseWalkSpeed = movementConfig.DefaultWalkSpeed,
	}

	movementStates[player] = state
	return state
end

local function syncAttributes(player, state, isSprinting)
	player:SetAttribute("SprintEnergy", state.sprintEnergy)
	player:SetAttribute("SprintBurnedOut", state.sprintBurnedOut)
	player:SetAttribute("IsSprinting", isSprinting)
	player:SetAttribute("IsCrouching", state.isCrouching)
	player:SetAttribute("IsSliding", state.isSliding)
	player:SetAttribute("SprintEnergyPercent", math.floor((state.sprintEnergy * 100) + 0.5))
end

local function resetMovementState(player)
	local state = getState(player)
	state.sprintHeld = false
	state.crouchHeld = false
	state.sprintEnergy = 1
	state.sprintBurnedOut = false
	state.isCrouching = false
	state.isSliding = false
	state.slideEndsAt = 0
	state.slideDirection = Vector3.new(0, 0, -1)
	syncAttributes(player, state, false)
	return state
end

local function applyJumpReduction(humanoid)
	if humanoid.UseJumpPower then
		humanoid.JumpPower = humanoid.JumpPower * movementConfig.JumpReductionMultiplier
	else
		humanoid.JumpHeight = humanoid.JumpHeight * movementConfig.JumpReductionMultiplier
	end
end

local function canSprint(state, humanoid)
	return state.sprintHeld
		and not state.isCrouching
		and not state.isSliding
		and humanoid.MoveDirection.Magnitude > 0
		and state.sprintEnergy > 0
		and not state.sprintBurnedOut
end

local function updateWalkSpeed(humanoid, state, isSprinting)
	if state.isSliding or state.isCrouching then
		humanoid.WalkSpeed = state.baseWalkSpeed * movementConfig.CrouchSpeedMultiplier
	elseif isSprinting then
		humanoid.WalkSpeed = state.baseWalkSpeed * movementConfig.SprintSpeedMultiplier
	else
		humanoid.WalkSpeed = state.baseWalkSpeed
	end
end

local function applySlidePenalty(state)
	state.sprintEnergy = math.max(0, state.sprintEnergy - movementConfig.SlideSprintEnergyPenalty)
	if state.sprintEnergy <= 0 then
		state.sprintBurnedOut = true
	end
end

local function finishSlide(state)
	if not state.isSliding then
		return
	end

	state.isSliding = false
	state.isCrouching = state.crouchHeld
	applySlidePenalty(state)
end

local function cancelSlide(state)
	if not state.isSliding then
		return
	end

	state.isSliding = false
	state.isCrouching = false
	state.slideEndsAt = 0
	state.slideDirection = Vector3.new(0, 0, -1)
end

local function canStartSlide(player, state, humanoid)
	local rootPart = getRootPart(player)
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return false
	end

	if state.isSliding or not canSprint(state, humanoid) then
		return false
	end

	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	return true
end

local function startSlide(player, state, humanoid)
	local rootPart = getRootPart(player)
	if not humanoid or not rootPart then
		return false
	end

	local lookVector = rootPart.CFrame.LookVector
	local horizontalDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
	if horizontalDirection.Magnitude <= 0 then
		return false
	end

	state.slideDirection = horizontalDirection.Unit
	state.isSliding = true
	state.isCrouching = true
	state.slideEndsAt = tick() + movementConfig.SlideDuration
	return true
end

local function updateSlideVelocity(player, state)
	if not state.isSliding then
		return
	end

	local rootPart = getRootPart(player)
	if not rootPart then
		cancelSlide(state)
		return
	end

	local timeRemaining = state.slideEndsAt - tick()
	if timeRemaining <= 0 then
		finishSlide(state)
		return
	end

	local elapsedTime = movementConfig.SlideDuration - timeRemaining
	local speedMultiplier = movementConfig.SlideSpeedMultiplier

	if elapsedTime < movementConfig.SlideBurstDuration then
		local burstProgress = clamp(elapsedTime / movementConfig.SlideBurstDuration, 0, 1)
		speedMultiplier = movementConfig.SlideBurstSpeedMultiplier + ((movementConfig.SlideSpeedMultiplier - movementConfig.SlideBurstSpeedMultiplier) * burstProgress)
	else
		local slowdownDuration = math.max(movementConfig.SlideDuration - movementConfig.SlideBurstDuration, 0.001)
		local slowdownProgress = clamp((elapsedTime - movementConfig.SlideBurstDuration) / slowdownDuration, 0, 1)
		speedMultiplier = movementConfig.SlideSpeedMultiplier + ((movementConfig.CrouchSpeedMultiplier - movementConfig.SlideSpeedMultiplier) * slowdownProgress)
	end

	local horizontalSpeed = state.baseWalkSpeed * speedMultiplier
	rootPart.AssemblyLinearVelocity = Vector3.new(
		state.slideDirection.X * horizontalSpeed,
		rootPart.AssemblyLinearVelocity.Y,
		state.slideDirection.Z * horizontalSpeed
	)
end

local function initializeCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	local state = resetMovementState(player)
	state.baseWalkSpeed = humanoid.WalkSpeed > 0 and humanoid.WalkSpeed or movementConfig.DefaultWalkSpeed
	applyJumpReduction(humanoid)
	updateWalkSpeed(humanoid, state, false)
	syncAttributes(player, state, false)
end

local function initializePlayer(player)
	resetMovementState(player)
	player.CharacterAdded:Connect(function(character)
		initializeCharacter(player, character)
	end)

	if player.Character then
		initializeCharacter(player, player.Character)
	end
end

movementInputEvent.OnServerEvent:Connect(function(player, action, isActive)
	if type(action) ~= "string" or type(isActive) ~= "boolean" then
		return
	end

	local state = getState(player)
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if action == "Sprint" then
		state.sprintHeld = isActive
	elseif action == "Crouch" then
		local wasHeld = state.crouchHeld
		state.crouchHeld = isActive

		if isActive and not wasHeld then
			if not canStartSlide(player, state, humanoid) then
				state.isCrouching = true
			else
				startSlide(player, state, humanoid)
			end
		elseif not isActive and wasHeld and not state.isSliding then
			state.isCrouching = false
		end
	else
		return
	end

	local isSprinting = canSprint(state, humanoid)
	updateWalkSpeed(humanoid, state, isSprinting)
	syncAttributes(player, state, isSprinting)
end)

RunService.Heartbeat:Connect(function(deltaTime)
	for player, state in pairs(movementStates) do
		local humanoid = getHumanoid(player)
		if not humanoid or humanoid.Health <= 0 then
			cancelSlide(state)
			state.isCrouching = false
			syncAttributes(player, state, false)
		else
			if state.sprintBurnedOut and state.sprintEnergy >= 1 then
				state.sprintBurnedOut = false
			end

			local isSprinting = canSprint(state, humanoid)
			if isSprinting then
				state.sprintEnergy = math.max(0, state.sprintEnergy - (deltaTime / movementConfig.MaxSprintDuration))
				if state.sprintEnergy <= 0 then
					state.sprintEnergy = 0
					state.sprintBurnedOut = true
					isSprinting = false
				end
			elseif not state.isSliding then
				local recoveryDuration = state.sprintBurnedOut and movementConfig.ExhaustedRecoveryDuration or movementConfig.NormalRecoveryDuration
				if state.sprintEnergy < 1 then
					state.sprintEnergy = math.min(1, state.sprintEnergy + (deltaTime / recoveryDuration))
				end
			end

			updateSlideVelocity(player, state)
			isSprinting = canSprint(state, humanoid)
			updateWalkSpeed(humanoid, state, isSprinting)
			syncAttributes(player, state, isSprinting)
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	initializePlayer(player)
end

Players.PlayerAdded:Connect(initializePlayer)

Players.PlayerRemoving:Connect(function(player)
	movementStates[player] = nil
end)