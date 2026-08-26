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
end)
