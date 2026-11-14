local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stars = require(Shared.Stars)
local Mutations = require(Shared.Mutations)
local Constellations = require(Shared.Constellations)
local Items = require(Shared.Items)
local Evolution = require(Shared.Evolution)
local Odds = require(Shared.Odds)
local Sky = require(Shared.Sky)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local World = require(script.Parent.World)
local Leaderboards = require(script.Parent.Leaderboards)

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
local AnnounceEv = remote("RemoteEvent", "Announce") -- (langKey, args, color)
local PickerEv = remote("RemoteEvent", "OpenPicker") -- (cellKey)
local OpenWindowEv = remote("RemoteEvent", "OpenWindow") -- (name)
local GlobalRareEv = remote("RemoteEvent", "GlobalRare") -- (playerName, itemKey, chance)
remotes.Parent = ReplicatedStorage

ReplicatedStorage:SetAttribute("ShowerEndsAt", 0)

World.build()

local GOLD = Color3.fromRGB(255, 196, 70)
local rng = Random.new()
local sessions: { [Player]: any } = {}

---------------------------------------------------------------- messaging
local function toast(player: Player, key: string, args: { any }?, color: Color3?)
	AnnounceEv:FireClient(player, key, args or {}, color or GOLD)
end

local function announceAll(key: string, args: { any }, color: Color3?)
	AnnounceEv:FireAllClients(key, args, color or GOLD)
end

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
	local luck = (1 + data.luckLevel * Config.LuckPerLevel + data.bonusLuck) * (1 + data.rebirths * Config.RebirthLuckMult)
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
	if not World.plotOf(player) or not session.eval then
		return 0
	end
	local mult = (1 + data.rebirths * Config.RebirthIncomeBonus) * (if session.passes.Cash2x then 2 else 1)
	return session.eval.income * mult
end

local function recompute(player: Player, data)
	local session = sessions[player]
	session.eval = Sky.evaluate(data.grid, data.gridSize, data.slabs)
	if World.plotOf(player) then
		for _, group in session.eval.groups do
			if not data.discovered[group.id] then
				data.discovered[group.id] = true
				announceAll("annDiscover", { player.DisplayName, { constellation = group.id }, Constellations.ById[group.id].mult })
			end
		end
		World.renderPlot(player, data, session.eval, incomePerSecond(player, data))
	end
end

local function setStat(player: Player, name: string, value: number)
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild(name)
	if stat then
		stat.Value = value
	end
end

local function setCash(player: Player, data, value: number)
	data.cash = value
	setStat(player, "Cash", value)
end

-- Admin = owner of the game (user-owned games), listed user IDs, or anyone in a Studio test
local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
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
		rollSpeedLevel = data.rollSpeedLevel,
		multiRollLevel = data.multiRollLevel,
		luck = getLuck(player, data),
		income = incomePerSecond(player, data),
		groups = if session.eval then session.eval.groups else {},
		discovered = data.discovered,
		totalRolls = data.totalRolls,
		rebirthRolls = data.rebirthRolls,
		floors = data.floors,
		theme = data.theme,
		rebirths = data.rebirths,
		mass = data.mass,
		index = data.index,
		indexClaims = data.indexClaims,
		milestones = data.milestones,
		lang = data.lang,
		settings = data.settings,
		hasPlot = World.plotOf(player) ~= nil,
		passes = session.passes,
		isAdmin = isAdmin(player),
	})
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

local function discover(player: Player, data, key: string)
	if Items.chance(key) > Items.chance(data.best) then
		data.best = key
	end
	if not data.index[key] then
		data.index[key] = true
		toast(player, "toastNewIndex", { { item = key } }, Items.parse(key).color)
	end
end

-- free starter slabs in the middle of the plot (and under stars from older saves)
local function giveFreeSlabs(data)
	if data.freeSlabsGiven then
		return
	end
	data.freeSlabsGiven = true
	for key in data.grid do
		data.slabs[key] = data.slabs[key] or "stone"
	end
	-- first spots on the left wall of the ground floor
	local given = 0
	for spot = 1, Config.SpotsPerFloor do
		local key = Sky.key(spot, 1)
		if given >= Config.FreeStoneSlabs then
			break
		end
		if not data.slabs[key] then
			data.slabs[key] = "stone"
			given += 1
		end
	end
end

