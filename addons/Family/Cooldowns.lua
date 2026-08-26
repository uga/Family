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
		if entry.readyAt > now then
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
		local profession = entry.profession or "?"

		-- Running ones are keyed by the moment they come back, which is what puts every
		-- recipe on one timer into one group. Ready ones share a key of their own, for the
		-- same reason: they are all "the transmute", and it is available.
		local when = entry.readyAt and entry.readyAt > now and entry.readyAt or nil
		local found = group(profession .. "\1" .. tostring(when or "ready"),
			entry.name or profession, profession)

		found.count = found.count + 1
		if found.count > 1 then found.label = profession end

		if when then
			found.ready = false
			if not found.readyAt or when < found.readyAt then found.readyAt = when end
		end
	end

	for _, entry in ipairs(meta.itemCooldowns or {}) do
		if entry.readyAt and entry.readyAt > now then
			local profession = (meta.cooldownItems or {})[entry.id]
			local found = group("item\1" .. tostring(entry.id),
				(entry.id and Family.Names:CachedItem(entry.id))
					or ("item " .. tostring(entry.id)),
				profession)

			found.count = found.count + 1
			found.item = entry.id
			found.ready = false
			found.readyAt = entry.readyAt
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
