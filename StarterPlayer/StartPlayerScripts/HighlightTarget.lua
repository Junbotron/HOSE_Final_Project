--====================================================
--              TARGET HIGHLIGHT SYSTEM
--====================================================
--[[
This script:
• Highlights players you can tag
• Only activates when YOU are the tagger
• Uses colors to show cooldown, no-tagback, or taggable state
====================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local MAX_HIGHLIGHT_DISTANCE = 3

--==================================================
--                HIGHLIGHT OBJECT
--==================================================

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.5
highlight.OutlineColor = Color3.fromRGB(255,255,255)
highlight.Enabled = false
highlight.Parent = workspace

local function clear()
	highlight.Enabled = false
	highlight.Adornee = nil
end

--==================================================
--              HIGHLIGHT UPDATE LOOP
--==================================================

RunService.RenderStepped:Connect(function()
	-- Only highlight if YOU are the tagger
	if not _G.isIt then return clear() end

	local target = mouse.Target
	if not target then return clear() end

	local character = target:FindFirstAncestorOfClass("Model")
	if not character then return clear() end

	local targetPlayer = Players:GetPlayerFromCharacter(character)
	if not targetPlayer or targetPlayer == player then return clear() end
	if targetPlayer:GetAttribute("IsInvisible") then return clear() end

	local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tRoot = character:FindFirstChild("HumanoidRootPart")
	if not pRoot or not tRoot then return clear() end

	-- Must be close enough to tag
	if (pRoot.Position - tRoot.Position).Magnitude > MAX_HIGHLIGHT_DISTANCE then
		return clear()
	end

	local now = tick()
	local noTagBackEndsAt = targetPlayer:GetAttribute("NoTagBackEndsAt") or 0

	if now < noTagBackEndsAt then
		highlight.FillColor = Color3.fromRGB(255, 0, 0)
	else
		highlight.FillColor = Color3.fromRGB(0, 255, 0)
	end

	highlight.Adornee = character
	highlight.Enabled = true
end)