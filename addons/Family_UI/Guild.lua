-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The guild, and what everyone in it is wearing (§7).
--
-- The roster is the game's own - Family adds nothing to who is in the guild, and could not.
-- What it adds is one dot per row saying whether that player runs Family, and behind the ones
-- that do, their characters' gear and talents.
--
-- The dot is drawn as a colour rather than as a picture on purpose. A texture path that does
-- not exist on a client draws nothing, silently, and no code can ask whether it exists
-- (HANDOFF §3) - so the one mark on this panel that has to be legible on all three clients is
-- the one thing here that cannot be a file name.
--
-- **The grid of what you share lives here too** (§7.1), above the roster it governs, in the
-- way Wide Family's grid lives on Wide Family's panel. A switch belongs in Options and a grid
-- does not, because a grid is the feature rather than a preference about it. It is drawn
-- whether guild share is on or off, greyed while it is off: a grid that looked live and
-- quietly recorded grants before the transport existed would be the one way this feature
-- could undo a default it has no business touching.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 18
local GRID = 24
local GRID_GAP = 2
local DOT = 8

-- One tick box and the profession beside it. Wide enough for "Blacksmithing 300/300" in the
-- longest of the five languages, because a column that fits English and clips German is a
-- column measured in the wrong place.
local TICK = 210
local TICK_ROW = 22

-- The paper-doll order again, so a guildmate's row of gear reads the same way a member's
-- does. Kept here rather than shared with Character.lua because the two panels are not
-- allowed to reach into each other, and nineteen numbers are cheaper than a dependency.
local SLOT_ORDER = {
	{ 1, "HEADSLOT", "Head" },       { 2,  "NECKSLOT",     "Neck" },
	{ 3, "SHOULDERSLOT", "Shoulder" }, { 15, "BACKSLOT",   "Chest" },
	{ 5, "CHESTSLOT", "Chest" },     { 4,  "SHIRTSLOT",    "Shirt" },
	{ 19, "TABARDSLOT", "Tabard" },  { 9,  "WRISTSLOT",    "Wrists" },
	{ 10, "HANDSSLOT", "Hands" },    { 6,  "WAISTSLOT",    "Waist" },
	{ 7, "LEGSSLOT", "Legs" },       { 8,  "FEETSLOT",     "Feet" },
	{ 11, "FINGER0SLOT", "Finger" }, { 12, "FINGER1SLOT",  "Finger" },
	{ 13, "TRINKET0SLOT", "Trinket" }, { 14, "TRINKET1SLOT", "Trinket" },
	{ 16, "MAINHANDSLOT", "MainHand" },
	{ 17, "SECONDARYHANDSLOT", "SecondaryHand" },
	{ 18, "RANGEDSLOT", "Ranged" },
}

--------------------------------------------------------------------------------------------

-- The guild's own roster, as the client has it. Offline members are only in it if the client
-- has been told to include them, which is a setting on the game's own guild frame - so it is
-- asked for here rather than assumed, or the "everyone" filter would quietly show the same
-- list as "online only".
local function roster()
	local list = {}
	local count = Family:TryCall(GetNumGuildMembers) or 0

	for index = 1, count do
		local name, rank, rankIndex, level, _, zone, _, _, online, status, classFile =
			Family:TryCall(GetGuildRosterInfo, index)

		if name then
			list[#list + 1] = {
				name = name,
				rank = rank,
				rankIndex = tonumber(rankIndex) or 0,
				level = tonumber(level) or 0,
				zone = zone,
				online = online and true or false,
				status = status,
				classFile = classFile,
			}
		end
	end

	table.sort(list, function(a, b)
		if a.online ~= b.online then return a.online end
		if a.level ~= b.level then return a.level > b.level end
		return tostring(a.name) < tostring(b.name)
	end)

	return list
end

