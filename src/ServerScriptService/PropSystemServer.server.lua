local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropService = require(script.Parent.PropService)
local folder = ReplicatedStorage:FindFirstChild("PropRemotes") or Instance.new("Folder")
folder.Name = "PropRemotes"
folder.Parent = ReplicatedStorage

local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder

local function isNearProp(player, prop)
	local record = PropService:GetRecord(prop)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return record ~= nil and root ~= nil and root:IsA("BasePart") and (root.Position - record.instance.Position).Magnitude <= 12
end

request.OnServerInvoke = function(player, action, prop, value)
	if typeof(prop) ~= "Instance" then
		return false, "Invalid prop"
	end
	if action == "Grab" and typeof(value) == "Vector3" then
		return PropService:Grab(player, prop, value)
	elseif action == "Release" then
		return PropService:Release(player, prop)
	elseif action == "Anchor" and typeof(value) == "boolean" and isNearProp(player, prop) then
		return PropService:SetAnchored(prop, value)
	elseif action == "Rotate" and typeof(value) == "number" then
		return PropService:Rotate(player, prop, value)
	end
	return false, "Unknown action"
end

Players.PlayerRemoving:Connect(function(player)
	PropService:ReleaseAll(player)
end)

PropService:Start()
