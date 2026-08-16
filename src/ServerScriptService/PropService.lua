--!strict

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.PropSystem.Config)

type Grip = {
	player: Player,
	grab: Attachment,
	target: Attachment,
	position: AlignPosition,
	orientation: AlignOrientation,
	noCollisionConstraints: { NoCollisionConstraint },
	arms: { CarryArm },
	originalWalkSpeed: number?,
	createdAt: number,
	side: string,
	holdDistance: number,
}

type CarryArm = {
	part: BasePart,
	shoulder: Attachment,
	bodyArm: BasePart,
	transparency: number,
	side: string,
}

export type PropRecord = {
	source: Instance,
	instance: BasePart,
	objectID: string,
	health: number,
	maxHealth: number,
	mass: number,
	state: string,
	grips: { [Player]: Grip },
}

local PropService = {}
local PlotService: any = nil
local registry: { [string]: PropRecord } = {}
local byInstance: { [Instance]: PropRecord } = {}
local heldByPlayer: { [Player]: PropRecord } = {}
local gripEnded = Instance.new("BindableEvent")
PropService.GripEnded = gripEnded.Event

local function resolvePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then return instance end
	if instance:IsA("Model") then return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function setReplicatedState(record: PropRecord)
	record.state = if next(record.grips) then "HELD" elseif record.instance.Anchored then "ANCHORED" else "LOOSE"
	local holders = 0
	for _ in record.grips do holders += 1 end
	for _, instance in { record.source, record.instance } do
		instance:SetAttribute("ObjectID", record.objectID)
		instance:SetAttribute("Health", record.health)
		instance:SetAttribute("PropState", record.state)
		instance:SetAttribute("HolderCount", holders)
	end
end

local function removeGrip(record: PropRecord, player: Player, reason: string): boolean
	local grip = record.grips[player]
	if not grip then return false end
	for _, item in grip.noCollisionConstraints do item:Destroy() end
	for _, arm in grip.arms do
		arm.part:Destroy()
		arm.shoulder:Destroy()
		if arm.bodyArm.Parent then arm.bodyArm.Transparency = arm.transparency end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and grip.originalWalkSpeed then humanoid.WalkSpeed = grip.originalWalkSpeed end
	for _, item in { grip.position, grip.orientation, grip.grab, grip.target } do item:Destroy() end
	record.grips[player] = nil
	heldByPlayer[player] = nil
	if next(record.grips) == nil then record.instance:SetNetworkOwnershipAuto() end
	setReplicatedState(record)
	gripEnded:Fire(player, record.source, reason)
	return true
end

local function createCarryArm(character: Model, side: string, ownerUserId: number): CarryArm?
	local torso = character:FindFirstChild("Torso")
	local bodyArm = character:FindFirstChild(side .. " Arm")
	if not torso or not torso:IsA("BasePart") or not bodyArm or not bodyArm:IsA("BasePart") then return nil end
	local shoulder = Instance.new("Attachment")
	shoulder.Name = side .. "ShoulderGripOrigin"
	shoulder.Position = Vector3.new(if side == "Left" then -1.5 else 1.5, 0.5, 0)
	shoulder.Parent = torso
	local arm = bodyArm:Clone()
	-- Preserve the canonical R6 part name so classic Shirt textures apply to the clone.
	arm.Name = bodyArm.Name; arm.Anchored = true; arm.CanCollide = false; arm.CanTouch = false; arm.CanQuery = false
	arm:SetAttribute("PropCarryArm", true); arm:SetAttribute("OwnerUserId", ownerUserId); arm:SetAttribute("GripSide", side)
	for _, child in arm:GetChildren() do if child:IsA("JointInstance") or child:IsA("Attachment") then child:Destroy() end end
	arm.Parent = character
	local transparency = bodyArm.Transparency
	bodyArm.Transparency = 1
	return { part = arm, shoulder = shoulder, bodyArm = bodyArm, transparency = transparency, side = side }
end

local function isHeavy(record: PropRecord): boolean
	local classification = record.source:GetAttribute("Classification")
	return record.source:GetAttribute("Heavy") == true
		or (typeof(classification) == "string" and string.lower(classification) == "heavy")
		or record.mass >= Config.HeavyMass
