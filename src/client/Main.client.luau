local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

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
local Lang = require(Shared.Lang)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollFn = Remotes:WaitForChild("Roll")
local ActionEv = Remotes:WaitForChild("Action")
local StateEv = Remotes:WaitForChild("State")
local AnnounceEv = Remotes:WaitForChild("Announce")
local PickerEv = Remotes:WaitForChild("OpenPicker")
local OpenWindowEv = Remotes:WaitForChild("OpenWindow")
local GlobalRareEv = Remotes:WaitForChild("GlobalRare")

local state = nil
local selected: string? = nil
local pickerCell: string? = nil
local rolling = false
local autoRoll = false
local lastResult: { string }? = nil
local showRare -- defined later (rare roll reveal)

local autoLang = if string.sub(LocalizationService.RobloxLocaleId, 1, 2) == "ru" then "ru" else "en"
local lang = autoLang
local function t(key: string, ...): string
	return Lang.t(lang, key, ...)
end

---------------------------------------------------------------- Theme: bright sky
local WHITE = Color3.fromRGB(255, 255, 255)
local PANEL = Color3.fromRGB(250, 252, 255)
local PANEL_2 = Color3.fromRGB(233, 243, 255)
local LINE = Color3.fromRGB(190, 216, 245)
local TEXT = Color3.fromRGB(34, 52, 88)
local MUTED = Color3.fromRGB(108, 130, 166)
local BLUE = Color3.fromRGB(70, 158, 255)
local MINT = Color3.fromRGB(56, 196, 146)
local GOLD = Color3.fromRGB(255, 186, 60)
local RED = Color3.fromRGB(240, 102, 102)
local LILAC = Color3.fromRGB(150, 110, 255)
local GREY = Color3.fromRGB(170, 184, 205)
local INK = Color3.fromRGB(26, 28, 48)

local TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
local BODY_SEMI = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)

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
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function stroke(color: Color3?, thickness: number?)
	return make("UIStroke", { Color = color or LINE, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function pad(px: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

local function text(props)
	local max = props.Max or 20
	props.Max = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or TEXT
	props.FontFace = props.FontFace or BODY
	props.TextScaled = true
	return make("TextLabel", props, { make("UITextSizeConstraint", { MaxTextSize = max }) })
end

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Localized static labels: re-applied when the language changes
local bound = {}
local function bind(inst: TextLabel | TextButton, key: string)
	table.insert(bound, { inst = inst, key = key })
	inst.Text = t(key)
	return inst
end

-- Uploaded UI icon (Config.UiIcons) or nil when not configured
local function uiIcon(key: string, props)
	local id = Config.UiIcons[key]
	if not id or id == "" then
		return nil
	end
	props.BackgroundTransparency = 1
	props.Image = if string.find(id, "://") then id else "rbxassetid://" .. id
	return make("ImageLabel", props, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
end

-- Chunky cartoon button: thick ink outline, white text with ink stroke, optional icon on the left
local function btn(color: Color3, props, onClick, iconKey: string?)
	local max = props.Max or 18
	props.Max = nil
	props.BackgroundColor3 = color
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextStrokeColor3 = INK
	props.TextStrokeTransparency = if props.TextColor3 == WHITE then 0 else 1
	props.FontFace = props.FontFace or TITLE
	props.TextScaled = true
	props.AutoButtonColor = true
	local padding = pad(6)
	local b = make("TextButton", props, {
		corner(12),
		stroke(INK, 3),
		padding,
		make("UITextSizeConstraint", { MaxTextSize = max }),
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 212, 232)), Rotation = 90 }),
	})
	if iconKey then
		local icon = uiIcon(iconKey, {
			Size = UDim2.new(1.35, 0, 1.35, 0), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -2, 0.5, 0),
			ZIndex = (props.ZIndex or 1) + 1, Parent = b,
		})
		if icon then
			padding.PaddingLeft = UDim.new(0.3, 0)
		end
	end
	-- juice: grow on hover, squish on press
	local scale = make("UIScale", { Parent = b })
	local function to(value: number)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.06)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.06)
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Square icon-only button. If the image is missing or still in moderation, shows a short caption instead.
local function iconButton(iconKey: string, captionKey: string, color: Color3, props, onClick)
	props.Text = ""
	props.Max = props.Max or 14
	local b = btn(color, props, onClick)
	make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = b })
	local icon = uiIcon(iconKey, {
		Size = UDim2.new(1.2, 0, 1.2, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = (props.ZIndex or 1) + 1, Parent = b,
	})
	local function caption()
		bind(b, captionKey)
		if icon then
			icon.Visible = false
		end
	end
	if not icon then
		caption()
	else
		task.delay(6, function()
			if not icon.IsLoaded then
				caption()
			end
		end)
	end
	return b
end

-- red "!" bubble in a button's corner
local function badge(target: GuiObject)
	return make("TextLabel", {
		Size = UDim2.new(0, 24, 0, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2),
		BackgroundColor3 = RED, Text = "!", TextScaled = true, FontFace = TITLE, TextColor3 = WHITE,
		TextStrokeColor3 = INK, TextStrokeTransparency = 0, Visible = false, ZIndex = (target.ZIndex or 1) + 5, Parent = target,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(INK, 2.5) })
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Star icon: uploaded image if configured, otherwise a drawn glowing disc
local function starIcon(star, mutation, props)
	local holder = make("Frame", props, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	holder.BackgroundTransparency = 1
	local id = Config.StarIcons[star.id]
	do
		local disc = make("Frame", {
			Size = UDim2.new(0.7, 0, 0.7, 0), Position = UDim2.new(0.15, 0, 0.15, 0), BackgroundColor3 = WHITE, ZIndex = holder.ZIndex, Parent = holder,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIGradient", { Color = ColorSequence.new(star.color:Lerp(WHITE, 0.6), star.color), Rotation = 45 }),
			stroke(shade(star.color, 0.25), 2),
		})
		local _ = disc
	end
	if id and id ~= "" then
		-- the photo covers the disc once it has loaded
		make("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = holder.ZIndex,
			Image = if string.find(id, "://") then id else "rbxassetid://" .. id, Parent = holder,
		})
	end
	if mutation and mutation.id ~= "normal" then
		make("Frame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = holder.ZIndex, Parent = holder,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(mutation.color, 3) })
	end
	return holder
end

---------------------------------------------------------------- Root
local gui = make("ScreenGui", {
	Name = "SkyHaven",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local function panelFrame(props)
	props.BackgroundColor3 = props.BackgroundColor3 or PANEL
	props.BackgroundTransparency = props.BackgroundTransparency or 0.04
	return make("Frame", props, { corner(16), stroke(INK, 3), pad(10) })
end

---------------------------------------------------------------- Header
local header = panelFrame({ Size = UDim2.new(0.5, 0, 0, 58), Position = UDim2.new(0.25, 0, 0, 8), Parent = gui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.01, 0), Parent = header })
local function readout(key: string, color: Color3, iconKey: string?, fallbackIcon: string?)
	local box = make("Frame", { Size = UDim2.new(0.19, 0, 1, 0), BackgroundTransparency = 1, Parent = header })
	bind(text({ Size = UDim2.new(1, 0, 0.36, 0), TextColor3 = MUTED, FontFace = BODY, Max = 12, Parent = box }), key)
	-- icon + number as one centered group
	local line = make("Frame", { Size = UDim2.new(1, 0, 0.64, 0), Position = UDim2.new(0, 0, 0.36, 0), BackgroundTransparency = 1, Parent = box })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = line,
	})
	-- icon goes to the RIGHT of the number
	if iconKey then
		local _ = uiIcon(iconKey, { Size = UDim2.new(0, 28, 0, 28), LayoutOrder = 3, Parent = line })
			or (fallbackIcon and uiIcon(fallbackIcon, { Size = UDim2.new(0, 28, 0, 28), LayoutOrder = 3, Parent = line }))
	end
	return make("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 2,
		Text = "0", TextColor3 = color, TextStrokeColor3 = INK, TextStrokeTransparency = 0.4, FontFace = TITLE, TextSize = 24, Parent = line,
	})
end
local cashValue = readout("cash", Color3.fromRGB(230, 150, 20), "coins", "cash")
local incomeValue = readout("perSec", MINT, "income")
local luckValue = readout("luck", BLUE, "luck")
local rollsValue = readout("rolls", LILAC, "rolls")
local rebirthValue = readout("rebirths", TEXT, "rebirth")

local showerBanner = text({ Size = UDim2.new(0.4, 0, 0, 22), Position = UDim2.new(0.3, 0, 0, 70), Text = "", TextColor3 = BLUE, FontFace = TITLE, TextStrokeColor3 = WHITE, TextStrokeTransparency = 0, Max = 18, Parent = gui })
local announce = text({
	Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.new(0.2, 0, 0, 94), Text = "", TextTransparency = 1,
	TextStrokeColor3 = WHITE, TextStrokeTransparency = 1, FontFace = TITLE, Max = 22, ZIndex = 50, Parent = gui,
})
local announceTween = nil
local function showToast(message: string, color: Color3?)
	if announceTween then
		announceTween:Cancel()
	end
	announce.Text = message
	announce.TextColor3 = if color then shade(color, 0.2) else TEXT
	announce.TextTransparency = 0
	announce.TextStrokeTransparency = 0
	announceTween = TweenService:Create(announce, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 3.5), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	})
	announceTween:Play()
end

---------------------------------------------------------------- Language toggle (top-left)
local langFrame = panelFrame({ Size = UDim2.new(0, 112, 0, 44), Position = UDim2.new(0, 16, 0, 64), Parent = gui })
local enButton, ruButton
local render -- forward

local function setLang(newLang: string)
	lang = newLang
	for _, entry in bound do
		entry.inst.Text = t(entry.key)
	end
	enButton.BackgroundColor3 = if lang == "en" then BLUE else PANEL_2
	enButton.TextColor3 = if lang == "en" then WHITE else MUTED
	ruButton.BackgroundColor3 = if lang == "ru" then BLUE else PANEL_2
	ruButton.TextColor3 = if lang == "ru" then WHITE else MUTED
	if render then
		render()
	end
end
enButton = btn(BLUE, { Size = UDim2.new(0.48, 0, 1, 0), Text = "EN", Max = 16, Parent = langFrame }, function()
	ActionEv:FireServer("SetLang", "en")
	setLang("en")
end)
ruButton = btn(PANEL_2, { Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), Text = "RU", Max = 16, Parent = langFrame }, function()
	ActionEv:FireServer("SetLang", "ru")
	setLang("ru")
