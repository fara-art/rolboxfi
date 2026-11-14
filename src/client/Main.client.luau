local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
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

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollFn = Remotes:WaitForChild("Roll")
local ActionEv = Remotes:WaitForChild("Action")
local StateEv = Remotes:WaitForChild("State")
local AnnounceEv = Remotes:WaitForChild("Announce")
local CometEv = Remotes:WaitForChild("Comet")

local state = nil
local selected: string? = nil
local rolling = false
local autoRoll = false

---------------------------------------------------------------- Theme
-- Brass instruments of an old observatory: ink panels, thin brass lines, parchment text.
local INK = Color3.fromRGB(11, 13, 24)
local INK_2 = Color3.fromRGB(21, 24, 40)
local BRASS = Color3.fromRGB(201, 162, 92)
local BRASS_DIM = Color3.fromRGB(110, 90, 58)
local PARCH = Color3.fromRGB(236, 226, 200)
local MUTED = Color3.fromRGB(150, 144, 128)
local RED = Color3.fromRGB(150, 62, 52)
local GREEN = Color3.fromRGB(96, 132, 84)
local SKY_BLUE = Color3.fromRGB(150, 210, 255)

local function family(name: string, weight: Enum.FontWeight?)
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight or Enum.FontWeight.Regular)
end
local TITLE = family("Michroma")
local BODY = family("Jura", Enum.FontWeight.Bold)

---------------------------------------------------------------- UI helpers
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
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 4) })
end

local function stroke(color: Color3?, thickness: number?)
	return make("UIStroke", { Color = color or BRASS_DIM, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function pad(px: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

local function text(props)
	local max = props.Max or 22
	props.Max = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or PARCH
	props.FontFace = props.FontFace or BODY
	props.TextScaled = true
	return make("TextLabel", props, { make("UITextSizeConstraint", { MaxTextSize = max }) })
end

local KINDS = {
	primary = { fill = BRASS, text = INK, line = BRASS },
	ghost = { fill = INK_2, text = PARCH, line = BRASS_DIM },
	danger = { fill = RED, text = PARCH, line = RED },
	good = { fill = GREEN, text = PARCH, line = GREEN },
}

local function btn(kind: string, props, onClick)
	local style = KINDS[kind]
	local max = props.Max or 18
	props.Max = nil
	props.BackgroundColor3 = style.fill
	props.TextColor3 = style.text
	props.FontFace = props.FontFace or TITLE
	props.TextScaled = true
	props.AutoButtonColor = true
	local b = make("TextButton", props, {
		corner(),
		stroke(style.line),
		pad(6),
		make("UITextSizeConstraint", { MaxTextSize = max }),
	})
	b.Activated:Connect(onClick)
	return b
end

-- Panel with a small caption and a brass rule under it. Returns frame, body.
local function panel(caption: string?, props)
	props.BackgroundColor3 = INK
	props.BackgroundTransparency = 0.08
	local frame = make("Frame", props, { corner(), stroke(BRASS_DIM), pad(10) })
	local top = 0
	if caption then
		text({ Size = UDim2.new(1, 0, 0, 16), Text = caption, TextColor3 = BRASS, FontFace = TITLE, Max = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = props.ZIndex, Parent = frame })
		make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 22), BackgroundColor3 = BRASS_DIM, BorderSizePixel = 0, ZIndex = props.ZIndex, Parent = frame })
		top = 30
	end
	local body = make("Frame", { Size = UDim2.new(1, 0, 1, -top), Position = UDim2.new(0, 0, 0, top), BackgroundTransparency = 1, ZIndex = props.ZIndex, Parent = frame })
	return frame, body
end

