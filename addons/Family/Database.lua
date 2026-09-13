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
--         codec   = "plain",              -- how payload was written
--         payload = { ... },              -- everything bulky, as the table itself
--         mark    = "w1789000000.3f2a9c1.12", -- moves when payload is written, and only then
--       },
--     },
--   }
--
-- **Payload was stored compressed until backlog 74** (codec `"ld1"`, a string) and decoded on
-- demand. Why that stopped is in the section on unpacking at the end of this file. A record still
-- stored the old way is read, and rewritten plain, the first time anything reads it.
--
-- The split between meta and payload is the whole architecture in one line. The summary is
-- the screen that reads every member at once, and it only ever needs the handful of values
-- in meta - money, level, free slots, when we last saw them. Those stay plain and small.
-- Everything that grows with what a character owns - the item in every bag slot - goes in
-- payload, which the summary never touches.
--
-- The split was first argued as what made lazy decoding worth anything. There is no decoding
-- now, and the split still decides what the one screen that reads everybody has to walk.

local _, Family = ...

local L = Family.L

local Database = {}
Family.Database = Database

local SCHEMA = 1

-- How a record written by this version is stored: the table itself, handed to the game's own
-- saved-variables writer. `Codec:Decode` answers it unchanged.
local PLAIN = "plain"

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
	-- The other end of the saved data's parse; the first is taken in `Loaded.lua`.
	if type(_G.debugprofilestop) == "function" then Family.savedReadAt = _G.debugprofilestop() end

	if type(FamilyDB) ~= "table" then
		FamilyDB = { schema = SCHEMA, members = {} }
	end

	FamilyDB.members = FamilyDB.members or {}
	FamilyDB.ui = FamilyDB.ui or {}

	self.usable = migrate(FamilyDB)
	self.db = FamilyDB

	Family.Codec:Initialise()

	-- Said once, at login, because it changes what the addon can do and the player should
	-- not have to deduce it from a panel being empty. Records are stored plain either way; what
	-- the libraries are missed for is sharing, and reading a record still stored compressed.
	if not Family.Codec.compressing then
		Family:Debug("LibSerialize/LibDeflate not present - no sharing, and records still "
			.. "stored compressed cannot be read")
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

-- The bulky read. Held for the session, keyed by member, and replaced when that member is
-- written again. Since backlog 74 the table held is the stored table itself; it was a decoded
-- copy while records were stored compressed, and a record still stored that way is decoded here
-- once and rewritten plain.
local decoded = {}

-- And the mark of the same record, kept beside it for the same reason and dropped at the same
-- moment. The mark cannot change while the record is not written - and both callers ask for it
-- far more often than the record changes.
--
-- **It is the multiplication that made this worth having.** A Wide Family exchange marks the
-- members one link was granted, and a family with fifteen links marks the same member fifteen
-- times in the same second: two hundred and ten members over fifteen links is three thousand
-- one hundred and fifty folds at every login, of two hundred and ten different records. False
-- means *asked and there is no mark to be had*, which is a different answer from *not asked*
-- and is worth caching too; since stamps, only a payload that is neither a table nor a string
-- answers it.
local marks = {}

function Database:Payload(key)
	if decoded[key] ~= nil then return decoded[key] end

	local entry = record(key, false)
	if not entry or entry.payload == nil then return nil end

	-- Stored plain, which is every record written since backlog 74: nothing to undo.
	if type(entry.payload) == "table" then
		decoded[key] = entry.payload
		return entry.payload
	end

	-- **A record from before 74: its mark first, while the string it is a fold of still exists.**
	local oldMark = self:ReadPayloadMark(key)

	local data, reason = Family.Codec:Decode(entry.codec, entry.payload)
	if data == nil then
		return nil, reason
	end

	-- **And then rewritten plain, straight into the entry and not through `SetPayload`.** The
	-- data has not changed, so neither may anything that says it has: the mark stays the fold
	-- of the old string, so a Wide Family link that sent this member holds it back and the name
	-- walk steps past it; no new stamp, no `Changed`, nothing invalidated in the index. A write
	-- would have done all three, and on the first exchange after updating every member of every
	-- family would have gone again.
	--
	-- Only a table is written back; anything else a string could decode to is left where it is.
	if type(data) == "table" then
		entry.mark = entry.mark or oldMark
		entry.codec = PLAIN
		entry.payload = data
		-- Asked again of the entry from here on, as the next session will ask it: an answer held
		-- from the string would hide a rewrite that got the mark wrong until the next login.
		marks[key] = nil
	end

	decoded[key] = data
	return data
end

