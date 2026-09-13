-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- A family of two hundred, built from real records, for a load test.
--
--     lua5.1 tools/grow-family.lua --into <Family.lua> [--read <Family.lua>]... --out <file>
--         --tier <name>=<count>:<donor key>,<donor key>,...   (one per tier, in order)
--         --realm "<Realm Name>=<count>"                        (one per destination realm)
--
-- Run from the repository root. `--into` is the saved data that is extended; every `--read` is
-- one more file donors may come from. Donors are named by member key, and a tier's copies take
-- its donors in turn. The profile - how many copies of each tier, and how many go to each realm
-- - is the arguments and nothing else, so one tool serves any account.
--
-- **What a copy is.** The donor's record, faithful: payload and meta copied whole, with only the
-- key, `meta.name` and `meta.realm` new. No `mark` and no `partMarks`, so the addon makes them at
-- the first request and the test measures that too. Nothing else in the file is touched - the
-- original members, `wide` and its grants, the name caches - so a copy is shared with no linked
-- family until somebody grants it.
--
-- **Names** are made from syllables, in a fixed order, so two runs of one profile write the same
-- file. None coincides with a member of any file read, whatever its realm, or with another copy.
--
-- **Alliance donors only.** A Horde donor is refused by name and nothing is written: a copy is
-- never moved to another faction, because its payload would still be a Horde character's.
--
-- The real saved data this is run on lives in `tools/live/`, which is ignored by git and never
-- leaves the development machine. The harness checks this tool on small invented fixtures only.

local Grow = {}

--------------------------------------------------------------------------------------------
-- Reading and writing saved data
--------------------------------------------------------------------------------------------

-- The globals a SavedVariables file sets, read into a table of their own.
function Grow.readSaved(path)
	local chunk, problem = loadfile(path)
	if not chunk then return nil, "cannot read " .. path .. ": " .. tostring(problem) end
	local globals = {}
	setfenv(chunk, globals)
	local ok, runProblem = pcall(chunk)
	if not ok then return nil, "cannot run " .. path .. ": " .. tostring(runProblem) end
	if type(globals.FamilyDB) ~= "table" then return nil, path .. " holds no FamilyDB" end
	return globals
end

-- As `Family:MemberKey` writes it (`addons/Family/Core.lua`).
function Grow.memberKey(name, realm)
	return name .. "-" .. ((realm or ""):gsub("%s+", ""))
end

local function keyOrder(a, b)
	local ta, tb = type(a), type(b)
	if ta ~= tb then return ta < tb end
	if ta == "boolean" then return (not a) and b end
	return a < b
end

local function literal(value)
	local kind = type(value)
	if kind == "string" then return string.format("%q", value) end
	if kind == "boolean" then return tostring(value) end
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("a number that cannot be written back: " .. tostring(value))
		end
		if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
			return string.format("%d", value)
		end
		return string.format("%.17g", value)
	end
	error("a value that cannot be written back: " .. kind)
end

