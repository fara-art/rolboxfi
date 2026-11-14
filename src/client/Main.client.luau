local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stars = require(Shared.Stars)
local Constellations = require(Shared.Constellations)
local Odds = require(Shared.Odds)
local Sky = require(Shared.Sky)
local Format = require(Shared.Format)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollFn = Remotes:WaitForChild("Roll")
local ActionEv = Remotes:WaitForChild("Action")
local StateEv = Remotes:WaitForChild("State")
local AnnounceEv = Remotes:WaitForChild("Announce")

local state = nil
local selectedStar: string? = nil
local rolling = false
local autoRoll = false

---------------------------------------------------------------- UI helpers
local BG = Color3.fromRGB(14, 16, 34)
local PANEL = Color3.fromRGB(26, 30, 58)
local ACCENT = Color3.fromRGB(110, 90, 255)
local TEXT = Color3.fromRGB(235, 235, 255)
local MUTED = Color3.fromRGB(150, 150, 190)

local function make(className: string, props, children)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function padding(px: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

local function label(props)
	local max = props.MaxText or 28
	props.MaxText = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return make("TextLabel", props, { make("UITextSizeConstraint", { MaxTextSize = max }) })
end

local function button(props, onClick)
	local max = props.MaxText or 24
	props.MaxText = nil
	props.BackgroundColor3 = props.BackgroundColor3 or ACCENT
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextScaled = true
	props.AutoButtonColor = true
	local btn = make("TextButton", props, { corner(), make("UITextSizeConstraint", { MaxTextSize = max }) })
	btn.Activated:Connect(onClick)
	return btn
end

local function panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or PANEL
	return make("Frame", props, { corner(14), padding(8) })
end

---------------------------------------------------------------- Layout
local gui = make("ScreenGui", {
	Name = "ConstellationsUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Верх: деньги, доход, удача, звездопад
local top = panel({ Size = UDim2.new(0.6, 0, 0.09, 0), Position = UDim2.new(0.2, 0, 0.01, 0), Parent = gui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0), Parent = top })
local cashLabel = label({ Size = UDim2.new(0.3, 0, 1, 0), Text = "💰 0", TextColor3 = Color3.fromRGB(255, 220, 90), Parent = top })
local incomeLabel = label({ Size = UDim2.new(0.22, 0, 1, 0), Text = "+0/s", TextColor3 = Color3.fromRGB(140, 255, 160), Parent = top })
local luckLabel = label({ Size = UDim2.new(0.2, 0, 1, 0), Text = "🍀 x1", Parent = top })
local showerLabel = label({ Size = UDim2.new(0.24, 0, 1, 0), Text = "", TextColor3 = Color3.fromRGB(140, 200, 255), Parent = top })

-- Лево: крутка
local left = panel({ Size = UDim2.new(0.2, 0, 0.6, 0), Position = UDim2.new(0.01, 0, 0.14, 0), Parent = gui })
local resultLabel = label({ Size = UDim2.new(1, 0, 0.22, 0), Text = "Roll for stars!", MaxText = 30, Parent = left })
local chanceLabel = label({ Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.new(0, 0, 0.22, 0), Text = "", TextColor3 = MUTED, MaxText = 18, Parent = left })
local rollButton
local autoButton
local oddsButton
local bookButton

-- Центр: небо
local skyHolder = make("Frame", { Size = UDim2.new(0.5, 0, 0.66, 0), Position = UDim2.new(0.25, 0, 0.14, 0), BackgroundTransparency = 1, Parent = gui })
local sky = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = BG, Parent = skyHolder,
}, { corner(16), padding(8), make("UIAspectRatioConstraint", { AspectRatio = 1 }), make("UIStroke", { Color = ACCENT, Thickness = 2 }) })
local skyGrid = make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = sky })
local skyHint = label({
	Size = UDim2.new(0.5, 0, 0.05, 0), Position = UDim2.new(0.25, 0, 0.805, 0),
	Text = "Pick a star on the right, then tap a cell. Tap a placed star to remove it.", TextColor3 = MUTED, MaxText = 16, Font = Enum.Font.Gotham, Parent = gui,
})

