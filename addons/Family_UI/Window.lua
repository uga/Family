-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The window everything else lives in.
--
-- Plain Lua and Blizzard's own templates, no XML and no framework (HANDOFF §1). Tabs
-- register themselves here; the window knows how to show one at a time and nothing about
-- what any of them contain.

local _, UI = ...

local Family = _G.Family
local L = Family.L
UI.Family = Family
Family.UI = UI

-- Wider than it was by exactly what the tab strip grew (below).
--
-- The strip taking room for its pictures took it from every panel's content, and the summary
-- said so at once: the side filters at the right-hand end of its top row began touching the
-- last set button. Shaving the buttons would have been treating the symptom on one panel and
-- leaving the other five quietly tighter than they were designed to be.
local WIDTH, HEIGHT = 924, 560

--------------------------------------------------------------------------------------------
-- The pictures on the tab strip
--
-- Every one of these was looked at, at this size, on Classic Era, Anniversary and Mists,
-- before it was written down - because a texture is the one thing in Family that cannot be
-- probed (HANDOFF §3). A path that does not exist draws nothing, silently, and GetTexture()
-- reads back whatever string it was handed, so confidence is worth exactly nothing here.
-- Chosen from `tools/FamilyIconSheet` on 2026-08-25.
--
-- They live in one table rather than beside each RegisterTab call, and that is the whole
-- point: the list of paths Family asserts exist is then one thing to audit against one set of
-- screenshots, instead of nine lines scattered across nine files with nothing tying them to
-- the day somebody checked.
--
-- A tab with no entry here draws no picture and keeps the space, so the labels stay in line
-- down the strip. That is deliberately better than a question mark, which reads as a fault
-- rather than as a gap.
--
-- No two of these may be the same. Summary and Wide Family were first chosen the same
-- picture, and a strip where two rows are alike has stopped being readable by icon, which is
-- most of what the icons are for. The harness checks it, because it is the one thing about
-- this table that can be checked without eyes.
local TAB_ICONS = {
	summary     = "Interface\\Icons\\INV_Misc_GroupLooking",
	talents     = "Interface\\Icons\\INV_Misc_Book_11",
	contents    = "Interface\\Icons\\INV_Misc_Bag_07",
	professions = "Interface\\Minimap\\Tracking\\Profession",
	character   = "Interface\\Icons\\INV_Shirt_White_01",
	wide        = "Interface\\Icons\\INV_Misc_GroupNeedMore",
	guild       = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
	options     = "Interface\\Icons\\Ability_Repair",
	about       = "Interface\\Common\\help-i",
}

UI.TAB_ICONS = TAB_ICONS

-- The strip is wider than it was by exactly what the icon costs, so no label lost any room
-- to it. Sized down instead, "Abilities & Talents" would have been the one to go, and a tab
-- whose name is cut in half says less than a tab with no picture on it.
local TAB_W, TAB_H = 160, 24
local TAB_STEP = 27
local STRIP_W = TAB_W + 4
local TAB_ICON = 16
local TAB_TEXT_INSET = 22         -- the picture, and a gap after it

local tabs, tabButtons = {}, {}
local current

--------------------------------------------------------------------------------------------

