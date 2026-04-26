local ReplicatedStorage = game:GetService("ReplicatedStorage")
local cooldownEvent = ReplicatedStorage:WaitForChild("CooldownEvent")

_G.cooldownReady = true
_G.tagbackReady = true
_G.tagCooldownEndsAt = 0
_G.noTagBackEndsAt = 0

cooldownEvent.OnClientEvent:Connect(function(data)
	_G.tagCooldownEndsAt = data.cooldownEndsAt or 0
	_G.noTagBackEndsAt = data.noTagBackEndsAt or 0
	_G.cooldownReady = tick() >= _G.tagCooldownEndsAt
	_G.tagbackReady = tick() >= _G.noTagBackEndsAt
end)

