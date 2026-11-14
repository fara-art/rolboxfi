local Stars = require(script.Parent.Stars)

local Odds = {}

-- Идём от самой редкой: шанс luck/N, иначе дальше. Пыль, если ничего не выпало.
function Odds.roll(luck: number, rng: Random)
	for i = #Stars.List, 2, -1 do
		local star = Stars.List[i]
		if rng:NextNumber() < math.min(1, luck / star.chance) then
			return star
		end
	end
	return Stars.List[1]
end

-- Точные вероятности при текущей удаче (показываем игрокам честно)
function Odds.exact(luck: number): { [string]: number }
	local result = {}
	local remaining = 1
	for i = #Stars.List, 2, -1 do
		local star = Stars.List[i]
		local p = math.min(1, luck / star.chance)
		result[star.id] = remaining * p
		remaining *= 1 - p
	end
	result[Stars.List[1].id] = remaining
	return result
end

return Odds
