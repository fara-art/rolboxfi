-- Builds the sky world at runtime and renders stars on each plot's pedestals.
-- Look: bright heaven. White marble, warm gold trim, soft clouds, pastel trees, glassy blue.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Sky = require(Shared.Sky)
local Evolution = require(Shared.Evolution)
local StarModels = require(script.Parent.StarModels)

local World = {}

-- callbacks set by Main
World.onPlotTouched = nil :: ((Player, number) -> ())?
World.onPedestal = nil :: ((Player, number, string) -> ())?
World.onForge = nil :: ((Player) -> ())?
World.onHole = nil :: ((Player) -> ())?
World.onElevator = nil :: ((Player, number, number, number) -> ())?

local RING = 150 -- distance from hub center to satellite islands
local HUB_RADIUS = 50
local PLOT_SIZE = 64
local SPACING = 7
local STAR_HEIGHT = 4.9 -- above the stand's floor

local MARBLE = Color3.fromRGB(246, 246, 250)
local MARBLE_WARM = Color3.fromRGB(238, 232, 220)
local GOLD = Color3.fromRGB(236, 196, 100)
local GRASS = Color3.fromRGB(146, 214, 140)
local GLASS = Color3.fromRGB(170, 220, 255)
local CLOUD = Color3.fromRGB(255, 255, 255)

local rng = Random.new(20261114)
local plots = {}
local playerPlot: { [Player]: number } = {}
World.ForgePosition = Vector3.zero
World.AltarPosition = Vector3.zero

---------------------------------------------------------------- helpers
local function make(className: string, props)
	local inst = Instance.new(className)
	if props.Shape then
		inst.Shape = props.Shape -- shape first, so it doesn't reset the size
	end
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
	end
	for key, value in props do
		if key ~= "Parent" and key ~= "Shape" then
			inst[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function cylinder(cf: CFrame, height: number, diameter: number, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	return make("Part", props)
end

local function ball(position: Vector3, diameter: number, props)
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = CFrame.new(position)
	return make("Part", props)
end

local function cloudPuff(center: Vector3, size: number, parent: Instance, count: number?)
	for _ = 1, count or 5 do
		local offset = Vector3.new(rng:NextNumber(-1, 1) * size * 0.6, rng:NextNumber(-0.25, 0.25) * size, rng:NextNumber(-1, 1) * size * 0.6)
		ball(center + offset, size * rng:NextNumber(0.5, 0.9), {
			Color = CLOUD, Material = Enum.Material.SmoothPlastic, Transparency = 0.08,
			CanCollide = false, CastShadow = false, Parent = parent,
		})
	end
end

-- Text in the world. Client re-localizes everything tagged WorldText.
local function worldText(adornee: BasePart, langKey: string, offset: number, studsWide: number, studsTall: number?)
	local gui = make("BillboardGui", {
		Size = UDim2.new(studsWide, 0, studsTall or 3, 0),
		StudsOffset = Vector3.new(0, offset, 0),
		MaxDistance = 160,
		AlwaysOnTop = true, -- never hidden inside walls
		LightInfluence = 0,
		Parent = adornee,
	})
	local label = make("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = langKey,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(40, 70, 120),
		TextStrokeTransparency = 0.1,
		TextScaled = true,
		FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
		Parent = gui,
	})
	label:SetAttribute("LangKey", langKey)
	CollectionService:AddTag(label, "WorldText")
	return label
end

local function prompt(parent: BasePart, name: string, langKey: string, objKey: string?, distance: number?)
	local p = make("ProximityPrompt", {
		Name = name,
		ActionText = langKey,
		ObjectText = "",
		HoldDuration = 0,
		MaxActivationDistance = distance or 12,
		RequiresLineOfSight = false,
		Parent = parent,
	})
	p:SetAttribute("LangKey", langKey)
	if objKey then
		p:SetAttribute("ObjKey", objKey)
	end
	CollectionService:AddTag(p, "WorldPrompt")
	return p
end

-- round floating island: marble top, gold rim, clouds hugging the underside
local function roundIsland(center: Vector3, radius: number, parent: Instance, topColor: Color3?, topMaterial: Enum.Material?)
	cylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, radius * 2, { Name = "Floor", Material = topMaterial or Enum.Material.Marble, Color = topColor or MARBLE, Parent = parent })
	cylinder(CFrame.new(center + Vector3.new(0, -2.4, 0)), 3.6, radius * 2 + 2, { Name = "Rim", Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = parent })
	cylinder(CFrame.new(center + Vector3.new(0, -7, 0)), 6, radius * 1.7, { Name = "Base", Material = Enum.Material.Marble, Color = MARBLE_WARM, Parent = parent })
	for _ = 1, math.floor(radius / 4) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius * 0.8)
		cloudPuff(center + Vector3.new(math.cos(a) * r, -11 - rng:NextNumber(0, 4), math.sin(a) * r), rng:NextNumber(10, 18), parent, 3)
	end
end

local function pillar(base: Vector3, height: number, parent: Instance)
	cylinder(CFrame.new(base + Vector3.new(0, 0.6, 0)), 1.2, 4, { Name = "PillarFoot", Material = Enum.Material.Marble, Color = MARBLE, Parent = parent })
	cylinder(CFrame.new(base + Vector3.new(0, height / 2, 0)), height, 2.6, { Name = "Pillar", Material = Enum.Material.Marble, Color = MARBLE, Parent = parent })
	cylinder(CFrame.new(base + Vector3.new(0, height + 0.5, 0)), 1, 3.8, { Name = "PillarCap", Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = parent })
end

local function crystal(position: Vector3, size: number, color: Color3, parent: Instance)
	local c = make("Part", {
		Name = "Crystal",
		Size = Vector3.new(size, size * 1.6, size),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(45), math.rad(45)),
		Material = Enum.Material.Glass,
		Color = color,
		Transparency = 0.2,
		CanCollide = false,
		Parent = parent,
	})
	make("PointLight", { Color = color, Range = size * 4, Brightness = 1, Parent = c })
	return c
end

