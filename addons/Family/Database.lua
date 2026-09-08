-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- One saved variable, versioned, with a migration that runs.
--
-- The shape, and the reason for it:
--
--   FamilyDB = {
--     schema  = 1,
--     members = {
--       ["Alberta-Firemaw"] = {
--         meta    = { ... },              -- small, plain, always loaded
--         codec   = "ld1",                -- how payload was written
--         payload = "<encoded>",          -- everything bulky, decoded on demand
--       },
--     },
--   }
--
-- The split between meta and payload is the whole architecture in one line. The summary is
-- the screen that reads every member at once, and it only ever needs the handful of values
-- in meta - money, level, free slots, when we last saw them. Those stay plain and small.
-- Everything that grows with what a character owns - the item in every bag slot - goes in
-- payload, which is decoded for the one member actually being looked at and never for the
-- other thirty-nine.
--
-- Get that split wrong and lazy decoding buys nothing, because the summary forces every
-- record open at login anyway. It is not an optimisation to be added later; it is a decision
-- about which field a value lives in.

local _, Family = ...

local L = Family.L

local Database = {}
Family.Database = Database

local SCHEMA = 1

--------------------------------------------------------------------------------------------
-- Migrations
--
-- One function per step, from the version it upgrades. They run in order, each on the output
-- of the last. A step must be safe to run on a database written by any earlier version, and
-- must never assume a field exists just because the current code writes it.
--------------------------------------------------------------------------------------------

local migrations = {
	-- [1] = function(db) ... end,   -- 1 -> 2, when there is a 2
}

local function migrate(db)
	local from = db.schema or 0

	if from > SCHEMA then
		-- Downgrade. Refuse rather than mangle: an older Family writing over a newer
		-- database is how people lose data they cannot get back.
		Family:Print(L["|cffff5555Your saved data was written by Family schema %d, and this " ..
			"is schema %d.|r Nothing has been changed. Update Family, or move FamilyDB " ..
			"aside if you meant to start over."], from, SCHEMA)
		return false
	end

	if from == SCHEMA then return true end

	for version = from, SCHEMA - 1 do
		local step = migrations[version]
		if step then
			local ok, err = pcall(step, db)
			if not ok then
				Family:Print(L["|cffff5555Migration from schema %d failed|r: %s"], version,
					tostring(err))
				return false
			end
		end
		db.schema = version + 1
	end

	if from > 0 then
		Family:Debug("migrated saved data from schema %d to %d", from, SCHEMA)
	end
	return true
end

--------------------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------------------

function Database:Initialise()
	if type(FamilyDB) ~= "table" then
		FamilyDB = { schema = SCHEMA, members = {} }
	end

	FamilyDB.members = FamilyDB.members or {}
	FamilyDB.ui = FamilyDB.ui or {}

	self.usable = migrate(FamilyDB)
	self.db = FamilyDB

	Family.Codec:Initialise()

	-- Said once, at login, because it changes what the addon can do and the player should
	-- not have to deduce it from a panel being empty.
	if not Family.Codec.compressing then
		Family:Debug("LibSerialize/LibDeflate not present - storing records uncompressed")
	end
end

--------------------------------------------------------------------------------------------
-- Reading and writing members
--------------------------------------------------------------------------------------------

local function record(key, create)
	if not Database.usable then return nil end
	local members = FamilyDB.members
	if not members[key] and create then
		members[key] = { meta = {}, codec = nil, payload = nil }
	end
	return members[key]
end

function Database:Members()
	if not self.usable then return {} end
	return FamilyDB.members
end

-- The cheap read. Never decodes anything.
function Database:Meta(key)
	local entry = record(key, false)
	return entry and entry.meta or nil
end

-- Passed as a value, this removes the field rather than setting it.
--
-- SetMeta merges, so writing nil does nothing at all: the key is simply absent from the
-- table handed in, and the old value survives. That is right for a partial update - a money
-- change should not erase the bag counts - but it means a fact that stops being true has no
-- way to say so. A character reaching the level cap stops having experience, and without
-- this its last rested figure would sit in the summary for ever.
Family.CLEAR = setmetatable({}, { __tostring = function() return "Family.CLEAR" end })

function Database:SetMeta(key, fields)
	local entry = record(key, true)
	if not entry then return end
	entry.meta = entry.meta or {}

	for name, value in pairs(fields) do
		if value == Family.CLEAR then
			entry.meta[name] = nil
		else
			entry.meta[name] = value
		end
	end

	entry.meta.lastSeen = time()
	Database:Changed(key)