local function write(out, value, seen)
	if type(value) ~= "table" then
		out[#out + 1] = literal(value)
		return
	end
	if seen[value] then error("a table that holds itself cannot be written back") end
	seen[value] = true

	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, keyOrder)

	out[#out + 1] = "{\n"
	for _, key in ipairs(keys) do
		out[#out + 1] = "[" .. literal(key) .. "] = "
		write(out, value[key], seen)
		out[#out + 1] = ",\n"
	end
	out[#out + 1] = "}"
	seen[value] = nil
end

-- Every global of a saved file, in the shape the client writes: `Name = { ... }`.
function Grow.serialize(globals)
	local names = {}
	for name in pairs(globals) do names[#names + 1] = name end
	table.sort(names)

	local out = {}
	for _, name in ipairs(names) do
		out[#out + 1] = "\n" .. name .. " = "
		write(out, globals[name], {})
		out[#out + 1] = "\n"
	end
	return table.concat(out)
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, inner in pairs(value) do result[key] = copy(inner) end
	return result
end

--------------------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------------------

local STARTS = { "Al", "Bel", "Cor", "Dar", "El", "Fen", "Gar", "Hal", "Ir", "Jor", "Kel", "Lor",
	"Mar", "Nor", "Or", "Per", "Quin", "Ros", "Sel", "Tor", "Ul", "Val", "Wen", "Yor", "Zel" }
local MIDDLES = { "a", "e", "i", "o", "u", "ae", "ia" }
local ENDS = { "dan", "wyn", "ric", "nor", "len", "mir", "thas", "dor", "ris", "gan", "lia",
	"wen", "mor", "tis" }

local NAMES = #STARTS * #MIDDLES * #ENDS
-- A stride with no factor in common with the count, so that the walk visits every name once and
-- neighbouring copies do not share their first syllable.
local STRIDE = 1009

local function nameAt(position)
	local index = (position * STRIDE) % NAMES
	local e = index % #ENDS
	index = (index - e) / #ENDS
	local m = index % #MIDDLES
	local s = (index - m) / #MIDDLES
	return STARTS[s + 1] .. MIDDLES[m + 1] .. ENDS[e + 1]
end

-- A source of names none of which is in `taken` (lower-cased), and none twice.
local function names(taken)
	local position = 0
	return function()
		for _ = 1, NAMES do
			local name = nameAt(position)
			position = position + 1
			if not taken[name:lower()] then
				taken[name:lower()] = true
				return name
			end
		end
		error("out of names")
	end
end

--------------------------------------------------------------------------------------------
-- Growing a family
--------------------------------------------------------------------------------------------

-- The tier of every copy, in the order copies are made: interleaved so that every stretch of the
-- list holds each tier in proportion - which is what gives every destination realm its share of each.
local function interleave(tiers)
	local total = 0
	for _, tier in ipairs(tiers) do total = total + tier.count end

	local taken, list = {}, {}
	for position = 1, total do
		local best, bestDeficit
		for index, tier in ipairs(tiers) do
			local deficit = tier.count * position / total - (taken[index] or 0)
			if (taken[index] or 0) < tier.count and (not best or deficit > bestDeficit) then
				best, bestDeficit = index, deficit
			end
		end
		taken[best] = (taken[best] or 0) + 1
		list[#list + 1] = best
	end
	return list
end

-- Adds the copies a profile asks for to `target` (the globals of the file being extended).
-- `sources` is every file read, `target` among them. Answers the copies made, each as
-- `{ key, donor, tier, realm }`, or nil and what is wrong - in which case nothing was added.
function Grow.grow(target, sources, profile)
	local donors, taken = {}, {}

	for _, source in ipairs(sources) do
		for key, entry in pairs(source.FamilyDB.members or {}) do
			local meta = type(entry) == "table" and entry.meta or {}
			if meta.name then taken[tostring(meta.name):lower()] = true end
			if donors[key] and donors[key] ~= entry then
				return nil, "donor " .. key .. " is in more than one file read"
			end
			donors[key] = entry
		end
	end

	local tierTotal, realmTotal = 0, 0
	for _, tier in ipairs(profile.tiers) do
		if #tier.donors == 0 then return nil, "tier " .. tier.name .. " names no donor" end
		for _, key in ipairs(tier.donors) do
			local entry = donors[key]
			if not entry then return nil, "donor " .. key .. " is in no file read" end
			local faction = entry.meta and entry.meta.faction
			if faction ~= "Alliance" then
				return nil, "donor " .. key .. " is " .. tostring(faction)
					.. ", not Alliance: refused, and never rewritten to another faction"
			end
		end
		tierTotal = tierTotal + tier.count
	end
	for _, realm in ipairs(profile.realms) do realmTotal = realmTotal + realm.count end
	if tierTotal ~= realmTotal then
		return nil, string.format("the tiers ask for %d copies and the realms place %d",
			tierTotal, realmTotal)
	end

	local members = target.FamilyDB.members
	local nextName = names(taken)
	local order = interleave(profile.tiers)
	local made, turns, keysMade = {}, {}, {}
	local realmIndex, realmLeft = 1, profile.realms[1] and profile.realms[1].count or 0

	for _, tierIndex in ipairs(order) do
		while realmLeft == 0 do
			realmIndex = realmIndex + 1
			realmLeft = profile.realms[realmIndex].count
		end
		local realm = profile.realms[realmIndex].name
		realmLeft = realmLeft - 1

		local tier = profile.tiers[tierIndex]
		local turn = (turns[tierIndex] or 0) % #tier.donors + 1
		turns[tierIndex] = turn
		local donorKey = tier.donors[turn]
		local donor = donors[donorKey]

		local name = nextName()
		local key = Grow.memberKey(name, realm)
		if members[key] or keysMade[key] then
			return nil, "a copy's key is already taken: " .. key
		end
		keysMade[key] = true

		made[#made + 1] = { key = key, name = name, donor = donorKey, tier = tier.name, realm = realm,
			entry = donor }
	end

	for _, copyMade in ipairs(made) do
		local entry = {}
		for field, value in pairs(copyMade.entry) do
			if field ~= "mark" and field ~= "partMarks" then entry[field] = copy(value) end
		end
		entry.meta = entry.meta or {}
		entry.meta.name = copyMade.name
		entry.meta.realm = copyMade.realm
		members[copyMade.key] = entry
		copyMade.entry = nil
	end

	return made
end

--------------------------------------------------------------------------------------------
-- From the command line
--------------------------------------------------------------------------------------------

local function parseArguments(argv)
	local options = { reads = {}, tiers = {}, realms = {} }
	local index = 1
	while index <= #argv do
		local flag, value = argv[index], argv[index + 1]
		if value == nil then return nil, flag .. " wants a value" end
		if flag == "--into" then
			options.into = value
		elseif flag == "--read" then
			options.reads[#options.reads + 1] = value
		elseif flag == "--out" then
			options.out = value
		elseif flag == "--tier" then
			local name, count, list = value:match("^([%w_]+)=(%d+):(.*)$")
			if not name then return nil, "--tier wants name=count:key,key,... - got " .. value end
			local tier = { name = name, count = tonumber(count), donors = {} }
			for key in list:gmatch("[^,]+") do tier.donors[#tier.donors + 1] = key end
			options.tiers[#options.tiers + 1] = tier
		elseif flag == "--realm" then
			local name, count = value:match("^(.-)=(%d+)$")
			if not name or name == "" then return nil, "--realm wants \"Realm Name=count\"" end
			options.realms[#options.realms + 1] = { name = name, count = tonumber(count) }
		else
			return nil, "unknown argument " .. flag
		end
		index = index + 2
	end
	if not (options.into and options.out) then return nil, "--into and --out are both needed" end
	if #options.tiers == 0 or #options.realms == 0 then
		return nil, "at least one --tier and one --realm are needed"
	end
	if options.out == options.into then return nil, "--out would overwrite --into" end
	for _, path in ipairs(options.reads) do
		if options.out == path then return nil, "--out would overwrite " .. path end
	end
	return options
end

local function sizeOf(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local size = handle:seek("end")
	handle:close()
	return size
end

function Grow.run(argv)
	local options, problem = parseArguments(argv)
	if not options then
		print("grow-family: " .. problem)
		return 2
	end

	local target, readProblem = Grow.readSaved(options.into)
	if not target then
		print("grow-family: " .. readProblem)
		return 1
	end
	local sources = { target }
	for _, path in ipairs(options.reads) do
		local source, sourceProblem = Grow.readSaved(path)
		if not source then
			print("grow-family: " .. sourceProblem)
			return 1
		end
		sources[#sources + 1] = source
	end

	local before = 0
	for _ in pairs(target.FamilyDB.members or {}) do before = before + 1 end
	local sameShape = #Grow.serialize(target)

	local made, growProblem = Grow.grow(target, sources, options)
	if not made then
		print("grow-family: " .. growProblem .. " - nothing written")
		return 1
	end

	local text = Grow.serialize(target)
	local handle, openProblem = io.open(options.out, "wb")
	if not handle then
		print("grow-family: cannot write " .. options.out .. ": " .. tostring(openProblem))
		return 1
	end
	handle:write(text)
	handle:close()

	local byTier, byRealm = {}, {}
	for _, one in ipairs(made) do
		byTier[one.tier] = (byTier[one.tier] or 0) + 1
		byRealm[one.realm] = (byRealm[one.realm] or 0) + 1
	end

	print(string.format("%s: %d members, %d copies added, %d members now", options.out, before,
		#made, before + #made))
	for _, tier in ipairs(options.tiers) do
		print(string.format("  tier %-10s %4d", tier.name, byTier[tier.name] or 0))
	end
	for _, realm in ipairs(options.realms) do
		print(string.format("  realm %-20s %4d", realm.name, byRealm[realm.name] or 0))
	end
	print(string.format("  weight: %d bytes before (%d written back in this tool's layout), %d after",
		sizeOf(options.into) or 0, sameShape, #text))
	return 0
end

-- Run from the command line, or handed back to whoever loaded it (the harness).
if arg and arg[0] and arg[0]:find("grow%-family%.lua$") then
	os.exit(Grow.run(arg))
end

return Grow
