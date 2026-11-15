local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
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
local Pets = require(Shared.Pets)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollFn = Remotes:WaitForChild("Roll")
local ActionEv = Remotes:WaitForChild("Action")
local StateEv = Remotes:WaitForChild("State")
local AnnounceEv = Remotes:WaitForChild("Announce")
local PickerEv = Remotes:WaitForChild("OpenPicker")
local OpenWindowEv = Remotes:WaitForChild("OpenWindow")
local GlobalRareEv = Remotes:WaitForChild("GlobalRare")
local CrateEv = Remotes:WaitForChild("CrateResult")
local TradeEv = Remotes:WaitForChild("Trade")

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
	if (not id or id == "") and Config.UiIconFallback[key] then
		id = Config.UiIcons[Config.UiIconFallback[key]] -- new art not uploaded yet: use the older icon
	end
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
local readout, cashValue, incomeValue, luckValue, rollsValue, rebirthValue, luckyBar, luckyFill, luckyText, showerBanner, showToast
do
	local header = panelFrame({ Size = UDim2.new(0, 380, 0, 58), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = gui })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.01, 0), Parent = header })
	readout = function(key: string, color: Color3, iconKey: string?, fallbackIcon: string?)
		local box = make("Frame", { Size = UDim2.new(0.32, 0, 1, 0), BackgroundTransparency = 1, Parent = header })
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
	cashValue = readout("cash", Color3.fromRGB(230, 150, 20), "coins", "cash")
	local headerCashBox = cashValue.Parent.Parent
	incomeValue = readout("perSec", MINT, "income")
	luckValue = readout("luck", BLUE, "luck")
	rollsValue = readout("rolls", LILAC, "rolls")
	local headerRollsBox = rollsValue.Parent.Parent
	-- bottom-left corner: rolls and cash, big and chunky
	local cornerHud = make("Frame", { Size = UDim2.new(0, 360, 0, 120), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -10), BackgroundTransparency = 1, Parent = gui })
	local function hudLine(y: number, iconKey: string, color: Color3)
		local icon = uiIcon(iconKey, { Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 0, 0, y), Parent = cornerHud })
		local label = make("TextLabel", {
			Size = UDim2.new(1, -64, 0, 54), Position = UDim2.new(0, if icon then 62 else 0, 0, y), BackgroundTransparency = 1, Text = "0",
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic), TextScaled = true,
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = cornerHud,
		}, { make("UITextSizeConstraint", { MaxTextSize = 46 }), make("UIStroke", { Color = INK, Thickness = 3.5 }) })
		return label
	end
	rollsValue = hudLine(0, "rolls", WHITE)
	cashValue = hudLine(60, "coins", Color3.fromRGB(110, 255, 90))
	headerCashBox:Destroy()
	headerRollsBox:Destroy()
	rebirthValue = readout("rebirths", TEXT, "rebirth")

	-- x2 luck progress bar
	luckyBar = make("Frame", { Size = UDim2.new(0, 300, 0, 26), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), BackgroundColor3 = Color3.fromRGB(60, 66, 90), Parent = gui }, { corner(13), stroke(INK, 2.5) })
	luckyFill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = MINT, BorderSizePixel = 0, Parent = luckyBar }, { corner(13) })
	luckyText = text({ Size = UDim2.new(1, 0, 1, 0), Text = "", FontFace = TITLE, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 16, ZIndex = 2, Parent = luckyBar })

	showerBanner = text({ Size = UDim2.new(0.4, 0, 0, 22), Position = UDim2.new(0.3, 0, 0, 102), Text = "", TextColor3 = BLUE, FontFace = TITLE, TextStrokeColor3 = WHITE, TextStrokeTransparency = 0, Max = 18, Parent = gui })
	local announce = text({
		Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.new(0.2, 0, 0, 126), Text = "", TextTransparency = 1,
		TextStrokeColor3 = WHITE, TextStrokeTransparency = 1, FontFace = TITLE, Max = 22, ZIndex = 50, Parent = gui,
	})
	local announceTween = nil
	showToast = function(message: string, color: Color3?)
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
end

---------------------------------------------------------------- Language toggle (top-left)
local setLang
local render
local settingsButton
do
	local langFrame = panelFrame({ Size = UDim2.new(0, 112, 0, 44), Position = UDim2.new(0, 16, 0, 64), Visible = false, Parent = gui }) -- language lives in the settings now
	local enButton, ruButton

	setLang = function(newLang: string)
		lang = newLang
		for _, entry in bound do
			entry.inst.Text = t(entry.key)
		end
		enButton.BackgroundColor3 = if lang == "en" then BLUE else PANEL_2
		enButton.TextColor3 = if lang == "en" then WHITE else MUTED
		ruButton.BackgroundColor3 = if lang == "ru" then BLUE else PANEL_2
		ruButton.TextColor3 = if lang == "ru" then WHITE else MUTED
		if render then
			render(true) -- new language: every open window redraws
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

	-- created after windows exist
end

---------------------------------------------------------------- Telescope (left)
local telescope = panelFrame({ Size = UDim2.new(0, 330, 0, 240), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Parent = gui }) -- roll panel at the bottom centre
bind(text({ Size = UDim2.new(1, 0, 0.08, 0), TextColor3 = BLUE, FontFace = TITLE, Max = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = telescope }), "telescope")
local resultName = bind(text({ Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.new(0, 0, 0.1, 0), FontFace = TITLE, Max = 24, Parent = telescope }), "rollHint")
local resultChance = text({ Size = UDim2.new(1, 0, 0.08, 0), Position = UDim2.new(0, 0, 0.26, 0), Text = "", TextColor3 = MUTED, Max = 15, Parent = telescope })
local rollButton, autoButton
local rollsLine = text({ Size = UDim2.new(1, 0, 0.08, 0), Position = UDim2.new(0, 0, 0.92, 0), Text = "", TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 14, Parent = telescope })

---------------------------------------------------------------- Windows
local windows, window, catalogueW, skyW, upgradesW, indexW, bookW, oddsW, pickerW, forgeW, holeW, elevatorW, shopW, giftW, tradeW, playersW, tradeReqW, dailyW, codesW, lastCrate, crateInZone, dailyInZone, elevatorInfo, rewardsW, settingsW, sellBar, sellInfo, renderers, isOpen, onWindowOpened, open
do
	windows = {}
	window = function(titleKey: string, group: string, props)
		props.Visible = false
		props.ZIndex = 20
		props.Parent = gui
		local frame = panelFrame(props)
		-- chunky game-style board: dark slate frame, light inside, big title sitting on top
		frame.BackgroundColor3 = Color3.fromRGB(70, 78, 108)
		frame.BackgroundTransparency = 0
		local edge = frame:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Thickness = 4
		end
		local titleLabel = bind(text({
			Size = UDim2.new(1, -80, 0, 50), Position = UDim2.new(0, 4, 0, -62), FontFace = TITLE, TextColor3 = WHITE,
			TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 44, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 26, Parent = frame,
		}), titleKey)
		make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = titleLabel })
		btn(RED, { Size = UDim2.new(0, 58, 0, 58), Position = UDim2.new(1, -36, 0, -50), Text = "X", Max = 34, ZIndex = 27, Parent = frame }, function()
			frame.Visible = false
		end)
		local body = make("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -8), Position = UDim2.new(0, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(214, 222, 238), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 21,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = INK, Parent = frame,
		}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }), corner(10), stroke(INK, 2) })
		local w = { frame = frame, body = body, group = group, title = titleLabel, scale = make("UIScale", { Parent = frame }) }
		table.insert(windows, w)
		return w
	end

	local CENTER = { Size = UDim2.new(0.42, 0, 0.66, 0), Position = UDim2.new(0.29, 0, 0.16, 0) }
	local function centerProps()
		return { Size = CENTER.Size, Position = CENTER.Position }
	end

	catalogueW = window("catalogue", "side", { Size = UDim2.new(0.25, 0, 0.66, 0), Position = UDim2.new(1, -104, 0.16, 0), AnchorPoint = Vector2.new(1, 0) })
	skyW = window("mySky", "center", centerProps())
	upgradesW = window("upgrades", "center", centerProps())
	indexW = window("indexTitle", "center", centerProps())
	bookW = window("bookTitle", "center", centerProps())
	oddsW = window("oddsTitle", "center", centerProps())
	pickerW = window("pickTitle", "center", centerProps())
	forgeW = window("forgeTitle", "center", centerProps())
	holeW = window("holeTitle", "center", centerProps())
	elevatorW = window("elevatorTitle", "center", { Size = UDim2.new(0.26, 0, 0.5, 0), Position = UDim2.new(0.37, 0, 0.22, 0) })
	shopW = window("shop", "center", { Size = UDim2.new(0.66, 0, 0.72, 0), Position = UDim2.new(0.17, 0, 0.15, 0) })
	giftW = window("giftTo", "center", { Size = UDim2.new(0.3, 0, 0.5, 0), Position = UDim2.new(0.35, 0, 0.25, 0) })
	tradeW = window("tradeTitle", "center", { Size = UDim2.new(0.76, 0, 0.82, 0), Position = UDim2.new(0.12, 0, 0.09, 0) })
	playersW = window("tradePlayers", "center", { Size = UDim2.new(0.3, 0, 0.5, 0), Position = UDim2.new(0.35, 0, 0.25, 0) })
	tradeReqW = window("tradeTitle", "center", { Size = UDim2.new(0.36, 0, 0.28, 0), Position = UDim2.new(0.32, 0, 0.3, 0) })
	local crateW = window("crateGot", "center", { Size = UDim2.new(0.4, 0, 0.5, 0), Position = UDim2.new(0.3, 0, 0.24, 0) })
	dailyW = window("dailyTitle", "center", { Size = UDim2.new(0.66, 0, 0.5, 0), Position = UDim2.new(0.17, 0, 0.22, 0) })
	codesW = window("codes", "center", { Size = UDim2.new(0.34, 0, 0.32, 0), Position = UDim2.new(0.33, 0, 0.3, 0) })
	lastCrate = {}
	crateInZone = false
	dailyInZone = false
	elevatorInfo = { plot = 0, floor = 1, floors = 1 }
	rewardsW = window("rewardsTitle", "center", { Size = UDim2.new(0.72, 0, 0.6, 0), Position = UDim2.new(0.14, 0, 0.18, 0) })
	settingsW = window("settings", "center", { Size = UDim2.new(0.38, 0, 0.56, 0), Position = UDim2.new(0.31, 0, 0.18, 0) })

	-- a big picture next to each window title (when the icon is uploaded)
	for _, pair in { { forgeW, "forge" }, { holeW, "blackhole" }, { upgradesW, "upgrades" }, { indexW, "index" }, { rewardsW, "rewards" }, { oddsW, "odds" }, { shopW, "shop" }, { settingsW, "settings" }, { catalogueW, "backpack" }, { tradeW, "trade" } } do
		local w, key = pair[1], pair[2]
		if uiIcon(key, { Size = UDim2.new(0, 72, 0, 72), Position = UDim2.new(0, -18, 0, -86), Rotation = -8, ZIndex = 27, Parent = w.frame }) then
			w.title.Position = UDim2.new(0, 60, 0, -62)
			w.title.Size = UDim2.new(1, -136, 0, 50)
		end
	end

	-- catalogue: list + sell bar at the bottom
	catalogueW.body.Size = UDim2.new(1, 0, 1, -90)
	catalogueW.frame.BackgroundColor3 = Color3.fromRGB(196, 138, 74)
	catalogueW.body.BackgroundColor3 = Color3.fromRGB(74, 52, 40)
	sellBar = make("Frame", { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 1, -52), BackgroundTransparency = 1, ZIndex = 21, Visible = false, Parent = catalogueW.frame })
	sellInfo = text({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -80), Text = "", TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 14, ZIndex = 21, Parent = catalogueW.frame })

	renderers = {}
	isOpen = function(w): boolean
		return w.frame.Visible
	end
	onWindowOpened = nil -- set by build mode: opening any window leaves build mode
	open = function(w, force: boolean?)
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
		if willShow and w.group == "side" then
			local target = w.frame.Position
			w.frame.Position = target + UDim2.new(0, 520, 0, 0)
			TweenService:Create(w.frame, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Position = target }):Play()
		elseif willShow then
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
end

---------------------------------------------------------------- Tutorial card (first visit only, closable)
local tutorialCard, tutorialTitle, tutorialText, tutorialStep, tutorialClosed, TUTORIAL_STEPS
local tutorialNext
do
	tutorialCard = panelFrame({ Size = UDim2.new(0, 330, 0, 150), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 104, 0.42, 0), Visible = false, ZIndex = 40, Parent = gui })
	tutorialTitle = text({ Size = UDim2.new(1, -40, 0, 24), Text = "", FontFace = TITLE, TextColor3 = BLUE, TextXAlignment = Enum.TextXAlignment.Left, Max = 18, ZIndex = 41, Parent = tutorialCard })
	tutorialText = text({ Size = UDim2.new(1, 0, 0, 62), Position = UDim2.new(0, 0, 0, 28), Text = "", FontFace = BODY, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Max = 17, ZIndex = 41, Parent = tutorialCard })
	-- button, created below
	tutorialStep = 1
	tutorialClosed = false
	TUTORIAL_STEPS = 5
	local function finishTutorial()
		tutorialClosed = true
		tutorialCard.Visible = false
		ActionEv:FireServer("TutorialDone")
	end
	btn(RED, { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -30, 0, -4), Text = "X", Max = 16, ZIndex = 42, Parent = tutorialCard }, finishTutorial)
	tutorialNext = btn(MINT, { Size = UDim2.new(0, 130, 0, 36), Position = UDim2.new(1, -130, 1, -36), Text = "", Max = 16, ZIndex = 42, Parent = tutorialCard }, function()
		if tutorialStep >= TUTORIAL_STEPS then
			finishTutorial()
		else
			tutorialStep += 1
		end
	end)
end

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

-- shimmering rainbow text: every UIGradient tagged "RainbowFx" gets the moving rainbow
task.spawn(function()
	while true do
		local phase = (os.clock() * 0.25) % 1
		local points = {}
		for i = 0, 6 do
			table.insert(points, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((phase + i / 6 * 0.6) % 1, 0.75, 1)))
		end
		local sequence = ColorSequence.new(points)
		for _, gradient in CollectionService:GetTagged("RainbowFx") do
			gradient.Color = sequence
		end
		task.wait(0.05)
	end
end)

