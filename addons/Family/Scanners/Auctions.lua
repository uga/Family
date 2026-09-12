-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a member has up for sale, and what they have bid on.
--
-- Readable only at an auction house, so this is a photograph of the last visit like the bank
-- is - except that auctions expire on their own, which the bank does not. An auction seen two
-- days ago on a twelve hour listing is not there any more, and Family works that out from the
-- time left it recorded rather than pretending the snapshot is still true.
--
-- The list has to be asked for before it can be read: GetOwnerAuctionItems starts the query
-- and the answer arrives as an event.

local _, Family = ...

local Auctions = {}
Family.Auctions = Auctions

-- The client reports time left as one of four buckets rather than a number. These are the
-- upper bound of each in seconds, which is what an expiry has to be worked out from.
local BUCKET_SECONDS = { 1800, 7200, 43200, 172800 }

local function timeLeftSeconds(bucket)
	return BUCKET_SECONDS[tonumber(bucket) or 0] or 0
end

--------------------------------------------------------------------------------------------

local function readList(which)
	local count = Family:TryCall(GetNumAuctionItems, which)
	if not count or count == 0 then return {} end

	local entries = {}

	for index = 1, count do
		local name, _, quantity, _, _, _, _, minBid, _, buyout, bidAmount,
			highBidder, _, _, _, _, itemID = Family:TryCall(GetAuctionItemInfo, which, index)

		-- **A sold auction is not something on sale.**
		--
		-- Measured on Burning Crusade 2026-09-10, thirteen rows on one character: the three the
		-- window labels *Sold* answer a quantity of nought and a minimum bid of nought, with the
		-- buyout carrying the amount on its way to the mailbox - 14s97c, 25s36c, 16s38c, which is
		-- what the window draws beside them as *Incoming Amount*. All ten live ones answer a real
		-- quantity.
		--
		-- They were already being left out, and for the wrong reason: the client gives a sold
		-- auction no time left either, so it read as expired and `Live` dropped it. The totals
		-- were right by accident. A client that answered with a real bucket there would have
		-- folded money already earned into what is still for sale, and nothing would have said so.
		if name and (tonumber(quantity) or 0) > 0 then
			local bucket = Family:TryCall(GetAuctionItemTimeLeft, which, index)

			entries[#entries + 1] = {
				id = itemID,
				count = quantity or 1,
				minBid = minBid or 0,
				buyout = buyout or 0,
				bid = bidAmount or 0,
				hasBid = (bidAmount or 0) > 0,
				highBidder = highBidder and true or false,
				bucket = tonumber(bucket) or 0,
				-- Recorded as a moment rather than a duration, so it keeps meaning
				-- something after the window is shut.
				expiresBy = time() + timeLeftSeconds(bucket),
			}
		end
	end

	return entries
end

-- **What this character has up for sale, on the newer auction house.**
--
-- The repair for backlog 56: everything above reads calls that exist on Mists and answer nothing,
-- so *what a member has up for sale* has been empty there since Family first ran on that build,
-- and nothing announced it because nought auctions is what somebody with no auctions has.
--
-- Eight rows read on a live client 2026-09-10, with Auctionator and without it, identically - and
-- a stackable good carries the same fields as a single item, which one row could not have shown:
--
--     auctionID 483115863   itemKey { itemID=5527, itemLevel=15, itemSuffix=0 }
--     buyoutAmount 1999     quantity 12    status 0    timeLeftSeconds 85944
--
-- **`buyoutAmount` is the price of one**, confirmed by the person who typed it rather than
-- inferred from the numbers: twelve clams at 19s99c is 19s99c *each*. The record this writes into
-- has always held the whole auction's buyout, because that is what the older call gives - so this
-- multiplies, and getting that backwards would have had the summary out by whatever somebody's
-- stack sizes happened to be, silently. One row of 152 Solid Stone is the difference between
-- 3s98c and 605g.
--
-- **`timeLeftSeconds` is real seconds**, so no bucket has to be translated and the expiry is
-- exact rather than an upper bound.
--
-- **What is not here is bids.** No row carried a bid field, and every one of the eight was a
-- buyout-only listing - so *the field is absent* and *there was nothing to bid on* cannot be told
-- apart from this reading. A bid is read where the client offers one and defaults to nought
-- otherwise, which is what the older reader already does with the same meaning.
local function readModernOwned()
	if not C_AuctionHouse then return {} end

	local count = tonumber((Family:TryCall(C_AuctionHouse.GetNumOwnedAuctions))) or 0
	if count < 1 then return {} end

	local entries = {}

	for index = 1, count do
		local row = Family:TryCall(C_AuctionHouse.GetOwnedAuctionInfo, index)
		local key = type(row) == "table" and row.itemKey
		local itemID = type(key) == "table" and tonumber(key.itemID) or nil

		if itemID then
			local quantity = tonumber(row.quantity) or 1
			local each = tonumber(row.buyoutAmount) or 0
			local left = tonumber(row.timeLeftSeconds)
			local bid = tonumber(row.bidAmount) or 0

			entries[#entries + 1] = {
				id = itemID,
				count = quantity,
				minBid = tonumber(row.minBid) or 0,
				-- The whole auction, which is what this field has always meant.
				buyout = each * quantity,
				bid = bid,
				hasBid = bid > 0,
				-- Meaningless on one's own listings, and false is what the older reader
				-- writes for them too.
				highBidder = false,
				bucket = 0,
				-- Exact here rather than the upper bound of a bucket.
				expiresBy = left and (time() + left) or time(),
			}
		end
	end

	return entries
end

