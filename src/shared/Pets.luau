-- Star pets: equipped stars orbit the player like little planets.
-- Every pet adds luck (rarer star = more), mutated pets also make rolls faster.
local Items = require(script.Parent.Items)
local Config = require(script.Parent.Config)

local Pets = {}

Pets.BaseSlots = 2

function Pets.slots(data): number
	return Pets.BaseSlots + Config.RebirthUp(data, "pets")
end

-- extra luck share of one pet: 1/100 -> +10%, 1/1M -> +30%, 1/1B -> +45%
function Pets.luck(key: string): number
	local chance = Items.chance(key)
	if chance <= 1 then
		return 0
	end
	return math.floor(math.log10(chance) * 5 + 0.5) / 100
end

-- roll speed share: Shiny 5%, Golden 10%, Void 15%, Celestial 20%
function Pets.speed(key: string): number
	local _, mutation = Items.parse(key)
	if not mutation or mutation.index <= 1 then
		return 0
	end
	return (mutation.index - 1) * 0.05
end

function Pets.totals(list): (number, number)
	local luck, speed = 0, 0
	for _, key in list or {} do
		luck += Pets.luck(key)
		speed += Pets.speed(key)
	end
	return luck, speed
end

return Pets
