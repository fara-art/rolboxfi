-- Builds the map at runtime and renders every player's sky above their plot.
-- Look: old brass observatory floating in deep space. Dark stone, brass trim, warm light.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Sky = require(Shared.Sky)
local Evolution = require(Shared.Evolution)
local Format = require(Shared.Format)

local World = {}

local PLOT_COUNT = 8
local HUB_RADIUS = 70
local PLOT_RING = 140
local PLOT_SIZE = 56
local CELL = 5
local SKY_HEIGHT = 22

local STONE = Color3.fromRGB(38, 40, 52)
local STONE_DARK = Color3.fromRGB(24, 25, 34)
local BRASS = Color3.fromRGB(201, 162, 92)
local PARCHMENT = Color3.fromRGB(236, 226, 200)

local plots = {}
local playerPlot: { [Player]: number } = {}

local function make(className: string, props)
	local inst = Instance.new(className)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
	end
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function cylinder(cf: CFrame, height: number, diameter: number, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cf * CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis is X, stand it up
	return make("Part", props)
end

local function sign(adornee: BasePart, text: string, offset: number, width: number)
	local gui = make("BillboardGui", {
		Size = UDim2.new(0, width, 0, 50),
		StudsOffset = Vector3.new(0, offset, 0),
		MaxDistance = 220,
		LightInfluence = 0,
		Parent = adornee,
	})
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = PARCHMENT,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.3,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = gui,
	})
end