end)

local settingsButton -- created after windows exist

---------------------------------------------------------------- Telescope (left)
local telescope = panelFrame({ Size = UDim2.new(0.17, 0, 0.4, 0), Position = UDim2.new(0, 16, 0, 120), Parent = gui }) -- below Roblox buttons, language and settings
bind(text({ Size = UDim2.new(1, 0, 0.08, 0), TextColor3 = BLUE, FontFace = TITLE, Max = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = telescope }), "telescope")
local resultName = bind(text({ Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.new(0, 0, 0.1, 0), FontFace = TITLE, Max = 24, Parent = telescope }), "rollHint")
local resultChance = text({ Size = UDim2.new(1, 0, 0.08, 0), Position = UDim2.new(0, 0, 0.26, 0), Text = "", TextColor3 = MUTED, Max = 15, Parent = telescope })
local rollButton, autoButton
local rollsLine = text({ Size = UDim2.new(1, 0, 0.08, 0), Position = UDim2.new(0, 0, 0.92, 0), Text = "", TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 14, Parent = telescope })

---------------------------------------------------------------- Windows
local windows = {}
local function window(titleKey: string, group: string, props)
	props.Visible = false
	props.ZIndex = 20
	props.Parent = gui
	local frame = panelFrame(props)
	local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BLUE, ZIndex = 21, Parent = frame }, {
		corner(12), stroke(INK, 3),
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(130, 200, 255), Color3.fromRGB(60, 130, 235)), Rotation = 90 }),
	})
	bind(text({ Size = UDim2.new(1, -70, 1, -8), Position = UDim2.new(0, 12, 0, 4), FontFace = TITLE, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 26, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = bar }), titleKey)
	btn(RED, { Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -40, 0, -8), Text = "X", Max = 24, ZIndex = 23, Parent = frame }, function()
		frame.Visible = false
	end)
	local body = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -50), Position = UDim2.new(0, 0, 0, 50), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 21,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, ScrollBarImageColor3 = LINE, Parent = frame,
	}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), make("UIPadding", { PaddingRight = UDim.new(0, 8) }) })
	local w = { frame = frame, body = body, group = group, scale = make("UIScale", { Parent = frame }) }
	table.insert(windows, w)
	return w
end

local CENTER = { Size = UDim2.new(0.42, 0, 0.66, 0), Position = UDim2.new(0.29, 0, 0.16, 0) }
local function centerProps()
	return { Size = CENTER.Size, Position = CENTER.Position }
end

local catalogueW = window("catalogue", "side", { Size = UDim2.new(0.25, 0, 0.66, 0), Position = UDim2.new(1, -104, 0.16, 0), AnchorPoint = Vector2.new(1, 0) })
local skyW = window("mySky", "center", centerProps())
local upgradesW = window("upgrades", "center", centerProps())
local indexW = window("indexTitle", "center", centerProps())
local bookW = window("bookTitle", "center", centerProps())
local oddsW = window("oddsTitle", "center", centerProps())
local pickerW = window("pickTitle", "center", centerProps())
local forgeW = window("forgeTitle", "center", centerProps())
local holeW = window("holeTitle", "center", centerProps())
local rewardsW = window("rewardsTitle", "center", { Size = UDim2.new(0.72, 0, 0.6, 0), Position = UDim2.new(0.14, 0, 0.18, 0) })
local settingsW = window("settings", "center", { Size = UDim2.new(0.38, 0, 0.56, 0), Position = UDim2.new(0.31, 0, 0.18, 0) })

-- catalogue: list + sell bar at the bottom
catalogueW.body.Size = UDim2.new(1, 0, 1, -124)
local sellBar = make("Frame", { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 1, -52), BackgroundTransparency = 1, ZIndex = 21, Visible = false, Parent = catalogueW.frame })
local sellInfo = text({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -80), Text = "", TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 14, ZIndex = 21, Parent = catalogueW.frame })

local renderers = {}
local function isOpen(w): boolean
	return w.frame.Visible
end
local onWindowOpened = nil -- set by build mode: opening any window leaves build mode
local function open(w, force: boolean?)
	local willShow = force or not w.frame.Visible
	if willShow then
		for _, other in windows do
			other.frame.Visible = false
		end
		if onWindowOpened then
			onWindowOpened()
		end
	end
	w.frame.Visible = willShow
	if willShow then
		w.scale.Scale = 0.85
		TweenService:Create(w.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if willShow and renderers[w] then
		local ok, err = pcall(renderers[w])
		if not ok then
			warn("[UI] window failed to render: " .. tostring(err))
		end
	end
end

---------------------------------------------------------------- Tip card (closable)
local tip = panelFrame({ Size = UDim2.new(0.17, 0, 0.14, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -80), Parent = gui }) -- just above the dock
bind(text({ Size = UDim2.new(1, -30, 1, 0), TextColor3 = TEXT, FontFace = BODY_SEMI, Max = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = tip }), "tip")
btn(RED, { Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -24, 0, -2), Text = "X", Max = 14, Parent = tip }, function()
	tip.Visible = false
end)

---------------------------------------------------------------- Row helpers
local function row(parent: Instance, order: number, height: number, color: Color3?)
	return make("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = color or PANEL_2, LayoutOrder = order, ZIndex = 21, Parent = parent }, { corner(12), stroke(LINE, 1) })
end

local function sortedInventory(filter: ((string) -> boolean)?): { string }
	local keys = {}
	if not state then
		return keys
	end
	for key in state.inventory do
		if Items.parse(key) and (not filter or filter(key)) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return Items.rank(a) > Items.rank(b)
	end)
	return keys
end

-- one inventory row: icon, bold name, subtext, count. Returns the row (a TextButton).
local function itemRow(parent: Instance, order: number, key: string, subText: string, highlighted: boolean?)
	local star, mutation = Items.parse(key)
	local r = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 58), LayoutOrder = order, Text = "", AutoButtonColor = true, ZIndex = 21,
		BackgroundColor3 = if highlighted then Color3.fromRGB(220, 236, 255) else WHITE, Parent = parent,
	}, { corner(12), stroke(if highlighted then BLUE else LINE, if highlighted then 2.5 else 1.5) })
	starIcon(star, mutation, { Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(0, 6, 0, 6), ZIndex = 22, Parent = r })
	text({ Size = UDim2.new(1, -120, 0, 26), Position = UDim2.new(0, 58, 0, 6), Text = Lang.item(lang, key), FontFace = TITLE, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, Max = 19, ZIndex = 22, Parent = r })
	text({ Size = UDim2.new(1, -120, 0, 18), Position = UDim2.new(0, 58, 0, 33), Text = subText, FontFace = BODY_SEMI, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Max = 14, ZIndex = 22, Parent = r })
	text({ Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(1, -60, 0, 0), Text = "x" .. (state.inventory[key] or 0), FontFace = TITLE, TextColor3 = if mutation.id ~= "normal" then shade(mutation.color, 0.2) else BLUE, Max = 20, ZIndex = 22, Parent = r })
	return r
end

local function itemSubText(key: string): string
	local onPlot = 0
	if state then
		for _, cell in state.grid do
			if cell.id == key then
				onPlot += 1
			end
		end
	end
	return t("oneIn", Format.number(Items.chance(key))) .. "  ·  " .. t("perSecShort", Format.number(Items.income(key)))
		.. "  ·  " .. t("sellsFor", Format.number(Items.income(key) * Config.SellMultiplier))
		.. (if onPlot > 0 then "  ·  " .. t("onPlot", onPlot) else "")
end

---------------------------------------------------------------- Catalogue
local sell1Button, sellAllButton
renderers[catalogueW] = function()
	local body = catalogueW.body
	clear(body)
	if selected and not state.inventory[selected] then
		selected = nil
	end
	local keys = sortedInventory()
	if #keys == 0 then
		text({ Size = UDim2.new(1, 0, 0, 40), Text = t("emptyCatalogue"), TextColor3 = MUTED, Max = 16, ZIndex = 21, Parent = body })
	end
	for order, key in keys do
		itemRow(body, order, key, itemSubText(key), selected == key).Activated:Connect(function()
			selected = if selected == key then nil else key
			renderers[catalogueW]()
		end)
	end
	sellBar.Visible = selected ~= nil
	sellInfo.Text = if selected then Lang.item(lang, selected) else ""
	sell1Button.Text = t("sell1")
	sellAllButton.Text = t("sellAll")
end
sell1Button = btn(GOLD, { Size = UDim2.new(0.48, 0, 1, 0), Text = "", ZIndex = 22, Parent = sellBar }, function()
	if selected then
		ActionEv:FireServer("Sell", selected, 1)
	end
end)
sellAllButton = btn(RED, { Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), Text = "", ZIndex = 22, Parent = sellBar }, function()
	if selected and state then
		ActionEv:FireServer("Sell", selected, state.inventory[selected] or 0)
	end
end)

