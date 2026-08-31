-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What is ready, and what is not ready yet.
--
-- A transmute, a bolt of mooncloth, a salt shaker: things that can be done once a day and are
-- therefore forgotten by exactly the character who could do them. This is the one question in
-- an alt manager where the answer changes on its own while nobody is looking, which is why it
-- is worth saying out loud rather than waiting to be asked.
--
-- Two scanners fill this in and neither knows about the other: professions records what its
-- windows said, bags records what the things in them said. Both write into meta, in small
-- plain lists - there are three or four of these on a busy character - so that a broker
-- tooltip or a login message can read every member's without decoding anybody's payload.
--
-- Everything is stored as the moment it comes ready rather than as time remaining, for the
-- same reason mail expiry is: a countdown written down yesterday is wrong today, and a moment
-- is still true.

local _, Family = ...

local Cooldowns = {}
Family.Cooldowns = Cooldowns

--------------------------------------------------------------------------------------------

-- Everything one member is waiting on, soonest first. Each is
--   { name, readyAt, ready, profession, id }
-- where name may be missing for an item the client has not named yet - it is asked for by id
-- like everything else (§2.1), and the caller redraws when the answer arrives.
function Cooldowns:For(meta)
	if not meta then return {} end

	local now = time()
	local found = {}

	-- A crafting cooldown with no moment on it is one that is not running, which is the
	-- answer rather than a gap: a recipe is in this list at all only because Family has
	-- watched it on cooldown once, so "no readyAt" means available and nothing else.
	for _, entry in ipairs(meta.craftCooldowns or {}) do
		found[#found + 1] = {
			kind = "craft",
			name = entry.name,
			profession = entry.profession,
			readyAt = entry.readyAt,
			ready = (entry.readyAt or 0) <= now,
		}
	end

	-- An item's cooldown is dropped the moment it comes ready, and a craft's is not. The two
	-- look alike and are not alike, and the difference is what Family can still know.
	--
	-- **Using a craft needs the profession window open**, and Family scans that window, so
	-- when a transmute is used the fresh cooldown is recorded. A transmute still reading
	-- "ready" is therefore real evidence: it has not been used since.
	--
	-- **Using an item needs nothing open at all.** A salt shaker, a mana stone, a trinket -
	-- these are used out of the bags, and Family sees nothing. So once the moment passes,
	-- "ready" has stopped meaning "waiting for you" and means only "it was on cooldown the
	-- last time anybody looked, and that was a while ago". It could have been used and
	-- re-used a dozen times since. Announcing it is claiming knowledge Family does not have,
	-- which §2.2 forbids in the other direction and forbids here too.
	--
	-- While it is still counting down it is a fact and it is kept: "ready in two hours" is
	-- something Family does know.
	for _, entry in ipairs(meta.itemCooldowns or {}) do
		if entry.readyAt and entry.readyAt > now then
			found[#found + 1] = {
				kind = "item",
				id = entry.id,
				name = entry.id and Family.Names:CachedItem(entry.id) or nil,
				readyAt = entry.readyAt,
				ready = false,
			}
		end
	end

	table.sort(found, function(a, b) return (a.readyAt or 0) < (b.readyAt or 0) end)
	return found
end

-- Whether a recipe has a cooldown at all, and how long it is, from the client's own tables.
--
-- `GetTradeSkillCooldown` answers with the time remaining and nothing at all when there is
-- none, so a transmute that is ready looks exactly like a bandage. Family learned it by
-- watching - and a character had to be caught mid-transmute once before anything would say
-- they had one. `RecipeCooldowns.lua` is generated from `SpellCooldowns` and answers without
-- anybody having watched.
--
-- **By expansion**, because the same spell differs: Transmute: Mithril to Truesilver is 48
-- hours on Classic Era, 20 on Burning Crusade and gone on Mists. **By item as well as by
-- spell**, because a recipe on Era often arrives with an item id and no spell at all.
--
-- Nil where the table has never heard of it, which is not a claim that there is no cooldown -
-- watching still fills those in.
function Cooldowns:Known(spellID, itemID)
	local expansion = Family.Capabilities and Family.Capabilities.expansion
	local here = expansion and (Family.RecipeCooldowns or {})[expansion]
	if not here then return nil end

	if spellID and here.spell then
		local seconds = here.spell[spellID]
		if seconds then return seconds end
	end

	if itemID and here.item then
		local seconds = here.item[itemID]
		if seconds then return seconds end
	end

	return nil
