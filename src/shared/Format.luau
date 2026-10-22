--!strict
-- Number formatting shared by server signs and client UI.

local Format = {}

-- 15000 → "15,000"
function Format.commas(value: number): string
	local text = tostring(math.floor(value))
	local sign, digits = string.match(text, "^(%-?)(%d+)$")
	if not digits then
		return text
	end
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	return (sign or "") .. (string.gsub(grouped, "^,", ""))
end

-- 15000 → "$15,000"
function Format.money(value: number): string
	return "$" .. Format.commas(value)
end

-- Stamina with one decimal, without a trailing ".0": 20 → "20", 23.4 → "23.4".
function Format.stamina(value: number): string
	local text = string.format("%.1f", math.floor(value * 10 + 0.5) / 10)
	return (string.gsub(text, "%.0$", ""))
end

return Format
