local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stars = require(Shared.Stars)
local Constellations = require(Shared.Constellations)
local Items = require(Shared.Items)
local Evolution = require(Shared.Evolution)
local Odds = require(Shared.Odds)
local Sky = require(Shared.Sky)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local World = require(script.Parent.World)

World.build()

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local RollFn = remote("RemoteFunction", "Roll")
local ActionEv = remote("RemoteEvent", "Action")
local StateEv = remote("RemoteEvent", "State")
local AnnounceEv = remote("RemoteEvent", "Announce")
local CometEv = remote("RemoteEvent", "Comet")
remotes.Parent = ReplicatedStorage

ReplicatedStorage:SetAttribute("ShowerEndsAt", 0)

local GOLD = Color3.fromRGB(255, 214, 140)
local rng = Random.new()
local sessions: { [Player]: any } = {}

---------------------------------------------------------------- helpers
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
	if session then
		for name in Config.GamePasses do
			session.passes[name] = checkPass(player, name)
		end
	end
end

local function isShower(): boolean
	return workspace:GetServerTimeNow() < (ReplicatedStorage:GetAttribute("ShowerEndsAt") or 0)
end

local function getLuck(player: Player, data): number
	local luck = 1 + data.luckLevel * Config.LuckPerLevel + data.rebirths * Config.RebirthLuckBonus
	if sessions[player].passes.Luck2x then
		luck *= 2
	end
	if isShower() then
		luck *= Config.ShowerLuck
	end
	return luck
end

local function incomePerSecond(player: Player, data): number
	local session = sessions[player]
	local mult = (1 + data.rebirths * Config.RebirthIncomeBonus) * (if session.passes.Cash2x then 2 else 1)
	return session.eval.income * mult
end

local function toast(player: Player, text: string, color: Color3?)
	AnnounceEv:FireClient(player, text, color or GOLD)
end

local function recompute(player: Player, data)
	local session = sessions[player]
	session.eval = Sky.evaluate(data.grid, data.gridSize)
	for _, group in session.eval.groups do
		if not data.discovered[group.id] then
			data.discovered[group.id] = true
			local pattern = Constellations.ById[group.id]
			AnnounceEv:FireAllClients(
				string.format("%s discovered %s  (x%s)", player.DisplayName, pattern.name, pattern.mult),
				GOLD
			)
		end
	end
	World.renderPlot(player, data, session.eval, incomePerSecond(player, data))
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
		income = incomePerSecond(player, data),
		groups = session.eval.groups,
		discovered = data.discovered,
		totalRolls = data.totalRolls,
		rebirths = data.rebirths,
		mass = data.mass,
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

local function takeFromInventory(data, key: string, count: number): boolean
	local have = data.inventory[key] or 0
	if count < 1 or have < count then
		return false
	end
	have -= count
	data.inventory[key] = if have > 0 then have else nil
	return true
end

local function addToInventory(data, key: string, count: number)
	data.inventory[key] = (data.inventory[key] or 0) + count
end

