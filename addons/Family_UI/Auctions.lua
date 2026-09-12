-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- A button on the auction window that reads the whole house.
--
-- **It presses the window's own buttons.** That is the whole design, and it is what keeps the
-- rule the walk was rebuilt around: Family does not compose an auction query. Two of ours, one
-- of which said `getAll = true` by accident, are what it took to learn that (L-071). So the
-- button presses **Search**, and then **Next**, and the client composes both queries exactly as
-- it does when the player presses them; Family hears them through the hook it already has and
-- the walk replays one of them with the page changed.
--
-- It is the same shape as the profession button, which asks the client to open its own window
-- rather than reaching inside it.
--
-- **And it only exists where that window does.** `AuctionFrameBrowse` is part of an addon the
-- client loads when the player first opens an auction house, and on a build with the newer
-- house it is never there at all - so nothing is built, nothing is hidden, and no version
-- number is consulted (§2.3).
--
-- Measured on all three clients 2026-09-11. Classic Era and Burning Crusade answer identically:
-- all six controls present as tables and `AuctionFrameBrowse_Search` as a function. On Mists
-- every one of them is **nil**, while `QueryAuctionItems` and `CanSendAuctionQuery` are still
-- `function` there - shells that answer nought. So the call being there says nothing about the
-- window being there, and it is the window this hangs off.

local _, UI = ...

local Family = _G.Family
local L = Family.L

-- **The controls, by the names the client gave them.** Read at click time rather than held,
-- because the window is built after this file is and rebuilt by nothing in particular.
local SEARCH = "BrowseSearchButton"
local NEXT_PAGE = "BrowseNextPageButton"

-- **What to sit beside.** Reported from play on Burning Crusade 2026-09-11: no button appeared
-- on the browse panel at all. `AuctionFrameBrowse` is the panel's container and nothing here
-- measured it before anchoring to a corner of it - a frame whose size has never been read is a
-- frame whose corners are not where they look, and a button placed at one of them can be under
-- the portrait, behind the money, or off the window entirely.
--
-- So it hangs off a **control**, which has a size because the client gave it one and which the
-- player can see for themselves. Reset is the one with room beside it, and it is present as a
-- table on both clients that have this window (measured on all three, 2026-09-11).
-- **And the newer house's window, whose name has never been read here.**
--
-- Measured on Mists 2026-09-12: every one of the old window's controls is nil there, and the
-- probe has never asked what replaced them. So this is a list rather than a name, the first
-- entry that turns out to be a real frame wins, and `/family ah` prints what it found - a
-- candidate that is not there answers nil exactly like a misspelling, which is why the client is
-- asked rather than trusted.
--
-- Anchored **outside** the window's top-right corner. Inside it, the button would sit at a
-- coordinate of a layout nobody here has seen, which is the fault L-073 records; outside, there
-- is nothing to be covered by.
local MODERN = { "AuctionHouseFrame" }

local function modernWindow()
	for _, name in ipairs(MODERN) do
		local frame = _G[name]
		if type(frame) == "table" and type(frame.CreateFontString) == "function" then
			return frame, name
		end
	end
end

UI.__modernAuctionWindow = modernWindow

local BESIDE = "BrowseResetButton"

-- **And the control that makes it the whole house rather than the last search.**
--
-- Reported from play on Burning Crusade 2026-09-11: the button read sixty-eight pages and said
-- it had read the whole house, on a house this repository had already measured at 3,605 pages.
-- It had - faithfully - walked every page of what the player last searched for, which was a
-- category of recipes. A walk replays the client's query with the page changed, so whatever
-- narrowed that query narrows the walk.
--
-- The window has a control for exactly this, and it is the client's own: Reset empties the
-- search form. Pressed first, the Search that follows is a search for everything, and that is
-- the only way this button can honestly be called *read it all*.
local RESET = "BrowseResetButton"

local button

-- What the button is waiting for, or nothing. **One click starts one sequence**: a probe that
-- can be started twice is a probe that will be, and the auction house is the one place in this
-- addon where a doubled action costs somebody a disconnection (L-070).
local waitingFor

-- How long a press of the window's own button is given to be answered before the sequence is
-- abandoned. The walk has its own, longer patience once it is running; this is only about the
-- two presses that get it started.
local ANSWER_SECONDS = 10

local function ready()
	return Family.Auctions:LastQuery() ~= nil and Family.Auctions:PagePosition() ~= nil
end

local function refresh()
	if not button then return end

	if Family.Auctions:Walking() or Family.Auctions:ReplicateReading() then
		button:SetText(L["Stop"])
	elseif waitingFor then
		button:SetText(L["Searching..."])
	else
		button:SetText(L["Read it all"])
	end
end

-- **Said again whenever a read starts or ends**, whoever started it. A read that ends between
-- one list update and the next leaves nothing to redraw on: reported from play 2026-09-12, the
-- button still read *Stop* after the walk had finished, and pressing it started a new read
-- instead of stopping anything.
function UI:HouseReadChanged()
	refresh()
end