local FLOWERS = { Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 170, 255) }
local function flowers(center: Vector3, radius: number, count: number, parent: Instance)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(radius * 0.4, radius)
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		make("Part", { Name = "Stem", Size = Vector3.new(0.15, 0.9, 0.15), CFrame = CFrame.new(p + Vector3.new(0, 0.45, 0)), Color = Color3.fromRGB(90, 170, 80), CanCollide = false, CastShadow = false, Parent = parent })
		ball(p + Vector3.new(0, 1, 0), rng:NextNumber(0.6, 0.9), { Name = "Flower", Material = Enum.Material.SmoothPlastic, Color = FLOWERS[rng:NextInteger(1, #FLOWERS)], CanCollide = false, CastShadow = false, Parent = parent })
	end
end

local function tree(base: Vector3, parent: Instance, leafColor: Color3)
	local height = rng:NextNumber(7, 10)
	make("Part", {
		Name = "Trunk", Size = Vector3.new(1.4, height, 1.4), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)),
		Material = Enum.Material.Wood, Color = Color3.fromRGB(235, 228, 214), Parent = parent,
	})
	for _ = 1, 4 do
		ball(base + Vector3.new(rng:NextNumber(-2, 2), height + rng:NextNumber(-1, 2), rng:NextNumber(-2, 2)), rng:NextNumber(5, 7), {
			Name = "Leaves", Material = Enum.Material.SmoothPlastic, Color = leafColor, CanCollide = false, Parent = parent,
		})
	end
end

local WOOD = Color3.fromRGB(166, 112, 70)
local WOOD_DARK = Color3.fromRGB(120, 78, 48)
local BRIDGE_RISE = 6 -- how high the middle of the arch goes

local function bridge(direction: Vector3, from: number, to: number, parent: Instance)
	local length = to - from
	local segments = math.max(8, math.floor(length / 5))
	local side = Vector3.new(-direction.Z, 0, direction.X) -- horizontal, across the bridge
	local function point(t: number): Vector3
		return direction * (from + length * t) + Vector3.new(0, math.sin(math.pi * t) * BRIDGE_RISE, 0)
	end

	for i = 0, segments - 1 do
		local a, b = point(i / segments), point((i + 1) / segments)
		local segLength = (b - a).Magnitude + 0.6 -- small overlap: no gaps or bumps
		local cf = CFrame.lookAt((a + b) / 2, b, Vector3.yAxis)
		-- planks
		make("Part", { Name = "Deck", Size = Vector3.new(11, 1, segLength), CFrame = cf * CFrame.new(0, -0.5, 0), Material = Enum.Material.WoodPlanks, Color = WOOD, Parent = parent })
		-- rails on both sides
		for _, s in { -5.6, 5.6 } do
			make("Part", { Name = "Rail", Size = Vector3.new(0.5, 0.5, segLength), CFrame = cf * CFrame.new(s, 2.6, 0), Material = Enum.Material.Wood, Color = WOOD_DARK, Parent = parent })
		end
	end
	-- posts at every joint, lanterns in the middle
	for i = 0, segments do
		local t = i / segments
		local base = point(t)
		for _, s in { -5.6, 5.6 } do
			local postPos = base + side * s + Vector3.new(0, 1.5, 0)
			make("Part", { Name = "Post", Size = Vector3.new(0.7, 3.4, 0.7), CFrame = CFrame.new(postPos), Material = Enum.Material.Wood, Color = WOOD_DARK, Parent = parent })
			if i == math.floor(segments / 2) then
				local lamp = make("Part", { Name = "Lantern", Size = Vector3.new(1, 1.2, 1), CFrame = CFrame.new(postPos + Vector3.new(0, 2.3, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 214, 150), CanCollide = false, Parent = parent })
				make("PointLight", { Color = Color3.fromRGB(255, 200, 140), Range = 12, Brightness = 1, Parent = lamp })
			end
		end
	end

	-- arch at the hub end
	local archCF = CFrame.lookAt(direction * (from + 2), Vector3.zero)
	for _, side in { -7, 7 } do
		pillar((archCF * CFrame.new(side, 0, 0)).Position, 12, parent)
	end
	make("Part", { Name = "ArchBeam", Size = Vector3.new(17, 1.6, 2.4), CFrame = archCF * CFrame.new(0, 13.4, 0), Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = parent })
	-- cloud tufts under the bridge
	for t = 0.2, 0.8, 0.3 do
		cloudPuff(point(t) + Vector3.new(0, -7, 0), 9, parent, 2)
	end
end

local function directionAt(slot: number): Vector3
	local angle = (slot - 1) / 8 * math.pi * 2
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

---------------------------------------------------------------- atmosphere
local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(150, 170, 200)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 195, 225)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	make("Atmosphere", {
		Density = 0.28, Offset = 0.1,
		Color = Color3.fromRGB(205, 228, 255), Decay = Color3.fromRGB(150, 190, 240),
		Glare = 0.25, Haze = 1.4, Parent = Lighting,
	})
	make("Sky", { CelestialBodiesShown = true, SunAngularSize = 14, StarCount = 0, Parent = Lighting })
	make("BloomEffect", { Intensity = 0.2, Size = 18, Threshold = 2, Parent = Lighting })
	make("SunRaysEffect", { Intensity = 0.06, Spread = 0.8, Parent = Lighting })
	make("ColorCorrectionEffect", { Brightness = 0.03, Contrast = 0.05, Saturation = 0.12, TintColor = Color3.fromRGB(255, 252, 245), Parent = Lighting })

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		make("Clouds", { Cover = 0.55, Density = 0.6, Color = Color3.fromRGB(255, 255, 255), Parent = terrain })
	end
end

---------------------------------------------------------------- hub
local function buildHub(folder: Folder)
	roundIsland(Vector3.zero, HUB_RADIUS, folder)
	-- gold compass inlay
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		make("Part", {
			Name = "Inlay", Size = Vector3.new(0.6, 0.12, 30),
			CFrame = CFrame.new(math.cos(a) * 22, 0.06, math.sin(a) * 22) * CFrame.Angles(0, -a - math.pi / 2, 0),
			Material = Enum.Material.SmoothPlastic, Color = GOLD, CanCollide = false, Parent = folder,
		})
	end

	-- fountain
	cylinder(CFrame.new(0, 1, 0), 2, 26, { Name = "Basin", Material = Enum.Material.Marble, Color = MARBLE, Parent = folder })
	cylinder(CFrame.new(0, 2.05, 0), 0.2, 23, { Name = "Water", Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 200, 255), Transparency = 0.25, CanCollide = false, Parent = folder })
	cylinder(CFrame.new(0, 5, 0), 6, 3, { Name = "Column", Material = Enum.Material.Marble, Color = MARBLE, Parent = folder })
	cylinder(CFrame.new(0, 8.2, 0), 0.8, 9, { Name = "Bowl", Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = folder })
	local orb = ball(Vector3.new(0, 11.5, 0), 4, { Name = "Orb", Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 230, 255), CanCollide = false, Parent = folder })
	make("PointLight", { Color = Color3.fromRGB(170, 230, 255), Range = 24, Brightness = 1.5, Parent = orb })
	make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)), LightEmission = 0.6, Rate = 18,
		Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -8, 0), Size = NumberSequence.new(0.5, 0), Transparency = NumberSequence.new(0.2, 1),
		Parent = orb,
	})
	worldText(orb, "signHub", 6, 22, 4)

	-- pillars with floating crystals between the bridges
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		local base = Vector3.new(math.cos(a) * 43, 0, math.sin(a) * 43)
		if i >= 4 then
			continue -- the leaderboard tablets stand on this half of the edge
		end
		pillar(base, 14, folder)
		crystal(base + Vector3.new(0, 18, 0), 2.2, if i % 2 == 0 then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(190, 255, 220), folder)
	end

	-- drifting golden sparkles above the island
	local air = make("Part", { Name = "AirSparkles", Size = Vector3.new(90, 1, 90), CFrame = CFrame.new(0, 6, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = folder })
	make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), Color3.fromRGB(190, 230, 255)),
		LightEmission = 1, LightInfluence = 0, Rate = 14, Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-40, 40),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Parent = air,
	})

	-- trees
	local leaves = { Color3.fromRGB(255, 205, 225), Color3.fromRGB(190, 240, 205), Color3.fromRGB(255, 230, 190), Color3.fromRGB(215, 205, 255) }
	for i = 1, 4 do
		local a = math.rad(22.5 + (i - 1) * 45)
		local base = Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
		tree(base, folder, leaves[i])
		flowers(base, 5, 10, folder)
	end

	-- stone leaderboard tablets (the client draws the scrollable lists on them)
	local boards = make("Folder", { Name = "Leaderboards", Parent = folder })
	for i, board in { "rolls", "rebirths", "cash", "rarest" } do
		local a = math.rad(202.5 + (i - 1) * 45)
		local pos = Vector3.new(math.cos(a) * 45, 0, math.sin(a) * 45)
		local cf = CFrame.lookAt(pos, Vector3.zero)
		make("Part", { Name = "Step", Size = Vector3.new(10.5, 1.2, 4), CFrame = cf * CFrame.new(0, 0.6, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(118, 120, 132), Parent = folder })
		make("Part", { Name = "Board_" .. board, Size = Vector3.new(9, 12, 1.2), CFrame = cf * CFrame.new(0, 7.2, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(172, 174, 186), Parent = boards })
		make("Part", { Name = "Cap", Size = Vector3.new(10, 0.8, 2), CFrame = cf * CFrame.new(0, 13.6, 0), Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = folder })
		crystal((cf * CFrame.new(0, 15.4, 0)).Position, 1.3, Color3.fromRGB(255, 220, 120), folder)
	end

	-- the spawn plate stays but invisible
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CFrame = CFrame.new(0, 0.5, 20)
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
end

---------------------------------------------------------------- Star Forge house (on the hub, next to spawn)
local function buildForgeHouse(folder: Folder)
	-- front faces the hub center (local -Z)
	local cf = CFrame.lookAt(Vector3.new(0, 0, 33), Vector3.zero)
	local BRICK = Color3.fromRGB(222, 170, 140)
	local ROOF = Color3.fromRGB(96, 150, 232)
	make("Part", { Name = "HouseFloor", Size = Vector3.new(17, 0.4, 15), CFrame = cf * CFrame.new(0, 0.2, 0), Material = Enum.Material.Marble, Color = MARBLE_WARM, Parent = folder })
	make("Part", { Name = "BackWall", Size = Vector3.new(17, 10, 1), CFrame = cf * CFrame.new(0, 5, 7), Material = Enum.Material.Brick, Color = BRICK, Parent = folder })
	for _, side in { -8, 8 } do
		make("Part", { Name = "SideWall", Size = Vector3.new(1, 10, 15), CFrame = cf * CFrame.new(side, 5, 0), Material = Enum.Material.Brick, Color = BRICK, Parent = folder })
		pillar((cf * CFrame.new(side, 0, -7.5)).Position, 10, folder)
	end
	make("Part", { Name = "Ceiling", Size = Vector3.new(19, 1, 17), CFrame = cf * CFrame.new(0, 10.6, 0), Material = Enum.Material.Marble, Color = MARBLE, Parent = folder })
	for _, side in { -1, 1 } do
		make("Part", {
			Name = "Roof", Size = Vector3.new(11, 0.8, 18), CFrame = cf * CFrame.new(side * 4.6, 13.2, 0) * CFrame.Angles(0, 0, math.rad(-28 * side)),
			Material = Enum.Material.SmoothPlastic, Color = ROOF, Parent = folder,
		})
	end
	local chimney = cylinder(cf * CFrame.new(5, 15, 4), 6, 2.4, { Name = "Chimney", Material = Enum.Material.Brick, Color = BRICK, Parent = folder })
	make("Smoke", { Color = Color3.fromRGB(255, 255, 255), Opacity = 0.15, RiseVelocity = 4, Size = 2, Parent = chimney })

	-- furnace at the back
	local furnace = make("Part", { Name = "Furnace", Size = Vector3.new(8, 5, 3), CFrame = cf * CFrame.new(0, 2.5, 5), Material = Enum.Material.Brick, Color = Color3.fromRGB(190, 130, 105), Parent = folder })
	local mouth = make("Part", { Name = "Mouth", Size = Vector3.new(4, 2.2, 0.3), CFrame = furnace.CFrame * CFrame.new(0, -0.8, -1.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 130, 40), Parent = folder })
	make("Fire", { Heat = 4, Size = 3, Color = Color3.fromRGB(255, 140, 50), SecondaryColor = Color3.fromRGB(255, 230, 140), Parent = mouth })
	make("PointLight", { Color = Color3.fromRGB(255, 150, 70), Range = 16, Brightness = 2, Parent = mouth })

	-- forge table in front
	local tableBase = make("Part", { Name = "ForgeTable", Size = Vector3.new(6, 3, 3.5), CFrame = cf * CFrame.new(0, 1.7, -3), Material = Enum.Material.Marble, Color = Color3.fromRGB(125, 125, 140), Parent = folder })
	local anvil = make("Part", { Name = "Anvil", Size = Vector3.new(5, 1.2, 2.2), CFrame = cf * CFrame.new(0, 3.8, -3), Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 84, 96), Parent = folder })
	make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 40)), LightEmission = 1, Rate = 6,
		Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -20, 0), Size = NumberSequence.new(0.25, 0), Parent = anvil,
	})
	local forgePrompt = prompt(tableBase, "ForgePrompt", "promptForge", nil, 12)
	forgePrompt.Triggered:Connect(function(who)
		if World.onForge then
			World.onForge(who)
		end
	end)
	World.ForgePosition = tableBase.Position

	-- banner over the entrance
	local banner = make("Part", { Name = "Banner", Size = Vector3.new(12, 2.4, 0.4), CFrame = cf * CFrame.new(0, 9, -8.3), Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = folder })
	worldText(banner, "signForge", 2.8, 14, 2.6)
