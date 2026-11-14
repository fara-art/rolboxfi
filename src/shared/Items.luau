-- Item key = "starId" or "starId|mutationId"
local Stars = require(script.Parent.Stars)
local Mutations = require(script.Parent.Mutations)

local Items = {}

function Items.key(starId: string, mutationId: string?): string
	if mutationId == nil or mutationId == "normal" then
		return starId
	end
	return starId .. "|" .. mutationId
end

function Items.parse(key: any)
	if type(key) ~= "string" then
		return nil, nil
	end
	local starId, mutationId = string.match(key, "^(%w+)|(%w+)$")
	if not starId then
		starId, mutationId = key, "normal"
	end
	local star, mutation = Stars.ById[starId], Mutations.ById[mutationId]
	if not star or not mutation then
		return nil, nil
	end
	return star, mutation
end

function Items.name(key: string): string
	local star, mutation = Items.parse(key)
	if not star then
		return "?"
	end
	return if mutation.id == "normal" then star.name else mutation.name .. " " .. star.name
end

function Items.income(key: string): number
	local star, mutation = Items.parse(key)
	return if star then star.income * mutation.mult else 0
end

function Items.chance(key: string): number
	local star, mutation = Items.parse(key)
	return if star then star.chance * mutation.chance else 0
end

-- for sorting: rarer first
function Items.rank(key: string): number
	local star, mutation = Items.parse(key)
	return if star then star.index * 100 + mutation.index else 0
end

return Items
