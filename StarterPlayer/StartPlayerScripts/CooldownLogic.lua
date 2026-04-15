local ReplicatedStorage = game:GetService("ReplicatedStorage")
local cooldownEvent = ReplicatedStorage:WaitForChild("CooldownEvent")

_G.cooldownReady = true
_G.tagbackReady = true

cooldownEvent.OnClientEvent:Connect(function(data)
	_G.cooldownReady = data.cooldown
	_G.tagbackReady = data.tagback
end)

