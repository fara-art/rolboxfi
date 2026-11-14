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

-- Plot (pedestal grid)
Config.StartGridSize = 4
Config.MaxGridSize = 8
function Config.GridCost(size: number): number
	return math.floor(1000 * 8 ^ (size - Config.StartGridSize))
end
Config.PlotReach = 52 -- how far from plot center you can place stars

-- Luck
Config.LuckPerLevel = 0.25
Config.MaxLuckLevel = 40
function Config.LuckCost(level: number): number
	return math.floor(150 * 1.6 ^ level)
end

Config.SellMultiplier = 20 -- sell value = income/s * this (also Black Hole mass)

-- Star Forge: ForgeAmount of the same item -> 1 of the next star (mutation kept)
Config.ForgeAmount = 5
Config.ForgeCostMult = 10 -- cash cost = next star income * this
Config.ForgeReach = 26

-- Black Hole / Rebirth
function Config.RebirthCost(rebirths: number): number
	return math.floor(100000 * 10 ^ rebirths)
end
Config.RebirthIncomeBonus = 1 -- income x(1 + rebirths * this)
Config.RebirthLuckBonus = 0.5 -- luck + rebirths * this
Config.AltarReach = 30

-- Star Index: complete a mutation row (all stars) -> claim permanent luck
Config.IndexRowLuck = 0.5

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

Config.AutosaveInterval = 120
Config.DataStoreName = "ConstellationsRNG_v1"

-- Game pass IDs. 0 = not created yet
Config.GamePasses = {
	Luck2x = 0,
	Cash2x = 0,
}

-- Star icons: upload assets/icons/*.png to Roblox and paste the image IDs here.
-- Empty = drawn fallback circle.
Config.StarIcons = {
	dust = "",
	spark = "",
	dwarf = "",
	sun = "",
	giant = "",
	pulsar = "",
	neutron = "",
	quasar = "",
	supernova = "",
}

-- UI icons (assets/icons/ui_*.png). Same as StarIcons: paste uploaded image IDs.
Config.UiIcons = {
	catalogue = "",
	sky = "",
	upgrades = "",
	index = "",
	constellations = "",
	odds = "",
	rewards = "",
	cash = "",
	luck = "",
	rolls = "",
	settings = "",
}

-- Audio (assets/audio/*.ogg): upload and paste the IDs.
-- Music can hold several tracks; they play one after another.
Config.Sounds = {
	Music = { "" },
	MusicVolume = 0.3,
	Rebirth = "",
	RebirthVolume = 0.8,
}

return Config