end

---------------------------------------------------------------- Black Hole island
local function buildBlackHole(folder: Folder, slot: number)
	local direction = directionAt(slot)
	local center = direction * RING
	World.AltarPosition = center
	roundIsland(center, 34, folder, Color3.fromRGB(42, 34, 58), Enum.Material.Basalt) -- obsidian
	bridge(direction, HUB_RADIUS - 2, RING - 33, folder)

	local holePos = center + Vector3.new(0, 34, 0)
	local hole = ball(holePos, 20, { Name = "BlackHole", Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false, Parent = folder })
	make("PointLight", { Color = Color3.fromRGB(180, 110, 255), Range = 60, Brightness = 3, Parent = hole })
	local disk = cylinder(CFrame.new(holePos) * CFrame.Angles(math.rad(16), 0, math.rad(8)), 0.4, 50, {
		Name = "Disk", Material = Enum.Material.Neon, Color = Color3.fromRGB(176, 110, 255), Transparency = 0.35, CanCollide = false, CastShadow = false, Parent = folder,
	})
	cylinder(CFrame.new(holePos) * CFrame.Angles(math.rad(16), 0, math.rad(8)), 0.5, 32, {
		Name = "InnerDisk", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 220), Transparency = 0.25, CanCollide = false, CastShadow = false, Parent = folder,
	})
	make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(220, 170, 255), Color3.fromRGB(110, 50, 200)), LightEmission = 1, Rate = 40,
		Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(0.5, 2), Size = NumberSequence.new(0.7, 0), Parent = disk,
	})
	local FIRE = Color3.fromRGB(255, 120, 40)
	local VIOLET = Color3.fromRGB(176, 110, 255)

	-- second, steeper accretion ring
	cylinder(CFrame.new(holePos) * CFrame.Angles(math.rad(-58), math.rad(30), 0), 0.3, 40, {
		Name = "OuterDisk", Material = Enum.Material.Neon, Color = FIRE, Transparency = 0.55, CanCollide = false, CastShadow = false, Parent = folder,
	})

	-- particles sucked into the hole from every direction
	local vortex = ball(holePos, 70, { Name = "Vortex", Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = folder })
	make("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), VIOLET),
		LightEmission = 1, LightInfluence = 0, Rate = 60, Lifetime = NumberRange.new(2, 2.6), Speed = NumberRange.new(13, 16),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(1, 0.4) }),
		Parent = vortex,
	})

	-- burning meteors orbiting the hole: one anchored model, every client spins it locally (smooth at any FPS)
	local orbit = make("Model", { Name = "OrbitRing", Parent = folder })
	orbit.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local r = rng:NextNumber(22, 32)
		local size = rng:NextNumber(2, 4.5)
		local rock = make("Part", {
			Name = "Meteor", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.85, size),
			CFrame = CFrame.new(holePos + Vector3.new(math.cos(a) * r, rng:NextNumber(-7, 7), math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Material = Enum.Material.Basalt, Color = Color3.fromRGB(55, 40, 45), CanCollide = false, CanQuery = false, Parent = orbit,
		})
		make("Fire", { Heat = 7, Size = size * 1.5, Color = if i % 2 == 0 then FIRE else VIOLET, SecondaryColor = Color3.fromRGB(255, 220, 140), Parent = rock })
		local t0 = make("Attachment", { Position = Vector3.new(0, size * 0.3, 0), Parent = rock })
		local t1 = make("Attachment", { Position = Vector3.new(0, -size * 0.3, 0), Parent = rock })
		make("Trail", {
			Attachment0 = t0, Attachment1 = t1, Lifetime = 0.8, LightEmission = 1, FaceCamera = true,
			Color = ColorSequence.new(if i % 2 == 0 then FIRE else VIOLET, Color3.fromRGB(80, 30, 60)),
			Transparency = NumberSequence.new(0.1, 1), Parent = rock,
		})
	end
	orbit.WorldPivot = CFrame.new(holePos)
	orbit:SetAttribute("Center", holePos)
	CollectionService:AddTag(orbit, "Orbit")
	hole:SetAttribute("MeteorTarget", true) -- clients drop decorative meteors into it
	CollectionService:AddTag(hole, "MeteorTarget")

	-- lava cracks in the obsidian floor
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 28)
		make("Part", {
			Name = "LavaCrack", Size = Vector3.new(rng:NextNumber(0.3, 0.7), 0.12, rng:NextNumber(4, 10)),
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, 0.06, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.Neon, Color = if i % 3 == 0 then VIOLET else FIRE, CanCollide = false, Parent = folder,
		})
	end
	-- burning rocks lying around + fire braziers
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2 + 0.2
		local pos = center + Vector3.new(math.cos(a) * 25, 1.2, math.sin(a) * 25)
		local rock = make("Part", {
			Name = "Rock", Size = Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(2, 3.5), rng:NextNumber(3, 5)),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Material = Enum.Material.Basalt, Color = Color3.fromRGB(45, 35, 50), Parent = folder,
		})
		if i % 2 == 0 then
			make("Fire", { Heat = 7, Size = 5, Color = FIRE, SecondaryColor = Color3.fromRGB(255, 220, 120), Parent = rock })
			make("Smoke", { Color = Color3.fromRGB(60, 40, 70), Opacity = 0.25, RiseVelocity = 5, Size = 3, Parent = rock })
		end
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local base = center + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10)
		cylinder(CFrame.new(base + Vector3.new(0, 2, 0)), 4, 1.4, { Name = "BrazierStand", Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 50, 70), Parent = folder })
		local bowl = cylinder(CFrame.new(base + Vector3.new(0, 4.3, 0)), 0.8, 3.2, { Name = "Brazier", Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 60, 90), Parent = folder })
		make("Fire", { Heat = 9, Size = 4, Color = VIOLET, SecondaryColor = Color3.fromRGB(255, 160, 230), Parent = bowl })
		make("PointLight", { Color = VIOLET, Range = 14, Brightness = 1.5, Parent = bowl })
	end
	-- lightning-like arcs from the hole down to big crystals
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local c = crystal(center + Vector3.new(math.cos(a) * 19, 5, math.sin(a) * 19), 3.2, VIOLET, folder)
		local from = make("Attachment", { Parent = hole })
		local to = make("Attachment", { Parent = c })
		make("Beam", {
			Attachment0 = from, Attachment1 = to, Color = ColorSequence.new(Color3.fromRGB(230, 200, 255), VIOLET), LightEmission = 1,
			Width0 = 0.6, Width1 = 0.3, CurveSize0 = 8, CurveSize1 = -6, Segments = 20, FaceCamera = true,
			Transparency = NumberSequence.new(0.1, 0.5), Parent = c,
		})
	end

	prompt(altar, "BlackHolePrompt", "promptHole", nil, 14).Triggered:Connect(function(who)
		if World.onHole then
			World.onHole(who)
		end
	end)
	worldText(altar, "signHole", 7, 20, 3.5)