local function prompt(parent: BasePart, name: string, action: string, object: string)
	return make("ProximityPrompt", {
		Name = name,
		ActionText = action,
		ObjectText = object,
		HoldDuration = 0,
		MaxActivationDistance = 14,
		RequiresLineOfSight = false,
		Parent = parent,
	})
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(45, 45, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 105)
	Lighting.EnvironmentDiffuseScale = 0.3
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("BloomEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	make("Sky", { StarCount = 8000, CelestialBodiesShown = false, Parent = Lighting })
	make("BloomEffect", { Intensity = 0.8, Size = 28, Threshold = 0.95, Parent = Lighting })
end

local function buildHub(folder: Folder)
	cylinder(CFrame.new(0, -2, 0), 4, HUB_RADIUS * 2, { Name = "Floor", Material = Enum.Material.Slate, Color = STONE, Parent = folder })
	cylinder(CFrame.new(0, -2.3, 0), 3.4, HUB_RADIUS * 2 + 2, { Name = "Trim", Material = Enum.Material.Metal, Color = BRASS, Parent = folder })
	-- inner ring of darker stone, like a star chart
	cylinder(CFrame.new(0, 0.05, 0), 0.2, 44, { Name = "Inlay", Material = Enum.Material.Slate, Color = STONE_DARK, CanCollide = false, Parent = folder })
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		make("Part", {
			Name = "Ray",
			Size = Vector3.new(0.4, 0.22, 20),
			CFrame = CFrame.new(math.cos(angle) * 12, 0.06, math.sin(angle) * 12) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			Material = Enum.Material.Metal,
			Color = BRASS,
			CanCollide = false,
			Parent = folder,
		})
	end

	-- Black Hole above the center + altar to feed it
	local hole = make("Part", {
		Name = "BlackHole",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(22, 22, 22),
		CFrame = CFrame.new(0, 38, 0),
		Color = Color3.new(0, 0, 0),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = folder,
	})
	make("PointLight", { Color = Color3.fromRGB(255, 140, 60), Range = 50, Brightness = 2, Parent = hole })
	local disk = cylinder(CFrame.new(0, 38, 0) * CFrame.Angles(math.rad(18), 0, 0), 0.4, 54, {
		Name = "AccretionDisk",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 120, 40),
		Transparency = 0.35,
		CanCollide = false,
		Parent = folder,
	})
	make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 90), Color3.fromRGB(120, 40, 20)),
		LightEmission = 1,
		Rate = 40,
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(0.5, 2),
		Size = NumberSequence.new(0.6, 0),
		Parent = disk,
	})
	local altar = cylinder(CFrame.new(0, 1.5, -24), 3, 9, { Name = "Altar", Material = Enum.Material.Basalt, Color = STONE_DARK, Parent = folder })
	cylinder(CFrame.new(0, 3.1, -24), 0.3, 7, { Name = "AltarTop", Material = Enum.Material.Metal, Color = BRASS, Parent = folder })
	prompt(altar, "BlackHolePrompt", "Open", "Black Hole")
	sign(altar, "BLACK HOLE", 6, 220)

	-- Star Forge
	local forge = make("Part", {
		Name = "Forge",
		Size = Vector3.new(10, 4, 7),
		CFrame = CFrame.new(42, 2, 0),
		Material = Enum.Material.Basalt,
		Color = STONE_DARK,
		Parent = folder,
	})
	make("Part", { Name = "Anvil", Size = Vector3.new(7, 1.6, 3), CFrame = CFrame.new(42, 4.8, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 78), Parent = folder })
	local ember = make("Part", { Name = "Ember", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(42, 4.5, 5), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 110, 30), Parent = folder })
	make("Fire", { Heat = 6, Size = 4, Color = Color3.fromRGB(255, 120, 40), SecondaryColor = Color3.fromRGB(255, 220, 120), Parent = ember })
	make("PointLight", { Color = Color3.fromRGB(255, 130, 50), Range = 20, Brightness = 2, Parent = ember })
	prompt(forge, "ForgePrompt", "Use", "Star Forge")
	sign(forge, "STAR FORGE", 7, 220)

	-- Observatory
	local dome = make("Part", {
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(28, 28, 28),
		CFrame = CFrame.new(-42, 0, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 120, 75),
		Parent = folder,
	})
	make("Part", {
		Name = "Telescope",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(18, 3, 3),
		CFrame = CFrame.new(-36, 16, 0) * CFrame.Angles(0, 0, math.rad(40)),
		Material = Enum.Material.Metal,
		Color = BRASS,
		Parent = folder,
	})
	prompt(dome, "ObservatoryPrompt", "Read", "Constellation Book")
	sign(dome, "OBSERVATORY", 18, 240)

	-- brass lamp posts around the edge
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local base = Vector3.new(math.cos(angle) * (HUB_RADIUS - 4), 0, math.sin(angle) * (HUB_RADIUS - 4))
		make("Part", { Name = "Post", Size = Vector3.new(0.8, 9, 0.8), CFrame = CFrame.new(base + Vector3.new(0, 4.5, 0)), Material = Enum.Material.Metal, Color = BRASS, Parent = folder })
		local lamp = make("Part", { Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(base + Vector3.new(0, 9.5, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 214, 150), CanCollide = false, Parent = folder })
		make("PointLight", { Color = Color3.fromRGB(255, 200, 140), Range = 18, Brightness = 1.2, Parent = lamp })
	end
end

local function buildPlot(index: number, folder: Folder)
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local center = direction * PLOT_RING
	local plotCF = CFrame.lookAt(center, Vector3.zero) -- faces the hub

	local plotFolder = make("Folder", { Name = "Plot" .. index, Parent = folder })
	make("Part", { Name = "Floor", Size = Vector3.new(PLOT_SIZE, 4, PLOT_SIZE), CFrame = plotCF * CFrame.new(0, -2, 0), Material = Enum.Material.Slate, Color = STONE, Parent = plotFolder })
	make("Part", { Name = "Trim", Size = Vector3.new(PLOT_SIZE + 2, 3.4, PLOT_SIZE + 2), CFrame = plotCF * CFrame.new(0, -2.3, 0), Material = Enum.Material.Metal, Color = BRASS, Parent = plotFolder })

	-- bridge to the hub
	local from = HUB_RADIUS - 2
	local to = PLOT_RING - PLOT_SIZE / 2 + 2
	local length = to - from
	local bridgeCF = CFrame.lookAt(direction * (from + to) / 2 + Vector3.new(0, -0.5, 0), Vector3.new(0, -0.5, 0))
	make("Part", { Name = "Bridge", Size = Vector3.new(10, 1, length), CFrame = bridgeCF, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(92, 66, 46), Parent = plotFolder })
	for _, side in { -5.2, 5.2 } do
		make("Part", { Name = "Rail", Size = Vector3.new(0.4, 2.4, length), CFrame = bridgeCF * CFrame.new(side, 1.7, 0), Material = Enum.Material.Metal, Color = BRASS, Parent = plotFolder })
	end

	-- name sign at the entrance
	local post = make("Part", {
		Name = "SignPost",
		Size = Vector3.new(1, 6, 1),
		CFrame = plotCF * CFrame.new(-7, 3, -(PLOT_SIZE / 2 - 3)),
		Material = Enum.Material.Metal,
		Color = BRASS,
		Parent = plotFolder,
	})
	local label = sign(post, "Empty Sky", 5, 320)

	plots[index] = {
		cf = plotCF,
		display = make("Folder", { Name = "Sky", Parent = plotFolder }),
		label = label,
		owner = nil,
	}
end

function World.build()
	setupLighting()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local map = make("Folder", { Name = "Map", Parent = workspace })
	buildHub(make("Folder", { Name = "Hub", Parent = map }))
	local plotFolder = make("Folder", { Name = "Plots", Parent = map })
	for i = 1, PLOT_COUNT do
		buildPlot(i, plotFolder)
	end
end

function World.assignPlot(player: Player): number?
	for index, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			playerPlot[player] = index
			plot.label.Text = player.DisplayName .. "'s Sky"
			return index
		end
	end
	return nil
end

function World.releasePlot(player: Player)
	local index = playerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	plot.owner = nil
	plot.display:ClearAllChildren()
	plot.label.Text = "Empty Sky"
	playerPlot[player] = nil
end

function World.spawnCFrame(player: Player): CFrame?
	local index = playerPlot[player]
	if not index then
		return nil
	end
	local position = (plots[index].cf * CFrame.new(0, 4, -10)).Position
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local NEIGHBORS = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } }

