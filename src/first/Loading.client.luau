-- Custom loading screen (runs before anything else is loaded)
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local LocalizationService = game:GetService("LocalizationService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local russian = string.sub(LocalizationService.RobloxLocaleId, 1, 2) == "ru"
local TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(26, 28, 48)

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

local gui = make("ScreenGui", { Name = "Loading", IgnoreGuiInset = true, DisplayOrder = 1000, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
local bg = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = gui }, {
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(40, 18, 90), Color3.fromRGB(6, 6, 22)), Rotation = 90 }),
})

-- twinkling stars
local rng = Random.new()
for _ = 1, 140 do
	local size = rng:NextInteger(2, 5)
	local dot = make("Frame", {
		Size = UDim2.new(0, size, 0, size), Position = UDim2.new(rng:NextNumber(), 0, rng:NextNumber(), 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = rng:NextNumber(0.2, 0.8), BorderSizePixel = 0, Parent = bg,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	TweenService:Create(dot, TweenInfo.new(rng:NextNumber(0.8, 2.2), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.95 }):Play()
end

-- orbits with planets around a pulsing star
local center = make("Frame", { Size = UDim2.new(0, 360, 0, 360), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0), BackgroundTransparency = 1, Parent = bg })
local orbitColors = { Color3.fromRGB(120, 210, 255), Color3.fromRGB(200, 130, 255), Color3.fromRGB(255, 200, 100) }
for i, color in orbitColors do
	local size = 140 + i * 70
	local ring = make("Frame", { Size = UDim2.new(0, size, 0, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, Rotation = i * 40, Parent = center }, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = color, Thickness = 2, Transparency = 0.4 }),
	})
	make("Frame", { Size = UDim2.new(0, 14 + i * 3, 0, 14 + i * 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = color, Parent = ring }, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = INK, Thickness = 2 }),
	})
	TweenService:Create(ring, TweenInfo.new(4 + i * 2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = ring.Rotation + (if i % 2 == 0 then -360 else 360) }):Play()
end
local core = make("Frame", { Size = UDim2.new(0, 80, 0, 80), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, Parent = center })
for k = 0, 1 do
	make("Frame", { Size = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = k * 45, BackgroundColor3 = Color3.fromRGB(255, 215, 110), Parent = core }, {
		make("UICorner", { CornerRadius = UDim.new(0, 10) }), make("UIStroke", { Color = INK, Thickness = 3 }),
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 250, 210), Color3.fromRGB(255, 170, 40)), Rotation = 90 }),
	})
end
TweenService:Create(core, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.new(0, 100, 0, 100) }):Play()
TweenService:Create(core, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()

-- title
local title = make("TextLabel", {
	Size = UDim2.new(0.8, 0, 0, 110), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.66, 0), BackgroundTransparency = 1, Text = "STAR RNG",
	FontFace = TITLE, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = INK, TextStrokeTransparency = 0, Parent = bg,
}, { make("UITextSizeConstraint", { MaxTextSize = 96 }) })
make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 220)), ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 200, 255)) }), Parent = title })

-- progress bar + tips
local barBack = make("Frame", { Size = UDim2.new(0, 420, 0, 22), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.83, 0), BackgroundColor3 = Color3.fromRGB(30, 26, 60), Parent = bg }, {
	make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = INK, Thickness = 3 }),
})
local barFill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = barBack }, {
	make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(200, 130, 255)) }),
})
local tipsText = make("TextLabel", {
	Size = UDim2.new(0.7, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.88, 0), BackgroundTransparency = 1, Text = "",
	FontFace = TITLE, TextScaled = true, TextColor3 = Color3.fromRGB(210, 210, 240), TextStrokeColor3 = INK, TextStrokeTransparency = 0.3, Parent = bg,
}, { make("UITextSizeConstraint", { MaxTextSize = 22 }) })
local tips = if russian
	then { "Ставь звёзды в музей, чтобы они приносили деньги", "5 одинаковых звёзд в Кузне = звезда получше", "Корми Чёрную дыру и перерождайся ради множителей", "Заходи к сундуку каждый день за наградой", "Самые редкие звёзды видит весь сервер!" }
	else { "Put stars in your museum to earn cash", "5 of the same star at the Forge = a better star", "Feed the Black Hole and rebirth for multipliers", "Visit the daily chest every day", "The rarest finds are shown to the whole server!" }

local started = os.clock()
local shown = 0
local tipIndex = 0
while true do
	if os.clock() - started > tipIndex * 2.5 then
		tipIndex += 1
		tipsText.Text = tips[(tipIndex - 1) % #tips + 1]
	end
	local loaded = game:IsLoaded()
	local queue = ContentProvider.RequestQueueSize
	local target = if loaded then 1 else math.clamp(0.9 - queue / 200, 0.1, 0.9)
	shown += (target - shown) * 0.12
	barFill.Size = UDim2.new(shown, 0, 1, 0)
	if loaded and shown > 0.97 and os.clock() - started > 3 then
		break
	end
	if os.clock() - started > 25 then
		break -- never get stuck on the loading screen
	end
	task.wait(0.05)
end

-- fade everything out
for _, inst in gui:GetDescendants() do
	if inst:IsA("Frame") then
		TweenService:Create(inst, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	elseif inst:IsA("TextLabel") then
		TweenService:Create(inst, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif inst:IsA("UIStroke") then
		TweenService:Create(inst, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end
end
task.wait(0.7)
gui:Destroy()
