-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Narrowing a list of characters: which realm, which class, which levels.
--
-- Two panels had grown one of these each, separately - the summary's and the character
-- panel's - and two more were asked for. Four would have been four ideas of what a filter bar
-- is, and the first time one of them learned something the other three would not have. So it
-- is a widget, the way `CreateChoicePicker` is a widget, and a panel that wants filtering asks
-- for one instead of building it.
--
-- **What is not here is the search box.** Every panel has one and no two of them search the
-- same thing: member names on the summary, whatever section is open on the character panel,
-- recipes on professions, items on possessions. A box that means four things is not one
-- control, and pretending otherwise would put a `subject` parameter on this and make every
-- caller explain itself.
--
-- The choices are always what the family actually has. Offering a warlock filter to a family
-- with no warlock is offering a way to show nothing.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW_HEIGHT = 22

-- How wide the row of them is, said once.
--
-- The arithmetic was here already, in `filters:Width()`, for a caller that wanted to put
-- something after the row - and the frame holding the row was given a height and never a
-- width. A container with a height and no width has no area. The number is one number now and
-- the frame is the first thing to use it.
local ROW_WIDTH = 130 + 8 + 120 + 12 + 40 + 10 + 34 + 6 + 10 + 34

--------------------------------------------------------------------------------------------

-- Whose realms and classes are on offer.
--
-- Our own members by default, which is what every caller wanted until the character panel
-- asked: that one draws siblings beside our own, so its filters have to offer a realm only a
-- linked family is on and a class only they have. Offering the wrong population is a filter
-- that cannot reach half the rows it is drawn above, and the panel would look broken rather
-- than narrow.
local function ourMembers()
	local list = {}
	for _, entry in pairs(Family.Database:Members()) do
		list[#list + 1] = entry
	end
	return list
end

local function realmsHeld(entries)
	local seen, list = {}, {}
	for _, entry in ipairs(entries) do
		local realm = entry.meta and entry.meta.realm
		if realm and not seen[realm] then
			seen[realm] = true
			list[#list + 1] = realm
		end
	end
	table.sort(list)
	return list
end

local function classesHeld(entries)
	local seen, list = {}, {}
	for _, entry in ipairs(entries) do
		local classFile = entry.meta and entry.meta.classFile
		if classFile and not seen[classFile] then
			seen[classFile] = true
			list[#list + 1] = classFile
		end
	end
	table.sort(list)
	return list
end

--------------------------------------------------------------------------------------------

-- `onChange` is called whenever any of them is touched, and is where the panel redraws.
-- `population` is optional and answers which members the choices are drawn from; without one
-- it is our own.
function UI:CreateMemberFilters(parent, onChange, population)
	local filters = {}

	local function held()
		return (population and population()) or ourMembers()
	end

	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(ROW_WIDTH, ROW_HEIGHT)
	filters.frame = frame

	local function changed()
		if onChange then onChange() end
	end

	local realmButton = UI:CreateChoicePicker(frame, 130, L["Realm"], "all", function()
		local list = {}
		for _, realm in ipairs(realmsHeld(held())) do
			list[#list + 1] = { value = realm, label = realm }
		end
		return list
	end, changed)
	realmButton:SetPoint("LEFT", 0, 0)

	-- Named as the client names them and coloured as the game colours them: eleven class
	-- names in a list are read by colour long before they are read by name.
	local classButton = UI:CreateChoicePicker(frame, 120, L["Class"], "all", function()
		local names = _G.LOCALIZED_CLASS_NAMES_MALE
		local list = {}
		for _, classFile in ipairs(classesHeld(held())) do
			local red, green, blue = UI:ClassColour(classFile)
			list[#list + 1] = {
				value = classFile,
				label = (names and names[classFile]) or classFile,
				r = red, g = green, b = blue,
			}
		end
		return list
	end, changed)
	classButton:SetPoint("LEFT", realmButton, "RIGHT", 8, 0)

	-- Two numbers rather than a list of brackets. Brackets would have to be right on three
	-- clients whose ceilings are 60, 70 and 90, and a set built for one of them is wrong on
	-- the other two - so the player says the range and no client has to be guessed at.
	local levelLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	levelLabel:SetPoint("LEFT", classButton, "RIGHT", 12, 0)
	levelLabel:SetText(L["Level"])

	local function levelBox(anchor, gap)
		local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		box:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
		box:SetSize(34, 20)
		box:SetAutoFocus(false)
		box:SetNumeric(true)
		box:SetMaxLetters(3)
		box:SetJustifyH("CENTER")
		box:SetScript("OnTextChanged", changed)
		box:SetScript("OnEscapePressed", function(self)
			self:SetText("")
			self:ClearFocus()
		end)
		return box
	end

	local minBox = levelBox(levelLabel, 10)
	local dash = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	dash:SetPoint("LEFT", minBox, "RIGHT", 6, 0)
	dash:SetText("-")
	local maxBox = levelBox(dash, 10)

	filters.realmButton, filters.classButton = realmButton, classButton
	filters.minBox, filters.maxBox = minBox, maxBox

	-- How wide the row of them is, so a caller can put something after them.
	function filters:Width() return ROW_WIDTH end

	function filters:SetShown(shown) frame:SetShown(shown and true or false) end

	function filters:Reset()
		if realmButton.Choose then realmButton:Choose(UI.ANY) end
		if classButton.Choose then classButton:Choose(UI.ANY) end
		minBox:SetText("")
		maxBox:SetText("")
	end

	local function numberIn(box)
		local typed = tonumber(box:GetText())
		return typed and typed > 0 and typed or nil
	end

	-- Asked of the pickers rather than remembered from the click, because `Reconcile` also
	-- drops a choice the family no longer has: filter to the one warlock, delete that
	-- character, and a remembered value would leave the panel empty with the button still
	-- saying Warlock.
	function filters:Passes(meta)
		if type(meta) ~= "table" then return false end

		local realm = realmButton:Reconcile()
		local class = classButton:Reconcile()
		local low, high = numberIn(minBox), numberIn(maxBox)

		-- **Nothing is filtered out by something Family was never told.** A record with no
		-- realm, class or level recorded passes every one of these, because hiding it would
		-- claim Family knows it does not match (§2.2). It is a guard rather than a case -
		-- every writer of a member record writes all three - and it costs one `and` each.
		if realm and meta.realm and meta.realm ~= realm then return false end
		if class and meta.classFile and meta.classFile ~= class then return false end

		local level = meta.level
		if level then
			if low and level < low then return false end
			if high and level > high then return false end
		end

		return true
	end

	-- Whether any of them is actually narrowing anything, so a panel can say how much it is
	-- hiding only when there is something to say.
	function filters:Active()
		return (realmButton:Reconcile() or classButton:Reconcile()
			or numberIn(minBox) or numberIn(maxBox)) and true or false
	end

	return filters
end
