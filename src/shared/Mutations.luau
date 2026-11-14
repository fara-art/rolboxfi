-- Mutation rolled separately from the star. Multiplies income.
local Mutations = {}

Mutations.List = {
	{ id = "normal", name = "Normal", chance = 1, mult = 1, color = Color3.fromRGB(255, 255, 255) },
	{ id = "shiny", name = "Shiny", chance = 20, mult = 2, color = Color3.fromRGB(255, 255, 170) },
	{ id = "golden", name = "Golden", chance = 150, mult = 5, color = Color3.fromRGB(255, 200, 40) },
	{ id = "void", name = "Void", chance = 1500, mult = 15, color = Color3.fromRGB(140, 60, 255) },
	{ id = "celestial", name = "Celestial", chance = 20000, mult = 50, color = Color3.fromRGB(120, 255, 255) },
}

Mutations.ById = {}
for index, mutation in Mutations.List do
	mutation.index = index
	Mutations.ById[mutation.id] = mutation
end

return Mutations
