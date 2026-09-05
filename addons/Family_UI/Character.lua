-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- One member, and the things about them that are neither possessions nor professions: what
-- they are wearing, who likes them, what they are in the middle of, and what they have
-- finished.
--
-- Sections rather than tabs. They are all "about this member", and a tab strip that grew an
-- entry every time a scanner was written would say less, not more. What they can cast used
-- to be here too and has moved next door, to sit with the talents: a spellbook and a talent
-- tree are the same question asked twice.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 16

-- The character sheet, in the arrangement the game uses: a column down each side and the
-- weapons along the bottom. Drawn that way rather than as a list because that is where
-- everybody already knows to look for their boots, and because an empty slot in the right
-- place is a great deal more obvious than a row saying "empty".
--
-- Each entry is { slot id, the client's own name for it, the game's own empty picture }.
-- Slot names are localised globals, so the labels work in every language; the picture names
-- are Blizzard's own file names and are not.
local LEFT_SLOTS = {
	{ 1,  "HEADSLOT",     "Head" },
	{ 2,  "NECKSLOT",     "Neck" },
	{ 3,  "SHOULDERSLOT", "Shoulder" },
	{ 15, "BACKSLOT",     "Chest" },
	{ 5,  "CHESTSLOT",    "Chest" },
	{ 4,  "SHIRTSLOT",    "Shirt" },
	{ 19, "TABARDSLOT",   "Tabard" },
	{ 9,  "WRISTSLOT",    "Wrists" },
}

local RIGHT_SLOTS = {
	{ 10, "HANDSSLOT",    "Hands" },
	{ 6,  "WAISTSLOT",    "Waist" },
	{ 7,  "LEGSSLOT",     "Legs" },
	{ 8,  "FEETSLOT",     "Feet" },
	{ 11, "FINGER0SLOT",  "Finger" },
	{ 12, "FINGER1SLOT",  "Finger" },
	{ 13, "TRINKET0SLOT", "Trinket" },
	{ 14, "TRINKET1SLOT", "Trinket" },
}

local BOTTOM_SLOTS = {
	{ 16, "MAINHANDSLOT",      "MainHand" },
	{ 17, "SECONDARYHANDSLOT", "SecondaryHand" },
	{ 18, "RANGEDSLOT",        "Ranged" },
}

-- The same size the talents are drawn at. Bigger looked like a character sheet and read
-- like one thing per screen; at this size the whole of somebody's gear is one glance, which
-- is what a panel about somebody else is for.
local GEAR = 32
local GEAR_GAP = 4
local MIDDLE = 250       -- room for a name, a class and a side, and no more

