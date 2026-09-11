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

	if Family.Auctions:Walking() then
		button:SetText(L["Stop"])
	elseif waitingFor then
		button:SetText(L["Searching..."])
	else
		button:SetText(L["Read it all"])
	end
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
	if Family.Auctions:Walking() then
		UI:StopHouseRead()
		refresh()
		return
	end

	if waitingFor then return end

	-- Everything the walk needs is already known, which is the ordinary case for somebody who
	-- has used the auction house at all this session.
	if ready() then return UI:StartHouseRead(), refresh() end

	waitingFor = "search"
	Family.Auctions:TellNextList(heard)
	Family:After(ANSWER_SECONDS, "ui.auctions.button", giveUp)

	if not press(SEARCH) then giveUp() end
	refresh()
end

local function build()
	if button or type(_G.AuctionFrameBrowse) ~= "table" then return end

	button = CreateFrame("Button", "FamilyReadHouseButton", _G.AuctionFrameBrowse,
		"UIPanelButtonTemplate")
	button:SetSize(120, 22)

	-- Under the browse list rather than over it: this window is full, and a button that covers
	-- a row of somebody's search results is a button they resent.
	button:SetPoint("BOTTOMLEFT", _G.AuctionFrameBrowse, "BOTTOMLEFT", 20, 14)
	button:SetScript("OnClick", clicked)

	UI:AttachTooltip(button, function()
		return nil, nil, {
			{ L["Read it all"] },
			{ L["this reads every page of the auction house and takes a long time: /family ah scan go"] },
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