---------------------------------------------------------------- My Sky (overview of the plot)
renderers[skyW] = function()
	local body = skyW.body
	clear(body)
	if not state.hasPlot then
		text({ Size = UDim2.new(1, 0, 0, 50), Text = t("skyNoPlot"), TextColor3 = MUTED, TextWrapped = true, Max = 18, ZIndex = 21, Parent = body })
		return
	end
	text({ Size = UDim2.new(1, 0, 0, 24), Text = t("skyHint"), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 15, LayoutOrder = 1, ZIndex = 21, Parent = body })
	local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 21, Parent = body })
	local grid = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 210, 140), ZIndex = 21, Parent = holder }, {
		corner(14), stroke(Color3.fromRGB(120, 180, 110), 2), pad(8), make("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	-- square that fits the window width
	holder.Size = UDim2.new(1, 0, 0, math.max(200, body.AbsoluteSize.X - 16))
	local size = state.gridSize
	make("UIGridLayout", { CellSize = UDim2.new(1 / size, -6, 1 / size, -6), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
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
			local cellFrame = make("Frame", { LayoutOrder = y * 100 + x, BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, ZIndex = 22, Parent = grid }, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local group = inGroup[key]
			if group then
				stroke(if group.pure then BLUE else GOLD, 3).Parent = cellFrame
			end
			local star, mutation = Items.parse(cell and cell.id)
			if star then
				starIcon(star, mutation, { Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.05, 0), ZIndex = 23, Parent = cellFrame })
				local level = Evolution.level(cell.age or 0)
				text({ Size = UDim2.new(0.6, 0, 0.26, 0), Position = UDim2.new(0.2, 0, 0.74, 0), Text = "Lv" .. level, FontFace = TITLE, TextColor3 = TEXT, Max = 13, ZIndex = 24, Parent = cellFrame })
			end
		end
	end
end

---------------------------------------------------------------- Picker (from a pedestal)
renderers[pickerW] = function()
	local body = pickerW.body
	clear(body)
	local keys = sortedInventory()
	if #keys == 0 then
		text({ Size = UDim2.new(1, 0, 0, 40), Text = t("pickEmpty"), TextColor3 = MUTED, Max = 16, ZIndex = 21, Parent = body })
	end
	for order, key in keys do
		itemRow(body, order, key, itemSubText(key)).Activated:Connect(function()
			if pickerCell then
				ActionEv:FireServer("Place", pickerCell, key)
			end
			pickerW.frame.Visible = false
		end)
	end
end

---------------------------------------------------------------- Upgrades
renderers[upgradesW] = function()
	local body = upgradesW.body
	clear(body)
	local function upgrade(order: number, nameKey: string, desc: string, maxed: boolean, cost: number, action: string, color: Color3)
		local r = row(body, order, 70, WHITE)
		text({ Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.new(0, 12, 0, 8), Text = t(nameKey), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 20, ZIndex = 22, Parent = r })
		text({ Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 12, 0, 40), Text = desc, FontFace = BODY_SEMI, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Max = 15, ZIndex = 22, Parent = r })
		btn(if maxed then GREY else color, {
			Size = UDim2.new(0.36, 0, 0, 46), Position = UDim2.new(0.62, 0, 0, 12), ZIndex = 22, Max = 17,
			Text = if maxed then t("upMax") else t("buy", Format.number(cost)), Parent = r,
		}, function()
			if not maxed then
				ActionEv:FireServer(action)
			end
		end)
	end
	local luckNow = 1 + state.luckLevel * Config.LuckPerLevel
	upgrade(1, "upLuck", t("upLuckDesc", luckNow, luckNow + Config.LuckPerLevel), state.luckLevel >= Config.MaxLuckLevel, Config.LuckCost(state.luckLevel), "BuyLuck", MINT)
	local speedNow = math.floor(Config.RollCooldown(state.rollSpeedLevel) * 100) / 100
	local speedNext = math.floor(Config.RollCooldown(state.rollSpeedLevel + 1) * 100) / 100
	upgrade(2, "upSpeed", t("upSpeedDesc", speedNow, speedNext), state.rollSpeedLevel >= Config.MaxRollSpeedLevel, Config.RollSpeedCost(state.rollSpeedLevel), "BuySpeed", BLUE)
	upgrade(3, "upMulti", t("upMultiDesc", 1 + state.multiRollLevel, 2 + state.multiRollLevel), state.multiRollLevel >= Config.MaxMultiRollLevel, Config.MultiRollCost(state.multiRollLevel), "BuyMulti", LILAC)
	local floors = state.floors or 1
	upgrade(4, "upFloor", t("upFloorDesc", floors, floors + 1), floors >= Config.MaxFloors, Config.FloorCost(floors + 1), "BuyFloor", GOLD)
end

---------------------------------------------------------------- Star Index (+ roll rewards)
local indexTier = 1
renderers[indexW] = function()
	local body = indexW.body
	clear(body)
	local tabRows = math.ceil(#Config.IndexTiers / 5)
	local tabs = make("Frame", { Size = UDim2.new(1, 0, 0, tabRows * 40), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 21, Parent = body })
	make("UIGridLayout", { CellSize = UDim2.new(0.2, -5, 0, 34), CellPadding = UDim2.new(0, 5, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	for number, tier in Config.IndexTiers do
		local label = t("oneIn", Format.number(Stars.List[tier.first].chance)) .. "–" .. Format.number(Stars.List[tier.last].chance)
		btn(if indexTier == number then BLUE else GREY, { LayoutOrder = number, Text = label, Max = 13, ZIndex = 22, Parent = tabs }, function()
			indexTier = number
			renderers[indexW]()
		end)
	end
	local tier = Config.IndexTiers[indexTier]
	local count = tier.last - tier.first + 1
	for order, mutation in Mutations.List do
		local found = 0
		for i = tier.first, tier.last do
			if state.index[Items.key(Stars.List[i].id, mutation.id)] then
				found += 1
			end
		end
		local complete = found == count
		local claimed = state.indexClaims[indexTier .. ":" .. mutation.id] == true
		local reward = tier.luck * (Config.IndexMutationMult[mutation.id] or 1)
		local r = row(body, order, 64 + 52, WHITE)
		text({ Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.new(0, 10, 0, 6), Text = Lang.mutation(lang, mutation) .. "   " .. found .. "/" .. count, FontFace = TITLE, TextColor3 = if mutation.id == "normal" then TEXT else shade(mutation.color, 0.25), TextXAlignment = Enum.TextXAlignment.Left, Max = 18, ZIndex = 22, Parent = r })
		text({ Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.new(0, 10, 0, 30), Text = t("rowReward", reward), FontFace = BODY_SEMI, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Max = 13, ZIndex = 22, Parent = r })
		btn(if claimed then GREY elseif complete then MINT else GREY, { Size = UDim2.new(0.34, 0, 0, 36), Position = UDim2.new(0.64, 0, 0, 8), ZIndex = 22, Max = 15, Text = if claimed then t("claimed") else t("claim"), Parent = r }, function()
			if complete and not claimed then
				ActionEv:FireServer("ClaimIndexRow", mutation.id, indexTier)
			end
		end)
		local strip = make("Frame", { Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 0, 58), BackgroundTransparency = 1, ZIndex = 22, Parent = r })
		make("UIGridLayout", { CellSize = UDim2.new(1 / count, -4, 1, 0), CellPadding = UDim2.new(0, 4, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = strip })
		for i = tier.first, tier.last do
			local star = Stars.List[i]
			if state.index[Items.key(star.id, mutation.id)] then
				starIcon(star, mutation, { LayoutOrder = i, ZIndex = 23, Parent = strip })
			else
				local unknown = make("Frame", { LayoutOrder = i, BackgroundTransparency = 1, ZIndex = 23, Parent = strip }, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
				make("TextLabel", {
					Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.1, 0), BackgroundColor3 = PANEL_2, Text = "?", TextScaled = true,
					FontFace = TITLE, TextColor3 = GREY, ZIndex = 24, Parent = unknown,
				}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			end
		end
	end
end

---------------------------------------------------------------- Roll rewards (cards)
local rewardsBody = rewardsW.body
rewardsBody.Size = UDim2.new(0.72, 0, 1, -50)
rewardsBody.Position = UDim2.new(0.28, 0, 0, 50)
rewardsBody.ScrollingDirection = Enum.ScrollingDirection.X
rewardsBody.AutomaticCanvasSize = Enum.AutomaticSize.X
rewardsBody.ScrollBarThickness = 8
local rewardsLayout = rewardsBody:FindFirstChildOfClass("UIListLayout")
rewardsLayout.FillDirection = Enum.FillDirection.Horizontal
rewardsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
rewardsLayout.Padding = UDim.new(0, 10)
local rewardsSummary = make("Frame", {
	Size = UDim2.new(0.26, 0, 1, -50), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = WHITE, ZIndex = 21, Parent = rewardsW.frame,
}, {
	corner(14), stroke(INK, 3),
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 190, 255), Color3.fromRGB(90, 90, 230)), Rotation = 90 }),
})

local function stroked(props)
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextStrokeColor3 = INK
	props.TextStrokeTransparency = 0
	props.FontFace = props.FontFace or TITLE
	props.ZIndex = props.ZIndex or 22
	return text(props)
end

-- icon for a milestone reward: the star itself, or coin / clover
local function rewardIcon(milestone, props)
	if milestone.item then
		local star, mutation = Items.parse(milestone.item)
		if star then
			return starIcon(star, mutation, props)
		end
	end
	local key = if milestone.cash then "cash" else "luck"
	local icon = uiIcon(key, props)
	if icon then
		return icon
	end
	local color = if milestone.cash then GOLD else MINT
	local holder = make("Frame", props, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	holder.BackgroundTransparency = 1
	make("TextLabel", {
		Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.1, 0), BackgroundColor3 = color,
		Text = if milestone.cash then "$" else "+", TextScaled = true, FontFace = TITLE, TextColor3 = WHITE,
		TextStrokeColor3 = INK, TextStrokeTransparency = 0, ZIndex = holder.ZIndex, Parent = holder,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(INK, 3) })
	return holder
end

local function rewardName(milestone): string
	if milestone.item then
		return Lang.item(lang, milestone.item)
	end
	return if milestone.cash then t("cashWord") else t("luckWord")
end

local function rewardAmount(milestone): string
	if milestone.item then
		return "x" .. (milestone.count or 1)
	end
	return if milestone.cash then "+" .. Format.number(milestone.cash) else "+" .. milestone.luck
end

renderers[rewardsW] = function()
	clear(rewardsBody)
	clear(rewardsSummary)
	local rolls = state.rebirthRolls or state.totalRolls

	-- left: progress summary
	stroked({ Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.new(0, 0, 0.03, 0), Text = t("rewardsDone"), Max = 22, Parent = rewardsSummary })
	stroked({ Size = UDim2.new(1, 0, 0.24, 0), Position = UDim2.new(0, 0, 0.14, 0), Text = Format.number(rolls), Max = 64, Parent = rewardsSummary })
	local nextMilestone = nil
	for _, milestone in Config.RollMilestones do
		if rolls < milestone.rolls then
			nextMilestone = milestone
			break
		end
	end
	if nextMilestone then
		stroked({ Size = UDim2.new(1, 0, 0.08, 0), Position = UDim2.new(0, 0, 0.46, 0), Text = t("nextReward"), Max = 18, Parent = rewardsSummary })
		local iconBox = make("Frame", { Size = UDim2.new(0.42, 0, 0.32, 0), Position = UDim2.new(0.04, 0, 0.58, 0), BackgroundTransparency = 1, ZIndex = 22, Parent = rewardsSummary })
		rewardIcon(nextMilestone, { Size = UDim2.new(1, 0, 1, 0), ZIndex = 23, Parent = iconBox })
		stroked({ Size = UDim2.new(0.5, 0, 0.12, 0), Position = UDim2.new(0.48, 0, 0.6, 0), Text = rewardAmount(nextMilestone), Max = 26, Parent = rewardsSummary })
		stroked({ Size = UDim2.new(0.5, 0, 0.14, 0), Position = UDim2.new(0.48, 0, 0.74, 0), Text = t("moreRolls", Format.number(nextMilestone.rolls - rolls)), TextWrapped = true, Max = 18, Parent = rewardsSummary })
	else
		stroked({ Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.new(0, 0, 0.55, 0), Text = t("allDone"), TextWrapped = true, Max = 22, Parent = rewardsSummary })
	end

	-- right: one card per milestone
	local h = math.max(160, rewardsBody.AbsoluteSize.Y - 14)
	local w = math.floor(h * 0.66)
	for i, milestone in Config.RollMilestones do
		local claimed = state.milestones[tostring(i)] == true
		local ready = rolls >= milestone.rolls and not claimed
		local card = make("Frame", {
			Size = UDim2.new(0, w, 0, h), LayoutOrder = i, ZIndex = 21, Parent = rewardsBody,
			BackgroundColor3 = if claimed then Color3.fromRGB(205, 242, 220) elseif ready then Color3.fromRGB(255, 244, 200) else WHITE,
		}, { corner(14), stroke(if ready then GOLD else INK, if ready then 4 else 3) })
		stroked({ Size = UDim2.new(1, 0, 0.09, 0), Position = UDim2.new(0, 0, 0.03, 0), Text = t("rollsWord"), TextColor3 = BLUE, Max = 20, Parent = card })
		stroked({ Size = UDim2.new(1, 0, 0.17, 0), Position = UDim2.new(0, 0, 0.12, 0), Text = Format.number(milestone.rolls), Max = 48, Parent = card })
		local mutation = nil
		if milestone.item then
			local _, parsed = Items.parse(milestone.item)
			mutation = parsed
		end
		stroked({
			Size = UDim2.new(0.94, 0, 0.08, 0), Position = UDim2.new(0.03, 0, 0.31, 0), Text = rewardName(milestone), Max = 18,
			TextColor3 = if mutation and mutation.id ~= "normal" then mutation.color elseif milestone.cash then GOLD elseif milestone.luck then MINT else BLUE,
			Parent = card,
		})
		local box = make("Frame", {
			Size = UDim2.new(0.84, 0, 0.38, 0), Position = UDim2.new(0.08, 0, 0.41, 0), BackgroundColor3 = PANEL_2, ZIndex = 22, Parent = card,
		}, { corner(12), stroke(INK, 2.5) })
		rewardIcon(milestone, { Size = UDim2.new(0.78, 0, 0.78, 0), Position = UDim2.new(0.11, 0, 0.06, 0), ZIndex = 23, Parent = box })
		stroked({ Size = UDim2.new(0.9, 0, 0.26, 0), Position = UDim2.new(0.05, 0, 0.72, 0), Text = rewardAmount(milestone), Max = 26, ZIndex = 24, Parent = box })
		btn(if ready then MINT else GREY, {
			Size = UDim2.new(0.86, 0, 0.13, 0), Position = UDim2.new(0.07, 0, 0.84, 0), ZIndex = 22, Max = 20,
			Text = if claimed then t("claimed") elseif ready then t("claim") else t("locked"), Parent = card,
		}, function()
			if ready then
				ActionEv:FireServer("ClaimMilestone", i)
			end
		end)
	end
end

---------------------------------------------------------------- Constellation book
renderers[bookW] = function()
	local body = bookW.body
	clear(body)
	for order, pattern in Constellations.List do
		local found = state and state.discovered[pattern.id]
		local r = row(body, order, 76, WHITE)
		local maxX, maxY = 0, 0
		for _, c in pattern.cells do
			maxX = math.max(maxX, c[1])
			maxY = math.max(maxY, c[2])
		end
		local box = make("Frame", { Size = UDim2.new(0, 62, 0, 62), Position = UDim2.new(0, 7, 0, 7), BackgroundColor3 = PANEL_2, ZIndex = 22, Parent = r }, { corner(10) })
		local cell = 56 / math.max(maxX + 1, maxY + 1)
		for _, c in pattern.cells do
			make("Frame", {
				Size = UDim2.new(0, cell * 0.6, 0, cell * 0.6), Position = UDim2.new(0, 3 + c[1] * cell + cell * 0.2, 0, 3 + c[2] * cell + cell * 0.2),
				BackgroundColor3 = if found then GOLD else GREY, ZIndex = 23, Parent = box,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		text({ Size = UDim2.new(1, -90, 0, 28), Position = UDim2.new(0, 80, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, FontFace = TITLE, Max = 19,
			Text = if found then Lang.constellation(lang, pattern) else t("unknown"), TextColor3 = if found then TEXT else MUTED, Parent = r })
		text({ Size = UDim2.new(1, -90, 0, 20), Position = UDim2.new(0, 80, 0, 42), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, FontFace = BODY_SEMI, Max = 15,
			Text = if found then t("incomeX", pattern.mult) else t("nStars", #pattern.cells), TextColor3 = MUTED, Parent = r })
	end
	text({ Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 999, ZIndex = 21, TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 14, TextWrapped = true, Text = t("bookHint", Constellations.PureBonus), Parent = body })
end

---------------------------------------------------------------- Odds
renderers[oddsW] = function()
	local body = oddsW.body
	clear(body)
	local luck = if state then state.luck else 1
	local odds = Odds.exact(luck)
	for i = 1, #Stars.List do
		local star = Stars.List[i]
		local r = row(body, i, 40, WHITE)
		starIcon(star, nil, { Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 4, 0, 4), ZIndex = 22, Parent = r })
		text({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 44, 0, 0), Text = Lang.star(lang, star), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 22, Parent = r })
		text({ Size = UDim2.new(0.45, -10, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Text = t("oneIn", Format.number(if odds[star.id] > 0 then 1 / odds[star.id] else star.chance)), TextColor3 = MUTED, FontFace = BODY_SEMI, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 22, Parent = r })
	end
	text({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 100, Text = t("mutations"), TextColor3 = BLUE, FontFace = TITLE, Max = 16, ZIndex = 21, Parent = body })
	text({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 101, Text = t("mutationsInfo"), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 14, ZIndex = 21, Parent = body })
	for i, mutation in Mutations.List do
		if mutation.copies then
			local r = row(body, 101 + i, 40, WHITE)
			text({ Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0), Text = Lang.mutation(lang, mutation), FontFace = TITLE, TextColor3 = shade(mutation.color, 0.25), TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 22, Parent = r })
			text({ Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.new(0.4, 0, 0, 0), Text = t("upgradeTo", mutation.copies, Lang.mutation(lang, mutation), mutation.chance), TextColor3 = MUTED, FontFace = BODY_SEMI, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 22, Parent = r })
		end
	end
end

---------------------------------------------------------------- Forge (only at the forge table)
renderers[forgeW] = function()
	local body = forgeW.body
	clear(body)
	text({ Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 0, Text = t("forgeHint", Config.ForgeAmount), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 15, ZIndex = 21, Parent = body })
	for order, key in sortedInventory() do
		local star, mutation = Items.parse(key)
		local nextStar = Stars.List[star.index + 1]
		local have = state.inventory[key]
		local sub = if nextStar
			then "→ " .. Lang.item(lang, Items.key(nextStar.id, mutation.id)) .. "   " .. t("forgeHave", math.min(have, Config.ForgeAmount), Config.ForgeAmount)
			else t("forgeMax")
		local r = itemRow(body, order, key, sub)
		if nextStar then
			local ready = have >= Config.ForgeAmount
			btn(if ready then GOLD else GREY, { Size = UDim2.new(0, 110, 0, 40), Position = UDim2.new(1, -290, 0, 9), ZIndex = 23, Max = 13,
				Text = t("forgeBtn", Format.number(nextStar.income * Config.ForgeCostMult)), Parent = r }, function()
				ActionEv:FireServer("Forge", key)
			end)
		end
		local nextMutation = Mutations.List[mutation.index + 1]
		if nextMutation then
			local upgraded = Items.key(star.id, nextMutation.id)
			local ready = have >= nextMutation.copies
			btn(if ready then shade(nextMutation.color, 0.15) else GREY, { Size = UDim2.new(0, 110, 0, 40), Position = UDim2.new(1, -174, 0, 9), ZIndex = 23, Max = 13,
				Text = t("upgradeBtn", Format.number(Items.income(upgraded) * Config.ForgeCostMult)), Parent = r }, function()
				ActionEv:FireServer("UpgradeMutation", key)
			end)
		end
	end
end

---------------------------------------------------------------- Black Hole (only at the altar)
renderers[holeW] = function()
	local body = holeW.body
	clear(body)
	local cost = Config.RebirthCost(state.rebirths)
	local progress = math.clamp(state.mass / cost, 0, 1)
	text({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Text = t("mass", Format.number(state.mass), Format.number(cost)), FontFace = TITLE, Max = 20, ZIndex = 21, Parent = body })
	local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = PANEL_2, LayoutOrder = 2, ZIndex = 21, Parent = body }, { corner(9), stroke(LINE, 1.5) })
	make("Frame", { Size = UDim2.new(progress, 0, 1, 0), BackgroundColor3 = LILAC, BorderSizePixel = 0, ZIndex = 22, Parent = bar }, { corner(9) })
	local lines = {
		t("holeNow", 1 + state.rebirths * Config.RebirthIncomeBonus, 1 + state.rebirths * Config.RebirthLuckMult),
		t("holeNext", 1 + (state.rebirths + 1) * Config.RebirthIncomeBonus, 1 + (state.rebirths + 1) * Config.RebirthLuckMult),
		t("holeWarn"),
	}
	for i, line in lines do
		text({ Size = UDim2.new(1, 0, 0, if i == 3 then 36 else 22), LayoutOrder = 2 + i, Text = line, TextColor3 = if i == 1 then TEXT else MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 15, ZIndex = 21, Parent = body })
	end
	local ready = progress >= 1
	btn(if ready then LILAC else GREY, { Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 10, Text = if ready then t("rebirth") else t("notEnough"), ZIndex = 21, Max = 20, Parent = body }, function()
		if ready then
			ActionEv:FireServer("Rebirth")
		end
	end, "rebirth")
	text({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 11, Text = t("holeFeed"), TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 15, ZIndex = 21, Parent = body })
	for order, key in sortedInventory() do
		local mass = Items.income(key) * Config.SellMultiplier
		local r = itemRow(body, 20 + order, key, "+" .. Format.number(mass))
		btn(LILAC, { Size = UDim2.new(0, 70, 0, 40), Position = UDim2.new(1, -212, 0, 9), ZIndex = 23, Max = 12, Text = t("feed1"), Parent = r }, function()
			ActionEv:FireServer("Feed", key, 1)
		end)
		btn(shade(LILAC, 0.15), { Size = UDim2.new(0, 70, 0, 40), Position = UDim2.new(1, -136, 0, 9), ZIndex = 23, Max = 12, Text = t("feedAll"), Parent = r }, function()
			ActionEv:FireServer("Feed", key, state.inventory[key] or 0)
		end)
	end
end

---------------------------------------------------------------- Settings + audio
local function soundId(id: string?): string?
	if not id or id == "" then
		return nil
	end
	return if string.find(id, "://") then id else "rbxassetid://" .. id
end

local music = make("Sound", { Name = "Music", Volume = Config.Sounds.MusicVolume, Parent = SoundService })
local musicTracks = {}
for _, id in Config.Sounds.Music do
	local resolved = soundId(id)
	if resolved then
		table.insert(musicTracks, resolved)
	end
end
local trackIndex = 1
music.Looped = #musicTracks == 1
music.Ended:Connect(function()
	if #musicTracks > 1 then
		trackIndex = trackIndex % #musicTracks + 1
		music.SoundId = musicTracks[trackIndex]
		music:Play()
	end
end)

local function settingOn(name: string): boolean
	return not state or not state.settings or state.settings[name] ~= false
end

local function applyMusic()
	if #musicTracks == 0 then
		return
	end
	if settingOn("music") then
		if not music.IsPlaying then
			music.SoundId = musicTracks[trackIndex]
			music:Play()
		end
	else
		music:Stop()
	end
end

local function playSfx(id: string?, volume: number)
	local resolved = soundId(id)
	if not resolved or not settingOn("sfx") then
		return
	end
	local s = make("Sound", { SoundId = resolved, Volume = volume, Parent = SoundService })
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(15, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

renderers[settingsW] = function()
	local body = settingsW.body
	clear(body)
	for order, name in { "music", "sfx" } do
		local r = row(body, order, 60, WHITE)
		text({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0), Text = t(name), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 22, ZIndex = 22, Parent = r })
		local on = settingOn(name)
		btn(if on then MINT else GREY, { Size = UDim2.new(0.38, 0, 0, 42), Position = UDim2.new(0.58, 0, 0, 9), Text = if on then t("on") else t("off"), Max = 20, ZIndex = 22, Parent = r }, function()
			if state then
				state.settings = state.settings or {}
				state.settings[name] = not on
				ActionEv:FireServer("SetSetting", name, not on)
				applyMusic()
				renderers[settingsW]()
			end
		end)
	end
	-- from which odds the big reveal / announcements show up
	local alertRow = row(body, 3, 160, WHITE)
	text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 14, 0, 6), Text = t("rareAlert"), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 20, ZIndex = 22, Parent = alertRow })
	local options = make("Frame", { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 0, 46), BackgroundTransparency = 1, ZIndex = 22, Parent = alertRow })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = options })
	local current = (state and state.settings and state.settings.rareAlert) or 50000000
	text({ Size = UDim2.new(0.42, 0, 0, 40), Position = UDim2.new(0, 14, 0, 106), Text = t("customAlert"), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 17, ZIndex = 22, Parent = alertRow })
	local custom = make("TextBox", {
		Size = UDim2.new(0.5, 0, 0, 40), Position = UDim2.new(0.46, 0, 0, 106), BackgroundColor3 = PANEL_2, Text = if current > 0 then Format.number(current) else "",
		PlaceholderText = "5M, 2.5B, 1e12", TextColor3 = TEXT, FontFace = TITLE, TextScaled = true, ClearTextOnFocus = false, ZIndex = 23, Parent = alertRow,
	}, { corner(10), stroke(INK, 2.5), pad(6), make("UITextSizeConstraint", { MaxTextSize = 18 }) })
	custom.FocusLost:Connect(function()
		local value = Format.parse(custom.Text)
		if value and value >= 1 and state then
			state.settings = state.settings or {}
			state.settings.rareAlert = value
			ActionEv:FireServer("SetSetting", "rareAlert", value)
			renderers[settingsW]()
		end
	end)
	for _, value in { 1000, 1000000, 50000000, 1000000000, 0 } do
		btn(if current == value then BLUE else GREY, {
			Size = UDim2.new(0.2, -5, 1, 0), Text = if value == 0 then t("alertOff") else t("oneIn", Format.number(value)), Max = 15, ZIndex = 23, Parent = options,
		}, function()
			if state then
				state.settings = state.settings or {}
				state.settings.rareAlert = value
				ActionEv:FireServer("SetSetting", "rareAlert", value)
				renderers[settingsW]()
			end
		end)
	end