-- **Pressing a control of the window's, if it is there and willing.** A button that is disabled
-- is a button the client is saying no with - the last page has no next one - and clicking it
-- anyway achieves nothing and looks like it achieved something.
local function press(name)
	local control = _G[name]
	if type(control) ~= "table" or type(control.Click) ~= "function" then return false end

	if type(control.IsEnabled) == "function" then
		local willing = (Family:TryCall(control.IsEnabled, control))
		if willing == false or willing == 0 then return false end
	end

	Family:TryCall(control.Click, control)
	return true
end

local function giveUp()
	waitingFor = nil
	Family.Auctions:TellNextList(nil)
	refresh()
end

local heard

-- **The window answered, so what is known now?** After Search, Family has a query of the
-- client's own and can replay it - but which of its arguments is the page is a second question,
-- and only two queries differing in one place answer it. So Next is pressed once, and that is
-- the whole of what this sequence does before handing over to the walk.
heard = function()
	if not waitingFor then return end

	if ready() then
		waitingFor = nil
		refresh()
		UI:StartHouseRead()
		return
	end

	if waitingFor ~= "search" then
		-- Next has been pressed and the two queries still do not differ in one clear place.
		-- The walk will refuse and say which button to press, which is the same sentence
		-- whoever asked for the read.
		waitingFor = nil
		refresh()
		UI:StartHouseRead()
		return
	end

	waitingFor = "page"
	Family.Auctions:TellNextList(heard)
	Family:After(ANSWER_SECONDS, "ui.auctions.button", giveUp)

	if not press(NEXT_PAGE) then giveUp() end
	refresh()
end

local function clicked()
	if Family.Auctions:Walking() or Family.Auctions:ReplicateReading() then
		UI:StopHouseRead()
		refresh()
		return
	end

	if waitingFor then return end

	-- **The newer house has nothing to search first.** It answers its whole list to one call,
	-- so there is no form to empty and no page to turn - the read starts on the press.
	if Family.Auctions:CanReplicate() then
		UI:StartHouseRead()
		refresh()
		return
	end

	-- **Always Reset, then Search - never the shortcut.** Knowing which argument is the page is
	-- not the same as the last query being a search for everything, and this used to start the
	-- walk straight away whenever it was. That is how a walk of one category came to be called
	-- the whole house.
	--
	-- **Its answer is not the claim, though, and used to be.** A control the client disables is
	-- a control it is refusing to be clicked, and the client disables Reset for its own reasons
	-- - reported from play 2026-09-12, twice running, a read that announced *the search form
	-- could not be emptied* and then walked three and a half thousand pages, which is a house.
	-- What is read is now decided by the query the client actually sends, which Family hears in
	-- full: see `Auctions:QueryAsksForEverything`. Reset is still pressed, because pressing it
	-- is what empties the form; it just no longer gets to say what happened.
	press(RESET)

	waitingFor = "search"
	Family.Auctions:TellNextList(heard)
	Family:After(ANSWER_SECONDS, "ui.auctions.button", giveUp)

	if not press(SEARCH) then giveUp() end
	refresh()
end

local function build()
	if button then return end

	-- The newer house first, because on a build that has it the old window is not there at all
	-- and nothing below would find anything to hang off.
	local modern = modernWindow()
	local parent = modern or _G.AuctionFrameBrowse
	if type(parent) ~= "table" then return end

	-- Through `TryCall`, because a template this client turns out not to have would otherwise
	-- take the auction window down with it - and a window that will not open is a worse fault
	-- than a button that is not there.
	button = (Family:TryCall(CreateFrame, "Button", "FamilyReadHouseButton",
		parent, "UIPanelButtonTemplate"))
	if type(button) ~= "table" then
		button = nil
		return
	end

	button:SetSize(120, 22)

	-- Beside Reset on the old window, which is a control with a size of its own rather than a
	-- corner of a container nothing has measured (L-073). On the newer one there is no such
	-- control read yet, so the button hangs just outside the window's top-right corner, where
	-- no layout can put anything over it.
	local beside = not modern and _G[BESIDE] or nil
	if type(beside) == "table" then
		button:SetPoint("LEFT", beside, "RIGHT", 8, 0)
	elseif modern then
		button:SetPoint("TOPLEFT", modern, "TOPRIGHT", 6, -30)
	else
		button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -80)
	end

	-- Above whatever the panel draws in that corner. A button that is there and covered reads
	-- exactly like a button that was never built.
	local level = tonumber((Family:TryCall(button.GetFrameLevel, button)))
	if level then Family:TryCall(button.SetFrameLevel, button, level + 4) end

	button:SetScript("OnClick", clicked)

	UI:AttachTooltip(button, function()
		return nil, nil, {
			{ L["Read it all"] },
			{ L["this clears the search, then reads every page there is - it takes a long time"] },
		}
	end)

	refresh()
end

Family:OnDatabaseReady("ui.auctions", function()
	-- The window is built when the client loads the addon that owns it, which is the first time
	-- the player opens an auction house - so this is the earliest moment it can be there.
	Family:RegisterEvent("AUCTION_HOUSE_SHOW", "ui.auctions", function()
		build()
		refresh()
	end)

	-- **And the label keeps up with the walk.** Its own key, because a second registration
	-- under the scanner's would replace the scanner's (L-068).
	Family:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "ui.auctions.button", refresh)

	Family:RegisterEvent("AUCTION_HOUSE_CLOSED", "ui.auctions", function()
		giveUp()
	end)
end)