local window = CreateFrame("Frame", "FamilyWindow", UIParent, "BasicFrameTemplateWithInset")
window:SetSize(WIDTH, HEIGHT)
window:SetPoint("CENTER")
window:SetMovable(true)
window:EnableMouse(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", window.StopMovingOrSizing)
window:SetClampedToScreen(true)
window:Hide()

--------------------------------------------------------------------------------------------
-- Layering
--
-- Which strata a window needs is not something that can be decided from the code, because it
-- depends on what else the player runs. A HUD drawing its health numbers over the top of
-- this window is not a bug in either addon - it is two addons with an opinion about depth
-- and no way to know about each other.
--
-- So it is a setting, defaulting high enough to clear the ordinary run of unit frames and
-- HUDs, and adjustable without a code change when it does not.
--
-- Not FULLSCREEN or TOOLTIP: a panel that covers tooltips, or the map, has stopped being a
-- panel and become a nuisance.
--------------------------------------------------------------------------------------------

local STRATA = { "MEDIUM", "HIGH", "DIALOG" }
local DEFAULT_STRATA = "HIGH"

function UI:StrataChoices()
	return STRATA
end

-- Nothing here reads FamilyDB at file scope. The game loads a dependency completely, saved
-- variables and all, before a dependent addon's files run - but relying on that is relying
-- on load order, and load order is exactly the sort of thing that is true until it is not.
function UI:SetStrata(name)
	local wanted
	for _, candidate in ipairs(STRATA) do
		if candidate == (name or ""):upper() then wanted = candidate end
	end
	if not wanted then return nil end

	window:SetFrameStrata(wanted)
	window:SetToplevel(true)
	window:Raise()

	if FamilyDB then
		FamilyDB.ui = FamilyDB.ui or {}
		FamilyDB.ui.strata = wanted
	end
	return wanted
end

function UI:CurrentStrata()
	return (FamilyDB and FamilyDB.ui and FamilyDB.ui.strata) or DEFAULT_STRATA
end

window:SetFrameStrata(DEFAULT_STRATA)
window:SetToplevel(true)

Family:OnDatabaseReady("ui.strata", function()
	UI:SetStrata(UI:CurrentStrata())
end)

-- Escape closes it, like every other panel in the game.
tinsert(UISpecialFrames, "FamilyWindow")

window.TitleText:SetText(L["Family"])

UI.window = window

-- How much room a panel actually has, which is a thing panels have had to guess at. The Wide
-- Family consent grid guessed 816 pixels of it and had 712, so its last column was drawn off
-- the end of the list and the one before it was cut by the edge. A panel that lays out fixed
-- columns can ask instead.
UI.CONTENT_W = WIDTH - (12 + STRIP_W) - 8

-- What a scroll bar and its inset take out of that, for a panel whose columns live in one.
UI.SCROLLBAR_W = 32

-- How wide to make a list inside a scroll frame, and what to answer when the client has not
-- measured the scroll frame yet.
--
-- Panels read scroll:GetWidth() while refreshing, and on a panel's first draw that answer is
-- nought - the frame exists and has not been laid out. Several panels fell back to 200, which
-- is not a width any of them can be drawn at: the guild row anchors its middle column at x=244
-- and its right column to the right-hand edge with a width of 200, so at a list width of 200
-- all three of its texts were written on top of one another. Closing the window and opening it
-- again appeared to fix it, and had only given the second draw a measurement the first was
-- refused.
--
-- The panel's own content width is known before any frame is laid out, so it is what a panel
-- gets when the client has nothing to tell it. A fallback has to be a width the panel can
-- actually be drawn at, or it is just a different way of being wrong.
-- Something solid behind a frame that floats over a panel.
--
-- TooltipBorderedFrameTemplate draws an edge and, on these clients, nothing behind it, so a
-- list opened over a panel had that panel's words read straight through its own: a member's
-- name over a recipe's, and neither of them legible. Every popup here paints its own fill
-- rather than trusting the template, because what a template paints differs between these
-- clients and is the one thing that cannot be probed - the client echoes back whatever texture
-- path it was handed, whether or not it drew a single pixel of it.
--
-- BACKGROUND at the lowest sub-level, so a row's own hover highlight still shows over it.
function UI:PaintOpaque(frame)
	if not frame or not frame.CreateTexture then return end
	local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetAllPoints()
	fill:SetColorTexture(0, 0, 0, 0.95)
	return fill
end

function UI:ListWidth(scroll)
	local room = scroll and scroll.GetWidth and scroll:GetWidth()
	if type(room) == "number" and room >= 200 then return room end
	return (UI.CONTENT_W or 740) - UI.SCROLLBAR_W
end

local content = CreateFrame("Frame", nil, window)
content:SetPoint("TOPLEFT", 12 + STRIP_W, -32)
content:SetPoint("BOTTOMRIGHT", -8, 8)
UI.content = content

-- The tab strip runs down the left, because the number of tabs is fixed and the number of
-- members is not - horizontal tabs would compete for the width the table needs.
local strip = CreateFrame("Frame", nil, window)
strip:SetPoint("TOPLEFT", 8, -32)
strip:SetPoint("BOTTOMLEFT", 8, 8)
-- Wide enough for the longest tab name there is. A strip sized to "Summary" clipped
-- "Abilities & Talents" to something that read as a different tab - and adding a picture to
-- the front of every label is the same mistake in a different order, so the strip grew by
-- what the picture takes rather than the labels shrinking by it.
strip:SetWidth(STRIP_W)

--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- Columns that hold their own headings
--
-- Every fixed column width in Family was chosen by looking at English, and English is the
-- shortest of the five languages it speaks. "Last seen" is nine characters and was given 95
-- pixels; a German client draws Blizzard's own word for the same thing in that space and
-- writes it straight through the column beside it.
--
-- The fix is not a shorter word - a game term has to be the game's term, whatever its length
-- (DATASOURCES, "By global string"), and it is not ours to abbreviate. The fix is that the
-- column gives way instead: every one is widened to hold its heading, and the room that
-- costs is taken back from whichever columns have the most to spare.
--
-- Measured, not counted. GetStringWidth asks the client what it will actually draw, which is
-- the only thing that knows - the fonts are not monospaced and Blizzard's translation of a
-- term is whatever it is. Counting characters here would be guessing twice over.
--
-- `measure` is a font string in the same font the headings are drawn in, never shown. What
-- is measured has to be drawn the same way or the answer is about a different string.
--------------------------------------------------------------------------------------------

-- Each edge a heading needs clear of its neighbour: the 4 pixels a cell is inset by on each
-- side, and two more so that two headings never quite touch.
local HEADER_PAD = 10

-- Shared by the columns and by the rows of buttons: given what each thing needs and the
-- least it may have, take any excess back from whatever is carrying the most slack, and
-- never take anything below its floor.
local function shrinkToFit(need, floor, budget)
	if not budget then return end

	local total = 0
	for index = 1, #need do total = total + need[index] end

	local over = total - budget
	while over > 0 do
		local most, at = 0, nil
		for index = 1, #need do
			local slack = need[index] - floor[index]
			if slack > most then most, at = slack, index end
		end
		if not at then break end
		local take = math.min(over, most)
		need[at] = need[at] - take
		over = over - take
	end
end

-- A row of buttons, each as wide as its own label needs.
--
-- The same fault as the columns and the same answer. Every button width in Family was picked
-- by looking at an English label; "Skill needed" fits 110 pixels and "Compétence requise"
-- does not, so it was drawn straight out of the button and into the one beside it. Sizing
-- each button to its text and then placing them one after the next means a longer word costs
-- room rather than legibility.
--
-- `minimum` keeps a row of short labels looking like a row rather than like a set of
-- differently sized lozenges. `budget`, where the row has one, is shared out the same way the
-- columns share theirs.
local BUTTON_PAD = 18

-- `place` is how a row anchors itself, because they do not all anchor the same way: some sit
-- on their own bar, some hang off the caption above them. Given the button, where it starts
-- and how wide it turned out, a caller that has a preference says so; the rest get the
-- ordinary thing, which is left to right inside the parent.
-- How much room to leave under a scrolling table for the captions beneath it.
--
-- A margin below the footer, the footer, a gap and the note where there is one, and then a
-- clear line before the table starts. The heights are measured by the caller after the text
-- is written, because how tall a caption is depends on the language it is in: English fits
-- the summary's grand totals on one line and French wraps them onto two, which drew the
-- table's last row underneath them.
--
-- The last term is the one that is easy to leave out and the one that shows: without it the
-- bottom row sits directly on the caption and the two read as a single block of text.
function UI:CaptionRoom(footerHeight, noteHeight, margin, gap, clear)
	margin = margin or 8
	gap = gap or 4
	clear = clear or 8

	local room = margin + math.ceil(footerHeight or 12)
	if noteHeight and noteHeight > 0 then
		room = room + gap + math.ceil(noteHeight)
	end
	return room + clear
end

-- One button, on its own, wide enough for what it says. The rows above are the interesting
-- case; this is for the buttons that are anchored individually and have nothing to share
-- their line with.
function UI:FitButton(button, minimum)
	if not button then return end
	local text = button.GetFontString and button:GetFontString()
	local wanted = (text and text.GetStringWidth and text:GetStringWidth()) or 0
	button:SetWidth(math.max(minimum or 0,
		math.ceil(wanted) + BUTTON_PAD + (button.__labelInset or 0)))
end

function UI:LayOutRow(buttons, minimum, gap, from, place, budget)
	if not buttons or #buttons == 0 then return from or 0 end

	local need, floor = {}, {}
	for index, button in ipairs(buttons) do
		local text = button.GetFontString and button:GetFontString()
		local wanted = (text and text.GetStringWidth and text:GetStringWidth()) or 0
		-- A button carrying a picture holds its label to one side of it, and that room is
		-- not room for the label. Set by whoever put the picture there.
		floor[index] = math.ceil(wanted) + BUTTON_PAD + (button.__labelInset or 0)
		need[index] = math.max(minimum or 0, floor[index])
	end

	shrinkToFit(need, floor, budget)

	-- Squeezing stops at the labels themselves, so a row of words long enough can still be
	-- wider than the room there is. Said out loud rather than drawn off the edge of the
	-- panel in silence: the same answer the summary gives when its columns will not fit.
	if budget then
		local total = 0
		for index = 1, #need do total = total + need[index] + (gap or 4) end
		if total - (gap or 4) > budget then
			Family:Print(L["|cffffaa00a row of %d buttons needs %d pixels and has %d - the "
				.. "labels are longer than the room in this language|r"],
				#buttons, math.ceil(total - (gap or 4)), math.ceil(budget))
		end
	end

	local x = from or 0
	for index, button in ipairs(buttons) do
		button:SetWidth(need[index])
		button:ClearAllPoints()
		if place then
			place(button, x, need[index])
		else
			button:SetPoint("LEFT", x, 0)
		end
		x = x + need[index] + (gap or 4)
	end
	return x
end

function UI:FitColumns(columns, budget, measure)
	if not (columns and measure and measure.GetStringWidth) then return end

	local need, floor = {}, {}
	for index, column in ipairs(columns) do
		measure:SetText(column.label or "")
		floor[index] = math.ceil((measure:GetStringWidth() or 0) + HEADER_PAD)
		need[index] = math.max(column.width or 0, floor[index])
	end

	-- Wider than the row: take it back from whatever is carrying slack, most first. A
	-- column is never taken below its own heading - that is the fault being fixed here, and
	-- reintroducing it to balance the books would be absurd. If every column is already at
	-- its heading and it still does not fit, this stops and the panel's own warning stands.
	shrinkToFit(need, floor, budget)

	for index, column in ipairs(columns) do column.drawWidth = need[index] end
end

function UI:RegisterTab(id, label, builder)
	local index = #tabs + 1

	local button = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
	button:SetSize(TAB_W, TAB_H)
	button:SetPoint("TOPLEFT", 0, -((index - 1) * TAB_STEP))
	button:SetText(label)
	button:SetScript("OnClick", function() UI:ShowTab(id) end)

	-- The picture, and the label moved out of the way of it.
	--
	-- The template centres its text, which puts a short name in the middle of the button
	-- with the icon marooned at the far left and a long one running under the icon. Pinned
	-- to the left of the space the icon leaves instead, so every label starts in the same
	-- place whether or not its tab has a picture yet.
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(TAB_ICON, TAB_ICON)
	icon:SetPoint("LEFT", 5, 0)
	button.icon = icon

	local path = TAB_ICONS[id]
	if path then
		icon:SetTexture(path)
	else
		icon:Hide()
	end

	local text = button.GetFontString and button:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("LEFT", TAB_TEXT_INSET, 0)
		text:SetWidth(TAB_W - TAB_TEXT_INSET - 4)
		text:SetJustifyH("LEFT")
		if text.SetWordWrap then text:SetWordWrap(false) end
	end

	-- The star that says which panel Family opens on. A texture the game ships with, so
	-- there is no path of Family's own to be wrong about (HANDOFF §3), and a button over it
	-- because a texture cannot be clicked.
	local star = CreateFrame("Button", nil, button)
	star:SetSize(14, 14)
	star:SetPoint("RIGHT", -4, 0)
	star:SetNormalTexture("Interface\\Common\\ReputationStar")
	if star.GetNormalTexture and star:GetNormalTexture() then
		star:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
	end
	star:SetScript("OnClick", function()
		UI:SetDefaultPanel(id)
		UI:ShowTab(id)
	end)
	UI:AttachTooltip(star, function()
		return nil, nil, { { L["Open Family here"] },
			{ L["|cff9d9d9dFamily opens on this panel, every time.|r"] } }
	end)
	star:Hide()

	button.star = star

	tabs[index] = { id = id, label = label, builder = builder, frame = nil, icon = path }
	tabButtons[id] = button

	UI:RefreshStars()

	return index
end

-- The buttons themselves, for the harness: whether a star is offered and which one is filled
-- is a fact about the strip, and nothing outside this file can otherwise see it.
function UI:TabButtons()
	return tabButtons
end

-- Which tabs there are, and what each is drawn with. For the harness, which is the only thing
-- that can check the strip is internally consistent - whether a path exists is the one
-- question it cannot answer, and the reason `tools/FamilyIconSheet` exists.
function UI:Tabs()
	return tabs
end

-- Whether Family opens on a panel somebody chose, rather than on the first one.
--
-- Off unless it is asked for, and *chosen* rather than inferred. Reopening wherever you
-- happened to be last is a different thing and the wrong one: go to a second panel, close the
-- window, and it has quietly moved your home - which is exactly what somebody who wants to
-- land on the same screen every time did not ask for.
function UI:UsesDefaultPanel()
	return (FamilyDB and FamilyDB.ui and FamilyDB.ui.useDefaultPanel) and true or false
end

function UI:SetUsesDefaultPanel(on)
	FamilyDB.ui = FamilyDB.ui or {}
	FamilyDB.ui.useDefaultPanel = on and true or false
	UI:RefreshStars()
end

-- Which panel is starred, whether or not the switch is on. Kept while it is off so that
-- switching it back on lands where it did before rather than forgetting.
function UI:DefaultPanel()
	return (FamilyDB and FamilyDB.ui and FamilyDB.ui.defaultPanel) or nil
end

-- Starring a panel takes it as it stands. For the summary that means the set of columns
-- showing at the time, because "Activity" and "Currencies" are as different as two panels and
-- a home that landed on whichever was last used would have the same fault as the version this
-- replaces.
function UI:SetDefaultPanel(id)
	FamilyDB.ui = FamilyDB.ui or {}
	FamilyDB.ui.defaultPanel = id
	FamilyDB.ui.defaultSet = (id == "summary") and UI.__summarySet or nil
	UI:RefreshStars()
end

-- What the summary should open on, or nothing where no choice has been made.
function UI:DefaultSet()
	if not UI:UsesDefaultPanel() then return nil end
	if UI:DefaultPanel() ~= "summary" then return nil end
	return (FamilyDB.ui or {}).defaultSet
end

-- Which tab a window with nothing open yet should open on.
--
-- Its own function so that it can be asked without opening anything: closing the window does
-- not forget which tab is up, so within one session it already comes back where it was. What
-- this decides is the first opening after a login, which no check can stage.
function UI:StartingTab()
	if UI:UsesDefaultPanel() then
		local home = UI:DefaultPanel()
		if home and UI:HasTab(home) then return home end
	end

	return tabs[1] and tabs[1].id
end

-- The star on each tab: hollow on the others, filled on the one that is home, and gone
-- entirely while the switch is off. Nobody who has not asked for this should have to look at
-- nine stars.
function UI:RefreshStars()
	local on, home = UI:UsesDefaultPanel(), UI:DefaultPanel()

	for id, button in pairs(tabButtons) do
		if button.star then
			button.star:SetShown(on)
			button.star:SetAlpha(id == home and 1 or 0.35)
		end
	end
end

function UI:ShowTab(id)
	for _, tab in ipairs(tabs) do
		local selected = tab.id == id

		if selected and not tab.frame then
			-- Built the first time it is looked at, not at login.
			--
			-- Isolated, the same way event handlers are (Core.lua). A builder that
			-- throws half way leaves a frame that exists, is empty, and has no Refresh
			-- - which looks exactly like a panel with no data in it and sends you
			-- hunting in the wrong place. Say what actually happened.
			tab.frame = CreateFrame("Frame", nil, content)
			tab.frame:SetAllPoints(content)

			local ok, err = pcall(tab.builder, tab.frame)
			if not ok then
				Family:Print(L["|cffff5555the %s panel failed to build|r: %s"], tab.id,
					tostring(err))
				tab.broken = true
			end
		end

		if tab.frame then
			tab.frame:SetShown(selected)
		end

		local button = tabButtons[tab.id]
		if button then
			UI:MarkSelected(button, selected)
		end

		if selected then
			current = tab
			window.TitleText:SetText(string.format(L["Family - %s"], tab.label))

			if tab.frame.Refresh then
				local ok, err = pcall(tab.frame.Refresh, tab.frame)
				if not ok then
					Family:Print(L["|cffff5555the %s panel failed to draw|r: %s"], tab.id,
						tostring(err))
				end
			elseif not tab.broken then
				Family:Print(L["|cffffaa00the %s panel built but defined no Refresh|r"],
					tab.id)
			end
		end
	end
end

-- A scan that lands while a panel is open redraws it, coalesced because a single login
-- writes to the database a dozen times in a few seconds and each of those would otherwise be
-- a redraw of forty rows.
Family:OnDatabaseReady("ui.changes", function()
	Family.Database:OnChanged("ui", function()
		if not window:IsShown() then return end
		Family:After(0.5, "ui.refresh", function()
			if window:IsShown() then UI:Refresh() end
		end)
	end)
end)

function UI:Refresh()
	if current and current.frame and current.frame.Refresh then
		local ok, err = pcall(current.frame.Refresh, current.frame)
		if not ok then
			Family:Print(L["|cffff5555the %s panel failed to draw|r: %s"], current.id,
				tostring(err))
		end
	end
end

function UI:Toggle()
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
		if not current then
			UI:ShowTab(UI:StartingTab())
		else
			UI:Refresh()
		end
	end
end

function UI:Show()
	if not window:IsShown() then UI:Toggle() end
end

function UI:IsShown()
	return window:IsShown() and true or false
end

-- Which tab is being looked at, for anything that wants to send you somewhere and needs to
-- know whether you are already there.
function UI:CurrentTab()
	return current and current.id or nil
end

-- Whether a tab is in the strip at all. Two of them are conditional - Wide Family on a
-- preference, and any tab a future client cannot support - so "is it there" is a question
-- worth being able to ask rather than inferring from a panel being blank.
function UI:HasTab(id)
	for _, tab in ipairs(tabs) do
		if tab.id == id then return true end
	end
	return false
end

function UI:Hide()
	window:Hide()
end

-- Sending you to one of the game's own windows, and then getting out of its way.
--
-- Family sits at HIGH and the game's panels - the quest log, the character sheet, a
-- profession window - sit below it. **Strata beats click order**, so a panel in a lower one
-- can never be brought in front by clicking it, however many times: the quest log Family had
-- just opened stayed behind Family and there was nothing the player could do about it. That is
-- not a fault in either frame, and it is not fixable by raising or lowering anything without
-- breaking the setting that exists because other addons draw over this one.
--
-- So when Family opens one of the game's windows for you, Family closes. You clicked in order
-- to look at that window; leaving the thing you came from lying on top of it is the one
-- outcome nobody wanted. `/family` brings it back, on the tab it was on.
function UI:StepAside()
	if window:IsShown() then window:Hide() end
end

-- Both list popups are parented to the screen rather than to the window - they have to be, or
-- they would be clipped by the panel they open over - so hiding the window does not take them
-- with it, and a list left hanging over the game with nothing behind it is the result.
--
-- MemberPicker has had the call to close it since it was written and nothing ever made it;
-- adding a second popup with the same hazard is a good moment to notice.
window:HookScript("OnHide", function()
	if UI.CloseMemberPickers then UI:CloseMemberPickers() end
	if UI.CloseChoicePickers then UI:CloseChoicePickers() end
end)

--------------------------------------------------------------------------------------------
-- Marking which of a row of buttons is the one you are looking at
--
-- Disabling it was the obvious way and the wrong one. A greyed button is how the game says
-- "you cannot do this", so using it to mean "this is the one you are on" says the opposite
-- of what is meant - the current tab looked broken and the ones you could reach looked
-- available, which is true but reads as the current one being unavailable.
--
-- Held highlighted and in gold instead, which is how the game marks a thing as current, and
-- left clickable: clicking the tab you are already on should do nothing, not be impossible.
--------------------------------------------------------------------------------------------

function UI:MarkSelected(button, selected)
	if not button then return end

	button:Enable()

	if selected then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end

	local label = button.GetFontString and button:GetFontString()
	if label then
		if selected then
			label:SetTextColor(1, 0.82, 0)
		else
			label:SetTextColor(1, 1, 1)
		end
	end
end

--------------------------------------------------------------------------------------------
-- Scrolling
--
-- UIPanelScrollFrameTemplate brings a scrollbar and its two arrows, and nothing that
-- responds to a wheel. A list longer than the window is then reachable only by dragging a
-- narrow bar, which most people will not think to try - so the content is not really there.
--------------------------------------------------------------------------------------------

local WHEEL_STEP = 3 * 18   -- three rows a notch, at the row height the panels use

function UI:MakeScrollable(scroll)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		local wanted = (self:GetVerticalScroll() or 0) - (delta * WHEEL_STEP)

		if wanted < 0 then wanted = 0 end
		if wanted > range then wanted = range end

		self:SetVerticalScroll(wanted)
	end)
end

--------------------------------------------------------------------------------------------
-- Removing a member
--
-- The one destructive thing this window can do, so it asks first - and it says who, because
-- a confirmation that does not name what it is about to delete is not a confirmation.
--
-- Which member is remembered here rather than handed to the popup, because how a popup
-- carries its data differs across these clients and a closure does not.
--------------------------------------------------------------------------------------------

local FORGET_POPUP = "FAMILY_FORGET_MEMBER"
local pendingForget

-- Asking about anything else that cannot be undone.
--
-- The member popup below does one thing and does it by name; this is for the rest - ending a
-- link, say - and it is separate rather than a parameter, because a confirmation whose
-- wording is assembled from arguments ends up asking questions nobody wrote.
local ASK_POPUP = "FAMILY_CONFIRM"
local pendingAsk

function UI:Confirm(question, onAccept)
    if type(onAccept) ~= "function" then return end
    pendingAsk = onAccept

    if not (StaticPopupDialogs and StaticPopup_Show) then
        -- Nowhere to ask, so nothing happens. Doing it anyway because the popup is missing
        -- would be the one reading of "confirm" that cannot be right.
        Family:Print(L["|cffffaa00%s|r - but this client has no way to ask, so nothing was "
            .. "done."], tostring(question))
        pendingAsk = nil
        return
    end

    StaticPopupDialogs[ASK_POPUP] = StaticPopupDialogs[ASK_POPUP] or {
        text = "%s",
        button1 = _G.YES or L["Yes"],
        button2 = _G.NO or L["No"],
        OnAccept = function()
            local act = pendingAsk
            pendingAsk = nil
            if act then act() end
        end,
        OnCancel = function() pendingAsk = nil end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(ASK_POPUP, question)
end

function UI:ConfirmForget(key, name, realm)
	if not key then return end
	pendingForget = key

	-- Two characters can have the same name on two realms, and Family keeps them apart. A
	-- confirmation that does not say which of them it means is not much of one.
	name = name or key
	if realm then name = name .. " - " .. realm end

	if not (StaticPopupDialogs and StaticPopup_Show) then
		-- Nowhere to ask, so nothing is deleted. Saying what to type is the honest
		-- answer; deleting without asking is not.
		Family:Print(L["to remove %s, type |cffffd700/family forget %s|r"], name, key)
		return
	end

	StaticPopupDialogs[FORGET_POPUP] = StaticPopupDialogs[FORGET_POPUP] or {
		text = L["Remove %s from Family?\n\nEverything recorded about this character goes "
			.. "with it. Logging in on them again starts recording afresh."],
		button1 = _G.YES or L["Yes"],
		button2 = _G.NO or L["No"],
		OnAccept = function()
			if not pendingForget then return end
			Family.Database:Forget(pendingForget)
			pendingForget = nil
			UI:Refresh()
			if UI.UpdateBroker then UI:UpdateBroker() end
		end,
		OnCancel = function() pendingForget = nil end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopup_Show(FORGET_POPUP, name)
end

--------------------------------------------------------------------------------------------
-- Shared formatting
--------------------------------------------------------------------------------------------

-- Rows in these panels are a fixed height, so a cell that wraps does not make its row taller
-- - it draws over the row underneath. An achievement description ran to three lines and took
-- two other achievements with it. Text that does not fit is cut off instead, which is the
-- honest failure: the row below stays legible and the whole of it is a hover away.
function UI:NoWrap(...)
	for index = 1, select("#", ...) do
		local text = select(index, ...)
		if text and text.SetWordWrap then text:SetWordWrap(false) end
	end
end

-- Money, in the game's own colours. GetMoneyString exists on some of these clients and not
-- others, and its output differs, so Family formats its own and gets the same answer
-- everywhere.
--
-- Silver and copper are always two digits and the gold part is always there, even at nought.
-- A column of amounts is read by comparing them, and dropping the empty parts - which is what
-- the game itself does - meant "47g 87s 80c" sat under "354g 0s 39c" with nothing lining up:
-- every row put its gold, silver and copper in a different place. Right-aligned and evenly
-- shaped, the three parts land in the same three places on every row.
-- What every panel says for a thing it has never been told. One string rather than one per
-- file, because "we were never told" has to look the same everywhere or it reads as a value.
UI.UNKNOWN = "|cff9d9d9d-|r"

function UI:Money(copper)
	-- Nought copper is a fact about somebody who is broke. Nothing is a fact about us, and
	-- the two must not print the same (§2.2). This used to answer "0g 00s 00c" for both,
	-- which is how a linked family's members - whose money nobody had agreed to share -
	-- came to be listed on the summary as having none.
	if copper == nil then return UI.UNKNOWN end

	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local bronze = copper % 100

	return string.format("|cffffd700%d|rg |cffc7c7cf%02d|rs |cffeda55f%02d|rc",
		gold, silver, bronze)
end

-- A member named somewhere that is not about them alone: a search result, a tooltip, a
-- broker line. Two things can need saying, and only when they need saying.
--
-- The realm, when two of the listed names are the same - Family keeps two characters called
-- Eccebombo apart everywhere else and a single line has no column to do it in.
--
-- The side, when it is not the player's own. Their bank is a different bank and their auction
-- house is a different auction house, so what can be done about a thing depends on it
-- entirely - and a search result that does not say so invites a trip to the wrong mailbox.
function UI:NameOf(entry, clashes)
	local label = entry.name or entry.key or "?"

	if clashes and entry.realm then
		label = string.format("%s |cff888888(@%s)|r", label, entry.realm)
	end

	local mine = Family:TryCall(UnitFactionGroup, "player")
	if mine and entry.faction and entry.faction ~= mine then
		label = string.format("%s |cff888888(%s)|r", label, entry.faction:sub(1, 1))
	end

	return label
end

-- The same for a list: which names are said more than once, so only those carry their realm.
function UI:NamesOf(entries)
	local counts = {}
	for _, entry in ipairs(entries) do
		counts[entry.name or entry.key] = (counts[entry.name or entry.key] or 0) + 1
	end

	for _, entry in ipairs(entries) do
		entry.label = UI:NameOf(entry, counts[entry.name or entry.key] > 1)
	end

	return entries
end

--------------------------------------------------------------------------------------------
-- Reading a member, ours or somebody else's
--
-- A sibling (§6) sits in the same lists as our own members, so every panel that draws a list
-- would otherwise need to know that borrowed records live somewhere different and are reached
-- a different way. These two put that in one place: hand them a key and they answer, and the
-- panel above never learns whose the member was.
--
-- Borrowed keys begin with "@", which no character name can, so the two can never be mistaken
-- for one another and nothing has to be told apart by looking it up in both.
--------------------------------------------------------------------------------------------

local function borrowed(key)
	if type(key) ~= "string" or key:sub(1, 1) ~= "@" then return nil end
	return Family.Wide and Family.Wide:Borrowed(key) or nil
end

function UI:IsBorrowed(key)
	return borrowed(key) ~= nil
end

function UI:Meta(key)
	local entry = borrowed(key)
	if entry then return entry.meta end
	return Family.Database:Meta(key)
end

function UI:Payload(key)
	local entry = borrowed(key)
	-- Never decoded, because it never was encoded: what arrives over the wire is already a
	-- table, and only what we store is compressed.
	if entry then return entry.payload end
	return Family.Database:Payload(key)
end

-- Everyone a panel about one member may be asked about: our own, then everyone a linked
-- family shares with us.
--
-- Not only the siblings. A sibling is a decision about the *summary* - who belongs in my
-- lists, beside my own - and it was doing a second job nobody asked it to do: until now it
-- was also the only way to see a shared member's gear, bags, professions or talents at all,
-- because the four panels that show one member at a time offered our own members and nothing
-- else. So a family could grant you eight categories about eleven characters and you would
-- see none of it until you ticked them into your summary as well, which is a different
-- question and often the wrong answer to it.
--
-- Siblings stay what §6 says they are. This is the other half: everything shared is reachable,
-- and what appears in your own lists is still only what you asked for.
-- Our own, and nobody else's. A separate name from the one below rather than an argument to
-- it, because the difference between "everyone" and "ours" is the difference between a list to
-- look through and a list to be counted in, and a caller that wants one and gets the other
-- has no way of noticing. That is not hypothetical: the gear grid asked for ours, was quietly
-- handed everyone, and put a linked family's members in with our own under no heading at all.
function UI:OurMembers(keep)
	local ours = {}
	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		if not keep or keep(meta, key) then
			ours[#ours + 1] = { key = key, meta = meta }
		end
	end
	table.sort(ours, function(a, b) return a.key < b.key end)
	return ours
end

function UI:EveryMember(keep)
	local ours = UI:OurMembers(keep)

	local theirs = {}
	for _, member in ipairs(Family.Wide:BorrowedMembers()) do
		local meta = member.meta or {}
		if not keep or keep(meta, member.borrowedKey) then
			-- Under the family that shared them AND the realm they are on. Whose they
			-- are is the fact that decides what this panel can say about them, so it
			-- leads; but §6 asks for them "as a sub-section of the realm they are on,
			-- under the family they belong to", and a family with thirty members spread
			-- over three realms was one undivided run of names without it.
			--
			-- The realm rides on the end of the localised sentence rather than inside
			-- it, so that adding it costs no translator anything.
			local realm = meta.realm or "?"
			local where = meta.faction and (realm .. " " .. meta.faction) or realm

			theirs[#theirs + 1] = {
				key = member.borrowedKey,
				meta = meta,
				group = string.format(L["|cffc79fefshared by %s|r"],
					tostring(member.familyName))
					.. "  |cff888888" .. where .. "|r",
			}
		end
	end
	table.sort(theirs, function(a, b)
		if a.group ~= b.group then return a.group < b.group end
		return tostring(a.meta.name or a.key) < tostring(b.meta.name or b.key)
	end)

	for _, member in ipairs(theirs) do ours[#ours + 1] = member end
	return ours
end

--------------------------------------------------------------------------------------------
-- Closing a list by clicking away from it
--
-- A list that opens and can only be closed by choosing something from it is a list that makes
-- you answer a question you have decided not to answer. Both of Family's - the member button
-- and the realm and class buttons - were like that: nothing dismissed them but a selection,
-- and Escape worked on one of them and only while the search box had the cursor.
--
-- A sheet across the screen, behind the list and in front of everything else, is how a menu
-- in this game is normally dismissed: the click that closes it lands on the sheet and goes no
-- further, which is why choosing something elsewhere takes two clicks - the first puts the
-- menu away. That is the behaviour people expect, not a cost of doing it this way.
--------------------------------------------------------------------------------------------

local catcher

function UI:DismissOnClickOutside(popup)
	if not catcher then
		catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:SetFrameLevel(1)
		catcher:RegisterForClicks("AnyUp")
		catcher:Hide()
		catcher:SetScript("OnClick", function(self)
			local open = self.popup
			self.popup = nil
			self:Hide()
			if open then open:Hide() end
		end)
	end

	-- In front of the sheet, so the list itself is still clickable.
	popup:SetFrameLevel(10)

	popup:HookScript("OnShow", function(self)
		catcher.popup = self
		catcher:Show()
	end)

	popup:HookScript("OnHide", function(self)
		if catcher.popup == self then
			catcher.popup = nil
			catcher:Hide()
		end
	end)

	-- And Escape, which is how everything else in this game closes.
	local name = popup.GetName and popup:GetName()
	if type(name) == "string" and type(UISpecialFrames) == "table" then
		local listed
		for _, entry in ipairs(UISpecialFrames) do
			if entry == name then listed = true end
		end
		if not listed then table.insert(UISpecialFrames, name) end
	end
end

function UI:ClassColour(classFile)
	local colours = _G.RAID_CLASS_COLORS
	local colour = classFile and colours and colours[classFile]
	if colour then
		return colour.r, colour.g, colour.b
	end
	return 1, 1, 1
end

-- The two sides, and the third that is not one
--
-- A member whose side was never recorded still has to go somewhere, and it must not be into
-- either of the real ones. Named rather than left as nil so it can be a table key.
--
-- Here rather than in the panel that wanted them first, because two panels group by side now
-- - the summary's rows and the whole family's gear - and a second copy of the colours is how
-- the two come to disagree about which red Horde is.
UI.UNKNOWN_SIDE = "?"

UI.SIDE_ORDER = { Alliance = 1, Horde = 2, [UI.UNKNOWN_SIDE] = 3 }

-- The game's own two colours, and a grey for the side nobody knows.
UI.SIDE_COLOUR = {
	Alliance            = { 0.40, 0.60, 1.00 },
	Horde               = { 1.00, 0.30, 0.30 },
	[UI.UNKNOWN_SIDE]   = { 0.70, 0.70, 0.70 },
}

-- What the game calls this side, in whatever language it is running in. Family stores the
-- English word because that is what the client answers with; nothing shows it to a player
-- without coming through here first.
-- What the game calls this race, in the language the reader is running.
--
-- The whole of the answer is in Family:RaceName (Races.lua), because the data layer is where
-- the table lives and two panels asking the same question must not be able to disagree about
-- it. Left here is the last resort: the file string is not a word the game shows anybody -
-- the undead are "Scourge" in it and "Undead" on their own character sheet - so it beats a
-- blank and nothing else.
function UI:RaceName(meta)
	if not meta then return self.UNKNOWN end
	return Family:RaceName(meta) or meta.raceFile or self.UNKNOWN
end

function UI:SideName(side)
	return _G["FACTION_" .. tostring(side):upper()] or side
end

-- "3 days ago", and never "0 seconds ago". Anything under a minute is now, as far as a
-- player is concerned.
-- The other direction: "in 6h", for something that has not happened yet. Ago and In are the
-- same arithmetic and are kept apart because "3 days ago" and "in 3 days" are not the same
-- fact and must never be able to be confused for one another.
function UI:In(stamp)
	if not stamp then return L["|cff9d9d9dnever|r"] end

	local seconds = stamp - time()
	if seconds <= 0 then return L["now"] end

	if seconds < 3600 then return string.format(L["in %dm"], math.floor(seconds / 60)) end
	if seconds < 86400 then return string.format(L["in %dh"], math.floor(seconds / 3600)) end
	return string.format(L["in %dd"], math.floor(seconds / 86400))
end

function UI:Ago(stamp)
	if not stamp then return L["|cff9d9d9dnever|r"] end

	local seconds = time() - stamp
	if seconds < 60 then return L["just now"] end

	-- Abbreviated units on purpose, and down to one letter each. "5 minutes ago" needs one
	-- plural in English, two in German and three in Russian; "5m" needs none in any of
	-- them, and a date beside a number in a narrow column is not the place to be teaching
	-- declension. "19 days ago" was still wide enough to be cut to "19 days a..." in the
	-- activity row, in English, which is the language every width here was measured in.
	--
	-- The same units the other direction uses, deliberately: "in 6h" and "6h ago" are the
	-- one arithmetic said twice and a reader should not have to learn two scales.
	if seconds < 3600 then
		return string.format(L["%dm ago"], math.floor(seconds / 60))
	end
	if seconds < 86400 then
		return string.format(L["%dh ago"], math.floor(seconds / 3600))
	end

	local days = math.floor(seconds / 86400)
	if days == 1 then return L["yesterday"] end
	return string.format(L["%dd ago"], days)
end
