local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropService = require(script.Parent.PropService)
local folder = ReplicatedStorage:FindFirstChild("PropRemotes")
if folder and not folder:IsA("Folder") then
	folder:Destroy()
	folder = nil
end
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "PropRemotes"
	folder.Parent = ReplicatedStorage
end

-- Prop actions are one-way requests. Keep this endpoint as a RemoteEvent so
-- client input never blocks while waiting for a response from the server.
local request = folder:FindFirstChild("Request")
if request and not request:IsA("RemoteEvent") then
	request:Destroy()
	request = nil
end
if not request then
	request = Instance.new("RemoteEvent")
	request.Name = "Request"
	request.Parent = folder
end

local function isNearProp(player, prop)
	local record = PropService:GetRecord(prop)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return record ~= nil and root ~= nil and root:IsA("BasePart") and (root.Position - record.instance.Position).Magnitude <= 12
end

request.OnServerEvent:Connect(function(player, action, prop, value)
	if typeof(prop) ~= "Instance" then
		return
	end
	if action == "Grab" and typeof(value) == "Vector3" then
		PropService:Grab(player, prop, value)
	elseif action == "Release" then
		PropService:Release(player, prop)
	elseif action == "Anchor" and typeof(value) == "boolean" and isNearProp(player, prop) then
		PropService:SetAnchored(prop, value)
	elseif action == "Rotate" and typeof(value) == "number" then
		PropService:Rotate(player, prop, value)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PropService:ReleaseAll(player)
end)

PropService:Start()
