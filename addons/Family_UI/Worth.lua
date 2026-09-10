-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What everything the family holds is worth, at what the auction house was last asking.
--
-- Asked for 2026-09-10 and the reason the price work happened at all. The arithmetic is
-- `Index:Worth` and lives with the index, because the index is already the thing that knows who
-- holds what and a walk of it is one pass rather than a question per member.
--
-- **A section of its own rather than a set on the summary**, decided rather than defaulted. The
-- summary's sets read `meta` and nothing else, on purpose: that is what lets them cost the same
-- for forty members as for four, and this walks every item every member holds. Here a slower page
-- is what a reader expects, and the count of what could not be priced has room to be a sentence
-- instead of a column nobody reads.
--
-- **It never draws a total without saying what it left out.** A worth that quietly omits four
-- hundred unpriced stacks is the kind of number that gets believed, and believed numbers are how
-- somebody sells a bank alt short. The same rule the pet training line follows.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local GREY = "|cff888888"

local function classColour(classFile)
	local colours = _G.RAID_CLASS_COLORS
	local colour = classFile and colours and colours[classFile]
	if not colour then return 1, 1, 1 end
	return colour.r, colour.g, colour.b
end

local function build(frame)
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText(L["What everything is worth"])

	local summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", 4, -30)
	summary:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
	summary:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -52)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	local ROW = 18
	local rows = {}

	-- **`left`, `middle` and `right` on a frame**, which is the shape the character, professions
	-- and abilities panels already use. Not decoration: the harness reads a panel through its
	-- rows, and a panel that builds bare font strings on the list can only be checked by
	-- sweeping every string in the client - which is how a check for the sender of a letter
	-- passed for a month on a word in the development icon sheet.
	local function rowAt(index)
		local row = rows[index]
		if row then return row end

		row = CreateFrame("Frame", nil, list)
		row:SetHeight(ROW)

		row.left = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.left:SetPoint("LEFT", 4, 0)
		row.left:SetJustifyH("LEFT")

		row.middle = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.middle:SetJustifyH("LEFT")

		row.right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.right:SetPoint("RIGHT", -8, 0)
		row.right:SetJustifyH("RIGHT")

		UI:NoWrap(row.left, row.middle, row.right)

		rows[index] = row
		return row
	end

	function frame:Refresh()
		local width = math.max(UI:ListWidth(scroll) - 16, 260)
		list:SetWidth(width + 16)

		local held = Family.Index:Worth()
		local worth, priced, unpriced, oldest = Family.Index:WorthTotal(held)

		-- **Nothing priced is not nothing owned**, and the two must not read alike (§2.2). A
		-- page of noughts says the family is poor; this says Family has not been told yet, and
		-- where being told happens.
		if priced == 0 then
			summary:SetText(GREY .. L["Nothing here has a price yet. Family learns what "
				.. "things are worth from the auction house while you browse it."] .. "|r")
		else
			local line = string.format(L["%s across %d item(s), and %d could not be priced"],
				UI:Money(worth), priced, unpriced)
			if oldest then
				line = line .. GREY .. "   |||   "
					.. string.format(L["oldest price %s"], UI:Ago(oldest)) .. "|r"
			end
			summary:SetText(line)
		end

		local y, used = 0, 0

		for _, entry in ipairs(held) do
			-- Somebody holding nothing anybody has a price for is not a row worth a line:
			-- the sentence above already says how much of the family that is.
			if entry.priced > 0 then
				used = used + 1
				local row = rowAt(used)

				local label = entry.name
				if entry.familyName then
					label = string.format(L["%s |cff9d9d9dof %s|r"], label,
						tostring(entry.familyName))
				elseif entry.realm and entry.realm ~= GetRealmName() then
					label = label .. GREY .. " (" .. entry.realm .. ")|r"
				end

				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -y)
				row:SetPoint("TOPRIGHT", 0, -y)

				row.left:SetWidth(math.max(width * 0.42, 80))
				row.left:SetText(label)
				row.left:SetTextColor(classColour(entry.classFile))

				row.middle:ClearAllPoints()
				row.middle:SetPoint("LEFT", math.max(width * 0.42, 80) + 8, 0)
				row.middle:SetWidth(math.max(width * 0.26, 60))
				row.middle:SetText(GREY .. string.format(L["%d priced, %d not"],
					entry.priced, entry.unpriced) .. "|r")

				row.right:SetWidth(math.max(width * 0.26, 60))
				row.right:SetText(UI:Money(entry.worth))

				row:Show()
				y = y + ROW
			end
		end

		for index = used + 1, #rows do rows[index]:Hide() end

		list:SetHeight(math.max(y, 1))
	end
end

UI:RegisterTab("worth", L["Worth"], build)
