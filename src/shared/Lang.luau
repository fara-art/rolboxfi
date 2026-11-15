-- All player-facing text. Lang.t(lang, key, ...) -> string.format(template, ...)
local Items = require(script.Parent.Items)

local Lang = {}

Lang.Strings = {
	en = {
		cash = "CASH", perSec = "PER SEC", luck = "LUCK", rolls = "ROLLS", rebirths = "REBIRTHS",
		language = "Language", upTabCash = "UPGRADES", upTabRebirth = "REBIRTH", rebirthTokens = "Rebirth tokens: %d", tokensCost = "%d TOKENS",
		rup_luck = "Luck", rup_cash = "Income", rup_speed = "Roll speed", rup_multi = "Extra star",
		petsFull = "Pet slots are full (%d)", petEquip = "EQUIP", petUnequip = "UNEQUIP", petInfo = "+%d%% luck   +%d%% speed", toastSeasonalNoUpgrade = "Seasonal stars can't get mutations", toastBoughtLevels = "Bought %d levels!", offlineEarned = "While you were away (%s) your museum earned +%s", upMaxBtn = "MAX", petsTitle = "PETS %d/%d   +%d%% luck   +%d%% speed",
		petsHint = "Pick a star below and press EQUIP: it will orbit you and add luck", rup_pets = "Pet slots",
		expTitle = "EXPEDITIONS", signExpedition = "EXPEDITIONS", promptExpedition = "Expeditions",
		expHint = "Send up to %d stars away. They come back with cash, sometimes a better mutation or a rebirth token.",
		expHours = "%dh", expStart = "SEND", expEstimate = "Reward: ~%s cash", expAway = "Your stars are on an expedition",
		expLeft = "Back in %s", expReady = "They're back!", expClaim = "COLLECT", expCancel = "CALL BACK (no reward)",
		expSent = "Expedition started: %d h", expBack = "Stars are back! +%s cash, %d mutated",
		expBackToken = "Stars are back! +%s cash, %d mutated, +1 rebirth token!", expPick = "Tap stars to send (%d/%d)",
		set_dipper = "Little Dipper", set_orion = "Orion", set_cassiopeia = "Cassiopeia", set_triangle = "Summer Triangle",
		set_crown = "Nebula Crown", set_arc = "Galactic Arc", setBonus = "+%d%% income", setActive = "ACTIVE",
		setsHint = "Display every star of a set in your museum (any mutation): it lights up above the museum and boosts income.",
		promptLike = "Like", likeAlready = "You already liked this museum this week", likeSent = "You liked %s's museum!",
		likeGot = "%s liked your museum!", likeReward = "Your museum was #%d last week! +%d rebirth tokens",
		likesShort = "%d likes", lbLikes = "TOP MUSEUMS (WEEK)", seasonLine = "Season: %s, ends in %s",
		season_frost = "Frost", season_ember = "Ember", season_bloom = "Bloom", seasonTag = "SEASON",
		forgeTab = "FORGE", fusionTab = "FUSION", fuseHint = "Put two DIFFERENT stars in and press FUSE. Some pairs make a secret hybrid star you can't roll. Wrong pairs cost nothing.",
		fuseBtn = "FUSE", fuseBtnCost = "FUSE  $%s", fuseFound = "Hybrids found: %d / %d", fusePick = "tap to put on the bench",
		fuseNothing = "Nothing happened... try another pair", fuseDiscovered = "%s discovered a new hybrid: %s!",
		unionTitle = "STAR UNION", signUnion = "STAR UNION", promptUnion = "Star Union portal",
		unionHint = "Everyone on the server throws stars into the portal. When it's full, the WHOLE server gets x%d luck for %s!",
		unionActive = "x%d LUCK for everyone! %s", unionResting = "The portal is resting: %s", unionPoints = "+%d points", unionAll = "ALL",
		unionFull = "%s filled the Star Union portal! Everyone: x%d luck for %s!",
		fallingStar = "A star is falling on the hub! Run and catch it!", caughtStar = "%s caught a falling star: %s (1/%s)!", promptCatch = "Catch the star!",
		telescope = "TELESCOPE", rollHint = "Roll for a star", roll = "ROLL!", rollN = "ROLL x%d", inventory = "Inventory", rollAnim = "Roll animation",
		autoOn = "AUTO: ON", autoOff = "AUTO: OFF", autoLocked = "AUTO  %d/%d",
		oneIn = "1/%s", andMore = "+%d more", totalRolls = "Total rolls: %s",
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
		forgeBtn = "FORGE  %s", forgeMax = "Top star, can't forge", forgeHybrid = "Hybrid star: made only by fusion", forgeSeasonal = "Seasonal star: can't be forged", forgeHave = "%d/%d",
		holeTitle = "BLACK HOLE", mass = "%s / %s mass", holeFeed = "Feed it stars to grow its mass.",
		holeNow = "Now: income x%s, luck x%s", holeNext = "After rebirth: income x%s, luck x%s",
		holeWarn = "Rebirth resets cash, stars, plot and upgrades. Index and constellations stay.",
		rebirth = "REBIRTH", notEnough = "NOT ENOUGH MASS", feed1 = "FEED 1", feedAll = "FEED ALL",
		upLuck = "Luck", upSpeed = "Roll speed", upMulti = "Multi roll", upSky = "Plot size",
		upMax = "MAX", buy = "BUY  %s",
		upLuckDesc = "x%s → x%s", upSpeedDesc = "%ss → %ss", upMultiDesc = "%d → %d per roll", upSkyDesc = "%dx%d → %dx%d",
		indexTitle = "STAR INDEX", tabStars = "STARS", tabRolls = "ROLL REWARDS",
		claim = "CLAIM", claimed = "CLAIMED", rewardLuck = "+%s luck", rewardCash = "+%s cash", rollsReq = "%s rolls",
		rowReward = "Reward: +%s luck forever + %s", luckyBar = "x%s LUCK in %d rolls",
		shopFeatured = "FEATURED", shopPasses = "GAMEPASSES", shopMoney = "MONEY", shopLuckSpeed = "LUCK & SPEED", shopBoosts = "BOOSTS",
		newBadge = "New!", topDrop = "TOP DROP!", crates = "%d Crates", crate1 = "1 Crate",
		pass_ExtraRoll = "EXTRA Roll!", passDesc_ExtraRoll = "+1 roll per click", pass_FastRolls = "Fast Rolls!", passDesc_FastRolls = "+25% roll speed",
		pass_VIP = "VIP!", passDesc_VIP = "[VIP] tag + x1.5 cash", pass_Luck2x = "2x Luck!", passDesc_Luck2x = "x2 luck forever",
		pass_Cash2x = "2x Cash!", passDesc_Cash2x = "x2 cash forever", pass_LuckyHunter = "Lucky Hunter!", passDesc_LuckyHunter = "x2 luck roll every 25 rolls",
		owned = "OWNED", coinSmall = "Small Coin Pack", coinMedium = "Medium Coin Pack!", coinBig = "Big Coin Pack!", coinMega = "Mega Coin Pack!", coinGigantic = "Gigantic Coin Pack",
		doubleLuck = "DOUBLE Your LUCK", doubleSpeed = "DOUBLE Your SPEED", giftTo = "GIFT TO...", giftNobody = "Nobody else is on the server", giftSent = "Gift for %s!",
		giftGot = "%s sent you a gift!", tapToClose = "tap anywhere to close",
		trade = "TRADE", tradeTitle = "TRADE", tradePlayers = "TRADE WITH...", tradeSend = "TRADE", tradeNobody = "Nobody else is on the server",
		tradeRequest = "%s wants to trade with you!", accept = "ACCEPT", decline = "DECLINE", tradeSent = "Trade request sent to %s",
		tradeDeclined = "%s declined the trade", tradeBusy = "That player is busy", tradeCancelled = "Trade cancelled", tradeDone = "Trade complete!",
		tradeFailed = "Trade failed: items changed", tradeYou = "YOU", tradeReady = "READY", tradeNotReady = "NOT READY", tradeIn = "Trading in %d...",
		tradeAdd = "Your stars (tap + to offer)", tradeInfo = "%s · 1/%s · +%s/s · sells for %s",
		shop = "SHOP", featured = "FEATURED", crateName = "CELESTIAL CRATE", crateOdds = "Drop chances (shown before you buy)", crateBuy = "%d CRATE  R$ %s",
		boosts = "BOOSTS", luckBoost = "x2 Luck", speedBoost = "x2 Roll speed", minutes = "%d min", forever = "FOREVER",
		permSpeed = "Faster rolls", permSpeedDesc = "level %d → %d  (-15%% roll time)", permMulti = "Extra roll per click", permMultiDesc = "%d → %d rolls per click",
		buyRobux = "R$ %s", notConfigured = "This item isn't set up yet", luckActive = "x2 LUCK %s", speedActive = "x2 SPEED %s", crateGot = "YOU GOT", skyMode = "Sky", day = "DAY", night = "NIGHT",
		dailyTitle = "DAILY REWARDS", dayN = "DAY %d", dailyClaim = "CLAIM DAY %d", dailyWait = "NEXT IN %s", signDaily = "DAILY REWARD",
		rewardBoost = "x2 %s %d min", luckWord2 = "luck", speedWord2 = "speed", dailyHint = "Come back every day! Miss 2 days and the streak starts over.",
		codes = "CODES", codeHint = "Enter a code", redeem = "REDEEM", codeOk = "Code activated!", codeBad = "Wrong or expired code", codeUsed = "You already used this code",
		tutTitle = "TUTORIAL  %d/%d", tutNext = "NEXT", tutDone = "LET'S GO!",
		tut1 = "Press ROLL to find your first stars!", tut2 = "Walk into a free museum (follow the light) to claim it.",
		tut3 = "Go inside and press E at a stand to place a star.", tut4 = "Stars on stands earn cash every second. Spend it on UPGRADES to roll better!",
		tut5 = "The daily chest, the Star Forge and the Black Hole wait on the main island. Have fun!", luckyNow = "x%s LUCK ROLL!",
		bookTitle = "CONSTELLATION BOOK", unknown = "Unknown", nStars = "%d stars", incomeX = "income x%s",
		bookHint = "Place stars on pedestals in exactly this shape, with no extra neighbours (diagonals count). All stars of one kind: another x%s.",
		shower = "STAR SHOWER  x%s LUCK  %s",
		annDiscover = "%s discovered %s (x%s)", annRolled = "%s rolled %s (1/%s)", chatRareHere = "⭐ %s just rolled %s (1 in %s)!", chatRareGlobal = "🌌 [GLOBAL] %s rolled %s (1 in %s) on another server!", annForged = "%s forged %s",
		annExploded = "%s's %s exploded into %s!", annRebirth = "%s was reborn from the Black Hole (rebirth %s)",
		annShower = "STAR SHOWER! x%s luck for %s",
		toastForged = "Forged %s", toastNeedCash = "Need %s cash", toastNeedSame = "Need %d of the same star",
		toastNewIndex = "New in the Index: %s", toastClaimed = "This plot is yours!", toastNotYours = "This is not your plot",
		toastTooFar = "Come closer", toastAutoUnlocked = "Auto roll unlocked!", toastHavePlot = "You already have a plot",
		signFree = "FREE MUSEUM\nstep in to claim", signPlot = "%s\'s museum\n+%s/s",
		signForge = "STAR FORGE", signHole = "BLACK HOLE", signHub = "STAR RNG",
		promptPlace = "Place star", promptRemove = "Take star", promptForge = "Forge", promptHole = "Black Hole", pedestal = "Pedestal",
		rewardsTitle = "ROLL REWARDS", rewards = "REWARDS", rewardsDone = "ROLLS THIS REBIRTH", nextReward = "Next reward",
		moreRolls = "%s more rolls", allDone = "All rewards reached!", locked = "LOCKED", cashWord = "Cash", luckWord = "Luck", rollsWord = "ROLLS", toastReward = "Reward: %s",
		settings = "SETTINGS", music = "Music", sfx = "Sounds", on = "ON", off = "OFF", rebirthBig = "REBIRTH!", rareBig = "RARE!", legendBig = "LEGENDARY!",
		admin = "ADMIN", adminCash = "Give cash", adminStar = "Give star", adminRolls = "Add rolls", adminMass = "Add Black Hole mass",
		adminEvents = "Events", adminShower = "START STAR SHOWER", adminGlobal = "TEST SERVER ANIMATION", give = "GIVE",
		amountHint = "e.g. 5Qd or 1e15", countHint = "count", globalFound = "%s found",
		upFloor = "Museum floors", upFloorDesc = "%d → %d floors", promptElevator = "Next floor", confirmPlace = "Build here?", theme = "THEME", customAlert = "Your own:  1 /",
		theme_sky = "Sky", theme_hell = "Hell", theme_cosmos = "Dark Cosmos", theme_ice = "Ice", theme_emerald = "Emerald",
		upgradeBtn = "UPGRADE  %s", upgradeTo = "%s: x%s rarer, x%s income", elevatorTitle = "ELEVATOR", floorN = "FLOOR %d", mutationsInfo = "Mutations are not rolled: upgrade stars at the Star Forge.", confirmRemove = "Remove this slab?", rareAlert = "Big reveal from", alertOff = "OFF", farFromPlot = "Go to your plot to build",
		lbRolls = "TOP ROLLS", lbRebirths = "TOP REBIRTHS", lbCash = "RICHEST", lbRarest = "RAREST FINDS", lbEmpty = "No records yet",
		build = "BUILD", buildTitle = "BUILD MODE", buildHint = "Pick a slab and tap a free spot on your plot.", removeTool = "REMOVE", exitBuild = "EXIT",
		slab_stone = "Stone slab", slab_gold = "Gold slab", slab_emerald = "Emerald slab", slab_marble = "Marble slab",
		onPlot = "+%d on plot", needSlab = "Build a slab here first", buildNoPlot = "Claim a plot first", home = "MY MUSEUM",
		langButton = "EN",
	},
	ru = {
		cash = "ДЕНЬГИ", perSec = "В СЕКУНДУ", luck = "УДАЧА", rolls = "КРУТКИ", rebirths = "ПЕРЕРОЖД.",
		language = "Язык", upTabCash = "УЛУЧШЕНИЯ", upTabRebirth = "ПЕРЕРОЖДЕНИЕ", rebirthTokens = "Токены перерождения: %d", tokensCost = "%d ТОКЕН(ОВ)",
		rup_luck = "Удача", rup_cash = "Доход", rup_speed = "Скорость ролла", rup_multi = "Доп. звезда",
		petsFull = "Все слоты питомцев заняты (%d)", petEquip = "НАДЕТЬ", petUnequip = "СНЯТЬ", petInfo = "+%d%% удачи   +%d%% скорости", toastSeasonalNoUpgrade = "Сезонным звёздам мутации нельзя", toastBoughtLevels = "Куплено уровней: %d!", offlineEarned = "Пока тебя не было (%s), музей заработал +%s", upMaxBtn = "МАКС", petsTitle = "ПИТОМЦЫ %d/%d   +%d%% удачи   +%d%% скорости",
		petsHint = "Выбери звезду ниже и нажми «НАДЕТЬ»: она будет летать вокруг тебя и давать удачу", rup_pets = "Слоты питомцев",
		expTitle = "ЭКСПЕДИЦИИ", signExpedition = "ЭКСПЕДИЦИИ", promptExpedition = "Экспедиции",
		expHint = "Отправь до %d звёзд в полёт. Вернутся с деньгами, иногда с мутацией или токеном перерождения.",
		expHours = "%dч", expStart = "ОТПРАВИТЬ", expEstimate = "Награда: ~%s", expAway = "Твои звёзды в экспедиции",
		expLeft = "Вернутся через %s", expReady = "Вернулись!", expClaim = "ЗАБРАТЬ", expCancel = "ВЕРНУТЬ (без награды)",
		expSent = "Экспедиция началась: %d ч", expBack = "Звёзды вернулись! +%s, мутаций: %d",
		expBackToken = "Звёзды вернулись! +%s, мутаций: %d, +1 токен перерождения!", expPick = "Нажми на звёзды, чтобы отправить (%d/%d)",
		set_dipper = "Малая Медведица", set_orion = "Орион", set_cassiopeia = "Кассиопея", set_triangle = "Летний треугольник",
		set_crown = "Корона туманностей", set_arc = "Галактическая дуга", setBonus = "+%d%% дохода", setActive = "АКТИВНО",
		setsHint = "Поставь в музей все звёзды набора (любая мутация): созвездие загорится над музеем и увеличит доход.",
		promptLike = "Лайк", likeAlready = "Ты уже лайкал этот музей на этой неделе", likeSent = "Ты лайкнул музей игрока %s!",
		likeGot = "%s лайкнул твой музей!", likeReward = "Твой музей занял #%d на прошлой неделе! +%d токенов перерождения",
		likesShort = "Лайков: %d", lbLikes = "ТОП МУЗЕЕВ НЕДЕЛИ", seasonLine = "Сезон: %s, закончится через %s",
		season_frost = "Мороз", season_ember = "Пламя", season_bloom = "Цветение", seasonTag = "СЕЗОН",
		forgeTab = "КУЗНЯ", fusionTab = "СИНТЕЗ", fuseHint = "Положи две РАЗНЫЕ звезды и жми «СИНТЕЗ». Некоторые пары дают секретную гибридную звезду, её не выбить роллом. Неверная пара ничего не стоит.",
		fuseBtn = "СИНТЕЗ", fuseBtnCost = "СИНТЕЗ  $%s", fuseFound = "Найдено гибридов: %d / %d", fusePick = "нажми, чтобы положить на стол",
		fuseNothing = "Ничего не вышло... попробуй другую пару", fuseDiscovered = "%s открыл новый гибрид: %s!",
		unionTitle = "ЗВЁЗДНЫЙ СОЮЗ", signUnion = "ЗВЁЗДНЫЙ СОЮЗ", promptUnion = "Портал Звёздного союза",
		unionHint = "Все игроки сервера кидают звёзды в портал. Когда он заполнится, ВЕСЬ сервер получит x%d удачи на %s!",
		unionActive = "x%d УДАЧИ всем! %s", unionResting = "Портал отдыхает: %s", unionPoints = "+%d очков", unionAll = "ВСЕ",
		unionFull = "%s заполнил портал Звёздного союза! Всем x%d удачи на %s!",
		fallingStar = "На хаб падает звезда! Беги и лови!", caughtStar = "%s поймал падающую звезду: %s (1/%s)!", promptCatch = "Поймать звезду!",
		telescope = "ТЕЛЕСКОП", rollHint = "Крути звезду", roll = "КРУТИТЬ!", rollN = "КРУТИТЬ x%d", inventory = "Инвентарь", rollAnim = "Анимация ролла",
		autoOn = "АВТО: ВКЛ", autoOff = "АВТО: ВЫКЛ", autoLocked = "АВТО  %d/%d",
		oneIn = "1/%s", andMore = "ещё +%d", totalRolls = "Всего круток: %s",
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
		forgeBtn = "КОВАТЬ  %s", forgeMax = "Это лучшая звезда", forgeHybrid = "Гибрид: только через синтез", forgeSeasonal = "Сезонная звезда: ковать нельзя", forgeHave = "%d/%d",
		holeTitle = "ЧЁРНАЯ ДЫРА", mass = "%s / %s массы", holeFeed = "Корми её звёздами, чтобы росла масса.",
		holeNow = "Сейчас: доход x%s, удача x%s", holeNext = "После перерождения: доход x%s, удача x%s",
		holeWarn = "Перерождение сбрасывает деньги, звёзды, участок и улучшения. Индекс и созвездия остаются.",
		rebirth = "ПЕРЕРОДИТЬСЯ", notEnough = "МАЛО МАССЫ", feed1 = "СКОРМИТЬ 1", feedAll = "СКОРМИТЬ ВСЕ",
		upLuck = "Удача", upSpeed = "Скорость крутки", upMulti = "Мульти-крутка", upSky = "Размер участка",
		upMax = "МАКС", buy = "КУПИТЬ  %s",
		upLuckDesc = "x%s → x%s", upSpeedDesc = "%sс → %sс", upMultiDesc = "%d → %d за раз", upSkyDesc = "%dx%d → %dx%d",
		indexTitle = "ИНДЕКС ЗВЁЗД", tabStars = "ЗВЁЗДЫ", tabRolls = "НАГРАДЫ ЗА КРУТКИ",
		claim = "ЗАБРАТЬ", claimed = "ПОЛУЧЕНО", rewardLuck = "+%s удачи", rewardCash = "+%s денег", rollsReq = "%s круток",
		rowReward = "Награда: +%s удачи навсегда + %s", luckyBar = "x%s УДАЧА через %d",
		shopFeatured = "ГЛАВНОЕ", shopPasses = "ГЕЙМПАССЫ", shopMoney = "МОНЕТЫ", shopLuckSpeed = "УДАЧА И СКОРОСТЬ", shopBoosts = "БУСТЫ",
		newBadge = "Новинка!", topDrop = "ТОП ДРОП!", crates = "%d ящиков", crate1 = "1 ящик",
		pass_ExtraRoll = "Доп. крутка!", passDesc_ExtraRoll = "+1 крутка за раз", pass_FastRolls = "Быстрые крутки!", passDesc_FastRolls = "+25% скорости круток",
		pass_VIP = "VIP!", passDesc_VIP = "Тег [VIP] + x1.5 денег", pass_Luck2x = "x2 Удача!", passDesc_Luck2x = "x2 удачи навсегда",
		pass_Cash2x = "x2 Деньги!", passDesc_Cash2x = "x2 денег навсегда", pass_LuckyHunter = "Охотник за удачей!", passDesc_LuckyHunter = "x2 удача каждые 25 круток",
		owned = "КУПЛЕНО", coinSmall = "Маленький мешочек", coinMedium = "Средний мешок!", coinBig = "Большой мешок!", coinMega = "Мега мешок!", coinGigantic = "Гигантский мешок",
		doubleLuck = "УДВОЙ свою УДАЧУ", doubleSpeed = "УДВОЙ свою СКОРОСТЬ", giftTo = "ПОДАРИТЬ...", giftNobody = "На сервере больше никого нет", giftSent = "Подарок для %s!",
		giftGot = "%s прислал тебе подарок!", tapToClose = "нажми, чтобы закрыть",
		trade = "ОБМЕН", tradeTitle = "ОБМЕН", tradePlayers = "ОБМЕН С...", tradeSend = "ОБМЕН", tradeNobody = "На сервере больше никого нет",
		tradeRequest = "%s хочет обменяться с тобой!", accept = "ПРИНЯТЬ", decline = "ОТКЛОНИТЬ", tradeSent = "Запрос на обмен отправлен: %s",
		tradeDeclined = "%s отклонил обмен", tradeBusy = "Этот игрок занят", tradeCancelled = "Обмен отменён", tradeDone = "Обмен завершён!",
		tradeFailed = "Обмен сорвался: звёзды изменились", tradeYou = "ТЫ", tradeReady = "ГОТОВ", tradeNotReady = "НЕ ГОТОВ", tradeIn = "Обмен через %d...",
		tradeAdd = "Твои звёзды (жми +, чтобы предложить)", tradeInfo = "%s · 1/%s · +%s/с · продажа %s",
		shop = "МАГАЗИН", featured = "ГЛАВНОЕ", crateName = "НЕБЕСНЫЙ ЯЩИК", crateOdds = "Шансы выпадения (видны до покупки)", crateBuy = "%d ЯЩ.  R$ %s",
		boosts = "БУСТЫ", luckBoost = "x2 Удача", speedBoost = "x2 Скорость круток", minutes = "%d мин", forever = "НАВСЕГДА",
		permSpeed = "Быстрые крутки", permSpeedDesc = "уровень %d → %d  (-15%% времени)", permMulti = "+1 крутка за раз", permMultiDesc = "%d → %d за раз",
		buyRobux = "R$ %s", notConfigured = "Этот товар ещё не настроен", luckActive = "x2 УДАЧА %s", speedActive = "x2 СКОРОСТЬ %s", crateGot = "ВЫПАЛО", skyMode = "Небо", day = "ДЕНЬ", night = "НОЧЬ",
		dailyTitle = "ЕЖЕДНЕВНЫЕ НАГРАДЫ", dayN = "ДЕНЬ %d", dailyClaim = "ЗАБРАТЬ ДЕНЬ %d", dailyWait = "СЛЕДУЮЩАЯ ЧЕРЕЗ %s", signDaily = "ЕЖЕДНЕВНАЯ НАГРАДА",
		rewardBoost = "x2 %s %d мин", luckWord2 = "удача", speedWord2 = "скорость", dailyHint = "Заходи каждый день! Пропустишь 2 дня — серия начнётся заново.",
		codes = "КОДЫ", codeHint = "Введи код", redeem = "АКТИВИРОВАТЬ", codeOk = "Код активирован!", codeBad = "Неверный или устаревший код", codeUsed = "Ты уже использовал этот код",
		tutTitle = "ОБУЧЕНИЕ  %d/%d", tutNext = "ДАЛЕЕ", tutDone = "ПОГНАЛИ!",
		tut1 = "Жми КРУТИТЬ, чтобы найти первые звёзды!", tut2 = "Зайди в свободный музей (иди по лучу), чтобы занять его.",
		tut3 = "Зайди внутрь и нажми E у постамента, чтобы поставить звезду.", tut4 = "Звёзды на постаментах приносят деньги каждую секунду. Трать их на УЛУЧШЕНИЯ!",
		tut5 = "Ежедневный сундук, Звёздная кузня и Чёрная дыра ждут на главном острове. Удачи!", luckyNow = "КРУТКА С x%s УДАЧЕЙ!",
		bookTitle = "КНИГА СОЗВЕЗДИЙ", unknown = "Неизвестно", nStars = "звёзд: %d", incomeX = "доход x%s",
		bookHint = "Ставь звёзды на постаменты ровно такой фигурой, без лишних соседей (диагонали тоже считаются). Все звёзды одного вида: ещё x%s.",
		shower = "ЗВЕЗДОПАД  x%s УДАЧИ  %s",
		annDiscover = "%s открыл созвездие %s (x%s)", annRolled = "%s выбил %s (1/%s)", chatRareHere = "⭐ %s выбил %s (1 к %s)!", chatRareGlobal = "🌌 [ГЛОБАЛЬНО] %s выбил %s (1 к %s) на другом сервере!", annForged = "%s выковал %s",
		annExploded = "У %s звезда %s взорвалась в %s!", annRebirth = "%s переродился из Чёрной дыры (перерождение %s)",
		annShower = "ЗВЕЗДОПАД! x%s удачи на %s",
		toastForged = "Выковано: %s", toastNeedCash = "Нужно %s денег", toastNeedSame = "Нужно %d одинаковых звёзд",
		toastNewIndex = "Новое в индексе: %s", toastClaimed = "Участок теперь твой!", toastNotYours = "Это не твой участок",
		toastTooFar = "Подойди ближе", toastAutoUnlocked = "Автокрутка открыта!", toastHavePlot = "У тебя уже есть участок",
		signFree = "СВОБОДНЫЙ МУЗЕЙ\nзайди, чтобы занять", signPlot = "Музей %s\n+%s/с",
		signForge = "ЗВЁЗДНАЯ КУЗНЯ", signHole = "ЧЁРНАЯ ДЫРА", signHub = "STAR RNG",
		promptPlace = "Поставить звезду", promptRemove = "Забрать звезду", promptForge = "Ковать", promptHole = "Чёрная дыра", pedestal = "Постамент",
		rewardsTitle = "НАГРАДЫ ЗА КРУТКИ", rewards = "НАГРАДЫ", rewardsDone = "КРУТОК ЗА ПЕРЕРОЖДЕНИЕ", nextReward = "Следующая награда",
		moreRolls = "ещё %s круток", allDone = "Все награды открыты!", locked = "ЗАКРЫТО", cashWord = "Деньги", luckWord = "Удача", rollsWord = "КРУТОК", toastReward = "Награда: %s",
		settings = "НАСТРОЙКИ", music = "Музыка", sfx = "Звуки", on = "ВКЛ", off = "ВЫКЛ", rebirthBig = "ПЕРЕРОЖДЕНИЕ!", rareBig = "РЕДКАЯ!", legendBig = "ЛЕГЕНДАРНАЯ!",
		admin = "АДМИНКА", adminCash = "Выдать деньги", adminStar = "Выдать звезду", adminRolls = "Добавить крутки", adminMass = "Добавить массу дыры",
		adminEvents = "События", adminShower = "ЗАПУСТИТЬ ЗВЕЗДОПАД", adminGlobal = "ТЕСТ АНИМАЦИИ СЕРВЕРА", give = "ВЫДАТЬ",
		amountHint = "напр. 5Qd или 1e15", countHint = "кол-во", globalFound = "%s нашёл",
		upFloor = "Этажи музея", upFloorDesc = "%d → %d этажей", promptElevator = "Следующий этаж", confirmPlace = "Построить здесь?", theme = "ТЕМА", customAlert = "Своё:  1 /",
		theme_sky = "Небо", theme_hell = "Ад", theme_cosmos = "Тёмный космос", theme_ice = "Лёд", theme_emerald = "Изумруд",
		upgradeBtn = "УЛУЧШИТЬ  %s", upgradeTo = "%s: в %s раза реже, доход x%s", elevatorTitle = "ЛИФТ", floorN = "ЭТАЖ %d", mutationsInfo = "Мутации не выпадают: улучшай звёзды в Звёздной кузне.", confirmRemove = "Убрать эту плиту?", rareAlert = "Большая анимация от", alertOff = "ВЫКЛ", farFromPlot = "Подойди к своему участку",
		lbRolls = "ТОП КРУТОК", lbRebirths = "ТОП ПЕРЕРОЖДЕНИЙ", lbCash = "САМЫЕ БОГАТЫЕ", lbRarest = "САМЫЕ РЕДКИЕ", lbEmpty = "Пока пусто",
		build = "СТРОИТЬ", buildTitle = "СТРОИТЕЛЬСТВО", buildHint = "Выбери плиту и нажми на свободное место участка.", removeTool = "УБРАТЬ", exitBuild = "ВЫЙТИ",
		slab_stone = "Каменная плита", slab_gold = "Золотая плита", slab_emerald = "Изумрудная плита", slab_marble = "Мраморная плита",
		onPlot = "+%d на участке", needSlab = "Сначала построй тут плиту", buildNoPlot = "Сначала займи участок", home = "МОЙ МУЗЕЙ",
		langButton = "RU",
	},
}

