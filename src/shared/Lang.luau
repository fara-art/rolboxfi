-- All player-facing text. Lang.t(lang, key, ...) -> string.format(template, ...)
local Items = require(script.Parent.Items)

local Lang = {}

Lang.Strings = {
	en = {
		cash = "CASH", perSec = "PER SEC", luck = "LUCK", rolls = "ROLLS", rebirths = "REBIRTHS",
		telescope = "TELESCOPE", rollHint = "Roll for a star", roll = "ROLL", rollN = "ROLL x%d",
		autoOn = "AUTO: ON", autoOff = "AUTO: OFF", autoLocked = "AUTO  %d/%d",
		oneIn = "1 in %s", andMore = "+%d more", totalRolls = "Total rolls: %s",
		catalogue = "CATALOGUE", mySky = "MY SKY", upgrades = "UPGRADES", index = "INDEX",
		constellations = "CONSTELLATIONS", odds = "ODDS",
		oddsTitle = "ODDS AT YOUR LUCK", mutations = "MUTATIONS",
		perSecShort = "+%s/s", sellsFor = "Sells for %s",
		sell1 = "SELL 1", sellAll = "SELL ALL", emptyCatalogue = "Roll to find stars",
		tip = "Walk onto a free plot to claim it. Press E at a pedestal to place a star — stars earn only on your plot.",
		skyNoPlot = "Claim a plot first: walk onto a free one.",
		skyHint = "This is your plot from above. Place stars at the pedestals.",
		pickTitle = "PLACE A STAR", pickEmpty = "No stars yet. Roll first!",
		forgeTitle = "STAR FORGE", forgeHint = "%d of the same star + cash = the next star. Mutation is kept.",
		forgeBtn = "FORGE  %s", forgeMax = "Top star, can't forge", forgeHave = "%d/%d",
		holeTitle = "BLACK HOLE", mass = "%s / %s mass", holeFeed = "Feed it stars to grow its mass.",
		holeNow = "Now: income x%s, luck +%s", holeNext = "After rebirth: income x%s, luck +%s",
		holeWarn = "Rebirth resets cash, stars, plot and upgrades. Index and constellations stay.",
		rebirth = "REBIRTH", notEnough = "NOT ENOUGH MASS", feed1 = "FEED 1", feedAll = "FEED ALL",
		upLuck = "Luck", upSpeed = "Roll speed", upMulti = "Multi roll", upSky = "Plot size",
		upMax = "MAX", buy = "BUY  %s",
		upLuckDesc = "x%s → x%s", upSpeedDesc = "%ss → %ss", upMultiDesc = "%d → %d per roll", upSkyDesc = "%dx%d → %dx%d",
		indexTitle = "STAR INDEX", tabStars = "STARS", tabRolls = "ROLL REWARDS",
		claim = "CLAIM", claimed = "CLAIMED", rewardLuck = "+%s luck", rewardCash = "+%s cash", rollsReq = "%s rolls",
		rowReward = "Complete the row: +%s luck forever",
		bookTitle = "CONSTELLATION BOOK", unknown = "Unknown", nStars = "%d stars", incomeX = "income x%s",
		bookHint = "Place stars on pedestals in exactly this shape, with no extra neighbours (diagonals count). All stars of one kind: another x%s.",
		shower = "STAR SHOWER  x%s LUCK  %s",
		annDiscover = "%s discovered %s (x%s)", annRolled = "%s rolled %s (1 in %s)", annForged = "%s forged %s",
		annExploded = "%s's %s exploded into %s!", annRebirth = "%s was reborn from the Black Hole (rebirth %s)",
		annShower = "STAR SHOWER! x%s luck for %s",
		toastForged = "Forged %s", toastNeedCash = "Need %s cash", toastNeedSame = "Need %d of the same star",
		toastNewIndex = "New in the Index: %s", toastClaimed = "This plot is yours!", toastNotYours = "This is not your plot",
		toastTooFar = "Come closer", toastAutoUnlocked = "Auto roll unlocked!", toastHavePlot = "You already have a plot",
		signFree = "FREE PLOT\nstep in to claim", signPlot = "%s's plot\n+%s/s",
		signForge = "STAR FORGE", signHole = "BLACK HOLE", signHub = "SKY HAVEN",
		promptPlace = "Place star", promptRemove = "Take star", promptForge = "Forge", promptHole = "Black Hole", pedestal = "Pedestal",
		rewardsTitle = "ROLL REWARDS", rewards = "REWARDS", rewardsDone = "ROLLS DONE", nextReward = "Next reward",
		moreRolls = "%s more rolls", allDone = "All rewards reached!", locked = "LOCKED", cashWord = "Cash", luckWord = "Luck", rollsWord = "ROLLS", toastReward = "Reward: %s",
		settings = "SETTINGS", music = "Music", sfx = "Sounds", on = "ON", off = "OFF", rebirthBig = "REBIRTH!", rareBig = "RARE!", legendBig = "LEGENDARY!",
		langButton = "EN",
	},
	ru = {
		cash = "ДЕНЬГИ", perSec = "В СЕКУНДУ", luck = "УДАЧА", rolls = "КРУТКИ", rebirths = "ПЕРЕРОЖД.",
		telescope = "ТЕЛЕСКОП", rollHint = "Крути звезду", roll = "КРУТИТЬ", rollN = "КРУТИТЬ x%d",
		autoOn = "АВТО: ВКЛ", autoOff = "АВТО: ВЫКЛ", autoLocked = "АВТО  %d/%d",
		oneIn = "1 к %s", andMore = "ещё +%d", totalRolls = "Всего круток: %s",
		catalogue = "КАТАЛОГ", mySky = "МОЁ НЕБО", upgrades = "УЛУЧШЕНИЯ", index = "ИНДЕКС",
		constellations = "СОЗВЕЗДИЯ", odds = "ШАНСЫ",
		oddsTitle = "ШАНСЫ С ТВОЕЙ УДАЧЕЙ", mutations = "МУТАЦИИ",
		perSecShort = "+%s/с", sellsFor = "Продажа: %s",
		sell1 = "ПРОДАТЬ 1", sellAll = "ПРОДАТЬ ВСЕ", emptyCatalogue = "Крути, чтобы найти звёзды",
		tip = "Зайди на свободный участок, чтобы занять его. Нажми E у постамента, чтобы поставить звезду — деньги приносят только звёзды на участке.",
		skyNoPlot = "Сначала займи участок: просто зайди на свободный.",
		skyHint = "Это твой участок сверху. Ставь звёзды на постаменты.",
		pickTitle = "ПОСТАВИТЬ ЗВЕЗДУ", pickEmpty = "Звёзд пока нет. Сначала покрути!",
		forgeTitle = "ЗВЁЗДНАЯ КУЗНЯ", forgeHint = "%d одинаковых звёзд + деньги = следующая звезда. Мутация сохраняется.",
		forgeBtn = "КОВАТЬ  %s", forgeMax = "Это лучшая звезда", forgeHave = "%d/%d",
		holeTitle = "ЧЁРНАЯ ДЫРА", mass = "%s / %s массы", holeFeed = "Корми её звёздами, чтобы росла масса.",
		holeNow = "Сейчас: доход x%s, удача +%s", holeNext = "После перерождения: доход x%s, удача +%s",
		holeWarn = "Перерождение сбрасывает деньги, звёзды, участок и улучшения. Индекс и созвездия остаются.",
		rebirth = "ПЕРЕРОДИТЬСЯ", notEnough = "МАЛО МАССЫ", feed1 = "СКОРМИТЬ 1", feedAll = "СКОРМИТЬ ВСЕ",
		upLuck = "Удача", upSpeed = "Скорость крутки", upMulti = "Мульти-крутка", upSky = "Размер участка",
		upMax = "МАКС", buy = "КУПИТЬ  %s",
		upLuckDesc = "x%s → x%s", upSpeedDesc = "%sс → %sс", upMultiDesc = "%d → %d за раз", upSkyDesc = "%dx%d → %dx%d",
		indexTitle = "ИНДЕКС ЗВЁЗД", tabStars = "ЗВЁЗДЫ", tabRolls = "НАГРАДЫ ЗА КРУТКИ",
		claim = "ЗАБРАТЬ", claimed = "ПОЛУЧЕНО", rewardLuck = "+%s удачи", rewardCash = "+%s денег", rollsReq = "%s круток",
		rowReward = "Собери ряд: +%s удачи навсегда",
		bookTitle = "КНИГА СОЗВЕЗДИЙ", unknown = "Неизвестно", nStars = "звёзд: %d", incomeX = "доход x%s",
		bookHint = "Ставь звёзды на постаменты ровно такой фигурой, без лишних соседей (диагонали тоже считаются). Все звёзды одного вида: ещё x%s.",
		shower = "ЗВЕЗДОПАД  x%s УДАЧИ  %s",
		annDiscover = "%s открыл созвездие %s (x%s)", annRolled = "%s выбил %s (1 к %s)", annForged = "%s выковал %s",
		annExploded = "У %s звезда %s взорвалась в %s!", annRebirth = "%s переродился из Чёрной дыры (перерождение %s)",
		annShower = "ЗВЕЗДОПАД! x%s удачи на %s",
		toastForged = "Выковано: %s", toastNeedCash = "Нужно %s денег", toastNeedSame = "Нужно %d одинаковых звёзд",
		toastNewIndex = "Новое в индексе: %s", toastClaimed = "Участок теперь твой!", toastNotYours = "Это не твой участок",
		toastTooFar = "Подойди ближе", toastAutoUnlocked = "Автокрутка открыта!", toastHavePlot = "У тебя уже есть участок",
		signFree = "СВОБОДНЫЙ УЧАСТОК\nзайди, чтобы занять", signPlot = "Участок %s\n+%s/с",
		signForge = "ЗВЁЗДНАЯ КУЗНЯ", signHole = "ЧЁРНАЯ ДЫРА", signHub = "НЕБЕСНАЯ ГАВАНЬ",
		promptPlace = "Поставить звезду", promptRemove = "Забрать звезду", promptForge = "Ковать", promptHole = "Чёрная дыра", pedestal = "Постамент",
		rewardsTitle = "НАГРАДЫ ЗА КРУТКИ", rewards = "НАГРАДЫ", rewardsDone = "КРУТОК СДЕЛАНО", nextReward = "Следующая награда",
		moreRolls = "ещё %s круток", allDone = "Все награды открыты!", locked = "ЗАКРЫТО", cashWord = "Деньги", luckWord = "Удача", rollsWord = "КРУТОК", toastReward = "Награда: %s",
		settings = "НАСТРОЙКИ", music = "Музыка", sfx = "Звуки", on = "ВКЛ", off = "ВЫКЛ", rebirthBig = "ПЕРЕРОЖДЕНИЕ!", rareBig = "РЕДКАЯ!", legendBig = "ЛЕГЕНДАРНАЯ!",
		langButton = "RU",
	},
}