end

settingsButton = iconButton("settings", "settings", Color3.fromRGB(120, 130, 160), { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 136, 0, 64), Max = 10, Parent = gui }, function()
	open(settingsW)
end)

-- Rebirth celebration: sound, white flash, big title, camera punch
local function celebrateRebirth()
	playSfx(Config.Sounds.Rebirth, Config.Sounds.RebirthVolume)
	local flash = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 100, Parent = gui })
	TweenService:Create(flash, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	local title = text({
		Size = UDim2.new(0.2, 0, 0.06, 0), Position = UDim2.new(0.5, 0, 0.42, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = t("rebirthBig"), FontFace = TITLE, TextColor3 = LILAC, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 96, ZIndex = 101, Parent = gui,
	})
	TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = UDim2.new(0.7, 0, 0.2, 0) }):Play()
	task.delay(2.4, function()
		TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(3.4, function()
		flash:Destroy()
		title:Destroy()
	end)
	local camera = workspace.CurrentCamera
	if camera then
		local fov = camera.FieldOfView
		local punch = TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { FieldOfView = fov + 18 })
		punch:Play()
	end
end

---------------------------------------------------------------- Admin panel (only shown when the server says you are admin)
local adminW = window("admin", "center", { Size = UDim2.new(0.46, 0, 0.72, 0), Position = UDim2.new(0.27, 0, 0.14, 0) })
local adminStar = Stars.List[#Stars.List].id
local adminMutation = "normal"

local function inputBox(parent: Instance, hintKey: string, defaultText: string, props)
	props.BackgroundColor3 = WHITE
	props.PlaceholderText = t(hintKey)
	props.Text = defaultText
	props.TextColor3 = TEXT
	props.FontFace = TITLE
	props.TextScaled = true
	props.ClearTextOnFocus = false
	props.ZIndex = 22
	props.Parent = parent
	return make("TextBox", props, { corner(10), stroke(INK, 2.5), pad(6), make("UITextSizeConstraint", { MaxTextSize = 18 }) })
end

renderers[adminW] = function()
	local body = adminW.body
	clear(body)
	local function section(order: number, titleKey: string, height: number)
		local r = row(body, order, height, WHITE)
		text({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 6), Text = t(titleKey), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 19, ZIndex = 22, Parent = r })
		return r
	end
	local function amountRow(order: number, titleKey: string, action: string, default: string)
		local r = section(order, titleKey, 84)
		local box = inputBox(r, "amountHint", default, { Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.new(0, 10, 0, 36) })
		btn(MINT, { Size = UDim2.new(0.32, 0, 0, 40), Position = UDim2.new(0.66, 0, 0, 36), Text = t("give"), ZIndex = 22, Parent = r }, function()
			local value = Format.parse(box.Text)
			if value then
				ActionEv:FireServer(action, value)
			else
				box.Text = ""
			end
		end)
	end
	amountRow(1, "adminCash", "AdminCash", "1Qd")

	-- star picker: all stars as icons, mutations as buttons
	local gridRows = math.ceil(#Stars.List / 8)
	local gridHeight = gridRows * 62
	local starRow = section(2, "adminStar", 170 + gridHeight)
	local grid = make("Frame", { Size = UDim2.new(1, -20, 0, gridHeight), Position = UDim2.new(0, 10, 0, 36), BackgroundTransparency = 1, ZIndex = 22, Parent = starRow })
	make("UIGridLayout", { CellSize = UDim2.new(1 / 8, -6, 1 / gridRows, -6), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for _, star in Stars.List do
		local cell = make("TextButton", {
			LayoutOrder = star.index, Text = "", AutoButtonColor = true, ZIndex = 23, Parent = grid,
			BackgroundColor3 = if adminStar == star.id then Color3.fromRGB(220, 236, 255) else PANEL_2,
		}, { corner(10), stroke(if adminStar == star.id then BLUE else LINE, if adminStar == star.id then 3 else 1.5) })
		starIcon(star, Mutations.ById[adminMutation], { Size = UDim2.new(0.9, 0, 0.9, 0), Position = UDim2.new(0.05, 0, 0.05, 0), ZIndex = 24, Parent = cell })
		cell.Activated:Connect(function()
			adminStar = star.id
			renderers[adminW]()
		end)
	end
	local mutations = make("Frame", { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 0, 42 + gridHeight), BackgroundTransparency = 1, ZIndex = 22, Parent = starRow })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = mutations })
	for _, mutation in Mutations.List do
		btn(if adminMutation == mutation.id then BLUE else GREY, { Size = UDim2.new(0.19, -5, 1, 0), Text = Lang.mutation(lang, mutation), Max = 14, ZIndex = 23, Parent = mutations }, function()
			adminMutation = mutation.id
			renderers[adminW]()
		end)
	end
	local key = Items.key(adminStar, adminMutation)
	text({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 84 + gridHeight), Text = Lang.item(lang, key) .. "   " .. t("oneIn", Format.number(Items.chance(key))), FontFace = TITLE, TextColor3 = BLUE, Max = 17, ZIndex = 22, Parent = starRow })
	local countBox = inputBox(starRow, "countHint", "1", { Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.new(0, 10, 0, 118 + gridHeight) })
	btn(MINT, { Size = UDim2.new(0.32, 0, 0, 40), Position = UDim2.new(0.66, 0, 0, 118 + gridHeight), Text = t("give"), ZIndex = 22, Parent = starRow }, function()
		local count = Format.parse(countBox.Text)
		if count and count >= 1 then
			ActionEv:FireServer("AdminStar", key, count)
		end
	end)

	amountRow(3, "adminRolls", "AdminRolls", "1000")
	amountRow(4, "adminMass", "AdminMass", "1M")

	local events = section(5, "adminEvents", 140)
	btn(BLUE, { Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 0, 38), Text = t("adminShower"), ZIndex = 22, Max = 17, Parent = events }, function()
		ActionEv:FireServer("AdminShower")
	end)
	btn(LILAC, { Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 0, 88), Text = t("adminGlobal"), ZIndex = 22, Max = 17, Parent = events }, function()
		ActionEv:FireServer("AdminGlobalTest", key)
	end)
