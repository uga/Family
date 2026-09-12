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
-- chiusura della casella, stampiamo il totale.*
--
-- **And restated the same day, with the shape spelled out**, once the first version had been
-- read in play beside Postal's own lines: *per ogni messaggio con oggetti e soldi dobbiamo
-- stampare "You receive: [itemlink]" tanti quanti sono gli allegati di quel messaggio, poi "You
-- collected:" i soldi che c'erano in quel messaggio; alla fine, quando chiudiamo la mailbox,
-- "Total collected:" e "Now you own:".*
--
-- The game says nothing about what a mailbox full of auction returns actually came to, which is
-- the whole of why this exists.
--
-- **Two halves, and neither is enough on its own.**
--
-- *What was asked for* is read off the letter at the moment of the click. `hooksecurefunc` runs
-- after the real call and before the server has answered, so the letter, its attachments and its
-- money are all still standing and can be read - which is the only way to know that these three
-- attachments belong to that one letter. An index is not a thing that survives a take: the letter
-- above vanishing renumbers every one below it, which is why the comparison below is by item and
-- not by slot.
--
-- *What actually arrived* is the inbox compared against the last look. Reporting the hook's
-- arguments would announce a stack that never came, because a take the server refuses - and bags
-- are full exactly when a mailbox of auction returns is being emptied - looks identical from
-- inside the hook. And a comparison with no hook behind it would report a letter that expired
-- while the box was open, or one the player *returned to sender*, as things they received.
--
-- So the hook writes the sentence and the comparison decides how much of it is true.
--
-- **A link and not a name**, because a link is a thing the reader can click and hover and a name
-- is a string. Where the client will not give one up, the name is the fallback and the id is the
-- fallback after that: a line naming the item badly beats no line at all.
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

-- **What has been asked for and not yet answered**, read off the letters while they still stand.
-- `attachments` is a list in the order they sit in the letter, each `{ id =, count =, link =,
-- name = }`; `money` is what those letters were holding. Cleared by the comparison that answers
-- them, so a second click's letter never inherits the first's.
local pending = nil

-- What this visit has come to, which is what gets said on the way out.
local visitItems, visitMoney = 0, 0

local function arming()
	pending = pending or { attachments = {}, money = 0 }
	return pending
end

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

-- How to name a thing on its own line. The link first because it can be clicked, hovered and
-- shift-clicked into chat; the name where the client would not give a link up; and the id last,
-- which is ugly and is still an answer.
local function naming(row)
	if type(row.link) == "string" and row.link ~= "" then return row.link end
	return row.name or (row.id and Family.Names:CachedItem(row.id))
		or string.format(L["item %d"], row.id or 0)
end

-- **What is gone since the last look**, said one line at a time - in the order the attachments
-- sit in the letter, which is the order the reader watched them go.
local function sayWhatLeft()
	local now, money = inboxNow()

	if held and pending then
		-- How much of each item actually left, which is the ceiling on what may be claimed.
		-- A take the server refused leaves this at nought and the attachment says nothing.
		local gone = {}
		for itemID, was in pairs(held) do
			local still = (now[itemID] or {}).count or 0
			if was.count > still then gone[itemID] = was.count - still end
		end

		for _, row in ipairs(pending.attachments) do
			local left = row.id and gone[row.id] or 0
			local arrived = math.min(row.count or 0, left)

			if arrived > 0 then
				gone[row.id] = left - arrived
				visitItems = visitItems + arrived

				-- The count only where there is one to say. A single item followed by
				-- **x1** is a line that reads as though it were about a stack.
				if arrived > 1 then
					Family:Print(L["You receive: %s x%d"], naming(row), arrived)
				else
					Family:Print(L["You receive: %s"], naming(row))
				end
			end
		end

		-- Capped at what the letters were holding for the same reason the attachments are:
		-- the letter says what it has and the inbox says what went.
		local coin = math.min(pending.money, (heldMoney or 0) - money)
		if coin > 0 then
			visitMoney = visitMoney + coin
			Family:Print(L["You collected: %s"], UI:Coins(coin))
		end
	end

	held, heldMoney = now, money
	pending = nil
end

