-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The money that came out of the mailbox, said out loud.
--
-- Asked for 2026-09-12, and reshaped twice the same day from play. The first version named every
-- attachment; the second grouped them by letter. Both were read beside the client's own lines,
-- and Alberto's verdict on the second, with Postal switched off: *dobbiamo evitare di duplicare i
-- messaggi del client standard - visto che il client standard in realta STAMPA gli allegati
-- ricevuti (e li stampa pure giusti) potremmo concentrarci solo sui soldi: stampiamo solo quelli,
-- mentre arrivano, e il totale in fondo.*
--
-- **So this says the one thing the game does not.** Take an item from a letter and the client
-- prints *You receive item*, with the count, correctly. Take the gold out of forty auction
-- returns and it prints nothing at all - which is the whole of why this exists.
--
-- **Two halves, and neither is enough on its own.**
--
-- *What was asked for* is read off the letter at the moment of the click. `hooksecurefunc` runs
-- after the real call and before the server has answered, so the letter and its money are still
-- standing - the last moment at which the index names the letter that was clicked.
--
-- *What actually arrived* is the inbox's money compared against the last look. Reporting the
-- hook's arguments alone would announce money from a take the server never answered; a
-- comparison alone would report the money in a letter that was returned to its sender, or that
-- expired while the box was open, as money collected.
--
-- **And what was asked for is kept until it arrives**, not until the next update. Read from play
-- 2026-09-12 with the client's own *Open All*: two letters with money and not one line. The server
-- answers a take across more than one `MAIL_INBOX_UPDATE`, the first of which is often nothing
-- more than the letter being marked read - and dropping the request on that update left nothing to
-- match the money against when it really went (L-091).
--
-- Off until somebody switches it on (Family/Extras.lua).

local _, UI = ...

local Family = _G.Family
local L = Family.L

-- The money sitting in the inbox when it was last looked at.
local heldMoney

-- Money asked for and not yet seen to leave. Drained as it arrives, and let go of when the mailbox
-- closes - never on an update, because the server answers one take across several.
local waiting = 0

-- What this visit has come to, which is what gets said on the way out.
local visitMoney = 0

-- How long an emptied mailbox waits before saying its total. Not measured - the client's loot line
-- has no event of its own to wait for that would not also fire for loot from anything else - so
-- picked: the chat log does not say by how much the line trailed, only that it did, so this is a
-- guess to be read back from play, short enough that the total still answers the last click.
local TOTAL_SETTLE = 1

local function wanted()
	return Family.Extras and Family.Extras:On("mailReport")
end

-- The money still in the inbox, and whether there is anything left in it to take at all.
--
-- **Left to take**, not *letters left*: a letter that carried only words stays in the mailbox
-- after it has been read, so a box nobody can take another thing out of is rarely a box with no
-- letters in it. Nothing carrying money and nothing carrying an attachment is the empty that
-- somebody emptying their post means. And not while the server is holding more than the client
-- has been shown - the second value of `GetInboxNumItems` - because those are still to come.
local function inboxNow()
	local money, anything = 0, false
	local shown, held = Family:TryCall(GetInboxNumItems)
	shown = tonumber(shown) or 0

	for index = 1, shown do
		-- `packageIcon, stationeryIcon, sender, subject, money, cod, daysLeft, itemCount, ...`
		local _, _, _, _, letterMoney, _, _, itemCount = Family:TryCall(GetInboxHeaderInfo, index)
		letterMoney = tonumber(letterMoney) or 0
		money = money + letterMoney
		if letterMoney > 0 or (tonumber(itemCount) or 0) > 0 then anything = true end
	end

	if (tonumber(held) or shown) > shown then anything = true end

	return money, anything
end

local sayTheTotal

