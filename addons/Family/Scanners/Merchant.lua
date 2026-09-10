-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a vendor charges, learned from the vendors you actually open.
--
-- Asked for 2026-09-10 by one of Alberto's users, who wanted what a dedicated vendor-price addon
-- gives. Half of that needs nothing at all - the client hands the *sell* price with every item -
-- and the other half is this file, for reasons measured rather than assumed and written up in
-- `docs/DATASOURCES.md` §3 under *The two prices, and what only one of them means*.
--
-- The short of it: the client's own tables carry a buy price for nearly every item, including
-- 4093 epics and 29 legendaries that nothing sells - Sulfuras reads 166 gold and is forged. So
-- the number alone does not say a vendor has it, and **which vendor stocks what is nowhere in the
-- client**: wago.tools serves no such table on any of the three builds, because vendor inventories
-- live in the server's database. That is why a catalogue site gathers them from players walking
-- past the NPCs.
--
-- So Family gathers them the same way, from the merchant frames this player opens. It is not a
-- lesser version of a shipped table; it is the same mechanism, for one account, and it is better
-- in the way that matters - what it records was demonstrably for sale, at a price demonstrably
-- charged.

local Family = _G.Family

local Merchant = {}
Family.Merchant = Merchant

local function idFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

-- Account-wide, and by id with no language in it - the same arrangement as `FamilyDB.areas`.
-- A price is a number, so unlike a name it needs no locale beside it.
function Merchant:Prices()
	if type(_G.FamilyDB) ~= "table" then return {} end
	FamilyDB.vendorPrices = FamilyDB.vendorPrices or {}
	return FamilyDB.vendorPrices
end

function Merchant:PriceOf(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	return self:Prices()[itemID]
end

-- **The highest price ever seen is the one kept**, which is not a guess about which sighting is
-- better but the one direction a discount can move.
--
-- A reputation discount only ever lowers what a vendor asks, and every vendor asks the same base
-- for the same item. So the largest figure any character has been quoted is the closest thing to
-- the base that observation can produce, and each further sighting can only improve it. A record
-- that kept the newest instead would let one exalted character understate the price for the whole
-- family, and one that kept the lowest would do it permanently.
--
-- This is also why nothing has to be stored about *who* saw it, or where.
local function remember(prices, itemID, each)
	local before = prices[itemID]
	if before == nil then
		prices[itemID] = each
		return "learned"
	end
	if each > before then
		prices[itemID] = each
		return "raised"
	end
	return nil
end

-- One merchant's window, read while it is open.
function Merchant:Read()
	local count = tonumber((Family:TryCall(GetMerchantNumItems))) or 0
	if count < 1 then return 0, 0 end

	local prices = self:Prices()
	local learned, raised = 0, 0

	for index = 1, count do
		local _, _, price, quantity = Family:TryCall(GetMerchantItemInfo, index)
		local itemID = idFromLink(Family:TryCall(GetMerchantItemLink, index))

		price, quantity = tonumber(price), tonumber(quantity)

		-- **Anything bought with something other than money is passed over.**
		--
		-- Badges, honour, marks and the rest are an *extended cost*, and where one is
		-- attached the money figure is a part of the price rather than the price. Recording
		-- it would put a few silver against an epic. `GetMerchantItemCostInfo` says how many
		-- such components a row has; a client that does not have the call answers nothing,
		-- which reads as none, and the narration below is how that would be noticed.
		local components = tonumber((Family:TryCall(GetMerchantItemCostInfo, index))) or 0

		-- A stack has one price, so the price of one is a division - and only where it
		-- divides exactly. It always should; where it does not, §2.2 says say nothing
		-- rather than round something into the record.
		if itemID and components == 0 and price and price > 0
			and quantity and quantity > 0 and price % quantity == 0 then
			local what = remember(prices, itemID, price / quantity)
			if what == "learned" then learned = learned + 1
			elseif what == "raised" then raised = raised + 1 end
		end
	end

	if learned > 0 or raised > 0 then
		Family:Debug("merchant: %d price(s) learned, %d raised, of %d row(s)",
			learned, raised, count)
	end

	return learned, raised
end

Family:OnDatabaseReady("merchant", function()
	-- Both, because the window is filled in after it opens and a page turn is an update
	-- rather than a fresh show. Reading twice costs a walk of a list already in memory.
	Family:RegisterEvent("MERCHANT_SHOW", "merchant", function() Merchant:Read() end)
	Family:RegisterEvent("MERCHANT_UPDATE", "merchant", function() Merchant:Read() end)
end)
