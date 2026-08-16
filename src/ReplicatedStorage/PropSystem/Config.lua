return table.freeze({
	GrabDistance = 12,
	DefaultHoldDistance = 2.75,
	MinHoldDistance = 2,
	MaxHoldDistance = 3.25,
	BreakDistance = 3.5,
	BreakGracePeriod = 0.65,
	LightResponsiveness = 32,
	HeavyResponsiveness = 7,
	HeavyMass = 100,
	-- Force grows sub-linearly: a second holder really does make a heavy prop easier.
	BaseForce = 18000,
	ForcePerMass = 850,
	MaxTorquePerMass = 2400,
	RotationSensitivity = 0.35,
})
