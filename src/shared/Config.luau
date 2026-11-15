local Config = {}

-- Rolling
Config.AutoRollUnlock = 50 -- total rolls needed to unlock auto roll
Config.MaxRollSpeedLevel = 10
function Config.RollCooldown(level: number): number
	return math.max(0.3, 1 * 0.88 ^ level)
end
-- price of the NEXT level; a wide spread so it takes the whole game to max out
Config.RollSpeedPrices = { 500, 6000, 50000, 400000, 3000000, 25000000, 200000000, 1500000000, 12000000000, 100000000000 }
function Config.RollSpeedCost(level: number): number
	return Config.RollSpeedPrices[level + 1] or math.huge
end
Config.MaxMultiRollLevel = 4 -- rolls per click = 1 + level
Config.MultiRollPrices = { 2500, 200000, 25000000, 5000000000 }
function Config.MultiRollCost(level: number): number
	return Config.MultiRollPrices[level + 1] or math.huge
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
	return math.floor(100 * 1.4 ^ level) -- cheaper: luck is the main way to progress
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
	return math.floor(Config.ForgeCost(star, nextStar) * 10 * (nextMutation.chance / 1.5))
end

-- Black Hole / Rebirth
function Config.RebirthCost(rebirths: number): number
	return math.floor(100000 * 10 ^ rebirths)
end
Config.RebirthIncomeBonus = 2 -- income x(1 + rebirths * this)
Config.RebirthLuckMult = 0.5 -- luck x(1 + rebirths * this)

-- Rebirth tokens: +1 per rebirth, spent on permanent upgrades (they survive rebirths)
Config.RebirthUpgrades = {
	{ id = "luck", icon = "luck", per = 0.25, max = 20 }, -- luck x(1 + 0.25 * level)
	{ id = "cash", icon = "coins", per = 0.5, max = 20 }, -- income x(1 + 0.5 * level)
	{ id = "speed", icon = "bolt", per = 0.05, max = 10 }, -- rolls 5% faster per level
	{ id = "multi", icon = "dice2", per = 1, max = 3 }, -- +1 star per roll
	{ id = "pets", icon = "pets", per = 1, max = 4 }, -- +1 pet slot
}

-- Expeditions: send stars away for a few hours from the launch pad on the hub
Config.Expedition = {
	hours = { 1, 2, 4, 8 },
	maxStars = 5,
	cashFactor = 0.5, -- cash = income/s of the sent stars * seconds away * this
	tokenPerHour = 0.03, -- chance of a rebirth token (8 h = 24%)
	mutatePerHour = 0.025, -- chance per star to come back one mutation higher (8 h = 20%)
	reach = 24,
	studioSecondsPerHour = 10, -- Studio tests: one "hour" lasts 10 s
}

-- Constellations: show all stars of a set in your museum (any mutation) -> income bonus + it lights up above the museum
Config.ConstellationSets = {
	{ id = "dipper", stars = { "dust", "spark", "browndwarf", "dwarf" }, bonus = 0.1 },
	{ id = "orion", stars = { "sun", "redgiant", "giant", "binary", "pulsar" }, bonus = 0.25 },
	{ id = "cassiopeia", stars = { "wolfrayet", "neutron", "hypergiant", "quasar" }, bonus = 0.5 },
	{ id = "triangle", stars = { "sirius", "vega", "altair", "procyon", "arcturus" }, bonus = 1 },
	{ id = "crown", stars = { "eagle", "horsehead", "lagoon", "tarantula" }, bonus = 2 },
	{ id = "arc", stars = { "triangulum", "whirlpool", "sombrero", "andromeda" }, bonus = 4 },
}

-- Museum likes: weekly top 3 get rebirth tokens
Config.LikeRewards = { 3, 2, 1 }
function Config.RebirthUpCost(level: number): number
	return level + 1 -- tokens
end
function Config.RebirthUp(data, id: string): number
	return (data and data.rebirthUps and data.rebirthUps[id]) or 0
