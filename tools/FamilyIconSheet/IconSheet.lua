-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The icon contact sheet.
--
-- Everything else in Family is probed: an optional API is checked with type(_G[name]) ==
-- "function" and its answer read back, so the addon knows what this client can do rather
-- than assuming it. Textures are the one thing that cannot be treated that way. A path that
-- does not exist draws nothing, and GetTexture() cheerfully echoes back whatever string it
-- was handed - so from inside the client, a correct path and a typo are indistinguishable.
-- The only instrument is an eye.
--
-- So: this draws every candidate at the size it would really be used at, on a coloured
-- backing, once per client. Screenshot it on Era, on Anniversary and on Mists, and what
-- rendered is what exists. That turns an unverifiable assumption into a verified fact, which
-- is the standard the rest of the project is held to.
--
-- Reading it
--
--   A cell that is nothing but backing colour is a path this client does not have.
--   A cell showing a green square is the client's own "missing texture" marker.
--   Art with transparency - the Minimap\Tracking set, the GossipFrame set - shows backing
--   colour around the symbol. That is not a miss. Only a completely flat cell is.
--
--   The first group is a control: one path invented to be wrong and one known good. Whatever
--   the wrong one looks like on this client is what a miss looks like on this client, and it
--   is not the same on all of them. Read the rest of the sheet against it.
--
--   Backing cycles magenta / black / white. Magenta finds misses; black is what a tab strip
--   actually looks like; white catches dark art that vanishes into the frame.
--
-- Using it
--
--   /iconsheet          open it
--   click a cell        choose that path - it survives a reload
--   Print chosen        writes the choices to chat, grouped, ready to paste into code
--   the box at the top  try any path, or on Mists any atlas name, without editing this file
--
-- The last section is not a contact sheet at all: it is every real tab button at the real
-- size, with a real icon inset and the real labels, measured. Whether "Abilities & Talents"
-- still fits once an icon takes 22 pixels off the front is a question the client can answer
-- exactly, so it is asked rather than eyeballed.
--
-- Not part of any release: it lives in tools/, which .pkgmeta ignores, and depends on
-- nothing.

local ADDON = ...

local WIDTH, HEIGHT = 940, 620
local CELL_W, CELL_H = 118, 68
local BIG, SMALL = 32, 18          -- judging size, and the size a tab icon really is
-- Family_UI/Window.lua. The strip grew from 136 to 160 on 2026-08-25 so that adding a picture
-- to the front of every label cost no label any room; keep these two in step, or this section
-- measures a tab strip that does not exist.
local TAB_W, TAB_H = 160, 24       -- Family_UI/Window.lua
local TAB_ICON = 16
local TAB_TEXT_INSET = 22          -- icon plus a gap, taken off the front of the label

local GOLD, GREY, RED, GREEN = "|cffffd700", "|cff888888", "|cffff5555", "|cff55ff55"

--------------------------------------------------------------------------------------------
-- The candidates
--
-- Grouped by the question each group answers, because the sheet is read one decision at a
-- time. `fit` names the tab this group would supply an icon for, which is what the fit test
-- at the bottom draws.
--
-- Generous rather than confident. A candidate that turns out not to exist has cost one cell;
-- a decision taken without seeing it costs a silent blank on somebody's client.
--------------------------------------------------------------------------------------------

