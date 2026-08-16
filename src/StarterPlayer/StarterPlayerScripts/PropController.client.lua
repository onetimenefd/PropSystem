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
local held, pending, focused, carryArm, shoulderAttachment, hiddenArm
local previousCameraMode, previousAutoRotate
local rotating, lastTargetUpdate = false, 0

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

local function clearArm()
	if carryArm then carryArm:Destroy(); carryArm = nil end
	if shoulderAttachment then shoulderAttachment:Destroy(); shoulderAttachment = nil end
	if hiddenArm then hiddenArm.LocalTransparencyModifier = 0; hiddenArm = nil end
end

local function restoreCarryState()
	clearArm()
	if previousCameraMode then player.CameraMode = previousCameraMode; previousCameraMode = nil end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and previousAutoRotate ~= nil then humanoid.AutoRotate = previousAutoRotate end
	previousAutoRotate = nil
end

local function breakGrip(reason)
	if not held then return end
	held = nil
	restoreCarryState()
	if reason and reason ~= "Released" then warn("Grip ended: " .. reason) end
end

local function startArm(side)
	clearArm()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and character:FindFirstChild("Torso")
	hiddenArm = character and character:FindFirstChild(side .. " Arm")
	if humanoid then
		previousCameraMode = player.CameraMode
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		previousAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
	end
	if humanoid and torso and torso:IsA("BasePart") and hiddenArm and hiddenArm:IsA("BasePart") then
		shoulderAttachment = Instance.new("Attachment")
		shoulderAttachment.Name = side .. "ShoulderGripOrigin"
		shoulderAttachment.Position = Vector3.new(if side == "Left" then -1.5 else 1.5, 0.5, 0)
		shoulderAttachment.Parent = torso
		carryArm = hiddenArm:Clone()
		carryArm.Name = side .. "CarryArm"; carryArm.Anchored = true; carryArm.CanCollide = false; carryArm.CanTouch = false; carryArm.CanQuery = false
		for _, child in carryArm:GetChildren() do if child:IsA("JointInstance") or child:IsA("Attachment") then child:Destroy() end end
		carryArm.Parent = character
		hiddenArm.LocalTransparencyModifier = 1
	end
end

RunService.RenderStepped:Connect(function()
	if held then
		panel.Text = "<b>Holding</b>\nWheel: distance   Hold R + mouse: rotate   Q: roll\n[ E ] Release"
		panel.Visible = true
		if not held.target.Parent then breakGrip("PropDestroyed"); return end
		if carryArm and shoulderAttachment then
			local shoulderPos, gripPos = shoulderAttachment.WorldPosition, held.target.WorldPosition
			local delta = gripPos - shoulderPos
			if delta.Magnitude > 0.01 then
				carryArm.Size = Vector3.new(carryArm.Size.X, math.min(delta.Magnitude + Config.ArmOverlap * 2, Config.BreakDistance + Config.ArmOverlap * 2), carryArm.Size.Z)
				carryArm.CFrame = CFrame.lookAt(shoulderPos:Lerp(gripPos, 0.5), gripPos) * CFrame.Angles(math.pi / 2, 0, 0)
			end
		end
		local camera, character = workspace.CurrentCamera, player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if camera and root and root:IsA("BasePart") then
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

result.OnClientEvent:Connect(function(action, prop, ok, reason, attachment, side)
	if action == "Grab" and prop == pending then
		pending = nil
		if ok and attachment and attachment:IsA("Attachment") then held = { prop = prop, target = attachment }; startArm(side or "Right")
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
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not held then return end
	if input.KeyCode == Enum.KeyCode.R then rotating = true
	elseif input.KeyCode == Enum.KeyCode.Q then request:FireServer("Rotate", held.prop, 0, 0, UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and -2 or -8) end
end)
UserInputService.InputEnded:Connect(function(input) if input.KeyCode == Enum.KeyCode.R then rotating = false end end)
UserInputService.InputChanged:Connect(function(input, processed)
	if processed or not held then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then request:FireServer("Distance", held.prop, -input.Position.Z * 0.2)
	elseif rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
		local scale = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.08 or Config.RotationSensitivity
		request:FireServer("Rotate", held.prop, -input.Delta.Y * scale, -input.Delta.X * scale, 0)
	end
end)

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function() breakGrip("PlayerDied") end)
	humanoid.Seated:Connect(function(active) if active and held then request:FireServer("Release", held.prop); breakGrip("EnteredVehicle") end end)
end
player.CharacterRemoving:Connect(function() held, pending = nil, nil; restoreCarryState() end)
player.CharacterAdded:Connect(watchCharacter)
if player.Character then task.spawn(watchCharacter, player.Character) end