end

-- The expensive read, and the reason payload exists. Decoded results are cached in memory
-- for the session, keyed by member, and dropped when that member is written again.
local decoded = {}

function Database:Payload(key)
	if decoded[key] ~= nil then return decoded[key] end

	local entry = record(key, false)
	if not entry or entry.payload == nil then return nil end

	local data, reason = Family.Codec:Decode(entry.codec, entry.payload)
	if data == nil then
		return nil, reason
	end

	decoded[key] = data
	return data
end

-- A short mark of the record as it sits on disk, made without decoding it.
--
-- Two readers, and they ask the same question of it: *has this member changed since I last
-- looked?* The login walk asks so that it can skip a member whose item names it has already
-- fetched, and a Wide Family exchange asks so that it can skip building - and therefore
-- decoding - a member the other side already has. Both used to answer it the expensive way and
-- both answer it here now.
--
-- **Only where the record is a string**, which is the compressed path and the one that has a
-- decode worth skipping. Stored plain - the fallback when the compression libraries are not
-- loaded - the payload *is* the table, `Codec:Decode` hands it straight back, and folding it
-- would cost more than either caller saves. No mark means *not known*, and both callers do the
-- expensive thing rather than guess, which is §2.2 pointed at our own bookkeeping.
--
-- **Every byte, and the first version of this read only the ends.** Folding a 30 KB record
-- costs 1.0 ms in lua5.1 on the machine this was written on and folding its first and last 256
-- bytes costs 0.017 ms, so the ends looked like sixty times the walk for the same answer. They
-- are not the same answer: a record whose length does not change and whose ends do not change
-- reads as unchanged, and a member's language is exactly that - `enUS` and `frFR` are both four
-- bytes, in the middle. The harness flips one and three checks went red, which is what the
-- shortcut costs when it is wrong: a member's recipe names stop being fetched before the click.
--
-- So the whole record is folded, and the number that made the shortcut tempting pays for the
-- cap instead. At 1.0 ms a record, twenty of them is 20 ms on a tick that today decodes a whole
-- member - which is far more than 20 ms - so the cap is less work than the walk already does on
-- every tick, and a family of any size is spread rather than folded at once.
function Database:PayloadMark(key)
	local entry = record(key, false)
	if not entry then return nil end

	-- A member with nothing recorded yet is a fact of its own, and a stable one - so it gets
	-- a mark rather than the nil that means *this cannot be worked out*. The two used to be
	-- the same answer, which made every such member look changed on every comparison.
	if entry.payload == nil then return "none" end

	if type(entry.payload) ~= "string" then return nil end

	-- The codec and the length go in as well as the bytes. The same data written by two
	-- codecs is two different strings, and a mark that did not say which would match across
	-- a change of codec that rewrote every record.
	return string.format("%s:%d:%s", tostring(entry.codec), #entry.payload,
		Family.Codec:Fingerprint(entry.payload))
end

function Database:SetPayload(key, data)
	local entry = record(key, true)
	if not entry then return end

	local codec, encoded = Family.Codec:Encode(data)
	entry.codec = codec
	entry.payload = encoded
	decoded[key] = data

	-- Anything derived from what a member owns is now wrong for that member. Told here
	-- rather than by each scanner, so a scanner added later cannot forget to say so.
	if Family.Index then Family.Index:Invalidate(key) end
	Database:Changed(key)
end

function Database:Forget(key)
	if not self.usable then return false end
	if not FamilyDB.members[key] then return false end
	FamilyDB.members[key] = nil
	decoded[key] = nil
	if Family.Index then Family.Index:Invalidate(key) end
	Database:Changed(key)
	return true
end

--------------------------------------------------------------------------------------------
-- Saying that something changed
--
-- Panels are drawn once and left, so a scan that arrives while one is open used to leave it
-- showing what was true when it was opened: a member who had just walked round every trainer
-- had their professions listed as never opened until something else made the panel redraw.
--
-- Announced from here rather than from each scanner, for the same reason the index is
-- invalidated from here: a scanner written next year cannot forget to do it.
--------------------------------------------------------------------------------------------

local watchers = {}

function Database:OnChanged(name, callback)
	watchers[name] = callback
end

function Database:Changed(key)
	for name, callback in pairs(watchers) do
		local ok, err = pcall(callback, key)
		if not ok then
			Family:Print(L["|cffff5555error telling %s the database changed|r: %s"], name,
				tostring(err))
			watchers[name] = nil
		end
	end
end