local function dot(color: Color3, scale: number, props)
	props.Size = props.Size or UDim2.new(scale, 0, scale, 0)
	props.BackgroundColor3 = color
	props.BorderSizePixel = 0
	return make("Frame", props, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------- Layout
local gui = make("ScreenGui", {
	Name = "Observatory",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Header: instrument readouts
local _, header = panel(nil, { Size = UDim2.new(0.56, 0, 0.085, 0), Position = UDim2.new(0.22, 0, 0.012, 0), Parent = gui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0), Parent = header })
local function readout(caption: string, width: number, color: Color3)
	local box = make("Frame", { Size = UDim2.new(width, 0, 1, 0), BackgroundTransparency = 1, Parent = header })
	text({ Size = UDim2.new(1, 0, 0.32, 0), Text = caption, TextColor3 = MUTED, FontFace = TITLE, Max = 11, Parent = box })
	return text({ Size = UDim2.new(1, 0, 0.68, 0), Position = UDim2.new(0, 0, 0.32, 0), Text = "0", TextColor3 = color, FontFace = TITLE, Max = 24, Parent = box })
end
local cashValue = readout("CASH", 0.3, BRASS)
local incomeValue = readout("PER SECOND", 0.24, PARCH)
local luckValue = readout("LUCK", 0.18, PARCH)
local rebirthValue = readout("REBIRTHS", 0.18, PARCH)

local showerBanner = text({
	Size = UDim2.new(0.3, 0, 0.032, 0), Position = UDim2.new(0.35, 0, 0.1, 0),
	Text = "", TextColor3 = SKY_BLUE, FontFace = TITLE, Max = 15, Parent = gui,
})

-- Left: the roll
local _, left = panel("TELESCOPE", { Size = UDim2.new(0.2, 0, 0.64, 0), Position = UDim2.new(0.01, 0, 0.13, 0), Parent = gui })
local resultName = text({ Size = UDim2.new(1, 0, 0.14, 0), Text = "Point the lens", FontFace = TITLE, Max = 24, Parent = left })
local resultChance = text({ Size = UDim2.new(1, 0, 0.07, 0), Position = UDim2.new(0, 0, 0.14, 0), Text = "and roll for a star", TextColor3 = MUTED, Max = 16, Parent = left })
local rollButton
local autoButton

-- Center: the sky grid
local skyHolder = make("Frame", { Size = UDim2.new(0.5, 0, 0.66, 0), Position = UDim2.new(0.25, 0, 0.14, 0), BackgroundTransparency = 1, Parent = gui })
local sky = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = INK, BackgroundTransparency = 0.15, Parent = skyHolder,
}, { corner(), stroke(BRASS, 1.5), pad(10), make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
local skyGrid = make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = sky })
text({
	Size = UDim2.new(0.5, 0, 0.03, 0), Position = UDim2.new(0.25, 0, 0.81, 0),
	Text = "Select a star, then tap a cell. Tap a placed star to take it back.",
	TextColor3 = PARCH, TextStrokeTransparency = 0.3, Max = 15, Parent = gui,
})

-- Right: inventory
local _, right = panel("STAR CATALOGUE", { Size = UDim2.new(0.21, 0, 0.64, 0), Position = UDim2.new(0.78, 0, 0.13, 0), Parent = gui })
local invList = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0.6, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = BRASS_DIM, Parent = right,
}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local detail = text({ Size = UDim2.new(1, 0, 0.08, 0), Position = UDim2.new(0, 0, 0.62, 0), Text = "Nothing selected", TextColor3 = MUTED, Max = 15, Parent = right })
local actionsFrame = make("Frame", { Size = UDim2.new(1, 0, 0.28, 0), Position = UDim2.new(0, 0, 0.72, 0), BackgroundTransparency = 1, Visible = false, Parent = right })
local sellOne, sellAll, forgeButton, feedButton

-- Bottom: upgrades
local bottom = make("Frame", { Size = UDim2.new(0.5, 0, 0.07, 0), Position = UDim2.new(0.25, 0, 0.9, 0), BackgroundTransparency = 1, Parent = gui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0), Parent = bottom })
local luckUpgrade, gridUpgrade

-- Announcements
local announce = text({
	Size = UDim2.new(0.6, 0, 0.04, 0), Position = UDim2.new(0.2, 0, 0.135, 0),
	Text = "", TextTransparency = 1, TextStrokeTransparency = 1, FontFace = TITLE, Max = 20, ZIndex = 5, Parent = gui,
})

-- Popups
local popups = {}
local function popup(caption: string)
	local frame, body = panel(caption, { Size = UDim2.new(0.42, 0, 0.7, 0), Position = UDim2.new(0.29, 0, 0.14, 0), Visible = false, ZIndex = 10, Parent = gui })
	btn("ghost", { Size = UDim2.new(0, 70, 0, 22), Position = UDim2.new(1, -70, 0, -2), Text = "CLOSE", Max = 11, ZIndex = 11, Parent = frame }, function()
		frame.Visible = false
	end)
	local list = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = BRASS_DIM, Parent = body,
	}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	table.insert(popups, frame)
	return frame, list
