-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The switches, in the window rather than behind a slash command.
--
-- Everything here already had a way to set it typed; this is the same settings with somewhere
-- to find them. A setting nobody can find is a setting nobody has.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 30

-- The panel's own right-hand margin. Every caption stops here rather than at whatever
-- width its sentence happens to be.
local MARGIN = 12

--------------------------------------------------------------------------------------------
-- Each switch says how to read itself and what to do when it is flipped, and the panel
-- knows nothing else about any of them.
--------------------------------------------------------------------------------------------

local SWITCHES = {
	{
		label = L["Show the minimap button"],
		note = L["Drag it around the edge of the minimap to move it."],
		get = function() return UI:IsMinimapShown() end,
		set = function(on) UI:SetMinimapShown(on) end,
	},
	{
		label = L["Always open Family on one panel"],
		note = L["Switch this on and a star appears beside every panel in the strip. "
			.. "Clicking one locks Family to that panel: it opens there every time, now "
			.. "and after you log out. The star is solid on the panel it is locked to and "
			.. "faint everywhere else - and clicking the solid one unlocks it again.\n"
			.. "On the summary the lock takes the set of columns you are looking at too, "
			.. "so it can mean Activity rather than the whole panel. To move it to another "
			.. "set, go to that set and click the star again: it goes faint the moment the "
			.. "columns change, which is what says it can be moved."],
		get = function() return UI:UsesDefaultPanel() end,
		set = function(on) UI:SetUsesDefaultPanel(on) end,
	},
	{
		label = L["Add Family to item tooltips"],
		note = L["Who owns one, and where it is - bags, bank, mail, auctions."],
		get = function() return FamilyDB.tooltips ~= false end,
		set = function(on) FamilyDB.tooltips = on and true or false end,
	},
	{
		label = L["Say whose mail is running out when you log in"],
		note = L["Names the characters holding letters that have expired or are about to. "
			.. "The game puts an envelope on your minimap and never says when what is in "
			.. "it goes away."],
		get = function() return FamilyDB.mailNotice ~= false end,
		set = function(on) FamilyDB.mailNotice = on and true or false end,

		-- The first setting in Family that is a number rather than a yes or a no, which is
		-- why the schema above grew a field rather than this row growing a special case.
		number = {
			label = L["Warn me this many days before:"],
			get = function() return UI:MailNoticeDays() end,
			set = function(days) return UI:SetMailNoticeDays(days) end,
		},
	},
	{
		label = L["Say which crafting cooldowns are ready when you log in"],
		note = L["Transmutes, mooncloth, salt shakers. Crafting only - raid and heroic "
			.. "lockouts are a different thing and Family does not record them yet."],
		get = function() return FamilyDB.cooldownNotice ~= false end,
		set = function(on) FamilyDB.cooldownNotice = on and true or false end,
	},
	{
		-- The only switch there is. The Guild panel had one of its own once and no longer
		-- does: it is always shown, and says in grey that sharing is off and that this is
		-- where to turn it on. One switch in the place a player goes looking for switches
		-- beats two that have to be kept agreeing with each other.
		label = L["Share gear and talents with your guild"],
		note = L["Both ways: what your guild sees of you, and what you see of them. "
			.. "Nothing else is shared - bags, mail and the rest need a Wide Family link."],
		get = function() return Family.Guild:Enabled() end,
		set = function(on) Family.Guild:SetEnabled(on) end,
	},
	{
		-- The only switch there is, exactly as above. The Wide Family panel is always
		-- shown and greys itself out with a line saying what it would do and where to
		-- enable it, so that the decision is made having read what it is.
		label = L["Share with families you link to"],
		note = L["Wide Family: linking with another player, so each of you sees the members "
			.. "and categories the other allows. Nothing is shared until you link and tick "
			.. "what they may see."],
		get = function() return Family.Wide:Enabled() end,
		set = function(on) Family.Wide:SetEnabled(on) end,
	},
	{
		-- Under Wide Family's own switch, because it is about Wide Family and nothing
		-- else, and a player looking for it will look there.
		label = L["Say in chat how a Wide Family update went"],
		note = L["Whether a linked family had anybody online to talk to. Somebody asking to "
			.. "link, a link made or ended, and anything that has gone wrong are always "
			.. "said."],
		get = function() return Family.Wide:Reports() end,
		set = function(on) Family.Wide:SetReports(on) end,
	},
	{
		label = L["Narrate what the scanners are doing"],
		note = L["Chat messages while Family records things. For working out faults."],
		get = function() return FamilyDB.debug and true or false end,
		set = function(on) FamilyDB.debug = on and true or false end,
	},
}

