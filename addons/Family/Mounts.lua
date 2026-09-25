-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- How fast a character can travel.
--
-- Asked for from play as *has this alt got a mount, and is it the fast one*. Family already
-- recorded both halves of the answer and could not read either: the spellbook is a list of spell
-- ids and the bags are a list of item ids, and nothing said which of them was a horse.
--
-- **Keyed on the mount, never on the riding skill**, and Classic Era is what makes that obvious.
-- There the skill is a permission: its value is always 300 once you have it, one character can
-- hold several of them - a human exalted with Darnassus buys tiger riding and then a tiger - and
-- a paladin's or a warlock's mount is a class spell that teaches no riding skill at all. A column
-- keyed on the skill would print *cannot ride* over a paladin on a horse. From Burning Crusade
-- the skill does become the ladder, but the mount is still the evidence, so one key answers on
-- every build and nothing here branches on which one is running.
--
-- The numbers come from `MountSpeeds.lua`, generated from the client's own tables.

-- **What this cannot see, named by Alberto when the shape was chosen and deferred on purpose.**
-- Owning the mount is evidence of the permission, and losing it is not evidence of losing the
-- permission: a character who earned tiger riding, bought a tiger and then destroyed it still may
-- buy another, and this will say they are on foot. Rare, real, and not worth a second source
-- until somebody meets it - backlog entry 19.

local _, Family = ...

local Mounts = {}
Family.Mounts = Mounts

-- The fastest thing this record can summon: on the ground, and in the air. Either may be nothing.
--
-- **Two numbers and not one.** Flying is a second speed on the same spell rather than a faster
-- mount - an Ebon Gryphon is +60% on the ground and +60% in the air, an epic flyer +100% and
-- +280% - so a reader that took the larger of the two would call a gryphon a hundred per cent
-- mount and never say the character can fly. Reported from play 2026-09-06 for exactly that.
--
-- Nothing is an honest answer and is not nought: a character whose spellbook and bags have never
-- been read has no answer here, and a nought would say *on foot* about somebody nobody has looked
-- at (§2.2). The caller tells the two apart by having asked whether either was read at all.
function Mounts:Fastest(payload)
	if type(payload) ~= "table" then return nil end

	local speeds = Family.MountSpeeds
	if type(speeds) ~= "table" then return nil end

	local air = Family.MountFlight or {}
	local best, flying

	local function consider(id)
		if not id then return end
		local speed = speeds[id]
		if speed and (not best or speed > best) then best = speed end
		local wings = air[id]
		if wings and (not flying or wings > flying) then flying = wings end
	end

	-- Learned. Paladins and warlocks on every build, and everybody from Burning Crusade on.
	for _, school in ipairs(payload.spells or {}) do
		for _, id in ipairs(school.spells or {}) do consider(id) end
	end

	-- Carried, which is what a mount is on Classic Era: an item in a bag rather than a spell.
	local items = Family.MountItems
	if type(items) == "table" then
		for _, bag in pairs(payload.bags or {}) do
			for _, slot in pairs((type(bag) == "table" and bag.slots) or {}) do
				consider(slot.id and items[slot.id])
			end
		end
	end

	return best, flying
end

-- The same question on a client that keeps a mount journal, where the answer comes apart
-- differently.
--
-- From Cataclysm the mount stopped carrying its speed and the riding skill started carrying all of
-- it: `MountCapability` maps a required rank to the aura that applies the number, so Master Riding
-- upgrades every mount already owned and there is no such thing as a 310% mount. The mount's
-- **type** is what says which rungs it can use - a ground mount stops at Journeyman's 100% however
-- high the skill goes, because its type has no rung above 150.
--
-- So this reads two things and multiplies them: the rank says *how fast*, and the journal says
-- *whether there is anything to be that fast on*, and whether any of it flies.
--
-- **Usable and not merely collected.** Measured on a live Mists paladin by counting how many rows
-- carry each field: field 11 is true for seven - what the account owns - and field 5 for three,
-- which is what this character can ride. The four in between are flyers the account has and a
-- rank-150 paladin cannot, so field 5 already takes the riding skill into account and is the only
-- one that answers per character.
function Mounts:FromJournal(rank, payload)
	local journal = _G.C_MountJournal
	if not (journal and journal.GetMountIDs and journal.GetMountInfoByID) then return nil end

	local ladder = Family.RidingLadder
	local rung = type(ladder) == "table" and ladder[rank or 0] or nil
	if not rung then return nil end

	local ids = Family:TryCall(journal.GetMountIDs)
	if type(ids) ~= "table" then return nil end

	local flies = Family.MountFlies or {}
	local any, wings = false, false

	for _, id in ipairs(ids) do
		local _, spell, _, _, usable = Family:TryCall(journal.GetMountInfoByID, id)
		if usable then
			any = true
			if spell and flies[spell] then wings = true end
		end
	end

	-- **And a druid, whose wings are not in the journal at all.** A flight form is a spell in
	-- the book, so a reading that asked the journal alone said a druid could not fly - reported
	-- from play by one who knows Swift Flight Form and owns no flying mount. What the forms
	-- carry is aura 201, enable-flight, and the rung above supplies the number the form does
	-- not. It counts as something to ride, too: a druid with a form and no mount can still get
	-- about.
	local lifts = Family.FlightSpells
	if type(lifts) == "table" then
		for _, school in ipairs((payload or {}).spells or {}) do
			for _, id in ipairs(school.spells or {}) do
				if lifts[id] then
					any, wings = true, true
					break
				end
			end
		end
	end

	-- Nothing usable is not slowness, it is having no mount - and §2.2 says that is an answer
	-- rather than a nought. The caller falls through to the other reading, which on this build
	-- will find nothing either, and the panel says so.
	if not any then return nil end

	return rung[1], (wings and rung[2]) or nil
