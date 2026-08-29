-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a shared recipe list costs on the addon channel.
--
--     lua5.1 tools/wire-size.lua
--
-- Run from the repository root, and only after tools/FetchLibs.sh: it weighs the real
-- LibSerialize and LibDeflate, which a checkout does not have.
--
-- **Why this is not a harness check.** The harness stubs both libraries with pass-throughs,
-- deliberately - it exists to prove the protocol, and a serialiser that returns its input
-- makes every message the same shape whatever is in it. That is right for testing and
-- useless for weighing, so weighing happens here instead.
--
-- It exists because GUILD-CRAFTERS §4.4 said to measure this rather than trust its own
-- estimate, and the estimate turned out to be about half of the answer.

local root = "addons/Family/Libs/"

-- The handful of globals the game gives these libraries and a bare interpreter does not.
strmatch, strsub, strbyte, strchar = string.match, string.sub, string.byte, string.char
strlen, strrep = string.len, string.rep
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
tinsert, tremove = table.insert, table.remove
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
format, gsub = string.format, string.gsub

local stub = loadfile(root .. "LibStub/LibStub.lua")
if not stub then
	print("no libraries in " .. root .. " - run tools/FetchLibs.sh first")
	os.exit(1)
end
stub()

assert(loadfile(root .. "LibSerialize/LibSerialize.lua"))("LibSerialize", {})
assert(loadfile(root .. "LibDeflate/LibDeflate.lua"))("LibDeflate", {})

local Serialize = LibStub:GetLibrary("LibSerialize")
local Deflate = LibStub:GetLibrary("LibDeflate")

-- Comm.lua's own figures, so this cannot drift from what the channel actually does.
local CHUNK, PER_TICK, TICK = 200, 2, 0.2

math.randomseed(7)

-- One profession's worth of recipes, in the three shapes that were considered.
local function shapes(count)
	local spells, items, paired = {}, {}, {}
	local id = 2000

	for index = 1, count do
		id = id + math.random(1, 400)
		spells[index] = id
		-- Unrelated to the spell id and in no order, which is what an item id actually is.
		-- Deriving one from the other made them sort alongside the spells and compress like
		-- a second run of deltas, which flattered the whole measurement by a tenth.
		items[index] = (index % 5 == 0) and 0 or math.random(2000, 60000)
		paired[index] = { s = spells[index], i = items[index] ~= 0 and items[index] or nil }
	end

	local deltas, previous = {}, 0
	for index = 1, count do
		deltas[index] = spells[index] - previous
		previous = spells[index]
	end

	return { recipes = paired },
		{ spells = spells, items = items },
		{ spells = deltas, items = items }
end

local function weigh(body)
	local raw = Serialize:Serialize(body)
	local squashed = Deflate:CompressDeflate(raw, { level = 9 })
	return #Deflate:EncodeForWoWAddonChannel(squashed)
end

local function chunks(bytes) return math.ceil(bytes / CHUNK) end
local function seconds(n) return n / PER_TICK * TICK end

print(string.format("%-9s %-12s %-12s %-12s %-8s %-9s",
	"recipes", "pairs", "absolute", "deltas", "chunks", "seconds"))

for _, count in ipairs { 50, 150, 250, 400 } do
	local paired, absolute, deltas = shapes(count)
	local best = weigh(deltas)
	print(string.format("%-9d %-12d %-12d %-12d %-8d %-9.1f",
		count, weigh(paired), weigh(absolute), best, chunks(best), seconds(chunks(best))))
end

-- What a character actually sends: two maxed primaries and three secondaries.
local character = 0
for _, count in ipairs { 250, 250, 80, 60, 40 } do
	local _, _, deltas = shapes(count)
	character = character + weigh(deltas)
end

print()
print(string.format("one character, two maxed primaries and three secondaries: "
	.. "%d bytes, %d chunks", character, chunks(character)))
print(string.format("three such characters, which is what §4.4 sizes the feature by: "
	.. "%d bytes, %d chunks, %.1f seconds of queue",
	character * 3, chunks(character * 3), seconds(chunks(character * 3))))