local GROUPS = {
	{
		title = "Control - what a miss looks like here",
		note = "The first is deliberately wrong. Read the whole sheet against it.",
		icons = {
			{ "Interface\\Icons\\Family_NoSuchIcon_Control", "invented, cannot exist" },
			{ "Interface\\Icons\\INV_Misc_QuestionMark", "Family's own fallback" },
			{ "Interface\\Buttons\\UI-CheckBox-Check", "a non-Icons path, known good" },
		},
	},

	{
		title = "The bank's own container, on the Possessions panel",
		note = "It falls through to the backpack button today, so the bank reads as a bag. "
			.. "Wanted: something that says vault or stash without being a bag.",
		icons = {
			{ "Interface\\MINIMAP\\TRACKING\\Banker", "what the minimap calls a bank" },
			{ "Interface\\Icons\\INV_Misc_Coin_01", "coins - but auctions already uses 02" },
			{ "Interface\\Icons\\INV_Box_01", "a crate" },
			{ "Interface\\Icons\\INV_Crate_02" },
			{ "Interface\\Icons\\INV_Crate_04" },
			{ "Interface\\Icons\\INV_Misc_Chest_01" },
			{ "Interface\\Icons\\INV_Misc_TreasureChest01" },
			{ "Interface\\Icons\\INV_Misc_Bag_28", "a strongbox, if it exists here" },
			{ "Interface\\Icons\\Achievement_GuildPerk_MobileBanking", "likely retail only" },
			{ "Interface\\BankFrame\\Bank-Background", "not an icon - shape check only" },
		},
	},

	{
		title = "Summary", fit = "Summary",
		icons = {
			{ "Interface\\Icons\\INV_Misc_GroupLooking", "a group of people" },
			{ "Interface\\Icons\\INV_Misc_GroupNeedMore" },
			{ "Interface\\Icons\\INV_Misc_Note_01", "a list" },
			{ "Interface\\Icons\\INV_Misc_Spyglass_02", "an overview" },
			{ "Interface\\Icons\\Spell_Holy_PrayerOfHealing" },
		},
	},

	{
		title = "Abilities & Talents", fit = "Abilities & Talents",
		note = "The hard one. Vanilla drew the talent frame's own chrome, not a symbol, so "
			.. "there is no canonical answer - only what looks like one.",
		icons = {
			{ "Interface\\Icons\\Spell_Holy_MagicalSentry" },
			{ "Interface\\Icons\\Ability_Marksmanship" },
			{ "Interface\\Icons\\Spell_Nature_StarFall" },
			{ "Interface\\Icons\\Spell_Arcane_MindMastery" },
			{ "Interface\\Icons\\Spell_ChargePositive", "a point spent" },
			{ "Interface\\Icons\\Spell_Shadow_BrainWash" },
			{ "Interface\\Icons\\INV_Misc_Book_11", "a spellbook" },
			{ "Interface\\Icons\\INV_Misc_Rune_01" },
			{ "Interface\\Icons\\Spell_Nature_WispSplode" },
			{ "Interface\\Icons\\Spell_Holy_WordFortitude" },
			{ "Interface\\GossipFrame\\TrainerGossipIcon", "learning things" },
			{ "Interface\\Icons\\Achievement_Character_Human_Male",
				"achievement-era art: expected absent on Era and Burning Crusade" },
		},
	},

	{
		title = "Possessions", fit = "Possessions",
		icons = {
			{ "Interface\\Icons\\INV_Misc_Bag_08" },
			{ "Interface\\Icons\\INV_Misc_Bag_10_Blue" },
			{ "Interface\\Icons\\INV_Misc_Bag_07" },
			{ "Interface\\Buttons\\Button-Backpack-Up", "Contents.lua already uses it" },
			{ "Interface\\ContainerFrame\\KeyRing-Bag-Icon" },
		},
	},

	{
		title = "Professions", fit = "Professions",
		icons = {
			{ "Interface\\Minimap\\Tracking\\Profession", "transparent - judge on black" },
			{ "Interface\\Icons\\Trade_BlackSmithing" },
			{ "Interface\\Icons\\Trade_Engraving" },
			{ "Interface\\Icons\\Trade_Alchemy" },
			{ "Interface\\Icons\\Trade_Engineering" },
		},
	},

	{
		title = "Character", fit = "Character",
		icons = {
			{ "Interface\\Minimap\\Tracking\\Class", "transparent" },
			{ "Interface\\Icons\\INV_Chest_Chain" },
			{ "Interface\\Icons\\INV_Shirt_White_01" },
			{ "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest", "a slot frame, not an icon" },
		},
	},

	{
		title = "Character sections - all five settled",
		note = "Coin_17 was picked for Currencies and drew nothing on Burning Crusade, so it "
			.. "was withdrawn and Currencies took Minimap\\Tracking\\BattleMaster instead. "
			.. "That miss is exactly what this sheet is for, and it happened because the "
			.. "choice was made from one client. Judge on all three, every time.",
		icons = {
			-- Equipped gear. The slot frame is the safe one: Family already draws it for
			-- every empty slot on the character sheet, so it is known to exist on all
			-- three - which makes it the one candidate here that cannot be a miss.
			{ "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest", "gear: known good" },
			{ "Interface\\Icons\\INV_Chest_Plate01", "gear" },
			{ "Interface\\Icons\\INV_Helmet_24", "gear" },
			{ "Interface\\Icons\\Ability_Warrior_ShieldWall", "gear" },

			-- Currencies. Coin_02 is already the auction house's picture in Possessions,
			-- so taking it here would mean one picture meaning two things.
			{ "Interface\\Icons\\INV_Misc_Coin_01", "currencies" },
			{ "Interface\\Icons\\INV_Misc_Coin_17",
				"currencies - CHOSEN AND WITHDRAWN: drew nothing on Burning Crusade" },
			{ "Interface\\Icons\\INV_Misc_Rune_01", "currencies" },
			{ "Interface\\Icons\\Spell_Holy_ChampionsGrace", "currencies" },

			-- Achievements. The achievement-era art is exactly what Era is expected not to
			-- have, and this group is the place to find that out rather than to assume it.
			{ "Interface\\Icons\\Achievement_General",
				"expected absent on Era and Burning Crusade" },
			{ "Interface\\Icons\\INV_Misc_TrophyDaily_01", "achievements" },
			{ "Interface\\Icons\\INV_Misc_Note_01", "achievements" },
			{ "Interface\\Icons\\INV_Misc_Book_09", "achievements" },
		},
	},

	{
		title = "Wide Family", fit = "Wide Family",
		note = "The petition is a charter two parties sign, which is what a link is.",
		icons = {
			{ "Interface\\GossipFrame\\PetitionGossipIcon", "transparent" },
			{ "Interface\\Icons\\INV_Scroll_03" },
			{ "Interface\\Icons\\Spell_Arcane_PortalStormWind" },
			{ "Interface\\Icons\\INV_Misc_Rune_06" },
			{ "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon" },
			{ "Interface\\ChatFrame\\UI-ChatIcon-Blizz" },
			{ "Interface\\Icons\\INV_Misc_GroupNeedMore" },
		},
	},

	{
		title = "Options", fit = "Options",
		icons = {
			{ "Interface\\Icons\\Trade_Engineering" },
			{ "Interface\\Icons\\INV_Misc_Gear_01", "later art: worth proving on Era" },
			{ "Interface\\Icons\\INV_Misc_Wrench_01" },
			{ "Interface\\Icons\\Ability_Repair" },
		},
	},

	{
		title = "About", fit = "About",
		icons = {
			{ "Interface\\Icons\\INV_Misc_Book_09" },
			{ "Interface\\Icons\\INV_Misc_Book_07" },
			{ "Interface\\Icons\\INV_Misc_QuestionMark" },
			{ "Interface\\Common\\help-i", "uncertain path" },
		},
	},

	{
		title = "Reputations",
		note = "The other hard one. Reputation predates the art that would name it.",
		icons = {
			{ "Interface\\Icons\\Achievement_Reputation_01", "expected absent on Era" },
			{ "Interface\\Icons\\Achievement_Reputation_08", "likewise" },
			{ "Interface\\GossipFrame\\TabardGossipIcon", "transparent" },
			{ "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
			{ "Interface\\Icons\\INV_BannerPVP_03" },
			{ "Interface\\Icons\\Spell_Holy_ChampionsBond" },
			{ "Interface\\Icons\\INV_Jewelry_Talisman_08" },
			{ "Interface\\Icons\\INV_Misc_Note_02" },
		},
	},

	{
		title = "Quests",
		icons = {
			{ "Interface\\GossipFrame\\ActiveQuestIcon", "transparent" },
			{ "Interface\\GossipFrame\\AvailableQuestIcon", "transparent" },
			{ "Interface\\Icons\\INV_Misc_Note_03" },
			{ "Interface\\QuestFrame\\UI-QuestLog-BookIcon", "uncertain path" },
		},
	},

	{
		title = "Summary column sets",
		note = "The tightest row in the addon. Icons could buy width here rather than cost "
			.. "it, so these matter more than the tab ones.",
		icons = {
			{ "Interface\\Icons\\INV_Misc_Spyglass_02", "Overview" },
			{ "Interface\\Icons\\INV_Misc_Bag_08", "Bags" },
			{ "Interface\\Icons\\INV_Misc_PocketWatch_01", "Activity" },
			{ "Interface\\Icons\\Ability_Rogue_Sprint", "Activity" },
			{ "Interface\\Icons\\INV_Letter_15", "Activity - mail" },
			{ "Interface\\Icons\\INV_Misc_Coin_01", "Currencies" },
			{ "Interface\\Icons\\INV_Misc_Coin_02", "Currencies" },
			{ "Interface\\Icons\\INV_Misc_Gear_02", "Miscellaneous" },
		},
	},

	{
		title = "Faction",
		note = "The last two are wide, not square: they are drawn from part of a sheet and "
			.. "will look stretched here even where they exist.",
		icons = {
			{ "Interface\\Icons\\INV_BannerPVP_01", "Alliance" },
			{ "Interface\\Icons\\INV_BannerPVP_02", "Horde" },
			{ "Interface\\WorldStateFrame\\AllianceIcon", "uncertain path" },
			{ "Interface\\WorldStateFrame\\HordeIcon", "uncertain path" },
			{ "Interface\\TargetingFrame\\UI-PVP-Alliance", "not square" },
			{ "Interface\\TargetingFrame\\UI-PVP-Horde", "not square" },
		},
	},

	{
		title = "The minimap tracking set",
		note = "Flat monochrome symbols on transparency. They read better at 18 pixels than "
			.. "icon art does, and they are the most likely to differ between clients.",
		icons = {
			{ "Interface\\Minimap\\Tracking\\Class" },
			{ "Interface\\Minimap\\Tracking\\Profession" },
			{ "Interface\\Minimap\\Tracking\\Banker" },
			{ "Interface\\Minimap\\Tracking\\Mailbox" },
			{ "Interface\\Minimap\\Tracking\\Auctioneer" },
			{ "Interface\\Minimap\\Tracking\\Trainer" },
			{ "Interface\\Minimap\\Tracking\\Repair" },
			{ "Interface\\Minimap\\Tracking\\Innkeeper" },
			{ "Interface\\Minimap\\Tracking\\StableMaster" },
			{ "Interface\\Minimap\\Tracking\\BattleMaster" },
			{ "Interface\\Minimap\\Tracking\\FlightMaster" },
			{ "Interface\\Minimap\\Tracking\\Vendor" },
			{ "Interface\\Minimap\\Tracking\\Reagents" },
			{ "Interface\\Minimap\\Tracking\\Target" },
		},
	},
}

local TAB_LABELS = {
	"Summary", "Abilities & Talents", "Possessions", "Professions",
	"Character", "Wide Family", "Guild", "Options", "About",
}

--------------------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------------------

local function say(fmt, ...)
	print("|cff66bbffFamily icon sheet|r: " .. string.format(fmt, ...))
end

-- SetColorTexture is the modern spelling and all three clients have it, but this file exists
-- precisely because "all three clients have it" is a claim rather than a fact until it is
-- checked, so it is checked.
local function paint(texture, r, g, b, a)
	if type(texture.SetColorTexture) == "function" then
		texture:SetColorTexture(r, g, b, a or 1)
	else
		texture:SetTexture(r, g, b, a or 1)
	end
end

local function shortName(path)
	return (path:match("([^\\]+)$")) or path
end

local BACKINGS = {
	{ name = "magenta", r = 1, g = 0, b = 1 },
	{ name = "black",   r = 0, g = 0, b = 0 },
	{ name = "white",   r = 1, g = 1, b = 1 },
}

local function db()
	FamilyIconSheetDB = FamilyIconSheetDB or {}
	FamilyIconSheetDB.chosen = FamilyIconSheetDB.chosen or {}
	FamilyIconSheetDB.backing = FamilyIconSheetDB.backing or 1
	return FamilyIconSheetDB
end

--------------------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------------------

local sheet = CreateFrame("Frame", "FamilyIconSheet", UIParent,
	"BasicFrameTemplateWithInset")
sheet:SetSize(WIDTH, HEIGHT)
sheet:SetPoint("CENTER")
sheet:SetMovable(true)
sheet:EnableMouse(true)
sheet:RegisterForDrag("LeftButton")
sheet:SetScript("OnDragStart", sheet.StartMoving)
sheet:SetScript("OnDragStop", sheet.StopMovingOrSizing)
sheet:SetClampedToScreen(true)
sheet:SetFrameStrata("HIGH")
sheet:SetToplevel(true)
sheet:Hide()
sheet.TitleText:SetText("Family - icon contact sheet")
tinsert(UISpecialFrames, "FamilyIconSheet")

-- Which client this is, written on the sheet itself. A screenshot that does not say which
-- client it came from is three screenshots that cannot be told apart afterwards.
local client = sheet:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
client:SetPoint("TOPLEFT", 12, -32)
do
	local version, build, _, interface = GetBuildInfo()
	client:SetText(string.format("%s%s  (build %s, interface %s)|r",
		GOLD, tostring(version), tostring(build), tostring(interface)))
end

local legend = sheet:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
legend:SetPoint("TOPLEFT", client, "BOTTOMLEFT", 0, -3)
legend:SetWidth(WIDTH - 24)
legend:SetJustifyH("LEFT")
legend:SetText("A cell that is nothing but backing colour is a path this client does not "
	.. "have. Transparent art shows backing around the symbol - that is not a miss. "
	.. "Left size is 32, right size is 18: the size a tab icon really is.")

--------------------------------------------------------------------------------------------
-- The try-anything box, and the buttons
--------------------------------------------------------------------------------------------

local tryBox = CreateFrame("EditBox", nil, sheet, "InputBoxTemplate")
tryBox:SetSize(330, 20)
tryBox:SetPoint("TOPLEFT", legend, "BOTTOMLEFT", 6, -20)
tryBox:SetAutoFocus(false)
tryBox:SetScript("OnEscapePressed", tryBox.ClearFocus)

local tryLabel = sheet:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
tryLabel:SetPoint("BOTTOMLEFT", tryBox, "TOPLEFT", -4, 2)
tryLabel:SetText("try a path (or, where the client has atlases, an atlas name)")

local tryBacking = sheet:CreateTexture(nil, "BACKGROUND")
tryBacking:SetSize(BIG, BIG)
tryBacking:SetPoint("LEFT", tryBox, "RIGHT", 10, 0)

local tryIcon = sheet:CreateTexture(nil, "ARTWORK")
tryIcon:SetAllPoints(tryBacking)

local tryResult = sheet:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
tryResult:SetPoint("LEFT", tryBacking, "RIGHT", 8, 0)
tryResult:SetWidth(300)
tryResult:SetJustifyH("LEFT")

tryBox:SetScript("OnEnterPressed", function(box)
	local text = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		tryIcon:SetTexture(nil)
		tryResult:SetText("")
		return
	end

	-- The word here is the client's own texture-atlas API - C_Texture.GetAtlasInfo and
	-- SetAtlas - and has nothing to do with the addon of the same name. A sweep removing
	-- other people's addons from this tree will match it; it is not one of them, and a
	-- Blizzard call cannot be renamed. docs/LESSONS.md L-007 says so where a sweep will
	-- read it.
	--
	-- An atlas name is the one texture question that can be answered honestly, because
	-- GetAtlasInfo returns nil for one that does not exist. Paths get no such courtesy.
	local atlas
	if type(C_Texture) == "table" and type(C_Texture.GetAtlasInfo) == "function" then
		atlas = C_Texture.GetAtlasInfo(text)
	end

	if atlas and type(tryIcon.SetAtlas) == "function" then
		tryIcon:SetAtlas(text)
		tryResult:SetText(GREEN .. "drawn as an atlas|r " .. GREY
			.. "- the client confirmed this one exists|r")
	else
		tryIcon:SetTexture(text)
		tryResult:SetText(GREY .. "drawn as a path - the client cannot say whether it "
			.. "exists, so look at it|r")
	end
	box:ClearFocus()
end)

local function makeButton(text, width, anchor, x, y)
	local button = CreateFrame("Button", nil, sheet, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", x, y)
	button:SetText(text)
	return button
end

local backingButton = makeButton("Backing: magenta", 130, sheet, -12, -74)
local printButton = makeButton("Print chosen", 110, backingButton, 0, -25)
local clearButton = makeButton("Clear chosen", 110, printButton, 0, -25)

--------------------------------------------------------------------------------------------
-- The grid
--------------------------------------------------------------------------------------------

local scroll = CreateFrame("ScrollFrame", nil, sheet, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -152)
scroll:SetPoint("BOTTOMRIGHT", -32, 10)

local list = CreateFrame("Frame", nil, scroll)
list:SetSize(1, 1)
scroll:SetScrollChild(list)

-- Scrolled by moving the frame rather than by finding its bar: which name a template gives
-- its scroll bar has changed more than once, and the scroll frame's own offset has not.
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(frame, delta)
	local range = frame:GetVerticalScrollRange() or 0
	local wanted = (frame:GetVerticalScroll() or 0) - (delta * 60)

	if wanted < 0 then wanted = 0 end
	if wanted > range then wanted = range end

	frame:SetVerticalScroll(wanted)
end)

local cells, headings = {}, {}

local function applyChosen(cell)
	local chosen = db().chosen[cell.path] and true or false
	cell.check:SetShown(chosen)
	cell.name:SetTextColor(chosen and 1 or 0.6, chosen and 0.82 or 0.6,
		chosen and 0 or 0.6)
end

local function newCell(index)
	local cell = cells[index]
	if cell then return cell end

	cell = CreateFrame("Button", nil, list)
	cell:SetSize(CELL_W, CELL_H)
	cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

	cell.bigBacking = cell:CreateTexture(nil, "BACKGROUND")
	cell.bigBacking:SetSize(BIG, BIG)
	cell.bigBacking:SetPoint("TOPLEFT", 6, -4)

	cell.big = cell:CreateTexture(nil, "ARTWORK")
	cell.big:SetAllPoints(cell.bigBacking)

	cell.smallBacking = cell:CreateTexture(nil, "BACKGROUND")
	cell.smallBacking:SetSize(SMALL, SMALL)
	cell.smallBacking:SetPoint("TOPLEFT", cell.bigBacking, "TOPRIGHT", 8, -7)

	cell.small = cell:CreateTexture(nil, "ARTWORK")
	cell.small:SetAllPoints(cell.smallBacking)

	cell.check = cell:CreateTexture(nil, "OVERLAY")
	cell.check:SetSize(20, 20)
	cell.check:SetPoint("TOPRIGHT", -2, 0)
	cell.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	cell.check:Hide()

	cell.name = cell:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	cell.name:SetPoint("TOPLEFT", 4, -40)
	cell.name:SetWidth(CELL_W - 8)
	cell.name:SetJustifyH("LEFT")
	cell.name:SetJustifyV("TOP")

	cell:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(shortName(self.path))
		GameTooltip:AddLine(self.path, 0.6, 0.6, 0.6, true)
		if self.note then GameTooltip:AddLine(self.note, 1, 0.82, 0, true) end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(db().chosen[self.path] and "chosen - click to unchoose"
			or "click to choose", 0.4, 0.7, 1)
		GameTooltip:Show()
	end)
	cell:SetScript("OnLeave", GameTooltip_Hide or function() GameTooltip:Hide() end)
	cell:SetScript("OnClick", function(self)
		local chosen = db().chosen
		chosen[self.path] = (not chosen[self.path]) or nil
		applyChosen(self)
		if sheet.RefreshFit then sheet:RefreshFit() end
		say("%s %s", chosen[self.path] and "chosen:" or "unchosen:", self.path)
	end)

	cells[index] = cell
	return cell
