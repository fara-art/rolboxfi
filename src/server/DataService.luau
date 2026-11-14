-- Сохранение прогресса игроков в DataStore
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
		inventory = {}, -- [starId] = count
		grid = {}, -- ["x_y"] = starId
		gridSize = Config.StartGridSize,
		luckLevel = 0,
		discovered = {}, -- [constellationId] = true
		totalRolls = 0,
	}
end

local function reconcile(data)
	for key, value in default() do
		if data[key] == nil then
			data[key] = value
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
		warn("[DataService] попытка", attempt, result)
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
			warn("[DataService] DataStore недоступен (включи API Services в Game Settings). Играем без сохранений.")
		else
			player:Kick("Не удалось загрузить данные. Зайди ещё раз.")
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
