-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The creatures a character keeps, and what each of them can do.
--
-- A hunter's pets and a warlock's demons are the one thing these clients file under a
-- creature rather than under the character, which is why they are read here rather than in
-- Scanners/Character.lua beside the spellbook: the same hunter has four different books
-- depending on which pet is out, and the character's own book holds none of them.
--
-- Everything below rests on four measurements, all of them in DATASOURCES under
-- *A hunter's stable, and a warlock's demon* and *The pet book is the creature's, and the
-- creature has an id*:
--
--   1. `GetStablePetInfo` answers with the stable shut - names, levels and families - and
--      **slot 0 repeats slot 1**, on both clients that have a stable at all. A nil slot is a
--      gap and not the end of the list, so the walk runs the whole range.
--   2. `HasPetSpells()` answers `nil` with nothing summoned and a count with a creature out.
--      So a book can only be read at the moment its creature is out, and a record of all of
--      them is something Family accumulates over time - the same shape as a recipe list,
--      which is only readable while its window is open.
--   3. `UnitCreatureFamily` answers with the family's name **and a number**, and the number
--      is the same on every client for the same family: Owl is 26 on Era and on Burning
--      Crusade, Imp is 23 on both. That is the identity §2.1 asks for. The word beside it is
--      the reader's own language and is never what anything is filed under.
--   4. The book itself hands over no spell id by any of its own calls - `GetSpellBookItemLink`
--      does not exist on either older client - but a **tooltip** aimed at a book slot answers
--      `GetSpell()` with one, on Era included. So an ability is stored by id like every other
--      spell, with the word the book printed kept beside it for the client that has never
--      heard of another build's id.
--
-- What is deliberately not stored is the number `GetSpellBookItemInfo(i, "pet")` hands back
-- second. It is a `PETACTION`, it moves with the rank, and it differs between builds for the
-- same ability. Filing anything under it would be filing it under a bar position.

local Family = _G.Family

local Pets = {}
Family.Pets = Pets

-- Four is what the clients with a stable answer for, and the walk starts at nought because
-- that slot answers too. Both ends measured rather than assumed.
local STABLE_FIRST, STABLE_LAST = 0, 4

--------------------------------------------------------------------------------------------
-- Which creature this is
--------------------------------------------------------------------------------------------

