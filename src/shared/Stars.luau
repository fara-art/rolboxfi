-- Звёзды: chance = "1 к N", income = доход в секунду, когда звезда стоит на небе
local Stars = {}

Stars.List = {
	{ id = "dust", name = "Звёздная пыль", chance = 2, income = 1, color = Color3.fromRGB(170, 170, 190) },
	{ id = "spark", name = "Искра", chance = 5, income = 3, color = Color3.fromRGB(255, 240, 180) },
	{ id = "dwarf", name = "Красный карлик", chance = 15, income = 10, color = Color3.fromRGB(255, 90, 70) },
	{ id = "sun", name = "Жёлтое солнце", chance = 50, income = 35, color = Color3.fromRGB(255, 210, 60) },
	{ id = "giant", name = "Голубой гигант", chance = 200, income = 150, color = Color3.fromRGB(80, 160, 255) },
	{ id = "pulsar", name = "Пульсар", chance = 1000, income = 800, color = Color3.fromRGB(170, 90, 255) },
	{ id = "neutron", name = "Нейтронная звезда", chance = 10000, income = 9000, color = Color3.fromRGB(90, 255, 220) },
	{ id = "quasar", name = "Квазар", chance = 100000, income = 100000, color = Color3.fromRGB(255, 80, 200) },
	{ id = "supernova", name = "Сверхновая", chance = 1000000, income = 1500000, color = Color3.fromRGB(255, 255, 255) },
}

Stars.ById = {}
for index, star in Stars.List do
	star.index = index
	Stars.ById[star.id] = star
end

return Stars
