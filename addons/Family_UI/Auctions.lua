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

-- **A tab of Family's own on the auction window, and the panel behind it.**
--
-- Asked for 2026-09-12, off Classic Era: *perche non facciamo un panel Family per la finestra
-- della AH (come fa Auctionator) nel quale mettiamo il pulsante e il nostro progress?* The
-- button had nowhere to say how far along it was except the chat frame, which is the one place
-- a player is not looking while an auction house scrolls past.
--
-- **Built off the client's own furniture and nothing else.** The tab comes from
-- `AuctionFrameTabTemplate`, which is the template the window's own three are made from; how
-- many there already are is read out of `AuctionFrame.numTabs` rather than assumed to be three;
-- and the panel is anchored to `AuctionFrameBrowse`, a frame the client built and sized, rather
-- than to a corner of the window nobody here has measured (L-073).
--
-- **Every step is guarded and any of them may fail.** A client without the template, without
-- `PanelTemplates_SetNumTabs`, or without a fourth tab's worth of room answers nothing here, and
-- the button then sits beside Reset exactly where it has always sat. A tab that cannot be built
-- must never cost somebody the button.
local tab, panel, progress

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

-- **How far along whatever is reading has got**, in one sentence, or nothing where nothing is.
--
-- Three readers can be running and they are three different jobs, so this says which. A walk is
-- pages off the old house; a replicate read is the newer house answering its whole list at once;
-- and the third is not Family's read at all - it is somebody else's whole-house scan arriving on
-- the client's browse list, which Family reads for free and which is the fastest way to fill a
-- price store on any of these clients.
--
-- That third line is the one this panel exists for. On Classic Era 2026-09-12 the complaint was
-- that Family's own read takes far longer than another addon's, which is true and is the
-- throttle: the client refuses to send, 0.72 seconds a page over 394 pages, three of those five
-- minutes spent being refused. Nothing here can win that back. What Family can do is show, while
-- the other addon scans, that its work is being taken as well.
local function progressText()
	local walk = Family.Auctions:Walking()
	if walk and walk.pages then
		local gone = Family.Auctions:WalkSeconds(walk) or 0
		local done = walk.done or 0
		local left = done > 0 and gone / done * (walk.pages - done) or 0
		return string.format(L["page %d of %d, %d price(s) taken - about %s to go"],
			done, walk.pages, walk.kept or 0, UI:Span(left))
	end

	local reading = Family.Auctions:ReplicateReading()
	if reading and reading.rows then
		return string.format(L["reading the whole list: %d of %d row(s), %d price(s) taken"],
			reading.done or 0, reading.rows, reading.kept or 0)
	end

	local big = Family.Auctions:BigListReading()
	if big and big.count then
		return string.format(L["reading a list somebody else loaded: %d of %d row(s)"],
			big.at or 0, big.count)
	end

	return string.format(L["%d price(s) remembered for this realm and side"],
		Family.Auctions:PriceCount())
end

-- **Kept going by a timer while something is reading**, and stopped the moment nothing is.
--
-- The event this panel would otherwise ride on is `AUCTION_ITEM_LIST_UPDATE`, and during another
-- addon's whole-house delivery that event **does not fire at all** until the end - measured on
-- Burning Crusade 2026-09-12, nought firings through the delivery and then tens of thousands at
-- once. So a panel redrawn on that event would sit perfectly still through the one read it was
-- built to show.
--
-- **A panel that is up keeps itself current, whether or not anything is reading yet.** Written
-- first as *tick while a read is running*, which cannot start: with the panel open and nothing
-- happening there is no timer, so the moment somebody else's scan begins there is nothing
-- watching for it - and that scan is the whole reason this panel exists. Caught by the check
-- that reads the panel without clicking it, which is the only way to ask whether the timer works.
--
-- It costs one string a second while the player is looking at this tab, and stops when they are
-- not: the panel is put away on the client's own tabs, when the window opens, and when it shuts.
local function ticking()
	if panel and (Family:TryCall(panel.IsShown, panel)) then return true end

	return (Family.Auctions:Walking() or Family.Auctions:ReplicateReading()
		or Family.Auctions:BigListReading()) and true or false
end

local function refresh()
	if button then
		if Family.Auctions:Walking() or Family.Auctions:ReplicateReading() then
			button:SetText(L["Stop"])
		elseif waitingFor then
			button:SetText(L["Searching..."])
		else
			button:SetText(L["Read it all"])
		end
	end

	if progress then progress:SetText(progressText()) end

	if ticking() then
		Family:After(1, "ui.auctions.progress", function()
			-- Whatever else has changed, the panel is redrawn while a read is alive and
			-- the timer stops itself when one is not. `Family:After` replaces a pending
			-- timer under the same key, so this cannot pile up however often it is called.
			refresh()
		end)
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