--------------------------------------------------------------------------------------------

local function build(frame)
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText(L["Options"])

	-- The footer first, because the scroller is measured against it. It stays pinned to the
	-- bottom of the panel rather than scrolling with the switches: what it says is about this
	-- installation and not about any switch, and a line that scrolls away is a line somebody
	-- has to go looking for.
	local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", 8, 8)
	footer:SetPoint("BOTTOMRIGHT", -8, 8)
	footer:SetJustifyH("LEFT")

	-- **Scrolled, because the switches outgrew the panel.** Nine of them with a wrapping
	-- caption each, plus the strata row, run past the bottom in English and further in every
	-- other language - the last caption was drawn over the footer, and anything below that
	-- was simply not on the screen. There is no shorter way to say what these do, and a
	-- caption is what makes a switch safe to flip, so the panel scrolls instead.
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	-- The bottom edge follows the footer rather than sitting a fixed distance off the panel.
	-- That line is one line in English and can be two in German, and a scroller that assumed
	-- one would put the second through the last caption - which is the fault being fixed
	-- here, reintroduced in the fix.
	scroll:SetPoint("TOPLEFT", 4, -32)
	scroll:SetPoint("RIGHT", frame, "RIGHT", -26, 0)
	scroll:SetPoint("BOTTOM", footer, "TOP", 0, 6)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	-- Every caption stops here rather than at whatever width its sentence happens to be, and
	-- it is a width rather than a right-hand anchor now: the scroll child is one pixel wide
	-- until it is told otherwise, so anchoring to its edge would wrap every sentence to
	-- nothing.
	local room = math.max(UI:ListWidth(scroll) - MARGIN - 8, 200)

	local checkboxes = {}
	local numberFields = {}

	local y = 2
	for index, switch in ipairs(SWITCHES) do
		local box = CreateFrame("CheckButton", "FamilyOption" .. index, list,
			"UICheckButtonTemplate")
		box:SetSize(24, 24)
		box:SetPoint("TOPLEFT", 4, -y)

		local label = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("LEFT", box, "RIGHT", 4, 0)
		label:SetWidth(room - 32)
		label:SetJustifyH("LEFT")
		label:SetText(switch.label)

		local note = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		note:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 28, 4)
		-- A right edge, so the note wraps inside the panel instead of growing until it
		-- runs out of one. Without it these were drawn to the natural width of the
		-- sentence: fine in English, and straight through the border in French.
		note:SetWidth(room - 32)
		note:SetJustifyH("LEFT")
		if note.SetWordWrap then note:SetWordWrap(true) end
		note:SetText(switch.note)

		box:SetScript("OnClick", function(self)
			switch.set(self:GetChecked() and true or false)
			frame:Refresh()
		end)

		checkboxes[index] = box

		-- A number under its own switch, where the sentence it belongs to is.
		--
		-- A box to type in rather than a slider: a slider has to be dragged to a value it
		-- never quite lands on, and the two numbers a player actually wants here are the one
		-- they were told and the one they already have in mind. Bounded on the way in, and
		-- put back to what is stored when what was typed is not a number this accepts -
		-- silently keeping a refused value would be the control lying about the setting.
		local extra = 0
		if switch.number then
			-- A right edge, for the same reason the note above has one: without it a font
			-- string is drawn to the natural width of its sentence, which is fine in
			-- English and through the border in Russian.
			local prompt = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
			prompt:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -6)
			prompt:SetWidth(math.max(room - 110, 120))
			prompt:SetJustifyH("LEFT")
			if prompt.SetWordWrap then prompt:SetWordWrap(true) end
			prompt:SetText(switch.number.label)

			local field = CreateFrame("EditBox", "FamilyOptionNumber" .. index, list,
				"InputBoxTemplate")
			field:SetPoint("LEFT", prompt, "RIGHT", 10, 0)
			field:SetSize(40, 20)
			field:SetAutoFocus(false)
			field:SetNumeric(true)
			field:SetMaxLetters(3)
			field:SetJustifyH("CENTER")
			field:SetText(tostring(switch.number.get()))

			local function settle(self)
				if not switch.number.set(self:GetText()) then
					self:SetText(tostring(switch.number.get()))
				end
				self:ClearFocus()
			end

			field:SetScript("OnEnterPressed", settle)
			field:SetScript("OnEditFocusLost", settle)
			field:SetScript("OnEscapePressed", function(self)
				self:SetText(tostring(switch.number.get()))
				self:ClearFocus()
			end)

			numberFields[index] = field

			-- Stepped by what the prompt actually took, the same as the note above: a label
			-- that wraps to two lines in one language is two lines tall in that language.
			extra = math.max(26, math.ceil(prompt:GetStringHeight() or 12) + 12)
		end

		-- Stepped by what this row actually took. A note that wraps to two lines is two
		-- lines tall, and a fixed step would have the next switch sitting on top of it.
		y = y + ROW + math.max(12, math.ceil(note:GetStringHeight() or 12) + 2) + extra
	end

	-- Strata is a list rather than a switch, and it is here because a window hidden behind
	-- somebody's HUD is the sort of thing that needs fixing from inside the window.
	local strataLabel = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	strataLabel:SetPoint("TOPLEFT", 8, -(y + 6))
	strataLabel:SetText(L["How far in front the window sits"])

	local strataNote = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	strataNote:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -2)
	strataNote:SetWidth(room - 8)
	strataNote:SetJustifyH("LEFT")
	strataNote:SetText(L["Raise this if another addon draws over Family."])

	-- MEDIUM, HIGH and DIALOG are the game's own words for how deep a frame sits, and they
	-- say nothing to anybody who has not written an addon. What each one means in practice
	-- is what a player actually needs.
	local STRATA_MEANS = {
		MEDIUM = L["Behind most things. Choose this if Family covers something it should not."],
		HIGH   = L["In front of unit frames and most HUDs. The usual choice."],
		DIALOG = L["In front of nearly everything, alongside the game's own popups. " ..
			"Choose this if a HUD still draws over Family."],
	}

	local strataButtons, strataRow = {}, {}
	for _, name in ipairs(UI:StrataChoices()) do
		local button = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
		button:SetHeight(22)
		button:SetText(L[name])
		button:SetScript("OnClick", function()
			UI:SetStrata(name)
			frame:Refresh()
		end)
		strataButtons[name] = button
		strataRow[#strataRow + 1] = button
	end
	UI:LayOutRow(strataRow, 90, 4, 0, function(button, x)
		button:SetPoint("TOPLEFT", strataNote, "BOTTOMLEFT", x, -6)
	end, room - 8)

	local strataMeaning = list:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	strataMeaning:SetPoint("TOPLEFT", strataNote, "BOTTOMLEFT", 0, -34)
	strataMeaning:SetWidth(room - 8)
	strataMeaning:SetJustifyH("LEFT")
	strataMeaning:SetTextColor(0.7, 0.7, 0.7)

	-- What the scroller scrolls. Measured from the switches rather than guessed, and with the
	-- strata block's own height added: the label, its caption, the row of buttons and the
	-- sentence under them all sit below the last switch, and a child that stops at the last
	-- switch would leave that sentence unreachable - which is the fault this is fixing, moved
	-- rather than fixed.
	local STRATA_BLOCK = 6 + 16 + 2 + 14 + 6 + 22 + 12 + 30
	list:SetWidth(math.max(room, 1))
	list:SetHeight(math.max(y + STRATA_BLOCK, 1))

	function frame:Refresh()
		for index, switch in ipairs(SWITCHES) do
			checkboxes[index]:SetChecked(switch.get() and true or false)

			-- Redrawn from the setting rather than left as the player last saw it, so that
			-- a value refused elsewhere - or a saved variables file carrying a number this
			-- build no longer accepts - shows what is actually in force.
			local field = numberFields[index]
			if field and not field:HasFocus() then
				field:SetText(tostring(switch.number.get()))
			end
		end

		for name, button in pairs(strataButtons) do
			UI:MarkSelected(button, name == UI:CurrentStrata())
		end

		strataMeaning:SetText(STRATA_MEANS[UI:CurrentStrata()] or "")

		footer:SetText(string.format(
			L["|cff888888Family %s on %s   |||   tooltips hooked: %s   |||   storage: %s|r"],
			Family.version, Family.Capabilities.name,
			Family.tooltipRoute or L["not hooked"],
			Family.Codec.compressing and L["compressed"] or L["uncompressed"]))
	end
end

UI:RegisterTab("options", L["Options"], build)
