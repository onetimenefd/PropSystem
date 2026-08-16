local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PropService = require(script.Parent.PropService)
local PlotService = require(script.Parent.PlotService)
local BuildService = require(script.Parent.BuildService)
PropService:SetPlotService(PlotService)
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

local buildRemotes = ReplicatedStorage:FindFirstChild("BuildRemotes") or Instance.new("Folder")
buildRemotes.Name = "BuildRemotes"; buildRemotes.Parent = ReplicatedStorage
local placeBuild = buildRemotes:FindFirstChild("RequestPlaceBuild") or Instance.new("RemoteEvent")
placeBuild.Name = "RequestPlaceBuild"; placeBuild.Parent = buildRemotes
local buildResult = buildRemotes:FindFirstChild("Result") or Instance.new("RemoteEvent")
buildResult.Name = "Result"; buildResult.Parent = buildRemotes
placeBuild.OnServerEvent:Connect(function(player, buildType, desiredCFrame)
	local ok, reason = BuildService:Place(player, buildType, desiredCFrame)
	buildResult:FireClient(player, ok, reason)
end)

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
		local ok, reason = PropService:SetAnchored(player, prop, value)
		if not ok and reason then result:FireClient(player, "Notice", prop, false, reason) end
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

local function watchCharacter(player, character)
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		PropService:DisableRightArm(player)
	end)
end

local function watchPlayer(player)
	player.Chatted:Connect(function(message)
		local words = string.split(message, " ")
		local command = string.lower(words[1] or "")
		local ok, reason = false, "Unknown plot command"
		if command == "!pc" then ok, reason = PlotService:Create(player)
		elseif command == "!rmp" then ok, reason = PlotService:Remove(player)
		elseif command == "!pt" or command == "!ptr" then
			if command == "!ptr" and string.lower(words[2] or "") == "all" then ok, reason = PlotService:ClearTrusted(player)
		else
			local query = string.lower(words[2] or "")
			local target
			for _, candidate in Players:GetPlayers() do
				if string.sub(string.lower(candidate.Name), 1, #query) == query or string.sub(string.lower(candidate.DisplayName), 1, #query) == query then target = candidate; break end
			end
			if query == "" or not target then reason = "Player not found" else ok, reason = PlotService:SetTrusted(player, target, command == "!pt") end
		end end
		if command == "!pc" or command == "!rmp" or command == "!pt" or command == "!ptr" then
			result:FireClient(player, "Notice", nil, ok, reason or (if ok then "Plot updated" else "Request denied"))
		end
	end)
	player.CharacterAdded:Connect(function(character) watchCharacter(player, character) end)
	if player.Character then watchCharacter(player, player.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do watchPlayer(player) end

PropService:Start()
