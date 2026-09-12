-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What came out of the mailbox, said out loud.
--
-- Asked for 2026-09-12: *quando un personaggio legge e scarica i messaggi dalla casella postale,
-- stampiamo una riga in chat per ogni oggetto scaricato, e per ogni somma incassata. Alla
-- chiusura della casella, stampiamo il totale: x oggetti ricevuti, y g/s/c totali incassati.*
--
-- The game says nothing about what a mailbox full of auction returns actually came to, which is
-- the whole of why this exists.
--
-- **Read from what left the inbox, not from what was asked for.** Hooking `TakeInboxItem` and
-- reporting its arguments would announce a stack that never arrived, because a take the server
-- refuses - bags full, and a mailbox of auction returns is exactly when bags are full - looks
-- identical from inside the hook. So the inbox is remembered and compared, and only what is
-- actually gone is counted.
--
-- **But a take has to have been asked for.** A diff alone would report a letter that expired
-- while the box was open, and - worse - a letter the player *returned to sender*, as things they
-- received. The hooks arm the comparison and the comparison decides what to say: neither half is
-- enough on its own.
--
-- Off until somebody switches it on (Family/Extras.lua), because a line per item is a great many
-- lines and nobody asked for them by installing an alt manager.

local _, UI = ...

local Family = _G.Family
local L = Family.L

-- What the inbox held when it was last looked at: item id -> { name =, count = }, and the money
-- sitting in unread letters. Aggregated by item rather than by slot, because taking one letter
-- shifts every index after it and a slot is not a thing that survives that.
local held, heldMoney

-- Whether the player has asked for anything since the last comparison. Set by the hooks, cleared
-- by the comparison that answers them.
local asked = false

-- What this visit has come to, which is what gets said on the way out.
local visitItems, visitMoney = 0, 0

local function wanted()
	return Family.Extras and Family.Extras:On("mailReport")
end

-- **Every slot, not the first `itemCount` of them**, which is L-044 and is why the scanner beside
-- this one walks the client's own constant. A letter of ten can carry attachments past the tenth
-- slot, and a loop bounded by the count silently misses them.
local function inboxNow()
	local items, money = {}, 0
	local count = tonumber((Family:TryCall(GetInboxNumItems))) or 0
	local slots = tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or 16

	for index = 1, count do
		local _, _, _, _, letterMoney = Family:TryCall(GetInboxHeaderInfo, index)
		money = money + (tonumber(letterMoney) or 0)

		for attachment = 1, slots do
			local name, itemID, _, quantity = Family:TryCall(GetInboxItem, index, attachment)
			itemID = tonumber(itemID)

			-- An older client answers no id here and a link everywhere else, which is the
			-- same fallback the scanner uses a few files away.
			if not itemID then
				local link = Family:TryCall(GetInboxItemLink, index, attachment)
				itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
			end

			if itemID then
				local row = items[itemID] or { name = name, count = 0 }
				row.name = row.name or name
				row.count = row.count + (tonumber(quantity) or 1)
				items[itemID] = row
			end
		end
	end

	return items, money
end

-- **What is gone since the last look**, said one line at a time.
local function sayWhatLeft()
	local now, money = inboxNow()

	if held and asked then
		for itemID, was in pairs(held) do
			local still = (now[itemID] or {}).count or 0
			local gone = was.count - still

			if gone > 0 then
				visitItems = visitItems + gone
				Family:Print(L["received %d x %s"], gone,
					was.name or Family.Names:CachedItem(itemID)
						or string.format(L["item %d"], itemID))
			end
		end

		local coin = (heldMoney or 0) - money
		if coin > 0 then
			visitMoney = visitMoney + coin
			Family:Print(L["collected %s"], UI:Coins(coin))
		end
	end

	held, heldMoney = now, money
	asked = false
end

-- **The way out**, which is the figure somebody actually wanted: a mailbox of auction returns is
-- forty lines and one number.
local function sayTheTotal()
	if wanted() and (visitItems > 0 or visitMoney > 0) then
		Family:Print(L["|cff66bbffFrom the mailbox:|r %d item(s), %s collected"],
			visitItems, UI:Coins(visitMoney))
	end

	held, heldMoney, asked = nil, nil, false
	visitItems, visitMoney = 0, 0
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("ui.mailreport", function()
	-- **Its own key.** A second registration under the mail scanner's would replace the
	-- scanner's, which is L-068 and has already cost this addon a feature once.
	Family:RegisterEvent("MAIL_SHOW", "ui.mailreport", function()
		held, heldMoney = inboxNow()
		asked = false
		visitItems, visitMoney = 0, 0
	end)

	Family:RegisterEvent("MAIL_INBOX_UPDATE", "ui.mailreport", function()
		if not wanted() then
			held, heldMoney, asked = nil, nil, false
			return
		end
		sayWhatLeft()
	end)

	Family:RegisterEvent("MAIL_CLOSED", "ui.mailreport", sayTheTotal)

	-- The calls a player's click ends up in, whichever button or addon made it. Hooked rather
	-- than replaced, and each guarded on its own: `OpenAllMail` is not on every client, and a
	-- client without one of these loses that route rather than the file.
	if type(_G.hooksecurefunc) ~= "function" then
		Family:Debug("no way to watch the mailbox on this client")
		return
	end

	for _, name in ipairs { "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem" } do
		if type(_G[name]) == "function" then
			Family:TryCall(_G.hooksecurefunc, name, function() asked = true end)
		end
	end
end)
