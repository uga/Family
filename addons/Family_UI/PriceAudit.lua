-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- **Every auction price Family has collected, where somebody can look at it.** Backlog 81.
--
-- Asked for 2026-09-15, from play on Mists: two members' Worth came to a million gold each, and
-- the arithmetic was right. A couple of items had been read at a price somebody - a player or a
-- bot - listed far above the market, and nothing cheaper was up that visit to beat it. There is
-- no preventing that; there can be a place to find it and put it right.
--
-- Alberto's answers, the same day: **on the Extras page**; **every market in one list**, with a
-- filter for one at a time; **sorted by price**; a price can be **deleted**, and an item **banned**
-- per market, which clears the price it already has and keeps it out until lifted by hand; and
-- **likely troll prices highlighted**. Which prices look wrong is the recorder's call
-- (`Auctions:Audit`), so that a probe and this panel cannot disagree about it.
--
-- **A page of rows, not a scroll of all of them.** A whole-house read of Classic Era files some
-- seven thousand prices, per market, and a frame per price would be tens of thousands of frames.
-- The rows are a fixed handful, filled from wherever the list has been moved to.

local _, UI = ...

local Family = _G.Family
local L = Family.L
local Auctions = Family.Auctions

local ROW_HEIGHT = 20
-- Nineteen: seventeen left two rows of room at the bottom of the page, seen on TBC 2026-09-15.
local PAGE_ROWS = 19
local WHEEL_ROWS = 3

-- Item, market, the price of one, the price it replaced, when it was read, then the two buttons.
-- 656 for the columns: at 680 the Ban buttons stood past the window's right edge on TBC
-- 2026-09-15, and Market and Replaced had the room to give - "Thunderstrike, Alliance" is the
-- longest a market reads, and a price of one is never wider than the column beside it.
local COLUMNS = {
	{ key = "item", label = L["Item"], width = 230, justify = "LEFT" },
	{ key = "market", label = L["Market"], width = 128, justify = "LEFT" },
	{ key = "price", label = L["Price of one"], width = 122, justify = "RIGHT" },
	{ key = "was", label = L["Replaced"], width = 110, justify = "RIGHT" },
	{ key = "seen", label = L["Seen"], width = 66, justify = "RIGHT" },
}
local BUTTON_W = 50

local function marketLabel(where)
	local realm, side = tostring(where):match("^(.-)\30(.*)$")
	if not realm then return tostring(where) end
	if side == Auctions.NEUTRAL then return string.format(L["%s, neutral"], realm) end
	return realm .. ", " .. tostring(UI:SideName(side))
end

-- The name an item is filtered by is the one already written down, never one asked for: asking
-- the client about every item in a whole house is the ten-second freeze the name store exists to
-- stop (backlog 22). An item nobody has named yet cannot be found by typing, and is still listed.
local function storedName(variant)
	local id = Family:BaseItem(variant)
	local store = Family.Names and Family.Names:ItemStore()
	return type(store) == "table" and store[id] or nil
end