end
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
	-- "DOUBLE your LUCK / SPEED": every tier adds one more x, every tier costs more
	luckTiers = {
		{ id = 0, price = 3 }, { id = 0, price = 8 }, { id = 0, price = 25 }, { id = 0, price = 50 },
		{ id = 0, price = 99 }, { id = 0, price = 199 }, { id = 0, price = 399 }, { id = 0, price = 799 },
	},
	speedTiers = {
		{ id = 0, price = 5 }, { id = 0, price = 15 }, { id = 0, price = 45 },
		{ id = 0, price = 99 }, { id = 0, price = 249 }, { id = 0, price = 599 },
	},
	-- coin packs: you get at least `base`, or `minutes` of your income if that is more
	coins = {
		{ id = 0, price = 25, base = 10000, minutes = 10, key = "coinSmall" },
		{ id = 0, price = 125, base = 50000, minutes = 45, key = "coinMedium" },
		{ id = 0, price = 600, base = 300000, minutes = 240, key = "coinBig" },
		{ id = 0, price = 2250, base = 1200000, minutes = 900, key = "coinMega" },
		{ id = 0, price = 6750, base = 5000000, minutes = 2880, key = "coinGigantic" },
	},
	multiTiers = {
		{ id = 0, price = 99 }, { id = 0, price = 299 }, { id = 0, price = 899 },
		{ id = 0, price = 2499 }, { id = 0, price = 6999 },
	},
	luckBoosts = { { id = 0, price = 49, minutes = 15 }, { id = 0, price = 89, minutes = 30 }, { id = 0, price = 149, minutes = 60 } },
	speedBoosts = { { id = 0, price = 39, minutes = 15 }, { id = 0, price = 69, minutes = 30 }, { id = 0, price = 119, minutes = 60 } },
	-- paid random item: the odds are always shown before buying (Roblox rule)
	crate = {
		packs = { { id = 0, price = 99, count = 1 }, { id = 0, price = 249, count = 3 }, { id = 0, price = 799, count = 10 }, { id = 0, price = 3499, count = 50, oldPrice = 5959 } },
		odds = {
			{ item = "hypergiant", p = 0.39 },
			{ item = "quasar", p = 0.24 },
			{ item = "supernova", p = 0.18 },
			{ item = "magnetar", p = 0.12 },
			{ item = "etacarinae", p = 0.065 },
			{ item = "eventhorizon|golden", p = 0.005 },
		},
	},
}
Config.RobuxSpeedStep = 0.85 -- each speed tier: roll time x0.85

-- roll cooldown with every upgrade/boost (same formula on server and client)
-- speed multiplier from bought tiers: x1 -> x1.5 -> x2 -> ...
function Config.RobuxSpeedMult(tiers: number): number
	return 1 + 0.5 * tiers
end

function Config.CoinPack(pack, income: number): number
	return math.max(pack.base, math.floor(income * pack.minutes * 60))
end

function Config.EffectiveCooldown(data, now: number, passes): number
	local cooldown = Config.RollCooldown(data.rollSpeedLevel or 0) / Config.RobuxSpeedMult(data.robuxSpeed or 0) / (1 + 0.05 * Config.RebirthUp(data, "speed"))
	if (data.boostSpeedUntil or 0) > now then
		cooldown *= 0.5
	end
	if passes and passes.FastRolls then
		cooldown /= 1.25
	end
	cooldown /= 1 + (data.petSpeed or 0) -- mutated pets
	return math.max(0.1, cooldown)
end

function Config.RollsPerClick(data, passes): number
	return 1 + (data.multiRollLevel or 0) + (data.robuxMulti or 0) + Config.RebirthUp(data, "multi") + (if passes and passes.ExtraRoll then 1 else 0)
end

function Config.LuckyEvery(passes): number
	return if passes and passes.LuckyHunter then 25 else Config.LuckyRoll.every
end

-- Game pass IDs. 0 = not created yet
-- Game passes (one-time Robux purchases). id = 0 -> not created yet (free test in Studio)
Config.Passes = {
	{ key = "ExtraRoll", id = 0, price = 699, icon = "pass_extraroll", top = Color3.fromRGB(80, 200, 255), bottom = Color3.fromRGB(30, 90, 230) },
	{ key = "FastRolls", id = 0, price = 199, icon = "pass_fastrolls", top = Color3.fromRGB(255, 190, 80), bottom = Color3.fromRGB(240, 90, 30) },
	{ key = "VIP", id = 0, price = 199, icon = "pass_vip", top = Color3.fromRGB(255, 240, 120), bottom = Color3.fromRGB(240, 170, 20) },
	{ key = "Luck2x", id = 0, price = 480, icon = "pass_luck2x", top = Color3.fromRGB(130, 240, 140), bottom = Color3.fromRGB(30, 160, 80) },
	{ key = "Cash2x", id = 0, price = 330, icon = "pass_cash2x", top = Color3.fromRGB(255, 220, 110), bottom = Color3.fromRGB(220, 140, 20) },
	{ key = "LuckyHunter", id = 0, price = 640, icon = "pass_luckyhunter", top = Color3.fromRGB(200, 120, 255), bottom = Color3.fromRGB(90, 40, 200) },
}
Config.GamePasses = {}
for _, pass in Config.Passes do
	Config.GamePasses[pass.key] = pass.id