end

---------------------------------------------------------------- plots
-- ================================================================ museum on each plot
local FLOOR_H = 16
local HALF = 28.75 -- wall line from the plot center

-- display spots: 1-7 left wall (front->back), 8-13 back wall, 14-20 right wall (back->front)
local function spotLocal(spot: number): (number, number)
	if spot <= 7 then
		return -24, -18 + (spot - 1) * 7
	elseif spot <= 13 then
		return -17.5 + (spot - 8) * 7, 24
	end
	return 24, 24 - (spot - 14) * 7
end

local PEDESTAL_STYLE = {
	stone = { base = Color3.fromRGB(95, 97, 110), body = Color3.fromRGB(150, 152, 165), top = Color3.fromRGB(180, 182, 194), mat = Enum.Material.Slate },
	gold = { base = Color3.fromRGB(120, 85, 35), body = Color3.fromRGB(240, 190, 70), top = Color3.fromRGB(255, 215, 110), mat = Enum.Material.Foil, cushion = Color3.fromRGB(150, 30, 50) },
	emerald = { base = Color3.fromRGB(25, 80, 55), body = Color3.fromRGB(60, 210, 130), top = Color3.fromRGB(130, 240, 175), mat = Enum.Material.Glass, cushion = Color3.fromRGB(20, 70, 50) },
	marble = { base = GOLD, body = Color3.fromRGB(246, 246, 252), top = GOLD, mat = Enum.Material.Marble, cushion = Color3.fromRGB(70, 40, 120) },
}

