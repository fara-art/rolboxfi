local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stars = require(Shared.Stars)
local Constellations = require(Shared.Constellations)
local Odds = require(Shared.Odds)
local Sky = require(Shared.Sky)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)

-- Ремоуты
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local RollFn = Instance.new("RemoteFunction")
RollFn.Name = "Roll"
RollFn.Parent = remotes
local ActionEv = Instance.new("RemoteEvent")
ActionEv.Name = "Action"
ActionEv.Parent = remotes
local StateEv = Instance.new("RemoteEvent")
StateEv.Name = "State"
StateEv.Parent = remotes
local AnnounceEv = Instance.new("RemoteEvent")
AnnounceEv.Name = "Announce"
AnnounceEv.Parent = remotes
remotes.Parent = ReplicatedStorage

ReplicatedStorage:SetAttribute("ShowerEndsAt", 0)

local rng = Random.new()
local sessions: { [Player]: any } = {}

local function checkPass(player: Player, name: string): boolean
	local id = Config.GamePasses[name]
	if not id or id == 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	return ok and owns == true
end

local function refreshPasses(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	for name in Config.GamePasses do
		session.passes[name] = checkPass(player, name)
	end
end

local function isShower(): boolean
	return workspace:GetServerTimeNow() < (ReplicatedStorage:GetAttribute("ShowerEndsAt") or 0)
end

local function getLuck(player: Player, data): number
	local luck = 1 + data.luckLevel * Config.LuckPerLevel
	if sessions[player].passes.Luck2x then
		luck *= 2
	end
	if isShower() then
		luck *= Config.ShowerLuck
	end
	return luck
end

local function incomePerSecond(player: Player): number
	local session = sessions[player]
	return session.eval.income * (if session.passes.Cash2x then 2 else 1)
end

local function recompute(player: Player, data)
	local session = sessions[player]
	session.eval = Sky.evaluate(data.grid, data.gridSize)
	for _, group in session.eval.groups do
		if not data.discovered[group.id] then
			data.discovered[group.id] = true
			local pattern = Constellations.ById[group.id]
			AnnounceEv:FireAllClients(
				string.format("✨ %s открыл созвездие «%s» (x%s)!", player.DisplayName, pattern.name, pattern.mult),
				Color3.fromRGB(255, 220, 120)
			)
		end
	end
end

local function pushState(player: Player)
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return
	end
	StateEv:FireClient(player, {
		cash = data.cash,
		inventory = data.inventory,
		grid = data.grid,
		gridSize = data.gridSize,
		luckLevel = data.luckLevel,
		luck = getLuck(player, data),
		income = incomePerSecond(player),
		groups = session.eval.groups,
		discovered = data.discovered,
		totalRolls = data.totalRolls,
		passes = session.passes,
	})
end

local function setCash(player: Player, data, value: number)
	data.cash = value
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	if cash then
		cash.Value = value
	end
end

local function takeFromInventory(data, starId: string, count: number): boolean
	local have = data.inventory[starId] or 0
	if have < count then
		return false
	end
	have -= count
	data.inventory[starId] = if have > 0 then have else nil
	return true
end

local function addToInventory(data, starId: string, count: number)
	data.inventory[starId] = (data.inventory[starId] or 0) + count
end

local function inBounds(data, key: any): boolean
	local x, y = Sky.parse(key)
	return x ~= nil and y ~= nil and x >= 1 and y >= 1 and x <= data.gridSize and y <= data.gridSize
end

-- Вход / выход
Players.PlayerAdded:Connect(function(player)
	local data = DataService.load(player)
	if not data then
		return
	end
	sessions[player] = { lastRoll = 0, passes = {}, eval = nil }
	refreshPasses(player)
	recompute(player, data)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = stats
	stats.Parent = player

	pushState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	DataService.release(player)
	sessions[player] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
	if purchased and sessions[player] then
		refreshPasses(player)
		pushState(player)
	end
end)

-- Крутка
RollFn.OnServerInvoke = function(player)
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return nil
	end
	local now = os.clock()
	if now - session.lastRoll < Config.RollCooldown * 0.9 then
		return nil
	end
	session.lastRoll = now

	local star = Odds.roll(getLuck(player, data), rng)
	addToInventory(data, star.id, 1)
	data.totalRolls += 1

	if star.chance >= Config.AnnounceChance then
		AnnounceEv:FireAllClients(
			string.format("🌟 %s выбил «%s» (1 к %s)!", player.DisplayName, star.name, Format.number(star.chance)),
			star.color
		)
	end
	pushState(player)
	return star.id
end

-- Действия игрока
local actions = {}

function actions.Place(player, data, cellKey, starId)
	if not inBounds(data, cellKey) or type(starId) ~= "string" or not Stars.ById[starId] then
		return
	end
	if not takeFromInventory(data, starId, 1) then
		return
	end
	local old = data.grid[cellKey]
	if old then
		addToInventory(data, old, 1)
	end
	data.grid[cellKey] = starId
	recompute(player, data)
end

function actions.Remove(player, data, cellKey)
	if type(cellKey) ~= "string" then
		return
	end
	local old = data.grid[cellKey]
	if not old then
		return
	end
	data.grid[cellKey] = nil
	addToInventory(data, old, 1)
	recompute(player, data)
end

function actions.Sell(player, data, starId, count)
	if type(starId) ~= "string" or type(count) ~= "number" then
		return
	end
	local star = Stars.ById[starId]
	count = math.floor(count)
	if not star or count < 1 or count ~= count then
		return
	end
	count = math.min(count, data.inventory[starId] or 0)
	if count > 0 and takeFromInventory(data, starId, count) then
		setCash(player, data, data.cash + star.income * Config.SellMultiplier * count)
	end
end

function actions.BuyLuck(player, data)
	if data.luckLevel >= Config.MaxLuckLevel then
		return
	end
	local cost = Config.LuckCost(data.luckLevel)
	if data.cash < cost then
		return
	end
	setCash(player, data, data.cash - cost)
	data.luckLevel += 1
end

function actions.BuyGrid(player, data)
	if data.gridSize >= Config.MaxGridSize then
		return
	end
	local cost = Config.GridCost(data.gridSize)
	if data.cash < cost then
		return
	end
	setCash(player, data, data.cash - cost)
	data.gridSize += 1
	recompute(player, data)
end

ActionEv.OnServerEvent:Connect(function(player, action, a, b)
	local handler = type(action) == "string" and actions[action]
	local data = DataService.get(player)
	if not handler or not data or not sessions[player] then
		return
	end
	handler(player, data, a, b)
	pushState(player)
end)

-- Доход каждую секунду
task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			local data = DataService.get(player)
			if data and session.eval then
				setCash(player, data, data.cash + incomePerSecond(player))
			end
		end
	end
end)

-- Звездопад
task.spawn(function()
	while true do
		task.wait(Config.ShowerInterval)
		ReplicatedStorage:SetAttribute("ShowerEndsAt", workspace:GetServerTimeNow() + Config.ShowerDuration)
		AnnounceEv:FireAllClients(
			string.format("🌠 ЗВЕЗДОПАД! Удача x%s на %s", Config.ShowerLuck, Format.time(Config.ShowerDuration)),
			Color3.fromRGB(140, 200, 255)
		)
		for player in sessions do
			pushState(player)
		end
		task.wait(Config.ShowerDuration)
		for player in sessions do
			pushState(player)
		end
	end
end)
