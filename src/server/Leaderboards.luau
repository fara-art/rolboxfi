-- Global top-100 boards (rolls, rebirths, cash, rarest find) in OrderedDataStores.
-- Results go to ReplicatedStorage.Leaderboards.<board> as JSON for the clients to draw.
-- Falls back to the players on this server when DataStores are unavailable (e.g. Studio without API access).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stars = require(Shared.Stars)
local Mutations = require(Shared.Mutations)
local Items = require(Shared.Items)

local Leaderboards = {}

local BOARDS = { "rolls", "rebirths", "cash", "rarest" }
local TOP = 100

local stores = {}
pcall(function()
	for _, board in BOARDS do
		stores[board] = DataStoreService:GetOrderedDataStore("LB_" .. board .. "_v1")
	end
end)

local folder = Instance.new("Folder")
folder.Name = "Leaderboards"
local values = {}
for _, board in BOARDS do
	local v = Instance.new("StringValue")
	v.Name = board
	v.Value = "[]"
	v.Parent = folder
	values[board] = v
end
folder.Parent = ReplicatedStorage

-- OrderedDataStore only keeps integers, so cash is stored as log10 and the rarest find as a sortable code
local function encode(board: string, data): number?
	if board == "rolls" then
		return math.floor(data.totalRolls)
	elseif board == "rebirths" then
		return math.floor(data.rebirths)
	elseif board == "cash" then
		return math.floor(math.log10(math.max(data.cash, 0) + 1) * 1e9)
	elseif board == "rarest" then
		local star, mutation = Items.parse(data.best)
		if not star then
			return nil
		end
		return math.floor(math.log10(Items.chance(data.best)) * 1000) * 10000 + star.index * 100 + mutation.index
	end
	return nil
end

local function decode(board: string, value: number)
	if board == "cash" then
		return 10 ^ (value / 1e9) - 1
	elseif board == "rarest" then
		local star = Stars.List[math.floor(value / 100) % 100]
		local mutation = Mutations.List[value % 100]
		return if star and mutation then Items.key(star.id, mutation.id) else nil
	end
	return value
end

local names = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.Name
		return online.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else ("#" .. userId)
	return names[userId]
end

function Leaderboards.submit(player: Player, data)
	for _, board in BOARDS do
		local store = stores[board]
		local value = encode(board, data)
		if store and value and value > 0 then
			pcall(store.SetAsync, store, tostring(player.UserId), value)
		end
	end
end

-- live: { { player, data } } of this server, used when the global store can't be read
function Leaderboards.refresh(live)
	for _, board in BOARDS do
		local list = nil
		local store = stores[board]
		if store then
			local ok, pages = pcall(store.GetSortedAsync, store, false, TOP)
			if ok and pages then
				list = {}
				for _, entry in pages:GetCurrentPage() do
					local userId = tonumber(entry.key)
					local value = decode(board, entry.value)
					if userId and value then
						table.insert(list, { name = nameOf(userId), value = value })
					end
				end
			end
		end
		if not list then
			list = {}
			for _, row in live do
				local value = encode(board, row.data)
				if value and value > 0 then
					table.insert(list, { name = row.player.Name, value = decode(board, value), sort = value })
				end
			end
			table.sort(list, function(a, b)
				return a.sort > b.sort
			end)
			for _, row in list do
				row.sort = nil
			end
		end
		values[board].Value = HttpService:JSONEncode(list)
	end
end

return Leaderboards
