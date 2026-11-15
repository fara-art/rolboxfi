-- Player progress saving (DataStore)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local cache: { [Player]: any } = {}

local function default()
	return {
		cash = 0,
		inventory = {}, -- [itemKey] = count
		grid = {}, -- ["x_y"] = { id = itemKey, age = seconds }
		gridSize = Config.StartGridSize,
		luckLevel = 0,
		discovered = {}, -- [constellationId] = true
		totalRolls = 0,
		rebirths = 0,
		mass = 0, -- Black Hole progress
		rollSpeedLevel = 0,
		multiRollLevel = 0,
		bonusLuck = 0, -- from Index rows and roll milestones, survives rebirth
		index = {}, -- [itemKey] = true, every star ever found
		indexClaims = {}, -- [mutationId] = true
		milestones = {}, -- ["1"] = true (string keys for DataStore)
		lang = "", -- "" = auto
		settings = { music = true, sfx = true, rareAlert = 10000 },
		slabs = {}, -- ["x_y"] = slab id (build mode)
		freeSlabsGiven = false,
		best = "", -- rarest item ever found (leaderboard)
		rebirthRolls = -1, -- rolls since the last rebirth (roll rewards); -1 = not migrated yet
		floors = 1, -- museum floors
		luckyProgress = 0, -- rolls towards the next x2 luck roll
		robuxSpeed = 0, -- bought speed tiers
		robuxMulti = 0, -- bought extra rolls per click
		robuxLuck = 0, -- bought "double your luck" tiers
		boostLuckUntil = 0, -- server time when the x2 luck boost ends
		boostSpeedUntil = 0,
		receipts = {}, -- processed purchase ids (never grant twice)
		daily = { day = 0, last = 0 }, -- last claimed day of the 7-day cycle + when
		codes = {}, -- redeemed codes
		tutorialDone = false,
		theme = "sky",
		rebirthTokens = -1, -- -1 = old save: gets one token per rebirth already done
		rebirthUps = {}, -- [upgrade id] = level (permanent)
		pets = {}, -- equipped pet item keys (taken out of the inventory while equipped)
		petSpeed = 0, -- cached roll-speed share of the pets (read by Config.EffectiveCooldown)
		expedition = false, -- false or { items = { keys }, start = os.time(), hours = n }
		likes = { week = 0, count = 0 }, -- likes your museum got this week
		likedWeek = { week = 0, owners = {} }, -- museums you liked this week ([userId string] = true)
		likeRewardWeek = 0, -- last week whose top-3 reward was checked
		fusions = {}, -- [hybrid id] = true, recipes found
		lastSeen = 0, -- os.time() of the last income tick (offline income)
		lastIncome = 0, -- income per second at that moment
		layoutVersion = 0, -- 2 = museum layout (spot_floor keys)
	}
end

local function reconcile(data)
	for key, value in default() do
		if data[key] == nil then
			data[key] = value
		end
	end
	if data.rebirthTokens < 0 then
		data.rebirthTokens = data.rebirths or 0
	end
	-- v1 saves stored grid cells as plain star ids
	for key, cell in data.grid do
		if type(cell) == "string" then
			data.grid[key] = { id = cell, age = 0 }
		end
	end
	return data
end

local function retry(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn("[DataService] attempt", attempt, result)
		task.wait(attempt)
	end
	return false, nil
end

local function keyFor(player: Player): string
	return "p_" .. player.UserId
end

function DataService.load(player: Player)
	local ok, data = false, nil
	if store then
		ok, data = retry(function()
			return store:GetAsync(keyFor(player))
		end)
	end
	if not ok then
		if RunService:IsStudio() then
			warn("[DataService] DataStore unavailable (enable API Services in Game Settings). Playing without saves.")
		else
			player:Kick("Failed to load your data. Please rejoin.")
			return nil
		end
	end
	data = reconcile(if type(data) == "table" then data else default())
	cache[player] = data
	return data
end

function DataService.get(player: Player)
	return cache[player]
end

function DataService.save(player: Player)
	local data = cache[player]
	if not data or not store then
		return
	end
	retry(function()
		store:SetAsync(keyFor(player), data)
	end)
end

function DataService.release(player: Player)
	DataService.save(player)
	cache[player] = nil
end

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player in cache do
			task.spawn(DataService.save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			DataService.save(player)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)

return DataService