-- a museum display stand; returns the part that carries the prompt
local function buildPedestal(cf: CFrame, slab, parent: Instance, key: string): BasePart
	local st = PEDESTAL_STYLE[slab.id] or PEDESTAL_STYLE.stone
	local model = make("Model", { Name = key, Parent = parent })
	local trimMat = if slab.id == "marble" then Enum.Material.SmoothPlastic else st.mat
	make("Part", { Name = "Base", Size = Vector3.new(5.6, 0.5, 5.6), CFrame = cf * CFrame.new(0, 0.25, 0), Material = trimMat, Color = st.base, Parent = model })
	local body = make("Part", {
		Name = "Body", Size = Vector3.new(4.2, 1.6, 4.2), CFrame = cf * CFrame.new(0, 1.3, 0), Material = st.mat, Color = st.body,
		Reflectance = if slab.id == "gold" then 0.2 else 0, Transparency = if slab.id == "emerald" then 0.2 else 0, Parent = model,
	})
	make("Part", { Name = "Top", Size = Vector3.new(5, 0.4, 5), CFrame = cf * CFrame.new(0, 2.3, 0), Material = trimMat, Color = st.top, Reflectance = if slab.id == "gold" then 0.2 else 0, Parent = model })
	if st.cushion then
		make("Part", { Name = "Cushion", Size = Vector3.new(3.6, 0.25, 3.6), CFrame = cf * CFrame.new(0, 2.62, 0), Material = Enum.Material.Fabric, Color = st.cushion, CanCollide = false, Parent = model })
	end
	if slab.id == "emerald" then
		make("Part", { Name = "Core", Size = Vector3.new(1.4, 1.3, 1.4), CFrame = cf * CFrame.new(0, 1.3, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 255, 180), CanCollide = false, Parent = model })
		make("PointLight", { Color = Color3.fromRGB(120, 255, 180), Range = 9, Brightness = 0.6, Parent = body })
	elseif slab.id == "marble" then
		for _, c in { { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } } do
			ball((cf * CFrame.new(c[1], 2.65, c[2])).Position, 0.5, { Name = "Stud", Material = Enum.Material.SmoothPlastic, Color = GOLD, CanCollide = false, Parent = model })
		end
	end
	model.PrimaryPart = body
	return body
end