end

-- How many of a member's cooldowns have come ready, and when the next one will.
function Cooldowns:Summarise(meta)
	local ready, next_ = 0, nil

	for _, entry in ipairs(self:For(meta)) do
		if entry.ready then
			ready = ready + 1
		elseif not next_ or entry.readyAt < next_ then
			next_ = entry.readyAt
		end
	end

	return ready, next_
end

--------------------------------------------------------------------------------------------
-- Crafting cooldowns, grouped the way a person thinks about them
--
-- Thirty alchemy transmutes share one timer. Listing thirty of them answers a question nobody
-- asked; what somebody wants to know is whether *the transmute* is available, once.
--
-- Family works that out rather than being told it, because being told it would mean a table of
-- which recipes share a cooldown, per expansion, kept by hand. Recipes of one profession that
-- carry the same readyAt are on the same timer - that is what sharing a cooldown *is*, and it
-- is visible in the data without anybody writing it down. A group of one keeps the recipe's
-- own name; a group of several takes the profession's, because that is what it has become.
--
-- Items belong here too. A salt shaker is a leatherworking cooldown wearing an item's clothes:
-- the cooldown is on the item, and nothing in the client says which profession it answers to -
-- but Family records what each recipe makes, so an item on cooldown that one of this member's
-- recipes produces belongs to that recipe's profession (Scanners/Professions.lua).
--
-- Each entry is
--   { key, label, profession, ready, readyAt, count, item }
-- where `key` is stable across members and across draws, so a table can make a column of it.
--------------------------------------------------------------------------------------------

