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
-- **Midnight has none of the three old calls** (`docs/MIDNIGHT.md` §29) and answers the same
-- questions through `C_StableInfo` and `C_SpellBook`, read on the PTR 2026-09-26 (§124). They are
-- asked only where the old ones answer nothing, so the Classic clients keep the route they were
-- measured on:
--
--   - `C_StableInfo.GetActivePetList()` answers with the stable shut: a row a pet, with its name,
--     level, family as a word, `creatureID` and `petNumber`. `GetStabledPetList()` is the rest of
--     the stable, and is taken only while the hunter stands at the stable master: whether it
--     answers with the stable shut was read on a hunter with nothing stabled, which cannot say.
--   - `C_SpellBook.HasPetSpells()` counts the creature's book, and `GetSpellBookItemInfo(i, Pet)`
--     describes each slot as a table whose `spellID` is there for an ability and absent for a
--     command - Claw 16827 beside Attack with none - so the Classic filter holds unchanged.
--     `subName` is the book's second word, *Basic Attack* or *Ferocity Passive*, kept where
--     Classic keeps *Rank 2*.
--   - A hunter's pet's GUID carries a **generic** creature there, 165189 for a cat whose list
--     row says 42718, and the capability `petGuidGeneric` says so; its last field's low half is
--     the list's `petNumber`, which is how the creature that is out finds its row. A demon's
--     GUID is a `Creature-` one and names the demon, 416 for the Imp, as on Classic.
--   - `HasPetSpells()` answers the kind second, `DEMON` for a warlock's Imp, as the old call did.
--
-- What is deliberately not stored is the number `GetSpellBookItemInfo(i, "pet")` hands back
-- second. It is a `PETACTION`, it moves with the rank, and it differs between builds for the
-- same ability. Filing anything under it would be filing it under a bar position.

local _, Family = ...

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

-- The pet number a GUID ends on: its last field's low eight hex digits. `...-0100559D9D` is
-- 5610909, the `petNumber` of the same cat's list row (§124).
local function petNumberFrom(guid)
	if type(guid) ~= "string" then return nil end
	local last = guid:match("%-(%x+)$")
	if not last or #last < 8 then return nil end
	return tonumber(last:sub(-8), 16)
end

local function listRows(call)
	local rows = Family:TryCall(call)
	if type(rows) ~= "table" then return {} end
	return rows
end

local function stableRowFrom(pet, stabled)
	if type(pet) ~= "table" or type(pet.name) ~= "string" or pet.name == "" then return nil end
	return {
		name = pet.name,
		level = tonumber(pet.level),
		family = type(pet.familyName) == "string" and pet.familyName ~= ""
			and pet.familyName or nil,
		-- The tamed creature, which Classic's stable never gave.
		creature = tonumber(pet.creatureID),
		-- Which part of the stable this came from, so a read away from the stable master
		-- can keep the part it could not read (`Pets:Scan`).
		stabled = stabled or nil,
	}
end

