local Config = {}

-- Rolling
Config.AutoRollUnlock = 50 -- total rolls needed to unlock auto roll
Config.MaxRollSpeedLevel = 10
function Config.RollCooldown(level: number): number
	return math.max(0.3, 1 * 0.88 ^ level)
end
function Config.RollSpeedCost(level: number): number
	return math.floor(400 * 2.6 ^ level)
end
Config.MaxMultiRollLevel = 4 -- rolls per click = 1 + level
function Config.MultiRollCost(level: number): number
	return math.floor(5000 * 8 ^ level)
end

-- Museum on the plot: display spots along the walls, more floors can be bought
Config.SpotsPerFloor = 20 -- 7 on the left wall, 6 at the back, 7 on the right
Config.MaxFloors = 5
function Config.FloorCost(floor: number): number
	return math.floor(25000 * 25 ^ (floor - 2))
end
Config.StartGridSize = 4 -- legacy (old saves / admin)
Config.MaxGridSize = 8

-- Museum themes (free to switch)
Config.Themes = {
	{ id = "sky", wall = Color3.fromRGB(245, 245, 250), wallMat = Enum.Material.Marble, trim = Color3.fromRGB(236, 196, 100), trimMat = Enum.Material.SmoothPlastic, floor = Color3.fromRGB(232, 226, 214), floorMat = Enum.Material.Marble, light = Color3.fromRGB(255, 236, 200) },
	{ id = "hell", wall = Color3.fromRGB(70, 28, 26), wallMat = Enum.Material.Basalt, trim = Color3.fromRGB(255, 100, 30), trimMat = Enum.Material.Neon, floor = Color3.fromRGB(90, 35, 25), floorMat = Enum.Material.CrackedLava, light = Color3.fromRGB(255, 120, 60) },
	{ id = "cosmos", wall = Color3.fromRGB(28, 22, 58), wallMat = Enum.Material.Slate, trim = Color3.fromRGB(150, 110, 255), trimMat = Enum.Material.Neon, floor = Color3.fromRGB(18, 14, 40), floorMat = Enum.Material.Glass, light = Color3.fromRGB(170, 140, 255) },
	{ id = "ice", wall = Color3.fromRGB(205, 235, 255), wallMat = Enum.Material.Ice, trim = Color3.fromRGB(140, 210, 255), trimMat = Enum.Material.Glass, floor = Color3.fromRGB(225, 242, 255), floorMat = Enum.Material.Glacier, light = Color3.fromRGB(200, 235, 255) },
	{ id = "emerald", wall = Color3.fromRGB(225, 242, 228), wallMat = Enum.Material.Marble, trim = Color3.fromRGB(60, 200, 130), trimMat = Enum.Material.SmoothPlastic, floor = Color3.fromRGB(190, 225, 195), floorMat = Enum.Material.Marble, light = Color3.fromRGB(210, 255, 220) },
}
Config.ThemesById = {}
for _, theme in Config.Themes do
	Config.ThemesById[theme.id] = theme
end
Config.PlotReach = 52 -- how far from plot center you can place stars / build

-- Build mode: stars can only stand on slabs. Better slabs multiply the star's income.
Config.Slabs = {
	{ id = "stone", cost = 100, mult = 1, color = Color3.fromRGB(150, 152, 165), material = Enum.Material.Slate },
	{ id = "gold", cost = 50000, mult = 1.5, color = Color3.fromRGB(245, 196, 80), material = Enum.Material.Foil },
	{ id = "emerald", cost = 5000000, mult = 2.5, color = Color3.fromRGB(60, 210, 130), material = Enum.Material.Glass },
	{ id = "marble", cost = 1000000000, mult = 4, color = Color3.fromRGB(246, 246, 252), material = Enum.Material.Marble },
}
Config.SlabsById = {}
for index, slab in Config.Slabs do
	slab.index = index
	Config.SlabsById[slab.id] = slab
end
Config.FreeStoneSlabs = 4 -- new players start with these
Config.SlabRefund = 0.5 -- removing a slab gives back this share of its price

-- Movement
Config.WalkSpeed = 16
Config.SprintSpeed = 30

-- Luck
Config.LuckPerLevel = 0.5
Config.MaxLuckLevel = math.huge -- no limit
function Config.LuckCost(level: number): number
	return math.floor(150 * 1.6 ^ level)
end

Config.SellMultiplier = 20 -- sell value = income/s * this (also Black Hole mass)

-- Star Forge: ForgeAmount of the same item -> 1 of the next star (mutation kept)
Config.ForgeAmount = 5
Config.ForgeCostMult = 10 -- cash cost = next star income * this
Config.ForgeReach = 26

-- forge price of a star (5 -> next star) and of a mutation upgrade (1 -> same star, next mutation)
function Config.ForgeCost(star, nextStar): number
	return (nextStar or star).income * Config.ForgeCostMult
