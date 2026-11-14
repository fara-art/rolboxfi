-- 3D star models that sit on plot pedestals. Each star type has its own look,
-- glow shell and particles. The client spins / bobs models tagged "StarModel".
local CollectionService = game:GetService("CollectionService")

local StarModels = {}

local function part(model: Model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = model
	return p
end

local function orb(model: Model, cf: CFrame, diameter: number, color: Color3, transparency: number?)
	return part(model, {
		Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = cf,
		Material = Enum.Material.Neon, Color = color, Transparency = transparency or 0,
	})
end

local function bar(model: Model, cf: CFrame, size: Vector3, color: Color3, transparency: number?)
	return part(model, { Name = "Bar", Size = size, CFrame = cf, Material = Enum.Material.Neon, Color = color, Transparency = transparency or 0 })
end

local function disk(model: Model, cf: CFrame, diameter: number, color: Color3, transparency: number)
	return part(model, {
		Name = "Disk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = color, Transparency = transparency,
	})
end

local function particles(parent: BasePart, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = props.Rate or 8
	e.Lifetime = props.Lifetime or NumberRange.new(1.2, 2.4)
	e.Speed = props.Speed or NumberRange.new(0.6, 1.6)
	e.SpreadAngle = props.Spread or Vector2.new(180, 180)
	e.Acceleration = props.Acceleration or Vector3.new(0, 0.8, 0)
	e.Drag = props.Drag or 1
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.Color = ColorSequence.new(props.Color, props.Color2 or props.Color)
	e.Size = props.Size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.22), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	if props.Texture then
		e.Texture = props.Texture
	end
	e.Parent = parent
	return e
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.new(1, 1, 1)

-- builders: (model, cf, color) -> core part
local builders = {}

builders.dust = function(m, cf, color)
	local core = orb(m, cf, 0.5, WHITE)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		orb(m, cf * CFrame.new(math.cos(a) * 0.8, math.sin(i * 1.7) * 0.4, math.sin(a) * 0.8), 0.25 + (i % 3) * 0.08, color)
	end
	orb(m, cf, 2.2, color, 0.88)
	particles(core, { Color = color, Rate = 6, Texture = SPARKLE })
	return core
end

builders.spark = function(m, cf, color)
	local core = orb(m, cf, 0.6, WHITE)
	bar(m, cf, Vector3.new(0.18, 2.6, 0.18), color)
	bar(m, cf, Vector3.new(2.6, 0.18, 0.18), color)
	bar(m, cf * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.12, 1.4, 0.12), WHITE, 0.3)
	bar(m, cf * CFrame.Angles(0, 0, math.rad(-45)), Vector3.new(0.12, 1.4, 0.12), WHITE, 0.3)
	orb(m, cf, 1.8, color, 0.85)
	particles(core, { Color = color, Color2 = WHITE, Rate = 8, Texture = SPARKLE })
	light(core, color, 6, 0.8)
	return core
end

builders.dwarf = function(m, cf, color)
	local core = orb(m, cf, 1.3, color)
	orb(m, cf, 1.9, Color3.fromRGB(255, 140, 90), 0.75)
	orb(m, cf, 2.6, color, 0.9)
	particles(core, { Color = Color3.fromRGB(255, 170, 90), Color2 = color, Rate = 10, Acceleration = Vector3.new(0, 2, 0) })
	light(core, color, 8, 1)
	return core
end

builders.sun = function(m, cf, color)
	local core = orb(m, cf, 1.6, Color3.fromRGB(255, 236, 150))
	orb(m, cf, 2.2, color, 0.6)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		bar(m, cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.55, 0), Vector3.new(0.25, 0.9, 0.25), Color3.fromRGB(255, 200, 70), 0.1)
	end
	orb(m, cf, 3.4, color, 0.9)
	particles(core, { Color = Color3.fromRGB(255, 220, 110), Color2 = Color3.fromRGB(255, 140, 40), Rate = 14, Acceleration = Vector3.new(0, 1.5, 0) })
	light(core, color, 12, 1.5)
	return core
end

builders.giant = function(m, cf, color)
	local core = orb(m, cf, 2.2, color)
	orb(m, cf * CFrame.new(-0.35, 0.4, -0.35), 1, Color3.fromRGB(210, 240, 255), 0.2)
	orb(m, cf, 3, Color3.fromRGB(150, 210, 255), 0.75)
	orb(m, cf, 4, color, 0.9)
	particles(core, { Color = Color3.fromRGB(170, 220, 255), Color2 = color, Rate = 16, Texture = SPARKLE })
	light(core, color, 14, 2)
	return core