-- **The way out**, which is the figure somebody actually wanted: a mailbox of auction returns is
-- forty lines and one number.
--
-- Two lines and not one, as asked: what this visit brought in, and what the character is worth
-- afterwards. The second is this character's own purse and nothing else - `GetMoney` answers for
-- whoever is logged in, and the family's total is a question the summary already answers.
local function sayTheTotal()
	if wanted() and (visitItems > 0 or visitMoney > 0) then
		Family:Print(L["|cff66bbffTotal collected:|r %s"], UI:Coins(visitMoney))
		Family:Print(L["|cff66bbffNow you own:|r %s"],
			UI:Coins(tonumber((Family:TryCall(GetMoney))) or 0))
	end

	held, heldMoney, pending = nil, nil, nil
	visitItems, visitMoney = 0, 0
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("ui.mailreport", function()
	-- **Its own key.** A second registration under the mail scanner's would replace the
	-- scanner's, which is L-068 and has already cost this addon a feature once.
	Family:RegisterEvent("MAIL_SHOW", "ui.mailreport", function()
		held, heldMoney = inboxNow()
		pending = nil
		visitItems, visitMoney = 0, 0
	end)

	Family:RegisterEvent("MAIL_INBOX_UPDATE", "ui.mailreport", function()
		if not wanted() then
			held, heldMoney, pending = nil, nil, nil
			return
		end
		sayWhatLeft()
	end)

	Family:RegisterEvent("MAIL_CLOSED", "ui.mailreport", sayTheTotal)

	if type(_G.hooksecurefunc) ~= "function" then
		Family:Debug("no way to watch the mailbox on this client")
		return
	end

	-- **One attachment**, named from the letter it is still sitting in.
	local function noteAttachment(index, attachment)
		local name, itemID, _, quantity = Family:TryCall(GetInboxItem, index, attachment)
		local link = Family:TryCall(GetInboxItemLink, index, attachment)
		itemID = tonumber(itemID)

		-- An older client answers no id here and a link everywhere else, which is the same
		-- fallback `inboxNow` uses - and the comparison is by id, so without this the
		-- attachment could never be matched to what left.
		if not itemID and type(link) == "string" then
			itemID = tonumber(link:match("item:(%d+)"))
		end
		if not itemID then return end

		local slot = arming().attachments
		slot[#slot + 1] = { id = itemID, count = tonumber(quantity) or 1,
			link = type(link) == "string" and link or nil, name = name }
	end

	local function noteMoney(index)
		local _, _, _, _, letterMoney = Family:TryCall(GetInboxHeaderInfo, index)
		letterMoney = tonumber(letterMoney) or 0
		if letterMoney > 0 then arming().money = arming().money + letterMoney end
	end

	-- The calls a player's click ends up in, whichever button or addon made it - Postal and the
	-- client's own buttons both arrive here. Hooked rather than replaced, and each guarded on
	-- its own: `AutoLootMailItem` is not on every client, and a client without one of these
	-- loses that route rather than the file.
	--
	-- **Read now, not later.** The hook runs after the call and before the server answers, so
	-- this is the last moment at which `index` still names the letter the player clicked. One
	-- `MAIL_INBOX_UPDATE` later the letter may be gone and everything below it renumbered.
	local watch = {
		TakeInboxItem = function(index, attachment) noteAttachment(index, attachment) end,
		TakeInboxMoney = function(index) noteMoney(index) end,

		-- Everything in the letter at once, which is the button people actually use. The
		-- whole letter is walked here rather than left to the comparison, because *these
		-- attachments belong to that letter* is exactly what the comparison cannot see.
		AutoLootMailItem = function(index)
			local slots = tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or 16
			for attachment = 1, slots do noteAttachment(index, attachment) end
			noteMoney(index)
		end,
	}

	-- **One guard, and it is the event's.** These hooks were written checking the switch as
	-- well, which read as belt and braces and was worse than either: with two guards neither is
	-- load-bearing, so removing either one alone changed nothing a check could see, and the
	-- mutation that turns the switch off survived. The comparison is the only thing that says
	-- anything out loud, so the comparison is where the switch belongs - and it clears what was
	-- recorded on the way past, which a guard out here could not do.
	for name, note in pairs(watch) do
		if type(_G[name]) == "function" then
			Family:TryCall(_G.hooksecurefunc, name, function(...)
				Family:TryCall(note, ...)
			end)
		end
	end
end)
