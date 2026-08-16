return table.freeze({
	GrabDistance = 12,
	-- Allow for cursor/network drift when the server validates a surface hit.
	GrabPointTolerance = 1.5,
	DefaultHoldDistance = 2.75,
	MinHoldDistance = 1.5,
	MaxHoldDistance = 3.25,
	SoftGripDistance = 3.2,
	BreakDistance = 4.5,
	BreakGracePeriod = 0.65,
	LightResponsiveness = 32,
	HeavyResponsiveness = 7,
	HeavyMass = 100,
	-- Heavy props slow their holder continuously with mass, down to this fraction
	-- of the holder's normal WalkSpeed at HeavyMaxSlowMass.
	HeavyMaxSlowMass = 300,
	HeavyWalkSpeedScale = 0.8,
	MinimumWalkSpeedScale = 0.35,
	-- Force grows sub-linearly: a second holder really does make a heavy prop easier.
	BaseForce = 18000,
	ForcePerMass = 850,
	MaxTorquePerMass = 2400,
	TargetUpdateRate = 20,
	MinTargetHeightFromShoulder = -1.5,
	MaxTargetHeightFromShoulder = 2,
	ArmOverlap = 0.08,
})
