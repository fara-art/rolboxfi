-- A constellation = an isolated group of stars (diagonal neighbors count)
-- whose shape matches a pattern (rotations and mirrors allowed).
-- An extra neighbor breaks it: that's the puzzle.
local Constellations = {}

-- All stars of the same type -> extra multiplier
Constellations.PureBonus = 1.5

Constellations.List = {
	{ id = "pair", name = "Binary Star", mult = 1.2,
		cells = { {0,0}, {1,0} } },
	{ id = "triangle", name = "Summer Triangle", mult = 1.4,
		cells = { {0,0}, {1,0}, {0,1} } },
	{ id = "belt", name = "Orion's Belt", mult = 1.5,
		cells = { {0,0}, {1,0}, {2,0} } },
	{ id = "pegasus", name = "Pegasus Square", mult = 2,
		cells = { {0,0}, {1,0}, {0,1}, {1,1} } },
	{ id = "rhombus", name = "Dolphin Diamond", mult = 2.5,
		cells = { {1,0}, {0,1}, {2,1}, {1,2} } },
	{ id = "cross", name = "Southern Cross", mult = 3,
		cells = { {1,0}, {0,1}, {1,1}, {2,1}, {1,2} } },
	{ id = "cassiopeia", name = "Cassiopeia", mult = 3.5,
		cells = { {0,0}, {1,1}, {2,0}, {3,1}, {4,0} } },
	{ id = "dipper", name = "Big Dipper", mult = 5,
		cells = { {0,0}, {1,0}, {2,0}, {3,0}, {4,0}, {3,1}, {4,1} } },
	{ id = "ring", name = "Galaxy Ring", mult = 8,
		cells = { {0,0}, {1,0}, {2,0}, {0,1}, {2,1}, {0,2}, {1,2}, {2,2} } },
}

Constellations.ById = {}
for _, pattern in Constellations.List do
	Constellations.ById[pattern.id] = pattern
end

return Constellations
