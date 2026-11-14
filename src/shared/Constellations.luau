-- Созвездие = отдельная группа звёзд (соседи считаются и по диагонали),
-- форма которой совпадает с шаблоном (с учётом поворотов и отражений).
-- Если к группе прилипла лишняя звезда, созвездие ломается: в этом вся головоломка.
local Constellations = {}

-- Все звёзды в созвездии одного типа -> множитель ещё умножается на это
Constellations.PureBonus = 1.5

Constellations.List = {
	{ id = "pair", name = "Двойная звезда", mult = 1.2,
		cells = { {0,0}, {1,0} } },
	{ id = "triangle", name = "Летний треугольник", mult = 1.4,
		cells = { {0,0}, {1,0}, {0,1} } },
	{ id = "belt", name = "Пояс Ориона", mult = 1.5,
		cells = { {0,0}, {1,0}, {2,0} } },
	{ id = "pegasus", name = "Квадрат Пегаса", mult = 2,
		cells = { {0,0}, {1,0}, {0,1}, {1,1} } },
	{ id = "rhombus", name = "Ромб Дельфина", mult = 2.5,
		cells = { {1,0}, {0,1}, {2,1}, {1,2} } },
	{ id = "cross", name = "Южный Крест", mult = 3,
		cells = { {1,0}, {0,1}, {1,1}, {2,1}, {1,2} } },
	{ id = "cassiopeia", name = "Кассиопея", mult = 3.5,
		cells = { {0,0}, {1,1}, {2,0}, {3,1}, {4,0} } },
	{ id = "dipper", name = "Большая Медведица", mult = 5,
		cells = { {0,0}, {1,0}, {2,0}, {3,0}, {4,0}, {3,1}, {4,1} } },
	{ id = "ring", name = "Кольцо Галактики", mult = 8,
		cells = { {0,0}, {1,0}, {2,0}, {0,1}, {2,1}, {0,2}, {1,2}, {2,2} } },
}

Constellations.ById = {}
for _, pattern in Constellations.List do
	Constellations.ById[pattern.id] = pattern
end

return Constellations