-- Both specialisations, said in the space of a line. The full trees are what the talent panel
-- is for; what belongs beside somebody's gear is the shape of their build.
local function talentSummary(talents)
	if type(talents) ~= "table" or type(talents.groups) ~= "table" then
		return L["|cff9d9d9dno talents recorded|r"]
	end

	local parts = {}

	for group = 1, (talents.groupCount or 2) do
		local entry = talents.groups[group]
		if entry then
			local text

			if entry.system == "trees" and type(entry.tabs) == "table" then
				local points = {}
				for _, tab in ipairs(entry.tabs) do
					points[#points + 1] = tostring(tab.points or 0)
				end
				text = table.concat(points, " / ")
			elseif entry.specID then
				local name
				if GetSpecializationInfoByID then
					local _, specName = Family:TryCall(GetSpecializationInfoByID,
						entry.specID)
					name = specName
				end
				text = name or string.format(L["specialisation #%s"], tostring(entry.specID))
			end

			if text then
				-- Which of the two they are actually in, because a build only means
				-- something next to whether it is the one they are playing.
				parts[#parts + 1] = (group == talents.activeGroup)
					and ("|cffffd700" .. text .. "|r")
					or ("|cff888888" .. text .. "|r")
			end
		end
	end

	if #parts == 0 then return L["|cff9d9d9dno talents recorded|r"] end
	return table.concat(parts, "  |cff555555|||r  ")
end

--------------------------------------------------------------------------------------------

local function build(frame)
	local rows, cells, boxes = {}, {}, {}
	local onlineOnly = true
	local opened                     -- which player's characters are showing, by bare name

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText(L["Guild share"])

	-- Off is a state this panel explains rather than a switch it carries. Both sharing
	-- features are switched in Options, together, so a player looks in one place for a switch
	-- instead of hunting the panel each one governs. Wide Family's panel says the same thing
	-- in the same way.
	local offNote = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	offNote:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -6)
	offNote:SetJustifyH("LEFT")
	offNote:SetText(L["|cff9d9d9dGuild share is switched off, so nothing here will fill in. "
		.. "Switch it on in Options: it shows your guild the gear and talents of your "
		.. "characters in it, and shows you theirs.|r"])

	-- Right to left, each anchored to the one beside it rather than to a fixed offset.
	-- The offsets were -6 and -122, which is -6 and "-6 minus a button that is 110 wide" -
	-- true of the English labels and of nothing else. Anchored to each other, a longer word
	-- pushes its neighbour along instead of being drawn over it.
	local updateButton = CreateFrame("Button", "FamilyGuildUpdate", frame,
		"UIPanelButtonTemplate")
	updateButton:SetHeight(22)
	updateButton:SetPoint("TOPRIGHT", -6, -6)
	updateButton:SetText(L["Update now"])
	UI:FitButton(updateButton, 110)

	local whoButton = CreateFrame("Button", "FamilyGuildWho", frame, "UIPanelButtonTemplate")
	whoButton:SetHeight(22)
	whoButton:SetPoint("TOPRIGHT", updateButton, "TOPLEFT", -6, 0)
	whoButton:SetScript("OnClick", function()
		onlineOnly = not onlineOnly
		frame:Refresh()
	end)

	-- A width rather than a right anchor, because this line is measured: how far down the
	-- status sits depends on how many lines it takes, and a string that knows its right edge
	-- only by where it is pinned cannot answer that. Stops where the buttons begin.
	offNote:SetWidth((UI.CONTENT_W or 740) - 250)
	updateButton:SetScript("OnClick", function()
		local ok, why = Family.Guild:Refresh("asked for")
		if ok then
			Family:Print(L["Asked the guild. Whoever is online and running Family answers."])
		else
			Family:Print(L["|cffffaa00Could not: %s|r"], tostring(why))
		end
		frame:Refresh()
	end)

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("RIGHT", -8, 0)
	status:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -2, -8)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	----------------------------------------------------------------------------------------

	local function row(index)
		local existing = rows[index]
		if existing then return existing end

		local r = CreateFrame("Button", nil, list)
		r:SetHeight(ROW)

		-- The dot. A colour rather than a file, because a colour cannot be missing on a
		-- client and a texture path can (see the note at the top of this file).
		r.dot = r:CreateTexture(nil, "ARTWORK")
		r.dot:SetSize(DOT, DOT)
		r.dot:SetPoint("LEFT", 6, 0)

		r.text = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.text:SetPoint("LEFT", 20, 0)
		r.text:SetWidth(220)
		r.text:SetJustifyH("LEFT")

		r.middle = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.middle:SetPoint("LEFT", 244, 0)
		r.middle:SetJustifyH("LEFT")

		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.right:SetPoint("RIGHT", -8, 0)
		r.right:SetWidth(200)
		r.right:SetJustifyH("RIGHT")

		UI:NoWrap(r.text, r.middle, r.right)

		r.highlight = r:CreateTexture(nil, "BACKGROUND")
		r.highlight:SetAllPoints()
		r.highlight:SetColorTexture(1, 1, 1, 0.06)
		r.highlight:Hide()
		r:SetScript("OnEnter", function(self) self.highlight:Show() end)
		r:SetScript("OnLeave", function(self) self.highlight:Hide() end)

		rows[index] = r
		return r
	end

	local function cell(index)
		local existing = cells[index]
		if existing then return existing end

		local button = CreateFrame("Button", nil, list)
		button:SetSize(GRID, GRID)

		button.border = button:CreateTexture(nil, "BACKGROUND")
		button.border:SetAllPoints()
		button.border:SetColorTexture(1, 1, 1, 0.05)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)

		button.level = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.level:SetPoint("BOTTOMRIGHT", -1, 1)

		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

		UI:AttachTooltip(button, function(self)
			if self.itemLink then return "itemlink", self.itemLink end
			if self.itemID then return "item", self.itemID end
			if self.lines then return nil, nil, self.lines end
			return nil
		end)

		cells[index] = button
		return button
	end

	-- The grid's tick boxes, in their own pool. They are check buttons and the cells above
	-- are not, so one pool could not serve both without a frame remembering which it had been.
	local function box(index)
		local existing = boxes[index]
		if existing then return existing end

		local b = CreateFrame("CheckButton", nil, list, "UICheckButtonTemplate")
		b:SetSize(20, 20)

		-- **Lifted above the rows, or nothing here can be clicked.** A row is a Button as
		-- wide as the list, it takes the mouse whether or not anything is hooked to its
		-- click, and it is a sibling of this box at the same frame level - so the row wins
		-- the hit test and a grid of tick boxes silently becomes a picture of one. What the
		-- player sees is the row's hover highlight coming up under a box that will not
		-- answer, which is exactly how this was found.
		b:SetFrameLevel(list:GetFrameLevel() + 5)

		b.label = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		b.label:SetPoint("LEFT", b, "RIGHT", 2, 0)
		b.label:SetWidth(TICK - 24)
		b.label:SetJustifyH("LEFT")
		UI:NoWrap(b.label)

		boxes[index] = b
		return b
	end

	----------------------------------------------------------------------------------------

	function frame:Refresh()
		local used, usedCells, usedBoxes, y = 0, 0, 0, 0

		list:SetWidth(UI:ListWidth(scroll))
		-- The note is a sentence, and a sentence is one line in English and two in French.
		-- Measured and the status moved below it, rather than a fixed drop that was right
		-- in the language it was written in and drew the two through each other elsewhere.
		local off = not Family.Guild:Enabled()
		offNote:SetShown(off)

		-- Sixteen under the title when there is no note, which is about where the status sat
		-- when a checkbox stood between the two. Six put it against the heading.
		local drop = 16
		if off then
			local height = math.max(14, math.ceil(offNote:GetStringHeight() or 14))
			offNote:SetHeight(height)
			-- Clear of the last line rather than against it, the same gap the Wide Family
			-- panel leaves under the same sentence.
			drop = height + 20
		end
		status:ClearAllPoints()
		status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -drop)
		status:SetPoint("RIGHT", -8, 0)

		-- Greyed while the feature is off, because neither of them can do anything: there
		-- is no roster to filter and nothing to ask a guild that is not being spoken to.
		-- A button that looks live and answers nothing is worse than one that says it is
		-- not available, which is what the Wide Family panel does with its own controls.
		updateButton:SetEnabled(not off)
		whoButton:SetEnabled(not off)
		whoButton:SetText(onlineOnly and L["Online only"] or L["Everyone"])
		UI:FitButton(whoButton, 110)

		local function nextRow(height)
			used = used + 1
			local r = row(used)
			r:SetHeight(height or ROW)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -y)
			r:SetPoint("TOPRIGHT", 0, -y)
			-- Back to the width it was built with. One row is handed out for the grid's
			-- heading and another for a guildmate's professions, and both want more room than
			-- a name column - so the width has to be put back or the next roster row that
			-- borrows the frame keeps it.
			-- And the mouse back on. The grid's rows switch it off so that a hover
			-- highlight does not come up under a tick box, and a roster row that borrows
			-- one of those frames afterwards has to be clickable again.
			r:EnableMouse(true)
			r.text:SetWidth(220)
			r.text:SetText("")
			r.middle:SetText("")
			r.right:SetText("")
			r.dot:Hide()
			r:SetScript("OnClick", nil)
			r:Show()
			y = y + (height or ROW)
			return r
		end

		local function placeCell(atX, atY)
			usedCells = usedCells + 1
			local c = cell(usedCells)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", atX, -atY)
			c.itemID, c.itemLink, c.lines = nil, nil, nil
			c.level:SetText("")
			c.border:SetColorTexture(1, 1, 1, 0.05)
			if c.icon.SetDesaturated then c.icon:SetDesaturated(false) end
			c:Show()
			return c
		end

		local function placeBox(atX, atY)
			usedBoxes = usedBoxes + 1
			local b = box(usedBoxes)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", atX, -atY)
			b:SetScript("OnClick", nil)
			b:Show()
			return b
		end

		local function finish(message)
			for index = used + 1, #rows do rows[index]:Hide() end
			for index = usedCells + 1, #cells do cells[index]:Hide() end
			for index = usedBoxes + 1, #boxes do boxes[index]:Hide() end
			list:SetHeight(math.max(y, 1))
			if message then status:SetText(message) end
		end

		------------------------------------------------------------------------------------

		if not Family.Codec:CanTalk() then
			-- Said outright rather than left as a panel that never fills. §2.2 applies to
			-- Family's own abilities as much as to its records.
			whoButton:Hide()
			updateButton:Hide()
			return finish(L["|cffffaa00Guild share needs the serialisation libraries "
				.. "(LibSerialize and LibDeflate) and this client has neither loaded, so "
				.. "nothing can be sent or received.|r"])
		end

		whoButton:Show()
		updateButton:Show()

		local guildKey, guildName = Family.Guild:Current()

		if not guildKey then
			return finish(L["|cff9d9d9dThis character is not in a guild. Guild share is "
				.. "about one guild on one realm, so there is nothing for it to be about "
				.. "from here.|r"])
		end

		----------------------------------------------------------------------------------------
		-- What you share with this guild (§7.1)
		--
		-- Above the roster it governs, and drawn before the switch is consulted rather than
		-- after it: a player who has not switched guild share on should be able to see what
		-- ticking a box would do, and the boxes are greyed so that seeing it is all they can do.
		--
		-- One box per character per profession, and no default anywhere behind them - a grid
		-- nobody has touched shares nothing, and so does a grid whose transport is off. Those are
		-- two independent reasons, which is the point.
		----------------------------------------------------------------------------------------

		do
			local on = Family.Guild:Enabled()
			local width = UI:ListWidth(scroll)
			local perLine = math.max(1, math.floor((width - 24) / TICK))
			local ticks = Family.Guild:CountShared(guildKey)

			-- **Folded away by default.** This panel is about the guild's people, and the grid
			-- is something you open when you want to change what you offer: a player with eight
			-- characters in the guild has thirty rows of it above a roster of a hundred and
			-- sixty, which is a grid hiding the panel it was put on. Folded, the heading still
			-- says how much is offered, so the state is stated rather than hidden with the rows.
			local heading = nextRow()
			heading.text:SetWidth(width - 8)
			heading:SetScript("OnClick", function()
				FamilyDB.ui = FamilyDB.ui or {}
				FamilyDB.ui.guildGrid = not (FamilyDB.ui.guildGrid == true)
				frame:Refresh()
			end)

			local open = (FamilyDB.ui or {}).guildGrid == true

			heading.text:SetText(string.format(open
				and L["|cffffd700- What you share with %s|r   |cff888888one profession at a time, "
					.. "and nothing until it is ticked|r"]
				or (ticks > 0
					and L["|cffffd700+ What you share with %s|r   |cff888888%d offered - click to "
						.. "open|r"]
					or L["|cffffd700+ What you share with %s|r   |cff888888nothing ticked - click "
						.. "to open|r"]), guildName, ticks))

			if open then

				-- Whose characters they are, in a settled order. Offering() is the authority on
				-- which of ours are in this guild - the same answer the wire gets, so the grid
				-- cannot offer a box for somebody who would never be sent.
				local offering = Family.Guild:Offering() or {}
				local members = Family.Database:Members()

				local keys = {}
				for key in pairs(offering) do keys[#keys + 1] = key end
				table.sort(keys)

				if #keys == 0 then
					local none = nextRow()
					none:EnableMouse(false)
					none.text:SetWidth(width - 8)
					none.text:SetText(L["   |cff9d9d9dNone of your characters is in this guild, so "
						.. "there is nothing to offer it.|r"])
				end

				-- Named rather than counted. "1 left out" tells a player that something is wrong
				-- and gives them no way to find out what, which is a worse answer than none; the
				-- word the client used for it is the one thing that identifies it, and it is the
				-- one thing this end has.
				local nameless, namelessMore = {}, 0

				for _, key in ipairs(keys) do
					local meta = (members[key] or {}).meta or {}

					local who = nextRow()
					who:EnableMouse(false)
					local red, green, blue = UI:ClassColour(meta.classFile)
					who.text:SetWidth(width - 8)
					who.text:SetText(string.format("   |cff%02x%02x%02x%s|r  |cff888888%s|r",
						red * 255, green * 255, blue * 255, meta.name or key,
						tostring(meta.level or "?")))

					-- Identifiers, never names (§2.1). A profession this client gave no id for is
					-- filed under a word, and a word is one language, so it cannot cross and is not
					-- offered. It is named below instead of being left out in silence, which is the
					-- same promise §7.1 makes about recipes without ids.
					-- A profession filed under a word rather than an id, where the skill line
					-- table knows the word, is that profession - so it is looked up and offered
					-- like any other. Recipes:Crafters has resolved names this way since
					-- whole-family search was written, and the professions scanner does it when
					-- it re-keys a member.
					--
					-- Without this a character recorded by a version that had no ids, and not
					-- played since, offered nothing and was told it had no professions at all
					-- while the line at the foot of the grid listed three of them by name. The
					-- ids were a lookup away the whole time.
					local offered, seen, cannot = {}, {}, 0

					for id, skill in pairs(meta.skills or {}) do
						local line = type(id) == "number" and id or Family:SkillLineFor(id)

						if line and not seen[line] then
							seen[line] = true
							offered[#offered + 1] = { id = line, skill = skill,
								name = Family:ProfessionName(line, skill.name) }
						elseif not line then
							-- A word this client's table has never heard of: a rogue's
							-- poisons, or a skill from a client newer than the table. It
							-- cannot cross and it is named at the foot of the grid.
							cannot = cannot + 1
							if #nameless < 6 then
								nameless[#nameless + 1] = string.format("%s (%s)",
									tostring(skill.name or id),
									tostring(meta.name or key))
							else
								namelessMore = namelessMore + 1
							end
						end
					end
					table.sort(offered, function(a, b) return a.name < b.name end)

					if #offered == 0 then
						local note = nextRow()
						note:EnableMouse(false)
						note.text:SetWidth(width - 8)

						-- Two different states, and saying the first about the second is how
						-- this panel came to tell a player that a character had no
						-- professions in the same breath as listing three of them.
						note.text:SetText(cannot > 0
							and L["      |cff9d9d9dNothing on this character can be offered. "
								.. "The line at the foot of the grid says why.|r"]
							or L["      |cff9d9d9dNo professions recorded on this "
								.. "character yet. Open one of its profession windows "
								.. "once.|r"])
					end

					local placed = 0
					while placed < #offered do
						-- The row is a spacer holding the height, and it must not take the mouse:
						-- it is as wide as the list and the boxes sit on top of it.
						nextRow(TICK_ROW):EnableMouse(false)

						for column = 1, perLine do
							local entry = offered[placed + column]
							if entry then
								local b = placeBox(24 + (column - 1) * TICK,
									y - TICK_ROW + 1)

								-- Greyed in the words as well as in the widget. The game
								-- greys a disabled box on its own and cannot grey the font
								-- string beside it, so a live-looking label would sit next
								-- to a dead box.
								b.label:SetText(string.format(
									on and "%s |cffffd700%d|r|cff888888/%d|r"
										or "|cff777777%s %d/%d|r",
									entry.name, entry.skill.rank or 0,
									entry.skill.maxRank or 0))

								b:SetChecked(Family.Guild:Shares(guildKey, key, entry.id))
								b:SetEnabled(on)

								if on then
									b:SetScript("OnClick", function(self)
										Family.Guild:SetShare(guildKey, key,
											entry.id,
											self:GetChecked() and true or false)
										frame:Refresh()
									end)
								end
							end
						end
						placed = placed + perLine
					end
				end

				-- What the grid adds up to, said in a line, because a player scrolling past it wants
				-- to know whether they are sharing anything without reading every box.
				local total = nextRow()
				total:EnableMouse(false)
				total.text:SetWidth(width - 8)

				if not on then
					total.text:SetText(L["   |cff9d9d9dGuild share is switched off, so nothing is "
						.. "offered whatever is ticked here. The switch is in Options.|r"])
				elseif ticks == 0 then
					total.text:SetText(L["   |cff9d9d9dNothing is ticked, so this guild is sent no "
						.. "professions at all.|r"])
				else
					-- Said where somebody can read it, because it is the half of the promise
					-- Family can actually keep: unticking stops the next offering carrying it,
					-- and everything one player sends replaces everything held from them.
					total.text:SetText(string.format(L["   |cff888888%d offered. Unticking one "
						.. "stops it being sent, and what they already hold is replaced the next "
						.. "time they hear from you.|r"], ticks))
				end

				if #nameless > 0 then
					local left = nextRow()
					left:EnableMouse(false)
					left.text:SetWidth(width - 8)
					-- Capped rather than allowed to run off the edge of the panel. The row
					-- does not wrap, so a long list was silently cut in half by the frame's
					-- right-hand edge - which is the same failure as saying nothing.
					left.text:SetText(string.format(L["   |cffffaa00Not offered: %s%s. This client "
						.. "gave no identifier for those, only what they are called - and a name "
						.. "is readable in one language, so it cannot cross.|r"],
						table.concat(nameless, ", "),
						namelessMore > 0
							and string.format(L[" and %d more"], namelessMore) or ""))
				end

			end

			y = y + 10
		end

		if not Family.Guild:Enabled() then
			return finish(string.format(L["|cffffaa00Guild share is switched off.|r "
				.. "|cff888888Nothing is sent to %s and nothing that arrives is read. "
				.. "What was collected before is kept.|r"], guildName))
		end

		-- The client only lists offline members if it has been asked to, and this panel's
		-- "everyone" would otherwise quietly show the same list as "online only".
		Family:TryCall(SetGuildRosterShowOffline, not onlineOnly)
		Family:TryCall(_G.C_GuildInfo and _G.C_GuildInfo.GuildRoster or _G.GuildRoster)

		local everyone = roster()
		local shown, users = 0, 0

		-- **People, not characters.** A player with eight alts in the guild is eight rows on
		-- this roster and one person running Family, and counting the rows made the panel
		-- tell them that nine clients were out there when eight of the nine were their own -
		-- which is the one number on the panel that is supposed to answer "is anybody else
		-- out there". Ours collapse into one, because they are one; everybody else is
		-- already one row per player, since a guildmate's alts are their own guild rows and
		-- what identifies a player is the bare name their client sends.
		local ourselves = false
		for _, member in ipairs(everyone) do
			if Family.Guild:IsOurs(member.name) then
				ourselves = true
			elseif Family.Guild:RunsFamily(guildKey, member.name) then
				users = users + 1
			end
		end
		if ourselves then users = users + 1 end

		for _, member in ipairs(everyone) do
			if member.online or not onlineOnly then
				shown = shown + 1

				local runs = Family.Guild:RunsFamily(guildKey, member.name)
				local characters = runs
					and Family.Guild:CharactersOf(guildKey, member.name) or {}

				local r = nextRow()
				local red, green, blue = UI:ClassColour(member.classFile)

				-- Filled for a player running Family, hollow-looking for one who is not.
				-- Both are drawn: an absent dot would read as a rendering fault, and the
				-- ordinary state of a guild is that most of them do not.
				r.dot:Show()
				if runs then
					r.dot:SetColorTexture(0.2, 0.85, 0.3, 1)
				else
					r.dot:SetColorTexture(0.35, 0.35, 0.35, 0.6)
				end

				r.text:SetText(string.format("|cff%02x%02x%02x%s|r%s",
					red * 255, green * 255, blue * 255, member.name,
					member.online and "" or L["  |cff777777offline|r"]))

				r.middle:SetText(string.format("|cff888888%s   %s|r",
					tostring(member.level), tostring(member.rank or "")))

				local ours = Family.Guild:IsOurs(member.name)
				if ours then
					r.text:SetText(r.text:GetText() .. L["  |cff888888(you)|r"])
				end

				if not runs then
					r.right:SetText(L["|cff555555not running Family|r"])
				elseif #characters == 0 then
					r.right:SetText(L["|cff888888heard from, nothing sent yet|r"])
				else
					local best
					for _, entry in ipairs(characters) do
						local level = entry.meta.itemLevel
						if level and (not best or level > best) then best = level end
					end

					r.right:SetText(string.format(
						#characters == 1
							and L["|cffffd700%s|r |cff888888ilvl   |||   %d character   |||   %s|r"]
							or L["|cffffd700%s|r |cff888888ilvl   |||   %d characters   |||   %s|r"],
						best and string.format("%.1f", best) or "?",
						#characters,
						characters[1].at and UI:Ago(characters[1].at) or L["unknown"]))

					local bare = Family.Guild:BareName(member.name)
					r:SetScript("OnClick", function()
						opened = (opened ~= bare) and bare or nil
						frame:Refresh()
					end)

					----------------------------------------------------------------------
					-- One player's characters, opened
					----------------------------------------------------------------------

					if opened == bare then
						for _, entry in ipairs(characters) do
							local line = nextRow()
							local cr, cg, cb = UI:ClassColour(entry.meta.classFile)

							line.text:SetText(string.format(
								"    |cff%02x%02x%02x%s|r  |cff888888%s|r",
								cr * 255, cg * 255, cb * 255,
								entry.meta.name or entry.key,
								tostring(entry.meta.level or "?")))

							line.middle:SetText(talentSummary(entry.talents))

							local gear = entry.equipment
							line.right:SetText(gear and gear.itemLevel
								and string.format(L["|cffffd700%.1f|r |cff888888ilvl|r"],
									gear.itemLevel)
								or L["|cff9d9d9dno gear recorded|r"])

							if gear and gear.worn then
								for index, slot in ipairs(SLOT_ORDER) do
									local c = placeCell(
										24 + (index - 1) * (GRID + GRID_GAP), y)
									local item = gear.worn[slot[1]]

									if item then
										Family.Names:Item(item.id, "guild", function()
											if frame:IsShown() then frame:Refresh() end
										end)

										c.itemID = item.id
										c.itemLink = item.item
										c.icon:SetTexture(
											Family:TryCall(GetItemIcon, item.id)
											or "Interface\\Icons\\INV_Misc_QuestionMark")
										c.level:SetText(item.itemLevel
											and ("|cffffd700" .. item.itemLevel .. "|r")
											or "")

										local quality = select(3,
											Family:TryCall(GetItemInfo, item.id))
										local colours = _G.ITEM_QUALITY_COLORS
										local colour = quality and colours
											and colours[quality]
										if colour then
											c.border:SetColorTexture(colour.r, colour.g,
												colour.b, 0.7)
										end
									else
										c.icon:SetTexture(
											"Interface\\PaperDoll\\UI-PaperDoll-Slot-"
											.. slot[3])
										if c.icon.SetDesaturated then
											c.icon:SetDesaturated(true)
										end
										c.lines = { { _G[slot[2]] or slot[2],
											L["|cff9d9d9dempty|r"] } }
									end
								end

								y = y + GRID + 4
							end

							-- What that character shares, and only that: absent is the
							-- ordinary state, because a grid starts empty (§7.1).
							--
							-- A rank on its own is an honest answer and is shown as one.
							-- What it cannot say is whether they know any particular
							-- recipe, and nothing written here implies that it can: that
							-- is what a recipe list is for, and a recipe list is not what
							-- crossed.
							if entry.professions and #entry.professions > 0 then
								local parts = {}
								for _, skill in ipairs(entry.professions) do
									parts[#parts + 1] = string.format(
										"%s |cffffd700%d|r|cff888888/%d|r",
										Family:ProfessionName(skill.skillLine),
										skill.rank or 0, skill.maxRank or 0)
								end

								local shared = nextRow()
								shared.text:SetWidth(UI:ListWidth(scroll) - 8)
								shared.text:SetText(string.format(
									L["      |cff66bbffshares|r  %s"],
									table.concat(parts, "   |cff555555|||r   ")))
							end
						end

						y = y + 6
					end
				end
			end
		end

		if shown == 0 then
			return finish(L["|cff9d9d9dNobody to show. The guild roster arrives a moment "
				.. "after the panel does - try Update now.|r"])
		end

		-- "1 running Family" in a guild of a hundred is the ordinary state of things and not
		-- a fault, so it is said as a fact with the reason beside it rather than left to read
		-- as an empty panel. Somebody running Family who has not been heard from yet is
		-- indistinguishable here from somebody who is not running it at all - that is what
		-- the addon channel gives us, and saying so beats implying otherwise.
		return finish(string.format(
			-- "guildmates shown" rather than "shown", because the grid now sits between
			-- this line and the roster it counts, and a bare number that far from its list
			-- reads as though it might be counting the rows just above it.
			L["|cffffd700%s|r   |cff888888|||r   %d guildmates shown of %d   "
			.. "|cff888888|||r   |cffffd700%d|r running Family   |cff888888|||r   "
			.. "|cff888888%s|r"],
			guildName, shown, #everyone, users,
			users <= 1
				and L["nobody else has answered yet - they must be online and running it, "
					.. "and Update now asks again"]
				or L["click one of them to see their characters"]))
	end
end

-- Registered inside OnDatabaseReady for the reason the Wide Family tab is: by the time
-- Family_UI's files run, Family's own ADDON_LOADED has been and gone, so this runs at once
-- and the tab keeps its place in the strip.
--
-- Unlike that one, the tab is here whether the feature is on or off. Wide Family's is hidden
-- because a panel advertising an untested consent feature invites the use it is being
-- withheld from; this panel *is* where the switch lives, and hiding the switch inside the
-- feature it turns off would be a poor joke.
Family:OnDatabaseReady("ui.guild", function()
	UI:RegisterTab("guild", L["Guild"], build)
end)