-- The creature id inside a pet's GUID, which is the sixth field:
--
--     Pet-0-5208-0-20-6516-01008A56D5
--                       \_ gorilla
--
-- For a demon it is the whole identity - the Imp is 416 on Era and on Burning Crusade - and
-- for a hunter's pet it names the tamed NPC rather than the family, which is why the family
-- id is recorded beside it rather than instead of it: two owls are 7456 on Era and 1997 on
-- Burning Crusade and both are family 26.
local function creatureFrom(guid)
	if type(guid) ~= "string" then return nil end

	local fields = {}
	for piece in guid:gmatch("[^%-]+") do fields[#fields + 1] = piece end

	return tonumber(fields[6])
end

-- What a creature is filed under.
--
-- A demon is its family and nothing else: a warlock has one Imp, and summoning it again is
-- the same Imp. A hunter's pet is a name as well, because a hunter can keep four of the same
-- family and tell them apart only by what they were called - and the name is the player's own
-- word, which is the one place in Family where a name is the key because there is no id for
-- the individual creature anywhere in the client's answer.
function Pets:KeyFor(kind, familyID, name)
	if kind == "DEMON" then
		if not familyID then return nil end
		return "d:" .. familyID
	end

	if not name or name == "" then return nil end
	return "p:" .. (familyID or "?") .. ":" .. name
end

--------------------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------------------

-- The stable, which answers with the door shut.
--
-- Deduplicated on what the client said rather than by skipping slot 0, because which of the
-- two indices *means* the current pet was not settled by the measurement and does not need to
-- be: what is wanted is the pets, and two rows the client describes identically are one pet
-- as far as anything here can tell.
function Pets:ReadStable()
	local found, seen = {}, {}

	for slot = STABLE_FIRST, STABLE_LAST do
		local _, name, level, family = Family:TryCall(GetStablePetInfo, slot)

		if type(name) == "string" and name ~= "" then
			local mark = name .. "\30" .. tostring(level) .. "\30" .. tostring(family)

			if not seen[mark] then
				seen[mark] = true
				found[#found + 1] = {
					name = name,
					level = tonumber(level),
					-- The family as a word, because the stable gives no number for it -
					-- only `UnitCreatureFamily` does, and only for the creature that is
					-- out. So a stabled pet reaches its family id the first time it is
					-- summoned, and until then this word is all there is.
					family = type(family) == "string" and family ~= "" and family or nil,
				}
			end
		end
	end

	return #found > 0 and found or nil
end

-- One creature's book, read while that creature is out.
function Pets:ReadAbilities()
	local count, kind = Family:TryCall(HasPetSpells)

	count = tonumber(count)
	if not count or count < 1 then return nil, nil end

	local found, identified = {}, 0

	for index = 1, count do
		-- Two returns: the name and the rank as a word - *Rank 2*, or *Passive* for one
		-- that has no rank. Both are in the reader's language, which is why the id below
		-- is what this is filed under and these are what is drawn when there is no id.
		local name, rank = Family:TryCall(GetSpellBookItemName, index, "pet")

		local id = Family:ScanTooltipSpell(function(tip)
			Family:TryCall(tip.SetSpellBookItem, tip, index, "pet")
		end)

		if id then identified = identified + 1 end

		if id or (type(name) == "string" and name ~= "") then
			found[#found + 1] = {
				id = id,
				name = type(name) == "string" and name ~= "" and name or nil,
				rank = type(rank) == "string" and rank ~= "" and rank or nil,
			}
		end
	end

	-- Mists puts the pet's own bar in the pet's book: seven of a cat's fifteen rows are
	-- Assist, Attack, Defensive, Follow, Move To, Passive and Stay, which are buttons rather
	-- than anything the pet has learned. Era and Burning Crusade hold none of them.
	--
	-- The client says which is which without being asked in any language: a command has no
	-- spell id - `Attack` answers nothing where `Claw` answers 16827 and `Growl` 2649 - so
	-- *has an id* is the filter. The two obvious alternatives are both guesses: the rank word
	-- is *Pet Command* in English and something else everywhere, and the `PETACTION` number
	-- is a bar position nothing may be filed under.
	--
	-- Only where the client identified something, though. A book where **nothing** came back
	-- with an id is a client whose tooltip will not describe a pet book at all, and there the
	-- words are all there is - dropping them would turn a whole hunter's page blank rather
	-- than leaving it a language behind.
	if identified > 0 then
		local abilities = {}
		for _, entry in ipairs(found) do
			if entry.id then abilities[#abilities + 1] = entry end
		end
		found = abilities
	end

	if #found == 0 then return nil, kind end

	-- Sorted so that two reads of an unchanged creature write an identical list and the
	-- record does not churn - the same reason the spellbook is sorted.
	table.sort(found, function(a, b)
		if (a.id or 0) ~= (b.id or 0) then return (a.id or 0) < (b.id or 0) end
		return tostring(a.name) < tostring(b.name)
	end)

	return found, kind
end

-- The creature that is out, or nothing.
function Pets:ReadOut()
	local abilities, kind = self:ReadAbilities()

	-- A book is what says a creature is out. `UnitExists("pet")` would say so as well, but
	-- a creature with no book is a creature there is nothing to record about, and the count
	-- is the same call that has to be made anyway.
	if not abilities then return nil end

	local family, familyID = Family:TryCall(UnitCreatureFamily, "pet")
	local name = Family:TryCall(UnitName, "pet")

	local key = self:KeyFor(kind, tonumber(familyID), name)
	if not key then return nil end

	return {
		key = key,
		kind = kind,
		name = type(name) == "string" and name ~= "" and name or nil,
		level = tonumber((Family:TryCall(UnitLevel, "pet"))),
		familyID = tonumber(familyID),
		family = type(family) == "string" and family ~= "" and family or nil,
		creature = creatureFrom((Family:TryCall(UnitGUID, "pet"))),
		abilities = abilities,
		seen = time(),
	}
end

--------------------------------------------------------------------------------------------
-- Recording
--
-- In the payload rather than in meta: a hunter with four pets carries four books of a dozen
-- abilities each, and meta is what the summary reads for every member without decoding
-- anybody (HANDOFF §1).
--
-- `known` accumulates and is never pruned by a scan. A creature that is not out today has not
-- gone away, and the only way to read one at all is to have it out - so a scan that replaced
-- the table would leave a hunter with whichever pet happened to be summoned last and call the
-- other three unknown (§2.2).
--------------------------------------------------------------------------------------------

function Pets:Scan()
	local key = Family:CurrentMember()
	if not key then return end

	local payload = Family.Database:Payload(key) or {}
	local record = payload.pets or {}
	local known = record.known or {}

	local stable = self:ReadStable()
	local out = self:ReadOut()

	-- Nothing read at all leaves the record alone rather than writing an empty one. A
	-- character who has stabled every pet and summoned none answers neither call, and that
	-- is not evidence that what was recorded before is wrong. It is also every scan a mage
	-- ever runs, which is the common case and must not touch the record at all.
	if not stable and not out then return end

	if out then known[out.key] = out end

	record.known = known
	-- The stable is a whole answer every time it answers, so it replaces rather than
	-- accumulates: a pet released is gone from it, and keeping the old row would report a
	-- pet the hunter no longer has.
	if stable then record.stable = stable end
	record.seen = time()

	payload.pets = record
	Family.Database:SetPayload(key, payload)

	local count = 0
	for _ in pairs(known) do count = count + 1 end

	Family:Debug("scanned pets: %d in the stable, %d creature(s) known%s",
		stable and #stable or 0, count,
		out and (", " .. tostring(out.name or out.family) .. " out") or "")
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("pets", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "pets", function()
		Family:After(5, "pets", function() Pets:Scan() end)
	end)

	-- `UNIT_PET` is the summon and the dismissal; `PET_BAR_UPDATE` is the book arriving,
	-- which is a moment later than the summon and is what makes the first read after a
	-- summon find anything. `SPELLS_CHANGED` covers a rank learnt at a trainer while the
	-- creature is already out, and the two stable events cover a swap at the stable master.
	for _, event in ipairs {
		"UNIT_PET",
		"PET_BAR_UPDATE",
		"SPELLS_CHANGED",
		"PET_STABLE_UPDATE",
		"PET_STABLE_SHOW",
	} do
		Family:RegisterEvent(event, "pets", function()
			Family:After(3, "pets", function() Pets:Scan() end)
		end)
	end
end)
