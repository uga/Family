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

-- **Two lines to an item**, Alberto 2026-09-15: *I'm afraid we need to dedicate 2 lines to each item
-- on that panel*, off a Mists screenshot where six figures of gold ran out of *Price of one* and
-- *Mirage Raceway, Alliance* out of Market. One line of seven columns could not hold a long item
-- name, a long realm and three money figures at once; on two, every one of them has room. Scrolling
-- is fast enough since the page stopped sorting on the wheel, so ten items a page reads well.
--
-- The first line names the thing and where it was read; the second is the reading - the price of
-- one, the price it replaced, when - and the buttons that act on it.
local ROW_HEIGHT = 34
local LINE_TWO = -17
local PAGE_ROWS = 10
local WHEEL_ROWS = 2

-- `line` and `x` place a column on its line; widths from a row of 746, the content less the margins
-- and the scroll bar. A six-figure price with its silver and copper is some 125 pixels in this font.
local COLUMNS = {
	{ key = "item", label = L["Item"], line = 1, x = 0, width = 440, justify = "LEFT" },
	{ key = "market", label = L["Market"], line = 1, x = 440, width = 300, justify = "LEFT" },
	{ key = "price", label = L["Price of one"], line = 2, x = 0, width = 160, justify = "RIGHT" },
	{ key = "was", label = L["Replaced"], line = 2, x = 160, width = 160, justify = "RIGHT" },
	{ key = "seen", label = L["Seen"], line = 2, x = 320, width = 90, justify = "RIGHT" },
}
local BUTTON_W = 60
local BAR_ROOM = 24

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

-- A flat colour, by whichever name this client has for it.
local function paintAlert(texture, r, g, b, a)
	texture.__colour = { r, g, b, a }
	if texture.SetColorTexture then
		texture:SetColorTexture(r, g, b, a)
	else
		texture:SetTexture(r, g, b, a)
	end
end