Lang.StarNames = {
	ru = {
		dust = "Звёздная пыль", spark = "Искра", dwarf = "Красный карлик", sun = "Жёлтое солнце", giant = "Голубой гигант",
		pulsar = "Пульсар", neutron = "Нейтронная звезда", quasar = "Квазар", supernova = "Сверхновая",
	},
}

Lang.MutationNames = {
	ru = { normal = "Обычная", shiny = "Сияние", golden = "Золото", void = "Пустота", celestial = "Небеса" },
}

Lang.ConstellationNames = {
	ru = {
		pair = "Двойная звезда", triangle = "Летний треугольник", belt = "Пояс Ориона", pegasus = "Квадрат Пегаса",
		rhombus = "Ромб Дельфина", cross = "Южный Крест", cassiopeia = "Кассиопея", dipper = "Большая Медведица", ring = "Кольцо Галактики",
	},
}

function Lang.t(lang: string, key: string, ...): string
	local strings = Lang.Strings[lang] or Lang.Strings.en
	local template = strings[key] or Lang.Strings.en[key] or key
	if select("#", ...) > 0 then
		local ok, result = pcall(string.format, template, ...)
		return if ok then result else template
	end
	return template
end

function Lang.star(lang: string, star): string
	local names = Lang.StarNames[lang]
	return names and names[star.id] or star.name
