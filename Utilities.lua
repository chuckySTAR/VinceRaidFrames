local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")

local max = math.max
local min = math.min
local floor = math.floor
local round = function(val) return floor(val + .5) end
local tonumber = tonumber
local bit = bit

local dummyFrameXmlDoc = XmlDoc.CreateFromTable({__XmlNode = "Forms", [1] = {__XmlNode = "Form", Name = "Form"}})

local Utilities = {
	version = nil
}
function Utilities:Init(parent)
	Apollo.LinkAddon(parent, self)
end

function Utilities:GetAddonVersion()
	if Utilities.version then
		return Utilities.version
	end
	Utilities.version = XmlDoc.CreateFromFile("toc.xml"):ToTable().Version
	return Utilities.version
end

function Utilities.GetColorBetween(from, to, position)
	local r, g, b = Utilities.HSV2RGB((to[1] - from[1]) * position + from[1], (to[2] - from[2]) * position + from[2], (to[3] - from[3]) * position + from[3])
	return ("%02X%02X%02X"):format(r, g, b)
end

function Utilities.GetFrame(parent, handler)
	return Apollo.LoadForm(dummyFrameXmlDoc, "Form", parent, handler)
end

-- "ffff0000" -> a, r, g, b [0..1]
function Utilities.HexToNumbers(hex)
	hex = tonumber(hex, 16) or 0
	return bit.rshift(hex, 24) / 255, bit.band(bit.rshift(hex, 16), 0xff) / 255, bit.band(bit.rshift(hex, 8), 0xff) / 255, bit.band(hex, 0xff) / 255
end

-- r, g, b [0..1]
-- h [0..360], s, v [0..1]
function Utilities.RGB2HSV(r, g, b)
	local h
	local v = max(r, g, b)
	local MIN = min(r, g, b)
	local d = v - MIN
	local s = v == 0 and 0 or d / v

	if v == MIN then
		h = 0
	elseif v == r then
		h = (g - b) / d + (b > g and 6 or 0)
	elseif v == g then
		h = (b - r) / d + 2
	else
		h = (r - g) / d + 4
	end

	return h * 60, s, v
end

-- h [0..360], s, v [0..1]
-- r, g, b [0..255]
function Utilities.HSV2RGB(h, s, v)
	local h2 = floor(h / 60)
	local f = h / 60 - h2

	v = round(v * 255)
	local p = round(v * (1 - s))
	local q = round(v * (1 - s * f))
	local t = round(v * (1 - s * (1 - f)))

	if h2 % 6 == 0 then
		return v, t, p
	elseif h2 == 1 then
		return q, v, p
	elseif h2 == 2 then
		return p, v, t
	elseif h2 == 3 then
		return p, q, v
	elseif h2 == 4 then
		return t, p, v
	else
		return v, p, q
	end
end

VinceRaidFrames.Utilities = Utilities