end

local oddsFrame, oddsList = popup("ODDS AT YOUR LUCK")
local bookFrame, bookList = popup("CONSTELLATION BOOK")
local holeFrame, holeList = popup("BLACK HOLE")

local function open(frame: Frame)
	local wasOpen = frame.Visible
	for _, other in popups do
		other.Visible = false
	end
	frame.Visible = not wasOpen
end

---------------------------------------------------------------- Render: popups
local function row(list: Instance, order: number, height: number)
	return make("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = INK_2, LayoutOrder = order, ZIndex = 10, Parent = list }, { corner() })
end

local function renderOdds()
	clear(oddsList)
	local luck = if state then state.luck else 1
	local odds = Odds.exact(luck)
	for i = #Stars.List, 1, -1 do
		local star = Stars.List[i]
		local r = row(oddsList, -i, 30)
		dot(star.color, 0.5, { Position = UDim2.new(0, 8, 0.25, 0), ZIndex = 10, Parent = r })
		text({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 30, 0, 0), Text = star.name, TextColor3 = star.color, TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 10, Parent = r })
		text({ Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.new(0.56, 0, 0, 0), Text = "1 in " .. Format.number(star.chance) .. "   " .. Format.percent(odds[star.id]), TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 10, Parent = r })
	end
	text({ Size = UDim2.new(1, -8, 0, 26), LayoutOrder = 100, Text = "MUTATIONS", TextColor3 = BRASS, FontFace = TITLE, Max = 13, ZIndex = 10, Parent = oddsList })
	local mutationOdds = Odds.exactMutations(luck)
	for i, mutation in Mutations.List do
		local r = row(oddsList, 100 + i, 30)
		text({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Text = mutation.name .. "  x" .. mutation.mult, TextColor3 = mutation.color, TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 10, Parent = r })
		text({ Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.new(0.56, 0, 0, 0), Text = "1 in " .. Format.number(mutation.chance) .. "   " .. Format.percent(mutationOdds[mutation.id]), TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 10, Parent = r })
	end
end