end

function Lang.mutation(lang: string, mutation): string
	local names = Lang.MutationNames[lang]
	return names and names[mutation.id] or mutation.name
end

function Lang.constellation(lang: string, pattern): string
	local names = Lang.ConstellationNames[lang]
	return names and names[pattern.id] or pattern.name
end

-- "Golden Pulsar" / "Пульсар · Золото"
function Lang.item(lang: string, key: string): string
	local star, mutation = Items.parse(key)
	if not star then
		return "?"
	end
	if mutation.id == "normal" then
		return Lang.star(lang, star)
	end
	if lang == "ru" then
		return Lang.star(lang, star) .. " · " .. Lang.mutation(lang, mutation)
	end
	return mutation.name .. " " .. star.name
end

-- Server sends messages as { key, args } where an arg may be { item = key } or { constellation = id }.
function Lang.resolve(lang: string, key: string, args: { any }?): string
	local Constellations = require(script.Parent.Constellations)
	local out = {}
	for i, arg in args or {} do
		if type(arg) == "table" and arg.item then
			out[i] = Lang.item(lang, arg.item)
		elseif type(arg) == "table" and arg.constellation then
			local pattern = Constellations.ById[arg.constellation]
			out[i] = if pattern then Lang.constellation(lang, pattern) else "?"
		else
			out[i] = tostring(arg)
		end
	end
	return Lang.t(lang, key, table.unpack(out))
end

return Lang