-- old grid saves -> museum layout: stars go back to the catalogue, starter stands are given again
local function migrateToMuseum(data)
	if data.layoutVersion == 2 then
		return
	end
	for _, cell in data.grid do
		data.inventory[cell.id] = (data.inventory[cell.id] or 0) + 1
	end
	data.grid = {}
	data.slabs = {}
	data.freeSlabsGiven = false
	data.floors = math.max(1, data.floors or 1)
	data.theme = data.theme or "sky"
	data.layoutVersion = 2
end

local function addToInventory(player: Player, data, key: string, count: number)
	data.inventory[key] = (data.inventory[key] or 0) + count
	discover(player, data, key)
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
	return x ~= nil and y ~= nil and x >= 1 and y >= 1 and x <= Config.SpotsPerFloor and y <= data.floors
end

local function rollItem(luck: number): string
	return Odds.roll(luck, rng).id -- mutations come from upgrading at the Forge
end

local function announceIfRare(player: Player, key: string)
	local chance = Items.chance(key)
	if chance >= Config.GlobalRareChance then
		-- whole server sees a cinematic + a pillar of light over the lucky player
		GlobalRareEv:FireAllClients(player.DisplayName, key, chance)
		World.lightPillar(player, Items.parse(key).color)
	elseif chance >= Config.AnnounceChance then
		announceAll("annRolled", { player.DisplayName, { item = key }, Format.number(chance), chance }, Items.parse(key).color)
	end
end



local function spend(player: Player, data, cost: number): boolean
	if data.cash < cost then
		toast(player, "toastNeedCash", { Format.number(cost) })
		return false
	end
	setCash(player, data, data.cash - cost)
	return true
end

---------------------------------------------------------------- join / leave
local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	if character.Parent then
		character:PivotTo(World.spawnCFrame(player))
	end
end