Lang.StarNames = {
	ru = {
		twinkle = "Мерцающая звезда", greydwarf = "Сумеречный карлик", crimsonsun = "Багровое солнце", violetgiant = "Фиолетовый гигант",
		trinary = "Тройная звезда", beacon = "Космический маяк", stormstar = "Штормовая звезда", blazar = "Блазар",
		goldenkilonova = "Золотая килоновая", twinlights = "Огни-близнецы", chimera = "Туманность Химера", milkomeda = "Млечномеда",
		frostcomet = "Морозная комета", icenova = "Ледяная новая", aurorastar = "Звезда сияния", glacierpulsar = "Ледниковый пульсар",
		wintercrown = "Зимняя корона", embercomet = "Тлеющая комета", phoenixstar = "Звезда феникса", solarflare = "Солнечная вспышка",
		magmapulsar = "Магмовый пульсар", infernocrown = "Огненная корона", petalcomet = "Лепестковая комета", bloomnova = "Цветущая новая",
		springstar = "Весенняя звезда", emeraldpulsar = "Изумрудный пульсар", verdantcrown = "Зелёная корона",
		dust = "Звёздная пыль", spark = "Искра", dwarf = "Красный карлик", sun = "Жёлтое солнце", giant = "Голубой гигант",
		pulsar = "Пульсар", neutron = "Нейтронная звезда", quasar = "Квазар", supernova = "Сверхновая",
		magnetar = "Магнетар", nebula = "Сердце туманности", whitehole = "Белая дыра", galaxy = "Ядро галактики",
		cosmic = "Космическая струна", bigbang = "Большой взрыв", infinity = "Звезда бесконечности",
		browndwarf = "Коричневый карлик", whitedwarf = "Белый карлик", redgiant = "Красный гигант", binary = "Звёзды-близнецы",
		wolfrayet = "Звезда Вольфа-Райе", hypergiant = "Гипергигант", kilonova = "Килоновая", eventhorizon = "Горизонт событий",
		darkmatter = "Звезда тёмной материи", multiverse = "Мультивселенная", cosmicweb = "Космическая паутина",
		proxima = "Проксима Центавра",
		sirius = "Сириус",
		vega = "Вега",
		altair = "Альтаир",
		procyon = "Процион",
		arcturus = "Арктур",
		aldebaran = "Альдебаран",
		capella = "Капелла",
		spica = "Спика",
		polaris = "Полярная звезда",
		algol = "Алголь",
		mira = "Мира",
		achernar = "Ахернар",
		canopus = "Канопус",
		antares = "Антарес",
		rigel = "Ригель",
		deneb = "Денеб",
		betelgeuse = "Бетельгейзе",
		tabby = "Звезда Табби",
		przybylski = "Звезда Пшибыльского",
		vela = "Пульсар Паруса",
		crabpulsar = "Пульсар Краба",
		cygnusx1 = "Лебедь X-1",
		sgr1806 = "SGR 1806-20",
		etacarinae = "Эта Киля",
		vycma = "VY Большого Пса",
		uyscuti = "UY Щита",
		stephenson = "Стивенсон 2-18",
		r136a1 = "R136a1",
		ringneb = "Туманность Кольцо",
		helix = "Туманность Улитка",
		catseye = "Кошачий Глаз",
		crab = "Крабовидная туманность",
		sn1987a = "Сверхновая 1987A",
		tycho = "Сверхновая Тихо",
		kepler = "Сверхновая Кеплера",
		orion = "Туманность Ориона",
		eagle = "Туманность Орёл",
		horsehead = "Конская Голова",
		lagoon = "Туманность Лагуна",
		tarantula = "Туманность Тарантул",
		triangulum = "Галактика Треугольника",
		whirlpool = "Галактика Водоворот",
		sombrero = "Галактика Сомбреро",
		andromeda = "Галактика Андромеды",
		hoag = "Объект Хога",
		einstein = "Кольцо Эйнштейна",
		quasar3c273 = "Квазар 3C 273",
		sgra = "Стрелец A*",
		ton618 = "TON 618",
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
