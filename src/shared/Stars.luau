-- chance = "1 in N", income = cash per second while placed on the sky
-- evolvesTo = what it can explode into at max evolution level
-- kind = which look (icon + 3D model) a named star borrows
local Stars = {}

Stars.List = {
	{ id = "dust", name = "Stardust", chance = 2, income = 1, color = Color3.fromRGB(170, 170, 190) },
	{ id = "spark", name = "Spark", chance = 5, income = 3, color = Color3.fromRGB(255, 240, 180) },
	{ id = "browndwarf", name = "Brown Dwarf", chance = 9, income = 6, color = Color3.fromRGB(160, 100, 70) },
	{ id = "dwarf", name = "Red Dwarf", chance = 15, income = 10, color = Color3.fromRGB(255, 90, 70) },
	{ id = "whitedwarf", name = "White Dwarf", chance = 30, income = 20, color = Color3.fromRGB(225, 240, 255) },
	{ id = "sun", name = "Yellow Sun", chance = 50, income = 35, color = Color3.fromRGB(255, 210, 60), evolvesTo = "giant" },
	{ id = "redgiant", name = "Red Giant", chance = 100, income = 75, color = Color3.fromRGB(255, 120, 60) },
	{ id = "giant", name = "Blue Giant", chance = 200, income = 150, color = Color3.fromRGB(80, 160, 255), evolvesTo = "neutron" },
	{ id = "binary", name = "Twin Stars", chance = 450, income = 350, color = Color3.fromRGB(255, 220, 160) },
	{ id = "pulsar", name = "Pulsar", chance = 1000, income = 800, color = Color3.fromRGB(170, 90, 255) },
	{ id = "wolfrayet", name = "Wolf-Rayet Star", chance = 3000, income = 2500, color = Color3.fromRGB(255, 130, 170) },
	{ id = "neutron", name = "Neutron Star", chance = 10000, income = 9000, color = Color3.fromRGB(90, 255, 220) },
	{ id = "hypergiant", name = "Hypergiant", chance = 30000, income = 28000, color = Color3.fromRGB(255, 100, 40) },
	{ id = "quasar", name = "Quasar", chance = 100000, income = 100000, color = Color3.fromRGB(255, 80, 200), evolvesTo = "supernova" },
	{ id = "proxima", name = "Proxima Centauri", chance = 120000, income = 150000, color = Color3.fromRGB(255, 110, 80), kind = "sphere" },
	{ id = "sirius", name = "Sirius", chance = 140000, income = 180000, color = Color3.fromRGB(200, 225, 255), kind = "point" },
	{ id = "vega", name = "Vega", chance = 170000, income = 220000, color = Color3.fromRGB(190, 210, 255), kind = "point" },
	{ id = "altair", name = "Altair", chance = 210000, income = 280000, color = Color3.fromRGB(235, 240, 255), kind = "sphere" },
	{ id = "procyon", name = "Procyon", chance = 250000, income = 340000, color = Color3.fromRGB(255, 245, 210), kind = "sphere" },
	{ id = "kilonova", name = "Kilonova", chance = 300000, income = 350000, color = Color3.fromRGB(255, 190, 90) },
	{ id = "arcturus", name = "Arcturus", chance = 300000, income = 410000, color = Color3.fromRGB(255, 170, 90), kind = "giant" },
	{ id = "aldebaran", name = "Aldebaran", chance = 360000, income = 500000, color = Color3.fromRGB(255, 140, 70), kind = "giant" },
	{ id = "capella", name = "Capella", chance = 430000, income = 610000, color = Color3.fromRGB(255, 230, 150), kind = "binary" },
	{ id = "spica", name = "Spica", chance = 520000, income = 740000, color = Color3.fromRGB(150, 190, 255), kind = "binary" },
	{ id = "polaris", name = "Polaris", chance = 620000, income = 900000, color = Color3.fromRGB(255, 250, 220), kind = "point" },
	{ id = "algol", name = "Algol", chance = 740000, income = 1100000, color = Color3.fromRGB(190, 210, 255), kind = "binary" },
	{ id = "mira", name = "Mira", chance = 890000, income = 1300000, color = Color3.fromRGB(255, 90, 70), kind = "giant" },
	{ id = "supernova", name = "Supernova", chance = 1000000, income = 1500000, color = Color3.fromRGB(255, 255, 255) },
	{ id = "achernar", name = "Achernar", chance = 1100000, income = 1700000, color = Color3.fromRGB(150, 190, 255), kind = "sphere" },
	{ id = "canopus", name = "Canopus", chance = 1300000, income = 2000000, color = Color3.fromRGB(255, 250, 235), kind = "point" },
	{ id = "antares", name = "Antares", chance = 1500000, income = 2300000, color = Color3.fromRGB(255, 80, 50), kind = "giant" },
	{ id = "rigel", name = "Rigel", chance = 1800000, income = 2800000, color = Color3.fromRGB(160, 200, 255), kind = "point" },
	{ id = "deneb", name = "Deneb", chance = 2200000, income = 3500000, color = Color3.fromRGB(230, 240, 255), kind = "point" },
	{ id = "betelgeuse", name = "Betelgeuse", chance = 2700000, income = 4300000, color = Color3.fromRGB(255, 100, 50), kind = "giant" },
	{ id = "tabby", name = "Tabby's Star", chance = 3200000, income = 5200000, color = Color3.fromRGB(255, 220, 160), kind = "sphere" },
	{ id = "przybylski", name = "Przybylski's Star", chance = 3800000, income = 6300000, color = Color3.fromRGB(210, 255, 230), kind = "sphere" },
	{ id = "vela", name = "Vela Pulsar", chance = 4600000, income = 7700000, color = Color3.fromRGB(150, 200, 255), kind = "pulsar" },
	{ id = "magnetar", name = "Magnetar", chance = 5000000, income = 8000000, color = Color3.fromRGB(110, 200, 255) },
	{ id = "crabpulsar", name = "Crab Pulsar", chance = 5500000, income = 9300000, color = Color3.fromRGB(255, 170, 230), kind = "pulsar" },
	{ id = "cygnusx1", name = "Cygnus X-1", chance = 6600000, income = 11000000, color = Color3.fromRGB(120, 180, 255), kind = "blackhole" },
	{ id = "sgr1806", name = "SGR 1806-20", chance = 7900000, income = 14000000, color = Color3.fromRGB(130, 220, 255), kind = "magnetar" },
	{ id = "etacarinae", name = "Eta Carinae", chance = 9500000, income = 17000000, color = Color3.fromRGB(255, 170, 120), kind = "nebula" },
	{ id = "vycma", name = "VY Canis Majoris", chance = 11000000, income = 19000000, color = Color3.fromRGB(255, 70, 40), kind = "giant" },
	{ id = "uyscuti", name = "UY Scuti", chance = 14000000, income = 25000000, color = Color3.fromRGB(255, 120, 60), kind = "giant" },
	{ id = "stephenson", name = "Stephenson 2-18", chance = 16000000, income = 29000000, color = Color3.fromRGB(230, 60, 50), kind = "giant" },
	{ id = "r136a1", name = "R136a1", chance = 20000000, income = 37000000, color = Color3.fromRGB(140, 180, 255), kind = "point" },
	{ id = "ringneb", name = "Ring Nebula", chance = 24000000, income = 44000000, color = Color3.fromRGB(120, 220, 200), kind = "remnant" },
	{ id = "nebula", name = "Nebula Heart", chance = 25000000, income = 45000000, color = Color3.fromRGB(255, 140, 230) },
	{ id = "helix", name = "Helix Nebula", chance = 28000000, income = 52000000, color = Color3.fromRGB(90, 200, 255), kind = "remnant" },
	{ id = "catseye", name = "Cat's Eye Nebula", chance = 34000000, income = 64000000, color = Color3.fromRGB(140, 255, 190), kind = "remnant" },
	{ id = "crab", name = "Crab Nebula", chance = 41000000, income = 78000000, color = Color3.fromRGB(255, 140, 90), kind = "remnant" },
	{ id = "sn1987a", name = "SN 1987A", chance = 49000000, income = 94000000, color = Color3.fromRGB(255, 220, 170), kind = "remnant" },
	{ id = "tycho", name = "Tycho's Supernova", chance = 59000000, income = 110000000, color = Color3.fromRGB(255, 120, 120), kind = "remnant" },
	{ id = "kepler", name = "Kepler's Supernova", chance = 70000000, income = 140000000, color = Color3.fromRGB(255, 190, 90), kind = "remnant" },
	{ id = "orion", name = "Orion Nebula", chance = 84000000, income = 170000000, color = Color3.fromRGB(255, 120, 170), kind = "nebula" },
	{ id = "whitehole", name = "White Hole", chance = 100000000, income = 200000000, color = Color3.fromRGB(235, 248, 255) },
	{ id = "eagle", name = "Eagle Nebula", chance = 100000000, income = 200000000, color = Color3.fromRGB(230, 190, 120), kind = "nebula" },
	{ id = "horsehead", name = "Horsehead Nebula", chance = 120000000, income = 240000000, color = Color3.fromRGB(255, 90, 110), kind = "nebula" },
	{ id = "lagoon", name = "Lagoon Nebula", chance = 150000000, income = 310000000, color = Color3.fromRGB(255, 110, 150), kind = "nebula" },
	{ id = "tarantula", name = "Tarantula Nebula", chance = 170000000, income = 350000000, color = Color3.fromRGB(190, 120, 255), kind = "nebula" },
	{ id = "triangulum", name = "Triangulum Galaxy", chance = 210000000, income = 440000000, color = Color3.fromRGB(170, 200, 255), kind = "galaxy" },
	{ id = "whirlpool", name = "Whirlpool Galaxy", chance = 250000000, income = 520000000, color = Color3.fromRGB(200, 180, 255), kind = "galaxy" },
	{ id = "eventhorizon", name = "Event Horizon", chance = 300000000, income = 650000000, color = Color3.fromRGB(255, 150, 60) },
	{ id = "sombrero", name = "Sombrero Galaxy", chance = 300000000, income = 640000000, color = Color3.fromRGB(255, 225, 170), kind = "galaxy" },
	{ id = "andromeda", name = "Andromeda Galaxy", chance = 360000000, income = 770000000, color = Color3.fromRGB(210, 210, 255), kind = "galaxy" },
	{ id = "hoag", name = "Hoag's Object", chance = 430000000, income = 930000000, color = Color3.fromRGB(255, 230, 150), kind = "lens" },
	{ id = "einstein", name = "Einstein Ring", chance = 520000000, income = 1100000000, color = Color3.fromRGB(170, 210, 255), kind = "lens" },
	{ id = "quasar3c273", name = "Quasar 3C 273", chance = 630000000, income = 1400000000, color = Color3.fromRGB(255, 160, 210), kind = "quasar" },
	{ id = "sgra", name = "Sagittarius A*", chance = 750000000, income = 1700000000, color = Color3.fromRGB(255, 160, 70), kind = "blackhole" },
	{ id = "ton618", name = "TON 618", chance = 900000000, income = 2000000000, color = Color3.fromRGB(255, 120, 60), kind = "blackhole" },
	{ id = "galaxy", name = "Galaxy Core", chance = 1000000000, income = 2500000000, color = Color3.fromRGB(255, 205, 110) },
	{ id = "darkmatter", name = "Dark Matter Star", chance = 3000000000, income = 8000000000, color = Color3.fromRGB(150, 90, 220) },
	{ id = "cosmic", name = "Cosmic String", chance = 10000000000, income = 30000000000, color = Color3.fromRGB(130, 255, 200) },
	{ id = "multiverse", name = "Multiverse", chance = 30000000000, income = 100000000000, color = Color3.fromRGB(120, 220, 255) },
	{ id = "bigbang", name = "Big Bang", chance = 100000000000, income = 400000000000, color = Color3.fromRGB(255, 120, 80) },
	{ id = "cosmicweb", name = "Cosmic Web", chance = 300000000000, income = 1300000000000, color = Color3.fromRGB(170, 190, 255) },
	{ id = "infinity", name = "Infinity Star", chance = 1000000000000, income = 5000000000000, color = Color3.fromRGB(200, 160, 255) },
}

