local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remoteFolder = ReplicatedStorage:WaitForChild("PropRemotes")
local request = remoteFolder:FindFirstChild("Request")
while not request or not request:IsA("RemoteEvent") do
	request = remoteFolder.ChildAdded:Wait()
	if request.Name ~= "Request" then
		request = remoteFolder:FindFirstChild("Request")
	end
end
local held = nil
local focused = nil
local armIK = nil

local gui = Instance.new("ScreenGui")
gui.Name = "PropInfo"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("TextLabel")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.fromScale(0.5, 0.86)
panel.Size = UDim2.fromOffset(280, 112)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
panel.BackgroundTransparency = 0.12
panel.TextColor3 = Color3.new(1, 1, 1)
panel.Font = Enum.Font.GothamMedium
panel.TextSize = 16
panel.RichText = true
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local function taggedAncestor(instance)
	while instance and instance ~= workspace do
		if CollectionService:HasTag(instance, "Prop") or instance:GetAttribute("ObjectID") then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	if held then
		panel.Visible = false
		return
	end
	focused = taggedAncestor(mouse.Target)
	if not focused then
		panel.Visible = false
		return
	end
	local health = focused:GetAttribute("Health") or 0
	local maxHealth = focused:GetAttribute("MaxHealth") or 0
	local suffix = if health < maxHealth then " <font color=\"#e9a35b\">(Damaged)</font>" else ""
	panel.Text = string.format("<b>%s</b>%s\nHealth: %d / %d\nMass: %.1f\n\n[ E ] Grab    [ F ] Anchor", focused.Name, suffix, health, maxHealth, focused:GetAttribute("Mass") or 0)
	panel.Visible = true
end)

local function handleAction(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if held then
		request:FireServer("Release", held)
		if armIK then
			armIK:Destroy()
			armIK = nil
		end
		held = nil
	elseif focused then
		request:FireServer("Grab", focused, mouse.Hit.Position)
		held = focused
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local upperArm = character and character:FindFirstChild("RightUpperArm")
		local hand = character and character:FindFirstChild("RightHand")
		local grabPoint = focused:FindFirstChild("PropGrabPoint", true)
		if humanoid and upperArm and hand and grabPoint and grabPoint:IsA("Attachment") then
			armIK = Instance.new("IKControl")
			armIK.Name = "PropArmIK"
			armIK.Type = Enum.IKControlType.Position
			armIK.ChainRoot = upperArm
			armIK.EndEffector = hand
			armIK.Target = grabPoint
			armIK.SmoothTime = 0.12
			armIK.Weight = 0.85
			armIK.Parent = humanoid
		end
	end
	return Enum.ContextActionResult.Sink
end

local function anchorAction(_, inputState)
	if inputState == Enum.UserInputState.Begin and focused and not held then
		request:FireServer("Anchor", focused, focused:GetAttribute("PropState") ~= "ANCHORED")
	end
	return Enum.ContextActionResult.Sink
end

local function rotateAction(_, inputState)
	if inputState == Enum.UserInputState.Begin and held then
		request:FireServer("Rotate", held, 15)
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("GrabProp", handleAction, false, Enum.KeyCode.E)
ContextActionService:BindAction("AnchorProp", anchorAction, false, Enum.KeyCode.F)
ContextActionService:BindAction("RotateProp", rotateAction, false, Enum.KeyCode.R)
