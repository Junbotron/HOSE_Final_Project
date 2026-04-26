local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local requestEvent = ReplicatedStorage:WaitForChild("InvisibilityRequestEvent")

local ABILITY_KEY = Enum.KeyCode.Q
local SELF_TRANSPARENCY = 0.55
local SELF_OUTLINE_COLOR = Color3.fromRGB(150, 150, 150)

local hiddenStates = {}
local trackedPlayers = {}
local selfTrackedTransparency = {}
local selfDescendantConnection = nil
local selfHighlight = Instance.new("Highlight")

selfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
selfHighlight.FillTransparency = 1
selfHighlight.OutlineColor = SELF_OUTLINE_COLOR
selfHighlight.OutlineTransparency = 0
selfHighlight.Enabled = false
selfHighlight.Parent = workspace

local function restoreVisibility(targetPlayer)
	local state = hiddenStates[targetPlayer]
	if not state then return end

	for instance, originalValue in pairs(state.trackedTransparency) do
		if instance.Parent then
			if instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = originalValue
			elseif instance:IsA("Decal") then
				instance.Transparency = originalValue
			end
		end
	end

	if state.descendantConnection then
		state.descendantConnection:Disconnect()
		state.descendantConnection = nil
	end

	hiddenStates[targetPlayer] = nil
end

local function restoreSelfVisibility()
	for instance, originalValue in pairs(selfTrackedTransparency) do
		if instance.Parent then
			if instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = originalValue
			elseif instance:IsA("Decal") then
				instance.Transparency = originalValue
			end
		end
	end

	if selfDescendantConnection then
		selfDescendantConnection:Disconnect()
		selfDescendantConnection = nil
	end

	selfTrackedTransparency = {}
	selfHighlight.Adornee = nil
	selfHighlight.Enabled = false
end

local function applyInvisibility(targetPlayer, instance)
	local state = hiddenStates[targetPlayer]
	if not state then return end

	if instance:IsA("BasePart") then
		if state.trackedTransparency[instance] == nil then
			state.trackedTransparency[instance] = instance.LocalTransparencyModifier
		end
		instance.LocalTransparencyModifier = 1
	elseif instance:IsA("Decal") then
		if state.trackedTransparency[instance] == nil then
			state.trackedTransparency[instance] = instance.Transparency
		end
		instance.Transparency = 1
	end
end

local function applySelfInvisibility(instance)
	if instance:IsA("BasePart") then
		if selfTrackedTransparency[instance] == nil then
			selfTrackedTransparency[instance] = instance.LocalTransparencyModifier
		end
		instance.LocalTransparencyModifier = math.max(selfTrackedTransparency[instance], SELF_TRANSPARENCY)
	elseif instance:IsA("Decal") then
		if selfTrackedTransparency[instance] == nil then
			selfTrackedTransparency[instance] = instance.Transparency
		end
		instance.Transparency = math.max(selfTrackedTransparency[instance], SELF_TRANSPARENCY)
	end
end

local function hideCharacter(targetPlayer, character)
	restoreVisibility(targetPlayer)

	local state = {
		trackedTransparency = {},
		descendantConnection = nil,
	}
	hiddenStates[targetPlayer] = state

	for _, descendant in ipairs(character:GetDescendants()) do
		applyInvisibility(targetPlayer, descendant)
	end

	state.descendantConnection = character.DescendantAdded:Connect(function(descendant)
		if targetPlayer:GetAttribute("IsInvisible") then
			applyInvisibility(targetPlayer, descendant)
		end
	end)
end

local function showSelfInvisible(character)
	restoreSelfVisibility()

	for _, descendant in ipairs(character:GetDescendants()) do
		applySelfInvisibility(descendant)
	end

	selfDescendantConnection = character.DescendantAdded:Connect(function(descendant)
		if player:GetAttribute("IsInvisible") then
			applySelfInvisibility(descendant)
		end
	end)

	selfHighlight.Adornee = character
	selfHighlight.Enabled = true
end

local function syncPlayerVisibility(targetPlayer)
	if targetPlayer == player then
		if targetPlayer:GetAttribute("IsInvisible") then
			local character = targetPlayer.Character
			if character and character.Parent then
				showSelfInvisible(character)
			end
		else
			restoreSelfVisibility()
		end
		return
	end

	if targetPlayer:GetAttribute("IsInvisible") then
		local character = targetPlayer.Character
		if character and character.Parent then
			hideCharacter(targetPlayer, character)
		end
	else
		restoreVisibility(targetPlayer)
	end
end

local function trackPlayer(targetPlayer)
	if trackedPlayers[targetPlayer] then return end

	trackedPlayers[targetPlayer] = {
		attributeConnection = targetPlayer:GetAttributeChangedSignal("IsInvisible"):Connect(function()
			syncPlayerVisibility(targetPlayer)
		end),
		characterConnection = targetPlayer.CharacterAdded:Connect(function()
			task.defer(function()
				syncPlayerVisibility(targetPlayer)
			end)
		end),
		ancestryConnection = targetPlayer.AncestryChanged:Connect(function(_, parent)
			if parent then return end
			restoreVisibility(targetPlayer)
			local connections = trackedPlayers[targetPlayer]
			if not connections then return end
			connections.attributeConnection:Disconnect()
			connections.characterConnection:Disconnect()
			connections.ancestryConnection:Disconnect()
			trackedPlayers[targetPlayer] = nil
		end),
	}

	syncPlayerVisibility(targetPlayer)
end

for _, otherPlayer in ipairs(Players:GetPlayers()) do
	trackPlayer(otherPlayer)
end

Players.PlayerAdded:Connect(trackPlayer)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode ~= ABILITY_KEY then return end
	if player:GetAttribute("IsInvisible") then return end
	if tick() < (player:GetAttribute("InvisibilityCooldownEndsAt") or 0) then return end

	requestEvent:FireServer()
end)