-- Seasonal stars: each season (2 weeks) five of them can be rolled, then they're gone until the season comes back.
Stars.SeasonDays = 14
Stars.Seasons = { "frost", "ember", "bloom" }
Stars.Seasonal = {
	{ id = "frostcomet", name = "Frost Comet", chance = 5000, income = 5000, color = Color3.fromRGB(170, 230, 255), kind = "point", season = 1 },
	{ id = "icenova", name = "Ice Nova", chance = 50000, income = 50000, color = Color3.fromRGB(140, 210, 255), kind = "sphere", season = 1 },
	{ id = "aurorastar", name = "Aurora Star", chance = 500000, income = 520000, color = Color3.fromRGB(120, 255, 200), kind = "giant", season = 1 },
	{ id = "glacierpulsar", name = "Glacier Pulsar", chance = 5000000, income = 5500000, color = Color3.fromRGB(200, 240, 255), kind = "pulsar", season = 1 },
	{ id = "wintercrown", name = "Winter Crown", chance = 50000000, income = 60000000, color = Color3.fromRGB(230, 245, 255), kind = "galaxy", season = 1 },
	{ id = "embercomet", name = "Ember Comet", chance = 5000, income = 5000, color = Color3.fromRGB(255, 150, 80), kind = "point", season = 2 },
	{ id = "phoenixstar", name = "Phoenix Star", chance = 50000, income = 50000, color = Color3.fromRGB(255, 110, 50), kind = "sphere", season = 2 },
	{ id = "solarflare", name = "Solar Flare", chance = 500000, income = 520000, color = Color3.fromRGB(255, 200, 60), kind = "giant", season = 2 },
	{ id = "magmapulsar", name = "Magma Pulsar", chance = 5000000, income = 5500000, color = Color3.fromRGB(255, 80, 40), kind = "pulsar", season = 2 },
	{ id = "infernocrown", name = "Inferno Crown", chance = 50000000, income = 60000000, color = Color3.fromRGB(255, 60, 90), kind = "galaxy", season = 2 },
	{ id = "petalcomet", name = "Petal Comet", chance = 5000, income = 5000, color = Color3.fromRGB(255, 170, 220), kind = "point", season = 3 },
	{ id = "bloomnova", name = "Bloom Nova", chance = 50000, income = 50000, color = Color3.fromRGB(255, 130, 200), kind = "sphere", season = 3 },
	{ id = "springstar", name = "Spring Star", chance = 500000, income = 520000, color = Color3.fromRGB(170, 255, 140), kind = "giant", season = 3 },
	{ id = "emeraldpulsar", name = "Emerald Pulsar", chance = 5000000, income = 5500000, color = Color3.fromRGB(60, 230, 130), kind = "pulsar", season = 3 },
	{ id = "verdantcrown", name = "Verdant Crown", chance = 50000000, income = 60000000, color = Color3.fromRGB(120, 255, 170), kind = "galaxy", season = 3 },
}

