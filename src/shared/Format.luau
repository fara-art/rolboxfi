local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

function Format.number(n: number): string
	if n < 1000 then
		return tostring(math.floor(n * 10 + 0.5) / 10)
	end
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	return string.format("%.2f", n):gsub("%.?0+$", "") .. suffixes[i]
end

function Format.percent(p: number): string
	if p >= 0.01 then
		return string.format("%.2f%%", p * 100)
	end
	return (string.format("%.6f%%", p * 100):gsub("0+%%$", "%%"))
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