-- walls, floors, lights, elevator and roof in the plot's theme
local function buildMuseum(plot, floors: number, themeId: string)
	plot.museum:ClearAllChildren()
	local theme = Config.ThemesById[themeId] or Config.Themes[1]
	local m = plot.museum
	local function wall(name: string, size: Vector3, offset: Vector3)
		-- glass panes tinted by the theme, so the collection is visible from outside
		return make("Part", { Name = name, Size = size, CFrame = plot.cf * CFrame.new(offset), Material = Enum.Material.Glass, Color = theme.wall, Transparency = 0.45, Parent = m })
	end
	local function trim(name: string, size: Vector3, offset: Vector3)
		return make("Part", { Name = name, Size = size, CFrame = plot.cf * CFrame.new(offset), Material = theme.trimMat, Color = theme.trim, Parent = m })
	end
	local wh = FLOOR_H - 0.4
	for f = 1, floors do
		local y0 = (f - 1) * FLOOR_H
		local floorPart = make("Part", {
			Name = "MuseumFloor", Size = Vector3.new(HALF * 2 + (if f > 1 then 3 else 0), 0.4, HALF * 2 + (if f > 1 then 3 else 0)),
			CFrame = plot.cf * CFrame.new(0, y0 + 0.2, 0), Material = theme.floorMat, Color = theme.floor, Parent = m,
		})
		if f == 1 then
			floorPart.Touched:Connect(plot.onTouch)
		else
			trim("Cornice", Vector3.new(HALF * 2 + 3.4, 0.6, HALF * 2 + 3.4), Vector3.new(0, y0 - 0.3, 0)) -- band between floors
		end
		local yc = y0 + 0.4 + wh / 2
		wall("WallLeft", Vector3.new(1.5, wh, HALF * 2 + 1.5), Vector3.new(-HALF, yc, 0))
		wall("WallRight", Vector3.new(1.5, wh, HALF * 2 + 1.5), Vector3.new(HALF, yc, 0))
		wall("WallBack", Vector3.new(HALF * 2 + 1.5, wh, 1.5), Vector3.new(0, yc, HALF))
		if f == 1 then
			local door = 7
			local side = HALF - door
			wall("WallFront", Vector3.new(side, wh, 1.5), Vector3.new(-(door + side / 2), yc, -HALF))
			wall("WallFront", Vector3.new(side, wh, 1.5), Vector3.new(door + side / 2, yc, -HALF))
			wall("Lintel", Vector3.new(door * 2, wh - 10, 1.5), Vector3.new(0, y0 + 0.4 + 10 + (wh - 10) / 2, -HALF))
			trim("DoorTrim", Vector3.new(door * 2 + 1.5, 0.8, 2.2), Vector3.new(0, y0 + 10.4, -HALF))
		else
			wall("WallFront", Vector3.new(HALF * 2 + 1.5, 3, 1.5), Vector3.new(0, y0 + 1.9, -HALF))
			make("Part", { Name = "Window", Size = Vector3.new(HALF * 2, 8, 0.6), CFrame = plot.cf * CFrame.new(0, y0 + 7.4, -HALF), Material = Enum.Material.Glass, Color = theme.light, Transparency = 0.6, Parent = m })
			wall("WallFront", Vector3.new(HALF * 2 + 1.5, wh - 11, 1.5), Vector3.new(0, y0 + 11.4 + (wh - 11) / 2, -HALF))
		end
		-- trim posts holding the glass
		for k = -3, 3 do
			local along = k * 8
			trim("Post", Vector3.new(1, wh, 1), Vector3.new(-HALF, yc, along))
			trim("Post", Vector3.new(1, wh, 1), Vector3.new(HALF, yc, along))
			trim("Post", Vector3.new(1, wh, 1), Vector3.new(along, yc, HALF))
		end
		-- ceiling lights
		for _, x in { -12, 12 } do
			local lamp = make("Part", { Name = "Lamp", Size = Vector3.new(4, 0.4, 4), CFrame = plot.cf * CFrame.new(x, y0 + FLOOR_H - 0.6, 4), Material = Enum.Material.Neon, Color = theme.light, CanCollide = false, Parent = m })
			make("PointLight", { Color = theme.light, Range = 34, Brightness = 1.1, Shadows = false, Parent = lamp })
		end
		-- elevator pad (only when there is somewhere to go)
		if floors > 1 then
			local pad = make("Part", { Name = "Elevator", Size = Vector3.new(5, 0.3, 5), CFrame = plot.cf * CFrame.new(16, y0 + 0.55, -22), Material = Enum.Material.Neon, Color = theme.trim, CanCollide = false, Parent = m })
			local floorNumber = f
			prompt(pad, "ElevatorPrompt", "promptElevator", nil, 8).Triggered:Connect(function(who)
				if World.onElevator then
					World.onElevator(who, plot.index, floorNumber, plot.builtFloors)
				end
			end)
		end
	end
	-- roof + corner columns
	local top = floors * FLOOR_H
	make("Part", { Name = "Roof", Size = Vector3.new(HALF * 2 + 3, 1.2, HALF * 2 + 3), CFrame = plot.cf * CFrame.new(0, top + 0.6, 0), Material = theme.wallMat, Color = theme.wall, Parent = m })
	trim("RoofTrim", Vector3.new(HALF * 2 + 4, 0.8, HALF * 2 + 4), Vector3.new(0, top + 1.6, 0))
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		cylinder(plot.cf * CFrame.new(c[1] * (HALF + 0.6), top / 2 + 1, c[2] * (HALF + 0.6)), top + 2, 3.2, {
			Name = "Column", Material = if theme.trimMat == Enum.Material.Neon then theme.wallMat else theme.trimMat, Color = theme.trim, Parent = m,
		})
	end
	if themeId == "hell" then
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local flame = make("Part", { Name = "Flame", Size = Vector3.one, CFrame = plot.cf * CFrame.new(c[1] * (HALF + 0.6), top + 3, c[2] * (HALF + 0.6)), Transparency = 1, CanCollide = false, Parent = m })
			make("Fire", { Heat = 10, Size = 6, Color = Color3.fromRGB(255, 100, 30), SecondaryColor = Color3.fromRGB(255, 220, 120), Parent = flame })
		end
	elseif themeId == "cosmos" then
		local roofTop = make("Part", { Name = "StarDust", Size = Vector3.new(HALF * 2, 1, HALF * 2), CFrame = plot.cf * CFrame.new(0, top + 6, 0), Transparency = 1, CanCollide = false, Parent = m })
		make("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(190, 160, 255)), LightEmission = 0.7,
			Rate = 20, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.4, 0), Parent = roofTop })
	end
	plot.builtFloors = floors
	plot.builtTheme = themeId
end

-- display spots: invisible build markers on all of them, pedestals (with prompts) where the owner built one
local function buildSpots(plot, floors: number, slabs, grid)
	plot.pedestals:ClearAllChildren()
	plot.markers:ClearAllChildren()
	plot.cells = {}
	for f = 1, floors do
		local y0 = (f - 1) * FLOOR_H + 0.4
		for spot = 1, Config.SpotsPerFloor do
			local key = Sky.key(spot, f)
			local x, z = spotLocal(spot)
			local cf = plot.cf * CFrame.new(x, y0, z)
			plot.cells[key] = { cf = cf }
			-- the marker covers the whole stand, so clicks never "fall through" to a neighbour
			make("Part", {
				Name = key, Size = Vector3.new(6, 3, 6), CFrame = cf * CFrame.new(0, 1.5, 0), Transparency = 1,
				CanCollide = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 230, 140), Parent = plot.markers,
			})
			local slab = Config.SlabsById[slabs[key]]
			if slab then
				local body = buildPedestal(cf, slab, plot.pedestals, key)
				local p = prompt(body, "PedestalPrompt", if grid[key] then "promptRemove" else "promptPlace", "slab_" .. slab.id, 6)
				p:SetAttribute("Plot", plot.index)
				p.Triggered:Connect(function(who)
					if World.onPedestal then
						World.onPedestal(who, plot.index, key)
					end
				end)
			end
		end
	end
end

