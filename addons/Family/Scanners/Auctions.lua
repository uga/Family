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

		if name then
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
		-- anybody can pay today, and §2.2 says that is silence rather than nought. The stack
		-- is divided only where it divides exactly, as at a vendor.
		if itemID and buyout and buyout > 0 and quantity and quantity > 0
			and buyout % quantity == 0 then
			local each = buyout / quantity
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
		Family:Debug("auctions: %d price(s) taken from %d row(s) on show", kept, count)
	end

	return kept
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
	end)

	for _, event in ipairs(MODERN_EVENTS) do
		Family:RegisterEvent(event, "auctions", function()
			modernHeard[event] = (modernHeard[event] or 0) + 1
		end)
	end

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
		Auctions:ReadPrices()
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