-- integer in [0, max], rejects NaN / junk from the client
local function toCount(value: any, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

local function inBounds(data, key: any): boolean
	local x, y = Sky.parse(key)
	return x ~= nil and y ~= nil and x >= 1 and y >= 1 and x <= data.gridSize and y <= data.gridSize
end

local function rollItem(luck: number): string
	local star = Odds.roll(luck, rng)
	local mutation = Odds.rollMutation(luck, rng)
	return Items.key(star.id, mutation.id)
end

local function announceIfRare(player: Player, key: string, verb: string)
	local chance = Items.chance(key)
	if chance >= Config.AnnounceChance then
		local star = Items.parse(key)
		AnnounceEv:FireAllClients(
			string.format("%s %s %s  (1 in %s)", player.DisplayName, verb, Items.name(key), Format.number(chance)),
			star.color
		)
	end
end

---------------------------------------------------------------- join / leave
local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	local cf = World.spawnCFrame(player)
	if cf and character.Parent then
		character:PivotTo(cf)
	end
end

Players.PlayerAdded:Connect(function(player)
	local data = DataService.load(player)
	if not data then
		return
	end
	sessions[player] = {
		lastRoll = 0,
		passes = {},
		eval = nil,
		nextComet = os.clock() + rng:NextNumber(20, 40),
		cometExpires = nil,
	}
	refreshPasses(player)
	World.assignPlot(player)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = stats
	stats.Parent = player

	recompute(player, data)
	pushState(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	World.releasePlot(player)
	DataService.release(player)
	sessions[player] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
	local data = DataService.get(player)
	if purchased and sessions[player] and data then
		refreshPasses(player)
		recompute(player, data)
		pushState(player)
	end
end)

---------------------------------------------------------------- roll
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

	local key = rollItem(getLuck(player, data))
	addToInventory(data, key, 1)
	data.totalRolls += 1
	announceIfRare(player, key, "rolled")
	pushState(player)
	return key
end

---------------------------------------------------------------- actions
local actions = {}

function actions.Place(player, data, cellKey, itemKey)
	if not inBounds(data, cellKey) or not Items.parse(itemKey) then
		return
	end
	if not takeFromInventory(data, itemKey, 1) then
		return
	end
	local old = data.grid[cellKey]
	if old then
		addToInventory(data, old.id, 1)
	end
	data.grid[cellKey] = { id = itemKey, age = 0 }
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
	addToInventory(data, old.id, 1)
	recompute(player, data)
end

function actions.Sell(player, data, itemKey, count)
	if not Items.parse(itemKey) then
		return
	end
	count = toCount(count, data.inventory[itemKey] or 0)
	if takeFromInventory(data, itemKey, count) then
		setCash(player, data, data.cash + Items.income(itemKey) * Config.SellMultiplier * count)
	end
end

function actions.Forge(player, data, itemKey)
	local star, mutation = Items.parse(itemKey)
	if not star then
		return
	end
	local nextStar = Stars.List[star.index + 1]
	if not nextStar then
		return toast(player, "This star can't be forged any further")
	end
	local cost = nextStar.income * Config.ForgeCostMult
	if (data.inventory[itemKey] or 0) < Config.ForgeAmount then
		return toast(player, string.format("Need %d of the same star", Config.ForgeAmount))
	end
	if data.cash < cost then
		return toast(player, "Need " .. Format.number(cost) .. " cash")
	end
	takeFromInventory(data, itemKey, Config.ForgeAmount)
	setCash(player, data, data.cash - cost)
	local result = Items.key(nextStar.id, mutation.id)
	addToInventory(data, result, 1)
	toast(player, "Forged " .. Items.name(result), nextStar.color)
	announceIfRare(player, result, "forged")
end

function actions.Feed(player, data, itemKey, count)
	if not Items.parse(itemKey) then
		return
	end
	count = toCount(count, data.inventory[itemKey] or 0)
	if takeFromInventory(data, itemKey, count) then
		data.mass += Items.income(itemKey) * Config.SellMultiplier * count
	end
end

function actions.Rebirth(player, data)
	local cost = Config.RebirthCost(data.rebirths)
	if data.mass < cost then
		return
	end
	data.rebirths += 1
	data.mass = 0
	data.inventory = {}
	data.grid = {}
	data.gridSize = Config.StartGridSize
	data.luckLevel = 0
	setCash(player, data, 0)
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Rebirths") then
		stats.Rebirths.Value = data.rebirths
	end
	recompute(player, data)
	AnnounceEv:FireAllClients(string.format("%s was reborn from the Black Hole  (Rebirth %d)", player.DisplayName, data.rebirths), Color3.fromRGB(255, 150, 70))
end

function actions.CatchComet(player, data)
	local session = sessions[player]
	if not session.cometExpires or os.clock() > session.cometExpires then
		return
	end
	session.cometExpires = nil
	local key = rollItem(getLuck(player, data) * Config.CometLuck)
	addToInventory(data, key, 1)
	local star = Items.parse(key)
	toast(player, "Comet caught: " .. Items.name(key), star.color)
	announceIfRare(player, key, "caught a comet with")
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

---------------------------------------------------------------- every second: income, aging, comets
local function tickPlayer(player: Player, session)
	local data = DataService.get(player)
	if not data or not session.eval then
		return
	end

	local changed = false
	for _, cell in data.grid do
		local before = Evolution.level(cell.age)
		cell.age += 1
		local after = Evolution.level(cell.age)
		if after ~= before then
			changed = true
		end
		if after == Evolution.MaxLevel then
			local star, mutation = Items.parse(cell.id)
			if star and star.evolvesTo and rng:NextNumber() < Evolution.ExplodeChance then
				local oldName = Items.name(cell.id)
				cell.id = Items.key(star.evolvesTo, mutation.id)
				cell.age = 0
				changed = true
				AnnounceEv:FireAllClients(
					string.format("%s's %s exploded into %s!", player.DisplayName, oldName, Items.name(cell.id)),
					Stars.ById[star.evolvesTo].color
				)
			end
		end
	end
	if changed then
		recompute(player, data)
		pushState(player)
	end

	setCash(player, data, data.cash + incomePerSecond(player, data))

	local now = os.clock()
	if session.cometExpires then
		if now > session.cometExpires then
			session.cometExpires = nil
		end
	elseif now >= session.nextComet then
		session.cometExpires = now + Config.CometLifetime + 0.5
		session.nextComet = now + rng:NextNumber(Config.CometMinDelay, Config.CometMaxDelay)
		CometEv:FireClient(player, Config.CometLifetime)
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			task.spawn(tickPlayer, player, session)
		end
	end
end)

---------------------------------------------------------------- Star Shower
task.spawn(function()
	while true do
		task.wait(Config.ShowerInterval)
		ReplicatedStorage:SetAttribute("ShowerEndsAt", workspace:GetServerTimeNow() + Config.ShowerDuration)
		AnnounceEv:FireAllClients(
			string.format("STAR SHOWER  —  x%s luck for %s", Config.ShowerLuck, Format.time(Config.ShowerDuration)),
			Color3.fromRGB(150, 210, 255)
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