-- one inventory row: icon, bold name, subtext, count. Returns the row (a TextButton).
local function itemRow(parent: Instance, order: number, key: string, subText: string, highlighted: boolean?)
	local star, mutation = Items.parse(key)
	local r = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 58), LayoutOrder = order, Text = "", AutoButtonColor = true, ZIndex = 21,
		BackgroundColor3 = if highlighted then Color3.fromRGB(220, 236, 255) else WHITE, Parent = parent,
	}, { corner(12), stroke(if highlighted then BLUE else LINE, if highlighted then 2.5 else 1.5) })
	starIcon(star, mutation, { Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(0, 6, 0, 6), ZIndex = 22, Parent = r })
	-- name, then the shimmering odds right after it (left side, never under the buttons)
	local head = make("Frame", { Size = UDim2.new(1, -120, 0, 26), Position = UDim2.new(0, 58, 0, 6), BackgroundTransparency = 1, ZIndex = 22, Parent = r }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	make("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, BackgroundTransparency = 1, Text = Lang.item(lang, key), FontFace = TITLE, TextSize = 19, TextColor3 = TEXT, ZIndex = 22, Parent = head })
	local odds = make("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, BackgroundTransparency = 1, Text = t("oneIn", Format.number(Items.chance(key))), FontFace = TITLE, TextSize = 18, TextColor3 = WHITE, ZIndex = 22, Parent = head })
	make("UIStroke", { Color = INK, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = odds })
	CollectionService:AddTag(make("UIGradient", { Parent = odds }), "RainbowFx")
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
	return t("perSecShort", Format.number(Items.income(key)))
		.. "  ·  " .. t("sellsFor", Format.number(Items.income(key) * Config.SellMultiplier))
		.. (if onPlot > 0 then "  ·  " .. t("onPlot", onPlot) else "")
end

---------------------------------------------------------------- Catalogue
do
	local sell1Button, sellAllButton, petButton
	local petPicked: number? = nil -- pet slot whose info card is shown
	renderers[catalogueW] = function()
		local body = catalogueW.body
		clear(body)
		if selected and not state.inventory[selected] then
			selected = nil
		end
		-- equipped pets: tap one to take it back
		local pets = state.pets or {}
		local slots = Pets.slots(state)
		local petLuck, petSpeed = Pets.totals(pets)
		if petPicked and not pets[petPicked] then
			petPicked = nil
		end
		local panel = make("Frame", { Size = UDim2.new(1, 0, 0, if petPicked then 150 else 104), LayoutOrder = 0, BackgroundColor3 = Color3.fromRGB(44, 34, 80), ZIndex = 21, Parent = body }, { corner(12), stroke(INK, 2.5) })
		local head = text({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 4), Text = t("petsTitle", #pets, slots, math.floor(petLuck * 100 + 0.5), math.floor(petSpeed * 100 + 0.5)), FontFace = TITLE, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Max = 17, ZIndex = 22, Parent = panel })
		make("UIStroke", { Color = INK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = head })
		local row = make("Frame", { Size = UDim2.new(1, -16, 0, 62), Position = UDim2.new(0, 8, 0, 34), BackgroundTransparency = 1, ZIndex = 22, Parent = panel })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for slot = 1, slots do
			local key = pets[slot]
			local cell = make("TextButton", { Size = UDim2.new(0, 60, 0, 60), LayoutOrder = slot, Text = if key then "" else "+", FontFace = TITLE, TextSize = 28, TextColor3 = Color3.fromRGB(150, 140, 200), BackgroundColor3 = Color3.fromRGB(70, 58, 120), AutoButtonColor = true, ZIndex = 23, Parent = row }, {
				corner(30), stroke(if key then GOLD else Color3.fromRGB(110, 100, 170), 2.5),
			})
			if key then
				local star, mutation = Items.parse(key)
				if star then
					starIcon(star, mutation, { Size = UDim2.new(0.86, 0, 0.86, 0), Position = UDim2.new(0.07, 0, 0.07, 0), ZIndex = 24, Parent = cell })
				end
				if petPicked == slot then
					stroke(Color3.fromRGB(120, 255, 150), 4).Parent = cell
				end
				cell.Activated:Connect(function()
					petPicked = if petPicked == slot then nil else slot
					renderers[catalogueW]()
				end)
			end
		end
		if petPicked then
			local key = pets[petPicked]
			local info = text({ Size = UDim2.new(1, -150, 0, 36), Position = UDim2.new(0, 8, 0, 104), Text = Lang.item(lang, key) .. "   " .. t("petInfo", math.floor(Pets.luck(key) * 100 + 0.5), math.floor(Pets.speed(key) * 100 + 0.5)), FontFace = TITLE, TextColor3 = Color3.fromRGB(255, 225, 120), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Max = 15, ZIndex = 22, Parent = panel })
			make("UIStroke", { Color = INK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = info })
			local slotToRemove = petPicked
			btn(RED, { Size = UDim2.new(0, 130, 0, 36), Position = UDim2.new(1, -138, 0, 104), Text = t("petUnequip"), Max = 18, ZIndex = 23, Parent = panel }, function()
				petPicked = nil
				ActionEv:FireServer("PetUnequip", slotToRemove)
			end)
		end
		if #pets == 0 then
			text({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.new(0, 8, 1, -22), Text = t("petsHint"), TextColor3 = Color3.fromRGB(190, 180, 230), FontFace = BODY_SEMI, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Max = 12, ZIndex = 22, Parent = panel })
		end

		local keys = sortedInventory()
		if #keys == 0 then
			text({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Text = t("emptyCatalogue"), TextColor3 = MUTED, Max = 16, ZIndex = 21, Parent = body })
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
		petButton.Text = t("petEquip")
	end
	petButton = btn(Color3.fromRGB(150, 90, 255), { Size = UDim2.new(0.32, 0, 1, 0), Position = UDim2.new(0.68, 0, 0, 0), Text = "", ZIndex = 22, Parent = sellBar }, function()
		if selected then
			ActionEv:FireServer("PetEquip", selected)
		end
	end)
	sell1Button = btn(GOLD, { Size = UDim2.new(0.32, 0, 1, 0), Text = "", ZIndex = 22, Parent = sellBar }, function()
		if selected then
			ActionEv:FireServer("Sell", selected, 1)
		end
	end)
	sellAllButton = btn(RED, { Size = UDim2.new(0.32, 0, 1, 0), Position = UDim2.new(0.34, 0, 0, 0), Text = "", ZIndex = 22, Parent = sellBar }, function()
		if selected and state then
			ActionEv:FireServer("Sell", selected, state.inventory[selected] or 0)
		end
	end)
end

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
do
	local upgradesTab = "cash"
	local function cashUpgrades(body)
		local grid = make("Frame", { Size = UDim2.new(1, 0, 0, 2 * 236 + 10), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 21, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 236), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		local function upgrade(order: number, nameKey: string, iconKey: string, desc: string, maxed: boolean, cost: number, action: string, top: Color3, bottom: Color3)
			local card = make("Frame", { LayoutOrder = order, BackgroundColor3 = WHITE, ZIndex = 22, Parent = grid }, {
				corner(14), stroke(INK, 3.5),
				make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }),
			})
			-- soft shine on the upper half
			make("Frame", { Size = UDim2.new(1, -12, 0.35, 0), Position = UDim2.new(0, 6, 0, 6), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, ZIndex = 22, Parent = card }, { corner(10) })
			local icon = uiIcon(iconKey, { Size = UDim2.new(0, 84, 0, 84), Position = UDim2.new(0.5, -42, 0, 10), ZIndex = 24, Parent = card })
				or uiIcon(if iconKey == "bolt" then "rolls" else "upgrades", { Size = UDim2.new(0, 84, 0, 84), Position = UDim2.new(0.5, -42, 0, 10), ZIndex = 24, Parent = card })
			if not icon then
				text({ Size = UDim2.new(0, 84, 0, 84), Position = UDim2.new(0.5, -42, 0, 10), Text = string.sub(t(nameKey), 1, 1), FontFace = TITLE, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 60, ZIndex = 24, Parent = card })
			end
			local title = text({ Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0, 98), Text = t(nameKey), FontFace = TITLE, TextColor3 = WHITE, Max = 24, ZIndex = 24, Parent = card })
			make("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = title })
			local sub = text({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 0, 128), Text = desc, FontFace = TITLE, TextColor3 = WHITE, TextWrapped = true, Max = 18, ZIndex = 24, Parent = card })
			make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = sub })
			btn(if maxed then GREY else Color3.fromRGB(80, 210, 90), {
				Size = UDim2.new(if maxed then 1 else 0.68, if maxed then -20 else -14, 0, 50), Position = UDim2.new(0, 10, 1, -60), ZIndex = 24, Max = 24,
				Text = if maxed then t("upMax") else "$" .. Format.number(cost), Parent = card,
			}, function()
				if not maxed then
					ActionEv:FireServer(action)
				end
			end)
			if not maxed then
				btn(Color3.fromRGB(255, 170, 40), { Size = UDim2.new(0.32, -12, 0, 50), Position = UDim2.new(0.68, 2, 1, -60), Text = t("upMaxBtn"), Max = 20, ZIndex = 24, Parent = card }, function()
					ActionEv:FireServer("BuyMax", action)
				end)
			end
		end
		local luckNow = 1 + state.luckLevel * Config.LuckPerLevel
		upgrade(1, "upLuck", "luck", t("upLuckDesc", luckNow, luckNow + Config.LuckPerLevel), state.luckLevel >= Config.MaxLuckLevel, Config.LuckCost(state.luckLevel), "BuyLuck", Color3.fromRGB(110, 235, 120), Color3.fromRGB(30, 150, 70))
		local speedNow = math.floor(Config.RollCooldown(state.rollSpeedLevel) * 100) / 100
		local speedNext = math.floor(Config.RollCooldown(state.rollSpeedLevel + 1) * 100) / 100
		upgrade(2, "upSpeed", "bolt", t("upSpeedDesc", speedNow, speedNext), state.rollSpeedLevel >= Config.MaxRollSpeedLevel, Config.RollSpeedCost(state.rollSpeedLevel), "BuySpeed", Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 90, 220))
		upgrade(3, "upMulti", "dice2", t("upMultiDesc", 1 + state.multiRollLevel, 2 + state.multiRollLevel), state.multiRollLevel >= Config.MaxMultiRollLevel, Config.MultiRollCost(state.multiRollLevel), "BuyMulti", Color3.fromRGB(220, 140, 255), Color3.fromRGB(120, 50, 200))
		local floors = state.floors or 1
		upgrade(4, "upFloor", "build", t("upFloorDesc", floors, floors + 1), floors >= Config.MaxFloors, Config.FloorCost(floors + 1), "BuyFloor", Color3.fromRGB(255, 220, 100), Color3.fromRGB(230, 130, 30))
	end

	-- permanent upgrades bought with rebirth tokens
	local function rebirthUpgrades(body)
		local tokens = math.max(0, state.rebirthTokens or 0)
		local info = make("Frame", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, BackgroundColor3 = Color3.fromRGB(120, 70, 220), ZIndex = 22, Parent = body }, { corner(12), stroke(INK, 3) })
		uiIcon("rebirth", { Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0, 8, 0, 3), ZIndex = 23, Parent = info })
		local label = text({ Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 52, 0, 0), Text = t("rebirthTokens", tokens), FontFace = TITLE, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Max = 24, ZIndex = 23, Parent = info })
		make("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
		local rows = math.ceil(#Config.RebirthUpgrades / 2)
		local grid = make("Frame", { Size = UDim2.new(1, 0, 0, rows * 246), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 21, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 236), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		local colors = {
			pets = { Color3.fromRGB(255, 150, 220), Color3.fromRGB(190, 60, 160) },
			luck = { Color3.fromRGB(110, 235, 120), Color3.fromRGB(30, 150, 70) },
			cash = { Color3.fromRGB(255, 220, 100), Color3.fromRGB(230, 130, 30) },
			speed = { Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 90, 220) },
			multi = { Color3.fromRGB(220, 140, 255), Color3.fromRGB(120, 50, 200) },
		}
		for order, upgrade in Config.RebirthUpgrades do
			local level = Config.RebirthUp(state, upgrade.id)
			local maxed = level >= upgrade.max
			local cost = Config.RebirthUpCost(level)
			local c = colors[upgrade.id] or colors.luck
			local card = make("Frame", { LayoutOrder = order, BackgroundColor3 = WHITE, ZIndex = 22, Parent = grid }, {
				corner(14), stroke(INK, 3.5), make("UIGradient", { Color = ColorSequence.new(c[1], c[2]), Rotation = 90 }),
			})
			uiIcon(upgrade.icon, { Size = UDim2.new(0, 80, 0, 80), Position = UDim2.new(0.5, -40, 0, 10), ZIndex = 24, Parent = card })
			local title = text({ Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0, 94), Text = t("rup_" .. upgrade.id) .. "  " .. level .. "/" .. upgrade.max, FontFace = TITLE, TextColor3 = WHITE, Max = 22, ZIndex = 24, Parent = card })
			make("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = title })
			local function mult(l: number): string
				return if upgrade.id == "multi" or upgrade.id == "pets" then "+" .. l else "x" .. math.floor((1 + upgrade.per * l) * 100 + 0.5) / 100
			end
			local now, after = mult(level), mult(level + 1)
			local desc = text({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 0, 126), Text = if maxed then now else now .. "  →  " .. after, FontFace = TITLE, TextColor3 = WHITE, Max = 24, ZIndex = 24, Parent = card })
			make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = desc })
			btn(if maxed then GREY elseif tokens >= cost then Color3.fromRGB(150, 90, 255) else Color3.fromRGB(110, 100, 140), {
				Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -60), ZIndex = 24, Max = 22,
				Text = if maxed then t("upMax") else t("tokensCost", cost), Parent = card,
			}, function()
				if not maxed and tokens >= cost then
					ActionEv:FireServer("BuyRebirthUp", upgrade.id)
				end
			end)
		end
	end

	renderers[upgradesW] = function()
		local body = upgradesW.body
		clear(body)
		body.BackgroundColor3 = Color3.fromRGB(46, 40, 78)
		local tabs = make("Frame", { Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 0, BackgroundTransparency = 1, ZIndex = 21, Parent = body })
		for i, tab in { { id = "cash", key = "upTabCash", color = Color3.fromRGB(80, 210, 90) }, { id = "rebirth", key = "upTabRebirth", color = Color3.fromRGB(150, 90, 255) } } do
			local b = btn(if upgradesTab == tab.id then tab.color else Color3.fromRGB(100, 104, 130), {
				Size = UDim2.new(0.5, -5, 1, 0), Position = UDim2.new((i - 1) * 0.5, if i == 2 then 5 else 0, 0, 0), Text = t(tab.key), Max = 20, ZIndex = 22, Parent = tabs,
			}, function()
				upgradesTab = tab.id
				renderers[upgradesW]()
			end)
			if tab.id == "rebirth" and (state.rebirthTokens or 0) > 0 then
				badge(b).Visible = true
			end
		end
		if upgradesTab == "rebirth" then
			rebirthUpgrades(body)
		else
			cashUpgrades(body)
		end
	end
end

---------------------------------------------------------------- Star Index (+ roll rewards)
do
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
			local rewardStar = Stars.List[math.min(tier.last + 1, #Stars.List)]
			local r = row(body, order, 64 + 52, WHITE)
			text({ Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.new(0, 10, 0, 6), Text = Lang.mutation(lang, mutation) .. "   " .. found .. "/" .. count, FontFace = TITLE, TextColor3 = if mutation.id == "normal" then TEXT else shade(mutation.color, 0.25), TextXAlignment = Enum.TextXAlignment.Left, Max = 18, ZIndex = 22, Parent = r })
			text({ Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.new(0, 10, 0, 30), Text = t("rowReward", reward, Lang.item(lang, Items.key(rewardStar.id, mutation.id))), FontFace = BODY_SEMI, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Max = 13, ZIndex = 22, Parent = r })
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
end

---------------------------------------------------------------- Roll rewards (cards)
do
	local rewardsBody = rewardsW.body
	rewardsBody.Size = UDim2.new(0.72, 0, 1, -8)
	rewardsBody.Position = UDim2.new(0.28, 0, 0, 8)
	rewardsBody.ScrollingDirection = Enum.ScrollingDirection.X
	rewardsBody.AutomaticCanvasSize = Enum.AutomaticSize.X
	rewardsBody.ScrollBarThickness = 8
	local rewardsLayout = rewardsBody:FindFirstChildOfClass("UIListLayout")
	rewardsLayout.FillDirection = Enum.FillDirection.Horizontal
	rewardsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	rewardsLayout.Padding = UDim.new(0, 10)
	rewardsW.frame.BackgroundColor3 = Color3.fromRGB(44, 30, 74)
	rewardsBody.BackgroundColor3 = Color3.fromRGB(58, 40, 96)
	local NEON = Color3.fromRGB(90, 255, 120)
	local rewardsSummary = make("Frame", {
		Size = UDim2.new(0.26, 0, 1, -8), Position = UDim2.new(0, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(30, 70, 50), ZIndex = 21, Parent = rewardsW.frame,
	}, {
		corner(14), stroke(NEON, 4),
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(60, 130, 80), Color3.fromRGB(20, 60, 40)), Rotation = 90 }),
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
		local key = if milestone.cash then "coins_small" else "boost_luck"
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

		-- right: one card per milestone (sized from the screen, not from the animated window)
		local cardH = math.max(170, math.floor(gui.AbsoluteSize.Y * 0.6 - 48))
		local cardW = math.floor(cardH * 0.66)
for i, milestone in Config.RollMilestones do
			local claimed = state.milestones[tostring(i)] == true
			local ready = rolls >= milestone.rolls and not claimed
			local card = make("Frame", {
				Size = UDim2.new(0, cardW, 0, cardH), LayoutOrder = i, ZIndex = 21, Parent = rewardsBody, BackgroundColor3 = WHITE,
			}, {
				corner(14), stroke(if ready then NEON else INK, if ready then 4 else 3),
				make("UIGradient", {
					Color = if claimed then ColorSequence.new(Color3.fromRGB(70, 80, 90), Color3.fromRGB(40, 46, 56))
						else ColorSequence.new(Color3.fromRGB(50, 120, 70), Color3.fromRGB(18, 58, 36)),
					Rotation = 90,
				}),
			})
			stroked({ Size = UDim2.new(1, 0, 0.09, 0), Position = UDim2.new(0, 0, 0.03, 0), Text = t("rollsWord"), TextColor3 = NEON, Max = 20, Parent = card })
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
				Size = UDim2.new(0.84, 0, 0.38, 0), Position = UDim2.new(0.08, 0, 0.41, 0), BackgroundColor3 = Color3.fromRGB(14, 40, 26), BackgroundTransparency = 0.2, ZIndex = 22, Parent = card,
			}, { corner(12), stroke(INK, 2.5) })
			rewardIcon(milestone, { Size = UDim2.new(0.78, 0, 0.78, 0), Position = UDim2.new(0.11, 0, 0.06, 0), ZIndex = 23, Parent = box })
			stroked({ Size = UDim2.new(0.9, 0, 0.26, 0), Position = UDim2.new(0.05, 0, 0.72, 0), Text = rewardAmount(milestone), Max = 26, ZIndex = 24, Parent = box })
			btn(if ready then Color3.fromRGB(80, 220, 90) elseif claimed then Color3.fromRGB(90, 100, 120) else Color3.fromRGB(120, 120, 140), {
				Size = UDim2.new(0.86, 0, 0.13, 0), Position = UDim2.new(0.07, 0, 0.84, 0), ZIndex = 22, Max = 22,
				Text = if claimed then t("claimed") elseif ready then t("claim") else t("locked"), Parent = card,
			}, function()
				if ready then
					ActionEv:FireServer("ClaimMilestone", i)
				end
			end)
		end
	end
end

---------------------------------------------------------------- Constellation book
-- one floating tooltip for the constellation stars (hover on PC, tap on phones)
local setTip = text({ Size = UDim2.new(0, 220, 0, 40), Text = "", FontFace = TITLE, TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(20, 18, 44), BackgroundTransparency = 0.1, Visible = false, Max = 16, ZIndex = 300, Parent = gui })
corner(8).Parent = setTip
stroke(Color3.fromRGB(255, 220, 90), 2).Parent = setTip
local function showSetTip(slot: GuiObject, star)
	setTip.Text = Lang.star(lang, star) .. "  " .. t("oneIn", Format.number(star.chance))
	setTip.Position = UDim2.new(0, slot.AbsolutePosition.X + slot.AbsoluteSize.X / 2 - 110, 0, slot.AbsolutePosition.Y - 46)
	setTip.Visible = true
end
renderers[bookW] = function()
	setTip.Visible = false
	local body = bookW.body
	clear(body)
	body.BackgroundColor3 = Color3.fromRGB(26, 24, 60)
	local hint = text({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 0, Text = t("setsHint"), TextColor3 = Color3.fromRGB(200, 200, 240), FontFace = BODY_SEMI, TextWrapped = true, Max = 14, ZIndex = 21, Parent = body })
	hint.TextXAlignment = Enum.TextXAlignment.Left
	-- which stars stand in the museum right now
	local placed = {}
	for _, cell in (state and state.grid) or {} do
		local star = Items.parse(cell.id)
		if star then
			placed[star.id] = true
		end
	end
	local active = {}
	for _, id in (state and state.activeSets) or {} do
		active[id] = true
	end
	for order, set in Config.ConstellationSets do
		local on = active[set.id] == true
		local card = make("Frame", { Size = UDim2.new(1, -4, 0, 118), LayoutOrder = order, BackgroundColor3 = WHITE, ZIndex = 21, Parent = body }, {
			corner(14), stroke(if on then Color3.fromRGB(255, 220, 90) else INK, if on then 4 else 2.5),
			make("UIGradient", { Color = if on then ColorSequence.new(Color3.fromRGB(90, 70, 200), Color3.fromRGB(40, 30, 110)) else ColorSequence.new(Color3.fromRGB(60, 62, 96), Color3.fromRGB(34, 36, 60)), Rotation = 90 }),
		})
		local name = text({ Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.new(0, 12, 0, 6), Text = t("set_" .. set.id), FontFace = TITLE, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Max = 22, ZIndex = 22, Parent = card })
		make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = name })
		local bonus = text({ Size = UDim2.new(0.42, -26, 0, 30), Position = UDim2.new(0.58, 0, 0, 6), Text = (if on then t("setActive") .. "  " else "") .. t("setBonus", math.floor(set.bonus * 100 + 0.5)), FontFace = TITLE, TextColor3 = if on then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(180, 180, 210), TextXAlignment = Enum.TextXAlignment.Right, Max = 18, ZIndex = 22, Parent = card })
		make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = bonus })
		local strip = make("Frame", { Size = UDim2.new(1, -20, 0, 70), Position = UDim2.new(0, 10, 0, 40), BackgroundTransparency = 1, ZIndex = 22, Parent = card })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = strip })
		for k, id in set.stars do
			local star = Stars.ById[id]
			if star then
				local have = placed[id] == true
				local slot = make("TextButton", { Size = UDim2.new(0, 64, 0, 64), LayoutOrder = k, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(20, 18, 44), BackgroundTransparency = 0.2, ZIndex = 23, Parent = strip }, {
					make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(if have then Color3.fromRGB(120, 255, 150) else Color3.fromRGB(90, 90, 120), 2.5),
				})
				local icon = starIcon(star, nil, { Size = UDim2.new(0.84, 0, 0.84, 0), Position = UDim2.new(0.08, 0, 0.08, 0), ZIndex = 24, Parent = slot })
				slot.MouseEnter:Connect(function()
					showSetTip(slot, star)
				end)
				slot.MouseLeave:Connect(function()
					setTip.Visible = false
				end)
				slot.Activated:Connect(function()
					showSetTip(slot, star)
					task.delay(2, function()
						if setTip.Text == Lang.star(lang, star) .. "  " .. t("oneIn", Format.number(star.chance)) then
							setTip.Visible = false
						end
					end)
				end)
				if not have then
					for _, d in icon:GetDescendants() do
						if d:IsA("ImageLabel") then
							d.ImageTransparency = 0.6
						elseif d:IsA("Frame") then
							d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.6)
						end
					end
				else
					text({ Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -18, 1, -20), Text = "✓", FontFace = Font.fromEnum(Enum.Font.SourceSansBold), TextColor3 = Color3.fromRGB(120, 255, 150), TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 22, ZIndex = 26, Parent = slot })
				end
			end
		end
	end
