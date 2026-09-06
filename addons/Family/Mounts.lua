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

-- The fastest thing this record can summon, as a percentage over running, or nothing.
--
-- Nothing is an honest answer and is not nought: a character whose spellbook and bags have never
-- been read has no answer here, and a nought would say *on foot* about somebody nobody has looked
-- at (§2.2). The caller tells the two apart by having asked whether either was read at all.
function Mounts:Fastest(payload)
	if type(payload) ~= "table" then return nil end

	local speeds = Family.MountSpeeds
	if type(speeds) ~= "table" then return nil end

	local best

	-- Learned. Paladins and warlocks on every build, and everybody from Burning Crusade on.
	for _, school in ipairs(payload.spells or {}) do
		for _, id in ipairs(school.spells or {}) do
			local speed = speeds[id]
			if speed and (not best or speed > best) then best = speed end
		end
	end

	-- Carried, which is what a mount is on Classic Era: an item in a bag rather than a spell.
	local items = Family.MountItems
	if type(items) == "table" then
		for _, bag in pairs(payload.bags or {}) do
			for _, slot in pairs((type(bag) == "table" and bag.slots) or {}) do
				local speed = slot.id and speeds[items[slot.id] or 0]
				if speed and (not best or speed > best) then best = speed end
			end
		end
	end

	return best
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
function Mounts:Recompute(key)
	if not key then return end

	local payload = Family.Database:Payload(key)
	if not payload then return end

	Family.Database:SetMeta(key, { mount = self:Fastest(payload) or Family.CLEAR })
end
