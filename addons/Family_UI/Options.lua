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
		label = L["Add Family to item tooltips"],
		note = L["Who owns one, and where it is - bags, bank, mail, auctions."],
		get = function() return FamilyDB.tooltips ~= false end,
		set = function(on) FamilyDB.tooltips = on and true or false end,
	},
	{
		label = L["Say which crafting cooldowns are ready when you log in"],
		note = L["Transmutes, mooncloth, salt shakers. Crafting only - raid and heroic "
			.. "lockouts are a different thing and Family does not record them yet."],
		get = function() return FamilyDB.cooldownNotice ~= false end,
		set = function(on) FamilyDB.cooldownNotice = on and true or false end,
	},
	{
		-- The same switch as the one on the Guild panel, reading the same answer. Two
		-- places to find it rather than two settings: this is where a player looks for a
		-- switch, and that is where they are when they decide they want it off.
		label = L["Share gear and talents with your guild"],
		note = L["Both ways: what your guild sees of you, and what you see of them. "
			.. "Nothing else is shared - bags, mail and the rest need a Wide Family link."],
		get = function() return Family.Guild:Enabled() end,
		set = function(on) Family.Guild:SetEnabled(on) end,
	},
	{
		-- The same switch as the one on the Wide Family panel, reading the same answer, for
		-- the same reason the guild one is here twice: this is where a player looks for a
		-- switch, and that is where they are when they decide they want it.
		label = L["Share with families you link to"],
		note = L["Wide Family: linking with another player, so each of you sees the members "
			.. "and categories the other allows. Nothing is shared until you link and tick "
			.. "what they may see."],
		get = function() return Family.Wide:Enabled() end,
		set = function(on) Family.Wide:SetEnabled(on) end,
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

	local checkboxes = {}

	local y = -34
	for index, switch in ipairs(SWITCHES) do
		local box = CreateFrame("CheckButton", "FamilyOption" .. index, frame,
			"UICheckButtonTemplate")
		box:SetSize(24, 24)
		box:SetPoint("TOPLEFT", 8, y)

		local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("LEFT", box, "RIGHT", 4, 0)
		label:SetPoint("RIGHT", frame, "RIGHT", -MARGIN, 0)
		label:SetJustifyH("LEFT")
		label:SetText(switch.label)

		local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		note:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 28, 4)
		-- A right edge, so the note wraps inside the panel instead of growing until it
		-- runs out of one. Without it these were drawn to the natural width of the
		-- sentence: fine in English, and straight through the border in French.
		note:SetPoint("RIGHT", frame, "RIGHT", -MARGIN, 0)
		note:SetJustifyH("LEFT")
		if note.SetWordWrap then note:SetWordWrap(true) end
		note:SetText(switch.note)

		box:SetScript("OnClick", function(self)
			switch.set(self:GetChecked() and true or false)
			frame:Refresh()
		end)

		checkboxes[index] = box

		-- Stepped by what this row actually took. A note that wraps to two lines is two
		-- lines tall, and a fixed step would have the next switch sitting on top of it.
		y = y - ROW - math.max(12, math.ceil(note:GetStringHeight() or 12) + 2)
	end

	-- Strata is a list rather than a switch, and it is here because a window hidden behind
	-- somebody's HUD is the sort of thing that needs fixing from inside the window.
	local strataLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	strataLabel:SetPoint("TOPLEFT", 12, y - 6)
	strataLabel:SetText(L["How far in front the window sits"])

	local strataNote = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	strataNote:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -2)
	strataNote:SetPoint("RIGHT", frame, "RIGHT", -MARGIN, 0)
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
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
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
	end, (UI.CONTENT_W or 740) - 24)

	local strataMeaning = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	strataMeaning:SetPoint("TOPLEFT", strataNote, "BOTTOMLEFT", 0, -34)
	strataMeaning:SetPoint("RIGHT", -8, 0)
	strataMeaning:SetJustifyH("LEFT")
	strataMeaning:SetTextColor(0.7, 0.7, 0.7)

	local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", 8, 8)
	footer:SetPoint("BOTTOMRIGHT", -8, 8)
	footer:SetJustifyH("LEFT")

	function frame:Refresh()
		for index, switch in ipairs(SWITCHES) do
			checkboxes[index]:SetChecked(switch.get() and true or false)
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
