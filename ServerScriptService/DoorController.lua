--====================================================
--                  DOOR CONTROLLER
--====================================================
--[[
Attach this script to ServerScriptService.
Any BasePart named "Door" anywhere in the Workspace will
be picked up automatically (including parts added at runtime).
The hinge is on the part's local -X edge.
If the door opens the wrong way, set a boolean attribute
named "HingeRight" = true on the Part.
====================================================]]

local Workspace          = game:GetService("Workspace")
local TweenService       = game:GetService("TweenService")

local DOOR_NAME         = "Door"
local OPEN_DURATION     = 0.6   -- seconds to swing open
local SLAM_DURATION     = 0.25  -- seconds to slam shut
local PROXIMITY_DIST    = 8     -- max stud distance to interact

-- Active tween per door so we can cancel mid-animation
local activeTweens = {}

local function stopTween(door)
	if activeTweens[door] then
		activeTweens[door]:Cancel()
		activeTweens[door] = nil
	end
end

local function tweenDoor(door, targetCF, duration, style, direction)
	stopTween(door)
	local info  = TweenInfo.new(duration, style, direction)
	local tween = TweenService:Create(door, info, { CFrame = targetCF })
	activeTweens[door] = tween
	tween.Completed:Connect(function()
		if activeTweens[door] == tween then
			activeTweens[door] = nil
		end
	end)
	tween:Play()
	return tween
end

-- Build open CFrame by rotating 90 degrees around one vertical edge.
-- HingeRight attribute = true  →  hinge on local +X edge (right)
--                        false →  hinge on local -X edge (left, default)
local function buildOpenCFrame(door)
	local hingeRight = door:GetAttribute("HingeRight") == true
	local halfWidth  = door.Size.X / 2
	local edgeOffset = hingeRight and halfWidth or -halfWidth
	local angle      = hingeRight and math.rad(90) or math.rad(-90)

	-- Rotate around the chosen edge: translate to edge → rotate → translate back
	return door.CFrame
		* CFrame.new(edgeOffset, 0, 0)
		* CFrame.Angles(0, angle, 0)
		* CFrame.new(-edgeOffset, 0, 0)
end

local function setupDoor(door)
	if not door:IsA("BasePart") then return end

	door.Anchored = true

	local closedCF = door.CFrame
	local openCF   = buildOpenCFrame(door)
	local isOpen   = false

	-- ── Open prompt: hold E for 2 seconds ──────────────────────────
	local openPrompt = Instance.new("ProximityPrompt")
	openPrompt.Name                = "OpenPrompt"
	openPrompt.ActionText          = "Open Door"
	openPrompt.KeyboardKeyCode     = Enum.KeyCode.E
	openPrompt.HoldDuration        = 2
	openPrompt.MaxActivationDistance = PROXIMITY_DIST
	openPrompt.RequiresLineOfSight    = false
	openPrompt:SetAttribute("UseLoadingGui", true)      -- hooks into MapInteractionClient loading bar
	openPrompt:SetAttribute("LoaderText", "OPENING DOOR")
	openPrompt.Parent = door

	-- ── Slam prompt: tap E (only visible when door is open) ─────────
	local slamPrompt = Instance.new("ProximityPrompt")
	slamPrompt.Name                = "SlamPrompt"
	slamPrompt.ActionText          = "Slam Shut"
	slamPrompt.KeyboardKeyCode     = Enum.KeyCode.E
	slamPrompt.HoldDuration        = 0
	slamPrompt.MaxActivationDistance = PROXIMITY_DIST
	slamPrompt.RequiresLineOfSight   = false
	slamPrompt.Enabled             = false
	slamPrompt.Parent              = door

	-- ── Handlers ────────────────────────────────────────────────────
	openPrompt.Triggered:Connect(function()
		if isOpen then return end
		isOpen = true
		openPrompt.Enabled = false
		slamPrompt.Enabled = true

		tweenDoor(door, openCF, OPEN_DURATION,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	slamPrompt.Triggered:Connect(function()
		if not isOpen then return end
		isOpen = false
		slamPrompt.Enabled = false

		local tween = tweenDoor(door, closedCF, SLAM_DURATION,
			Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		tween.Completed:Connect(function()
			if not isOpen then          -- guard against re-open mid-tween
				openPrompt.Enabled = true
			end
		end)
	end)
end

-- ── Bootstrap ────────────────────────────────────────────────────────
for _, part in ipairs(Workspace:GetDescendants()) do
	if part:IsA("BasePart") and part.Name == DOOR_NAME then
		setupDoor(part)
	end
end

Workspace.DescendantAdded:Connect(function(part)
	if part:IsA("BasePart") and part.Name == DOOR_NAME then
		setupDoor(part)
	end
end)
