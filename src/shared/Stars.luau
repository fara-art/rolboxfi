-- chance = "1 in N", income = cash per second while placed on the sky
-- evolvesTo = what it can explode into at max evolution level
local Stars = {}

Stars.List = {
	{ id = "dust", name = "Stardust", chance = 2, income = 1, color = Color3.fromRGB(170, 170, 190) },
	{ id = "spark", name = "Spark", chance = 5, income = 3, color = Color3.fromRGB(255, 240, 180) },
	{ id = "dwarf", name = "Red Dwarf", chance = 15, income = 10, color = Color3.fromRGB(255, 90, 70) },
	{ id = "sun", name = "Yellow Sun", chance = 50, income = 35, color = Color3.fromRGB(255, 210, 60), evolvesTo = "giant" },
	{ id = "giant", name = "Blue Giant", chance = 200, income = 150, color = Color3.fromRGB(80, 160, 255), evolvesTo = "neutron" },
	{ id = "pulsar", name = "Pulsar", chance = 1000, income = 800, color = Color3.fromRGB(170, 90, 255) },
	{ id = "neutron", name = "Neutron Star", chance = 10000, income = 9000, color = Color3.fromRGB(90, 255, 220) },
	{ id = "quasar", name = "Quasar", chance = 100000, income = 100000, color = Color3.fromRGB(255, 80, 200), evolvesTo = "supernova" },
	{ id = "supernova", name = "Supernova", chance = 1000000, income = 1500000, color = Color3.fromRGB(255, 255, 255) },
}

Stars.ById = {}
for index, star in Stars.List do
	star.index = index
	Stars.ById[star.id] = star
end

return Stars