end

builders.pulsar = function(m, cf, color)
	local core = orb(m, cf, 1.1, Color3.fromRGB(240, 220, 255))
	orb(m, cf, 1.8, color, 0.55)
	local tilt = cf * CFrame.Angles(0, 0, math.rad(18))
	bar(m, tilt, Vector3.new(0.2, 6, 0.2), WHITE, 0.15)
	bar(m, tilt, Vector3.new(0.6, 5.4, 0.6), color, 0.6)
	disk(m, tilt, 2.8, color, 0.7)
	particles(core, { Color = color, Color2 = WHITE, Rate = 20, Speed = NumberRange.new(2, 4), Spread = Vector2.new(10, 10), Acceleration = Vector3.zero })
	light(core, color, 14, 2)
	return core
end

builders.neutron = function(m, cf, color)
	local core = orb(m, cf, 0.8, WHITE)
	orb(m, cf, 1.4, color, 0.5)
	disk(m, cf * CFrame.Angles(math.rad(30), 0, 0), 3.2, color, 0.75)
	disk(m, cf * CFrame.Angles(math.rad(-30), 0, math.rad(60)), 3.2, color, 0.75)
	disk(m, cf * CFrame.Angles(0, 0, math.rad(90)), 3.2, Color3.fromRGB(200, 255, 245), 0.8)
	orb(m, cf, 4, color, 0.92)
	particles(core, { Color = color, Color2 = WHITE, Rate = 22, Texture = SPARKLE, Speed = NumberRange.new(1, 2.5) })
	light(core, color, 16, 2.5)
	return core
end

builders.quasar = function(m, cf, color)
	local core = orb(m, cf, 0.9, WHITE)
	local tilt = cf * CFrame.Angles(math.rad(20), 0, math.rad(10))
	disk(m, tilt, 4.4, color, 0.45)
	disk(m, tilt, 3, Color3.fromRGB(255, 170, 120), 0.35)
	disk(m, tilt, 1.8, Color3.fromRGB(255, 240, 210), 0.2)
	bar(m, tilt, Vector3.new(0.18, 8, 0.18), Color3.fromRGB(255, 210, 250), 0.2)
	bar(m, tilt, Vector3.new(0.5, 7, 0.5), color, 0.7)
	particles(core, { Color = color, Color2 = Color3.fromRGB(255, 200, 140), Rate = 30, Speed = NumberRange.new(1.5, 3), Texture = SPARKLE })
	light(core, color, 18, 3)
	return core
end

builders.supernova = function(m, cf, color)
	local core = orb(m, cf, 1.6, WHITE)
	orb(m, cf, 2.4, Color3.fromRGB(255, 230, 160), 0.4)
	for i = 1, 14 do
		local rot = CFrame.Angles(i * 1.3, i * 2.1, i * 0.7)
		local length = 2.2 + (i % 3) * 0.6
		bar(m, cf * rot * CFrame.new(0, length / 2, 0), Vector3.new(0.22, length, 0.22), if i % 2 == 0 then Color3.fromRGB(255, 190, 90) else WHITE, 0.1)
	end
	orb(m, cf, 5, Color3.fromRGB(255, 200, 120), 0.9)
	particles(core, { Color = Color3.fromRGB(255, 240, 200), Color2 = Color3.fromRGB(255, 120, 60), Rate = 45, Speed = NumberRange.new(2, 5), Texture = SPARKLE })
	particles(core, { Color = WHITE, Rate = 8, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(0, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 4) }) })
	light(core, Color3.fromRGB(255, 230, 180), 22, 4)
	return core
end

-- star, mutation, level -> Model at position
function StarModels.create(star, mutation, level: number, position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = star.id
	local scale = 1 + (level - 1) * 0.08
	local cf = CFrame.new(position)
	local builder = builders[star.id] or builders.dwarf
	local core = builder(model, cf, star.color)
	model.PrimaryPart = core

	-- glow ring on the pedestal top (outside the model so it doesn't spin or bob)
	part(parent :: any, {
		Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 3.4, 3.4),
		CFrame = CFrame.new(position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon, Color = star.color, Transparency = 0.55,
	})

	if mutation.id ~= "normal" then
		particles(core, {
			Color = mutation.color, Rate = 6 + mutation.index * 4, Texture = SPARKLE,
			Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1, 2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		})
		orb(model, cf, 3 + mutation.index * 0.3, mutation.color, 0.88)
	end

	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:SetAttribute("Spin", 20 + star.index * 6)
	model.Parent = parent
	CollectionService:AddTag(model, "StarModel")
	return model
end

return StarModels
