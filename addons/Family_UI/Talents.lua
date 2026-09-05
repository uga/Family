-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a member can do: their talents, either specialisation, and their spellbook.
--
-- The two sit together because they answer one question between them. "What is this
-- character" is half a talent tree and half a list of what it can cast, and having to visit
-- two tabs to read the two halves is what made the spellbook feel misfiled next to a
-- reputation list.
--
-- The side-by-side comparison that used to live here is gone. It was the more interesting
-- screen and the less useful one: reading one member is what anybody actually opens this for,
-- and paying for the comparison meant every row on both sides had to be paired, coloured and
-- explained. §4.4 still asks for it, and it can come back as a switch once the plain view is
-- right.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 16

local SECTIONS = { "Talents", "Spellbook" }

local function membersKnown()
	return UI:EveryMember()
end

--------------------------------------------------------------------------------------------
-- The specialisation
--
-- On Mists it is not what the talents add up to: it is picked outright, before any of them,
-- and it decides more about a character than the six tier choices below it do. Answered here
-- either way - a member with none recorded has not chosen one or could not be read, and both
-- deserve better than a blank space where it would have been.
--------------------------------------------------------------------------------------------

local function specOf(specID)
	if not specID then return { label = L["|cff9d9d9dnone recorded|r"] } end

	local name, icon, role
	if GetSpecializationInfoByID then
		local _, specName, _, specIcon, specRole = GetSpecializationInfoByID(specID)
		name, icon, role = specName, specIcon, specRole
	end

	return {
		label = name or string.format(L["Specialisation #%s"], specID),
		icon = icon,
		-- The game's own word for the role, so "Tank" is whatever the player calls it.
		role = role and (_G[role] or role) or nil,
	}
end

--------------------------------------------------------------------------------------------
-- The talents, laid out the way the game lays them out
--
-- A tree is a grid and reading one is a spatial act: the shape of where the points went is
-- the answer, and a list of names in tier order is that answer transcribed into a form nobody
-- thinks in. So the trees are drawn as trees, three of them side by side, each talent at the
-- tier and column it really occupies - and the ones with no points in them are drawn too,
-- greyed, because a gap in a tree means something and a missing row does not.
--
-- Mists is the same idea with a different shape: six tiers of three, one taken from each.
--------------------------------------------------------------------------------------------

local CELL = 36           -- icon and its margin
local TREE_GAP = 24
local TITLE = 24

