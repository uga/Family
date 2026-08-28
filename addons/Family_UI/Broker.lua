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

local function summary()
	local members, money = 0, 0
	local needsAttention = 0

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		members = members + 1
		money = money + (meta.money or 0)

		-- Mail about to be destroyed is the one thing worth saying on a minimap button,
		-- because it is the one thing that gets worse while you are not looking.
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

-- A tooltip has two columns and no more, so level and item level ride with the name on the
-- left and money holds the right on its own. That is the one column where alignment earns
-- anything: a column of gold amounts is read by comparing lengths, and the rest is not.
local function describe(tooltip)
	local order, realms = byRealm()
	local _, total, needsAttention = summary()

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

				for _, member in ipairs(group.members) do drawMember(member, "    ") end
			end
		else
			for _, member in ipairs(here.members) do drawMember(member, "") end
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

	tooltip:AddLine(" ")
	tooltip:AddLine(L["|cff888888Left-click for the family. Right-click for the options.|r"])
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

-- Off is a setting rather than a removal, so turning it back on does not need a reload.
function UI:SetMinimapShown(shown)
	FamilyDB.ui = FamilyDB.ui or {}
	FamilyDB.ui.minimap = shown and true or false

	if minimapButton then
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

	minimapButton = createMinimapButton()
	UI.minimapButton = minimapButton

	place(FamilyDB.ui.minimapAngle or 200)
	if minimapButton then
		minimapButton:SetShown(UI:IsMinimapShown())
	end
end)