-- Право: инвентарь
local right = panel({ Size = UDim2.new(0.22, 0, 0.6, 0), Position = UDim2.new(0.77, 0, 0.14, 0), Parent = gui })
label({ Size = UDim2.new(1, 0, 0.08, 0), Text = "Inventory", Parent = right })
local invList = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0.72, 0), Position = UDim2.new(0, 0, 0.09, 0), BackgroundTransparency = 1,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = right,
}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local sellOne
local sellAll

-- Низ: улучшения
local bottom = panel({ Size = UDim2.new(0.5, 0, 0.09, 0), Position = UDim2.new(0.25, 0, 0.88, 0), Parent = gui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0), Parent = bottom })
local luckUpgrade
local gridUpgrade

-- Объявления
local announce = label({
	Size = UDim2.new(0.6, 0, 0.05, 0), Position = UDim2.new(0.2, 0, 0.105, 0),
	Text = "", TextTransparency = 1, TextStrokeTransparency = 1, MaxText = 26, Parent = gui,
})

-- Всплывающие окна
local function popup(title: string)
	local frame = panel({ Size = UDim2.new(0.4, 0, 0.7, 0), Position = UDim2.new(0.3, 0, 0.14, 0), Visible = false, ZIndex = 10, Parent = gui })
	label({ Size = UDim2.new(0.85, 0, 0.08, 0), Text = title, ZIndex = 10, Parent = frame })
	button({ Size = UDim2.new(0.1, 0, 0.08, 0), Position = UDim2.new(0.9, 0, 0, 0), Text = "✕", BackgroundColor3 = Color3.fromRGB(200, 60, 80), ZIndex = 10 }, function()
		frame.Visible = false
	end).Parent = frame
	local list = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0.9, 0), Position = UDim2.new(0, 0, 0.1, 0), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 10, Parent = frame,
	}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	return frame, list
end

local oddsFrame, oddsList = popup("Odds (with your luck)")
local bookFrame, bookList = popup("Constellation Book")

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------- Render
local function renderOdds()
	clear(oddsList)
	local odds = Odds.exact(if state then state.luck else 1)
	for i = #Stars.List, 1, -1 do
		local star = Stars.List[i]
		label({
			Size = UDim2.new(1, -10, 0, 30), LayoutOrder = -i, ZIndex = 10, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%s  •  1 in %s  •  %s", star.name, Format.number(star.chance), Format.percent(odds[star.id])),
			TextColor3 = star.color, MaxText = 20, Parent = oddsList,
		})
	end
end

