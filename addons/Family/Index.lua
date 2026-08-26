-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Who owns what, answered without looking.
--
-- The question "which of my members has one of these" arrives on every mouseover, which is
-- the fastest thing a player can do repeatedly. Answering it by walking forty members'
-- possessions each time would mean decoding forty compressed records to draw a tooltip -
-- so it is answered from an index built once and kept until something changes.
--
-- HANDOFF §1: an index, not a scan, invalidated per member. The cost of building it is one
-- pass over everybody, paid the first time anybody asks; the cost of a member changing is
-- one pass over that member.
--
-- Nothing here is written to disk. It is derived entirely from what is already stored, and a
-- saved copy would only be another thing that could disagree with the records it came from.

local _, Family = ...

local Index = {}
Family.Index = Index

local entries       -- itemID -> memberKey -> { bags =, bank =, mail =, auctions = }
local guildEntries  -- itemID -> guildKey -> count
local stale = {}    -- members whose part of the index is known to be wrong

--------------------------------------------------------------------------------------------

local function bucket(itemID, key)
	entries[itemID] = entries[itemID] or {}
	entries[itemID][key] = entries[itemID][key] or
		{ bags = 0, bank = 0, mail = 0, auctions = 0 }
	return entries[itemID][key]
end

local function forget(key)
	if not entries then return end
	for _, byMember in pairs(entries) do
		byMember[key] = nil
	end
end

local function addContainers(key, containers, field)
	for _, container in pairs(containers or {}) do
		for _, item in pairs(container.slots or {}) do
			if item.id then
				local record = bucket(item.id, key)
				record[field] = record[field] + (item.count or 1)
			end
		end
	end
end

-- A member's records, ours or a sibling's.
--
-- §6 says a sibling appears wherever our own members are listed, and an item tooltip is one of
-- those places - arguably the most useful of them, since "who has one of these" is the whole
-- question a shared family is being asked. Siblings only, not everyone a family shares: the
-- ones we have not adopted are explicitly somewhere to go and look, not something to be
-- counted in with our own.
local function payloadOf(key)
	local borrowed = Family.Wide and Family.Wide:Borrowed(key)
	if borrowed then return borrowed.payload end
	return Family.Database:Payload(key)
end

local function addMember(key)
	local payload = payloadOf(key)
	if not payload then return end

	addContainers(key, payload.bags, "bags")
	if payload.bank then addContainers(key, payload.bank.containers, "bank") end

	-- Only mail that has not run out. An attachment on a letter that expired is gone, and
	-- pointing somebody at it would send them looking for something that is not there.
	if payload.mail then
		for _, letter in ipairs(Family.Mail:Live(payload.mail)) do
			for _, item in ipairs(letter.attachments or {}) do
				local record = bucket(item.id, key)
				record.mail = record.mail + (item.count or 1)
			end
		end
	end

	-- Same for auctions: what is still listed, not what was listed on Tuesday.
	if payload.auctions then
		local selling = Family.Auctions:Live(payload.auctions)
		for _, entry in ipairs(selling) do
			if entry.id then
				local record = bucket(entry.id, key)
				record.auctions = record.auctions + (entry.count or 1)
			end
		end
	end
end

local function addGuilds()
	guildEntries = {}

	for guildKey, guild in pairs((FamilyDB and FamilyDB.guilds) or {}) do
		for _, tab in pairs(guild.tabs or {}) do
			for _, item in pairs(tab.slots or {}) do
				if item.id then
					guildEntries[item.id] = guildEntries[item.id] or {}
					guildEntries[item.id][guildKey] =
						(guildEntries[item.id][guildKey] or 0) + (item.count or 1)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------------------

local function rebuild()
	entries = {}
	wipe(stale)

	for key in pairs(Family.Database:Members()) do
		addMember(key)
	end

	for _, sibling in ipairs(Family.Wide and Family.Wide:Siblings() or {}) do
		addMember(sibling.key)
	end

	addGuilds()
end

