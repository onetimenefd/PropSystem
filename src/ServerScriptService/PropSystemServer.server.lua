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
local result = folder:FindFirstChild("Result")
if result and not result:IsA("RemoteEvent") then result:Destroy(); result = nil end
if not result then result = Instance.new("RemoteEvent"); result.Name = "Result"; result.Parent = folder end
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

request.OnServerEvent:Connect(function(player, action, prop, value, value2, value3)
	if typeof(prop) ~= "Instance" then
		return
	end
	if action == "Grab" and typeof(value) == "Vector3" and typeof(value2) == "Vector3" then
		local ok, reason, attachment, side = PropService:Grab(player, prop, value, value2)
		result:FireClient(player, "Grab", prop, ok, reason, attachment, side)
	elseif action == "Release" then
		PropService:Release(player, prop)
	elseif action == "Anchor" and typeof(value) == "boolean" and isNearProp(player, prop) then
		PropService:SetAnchored(prop, value)
	elseif action == "Distance" and typeof(value) == "number" then
		PropService:AdjustHold(player, prop, math.clamp(value, -0.35, 0.35))
	elseif action == "Target" and typeof(value) == "Vector3" and typeof(value2) == "Vector3" then
		PropService:UpdateTarget(player, prop, value, value2)
	end
end)

PropService.GripEnded:Connect(function(player, prop, reason)
	result:FireClient(player, "Broken", prop, reason)
end)

Players.PlayerRemoving:Connect(function(player)
	PropService:ReleaseAll(player, "PlayerLeft")
end)

PropService:Start()