-- A short mark of the record as it sits on disk, made without reading it.
--
-- Two readers, and they ask the same question of it: *has this member changed since I last
-- looked?* The login walk asks so that it can skip a member whose item names it has already
-- fetched, and a Wide Family exchange asks so that it can skip building - and therefore
-- decoding - a member the other side already has. Both used to answer it the expensive way and
-- both answer it here now.
--
-- **Made of what the record holds, part by part, since 2026-09-13** (data-path review, step 6).
-- Each part of a payload - `bags`, `quests`, `professions` and the rest - has its own mark, a
-- stable fold of that part (`Codec:StableFingerprint`: the moments things were looked at left
-- out, deadlines rounded to the minute), kept beside the record in `entry.partMarks`. The record's
-- mark is a fold of those. A scanner says which part it wrote, and only that part is folded again:
-- a loot pays for `bags`, about 3 ms, not for the whole record's 35 (`/family paycost`, backlog 72).
-- A write that names no part folds them all. A part no write of this version has marked yet is
-- folded the first time the mark is asked for, once.
--
-- **Why content and not a stamp.** Backlog 74 stamped every write, and a login rewrites the parts
-- its scanners read, so an idle relog moved the mark and sent the member to every linked family
-- again - read on the client as `ld1:7510:2347148292` against `ld1:7510:1867974627` before stamps,
-- and certain with them. A mark made of contents without their clocks stays still when nothing
-- changed, and moves with the part that did.
--
-- **A record this version has never written keeps the mark it had** - the fold of the string it
-- was stored as, or a 74 stamp - until its first write here. Only characters actually played get
-- a new mark, so an update does not resend a family's thirty alts nobody logged in.
--
-- **A record still stored as a string** is folded as before; that fold becomes its `mark` when it
-- is rewritten plain (`Payload`).
--
-- **Every byte of a string, and the first version of this read only the ends.** Folding a 30 KB record
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
-- The record's mark out of its part marks, folding any part not marked yet. Answers nil for a
-- payload that is not a table.
local function composeMark(entry)
	if type(entry.payload) ~= "table" then return nil end
	entry.partMarks = entry.partMarks or {}
	local parts = entry.partMarks
	for part, value in pairs(entry.payload) do
		if parts[part] == nil then parts[part] = Family.Codec:StableFingerprint(value) end
	end
	for part in pairs(parts) do
		if entry.payload[part] == nil then parts[part] = nil end
	end
	return "p" .. Family.Codec:Fingerprint(parts)
end

function Database:PayloadMark(key)
	local held = marks[key]
	if held ~= nil then
		if held == false then return nil end
		return held
	end

	local mark = self:ReadPayloadMark(key)
	marks[key] = mark or false
	return mark
end

function Database:ReadPayloadMark(key)
	local entry = record(key, false)
	if not entry then return nil end

	-- A member with nothing recorded yet is a fact of its own, and a stable one - so it gets
	-- a mark rather than the nil that means *this cannot be worked out*. The two used to be
	-- the same answer, which made every such member look changed on every comparison.
	if entry.payload == nil then return "none" end

	-- Never written by this version: the mark it came with, as long as it has one.
	if entry.partMarks == nil and type(entry.mark) == "string" then return entry.mark end

	if type(entry.payload) == "table" then return composeMark(entry) end

	if type(entry.payload) ~= "string" then return nil end

	-- The codec and the length go in as well as the bytes. The same data written by two
	-- codecs is two different strings, and a mark that did not say which would match across
	-- a change of codec that rewrote every record.
	return string.format("%s:%d:%s", tostring(entry.codec), #entry.payload,
		Family.Codec:Fingerprint(entry.payload))
end

-- **How often records are written this session, and which parts each write replaced.**
--
-- Asked for by backlog 72, which wants to mark each part of a record at the moment it is written
-- and so pays that cost on every write - and a bag scan is a write, after every loot. A part counts
-- as replaced when the write carries a different table for it than the last write of that member
-- did: every scanner builds its own part afresh and leaves the others as they were, so that is the
-- part it wrote. A part changed in place without a new table is missed, so the counts are a floor.
-- Nothing here is saved; it is a reading of one session.
local writes = { total = 0, since = time(), parts = {} }
local lastParts = {}

function Database:Writes() return writes end

