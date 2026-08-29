-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Choosing which member a panel is about.
--
-- Every screen that shows one member at a time needs this, which is the whole argument for
-- it being one control rather than four. The talent panel had a pair of arrows; reaching the
-- fortieth member through them takes thirty-nine clicks, and the specification (§4.3) asks
-- for a searchable list for exactly that reason.
--
-- Typing filters. Members are grouped by realm, because an account spread over several is
-- the normal case, and a name alone does not say which realm it is on.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 16
local LIST_HEIGHT = 260
local LIST_WIDTH = 220

-- Air above a heading, so that a section starts rather than merely continues. Every row was
-- the same height including the headings, which put "shared by ..." hard against the last
-- name of the realm above it and read as one more member with a strange name.
local HEADING_GAP = 6

--------------------------------------------------------------------------------------------
-- The popup, of which there is exactly one, reused by whichever picker opened it
--
-- One list shared between pickers rather than one each: two open at once would be two ways
-- to answer the same question, and closing them all when the window closes is then a single
-- thing to remember.
--------------------------------------------------------------------------------------------

local popup, activePicker

local function buildPopup()
	if popup then return popup end

	popup = CreateFrame("Frame", "FamilyMemberPickerList", UIParent,
		"TooltipBorderedFrameTemplate")
	popup:SetSize(LIST_WIDTH, LIST_HEIGHT)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:EnableMouse(true)
	popup:Hide()

	-- The bordered template draws an edge and, on these clients, nothing solid behind it:
	-- the panel underneath read straight through the list, so a member's name sat on top of
	-- a recipe's and neither could be made out. This is an opaque fill of our own rather
	-- than a reliance on whatever the template happens to paint, because what a template
	-- paints differs between these clients and is the one thing here that cannot be probed -
	-- the client echoes back whatever texture path it was handed, whether or not it drew it.
	--
	-- Behind everything else in the frame: BACKGROUND layer at the lowest sub-level, so the
	-- rows' own hover highlight still shows over it.
	local fill = popup:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetAllPoints()
	fill:SetColorTexture(0, 0, 0, 0.95)

	local search = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
	search:SetPoint("TOPLEFT", 12, -10)
	search:SetPoint("TOPRIGHT", -10, -10)
	search:SetHeight(18)
	search:SetAutoFocus(true)
	popup.search = search

	local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -4, -8)
	scroll:SetPoint("BOTTOMRIGHT", -26, 8)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	popup.scroll, popup.list, popup.rows = scroll, list, {}

	search:SetScript("OnTextChanged", function() popup:Rebuild() end)
	search:SetScript("OnEscapePressed", function() popup:Hide() end)

	-- Enter takes the first thing still showing, so a name typed in full needs no click.
	search:SetScript("OnEnterPressed", function()
		if popup.firstMatch and activePicker then
			activePicker:Select(popup.firstMatch)
		end
		popup:Hide()
	end)

	popup:SetScript("OnHide", function()
		search:SetText("")
		activePicker = nil
	end)

	-- After every SetScript on this frame, and not before one: hooking adds a handler to
	-- what is there, and a SetScript afterwards throws away what is there - hook included.
	UI:DismissOnClickOutside(popup)

	function popup:Rebuild()
		local picker = activePicker
		if not picker then return end

		local needle = (self.search:GetText() or ""):lower()
		local members = picker:Members()

		-- Grouped by realm and by faction, and each group only appears if something under
		-- it survived the filter - a heading with nothing beneath it is noise.
		--
		-- By faction as well as by realm because the two halves of a realm are two
		-- different games: different auction house, different mail, different everything
		-- an alt manager is asked about. Two characters on one realm on opposite sides
		-- have less to do with each other than two on different realms on the same side.
		local byRealm, realms, shared = {}, {}, {}
		for _, member in ipairs(members) do
			local name = (member.meta.name or member.key):lower()
			if needle == "" or name:find(needle, 1, true) then
				local realm = member.meta.realm or "?"
				-- A member can name its own heading, and one shared by a linked family
				-- does: the realm is a fact about them, and whose they are is the fact
				-- that decides what this panel is able to say about them.
				local group = member.group or (member.meta.faction
					and (realm .. "  |cff888888" .. member.meta.faction .. "|r")
					or realm)

				if not byRealm[group] then
					byRealm[group] = {}
					realms[#realms + 1] = group
					shared[group] = member.group ~= nil
				end
				table.insert(byRealm[group], member)
			end
		end

		-- Our own realms first and in order, then the linked families. Sorted purely by
		-- name a family called "Ardent" would land between two of our realms, which reads
		-- as a realm we had forgotten about.
		table.sort(realms, function(a, b)
			if (shared[a] or false) ~= (shared[b] or false) then return shared[b] end
			return a < b
		end)

		local used, y = 0, 0
		self.firstMatch = nil
		self.list:SetWidth(UI:ListWidth(self.scroll))

		local function nextRow()
			used = used + 1
			local row = self.rows[used]
			if not row then
				row = CreateFrame("Button", nil, self.list)
				row:SetHeight(ROW)
				row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
				row.text:SetPoint("LEFT", 4, 0)
				row.text:SetJustifyH("LEFT")

				row.highlight = row:CreateTexture(nil, "BACKGROUND")
				row.highlight:SetAllPoints()
				row.highlight:SetColorTexture(1, 1, 1, 0.10)
				row.highlight:Hide()
				row:SetScript("OnEnter", function(self) self.highlight:Show() end)
				row:SetScript("OnLeave", function(self) self.highlight:Hide() end)

				self.rows[used] = row
			end
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetPoint("TOPRIGHT", 0, -y)
			row.text:SetWidth(LIST_WIDTH - 40)
			row:Show()
			y = y + ROW
			return row
		end

		for index, realm in ipairs(realms) do
			-- Above every heading but the first, which has the search box above it and
			-- needs no separating from anything.
			if index > 1 then y = y + HEADING_GAP end

			local heading = nextRow()
			heading.text:SetText("|cff8888ff" .. realm .. "|r")
			heading:SetScript("OnClick", nil)
			heading:Disable()

			table.sort(byRealm[realm], function(a, b)
				return (a.meta.name or a.key) < (b.meta.name or b.key)
			end)

			for _, member in ipairs(byRealm[realm]) do
				self.firstMatch = self.firstMatch or member

				local row = nextRow()
				row:Enable()
				local r, g, b = UI:ClassColour(member.meta.classFile)
				row.text:SetText(string.format("  |cff%02x%02x%02x%s|r  |cff777777%s|r",
					r * 255, g * 255, b * 255,
					member.meta.name or member.key,
					member.meta.level and tostring(member.meta.level) or ""))
				row:SetScript("OnClick", function()
					if activePicker then activePicker:Select(member) end
					popup:Hide()
				end)
			end
		end

		for index = used + 1, #self.rows do self.rows[index]:Hide() end
		self.list:SetHeight(math.max(y, 1))

		if used == 0 then
			local row = nextRow()
			row:Disable()
			row.text:SetText(L["|cff9d9d9dnobody matches|r"])
		end
	end

	return popup
end

--------------------------------------------------------------------------------------------
-- A picker
--------------------------------------------------------------------------------------------

-- Every picker there is, so that a new session can put all of them back to the member being
-- played. A panel is built once and kept, and a choice made by hand is meant to stand - but
-- only until the character logging in changes, at which point the answer to "who is this
-- panel about" has changed with it.
local pickers = {}

Family:OnDatabaseReady("ui.pickers", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "ui.pickers", function()
		for _, picker in ipairs(pickers) do
			picker.chosen, picker.selected = nil, nil
		end
	end)
end)