end

---------------------------------------------------------------- Odds
renderers[oddsW] = function()
	local body = oddsW.body
	clear(body)
	local luck = if state then state.luck else 1
	local season = if state then state.season else nil
	local odds = Odds.exact(luck, season)
	for i = 1, #Stars.List do
		local star = Stars.List[i]
		local r = row(body, i, 40, WHITE)
		starIcon(star, nil, { Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 4, 0, 4), ZIndex = 22, Parent = r })
		text({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 44, 0, 0), Text = Lang.star(lang, star), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 22, Parent = r })
		text({ Size = UDim2.new(0.45, -10, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Text = t("oneIn", Format.number(if odds[star.id] > 0 then 1 / odds[star.id] else star.chance)), TextColor3 = MUTED, FontFace = BODY_SEMI, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 22, Parent = r })
	end
	-- seasonal stars (only this season)
	if season then
		local seasonName = t("season_" .. Stars.Seasons[season])
		text({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 90, Text = t("seasonLine", seasonName, Format.time(state.seasonLeft or 0)), TextColor3 = Color3.fromRGB(200, 90, 255), FontFace = TITLE, Max = 16, ZIndex = 21, Parent = body })
		local order = 90
		for _, star in Stars.Seasonal do
			if star.season == season then
				order += 1
				local r = row(body, order, 40, Color3.fromRGB(250, 240, 255))
				starIcon(star, nil, { Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 4, 0, 4), ZIndex = 22, Parent = r })
				text({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 44, 0, 0), Text = Lang.star(lang, star) .. "  [" .. t("seasonTag") .. "]", FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 22, Parent = r })
				local chance = odds[star.id] or 0
				text({ Size = UDim2.new(0.45, -10, 1, 0), Position = UDim2.new(0.55, 0, 0, 0), Text = t("oneIn", Format.number(if chance > 0 then 1 / chance else star.chance)), TextColor3 = MUTED, FontFace = BODY_SEMI, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 22, Parent = r })
			end
		end
	end
	text({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 100, Text = t("mutations"), TextColor3 = BLUE, FontFace = TITLE, Max = 16, ZIndex = 21, Parent = body })
	text({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 101, Text = t("mutationsInfo"), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 14, ZIndex = 21, Parent = body })
	for i, mutation in Mutations.List do
		if mutation.copies then
			local r = row(body, 101 + i, 40, WHITE)
			text({ Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0), Text = Lang.mutation(lang, mutation), FontFace = TITLE, TextColor3 = shade(mutation.color, 0.25), TextXAlignment = Enum.TextXAlignment.Left, Max = 16, ZIndex = 22, Parent = r })
			text({ Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.new(0.4, 0, 0, 0), Text = t("upgradeTo", Lang.mutation(lang, mutation), mutation.chance, mutation.mult), TextColor3 = MUTED, FontFace = BODY_SEMI, TextXAlignment = Enum.TextXAlignment.Right, Max = 14, ZIndex = 22, Parent = r })
		end
	end
end

---------------------------------------------------------------- Forge (only at the forge table)
do
	local forgeTab = "forge"
	local fuseA: string? = nil
	local fuseB: string? = nil

	local function forgeList(body)
		text({ Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, Text = t("forgeHint", Config.ForgeAmount), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 15, ZIndex = 21, Parent = body })
		for order, key in sortedInventory() do
			local star, mutation = Items.parse(key)
			local special = star.hybrid or star.season -- fusion / seasonal stars sit outside the forge chain
			local nextStar = if special then nil else Stars.List[star.index + 1]
			local have = state.inventory[key]
			local sub = if nextStar
				then "→ " .. Lang.item(lang, Items.key(nextStar.id, mutation.id)) .. "   " .. t("forgeHave", math.min(have, Config.ForgeAmount), Config.ForgeAmount)
				elseif star.hybrid then t("forgeHybrid")
				elseif star.season then t("forgeSeasonal")
				else t("forgeMax")
			local r = itemRow(body, order + 1, key, sub)
			if nextStar then
				local ready = have >= Config.ForgeAmount
				btn(if ready then GOLD else GREY, { Size = UDim2.new(0, 110, 0, 40), Position = UDim2.new(1, -290, 0, 9), ZIndex = 23, Max = 13,
					Text = t("forgeBtn", Format.number(Config.ForgeCost(star, nextStar))), Parent = r }, function()
					ActionEv:FireServer("Forge", key)
				end)
			end
			local nextMutation = Mutations.List[mutation.index + 1]
			if nextMutation and not star.season and not star.hybrid then
				local upgraded = Items.key(star.id, nextMutation.id)
				local ready = have >= nextMutation.copies
				btn(if ready then shade(nextMutation.color, 0.15) else GREY, { Size = UDim2.new(0, 110, 0, 40), Position = UDim2.new(1, -174, 0, 9), ZIndex = 23, Max = 13,
					Text = t("upgradeBtn", Format.number(Config.UpgradeCost(star, nextStar, nextMutation))), Parent = r }, function()
					ActionEv:FireServer("UpgradeMutation", key)
				end)
			end
		end
	end

	-- FUSION: two different stars -> a hybrid (recipes are secret until someone finds them)
	local function fuseText(parent: Instance, value: string, props)
		props.Text = value
		props.FontFace = TITLE
		props.TextColor3 = props.TextColor3 or WHITE
		props.Parent = parent
		local label = text(props)
		make("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
		return label
	end

	local function fusionPage(body)
		local hint = text({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Text = t("fuseHint"), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 15, ZIndex = 21, Parent = body })
		hint.TextXAlignment = Enum.TextXAlignment.Left
		local bench = make("Frame", { Size = UDim2.new(1, 0, 0, 110), LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(60, 40, 110), ZIndex = 21, Parent = body }, { corner(14), stroke(INK, 3) })
		local function slot(x: number, key: string?, which: string)
			local b = make("TextButton", { Size = UDim2.new(0, 86, 0, 86), Position = UDim2.new(0, x, 0, 12), Text = if key then "" else "?", FontFace = TITLE, TextSize = 40, TextColor3 = Color3.fromRGB(170, 150, 230), BackgroundColor3 = Color3.fromRGB(36, 24, 70), ZIndex = 22, Parent = bench }, {
				make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(if key then GOLD else Color3.fromRGB(110, 90, 170), 3),
			})
			local star, mutation = Items.parse(key)
			if star then
				starIcon(star, mutation, { Size = UDim2.new(0.86, 0, 0.86, 0), Position = UDim2.new(0.07, 0, 0.07, 0), ZIndex = 23, Parent = b })
			end
			b.Activated:Connect(function() -- tap a filled slot to empty it
				if which == "a" then
					fuseA = nil
				else
					fuseB = nil
				end
				renderers[forgeW]()
			end)
		end
		slot(14, fuseA, "a")
		fuseText(bench, "+", { Size = UDim2.new(0, 40, 0, 86), Position = UDim2.new(0, 104, 0, 12), Max = 44, ZIndex = 22 })
		slot(148, fuseB, "b")
		local a, b = Items.parse(fuseA), Items.parse(fuseB)
		local known = a and b and Stars.fusion(a.id, b.id)
		local found = known and state.fusions and state.fusions[known.id]
		fuseText(bench, "=", { Size = UDim2.new(0, 40, 0, 86), Position = UDim2.new(0, 238, 0, 12), Max = 44, ZIndex = 22 })
		local result = make("Frame", { Size = UDim2.new(0, 86, 0, 86), Position = UDim2.new(0, 282, 0, 12), BackgroundColor3 = Color3.fromRGB(36, 24, 70), ZIndex = 22, Parent = bench }, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Color3.fromRGB(200, 120, 255), 3),
		})
		if found then
			starIcon(known, nil, { Size = UDim2.new(0.86, 0, 0.86, 0), Position = UDim2.new(0.07, 0, 0.07, 0), ZIndex = 23, Parent = result })
		else
			fuseText(result, "?", { Size = UDim2.new(1, 0, 1, 0), Max = 44, ZIndex = 23 })
		end
		btn(if a and b then Color3.fromRGB(170, 90, 255) else GREY, { Size = UDim2.new(1, -400, 0, 60), Position = UDim2.new(0, 386, 0, 25), ZIndex = 22, Max = 20,
			Text = if found then t("fuseBtnCost", Format.number(Config.FusionCost(known))) else t("fuseBtn"), Parent = bench }, function()
			if fuseA and fuseB then
				ActionEv:FireServer("Fuse", fuseA, fuseB)
			end
		end)
		-- recipes already found (by you)
		local foundList = {}
		for _, hybrid in Stars.Hybrids do
			if state.fusions and state.fusions[hybrid.id] then
				table.insert(foundList, Lang.star(lang, Stars.ById[hybrid.recipe[1]]) .. " + " .. Lang.star(lang, Stars.ById[hybrid.recipe[2]]) .. " = " .. Lang.star(lang, hybrid))
			end
		end
		text({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 3, Text = t("fuseFound", #foundList, #Stars.Hybrids), FontFace = TITLE, TextColor3 = Color3.fromRGB(170, 90, 255), Max = 17, ZIndex = 21, Parent = body })
		for i, line in foundList do
			text({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 3 + i, Text = line, FontFace = BODY_SEMI, TextColor3 = TEXT, Max = 14, ZIndex = 21, Parent = body })
		end
		-- your stars: tap to put into the first empty slot
		for order, key in sortedInventory() do
			itemRow(body, 100 + order, key, t("fusePick")).Activated:Connect(function()
				if not fuseA then
					fuseA = key
				elseif not fuseB and key ~= fuseA then
					fuseB = key
				else
					fuseB = key
				end
				renderers[forgeW]()
			end)
		end
	end

	renderers[forgeW] = function()
		local body = forgeW.body
		clear(body)
		if fuseA and not ((state.inventory[fuseA] or 0) > 0) then
			fuseA = nil
		end
		if fuseB and not ((state.inventory[fuseB] or 0) > 0) then
			fuseB = nil
		end
		local tabs = make("Frame", { Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 0, BackgroundTransparency = 1, ZIndex = 21, Parent = body })
		for i, tab in { { id = "forge", key = "forgeTab", color = GOLD }, { id = "fusion", key = "fusionTab", color = Color3.fromRGB(170, 90, 255) } } do
			local b = btn(if forgeTab == tab.id then tab.color else Color3.fromRGB(110, 118, 150), { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new((i - 1) * 0.5, if i == 2 then 4 else 0, 0, 0), Text = t(tab.key), Max = 20, ZIndex = 22, Parent = tabs }, function()
				forgeTab = tab.id
				renderers[forgeW]()
			end)
			uiIcon(if tab.id == "fusion" then "fusion" else "forge", { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 6, 0.5, -20), ZIndex = 24, Parent = b })
		end
		if forgeTab == "fusion" then
			fusionPage(body)
		else
			forgeList(body)
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
		t("holeNow", 1 + state.rebirths * Config.RebirthIncomeBonus, Config.RebirthLuck(state.rebirths)),
		t("holeNext", 1 + (state.rebirths + 1) * Config.RebirthIncomeBonus, Config.RebirthLuck(state.rebirths + 1)),
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
local applyDayNight, applyMusic, playSfx, celebrateRebirth
do
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

	-- Day / night is a personal setting: only this player's lighting changes
	local Lighting = game:GetService("Lighting")
	local dayLook = nil
	applyDayNight = function()
		local night = state and state.settings and state.settings.night == true
		local sky = Lighting:FindFirstChildOfClass("Sky")
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if not dayLook then
			dayLook = {
				clock = Lighting.ClockTime, brightness = Lighting.Brightness, ambient = Lighting.Ambient, outdoor = Lighting.OutdoorAmbient,
				stars = sky and sky.StarCount, density = atmosphere and atmosphere.Density, atmoColor = atmosphere and atmosphere.Color,
				decay = atmosphere and atmosphere.Decay, haze = atmosphere and atmosphere.Haze, cloudColor = clouds and clouds.Color,
			}
		end
		if night then
			Lighting.ClockTime = 0
			Lighting.Brightness = 1.4
			Lighting.Ambient = Color3.fromRGB(70, 70, 110)
			Lighting.OutdoorAmbient = Color3.fromRGB(70, 75, 115)
			if sky then
				sky.StarCount = 6000
				sky.MoonAngularSize = 16
				sky.CelestialBodiesShown = true
			end
			if atmosphere then
				atmosphere.Density = 0.25
				atmosphere.Color = Color3.fromRGB(40, 45, 85)
				atmosphere.Decay = Color3.fromRGB(20, 20, 50)
				atmosphere.Haze = 0.6
			end
			if clouds then
				clouds.Color = Color3.fromRGB(90, 95, 130)
			end
		else
			Lighting.ClockTime = dayLook.clock
			Lighting.Brightness = dayLook.brightness
			Lighting.Ambient = dayLook.ambient
			Lighting.OutdoorAmbient = dayLook.outdoor
			if sky and dayLook.stars then
				sky.StarCount = dayLook.stars
			end
			if atmosphere and dayLook.density then
				atmosphere.Density = dayLook.density
				atmosphere.Color = dayLook.atmoColor
				atmosphere.Decay = dayLook.decay
				atmosphere.Haze = dayLook.haze
			end
			if clouds and dayLook.cloudColor then
				clouds.Color = dayLook.cloudColor
			end
		end
	end

	local function settingOn(name: string): boolean
		return not state or not state.settings or state.settings[name] ~= false
	end

	applyMusic = function()
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

	playSfx = function(id: string?, volume: number)
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
		-- language
		local langRow = row(body, 0, 60, WHITE)
		text({ Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0), Text = t("language"), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 22, ZIndex = 22, Parent = langRow })
		for i, code in { "en", "ru" } do
			btn(if lang == code then BLUE else GREY, {
				Size = UDim2.new(0.27, 0, 0, 42), Position = UDim2.new(0.4 + (i - 1) * 0.29, 0, 0, 9), Text = if code == "en" then "English" else "Русский", Max = 18, ZIndex = 22, Parent = langRow,
			}, function()
				ActionEv:FireServer("SetLang", code)
				setLang(code)
				renderers[settingsW]()
			end)
		end
		for order, name in { "music", "sfx", "rollAnim" } do
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
		local skyRow = row(body, 4, 60, WHITE)
		text({ Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0), Text = t("skyMode"), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 22, ZIndex = 22, Parent = skyRow })
		local isNight = state and state.settings and state.settings.night == true
		for i, mode in { "day", "night" } do
			local selected = (mode == "night") == isNight
			btn(if selected then (if mode == "night" then Color3.fromRGB(60, 60, 130) else GOLD) else GREY, {
				Size = UDim2.new(0.27, 0, 0, 42), Position = UDim2.new(0.4 + (i - 1) * 0.29, 0, 0, 9), Text = t(mode), Max = 18, ZIndex = 22, Parent = skyRow,
			}, function()
				if state then
					state.settings = state.settings or {}
					state.settings.night = mode == "night"
					ActionEv:FireServer("SetSetting", "night", mode == "night")
					applyDayNight()
					renderers[settingsW]()
				end
			end)
		end

		-- from which odds the big reveal / announcements show up
		local alertRow = row(body, 5, 160, WHITE)
		text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 14, 0, 6), Text = t("rareAlert"), FontFace = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Max = 20, ZIndex = 22, Parent = alertRow })
		local options = make("Frame", { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 0, 46), BackgroundTransparency = 1, ZIndex = 22, Parent = alertRow })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = options })
		local current = (state and state.settings and state.settings.rareAlert) or 10000
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
		for _, value in { 10000, 1000000, 50000000, 1000000000, 0 } do
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

	settingsButton = iconButton("settings", "settings", Color3.fromRGB(120, 130, 160), { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 16, 0, 64), Max = 10, Parent = gui }, function()
		open(settingsW)
	end)

	-- Rebirth celebration: sound, white flash, big title, camera punch
	celebrateRebirth = function()
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
end

---------------------------------------------------------------- Admin panel (only shown when the server says you are admin)
local adminButton
do
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

	adminButton = iconButton("admin", "admin", Color3.fromRGB(230, 90, 90), { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 68, 0, 64), Max = 9, Visible = false, Parent = gui }, function()
		open(adminW)
	end)
end

