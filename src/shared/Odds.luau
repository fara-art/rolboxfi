local Stars = require(script.Parent.Stars)
local Mutations = require(script.Parent.Mutations)

local Odds = {}

-- From rarest down: chance luck/N each, fallback to the most common.
local function rollFrom(list, luck: number, rng: Random)
	for i = #list, 2, -1 do
		if rng:NextNumber() < math.min(1, luck / list[i].chance) then
			return list[i]
		end
	end
	return list[1]
end

-- Exact probabilities shown to players
local function exactFrom(list, luck: number): { [string]: number }
	local result = {}
	local remaining = 1
	for i = #list, 2, -1 do
		local p = math.min(1, luck / list[i].chance)
		result[list[i].id] = remaining * p
		remaining *= 1 - p
	end
	result[list[1].id] = remaining
	return result
end

-- Mutations use sqrt(luck) so luck doesn't break them
function Odds.mutationLuck(luck: number): number
	return math.sqrt(luck)
end

function Odds.roll(luck: number, rng: Random)
	return rollFrom(Stars.List, luck, rng)
end

function Odds.rollMutation(luck: number, rng: Random)
	return rollFrom(Mutations.List, Odds.mutationLuck(luck), rng)
end

function Odds.exact(luck: number)
	return exactFrom(Stars.List, luck)
end

function Odds.exactMutations(luck: number)
	return exactFrom(Mutations.List, Odds.mutationLuck(luck))
end

return Odds
