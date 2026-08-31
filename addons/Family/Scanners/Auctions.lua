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

Family:OnDatabaseReady("auctions", function()
	Family:RegisterEvent("AUCTION_HOUSE_SHOW", "auctions", function()
		-- Asking is what makes the answer arrive; reading without asking gets whatever
		-- the last visit left behind.
		Family:After(1, "auctions.ask", function()
			Family:TryCall(GetOwnerAuctionItems)
		end)
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
