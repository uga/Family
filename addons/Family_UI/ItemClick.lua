-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Watching a modified click on an item, so that one day Family can answer one.
--
-- Alberto's idea 2026-09-12, for a possessions list too long to draw whole: *hold CTRL-ALT and
-- click the item to open Family here*. It is a better answer than a grey note, and it needs
-- something Family has never done - noticing a click on an item it did not draw.
--
-- **Why a click rather than a modifier held over the tooltip.** Family cannot repaint somebody
-- else's tooltip; the note at the foot of `Tooltip.lua` measured that as unreliable, and the CTRL
-- worth block works only because the bag addon re-shows its own tooltip when a modifier changes.
-- A player on the stock interface would get nothing. A click does not depend on any of that.
--
-- **And why this is a probe and not the feature.** `HandleModifiedItemClick` is the client's own
-- crossroads for a modified click, and it is present on Mists (measured 2026-09-12, with
-- `IsModifiedClick`, `ChatEdit_InsertLink` and `SetItemRef` beside it). Present is not the
-- question. Whether it fires from a **bag slot**, what it is handed, and which modifiers reach it
-- are three more, and this repository has spent two days paying for things built on a call that
-- existed and answered something else. So this watches the client do it and prints what arrived.
--
-- Nothing here sends anything, changes anything, or consumes the click: `hooksecurefunc` runs
-- after the real work and cannot alter it.

local _, UI = ...

local Family = _G.Family

-- Told once, like every other probe in this addon. A watcher that reports every click is a
-- watcher somebody turns the addon off over.
local tellNextClick

function UI:TellNextItemClick(fn)
	tellNextClick = type(fn) == "function" and fn or nil
end

-- How many have gone past since login, whether or not anybody was listening. It is the difference
-- between *the hook is not called from a bag* and *the hook is not installed*, and those two
-- arrive as the same silence.
local seen = 0

function UI:ItemClicksSeen()
	return seen
end

local function packOf(...)
	return { n = select("#", ...), ... }
end

local function heard(...)
	seen = seen + 1

	if not tellNextClick then return end

	local told = tellNextClick
	tellNextClick = nil

	-- **The modifiers as they are now**, which is the moment the click happened - this runs
	-- inside the call, before anything has had a chance to let go of a key.
	local held = {
		{ "control", tostring((Family:TryCall(IsControlKeyDown)) and true or false) },
		{ "shift", tostring((Family:TryCall(IsShiftKeyDown)) and true or false) },
		{ "alt", tostring((Family:TryCall(IsAltKeyDown)) and true or false) },
	}

	-- And everything the client handed over, by position. Which argument is the link is not
	-- something to write down from memory on three clients at once.
	local got = packOf(...)
	for index = 1, got.n do
		held[#held + 1] = { tostring(index), tostring(got[index]) }
	end

	Family:TryCall(told, held)
end

UI.__itemClickHeard = heard

Family:OnDatabaseReady("ui.itemclick", function()
	-- Guarded, because a client without it must lose nothing else: an unprotected hook on a
	-- name that is not there takes this whole file down with it, and this file is a probe.
	if type(_G.hooksecurefunc) ~= "function" then return end
	if type(_G.HandleModifiedItemClick) ~= "function" then return end

	Family:TryCall(_G.hooksecurefunc, "HandleModifiedItemClick", heard)
end)