---------------------------------------------------------------- Server-wide cinematic for 1-in-a-billion finds
local rareThreshold, bigReveal, wantsReveal
do
	rareThreshold = function(): number
		local value = state and state.settings and state.settings.rareAlert
		if value == 0 then
			return math.huge -- off
		end
		return value or 10000
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
	bigReveal = function(key: string, chance: number, finder: string?, ultra: boolean?)
		local star, mutation = Items.parse(key)
		if not star then
			return
		end
		local glow = if mutation.id ~= "normal" then mutation.color else star.color
		local root = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(6, 4, 20), BackgroundTransparency = 1, ZIndex = 200, Parent = gui })
		local introTime = 1
		local meteor: Frame? = nil

		if ultra then
			-- ULTRA: pitch black for 5 s with a faint heartbeat of light, a strobe, then the star rushes at the screen
			root.BackgroundColor3 = Color3.new(0, 0, 0)
			root.BackgroundTransparency = 0
			introTime = 5 + 12 * 0.08 + 0.7
			task.spawn(function()
				local core = circle(4, WHITE, 205, root)
				core.Position = UDim2.new(0.5, 0, 0.42, 0)
				for beat = 1, 5 do
					TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 8 + beat * 7, 0, 8 + beat * 7), BackgroundTransparency = 0.1 }):Play()
					task.wait(0.5)
					TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 4, 0, 4), BackgroundTransparency = 0.7 }):Play()
					task.wait(0.5)
				end
				core:Destroy()
				local strobe = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 225, Parent = root })
				for flick = 1, 12 do
					strobe.BackgroundColor3 = if flick % 3 == 0 then glow else WHITE
					strobe.BackgroundTransparency = if flick % 2 == 0 then 1 else 0.05
					task.wait(0.08)
				end
				strobe:Destroy()
				local giant = make("Frame", { Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), BackgroundTransparency = 1, ZIndex = 226, Parent = root })
				starIcon(star, mutation, { Size = UDim2.new(1, 0, 1, 0), ZIndex = 227, Parent = giant })
				TweenService:Create(giant, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(0, 3200, 0, 3200), Rotation = 90 }):Play()
				task.wait(0.7)
				giant:Destroy()
			end)
		else
			TweenService:Create(root, TweenInfo.new(0.6), { BackgroundTransparency = 0.2 }):Play()
			-- 1) the falling star with a fiery trail
			local falling = make("Frame", { Size = UDim2.new(0, 80, 0, 80), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1.1, 0, -0.15, 0), BackgroundTransparency = 1, ZIndex = 205, Parent = root })
			meteor = falling
			starIcon(star, mutation, { Size = UDim2.new(1, 0, 1, 0), ZIndex = 206, Parent = falling })
			TweenService:Create(falling, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.42, 0), Rotation = 540 }):Play()
			task.spawn(function()
				local stop = os.clock() + 1
				while os.clock() < stop do
					local dot = circle(math.random(14, 34), if math.random() < 0.5 then glow else Color3.fromRGB(255, 200, 120), 204, root)
					dot.Position = falling.Position
					TweenService:Create(dot, TweenInfo.new(0.6), { Size = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1 }):Play()
					task.delay(0.65, function()
						dot:Destroy()
					end)
					task.wait(0.025)
				end
			end)
		end

		task.delay(introTime, function()
			if meteor then
				meteor:Destroy()
			end
			if ultra then
				root.BackgroundColor3 = Color3.fromRGB(6, 4, 20)
				TweenService:Create(root, TweenInfo.new(0.8), { BackgroundTransparency = 0.2 }):Play()
			end
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

	wantsReveal = function(chance: number): boolean
		local threshold = rareThreshold()
		if threshold == math.huge then
			return false -- reveals switched off
		end
		return chance >= threshold -- only what the player picked in the settings
	end

	GlobalRareEv.OnClientEvent:Connect(function(finder: string, key: string, chance: number)
		if wantsReveal(chance) then
			bigReveal(key, chance, finder, chance >= Config.UltraRevealChance)
		end
	end)
end

---------------------------------------------------------------- Sprint: Shift on PC, a button on phones
do
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
end

---------------------------------------------------------------- Leaderboard tablets (scrollable top 100 drawn on the stone)
do
	local BOARD_TITLES = { rolls = "lbRolls", rebirths = "lbRebirths", cash = "lbCash", rarest = "lbRarest", likes = "lbLikes" }
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
end

---------------------------------------------------------------- Build mode: buy slabs and put them on your plot
local buildMode, myPlotFolder, refreshMarkers, renderBuildPanel, nearMyPlot
local setBuildMode
do
	buildMode = false
	local buildTool: string? = Config.Slabs[1].id -- slab id, "remove", or nil (nothing selected)
	local pendingRemove: string? = nil -- slab waiting for the ✓ confirmation
	local pendingPlace: string? = nil -- phones: spot waiting for the ✓ confirmation
	local hoverKey: string? = nil -- PC: spot under the mouse
	-- defined below (the panel's EXIT button needs it)
	local buildPanel = panelFrame({ Size = UDim2.new(0, 380, 0, 440), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.55, 0), Visible = false, ZIndex = 30, Parent = gui })
	buildPanel.BackgroundColor3 = Color3.fromRGB(70, 78, 108)
	buildPanel.BackgroundTransparency = 0
	local buildBottom = make("Frame", { Size = UDim2.new(0, 360, 0, 190), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui })
	local buildTab = "stands"

	myPlotFolder = function(): Instance?
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

	refreshMarkers = function()
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

	local function inkText(parent: Instance, value: string, props)
		props.Text = value
		props.FontFace = TITLE
		props.TextColor3 = props.TextColor3 or WHITE
		props.ZIndex = props.ZIndex or 33
		props.Parent = parent
		local thick = props.Thick or 2.5
		props.Thick = nil
		local label = text(props)
		make("UIStroke", { Color = INK, Thickness = thick, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
		return label
	end

	renderBuildPanel = function()
		clear(buildPanel)
		clear(buildBottom)
		-- title above the board, hammer icon, red X on the corner
		local titleRow = make("Frame", { Size = UDim2.new(1, -60, 0, 64), Position = UDim2.new(0, -6, 0, -78), BackgroundTransparency = 1, ZIndex = 33, Parent = buildPanel })
		local hammer = uiIcon("build", { Size = UDim2.new(0, 64, 0, 64), ZIndex = 34, Parent = titleRow })
		inkText(titleRow, t("buildTitle"), { Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, if hammer then 66 else 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 42, Thick = 3.5 })
		btn(RED, { Size = UDim2.new(0, 58, 0, 58), Position = UDim2.new(1, -36, 0, -54), Text = "X", Max = 34, ZIndex = 35, Parent = buildPanel }, function()
			setBuildMode(false)
		end)
		-- tabs
		for i, tab in { { id = "stands", key = "buildTitle", color = Color3.fromRGB(70, 200, 90) }, { id = "themes", key = "theme", color = Color3.fromRGB(80, 120, 255) } } do
			local b = btn(if buildTab == tab.id then tab.color else Color3.fromRGB(110, 118, 150), {
				Size = UDim2.new(0.48, 0, 0, 48), Position = UDim2.new((i - 1) * 0.52, 0, 0, 0), Text = t("theme"), Max = 22, ZIndex = 33, Parent = buildPanel,
			}, function()
				buildTab = tab.id
				renderBuildPanel()
			end)
			if tab.id == "stands" then
				b.Text = if lang == "ru" then "ПОСТАМЕНТЫ" else "STANDS"
			end
		end
		-- tiles
		local inner = make("Frame", { Size = UDim2.new(1, 0, 1, -60), Position = UDim2.new(0, 0, 0, 58), BackgroundColor3 = Color3.fromRGB(96, 106, 140), ZIndex = 31, Parent = buildPanel }, { corner(10), stroke(INK, 2), pad(8) })
		make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 118), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })
		local function tile(order: number, top: Color3, bottom: Color3, selected: boolean, onClick)
			local b = make("TextButton", { LayoutOrder = order, Text = "", AutoButtonColor = true, BackgroundColor3 = WHITE, ZIndex = 32, Parent = inner }, {
				corner(8), stroke(if selected then Color3.fromRGB(80, 220, 255) else INK, if selected then 4 else 2.5),
				make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }),
			})
			b.Activated:Connect(onClick)
			return b
		end
		if buildTab == "stands" then
			for i, slab in Config.Slabs do
				local selected = buildTool == slab.id
				local b = tile(i, Color3.fromRGB(70, 90, 120), Color3.fromRGB(30, 40, 60), selected, function()
					buildTool = if buildTool == slab.id then nil else slab.id -- tap again to deselect
					pendingRemove = nil
					pendingPlace = nil
					renderBuildPanel()
					refreshMarkers()
				end)
				-- little drawing of the stand
				make("Frame", { Size = UDim2.new(0, 64, 0, 12), Position = UDim2.new(0.5, -32, 0, 58), BackgroundColor3 = slab.color:Lerp(Color3.new(0, 0, 0), 0.35), ZIndex = 33, Parent = b }, { corner(3), stroke(INK, 2) })
				make("Frame", { Size = UDim2.new(0, 46, 0, 26), Position = UDim2.new(0.5, -23, 0, 34), BackgroundColor3 = slab.color, ZIndex = 33, Parent = b }, { corner(3), stroke(INK, 2) })
				make("Frame", { Size = UDim2.new(0, 58, 0, 10), Position = UDim2.new(0.5, -29, 0, 26), BackgroundColor3 = slab.color:Lerp(Color3.new(1, 1, 1), 0.3), ZIndex = 34, Parent = b }, { corner(3), stroke(INK, 2) })
				inkText(b, "x" .. slab.mult, { Size = UDim2.new(0, 50, 0, 26), Position = UDim2.new(1, -52, 0, 2), TextXAlignment = Enum.TextXAlignment.Right, Max = 22, ZIndex = 35 })
				inkText(b, Format.number(slab.cost), { Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.new(0, 4, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 90), Max = 15, ZIndex = 35 })
				inkText(b, t("slab_" .. slab.id), { Size = UDim2.new(1, -6, 0, 26), Position = UDim2.new(0, 3, 1, -30), Max = 16, ZIndex = 35 })
			end
		else
			for i, theme in Config.Themes do
				local current = state and state.theme == theme.id
				local b = tile(i, theme.wall, theme.wall:Lerp(Color3.new(0, 0, 0), 0.45), current, function()
					ActionEv:FireServer("SetTheme", theme.id)
				end)
				make("Frame", { Size = UDim2.new(0, 70, 0, 50), Position = UDim2.new(0.5, -35, 0, 20), BackgroundColor3 = theme.wall, BackgroundTransparency = 0.3, ZIndex = 33, Parent = b }, { corner(4), stroke(theme.trim, 4) })
				make("Frame", { Size = UDim2.new(0, 70, 0, 8), Position = UDim2.new(0.5, -35, 0, 70), BackgroundColor3 = theme.floor, ZIndex = 33, Parent = b }, { corner(2), stroke(INK, 1.5) })
				inkText(b, t("theme_" .. theme.id), { Size = UDim2.new(1, -6, 0, 26), Position = UDim2.new(0, 3, 1, -30), Max = 16, ZIndex = 35 })
			end
		end

		-- bottom centre: how many stands are built, Exit and Delete
		local spots = Config.SpotsPerFloor * ((state and state.floors) or 1)
		local built = 0
		for _ in (state and state.slabs) or {} do
			built += 1
		end
		inkText(buildBottom, built .. " / " .. spots, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 0), Max = 56, Thick = 4 })
		local function iconAction(x: number, iconKey: string, label: string, active: boolean, onClick)
			local b = make("TextButton", { Size = UDim2.new(0, 110, 0, 110), Position = UDim2.new(0.5, x, 0, 66), BackgroundTransparency = 1, Text = "", ZIndex = 33, Parent = buildBottom })
			local icon = uiIcon(iconKey, { Size = UDim2.new(0, 88, 0, 88), Position = UDim2.new(0.5, -44, 0, 0), ZIndex = 34, Parent = b })
			if not icon then
				make("Frame", { Size = UDim2.new(0, 70, 0, 70), Position = UDim2.new(0.5, -35, 0, 6), BackgroundColor3 = if active then RED else Color3.fromRGB(110, 118, 150), ZIndex = 34, Parent = b }, { corner(14), stroke(INK, 3) })
			end
			inkText(b, label, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -36), TextColor3 = if active then Color3.fromRGB(255, 110, 110) else WHITE, Max = 30, Thick = 3, ZIndex = 35 })
			local scale = make("UIScale", { Parent = b })
			b.MouseEnter:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
			end)
			b.MouseLeave:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
			end)
			b.Activated:Connect(onClick)
		end
		iconAction(-120, "build", t("exitBuild"), false, function()
			setBuildMode(false)
		end)
		iconAction(10, "trash", t("removeTool"), buildTool == "remove", function()
			buildTool = if buildTool == "remove" then nil else "remove"
			pendingRemove = nil
			pendingPlace = nil
			renderBuildPanel()
			refreshMarkers()
		end)

		-- removing (and placing on phones) needs a confirmation
		local pending = pendingRemove or pendingPlace
		if pending then
			local removing = pendingRemove ~= nil
			local bar = panelFrame({ Size = UDim2.new(0, 400, 0, 58), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), ZIndex = 32, Parent = buildBottom })
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

	nearMyPlot = function(): boolean
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
		buildBottom.Visible = on
		telescope.Visible = not on -- the roll panel makes room for the build controls
		if on then
			tutorialCard.Visible = false
		end
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
end

---------------------------------------------------------------- Icon buttons: bottom row + right column
local rewardsBadge, indexBadge
do
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
				elseif entry[2] == "home" then
					ActionEv:FireServer("GoHome")
				else
					open(entry[2])
				end
			end)
			dockButtons[entry[1]] = b
		end
	end

	-- left side: roll rewards + index
	local leftColumn = buttonGroup(4, false, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.45, 0), Parent = gui })
	addButtons(leftColumn, {
		{ "rewards", rewardsW, RED, "rewards" },
		{ "index", indexW, LILAC, "index" },
		{ "constellations", bookW, Color3.fromRGB(110, 100, 255), "constellations" },
		{ "home", "home", Color3.fromRGB(90, 190, 255), "museum" },
	})
	-- right side: everything else (codes live at the bottom of the shop now)
	local rightColumn = buttonGroup(4, false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Parent = gui })
	addButtons(rightColumn, {
		{ "shop", shopW, Color3.fromRGB(70, 200, 90), "shop" },
		{ "build", "build", Color3.fromRGB(240, 150, 60), "build" },
		{ "odds", oddsW, GOLD, "odds" },
		{ "trade", playersW, Color3.fromRGB(255, 140, 60), "trade" },
	})
	rewardsBadge = badge(dockButtons.rewards)
	indexBadge = badge(dockButtons.index)
end

---------------------------------------------------------------- Render
local function canAutoRoll(): boolean
	return state ~= nil and state.totalRolls >= Config.AutoRollUnlock
end

local function renderTelescope()
	local multi = if state then Config.RollsPerClick(state, state.passes) else 1
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

-- windows are redrawn only when the data they show changed (not for every cash tick), and never while a
-- finger / mouse button is held down: rebuilding a button between press and release swallowed the click
local windowSig: { [any]: string } = {}
local pointerDown = false
local pendingRender = false
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pointerDown = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pointerDown = false
		if pendingRender then
			pendingRender = false
			task.delay(0.05, function()
				if render then
					render()
				end
			end)
		end
	end
end)
local function stateSignature(): string
	if not state then
		return ""
	end
	local copy = table.clone(state)
	copy.cash = nil -- changes every second, no window draws it
	copy.seasonLeft = nil
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, copy)
	return if ok then encoded else tostring(os.clock())
end

render = function(force: boolean?)
	if not state then
		return
	end
	incomeValue.Text = "+" .. Format.number(state.income)
	luckValue.Text = "x" .. (math.floor(state.luck * 100 + 0.5) / 100)
	rollsValue.Text = Format.number(state.totalRolls)
	rebirthValue.Text = tostring(state.rebirths)
	adminButton.Visible = state.isAdmin == true
	local progress = state.luckyProgress or 0
	luckyFill.Size = UDim2.new(progress / Config.LuckyRoll.every, 0, 1, 0)
	luckyText.Text = t("luckyBar", Config.LuckyRoll.mult, Config.LuckyRoll.every - progress)
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

	if pointerDown and not force then
		pendingRender = true -- redraw the windows once the click is finished
		return
	end
	local sig = stateSignature()
	for _, w in windows do
		if w.frame.Visible and renderers[w] and (force or windowSig[w] ~= sig) then
			windowSig[w] = sig
			local scroll = w.body.CanvasPosition
			local ok, err = pcall(renderers[w])
			if not ok then
				warn("[UI] window failed to render: " .. tostring(err))
			end
			task.spawn(function()
				RunService.RenderStepped:Wait() -- after the list has been laid out again
				w.body.CanvasPosition = scroll
			end)
		end
	end
end

---------------------------------------------------------------- Roll
-- Big centered reveal for rare finds
showRare = function(key: string)
	local chance = Items.chance(key)
	bigReveal(key, chance, nil, chance >= Config.UltraRevealChance)
end

