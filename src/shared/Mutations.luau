-- Mutations are upgrades made at the Star Forge (not rolled).
-- chance = how much rarer the star becomes (1/100K Shiny -> 1/150K), mult = income multiplier.
-- Upgrading takes ONE star and gives it the next mutation; it costs 3x the Forge price (more for higher tiers).
local Mutations = {}

Mutations.List = {
	{ id = "normal", name = "Normal", chance = 1, mult = 1, color = Color3.fromRGB(255, 255, 255) },
	{ id = "shiny", name = "Shiny", chance = 1.5, mult = 1.5, copies = 1, color = Color3.fromRGB(255, 255, 170) },
	{ id = "golden", name = "Golden", chance = 3, mult = 3, copies = 1, color = Color3.fromRGB(255, 200, 40) },
	{ id = "void", name = "Void", chance = 10, mult = 10, copies = 1, color = Color3.fromRGB(140, 60, 255) },
	{ id = "celestial", name = "Celestial", chance = 50, mult = 50, copies = 1, color = Color3.fromRGB(120, 255, 255) },
}

Mutations.ById = {}
for index, mutation in Mutations.List do
	mutation.index = index
	Mutations.ById[mutation.id] = mutation
end

return Mutations
