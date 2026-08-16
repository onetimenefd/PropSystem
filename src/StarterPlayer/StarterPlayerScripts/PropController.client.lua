local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("PropRemotes")
local request = remotes:WaitForChild("Request")
local result = remotes:WaitForChild("Result")
local held, pending, focused, armIK, r6Shoulder, r6Original
local rotating = false

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
	if armIK then armIK:Destroy(); armIK = nil end
	if r6Shoulder then r6Shoulder.Transform = r6Original or CFrame.identity end
	r6Shoulder, r6Original = nil, nil
end

local function startArm(target)
	clearArm()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local upperArm = character and character:FindFirstChild("RightUpperArm")
	local hand = character and character:FindFirstChild("RightHand")
	if humanoid and upperArm and hand then
		armIK = Instance.new("IKControl"); armIK.Name = "PropArmIK"; armIK.Type = Enum.IKControlType.Position
		armIK.ChainRoot = upperArm; armIK.EndEffector = hand; armIK.Target = target; armIK.SmoothTime = 0.08; armIK.Weight = 1; armIK.Parent = humanoid
	else
		local torso = character and character:FindFirstChild("Torso")
		r6Shoulder = torso and torso:FindFirstChild("Right Shoulder")
		if r6Shoulder and r6Shoulder:IsA("Motor6D") then r6Original = r6Shoulder.Transform end
	end
end

RunService.RenderStepped:Connect(function()
	if held then
		panel.Text = "<b>Holding</b>\nWheel: distance   Hold R + mouse: rotate   Q: roll\n[ E ] Release"
		panel.Visible = true
		-- R6 has one-piece arms; aim that arm at the exact replicated grab attachment.
		if r6Shoulder and r6Shoulder.Part0 and held.target and held.target.Parent then
			local origin = (r6Shoulder.Part0.CFrame * r6Shoulder.C0).Position
			local direction = held.target.WorldPosition - origin
			if direction.Magnitude > 0.01 then
				local localDirection = r6Shoulder.Part0.CFrame:VectorToObjectSpace(direction.Unit)
				r6Shoulder.Transform = CFrame.Angles(math.asin(localDirection.Y), 0, -math.atan2(localDirection.X, -localDirection.Z))
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
		if ok and attachment and attachment:IsA("Attachment") then held = { prop = prop, target = attachment }; startArm(attachment)
		elseif reason then warn("Grab rejected: " .. reason) end
	elseif action == "Broken" and held and held.prop == prop then held = nil; clearArm() end
end)

local function grabAction(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if held then request:FireServer("Release", held.prop); held = nil; clearArm()
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
		local scale = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.08 or 0.35
		request:FireServer("Rotate", held.prop, -input.Delta.Y * scale, -input.Delta.X * scale, 0)
	end
end)

player.CharacterRemoving:Connect(function() held, pending = nil, nil; clearArm() end)
