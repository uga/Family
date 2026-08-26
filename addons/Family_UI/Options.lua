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

local ROW = 30

--------------------------------------------------------------------------------------------
-- Each switch says how to read itself and what to do when it is flipped, and the panel
-- knows nothing else about any of them.
--------------------------------------------------------------------------------------------

local SWITCHES = {
	{
		label = "Show the minimap button",
		note = "Drag it around the edge of the minimap to move it.",
		get = function() return UI:IsMinimapShown() end,
		set = function(on) UI:SetMinimapShown(on) end,
	},
	{
		label = "Add Family to item tooltips",
		note = "Who owns one, and where it is - bags, bank, mail, auctions.",
		get = function() return FamilyDB.tooltips ~= false end,
		set = function(on) FamilyDB.tooltips = on and true or false end,
	},
	{
		label = "Say which crafting cooldowns are ready when you log in",
		note = "Transmutes, mooncloth, salt shakers. Crafting only - raid and heroic "
			.. "lockouts are a different thing and Family does not record them yet.",
		get = function() return FamilyDB.cooldownNotice ~= false end,
		set = function(on) FamilyDB.cooldownNotice = on and true or false end,
	},
	{
		-- The same switch as the one on the Guild panel, reading the same answer. Two
		-- places to find it rather than two settings: this is where a player looks for a
		-- switch, and that is where they are when they decide they want it off.
		label = "Share gear and talents with your guild",
		note = "Both ways: what your guild sees of you, and what you see of them. "
			.. "Nothing else is shared - bags, mail and the rest need a Wide Family link.",
		get = function() return Family.Guild:Enabled() end,
		set = function(on) Family.Guild:SetEnabled(on) end,
	},
	{
		label = "Narrate what the scanners are doing",
		note = "Chat messages while Family records things. For working out faults.",
		get = function() return FamilyDB.debug and true or false end,
		set = function(on) FamilyDB.debug = on and true or false end,
	},
}

--------------------------------------------------------------------------------------------

local function build(frame)
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText("Options")

	local checkboxes = {}

	local y = -34
	for index, switch in ipairs(SWITCHES) do
		local box = CreateFrame("CheckButton", "FamilyOption" .. index, frame,
			"UICheckButtonTemplate")
		box:SetSize(24, 24)
		box:SetPoint("TOPLEFT", 8, y)

		local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("LEFT", box, "RIGHT", 4, 0)
		label:SetText(switch.label)

		local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		note:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 28, 4)
		note:SetText(switch.note)

		box:SetScript("OnClick", function(self)
			switch.set(self:GetChecked() and true or false)
			frame:Refresh()
		end)

		checkboxes[index] = box
		y = y - ROW - 12
	end

	-- Strata is a list rather than a switch, and it is here because a window hidden behind
	-- somebody's HUD is the sort of thing that needs fixing from inside the window.
	local strataLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	strataLabel:SetPoint("TOPLEFT", 12, y - 6)
	strataLabel:SetText("How far in front the window sits")

	local strataNote = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	strataNote:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -2)
	strataNote:SetText("Raise this if another addon draws over Family.")

	-- MEDIUM, HIGH and DIALOG are the game's own words for how deep a frame sits, and they
	-- say nothing to anybody who has not written an addon. What each one means in practice
	-- is what a player actually needs.
	local STRATA_MEANS = {
		MEDIUM = "Behind most things. Choose this if Family covers something it should not.",
		HIGH   = "In front of unit frames and most HUDs. The usual choice.",
		DIALOG = "In front of nearly everything, alongside the game's own popups. " ..
			"Choose this if a HUD still draws over Family.",
	}

	local strataButtons = {}
	local x = 0
	for _, name in ipairs(UI:StrataChoices()) do
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		button:SetSize(90, 22)
		button:SetPoint("TOPLEFT", strataNote, "BOTTOMLEFT", x, -6)
		button:SetText(name)
		button:SetScript("OnClick", function()
			UI:SetStrata(name)
			frame:Refresh()
		end)
		strataButtons[name] = button
		x = x + 94
	end

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
			"|cff888888Family %s on %s   |||   tooltips hooked: %s   |||   storage: %s|r",
			Family.version, Family.Capabilities.name,
			Family.tooltipRoute or "not hooked",
			Family.Codec.compressing and "compressed" or "uncompressed"))
	end
end

UI:RegisterTab("options", "Options", build)