local function build(frame)
	local section = SECTIONS[1]
	local sectionButtons = {}
	local group = 1

	local rows = {}           -- the spellbook's lines
	local cells = {}          -- the talent icons
	local labels = {}         -- headings and tier numbers on the talent grid

	-- Declared before the picker, whose callback clears it.
	local search

	local picker = UI:CreateMemberPicker(frame, 200, membersKnown, function()
		if search then search:SetText("") end
		group = 1
		frame:Refresh()
	end)
	picker:SetPoint("TOPLEFT", 0, -2)

	local spec = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	spec:SetSize(90, 22)
	spec:SetPoint("LEFT", picker, "RIGHT", 8, 0)
	spec:SetScript("OnClick", function()
		group = (group == 1) and 2 or 1
		frame:Refresh()
	end)

	search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	search:SetPoint("LEFT", spec, "RIGHT", 16, 0)
	search:SetSize(200, 20)
	search:SetAutoFocus(false)
	UI:ReleaseFocusOnClick(search)
	search:SetScript("OnTextChanged", function() frame:Refresh() end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", search, "RIGHT", 8, 0)
	hint:SetText(L["filter"])

	local function matches(text)
		local needle = (search:GetText() or ""):lower()
		if needle == "" then return true end
		return type(text) == "string" and text:lower():find(needle, 1, true) ~= nil
	end

	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -6)
	bar:SetPoint("RIGHT", -8, 0)
	bar:SetHeight(24)

	local sectionRow = {}
	for _, name in ipairs(SECTIONS) do
		local button = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
		button:SetHeight(20)
		button:SetText(L[name])
		button:SetScript("OnClick", function()
			section = name
			-- A filter typed for one section rarely means anything in the next.
			search:SetText("")
			frame:Refresh()
		end)
		sectionButtons[name] = button
		sectionRow[#sectionRow + 1] = button
	end
	UI:LayOutRow(sectionRow, 110, 2, 0, nil, (UI.CONTENT_W or 740) - 16)

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 2, -4)
	status:SetPoint("RIGHT", -8, 0)
	status:SetJustifyH("LEFT")

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
	headings[3]:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	----------------------------------------------------------------------------------------
	-- The two kinds of thing that can be on the scroll child
	----------------------------------------------------------------------------------------

	local function row(index)
		local existing = rows[index]
		if existing then return existing end

		local r = CreateFrame("Frame", nil, list)
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

		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.right:SetPoint("RIGHT", -8, 0)
		r.right:SetWidth(140)
		r.right:SetJustifyH("LEFT")

		UI:NoWrap(r.left, r.middle, r.right)

		UI:AttachTooltip(r, function(self)
			if self.spellID then return "spell", self.spellID end
			return nil
		end)

		rows[index] = r
		return r
	end

	local function cell(index)
		local existing = cells[index]
		if existing then return existing end

		local button = CreateFrame("Button", nil, list)
		button:SetSize(CELL - 4, CELL - 4)

		button.border = button:CreateTexture(nil, "BACKGROUND")
		button.border:SetAllPoints()

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)

		button.rank = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.rank:SetPoint("BOTTOMRIGHT", -1, 1)

		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

		-- A glyph is a spell and the game describes it. A talent in a tree has no id of
		-- any sort on these clients, so what is shown for one is what Family recorded.
		UI:AttachTooltip(button, function(self)
			if self.spellID then return "spell", self.spellID, self.fallback end
			if self.talentID then return "talent", self.talentID, self.fallback end

			-- The game will describe a talent by where it sits, but only for the class
			-- that has those talents in those places - so this is offered when the
			-- member being looked at is of the player's own class, and Family's own
			-- lines are what everybody else gets.
			if self.talentSlot then
				return "talentslot", self.talentSlot, self.fallback
			end

			if self.fallback then return nil, nil, self.fallback end
			return nil
		end)

		cells[index] = button
		return button
	end

	local function label(index)
		local existing = labels[index]
		if existing then return existing end

		local text = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		text:SetJustifyH("LEFT")
		UI:NoWrap(text)

		labels[index] = text
		return text
	end

	----------------------------------------------------------------------------------------

	function frame:Refresh()
		local member = picker:Reconcile()

		for name, button in pairs(sectionButtons) do
			UI:MarkSelected(button, name == section)
		end

		local usedRows, usedCells, usedLabels = 0, 0, 0
		local y = 0

		list:SetWidth(UI:ListWidth(scroll))

		-- The spellbook is read by its pictures as much as by its words, so its rows are
		-- twice the height and carry an icon to match - the same reason the gear list is.
		local rowHeight = (section == "Spellbook") and (ROW * 2) or ROW

		local function nextRow()
			usedRows = usedRows + 1
			local r = row(usedRows)
			r:SetHeight(rowHeight)
			r.icon:SetSize(rowHeight - 4, rowHeight - 4)
			r.middle:ClearAllPoints()
			r.middle:SetPoint("LEFT", 180 + rowHeight + 2, 0)
			r:SetPoint("TOPLEFT", 0, -y)
			r:SetPoint("TOPRIGHT", 0, -y)
			r.middle:SetWidth(math.max(UI:ListWidth(scroll) - 360, 40))
			r.spellID = nil
			r.icon:SetTexture(nil)
			r.left:SetText("")
			r.middle:SetText("")
			r.right:SetText("")
			r:Show()
			y = y + rowHeight
			return r
		end

		-- A talent, at the place in the grid it really occupies.
		local function nextCell(atX, atY, entry)
			usedCells = usedCells + 1
			local button = cell(usedCells)

			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", atX, -atY)
			button:Show()

			button.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			button.spellID = entry.spellID
			button.talentID = entry.talentID
			button.talentSlot = entry.talentSlot
			button.fallback = entry.fallback

			-- Taken and not taken are told apart the way the game tells them apart: the
			-- ones with nothing in them are drawn grey, and are still drawn, because
			-- where the gaps are is half of what a tree says.
			local taken = entry.taken
			if button.icon.SetDesaturated then button.icon:SetDesaturated(not taken) end
			button.icon:SetAlpha(entry.dim and 0.2 or (taken and 1 or 0.45))

			button.rank:SetText(entry.rank or "")
			button.border:SetColorTexture(0, 0, 0, 0)
			if entry.chosen then
				button.border:SetColorTexture(1, 0.82, 0, 0.35)
			end

			return button
		end

		local function nextLabel(atX, atY, text, width)
			usedLabels = usedLabels + 1
			local widget = label(usedLabels)
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", atX, -atY)
			widget:SetWidth(width or 200)
			widget:SetText(text)
			widget:Show()
			return widget
		end

		local function finish(message)
			if message then status:SetText(message) end
			for index = usedRows + 1, #rows do rows[index]:Hide() end
			for index = usedCells + 1, #cells do cells[index]:Hide() end
			for index = usedLabels + 1, #labels do labels[index]:Hide() end
			list:SetHeight(math.max(y, 1))
		end

		if not member then
			spec:Hide()
			return finish(L["|cff9d9d9dNothing recorded yet.|r"])
		end

		local payload = UI:Payload(member.key) or {}

		----------------------------------------------------------------------------------

		if section == "Spellbook" then
			spec:Hide()

			-- Skills that are abilities rather than professions, above the book.
			--
			-- Lockpicking is the one these builds have: a rank and a maximum, taught by no
			-- window, making nothing, and gone from the game entirely after Cataclysm - so
			-- Mists members simply have none and this list is empty for them. It was drawn
			-- among the professions on the summary for an hour, beside cooking and fishing,
			-- until Alberto pointed out that it is technically an ability. It is one, and
			-- the comment below already says what this section is for: the things this
			-- member can do.
			--
			-- Above the book rather than inside it, because the book is grouped by school
			-- and a skill has none - and putting it in a school would be inventing one.
			local ranked = {}
			for id, skill in pairs(member.meta.skills or {}) do
				if skill.class then
					ranked[#ranked + 1] = { id = id, skill = skill,
						name = Family:ProfessionName(id, skill.name) }
				end
			end
			table.sort(ranked, function(a, b) return a.name < b.name end)

			for _, entry in ipairs(ranked) do
				local r = nextRow()
				r.left:SetText(entry.name)
				r.right:SetText(string.format("|cffffd700%d|r/%d",
					entry.skill.rank or 0, entry.skill.maxRank or 0))
			end

			local book = payload.spells
			if not book or #book == 0 then
				-- Having drawn something, saying nothing was recorded would be a fresh
				-- claim contradicted by what is on the screen above it.
				if #ranked > 0 then return finish() end
				return finish(L["|cffffaa00Nothing recorded for this member.|r"])
			end

			-- Anything the game teaches through a window of its own that is not a
			-- profession: a hunter's pet training, and whatever else turns out to work
			-- that way. It is a list of things this member can do, so it belongs here,
			-- as a school of its own below the ones the spellbook has - it has no rank,
			-- it is not a profession, and it does not change with a specialisation.
			local extra = {}
			for name, record in pairs(payload.crafts or {}) do
				local spells = {}
				for _, entry in ipairs(record.entries or {}) do
					spells[#spells + 1] = {
						name = entry.name,
						icon = entry.icon,
						spellID = entry.spellID,
					}
				end
				if #spells > 0 then
					extra[#extra + 1] = { name = name, taught = spells, seen = record.seen }
				end
			end
			table.sort(extra, function(a, b) return a.name < b.name end)

			local total = 0
			for _, school in ipairs(book) do total = total + #school.spells end
			for _, school in ipairs(extra) do total = total + #school.taught end

			status:SetText(string.format(L["%d abilities in %d schools"], total,
				#book + #extra))

			-- "Rank 10" belongs after "Rank 9", which comparing the words gets backwards.
			local function rankOrder(text)
				return tonumber(text:match("%d+") or "") or 0
			end

			for _, school in ipairs(book) do
				-- Worked out before the heading is drawn, so a school with nothing
				-- matching the filter does not leave an empty title behind.
				local keep = {}
				for _, spellID in ipairs(school.spells) do
					local spellName, spellIcon = Family.Names:Spell(spellID)
					if matches(spellName) or matches(school.name) then
						keep[#keep + 1] = {
							id = spellID,
							name = spellName or string.format(L["Spell #%s"], spellID),
							known = spellName ~= nil,
							icon = spellIcon,
							-- Six spells all called Aspect of the Hawk are six ranks
							-- of it, and without this the list reads as a mistake.
							-- Not always a rank: the client uses the same field for
							-- Passive, Racial, Master and the rest, and for a plain
							-- ability it is empty.
							rank = Family:TryCall(GetSpellSubtext, spellID) or "",
						}
					end
				end

				-- Sorted here rather than left in the order the spellbook hands them
				-- over. That order is the client's own, and on Mists it runs through
				-- General alphabetically and then adds the riding skills at the end.
				table.sort(keep, function(a, b)
					if a.name ~= b.name then return a.name < b.name end
					local rankA, rankB = rankOrder(a.rank), rankOrder(b.rank)
					if rankA ~= rankB then return rankA < rankB end
					return a.rank < b.rank
				end)

				if #keep > 0 then
					local heading = nextRow()
					-- Beside the name rather than in the last column. Put there it
					-- lined up under "Rank" and read as one, which is a different kind
					-- of number entirely.
					heading.left:SetText(string.format("|cff88bbff%s|r |cff888888(%d)|r",
						school.name or "?", #keep))
					heading.middle:SetText("")
					heading.right:SetText("")

					for _, spell in ipairs(keep) do
						local r = nextRow()
						r.left:SetText("")
						r.middle:SetText(spell.known and spell.name
							or ("|cff9d9d9d" .. spell.name .. "|r"))
						r.spellID = spell.id
						if spell.icon then r.icon:SetTexture(spell.icon) end
						r.right:SetText(spell.rank ~= ""
							and ("|cff888888" .. spell.rank .. "|r") or "")
					end
				end
			end
			-- Below the spellbook proper, because that is what it is: an appendix. Each
			-- entry is a name and a picture and no rank, because that is all there is.
			for _, school in ipairs(extra) do
				local keep = {}
				for _, taught in ipairs(school.taught) do
					if matches(taught.name) or matches(school.name) then
						keep[#keep + 1] = taught
					end
				end

				table.sort(keep, function(a, b) return (a.name or "") < (b.name or "") end)

				if #keep > 0 then
					local heading = nextRow()
					heading.left:SetText(string.format(
						"|cff88bbff%s|r |cff888888(%d)|r", school.name, #keep))

					for _, taught in ipairs(keep) do
						local r = nextRow()
						r.middle:SetText(taught.name or "?")
						r.spellID = taught.spellID
						if taught.icon then r.icon:SetTexture(taught.icon) end
					end
				end
			end

			return finish()
		end

		----------------------------------------------------------------------------------
		-- Talents
		----------------------------------------------------------------------------------

		for index = 1, 3 do headings[index]:SetText("") end

		local talents = payload.talents
		if not talents then
			spec:Hide()
			return finish(L["|cffffaa00Nothing recorded for this member.|r"])
		end

		local count = talents.groupCount or 1
		spec:Show()
		spec:SetText(count > 1 and string.format(L["Spec %d"], group) or L["Spec"])
		spec:SetEnabled(count > 1)
		if group > count then group = 1 end

		local data = talents.groups and talents.groups[group]

		if not data then
			return finish(L["|cffffaa00Nothing recorded for this specialisation.|r"])
		end
		if data.visited == false then
			return finish(L["|cff9d9d9dNever activated - nothing recorded.|r"])
		end

		local sameClass = member.meta.classFile ~= nil
			and member.meta.classFile == select(2, UnitClass("player"))

		if data.system == "trees" then
			local spent = 0
			for _, tab in pairs(data.tabs or {}) do spent = spent + (tab.points or 0) end

			-- Spent out of available, because the first number alone says nothing: eight
			-- of fifty-one is somebody who has not finished, and eight of eight is a
			-- level eighteen.
			local available = talents.available
			local spentText = available
				and string.format(available == 1
					and L["|cffffd700%d|r of %d point spent"]
					or L["|cffffd700%d|r of %d points spent"], spent, available)
				or string.format(spent == 1 and L["|cffffd700%d|r point spent"]
					or L["|cffffd700%d|r points spent"], spent)

			if available and available > spent then
				spentText = spentText .. string.format(L[" |cff40bf40(%d to spend)|r"],
					available - spent)
			end

			status:SetText(string.format(
				L["%s%s   |cff888888|||r   seen %s"],
				spentText,
				count > 1 and string.format(
					L["   |cff888888|||r   specialisation %d of %d%s"],
					group, count,
					group == (talents.activeGroup or 1) and L[" |cff40bf40(active)|r"] or "")
					or "",
				UI:Ago(talents.seen)))

			local deepest = 0

			for tab = 1, #data.tabs do
				local tree = data.tabs[tab]
				local left = (tab - 1) * (4 * CELL + TREE_GAP)

				-- The tree's own name, in the reader's language. The client answers only
				-- for the class being played, so this comes from the game's own table -
				-- the same place profession and race names come from.
				local treeName = Family:TalentTreeName(member.meta.classFile, tab,
					tree.name) or string.format(L["Tree %d"], tab)

				nextLabel(left, 0, string.format("|cff88bbff%s|r |cffffd700%d|r",
					treeName, tree.points or 0), 4 * CELL)

				for _, talent in pairs(tree.talents or {}) do
					local tier = talent.tier or 1
					local column = talent.column or 1
					if tier > deepest then deepest = tier end

					-- What this talent is called here. A talent is a spell and the
					-- client names any spell for any class, so its position is turned
					-- into a spell id and the answer is in the reader's language
					-- whoever recorded the member. The recorded word is the fallback,
					-- and is what a record made before that table existed carries.
					local shownName = Family:TalentName(member.meta.classFile,
						talent.tab, tier, column, talent.name)

					local rank = talent.rank or 0
					local maxRank = talent.maxRank or 0

					nextCell(left + (column - 1) * CELL, TITLE + (tier - 1) * CELL, {
						icon = talent.icon,
						-- Only where the client has those talents in those places,
						-- which is to say for the player's own class.
						-- The specialisation being shown travels with the slot: a client
						-- with two of them describes the talent in whichever it is told
						-- about, and the one on screen is the one being asked about.
						talentSlot = sameClass and talent.tab and talent.index
							and { tab = talent.tab, index = talent.index, group = group }
							or nil,
						taken = rank > 0,
						-- Searched by the word on screen and by the one recorded, so
						-- a family holding records from other people's clients is not
						-- searchable in only one language.
						dim = not (matches(shownName) or matches(talent.name)),
						rank = maxRank > 1 and string.format("%d/%d", rank, maxRank)
							or (rank > 0 and "" or nil),
						fallback = {
							{ shownName or "?" },
							{ treeName },
							{ string.format(L["|cffffd700%d|r of %d"], rank, maxRank),
								string.format(L["|cff888888tier %d|r"], tier) },
						},
					})
				end
			end

			y = TITLE + deepest * CELL + 8
			return finish()
		end

		----------------------------------------------------------------------------------
		-- Mists: six tiers of three, one taken from each
		----------------------------------------------------------------------------------

		local chosen = specOf(data.specID)

		status:SetText(string.format(
			L["|cff88bbff%s|r%s   |cff888888|||r   one talent a tier%s"
			.. "   |cff888888|||r   seen %s"],
			chosen.label, chosen.role and string.format(L[" |cff888888- %s|r"], chosen.role)
				or "",
			count > 1 and string.format(
				L["   |cff888888|||r   specialisation %d of %d%s"],
				group, count,
				group == (talents.activeGroup or 1) and L[" |cff40bf40(active)|r"] or "")
				or "",
			UI:Ago(talents.seen)))

		local left = 70

		for tier = 1, #data.tiers do
			local rowY = (tier - 1) * CELL
			nextLabel(0, rowY + 8, string.format(L["|cff888888tier %d|r"], tier), 60)

			local choices = data.tiers[tier].choices or {}
			local picked = data.tiers[tier].chosen

			for column = 1, math.max(#choices, 3) do
				local choice = choices[column]
				if choice then
					-- Mists talents carry an id of their own, so the position is not
					-- needed: the id is the spell, and the client names any spell for
					-- any class. Same answer as the tree grid above, by a shorter road.
					local shownName = Family:TalentNameByID(choice.id, choice.name)

					nextCell(left + (column - 1) * CELL, rowY, {
						icon = choice.icon,
						taken = column == picked,
						chosen = column == picked,
						dim = not (matches(shownName) or matches(choice.name)),
						talentID = choice.id,
						fallback = {
							{ shownName or "?" },
							{ string.format(L["|cff888888tier %d|r"], tier),
								column == picked and L["|cff40bf40taken|r"]
									or L["|cff9d9d9dpassed over|r"] },
						},
					})
				end
			end

			-- What was taken, spelled out beside the row. The icons say which one; the
			-- name says what it is without a hover for each.
			local taken = picked and choices[picked]
			nextLabel(left + 3 * CELL + 8, rowY + 8,
				taken and Family:TalentNameByID(taken.id, taken.name)
					or L["|cff9d9d9dnothing chosen|r"], 220)
		end

		y = #data.tiers * CELL + 8

		-- Glyphs under the talents of the specialisation they belong to, because that is
		-- what they are: part of how this spec is put together.
		if data.glyphs then
			y = y + 8
			nextLabel(0, y, _G.GLYPHS or L["Glyphs"], 200)
			y = y + TITLE

			for socket = 1, #data.glyphs do
				local glyph = data.glyphs[socket]
				local name, icon
				if glyph.spellID then name, icon = Family.Names:Spell(glyph.spellID) end

				nextCell((socket - 1) * CELL, y, {
					icon = icon or glyph.icon,
					taken = glyph.spellID ~= nil,
					dim = name and not matches(name) or false,
					spellID = glyph.spellID,
					fallback = { { name or (glyph.enabled and "empty" or "locked") } },
				})
			end

			y = y + CELL
		end

		return finish()
	end
end

UI:RegisterTab("talents", L["Abilities & Talents"], build)
