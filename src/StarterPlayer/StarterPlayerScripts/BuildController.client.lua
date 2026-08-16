local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.BuildSystem.Config)
local Definitions = require(ReplicatedStorage.BuildSystem.BuildDefinitions)
local remotes = ReplicatedStorage:WaitForChild("BuildRemotes")
local request = remotes:WaitForChild("RequestPlaceBuild")
local enabled, selected, ghost, boundary = false, "Wall", nil, nil
local rotation = Vector3.zero
remotes:WaitForChild("Result").OnClientEvent:Connect(function(ok, reason) if not ok and reason then warn("Build rejected: " .. reason) end end)

local gui = Instance.new("ScreenGui"); gui.Name = "BuildUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local plotTag = Instance.new("TextLabel"); plotTag.Name = "PlotTag"; plotTag.AnchorPoint = Vector2.new(1, 0); plotTag.Position = UDim2.new(1, -24, 0, 24); plotTag.Size = UDim2.fromOffset(260, 48)
plotTag.BackgroundTransparency = 1; plotTag.TextColor3 = Color3.fromRGB(235, 235, 235); plotTag.TextTransparency = 0.25; plotTag.TextXAlignment = Enum.TextXAlignment.Right; plotTag.Font = Enum.Font.GothamMedium; plotTag.TextSize = 15; plotTag.RichText = true; plotTag.Visible = false; plotTag.Parent = gui
local menu = Instance.new("Frame"); menu.Position = UDim2.new(0, 24, 0.5, -110); menu.Size = UDim2.fromOffset(170, 220); menu.BackgroundColor3 = Color3.fromRGB(18, 20, 24); menu.BackgroundTransparency = 0.12; menu.Visible = false; menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 8)
local layout = Instance.new("UIListLayout", menu); layout.Padding = UDim.new(0, 6); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local padding = Instance.new("UIPadding", menu); padding.PaddingTop = UDim.new(0, 10)
for _, name in { "Wall", "Floor", "Ramp", "Foundation" } do
	local button = Instance.new("TextButton"); button.Name = name; button.Size = UDim2.fromOffset(150, 42); button.Text = name; button.Font = Enum.Font.GothamMedium; button.TextSize = 15; button.TextColor3 = Color3.new(1, 1, 1); button.BackgroundColor3 = Color3.fromRGB(48, 53, 61); button.Parent = menu
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
	button.Activated:Connect(function() selected = name; rotation = Vector3.zero end)
end

local function plotAt(position)
	local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
	for _, model in plots:GetChildren() do
		local origin, size = model:GetAttribute("Origin"), model:GetAttribute("Size")
		if typeof(origin) == "Vector3" and typeof(size) == "Vector3" then
			local p, half = position - origin, size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then return model end
		end
	end
end

local function clearBoundary() if boundary then boundary:Destroy(); boundary = nil end end
local function showBoundary(plot)
	clearBoundary(); if not plot then return end
	local origin, size = plot:GetAttribute("Origin"), plot:GetAttribute("Size")
	boundary = Instance.new("Part"); boundary.Name = "LocalPlotBoundary"; boundary.Size = size; boundary.CFrame = CFrame.new(origin); boundary.Anchored = true
	boundary.CanCollide = false; boundary.CanTouch = false; boundary.CanQuery = false; boundary.Color = Color3.fromRGB(90, 170, 255); boundary.Transparency = 1; boundary.Parent = workspace
	local box = Instance.new("SelectionBox"); box.Adornee = boundary; box.LineThickness = 0.03; box.Color3 = boundary.Color; box.SurfaceTransparency = 1; box.Parent = boundary
	local floor = Instance.new("Part"); floor.Name = "FloorTint"; floor.Size = Vector3.new(size.X, 0.15, size.Z); floor.CFrame = CFrame.new(origin - Vector3.new(0, size.Y / 2, 0)); floor.Anchored = true
	floor.CanCollide = false; floor.CanTouch = false; floor.CanQuery = false; floor.Material = Enum.Material.ForceField; floor.Color = boundary.Color; floor.Transparency = 0.8; floor.Parent = boundary
end

local function ensureGhost()
	local definition = Definitions[selected]
	if ghost and ghost.Name == selected then return end
	if ghost then ghost:Destroy() end
	ghost = if definition.Ramp then Instance.new("WedgePart") else Instance.new("Part")
	ghost.Name = selected; ghost.Size = definition.Size; ghost.Color = Color3.fromRGB(100, 210, 140); ghost.Material = Enum.Material.ForceField; ghost.Transparency = 0.55; ghost.Anchored = true; ghost.CanCollide = false; ghost.CanTouch = false; ghost.CanQuery = false; ghost.Parent = workspace
end

local function setEnabled(value)
	enabled = value; menu.Visible = value
	if not value then if ghost then ghost:Destroy(); ghost = nil end; clearBoundary(); return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); showBoundary(root and plotAt(root.Position))
end

ContextActionService:BindAction("ToggleBuildMode", function(_, state)
	if state == Enum.UserInputState.Begin then setEnabled(not enabled) end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.B)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not enabled then return end
	if input.KeyCode == Enum.KeyCode.R then rotation += Vector3.new(0, Config.RotationIncrement, 0)
	elseif input.KeyCode == Enum.KeyCode.T then rotation += Vector3.new(Config.RotationIncrement, 0, 0)
	elseif input.KeyCode == Enum.KeyCode.Y then rotation += Vector3.new(0, 0, Config.RotationIncrement)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and ghost then request:FireServer(selected, ghost.CFrame)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then if ghost then ghost:Destroy(); ghost = nil end; selected = "Wall" end
end)

RunService.RenderStepped:Connect(function()
	if not enabled then return end
	ensureGhost()
	local camera = workspace.CurrentCamera; if not camera then return end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { player.Character, ghost, boundary }
	local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * Config.PlacementRange, params)
	local position = hit and hit.Position or camera.CFrame.Position + camera.CFrame.LookVector * 12
	if hit then
		local half, normal = ghost.Size / 2, hit.Normal
		local support = math.abs(ghost.CFrame.RightVector:Dot(normal)) * half.X + math.abs(ghost.CFrame.UpVector:Dot(normal)) * half.Y + math.abs(ghost.CFrame.LookVector:Dot(normal)) * half.Z
		position += normal * (support + 0.05)
	end
	position = Vector3.new(math.round(position.X / Config.GridSize) * Config.GridSize, math.round(position.Y / Config.GridSize) * Config.GridSize, math.round(position.Z / Config.GridSize) * Config.GridSize)
	ghost.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end)

task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local plot = root and plotAt(root.Position)
		plotTag.Visible = plot ~= nil
		if plot then
			local trusted = plot:GetAttribute("Trusted_" .. player.UserId) == true
			plotTag.Text = string.upper(plot:GetAttribute("OwnerName") or "PLAYER") .. "'S PLOT" .. (if trusted then "\n<font color=\"#8ed6a5\">TRUSTED</font>" else "")
		end
		task.wait(0.25)
	end
end)