local function renderBook()
	clear(bookList)
	for order, pattern in Constellations.List do
		local found = state and state.discovered[pattern.id]
		local r = row(bookList, order, 72)
		local maxX, maxY = 0, 0
		for _, c in pattern.cells do
			maxX = math.max(maxX, c[1])
			maxY = math.max(maxY, c[2])
		end
		local box = make("Frame", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 6, 0, 6), BackgroundTransparency = 1, ZIndex = 10, Parent = r })
		local cell = 60 / math.max(maxX + 1, maxY + 1)
		for _, c in pattern.cells do
			dot(if found then BRASS else BRASS_DIM, 0, {
				Size = UDim2.new(0, cell * 0.6, 0, cell * 0.6),
				Position = UDim2.new(0, c[1] * cell + cell * 0.2, 0, c[2] * cell + cell * 0.2),
				ZIndex = 10, Parent = box,
			})
		end
		text({
			Size = UDim2.new(1, -84, 0.5, 0), Position = UDim2.new(0, 76, 0.1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10,
			Text = if found then pattern.name else "Unknown", TextColor3 = if found then PARCH else MUTED, FontFace = TITLE, Max = 15, Parent = r,
		})
		text({
			Size = UDim2.new(1, -84, 0.35, 0), Position = UDim2.new(0, 76, 0.55, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10,
			Text = if found then "income x" .. pattern.mult else #pattern.cells .. " stars", TextColor3 = MUTED, Max = 14, Parent = r,
		})
	end
	text({
		Size = UDim2.new(1, -8, 0, 54), LayoutOrder = 999, ZIndex = 10, TextColor3 = MUTED, Max = 14, TextWrapped = true,
		Text = "A group must be exactly this shape with no extra neighbours, diagonals included. All stars of one kind: another x" .. Constellations.PureBonus .. ".",
		Parent = bookList,
	})
end

local function renderHole()
	clear(holeList)
	if not state then
		return
	end
	local cost = Config.RebirthCost(state.rebirths)
	local progress = math.clamp(state.mass / cost, 0, 1)
	text({ Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 1, Text = Format.number(state.mass) .. " / " .. Format.number(cost) .. " mass", FontFace = TITLE, Max = 18, ZIndex = 10, Parent = holeList })
	local bar = make("Frame", { Size = UDim2.new(1, -8, 0, 14), BackgroundColor3 = INK_2, LayoutOrder = 2, ZIndex = 10, Parent = holeList }, { corner(), stroke() })
	make("Frame", { Size = UDim2.new(progress, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 130, 50), BorderSizePixel = 0, ZIndex = 10, Parent = bar }, { corner() })
	local lines = {
		"Feed stars from your catalogue to grow its mass.",
		string.format("Now: income x%s, luck +%s", 1 + state.rebirths * Config.RebirthIncomeBonus, state.rebirths * Config.RebirthLuckBonus),
		string.format("After rebirth: income x%s, luck +%s", 1 + (state.rebirths + 1) * Config.RebirthIncomeBonus, (state.rebirths + 1) * Config.RebirthLuckBonus),
		"Rebirth resets cash, stars, sky and upgrades. Discovered constellations stay.",
	}
	for i, line in lines do
		text({ Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 2 + i, Text = line, TextColor3 = if i == 1 then PARCH else MUTED, TextWrapped = true, Max = 15, ZIndex = 10, Parent = holeList })
	end
	local ready = progress >= 1
	btn(if ready then "primary" else "ghost", { Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 10, Text = if ready then "REBIRTH" else "NOT ENOUGH MASS", ZIndex = 10, Parent = holeList }, function()
		if ready then
			ActionEv:FireServer("Rebirth")
		end
	end)
end

---------------------------------------------------------------- Render: main
local function renderSky()
	clear(sky)
	local size = state.gridSize
	local gap = 5
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
			local cell = state.grid[key]
			local star, mutation = Items.parse(cell and cell.id)
			local group = inGroup[key]
			local cellButton = make("TextButton", {
				LayoutOrder = y * 100 + x, Text = "", AutoButtonColor = true,
				BackgroundColor3 = if star then INK_2 else Color3.fromRGB(16, 18, 31),
				Parent = sky,
			}, { corner() })
			if group then
				stroke(if group.pure then SKY_BLUE else BRASS, 1.5).Parent = cellButton
			end
			if star then
				local d = dot(star.color, math.min(0.28 + star.index * 0.05, 0.72), {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Parent = cellButton,
				})
				if mutation.id ~= "normal" then
					stroke(mutation.color, 2).Parent = d
				end
				-- evolution ticks
				local level = Evolution.level(cell.age or 0)
				local ticks = make("Frame", { Size = UDim2.new(0.6, 0, 0.07, 0), Position = UDim2.new(0.2, 0, 0.86, 0), BackgroundTransparency = 1, Parent = cellButton })
				make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.04, 0), Parent = ticks })
				for i = 1, Evolution.MaxLevel do
					make("Frame", { Size = UDim2.new(0.16, 0, 1, 0), BorderSizePixel = 0, BackgroundColor3 = if i <= level then BRASS else BRASS_DIM, BackgroundTransparency = if i <= level then 0 else 0.6, Parent = ticks })
				end
			end
			cellButton.Activated:Connect(function()
				if selected and (state.inventory[selected] or 0) > 0 and not (cell and cell.id == selected) then
					ActionEv:FireServer("Place", key, selected)
				elseif cell then
					ActionEv:FireServer("Remove", key)
				end
			end)
		end
	end
end

local function renderInventory()
	clear(invList)
	if selected and not state.inventory[selected] then
		selected = nil
	end
	local keys = {}
	for key in state.inventory do
		if Items.parse(key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return Items.rank(a) > Items.rank(b)
	end)
	for order, key in keys do
		local star, mutation = Items.parse(key)
		local isSelected = selected == key
		local r = make("TextButton", {
			Size = UDim2.new(1, -6, 0, 30), LayoutOrder = order, Text = "", AutoButtonColor = true,
			BackgroundColor3 = if isSelected then Color3.fromRGB(48, 42, 30) else INK_2, Parent = invList,
		}, { corner(), stroke(if isSelected then BRASS else Color3.fromRGB(34, 37, 56)) })
		local d = dot(star.color, 0.5, { Position = UDim2.new(0, 8, 0.25, 0), Parent = r })
		if mutation.id ~= "normal" then
			stroke(mutation.color, 2).Parent = d
		end
		text({ Size = UDim2.new(0.7, -30, 1, 0), Position = UDim2.new(0, 30, 0, 0), Text = Items.name(key), TextColor3 = star.color, TextXAlignment = Enum.TextXAlignment.Left, Max = 15, Parent = r })
		text({ Size = UDim2.new(0.3, -8, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), Text = "x" .. state.inventory[key], TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, FontFace = TITLE, Max = 13, Parent = r })
		r.Activated:Connect(function()
			selected = if selected == key then nil else key
			renderInventory()
		end)
	end

	actionsFrame.Visible = selected ~= nil
	if not selected then
		detail.Text = if #keys > 0 then "Nothing selected" else "Roll to find stars"
		return
	end
	local star = Items.parse(selected)
	detail.Text = string.format("+%s/s on the sky  ·  sells for %s", Format.number(Items.income(selected)), Format.number(Items.income(selected) * Config.SellMultiplier))
	local nextStar = Stars.List[star.index + 1]
	forgeButton.Text = if nextStar
		then string.format("FORGE %d/%d", math.min(state.inventory[selected], Config.ForgeAmount), Config.ForgeAmount)
		else "FORGE MAX"
	feedButton.Text = "FEED ALL"
