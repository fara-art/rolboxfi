local Config = {}

Config.RollCooldown = 1 -- секунд между крутками

Config.StartGridSize = 4
Config.MaxGridSize = 8
-- цена расширения неба с size до size + 1
function Config.GridCost(size: number): number
	return math.floor(1000 * 8 ^ (size - Config.StartGridSize))
end

Config.LuckPerLevel = 0.25
Config.MaxLuckLevel = 40
function Config.LuckCost(level: number): number
	return math.floor(150 * 1.6 ^ level)
end

Config.SellMultiplier = 20 -- продажа звезды = доход/с * это

-- Звездопад: событие на весь сервер
Config.ShowerInterval = 600
Config.ShowerDuration = 180
Config.ShowerLuck = 2

Config.AnnounceChance = 10000 -- объявлять на сервер звёзды от 1 к N

Config.AutosaveInterval = 120
Config.DataStoreName = "ConstellationsRNG_v1"

-- ID геймпассов. 0 = ещё не создан (AutoRoll при 0 доступен всем, для тестов)
Config.GamePasses = {
	Luck2x = 0,
	Cash2x = 0,
	AutoRoll = 0,
}

return Config
