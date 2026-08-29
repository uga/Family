-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Choosing one of a short list of things.
--
-- The member picker next door answers "which member", which is a list of forty that wants
-- grouping and a search box. This answers "which realm" and "which class", which are lists of
-- five and eleven that want neither - and it is a separate control rather than a setting on
-- that one, because generalising a working control to cover a case it was not built for is how
-- both cases end up half served.
--
-- It replaced a button that stepped through the values on each click. Stepping is fine for two
-- or three and became unusable at eleven, and worse than unusable at the first realm called
-- "Pyrewood Village": the name was written straight through the side of the button, because a
-- button's own label has no width and will not clip itself.
--
-- So two things here are load-bearing rather than decorative. The list shows every option at
-- once, which is what makes a long one reachable. And the button's label is given an explicit
-- width and told not to wrap, which is what stops any of them ever writing through the side of
-- it again - the full text is on the hover, where a clipped one belongs.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 16
local LIST_WIDTH = 190
local PADDING = 10

-- Stands for "no filter at all". A sentinel rather than nil, because a choice has to be able
-- to sit in a list, and nil cannot.
local ANY = setmetatable({}, { __tostring = function() return "Family.ANY" end })
UI.ANY = ANY

--------------------------------------------------------------------------------------------
-- The list, of which there is one, reused by whichever picker opened it
--------------------------------------------------------------------------------------------

local popup, activePicker

local function buildPopup()
	if popup then return popup end

	popup = CreateFrame("Frame", "FamilyChoicePickerList", UIParent,
		"TooltipBorderedFrameTemplate")
	popup:SetSize(LIST_WIDTH, 40)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:EnableMouse(true)
	popup:Hide()

	UI:PaintOpaque(popup)

	popup.rows = {}

	popup:SetScript("OnHide", function() activePicker = nil end)

	-- After the SetScript above, never before it: hooking adds to what is there, and a
	-- SetScript afterwards throws away what is there, hook included.
	UI:DismissOnClickOutside(popup)

	function popup:Rebuild()
		local picker = activePicker
		if not picker then return end

		local choices = picker:Choices()
		local y = PADDING

		for index, choice in ipairs(choices) do
			local row = self.rows[index]
			if not row then
				row = CreateFrame("Button", nil, self)
				row:SetHeight(ROW)
				row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
				row.text:SetPoint("LEFT", 6, 0)
				row.text:SetWidth(LIST_WIDTH - 20)
				row.text:SetJustifyH("LEFT")
				UI:NoWrap(row.text)

				row.highlight = row:CreateTexture(nil, "BACKGROUND")
				row.highlight:SetAllPoints()
				row.highlight:SetColorTexture(1, 1, 1, 0.10)
				row.highlight:Hide()
				row:SetScript("OnEnter", function(self) self.highlight:Show() end)
				row:SetScript("OnLeave", function(self) self.highlight:Hide() end)

				self.rows[index] = row
			end

			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 4, -y)
			row:SetPoint("TOPRIGHT", -4, -y)

			-- The one you are on is marked rather than removed from the list. A list that
			-- drops the current entry changes length as you use it, and the row you wanted
			-- is then never where you last saw it.
			local current = choice.value == picker:Raw()
			local red, green, blue = choice.r or 1, choice.g or 1, choice.b or 1
			row.text:SetText(string.format("%s|cff%02x%02x%02x%s|r",
				current and "|cffffd700> |r" or "   ",
				red * 255, green * 255, blue * 255, choice.label))

			row:SetScript("OnClick", function()
				popup:Hide()
				picker:Choose(choice.value)
			end)
			row:Show()

			y = y + ROW
		end

		for index = #choices + 1, #self.rows do self.rows[index]:Hide() end

		self:SetHeight(y + PADDING)
	end

	return popup
end

-- Any list left hanging. Called when the window closes: the list is parented to the screen
-- rather than to the panel, so hiding the panel does not take it with it.
function UI:CloseChoicePickers()
	if popup then popup:Hide() end
end

--------------------------------------------------------------------------------------------
-- A picker
--
-- `provider` returns the concrete choices as { { value = , label = , r = , g = , b = } }.
-- Whatever "no filter" is called is this control's business, not the caller's, so the caller
-- never has to remember to put it in the list and can never leave it out.
--------------------------------------------------------------------------------------------

function UI:CreateChoicePicker(parent, width, prefix, anyLabel, provider, onChoose)
	local picker = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	picker:SetSize(width or 150, 22)

	picker.prefix = prefix
	picker.anyLabel = anyLabel or "all"
	picker.provider = provider
	picker.onChoose = onChoose
	picker.value = ANY

	-- The whole reason the old control could be overrun. A button's label is anchored to its
	-- centre and has no width of its own, so a long one simply draws past both ends of the
	-- button and over whatever is beside it.
	local label = picker.GetFontString and picker:GetFontString()
	if label then
		label:ClearAllPoints()
		label:SetPoint("LEFT", 6, 0)
		label:SetWidth((width or 150) - 12)
		label:SetJustifyH("LEFT")
		if label.SetWordWrap then label:SetWordWrap(false) end
	end

	-- The full text, for the ones the button had to cut short.
	UI:AttachTooltip(picker, function(self)
		return nil, nil, { { self.prefix, self:Label() } }
	end)

	function picker:Choices()
		local list = { { value = ANY, label = self.anyLabel, r = 0.7, g = 0.7, b = 0.7 } }
		for _, choice in ipairs(self.provider() or {}) do
			list[#list + 1] = choice
		end
		return list
	end

	-- Raw is the sentinel or the value; Value is what a caller wants, which is nil for "no
	-- filter". Two calls rather than one, because a caller writing `if picker:Value()` and a
	-- list needing something to compare against are different questions.
	function picker:Raw() return self.value end

	function picker:Value()
		if self.value == ANY then return nil end
		return self.value
	end

	function picker:Label()
		if self.value == ANY then return self.anyLabel end
		for _, choice in ipairs(self.provider() or {}) do
			if choice.value == self.value then return choice.label end
		end
		return tostring(self.value)
	end

	function picker:Redraw()
		self:SetText(string.format("%s: %s", self.prefix, self:Label()))
	end

	function picker:Choose(value)
		self.value = value
		self:Redraw()
		if self.onChoose then self.onChoose(self:Value()) end
	end

	-- Whatever was chosen, if it is still there to be chosen. A realm stops existing the
	-- moment its last member is removed, and a filter still pointing at it would show an
	-- empty panel that no longer says why.
	function picker:Reconcile()
		if self.value == ANY then
			self:Redraw()
			return nil
		end

		for _, choice in ipairs(self.provider() or {}) do
			if choice.value == self.value then
				self:Redraw()
				return self.value
			end
		end

		self.value = ANY
		self:Redraw()
		return nil
	end

	picker:SetScript("OnClick", function(self)
		local list = buildPopup()

		if list:IsShown() and activePicker == self then
			list:Hide()
			return
		end

		activePicker = self
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		list:Show()
		list:Rebuild()
	end)

	picker:Redraw()
	return picker
end
