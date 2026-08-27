-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- One member's professions, and what each of them can make.
--
-- The distinction the scanner keeps is the one this panel has to show. A rank is always
-- known; a recipe list only exists if that profession's window has been opened, and is as
-- old as the last time it was. A profession with no recipes recorded says "never opened"
-- rather than showing an empty list, because those are different facts (§2.2).

local _, UI = ...

local Family = _G.Family

-- Twice the height a list row needs, because the icon is the useful part: a recipe is
-- recognised by its picture long before its name is read.
local ROW = 32

-- The profession buttons along the top. Wider than they were by what a picture takes, so that
-- "Leatherworking 375" lost no room to it - the same trade the tab strip made.
local SKILL_W = 158
local SKILL_STEP = SKILL_W + 2
local SKILL_ICON = 14
local SKILL_INSET = 20

-- The client's own words for how hard a recipe is, and what they are worth showing as. These
-- keys are not translated - they are the same on a German client - so they are safe to key on.
local DIFFICULTY = {
	optimal  = { colour = "|cffff8040", label = "orange", order = 1 },
	medium   = { colour = "|cffffff00", label = "yellow", order = 2 },
	easy     = { colour = "|cff40bf40", label = "green",  order = 3 },
	trivial  = { colour = "|cff808080", label = "grey",   order = 4 },
}

--------------------------------------------------------------------------------------------
-- Sorting
--
-- Three orders, because a recipe list is read for three different reasons: what will skill me
-- up, what is worth making, and what I will be able to make next.
--
-- The item level of what a recipe creates comes from the client by id, and is nil until it
-- has loaded that item - so a recipe whose item is not known yet sorts last rather than
-- sorting as zero, which would put every unloaded recipe above the ones worth seeing.
--------------------------------------------------------------------------------------------

local function craftedItemLevel(recipe)
	if not recipe.itemID then return nil end
	local _, _, _, level = Family:TryCall(GetItemInfo, recipe.itemID)
	return level
end

local ORDERS = {
	{
		id = "difficulty",
		label = "Difficulty",
		note = "Hardest first. Within a colour, the ones that took the most skill to learn.",
		-- The colour is a band of four, and a band is a coarse answer: nine grey recipes are
		-- all "trivial" and are emphatically not all equally trivial. Ordered by name inside
		-- the band, Heavy Linen Bandage sat above Runecloth Bandage, which is alphabetical
		-- and reads as a difficulty order that is simply wrong.
		--
		-- So inside a band: the skill each one needed, highest first, where that is known;
		-- then the item level of what it makes, highest first, which is a decent stand-in
		-- and is known far more often; then the name, which orders nothing but at least does
		-- it the same way twice.
		sort = function(a, b)
			local orderA = (DIFFICULTY[a.difficulty] or {}).order or 9
			local orderB = (DIFFICULTY[b.difficulty] or {}).order or 9
			if orderA ~= orderB then return orderA < orderB end

			local skillA, skillB = a.minSkill, b.minSkill
			if skillA and skillB and skillA ~= skillB then return skillA > skillB end
			if skillA and not skillB then return true end
			if skillB and not skillA then return false end

			local levelA, levelB = craftedItemLevel(a), craftedItemLevel(b)
			if levelA and levelB and levelA ~= levelB then return levelA > levelB end
			if levelA and not levelB then return true end
			if levelB and not levelA then return false end

			return (a.name or "") < (b.name or "")
		end,
	},
	{
		id = "itemlevel",
		label = "Item level",
		note = "Hardest first, then by the item level of what it makes.",
		sort = function(a, b)
			local orderA = (DIFFICULTY[a.difficulty] or {}).order or 9
			local orderB = (DIFFICULTY[b.difficulty] or {}).order or 9
			if orderA ~= orderB then return orderA < orderB end

			local levelA, levelB = craftedItemLevel(a), craftedItemLevel(b)
			if levelA and levelB and levelA ~= levelB then return levelA > levelB end
			if levelA and not levelB then return true end
			if levelB and not levelA then return false end
			return (a.name or "") < (b.name or "")
		end,
	},
	{
		id = "skill",
		label = "Skill needed",
		note = "By the skill each one needs. Not yet known for every recipe - see below.",
		sort = function(a, b)
			local skillA, skillB = a.minSkill, b.minSkill
			if skillA and skillB and skillA ~= skillB then return skillA < skillB end
			if skillA and not skillB then return true end
			if skillB and not skillA then return false end
			return (a.name or "") < (b.name or "")
		end,
	},
}