end

local function renderUpgrades()
	luckUpgrade.Text = if state.luckLevel >= Config.MaxLuckLevel
		then "LUCK  MAX"
		else string.format("LUCK +%s   %s", Config.LuckPerLevel, Format.number(Config.LuckCost(state.luckLevel)))
	gridUpgrade.Text = if state.gridSize >= Config.MaxGridSize
		then "SKY  MAX"
		else string.format("SKY %dx%d   %s", state.gridSize + 1, state.gridSize + 1, Format.number(Config.GridCost(state.gridSize)))
end

local function canAutoRoll(): boolean
	return Config.GamePasses.AutoRoll == 0 or (state ~= nil and state.passes.AutoRoll == true)
end

local function render()
	if not state then
		return
	end
	incomeValue.Text = "+" .. Format.number(state.income)
	luckValue.Text = "x" .. (math.floor(state.luck * 100 + 0.5) / 100)
	rebirthValue.Text = tostring(state.rebirths)
	renderSky()
	renderInventory()
	renderUpgrades()
	if oddsFrame.Visible then
		renderOdds()
	end
	if bookFrame.Visible then
		renderBook()
	end
	if holeFrame.Visible then
		renderHole()
	end
	autoButton.Text = if autoRoll then "AUTO  ON" else "AUTO  OFF"
end

---------------------------------------------------------------- Roll
local function showResult(key: string)
	local star = Items.parse(key)
	resultName.Text = Items.name(key)
	resultName.TextColor3 = star.color
	resultChance.Text = "1 in " .. Format.number(Items.chance(key))
	resultName.Size = UDim2.new(1, 0, 0.17, 0)
	TweenService:Create(resultName, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0.14, 0) }):Play()
end

local function doRoll()
	if rolling then
		return
	end
	rolling = true
	local result = nil
	task.spawn(function()
		result = RollFn:InvokeServer()
	end)
	local started = os.clock()
	while (os.clock() - started < 0.6 or result == nil) and os.clock() - started < 5 do
		local fake = Stars.List[math.random(1, 6)]
		resultName.Text = fake.name
		resultName.TextColor3 = MUTED
		resultChance.Text = "..."
		task.wait(0.06)
	end
	if result then
		showResult(result)
	end
	task.wait(math.max(0, Config.RollCooldown - (os.clock() - started)))
	rolling = false
end

---------------------------------------------------------------- Buttons
rollButton = btn("primary", { Size = UDim2.new(1, 0, 0.17, 0), Position = UDim2.new(0, 0, 0.24, 0), Text = "ROLL", Max = 30, Parent = left }, doRoll)
autoButton = btn("ghost", { Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.new(0, 0, 0.45, 0), Text = "AUTO  OFF", Parent = left }, function()
	if canAutoRoll() then
		autoRoll = not autoRoll
		render()
	elseif Config.GamePasses.AutoRoll ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.AutoRoll)
	end
end)
btn("ghost", { Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.new(0, 0, 0.59, 0), Text = "ODDS", Parent = left }, function()
	open(oddsFrame)
	renderOdds()
end)
btn("ghost", { Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.new(0, 0, 0.73, 0), Text = "CONSTELLATIONS", Parent = left }, function()
	open(bookFrame)
	renderBook()
end)
btn("ghost", { Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.new(0, 0, 0.87, 0), Text = "BLACK HOLE", Parent = left }, function()
	open(holeFrame)
	renderHole()
end)