end

local function newHeading(index)
	local heading = headings[index]
	if heading then return heading end

	heading = {}
	heading.title = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	heading.title:SetJustifyH("LEFT")
	heading.note = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	heading.note:SetJustifyH("LEFT")

	headings[index] = heading
	return heading
end

--------------------------------------------------------------------------------------------
-- The tab fit test
--
-- Not a contact sheet: a measurement. Eight real buttons at the real size, each with the
-- real label and 22 pixels taken off the front for an icon, and the client asked how wide
-- the text came out. This is the one part of the icon question that does not need eyes.
--------------------------------------------------------------------------------------------

local fitHeading, fitNote
local fitButtons = {}

local function chosenIn(groupTitle)
	for _, group in ipairs(GROUPS) do
		if group.fit == groupTitle then
			for _, entry in ipairs(group.icons) do
				if db().chosen[entry[1]] then return entry[1] end
			end
		end
	end
	return nil
end

local function newFitButton(index)
	local button = fitButtons[index]
	if button then return button end

	button = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
	button:SetSize(TAB_W, TAB_H)

	button.icon = button:CreateTexture(nil, "OVERLAY")
	button.icon:SetSize(TAB_ICON, TAB_ICON)
	button.icon:SetPoint("LEFT", 5, 0)

	local text = button:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("LEFT", TAB_TEXT_INSET, 0)
		text:SetPoint("RIGHT", -4, 0)
		text:SetJustifyH("LEFT")
	end

	button.verdict = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	button.verdict:SetJustifyH("LEFT")

	fitButtons[index] = button
	return button
