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

function Auctions:Scan()
	local key = Family:CurrentMember()

	local selling = readList("owner")
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
		-- the last visit left behind.
		Family:After(1, "auctions.ask", function()
			Family:TryCall(GetOwnerAuctionItems)
		end)
	end)

	Family:RegisterEvent("AUCTION_HOUSE_CLOSED", "auctions", function()
		Auctions:ForgetVisit()
	end)

	-- The browse list, which is whatever the player last searched for. Read rather than
	-- asked for: nothing here sends a query.
	Family:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "auctions", function()
		Auctions:ReadPrices()
	end)

	for _, event in ipairs { "AUCTION_OWNED_LIST_UPDATE", "AUCTION_BIDDER_LIST_UPDATE" } do
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
