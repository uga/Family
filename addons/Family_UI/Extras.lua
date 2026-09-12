-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Things Family will do that are not what Family is for.
--
-- Asked for 2026-09-12: *mi stanno venendo in mente un po' di queste features collaterali,
-- forse puo valer la pena di creare un ulteriore pannello Extras (sopra Options) per
-- abilitarle / disabilitarle singolarmente.*
--
-- **The line between this panel and Options is what the switch is about, not how big it is.**
-- Options settles how Family behaves while doing its job: whether the tooltip carries a
-- possessions block, who may see what, how far in front the window sits. Everything here is a
-- job Family is not otherwise doing at all - reading an auction house, narrating a mailbox -
-- and each one is off or on by itself.
--
-- **A new extra ships off**, which is settled where the defaults are. The one exception is the
-- auction house, which is not a new job at all.

local _, UI = ...

local Family = _G.Family
local L = Family.L

-- **The answers live in the recorder half** (`addons/Family/Extras.lua`), because the scanners
-- obey them and this addon is one a player can have disabled. This file is the switches and the
-- sentences under them, and nothing else.
local Extras = Family.Extras

local ROW = 30
local MARGIN = 12

local SWITCHES = {
	{
		name = "auctionPrices",
		label = L["Read prices at the auction house"],
		note = L["Using the auction house fills Family in: whatever that window is showing "
			.. "is read, including the whole-house scan of an addon like Auctionator or "
			.. "Auctioneer, which Family listens to and takes prices from for nothing. "
			.. "With this off, Family values what your characters hold at what a vendor "
			.. "pays - which the game states for nearly everything - and reads nothing at "
			.. "an auction house. Prices already recorded are kept either way."],
	},
	{
		name = "houseWalk",
		label = L["Let Family read the whole auction house itself"],
		note = L["Adds a Family tab to the auction window with a button that walks every "
			.. "page there is. It takes minutes, because the game only lets one search out "
			.. "at a time - so if you already run an auction addon, use its own full scan "
			.. "instead and Family will hear it. This is for people who do not."],
	},
	{
		name = "craftingCost",
		label = L["Say what a craftable item costs to make"],
		note = L["On the tooltip of anything a profession makes: every material with what it "
			.. "would cost to buy, and the total. The cheapest source wins where there is "
			.. "more than one. A material Family has no price for is said to be unknown "
			.. "rather than counted as nothing, and one that binds on pickup adds nothing "
			.. "because no money can buy it - the total says so when it happens."],
	},
	{
		name = "mailReport",
		label = L["Say what came out of the mailbox"],
		note = L["A line in chat for each thing taken out of a letter and each sum "
			.. "collected, and a total when you close the mailbox. The game says nothing "
			.. "about what a mailbox full of auction returns actually came to."],
	},
}

--------------------------------------------------------------------------------------------

local function build(frame)
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText(L["Extras"])

	local blurb = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	blurb:SetPoint("TOPLEFT", 8, -30)
	blurb:SetPoint("TOPRIGHT", -8, -30)
	blurb:SetJustifyH("LEFT")
	blurb:SetText(L["Jobs Family will do for you that are not what Family is for. Each one "
		.. "is off or on by itself, and a new one always arrives off."])

	-- The same scroller the Options panel has, and for the same reason: a switch is only safe
	-- to flip when the sentence under it says what it does, and those sentences are longer in
	-- every language than they are in English.
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -64)
	scroll:SetPoint("RIGHT", frame, "RIGHT", -26, 0)
	scroll:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	local room = math.max(UI:ListWidth(scroll) - MARGIN - 8, 200)

	local checkboxes = {}
	local y = 2

	for index, switch in ipairs(SWITCHES) do
		local box = CreateFrame("CheckButton", "FamilyExtra" .. index, list,
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
		note:SetWidth(room - 32)
		note:SetJustifyH("LEFT")
		if note.SetWordWrap then note:SetWordWrap(true) end
		note:SetText(switch.note)

		box:SetScript("OnClick", function(self)
			Extras:Set(switch.name, self:GetChecked() and true or false)
			frame:Refresh()
		end)

		checkboxes[index] = box

		-- Stepped by what this row actually took, as the Options panel does: a note that
		-- wraps to two lines is two lines tall, and a fixed step puts the next switch on it.
		y = y + ROW + math.max(12, math.ceil(note:GetStringHeight() or 12) + 2)
	end

	list:SetWidth(math.max(room, 1))
	list:SetHeight(math.max(y, 1))

	function frame:Refresh()
		for index, switch in ipairs(SWITCHES) do
			checkboxes[index]:SetChecked(Extras:On(switch.name))
		end
	end
end

-- **No picture.** A texture is the one thing in Family that cannot be probed: the client
-- echoes back whatever path it was handed, so a path chosen from memory draws nothing and says
-- nothing about having done so. `Window.lua` draws no icon for a tab with no entry in its table
-- and keeps the space, so the strip stays in line until one is picked off the icon sheet and
-- looked at (HANDOFF §3).
UI:RegisterTab("extras", L["Extras"], build)