end

local function removeCarryArm(grip: Grip, side: string)
	for index = #grip.arms, 1, -1 do
		local arm = grip.arms[index]
		if arm.side == side then
			arm.part:Destroy(); arm.shoulder:Destroy()
			if arm.bodyArm.Parent then arm.bodyArm.Transparency = arm.transparency end
			table.remove(grip.arms, index)
		end
	end
end

function PropService:Register(instance: Instance): PropRecord?
	local part = resolvePart(instance)
	if not part then warn(`Cannot register Prop {instance:GetFullName()}: no BasePart`); return nil end
	if byInstance[instance] or byInstance[part] then return byInstance[instance] or byInstance[part] end
	local maxHealth = math.max(1, tonumber(instance:GetAttribute("MaxHealth")) or 100)
	local record: PropRecord = {
		source = instance, instance = part,
		objectID = "prop_" .. string.sub(HttpService:GenerateGUID(false):gsub("%-", ""), 1, 12),
		health = maxHealth, maxHealth = maxHealth,
		mass = math.max(0.1, tonumber(instance:GetAttribute("Mass")) or part.AssemblyMass),
		state = "LOOSE", grips = {},
	}
	registry[record.objectID] = record
	byInstance[instance], byInstance[part] = record, record
	for _, item in { instance, part } do
		item:SetAttribute("AssetKey", instance:GetAttribute("AssetKey") or instance.Name)
		item:SetAttribute("MaxHealth", maxHealth); item:SetAttribute("Mass", record.mass)
	end
	setReplicatedState(record)
	return record
end

function PropService:Get(objectID: string): BasePart? local r = registry[objectID]; return if r then r.instance else nil end
function PropService:GetRecord(prop: Instance): PropRecord? return byInstance[prop] end
function PropService:GetHeldSide(player: Player): string?
	local record = heldByPlayer[player]
	local grip = record and record.grips[player]
	return if grip then grip.side else nil
end

function PropService:DisableRightArm(player: Player): boolean
	local record = heldByPlayer[player]
	local grip = record and record.grips[player]
	if not grip then return false end
	local hadRight = false
	for _, arm in grip.arms do if arm.side == "Right" then hadRight = true end end
	if not hadRight then return false end
	removeCarryArm(grip, "Right")
	if #grip.arms == 0 then return removeGrip(record, player, "ToolEquipped") end
	grip.side = "Left"
	return true
end