end

-- Worked out where the record is, and written down as one number.
--
-- Recomputed rather than accumulated: a mount sold is a mount gone, and a `max` kept against what
-- was there before would go on claiming it for ever. Both scanners that can change the answer call
-- this, so whichever ran last leaves it right.
--
-- One field, so it costs a Wide Family link a number rather than a spellbook - which is the whole
-- reason it is worked out here and not in the panel: a sibling shares no bags and no spells, and
-- would otherwise have no answer at all.
-- **Midnight: ground speed from the riding spell, flying as its style.** The skill sheet there
-- lists professions only, and the game shows no flying speed anywhere - Mists' `RidingLadder`
-- priced Master Riding at 310% and Alberto called it wrong (`docs/MIDNIGHT.md` §81). What the
-- client does say, read on Ahia on the PTR, 12.1.5, 2026-09-25 (§80, §85):
--
-- - only the highest riding spell learnt answers known - Master Riding 90265 true, Apprentice
--   33388, Journeyman 33391 and Expert 34090 false - and the mount's aura is +100% on the ground
--   from Journeyman up, +60% at Apprentice;
-- - `C_MountJournal.IsDragonridingUnlocked()` answers whether this character flies at all;
-- - the flying style chosen is an aura on the character, 404464 *Flight Style: Skyriding* or 404468
--   *Flight Style: Steady*, and there are moments with neither, when nothing is said.
--
-- Asked of the character being played only, as everything here that is a question about this
-- client's player.
local RIDING_SPELLS = {
	{ 90265, 100 }, -- Master Riding
	{ 34090, 100 }, -- Expert Riding
	{ 33391, 100 }, -- Journeyman Riding
	{ 33388, 60 },  -- Apprentice Riding
}

local FLIGHT_STYLES = { [404464] = "skyriding", [404468] = "steady" }

local function knows(spell)
	local old = Family:TryCall(_G.IsSpellKnown, spell)
	if old ~= nil then return old end
	return Family:TryCall(_G.C_SpellBook and _G.C_SpellBook.IsSpellKnown, spell)
end

-- An aura's id is looked up inside `pcall`: Midnight hands some values over as secrets, and a
-- secret cannot be used as a key (§75).
local AURAS_AT_MOST = 60
local function flightStyle()
	local auras = _G.C_UnitAuras
	for index = 1, AURAS_AT_MOST do
		local aura = Family:TryCall(auras and auras.GetAuraDataByIndex, "player", index, "HELPFUL")
		if type(aura) ~= "table" then return nil end
		local ok, style = pcall(function() return FLIGHT_STYLES[aura.spellId] end)
		if ok and style then return style end
	end
	return nil
end

function Mounts:Styled()
	local ground
	for _, row in ipairs(RIDING_SPELLS) do
		if knows(row[1]) then ground = row[2] break end
	end
	if not ground then return nil end

	local journal = _G.C_MountJournal
	local unlocked = Family:TryCall(journal and journal.IsDragonridingUnlocked)
	return ground, unlocked and flightStyle() or nil
end

function Mounts:Recompute(key)
	if not key then return end

	local payload = Family.Database:Payload(key)
	if not payload then return end

	-- The journal first, where there is one: on those builds the mount holds no speed and this
	-- is the only reading that is right. 762 is the riding skill line every build that has a
	-- journal uses - an id, and the same number in every language.
	local meta = Family.Database:Meta(key)
	local riding = meta and meta.skills and meta.skills[762]

	local ground, flying = self:FromJournal(riding and riding.rank, payload)
	if not ground then ground, flying = self:Fastest(payload) end

	local style
	if not ground and Family.Capabilities:Has("skyriding") and key == Family:CurrentMember() then
		ground, style = self:Styled()
	end

	Family.Database:SetMeta(key, {
		mount = ground or Family.CLEAR,
		mountFly = flying or Family.CLEAR,
		flightStyle = style or Family.CLEAR,
	})
end
