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

local function wanted()
	return Family.Extras and Family.Extras:On("mailReport")
end

local function inboxMoney()
	local money = 0
	local count = tonumber((Family:TryCall(GetInboxNumItems))) or 0
	for index = 1, count do
		-- The fifth return. `packageIcon, stationeryIcon, sender, subject, money, ...`
		local _, _, _, _, letterMoney = Family:TryCall(GetInboxHeaderInfo, index)
		money = money + (tonumber(letterMoney) or 0)
	end
	return money
end

-- **What has come in since the last look**, one line a sum, as it arrives.
local function sayWhatCameIn()
	local money = inboxMoney()

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
end

-- **The way out**: what the visit brought in, and what this character now owns. `GetMoney`
-- answers for whoever is logged in and for nobody else; the family's total is the summary's job.
--
-- **The one place a request is let go of.** Opening the mailbox used to clear it as well, and with
-- two places doing it neither was load-bearing - the recorded mutation removing either survived.
local function sayTheTotal()
	if wanted() and visitMoney > 0 then
		Family:Print(L["|cff66bbffTotal collected:|r %s"], UI:Coins(visitMoney))
		Family:Print(L["|cff66bbffNow you own:|r %s"],
			UI:Coins(tonumber((Family:TryCall(GetMoney))) or 0))
	end

	heldMoney, waiting, visitMoney = nil, 0, 0
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("ui.mailreport", function()
	-- **Its own key.** A second registration under the mail scanner's would replace the
	-- scanner's, which is L-068 and has already cost this addon a feature once.
	Family:RegisterEvent("MAIL_SHOW", "ui.mailreport", function()
		heldMoney = inboxMoney()
		visitMoney = 0
	end)

	Family:RegisterEvent("MAIL_INBOX_UPDATE", "ui.mailreport", function()
		if not wanted() then
			heldMoney, waiting = nil, 0
			return
		end
		sayWhatCameIn()
	end)

	Family:RegisterEvent("MAIL_CLOSED", "ui.mailreport", sayTheTotal)

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