end

-- Star icons: upload assets/icons/*.png to Roblox and paste the image IDs here.
-- Empty = drawn fallback circle.
Config.StarIcons = {
	-- seasonal stars (assets/seasonal_upload.zip)
	frostcomet = "81175787024013",
	icenova = "135635151967740",
	aurorastar = "133750262700477",
	glacierpulsar = "116430703344687",
	wintercrown = "103925340474775",
	embercomet = "96664330336382",
	phoenixstar = "129939371462471",
	solarflare = "97553297287638",
	magmapulsar = "118574565752039",
	infernocrown = "74373398033857",
	petalcomet = "115091431046783",
	bloomnova = "115703507420552",
	springstar = "74897878037772",
	emeraldpulsar = "71378680976619",
	verdantcrown = "95400792421694",
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
	kilonova = "115649708668880",
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
	upgrades = "117562119988324",
	index = "81523855539161",
	constellations = "129859327315009",
	odds = "131820832311248",
	rewards = "139935111395488",
	cash = "98757200307701",
	luck = "137487992289485",
	rolls = "83836984571464",
	settings = "93907162392542",
	coins = "129002927140322", -- ui_coins.png (header cash)
	income = "86803937711887", -- ui_income.png (header per second)
	rebirth = "95148629177835", -- ui_rebirth.png
	build = "110351772050148", -- ui_build.png
	codes = "79945267436720", -- ui_codes.png
	robux = "88925874604658", -- ui_robux.png
	crate = "103907162035497", -- ui_crate.png
	shop = "110650125502781", -- ui_shop.png
	crown = "82112958345651", -- ui_crown.png
	bolt = "82339824773311", -- ui_bolt.png
	dice2 = "136163108916637", -- ui_dice2.png
	target = "129463744030485", -- ui_target.png
	trash = "136882546836414",
	museum = "103453143351358", -- ui_museum.png ("My museum" teleport button)
	forge = "109351671873293", -- ui_forge.png
	pets = "105949137779821", -- ui_pets.png (pet slots)
	expedition = "", -- ui_expedition.png (rocket)
	blackhole = "89016344401227", -- ui_blackhole.png -- ui_trash.png
	backpack = "86024249124101", -- ui_backpack.png (inventory)
	roll = "85946183739046", -- ui_roll.png (big ROLL dice)
	trade = "121704980641198", -- ui_trade.png (two arrows)
	crateBg = "129630863310767", -- optional painted background for the featured crate (shop)
	-- ChatGPT art (assets/gpt): empty = falls back to the older icon in Config.UiIconFallback
	coins_small = "133136353755983", -- coins_small.png
	coins_big = "115845941365325", -- coins_big.png
	boost_luck = "116932441361556", -- boost_luck.png
	boost_speed = "118140738424878", -- boost_speed.png
	pass_extraroll = "132124631207548", -- pass_extraroll.png
	pass_fastrolls = "77255633028064", -- pass_fastrolls.png
	pass_vip = "81329674146883", -- pass_vip.png
	pass_luck2x = "133008111301100", -- pass_luck2x.png
	pass_cash2x = "125093220405508", -- pass_cash2x.png
	pass_luckyhunter = "98097466780495", -- pass_luckyhunter.png
}
Config.UiIconFallback = {
	pets = "luck", expedition = "rolls", coins_small = "coins", coins_big = "coins", boost_luck = "luck", boost_speed = "bolt",
	pass_extraroll = "dice2", pass_fastrolls = "bolt", pass_vip = "crown", pass_luck2x = "luck", pass_cash2x = "coins", pass_luckyhunter = "target",
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