local function renderBook()
	clear(bookList)
	for order, pattern in Constellations.List do
		local found = state and state.discovered[pattern.id]
		local row = make("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = BG, LayoutOrder = order, ZIndex = 10, Parent = bookList }, { corner() })
		-- мини-схема
		local maxX, maxY = 0, 0
		for _, c in pattern.cells do
			maxX = math.max(maxX, c[1])
			maxY = math.max(maxY, c[2])
		end
		local box = make("Frame", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, ZIndex = 10, Parent = row })
		local cell = 60 / math.max(maxX + 1, maxY + 1)
		for _, c in pattern.cells do
			make("Frame", {
				Size = UDim2.new(0, cell - 2, 0, cell - 2), Position = UDim2.new(0, c[1] * cell, 0, c[2] * cell),
				BackgroundColor3 = if found then Color3.fromRGB(255, 220, 120) else MUTED, ZIndex = 10, Parent = box,
			}, { corner(3) })
		end
		label({
			Size = UDim2.new(1, -80, 1, -10), Position = UDim2.new(0, 75, 0, 5), ZIndex = 10, TextXAlignment = Enum.TextXAlignment.Left,
			Text = if found then string.format("%s  •  x%s", pattern.name, pattern.mult) else string.format("???  •  %d stars", #pattern.cells),
			TextColor3 = if found then TEXT else MUTED, MaxText = 20, Parent = row,
		})
	end
	label({
		Size = UDim2.new(1, -10, 0, 50), LayoutOrder = 999, ZIndex = 10, Font = Enum.Font.Gotham, TextColor3 = MUTED, MaxText = 16,
		Text = string.format("A group must be exactly this shape with no extra neighbors (diagonals count). All stars of one type: extra x%s.", Constellations.PureBonus),
		Parent = bookList,
	})
end

local function renderSky()
	clear(sky)
	local size = state.gridSize
	local gap = 4
	skyGrid.CellPadding = UDim2.new(0, gap, 0, gap)
	skyGrid.CellSize = UDim2.new(1 / size, -gap, 1 / size, -gap)

	local inGroup = {}
	for _, group in state.groups do
		for _, key in group.cells do
			inGroup[key] = group
		end
	end

	for y = 1, size do
		for x = 1, size do
			local key = Sky.key(x, y)
			local star = Stars.ById[state.grid[key]]
			local group = inGroup[key]
			local cellBtn = make("TextButton", {
				LayoutOrder = y * 100 + x,
				BackgroundColor3 = if star then Color3.fromRGB(34, 38, 74) else Color3.fromRGB(22, 24, 48),
				Text = if star then "★" else "",
				TextColor3 = if star then star.color else TEXT,
				TextScaled = true, Font = Enum.Font.GothamBold, AutoButtonColor = true,
				Parent = sky,
			}, { corner(8) })
			if group then
				make("UIStroke", {
					Color = if group.pure then Color3.fromRGB(120, 255, 255) else Color3.fromRGB(255, 220, 120),
					Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cellBtn,
				})
			end
			cellBtn.Activated:Connect(function()
				if selectedStar and (state.inventory[selectedStar] or 0) > 0 and state.grid[key] ~= selectedStar then
					ActionEv:FireServer("Place", key, selectedStar)
				elseif star then
					ActionEv:FireServer("Remove", key)
				end
			end)
		end
	end
end

local function renderInventory()
	clear(invList)
	if selectedStar and not state.inventory[selectedStar] then
		selectedStar = nil
	end
	for i = #Stars.List, 1, -1 do
		local star = Stars.List[i]
		local count = state.inventory[star.id]
		if count then
			local selected = selectedStar == star.id
			button({
				Size = UDim2.new(1, -8, 0, 36), LayoutOrder = -i,
				BackgroundColor3 = if selected then Color3.fromRGB(70, 60, 150) else BG,
				TextColor3 = star.color, MaxText = 18,
				Text = string.format("%s ×%d  (+%s/s)", star.name, count, Format.number(star.income)),
				Parent = invList,
			}, function()
				selectedStar = if selectedStar == star.id then nil else star.id
				renderInventory()
			end)
		end
	end
	sellOne.Text = if selectedStar then "Sell 1" else "Select a star"
	sellAll.Text = if selectedStar then "Sell all" else ""
end

local function renderUpgrades()
	if state.luckLevel >= Config.MaxLuckLevel then
		luckUpgrade.Text = "🍀 Luck: MAX"
	else
		luckUpgrade.Text = string.format("🍀 Luck +%s  (💰%s)", Config.LuckPerLevel, Format.number(Config.LuckCost(state.luckLevel)))
	end
	if state.gridSize >= Config.MaxGridSize then
		gridUpgrade.Text = "🌌 Sky: MAX"
	else
		gridUpgrade.Text = string.format("🌌 Sky %d×%d  (💰%s)", state.gridSize + 1, state.gridSize + 1, Format.number(Config.GridCost(state.gridSize)))
	end
end

local function canAutoRoll(): boolean
	return Config.GamePasses.AutoRoll == 0 or (state ~= nil and state.passes.AutoRoll == true)
end

local function render()
	if not state then
		return
	end
	incomeLabel.Text = "+" .. Format.number(state.income) .. "/s"
	luckLabel.Text = "🍀 x" .. (math.floor(state.luck * 100 + 0.5) / 100)
	renderSky()
	renderInventory()
	renderUpgrades()
	if oddsFrame.Visible then
		renderOdds()
	end
	if bookFrame.Visible then
		renderBook()
	end
	autoButton.Text = if autoRoll then "Auto: ON" else "Auto: OFF"
end

---------------------------------------------------------------- Buttons
local function doRoll()
	if rolling then
		return
	end
	rolling = true
	local result = nil
	task.spawn(function()
		result = RollFn:InvokeServer()
	end)
	-- анимация перебора
	local started = os.clock()
	while os.clock() - started < 0.6 or result == nil do
		local fake = Stars.List[math.random(1, math.min(#Stars.List, 6))]
		resultLabel.Text = fake.name
		resultLabel.TextColor3 = fake.color
		task.wait(0.05)
		if os.clock() - started > 5 then
			break
		end
	end
	local star = Stars.ById[result]
	if star then
		resultLabel.Text = star.name
		resultLabel.TextColor3 = star.color
		chanceLabel.Text = "1 in " .. Format.number(star.chance)
		local pop = TweenService:Create(resultLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0.22, 0) })
		resultLabel.Size = UDim2.new(1.2, 0, 0.26, 0)
		pop:Play()
	end
	task.wait(math.max(0, Config.RollCooldown - (os.clock() - started)))
	rolling = false
end

rollButton = button({ Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.new(0, 0, 0.35, 0), Text = "🎲 ROLL", MaxText = 32, Parent = left }, doRoll)
autoButton = button({ Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.new(0, 0, 0.58, 0), Text = "Auto: OFF", BackgroundColor3 = Color3.fromRGB(60, 60, 110), Parent = left }, function()
	if canAutoRoll() then
		autoRoll = not autoRoll
		render()
	elseif Config.GamePasses.AutoRoll ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.AutoRoll)
	end
end)
oddsButton = button({ Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.new(0, 0, 0.73, 0), Text = "📊 Odds", BackgroundColor3 = Color3.fromRGB(60, 60, 110), Parent = left }, function()
	bookFrame.Visible = false
	oddsFrame.Visible = not oddsFrame.Visible
	renderOdds()
end)
bookButton = button({ Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.new(0, 0, 0.88, 0), Text = "📖 Constellations", BackgroundColor3 = Color3.fromRGB(60, 60, 110), Parent = left }, function()
	oddsFrame.Visible = false
	bookFrame.Visible = not bookFrame.Visible
	renderBook()
end)

sellOne = button({ Size = UDim2.new(0.48, 0, 0.16, 0), Position = UDim2.new(0, 0, 0.84, 0), Text = "Select a star", BackgroundColor3 = Color3.fromRGB(180, 70, 90), MaxText = 18, Parent = right }, function()
	if selectedStar then
		ActionEv:FireServer("Sell", selectedStar, 1)
	end
end)
sellAll = button({ Size = UDim2.new(0.48, 0, 0.16, 0), Position = UDim2.new(0.52, 0, 0.84, 0), Text = "", BackgroundColor3 = Color3.fromRGB(150, 50, 70), MaxText = 18, Parent = right }, function()
	if selectedStar and state then
		ActionEv:FireServer("Sell", selectedStar, state.inventory[selectedStar] or 0)
	end
end)

luckUpgrade = button({ Size = UDim2.new(0.48, 0, 1, 0), Text = "", BackgroundColor3 = Color3.fromRGB(50, 140, 90), MaxText = 20, Parent = bottom }, function()
	ActionEv:FireServer("BuyLuck")
end)
gridUpgrade = button({ Size = UDim2.new(0.48, 0, 1, 0), Text = "", BackgroundColor3 = Color3.fromRGB(60, 90, 170), MaxText = 20, Parent = bottom }, function()
	ActionEv:FireServer("BuyGrid")
end)

---------------------------------------------------------------- Events
StateEv.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

local announceTween = nil
AnnounceEv.OnClientEvent:Connect(function(text: string, color: Color3?)
	if announceTween then
		announceTween:Cancel()
	end
	announce.Text = text
	announce.TextColor3 = color or TEXT
	announce.TextTransparency = 0
	announce.TextStrokeTransparency = 0.4
	announceTween = TweenService:Create(announce, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 4), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	})
	announceTween:Play()
end)

-- Деньги из leaderstats (обновляются каждую секунду)
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	local function update()
		cashLabel.Text = "💰 " .. Format.number(cash.Value)
	end
	cash.Changed:Connect(update)
	update()
end)

-- Таймер звездопада + автокрутка
task.spawn(function()
	while true do
		local remaining = (ReplicatedStorage:GetAttribute("ShowerEndsAt") or 0) - workspace:GetServerTimeNow()
		showerLabel.Text = if remaining > 0 then "🌠 x" .. Config.ShowerLuck .. " " .. Format.time(remaining) else ""
		if autoRoll and canAutoRoll() and not rolling then
			task.spawn(doRoll)
		end
		task.wait(0.2)
	end
end)