-- "287/375", or nothing at all. Not every profession has a rank: a death knight's
-- runeforging is a window full of things they can make and no skill anywhere, and printing
-- it as 0/0 would be inventing a fact rather than reporting one.
local function rankText(skill)
	if not (skill and skill.rank and skill.maxRank) then return nil end
	return string.format("%d/%d", skill.rank, skill.maxRank)
end

--------------------------------------------------------------------------------------------
-- Opening a profession from here
--
-- Casting a spell is something the game will not let an addon do on its own - and it is
-- right not to. What it does allow is a button the player clicks themselves: a secure action
-- button carries the name of a spell and the game casts it, because the click came from a
-- hand on a mouse rather than from code deciding to cast something.
--
-- That is the whole trick. The button is set up out of combat - attributes cannot be changed
-- during a fight, which is the point of them - and clicking it casts the spell that opens the
-- profession, which for mining is Smelting and for blacksmithing is Blacksmithing. Family
-- knows that name because it wrote it down the last time the window was open.
--
-- The recipe that was clicked is remembered, and selected when the window arrives.
--------------------------------------------------------------------------------------------

local pending

-- A button that will cast, or one that will not. Both have to be arranged out of combat, so
-- in a fight the button simply does nothing rather than doing something unpredictable.
--
-- Two things have to be true of a button for this to work, and neither of them shows up
-- anywhere if it is not: the button must have been made from SecureActionButtonTemplate, and
-- nothing may have replaced its OnClick script. The template *is* its OnClick script - that is
-- where the game does the casting - so SetScript("OnClick", ...) on one of these silently
-- throws away the only part that casts anything, leaving a button that arms itself perfectly
-- and does nothing when clicked. Family's own work goes in PostClick, which runs afterwards
-- and takes nothing away.
local function armButton(button, spellName)
	if Family:TryCall(InCombatLockdown) then return false end
	if not button.SetAttribute then return false end

	if spellName then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", spellName)
		button:SetAttribute("unit", nil)
		return true
	end

	button:SetAttribute("type", nil)
	button:SetAttribute("spell", nil)
	return false
end

-- Clicking a recipe finds it in the window that is open, for the member being played.
function UI:SelectRecipe(memberKey, profession, recipeName)
	if not (memberKey and recipeName) then return false end
	if memberKey ~= Family:CurrentMember() then return false end

	-- Whatever window is open is searched by the recipe's own name, and the profession is
	-- not checked against it.
	--
	-- Checking it looked tidier and was wrong twice over. The craft frame is titled one
	-- thing and belongs to a skill line called another, so enchanting never matched itself;
	-- and a member scanned on a client of a different language has the profession under a
	-- different name again. The name of the recipe in the window in front of you is the
	-- thing that identifies it.
	local line = Family:TryCall(GetTradeSkillLine)
	if line and line ~= "UNKNOWN" then
		local count = Family:TryCall(GetNumTradeSkills) or 0
		for index = 1, count do
			local name, kind = Family:TryCall(GetTradeSkillInfo, index)
			if name == recipeName and kind ~= "header" then
				Family:TryCall(SelectTradeSkill, index)
				return true
			end
		end
	end

	-- The older Craft frame, where enchanting and poisons live.
	local craft = Family:TryCall(GetCraftName)
	if craft and craft ~= "UNKNOWN" then
		local count = Family:TryCall(GetNumCrafts) or 0
		for index = 1, count do
			local name = Family:TryCall(GetCraftInfo, index)
			if name == recipeName then
				Family:TryCall(SelectCraft, index)
				return true
			end
		end
	end

	-- Nothing open, or open on something else. The click may have been a cast that is
	-- about to open one, in which case this is remembered and done again when it arrives.
	return false
end

-- What was clicked while no window was open, so it can be selected when one appears.
function UI:RememberRecipe(memberKey, profession, recipeName)
	pending = { key = memberKey, profession = profession, name = recipeName,
		at = time() }
end

