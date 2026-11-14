-- Stars on the sky age and level up. Some stars at max level can explode into a better star.
local Evolution = {}

Evolution.Thresholds = { 0, 60, 300, 1200, 3600 } -- seconds on the sky
Evolution.Mults = { 1, 1.25, 1.5, 2, 3 }
Evolution.MaxLevel = #Evolution.Thresholds
Evolution.ExplodeChance = 1 / 900 -- per second, at max level

function Evolution.level(age: number): number
	local level = 1
	for i, threshold in Evolution.Thresholds do
		if age >= threshold then
			level = i
		end
	end
	return level
end

function Evolution.mult(age: number): number
	return Evolution.Mults[Evolution.level(age)]
end

return Evolution