-- The same slots again, in one list, in the order the game's own character sheet reads them:
-- down the left, down the right, then the weapons. That order is the whole reason a row of
-- twenty icons is legible without a label on any of them - everybody's boots are in the same
-- place, so a gap is a gap in a slot you can name.
local FAMILY_ORDER = {}
for _, set in ipairs { LEFT_SLOTS, RIGHT_SLOTS, BOTTOM_SLOTS } do
	for _, entry in ipairs(set) do FAMILY_ORDER[#FAMILY_ORDER + 1] = entry end
end

-- Smaller than the paper doll's, because twenty of these have to fit across the panel and
-- twenty members have to fit down it. This is the size at which both are true.
local GRID = 26
local GRID_GAP = 2
local GRID_ROW = GRID + 6

local SECTIONS = { "Equipped gear", "Currencies", "Reputations", "Quests", "Achievements" }

-- Pictures for the sections, chosen from `tools/FamilyIconSheet` and looked at on all three
-- clients - the same provenance, and the same reason, as the tab strip's (Window.lua). No two
-- may be alike, for the reason the tab strip's may not, and the harness checks it.
--
-- Achievements is the one worth a note. Its picture is achievement-era art, which is exactly
-- what neither Era nor Burning Crusade is expected to have - and it cannot matter here,
-- because the Achievements button is not built at all on a client with no achievements (§2.3,
-- below), which is both of them. The one candidate that might be missing is drawn only on the
-- one client that certainly has it.
--
-- A section with no entry keeps its label centred, as all of them did before there were any
-- pictures. There are none such today; the code stays because the next section added will be
-- one until somebody has looked at a candidate for it.
local SECTION_ICONS = {
	["Equipped gear"] = "Interface\\Icons\\INV_Chest_Chain",
	-- Currencies is the one that cost a round trip. INV_Misc_Coin_17 was chosen for it and
	-- drew nothing at all on Burning Crusade - this file's own rule arriving in person - so
	-- the replacement comes from the minimap tracking set, which is flat monochrome art on
	-- transparency and the part of the sheet that reads best at this size. It sits beside the
	-- Professions tab, which is drawn from the same set.
	Currencies        = "Interface\\Minimap\\Tracking\\BattleMaster",
	Reputations       = "Interface\\Icons\\INV_BannerPVP_03",
	Quests            = "Interface\\GossipFrame\\ActiveQuestIcon",
	Achievements      = "Interface\\Icons\\Achievement_Character_Human_Male",
}

UI.SECTION_ICONS = SECTION_ICONS

-- Wider than they were by what the picture takes, for the reason the tab strip grew: sized
-- down instead, "Equipped gear" would have been the label to go.
local SECTION_W = 122
local SECTION_STEP = SECTION_W + 2
local SECTION_ICON = 14
local SECTION_INSET = 19

-- Whom the member button offers: ours, and everyone a linked family shares with us.
local function membersKnown()
	return UI:EveryMember()
end

-- Everyone the gear grid draws: our own members, then each linked family's siblings under
-- their own name (§6). Our own are one group with no heading, because a heading over the
-- only group that is not somebody else's would be labelling the ordinary case.
--
-- Ours, strictly - not the list the member button offers. The two were the same call for a
-- while and this grid was the loser: a shared member landed in the group that has no heading,
-- which is the one place on this screen where whose somebody is cannot be seen at all.
-- The faction whose people are all showing, if any. On the panel rather than on a row, because
-- rows are pooled and a row would carry it into whatever is drawn next.
UI:OnFold("character", function()
	UI.__openFaction = nil
end)

-- How many of a faction's people are shown before the rest are folded away, and how much room
-- their standing needs beside them. Three, because the ask was three and because a faction a
-- family of forty has all met is forty lines nobody scrolls past.
local FACTION_PEOPLE = 3
local FACTION_RIGHT = 200

local function gearRoster()
	local groups = { { name = nil, members = UI:OurMembers() } }

	local byFamily, order = {}, {}
	for _, sibling in ipairs(Family.Wide:Siblings()) do
		local group = byFamily[sibling.family]
		if not group then
			group = { name = sibling.familyName or L["another family"], members = {},
				borrowed = true }
			byFamily[sibling.family] = group
			order[#order + 1] = group
		end
		group.members[#group.members + 1] =
			{ key = sibling.key, meta = sibling.meta, familyName = group.name }
	end

	table.sort(order, function(a, b) return tostring(a.name) < tostring(b.name) end)
	for _, group in ipairs(order) do
		table.sort(group.members, function(a, b)
			return tostring(a.meta.name or a.key) < tostring(b.meta.name or b.key)
		end)
		groups[#groups + 1] = group
	end

	return groups
end

-- The game's own class pictures, which live in one file with a set of coordinates per class.
-- Asked for by class file name so it is right in every language, and given up on rather than
-- guessed at where the coordinates are missing: a wrong corner of that file is a picture of
-- somebody else's class, which is worse than a question mark.
local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local function drawClassIcon(texture, classFile)
	local coords = _G.CLASS_ICON_TCOORDS
	local box = classFile and coords and coords[classFile]

	if box then
		texture:SetTexture(CLASS_SHEET)
		if texture.SetTexCoord then
			texture:SetTexCoord(box[1], box[2], box[3], box[4])
		end
		return true
	end

	texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	if texture.SetTexCoord then texture:SetTexCoord(0, 1, 0, 1) end
	return false
end

-- The client's own word for a standing, so "Revered" is whatever the player calls it.
local function standingLabel(standing)
	local label = _G["FACTION_STANDING_LABEL" .. tostring(standing)]
	return label or string.format(L["standing %s"], tostring(standing))
end

local STANDING_COLOUR = {
	[1] = "|cffcc2222", [2] = "|cffff4400", [3] = "|cffee6622", [4] = "|cffffff00",
	[5] = "|cff00ff88", [6] = "|cff00ff88", [7] = "|cff00ff88", [8] = "|cff00ffcc",
}

--------------------------------------------------------------------------------------------

local function build(frame)
	local rows = {}
	local section = SECTIONS[1]
	local sectionButtons = {}

	-- Whether the gear section is showing one member as a character sheet or the whole
	-- family as rows. Two readings of the same record rather than two panels (§4.3.1), so it
	-- is a switch on this panel and not a tab of its own.
	local familyMode = false

	-- What the family grid is filtered to, or nil for everything. Held as the value rather
	-- than as an index into a list, because the list is whatever the family happens to have
	-- and it changes underneath: an index would silently come to mean a different realm.
	local realmFilter, classFilter

	-- Declared before the picker, which clears it. Written the other way round the closure
	-- captures a global that never gets set, and choosing a member errors on a nil.
	local search

	local picker = UI:CreateMemberPicker(frame, 200, membersKnown, function()
		UI:FoldEverything()
		if search then search:SetText("") end
		frame:Refresh()
	end)
	picker:SetPoint("TOPLEFT", 0, -2)

	-- One box, filtering whatever section is open. A reputation list on a played character
	-- and a spellbook are both far longer than a screen, and neither is worth scrolling.
	-- Named, like the other panels' filters, so a macro or a check can reach it without
	-- guessing which of several unnamed boxes belongs to which panel.
	-- The label goes in front of the box rather than after it.
	--
	-- A caption to the right of the field it captions is read after the thing it was meant to
	-- explain, which is the wrong order for the one control here whose purpose is not obvious
	-- from looking at it. It also left the caption floating between this box and whatever came
	-- next, belonging to neither.
	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", picker, "RIGHT", 16, 0)
	hint:SetText(L["filter"])

	search = CreateFrame("EditBox", "FamilyCharacterSearch", frame, "InputBoxTemplate")
	search:SetPoint("LEFT", hint, "RIGHT", 10, 0)
	search:SetSize(200, 20)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function() frame:Refresh() end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)


	----------------------------------------------------------------------------------------
	-- The gear section's two readings, and what filters the wide one
	--
	-- The realm and class filters take the place the member picker vacates, because in this
	-- mode the picker has nothing to choose: the panel is about everybody. Nothing is added
	-- to the row of controls that was not already there, and the mode is the only new one.
	--
	-- Each is a button that steps through the values the family actually has, forwards on the
	-- left button and back on the right, with the current value written on it. A dropdown is
	-- the game's own control for this and Family has none yet; the number of realms a family
	-- spans is small enough that stepping is not a hardship, and a button that says what it
	-- is set to is at least never a mystery.
	----------------------------------------------------------------------------------------

	local wholeFamily = CreateFrame("Button", "FamilyGearWholeFamily", frame,
		"UIPanelButtonTemplate")
	wholeFamily:SetSize(120, 22)
	wholeFamily:SetPoint("TOPRIGHT", -4, -2)
	wholeFamily:SetText(L["Whole family"])
	UI:FitButton(wholeFamily, 120)
	wholeFamily:SetScript("OnClick", function()
		familyMode = not familyMode
		frame:Refresh()
	end)

	-- What the family has, which is what may be filtered on. Offering a warlock filter to a
	-- family with no warlock would be offering a way to show nothing.
	local function choicesIn(roster)
		local realms, classes, seenRealm, seenClass = {}, {}, {}, {}

		for _, group in ipairs(roster) do
			for _, member in ipairs(group.members) do
				local realm = member.meta.realm
				if realm and not seenRealm[realm] then
					seenRealm[realm] = true
					realms[#realms + 1] = realm
				end

				local class = member.meta.classFile
				if class and not seenClass[class] then
					seenClass[class] = true
					classes[#classes + 1] = class
				end
			end
		end

		table.sort(realms)
		table.sort(classes)
		return realms, classes
	end

	-- Two lists rather than two buttons that step through the values one click at a time.
	--
	-- Stepping was fine for the two or three realms this was written against and unusable at
	-- eleven classes, and it had a worse fault than that: the button showed the current value
	-- and a button's label has no width, so the first realm called "Pyrewood Village" wrote
	-- itself straight through the side of it. Both are fixed in ChoicePicker.lua, and fixed
	-- for whatever asks next rather than here.
	local realmButton = UI:CreateChoicePicker(frame, 150, L["Realm"], "all", function()
		local realms = choicesIn(gearRoster())
		local list = {}
		for _, realm in ipairs(realms) do
			list[#list + 1] = { value = realm, label = realm }
		end
		return list
	end, function(value)
		realmFilter = value
		frame:Refresh()
	end)
	realmButton:SetPoint("TOPLEFT", 0, -2)

	-- Named as the client names them, and coloured as the game colours them: eleven class
	-- names in a list are read by colour long before they are read by name.
	local classButton = UI:CreateChoicePicker(frame, 150, L["Class"], "all", function()
		local _, classes = choicesIn(gearRoster())
		local names = _G.LOCALIZED_CLASS_NAMES_MALE
		local list = {}
		for _, classFile in ipairs(classes) do
			local red, green, blue = UI:ClassColour(classFile)
			list[#list + 1] = {
				value = classFile,
				label = (names and names[classFile]) or classFile,
				r = red, g = green, b = blue,
			}
		end
		return list
	end, function(value)
		classFilter = value
		frame:Refresh()
	end)
	classButton:SetPoint("LEFT", realmButton, "RIGHT", 6, 0)

	local function matches(text)
		local needle = (search:GetText() or ""):lower()
		if needle == "" then return true end
		return type(text) == "string" and text:lower():find(needle, 1, true) ~= nil
	end

	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -6)
	bar:SetPoint("RIGHT", -8, 0)
	bar:SetHeight(24)

	-- Achievements are absent, not empty, on a client that has none (§2.3) - so the button
	-- is not drawn at all rather than offered and then apologised for.
	local sectionRow = {}
	for _, name in ipairs(SECTIONS) do
		if name ~= "Achievements" or Family.Capabilities:Has("achievements") then
			local button = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
			button:SetHeight(20)
			button:SetText(L[name])

			-- Only where there is a picture. A section without one keeps its label where
			-- the template put it, in the middle: this is a row rather than a column, so
			-- nothing has to line up with anything above or below it, and an inset held
			-- open for a picture that never comes just looks like a label pushed sideways.
			local path = SECTION_ICONS[name]
			if path then
				local icon = button:CreateTexture(nil, "ARTWORK")
				icon:SetSize(SECTION_ICON, SECTION_ICON)
				icon:SetPoint("LEFT", 4, 0)
				icon:SetTexture(path)
				button.icon = icon

				local text = button.GetFontString and button:GetFontString()
				if text then
					text:ClearAllPoints()
					text:SetPoint("LEFT", SECTION_INSET, 0)
					text:SetJustifyH("LEFT")
					if text.SetWordWrap then text:SetWordWrap(false) end
					button.__labelInset = SECTION_INSET
				end
			end

			button:SetScript("OnClick", function()
				section = name
				-- A filter typed for one section rarely means anything in the next,
				-- and a list that comes up empty because of a box you have stopped
				-- looking at reads as missing data.
				search:SetText("")
				-- And whatever was unfolded, folded: this is a different page, and
				-- clicking the section you are already on is how somebody asks for
				-- the page back. `Window.lua` carries the rule.
				UI:FoldEverything()
				frame:Refresh()
			end)
			sectionButtons[name] = button
			sectionRow[#sectionRow + 1] = button
		end
	end

	UI:LayOutRow(sectionRow, SECTION_W, SECTION_STEP - SECTION_W, 0,
		function(button, at, width)
			button:SetPoint("LEFT", at, 0)
			local text = button.icon and button.GetFontString and button:GetFontString()
			if text then text:SetWidth(width - SECTION_INSET - 4) end
		end, (UI.CONTENT_W or 740) - 16)

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 2, -4)
	status:SetPoint("RIGHT", -8, 0)
	status:SetJustifyH("LEFT")

	-- What the three columns mean, which differs per section. Without them the equipment
	-- list is three unlabelled columns of numbers and names.
	local HEADINGS = {
		-- The gear is drawn as a character sheet, where a column of headings would be
		-- three words over a picture of a helmet. Every slot says what it is by where it
		-- is, which is the whole point of drawing it that way.
		["Equipped gear"] = { "", "", "" },
		Currencies        = { L["Currency"], L["Held"], L["Of a cap of"] },
		Reputations       = { L["Faction"], L["Standing"], L["Progress"] },
		Quests            = { L["Level"], L["Quest"], L["Progress"] },
		Achievements      = { L["Category"], L["Achievement"], L["Points or progress"] },
	}

	-- Which sections have a whole-family reading as well as a per-member one, and what
	-- their columns are called when they are showing it. Gear draws a character sheet and
	-- keeps its three blanks; reputations become a list of factions rather than of members,
	-- so all three headings change.
	local FAMILY_SECTIONS = { ["Equipped gear"] = true, Reputations = true }
	local FAMILY_HEADINGS = {
		-- Faction, then who, then how far they got. It was faction / furthest / held by,
		-- which is the shape of a single winner rather than of a list of people.
		Reputations = { L["Faction"], L["Character"], L["Standing"] },
	}

	local headerRow = CreateFrame("Frame", nil, frame)
	headerRow:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -2, -4)
	-- Ends where the list ends, which is short of the panel by the width of the scroll bar.
	-- Anchored to the panel instead, every heading over a right-aligned column sat that far
	-- to the right of the figures underneath it.
	headerRow:SetPoint("RIGHT", -26, 0)
	headerRow:SetHeight(16)

	local headings = {}
	for index = 1, 3 do
		local text = headerRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		text:SetTextColor(1, 0.82, 0)
		headings[index] = text
	end
	headings[1]:SetPoint("LEFT", 4, 0)
	headings[1]:SetWidth(170)
	headings[1]:SetJustifyH("LEFT")
	headings[2]:SetPoint("LEFT", 180, 0)
	headings[2]:SetJustifyH("LEFT")
	headings[3]:SetPoint("RIGHT", -8, 0)
	headings[3]:SetWidth(140)
	headings[3]:SetJustifyH("RIGHT")

	-- The last column is right-aligned for numbers and left-aligned for words. Ranks and
	-- qualifiers ragged on the right read as though they were falling off the panel.
	local RIGHT_JUSTIFY = {
		["Equipped gear"] = "RIGHT", Reputations = "RIGHT",
		Quests = "RIGHT", Achievements = "LEFT", Currencies = "RIGHT",
	}

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	-- The paper doll's slots, which are buttons rather than rows and are pooled separately:
	-- nineteen of them exist for one section and none of the others has any use for one.
	local slots = {}

	local function gearSlot(index)
		local existing = slots[index]
		if existing then return existing end

		local button = CreateFrame("Button", nil, list)
		button:SetSize(GEAR, GEAR)

		button.border = button:CreateTexture(nil, "BACKGROUND")
		button.border:SetAllPoints()
		button.border:SetColorTexture(1, 1, 1, 0.05)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 2, -2)
		button.icon:SetPoint("BOTTOMRIGHT", -2, 2)

		button.level = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.level:SetPoint("BOTTOMRIGHT", -2, 2)

		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

		-- By the item string where there is one, which is what puts the enchant, the gems
		-- and the patch on the tooltip. By id for anything recorded before Family kept it,
		-- which describes the item as it left the vendor and is better than nothing.
		UI:AttachTooltip(button, function(self)
			if self.itemLink then return "itemlink", self.itemLink end
			return "item", self.itemID
		end)

		button:RegisterForClicks("LeftButtonUp")
		button:SetScript("OnClick", function(self)
			if self.memberKey == Family:CurrentMember() then
				Family:TryCall(ToggleCharacter, "PaperDollFrame")
				-- This one really does open a window of the game's own, and it opens it
				-- underneath this panel where clicking cannot reach it.
				UI:StepAside()
			end
		end)

		slots[index] = button
		return button
	end

	-- The family grid's cells, pooled separately from the paper doll's. They are a different
	-- size and there are two orders of magnitude more of them, and one pool holding both
	-- would mean every switch of mode resizing every button that had ever been made.
	--
	-- They are made as they are needed and then kept, so a family of forty costs its eight
	-- hundred buttons once and never again. The filters are the answer to a family large
	-- enough for that to matter, which is the other reason they are not a nicety.
	local gridCells = {}

	local function gridCell(index)
		local existing = gridCells[index]
		if existing then return existing end

		local button = CreateFrame("Button", nil, list)
		button:SetSize(GRID, GRID)

		button.border = button:CreateTexture(nil, "BACKGROUND")
		button.border:SetAllPoints()
		button.border:SetColorTexture(1, 1, 1, 0.05)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)

		-- Over the picture rather than beside it, because beside it there is no room: a row
		-- is twenty icons wide and the number has to live on one of them.
		button.level = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.level:SetPoint("BOTTOMRIGHT", -1, 1)

		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

		UI:AttachTooltip(button, function(self)
			if self.itemLink then return "itemlink", self.itemLink end
			if self.itemID then return "item", self.itemID end
			-- The class icon at the front of the row, and any empty slot: neither is an
			-- item, and both have something worth saying on hover.
			if self.lines then return nil, nil, self.lines end
			return nil
		end)

		gridCells[index] = button
		return button
	end

	local function row(index)
		local existing = rows[index]
		if existing then return existing end

		-- A button rather than a frame: rows in the quest section are clickable, and a
		-- frame cannot be clicked.
		local r = CreateFrame("Button", nil, list)
		r:SetHeight(ROW)
		r.left = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.left:SetPoint("LEFT", 4, 0)
		r.left:SetWidth(170)
		r.left:SetJustifyH("LEFT")

		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(ROW - 2, ROW - 2)
		r.icon:SetPoint("LEFT", 180, 0)

		r.middle = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.middle:SetPoint("LEFT", 180 + ROW + 2, 0)
		r.middle:SetJustifyH("LEFT")

		-- One row carries a piece of equipment in one section and a quest in another, so
		-- what to describe is decided per row rather than per section. The fallback lines
		-- are for the ones the game will not describe: a faction has no tooltip of its
		-- own, and what Family knows about it is worth showing on hover all the same.
		-- Clicking a quest opens it in the log and clicking a worn item opens the
		-- character sheet - for the member being played, and only for them. Somebody
		-- else's quest log is not open and their gear is not on anybody.
		r:RegisterForClicks("LeftButtonUp")
		-- Quests, and nothing else. Worn gear used to be a list of these rows and is a paper
		-- doll now, so the branch that opened the character sheet from here has had nothing
		-- to open it from for some time: no row in this panel carries an item. That click
		-- lives on the gear buttons themselves, where it can still happen.
		r:SetScript("OnClick", function(self)
			-- A faction with more people than fit, opened and closed again. The same
			-- unfolding the professions search does for a recipe more of the family can
			-- make than a line will hold, and kept on the panel rather than in the row so
			-- that a pooled row cannot carry it into whatever is drawn next.
			if self.expandFaction then
				UI.__openFaction = (UI.__openFaction ~= self.expandFaction)
					and self.expandFaction or nil
				frame:Refresh()
				return
			end

			if self.questID or self.questTitle then
				if UI:OpenQuest(self.memberKey, self.questID, self.questTitle) then
					UI:StepAside()
				end
			end
		end)

		-- Lit on hover, and only on the rows a click will actually do something to.
		--
		-- In the HIGHLIGHT layer rather than on an OnEnter script, because AttachTooltip
		-- below owns OnEnter and OnLeave and a second one would simply replace it: the game
		-- shows a highlight-layer texture on mouseover by itself, with nothing to collide
		-- with. Hidden by default and shown per row, since most rows here are reputations
		-- and currencies that click nowhere, and lighting those would promise something.
		r.highlight = r:CreateTexture(nil, "HIGHLIGHT")
		r.highlight:SetAllPoints()
		r.highlight:SetColorTexture(1, 1, 1, 0.10)
		r.highlight:Hide()

		UI:AttachTooltip(r, function(self)
			if self.itemID then return "item", self.itemID end
			if self.questID then return "quest", self.questID end
			if self.achievementID then
				return "achievement", self.achievementID, self.fallback
			end
			if self.currencyID then
				return "currency", self.currencyID, self.fallback
			end
			if self.fallback then return nil, nil, self.fallback end
			return nil
		end)

		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.right:SetPoint("RIGHT", -8, 0)
		r.right:SetWidth(140)
		r.right:SetJustifyH("RIGHT")

		UI:NoWrap(r.left, r.middle, r.right)

		rows[index] = r
		return r
	end

	function frame:Refresh()
		local member = picker:Reconcile()

		for name, button in pairs(sectionButtons) do
			UI:MarkSelected(button, name == section)
		end

		local labels = (familyMode and FAMILY_SECTIONS[section] and FAMILY_HEADINGS[section])
			or HEADINGS[section] or { "", "", "" }
		for index = 1, 3 do headings[index]:SetText(labels[index] or "") end

		local justify = RIGHT_JUSTIFY[section] or "RIGHT"
		headings[3]:SetJustifyH(justify)

		local used, y = 0, 0
		list:SetWidth(UI:ListWidth(scroll))

		-- Equipment is read by its pictures, so its rows are twice the height and carry an
		-- icon to match. The other sections are lists of words and a taller row would only
		-- mean fewer of them on screen.
		--
		-- The family grid is the exception: the rows that come out of this pool there are
		-- headings rather than members, and a heading is a line of text.
		local gearSection = section == "Equipped gear"

		-- Whether what is in front of the player is about the whole family. Two sections
		-- can be, and every control below asks this rather than asking about gear - which
		-- is what the whole of this used to ask, and what kept the switch off every other
		-- section that could have had it.
		local familyView = FAMILY_SECTIONS[section] and familyMode or false

		local height = (gearSection and not familyMode) and (ROW * 2) or ROW

		local function nextRow()
			used = used + 1
			local r = row(used)
			r:SetHeight(height)
			r.icon:SetSize(height - 4, height - 4)
			-- Put back where it was built, because the gear section moves it into the
			-- middle of the character sheet and every section after it would inherit
			-- that. A row is only ever borrowed.
			r.middle:ClearAllPoints()
			r.middle:SetPoint("LEFT", 180 + height + 2, 0)
			r:SetPoint("TOPLEFT", 0, -y)
			r:SetPoint("TOPRIGHT", 0, -y)
			r.middle:SetWidth(math.max(UI:ListWidth(scroll) - 360, 40))
			r.right:SetJustifyH(justify)
			-- Put back to the width it was built with. The reputations section widens it
			-- for its category names, and without this every later section inherited that.
			r.left:SetWidth(170)
			-- And the right one, for the same reason: the family reputations section
			-- widens it to hold a standing and a score together.
			r.right:SetWidth(140)
			r.expandFaction = nil
			r.itemID, r.spellID, r.questID = nil, nil, nil
			r.achievementID, r.fallback = nil, nil
			r.currencyID = nil
			r.questTitle, r.memberKey = nil, nil
			r.highlight:Hide()
			r.icon:SetTexture(nil)
			-- Wiped here rather than by each caller. A row that is shown but not written
			-- keeps whatever it last said, and a section that writes only two of the three
			-- columns would inherit the third from whatever was drawn there before.
			r.left:SetText("")
			r.middle:SetText("")
			r.right:SetText("")
			r:Show()
			y = y + height
			return r
		end

		local usedSlots, usedGrid = 0, 0

		local function finish(message)
			for index = used + 1, #rows do rows[index]:Hide() end
			for index = usedSlots + 1, #slots do slots[index]:Hide() end
			for index = usedGrid + 1, #gridCells do gridCells[index]:Hide() end
			list:SetHeight(math.max(y, 1))
			if message then status:SetText(message) end
		end

		------------------------------------------------------------------------------------
		-- Which controls the section in front of you actually has
		------------------------------------------------------------------------------------

		wholeFamily:SetShown(FAMILY_SECTIONS[section] and true or false)
		UI:MarkSelected(wholeFamily, familyView)
		realmButton:SetShown(familyView)
		classButton:SetShown(familyView)
		-- Nothing for it to choose when the panel is about everybody, and its space is
		-- exactly where the two filters go.
		picker:SetShown(not familyView)

		-- The filter box follows whatever is actually in front of it. Hung off the picker
		-- and left there, it stayed where the picker would have been - which in the whole
		-- family reading is underneath the two filters that replaced it.
		hint:ClearAllPoints()
		if familyView then
			hint:SetPoint("LEFT", classButton, "RIGHT", 16, 0)
		else
			hint:SetPoint("LEFT", picker, "RIGHT", 16, 0)
		end

		------------------------------------------------------------------------------------
		-- Everyone's gear at once (§4.3.1)
		--
		-- Before the check for a chosen member, and deliberately: a family whose only rows
		-- here are siblings has no member of its own to have chosen, and that is a family
		-- this screen has something to say to rather than one it should apologise to.
		------------------------------------------------------------------------------------

		if gearSection and familyView then
			local roster = gearRoster()

			local classNames = _G.LOCALIZED_CLASS_NAMES_MALE

			-- A realm stops existing the moment its last member is removed, and a filter
			-- still pointing at one would leave this panel empty with nothing on screen
			-- saying why. The pickers put themselves back to "all" rather than to a value
			-- nobody can see any more.
			realmFilter = realmButton:Reconcile()
			classFilter = classButton:Reconcile()

			-- Wide enough for a full row of slots even when the panel is not, so the last
			-- weapon is reachable by scrolling rather than simply absent.
			local rowWidth = 4 + GRID + 8 + (#FAMILY_ORDER * (GRID + GRID_GAP))
			list:SetWidth(math.max(UI:ListWidth(scroll), rowWidth))

			local function passes(entry)
				if realmFilter and entry.meta.realm ~= realmFilter then return false end
				if classFilter and entry.meta.classFile ~= classFilter then return false end
				return matches(entry.meta.name or entry.key)
			end

			local function placeCell(atX, atY)
				usedGrid = usedGrid + 1
				local cell = gridCell(usedGrid)

				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", atX, -atY)
				-- Wiped here rather than by each caller, for the reason the row pool wipes
				-- itself: a cell that is shown and not written keeps what it last said,
				-- and here that means one member wearing another's helmet.
				cell.itemID, cell.itemLink, cell.lines = nil, nil, nil
				cell.level:SetText("")
				cell.border:SetColorTexture(1, 1, 1, 0.05)
				if cell.icon.SetTexCoord then cell.icon:SetTexCoord(0, 1, 0, 1) end
				if cell.icon.SetDesaturated then cell.icon:SetDesaturated(false) end
				cell:Show()
				return cell
			end

			local shown, total, geared = 0, 0, 0

			for _, group in ipairs(roster) do
				local here = {}
				for _, entry in ipairs(group.members) do
					total = total + 1
					if passes(entry) then here[#here + 1] = entry end
				end

				if #here > 0 then
					-- Our own members get no heading; a linked family's do, because whose
					-- they are is never merged away (§6).
					if group.name then
						local heading = nextRow()
						heading.left:SetText("|cff88bbff" .. group.name .. "|r")
						heading.left:SetWidth(300)
					end

					--------------------------------------------------------------------
					-- And inside that, by side
					--
					-- On the summary's reasoning (Summary.lua): two characters on
					-- opposite sides have less to do with each other than two on
					-- different realms, and this panel is about what they are wearing,
					-- which they cannot hand one another.
					--
					-- Drawn as one flat block it read worse than that. The side was
					-- recorded and it was shown - but only on the tooltip of the class
					-- picture, so a family with one Horde character in it looked like a
					-- family that had lost them. The eye had nothing to find them by.
					--
					-- Where there is no split to make - one side, or one side left by
					-- the filters - no heading is drawn. And a member whose side was
					-- never recorded is not a third faction that would force one; they
					-- are a member Family has not finished reading.
					--------------------------------------------------------------------
					local known, count = 0, {}
					for _, entry in ipairs(here) do
						local side = entry.meta.faction or UI.UNKNOWN_SIDE
						if not count[side] then
							count[side] = 0
							if side ~= UI.UNKNOWN_SIDE then known = known + 1 end
						end
						count[side] = count[side] + 1
					end

					if known > 1 then
						-- By side and by nothing else. Inside a side the order is the
						-- order they arrived in, which is the order every other list of
						-- members on this panel is already in - table.sort settles ties
						-- however it likes, and "however it likes" reshuffles the whole
						-- family every time a filter is typed into.
						local arrived = {}
						for index, entry in ipairs(here) do arrived[entry] = index end

						table.sort(here, function(a, b)
							local first = UI.SIDE_ORDER[a.meta.faction
								or UI.UNKNOWN_SIDE] or 99
							local second = UI.SIDE_ORDER[b.meta.faction
								or UI.UNKNOWN_SIDE] or 99
							if first ~= second then return first < second end
							return arrived[a] < arrived[b]
						end)
					end

					local lastSide

					for _, entry in ipairs(here) do
						-- A side's heading goes where that side starts, which is wherever
						-- the one before it ran out.
						local side = entry.meta.faction or UI.UNKNOWN_SIDE
						if known > 1 and side ~= lastSide then
							-- A line's space between one side and the next, as on the
							-- summary. Without it two headings in a grid this dense are
							-- two rows of text among twelve rows of pictures.
							if lastSide then y = y + 6 end

							local colour = UI.SIDE_COLOUR[side]
								or { 0.8, 0.8, 0.8 }

							local sideHeading = nextRow()
							sideHeading.left:SetText(string.format(
								"|cff%02x%02x%02x%s|r  |cff888888(%d)|r",
								math.floor(colour[1] * 255 + 0.5),
								math.floor(colour[2] * 255 + 0.5),
								math.floor(colour[3] * 255 + 0.5),
								UI:SideName(side), count[side]))
							sideHeading.left:SetWidth(300)
							lastSide = side
						end

						shown = shown + 1

						local meta = entry.meta
						local payload = UI:Payload(entry.key) or {}
						local gear = payload.equipment
						if gear and gear.itemLevel then geared = geared + 1 end

						-- The class picture, and the only place this row says who it is
						-- about. Everything else on it is what they are wearing.
						local head = placeCell(4, y)
						drawClassIcon(head.icon, meta.classFile)

						local className = meta.classFile
							and ((classNames and classNames[meta.classFile])
								or meta.classFile)

						head.lines = {
							{ meta.name or entry.key,
								meta.realm and ("|cff888888" .. meta.realm .. "|r") or nil },
							{ string.format(L["|cff888888level %s|r  %s  %s"],
								tostring(meta.level or "?"),
								tostring(UI:RaceName(meta)),
								tostring(className or "")) },
							{ L["Average item level"],
								gear and gear.itemLevel
									and string.format("|cffffd700%.1f|r", gear.itemLevel)
									or L["|cff9d9d9dnot recorded|r"] },
						}

						if entry.familyName then
							head.lines[#head.lines + 1] =
								{ string.format(L["|cff888888of %s|r"], entry.familyName) }
						end

						if not gear then
							head.lines[#head.lines + 1] = { L["|cffffaa00Nothing recorded - "
								.. "log in on this member once.|r"] }
						end

						for index, slot in ipairs(FAMILY_ORDER) do
							local cell = placeCell(
								4 + GRID + 8 + (index - 1) * (GRID + GRID_GAP), y)

							local item = gear and gear.worn and gear.worn[slot[1]]

							if item then
								-- Asked for by id, and the panel redraws when the client
								-- answers, so a name and a border arrive together (§2.1).
								Family.Names:Item(item.id, "character", function()
									if frame:IsShown() then frame:Refresh() end
								end)

								cell.itemID = item.id
								cell.itemLink = item.item
								cell.icon:SetTexture(
									Family:TryCall(GetItemIcon, item.id)
									or "Interface\\Icons\\INV_Misc_QuestionMark")
								cell.level:SetText(item.itemLevel
									and ("|cffffd700" .. item.itemLevel .. "|r") or "")

								local quality = select(3,
									Family:TryCall(GetItemInfo, item.id))
								local colours = _G.ITEM_QUALITY_COLORS
								local colour = quality and colours and colours[quality]
								if colour then
									cell.border:SetColorTexture(colour.r, colour.g,
										colour.b, 0.7)
								end
							else
								cell.icon:SetTexture(
									"Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slot[3])
								if cell.icon.SetDesaturated then
									cell.icon:SetDesaturated(true)
								end
								-- An empty slot has no item to describe, and which slot
								-- it is is the whole of what somebody hovering wants.
								cell.lines = { { _G[slot[2]] or slot[2],
									L["|cff9d9d9dempty|r"] } }
							end
						end

						y = y + GRID_ROW
					end

					y = y + 4
				end
			end

			if shown == 0 then
				return finish(total == 0
					and L["|cff9d9d9dNothing recorded yet.|r"]
					or L["|cffffaa00Nothing matches those filters.|r"])
			end

			return finish(string.format(total == 1
				and L["|cffffd700%d|r of %d member   |cff888888|||r   %d with gear recorded"
					.. "   |cff888888|||r   |cff888888hover the class picture for who they "
					.. "are, and any slot for what is in it|r"]
				or L["|cffffd700%d|r of %d members   |cff888888|||r   %d with gear recorded"
					.. "   |cff888888|||r   |cff888888hover the class picture for who they "
					.. "are, and any slot for what is in it|r"],
				shown, total, geared))
		end

		------------------------------------------------------------------------------------
		-- Everyone's reputations at once
		--
		-- The per-member reading below answers "what has this character done"; this answers
		-- "has anybody done it", which is the question that actually gets asked - a pattern
		-- behind exalted, a quartermaster behind honoured. So the rows are factions rather
		-- than members, and each says how far the family has got and who got there.
		--
		-- Keyed by faction id where the client gave one. The name is the same faction in a
		-- different language on a shared character's record, and two rows for one faction is
		-- the fault §2.1 exists to prevent; the name is the fallback and nothing else.
		------------------------------------------------------------------------------------

		if section == "Reputations" and familyView then
			local byFaction, order = {}, {}
			local people = 0

			for _, group in ipairs(gearRoster()) do
				for _, entry in ipairs(group.members) do
					local meta = entry.meta or {}
					if (not realmFilter or meta.realm == realmFilter)
						and (not classFilter or meta.classFile == classFilter) then
						local reps = (UI:Payload(entry.key) or {}).reputations
						if reps and #reps > 0 then people = people + 1 end

						for _, faction in ipairs(reps or {}) do
							local id = faction.id and ("id:" .. faction.id)
								or ("name:" .. tostring(faction.name))
							local row = byFaction[id]

							if not row then
								row = { id = id, name = faction.name,
									category = faction.category, people = {} }
								byFaction[id] = row
								order[#order + 1] = row
							end

							-- Everybody who has met it, not the furthest of them.
							--
							-- The first version of this panel kept one holder per faction
							-- and showed how far the family had got. That answers "has
							-- anybody done it" and Alberto asked for the other question:
							-- a faction and *its people*, because the next thing you do
							-- with the answer is go and log in on one of them.
							row.people[#row.people + 1] = {
								entry = entry,
								standing = faction.standing,
								value = faction.value,
								maximum = faction.maximum,
							}

							-- A faction only some of them have met is still that faction.
							-- Its category comes from whoever had one, because a record
							-- from a client that never expanded that header carries none.
							row.category = row.category or faction.category
							row.name = row.name or faction.name
						end
					end
				end
			end

			local byCategory, categories, shown = {}, {}, 0
			for _, row in ipairs(order) do
				if matches(row.name) or matches(row.category) then
					local group = row.category or L["|cff888888Other|r"]
					if not byCategory[group] then
						byCategory[group] = {}
						categories[#categories + 1] = group
					end
					table.insert(byCategory[group], row)
					shown = shown + 1
				end
			end

			if shown == 0 then
				return finish(#order == 0
					and L["|cff9d9d9dNo reputation has been recorded for anybody yet.|r"]
					or L["|cffffaa00Nothing matches those filters.|r"])
			end

			table.sort(categories)

			-- Whose name goes on a line: the realm where they are not on ours, and the
			-- family where they are not ours, exactly as every other panel says it.
			local function labelFor(entry)
				local who = UI:NameOf(entry.meta or {})
				if entry.familyName then
					who = string.format(L["%s |cff9d9d9dof %s|r"], who,
						tostring(entry.familyName))
				end
				return who
			end

			for _, group in ipairs(categories) do
				local heading = nextRow()
				heading.left:SetText("|cff88bbff" .. group .. "|r")
				heading.left:SetWidth(220)
				heading.right:SetText("|cff888888" .. #byCategory[group] .. "|r")

				table.sort(byCategory[group], function(a, b)
					return (a.name or "") < (b.name or "")
				end)

				for _, row in ipairs(byCategory[group]) do
					-- Furthest first, and a name to settle the rest.
					--
					-- The single-holder version said outright that a name is never the
					-- tie-break, because two people at the same point is a tie the panel
					-- has no business inventing an order for. That was right about
					-- *picking a winner* and is wrong about drawing a list: an order that
					-- stops at its keys leaves the rest to `table.sort`'s own
					-- arrangement, and two draws of one page then disagree.
					table.sort(row.people, function(a, b)
						if a.standing ~= b.standing then
							return a.standing > b.standing
						end
						if (a.value or 0) ~= (b.value or 0) then
							return (a.value or 0) > (b.value or 0)
						end
						return tostring((a.entry.meta or {}).name)
							< tostring((b.entry.meta or {}).name)
					end)

					local open = UI.__openFaction == row.id
					local limit = open and #row.people
						or math.min(FACTION_PEOPLE, #row.people)
					local foldable = #row.people > FACTION_PEOPLE

					for index = 1, limit do
						local person = row.people[index]
						local held = person.entry.meta or {}

						local r = nextRow()
						r.memberKey = person.entry.key
						r.left:SetWidth(220)
						r.right:SetWidth(FACTION_RIGHT)

						-- The faction is written once, against its first person. Said
						-- again on every line it would read as a different faction each
						-- time, which is what a column of repeated words does.
						r.left:SetText(index == 1 and ("  " .. (row.name or "?")) or "")
						r.middle:SetText(labelFor(person.entry))

						local progress = person.maximum and person.maximum > 0
							and string.format(" |cff888888%d / %d|r", person.value or 0,
								person.maximum) or ""
						r.right:SetText((STANDING_COLOUR[person.standing] or "|cffdddddd")
							.. standingLabel(person.standing) .. "|r" .. progress)

						r.fallback = {
							{ row.name or "?" },
							{ group },
							{ held.name or person.entry.key or "?",
								standingLabel(person.standing) },
						}

						-- The faction's own line opens and closes the rest of it, which
						-- is where a click about the whole faction belongs.
						if foldable and index == 1 then
							r.expandFaction = row.id
							r.highlight:Show()
						end
					end

					if foldable then
						local r = nextRow()
						r.left:SetWidth(220)
						r.right:SetWidth(FACTION_RIGHT)
						r.middle:SetText(open and L["|cff888888fewer|r"]
							or string.format(L["|cff888888and %d more|r"],
								#row.people - limit))
						r.expandFaction = row.id
						r.highlight:Show()
					end
				end
			end

			return finish(string.format(L["|cffffd700%d|r of %d factions   |cff888888|||r"
				.. "   %d with reputations recorded"], shown, #order, people))
		end

		if not member then
			status:SetText(L["|cff9d9d9dNothing recorded yet.|r"])
			return finish()
		end

		local payload = UI:Payload(member.key) or {}

		----------------------------------------------------------------------------------

		if section == "Equipped gear" then
			local gear = payload.equipment
			if not gear or not gear.worn then
				return finish(L["|cffffaa00Nothing recorded - log in on this member once.|r"])
			end

			status:SetText(string.format(
				L["average item level |cffffd700%s|r over %d pieces"],
				gear.itemLevel and string.format("%.1f", gear.itemLevel) or "?",
				gear.counted or 0))

			-- A block of a fixed size rather than one stretched across the panel. Slots a
			-- screen apart are two lists, not a character sheet.
			local leftX = 8
			local rightX = leftX + GEAR + MIDDLE
			local blockWidth = rightX + GEAR

			-- One slot, wherever it goes. Empty ones are drawn with the game's own
			-- picture for that slot, which is what makes an empty shoulder obvious at a
			-- glance instead of being a row that says "empty" among eighteen others.
			local function place(entry, atX, atY)
				usedSlots = usedSlots + 1
				local button = gearSlot(usedSlots)

				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", atX, -atY)
				button:Show()

				local item = gear.worn[entry[1]]
				button.memberKey = member.key
				button.itemID = item and item.id or nil
				button.itemLink = item and item.item or nil
				button.slotName = _G[entry[2]] or entry[2]

				if item then
					-- Asked for by id; the panel draws itself again when the client
					-- answers, so a name and a border arrive together (§2.1).
					Family.Names:Item(item.id, "character", function()
						if frame:IsShown() then frame:Refresh() end
					end)

					button.icon:SetTexture(Family:TryCall(GetItemIcon, item.id)
						or "Interface\\Icons\\INV_Misc_QuestionMark")
					if button.icon.SetDesaturated then
						button.icon:SetDesaturated(false)
					end

					button.level:SetText(item.itemLevel
						and ("|cffffd700" .. item.itemLevel .. "|r") or "")

					-- The quality colour round the edge, which is how the game says
					-- the same thing. Asked for at display time by id, so it costs
					-- nothing to store and is right in every language.
					local quality = select(3, Family:TryCall(GetItemInfo, item.id))
					local colours = _G.ITEM_QUALITY_COLORS
					local colour = quality and colours and colours[quality]
					if colour then
						button.border:SetColorTexture(colour.r, colour.g, colour.b, 0.7)
					else
						button.border:SetColorTexture(1, 1, 1, 0.15)
					end
				else
					button.icon:SetTexture(
						"Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. entry[3])
					if button.icon.SetDesaturated then
						button.icon:SetDesaturated(true)
					end
					button.level:SetText("")
					button.border:SetColorTexture(1, 1, 1, 0.05)
				end
			end

			for index, entry in ipairs(LEFT_SLOTS) do
				place(entry, leftX, (index - 1) * (GEAR + GEAR_GAP))
			end
			for index, entry in ipairs(RIGHT_SLOTS) do
				place(entry, rightX, (index - 1) * (GEAR + GEAR_GAP))
			end

			local bottomY = #LEFT_SLOTS * (GEAR + GEAR_GAP) + 8
			local bottomX = leftX
				+ (blockWidth - leftX - (#BOTTOM_SLOTS * (GEAR + GEAR_GAP))) / 2
			for index, entry in ipairs(BOTTOM_SLOTS) do
				place(entry, bottomX + (index - 1) * (GEAR + GEAR_GAP), bottomY)
			end

			-- The middle of a character sheet is the character, and Family has no model
			-- of somebody who is not logged in. What it does have is worth more there
			-- than an empty space: who they are, in the words the game uses for it.
			local meta = member.meta
			local colours = _G.RAID_CLASS_COLORS
			local classNames = _G.LOCALIZED_CLASS_NAMES_MALE
			local className = meta.classFile
				and ((classNames and classNames[meta.classFile]) or meta.classFile)

			local red, green, blue = UI:ClassColour(meta.classFile)

			local FACTION_COLOUR = { Alliance = "|cff6699ff", Horde = "|cffff4444" }

			local lines = {
				{ string.format("|cffffd700%s|r", meta.name or member.key) },
				{ string.format(L["|cff888888level %s|r  %s%s|r"],
					tostring(meta.level or "?"),
					string.format("|cff%02x%02x%02x", red * 255, green * 255, blue * 255),
					className or "?") },
				{ string.format("|cffdddddd%s|r", UI:RaceName(meta)) },
				{ meta.faction
					and string.format("%s%s|r", FACTION_COLOUR[meta.faction] or "|cffdddddd",
						meta.faction)
					or "" },
				{ string.format("|cff888888%s|r", meta.realm or "") },
			}

			for index, line in ipairs(lines) do
				if line[1] ~= "" then
					local r = nextRow()
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", leftX + GEAR + 12, -(8 + (index - 1) * ROW))
					r:SetWidth(MIDDLE - 24)
					r.middle:ClearAllPoints()
					r.middle:SetPoint("LEFT", 0, 0)
					r.middle:SetWidth(MIDDLE - 24)
					r.middle:SetText(line[1])
				end
			end

			y = bottomY + GEAR + 8
			return finish()
		end

		----------------------------------------------------------------------------------

		if section == "Reputations" then
			local reps = payload.reputations
			if not reps or #reps == 0 then
				return finish(L["|cffffaa00Nothing recorded for this member.|r"])
			end

			-- Grouped under the game's own headings rather than one flat list, and inside
			-- each, highest standing first. A category with nothing left after the filter
			-- is not drawn at all.
			local byCategory, categories = {}, {}
			local shown = 0

			for _, faction in ipairs(reps) do
				if matches(faction.name) or matches(faction.category) then
					local group = faction.category or L["|cff888888Other|r"]
					if not byCategory[group] then
						byCategory[group] = {}
						categories[#categories + 1] = group
					end
					table.insert(byCategory[group], faction)
					shown = shown + 1
				end
			end

			table.sort(categories)
			status:SetText(string.format(L["%d of %d factions"], shown, #reps))

			for _, group in ipairs(categories) do
				local heading = nextRow()
				heading.left:SetText("|cff88bbff" .. group .. "|r")
				heading.left:SetWidth(220)
				heading.middle:SetText("")
				heading.right:SetText("|cff888888" .. #byCategory[group] .. "|r")

				table.sort(byCategory[group], function(a, b)
					if a.standing ~= b.standing then return a.standing > b.standing end
					return (a.name or "") < (b.name or "")
				end)

				for _, faction in ipairs(byCategory[group]) do
					local r = nextRow()

					-- The game has no tooltip for a faction, so this is Family's own:
					-- the standing and the numbers behind it, which the row shows
					-- abbreviated and which are worth reading in full.
					r.fallback = {
						{ faction.name or ("#" .. tostring(faction.id)) },
						{ group },
						{ standingLabel(faction.standing),
							faction.maximum and faction.maximum > 0
								and string.format("%d / %d", faction.value,
									faction.maximum) or "" },
					}

					r.left:SetText("  " .. (faction.name or ("#" .. tostring(faction.id))))
					r.left:SetWidth(220)
					r.middle:SetText((STANDING_COLOUR[faction.standing] or "|cffdddddd")
						.. standingLabel(faction.standing) .. "|r")
					r.right:SetText(faction.maximum and faction.maximum > 0
						and string.format("|cff888888%d / %d|r",
							faction.value, faction.maximum) or "")
				end
			end
			return finish()
		end

		----------------------------------------------------------------------------------

		if section == "Currencies" then
			-- Read from meta, not the payload: these are small, the summary totals them
			-- across the family, and both screens should be reading the same numbers.
			local held = member.meta.currencies

			if not member.meta.currenciesSeen then
				return finish(L["|cffffaa00Nothing recorded for this member - log in on "
					.. "them once.|r"])
			end
			if not held or #held == 0 then
				return finish(L["|cff9d9d9dThis client offers no currencies, or this "
					.. "member has never held one.|r"])
			end

			-- Most held first, which is the same order the summary picks its columns in.
			local ordered = {}
			for _, currency in ipairs(held) do ordered[#ordered + 1] = currency end
			table.sort(ordered, function(a, b)
				if (a.quantity or 0) ~= (b.quantity or 0) then
					return (a.quantity or 0) > (b.quantity or 0)
				end
				return tostring(a.name or a.key) < tostring(b.name or b.key)
			end)

			local shown = 0
			for _, currency in ipairs(ordered) do
				local name = currency.name or string.format(L["Currency #%s"], tostring(currency.id))
				if matches(name) then
					shown = shown + 1
					local r = nextRow()
					r.icon:SetTexture(currency.icon
						or "Interface\\Icons\\INV_Misc_QuestionMark")
					r.left:SetText(name)
					r.middle:SetText(string.format("|cffffd700%s|r",
						tostring(currency.quantity or 0)))

					-- The cap only where there is one. Most currencies have none, and a
					-- column reading "of a cap of 0" would be an invented ceiling.
					if currency.max then
						local room = currency.max - (currency.quantity or 0)
						r.right:SetText(string.format(L["%s%s|r  |cff888888(%s to go)|r"],
							room <= 0 and "|cffff8040" or "|cff888888",
							tostring(currency.max), tostring(math.max(room, 0))))
					else
						r.right:SetText(L["|cff9d9d9dno cap|r"])
					end

					-- The game will describe a currency it has an id for, which is every
					-- one on the clients that keep a list. Honor and arena points on the
					-- Burning Crusade clients have none, so those show what was recorded.
					r.currencyID = currency.id
					r.fallback = { { name },
						{ tostring(currency.quantity or 0),
							currency.max and tostring(currency.max) or "" } }
				end
			end

			status:SetText(string.format(shown == 1
				and L["|cffffd700%d|r currency   |cff888888|||r   seen %s"]
				or L["|cffffd700%d|r currencies   |cff888888|||r   seen %s"],
				shown, UI:Ago(member.meta.currenciesSeen)))
			return finish()
		end

		----------------------------------------------------------------------------------

		if section == "Quests" then
			-- The rows come from Quests.lua, which knows the zone grouping and the
			-- difficulty banding. This panel only draws them.
			local lines, message = UI:QuestLines(member.key, member.meta, matches)
			if not lines then return finish(message) end

			status:SetText(message)

			-- Only the member being played has a quest log open, so only their rows do
			-- anything when clicked - and only those are lit. A row that highlights and
			-- then does nothing is worse than one that never suggested it would.
			local playing = member.key == Family:CurrentMember()

			for _, line in ipairs(lines) do
				local r = nextRow()
				r.left:SetText(line.left)
				r.left:SetWidth(170)
				r.middle:SetText(line.middle)
				r.right:SetText(line.right)
				r.questID = line.questID
				r.questTitle = line.title
				r.memberKey = member.key
				r.highlight:SetShown(playing and (line.questID or line.title) and true
					or false)
			end
			return finish()
		end

		----------------------------------------------------------------------------------

		local record = payload.achievements
		if not Family.Capabilities:Has("achievements") then
			return finish(L["|cff9d9d9dThis client has no achievements.|r"])
		end
		if not record then
			return finish(L["|cffffaa00Nothing recorded for this member.|r"])
		end

		-- Everything but the ids comes back from the client, for any achievement, in
		-- whatever language it is running in (§2.1). Only the category and the progress
		-- were recorded, because those are the two it will not answer for later.
		local groups, order = {}, {}
		local shown, earnedPoints = 0, 0

		for _, entry in ipairs(record.list or {}) do
			local id, name, points, _, _, _, _, description =
				Family:TryCall(GetAchievementInfo, entry.id)

			name = name or string.format(L["Achievement #%s"], entry.id)

			if matches(name) or matches(description) then
				local category = entry.category or 0
				if not groups[category] then
					groups[category] = {}
					order[#order + 1] = category
				end

				table.insert(groups[category], {
					entry = entry,
					name = name,
					description = description,
					points = tonumber(points) or entry.points or 0,
				})
				shown = shown + 1
			end

			if entry.done then earnedPoints = earnedPoints + (entry.points or 0) end
		end

		status:SetText(string.format(
			L["|cffffd700%d|r points from %d achievements   |cff888888|||r   %d shown   "
			.. "|cff888888|||r   seen %s"],
			record.points or 0, record.count or 0, shown, UI:Ago(record.seen)))

		-- By the game's own category names, which it answers for any category id.
		local titles = {}
		for _, category in ipairs(order) do
			titles[category] = Family:TryCall(GetCategoryInfo, category)
				or string.format(L["Category %s"], tostring(category))
		end
		table.sort(order, function(a, b) return titles[a] < titles[b] end)

		for _, category in ipairs(order) do
			local entries = groups[category]

			-- Finished ones first, then by name: what is left to do reads best at the
			-- bottom of the group it belongs to.
			table.sort(entries, function(a, b)
				local doneA, doneB = a.entry.done or false, b.entry.done or false
				if doneA ~= doneB then return doneA end
				return a.name < b.name
			end)

			local heading = nextRow()
			heading.left:SetText(string.format("|cff88bbff%s|r |cff888888(%d)|r",
				titles[category], #entries))
			heading.left:SetWidth(220)
			heading.middle:SetText("")
			heading.right:SetText("")

			for _, item in ipairs(entries) do
				local r = nextRow()
				r.left:SetText("")
				r.achievementID = item.entry.id

				-- What Family knows, for the clients where an achievement link says
				-- nothing. The row shows the same three facts; a tooltip that repeats
				-- them is still better than one that opens empty.
				r.fallback = {
					{ item.name, string.format(L["%s points"], item.points) },
					{ item.description or "" },
					{ item.entry.done and L["|cff40bf40earned|r"]
						or string.format(L["|cffffd700%d|r of %d"],
							item.entry.completed or 0, item.entry.criteria or 0) },
				}

				-- The description in grey after the name, on the one line. It is what
				-- an achievement actually asks of you, and a list of titles alone
				-- means nothing for the ones nobody has memorised.
				r.middle:SetText(item.description
					and string.format("%s  |cff888888%s|r",
						item.entry.done and item.name
							or ("|cffffd700" .. item.name .. "|r"),
						item.description)
					or item.name)

				if item.entry.done then
					r.right:SetText(string.format(L["|cff40bf40%d|r points"], item.points))
				else
					-- Started and not finished, which is the only reason an unfinished
					-- one was recorded at all.
					r.right:SetText(string.format(L["|cffffd700%d|r of %d"],
						item.entry.completed or 0, item.entry.criteria or 0))
				end
			end
		end

		return finish()
	end
end

UI:RegisterTab("character", L["Character"], build)