Family:OnDatabaseReady("professions.open", function()
	for _, event in ipairs { "TRADE_SKILL_SHOW", "CRAFT_SHOW" } do
		Family:RegisterEvent(event, "professions.open", function()
			if not pending then return end

			-- A click a minute ago was about something else. Only the one that just
			-- opened this window is worth acting on.
			if time() - pending.at > 20 then
				pending = nil
				return
			end

			local wanted = pending
			pending = nil

			-- After the window has filled itself in, which is not the moment it says
			-- it is showing.
			Family:After(0.5, "professions.open", function()
				UI:SelectRecipe(wanted.key, wanted.profession, wanted.name)
			end)
		end)
	end
end)

local function membersWithSkills()
	return UI:EveryMember(function(meta)
		return meta.skills and next(meta.skills) and true or false
	end)
end

--------------------------------------------------------------------------------------------

local function build(frame)
	local rows = {}
	local chosen                     -- which profession is open, by name
	local skillButtons = {}

	-- Declared first because the picker clears it; the other way round the closure would
	-- capture a global that is never set.
	local search

	local picker = UI:CreateMemberPicker(frame, 200, membersWithSkills, function()
		chosen = nil
		if search then search:SetText("") end
		frame:Refresh()
	end)
	picker:SetPoint("TOPLEFT", 0, -2)

	-- The label goes in front of the box rather than after it.
	--
	-- A caption to the right of the field it captions is read after the thing it was meant to
	-- explain, which is the wrong order for the one control here whose purpose is not obvious
	-- from looking at it. It also left the caption floating between this box and whatever came
	-- next, belonging to neither.
	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", picker, "RIGHT", 16, 0)
	hint:SetText("search recipes")

	search = CreateFrame("EditBox", "FamilyProfessionsSearch", frame, "InputBoxTemplate")
	search:SetPoint("LEFT", hint, "RIGHT", 10, 0)
	search:SetSize(200, 20)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function() frame:Refresh() end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)


	-- "Who can make this" is a different question from "what can this member make", and the
	-- answer needs a name against every line. It is also the question worth having an alt
	-- manager for: nobody remembers which of six characters took jewelcrafting.
	-- The same control the Character panel uses for the same idea, in the same place: a
	-- button at the top right that holds itself highlighted while it is on. It was a tick
	-- box and a caption, which is a second visual language for a thing that already had one
	-- three panels away - and "the whole family" beside a small square reads as a setting
	-- rather than as the switch between two ways of looking that it actually is.
	local wholeFamily = false

	local everyone = CreateFrame("Button", "FamilyProfessionsEveryone", frame, "UIPanelButtonTemplate")
	everyone:SetSize(120, 22)
	everyone:SetPoint("TOPRIGHT", -4, -2)
	everyone:SetText("Whole family")
	everyone:SetScript("OnClick", function()
		wholeFamily = not wholeFamily

		-- The same as the possessions panel, for the same reason: this mode draws nothing
		-- until it is given something to look for, so the cursor goes where the answer has
		-- to be typed.
		if wholeFamily then search:SetFocus() else search:ClearFocus() end

		frame:Refresh()
	end)

	local skillBar = CreateFrame("Frame", nil, frame)
	skillBar:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -6)
	skillBar:SetPoint("RIGHT", -8, 0)
	skillBar:SetHeight(24)

	local order = ORDERS[1]

	local sortBar = CreateFrame("Frame", nil, frame)
	sortBar:SetPoint("TOPLEFT", skillBar, "BOTTOMLEFT", 0, -4)
	sortBar:SetPoint("RIGHT", -8, 0)
	sortBar:SetHeight(22)

	local sortLabel = sortBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	sortLabel:SetPoint("LEFT", 2, 0)
	sortLabel:SetText("|cffffd700Sort by|r")

	local sortButtons = {}
	local sortX = 60
	for _, entry in ipairs(ORDERS) do
		local button = CreateFrame("Button", nil, sortBar, "UIPanelButtonTemplate")
		button:SetSize(110, 20)
		button:SetPoint("LEFT", sortX, 0)
		button:SetText(entry.label)
		button:SetScript("OnClick", function()
			order = entry
			frame:Refresh()
		end)
		sortButtons[entry.id] = button
		sortX = sortX + 114
	end

	local sortNote = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	sortNote:SetPoint("LEFT", sortBar, "LEFT", sortX + 8, 0)
	sortNote:SetPoint("RIGHT", -8, 0)
	sortNote:SetJustifyH("LEFT")

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("TOPLEFT", sortBar, "BOTTOMLEFT", 2, -4)
	status:SetPoint("RIGHT", -8, 0)
	status:SetJustifyH("LEFT")

	-- Which professions were left out of the bar, and why. Without it a herbalist's panel
	-- would simply be missing a profession they know perfectly well they have, and there is
	-- no way to tell that from Family having lost it.
	local omitted = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	omitted:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -3)
	omitted:SetPoint("RIGHT", -8, 0)
	omitted:SetJustifyH("LEFT")
	omitted:SetHeight(0)
	UI:NoWrap(omitted)

	-- Height as well as text, so that a member with nothing left out loses the gap too.
	local function setOmitted(text)
		omitted:SetText(text or "")
		omitted:SetHeight((text and text ~= "") and 14 or 0)
	end

	-- Said when a recipe is clicked and there is no window open for it to be found in.
	--
	-- The click cannot open one: nothing inside the scrolling list may cast, and the button
	-- that can is the profession's, a few inches up. So the recipe is remembered and this
	-- says which button to press - one more click than clicking the recipe alone, and the
	-- alternative was a click that appeared to do nothing at all.
	local function announceOpener(recipeName, profession)
		status:SetText(string.format("|cffffd700%s|r is waiting. Click |cffffd700%s|r "
			.. "above to open the window and it will be selected there.",
			tostring(recipeName), tostring(profession)))
	end

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", omitted, "BOTTOMLEFT", -2, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	local function row(index)
		local existing = rows[index]
		if existing then return existing end

		-- An ordinary button, and nothing protected anywhere beneath it.
		--
		-- Nothing in this list may be secure, or have anything secure inside it. The rows
		-- live in a scroll frame's child and are moved on every draw, and a protected frame
		-- inside a scroll child cannot be anchored at all - the game refuses it with
		-- "cannot anchor protected frames to regions", not only in combat. Both shapes were
		-- tried in game: the row made secure, and then an ordinary row with a secure child
		-- over it, which fails the same way because a frame with a protected child is
		-- protected itself.
		--
		-- The profession buttons a few inches above are secure and are moved on every draw
		-- without complaint, which is what says the scroll frame is the difference and not
		-- the moving. So the casting lives up there, where it works, and a recipe clicked
		-- with nothing open is remembered for the button that can open it (below).
		local r = CreateFrame("Button", nil, list)
		r:SetHeight(ROW)

		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(ROW - 4, ROW - 4)
		r.icon:SetPoint("LEFT", 4, 0)

		r:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		r:RegisterForClicks("LeftButtonUp")

		r:SetScript("OnClick", function(self)
			if UI:SelectRecipe(self.memberKey, self.profession, self.recipeName) then
				-- Family stays where it is. This opened nothing: it found the recipe in
				-- the window that was already in front of you and selected it there. The
				-- ordinary use of this panel is with a profession window open beside it,
				-- clicking one recipe after another - and closing Family after each one
				-- would end that after the first.
				return
			end

			-- Nothing open to find it in. Remembered, so that the profession button -
			-- which can cast and this cannot - selects it the moment the window arrives,
			-- and the panel says which button that is rather than looking broken.
			if self.canOpen then
				UI:RememberRecipe(self.memberKey, self.profession, self.recipeName)
				if self.announce then self.announce(self.recipeName, self.profession) end
			end
		end)

		r.text = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.text:SetPoint("LEFT", 4 + ROW, 0)
		r.text:SetJustifyH("LEFT")
		r.note = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.note:SetPoint("RIGHT", -8, 0)
		r.note:SetWidth(150)
		r.note:SetJustifyH("RIGHT")

		UI:NoWrap(r.text, r.note)

		-- A recipe is a spell that sometimes makes an item, so the tooltip is whichever of
		-- the two this one has. The spell is preferred: it is the recipe, and it says what
		-- the thing costs to make as well as what it is.
		--
		UI:AttachTooltip(r, function(self)
			if self.spellID then return "spell", self.spellID, self.fallback end
			if self.itemID then return "item", self.itemID, self.fallback end
			if self.fallback then return nil, nil, self.fallback end
			return nil
		end)

		rows[index] = r
		return r
	end

	local function skillButton(index)
		local existing = skillButtons[index]
		if existing then return existing end
		-- Secure, and moved on every draw without complaint - because this bar is an
		-- ordinary frame in the panel and not a scroll frame's child. That is the whole of
		-- the difference between here and the recipe list, and it is why the casting lives
		-- here and only here.
		local button = CreateFrame("Button", nil, skillBar,
			"UIPanelButtonTemplate,SecureActionButtonTemplate")
		button:SetSize(SKILL_W, 20)
		button:RegisterForClicks("LeftButtonUp")

		-- The profession's own picture, where the client hands one over.
		--
		-- Asked for by nothing: it arrives beside the rank, out of GetProfessionInfo, so it
		-- is the client's own answer for the profession this character actually has and it
		-- is right in every language. A table of paths keyed by "Blacksmithing" would be
		-- right in one (§2.1), which is why there isn't one.
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetSize(SKILL_ICON, SKILL_ICON)
		button.icon:SetPoint("LEFT", 4, 0)

		button.label = button.GetFontString and button:GetFontString()

		skillButtons[index] = button
		return button
	end

	-- Open this panel on a particular member's particular profession, for anything that
	-- knows both - the summary, where clicking a profession is the obvious thing to try.
	--
	-- Selected by hand as far as the picker is concerned, because it was: somebody clicked
	-- that member's row, and the choice should stand until they choose otherwise.
	function UI:ShowProfessionFor(key, profession)
		UI:ShowTab("professions")

		for _, entry in ipairs(membersWithSkills()) do
			if entry.key == key then
				picker:Select(entry)
				break
			end
		end

		if profession then chosen = profession end
		wholeFamily = false
		frame:Refresh()
	end

	function frame:Refresh()
		UI:MarkSelected(everyone, wholeFamily)
		local member = picker:Reconcile()

		for _, button in ipairs(skillButtons) do button:Hide() end
		for index = 1, #rows do rows[index]:Hide() end

		----------------------------------------------------------------------------------
		-- Searching everybody
		--
		-- One line per recipe rather than one per member holding it: the recipe is the
		-- thing being looked for, and who can make it is the answer beside it.
		----------------------------------------------------------------------------------

		if wholeFamily then
			picker:Hide()
			sortBar:Hide()
			skillBar:SetHeight(1)
			setOmitted(nil)

			local needle = (search:GetText() or ""):lower()

			if #needle < 2 then
				status:SetText("|cff9d9d9dSearching every profession of every member. "
					.. "Type at least two letters in the box above.|r")
				list:SetHeight(1)
				return
			end

			local found = Family.Recipes:Search(needle)
			local used, y = 0, 0
			list:SetWidth(scroll:GetWidth())

			for _, recipe in ipairs(found) do
				used = used + 1
				local r = row(used)
				r:SetPoint("TOPLEFT", 0, -y)
				r:SetPoint("TOPRIGHT", 0, -y)
				r:Show()
				y = y + ROW

				r.spellID, r.itemID = recipe.spellID, recipe.itemID
				r.memberKey, r.profession, r.recipeName = nil, nil, nil
				-- A row about the whole family is about somebody else as often as not, so
				-- it is disarmed: rows are pooled, and one left armed from a previous draw
				-- would cast for a recipe it is no longer showing.
				r.canOpen = false
				r.fallback = { { recipe.name or "?" }, { recipe.profession } }

				local icon = recipe.icon
				if not icon and recipe.itemID then
					icon = Family:TryCall(GetItemIcon, recipe.itemID)
				end
				r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

				r.text:SetText(string.format("%s   |cff888888%s|r", recipe.name or "?",
					recipe.profession))
				r.text:SetWidth(scroll:GetWidth() - 260 - ROW)

				local names = {}
				for _, who in ipairs(UI:NamesOf(recipe.members)) do
					names[#names + 1] = who.rank
						and string.format("%s |cff888888%d|r", who.label, who.rank)
						or who.label
				end
				r.note:SetWidth(250)
				r.note:SetText(table.concat(names, ", "))
			end

			for index = used + 1, #rows do rows[index]:Hide() end
			list:SetHeight(math.max(y, 1))

			status:SetText(#found > 0
				and string.format("|cffffd700%d|r recipe%s named like \"%s\", and who "
					.. "can make each", #found, #found == 1 and "" or "s", needle)
				or string.format("|cff9d9d9dNobody in the family knows a recipe named "
					.. "like \"%s\".|r", needle))
			return
		end

		picker:Show()
		sortBar:Show()
		for _, entry in ipairs(rows) do entry.note:SetWidth(150) end

		if not member then
			status:SetText("|cff9d9d9dNo member has any profession recorded yet.|r")
			setOmitted(nil)
			list:SetHeight(1)
			return
		end

		local skills = member.meta.skills or {}
		local payload = UI:Payload(member.key) or {}
		local stored = payload.professions or {}

		-- Only the professions there is something to look at.
		--
		-- Herbalism, skinning and fishing make nothing, and a button leading to an empty list
		-- costs a click every time somebody tries it to find that out again. That a member has
		-- them, and how far they have taken them, is the summary's business - it says so in
		-- one line per member, which is where that question is actually asked.
		--
		-- "Makes nothing" and "never opened" remain two different facts (§2.2) and Family can
		-- only tell them apart by having seen the window, so the ones left out are named below
		-- with whichever of the two they are.
		local ordered, makesNothing, notOpened = {}, {}, {}

		for name, skill in pairs(skills) do
			local record = stored[name]
			if record and record.recipes and #record.recipes > 0 then
				ordered[#ordered + 1] = { name = name, skill = skill }
			elseif record and record.recipes then
				makesNothing[#makesNothing + 1] = name
			else
				notOpened[#notOpened + 1] = name
			end
		end

		-- Primaries first, then the secondaries, each alphabetical - the same order the
		-- summary uses, so the two do not disagree about what comes first.
		table.sort(ordered, function(a, b)
			local aSecond, bSecond = a.skill.secondary or false, b.skill.secondary or false
			if aSecond ~= bSecond then return bSecond end
			return a.name < b.name
		end)
		table.sort(makesNothing)
		table.sort(notOpened)

		local left = {}
		if #makesNothing > 0 then
			left[#left + 1] = table.concat(makesNothing, ", ") .. " make nothing"
		end
		if #notOpened > 0 then
			left[#left + 1] = table.concat(notOpened, ", ") .. " never opened"
		end
		setOmitted(#left > 0 and ("Not listed: " .. table.concat(left, "; ")
			.. ".  Summary / Professions has every profession and its level.") or nil)

		if #ordered == 0 then
			status:SetText(next(skills)
				and "|cff9d9d9dNothing this member has recorded makes anything.|r"
				or "|cff9d9d9dNothing recorded for this member.|r")
			skillBar:SetHeight(1)
			list:SetHeight(1)
			return
		end

		local listed = {}
		for _, entry in ipairs(ordered) do listed[entry.name] = true end
		if not chosen or not listed[chosen] then chosen = ordered[1].name end

		-- Wrapped rather than run off the edge. Eight professions is normal - two primary,
		-- three secondary, and whatever else the class was given - and the ninth used to
		-- be drawn somewhere nobody could click it.
		local perRow = math.max(math.floor(scroll:GetWidth() / SKILL_STEP), 1)
		local barRows = math.ceil(#ordered / perRow)
		skillBar:SetHeight(barRows * 24)

		local x = 0
		for index, entry in ipairs(ordered) do
			local button = skillButton(index)
			local column = (index - 1) % perRow
			local line = math.floor((index - 1) / perRow)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", column * SKILL_STEP, -(line * 24))
			local rank = rankText(entry.skill)
			button:SetText(rank and string.format("%s %d", entry.name, entry.skill.rank)
				or entry.name)

			-- A profession the client gave no picture for keeps its label centred, exactly
			-- as all of them did before. Holding the inset open for a picture that is never
			-- coming would push every label sideways for no visible reason, on the clients
			-- that have no such call at all.
			local picture = entry.skill and entry.skill.icon
			button.icon:SetShown(picture and true or false)
			if picture then button.icon:SetTexture(picture) end

			if button.label then
				button.label:ClearAllPoints()
				if picture then
					button.label:SetPoint("LEFT", SKILL_INSET, 0)
					button.label:SetWidth(SKILL_W - SKILL_INSET - 4)
					button.label:SetJustifyH("LEFT")
				else
					button.label:SetPoint("CENTER")
					button.label:SetWidth(SKILL_W - 8)
					button.label:SetJustifyH("CENTER")
				end
				if button.label.SetWordWrap then button.label:SetWordWrap(false) end
			end
			UI:MarkSelected(button, entry.name == chosen)

			-- Clicking it opens that profession, where this is the member being played
			-- and Family has seen the window once and so knows what opens it.
			local record = stored[entry.name]
			armButton(button, member.key == Family:CurrentMember()
				and record and record.openWith or nil)

			-- PostClick, never OnClick: see armButton above. This button's OnClick belongs
			-- to the game, and taking it was why clicking a profession opened nothing.
			button:SetScript("PostClick", function()
				chosen = entry.name
				-- A recipe name typed for one profession means nothing in the next,
				-- and an empty list reads as missing data rather than as a filter.
				search:SetText("")
				frame:Refresh()
			end)
			button:Show()
		end

		-- Whatever is chosen has recipes: that is what got it a button in the first place.
		local skill = skills[chosen]
		local record = stored[chosen] or {}
		local recipes = record.recipes or {}

		local needle = (search:GetText() or ""):lower()

		local shown, counts = {}, {}
		for _, recipe in ipairs(recipes) do
			local name = recipe.name or ""
			if needle == "" or name:lower():find(needle, 1, true) then
				shown[#shown + 1] = recipe
			end
			local key = recipe.difficulty or "trivial"
			counts[key] = (counts[key] or 0) + 1
		end

		table.sort(shown, order.sort)

		for id, button in pairs(sortButtons) do
			UI:MarkSelected(button, id == order.id)
		end
		sortNote:SetText("|cff888888" .. order.note .. "|r")

		local breakdown = {}
		for key, entry in pairs(DIFFICULTY) do
			if counts[key] then
				breakdown[#breakdown + 1] = { order = entry.order,
					text = entry.colour .. counts[key] .. " " .. entry.label .. "|r" }
			end
		end
		table.sort(breakdown, function(a, b) return a.order < b.order end)

		local pieces = {}
		for _, entry in ipairs(breakdown) do pieces[#pieces + 1] = entry.text end

		status:SetText(string.format("|cffffd700%s|r %s   |cff888888|||r   %d recipes  %s"
			.. "   |cff888888|||r   seen %s",
			chosen, rankText(skill) or "", #recipes,
			table.concat(pieces, "  "), UI:Ago(record.recipesSeen)))

		local used, y = 0, 0
		list:SetWidth(scroll:GetWidth())

		for _, recipe in ipairs(shown) do
			used = used + 1
			local r = row(used)
			r:SetPoint("TOPLEFT", 0, -y)
			r:SetPoint("TOPRIGHT", 0, -y)
			r:Show()
			y = y + ROW

			local style = DIFFICULTY[recipe.difficulty] or { colour = "|cffdddddd" }
			r.text:SetText(style.colour .. (recipe.name or "?") .. "|r")
			r.text:SetWidth(scroll:GetWidth() - 170 - ROW)

			-- Whatever the client said this row's icon was, recorded at scan time. Failing
			-- that, the icon of the thing it makes - which is right for anything that
			-- makes an item and wrong for nothing, since an enchant that makes no item
			-- falls through to its own spell.
			r.spellID, r.itemID = recipe.spellID, recipe.itemID
			r.memberKey, r.profession, r.recipeName = member.key, chosen, recipe.name

			-- Armed only when there is something to cast and somebody to cast it, so a
			-- row about another member stays a picture of a recipe.
			-- Not armed - nothing in this list can be - but it is still worth knowing
			-- whether there is a window to open, because that decides whether a click
			-- with nothing open has anything to say for itself.
			r.canOpen = (member.key == Family:CurrentMember()) and record.openWith ~= nil
			r.announce = announceOpener

			-- For a recipe the client will describe neither way, which happens when its
			-- window has not been open since the client last loaded the spell.
			r.fallback = {
				{ recipe.name or "?" },
				{ chosen, style.label and ("|cff888888" .. style.label .. "|r") or "" },
			}

			local icon = recipe.icon
			if not icon and recipe.itemID then
				icon = Family:TryCall(GetItemIcon, recipe.itemID)
			end
			if not icon and recipe.spellID then
				icon = select(2, Family.Names:Spell(recipe.spellID))
			end
			r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

			-- A cooldown outranks how many can be made: a transmute you cannot do for
			-- another six hours is not one you can make, whatever the reagents say.
			if recipe.readyAt and recipe.readyAt > time() then
				r.note:SetText("|cffff8040ready " .. UI:In(recipe.readyAt) .. "|r")
			elseif recipe.readyAt then
				r.note:SetText("|cff40bf40ready now|r")
			elseif recipe.available and recipe.available > 0 then
				r.note:SetText("|cff40bf40can make " .. recipe.available .. "|r")
			else
				r.note:SetText("")
			end
		end

		for index = used + 1, #rows do rows[index]:Hide() end
		list:SetHeight(math.max(y, 1))
	end
end

UI:RegisterTab("professions", "Professions", build)