-- roll reel: a strip at the top centre, stars fly right → left and stop on what you got
local reelHolder = make("Frame", { Size = UDim2.new(0, 560, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 165), BackgroundTransparency = 1, ZIndex = 60, Parent = gui }, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
})
local reelToken = 0
local function playReel(results, duration: number)
	reelToken += 1
	local token = reelToken
	clear(reelHolder)
	local count = math.min(#results, 6)
	local cell = if count <= 2 then 92 elseif count <= 4 then 72 else 58
	local WIDTH, SLOTS, FINAL = 560, 26, 22
	for r = 1, count do
		local key = results[r]
		local star, mutation = Items.parse(key)
		if not star then
			continue
		end
		local rowFrame = make("CanvasGroup", {
			Size = UDim2.new(0, WIDTH, 0, cell + 26), LayoutOrder = r, BackgroundColor3 = Color3.fromRGB(24, 20, 48), BackgroundTransparency = 0.3, ZIndex = 60, Parent = reelHolder,
		}, {
			corner(12),
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.14, 0), NumberSequenceKeypoint.new(0.86, 0), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		local strip = make("Frame", { Size = UDim2.new(0, SLOTS * cell, 0, cell), Position = UDim2.new(0, WIDTH, 0, 0), BackgroundTransparency = 1, ZIndex = 61, Parent = rowFrame })
		local finalIcon = nil
		for i = 1, SLOTS do
			local s, m = star, mutation
			if i ~= FINAL then
				-- mostly common stars, now and then a rare one to tease
				local top = if math.random() < 0.15 then math.min(#Stars.List, 40) else math.min(#Stars.List, 12)
				s, m = Stars.List[math.random(1, top)], nil
			end
			local icon = starIcon(s, m, { Size = UDim2.new(0, cell - 10, 0, cell - 10), Position = UDim2.new(0, (i - 1) * cell + 5, 0, 5), ZIndex = 62, Parent = strip })
			if i == FINAL then
				finalIcon = icon
			end
		end
		-- the window in the middle
		make("Frame", { Size = UDim2.new(0, cell, 0, cell), Position = UDim2.new(0.5, -cell / 2, 0, 0), BackgroundTransparency = 1, ZIndex = 64, Parent = rowFrame }, { corner(12), stroke(GOLD, 3) })
		local endX = WIDTH / 2 - (FINAL - 0.5) * cell
		task.delay((r - 1) * 0.06, function()
			TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, endX, 0, 0) }):Play()
		end)
		task.delay(duration + (r - 1) * 0.06, function()
			if token ~= reelToken or not rowFrame.Parent then
				return
			end
			if finalIcon then
				local pop = make("UIScale", { Scale = 1.35, Parent = finalIcon })
				TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			-- name and odds under the star
			local name = text({
				Size = UDim2.new(0, WIDTH - 40, 0, 24), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, cell + 1),
				Text = Lang.item(lang, key) .. "   " .. t("oneIn", Format.number(Items.chance(key))), FontFace = TITLE,
				TextColor3 = if mutation and mutation.id ~= "normal" then mutation.color else star.color:Lerp(WHITE, 0.35), Max = 20, ZIndex = 65, Parent = rowFrame,
			})
			make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = name })
		end)
	end
	task.delay(duration + 1.6, function()
		if token ~= reelToken then
			return
		end
		for _, rowFrame in reelHolder:GetChildren() do
			if rowFrame:IsA("CanvasGroup") then
				TweenService:Create(rowFrame, TweenInfo.new(0.35), { GroupTransparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		if token == reelToken then
			clear(reelHolder)
		end
	end)
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
	while (os.clock() - started < 0.15 or not done) and os.clock() - started < 5 do
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
		local reelOn = not (state and state.settings and state.settings.rollAnim == false)
		local cooldownNow = if state then Config.EffectiveCooldown(state, workspace:GetServerTimeNow(), state.passes) else 1
		local reelTime = math.clamp(cooldownNow * 0.9, 0.35, 1.1)
		if reelOn then
			playReel(result, reelTime)
		end
		if wantsReveal(Items.chance(best)) and Items.chance(best) < Config.GlobalRareChance then
			-- rare finds always get their cinematic, even with the reel turned off
			task.delay(if reelOn then reelTime + 0.2 else 0, showRare, best)
		end
	end
	renderTelescope()
	local cooldown = if state then Config.EffectiveCooldown(state, workspace:GetServerTimeNow(), state.passes) else 1
	task.wait(math.max(0, cooldown - (os.clock() - started)))
	rolling = false
end

-- the old panel becomes an invisible holder for the big bottom buttons
telescope.Size = UDim2.new(0, 520, 0, 210)
telescope.BackgroundTransparency = 1
for _, child in telescope:GetChildren() do
	if child:IsA("UIStroke") or child:IsA("UIGradient") then
		child:Destroy()
	elseif child:IsA("GuiObject") then
		child.Visible = false -- old title / result lines (the reel shows results now)
	end
end
local function bigAction(x: number, size: number, iconKey: string, fallbackColor: Color3, onClick)
	local holder = make("TextButton", { Size = UDim2.new(0, size, 0, size + 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, x, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = telescope })
	local icon = uiIcon(iconKey, { Size = UDim2.new(0, size, 0, size), ZIndex = 6, Parent = holder })
	if not icon then
		make("Frame", { Size = UDim2.new(0, size * 0.8, 0, size * 0.8), Position = UDim2.new(0.1, 0, 0.1, 0), BackgroundColor3 = fallbackColor, ZIndex = 6, Parent = holder }, { corner(18), stroke(INK, 4) })
	end
	local label = text({ Size = UDim2.new(1, 40, 0, 40), Position = UDim2.new(0, -20, 1, -40), Text = "", FontFace = TITLE, TextColor3 = WHITE, Max = 34, ZIndex = 7, Parent = holder })
	make("UIStroke", { Color = INK, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	local scale = make("UIScale", { Parent = holder })
	holder.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.07 }):Play()
	end)
	holder.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	holder.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return holder, label
end
local inventoryLabel = select(2, bigAction(-170, 92, "backpack", Color3.fromRGB(190, 120, 60), function()
	open(catalogueW)
end))
rollButton = select(2, bigAction(0, 128, "roll", WHITE, doRoll))
local upgradesLabel = select(2, bigAction(170, 92, "upgrades", Color3.fromRGB(80, 210, 110), function()
	open(upgradesW)
end))
bind(inventoryLabel, "inventory")
bind(upgradesLabel, "upgrades")
autoButton = btn(GREY, { Size = UDim2.new(0, 130, 0, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Text = "", Max = 17, ZIndex = 8, Parent = telescope }, function()
	if canAutoRoll() then
		autoRoll = not autoRoll
		renderTelescope()
	end
end)

---------------------------------------------------------------- Events
do
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
			task.defer(applyDayNight) -- the world's lighting is set by the server first
		end
		if firstState then
			firstState = false
			setLang(if state.lang == "en" or state.lang == "ru" then state.lang else autoLang)
			tutorialClosed = state.tutorialDone == true
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
end
---------------------------------------------------------------- Daily chest
local dailyButton, dailyNext, setLid
do
	dailyButton = nil
	dailyNext = function(now: number): (number, boolean)
		local daily = state.daily or { day = 0, last = 0 }
		local lost = daily.last > 0 and now - daily.last > Config.DailyStreakLoss
		local nextDay = if daily.day >= #Config.DailyRewards or lost then 1 else daily.day + 1
		return nextDay, now - daily.last >= Config.DailyCooldown
	end

	local function rewardText(reward): string
		local parts = {}
		if reward.cash then
			table.insert(parts, "+" .. Format.number(Config.DailyCash(reward.cash, state.income or 0)))
		end
		if reward.item then
			table.insert(parts, Lang.item(lang, reward.item) .. " x" .. (reward.count or 1))
		end
		if reward.boost then
			table.insert(parts, t("rewardBoost", t(if reward.boost == "luck" then "luckWord2" else "speedWord2"), reward.minutes))
		end
		return table.concat(parts, "\n")
	end

	renderers[dailyW] = function()
		local body = dailyW.body
		clear(body)
		local now = workspace:GetServerTimeNow()
		local daily = state.daily or { day = 0, last = 0 }
		local nextDay, ready = dailyNext(now)
		-- days of the current streak that were already claimed are revealed; the rest stay black
		local revealed = if nextDay == 1 and ready then 0 else daily.day
		text({ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Text = t("dailyHint"), TextColor3 = MUTED, FontFace = BODY_SEMI, TextWrapped = true, Max = 15, ZIndex = 21, Parent = body })
		local grid = make("Frame", { Size = UDim2.new(1, 0, 0, 170), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 21, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(1 / #Config.DailyRewards, -8, 1, 0), CellPadding = UDim2.new(0, 8, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		for day, reward in Config.DailyRewards do
			local shown = day <= revealed
			local isNext = day == nextDay
			local card = make("Frame", {
				LayoutOrder = day, ZIndex = 22, Parent = grid,
				BackgroundColor3 = if shown then WHITE else Color3.fromRGB(18, 18, 28),
			}, { corner(12), stroke(if isNext then GOLD else INK, if isNext then 4 else 2.5) })
			text({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 6), Text = t("dayN", day), FontFace = TITLE, TextColor3 = if shown then BLUE else WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = if shown then 1 else 0.3, Max = 18, ZIndex = 23, Parent = card })
			if shown then
				if reward.item then
					local star, mutation = Items.parse(reward.item)
					if star then
						starIcon(star, mutation, { Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0.5, -28, 0, 36), ZIndex = 23, Parent = card })
					end
				else
					uiIcon(if reward.cash then "coins" else (if reward.boost == "luck" then "luck" else "rolls"), { Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0.5, -28, 0, 36), ZIndex = 23, Parent = card })
				end
				text({ Size = UDim2.new(1, -8, 0, 54), Position = UDim2.new(0, 4, 0, 96), Text = rewardText(reward), FontFace = BODY, TextWrapped = true, Max = 14, ZIndex = 23, Parent = card })
			else
				text({ Size = UDim2.new(1, 0, 0, 80), Position = UDim2.new(0, 0, 0, 40), Text = "?", FontFace = TITLE, TextColor3 = Color3.fromRGB(90, 90, 120), Max = 60, ZIndex = 23, Parent = card })
			end
		end
		dailyButton = btn(if ready then MINT else GREY, {
			Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 3, ZIndex = 21, Max = 20,
			Text = if ready then t("dailyClaim", nextDay) else t("dailyWait", Format.time(Config.DailyCooldown - (now - daily.last))), Parent = body,
		}, function()
			local _, canClaim = dailyNext(workspace:GetServerTimeNow())
			if canClaim then
				ActionEv:FireServer("ClaimDaily")
			end
		end)
	end

	-- the chest lid swings open while you stand near it
	local lidParts = nil
	setLid = function(openLid: boolean)
		local chest = CollectionService:GetTagged("DailyChest")[1]
		local lid = chest and chest:FindFirstChild("Lid")
		if not lid then
			return
		end
		if not lidParts then
			lidParts = {}
			for _, part in { lid, lid:FindFirstChild("LidBand") } do
				if part then
					table.insert(lidParts, { part = part, base = part.CFrame })
				end
			end
			lidParts.hinge = lid.CFrame * CFrame.new(0, -lid.Size.Y / 2, lid.Size.Z / 2)
		end
		local opened = lidParts.hinge * CFrame.Angles(math.rad(75), 0, 0) * lidParts.hinge:Inverse()
		for _, info in ipairs(lidParts) do
			TweenService:Create(info.part, TweenInfo.new(0.5, Enum.EasingStyle.Back), { CFrame = if openLid then opened * info.base else info.base }):Play()
		end
	end
end

---------------------------------------------------------------- Codes
renderers[codesW] = function()
	local body = codesW.body
	clear(body)
	-- rounded frame holds a transparent text box (no square corners poking out)
	local holder = make("Frame", { Size = UDim2.new(1, -8, 0, 50), LayoutOrder = 1, BackgroundColor3 = WHITE, ZIndex = 22, Parent = body }, { corner(14), stroke(INK, 2.5) })
	local box = make("TextBox", {
		Size = UDim2.new(1, -24, 1, -12), Position = UDim2.new(0, 12, 0, 6), BackgroundTransparency = 1, PlaceholderText = t("codeHint"), Text = "",
		TextColor3 = TEXT, FontFace = TITLE, TextScaled = true, ClearTextOnFocus = false, ZIndex = 23, Parent = holder,
	}, { make("UITextSizeConstraint", { MaxTextSize = 22 }) })
	btn(MINT, { Size = UDim2.new(1, -8, 0, 50), LayoutOrder = 2, Text = t("redeem"), Max = 20, ZIndex = 22, Parent = body }, function()
		if box.Text ~= "" then
			ActionEv:FireServer("RedeemCode", box.Text)
			box.Text = ""
		end
	end)
end

---------------------------------------------------------------- Tutorial guidance (a light beam towards the goal)
local updateTutorial
do
	local guideBeam: Beam? = nil
	local guideTarget: Attachment? = nil
	local function setGuide(target: BasePart?)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not target or not root then
			if guideBeam then
				guideBeam:Destroy()
				guideBeam = nil
			end
			if guideTarget then
				guideTarget:Destroy()
				guideTarget = nil
			end
			return
		end
		if not guideBeam or not guideBeam.Attachment0 or guideBeam.Attachment0.Parent ~= root then
			if guideBeam then
				guideBeam:Destroy()
			end
			local from = Instance.new("Attachment")
			from.Parent = root
			guideBeam = make("Beam", {
				Attachment0 = from, Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)), LightEmission = 1, Width0 = 1.2, Width1 = 1.2,
				FaceCamera = true, Transparency = NumberSequence.new(0.2, 0.6), Segments = 10, Parent = root,
			})
		end
		if not guideTarget or guideTarget.Parent ~= target then
			if guideTarget then
				guideTarget:Destroy()
			end
			guideTarget = Instance.new("Attachment")
			guideTarget.Parent = target
			guideBeam.Attachment1 = guideTarget
		end
	end

	updateTutorial = function()
		if not state or tutorialClosed then
			tutorialCard.Visible = false
			setGuide(nil)
			return
		end
		-- automatic steps advance by themselves
		if tutorialStep == 1 and state.totalRolls >= 3 then
			tutorialStep = 2
		end
		if tutorialStep == 2 and state.hasPlot then
			tutorialStep = 3
		end
		if tutorialStep == 3 and next(state.grid) ~= nil then
			tutorialStep = 4
		end
		tutorialCard.Visible = not buildMode -- the build panel takes the left side
		tutorialTitle.Text = t("tutTitle", tutorialStep, TUTORIAL_STEPS)
		tutorialText.Text = t("tut" .. tutorialStep)
		tutorialNext.Visible = tutorialStep >= 4
		tutorialNext.Text = if tutorialStep >= TUTORIAL_STEPS then t("tutDone") else t("tutNext")
		-- guide beam
		local target = nil
		local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
		if tutorialStep == 2 and plots then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local best = math.huge
			for _, plot in plots:GetChildren() do
				local post = plot:FindFirstChild("SignPost")
				if plot:GetAttribute("OwnerId") == 0 and post and root then
					local d = (post.Position - root.Position).Magnitude
					if d < best then
						best = d
						target = post
					end
				end
			end
		elseif tutorialStep == 3 then
			local mine = myPlotFolder()
			local pedestals = mine and mine:FindFirstChild("Pedestals")
			local first = pedestals and pedestals:FindFirstChildWhichIsA("Model")
			target = first and first.PrimaryPart
		end
		setGuide(target)
	end

	renderers[elevatorW] = function()
		local body = elevatorW.body
		clear(body)
		for floor = 1, elevatorInfo.floors do
			local here = floor == elevatorInfo.floor
			btn(if here then GREY else BLUE, { Size = UDim2.new(1, 0, 0, 50), LayoutOrder = floor, Text = t("floorN", floor), Max = 20, ZIndex = 22, Parent = body }, function()
				if not here then
					ActionEv:FireServer("Elevator", elevatorInfo.plot, floor)
				end
				elevatorW.frame.Visible = false
			end)
		end
	end
end

---------------------------------------------------------------- Robux shop (tabs on the right, gradient cards)
local shopTab, rgbStroke, titleText
do
	shopTab = "featured"
	local rgbGradients = {}
	local RAINBOW = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 120)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 200, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 90, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 70)),
	})
	-- glowing rainbow outline that keeps spinning
	rgbStroke = function(target: GuiObject, thickness: number)
		local outline = make("UIStroke", { Thickness = thickness, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = target })
		local gradient = make("UIGradient", { Color = RAINBOW, Parent = outline })
		rgbGradients[gradient] = true
		return outline
	end
	RunService.RenderStepped:Connect(function(dt)
		for gradient in rgbGradients do
			if gradient.Parent then
				gradient.Rotation = (gradient.Rotation + dt * 140) % 360
			else
				rgbGradients[gradient] = nil
			end
		end
	end)

	local pendingGiftItem = nil
	local function buy(kind: string, index: number, entry)
		if kind == "pass" then
			if entry.id and entry.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, entry.id)
			elseif RunService:IsStudio() then
				ActionEv:FireServer("ShopTest", "pass", index)
			else
				showToast(t("notConfigured"))
			end
			return
		end
		if entry.id and entry.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, entry.id)
		elseif RunService:IsStudio() then
			ActionEv:FireServer("ShopTest", kind, index) -- free test in Studio until the product exists
		else
			showToast(t("notConfigured"))
		end
	end

	local function gradientCard(parent: Instance, props, top: Color3, bottom: Color3)
		props.BackgroundColor3 = WHITE
		props.ZIndex = props.ZIndex or 22
		props.Parent = parent
		local card = make("Frame", props, {
			corner(16), stroke(INK, 3),
			make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }),
		})
		-- soft glow in the middle, like a spotlight behind the item
		make("Frame", { Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.05, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, ZIndex = card.ZIndex, Parent = card }, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		return card
	end

	titleText = function(parent: Instance, value: string, props)
		props.Text = value
		props.FontFace = TITLE
		props.TextColor3 = props.TextColor3 or WHITE
		props.TextStrokeColor3 = INK
		props.TextStrokeTransparency = 0
		props.ZIndex = props.ZIndex or 24
		props.Parent = parent
		return text(props)
	end

	-- green price button with the robux icon
	local function priceButton(parent: Instance, props, price: number, onClick, color: Color3?)
		props.Text = ""
		props.Parent = parent
		props.ZIndex = props.ZIndex or 24
		local b = btn(color or Color3.fromRGB(70, 210, 80), props, onClick)
		local row = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = b.ZIndex + 1, Parent = b })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		local icon = uiIcon("robux", { Size = UDim2.new(0, 28, 0, 28), LayoutOrder = 1, ZIndex = b.ZIndex + 1, Parent = row })
		make("TextLabel", {
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 2,
			Text = (if icon then "" else "R$ ") .. Format.number(price), FontFace = TITLE, TextSize = 24, TextColor3 = WHITE,
			TextStrokeColor3 = INK, TextStrokeTransparency = 0, ZIndex = b.ZIndex + 1, Parent = row,
		})
		return b
	end

	-- purple gift button: pick a player, then buy for them
	local function giftButton(parent: Instance, props, kind: string, index: number, entry)
		props.Text = ""
		props.Parent = parent
		props.ZIndex = props.ZIndex or 24
		local b = btn(Color3.fromRGB(190, 80, 230), props, function()
			pendingGiftItem = { kind = kind, index = index, entry = entry }
			open(giftW, true)
		end)
		make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = b })
		local icon = uiIcon("rewards", { Size = UDim2.new(1, 0, 1, 0), ZIndex = b.ZIndex + 1, Parent = b })
		if not icon then
			b.Text = "GIFT"
		end
		return b
	end

	renderers[giftW] = function()
		local body = giftW.body
		clear(body)
		local any = false
		for _, other in Players:GetPlayers() do
			if other ~= player then
				any = true
				btn(BLUE, { Size = UDim2.new(1, -8, 0, 46), Text = other.DisplayName, Max = 18, ZIndex = 22, Parent = body }, function()
					local item = pendingGiftItem
					giftW.frame.Visible = false
					if item then
						ActionEv:FireServer("SetGift", other.UserId)
						buy(item.kind, item.index, item.entry)
					end
				end)
			end
		end
		if not any then
			text({ Size = UDim2.new(1, 0, 0, 40), Text = t("giftNobody"), TextColor3 = MUTED, Max = 16, ZIndex = 22, Parent = body })
		end
	end

	local function sectionTitle(parent: Instance, order: number, key: string)
		titleText(parent, "— " .. t(key) .. " —", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, TextColor3 = Color3.fromRGB(255, 205, 60), Max = 30, ZIndex = 22 })
	end

	-- shop frame: dark board, tab rail on the right
	shopW.frame.BackgroundColor3 = Color3.fromRGB(46, 50, 68)
	shopW.body.Size = UDim2.new(1, -150, 1, -8)
	shopW.body.Position = UDim2.new(0, 0, 0, 8)
	local shopRail = make("Frame", { Size = UDim2.new(0, 138, 1, -12), Position = UDim2.new(1, -138, 0, 8), BackgroundTransparency = 1, ZIndex = 21, Parent = shopW.frame })
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = shopRail })
	local SHOP_TABS = {
		{ id = "featured", key = "shopFeatured", color = Color3.fromRGB(170, 90, 255), icon = "crate" },
		{ id = "passes", key = "shopPasses", color = Color3.fromRGB(255, 170, 40), icon = "crown" },
		{ id = "money", key = "shopMoney", color = Color3.fromRGB(70, 200, 90), icon = "coins" },
		{ id = "luckspeed", key = "shopLuckSpeed", color = Color3.fromRGB(70, 160, 255), icon = "luck" },
		{ id = "boosts", key = "shopBoosts", color = Color3.fromRGB(255, 100, 140), icon = "bolt" },
		{ id = "codes", key = "codes", color = Color3.fromRGB(80, 170, 240), icon = "codes" },
	}

	-- slowly spinning light rays behind the featured crate
	local spinning = {}
	RunService.RenderStepped:Connect(function(dt)
		for ray in spinning do
			if ray.Parent then
				ray.Rotation = (ray.Rotation + dt * 12) % 360
			else
				spinning[ray] = nil
			end
		end
	end)
	local function sunburst(parent: GuiObject, center: UDim2, color: Color3, z: number)
		for k = 0, 11 do
			local ray = make("Frame", {
				Size = UDim2.new(0, 46, 0, 900), AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Rotation = k * 15,
				BackgroundColor3 = color, BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = z, Parent = parent,
			}, {
				make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }),
			})
			spinning[ray] = true
		end
	end

	local renderShopTab = {}

	renderShopTab.featured = function(body)
		sectionTitle(body, 1, "shopFeatured")
		local crate = Config.Shop.crate
		local card = gradientCard(body, { Size = UDim2.new(1, -8, 0, 330), LayoutOrder = 2, ClipsDescendants = true }, Color3.fromRGB(150, 80, 255), Color3.fromRGB(40, 20, 100))
		rgbStroke(card, 5)
		local paintedBg = Config.UiIcons.crateBg
		if paintedBg and paintedBg ~= "" then
			make("ImageLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "rbxassetid://" .. paintedBg, ScaleType = Enum.ScaleType.Crop, ZIndex = 22, Parent = card }, { corner(16) })
		end
		sunburst(card, UDim2.new(0, 80, 0, 150), Color3.fromRGB(255, 230, 255), 22)
		for k = 1, 14 do -- twinkling little stars
			local dot = make("Frame", {
				Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(math.random(), 0, math.random() * 0.75, 0), Rotation = 45,
				BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 23, Parent = card,
			})
			TweenService:Create(dot, TweenInfo.new(0.6 + math.random() * 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, math.random() * 1.5), { BackgroundTransparency = 1, Size = UDim2.new(0, 2, 0, 2) }):Play()
		end
		local badge = make("Frame", { Size = UDim2.new(0, 110, 0, 34), Position = UDim2.new(0, 14, 0, 12), Rotation = -6, BackgroundColor3 = WHITE, ZIndex = 24, Parent = card }, {
			corner(8), stroke(INK, 2.5),
		})
		CollectionService:AddTag(make("UIGradient", { Parent = badge }), "RainbowFx")
		titleText(badge, t("newBadge"), { Size = UDim2.new(1, 0, 1, 0), Max = 20, ZIndex = 25 })
		local pulse = make("UIScale", { Parent = badge })
		TweenService:Create(pulse, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 }):Play()
		titleText(card, t("crateName"), { Size = UDim2.new(0.6, 0, 0, 44), Position = UDim2.new(0, 134, 0, 8), TextColor3 = Color3.fromRGB(255, 225, 80), TextXAlignment = Enum.TextXAlignment.Left, Max = 36 })
		text({ Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 136, 0, 52), Text = t("crateOdds"), FontFace = BODY, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Max = 15, ZIndex = 24, Parent = card })
		uiIcon("crate", { Size = UDim2.new(0, 150, 0, 150), Position = UDim2.new(0, 6, 0, 70), ZIndex = 24, Parent = card })
		-- odds tiles; the rarest one is big with a spinning rainbow frame
		local tiles = make("Frame", { Size = UDim2.new(1, -170, 0, 170), Position = UDim2.new(0, 160, 0, 80), BackgroundTransparency = 1, ZIndex = 23, Parent = card })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tiles })
		for i, entry in crate.odds do
			local star, mutation = Items.parse(entry.item)
			if star then
				local top = i == #crate.odds
				-- sizes follow the card width, so the top drop always fits (shop window got smaller)
				local share = if top then 0.22 else (0.76 / (#crate.odds - 1))
				local tile = make("Frame", { Size = UDim2.new(share, -8, 1, 0), LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(30, 18, 66), ZIndex = 24, Parent = tiles }, {
					corner(10), make("UIAspectRatioConstraint", { AspectRatio = 0.9, DominantAxis = Enum.DominantAxis.Width }),
				})
				if top then
					rgbStroke(tile, 4)
					titleText(tile, t("topDrop"), { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, -26), Max = 20, ZIndex = 26 }):FindFirstChildOfClass("UITextSizeConstraint")
					local label = tile:FindFirstChildWhichIsA("TextLabel")
					if label then
						make("UIGradient", { Color = RAINBOW, Parent = label })
					end
				else
					stroke(INK, 2.5).Parent = tile
				end
				if top then
					-- the top drop stays a mystery
					local mystery = titleText(tile, "???", { Size = UDim2.new(0.9, 0, 0.62, 0), Position = UDim2.new(0.05, 0, 0.06, 0), TextColor3 = WHITE, Max = 80, ZIndex = 26 })
					CollectionService:AddTag(make("UIGradient", { Parent = mystery }), "RainbowFx")
				else
					starIcon(star, mutation, { Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.02, 0), ZIndex = 25, Parent = tile })
				end
				titleText(tile, (math.floor(entry.p * 1000 + 0.5) / 10) .. "%", { Size = UDim2.new(1, -8, 0.2, 0), Position = UDim2.new(0, 4, 0.78, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if top then Color3.fromRGB(255, 225, 80) else WHITE, Max = 20, ZIndex = 26 })
			end
		end
		-- buy row: biggest pack first, like the reference
		local row = make("Frame", { Size = UDim2.new(1, -20, 0, 66), Position = UDim2.new(0, 10, 1, -74), BackgroundTransparency = 1, ZIndex = 23, Parent = card })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i = #crate.packs, 1, -1 do
			local pack = crate.packs[i]
			local slot = make("Frame", { Size = UDim2.new(0.24, -8, 1, 0), LayoutOrder = #crate.packs - i, BackgroundTransparency = 1, ZIndex = 23, Parent = row })
			giftButton(slot, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 0, 0, 0) }, "crate", i, pack)
			priceButton(slot, { Size = UDim2.new(1, -50, 0, 44), Position = UDim2.new(0, 50, 0, 0), Max = 20 }, pack.price, function()
				buy("crate", i, pack)
			end, if pack.count >= 50 then Color3.fromRGB(230, 60, 60) else nil)
			titleText(slot, if pack.count == 1 then t("crate1") else t("crates", pack.count), { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 46), Max = 15 })
			if pack.oldPrice then
				local old = titleText(slot, Format.number(pack.oldPrice), { Size = UDim2.new(0, 70, 0, 18), Position = UDim2.new(0.5, -10, 0, -20), TextColor3 = Color3.fromRGB(255, 90, 90), Max = 15 })
				make("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 70, 70), BorderSizePixel = 0, ZIndex = 27, Parent = old })
			end
		end
	end

	renderShopTab.passes = function(body)
		sectionTitle(body, 1, "shopPasses")
		local grid = make("Frame", { Size = UDim2.new(1, -8, 0, 2 * 236), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -10, 0, 226), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		for i, pass in Config.Passes do
			local owned = state.passes and state.passes[pass.key]
			local card = gradientCard(grid, { LayoutOrder = i }, pass.top, pass.bottom)
			titleText(card, t("pass_" .. pass.key), { Size = UDim2.new(1, -12, 0, 34), Position = UDim2.new(0, 6, 0, 8), Max = 26 })
			local holder = make("Frame", { Size = UDim2.new(0, 98, 0, 98), Position = UDim2.new(0.5, -49, 0, 42), BackgroundColor3 = Color3.fromRGB(30, 30, 50), BackgroundTransparency = 0.35, ZIndex = 23, Parent = card }, {
				make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(WHITE, 3),
			})
			uiIcon(pass.icon, { Size = UDim2.new(1.08, 0, 1.08, 0), Position = UDim2.new(-0.04, 0, -0.04, 0), ZIndex = 24, Parent = holder })
			titleText(card, t("passDesc_" .. pass.key), { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 0, 146), Max = 17 })
			if owned then
				btn(GREY, { Size = UDim2.new(0.7, 0, 0, 40), Position = UDim2.new(0.15, 0, 1, -48), Text = t("owned"), Max = 20, ZIndex = 24, Parent = card })
			else
				priceButton(card, { Size = UDim2.new(0.7, 0, 0, 40), Position = UDim2.new(0.15, 0, 1, -48), Max = 20 }, pass.price, function()
					buy("pass", i, pass)
				end)
			end
		end
	end

	renderShopTab.money = function(body)
		sectionTitle(body, 1, "shopMoney")
		local function coinCard(parent: Instance, order: number, index: number, big: boolean)
			local pack = Config.Shop.coins[index]
			local card = gradientCard(parent, { LayoutOrder = order }, Color3.fromRGB(255, 225, 90), Color3.fromRGB(245, 170, 30))
			titleText(card, t(pack.key), { Size = UDim2.new(1, -60, 0, if big then 34 else 26), Position = UDim2.new(0, 10, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, Max = if big then 28 else 20 })
			uiIcon(if big then "coins_big" else "coins_small", { Size = UDim2.new(0, if big then 130 else 90, 0, if big then 130 else 90), Position = UDim2.new(0, 10, 0, if big then 46 else 40), ZIndex = 24, Parent = card })
			titleText(card, Format.number(Config.CoinPack(pack, state.income or 0)), { Size = UDim2.new(0.55, 0, 0, if big then 60 else 36), Position = UDim2.new(0.42, 0, 0, if big then 60 else 46), Max = if big then 56 else 32 })
			giftButton(card, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -48, 0, 8) }, "coins", index, pack)
			priceButton(card, { Size = UDim2.new(0.5, 0, 0, 40), Position = UDim2.new(0.46, 0, 1, -48), Max = 20 }, pack.price, function()
				buy("coins", index, pack)
			end)
		end
		local top = make("Frame", { Size = UDim2.new(1, -8, 0, 210), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 1, 0), CellPadding = UDim2.new(0, 12, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = top })
		coinCard(top, 1, 5, true)
		coinCard(top, 2, 4, true)
		local bottom = make("Frame", { Size = UDim2.new(1, -8, 0, 170), LayoutOrder = 3, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 1, 0), CellPadding = UDim2.new(0, 12, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = bottom })
		coinCard(bottom, 1, 3, false)
		coinCard(bottom, 2, 2, false)
		coinCard(bottom, 3, 1, false)
	end

	renderShopTab.luckspeed = function(body)
		sectionTitle(body, 1, "shopLuckSpeed")
		-- "DOUBLE your X: x1 > x2" cards
		local function doubleCard(order: number, titleKey: string, now: string, after: string, list, owned: number, kind: string, top: Color3, bottom: Color3, iconKey: string)
			local card = gradientCard(body, { Size = UDim2.new(1, -8, 0, 150), LayoutOrder = order }, top, bottom)
			uiIcon(iconKey, { Size = UDim2.new(0, 110, 0, 110), Position = UDim2.new(0, 14, 0.5, -55), ZIndex = 24, Parent = card })
			titleText(card, t(titleKey), { Size = UDim2.new(0.6, 0, 0, 36), Position = UDim2.new(0.2, 0, 0, 8), Max = 30 })
			titleText(card, now, { Size = UDim2.new(0.18, 0, 0, 70), Position = UDim2.new(0.24, 0, 0, 52), Max = 64 })
			titleText(card, ">", { Size = UDim2.new(0.06, 0, 0, 50), Position = UDim2.new(0.43, 0, 0, 62), Max = 40 })
			titleText(card, after, { Size = UDim2.new(0.2, 0, 0, 70), Position = UDim2.new(0.5, 0, 0, 52), TextColor3 = Color3.fromRGB(255, 215, 60), Max = 64 })
			local nextTier = list[owned + 1]
			if nextTier then
				priceButton(card, { Size = UDim2.new(0.22, 0, 0, 56), Position = UDim2.new(0.76, 0, 0.5, -28), Max = 24 }, nextTier.price, function()
					buy(kind, owned + 1, nextTier)
				end)
			else
				btn(GREY, { Size = UDim2.new(0.22, 0, 0, 56), Position = UDim2.new(0.76, 0, 0.5, -28), Text = t("upMax"), Max = 22, ZIndex = 24, Parent = card })
			end
		end
		local luckOwned = state.robuxLuck or 0
		doubleCard(2, "doubleLuck", "x" .. (1 + luckOwned), "x" .. (2 + luckOwned), Config.Shop.luckTiers, luckOwned, "luckTier", Color3.fromRGB(110, 240, 140), Color3.fromRGB(30, 150, 80), "boost_luck")
		local speedOwned = state.robuxSpeed or 0
		doubleCard(3, "doubleSpeed", "x" .. Config.RobuxSpeedMult(speedOwned), "x" .. Config.RobuxSpeedMult(speedOwned + 1), Config.Shop.speedTiers, speedOwned, "speed", Color3.fromRGB(110, 210, 255), Color3.fromRGB(30, 110, 230), "boost_speed")
		local multiOwned = state.robuxMulti or 0
		local perClick = Config.RollsPerClick(state, state.passes)
		doubleCard(4, "permMulti", tostring(perClick), tostring(perClick + 1), Config.Shop.multiTiers, multiOwned, "multi", Color3.fromRGB(210, 150, 255), Color3.fromRGB(110, 50, 220), "pass_extraroll")
	end

	renderShopTab.boosts = function(body)
		sectionTitle(body, 1, "shopBoosts")
		local grid = make("Frame", { Size = UDim2.new(1, -8, 0, 2 * 190), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -10, 0, 180), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		for group, info in { { kind = "luckBoost", list = Config.Shop.luckBoosts, title = "luckBoost", top = Color3.fromRGB(110, 240, 140), bottom = Color3.fromRGB(30, 150, 80), icon = "boost_luck" }, { kind = "speedBoost", list = Config.Shop.speedBoosts, title = "speedBoost", top = Color3.fromRGB(110, 210, 255), bottom = Color3.fromRGB(30, 110, 230), icon = "boost_speed" } } do
			for i, boost in info.list do
				local card = gradientCard(grid, { LayoutOrder = group * 10 + i }, info.top, info.bottom)
				titleText(card, t(info.title), { Size = UDim2.new(1, -54, 0, 28), Position = UDim2.new(0, 8, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, Max = 22 })
				uiIcon(info.icon, { Size = UDim2.new(0, 70, 0, 70), Position = UDim2.new(0, 10, 0, 44), ZIndex = 24, Parent = card })
				titleText(card, t("minutes", boost.minutes), { Size = UDim2.new(0.5, 0, 0, 44), Position = UDim2.new(0.45, 0, 0, 56), Max = 34 })
				giftButton(card, { Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(1, -46, 0, 6) }, info.kind, i, boost)
				priceButton(card, { Size = UDim2.new(0.8, 0, 0, 42), Position = UDim2.new(0.1, 0, 1, -50), Max = 20 }, boost.price, function()
					buy(info.kind, i, boost)
				end)
			end
		end
	end

	local codesSection = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 22 }, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	do
		titleText(codesSection, "— " .. t("codes") .. " —", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, TextColor3 = Color3.fromRGB(255, 205, 60), Max = 30, ZIndex = 22 })
		local card = gradientCard(codesSection, { Size = UDim2.new(1, -8, 0, 96), LayoutOrder = 2 }, Color3.fromRGB(110, 190, 255), Color3.fromRGB(40, 90, 210))
		uiIcon("codes", { Size = UDim2.new(0, 76, 0, 76), Position = UDim2.new(0, 10, 0.5, -38), ZIndex = 24, Parent = card })
		local holder = make("Frame", { Size = UDim2.new(1, -320, 0, 54), Position = UDim2.new(0, 96, 0.5, -27), BackgroundColor3 = WHITE, ZIndex = 24, Parent = card }, { corner(14), stroke(INK, 2.5) })
		local box = make("TextBox", {
			Size = UDim2.new(1, -24, 1, -12), Position = UDim2.new(0, 12, 0, 6), BackgroundTransparency = 1, PlaceholderText = t("codeHint"), Text = "",
			TextColor3 = TEXT, FontFace = TITLE, TextScaled = true, ClearTextOnFocus = false, ZIndex = 25, Parent = holder,
		}, { make("UITextSizeConstraint", { MaxTextSize = 24 }) })
		btn(Color3.fromRGB(70, 210, 80), { Size = UDim2.new(0, 200, 0, 54), Position = UDim2.new(1, -212, 0.5, -27), Text = t("redeem"), Max = 22, ZIndex = 24, Parent = card }, function()
			if box.Text ~= "" then
				ActionEv:FireServer("RedeemCode", box.Text)
				box.Text = ""
			end
		end)
	end
	renderShopTab.codes = function(body)
		codesSection.Parent = body
	end

	-- one long column; the rail on the right just scrolls to a section
	local sections = {}
	local railButtons = {}
	local function jumpTo(id: string)
		local section = sections[id]
		local body = shopW.body
		if not section then
			return
		end
		local y = section.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y
		local maxY = math.max(0, body.AbsoluteCanvasSize.Y - body.AbsoluteWindowSize.Y)
		TweenService:Create(body, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { CanvasPosition = Vector2.new(0, math.clamp(y - 4, 0, maxY)) }):Play()
		for tabId, b in railButtons do -- highlight the pressed tab right away
			for _, entry in SHOP_TABS do
				if entry.id == tabId then
					b.BackgroundColor3 = if tabId == id then entry.color else Color3.fromRGB(90, 96, 120)
				end
			end
		end
	end
	local function highlightRail()
		local body = shopW.body
		local current = SHOP_TABS[1].id
		for _, tab in SHOP_TABS do
			local section = sections[tab.id]
			if section and section.AbsolutePosition.Y - body.AbsolutePosition.Y <= 60 then
				current = tab.id
			end
		end
		for id, b in railButtons do
			local tab = nil
			for _, entry in SHOP_TABS do
				if entry.id == id then
					tab = entry
				end
			end
			b.BackgroundColor3 = if id == current and tab then tab.color else Color3.fromRGB(90, 96, 120)
		end
	end
	shopW.body:GetPropertyChangedSignal("CanvasPosition"):Connect(highlightRail)

	renderers[shopW] = function()
		clear(shopRail)
		railButtons = {}
		for order, tab in SHOP_TABS do
			railButtons[tab.id] = btn(Color3.fromRGB(90, 96, 120), { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = order, Text = t(tab.key), Max = 15, ZIndex = 22, Parent = shopRail }, function()
				jumpTo(tab.id)
			end)
		end
		local body = shopW.body
		codesSection.Parent = nil -- survives the clear (keeps what you typed)
		clear(body)
		sections = {}
		for order, tab in SHOP_TABS do
			local section = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, BackgroundTransparency = 1, ZIndex = 21, Parent = body }, {
				make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			sections[tab.id] = section
			renderShopTab[tab.id](section)
		end
		-- empty space at the end: lets the last sections (codes) scroll up to the top too
		make("Frame", { Size = UDim2.new(1, 0, 0, math.max(200, shopW.body.AbsoluteSize.Y - 160)), LayoutOrder = #SHOP_TABS + 1, BackgroundTransparency = 1, Parent = body })
		highlightRail()
		if shopTab then -- opened for a specific section (e.g. from the crate ring)
			local target = shopTab
			shopTab = nil
			task.defer(function()
				RunService.RenderStepped:Wait()
				jumpTo(target)
			end)
		end
	end
end

---------------------------------------------------------------- Trading
do
	local tradeState = nil
	local tradeRequest = nil
	local tradeCountdownEnd: number? = nil
	local tradeInfoKey: string? = nil
	local tradeClosingQuietly = false
	local tradeCountdownLabel: TextLabel? = nil

	renderers[playersW] = function()
		local body = playersW.body
		clear(body)
		local any = false
		for _, other in Players:GetPlayers() do
			if other ~= player then
				any = true
				btn(Color3.fromRGB(255, 140, 60), { Size = UDim2.new(1, -8, 0, 46), Text = t("tradeSend") .. ":  " .. other.DisplayName, Max = 18, ZIndex = 22, Parent = body }, function()
					ActionEv:FireServer("TradeRequest", other.UserId)
					playersW.frame.Visible = false
				end)
			end
		end
		if not any then
			text({ Size = UDim2.new(1, 0, 0, 40), Text = t("tradeNobody"), TextColor3 = MUTED, Max = 16, ZIndex = 22, Parent = body })
		end
	end

	renderers[tradeReqW] = function()
		local body = tradeReqW.body
		clear(body)
		if not tradeRequest then
			return
		end
		text({ Size = UDim2.new(1, 0, 0, 50), Text = t("tradeRequest", tradeRequest.from), FontFace = TITLE, TextWrapped = true, Max = 20, ZIndex = 22, Parent = body })
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 50), BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		local request = tradeRequest
		btn(MINT, { Size = UDim2.new(0.48, 0, 1, 0), Text = t("accept"), Max = 18, ZIndex = 23, Parent = row }, function()
			ActionEv:FireServer("TradeRespond", request.userId, true)
			tradeReqW.frame.Visible = false
		end)
		btn(RED, { Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), Text = t("decline"), Max = 18, ZIndex = 23, Parent = row }, function()
			ActionEv:FireServer("TradeRespond", request.userId, false)
			tradeReqW.frame.Visible = false
		end)
	end

	local function tradeCard(parent: Instance, order: number, key: string, count: number, onMinus, onPlus)
		local star, mutation = Items.parse(key)
		if not star then
			return
		end
		local card = make("TextButton", { LayoutOrder = order, Text = "", AutoButtonColor = true, BackgroundColor3 = if tradeInfoKey == key then Color3.fromRGB(220, 236, 255) else WHITE, ZIndex = 23, Parent = parent }, {
			corner(10), stroke(if tradeInfoKey == key then BLUE else INK, 2.5),
		})
		starIcon(star, mutation, { Size = UDim2.new(0, 64, 0, 64), Position = UDim2.new(0.5, -32, 0, 4), ZIndex = 24, Parent = card })
		text({ Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0, 3, 0, 70), Text = Lang.item(lang, key), FontFace = TITLE, Max = 13, ZIndex = 24, Parent = card })
		text({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 0, 88), Text = t("perSecShort", Format.number(Items.income(key))), FontFace = BODY, TextColor3 = MUTED, Max = 12, ZIndex = 24, Parent = card })
		titleText(card, "x" .. count, { Size = UDim2.new(0, 40, 0, 22), Position = UDim2.new(1, -44, 0, 2), Max = 18, ZIndex = 25 })
		card.Activated:Connect(function()
			tradeInfoKey = key -- full info about this star (works for the partner's stars too)
			renderers[tradeW]()
		end)
		if onMinus then
			btn(RED, { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 2, 0, 2), Text = "-", Max = 18, ZIndex = 25, Parent = card }, onMinus)
		end
		if onPlus then
			btn(MINT, { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 2, 0, 2), Text = "+", Max = 18, ZIndex = 25, Parent = card }, onPlus)
		end
	end

	renderers[tradeW] = function()
		local body = tradeW.body
		clear(body)
		if not tradeState then
			return
		end
		body.BackgroundColor3 = Color3.fromRGB(40, 44, 66)
		local function column(order: number, title: string, ready: boolean, offer, mine: boolean)
			local top = if order == 1 then Color3.fromRGB(90, 210, 110) else Color3.fromRGB(90, 160, 255)
			local col = make("Frame", { Size = UDim2.new(0.43, 0, 1, 0), Position = UDim2.new(if order == 1 then 0 else 0.57, 0, 0, 0), BackgroundColor3 = WHITE, ZIndex = 22 }, {
				corner(14), stroke(if ready then Color3.fromRGB(90, 255, 120) else INK, if ready then 5 else 3),
				make("UIGradient", { Color = ColorSequence.new(top, top:Lerp(Color3.new(0, 0, 0), 0.55)), Rotation = 90 }),
			})
			-- name plate + ready tick
			local plate = make("Frame", { Size = UDim2.new(1, -12, 0, 38), Position = UDim2.new(0, 6, 0, 6), BackgroundColor3 = Color3.fromRGB(20, 24, 40), BackgroundTransparency = 0.35, ZIndex = 23, Parent = col }, { corner(10) })
			titleText(plate, title, { Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 22 })
			titleText(plate, if ready then "✓" else "…", { Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -44, 0, 0), FontFace = Font.fromEnum(Enum.Font.SourceSansBold), TextColor3 = if ready then Color3.fromRGB(90, 255, 120) else Color3.fromRGB(200, 200, 210), Max = 32 })
			local grid = make("Frame", { Size = UDim2.new(1, -12, 1, -54), Position = UDim2.new(0, 6, 0, 50), BackgroundTransparency = 1, ZIndex = 22, Parent = col })
			make("UIGridLayout", { CellSize = UDim2.new(0, 110, 0, 108), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
			local keys = {}
			for key in offer do
				table.insert(keys, key)
			end
			table.sort(keys, function(a, b)
				return Items.rank(a) > Items.rank(b)
			end)
			for i, key in keys do
				tradeCard(grid, i, key, offer[key], if mine then function()
					ActionEv:FireServer("TradeOffer", key, -1)
				end else nil, nil)
			end
			return col
		end
		local top = make("Frame", { Size = UDim2.new(1, -8, 0, 290), LayoutOrder = 1, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		column(1, t("tradeYou"), tradeState.myReady, tradeState.mine, true).Parent = top
		column(2, tradeState.partner, tradeState.theirReady, tradeState.theirs, false).Parent = top
		-- two arrows in the middle: the swap
		local middle = make("Frame", { Size = UDim2.new(0.14, 0, 1, 0), Position = UDim2.new(0.43, 0, 0, 0), BackgroundTransparency = 1, ZIndex = 23, Parent = top })
		if not uiIcon("trade", { Size = UDim2.new(1, -8, 0, 120), Position = UDim2.new(0, 4, 0.5, -60), ZIndex = 24, Parent = middle }) then
			for k, info in { { "→", Color3.fromRGB(90, 230, 110), -56 }, { "←", Color3.fromRGB(90, 170, 255), 6 } } do
				local arrow = titleText(middle, info[1], { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0.5, info[3]), FontFace = Font.fromEnum(Enum.Font.SourceSansBold), TextColor3 = info[2], Max = 64, ZIndex = 24 })
				TweenService:Create(arrow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, if k == 1 then 6 else -6, 0.5, info[3]) }):Play()
			end
		end

		-- info about the selected star
		local info = if tradeInfoKey and Items.parse(tradeInfoKey) then t("tradeInfo", Lang.item(lang, tradeInfoKey), Format.number(Items.chance(tradeInfoKey)), Format.number(Items.income(tradeInfoKey)), Format.number(Items.income(tradeInfoKey) * Config.SellMultiplier)) else ""
		text({ Size = UDim2.new(1, -8, 0, 26), LayoutOrder = 2, Text = info, FontFace = TITLE, TextColor3 = BLUE, Max = 17, ZIndex = 22, Parent = body })

		-- ready / countdown / cancel
		local controls = make("Frame", { Size = UDim2.new(1, -8, 0, 52), LayoutOrder = 3, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		btn(if tradeState.myReady then MINT else GREY, { Size = UDim2.new(0.3, 0, 1, 0), Text = "✓  " .. (if tradeState.myReady then t("tradeReady") else t("tradeNotReady")), FontFace = TITLE, Max = 20, ZIndex = 23, Parent = controls }, function()
			ActionEv:FireServer("TradeReady", not tradeState.myReady)
		end)
		tradeCountdownLabel = titleText(controls, "", { Size = UDim2.new(0.36, 0, 1, 0), Position = UDim2.new(0.32, 0, 0, 0), TextColor3 = GOLD, Max = 26, ZIndex = 23 })
		btn(RED, { Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), Text = "X  " .. t("decline"), Max = 18, ZIndex = 23, Parent = controls }, function()
			ActionEv:FireServer("TradeCancel")
		end)

		-- your catalogue: tap + to add one
		text({ Size = UDim2.new(1, -8, 0, 22), LayoutOrder = 4, Text = t("tradeAdd"), TextColor3 = MUTED, FontFace = BODY_SEMI, Max = 15, ZIndex = 22, Parent = body })
		local inv = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(0, 110, 0, 108), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inv })
		for i, key in sortedInventory() do
			local left = (state.inventory[key] or 0) - (tradeState.mine[key] or 0)
			if left > 0 then
				tradeCard(inv, i, key, left, nil, function()
					ActionEv:FireServer("TradeOffer", key, 1)
				end)
			end
		end
	end

	-- closing the trade window cancels the trade
	tradeW.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not tradeW.frame.Visible and tradeState and not tradeClosingQuietly then
			ActionEv:FireServer("TradeCancel")
		end
	end)

	TradeEv.OnClientEvent:Connect(function(kind: string, info)
		if kind == "request" and type(info) == "table" then
			tradeRequest = info
			open(tradeReqW, true)
		elseif kind == "state" and type(info) == "table" then
			tradeState = info
			tradeCountdownEnd = if info.countdown then os.clock() + info.countdown else nil
			if tradeW.frame.Visible then
				renderers[tradeW]()
			else
				open(tradeW, true)
			end
		elseif kind == "closed" then
			tradeState = nil
			tradeCountdownEnd = nil
			tradeInfoKey = nil
			tradeClosingQuietly = true
			tradeW.frame.Visible = false
			tradeClosingQuietly = false
			if type(info) == "string" then
				showToast(t(info), if info == "tradeDone" then MINT else RED)
			end
		end
	end)

	task.spawn(function()
		while true do
			if tradeCountdownLabel and tradeCountdownLabel.Parent then
				tradeCountdownLabel.Text = if tradeCountdownEnd then t("tradeIn", math.max(0, math.ceil(tradeCountdownEnd - os.clock()))) else ""
			end
			task.wait(0.2)
		end
	end)
