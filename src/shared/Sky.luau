-- Логика неба: поиск групп звёзд, распознавание созвездий, доход
local Stars = require(script.Parent.Stars)
local Constellations = require(script.Parent.Constellations)

local Sky = {}

function Sky.key(x: number, y: number): string
	return x .. "_" .. y
end

function Sky.parse(key: any): (number?, number?)
	if type(key) ~= "string" then
		return nil, nil
	end
	local x, y = string.match(key, "^(%d+)_(%d+)$")
	return tonumber(x), tonumber(y)
end

local function shapeKey(cells): string
	local minX, minY = math.huge, math.huge
	for _, c in cells do
		minX = math.min(minX, c[1])
		minY = math.min(minY, c[2])
	end
	local parts = table.create(#cells)
	for i, c in cells do
		parts[i] = (c[1] - minX) .. ":" .. (c[2] - minY)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

-- 4 поворота * 2 отражения
local transforms = {
	function(x, y) return x, y end,
	function(x, y) return -y, x end,
	function(x, y) return -x, -y end,
	function(x, y) return y, -x end,
	function(x, y) return -x, y end,
	function(x, y) return x, -y end,
	function(x, y) return y, x end,
	function(x, y) return -y, -x end,
}

local lookup = {}
for _, pattern in Constellations.List do
	for _, t in transforms do
		local moved = {}
		for i, c in pattern.cells do
			local x, y = t(c[1], c[2])
			moved[i] = { x, y }
		end
		lookup[shapeKey(moved)] = pattern
	end
end

export type Group = { id: string, pure: boolean, mult: number, cells: { string } }
export type Evaluation = { income: number, groups: { Group }, cellMult: { [string]: number } }

function Sky.evaluate(grid: { [string]: string }, size: number): Evaluation
	local visited = {}
	local groups = {}
	local cellMult = {}
	local total = 0

	for y = 1, size do
		for x = 1, size do
			local startKey = Sky.key(x, y)
			if grid[startKey] and not visited[startKey] then
				-- собираем группу (8 соседей)
				visited[startKey] = true
				local stack = { { x, y } }
				local cells = {}
				while #stack > 0 do
					local c = table.remove(stack)
					table.insert(cells, c)
					for dx = -1, 1 do
						for dy = -1, 1 do
							local nx, ny = c[1] + dx, c[2] + dy
							if (dx ~= 0 or dy ~= 0) and nx >= 1 and ny >= 1 and nx <= size and ny <= size then
								local nk = Sky.key(nx, ny)
								if grid[nk] and not visited[nk] then
									visited[nk] = true
									table.insert(stack, { nx, ny })
								end
							end
						end
					end
				end

				local keys = table.create(#cells)
				for i, c in cells do
					keys[i] = Sky.key(c[1], c[2])
				end

				local mult = 1
				local pattern = lookup[shapeKey(cells)]
				if pattern then
					local first = grid[keys[1]]
					local pure = true
					for _, k in keys do
						if grid[k] ~= first then
							pure = false
							break
						end
					end
					mult = pattern.mult * (if pure then Constellations.PureBonus else 1)
					table.insert(groups, { id = pattern.id, pure = pure, mult = mult, cells = keys })
				end

				for _, k in keys do
					local star = Stars.ById[grid[k]]
					if star then
						total += star.income * mult
					end
					cellMult[k] = mult
				end
			end
		end
	end

	return { income = total, groups = groups, cellMult = cellMult }
end

return Sky