sellOne = btn("ghost", { Size = UDim2.new(0.48, 0, 0.42, 0), Text = "SELL 1", Max = 14, Parent = actionsFrame }, function()
	if selected then
		ActionEv:FireServer("Sell", selected, 1)
	end
end)
sellAll = btn("danger", { Size = UDim2.new(0.48, 0, 0.42, 0), Position = UDim2.new(0.52, 0, 0, 0), Text = "SELL ALL", Max = 14, Parent = actionsFrame }, function()
	if selected and state then
		ActionEv:FireServer("Sell", selected, state.inventory[selected] or 0)
	end
end)
forgeButton = btn("primary", { Size = UDim2.new(0.48, 0, 0.42, 0), Position = UDim2.new(0, 0, 0.54, 0), Text = "FORGE", Max = 14, Parent = actionsFrame }, function()
	if selected then
		ActionEv:FireServer("Forge", selected)
	end
end)
feedButton = btn("ghost", { Size = UDim2.new(0.48, 0, 0.42, 0), Position = UDim2.new(0.52, 0, 0.54, 0), Text = "FEED ALL", Max = 14, Parent = actionsFrame }, function()
	if selected and state then
		ActionEv:FireServer("Feed", selected, state.inventory[selected] or 0)
	end
end)

luckUpgrade = btn("good", { Size = UDim2.new(0.49, 0, 1, 0), Text = "", Max = 16, Parent = bottom }, function()
	ActionEv:FireServer("BuyLuck")
end)
gridUpgrade = btn("ghost", { Size = UDim2.new(0.49, 0, 1, 0), Text = "", Max = 16, Parent = bottom }, function()
	ActionEv:FireServer("BuyGrid")
end)

---------------------------------------------------------------- Events
StateEv.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

local announceTween = nil
local function showAnnounce(message: string, color: Color3?)
	if announceTween then
		announceTween:Cancel()
	end
	announce.Text = message
	announce.TextColor3 = color or PARCH
	announce.TextTransparency = 0
	announce.TextStrokeTransparency = 0.35
	announceTween = TweenService:Create(announce, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 4), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	})
	announceTween:Play()
end
AnnounceEv.OnClientEvent:Connect(showAnnounce)

-- World prompts
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BlackHolePrompt" then
		open(holeFrame)
		renderHole()
	elseif prompt.Name == "ObservatoryPrompt" then
		open(bookFrame)
		renderBook()
	elseif prompt.Name == "ForgePrompt" then
		showAnnounce(string.format("Select a star in your catalogue and press FORGE: %d of the same make the next one", Config.ForgeAmount), BRASS)
	end
end)

-- Comets
CometEv.OnClientEvent:Connect(function(lifetime: number)
	local y = math.random(18, 55) / 100
	local comet = make("TextButton", {
		Size = UDim2.new(0, 120, 0, 40), Position = UDim2.new(1.02, 0, y, 0), AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1, Text = "", ZIndex = 20, Parent = gui,
	})
	local tail = make("Frame", { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 20, 0.5, -3), BackgroundColor3 = SKY_BLUE, BorderSizePixel = 0, ZIndex = 20, Parent = comet }, {
		corner(3),
		make("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	dot(Color3.fromRGB(235, 248, 255), 0, { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 0, 0.5, -13), ZIndex = 21, Parent = comet })
	local _ = tail
	TweenService:Create(comet, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), { Position = UDim2.new(-0.12, 0, y + 0.12, 0) }):Play()
	comet.Activated:Connect(function()
		ActionEv:FireServer("CatchComet")
		comet:Destroy()
	end)
	task.delay(lifetime, function()
		if comet.Parent then
			comet:Destroy()
		end
	end)
end)

-- Cash readout
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	local function update()
		cashValue.Text = Format.number(cash.Value)
	end
	cash.Changed:Connect(update)
	update()
end)

-- Star Shower timer + auto roll
task.spawn(function()
	while true do
		local remaining = (ReplicatedStorage:GetAttribute("ShowerEndsAt") or 0) - workspace:GetServerTimeNow()
		showerBanner.Text = if remaining > 0 then "STAR SHOWER  x" .. Config.ShowerLuck .. " LUCK  " .. Format.time(remaining) else ""
		if autoRoll and canAutoRoll() and not rolling then
			task.spawn(doRoll)
		end
		task.wait(0.2)
	end
end)
