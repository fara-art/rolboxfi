-- chance = "1 in N", income = cash per second while placed on the sky
-- evolvesTo = what it can explode into at max evolution level
local Stars = {}

Stars.List = {
	{ id = "dust", name = "Stardust", chance = 2, income = 1, color = Color3.fromRGB(170, 170, 190) },
	{ id = "spark", name = "Spark", chance = 5, income = 3, color = Color3.fromRGB(255, 240, 180) },
	{ id = "browndwarf", name = "Brown Dwarf", chance = 9, income = 6, color = Color3.fromRGB(160, 100, 70) },
	{ id = "dwarf", name = "Red Dwarf", chance = 15, income = 10, color = Color3.fromRGB(255, 90, 70) },
	{ id = "whitedwarf", name = "White Dwarf", chance = 30, income = 20, color = Color3.fromRGB(225, 240, 255) },
	{ id = "sun", name = "Yellow Sun", chance = 50, income = 35, color = Color3.fromRGB(255, 210, 60), evolvesTo = "giant" },
	{ id = "redgiant", name = "Red Giant", chance = 100, income = 75, color = Color3.fromRGB(255, 120, 60) },
	{ id = "giant", name = "Blue Giant", chance = 200, income = 150, color = Color3.fromRGB(80, 160, 255), evolvesTo = "neutron" },
	{ id = "binary", name = "Twin Stars", chance = 450, income = 350, color = Color3.fromRGB(255, 220, 160) },
	{ id = "pulsar", name = "Pulsar", chance = 1000, income = 800, color = Color3.fromRGB(170, 90, 255) },
	{ id = "wolfrayet", name = "Wolf-Rayet Star", chance = 3000, income = 2500, color = Color3.fromRGB(255, 130, 170) },
	{ id = "neutron", name = "Neutron Star", chance = 10000, income = 9000, color = Color3.fromRGB(90, 255, 220) },
	{ id = "hypergiant", name = "Hypergiant", chance = 30000, income = 28000, color = Color3.fromRGB(255, 100, 40) },
	{ id = "quasar", name = "Quasar", chance = 100000, income = 100000, color = Color3.fromRGB(255, 80, 200), evolvesTo = "supernova" },
	{ id = "kilonova", name = "Kilonova", chance = 300000, income = 350000, color = Color3.fromRGB(255, 190, 90) },
	{ id = "supernova", name = "Supernova", chance = 1000000, income = 1500000, color = Color3.fromRGB(255, 255, 255) },
	{ id = "magnetar", name = "Magnetar", chance = 5000000, income = 8000000, color = Color3.fromRGB(110, 200, 255) },
	{ id = "nebula", name = "Nebula Heart", chance = 25000000, income = 45000000, color = Color3.fromRGB(255, 140, 230) },
	{ id = "whitehole", name = "White Hole", chance = 100000000, income = 200000000, color = Color3.fromRGB(235, 248, 255) },
	{ id = "eventhorizon", name = "Event Horizon", chance = 300000000, income = 650000000, color = Color3.fromRGB(255, 150, 60) },
	{ id = "galaxy", name = "Galaxy Core", chance = 1000000000, income = 2500000000, color = Color3.fromRGB(255, 205, 110) },
	{ id = "darkmatter", name = "Dark Matter Star", chance = 3000000000, income = 8000000000, color = Color3.fromRGB(150, 90, 220) },
	{ id = "cosmic", name = "Cosmic String", chance = 10000000000, income = 30000000000, color = Color3.fromRGB(130, 255, 200) },
	{ id = "multiverse", name = "Multiverse", chance = 30000000000, income = 100000000000, color = Color3.fromRGB(120, 220, 255) },
	{ id = "bigbang", name = "Big Bang", chance = 100000000000, income = 400000000000, color = Color3.fromRGB(255, 120, 80) },
	{ id = "cosmicweb", name = "Cosmic Web", chance = 300000000000, income = 1300000000000, color = Color3.fromRGB(170, 190, 255) },
	{ id = "infinity", name = "Infinity Star", chance = 1000000000000, income = 5000000000000, color = Color3.fromRGB(200, 160, 255) },
}

Stars.ById = {}
for index, star in Stars.List do
	star.index = index
	Stars.ById[star.id] = star
end

return Stars
