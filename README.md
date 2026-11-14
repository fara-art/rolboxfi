# Созвездия RNG

Roblox RNG-игра: крутишь звёзды, расставляешь на небе, собираешь созвездия, получаешь доход.

## Механика
- **Крутка**: 9 звёзд + отдельный ролл мутации (Shiny/Golden/Void/Celestial)
- **Участки**: зашёл на свободный, и он твой. Звёзды ставятся на постаменты (E) и только там приносят деньги
- **Созвездия**: фигуры из звёзд на постаментах дают множители, линии рисуются в 3D
- **Эволюция**: звёзды на участке растут до 5 уровня, некоторые взрываются в звезду получше
- **Кузня** (отдельный остров): 5 одинаковых + кэш → следующая звезда
- **Чёрная дыра** (отдельный остров): кормишь звёздами → перерождение
- **Индекс звёзд**: собранный ряд мутации = +удача навсегда; награды за количество круток
- **Улучшения**: удача, скорость крутки, мульти-крутка, размер участка
- **Автокрутка** открывается после 50 круток
- **Языки**: EN / RU (кнопка слева сверху)
- **Падение в бездну**: телепорт на базу, без смерти

## Иконки звёзд
`assets/icons/*.png` (рисуются `tools/make_icons.py`). Загрузить в Roblox (Asset Manager → Bulk Import),
вписать ID в `Config.StarIcons`.

## Структура
```
src/shared   -> ReplicatedStorage.Shared   (звёзды, созвездия, конфиг, логика)
src/server   -> ServerScriptService.Server (крутка, сохранения, доход)
src/client   -> StarterPlayerScripts.Client (интерфейс)
```
Баланс правится в `src/shared/Config.luau`, `Stars.luau`, `Constellations.luau`.

## Быстрый запуск (без Rojo)
Открыть `ConstellationsRNG.rbxlx` в Roblox Studio → Play.
После правок в `src/` пересобрать: `python3 tools/build_place.py`.

## Запуск через Rojo
1. Поставить [Rokit](https://github.com/rojo-rbx/rokit), в папке проекта: `rokit install`
2. В Roblox Studio поставить плагин Rojo
3. `rojo serve`, в Studio: плагин Rojo → Connect
4. Game Settings → Security → включить **Enable Studio Access to API Services** (для сохранений)
5. Play

## Геймпассы
Создать на create.roblox.com и вписать ID в `Config.GamePasses`:
`Luck2x`, `Cash2x`, `AutoRoll` (пока ID = 0, автокрутка бесплатная для тестов).