-- **The client's own three panels, put away so ours can be seen.** Named rather than walked,
-- because the window has furniture that is not a panel and hiding all of it would take the tabs
-- with it. A name that is not there is not an error: on a client with only two of these, the
-- third simply is not found.
local CLIENT_PANELS = { "AuctionFrameBrowse", "AuctionFrameBid", "AuctionFrameAuctions" }

local function hideClientPanels()
	for _, name in ipairs(CLIENT_PANELS) do
		local other = _G[name]
		if type(other) == "table" and type(other.Hide) == "function" then
			Family:TryCall(other.Hide, other)
		end
	end
end

-- **A tab of ours beside the window's own, and a panel behind it.**
--
-- Returns the panel or nothing, and nothing is a perfectly good answer: every call below is one
-- this client may not have, and the button has somewhere else to sit.
--
-- **How many tabs there already are is read, not assumed.** `AuctionFrame.numTabs` is what
-- `PanelTemplates_SetNumTabs` last wrote there, so it is the client's own count on whichever
-- build this is - and three is exactly the sort of number that is right on two clients and
-- wrong on the third.
local function buildTab()
	if panel then return panel end

	local frame = _G.AuctionFrame
	if type(frame) ~= "table" or type(frame.CreateFontString) ~= "function" then return nil end
	if type(_G.PanelTemplates_SetNumTabs) ~= "function" then return nil end

	local held = tonumber(frame.numTabs)
	if not held or held < 1 then return nil end

	local last = _G["AuctionFrameTab" .. held]
	if type(last) ~= "table" or type(last.GetName) ~= "function" then return nil end

	-- Through `TryCall`, because a template this client turns out not to have would take the
	-- auction window down with it - and a window that will not open is a far worse fault than
	-- a tab that is not there. The same guard the button below has used since it was written.
	local made = (Family:TryCall(CreateFrame, "Button", "FamilyAuctionTab", frame,
		"AuctionFrameTabTemplate"))
	if type(made) ~= "table" or type(made.SetID) ~= "function" then return nil end

	tab = made
	tab:SetID(held + 1)
	tab:SetText(L["Family"])
	tab:SetPoint("LEFT", last, "RIGHT", -8, 0)

	Family:TryCall(_G.PanelTemplates_SetNumTabs, frame, held + 1)
	if type(_G.PanelTemplates_TabResize) == "function" then
		Family:TryCall(_G.PanelTemplates_TabResize, tab, 0)
	end

	-- **Anchored to a frame the client sized**, which is the whole of L-073: the browse panel
	-- is where the window's content goes, it has a size because the client gave it one, and a
	-- corner of the outer window is a coordinate nobody here has measured. Parented to the
	-- window rather than to that panel, or hiding the panel would hide ours with it.
	panel = (Family:TryCall(CreateFrame, "Frame", "FamilyAuctionPanel", frame))
	if type(panel) ~= "table" then
		tab, panel = nil, nil
		return nil
	end

	local content = _G.AuctionFrameBrowse
	if type(content) == "table" then
		panel:SetAllPoints(content)
	else
		panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -80)
		panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 40)
	end
	panel:Hide()

	progress = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	progress:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -60)
	progress:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -60)
	progress:SetJustifyH("LEFT")

	local blurb = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	blurb:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -10)
	blurb:SetPoint("TOPRIGHT", progress, "BOTTOMRIGHT", 0, -10)
	blurb:SetJustifyH("LEFT")
	blurb:SetText(L["Family reads whatever the auction window is showing, so another addon's "
		.. "whole-house scan fills these prices too - and far faster than reading it a page "
		.. "at a time."])

	tab:SetScript("OnClick", function(self)
		if type(_G.PanelTemplates_SetTab) == "function" then
			Family:TryCall(_G.PanelTemplates_SetTab, frame, self:GetID())
		end
		hideClientPanels()
		panel:Show()
		refresh()
	end)

	-- **And ours goes away when one of theirs is clicked.** Hooked on the client's own handler
	-- where there is one, because that is the single place all three of its tabs go through;
	-- where there is not, each tab is hooked instead. Hooking rather than replacing: what the
	-- window does with its own tabs is none of Family's business.
	if type(_G.hooksecurefunc) == "function"
		and type(_G.AuctionFrameTab_OnClick) == "function" then
		Family:TryCall(_G.hooksecurefunc, "AuctionFrameTab_OnClick", function()
			if panel then panel:Hide() end
		end)
	else
		for index = 1, held do
			local other = _G["AuctionFrameTab" .. index]
			if type(other) == "table" and type(other.HookScript) == "function" then
				other:HookScript("OnClick", function()
					if panel then panel:Hide() end
				end)
			end
		end
	end

	return panel