function PropService:Grab(player: Player, prop: Instance, rayOrigin: Vector3, hitPoint: Vector3): (boolean, string?, Attachment?, string?)
	local record = byInstance[prop]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not record or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then return false, "Invalid prop or character" end
	if heldByPlayer[player] then return false, "Already holding a prop" end
	if record.instance.Anchored then return false, "Prop is anchored" end
	if (rayOrigin - head.Position).Magnitude > 3 or (hitPoint - rayOrigin).Magnitude > Config.GrabDistance then return false, "Prop is too far away" end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(rayOrigin, hitPoint - rayOrigin, params)
	if not result or (result.Instance ~= record.instance and not result.Instance:IsDescendantOf(record.source)) or (result.Position - hitPoint).Magnitude > Config.GrabPointTolerance then
		return false, "Invalid grab point"
	end

	local suffix = tostring(player.UserId)
	local hasEquippedTool = character:FindFirstChildWhichIsA("Tool") ~= nil
	local side = if hasEquippedTool then "Left" elseif root.CFrame:PointToObjectSpace(result.Position).X < 0 then "Left" else "Right"
	local target = Instance.new("Attachment")
	target.Name = "PropHoldTarget_" .. suffix; target.Position = Vector3.new(0, 0, -Config.DefaultHoldDistance); target.Parent = root
	local grab = Instance.new("Attachment")
	grab.Name = "PropGrabPoint_" .. suffix; grab.Position = record.instance.CFrame:PointToObjectSpace(result.Position); grab.Parent = record.instance
	local alpha = math.clamp(record.mass / Config.HeavyMass, 0, 1)
	local responsiveness = Config.LightResponsiveness + (Config.HeavyResponsiveness - Config.LightResponsiveness) * alpha
	local force = Config.BaseForce + math.sqrt(record.mass) * Config.ForcePerMass
	local position = Instance.new("AlignPosition")
	position.Name = "PropGrabPosition"; position.Attachment0 = grab; position.Attachment1 = target
	position.MaxForce = force; position.Responsiveness = responsiveness; position.ApplyAtCenterOfMass = false; position.Parent = record.instance
	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "PropGrabOrientation"; orientation.Attachment0 = grab; orientation.Attachment1 = target
	orientation.MaxTorque = record.mass * Config.MaxTorquePerMass; orientation.Responsiveness = responsiveness; orientation.Parent = record.instance
	local noCollisionConstraints = {}
	local propParts = if record.source:IsA("BasePart") then { record.source } else record.source:GetDescendants()
	for _, propPart in propParts do
		if not propPart:IsA("BasePart") then continue end
		for _, characterPart in character:GetDescendants() do
			if not characterPart:IsA("BasePart") then continue end
			local constraint = Instance.new("NoCollisionConstraint")
			constraint.Name = "PropHolderNoCollision"
			constraint.Part0 = propPart
			constraint.Part1 = characterPart
			constraint.Parent = propPart
			table.insert(noCollisionConstraints, constraint)
		end
	end
	local arms = {}
	local sides = if isHeavy(record) and not hasEquippedTool then { "Left", "Right" } else { side }
	for _, armSide in sides do
		local arm = createCarryArm(character, armSide, player.UserId)
		if arm then table.insert(arms, arm) end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local originalWalkSpeed = humanoid and humanoid.WalkSpeed or nil
	if humanoid and isHeavy(record) then
		local alpha = math.clamp((record.mass - Config.HeavyMass) / math.max(1, Config.HeavyMaxSlowMass - Config.HeavyMass), 0, 1)
		local scale = Config.HeavyWalkSpeedScale + (Config.MinimumWalkSpeedScale - Config.HeavyWalkSpeedScale) * alpha
		humanoid.WalkSpeed = humanoid.WalkSpeed * scale
	end
	record.grips[player] = {
		player = player, grab = grab, target = target, position = position, orientation = orientation,
		noCollisionConstraints = noCollisionConstraints, arms = arms, originalWalkSpeed = originalWalkSpeed,
		createdAt = os.clock(), side = side, holdDistance = Config.DefaultHoldDistance,
	}
	heldByPlayer[player] = record
	-- Roblox permits one owner per assembly; the first holder owns it while additional
	-- server constraints still contribute force.
	if next(record.grips) == player then record.instance:SetNetworkOwner(player) end
	setReplicatedState(record)
	return true, nil, grab, side
end

function PropService:Release(player: Player, prop: Instance, reason: string?): boolean local r = byInstance[prop]; return if r then removeGrip(r, player, reason or "Released") else false end

function PropService:SetPlotService(service: any) PlotService = service end

function PropService:SetAnchored(player: Player, prop: Instance, anchored: boolean): (boolean, string?)
	local r = byInstance[prop]; if not r or next(r.grips) then return false, "Prop cannot be anchored right now" end
	local allowed, plot = PlotService:CanModifyAt(player, r.instance.Position)
	if not allowed then return false, "You are not trusted on this plot" end
	if plot then
		r.source:SetAttribute("PlotOwner", plot.OwnerUserId); r.source:SetAttribute("PlacedBy", player.UserId)
		r.instance:SetAttribute("PlotOwner", plot.OwnerUserId); r.instance:SetAttribute("PlacedBy", player.UserId)
	elseif anchored then
		r.source:SetAttribute("PlotOwner", nil); r.instance:SetAttribute("PlotOwner", nil)
	end
	r.instance.Anchored = anchored; setReplicatedState(r); return true
end

function PropService:AdjustHold(player: Player, prop: Instance, delta: number): boolean
	local r = byInstance[prop]; local grip = r and r.grips[player]; if not grip then return false end
	local distance = math.clamp(grip.holdDistance + delta, Config.MinHoldDistance, Config.MaxHoldDistance)
	grip.holdDistance = distance; return true