-- **What has come in since the last look**, one line a sum, as it arrives.
local function sayWhatCameIn()
	local money, anything = inboxNow()

	if heldMoney and waiting > 0 then
		-- Capped at what the clicked letters were holding: the letter says what it has and the
		-- inbox says what went, and money leaving for any other reason is not money collected.
		local coin = math.min(waiting, heldMoney - money)
		if coin > 0 then
			waiting = waiting - coin
			visitMoney = visitMoney + coin
			Family:Print(L["You collected: %s"], UI:Coins(coin))
		end
	end

	heldMoney = money

	-- **And the total the moment there is nothing left to take**, rather than waiting for the
	-- mailbox to close. Alberto, 2026-09-12: *il totale va stampato quando svuoto la casella o
	-- quando chiudo la mailbox - per esempio perche ho riempito le borse e devo andare in banca -
	-- whichever happens first.* Only once: saying it resets the visit, so closing the box
	-- straight after has nothing new to add and says nothing.
	--
	-- **A moment after, not on the update itself.** Read from play the same evening: the total
	-- came out, and *then* the client's *You receive item* for the last letter. The letter has
	-- left the inbox by the update that says so; the client's line for what was in it comes a
	-- little later. Waiting lets that line land above the total rather than below it, and a
	-- sum still arriving in the meantime starts the wait again - `Family:After` restarts a
	-- pending call under the same key. Closing the box before it fires says the total then,
	-- which empties the visit, so the wait finds nothing left to say.
	if not anything and waiting <= 0 and visitMoney > 0 then
		Family:After(TOTAL_SETTLE, "ui.mailreport.total", function() sayTheTotal(true) end)
	end
end

-- **The way out**: what the visit brought in, and what this character now owns. `GetMoney`
-- answers for whoever is logged in and for nobody else; the family's total is the summary's job.
--
-- **The one place a request is let go of.** Opening the mailbox used to clear it as well, and with
-- two places doing it neither was load-bearing - the recorded mutation removing either survived.
function sayTheTotal(stillOpen)
	if wanted() and visitMoney > 0 then
		Family:Print(L["|cff66bbffTotal collected:|r %s"], UI:Coins(visitMoney))
		Family:Print(L["|cff66bbffNow you own:|r %s"],
			UI:Coins(tonumber((Family:TryCall(GetMoney))) or 0))
	end

	-- Emptied with the box still open: the visit's sum has been said and starts again from
	-- nothing, but what the inbox holds is still being watched - a letter can arrive while it
	-- is open. Closed: all of it goes.
	visitMoney = 0
	if not stillOpen then heldMoney, waiting = nil, 0 end
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("ui.mailreport", function()
	-- **Its own key.** A second registration under the mail scanner's would replace the
	-- scanner's, which is L-068 and has already cost this addon a feature once.
	Family:RegisterEvent("MAIL_SHOW", "ui.mailreport", function()
		heldMoney = (inboxNow())
		visitMoney = 0
	end)

	Family:RegisterEvent("MAIL_INBOX_UPDATE", "ui.mailreport", function()
		if not wanted() then
			heldMoney, waiting = nil, 0
			return
		end
		sayWhatCameIn()
	end)

	-- Wrapped, because an event handler is handed the event's own arguments - and passed
	-- straight in, those arrive as `stillOpen`, and a mailbox that has closed would keep what it
	-- was waiting for into the next visit.
	Family:RegisterEvent("MAIL_CLOSED", "ui.mailreport", function() sayTheTotal(false) end)

	if type(_G.hooksecurefunc) ~= "function" then
		Family:Debug("no way to watch the mailbox on this client")
		return
	end

	-- **Read now, not later.** One `MAIL_INBOX_UPDATE` from now the letter may be gone and every
	-- letter below it renumbered.
	local function noteMoney(index)
		local _, _, _, _, letterMoney = Family:TryCall(GetInboxHeaderInfo, index)
		letterMoney = tonumber(letterMoney) or 0
		if letterMoney > 0 then waiting = waiting + letterMoney end
	end

	-- The two calls money leaves a letter through, whichever button or addon made them - Postal
	-- and the client's own *Open All* both arrive here. Hooked rather than replaced, and each
	-- guarded on its own, because `AutoLootMailItem` is not on every client.
	for _, name in ipairs { "TakeInboxMoney", "AutoLootMailItem" } do
		if type(_G[name]) == "function" then
			Family:TryCall(_G.hooksecurefunc, name, function(index)
				Family:TryCall(noteMoney, index)
			end)
		end
	end
end)