end

---------------------------------------------------------------- Crate opening: every crate on screen, rows of five
do
	local function showCrateResults(got)
		local overlay = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 6, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 150, Parent = gui })
		TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 0.15 }):Play()
		-- the crate shakes, then bursts
		local crateIcon = make("Frame", { Size = UDim2.new(0, 220, 0, 220), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), BackgroundTransparency = 1, ZIndex = 151, Parent = overlay })
		if not uiIcon("crate", { Size = UDim2.new(1, 0, 1, 0), ZIndex = 152, Parent = crateIcon }) then
			make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 80, 255), ZIndex = 152, Parent = crateIcon }, { corner(30), stroke(INK, 4) })
		end
		for k = 1, 8 do
			TweenService:Create(crateIcon, TweenInfo.new(0.07), { Rotation = if k % 2 == 0 then 10 else -10, Size = UDim2.new(0, 220 + k * 6, 0, 220 + k * 6) }):Play()
			task.wait(0.08)
		end
		playSfx(Config.Sounds.Rebirth, 0.6)
		local flash = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, ZIndex = 170, Parent = overlay })
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		crateIcon:Destroy()

		local best = got[1]
		for _, key in got do
			if Items.chance(key) > Items.chance(best) then
				best = key
			end
		end
		local perRow = 5
		local rows = math.ceil(#got / perRow)
		local cell = math.clamp(math.floor(520 / math.max(rows, 2)), 80, 150)
		local grid = make("Frame", {
			Size = UDim2.new(0, perRow * (cell + 10), 0, rows * (cell + 34)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.46, 0),
			BackgroundTransparency = 1, ZIndex = 151, Parent = overlay,
		})
		make("UIGridLayout", { CellSize = UDim2.new(0, cell, 0, cell + 24), CellPadding = UDim2.new(0, 10, 0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		titleText(overlay, t("crateGot"), { Size = UDim2.new(0.6, 0, 0, 50), Position = UDim2.new(0.2, 0, 0.06, 0), TextColor3 = Color3.fromRGB(255, 220, 80), Max = 44, ZIndex = 160 })
		for i, key in got do
			local star, mutation = Items.parse(key)
			if star then
				local card = make("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(30, 22, 64), ZIndex = 152, Parent = grid }, { corner(12) })
				if key == best then
					rgbStroke(card, 4)
				else
					stroke(INK, 2.5).Parent = card
				end
				local scale = make("UIScale", { Scale = 0, Parent = card })
				starIcon(star, mutation, { Size = UDim2.new(0, cell - 16, 0, cell - 16), Position = UDim2.new(0, 8, 0, 6), ZIndex = 153, Parent = card })
				titleText(card, t("oneIn", Format.number(Items.chance(key))), { Size = UDim2.new(1, -6, 0, 22), Position = UDim2.new(0, 3, 1, -26), Max = 16, ZIndex = 154, TextColor3 = if key == best then Color3.fromRGB(255, 220, 80) else WHITE })
				task.delay(i * 0.08, function()
					TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end)
			end
		end
		text({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.92, 0), Text = t("tapToClose"), TextColor3 = MUTED, Max = 18, ZIndex = 160, Parent = overlay })
		local closing = false
		overlay.Activated:Connect(function()
			if closing then
				return
			end
			closing = true
			TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			overlay:Destroy()
		end)
		local _ = best
	end

	CrateEv.OnClientEvent:Connect(function(got)
		if type(got) ~= "table" or #got == 0 then
			return
		end
		lastCrate = got
		local best = got[1]
		for _, key in got do
			if Items.chance(key) > Items.chance(best) then
				best = key
			end
		end
		shopW.frame.Visible = false
		if wantsReveal(Items.chance(best)) then
			bigReveal(best, Items.chance(best), nil, Items.chance(best) >= Config.UltraRevealChance)
			task.delay(if Items.chance(best) >= Config.UltraRevealChance then 12 else 6, function()
				showCrateResults(got)
			end)
		else
			task.spawn(showCrateResults, got)
		end
	end)

	OpenWindowEv.OnClientEvent:Connect(function(name: string, info)
		if name == "forge" then
			open(forgeW, true)
		elseif name == "hole" then
			open(holeW, true)
		elseif name == "elevator" and type(info) == "table" then
			elevatorInfo = info
			open(elevatorW, true)
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
end

---------------------------------------------------------------- World text, prompts, location windows (2x a second)
do
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
					label.Text = if owner ~= "" then t("signPlot", owner, Format.number(label:GetAttribute("Income") or 0)) .. "\n" .. t("likesShort", label:GetAttribute("Likes") or 0) else t("signFree")
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
					local ownerId = plotFolder and plotFolder:GetAttribute("OwnerId") or 0
					if prompt:GetAttribute("NotOwner") then
						prompt.Enabled = ownerId ~= 0 and ownerId ~= player.UserId -- likes: only other people's museums
					else
						prompt.Enabled = ownerId == player.UserId
					end
				end
			end
			-- crate ring at spawn: walking in opens the crate shop
			local crateZone = CollectionService:GetTagged("CrateZone")[1]
			if crateZone and crateZone:IsA("BasePart") then
				local d = distanceTo(crateZone)
				if d < 9 and not crateInZone then
					crateInZone = true
					if state and not buildMode then
						shopTab = "featured"
						open(shopW, true)
					end
				elseif d > 14 and crateInZone then
					crateInZone = false
				end
			end
			-- daily chest zone
			local chest = CollectionService:GetTagged("DailyChest")[1]
			local chestBody = chest and chest:FindFirstChild("Body")
			if chestBody then
				local d = distanceTo(chestBody)
				if d < 10 and not dailyInZone then
					dailyInZone = true
					setLid(true)
					if state then
						open(dailyW, true)
					end
				elseif d > 16 and dailyInZone then
					dailyInZone = false
					setLid(false)
					dailyW.frame.Visible = false
				end
			end
			if dailyW.frame.Visible and dailyButton and state then
				local now = workspace:GetServerTimeNow()
				local _, ready = dailyNext(now)
				if not ready then
					dailyButton.Text = t("dailyWait", Format.time(Config.DailyCooldown - (now - (state.daily and state.daily.last or 0))))
				end
			end
			updateTutorial()

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
			-- star shower + bought boosts with their timers
			local banner = {}
			if remaining > 0 then
				table.insert(banner, t("shower", Config.ShowerLuck, Format.time(remaining)))
			end
			local now = workspace:GetServerTimeNow()
			if state and (state.boostLuckUntil or 0) > now then
				table.insert(banner, t("luckActive", Format.time(state.boostLuckUntil - now)))
			end
			if state and (state.boostSpeedUntil or 0) > now then
				table.insert(banner, t("speedActive", Format.time(state.boostSpeedUntil - now)))
			end
			showerBanner.Text = table.concat(banner, "   ·   ")
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
end

---------------------------------------------------------------- Rarest find over every player's head
do
	local headTags: { [Player]: { gui: BillboardGui, label: TextLabel, best: string? } } = {}
	task.spawn(function()
		while true do
			for _, other in Players:GetPlayers() do
				local character = other.Character
				local head = character and character:FindFirstChild("Head")
				local best = other:GetAttribute("Best")
				local tag = headTags[other]
				if head and type(best) == "string" and best ~= "" then
					if not tag or tag.gui.Adornee ~= head then
						if tag then
							tag.gui:Destroy()
						end
						local billboard = make("BillboardGui", {
							Adornee = head, Size = UDim2.new(5, 0, 0.55, 0), StudsOffset = Vector3.new(0, 2.2, 0), MaxDistance = 60,
							LightInfluence = 0, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui"),
						})
						tag = { gui = billboard, label = text({ Size = UDim2.new(1, 0, 1, 0), Text = "", FontFace = TITLE, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 14, Parent = billboard }), best = nil }
						headTags[other] = tag
					end
					if tag.best ~= best .. lang .. tostring(other:GetAttribute("VIP")) then
						local star = Items.parse(best)
						tag.label.Text = (if other:GetAttribute("VIP") then "[VIP] " else "") .. Lang.item(lang, best) .. "  " .. t("oneIn", Format.number(Items.chance(best)))
						tag.label.TextColor3 = if star then star.color:Lerp(WHITE, 0.2) else WHITE
						tag.best = best .. lang .. tostring(other:GetAttribute("VIP"))
					end
				elseif tag then
					tag.gui:Destroy()
					headTags[other] = nil
				end
			end
			for other, tag in headTags do
				if not other.Parent then
					tag.gui:Destroy()
					headTags[other] = nil
				end
			end
			task.wait(1)
		end
	end)
end

---------------------------------------------------------------- Black Hole island: orbit + falling meteors (client-side = smooth)
do
	local orbits = {}
	local function trackOrbit(model: Instance)
		if model:IsA("Model") then
			orbits[model] = { center = model:GetAttribute("Center"), angle = math.random() * 6 }
		end
	end
	for _, model in CollectionService:GetTagged("Orbit") do
		trackOrbit(model)
	end
	CollectionService:GetInstanceAddedSignal("Orbit"):Connect(trackOrbit)
	RunService.RenderStepped:Connect(function(dt)
		for model, info in orbits do
			if model.Parent and typeof(info.center) == "Vector3" then
				info.angle += dt * 0.35
				model:PivotTo(CFrame.new(info.center) * CFrame.Angles(math.rad(12), info.angle, 0))
			else
				orbits[model] = nil
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(math.random(25, 50) / 10)
			local target = CollectionService:GetTagged("MeteorTarget")[1]
			if target and target:IsA("BasePart") and workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position - target.Position).Magnitude < 400 then
				local a = math.random() * math.pi * 2
				local start = target.Position + Vector3.new(math.cos(a) * 110, math.random(50, 90), math.sin(a) * 110)
				local meteor = make("Part", {
					Shape = Enum.PartType.Ball, Size = Vector3.one * (2 + math.random() * 1.5), CFrame = CFrame.new(start), Anchored = true,
					CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Basalt, Color = Color3.fromRGB(60, 40, 40), Parent = workspace,
				})
				make("Fire", { Heat = 15, Size = 8, Color = Color3.fromRGB(255, 120, 40), SecondaryColor = Color3.fromRGB(255, 230, 140), Parent = meteor })
				local a0 = make("Attachment", { Position = Vector3.new(0, 1, 0), Parent = meteor })
				local a1 = make("Attachment", { Position = Vector3.new(0, -1, 0), Parent = meteor })
				make("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 1.2, LightEmission = 1, FaceCamera = true, WidthScale = NumberSequence.new(1, 0),
					Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 40)), Transparency = NumberSequence.new(0, 1), Parent = meteor })
				local flight = TweenService:Create(meteor, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = target.CFrame })
				flight:Play()
				flight.Completed:Connect(function()
					local burst = make("ParticleEmitter", {
						Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(176, 110, 255)),
						LightEmission = 1, Lifetime = NumberRange.new(0.6, 1.4), Speed = NumberRange.new(15, 30), SpreadAngle = Vector2.new(180, 180), Rate = 0,
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = meteor,
					})
					meteor.Transparency = 1
					for _, child in meteor:GetChildren() do
						if child:IsA("Fire") then
							child.Enabled = false
						end
					end
					burst:Emit(60)
					task.delay(2, function()
						meteor:Destroy()
					end)
				end)
			end
		end
	end)