end

local adminButton = iconButton("admin", "admin", Color3.fromRGB(230, 90, 90), { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 188, 0, 64), Max = 9, Visible = false, Parent = gui }, function()
	open(adminW)
end)

---------------------------------------------------------------- Server-wide cinematic for 1-in-a-billion finds
local function rareThreshold(): number
	local value = state and state.settings and state.settings.rareAlert
	if value == 0 then
		return math.huge -- off
	end
	return value or 50000000
end

local function circle(px: number, color: Color3, z: number, parent: Instance)
	return make("Frame", {
		Size = UDim2.new(0, px, 0, px), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z, Parent = parent,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function shakeCamera(duration: number, power: number)
	task.spawn(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local stop = os.clock() + duration
		while os.clock() < stop do
			local k = (stop - os.clock()) / duration * power
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- The big reveal: darkness, a falling star, impact, shockwaves, particles, then the star and its odds
local function bigReveal(key: string, chance: number, finder: string?)
	local star, mutation = Items.parse(key)
	if not star then
		return
	end
	local glow = if mutation.id ~= "normal" then mutation.color else star.color
	local root = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(6, 4, 20), BackgroundTransparency = 1, ZIndex = 200, Parent = gui })
	TweenService:Create(root, TweenInfo.new(0.6), { BackgroundTransparency = 0.2 }):Play()

	-- 1) the falling star with a fiery trail
	local meteor = make("Frame", { Size = UDim2.new(0, 80, 0, 80), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1.1, 0, -0.15, 0), BackgroundTransparency = 1, ZIndex = 205, Parent = root })
	starIcon(star, mutation, { Size = UDim2.new(1, 0, 1, 0), ZIndex = 206, Parent = meteor })
	local fall = TweenService:Create(meteor, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.42, 0), Rotation = 540 })
	fall:Play()
	task.spawn(function()
		local stop = os.clock() + 1
		while os.clock() < stop do
			local dot = circle(math.random(14, 34), if math.random() < 0.5 then glow else Color3.fromRGB(255, 200, 120), 204, root)
			dot.Position = meteor.Position
			TweenService:Create(dot, TweenInfo.new(0.6), { Size = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1 }):Play()
			task.delay(0.65, function()
				dot:Destroy()
			end)
			task.wait(0.025)
		end
	end)

	task.delay(1, function()
		meteor:Destroy()
		-- 2) impact: flash, shockwaves, rays, particle burst, shake, sound
		playSfx(if Config.Sounds.GlobalRare ~= "" then Config.Sounds.GlobalRare else Config.Sounds.Rebirth, 1)
		shakeCamera(0.8, 1.6)
		local camera = workspace.CurrentCamera
		if camera then
			TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { FieldOfView = camera.FieldOfView + 22 }):Play()
		end
		local flash = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, ZIndex = 230, Parent = root })
		TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()

		for i = 1, 3 do
			local ring = make("Frame", {
				Size = UDim2.new(0, 20, 0, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), BackgroundTransparency = 1, ZIndex = 210, Parent = root,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = if i == 2 then WHITE else glow, Thickness = 10 - i * 2 }) })
			local stroke = ring:FindFirstChildOfClass("UIStroke")
			task.delay((i - 1) * 0.15, function()
				TweenService:Create(ring, TweenInfo.new(1, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 1500, 0, 1500) }):Play()
				TweenService:Create(stroke, TweenInfo.new(1), { Transparency = 1 }):Play()
			end)
			task.delay(1.4, function()
				ring:Destroy()
			end)
		end

		local rays = make("Frame", { Size = UDim2.new(0, 1600, 0, 1600), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), BackgroundTransparency = 1, ZIndex = 201, Parent = root })
		for i = 1, 8 do
			make("Frame", {
				Size = UDim2.new(0, 60, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = i * (180 / 8),
				BackgroundColor3 = if i % 2 == 0 then glow else WHITE, BorderSizePixel = 0, ZIndex = 201, Parent = rays,
			}, { make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
		end
		TweenService:Create(rays, TweenInfo.new(6, Enum.EasingStyle.Linear), { Rotation = 140 }):Play()

		local burstColors = { glow, WHITE, Color3.fromRGB(255, 210, 110), star.color }
		for _ = 1, 70 do
			local dot = circle(math.random(6, 20), burstColors[math.random(1, #burstColors)], 220, root)
			dot.Position = UDim2.new(0.5, 0, 0.42, 0)
			local a = math.random() * math.pi * 2
			local dist = math.random(180, 760)
			local life = 0.8 + math.random() * 0.9
			TweenService:Create(dot, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(a) * dist, 0.42, math.sin(a) * dist), BackgroundTransparency = 1, Size = UDim2.new(0, 3, 0, 3),
			}):Play()
			task.delay(life + 0.05, function()
				dot:Destroy()
			end)
		end

		-- 3) the star itself
		local holder = make("Frame", { Size = UDim2.new(0, 660, 0, 440), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), BackgroundTransparency = 1, ZIndex = 240, Parent = root })
		local scale = make("UIScale", { Scale = 0, Parent = holder })
		starIcon(star, mutation, { Size = UDim2.new(0, 240, 0, 240), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 241, Parent = holder })
		local function line(y: number, h: number, value: string, color: Color3, max: number)
			text({ Size = UDim2.new(1, 0, 0, h), Position = UDim2.new(0, 0, 0, y), Text = value, FontFace = TITLE, TextColor3 = color, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = max, ZIndex = 242, Parent = holder })
		end
		local y = 244
		if finder then
			line(y, 36, t("globalFound", finder), WHITE, 32)
			y += 36
		end
		line(y, 76, Lang.item(lang, key), glow, 70)
		line(y + 76, 50, t("oneIn", Format.number(chance)), GOLD, 46)
		TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Back), { Scale = 1 }):Play()

		-- sparkles hovering around the star while it is shown
		task.spawn(function()
			local stop = os.clock() + 3.6
			while os.clock() < stop and root.Parent do
				local dot = circle(math.random(5, 12), if math.random() < 0.5 then WHITE else glow, 239, root)
				local a = math.random() * math.pi * 2
				local r = math.random(120, 200)
				dot.Position = UDim2.new(0.5, math.cos(a) * r, 0.33, math.sin(a) * r)
				TweenService:Create(dot, TweenInfo.new(1.2), { Position = UDim2.new(0.5, math.cos(a) * (r + 60), 0.33, math.sin(a) * (r + 60) - 40), BackgroundTransparency = 1 }):Play()
				task.delay(1.25, function()
					dot:Destroy()
				end)
				task.wait(0.05)
			end
		end)

		task.delay(4.2, function()
			TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
			TweenService:Create(root, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
			for _, ray in rays:GetChildren() do
				if ray:IsA("Frame") then
					TweenService:Create(ray, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
				end
			end
			task.wait(1)
			root:Destroy()
		end)
	end)
end

GlobalRareEv.OnClientEvent:Connect(function(finder: string, key: string, chance: number)
	if chance >= rareThreshold() then
		bigReveal(key, chance, finder)
	end
end)

---------------------------------------------------------------- Sprint: Shift on PC, a button on phones
local sprinting = false
local function applySpeed()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if sprinting then Config.SprintSpeed else Config.WalkSpeed
	end
end
ContextActionService:BindAction("Sprint", function(_, inputState, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		if inputState == Enum.UserInputState.Begin then
			sprinting = not sprinting -- tap to toggle on touch screens
		end
	else
		sprinting = inputState == Enum.UserInputState.Begin
	end
	applySpeed()
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
ContextActionService:SetTitle("Sprint", "RUN")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -170))
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	applySpeed()
end)

