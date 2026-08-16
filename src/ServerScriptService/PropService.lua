--!strict

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.PropSystem.Config)

export type PropRecord = {
	source: Instance,
	instance: BasePart,
	objectID: string,
	health: number,
	maxHealth: number,
	mass: number,
	state: string,
	holder: Player?,
	holdAttachment: Attachment?,
	targetAttachment: Attachment?,
	alignPosition: AlignPosition?,
	alignOrientation: AlignOrientation?,
}

local PropService = {}
local registry: { [string]: PropRecord } = {}
local byInstance: { [Instance]: PropRecord } = {}

local function resolvePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function cleanupConstraints(record: PropRecord)
	for _, item in { record.alignPosition, record.alignOrientation, record.holdAttachment, record.targetAttachment } do
		if item then
			item:Destroy()
		end
	end
	record.alignPosition = nil
	record.alignOrientation = nil
	record.holdAttachment = nil
	record.targetAttachment = nil
end

local function setReplicatedState(record: PropRecord)
	for _, instance in { record.source, record.instance } do
		instance:SetAttribute("ObjectID", record.objectID)
		instance:SetAttribute("Health", record.health)
		instance:SetAttribute("PropState", record.state)
	end
end

function PropService:Register(instance: Instance): PropRecord?
	local part = resolvePart(instance)
	if not part then
		warn(`Cannot register Prop {instance:GetFullName()}: no BasePart`)
		return nil
	end
	if byInstance[instance] or byInstance[part] then
		return byInstance[instance] or byInstance[part]
	end

	local maxHealth = math.max(1, tonumber(instance:GetAttribute("MaxHealth")) or 100)
	local configuredMass = tonumber(instance:GetAttribute("Mass"))
	local record: PropRecord = {
		source = instance,
		instance = part,
		objectID = "prop_" .. string.sub(HttpService:GenerateGUID(false):gsub("%-", ""), 1, 12),
		health = maxHealth,
		maxHealth = maxHealth,
		mass = math.max(0.1, configuredMass or part.AssemblyMass),
		state = if part.Anchored then "ANCHORED" else "LOOSE",
		holder = nil,
		holdAttachment = nil,
		targetAttachment = nil,
		alignPosition = nil,
		alignOrientation = nil,
	}

	registry[record.objectID] = record
	byInstance[instance] = record
	byInstance[part] = record
	for _, replicatedInstance in { instance, part } do
		replicatedInstance:SetAttribute("AssetKey", instance:GetAttribute("AssetKey") or instance.Name)
		replicatedInstance:SetAttribute("MaxHealth", maxHealth)
		replicatedInstance:SetAttribute("Mass", record.mass)
	end
	setReplicatedState(record)
	return record
end

function PropService:Get(objectID: string): BasePart?
	local record = registry[objectID]
	return if record then record.instance else nil
end

function PropService:GetRecord(prop: Instance): PropRecord?
	return byInstance[prop]
end

function PropService:Grab(player: Player, prop: Instance, hitPoint: Vector3): (boolean, string?)
	local record = byInstance[prop]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not record or not root or not root:IsA("BasePart") then
		return false, "Invalid prop or character"
	end
	if record.state ~= "LOOSE" or record.instance.Anchored then
		return false, "Prop is unavailable"
	end
	if (hitPoint - record.instance.Position).Magnitude > record.instance.Size.Magnitude then
		return false, "Invalid grab point"
	end
	if (hitPoint - root.Position).Magnitude > Config.GrabDistance then
		return false, "Prop is too far away"
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(root.Position, hitPoint - root.Position, rayParams)
	if result and result.Instance ~= record.instance and not result.Instance:IsDescendantOf(prop) then
		return false, "Line of sight is blocked"
	end

	local target = Instance.new("Attachment")
	target.Name = "PropHoldTarget"
	target.Position = Vector3.new(0, 0, -Config.HoldDistance)
	target.Parent = root
	local held = Instance.new("Attachment")
	held.Name = "PropGrabPoint"
	held.Position = record.instance.CFrame:PointToObjectSpace(hitPoint)
	held.Parent = record.instance

	local responsivenessAlpha = math.clamp(record.mass / Config.HeavyMass, 0, 1)
	local responsiveness = Config.LightResponsiveness + (Config.HeavyResponsiveness - Config.LightResponsiveness) * responsivenessAlpha
	local position = Instance.new("AlignPosition")
	position.Attachment0 = held
	position.Attachment1 = target
	position.MaxForce = record.mass * Config.MaxForcePerMass
	position.Responsiveness = responsiveness
	position.ApplyAtCenterOfMass = false
	position.Parent = record.instance
	local orientation = Instance.new("AlignOrientation")
	orientation.Attachment0 = held
	orientation.Attachment1 = target
	orientation.MaxTorque = record.mass * Config.MaxForcePerMass
	orientation.Responsiveness = responsiveness
	orientation.Parent = record.instance

	record.holder = player
	record.holdAttachment = held
	record.targetAttachment = target
	record.alignPosition = position
	record.alignOrientation = orientation
	record.state = "HELD"
	record.instance:SetNetworkOwner(player)
	setReplicatedState(record)
	return true
end

function PropService:Release(player: Player, prop: Instance): boolean
	local record = byInstance[prop]
	if not record or record.holder ~= player then
		return false
	end
	cleanupConstraints(record)
	record.holder = nil
	record.state = "LOOSE"
	record.instance:SetNetworkOwnershipAuto()
	setReplicatedState(record)
	return true
end

function PropService:SetAnchored(prop: Instance, anchored: boolean): boolean
	local record = byInstance[prop]
	if not record or record.state == "HELD" then
		return false
	end
	record.instance.Anchored = anchored
	record.state = if anchored then "ANCHORED" else "LOOSE"
	setReplicatedState(record)
	return true
end

function PropService:Rotate(player: Player, prop: Instance, degrees: number): boolean
	local record = byInstance[prop]
	if not record or record.holder ~= player or not record.targetAttachment then
		return false
	end
	record.targetAttachment.CFrame *= CFrame.Angles(0, math.rad(math.clamp(degrees, -45, 45)), 0)
	return true
end

function PropService:Damage(prop: Instance, amount: number): boolean
	local record = byInstance[prop]
	if not record or amount <= 0 then
		return false
	end
	record.health = math.max(0, record.health - amount)
	setReplicatedState(record)
	if record.health <= 0 then
		self:Break(prop)
	end
	return true
end

function PropService:Break(prop: Instance): boolean
	local record = byInstance[prop]
	if not record then
		return false
	end
	cleanupConstraints(record)
	registry[record.objectID] = nil
	for instance, candidate in byInstance do
		if candidate == record then
			byInstance[instance] = nil
		end
	end
	record.source:Destroy()
	return true
end

function PropService:ReleaseAll(player: Player)
	for _, record in registry do
		if record.holder == player then
			self:Release(player, record.instance)
		end
	end
end

function PropService:Start()
	for _, instance in CollectionService:GetTagged("Prop") do
		self:Register(instance)
	end
	CollectionService:GetInstanceAddedSignal("Prop"):Connect(function(instance)
		self:Register(instance)
	end)
end

return PropService
