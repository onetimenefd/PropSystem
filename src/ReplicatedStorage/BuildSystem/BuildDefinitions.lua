return table.freeze({
	Wall = table.freeze({ Size = Vector3.new(12, 10, 1), Color = Color3.fromRGB(166, 147, 122) }),
	Floor = table.freeze({ Size = Vector3.new(12, 1, 12), Color = Color3.fromRGB(125, 111, 93) }),
	Ramp = table.freeze({ Size = Vector3.new(12, 1, 12), Color = Color3.fromRGB(151, 132, 105), Ramp = true }),
	Foundation = table.freeze({ Size = Vector3.new(12, 2, 12), Color = Color3.fromRGB(105, 105, 105) }),
})