local function refresh()
	if not entries then
		rebuild()
		return
	end

	if not next(stale) then return end

	-- Only the members that changed, which is the whole point of keeping the list.
	for key in pairs(stale) do
		forget(key)
		addMember(key)
	end
	wipe(stale)

	addGuilds()
end

-- Called whenever a member's stored possessions change. Deliberately cheap: it records that
-- something is wrong rather than putting it right, because a bag update during a vendor
-- sweep fires many times a second and nobody is looking at a tooltip during it.
-- A linked family's records are in this index now, and they change from outside every path
-- that invalidates it: an exchange arrives, a grant is withdrawn, somebody is made a sibling
-- or stops being one. None of those is a member of ours being scanned, so none of them went
-- through Database:SetPayload and none of them said anything to this file. The whole index
-- goes rather than one member's part of it, because "which member" is exactly what these
-- messages do not say.
Family.Database:OnChanged("index.wide", function(what)
	if what == "wide" then Index:Invalidate() end
end)

function Index:Invalidate(key)
	if key then
		stale[key] = true
	else
		entries = nil
	end
end

--------------------------------------------------------------------------------------------

-- Everybody holding this item, as a list of
--   { key, name, classFile, bags, bank, mail, auctions, total }
-- sorted by who has most. Guild banks come back separately: a guild bank belongs to the
-- guild rather than to any one member, and saying "Nervina has 40" of something sitting in
-- a guild vault would be wrong twice over.
-- Every item anybody holds whose name matches, as { id, name }, soonest to say: this is the
-- index read the other way round. It is built from ids and answers with the ones the client
-- has already named, because a name that has not arrived cannot be matched against - and
-- asking the client for every id it has never heard of, to answer a search, would be a great
-- deal of work for an answer nobody waited for.
--
-- Capped, because a two-letter search matches half of everything and a tooltip-sized answer
-- is more use than a complete one.
function Index:Search(needle, limit)
	if type(needle) ~= "string" or needle == "" then return {} end
	refresh()

	needle = needle:lower()
	limit = limit or 200

	local found = {}
	for itemID in pairs(entries or {}) do
		local name = Family.Names:CachedItem(itemID)
		if name and name:lower():find(needle, 1, true) then
			found[#found + 1] = { id = itemID, name = name }
		end
	end

	table.sort(found, function(a, b) return a.name < b.name end)

	while #found > limit do table.remove(found) end
	return found
end

function Index:Owners(itemID)
	if not itemID then return {}, {} end
	refresh()

	local owners = {}
	for key, record in pairs(entries[itemID] or {}) do
		local total = record.bags + record.bank + record.mail + record.auctions
		if total > 0 then
			local borrowed, link = nil, nil
			if Family.Wide then borrowed, link = Family.Wide:Borrowed(key) end
			local meta = (borrowed and borrowed.meta) or Family.Database:Meta(key) or {}

			owners[#owners + 1] = {
				key = key,
				-- Whose they are, where they are not ours. Never left off: a count on a
				-- tooltip is read as "I can go and get that", and for somebody else's
				-- character that is not true.
				familyName = link and link.name or nil,
				name = meta.name or key,
				realm = meta.realm,
				faction = meta.faction,
				classFile = meta.classFile,
				bags = record.bags,
				bank = record.bank,
				mail = record.mail,
				auctions = record.auctions,
				total = total,
			}
		end
	end

	table.sort(owners, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return a.name < b.name
	end)

	local guilds = {}
	for guildKey, count in pairs((guildEntries or {})[itemID] or {}) do
		guilds[#guilds + 1] = { key = guildKey, count = count }
	end
	table.sort(guilds, function(a, b) return a.count > b.count end)

	return owners, guilds
end

-- How many the whole family holds, across everybody and everywhere.
function Index:Total(itemID)
	local owners, guilds = self:Owners(itemID)

	local total = 0
	for _, owner in ipairs(owners) do total = total + owner.total end

	local guildTotal = 0
	for _, guild in ipairs(guilds) do guildTotal = guildTotal + guild.count end

	return total, guildTotal
end