end

-- **Whether any of this should be on the window at all.**
--
-- Asked for 2026-09-12 as an extra a player switches: with it off Family values a family at
-- what a vendor pays and reads nothing here, so a tab offering to read the house would be a
-- control that does nothing. Asked of the scanner rather than of the setting, because the
-- scanner is what obeys it and one of them has to be the answer.
-- **The tab is the walk's**, not the price reader's. Listening happens whether or not this
-- window carries anything of Family's; a tab exists to start a read, so it belongs to the switch
-- that says whether Family reads the house itself. With prices off, `WalkWanted` is false too -
-- there would be nothing to do with the pages.
local function wanted()
	return Family.Auctions:WalkWanted()
end

local function build()
	if not wanted() then return end
	if button then return end

	-- The newer house first, because on a build that has it the old window is not there at all
	-- and nothing below would find anything to hang off.
	local modern = modernWindow()

	-- **A tab of Family's own, where this client will give us one.** Tried before the button is
	-- built, because where it succeeds the button belongs on it. Only on the old window: the
	-- newer house is a different frame whose tabs have never been read here, and inventing a
	-- coordinate on a layout nobody has seen is the fault L-073 records.
	local ours = not modern and buildTab() or nil

	local parent = ours or modern or _G.AuctionFrameBrowse
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

	-- **On Family's own panel where there is one**, which is what it was asked for: the button
	-- and how far it has got, in one place, on the window the player is already looking at.
	--
	-- Otherwise beside Reset on the old window, which is a control with a size of its own rather
	-- than a corner of a container nothing has measured (L-073). On the newer one there is no
	-- such control read yet, so the button hangs just outside the window's top-right corner,
	-- where no layout can put anything over it.
	local beside = not ours and not modern and _G[BESIDE] or nil
	if ours then
		button:SetPoint("TOPLEFT", ours, "TOPLEFT", 24, -20)
	elseif type(beside) == "table" then
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

-- **The switch was flipped, so this window has to catch up.**
--
-- Neither direction happens on its own: the auction window is built when a player first opens
-- an auction house, so turning the extra on while standing at an auctioneer has to build the
-- tab now, and turning it off has to take it away rather than leave a control that does
-- nothing. Hidden rather than destroyed - a frame cannot be unmade in this game, and hiding is
-- what the client itself does with the tabs it is not showing.
function UI:ExtraChanged(name)
	if name ~= "auctionPrices" and name ~= "houseWalk" then return end

	if wanted() then
		build()
		if tab then tab:Show() end
		if button then button:Show() end
	else
		if panel then panel:Hide() end
		if tab then tab:Hide() end
		if button then button:Hide() end
	end

	refresh()
end

-- **Reachable so the harness can build this twice**, which the game does not do and the checks
-- have to: the button and the tab are built once and kept, so a lane that has already built them
-- beside Reset cannot then build them on a window with tabs. Nothing in the addon calls this.
--
-- It does not take anything off the screen. What was built stays where it is; this only forgets
-- the handles, which is exactly what makes it useless in play and useful in a check.
function UI:__forgetAuctionFurniture()
	button, tab, panel, progress = nil, nil, nil, nil
end

Family:OnDatabaseReady("ui.auctions", function()
	-- The window is built when the client loads the addon that owns it, which is the first time
	-- the player opens an auction house - so this is the earliest moment it can be there.
	Family:RegisterEvent("AUCTION_HOUSE_SHOW", "ui.auctions", function()
		build()

		-- The client opens on its own first tab, so ours starts put away. Without this a
		-- panel left showing when the window was shut comes back over the browse list.
		if panel then panel:Hide() end

		refresh()
	end)

	-- **And the label keeps up with the walk.** Its own key, because a second registration
	-- under the scanner's would replace the scanner's (L-068).
	Family:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "ui.auctions.button", refresh)

	Family:RegisterEvent("AUCTION_HOUSE_CLOSED", "ui.auctions", function()
		giveUp()
		if panel then panel:Hide() end
	end)
end)