-- Midnight's stable: the active pets always, the stabled ones only at the stable master. The
-- second answer says whether the stabled part was read at all.
local function readModernStable()
	local api = _G.C_StableInfo
	if type(api) ~= "table" then return nil end

	local found = {}
	for _, pet in ipairs(listRows(api.GetActivePetList)) do
		found[#found + 1] = stableRowFrom(pet)
	end

	local atMaster = Family:TryCall(api.IsAtStableMaster) == true
	if atMaster then
		for _, pet in ipairs(listRows(api.GetStabledPetList)) do
			found[#found + 1] = stableRowFrom(pet, true)
		end
	end

	return #found > 0 and found or nil, atMaster
end

-- The stable, which answers with the door shut.
--
-- Deduplicated on what the client said rather than by skipping slot 0, because which of the
-- two indices *means* the current pet was not settled by the measurement and does not need to
-- be: what is wanted is the pets, and two rows the client describes identically are one pet
-- as far as anything here can tell.
local function readOldStable()
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

-- The old walk first, so the Classic clients keep the route they were measured on, and
-- Midnight's lists where it finds nothing. The second answer is Midnight's: whether the stabled
-- part was read, which the old walk always reads whole.
function Pets:ReadStable()
	local found = readOldStable()
	if found then return found, true end
	return readModernStable()
end

-- Midnight's book of the creature that is out: its slots by `C_SpellBook`, each a table.
-- `HasPetSpells` answers the count and then the kind, `11 DEMON` for a warlock's Imp (§124); a
-- kind that does not come keys the creature as a hunter's pet.
local function readModernBook()
	local book = _G.C_SpellBook
	local banks = _G.Enum and _G.Enum.SpellBookSpellBank
	if type(book) ~= "table" or type(banks) ~= "table" or banks.Pet == nil then return nil end

	local count, kind = Family:TryCall(book.HasPetSpells)
	count = tonumber(count)
	if not count or count < 1 then return nil end

	local found = {}
	for index = 1, count do
		local item = Family:TryCall(book.GetSpellBookItemInfo, index, banks.Pet)
		local id = type(item) == "table" and tonumber(item.spellID) or nil
		local name = type(item) == "table" and type(item.name) == "string" and item.name ~= ""
			and item.name or nil
		if id or name then
			found[#found + 1] = {
				id = id,
				name = name,
				rank = type(item.subName) == "string" and item.subName ~= ""
					and item.subName or nil,
			}
		end
	end
	return found, type(kind) == "string" and kind or nil
end

-- One creature's book, read while that creature is out.
function Pets:ReadAbilities()
	local count, kind = Family:TryCall(HasPetSpells)

	count = tonumber(count)
	local found, identified = {}, 0

	if not count or count < 1 then
		-- The old count answers nothing: Midnight's book, where there is one.
		local modern, modernKind = readModernBook()
		if not modern then return nil, nil end
		found, kind = modern, modernKind
		for _, entry in ipairs(found) do
			if entry.id then identified = identified + 1 end
		end
		count = 0
	end

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

-- Which creature is out, by id. From its GUID, as measured on Era and Burning Crusade; where
-- the GUID names a generic creature, which is a hunter's pet on Midnight (§124), from the
-- active list's row whose `petNumber` the GUID ends on, or nothing where no row does - a generic
-- number would file every pet under one creature. Only a `Pet-` GUID is generic there: a
-- warlock's Imp answered `Creature-0-5769-0-44-416-...`, 416 being the Imp as on Era.
function Pets:CreatureOut()
	local guid = Family:TryCall(UnitGUID, "pet")
	if not Family.Capabilities:Has("petGuidGeneric")
		or not (type(guid) == "string" and guid:match("^Pet%-")) then
		return creatureFrom(guid)
	end

	local number = petNumberFrom(guid)
	local api = _G.C_StableInfo
	if not number or type(api) ~= "table" then return nil end
	for _, pet in ipairs(listRows(api.GetActivePetList)) do
		if type(pet) == "table" and tonumber(pet.petNumber) == number then
			return tonumber(pet.creatureID)
		end
	end
	return nil
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

	-- What this creature has to spend, which is the one number on the trainer's window that
	-- is about the pet rather than about a row on it.
	--
	-- Two returns, and which is which was settled by a reading rather than by the order they
	-- are documented in: a Burning Crusade pet with seventy-seven points free answered
	-- **350 273**, and the window said 77. So the first is the total, the second is spent,
	-- and the free ones are the difference (measured 2026-09-07).
	--
	-- Nothing is recorded where there is nothing to spend against: Mists has no training
	-- points at all, and a nought there is a claim about a system that build does not have
	-- rather than a pet with none left (§2.2).
	local total, spent = Family:TryCall(GetPetTrainingPoints)
	total, spent = tonumber(total), tonumber(spent)
	if not total or total <= 0 then total, spent = nil, nil end

	local key = self:KeyFor(kind, tonumber(familyID), name)
	if not key then return nil end

	return {
		key = key,
		kind = kind,
		name = type(name) == "string" and name ~= "" and name or nil,
		level = tonumber((Family:TryCall(UnitLevel, "pet"))),
		familyID = tonumber(familyID),
		family = type(family) == "string" and family ~= "" and family or nil,
		creature = self:CreatureOut(),
		trainingTotal = total,
		trainingSpent = total and (spent or 0) or nil,
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

	local stable, whole = self:ReadStable()
	local out = self:ReadOut()

	-- Away from the stable master Midnight's stabled pets are not read, and are not gone: the
	-- ones the last reading at the master found are kept beside the active ones just read.
	if stable and not whole then
		for _, pet in ipairs(record.stable or {}) do
			if pet.stabled then stable[#stable + 1] = pet end
		end
	end

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
	Family.Database:SetPayload(key, payload, "pets")

	local count = 0
	for _ in pairs(known) do count = count + 1 end

	Family:Debug("scanned pets: %d in the stable, %d creature(s) known%s",
		stable and #stable or 0, count,
		out and (", " .. tostring(out.name or out.family) .. " out") or "")
end

--------------------------------------------------------------------------------------------
-- What a creature's abilities cost it
--
-- Two readings of the same character, put beside each other. The creature's book says which
-- abilities it holds and at which rank, by spell id; the trainer's window - which is a Craft
-- window and is recorded with the professions - says what each row costs in training points, by
-- the same spell id. `GetPetTrainingPoints` says how many the creature has spent altogether.
--
-- So the sum of the priced abilities can be held against the number the client gave, and that is
-- a question worth asking rather than an answer worth assuming: **whether the trainer's window
-- prices a rank the creature already holds is not measured anywhere in this repository.** The
-- window prices what the creature that is out *can learn* (DATASOURCES), and whether that
-- includes the rank it is already on is exactly what this arithmetic finds out.
--
-- Which is why it reports the working and not a verdict: how many abilities could be priced, how
-- many could not, and what the priced ones add up to. A total that matched would confirm the
-- model; one that falls short by the abilities that could not be priced says which reading is
-- missing rather than that the pet is wrong. §2.2, pointed at our own arithmetic.
--------------------------------------------------------------------------------------------

function Pets:Training(payload)
    payload = payload or {}

    -- Every priced row this character's trainer window has ever shown, by spell id. Only the
    -- rows that carry a cost: a craft window that is not Beast Training answers nought for
    -- every row, and nought is not stored (§2.2).
    -- The cost and not the row, so that a row without one stores nothing rather than storing a
    -- row whose cost is nil. Writing nil into a table is writing nothing, which makes *has no
    -- price* and *is not in the window* the same absence here - and they are, because neither
    -- can be added up.
    local priced = {}

    -- And the same rows by the word they were recorded under, which is **not** how anything is
    -- joined and is only ever shown.
    --
    -- The join is by spell id (§2.1) and stays that way: a word is the reader's own language and
    -- two ranks of one ability share it. But when a creature holds an ability the window prices
    -- and the two ids do not meet, the useful thing to put in front of somebody is *here is what
    -- the window has under that name* - which turns a gap into a reading rather than a mystery.
    -- Ranghesante's Avoidance is exactly that: priced at 15 and 25 in the window, unmatched in
    -- the book, and worth 25 by the arithmetic.
    local named = {}

    for _, record in pairs(payload.crafts or {}) do
        for _, entry in ipairs(record.entries or {}) do
            if entry.spellID then priced[entry.spellID] = entry.trainingPoints end

            if type(entry.name) == "string" and entry.name ~= "" then
                named[entry.name] = named[entry.name] or {}
                local rows = named[entry.name]
                rows[#rows + 1] = entry
            end
        end
    end

    local creatures = {}

    for key, creature in pairs((payload.pets or {}).known or {}) do
        local abilities, counted, unpriced, nameless = {}, 0, 0, 0

        for _, ability in ipairs(creature.abilities or {}) do
            local points = ability.id and priced[ability.id]

            if points then
                counted = counted + points
            elseif not ability.id then
                -- A client that would not name the ability at all cannot be asked to price
                -- it either, and that is a different absence from *the window never showed
                -- this row*. Counted apart so the report can say which.
                nameless = nameless + 1
            else
                unpriced = unpriced + 1
            end

            abilities[#abilities + 1] = {
                id = ability.id,
                name = ability.name,
                rank = ability.rank,
                points = points or nil,
                -- Only where it could not be priced, and only ever to be shown: what the
                -- window holds under the same word. Nothing is joined by it.
                near = not points and ability.name and named[ability.name] or nil,
            }
        end

        table.sort(abilities, function(a, b)
            if (a.name or "") ~= (b.name or "") then
                return tostring(a.name) < tostring(b.name)
            end
            return (a.id or 0) < (b.id or 0)
        end)

        creatures[#creatures + 1] = {
            key = key,
            name = creature.name,
            family = creature.family,
            level = creature.level,
            total = creature.trainingTotal,
            spent = creature.trainingSpent,
            counted = counted,
            unpriced = unpriced,
            nameless = nameless,
            abilities = abilities,
        }
    end

    table.sort(creatures, function(a, b)
        local left = a.name or a.family or ""
        local right = b.name or b.family or ""
        if left ~= right then return left < right end
        return tostring(a.key) < tostring(b.key)
    end)

    return creatures
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
