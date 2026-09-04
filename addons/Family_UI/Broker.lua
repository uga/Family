-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Two ways to open Family without typing anything: a broker object for the display addons,
-- and a button on the minimap for everyone else.
--
-- They share a summary and a click, because they are the same thing in two housings, and
-- keeping the text in one place is what stops the two disagreeing about how much money the
-- family has.
--
-- The minimap button is written here rather than taken from a library. It needs to sit on a
-- circle, be dragged around it and remember where it was left, which is eighty lines - and a
-- dependency that has to be fetched before the addon will load is a poor trade for that.
--
-- It is handed over to LibDBIcon when the player already has it, for the reasons at that
-- section below. Used, never shipped: nothing here is fetched at package time and the .toc
-- loads nothing new.

local _, UI = ...

local Family = _G.Family
local L = Family.L

-- Family's own, rather than one of the game's.
--
-- Three linked nodes: two members and the one above them. It is a family tree with the
-- detail taken out, which is as much as survives at the sixteen pixels a broker bar gives
-- it. tools/GenerateIcon.py draws it and says why it is drawn the way it is; a texture that
-- can be regenerated from readable source is a texture anybody can change.
--
-- Borrowing one of the game's icons was what came before, and the trouble with that is that
-- it is somebody else's: INV_Misc_GroupLooking is the icon on the dungeon finder and on
-- every other addon that reached for the same obvious file.
local ICON = "Interface\\AddOns\\Family_UI\\Textures\\Family.tga"
local RADIUS = 80

--------------------------------------------------------------------------------------------
-- What both of them say
--------------------------------------------------------------------------------------------

-- How much of the family the bar is counting.
--
-- **All of it is not always the useful answer.** The tooltip below already sets out why: an
-- Alliance member and a Horde member on one realm share nothing but the realm - not a bank, not
-- a mailbox, not an auction house - so a grand total across every realm is a number nobody can
-- spend. What one *can* spend is what this side of this realm holds between them, and what is
-- in this character's own pocket.
--
-- Three, not two, because the total this shipped with is somebody's answer already and taking
-- it away would be answering a question nobody asked.
local SCOPES = { "all", "realm", "character" }

function UI:BrokerScope()
	local wanted = FamilyDB and FamilyDB.ui and FamilyDB.ui.brokerScope
	for _, scope in ipairs(SCOPES) do
		if scope == wanted then return scope end
	end
	return SCOPES[1]
end

