local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")

local max, min, floor, tonumber, bit, type, pairs, ipairs, next, tinsert, tconcat, tremove, tostring = math.max, math.min, math.floor, tonumber, bit, type, pairs, ipairs, next, table.insert, table.concat, table.remove, tostring
local round = function(val) return floor(val + .5) end

local dummyFrameXmlDoc = XmlDoc.CreateFromTable({__XmlNode = "Forms", [1] = {__XmlNode = "Form", Name = "Form"}})


local Utilities = setmetatable({
	version = nil
}, {__index = _G})

setfenv(1, Utilities)



function Init(parent)
	Apollo.LinkAddon(parent, Utilities)
end

function GetAddonVersion()
	if Utilities.version then
		return Utilities.version
	end
	Utilities.version = XmlDoc.CreateFromFile("toc.xml"):ToTable().Version
	return Utilities.version
end

function GetColorBetween(from, to, position)
	local r, g, b = HSV2RGB((to[1] - from[1]) * position + from[1], (to[2] - from[2]) * position + from[2], (to[3] - from[3]) * position + from[3])
	return ("%02X%02X%02X"):format(r, g, b)
end

function GetFrame(parent, handler)
	return Apollo.LoadForm(dummyFrameXmlDoc, "Form", parent, handler)
end

-- "ffff0000" -> a, r, g, b [0..1]
function HexToNumbers(hex)
	hex = tonumber(hex, 16) or 0
	return bit.rshift(hex, 24) / 255, bit.band(bit.rshift(hex, 16), 0xff) / 255, bit.band(bit.rshift(hex, 8), 0xff) / 255, bit.band(hex, 0xff) / 255
end

-- r, g, b [0..1]
-- h [0..360], s, v [0..1]
function RGB2HSV(r, g, b)
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
function HSV2RGB(h, s, v)
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

function Round(num, digits)
	local mult = 10^(digits or 0)
	return floor(num * mult + .5) / mult
end

function Serialize(t)
	local type = type(t)
	if type == "string" then
		return ("%q"):format(t)
	elseif type == "table" then
		local tbl = {"{"}
		local indexed = #t > 0
		local hasValues = false
		for k, v in pairs(t) do
			hasValues = true
			tinsert(tbl, indexed and Serialize(v) or "[" .. Serialize(k) .. "]=" .. Serialize(v))
			tinsert(tbl, ",")
		end
		if hasValues then
			tremove(tbl, #tbl)
		end
		tinsert(tbl, "}")
		return tconcat(tbl)
	end
	return tostring(t)
end

function Deserialize(str)
	local func = loadstring("return {" .. str .. "}")
	if func then
		setfenv(func, {})
		local succeeded, ret = pcall(func)
		if succeeded then
			return unpack(ret)
		end
	end
	return nil
end

function DeepCopy(t)
	if type(t) == "table" then
		local copy = {}
		for k, v in next, t do
			copy[DeepCopy(k)] = DeepCopy(v)
		end
		return copy
	else
		return t
	end
end

function Extend(...)
	local args = {...}
	for i = 2, #args do
		for key, value in pairs(args[i]) do
			args[1][key] = value
		end
	end
	return args[1]
end

function GetKeyByValue(tbl, val)
	for k, v in pairs(tbl) do
		if v == val then
			return k
		end
	end
end

function ParseStrings(str)
	local strings = {}
	local position = 0
	while true do
		local start = position + 1
		start = str:find("%S", position)
		if not start then
			break
		end
		local char = str:sub(start, start)
		local quotes = char == "\"" or char == "'"
		if quotes then
			start = start + 1
			position = str:find(char, start)
			while true do
				if position then
					if str:sub(position - 1, position - 1) == "\\" then
						position = str:find(char, position + 1)
					else
						break
					end
				else
					break
				end
			end
		else
			position = str:find("%s", start + 1)
		end
		position = position and position or #str + 1
		local sub = str:sub(start, position - 1)
		tinsert(strings, quotes and sub:gsub("\\" .. char, char) or sub)
	end
	return strings
end

VinceRaidFrames.Utilities = Utilities
