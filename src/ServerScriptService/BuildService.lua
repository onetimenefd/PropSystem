--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService = require(script.Parent.PlotService)
local Config = require(ReplicatedStorage.BuildSystem.Config)
local Definitions = require(ReplicatedStorage.BuildSystem.BuildDefinitions)

local BuildService = {}
local folder = workspace:FindFirstChild("PlotBuilds") :: Folder?
if not folder then folder = Instance.new("Folder"); folder.Name = "PlotBuilds"; folder.Parent = workspace end

function BuildService:Place(player: Player, buildType: any, desiredCFrame: any): (boolean, string?)
	if typeof(buildType) ~= "string" or typeof(desiredCFrame) ~= "CFrame" then return false, "Invalid placement request" end
	local position = desiredCFrame.Position
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then return false, "Invalid placement coordinates" end
	local snapped = Vector3.new(math.round(position.X / Config.GridSize) * Config.GridSize, math.round(position.Y / Config.GridSize) * Config.GridSize, math.round(position.Z / Config.GridSize) * Config.GridSize)
	if (position - snapped).Magnitude > 0.01 then return false, "Placement must be grid-aligned" end
	local increment = math.rad(Config.RotationIncrement)
	local rx, ry, rz = desiredCFrame:ToOrientation()
	local function isSnapped(angle: number): boolean return math.abs(angle / increment - math.round(angle / increment)) < 0.001 end
	if not isSnapped(rx) or not isSnapped(ry) or not isSnapped(rz) then return false, "Rotation must be snapped" end
	local definition = Definitions[buildType]
	if not definition then return false, "Unknown build type" end
	local plot = PlotService:GetPlotAtPosition(desiredCFrame.Position)
	if not plot or not PlotService:CanBuild(player, plot) then return false, "You cannot build here" end
	if PlotService:GetBuildCount(plot) >= Config.MaxBuildsPerPlot then return false, "Plot build limit reached" end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - desiredCFrame.Position).Magnitude > Config.PlacementRange then return false, "Placement is too far away" end
	if not PlotService:ContainsBox(plot, desiredCFrame, definition.Size) then return false, "The entire build must be inside the plot" end
	local overlap = OverlapParams.new(); overlap.FilterType = Enum.RaycastFilterType.Exclude; overlap.FilterDescendantsInstances = { player.Character }
	if #workspace:GetPartBoundsInBox(desiredCFrame, definition.Size - Vector3.new(0.1, 0.1, 0.1), overlap) > 0 then return false, "Placement overlaps the world" end
	local part: BasePart
	if definition.Ramp then
		local wedge = Instance.new("WedgePart"); wedge.Size = definition.Size; part = wedge
	else
		local block = Instance.new("Part"); block.Size = definition.Size; part = block
	end
	part.Name = buildType; part.CFrame = desiredCFrame; part.Color = definition.Color; part.Material = Enum.Material.WoodPlanks
	part.Anchored = true; part:SetAttribute("BuildType", buildType); part:SetAttribute("PlotOwner", plot.OwnerUserId); part:SetAttribute("PlacedBy", player.UserId); part.Parent = folder
	PlotService:AddBuild(plot, part)
	return true
end
return BuildService