---------------------------------------------------------------- Leaderboard tablets (scrollable top 100 drawn on the stone)
local BOARD_TITLES = { rolls = "lbRolls", rebirths = "lbRebirths", cash = "lbCash", rarest = "lbRarest" }
local boardGuis = {}

local function renderBoard(board: string)
	local entry = boardGuis[board]
	local source = ReplicatedStorage:FindFirstChild("Leaderboards")
	local value = source and source:FindFirstChild(board)
	if not entry or not value then
		return
	end
	entry.title.Text = t(BOARD_TITLES[board])
	clear(entry.list)
	local ok, rows = pcall(HttpService.JSONDecode, HttpService, value.Value)
	if not ok or type(rows) ~= "table" or #rows == 0 then
		text({ Size = UDim2.new(1, 0, 0, 50), Text = t("lbEmpty"), TextColor3 = Color3.fromRGB(70, 72, 84), FontFace = TITLE, Max = 34, Parent = entry.list })
		return
	end
	local medal = { Color3.fromRGB(230, 170, 30), Color3.fromRGB(150, 160, 175), Color3.fromRGB(190, 110, 60) }
	for rank, row in rows do
		local line = make("Frame", { Size = UDim2.new(1, -12, 0, 54), LayoutOrder = rank, BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(150, 152, 166) else Color3.fromRGB(160, 162, 176), BackgroundTransparency = 0.3, Parent = entry.list }, { corner(8) })
		text({ Size = UDim2.new(0, 70, 1, 0), Text = "#" .. rank, FontFace = TITLE, TextColor3 = medal[rank] or WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0.2, Max = 30, Parent = line })
		text({ Size = UDim2.new(0.48, -70, 1, 0), Position = UDim2.new(0, 72, 0, 0), Text = tostring(row.name), FontFace = TITLE, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Left, Max = 28, Parent = line })
		local shown
		if board == "rarest" then
			shown = if type(row.value) == "string" then Lang.item(lang, row.value) .. "  " .. t("oneIn", Format.number(Items.chance(row.value))) else "?"
		else
			shown = Format.number(tonumber(row.value) or 0)
		end
		text({ Size = UDim2.new(0.52, -8, 1, 0), Position = UDim2.new(0.48, 0, 0, 0), Text = shown, FontFace = TITLE, TextColor3 = Color3.fromRGB(255, 226, 130), TextStrokeColor3 = INK, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Right, Max = 26, Parent = line })
	end
