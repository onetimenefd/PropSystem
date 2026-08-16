--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BuildSystem.Config)

export type Plot = {
	OwnerUserId: number,
	OwnerName: string,
	Origin: Vector3,
	CFrame: CFrame,
	Size: Vector3,
	Trusted: { [number]: boolean },
	Builds: { Instance },
	model: Model,
}

local PlotService = {}
local plots: { [number]: Plot } = {}
local folder = workspace:FindFirstChild("Plots") :: Folder?
if not folder then folder = Instance.new("Folder"); folder.Name = "Plots"; folder.Parent = workspace end

local function snap(position: Vector3): Vector3
	return Vector3.new(math.round(position.X), math.round(position.Y), math.round(position.Z))
end

local function overlaps(originA: Vector3, sizeA: Vector3, originB: Vector3, sizeB: Vector3): boolean
	local distance = originA - originB
	local half = (sizeA + sizeB) / 2
	return math.abs(distance.X) < half.X and math.abs(distance.Y) < half.Y and math.abs(distance.Z) < half.Z
end

function PlotService:GetPlotForPlayer(player: Player): Plot? return plots[player.UserId] end

function PlotService:GetPlotAtPosition(position: Vector3): Plot?
	for _, plot in plots do
		local localPosition = plot.CFrame:PointToObjectSpace(position)
		local half = plot.Size / 2
		if math.abs(localPosition.X) <= half.X and math.abs(localPosition.Y) <= half.Y and math.abs(localPosition.Z) <= half.Z then return plot end
	end
	return nil
end

function PlotService:CanBuild(player: Player, plot: Plot): boolean
	return player.UserId == plot.OwnerUserId or plot.Trusted[player.UserId] == true
end

function PlotService:CanModifyAt(player: Player, position: Vector3): (boolean, Plot?)
	local plot = self:GetPlotAtPosition(position)
	return plot == nil or self:CanBuild(player, plot), plot
end

function PlotService:ContainsBox(plot: Plot, boxCFrame: CFrame, boxSize: Vector3): boolean
	local half = boxSize / 2
	for _, x in { -half.X, half.X } do for _, y in { -half.Y, half.Y } do for _, z in { -half.Z, half.Z } do
		if self:GetPlotAtPosition((boxCFrame * CFrame.new(x, y, z)).Position) ~= plot then return false end
	end end end
	return true
end

function PlotService:Create(player: Player): (boolean, string?)
	if plots[player.UserId] then return false, "You already have a plot" end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false, "Character is not ready" end
	local origin = snap(root.Position)
	for _, plot in plots do if overlaps(origin, Config.PlotSize, plot.Origin, plot.Size) then return false, "That plot would overlap an existing plot" end end
	local model = Instance.new("Model"); model.Name = "Plot_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId); model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("Origin", origin); model:SetAttribute("Size", Config.PlotSize); model.Parent = folder
	local plot: Plot = { OwnerUserId = player.UserId, OwnerName = player.DisplayName, Origin = origin, CFrame = CFrame.new(origin), Size = Config.PlotSize, Trusted = {}, Builds = {}, model = model }
	plots[player.UserId] = plot
	return true
end

function PlotService:Remove(player: Player): (boolean, string?)
	local plot = plots[player.UserId]
	if not plot then return false, "You do not have a plot" end
	for _, child in workspace:GetDescendants() do
		if child:GetAttribute("PlotOwner") == player.UserId and (child:IsA("Model") or child:IsA("BasePart")) then
			local parent = child.Parent
			if not parent or parent:GetAttribute("PlotOwner") ~= player.UserId then child:Destroy() end
		end
	end
	plots[player.UserId] = nil; plot.model:Destroy()
	return true
end

function PlotService:SetTrusted(owner: Player, target: Player, trusted: boolean): (boolean, string?)
	local plot = plots[owner.UserId]
	if not plot then return false, "Create a plot first" end
	if owner == target then return false, "You already own this plot" end
	plot.Trusted[target.UserId] = if trusted then true else nil
	plot.model:SetAttribute("Trusted_" .. target.UserId, if trusted then true else nil)
	return true
end

function PlotService:ClearTrusted(owner: Player): (boolean, string?)
	local plot = plots[owner.UserId]; if not plot then return false, "Create a plot first" end
	for userId in plot.Trusted do plot.model:SetAttribute("Trusted_" .. userId, nil) end
	table.clear(plot.Trusted); return true
end

function PlotService:AddBuild(plot: Plot, build: Instance) table.insert(plot.Builds, build) end
function PlotService:GetBuildCount(plot: Plot): number
	local count = 0; for _, build in plot.Builds do if build.Parent then count += 1 end end; return count
end

Players.PlayerRemoving:Connect(function(player) PlotService:Remove(player) end)
return PlotService