function UI:BuildPriceAudit(frame)
	local rowsData, shown = {}, {}
	local offset = 0
	local wantedMarket = nil
	local ascending = false

	local panel = CreateFrame("Frame", nil, frame)
	panel:SetPoint("TOPLEFT", 0, -30)
	panel:SetPoint("BOTTOMRIGHT", 0, 0)
	panel:Hide()

	local blurb = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	blurb:SetPoint("TOPLEFT", 8, 0)
	blurb:SetPoint("TOPRIGHT", -8, 0)
	blurb:SetJustifyH("LEFT")
	if blurb.SetWordWrap then blurb:SetWordWrap(true) end
	blurb:SetText(L["Every price Family has taken from an auction house. Red is a price ten times "
		.. "or more the one it replaced, or ten times what the same item costs on the other "
		.. "markets. Deleting a price lets the next visit read a new one; banning an item clears "
		.. "its price in that market and keeps it out until the ban is lifted."])

	-- The market filter: one button that steps through every market there is, and back to all.
	local marketButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	marketButton:SetSize(220, 20)
	marketButton:SetPoint("TOPLEFT", 8, -34)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("LEFT", marketButton, "RIGHT", 16, 0)
	hint:SetText(L["filter"])

	local search = CreateFrame("EditBox", "FamilyPriceAuditSearch", panel, "InputBoxTemplate")
	search:SetPoint("LEFT", hint, "RIGHT", 10, 0)
	search:SetSize(150, 20)
	search:SetAutoFocus(false)
	UI:ReleaseFocusOnClick(search)

	local count = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	count:SetPoint("TOPRIGHT", -70, -38)
	count:SetJustifyH("RIGHT")

	local previous = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	previous:SetSize(28, 20)
	previous:SetPoint("TOPRIGHT", -38, -34)
	previous:SetText("<")

	local following = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	following:SetSize(28, 20)
	following:SetPoint("TOPRIGHT", -8, -34)
	following:SetText(">")

	-- Headings. The price heading is a button, and pressing it turns the order round.
	local x = 8
	local headings = {}
	for _, column in ipairs(COLUMNS) do
		local heading
		if column.key == "price" then
			heading = CreateFrame("Button", nil, panel)
			heading:SetSize(column.width, 18)
			heading.text = heading:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			heading.text:SetAllPoints()
			heading.text:SetJustifyH(column.justify)
			heading:SetFontString(heading.text)
		else
			heading = { text = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall") }
			heading.text:SetSize(column.width, 18)
			heading.text:SetJustifyH(column.justify)
		end
		local anchor = heading.SetPoint and heading or heading.text
		anchor:SetPoint("TOPLEFT", x + 4, -60)
		if heading.SetText then heading:SetText(column.label) else heading.text:SetText(column.label) end
		headings[column.key] = heading
		x = x + column.width
	end

	local empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	empty:SetPoint("TOPLEFT", 12, -84)
	empty:SetText(L["No auction prices collected yet."])

	-- The rows in a frame of their own. A row takes the mouse for its tooltip and spans the width,
	-- and one sharing a parent with the heading and the page buttons would sit over them.
	local body = CreateFrame("Frame", nil, panel)
	body:SetPoint("TOPLEFT", 8, -80)
	body:SetPoint("BOTTOMRIGHT", -8, 0)

	local rows = {}
	for index = 1, PAGE_ROWS do
		local row = CreateFrame("Frame", nil, body)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT", body, "RIGHT", 0, 0)

		-- **Red behind a row that looks wrong**, rather than a colour on one of its numbers:
		-- the figures are white on every row in Family, and a suspect is a fact about the row.
		row.alert = row:CreateTexture(nil, "BACKGROUND")
		row.alert:SetAllPoints()
		if row.alert.SetColorTexture then
			row.alert:SetColorTexture(0.8, 0.1, 0.1, 0.25)
		else
			row.alert:SetTexture(0.8, 0.1, 0.1, 0.25)
		end
		row.alert:Hide()

		row.cells = {}
		local cx = 0
		for c, column in ipairs(COLUMNS) do
			local cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			cell:SetPoint("LEFT", cx + 4, 0)
			cell:SetWidth(column.width - 8)
			cell:SetJustifyH(column.justify)
			if cell.SetWordWrap then cell:SetWordWrap(false) end
			row.cells[c] = cell
			cx = cx + column.width
		end

		row.forget = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.forget:SetSize(BUTTON_W, 18)
		row.forget:SetPoint("LEFT", cx + 4, 0)

		row.ban = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.ban:SetSize(BUTTON_W, 18)
		row.ban:SetPoint("LEFT", row.forget, "RIGHT", 2, 0)
		row.ban:SetText(L["Ban"])

		-- **The item's own tooltip, with the audit's reading under it.** A price is only worth
		-- judging when the thing it is for is in front of you. A suffixed variant is drawn from
		-- an item string carrying its suffix in the field `Family:ItemSuffix` reads it from, so
		-- "of the Bear" is described as the Bear and not as the plain item.
		UI:AttachTooltip(row, function(self)
			local entry = self.entry
			if not entry then return nil end
			local lines = { { "|cff66bbff" .. marketLabel(entry.market) .. "|r" } }
			if entry.banned then
				lines[#lines + 1] = { string.format(L["Banned %s"], UI:Ago(entry.banned)) }
			elseif entry.suspect == "replaced" then
				lines[#lines + 1] = { string.format(L["Ten times or more the price it replaced, %s"],
					UI:Money(entry.was)) }
			elseif entry.suspect == "markets" then
				lines[#lines + 1] = { string.format(
					L["Ten times or more what it costs on the other markets, %s"],
					UI:Money(math.floor(entry.elsewhere))) }
			end

			-- The name alone if the client will not describe the item, and the reading either way.
			local id = Family:BaseItem(entry.variant)
			local fallback = { { (Family.Names:Item(id)) } }
			local suffix = type(entry.variant) == "string"
				and tonumber(entry.variant:match(":(%-?%d+)$")) or nil
			if suffix then
				return "itemlink", string.format("item:%d:0:0:0:0:0:%d", id, suffix), fallback, nil,
					lines
			end
			return "item", id, fallback, nil, lines
		end)

		row.index = index
		rows[index] = row
	end

	local function reload()
		rowsData = Auctions:Audit()
	end

	local function markets()
		local list = Auctions:AuditMarkets()
		return list
	end

	-- **Two halves: choosing the rows, and drawing a page of them.** Refresh filters and sorts the
	-- whole store, which on a read house is thousands of prices; Draw fills nineteen rows. They
	-- were one function, and every notch of the wheel sorted 6,898 prices again to move three
	-- rows - reported as lag from TBC 2026-09-15. Moving through the list now only draws.
	panel.__rebuilds = 0

	function panel:Refresh()
		panel.__rebuilds = panel.__rebuilds + 1

		-- Which market the filter is on, said on its button; a market that has gone since it
		-- was chosen - its last price deleted - puts the filter back on all of them.
		local known = markets()
		local stillThere = false
		for _, where in ipairs(known) do
			if where == wantedMarket then stillThere = true end
		end
		if not stillThere then wantedMarket = nil end
		marketButton:SetText(wantedMarket and marketLabel(wantedMarket) or L["All markets"])

		local needle = (search:GetText() or ""):lower()
		shown = {}
		for _, entry in ipairs(rowsData) do
			if (not wantedMarket or entry.market == wantedMarket) then
				local keep = true
				if needle ~= "" then
					local name = storedName(entry.variant)
					keep = name ~= nil and name:lower():find(needle, 1, true) ~= nil
				end
				if keep then shown[#shown + 1] = entry end
			end
		end

		-- **Bans first, whatever the order**, because a ban is a thing somebody did and will
		-- come back to lift; then by the price of one, highest first unless turned round.
		table.sort(shown, function(a, b)
			if (a.banned ~= nil) ~= (b.banned ~= nil) then return a.banned ~= nil end
			if a.banned then return tostring(a.variant) < tostring(b.variant) end
			if a.p ~= b.p then
				if ascending then return a.p < b.p end
				return a.p > b.p
			end
			return tostring(a.market) .. tostring(a.variant) < tostring(b.market) .. tostring(b.variant)
		end)

		headings.price:SetText(COLUMNS[3].label .. (ascending and " ^" or " v"))
		panel:Draw()
	end

	function panel:Draw()
		local total = #shown
		if offset > math.max(total - PAGE_ROWS, 0) then offset = math.max(total - PAGE_ROWS, 0) end
		if offset < 0 then offset = 0 end

		empty:SetShown(total == 0)
		count:SetText(total == 0 and "" or string.format(L["%d-%d of %d"], offset + 1,
			math.min(offset + PAGE_ROWS, total), total))

		for index, row in ipairs(rows) do
			local entry = shown[offset + index]
			row.entry = entry
			if not entry then
				row:Hide()
			else
				local id = Family:BaseItem(entry.variant)
				local name = Family.Names:Item(id, "priceAudit" .. index, function()
					panel:Draw()
				end)
				row.cells[1]:SetText(name)
				row.cells[2]:SetText(marketLabel(entry.market))

				if entry.banned then
					row.cells[3]:SetText("|cffff5555" .. L["banned"] .. "|r")
					row.cells[4]:SetText("")
					row.cells[5]:SetText(UI:Ago(entry.banned))
					row.forget:SetText(L["Lift"])
					row.ban:Hide()
				else
					row.cells[3]:SetText(UI:Money(entry.p))
					row.cells[4]:SetText(entry.was and UI:Money(entry.was) or UI.UNKNOWN)
					row.cells[5]:SetText(UI:Ago(entry.at))
					row.forget:SetText(L["Delete"])
					row.ban:Show()
				end

				row.alert:SetShown(entry.suspect ~= nil)
				row:Show()
			end
		end
	end

	local function changed()
		reload()
		panel:Refresh()
		-- Worth on the Summary is worked out from these prices on every draw; a panel already
		-- open is told, so a deleted troll price leaves the total the moment it goes.
		if UI.Refresh then UI:Refresh() end
	end

	for index, row in ipairs(rows) do
		row.forget:SetScript("OnClick", function()
			local entry = row.entry
			if not entry then return end
			if entry.banned then
				Auctions:Unban(entry.market, entry.variant)
			else
				Auctions:Forget(entry.market, entry.variant)
			end
			changed()
		end)
		row.ban:SetScript("OnClick", function()
			local entry = row.entry
			if not entry or entry.banned then return end
			Auctions:Ban(entry.market, entry.variant)
			changed()
		end)
	end

	marketButton:SetScript("OnClick", function()
		local known = markets()
		local nextOne = nil
		if not wantedMarket then
			nextOne = known[1]
		else
			for index, where in ipairs(known) do
				if where == wantedMarket then nextOne = known[index + 1] end
			end
		end
		wantedMarket = nextOne
		offset = 0
		panel:Refresh()
	end)

	search:SetScript("OnTextChanged", function()
		offset = 0
		panel:Refresh()
	end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	headings.price:SetScript("OnClick", function()
		ascending = not ascending
		offset = 0
		panel:Refresh()
	end)

	previous:SetScript("OnClick", function()
		offset = offset - PAGE_ROWS
		panel:Draw()
	end)
	following:SetScript("OnClick", function()
		offset = offset + PAGE_ROWS
		panel:Draw()
	end)

	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta)
		offset = offset - delta * WHEEL_ROWS
		panel:Draw()
	end)

	-- Read afresh each time the view is opened, by whoever opens it rather than on OnShow: the
	-- store changes behind a closed panel with every visit to an auction house.
	function panel:Reload()
		reload()
		offset = 0
		panel:Refresh()
	end

	-- Reachable for the harness and for a probe, the way the Summary's set buttons are.
	UI.__priceAudit = panel
	return panel
end