end

--------------------------------------------------------------------------------------------
-- Laying it out
--------------------------------------------------------------------------------------------

function sheet:RefreshFit()
	local room = TAB_W - TAB_TEXT_INSET - 4

	for index, label in ipairs(TAB_LABELS) do
		local button = fitButtons[index]
		if button then
			local path = chosenIn(label)
			button.icon:SetTexture(path or "Interface\\Icons\\INV_Misc_QuestionMark")

			local text = button:GetFontString()
			local width = text and text:GetStringWidth() or 0
			local fits = width <= room

			button.verdict:SetText(string.format("%s%.0f of %d px%s%s",
				fits and GREY or RED, width, room,
				fits and " - fits" or " - CLIPS",
				path and "" or ("  " .. GREY .. "(no icon chosen yet)|r")))
		end
	end
end

function sheet:Rebuild()
	local backing = BACKINGS[db().backing] or BACKINGS[1]
	backingButton:SetText("Backing: " .. backing.name)
	paint(tryBacking, backing.r, backing.g, backing.b)

	local width = math.max(scroll:GetWidth() - 8, CELL_W)
	list:SetWidth(width)

	local perRow = math.max(math.floor(width / CELL_W), 1)
	local cell, heading, y = 0, 0, 0

	for _, group in ipairs(GROUPS) do
		heading = heading + 1
		local block = newHeading(heading)

		block.title:ClearAllPoints()
		block.title:SetPoint("TOPLEFT", 2, -y)
		block.title:SetWidth(width - 4)
		block.title:SetText(GOLD .. group.title .. "|r")
		block.title:Show()
		y = y + 18

		if group.note then
			block.note:ClearAllPoints()
			block.note:SetPoint("TOPLEFT", 2, -y)
			block.note:SetWidth(width - 4)
			block.note:SetText(group.note)
			block.note:Show()
			y = y + math.max(block.note:GetStringHeight() or 10, 10) + 2
		else
			block.note:Hide()
		end

		local column = 0
		for _, entry in ipairs(group.icons) do
			cell = cell + 1
			local widget = newCell(cell)

			widget.path = entry[1]
			widget.note = entry[2]
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", column * CELL_W, -y)
			widget.big:SetTexture(entry[1])
			widget.small:SetTexture(entry[1])
			paint(widget.bigBacking, backing.r, backing.g, backing.b)
			paint(widget.smallBacking, backing.r, backing.g, backing.b)
			widget.name:SetText(shortName(entry[1]))
			applyChosen(widget)
			widget:Show()

			column = column + 1
			if column >= perRow then
				column = 0
				y = y + CELL_H
			end
		end
		if column > 0 then y = y + CELL_H end
		y = y + 10
	end

	-- The fit test
	y = y + 8
	if not fitHeading then
		fitHeading = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fitHeading:SetJustifyH("LEFT")
		fitNote = list:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		fitNote:SetJustifyH("LEFT")
	end

	fitHeading:ClearAllPoints()
	fitHeading:SetPoint("TOPLEFT", 2, -y)
	fitHeading:SetText(GOLD .. "Does the label still fit?|r")
	y = y + 18

	fitNote:ClearAllPoints()
	fitNote:SetPoint("TOPLEFT", 2, -y)
	fitNote:SetWidth(width - 4)
	fitNote:SetText(string.format("Real buttons at the real %dx%d, with %d pixels taken off "
		.. "the front for a %d pixel icon. Measured, not eyeballed - and it is measured "
		.. "with this client's font, so the answer can differ between the three. Choose an "
		.. "icon above and it appears here.", TAB_W, TAB_H, TAB_TEXT_INSET, TAB_ICON))
	y = y + math.max(fitNote:GetStringHeight() or 10, 10) + 8

	for index, label in ipairs(TAB_LABELS) do
		local button = newFitButton(index)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", 2, -y)
		button:SetText(label)
		button:Show()

		button.verdict:ClearAllPoints()
		button.verdict:SetPoint("LEFT", button, "RIGHT", 10, 0)
		button.verdict:SetWidth(280)
		button.verdict:Show()

		y = y + TAB_H + 4
	end

	self:RefreshFit()

	for index = cell + 1, #cells do cells[index]:Hide() end
	for index = heading + 1, #headings do
		headings[index].title:Hide()
		headings[index].note:Hide()
	end

	list:SetHeight(math.max(y + 10, 1))
