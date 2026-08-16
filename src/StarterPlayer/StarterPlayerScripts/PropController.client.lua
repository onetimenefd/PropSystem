local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.PropSystem.Config)
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("PropRemotes")
local request = remotes:WaitForChild("Request")
local result = remotes:WaitForChild("Result")
local held, pending, focused
local previousCameraMode, previousAutoRotate
local lastTargetUpdate = 0
local localArms = {}

local gui = Instance.new("ScreenGui")
gui.Name = "PropInfo"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("TextLabel")
panel.AnchorPoint = Vector2.new(0.5, 1); panel.Position = UDim2.fromScale(0.5, 0.86); panel.Size = UDim2.fromOffset(320, 120)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 24); panel.BackgroundTransparency = 0.12; panel.TextColor3 = Color3.new(1, 1, 1)
panel.Font = Enum.Font.GothamMedium; panel.TextSize = 16; panel.RichText = true; panel.Visible = false; panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local function taggedAncestor(instance)
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, "Prop") or instance:GetAttribute("ObjectID") then return instance end
		instance = instance.Parent
	end
end

local function restoreCarryState()
	if previousCameraMode then player.CameraMode = previousCameraMode; previousCameraMode = nil end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and previousAutoRotate ~= nil then humanoid.AutoRotate = previousAutoRotate end
	previousAutoRotate = nil
end

local function clearLocalArms()
	for _, arm in localArms do arm:Destroy() end
	table.clear(localArms)
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("PropCarryArm") and child:GetAttribute("OwnerUserId") == player.UserId then
				child.LocalTransparencyModifier = 0
			end
		end
	end
end

local function breakGrip(reason)
	if not held then return end
	held = nil
	clearLocalArms()
	restoreCarryState()
	if reason and reason ~= "Released" then warn("Grip ended: " .. reason) end
end

local function syncLocalArms(character)
	local activeSides = {}
	for _, serverArm in character:GetChildren() do
		if not serverArm:IsA("BasePart") or not serverArm:GetAttribute("PropCarryArm") or serverArm:GetAttribute("OwnerUserId") ~= player.UserId then continue end
		serverArm.LocalTransparencyModifier = 1
		local side = serverArm:GetAttribute("GripSide")
		if typeof(side) ~= "string" then continue end
		activeSides[side] = true
		if not localArms[side] then
			local clone = serverArm:Clone()
			-- Classic Shirt textures are applied by matching the canonical R6 limb name.
			clone.Name = serverArm.Name
			clone:SetAttribute("PropCarryArm", nil)
			clone.LocalTransparencyModifier = 0
			clone.Parent = character
			localArms[side] = clone
		end
	end
	for side, arm in localArms do
		if not activeSides[side] then arm:Destroy(); localArms[side] = nil end
	end
end

local function startArm()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		previousCameraMode = player.CameraMode
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		previousAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
	end
end

RunService.RenderStepped:Connect(function()
	if held then
		panel.Text = "<b>Holding</b>\nMouse wheel: distance\n[ E ] Release"
		panel.Visible = true
		if not held.target.Parent then breakGrip("PropDestroyed"); return end
		local camera, character = workspace.CurrentCamera, player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if camera and root and root:IsA("BasePart") then
			syncLocalArms(character)
			local torso = character:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				for side, arm in localArms do
					local shoulder = (torso.CFrame * CFrame.new(if side == "Left" then -1.5 else 1.5, 0.5, 0)).Position
					local gripPosition = held.target.WorldPosition
					local delta = gripPosition - shoulder
					if delta.Magnitude > 0.01 then
						arm.Size = Vector3.new(arm.Size.X, math.min(delta.Magnitude + Config.ArmOverlap * 2, Config.BreakDistance + Config.ArmOverlap * 2), arm.Size.Z)
						arm.CFrame = CFrame.lookAt(shoulder:Lerp(gripPosition, 0.5), gripPosition) * CFrame.Angles(math.pi / 2, 0, 0)
					end
				end
			end
			local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
			if flatLook.Magnitude > 0.01 then root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook) end
			if os.clock() - lastTargetUpdate >= 1 / Config.TargetUpdateRate then
				lastTargetUpdate = os.clock()
				request:FireServer("Target", held.prop, camera.CFrame.Position, camera.CFrame.LookVector)
			end
		end
		return
	end
	focused = taggedAncestor(mouse.Target)
	if not focused then panel.Visible = false; return end
	local health, maxHealth = focused:GetAttribute("Health") or 0, focused:GetAttribute("MaxHealth") or 0
	local suffix = if health < maxHealth then " <font color=\"#e9a35b\">(Damaged)</font>" else ""
	panel.Text = string.format("<b>%s</b>%s\nHealth: %d / %d   Mass: %.1f   Holders: %d\n[ E ] Grab    [ F ] Anchor", focused.Name, suffix, health, maxHealth, focused:GetAttribute("Mass") or 0, focused:GetAttribute("HolderCount") or 0)
	panel.Visible = true
end)

result.OnClientEvent:Connect(function(action, prop, ok, reason, attachment)
	if action == "Grab" and prop == pending then
		pending = nil
		if ok and attachment and attachment:IsA("Attachment") then held = { prop = prop, target = attachment }; startArm()
		elseif reason then warn("Grab rejected: " .. reason) end
	elseif action == "Broken" and held and held.prop == prop then breakGrip(ok) end
end)

local function grabAction(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if held then request:FireServer("Release", held.prop); breakGrip("Released")
	elseif focused and not pending then
		local camera = workspace.CurrentCamera
		if camera then pending = focused; request:FireServer("Grab", focused, camera.CFrame.Position, mouse.Hit.Position) end
	end
	return Enum.ContextActionResult.Sink
end

local function anchorAction(_, state)
	if state == Enum.UserInputState.Begin and focused and not held then request:FireServer("Anchor", focused, focused:GetAttribute("PropState") ~= "ANCHORED") end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("GrabProp", grabAction, false, Enum.KeyCode.E)
ContextActionService:BindAction("AnchorProp", anchorAction, false, Enum.KeyCode.F)
UserInputService.InputChanged:Connect(function(input, processed)
	if processed or not held then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then request:FireServer("Distance", held.prop, -input.Position.Z * 0.2)
	end
end)

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function() breakGrip("PlayerDied") end)
	humanoid.Seated:Connect(function(active) if active and held then request:FireServer("Release", held.prop); breakGrip("EnteredVehicle") end end)
end
player.CharacterRemoving:Connect(function() held, pending = nil, nil; clearLocalArms(); restoreCarryState() end)
player.CharacterAdded:Connect(watchCharacter)
if player.Character then task.spawn(watchCharacter, player.Character) end