end

---------------------------------------------------------------- Spinning star models on plots
do
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
end

---------------------------------------------------------------- Pets: little planets orbiting every player
do
	local folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace
	local views: { [Player]: { attr: string, models: { Model } } } = {}

	local function part(props)
		props.Anchored = true
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		props.CastShadow = false
		return make("Part", props)
	end

	-- about a third of a museum star: a glowing core in a glass shell, rings and sparkles for mutated ones
	local function petModel(key: string): Model?
		local star, mutation = Items.parse(key)
		if not star then
			return nil
		end
		local model = Instance.new("Model")
		model.Name = key
		local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Material = Enum.Material.Neon, Color = star.color, Parent = model })
		part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Material = Enum.Material.Glass, Color = star.color:Lerp(Color3.new(1, 1, 1), 0.35), Transparency = 0.55, Parent = model })
		make("PointLight", { Color = star.color, Range = 6, Brightness = 0.8, Parent = core })
		if mutation.index >= 2 then
			make("ParticleEmitter", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(mutation.color), LightEmission = 1,
				Rate = 6, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.25, 0), Parent = core,
			})
		end
		if mutation.index >= 3 then -- Golden and up get a planet ring
			part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 2.3, 2.3), CFrame = CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(25), 0, 0), Material = Enum.Material.Neon, Color = mutation.color, Transparency = 0.25, Parent = model })
		end
		model.PrimaryPart = core
		model.Parent = folder
		return model
	end

	local function rebuild(other: Player, attr: string)
		local view = views[other]
		if view then
			for _, model in view.models do
				model:Destroy()
			end
		end
		view = { attr = attr, models = {} }
		views[other] = view
		for key in string.gmatch(attr, "[^,]+") do
			local model = petModel(key)
			if model then
				table.insert(view.models, model)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(other)
		local view = views[other]
		if view then
			for _, model in view.models do
				model:Destroy()
			end
			views[other] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, other in Players:GetPlayers() do
			local attr = other:GetAttribute("Pets") or ""
			local view = views[other]
			if not view or view.attr ~= attr then
				rebuild(other, attr)
				view = views[other]
			end
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local count = #view.models
			for i, model in view.models do
				if root then
					local a = now * 1.2 + (i - 1) / count * math.pi * 2
					local pos = root.Position + Vector3.new(math.cos(a) * 3.4, 1.6 + math.sin(now * 2.2 + i) * 0.35, math.sin(a) * 3.4)
					model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, now * 2, 0))
				else
					model:PivotTo(CFrame.new(0, -500, 0))
				end
			end
		end
	end)