-- provider is a function returning the list this picker may choose from, each entry being
-- { key = , meta = , ... }. Panels differ in what they can show, so each says for itself.
function UI:CreateMemberPicker(parent, width, provider, onSelect)
	local picker = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	picker:SetSize(width or 200, 22)

	pickers[#pickers + 1] = picker

	picker.provider = provider
	picker.onSelect = onSelect

	function picker:Members()
		return self.provider() or {}
	end

	function picker:Selected()
		return self.selected
	end

	function picker:Select(member)
		self.selected = member
		-- Chosen by hand, which is what makes it stick. A selection that was merely
		-- defaulted to is not the same thing and does not.
		self.chosen = true
		self:Redraw()
		if self.onSelect then self.onSelect(member) end
	end

	-- Keeps the selection if that member is still available, otherwise falls back - and
	-- answers nil rather than inventing a member when the list is empty.
	function picker:Reconcile()
		local members = self:Members()
		if #members == 0 then
			self.selected = nil
			self:Redraw()
			return nil
		end

		-- Only a member picked by hand stands. One that was merely defaulted to gives way
		-- as soon as the character being played turns up in the list - which on a fresh
		-- login is usually a few seconds after the panel was first drawn, since that
		-- member has not been scanned into it yet. Without this, a panel opened during
		-- those seconds kept whoever it settled on for the rest of the session, and the
		-- effect was of a filter that remembered the wrong character across logins.
		if self.chosen and self.selected then
			for _, member in ipairs(members) do
				if member.key == self.selected.key then
					self.selected = member
					self:Redraw()
					return member
				end
			end
		end

		-- Nothing chosen yet: the character being played, if this panel has anything to
		-- show for them. Family is opened from a character and usually about that
		-- character, and a panel that lands on whoever happens to sort first made every
		-- one of them cost a pick before it said anything useful.
		--
		-- Only as a default. Once a member has been chosen the choice stands, including
		-- across a trip to another tab and back: overriding it on every redraw would make
		-- the control unusable for the thing it is actually for, which is looking at
		-- somebody else.
		local playing = Family:CurrentMember()
		for _, member in ipairs(members) do
			if member.key == playing then
				self.selected = member
				self:Redraw()
				return member
			end
		end

		self.selected = members[1]
		self:Redraw()
		return self.selected
	end

	function picker:Redraw()
		local member = self.selected
		if not member then
			self:SetText(L["|cff9d9d9d(nobody)|r"])
			return
		end
		local r, g, b = UI:ClassColour(member.meta.classFile)
		self:SetText(string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255,
			member.meta.name or member.key))
	end

	picker:SetScript("OnClick", function(self)
		local list = buildPopup()

		if list:IsShown() and activePicker == self then
			list:Hide()
			return
		end

		activePicker = self
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		list:Show()
		list.search:SetText("")
		list:Rebuild()
	end)

	picker:Redraw()
	return picker
end

-- Closing the window must take the list with it, or it is left hanging over the game with
-- nothing behind it.
function UI:CloseMemberPickers()
	if popup then popup:Hide() end
end