local function buildPlot(index: number, slot: number, folder: Folder)
	local direction = directionAt(slot)
	local center = direction * RING
	local cf = CFrame.lookAt(center, Vector3.zero)
	local plotFolder = make("Folder", { Name = "Plot" .. index, Parent = folder })
	plotFolder:SetAttribute("OwnerId", 0)

	local floor = make("Part", { Name = "Floor", Size = Vector3.new(PLOT_SIZE, 4, PLOT_SIZE), CFrame = cf * CFrame.new(0, -2, 0), Material = Enum.Material.Grass, Color = GRASS, Parent = plotFolder })
	make("Part", { Name = "Border", Size = Vector3.new(PLOT_SIZE + 3, 3.6, PLOT_SIZE + 3), CFrame = cf * CFrame.new(0, -2.3, 0), Material = Enum.Material.Marble, Color = MARBLE, Parent = plotFolder })
	make("Part", { Name = "Trim", Size = Vector3.new(PLOT_SIZE + 4, 1, PLOT_SIZE + 4), CFrame = cf * CFrame.new(0, -4.2, 0), Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = plotFolder })
	for _ = 1, 10 do
		cloudPuff((cf * CFrame.new(rng:NextNumber(-26, 26), -9, rng:NextNumber(-26, 26))).Position, rng:NextNumber(12, 18), plotFolder, 2)
	end
	for _, c in { { -31, -31 }, { 31, -31 } } do
		flowers((cf * CFrame.new(c[1], 0, c[2])).Position, 1.5, 4, plotFolder)
	end
	bridge(direction, HUB_RADIUS - 2, RING - PLOT_SIZE / 2 + 1, plotFolder)

	local post = make("Part", { Name = "SignPost", Size = Vector3.new(1, 7, 1), CFrame = cf * CFrame.new(-10, 3.5, -(PLOT_SIZE / 2 - 1.5)), Material = Enum.Material.SmoothPlastic, Color = GOLD, Parent = plotFolder })
	local label = worldText(post, "signFree", 5, 11, 3.2)
	label:SetAttribute("Owner", "")
	label:SetAttribute("Income", 0)

	local plot = {
		index = index,
		cf = cf,
		folder = plotFolder,
		museum = make("Folder", { Name = "Museum", Parent = plotFolder }),
		pedestals = make("Folder", { Name = "Pedestals", Parent = plotFolder }),
		stars = make("Folder", { Name = "Stars", Parent = plotFolder }),
		markers = make("Folder", { Name = "Markers", Parent = plotFolder }),
		label = label,
		owner = nil,
		cells = {},
		builtFloors = 0,
		builtTheme = "",
	}
	plots[index] = plot

	local cooldown = {}
	plot.onTouch = function(hit: BasePart)
		local who = Players:GetPlayerFromCharacter(hit.Parent)
		if not who or plot.owner or (cooldown[who] and os.clock() - cooldown[who] < 1) then
			return
		end
		cooldown[who] = os.clock()
		if World.onPlotTouched then
			World.onPlotTouched(who, index)
		end
	end
	floor.Touched:Connect(plot.onTouch)
	-- the museum only appears once somebody claims the plot (it is loaded from their save)
end

