-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The other money: honor, arena points, and whatever else the client calls a currency.
--
-- These buy items exactly as gold does, and an alt manager that reports gold and not these
-- is answering half the question. On the clients Family runs on that means at least honor
-- and arena points, and on Mists a list of a dozen the player has never counted.
--
-- Three different clients, three different ways of being asked, and no way to find out which
-- one this is except by trying (§2.1 and the note in Talents.lua at length). So each way is
-- tried in turn, and Family records whichever answered. A client that answers none of them
-- records nothing, which is the honest outcome and not a fault.
--
-- Ids, not names. "Honor Points" is "Points d'honneur" on a French client and a member
-- scanned there has to line up in a column with a member scanned here. The standalone honor
-- and arena calls of the Burning Crusade clients hand over no id at all, so those two get a
-- name of Family's own - "honor" and "arena", never translated, never shown - and the label
-- on screen comes from whichever client last saw them.

local Family = _G.Family

local Currencies = {}
Family.Currencies = Currencies

--------------------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------------------

-- The id inside a currency link, which is the only place several of these calls put one.
local function idFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("currency:(%d+)"))
end

local function positive(value)
	local number = tonumber(value)
	if not number or number <= 0 then return nil end
	return number
end

-- One entry, from whatever shape the client answered in.
--
-- Never by position: the list call returns eleven values on one client and a table on
-- another, and both have been the truth at some point in these clients' lives.
local function entryFrom(id, name, quantity, maximum, icon, kind)
	local count = tonumber(quantity)
	if not count then return nil end
	if type(name) ~= "string" or name == "" then name = nil end

	-- Every entry has a key or it is not an entry. An id makes the best one, Family's own
	-- word for honor and arena the next best, and a name the worst - a name will not line
	-- up across two language clients, but it is a great deal better than the nothing this
	-- used to hand back when a client kept a currency list and would not link to it. That
	-- nothing then went straight into a table index and took the summary down with it.
	local key = id and ("c" .. id) or kind or (name and ("n:" .. name))
	if not key then return nil end

	return {
		id = id,
		key = key,
		kind = kind,
		name = name,
		quantity = count,
		-- A cap of zero means "no cap" everywhere this appears, and drawing 0 as the
		-- ceiling would report every currency as overflowing.
		max = positive(maximum),
		icon = icon,
	}
end

-- Mists and anything on the modern engine: the whole list, in the order the player sees it,
-- headers and all.
local function readModernList()
	local api = _G.C_CurrencyInfo
	if type(api) ~= "table" then return nil end

	local size = tonumber(Family:TryCall(api.GetCurrencyListSize)) or 0
	if size == 0 then return nil end

	local found = {}
	for index = 1, size do
		local info = Family:TryCall(api.GetCurrencyListInfo, index)

		-- A table, and the headers in the list are not currencies.
		if type(info) == "table" and not info.isHeader then
			local id = tonumber(info.currencyID)
				or idFromLink(Family:TryCall(api.GetCurrencyListLink, index))

			local entry = entryFrom(id, info.name, info.quantity, info.maxQuantity,
				info.iconFileID or info.icon)
			if entry then found[#found + 1] = entry end
		end
	end

	return #found > 0 and found or nil
end

-- The list as the clients before that one answered it: eleven return values, no table.
local function readGlobalList()
	if type(_G.GetCurrencyListSize) ~= "function" then return nil end

	local size = tonumber(Family:TryCall(GetCurrencyListSize)) or 0
	if size == 0 then return nil end

	local found = {}
	for index = 1, size do
		local name, isHeader, _, _, _, count, icon, maximum =
			Family:TryCall(GetCurrencyListInfo, index)

		if not isHeader then
			local entry = entryFrom(idFromLink(Family:TryCall(GetCurrencyListLink, index)),
				name, count, maximum, icon)
			if entry then found[#found + 1] = entry end
		end
	end

	return #found > 0 and found or nil
end

-- Honor and arena points on the clients that have them and no list to put them in.
--
-- Kept separate from the lists above rather than folded into them: these two answer a bare
-- number and nothing else, so the name and the picture have to be Family's, and a client
-- that has both a list and these calls should be believed about the list.
local STANDALONE = {
	{ kind = "honor", call = "GetHonorCurrency", label = "Honor",
		icon = "Interface\\Icons\\Achievement_PVP_A_A" },
	{ kind = "arena", call = "GetArenaCurrency", label = "Arena",
		icon = "Interface\\Icons\\Achievement_Arena_2v2_1" },
}

local function readStandalone()
	local found = {}

	for _, source in ipairs(STANDALONE) do
		local answer = Family:TryCall(_G[source.call])

		-- A call that is missing and a call that answers nothing both come back as nil, and
		-- neither is a balance of zero. A client with no arena points has no arena points
		-- to report, which is not the same as a character who has spent all of theirs -
		-- but the client that has the call reports the zero itself, so it is kept.
		local count = tonumber(answer)
		if count then
			local entry = entryFrom(nil, source.label, count, nil, source.icon, source.kind)
			if entry then found[#found + 1] = entry end
		end
	end

	return #found > 0 and found or nil
end

-- Everything this client will say, from whichever of the three knows how to ask it.
--
-- One of them, not several. A client that keeps a list has honor and arena points in that
-- list, and asking the old calls as well would count the same points twice under two
-- different keys - once with the id the list gave and once with a name of Family's own,
-- which is worse than double, because nothing downstream could tell they were the same
-- thing. The standalone calls are what a client with no list has instead, and only that.
function Currencies:Read()
	local found = readModernList() or readGlobalList() or readStandalone()
	if not found then return nil end

	table.sort(found, function(a, b)
		if (a.id or 0) ~= (b.id or 0) then return (a.id or 0) < (b.id or 0) end
		return tostring(a.key) < tostring(b.key)
	end)

	return #found > 0 and found or nil
end

--------------------------------------------------------------------------------------------
-- Recording
--
-- In meta rather than in the payload. The summary totals these across the whole family, and
-- meta is what it may read without decoding anybody (HANDOFF §1). It stays small: a handful
-- of entries on the clients that have any, a dozen on Mists.
--------------------------------------------------------------------------------------------

function Currencies:Scan()
	local key = Family:CurrentMember()
	if not key then return end

	local found = self:Read()

	-- Nothing found leaves what was there alone. A client that will not answer today is not
	-- evidence that yesterday's answer was wrong, and clearing it would turn a currency the
	-- player has into one they are told they do not (§2.2).
	if not found then
		Family:Debug("no currencies on this client")
		return
	end

	Family.Database:SetMeta(key, {
		currencies = found,
		currenciesSeen = time(),
	})

	Family:Debug("scanned %d currencies", #found)
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("currencies", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "currencies", function()
		Family:After(5, "currencies", function() Currencies:Scan() end)
	end)

	-- Whichever of these the client has. Honor arrives at the end of a battleground, arena
	-- points once a week, and the modern list announces itself for all of them.
	for _, event in ipairs {
		"CURRENCY_DISPLAY_UPDATE",
		"PLAYER_PVP_KILLS_CHANGED",
		"HONOR_CURRENCY_UPDATE",
		"UPDATE_BATTLEFIELD_SCORE",
		"PLAYER_MONEY",
	} do
		Family:RegisterEvent(event, "currencies", function()
			Family:After(3, "currencies", function() Currencies:Scan() end)
		end)
	end
end)