end

task.spawn(function()
	local boards = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Leaderboards")
	local source = ReplicatedStorage:WaitForChild("Leaderboards")
	for board in BOARD_TITLES do
		local part = boards:WaitForChild("Board_" .. board)
		local surface = make("SurfaceGui", {
			Name = "Board_" .. board, Adornee = part, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
			CanvasSize = Vector2.new(600, 800), LightInfluence = 0, MaxDistance = 140, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui"),
		})
		local title = text({ Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 0, 10), Text = "", FontFace = TITLE, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 64, Parent = surface })
		make("Frame", { Size = UDim2.new(0.9, 0, 0, 4), Position = UDim2.new(0.05, 0, 0, 104), BackgroundColor3 = Color3.fromRGB(236, 196, 100), BorderSizePixel = 0, Parent = surface })
		local list = make("ScrollingFrame", {
			Size = UDim2.new(1, -20, 1, -130), Position = UDim2.new(0, 10, 0, 118), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 12, ScrollBarImageColor3 = Color3.fromRGB(236, 196, 100),
			ScrollingDirection = Enum.ScrollingDirection.Y, Parent = surface,
		}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		boardGuis[board] = { title = title, list = list }
		local value = source:WaitForChild(board)
		value.Changed:Connect(function()
			renderBoard(board)
		end)
		renderBoard(board)
	end
end)

---------------------------------------------------------------- Build mode: buy slabs and put them on your plot
local buildMode = false
local buildTool: string? = Config.Slabs[1].id -- slab id, "remove", or nil (nothing selected)
local pendingRemove: string? = nil -- slab waiting for the ✓ confirmation
local pendingPlace: string? = nil -- phones: spot waiting for the ✓ confirmation
local hoverKey: string? = nil -- PC: spot under the mouse
local setBuildMode -- defined below (the panel's EXIT button needs it)
local buildPanel = panelFrame({ Size = UDim2.new(0, 640, 0, 196), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Visible = false, ZIndex = 30, Parent = gui })

local function myPlotFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function refreshMarkers()
	local plot = myPlotFolder()
	local markers = plot and plot:FindFirstChild("Markers")
	if not markers then
		return
	end
	for _, marker in markers:GetChildren() do
		if marker:IsA("BasePart") then
			local name = marker.Name
			local focused = name == pendingRemove or name == pendingPlace or name == hoverKey
			marker.Transparency = if not buildMode then 1 elseif focused then 0.3 elseif buildTool then 0.78 else 0.9
			marker.Color = if name == pendingRemove then RED
				elseif name == pendingPlace or name == hoverKey then BLUE
				elseif buildTool == "remove" then RED
				elseif buildTool then MINT
				else WHITE
		end
	end
end

local function renderBuildPanel()
	clear(buildPanel)
	text({ Size = UDim2.new(1, -110, 0, 26), Text = t("buildTitle") .. "   ·   " .. t("buildHint"), FontFace = TITLE, TextColor3 = BLUE, TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 31, Parent = buildPanel })
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0, 32), BackgroundTransparency = 1, ZIndex = 31, Parent = buildPanel })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	for i, slab in Config.Slabs do
		local selectedSlab = buildTool == slab.id
		local card = make("TextButton", {
			Size = UDim2.new(0, 112, 1, 0), LayoutOrder = i, Text = "", AutoButtonColor = true, ZIndex = 31, Parent = row,
			BackgroundColor3 = if selectedSlab then Color3.fromRGB(220, 236, 255) else WHITE,
		}, { corner(12), stroke(if selectedSlab then BLUE else INK, if selectedSlab then 3.5 else 2.5) })
		make("Frame", { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0.5, -20, 0, 6), BackgroundColor3 = slab.color, ZIndex = 32, Parent = card }, { corner(6), stroke(INK, 2) })
		text({ Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0, 3, 0, 48), Text = t("slab_" .. slab.id), FontFace = TITLE, Max = 13, ZIndex = 32, Parent = card })
		text({ Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0, 3, 0, 68), Text = Format.number(slab.cost) .. "  ·  x" .. slab.mult, FontFace = BODY, TextColor3 = MUTED, Max = 13, ZIndex = 32, Parent = card })
		card.Activated:Connect(function()
			buildTool = if buildTool == slab.id then nil else slab.id -- tap again to deselect
			pendingRemove = nil
			pendingPlace = nil
			renderBuildPanel()
			refreshMarkers()
		end)
	end
	-- grey until selected, red while active; tap again to deselect
	btn(if buildTool == "remove" then RED else GREY, { Size = UDim2.new(0, 84, 1, 0), LayoutOrder = 10, Text = t("removeTool"), Max = 14, ZIndex = 31, Parent = row }, function()
		buildTool = if buildTool == "remove" then nil else "remove"
		pendingRemove = nil
		pendingPlace = nil
		renderBuildPanel()
		refreshMarkers()
	end)
	btn(BLUE, { Size = UDim2.new(0, 84, 1, 0), LayoutOrder = 11, Text = t("exitBuild"), Max = 14, ZIndex = 31, Parent = row }, function()
		setBuildMode(false)
	end)

	-- themes for the museum
	local themes = make("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 132), BackgroundTransparency = 1, ZIndex = 31, Parent = buildPanel })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = themes })
	text({ Size = UDim2.new(0, 70, 1, 0), LayoutOrder = 0, Text = t("theme"), FontFace = TITLE, TextColor3 = BLUE, Max = 15, ZIndex = 32, Parent = themes })
	for i, theme in Config.Themes do
		local current = state and state.theme == theme.id
		btn(theme.wall, {
			Size = UDim2.new(0, 104, 1, 0), LayoutOrder = i, Text = t("theme_" .. theme.id), Max = 13, ZIndex = 32, Parent = themes,
			TextColor3 = WHITE,
		}, function()
			ActionEv:FireServer("SetTheme", theme.id)
		end):FindFirstChildOfClass("UIStroke").Color = if current then BLUE else INK
	end

	-- removing (and placing on phones) needs a confirmation
	local pending = pendingRemove or pendingPlace
	if pending then
		local removing = pendingRemove ~= nil
		local bar = panelFrame({ Size = UDim2.new(0, 400, 0, 58), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), ZIndex = 32, Parent = buildPanel })
		text({ Size = UDim2.new(1, -130, 1, 0), Text = t(if removing then "confirmRemove" else "confirmPlace"), FontFace = TITLE, TextColor3 = if removing then RED else BLUE, TextXAlignment = Enum.TextXAlignment.Left, Max = 18, ZIndex = 33, Parent = bar })
		btn(MINT, { Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(1, -120, 0, 0), Text = "✓", FontFace = Font.fromEnum(Enum.Font.SourceSansBold), Max = 30, ZIndex = 33, Parent = bar }, function()
			if pendingRemove then
				ActionEv:FireServer("RemoveSlab", pendingRemove)
			elseif pendingPlace and buildTool and buildTool ~= "remove" then
				ActionEv:FireServer("BuildSlab", pendingPlace, buildTool)
			end
			pendingRemove = nil
			pendingPlace = nil
			renderBuildPanel()
			refreshMarkers()
		end)
		btn(GREY, { Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(1, -58, 0, 0), Text = "X", Max = 26, ZIndex = 33, Parent = bar }, function()
			pendingRemove = nil
			pendingPlace = nil
			renderBuildPanel()
			refreshMarkers()
		end)
	end
end

local function nearMyPlot(): boolean
	local plot = myPlotFolder()
	local floor = plot and plot:FindFirstChild("Floor")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not floor or not root then
		return false
	end
	local offset = root.Position - floor.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.PlotReach
end

setBuildMode = function(on: boolean)
	if on and not (state and state.hasPlot) then
		showToast(t("buildNoPlot"))
		return
	end
	if on and not nearMyPlot() then
		showToast(t("farFromPlot"))
		return
	end
	if on then
		for _, w in windows do
			w.frame.Visible = false -- build mode gets the whole screen
		end
	end
	buildMode = on
	pendingRemove = nil
	pendingPlace = nil
	hoverKey = nil
	buildPanel.Visible = on
	if on then
		renderBuildPanel()
	end
	refreshMarkers()
end
onWindowOpened = function()
	if buildMode then
		setBuildMode(false)
	end
end

-- tap/click a marker on your plot while building
UserInputService.InputBegan:Connect(function(input, processed)
	if not buildMode or processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local plot = myPlotFolder()
	local markers = plot and plot:FindFirstChild("Markers")
	local camera = workspace.CurrentCamera
	if not markers or not camera then
		return
	end
	-- input positions exclude the top bar inset, ScreenPointToRay expects exactly that
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { markers }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit and hit.Instance and buildTool then
		local key = hit.Instance.Name
		if buildTool == "remove" then
			pendingRemove = if pendingRemove == key then nil else key -- tap again to cancel
		elseif input.UserInputType == Enum.UserInputType.Touch then
			pendingPlace = if pendingPlace == key then nil else key -- phones: tap, then ✓
		else
			ActionEv:FireServer("BuildSlab", key, buildTool) -- PC: click builds right away
		end
		renderBuildPanel()
		refreshMarkers()
	end
end)

-- PC: the spot under the mouse lights up blue
RunService.Heartbeat:Connect(function()
	if not buildMode or not UserInputService.MouseEnabled then
		return
	end
	local plot = myPlotFolder()
	local markers = plot and plot:FindFirstChild("Markers")
	local camera = workspace.CurrentCamera
	if not markers or not camera then
		return
	end
	local mouse = UserInputService:GetMouseLocation() -- viewport coordinates (with the top bar)
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { markers }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local key = if hit and hit.Instance and buildTool then hit.Instance.Name else nil
	if key ~= hoverKey then
		hoverKey = key
		refreshMarkers()
	end
end)

---------------------------------------------------------------- Icon buttons: bottom row + right column
local BUTTON = 72
local GAP = 12
local function buttonGroup(count: number, horizontal: boolean, props)
	props.BackgroundTransparency = 1
	props.Size = if horizontal
		then UDim2.new(0, count * BUTTON + (count - 1) * GAP, 0, BUTTON)
		else UDim2.new(0, BUTTON, 0, count * BUTTON + (count - 1) * GAP)
	local frame = make("Frame", props)
	make("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame,
	})
	return frame
end

