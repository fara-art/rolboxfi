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

-- the normal stars plus the stars of one season, kept in order of rarity
local listCache = {}
function Odds.list(season: number?)
	if not season then
		return Stars.List
	end
	if not listCache[season] then
		local list = table.clone(Stars.List)
		for _, star in Stars.Seasonal do
			if star.season == season then
				local at = #list + 1
				for i = #list, 1, -1 do
					if list[i].chance <= star.chance then
						break
					end
					at = i
				end
				table.insert(list, at, star)
			end
		end
		listCache[season] = list
	end
	return listCache[season]
end

function Odds.roll(luck: number, rng: Random, season: number?)
	return rollFrom(Odds.list(season), luck, rng)
end

function Odds.rollMutation(luck: number, rng: Random)
	return rollFrom(Mutations.List, Odds.mutationLuck(luck), rng)
end

function Odds.exact(luck: number, season: number?)
	return exactFrom(Odds.list(season), luck)
end

function Odds.exactMutations(luck: number)
	return exactFrom(Mutations.List, Odds.mutationLuck(luck))
end

return Odds