end

---------------------------------------------------------------- Expeditions (window opened at the launch pad)
do
	local expeditionW = window("expTitle", "center", { Size = UDim2.new(0.42, 0, 0.66, 0), Position = UDim2.new(0.29, 0, 0.16, 0) })
	if uiIcon("expedition", { Size = UDim2.new(0, 72, 0, 72), Position = UDim2.new(0, -18, 0, -86), Rotation = -8, ZIndex = 27, Parent = expeditionW.frame }) then
		expeditionW.title.Position = UDim2.new(0, 60, 0, -62)
		expeditionW.title.Size = UDim2.new(1, -136, 0, 50)
	end
	local picked: { string } = {}
	local hours = Config.Expedition.hours[1]
	local timerLabel: TextLabel? = nil
	local claimButton: TextButton? = nil

	local function tripSeconds(h: number): number
		return if RunService:IsStudio() then h * Config.Expedition.studioSecondsPerHour else h * 3600
	end

	local function title(parent: Instance, value: string, order: number, color: Color3?, size: number?)
		local label = text({ Size = UDim2.new(1, -8, 0, size or 30), LayoutOrder = order, Text = value, FontFace = TITLE, TextColor3 = color or WHITE, TextWrapped = true, Max = 20, ZIndex = 22, Parent = parent })
		make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
		return label
	end

	local function iconRow(parent: Instance, order: number, keys: { string }, onTap)
		local strip = make("Frame", { Size = UDim2.new(1, -8, 0, 70), LayoutOrder = order, BackgroundTransparency = 1, ZIndex = 22, Parent = parent })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = strip })
		for i = 1, Config.Expedition.maxStars do
			local key = keys[i]
			local slot = make("TextButton", { Size = UDim2.new(0, 64, 0, 64), LayoutOrder = i, Text = "", AutoButtonColor = onTap ~= nil, BackgroundColor3 = Color3.fromRGB(30, 40, 80), ZIndex = 23, Parent = strip }, {
				make("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(if key then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(70, 80, 120), 2.5),
			})
			local star, mutation = Items.parse(key)
			if star then
				starIcon(star, mutation, { Size = UDim2.new(0.86, 0, 0.86, 0), Position = UDim2.new(0.07, 0, 0.07, 0), ZIndex = 24, Parent = slot })
				if onTap then
					slot.Activated:Connect(function()
						onTap(i)
					end)
				end
			end
		end
	end

	renderers[expeditionW] = function()
		local body = expeditionW.body
		clear(body)
		body.BackgroundColor3 = Color3.fromRGB(24, 32, 66)
		timerLabel, claimButton = nil, nil
		local trip = state and state.expedition
		if trip then
			title(body, t("expAway"), 1, Color3.fromRGB(150, 210, 255))
			iconRow(body, 2, trip.items, nil)
			timerLabel = title(body, "", 3, GOLD, 40)
			local controls = make("Frame", { Size = UDim2.new(1, -8, 0, 54), LayoutOrder = 4, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
			claimButton = btn(GREY, { Size = UDim2.new(0.48, 0, 1, 0), Text = t("expClaim"), Max = 22, ZIndex = 23, Parent = controls }, function()
				ActionEv:FireServer("ExpeditionClaim")
			end)
			btn(RED, { Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), Text = t("expCancel"), Max = 16, ZIndex = 23, Parent = controls }, function()
				ActionEv:FireServer("ExpeditionCancel")
			end)
			return
		end

		title(body, t("expHint", Config.Expedition.maxStars), 1, Color3.fromRGB(200, 215, 255), 44)
		-- how long
		local hoursRow = make("Frame", { Size = UDim2.new(1, -8, 0, 48), LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 22, Parent = body })
		make("UIGridLayout", { CellSize = UDim2.new(1 / #Config.Expedition.hours, -6, 1, 0), CellPadding = UDim2.new(0, 6, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = hoursRow })
		for i, h in Config.Expedition.hours do
			btn(if h == hours then Color3.fromRGB(80, 160, 255) else Color3.fromRGB(80, 88, 120), { LayoutOrder = i, Text = t("expHours", h), Max = 20, ZIndex = 23, Parent = hoursRow }, function()
				hours = h
				renderers[expeditionW]()
			end)
		end
		-- picked stars (tap to remove)
		title(body, t("expPick", #picked, Config.Expedition.maxStars), 3, WHITE, 26)
		iconRow(body, 4, picked, function(i)
			table.remove(picked, i)
			renderers[expeditionW]()
		end)
		local income = 0
		for _, key in picked do
			income += Items.income(key)
		end
		title(body, t("expEstimate", Format.number(math.floor(income * hours * 3600 * Config.Expedition.cashFactor))), 5, Color3.fromRGB(120, 255, 140), 26)
		btn(if #picked > 0 then Color3.fromRGB(70, 200, 90) else GREY, { Size = UDim2.new(1, -8, 0, 54), LayoutOrder = 6, Text = t("expStart"), Max = 24, ZIndex = 22, Parent = body }, function()
			if #picked > 0 then
				ActionEv:FireServer("ExpeditionStart", picked, hours)
				picked = {}
			end
		end)
		-- your stars
		local used = {}
		for _, key in picked do
			used[key] = (used[key] or 0) + 1
		end
		for order, key in sortedInventory() do
			local left = (state.inventory[key] or 0) - (used[key] or 0)
			if left > 0 then
				itemRow(body, 10 + order, key, "x" .. left .. "   " .. t("perSecShort", Format.number(Items.income(key)))).Activated:Connect(function()
					if #picked < Config.Expedition.maxStars then
						table.insert(picked, key)
						renderers[expeditionW]()
					end
				end)
			end
		end
	end

	OpenWindowEv.OnClientEvent:Connect(function(name: string)
		if name == "expedition" then
			picked = {}
			open(expeditionW, true)
		end
	end)

	-- countdown + close when walking away
	task.spawn(function()
		while true do
			task.wait(0.5)
			local trip = state and state.expedition
			if timerLabel and timerLabel.Parent and trip then
				local left = trip.start + tripSeconds(trip.hours) - workspace:GetServerTimeNow()
				timerLabel.Text = if left <= 0 then t("expReady") else t("expLeft", Format.time(math.ceil(left)))
				if claimButton then
					claimButton.BackgroundColor3 = if left <= 0 then Color3.fromRGB(70, 200, 90) else GREY
				end
			end
			if expeditionW.frame.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local pad = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Hub") and workspace.Map.Hub:FindFirstChild("LaunchPad")
				if root and pad and (root.Position - pad.Position).Magnitude > Config.Expedition.reach + 8 then
					expeditionW.frame.Visible = false
				end
			end
		end
	end)
end

---------------------------------------------------------------- Star Union portal (everyone fills it together -> x3 luck for the server)
do
	local unionW = window("unionTitle", "center", { Size = UDim2.new(0.42, 0, 0.66, 0), Position = UDim2.new(0.29, 0, 0.16, 0) })
	if uiIcon("union", { Size = UDim2.new(0, 72, 0, 72), Position = UDim2.new(0, -18, 0, -86), Rotation = -8, ZIndex = 27, Parent = unionW.frame }) then
		unionW.title.Position = UDim2.new(0, 60, 0, -62)
		unionW.title.Size = UDim2.new(1, -136, 0, 50)
	end
	local meterFill: Frame? = nil
	local meterText: TextLabel? = nil

	local function updateMeter()
		if not meterFill or not meterFill.Parent or not meterText then
			return
		end
		local now = workspace:GetServerTimeNow()
		local points = ReplicatedStorage:GetAttribute("UnionPoints") or 0
		local target = math.max(1, ReplicatedStorage:GetAttribute("UnionTarget") or 1)
		local endsAt = ReplicatedStorage:GetAttribute("UnionEndsAt") or 0
		local readyAt = ReplicatedStorage:GetAttribute("UnionReadyAt") or 0
		if now < endsAt then
			meterFill.Size = UDim2.new(1, 0, 1, 0)
			meterText.Text = t("unionActive", Config.Union.luck, Format.time(math.ceil(endsAt - now)))
		elseif now < readyAt then
			meterFill.Size = UDim2.new(0, 0, 1, 0)
			meterText.Text = t("unionResting", Format.time(math.ceil(readyAt - now)))
		else
			meterFill.Size = UDim2.new(math.clamp(points / target, 0, 1), 0, 1, 0)
			meterText.Text = points .. " / " .. target
		end
	end

	renderers[unionW] = function()
		local body = unionW.body
		clear(body)
		body.BackgroundColor3 = Color3.fromRGB(34, 22, 66)
		local hint = text({ Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Text = t("unionHint", Config.Union.luck, Format.time(Config.Union.duration)), TextColor3 = Color3.fromRGB(215, 200, 255), FontFace = BODY_SEMI, TextWrapped = true, Max = 15, ZIndex = 21, Parent = body })
		hint.TextXAlignment = Enum.TextXAlignment.Left
		local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(20, 12, 40), ZIndex = 21, Parent = body }, { corner(12), stroke(Color3.fromRGB(200, 130, 255), 3) })
		meterFill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 22, Parent = bar }, {
			corner(12), make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 80, 255), Color3.fromRGB(255, 120, 220)) }),
		})
		meterText = text({ Size = UDim2.new(1, 0, 1, 0), Text = "", FontFace = TITLE, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0, Max = 20, ZIndex = 23, Parent = bar })
		updateMeter()
		-- your stars: tap = 1, ALL = every copy
		for order, key in sortedInventory() do
			local r = itemRow(body, 10 + order, key, t("unionPoints", Config.UnionPoints(Items.chance(key))))
			r.Activated:Connect(function()
				ActionEv:FireServer("UnionGive", key, 1)
			end)
			btn(Color3.fromRGB(200, 90, 230), { Size = UDim2.new(0, 70, 0, 36), Position = UDim2.new(1, -140, 0, 11), Text = t("unionAll"), Max = 15, ZIndex = 23, Parent = r }, function()
				ActionEv:FireServer("UnionGive", key, state.inventory[key] or 0)
			end)
		end
	end

	OpenWindowEv.OnClientEvent:Connect(function(name: string)
		if name == "union" then
			open(unionW, true)
		end
	end)
	for _, attr in { "UnionPoints", "UnionTarget", "UnionEndsAt", "UnionReadyAt" } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(updateMeter)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			updateMeter()
			if unionW.frame.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude > 44 then
					unionW.frame.Visible = false
				end
			end
		end
	end)
end