-- Hybrid stars: can't be rolled, only made by FUSION at the Star Forge (two different stars -> one hybrid).
-- recipe = the two star ids; players discover the recipes themselves.
Stars.Hybrids = {
	{ id = "twinkle", name = "Twinkle Star", recipe = { "dust", "spark" }, kind = "point", color = Color3.fromRGB(255, 250, 200) },
	{ id = "greydwarf", name = "Twilight Dwarf", recipe = { "browndwarf", "whitedwarf" }, kind = "sphere", color = Color3.fromRGB(190, 170, 210) },
	{ id = "crimsonsun", name = "Crimson Sun", recipe = { "dwarf", "sun" }, kind = "sphere", color = Color3.fromRGB(255, 90, 60) },
	{ id = "violetgiant", name = "Violet Giant", recipe = { "redgiant", "giant" }, kind = "giant", color = Color3.fromRGB(190, 110, 255) },
	{ id = "trinary", name = "Trinary Star", recipe = { "sun", "binary" }, kind = "binary", color = Color3.fromRGB(255, 230, 120) },
	{ id = "beacon", name = "Cosmic Beacon", recipe = { "pulsar", "neutron" }, kind = "pulsar", color = Color3.fromRGB(120, 255, 240) },
	{ id = "stormstar", name = "Storm Star", recipe = { "wolfrayet", "hypergiant" }, kind = "giant", color = Color3.fromRGB(255, 140, 220) },
	{ id = "blazar", name = "Blazar", recipe = { "pulsar", "quasar" }, kind = "quasar", color = Color3.fromRGB(255, 120, 255) },
	{ id = "goldenkilonova", name = "Golden Kilonova", recipe = { "neutron", "kilonova" }, kind = "remnant", color = Color3.fromRGB(255, 210, 90) },
	{ id = "twinlights", name = "Twin Lights", recipe = { "sirius", "vega" }, kind = "binary", color = Color3.fromRGB(200, 220, 255) },
	{ id = "chimera", name = "Chimera Nebula", recipe = { "eagle", "horsehead" }, kind = "nebula", color = Color3.fromRGB(255, 150, 120) },
	{ id = "milkomeda", name = "Milkomeda", recipe = { "whirlpool", "andromeda" }, kind = "galaxy", color = Color3.fromRGB(220, 200, 255) },
}