end
function Config.UpgradeCost(star, nextStar, nextMutation): number
	return math.floor(Config.ForgeCost(star, nextStar) * 3 * (nextMutation.chance / 1.5))
end

-- Black Hole / Rebirth
function Config.RebirthCost(rebirths: number): number
	return math.floor(100000 * 10 ^ rebirths)
end
Config.RebirthIncomeBonus = 2 -- income x(1 + rebirths * this)
Config.RebirthLuckMult = 0.5 -- luck x(1 + rebirths * this)
Config.AltarReach = 30

-- Star Index: split into tiers; each tier has a row per mutation. A complete row -> permanent luck.
do
	local Stars = require(script.Parent.Stars)
	Config.IndexTiers = {}
	local perTier = 9
	for first = 1, #Stars.List, perTier do
		local number = #Config.IndexTiers + 1
		table.insert(Config.IndexTiers, {
			first = first,
			last = math.min(first + perTier - 1, #Stars.List),
			luck = math.floor(0.25 * 1.8 ^ (number - 1) * 100) / 100,
		})
	end
end
-- extra luck for a row with a rarer mutation: luck * this
Config.IndexMutationMult = { normal = 1, shiny = 2, golden = 4, void = 8, celestial = 16 }

-- Constellations (shape bonuses) are switched off for now; flip to true to bring them back
Config.ConstellationsEnabled = false

-- Roll milestones (Roll Rewards window). Reward: cash / luck / item (+ count)
Config.RollMilestones = {
	{ rolls = 50, cash = 500 },
	{ rolls = 100, item = "sun", count = 1 },
	{ rolls = 250, luck = 0.25 },
	{ rolls = 500, item = "giant", count = 1 },
	{ rolls = 1000, cash = 50000 },
	{ rolls = 2500, item = "giant|golden", count = 1 },
	{ rolls = 5000, luck = 1 },
	{ rolls = 10000, item = "pulsar|shiny", count = 1 },
	{ rolls = 25000, cash = 5000000 },
	{ rolls = 50000, item = "neutron|golden", count = 1 },
	{ rolls = 100000, luck = 3 },
}

-- Star Shower: server-wide luck event
Config.ShowerInterval = 600
Config.ShowerDuration = 180
Config.ShowerLuck = 2

Config.AnnounceChance = 10000 -- announce items rarer than 1 in N
Config.GlobalRareChance = 1000000000 -- 1 in a billion and rarer: cinematic for the whole server
Config.UltraRevealChance = 500000 -- 1 in 500K and rarer: the long black-screen ultra reveal

-- ================= Daily chest (7-day streak). Cash grows with the player's income.
Config.DailyRewards = {
	{ cash = 2000 },
	{ boost = "luck", minutes = 15 },
	{ item = "redgiant", count = 3 },
	{ cash = 50000 },
	{ boost = "speed", minutes = 30 },
	{ item = "pulsar|shiny", count = 1 },
	{ item = "neutron|golden", count = 1, boost = "luck", minutes = 60 },
}
Config.DailyCooldown = 20 * 3600 -- a new reward every 20 hours
Config.DailyStreakLoss = 48 * 3600 -- miss more than 48 hours -> back to day 1
Config.DailyReach = 14
function Config.DailyCash(base: number, income: number): number
	return math.max(base, math.floor(income * 120))
end

-- every N rolls the next roll gets x2 luck (progress bar under the header)
Config.LuckyRoll = { every = 50, mult = 2 }

-- Admin panel: the game owner (if the game belongs to a user), these user IDs, and anyone in Studio tests
Config.AdminUserIds = {}

Config.AutosaveInterval = 120
Config.DataStoreName = "ConstellationsRNG_v1"

-- ================= Robux shop (Developer Products). id = 0 -> not created yet (free test purchases in Studio)
Config.Shop = {
	-- permanent, bought one after another, each tier much pricier
	speedTiers = {
		{ id = 0, price = 49 }, { id = 0, price = 149 }, { id = 0, price = 449 },
		{ id = 0, price = 1299 }, { id = 0, price = 3499 }, { id = 0, price = 9999 },
	},
	multiTiers = {
		{ id = 0, price = 99 }, { id = 0, price = 299 }, { id = 0, price = 899 },
		{ id = 0, price = 2499 }, { id = 0, price = 6999 },
	},
	luckBoosts = { { id = 0, price = 49, minutes = 15 }, { id = 0, price = 89, minutes = 30 }, { id = 0, price = 149, minutes = 60 } },
	speedBoosts = { { id = 0, price = 39, minutes = 15 }, { id = 0, price = 69, minutes = 30 }, { id = 0, price = 119, minutes = 60 } },
	-- paid random item: the odds are always shown before buying (Roblox rule)
	crate = {
		packs = { { id = 0, price = 99, count = 1 }, { id = 0, price = 249, count = 3 }, { id = 0, price = 799, count = 10 } },
		odds = {
			{ item = "hypergiant", p = 0.39 },
			{ item = "kilonova", p = 0.24 },
			{ item = "supernova", p = 0.18 },
			{ item = "magnetar", p = 0.12 },
			{ item = "etacarinae", p = 0.065 },
			{ item = "eventhorizon|golden", p = 0.005 },
		},
	},
}
Config.RobuxSpeedStep = 0.85 -- each speed tier: roll time x0.85

-- roll cooldown with every upgrade/boost (same formula on server and client)
function Config.EffectiveCooldown(data, now: number): number
	local cooldown = Config.RollCooldown(data.rollSpeedLevel or 0) * Config.RobuxSpeedStep ^ (data.robuxSpeed or 0)
	if (data.boostSpeedUntil or 0) > now then
		cooldown *= 0.5
	end
	return math.max(0.1, cooldown)
end

function Config.RollsPerClick(data): number
	return 1 + (data.multiRollLevel or 0) + (data.robuxMulti or 0)
end

-- Game pass IDs. 0 = not created yet
Config.GamePasses = {
	Luck2x = 0,
	Cash2x = 0,
}

-- Star icons: upload assets/icons/*.png to Roblox and paste the image IDs here.
-- Empty = drawn fallback circle.
Config.StarIcons = {
	dust = "88057257304175",
	spark = "95759760184166",
	dwarf = "108641320003033",
	sun = "110450191626991",
	giant = "87788328424963",
	pulsar = "101025474600822",
	neutron = "111195013890666",
	quasar = "84881845971446",
	supernova = "118384507441772",
	magnetar = "128331602873383",
	nebula = "80310128810215",
	whitehole = "104117385727434",
	galaxy = "77000251679559",
	cosmic = "109629805308709",
	bigbang = "89853132357952",
	infinity = "97010309864023",
	browndwarf = "122219079213891",
	whitedwarf = "99936181938781",
	redgiant = "132862981123128",
	binary = "136388952276344",
	wolfrayet = "106037066020635",
	hypergiant = "73599949491582",
	kilonova = "",
	eventhorizon = "130974260909735",
	darkmatter = "119288797918952",
	multiverse = "82842345020371",
	cosmicweb = "127974564338567",
	tarantula = "123461818609017",
	sgra = "83094720206032",
	crab = "82952577689950",
	catseye = "95691637097229",
	r136a1 = "104836728930765",
	polaris = "90914236497013",
	vycma = "72733119044409",
	quasar3c273 = "71869625658553",
	sombrero = "139179750417158",
	canopus = "118670464850146",
	cygnusx1 = "93855375341192",
	sgr1806 = "114268005931850",
	przybylski = "79651415993461",
	antares = "133530052254963",
	capella = "128365757101406",
	lagoon = "77800780879420",
	tabby = "121136077862040",
	arcturus = "136967584858281",
	rigel = "129215265229548",
	procyon = "85472242928493",
	deneb = "139863159535101",
	helix = "131708372907605",
	tycho = "85061805605116",
	betelgeuse = "114246982847890",
	stephenson = "83914423488804",
	triangulum = "81304937631722",
	crabpulsar = "118531779655048",
	sn1987a = "125899262161824",
	vela = "122680715959272",
	spica = "94529889701180",
	achernar = "119183086522446",
	altair = "105809618647246",
	aldebaran = "81995092900761",
	whirlpool = "72672089543141",
	eagle = "93070181389880",
	ton618 = "134472432610677",
	horsehead = "109288878392815",
	andromeda = "107702880617095",
	uyscuti = "130122821572177",
	proxima = "74336715909517",
	ringneb = "71948079613438",
	algol = "123781888335562",
	sirius = "111552954312549",
	hoag = "129591721557417",
	mira = "138541845763737",
	vega = "103122323717926",
	etacarinae = "123635141173829",
	kepler = "129281011786240",
	einstein = "103369165914547",
	orion = "99434913869769",
}

-- UI icons (assets/icons/ui_*.png). Same as StarIcons: paste uploaded image IDs.
Config.UiIcons = {
	catalogue = "107402829607762",
	sky = "104272326719626",
	upgrades = "76865058340757",
	index = "93310774370747",
	constellations = "129859327315009",
	odds = "89101290443368",
	rewards = "88325511755224",
	cash = "98757200307701",
	luck = "137487992289485",
	rolls = "97966246674669",
	settings = "104579262501708",
	coins = "129002927140322", -- ui_coins.png (header cash)
	income = "128510907463165", -- ui_income.png (header per second)
	rebirth = "73756458949010", -- ui_rebirth.png
	build = "81422090060014", -- ui_build.png
	codes = "", -- ui_codes.png
}

-- Audio (assets/audio/*.ogg): upload and paste the IDs.
-- Music can hold several tracks; they play one after another.
Config.Sounds = {
	Music = { "70905224258341" },
	MusicVolume = 0.12,
	Rebirth = "73693601629586",
	GlobalRare = "", -- empty = uses the rebirth sound
	RebirthVolume = 0.8,
}

return Config