function World.renderPlot(player: Player, data, evaluation, income: number)
	local index = playerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	local display = plot.display
	display:ClearAllChildren()
	plot.label.Text = string.format("%s's Sky   +%s/s", player.DisplayName, Format.number(income))

	local size = data.gridSize
	local half = (size + 1) / 2
	local function cellPosition(x: number, y: number): Vector3
		return (plot.cf * CFrame.new((x - half) * CELL, SKY_HEIGHT, (y - half) * CELL)).Position
	end

	-- faint brass frame marking the sky area
	make("Part", {
		Name = "Frame",
		Size = Vector3.new(size * CELL, 0.15, size * CELL),
		CFrame = plot.cf * CFrame.new(0, SKY_HEIGHT - 4, 0),
		Material = Enum.Material.Neon,
		Color = BRASS,
		Transparency = 0.9,
		CanCollide = false,
		CastShadow = false,
		Parent = display,
	})

	for key, cell in data.grid do
		local x, y = Sky.parse(key)
		local star, mutation = Items.parse(cell.id)
		if x and y and star and x <= size and y <= size then
			local level = Evolution.level(cell.age or 0)
			local diameter = 1.1 + star.index * 0.3 + (level - 1) * 0.15
			local ball = make("Part", {
				Name = key,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(diameter, diameter, diameter),
				CFrame = CFrame.new(cellPosition(x, y)),
				Material = Enum.Material.Neon,
				Color = star.color,
				CanCollide = false,
				CastShadow = false,
				Parent = display,
			})
			if mutation.id ~= "normal" then
				make("Sparkles", { SparkleColor = mutation.color, Parent = ball })
			end
			if star.index >= 5 then
				make("PointLight", { Color = star.color, Range = 10, Brightness = 1.5, Parent = ball })
			end
		end
	end

	-- constellation lines
	for _, group in evaluation.groups do
		local members = {}
		for _, key in group.cells do
			members[key] = true
		end
		local color = if group.pure then Color3.fromRGB(150, 230, 255) else BRASS
		for _, key in group.cells do
			local x, y = Sky.parse(key)
			for _, offset in NEIGHBORS do
				local nx, ny = x + offset[1], y + offset[2]
				if members[Sky.key(nx, ny)] then
					local a, b = cellPosition(x, y), cellPosition(nx, ny)
					make("Part", {
						Name = "Line",
						Size = Vector3.new(0.18, 0.18, (b - a).Magnitude),
						CFrame = CFrame.lookAt((a + b) / 2, b),
						Material = Enum.Material.Neon,
						Color = color,
						Transparency = 0.15,
						CanCollide = false,
						CastShadow = false,
						Parent = display,
					})
				end
			end
		end
	end
end

return World