end

function PropService:UpdateTarget(player: Player, prop: Instance, cameraPosition: Vector3, lookVector: Vector3): boolean
	local r = byInstance[prop]; local grip = r and r.grips[player]
	local character = player.Character; local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not grip or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then return false end
	if (cameraPosition - head.Position).Magnitude > 3 or lookVector.Magnitude < 0.9 then return false end
	local shoulderOffset = Vector3.new(if grip.side == "Left" then -1.5 else 1.5, 0.5, 0)
	local shoulder = (root.CFrame * CFrame.new(shoulderOffset)).Position
	local desired = cameraPosition + lookVector.Unit * grip.holdDistance
	desired = Vector3.new(desired.X, math.clamp(desired.Y, shoulder.Y + Config.MinTargetHeightFromShoulder, shoulder.Y + Config.MaxTargetHeightFromShoulder), desired.Z)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, r.source }
	local ground = workspace:Raycast(desired + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)
	if ground then desired = Vector3.new(desired.X, math.max(desired.Y, ground.Position.Y + 0.2), desired.Z) end
	local delta = desired - shoulder
	if delta.Magnitude > Config.BreakDistance - 0.1 then desired = shoulder + delta.Unit * (Config.BreakDistance - 0.1) end
	-- Only update the target's local position. Keeping its local orientation at the
	-- identity makes the prop turn with the character instead of holding a fixed
	-- world-space rotation as the character turns.
	grip.target.Position = root.CFrame:PointToObjectSpace(desired)
	return true
end

function PropService:Damage(prop: Instance, amount: number): boolean
	local r = byInstance[prop]; if not r or amount <= 0 then return false end
	r.health = math.max(0, r.health - amount); setReplicatedState(r); if r.health <= 0 then self:Break(prop) end; return true
end

function PropService:Break(prop: Instance): boolean
	local r = byInstance[prop]; if not r then return false end
	for player in r.grips do removeGrip(r, player, "PropDestroyed") end
	registry[r.objectID] = nil
	for instance, candidate in byInstance do if candidate == r then byInstance[instance] = nil end end
	r.source:Destroy(); return true
end

function PropService:ReleaseAll(player: Player, reason: string?) local r = heldByPlayer[player]; if r then removeGrip(r, player, reason or "Interrupted") end end

function PropService:Start()
	for _, instance in CollectionService:GetTagged("Prop") do self:Register(instance) end
	CollectionService:GetInstanceAddedSignal("Prop"):Connect(function(instance) self:Register(instance) end)
	RunService.Heartbeat:Connect(function()
		for _, record in registry do
			for player, grip in record.grips do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local shoulder = root and root:IsA("BasePart") and (root.CFrame * CFrame.new(if grip.side == "Left" then -1.5 else 1.5, 0.5, 0)).Position
				for _, arm in grip.arms do
					local shoulderPosition, gripPosition = arm.shoulder.WorldPosition, grip.grab.WorldPosition
					local delta = gripPosition - shoulderPosition
					if delta.Magnitude > 0.01 then
						arm.part.Size = Vector3.new(arm.part.Size.X, math.min(delta.Magnitude + Config.ArmOverlap * 2, Config.BreakDistance + Config.ArmOverlap * 2), arm.part.Size.Z)
						arm.part.CFrame = CFrame.lookAt(shoulderPosition:Lerp(gripPosition, 0.5), gripPosition) * CFrame.Angles(math.pi / 2, 0, 0)
					end
				end
				if not player.Parent or not grip.target.Parent or not grip.grab.Parent then removeGrip(record, player, "InvalidGrip")
				elseif not humanoid or humanoid.Health <= 0 then removeGrip(record, player, "PlayerDied")
				elseif record.instance.Anchored then removeGrip(record, player, "PropAnchored")
				elseif shoulder and os.clock() - grip.createdAt > Config.BreakGracePeriod and (grip.grab.WorldPosition - shoulder).Magnitude > Config.BreakDistance then removeGrip(record, player, "Overextended") end
			end
		end
	end)
end

return PropService