Players.PlayerAdded:Connect(function(player)
	local data = DataService.load(player)
	if not data then
		return
	end
	sessions[player] = { lastRoll = 0, passes = {}, eval = nil }
	refreshPasses(player)

	-- older saves: put everything owned into the Index
	for key in data.inventory do
		data.index[key] = true
	end
	for _, cell in data.grid do
		data.index[cell.id] = true
	end
	for key in data.index do
		if Items.chance(key) > Items.chance(data.best) then
			data.best = key
		end
	end
	migrateToMuseum(data)
	giveFreeSlabs(data)
	if data.rebirthRolls < 0 then
		data.rebirthRolls = data.totalRolls
	end
	data.settings.rareAlert = data.settings.rareAlert or 50000000

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, info in { { "Cash", "NumberValue", data.cash }, { "Rolls", "IntValue", data.totalRolls }, { "Rebirths", "IntValue", data.rebirths } } do
		local value = Instance.new(info[2])
		value.Name = info[1]
		value.Value = info[3]
		value.Parent = stats
	end
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
	local leaving = DataService.get(player)
	if leaving then
		task.spawn(Leaderboards.submit, player, leaving)
	end
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

---------------------------------------------------------------- plots
World.onPlotTouched = function(player, index)
	local data = DataService.get(player)
	if not data or not sessions[player] or World.plotOf(player) then
		return
	end
	if World.claimPlot(player, index) then
		toast(player, "toastClaimed", {}, Color3.fromRGB(90, 200, 140))
		recompute(player, data)
		pushState(player)
	end
end

World.onForge = function(player)
	OpenWindowEv:FireClient(player, "forge")
end

World.onElevator = function(player, index, floor, floors)
	OpenWindowEv:FireClient(player, "elevator", { plot = index, floor = floor, floors = floors })
end

World.onHole = function(player)
	OpenWindowEv:FireClient(player, "hole")
end

World.onPedestal = function(player, index, cellKey)
	local data = DataService.get(player)
	if not data or not sessions[player] then
		return
	end
	if World.plotOf(player) ~= index then
		return toast(player, "toastNotYours")
	end
	local placed = data.grid[cellKey]
	if placed then
		data.grid[cellKey] = nil
		addToInventory(player, data, placed.id, 1)
		recompute(player, data)
		pushState(player)
	else
		PickerEv:FireClient(player, cellKey)
	end
end

---------------------------------------------------------------- roll
RollFn.OnServerInvoke = function(player)
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return nil
	end
	local now = os.clock()
	if now - session.lastRoll < Config.RollCooldown(data.rollSpeedLevel) * 0.9 then
		return nil
	end
	session.lastRoll = now

	local before = data.totalRolls
	local luck = getLuck(player, data)
	local results = {}
	for i = 1, 1 + data.multiRollLevel do
		local key = rollItem(luck)
		results[i] = key
		addToInventory(player, data, key, 1)
		announceIfRare(player, key)
	end
	data.totalRolls += #results
	data.rebirthRolls += #results
	setStat(player, "Rolls", data.totalRolls)
	if before < Config.AutoRollUnlock and data.totalRolls >= Config.AutoRollUnlock then
		toast(player, "toastAutoUnlocked", {}, Color3.fromRGB(90, 200, 140))
	end
	pushState(player)
	return results
end

---------------------------------------------------------------- actions
local actions = {}

function actions.Place(player, data, cellKey, itemKey)
	local index = World.plotOf(player)
	if not index or not inBounds(data, cellKey) or not Items.parse(itemKey) then
		return
	end
	if not World.isNearPlot(player, index) then
		return toast(player, "toastTooFar")
	end
	if not data.slabs[cellKey] then
		return toast(player, "needSlab")
	end
	if not takeFromInventory(data, itemKey, 1) then
		return
	end
	local old = data.grid[cellKey]
	if old then
		addToInventory(player, data, old.id, 1)
	end
	data.grid[cellKey] = { id = itemKey, age = 0 }
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
	if World.distanceTo(player, World.ForgePosition) > Config.ForgeReach then
		return toast(player, "toastTooFar")
	end
	local nextStar = Stars.List[star.index + 1]
	if not nextStar then
		return
	end
	if (data.inventory[itemKey] or 0) < Config.ForgeAmount then
		return toast(player, "toastNeedSame", { Config.ForgeAmount })
	end
	if not spend(player, data, nextStar.income * Config.ForgeCostMult) then
		return
	end
	takeFromInventory(data, itemKey, Config.ForgeAmount)
	local result = Items.key(nextStar.id, mutation.id)
	addToInventory(player, data, result, 1)
	toast(player, "toastForged", { { item = result } }, nextStar.color)
	if Items.chance(result) >= Config.AnnounceChance then
		announceAll("annForged", { player.DisplayName, { item = result } }, nextStar.color)
	end
end

-- Forge upgrade: N copies of a star -> 1 copy with the next mutation
function actions.UpgradeMutation(player, data, itemKey)
	local star, mutation = Items.parse(itemKey)
	if not star then
		return
	end
	if World.distanceTo(player, World.ForgePosition) > Config.ForgeReach then
		return toast(player, "toastTooFar")
	end
	local nextMutation = Mutations.List[mutation.index + 1]
	if not nextMutation then
		return
	end
	if (data.inventory[itemKey] or 0) < nextMutation.copies then
		return toast(player, "toastNeedSame", { nextMutation.copies })
	end
	local result = Items.key(star.id, nextMutation.id)
	if not spend(player, data, Config.UpgradeCost(star, Stars.List[star.index + 1], nextMutation)) then
		return
	end
	takeFromInventory(data, itemKey, nextMutation.copies)
	addToInventory(player, data, result, 1)
	toast(player, "toastForged", { { item = result } }, nextMutation.color)
end

function actions.Feed(player, data, itemKey, count)
	if not Items.parse(itemKey) then
		return
	end
	if World.distanceTo(player, World.AltarPosition) > Config.AltarReach then
		return toast(player, "toastTooFar")
	end
	count = toCount(count, data.inventory[itemKey] or 0)
	if takeFromInventory(data, itemKey, count) then
		data.mass += Items.income(itemKey) * Config.SellMultiplier * count
	end
end

function actions.Rebirth(player, data)
	if World.distanceTo(player, World.AltarPosition) > Config.AltarReach then
		return toast(player, "toastTooFar")
	end
	if data.mass < Config.RebirthCost(data.rebirths) then
		return
	end
	data.rebirths += 1
	data.mass = 0
	data.inventory = {}
	data.grid = {}
	data.gridSize = Config.StartGridSize
	data.luckLevel = 0
	data.rollSpeedLevel = 0
	data.multiRollLevel = 0
	data.slabs = {}
	data.floors = 1
	data.freeSlabsGiven = false
	giveFreeSlabs(data)
	data.rebirthRolls = 0 -- roll rewards start over every rebirth
	data.milestones = {}
	setCash(player, data, 0)
	setStat(player, "Rebirths", data.rebirths)
	recompute(player, data)
	announceAll("annRebirth", { player.DisplayName, data.rebirths }, Color3.fromRGB(176, 110, 255))
end

function actions.BuyLuck(player, data)
	if data.luckLevel < Config.MaxLuckLevel and spend(player, data, Config.LuckCost(data.luckLevel)) then
		data.luckLevel += 1
	end
end

function actions.BuySpeed(player, data)
	if data.rollSpeedLevel < Config.MaxRollSpeedLevel and spend(player, data, Config.RollSpeedCost(data.rollSpeedLevel)) then
		data.rollSpeedLevel += 1
	end
end

function actions.BuyMulti(player, data)
	if data.multiRollLevel < Config.MaxMultiRollLevel and spend(player, data, Config.MultiRollCost(data.multiRollLevel)) then
		data.multiRollLevel += 1
	end
end

function actions.BuyFloor(player, data)
	if data.floors < Config.MaxFloors and spend(player, data, Config.FloorCost(data.floors + 1)) then
		data.floors += 1
		recompute(player, data)
	end
end

function actions.SetTheme(player, data, themeId)
	if type(themeId) == "string" and Config.ThemesById[themeId] and World.plotOf(player) then
		data.theme = themeId
		recompute(player, data)
	end
end

function actions.ClaimIndexRow(player, data, mutationId, tierNumber)
	local mutation = type(mutationId) == "string" and Mutations.ById[mutationId]
	local tier = type(tierNumber) == "number" and Config.IndexTiers[tierNumber]
	local claimKey = tostring(tierNumber) .. ":" .. tostring(mutationId)
	if not mutation or not tier or data.indexClaims[claimKey] then
		return
	end
	for i = tier.first, tier.last do
		local star = Stars.List[i]
		if star and not data.index[Items.key(star.id, mutationId)] then
			return
		end
	end
	data.indexClaims[claimKey] = true
	data.bonusLuck += tier.luck * (Config.IndexMutationMult[mutationId] or 1)
end

function actions.ClaimMilestone(player, data, number)
	local milestone = type(number) == "number" and Config.RollMilestones[number]
	local id = tostring(number)
	if not milestone or data.milestones[id] or data.rebirthRolls < milestone.rolls then
		return
	end
	data.milestones[id] = true
	if milestone.cash then
		setCash(player, data, data.cash + milestone.cash)
	end
	if milestone.luck then
		data.bonusLuck += milestone.luck
	end
	if milestone.item and Items.parse(milestone.item) then
		addToInventory(player, data, milestone.item, milestone.count or 1)
		toast(player, "toastReward", { { item = milestone.item } }, Items.parse(milestone.item).color)
	end
end

function actions.SetSetting(player, data, name, value)
	if (name == "music" or name == "sfx") and type(value) == "boolean" then
		data.settings[name] = value
	elseif name == "rareAlert" and type(value) == "number" and value == value and value >= 0 and value <= 1e15 then
		data.settings.rareAlert = value
	end
end

---------------------------------------------------------------- build mode: slabs
function actions.BuildSlab(player, data, cellKey, slabId)
	local index = World.plotOf(player)
	local slab = type(slabId) == "string" and Config.SlabsById[slabId]
	if not index or not slab or not inBounds(data, cellKey) then
		return
	end
	if not World.isNearPlot(player, index) then
		return toast(player, "toastTooFar")
	end
	if data.slabs[cellKey] == slab.id then
		return
	end
	if spend(player, data, slab.cost) then
		data.slabs[cellKey] = slab.id
		recompute(player, data)
	end
end

function actions.RemoveSlab(player, data, cellKey)
	local index = World.plotOf(player)
	local slab = type(cellKey) == "string" and Config.SlabsById[data.slabs[cellKey]]
	if not index or not slab then
		return
	end
	if not World.isNearPlot(player, index) then
		return toast(player, "toastTooFar")
	end
	local placed = data.grid[cellKey]
	if placed then
		data.grid[cellKey] = nil
		addToInventory(player, data, placed.id, 1)
	end
	data.slabs[cellKey] = nil
	setCash(player, data, data.cash + math.floor(slab.cost * Config.SlabRefund))
	recompute(player, data)
end

---------------------------------------------------------------- admin (checked on the server, see the handler below)
local function adminNumber(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
		return nil
	end
	return math.min(value, 1e300)
end

function actions.AdminCash(player, data, amount)
	amount = adminNumber(amount)
	if amount then
		setCash(player, data, data.cash + amount)
	end
end

function actions.AdminStar(player, data, itemKey, count)
	count = adminNumber(count)
	if Items.parse(itemKey) and count and count >= 1 then
		addToInventory(player, data, itemKey, math.floor(math.min(count, 1e6)))
	end
end

function actions.AdminRolls(player, data, amount)
	amount = adminNumber(amount)
	if amount then
		data.totalRolls += math.floor(math.min(amount, 1e9))
		data.rebirthRolls += math.floor(math.min(amount, 1e9))
		setStat(player, "Rolls", data.totalRolls)
	end
end

function actions.AdminMass(player, data, amount)
	amount = adminNumber(amount)
	if amount then
		data.mass += amount
	end
end

local startShower -- defined at the bottom
function actions.AdminShower(player, data)
	if startShower then
		task.spawn(startShower)
	end
end

function actions.AdminGlobalTest(player, data, itemKey)
	local key = if Items.parse(itemKey) then itemKey else "infinity|celestial"
	GlobalRareEv:FireAllClients(player.DisplayName, key, Items.chance(key))
	World.lightPillar(player, Items.parse(key).color)
end

function actions.Elevator(player, data, plotIndex, floor)
	if type(plotIndex) == "number" and type(floor) == "number" and World.isNearPlot(player, plotIndex) then
		World.teleportToFloor(player, plotIndex, math.floor(floor))
	end
end

function actions.SetLang(player, data, lang)
	if lang == "en" or lang == "ru" then
		data.lang = lang
	end
end

ActionEv.OnServerEvent:Connect(function(player, action, a, b)
	local handler = type(action) == "string" and actions[action]
	local data = DataService.get(player)
	if not handler or not data or not sessions[player] then
		return
	end
	if string.sub(action, 1, 5) == "Admin" and not isAdmin(player) then
		warn("[Admin] blocked " .. action .. " from " .. player.Name)
		return
	end
	handler(player, data, a, b)
	pushState(player)
end)

---------------------------------------------------------------- every second: income and aging
local function tickPlayer(player: Player, session)
	local data = DataService.get(player)
	if not data or not session.eval or not World.plotOf(player) then
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
				local oldKey = cell.id
				cell.id = Items.key(star.evolvesTo, mutation.id)
				cell.age = 0
				changed = true
				discover(player, data, cell.id)
				announceAll("annExploded", { player.DisplayName, { item = oldKey }, { item = cell.id } }, Stars.ById[star.evolvesTo].color)
			end
		end
	end
	if changed then
		recompute(player, data)
		pushState(player)
	end

	setCash(player, data, data.cash + incomePerSecond(player, data))
end

task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			task.spawn(tickPlayer, player, session)
		end
	end
end)

---------------------------------------------------------------- falling off the world: back to base, no death
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < -40 then
				root.AssemblyLinearVelocity = Vector3.zero
				character:PivotTo(World.spawnCFrame(player))
			end
		end
	end
end)

---------------------------------------------------------------- Star Shower
startShower = function()
	ReplicatedStorage:SetAttribute("ShowerEndsAt", workspace:GetServerTimeNow() + Config.ShowerDuration)
	announceAll("annShower", { Config.ShowerLuck, Format.time(Config.ShowerDuration) }, Color3.fromRGB(90, 170, 255))
	for player in sessions do
		pushState(player)
	end
	task.wait(Config.ShowerDuration)
	for player in sessions do
		pushState(player)
	end
end

task.spawn(function()
	while true do
		task.wait(Config.ShowerInterval)
		startShower()
	end
end)

---------------------------------------------------------------- Leaderboards: submit + refresh every 2 minutes
local function liveRows()
	local rows = {}
	for player in sessions do
		local data = DataService.get(player)
		if data then
			table.insert(rows, { player = player, data = data })
		end
	end
	return rows
end

task.spawn(function()
	task.wait(8)
	Leaderboards.refresh(liveRows())
	while true do
		task.wait(120)
		for _, row in liveRows() do
			Leaderboards.submit(row.player, row.data)
		end
		Leaderboards.refresh(liveRows())
	end
end)