Stars.ById = {}
Stars.ByIndex = {}
for index, star in Stars.List do
	star.index = index
	Stars.ById[star.id] = star
	Stars.ByIndex[index] = star
end
for i, star in Stars.Seasonal do
	star.index = #Stars.List + i -- after the normal stars (not part of the Index tiers / Forge chain)
	Stars.ById[star.id] = star
	Stars.ByIndex[star.index] = star
end

for i, hybrid in Stars.Hybrids do
	local a, b = Stars.ById[hybrid.recipe[1]], Stars.ById[hybrid.recipe[2]]
	hybrid.hybrid = true
	hybrid.chance = math.max(a.chance, b.chance) * 3 -- counts as rarer than both parents
	hybrid.income = (a.income + b.income) * 2
	hybrid.index = #Stars.List + #Stars.Seasonal + i
	Stars.ById[hybrid.id] = hybrid
	Stars.ByIndex[hybrid.index] = hybrid
end

-- hybrid made from two star ids (order doesn't matter), or nil
function Stars.fusion(a: string, b: string)
	for _, hybrid in Stars.Hybrids do
		local r = hybrid.recipe
		if (r[1] == a and r[2] == b) or (r[1] == b and r[2] == a) then
			return hybrid
		end
	end
	return nil
end

-- which season is running (1..#Seasons) and how many seconds are left
function Stars.season(now: number): number
	return math.floor(now / (Stars.SeasonDays * 86400)) % #Stars.Seasons + 1
end
function Stars.seasonLeft(now: number): number
	local length = Stars.SeasonDays * 86400
	return length - now % length
end

return Stars