function UI:BuildPriceAudit(frame)
	local rowsData, shown = {}, {}
	local offset = 0
	local wantedMarket = nil
	local wantedCategory, wantedSub = nil, nil
	local categories = nil
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
		.. "markets. Deleting a price lets the next visit read a new one. Banning an item keeps "
		.. "its price in that market out of Worth and recipe costs, while new readings are still "
		.. "taken and shown here - lift the ban when they look right again."])

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

	-- **Suspects only**, asked for 2026-09-15 on the first look at a store of 6,898 prices: red
	-- rows are what somebody comes here for, and on a real store they are pages apart.
	local suspectsOnly = false
	local suspectsBox = CreateFrame("CheckButton", "FamilyPriceAuditSuspects", panel,
		"UICheckButtonTemplate")
	suspectsBox:SetSize(24, 24)
	suspectsBox:SetPoint("LEFT", search, "RIGHT", 12, 0)
	local suspectsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	suspectsLabel:SetPoint("LEFT", suspectsBox, "RIGHT", 2, 0)
	suspectsLabel:SetText(L["Suspects only"])

	-- **Bans only**, asked for the same day with the change to what a ban does: after reading the
	-- house again, the bans are the rows to look at, newest reading beside each, to decide which
	-- can be lifted.
	local bansOnly = false
	local bansBox = CreateFrame("CheckButton", "FamilyPriceAuditBans", panel, "UICheckButtonTemplate")
	bansBox:SetSize(24, 24)
	bansBox:SetPoint("LEFT", suspectsLabel, "RIGHT", 12, 0)
	local bansLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	bansLabel:SetPoint("LEFT", bansBox, "RIGHT", 2, 0)
	bansLabel:SetText(L["Bans only"])

	-- On the headings' line, over the buttons, where the filter row has run out of room.
	local count = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	count:SetPoint("TOPRIGHT", -8 - BAR_ROOM, -86 + LINE_TWO)
	count:SetJustifyH("RIGHT")

	-- **The auction house's categories and subcategories, in its own order** (backlog 83). Two
	-- buttons on a line of their own; each opens a list of what there is to choose from, the way
	-- the house's own sidebar reads, and the second follows the first.
	local categoryButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	categoryButton:SetSize(220, 20)
	categoryButton:SetPoint("TOPLEFT", 8, -58)

	local subButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	subButton:SetSize(220, 20)
	subButton:SetPoint("LEFT", categoryButton, "RIGHT", 8, 0)

	-- One list for both, drawn over the rows and closed by choosing or by pressing its button again.
	local menu = CreateFrame("Frame", nil, panel)
	menu:SetFrameStrata("DIALOG")
	menu:Hide()
	local menuBack = menu:CreateTexture(nil, "BACKGROUND")
	menuBack:SetAllPoints()
	paintAlert(menuBack, 0, 0, 0, 0.92)
	local menuButtons = {}
	local menuFor = nil

	local function openMenu(owner, choices, pick)
		if menu:IsShown() and menuFor == owner then
			menu:Hide()
			return
		end
		menuFor = owner
		menu:ClearAllPoints()
		menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
		menu:SetSize(220, #choices * 18 + 4)
		for index, choice in ipairs(choices) do
			local button = menuButtons[index]
			if not button then
				button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
				button:SetSize(216, 18)
				button:SetPoint("TOPLEFT", 2, -2 - (index - 1) * 18)
				menuButtons[index] = button
			end
			button:SetText(choice.label)
			button:SetScript("OnClick", function()
				menu:Hide()
				pick(choice.value)
			end)
			button:Show()
		end
		for index = #choices + 1, #menuButtons do menuButtons[index]:Hide() end
		menu:Show()
	end

	local previous = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	previous:SetSize(28, 20)
	previous:SetPoint("TOPRIGHT", -38, -34)
	previous:SetText("<")

	local following = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	following:SetSize(28, 20)
	following:SetPoint("TOPRIGHT", -8, -34)
	following:SetText(">")

	-- Headings. The price heading is a button, and pressing it turns the order round.
	local headings = {}
	for _, column in ipairs(COLUMNS) do
		local x = 8 + column.x
		local y = column.line == 1 and -84 or -84 + LINE_TWO
		local heading
		if column.key == "price" then
			heading = CreateFrame("Button", nil, panel)
			heading:SetSize(column.width - 8, 18)
			heading.text = heading:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			heading.text:SetAllPoints()
			heading.text:SetJustifyH(column.justify)
			heading:SetFontString(heading.text)
		else
			heading = { text = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall") }
			heading.text:SetSize(column.width - 8, 18)
			heading.text:SetJustifyH(column.justify)
		end
		local anchor = heading.SetPoint and heading or heading.text
		anchor:SetPoint("TOPLEFT", x + 4, y)
		if heading.SetText then heading:SetText(column.label) else heading.text:SetText(column.label) end
		headings[column.key] = heading
	end

	local empty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	empty:SetPoint("TOPLEFT", 12, -124)
	empty:SetText(L["No auction prices collected yet."])

	-- The rows in a frame of their own. A row takes the mouse for its tooltip and spans the width,
	-- and one sharing a parent with the heading and the page buttons would sit over them.
	local body = CreateFrame("Frame", nil, panel)
	body:SetPoint("TOPLEFT", 8, -120)
	body:SetPoint("BOTTOMRIGHT", -8, 0)

	-- **The game's own scroll bar**, asked for 2026-09-15: on thousands of prices the wheel takes
	-- a long time to reach the middle or the end. `FauxScrollFrameTemplate` is the bar the client's
	-- own browse list is built on (`BrowseScrollFrame`, backlog 62), so it is the client drawing
	-- its own textures and not a path Family asserts. It scrolls nothing itself; it holds the
	-- offset, and the page is drawn from it. Made before the rows so the rows, which stop short of
	-- it, sit above it; and only where the client has the template and its three functions -
	-- without them the wheel and the arrows are the whole of it, as they were.
	local bar
	if type(_G.FauxScrollFrame_Update) == "function"
		and type(_G.FauxScrollFrame_GetOffset) == "function"
		and type(_G.FauxScrollFrame_OnVerticalScroll) == "function" then
		local ok, made = pcall(CreateFrame, "ScrollFrame", "FamilyPriceAuditScroll", body,
			"FauxScrollFrameTemplate")
		if ok then bar = made end
	end
	if bar then
		bar:SetPoint("TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", -BAR_ROOM, -PAGE_ROWS * ROW_HEIGHT)
	end

	local rows = {}
	for index = 1, PAGE_ROWS do
		local row = CreateFrame("Frame", nil, body)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT", body, "RIGHT", -BAR_ROOM, 0)

		-- **Red behind a row that looks wrong**, rather than a colour on one of its numbers:
		-- the figures are white on every row in Family, and a suspect is a fact about the row.
		-- Every other item faintly lit, so the two lines of one read as one thing.
		row.stripe = row:CreateTexture(nil, "BACKGROUND")
		row.stripe:SetAllPoints()
		paintAlert(row.stripe, 1, 1, 1, 0.05)
		row.stripe:SetShown(index % 2 == 0)

		row.alert = row:CreateTexture(nil, "BORDER")
		row.alert:SetAllPoints()
		row.alert:Hide()

		row.cells = {}
		for c, column in ipairs(COLUMNS) do
			local cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			cell:SetPoint("TOPLEFT", column.x + 4, column.line == 1 and -3 or -3 + LINE_TWO)
			cell:SetWidth(column.width - 8)
			cell:SetJustifyH(column.justify)
			if cell.SetWordWrap then cell:SetWordWrap(false) end
			row.cells[c] = cell
		end

		-- On the second line, at the row's right-hand end, beside the reading they act on.
		row.ban = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.ban:SetSize(BUTTON_W, 16)
		row.ban:SetPoint("TOPRIGHT", -2, LINE_TWO)
		row.ban:SetText(L["Ban"])

		row.forget = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.forget:SetSize(BUTTON_W, 16)
		row.forget:SetPoint("RIGHT", row.ban, "LEFT", -4, 0)
		row.forget:SetText(L["Delete"])

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
			end
			if entry.suspect == "replaced" then
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

		-- The categories this client has written down, and which one is chosen. A list that has
		-- changed under a choice - another client, another language - puts the choice back on all.
		categories = Auctions:Categories()
		local category = categories and wantedCategory and categories[wantedCategory] or nil
		if not category then wantedCategory, wantedSub = nil, nil end
		local subcategory = category and wantedSub and category.subs[wantedSub] or nil
		if not subcategory then wantedSub = nil end

		-- None written down yet: the list exists only once an auction window has been opened on
		-- this client and language, and this says so in the few words a button holds.
		if not categories then
			categoryButton:SetText(L["No categories yet"])
			categoryButton:Disable()
		else
			categoryButton:SetText(category and category.name or L["All categories"])
			categoryButton:Enable()
		end
		subButton:SetText(subcategory and subcategory.name or L["All subcategories"])
		subButton:SetShown(category ~= nil and #category.subs > 0)

		local wantedFilters = subcategory and subcategory.filters or category and category.filters
			or nil

		local needle = (search:GetText() or ""):lower()
		shown = {}
		for _, entry in ipairs(rowsData) do
			if (not wantedMarket or entry.market == wantedMarket)
				and (not suspectsOnly or entry.suspect ~= nil)
				and (not bansOnly or entry.banned ~= nil)
				and (not wantedFilters or Auctions:InCategory(entry.variant, wantedFilters)) then
				local keep = true
				if needle ~= "" then
					local name = storedName(entry.variant)
					keep = name ~= nil and name:lower():find(needle, 1, true) ~= nil
				end
				if keep then shown[#shown + 1] = entry end
			end
		end

		-- **Bans first, whatever the order**, because a ban is a thing somebody did and will
		-- come back to lift; then by the price of one, highest first unless turned round. A ban
		-- with no reading yet has no price, and goes after the bans that have one.
		table.sort(shown, function(a, b)
			if (a.banned ~= nil) ~= (b.banned ~= nil) then return a.banned ~= nil end
			if (a.p ~= nil) ~= (b.p ~= nil) then return a.p ~= nil end
			if not a.p then return tostring(a.variant) < tostring(b.variant) end
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

		-- The bar is told how long the list is and where the page stands in it.
		if bar then
			Family:TryCall(FauxScrollFrame_Update, bar, total, PAGE_ROWS, ROW_HEIGHT)
			if (tonumber((Family:TryCall(FauxScrollFrame_GetOffset, bar))) or 0) ~= offset then
				Family:TryCall(bar.SetVerticalScroll, bar, offset * ROW_HEIGHT)
			end
		end

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

				-- **A banned row shows its newest reading**: the ban keeps the price out of Worth
				-- and recipe costs, and what the house is asking now is how to tell it can go.
				if entry.p then
					row.cells[3]:SetText(UI:Money(entry.p))
					row.cells[4]:SetText(entry.was and UI:Money(entry.was) or UI.UNKNOWN)
					row.cells[5]:SetText(UI:Ago(entry.at))
					row.forget:Show()
				else
					row.cells[3]:SetText("|cffff5555" .. L["banned"] .. "|r")
					row.cells[4]:SetText("")
					row.cells[5]:SetText(UI:Ago(entry.banned))
					row.forget:Hide()
				end
				row.ban:SetText(entry.banned and L["Lift"] or L["Ban"])

				-- Blue behind a ban, red behind a suspect; a banned suspect is a ban.
				if entry.banned then
					paintAlert(row.alert, 0.15, 0.35, 0.9, 0.3)
				elseif entry.suspect then
					paintAlert(row.alert, 0.8, 0.1, 0.1, 0.25)
				end
				row.alert:SetShown(entry.banned ~= nil or entry.suspect ~= nil)
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
			if not entry or not entry.p then return end
			Auctions:Forget(entry.market, entry.variant)
			changed()
		end)
		row.ban:SetScript("OnClick", function()
			local entry = row.entry
			if not entry then return end
			if entry.banned then
				Auctions:Unban(entry.market, entry.variant)
			else
				Auctions:Ban(entry.market, entry.variant)
			end
			changed()
		end)
	end

	categoryButton:SetScript("OnClick", function()
		if not categories then return end
		local choices = { { label = L["All categories"], value = false } }
		for index, category in ipairs(categories) do
			choices[#choices + 1] = { label = category.name, value = index }
		end
		openMenu(categoryButton, choices, function(value)
			wantedCategory = value or nil
			wantedSub = nil
			offset = 0
			panel:Refresh()
		end)
	end)

	subButton:SetScript("OnClick", function()
		local category = categories and wantedCategory and categories[wantedCategory]
		if not category then return end
		local choices = { { label = L["All subcategories"], value = false } }
		for index, sub in ipairs(category.subs) do
			choices[#choices + 1] = { label = sub.name, value = index }
		end
		openMenu(subButton, choices, function(value)
			wantedSub = value or nil
			offset = 0
			panel:Refresh()
		end)
	end)

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

	suspectsBox:SetScript("OnClick", function(self)
		suspectsOnly = self:GetChecked() and true or false
		offset = 0
		panel:Refresh()
	end)

	bansBox:SetScript("OnClick", function(self)
		bansOnly = self:GetChecked() and true or false
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

	-- Dragging the bar, or its own arrows, moves the page. The template works the offset out from
	-- where it was dragged to; the page is drawn from that.
	if bar then
		bar:SetScript("OnVerticalScroll", function(self, value)
			FauxScrollFrame_OnVerticalScroll(self, value, ROW_HEIGHT, function()
				offset = tonumber((Family:TryCall(FauxScrollFrame_GetOffset, self))) or 0
				panel:Draw()
			end)
		end)
	end
	panel.__bar = bar
	panel.__marketButton = marketButton
	panel.__categoryButton, panel.__subButton, panel.__menu = categoryButton, subButton, menu

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