---------------------------------------------------------------- scenery
local function buildScenery(folder: Folder)
	-- sea of clouds far below
	for _ = 1, 70 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 340)
		ball(Vector3.new(math.cos(a) * r, rng:NextNumber(-70, -50), math.sin(a) * r), rng:NextNumber(30, 60), {
			Name = "CloudSea", Color = CLOUD, Material = Enum.Material.SmoothPlastic, Transparency = 0.05, CanCollide = false, CastShadow = false, Parent = folder,
		})
	end

	-- rainbow behind the Forge side
	local bands = {
		Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 110), Color3.fromRGB(255, 235, 130), Color3.fromRGB(150, 230, 140),
		Color3.fromRGB(130, 200, 255), Color3.fromRGB(150, 150, 255), Color3.fromRGB(200, 150, 255),
	}
	local segments = 36
	for b, color in bands do
		local radius = 200 - (b - 1) * 4
		for s = 0, segments - 1 do
			local a0 = s / segments * math.pi
			local a1 = (s + 1) / segments * math.pi
			local p0 = Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius - 60, 330)
			local p1 = Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius - 60, 330)
			make("Part", {
				Name = "Rainbow", Size = Vector3.new(4, 1, (p1 - p0).Magnitude + 0.4), CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Material = Enum.Material.SmoothPlastic, Color = color, Transparency = 0.35, CanCollide = false, CastShadow = false, Parent = folder,
			})
		end
	end

	-- little floating islets with a tree or a crystal
	for i = 1, 10 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / 10 * math.pi * 2
		local r = rng:NextNumber(215, 280)
		local center = Vector3.new(math.cos(a) * r, rng:NextNumber(-15, 35), math.sin(a) * r)
		local size = rng:NextNumber(10, 16)
		cylinder(CFrame.new(center + Vector3.new(0, -1.5, 0)), 3, size, { Name = "Islet", Material = Enum.Material.Grass, Color = GRASS, Parent = folder })
		cylinder(CFrame.new(center + Vector3.new(0, -4, 0)), 3, size * 0.75, { Name = "IsletBase", Material = Enum.Material.Marble, Color = MARBLE_WARM, Parent = folder })
		cloudPuff(center + Vector3.new(0, -7, 0), size * 0.7, folder, 3)
		if i % 2 == 0 then
			tree(center, folder, Color3.fromRGB(255, 210, 230))
		else
			crystal(center + Vector3.new(0, 4, 0), 2.5, Color3.fromRGB(180, 230, 255), folder)
		end
	end

	-- hot air balloons gently bobbing
	local balloonColors = { Color3.fromRGB(255, 160, 170), Color3.fromRGB(150, 210, 255), Color3.fromRGB(255, 220, 130), Color3.fromRGB(170, 235, 190) }
	for i, color in balloonColors do
		local a = (i - 0.5) / #balloonColors * math.pi * 2 + 0.4
		local origin = Vector3.new(math.cos(a) * 205, 40 + i * 6, math.sin(a) * 205)
		local parts = {
			ball(origin, 16, { Name = "Balloon", Material = Enum.Material.SmoothPlastic, Color = color, CanCollide = false, Parent = folder }),
			make("Part", { Name = "Band", Size = Vector3.new(2, 16.4, 16.4), CFrame = CFrame.new(origin), Material = Enum.Material.SmoothPlastic, Color = MARBLE, CanCollide = false, Shape = Enum.PartType.Cylinder, Parent = folder }),
			make("Part", { Name = "Basket", Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(origin + Vector3.new(0, -13, 0)), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(170, 120, 80), CanCollide = false, Parent = folder }),
		}
		parts[2].CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
		for _, corner in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
			table.insert(parts, make("Part", {
				Name = "Rope", Size = Vector3.new(0.15, 6, 0.15), CFrame = CFrame.new(origin + Vector3.new(corner[1], -9, corner[2])),
				Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 90, 60), CanCollide = false, Parent = folder,
			}))
		end
		local info = TweenInfo.new(4 + i, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		for _, part in parts do
			TweenService:Create(part, info, { CFrame = part.CFrame + Vector3.new(0, 4, 0) }):Play()
		end
	end
end

---------------------------------------------------------------- public API
function World.build()
	local okLight, errLight = pcall(setupLighting)
	if not okLight then
		warn("[World] lighting: " .. tostring(errLight))
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local map = make("Folder", { Name = "Map", Parent = workspace })
	-- each part is guarded: a broken decoration must never take the whole game down
	local function try(name: string, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[World] failed to build " .. name .. ": " .. tostring(err))
		end
	end
	try("hub", buildHub, make("Folder", { Name = "Hub", Parent = map }))
	try("forge", buildForgeHouse, make("Folder", { Name = "Forge", Parent = map }))
	try("black hole", buildBlackHole, make("Folder", { Name = "BlackHoleIsland", Parent = map }), 7) -- -Z
	local plotFolder = make("Folder", { Name = "Plots", Parent = map })
	local index = 0
	for _, slot in { 1, 2, 3, 4, 5, 6, 8 } do
		index += 1
		try("plot " .. index, buildPlot, index, slot, plotFolder)
	end
	try("scenery", buildScenery, make("Folder", { Name = "Scenery", Parent = map }))
end

function World.plotOf(player: Player): number?
	return playerPlot[player]
end

function World.claimPlot(player: Player, index: number): boolean
	local plot = plots[index]
	if not plot or plot.owner or playerPlot[player] then
		return false
	end
	plot.owner = player
	playerPlot[player] = index
	plot.folder:SetAttribute("OwnerId", player.UserId)
	plot.label:SetAttribute("Owner", player.DisplayName)
	return true
end

function World.releasePlot(player: Player)
	local index = playerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	plot.owner = nil
	plot.folder:SetAttribute("OwnerId", 0)
	plot.label:SetAttribute("Owner", "")
	plot.label:SetAttribute("Income", 0)
	plot.stars:ClearAllChildren()
	plot.museum:ClearAllChildren()
	plot.pedestals:ClearAllChildren()
	plot.markers:ClearAllChildren()
	plot.cells = {}
	plot.builtFloors = 0
	plot.builtTheme = ""
	playerPlot[player] = nil
end

function World.spawnCFrame(player: Player): CFrame
	local index = playerPlot[player]
	if not index then
		return CFrame.new(0, 4, 20)
	end
	local cf = plots[index].cf
	local position = (cf * CFrame.new(0, 4, -(PLOT_SIZE / 2 - 1.5))).Position -- just outside the museum door
	return CFrame.lookAt(position, cf.Position + Vector3.new(0, 4, 0))
end

function World.teleportToFloor(player: Player, index: number, floor: number)
	local plot = plots[index]
	local character = player.Character
	if not plot or not character or floor < 1 or floor > plot.builtFloors then
		return
	end
	character:PivotTo(plot.cf * CFrame.new(16, (floor - 1) * FLOOR_H + 3.5, -17))
end

function World.isNearPlot(player: Player, index: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local plot = plots[index]
	if not root or not plot then
		return false
	end
	local offset = root.Position - plot.cf.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.PlotReach
end

function World.distanceTo(player: Player, position: Vector3): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root then (root.Position - position).Magnitude else math.huge
end

-- A huge column of light over a player (server-wide rare find)
function World.lightPillar(player: Player, color: Color3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local base = root.Position
	local pillar = cylinder(CFrame.new(base + Vector3.new(0, 150, 0)), 300, 7, {
		Name = "LightPillar", Material = Enum.Material.Neon, Color = color, Transparency = 0.15, CanCollide = false, CanQuery = false, CastShadow = false, Parent = workspace,
	})
	local glow = cylinder(CFrame.new(base + Vector3.new(0, 150, 0)), 300, 16, {
		Name = "LightGlow", Material = Enum.Material.Neon, Color = color, Transparency = 0.7, CanCollide = false, CanQuery = false, CastShadow = false, Parent = workspace,
	})
	local burst = make("Part", { Name = "Burst", Size = Vector3.one, CFrame = CFrame.new(base), Transparency = 1, CanCollide = false, CanQuery = false, Parent = workspace })
	local emitter = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(color, Color3.new(1, 1, 1)), LightEmission = 1,
		Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(20, 45), SpreadAngle = Vector2.new(180, 180), Rate = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }), Parent = burst,
	})
	emitter:Emit(160)
	local info = TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(pillar, info, { Transparency = 1 }):Play()
	TweenService:Create(glow, info, { Transparency = 1 }):Play()
	task.delay(7, function()
		pillar:Destroy()
		glow:Destroy()
		burst:Destroy()
	end)
end

local NEIGHBORS = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } }

function World.renderPlot(player: Player, data, evaluation, income: number)
	local index = playerPlot[player]
	if not index then
		return
	end
	local plot = plots[index]
	if plot.builtFloors ~= data.floors or plot.builtTheme ~= data.theme then
		buildMuseum(plot, data.floors, data.theme)
	end
	buildSpots(plot, data.floors, data.slabs, data.grid)
	plot.stars:ClearAllChildren()
	plot.label:SetAttribute("Income", income)

	local function starPosition(key: string): Vector3?
		local cell = plot.cells[key]
		return cell and (cell.cf * CFrame.new(0, STAR_HEIGHT, 0)).Position
	end

	for key, cell in data.grid do
		local star, mutation = Items.parse(cell.id)
		local position = starPosition(key)
		if star and position then
			StarModels.create(star, mutation, Evolution.level(cell.age or 0), position, plot.stars)
		end
	end

	for _, group in evaluation.groups do
		local members = {}
		for _, key in group.cells do
			members[key] = true
		end
		local color = if group.pure then Color3.fromRGB(120, 210, 255) else GOLD
		for _, key in group.cells do
			local x, y = Sky.parse(key)
			for _, offset in NEIGHBORS do
				local otherKey = Sky.key(x + offset[1], y + offset[2])
				if members[otherKey] then
					local a, b = starPosition(key), starPosition(otherKey)
					if a and b then
						make("Part", {
							Name = "Line", Size = Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b),
							Material = Enum.Material.Neon, Color = color, CanCollide = false, CastShadow = false, Parent = plot.stars,
						})
					end
				end
			end
		end
	end
end

return World