end

--------------------------------------------------------------------------------------------
-- The buttons' work
--------------------------------------------------------------------------------------------

backingButton:SetScript("OnClick", function()
	local data = db()
	data.backing = (data.backing % #BACKINGS) + 1
	sheet:Rebuild()
end)

clearButton:SetScript("OnClick", function()
	db().chosen = {}
	sheet:Rebuild()
	say("choices cleared")
end)

-- Printed in the order the groups are written, with the group name against each, because a
-- bare list of twelve paths in the chat log is not a decision anybody can act on a week
-- later. What comes out is meant to be pasted straight into a table.
local function printChosen()
	local chosen = db().chosen
	local version = GetBuildInfo()
	local any = false

	say("chosen on %s:", tostring(version))
	for _, group in ipairs(GROUPS) do
		local printedHeading = false
		for _, entry in ipairs(group.icons) do
			if chosen[entry[1]] then
				if not printedHeading then
					print(string.format("  %s-- %s|r", GREY, group.title))
					printedHeading = true
				end
				print(string.format("  %s\"%s\",|r", GOLD, entry[1]:gsub("\\", "\\\\")))
				any = true
			end
		end
	end

	if not any then
		print("  " .. GREY .. "nothing chosen yet - click the cells that rendered|r")
	end
end

printButton:SetScript("OnClick", printChosen)

--------------------------------------------------------------------------------------------

sheet:SetScript("OnShow", function(self) self:Rebuild() end)

SLASH_FAMILYICONSHEET1 = "/iconsheet"
SLASH_FAMILYICONSHEET2 = "/fis"
SlashCmdList["FAMILYICONSHEET"] = function(argument)
	argument = (argument or ""):lower()

	if argument == "print" then
		printChosen()
		return
	end

	if sheet:IsShown() then sheet:Hide() else sheet:Show() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")
	db()
	say("loaded. |cffffd700/iconsheet|r opens it. Screenshot it once per client.")
end)
