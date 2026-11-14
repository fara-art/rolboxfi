local Format = {}

-- K, M, B, T, Qd (quadrillion), Qn (quintillion), Sx, Sp, Oc, No, Dc, ...
local suffixes = {
	"", "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qdd", "Qnd", "Sxd", "Spd", "Ocd", "Nvd", "Vg",
}

function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "inf"
	end
	local negative = n < 0
	n = math.abs(n)
	local out
	if n < 1000 then
		out = tostring(math.floor(n * 10 + 0.5) / 10)
	else
		local i = 1
		while n >= 1000 and i < #suffixes do
			n /= 1000
			i += 1
		end
		if n >= 1000 then
			out = string.format("%.2e", n * 1000 ^ (i - 1))
		else
			out = string.format("%.2f", n):gsub("%.?0+$", "") .. suffixes[i]
		end
	end
	return (if negative then "-" else "") .. out
end

-- "5Qd", "1.5e12", "250K" -> number (admin input)
function Format.parse(text: string): number?
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("%s", ""):gsub(",", "")
	local plain = tonumber(text)
	if plain then
		return plain
	end
	local num, suffix = string.match(text, "^([%d%.]+)(%a+)$")
	num = tonumber(num)
	if not num then
		return nil
	end
	for i, s in suffixes do
		if s ~= "" and string.lower(s) == string.lower(suffix) then
			return num * 1000 ^ (i - 1)
		end
	end
	return nil
end

function Format.percent(p: number): string
	if p >= 0.01 then
		return string.format("%.2f%%", p * 100)
	end
	if p >= 0.000001 then
		return (string.format("%.6f%%", p * 100):gsub("0+%%$", "%%"))
	end
	return string.format("%.1e%%", p * 100)
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