-- `parts`, where given, is the name of the part this write replaced or a list of them. Given by
-- every scanner; a write without it folds every part again.
function Database:SetPayload(key, data, parts)
	local entry = record(key, true)
	if not entry then return end

	writes.total = writes.total + 1
	if type(data) == "table" then
		local before, now = lastParts[key] or {}, {}
		for part, value in pairs(data) do
			if before[part] ~= value then
				writes.parts[part] = (writes.parts[part] or 0) + 1
			end
			now[part] = value
		end
		lastParts[key] = now
	end

	-- Stored as the table itself (backlog 74), and its part marks brought up to date.
	entry.codec = PLAIN
	entry.payload = data
	entry.mark = nil
	if type(data) == "table" then
		if type(parts) == "string" then parts = { parts } end
		if type(parts) == "table" and entry.partMarks then
			for _, part in ipairs(parts) do
				entry.partMarks[part] = data[part] ~= nil
					and Family.Codec:StableFingerprint(data[part]) or nil
			end
		else
			-- The first write this version makes of a record, or one that names no part.
			entry.partMarks = {}
			if type(parts) == "table" then
				for _, part in ipairs(parts) do
					if data[part] ~= nil then
						entry.partMarks[part] = Family.Codec:StableFingerprint(data[part])
					end
				end
			else
				for part, value in pairs(data) do
					entry.partMarks[part] = Family.Codec:StableFingerprint(value)
				end
			end
		end
	else
		entry.partMarks = nil
	end
	decoded[key] = data
	marks[key] = nil

	-- Anything derived from what a member owns is now wrong for that member. Told here
	-- rather than by each scanner, so a scanner added later cannot forget to say so.
	if Family.Index then Family.Index:Invalidate(key) end
	Database:Changed(key)
end

-- **How many records are still stored the old way**, for `/family status`: nought once every
-- record has been read once since backlog 74.
function Database:StillCompressed()
	local count = 0
	for _, entry in pairs(self:Members()) do
		if type(entry) == "table" and type(entry.payload) == "string" then count = count + 1 end
	end
	return count
end

function Database:Forget(key)
	if not self.usable then return false end
	if not FamilyDB.members[key] then return false end
	FamilyDB.members[key] = nil
	decoded[key] = nil
	marks[key] = nil
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

--------------------------------------------------------------------------------------------
-- Unpacking the records still stored compressed, a little at a time after logging in
--
-- **Reported from play 2026-09-13 as *script ran too long*, twice**, under the recipe search and
-- under a recipe tooltip's *who can make it*, each at the first whole-family question after
-- logging a character in. Measured on that client with `/family decodecost`: **31 records, 524 ms
-- to decode**, the largest 35 to 50 ms each. Every whole-family question reads every record, so
-- the first one of a session paid all of that in one frame.
--
-- It used not to, and not by design. The recipe-name warm-up at login read one member a second
-- through `Payload`, which decodes and caches - so the decoding was spread out as a side effect.
-- Backlog 25 then taught that walk to step past members whose names it already had, which was
-- the point of it, and stepping past a member also meant never decoding it. From the second
-- session on nothing was decoded ahead of time at all (L-094).
--
-- So decoding became its own job, one record a step, a moment apart. **Then backlog 74 took the
-- reason for it away.** Alberto: *abbiamo utenti con 200++ alt; non è accettabile un crash perché
-- facciamo una ricerca prima di aver finito di decomprimere* - and at two hundred records the steps
-- take a minute, inside which the crash is still there. Readings taken with every record decoded
-- put the search and the tooltip's question at milliseconds and the decode at over half a second
-- (DECISIONS, 2026-09-13), so the decode was the cost, and records are stored plain. Memory was
-- never an argument for compressing: a decoded record weighs what a plain one does, and the
-- whole-family questions hold every record decoded.
--
-- What is left for this job is the records written before that, **once each**: it reads the next
-- one still stored as a string, and `Payload` rewrites it plain. The character being played
-- first. From the next session there is nothing left, and it finds that in one look.
--------------------------------------------------------------------------------------------

Database.WARM_STEP = Database.WARM_STEP or 0.3

-- Records that would not decode this session, kept apart from the cache so that `Payload` still
-- answers nil for them exactly as it always has.
local undecodable = {}

-- Unpacks the next record still stored compressed. Answers whether any were left to do.
function Database:WarmPayloads()
	if not self.usable or type(FamilyDB) ~= "table" then return false end

	local keys = {}
	for key, entry in pairs(FamilyDB.members or {}) do
		if not undecodable[key] and type(entry) == "table" and type(entry.payload) == "string" then
			keys[#keys + 1] = key
		end
	end
	if #keys == 0 then return false end

	-- The character being played first: theirs is the record somebody is about to open.
	table.sort(keys)
	local playing = Family:CurrentMember()
	local pick = keys[1]
	for _, key in ipairs(keys) do
		if key == playing then pick = key break end
	end

	local _, reason = self:Payload(pick)
	-- A record that will not decode stays as it is, and must not be picked again every step.
	if type(FamilyDB.members[pick].payload) == "string" then
		undecodable[pick] = true
		Family:Debug("could not decode %s: %s", tostring(pick), tostring(reason))
	end

	return #keys > 1
end

Family:OnDatabaseReady("database.warm", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "database.warm", function()
		local function step()
			if Database:WarmPayloads() then
				Family:After(Database.WARM_STEP, "database.warm", step)
			end
		end
		-- After the client's own arrival and the first scans, which rewrite their own records
		-- plain; before the recipe-name walk, which would otherwise pay these one a second.
		Family:After(3, "database.warm", step)
	end)
end)