function UI:CycleBrokerScope()
	local now = self:BrokerScope()
	local at = 1
	for index, scope in ipairs(SCOPES) do
		if scope == now then at = index end
	end

	if FamilyDB then
		FamilyDB.ui = FamilyDB.ui or {}
		FamilyDB.ui.brokerScope = SCOPES[(at % #SCOPES) + 1]
	end

	self:UpdateBroker()
	return self:BrokerScope()
end

-- Whether one member is inside the scope on show.
--
-- Both halves of "this realm" are asked, because the realm alone is not the pool: two sides on
-- one realm are two families that cannot pass each other a copper.
local function inScope(scope, key, meta)
	if scope == "all" then return true end
	if scope == "character" then return key == Family:CurrentMember() end

	local mine = Family.Database:Members()[Family:CurrentMember()]
	local ours = (mine and mine.meta) or {}
	return meta.realm == ours.realm and meta.faction == ours.faction
end

local function summary()
	local members, money = 0, 0
	local needsAttention = 0
	local scope = UI:BrokerScope()

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}

		-- Counted together, so the two numbers on the bar always describe one another:
		-- "15 members, 4200g" is a sentence and "29 members, 4200g" is a puzzle.
		if inScope(scope, key, meta) then
			members = members + 1
			money = money + (meta.money or 0)
		end

		-- Mail about to be destroyed is the one thing worth saying on a minimap button,
		-- because it is the one thing that gets worse while you are not looking.
		-- Deliberately outside the scope test above. Mail rotting on a character three
		-- realms away is exactly the thing somebody is not looking at, and narrowing what
		-- the bar counts must not narrow what it warns about.
		local remaining = Family.Mail:TimeToExpiry(meta)
		if remaining and remaining < 3 * 86400 then
			needsAttention = needsAttention + 1
		end
	end

	return members, money, needsAttention
end

-- Members grouped by realm, and by side within each realm, with what each is worth.
--
-- The same shape the summary uses, and for the same reason: an Alliance member and a Horde
-- member on one realm share nothing but the realm - not a bank, not a mailbox, not an
-- auction house - so a single list of them reads as one pool of characters that could pass
-- things between them, which is exactly what they cannot do.
--
-- The tooltip's two columns carry it without extra rows: the side names itself on the left
-- and its own money sits on the right, the same way the realm line above it is drawn.
local function byRealm()
	local realms, order = {}, {}

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		local realm = meta.realm or "?"
		local side = meta.faction or UI.UNKNOWN_SIDE

		local here = realms[realm]
		if not here then
			here = { members = {}, money = 0, bySide = {}, sides = {} }
			realms[realm] = here
			order[#order + 1] = realm
		end

		local group = here.bySide[side]
		if not group then
			group = { members = {}, money = 0 }
			here.bySide[side] = group
			here.sides[#here.sides + 1] = side
		end

		local member = { key = key, meta = meta }
		table.insert(here.members, member)
		table.insert(group.members, member)
		here.money = here.money + (meta.money or 0)
		group.money = group.money + (meta.money or 0)
	end

	local function highestFirst(a, b)
		local levelA, levelB = a.meta.level or 0, b.meta.level or 0
		if levelA ~= levelB then return levelA > levelB end
		return (a.meta.name or "") < (b.meta.name or "")
	end

	for _, here in pairs(realms) do
		table.sort(here.members, highestFirst)
		for _, group in pairs(here.bySide) do table.sort(group.members, highestFirst) end

		-- Alliance, then Horde, then anybody whose side was never recorded.
		table.sort(here.sides, function(a, b)
			return (UI.SIDE_ORDER[a] or 99) < (UI.SIDE_ORDER[b] or 99)
		end)
	end

	table.sort(order)
	return order, realms
end

-- Whether a realm is worth splitting is decided by its *known* sides. A member whose side
-- has never been read is not a third faction - they are a member Family has not finished
-- reading - and letting them force the split would put a heading over a realm that has only
-- one side on it because one character has not been logged into yet.
local function knownSides(here)
	local known = 0
	for _, side in ipairs(here.sides) do
		if side ~= UI.UNKNOWN_SIDE then known = known + 1 end
	end
	return known
end

-- How many lines this screen has room for.
--
-- A tooltip does not scroll and is not clipped politely: a family of thirty runs off the top
-- and the bottom at once, and what goes off the bottom is the grand total and the warnings -
-- the answers, while the detail survives. Reported with a screenshot of exactly that.
--
-- Derived rather than chosen. A constant that fits one screen is wrong on a laptop at 0.8 UI
-- scale and wasteful on a tall one, and the client knows the height of its own screen and the
-- size of its own font. Nine tenths, because a tooltip anchored to a minimap button does not
-- start at the top of the screen.
local MINIMUM_ROWS = 6
local SAFE_FRACTION = 0.9
local FALLBACK_FONT = 12
local LINE_PADDING = 2.5

local function rowsOnScreen()
	local parent = _G.UIParent
	local height = tonumber((Family:TryCall(parent and parent.GetHeight, parent))) or 768

	local font = _G.GameTooltipText
	local size = font and select(2, Family:TryCall(font.GetFont, font))
	local line = (tonumber(size) or FALLBACK_FONT) + LINE_PADDING

	return math.max(math.floor(height * SAFE_FRACTION / line), MINIMUM_ROWS)
end

-- A tooltip has two columns and no more, so level and item level ride with the name on the
-- left and money holds the right on its own. That is the one column where alignment earns
-- anything: a column of gold amounts is read by comparing lengths, and the rest is not.
local function describe(tooltip)
	local order, realms = byRealm()
	local _, _, needsAttention = summary()

	-- The tooltip's own total, added up from the realms it has just listed.
	--
	-- It used to come from `summary`, which narrows to whatever the bar is counting - so with
	-- the scope set to one character the tooltip listed every member of every realm and then
	-- footed the column with that one character's gold. The realms added to 7794g and the
	-- line under them said 1192g. Reported from a screenshot, and it was in 1.2.0.
	--
	-- The tooltip is the whole-family view and stays that way; it is the **bar** that narrows,
	-- and the line near the bottom saying what the bar is counting is what explains the
	-- difference. A document that disagrees with itself is worse than either choice.
	local total = 0
	for _, realm in ipairs(order) do total = total + realms[realm].money end

	tooltip:AddLine(L["Family"])

	if #order == 0 then
		tooltip:AddLine(L["|cff9d9d9dNothing recorded yet.|r"])
		return
	end

	-- The two numbers beside each name are unlabelled and have to be: a tooltip has two
	-- columns and these three things share one of them. So one line says which is which,
	-- once, at the top. The money column labels itself by being money, and is named here
	-- only because a heading over one of two columns reads as though the other has none.
	tooltip:AddDoubleLine(L["|cff888888name, level, item level|r"], L["|cff888888money|r"])

	-- What actually carries member rows: one group per faction where a realm is split, one
	-- per realm where it is not. Everything else on this tooltip is structure, and structure
	-- is what must never be the thing that falls off the screen.
	local groups = {}
	for _, realm in ipairs(order) do
		local here = realms[realm]
		if knownSides(here) > 1 then
			for _, side in ipairs(here.sides) do
				groups[#groups + 1] = { realm = realm, list = here.bySide[side].members,
					money = here.bySide[side].money }
			end
		else
			groups[#groups + 1] = { realm = realm, list = here.members, money = here.money }
		end
	end

	-- Counted, not guessed. Every one of these is a row this function is about to draw, and
	-- the conditions are the same ones the code below tests.
	local structure = 2
	for _, realm in ipairs(order) do
		structure = structure + 2
		if knownSides(realms[realm]) > 1 then
			structure = structure + #realms[realm].sides
		end
	end
	structure = structure + #groups                          -- one "and N more" apiece, at worst
	if #order > 1 then structure = structure + 2 end         -- the grand total
	if #Family.Cooldowns:Ready() > 0 then structure = structure + 2 end
	if needsAttention > 0 then structure = structure + 2 end
	if UI:BrokerScope() ~= "all" then structure = structure + 2 end
	structure = structure + 2                                -- the footer

	local members = 0
	for _, group in ipairs(groups) do members = members + #group.list end

	local budget = rowsOnScreen() - structure
	local trimming = members > budget

	-- Nothing changes at all for a family that fits, which is nearly everybody: same order,
	-- same rows, same tooltip. The trimming below is a second mode and not a new default.
	local take = {}
	if trimming then
		-- Richest first, and only while trimming. On a tooltip whose subject is money, the
		-- characters worth keeping are the ones the number is mostly about - and listing them
		-- in that order is what makes it obvious why those are the ones that stayed.
		local function richestFirst(a, b)
			local moneyA, moneyB = a.meta.money or 0, b.meta.money or 0
			if moneyA ~= moneyB then return moneyA > moneyB end
			return (a.meta.name or "") < (b.meta.name or "")
		end
		for _, group in ipairs(groups) do table.sort(group.list, richestFirst) end

		-- The realm you are standing on is served first and in full if it fits: it is the one
		-- whose gold you can actually spend today, which is the argument the money scope
		-- already makes. The rest take what is left, richest group first.
		local ours = Family.Database:Members()[Family:CurrentMember()]
		local home = ours and ours.meta and ours.meta.realm

		local queue = {}
		for _, group in ipairs(groups) do queue[#queue + 1] = group end
		table.sort(queue, function(a, b)
			local mineA = (a.realm == home) and 1 or 0
			local mineB = (b.realm == home) and 1 or 0
			if mineA ~= mineB then return mineA > mineB end
			if a.money ~= b.money then return a.money > b.money end
			return tostring(a.realm) < tostring(b.realm)
		end)

		local left = budget
		for _, group in ipairs(queue) do
			local room = math.max(math.min(#group.list, left), 0)
			take[group.list] = room
			left = left - room
		end
	end

	local function drawMember(member, indent)
		local meta = member.meta
		local r, g, b = UI:ClassColour(meta.classFile)

		-- Both slots or neither. With one number printed and the other left out,
		-- there is nothing on the line to say which of the two it was - and a
		-- member whose gear has never been read is exactly the member whose level
		-- would then be mistaken for an item level. A dash says "not known", which
		-- is the answer (§2.2), and keeps the two columns where the heading says.
		local detail = ""
		if meta.level or meta.itemLevel then
			detail = string.format("|cff888888  %s  %s|r",
				meta.level and tostring(meta.level) or "-",
				meta.itemLevel and string.format("%.0f", meta.itemLevel) or "-")
		end

		tooltip:AddDoubleLine(indent .. (meta.name or member.key) .. detail,
			UI:Money(meta.money), r, g, b, 1, 1, 1)
	end

	-- Whatever room this group was given, and a line saying what was left out. A family that
	-- is quietly shown as smaller than it is would be worse than one that does not fit.
	local function drawGroup(list, indent)
		local limit = take[list] or #list
		if limit > #list then limit = #list end

		for index = 1, limit do drawMember(list[index], indent) end

		if limit < #list then
			tooltip:AddLine(indent .. string.format(L["|cff888888and %d more|r"],
				#list - limit))
		end
	end

	for _, realm in ipairs(order) do
		local here = realms[realm]

		tooltip:AddLine(" ")
		tooltip:AddDoubleLine("|cff88bbff" .. realm .. "|r", UI:Money(here.money))

		if knownSides(here) > 1 then
			for _, side in ipairs(here.sides) do
				local group = here.bySide[side]
				local colour = UI.SIDE_COLOUR[side] or { 0.7, 0.7, 0.7 }

				tooltip:AddDoubleLine(
					string.format(L["  %s |cff888888(%d)|r"],
						UI:SideName(side), #group.members),
					UI:Money(group.money),
					colour[1], colour[2], colour[3], 0.8, 0.8, 0.8)

				drawGroup(group.members, "    ")
			end
		else
			drawGroup(here.members, "")
		end
	end

	-- Only worth printing when there is more than one realm to add up; with one realm the
	-- grand total is the realm total, written twice.
	if #order > 1 then
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["|cffffd700All realms|r"], UI:Money(total))
	end

	-- What is ready now. The one thing on this tooltip that changes while nobody is looking,
	-- which is what makes it worth putting where it will be seen without being asked for.
	local waiting = Family.Cooldowns:Ready()
	if #waiting > 0 then
		local names = {}
		for _, member in ipairs(waiting) do
			names[#names + 1] = member.count > 1
				and string.format("%s (%d)", member.name, member.count) or member.name
		end

		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["|cff40bf40Crafting cooldowns ready|r"],
			"|cff888888" .. table.concat(names, ", ") .. "|r")
	end

	if needsAttention > 0 then
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["|cffff4444Mail expiring soon|r"],
			string.format(needsAttention == 1 and L["%d member"] or L["%d members"],
				needsAttention))
	end

	-- What the bar itself is counting, said where somebody will read it.
	--
	-- A number that quietly means something else is worse than no number: middle-click once by
	-- accident and the money on the bar drops, with nothing anywhere to say why. So the scope
	-- is named on hover whenever it is not the whole family, and the way back is named with it.
	local scope = UI:BrokerScope()
	if scope ~= "all" then
		local mine = Family.Database:Members()[Family:CurrentMember()]
		local ours = (mine and mine.meta) or {}

		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["|cff888888the bar is counting|r"],
			scope == "character" and (ours.name or L["this character"])
				or string.format("%s |cff888888(%s)|r", tostring(ours.realm or "?"),
					tostring(ours.faction or UI.UNKNOWN_SIDE)))
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(L["|cff888888Left-click for the family. Right-click for the options. "
		.. "Shift-click to change what the money counts.|r"])
end

-- Each click goes to a fixed place rather than to wherever the window was left.
--
-- Toggling was the obvious way and produced a small trap: right-click put the window on the
-- options, and the next left-click - advertised as opening Family - reopened it on the
-- options, because that was the last tab shown. A button on the minimap is an entry point,
-- and an entry point that lands somewhere different depending on what you did last is not
-- one. So left is always the summary and right is always the options, and clicking for where
-- you already are closes the window.
local function onClick(button)
	-- Shift and the left button change what the money is counting, and so does the middle
	-- button on a mouse that has one.
	--
	-- Not the money's own click: a broker bar is one label and its display hands the whole of
	-- it to one handler, so there is no "on the money" to click on. Plain left and right are
	-- already the two panels.
	--
	-- **Shift-left is the one that is named**, because a middle button is not a thing everybody
	-- has - a trackpad often has two - and an action reachable only by hardware some people
	-- lack is an action those people do not have. The middle button stays because it costs one
	-- comparison and some hands prefer it.
	if button == "MiddleButton" or (IsShiftKeyDown and IsShiftKeyDown()) then
		UI:CycleBrokerScope()
		return
	end

	local wanted = (button == "RightButton") and "options" or "summary"

	if UI:IsShown() and UI:CurrentTab() == wanted then
		UI:Hide()
		return
	end

	UI:Show()
	UI:ShowTab(wanted)
end

--------------------------------------------------------------------------------------------
-- The broker object
--
-- Optional, like the compression libraries: if nothing in the game provides LibDataBroker
-- there is nothing to register with, and Family carries on with its own button.
--------------------------------------------------------------------------------------------

local function createBroker()
	if not LibStub then return nil end

	local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
	if not ldb then return nil end

	local object = ldb:NewDataObject("Family", {
		type = "data source",
		label = "Family",
		text = "Family",
		icon = ICON,
		OnClick = function(_, button) onClick(button) end,
		OnTooltipShow = describe,
	})

	return object
end

function UI:UpdateBroker()
	if not self.broker then return end

	local members, money = summary()
	self.broker.text = string.format("%d  %s", members, UI:Money(money))
end

--------------------------------------------------------------------------------------------
-- The minimap button
--------------------------------------------------------------------------------------------

local minimapButton

local function place(angle)
	if not minimapButton then return end

	local radians = math.rad(angle)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER",
		math.cos(radians) * RADIUS, math.sin(radians) * RADIUS)
end

-- Where the cursor is, as an angle around the minimap's centre. Everything is divided by the
-- effective scale because the cursor is reported in screen pixels and the frame is not.
local function angleFromCursor()
	local centreX, centreY = Minimap:GetCenter()
	if not centreX then return nil end

	local scale = Minimap:GetEffectiveScale()
	if not scale or scale == 0 then scale = 1 end

	local cursorX, cursorY = GetCursorPosition()
	cursorX, cursorY = cursorX / scale, cursorY / scale

	return math.deg(math.atan2(cursorY - centreY, cursorX - centreX))
end

local function onDragUpdate()
	local angle = angleFromCursor()
	if not angle then return end

	FamilyDB.ui.minimapAngle = angle
	place(angle)
end

local function createMinimapButton()
	if not Minimap then return nil end

	local button = CreateFrame("Button", "FamilyMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetTexture(ICON)
	-- Trimmed, the way every icon shown in a round frame is: the corners of a square are
	-- what the tracking border cuts off anyway, so giving them up buys the mark itself
	-- three or four more pixels of the twenty there are.
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("TOPLEFT", 7, -5)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	button:SetScript("OnClick", function(_, pressed) onClick(pressed) end)

	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", onDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		describe(GameTooltip)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	return button
end

--------------------------------------------------------------------------------------------
-- The collector, where the player already has one
--
-- Other addons gather minimap buttons into a bag or a bar, and what they gather is what
-- LibDBIcon registered - so a button built by hand sits outside the bag however well it
-- behaves. Reported from play, with Family named in somebody else's complaint while two
-- other addons on the same minimap were collected.
--
-- **LibDBIcon is used and never shipped**, and that is a licence decision rather than a
-- packaging convenience. Its terms forbid redistributing a stand-alone version without
-- written permission, and the LibDataBroker it requires states no licence anywhere - neither
-- can travel inside a zip that promises GPL terms to whoever receives it. Reading a library
-- that another addon has already loaded is not redistributing it, so this asks for nothing
-- and grants nothing.
--
-- **Two different addons are involved and they are easy to run together.** LibDBIcon is
-- *embedded* by most large addons for their own icon - DBM and WeakAuras both fetch it and
-- LibDataBroker as externals, which is how it comes to be loaded in a game that never asked
-- for it. Neither of them collects anything. What collects is a third addon, the kind that
-- sweeps every LibDBIcon button into one bag, and it is the one that could not find Family.
-- So the embedders are why the library is usually *there*, and the collector is who this is
-- *for*; a player with neither keeps the button above, which is why that button stays.
--------------------------------------------------------------------------------------------

local collector

-- Hand the broker object over, and say whether it was taken.
--
-- The saved table is ours to fill. `minimapPos` is an angle in degrees, which is the unit our
-- own button has been writing all along, so seeding it from `minimapAngle` leaves the button
-- where the player put it instead of at the library's default. `hide` is how it is asked to
-- stay away, and it has to be written as well as read or the setting would not survive a
-- logout.
--
-- Nothing is assumed about what was found under that name. A library is whatever the game
-- handed back, so the two methods used here are checked for before either is called - §2.3
-- pointed at another addon rather than at the client.
function UI:GiveButtonToCollector(dbicon, object)
	if not dbicon or not object then return false end
	if type(dbicon.Register) ~= "function" or type(dbicon.IsRegistered) ~= "function" then
		return false
	end

	FamilyDB.ui.minimapIcon = FamilyDB.ui.minimapIcon or {}
	local saved = FamilyDB.ui.minimapIcon

	if saved.minimapPos == nil then saved.minimapPos = FamilyDB.ui.minimapAngle end
	saved.hide = not UI:IsMinimapShown()

	if not dbicon:IsRegistered("Family") then
		dbicon:Register("Family", object, saved)
	end

	collector = dbicon

	-- Two buttons on one minimap is worse than the wrong one of them.
	if minimapButton then minimapButton:Hide() end

	return true
end

-- What login decides about the button, in one function, so that the harness can put a
-- collector in front of the real decision rather than in front of a copy of it.
function UI:BuildMinimapButton()
	local dbicon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
	if UI:GiveButtonToCollector(dbicon, UI.broker) then return "collector" end

	minimapButton = minimapButton or createMinimapButton()
	UI.minimapButton = minimapButton
	if not minimapButton then return nil end

	place(FamilyDB.ui.minimapAngle or 200)
	minimapButton:SetShown(UI:IsMinimapShown())
	return "own"
end

-- Off is a setting rather than a removal, so turning it back on does not need a reload.
function UI:SetMinimapShown(shown)
	FamilyDB.ui = FamilyDB.ui or {}
	FamilyDB.ui.minimap = shown and true or false

	if collector then
		FamilyDB.ui.minimapIcon = FamilyDB.ui.minimapIcon or {}
		FamilyDB.ui.minimapIcon.hide = not FamilyDB.ui.minimap

		if FamilyDB.ui.minimap then
			collector:Show("Family")
		else
			collector:Hide("Family")
		end
	elseif minimapButton then
		minimapButton:SetShown(FamilyDB.ui.minimap)
	end
end

function UI:IsMinimapShown()
	return not (FamilyDB.ui and FamilyDB.ui.minimap == false)
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("broker", function()
	FamilyDB.ui = FamilyDB.ui or {}

	UI.broker = createBroker()
	UI:UpdateBroker()

	-- The one number on screen that nobody asked to see, and the only one that was never
	-- brought up to date. The tooltip is built fresh on every hover and the summary redraws
	-- itself when the database says something changed, so the bar sat there saying what was
	-- true at login and disagreeing with both of them by however much the player had spent.
	--
	-- Not the panels' watcher, which returns early while the window is closed: the bar has
	-- no closed state and cannot wait to be reopened. Nor is it deferred the way that one
	-- is - what a panel does on a change is redraw every row it has, and what this does is
	-- add up forty numbers and format one string.
	Family.Database:OnChanged("broker", function() UI:UpdateBroker() end)

	UI:BuildMinimapButton()
end)