local dockButtons = {}
local function addButtons(parent: Frame, entries)
	for order, entry in entries do
		local b = iconButton(entry[4], entry[1], entry[3], { Size = UDim2.new(0, BUTTON, 0, BUTTON), LayoutOrder = order, Parent = parent }, function()
			if entry[2] == "build" then
				setBuildMode(not buildMode)
			else
				open(entry[2])
			end
		end)
		dockButtons[entry[1]] = b
	end
end

local bottomRow = buttonGroup(3, true, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Parent = gui })
addButtons(bottomRow, {
	{ "upgrades", upgradesW, Color3.fromRGB(80, 210, 110), "upgrades" },
	{ "rewards", rewardsW, RED, "rewards" },
	{ "build", "build", Color3.fromRGB(240, 150, 60), "build" },
})
local rightColumn = buttonGroup(3, false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Parent = gui })
addButtons(rightColumn, {
	{ "catalogue", catalogueW, BLUE, "catalogue" },
	{ "index", indexW, LILAC, "index" },
	{ "odds", oddsW, GOLD, "odds" },
})
local rewardsBadge = badge(dockButtons.rewards)
local indexBadge = badge(dockButtons.index)

---------------------------------------------------------------- Render
local function canAutoRoll(): boolean
	return state ~= nil and state.totalRolls >= Config.AutoRollUnlock
end

local function renderTelescope()
	local multi = if state then 1 + state.multiRollLevel else 1
	rollButton.Text = if multi > 1 then t("rollN", multi) else t("roll")
	if not canAutoRoll() then
		autoRoll = false
		autoButton.Text = t("autoLocked", if state then math.min(state.totalRolls, Config.AutoRollUnlock) else 0, Config.AutoRollUnlock)
		autoButton.BackgroundColor3 = GREY
	else
		autoButton.Text = if autoRoll then t("autoOn") else t("autoOff")
		autoButton.BackgroundColor3 = if autoRoll then MINT else BLUE
	end
	rollsLine.Text = t("totalRolls", Format.number(if state then state.totalRolls else 0))
	if lastResult then
		local best = lastResult[1]
		for _, key in lastResult do
			if Items.chance(key) > Items.chance(best) then
				best = key
			end
		end
		local star = Items.parse(best)
		resultName.Text = Lang.item(lang, best)
		resultName.TextColor3 = shade(star.color, 0.25)
		resultChance.Text = t("oneIn", Format.number(Items.chance(best))) .. (if #lastResult > 1 then "   " .. t("andMore", #lastResult - 1) else "")
	end
end

render = function()
	if not state then
		return
	end
	incomeValue.Text = "+" .. Format.number(state.income)
	luckValue.Text = "x" .. (math.floor(state.luck * 100 + 0.5) / 100)
	rollsValue.Text = Format.number(state.totalRolls)
	rebirthValue.Text = tostring(state.rebirths)
	adminButton.Visible = state.isAdmin == true
	if buildMode then
		renderBuildPanel()
	end
	renderTelescope()

	local rewardReady = false
	for i, milestone in Config.RollMilestones do
		if (state.rebirthRolls or state.totalRolls) >= milestone.rolls and not state.milestones[tostring(i)] then
			rewardReady = true
		end
	end
	rewardsBadge.Visible = rewardReady
	local rowReady = false
	for number, tier in Config.IndexTiers do
		for _, mutation in Mutations.List do
			if not state.indexClaims[number .. ":" .. mutation.id] then
				local complete = true
				for i = tier.first, tier.last do
					if not state.index[Items.key(Stars.List[i].id, mutation.id)] then
						complete = false
						break
					end
				end
				rowReady = rowReady or complete
			end
		end
	end
	indexBadge.Visible = rowReady

	for _, w in windows do
		if w.frame.Visible and renderers[w] then
			local ok, err = pcall(renderers[w])
			if not ok then
				warn("[UI] window failed to render: " .. tostring(err))
			end
		end
	end
end

---------------------------------------------------------------- Roll
-- Big centered reveal for rare finds
showRare = function(key: string)
	bigReveal(key, Items.chance(key), nil)
end

local function doRoll()
	if rolling then
		return
	end
	rolling = true
	local result = nil
	local done = false
	task.spawn(function()
		result = RollFn:InvokeServer()
		done = true
	end)
	local started = os.clock()
	while (os.clock() - started < 0.5 or not done) and os.clock() - started < 5 do
		local fake = Stars.List[math.random(1, 6)]
		resultName.Text = Lang.star(lang, fake)
		resultName.TextColor3 = GREY
		resultChance.Text = "..."
		task.wait(0.06)
	end
	if type(result) == "table" and #result > 0 then
		lastResult = result
		resultName.Size = UDim2.new(1, 0, 0.2, 0)
		TweenService:Create(resultName, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0.16, 0) }):Play()
		local best = result[1]
		for _, key in result do
			if Items.chance(key) > Items.chance(best) then
				best = key
			end
		end
		if Items.chance(best) >= rareThreshold() and Items.chance(best) < Config.GlobalRareChance then
			showRare(best)
		end
	end
	renderTelescope()
	local cooldown = Config.RollCooldown(if state then state.rollSpeedLevel else 0)
	task.wait(math.max(0, cooldown - (os.clock() - started)))
	rolling = false
end

rollButton = btn(BLUE, { Size = UDim2.new(1, 0, 0.24, 0), Position = UDim2.new(0, 0, 0.38, 0), Text = "", Max = 30, Parent = telescope }, doRoll)
autoButton = btn(GREY, { Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.new(0, 0, 0.66, 0), Text = "", Max = 18, Parent = telescope }, function()
	if canAutoRoll() then
		autoRoll = not autoRoll
		renderTelescope()
	end
end)

---------------------------------------------------------------- Events
local firstState = true
StateEv.OnClientEvent:Connect(function(newState)
	local previous = state
	state = newState
	if previous and newState.rebirths > previous.rebirths then
		celebrateRebirth()
	end
	if firstState or (previous and previous.settings and newState.settings and previous.settings.music ~= newState.settings.music) then
		applyMusic()
	end
	if firstState then
		firstState = false
		setLang(if state.lang == "en" or state.lang == "ru" then state.lang else autoLang)
		tip.Visible = not state.hasPlot
	else
		render()
	end
end)

AnnounceEv.OnClientEvent:Connect(function(key: string, args, color: Color3?)
	if key == "annRolled" and type(args) == "table" and type(args[4]) == "number" and args[4] < rareThreshold() then
		return
	end
	showToast(Lang.resolve(lang, key, args), color)
end)

PickerEv.OnClientEvent:Connect(function(cellKey: string)
	pickerCell = cellKey
	open(pickerW, true)
end)

-- Forge / Black Hole windows are opened by the server when you use their prompts
OpenWindowEv.OnClientEvent:Connect(function(name: string)
	if name == "forge" then
		open(forgeW, true)
	elseif name == "hole" then
		open(holeW, true)
	end
end)

-- Cash readout
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	-- the number rolls smoothly to the new value
	local shown = Instance.new("NumberValue")
	shown.Value = cash.Value
	shown.Changed:Connect(function()
		cashValue.Text = Format.number(shown.Value)
	end)
	cash.Changed:Connect(function()
		TweenService:Create(shown, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = cash.Value }):Play()
	end)
	cashValue.Text = Format.number(cash.Value)
end)

---------------------------------------------------------------- World text, prompts, location windows (2x a second)
local function partAt(path: { string }): BasePart?
	local node: Instance? = workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local function distanceTo(part: BasePart?): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not part then
		return math.huge
	end
	return (root.Position - part.Position).Magnitude
end

task.spawn(function()
	while true do
		for _, label in CollectionService:GetTagged("WorldText") do
			local owner = label:GetAttribute("Owner")
			if owner ~= nil then
				label.Text = if owner ~= "" then t("signPlot", owner, Format.number(label:GetAttribute("Income") or 0)) else t("signFree")
			else
				label.Text = t(label:GetAttribute("LangKey") or "")
			end
		end
		for _, prompt in CollectionService:GetTagged("WorldPrompt") do
			prompt.ActionText = t(prompt:GetAttribute("LangKey") or "")
			local objKey = prompt:GetAttribute("ObjKey")
			prompt.ObjectText = if objKey then t(objKey) else ""
			local plotIndex = prompt:GetAttribute("Plot")
			if plotIndex then
				local plotFolder = prompt:FindFirstAncestor("Plot" .. plotIndex)
				prompt.Enabled = plotFolder ~= nil and plotFolder:GetAttribute("OwnerId") == player.UserId
			end
		end
		if buildMode then
			if not nearMyPlot() then
				setBuildMode(false)
				showToast(t("farFromPlot"))
			else
				refreshMarkers()
			end
		end
		if isOpen(forgeW) and distanceTo(partAt({ "Map", "Forge", "ForgeTable" })) > Config.ForgeReach + 6 then
			forgeW.frame.Visible = false
		end
		if isOpen(holeW) and distanceTo(partAt({ "Map", "BlackHoleIsland", "Altar" })) > Config.AltarReach + 6 then
			holeW.frame.Visible = false
		end

		local remaining = (ReplicatedStorage:GetAttribute("ShowerEndsAt") or 0) - workspace:GetServerTimeNow()
		showerBanner.Text = if remaining > 0 then t("shower", Config.ShowerLuck, Format.time(remaining)) else ""
		task.wait(0.5)
	end
end)

-- Auto roll
task.spawn(function()
	while true do
		if autoRoll and canAutoRoll() and not rolling then
			task.spawn(doRoll)
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------- Spinning star models on plots
local starModels: { [Model]: { base: CFrame, spin: number, phase: number } } = {}
local function trackModel(model: Instance)
	if model:IsA("Model") then
		starModels[model] = { spin = math.rad(model:GetAttribute("Spin") or 30), phase = math.random() * 6 }
	end
end
for _, model in CollectionService:GetTagged("StarModel") do
	trackModel(model)
end
CollectionService:GetInstanceAddedSignal("StarModel"):Connect(trackModel)
CollectionService:GetInstanceRemovedSignal("StarModel"):Connect(function(model)
	starModels[model :: Model] = nil
end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local eye = camera.CFrame.Position
	for model, info in starModels do
		local base = model:GetAttribute("Base")
		if typeof(base) == "CFrame" and model.PrimaryPart and model.Parent and (base.Position - eye).Magnitude < 160 then
			info.base = base
			local bob = math.sin(now * 1.6 + info.phase) * 0.25
			model:PivotTo(info.base * CFrame.Angles(0, now * info.spin, 0) + Vector3.new(0, bob, 0))
		end
	end
end)
