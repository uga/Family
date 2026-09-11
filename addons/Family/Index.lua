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
		{ bags = 0, bank = 0, mail = 0, auctions = 0, worn = 0, bound = 0 }
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

				-- **How many of them can no longer be sold at an auction house.**
				--
				-- Backlog 63: an auction price is a price for the unbound version, so two
				-- of one id on one character - one worn once, one never - are worth
				-- different money. Counted rather than flagged, because a member can hold
				-- both at the same time and the figure needs to split them.
				if item.bound then
					record.bound = record.bound + (item.count or 1)
				end
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

	-- **What they are wearing**, which `Character:ReadEquipment` has recorded per slot since
	-- long before this and which nothing counted until 2026-09-11. An item on somebody's back
	-- is one the family owns, and *who has one of these* - the whole question an item tooltip
	-- is asked - was being answered wrongly by leaving it out.
	--
	-- One per slot, so two rings of the same id are two. Equipment is its own sharing category
	-- (§6) because what somebody wears and what they own are different things to show a friend,
	-- and nothing here has to know that: a sibling who granted one and not the other simply has
	-- the payload they granted.
	if payload.equipment then
		for _, item in pairs(payload.equipment.worn or {}) do
			if item.id then
				local record = bucket(item.id, key)
				record.worn = record.worn + 1
				-- Nearly always bound, and not always: a shirt binds to nobody. Read per
				-- piece rather than assumed, which is the measurement backlog 63 rests on.
				if item.bound then record.bound = record.bound + 1 end
			end
		end
	end

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
			+ record.worn
		if total > 0 then
			local borrowed, link = nil, nil
			if Family.Wide then borrowed, link = Family.Wide:Borrowed(key) end
			local meta = (borrowed and borrowed.meta) or Family.Database:Meta(key) or {}

			owners[#owners + 1] = {
				key = key,
				-- Whose they are, where they are not ours. Never left off: a count on a
				-- tooltip is read as "I can go and get that", and for somebody else's
				-- character that is not true.
				familyName = link and Family.Wide:Called(link) or nil,
				name = meta.name or key,
				realm = meta.realm,
				faction = meta.faction,
				classFile = meta.classFile,
				bags = record.bags,
				bank = record.bank,
				mail = record.mail,
				auctions = record.auctions,
				worn = record.worn,
				bound = record.bound,
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

--------------------------------------------------------------------------------------------
-- What it is all worth
--
-- Asked for 2026-09-10, and the reason the price work happened at all. The arithmetic lives here
-- rather than in a panel because the index is already the thing that knows who holds what, and a
-- walk of it is one pass over everything rather than a question asked once per member.
--
-- **Two prices, in that order.** What the auction house was last seen asking, and where there is
-- none, what a vendor pays. The first version used the auction price alone and left most of a
-- family unvalued - reported from play as *far too many items without a price*, and rightly: an
-- auction price exists only for what somebody has browsed, while the client states a sell price
-- for nearly every item there is. The sum says how much of it came from each, because a bank alt
-- valued at vendor prices and one valued at the auction house are two very different numbers and
-- a reader has to be able to tell which they are looking at.
--
-- **A sell price of nought is a price.** Plenty of things cannot be sold at all, and that is an
-- answer rather than a gap - what counts as unpriced is an item this client has never named.
--
-- **Everything a member holds**, which since 2026-09-10 includes what they have listed: bags,
-- bank, unexpired mail and live auctions. Not the guild bank, which belongs to the guild and not
-- to any one member, and not the keyring, which the client values at nothing anyway.
--
-- **And it never reports a total without saying what it left out.** The count it could not price
-- travels beside the money, the way the pet training line reports what it accounted for rather
-- than a bare sum. A worth that quietly omits four hundred stacks is the kind of number that gets
-- believed.
--------------------------------------------------------------------------------------------

local function marketOf(meta)
	local realm = meta and meta.realm
	if type(realm) ~= "string" or realm == "" then return nil end
	return realm .. "\30" .. (type(meta.faction) == "string" and meta.faction or "?")
end

-- **What a vendor pays, remembered account-wide.**
--
-- The client answers for any item it has in its cache and answers nothing for one it has not met
-- this session, so asking alone would value a family differently at every login. Written down
-- instead, by id and with no language in it, the same arrangement `FamilyDB.itemNames` uses - and
-- filled in from wherever an item is looked at, so it fills up rather than being gathered.
local function sellPriceOf(itemID)
	if type(_G.FamilyDB) ~= "table" then return nil end
	FamilyDB.sellPrices = FamilyDB.sellPrices or {}

	local held = FamilyDB.sellPrices[itemID]
	if held ~= nil then return held end

	local asked = tonumber((select(11, Family:TryCall(GetItemInfo, itemID))))
	if asked == nil then return nil end

	FamilyDB.sellPrices[itemID] = asked
	return asked
end

Index.SellPriceOf = function(_, itemID)
	itemID = tonumber(itemID)
	return itemID and sellPriceOf(itemID) or nil
end

function Index:Worth()
	refresh()

	local rows, byKey = {}, {}
	local markets = {}

	local function rowFor(key)
		if byKey[key] then return byKey[key] end

		local borrowed, link = nil, nil
		if Family.Wide then borrowed, link = Family.Wide:Borrowed(key) end
		local meta = (borrowed and borrowed.meta) or Family.Database:Meta(key) or {}

		local market = marketOf(meta)
		if market and markets[market] == nil then
			markets[market] = Family.Auctions and Family.Auctions:Prices(market) or false
		end

		local row = {
			key = key,
			name = meta.name or key,
			realm = meta.realm,
			classFile = meta.classFile,
			familyName = link and Family.Wide:Called(link) or nil,
			market = market,
			worth = 0,
			atMarket = 0,
			atVendor = 0,
			unpriced = 0,
			oldest = nil,
		}

		byKey[key] = row
		rows[#rows + 1] = row
		return row
	end

	for itemID, holders in pairs(entries) do
		for key, record in pairs(holders) do
			local held = record.bags + record.bank + record.mail + record.auctions
				+ record.worn

			if held > 0 then
				local row = rowFor(key)
				local price = row.market and markets[row.market]
					and markets[row.market][itemID] or nil

				-- **A bound one has no auction price, whatever the auction house says.**
				--
				-- Backlog 63, reported by Alberto: what is on sale there is the unbound
				-- version of the item, and a soulbound copy cannot be listed at any price.
				-- Its only buyer is a vendor. So the market lane values what is still
				-- sellable and the rest falls through to what a vendor pays - which is how
				-- two of one sword on one character come to be ten gold and half a gold.
				local bound = math.min(record.bound, held)
				local free = held - bound

				if free > 0 and type(price) == "table" and tonumber(price.p) then
					row.worth = row.worth + price.p * free
					row.atMarket = row.atMarket + free
					if price.at and (not row.oldest or price.at < row.oldest) then
						row.oldest = price.at
					end
				else
					bound = held
					free = 0
				end

				if bound > 0 then
					local sell = sellPriceOf(itemID)
					if sell then
						row.worth = row.worth + sell * bound
						row.atVendor = row.atVendor + bound
					else
						row.unpriced = row.unpriced + bound
					end
				end
			end
		end
	end

	table.sort(rows, function(a, b)
		if a.worth ~= b.worth then return a.worth > b.worth end
		return tostring(a.key) < tostring(b.key)
	end)

	return rows
end

-- One member's share of it, which is what the possessions panel draws above their bags.
function Index:WorthOf(key)
	for _, row in ipairs(self:Worth()) do
		if row.key == key then return row end
	end
	return nil
end

-- **What the family's lot of one item comes to**, which is the same walk as `Worth` narrowed to
-- a single id rather than a second way of pricing things.
--
-- Asked for 2026-09-10, for the item tooltip, where the count of what the family holds has been
-- drawn since the possessions block was written and its value never was. Outside your own bags
-- there is no pile to multiply - on an auction row the frame belongs to whoever drew it and a
-- count read off it could not be checked against anything (L-066's shape) - and this needs no
-- pile at all: it is the index, which knows who holds what wherever they are standing.
--
-- **Valued per holder, not per reader.** A price is a photograph of one realm and one side, so a
-- brother on another realm is valued at his market and not at ours. That is why the market is
-- looked up per member here exactly as `Worth` does it, rather than asking `Auctions:PriceOf`
-- once for the reader and multiplying.
--
-- The guild bank is left out, as it is everywhere else this arithmetic runs: it belongs to the
-- guild rather than to any member, and the tooltip's own count of it is drawn on its own line.
function Index:WorthOfItem(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	refresh()

	local holders = entries[itemID]
	if not holders then return nil end

	local markets = {}
	local out = { held = 0, worth = 0, atMarket = 0, atVendor = 0, unpriced = 0, oldest = nil }

	for key, record in pairs(holders) do
		local held = record.bags + record.bank + record.mail + record.auctions
			+ record.worn

		if held > 0 then
			local borrowed = Family.Wide and Family.Wide:Borrowed(key)
			local meta = (borrowed and borrowed.meta) or Family.Database:Meta(key) or {}

			local market = marketOf(meta)
			if market and markets[market] == nil then
				markets[market] = Family.Auctions and Family.Auctions:Prices(market) or false
			end

			local price = market and markets[market] and markets[market][itemID] or nil

			out.held = out.held + held

			-- The same split as `Worth` above: a bound copy has no auction price at all,
			-- because it cannot be listed at one. Backlog 63.
			local bound = math.min(record.bound, held)
			local free = held - bound

			if free > 0 and type(price) == "table" and tonumber(price.p) then
				out.worth = out.worth + price.p * free
				out.atMarket = out.atMarket + free
				if price.at and (not out.oldest or price.at < out.oldest) then
					out.oldest = price.at
				end
			else
				bound = held
				free = 0
			end

			if bound > 0 then
				local sell = sellPriceOf(itemID)
				if sell then
					out.worth = out.worth + sell * bound
					out.atVendor = out.atVendor + bound
				else
					out.unpriced = out.unpriced + bound
				end
			end
		end
	end

	if out.held == 0 then return nil end
	return out
end

-- The same thing added up, for a heading or a grand total.
function Index:WorthTotal(rows)
	local worth, atMarket, atVendor, unpriced, oldest = 0, 0, 0, 0, nil

	for _, row in ipairs(rows or self:Worth()) do
		worth = worth + row.worth
		atMarket = atMarket + row.atMarket
		atVendor = atVendor + row.atVendor
		unpriced = unpriced + row.unpriced
		if row.oldest and (not oldest or row.oldest < oldest) then oldest = row.oldest end
	end

	return worth, atMarket, atVendor, unpriced, oldest
end