function Cooldowns:Crafting(meta)
	if not meta then return {} end

	local now = time()
	local groups, order = {}, {}

	local function group(key, label, profession)
		local found = groups[key]
		if not found then
			found = { key = key, label = label, profession = profession,
				ready = true, count = 0 }
			groups[key] = found
			order[#order + 1] = found
		end
		return found
	end

	for _, entry in ipairs(meta.craftCooldowns or {}) do
		-- The profession is recorded as an **identity** - a skill line id on the clients that
		-- have one, and the word it was recorded under where they do not. So it groups by
		-- itself and is never shown by itself.
		--
		-- Shown by itself is exactly what happened. Where two recipes share one timer the
		-- label became the profession, that profession was the number 171, and `shortened`
		-- in the summary refuses anything that is not a string and draws "?" instead. The
		-- transmute column has been headed "?" on every client with skill line ids, which is
		-- all three - and it only ever showed up on a shared timer, which is why it looked
		-- like a translation fault and is not one.
		local profession = entry.profession
		local named = Family:ProfessionName(profession)

		-- Running ones are keyed by the moment they come back, which is what puts every
		-- recipe on one timer into one group. Ready ones share a key of their own, for the
		-- same reason: they are all "the transmute", and it is available.
		local when = entry.readyAt and entry.readyAt > now and entry.readyAt or nil
		local found = group(tostring(profession or "?") .. "\1" .. tostring(when or "ready"),
			entry.name or named, profession)

		found.count = found.count + 1
		if found.count > 1 then found.label = named end

		if when then
			found.ready = false
			if not found.readyAt or when < found.readyAt then found.readyAt = when end
		end
	end

	-- Items, running or ready. A ready one is shown here and is still not *announced* at
	-- login: this panel is a table somebody chose to open and read, and the login message is
	-- a claim pushed at them. `For` above says why the second one stays cautious - an item is
	-- used out of the bags with nothing open - and the difference is deliberate.
	for _, entry in ipairs(meta.itemCooldowns or {}) do
		local when = entry.readyAt and entry.readyAt > now and entry.readyAt or nil
		local found = group("item\1" .. tostring(entry.id),
			(entry.id and Family.Names:CachedItem(entry.id))
				or ("item " .. tostring(entry.id)),
			(meta.cooldownItems or {})[entry.id])

		found.count = found.count + 1
		found.item = entry.id

		if when then
			found.ready = false
			found.readyAt = when
		end
	end

	-- Ready first, because that is the half anybody is looking for, then soonest back.
	table.sort(order, function(a, b)
		if a.ready ~= b.ready then return a.ready end
		if a.ready then return tostring(a.label) < tostring(b.label) end
		return (a.readyAt or 0) < (b.readyAt or 0)
	end)

	return order
end

-- Every member with something ready, by name. The question a login message answers.
function Cooldowns:Ready()
	local members = {}

	for key, entry in pairs(Family.Database:Members()) do
		local ready = self:Summarise(entry.meta)
		if ready > 0 then
			members[#members + 1] = {
				key = key,
				name = (entry.meta or {}).name or key,
				count = ready,
			}
		end
	end

	table.sort(members, function(a, b) return a.name < b.name end)
	return members
end

--------------------------------------------------------------------------------------------
-- What may be told to somebody else (§7.1, §4.5)
--------------------------------------------------------------------------------------------

-- Every cooldown of this member's that can honestly cross the wire, one flat list.
--
-- It lives here rather than in Guild.lua because the rule it keeps is this file's rule, argued
-- at length above: **a craft may say it is ready and an item may not.** A craft is used through
-- a window Family scans, so a transmute still reading ready is evidence that it has not been
-- used; an item is used out of the bags where Family sees nothing, so "ready" would mean only
-- "it was running the last time anybody looked". Guild share makes that worse rather than
-- better - the reader is a different player looking at a record of unknown age - so the item
-- half crosses while it is still counting down, which is a fact, and stops there.
--
-- Durations rather than moments, and this is the one place in Family that sends one. Two
-- clients need not agree about what time it is; a duration is right whoever reads it, and the
-- other end turns it back into a moment the instant it arrives.
--
-- **Identifiers, never names** (§2.1). A cooldown Family only has a word for is one that
-- cannot cross, and it is left out rather than sent in a language the reader may not read.
-- Both ids ride along for the reason slice 2's recipe lists carry both: which of the two a
-- client hands over differs by expansion, and the far end matches on either.
--
-- Each row is { profession, spell, item, left, bags }, where `profession` is the key
-- Scanners/Professions.lua files that profession under and `left` is absent for a craft that
-- is ready. The caller decides which professions are shared; this decides what is true.
function Cooldowns:Sharable(meta)
	if not meta then return {} end

	local now = time()
	local out = {}

	for _, entry in ipairs(meta.craftCooldowns or {}) do
		local spell = tonumber(entry.spellID) or 0
		local item = tonumber(entry.itemID) or 0
		local left = entry.readyAt and entry.readyAt - now or nil

		if (spell ~= 0 or item ~= 0) and entry.profession then
			out[#out + 1] = {
				profession = entry.profession,
				spell = spell ~= 0 and spell or nil,
				item = item ~= 0 and item or nil,
				-- A moment that has passed is a craft that is ready, which crosses as
				-- the absence of a duration rather than as a zero.
				left = (left and left > 0) and left or nil,
			}
		end
	end

	-- Which profession an item's cooldown answers to is worked out by the scanner, from what
	-- this member's own recipes make, and it is the only thing that can say so - nothing in
	-- the client relates a salt shaker to leatherworking. An item no recipe of theirs
	-- produces belongs to no profession, so there is no tick that could have offered it and
	-- it does not cross.
	for _, entry in ipairs(meta.itemCooldowns or {}) do
		local profession = entry.id and (meta.cooldownItems or {})[entry.id]
		local left = entry.readyAt and entry.readyAt - now or nil

		if profession and left and left > 0 then
			out[#out + 1] = {
				profession = profession,
				item = entry.id,
				left = left,
				bags = true,
			}
		end
	end

	return out
end