function Auctions:Scan()
	local key = Family:CurrentMember()

	-- Both routes, neither gated, each silent where it does not apply - the same arrangement
	-- the prices use, and for the same reason: all eight of the older symbols are present on
	-- the build where none of them work, so nothing can be asked *which house is this*.
	local selling = readList("owner")
	if #selling == 0 then selling = readModernOwned() end

	-- No bidder list on the newer house has been read, so this stays what the older call
	-- answers - which on Mists is nothing, honestly rather than wrongly.
	local bidding = readList("bidder")

	local payload = Family.Database:Payload(key) or {}
	payload.auctions = {
		selling = selling,
		bidding = bidding,
		seen = time(),
	}
	Family.Database:SetPayload(key, payload)

	Family.Database:SetMeta(key, {
		auctionsSelling = #selling,
		auctionsBidding = #bidding,
		auctionsSeen = time(),
	})

	Family:Debug("scanned auctions: %d selling, %d bidding", #selling, #bidding)
end

-- Everything still listed as of now. An auction whose latest possible expiry has passed is
-- gone whatever the snapshot said, and saying otherwise would be worse than saying nothing.
function Auctions:Live(record)
	if not record then return {}, {} end

	local now = time()
	local selling, bidding = {}, {}

	for _, entry in ipairs(record.selling or {}) do
		if (entry.expiresBy or 0) > now then selling[#selling + 1] = entry end
	end
	for _, entry in ipairs(record.bidding or {}) do
		if (entry.expiresBy or 0) > now then bidding[#bidding + 1] = entry end
	end

	return selling, bidding
end

--------------------------------------------------------------------------------------------
-- Winning one, which the server posts to you as mail
--
-- Buying something out sends it by mail, exactly as posting to an alt does - so it belongs in
-- the same "in the post" count, and a character who bought something and logged off without
-- collecting it says so from any other character. Asked for from play.
--
-- **The server decides whether it was a buyout, not us.** The first design compared the bid
-- against the auction's buyout price, which means knowing where `GetAuctionItemInfo` puts that
-- price, and it moves between expansions. It is not needed: the bid is remembered whatever
-- kind it was, and nothing is recorded until the client is told the auction was won. A buyout
-- somebody beat you to, or one there was not gold for, is never told that - so it writes
-- nothing, which is the same guarantee `MAIL_SEND_SUCCESS` gives the outgoing side.
--
-- Measured 2026-08-31 on a French Era client, buying one item out:
--
--     CHAT_MSG_SYSTEM  Vous avez gagn\195\169 les ench\195\168res pour Cristal des arcanes
--     CHAT_MSG_SYSTEM  Offre accept\195\169e.
--     AUCTION_BIDDER_LIST_UPDATE
--
-- Two messages and only the first one means this. `ERR_AUCTION_BID_PLACED` - the second - is
-- said for any bid at all, and a bid is not an item on its way.
--------------------------------------------------------------------------------------------

-- How long a remembered bid stays worth committing. The confirmation arrives in the same
-- breath as the bid; a minute later it belongs to something else the player has done since.
local WON_WINDOW = 30

-- "You won an auction for %s", turned into something to match against, out of the client's
-- own string. Never the English, and never the French either: `ERR_AUCTION_WON_S` is the same
-- global in every language, which is the whole reason to build the pattern rather than write
-- one. The same three steps `ITEM_SPELL_CHARGES` gets in Core.lua, minus the plural markup,
-- which this string does not carry.
local builtFrom, builtPattern

local function wonPattern()
	local format = _G.ERR_AUCTION_WON_S
	if type(format) ~= "string" or format == "" then return nil end
	if builtFrom == format then return builtPattern end

	local escaped = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	escaped = escaped:gsub("%%%%s", ".+")

	builtFrom, builtPattern = format, "^" .. escaped .. "$"
	return builtPattern
end

-- What was last bid on, held between the bid and the server's answer.
local pending

-- Read as the bid is made, because the browse list is rebuilt underneath it a moment later.
function Auctions:NoteBid(list, index)
	pending = nil
	if list ~= "list" then return nil end

	local link = Family:TryCall(GetAuctionItemLink, list, index)
	local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
	if not id then return nil end

	-- Captured into a table rather than off a run of placeholders, which survives the
	-- signature changing underneath it (L-032). The stack size is the third return on every
	-- client this addon supports; where it is not a sensible number, one is the honest guess
	-- and the id is the part that matters.
	local row = { Family:TryCall(GetAuctionItemInfo, list, index) }
	local count = tonumber(row[3])
	if not count or count < 1 then count = 1 end

	pending = { id = id, count = count, item = Family:ItemString(link), at = time() }
	return pending
end

-- The server says it was won. Now it is a fact about this character's mailbox.
function Auctions:NoteWon()
	local won = pending
	pending = nil

	if not won then return false end
	if time() - (won.at or 0) > WON_WINDOW then return false end

	return Family.Mail:CommitWon(won)
end

--------------------------------------------------------------------------------------------
-- What things are going for
--
-- Asked for 2026-09-10: remember the buyout of what is on sale, so that Family can eventually say
-- what everything a family holds is worth. Read from the browse list the player is already
-- looking at - `AUCTION_ITEM_LIST_UPDATE` fires many times while somebody searches, measured on a
-- live Era client 2026-08-31 and written up in `docs/DATASOURCES.md`. Nothing is queried here.
--
-- **Not account-wide.** An auction price belongs to one realm and one faction, unlike everything
-- else Family keeps in `FamilyDB`, so the store is keyed by both before the item. The neutral
-- auction house is a third market and is filed under the reader's own faction, which is what they
-- would pay there and is not the same as what their side's own house is asking - a known
-- imprecision rather than a solved problem.
--------------------------------------------------------------------------------------------

-- Which market this character is standing in. Both parts are the client's own English tokens
-- rather than anything a reader sees, so a record written on a German client lines up with one
-- written here.
local function market()
	local realm = Family:TryCall(GetRealmName)
	local faction = Family:TryCall(UnitFactionGroup, "player")
	if type(realm) ~= "string" or realm == "" then return nil end
	return realm .. "\30" .. (type(faction) == "string" and faction or "?")
end

-- **What counts as one reading, and why it has to be a visit rather than a page.**
--
-- The rule asked for is *the freshest wins, and among the freshest the lowest*. Taken literally
-- as "the last page seen wins" it loses money: search Black Lotus, see 40g, open page two of the
-- same search, see 60g - and the record now says 60 for something you could have had at 40.
--
-- So a reading is an auction house **visit**. The first sighting of an item in a visit replaces
-- whatever was there, however old or new; every later sighting in the same visit keeps the lower.
-- Emptied when the window opens and again when it closes, so nothing survives to make yesterday's
-- browse look like today's.
local seenThisVisit = {}

function Auctions:Prices(where)
	if type(_G.FamilyDB) ~= "table" then return {} end
	FamilyDB.auctionPrices = FamilyDB.auctionPrices or {}

	where = where or market()
	if not where then return {} end

	FamilyDB.auctionPrices[where] = FamilyDB.auctionPrices[where] or {}
	return FamilyDB.auctionPrices[where]
end

-- The price and when it was seen, for the market this character is in. Two returns rather than
-- the row itself, because a caller that is handed the row can hold on to it.
-- How many this market has a price for, which is the only progress figure that means anything
-- during a read: pages are how far it has got, prices are what it has been worth.
function Auctions:PriceCount()
	local held = 0
	for _, row in pairs(self:Prices()) do
		if type(row) == "table" and row.at then held = held + 1 end
	end
	return held
end

-- How many this market has a price for, which is the only progress figure that means anything
-- during a read of the house: pages are how far it has got, prices are what it has been worth.
function Auctions:PriceCount()
	local held = 0
	for _, row in pairs(self:Prices()) do
		if type(row) == "table" and row.at then held = held + 1 end
	end
	return held
end

function Auctions:PriceOf(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end

	local held = self:Prices()[itemID]
	if type(held) ~= "table" then return nil end
	return held.p, held.at
end

function Auctions:ForgetVisit()
	seenThisVisit = {}
end

-- **Counted, because on Mists nothing is being learned and three things could explain it.**
--
-- Reported 2026-09-10: all eight calls present, a query would be accepted, and nought prices after
-- a session of browsing - where the same probe on Burning Crusade said fifty rows on show. Either
-- the event does not fire on that build, or it fires and the list answers nought, or the list is
-- not where that client puts what the player is looking at. A count of the firings and of what was
-- on show at the last one tells the three apart, which reasoning about them cannot.
local fired, lastRows = 0, nil

function Auctions:ReadingsSeen()
	return fired, lastRows
end

-- **And the same count for the newer auction house**, because Mists turned out to have it.
--
-- Read 2026-09-10: on that build all three of the old lists answer nought, the old event never
-- fires once, and `C_AuctionHouse` carries `GetBrowseResults`, `SendBrowseQuery`,
-- `GetNumReplicateItems`, `QueryOwnedAuctions` and `SearchForFavorites`. So the eight old calls
-- are shells - present, and answering nothing - and everything this file reads is dead there,
-- which is not only the prices but the auctions a member has up for sale.
--
-- Which of the newer events actually arrives while a player browses is the next thing that has to
-- be read rather than assumed, so they are counted the same way. `RegisterEvent` refuses an event
-- the client has not got and says so, which makes this free on Era and Burning Crusade.
local MODERN_EVENTS = {
	"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
	"AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
	"COMMODITY_SEARCH_RESULTS_UPDATED",
	"ITEM_SEARCH_RESULTS_UPDATED",
	"OWNED_AUCTIONS_UPDATED",
	-- Counted rather than assumed, because the visit rule rests on them: a client where these
	-- never fire is one where nothing ever starts a new visit, and prices would only ever fall.
	"AUCTION_HOUSE_SHOW",
	"AUCTION_HOUSE_CLOSED",
}

local modernHeard = {}

function Auctions:ModernEvents()
	return MODERN_EVENTS, modernHeard
end

-- **One browse result, whatever shape it is.**
--
-- Read 2026-09-10: `GetBrowseResults` was holding 500 rows on Mists and
-- `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` had fired once, so the passive route exists there. What
-- a row *is* has not been read, and guessing at field names is how the vendor question went wrong
-- this morning - so the probe prints one, and the reader is written against what comes back
-- rather than against what a field is usually called.
--
-- Returned rather than printed, because this file may not talk to the player.
function Auctions:ModernSample()
	if not C_AuctionHouse then return nil end

	local results = Family:TryCall(C_AuctionHouse.GetBrowseResults)
	if type(results) ~= "table" then return nil end

	local first = results[1]
	if type(first) ~= "table" then return nil end

	local out = {}
	for key, value in pairs(first) do
		if type(value) == "table" then
			local inner = {}
			for k, v in pairs(value) do
				inner[#inner + 1] = string.format("%s=%s", tostring(k), tostring(v))
			end
			table.sort(inner)
			out[#out + 1] = { tostring(key), "{ " .. table.concat(inner, ", ") .. " }" }
		else
			out[#out + 1] = { tostring(key), tostring(value) }
		end
	end

	table.sort(out, function(a, b) return a[1] < b[1] end)
	return out
end

-- **And one of this character's own auctions**, for the repair in backlog 56.
--
-- Read 2026-09-10: listing a single item took `GetNumOwnedAuctions` from nought to one and fired
-- `OWNED_AUCTIONS_UPDATED` four times, so the newer house does answer for the owner list - which
-- is the feature that has been silently empty on that build since Family first ran there. What a
-- row of it looks like is the next thing that must be read rather than named from memory.
function Auctions:ModernOwnedSample()
	if not C_AuctionHouse then return nil, nil end

	local tried = {}
	for _, name in ipairs { "GetOwnedAuctionInfo", "GetOwnedAuctions" } do
		if type(C_AuctionHouse[name]) == "function" then tried[#tried + 1] = name end
	end

	-- **All of them, not the first.** A stackable good and a single item are two different
	-- things on the newer house and may not carry the same fields, and one row cannot show
	-- that. Seven rows of chat is a fair price for not guessing.
	local howMany = tonumber((Family:TryCall(C_AuctionHouse.GetNumOwnedAuctions))) or 0
	local all = Family:TryCall(C_AuctionHouse.GetOwnedAuctions)
	if type(all) ~= "table" then all = nil end

	local out = {}
	for index = 1, math.max(howMany, all and #all or 0) do
		local row = Family:TryCall(C_AuctionHouse.GetOwnedAuctionInfo, index)
		if type(row) ~= "table" then row = all and all[index] or nil end

		if type(row) == "table" then
			out[#out + 1] = { "-", tostring(index) }

			local keys = {}
			for key in pairs(row) do keys[#keys + 1] = tostring(key) end
			table.sort(keys)

			for _, key in ipairs(keys) do
				local value = row[key]
				if type(value) == "table" then
					local inner = {}
					for k, v in pairs(value) do
						inner[#inner + 1] =
							string.format("%s=%s", tostring(k), tostring(v))
					end
					table.sort(inner)
					out[#out + 1] =
						{ key, "{ " .. table.concat(inner, ", ") .. " }" }
				else
					out[#out + 1] = { key, tostring(value) }
				end
			end
		end
	end

	return tried, (#out > 0) and out or nil
end

-- **And the same for the older house's own listings**, which is a different question with the
-- same shape.
--
-- Alberto asked whether *per one* or *per stack* might differ between the two, and it is exactly
-- the sort of thing that would: on the newer house a stackable good is priced by the unit, and the
-- older one has no such notion. Everything Family does on Era and Burning Crusade - the owner
-- record, and the browse prices, which **divide** by the quantity - rests on that buyout being the
-- whole stack, and that has never been read here.
--
-- Printed rather than reasoned about, so somebody with a stack listed can hold the number against
-- what they typed.
function Auctions:OldOwnedSample()
	local count = tonumber((Family:TryCall(GetNumAuctionItems, "owner"))) or 0
	if count < 1 then return nil end

	local out = {}
	for index = 1, count do
		local row = { Family:TryCall(GetAuctionItemInfo, "owner", index) }
		local link = Family:TryCall(GetAuctionItemLink, "owner", index)

		out[#out + 1] = { "-", tostring(index) }
		out[#out + 1] = { "item", tostring(type(link) == "string"
			and link:match("item:(%d+)") or row[17]) }
		out[#out + 1] = { "quantity", tostring(row[3]) }
		out[#out + 1] = { "minBid", tostring(row[8]) }
		out[#out + 1] = { "buyout", tostring(row[10]) }
	end

	return out
end

-- What the newer house says it is holding right now, asked without being told to search.
function Auctions:ModernCounts()
	if not C_AuctionHouse then return nil end

	local browse = Family:TryCall(C_AuctionHouse.GetBrowseResults)
	local owned = Family:TryCall(C_AuctionHouse.GetNumOwnedAuctions)

	return (type(browse) == "table") and #browse or nil, tonumber(owned)
end

-- **The same reading on the newer auction house**, which Mists turned out to have.
--
-- Measured 2026-09-10, one row of `C_AuctionHouse.GetBrowseResults()` printed rather than guessed
-- at:
--
--     containsOwnerItem  false
--     itemKey            { battlePetSpeciesID=0, itemID=32902, itemLevel=68, itemSuffix=0 }
--     minPrice           1
--     totalQuantity      442
--
-- **`minPrice` is already the lowest price of one**, across every listing under that key, so this
-- route divides nothing and takes no minimum of its own - the client has done both. That is the
-- one place the newer house is simpler than the old, where fifty rows have to be walked.
--
-- **Known imprecision, and the same one the tooltip has**: a key carries an item level and a
-- suffix, so two rows can share an item id and be different things - a random-enchantment item is
-- one id wearing dozens of suffixes. Family files a price under the id, because the tooltip that
-- will ask for it knows an id and nothing else, so the cheapest variant speaks for the plain one.
--
-- Both routes are registered on every client and neither is gated: the old one reads a list that
-- answers nought on Mists, the newer one reads a call that does not exist on Era, and each is
-- silent where it does not apply. Nothing has to decide which house this is.
--------------------------------------------------------------------------------------------
-- The newer house's whole-list read, asked about rather than used
--
-- Entry 55 slice 3. The old house is walked a page at a time because a page is what it offers.
-- The newer one offers a single call that asks the server for its entire list, and Mists has it:
-- measured 2026-09-11, `ReplicateItems`, `GetNumReplicateItems`, `GetReplicateItemInfo` and
-- `IsThrottledMessageSystemReady` are all present there and all absent on Era.
--
-- **Presence is not behaviour.** What that call answers, how much arrives, in how many pieces,
-- whether the rows are numbered from nought or from one, and what the throttle does are five
-- things nothing here knows. And it is the same family of call as the one that crawled a live
-- client for minutes - so nothing is built on it until it has been run once and the answers
-- written down, which is why everything below reads and nothing acts.
--------------------------------------------------------------------------------------------

local tellNextReplicate
local replicateHeard = 0

function Auctions:TellNextReplicate(fn)
	tellNextReplicate = type(fn) == "function" and fn or nil
end

function Auctions:ReplicateHeard()
	return replicateHeard
end

-- Whether this build offers it at all, which is what decides whether the probe has anything to
-- do - and it is the call being there, never the build number.
function Auctions:CanReplicate()
	return (_G.C_AuctionHouse and type(C_AuctionHouse.ReplicateItems) == "function") or false
end

function Auctions:ThrottleReady()
	if not _G.C_AuctionHouse then return nil end
	if type(C_AuctionHouse.IsThrottledMessageSystemReady) ~= "function" then return nil end
	return (Family:TryCall(C_AuctionHouse.IsThrottledMessageSystemReady))
end

function Auctions:ReplicateCount()
	if not _G.C_AuctionHouse then return nil end
	if type(C_AuctionHouse.GetNumReplicateItems) ~= "function" then return nil end
	return tonumber((Family:TryCall(C_AuctionHouse.GetNumReplicateItems)))
end

-- Every return of a row, by **position**, with a trailing nothing kept as part of the shape.
local function packOf(...)
	return { n = select("#", ...), ... }
end

-- **A row of the replicated list, at the index it was asked for.**
--
-- The indices are asked for rather than iterated, and nought is among them, because whether this
-- list is numbered from nought or from one is one of the things unknown - and a loop written from
-- either guess would answer with the guess. Nothing here names a return either: which position
-- holds what is the reading, and a table of names written now would be the same mistake wearing
-- a different coat (L-071).
function Auctions:ReplicateSample(indices)
	local rows = {}
	if not _G.C_AuctionHouse then return rows end
	if type(C_AuctionHouse.GetReplicateItemInfo) ~= "function" then return rows end

	for _, index in ipairs(indices or { 0, 1 }) do
		local got = packOf(Family:TryCall(C_AuctionHouse.GetReplicateItemInfo, index))

		local said = {}
		for position = 1, got.n do said[position] = tostring(got[position]) end
		rows[#rows + 1] = { index = index, n = got.n, values = said }
	end

	return rows
end

-- **Which position holds what, worked out from the client's other description of the same
-- auction.**
--
-- Read from play on Mists 2026-09-12: one call answered **43,002 rows**, numbered from **nought**,
-- eighteen returns apiece. Two of those eighteen are what a price needs - the item and what it is
-- going for - and reading a table of names off the shape of the numbers is exactly the guess this
-- repository has twice paid for (L-071, L-074).
--
-- It does not have to be guessed. The player's **own** auctions are readable through
-- `GetOwnedAuctionInfo`, which answers **named** fields: `itemKey.itemID`, `quantity`,
-- `buyoutAmount`. Those same auctions are somewhere in the replicated list. So this looks for a
-- row carrying those values and reports **which positions** they turned up in - the client
-- describing one auction twice, and the map falling out of the difference.
--
-- Nothing is sent and nothing is stored. It walks a list the client is already holding.
function Auctions:ReplicateMatchOwned(limit)
	local out = { scanned = 0, owned = 0, matches = {} }
	if not _G.C_AuctionHouse then return out end
	if type(C_AuctionHouse.GetReplicateItemInfo) ~= "function" then return out end

	local mine = readModernOwned()
	out.owned = #mine
	if #mine == 0 then return out end

	-- **How many of them could settle anything.** A listing of one prices the same whichever
	-- way the house counts, so a player whose auctions are all singles can run this all day and
	-- learn nothing - and *no answer* and *no listing that could answer* must not read alike.
	for _, auction in ipairs(mine) do
		if (auction.count or 1) > 1 then out.stacks = (out.stacks or 0) + 1 end
	end
	out.stacks = out.stacks or 0

	-- What to look for: every value one of these auctions is described by, and the name the
	-- **other** route gave it. `buyoutAmount` is per item there and the reader above multiplies
	-- it out, so both forms are looked for rather than one being assumed.
	-- **Both forms of the price, because one auction cannot tell them apart.**
	--
	-- Read from play on Mists 2026-09-12: the auction that matched had a quantity of **one**, so
	-- the price for one and the price for the stack are the same number and the match says
	-- nothing about which of them position ten holds. An auction of a hundred and one says it in
	-- one reading - so both are looked for, and the label that comes back says which it was.
	local wanted = {}
	for _, auction in ipairs(mine) do
		local each = auction.count > 0 and (auction.buyout / auction.count) or auction.buyout

		wanted[#wanted + 1] = {
			told = auction.count,
			{ "itemID", auction.id },
			{ "quantity", auction.count },
			{ auction.count > 1 and "buyoutAmount(each)" or "buyoutAmount(1)", each },
		}

		if auction.count > 1 then
			wanted[#wanted + 1] = {
				told = auction.count,
				{ "itemID", auction.id },
				{ "quantity", auction.count },
				{ "buyoutAmount(stack)", auction.buyout },
			}
		end
	end

	local held = self:ReplicateCount() or 0
	local ceiling = math.min(held, tonumber(limit) or 60000)

	for index = 0, ceiling - 1 do
		out.scanned = out.scanned + 1

		local got = packOf(Family:TryCall(C_AuctionHouse.GetReplicateItemInfo, index))
		if got.n > 0 then
			for _, auction in ipairs(wanted) do
				-- Every field has to be somewhere in the row, or a row that happens to
				-- share one number with an auction of ours would be read as that auction.
				local found, where = 0, {}

				for _, field in ipairs(auction) do
					for position = 1, got.n do
						if got[position] == field[2] then
							found = found + 1
							where[#where + 1] = { field[1], position, field[2] }
							break
						end
					end
				end

				if found == #auction then
					out.matches[#out.matches + 1] = {
						index = index, at = where, quantity = auction.told,
					}
				end
			end
		end

		-- **Stopped only by a match that settles something**, which is a match on a listing of
		-- more than one. A count of matches was the first stopping rule and it was wrong the
		-- way silence is wrong: four listings of one apiece would satisfy it and answer
		-- nothing, and the walk would stop just short of the auction that could have.
		--
		-- Otherwise it reads the list out - forty-three thousand rows on Mists, and it did
		-- that once already without anybody noticing the wait.
		local settled = false
		for _, match in ipairs(out.matches) do
			if (match.quantity or 1) > 1 then settled = true end
		end

		if settled then break end
	end

	return out
end

--------------------------------------------------------------------------------------------
-- Reading the newer house whole
--
-- Entry 55 slice 3. The old house is walked a page at a time because a page is what it offers;
-- this one answers its entire list to a single call, and the whole of Mists arrived in one event:
-- **43,002 rows**, then 43,300, then 42,990 across an evening.
--
-- **Every position below was measured, none was guessed.** The client describes the player's own
-- auctions a second way, through `GetOwnedAuctionInfo`, which answers named fields - so a row
-- carrying all of an auction's values says where each one lives (`ReplicateMatchOwned`, and
-- DATASOURCES has the readings). On Mists 2026-09-12 that came out as quantity at 3, the price
-- at 10, the item at 17 - and the price is **for the whole lot**: an auction the named route
-- calls twenty at 44,993 apiece arrives here as 899,860.
--
-- **Read in pieces.** Forty-three thousand rows in one frame is a client that has stopped
-- answering its keyboard. The list is already in the client's hands by then, so this pacing costs
-- the server nothing - it is not the page walk, where every step is a query.
--------------------------------------------------------------------------------------------

local REPLICATE_QUANTITY, REPLICATE_LOT, REPLICATE_ITEM = 3, 10, 17

local ROWS_PER_TICK = 500
local READ_QUIET = 30

local reading

function Auctions:ReplicateReading()
	return reading
end

function Auctions:StopReplicateRead(why)
	if not reading then return false end
	local stopping, told = reading, reading.told
	reading = nil
	if told then Family:TryCall(told, "stopped", stopping, why) end
	return true
end

-- One slice of the list, and then the next, until there is none left.
local function readSome()
	if not reading then return end

	local prices = Auctions:Prices()
	if not prices then return Auctions:StopReplicateRead("query") end

	local now = time()
	local last = math.min(reading.done + ROWS_PER_TICK, reading.rows)

	while reading.done < last do
		local got = packOf(Family:TryCall(C_AuctionHouse.GetReplicateItemInfo, reading.done))

		if got.n > 0 then
			reading.kept = reading.kept + Auctions:KeepPrice(prices,
				got[REPLICATE_ITEM], got[REPLICATE_LOT], got[REPLICATE_QUANTITY], now)
		end

		reading.done = reading.done + 1
	end

	if reading.told then Family:TryCall(reading.told, "some", reading) end

	if reading.done >= reading.rows then
		local finished, told = reading, reading.told
		reading = nil
		if told then Family:TryCall(told, "finished", finished) end
		return
	end

	Family:After(0.05, "auctions.replicate.read", readSome)
end

-- **The list arrived**, which is the only thing that starts the reading.
local function replicateAnswered()
	if not reading or reading.rows then return end

	reading.rows = Auctions:ReplicateCount() or 0

	-- Nought rows is an answer, and it is not the same as no answer: an empty house, or a build
	-- that hands the list over some other way. Either is worth saying rather than looking like
	-- a read that never started.
	if reading.rows < 1 then return Auctions:StopReplicateRead("emptyList") end

	readSome()
end

function Auctions:StartReplicateRead(told)
	if reading then return false, "running" end
	if not self:CanReplicate() then return false, "olderHouse" end

	-- Asked **once**, by somebody who said so: this is the same call the probe sends, and the
	-- one thing in this addon that a server may ration for the rest of an evening.
	reading = { done = 0, kept = 0, told = told, started = time(),
		clock = tonumber((Family:TryCall(GetTime))) }

	local ok, err = self:AskReplicate()
	if not ok then
		reading = nil
		return false, err == "absent" and "olderHouse" or "query"
	end

	-- **A list that never arrives ends it rather than leaving it looking alive.** Measured on
	-- Mists 2026-09-12: two calls answered forty-three thousand rows apiece and a third,
	-- minutes later, answered nothing - so this is not a rare case, it is the third try.
	Family:After(READ_QUIET, "auctions.replicate.quiet", function()
		if reading and not reading.rows then Auctions:StopReplicateRead("quiet") end
	end)

	return true, nil
end

-- **Sent once, and only by somebody asking for it in as many words.**
--
-- `pcall` rather than `TryCall`, because here an error is the measurement and `TryCall` throws
-- the words away - the same reason `ReplayQuery` uses one.
function Auctions:AskReplicate()
	if not self:CanReplicate() then return false, "absent" end

	local ok, err = pcall(C_AuctionHouse.ReplicateItems)
	if not ok then return false, tostring(err) end
	return true, nil
end

function Auctions:ReadModernPrices()
	if not C_AuctionHouse then return 0 end

	local where = market()
	if not where then return 0 end

	local results = Family:TryCall(C_AuctionHouse.GetBrowseResults)
	if type(results) ~= "table" then return 0 end

	local prices = self:Prices(where)
	local now = time()
	local kept = 0

	for _, entry in ipairs(results) do
		local key = type(entry) == "table" and entry.itemKey
		local itemID = type(key) == "table" and tonumber(key.itemID) or nil
		local each = type(entry) == "table" and tonumber(entry.minPrice) or nil

		if itemID and each and each > 0 then
			local held = prices[itemID]

			if not seenThisVisit[itemID] or type(held) ~= "table" then
				seenThisVisit[itemID] = true
				prices[itemID] = { p = each, at = now }
				kept = kept + 1
			elseif each < held.p then
				held.p, held.at = each, now
				kept = kept + 1
			end
		end
	end

	if kept > 0 then
		Family:Debug("auctions: %d price(s) taken from %d browse result(s)", kept, #results)
	end

	return kept
end

-- One page of whatever the player last searched for.
-- **The visit rule, in one place, because two readers obeying it separately is two readers
-- drifting apart.**
--
-- The freshest wins, and among the freshest the lowest: the first sighting of an item in a visit
-- replaces whatever was there however old, and every later sighting keeps the lower. Written out
-- at length where `seenThisVisit` is declared.
--
-- **The price handed in is for the whole lot** and the price of one is a division Family does -
-- true of the old house (measured on Era 2026-09-10: three of a thing at 2g99s61c, a minimum bid
-- that does not divide by three) and true of the newer one (measured on Mists 2026-09-12: an
-- auction the named route calls twenty at 44,993 apiece arrives here as 899,860).
--
-- Rounded down rather than refused. Seven of something at five gold is 71.43 copper each, and the
-- first writing recorded that as nothing at all. Losing a fraction of a copper is arithmetic;
-- losing the auction is losing the reading. A lot so large that one comes to nought is still
-- refused, because nought is not a price anybody paid.
function Auctions:KeepPrice(prices, itemID, lot, quantity, now)
	itemID, lot, quantity = tonumber(itemID), tonumber(lot), tonumber(quantity)
	if not (itemID and lot and quantity) then return 0 end
	if lot <= 0 or quantity <= 0 then return 0 end

	local each = math.floor(lot / quantity)
	if each <= 0 then return 0 end

	local held = prices[itemID]

	if not seenThisVisit[itemID] or type(held) ~= "table" then
		seenThisVisit[itemID] = true
		prices[itemID] = { p = each, at = now }
		return 1
	elseif each < held.p then
		held.p, held.at = each, now
		return 1
	end

	return 0
end

function Auctions:ReadPrices()
	local where = market()
	if not where then return 0 end

	local count = tonumber((Family:TryCall(GetNumAuctionItems, "list"))) or 0
	if count < 1 then return 0 end

	local prices = self:Prices(where)
	local now = time()
	local kept = 0

	for index = 1, count do
		local link = Family:TryCall(GetAuctionItemLink, "list", index)
		local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil

		-- Captured into a table rather than off a run of placeholders, for the reason the
		-- reader above gives: the signature moves between clients (L-032). The stack size is
		-- the third and the buyout the tenth, which is where the owner reader takes them from.
		local row = { Family:TryCall(GetAuctionItemInfo, "list", index) }
		local quantity = tonumber(row[3])
		local buyout = tonumber(row[10])

		-- **A bid-only auction is not a price.** No buyout means the thing has no number
		-- anybody can pay today, and §2.2 says that is silence rather than nought.
		--
		-- **The buyout here is the whole stack**, measured on Era 2026-09-10 and confirmed by
		-- the person who posted it: three of a thing at 2g99s61c, and a minimum bid of 28463,
		-- which does not divide by three at all - and a price of one cannot be a fraction of a
		-- copper, because nobody can type one. So the stack total is what this call gives, and
		-- the price of one is a division Family does.
		--
		-- **Rounded down rather than refused.** The first version kept only stacks that divided
		-- exactly, which on a house where a human types the total for the stack throws most of
		-- them away in silence: seven of something at five gold is 71.43 copper each, and that
		-- was recorded as nothing. Losing less than a copper to a division is arithmetic;
		-- losing the auction is losing the reading. A stack so large that one of them comes to
		-- nought is still refused, because nought is not a price anybody paid.
		kept = kept + Auctions:KeepPrice(prices, itemID, buyout, quantity, now)
	end

	if kept > 0 then
		Family:Debug("auctions: %d price(s) taken from %d row(s) on show", kept, count)
	end

	return kept
end

--------------------------------------------------------------------------------------------
-- Asking, which nothing in this addon has ever done
--
-- Slice 3 of the price work is a full read of everything on sale, and it is the one thing here
-- that could get somebody disconnected. `/family ah` has already settled that the query side
-- exists on both older builds and that `CanSendAuctionQuery` answers. What it cannot settle is
-- **the shape of the call**: a C function takes what it takes and Lua has no way to ask it, and
-- the order of `QueryAuctionItems`' arguments is not the same on every one of these clients.
--
-- So it is measured the only way it can be - one query, on request, and the list read back. Two
-- candidate layouts, and **neither of them is confirmed anywhere in this repository**: where
-- `page` sits is the whole difference between them, and `page` is the only argument a walk has
-- to vary.
--
--     long    name, minLevel, maxLevel, invType, class, subclass, PAGE, usable, quality, getAll, exact
--     short   name, minLevel, maxLevel, PAGE, usable, quality, getAll, exact, filterData
--
-- **`getAll` is false in both and is never offered as a choice.** It is the route that freezes a
-- client and disconnects people, and that it is never sent was decided before any of this was
-- written (backlog 55).
--
-- **The answer is not *did rows arrive*.** A wrong layout can be accepted and quietly query the
-- wrong thing - rows would still come back, and a scanner built on that would walk a filtered
-- list believing it had walked the house. What settles it is the **total beside the rows**, held
-- against the number the player's own auction window is showing on screen. That comparison is
-- not something code can make, which is why this prints and decides nothing.
-- **Nothing is guessed any more: the client's own query is the only shape ever sent.**
--
-- Two candidate layouts stood here, both guesses at the argument order, and one of them was
-- dangerous. Measured on Burning Crusade 2026-09-10 by watching the client itself, that build
-- takes **nine** arguments and `getAll` is the **seventh**:
--
--     ""     0    0    0     false    -1       false    false   nil
--     name   min  max  page  usable   quality  getAll   exact   filterData
--
-- The `long` guess put `page` seventh, and the page was `0`. **In Lua `0` is true** - only nil and
-- false are false - so that call said `getAll = true`, which is the one thing this feature was
-- written never to do. It fits what was seen: ten seconds of silence, because a whole-house read
-- takes far longer than that, and a client crawling a minute later because it was arriving.
--
-- So the guessing is gone. `sawQuery` below records what the auction house asked for, and the only
-- query Family ever sends is **that same call with the page changed** - every argument one the
-- client itself chose, on a build the client itself described.

-- Both returns of it, and the second is the one a page walk needs: how many there are in all.
-- Everything written here so far has used the first and nothing had ever read the second.
function Auctions:ListTotals()
	local onPage, inAll = Family:TryCall(GetNumAuctionItems, "list")
	return tonumber(onPage), tonumber(inAll)
end

-- **Watching the client ask, instead of asking.**
--
-- The better half of the signature question, and it should have been the first: the auction house
-- the player is looking at calls `QueryAuctionItems` itself every time Search is pressed, with the
-- arguments that are right for **this** build. Hooked rather than sent, it costs no traffic, needs
-- no guess, and cannot get anybody disconnected - and it answers exactly what two candidate
-- layouts were written to guess at.
--
-- Measured on Burning Crusade 2026-09-10: one query of ours, accepted by `CanSendAuctionQuery`,
-- with no error and no list update in ten seconds. Twice. Whatever that is, watching the client
-- does not depend on the answer.
--
-- Told once, like the list reader beside it, and armed only on request - a hook that prints on
-- every search is a hook somebody turns the addon off over.
local tellNextQuery
local lastQueries = {}

function Auctions:TellNextQuery(fn)
	tellNextQuery = type(fn) == "function" and fn or nil
end

-- **Where the page sits, worked out rather than assumed.**
--
-- Two of the client's own queries identical but for one place, and that place holding a number in
-- both, can only differ in the page: everything else on that window is a control the player did
-- not touch between one Search and the next. Anything less clear than that answers nothing rather
-- than guessing, because a wrong answer here means walking the wrong argument.
local function pagePositionFrom(now, before)
	if not (now and before) or now.n ~= before.n then return nil end

	local differing
	for index = 1, now.n do
		if now[index] ~= before[index] then
			if differing then return nil end
			differing = index
		end
	end

	if not differing then return nil end
	if type(now[differing]) ~= "number" or type(before[differing]) ~= "number" then
		return nil
	end

	return differing
end

function Auctions:PagePosition()
	return type(_G.FamilyDB) == "table" and FamilyDB.auctionPageAt or nil
end

function Auctions:LastQuery()
	return lastQueries[1]
end

-- Every argument as the client passed it, positions and all - `select("#")` rather than the length
-- of a table, because a nil in the middle **or at the end** is part of the shape and a table's
-- length loses the last one.
local function sawQuery(...)
	local count = select("#", ...)
	local raw = { n = count, ... }

	table.insert(lastQueries, 1, raw)
	lastQueries[3] = nil

	local at = pagePositionFrom(lastQueries[1], lastQueries[2])
	if at and type(_G.FamilyDB) == "table" then FamilyDB.auctionPageAt = at end

	if not tellNextQuery then return end

	local told = tellNextQuery
	tellNextQuery = nil

	local said = {}
	for index = 1, count do
		said[index] = tostring(raw[index])
	end

	Family:TryCall(told, said, count)
end

-- Reading the whole house, one page at a time
--
-- Slice 3, and it is buildable only because of what sits above it: Family does not compose a
-- query, it replays the client's own with the page changed, so a walk varies one number and
-- nothing else. Measured on Burning Crusade 2026-09-11 - the house held **180,205** auctions,
-- which at fifty a page is **3,605 pages**. That is the arithmetic the backlog said would decide
-- whether this is minutes or an evening, and the answer is an evening.
--
-- **Clocked by the server, never by a timer.** The next page is asked for when the previous one
-- has arrived, so the walk runs exactly as fast as the client is being answered and cannot get
-- ahead of it. A timer would keep sending into a server that had stopped replying, which is how
-- addon traffic becomes a disconnection.
--
-- **`CanSendAuctionQuery` before every page**, not just the first. It answers about now, and a
-- walk spends an hour in a lot of nows.
--
-- **And it stops on everything that is not progress**: the house closing, a refusal, a page that
-- does not arrive within half a minute, or the player saying so. Never `getAll` - that is not a
-- setting here, it is an argument of the client's own that Family never touches.
local walk

local PAGE_ROWS = 50
local QUIET_SECONDS = 30

-- How long the answers to one query are given to stop arriving before the next goes out.
--
-- `AUCTION_ITEM_LIST_UPDATE` fires several times for a single query, which is why this exists
-- rather than asking the moment the first one lands, and a server that has just sent six
-- messages is not asking to be written to again immediately.
--
-- **It is also the walk's only pacing, which makes it the only part of the speed anybody here
-- decides.** Measured on Burning Crusade 2026-09-11: sixty-eight pages in forty-nine seconds,
-- about three quarters of a second each, of which this was three tenths - so the server took
-- roughly four tenths and Family spent the rest waiting on purpose. Over a house of 3,605 pages
-- that is eighteen minutes of a forty-three minute read.
--
-- Alberto's comparison is what sized it: another addon reads the same house in about fifteen
-- minutes, which is a quarter of a second a page in total - less than this delay alone was. Cut
-- to a tenth on his instruction, which gives back about twelve of those eighteen minutes and is
-- still a real pause between one page and the next. It does not close the gap: even at nothing
-- at all the server's own four tenths a page is twenty-five minutes, and what the rest of that
-- difference is has not been measured by anybody here.
local SETTLE_SECONDS = 0.1

function Auctions:Walking()
	return walk ~= nil and walk or nil
end

-- **How long a walk has been going.** Asked for from play 2026-09-11 - *and how long will it
-- take?* - which nothing could answer, because the walk timed itself and told nobody.
--
-- A reading rather than an estimate: the file's own comment said *the best part of an hour* for
-- three and a half thousand pages, and that was arithmetic somebody did in their head.
function Auctions:WalkSeconds(state)
	state = state or walk
	if not state or not state.clock then return nil end

	local now = tonumber((Family:TryCall(GetTime)))
	if not now then return nil end

	return now - state.clock
end

-- **How much of that was the server.** The rest is the settling Family does between pages, which
-- is the only half anybody here can decide about.
function Auctions:WalkWaiting(state)
	state = state or walk
	return state and state.waited or nil
end

-- **And how long the client spent refusing to send.** A third thing, not a share of the other
-- two: `CanSendAuctionQuery` answering no is the server's throttle reaching us through the
-- client, and it is neither the answer taking time nor a delay anybody here chose.
function Auctions:WalkHeld(state)
	state = state or walk
	return state and state.held or nil
end

function Auctions:StopWalk(why)
	if not walk then return false end
	local stopping, told = walk, walk.told
	walk = nil
	if told then Family:TryCall(told, "stopped", stopping, why) end
	return true
end

-- One page, or a reason there is not one.
local function askPage(page)
	if not walk then return end

	if not Family:TryCall(CanSendAuctionQuery) then
		-- Waited for rather than pushed through: this is the client saying not yet, and
		-- the only wrong answer is to ask again immediately.
		walk.waits = (walk.waits or 0) + 1
		if walk.waits > 60 then
			return Auctions:StopWalk("refusing")
		end

		-- **And how long it goes on saying it**, which turned out to be most of a read.
		-- Reported from play on Classic Era 2026-09-12: 394 pages in five minutes, of
		-- which one was the server answering - leaving four that were called *Family's own
		-- pacing* when the settle at a tenth of a second a page accounts for forty seconds
		-- of them. The rest is here, in half-second retries nobody was counting.
		walk.heldFrom = walk.heldFrom or tonumber((Family:TryCall(GetTime)))

		return Family:After(0.5, "auctions.walk", function() askPage(page) end)
	end

	if walk.heldFrom then
		local now = tonumber((Family:TryCall(GetTime)))
		if now then walk.held = (walk.held or 0) + (now - walk.heldFrom) end
		walk.heldFrom = nil
	end

	walk.waits = 0
	walk.page = page
	walk.sentAt = time()

	-- **When this one went out**, so that what the server took can be told apart from what
	-- Family's own pacing took. Asked from play: could a read be made faster? Only the second
	-- half is ours to decide, and until now nothing said how big it was.
	walk.sentClock = tonumber((Family:TryCall(GetTime)))

	local ok = Auctions:ReplayQuery(page)
	if not ok then return Auctions:StopWalk("query") end

	-- A page that never arrives ends the walk rather than leaving it looking alive.
	Family:After(QUIET_SECONDS, "auctions.walk.quiet", function()
		if walk and walk.sentAt and (time() - walk.sentAt) >= QUIET_SECONDS then
			Auctions:StopWalk("quiet")
		end
	end)
end

-- What arrived, and then the next one. Called from the scanner's own list handler, after the
-- prices on the page have been read - so the walk never reads anything itself.
-- **What the pages gave up, counted as they arrive.**
--
-- Reported from play on Classic Era 2026-09-11: ninety-nine pages read and the count of prices
-- known went from 3923 to 3925. That figure is *how many items this market has a price for*, so
-- it only moves for an item nobody has ever browsed - which after a season of ordinary searching
-- is almost none of them, and a walk that is working looks exactly like a walk that is re-reading
-- page nought.
--
-- `ReadPrices` answers how many it took off the page, and within one visit the first sighting of
-- an item always counts - so a page of fifty gives up about fifty the first time it is seen and
-- almost nothing the second. Summed here, it is the one number that tells the two apart.
local function walkHeard(kept)
	if not walk then return end

	walk.kept = (walk.kept or 0) + (tonumber(kept) or 0)

	-- **One page in, one page out.** `AUCTION_ITEM_LIST_UPDATE` fires several times for a
	-- single query - this file has said so since the passive reader was written - so without
	-- this the walk advanced on every one of them: it asked for the next page once per event
	-- rather than once per page, and said so in the chat frame six times running.
	--
	-- Seen in play on Classic Era 2026-09-11: *page 25 of 537* printed six times, *page 75*
	-- six more. The duplicated lines were the harmless half; the duplicated queries were not.
	--
	-- Not waiting for anything now, which is what the quiet timeout reads.
	walk.sentAt = nil

	-- And the round trip goes on the pile, once per page rather than once per answer: the
	-- clock is cleared with the flag above it, so the five answers that follow add nothing.
	if walk.sentClock then
		local now = tonumber((Family:TryCall(GetTime)))
		if now then walk.waited = (walk.waited or 0) + (now - walk.sentClock) end
		walk.sentClock = nil
	end

	-- **The burst is let settle, and settling is what collapses it.** `Family:After` replaces a
	-- pending timer of the same key, so six answers to one query schedule the same callback six
	-- times and it runs once. A flag saying *already answered* was written here first and did
	-- nothing the key was not already doing - no check could tell the two apart, which is what
	-- says it should not be here.
	--
	-- It is also the gentler thing to do to a server that has just sent six messages.
	Family:After(SETTLE_SECONDS, "auctions.walk.settle", function()
		if not walk then return end

		-- **A page is settled once, and the key alone does not promise that.**
		--
		-- Replacing a pending timer collapses the answers that arrive *before* it fires. It
		-- says nothing about one that arrives after - and there is a window where that
		-- matters, because `walk.done` is worked out from `walk.page`, and `askPage` writes
		-- `walk.page` only once the client has accepted the query. A client saying *not yet*
		-- leaves the number where it was, so a late answer settles the same page again:
		-- announces it again, and asks for it again.
		--
		-- Seen in play on Burning Crusade 2026-09-12, on a connection that was failing -
		-- which is exactly when `CanSendAuctionQuery` refuses: *page 25 of 3704* printed
		-- twice, identically. This is a second cause of the symptom the settle was added
		-- for, and the settle cannot reach it. Cutting the settle to a tenth of a second
		-- widened the window rather than making it.
		if walk.settledFor == walk.page then return end
		walk.settledFor = walk.page

		local _, inAll = Auctions:ListTotals()
		if inAll and inAll > 0 then
			walk.inAll = inAll
			walk.pages = math.ceil(inAll / PAGE_ROWS)
		end

		walk.done = (walk.page or 0) + 1

		if walk.told then Family:TryCall(walk.told, "page", walk) end

		if walk.pages and walk.done >= walk.pages then
			local finished, told = walk, walk.told
			walk = nil
			if told then Family:TryCall(told, "finished", finished) end
			return
		end

		askPage(walk.done)
	end)
end

-- **Started only by somebody asking for it**, and it says what it is about to do before it does
-- it. The size is not known until the first page comes back, which is why the first page is the
-- whole of what starting it commits to.
-- `everything` is the caller saying it has cleared the search form itself, and it is a claim
-- rather than a guess: Family cannot look at a query and tell a blank one from a narrow one, so
-- whoever pressed Reset is the only thing that knows. Reported from play 2026-09-11 - a walk of
-- sixty-eight pages announced as *the whole house* on a house this repository had already
-- measured at three and a half thousand.
function Auctions:StartWalk(told, everything)
	-- **A code, never a sentence.** These are said to the player, and a sentence written here
	-- would be an English one wherever it was read (§2.1). The words live in `Slash.lua`, where
	-- everything else the player is told lives and where the translation gate can see them.
	if walk then return false, "running" end

	-- **The newer house is not walked this way, and saying *no query seen yet* there would be
	-- true and misleading.** On Mists the old calls are shells - all three selectors answer
	-- nought and `AUCTION_ITEM_LIST_UPDATE` never fires - and the client never calls
	-- `QueryAuctionItems` at all, so the thing this waits for cannot happen. Measured
	-- 2026-09-11: `/family ah watch` armed and nothing was ever printed. That house answers one
	-- row per item with a count beside it and has no pages to walk.
	if _G.C_AuctionHouse and type(C_AuctionHouse.SendBrowseQuery) == "function" then
		return false, "newerHouse"
	end

	if not self:LastQuery() then return false, "seenNothing" end
	if not self:PagePosition() then return false, "pageUnknown" end

	-- Two clocks, because they answer different questions. `time()` says *when this started*
	-- and counts whole seconds of wall clock; `GetTime` is the one to subtract for *how long it
	-- has been going*, and it is the one that moves under a harness.
	walk = { page = 0, done = 0, started = time(), told = told,
		everything = everything and true or false,
		clock = tonumber((Family:TryCall(GetTime))) }
	askPage(0)
	return true, nil
end

Auctions.__walkHeard = walkHeard

-- **And the newer house's own query, watched the same way.**
--
-- Mists does not call `QueryAuctionItems` at all - measured 2026-09-11, the watcher was armed and
-- stayed silent - and its house has no pages: one row per item with a count beside it, five
-- hundred rows to a browse. Its full read is the same shape as the old one all the same, which is
-- *replay what the client asked for*: `SendBrowseQuery` with whatever the auction house itself
-- passes, and then more results asked for until it says there are no more.
--
-- **What is in that query is not written down here and is not going to be guessed.** It is a
-- table rather than a row of arguments, so the argument-order trap of L-071 cannot happen - but
-- the field names are exactly as much hearsay, and one wrong one is a query that searches for
-- something nobody asked about.
local tellNextBrowse
local lastBrowse

function Auctions:TellNextBrowse(fn)
	tellNextBrowse = type(fn) == "function" and fn or nil
end

function Auctions:LastBrowse()
	return lastBrowse
end

-- The table the client passed, described a field at a time. One level deep and no further: the
-- sorts and the filters are lists of tables, and saying how many are in each is what a reader
-- needs to know that they are there at all.
local function describe(query)
	local rows = {}
	if type(query) ~= "table" then
		rows[#rows + 1] = { "-", type(query) }
		return rows
	end

	-- **The keys themselves, not their names.** Looking a value up again by `tostring(key)`
	-- loses every numeric key, and fetching it through `a ~= nil and a or b` loses every value
	-- that is `false` - which on this query is `exactMatch`, a field that is false far more
	-- often than it is true. The check for it went red on the first writing.
	local keys = {}
	for key in pairs(query) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

	for _, key in ipairs(keys) do
		local value = query[key]
		if type(value) == "table" then
			local count = 0
			for _ in pairs(value) do count = count + 1 end
			rows[#rows + 1] = { tostring(key), "{" .. count .. "}" }
		else
			rows[#rows + 1] = { tostring(key), tostring(value) }
		end
	end

	return rows
end

Auctions.__describeBrowse = describe

local function sawBrowse(query)
	lastBrowse = query

	if not tellNextBrowse then return end

	local told = tellNextBrowse
	tellNextBrowse = nil
	Family:TryCall(told, describe(query))
end

Auctions.__sawBrowse = sawBrowse

-- **The client's own call, with the page changed and nothing else.**
--
-- This is the whole of what a page walk is allowed to send. Every argument is one the auction
-- house itself chose on this build, so there is no order to guess at and no boolean slot to put a
-- number into; the page goes where two of the client's own queries showed it to be.
function Auctions:ReplayQuery(page)
	local last = lastQueries[1]
	if not last then
		return false, "no query of the client's own has been seen this session"
	end

	local at = self:PagePosition()
	if not at then
		return false, "which argument is the page has not been worked out yet"
	end

	if type(_G.QueryAuctionItems) ~= "function" then
		return false, "QueryAuctionItems is not a function on this client"
	end

	if not Family:TryCall(CanSendAuctionQuery) then
		return false, "the client says a query would not be accepted right now"
	end

	local args = {}
	for index = 1, last.n do args[index] = last[index] end
	args[at] = tonumber(page) or 0

	-- `pcall` rather than `TryCall`, because here an error is the measurement and TryCall throws
	-- the words away. `unpack` with an explicit end, so a trailing nil is still sent.
	local ok, err = pcall(_G.QueryAuctionItems, unpack(args, 1, last.n))
	if not ok then return false, tostring(err) end
	return true, nil
end

Auctions.__sawQuery = sawQuery

-- **The next list update, told once.**
--
-- Registered through the scanner's own handler rather than as a second one of its own: an event
-- key registered twice replaces what was there, which is how a probe once came to report an
-- event arriving because the probe was the thing that had replaced it (L-068).
local tellNextList

function Auctions:TellNextList(fn)
	tellNextList = type(fn) == "function" and fn or nil
end

-- What is actually on the list, printed rather than summarised, so a layout that was accepted
-- and queried the wrong thing can be seen to have done so.
function Auctions:OldListSample(howMany)
	local onPage = tonumber((Family:TryCall(GetNumAuctionItems, "list"))) or 0
	local rows = {}

	for index = 1, math.min(onPage, tonumber(howMany) or 3) do
		local link = Family:TryCall(GetAuctionItemLink, "list", index)
		local row = { Family:TryCall(GetAuctionItemInfo, "list", index) }

		rows[#rows + 1] = {
			index,
			type(link) == "string" and (link:match("item:(%d+)") or "?") or "?",
			tostring(row[3]),
			tostring(row[10]),
		}
	end

	return rows
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("auctions", function()
	Family:RegisterEvent("AUCTION_HOUSE_SHOW", "auctions", function()
		Auctions:ForgetVisit()

		-- Asking is what makes the answer arrive; reading without asking gets whatever
		-- the last visit left behind. The newer house wants the same asking under another
		-- name, and it is the same act rather than a bolder one: one's own listings, at a
		-- window one has just opened.
		Family:After(1, "auctions.ask", function()
			Family:TryCall(GetOwnerAuctionItems)
			if C_AuctionHouse then
				Family:TryCall(C_AuctionHouse.QueryOwnedAuctions, {})
			end
		end)
	end)

	Family:RegisterEvent("AUCTION_HOUSE_CLOSED", "auctions", function()
		Auctions:ForgetVisit()
		-- Walking away from the auctioneer ends the read. Everything already taken is kept:
		-- a half-read house is a lot of prices, not a failure. Both houses, because a client
		-- has one of them and the call for the other is a shell that answers nought.
		Auctions:StopReplicateRead("closed")
		Auctions:StopWalk("closed")
	end)

	-- A key of their own. Under "auctions" these counters replaced the handlers registered
	-- above them for the two events they share, so opening the auction house stopped asking
	-- for this character's own listings and nothing was ever scanned.
	for _, event in ipairs(MODERN_EVENTS) do
		Family:RegisterEvent(event, "auctions.heard", function()
			modernHeard[event] = (modernHeard[event] or 0) + 1
		end)
	end

	-- **And the whole-list read answering, where this build has one.** Its own key, and
	-- registered on every client - `Family:RegisterEvent` answers false for an event a client
	-- does not have and leaves nothing behind, so this costs Era nothing.
	Family:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", "auctions.replicate", function()
		replicateHeard = replicateHeard + 1

		-- A read waiting on it starts here, before the probe is told: the reading is the
		-- feature and the probe is what measured it.
		replicateAnswered()

		if not tellNextReplicate then return end
		local told = tellNextReplicate
		tellNextReplicate = nil
		Family:TryCall(told)
	end)

	-- The newer house's own way of saying the same thing. `..._ADDED` is here because it is
	-- how further results arrive where they arrive in pieces, and it costs nothing on a
	-- client that never sends it.
	for _, event in ipairs { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
		"AUCTION_HOUSE_BROWSE_RESULTS_ADDED" } do
		Family:RegisterEvent(event, "auctions.prices", function()
			Auctions:ReadModernPrices()
		end)
	end

	-- The browse list, which is whatever the player last searched for. Read rather than
	-- asked for: nothing here sends a query.
	Family:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "auctions", function()
		fired = fired + 1
		lastRows = tonumber((Family:TryCall(GetNumAuctionItems, "list"))) or 0
		local kept = Auctions:ReadPrices()

		-- And if a read of the whole house is running, this is its clock: the next page is
		-- asked for because this one arrived, never because a timer went off. What the page
		-- gave up goes with it, because that is the only figure that says the walk is really
		-- moving - see `walkHeard`.
		walkHeard(kept)

		-- And whoever asked to be told about the next one, told once. Inside this handler
		-- rather than beside it: a second registration under this event's key would have
		-- replaced the three lines above, which is L-068 exactly.
		if tellNextList then
			local told = tellNextList
			tellNextList = nil
			Family:TryCall(told)
		end
	end)

	for _, event in ipairs { "AUCTION_OWNED_LIST_UPDATE", "AUCTION_BIDDER_LIST_UPDATE",
		"OWNED_AUCTIONS_UPDATED" } do
		Family:RegisterEvent(event, "auctions", function()
			Family:After(0.5, "auctions", function() Auctions:Scan() end)
		end)
	end

	-- Watching the bid go, the same way the outgoing letter is watched: hooked rather than
	-- reimplemented, because the bid is Blizzard's and the browse list is still standing when
	-- the hook runs. Without the hook Family simply learns about the item later, when the
	-- mailbox is opened - which is what it did before this existed.
	-- The client's own query, watched. `hooksecurefunc` runs after the real call and takes
	-- nothing away from it, which is the same arrangement the bid below uses.
	if type(_G.hooksecurefunc) == "function" and type(_G.QueryAuctionItems) == "function" then
		Family:TryCall(_G.hooksecurefunc, "QueryAuctionItems", sawQuery)
	else
		Family:Debug("no way to watch auction queries on this client")
	end

	-- The same, for the house that has no pages. A table method rather than a global, which
	-- `hooksecurefunc` takes as its first two arguments.
	if type(_G.hooksecurefunc) == "function" and _G.C_AuctionHouse
		and type(C_AuctionHouse.SendBrowseQuery) == "function" then
		Family:TryCall(_G.hooksecurefunc, C_AuctionHouse, "SendBrowseQuery", sawBrowse)
	end

	if type(_G.hooksecurefunc) == "function" and type(_G.PlaceAuctionBid) == "function" then
		Family:TryCall(_G.hooksecurefunc, "PlaceAuctionBid", function(list, index)
			Auctions:NoteBid(list, index)
		end)
	else
		Family:Debug("no way to watch auction bids on this client")
	end

	Family:RegisterEvent("CHAT_MSG_SYSTEM", "auctions", function(_, message)
		local pattern = wonPattern()
		if pattern and type(message) == "string" and message:match(pattern) then
			Auctions:NoteWon()
		end
	end)
end)
