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
-- **What it turned into.** Read from play on Burning Crusade 2026-09-12, with `/family
-- itemclick` armed and an item clicked in the bags:
--
--     control    true
--     shift      false
--     alt        true
--     1          [Wicked Claw]
--
-- So the crossroads does fire from a bag slot, both modifiers reach it, and the first argument
-- is the link. That is the three things presence could not say, and the feature is built on
-- them rather than on the shape of the call.
--
-- **Why a probe first.** `HandleModifiedItemClick` is the client's own
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

-- **Which modified clicks this client has already spoken for.**
--
-- Reported from play on Mists 2026-09-12, with the game's own window saying it: CTRL and a click
-- opens the Dressing Room, and holding ALT as well does not stop it. So CTRL and ALT is taken -
-- by the client, not by an addon - and Family's gesture has to move.
--
-- Which combination is free is not a thing to pick and hope. The client keeps the list itself:
-- every named modified-click action and the keys bound to it, the same list the game's own key
-- bindings screen draws. Read out rather than guessed at, so the answer comes from the build in
-- front of the player and holds on all three.
function UI:ModifiedClickActions()
	local out = {}

	local count = tonumber((Family:TryCall(_G.GetNumModifiedClickActions)))
	if not count then return out end

	for index = 1, count do
		local name = (Family:TryCall(_G.GetModifiedClickAction, index))
		if type(name) == "string" then
			out[#out + 1] = { name, tostring((Family:TryCall(_G.GetModifiedClick, name))) }
		end
	end

	return out
end

-- **The frame the pointer is on, whichever way this client will say it.**
--
-- Measured on Classic Era 2026-09-12: `GetMouseFocus` is **nil** there and `GetMouseFoci` is a
-- function answering a list. Asking only the first is how the click probe's own `clicked` line
-- came back blank on two clients and was written down as a reading rather than as a missing call
-- (L-080).
--
-- In one place because two probes asking it separately is two probes drifting, and the second of
-- them drifted within the hour.
function UI:FrameUnderPointer()
	local frame = (Family:TryCall(_G.GetMouseFocus))
	if type(frame) == "table" then return frame end

	local list = (Family:TryCall(_G.GetMouseFoci))
	if type(list) == "table" then return list[1] end
end

function UI:PointerRoutes()
	return type(_G.GetMouseFocus), type(_G.GetMouseFoci)
end

local function packOf(...)
	return { n = select("#", ...), ... }
end

-- Whether a modified click can reach Family at all on this client, which is what decides
-- whether a tooltip may offer the shortcut. The hook is installed or it is not; nothing here
-- guesses from a build number.
local armed = false

function UI:ItemClickArmed()
	return armed
end

-- **The combination, and why these two.** Alberto's suggestion, and it read as free on Burning
-- Crusade: held together, nothing else happened. Shift has to be **up** - it is the game's own
-- key for putting a link in the chat box, and a shortcut that fires while somebody is doing that
-- is a shortcut they turn off.
local function wanted()
	return (Family:TryCall(IsControlKeyDown)) and true or false,
		(Family:TryCall(IsAltKeyDown)) and true or false,
		(Family:TryCall(IsShiftKeyDown)) and true or false
end

local function heard(link, ...)
	seen = seen + 1

	local control, alt, shift = wanted()

	-- **The whole family's copies of this item, in one gesture.** The tooltip already says who
	-- has one and stops at ten of them, because a family can be bigger than a tooltip - this is
	-- where the rest of that list lives, and getting to it used to mean opening the window,
	-- finding the panel, pressing Whole family and typing the name back in.
	--
	-- The name is taken out of the link rather than looked up: it is already the client's own
	-- word for the item, in the language the search box matches on.
	if control and alt and not shift and type(link) == "string" then
		local name = link:match("%[(.-)%]")
		if name and name ~= "" and UI.SearchPossessions then
			UI:SearchPossessions(name)
		end
	end

	if not tellNextClick then return end

	local told = tellNextClick
	tellNextClick = nil

	-- **The modifiers as they are now**, which is the moment the click happened - this runs
	-- inside the call, before anything has had a chance to let go of a key.
	local held = {
		{ "control", tostring(control) },
		{ "shift", tostring(shift) },
		{ "alt", tostring(alt) },
	}

	-- **And who else is claiming this click.**
	--
	-- Asked 2026-09-12: on Mists, CTRL and ALT and a click turn the cursor into a magnifying
	-- glass, and the question is whether Family is taking something away from whoever does
	-- that. It is not - `hooksecurefunc` runs after the real call and passes its answer back
	-- untouched, so both things happen and neither is lost. But *which* thing is worth knowing,
	-- and none of it has to be guessed at.
	--
	-- `GetCursorInfo` says what the cursor is now holding, which is the magnifying glass's own
	-- description of itself. `GetMouseFocus` names the frame that was clicked, and a frame's
	-- name says whose it is - `ContainerFrame1Item5` is the client's own bag, anything else is
	-- somebody's addon. `issecurevariable` answers whether this global has been touched by an
	-- addon **and names it**, which is the question asked, answered by the client rather than
	-- by a list of suspects.
	local kind, one, two = Family:TryCall(GetCursorInfo)
	held[#held + 1] = { "cursor", table.concat({ tostring(kind), tostring(one),
		tostring(two) }, " / ") }

	local focus = UI:FrameUnderPointer()
	local named = type(focus) == "table" and (Family:TryCall(focus.GetName, focus)) or nil
	held[#held + 1] = { "clicked", tostring(named) }

	local secure, owner = Family:TryCall(issecurevariable, "HandleModifiedItemClick")
	held[#held + 1] = { "hooked by", tostring(secure) .. " / " .. tostring(owner) }

	-- And everything the client handed over, by position. Which argument is the link is not
	-- something to write down from memory on three clients at once.
	local got = packOf(link, ...)
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
	armed = true
end)
