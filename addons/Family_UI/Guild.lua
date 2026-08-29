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

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 18
local GRID = 24
local GRID_GAP = 2
local DOT = 8

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
	local rows, cells = {}, {}
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

	-- Stops where the buttons begin rather than running underneath them.
	offNote:SetPoint("RIGHT", whoButton, "LEFT", -8, 0)
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
	status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -28)
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

	----------------------------------------------------------------------------------------

	function frame:Refresh()
		local used, usedCells, y = 0, 0, 0

		list:SetWidth(math.max(scroll:GetWidth(), 200))
		offNote:SetShown(not Family.Guild:Enabled())
		whoButton:SetText(onlineOnly and L["Online only"] or L["Everyone"])
		UI:FitButton(whoButton, 110)

		local function nextRow(height)
			used = used + 1
			local r = row(used)
			r:SetHeight(height or ROW)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", 0, -y)
			r:SetPoint("TOPRIGHT", 0, -y)
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

		local function finish(message)
			for index = used + 1, #rows do rows[index]:Hide() end
			for index = usedCells + 1, #cells do cells[index]:Hide() end
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

		for _, member in ipairs(everyone) do
			if Family.Guild:RunsFamily(guildKey, member.name) then users = users + 1 end
		end

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
			L["|cffffd700%s|r   |cff888888|||r   %d shown of %d   |cff888888|||r   "
			.. "|cffffd700%d|r running Family   |cff888888|||r   "
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
