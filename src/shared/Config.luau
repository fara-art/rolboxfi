local Config = {}

Config.RollCooldown = 1 -- seconds between rolls

Config.StartGridSize = 4
Config.MaxGridSize = 8
-- cost to expand the sky from size to size + 1
function Config.GridCost(size: number): number
	return math.floor(1000 * 8 ^ (size - Config.StartGridSize))
end

Config.LuckPerLevel = 0.25
Config.MaxLuckLevel = 40
function Config.LuckCost(level: number): number
	return math.floor(150 * 1.6 ^ level)
end

Config.SellMultiplier = 20 -- sell value = income/s * this (also Black Hole mass)

-- Star Forge: ForgeAmount of the same item -> 1 of the next star (mutation kept)
Config.ForgeAmount = 5
Config.ForgeCostMult = 10 -- cash cost = next star income * this

-- Black Hole / Rebirth
function Config.RebirthCost(rebirths: number): number
	return math.floor(100000 * 10 ^ rebirths)
end
Config.RebirthIncomeBonus = 1 -- income x(1 + rebirths * this)
Config.RebirthLuckBonus = 0.5 -- luck + rebirths * this

-- Comets: fly across the screen, click for a lucky roll
Config.CometMinDelay = 40
Config.CometMaxDelay = 90
Config.CometLifetime = 8
Config.CometLuck = 5

-- Star Shower: server-wide luck event
Config.ShowerInterval = 600
Config.ShowerDuration = 180
Config.ShowerLuck = 2

Config.AnnounceChance = 10000 -- announce items rarer than 1 in N

Config.AutosaveInterval = 120
Config.DataStoreName = "ConstellationsRNG_v1"

-- Game pass IDs. 0 = not created yet (AutoRoll with 0 is free, for testing)
Config.GamePasses = {
	Luck2x = 0,
	Cash2x = 0,
	AutoRoll = 0,
}

return Config
