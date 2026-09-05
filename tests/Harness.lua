-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Run with:  lua5.1 tests/Harness.lua .
--
-- A stub of just enough of the game to load Family outside it and drive it through a login,
-- a bag scan and a look at the summary. It is not a substitute for running in the client -
-- nothing here proves a frame is drawn where it should be, or that an API returns what this
-- file claims. It is a substitute for *guessing*, which is what the alternative is when the
-- game is on another machine.
--
-- It has already earned its place once: it caught the capability probe demoting dual spec on
-- Era, which is the one bug this project has already made in prose and would rather not make
-- again in code.
--
-- Extend it with each slice. A check here costs a minute and a wrong answer in the game
-- costs a relog.

local ROOT = arg[1] or "."

--------------------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------------------

local clock = 0
local frames = {}

local noop = function() end

-- Who is anchored to whom. Forward-declared because font strings need it as much as frames
-- do - a caption moved down to make room for a row is a font string - and their metatable is
-- written above the frames' method table.
local recordAnchor, forgetAnchors

local fontMeta = {}
fontMeta.__index = function(_, key)
	-- Font strings are anchored like anything else. Only the anchoring is kept: there is no
	-- geometry in here to compute a position from, and pretending otherwise is how a check
	-- comes to measure the stub instead of the panel.
	if key == "SetPoint" then
		return function(self, point, a, b, c, d) recordAnchor(self, point, a, b, c, d) end
	end
	if key == "ClearAllPoints" then
		return function(self) forgetAnchors(self) end
	end
	-- How wide somebody asked this to be, which matters because these are pooled: a font
	-- string given a narrow column by one row carries it to whatever the row is used for
	-- next unless somebody puts it back. Nought is the game's own word for "as wide as the
	-- text needs", so that is what a reset looks like.
	if key == "SetWidth" then return function(self, w) self.__width = w end end
	if key == "GetWidth" then return function(self) return self.__width or 100 end end
	-- Recorded rather than answered with a constant: a panel that measures a caption and
	-- reserves the room it needs is making a decision, and a stub that forgets the decision
	-- leaves nothing to check it by.
	if key == "SetHeight" then return function(self, h) self.__height = h end end
	if key == "GetHeight" then return function(self) return self.__height or 100 end end
	if key == "GetText" then return function(self) return self.__text end end
	if key == "SetText" then return function(self, t) self.__text = t end end

	-- The client measures a rendered string in pixels, and the panels now ask it to, so the
	-- stub has to answer something. Characters rather than bytes, colour codes not counted,
	-- at the same pixels-per-character the rest of this file uses. The number is not the
	-- client's - only the client knows that - but it is proportional to the text, which is
	-- what the layout logic under test actually depends on.
	-- How tall the string will be once it has wrapped inside the width it was given. The
	-- panels ask so they can reserve the room a caption actually needs, which is not the
	-- same in two languages.
	if key == "GetStringHeight" then
		return function(self)
			local text = tostring(self.__text or "")
			if text == "" then return 0 end
			local width = self.__width
			local lines = 1
			if width and width > 0 then
				local w = self.GetStringWidth and self:GetStringWidth() or 0
				lines = math.max(1, math.ceil(w / width))
			end
			return lines * 12
		end
	end

	if key == "GetStringWidth" then
		return function(self)
			local text = tostring(self.__text or "")
			text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			local n = 0
			for _ in text:gmatch("[^\128-\191]") do n = n + 1 end
			return n * 6.5
		end
	end
	-- Greying a texture is how the game says "you do not have this", and the talent grid
	-- says it that way too, so a check has to be able to see it.
	if key == "SetDesaturated" then
		return function(self, value) self.__desaturated = value and true or false end
	end
	-- Some font strings are shown and hidden in their own right rather than with a row -
	-- the labels on the talent grid are - so that has to be remembered too.
	if key == "Show" then return function(self) self.__visible = true end end
	if key == "Hide" then return function(self) self.__visible = false end end
	-- And the one call that does both. Frames have had this since the beginning; regions
	-- did not, so a texture shown or hidden by a condition was invisible to this file.
	if key == "SetShown" then
		return function(self, v) self.__visible = v and true or false end
	end
	-- And asked back. Show, Hide and SetShown were all recorded here and nothing could read
	-- the answer, so a caption hidden with the controls it describes and a caption left
	-- behind on the screen were the same answer to this file. Shown unless hidden, which is
	-- what a region that nobody has touched is.
	if key == "IsShown" then return function(self) return self.__visible ~= false end end
	-- Which picture a texture was given. It went to the same noop everything unrecognised
	-- did, so nothing here could see what anything was drawn as - and the possessions panel
	-- drew the keyring as a helm for weeks with this file perfectly content.
	if key == "SetTexture" then return function(self, path) self.__texture = path end end
	if key == "GetTexture" then return function(self) return self.__texture end end
	-- A field, not a call. Anything beginning with two underscores is this harness's own
	-- record of what happened, and answering a function for one is how a check comes to
	-- compare a string against something that is not one.
	if type(key) == "string" and key:sub(1, 2) == "__" then return nil end
	return noop
end

-- Kept in creation order, which is the order the panels build their rows in, so a check can
-- ask what a list actually reads like from top to bottom rather than only whether it drew.
local fontStrings = {}

local function newFontString()
	local fs = setmetatable({}, fontMeta)
	fontStrings[#fontStrings + 1] = fs
	return fs
end

-- Widget methods the real clients have. Anything called that is not in here is a mistake,
-- and the harness must say so rather than quietly returning a no-op - a stub that answers
-- every question is a stub that proves nothing. Add a name here only after checking it
-- exists on all three clients.
local KNOWN = {
	SetSize = 1, SetHeight = 1,
	SetMovable = 1, EnableMouse = 1, RegisterForDrag = 1,
	StartMoving = 1, StopMovingOrSizing = 1, SetClampedToScreen = 1,
	SetFrameStrata = 1, SetToplevel = 1, Raise = 1,
	Show = 1, Hide = 1, IsShown = 1, IsVisible = 1, SetShown = 1, SetAlpha = 1,
	SetOwner = 1, GetOwner = 1,
	GetNormalTexture = 1, SetTexCoord = 1,
	SetScript = 1, GetScript = 1,
	RegisterEvent = 1, UnregisterEvent = 1,
	CreateFontString = 1, CreateTexture = 1,
	GetWidth = 1, GetHeight = 1, GetName = 1,
	SetText = 1, GetText = 1, SetJustifyH = 1, SetTextColor = 1, SetFont = 1,
	GetStringWidth = 1, GetStringHeight = 1,
	SetColorTexture = 1, SetTexture = 1, SetVertexColor = 1,
	SetScrollChild = 1, GetScrollChild = 1, SetVerticalScroll = 1,
	GetVerticalScroll = 1, GetVerticalScrollRange = 1, EnableMouseWheel = 1,
	SetEnabled = 1, Enable = 1, Disable = 1, RegisterForClicks = 1,
	SetNormalTexture = 1, SetHighlightTexture = 1, SetPushedTexture = 1,
	SetAutoFocus = 1, HighlightText = 1, SetMaxLetters = 1,
	SetNumeric = 1,
	SetOwner = 1, GetSpell = 1,
	-- Secure buttons: the game casts what the attributes say when a player clicks them,
	-- which is the only way an addon may cast anything at all.
	SetAttribute = 1, GetAttribute = 1,
	LockHighlight = 1, UnlockHighlight = 1,
}

local frameMethods = {}
-- Unknown keys answer nil, which is what a real frame does for a field nobody set, and is
-- what code like `if frame.Refresh then` relies on. Calling one then fails with "attempt to
-- call a nil value", which is the mistake worth catching - so this stays strict about
-- methods without lying about fields.
local frameMeta = {
	__index = function(self, key)
		if frameMethods[key] then return frameMethods[key] end
		if KNOWN[key] then return noop end
		return nil
	end,
}

function frameMethods:RegisterEvent(event)
	assert(type(event) == "string", "RegisterEvent needs a string")
	-- Events the client does not have: the addon must survive these.
	if event == "NONEXISTENT_EVENT" then error("no such event") end
	self.__events[event] = true
end

function frameMethods:UnregisterEvent(event) self.__events[event] = nil end
function frameMethods:SetScript(name, fn) self.__scripts[name] = fn end
function frameMethods:GetScript(name) return self.__scripts[name] end
-- Showing and hiding run the frame's own OnShow and OnHide, as they do in the game, and only
-- when the answer actually changes. They used to set a field and nothing else, so anything
-- built on those two handlers was invisible to this file - and Family closes its lists and
-- puts its popups away from exactly there.
local function visibility(self, shown)
	if self.__shown == shown then return end
	self.__shown = shown
	local script = self.__scripts[shown and "OnShow" or "OnHide"]
	if script then script(self) end
end

function frameMethods:Show() visibility(self, true) end
function frameMethods:Hide() visibility(self, false) end
function frameMethods:IsShown() return self.__shown end
-- Shown *and* every ancestor shown, which is what the client means by it and what `IsShown`
-- deliberately does not answer. It was missing entirely, so a panel asking for it got the
-- unknown-method refusal - and the first thing to ask for it was the tooltip watcher, which
-- has to know whether the row the pointer was on is still on the screen.
function frameMethods:IsVisible() return onScreen(self) end
function frameMethods:SetShown(v) visibility(self, v and true or false) end
-- The parent is recorded so a check can ask whether a piece of text is actually on screen.
-- Rows are pooled and hidden rather than destroyed, so their last words stay in the harness
-- for ever, and a check that merely finds a string finds one that nobody can see.
function frameMethods:CreateFontString()
	local fs = newFontString()
	fs.__parent = self
	return fs
end
-- Textures are kept on the frame that made them, and remember the colour they were filled
-- with. A texture path cannot be checked here and is not checked anywhere - the client echoes
-- back whatever path it was handed - but "is there something opaque behind this list" is a
-- question about geometry and alpha, and it is one worth being able to ask: the member picker
-- shipped for months with the panel underneath reading straight through it.
function frameMethods:CreateTexture()
	local fs = newFontString()
	fs.__parent = self
	fs.SetColorTexture = function(texture, r, g, b, a)
		texture.__fill = { r = r, g = g, b = b, a = a }
	end
	fs.SetAllPoints = function(texture) texture.__allPoints = true end
	self.__textures = self.__textures or {}
	self.__textures[#self.__textures + 1] = fs
	return fs
end
-- Records what it is given, because the panels now size their own buttons and a stub that
-- answers a constant cannot be asked whether they did. Anything that never sets a width
-- still gets the old answer, which is what the scroll frames and lists rely on.
function frameMethods:SetWidth(w) self.__width = w end
-- The two of them at once, which is what most callers use and what nothing here recorded: a
-- frame sized this way answered the default width to every check that asked, so a container
-- given no size at all and one given a real one were the same answer.
function frameMethods:SetSize(w, h) self.__width, self.__height = w, h end
-- Recorded but not answered back: GetHeight stays the constant the scroll frames rely on.
-- What this is for is asking a list how tall it made itself, which is the only way to tell
-- from outside whether it left room between its sections or packed them flush.
function frameMethods:SetHeight(h) self.__height = h end
function frameMethods:GetWidth() return self.__width or 800 end
function frameMethods:GetHeight() return 500 end
-- Recorded rather than ignored, because whether a frame takes the mouse is the whole of
-- whether anything drawn on top of it can be clicked. See takesMouse below.
function frameMethods:EnableMouse(v) self.__mouse = v and true or false end
-- Recorded, because a star says which panel is home by how solid it is drawn and there is no
-- other way to ask.
function frameMethods:SetAlpha(v) self.__alpha = v end
function frameMethods:SetEnabled(v) self.__enabled = v end
function frameMethods:Enable() self.__enabled = true end
function frameMethods:Disable() self.__enabled = false end
function frameMethods:IsEnabled() return self.__enabled ~= false end

-- The selected button is held highlighted rather than disabled, so that is what a test has
-- to look at to know which one is current.
function frameMethods:LockHighlight() self.__highlighted = true end
function frameMethods:UnlockHighlight() self.__highlighted = false end
function frameMethods:GetFontString() return self.__fontString end

-- Recorded, because which frame a scroller scrolls is the whole of whether content past the
-- bottom of a panel can be reached at all - and there is no other way to ask from outside.
function frameMethods:SetScrollChild(child) self.__scrollChild = child end
function frameMethods:GetScrollChild() return self.__scrollChild end

-- Buttons remember their label, so a test can find one by what it says and click it. Without
-- this the only way to exercise a button is to reach inside the panel that made it.
function frameMethods:SetText(text) self.__text = text end
function frameMethods:GetText() return self.__text end

-- Hooks chain rather than replace, which is the point of them. Left as a no-op, every
-- tooltip hook the addon installs would simply never run and the test would prove nothing.
function frameMethods:HookScript(name, fn)
	local existing = self.__scripts[name]
	self.__scripts[name] = function(...)
		if existing then existing(...) end
		fn(...)
	end
end

-- Just enough tooltip to see what gets written on it.
-- The tooltip answers like the game's does: a setter that knows the thing writes a line, one
-- that does not writes nothing at all, and NumLines is how the addon finds out which
-- happened. A stub where every setter silently succeeds would have hidden the fact that
-- SetItemByID reports nothing whether it worked or not.
local TOOLTIP_KNOWS = { item = true, spell = true, quest = true, achievement = true }

function frameMethods:ClearLines()
	wipe(self.__lines)
	self.__shownAs = nil
end

function frameMethods:NumLines() return #self.__lines end

-- What a bag slot's tooltip says, by "bag:slot". The one thing in Family that reads a tooltip
-- is the charge count (Core.lua), and it reads the lines through the named globals the game
-- makes for a tooltip rather than off the frame - so the stub has to make those too, or the
-- reader is exercised against a shape the client never produces.
CHARGE_LINES = {}
CHARGE_ASKED = 0

function frameMethods:SetOwner() end

function frameMethods:SetBagItem(bag, slot)
	CHARGE_ASKED = CHARGE_ASKED + 1
	wipe(self.__lines)

	local lines = CHARGE_LINES[tostring(bag) .. ":" .. tostring(slot)] or {}
	for index = 1, 12 do
		local text = lines[index]
		if text then table.insert(self.__lines, { text }) end
		_G[(self.__name or "?") .. "TextLeft" .. index] =
			text and { GetText = function() return text end } or nil
	end
end

-- The player's auras, and what a tooltip pointed at one says.
--
-- A Chronoboon's contents are tooltip text and nothing else (DATASOURCES §2), and the shape
-- matters more than the content: the whole of it arrives in **one** tooltip line, as rows
-- separated by \r\n, each buff row carrying an icon escape and a colour code. A fake that
-- handed back one row per tooltip line would pass a reader that only ever read the first row -
-- which is exactly the reader that was written first, and exactly the misread behind L-034.
PLAYER_AURAS = {}
AURA_LINES = {}
AURA_ASKED = 0

function UnitBuff(unit, index)
	local aura = PLAYER_AURAS[index]
	if not aura then return nil end
	-- Ten returns, because the tenth is the spell id and that is the one Family reads.
	return aura.name, nil, aura.count, nil, nil, nil, nil, nil, nil, aura.spellID
end

function frameMethods:SetUnitBuff(unit, index)
	AURA_ASKED = AURA_ASKED + 1
	wipe(self.__lines)

	local lines = AURA_LINES[index] or {}
	for line = 1, 12 do
		local text = lines[line]
		if text then table.insert(self.__lines, { text }) end
		_G[(self.__name or "?") .. "TextLeft" .. line] =
			text and { GetText = function() return text end } or nil
	end
end

-- Which specialisation branches this character has taken, asked one spell at a time.
--
-- A branch is a passive spell and `IsSpellKnown` is the whole of the question. Set to nil in
-- one check below, because a client that cannot be asked has to record *nothing* rather than
-- "took no branch" - and those two are drawn differently.
KNOWN_SPELLS = {}

function IsSpellKnown(spellID) return KNOWN_SPELLS[spellID] == true end

ITEM_SPELL_CHARGES = "%d |4Charge:Charges;"

function frameMethods:SetItemByID(id)
	wipe(self.__lines)
	self.__shownAs = { kind = "item", id = id }
	table.insert(self.__lines, { "Item " .. tostring(id) })
end

function frameMethods:SetSpellByID(id)
	wipe(self.__lines)
	self.__shownAs = { kind = "spell", id = id }
	table.insert(self.__lines, { "Spell " .. tostring(id) })
end

-- What a tooltip is left as when the client will not describe what it was handed.
--
-- Measured 2026-09-05 on Era and TBC, because it had been guessed at once already and a guess
-- modelled here is a wrong claim about the client (L-037):
--
--     /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_CURSOR") t:ClearLines()
--         t:SetHyperlink("quest:999999:60")
--         print(t:NumLines(), t:IsShown(), t:GetOwner() ~= nil)
--
--     0  false  false
--
-- So it is not merely silent: it **hides the tooltip and drops the owner**. Anything written
-- afterwards goes nowhere, which is exactly what the quest rows did the day they started
-- asking - and this is what makes the fallback's own SetOwner checkable rather than a
-- precaution nobody can measure.
local function declined(tooltip)
	wipe(tooltip.__lines)
	tooltip.__shownAs = nil
	tooltip.__shown = false
	tooltip.__owner = nil
end

function frameMethods:SetHyperlink(link)
	local kind, id = tostring(link):match("^(%a+):(%d+)")

	-- A quest link needs its level as well as its id, and a bare "quest:84" describes
	-- nothing at all.
	--
	-- Measured on Era and TBC 2026-09-05, after the question "could the quest rows have
	-- tooltips" turned out to be "they were asking for one in a form the client ignores".
	-- `quest:84` answered nought lines; `quest:84:20` answered three and drew the quest.
	-- The stub said yes to both, which is why nothing here ever noticed - a fixture is a
	-- claim about what the client does, and this one was wrong (L-037).
	if kind == "quest" and not tostring(link):match("^quest:%d+:%d+") then
		return declined(self)
	end

	-- What was done to the item after it was bought. The stub used to stop at the id, so
	-- an item string and a bare id looked identical here - which is exactly the difference
	-- the gear tooltips turned out to be losing.
	local enchant = tonumber(tostring(link):match("^item:%d+:(%d+)"))
	if not TOOLTIP_KNOWS[kind] then
		-- A link type this client does not know says nothing, which is exactly the case
		-- the fallback lines exist for.
		return declined(self)
	end
	wipe(self.__lines)
	self.__shownAs = { kind = kind, id = tonumber(id), enchant = enchant }
	table.insert(self.__lines, { kind .. " " .. id })
	if kind == "talent" then
		table.insert(self.__lines, { "what the talent actually does" })
	end
end

-- Which way this pretend client will describe a talent in a tree, and only that way.
--
-- Real clients differ here and none of them will say so: a setter that is missing and a
-- setter that describes nothing both come back as silence. A stub that answered to every
-- shape would have gone on hiding the fact that the one Family used answers to none of them
-- on the client in front of the player, which is what it did.
local talentRoute
local function useTalentRoute(which)
	talentRoute = which
	TOOLTIP_KNOWS.talent = (which == "link") or nil
end

function frameMethods:SetTalent(...)
	local count = select("#", ...)
	local first, second, _, _, group = ...

	local wanted =
		(talentRoute == "tabindex" and count == 2 and first and second)
		or (talentRoute == "group" and first and second and group ~= nil)
		or (talentRoute == "id" and count == 1 and first)

	if not wanted then return end

	wipe(self.__lines)
	self.__shownAs = { kind = "talent", tab = first, index = second }
	table.insert(self.__lines, { "Talent " .. tostring(first) })
	table.insert(self.__lines, { "what the talent actually does" })
end

GetTalentLink = function(tab, index)
	if talentRoute ~= "link" then return nil end
	return "talent:" .. ((tonumber(tab) or 0) * 100 + (tonumber(index) or 0))
end

function frameMethods:GetName() return self.__name end

-- The game exposes each line as its own font string, named after the tooltip, and that is
-- the only way to read what is written on one. Family reads the skill a recipe needs from
-- there, because no call answers it.
local function publishLine(tooltip, text)
	if not tooltip.__name then return end
	local widget = _G[tooltip.__name .. "TextLeft" .. #tooltip.__lines]
	if not widget then
		widget = newFontString()
		_G[tooltip.__name .. "TextLeft" .. #tooltip.__lines] = widget
	end
	widget.__text = text
end

function frameMethods:AddLine(text)
	table.insert(self.__lines, { text })
	publishLine(self, text)
end
function frameMethods:AddDoubleLine(left, right)
	table.insert(self.__lines, { left, right })
	publishLine(self, left)
end
-- A real answer, not a silent nil. It was in the list of calls that do nothing, and a
-- secure child that asks its parent which recipe it is showing got nothing back - which
-- reads as a fault in the addon and was a fault in here.
function frameMethods:GetParent() return self.__parent end

-- Its pair. The stub had the reader and not the writer, so a frame moved from one parent to
-- another - which the client does allow - died here rather than being checked.
function frameMethods:SetParent(parent) self.__parent = parent end

-- Focus, modelled rather than shrugged off. A panel that redraws a box the player is halfway
-- through typing into takes the number out from under them, and a no-op HasFocus would have
-- said that never happens.
function frameMethods:SetOwner(owner) self.__owner = owner end
function frameMethods:GetOwner() return self.__owner end

-- One box at a time, which is what the client means by focus and what this did not model.
--
-- `SetFocus` set a flag and took it from nobody, so every box the cursor had ever been in
-- answered yes to `HasFocus` - and three mutations of the tab ring passed against that,
-- because a check asking whether the *right* box has focus is answered by any of them.
-- Kept on the method table rather than in a local of its own: this file is already near Lua's
-- limit of two hundred locals in one function, and one more turned the whole harness into a
-- compile error rather than a failing check.
function frameMethods:SetFocus()
	local held = frameMethods.__focused
	if held and held ~= self then held.__focus = false end
	frameMethods.__focused = self
	self.__focus = true
end
function frameMethods:ClearFocus()
	if frameMethods.__focused == self then frameMethods.__focused = nil end
	self.__focus = false
end
function frameMethods:HasFocus() return self.__focus == true end

-- Where the pointer is, which the client knows and this did not. A box gives the keyboard back
-- on a click that lands somewhere else, so "somewhere else" has to be sayable here or the rule
-- can only be checked in the direction that needs no pointer at all.
function frameMethods:IsMouseOver() return self.__mouseOver == true end

function frameMethods:GetItem() return self.__itemName, self.__itemLink end
-- What a tooltip says about the spell it is describing. The older clients answer here and the
-- newer ones hand the id to a post-call instead, and both routes have to be exercised: the
-- one that is only ever called by the harness is the one that can rot in the game unseen.
function frameMethods:GetSpell() return self.__spellName, self.__spellID end
function frameMethods:IsForbidden() return false end

-- Attributes are remembered, because whether a button is armed to cast is the whole of what
-- makes clicking a recipe able to open a profession.
function frameMethods:SetAttribute(name, value)
	self.__attributes = self.__attributes or {}
	self.__attributes[name] = value
end

function frameMethods:GetAttribute(name)
	return self.__attributes and self.__attributes[name]
end

InCombatLockdown = function() return false end

-- How deep a frame sits, which decides what a click lands on when two frames overlap. This
-- was a no-op for the life of the harness, so every check that clicked a button clicked it
-- through whatever was drawn on top of it. Modelled now, because "is this button reachable"
-- is a different question from "does this button have a handler" and only the second one was
-- ever being asked.
-- Which corners a frame is pinned by. Not a layout engine and not trying to be one - what
-- this answers is the one question that separates a row from the things drawn on it: a row is
-- pinned by both edges and spans the width, and a button or an icon on top of it is pinned by
-- one. That is enough to ask whether a click would reach something, and it needs no geometry.
-- Hooking a script runs the new handler after whatever was there, and a later SetScript
-- throws the lot away - which is the trap this models. It was a no-op, so a hook installed
-- before a SetScript looked exactly like one installed after it, and only one of those
-- survives in the game.
function frameMethods:HookScript(name, fn)
	local existing = self.__scripts[name]
	if not existing then
		self.__scripts[name] = fn
		return
	end
	self.__scripts[name] = function(...)
		existing(...)
		return fn(...)
	end
end

-- Records the offsets as well as the point. A panel that reserves room for a caption is
-- deciding a number, and a stub that keeps only "yes, something was anchored here" cannot be
-- asked what the number turned out to be.
-- Both ends of every anchor, so that the structure can be asked about.
--
-- There is no geometry in this harness and every frame answers that it is shown, so a row
-- that is switched on and then laid straight through whatever was already on that line is
-- invisible here. What is visible is the structure: a row that nothing below it is anchored
-- to is a row nobody made room for. That is the shape of the fault that shipped on the
-- possessions and professions panels, where the filter row was being shown all along and
-- shared its line with a caption running the full width of the panel.
function recordAnchor(self, point, a, b, c, d)
	if type(point) ~= "string" then return end
	self.__points = self.__points or {}
	self.__points[point] = true

	self.__offsets = self.__offsets or {}
	if type(a) == "number" then
		self.__offsets[point] = { x = a, y = b }
	elseif type(c) == "number" then
		self.__offsets[point] = { x = c, y = d }
	end

	if type(a) == "table" then
		a.__anchoredBy = a.__anchoredBy or {}
		a.__anchoredBy[self] = true
		self.__anchoredTo = self.__anchoredTo or {}
		self.__anchoredTo[a] = true
	end
end

-- And forgotten at both ends, or a row re-anchored somewhere else every draw would leave a
-- trail saying room was made for it in places it no longer is.
function forgetAnchors(self)
	self.__points = nil
	for target in pairs(self.__anchoredTo or {}) do
		if target.__anchoredBy then target.__anchoredBy[self] = nil end
	end
	self.__anchoredTo = nil
end

function frameMethods:SetPoint(point, a, b, c, d)
	recordAnchor(self, point, a, b, c, d)
end

function frameMethods:SetAllPoints()
	self.__points = { TOPLEFT = true, BOTTOMRIGHT = true }
end

function frameMethods:ClearAllPoints() forgetAnchors(self) end

function frameMethods:SetFrameLevel(level) self.__level = level end
function frameMethods:GetFrameLevel() return self.__level or 0 end

function frameMethods:SetChecked(v) self.__checked = v and true or false end
function frameMethods:GetChecked() return self.__checked end
function frameMethods:GetCenter() return 400, 300 end
function frameMethods:GetEffectiveScale() return 1 end

-- Where a frame is, which is how a click on a row works out which column it landed in. Rows
-- are laid out from the left edge of the list, so this is that edge.
function frameMethods:GetLeft() return 0 end

function CreateFrame(kind, name, parent, template)
	local f = setmetatable({
		__kind = kind, __name = name, __template = template, __parent = parent,
		-- Shown, as a frame in the game is: a new frame is visible unless it or something
		-- above it is hidden. Defaulting to hidden made this harness harsher than the
		-- client, which invents faults as readily as a lenient one hides them.
		__scripts = {}, __events = {}, __shown = true, __lines = {},
		__level = (parent and parent.__level or 0) + 1,
	}, frameMeta)

	-- BasicFrameTemplateWithInset gives a TitleText; the addon uses it.
	if template and template:find("BasicFrame") then
		f.TitleText = newFontString()
	end

	table.insert(frames, f)
	if name then _G[name] = f end
	return f
end

UIParent = CreateFrame("Frame", "UIParent")
UISpecialFrames = {}

GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")

Minimap = CreateFrame("Frame", "Minimap")
-- Somewhere up and to the right of the minimap's centre, so a drag lands on a known angle.
GetCursorPosition = function() return 500, 400 end

--------------------------------------------------------------------------------------------
-- The rest of the API surface Family touches
--------------------------------------------------------------------------------------------

DEFAULT_CHAT_FRAME = { messages = {} }
function DEFAULT_CHAT_FRAME:AddMessage(text) table.insert(self.messages, text) end

function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
time = function() return 1786000000 end

GetBuildInfo = function() return "1.15.9", "69109", "Aug 2026", 11507 end
UnitName = function() return "Tester" end
GetRealmName = function() return "Fire Maw" end
UnitLevel = function() return 60 end
UnitClass = function() return "Mage", "MAGE" end
-- Three returns, as the real one has them: the word, the language-neutral file string and
-- the id. The harness had only the first two, which is exactly the shape of record that made
-- races read in the wrong language, so the stub now answers the way the client does.
UnitRace = function() return "Gnome", "Gnome", 7 end
UnitSex = function() return 2 end

-- The client's own name for a race, which Family falls back to for the languages Races.lua
-- does not ship. Answering in a language that is nobody's real one keeps the two apart: if a
-- check expects this and gets "Gnome", the table answered when it should not have.
C_CreatureInfo = {
	GetRaceInfo = function(id)
		local names = { [7] = "Gnomo di prova", [5] = "Non-morto di prova" }
		if names[id] then return { raceID = id, raceName = names[id] } end
		return nil
	end,
}
UnitFactionGroup = function() return "Alliance" end
GetMoney = function() return 12345678 end

RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.8, b = 0.94 } }

-- The client's own wording for a whisper to somebody who is not logged in, which is the only
-- notice anybody gets that an exchange is going nowhere. Kept here exactly as the game has it,
-- placeholder and all: Family builds a pattern out of this global rather than out of the
-- English, and a harness that invented a friendlier sentence would be testing the invention.
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."

NUM_BAG_SLOTS = 4
KEYRING_CONTAINER = -2

-- Bag 0: backpack, 16 slots, 2 used.
-- Bag 1: 16-slot normal bag, 1 used.
-- Bag 2: 16-slot QUIVER (bagType nonzero) - must not count towards free space.
-- Bags 3,4: absent.
BAGS = {
	[0] = { size = 16, free = 14, bagType = 0,
	        items = { [1] = { 6948, 1 }, [2] = { 2589, 20 } } },
	-- 20747 is Lesser Mana Oil: in the generated charged-items table at 5, one item rather
	-- than a stack, and carried for the whole run so every panel and scanner meets one.
	[1] = { size = 16, free = 15, bagType = 0,
	        items = { [5] = { 4306, 12 }, [8] = { 20747, 1 } } },
	[2] = { size = 16, free = 16, bagType = 1, items = {} },
	-- The keyring, whose container number is negative. Everything about it is a special
	-- case and it was never in this list, so none of those cases was ever exercised.
	[-2] = { size = 8, free = 6, bagType = 0, items = { [1] = { 5178, 1 } } },
}

CHARGE_LINES["1:8"] = { "Lesser Mana Oil", "Requires Level 40", "5 Charges" }

C_Container = {
	GetContainerNumSlots = function(bag)
		return BAGS[bag] and BAGS[bag].size or 0
	end,
	GetContainerNumFreeSlots = function(bag)
		local b = BAGS[bag]
		if not b then return 0, 0 end
		return b.free, b.bagType
	end,
	GetContainerItemInfo = function(bag, slot)
		local b = BAGS[bag]
		local item = b and b.items[slot]
		if not item then return nil end
		return { itemID = item[1], stackCount = item[2] }
	end,
	ContainerIDToInventoryID = function(bag) return 19 + bag end,
}

GetInventoryItemID = function(_, slot) return 4000 + slot end

-- Held down or not, which a click handler asks about rather than being told. Set SHIFT_DOWN
-- to drive it.
SHIFT_DOWN = false
IsShiftKeyDown = function() return SHIFT_DOWN end

-- Identity. The character is below the cap so experience exists; the max-level case is
-- checked separately, because a capped character must read "max level" and not "0%".
UnitSex = function() return 2 end
GetMaxPlayerLevel = function() return 70 end
UnitXP = function() return 4000 end
UnitXPMax = function() return 10000 end
GetXPExhaustion = function() return 2500 end
GetBindLocation = function() return "Shattrath City" end
GetGuildInfo = function() return "Late Night Raiders", "Officer", 2 end
RequestTimePlayed = function() end

-- The guild roster, for Guild share (§7). Two of them run Family and one does not, because
-- the ordinary state of a guild is that most people do not and the panel has to draw that
-- case as its normal one rather than as an error.
-- In a block of its own, like the other late additions here: the main chunk is up against
-- Lua 5.1's limit of two hundred locals, and a block gives its own back on the way out.
do
local GUILD_ROSTER = {
	{ name = "Tester",  rank = "Officer", rankIndex = 1, level = 70, zone = "Shattrath",
	  online = true,  classFile = "MAGE" },
	{ name = "Faraway", rank = "Member",  rankIndex = 4, level = 70, zone = "Nagrand",
	  online = true,  classFile = "WARRIOR" },
	{ name = "Absent",  rank = "Member",  rankIndex = 4, level = 61, zone = "Hellfire",
	  online = false, classFile = "MAGE" },
}
GetNumGuildMembers = function() return #GUILD_ROSTER end
GetGuildRosterInfo = function(index)
	local entry = GUILD_ROSTER[index]
	if not entry then return nil end
	return entry.name, entry.rank, entry.rankIndex, entry.level, "Mage", entry.zone,
		nil, nil, entry.online, nil, entry.classFile
end
SetGuildRosterShowOffline = function() end
GuildRoster = function() end

-- The outgoing mail frame (§5). Read as the letter goes and cleared by the client the moment
-- the server confirms it, which is why Family reads it in the hook and not afterwards.
-- Reachable from the checks for the same reason the inbox is: a player can take some of a
-- letter's attachments and leave the rest, so a check has to be able to put a gappy one in
-- front of the scanner without changing what every other mail check is counting.
SEND_MAIL = { money = 12000, cod = 0, items = { { 2589, 20 }, { 4306, 5 } } }
ATTACHMENTS_MAX_SEND = 12
GetSendMailMoney = function() return SEND_MAIL.money end
GetSendMailCOD = function() return SEND_MAIL.cod end
GetSendMailItem = function(slot)
	local item = SEND_MAIL.items[slot]
	if not item then return nil end
	return "Thing", item[1], nil, item[2]
end
GetSendMailItemLink = function(slot)
	local item = SEND_MAIL.items[slot]
	return item and ("|Hitem:" .. item[1] .. "|h") or nil
end
SendMail = function() end

-- Hooking a global, the way the game does it: the original still runs, and the hook runs
-- after it with the same arguments. Family uses this for exactly one thing and guards its
-- existence, so a client without it loses the feature rather than the addon.
hooksecurefunc = function(name, hook)
	local original = _G[name]
	assert(type(original) == "function", "hooksecurefunc: no such function " .. tostring(name))
	_G[name] = function(...)
		local results = { original(...) }
		hook(...)
		return unpack(results)
	end
end

-- The class pictures live in one file with a set of coordinates per class, and a class with
-- no coordinates is drawn as a question mark rather than as a corner of somebody else's.
CLASS_ICON_TCOORDS = {
	MAGE = { 0.25, 0.49, 0, 0.25 },
	WARRIOR = { 0, 0.25, 0, 0.25 },
}
end
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", WARRIOR = "Warrior" }

--------------------------------------------------------------------------------------------
-- Equipment, reputations, the spellbook, achievements and auctions
--------------------------------------------------------------------------------------------

INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED = 1, 19
INVSLOT_BODY, INVSLOT_TABARD = 4, 19
-- A worn item's link, with the enchant and the gems where the game really puts them: an
-- item string is the id and then a row of numbers, and everything after the first is what
-- somebody did to the item after buying it. Slot 5 has an enchant and two gems on it.
GetInventoryItemLink = function(_, slot)
	if slot == 5 then
		return "|cffa335ee|Hitem:4005:2661:3000:3001:0:0:0:0:60|h[Chest]|h|r"
	end
	return "|cffffffff|Hitem:" .. (4000 + slot) .. ":0:0:0:0:0:0:0:60|h[Worn]|h|r"
end

-- Two factions under one header, which starts collapsed. A header itself is not a
-- reputation and must not be recorded as one.
local FACTIONS = {
	{ name = "Alliance", header = true, collapsed = true },
	{ name = "Stormwind", standing = 5, min = 0, max = 12000, value = 8000, hasRep = true,
	  id = 72 },
	{ name = "Ironforge", standing = 4, min = 0, max = 6000, value = 3000, hasRep = true,
	  id = 47 },
}
GetNumFactions = function() return #FACTIONS end
GetFactionInfo = function(index)
	local f = FACTIONS[index]
	if not f then return nil end
	return f.name, "", f.standing or 0, f.min or 0, f.max or 0, f.value or 0,
		false, false, f.header or false, f.collapsed or false, f.hasRep or false,
		false, false, f.id
end
ExpandFactionHeader = function(index)
	if FACTIONS[index] then FACTIONS[index].collapsed = false end
end
CollapseFactionHeader = function(index)
	if FACTIONS[index] then FACTIONS[index].collapsed = true end
end

-- Deliberately not in the order the spellbook hands the ids over. Mists lists the General
-- tab alphabetically and then adds the riding skills after it, so the panel showed a sorted
-- list with an unsorted one stuck to the bottom of it, under no heading of its own.
-- The client's own word for a spell, which is what a recipe's name comes from now: a recipe
-- is a spell and every reader asks their own client what it is called.
--
-- The two enchanting rows are deliberately answered in English while the recipes recorded
-- below them are in French. That is the fault as it was reported - a list read on one client
-- and shown on another - and it is the enchanting case specifically, where one recipe makes
-- an item and the other makes no item at all.
local SPELL_NAMES = {
	[501] = "Zul'Gurub Ritual", [502] = "Apprentice Riding",
	[2667] = "Runed Copper Breastplate", [3339] = "Silver Rod",
	[13640] = "Enchant Chest - Major Health", [25128] = "Wizard Oil",
	-- The four talents the arcane tree fixture puts on the grid, at the spell ids
	-- TalentSpells.lua maps their positions to. A talent is a spell, so this is the client
	-- answering about them the way it answers about any other.
	[11210] = "Arcane Subtlety", [11222] = "Arcane Focus",
	-- The Mists talent the choices fixture takes, by the spell its id maps to.
	[29838] = "Sacred Shield",
	[6057] = "Improved Arcane Missiles", [29441] = "Wand Specialization",
}
GetSpellInfo = function(id)
	-- Above nine hundred thousand the client says nothing, which is the state a recipe is
	-- in when its spell has not been loaded. Family has to fall back to the recorded word
	-- there, and something has to be able to put it in that state.
	if id >= 900000 then return nil end
	return SPELL_NAMES[id] or ("Spell " .. id), nil, "icon"
end
GetNumSpellTabs = function() return 2 end
GetSpellTabInfo = function(tab)
	if tab == 1 then return "General", "", 0, 2 end
	return "Frost", "", 2, 3
end
GetSpellBookItemInfo = function(position) return "SPELL", 500 + position end

--------------------------------------------------------------------------------------------
-- The quest log
--
-- Written as the game behaves rather than as the scanner would like: a collapsed heading
-- genuinely hides its quests from every call, so a scanner that forgets to expand sees a
-- shorter log and never knows it. That is the same trap the skill list sets, and this stub
-- exists to spring it.
--------------------------------------------------------------------------------------------

local QUEST_HEADERS = {
	{ title = "Elwynn Forest", collapsed = true, quests = {
		{ title = "Red Linen Goods", level = 14, id = 84, objectives = 2, done = 2 },
		{ title = "Wanted: Hogger", level = 11, id = 176, objectives = 1, done = 0 },
	} },
	{ title = "Westfall", collapsed = false, quests = {
		-- No objectives at all: a delivery. It must not be reported as nought of nought.
		{ title = "The Killing Fields", level = 18, id = 96, objectives = 0 },
	} },
}

local function questRows()
	local rows = {}
	for _, header in ipairs(QUEST_HEADERS) do
		rows[#rows + 1] = { header = header }
		if not header.collapsed then
			for _, quest in ipairs(header.quests) do rows[#rows + 1] = { quest = quest } end
		end
	end
	return rows
end

MAX_QUESTS = 25
GetNumQuestLogEntries = function() return #questRows(), 3 end

-- The Era shape: title, level, suggestedGroup, isHeader, isCollapsed, isComplete,
-- frequency, questID.
GetQuestLogTitle = function(index)
	local row = questRows()[index]
	if not row then return nil end
	if row.header then
		return row.header.title, 0, nil, true, row.header.collapsed
	end
	local quest = row.quest
	-- The shape this client really answers with, measured on TBC 2026-09-05:
	--
	--     No Time for Curiosity  65  nil  false  false  1  1  9794  false ...
	--
	-- The two ones before the id matter. With noughts there instead, "take the first number
	-- after the level" is indistinguishable from "ask which number is the id" - and the
	-- mutation that skips the asking passed against the old fixture.
	return quest.title, quest.level, nil, false, false, 1, 1, quest.id
end

-- **By quest id, not by log index**, which is what the client actually takes.
--
-- This took an index, and that was a wrong claim about the client: passing one an index
-- answers nothing, and passing it a number that happens to be a valid id answers about
-- somebody else's quest. The game says so outright - *Usage: GetQuestLink(questID)* - and
-- until 2026-09-05 the scanner's second route asked with an index and this stub agreed with
-- it, so every quest in the game had no id and every quest here had one (L-037).
--
-- Which also makes it the way to *find* the id: hand it a candidate and read the title back.
GetQuestLink = function(questID)
	for _, row in ipairs(questRows()) do
		if row.quest and row.quest.id == questID then
			return string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", row.quest.id,
				row.quest.level, row.quest.title)
		end
	end
	return nil
end

GetNumQuestLeaderBoards = function(index)
	local row = questRows()[index]
	return (row and row.quest and row.quest.objectives) or 0
end

-- Each objective says something of its own, the way a real leaderboard line does - *Gem of
-- Smolderthorn: 1/1* - because a stub that answers one shared string for all of them cannot
-- tell a check that reads the objectives apart from one that merely counts them, and it is
-- the reading that Family had never done.
GetQuestLogLeaderBoard = function(objective, index)
	local row = questRows()[index]
	if not (row and row.quest) then return nil end
	local done = objective <= (row.quest.done or 0)
	return string.format("%s %d: %d/1", row.quest.title, objective, done and 1 or 0),
		"monster", done
end

ExpandQuestHeader = function(index)
	if index == 0 then
		for _, header in ipairs(QUEST_HEADERS) do header.collapsed = false end
	end
end

CollapseQuestHeader = function(index)
	local row = questRows()[index]
	if row and row.header then row.header.collapsed = true end
end

-- Confirmation popups. The stub accepts immediately, so a check can right-click a row and
-- look at what happened; what it must not do is pretend the popup was never asked for.
StaticPopupDialogs = {}
StaticPopup_Show = function(which)
	local dialog = StaticPopupDialogs[which]
	if dialog and dialog.OnAccept then dialog.OnAccept() end
	return dialog
end

-- Achievements, with the three cases that matter: finished, started, and not begun. The last
-- one is the reason the whole catalogue is not stored - there are thousands of it, and being
-- at nought of ten is the same fact as not having the achievement at all.
local ACHIEVEMENTS = {
	[9201] = { name = "Bandage Master", points = 10, completed = true,
	           description = "Bandage a great many people." },
	[9202] = { name = "Cooking Fiend", points = 20, criteria = 5, done = 2,
	           description = "Cook five different things." },
	[9203] = { name = "Untouched", points = 10, criteria = 3, done = 0,
	           description = "Something nobody has started." },
	[9601] = { name = "Well Read", points = 25, completed = true,
	           description = "Read everything." },
	[9602] = { name = "Half Read", points = 5, criteria = 4, done = 1,
	           description = "Read half of everything." },
}

local ACHIEVEMENT_CATEGORIES = {
	[92] = { title = "Quests", ids = { 9201, 9202, 9203 } },
	[96] = { title = "Exploration", ids = { 9601, 9602 } },
}

-- Kept, because a later check replaces this with a symbol that answers nothing - the trap
-- these clients set - and the Mists section needs the real one back afterwards.
local realAchievementInfo

GetTotalAchievementPoints = function() return 1450 end
GetCategoryList = function() return { 92, 96 } end
GetCategoryInfo = function(category)
	local entry = ACHIEVEMENT_CATEGORIES[category]
	return entry and entry.title
end
GetCategoryNumAchievements = function(category)
	local entry = ACHIEVEMENT_CATEGORIES[category]
	return entry and #entry.ids or 0
end

-- Asked either way: by category and index while walking the list, and by id afterwards to
-- find out what one is called. Both forms are real, and Family uses both.
realAchievementInfo = function(first, index)
	local id = first
	if index then
		local entry = ACHIEVEMENT_CATEGORIES[first]
		id = entry and entry.ids[index]
	end

	local achievement = id and ACHIEVEMENTS[id]
	if not achievement then return nil end

	return id, achievement.name, achievement.points, achievement.completed or false,
		nil, nil, nil, achievement.description
end

GetAchievementInfo = realAchievementInfo

GetAchievementNumCriteria = function(id)
	local achievement = ACHIEVEMENTS[id]
	return achievement and achievement.criteria or 0
end

GetAchievementCriteriaInfo = function(id, index)
	local achievement = ACHIEVEMENTS[id]
	if not achievement then return nil end
	return "a criterion", 1, index <= (achievement.done or 0)
end

local OWNED = {
	{ "Copper Bar", 20, 100, 500, 0, false, 3 },
	{ "Silver Rod", 1, 5000, 9000, 5000, true, 4 },
}
GetNumAuctionItems = function(which) return which == "owner" and #OWNED or 0 end
GetAuctionItemInfo = function(which, index)
	if which == "list" then
		local row = BROWSE[index]
		if not row then return nil end
		-- Name, texture, count: the stack size is the third return, which is what the
		-- bid watcher reads.
		return "Linen Cloth", nil, row.count
	end
	local a = OWNED[index]
	if not a or which ~= "owner" then return nil end
	return a[1], nil, a[2], nil, nil, nil, nil, a[3], nil, a[4], a[5], a[6],
		nil, nil, nil, nil, 2840 + index
end
GetAuctionItemTimeLeft = function(_, index) return OWNED[index] and OWNED[index][7] or 0 end
GetOwnerAuctionItems = function() end

-- The browse list, which is what somebody buys out of, and the bid that does it.
--
-- The two system messages a bid can be answered with, as the client's own globals. Both carry
-- %s, and only one of them means an item is on its way - which is exactly what the pattern
-- built from the first has to be able to tell.
BROWSE = { { link = "|Hitem:2589|h[Linen Cloth]|h", count = 4 } }
ERR_AUCTION_WON_S = "You won an auction for %s"
ERR_AUCTION_BID_PLACED = "Bid accepted."
ERR_AUCTION_OUTBID_S = "You were outbid on %s."

-- Answers for every list, as the client does. It returned nil for anything but the browse
-- list at first, which made the fake enforce the scanner's own guard instead of testing it:
-- the mutation removing that guard passed. The client hands back a link for your own auctions
-- and your bids too, and only the scanner decides which of those is a purchase.
GetAuctionItemLink = function(which, index)
	if which == "list" then return BROWSE[index] and BROWSE[index].link or nil end
	return OWNED[index] and "|Hitem:2840|h[Something of yours]|h" or nil
end

PlaceAuctionBid = function() end

-- The mailbox. One letter is about to expire and one is not, because the only number on the
-- summary worth reacting to is how long until something is destroyed.
-- How many slots a letter has room for. The client's own constant, and the reason it is
-- modelled: attachments do **not** sit in the first `itemCount` slots. They have gaps, and a
-- letter of ten can put four of them past the tenth slot - which is how four stacks of linen
-- and two of wool went unrecorded while the record looked complete (L-044).
ATTACHMENTS_MAX_RECEIVE = 16

-- Reachable from the checks, so that one of them can put a letter with gaps in it into the
-- inbox for as long as it needs one and take it out again. Adding it here instead would change
-- what every other mail check is counting.
INBOX = {
	{ sender = "Deiana", subject = "Cloth", money = 0, cod = 0, days = 0.5,
	  items = { { 2589, 20 } } },
	{ sender = "Auction House", subject = "Sold", money = 50000, cod = 0, days = 25,
	  items = {} },
}
GetInboxNumItems = function() return #INBOX end
GetInboxHeaderInfo = function(index)
	local m = INBOX[index]
	if not m then return nil end
	-- The count the client reports, which is how many there are and not where they are.
	local held = m.count
	if not held then
		held = 0
		for _ in pairs(m.items) do held = held + 1 end
	end
	return nil, nil, m.sender, m.subject, m.money, m.cod, m.days, held, true
end
GetInboxItem = function(index, attachment)
	local item = INBOX[index] and INBOX[index].items[attachment]
	if not item then return nil end
	return "Thing", item[1], nil, item[2]
end
GetInboxItemLink = function(index, attachment)
	local item = INBOX[index] and INBOX[index].items[attachment]
	return item and ("|Hitem:" .. item[1] .. "|h") or nil
end

-- Enchanting is behind the Craft frame, not the trade skill one. Most of its recipes create
-- no item at all - an enchant is a spell applied to something - and a few make oils and rods.
-- Both shapes are here, because a reader that assumes an item exists loses most of the list.
--
-- The two rows also answer differently, which is not tidiness but measurement. On Classic Era
-- GetCraftRecipeLink is nil for every row and GetCraftItemLink returns an *enchant* link even
-- for a recipe that makes an item, so the first row is written the way a live client answered.
-- The second keeps the shape this was first written from, so that both are read.
local CRAFTS = {
	{ "Header", "header" },
	{ "Ench. de plastron (Vie majeure)", "optimal", 0, nil, "|Henchant:13640|h" },
	{ "Huile de sorcier", "easy", 2, "|Henchant:25128|h", "|Hitem:20749|h" },
}
GetCraftName = function() return "Enchantement" end

-- The Craft frame collapses the same way and hides the same way.
CRAFT_COLLAPSED = false

local function visibleCrafts()
	local rows = { CRAFTS[1] }
	if not CRAFT_COLLAPSED then
		for index = 2, #CRAFTS do rows[#rows + 1] = CRAFTS[index] end
	end
	return rows
end

GetNumCrafts = function() return #visibleCrafts() end
GetCraftInfo = function(index)
	local c = visibleCrafts()[index]
	if not c then return nil end
	if c[2] == "header" then return c[1], nil, "header", 0, not CRAFT_COLLAPSED end
	return c[1], nil, c[2], c[3]
end
ExpandCraftSkillLine = function() CRAFT_COLLAPSED = false end
CollapseCraftSkillLine = function() CRAFT_COLLAPSED = true end
GetCraftCooldown = function(index)
	-- One thing on a real cooldown, so the "not ready yet" case exists at all.
	return index == 2 and 3600 or nil
end
GetCraftIcon = function(index)
	return visibleCrafts()[index] and ("Interface\\Icons\\Craft_" .. index)
end
GetCraftRecipeLink = function(index)
	local c = visibleCrafts()[index]
	return c and c[4]
end
GetCraftItemLink = function(index)
	local c = visibleCrafts()[index]
	return c and c[5]
end
GetSpellSubtext = function() return "Rang 3" end
GetItemIcon = function(id) return "Interface\\Icons\\Item_" .. id end

-- A click, delivered the way the game delivers one: PreClick, then whatever the button's own
-- template does with its attributes, then OnClick, then PostClick.
--
-- All four, not just OnClick. A secure action button's casting *is* its OnClick script, which
-- is why an addon's own work on one has to go in PostClick - and a harness that fired only
-- OnClick could not tell a button that casts from one that does not. It could not, and did
-- not: recipe rows were plain frames wearing attributes nothing would ever read, and the
-- profession buttons had had the casting script overwritten. Both passed every check here.
local cast = {}

local function isSecure(f)
	return type(f.__template) == "string"
		and f.__template:find("SecureActionButtonTemplate", 1, true) ~= nil
end

local function fireClick(f, button)
	if f.__scripts.PreClick then f.__scripts.PreClick(f, button) end

	-- Only a secure button does anything with the attributes. A plain one holds them and
	-- ignores them, which is exactly what made arming recipe rows look as though it worked.
	local attributes = f.__attributes
	if isSecure(f) and attributes and attributes.type == "spell" and attributes.spell then
		cast[#cast + 1] = attributes.spell
	end

	if f.__scripts.OnClick then f.__scripts.OnClick(f, button) end
	if f.__scripts.PostClick then f.__scripts.PostClick(f, button) end
end

local function clickable(f)
	return f.__scripts.OnClick ~= nil or f.__scripts.PostClick ~= nil
end

-- Whether a click on this button would actually reach it.
--
-- Being shown and having a handler is not the same as being reachable, which is the whole of
-- what went wrong on the Wide Family panel: Accept, Decline, Ask again and Forget drew
-- perfectly and did nothing, because the full-width row they sit on top of was covering them
-- and taking the click. Every check in this file clicked buttons by calling their handler, so
-- all of them passed while none of the buttons worked.
--
-- Geometry is not modelled here, so this asks the structural question instead, which is the
-- one that has an answer: a panel's rows span the whole width of their list, so anything else
-- in that list is drawn over a row and has to sit in front of it. A sibling row at the same
-- level or higher would win the click. That is the only tie the game breaks by creation
-- order, and creation order here is whatever order two frame pools happened to grow in.
--
-- A row is pinned by both edges; the buttons, tick boxes and icons laid on one are pinned by
-- a single corner. That is what tells them apart, and it names no panel and no template.
--
-- The first version of this asked whether a widget was built from a template, on the grounds
-- that rows are built by hand and the things on them are not. True of the Wide Family panel
-- and of nowhere else: the icon cells on the guild, character and talent panels are built by
-- hand too, so the one rule that was meant to be checked everywhere was in fact checked in the
-- one place the fault had already been found.
--
-- Global rather than local, and the reason is Lua 5.1 rather than taste: the main chunk is at
-- its limit of two hundred locals and these are wanted several thousand lines down, so a do
-- block cannot hold them.
function spansWidth(f)
	local points = f.__points
	if not points then return false end
	local left = points.TOPLEFT or points.BOTTOMLEFT or points.LEFT
	local right = points.TOPRIGHT or points.BOTTOMRIGHT or points.RIGHT
	return (left and right) and true or false
end

-- Whether the game would hand this frame the mouse at all.
--
-- **Not "does it have an OnClick".** A frame takes the mouse because its mouse is enabled,
-- and a Button created with CreateFrame has it enabled from birth - so a row with nothing
-- hooked to its click, carrying only a hover highlight, still swallows every click aimed at
-- something drawn on it. Asking about OnClick was the whole of this test until a grid of tick
-- boxes was drawn on exactly such rows, passed here, and could not be clicked in the game.
-- What the player saw was the row's highlight coming up under a box that would not answer.
function takesMouse(f)
	if f.__mouse == false then return false end

	local scripts = f.__scripts or {}
	return (scripts.OnClick or scripts.PostClick or scripts.OnEnter or scripts.OnLeave
		or scripts.OnMouseDown or scripts.OnMouseUp) ~= nil
end

function coveredBy(f)
	-- A row is not drawn on anything. Two rows never overlap: they are laid out one under
	-- the next by the same counter.
	if spansWidth(f) then return nil end

	for _, other in ipairs(frames) do
		if other ~= f and other.__parent == f.__parent and other.__shown == true
			and takesMouse(other) and spansWidth(other)
			and other:GetFrameLevel() >= f:GetFrameLevel() then
			return other
		end
	end

	return nil
end

function reachable(f)
	return f.__shown == true and clickable(f) and coveredBy(f) == nil
end

-- Whether every frame between this one and the screen is shown.
--
-- A control on a panel that is not open still carries its own `__shown`, because hiding a
-- panel does not walk into its children. So asking the widget alone finds whichever panel
-- happened to build one of these first - which is exactly how a check written for the
-- character panel's class filter came to be driving the summary's copy of the same control,
-- the day the summary grew one. It went on passing, because it then read the button it had
-- just moved, and the panel it was written about stopped being tested at all.
--
-- Global for the same reason as the two above: the main chunk is at its limit of two hundred
-- locals and this is wanted several thousand lines further down.
function onScreen(f)
	local at = f
	while type(at) == "table" do
		if at.__shown == false then return false end
		at = type(at.__parent) == "table" and at.__parent or nil
	end
	return true
end

-- The shown button whose label contains this text, whether or not a click would reach it -
-- so a check can ask the two questions separately.
function findButton(label)
	for _, f in ipairs(frames) do
		-- Either where a template put the label or where the panel put it by hand. A
		-- button built without a template has no font string of its own, so the panels
		-- that build their own give it one and hang it on .text - and a search that knew
		-- only about the first kind could not see them.
		local text = type(f.__text) == "string" and f.__text
			or (type(f.text) == "table" and type(f.text.__text) == "string"
				and f.text.__text or nil)

		if text and text:find(label, 1, true) and f.__shown == true and clickable(f) then
			return f
		end
	end
end

-- Clicks the button whose label contains this text, wherever it lives. Matched loosely
-- because a label is often wrapped in colour codes - "Tester" arrives as "|cff...Tester|r".
local function clickButton(label)
	for _, f in ipairs(frames) do
		if type(f.__text) == "string" and f.__text:find(label, 1, true) and clickable(f) then
			fireClick(f)
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------------------
-- Skills, professions and the bank
--------------------------------------------------------------------------------------------

-- Weapon skills have a maximum too, so they are here to prove they are not mistaken for
-- professions. The Trade Skills header starts collapsed, hiding everything under it, which
-- is the case that makes a naive scan report no professions at all.
-- Reachable from the checks, so that one of them can put a class skill in the list without
-- changing what every other profession check is counting.
SKILL_LINES = {
	{ name = "Weapon Skills", header = true, expanded = true },
	-- Caps at exactly the same 300 an artisan profession does, so only the fact that it
	-- cannot be unlearned tells the two apart.
	{ name = "Swords", rank = 300, maxRank = 300, abandonable = false },
	{ name = "Trade Skills", header = true, expanded = false },
	{ name = "Blacksmithing", rank = 287, maxRank = 375, abandonable = true },
	-- Neither of these can be unlearned, any more than swords can. Being unlearnable is
	-- what identifies a primary profession, so on this test alone both are lost - which is
	-- exactly what happened in the game, and left every secondary invisible for ever.
	{ name = "Cooking", rank = 300, maxRank = 300, abandonable = false },
	{ name = "First Aid", rank = 225, maxRank = 300, abandonable = false },
	-- A gathering profession: a real skill with a real rank and no window anywhere, so no
	-- recipe list will ever exist for it however many times it is scanned.
	{ name = "Herbalism", rank = 150, maxRank = 300, abandonable = true },
	{ name = "Languages", header = true, expanded = true },
	{ name = "Common", rank = 1, maxRank = 1, abandonable = false },
}

local function visibleSkills()
	local shown, hiding = {}, false
	for _, line in ipairs(SKILL_LINES) do
		if line.header then
			hiding = not line.expanded
			shown[#shown + 1] = line
		elseif not hiding then
			shown[#shown + 1] = line
		end
	end
	return shown
end

GetNumSkillLines = function() return #visibleSkills() end
GetSkillLineInfo = function(index)
	local line = visibleSkills()[index]
	if not line then return nil end
	return line.name, line.header or false, line.expanded or false,
		line.rank or 0, 0, 0, line.maxRank or 0, line.abandonable or false
end
ExpandSkillHeader = function()
	for _, line in ipairs(SKILL_LINES) do
		if line.header then line.expanded = true end
	end
end
CollapseSkillHeader = function(index)
	local line = visibleSkills()[index]
	if line and line.header then line.expanded = false end
end

PROFESSIONS_COOKING = "Cooking"
PROFESSIONS_FIRST_AID = "First Aid"
PROFESSIONS_FISHING = "Fishing"

TRADE_RECIPES = {
	{ "Header", "header" },
	{ "Runed Copper Breastplate", "trivial", 0, "|cffffd000|Henchant:2667|h[Runed Copper Breastplate]|h|r",
	  "|cffffffff|Hitem:2864|h[Runed Copper Breastplate]|h|r" },
	-- Not an enchant link. A live Era client does not hand these back the way the other
	-- rows here say it does, and reading only one kind is what left a hundred and fifty
	-- recipes with no id to be named by.
	{ "Silver Rod", "optimal", 2, "|cffffd000|Hspell:3339|h[Silver Rod]|h|r",
	  "|cffffffff|Hitem:6338|h[Silver Rod]|h|r" },
}

-- The trade skill window is only "open" while a test says it is. In the game the call
-- answers UNKNOWN when it is shut, which is what lets the Craft frame be tried next -
-- without that, the trade skill path always wins and enchanting is never reached.
TRADE_SKILL_OPEN = true
-- Which profession's window is open. A variable rather than a constant because what a recipe
-- makes does not say who made it: a Gold Bar is smelted by a miner for nothing and transmuted
-- by an alchemist on a day's wait, so the same row means different things under two windows.
TRADE_SKILL_NAME = "Blacksmithing"
GetTradeSkillLine = function()
	return TRADE_SKILL_OPEN and TRADE_SKILL_NAME or "UNKNOWN"
end
-- The window lists what it *shows*, exactly as the skill list above does: a collapsed
-- sub-class header hides every row under it and the count is of rows on screen. Modelled
-- rather than assumed away, because reading a collapsed window is the fault this fixture
-- exists to reproduce - the recipes are still known, and the client will not name one of them.
TRADE_COLLAPSED = false

local function visibleTradeRows()
	local rows = { TRADE_RECIPES[1] }
	if not TRADE_COLLAPSED then
		for index = 2, #TRADE_RECIPES do rows[#rows + 1] = TRADE_RECIPES[index] end
	end
	return rows
end

GetNumTradeSkills = function() return #visibleTradeRows() end
GetTradeSkillInfo = function(index)
	local r = visibleTradeRows()[index]
	if not r then return nil end
	if r[2] == "header" then return r[1], "header", 0, not TRADE_COLLAPSED end
	return r[1], r[2], r[3]
end
ExpandTradeSkillSubClass = function() TRADE_COLLAPSED = false end
CollapseTradeSkillSubClass = function() TRADE_COLLAPSED = true end
-- The client's own icon for each row, which is the only thing that is right for every kind
-- of recipe: the crafting spell of a bandage is not drawn as a bandage.
GetTradeSkillIcon = function(index)
	return visibleTradeRows()[index] and ("Interface\\Icons\\Recipe_" .. index)
end
GetTradeSkillRecipeLink = function(index)
	local r = visibleTradeRows()[index]
	return r and r[4]
end
GetTradeSkillItemLink = function(index)
	local r = visibleTradeRows()[index]
	return r and r[5]
end
-- The seconds left on a row's cooldown, or nothing at all - which is what the client answers
-- for a recipe that has none *and* for one that is ready, the ambiguity the generated tables
-- exist to resolve. Taken from the row so that a test can put a recipe on cooldown and then
-- take it off again, which is the only way to earn the "Family watched this" mark honestly.
GetTradeSkillCooldown = function(index)
	local r = visibleTradeRows()[index]
	return r and r[6] or nil
end

-- The bank: container -1, plus one bought bank bag at 6. Bag 5 is deliberately absent.
-- The bank's own window answers 20 free while holding one thing in twenty-four slots, which
-- is what a live Classic Era client does: it computes that count from twenty-eight and the
-- bank is twenty-four, so it is four out whatever is in it. Family does not ask - it reads
-- every slot anyway, so free is the size less what was found - and this fixture is the client
-- being wrong about it.
BANK_BAGS = {
	[-1] = { size = 24, free = 20, bagType = 0, items = { [1] = { 7909, 3 } } },
	[6]  = { size = 16, free = 16, bagType = 0, items = {} },
}
BANK_CONTAINER = -1
NUM_BANKBAGSLOTS = 7
IsInGuild = function() return false end

local baseNumSlots = C_Container.GetContainerNumSlots
local baseFreeSlots = C_Container.GetContainerNumFreeSlots
local baseItemInfo = C_Container.GetContainerItemInfo

C_Container.GetContainerNumSlots = function(bag)
	if BANK_BAGS[bag] then return BANK_BAGS[bag].size end
	return baseNumSlots(bag)
end
C_Container.GetContainerNumFreeSlots = function(bag)
	local b = BANK_BAGS[bag]
	if b then return b.free, b.bagType end
	return baseFreeSlots(bag)
end
-- A thing in a bag with a long cooldown of its own: a salt shaker, an alchemy stone. Short
-- ones are every potion in the bags after every fight and are deliberately not recorded.
-- The game's fractional clock, and it has to move when advance() does. Frozen, anything that
-- waits a moment before doing something waits for ever - which is not a stub being unhelpful,
-- it is a stub answering a question wrongly.
FAKE_CLOCK = 1000
GetTime = function() return FAKE_CLOCK end
-- One thing on a real daily cooldown, and one hearthstone. The hearthstone is the case that
-- proved the floor was wrong: half an hour is a cooldown, and being told at login that a
-- character's hearthstone is ready is not information anybody wanted.
-- And the shape a client answers with at login, before it has settled its cooldown clock: a
-- start far in the *future*, which makes the arithmetic produce a wait longer than the
-- cooldown itself. Switched on by a test rather than always, because it is a state the client
-- passes through rather than one it stays in.
COOLDOWN_UNSETTLED = false
C_Container.GetContainerItemCooldown = function(bag, slot)
	if bag == 0 and slot == 1 then
		if COOLDOWN_UNSETTLED then return FAKE_CLOCK + 4000000, 86400, 1 end
		return 900, 86400, 1
	end
	if bag == 0 and slot == 2 then return 900, 1800, 1 end
	return 0, 0, 0
end
GetContainerItemCooldown = C_Container.GetContainerItemCooldown

C_Container.GetContainerItemInfo = function(bag, slot)
	local b = BANK_BAGS[bag]
	if b then
		local item = b.items[slot]
		if not item then return nil end
		return { itemID = item[1], stackCount = item[2] }
	end
	return baseItemInfo(bag, slot)
end

local ITEM_NAMES = { [6948] = "Hearthstone", [2589] = "Linen Cloth",
	-- Charged, and the client knows it - which is the ordinary case once an item
	-- has been seen. The case where it does not yet is held further down.
	[20747] = "Lesser Mana Oil" }

-- Recipe items, and one deliberate impostor. Arcane dust is trade goods with a subclass
-- named after a profession, which is exactly why a subtype matching a profession cannot on
-- its own be taken for a recipe.
local RECIPE_ITEMS = {
	[2881] = { name = "Plans: Runed Copper Breastplate", profession = "Blacksmithing",
	           class = 9, minLevel = 10 },
	[3608] = { name = "Plans: Silver Rod", profession = "Blacksmithing",
	           class = 9, minLevel = 20 },
	[22445] = { name = "Arcane Dust", profession = "Enchantement", class = 7 },
	-- Named in this client's language for a recipe recorded in another one. The crafters
	-- block matches an item's name against the recipes members hold, and while both sides
	-- were words that comparison was between two different languages.
	[20750] = { name = "Formula: Wizard Oil", profession = "Enchantement",
	            class = 9, minLevel = 20 },
}

-- A link answers with an item level; a bare id answers only if the client knows the item,
-- because the placeholder path depends on it not knowing some of them.
local function itemInfo(key)
	if type(key) == "string" then return "Worn thing", key, 3, 115 end

	local recipe = RECIPE_ITEMS[key]
	if recipe then
		-- name, link, quality, item level, required level, class, subclass, ...
		-- and the class as a number at twelve, which is the only locale-free part of it.
		return recipe.name, "|Hitem:" .. key .. "|h", 1, 1, recipe.minLevel or 0,
			"Recipe", recipe.profession, 1, nil, nil, 0, recipe.class
	end

	local name = ITEM_NAMES[key]
	if not name then return nil end
	return name, "|Hitem:" .. key .. "|h", 1, 20
end

C_Item = {
	GetItemInfo = itemInfo,
	RequestLoadItemDataByID = noop,
}
GetItemInfo = itemInfo

C_AddOns = { GetAddOnMetadata = function(_, field)
	if field == "Version" then return "0.1.0" end
end }

--------------------------------------------------------------------------------------------
-- Talents
--
-- Two systems behind one panel, so both are stubbed. The tree stub is a mage with 8 points
-- in Arcane on spec 1 and nothing at all on spec 2, which is the "never activated" case the
-- specification says must be reported rather than drawn as an empty tree.
--------------------------------------------------------------------------------------------

-- Anniversary carries GetNumSpecGroups and throws when it is called. Reproduced exactly,
-- because an existence check passes it and then the call it guards takes the scan down -
-- which is what happened in the game, and what this harness could not see.
GetNumSpecGroups = function()
	error("Script_GetNumSpecGroups: API unsupported in this version of World of Warcraft.")
end
GetActiveSpecGroup = function()
	error("Script_GetActiveSpecGroup: API unsupported in this version of World of Warcraft.")
end

GetNumTalentGroups = function() return 2 end
GetActiveTalentGroup = function() return 1 end

local TREES = {
	-- Named as a German client would have named it. The panel is not German, and the tree
	-- headings have to come from the game's own table rather than from this word.
	[1] = { name = "Arkan", icon = "arcane-icon", points = { [1] = 8, [2] = 0 },
	        talents = {
	          [1] = { "Arcane Subtlety", "icon1", 1, 1, { [1] = 2, [2] = 0 }, 2 },
	          [2] = { "Arcane Focus",    "icon2", 1, 2, { [1] = 5, [2] = 0 }, 5 },
	          [3] = { "Improved Arcane Missiles", "icon3", 2, 1, { [1] = 1, [2] = 0 }, 5 },
	          -- Nobody has put a point in this one. It is still part of the tree, and a
	          -- tree with the untaken talents left out is not a tree.
	          [4] = { "Wand Specialization", "icon4", 2, 2, { [1] = 0, [2] = 0 }, 5 },
	        } },
	[2] = { name = "Fire", icon = "fire-icon", points = { [1] = 0, [2] = 0 }, talents = {} },
	[3] = { name = "Frost", icon = "frost-icon", points = { [1] = 0, [2] = 0 }, talents = {} },
}

-- Mists has neither of these, and reports its grid shape in constants instead. Left absent
-- here so the fallback is what gets exercised, which is what the client actually does.
GetNumTalentTiers = nil
MAX_TALENT_TIERS = 6
NUM_TALENT_COLUMNS = 3

GetNumTalentTabs = function() return 3 end

-- Deliberately NOT the signature the code once assumed. Anniversary returns something whose
-- third value is not the points spent, which recorded a fully specced tree as having none
-- and then as never visited. The points must come from summing the ranks, so this stub
-- returns an id first and no point count at all - if the scanner ever leans on position
-- again, the totals below go wrong.
GetTalentTabInfo = function(tab, _, _, group)
	local t = TREES[tab]
	if not t then return nil end
	return 40 + tab, t.name, "A description", "Interface\\Icons\\" .. t.icon
end
GetNumTalents = function(tab)
	local t = TREES[tab]
	if not t then return 0 end
	local n = 0
	for _ in pairs(t.talents) do n = n + 1 end
	return n
end
GetTalentInfo = function(tab, index, _, _, group)
	local t = TREES[tab]
	local row = t and t.talents[index]
	if not row then return nil end
	return row[1], row[2], row[3], row[4], row[5][group or 1] or 0, row[6]
end

SLASH_FAMILY1, SLASH_FAMILY2 = nil, nil
SlashCmdList = {}

--------------------------------------------------------------------------------------------
-- Driving it
--------------------------------------------------------------------------------------------

-- A box with the keyboard eats the modifier keys, and this now says so.
--
-- Measured in play 2026-09-05, and it cost a day of looking in the wrong place. Family swapped
-- a recipe's tooltip for its product on CTRL, and the swap was dead whenever anything was typed
-- in the panel's search box - which on the whole-family readings is always, because the search
-- is what produces the rows. `MODIFIER_STATE_CHANGED` simply does not arrive while an EditBox
-- has focus: the client gives the key to the box.
--
-- The stub delivered it regardless, so it agreed with the mistake exactly as the quest-id stub
-- did (L-053), and no check written against the old mechanism could have gone red. It refuses
-- now, which is what makes the watcher below measurable rather than merely different.
local function fire(event, ...)
	if event == "MODIFIER_STATE_CHANGED" and frameMethods.__focused then return end

	for _, f in ipairs(frames) do
		if f.__events[event] and f.__scripts.OnEvent then
			f.__scripts.OnEvent(f, event, ...)
		end
	end
end

local function advance(seconds)
	local step = 0.1
	local elapsed = 0
	while elapsed < seconds do
		-- The fractional clock moves with the frames, because something that waits half a
		-- second between two sends is waiting on this and not on the tick count.
		FAKE_CLOCK = FAKE_CLOCK + step

		for _, f in ipairs(frames) do
			if f.__scripts.OnUpdate and f.__shown then
				f.__scripts.OnUpdate(f, step)
			end
		end
		elapsed = elapsed + step
	end
end

local function load(path, addonName, private)
	local chunk, err = loadfile(ROOT .. "/" .. path)
	if not chunk then error("could not load " .. path .. ": " .. tostring(err)) end
	local ok, runErr = pcall(chunk, addonName, private)
	if not ok then error("error running " .. path .. ": " .. tostring(runErr)) end
end

--------------------------------------------------------------------------------------------

local failures = 0
local function check(label, condition, detail)
	if condition then
		print(string.format("  ok    %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -> " .. detail) or ""))
	end
end

--------------------------------------------------------------------------------------------
-- The serialisation libraries
--
-- Stood in for rather than fetched. Family treats them as optional and works without them for
-- storage, but the addon channel carries a string and nothing else, so Wide Family cannot be
-- exercised at all unless something here can turn a table into one and back.
--
-- These stubs are deliberately not compression: what is under test is Family's use of them,
-- and a round trip that changes nothing is the strictest version of that. Anything Family
-- gets wrong about its own framing shows up here rather than being hidden by a codec that
-- happens to be tolerant.
--------------------------------------------------------------------------------------------

do
local function dumpValue(value)
	local kind = type(value)
	if kind == "number" or kind == "boolean" then return tostring(value) end
	if kind == "string" then return string.format("%q", value) end
	if kind ~= "table" then return "nil" end

	local pieces = {}
	for key, item in pairs(value) do
		local name = type(key) == "string" and string.format("[%q]", key)
			or string.format("[%s]", tostring(key))
		pieces[#pieces + 1] = name .. "=" .. dumpValue(item)
	end
	return "{" .. table.concat(pieces, ",") .. "}"
end
local libraries = {
	LibSerialize = {
		Serialize = function(_, data) return dumpValue(data) end,
		Deserialize = function(_, text)
			local chunk = loadstring("return " .. text)
			if not chunk then return false end
			local ok, data = pcall(chunk)
			if not ok then return false end
			return true, data
		end,
	},
	LibDeflate = {
		CompressDeflate = function(_, text) return text end,
		DecompressDeflate = function(_, text) return text end,
		-- Printable, and with no \1 in it: that is the character Comm cuts its own header
		-- with, so a payload containing one would be indistinguishable from a header and
		-- the reassembly would quietly go wrong.
		EncodeForPrint = function(_, text) return (text:gsub("[\1\2]", "?")) end,
		DecodeForPrint = function(_, text) return text end,
	},
}

LibStub = {
	GetLibrary = function(_, name) return libraries[name] end,
}
end

-- The game loads a dependency completely - files, then its ADDON_LOADED - before a dependent
-- addon's files run. Doing the same here, so a mistake about load order shows up in this
-- harness rather than in the client.
print("loading Family")
local FamilyPrivate = {}
for _, file in ipairs {
	"Core.lua",
	-- The string table, then every translation of it. All four are read on every client,
	-- English included, so that a broken locale file fails here rather than only for the
	-- players who speak that language and cannot be asked to run a harness.
	"Locale.lua",
	"Locales/deDE.lua", "Locales/frFR.lua", "Locales/esES.lua", "Locales/ruRU.lua",
	-- What each client calls each profession and each race, and which spell each talent
	-- is, generated from the client's own tables.
	"SkillLines.lua", "Races.lua", "TalentSpells.lua", "ChargedItems.lua",
	"WorldBuffs.lua", "Specialisations.lua", "MadeByItem.lua", "RecipeCooldowns.lua",
	"RecipeTeaches.lua",
	"Capabilities.lua", "Codec.lua",
	"Comm.lua", "Database.lua", "Names.lua", "Index.lua",
	"Recipes.lua", "Cooldowns.lua",
	"Scanners/Bags.lua", "Scanners/Talents.lua", "Scanners/Professions.lua",
	"Scanners/Bank.lua", "Scanners/Identity.lua",
	"Scanners/Auctions.lua", "Scanners/Mail.lua", "Scanners/Character.lua",
	"Scanners/Quests.lua",
	"Scanners/Currencies.lua",
	"Wide.lua",
	"Guild.lua",
} do
	load("addons/Family/" .. file, "Family", FamilyPrivate)
end

print()
print("startup")
fire("ADDON_LOADED", "Family")

-- Wide Family ships switched off until it has been tested against a real server, so a fresh
-- database has it off and the rest of this file has to turn it on the way a player would.
-- Checked here rather than taken on trust: "off by default" is a claim about what a stranger
-- receives, and the only place that is observable is a database nobody has touched.
check("wide family is off in a database nobody has touched",
	Family.Wide:Enabled() == false)
check("and asking to link while it is off is refused rather than sent",
	select(1, Family.Wide:RequestLink("Somebody")) == false)

-- Left off across the interface loading below, because whether its tab appears is decided
-- while the strip is built and the case worth testing is the one a stranger meets: the
-- feature off, and the tab there regardless. Switched on after that, the way a player would,
-- and checked there.

-- Narration is a fault-finding tool and a stranger should not be reading it. Nothing sets
-- FamilyDB.debug, so a fresh database leaves it nil and Family:Debug returns early - but
-- "nothing sets it" is a fact about code that somebody could change in a line, which is
-- what makes it worth a check rather than a comment.
check("the scanners do not narrate themselves in a database nobody has touched",
	not (FamilyDB and FamilyDB.debug))

print()
print("loading Family_UI")
local UIPrivate = {}
-- Named once, because a check below reads these same files and a second list would drift:
-- a new panel would be loaded and quietly not examined, which is the shape of an omission
-- nobody notices until it is in somebody's game.
local UI_FILES = { "Window.lua", "MemberPicker.lua", "ChoicePicker.lua", "MemberFilters.lua",
	"Tooltip.lua",
	"Summary.lua", "Talents.lua",
	"Contents.lua", "Professions.lua", "Character.lua", "Quests.lua", "Wide.lua", "Guild.lua",
	"Broker.lua", "Options.lua", "About.lua", "Slash.lua" }

for _, file in ipairs(UI_FILES) do
	load("addons/Family_UI/" .. file, "Family_UI", UIPrivate)
end
fire("ADDON_LOADED", "Family_UI")

-- But the tab is there. It used to appear only once the feature was on, so the only way to
-- learn Wide Family existed was to read a manual - and a choice nobody can find is not a
-- choice anybody has made. Both sharing features ship off and both panels are in the list
-- either way, each carrying its own switch; finding one is not flipping it.
check("its tab is in the strip anyway", Family.UI:HasTab("wide"))
check("and the guild's is too, for the same reason", Family.UI:HasTab("guild"))


-- On from here, the way a player would, because the rest of this file exercises the protocol.
Family.Wide:SetEnabled(true)
check("and it can be switched on", Family.Wide:Enabled() == true)

check("FamilyDB created with a schema", FamilyDB and FamilyDB.schema == 1,
	FamilyDB and tostring(FamilyDB.schema) or "no FamilyDB")
check("expansion detected as Classic Era", Family.Capabilities.name == "Classic Era",
	Family.Capabilities.name)
check("dual spec is on on Era", Family.Capabilities:Has("dualSpec") == true)
check("achievements are off on Era", Family.Capabilities:Has("achievements") == false)
check("currencies are off on Era", Family.Capabilities:Has("currencies") == false)
check("guild bank is off on Era", Family.Capabilities:Has("guildBank") == false)
check("keyring is on on Era", Family.Capabilities:Has("keyring") == true)
check("unknown capability answers false", Family.Capabilities:Has("nonsense") == false)

-- Burning Crusade is the harder half of the same case, and the one that catches people out:
-- Era is obviously an old game, whereas Anniversary looks modern and its client carries the
-- whole achievement API. It has no achievements all the same. Checked by asking the table
-- what it says for that build rather than by reasoning about it, because reasoning about it
-- is exactly what goes wrong.
;(function()
	local realBuildInfo = GetBuildInfo
	GetBuildInfo = function() return "2.5.6", "00000", "", 20506 end
	Family.Capabilities:Detect()

	check("the client is recognised as Burning Crusade",
		Family.Capabilities.name == "Burning Crusade", Family.Capabilities.name)
	check("and achievements are off there too, whatever the client carries",
		Family.Capabilities:Has("achievements") == false)
	check("while the guild bank, which it really does have, is on",
		Family.Capabilities:Has("guildBank") == true)

	GetBuildInfo = realBuildInfo
	Family.Capabilities:Detect()
	check("and putting the build back puts the answers back",
		Family.Capabilities.name == "Classic Era")
end)()

-- The bug the game found three times over: these clients carry symbols for features they do
-- not have. GetAchievementInfo, C_GuildBank and KEYRING_CONTAINER all exist on clients where
-- the feature does not. A probe finding one must change nothing at all.
--
-- Put back afterwards, because the Mists section below reads achievements for real and a
-- stub left standing here quietly emptied that whole list.
GetAchievementInfo = function() end
C_GuildBank = {}
Family.Capabilities:Detect()
check("a symbol cannot turn a feature on",
	Family.Capabilities:Has("achievements") == false)
check("nor can a second one",
	Family.Capabilities:Has("guildBank") == false)

local reported = {}
for _, entry in ipairs(Family.Capabilities:Report()) do reported[entry.feature] = entry end
check("but the disagreement is reported for a human to look at",
	reported.achievements.disagrees ~= nil, tostring(reported.achievements.disagrees))
check("and entries checked in game are marked as such",
	reported.achievements.source == "seen in game", reported.achievements.source)
check("while unchecked ones are not",
	reported.ammoBags.source == "expected", reported.ammoBags.source)

-- The symbol goes away again, and the real stub comes back with it: the Mists section below
-- reads achievements for real, and a probe's leavings standing in for the client quietly
-- emptied that whole list.
GetAchievementInfo, C_GuildBank = realAchievementInfo, nil
Family.Capabilities:Detect()

print()
print("login and bag scan")
fire("PLAYER_ENTERING_WORLD")
advance(4)

local key = Family:CurrentMember()
check("member key has no space in the realm", key == "Tester-FireMaw", key)

local meta = Family.Database:Meta(key)
check("meta recorded", meta ~= nil)
if meta then
	check("money", meta.money == 12345678, tostring(meta.money))
	check("level", meta.level == 60, tostring(meta.level))
	check("class", meta.classFile == "MAGE", tostring(meta.classFile))
	-- 16 + 16 general. The quiver's 16 must NOT be here.
	check("general bag slots exclude the quiver", meta.bagSlots == 32, tostring(meta.bagSlots))
	check("general free slots exclude the quiver", meta.bagFree == 29, tostring(meta.bagFree))
	-- The quiver's sixteen and the keyring's eight. Both are special: their slots are not
	-- room for anything else, which is the whole reason the two figures are kept apart.
	check("quiver and keyring counted separately", meta.specialSlots == 24,
		tostring(meta.specialSlots))
	check("lastSeen stamped", meta.lastSeen ~= nil)
end

local payload = Family.Database:Payload(key)
check("payload recorded", payload ~= nil and payload.bags ~= nil)
if payload and payload.bags then
	check("backpack contents", payload.bags[0].slots[2].id == 2589
		and payload.bags[0].slots[2].count == 20)
	check("quiver flagged special", payload.bags[2].special == true)
	check("backpack never special", payload.bags[0].special == false)
	check("bag item id recorded by id", payload.bags[1].itemID ~= nil)
end

print()
print("money-only update does not need a full scan")
GetMoney = function() return 500 end
fire("PLAYER_MONEY")
check("money updated in place", Family.Database:Meta(key).money == 500,
	tostring(Family.Database:Meta(key).money))
check("bag totals untouched", Family.Database:Meta(key).bagSlots == 32)

print()
print("identity")
advance(3)

local id = Family.Database:Meta(key)
check("hearthstone recorded", id.hearth == "Shattrath City", tostring(id.hearth))
check("guild recorded", id.guild == "Late Night Raiders", tostring(id.guild))
check("guild rank too", id.guildRank == "Officer", tostring(id.guildRank))
check("experience recorded", id.xp == 4000 and id.xpMax == 10000)
check("rested experience recorded", id.rested == 2500, tostring(id.rested))

-- Time played cannot be read, only received. Nothing until the server says so.
check("time played is absent until the server sends it", id.played == nil)
fire("TIME_PLAYED_MSG", 616852, 31404)
check("and recorded when it arrives",
	Family.Database:Meta(key).played == 616852,
	tostring(Family.Database:Meta(key).played))

-- At the cap experience stops existing, and a zero would read as no progress rather than
-- as finished.
UnitLevel = function() return 70 end
Family.Identity:Scan()
check("experience is dropped at the level cap",
	Family.Database:Meta(key).xpMax == nil)
UnitLevel = function() return 60 end
Family.Identity:Scan()

-- The guild, which is the one thing on this scan the client answers late
--
-- Reported from a live client: a character played that morning, in the guild, with guild
-- share switched on, reading as "not running Family" on the player's own roster and missing
-- from the grid of what they share. Everything in §7 is keyed by the guild a character is
-- *recorded* as being in, and that field had never been written.
--
-- IsInGuild answers the moment the client loads and GetGuildInfo does not. The scan runs two
-- seconds after entering the world and one second after PLAYER_GUILD_UPDATE, both of which
-- can land inside that gap - and SetMeta merges, so a nil field is skipped rather than
-- written. Nothing fires afterwards to put it right: the event that scheduled the scan which
-- missed has already been and gone.
do
	local realInGuild, realGuildInfo = IsInGuild, GetGuildInfo

	local recorded = Family.Database:Meta(key).guild
	check("the guild is on the record to begin with", recorded == "Late Night Raiders",
		tostring(recorded))

	-- In a guild, and the client will not yet say which.
	IsInGuild = function() return true end
	GetGuildInfo = function() return nil end
	Family.Identity:Scan()

	check("a client that will not name the guild yet does not unname it",
		Family.Database:Meta(key).guild == "Late Night Raiders",
		tostring(Family.Database:Meta(key).guild))

	-- And it asks again rather than leaving it. The name arriving between one attempt and
	-- the next is the whole of what the retry is for.
	Family.Database:SetMeta(key, { guild = Family.CLEAR })
	Family.Identity:Scan()
	check("with nothing on the record, it is still not guessed at",
		Family.Database:Meta(key).guild == nil)

	GetGuildInfo = function() return "Late Night Raiders", "Officer", 2 end
	advance(4)
	check("and the scan it asked for records it once the client answers",
		Family.Database:Meta(key).guild == "Late Night Raiders",
		tostring(Family.Database:Meta(key).guild))

	-- A few times and then it stops. A scanner waking up for ever is what "wait for it to
	-- arrive" turns into when it never does.
	GetGuildInfo = function() return nil end
	Family.Database:SetMeta(key, { guild = Family.CLEAR })
	Family.Identity.waitingForGuild = nil
	Family.Identity:Scan()
	for _ = 1, 12 do advance(4) end
	check("and it gives up rather than asking for ever",
		Family.Identity.waitingForGuild ~= nil and Family.Identity.waitingForGuild <= 7,
		tostring(Family.Identity.waitingForGuild))

	-- Not in a guild, recorded as an answer rather than as an absence.
	--
	-- A missing guild name meant four things at once - never scanned, the client had not
	-- caught up, the client has no IsInGuild, and genuinely in no guild - and only the last is
	-- a fact about the character. The panel drew one dash for all four and looked complete.
	Family.Identity.waitingForGuild = nil
	IsInGuild = function() return false end
	GetGuildInfo = function() return nil end
	Family.Identity:Scan()
	check("a client that says outright there is no guild records that",
		Family.Database:Meta(key).guildless == true,
		tostring(Family.Database:Meta(key).guildless))
	check("and takes the guild off the record with it",
		Family.Database:Meta(key).guild == nil,
		tostring(Family.Database:Meta(key).guild))

	-- Joining one takes it away again, or a character who joined a guild would go on being
	-- drawn as having none for as long as the record lasted.
	IsInGuild = function() return true end
	GetGuildInfo = function() return "Late Night Raiders", "Officer", 2 end
	Family.Identity:Scan()
	check("and joining a guild clears it rather than leaving both on the record",
		Family.Database:Meta(key).guildless == nil
			and Family.Database:Meta(key).guild == "Late Night Raiders",
		tostring(Family.Database:Meta(key).guildless))

	-- In a guild the client will not name. Nothing may be written here either way: guessing
	-- which of the two silences this is, is the whole of what the field exists to avoid.
	Family.Database:SetMeta(key, { guildless = Family.CLEAR })
	Family.Identity.waitingForGuild = nil
	GetGuildInfo = function() return nil end
	Family.Identity:Scan()
	check("a client that will not name the guild records neither answer",
		Family.Database:Meta(key).guildless == nil,
		tostring(Family.Database:Meta(key).guildless))

	-- And a client with no IsInGuild at all, which is the same silence for a different reason.
	Family.Identity.waitingForGuild = nil
	IsInGuild = nil
	Family.Identity:Scan()
	check("nor does one with no way of being asked",
		Family.Database:Meta(key).guildless == nil,
		tostring(Family.Database:Meta(key).guildless))

	IsInGuild, GetGuildInfo = realInGuild, realGuildInfo
	Family.Identity.waitingForGuild = nil
	Family.Identity:Scan()


	------------------------------------------------------------------------------------------
	-- And a fresh reason to ask re-arms the attempts
	--
	-- The counter bounds one series and not the session. Seen live on a freshly created guild:
	-- the character who had just made it was recorded as being in none, and everything in §7 is
	-- keyed on the guild a character is *recorded* in - so the guild master was absent from his
	-- own offering.
	------------------------------------------------------------------------------------------

	GetGuildInfo = function() return nil end
	IsInGuild = function() return true end
	Family.Database:SetMeta(key, { guild = Family.CLEAR })
	Family.Identity.waitingForGuild = nil

	Family.Identity:Scan()
	for _ = 1, 12 do advance(4) end
	check("it has given up after a series of tries",
		(Family.Identity.waitingForGuild or 0) > 5,
		tostring(Family.Identity.waitingForGuild))

	-- Which is exactly what a PLAYER_GUILD_UPDATE means: the game saying this has changed, ask
	-- again. Before this it was answered with one attempt and a shrug.
	Family.Identity:Scan()
	check("and a fresh scan starts the count over rather than giving up at once",
		(Family.Identity.waitingForGuild or 0) == 1,
		tostring(Family.Identity.waitingForGuild))

	GetGuildInfo = function() return "Late Night Raiders", "Officer", 2 end
	advance(4)
	check("so the guild is recorded when the client finally answers",
		Family.Database:Meta(key).guild == "Late Night Raiders",
		tostring(Family.Database:Meta(key).guild))

	-- And the roster arriving is a reason of its own, because it is the client saying it knows
	-- which guild this is. Only where the fact is missing: it fires on every refresh, and a
	-- scan per refresh would be this scanner running all evening in a guild somebody is
	-- looking at.
	GetGuildInfo = function() return nil end
	Family.Database:SetMeta(key, { guild = Family.CLEAR })
	Family.Identity.waitingForGuild = nil

	fire("GUILD_ROSTER_UPDATE")
	GetGuildInfo = function() return "Late Night Raiders", "Officer", 2 end
	advance(3)
	check("the roster arriving is reason enough to ask again",
		Family.Database:Meta(key).guild == "Late Night Raiders",
		tostring(Family.Database:Meta(key).guild))

	-- And costs nothing where there is nothing to settle.
	local scans = 0
	local realScan = Family.Identity.Scan
	Family.Identity.Scan = function(self, retrying) scans = scans + 1
		return realScan(self, retrying) end

	fire("GUILD_ROSTER_UPDATE")
	advance(3)
	check("and does nothing at all when the guild is already recorded",
		scans == 0, tostring(scans) .. " scan(s)")

	Family.Identity.Scan = realScan

	-- Put back what the checks below are written against: a client that will not name the
	-- guild. Restoring it to the value this block happened to leave, rather than to the one
	-- the next check needs, is how a fixture passes its own state to the next one - which has
	-- cost an evening here before.
	GetGuildInfo = function() return nil end

	-- Not in a guild at all, which is a different answer from "has not said yet" and has to
	-- be written: SetMeta merges, so a nil would leave the last guild sitting there and a
	-- character who left one would go on being offered to it.
	IsInGuild = function() return false end
	Family.Database:SetMeta(key, { guild = "Late Night Raiders", guildRank = "Officer" })
	Family.Identity:Scan()
	check("a character who is in no guild has the last one cleared rather than kept",
		Family.Database:Meta(key).guild == nil
			and Family.Database:Meta(key).guildRank == nil,
		tostring(Family.Database:Meta(key).guild))

	-- And on a client with no IsInGuild there is no way to tell the two apart, so nothing is
	-- written either way - clearing on "has not said yet" would take a guild away from
	-- somebody who is in one.
	IsInGuild = nil
	Family.Database:SetMeta(key, { guild = "Late Night Raiders" })
	Family.Identity:Scan()
	check("a client that cannot be asked leaves the record alone",
		Family.Database:Meta(key).guild == "Late Night Raiders",
		tostring(Family.Database:Meta(key).guild))

	IsInGuild, GetGuildInfo = realInGuild, realGuildInfo
	Family.Identity.waitingForGuild = nil
	Family.Identity:Scan()
	check("and the fixture is put back", Family.Database:Meta(key).guild
		== "Late Night Raiders")
end

print()
print("currencies")

-- Wrapped, because Lua counts locals per chunk and this file has a great many: names
-- that are only wanted for these checks should stop existing when the checks are done.
do
-- Three clients, three ways of being asked, and none of them will say which one it is. Each
-- is stubbed on its own here, because a client that has one of these does not have the
-- others and a stub answering to all three would prove nothing about any of them.
local function clearCurrencyAPI()
	GetHonorCurrency, GetArenaCurrency = nil, nil
	GetCurrencyListSize, GetCurrencyListInfo, GetCurrencyListLink = nil, nil, nil
	C_CurrencyInfo = nil
end

-- The Burning Crusade clients: two calls, two bare numbers, no list and no ids anywhere.
clearCurrencyAPI()
GetHonorCurrency = function() return 12340 end
GetArenaCurrency = function() return 875 end

local money = Family.Currencies:Read()
check("honor and arena points are read where the client has only those two calls",
	money ~= nil and #money == 2, money and tostring(#money))

local function currencyNamed(list, kind)
	for _, entry in ipairs(list or {}) do
		if entry.kind == kind then return entry end
	end
	return nil
end

check("honor keeps its amount", (currencyNamed(money, "honor") or {}).quantity == 12340)
check("and a client with no id for it gets a key of Family's own, never a name",
	(currencyNamed(money, "honor") or {}).key == "honor"
		and (currencyNamed(money, "honor") or {}).id == nil)
check("arena points are read too", (currencyNamed(money, "arena") or {}).quantity == 875)

-- Zero is a balance. It is the missing call that means nothing is known, and the two are
-- the same nil from the client - so the one that answers is believed, zero and all.
GetArenaCurrency = function() return 0 end
check("a currency the client reports as nought is still recorded",
	(currencyNamed(Family.Currencies:Read(), "arena") or {}).quantity == 0)

GetArenaCurrency = function() end
check("and one the client will not answer for at all is not invented",
	currencyNamed(Family.Currencies:Read(), "arena") == nil)

-- The clients that keep a list: eleven return values, headers in among the currencies, and
-- the id only inside a link.
clearCurrencyAPI()
GetCurrencyListSize = function() return 3 end
GetCurrencyListInfo = function(index)
	if index == 1 then return "Player vs Player", true end
	if index == 2 then return "Honor Points", false, false, false, false, 22000,
		"Interface\\Icons\\PVP", 75000 end
	return "Arena Points", false, false, false, false, 1200,
		"Interface\\Icons\\Arena", 0
end
GetCurrencyListLink = function(index)
	return index == 2 and "|Hcurrency:1901|h[Honor]|h" or "|Hcurrency:1900|h[Arena]|h"
end

money = Family.Currencies:Read()
check("a currency list is read, and its headers are not currencies",
	money ~= nil and #money == 2, money and tostring(#money))
check("with the id taken out of the link rather than the name kept",
	money and money[1] and money[1].id == 1900 and money[1].key == "c1900",
	money and money[1] and tostring(money[1].id))
check("and the cap where there is one", (money[2] or {}).max == 75000,
	tostring((money[2] or {}).max))
-- Nothing in the game is capped at nought, so a nought there means "no cap" - and drawing
-- it as a ceiling would report every one of them as full.
check("a cap of nought is no cap at all", (money[1] or {}).max == nil)

-- Mists and anything on the modern engine, which answers with a table.
clearCurrencyAPI()
C_CurrencyInfo = {
	GetCurrencyListSize = function() return 2 end,
	GetCurrencyListInfo = function(index)
		if index == 1 then return { name = "Valor", isHeader = false, quantity = 980,
			maxQuantity = 3000, iconFileID = 12345, currencyID = 396 } end
		return { name = "Currencies", isHeader = true }
	end,
	GetCurrencyListLink = function() return nil end,
}

money = Family.Currencies:Read()
check("the modern list is read from the table it answers with, not by position",
	money ~= nil and #money == 1 and money[1].id == 396 and money[1].quantity == 980,
	money and money[1] and tostring(money[1].id))

-- A client with both is one client, not two: the same currencies would otherwise be counted
-- once from the list and once from the standalone calls.
GetHonorCurrency = function() return 5 end
clearCurrencyAPI()
GetCurrencyListSize = function() return 1 end
GetCurrencyListInfo = function() return "Honor Points", false, false, false, false, 4000,
	"Interface\\Icons\\PVP", 75000 end
GetCurrencyListLink = function() return "|Hcurrency:1901|h[Honor]|h" end
GetHonorCurrency = function() return 4000 end

money = Family.Currencies:Read()
check("a client with a list and the old calls counts each currency once",
	money ~= nil and #money == 1, money and tostring(#money))

-- Back to the two calls, which is what the rest of this file's pretend client has.
clearCurrencyAPI()
GetHonorCurrency = function() return 12340 end
GetArenaCurrency = function() return 875 end

Family.Currencies:Scan()
local recorded = Family.Database:Meta(key)
check("a scan records them against the member",
	recorded.currencies ~= nil and #recorded.currencies == 2)
check("stamped with when it was done", recorded.currenciesSeen ~= nil)

-- A client that will not answer today is not evidence that yesterday's answer was wrong.
clearCurrencyAPI()
Family.Currencies:Scan()
check("a client that answers nothing leaves what was recorded alone",
	#(Family.Database:Meta(key).currencies or {}) == 2)

GetHonorCurrency = function() return 12340 end
GetArenaCurrency = function() return 875 end
end

print()
print("professions")
do
advance(5)

-- Skill line ids. Professions are filed under these rather than under a word, because a word
-- is one language: the stub below calls enchanting "Enchantement", and that is the whole
-- point - it is the same profession as anybody else's, and now files under the same key.
-- One table rather than four locals: this chunk is close to Lua's limit of 200 of them.
local SKILL = { blacksmithing = 164, cooking = 185, firstAid = 129, enchanting = 333 }

local skills = Family.Database:Meta(key).skills
check("professions recorded", skills ~= nil)
if skills then

	-- Blacksmithing sits under a collapsed header. A scan that only reads what is visible
	-- reports no professions at all, which is the failure this stub exists to catch.
	check("a skill hidden under a collapsed header is still found",
		skills[SKILL.blacksmithing] ~= nil)
	check("with its rank", skills[SKILL.blacksmithing] and skills[SKILL.blacksmithing].rank == 287,
		skills[SKILL.blacksmithing] and tostring(skills[SKILL.blacksmithing].rank))
	check("and it is filed under its skill line id, not under a word",
		skills.Blacksmithing == nil and skills[SKILL.blacksmithing] ~= nil,
		"a name-keyed profession is a profession that vanishes when the client changes")
	check("with what this client called it kept beside it",
		skills[SKILL.blacksmithing] and skills[SKILL.blacksmithing].name == "Blacksmithing",
		skills[SKILL.blacksmithing] and tostring(skills[SKILL.blacksmithing].name))
	check("a secondary profession is a profession, though it cannot be unlearned",
		skills[SKILL.cooking] ~= nil and skills[SKILL.firstAid] ~= nil)
	check("cooking is marked secondary",
		skills[SKILL.cooking] and skills[SKILL.cooking].secondary == true)
	check("and so is first aid, with its rank",
		skills[SKILL.firstAid] and skills[SKILL.firstAid].secondary == true
			and skills[SKILL.firstAid].rank == 225,
		skills[SKILL.firstAid] and tostring(skills[SKILL.firstAid].rank))
	check("blacksmithing is not", skills[SKILL.blacksmithing]
		and skills[SKILL.blacksmithing].secondary == false)
	check("a weapon skill is not mistaken for a profession", skills.Swords == nil)
	check("nor is a language", skills.Common == nil)
end

local collapsedAfter = false
for _, line in ipairs(SKILL_LINES) do
	if line.name == "Trade Skills" and not line.expanded then collapsedAfter = true end
end
check("and the skill window is put back as it was found", collapsedAfter)

check("no recipes until a profession window is opened",
	Family.Database:Payload(key).professions[SKILL.blacksmithing].recipes == nil)

fire("TRADE_SKILL_SHOW")
advance(1)
local bs = Family.Database:Payload(key).professions[SKILL.blacksmithing]
check("recipes read once the window is open", bs.recipes and #bs.recipes == 2,
	bs.recipes and tostring(#bs.recipes))
check("the header is not a recipe", bs.recipes
	and bs.recipes[1].name == "Runed Copper Breastplate", bs.recipes and bs.recipes[1].name)
check("a recipe keeps the spell id from its link", bs.recipes
	and bs.recipes[1].spellID == 2667, bs.recipes and tostring(bs.recipes[1].spellID))
check("and the icon the client drew it with, rather than one worked out afterwards",
	bs.recipes and bs.recipes[1].icon ~= nil, bs.recipes and tostring(bs.recipes[1].icon))
check("and the item id of what it makes", bs.recipes
	and bs.recipes[1].itemID == 2864, bs.recipes and tostring(bs.recipes[1].itemID))
check("difficulty is the client's own unlocalised word", bs.recipes
	and bs.recipes[2].difficulty == "optimal", bs.recipes and bs.recipes[2].difficulty)

-- The two rows carry two different kinds of link on purpose. Which kind a client hands back
-- is not something this file can settle - a live Era client returned nothing readable at all,
-- and a hundred and fifty recipes went unnamed because one kind was assumed.
check("a recipe link of another kind is read just the same", bs.recipes
	and bs.recipes[2].spellID == 3339, bs.recipes and tostring(bs.recipes[2].spellID))
check("and when they were seen is recorded", bs.recipesSeen ~= nil)

-- Enchanting arrives through the Craft frame. The character has no skill by that name, so
-- it must be refused - the same frame carries Beast Training, and a hunter's pet abilities
-- are not a profession.
TRADE_SKILL_OPEN = false
fire("CRAFT_SHOW")
advance(1)
check("a craft the member has no skill for is refused",
	Family.Database:Payload(key).professions[SKILL.enchanting] == nil)

-- Give them the skill and it is accepted, items and item-less enchants alike.
table.insert(SKILL_LINES, { name = "Enchantement", rank = 300, maxRank = 300,
	abandonable = true })
Family.Professions:Scan(true)
local ench = Family.Database:Payload(key).professions[SKILL.enchanting]
check("enchanting is read from the Craft frame", ench ~= nil and ench.recipes ~= nil)
check("both its recipes are kept", ench and #ench.recipes == 2,
	ench and tostring(#ench.recipes))
check("an enchant that creates no item still has its spell",
	ench and ench.recipes[1].spellID == 13640 and ench.recipes[1].itemID == nil)
check("and one that makes an oil has both",
	ench and ench.recipes[2].spellID == 25128 and ench.recipes[2].itemID == 20749)
check("opening a window marks it as a profession",
	FamilyDB.professionNames["Enchantement"] == true)

-- A window whose sub-class headers are collapsed
--
-- The window lists what it *shows*: a collapsed header hides every row under it, and the
-- count is of rows on screen. The skill list has been expanded and put back since this
-- scanner was written, and the window the recipes are actually in never was - so a player
-- who keeps their categories folded had their recipe list read as one row of heading.
--
-- Put back afterwards, because leaving somebody's window rearranged is how they learn not to
-- trust the addon.
do
	CRAFT_COLLAPSED = true
	check("a collapsed window hides its rows from the client, as the game's does",
		(Family:TryCall(GetNumCrafts) or 0) == 1, tostring(Family:TryCall(GetNumCrafts)))

	-- Wiped first, or this proves nothing. The craft reader answers nil when it finds no
	-- rows, and a nil leaves the record from the scan before it in place - so the check
	-- would pass on a list read while the window was open, which is the opposite of what
	-- it is asking about.
	Family.Database:Payload(key).professions[SKILL.enchanting].recipes = nil

	Family.Professions:Scan(true)
	local folded = Family.Database:Payload(key).professions[SKILL.enchanting]
	check("and every recipe is read anyway", folded and #folded.recipes == 2,
		folded and tostring(#folded.recipes) or "nothing recorded")
	check("with the window left folded as it was found", CRAFT_COLLAPSED == true)

	CRAFT_COLLAPSED = false
end

-- The same for the trade skill window, which is the one Alchemy and Cooking are in.
do
	local realOpen = TRADE_SKILL_OPEN
	TRADE_SKILL_OPEN = true
	TRADE_COLLAPSED = true

	check("a collapsed trade skill window hides its rows too",
		(Family:TryCall(GetNumTradeSkills) or 0) == 1,
		tostring(Family:TryCall(GetNumTradeSkills)))

	Family.Professions:Scan(true)
	local smithing = Family.Database:Payload(key).professions[SKILL.blacksmithing]
	check("and its recipes are read anyway", smithing and #smithing.recipes == 2,
		smithing and tostring(#smithing.recipes) or "nothing recorded")
	check("with that window left folded as it was found too", TRADE_COLLAPSED == true)

	TRADE_COLLAPSED = false
	TRADE_SKILL_OPEN = realOpen
end

-- The third client's window, which hands back a recipe id and nothing else
--
-- Mists has C_TradeSkillUI and answers with recipe ids; the id of the thing each one makes has
-- to be asked for separately. Without it every recipe on that client is a spell alone, and
-- "who can make one of these" has only the recipe's name to go on - which is the product's
-- name for most trade skills and is not for the ones that are not named after what they make.
do
	-- Put back as found rather than as expected. The craft tests after this one need the
	-- trade skill window shut, and restoring it open left them reading the wrong window -
	-- which is the third time in this file a block has broken the one after it by tidying
	-- to a value it assumed rather than to the one it displaced.
	local realCraft, realOpen = GetCraftName, TRADE_SKILL_OPEN
	GetCraftName = function() return "UNKNOWN" end
	TRADE_SKILL_OPEN = false

	C_TradeSkillUI = {
		GetTradeSkillLine = function() return "Blacksmithing" end,
		GetAllRecipeIDs = function() return { 3304, 2667 } end,
		GetRecipeInfo = function(id)
			return { learned = true, name = "Recipe " .. id, relativeDifficulty = "easy",
				numAvailable = 0 }
		end,
		-- Answered for one and not the other, because a client that will not say is the
		-- case this has to survive rather than the case it is written for.
		GetRecipeItemLink = function(id)
			if id == 3304 then return "|cffffffff|Hitem:3576|h[Tin Bar]|h|r" end
			return nil
		end,
	}

	Family.Professions:Scan(true)

	local modern = Family.Database:Payload(key).professions[SKILL.blacksmithing]
	local made, spellOnly
	for _, recipe in ipairs((modern or {}).recipes or {}) do
		if recipe.spellID == 3304 then made = recipe end
		if recipe.spellID == 2667 then spellOnly = recipe end
	end

	check("a recipe id window is read at all", made ~= nil and spellOnly ~= nil)
	check("and the id of what each one makes is asked for separately",
		made and made.itemID == 3576, made and tostring(made.itemID) or "nothing")
	check("while one the client will not answer for keeps its spell and no more",
		spellOnly and spellOnly.spellID == 2667 and spellOnly.itemID == nil)

	C_TradeSkillUI = nil
	GetCraftName = realCraft
	TRADE_SKILL_OPEN = realOpen
end

-- A window that is open and lists nothing at all
--
-- Which is what another addon filtering or replacing that window looks like from in here. It
-- must not be recorded as a window nobody ever opened: those are two different facts (§2.2),
-- and collapsing the first into the second is what sent somebody hunting a fault in Family
-- for an evening over a conflict on their own machine.
do
	local realCount, realOpen = GetNumTradeSkills, TRADE_SKILL_OPEN
	TRADE_SKILL_OPEN = true
	GetNumTradeSkills = function() return 0 end

	Family.Database:Payload(key).professions[SKILL.blacksmithing].recipes = nil
	Family.Professions:Scan(true)

	local empty = Family.Database:Payload(key).professions[SKILL.blacksmithing]
	check("a window that opens and lists nothing is recorded as opened, not as never opened",
		empty and type(empty.recipes) == "table" and #empty.recipes == 0,
		empty and tostring(empty.recipes) or "no record at all")

	-- Put back with the window still open, or the scan that is meant to restore the list
	-- takes the craft path instead and blacksmithing keeps the empty one.
	GetNumTradeSkills = realCount
	Family.Professions:Scan(true)
	check("and the real list comes back on the next scan",
		#Family.Database:Payload(key).professions[SKILL.blacksmithing].recipes == 2,
		tostring(#Family.Database:Payload(key).professions[SKILL.blacksmithing].recipes))

	TRADE_SKILL_OPEN = realOpen
end

-- Beast Training: the same frame a third time, with no skill line and no skill - so not a
-- profession, and not nothing either. A hunter's pet abilities are a real list of things that
-- member can do, and they are filed as abilities rather than thrown away.
local beastCraftName = GetCraftName
GetCraftName = function() return "Beast Training" end
GetCraftDisplaySkillLine = function() return nil end
Family.Professions:Scan(true)

check("a craft window that is not a profession is not recorded as one",
	Family.Database:Payload(key).professions["Beast Training"] == nil)
check("but what it teaches is kept, as abilities",
	Family.Database:Payload(key).crafts
		and Family.Database:Payload(key).crafts["Beast Training"] ~= nil)
check("with everything that was in it",
	Family.Database:Payload(key).crafts
		and #Family.Database:Payload(key).crafts["Beast Training"].entries == 2)

GetCraftName = beastCraftName
GetCraftDisplaySkillLine = nil

-- Rogue poisons: the same frame again, this time with a skill bar of its own and no line in
-- the skill list at all. Beast Training has neither, and that is the whole difference.
local savedCraftName = GetCraftName
GetCraftName = function() return "Poisons" end
GetCraftDisplaySkillLine = function() return "Poisons", 210, 300 end
Family.Professions:Scan(true)

local poisons = Family.Database:Payload(key).professions["Poisons"]
check("a craft window with a skill line of its own is a profession", poisons ~= nil)
check("and its rank is taken from the window, the only place it is stated",
	poisons and poisons.rank == 210, poisons and tostring(poisons.rank))
check("with its recipes", poisons and poisons.recipes and #poisons.recipes == 2,
	poisons and poisons.recipes and tostring(#poisons.recipes))

GetCraftName = function() return "Beast Training" end
GetCraftDisplaySkillLine = function() return nil end
Family.Professions:Scan(true)
check("a craft window with no skill line and no skill is still refused",
	Family.Database:Payload(key).professions["Beast Training"] == nil)

GetCraftName = savedCraftName
GetCraftDisplaySkillLine = nil

-- Runeforging: a trade skill window full of things a death knight can make, with no skill
-- line and no rank anywhere. The trade skill frame is not shared with anything that is not a
-- profession, so what it says is believed - and the rank stays absent rather than being
-- invented as nought out of nought.
TRADE_SKILL_OPEN = true
local savedTradeLine = GetTradeSkillLine
GetTradeSkillLine = function() return "Runeforging" end
Family.Professions:Scan(true)

local runeforging = Family.Database:Payload(key).professions["Runeforging"]
check("a trade window for something the skill list has never heard of is believed",
	runeforging ~= nil and runeforging.recipes ~= nil)
check("and it is kept with no rank rather than a made-up one",
	runeforging and runeforging.rank == nil, runeforging and tostring(runeforging.rank))

GetTradeSkillLine = savedTradeLine
TRADE_SKILL_OPEN = false

print()
end
print("what is ready, and what is not ready yet")

local craftCooldowns = Family.Database:Meta(key).craftCooldowns
check("a recipe on cooldown is recorded", craftCooldowns and #craftCooldowns > 0,
	craftCooldowns and tostring(#craftCooldowns))
check("as the moment it comes ready rather than as time remaining, which goes stale",
	craftCooldowns and craftCooldowns[1].readyAt > time(),
	craftCooldowns and tostring(craftCooldowns[1].readyAt))

local itemCooldowns = Family.Database:Meta(key).itemCooldowns
check("and so is a thing in a bag with a long cooldown of its own",
	itemCooldowns and #itemCooldowns == 1, itemCooldowns and tostring(#itemCooldowns))
-- The second slot holds something on half an hour, which is a cooldown and is not news. The
-- hearthstone is the one that proved this: it was being announced at login.
check("but a half-hour cooldown is not one of the things this is for",
	itemCooldowns and #itemCooldowns == 1, itemCooldowns and tostring(#itemCooldowns))

-- And a client that has not settled its cooldown clock is not believed.
--
-- At login the client can answer with a `start` in the *future*, and the arithmetic that
-- turns start and duration into a moment then produces a wait longer than the cooldown
-- itself: a salt shaker whose cooldown is three days was recorded as ready in 49, and shown
-- that way on the Crafting panel until the character was rescanned by hand. Reported from
-- play, with that rescan as the clue - the arithmetic was right and one of its inputs was not.
--
-- A cooldown cannot have more time left than its own length, because `start` is a moment that
-- has already passed. That is an invariant rather than a guess, and it costs one comparison.
do
	COOLDOWN_UNSETTLED = true
	Family.Bags:Scan()

	local unsettled = Family.Database:Meta(key).itemCooldowns
	check("a start in the future is refused rather than written as a very long wait",
		unsettled == nil or #unsettled == 0,
		unsettled and tostring(#unsettled) .. " recorded, first readyAt in "
			.. tostring(math.floor(((unsettled[1] or {}).readyAt or 0) - time()) / 86400)
			.. " days" or "none")

	-- And the next scan, once the client has settled, records it properly - which is why
	-- refusing costs nothing: the list is rewritten whole every time.
	COOLDOWN_UNSETTLED = false
	Family.Bags:Scan()

	local settled = Family.Database:Meta(key).itemCooldowns
	check("and the next scan records it, so a refusal costs one scan and not the fact",
		settled and #settled == 1 and settled[1].readyAt - time() <= 86400,
		settled and tostring(#settled) or "none")
end

itemCooldowns = Family.Database:Meta(key).itemCooldowns

local ready, nextReady = Family.Cooldowns:Summarise(Family.Database:Meta(key))
check("nothing is ready while both are still running", ready == 0, tostring(ready))
check("and the next one to come back is known", nextReady ~= nil)

-- Two days on, and the two part company - which is the whole point of them being two kinds.
--
-- Using a craft needs the profession window open and Family scans that window, so a transmute
-- still reading "ready" has genuinely not been used. Using an item needs nothing open at all,
-- so once the moment passes Family knows only that it was on cooldown the last time anybody
-- looked. That is not "waiting for you", and reporting it as such is a claim about a bag
-- nobody has seen for two days.
local realTime = time
time = function() return realTime() + 2 * 86400 end

ready = Family.Cooldowns:Summarise(Family.Database:Meta(key))
check("two days later the crafting cooldown is ready", ready == 1, tostring(ready))

local kinds = {}
for _, entry in ipairs(Family.Cooldowns:For(Family.Database:Meta(key))) do
	kinds[entry.kind] = (kinds[entry.kind] or 0) + 1
end
check("and the item's has stopped being a fact rather than become a ready one",
	kinds.item == nil, tostring(kinds.item))
check("while the crafting one is still there to be named", kinds.craft == 1,
	tostring(kinds.craft))

check("and the member is named as having something to do",
	#Family.Cooldowns:Ready() > 0)

-- Still counting down, it is a fact and it is kept: "ready in two hours" is knowable.
time = realTime
local running = 0
for _, entry in ipairs(Family.Cooldowns:For(Family.Database:Meta(key))) do
	if entry.kind == "item" then running = running + 1 end
end
check("an item cooldown still running is reported, because that much is known",
	running == 1, tostring(running))

print()
print("the mailbox")
check("nothing until a mailbox is opened", Family.Database:Meta(key).mailSeen == nil)

fire("MAIL_INBOX_UPDATE")
advance(1)
local mailMeta = Family.Database:Meta(key)
check("mail recorded", mailMeta.mailCount == 2, tostring(mailMeta.mailCount))

local letters = Family.Database:Payload(key).mail.letters
check("attachments kept by id", letters[1].attachments[1].id == 2589)
check("money in the mail kept", letters[2].money == 50000)
check("the soonest expiry reaches meta", mailMeta.mailExpiresBy ~= nil)

-- Half a day left when it was read; a day later it is gone, and so is what was attached.
local realTime = time
time = function() return realTime() + 86400 end
check("expired mail is not still reported",
	#(Family.Mail:Live(Family.Database:Payload(key).mail)) == 1)
check("and the time to expiry has run out", Family.Mail:TimeToExpiry(mailMeta) == 0)
time = realTime

print()
print("the bank")
check("a bank nobody opened is not reported as empty",
	Family.Database:Meta(key).bankSeen == nil)

fire("BANKFRAME_OPENED")
advance(1)
local bankMeta = Family.Database:Meta(key)
check("bank scanned when the window opens", bankMeta.bankSeen ~= nil)
check("bank slots counted across container and bank bags", bankMeta.bankSlots == 40,
	tostring(bankMeta.bankSlots))
-- Twenty-three of the twenty-four, one being occupied, and all sixteen of the bag. Not the
-- forty-four the client's own counts add up to, and not the thirty-six they used to give.
check("free bank slots counted", bankMeta.bankFree == 39, tostring(bankMeta.bankFree))


-- The invariant a live client broke: it reported 56 free of 52, which cannot be true of any
-- bank, because its own free count is computed from a bank four slots larger than the one it
-- has. Family derives the count instead, so the record cannot contradict itself.
check("a bank never has more free slots than it has slots",
	bankMeta.bankFree <= bankMeta.bankSlots,
	tostring(bankMeta.bankFree) .. " free of " .. tostring(bankMeta.bankSlots))

local bank = Family.Database:Payload(key).bank
check("bank contents kept by id", bank and bank.containers[-1].slots[1].id == 7909)

-- The client says twenty of those twenty-four are free while one of them holds something.
-- Believing it is what put "56 of 52 free" on somebody's screen; counting is what does not.
check("a container's free count is what was found, not what the client claims",
	bank and bank.containers[-1].free == 23,
	bank and tostring(bank.containers[-1].free))
local everySum = true
for _, entry in pairs((bank or {}).containers or {}) do
	local used = 0
	for _ in pairs(entry.slots) do used = used + 1 end
	if used + entry.free ~= entry.size then everySum = false end
end
check("and every container adds up: what is in it, plus what is free, is its size",
	everySum)

check("carried bags are not scanned again as bank bags",
	bank and bank.containers[1] == nil)

-- A scan with no bank window open, which is how a record was replaced by an empty one
--
-- Away from a bank the client still answers about the bank container - twenty-four slots, none
-- of them holding anything - so a scan there builds a well-formed record of a bank containing
-- nothing and writes it over whatever was there. One member went from five containers and
-- eighty-three items to one container and none that way (L-019). An empty bank with no bank
-- bags is indistinguishable from no bank at all, so the window being open is the only thing
-- that can tell them apart.
do
	local function containersNow()
		local held = Family.Database:Payload(key).bank
		local n = 0
		for _ in pairs((held or {}).containers or {}) do n = n + 1 end
		return n
	end

	local before = containersNow()
	check("the bank was recorded with more than the bank container", before > 1,
		tostring(before))

	-- The bank is gone from in front of us, and every bag on this character says so.
	local heldBags = BANK_BAGS[6]
	BANK_BAGS[6] = nil
	fire("BANKFRAME_CLOSED")
	advance(1)

	Family.Bank:Scan()
	check("a scan with no bank window open records nothing",
		containersNow() == before, tostring(containersNow()) .. " now")

	-- And a window that was opened and never announced as closed must not leave the door
	-- open for the rest of the session: everything that follows arrives in the world first.
	fire("BANKFRAME_OPENED")
	check("opening one says the window is open", Family.Bank:IsOpen() == true)
	fire("PLAYER_ENTERING_WORLD")
	check("and arriving in the world says it is not", Family.Bank:IsOpen() == false)

	Family.Bank:Scan()
	check("so a stale flag cannot let an empty record through either",
		containersNow() == before, tostring(containersNow()) .. " now")

	-- Being told the bank changed is not being told a bank is in front of you. These used to
	-- set the flag themselves, which gave it two ways to be set and one to be cleared.
	fire("PLAYERBANKSLOTS_CHANGED")
	advance(1)
	check("a bank slot changing with no window open does not open one",
		Family.Bank:IsOpen() == false)
	check("and records nothing", containersNow() == before,
		tostring(containersNow()) .. " now")

	BANK_BAGS[6] = heldBags
	fire("BANKFRAME_OPENED")
	advance(1)
end

-- Taking something out of the bank while the window is open changes the bank, and the game
-- announces that half as a bag update rather than as a bank event. Without this the bank
-- kept the photograph taken when the window opened, so the item tooltip counted the same
-- twelve twice: in the bags, where they now were, and in the bank, where they used to be.
BANK_BAGS[-1].items[1] = nil
BANK_BAGS[-1].free = 21
fire("BAG_UPDATE_DELAYED")
advance(1)

bank = Family.Database:Payload(key).bank
check("emptying a bank slot while the window is open is noticed",
	bank and bank.containers[-1].slots[1] == nil,
	bank and bank.containers[-1].slots[1] and tostring(bank.containers[-1].slots[1].id))
check("and the free count follows it", Family.Database:Meta(key).bankFree == 40,
	tostring(Family.Database:Meta(key).bankFree))

-- With the window shut there is nothing to read, and what was last seen has to survive
-- being asked about anyway.
fire("BANKFRAME_CLOSED")
BANK_BAGS[-1].items[1] = { 7909, 3 }
BANK_BAGS[-1].free = 20
fire("BAG_UPDATE_DELAYED")
advance(1)
check("a bag update with the bank shut does not touch the bank",
	Family.Database:Payload(key).bank.containers[-1].slots[1] == nil)

-- The guild bank, which nothing here had ever made run: this pretend client is Era, where
-- there is no guild bank at all, so every line of that scanner went untested.
do
	local realHas = Family.Capabilities.Has
	Family.Capabilities.Has = function(self, what)
		if what == "guildBank" then return true end
		return realHas(self, what)
	end

	local realInGuild, realGuildInfo = IsInGuild, GetGuildInfo
	IsInGuild = function() return true end
	GetNumGuildBankTabs = function() return 1 end
	GetGuildBankItemLink = function(tab, slot)
		if tab == 1 and slot == 1 then return "|Hitem:2589:0:0:0|h[Linen Cloth]|h" end
		-- Charged, and reached by link like everything else in here - which is exactly why
		-- the charge must not be read off the link.
		if tab == 1 and slot == 2 then return "|Hitem:20747:0:0:0|h[Lesser Mana Oil]|h" end
		-- 18149 is a Rune of Recall: charged, and an id nothing else in this run names, so
		-- the client genuinely does not know it yet. Once known, always known.
		if tab == 1 and slot == 3 then return "|Hitem:18149:0:0:0|h[Rune of Recall]|h" end
		return nil
	end
	GetGuildBankItemInfo = function(_, slot)
		if slot == 2 then return "Lesser Mana Oil", 1 end
		return "Linen Cloth", 20
	end

	-- The guild bank has its own setter, because a link carries no charges: reading one off
	-- the link would answer with the item's maximum and file a full oil for one with a single
	-- use left. The stub answers only for the right one, so using the wrong setter reads
	-- nothing at all.
	local aimedAt, everyAim = nil, {}
	function frameMethods:SetGuildBankItem(tab, slot)
		aimedAt = tostring(tab) .. ":" .. tostring(slot)
		everyAim[#everyAim + 1] = aimedAt
		wipe(self.__lines)
		local lines = (slot == 2) and { "Lesser Mana Oil", "3 Charges" }
			or (slot == 3) and { "Rune of Recall", "20 Charges" } or {}
		for index = 1, 12 do
			local text = lines[index]
			if text then table.insert(self.__lines, { text }) end
			_G[(self.__name or "?") .. "TextLeft" .. index] =
				text and { GetText = function() return text end } or nil
		end
	end

	FamilyDB.guilds = nil

	-- IsInGuild answers the moment the client loads and GetGuildInfo does not, so a
	-- character certainly in a guild can have no guild name for the first few seconds.
	-- Filing the tabs under a made-up name put a guild called "Unknown" into the index,
	-- the summary and every tooltip an item in it appeared on - and left it there after
	-- the real name arrived and the same tabs were filed again beside it.
	GetGuildInfo = function() return nil end
	Family.Bank:ScanGuildBank()
	check("a guild bank read before the guild has a name is not filed under one",
		FamilyDB.guilds == nil or next(FamilyDB.guilds) == nil)

	-- But not for ever. "Wait for it to arrive" is an unbounded loop when it never does, and
	-- a scanner waking up every three seconds until logout is worse than one that gave up.
	for _ = 1, 8 do advance(4) end
	local asked = 0
	local realAfter = Family.After
	Family.After = function(self, delay, what, fn)
		if what == "bank.guild.named" then asked = asked + 1 end
		return realAfter(self, delay, what, fn)
	end
	Family.Bank:ScanGuildBank()
	for _ = 1, 8 do advance(4) end
	Family.After = realAfter
	check("and it stops asking rather than waking up for ever", asked == 0,
		tostring(asked) .. " more asked")

	-- And it is asked for again rather than given up on, because the window is still open.
	Family.Bank.waitingForName = nil
	GetGuildInfo = function() return "Late Night Raiders", "Officer", 2 end
	Family.Bank:ScanGuildBank()
	advance(4)
	check("it is read again once the client will say which guild it is",
		FamilyDB.guilds ~= nil
			and FamilyDB.guilds["Late Night Raiders-Fire Maw"] ~= nil,
		FamilyDB.guilds and next(FamilyDB.guilds) or "nothing")

	local vault = FamilyDB.guilds and FamilyDB.guilds["Late Night Raiders-Fire Maw"]
	check("with what was in it, by id", vault and vault.tabs[1]
		and vault.tabs[1].slots[1] and vault.tabs[1].slots[1].id == 2589,
		vault and vault.tabs[1] and vault.tabs[1].slots[1]
			and tostring(vault.tabs[1].slots[1].id))

	-- And with how many charges are left on the one that has any.
	local oil = vault and vault.tabs[1] and vault.tabs[1].slots[2]
	check("and how many charges are left on a charged one", oil and oil.charges == 3,
		oil and tostring(oil.charges) or "no slot 2")

	-- Read through the guild bank's own setter, aimed at that tab and slot. A link cannot
	-- answer this: it describes the item, not the one in the vault.
	check("read through the guild bank's own setter, at that tab and slot",
		aimedAt == "1:2", tostring(aimedAt))

	-- An item the client has never heard of records nothing yet, and asks again when it does.
	-- The same wait as the bags, and it needs its own check: without one this scanner could
	-- stop waiting and every check here would stay green (L-030).
	check("an item the client does not know yet records no charges here either",
		vault and vault.tabs[1].slots[3] and vault.tabs[1].slots[3].charges == nil,
		vault and vault.tabs[1].slots[3] and tostring(vault.tabs[1].slots[3].charges)
			or "no slot 3")

	ITEM_NAMES[18149] = "Rune of Recall"
	fire("GET_ITEM_INFO_RECEIVED", 18149, true)
	advance(2)
	vault = FamilyDB.guilds and FamilyDB.guilds["Late Night Raiders-Fire Maw"]
	check("and the count arrives once the client answers about it",
		vault and vault.tabs[1].slots[3] and vault.tabs[1].slots[3].charges == 20,
		vault and vault.tabs[1].slots[3] and tostring(vault.tabs[1].slots[3].charges))
	ITEM_NAMES[18149] = nil

	-- The cloth is not charged, so it must not be tooltipped at all - the gate is what makes
	-- a hundred-slot tab affordable.
	-- Asked of what the setter was *aimed at*, not of what came back. A tab holds a hundred
	-- slots and the gate is what makes reading one affordable, so "the cloth has no charges"
	-- is not the claim - "the cloth was never tooltipped" is.
	local askedAboutCloth = false
	for _, at in ipairs(everyAim) do
		if at == "1:1" then askedAboutCloth = true end
	end
	check("and nothing that cannot carry charges is asked about at all",
		not askedAboutCloth, table.concat(everyAim, ", "))

	-- A character with no guild at all. Skillet fell over on exactly this - the guild bank
	-- frame announced itself and its guild name was nil - so it is worth knowing that
	-- Family walks away instead.
	IsInGuild = function() return false end
	local before = FamilyDB.guilds["Late Night Raiders-Fire Maw"].seen
	Family.Bank:ScanGuildBank()
	check("a character with no guild reads no guild bank and breaks nothing",
		FamilyDB.guilds["Late Night Raiders-Fire Maw"].seen == before)

	Family.Capabilities.Has = realHas
	IsInGuild, GetGuildInfo = realInGuild, realGuildInfo
	GetNumGuildBankTabs, GetGuildBankItemLink, GetGuildBankItemInfo = nil, nil, nil
	FamilyDB.guilds = nil
end

-- Put it back the way the rest of the checks expect to find it.
fire("BANKFRAME_OPENED")
advance(1)

print()
print("the quest log")
advance(5)

local log = Family.Database:Payload(key).quests
check("the quest log is read", log ~= nil and log.entries ~= nil)
check("a collapsed zone does not hide its quests",
	log and #log.entries == 3, log and tostring(#log.entries))
check("and is left collapsed afterwards, as it was found",
	QUEST_HEADERS[1].collapsed == true)
check("every quest knows which zone it is in",
	log and log.entries[1] and log.entries[1].category == "Elwynn Forest",
	log and log.entries[1] and tostring(log.entries[1].category))
check("a quest keeps its id, so the game can describe it later",
	log and log.entries[1] and log.entries[1].id == 84,
	log and log.entries[1] and tostring(log.entries[1].id))
check("objectives are counted, not just finished or not",
	log and log.entries[2] and log.entries[2].done == 0
		and log.entries[2].objectives == 1,
	log and log.entries[2] and tostring(log.entries[2].done))
check("a quest with no objectives says nothing rather than nought of nought",
	log and log.entries[3] and log.entries[3].objectives == nil)

local questMeta = Family.Database:Meta(key)
check("the count reaches meta, where a summary can read it",
	questMeta.questCount == 3, tostring(questMeta.questCount))
check("and so does what is ready to hand in", questMeta.questsComplete == 1,
	tostring(questMeta.questsComplete))
check("with the cap, so twenty of twenty-five means something",
	questMeta.questMax == 25, tostring(questMeta.questMax))

-- Scanning twice must produce the same log, not two of it.
Family.Quests:Scan()
check("a second scan does not double the log",
	#Family.Database:Payload(key).quests.entries == 3,
	tostring(#Family.Database:Payload(key).quests.entries))
;(function()
	-- Each objective as the client wrote it, which is the half a count cannot answer.
	--
	-- Reported from play 2026-09-05 with a screenshot: the Progress column said *2 sur 4* and the
	-- tooltip listed all four requirements with none of them marked. The client cannot answer this
	-- and it is §2.1 in reverse - a quest is described by id, and what comes back is the quest as
	-- it stands **for whoever is being played**, which on this panel is the wrong character on
	-- every row but one. So the per-character half is recorded here or it does not exist.
	local objectives = Family.Database:Payload(key).questObjectives
	check("the objectives are recorded, not only counted", objectives ~= nil)
	
	local linen = objectives and objectives["Red Linen Goods"]
	check("filed under the quest's title, which is what a row has in its hand",
		linen ~= nil)
	check("one entry for each objective rather than a total", linen and #linen == 2,
		linen and tostring(#linen))
	check("carrying the words the client used", linen and linen[1].text == "Red Linen Goods 1: 1/1",
		linen and tostring(linen[1].text))
	check("and which of them are finished", linen and linen[1].done == true,
		linen and tostring(linen[1].done))
	
	local hogger = objectives and objectives["Wanted: Hogger"]
	check("an unfinished objective is not marked finished",
		hogger and hogger[1] and hogger[1].done == nil,
		hogger and hogger[1] and tostring(hogger[1].done))
	
	-- The same rule the counting half already keeps: a delivery has nothing to be part-way
	-- through, and inventing an empty list for it would put a blank block under every such row.
	check("a quest with no objectives files none",
		objectives and objectives["The Killing Fields"] == nil)
	
	-- **And they do not cross a Wide Family link.** `Wide.lua` shares a payload key whole, so a
	-- field added inside `quests` would start travelling the moment it was written, without
	-- anybody deciding it should: these are bulky, they are in one client's language, and the
	-- channel is 200-byte chunks shared with every other addon the player runs. They live under a
	-- key no category lists, and this is what makes that the state of the code rather than a
	-- promise - the decision to share them would be an entry in CATEGORIES and a row of its own.
	do
		local held = FamilyDB.wide
		FamilyDB.wide = { enabled = true, id = "us", requests = {}, pendingOut = {},
			links = { ["objfam"] = { name = "Nosy-Thunderstrike",
				grants = { [key] = { quests = true } }, siblings = {}, members = {} } } }
	
		-- The link itself and not its id, and a map keyed by member rather than a list -
		-- read out of `Wide.lua` rather than assumed, because the first version of this
		-- guessed both and got two nils that looked exactly like the property holding.
		local offered = Family.Wide:Offering(FamilyDB.wide.links["objfam"])
		local sent = offered and offered[key]
	
		check("a member whose quests are granted does send the log", sent ~= nil
			and sent.payload ~= nil and sent.payload.quests ~= nil,
			tostring(sent and sent.payload))
		check("and never sends the objectives with it",
			sent and sent.payload and sent.payload.questObjectives == nil,
			tostring(sent and sent.payload and sent.payload.questObjectives))
	
		FamilyDB.wide = held
	end
end)()


print()
print("equipment, reputations and the spellbook")
advance(7)

local gear = Family.Database:Payload(key).equipment
check("equipment recorded", gear ~= nil and gear.worn[1] ~= nil)
check("an average item level is worked out", gear and gear.itemLevel == 115,
	gear and tostring(gear.itemLevel))
check("and reaches meta for the summary", Family.Database:Meta(key).itemLevel == 115)
-- 19 slots are worn, of which the shirt and the tabard do not count towards the average.
check("the shirt and tabard are recorded but not counted", gear and gear.counted == 17,
	gear and tostring(gear.counted))

local reps = Family.Database:Payload(key).reputations
check("reputations recorded", reps ~= nil and #reps == 2, reps and tostring(#reps))
check("a faction header is not a reputation", reps and reps[1].name == "Stormwind",
	reps and reps[1].name)
check("standing and progress kept", reps and reps[1].standing == 5
	and reps[1].value == 8000)
check("with the faction id where the client has one", reps and reps[1].id == 72)
check("and the faction list is put back as it was found", FACTIONS[1].collapsed == true)

-- The bug that ended as "script ran too long" on Burning Crusade. A loop that walks until
-- the client runs out of factions never ends on a client that answers for an index past the
-- end - so one is simulated here, and the scan has to finish anyway.
local honestFactionInfo = GetFactionInfo
GetFactionInfo = function(index)
	local answer = { honestFactionInfo(index) }
	if answer[1] == nil then
		-- Never runs out: keeps repeating the last header for ever.
		return "Alliance", "", 0, 0, 0, 0, false, false, true, false, false
	end
	return unpack(answer)
end

FACTIONS[1].collapsed = true
local finished = false
local timer = os.clock()
Family.Character:ReadReputations()
finished = (os.clock() - timer) < 2
check("a client that never runs out of factions does not hang the scan", finished)

GetFactionInfo = honestFactionInfo

-- The other half: expanding a header makes the game announce that factions changed, and
-- that announcement asks for a scan. Left alone it books the next one for ever.
local scansAsked = 0
local realAfter = Family.After
Family.After = function(self, delay, key, fn)
	if key == "character" then scansAsked = scansAsked + 1 end
	return realAfter(self, delay, key, fn)
end

-- The game announces a change the moment a header is opened, which is what the scan does to
-- read the list at all. Modelled here, because without it the loop is invisible.
local plainExpand = ExpandFactionHeader
ExpandFactionHeader = function(index)
	plainExpand(index)
	fire("UPDATE_FACTION")
end

FACTIONS[1].collapsed = true
Family.Character:Scan()

ExpandFactionHeader = plainExpand
Family.After = realAfter
check("a scan does not book another scan by scanning", scansAsked == 0,
	tostring(scansAsked) .. " asked")

-- And an announcement that did not come from the scan is still acted on.
scansAsked = 0
Family.After = function(self, delay, key, fn)
	if key == "character" then scansAsked = scansAsked + 1 end
	return realAfter(self, delay, key, fn)
end
fire("UPDATE_FACTION")
Family.After = realAfter
check("but a real change still books one", scansAsked == 1, tostring(scansAsked))

local book = Family.Database:Payload(key).spells
check("the spellbook is recorded by school", book ~= nil and #book == 2)
check("spells are kept as ids, never names", book and book[1].spells[1] == 501,
	book and tostring(book[1].spells[1]))

print()
print("auctions")
check("nothing until the auction house is visited",
	Family.Database:Meta(key).auctionsSeen == nil)

fire("AUCTION_OWNED_LIST_UPDATE")
advance(1)
local auctions = Family.Database:Payload(key).auctions
check("auctions recorded", auctions ~= nil and #auctions.selling == 2,
	auctions and tostring(#auctions.selling))
check("kept by item id", auctions and auctions.selling[1].id == 2841)
check("with the bid on it", auctions and auctions.selling[2].bid == 5000)

-- An auction is the one snapshot that expires on its own. The first has twelve hours left,
-- the second two days; a day later only the second can still be listed.
local realTime = time
time = function() return realTime() + 86400 end
local selling = Family.Auctions:Live(auctions)
check("an expired auction is not still reported", #selling == 1, tostring(#selling))
time = realTime
check("and it is back when the clock is", #(Family.Auctions:Live(auctions)) == 2)

-- Buying something out, which the server posts to you as mail
--
-- The same claim as a letter posted to an alt: something is on its way to this character that
-- is not in their bags yet. Asked for from play, on the observation that the two are the same
-- thing arriving by two routes.
--
-- The bid is remembered whatever kind it was and **nothing is written until the server says
-- the auction was won** - so a buyout somebody beat you to writes nothing at all, which is the
-- same guarantee MAIL_SEND_SUCCESS gives the outgoing side.
do
	local function lettersOf()
		local payload = Family.Database:Payload(key) or {}
		return (payload.mail or {}).letters or {}
	end

	local before = #lettersOf()
	local inPostBefore = Family.Mail:InPost(Family.Database:Meta(key))

	-- What the record held before this block, kept so it can be put back. The letters below
	-- carry an item the ownership checks further down count, and a fixture that leaves its
	-- own props on the stage makes the next section fail for a reason that is not its own.
	local heldLetters = {}
	for index, letter in ipairs(lettersOf()) do heldLetters[index] = letter end
	local heldMeta = Family.Database:Meta(key) or {}
	local heldCount, heldExpiry = heldMeta.mailCount, heldMeta.mailExpiresBy

	-- A bid the server never answers. Nothing may be recorded, however long anybody waits.
	Family.Auctions:NoteBid("list", 1)
	check("a bid nobody has answered records nothing", #lettersOf() == before,
		tostring(#lettersOf()))

	-- The outbid message carries a %s exactly as the won message does, and means the
	-- opposite. A pattern that could not tell them apart would file every lost auction as
	-- an item on its way.
	fire("CHAT_MSG_SYSTEM", "You were outbid on Linen Cloth.")
	check("and being outbid is not winning", #lettersOf() == before, tostring(#lettersOf()))

	-- "Bid accepted" is said for any bid at all, including one that won nothing.
	Family.Auctions:NoteBid("list", 1)
	fire("CHAT_MSG_SYSTEM", "Bid accepted.")
	check("nor is a bid merely being accepted", #lettersOf() == before, tostring(#lettersOf()))

	-- Won. Now it is a letter.
	Family.Auctions:NoteBid("list", 1)
	fire("CHAT_MSG_SYSTEM", "You won an auction for Linen Cloth")
	local letters = lettersOf()
	check("winning one puts a letter on the record", #letters == before + 1,
		tostring(#letters))

	local won = letters[#letters]
	check("with the item that was bought, by id",
		won and won.attachments and won.attachments[1]
			and won.attachments[1].id == 2589,
		won and won.attachments and won.attachments[1]
			and tostring(won.attachments[1].id))
	check("and the stack size that was on the auction",
		won and won.attachments[1].count == 4,
		won and tostring(won.attachments[1].count))
	check("marked as being in the post, not as seen in a mailbox",
		won and won.inPost == true, tostring(won and won.inPost))
	check("and the in-post count follows it",
		Family.Mail:InPost(Family.Database:Meta(key)) == inPostBefore + 1,
		tostring(Family.Mail:InPost(Family.Database:Meta(key))))

	-- A win with no bid behind it - somebody else's auction closing while the player stands
	-- there - has no item to record and must invent none.
	local after = #lettersOf()
	fire("CHAT_MSG_SYSTEM", "You won an auction for Linen Cloth")
	check("a win with no bid behind it records nothing", #lettersOf() == after,
		tostring(#lettersOf()))

	-- And a bid the confirmation arrives far too late for belongs to whatever the player has
	-- done since, not to this.
	Family.Auctions:NoteBid("list", 1)
	local held = time
	time = function() return held() + 600 end
	fire("CHAT_MSG_SYSTEM", "You won an auction for Linen Cloth")
	time = held
	check("nor does a confirmation that arrives ten minutes late",
		#lettersOf() == after, tostring(#lettersOf()))

	-- Only the browse list. A bid placed from the owner or bidder lists is not a purchase,
	-- and the client answers with a link for those lists too - so this is the scanner's own
	-- decision and not something the absence of data makes for it.
	check("a bid outside the browse list is not remembered",
		Family.Auctions:NoteBid("owner", 1) == nil)

	-- The whole message, not a phrase inside one. Anything that reaches CHAT_MSG_SYSTEM
	-- carrying the won sentence within a longer line is not the server saying you won, and
	-- an unanchored pattern would take it for one. Synthetic, and here because the anchor
	-- was unexercised until it existed.
	Family.Auctions:NoteBid("list", 1)
	fire("CHAT_MSG_SYSTEM", "[Someone]: You won an auction for Linen Cloth, lucky you")
	check("and a sentence quoted inside a longer line is not the server speaking",
		#lettersOf() == after, tostring(#lettersOf()))

	local payload = Family.Database:Payload(key) or {}
	payload.mail = payload.mail or {}
	payload.mail.letters = heldLetters
	Family.Database:SetPayload(key, payload)
	Family.Database:SetMeta(key, {
		mailCount = heldCount or Family.CLEAR,
		mailInPost = inPostBefore > 0 and inPostBefore or Family.CLEAR,
		mailExpiresBy = heldExpiry or Family.CLEAR,
	})
	Family.Index:Invalidate(key)
end

print()
print("who owns what")

-- Linen Cloth is in the backpack (20) and attached to a letter (20). The letter has half a
-- day left, so both count for now.
local owners, guilds = Family.Index:Owners(2589)
check("the index finds an owner", #owners == 1, tostring(#owners))
check("counting bags and mail separately",
	owners[1] and owners[1].bags == 20 and owners[1].mail == 20,
	owners[1] and (owners[1].bags .. "/" .. owners[1].mail))
check("and totalling them", owners[1] and owners[1].total == 40,
	owners[1] and tostring(owners[1].total))
check("an item nobody has answers empty", #(Family.Index:Owners(999111)) == 0)

-- The index is derived, so a scan has to move it. Nothing else may need telling.
BAGS[0].items[3] = { 2589, 5 }
Family.Bags:Scan()
local after = Family.Index:Owners(2589)
check("a scan moves the index without anyone asking it to",
	after[1] and after[1].bags == 25, after[1] and tostring(after[1].bags))

-- What has expired is not owned. A day on, the letter is gone and so are its twenty.
local realTime = time
time = function() return realTime() + 86400 end
Family.Index:Invalidate()
local later = Family.Index:Owners(2589)
check("an expired letter stops counting",
	later[1] and later[1].mail == 0, later[1] and tostring(later[1].mail))
time = realTime
Family.Index:Invalidate()

print()
print("the possessions block on a game tooltip")

local function tooltipFor(itemID, viaData)
	wipe(GameTooltip.__lines)
	GameTooltip.__itemName = "Something"
	GameTooltip.__itemLink = "|Hitem:" .. itemID .. "|h"

	-- OnTooltipCleared is what resets the "already described this" guard, exactly as the
	-- game fires it between tooltips.
	if GameTooltip.__scripts.OnTooltipCleared then
		GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
	end

	if viaData then
		-- The newer route hands the item over in data and leaves the tooltip itself
		-- saying nothing, which is how the block went missing on Mists.
		GameTooltip.__itemLink = nil
		Family.UI.__modernCallback(GameTooltip, { id = itemID })
	else
		GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)
	end

	local found
	for _, line in ipairs(GameTooltip.__lines) do
		if type(line[1]) == "string" and line[1]:find("Family possessions") then
			found = true
		end
	end
	return found and true or false, #GameTooltip.__lines
end

check("an item somebody owns gets a possessions block", tooltipFor(2589) == true)

-- A thing made by using an item rather than by a recipe
--
-- Refined Deeprock Salt (15409) is on nobody's recipe list. It comes out of a Salt Shaker
-- (15846), an item with a four-day cooldown - so the question "who can make me one" is really
-- "who owns a shaker, and is theirs ready". Reported from play: the salt's tooltip said who
-- had some and nothing about who could make more.
do
	local function textOf()
		local lines = {}
		for _, line in ipairs(GameTooltip.__lines) do
			lines[#lines + 1] = tostring(line[1]) .. "  " .. tostring(line[2])
		end
		return table.concat(lines, "\n")
	end

	local made = (Family.MadeByItem or {})[15409]
	check("the generated table knows what makes the salt",
		made and made[1] and made[1].item == 15846,
		tostring(made and made[1] and made[1].item))

	-- Owning the shaker is not using it: it asks 250 leatherworking of whoever picks it up,
	-- and the client's own table says so.
	check("and what the shaker asks of whoever holds it",
		made and made[1] and made[1].skill == 165 and made[1].rank == 250,
		tostring(made and made[1] and made[1].skill))

	-- Nobody owns a shaker yet, so there is nothing to say and nothing is said.
	tooltipFor(15409)
	check("with nobody holding the shaker, the salt says nothing about making it",
		textOf():find("Can make it", 1, true) == nil, textOf())

	Family.Database:SetMeta("Salter-FireMaw", { name = "Salter", realm = "Fire Maw",
		level = 60, classFile = "SHAMAN",
		skills = { [165] = { rank = 300, maxRank = 300 } } })
	Family.Database:SetPayload("Salter-FireMaw", { bags = {
		{ slots = { { id = 15846, count = 1 } } } } })
	Family.Index:Invalidate("Salter-FireMaw")

	tooltipFor(15409)
	check("the owner of the shaker is who can make the salt",
		textOf():find("Salter", 1, true) ~= nil, textOf())
	check("and the block says so in as many words",
		textOf():find("Can make it", 1, true) ~= nil, textOf())
	check("and theirs is ready, having never been seen counting down",
		textOf():find("ready now", 1, true) ~= nil, textOf())

    -- And when it is counting down, the tooltip says when rather than saying ready.
	Family.Database:SetMeta("Salter-FireMaw",
		{ itemCooldowns = { { id = 15846, readyAt = time() + 86400 } } })
	tooltipFor(15409)
	check("a shaker on cooldown is not reported as ready",
		textOf():find("ready now", 1, true) == nil, textOf())
	check("and the owner is still named, because they are still who to ask",
		textOf():find("Salter", 1, true) ~= nil, textOf())

	-- A second owner who has the shaker and cannot use it. Reported from play, and the whole
	-- reason the table carries the requirement rather than only the join.
	Family.Database:SetMeta("Novice-FireMaw", { name = "Novice", realm = "Fire Maw",
		level = 60, classFile = "MAGE",
		skills = { [165] = { rank = 200, maxRank = 300 } } })
	Family.Database:SetPayload("Novice-FireMaw", { bags = {
		{ slots = { { id = 15846, count = 1 } } } } })
	Family.Index:Invalidate("Novice-FireMaw")

	tooltipFor(15409)
	check("an owner without the skill to use it is not named",
		textOf():find("Novice", 1, true) == nil, textOf())

	-- And one whose professions nobody has read is not claimed for either way.
	Family.Database:SetMeta("Unread-FireMaw", { name = "Unread", realm = "Fire Maw",
		level = 60, classFile = "ROGUE" })
	Family.Database:SetPayload("Unread-FireMaw", { bags = {
		{ slots = { { id = 15846, count = 1 } } } } })
	Family.Index:Invalidate("Unread-FireMaw")

	tooltipFor(15409)
	check("nor is one whose professions have never been read",
		textOf():find("Unread", 1, true) == nil, textOf())

	-- And a linked family's character who owns one and can use it.
	--
	-- `Index:Owners` answers with borrowed keys as well as our own, and this block asked
	-- `Family.Database:Meta` about every one of them - which the database has never heard of
	-- for a borrowed key, so a sibling came back with no professions and was dropped by the
	-- rank test. That reads exactly like the deliberate case two checks up, where somebody
	-- whose profession has never been read is left out on purpose: a right answer for the
	-- wrong reason, and the one shape of fault this file exists to refuse.
	do
		local held = FamilyDB.wide
		FamilyDB.wide = {
			enabled = true, id = "us", requests = {}, pendingOut = {},
			links = { ["saltfam"] = { name = "Brine-Thunderstrike", grants = {},
				siblings = {},
				members = {
					["Brine-Thunderstrike"] = {
						meta = { name = "Brine", realm = "Thunderstrike",
							classFile = "SHAMAN", level = 60, faction = "Alliance",
							skills = { [165] = { rank = 300, maxRank = 300 } } },
						payload = { bags = {
							{ slots = { { id = 15846, count = 1 } } } } },
						seen = time(),
					},
				} } },
		}
		Family.Wide:SetSibling("saltfam", "Brine-Thunderstrike", true)
		Family.Index:Invalidate()

		tooltipFor(15409)
		check("a linked family's owner who can use it is named too",
			textOf():find("Brine", 1, true) ~= nil, textOf())

		Family.Wide:SetSibling("saltfam", "Brine-Thunderstrike", false)
		FamilyDB.wide = held
		Family.Index:Invalidate()
	end

	Family.Database:Forget("Novice-FireMaw")
	Family.Database:Forget("Unread-FireMaw")

	-- Two trades that make the same thing, and one character with both
	--
	-- A Truesilver Bar is smelted by a miner and transmuted by an alchemist. A character with
	-- both matched once per profession, so the count said two where there was one person, and
	-- the block - which shows five names and then says how many more - gave a visible place to
	-- a duplicate. Reported from play as alchemists missing from a list with room for them.
	--
	-- 6037 is the bar, 164 is Blacksmithing standing in for a second trade that makes it.
	Family.Database:SetMeta("Twofold-FireMaw", { name = "Twofold", realm = "Fire Maw",
		level = 60, skills = { [171] = { rank = 300 }, [164] = { rank = 225 } } })
	Family.Database:SetPayload("Twofold-FireMaw", { professions = {
		[171] = { recipesSeen = time(), recipes = {
			{ name = "Transmute Truesilver", itemID = 6037, hasCooldown = true,
				readyAt = time() + 3600 } } },
		[164] = { recipesSeen = time(), recipes = {
			{ name = "Smelt Truesilver", itemID = 6037 } } },
	} })

	local knowers = Family.Recipes:KnowersOf(nil, 6037, "Truesilver Bar")
	local mine = 0
	for _, who in ipairs(knowers) do
		if who.key == "Twofold-FireMaw" then mine = mine + 1 end
	end
	check("a character who can make it two ways is one line, not two", mine == 1,
		tostring(mine))

	-- And the line kept is the one that says more: a timer beats a rank, because "ready in an
	-- hour" is the answer somebody wants and "smelts it, 225" is true and says less.
	local kept
	for _, who in ipairs(knowers) do
		if who.key == "Twofold-FireMaw" then kept = who end
	end
	check("and it is the one carrying the cooldown",
		kept and kept.cooldown ~= nil and kept.cooldown.ready == false,
		tostring(kept and kept.cooldown))
	check("with the rank of the trade that has it",
		kept and kept.rank == 300, tostring(kept and kept.rank))

	-- Neither trade on a timer, so the rank decides. Without this the tiebreak was
	-- unexercised: every fixture above had a cooldown on one side, so "keep the higher rank"
	-- could be deleted entirely and nothing failed.
	Family.Database:SetMeta("Plainly-FireMaw", { name = "Plainly", realm = "Fire Maw",
		level = 60, skills = { [171] = { rank = 120 }, [164] = { rank = 290 } } })
	Family.Database:SetPayload("Plainly-FireMaw", { professions = {
		[171] = { recipesSeen = time(), recipes = { { name = "A", itemID = 6037 } } },
		[164] = { recipesSeen = time(), recipes = { { name = "B", itemID = 6037 } } },
	} })

	local plain
	for _, who in ipairs(Family.Recipes:KnowersOf(nil, 6037, "Truesilver Bar")) do
		if who.key == "Plainly-FireMaw" then plain = who end
	end
	check("with neither on a timer, the higher rank is the line kept",
		plain and plain.rank == 290, tostring(plain and plain.rank))

	Family.Database:Forget("Plainly-FireMaw")
	Family.Database:Forget("Twofold-FireMaw")

	-- The shaker itself is unaffected: it is not made by anything.
	tooltipFor(15846)
	check("the maker itself gets no such block",
		textOf():find("Can make it", 1, true) == nil, textOf())

	Family.Database:Forget("Salter-FireMaw")
end

-- The total leads, in gold, with where they are behind it: "37 (17 bags, 20 bank)".
local ownedLine
for _, line in ipairs(GameTooltip.__lines) do
	if type(line[2]) == "string" and line[2]:find("bags", 1, true) then ownedLine = line[2] end
end
check("and each owner's line totals what they have before breaking it down",
	ownedLine and ownedLine:find("|cffffd700", 1, true) == 1
		and ownedLine:find("(", 1, true) ~= nil, tostring(ownedLine))
check("an item nobody owns gets nothing at all", tooltipFor(999111) == false)

print()
print("the crafters block on a recipe tooltip")

-- Three members with blacksmithing and one without, so the block has all four answers to
-- give at once. Tester knows Runed Copper Breastplate already (it is in the recipes read from the
-- open window above); the others differ in what they have been seen to know.
Family.Database:SetMeta("Novice-FireMaw", { name = "Novice", realm = "Fire Maw", level = 60,
	classFile = "WARRIOR", skills = { [164] = { name = "Blacksmithing", rank = 40, maxRank = 75 } } })
Family.Database:SetPayload("Novice-FireMaw", { professions = { [164] = {
	rank = 40, maxRank = 75, recipes = {} } } })

Family.Database:SetMeta("Ready-FireMaw", { name = "Ready", realm = "Fire Maw", level = 60,
	classFile = "MAGE", skills = { [164] = { name = "Blacksmithing", rank = 300, maxRank = 300 } } })
Family.Database:SetPayload("Ready-FireMaw", { professions = { [164] = {
	rank = 300, maxRank = 300, recipes = {} } } })

Family.Database:SetMeta("Unseen-FireMaw", { name = "Unseen", realm = "Fire Maw", level = 60,
	classFile = "PRIEST", skills = { [164] = { name = "Blacksmithing", rank = 300, maxRank = 300 } } })

Family.Database:SetMeta("Young-FireMaw", { name = "Young", realm = "Fire Maw", level = 5,
	classFile = "ROGUE", skills = { [164] = { name = "Blacksmithing", rank = 300, maxRank = 300 } } })
Family.Database:SetPayload("Young-FireMaw", { professions = { [164] = {
	rank = 300, maxRank = 300, recipes = {} } } })

-- What the crafters block said, as a name -> status list.
local function craftersFor(itemID, skillLine)
	wipe(GameTooltip.__lines)
	GameTooltip.__itemName = RECIPE_ITEMS[itemID] and RECIPE_ITEMS[itemID].name or "Thing"
	GameTooltip.__itemLink = "|Hitem:" .. itemID .. "|h"

	if GameTooltip.__scripts.OnTooltipCleared then
		GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
	end

	-- The line the game itself writes, which is the only place the skill a recipe needs is
	-- ever stated. Written before the hook runs, exactly as the client does it.
	if skillLine then GameTooltip:AddLine(skillLine) end

	GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

	local found, heading = {}, false
	for _, line in ipairs(GameTooltip.__lines) do
		if type(line[1]) == "string" and line[1]:find("Family crafters", 1, true) then
			heading = true
		elseif heading and type(line[1]) == "string" and line[2] then
			found[line[1]:match("^(%a+)") or "?"] = line[2]
		end
	end
	return found, heading
end

-- Somebody whose record of the same recipe carries no id for what it makes, which is the
-- ordinary Classic Era shape and the one case where the two blocks could both fire: the
-- pattern's own name teaches the recipe's, so "who can make one" would answer on the book.
Family.Database:SetMeta("Formulaic-FireMaw", { name = "Formulaic", realm = "Fire Maw",
	level = 60, skills = { [164] = { rank = 275, maxRank = 300 } } })
Family.Database:SetPayload("Formulaic-FireMaw", { professions = { [164] = {
	rank = 275, maxRank = 300, recipesSeen = time(),
	recipes = { { name = "Runed Copper Breastplate", spellID = 2667 } } } } })

local crafters, heading = craftersFor(2881, "Requires Blacksmithing (100)")
check("a recipe gets a crafters block", heading == true)

-- And only that one. A profession window lists the crafting spells a character has learnt; a
-- pattern is the book that teaches one. Hovering the plans asks who knows the recipe, hovering
-- what the plans make asks who can make another, and answering both on the book is Family
-- answering a question nobody put.
do
	local madeBy = false
	for _, line in ipairs(GameTooltip.__lines) do
		if type(line[1]) == "string" and line[1]:find("Can make it", 1, true) then
			madeBy = true
		end
	end
	check("and not the block about making the thing it teaches", not madeBy)
end

-- And whoever in the guild already knows it.
--
-- A guildmate's shared list *is* the list of recipes they know, so a pattern one of them is
-- holding is a pattern you may not need to buy. Found by name, because a formula's own id has
-- nothing to do with the id of what it teaches - and both sides of that comparison are worked
-- out here, from the ids that crossed.
do
	local wasOn = Family.Guild:Enabled()
	Family.Guild:SetEnabled(true)

	local guildKey = Family.Guild:Current()
	-- Switching it on has already built the tables; this is the panel being checked, not
	-- the protocol, so the state is written rather than exchanged for.
	local store = FamilyDB.guild

	store.known[guildKey] = store.known[guildKey] or {}
	store.known[guildKey]["Faraway-FireMaw"] = {
		meta = { name = "Faraway", realm = "Fire Maw" }, from = "Faraway", at = time(),
		professions = { { skillLine = 164, rank = 300, maxRank = 300 } },
	}
	-- Two entries, one of each shape, because a client gives one or the other and which it
	-- is differs by client and by window (DATASOURCES §2). The first is named by its spell,
	-- the second only by the thing it makes - which is every trade skill record on Era, and
	-- the shape a fixture with spells in it cannot test.
	RECIPE_ITEMS[7191] = { name = "Runed Copper Breastplate", profession = "Blacksmithing",
		class = 4, minLevel = 10 }

	store.recipes[guildKey] = { ["Faraway-FireMaw"] = { [164] = {
		spells = { 0 }, items = { 7191 }, missing = 0, fingerprint = 1,
		at = time(), from = "Faraway" } } }

	craftersFor(2881, "Requires Blacksmithing (100)")

	local guilded = false
	for _, line in ipairs(GameTooltip.__lines) do
		if type(line[1]) == "string" and line[1]:find("(guild)", 1, true) then
			guilded = true
		end
	end
	check("a guildmate who already knows the pattern is named on it", guilded)

	store.known[guildKey]["Faraway-FireMaw"] = nil
	store.recipes[guildKey] = nil
	Family.Guild:SetEnabled(wasOn)
end

-- And by the ids the pattern resolves to, where no name can answer.
--
-- The block above finds the guildmate by name, and that is the lane that fails for exactly
-- the recipes the family's own half used to fail on: a client abbreviates a recipe's name,
-- so the pattern's name is not the tail of it and the suffix test says no. The pattern's own
-- id is not the recipe's, but it resolves to both of the ids a guild list can hold - the
-- spell it teaches and the item that spell makes - and neither of those is a word.
do
	local wasOn = Family.Guild:Enabled()
	Family.Guild:SetEnabled(true)

	local guildKey = Family.Guild:Current()
	local store = FamilyDB.guild

	store.known[guildKey] = store.known[guildKey] or {}
	store.known[guildKey]["Faraway-FireMaw"] = {
		meta = { name = "Faraway", realm = "Fire Maw" }, from = "Faraway", at = time(),
		professions = { { skillLine = 164, rank = 300, maxRank = 300 } },
	}

	local function guilded()
		craftersFor(2881, "Requires Blacksmithing (100)")
		for _, line in ipairs(GameTooltip.__lines) do
			if type(line[1]) == "string" and line[1]:find("(guild)", 1, true) then
				return true
			end
		end
		return false
	end

	-- What the plans make, and a client that abbreviates it. 2881 teaches 2667, which makes
	-- 2864 - and this client's word for 2864 is not the tail of the pattern's name, so the
	-- name lane is answering no while the id lane answers yes.
	ITEM_NAMES[2864] = "Plast. en cuivre grav."

	store.recipes[guildKey] = { ["Faraway-FireMaw"] = { [164] = {
		spells = { 0 }, items = { 2864 }, missing = 0, fingerprint = 2,
		at = time(), from = "Faraway" } } }

	check("a guildmate whose list holds what the pattern makes is named on it", guilded())

	-- And the other shape, which is what an enchanting list crosses as: the spell and no
	-- item at all. The client's word for it is abbreviated too, for the same reason.
	local realName = SPELL_NAMES[2667]
	SPELL_NAMES[2667] = "Plast. en cuivre grav."

	store.recipes[guildKey] = { ["Faraway-FireMaw"] = { [164] = {
		spells = { 2667 }, items = { 0 }, missing = 0, fingerprint = 3,
		at = time(), from = "Faraway" } } }

	check("and one whose list holds the spell it teaches is named on it too", guilded())

	-- And a guildmate holding something else is not named, or the two lanes above would be
	-- a block that answers yes to everything.
	store.recipes[guildKey] = { ["Faraway-FireMaw"] = { [164] = {
		spells = { 0 }, items = { 2851 }, missing = 0, fingerprint = 4,
		at = time(), from = "Faraway" } } }

	check("and one holding something else is not", guilded() == false)

	SPELL_NAMES[2667] = realName
	ITEM_NAMES[2864] = nil
	store.known[guildKey]["Faraway-FireMaw"] = nil
	store.recipes[guildKey] = nil
	Family.Guild:SetEnabled(wasOn)
end
check("the member who knows it says so", crafters.Tester
	and crafters.Tester:find("knows it", 1, true) ~= nil, tostring(crafters.Tester))
check("one with the skill, the level and a list it is not on can learn it",
	crafters.Ready and crafters.Ready:find("can learn it", 1, true) ~= nil,
	tostring(crafters.Ready))
check("one whose skill is too low is shown how far off it is", crafters.Novice
	and crafters.Novice:find("40", 1, true) ~= nil, tostring(crafters.Novice))
check("one whose profession has never been opened is not told it can learn it",
	crafters.Unseen and crafters.Unseen:find("may know it", 1, true) ~= nil,
	tostring(crafters.Unseen))
check("and one too low a level to use it is told which level",
	crafters.Young and crafters.Young:find("level", 1, true) ~= nil,
	tostring(crafters.Young))
check("a member without the profession is left out entirely",
	crafters.Other == nil, tostring(crafters.Other))

-- An enchanter who already knows the formula
--
-- The crafters block decided "already knows it" by matching the item's name against the names
-- in a member's recipe list. Enchanting never agrees with itself there: the trade skill window
-- abbreviates. A French client lists "Ench. de bottes (Agilite superieure)" and names the
-- formula "Formule : Enchantement de bottes (Agilite superieure)", so the suffix test failed
-- and an enchanter who had known the recipe for a year was offered it as one to learn.
-- Reported from play, with the debug output showing all 132 enchanting recipes carrying a
-- spell id and no item id at all.
--
-- 16245 is Formula: Enchant Boots - Greater Agility and it teaches spell 20023.
;(function()
	local FORMULA, TAUGHT = 16245, 20023

	check("the generated table knows what the formula teaches",
		Family.Recipes:TaughtBy(FORMULA) == TAUGHT,
		tostring(Family.Recipes:TaughtBy(FORMULA)))

	Family.Database:SetMeta("Enchantress-FireMaw", { name = "Enchantress", realm = "Fire Maw",
		level = 60, skills = { [333] = { rank = 300, maxRank = 300 } } })
	Family.Database:SetPayload("Enchantress-FireMaw", { professions = { [333] = {
		rank = 300, maxRank = 300, recipesSeen = time(),
		-- Recorded exactly as the window hands it over: abbreviated, in another language,
		-- and with no item id at all. Every one of those is why the name test cannot work.
		recipes = { { name = "Ench. de bottes (Agilite superieure)", spellID = TAUGHT } } } } })

	local by = {}
	for _, who in ipairs(Family.Recipes:Crafters("Enchanting", "Formula: Enchant Boots - "
		.. "Greater Agility", nil, nil, FORMULA)) do
		by[who.name] = who
	end

	check("an enchanter who knows it is not offered it",
		by.Enchantress and by.Enchantress.state == "knows",
		tostring(by.Enchantress and by.Enchantress.state))

	-- And one who does not know it still reads as able to learn it, or the fix would be a
	-- claim that everybody knows everything.
	Family.Database:SetPayload("Enchantress-FireMaw", { professions = { [333] = {
		rank = 300, maxRank = 300, recipesSeen = time(),
		recipes = { { name = "Ench. d'arme (Agilite)", spellID = 23800 } } } } })

	local without = {}
	for _, who in ipairs(Family.Recipes:Crafters("Enchanting", "Formula: Enchant Boots - "
		.. "Greater Agility", nil, nil, FORMULA)) do
		without[who.name] = who
	end
	check("and one who does not still reads as able to learn it",
		without.Enchantress and without.Enchantress.state == "can",
		tostring(without.Enchantress and without.Enchantress.state))

	-- Per expansion, because the builds disagree about a few items: 23133 teaches 28903 on
	-- Mists and 28906 on Burning Crusade, and Era has never heard of it. Without a pair like this the per-expansion lookup could
	-- be pointed at any one table and nothing would fail - most items teach the same spell
	-- everywhere, so the ones that do not are the only fixtures worth having.
	do
		local held = Family.Capabilities.expansion
		Family.Capabilities.expansion = 2
		local onTBC = Family.Recipes:TaughtBy(23133)
		Family.Capabilities.expansion = 5
		local onMists = Family.Recipes:TaughtBy(23133)
		Family.Capabilities.expansion = held

		check("an item the builds disagree about is answered per build",
			onTBC ~= nil and onMists ~= nil and onTBC ~= onMists,
			tostring(onTBC) .. " vs " .. tostring(onMists))
	end

	-- And the block on the crafted thing resolves it too: given the item and no spell, the
	-- table supplies the spell, which is what "who can make one of these" is matched on.
	Family.Database:SetPayload("Enchantress-FireMaw", { professions = { [333] = {
		rank = 300, maxRank = 300, recipesSeen = time(),
		recipes = { { name = "Ench. de bottes (Agilite superieure)", spellID = TAUGHT } } } } })

	local found = false
	for _, who in ipairs(Family.Recipes:KnowersOf(nil, FORMULA, nil)) do
		if who.key == "Enchantress-FireMaw" then found = true end
	end
	check("and asking by item alone finds who knows the spell it teaches", found)

	Family.Database:Forget("Enchantress-FireMaw")
end)()

-- A smith whose record carries only the thing the recipe makes
--
-- The lane above is the one enchanting needs, and it is the smaller of the two. Every other
-- profession on Classic Era has the opposite shape: measured with a leatherworking window
-- open on 1.15.9, an item id on every recipe and a spell id on none (DATASOURCES §2). So the
-- spell the plans teach is on one side of the comparison and nothing at all is on the other,
-- and the id the two do share is the item the recipe makes.
--
-- 2881 is Plans: Runed Copper Breastplate, which teaches 2667, which makes 2864.
;(function()
	local PLANS, MADE = 2881, 2864

	check("the generated table knows what the plans make",
		Family.Recipes:Makes(PLANS) == MADE, tostring(Family.Recipes:Makes(PLANS)))

	-- Recorded the way an Era window hands it over - no spell - and under a name that shares
	-- not one letter with the item under the cursor, so nothing but the id can answer.
	Family.Database:SetMeta("Smithy-FireMaw", { name = "Smithy", realm = "Fire Maw",
		level = 60, skills = { [164] = { rank = 300, maxRank = 300 } } })
	Family.Database:SetPayload("Smithy-FireMaw", { professions = { [164] = {
		rank = 300, maxRank = 300, recipesSeen = time(),
		recipes = { { name = "Plastron en cuivre grav\195\169", itemID = MADE } } } } })

	local by = {}
	for _, who in ipairs(Family.Recipes:Crafters("Blacksmithing",
		"Plans: Runed Copper Breastplate", nil, nil, PLANS)) do
		by[who.name] = who
	end

	check("a smith whose record holds only what it makes is not offered it",
		by.Smithy and by.Smithy.state == "knows",
		tostring(by.Smithy and by.Smithy.state))

	-- And one holding a different product still reads as able to learn it, or the lane would
	-- be an assertion that everybody knows everything rather than a match.
	Family.Database:SetPayload("Smithy-FireMaw", { professions = { [164] = {
		rank = 300, maxRank = 300, recipesSeen = time(),
		recipes = { { name = "Ceinture en cuivre", itemID = 2851 } } } } })

	local without = {}
	for _, who in ipairs(Family.Recipes:Crafters("Blacksmithing",
		"Plans: Runed Copper Breastplate", nil, nil, PLANS)) do
		without[who.name] = who
	end

	check("and one holding a different product still reads as able to learn it",
		without.Smithy and without.Smithy.state == "can",
		tostring(without.Smithy and without.Smithy.state))

	-- Per expansion, exactly as the spell lane is, and pointed at the pair that disagrees:
	-- 23133 teaches 28903 on Mists and 28906 on Burning Crusade, so what it makes differs
	-- too. Without a fixture like this the lookup could read any one build's table and
	-- nothing here would notice.
	do
		local held = Family.Capabilities.expansion
		Family.Capabilities.expansion = 2
		local onTBC = Family.Recipes:Makes(23133)
		Family.Capabilities.expansion = 5
		local onMists = Family.Recipes:Makes(23133)
		Family.Capabilities.expansion = held

		check("and what an item makes is answered per build too",
			onTBC ~= nil and onMists ~= nil and onTBC ~= onMists,
			tostring(onTBC) .. " vs " .. tostring(onMists))
	end

	Family.Database:Forget("Smithy-FireMaw")
end)()

-- The branch a recipe belongs to, and the members who took a different one
--
-- A blacksmith is an armoursmith or a weaponsmith and cannot be both. Recipes belonging to one
-- branch can never be learnt by anybody on the other, however much skill they gain - so
-- "can learn it" was a false claim about most of the family for 239 recipe items across the
-- three builds, and no amount of levelling would have made it true.
--
-- Item 11612 needs Armorsmith (9788), taken from ItemSparse.RequiredAbility (DATASOURCES §2).
;(function()
	local ARMOURSMITH, WEAPONSMITH, GATED = 9788, 9787, 11612

	check("the generated table knows what the gated item needs",
		(Family.RecipeNeeds or {})[GATED] == ARMOURSMITH,
		tostring((Family.RecipeNeeds or {})[GATED]))
	check("and which profession that branch belongs to",
		(Family.Specialisations or {})[ARMOURSMITH] == 164,
		tostring((Family.Specialisations or {})[ARMOURSMITH]))

	local function smith(key, name, fields)
		local meta = { name = name, realm = "Fire Maw", level = 60,
			skills = { [164] = { rank = 300, maxRank = 300 } } }
		for field, value in pairs(fields) do meta[field] = value end
		Family.Database:SetMeta(key, meta)
		Family.Database:SetPayload(key, { professions = { [164] = {
			rank = 300, maxRank = 300, recipesSeen = time(), recipes = {} } } })
	end

	smith("Plated-FireMaw", "Plated", { specs = { ARMOURSMITH }, specsSeen = time() })
	smith("Bladed-FireMaw", "Bladed", { specs = { WEAPONSMITH }, specsSeen = time() })
	smith("Neither-FireMaw", "Neither", { specsSeen = time() })
	smith("Older-FireMaw", "Older", {})

	local function states(itemID)
		local by = {}
		for _, who in ipairs(Family.Recipes:Crafters("Blacksmithing", "Dark Iron Plate",
			nil, nil, itemID)) do
			by[who.name] = who
		end
		return by
	end

	local gated = states(GATED)

	check("the member on the branch it needs can learn it",
		gated.Plated and gated.Plated.state == "can",
		tostring(gated.Plated and gated.Plated.state))
	check("the one who took the other branch cannot, however much skill they have",
		gated.Bladed and gated.Bladed.state == "branch",
		tostring(gated.Bladed and gated.Bladed.state))
	check("and is told which branch it wanted, by id",
		gated.Bladed and gated.Bladed.needs == ARMOURSMITH,
		tostring(gated.Bladed and gated.Bladed.needs))
	check("one asked who took no branch at all cannot either",
		gated.Neither and gated.Neither.state == "branch",
		tostring(gated.Neither and gated.Neither.state))

	-- §2.2. A member recorded before Family knew to ask has no answer, and inventing one for
	-- them would be the same mistake in the opposite direction.
	check("and one nobody has asked says it may know it, not that it cannot",
		gated.Older and gated.Older.state == "unknown",
		tostring(gated.Older and gated.Older.state))

	-- The great majority of recipes have no branch, and none of this may touch them.
	local plain = states(2881)
	for _, name in ipairs { "Plated", "Bladed", "Neither", "Older" } do
		check("an ungated recipe is unaffected for " .. name,
			plain[name] and plain[name].state ~= "branch" and plain[name].needs == nil,
			tostring(plain[name] and plain[name].state))
	end

	for _, key in ipairs { "Plated-FireMaw", "Bladed-FireMaw", "Neither-FireMaw",
		"Older-FireMaw" } do
		Family.Database:Forget(key)
	end

	-- And the recording half: the branches this character took, asked of the client by id.
	local key = Family:CurrentMember()

	KNOWN_SPELLS = { [ARMOURSMITH] = true }
	Family.Professions:Scan(true)
	local meta = Family.Database:Members()[key].meta or {}
	check("a scan records the branch this character took",
		meta.specs and #meta.specs == 1 and meta.specs[1] == ARMOURSMITH,
		tostring(meta.specs and meta.specs[1]))
	check("and stamps when it asked", type(meta.specsSeen) == "number",
		tostring(meta.specsSeen))

	-- Asked, and the answer was none. Different from never asked, and the tooltip draws them
	-- differently, so the record has to keep them apart too.
	KNOWN_SPELLS = {}
	Family.Professions:Scan(true)
	meta = Family.Database:Members()[key].meta or {}
	check("taking no branch is recorded as an answer, not as silence",
		meta.specs == nil and type(meta.specsSeen) == "number",
		tostring(meta.specs) .. " " .. tostring(meta.specsSeen))

	-- A client that cannot be asked leaves the record alone. Clearing here would take a true
	-- fact away from a character because somebody logged in on a different client.
	KNOWN_SPELLS = { [ARMOURSMITH] = true }
	Family.Professions:Scan(true)
	local held = IsSpellKnown
	IsSpellKnown = nil
	Family.Professions:Scan(true)
	meta = Family.Database:Members()[key].meta or {}
	check("a client with no way of being asked leaves what was recorded alone",
		meta.specs and meta.specs[1] == ARMOURSMITH and type(meta.specsSeen) == "number",
		tostring(meta.specs and meta.specs[1]))
	IsSpellKnown = held
	KNOWN_SPELLS = {}
end)()

-- Which recipe an item teaches, across the five languages Family speaks
--
-- The book and the thing it makes do not agree about capitals, and which of the two is
-- capitalised differs by language. Every pair below is a real one, taken from the client's own
-- ItemSparse at the pinned Era build (DATASOURCES §2) rather than invented, because the shape
-- of the disagreement is the whole point and an invented pair would have been written to
-- match whatever the code already did.
--
-- Reported live on a French client: a Potion de Purification the character had already learnt
-- was offered as one they *could* learn. Measured afterwards, it was 105 recipes in French,
-- 920 in Spanish and 1006 in Russian - very nearly every recipe in the game on two of the five
-- clients - and 4 in English, which is why it went unseen for so long.
;(function()
	local teaches = function(item, recipe) return Family.Recipes:Teaches(item, recipe) end

	-- The one that was reported. ASCII letter, French.
	check("a French book teaches the potion it names in different capitals",
		teaches("Recette : Potion de Purification", "Potion de purification"))

	-- Cyrillic, which is the case string.lower cannot touch at all and Russian is made of.
	check("a Russian book teaches its stew", teaches(
		"\208\160\208\181\209\134\208\181\208\191\209\130: \208\191\208\190\209\133\208\187\208\181\208\177\208\186\208\176 \208\151\208\176\208\191\208\176\208\180\208\189\208\190\208\179\208\190 \208\154\209\128\208\176\209\143",
		"\208\159\208\190\209\133\208\187\208\181\208\177\208\186\208\176 \208\151\208\176\208\191\208\176\208\180\208\189\208\190\208\179\208\190 \208\154\209\128\208\176\209\143"))

	-- Cyrillic folds in two halves and both need a fixture. Б and П sit at 0xD0 0x91 and
	-- 0xD0 0x9F and fold within the same lead byte; Т sits at 0xD0 0xA2 and folds to т at
	-- 0xD1 0x82, carrying into the next one. Dropping the carry failed nothing at all until
	-- the third fixture below was added - both Russian pairs here used the easy half.
	check("and its jacket, whose letter folds within one lead byte", teaches(
		"\208\146\209\139\208\186\209\128\208\190\208\185\208\186\208\176: \208\177\208\181\208\187\209\139\208\185 \208\186\208\190\208\182\208\176\208\189\209\139\208\185 \208\182\208\176\208\186\208\181\209\130",
		"\208\145\208\181\208\187\209\139\208\185 \208\186\208\190\208\182\208\176\208\189\209\139\208\185 \208\182\208\176\208\186\208\181\209\130"))

	-- The half that carries: Т at 0xD0 0xA2 becomes т at 0xD1 0x82.
	check("and its boots, whose letter carries into the next lead byte", teaches(
		"\208\146\209\139\208\186\209\128\208\190\208\185\208\186\208\176: \209\130\208\190\208\189\208\186\208\184\208\181 \208\186\208\190\208\182\208\176\208\189\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184",
		"\208\162\208\190\208\189\208\186\208\184\208\181 \208\186\208\190\208\182\208\176\208\189\209\139\208\181 \209\129\208\176\208\191\208\190\208\179\208\184"))

	-- An accented capital, which is the Latin-1 branch and is exercised by exactly one recipe
	-- in French and three in Spanish. Rare is not the same as absent.
	check("a French book whose difference is an accented letter",
		teaches("Recette : \195\169lixir des regrets accumul\195\169s",
			"\195\137lixir des regrets accumul\195\169s"))
	check("and a Spanish one", teaches("F\195\179rmula: \195\173dolo de c\195\179lera sideral",
		"\195\141dolo de c\195\179lera sideral"))

	-- English and German agreed all along, and must go on agreeing.
	check("an English book still teaches what it always did",
		teaches("Recipe: Elixir of Fortitude", "Elixir of Fortitude"))
	check("a German one too", teaches("Rezept: Heiltrank", "Heiltrank"))
	check("and the four English recipes that never matched now do",
		teaches("Schematic: EZ-Thro Dynamite", "Ez-Thro Dynamite"))

	-- Folding must not start matching things that are not the same recipe. The boundary rule
	-- is what stops a tail landing in the middle of a word.
	check("a name starting mid-word is still not what the book teaches",
		teaches("Pattern: Frostweave Bag", "weave Bag") == false)

	-- And what the boundary rule does *not* do, which the comment above it used to claim it
	-- did. A one-word recipe matching the last word of a longer name is allowed through,
	-- because a space is not a letter. Written down as behaviour rather than left as a
	-- sentence in a comment that nothing was holding to account.
	check("but a whole word at the end is, space being no letter",
		teaches("Pattern: Frostweave Bag", "Bag"))
	check("and a different recipe entirely is still not",
		teaches("Recipe: Elixir of Fortitude", "Elixir of Defence") == false)
	check("nor is a recipe name longer than the item's",
		teaches("Rezept: Heiltrank", "Rezept: Heiltrank und mehr") == false)
end)()

-- Whose side a member is on decides what can be done about an item at all: their bank is a
-- different bank and their auction house is a different auction house. So anybody on the
-- other side to the player is marked, and nobody on the same side is.
UnitFactionGroup = function() return "Horde" end
Family.Database:SetMeta(key, { faction = "Horde" })
Family.Database:SetMeta("Novice-FireMaw", { faction = "Alliance" })

crafters = craftersFor(2881, "Requires Blacksmithing (100)")
local marked, unmarked
for _, line in ipairs(GameTooltip.__lines) do
	local text = type(line[1]) == "string" and line[1] or ""
	if text:find("Novice", 1, true) then marked = text end
	if text:find("Tester", 1, true) then unmarked = text end
end
check("a member on the other side is marked with it",
	marked and marked:find("(A)", 1, true) ~= nil, tostring(marked))
check("and one on the same side is not", unmarked
	and unmarked:find("(H)", 1, true) == nil, tostring(unmarked))

-- Two characters on two realms can share a name, and a tooltip has no column to say which is
-- which. The realm goes on the ones that clash and on nothing else.
Family.Database:SetMeta("Tester-Auberdine", { name = "Tester", realm = "Auberdine",
	level = 60, classFile = "PALADIN",
	skills = { [164] = { name = "Blacksmithing", rank = 300, maxRank = 300 } } })
Family.Database:SetPayload("Tester-Auberdine", { professions = { [164] = {
	rank = 300, maxRank = 300, recipes = {} } } })

crafters = craftersFor(2881, "Requires Blacksmithing (100)")

local sameName, otherName = 0, 0
for name in pairs(crafters) do
	if name == "Tester" then sameName = sameName + 1 end
end
for _, line in ipairs(GameTooltip.__lines) do
	local text = type(line[1]) == "string" and line[1] or ""
	if text:find("(@Fire Maw)", 1, true) or text:find("(@Auberdine)", 1, true) then
		sameName = sameName + 10
	end
	if text:find("Novice", 1, true) and text:find("(@", 1, true) then
		otherName = otherName + 1
	end
end

check("two members of the same name are told apart by their realm", sameName >= 20,
	tostring(sameName))

-- And nobody else here, because everybody else is on the realm being played. A character you
-- are standing next to needs no realm on their name: names are unique per realm, so the one
-- realm that never needs saying is your own. This spent a day as "any account with more than
-- one realm puts it on every name", which put it on the ones you are standing next to as well.
check("and the ones on the realm being played are left alone", otherName == 0,
	tostring(otherName))

Family.Database:Forget("Tester-Auberdine")

-- Trade goods have subclasses named after professions. Without the item class to settle it,
-- a pile of arcane dust would be read as an enchanting recipe.
local _, dustHeading = craftersFor(22445)
check("a trade good named after a profession is not taken for a recipe",
	dustHeading == false)

-- Both blocks on one tooltip, with exactly one blank line between them.
Family.Database:SetPayload("Novice-FireMaw", { professions = { [164] = {
	rank = 40, maxRank = 75, recipes = {} } },
	bags = { [0] = { size = 4, free = 3, slots = { [1] = { id = 2881, count = 1 } } } } })
Family.Index:Invalidate()

craftersFor(2881, "Requires Blacksmithing (100)")
local gaps, seenPossessions, seenCrafters = 0, false, false
for _, line in ipairs(GameTooltip.__lines) do
	local text = type(line[1]) == "string" and line[1] or ""
	if text == " " then gaps = gaps + 1 end
	if text:find("Family possessions", 1, true) then seenPossessions = true end
	if text:find("Family crafters", 1, true) then seenCrafters = true end
end
check("a recipe somebody owns gets both blocks", seenPossessions and seenCrafters)
check("with one blank line each rather than two in the middle", gaps == 3, tostring(gaps))

for _, key in ipairs { "Novice-FireMaw", "Ready-FireMaw", "Unseen-FireMaw",
	"Young-FireMaw" } do
	Family.Database:Forget(key)
end
Family.Index:Invalidate()

print()
print("the possessions block on a game tooltip, continued")

-- The reason it failed in the game: the modern route leaves the item off the tooltip, so a
-- hook that asks the tooltip what item it is showing finds nothing.
check("the modern route works when the tooltip itself says nothing",
	tooltipFor(2589, true) == true)

-- Both routes are registered at once, so the guard is what stops the block being written
-- twice on a client where both fire.
wipe(GameTooltip.__lines)
GameTooltip.__itemName = "Something"
GameTooltip.__itemLink = "|Hitem:2589|h"
if GameTooltip.__scripts.OnTooltipCleared then
	GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
end
GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)
Family.UI.__modernCallback(GameTooltip, { id = 2589 })
local headers = 0
for _, line in ipairs(GameTooltip.__lines) do
	if type(line[1]) == "string" and line[1]:find("Family possessions") then
		headers = headers + 1
	end
end
check("and it is written once when both routes fire", headers == 1, tostring(headers))

print()
print("a sibling's things, on the tooltip")

-- "Who has one of these" is the question a shared family is most often being asked, and §6
-- says a sibling belongs wherever our own members are listed. The item index was built from
-- our own members alone, so the answer left them out.
;(function()
	local before = FamilyDB.wide

	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["theirs"] = { name = "Ardent", members = {
			["Rider-FireMaw"] = {
				meta = { name = "Rider", realm = "Fire Maw", classFile = "HUNTER" },
				payload = { bags = { [0] = { size = 16, free = 15,
					slots = { [1] = { id = 11122, count = 1 } } } } },
				seen = time(),
			},
		} } },
	}

	local function tooltipFor(itemID)
		GameTooltip.__lines = {}
		GameTooltip.__itemName = "Carrot on a Stick"
		GameTooltip.__itemLink = "|Hitem:" .. itemID .. "|h"
		if GameTooltip.__scripts.OnTooltipCleared then
			GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
		end
		GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

		local text = ""
		for _, line in ipairs(GameTooltip.__lines) do
			text = text .. tostring(line[1]) .. " " .. tostring(line[2]) .. "\n"
		end
		return text
	end

	-- Once, by hand, because assigning the saved variables straight over is not something
	-- any code path does and nothing was told about it. Everything after this has to be
	-- noticed on its own.
	Family.Index:Invalidate()

	-- Shared, and not adopted. Somebody we have not made a sibling is explicitly somewhere
	-- to go and look, not something counted in with our own.
	check("a shared member who is not a sibling is not counted",
		tooltipFor(11122):find("Rider", 1, true) == nil)

	Family.Wide:SetSibling("theirs", "Rider-FireMaw", true)

	local said = tooltipFor(11122)
	check("a sibling holding one is named", said:find("Rider", 1, true) ~= nil, said)
	check("and where they keep it is said", said:find("bags", 1, true) ~= nil)
	-- A count on a tooltip reads as "I can go and get that", which is not true of
	-- somebody else's character.
	check("and whose character it is, which is not ours",
		said:find("of Ardent", 1, true) ~= nil, said)

	-- The index is built once and kept. Nothing that changes a linked family's records goes
	-- through the path that marks a member stale, so without a word from the other
	-- direction the tooltip would answer this session's first answer for ever.
	Family.Wide:SetSibling("theirs", "Rider-FireMaw", false)
	check("and unticking them takes it away again without a reload",
		tooltipFor(11122):find("Rider", 1, true) == nil)

	FamilyDB.wide = before
	Family.Index:Invalidate()
end)()

print()
print("an API that exists and throws")
check("TryCall on a throwing API answers nil",
	Family:TryCall(GetNumSpecGroups) == nil)
check("TryCall on a working one answers normally",
	Family:TryCall(GetNumTalentGroups) == 2)
check("TryCall on something absent answers nil",
	Family:TryCall(NoSuchGlobalAnywhere) == nil)
check("and the capability probe stops being fooled by the symbol",
	Family.Capabilities:Has("dualSpec") == true)

print()
print("talents")
advance(4)

local talents = Family.Database:Payload(key) and Family.Database:Payload(key).talents
check("talents recorded", talents ~= nil)
if talents then
	check("both specialisations scanned", talents.groupCount == 2, tostring(talents.groupCount))
	check("the tree system was chosen on Era", talents.system == "trees", talents.system)

	local one = talents.groups[1]
	-- 2 + 5 + 1 across the stubbed talents, summed from ranks rather than asked for.
	check("points are summed from ranks, not read positionally",
		one and one.pointsSpent == 8, one and tostring(one.pointsSpent))
	-- What the client said, which is what the scanner's job is. The panel turns it into the
	-- reader's language later; recording it is not where that happens.
	check("the tab name survives a different return order",
		one and one.tabs[1].name == "Arkan", one and tostring(one.tabs[1].name))
	check("and so does the icon", one and tostring(one.tabs[1].icon):find("arcane%-icon")
		~= nil, one and tostring(one.tabs[1].icon))
	check("a fully specced tree is never called unvisited",
		one and one.visited == true)
	check("a talent keeps its position", one and one.tabs[1].talents[2].tier == 1
		and one.tabs[1].talents[2].column == 2)
	check("and its rank", one and one.tabs[1].talents[2].rank == 5)
	check("spec 1 is marked visited", one and one.visited == true)

	-- The case §2.2 is about: an untouched second spec must say so rather than be drawn
	-- as a tree with nothing in it.
	local two = talents.groups[2]
	check("an unvisited spec 2 is flagged, not shown as empty", two and two.visited == false,
		two and tostring(two.visited))

	check("summary points reached meta",
		Family.Database:Meta(key).talentPoints[1] == 8,
		tostring(Family.Database:Meta(key).talentPoints and
			Family.Database:Meta(key).talentPoints[1]))
end

print()
print("talents on Mists - a different system behind the same panel")

-- Mists reuses the name GetTalentInfo for an entirely different call, which is the trap
-- this stub exists to catch: six tiers of three choices, and a specialisation by id.
local savedBuild, savedTalentInfo = GetBuildInfo, GetTalentInfo
GetBuildInfo = function() return "5.5.4", "69078", "Aug 2026", 50504 end
GetSpecialization = function() return 2 end
GetSpecializationInfo = function(index) return 62 + index end
GetSpecializationInfoByID = function(id) return id, "Arcane", nil, "spec-icon" end

-- Two sockets, one filled and one empty. An empty socket is a fact about the specialisation
-- and has to survive as one rather than being skipped.
GetNumGlyphSockets = function() return 2 end
GetGlyphSocketInfo = function(socket)
	if socket == 1 then return true, 1, nil, 55360, "glyph-icon" end
	return true, 1, nil, nil, nil
end
-- Six tiers, and a client that says MAX_TALENT_TIERS is seven. The constant is a ceiling
-- rather than a count, and believing it grew a permanent seventh row saying "nothing chosen"
-- - a talent nobody can ever take, reported as one this member has not taken.
MAX_TALENT_TIERS = 7

GetTalentInfo = function(tier, column, group)
	if tier > 6 then return nil end
	-- Chosen: column 2 on every tier for spec 1, column 3 for spec 2.
	local want = (group == 2) and 3 or 2
	return 1000 + tier * 10 + column, "Talent " .. tier .. "-" .. column,
		"icon", column == want
end

Family.Capabilities:Detect()
check("Mists is detected", Family.Capabilities.name == "Mists of Pandaria",
	Family.Capabilities.name)
check("and it does not use talent trees", Family.Capabilities:Has("talentTrees") == false)

Family.Talents:Scan()
local mop = Family.Database:Payload(key).talents
check("the choice system was used", mop.system == "choices", mop.system)
check("six tiers read, not the seven the constant allows for",
	mop.groups[1] and #mop.groups[1].tiers == 6,
	mop.groups[1] and tostring(#mop.groups[1].tiers))
check("the chosen column is recorded", mop.groups[1].tiers[3].chosen == 2,
	tostring(mop.groups[1].tiers[3].chosen))
check("the two specs differ", mop.groups[2].tiers[3].chosen == 3,
	tostring(mop.groups[2].tiers[3].chosen))
check("specialisation kept as an id, not a name", mop.groups[1].specID == 64,
	tostring(mop.groups[1].specID))
check("and it reached meta", Family.Database:Meta(key).specID == 64)
check("glyphs are read with the specialisation they belong to",
	mop.groups[1].glyphs and mop.groups[1].glyphs[1].spellID == 55360,
	mop.groups[1].glyphs and tostring(mop.groups[1].glyphs[1].spellID))
check("an empty glyph socket is recorded as empty, not skipped",
	mop.groups[1].glyphs and mop.groups[1].glyphs[2].spellID == nil)

-- The grid is asked for by tier and column on some builds and by a flat index on others.
-- Answering only the flat form must still produce the same six tiers.
local byTierAndColumn = GetTalentInfo
GetTalentInfo = function(a, b, c)
	if type(b) == "boolean" then
		local tier = math.floor((a - 1) / 3) + 1
		local column = ((a - 1) % 3) + 1
		return byTierAndColumn(tier, column, c)
	end
	return nil
end
Family.Talents:Scan()
local flat = Family.Database:Payload(key).talents
check("a client that only answers by flat index reads the same",
	flat.groups[1] and #flat.groups[1].tiers == 6,
	flat.groups[1] and tostring(#flat.groups[1].tiers))
-- The trap the flat check above does not catch: a client whose first shape answers
-- *something* whatever it is handed. Asked for column 1 and column 2 of a tier it returns
-- the same talent twice, so choosing it would fill every tier with three copies of its
-- first choice - confident nonsense, which is worse than nothing.
--
-- So a reader is chosen by asking it for a whole tier and requiring three different answers.
GetTalentInfo = function(a, b, c)
	if type(b) == "boolean" or b == nil then
		local tier = math.floor((a - 1) / 3) + 1
		local column = ((a - 1) % 3) + 1
		return byTierAndColumn(tier, column, c)
	end
	-- Here the second argument is not a column at all, so every column of a tier answers
	-- with the same talent.
	return byTierAndColumn(a, 1, c)
end
Family.Talents:Scan()
local distinct = Family.Database:Payload(key).talents
local tier2 = distinct.groups[1] and distinct.groups[1].tiers[2]
check("a reader that answers the same talent for every column is not the one used",
	tier2 and tier2.choices[1] and tier2.choices[2]
		and tier2.choices[1].name ~= tier2.choices[2].name,
	tier2 and tier2.choices[1] and tier2.choices[1].name)
check("and the tier that was read is the tier that was asked for",
	tier2 and tier2.choices[3] and tier2.choices[3].name == "Talent 2-3",
	tier2 and tier2.choices[3] and tier2.choices[3].name)

-- A name is enough to draw a talent, and an id is not needed to. Requiring both is what
-- left Mists showing a column of "nothing chosen" for a character who had six talents.
GetTalentInfo = function(tier, column, group)
	if type(column) ~= "number" or tier > 6 then return nil end
	local want = (group == 2) and 3 or 2
	return "Talent " .. tier .. "-" .. column, "icon", tier, column, column == want
end
Family.Talents:Scan()
local nameless = Family.Database:Payload(key).talents
check("a client that answers with no talent id at all is still readable",
	nameless.groups[1] and #nameless.groups[1].tiers == 6,
	nameless.groups[1] and tostring(#nameless.groups[1].tiers))
check("and the chosen one is still known",
	nameless.groups[1] and nameless.groups[1].tiers[4]
		and nameless.groups[1].tiers[4].chosen == 2,
	nameless.groups[1] and nameless.groups[1].tiers[4]
		and tostring(nameless.groups[1].tiers[4].chosen))

-- The newest shape answers with one table instead of a list of values.
GetTalentInfo = nil
C_SpecializationInfo = {
	GetTalentInfo = function(query)
		if not query or query.tier > 6 then return nil end
		local want = (query.groupIndex == 2) and 3 or 2
		return {
			talentID = 2000 + query.tier * 10 + query.column,
			name = "Talent " .. query.tier .. "-" .. query.column,
			icon = "icon",
			selected = query.column == want,
		}
	end,
}
Family.Talents:Scan()
local tabled = Family.Database:Payload(key).talents
check("a client that answers with a table is read the same way",
	tabled.groups[1] and #tabled.groups[1].tiers == 6,
	tabled.groups[1] and tostring(#tabled.groups[1].tiers))
check("including which choice was taken",
	tabled.groups[1] and tabled.groups[1].tiers[5]
		and tabled.groups[1].tiers[5].chosen == 2,
	tabled.groups[1] and tabled.groups[1].tiers[5]
		and tostring(tabled.groups[1].tiers[5].chosen))
C_SpecializationInfo = nil

GetTalentInfo = byTierAndColumn

-- A grid that cannot be read at all must not take the specialisation with it.
local noGrid = GetTalentInfo
GetTalentInfo = function() return nil end
Family.Talents:Scan()
local specOnly = Family.Database:Payload(key).talents
check("a specialisation survives a grid that will not read",
	specOnly.groups[1] and specOnly.groups[1].specID == 64,
	specOnly.groups[1] and tostring(specOnly.groups[1].specID))
GetTalentInfo = noGrid
Family.Talents:Scan()

-- On some builds the group-aware call answers only for the specialisation that is live and
-- refuses to say anything about the other one - which is how a paladin with two
-- specialisations had the inactive one reported as "none recorded" beside six talents it
-- plainly had. What the client will no longer say, it said last time, and that stands.
local anySpec = GetSpecialization
GetSpecialization = function(_, _, group)
	if group and group ~= GetActiveTalentGroup() then return nil end
	return 2
end

Family.Talents:Scan()
local kept = Family.Database:Payload(key).talents
check("the live specialisation is still read", kept.groups[1]
	and kept.groups[1].specID == 64, kept.groups[1] and tostring(kept.groups[1].specID))
check("and the one the client will no longer talk about is not forgotten",
	kept.groups[2] and kept.groups[2].specID == 64,
	kept.groups[2] and tostring(kept.groups[2].specID))

GetSpecialization = anySpec

-- Achievements are a Mists thing, so this is the one place they can be read at all.
Family.Character:Scan()
local achievements = Family.Database:Payload(key).achievements
check("achievements are read on a client that has them", achievements ~= nil)
check("with the points the client reports", achievements
	and achievements.points == 1450, achievements and tostring(achievements.points))
check("and a count of the finished ones", achievements and achievements.count == 2,
	achievements and tostring(achievements.count))

local byId = {}
for _, entry in ipairs(achievements and achievements.list or {}) do byId[entry.id] = entry end

check("a finished one is kept with its category", byId[9201]
	and byId[9201].done == true and byId[9201].category == 92)
check("a started one is kept with how far through it is",
	byId[9202] and byId[9202].completed == 2 and byId[9202].criteria == 5,
	byId[9202] and tostring(byId[9202].completed))
check("and one nobody has started is not kept at all - there are thousands of those",
	byId[9203] == nil)

-- Back to Era for the rest.
GetBuildInfo, GetTalentInfo = savedBuild, savedTalentInfo
GetNumTalentTiers, GetSpecialization = nil, nil
Family.Capabilities:Detect()
Family.Talents:Scan()

print()
print("names")
local name, known = Family.Names:Item(2589, "test")
check("known item resolves", known == true and name == "Linen Cloth", tostring(name))
local placeholder, wasKnown = Family.Names:Item(99999, "test", function() end)
check("unknown item gives a legible placeholder", wasKnown == false
	and placeholder:find("99999") ~= nil, placeholder)

local delivered
Family.Names:Item(12345, "test", function(_, resolved) delivered = resolved end)
ITEM_NAMES[12345] = "Arrival"
GetItemInfo = function(id) return ITEM_NAMES[id] end
C_Item.GetItemInfo = GetItemInfo
fire("GET_ITEM_INFO_RECEIVED", 12345, true)
check("callback fires when the name arrives", delivered == "Arrival", tostring(delivered))

print()
print("codec round trip")
local codecName, encoded = Family.Codec:Encode({ a = 1, b = { 2, 3 } })
local back = Family.Codec:Decode(codecName, encoded)
check("plain codec round-trips", back.b[2] == 3)
check("unknown codec reports rather than errors",
	select(2, Family.Codec:Decode("nope", "x")) ~= nil)

print()
print("interface")
local ok, err = pcall(function()
	Family.UI:Toggle()
	Family.UI:Refresh()
end)
check("summary builds and refreshes", ok, tostring(err))

-- A column set wider than the row loses its last column off an edge with no scroll bar to
-- find it with. Summary.lua adds each set up when it loads and says so; nothing should have.
--
-- Every one of these warnings is checked, not just the one that existed when this was
-- written. Adding the Crafting set made the button-row guard fire, and the warning went into
-- a chat frame nobody was reading while the buttons overlapped the side filters on screen. A
-- guard whose output nobody asserts is a guard that has already stopped working.
--
-- In a block of its own: the main chunk is up against Lua 5.1's limit of two hundred locals.
do
	local COMPLAINTS = { "wider than", "across the top", "pixels each",
		"drawn off the end" }

	local complained
	for _, message in ipairs(DEFAULT_CHAT_FRAME.messages) do
		for _, needle in ipairs(COMPLAINTS) do
			if message:find(needle, 1, true) then complained = message end
		end
	end
	check("nothing on the summary complains that it does not fit", complained == nil,
		complained)
end
check("window is showing", Family.UI.window:IsShown() == true)

-- The abilities panel, with a second member so the picker has something to pick between.
-- Other-FireMaw carries meta and no payload, which is its other job: every panel has to cope
-- with a member it knows of and nothing about.
Family.Database:SetMeta("Other-FireMaw", { name = "Other", realm = "Fire Maw",
	classFile = "MAGE", level = 60 })
Family.Talents:Scan()

-- Every panel below is read for its contents, not merely for drawing without complaint, and
-- that only means anything if the picker lands on the member who has any. It lands on the
-- one being played - Other-FireMaw has meta and no payload at all, and used to be chosen by
-- every panel simply for sorting first, which is how these checks came to pass over panels
-- that were drawing nothing.
check("the member being played is the one the panels below must land on",
	Family:CurrentMember() == "Tester-FireMaw", Family:CurrentMember())

-- A choice made by hand stands, but only until somebody else logs in. Panels are built once
-- and kept for the session, so without this a member chosen on Tuesday was still selected on
-- Wednesday's character - which is what it looked like from outside: a filter that remembered
-- across logouts.
Family.UI:ShowTab("character")
local characterPicker
for _, f in ipairs(frames) do
	if f.Select and f.Reconcile and f.__shown == true then
		characterPicker = characterPicker or f
	end
end
check("a panel has a picker to test with", characterPicker ~= nil)

if characterPicker then
	characterPicker:Select({ key = "Other-FireMaw", meta = { name = "Other" } })
	check("a member chosen by hand is kept while the session lasts",
		characterPicker.chosen == true)

	fire("PLAYER_ENTERING_WORLD")
	check("and forgotten when somebody logs in", characterPicker.chosen == nil
		and characterPicker.selected == nil)

	Family.UI:Refresh()
end

local okTalents, talentErr = pcall(function() Family.UI:ShowTab("talents") end)
check("the abilities and talents panel builds", okTalents, tostring(talentErr))

-- UI:Refresh isolates a failing panel and reports it, so wrapping it in pcall says nothing
-- at all - it succeeds either way. The only honest test is whether the panel complained.
local function drawsCleanly(label)
	local mark = #DEFAULT_CHAT_FRAME.messages
	Family.UI:Refresh()
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		local message = DEFAULT_CHAT_FRAME.messages[index]
		if message:find("failed to draw") then
			check(label, false, message)
			return
		end
	end
	check(label, true)
end

drawsCleanly("and redraws")

local function textShowing(needle)
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find(needle, 1, true) then return true end
	end
	return false
end

-- A tree is drawn as a tree: the talents are icons at the tier and column they occupy, so
-- what is on screen is a grid of buttons rather than a list of names. What can be read back
-- is the tree headings and what each icon would say on hover.
--
-- Only Tester has talents; Other-FireMaw has meta and nothing else and sorts first. So this
-- is also the check that a picker defaults to the character being played.
-- The tree heading, in the reader's language. The client answers only for the class being
-- played, so a tree belonging to somebody else's character comes from the game's own table -
-- the same place profession and race names come from. This member's was recorded in German.
check("with the tree they are in and what was spent in it", textShowing("Arcane"),
	"the heading is still showing the word the recording client used")
check("and not the word the recording client used", not textShowing("Arkan"))

local function talentCellShowing(name)
	for _, f in ipairs(frames) do
		if f.__shown == true and f.fallback and f.fallback[1]
			and f.fallback[1][1] == name then
			return f
		end
	end
	return nil
end

check("and lists the talents that were actually taken",
	talentCellShowing("Arcane Subtlety") ~= nil and talentCellShowing("Arcane Focus") ~= nil)

-- A talent recorded in another language
--
-- This was the one thing Family stored as a word, because GetTalentInfo answers only for the
-- class being played and showing another member's talents is the whole point of the panel. A
-- talent is a spell, though, and the client names any spell for any class - so the position
-- is turned into a spell id and the reader's own client answers.
do
	local who = Family:CurrentMember()
	local payload = Family.Database:Payload(who) or {}
	local group = payload.talents and payload.talents.groups
		and payload.talents.groups[1]
	local recorded = group and group.tabs and group.tabs[1]
		and group.tabs[1].talents and group.tabs[1].talents[1]

	check("the talent the panel is about is in the record", recorded ~= nil)
	if recorded then
		local was = recorded.name
		-- As a German client would have written it, on a client that is not German.
		recorded.name = "Arkane Feinheit"
		Family.Database:SetPayload(who, payload)
		Family.UI:Refresh()

		check("a talent recorded in another language reads in this client's",
			talentCellShowing("Arcane Subtlety") ~= nil,
			"the panel is still showing the word it was recorded under")
		check("and the recorded word is not on the grid",
			talentCellShowing("Arkane Feinheit") == nil)

		recorded.name = was
		Family.Database:SetPayload(who, payload)
		Family.UI:Refresh()
	end

	-- A talent this table has never heard of - a client newer than the table, or a position
	-- that has moved - still has the word the recording client wrote.
	check("a talent no table knows keeps the word it was recorded under",
		Family:TalentName("MAGE", 9, 9, 9, "Arkane Feinheit") == "Arkane Feinheit")
	check("and one whose class was never recorded does too",
		Family:TalentName(nil, 1, 1, 1, "Arkane Feinheit") == "Arkane Feinheit")

	-- Era and Burning Crusade hold different talents at thirty-two of the positions they
	-- share, which is why they are two tables rather than one merged one. This harness runs
	-- as Era, and the warrior's second tier is one of the thirty-two: 12295 here, 12300
	-- there. A single table would be right about most of the grid and quietly wrong about
	-- those, which is worse than being wrong about all of it.
	-- Mists asks the same question with a shorter answer: its talents carry an id of their
	-- own, so there is no position to look up.
	-- The trees themselves are the one part of this with no spell behind them, so their
	-- names are shipped - and, like every shipped name, fall back to English for a language
	-- Family does not write and to the recorded word for anything the table has never heard
	-- of.
	do
		local was = Family.locale
		Family.locale = "frFR"
		check("a talent tree is named in the reader's language",
			Family:TalentTreeName("MAGE", 1, "Arkan") == "Arcanes",
			tostring(Family:TalentTreeName("MAGE", 1, "Arkan")))
		Family.locale = "itIT"
		check("and in English for a language this table does not ship",
			Family:TalentTreeName("MAGE", 1, "Arkan") == "Arcane",
			tostring(Family:TalentTreeName("MAGE", 1, "Arkan")))
		Family.locale = was
		check("a tree no table knows keeps the word it was recorded under",
			Family:TalentTreeName("MAGE", 9, "Arkan") == "Arkan")
	end

	check("a Mists talent is named from the spell its id maps to",
		Family:TalentNameByID(15757, "recorded") == "Sacred Shield",
		tostring(Family:TalentNameByID(15757, "recorded")))
	check("and one no table knows keeps the word it was recorded under",
		Family:TalentNameByID(999999, "Heiliger Schild") == "Heiliger Schild")

	check("a position the two builds disagree about is read from this client's build",
		Family:TalentName("WARRIOR", 1, 2, 2, "recorded") == "Spell 12295",
		tostring(Family:TalentName("WARRIOR", 1, 2, 2, "recorded")))
end

-- Drawn even at nought points, and greyed. Where the gaps are is half of what a tree says,
-- and a talent left out of the grid is not a gap, it is a missing square.
local untaken = talentCellShowing("Wand Specialization")
check("a talent with no points in it is still drawn, and greyed",
	untaken ~= nil and untaken.icon.__desaturated == true,
	untaken and tostring(untaken.icon.__desaturated))

-- What a talent's tooltip actually says.
--
-- There is no id to ask about in a tree, so the game has to be asked by the position the
-- talent sits at - and which call does that differs by client, with no way to ask which. Each
-- of these is the only working call on some client Family runs on, and on every one of them
-- the wrong call is silent rather than wrong. That silence is what the player saw: three
-- lines of Family's own and none of the game's.
local hovered = talentCellShowing("Arcane Subtlety")

local function talentTooltipSays(needle)
	wipe(GameTooltip.__lines)
	hovered.__scripts.OnEnter(hovered)
	for _, line in ipairs(GameTooltip.__lines) do
		if type(line[1]) == "string" and line[1]:find(needle, 1, true) then return true end
	end
	return false
end

check("a talent is hoverable at all", hovered ~= nil and hovered.__scripts.OnEnter ~= nil)

if hovered then
	for _, route in ipairs { "tabindex", "group", "link" } do
		useTalentRoute(route)
		check("a talent tooltip carries the game's own words on a client that answers to "
			.. route, talentTooltipSays("what the talent actually does"))
	end

	-- And a client that answers to none of them still says what Family knows, which is what
	-- the fallback lines are for - but it must be the last resort, not the usual case.
	useTalentRoute(nil)
	check("a client that will describe no talent at all falls back to what Family recorded",
		talentTooltipSays("Arcane Subtlety"))

	useTalentRoute("tabindex")
end

-- The two new panels, and the shared picker they both hang off.
local function tabDrawsCleanly(id, label)
	local mark = #DEFAULT_CHAT_FRAME.messages
	Family.UI:ShowTab(id)
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		local message = DEFAULT_CHAT_FRAME.messages[index]
		if message:find("failed to") then
			check(label, false, message)
			return
		end
	end
	check(label, true)
end

tabDrawsCleanly("contents", "the possessions panel builds and draws")
tabDrawsCleanly("professions", "the professions panel builds and draws")


-- Each sort runs its own comparison over the same list, and a comparison that is not a
-- strict ordering makes table.sort throw rather than merely order things oddly.
for _, label in ipairs { "Item level", "Skill needed", "Difficulty" } do
	local mark = #DEFAULT_CHAT_FRAME.messages
	local clicked = clickButton(label)
	local complained = false
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("failed to") then complained = true end
	end
	check("sorting recipes by " .. label:lower() .. " works", clicked and not complained,
		clicked and "panel complained" or "no button called " .. label)
end
local function frameShowing(text)
	for index, f in ipairs(fontStrings) do
		if f.__text == text then return index end
	end
	return nil
end

-- Text on a row that is actually being drawn. Rows are pooled and hidden rather than
-- destroyed, so their last words stay in this harness for ever - and a check that merely
-- finds a string finds one nobody can see. Only the row's own shown flag is consulted,
-- because the row is the thing these panels show and hide.
-- Text a panel has actually drawn, read off its rows rather than swept out of every font
-- string in the client.
--
-- `visibleText` below answers "is this word anywhere on screen", which is the right question
-- for a chat line or a tooltip and the wrong one for a panel: several panels are built, they
-- say ordinary words, and a check about one of them passes on another's text. That is how a
-- check for the sender of a letter passed for a month on the word "Auctioneer" appearing
-- inside the development icon sheet, while the summary was drawing "Auction House" - the
-- needle never matched what the panel wrote, and nothing said so.
--
-- Rows come in two shapes here: the summary builds `cells`, and the character, professions
-- and abilities panels build `left`, `middle` and `right`. Both are read.
function drawnText(needle)
	for _, f in ipairs(frames) do
		if onScreen(f) then
			for _, field in ipairs { "cells" } do
				for _, cell in ipairs(f[field] or {}) do
					if type(cell.__text) == "string"
						and cell.__text:find(needle, 1, true) then
						return true
					end
				end
			end

			for _, field in ipairs { "left", "middle", "right", "text" } do
				local part = rawget(f, field)
				if type(part) == "table" and type(part.__text) == "string"
					and part.__text:find(needle, 1, true) then
					return true
				end
			end
		end
	end
	return false
end

local function visibleText(needle)
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find(needle, 1, true)
			and f.__visible ~= false and onScreen(f) then
			return true
		end
	end
	return false
end

-- A profession recorded in one language, read in another
--
-- Reported from a live client: a Spanish panel listing five French professions as never
-- opened, and a hunter whose professions had apparently vanished until its windows were
-- reopened. Recipes opened on a French client sat under "Couture" while the skill list,
-- re-read after the client was set to English, was under "Tailoring". Nothing matched, and
-- the panel said never opened about a profession whose recipes it was holding.
--
-- Both words are skill line 197, so both now file under 197 and the recipes are simply
-- found. This drives the case that used to fail and asserts that it no longer does.
do
	local who = Family:CurrentMember()
	local payload = Family.Database:Payload(who) or {}
	local before = payload.professions
	-- Borrowed, not spent: everything after this reads the same member.
	local wasSkills = (Family.Database:Meta(who) or {}).skills
	local wasLocale = (Family.Database:Meta(who) or {}).skillsLocale

	-- The skill list as an English client reads it, filed by identity.
	Family.Database:SetMeta(who, {
		skills = { [Family:SkillLineFor("Tailoring")] =
			{ rank = 300, maxRank = 300, secondary = false, name = "Tailoring" } },
		skillsLocale = Family.locale,
	})
	-- The recipes, opened while the client was French - and filed under the same number,
	-- because that is what the French word resolves to.
	payload.professions = {
		[Family:SkillLineFor("Couture")] = {
			recipes = { { id = 3914, name = "Bolt of Linen" } },
			recipesSeen = time(), locale = "frFR", name = "Couture",
		},
	}
	Family.Database:SetPayload(who, payload)

	check("the French word and the English one are the same profession",
		Family:SkillLineFor("Couture") == Family:SkillLineFor("Tailoring"))

	-- Earlier checks left a search typed and the whole family ticked, which puts this panel
	-- into a different mode entirely.
	if _G.FamilyProfessionsSearch then _G.FamilyProfessionsSearch:SetText("") end
	if _G.FamilyProfessionsEveryone then
		_G.FamilyProfessionsEveryone:SetChecked(false)
	end

	Family.UI:ShowTab("professions")
	Family.UI:Refresh()

	check("a profession recorded in another language is not called never opened",
		not visibleText("Tailoring never opened"),
		"the panel claims a profession it holds recipes for was never opened")
	check("and its recipes are found rather than merely explained",
		visibleText("Bolt of Linen"),
		"the recipes are still unreachable - the identity did not join them up")
	-- A button's label lives on the button, not in a font string, so this looks where the
	-- label actually is rather than where the other checks look.
	local labelled = false
	for _, f in ipairs(frames) do
		if type(f.__text) == "string" and f.__text:find("Tailoring", 1, true)
			and f.__shown ~= false then
			labelled = true
		end
	end
	check("and it is named in the language of whoever is reading", labelled,
		"the profession is shown under the word it was recorded with, not the reader's")

	payload.professions = before
	Family.Database:SetPayload(who, payload)
	Family.Database:SetMeta(who, {
		skills = wasSkills or Family.CLEAR,
		skillsLocale = wasLocale or Family.CLEAR,
	})
	Family.UI:Refresh()
end

local function somethingShowing(needle)
	for index, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find(needle, 1, true) then return index end
	end
	return nil
end

tabDrawsCleanly("character", "the character panel builds and draws")

-- The quest log is a section of this panel rather than a tab of its own.
clickButton("Quests")
check("the quest section groups by zone", somethingShowing("Elwynn Forest") ~= nil)
-- Difficulty belongs to the member holding the quest, not to whoever is being played: an
-- eleventh-level quest is trivial to this sixtieth-level member and would be red to another.
check("and says how hard each quest is for the member holding it",
	somethingShowing("trivial") ~= nil)
check("a finished quest says so rather than counting objectives",
	somethingShowing("ready to hand in") ~= nil)

-- Clicking a quest opens it in the log, but only for the member being played: the quest log
-- belongs to whoever is logged in, so opening "their" quest on somebody else would open a
-- different quest or none at all.
local opened
SelectQuestLogEntry = function(index) opened = index end
QuestLogFrame = CreateFrame("Frame", "QuestLogFrame")
ShowUIPanel = function(frame) frame:Show() end
QuestLog_SetSelection = noop
QuestLog_Update = noop

local questRow
for _, f in ipairs(frames) do
	if f.__shown == true and f.questTitle == "Wanted: Hogger" then questRow = f end
end
check("a quest row knows which quest it is", questRow ~= nil)

if questRow then
	questRow.__scripts.OnClick(questRow)
	check("clicking one opens it in the log", opened ~= nil, tostring(opened))

	opened = nil
	questRow.memberKey = "Somebody-Else"
	questRow.__scripts.OnClick(questRow)
	check("and clicking another member's quest opens nothing", opened == nil,
		tostring(opened))
end

-- Attachments are possessions: they are somewhere, they belong to this member, and unlike
-- everything else on that panel they leave on their own. The panel draws bags rather than a
-- list now, so what is checked is that the mail is one of the containers on it and that its
-- attachment is in a slot.
Family.UI:ShowTab("contents")

-- What a container is, and how full it is, is asked for rather than shown.
--
-- Six containers cost six headings and six lines of counts, and that pushed the last bags off
-- a screen with room for all of them. The bag now sits at the head of its own row of slots and
-- carries all of it on hover - so this is read the way a player reads it.
local function bagTooltip(needle)
	for _, f in ipairs(frames) do
		if f.__shown == true and f.lines and f.__scripts.OnEnter then
			wipe(GameTooltip.__lines)
			f.__scripts.OnEnter(f)
			for _, line in ipairs(GameTooltip.__lines) do
				if type(line[1]) == "string" and line[1]:find(needle, 1, true) then
					return f
				end
			end
		end
	end
	return nil
end

check("the possessions panel draws the mail as a container of its own",
	bagTooltip("Mail") ~= nil)
check("a bag says which bag it is when asked", bagTooltip("Backpack") ~= nil)

-- A bank bag the client has no name for is numbered as the player numbers them, not by the
-- container id it happens to have. The bank's own window is container -1 and its bags start
-- at five, so the first bank bag was being called the fifth - and a player counting bank bags
-- in this panel has already had to work out that the first block is the bank itself.
do
	-- The panel draws the member being played, so this borrows their bank and gives it back.
	local who = Family:CurrentMember()
	local payload = Family.Database:Payload(who) or {}
	local held = payload.bank

	payload.bank = { seen = time(), containers = {
		[-1] = { size = 28, free = 28, slots = {} },
		-- No itemID on either, so the name has to be made rather than looked up.
		[5] = { size = 16, free = 16, slots = {} },
		[6] = { size = 16, free = 16, slots = {} },
	} }
	Family.Database:SetPayload(who, payload)

	Family.UI:Show()
	Family.UI:ShowTab("contents")
	Family.UI:Refresh()

	check("the first bank bag is called the first, not the fifth",
		bagTooltip("Bank bag 1") ~= nil, "it is numbered by its container id")
	check("and the one after it the second", bagTooltip("Bank bag 2") ~= nil)

	payload.bank = held
	Family.Database:SetPayload(who, payload)
end
check("and how full it is", bagTooltip("14 of 16 free") ~= nil)

-- §3 has nowhere else left to be said. A quiver's free slots are not room for anything else,
-- and that used to be three words on a heading that no longer exists.
check("and a restricted bag still says that its free slots are not free for anything",
	bagTooltip("own kind of thing") ~= nil)

-- None of it on the panel itself, which is the whole point of moving it.
check("but none of that is spent on a line of its own",
	visibleText("14 of 16 free") == false and visibleText("Backpack") == false)

do
-- The right picture on each container.
--
-- A bought bag is an item and draws itself. Nothing else is, and everything else used to be
-- drawn as a backpack - a mailbox is not a rucksack, and somebody looking for their keys is
-- looking for keys. Worse, the keyring was drawn as a helm: its container number is negative,
-- ContainerIDToInventoryID turns it into an equipment slot anyway, and the client answered
-- with whatever was worn there. A call answering is not a call agreeing with the question.
local function iconOfBagShowing(needle)
	local found = bagTooltip(needle)
	return found and found.texture and found.texture.__texture
end

check("the keyring is drawn as a keyring, not as whatever is worn in slot -2",
	(iconOfBagShowing("Keyring") or ""):find("KeyRing", 1, true) ~= nil,
	tostring(iconOfBagShowing("Keyring")))
check("and the mail as a letter, not as a backpack",
	(iconOfBagShowing("Mail") or ""):find("Letter", 1, true) ~= nil,
	tostring(iconOfBagShowing("Mail")))

-- The bank's own window had no icon of its own, so it fell through to the backpack button:
-- a vault drawn as a bag, on the one panel where what a container is matters. The bags bought
-- to go in the bank are still drawn as the bags they are, which is why this is asked of the
-- bank container by name rather than of everything filed under the bank.
check("the bank's own window is drawn as a bank, not as a bag",
	(iconOfBagShowing("Bank") or ""):find("Banker", 1, true) ~= nil,
	tostring(iconOfBagShowing("Bank")))

-- And the scanner does not record one at all, which is where the helm came from.
local keyringEntry = Family.Database:Payload(key).bags[-2]
check("the keyring is not recorded as being some item somebody equipped",
	keyringEntry ~= nil and keyringEntry.itemID == nil,
	keyringEntry and tostring(keyringEntry.itemID))
end

local mailSlot
for _, f in ipairs(frames) do
	if f.__shown == true and f.itemID == 2589 and f.block
		and f.block.where == "mail" then
		mailSlot = f
	end
end
check("with what is attached to it in a slot", mailSlot ~= nil)

local backpackSlot
for _, f in ipairs(frames) do
	if f.__shown == true and f.block and f.block.where == "bags"
		and f.block.bag == 0 and f.itemID then
		backpackSlot = f
	end
end
check("and the backpack drawn as a bag, with what is in it where it really is",
	backpackSlot ~= nil)

-- Charges in the corner where a stack count would be, which is where the game itself puts
-- them: an oil with five uses is one item and its stackCount says 1, so that corner is empty
-- and the number somebody wants is the charges. Recording it and drawing it are two claims,
-- and only the first was held (L-030).
do
	local charged, stacked
	for _, f in ipairs(frames) do
		if f.__shown == true and f.block and f.block.where == "bags" and f.count then
			-- By id for the oil, which is in exactly one slot. The cloth is looked for by
			-- what it should say rather than by id: buttons are pooled, and one that drew
			-- a slot in an earlier refresh is still in the list with its old id on it.
			if f.itemID == 20747 then charged = f end
			if f.itemID == 2589 and tostring(f.count.__text) == "20" then stacked = f end
		end
	end

	check("a charged item is drawn", charged ~= nil,
		"Lesser Mana Oil is in the bags for the whole run")
	check("with its charges in the corner, not an empty one",
		charged and tostring(charged.count.__text) == "5",
		charged and tostring(charged.count.__text) or "no button")
	check("and an ordinary stack still shows how many there are", stacked ~= nil,
		"the charges displaced the count rather than joining it")
end

-- Clicking a slot opens the real container - for the member being played, since a bag of
-- somebody else's is a picture and clicking a picture of a bag cannot open it.
local openedBag, openedBackpack, toggled

-- The client's own answer to whether a bag is open, which is what Family asks rather than
-- handing the whole question to ToggleBag - that answered differently depending on which of
-- several frames the game had put the bag in, so a click opened, closed, or did nothing.
local bagsOpen = {}
IsBagOpen = function(bag) return bagsOpen[bag] end
OpenBag = function(bag) bagsOpen[bag] = true; openedBag = bag
	toggled = (toggled or 0) + 1 end
CloseBag = function(bag) bagsOpen[bag] = nil; toggled = (toggled or 0) + 1 end
OpenBackpack = function() bagsOpen[0] = true; openedBackpack = true
	toggled = (toggled or 0) + 1 end
CloseBackpack = function() bagsOpen[0] = nil; toggled = (toggled or 0) + 1 end

if backpackSlot then
	backpackSlot.__scripts.OnClick(backpackSlot)
	check("clicking a slot opens the bag it is in", bagsOpen[0] == true)
	backpackSlot.__scripts.OnClick(backpackSlot)
	check("and clicking it again shuts it rather than doing nothing visible",
		bagsOpen[0] == nil)
	backpackSlot.__scripts.OnClick(backpackSlot)
	check("and again opens it, every time, rather than sometimes",
		bagsOpen[0] == true)
	openedBackpack = nil

	toggled = nil
	backpackSlot.memberKey = "Somebody-Else"
	backpackSlot.__scripts.OnClick(backpackSlot)
	check("and clicking somebody else's bag opens nothing", toggled == nil)
	backpackSlot.memberKey = key
end

-- Every bag, not only the first one.
--
-- The backpack has calls of its own - OpenBackpack, CloseBackpack - and the other four do
-- not, so a check that only ever clicked the backpack proved nothing about any of them. In
-- the game the backpack opened and none of the rest did, and this file was perfectly happy.
local carriedSlot
for _, f in ipairs(frames) do
	if f.__shown == true and f.block and f.block.where == "bags"
		and f.block.bag == 1 and f.itemID then
		carriedSlot = f
	end
end
check("a bag that is not the backpack is drawn too, with what is in it",
	carriedSlot ~= nil)

if carriedSlot then
	carriedSlot.__scripts.OnClick(carriedSlot)
	check("and clicking a slot in it opens that bag", bagsOpen[1] == true)
	carriedSlot.__scripts.OnClick(carriedSlot)
	check("and again shuts it", bagsOpen[1] == nil)

	-- The client that caused this. OpenBag and CloseBag are written in the game's own Lua
	-- rather than built into the engine, and that file is rewritten between expansions -
	-- so a client can have OpenBackpack and not OpenBag, and Family must still show the
	-- bag rather than doing nothing and saying nothing.
	local realOpenBag, realCloseBag = OpenBag, CloseBag
	local toggledBag, openedEverything
	OpenBag, CloseBag = nil, nil
	ToggleBag = function(bag) toggledBag = bag; bagsOpen[bag] = not bagsOpen[bag] end

	carriedSlot.__scripts.OnClick(carriedSlot)
	check("a client without OpenBag still gets the bag shown", toggledBag == 1,
		tostring(toggledBag))

	-- And one with neither. Opening every bag at once is the wrong shape for a click that
	-- named one, and it is still better than a click that does nothing.
	ToggleBag = nil
	bagsOpen[1] = nil
	OpenAllBags = function() openedEverything = true end
	carriedSlot.__scripts.OnClick(carriedSlot)
	check("and a client with neither falls back to opening all of them",
		openedEverything == true)

	OpenBag, CloseBag = realOpenBag, realCloseBag
	ToggleBag, OpenAllBags = nil, nil
	bagsOpen[1] = nil
end

if mailSlot then
	openedBag, openedBackpack, toggled = nil, nil, nil
	mailSlot.__scripts.OnClick(mailSlot)
	check("the mail has no container to open, and opening it is not attempted",
		openedBag == nil and openedBackpack == nil and toggled == nil)
end

-- Opening a profession from Family. An addon may not cast a spell, and may set up a button
-- that casts one when a player clicks it - so the button carries the name of the spell that
-- opens the profession, which Family wrote down the last time that window was open.
Family.UI:ShowProfessionFor(key, "Blacksmithing")

local professionButton, recipeButton
for _, f in ipairs(frames) do
	-- Found by different things, because they are different things now. Only the
	-- profession button casts, so only it is armed; a recipe row is identified by the
	-- recipe it carries. Asking for "armed and carrying a recipe" found nothing at all
	-- and would have gone quietly green.
	if f.__shown == true and f.recipeName then
		recipeButton = recipeButton or f
	elseif f.__shown == true and f.__attributes and f.__attributes.spell then
		professionButton = professionButton or f
	end
end

check("the profession button is armed with the spell that opens it",
	professionButton ~= nil
		and professionButton.__attributes.spell == "Blacksmithing",
	professionButton and tostring(professionButton.__attributes.spell))
check("and a recipe row knows whether there is a window to open",
	recipeButton ~= nil, recipeButton and recipeButton.recipeName)

-- Armed is not the same as able. Attributes on a plain frame are decoration: the game reads
-- them off secure action buttons and nothing else, and the profession buttons had had the
-- template's own OnClick - which is where the casting happens - replaced by Family's.
check("the profession button is a secure action button, or nothing will cast",
	professionButton ~= nil and isSecure(professionButton),
	professionButton and tostring(professionButton.__template))
check("and it has not had the template's own OnClick taken away",
	professionButton ~= nil and professionButton.__scripts.OnClick == nil)

-- And nothing in the recipe list is secure, or has anything secure inside it.
--
-- This is a rule about where a frame lives, not about what it does. The rows sit in a scroll
-- frame's child and are moved on every draw, and the game refuses to anchor a protected frame
-- in there at all - "cannot anchor protected frames to regions", out of combat and in. Both
-- shapes were tried in game and both died: the row made secure, and an ordinary row with a
-- secure child over it, because a frame with a protected child is protected itself.
local function anythingSecureBeneath(frame)
	if isSecure(frame) then return true end
	for _, f in ipairs(frames) do
		if f.__parent == frame and anythingSecureBeneath(f) then return true end
	end
	return false
end

check("nothing in the scrolling recipe list is protected, or the panel cannot draw",
	recipeButton ~= nil and not anythingSecureBeneath(recipeButton),
	recipeButton and tostring(recipeButton.__template))

wipe(cast)
if professionButton then fireClick(professionButton) end
check("so clicking a profession casts the spell that opens it",
	cast[1] == "Blacksmithing", table.concat(cast, ","))
check("and still chooses that profession in the panel", visibleText("Runed Copper Breastplate"))

-- The line above the list, which said "129 241/300" on a live client: the profession arrives
-- as the skill line it is keyed by and was printed as the number it is.
do
	local heading
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find("recipes", 1, true)
			and f.__text:find("seen", 1, true) then
			heading = f.__text
		end
	end
	check("the list's own heading names the profession rather than its skill line",
		heading ~= nil and heading:find("Blacksmithing", 1, true) ~= nil
			and heading:find("164", 1, true) == nil,
		tostring(heading))
end

-- A recipe clicked with nothing open cannot open anything itself. It is remembered for the
-- button that can, and the panel says which button that is rather than looking broken.
TRADE_SKILL_OPEN = false
wipe(cast)
if recipeButton then fireClick(recipeButton) end
check("clicking a recipe with nothing open casts nothing at all", #cast == 0,
	table.concat(cast, ","))
check("and says which button will open it", visibleText("is waiting"))

-- Which button, by its name. The profession arrives here as the skill line it is keyed by,
-- and the message read "Click 333 above to open the window", which is not something anybody
-- can act on.
do
	local said
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find("is waiting", 1, true) then
			said = f.__text
		end
	end
	-- The row stays marked, because the message tells you to move the mouse somewhere
	-- else and a highlight that follows the mouse is gone by the time you get there.
	local marked, others = 0, 0
	for _, f in ipairs(frames) do
		if f.waiting and f.__shown ~= false and type(f.recipeName) == "string" then
			if f.waiting.__visible == true then marked = marked + 1 else others = others + 1 end
		end
	end
	check("the recipe that is waiting stays marked once the mouse has gone",
		marked == 1, tostring(marked) .. " marked, " .. tostring(others) .. " not")

	check("and names that button rather than printing its skill line number",
		said ~= nil and said:find("Blacksmithing", 1, true) ~= nil
			-- 164 is blacksmithing. Written out because SKILL is scoped to the section
			-- that reads the skill list, and this is a long way below it.
			and said:find("164", 1, true) == nil,
		tostring(said))
end

local selectedOnArrival
SelectTradeSkill = function(index) selectedOnArrival = index end
TRADE_SKILL_OPEN = true
fire("TRADE_SKILL_SHOW")
advance(1)
check("and the recipe that was clicked is selected once the window has arrived",
	selectedOnArrival ~= nil, tostring(selectedOnArrival))

-- Not for somebody else's profession: their window is not going to open on this computer.
local other = Family.Database:Meta("Other-FireMaw")
Family.Database:SetMeta("Other-FireMaw", { skills = { [164] = { name = "Blacksmithing",
	rank = 100, maxRank = 300 } } })
Family.Database:SetPayload("Other-FireMaw", { professions = { [164] = {
	recipesSeen = time(), openWith = "Blacksmithing",
	recipes = { { name = "Runed Copper Breastplate", difficulty = "medium" } } } } })
Family.UI:ShowProfessionFor("Other-FireMaw", "Blacksmithing")

local armedForOther = false
for _, f in ipairs(frames) do
	-- The row's shown state, not the child's. A secure child is never hidden by name -
	-- it disappears because its parent does - so asking the child made every pooled row
	-- ever drawn count as on screen.
	local owner = type(f.__parent) == "table" and f.__parent or nil
	if owner and owner.__shown == true and owner.recipeName and f.__attributes
		and f.__attributes.spell then
		armedForOther = true
	end
end
check("a recipe of another member's is not armed to cast anything",
	armedForOther == false)

-- Put back the way it was found. Other-FireMaw's job in the rest of this file is to be a
-- member with meta and no payload at all, which is the shape every panel has to cope with.
Family.Database:SetPayload("Other-FireMaw", nil)
Family.Database:SetMeta("Other-FireMaw", other)

-- A profession with nothing in it gets no button here. Herbalism makes nothing and never
-- will, and a button leading to an empty list costs a click every time somebody tries it to
-- find that out again - the summary is where "who has herbalism, and how far" is answered.
--
-- It still has to be said out loud, or the panel is simply missing a profession the player
-- knows they have, and there is no telling that from Family having lost it.
Family.UI:ShowProfessionFor(key, "Blacksmithing")

local function professionButtonNamed(name)
	for _, f in ipairs(frames) do
		if f.__shown == true and type(f.__text) == "string"
			and f.__text:find(name, 1, true) and isSecure(f) then
			return f
		end
	end
	return nil
end

check("a profession that makes nothing is given no button",
	professionButtonNamed("Herbalism") == nil)
check("one that does keeps its button", professionButtonNamed("Blacksmithing") ~= nil)
check("and the ones left out are named, with the reason", visibleText("Herbalism")
	and visibleText("Not listed"))

-- The two reasons are still two different facts (§2.2). A window Family has opened and found
-- empty is not the same as one it has never opened, and it does not say it is.
--
-- Said as what was seen rather than as what it means. "Makes nothing" is a claim about the
-- character and is right for herbalism; for a crafting profession behind an addon that
-- filters or replaces the window it is wrong, and reading it as the truth is what sent
-- somebody hunting a fault in Family for an evening.
local testerSkills = Family.Database:Meta(key).skills
testerSkills.Tailoring = { rank = 40, maxRank = 75 }
Family.Database:Payload(key).professions.Tailoring = { recipesSeen = time(), recipes = {} }
Family.UI:ShowProfessionFor(key, "Blacksmithing")
check("a window opened and found empty says so",
	visibleText("Tailoring opened, and listed nothing"))
check("and names the likeliest reason beside it",
	visibleText("another addon filtering or replacing that window"))
check("and one never opened says that instead", visibleText("Herbalism never opened"))

testerSkills.Tailoring = nil
Family.Database:Payload(key).professions.Tailoring = nil

Family.UI:ShowProfessionFor(key, "Blacksmithing")

-- Clicking a recipe finds it in the window that is open. Nothing opens the window by itself:
-- an addon casting a spell of its own accord is what the game refuses.
local selectedRecipe
SelectTradeSkill = function(index) selectedRecipe = index end
TRADE_SKILL_OPEN = true

check("clicking a recipe selects it in the open window",
	Family.UI:SelectRecipe(key, "Blacksmithing", "Runed Copper Breastplate") == true
		and selectedRecipe ~= nil, tostring(selectedRecipe))

selectedRecipe = nil
check("a recipe of somebody else's selects nothing",
	Family.UI:SelectRecipe("Somebody-Else", "Blacksmithing", "Runed Copper Breastplate") == false)
check("and a profession whose window is shut selects nothing",
	Family.UI:SelectRecipe(key, "Tailoring", "Bolt of Linen Cloth") == false)

-- The window's own name is not checked against the profession's. The craft frame is titled
-- one thing and belongs to a skill line called another, so enchanting never matched itself -
-- and a member scanned on a French client has the profession under a different name again.
selectedRecipe = nil
check("a recipe is found in the open window whatever that window calls itself",
	Family.UI:SelectRecipe(key, "Forgeage", "Runed Copper Breastplate") == true
		and selectedRecipe ~= nil, tostring(selectedRecipe))

TRADE_SKILL_OPEN = false

-- Every list that names something the game can describe opens its tooltip on hover, and the
-- ones it cannot describe - a faction, a talent in a tree - show what Family recorded rather
-- than nothing at all. Checked by hovering a real row in each panel and reading back what
-- the tooltip was asked for.
-- A row is hovered through whatever frame the cursor is actually over, which for the
-- profession rows is a secure child covering the row. So the match is offered the frame that
-- carries what is being looked for - the row - and the hover goes to whatever has the script.
local function hoverRow(match)
	for _, f in ipairs(frames) do
		local carrier = (f.__scripts.OnEnter and type(f.__parent) == "table"
			and match(f.__parent)) and f.__parent or nil
		if carrier and (carrier.__shown ~= false) then
			GameTooltip.__shownAs = nil
			wipe(GameTooltip.__lines)
			f.__scripts.OnEnter(f)
			return GameTooltip.__shownAs, #GameTooltip.__lines
		end
		if f.__shown == true and f.__scripts.OnEnter and match(f) then
			GameTooltip.__shownAs = nil
			wipe(GameTooltip.__lines)
			f.__scripts.OnEnter(f)
			return GameTooltip.__shownAs, #GameTooltip.__lines
		end
	end
	return nil, 0
end

Family.UI:ShowTab("character")
clickButton("Equipped gear")
local shownAs, lineCount = hoverRow(function(f) return f.slotName ~= nil and f.itemID end)
check("hovering a worn item opens the game's own item tooltip",
	shownAs and shownAs.kind == "item", shownAs and shownAs.kind)

-- And it describes what they are wearing, not what they bought.
--
-- An id names the item off the vendor's shelf. What is on the character is that item plus
-- its enchant, its gems and its patch, and none of that is in the id - so a tooltip drawn
-- from the id alone described a weapon nobody owns. The item string carries all of it, and
-- is still nothing but numbers, so §2.1 is untouched.
do
	local chest
	for _, f in ipairs(frames) do
		if f.__shown == true and f.slotName and f.itemID == 4005 then chest = f end
	end

	check("a worn item is recorded with its enchant and its gems, not only its id",
		chest ~= nil and chest.itemLink == "item:4005:2661:3000:3001:0:0:0:0:60",
		chest and tostring(chest.itemLink))

	if chest then
		GameTooltip.__shownAs = nil
		wipe(GameTooltip.__lines)
		chest.__scripts.OnEnter(chest)
		check("and its tooltip is asked for by that, so the enchant is on it",
			GameTooltip.__shownAs and GameTooltip.__shownAs.kind == "item"
				and GameTooltip.__shownAs.enchant == 2661,
			GameTooltip.__shownAs and tostring(GameTooltip.__shownAs.enchant))
	end
end

-- Drawn as a character sheet rather than as a list: a slot per slot, in the arrangement the
-- game uses, so an empty shoulder is an empty square where a shoulder goes.
local worn, empty = 0, 0
for _, f in ipairs(frames) do
	if f.__shown == true and f.slotName then
		if f.itemID then worn = worn + 1 else empty = empty + 1 end
	end
end
check("every slot of the character sheet is drawn, worn or not", worn + empty == 19,
	tostring(worn) .. " worn and " .. tostring(empty) .. " empty")
check("with something in at least one of them", worn > 0, tostring(worn))

-- The middle says who they are, because there is no model of somebody who is not logged in
-- and a blank space says less than a name does.
check("and the middle names the member, their class, their race and their side",
	visibleText("Tester") and visibleText("Mage") and visibleText("Gnome")
		and visibleText("Horde"))

-- Borrowed rows have to go back as they were found: the gear section moves one into the
-- middle of the sheet, and the section after it would otherwise inherit that.
clickButton("Reputations")
clickButton("Equipped gear")
check("and the sections after it are unharmed by the borrowing",
	visibleText("Tester"))

-- One member's currencies in full, which is what the summary's columns cannot be: there is
-- room here for the cap and how far off it is.
do
	-- The character panel's own section, which is the last button with that name - the
	-- summary's column set was built first and carries the same word.
	local found
	for _, f in ipairs(frames) do
		if f.__text == "Currencies" and f.__scripts.OnClick then found = f end
	end
	check("the character panel has a currencies section", found ~= nil)
	if found then found.__scripts.OnClick(found) end
	check("the character panel lists one member's currencies", visibleText("Honor"))
	check("with what they hold", visibleText("12340"))
	-- Nothing in the game is capped at nought. Honor on this pretend client has no cap at
	-- all, and a ceiling of zero would report it as permanently full.
	check("and says outright where there is no cap", visibleText("no cap"))
end

clickButton("Quests")
shownAs = hoverRow(function(f) return f.questID ~= nil end)
check("and hovering a quest opens the quest tooltip",
	shownAs and shownAs.kind == "quest", shownAs and shownAs.kind)

clickButton("Reputations")
shownAs, lineCount = hoverRow(function(f) return f.fallback ~= nil end)
check("a faction, which the game will not describe, shows what Family knows instead",
	shownAs == nil and lineCount > 0, tostring(lineCount))

-- Matched by the id itself rather than by "has one". Rows are pooled per panel and only
-- hidden when spare, so a row belonging to a panel nobody is looking at is still a shown
-- frame - and searching for "any row with a spell" finds the spellbook's.
Family.UI:ShowTab("professions")

-- Both readings of a recipe, and CTRL chooses.
--
-- A row knows the spell that makes something and the item it makes. It used to show whichever
-- it found first, which was the spell - so every profession read as the recipe and enchanting,
-- which makes no item, agreed with the rest by accident. Asked for as *hovering gives the item,
-- hovering with CTRL held gives the recipe*, and the modifier is measured here rather than the
-- variable behind it because a player presses a key.
local heldControl = _G.IsControlKeyDown
_G.IsControlKeyDown = function() return false end

shownAs = hoverRow(function(f) return f.spellID == 2667 end)
check("hovering a recipe opens the tooltip for what it makes",
	shownAs and shownAs.kind == "item", shownAs and shownAs.kind)

_G.IsControlKeyDown = function() return true end
shownAs = hoverRow(function(f) return f.spellID == 2667 end)
check("and with CTRL held, for the recipe itself",
	shownAs and shownAs.kind == "spell", shownAs and shownAs.kind)

-- And the row says so, because a reading you only find by holding a key you had no reason to
-- hold is a reading nobody finds.
do
	local said = ""
	for _, line in ipairs(GameTooltip.__lines) do said = said .. " " .. tostring(line[1]) end
	check("and the row says the key is there to press",
		said:find(Family.L["|cff888888CTRL swaps the recipe and what it makes|r"],
			1, true) ~= nil, said)
end

-- The whole point, and the thing three probes were spent on: pressing the key with the pointer
-- held still repaints. Family does not reach into the tooltip to do it - it asks the row the
-- pointer is on to draw its own tooltip again, and the row decides what the key now means.
-- Measured because a tooltip that only changes when the mouse moves is a trick rather than a
-- feature.
do
	_G.IsControlKeyDown = function() return false end
	shownAs = hoverRow(function(f) return f.spellID == 2667 end)
	check("hovering again without the key gives what it makes", shownAs
		and shownAs.kind == "item", shownAs and shownAs.kind)

	-- Driven the way the client drives it: the watcher is a frame that is shown while the
	-- pointer is on a row, so its OnUpdate is what notices the key. It used to be an event,
	-- and the event is exactly what a focused search box eats - see the comment over the
	-- watcher, and the day it cost.
	local watcher = Family.UI.__tooltipModifiers

	-- That it watches at all, said before anything drives it. Without this the mutation that
	-- puts the event back does not fail a check - it takes the whole harness down on a nil
	-- OnUpdate, which is a crash and not a measurement.
	check("the key is watched rather than awaited",
		watcher and watcher.__scripts.OnUpdate ~= nil and watcher.__events == nil
			or (watcher and watcher.__scripts.OnUpdate ~= nil
				and not watcher.__events["MODIFIER_STATE_CHANGED"]),
		"an event is eaten by a focused box; a watch is not")

	check("the watcher is running while the pointer is on a row",
		watcher and watcher.__shown == true, tostring(watcher and watcher.__shown))

	-- Guarded, so that a mutation which takes the watch away is *reported* by the check
	-- above and does not also take the rest of this file down with a nil call.
	local function tick()
		if watcher and watcher.__scripts.OnUpdate then
			watcher.__scripts.OnUpdate(watcher, 0)
		end
	end

	_G.IsControlKeyDown = function() return true end
	GameTooltip.__shownAs = nil
	wipe(GameTooltip.__lines)
	tick()

	check("and pressing it repaints without the pointer moving",
		GameTooltip.__shownAs and GameTooltip.__shownAs.kind == "spell",
		GameTooltip.__shownAs and GameTooltip.__shownAs.kind)

	-- And it notices a *change* rather than a state, or every frame would repaint the
	-- tooltip for as long as the key is held.
	GameTooltip.__shownAs = nil
	tick()
	check("while holding it changes nothing further",
		GameTooltip.__shownAs == nil, tostring(GameTooltip.__shownAs))

	-- Letting go is a change too, and puts back what the row says without it.
	_G.IsControlKeyDown = function() return false end
	tick()
	check("and letting go puts back what it makes",
		GameTooltip.__shownAs and GameTooltip.__shownAs.kind == "item",
		GameTooltip.__shownAs and GameTooltip.__shownAs.kind)

	-- **And it works while the search box has the keyboard**, which is the fault this
	-- mechanism exists for and the one thing the old one could not do. The event never
	-- arrives then - the stub refuses to deliver it now, for the reason written over
	-- `fire` - so a watcher that listened would be silent here and this would go red.
	do
		local box = _G.FamilyProfessionsSearch
		check("the panel's search box is there to be typed into", box ~= nil)

		if box then
			box:SetFocus()
			check("and it has the keyboard", box:HasFocus() == true)

			-- Said out loud: the event really is gone in this state, which is why the
			-- watcher does not use one.
			GameTooltip.__shownAs = nil
			fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
			check("the modifier event does not arrive while it does",
				GameTooltip.__shownAs == nil, tostring(GameTooltip.__shownAs))

			_G.IsControlKeyDown = function() return true end
			tick()
			check("and the swap happens anyway, because the key is watched not awaited",
				GameTooltip.__shownAs and GameTooltip.__shownAs.kind == "spell",
				GameTooltip.__shownAs and GameTooltip.__shownAs.kind)

			_G.IsControlKeyDown = function() return false end
			tick()
			box:ClearFocus()
		end
	end

	-- Arriving on a row with the key already held is not a press. The row's own resolver
	-- has already taken the key into account by then, so a watcher that had not seeded
	-- itself would repaint on its first tick - once per row entered, for ever.
	do
		_G.IsControlKeyDown = function() return true end
		hoverRow(function(f) return f.spellID == 2667 end)

		GameTooltip.__shownAs = nil
		tick()
		check("arriving with the key already held is not a press",
			GameTooltip.__shownAs == nil, tostring(GameTooltip.__shownAs))
		_G.IsControlKeyDown = function() return false end
	end

	-- And it stops when the pointer goes. A frame runs OnUpdate while it is shown, so this
	-- is the whole of the cost control - and a watcher left running is one that repaints a
	-- row nobody is pointing at.
	do
		local row
		for _, f in ipairs(frames) do
			if f.__shown ~= false and f.spellID == 2667 and f.__scripts.OnLeave then
				row = f
			end
		end
		check("the row that was hovered can be left", row ~= nil)
		if row then
			row.__scripts.OnEnter(row)
			check("entering starts the watch", watcher.__shown == true)
			row.__scripts.OnLeave(row)
			check("and leaving stops it", watcher.__shown == false,
				tostring(watcher.__shown))
		end
	end
end

-- A recipe with no product - every enchant - has nothing to swap to, and says nothing about a
-- key that would do nothing. An offer to swap that swaps to the same tooltip is worse than no
-- offer at all.
_G.IsControlKeyDown = heldControl

Family.UI:ShowTab("talents")
shownAs, lineCount = hoverRow(function(f)
	return f.fallback and f.fallback[1] and f.fallback[1][1] == "Arcane Subtlety"
end)
-- A talent in a tree has no id to ask about, so it is asked for by the position it sits at.
-- That it answers at all is the point: this used to be Family's own three lines every time,
-- on every client, because the one call it made was silently the wrong one.
check("and a talent in a tree is described by the game, not by Family",
	shownAs and shownAs.kind == "talent",
	shownAs and shownAs.kind or ("fallback, " .. tostring(lineCount) .. " lines"))

Family.UI:ShowTab("contents")
shownAs = hoverRow(function(f) return f.itemID ~= nil end)
check("hovering a possession opens its item tooltip",
	shownAs and shownAs.kind == "item", shownAs and shownAs.kind)

-- Searching the whole family rather than one member. Two different questions - "what is this
-- member carrying" and "who has one of these" - and the second wants a name against every
-- line, so the panel changes shape rather than pretending bags fit.
Family.UI:ShowTab("contents")
local contentsEveryone = _G.FamilyContentsEveryone
check("possessions offers a whole-family search", contentsEveryone ~= nil)

if contentsEveryone then
	contentsEveryone.__scripts.OnClick(contentsEveryone)
	check("and with nothing typed it asks for something to search for",
		visibleText("at least two letters"))

	-- The empty panel is the mode working, not the mode broken - but only if the caption
	-- over the box says which of its two jobs it is doing. "dim everything but" above a
	-- screen with nothing left on it to dim is how this came to be reported as a blank page.
	check("and the caption says it is searching rather than dimming",
		visibleText("find across the family") and not visibleText("dim everything but"))

	-- The filter row is on a line of its own, and something below it made the room.
	--
	-- Both halves shipped wrong and neither was visible here. The container was given a
	-- height and never a width - the arithmetic for it existed, in `filters:Width()`, and
	-- nothing called it - and the row was anchored under the search box, which sits *beside*
	-- the member picker rather than under it, so it shared a line with a caption that runs
	-- the full width of the panel while nothing below reserved any space. Reported from play
	-- with a screenshot of the panel switched to the whole family and no filters on it.
	--
	-- Read off `__width` rather than `GetWidth`, which answers a default of 800 for a frame
	-- nobody sized: the question is what the panel decided, and a stub that answers for it
	-- turns this into a check that cannot fail.
	--
	-- The made-room half is structural because there is no geometry here: it asks whether
	-- anything is anchored to the row. Nothing inside the widget anchors to its own
	-- container, so today an entry means something outside it did.
	local contentsFilters = Family.UI.__contentsFilters
	check("possessions has a filter row", contentsFilters ~= nil)

	if contentsFilters then
		check("and it is shown while the panel is about everybody",
			contentsFilters.frame:IsShown() == true)
		check("and it was given a width as well as a height",
			type(contentsFilters.frame.__width) == "number"
				and contentsFilters.frame.__width > 0,
			tostring(contentsFilters.frame.__width))
		check("and what comes below hangs off it, which is what makes the room",
			next(contentsFilters.frame.__anchoredBy or {}) ~= nil)
	end

	_G.FamilyContentsSearch:SetText("Linen")
	Family.UI:Refresh()

	check("typing finds the item wherever in the family it is",
		visibleText("Linen Cloth"))
	check("and says who has it, which is the whole point of asking everybody",
		visibleText("Tester"))

	_G.FamilyContentsSearch:SetText("")
	contentsEveryone.__scripts.OnClick(contentsEveryone)

	check("and switching back gives the box its other job again",
		visibleText("dim everything but"))
end

-- The same question of the professions: who can make this.
Family.UI:ShowTab("professions")
local professionsEveryone = _G.FamilyProfessionsEveryone
check("professions offers a whole-family search too", professionsEveryone ~= nil)

if professionsEveryone then
	professionsEveryone.__scripts.OnClick(professionsEveryone)

	_G.FamilyProfessionsSearch:SetText("Copper")
	Family.UI:Refresh()

	check("a recipe is found by name across every profession of every member",
		visibleText("Runed Copper Breastplate"))
	-- Not "Runeforging", which the same recipe is also filed under here: where a recipe is
	-- held under both a real profession and one the client's table has never heard of, the
	-- identified one is the label.
	check("with the profession it belongs to", visibleText("Blacksmithing"))
	check("and everybody who can make it", visibleText("Tester"))

	-- The caption for the sort buttons goes away with them.
	--
	-- It is parented to the panel rather than to the bar it describes, because it is anchored
	-- across the bar's right-hand end - so putting the bar away left the caption behind,
	-- reading "Hardest first" over a list that the whole-family search orders by name
	-- (`Family/Recipes.lua` sorts `order` on the name). A caption with no controls under it
	-- is read as a description of the list, which made it a wrong one. Reported from play.
	local sortNote = Family.UI.__professionsSortNote
	check("professions exposes the sort caption", sortNote ~= nil)
	if sortNote then
		-- The bar stays across the family now, carrying its other row of buttons, so the
		-- caption stays with it. What has to be true is that it is describing one of *those*
		-- orders: it used to be left behind by buttons that had gone, reading "Hardest
		-- first" over a list that comes back in name order.
		check("and it is there together with the buttons it describes",
			sortNote:IsShown() == true)
		-- The caption is a child of the panel rather than of the bar, so a second line is
		-- drawn *below* the bar - in the band the status line is anchored in. Whether it
		-- wraps at all depends on the language, so the rule is that the bar is at least as
		-- tall as the caption, not that the caption fits in a number.
		check("and the bar is at least as tall as the caption it carries",
			(Family.UI.__professionsSort.bar.__height or 0)
				>= math.ceil(sortNote:GetStringHeight() or 0),
			tostring(Family.UI.__professionsSort.bar.__height) .. " against "
				.. tostring(sortNote:GetStringHeight()))
		check("and it describes an order this list can actually be put in",
			(sortNote:GetText() or ""):find(
				Family.L["By name, which is the order the search itself comes back in."],
				1, true) ~= nil,
			tostring(sortNote:GetText()))
		check("and never one that needs a field these rows do not carry",
			(sortNote:GetText() or ""):find(Family.L["Hardest first. Within a colour, the "
				.. "ones that took the most skill to learn."], 1, true) == nil)
	end

	-- The filter row is on a line of its own, and something below it made the room.
	--
	-- Both halves shipped wrong and neither was visible here. The container was given a
	-- height and never a width - the arithmetic for it existed, in `filters:Width()`, and
	-- nothing called it - and the row was anchored under the search box, which sits *beside*
	-- the member picker rather than under it, so it shared a line with a caption that runs
	-- the full width of the panel while nothing below reserved any space. Reported from play
	-- with a screenshot of the panel switched to the whole family and no filters on it.
	--
	-- Read off `__width` rather than `GetWidth`, which answers a default of 800 for a frame
	-- nobody sized: the question is what the panel decided, and a stub that answers for it
	-- turns this into a check that cannot fail.
	--
	-- The made-room half is structural because there is no geometry here: it asks whether
	-- anything is anchored to the row. Nothing inside the widget anchors to its own
	-- container, so today an entry means something outside it did.
	local professionsFilters = Family.UI.__professionsFilters
	check("professions has a filter row", professionsFilters ~= nil)

	if professionsFilters then
		check("and it is shown while the panel is about everybody",
			professionsFilters.frame:IsShown() == true)
		check("and it was given a width as well as a height",
			type(professionsFilters.frame.__width) == "number"
				and professionsFilters.frame.__width > 0,
			tostring(professionsFilters.frame.__width))
		check("and what comes below hangs off it, which is what makes the room",
			next(professionsFilters.frame.__anchoredBy or {}) ~= nil)
	end

	-- Three members added so that the three orders give three different pages.
	--
	-- Two smiths who know Silver Rod, which is second by name, so the recipe with the most
	-- crafters is not the one that was already first. And a tailor, because the two
	-- professions already here sort the same way by their skill line id as by their word -
	-- 164 before 333, Blacksmithing before Enchanting - and tailoring is 197, which falls
	-- between them by id and after both by name. Without that a sort on the raw key and a
	-- sort on the word the reader sees are the same page.
	--
	-- The first attempt at this added enchanters who knew the same recipe, and it quietly
	-- undid something else: the enchant is recorded in French in this fixture, and a second
	-- record of it put the English name on the row - which is the one thing the name order
	-- has to be read against. Two mutations went uncaught until that was noticed.
	for _, who in ipairs { "Rodder", "Roddertwo" } do
		Family.Database:SetMeta(who .. "-FireMaw", { name = who, realm = "Fire Maw",
			level = 60, classFile = "WARRIOR",
			skills = { [164] = { rank = 300, maxRank = 300 } } })
		Family.Database:SetPayload(who .. "-FireMaw", { professions = { [164] = {
			rank = 300, maxRank = 300, recipesSeen = time(),
			recipes = { { name = "Silver Rod", spellID = 3339, itemID = 6338 } } } } })
	end

	Family.Database:SetMeta("Stitcher-FireMaw", { name = "Stitcher", realm = "Fire Maw",
		level = 60, classFile = "MAGE",
		skills = { [197] = { rank = 300, maxRank = 300 } } })
	Family.Database:SetPayload("Stitcher-FireMaw", { professions = { [197] = {
		rank = 300, maxRank = 300, recipesSeen = time(),
		recipes = { { name = "Stitched Cloak", itemID = 6338 } } } } })

	------------------------------------------------------------------------------------
	-- And in an order the player chose
	--
	-- Three orders and a fixture for each that tells it apart from the other two. On "er"
	-- the two professions happen to fall in the same order as the names, so that needle can
	-- only show the crafter count; "st" is the pair where profession and name disagree. A
	-- check run on one needle alone would have passed for all three orders and proved none,
	-- which is also why the two enchanters above are there: without them the recipe with the
	-- most crafters was already first by name.
	------------------------------------------------------------------------------------

	local sort = Family.UI.__professionsSort
	check("professions offers the orders a family's list can be put in", sort ~= nil
		and sort.buttons.recipename ~= nil and sort.buttons.recipeprofession ~= nil
		and sort.buttons.crafters ~= nil)

	if sort then
		-- And puts away the ones that ask about a field these rows do not carry. A recipe's
		-- colour is what one character sees; across forty there are forty answers, and
		-- `Family/Recipes.lua` puts none of them on a whole-family row.
		check("and puts away the ones that ask about one character's own view",
			sort.buttons.difficulty:IsShown() == false
				and sort.buttons.skill:IsShown() == false
				and sort.buttons.itemlevel:IsShown() == false)

		local function page()
			local out = {}
			for _, recipe in ipairs(Family.UI.__professionsFound or {}) do
				out[#out + 1] = tostring(Family.Names:Recipe(recipe) or recipe.name)
			end
			return table.concat(out, " | ")
		end

		local function searchFor(needle)
			_G.FamilyProfessionsSearch:SetText(needle)
			Family.UI:Refresh()
		end

		local function choose(id)
			sort.buttons[id].__scripts.OnClick(sort.buttons[id])
		end

		choose("recipename")
		searchFor("er")
		check("by name, which is the order the search itself answers in",
			page() == "Runed Copper Breastplate | Silver Rod | Wizard Oil", page())

		choose("crafters")
		check("by how many of the family can make it, most first",
			page() == "Silver Rod | Runed Copper Breastplate | Wizard Oil", page())

		-- The pair the professions disagree with the names about, which is the only place
		-- the profession order can be read at all.
		searchFor("st")
		choose("recipename")
		check("by name again, on three the professions put another way",
			page() == "Enchant Chest - Major Health | Runed Copper Breastplate | "
				.. "Stitched Cloak", page())

		choose("recipeprofession")
		-- Blacksmithing, Enchanting, Tailoring - the words. By the skill line ids behind
		-- them it would be 164, 197, 333, which puts the tailor in the middle: the one
		-- fixture arrangement that tells the two apart.
		check("and by profession, which is the word rather than the key behind it",
			page() == "Runed Copper Breastplate | Enchant Chest - Major Health | "
				.. "Stitched Cloak", page())

		-- And the bar holds whichever caption is on it, asked of all three for the reason
		-- the possessions panel's is: only one of them wraps at these metrics, and which
		-- one depends on the language.
		local tallEnough, worst = true, ""
		for _, id in ipairs { "recipename", "recipeprofession", "crafters" } do
			choose(id)
			local needed = math.ceil(sort.note:GetStringHeight() or 0)
			if (sort.bar.__height or 0) < needed then
				tallEnough = false
				worst = id .. ": " .. tostring(sort.bar.__height)
					.. " against " .. tostring(needed)
			end
		end
		check("and the bar is at least as tall as whichever caption is on it",
			tallEnough, worst)

		choose("recipename")
	end

	_G.FamilyProfessionsSearch:SetText("")
	professionsEveryone.__scripts.OnClick(professionsEveryone)

	for _, who in ipairs { "Rodder", "Roddertwo", "Stitcher" } do
		Family.Database:Forget(who .. "-FireMaw")
	end
	Family.UI:Refresh()
end

-- The spellbook has moved in with the talents, and is sorted by name rather than left in
-- the order the client hands the ids over. The rows are created top to bottom, so which was
-- made first is which is drawn higher.
Family.UI:ShowTab("talents")
clickButton("Spellbook")
check("the spellbook is sorted rather than left in the client's order",
	(frameShowing("Apprentice Riding") or math.huge)
		< (frameShowing("Zul'Gurub Ritual") or 0),
	tostring(frameShowing("Apprentice Riding")) .. " vs "
		.. tostring(frameShowing("Zul'Gurub Ritual")))

-- Each section runs entirely different code, and one that throws takes the panel with it,
-- so all four are visited rather than only the one that happens to open first.
Family.UI:ShowTab("character")
for _, name in ipairs { "Reputations", "Quests", "Equipped gear" } do
	local mark = #DEFAULT_CHAT_FRAME.messages
	local clicked = clickButton(name)
	local complained = false
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("failed to") then complained = true end
	end
	check("the " .. name:lower() .. " section draws", clicked and not complained,
		clicked and "panel complained" or "no button called " .. name)
end

-- Era has no achievements, so the section must not be offered at all - absent rather than
-- present and apologising for itself (§2.3).
check("no achievements button on a client without achievements",
	clickButton("Achievements") == false)


-- Opening the picker builds the shared list, filters it, and picks from it - the paths a
-- panel that is merely drawn never touches.
local opened = clickButton("Tester")
check("a member picker opens", opened or clickButton("Other"))

local list = _G.FamilyMemberPickerList
check("the shared list exists once opened", list ~= nil)
if list then
	check("and is showing", list:IsShown() == true)

	-- The list floats over whichever panel opened it. The bordered template draws an edge
	-- and nothing solid behind it, so the professions panel read straight through the names
	-- and neither could be made out. Geometry and alpha, which are checkable; what the
	-- texture would actually paint is not, here or anywhere.
	local fill
	for _, texture in ipairs(list.__textures or {}) do
		if texture.__allPoints and texture.__fill
			and (texture.__fill.a or 0) >= 0.9 then
			fill = texture
		end
	end
	check("and is drawn on something opaque, so the panel beneath does not read through",
		fill ~= nil)

	-- Every row was one ROW tall including the headings, so a heading sat flush against the
	-- last name above it and "shared by ..." read as one more member with an odd name. The
	-- list is taller than its rows exactly when it has left air above its headings.
	local shownRows, headings = 0, 0
	for _, row in ipairs(list.rows or {}) do
		if row:IsShown() then
			shownRows = shownRows + 1
			if row.__enabled == false then headings = headings + 1 end
		end
	end
	check("with more than one section on screen", headings > 1, tostring(headings))
	check("and air above each heading rather than rows packed flush",
		(list.list.__height or 0) > shownRows * 16,
		tostring(list.list.__height) .. " for " .. tostring(shownRows) .. " rows")

	local okFilter = pcall(function()
		list.search:SetText("oth")
		list:Rebuild()
	end)
	check("typing filters it", okFilter)

	local okNone = pcall(function()
		list.search:SetText("nobody by this name")
		list:Rebuild()
	end)
	check("and says so when nothing matches", okNone)

	local okAll = pcall(function()
		list.search:SetText("")
		list:Rebuild()
	end)
	check("clearing the filter restores it", okAll)

	-- Closing it without answering it.
	--
	-- Until now the only way out of this list was to choose somebody from it, which turns
	-- a list you opened to look at into a question you have to answer. Escape worked only
	-- while the search box had the cursor, and the realm and class lists had no way out at
	-- all. A sheet across the screen behind the list takes the click that lands anywhere
	-- else, which is how a menu in this game is normally dismissed.
	local sheet
	for _, f in ipairs(frames) do
		if f.__parent == UIParent and f.__scripts.OnClick and f.__shown == true
			and f.__kind == "Button" and f.popup == list then
			sheet = f
		end
	end

	check("a click anywhere else has something to land on", sheet ~= nil)
	if sheet then
		fireClick(sheet)
		check("and it puts the list away", list:IsShown() == false)
		check("and the sheet goes with it", sheet.__shown == false)
	end

	-- Escape, the way everything else in this game closes. The frame has to be on the
	-- game's own list for that, and being on it is the whole of what makes it work.
	local listed
	for _, name in ipairs(UISpecialFrames) do
		if name == "FamilyMemberPickerList" then listed = true end
	end
	check("and Escape closes it as well", listed == true)

	-- And the sheet goes away however the list went away, not only when the sheet itself
	-- was what closed it. Choosing somebody closes the list from the inside, and a sheet
	-- left behind then covers the whole screen and silently eats every click in the game
	-- until the next reload - a far worse fault than the one being fixed.
	--
	-- It is also the one this nearly shipped with. The hook that ties the two together is
	-- installed with HookScript, and MemberPicker does a SetScript on OnHide after the
	-- point where the hook first went in, which throws the hook away and keeps the frame
	-- looking perfectly correct.
	if sheet then
		list:Show()
		check("the sheet comes back with the list", sheet.__shown == true)
		list:Hide()
		check("and goes when the list is closed from the inside",
			sheet.__shown == false)
	end

	list:Hide()
end

Family.UI:ShowTab("summary")

-- Every column set, by clicking its button. Each one runs a different set of cell
-- functions, and a cell that throws takes the whole summary with it - so all four are
-- looked at rather than only the one that happens to be showing.
for _, label in ipairs { "Bags", "Professions", "Miscellaneous", "Overview" } do
	local clicked = clickButton(label)
	local complained = false
	for index = 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("failed to draw") then
			complained = true
		end
	end
	check("the " .. label:lower() .. " columns draw", clicked and not complained,
		clicked and "panel complained" or "no button called " .. label)
end

local before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("status")
check("/family status says something", #DEFAULT_CHAT_FRAME.messages > before)

before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("talents")
check("/family talents reports what is stored",
	#DEFAULT_CHAT_FRAME.messages > before)

-- Says whether a recipe has an id to be named by at all, which is the difference between a
-- display fault and a scan that has to be run again - and is not something this file can
-- answer about somebody else's saved data.
-- Which members have a bank record and what the client says about the bag in each bank
-- container. Reported from a live client: a bank that does not save, and a bag shown one slot
-- along from where it is. Neither is answerable from here - one is in somebody's saved data
-- and the other only exists while a bank window is open.
before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("bank")
check("/family bank reports what is recorded for every member",
	#DEFAULT_CHAT_FRAME.messages > before)

before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("recipes")
check("/family recipes reports what each recipe has to be named by",
	#DEFAULT_CHAT_FRAME.messages > before)

-- Whether the client can name a place from its id decides whether the hearthstone column can
-- ever be translated: the tables that would do it out of a file measure 876 KB (L-020), so
-- the only affordable answer is the client's own, and no file can say whether it has one.
--
-- What this can check is that the question gets asked and survives a client that answers
-- none of it - which is the case the harness is, having no map API at all. That it reports
-- the right thing about a real client is not checkable here and is the whole reason the
-- command exists.
before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("hearth")
check("/family hearth reports whether the client can name a place",
	#DEFAULT_CHAT_FRAME.messages > before)
check("and says so plainly when the client cannot",
	(function()
		for _, line in ipairs(DEFAULT_CHAT_FRAME.messages) do
			if type(line) == "string" and line:find("cannot be translated", 1, true) then
				return true
			end
		end
		return false
	end)())

before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("rescan")
check("/family rescan runs both scanners",
	#DEFAULT_CHAT_FRAME.messages > before)

-- A panel whose builder throws must say so rather than looking like a panel with no data.
before = #DEFAULT_CHAT_FRAME.messages
Family.UI:RegisterTab("broken", "Broken", function() error("deliberate") end)
Family.UI:ShowTab("broken")
local reported = false
for index = before + 1, #DEFAULT_CHAT_FRAME.messages do
	if DEFAULT_CHAT_FRAME.messages[index]:find("failed to build") then reported = true end
end
check("a panel that fails to build says so", reported)
Family.UI:ShowTab("summary")

before = #DEFAULT_CHAT_FRAME.messages
SlashCmdList["FAMILY"]("caps")
check("/family caps lists every capability",
	#DEFAULT_CHAT_FRAME.messages - before >= 10,
	tostring(#DEFAULT_CHAT_FRAME.messages - before) .. " lines")

-- Every capability reports where its answer came from, so a reader can tell a researched
-- guess from something somebody actually looked at.
local sources = {}
for _, entry in ipairs(Family.Capabilities:Report()) do sources[entry.feature] = entry.source end
check("dual spec is marked as seen in the game", sources.dualSpec == "seen in game",
	tostring(sources.dualSpec))
check("ammo bags are still only expected", sources.ammoBags == "expected",
	tostring(sources.ammoBags))

print()
print("the minimap button and the options that switch it")

local minimap = _G.FamilyMinimapButton
check("a minimap button exists", minimap ~= nil)
check("and is showing by default", minimap and minimap:IsShown() == true)

Family.UI:SetMinimapShown(false)
check("turning it off hides it", minimap and minimap:IsShown() == false)
check("and the choice is remembered", FamilyDB.ui.minimap == false)
check("without needing a reload to come back", Family.UI:IsMinimapShown() == false)
Family.UI:SetMinimapShown(true)
check("turning it back on shows it again", minimap and minimap:IsShown() == true)

-- Dragging it round the minimap has to leave it where it was left.
minimap.__scripts.OnDragStart(minimap)
minimap.__scripts.OnUpdate(minimap)
minimap.__scripts.OnDragStop(minimap)
check("dragging it records an angle", FamilyDB.ui.minimapAngle ~= nil,
	tostring(FamilyDB.ui.minimapAngle))
check("and that angle is where the cursor was", FamilyDB.ui.minimapAngle == 45,
	tostring(FamilyDB.ui.minimapAngle))

tabDrawsCleanly("options", "the options panel builds and draws")

--------------------------------------------------------------------------------------------
-- The Options panel scrolls, because it outgrew the window
--
-- Nine switches with a wrapping caption each, plus the strata row and the sentence under it,
-- run past the bottom of the panel in English and further in every other language. The last
-- caption was being drawn over the footer and everything below it was simply not on the
-- screen - which is the same fault as an unclickable tick box: the thing is there in the code
-- and not there for the player.
--
-- Three things have to hold, and each of them was false before this.
--------------------------------------------------------------------------------------------

do
	Family.UI:Show()
	Family.UI:ShowTab("options")

	local panel, scroll
	for _, f in ipairs(frames) do
		if f.__kind == "ScrollFrame" and f.__parent and f.__parent.Refresh
			and f.__parent.__optionsPanel then
			scroll = f
		end
	end

	-- Found by what it holds rather than by a marker, because a marker is a thing the panel
	-- would have to remember to set and this has to be true of the panel as it is written.
	if not scroll then
		for _, f in ipairs(frames) do
			if f.__kind == "ScrollFrame" then
				local child = f.__scrollChild
				if child then
					for _, box in ipairs(frames) do
						if box.__name == "FamilyOption1" and box.__parent == child then
							scroll, panel = f, f.__parent
						end
					end
				end
			end
		end
	end

	check("the options panel has a scroller with the switches inside it", scroll ~= nil)

	local child = scroll and scroll.__scrollChild
	check("and the switches are its child rather than the panel's", child ~= nil)

	-- Taller than the window, which is what says there is something below the fold to reach.
	-- A scroller around content that fits is a scroller nobody needs and proves nothing.
	check("and it is taller than the panel, so there is something to scroll to",
		child ~= nil and (child.__height or 0) > (scroll:GetHeight() or 500),
		child and tostring(child.__height) or "no child")

	-- And a wheel reaches it. UIPanelScrollFrameTemplate brings a bar and two arrows and
	-- nothing that answers a wheel, which most people will not think to drag.
	check("and the wheel scrolls it",
		scroll ~= nil and type(scroll.__scripts.OnMouseWheel) == "function")

	-- The last thing on the panel, which is the one that was drawn over the footer. Inside
	-- the child means reachable; on the panel means printed wherever the maths happened to
	-- put it, which is off the bottom.
	local meaning, footer = nil, nil
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" then
			if f.__text:find("In front of unit frames", 1, true) then meaning = f end
			if f.__text:find("tooltips hooked", 1, true) then footer = f end
		end
	end

	check("the sentence under the strata buttons is inside the scroller",
		meaning ~= nil and child ~= nil and meaning.__parent == child,
		meaning and tostring(meaning.__parent == child) or "not drawn")

	-- And the footer is not, because it is about this installation rather than about any
	-- switch, and a line that scrolls away is a line somebody has to go looking for.
	check("and the footer is pinned to the panel rather than scrolling with them",
		footer ~= nil and child ~= nil and footer.__parent ~= child,
		footer and tostring(footer.__parent == child) or "not drawn")
end

-- The tab you are on is marked by being held highlighted, not by being disabled. Greying it
-- is how the game says "you cannot do this", which is the opposite of what is meant.
local function buttonLabelled(label)
	for _, f in ipairs(frames) do
		if type(f.__text) == "string" and f.__text:find(label, 1, true) then return f end
	end
end

Family.UI:ShowTab("contents")
local contentsTab = buttonLabelled("Possessions")
local optionsTab = buttonLabelled("Options")
check("the tab you are on is highlighted",
	contentsTab and contentsTab.__highlighted == true)
check("and still clickable rather than disabled",
	contentsTab and contentsTab:IsEnabled() == true)
check("the others are not highlighted", optionsTab and optionsTab.__highlighted == false)

-- Switching section clears the filter, so a word typed for one list does not silently empty
-- the next one.
Family.UI:ShowTab("character")
-- By name. Taking "the last edit box that is not the picker's" worked only for as long as
-- the character panel happened to be the last one built, and stopped the moment a check
-- above it opened that panel earlier - at which point it was quietly testing the professions
-- panel's filter against the character panel's buttons.
local characterSearch = _G.FamilyCharacterSearch
if characterSearch then
	characterSearch:SetText("nothing matches this")
	clickButton("Reputations")
	check("changing section clears the filter",
		(characterSearch:GetText() or "") == "",
		tostring(characterSearch:GetText()))
end

-- Placed before the second build below, and that is the whole reason it is here rather than
-- beside the other whole-family checks at the end of this file.
--
-- This panel is registered twice - once more with Mists in force - and both builds claim the
-- same global names and the same `UI.__characterFilters`. So the handle is the second panel's
-- while the one on screen is the first, and a check written down there drove one and measured
-- the other. L-041, which this file already carries, in the one place where it costs an hour.
print()
print("the character panel's filters, asked of the widget")

-- Asked for twice from play: this panel had a realm picker and a class picker of its own and
-- no level range at all. The widget has had all three since the summary's slice, so the answer
-- was a migration rather than a fourth hand-written filter bar.
--
-- The sibling here is on another realm on purpose. The widget offers our own members by
-- default, and this panel draws siblings beside them - so a realm only a linked family is on
-- has to be offered here, and a check whose sibling shares our realm cannot tell the two
-- populations apart.
;(function()
	local held = FamilyDB.wide
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["farfam"] = { name = "Faraway-Thunderstrike", grants = {}, siblings = {},
			members = {
				["Faraway-Thunderstrike"] = {
					meta = { name = "Faraway", realm = "Thunderstrike",
						classFile = "PRIEST", level = 70, faction = "Alliance" },
					payload = { equipment = { itemLevel = 100, counted = 17 } },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("farfam", "Faraway-Thunderstrike", true)

	Family.UI:Show()
	Family.UI:ShowTab("character")
	clickButton("Equipped gear")

	local filters = Family.UI.__characterFilters
	check("the character panel asks the widget for its filters", filters ~= nil)

	if filters then
		-- Driven until the panel is in the mode this is about rather than clicked once and
		-- hoped over: the switch is a toggle and something earlier may have left it on.
		-- By its own name, not by its label. Three panels carry a button saying "Whole
		-- family" and `clickButton` takes the first clickable one it finds, which is how a
		-- first version of this clicked another panel's switch and then measured this one.
		local switch = _G.FamilyGearWholeFamily
		check("the panel's own whole-family switch is reachable", switch ~= nil)

		if switch and not filters.frame:IsShown() then
			switch.__scripts.OnClick(switch)
		end
		Family.UI:Refresh()

		check("and shows them while the panel is about everybody",
			filters.frame:IsShown() == true)
		check("with the level range this panel never had",
			filters.minBox ~= nil and filters.maxBox ~= nil)

		local offered = {}
		for _, choice in ipairs(filters.realmButton:Choices()) do
			offered[tostring(choice.value)] = true
		end
		check("offering a realm only a linked family is on",
			offered["Thunderstrike"] == true)

		-- TAB walks the boxes on this row, and Shift-TAB walks back.
		--
		-- Within the panel, which is the whole of what it means - a ring that jumped to
		-- another panel's box would be jumping to a box nobody can see. Asked for from play,
		-- because filling in a level range and then reaching for the mouse to type a name is
		-- three gestures where the keyboard offers one.
		do
			local box = _G.FamilyCharacterSearch
			filters.minBox:SetFocus()

			SHIFT_DOWN = false
			filters.minBox.__scripts.OnTabPressed(filters.minBox)
			check("tab moves to the next box on the row",
				filters.maxBox:HasFocus() == true)

			filters.maxBox.__scripts.OnTabPressed(filters.maxBox)
			check("and on to the one after it", box:HasFocus() == true)

			-- Round, because a ring that stops at the end makes the last box a dead end and
			-- the only way back the mouse, which is the thing this saves.
			box.__scripts.OnTabPressed(box)
			check("and round to the first again", filters.minBox:HasFocus() == true)

			SHIFT_DOWN = true
			filters.minBox.__scripts.OnTabPressed(filters.minBox)
			check("and shift-tab walks the other way", box:HasFocus() == true)
			SHIFT_DOWN = false

			box:ClearFocus()
		end

		-- And the row adds up. The filter box was a fixed 200 pixels and the filter row that
		-- replaced the member picker is twice the picker's width, so across the family the
		-- box ran under the Whole family button - reported from play, on two sections at
		-- once, because they share this row.
		--
		-- The panel's own inequality with the caption counted as nothing, so passing this is
		-- necessary rather than sufficient: three widths that have to add up are three
		-- chances to be wrong by hand, and the old fixed number fails it.
		do
			local box = _G.FamilyCharacterSearch
			local switch = _G.FamilyGearWholeFamily
			local room = (Family.UI.CONTENT_W or 740) - 14 - (switch:GetWidth() or 120)
			local used = filters:Width() + 26 + (box:GetWidth() or 200)
			check("and the filter box stops before the whole-family button starts",
				used <= room, used .. " against " .. room)
		end

		local function cellsDrawn()
			local drawn = 0
			for _, f in ipairs(frames) do
				if f.__shown == true and rawget(f, "level") and rawget(f, "border") then
					drawn = drawn + 1
				end
			end
			return drawn
		end

		local everybody = cellsDrawn()
		check("with somebody's gear to draw", everybody > 0, tostring(everybody))

		local function typeInto(box, text)
			box:SetText(text)
			if box.__scripts and box.__scripts.OnTextChanged then
				box.__scripts.OnTextChanged(box)
			end
		end

		-- Ours are sixty and the visitor is seventy, so a floor of sixty-five takes ours
		-- off the grid and leaves theirs.
		typeInto(filters.minBox, "65")
		Family.UI:Refresh()
		local above = cellsDrawn()
		check("and a level range narrows what is drawn", above < everybody,
			above .. " of " .. everybody)
		check("without emptying it, because somebody is above the floor", above > 0,
			tostring(above))

		typeInto(filters.minBox, "")
		Family.UI:Refresh()
		check("and emptying it brings them back", cellsDrawn() == everybody,
			cellsDrawn() .. " of " .. everybody)

		if switch then switch.__scripts.OnClick(switch) end
		Family.UI:Refresh()

		-- And a box that is not on the screen is stepped over rather than focused.
		--
		-- Out of the whole-family reading the level range is away, so the ring is the filter
		-- box alone and tab leaves the cursor where it is. Asked at the moment the key is
		-- pressed and not when the ring was built, because that row comes and goes.
		local box = _G.FamilyCharacterSearch
		box:SetFocus()
		box.__scripts.OnTabPressed(box)
		check("a box that is not on the screen is not tabbed to",
			box:HasFocus() == true and filters.minBox:HasFocus() == false)
		box:ClearFocus()
	end

	Family.Wide:SetSibling("farfam", "Faraway-Thunderstrike", false)
	FamilyDB.wide = held
	Family.UI:Refresh()
end)()


print()
print("everybody's quests at once")

-- The last named slice of backlog entry 3. The per-member reading answers "what is this
-- character doing"; this answers "who is on this one", which is the question a family asks - a
-- group quest wants somebody else at the same step, and a quest three of them are stuck on is
-- worth knowing before a fourth starts it.
--
-- Before the second panel build below, for the reason the block above is: both builds claim the
-- same globals, and a check written after them drives one panel and measures the other.
;(function()
	local shared = { title = "The Shared Errand", level = 40, id = 5001,
		objectives = 5, category = "Desolace" }

	local roster = {
		{ key = "Qone-FireMaw", name = "Qone", done = 5 },
		{ key = "Qtwo-FireMaw", name = "Qtwo", done = 3 },
		{ key = "Qthree-FireMaw", name = "Qthree", done = 2 },
		{ key = "Qfour-FireMaw", name = "Qfour", done = 1 },
	}

	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = "Fire Maw",
			level = 60, classFile = "MAGE", faction = "Alliance" })
		Family.Database:SetPayload(member.key, { quests = { seen = time(), entries = {
			{ title = shared.title, level = shared.level, id = shared.id,
				objectives = shared.objectives, done = member.done,
				category = shared.category },
		} } })
	end

	Family.UI:Show()
	Family.UI:ShowTab("character")
	check("the quests section can be opened", clickButton("Quests"))

	local switch = _G.FamilyGearWholeFamily
	local filters = Family.UI.__characterFilters
	if switch and filters and not filters.frame:IsShown() then
		switch.__scripts.OnClick(switch)
	end
	Family.UI:Refresh()

	check("and it has a whole-family reading of its own",
		filters and filters.frame:IsShown() == true)

	local function rowSaying(needle)
		for _, f in ipairs(frames) do
			local left = type(f.left) == "table" and f.left.__text
			if f.__shown ~= false and type(left) == "string"
				and left:find(needle, 1, true) then
				return f
			end
		end
		return nil
	end

	-- The lines under a quest, walked from its own row. Anything that is not one of this
	-- panel's rows is stepped over rather than read as the end of the block.
	local function under(head, needle)
		local at
		for index, f in ipairs(frames) do
			if f == head then
				at = index
				break
			end
		end
		if not at then return nil end

		for index = at + 1, #frames do
			local f = frames[index]
			if type(f.left) == "table" and type(f.middle) == "table"
				and type(f.right) == "table" then
				local left = f.left.__text
				if f.__shown == false or type(left) ~= "string" or left ~= "" then
					break
				end
				local middle = f.middle.__text
				if type(middle) == "string" and middle:find(needle, 1, true) then
					return f
				end
			end
		end
		return nil
	end

	-- The row that folds a quest out or back, found by the quest it carries. A row from a
	-- growing pool is last in `frames` the first time it is made, so walking to it misses it.
	local function foldRow(needle)
		for _, f in ipairs(frames) do
			local middle = type(f.middle) == "table" and f.middle.__text
			if f.__shown ~= false and f.expandQuest == "id:5001"
				and type(middle) == "string" and middle:find(needle, 1, true) then
				return f
			end
		end
		return nil
	end

	local quest = rowSaying(shared.title)
	check("a quest four of them are on is one row", quest ~= nil)

	-- The client's own description of it, which needs the id and the level together: a bare
	-- "quest:84" describes nothing, measured on Era and TBC. These rows carried neither until
	-- the question "could they have tooltips" was asked.
	do
		GameTooltip.__shownAs = nil
		wipe(GameTooltip.__lines)
		if quest and quest.__scripts.OnEnter then quest.__scripts.OnEnter(quest) end
		check("and hovering it opens the quest's own tooltip",
			GameTooltip.__shownAs and GameTooltip.__shownAs.kind == "quest",
			GameTooltip.__shownAs and GameTooltip.__shownAs.kind)
	end

	-- And a row whose quest the client will not describe still says what Family knows.
	--
	-- Not merely silent: a declined link hides the tooltip and drops the owner, measured on
	-- Era and TBC. So the fallback has to take the tooltip back before it writes, or its
	-- lines go nowhere - which is what the quest rows did on a single character the day this
	-- lane started asking. Reported from play, and the stub now models the refusal so that
	-- the repair can be measured rather than trusted.
	do
		-- A row with no level to give, which is the case the client declines: the id alone
		-- is a link it will not describe. Taking the *id* away instead would have left a
		-- well-formed link and measured nothing, which the first version of this did.
		local held = quest and quest.questLevel
		if quest then quest.questLevel = nil end

		GameTooltip.__shownAs = nil
		GameTooltip.__owner = nil
		wipe(GameTooltip.__lines)
		if quest and quest.__scripts.OnEnter then quest.__scripts.OnEnter(quest) end

		check("a quest the client will not describe falls back to what Family knows",
			#GameTooltip.__lines > 0, tostring(#GameTooltip.__lines))
		check("and those lines are drawn on the row they belong to",
			GameTooltip.__owner == quest,
			tostring(GameTooltip.__owner))

		if quest then quest.questLevel = held end
	end

	if quest then
		check("with the one who is furthest along on its own line",
			(quest.middle.__text or ""):find("Qone", 1, true) ~= nil,
			quest.middle.__text)
		check("and said to be ready, because they are",
			(quest.right.__text or ""):find(Family.L["|cff40bf40ready to hand in|r"],
				1, true) ~= nil, quest.right.__text)

		check("and the next of them under it", under(quest, "Qtwo") ~= nil)
		check("with their own progress rather than the family's best",
			under(quest, "Qtwo")
				and (under(quest, "Qtwo").right.__text or ""):find("3 / 5", 1, true) ~= nil,
			under(quest, "Qtwo") and under(quest, "Qtwo").right.__text)

		check("only three of them at once", under(quest, "Qfour") == nil)

		local more = foldRow(string.format(Family.L["|cff888888and %d more|r"], 1))
		check("and the rest offered rather than dropped", more ~= nil)

		if more then
			more.__scripts.OnClick(more)
			quest = rowSaying(shared.title)
			check("clicking that shows them",
				quest and under(quest, "Qfour") ~= nil)

			local fewer = foldRow(Family.L["|cff888888fewer|r"])
			if fewer then fewer.__scripts.OnClick(fewer) end
		end

		-- And the filters act on the people, in this reading too.
		if filters then
			filters.maxBox:SetText("30")
			if filters.maxBox.__scripts and filters.maxBox.__scripts.OnTextChanged then
				filters.maxBox.__scripts.OnTextChanged(filters.maxBox)
			end
			Family.UI:Refresh()
			check("a level range narrows who is listed under a quest",
				rowSaying(shared.title) == nil)

			filters.maxBox:SetText("")
			if filters.maxBox.__scripts and filters.maxBox.__scripts.OnTextChanged then
				filters.maxBox.__scripts.OnTextChanged(filters.maxBox)
			end
			Family.UI:Refresh()
		end
	end

	if switch then switch.__scripts.OnClick(switch) end
	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
	Family.UI:Refresh()
end)()

print()
print("a quest row's own objectives, under the client's description of the quest")

-- The other half of what was reported: the Progress column said *2 of 4* and the tooltip
-- listed all four requirements with none of them marked, because the client describes a quest
-- as it stands for **whoever is being played** and every row here but one is somebody else.
--
-- So the client's answer is kept - it is the quest's own text, which is worth having - and this
-- character's own progress is added under it. Not a fallback: a fallback replaces.
;(function()
	local key = Family:CurrentMember()

	local lines = Family.UI:QuestLines(key, Family.UI:Meta(key), nil)
	check("the quest rows are there to carry it", lines ~= nil and #lines > 0)

	local quest, heading
	for _, line in ipairs(lines or {}) do
		if line.title == "Red Linen Goods" then quest = line end
		-- A zone heading is a row in this list too, and has no quest behind it.
		if not line.title and not heading then heading = line end
	end

	check("a quest row carries this character's objectives", quest ~= nil
		and quest.progress ~= nil and #quest.progress == 2,
		quest and tostring(quest.progress and #quest.progress))
	check("in the client's own words", quest and quest.progress
		and quest.progress[1].text == "Red Linen Goods 1: 1/1",
		quest and quest.progress and tostring(quest.progress[1].text))
	check("and a zone heading carries none, having no quest behind it",
		heading ~= nil and heading.progress == nil)

	-- And on the panel, where the tooltip can reach them.
	Family.UI:Show()
	Family.UI:ShowTab("character")
	check("the quests section can be opened", clickButton("Quests"))
	Family.UI:Refresh()

	local row
	for _, f in ipairs(frames) do
		if f.__shown ~= false and f.questID == 84 then row = f end
	end
	check("the row for that quest is drawn", row ~= nil)

	if row then
		GameTooltip.__shownAs = nil
		wipe(GameTooltip.__lines)
		row.__scripts.OnEnter(row)

		-- Both halves, and the point is that they are both there. A check that only
		-- found the objectives would pass with the client's answer thrown away, which is
		-- what a fallback does and what this deliberately is not.
		check("hovering it still opens the quest's own tooltip",
			GameTooltip.__shownAs and GameTooltip.__shownAs.kind == "quest",
			GameTooltip.__shownAs and GameTooltip.__shownAs.kind)

		local said = ""
		for _, line in ipairs(GameTooltip.__lines) do
			said = said .. " " .. tostring(line[1]) .. " " .. tostring(line[2])
		end

		check("with this character's objectives added under it",
			said:find("Red Linen Goods 1: 1/1", 1, true) ~= nil, said)
		check("every one of them, not the first",
			said:find("Red Linen Goods 2: 1/1", 1, true) ~= nil, said)

		-- Whose progress it is, said out loud. The client writes *You are on this quest*
		-- above these lines, which is a claim about the player; without a name under it
		-- the reader has two statements about two different characters and nothing
		-- saying which is which.
		check("and the character it belongs to named, because the client named the player",
			said:find(tostring(Family.UI:Meta(key).name or key), 1, true) ~= nil, said)
	end
end)()

-- ...and drawing that section at all takes a client that has them. Which sections exist is
-- settled when the panel is built, so the panel is loaded a second time with Mists in force.
-- The double registration is deliberate and confined to here; without it the achievements
-- branch was written, shipped and never once run.
local eraBuild = GetBuildInfo
GetBuildInfo = function() return "5.5.4", "69078", "Aug 2026", 50504 end
Family.Capabilities:Detect()

load("addons/Family_UI/Character.lua", "Family_UI", UIPrivate)
Family.UI:ShowTab("character")

-- Said out loud, at the place it happens, because of what it does to every check written
-- below it. UI:RegisterTab appends without asking whether the id is taken, so the second load
-- leaves two tabs called "character": ShowTab builds both and leaves `current` on the second,
-- while clickButton walks the frame list in the order it was made and drives the first. A
-- check that changes a record, calls UI:Refresh and then reads the screen is therefore reading
-- a panel that was never redrawn - and both panels are internally consistent, so nothing looks
-- wrong. Drive this panel by clicking it (L-011).
-- In a function of its own because this file is one long function within sight of Lua's two
-- hundred locals, which the block further down says out loud.
;(function()
	local found = 0
	for _, tab in ipairs(Family.UI:Tabs()) do
		if tab.id == "character" then found = found + 1 end
	end
	check("the second load leaves two panels answering to \"character\"", found == 2,
		tostring(found))
end)()

check("the achievements section is offered on a client that has them",
	clickButton("Achievements"))
check("and groups them under the game's own category names", visibleText("Exploration"))
check("with what each one asks of you, since a list of titles alone means nothing",
	visibleText("Read everything"))
check("and how far through an unfinished one is", visibleText("1|r of 4"))
check("while a finished one shows what it was worth", visibleText("25|r points"))

GetBuildInfo = eraBuild
Family.Capabilities:Detect()

-- The Mists talent system, drawn. On that expansion the specialisation is chosen outright
-- rather than arrived at by spending points, so it is a line of its own with the role the
-- game gives it - and this is the only place in the harness where a choices payload reaches
-- a panel at all.
local eraTalents = Family.Database:Payload(key).talents
local talentPayload = Family.Database:Payload(key)
talentPayload.talents = {
	seen = time(), system = "choices", activeGroup = 1, groupCount = 1,
	groups = { [1] = { system = "choices", group = 1, visited = true, specID = 66,
		tiers = { [1] = { tier = 1, chosen = 1,
			-- A real Mists talent id, so the table is actually asked. 15757 is the
			-- spell 29838, which is what the client below is made to answer for.
			-- Recorded in German, on a client that is not German: the panel below has
			-- to show what this client calls it, not what was written down.
			choices = { [1] = { id = 15757, name = "Heiliger Schild",
				selected = true } } } } } },
}
Family.Database:SetPayload(key, talentPayload)

TANK = "Tank"
GetSpecializationInfoByID = function(id) return id, "Protection", nil, "spec-icon", "TANK" end

load("addons/Family_UI/Talents.lua", "Family_UI", UIPrivate)
Family.UI:ShowTab("talents")

check("the specialisation is named on the line above the grid", visibleText("Protection"))
check("with the role the game gives it", visibleText("Tank"))
check("and the talents drawn as a grid, a tier to a row", visibleText("tier 1"))
check("with what was taken on each tier spelled out beside it",
	visibleText("Sacred Shield"),
	"the Mists grid is showing the word it was recorded under")
check("and not the word it was recorded under", not visibleText("Heiliger Schild"))

talentPayload.talents = eraTalents
Family.Database:SetPayload(key, talentPayload)
Family.UI:ShowTab("summary")

-- The tooltip switch has to actually silence the block, not merely look switched.
FamilyDB.tooltips = false
check("turning tooltips off stops the block", tooltipFor(2589) == false)
FamilyDB.tooltips = true
check("and turning them back on restores it", tooltipFor(2589) == true)

print()
print("what the broker and the minimap button say and do")

-- Never asked for before, which is exactly how the tooltip came to call a function that was
-- private to another file: nothing in this harness had ever made it draw.
--
-- A second realm with a member of the same name on it, because a summary that keeps two
-- characters called Tester apart while the broker merges them is the broker being wrong.
Family.Database:SetMeta("Tester-Auberdine", { name = "Tester", realm = "Auberdine",
	level = 42, money = 12345, classFile = "PALADIN", itemLevel = 30 })

local function brokerTooltipText()
	wipe(GameTooltip.__lines)
	minimap.__scripts.OnEnter(minimap)

	local lines = {}
	for _, line in ipairs(GameTooltip.__lines) do
		lines[#lines + 1] = tostring(line[1]) .. "  " .. tostring(line[2])
	end
	return table.concat(lines, "\n")
end

local brokerText = brokerTooltipText()

check("the broker tooltip names every realm",
	brokerText:find("Fire Maw", 1, true) ~= nil
		and brokerText:find("Auberdine", 1, true) ~= nil, brokerText)
check("and lists the members under them, not just the realms",
	select(2, brokerText:gsub("Tester", "")) >= 2, brokerText)
check("a family on two realms is given a grand total",
	brokerText:find("All realms", 1, true) ~= nil, brokerText)

-- Two bare numbers beside a name are two bare numbers. A tooltip has no third column to
-- label them in, so one heading at the top does it for every line beneath.
check("the tooltip says what the numbers beside each name are",
	brokerText:find("level, item level", 1, true) ~= nil, brokerText)

-- Grouped by side as well as by realm, the way the summary is.
--
-- An Alliance member and a Horde member on one realm share nothing but the realm - no bank,
-- no mailbox, no auction house - so one flat list of them reads as a pool of characters that
-- can pass things between them, which is the one thing they cannot do.
do
	Family.Database:SetMeta("Alliedone-Fire Maw", { name = "Alliedone", realm = "Fire Maw",
		faction = "Alliance", level = 30, money = 5000, classFile = "MAGE" })
	Family.Database:SetMeta("Hordling-Fire Maw", { name = "Hordling", realm = "Fire Maw",
		faction = "Horde", level = 31, money = 7000, classFile = "SHAMAN" })

	local split = brokerTooltipText()
	local alliance = _G.FACTION_ALLIANCE or "Alliance"
	local horde = _G.FACTION_HORDE or "Horde"

	check("the broker tooltip splits a realm by faction",
		split:find(alliance, 1, true) ~= nil and split:find(horde, 1, true) ~= nil, split)

	-- Under the heading of their own side, not merely somewhere in the tooltip.
	local atAlliance = split:find(alliance, 1, true)
	local atHorde = split:find(horde, 1, true)
	local atAllied = split:find("Alliedone", 1, true)
	local atHordling = split:find("Hordling", 1, true)
	check("and lists each member under their own side",
		atAlliance and atHorde and atAllied and atHordling
			and atAllied > atAlliance and atAllied < atHorde and atHordling > atHorde,
		split)

	-- The side carries its own money, the way the realm line above it does.
	check("and gives each side its own money",
		split:match(alliance .. "[^\n]*5000") ~= nil
			or split:match(alliance .. "[^\n]*|cffffd700") ~= nil, split)

	-- A realm with one side is not given a heading it does not need. Auberdine has a single
	-- member on it and no faction recorded at all.
	check("but a realm with one side is left as a plain list",
		split:match("Auberdine[^\n]*\n%s*Tester") ~= nil, split)

	Family.Database:Forget("Alliedone-Fire Maw")
	Family.Database:Forget("Hordling-Fire Maw")
end

-- And both slots are always filled, because one number on its own says nothing about which
-- of the two it is - and a member whose gear was never read is precisely the member whose
-- level would be taken for an item level.
do
	Family.Database:SetMeta("Bare-FireMaw", { name = "Bare", realm = "Fire Maw",
		classFile = "ROGUE", level = 12 })
	local said = brokerTooltipText()
	check("a member with no item level is given a placeholder, not one lonely number",
		said:find("12  -", 1, true) ~= nil, said)
	Family.Database:Forget("Bare-FireMaw")
end

-- A family too big for the screen
--
-- A tooltip does not scroll and is not clipped politely. Reported with a screenshot of thirty
-- characters running off the top and the bottom at once, where what went off the bottom was the
-- grand total and the warnings - the answers - while the per-character detail survived.
--
-- So the rule is that structure never goes: realm lines, the grand total and the footer are
-- drawn whatever happens, and member rows take the room actually left on this screen at this
-- scale. The budget is derived from UIParent's own height, which is why this can move it.
do
	local held = UIParent.GetHeight
	local made = {}

	for index = 1, 40 do
		local key = string.format("Crowd%02d-Farshire", index)
		made[#made + 1] = key
		Family.Database:SetMeta(key, { name = string.format("Crowd%02d", index),
			realm = "Farshire", level = 60, faction = "Alliance", money = index * 10000 })
	end

	local function rowsOf(text)
		return select(2, text:gsub("\n", "\n")) + 1
	end

	UIParent.GetHeight = function() return 600 end
	local tight = brokerTooltipText()

	check("a family too big for the screen is trimmed to fit",
		rowsOf(tight) < 46, tostring(rowsOf(tight)))
	check("and says how many it left out", tight:find("more", 1, true) ~= nil, tight)

	-- The whole point: the answers survive and the detail is what gives way. These were the
	-- lines going off the bottom of the screenshot.
	check("the grand total survives the trimming",
		tight:find("All realms", 1, true) ~= nil, tight)
	check("and every realm still has its own line",
		tight:find("Farshire", 1, true) ~= nil and tight:find("Fire Maw", 1, true) ~= nil,
		tight)
	check("and the footer saying what the clicks do",
		tight:find("Right-click", 1, true) ~= nil, tight)

	-- Richest first while trimming, so the ones that stayed explain themselves. Crowd40 holds
	-- forty times what Crowd01 does.
	check("the richest of a trimmed group is kept",
		tight:find("Crowd40", 1, true) ~= nil, tight)
	check("and the poorest is not", tight:find("Crowd01", 1, true) == nil, tight)

	-- A screen with room changes nothing at all: no trimming line, everybody listed. The
	-- budget is a second mode and not a new default.
	UIParent.GetHeight = function() return 4000 end
	local roomy = brokerTooltipText()

	check("a screen with room for everybody trims nothing",
		roomy:find("more", 1, true) == nil, roomy)
	check("and lists the poorest character too",
		roomy:find("Crowd01", 1, true) ~= nil, roomy)
	check("and is longer than the trimmed one, which is the whole difference",
		rowsOf(roomy) > rowsOf(tight), rowsOf(roomy) .. " vs " .. rowsOf(tight))

	UIParent.GetHeight = held
	for _, key in ipairs(made) do Family.Database:Forget(key) end
end

-- The bar and the tooltip are two views of one sum and must not be able to disagree. The
-- bar was written once at login and never again, so a player who had spent two gold since
-- read one total on their screen and a different one in the tooltip above it - and the
-- tooltip, which is rebuilt on every hover, was the right one.
do
	-- LibDataBroker is used where the player already has it and is never shipped, so it is
	-- absent here exactly as it is absent from a game running nothing else that embeds it,
	-- and there is no bar object unless one is made. It is one field, and the whole of what
	-- the library gives us.
	Family.UI.broker = Family.UI.broker or { text = "" }

	local before = Family.UI.broker.text
	Family.Database:SetMeta("Tester-Auberdine", { money = 999999999 })
	do
		-- What the bar counts, and the way back.
		--
		-- A grand total across every realm is a number nobody can spend: two sides on one
		-- realm share no bank, no mailbox and no auction house, which the tooltip below
		-- already says at length. So the money narrows to what this side of this realm holds
		-- and then to this character's own pocket, and comes back round.
		local held = FamilyDB.ui and FamilyDB.ui.brokerScope

		check("the bar counts the whole family until asked otherwise",
			Family.UI:BrokerScope() == "all", tostring(Family.UI:BrokerScope()))

		local wide = Family.UI.broker.text
		check("and cycling goes realm, then character, then back",
			Family.UI:CycleBrokerScope() == "realm"
				and Family.UI:CycleBrokerScope() == "character"
				and Family.UI:CycleBrokerScope() == "all")

		-- The tooltip is the whole-family view and does not narrow with the bar. What it must
		-- never do is narrow *half* of itself: it used to list every member of every realm and
		-- then foot the column with whatever the bar was counting, so with the scope on one
		-- character the realms added to one number and the line under them said another.
		-- Reported from a screenshot of exactly that, and it shipped in 1.2.0.
		Family.UI:CycleBrokerScope()
		Family.UI:CycleBrokerScope()
		check("the scope is on one character for this",
			Family.UI:BrokerScope() == "character", tostring(Family.UI:BrokerScope()))

		-- Compared against the formatter's own output rather than by picking the numbers
		-- back out of it: the money carries a colour code between the digits and the "g",
		-- and a pattern that missed it made both sides nought and the check vacuous. The
		-- mutation restoring the bug passed until this was compared properly.
		local everyone = 0
		for _, entry in pairs(Family.Database:Members()) do
			everyone = everyone + ((entry.meta or {}).money or 0)
		end

		local scoped = brokerTooltipText()
		local grand
		for line in (scoped .. "\n"):gmatch("([^\n]*)\n") do
			if line:find("All realms", 1, true) then grand = line end
		end

		check("the tooltip's total is the whole family, not what the bar narrowed to",
			grand ~= nil and grand:find(Family.UI:Money(everyone), 1, true) ~= nil,
			tostring(grand) .. " wanted " .. tostring(Family.UI:Money(everyone)))

		-- And it still says which narrower thing the bar is counting, which is what explains
		-- the bar and the tooltip disagreeing on purpose.
		check("and still names what the bar is counting",
			scoped:find("the bar is counting", 1, true) ~= nil, scoped)

		Family.UI:CycleBrokerScope()

		-- Two sides on one realm, which is the whole reason the realm scope is not just the
		-- realm: they share no bank, no mailbox and no auction house, so counting them
		-- together would be a total nobody can spend. The fixture has one realm and no sides
		-- at all until this puts them there.
		Family.Database:SetMeta("Other-FireMaw", { faction = "Horde" })
		Family.Database:SetMeta("Formulaic-FireMaw", { faction = "Alliance" })

		-- And somebody far away with mail about to be destroyed, to hold the one count that
		-- must *not* narrow.
		Family.Database:SetMeta("Tester-Auberdine", { mailExpiresBy = time() + 3600 })

		Family.UI:CycleBrokerScope()
		local realmText = Family.UI.broker.text
		check("the realm scope counts this side of this realm and not the other side of it",
			tonumber((realmText:match("^(%d+)"))) == 2, realmText)
		check("and still warns about mail on a character it is no longer counting",
			brokerTooltipText():find("Mail expiring soon", 1, true) ~= nil,
			"narrowing what the bar counts must not narrow what it warns about")

		Family.UI:CycleBrokerScope()
		local charText = Family.UI.broker.text
		check("and the character scope counts exactly one",
			tonumber((charText:match("^(%d+)"))) == 1, charText)

		Family.Database:SetMeta("Other-FireMaw", { faction = Family.CLEAR })
		Family.Database:SetMeta("Formulaic-FireMaw", { faction = Family.CLEAR })
		Family.Database:SetMeta("Tester-Auberdine", { mailExpiresBy = Family.CLEAR })
		Family.UI:CycleBrokerScope()

		-- The button somebody actually presses, rather than the function behind it.
		local minimap = _G.FamilyMinimapButton
		local was, wasTab = Family.UI:BrokerScope(), Family.UI:CurrentTab()
		local function press(button)
			if minimap and minimap.__scripts and minimap.__scripts.OnClick then
				minimap.__scripts.OnClick(minimap, button)
			end
		end

		press("MiddleButton")
		check("and the middle button on the minimap changes it", Family.UI:BrokerScope() ~= was,
			was .. " -> " .. Family.UI:BrokerScope())

		-- The one that is named in the tooltip, because a middle button is not something
		-- everybody has and a trackpad often has two.
		local afterMiddle = Family.UI:BrokerScope()
		SHIFT_DOWN = true
		press("LeftButton")
		SHIFT_DOWN = false
		check("and so does shift with the left one, which everybody has",
			Family.UI:BrokerScope() ~= afterMiddle,
			afterMiddle .. " -> " .. Family.UI:BrokerScope())

		-- And a plain left click still opens Family rather than changing the money.
		local beforePlain = Family.UI:BrokerScope()
		press("LeftButton")
		check("while a plain left click leaves the money alone",
			Family.UI:BrokerScope() == beforePlain, beforePlain .. " -> "
				.. Family.UI:BrokerScope())
		-- Rather than doing what the other two buttons do. The window may well be open
		-- already from an earlier section, so what is asked is that this click did not move
		-- it - not that nothing is on screen.
		check("and does not send the window somewhere while it is at it",
			Family.UI:CurrentTab() == wasTab,
			tostring(wasTab) .. " -> " .. tostring(Family.UI:CurrentTab()))
		while Family.UI:BrokerScope() ~= "all" do Family.UI:CycleBrokerScope() end

		-- The claim, rather than the helper: the number on the bar has to move with it.
		Family.UI:CycleBrokerScope()
		local narrowed = Family.UI.broker.text
		check("and the bar itself says something different once it has",
			narrowed ~= wide, tostring(wide) .. " -> " .. tostring(narrowed))

		-- Both numbers together, or "29 members, 4200g" is a puzzle rather than a sentence.
		local mine = tonumber((narrowed:match("^(%d+)")))
		local all = tonumber((wide:match("^(%d+)")))
		check("with the member count narrowed alongside the money",
			mine ~= nil and all ~= nil and mine < all,
			tostring(all) .. " members -> " .. tostring(mine))

		-- And it says so on hover, or a number that quietly changed meaning is worse than
		-- no number at all.
		check("and the tooltip names what the bar is counting",
			brokerTooltipText():find("the bar is counting", 1, true) ~= nil)

		-- An unknown value on disk - an older version, or a hand-edited file - must read as
		-- the whole family rather than as nothing at all.
		FamilyDB.ui.brokerScope = "whatever"
		check("and a scope it does not recognise reads as the whole family",
			Family.UI:BrokerScope() == "all")

		FamilyDB.ui.brokerScope = held
		Family.UI:UpdateBroker()
	end
	Family.Database:SetMeta("Tester-Auberdine", { money = 999999999 })
	local text = Family.UI.broker.text
	check("the broker bar is brought up to date when the database changes",
		text ~= before, tostring(before) .. " -> " .. tostring(text))

	-- The same sum, said twice, which is the fault as a player meets it.
	local shown
	for line in (brokerTooltipText() .. "\n"):gmatch("([^\n]*)\n") do
		if line:find("All realms", 1, true) then shown = line:match("|r  (.+)$") end
	end
	check("and says the same total the tooltip under it says",
		shown ~= nil and text ~= nil and text:find(shown, 1, true) ~= nil,
		tostring(text) .. " vs " .. tostring(shown))

	Family.Database:SetMeta("Tester-Auberdine", { money = 12345 })
end

-- Each click goes to a fixed place. Toggling to whatever was last shown meant that
-- right-clicking for the options made every later left-click open the options too.
Family.UI:Hide()
minimap.__scripts.OnClick(minimap, "LeftButton")
check("left-click opens the family",
	Family.UI:IsShown() and Family.UI:CurrentTab() == "summary",
	tostring(Family.UI:CurrentTab()))
minimap.__scripts.OnClick(minimap, "RightButton")
check("right-click opens the options", Family.UI:CurrentTab() == "options",
	tostring(Family.UI:CurrentTab()))
minimap.__scripts.OnClick(minimap, "LeftButton")
check("and left-click goes back to the family rather than reopening the options",
	Family.UI:CurrentTab() == "summary", tostring(Family.UI:CurrentTab()))
minimap.__scripts.OnClick(minimap, "LeftButton")
check("clicking for where you already are closes the window",
	Family.UI:IsShown() == false)
Family.UI:Show()

-- Totals, per realm and over all of them. Two realms exist at this point, which is the only
-- time a grand total says anything a realm total does not.
Family.UI:ShowTab("summary")
check("each realm is given a totals line", somethingShowing("Total") ~= nil)
check("and a family on two realms a grand total", somethingShowing("Grand totals") ~= nil)

-- Professions take two lines per member: the primaries on the first with room to be read,
-- everything else on the second. Five side by side cut "Leatherworking 289/300" off in the
-- middle of a number, and a rogue's poisons fell off the edge entirely.
-- The last button with that text, not the first: there is a tab called Professions as well
-- as a column set, the tab was made first, and clicking that one silently walked this check
-- onto a different panel - which then left the summary undrawn for the checks below it.
local function clickLastButton(label)
	local found
	for _, f in ipairs(frames) do
		if type(f.__text) == "string" and f.__text:find(label, 1, true) and clickable(f) then
			found = f
		end
	end
	if found then fireClick(found) end
	return found ~= nil
end

-- Every column set, drawn and measured
--
-- Until now only the overview set was ever drawn here, so six of the seven were checked by
-- looking at them in the game. That is how the activity row came to say "1 (1 in p..." in
-- English - a cell holding two numbers and a phrase in a sixty-five pixel column - and it
-- was reported from a screenshot rather than by this file.
--
-- The columns already had a check that they add up to less than the row. What nothing said
-- was that a cell has to fit the column it is put in. The two are not the same rule and only
-- the first was written down.
--
-- Its own scope, not a bare do block: the main chunk is at Lua 5.1's ceiling of two hundred
-- locals and one more here is what tips it over.
;(function()
	Family.UI:Show()
	Family.UI:ShowTab("summary")

	-- One member with something to say in every column there is, and the widest thing each
	-- of them can say: twelve letters in the mailbox and three more on the way, nineteen
	-- days since anybody looked, and more gold than anybody has.
	Family.Database:SetMeta("Busy-FireMaw", {
		name = "Busy", realm = "Fire Maw", classFile = "WARLOCK", faction = "Alliance",
		level = 60, money = 99999999, itemLevel = 118.5,
		mailSeen = time() - 19 * 86400, mailCount = 12, mailInPost = 3,
		mailExpiresBy = time() + 29 * 86400,
		auctionsSeen = time() - 19 * 86400,
		bagsSeen = time() - 19 * 86400, bagSlots = 102, bagFree = 37,
		bankSeen = time() - 19 * 86400,
		guild = "Loch Modan Yachting Club", hearth = "Thelsamar",
		played = 4321987, playedAtLevel = 98765,
	})

	-- In every language, not only the one the widths were chosen in.
	--
	-- A cell's text is looked up when the row is drawn, so switching the locale and drawing
	-- again measures what a German or a Russian client would actually put in these columns.
	-- The headings are not re-read - they are captured when the file loads, which is true of
	-- the game as well, where changing the language means a reload - so this measures the
	-- content against the declared width. That is if anything stricter than the real thing,
	-- because a longer heading widens its own column before any of this is drawn.
	local wasLocale = Family.locale

	-- Two more, because one member only ever exercises one branch of each formatter. Mail
	-- expiring in days says "29d 23h" and mail expiring today says "5h 20m", which is two
	-- more characters in English and was four more in German until this found it.
	Family.Database:SetMeta("Soon-FireMaw", {
		name = "Soon", realm = "Fire Maw", classFile = "PRIEST", faction = "Alliance",
		level = 60, money = 1234, mailSeen = time() - 5000, mailCount = 3, mailInPost = 1,
		mailExpiresBy = time() + 5 * 3600 + 20 * 60,
		auctionsSeen = time() - 90, bagsSeen = time() - 90, bankSeen = time() - 3700,
	})
	Family.Database:SetMeta("Later-FireMaw", {
		name = "Later", realm = "Fire Maw", classFile = "DRUID", faction = "Horde",
		level = 60, money = 1234, mailSeen = time() - 86400, mailCount = 1,
		mailExpiresBy = time() + 45 * 60,
		auctionsSeen = time() - 86400 * 2, bagsSeen = time() - 3600 * 5,
	})

	-- A fixture nobody draws measures nothing, which is a way for all of this to pass by
	-- doing nothing at all.
	Family.UI:Refresh()
	check("the members these sets are measured against are on screen",
		visibleText("Busy") and visibleText("Soon") and visibleText("Later"))

	-- The tab strip carries some of these words too, so it is the last button with the
	-- label that is wanted - the same trap the professions check above walked into.
	for _, label in ipairs { "Overview", "Bags", "Activity", "Professions", "Currencies",
		"Crafting", "Miscellaneous" } do
		local clicked = clickLastButton(label)
		check("the " .. label:lower() .. " set is drawn", clicked)

		for _, locale in ipairs { "enUS", "deDE", "frFR", "esES", "ruRU" } do
		Family.locale = locale
		Family.UI:Refresh()
		local over = {}
		for _, f in ipairs(fontStrings) do
			local parent = type(f.__parent) == "table" and f.__parent or nil
			-- A grid cell is a font string given a column's worth of room and no more.
			-- Anything wider than the widest column is a caption or a note, and those are
			-- meant to wrap onto a second line rather than fit on one.
			if f.__visible ~= false and (parent == nil or parent.__shown ~= false)
				and type(f.__text) == "string" and f.__text ~= ""
				and type(f.__width) == "number" and f.__width > 0 and f.__width <= 130
			then
				local wide = f:GetStringWidth() or 0
				if wide > f.__width then
					over[#over + 1] = string.format("%q %d > %d", f.__text, math.ceil(wide),
						math.ceil(f.__width))
				end
			end
		end
		check("every cell of the " .. label:lower() .. " set fits its column in " .. locale,
			#over == 0, table.concat(over, " | "))
		end
	end

	Family.locale = wasLocale
	Family.UI:Refresh()
	Family.Database:Forget("Busy-FireMaw")
	Family.Database:Forget("Soon-FireMaw")
	Family.Database:Forget("Later-FireMaw")
end)()

Family.UI:ShowTab("summary")
clickLastButton("Professions")
check("a member's secondary skills are drawn on a line of their own",
	visibleText("Cooking") and visibleText("Blacksmithing"))
check("and the primaries have room for an uncapped rank",
	visibleText("287") and visibleText("/375"))

-- Clicking a profession opens it, on that member, in the panel that is about professions.
-- The cursor decides which one: the answer should be the profession that was clicked rather
-- than whichever of that member's comes first.
local professionRow
for _, f in ipairs(frames) do
	if f.__shown == true and f.professions and f.memberKey == key then
		professionRow = professionRow or f
	end
end
check("a professions row knows which profession each cell is showing",
	professionRow ~= nil and professionRow.professions[2] == "Blacksmithing",
	professionRow and tostring(professionRow.professions[2]))

if professionRow then
	professionRow.__scripts.OnClick(professionRow, "LeftButton")
	check("clicking one opens the professions panel",
		Family.UI:CurrentTab() == "professions", tostring(Family.UI:CurrentTab()))
	check("on the member whose row was clicked, and the profession under the cursor",
		visibleText("Blacksmithing"))
	Family.UI:ShowTab("summary")
end

do
-- Currencies are columns nobody wrote down: which of them exist is the client's business and
-- differs by expansion, so the set asks the family what it holds and builds columns for that.
-- The first button with that text, not the last: the character panel has a Currencies
-- section of its own and was built later, so clickLastButton walks onto the wrong panel -
-- the third time this file has caught itself addressing a control by where it was made.
Family.UI:ShowTab("summary")
clickButton("Currencies")
check("the currencies a member holds each get a column", visibleText("Honor"))
check("with what they hold in it", visibleText("12,340"))
check("and the set totals, because currencies add up", visibleText("Total"))

-- Most held first. Honor is in the tens of thousands and arena points in the hundreds, so a
-- row with room for one has to carry the honor - and a set that ordered them by name or by
-- id would carry the other.
local honorColumn, arenaColumn
for _, f in ipairs(fontStrings) do
	if f.__text == "Honor" then honorColumn = f end
	if f.__text == "Arena" then arenaColumn = f end
end
check("the ones the family has most of come first",
	honorColumn ~= nil and arenaColumn ~= nil,
	tostring(honorColumn) .. " " .. tostring(arenaColumn))
end

clickLastButton("Overview")

-- A set where nothing adds up gets no totals line at all. Under the professions columns it
-- was a row of blank cells labelled "Total", and the blank spacer beneath it kept whatever
-- the previous column set had left in those cells - which is how a realm came to be given
-- two totals, one of them showing another panel's figures.
clickButton("Miscellaneous")

-- What a character has banked in a Chronoboon, beside the other facts about a thing they are
-- carrying. Recording it and showing it are two claims, and until now only the first was held -
-- the count went to disk every bag scan and no panel ever drew it.
do
	local key = Family:CurrentMember()

	-- The cell on this member's row, found by asking which column the boon ended up in.
	--
	-- It was cell six - "member, guild, hearthstone, race, class, then this" - counted out by
	-- hand in a comment, and a column inserted before it moved every one of those without the
	-- comment noticing. `UI.__summaryColumns` is what the panel actually drew, so counting is
	-- not needed at all: the member column leads and the set's own columns follow it.
	local function boonCellOf(memberKey)
		local at
		for index, column in ipairs(Family.UI.__summaryColumns or {}) do
			if column.key == "boon" then at = index end
		end
		if not at then return nil end

		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true and f.memberKey == memberKey then
				local cell = f.cells[at]
				if cell then return cell.__text end
			end
		end
		return nil
	end

	-- Four answers and not two, which is §2.2 plus the difference between the two facts. The
	-- figure counts the **buffs trapped**, not the boons carried: there is only ever one boon,
	-- so counting those was counting to one.
	Family.Database:SetMeta(key, { boons = true,
		banked = { { icon = 134153, minutes = 120 }, { icon = 136109, minutes = 60 } } })
	clickButton("Overview") clickButton("Miscellaneous")
	check("the figure is how many buffs are trapped", boonCellOf(key) == "2",
		tostring(boonCellOf(key)))

	-- One buff in the boon is 1 and not "a boon", which is the whole of the change: with the
	-- old cell both of these said 1 and one of them was counting the wrong thing.
	Family.Database:SetMeta(key, { banked = { { icon = 134153, minutes = 120 } } })
	clickButton("Overview") clickButton("Miscellaneous")
	check("and one trapped buff is one", boonCellOf(key) == "1", tostring(boonCellOf(key)))

	-- A boon carried whose rows nobody could read is not none, and is not a number either.
	Family.Database:SetMeta(key, { banked = Family.CLEAR, boons = true })
	clickButton("Overview") clickButton("Miscellaneous")
	check("a boon whose contents were never read says it does not know",
		boonCellOf(key) == Family.UI.UNKNOWN, tostring(boonCellOf(key)))

	Family.Database:SetMeta(key, { boons = Family.CLEAR })
	clickButton("Overview") clickButton("Miscellaneous")
	check("one with none says nothing at all", boonCellOf(key) == "", tostring(boonCellOf(key)))

	local heldSeen = (Family.Database:Members()[key].meta or {}).bagsSeen
	Family.Database:SetMeta(key, { bagsSeen = Family.CLEAR })
	clickButton("Overview") clickButton("Miscellaneous")
	check("and one whose bags nobody has read says it does not know",
		boonCellOf(key) == Family.UI.UNKNOWN, tostring(boonCellOf(key)))

	Family.Database:SetMeta(key, { bagsSeen = heldSeen })
	clickButton("Overview") clickButton("Miscellaneous")

	-- The Guild cell, one column to the left, and the same §2.2 question asked of it. Second:
	-- member, then this.
	local function guildCellOf(memberKey)
		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true and f.memberKey == memberKey then
				local cell = f.cells[2]
				if cell then return cell.__text end
			end
		end
		return nil
	end

	local heldGuild = (Family.Database:Members()[key].meta or {}).guild

	Family.Database:SetMeta(key, { guild = "Late Night Raiders", guildless = Family.CLEAR })
	clickButton("Overview") clickButton("Miscellaneous")
	check("a character in a guild is named by it",
		guildCellOf(key) == "Late Night Raiders", tostring(guildCellOf(key)))

	-- Said outright by the client, so it is a fact about the character and is drawn as one.
	Family.Database:SetMeta(key, { guild = Family.CLEAR, guildless = true })
	clickButton("Overview") clickButton("Miscellaneous")
	check("one the client said is in no guild says nothing at all",
		guildCellOf(key) == "", tostring(guildCellOf(key)))

	-- And everybody else. Nobody has scanned them, or the client would not say - and the two
	-- used to look exactly like the line above, which is the bug this separates out.
	Family.Database:SetMeta(key, { guildless = Family.CLEAR })
	clickButton("Overview") clickButton("Miscellaneous")
	check("and one nobody has asked says it does not know",
		guildCellOf(key) == Family.UI.UNKNOWN, tostring(guildCellOf(key)))

	Family.Database:SetMeta(key, { guild = heldGuild or Family.CLEAR })
	clickButton("Overview") clickButton("Miscellaneous")
end

check("a column set with nothing to add up is given no totals line",
	visibleText("Total") == false)
-- Exactly, not merely containing: the footer under the table says "Grand totals:" whatever
-- set is on screen, and that is the line it is supposed to say it on.
local function visibleExactly(text)
	for _, f in ipairs(fontStrings) do
		local parent = type(f.__parent) == "table" and f.__parent or nil
		if f.__text == text and f.__visible ~= false
			and parent and parent.__shown ~= false then
			return true
		end
	end
	return false
end

check("nor a grand total", visibleExactly("Grand totals") == false)

-- One realm still has to end somewhere. The blank line between them was written as part of
-- the totals, so the two sets with nothing to total ran their realms straight together.
local function blankRowShowing()
	for _, f in ipairs(frames) do
		if f.cells and f.__shown == true then
			local empty = true
			for _, cell in ipairs(f.cells) do
				if type(cell.__text) == "string" and cell.__text ~= "" then empty = false end
			end
			if empty then return true end
		end
	end
	return false
end

check("but the realms are still held apart from one another", blankRowShowing())

clickButton("Overview")
check("and the set that does add up still has them",
	visibleText("Total") and visibleExactly("Grand totals"))

-- Removing a member on demand: right-click their row, and confirm.
local auberdineRow
for _, f in ipairs(frames) do
	if f.memberKey == "Tester-Auberdine" then auberdineRow = f end
end
check("a summary row knows which member it is", auberdineRow ~= nil)

if auberdineRow then
	auberdineRow.__scripts.OnClick(auberdineRow, "RightButton")
	check("right-clicking a member removes them once confirmed",
		Family.Database:Meta("Tester-Auberdine") == nil)
	check("and leaves everybody else alone", Family.Database:Meta(key) ~= nil)
end

-- A heading or a totals line is not a member, and must not carry the one that was drawn in
-- that row last time.
-- Rows that are drawn. A hidden one keeps whatever it last held and cannot be clicked, so
-- what matters is that nothing on screen still points at a member who is gone.
local headingCarriesMember = false
for _, f in ipairs(frames) do
	if f.__shown == true and f.memberKey == "Tester-Auberdine" then
		headingCarriesMember = true
	end
end
check("and no row on screen is left holding a member that is gone",
	headingCarriesMember == false)

Family.Database:Forget("Tester-Auberdine")

print()
print("window layering is a setting, not a guess")
check("defaults high enough to clear most HUDs", Family.UI:CurrentStrata() == "HIGH")
check("accepts a known strata", Family.UI:SetStrata("dialog") == "DIALOG")
check("and remembers it", FamilyDB.ui.strata == "DIALOG")
check("refuses one that would cover tooltips", Family.UI:SetStrata("TOOLTIP") == nil)
Family.UI:SetStrata("HIGH")

SlashCmdList["FAMILY"]("forget Tester-FireMaw")
check("forget removes the member", Family.Database:Meta(key) == nil)

local okRefresh, refreshErr = pcall(function() Family.UI:Refresh() end)
check("summary survives an empty database", okRefresh, tostring(refreshErr))

print()
print("wide family")

-- Off, the panel still says what it is and where its switch is
--
-- Both sharing features ship off and both panels are in the list either way, each explaining
-- itself rather than carrying a switch: they are together in Options, so a player looks in one
-- place. Borrowed and given back, because everything below needs the feature on.
do
	local was = Family.Wide:Enabled()
	Family.Wide:SetEnabled(false)
	Family.UI:Show()
	Family.UI:ShowTab("wide")
	Family.UI:Refresh()

	check("the wide family panel points at the switch rather than looking broken",
		visibleText("nothing here will do anything yet"))

	-- And what is under it starts below it. The sentence is one line in English and two in
	-- French, and the box beneath it used to be pinned at a fixed drop measured in the
	-- language it was written in - so in French the two were drawn through each other.
	do
		local note
		for _, f in ipairs(fontStrings) do
			if type(f.__text) == "string"
				and f.__text:find("nothing here will do anything yet", 1, true) then
				note = f
			end
		end
		local box = _G.FamilyWideAsk
		local under = box and box.__offsets and box.__offsets.TOPLEFT
		-- Below the title the note hangs from, plus the whole of the note. A drop that
		-- clears one line of it and not two is exactly the fault: right in English, drawn
		-- through itself in French.
		local wanted = math.ceil(note and note:GetStringHeight() or 0) + 30
		check("and its own controls are greyed too, for the same reason",
			_G.FamilyWideAskButton and _G.FamilyWideAskButton.__enabled == false,
			tostring(_G.FamilyWideAskButton and _G.FamilyWideAskButton.__enabled))

		check("and the box under it starts below the whole of it",
			note ~= nil and under ~= nil and math.abs(under.y) >= wanted,
			(under and tostring(under.y) or "not anchored") .. " against " .. tostring(wanted))
	end

	Family.Wide:SetEnabled(was)
	Family.UI:Refresh()
	check("and stops saying it once the feature is on",
		not visibleText("nothing here will do anything yet"))
end
-- Run as a function of its own rather than inline.
--
-- Lua allows two hundred local variables per function and this file is one long function
-- that is close to the limit. A do-block frees its names on the way out but still counts
-- them while inside it, so the only thing that actually buys room is another function.
;(function()
-- Two families, in one Lua state.
--
-- There is only one copy of Family here, so "the other family" is this one wearing a
-- different FamilyDB.wide. That is enough to put the whole protocol through its paces,
-- because the protocol is the part with the risk in it: what leaves this side is decided
-- entirely by this side's grants, and what arrives is decided entirely by theirs.
--
-- The channel is looped back rather than stubbed out. Every message goes through the real
-- chunking, is cut at the real size and is handed to the real reassembly, so a body too long
-- for one message is tested by the fact that half these checks would fail without it.
do
	-- A member to share, made here rather than borrowed from earlier in this file: the
	-- checks above this point delete members on purpose, and a section that quietly depended
	-- on one of them surviving would pass or fail according to what was tested before it.
	Family.Database:SetMeta(key, { name = "Tester", realm = "Fire Maw", classFile = "MAGE",
		level = 60, money = 12345678, faction = "Horde", race = "Gnome",
		skills = { [164] = { name = "Blacksmithing", rank = 287, maxRank = 375 } } })
	Family.Database:SetPayload(key, {
		bags = { [0] = { size = 16, free = 14, slots = { [1] = { id = 6948, count = 1 } } } },
		professions = { [164] = { recipes = { { name = "Runed Copper Breastplate" } } } },
		talents = { groups = {} },
		quests = { list = {} },
	})

	local sent = {}
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, text, channel, target)
			sent[#sent + 1] = { prefix = prefix, text = text, channel = channel,
				target = target }
			return true
		end,
	}

	-- The two saved files. Swapping which one is installed is what makes this side "them".
	--
	-- Both have the feature switched on, because both are players who typed /family wide on -
	-- that being the only way anybody has it at all. Two families where one had it off would
	-- be testing the gate, which is done further up, rather than the protocol.
	local ours, theirs = { enabled = true }, { enabled = true }

	local function wearing(which, fn)
		local before = FamilyDB.wide
		FamilyDB.wide = which
		local ok, err = pcall(fn)
		which = FamilyDB.wide
		FamilyDB.wide = before
		if not ok then error(err, 0) end
		return which
	end

	-- Everything queued so far, delivered to whoever is wearing the database now. The queue
	-- drains on a timer in the game; here it is emptied by hand so a check knows exactly
	-- what has and has not arrived.
	local function deliver(from)
		local queue = sent
		sent = {}
		for _, message in ipairs(queue) do
			Family.Comm:Receive(message.text, from, message.channel)
		end
		return #queue
	end

	-- A body far longer than a single addon message, which is the case every real exchange
	-- is: one member's bags do not fit in 255 bytes and never will.
	local long = string.rep("possessions ", 200)
	sent = {}
	-- Its own kind, not one Wide Family uses: replacing a real handler to watch a message
	-- arrive leaves it replaced, and every check after this one would then be testing a
	-- protocol with a hole in it.
	Family.Comm:Send("probe", long, "WHISPER", "Someone", false)
	check("a body too long for one message is sent in pieces", #sent > 1, tostring(#sent))

	local rebuilt
	Family.Comm:On("probe", function(_, body) rebuilt = body end)
	deliver("Someone")
	check("and arrives as the one body it started as", rebuilt == long,
		rebuilt and (#rebuilt .. " bytes of " .. #long) or "nothing")

	print()
	print("  linking, and what it does not do")

	-- Asking to link sends a request and nothing else. Not a member list, not a name, not
	-- what anybody has - §6 is explicit that nothing whatever is exchanged until somebody
	-- accepts, and this is the check that keeps it that way.
	sent = {}
	ours = wearing(ours, function()
		Family.Wide:RequestLink("Faraway")
	end)

	check("asking to link sends something", #sent > 0)

	-- It says who is asking, which the person being whispered can see anyway, and nothing
	-- else. No member list, no possessions, no money - §6 is explicit that nothing whatever
	-- is exchanged until somebody accepts, and this is the check that keeps it that way.
	local asking = Family.Codec:FromWire(sent[1] and sent[1].text:match("[^\1]*$") or "")
	check("and it carries no member of ours at all",
		type(asking) == "table" and asking.members == nil and asking.payload == nil
			and asking.offering == nil,
		type(asking) == "table" and "a table with " .. tostring(asking.members) or "nothing")

	-- Having asked is a state the player can see. Nothing acknowledges an addon whisper, so
	-- an undelivered request and an unanswered one look identical from here - which is the
	-- reason the waiting is shown at all rather than left to be inferred.
	ours = wearing(ours, function()
		local waitingOn = Family.Wide:Outgoing()
		check("asking is remembered as something we are waiting on",
			#waitingOn == 1 and waitingOn[1].name == "Faraway",
			#waitingOn .. " pending")
		check("and is not called unanswered the moment it is sent",
			waitingOn[1] and waitingOn[1].unanswered == false)

		-- Wound back past the threshold rather than waited out: the point being tested is
		-- what the panel says once enough time has passed, not how long enough is.
		Family.Wide:Store().pendingOut["Faraway"].at = time() - 3600
		check("but is, once long enough has gone by with nothing back",
			Family.Wide:Outgoing()[1].unanswered == true)
		Family.Wide:Store().pendingOut["Faraway"].at = time()
	end)

	-- A copy with the feature switched off is not merely quiet, it is deaf. The same request
	-- is replayed into one - without draining the queue, so the real exchange below still
	-- gets it - and must leave no trace at all. "Off" that quietly banks requests for
	-- whenever somebody switches it on is not off.
	local heldRequests
	wearing({ enabled = false }, function()
		for _, message in ipairs(sent) do
			Family.Comm:Receive(message.text, "Tester", message.channel)
		end
		heldRequests = Family.Wide:Requests()
	end)
	check("a copy with wide family off does not even record the request",
		next(heldRequests) == nil)

	-- The other side hears it. Nothing is linked yet: a request is written down and a
	-- person is asked, because accepting is a decision and not a protocol step.
	local theirRequests
	theirs = wearing(theirs, function()
		deliver("Tester")
		theirRequests = Family.Wide:Requests()
	end)

	local requestID
	for id in pairs(theirRequests or {}) do requestID = id end

	check("the other side is asked rather than linked", requestID ~= nil)

	theirs = wearing(theirs, function()
		check("and until they answer, they are linked to nobody",
			next(Family.Wide:Links()) == nil)
	end)

	-- They accept.
	sent = {}
	theirs = wearing(theirs, function()
		Family.Wide:Accept(requestID)
	end)
	ours = wearing(ours, function() deliver("Faraway") end)

	local ourLinkID
	ours = wearing(ours, function()
		for id in pairs(Family.Wide:Links()) do ourLinkID = id end
	end)
	check("accepting links both sides", ourLinkID ~= nil)

	ours = wearing(ours, function()
		check("and the answer stops us waiting on them",
			#Family.Wide:Outgoing() == 0,
			#Family.Wide:Outgoing() .. " still pending")

		-- Giving up on one nobody answered. It sends nothing: there is no reason to think
		-- anybody is listening, which is the whole reason for giving up.
		Family.Wide:RequestLink("Nobody")
		sent = {}
		local gone = Family.Wide:Forget("Nobody")
		check("a request can be given up on", gone == true and #Family.Wide:Outgoing() == 0)
		check("and giving up whispers nobody", #sent == 0, #sent .. " messages")
		check("while giving up on a name never asked is refused",
			Family.Wide:Forget("Nobody") == false)
	end)

	----------------------------------------------------------------------------------------
	-- A second character of a family we are already linked with
	--
	-- Reported from a live client. Two characters of one family were asked, the first
	-- accepted, and the request to the second sat on the panel reading "waiting for them to
	-- answer" for ever - about a link that already existed. A link is between families, so
	-- the second request was answered by the fact of the link, and the answer was never sent:
	-- the far end recognised the case, wrote a comment about a client that had lost track,
	-- and returned in silence, leaving that client exactly as lost.
	----------------------------------------------------------------------------------------

	sent = {}
	ours = wearing(ours, function()
		Family.Wide:RequestLink("Nervina")
		check("a second character of a linked family can still be asked",
			#Family.Wide:Outgoing() == 1, #Family.Wide:Outgoing() .. " pending")
	end)

	local answered = 0
	theirs = wearing(theirs, function()
		deliver("Tester")
		check("their side does not raise a second decision about it",
			next(Family.Wide:Requests()) == nil)
		answered = #sent
	end)

	check("but answers it rather than meeting it with silence", answered > 0,
		tostring(answered) .. " sent back")

	ours = wearing(ours, function()
		local mark = #DEFAULT_CHAT_FRAME.messages
		deliver("Nervina")

		check("and the answer ends the waiting", #Family.Wide:Outgoing() == 0,
			#Family.Wide:Outgoing() .. " still pending")

		-- Said once, when the link is made. Announcing it again for a link that was already
		-- there is how the fix for one confusion becomes another.
		local said = false
		for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
			if tostring(DEFAULT_CHAT_FRAME.messages[index]):find("Linked with", 1, true) then
				said = true
			end
		end
		check("without announcing a link that was already there", said == false)
	end)

	-- The other half, which does not need the far end to be new enough to answer at all: a
	-- character of theirs that arrives in an exchange is one there is no point waiting on,
	-- whatever their client does about the request itself.
	local theirLinkID
	theirs = wearing(theirs, function()
		for id in pairs(Family.Wide:Links()) do theirLinkID = id end
	end)

	sent = {}
	ours = wearing(ours, function()
		Family.Wide:Store().pendingOut["Faraway"] = { at = time() }
		check("a character of theirs we already know can be asked", #Family.Wide:Outgoing() == 1)
	end)

	sent = {}
	theirs = wearing(theirs, function()
		Family.Wide:ExchangeWith(theirLinkID, "a check")
	end)

	ours = wearing(ours, function()
		deliver("Faraway")
		check("and hearing from them at all ends it, with no answer to the request needed",
			#Family.Wide:Outgoing() == 0, #Family.Wide:Outgoing() .. " still pending")
	end)

	print()
	print("  what may be seen, one member and one category at a time")

	ours = wearing(ours, function()
		local link = Family.Wide:Links()[ourLinkID]
		local _, count = Family.Wide:Offering(link)
		check("a new link is granted nothing at all", count == 0, tostring(count))

		-- One member, one category.
		sent = {}
		Family.Wide:Grant(ourLinkID, key, "possessions", true)

		local offered = Family.Wide:Offering(link)
		local entry = offered[key]
		check("granting one member offers that member", entry ~= nil)
		check("with the identity that makes them a member at all",
			entry and entry.meta and entry.meta.name == "Tester",
			entry and entry.meta and tostring(entry.meta.name))
		check("and the category granted", entry and entry.payload
			and entry.payload.bags ~= nil)

		-- The part that matters. Everything not granted is absent, and absent means the
		-- key is not there rather than there and empty.
		check("and nothing else: not professions",
			entry and entry.payload and entry.payload.professions == nil)
		check("not talents", entry and entry.payload and entry.payload.talents == nil)
		check("not quests", entry and entry.payload and entry.payload.quests == nil)
		check("not the money, which is its own category",
			entry and entry.meta and entry.meta.money == nil,
			entry and entry.meta and tostring(entry.meta.money))

		-- And nobody else, however many members this family has.
		local offeredCount = 0
		for _ in pairs(offered) do offeredCount = offeredCount + 1 end
		check("and no other member of ours", offeredCount == 1, tostring(offeredCount))
	end)

	print()
	print("  what arrives, and where it is kept")

	theirs = wearing(theirs, function()
		deliver("Tester")

		local borrowed = Family.Wide:BorrowedMembers()
		check("the granted member arrives", #borrowed == 1, tostring(#borrowed))
		check("marked as belonging to another family",
			borrowed[1] and borrowed[1].family == Family.Wide:ID() == false
				and borrowed[1].family ~= nil)
		check("and carrying only what was granted",
			borrowed[1] and borrowed[1].payload and borrowed[1].payload.bags ~= nil
				and borrowed[1].payload.professions == nil)
	end)

	-- Never merged. §6: linked data is stored separately and is never edited, so a borrowed
	-- member must not turn up among this family's own however convenient that would be.
	theirs = wearing(theirs, function()
		local own = false
		for memberKey in pairs(Family.Database:Members()) do
			if memberKey == key then own = true end
		end
		check("but the summary's own members are untouched by any of it", own == true)
	end)

	print()
	print("  taking it back")

	-- Revoking is the half that has to be prompt. Waiting for somebody to press Update would
	-- mean the other side kept it for as long as nobody did.
	sent = {}
	ours = wearing(ours, function()
		Family.Wide:Grant(ourLinkID, key, "possessions", false)
		local link = Family.Wide:Links()[ourLinkID]
		local _, count = Family.Wide:Offering(link)
		check("revoking the last category stops offering that member", count == 0,
			tostring(count))
	end)
	check("and says so at once rather than at the next exchange", #sent > 0)

	theirs = wearing(theirs, function()
		deliver("Tester")
		check("so the other side forgets them", #Family.Wide:BorrowedMembers() == 0,
			tostring(#Family.Wide:BorrowedMembers()))
	end)

	print()
	print("  versions that do not match")

	-- §6 states this as a requirement rather than leaving it to the implementation, because
	-- getting it wrong corrupts records instead of failing visibly.
	theirs = wearing(theirs, function()
		local link
		for _, entry in pairs(Family.Wide:Links()) do link = entry end
		local body = Family.Codec:ToWire({ family = (function()
			for id in pairs(Family.Wide:Links()) do return id end
		end)(), schema = 99, members = { ["Ghost-Nowhere"] = { meta = { name = "Ghost" } } } })

		Family.Comm:Receive("1\0011\0011\001data\001" .. body, "Tester", "WHISPER")

		check("a payload from a version we cannot read is refused, not merged",
			#Family.Wide:BorrowedMembers() == 0)
		check("and the link says why in words", link and link.problem ~= nil,
			link and tostring(link.problem))
	end)

	print()
	print("  in combat")

	-- Sending is not forbidden in combat. It is deferred all the same, for bulk only: a
	-- hundred chunks during a boss fight competes with the raid's own addons for a channel
	-- they need more than Family does. A reply somebody is waiting for still goes.
	sent = {}
	InCombatLockdown = function() return true end
	Family.Comm:Send("data", string.rep("x", 900), "WHISPER", "Faraway", true)
	check("bulk waits for the fight to be over", #sent == 0, tostring(#sent))

	Family.Comm:Send("hello", "small", "WHISPER", "Faraway", false)
	check("but a control message does not", #sent > 0, tostring(#sent))

	InCombatLockdown = function() return false end
	fire("PLAYER_REGEN_ENABLED")
	check("and the fight ending sends what was waiting", #sent > 1, tostring(#sent))

	print()
	print("  the panel")

	-- Drawn with the two families this section made, so the grid has something to draw.
	ours = wearing(ours, function()
		Family.UI:ShowTab("wide")
		check("the wide family panel draws", Family.UI:CurrentTab() == "wide")
		-- By whatever the link is actually called. In this loopback both sides are the
		-- same character, so the name is not the one that was typed - and hard-coding the
		-- typed one would be checking the harness's fiction rather than the panel.
		local linkName
		for _, link in pairs(Family.Wide:Links()) do linkName = link.name end
		check("and names the family it is linked to",
			linkName ~= nil and visibleText(linkName), tostring(linkName))

		-- The consent grid is the specification's shape and the reason for it: a list of
		-- switches would let somebody agree to a thing without seeing the size of it.
		local linkRow
		for _, f in ipairs(frames) do
			if f.__shown == true and f.__scripts.OnClick and type(f.text) == "table"
				and type(f.text.__text) == "string"
				and linkName and f.text.__text:find(linkName, 1, true) then
				linkRow = f
			end
		end
		check("a link can be opened", linkRow ~= nil)

		-- How many of the consent grid's column headings are on screen. They are drawn
		-- on the row that carries them and were never hidden again, so they stayed on
		-- top of whatever that row was used for next - which on the live panel was the
		-- sentence about siblings, read through eight category names lying across it.
		-- Only what this panel's own rows are drawing. Category names are ordinary words -
		-- Mail, Quests, Money - and a sweep of every font string in the client finds them
		-- on the summary and in a tooltip, which says nothing about this grid.
		local wideList = linkRow and linkRow.__parent

		local function headingsShowing()
			local showing = 0
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				-- A heading is now a button of its own sitting on the row, so the
				-- row is a grandparent rather than a parent. Both are accepted: what
				-- is being asked is whether this panel is drawing it, not how deep.
				local row = parent and type(parent.__parent) == "table"
					and parent.__parent or nil

				if type(f.__text) == "string" and f.__visible ~= false
					and parent and parent.__shown ~= false
					and (parent.__parent == wideList
						or (row and row.__parent == wideList
							and row.__shown ~= false)) then
					for _, category in ipairs(Family.Wide.CATEGORIES) do
						if f.__text:find(category.label, 1, true) then
							showing = showing + 1
						end
					end
				end
			end
			return showing
		end

		if linkRow then
			-- A family that shares somebody back, which the panel had never been drawn
			-- with here and is the state both live clients were in. It matters because it
			-- puts a section *after* the links: closing the grid then shortens the list
			-- and the rows the grid was using are handed straight to that section, rather
			-- than simply going out of use. A pooled row is only dangerous when something
			-- else takes it, so a panel that only ever grows proves nothing.
			for _, link in pairs(Family.Wide:Links()) do
				link.members = link.members or {}
				-- On our own realm, so the summary nests them under a heading that
				-- already has our members under it - which is the arrangement the
				-- indentation has to be right for. Their money is deliberately absent:
				-- money is a category of its own and this family has not granted it.
				link.members["Grella-FireMaw"] = {
					meta = { name = "Grella", realm = "Fire Maw", classFile = "PRIEST",
						level = 61 },
					seen = time(),
				}
				-- Shared on the same terms and never made a sibling, which is the case
				-- the panels were failing: a family grants you eight categories about
				-- somebody and, until this member existed here, there was nowhere at all
				-- to look at any of it.
				link.members["Guest-FireMaw"] = {
					meta = { name = "Guest", realm = "Fire Maw", classFile = "DRUID",
						level = 44, skills = { Tailoring = { rank = 300, max = 300 } } },
					payload = { equipment = { itemLevel = 61.5, counted = 16 },
						professions = { Tailoring = { recipes = {} } } },
					-- What their side said it was granting, which is what a current
					-- Family sends. Grella above carries none, which is what an older
					-- one sends, so both readings are exercised.
					granted = { "equipment", "professions" },
					seen = time(),
				}
			end


			-- Drawn again, so the section listing what they share is actually on screen
			-- before it is counted.
			Family.UI:ShowTab("wide")

			-- Measured against the panel with the grid shut rather than against nought.
			-- The section listing what they share with *us* heads the same nine columns,
			-- and those headings are legitimately on screen the whole time - so what is
			-- being asked is whether opening the consent grid adds its own set and closing
			-- it takes that set away, not whether any category name is visible anywhere.
			local closed = headingsShowing()

			linkRow.__scripts.OnClick(linkRow)
			check("and opening it shows the categories to grant",
				visibleText("Possessions") and visibleText("Professions")
					and visibleText("Reputations"))
			check("and says that nothing is ticked to begin with",
				visibleText("Nothing is ticked to begin with"))
			check("and does not claim to be a lock", visibleText("not a lock"))

			local open = headingsShowing()
			-- Both grids, because opening a family now shows both halves of the link:
			-- what they may see of ours, and what they share of theirs. Two sets of the
			-- same nine columns in the same places, so the two read against each other.
			check("opening a family heads the columns of both its grids",
				open == closed + 2 * #Family.Wide.CATEGORIES,
				open .. " against " .. closed .. " + two lots of "
					.. #Family.Wide.CATEGORIES)

			-- §6 asks for members drawn under the realm they are on, and both lists here
			-- ran flat: a family across three realms arrived as one undivided column of
			-- names, with nothing saying which realm a row was on and no way at all to
			-- tell apart two characters sharing a name.
			local function drawnOnPanel(needle)
				for _, f in ipairs(fontStrings) do
					local parent = type(f.__parent) == "table" and f.__parent or nil
					local row = parent and type(parent.__parent) == "table"
						and parent.__parent or nil
					if type(f.__text) == "string" and f.__visible ~= false
						and parent and parent.__shown ~= false
						and (parent.__parent == wideList
							or (row and row.__parent == wideList
								and row.__shown ~= false))
						and f.__text:find(needle, 1, true) then
						return true
					end
				end
				return false
			end

			-- Every realm our own members are on, asked of the database rather than
			-- written down here: a list of realms typed into the check would go on
			-- passing after the fixture had moved on without them.
			local ourRealms, missing = {}, nil
			for _, entry in pairs(Family.Database:Members()) do
				local realm = (entry.meta or {}).realm
				if realm then ourRealms[realm] = true end
			end
			-- The heading's own colour and not merely the realm's name: realm names are
			-- written all over this panel already - in tooltips, in a member key, in the
			-- summary behind it - so a check that looked for the bare word passed just as
			-- happily with both lists left flat. Asked for and mutation-tested, twice.
			local function headed(realm)
				return drawnOnPanel("|cff8888ff" .. realm)
			end

			for realm in pairs(ourRealms) do
				if not headed(realm) then missing = realm end
			end

			-- Counted, not merely looked for. Both lists head the same realm names, so a
			-- check that only asked whether a realm appeared went on passing with either
			-- list left flat - the other one was still naming it. The number of headings
			-- is what tells the two apart, and it is worked out from the data rather than
			-- written down.
			local function groupsIn(list)
				local seen, n = {}, 0
				for _, member in ipairs(list) do
					local meta = member.meta or {}
					local key = (meta.realm or "?") .. "\1" .. tostring(meta.faction)
					if not seen[key] then
						seen[key] = true
						n = n + 1
					end
				end
				return n
			end

			local mine, borrowed = {}, {}
			for _, entry in pairs(Family.Database:Members()) do
				mine[#mine + 1] = { meta = entry.meta or {} }
			end
			for _, member in ipairs(Family.Wide:BorrowedMembers()) do
				borrowed[#borrowed + 1] = member
			end
			local wanted = groupsIn(mine) + groupsIn(borrowed)

			local headings = 0
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string"
					and f.__text:find("|cff8888ff", 1, true)
					and parent and parent.__parent == wideList then
					headings = headings + 1
				end
			end

			check("both grids head every realm their members are on, and no more",
				headings == wanted,
				headings .. " headings against " .. wanted .. " realm-and-faction groups")

			-- The switch above the list says when an exchange happens by itself, and the
			-- line under it says that this is the only time it does. Without that second
			-- line "automatically" reads as though Family kept two families in step while
			-- both are played, which it does not and is not meant to (§6).
			check("the panel says that coming online is the only automatic exchange",
				visibleText("only time it happens on its own"))
			check("and where to go for one on demand", visibleText("Update now"))

			-- Both halves under the one family, which is the whole of the rearrangement:
			-- what they may see of ours and what they share of theirs, in one place,
			-- because a link is one family and was being drawn as two things.
			check("what they share back is listed under that same family",
				visibleText("shares with you") and visibleText("Grella"))
			check("and what they may see of ours is under it too",
				visibleText("may see of your characters"))

			linkRow.__scripts.OnClick(linkRow)

			------------------------------------------------------------------------------
			-- The other direction
			--
			-- The consent grid answers "what do they see of mine". Nothing answered "what
			-- do I see of theirs", which is the half somebody is actually looking at when
			-- they wonder whether a link is worth having.
			------------------------------------------------------------------------------

			do
				local guest, grella
				for _, member in ipairs(Family.Wide:BorrowedMembers()) do
					if member.meta.name == "Guest" then guest = member end
					if member.meta.name == "Grella" then grella = member end
				end

				check("what a family shares about each member is worked out",
					guest ~= nil and grella ~= nil)

				-- Their word for it, not ours. A member with no auctions and a member
				-- whose auctions were not shared send the same nothing, so a panel that
				-- inferred it from what arrived would report the first as the second -
				-- inventing a fact out of an absence.
				check("from what they said they granted rather than from what arrived",
					guest and guest.toldUs == true)
				check("and it names the categories they actually granted",
					guest and guest.received.equipment == true
						and guest.received.professions == true)
				check("and not the ones they did not",
					guest and guest.received.mail ~= true
						and guest.received.money ~= true)

				-- An older Family says nothing about its grants. Answering nothing at all
				-- for one of those would make the panel look broken rather than look old.
				check("an older family that says nothing is guessed at instead",
					grella and grella.toldUs == false)
			end

			-- Shut again by the click above, which is when saying how to open it is worth
			-- anything and the only time it is said: a panel that goes on telling you to
			-- do what you have just done reads as though it had not noticed.
			check("and with a family shut its line says how to open it",
				visibleText("click the name to open"))
			check("and closing it takes both sets of column headings with it",
				headingsShowing() == closed,
				headingsShowing() .. " against " .. closed)

			linkRow.__scripts.OnClick(linkRow)
			check("and it stops saying that once it is open",
				visibleText("click the name to open") == false)
			linkRow.__scripts.OnClick(linkRow)

			-- The other half of the same fault: a row handed on from the grid, where the
			-- name column is narrow, used to keep the narrow column - which is why a
			-- borrowed member once read "Grella of Grella-Thunder...".
			--
			-- Asked of a heading rather than of the member row, because that row now sets
			-- its own width every draw and so cannot answer the question. A heading sets
			-- none, so nought is the only right answer for one.
			local wideName
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string"
					and f.__text:find("last exchange", 1, true)
					and parent and parent.__parent == wideList
					and parent.__shown ~= false then
					wideName = f
				end
			end
			----------------------------------------------------------------------------
			-- Ticking a whole column at once
			--
			-- Eighty-eight boxes for a family of eleven, and the decision is usually one
			-- decision taken eleven times. The heading takes it once.
			----------------------------------------------------------------------------

			do
				linkRow.__scripts.OnClick(linkRow)

				local familyID, ourKeys = nil, {}
				for id in pairs(Family.Wide:Links()) do familyID = id end
				for key in pairs(Family.Database:Members()) do
					ourKeys[#ourKeys + 1] = key
				end

				local function grantedCount()
					local count = 0
					for _, key in ipairs(ourKeys) do
						if Family.Wide:Granted(familyID, key, "equipment") then
							count = count + 1
						end
					end
					return count
				end

				-- Exchanges, not wire messages: one exchange is several messages
				-- because a member's records do not fit in one, and counting those
				-- would be counting the size of the family rather than the number of
				-- times it was told.
				local exchanges = 0
				local realExchange = Family.Wide.ExchangeWith
				Family.Wide.ExchangeWith = function(...)
					exchanges = exchanges + 1
					return realExchange(...)
				end

				local heading = findButton("Equipment")
				check("the column heading is a switch for the whole column",
					heading ~= nil and reachable(heading))

				if heading then fireClick(heading) end
				check("clicking it grants that category for everybody",
					grantedCount() == #ourKeys,
					grantedCount() .. " of " .. #ourKeys)

				-- One exchange for one decision. Written as a loop over Grant it would
				-- have been one per member, which is the same promise kept eleven times
				-- over a rate-limited channel.
				check("and tells them once rather than once per member",
					exchanges == 1, tostring(exchanges))
				Family.Wide.ExchangeWith = realExchange

				heading = findButton("Equipment")
				if heading then fireClick(heading) end
				check("clicking it again clears the column", grantedCount() == 0,
					tostring(grantedCount()))

				linkRow.__scripts.OnClick(linkRow)
			end

			check("and a row that sets no width of its own is handed back with none",
				wideName ~= nil and wideName:GetWidth() == 0,
				wideName and tostring(wideName:GetWidth()) or "row not found")
		end

		-- An ask nobody answered, aged past the threshold, so the panel has to account for
		-- it. Without this the screen after asking is the screen before asking.
		Family.Wide:RequestLink("Silent")
		Family.Wide:Store().pendingOut["Silent"].at = time() - 3600
		Family.UI:ShowTab("wide")

		check("an unanswered request is shown rather than left silent",
			visibleText("Waiting for them to answer") and visibleText("Silent"))
		check("and is called unanswered in as many words", visibleText("no answer"))
		-- The honest part: three causes, no way to tell them apart from inside the client,
		-- so all three are named and none is guessed at (§11.1).
		check("and the reasons it names include the one no addon can fix",
			visibleText("cannot exchange addon messages"))

		Family.Wide:Forget("Silent")

		----------------------------------------------------------------------------------
		-- Answering somebody, by clicking the button a player would click
		--
		-- The order matters and is the fault this was written for. The panel is drawn once
		-- with no request, which builds the button pool; then a request arrives and needs a
		-- row the row pool has not built yet. That row is therefore created after those
		-- buttons, and among siblings at the same frame level the game gives the click to
		-- the one built last - so the row swallowed it and Accept and Decline were dead.
		--
		-- Every check above this one drives the panel by calling handlers directly, which
		-- is why five hundred of them passed while nothing on this panel could be clicked.
		-- These two ask the other question.
		----------------------------------------------------------------------------------

		----------------------------------------------------------------------------------
		-- A sibling on the summary
		--
		-- The panel that decides sharing is not the panel anybody reads, so this is where
		-- the decision actually shows up. Three things about it are the player's, not
		-- ours: where the names line up, that the families are held apart from our own
		-- members by a blank line, and that a category nobody granted reads as unknown
		-- rather than as nought.
		----------------------------------------------------------------------------------

		do
			for familyID in pairs(Family.Wide:Links()) do
				Family.Wide:SetSibling(familyID, "Grella-FireMaw", true)
			end

			Family.UI:ShowTab("summary")
			clickButton("Overview")

			-- In draw order, which for a pool is the order it was built in.
			local ordered, siblingRow, familyRow, ourRow = {}, nil, nil, nil
			for _, f in ipairs(frames) do
				if f.cells and f.__shown == true then
					ordered[#ordered + 1] = f
					local first = f.cells[1]
					local text = type(first.__text) == "string" and first.__text or ""

					if f.memberKey == "Grella-FireMaw" or (f.borrowed
						and text:find("Grella", 1, true)) then
						siblingRow = f
					elseif f.memberKey == Family:CurrentMember() then
						ourRow = f
					elseif not f.memberKey and linkName
						and text:find(linkName, 1, true) then
						familyRow = f
					end
				end
			end

			check("a sibling reaches the summary", siblingRow ~= nil)
			check("under its own family", familyRow ~= nil)

			-- Aligned with our own names and with the realm above, so the table has two
			-- levels. A name that starts further right than every other name reads as a
			-- different kind of thing, which is the impression §6 asks it not to give.
			local function indentOf(row)
				local text = row and row.cells[1].__text or ""
				return #(text:match("^ *") or "")
			end

			check("whose members line up with our own",
				siblingRow and ourRow and indentOf(siblingRow) == indentOf(ourRow),
				siblingRow and (indentOf(siblingRow) .. " against " .. indentOf(ourRow)))
			check("and whose name lines up with the realm's", indentOf(familyRow) == 0,
				tostring(indentOf(familyRow)))

			-- Held apart from the last of our own members rather than running on from it
			-- as though it were one more of them.
			local blankAbove
			for index, f in ipairs(ordered) do
				if f == familyRow and index > 1 then
					local above, empty = ordered[index - 1], true
					for _, cell in ipairs(above.cells) do
						if type(cell.__text) == "string" and cell.__text ~= "" then
							empty = false
						end
					end
					blankAbove = empty
				end
			end
			check("with a line's space before it", blankAbove == true)

			-- Money is a category of its own and this family granted it to nobody. An
			-- amount here would be Family stating a figure it was never told (2.2).
			local said
			for _, cell in ipairs(siblingRow and siblingRow.cells or {}) do
				if type(cell.__text) == "string" and cell.__text:find("|rg ", 1, true) then
					said = cell.__text
				end
			end
			check("and money nobody shared is not reported as none", said == nil,
				tostring(said))

			-- Somebody shared and not made a sibling. The two decisions are different
			-- questions and were the same answer: everything shared is reachable, and
			-- what appears in your own lists is only what you asked for.
			local guestKey = Family.Wide:BorrowedKey(
				select(1, next(Family.Wide:Links())), "Guest-FireMaw")

			check("somebody not made a sibling stays out of the summary",
				visibleExactly("Guest") == false)

			local function offered(list)
				for _, member in ipairs(list) do
					if member.key == guestKey then return member end
				end
			end

			check("but a panel about one member can still be pointed at them",
				offered(Family.UI:EveryMember()) ~= nil)
			-- Against the link's own name rather than a literal, so that renaming the
			-- fixture cannot leave this check quietly passing against nothing.
			local theirName = select(2, next(Family.Wide:Links())).name
			check("and says whose they are",
				type(theirName) == "string" and theirName ~= ""
					and ((offered(Family.UI:EveryMember()) or {}).group or ""):find(
						theirName, 1, true) ~= nil,
				tostring(theirName))

			-- §6 asks for a borrowed member "as a sub-section of the realm they are on,
			-- under the family they belong to". Whose they are used to be the whole of
			-- the heading, so a family with members spread over three realms arrived as
			-- one undivided run of names and the picker could not say which of two
			-- identically named characters was which.
			check("and the realm they are on, which the heading used to leave out",
				((offered(Family.UI:EveryMember()) or {}).group or ""):find(
					"Fire Maw", 1, true) ~= nil)

			-- Two realms have to make two headings, which is the whole point and is not
			-- provable from a fixture where everybody shares one realm. Added here and
			-- taken away again rather than put in the shared fixture, where it would
			-- quietly change every count the other checks make about this link.
			do
				local id, link = next(Family.Wide:Links())
				link.members["Faraway-Earthshaker"] = {
					meta = { name = "Faraway", realm = "Earthshaker",
						classFile = "MAGE", level = 12 },
				}

				local awayKey = Family.Wide:BorrowedKey(id, "Faraway-Earthshaker")
				local here, away
				for _, member in ipairs(Family.UI:EveryMember()) do
					if member.key == guestKey then here = member.group end
					if member.key == awayKey then away = member.group end
				end

				check("two realms from one family are two headings, not one",
					here ~= nil and away ~= nil and here ~= away,
					tostring(here) .. " / " .. tostring(away))
				check("and each heading names its own realm",
					(away or ""):find("Earthshaker", 1, true) ~= nil
						and (away or ""):find("Fire Maw", 1, true) == nil)

				link.members["Faraway-Earthshaker"] = nil
			end
			check("and the filtered lists keep them where they qualify",
				offered(Family.UI:EveryMember(function(meta)
					return meta.skills and next(meta.skills) and true or false
				end)) ~= nil)
			check("and their records read back through the window's reader",
				(Family.UI:Payload(guestKey) or {}).equipment ~= nil)

			Family.UI:ShowTab("wide")
		end

		Family.Wide:Store().requests["some-other-family"] = {
			from = "Asker", name = "Asker's lot", at = time() - 60, version = "1.0.0",
		}
		Family.UI:ShowTab("wide")

		check("somebody asking is shown", visibleText("Waiting for you to answer")
			and visibleText("Asker"))

		local accept = findButton("Accept")
		check("with a button to accept it", accept ~= nil)
		check("and a click actually reaches that button",
			accept ~= nil and reachable(accept),
			accept and tostring(coveredBy(accept) ~= nil and "a row covers it") or "missing")

		if accept then fireClick(accept) end
		check("so clicking it makes the link",
			Family.Wide:Links()["some-other-family"] ~= nil)
		check("and the request is no longer waiting for an answer",
			Family.Wide:Store().requests["some-other-family"] == nil)

		Family.Wide:Unlink("some-other-family")

		-- The same question of every other button and tick box the panel puts on a row,
		-- rather than only of the one this was found on.
		do
			local unreachable
			for _, f in ipairs(frames) do
				if f.__shown == true and clickable(f) and coveredBy(f) then
					unreachable = f.__text or f.__template or "an unnamed widget"
				end
			end
			check("nothing anywhere is drawn on a row that would eat its click",
				unreachable == nil, tostring(unreachable))
		end
	end)

	Family.Comm:Abandon()
	sent = {}
end
end)()

--------------------------------------------------------------------------------------------
-- The icon contact sheet
--
-- A development tool rather than part of Family, and it ships in no release - but it is
-- copied to a Windows machine and looked at in three clients, which is an expensive place to
-- discover that a panel throws while building. What can be checked here is checked here: it
-- builds, it draws the paths it lists, a click records a choice, and the choice reaches the
-- tab fit test.
--
-- What cannot be checked here is the entire point of the tool - whether a path exists. No
-- harness can answer that, which is why the tool exists at all.
--------------------------------------------------------------------------------------------

print()
print("the icon contact sheet")

;(function()
	local CONTROL = "Interface\\Icons\\Family_NoSuchIcon_Control"

	load("tools/FamilyIconSheet/IconSheet.lua", "FamilyIconSheet")
	fire("ADDON_LOADED", "FamilyIconSheet")

	local sheet = _G.FamilyIconSheet
	check("it builds a window of its own", sheet ~= nil)

	-- Shown by hand: the harness does not fire OnShow, and building on show is what keeps
	-- the sheet off the login path of a client that only has it installed to look at once.
	--
	-- **And actually shown**, not only its handler called. Every check below reads text off
	-- this window, and `visibleText` now asks whether a font string's whole parent chain is
	-- on screen - so a window whose own frame was never shown reads as blank however much
	-- it has drawn. Which is right: it was blank, and the checks were passing on text
	-- nobody could have seen.
	sheet:Show()
	sheet.__scripts.OnShow(sheet)

	check("with the control group first, so a miss can be recognised",
		visibleText("Control - what a miss looks like here"))
	check("and the two awkward ones each get a group of their own",
		visibleText("Abilities & Talents") and visibleText("Reputations"))

	local function drawn(path)
		for _, f in ipairs(fontStrings) do
			if f.__texture == path then return true end
		end
		return false
	end

	check("every candidate is actually drawn, including the deliberately wrong one",
		drawn(CONTROL) and drawn("Interface\\Icons\\INV_Misc_GroupLooking")
			and drawn("Interface\\Minimap\\Tracking\\Profession"))
	check("at both sizes: the one that judges the art and the one a tab really uses",
		(function()
			local count = 0
			for _, f in ipairs(fontStrings) do
				if f.__texture == CONTROL then count = count + 1 end
			end
			return count >= 2
		end)())

	local function cellFor(path)
		for _, f in ipairs(frames) do
			if rawget(f, "path") == path then return f end
		end
	end

	local summaryIcon = "Interface\\Icons\\INV_Misc_GroupLooking"
	local cell = cellFor(summaryIcon)
	check("a candidate's cell can be found and clicked", cell ~= nil)

	fireClick(cell)
	check("clicking one chooses it", FamilyIconSheetDB.chosen[summaryIcon] == true)

	-- The fit test is the one part of the icon question a client can answer exactly, so it
	-- is the one part this harness can hold to account.
	--
	-- Found by the verdict line beside it, which only these have. Matching on an icon and
	-- the label "Summary" also matches the window's own Summary tab, now that the real strip
	-- has pictures on it too - and which of the two was found would then depend on the order
	-- this file happens to load things in.
	local fitButton
	for _, f in ipairs(frames) do
		if rawget(f, "verdict") and f.__text == "Summary" then fitButton = f end
	end
	check("the choice reaches the tab fit test", fitButton ~= nil
		and fitButton.icon.__texture == summaryIcon)
	check("which measures every label against the room an icon leaves it",
		visibleText("of 134 px"))

	fireClick(cell)
	check("and clicking again unchooses it", FamilyIconSheetDB.chosen[summaryIcon] == nil)

	local backing = buttonLabelled("Backing:")
	check("the backing colour is named on its own button", backing ~= nil
		and backing.__text == "Backing: magenta")
	fireClick(backing)
	check("and cycles, because transparent art has to be judged against dark and light",
		backing.__text == "Backing: black")

	check("printing the choices does not depend on anything being chosen",
		pcall(SlashCmdList["FAMILYICONSHEET"], "print"))

	sheet:Hide()
end)()

--------------------------------------------------------------------------------------------
-- Mail written down as it is posted (§5)
--
-- The one place Family knows something about a mailbox that is not open. What has to hold is
-- that it is written against the *recipient*, that it is written on the server's confirmation
-- rather than on the button, and that the recipient's own mailbox wins the moment they look.
--------------------------------------------------------------------------------------------

print()
print("mail posted to another member")

;(function()
	local recipient = "Novice-FireMaw"
	Family.Database:SetMeta(recipient, { name = "Novice", realm = "Fire Maw" })

	SendMail("Novice", "Here you go", "some words")
	check("nothing is recorded until the server says the send worked",
		(Family.Database:Meta(recipient) or {}).mailInPost == nil)

	fire("MAIL_SEND_SUCCESS")

	local meta = Family.Database:Meta(recipient) or {}
	check("and then it is, against the member it was sent to", (meta.mailInPost or 0) == 1)

	local mail = (Family.Database:Payload(recipient) or {}).mail
	local letter = mail and mail.letters and mail.letters[1]

	check("with the money that was attached to it", letter and letter.money == 12000)
	check("and the attachments, by id rather than by name",
		letter and #letter.attachments == 2 and letter.attachments[1].id == 2589)
	check("marked as in the post, because nobody has seen it in a mailbox",
		letter and letter.inPost == true)
	check("and carrying the date it would be sent back on",
		-- Against the clock the addon is on, not the one outside the window. This read
		-- the real clock, and the two are different: the harness freezes `time` at
		-- 1786000000, the letter is dated thirty days after that, and the check therefore
		-- held until 2026-09-05 07:06:40 and not one minute longer. It went red four
		-- minutes later, on a day nothing had changed (L-045).
		letter and letter.expiresBy and letter.expiresBy > time())

	-- Somebody who is not one of ours. Nothing is written down about them anywhere, and in
	-- particular no member is invented out of an addressed envelope.
	SendMail("Stranger", "Hello", "some words")
	fire("MAIL_SEND_SUCCESS")
	check("mail to somebody who is not a member records nothing at all",
		Family.Database:Meta("Stranger-FireMaw") == nil)

	-- And the truth wins as soon as there is one.
	local playing = Family.currentMember
	Family.currentMember = recipient
	Family.Mail:Scan()
	Family.currentMember = playing

	check("the recipient's own mailbox replaces the guess when they open it",
		(Family.Database:Meta(recipient) or {}).mailInPost == nil)
end)()

--------------------------------------------------------------------------------------------
-- Siblings (§6)
--
-- Somebody else's members, chosen from what they have already shared, sitting in our own
-- summary under their family's name. Nothing here may send a message: the consent that
-- matters was given before the name could appear in the list at all.
--------------------------------------------------------------------------------------------

print()
print("siblings")

;(function()
	local sent = 0
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function() sent = sent + 1; return true end,
	}

	local wide = Family.Wide:Store()
	wide.links["fam-far"] = {
		name = "Faraway",
		grants = {},
		siblings = {},
		members = {
			["Faraway-Auberdine"] = {
				meta = { name = "Faraway", realm = "Auberdine", classFile = "WARRIOR",
					level = 70, faction = "Horde", itemLevel = 91.5 },
				payload = { equipment = { itemLevel = 91.5, counted = 1,
					worn = { [1] = { id = 6948, itemLevel = 25 } } } },
				seen = time(),
			},
		},
	}

	check("a member nobody shares cannot be made a sibling",
		Family.Wide:SetSibling("fam-far", "Nobody-Anywhere", true) == false)

	sent = 0
	check("one they do share can be", Family.Wide:SetSibling("fam-far",
		"Faraway-Auberdine", true) == true)
	check("and naming one sends nothing whatever", sent == 0)

	local siblings = Family.Wide:Siblings()
	check("which puts them in the sibling list", #siblings == 1)
	check("under a key that cannot collide with one of ours",
		siblings[1] and siblings[1].key == "@fam-far/Faraway-Auberdine")
	check("saying whose they are", siblings[1] and siblings[1].familyName == "Faraway")

	-- The whole point of the borrowed key: a panel reads a sibling exactly as it reads one
	-- of our own, and never learns that the record lives somewhere different.
	local borrowedKey = siblings[1] and siblings[1].key
	check("and a panel can read them by that key alone",
		(Family.UI:Meta(borrowedKey) or {}).name == "Faraway")
	check("their payload included", (Family.UI:Payload(borrowedKey) or {}).equipment ~= nil)
	check("while our own members still read the way they always did",
		(Family.UI:Meta(Family:CurrentMember()) or {}).name == "Tester")

	Family.UI:ShowTab("summary")
	check("the summary gives them a realm of their own when we have nobody there",
		visibleText("Auberdine"))
	check("under the family they belong to", visibleText("Faraway"))

	-- Right-clicking one must not offer to delete somebody who is not ours to delete.
	local siblingRow
	for _, f in ipairs(frames) do
		if f.__shown == true and f.memberKey == borrowedKey then siblingRow = f end
	end
	check("and the summary row knows it is borrowed",
		siblingRow ~= nil and siblingRow.borrowed == true)

	Family.Wide:SetSibling("fam-far", "Faraway-Auberdine", false)
	check("unticking takes them off again", #Family.Wide:Siblings() == 0)
end)()

--------------------------------------------------------------------------------------------
-- Everyone's gear at once (§4.3.1)
--------------------------------------------------------------------------------------------

print()
print("the whole family's gear on one screen")

;(function()
	-- A button's label lives on the button, not in a font string, so this asks the frames
	-- rather than the text: visibleText would never find one and would never say why.
	-- `onScreen` rather than the frame's own flag, for the reason L-046 gives: a button on a
	-- panel that is not open still reports itself shown, so this answered for whichever
	-- panel happened to have a control of that name. It went red the day the professions
	-- panel grew a realm picker of its own, on a check about the character panel.
	local function buttonSaying(label)
		for _, f in ipairs(frames) do
			if onScreen(f) and type(f.__text) == "string"
				and f.__text:find(label, 1, true) then
				return true
			end
		end
		return false
	end

	Family.UI:ShowTab("character")
	-- Back to the section this is about: the checks above walked through the others, and
	-- the panel remembers which one it was left on.
	clickButton("Equipped gear")
	check("the gear section starts as one member's character sheet",
		not buttonSaying("Realm: "))

	check("and there is a switch to the whole family", clickButton("Whole family"))
	check("which brings the two filters with it",
		buttonSaying("Realm: all") and buttonSaying("Class: all"))

	-- A row of the open list, which is a font string on a button rather than a button's own
	-- label, so clickButton cannot see it.
	local function chooseFromList(needle)
		for _, f in ipairs(frames) do
			local text = rawget(f, "text")
			if f.__shown == true and type(text) == "table"
				and type(text.__text) == "string"
				and text.__text:find(needle, 1, true)
				and f.__scripts.OnClick then
				fireClick(f)
				return true
			end
		end
		return false
	end

	-- A list, not a button that steps through the values. Stepping was unusable at eleven
	-- classes, and at the first realm called "Pyrewood Village" the name was written straight
	-- through the side of the button - a button's label has no width of its own.
	--
	-- What each list offers has to be what the family actually has rather than everything the
	-- game has: a family with no warlock must not be offered a warlock.
	check("clicking a filter opens its options",
		clickButton("Realm: all") and chooseFromList("Fire Maw"))
	check("and choosing one sets the filter to it", buttonSaying("Realm: Fire Maw"))

	-- On this panel, not on whichever panel built one of these first.
	--
	-- The summary grew a class filter of its own, and `clickButton` matches by label in
	-- creation order - so this check began driving the summary's copy and reading back the
	-- button it had itself just changed. It passed the whole time, and the panel it is
	-- written about stopped being covered. `onScreen` is the question that tells them apart.
	local function clickHere(label)
		for _, f in ipairs(frames) do
			if type(f.__text) == "string" and f.__text:find(label, 1, true)
				and clickable(f) and onScreen(f) then
				fireClick(f)
				return true
			end
		end
		return false
	end

	check("the classes are a list too",
		clickHere("Class: all") and chooseFromList("Mage"))
	check("named as the client names them",
		buttonSaying("Class: Mage") or buttonSaying("Class: MAGE"))

	-- Every list offers everything again, at the top, whatever is currently chosen.
	check("and everything is always back on offer",
		clickButton("Realm: Fire Maw") and chooseFromList("all|r"))
	check("which clears the filter", buttonSaying("Realm: all"))

	-- And the class with it, or every check below this one reads a grid narrowed to one
	-- class. This block never had to clear it before, because the click was landing on
	-- another panel's copy of the same control and this panel's filter was never set - which
	-- is the second thing that came out of fixing the click, and the more expensive one.
	clickHere("Class: Mage")
	chooseFromList("all|r")
	check("and the class filter clears the same way", not buttonSaying("Class: Mage"))

	-- Every row is a class picture and nineteen slots, so the pool has to have grown past
	-- what a single character sheet ever needs.
	local drawn = 0
	for _, f in ipairs(frames) do
		if f.__shown == true and rawget(f, "level") and rawget(f, "border") then
			drawn = drawn + 1
		end
	end
	-- Nineteen slots and the class picture in front of them, so one member alone is twenty.
	check("and the grid draws a class picture and every slot, per member", drawn >= 20,
		tostring(drawn))

	------------------------------------------------------------------------------------
	-- Which side each row is on
	--
	-- A row here is nineteen item pictures and nothing else. The side was recorded and it
	-- was shown, but only on the class picture's tooltip - so a family with one Horde
	-- character in it read as a family that had lost them, and was reported as one.
	------------------------------------------------------------------------------------

	do
		-- Set here rather than borrowed from whatever the checks above left behind: which
		-- members survived them, and on which side, is not what this is about.
		local keys = {}
		for key in pairs(Family.Database:Members()) do keys[#keys + 1] = key end
		table.sort(keys)

		check("there are two members to put on opposite sides", #keys >= 2, tostring(#keys))

		-- Redrawn by working the panel rather than by asking for a refresh. Character.lua
		-- is deliberately loaded twice further up, to get a client with achievements in
		-- front of the achievements branch, and that leaves two panels answering to
		-- "character": UI:Refresh goes to the one the window calls current and clickButton
		-- drives the other. Asked for a refresh, the records changed, the refresh went to
		-- the other instance, and the grid on screen stayed exactly as it was - with a
		-- status line still saying "3 of 3 members", which is what made it look like a
		-- drawing fault (L-011). Two clicks leave the mode where they found it and draw it
		-- twice on the way.
		local function redraw()
			clickButton("Whole family")
			clickButton("Whole family")
		end

		-- Asked of this panel's own rows rather than of everything on screen. A hidden
		-- panel's rows are not themselves hidden in this harness - the panel over them is -
		-- so a plain visibleText finds the summary's Horde heading from three tabs away and
		-- passes whatever this panel draws. A row here is the one with three text columns;
		-- the summary builds its rows out of cells instead.
		local function gearRowSaying(needle)
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if parent and parent.__shown == true and rawget(parent, "left")
					and rawget(parent, "middle") and rawget(parent, "right")
					and type(f.__text) == "string"
					and f.__text:find(needle, 1, true) then
					return true
				end
			end
			return false
		end

		if #keys >= 2 then
			local was = {}
			for _, key in ipairs(keys) do
				was[key] = Family.Database:Meta(key).faction or Family.CLEAR
			end

			-- The class filter is still on Mage from the checks above, and a family
			-- filtered down to one class is a family with one side on it - which is the
			-- answer this check is looking for and would have got for the wrong reason.
			if not buttonSaying("Class: all") then
				clickButton("Class: ")
				chooseFromList("all|r")
			end

			Family.Database:SetMeta(keys[1], { faction = "Alliance" })
			for index = 2, #keys do
				Family.Database:SetMeta(keys[index], { faction = "Horde" })
			end
			redraw()

			check("a family on both sides is split into them here too",
				gearRowSaying("Alliance") and gearRowSaying("Horde"))

			-- And where there is nothing to divide, nothing is drawn: a heading over
			-- every row of the panel says only what the panel already said.
			for _, key in ipairs(keys) do
				Family.Database:SetMeta(key, { faction = "Alliance" })
			end
			redraw()

			check("and a family all on one side gets no headings at all",
				not gearRowSaying("Horde") and not gearRowSaying("Alliance"))

			for _, key in ipairs(keys) do
				Family.Database:SetMeta(key, { faction = was[key] })
			end
			redraw()
		end
	end

	------------------------------------------------------------------------------------
	-- Somebody else's, on the one screen where whose they are cannot be seen
	--
	-- Every other panel says whose a member is somewhere - a name, a heading, a colour.
	-- This one is nineteen item pictures in a row, and the only thing that distinguishes
	-- one family from another on it is the heading over the block. So a member of another
	-- family drawn in with our own here is not a cosmetic fault: there is nothing else on
	-- the row to correct it.
	--
	-- Which is what happened. This grid asks for our own members; the call it used to ask
	-- with was quietly widened to mean everyone shared with us as well, and a linked
	-- family's character went into the group that has no heading.
	------------------------------------------------------------------------------------

	do
		local before = FamilyDB.wide

		-- With the filters cleared, or this proves nothing: the class filter is still set
		-- to Mage from the check above, and a member left out by a filter looks exactly
		-- like a member left out for being somebody else's.
		-- Put the panel where this is about, every time, and say so rather than assume
		-- it. Two things had to be learned here the hard way: the checks above leave the
		-- panel on whatever section they finished with, and UI:Refresh only refreshes the
		-- tab that is current - so a first version of this changed the shared records,
		-- asked for a refresh that went to another panel, and counted the same sixty
		-- stale pictures twice. In this harness a grid that is not being drawn keeps its
		-- last rows showing, which is what made "no change" look like an answer.
		local function drawTheGrid()
			Family.UI:ShowTab("character")
			clickButton("Equipped gear")
			if not buttonSaying("Realm: ") then clickButton("Whole family") end
			if not buttonSaying("Class: all") then
				clickButton("Class: ")
				chooseFromList("all|r")
			end
			if not buttonSaying("Realm: all") then
				clickButton("Realm: ")
				chooseFromList("all|r")
			end
		end

		local function cellsDrawn()
			local drawn = 0
			for _, f in ipairs(frames) do
				if f.__shown == true and rawget(f, "level") and rawget(f, "border") then
					drawn = drawn + 1
				end
			end
			return drawn
		end

		FamilyDB.wide = {
			-- Switched on, because the feature ships switched off until a real server
			-- has seen it and everything under it answers nothing while it is off.
			enabled = true,
			id = "us", links = { ["them"] = { name = "Ardent", members = {
				["Visitor-FireMaw"] = {
					meta = { name = "Visitor", realm = "Fire Maw",
						classFile = "WARLOCK", level = 70 },
					payload = { equipment = { itemLevel = 100, counted = 17 } },
					seen = time(),
				},
			} } },
			requests = {}, pendingOut = {},
		}

		drawTheGrid()
		check("the whole-family grid is the thing being looked at, unfiltered",
			buttonSaying("Realm: all") and buttonSaying("Class: all"))

		-- Exactly our own and nobody else, counted rather than looked for.
		--
		-- Looking for the family's name is not enough and this was written the weak way
		-- first: the fault draws the shared member with no heading at all, so a check that
		-- asks whether the heading is absent passes precisely when the fault is present.
		-- The number is the only thing that tells the two apart.
		-- Nineteen slots and the class picture in front of them, which is the number the
		-- check above this section already states. Written down rather than derived from
		-- the panel, so that the panel quietly drawing a different number of slots is a
		-- failure here rather than something this silently agrees with.
		local perMember = 20
		local ourOwn = cellsDrawn()
		check("only our own are in the family grid until somebody is made a sibling",
			ourOwn == #Family.UI:OurMembers() * perMember,
			ourOwn .. " pictures for " .. #Family.UI:OurMembers() .. " members")
		check("and no other family is named over them",
			visibleText("Ardent") == false)

		Family.Wide:SetSibling("them", "Visitor-FireMaw", true)
		drawTheGrid()

		check("and once they are a sibling they are drawn, exactly once",
			cellsDrawn() == ourOwn + perMember,
			cellsDrawn() .. " against " .. (ourOwn + perMember))
		check("under the name of the family they belong to, not in with our own",
			visibleText("Ardent"))

		FamilyDB.wide = before
		Family.UI:Refresh()
	end

	clickButton("Whole family")
	check("switching back leaves the character sheet as it was",
		not buttonSaying("Realm: Fire Maw"))
end)()

--------------------------------------------------------------------------------------------
-- Guild share (§7)
--
-- Announce on the guild channel; everything with any size in it whispered to the one person
-- who asked. On by default, and one switch that stops it asking and answering at once.
--------------------------------------------------------------------------------------------

print()
print("guild share")

;(function()
	local sent = {}
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, text, channel, target)
			sent[#sent + 1] = { text = text, channel = channel, target = target }
			return true
		end,
	}

	local function deliver(from)
		local queue = sent
		sent = {}
		for _, message in ipairs(queue) do
			Family.Comm:Receive(message.text, from, message.channel)
		end
		return #queue
	end

	-- The two saved files, swapped to make this client "them". The same trick the Wide
	-- Family section uses, and for the same reason: a protocol tested against itself in one
	-- database proves only that a table survives being written and read.
	local ours, theirs = FamilyDB.guild, { enabled = true }

	local function wearing(which, fn)
		local before = FamilyDB.guild
		FamilyDB.guild = which
		local ok, err = pcall(fn)
		which = FamilyDB.guild
		FamilyDB.guild = before
		if not ok then error(err, 0) end
		return which
	end

	-- Off in a database nobody has touched, like Wide Family. Everything guild share carries
	-- is what Inspect already gives away, so this is not a consent gate - it is a first
	-- release not starting conversations on somebody's behalf before they have asked.
	check("it is off in a database nobody has touched", Family.Guild:Enabled() == false)
	check("and the panel is there anyway, with the switch on it",
		Family.UI:HasTab("guild"))

	-- Everything below is about the protocol, which needs it on.
	-- Neither sharing panel carries its own switch any more: both are in Options, together,
	-- so a player looks in one place. What a panel carries while its feature is off is an
	-- explanation of why nothing on it is filling in.
	Family.UI:Show()
	Family.UI:ShowTab("guild")
	check("and the panel points at the switch rather than looking empty",
		visibleText("nothing here will fill in"))

	-- A panel's first draw happens before the client has measured its scroll frame, so
	-- GetWidth answers nought. Falling back to 200 was the guild row's undoing: it anchors
	-- its middle column at x=244 and its right column to the right-hand edge, so at 200 all
	-- three of its texts landed on top of one another - and closing and reopening the window
	-- "fixed" it, having only given the second draw a measurement the first was refused.
	check("a list asked for its width before the client has measured anything gets a real one",
		Family.UI:ListWidth({ GetWidth = function() return 0 end }) > 400,
		tostring(Family.UI:ListWidth({ GetWidth = function() return 0 end })))
	check("and gets the measurement itself once there is one",
		Family.UI:ListWidth({ GetWidth = function() return 903 end }) == 903)
	check("and survives being handed nothing at all",
		Family.UI:ListWidth(nil) > 400)

	-- And the rule, rather than one more panel that happens to obey it. A width taken
	-- straight from a scroll frame is a width taken before the client has measured it, which
	-- on a first draw is nought - so every panel asks UI:ListWidth, and only Window.lua,
	-- where that function lives, may touch the scroll frame itself.
	--
	-- Read out of the sources rather than reasoned about, and over the same list the addon
	-- loads, so a panel added later is examined without anybody remembering to add it.
	do
		local offenders = {}
		for _, file in ipairs(UI_FILES) do
			if file ~= "Window.lua" then
				local handle = io.open(ROOT .. "/addons/Family_UI/" .. file)
				if handle then
					local number = 0
					for line in handle:lines() do
						number = number + 1
						if line:find("SetWidth%(") and line:find("scroll:GetWidth%(%)") then
							offenders[#offenders + 1] = file .. ":" .. number
						end
					end
					handle:close()
				end
			end
		end
		check("no panel sizes anything from a scroll frame the client has not measured",
			#offenders == 0, table.concat(offenders, ", "))
	end

	-- The same shape of rule for the same shape of fault. A frame built on the bordered
	-- template floats over a panel and the template draws no back to it, so whatever is
	-- underneath reads through. Two pickers were built that way and only one of them had been
	-- noticed; the other was found by somebody opening it and reading two words at once.
	--
	-- Matched on the quoted template name, so that writing about it in a comment - which the
	-- file defining UI:PaintOpaque does - is not mistaken for building one.
	do
		local bare = {}
		for _, file in ipairs(UI_FILES) do
			local handle = io.open(ROOT .. "/addons/Family_UI/" .. file)
			if handle then
				local text = handle:read("*a")
				handle:close()
				if text:find('"TooltipBorderedFrameTemplate"', 1, true)
					and not text:find("UI:PaintOpaque(", 1, true) then
					bare[#bare + 1] = file
				end
			end
		end
		check("every frame that floats over a panel is given something solid behind it",
			#bare == 0, table.concat(bare, ", "))
	end

	-- And its buttons are greyed, because neither can do anything: there is no roster to
	-- filter and nothing to ask a guild nobody is speaking to. A live-looking button that
	-- answers nothing is worse than one that says it is not available.
	check("and its buttons are greyed while it is off",
		_G.FamilyGuildUpdate and _G.FamilyGuildUpdate.__enabled == false
			and _G.FamilyGuildWho and _G.FamilyGuildWho.__enabled == false,
		tostring(_G.FamilyGuildUpdate and _G.FamilyGuildUpdate.__enabled))

	Family.Guild:SetEnabled(true)
	check("and it can be switched on", Family.Guild:Enabled() == true)

	-- Switching it on announces two seconds later, and that is its own check further down.
	-- This section measures how an announcement is *answered*, so a second one arriving inside
	-- the same window would be counted as an answer that told the whole guild. The pending
	-- timer is replaced with nothing rather than drained by moving the clock: everything below
	-- turns on what each side does and does not know *yet*, and time passing changes that.
	Family:After(0.01, "guild.enabled", function() end)

	Family.UI:Refresh()
	check("and its buttons come back with it",
		_G.FamilyGuildUpdate and _G.FamilyGuildUpdate.__enabled ~= false)

	local guildKey, guildName = Family.Guild:Current()
	check("it knows which guild on which realm", guildKey == "Late Night Raiders-Fire Maw",
		tostring(guildKey))

	Family.Database:SetMeta(Family:CurrentMember(),
		{ guild = guildName, realm = "Fire Maw" })
	Family.Database:SetPayload(Family:CurrentMember(), {
		bags = { [0] = { size = 16, free = 14 } },
		equipment = { itemLevel = 70.5, counted = 17, worn = { [1] = { id = 6948 } } },
		talents = { activeGroup = 1, groupCount = 2, system = "trees", groups = {} },
	})

	local offering = Family.Guild:Offering()
	local mine = offering and offering[Family:CurrentMember()]
	check("and what it would send is our own characters in that guild", mine ~= nil)
	check("carrying gear and talents", mine and mine.equipment ~= nil
		and mine.talents ~= nil)
	check("and nothing else - not bags, not mail, not money",
		mine and mine.bags == nil and mine.mail == nil and mine.meta.money == nil)

	-- Announcing. One small message, to the guild, and nothing whispered to anybody.
	sent = {}
	Family.Guild:Announce("a check")
	check("announcing goes to the guild channel and nowhere else",
		#sent > 0 and sent[1].channel == "GUILD" and sent[1].target == nil)

	-- Their client hears it, and answers with everything it has - by whisper, because the
	-- guild channel is shared with every other addon in the guild.
	local answered = {}
	theirs = wearing(theirs, function()
		-- Their client is somebody else's, so it is somebody else at the keyboard: the
		-- echo guard drops an announcement that came from the character being played, and
		-- without this the whole exchange would be this client ignoring itself.
		local realUnitName = UnitName
		UnitName = function() return "Faraway" end

		Family.Database:SetMeta("Faraway-FireMaw", { name = "Faraway", realm = "Fire Maw",
			guild = guildName, classFile = "WARRIOR", level = 70, itemLevel = 91.5 })
		Family.Database:SetPayload("Faraway-FireMaw", {
			equipment = { itemLevel = 91.5, counted = 1,
				worn = { [1] = { id = 6948, itemLevel = 25 } } },
			talents = { activeGroup = 1, groupCount = 2, system = "trees", groups = {
				{ system = "trees", tabs = { { points = 31 }, { points = 20 },
					{ points = 0 } } },
				{ system = "trees", tabs = { { points = 0 }, { points = 0 },
					{ points = 51 } } },
			} },
		})

		deliver("Tester")
		check("hearing an announcement marks that client as running Family",
			Family.Guild:RunsFamily(guildKey, "Tester"))

		-- Answering is deferred by a few seconds so a guild logging in together does not
		-- put every one of its clients on the channel in the same instant.
		advance(9)

		for _, message in ipairs(sent) do answered[#answered + 1] = message end
		sent = {}

		UnitName = realUnitName
	end)

	local whispered, broadcast = 0, 0
	for _, message in ipairs(answered) do
		if message.channel == "WHISPER" then whispered = whispered + 1 end
		if message.channel == "GUILD" then broadcast = broadcast + 1 end
	end
	check("and answering it whispers back rather than telling the whole guild",
		whispered > 0 and broadcast == 0, tostring(whispered) .. " / " .. tostring(broadcast))

	-- Back on our side, what they sent is filed under them.
	sent = answered
	deliver("Faraway")

	-- Filed under whoever sent it rather than under the character it is about, which is the
	-- only thing that says two characters are one person: their alts are not named after
	-- them, and one client sending both is the whole of the evidence.
	local known = Family.Guild:CharactersOf(guildKey, "Faraway")
	check("every character that client has in the guild arrives together", #known == 2,
		tostring(#known))

	local theirMain
	for _, entry in ipairs(known) do
		if entry.key == "Faraway-FireMaw" then theirMain = entry end
	end

	check("filed under the player who sent it, not the one it is about", theirMain ~= nil)
	check("with their gear", theirMain and theirMain.equipment
		and theirMain.equipment.itemLevel == 91.5)
	check("and both specialisations", theirMain and theirMain.talents
		and theirMain.talents.groupCount == 2)
	check("and nothing that was never in the offer",
		theirMain and theirMain.bags == nil and theirMain.meta.money == nil)

	Family.Database:Forget("Faraway-FireMaw")

	-- Hearing from somebody we already have
	--
	-- Reported from a live guild: nine guildmates listed as running Family and a tenth, who
	-- certainly was, listed as not. Being heard from is the only way anybody knows anybody
	-- runs this (§7), and the traffic control skipped the whole exchange when what we held
	-- from somebody was recent - so a player whose saved variables had been cleared announced
	-- to a guild full of clients that each decided, in silence, that they had nothing to say.
	--
	-- What we hold from them says nothing about what they hold from us, and that was the
	-- assumption underneath the silence.
	do
		-- Anything already on a timer, out of the way first: an announcement scheduled by
		-- an earlier check is not what this one is measuring.
		advance(9)
		sent = {}

		local function helloFrom(who, reply)
			sent = {}
			Family.Comm:Send("ghello", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = who .. "-FireMaw", reply = reply or nil,
			}, "GUILD", nil)
			deliver(who)
		end

		-- Their announcement, arriving while what we hold from them is a moment old.
		helloFrom("Faraway")
		sent = {}
		advance(9)

		local whispers = 0
		for _, message in ipairs(sent) do
			if message.channel == "WHISPER" and message.target == "Faraway" then
				whispers = whispers + 1
			end
		end
		check("a hello from somebody we already hold is answered rather than ignored",
			whispers > 0, "nothing went back to them")
		-- One message. Everything we have is eleven, which is what the skip exists to
		-- avoid and what this must not quietly become.
		check("and answered by one whisper rather than by sending everything again",
			whispers == 1, tostring(whispers) .. " whispers")

		local ourReply = {}
		for _, message in ipairs(sent) do ourReply[#ourReply + 1] = message end

		-- Their side of it: the reply is what tells them we are here, and it must not be
		-- answered - two clients that both hold recent data would say hello for ever.
		sent = {}
		advance(9)

		theirs = wearing(theirs, function()
			local realUnitName = UnitName
			UnitName = function() return "Faraway" end

			-- A client that has never heard of us in this guild, which is exactly the
			-- state a cleared or reinstalled database is in on the other end.
			FamilyDB.guild.users = {}
			check("before it arrives, that client does not know we run Family",
				Family.Guild:RunsFamily(guildKey, "Tester") == false)

			sent = ourReply
			deliver("Tester")
			check("and hearing the reply is what tells it",
				Family.Guild:RunsFamily(guildKey, "Tester"))

			-- A hello and nothing else. If the skip ever turns back into a full send this
			-- is where it shows, because their store would have our characters in it.
			check("and it carries a hello and not the characters the skip was avoiding",
				#Family.Guild:CharactersOf(guildKey, "Tester") == 0,
				tostring(#Family.Guild:CharactersOf(guildKey, "Tester")) .. " arrived")

			sent = {}
			advance(9)
			check("but a reply is never answered with another one", #sent == 0,
				tostring(#sent) .. " message(s) went back")

			UnitName = realUnitName
		end)
	end

	-- The panel.
	tabDrawsCleanly("guild", "the guild panel builds and draws")
	check("it names the guild", visibleText("Late Night Raiders"))
	check("and says who is not running Family rather than leaving them blank",
		visibleText("not running Family"))
	check("the roster can be shown in full as well as online only",
		clickButton("Online only") and visibleText("offline"))

	-- Only the guildmates this panel can exchange anything with (backlog entry 14).
	--
	-- Asked for from play: a large guild is a long list and most of it can never answer. The
	-- panel already knew who they are - it draws a filled dot against each and counts them in
	-- the status line - so this is a switch and not a new fact.
	--
	-- Who runs it is **stated here rather than inherited**. By this point in the file the
	-- player is Faraway and nothing has been heard from anybody, which is a history this
	-- block has no business depending on: the first draft asserted that Tester runs Family
	-- because an earlier block had made that true, and it was not true any more.
	do
		local heldRuns = Family.Guild.RunsFamily
		Family.Guild.RunsFamily = function(_, _, name) return name == "Tester" end

		local function drawn()
			local names = {}
			for _, f in ipairs(frames) do
				local text = type(f.text) == "table" and f.text.__text
				if onScreen(f) and f.dot and type(text) == "string" then
					names[#names + 1] = text
				end
			end
			return table.concat(names, " | ")
		end

		local function names(needle)
			return drawn():find(needle, 1, true) ~= nil
		end

		Family.UI:Refresh()
		check("with the filter off, one who runs Family is on the roster",
			names("Tester"), drawn())
		check("and one who does not", names("Absent"), drawn())
		check("and our own", names("Faraway"), drawn())

		check("the panel offers a filter for the people running it",
			_G.FamilyGuildUsers ~= nil)

		if _G.FamilyGuildUsers then
			fireClick(_G.FamilyGuildUsers)

			check("switching it on drops the ones who cannot answer",
				names("Absent") == false, drawn())
			check("and keeps the ones who can", names("Tester"), drawn())

			-- **Our own rows survive it**, and this is why the check exists rather than
			-- being taken as read. `RunsFamily` answers on what has been *heard*, and
			-- nothing is ever heard from our own characters - the panel's own counting
			-- treats the two apart for exactly that reason. A filter that only asked
			-- `RunsFamily` would hide the player's own row from a list of the people
			-- running Family, which is the one row they can be certain about.
			Family.Guild.RunsFamily = function() return false end
			Family.UI:Refresh()

			check("our own character is kept when nothing has been heard from anybody",
				names("Faraway"), drawn())
			check("while a guildmate nothing has been heard from is dropped",
				names("Tester") == false, drawn())

			-- Off again, because the switch is a toggle and this panel is measured below
			-- by checks that expect the whole roster.
			Family.Guild.RunsFamily = heldRuns
			fireClick(_G.FamilyGuildUsers)
			Family.UI:Refresh()
			check("and switching it off puts everybody back", names("Absent"), drawn())
		end

		Family.Guild.RunsFamily = heldRuns
		Family.UI:Refresh()
	end

	-- The diagnosis has to survive being asked in every state, because the state it will
	-- actually be asked in is the broken one.
	check("the diagnosis runs", pcall(Family.Guild.Diagnose, Family.Guild))

	-- And it names the one state nobody can diagnose from outside.
	--
	-- A character on the guild roster whose own record does not place them in this guild is
	-- absent from the offering and reads as "not running Family" on every roster, while
	-- looking perfectly ordinary on every other panel in Family. From the player's chair
	-- that is indistinguishable from the addon being broken; from in here it is one line.
	do
		local held = Family.Database:Meta(Family:CurrentMember()).guild

		-- Recorded under a different guild, which is what a character last played before
		-- they joined this one looks like, and one of the three reasons the offering can
		-- leave somebody out.
		Family.Database:SetMeta("Wanderer-FireMaw", { name = "Wanderer", realm = "Fire Maw",
			level = 44, guild = "Some Other Guild" })

		local mark = #DEFAULT_CHAT_FRAME.messages
		Family.Guild:Diagnose()

		local named = false
		for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
			local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
			if message:find("recorded in another guild", 1, true)
				and message:find("Wanderer (Some Other Guild)", 1, true) then
				named = true
			end
		end
		check("and it names one of ours recorded under a different guild, with the guild",
			named)

		-- On this realm, in this guild by name, and left out anyway - which on connected
		-- realms happens to characters who are genuinely in it.
		Family.Database:SetMeta("Wanderer-FireMaw",
			{ guild = guildName, realm = "Somewhere Else" })

		mark = #DEFAULT_CHAT_FRAME.messages
		Family.Guild:Diagnose()

		local realmed = false
		for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
			local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
			if message:find("recorded on another realm", 1, true)
				and message:find("Wanderer (Somewhere Else)", 1, true) then
				realmed = true
			end
		end
		check("and one in this guild but recorded on another realm, with the realm", realmed)

		Family.Database:Forget("Wanderer-FireMaw")
		Family.Database:SetMeta(Family:CurrentMember(), { guild = held })

		-- And it names one the roster cannot be asked about.
		--
		-- The client lists offline guild members only when it has been told to, which is a
		-- setting the panel's Online only / Everyone button drives - so a version of this
		-- that went through the roster could not see an alt played this morning and offline
		-- now, which is exactly the character it was written for.
		Family.Database:SetMeta("Hermit-FireMaw", { name = "Hermit", realm = "Fire Maw",
			level = 30 })

		local mark2 = #DEFAULT_CHAT_FRAME.messages
		Family.Guild:Diagnose()

		-- Two of ours with the same name on different realms, which is ordinary and is what
		-- made this line unreadable: it printed the bare name, so the character standing in
		-- the guild looked as though it were on the list of those with no guild. An evening
		-- went into reading that as a fault in the scanner.
		Family.Database:SetMeta("Hermit-Somewhere", { name = "Hermit",
			realm = "Somewhere Else", level = 31 })

		local bothMark = #DEFAULT_CHAT_FRAME.messages
		Family.Guild:Diagnose()

		local apart = false
		for index = bothMark + 1, #DEFAULT_CHAT_FRAME.messages do
			local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
			if message:find("with no guild recorded", 1, true)
				and message:find("Hermit (Fire Maw)", 1, true)
				and message:find("Hermit (Somewhere Else)", 1, true) then
				apart = true
			end
		end
		check("and tells two of ours with one name on two realms apart", apart)

		Family.Database:Forget("Hermit-Somewhere")

		local listed = false
		for index = mark2 + 1, #DEFAULT_CHAT_FRAME.messages do
			local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
			if message:find("with no guild recorded", 1, true)
				and message:find("Hermit", 1, true) then
				listed = true
			end
		end
		check("and one with no guild at all, without going through the roster to find them",
			listed)

		-- What is shareable and what has arrived, both of which are invisible on the panel:
		-- a profession can be ticked and have nothing to send because its window has never
		-- been opened, and a list can be asked for and never turn up.
		do
			-- Something ticked, because the line only exists when there is something to
			-- say: a grid nobody has touched has nothing to report about.
			local mine = Family:CurrentMember()
			Family.Guild:SetShare(guildKey, mine, 164, true)

			local mark = #DEFAULT_CHAT_FRAME.messages
			Family.Guild:Diagnose()

			local ticked, held = false, false
			for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
				local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
				if message:find("professions ticked", 1, true) then ticked = true end
				if message:find("recipe lists held from the guild", 1, true) then
					held = true
				end
			end

			check("and says how many professions are ticked and how many can send a list",
				ticked)

			-- And how many of the recipes held carry the id of what they make, which is the
			-- half that answers on a crafted item. Lists that are all spell and no item look
			-- exactly like lists that never arrived, to anybody hovering the food.
			local counted = false
			for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
				if tostring(DEFAULT_CHAT_FRAME.messages[index])
					:find("with the id of what they make", 1, true) then
					counted = true
				end
			end
			check("and how many of what arrived says what it makes", counted)

			-- Named, not counted. "One of three has nothing to send" says something is
			-- missing and gives nobody a way to find out which window to open.
			local named = false
			for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
				local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
				if message:find("nothing to send for", 1, true)
					and message:find("Blacksmithing", 1, true) then
					named = true
				end
			end
			check("naming the ones with nothing to send, so the window can be found",
				named)
			check("and how many lists have come back", held)

			Family.Guild:SetShare(guildKey, mine, 164, false)
		end

		Family.Database:Forget("Hermit-FireMaw")
	end
	check("and counts what crossed the wire", Family.Guild.stats.sent > 0,
		tostring(Family.Guild.stats.sent))
	check("including announcements from somebody who is not us",
		Family.Guild.stats.answered > 0, tostring(Family.Guild.stats.answered))

	------------------------------------------------------------------------------------
	-- Shared professions, slice 1: ranks (§7.1)
	--
	-- The one thing §7 carries that Inspect does not give away for free, and therefore the
	-- one thing in it with a grid in front of it. Everything below is about that grid meaning
	-- what it says: nothing is offered until a box is ticked, unticking one takes it back out
	-- of what would be sent, and what crosses is an identifier rather than a word.
	------------------------------------------------------------------------------------

	do
		-- Rows on this panel and rows on every other one are the same kind of frame with the
		-- same kind of name written on them, and fontStrings holds every font string the
		-- harness has ever built. Scoped to the frame the grid's heading sits in, or the
		-- first "Faraway" of the whole run gets clicked and it belongs to somebody else.
		local function guildList()
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string"
					and f.__text:find("What you share with", 1, true)
					and parent and parent.__shown ~= false then
					return parent.__parent
				end
			end
			return nil
		end

		local function clickRow(needle)
			local within = guildList()
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string" and f.__text:find(needle, 1, true)
					and parent and within and parent.__parent == within
					and parent.__scripts and parent.__scripts.OnClick then
					parent.__scripts.OnClick(parent)
					return true
				end
			end
			return false
		end

		-- A tick box, found by the words written beside it.
		local function labelled(needle)
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string" and f.__text:find(needle, 1, true)
					and parent and parent.label == f and parent.__shown ~= false then
					return parent
				end
			end
			return nil
		end

		local smith = Family:SkillLineFor("Blacksmithing")
		local mining = Family:SkillLineFor("Mining")
		check("the skill line table knows the professions this section is written about",
			type(smith) == "number" and type(mining) == "number",
			tostring(smith) .. " / " .. tostring(mining))

		-- Characters of our own, made here rather than borrowed from the sections above, so
		-- that what this block asserts does not depend on which members survived them.
		Family.Database:SetMeta("Smith-FireMaw", { name = "Smith", realm = "Fire Maw",
			guild = guildName, classFile = "WARRIOR", level = 70, skills = {
				[smith] = { rank = 300, maxRank = 300, name = "Blacksmithing" },
				[mining] = { rank = 275, maxRank = 300, name = "Mining" },
				-- A profession from a client newer than the skill line table is filed
				-- under the word that client used, and a word is one language. It can
				-- never cross, and it is counted rather than dropped in silence.
				["Cheesemaking"] = { rank = 12, maxRank = 75, name = "Cheesemaking" },
			} })
		Family.Database:SetMeta("Backup-FireMaw", { name = "Backup", realm = "Fire Maw",
			guild = guildName, classFile = "MAGE", level = 60 })

		-- A member recorded by a version that had no skill line ids: every profession filed
		-- under the word the client used. Reported from a live client, where two characters
		-- were told they had no professions at all in the same breath as a line at the foot
		-- of the grid listing three of them by name.
		-- Tailoring rather than a gathering profession, and that is not incidental: the
		-- perimeter excludes the ones that make nothing, so a fixture built on Herbalism
		-- would prove that a word resolves to an id by watching it be refused for an
		-- entirely different reason.
		Family.Database:SetMeta("Oldtimer-FireMaw", { name = "Oldtimer", realm = "Fire Maw",
			guild = guildName, classFile = "DRUID", level = 60, skills = {
				["Tailoring"] = { rank = 300, maxRank = 300, name = "Tailoring" },
			} })

		-- And one whose only skill is a word no table has an id for - a rogue's poisons, on
		-- the client this was found on. That one genuinely cannot cross.
		Family.Database:SetMeta("Poisoner-FireMaw", { name = "Poisoner", realm = "Fire Maw",
			guild = guildName, classFile = "ROGUE", level = 60, skills = {
				["Cheesemaking"] = { rank = 12, maxRank = 75, name = "Cheesemaking" },
			} })

		-- The character being played is called Tester. It says so here because the block
		-- above borrowed this client's identity to play the other end of the wire, and a
		-- scan that ran while it was borrowed wrote the borrowed name onto our own record -
		-- which makes IsOurs answer yes about the guildmate this section is about, and
		-- CharactersOf then answers out of our own records instead of out of what arrived.
		Family.Database:SetMeta(Family:CurrentMember(), { name = "Tester" })

		check("a profession is not offered until it is ticked",
			Family.Guild:Shares(guildKey, "Smith-FireMaw", smith) == false)
		check("and nothing is written for a box nobody has touched",
			(FamilyDB.guild.grants or {})[guildKey] == nil)
		check("so what would be sent says nothing about professions",
			(Family.Guild:Offering() or {})["Smith-FireMaw"].professions == nil)

		Family.Guild:SetShare(guildKey, "Smith-FireMaw", smith, true)
		check("ticking one records it",
			Family.Guild:Shares(guildKey, "Smith-FireMaw", smith))
		check("and records only it",
			Family.Guild:Shares(guildKey, "Smith-FireMaw", mining) == false)

		local offered = (Family.Guild:Offering() or {})["Smith-FireMaw"].professions
		check("the ticked one crosses, with its rank and its ceiling",
			offered and #offered == 1 and offered[1].skillLine == smith
				and offered[1].rank == 300 and offered[1].maxRank == 300,
			offered and tostring(offered[1] and offered[1].skillLine) or "nothing")
		check("as an identifier and not as a word (§2.1)",
			offered and offered[1].name == nil)

		-- The grant is made to a guild. A character of ours who is not in it has nothing to
		-- offer it, whatever any grid ever said.
		Family.Database:SetMeta("Smith-FireMaw", { guild = "Somewhere Else" })
		check("a character who is not in this guild is not offered to it",
			(Family.Guild:Offering() or {})["Smith-FireMaw"] == nil)
		Family.Database:SetMeta("Smith-FireMaw", { guild = guildName })

		-- Prompt, because the half of an exchange that takes something away must not wait
		-- for somebody to press Update now.
		advance(10)
		sent = {}
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, true)
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, false)
		advance(10)

		local announced = 0
		for _, message in ipairs(sent) do
			if message.channel == "GUILD" then announced = announced + 1 end
		end
		check("changing the grid tells the guild rather than waiting to be asked",
			announced == 1, tostring(announced) .. " announcements")

		-- Once, however many boxes were ticked. A player working down a grid of eight
		-- professions is one decision to everybody else in the guild.
		advance(10)
		sent = {}
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, true)
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, false)
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, true)
		advance(10)

		announced = 0
		for _, message in ipairs(sent) do
			if message.channel == "GUILD" then announced = announced + 1 end
		end
		check("and tells it once however many boxes were ticked",
			announced == 1, tostring(announced) .. " announcements")

		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, false)

		-- Unticking. Nothing has to be sent to undo a grant - what is sent next simply no
		-- longer contains it - so this is the check that the next thing sent is right.
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", smith, false)
		check("unticking takes it back out of what would be sent",
			(Family.Guild:Offering() or {})["Smith-FireMaw"].professions == nil)
		check("and leaves nothing behind on disk",
			(FamilyDB.guild.grants or {})[guildKey] == nil)

		Family.Guild:SetShare(guildKey, "Smith-FireMaw", smith, true)

		------------------------------------------------------------------------------------
		-- Slice 2: the recipe list itself, and the fingerprint that keeps it affordable
		------------------------------------------------------------------------------------

		Family.Database:SetPayload("Smith-FireMaw", { professions = { [smith] = {
			rank = 300, maxRank = 300, recipesSeen = time(), recipes = {
				{ name = "Runed Copper Breastplate", spellID = 2667, itemID = 2864 },
				{ name = "Silver Rod", spellID = 3339, itemID = 6338 },
				{ name = "Runed Copper Rod", spellID = 7421 },
				-- The client gave no id for this one. It cannot cross - a name is one
				-- language and the whole point is that a French list answers a German
				-- search - so it is left out, and counted rather than quietly dropped.
				{ name = "Something The Client Would Not Name" },
			},
		} } })

		local spells, items, missing, fingerprint = Family.Guild:RecipesFor("Smith-FireMaw",
			smith)

		check("what one of ours can make is read back as identifiers",
			spells and #spells == 3, spells and tostring(#spells) or "nothing")
		check("sorted, because both ends fingerprint the order",
			spells and spells[1] == 2667 and spells[2] == 3339 and spells[3] == 7421)
		check("with what each one makes beside it, and nought where it makes nothing",
			items and items[1] == 2864 and items[2] == 6338 and items[3] == 0)
		check("and a recipe the client would not name is omitted and counted",
			missing == 1, tostring(missing))
		check("the fingerprint is a number both ends can compute", type(fingerprint) == "number")

		------------------------------------------------------------------------------------
		-- A client that names recipes by what they make, and not by the spell
		--
		-- `GetTradeSkillRecipeLink` returns nothing at all on Classic Era, so a character
		-- there holds a hundred and fifty leatherworking recipes with an item id on every one
		-- and a spell id on none (DATASOURCES §2, measured on 1.15.9). This wire asked for a
		-- spell and dropped everything without one, so on Era it shared nothing whatever -
		-- and the Craft frame on the same client is the mirror image, answering with an
		-- enchant id and no item, which is why enchanting was the one thing that did cross.
		------------------------------------------------------------------------------------

		do
			local held = Family.Database:Payload("Smith-FireMaw").professions[smith].recipes

			Family.Database:Payload("Smith-FireMaw").professions[smith].recipes = {
				{ name = "Renfort d'armure robuste", itemID = 15564 },
				{ name = "Renfort d'armure epais", itemID = 8173 },
				-- Neither id. It cannot cross under any name, and is counted.
				{ name = "Something The Client Would Not Name" },
			}

			local eraSpells, eraItems, eraMissing, eraPrint =
				Family.Guild:RecipesFor("Smith-FireMaw", smith)

			check("a recipe with an item id and no spell still crosses",
				eraSpells and #eraSpells == 2, eraSpells and tostring(#eraSpells) or "none")
			check("with nought where the client gave no spell",
				eraSpells and eraSpells[1] == 0 and eraSpells[2] == 0)
			check("and the item it makes beside it",
				eraItems and eraItems[1] == 8173 and eraItems[2] == 15564,
				eraItems and (tostring(eraItems[1]) .. "," .. tostring(eraItems[2])) or "none")
			check("and one the client would name in neither way is left out and counted",
				eraMissing == 1, tostring(eraMissing))

			-- The fingerprint has to tell two such lists apart, and a hash over the spells
			-- alone answers the same number for every list on that client - every spell in
			-- it being nought.
			Family.Database:Payload("Smith-FireMaw").professions[smith].recipes[1].itemID = 9999
			local moved = select(4, Family.Guild:RecipesFor("Smith-FireMaw", smith))
			check("and the fingerprint moves when only the item does", moved ~= eraPrint,
				tostring(eraPrint) .. " / " .. tostring(moved))

			Family.Database:Payload("Smith-FireMaw").professions[smith].recipes = held
		end

		-- Nothing shareable is no list, not an empty one. A profession whose window came
		-- back with no rows had a perfectly good count and fingerprint of nothing, which the
		-- far end asked about and received nothing for - seen on a live client as "recipe
		-- lists held from the guild: 4, 0 recipe(s) in all".
		do
			local held = Family.Database:Payload("Smith-FireMaw").professions[smith].recipes
			Family.Database:Payload("Smith-FireMaw").professions[smith].recipes = {}

			check("a profession with nothing shareable offers no list at all",
				Family.Guild:RecipesFor("Smith-FireMaw", smith) == nil)
			check("and nothing for the other end to ask about",
				Family.Guild:RecipeMark("Smith-FireMaw", smith) == nil)

			Family.Database:Payload("Smith-FireMaw").professions[smith].recipes = held
		end

		-- A different list must fingerprint differently, or the whole traffic control is a
		-- way of never sending an update.
		local before = fingerprint
		Family.Database:Payload("Smith-FireMaw").professions[smith].recipes[3].spellID = 7422
		local _, _, _, after = Family.Guild:RecipesFor("Smith-FireMaw", smith)
		check("and one recipe changing changes it", after ~= before,
			tostring(before) .. " / " .. tostring(after))
		Family.Database:Payload("Smith-FireMaw").professions[smith].recipes[3].spellID = 7421

		-- It rides with the ranks, and the list does not: two numbers on a message that was
		-- going anyway, against a thousand bytes that were not.
		local mark = (Family.Guild:Offering() or {})["Smith-FireMaw"].professions[1]
		check("the count and the fingerprint go out with the rank",
			mark.count == 3 and mark.fingerprint == fingerprint,
			tostring(mark.count) .. " / " .. tostring(mark.fingerprint))
		check("and the list itself does not", mark.spells == nil and mark.recipes == nil)

		-- Their end: a list arriving, then the same one announced again, then a changed one.
		local asked = {}
		local realAsk = Family.Guild.AskRecipes
		Family.Guild.AskRecipes = function(this, name, memberKey, line)
			asked[#asked + 1] = tostring(memberKey) .. "/" .. tostring(line)
			return realAsk(this, name, memberKey, line)
		end

		local function theyAnnounce(count, print_)
			advance(30)
			asked = {}
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = { ["Faraway-FireMaw"] = {
					meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
					professions = { { skillLine = smith, rank = 300, maxRank = 300,
						count = count, fingerprint = print_ } },
				} },
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")
			advance(30)
			return #asked
		end

		check("a list we have never held is asked for", theyAnnounce(2, 4242) == 1,
			table.concat(asked, ", "))

		advance(30)
		sent = {}
		Family.Comm:Send("grec", Family.Codec:ToWire {
			schema = 1, version = Family.version, guild = guildName,
			character = "Faraway-FireMaw", rschema = 1,
			member = "Faraway-FireMaw", line = smith,
			-- Deltas, not ids: sorted ids differ by tens and LibSerialize spends one byte
			-- on a small integer and three on a large one.
			spells = { 2667, 672 }, items = { 2864, 0 },
			missing = 4, fingerprint = 4242,
		}, "WHISPER", "Tester")
		advance(3)
		deliver("Faraway")

		local theirList = Family.Guild:HeldRecipes(guildKey, "Faraway-FireMaw", smith)
		check("and what comes back is stored", theirList ~= nil)
		check("with the gaps read back as the ids they were",
			theirList and theirList.spells[1] == 2667 and theirList.spells[2] == 3339,
			theirList and tostring(theirList.spells[2]) or "nothing")
		check("and what they could not share counted rather than implied away",
			theirList and theirList.missing == 4, theirList and tostring(theirList.missing))

		-- On the item's own tooltip, which is where the question is actually asked (§7.1),
		-- and answered by identifier - so it lands on the *thing they make* and not only on
		-- the pattern, which is the whole reason the item id crosses beside the spell.
		do
			-- An alt of theirs with a different name, because that is the whole point:
			-- a player's characters are not named after them, and the one thing that
			-- says Faraway and Nervina are one person is that one client sent both. A
			-- fixture where the two names match cannot tell the answer apart from the
			-- character it is about.
			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = {
					["Faraway-FireMaw"] = {
						meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
						professions = { { skillLine = smith, rank = 300,
							maxRank = 300, count = 2, fingerprint = 4242 } },
					},
					["Nervina-FireMaw"] = {
						meta = { name = "Nervina", realm = "Fire Maw", level = 61,
							classFile = "MAGE" },
						professions = { { skillLine = smith, rank = 275,
							maxRank = 300, count = 1, fingerprint = 777 } },
					},
				},
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Nervina-FireMaw", line = smith,
				spells = { 60001 }, items = { 60001 },
				missing = 0, fingerprint = 777, seen = time() - 400,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			-- And a character of theirs called after the player, which is the ordinary case
			-- and the one the fixture could not otherwise produce: without it, a check
			-- that a name is not printed twice passes on rows where the two names differ.
			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Faraway-FireMaw", line = smith,
				spells = { 60001 }, items = { 60001 },
				missing = 0, fingerprint = 4242, seen = time() - 400,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			wipe(GameTooltip.__lines)
			GameTooltip.__itemName = "A Thing Made In The Guild"
			GameTooltip.__itemLink = "|Hitem:60001|h"
			if GameTooltip.__scripts.OnTooltipCleared then
				GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
			end
			GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

			local heading, named, alsoSender = false, false, false
			for _, line in ipairs(GameTooltip.__lines) do
				if type(line[1]) == "string" and line[1]:find("Can make it", 1, true) then
					heading = true
				elseif heading and type(line[1]) == "string"
					and line[1]:find("Nervina", 1, true) then
					named = true
					-- Nervina's list arrived from Faraway. Naming the sender as well
					-- would be naming somebody the reader then has to go and look up,
					-- when the character itself is on the roster next door.
					if line[1]:find("Faraway", 1, true) then alsoSender = true end
				end
			end

			check("the guild's answer appears on the item's own tooltip", heading)

			-- **And ours beside it.** Every other block answers about the item under the
			-- cursor; this one used to answer only about the guild, so hovering something
			-- one of your own characters could make said who in the guild could make it
			-- and stayed silent about the character sitting in your own list. One question
			-- gets one block.
			Family.Database:SetMeta("Maker-FireMaw", { name = "Maker", realm = "Fire Maw",
				level = 60, skills = { [smith] = { rank = 288, maxRank = 300 } } })
			Family.Database:SetPayload("Maker-FireMaw", { professions = {
				[smith] = { rank = 288, maxRank = 300, recipesSeen = time(),
					recipes = { { name = "A Thing", spellID = 60001, itemID = 60001 } } },
			} })

			wipe(GameTooltip.__lines)
			GameTooltip.__itemName = "A Thing Made In The Guild"
			GameTooltip.__itemLink = "|Hitem:60001|h"
			if GameTooltip.__scripts.OnTooltipCleared then
				GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
			end
			GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

			local mine, marked = false, false
			for _, line in ipairs(GameTooltip.__lines) do
				if type(line[1]) == "string" then
					if line[1]:find("Maker", 1, true) then mine = true end
					if line[1]:find("(guild)", 1, true) then marked = true end
				end
			end

			check("one of ours who can make it is named on the same block", mine)
			-- One is somebody to log into and the other is somebody to whisper, so the
			-- block says which is which without splitting into two.
			check("and the guild's are marked as theirs", marked)

			Family.Database:Forget("Maker-FireMaw")

			-- **The character, and only the character.** Everything §7 shares is a character
			-- in this guild, so the crafter is on the same roster the reader is looking at:
			-- whisperable if online, visibly not if not. The player who sent the record is
			-- known and adds nothing here, and two names where one is enough is clutter on
			-- the one surface that cannot afford any.
			check("naming the character that can make it", named)
			check("and not the guildmate whose client happened to send it", not alsoSender)

			-- Switched off means off in both directions, and that includes not answering
			-- out of what was collected while it was on.
			Family.Guild:SetEnabled(false)
			wipe(GameTooltip.__lines)
			GameTooltip.__itemLink = "|Hitem:60001|h"
			if GameTooltip.__scripts.OnTooltipCleared then
				GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
			end
			GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

			local stillThere = false
			for _, line in ipairs(GameTooltip.__lines) do
				if type(line[1]) == "string" and line[1]:find("Can make it", 1, true) then
					stillThere = true
				end
			end
			check("and says nothing at all once guild share is switched off", not stillThere)
			Family.Guild:SetEnabled(true)

			-- A recipe that crossed with a spell and no item, which is everything
			-- enchanting on Classic Era: the Craft frame gives no item id at all, even
			-- for the rows that make one. The oil under the cursor has an item id that is
			-- in no list, and the formula that teaches an enchant has one that was never
			-- related to it - so no id could ever match and enchanting answered nothing.
			ITEM_NAMES[70010] = "Wizard Oil"
			ITEM_NAMES[70011] = "Formula: Wizard Oil"

			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Nervina-FireMaw", line = mining,
				-- 25128 is Wizard Oil in this client's own tables. No item id, which is
				-- what that window answers with.
				spells = { 25128 }, items = { 0 },
				missing = 0, fingerprint = 909, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			local function hovered(id, needle)
				wipe(GameTooltip.__lines)
				GameTooltip.__itemName = ITEM_NAMES[id]
				GameTooltip.__itemLink = "|Hitem:" .. id .. "|h"
				if GameTooltip.__scripts.OnTooltipCleared then
					GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
				end
				GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

				for _, line in ipairs(GameTooltip.__lines) do
					if type(line[1]) == "string"
						and line[1]:find(needle or "Can make it", 1, true) then
						return true
					end
				end
				return false
			end

			-- And on the recipe's own tooltip, which for an enchant is the only tooltip
			-- there is: it makes no object, so there is nothing in the world to hover.
			-- Answered by id alone there - a spell tooltip states which spell it is, and
			-- that is the number the guild sent.
			do
				wipe(GameTooltip.__lines)
				if GameTooltip.__scripts.OnTooltipCleared then
					GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
				end
				Family.UI.__modernSpellCallback(GameTooltip, { id = 25128 })

				local named = false
				for _, line in ipairs(GameTooltip.__lines) do
					if type(line[1]) == "string"
						and line[1]:find("Can make it", 1, true) then
						named = true
					end
				end
				check("a recipe that makes nothing is answered on its own tooltip", named)

				-- And by the other route. Classic Era has no modern tooltip system at
				-- all, so the hook is the only thing that fires there - and a check that
				-- exercises the post-call alone is exactly the check this file already
				-- warns about, one route deep, for items.
				GameTooltip.__spellID = 25128
				wipe(GameTooltip.__lines)
				if GameTooltip.__scripts.OnTooltipCleared then
					GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
				end
				local hooked = false
				if GameTooltip.__scripts.OnTooltipSetSpell then
					GameTooltip.__scripts.OnTooltipSetSpell(GameTooltip)

					for _, line in ipairs(GameTooltip.__lines) do
						if type(line[1]) == "string"
							and line[1]:find("Can make it", 1, true) then
							hooked = true
						end
					end
				end
				check("by the hook as well as by the post-call", hooked)
				GameTooltip.__spellID = nil
			end

			check("the thing a spell-only recipe makes is answered for", hovered(70010))
			check("and so is the formula that teaches it", hovered(70011))

			-- **And the same client set to another language answers the same.**
			--
			-- Matching on a name is the one thing §2.1 forbids across a wire, and this does
			-- not do it: nothing but the id crossed, and *both* sides of the comparison are
			-- worked out here - the recipe's name from the id that arrived, the item's name
			-- from the item under the cursor. Change what this client calls things and the
			-- answer does not move, because neither side of it came from the sender.
			--
			-- Nothing stored is touched below. Only the client's answers change.
			do
				local realSpell, realLocale = SPELL_NAMES[25128], Family.locale

				-- Different item ids, because the names of the old ones are already
				-- cached from the hovers above and this is about what the client says,
				-- not about what it said an hour ago.
				ITEM_NAMES[70012] = "Huile de sorcier"
				ITEM_NAMES[70013] = "Formule : Huile de sorcier"

				SPELL_NAMES[25128] = "Huile de sorcier"
				Family.locale = "frFR"

				-- Looked for by the crafter's name rather than by the block's heading:
				-- the heading is translated along with everything else, and a check that
				-- searched for the English one would be measuring the locale switch.
				check("a client speaking another language answers the same",
					hovered(70012, "Nervina"))
				check("and about the formula in that language too",
					hovered(70013, "Nervina"))

				SPELL_NAMES[25128], Family.locale = realSpell, realLocale
			end
			Family.Guild:SetEnabled(true)
		end

		-- The recipe search, which is the other place the question gets asked (§7.1)
		--
		-- **And the check the whole of §2.1 is for.** Nothing that arrived carried a word:
		-- what crossed was spell 25128 and nothing else, and the name it is searched by comes
		-- from *this* client's own tables. A list recorded on a French client is found by
		-- somebody typing in German, and neither end ever held a word the other could read.
		do
			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Nervina-FireMaw", line = smith,
				spells = { 25128 }, items = { 0 },
				missing = 0, fingerprint = 555, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			-- A second character of the same player who knows it too. One guildmate to
			-- whisper, not two: the whole premise is that Faraway and Nervina are one
			-- person, and the only thing that says so is that one client sent both.
			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Faraway-FireMaw", line = smith,
				spells = { 25128 }, items = { 0 },
				missing = 0, fingerprint = 556, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			-- Two recipes with an item id and no spell, which is the ordinary Era shape.
			-- Keyed by the spell they have not got, they would collide into one row.
			ITEM_NAMES[70001] = "Pyrewood Pie"
			ITEM_NAMES[70002] = "Pyrewood Pudding"

			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Nervina-FireMaw", line = mining,
				-- Nought where the client gave no spell, and one row with neither id,
				-- which is a row about nothing and must not reach our disk (§2.3).
				spells = { 0, 0, 0 }, items = { 70001, 70002, 0 },
				missing = 0, fingerprint = 606, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			local eraList = Family.Guild:HeldRecipes(guildKey, "Nervina-FireMaw", mining)
			check("a row carrying neither identifier is not written to disk",
				eraList and #eraList.spells == 2,
				eraList and tostring(#eraList.spells) or "nothing")

			local pyrewood = Family.Recipes:Search("pyrewood")
			check("and two item-only recipes are two rows, not one",
				#pyrewood == 2, tostring(#pyrewood) .. " rows")

			-- A picture is not an identifier and does not cross the wire, so a recipe
			-- nobody at home knows has none of its own - and came up as a question mark
			-- beside the ones that do. The call that names an id hands back its picture.
			local drawn = 0
			for _, found in ipairs(pyrewood) do
				if found.icon then drawn = drawn + 1 end
			end
			check("a recipe only the guild knows is given the client's own picture for it",
				drawn == 2, tostring(drawn) .. " of " .. tostring(#pyrewood))

			-- A list that decodes to nothing is dropped rather than written empty. An
			-- older client still sends them - this end stopped - and one held counts on
			-- the panel as something that arrived while answering no question ever put
			-- to it.
			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Nervina-FireMaw", line = mining,
				spells = { 0, 0 }, items = { 0, 0 },
				missing = 0, fingerprint = 607, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			check("a list that decodes to nothing at all is not held as an empty one",
				Family.Guild:HeldRecipes(guildKey, "Nervina-FireMaw", mining) == nil)

			-- And a profession they still tick but can no longer send anything for takes
			-- the list we held for it with it: they cannot replace it, so keeping it makes
			-- them look like they still share something they do not.
			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Nervina-FireMaw", line = mining,
				spells = { 0 }, items = { 70001 },
				missing = 0, fingerprint = 608, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")
			check("a real list is held again", Family.Guild:HeldRecipes(guildKey,
				"Nervina-FireMaw", mining) ~= nil)

			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = {
					["Nervina-FireMaw"] = {
						meta = { name = "Nervina", realm = "Fire Maw", level = 61 },
						professions = {
							-- Ticked, and with nothing to send for it.
							{ skillLine = mining, rank = 275, maxRank = 300 },
							-- And the one the checks below are written about,
							-- carried along unchanged: a profession absent from
							-- what arrives loses the list held for it, which is
							-- the rule two checks above this one.
							{ skillLine = smith, rank = 275, maxRank = 300,
								count = 1, fingerprint = 555 },
						},
					},
					-- Carried along unchanged. Everything one player sends replaces
					-- everything held from them, so leaving this out would drop the
					-- character the checks below are written about.
					["Faraway-FireMaw"] = {
						meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
						professions = { { skillLine = smith, rank = 300,
							maxRank = 300, count = 2, fingerprint = 4242 } },
					},
				},
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			check("a profession they can no longer send for loses the list we held",
				Family.Guild:HeldRecipes(guildKey, "Nervina-FireMaw", mining) == nil)

			local hits = Family.Recipes:Search("wizard oil")
			local row
			for _, found in ipairs(hits) do
				if found.spellID == 25128 then row = found end
			end

			check("a guild recipe is found by the name this client gives its id", row ~= nil,
				tostring(#hits) .. " rows")
			check("and the guildmate is named on it, as a person",
				row and row.guild and row.guild[1]
					and row.guild[1].player:find("Faraway", 1, true) ~= nil,
				row and row.guild and row.guild[1]
					and tostring(row.guild[1].player) or "nobody")
			check("with nothing of that name recorded in the family",
				row and #row.members == 0, row and tostring(#row.members) or "no row")
			-- Two characters, because two characters can make it and each is on the guild
			-- roster in its own right. Collapsing them into the one player who owns both
			-- would name somebody the reader then has to go and look up.
			check("and two characters of theirs who know it are named as two",
				row and #row.guild == 2, row and tostring(#row.guild) or "no row")

			-- Off is off here too, and it has to be checked separately: this reads out of
			-- what was collected rather than off the wire, so the switch is the only thing
			-- stopping it.
			Family.Guild:SetEnabled(false)
			local quiet = Family.Recipes:Search("wizard oil")
			local stillFound = false
			for _, found in ipairs(quiet) do
				if found.spellID == 25128 then stillFound = true end
			end
			check("and the search says nothing about the guild once it is switched off",
				not stillFound)

			-- And says that it could. The box is labelled "whole family" and is now also
			-- asking the guild; somebody who has never switched guild share on has no way
			-- at all to learn that, and a row that happens to carry a guild group is not a
			-- way of learning it either.
			local box = _G.FamilyProfessionsSearch

			local function typed(text)
				box:SetText(text)
				box.__scripts.OnTextChanged(box)
			end

			Family.UI:Show()
			Family.UI:ShowTab("professions")

			-- Put back exactly as found. A search left typed and the whole family left
			-- ticked is a panel the checks after this one were not written about, and this
			-- file already carries a note about the last time that happened.
			local wasEveryone = _G.FamilyProfessionsEveryone.__checked
			local wasTyped = box.__text or ""

			if not wasEveryone then
				_G.FamilyProfessionsEveryone.__scripts.OnClick(
					_G.FamilyProfessionsEveryone)
			end

			typed("a recipe of no such name")
			check("with the feature off, the search says the guild could be searched too",
				visibleText("Guild share, in Options, searches your guild too"))

			Family.Guild:SetEnabled(true)
			typed("a recipe of no such name")
			check("and with it on, that it was", visibleText("family or the guild"))

			-- A row with more crafters than it can show unfolds into all of them - rows
			-- rather than a taller row, because the list hands out fixed-height frames
			-- from a pool and scrolls by their count.
			Family.Guild:SetEnabled(true)

			-- Five of ours who know the same thing, because a row only offers to unfold
			-- when it is hiding somebody - and with four shown, four crafters hide none.
			--
			-- Their skills run *against* their names on purpose: Alfa is the least skilled
			-- and Echo the most. Ranked the same way round as the alphabet, a check that
			-- the four shown are the four highest passes whichever order the panel used.
			for index, who in ipairs { "Alfa", "Bravo", "Charlie", "Delta", "Echo" } do
				Family.Database:SetMeta(who .. "-FireMaw", { name = who,
					realm = "Fire Maw", level = 60,
					skills = { [smith] = { rank = 290 + index, maxRank = 300 } } })
				Family.Database:SetPayload(who .. "-FireMaw", { professions = {
					[smith] = { rank = 290 + index, maxRank = 300, recipesSeen = time(),
						recipes = { { name = "Wizard Oil", spellID = 25128 } } },
				} })
			end

			typed("wizard oil")

			local opener
			for _, f in ipairs(frames) do
				if f.__shown == true and f.expandKey ~= nil then opener = f end
			end
			check("a row with more crafters than it shows offers to unfold", opener ~= nil)

			-- Highest skill first, which is what makes the cap bearable: alphabetical made
			-- "+3" hide three arbitrary people, and by rank it hides the three you would
			-- ask last. Echo is the most skilled of the five and Alfa the least, so by rank
			-- Echo is on the line and Alfa is behind the fold - and alphabetically it is
			-- the other way about, which is what lets this tell them apart.
			check("and the names it does show are the highest skilled",
				visibleText("Echo") and not visibleText("Alfa"))

			if opener then
				opener.__scripts.OnClick(opener)
				check("and unfolding it names every one of them",
					visibleText("Nervina") and visibleText("Faraway"))

				local rowsOpen = 0
				for _, f in ipairs(frames) do
					if f.__shown == true and f.__parent and f.icon then
						rowsOpen = rowsOpen + 1
					end
				end

				opener.__scripts.OnClick(opener)

				local rowsShut = 0
				for _, f in ipairs(frames) do
					if f.__shown == true and f.__parent and f.icon then
						rowsShut = rowsShut + 1
					end
				end
				check("and folding it again puts them away", rowsShut < rowsOpen,
					tostring(rowsShut) .. " against " .. tostring(rowsOpen))
			end

			for _, who in ipairs { "Alfa", "Bravo", "Charlie", "Delta", "Echo" } do
				Family.Database:Forget(who .. "-FireMaw")
			end

			if not wasEveryone then
				_G.FamilyProfessionsEveryone.__scripts.OnClick(
					_G.FamilyProfessionsEveryone)
			end
			typed(wasTyped)
			Family.UI:ShowTab("guild")
			Family.Guild:SetEnabled(true)

			-- Put back the list the fingerprint checks below are written about. The block
			-- above deliberately replaced it, and a check that depends on what the block
			-- before it left behind passes or fails according to the order of the file.
			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", rschema = 1,
				member = "Faraway-FireMaw", line = smith,
				spells = { 2667, 672 }, items = { 60001, 0 },
				missing = 0, fingerprint = 4242, seen = time() - 400,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")
		end

		check("the same list announced again is not asked for again",
			theyAnnounce(2, 4242) == 0, table.concat(asked, ", "))
		check("but a changed one is", theyAnnounce(3, 9999) == 1, table.concat(asked, ", "))
		check("and so is one whose count moved without its fingerprint",
			theyAnnounce(7, 4242) == 1, table.concat(asked, ", "))

		Family.Guild.AskRecipes = realAsk

		-- Unticked on their side. Nothing has to be sent to take a grant away: the profession
		-- is simply absent from what arrives next, and the list we held goes with it.
		advance(30)
		sent = {}
		Family.Comm:Send("gdata", Family.Codec:ToWire {
			schema = 1, version = Family.version, guild = guildName,
			character = "Faraway-FireMaw",
			characters = { ["Faraway-FireMaw"] = {
				meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
			} },
		}, "WHISPER", "Tester")
		advance(3)
		deliver("Faraway")

		check("a profession they stop offering takes its recipe list with it",
			Family.Guild:HeldRecipes(guildKey, "Faraway-FireMaw", smith) == nil)

		-- And our side keeps the same promise: a request naming a profession that has been
		-- unticked since is answered by today's grid, not by the one they last heard about.
		advance(30)
		sent = {}
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", smith, false)
		check("a request for something no longer offered is refused",
			Family.Guild:SendRecipes("Faraway", "Smith-FireMaw", smith) == false)
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", smith, true)
		check("and answered once it is offered again",
			Family.Guild:SendRecipes("Faraway", "Smith-FireMaw", smith) ~= false)
		advance(30)

		------------------------------------------------------------------------------------
		-- A list that appears when the grid did not change
		--
		-- Reported from a live guild: a profession ticked, its window opened, both panels
		-- correct, and nothing at all on the wire - the sending client's own diagnosis said
		-- "messages sent from here: 1".
		--
		-- The grid is not the only thing that changes an offering. Opening a profession's
		-- window for the first time gives a ticked profession a recipe list where it had
		-- none, and that touches no box. Nothing announced it, so the traffic control did
		-- what it is for: both ends held recent gear and talents, no exchange happened, the
		-- new fingerprint never crossed, and the list was never asked for.
		------------------------------------------------------------------------------------

		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, true)
		advance(30)
		Family.Guild:MarkChanged()
		advance(30)
		sent = {}

		check("with nothing new to say, nothing is said",
			Family.Guild:MarkChanged() == false)
		advance(30)
		check("and the guild is not told about it", #sent == 0, tostring(#sent))

		-- Their window, opened for the first time.
		Family.Database:Payload("Smith-FireMaw").professions[mining] = {
			rank = 275, maxRank = 300, recipesSeen = time(),
			recipes = { { name = "Smelt Copper", spellID = 2657, itemID = 2840 } },
		}

		sent = {}
		check("a ticked profession that gains a list has something new to say",
			Family.Guild:MarkChanged() == true)
		advance(30)

		local told = 0
		for _, message in ipairs(sent) do
			if message.channel == "GUILD" then told = told + 1 end
		end
		check("and the guild is told, without a box having been touched", told == 1,
			tostring(told) .. " announcements")

		check("and having told them, it does not tell them again",
			Family.Guild:MarkChanged() == false)

		-- **The first login after upgrading, with nobody opening anything.**
		--
		-- Nothing has been announced yet, because nothing was announcing before this existed,
		-- so everything a character can already make counts as new to say. The recipe lists
		-- were on disk the whole time - a profession window opened once, ever, records them
		-- and they persist - so no re-scan and no re-opening is needed. The login scan runs,
		-- the database says a member changed, and this side works out that it has something
		-- to tell the guild.
		do
			FamilyDB.guild.announced = {}
			advance(30)
			sent = {}

			Family.Database:Changed("Smith-FireMaw")
			advance(30)

			local said = 0
			for _, message in ipairs(sent) do
				if message.channel == "GUILD" then said = said + 1 end
			end
			check("a client that has never announced what it can make announces it once",
				said == 1, tostring(said) .. " announcements")
		end

		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, false)
		advance(30)

		-- And Update now means it. The traffic control skips an ordinary announcement when
		-- the other end holds something recent, which is right for a login and wrong for the
		-- one button somebody presses because they think what they see is stale.
		local forced = false
		local realForce = Family.Guild.AnnounceChange
		Family.Guild.AnnounceChange = function(this, ...)
			forced = true
			return realForce(this, ...)
		end

		Family.Guild:Refresh("a check")
		Family.Guild.AnnounceChange = realForce

		check("Update now asks in a way the other end will not skip", forced)
		advance(30)

		------------------------------------------------------------------------------------
		-- The six hours, and what used to fall down them
		--
		-- The traffic control asks whether what *we* hold from somebody is recent, and one of
		-- the things it decides is whether they get what *we* have. So two clients that each
		-- hold recent data from the other exchange nothing at all - and a change made while
		-- one of them was logged off waits out the whole of STALE_AFTER, because the
		-- announcement that carried it went to a guild they were not in yet.
		--
		-- One number in the hello closes it: what they say they are offering, against what we
		-- can build out of what we hold from them.
		------------------------------------------------------------------------------------

		do
			advance(30)
			sent = {}

			-- Everything settled: we hold their offering, and the number we build from it
			-- is the number they would send.
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = { ["Faraway-FireMaw"] = {
					meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
					professions = { { skillLine = smith, rank = 300, maxRank = 300,
						count = 2, fingerprint = 4242 } },
				} },
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")
			advance(30)

			local settled = Family.Guild:HeldOfferHash(guildKey, "Faraway")
			check("what we hold from somebody can be said in one number", settled ~= nil)

			-- And our own, on the wire. The number is only worth anything if it is the one
			-- that actually goes out and if it moves when what we offer moves.
			advance(30)
			sent = {}
			Family.Guild:Announce("a check")

			local announced = Family.Codec:FromWire(
				sent[1] and sent[1].text:match("[^\1]*$") or "")
			check("an announcement carries what we are offering, in one number",
				type(announced) == "table"
					and announced.offer == Family.Guild:OfferHash(),
				type(announced) == "table" and tostring(announced.offer) or "nothing")

			local was = Family.Guild:OfferHash()
			Family.Database:Payload("Smith-FireMaw").professions[smith]
				.recipes[1].spellID = 2662
			check("and the number moves when one recipe does",
				Family.Guild:OfferHash() ~= was,
				tostring(was) .. " / " .. tostring(Family.Guild:OfferHash()))
			Family.Database:Payload("Smith-FireMaw").professions[smith]
				.recipes[1].spellID = 2667

			advance(30)

			local function helloCarrying(offer)
				advance(30)
				sent = {}
				Family.Comm:Send("ghello", Family.Codec:ToWire {
					schema = 1, version = Family.version, guild = guildName,
					character = "Faraway-FireMaw", offer = offer,
				}, "GUILD", nil)
				advance(3)
				deliver("Faraway")
				sent = {}
				advance(12)
				return #sent
			end

			local agreeing = helloCarrying(settled)
			local differing = helloCarrying(settled + 1)

			check("a hello saying they offer what we already hold stays quiet",
				agreeing > 0, tostring(agreeing))
			check("and one saying they offer something else does not",
				differing > agreeing,
				tostring(differing) .. " against " .. tostring(agreeing))

			-- An older client sends no such number, and must not be treated as though it
			-- were always out of step: that would undo the six hours for every guild with
			-- one old copy in it.
			local silentAbout = helloCarrying(nil)
			check("and a client too old to send one is left to the six hours",
				silentAbout == agreeing,
				tostring(silentAbout) .. " against " .. tostring(agreeing))
		end

		-- **And nothing has to call any of that.** A scan writing a member's payload is what
		-- tells this side that a list has appeared, and the whole of the live bug was that
		-- nothing was listening: every check above would have passed with no watcher at all,
		-- because every one of them asks the question by hand.
		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, true)
		advance(30)
		Family.Guild:MarkChanged()
		advance(30)
		sent = {}

		Family.Database:Payload("Smith-FireMaw").professions[mining].recipes = {
			{ name = "Smelt Copper", spellID = 2657, itemID = 2840 },
			{ name = "Smelt Tin", spellID = 3304, itemID = 3576 },
		}
		Family.Database:Changed("Smith-FireMaw")
		advance(30)

		local noticed = 0
		for _, message in ipairs(sent) do
			if message.channel == "GUILD" then noticed = noticed + 1 end
		end
		check("a scan that adds a recipe is noticed without anybody asking it to be",
			noticed == 1, tostring(noticed) .. " announcements")

		Family.Guild:SetShare(guildKey, "Smith-FireMaw", mining, false)
		advance(30)

		------------------------------------------------------------------------------------
		-- Slice 3: cooldowns
		--
		-- The one question in here whose answer changes on its own while nobody is looking,
		-- and the one where "who can make this" is the wrong question and "whose is up" is
		-- the right one (§4.5). Two rules are being checked as much as any transport is: a
		-- craft may say it is ready and an item may not, and what crosses is a duration
		-- while what is kept is a moment.
		------------------------------------------------------------------------------------

		do
			local now = time()

			-- A cooldown starting is a change the guild is told about, and it has to be:
			-- the far end holds a duration it has been counting down since the last
			-- announcement, and a transmute used this afternoon would otherwise go on
			-- reading "ready" over there until something else happened to be worth
			-- sending. Using a craft means having its window open, and that means a scan,
			-- so this costs one small message at the moment the fact changes and nothing
			-- at all on the days it does not.
			advance(30)
			Family.Guild:MarkChanged()
			advance(30)
			sent = {}

			Family.Database:SetMeta("Smith-FireMaw", {
				craftCooldowns = {
					-- Running, and identified both ways.
					{ name = "Transmute: Arcanite", profession = smith,
						spellID = 17187, itemID = 12360, readyAt = now + 3600 },
					-- Ready. In the list at all because Family has watched it run once,
					-- and carrying no moment because none is running now.
					{ name = "Mooncloth", profession = smith,
						spellID = 18560, itemID = 14342 },
					-- The client named it and identified it in neither way, so there is
					-- nothing that could cross in a language the reader can read (§2.1).
					{ name = "Something The Client Would Not Name", profession = smith },
					-- A profession of ours that nobody has ticked. A tick means one
					-- thing, and this was not it.
					{ name = "Smelt Dark Iron", profession = mining,
						spellID = 22967, itemID = 11371, readyAt = now + 60 },
				},
				itemCooldowns = {
					-- Still running, so still a fact.
					{ id = 15846, readyAt = now + 1800 },
					-- Come ready while nobody was watching the bags it lives in.
					{ id = 15847, readyAt = now - 10 },
					-- On cooldown, and nothing of ours makes it - so no tick could ever
					-- have offered it.
					{ id = 20000, readyAt = now + 900 },
				},
				cooldownItems = { [15846] = smith, [15847] = smith },
			})

			Family.Database:Changed("Smith-FireMaw")
			advance(30)

			local told = 0
			for _, message in ipairs(sent) do
				if message.channel == "GUILD" then told = told + 1 end
			end
			check("a scan where a cooldown has started is told to the guild",
				told == 1, tostring(told) .. " announcement(s)")

			-- And the same cooldown, scanned again a second later, is not. This is the
			-- case the fixture has to produce rather than assume: a rescan writes
			-- `time()` plus whatever the client answered, so the moment lands a second
			-- or two from where it did before while nothing whatever has happened. A
			-- marker built out of that number puts a message on the guild channel every
			-- time somebody opens a profession window.
			advance(30)
			sent = {}

			local drifted = Family.Database:Meta("Smith-FireMaw").craftCooldowns
			for _, entry in ipairs(drifted) do
				if entry.readyAt then entry.readyAt = entry.readyAt - 2 end
			end
			Family.Database:SetMeta("Smith-FireMaw", { craftCooldowns = drifted })

			Family.Database:Changed("Smith-FireMaw")
			advance(30)

			local again = 0
			for _, message in ipairs(sent) do
				if message.channel == "GUILD" then again = again + 1 end
			end
			check("and the same one scanned again a second later is not",
				again == 0, tostring(again) .. " announcement(s)")

			-- Put back, so the durations the wire checks below are written about are the
			-- round numbers they were set to rather than the drifted ones.
			for _, entry in ipairs(drifted) do
				if entry.readyAt then entry.readyAt = entry.readyAt + 2 end
			end
			Family.Database:SetMeta("Smith-FireMaw", { craftCooldowns = drifted })

			local offered = (Family.Guild:Offering() or {})["Smith-FireMaw"]
			local line
			for _, profession in ipairs((offered or {}).professions or {}) do
				if profession.skillLine == smith then line = profession end
			end

			local rows = (line or {}).cooldowns or {}
			local byID = {}
			for _, row in ipairs(rows) do
				byID[(row.spell and "spell:" .. row.spell)
					or ("item:" .. tostring(row.item))] = row
			end

			check("what is on cooldown rides out with the profession it belongs to",
				#rows == 3, tostring(#rows) .. " row(s)")

			local running = byID["spell:17187"]
			check("a running cooldown crosses as how long is left",
				running ~= nil and running.left == 3600,
				running and tostring(running.left) or "nothing")
			check("and never as a moment, because two clients need not agree on one",
				running ~= nil and running.readyAt == nil)
			check("with both ids, so either end of the wire can match it",
				running ~= nil and running.spell == 17187 and running.item == 12360)

			local ready = byID["spell:18560"]
			check("a craft that is ready crosses, as the absence of a duration",
				ready ~= nil and ready.left == nil and ready.bags == nil,
				ready and tostring(ready.left) or "nothing")

			local bagged = byID["item:15846"]
			check("an item still counting down crosses, marked as the bags'",
				bagged ~= nil and bagged.left == 1800 and bagged.bags == true,
				bagged and tostring(bagged.left) or "nothing")

			check("an item cooldown that has come ready does not cross at all",
				byID["item:15847"] == nil)
			check("nor one belonging to no profession of theirs",
				byID["item:20000"] == nil)
			check("nor a cooldown the client would only give a word for",
				#rows == 3 and byID["spell:0"] == nil)
			check("nor one of a profession nobody ticked",
				byID["spell:22967"] == nil
					and (offered or {}).professions ~= nil
					and #offered.professions == 1)

			----------------------------------------------------------------------------
			-- Their end
			----------------------------------------------------------------------------

			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = {
					["Faraway-FireMaw"] = {
						meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
						professions = { { skillLine = smith, rank = 300,
							maxRank = 300, count = 1, fingerprint = 4242,
							cooldowns = {
								{ spell = 60001, item = 60001, left = 7200 },
							} } },
					},
					["Nervina-FireMaw"] = {
						meta = { name = "Nervina", realm = "Fire Maw", level = 61,
							classFile = "MAGE" },
						professions = { { skillLine = smith, rank = 275,
							maxRank = 300, count = 1, fingerprint = 777,
							cooldowns = {
								{ spell = 60001, item = 60001 },
							} } },
					},
				},
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			-- The lists themselves, planted fresh: earlier blocks have moved on and
			-- what a cooldown is attached to has to be a recipe this end still holds.
			for _, who in ipairs { { "Faraway-FireMaw", 4242 }, { "Nervina-FireMaw", 777 } } do
				advance(30)
				sent = {}
				Family.Comm:Send("grec", Family.Codec:ToWire {
					schema = 1, version = Family.version, guild = guildName,
					character = "Faraway-FireMaw", rschema = 1,
					member = who[1], line = smith,
					spells = { 60001 }, items = { 60001 },
					missing = 0, fingerprint = who[2], seen = time() - 400,
				}, "WHISPER", "Tester")
				advance(3)
				deliver("Faraway")
			end

			local crafters = Family.Guild:CraftersOf(60001, nil, nil)
			local mine = {}
			for _, who in ipairs(crafters) do mine[who.name] = who end

			check("a cooldown arrives beside the crafter it belongs to",
				mine.Faraway ~= nil and mine.Faraway.cooldown ~= nil)
			check("and the duration that crossed is kept as a moment",
				mine.Faraway ~= nil and mine.Faraway.cooldown ~= nil
					and mine.Faraway.cooldown.readyAt == time() + 7200,
				mine.Faraway and mine.Faraway.cooldown
					and tostring(mine.Faraway.cooldown.readyAt) or "nothing")
			check("a craft sent without one is read as ready",
				mine.Nervina ~= nil and mine.Nervina.cooldown ~= nil
					and mine.Nervina.cooldown.ready == true)

			-- The half a tooltip is read for. Whoever can do it now is above whoever
			-- cannot, whatever else is true of either of them.
			check("and whoever's is up is named before whoever is still waiting",
				crafters[1] ~= nil and crafters[1].name == "Nervina",
				crafters[1] and tostring(crafters[1].name) or "nobody")

			-- On the tooltip itself, which is where this is read.
			wipe(GameTooltip.__lines)
			GameTooltip.__itemName = "A Thing Made In The Guild"
			GameTooltip.__itemLink = "|Hitem:60001|h"
			if GameTooltip.__scripts.OnTooltipCleared then
				GameTooltip.__scripts.OnTooltipCleared(GameTooltip)
			end
			GameTooltip.__scripts.OnTooltipSetItem(GameTooltip)

			local said, waiting = false, false
			for _, entry in ipairs(GameTooltip.__lines) do
				if type(entry[1]) == "string" and entry[1]:find("Nervina", 1, true)
					and type(entry[2]) == "string"
					and entry[2]:find("ready now", 1, true) then
					said = true
				end
				if type(entry[1]) == "string" and entry[1]:find("Faraway", 1, true)
					and type(entry[2]) == "string"
					and entry[2]:find("ready ", 1, true)
					and not entry[2]:find("ready now", 1, true) then
					waiting = true
				end
			end

			check("the tooltip says beside the crafter that theirs is up", said)
			check("and says when the other one's comes back", waiting)

			-- And the age is still there, because a record of an announcement made some
			-- hours ago is a weaker "ready" than one made a minute ago (§2.2).
			local aged = false
			for _, entry in ipairs(GameTooltip.__lines) do
				if type(entry[1]) == "string" and entry[1]:find("Nervina", 1, true)
					and type(entry[2]) == "string"
					and entry[2]:find("ready now", 1, true)
					and entry[2]:find("ago", 1, true) then
					aged = true
				end
			end
			check("without dropping how old the record it came out of is", aged)

			----------------------------------------------------------------------------
			-- What must not be believed
			----------------------------------------------------------------------------

			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = {
					["Faraway-FireMaw"] = {
						meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
						professions = { { skillLine = smith, rank = 300,
							maxRank = 300, count = 1, fingerprint = 4242,
							cooldowns = {
								-- A duration no cooldown in the game has.
								{ spell = 60001, item = 60001,
									left = 400 * 86400 },
							} } },
					},
					["Nervina-FireMaw"] = {
						meta = { name = "Nervina", realm = "Fire Maw", level = 61,
							classFile = "MAGE" },
						professions = { { skillLine = smith, rank = 275,
							maxRank = 300, count = 1, fingerprint = 777,
							cooldowns = {
								-- An item's, with no duration on it - which is a
								-- claim about somebody else's bags, and is not
								-- one Family will repeat.
								{ item = 60001, bags = true },
							} } },
					},
				},
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			local after = {}
			for _, who in ipairs(Family.Guild:CraftersOf(60001, nil, nil)) do
				after[who.name] = who
			end

			check("an item cooldown arriving with no duration is not read as ready",
				after.Nervina ~= nil and after.Nervina.cooldown == nil)

			-- And is not written down either, which is not the same question. A record
			-- kept and then declined every time it is read is a record waiting for the
			-- one reader that forgets to decline it.
			local kept
			for _, profession in ipairs((Family.Guild:Known(guildKey)["Nervina-FireMaw"]
				or {}).professions or {}) do
				if profession.skillLine == smith then kept = profession.cooldowns end
			end
			check("and is not written to our disk on their say-so either", kept == nil,
				kept and tostring(#kept) .. " row(s)" or "nothing")
			check("and a duration longer than any cooldown in the game is dropped",
				after.Faraway ~= nil and after.Faraway.cooldown == nil)

			----------------------------------------------------------------------------
			-- And what happens to both of them once their moment passes
			--
			-- The distinction Cooldowns.lua draws for one's own characters, kept across
			-- the wire where it matters more rather than less: the reader is a different
			-- player, looking at a record made at some point in the past. A craft that
			-- has come back is a craft that has come back, because using one needs the
			-- window its owner's client scans. An item that has come back is a guess
			-- about a bag nobody has looked in since (§2.2).
			----------------------------------------------------------------------------

			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = {
					["Faraway-FireMaw"] = {
						meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
						professions = { { skillLine = smith, rank = 300,
							maxRank = 300, count = 1, fingerprint = 4242,
							cooldowns = {
								{ spell = 60001, item = 60001, left = 600 },
							} } },
					},
					["Nervina-FireMaw"] = {
						meta = { name = "Nervina", realm = "Fire Maw", level = 61,
							classFile = "MAGE" },
						professions = { { skillLine = smith, rank = 275,
							maxRank = 300, count = 1, fingerprint = 777,
							cooldowns = {
								{ item = 60001, left = 600, bags = true },
							} } },
					},
				},
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			local before = {}
			for _, who in ipairs(Family.Guild:CraftersOf(60001, nil, nil)) do
				before[who.name] = who
			end
			check("an item of theirs still counting down is a fact and is shown",
				before.Nervina ~= nil and before.Nervina.cooldown ~= nil
					and before.Nervina.cooldown.ready == false)

			local realTime = time
			time = function() return realTime() + 3600 end

			local later = {}
			for _, who in ipairs(Family.Guild:CraftersOf(60001, nil, nil)) do
				later[who.name] = who
			end

			check("an hour on, their craft has come back and says so",
				later.Faraway ~= nil and later.Faraway.cooldown ~= nil
					and later.Faraway.cooldown.ready == true)
			check("and their item's has stopped being a fact rather than become a ready one",
				later.Nervina ~= nil and later.Nervina.cooldown == nil)

			time = realTime
		end

		------------------------------------------------------------------------------------
		-- The grid, on the panel it governs
		------------------------------------------------------------------------------------

		Family.UI:Show()
		Family.UI:ShowTab("guild")

		check("the panel says what is shared and with whom",
			visibleText("What you share with"))

		-- Folded away to begin with. The panel is about the guild's people; a player with
		-- eight characters in it has thirty rows of grid sitting on a roster of a hundred
		-- and sixty, which is a grid hiding the panel it was put on.
		check("the grid is folded to begin with", labelled("Blacksmithing") == nil)
		check("and the heading says so, and says how much is offered while folded",
			visibleText("click to open"))
		check("the heading opens it", clickRow("What you share with"))
		check("and the boxes are there once it is open", labelled("Blacksmithing") ~= nil)

		-- A profession filed under a word the skill line table knows is that profession, and
		-- is offered like any other. The ids were a lookup away the whole time, and refusing
		-- them made a member recorded by an older version unshareable for ever.
		local herbs = Family:SkillLineFor("Tailoring")
		Family.Guild:SetShare(guildKey, "Oldtimer-FireMaw", herbs, true)
		Family.UI:Refresh()

		-- Found by being ticked, not by the word on it. Another member of this fixture has
		-- Tailoring too, keyed by an id, and a needle that matched the word alone found
		-- their box and passed whatever this panel did to Oldtimer's.
		local older
		for _, f in ipairs(fontStrings) do
			local parent = type(f.__parent) == "table" and f.__parent or nil
			if type(f.__text) == "string" and f.__text:find("Tailoring", 1, true)
				and parent and parent.label == f and parent.__shown ~= false
				and parent.__checked == true then
				older = parent
			end
		end
		check("a profession recorded under a word rather than an id is still offered",
			older ~= nil and older.__enabled ~= false)

		local theirs3 = (Family.Guild:Offering() or {})["Oldtimer-FireMaw"].professions
		check("and it crosses under its identifier, not under the word",
			theirs3 and #theirs3 == 1 and theirs3[1].skillLine == herbs
				and theirs3[1].rank == 300,
			theirs3 and tostring(theirs3[1] and theirs3[1].skillLine) or "nothing")
		Family.Guild:SetShare(guildKey, "Oldtimer-FireMaw", herbs, false)

		-- A record holding the same profession twice, once under its id and once under the
		-- word - which is what half a migration looks like, and what a saved variables file
		-- Family did not write may hold. One box, one entry on the wire.
		Family.Database:SetMeta("Twice-FireMaw", { name = "Twice", realm = "Fire Maw",
			guild = guildName, classFile = "DRUID", level = 60, skills = {
				[herbs] = { rank = 275, maxRank = 300, name = "Tailoring" },
				["Tailoring"] = { rank = 275, maxRank = 300, name = "Tailoring" },
			} })
		Family.Guild:SetShare(guildKey, "Twice-FireMaw", herbs, true)

		local twice = (Family.Guild:Offering() or {})["Twice-FireMaw"].professions
		check("and one held under both an id and a word crosses once, not twice",
			twice and #twice == 1, twice and tostring(#twice) or "nothing")




		------------------------------------------------------------------------------------
		-- Announcing when the client is slow to name the guild
		--
		-- Joining a guild and creating one are the two moments GetGuildInfo is slowest, and
		-- they are exactly the two moments an announcement matters most. This looked once,
		-- five seconds after the event, and gave up - so a character who had just joined told
		-- the guild nothing and nothing tried again until the next login. Reported live: a
		-- character invited, accepted and standing in the guild, and the guild master two feet
		-- away never heard of them.
		------------------------------------------------------------------------------------

		do
			local realGuildInfo = GetGuildInfo
			local realInGuild = IsInGuild

			local function announcements()
				local said = 0
				for _, message in ipairs(sent) do
					if message.channel == "GUILD" then said = said + 1 end
				end
				return said
			end

			-- The client will not name the guild yet, which is what it does for some seconds
			-- after a join.
			advance(30)
			GetGuildInfo = function() return nil end
			sent = {}

			fire("PLAYER_GUILD_UPDATE")
			advance(8)
			check("nothing is announced while the client will not name the guild",
				announcements() == 0, tostring(announcements()))

			-- And then it does, and the announcement goes without anybody pressing anything.
			GetGuildInfo = realGuildInfo
			advance(8)
			check("and it is announced as soon as the client answers",
				announcements() == 1, tostring(announcements()))

			-- Bounded, because a client that never answers must not be woken for ever.
			advance(30)
			GetGuildInfo = function() return nil end
			sent = {}

			fire("PLAYER_GUILD_UPDATE")
			for _ = 1, 12 do advance(4) end

			GetGuildInfo = realGuildInfo
			advance(10)
			check("and it gives up rather than asking for ever",
				announcements() == 0, tostring(announcements()))

			GetGuildInfo, IsInGuild = realGuildInfo, realInGuild
			advance(30)
			sent = {}
		end

		------------------------------------------------------------------------------------
		-- Switching guild share on says so
		--
		-- Reported from a live client: two characters in one guild, both switched on, and each
		-- panel went on reading "not running Family" about the other. Being heard from is the
		-- only way anybody knows anybody runs this at all - and switching the feature on sent
		-- nothing whatever, so a player was invisible until their next login.
		------------------------------------------------------------------------------------

		do
			local function announcements()
				local said = 0
				for _, message in ipairs(sent) do
					if message.channel == "GUILD" then said = said + 1 end
				end
				return said
			end

			-- Off, quietly. Off means this client neither asks nor answers, and a parting
			-- announcement would be it doing one last of both.
			advance(30)
			sent = {}
			Family.Guild:SetEnabled(false)
			advance(10)
			check("switching guild share off says nothing to the guild",
				announcements() == 0, tostring(announcements()))

			-- And on, loudly.
			sent = {}
			Family.Guild:SetEnabled(true)
			advance(10)
			check("switching it on announces to the guild",
				announcements() == 1, tostring(announcements()))

			-- Marked as a change, which is the half that matters. An ordinary hello lets the
			-- far end answer "what I hold from you is recent, so nothing to do" - and somebody
			-- who has this second switched the feature on is exactly who that must not
			-- silence.
			local marked = false
			for _, message in ipairs(sent) do
				if message.channel == "GUILD" then
					local body = Family.Codec:FromWire(message.text:match("[^\1]*$") or "")
					if type(body) == "table" and body.changed == true then marked = true end
				end
			end
			check("and says that what it offers has changed, so nobody stays quiet at it",
				marked)

			-- Only on the edge. A panel that writes the same value twice, or an options
			-- screen redrawing itself, must not put a second message on the channel.
			sent = {}
			Family.Guild:SetEnabled(true)
			advance(10)
			check("and switching it on when it is already on says nothing further",
				announcements() == 0, tostring(announcements()))
		end

		------------------------------------------------------------------------------------
		-- The perimeter: professions that make nothing are not offered at all
		--
		-- Guild crafters answers "who can make this", so a profession that makes nothing has
		-- no answer to give and a tick box beside it is a box that does nothing. Three places
		-- have to agree about which those are - the grid that draws the boxes, the count under
		-- it, and the wire - and a box drawn for something that never crosses is a box that
		-- lies.
		------------------------------------------------------------------------------------

		do
			local fishing = Family:SkillLineFor("Fishing")
			local mining = Family:SkillLineFor("Mining")
			local smith2 = Family:SkillLineFor("Blacksmithing")

			check("the table knows the professions this is about",
				fishing and mining and smith2 ~= nil,
				tostring(fishing) .. "/" .. tostring(mining) .. "/" .. tostring(smith2))

			-- One character with one of each: something that gathers and nothing else,
			-- something that gathers *and* smelts, and something that plainly crafts.
			Family.Database:SetMeta("Angler-FireMaw", { name = "Angler", realm = "Fire Maw",
				guild = guildName, classFile = "HUNTER", level = 60, skills = {
					[fishing] = { rank = 300, maxRank = 300, secondary = true },
					[mining] = { rank = 300, maxRank = 300 },
					[smith2] = { rank = 300, maxRank = 300 },
				} })
			Family.UI:Refresh()

			-- The grid itself. Nobody else in this fixture has Fishing, so its absence from
			-- the boxes is Angler's absence and not somebody else's presence.
			check("no box is drawn for a profession that gathers and nothing else",
				labelled("Fishing") == nil)
			check("but one is for the profession that smelts",
				labelled("Mining") ~= nil)
			check("and for the one that plainly crafts",
				labelled("Blacksmithing") ~= nil)

			-- The predicate the three of them share, asked directly.
			check("the perimeter refuses what gathers",
				Family.Guild:Shareable(fishing) == false
					and Family.Guild:Shareable(Family:SkillLineFor("Herbalism")) == false
					and Family.Guild:Shareable(Family:SkillLineFor("Skinning")) == false)
			check("and refuses first aid and archaeology, which was a decision not an argument",
				Family.Guild:Shareable(Family:SkillLineFor("First Aid")) == false
					and Family.Guild:Shareable(Family:SkillLineFor("Archaeology")) == false)
			check("and admits mining, for the smelting",
				Family.Guild:Shareable(mining) == true)

			-- A grant written by a version whose perimeter was wider stops counting the
			-- moment it is read, and is not deleted to make that true: the tick is somebody's
			-- decision and a narrowed perimeter is not a reason to throw it away.
			Family.Guild:SetShare(guildKey, "Angler-FireMaw", fishing, true)
			Family.Guild:SetShare(guildKey, "Angler-FireMaw", mining, true)

			check("a grant for something outside the perimeter reads as not shared",
				Family.Guild:Shares(guildKey, "Angler-FireMaw", fishing) == false)
			check("and one inside it reads as shared",
				Family.Guild:Shares(guildKey, "Angler-FireMaw", mining) == true)

			local ticks = Family.Guild:CountShared(guildKey)
			Family.Guild:SetShare(guildKey, "Angler-FireMaw", fishing, false)
			local without = Family.Guild:CountShared(guildKey)
			check("and the count under the grid does not count it either",
				ticks == without, tostring(ticks) .. " against " .. tostring(without))

			-- And the wire, which is the half that actually reaches somebody else.
			Family.Guild:SetShare(guildKey, "Angler-FireMaw", fishing, true)
			local offered = (Family.Guild:Offering() or {})["Angler-FireMaw"]
			local lines = {}
			for _, profession in ipairs((offered or {}).professions or {}) do
				lines[profession.skillLine] = true
			end

			check("a profession outside the perimeter does not cross, ticked or not",
				lines[fishing] ~= true)
			check("and the one that smelts does",
				lines[mining] == true)

			Family.Guild:SetShare(guildKey, "Angler-FireMaw", fishing, false)
			Family.Guild:SetShare(guildKey, "Angler-FireMaw", mining, false)
			Family.Database:Forget("Angler-FireMaw")
			Family.UI:Refresh()
		end

		Family.Guild:SetShare(guildKey, "Twice-FireMaw", herbs, false)
		Family.Database:Forget("Twice-FireMaw")
		Family.UI:Refresh()

		-- The two states said apart. Saying the first about the second is how the panel came
		-- to tell a player a character had no professions while listing three of them.
		check("a character with nothing offerable says so, rather than claiming it has none",
			visibleText("Nothing on this character can be offered"))
		check("and one that really has none still says that",
			visibleText("No professions recorded on this character yet"))

		local box = labelled("Blacksmithing")
		check("with a box per character per profession", box ~= nil)
		check("ticked where the grid says it is ticked", box and box.__checked == true)
		check("and live while guild share is on", box and box.__enabled ~= false)

		-- **And clickable, which is not the same question.** A row is as wide as the list
		-- and takes the mouse whether or not anything is hooked to its click, so a box drawn
		-- on one at the same frame level is a picture of a box. This is the check that was
		-- missing when the grid shipped: every line above it passed while not one box in the
		-- game would answer.
		check("and a click actually reaches it", box and reachable(box),
			box and tostring(coveredBy(box) ~= nil) or "no box")

		-- And the rows the grid draws do not light up under the cursor. A highlight coming
		-- up on a row nothing will happen on tells the player their click is going somewhere
		-- it is not, and it is how the dead boxes were noticed in the first place: the
		-- highlight answered and the box did not.
		-- The character's own row, matched on the name *followed by the colour the level is
		-- written in* rather than on the name alone. "Smith" also occurs inside
		-- "Blacksmithing" and inside the note naming what could not be offered, and the note
		-- has its mouse switched off for its own reasons - so a looser needle found that row
		-- instead and passed whatever this panel did.
		local nameRow
		for _, f in ipairs(fontStrings) do
			local parent = type(f.__parent) == "table" and f.__parent or nil
			if type(f.__text) == "string" and f.__text:find("Smith|r  |cff888888", 1, true)
				and parent and parent.text == f and parent.__parent == guildList() then
				nameRow = parent
			end
		end
		check("and the grid's own rows do not light up under the cursor",
			nameRow ~= nil and nameRow.__mouse == false,
			nameRow and tostring(nameRow.__mouse) or "no row")

		-- The rows the boxes sit on carry no text at all - they are spacers holding the
		-- height while the boxes are placed on top - so a row with nothing written on it
		-- that still answers the mouse is one of those, lighting up under a cursor that is
		-- aimed at a tick box. Said this way rather than by finding the spacer, because a
		-- blank row that highlights is wrong on any panel and for any reason.
		local liveBlank = 0
		for _, f in ipairs(frames) do
			if f.__parent == guildList() and f.__shown == true and takesMouse(f)
				and type(f.text) == "table" and (f.text.__text or "") == "" then
				liveBlank = liveBlank + 1
			end
		end
		check("and a row with nothing written on it does not light up either",
			liveBlank == 0, tostring(liveBlank) .. " blank rows answering the mouse")

		-- A profession this client has no id for is not offered, because it could not cross
		-- if it were - and it is counted rather than quietly left off the grid.
		check("a profession with no identifier is not offered", labelled("Cheesemaking") == nil)
		-- Named, not counted. "1 left out" says something is wrong and gives nobody a way to
		-- find out what; the word the client used is the one thing that identifies it and
		-- the one thing this end has.
		check("and is named rather than left off in silence",
			visibleText("Cheesemaking (Smith)") and visibleText("Not offered:"))

		-- Off means the grid looks inert as well as being inert. A live-looking grid that
		-- recorded grants before the transport existed would be the one way this feature
		-- could undo a default it has no business touching.
		Family.Guild:SetEnabled(false)
		Family.UI:Refresh()

		local greyed = labelled("Blacksmithing")
		check("switched off, the grid is greyed rather than merely inert",
			greyed and greyed.__enabled == false,
			tostring(greyed and greyed.__enabled))
		check("and it still shows what would be offered, and where the switch is",
			visibleText("The switch is in Options"))

		Family.Guild:SetEnabled(true)
		Family.UI:Refresh()

		------------------------------------------------------------------------------------
		-- What arrives
		------------------------------------------------------------------------------------

		-- Anything already on a timer out of the way first, so what is delivered below is
		-- this message and not an announcement an earlier check left pending.
		advance(10)
		sent = {}
		Family.Comm:Send("gdata", Family.Codec:ToWire {
			schema = 1, version = Family.version, guild = guildName,
			character = "Faraway-FireMaw",
			characters = { ["Faraway-FireMaw"] = {
				meta = { name = "Faraway", realm = "Fire Maw", classFile = "WARRIOR",
					level = 70, guild = guildName },
				professions = {
					{ skillLine = smith, rank = 285, maxRank = 300 },
					-- Somebody else's client being wrong, or being older than §2.1.
					-- A word arriving where an identifier was promised is the one
					-- mistake that must not reach our disk.
					{ skillLine = "Blacksmithing", rank = 300, maxRank = 300 },
				},
			} },
		}, "WHISPER", "Tester")
		-- Comm sends two chunks every fifth of a second, so a message is not on the wire
		-- the instant it is handed over. Delivering without this delivers nothing.
		advance(3)
		deliver("Faraway")

		local held = Family.Guild:CharactersOf(guildKey, "Faraway")
		local theirs2
		for _, entry in ipairs(held) do
			if entry.key == "Faraway-FireMaw" then theirs2 = entry end
		end

		check("a rank crosses and is read back", theirs2 and theirs2.professions
			and theirs2.professions[1] and theirs2.professions[1].rank == 285,
			theirs2 and tostring(theirs2.professions
				and theirs2.professions[1] and theirs2.professions[1].rank) or "nobody")
		check("and a profession that arrived as a word is not written to disk",
			theirs2 and theirs2.professions and #theirs2.professions == 1,
			theirs2 and tostring(#(theirs2.professions or {})) or "nobody")

		-- The traffic control skips the whole exchange when what we hold from somebody is
		-- recent. That is right for a login and wrong for exactly this: a grid that has just
		-- changed is the one case where holding something recent is the problem rather than
		-- the reason to relax, and a withdrawal that waits for the six hours to run out is
		-- not a withdrawal.
		--
		-- Measured against the quiet case rather than against a number, because what a full
		-- exchange comes to in chunks depends on how much gear the fixture is wearing.
		local function helloFromFaraway(changed)
			advance(10)
			sent = {}
			Family.Comm:Send("ghello", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw", changed = changed or nil,
			}, "GUILD", nil)
			advance(3)
			deliver("Faraway")
			sent = {}
			advance(9)
			return #sent
		end

		local quiet = helloFromFaraway(false)
		local loud = helloFromFaraway(true)
		check("a hello from somebody we already hold is still answered with a hello",
			quiet > 0, tostring(quiet))
		check("and one saying their grid has changed gets the exchange the skip avoids",
			loud > quiet, tostring(loud) .. " against " .. tostring(quiet))

		Family.UI:Refresh()

		-- Rows on this panel and rows on every other one are the same kind of frame with
		-- the same kind of name written on them, and fontStrings holds every font string the
		-- harness has ever built. Scoped to the frame the grid's heading sits in, or the
		-- first "Faraway" in the whole run gets clicked and it belongs to somebody else.
		local function guildList()
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string"
					and f.__text:find("What you share with", 1, true)
					and parent and parent.__shown ~= false then
					return parent.__parent
				end
			end
			return nil
		end

		local function clickRow(needle)
			local within = guildList()
			for _, f in ipairs(fontStrings) do
				local parent = type(f.__parent) == "table" and f.__parent or nil
				if type(f.__text) == "string" and f.__text:find(needle, 1, true)
					and parent and within and parent.__parent == within
					and parent.__scripts and parent.__scripts.OnClick then
					parent.__scripts.OnClick(parent)
					return true
				end
			end
			return false
		end

		-- One player with several characters in the guild is one client running Family, and
		-- the roster is a list of characters. Counting its rows told a player with eight alts
		-- in the guild that there were nine clients out there, eight of which were theirs -
		-- and that number exists to answer "is anybody else out there".
		Family.Database:SetMeta("Absent-FireMaw", { name = "Absent", realm = "Fire Maw",
			guild = guildName, classFile = "MAGE", level = 61 })
		Family.UI:Refresh()
		check("our own characters count as one person between them, not one each",
			visibleText("|cffffd7002|r running Family"))
		Family.Database:Forget("Absent-FireMaw")
		Family.UI:Refresh()

		check("their row opens", clickRow("Faraway"))
		-- 285 of 300, which is a rank and says nothing about any particular recipe. That
		-- distinction is the whole of what slice 1 is allowed to claim.
		check("and what they share is shown with its rank beside it", visibleText("285"))

		------------------------------------------------------------------------------------
		-- A character of theirs who goes, rather than a profession they untick
		--
		-- Three ways a shared list stops being ours to hold, and this is the third. A guild
		-- we leave is `ForgetLeft`; a profession unticked is absent from the next offering
		-- and dropped in the walk that reads one. A *character* who leaves the guild or is
		-- deleted is absent from the offering too - but the walk only reaches the characters
		-- that arrived, so nothing ever looked at theirs.
		------------------------------------------------------------------------------------

		do
			-- Two characters of Faraway's, each with a list, planted here rather than
			-- assumed: blocks above have moved on, and a check about what is dropped needs
			-- to know what was there.
			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = {
					["Faraway-FireMaw"] = {
						meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
						professions = { { skillLine = smith, rank = 300,
							maxRank = 300, count = 1, fingerprint = 4242 } },
					},
					["Nervina-FireMaw"] = {
						meta = { name = "Nervina", realm = "Fire Maw", level = 61,
							classFile = "MAGE" },
						professions = { { skillLine = smith, rank = 275,
							maxRank = 300, count = 1, fingerprint = 777 } },
					},
				},
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			for _, who in ipairs { { "Faraway-FireMaw", 4242 }, { "Nervina-FireMaw", 777 } } do
				advance(30)
				sent = {}
				Family.Comm:Send("grec", Family.Codec:ToWire {
					schema = 1, version = Family.version, guild = guildName,
					character = "Faraway-FireMaw", rschema = 1,
					member = who[1], line = smith,
					spells = { 60001 }, items = { 60001 },
					missing = 0, fingerprint = who[2], seen = time() - 400,
				}, "WHISPER", "Tester")
				advance(3)
				deliver("Faraway")
			end

			-- Somebody else in the guild entirely, so the sender test below has two senders
			-- to tell apart rather than being a comparison with itself.
			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Otherguy-FireMaw",
				characters = { ["Otherguy-FireMaw"] = {
					meta = { name = "Otherguy", realm = "Fire Maw", level = 60 },
					professions = { { skillLine = smith, rank = 300, maxRank = 300,
						count = 1, fingerprint = 31337 } },
				} },
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Otherguy")

			advance(30)
			sent = {}
			Family.Comm:Send("grec", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Otherguy-FireMaw", rschema = 1,
				member = "Otherguy-FireMaw", line = smith,
				spells = { 60002 }, items = { 60002 },
				missing = 0, fingerprint = 31337, seen = time() - 60,
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Otherguy")

			check("we hold a list for a character of theirs",
				Family.Guild:HeldRecipes(guildKey, "Nervina-FireMaw", smith) ~= nil)
			check("and one for somebody else's",
				Family.Guild:HeldRecipes(guildKey, "Otherguy-FireMaw", smith) ~= nil)

			-- Faraway offers again, and Nervina is not in it. Nothing is sent to say she
			-- has gone; her absence is the whole of the message.
			advance(30)
			sent = {}
			Family.Comm:Send("gdata", Family.Codec:ToWire {
				schema = 1, version = Family.version, guild = guildName,
				character = "Faraway-FireMaw",
				characters = { ["Faraway-FireMaw"] = {
					meta = { name = "Faraway", realm = "Fire Maw", level = 70 },
					professions = { { skillLine = smith, rank = 300, maxRank = 300,
						count = 1, fingerprint = 4242 } },
				} },
			}, "WHISPER", "Tester")
			advance(3)
			deliver("Faraway")

			check("a character who has left the guild takes their list with them",
				Family.Guild:HeldRecipes(guildKey, "Nervina-FireMaw", smith) == nil)
			check("and one still in it keeps theirs",
				Family.Guild:HeldRecipes(guildKey, "Faraway-FireMaw", smith) ~= nil)
			check("and somebody else's is not dropped on this sender's say-so",
				Family.Guild:HeldRecipes(guildKey, "Otherguy-FireMaw", smith) ~= nil)
		end


		------------------------------------------------------------------------------------------
		-- The guild event log probe
		--
		-- A probe rather than a feature: nothing in Family reads this log, and these checks are
		-- about whether the questions get *asked* properly. The one that matters is the last: the
		-- probe exists to find out what the client actually answers, so it has to print every
		-- value the call returned - including a nil in the middle and a nil at the end, which are
		-- exactly the shapes a table's length operator cannot see.
		------------------------------------------------------------------------------------------

		do
			local heldQuery, heldNum, heldInfo =
				_G.QueryGuildEventLog, _G.GetNumGuildEvents, _G.GetGuildEventInfo

			-- A client with no event log at all, which is what Era may turn out to be. It has to
			-- say so and stop, rather than erroring or claiming an empty log.
			_G.QueryGuildEventLog, _G.GetNumGuildEvents, _G.GetGuildEventInfo = nil, nil, nil

			local mark = #DEFAULT_CHAT_FRAME.messages
			Family.Guild:ProbeEventLog()
			advance(5)

			local said, claimed = false, false
			for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
				local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
				if message:find("no event log to read", 1, true) then said = true end
				if message:find("entries:", 1, true) then claimed = true end
			end
			check("a client with no event log is told so", said)
			check("and is not asked how many entries it has", not claimed)

			-- And one that has it. The middle value is nil and so is the last, because a call
			-- that answers with either is the case this probe is for and the case a length
			-- operator cannot see.
			local asked = 0
			_G.QueryGuildEventLog = function() asked = asked + 1 end
			_G.GetNumGuildEvents = function() return 11 end
			_G.GetGuildEventInfo = function(index)
				if index == 11 then return "join", "Oldest", nil, 4, 2, 1, 0, nil end
				return "quit", "Someone" .. index, nil, 3, 0, 1, 2, nil
			end

			mark = #DEFAULT_CHAT_FRAME.messages
			Family.Guild:ProbeEventLog()

			check("nothing is read before the server has been asked", asked == 1
				and not tostring(DEFAULT_CHAT_FRAME.messages[#DEFAULT_CHAT_FRAME.messages])
					:find("entries:", 1, true), tostring(asked))

			advance(5)

			local count, rows, oldest, kinds, positions = false, 0, false, false, nil
			for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
				local message = tostring(DEFAULT_CHAT_FRAME.messages[index])
				if message:find("entries: 11", 1, true) then count = true end
				if message:find("[1] ", 1, true) then
					rows = rows + 1
					positions = message
				end
				if message:find("2:Someone", 1, true) then rows = rows + 1 end
				if message:find("2:Oldest", 1, true) then oldest = true end
				if message:find("kinds of event", 1, true)
					and message:find("quit x10", 1, true)
					and message:find("join x1", 1, true) then kinds = true end
			end

			check("a client that has one says how many entries came back", count)
			check("and prints the newest few of them", rows > 1, tostring(rows))
			check("and the far end as well, because how far back it goes is the question",
				oldest)
			check("and counts every kind of event in the whole log, not only the ones shown",
				kinds)

			-- The one that is the point of the whole exercise.
			check("and prints every value the call returned, nils in the middle and at the end",
				positions ~= nil and positions:find("3:nil", 1, true) ~= nil
					and positions:find("8:nil", 1, true) ~= nil,
				tostring(positions))

			-- With the type beside each, because "3" and "3" are a number and a string on
			-- different clients and the difference is what a reader of DATASOURCES needs.
			check("with the type of each beside it",
				positions ~= nil and positions:find("(string)", 1, true) ~= nil
					and positions:find("(number)", 1, true) ~= nil)

			_G.QueryGuildEventLog, _G.GetNumGuildEvents, _G.GetGuildEventInfo =
				heldQuery, heldNum, heldInfo
		end

		------------------------------------------------------------------------------------
		-- Leaving, which is what Forget is for and what nothing called it for
		------------------------------------------------------------------------------------

		check("we are holding something for this guild",
			next(Family.Guild:Known(guildKey)) ~= nil)

		local realGuildInfo = GetGuildInfo
		GetGuildInfo = function() return "Somewhere Else", "Member", 3 end
		Family.Database:SetMeta(Family:CurrentMember(), { guild = "Somewhere Else" })
		Family.Database:SetMeta("Smith-FireMaw", { guild = "Somewhere Else" })

		-- The half that matters more, and the reason this is decided from our own records
		-- rather than from whichever guild is being stood in: a player with an alt in each
		-- of two guilds is ordinary, and dropping the other one's records on a login would
		-- be this feature eating a grid nobody withdrew.
		Family.Guild:ForgetLeft()
		check("a guild another of our characters is still in is not forgotten",
			next(Family.Guild:Known(guildKey)) ~= nil)

		Family.Database:SetMeta("Backup-FireMaw", { guild = "Somewhere Else" })
		Family.Database:SetMeta("Oldtimer-FireMaw", { guild = "Somewhere Else" })
		Family.Database:SetMeta("Poisoner-FireMaw", { guild = "Somewhere Else" })

		local dropped = Family.Guild:ForgetLeft()
		check("a guild none of them is in any more is forgotten",
			next(Family.Guild:Known(guildKey)) == nil, table.concat(dropped, ", "))
		check("and so is who in it we had heard from",
			Family.Guild:HeardFrom(guildKey, "Faraway") == nil)
		-- The grid goes with it. A grant said *this guild may see this*, and rejoining a
		-- year later should present an empty grid rather than resume sharing with whoever
		-- is in it by then.
		check("and so is the grid that was ticked for it",
			Family.Guild:Shares(guildKey, "Smith-FireMaw", smith) == false)

		-- And the rule, rather than one more panel that happens to obey it.
		--
		-- Every box any panel has drawn for somebody to tick, swept together: shown, with a
		-- click hooked to it, and nothing wide sitting over it. Written here because this is
		-- where the fault was found, but deliberately not written about this panel - the
		-- first version of the reachability test was used only where its fault had already
		-- been found, which is exactly why the same fault could be built again a fortnight
		-- later on a different panel.
		do
			local blocked = {}
			for _, f in ipairs(frames) do
				if f.__shown == true and f.__checked ~= nil
					and f.__scripts and f.__scripts.OnClick then
					local over = coveredBy(f)
					if over then
						blocked[#blocked + 1] = tostring(
							(type(f.label) == "table" and f.label.__text) or "a box")
					end
				end
			end
			check("every tick box a panel draws can actually be clicked",
				#blocked == 0, table.concat(blocked, ", "))
		end

		GetGuildInfo = realGuildInfo
		Family.Database:SetMeta(Family:CurrentMember(), { guild = guildName })
		Family.Database:Forget("Smith-FireMaw")
		Family.Database:Forget("Backup-FireMaw")
		Family.Database:Forget("Oldtimer-FireMaw")
		Family.Database:Forget("Poisoner-FireMaw")
		Family.Database:Forget("Faraway-FireMaw")
	end

	-- Off means off in both directions at once.
	Family.Guild:SetEnabled(false)
	sent = {}
	check("switched off, announcing does nothing",
		Family.Guild:Announce("a check") == false and #sent == 0)
	check("and asking for an update says so rather than appearing to work",
		select(1, Family.Guild:Refresh("a check")) == false)

	Family.UI:ShowTab("guild")
	check("and the panel says it is off rather than looking empty",
		visibleText("switched off"))

	Family.Guild:SetEnabled(true)
	ours = FamilyDB.guild
end)()

--------------------------------------------------------------------------------------------
-- The pictures on the tab strip
--
-- Whether a path exists is exactly what this file cannot answer - that is what
-- `tools/FamilyIconSheet` is for, and why every one of these was looked at on three clients
-- before it was written down. What can be checked is that the strip is internally consistent,
-- and one of these caught a real mistake before it shipped: Summary and Wide Family were
-- first given the same picture, and a strip with two rows alike has stopped being readable by
-- icon, which is most of what the icons are for.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- One realm, two sides
--
-- Two characters on one realm on opposite sides share nothing an alt manager is asked about:
-- different auction house, different mail, different everything. So a realm holding both is
-- split, with a subtotal each. The half that matters as much is the other one - a realm with
-- one side, or one side filtered away, must not grow a heading over every member and a
-- subtotal identical to the total under it.
--------------------------------------------------------------------------------------------

print()
print("sides within a realm")

;(function()
	Family.UI:ShowTab("summary")
	clickButton("Overview")

	local function sideHeadingShowing()
		local alliance = _G.FACTION_ALLIANCE or "Alliance"
		for _, f in ipairs(frames) do
			if f.__shown == true and f.cells then
				local first = f.cells[1]
				if type(first.__text) == "string"
					and first.__text:find(alliance, 1, true) then
					return true
				end
			end
		end
		return false
	end

	-- Both sides are on this realm by now: the members made further up put one on each.
	FamilyDB.ui = FamilyDB.ui or {}
	FamilyDB.ui.factions = nil
	Family.UI:Refresh()
	-- Made here rather than borrowed from what earlier sections left behind, for the reason
	-- the Wide Family block says out loud: a check that depends on which members survived
	-- the tests before it passes or fails according to what was tested, not what is true.
	-- One of each side, and one whose side was never recorded.
	Family.Database:SetMeta("Novice-FireMaw", { realm = "Fire Maw", faction = "Alliance" })
	Family.Database:SetMeta(Family:CurrentMember(), { realm = "Fire Maw", faction = "Horde" })
	Family.UI:Refresh()

	check("a realm holding both sides is split into them", sideHeadingShowing())

	-- The rows in the order they are drawn. The pool is handed out from the top down and a
	-- frame is only built the first time that line is needed, so the order they were made in
	-- is the order they sit in on screen - and Summary.lua is the only panel that puts cells
	-- in a row, so nothing else is caught by this.
	local function drawnRows()
		local drawn = {}
		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true then drawn[#drawn + 1] = f end
		end
		return drawn
	end

	local function blankRow(row)
		if not row or not row.cells then return false end
		for _, cell in ipairs(row.cells) do
			if type(cell.__text) == "string" and cell.__text ~= "" then return false end
		end
		return true
	end

	-- A side's subtotal and the next side's heading are both one line of large text in the
	-- same colours as the rows around them. Run together they read as one list, so what is
	-- checked is the blank line, not that the headings exist - that is the check above.
	local drawn = drawnRows()
	local hordeAt, totalAt
	for index, row in ipairs(drawn) do
		local first = row.cells[1]
		if not hordeAt and type(first.__text) == "string"
			and first.__text:find("Horde", 1, true) then
			hordeAt = index
		end
		if hordeAt and not totalAt and index > hordeAt then
			for _, cell in ipairs(row.cells) do
				if type(cell.__text) == "string"
					and cell.__text:find("Total", 1, true) then
					totalAt = index
					break
				end
			end
		end
	end

	check("the second side starts a line clear of the first side's figures",
		hordeAt ~= nil and blankRow(drawn[hordeAt - 1]),
		tostring(hordeAt))
	check("and the realm's own total is a line clear of the last side's",
		totalAt ~= nil and blankRow(drawn[totalAt - 1]),
		tostring(totalAt))

	-- With one side switched off there is nothing left to divide, and the divider goes -
	-- including for the member whose side was never recorded, who is not a third faction.
	FamilyDB.ui.factions = { Alliance = false }
	Family.UI:Refresh()
	check("and filtering one away takes the headings with it", not sideHeadingShowing())

	FamilyDB.ui.factions = nil
	Family.UI:Refresh()
end)()

--------------------------------------------------------------------------------------------
-- When an id is not enough
--
-- Family stores ids, and for almost everything an id is the whole truth. A random-enchantment
-- item is the exception, and in Classic it is not a small one: "Bloodscale Pauldrons of the
-- Eagle" is one item id wearing a suffix, and the suffix is where its entire stat line lives.
-- Asked by id alone the client answers about the generic item and prints "<Random
-- enchantment>" where the stats should be, which describes nothing anybody owns.
--------------------------------------------------------------------------------------------

print()
print("items an id does not describe")

;(function()
	local plain = "|cff9d9d9d|Hitem:2589:0:0:0:0:0:0:0|h[Linen Cloth]|h|r"
	local suffixed = "|cff1eff00|Hitem:14155:0:0:0:0:0:-9:1234:60|h[Pauldrons of the Eagle]|h|r"
	local enchanted = "|cff1eff00|Hitem:14155:2504:0:0:0:0:0:0|h[Pauldrons]|h|r"

	check("an ordinary item is left as an id and nothing else",
		Family:ItemString(plain) == nil, tostring(Family:ItemString(plain)))
	check("one with a random-enchantment suffix keeps its string",
		Family:ItemString(suffixed) == "item:14155:0:0:0:0:0:-9:1234:60",
		tostring(Family:ItemString(suffixed)))
	check("and so does one somebody enchanted",
		Family:ItemString(enchanted) == "item:14155:2504:0:0:0:0:0:0",
		tostring(Family:ItemString(enchanted)))

	-- The suffix is negative, and the pattern has to accept a minus sign. Without it the
	-- match stopped at the dash and handed back a truncated string that no longer described
	-- the item - which is worse than not storing one, because it looks like it worked.
	check("the negative suffix survives being read",
		(Family:ItemString(suffixed) or ""):find("-9", 1, true) ~= nil)

	check("nothing at all answers nothing", Family:ItemString(nil) == nil)
	check("and so does something that is not a link", Family:ItemString("hello") == nil)
end)()

--------------------------------------------------------------------------------------------
-- Sending you somewhere, and getting out of the way
--
-- Family sits above the game's own panels, and strata beats click order: a quest log opened
-- from here cannot be brought in front of Family by clicking it, however many times. So
-- Family closes instead of lying on top of the thing you clicked to look at.
--------------------------------------------------------------------------------------------

print()
print("opening one of the game's own windows")

;(function()
	Family.UI:Show()
	check("the window is open to begin with", Family.UI:IsShown())

	Family.UI:StepAside()
	check("and stepping aside closes it", not Family.UI:IsShown())

	-- Twice in a row must be harmless: two clicks land on two rows often enough.
	check("stepping aside again does nothing at all",
		pcall(Family.UI.StepAside, Family.UI) and not Family.UI:IsShown())

	Family.UI:Show()
end)()

--------------------------------------------------------------------------------------------
-- Opening on the panel you chose
--
-- Chosen rather than inferred. Reopening wherever you happened to be last is a different thing
-- and the wrong one: go to a second panel, close the window, and it has quietly moved your
-- home - which is what somebody who wants to land on the same screen every time did not ask
-- for.
--
-- Asked of UI:StartingTab rather than by closing and reopening: closing does not forget which
-- tab is up, so within one session it already comes back where it was. What this decides is
-- the first opening after a login, and no check can stage one.
--------------------------------------------------------------------------------------------

print()
print("opening on the panel you chose")

;(function()
	FamilyDB.ui = FamilyDB.ui or {}
	local wasOn, wasHome = FamilyDB.ui.useDefaultPanel, FamilyDB.ui.defaultPanel

	Family.UI:SetUsesDefaultPanel(false)
	FamilyDB.ui.defaultPanel = nil

	Family.UI:Show()
	Family.UI:ShowTab("guild")

	check("it is off in a database nobody has touched",
		Family.UI:UsesDefaultPanel() == false)
	check("and being on a panel does not make it home",
		Family.UI:DefaultPanel() == nil)
	check("so a fresh window opens on the first panel",
		Family.UI:StartingTab() == "summary", tostring(Family.UI:StartingTab()))

	-- The star is the whole of the marking, and it is not there to be clicked while the
	-- switch is off: nobody who has not asked for this should have to look at nine stars.
	local strip = Family.UI:TabButtons()
	check("and no star is offered on any panel",
		strip.guild.star.__shown == false,
		"a star showing while the switch is off")

	Family.UI:SetUsesDefaultPanel(true)
	check("switched on, the stars appear", strip.guild.star.__shown == true)

	-- Starring one is a decision, and it is the only thing that moves home.
	strip.guild.star.__scripts.OnClick(strip.guild.star)
	check("starring a panel makes it home", Family.UI:DefaultPanel() == "guild",
		tostring(Family.UI:DefaultPanel()))
	check("and a fresh window would open there",
		Family.UI:StartingTab() == "guild", tostring(Family.UI:StartingTab()))

	-- The fault in the version this replaces: walking to another panel must not move it.
	Family.UI:ShowTab("summary")
	check("but walking to another panel does not", Family.UI:DefaultPanel() == "guild",
		tostring(Family.UI:DefaultPanel()))
	check("and home is still where it was", Family.UI:StartingTab() == "guild")

	-- Two of the tabs come and go with the features they belong to, so a starred name may no
	-- longer answer - and opening on nothing at all is worse than opening on the first thing.
	FamilyDB.ui.defaultPanel = "a panel that was removed"
	check("a panel that is no longer there falls back to the first",
		Family.UI:StartingTab() == "summary", tostring(Family.UI:StartingTab()))

	-- Starring the summary takes the set of columns it is showing, because "Activity" and
	-- "Currencies" are as different as two panels are.
	Family.UI:ShowTab("summary")
	clickButton("Activity")
	strip.summary.star.__scripts.OnClick(strip.summary.star)
	check("starring the summary takes the columns it is showing",
		Family.UI:DefaultSet() == "activity", tostring(Family.UI:DefaultSet()))
	check("and the star is filled while those columns are the ones showing",
		Family.UI:LookingAtHome("summary"))
	-- Drawn, not merely decided: the star says which panel is home by how solid it is, and
	-- a rule nothing draws is a rule nobody can see.
	check("and drawn solid rather than merely known to be home",
		strip.summary.star.__alpha == 1, tostring(strip.summary.star.__alpha))
	check("while every other panel's is faint",
		strip.guild.star.__alpha ~= 1, tostring(strip.guild.star.__alpha))

	-- Changing your mind is clicking a different set and starring again, and the star going
	-- hollow is the only thing that says so. A filled star on a screen that clicking would
	-- change reads as a button that does nothing.
	clickButton("Bags")
	check("changing the columns leaves it hollow, which is the invitation",
		Family.UI:LookingAtHome("summary") == false)
	check("and the star goes faint the moment they change",
		strip.summary.star.__alpha ~= 1, tostring(strip.summary.star.__alpha))

	strip.summary.star.__scripts.OnClick(strip.summary.star)
	check("and starring again moves home to the new columns",
		Family.UI:DefaultSet() == "bags", tostring(Family.UI:DefaultSet()))
	check("with the star filled again", Family.UI:LookingAtHome("summary"))

	-- And off again with the same click. A star you can put on and not take off is a
	-- decision that has to be undone somewhere else, and somewhere else is not where it was
	-- made.
	strip.summary.star.__scripts.OnClick(strip.summary.star)
	check("clicking the filled star takes it off again",
		Family.UI:DefaultPanel() == nil, tostring(Family.UI:DefaultPanel()))
	check("and with nothing starred it opens on the first panel",
		Family.UI:StartingTab() == "summary", tostring(Family.UI:StartingTab()))

	strip.summary.star.__scripts.OnClick(strip.summary.star)

	Family.UI:SetUsesDefaultPanel(false)
	check("switched off, it opens on the first panel again",
		Family.UI:StartingTab() == "summary")
	check("but what was starred is kept, so switching back on lands where it did",
		Family.UI:DefaultPanel() == "summary", tostring(Family.UI:DefaultPanel()))

	FamilyDB.ui.useDefaultPanel, FamilyDB.ui.defaultPanel = wasOn, wasHome
	Family.UI:RefreshStars()
	Family.UI:ShowTab("summary")
end)()

--------------------------------------------------------------------------------------------
-- The letters behind the figure that counts them
--
-- A number saying "3" answers how much and never what, and the mailbox is the one screen a
-- player cannot open from somewhere else - the character it belongs to is not the one being
-- played. So the figure unfolds into the letters, under the member and on the widest column,
-- because a sender's name does not fit in the sixty pixels the count needs.
--------------------------------------------------------------------------------------------

print()
print("what is in the post")

;(function()
	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton("Activity")

	-- The rows that are armed to open something, which is the question this is about: a
	-- count of nought must not be, or a player learns the figure is not a button.
	local function openers()
		local found = {}
		for _, f in ipairs(frames) do
			if f.mailHit and f.__shown == true and f.mailHit.__shown == true
				and f.mailHit.__scripts and f.mailHit.__scripts.OnClick then
				found[#found + 1] = f
			end
		end
		return found
	end

	local armed = openers()
	check("the figure counting somebody's letters can be clicked", #armed > 0,
		tostring(#armed) .. " rows")

	-- And only where there is something behind it. A nought that opens nothing teaches a
	-- player that the figure is not a button, which costs them the ones that are.
	local members = 0
	for _, f in ipairs(frames) do
		if f.__shown == true and f.memberKey and f.cells then members = members + 1 end
	end
	check("and only on the members who have any", #armed < members,
		tostring(#armed) .. " armed of " .. tostring(members) .. " members")

	local before = 0
	for _, f in ipairs(frames) do
		if f.cells and f.__shown == true then before = before + 1 end
	end

	-- Gold on the letter that is actually going to be drawn, rather than trusting the
	-- fixture to have put it on one that has not expired by the time this runs.
	do
		local payload = Family.Database:Payload(armed[1].memberKey) or {}
		-- Every one of them, because which are still live depends on how far the clock
		-- has been wound on by the checks before this, and a letter that has expired is
		-- not drawn at all.
		for _, letter in ipairs((payload.mail or {}).letters or {}) do
			letter.money = 12345
		end
	end

	armed[1].mailHit.__scripts.OnClick(armed[1].mailHit)

	local after = 0
	for _, f in ipairs(frames) do
		if f.cells and f.__shown == true then after = after + 1 end
	end

	check("and clicking it unfolds the letters under that member", after > before,
		tostring(after) .. " rows against " .. tostring(before))
	-- The sender, read off the row the summary drew rather than swept out of the client.
	-- This asked for "Auctioneer" and the panel writes "Auction House"; it passed because
	-- the development icon sheet says the first of those somewhere, which is the whole
	-- reason this reads rows now.
	check("naming who each one is from", drawnText("Auction House"))

	-- What is in a letter is the thing somebody opened it to find out, and "2 items" is not
	-- an answer to that. The pictures are the answer, and they need a taller line than a row
	-- of figures does - an icon small enough for eighteen pixels is one nobody recognises.
	do
		local drawn, tall, moneyed = 0, 0, 0
		for _, f in ipairs(frames) do
			if f.attach and f.__shown == true then
				for _, slot in ipairs(f.attach) do
					if slot.__shown == true then drawn = drawn + 1 end
				end
				if (f.__height or 0) > 18 then tall = tall + 1 end
				-- Shown *and* saying something. A font string records being made
				-- visible in a different field from a frame, and asking a font string
				-- the frame's question gets nil for ever - while asking only what it
				-- says passes on one that was written and never shown.
				if f.attachMoney and f.attachMoney.__visible == true
					and type(f.attachMoney.__text) == "string"
					and f.attachMoney.__text ~= "" then
					moneyed = moneyed + 1
				end
			end
		end

		check("with what is attached to it drawn rather than counted", drawn > 0,
			tostring(drawn) .. " attachments")
		check("on a line tall enough to make a picture out", tall > 0,
			tostring(tall) .. " taller lines")
		check("and the gold in it said beside them", moneyed > 0,
			tostring(moneyed) .. " with money")
	end

	armed[1].mailHit.__scripts.OnClick(armed[1].mailHit)

	local shut, leftBehind = 0, 0
	for _, f in ipairs(frames) do
		if f.cells and f.__shown == true then
			shut = shut + 1

			-- Rows come out of a pool, so a letter's pictures have to be put away when
			-- one is handed out again - or they sit under a member who has no post.
			for _, slot in ipairs(f.attach or {}) do
				if slot.__shown == true then leftBehind = leftBehind + 1 end
			end
			if f.attachMoney and f.attachMoney.__visible == true then
				leftBehind = leftBehind + 1
			end
		end
	end
	check("and clicking it again folds them away", shut == before,
		tostring(shut) .. " against " .. tostring(before))
	check("leaving no pictures behind on the rows they came out of",
		leftBehind == 0, tostring(leftBehind) .. " left over")
end)()

--------------------------------------------------------------------------------------------
-- What the letters do when the window shuts, and whose letters they are
--
-- Two properties of the same unfold, written into the backlog on 2026-09-05 as owed rather
-- than closed with a check that reads the panel's source and calls a line of code proof.
--
-- **The fold.** `UI:FoldEverything` runs every registered folder and counts them, so a panel
-- that never registered one is caught - and nothing said whether the summary's folder clears
-- the right thing. `openMail` and `openBoon` are file locals in `Family_UI/Summary.lua`, so
-- there is no reading them from here at all: the only way in is the rows they cause to be
-- drawn, which means finding the figure on a drawn row, clicking it, and counting.
--
-- **The read.** The same unfold asked `Family.Database:Payload` for a member whose key may be
-- borrowed, so a sibling's letters drew none and said nothing about why - L-052, the class
-- entry 1 of the backlog turned up. That was fixed and the mutation putting it back failed
-- nothing, because every check of this unfold was on a member of our own.
--------------------------------------------------------------------------------------------

print()
print("the letters, put away with everything else")

;(function()
	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton("Activity")

	local function rows()
		local drawn = 0
		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true then drawn = drawn + 1 end
		end
		return drawn
	end

	-- Found by what the row carries rather than by where it sits in `frames`: rows come out
	-- of a pool that grows, so the order they were created in is not the order they are
	-- drawn in, and walking the list to find "the next one" has been wrong twice.
	local function armed(hit)
		for _, f in ipairs(frames) do
			local button = f[hit]
			if button and f.__shown == true and button.__shown == true
				and button.__scripts and button.__scripts.OnClick then
				return f
			end
		end
	end

	local shut = rows()
	local opener = armed("mailHit")
	check("a member's letters can be opened", opener ~= nil)

	opener.mailHit.__scripts.OnClick(opener.mailHit)
	local open = rows()
	check("and the figure unfolds them", open > shut,
		tostring(open) .. " rows against " .. tostring(shut))

	-- Nothing here counts the folders. That folders run at all is pinned where they are
	-- registered, and a check that a *number* came back would have passed with this panel's
	-- folder deleted - measured, and it did.
	Family.UI:FoldEverything()
	Family.UI:Refresh()
	check("and putting everything away takes the letters with it", rows() == shut,
		tostring(rows()) .. " against " .. tostring(shut))

	-- The other half of what that folder clears, and it is a separate local for a reason:
	-- opening one must not shut the other, so a folder that cleared only the letters would
	-- leave a boon unfolded behind a closed window and nothing above would notice.
	clickButton("Miscellaneous")

	local boonKey = opener.memberKey
	Family.Database:SetMeta(boonKey,
		{ banked = { { icon = 134153, minutes = 120 } } })
	Family.UI:Refresh()

	local shutBoon = rows()
	local boonRow = armed("boonHit")
	check("a member's banked boon can be opened too", boonRow ~= nil)

	boonRow.boonHit.__scripts.OnClick(boonRow.boonHit)
	check("and the Chrono figure unfolds it", rows() > shutBoon,
		tostring(rows()) .. " rows against " .. tostring(shutBoon))

	Family.UI:FoldEverything()
	Family.UI:Refresh()
	check("which the same fold puts away as well", rows() == shutBoon,
		tostring(rows()) .. " against " .. tostring(shutBoon))

	Family.Database:SetMeta(boonKey, { banked = Family.CLEAR })
	clickButton("Overview")
	Family.UI:Refresh()
end)()

print()
print("a linked family's letters, unfolded on the summary")

-- The third of the three `Family.Database:Payload` calls L-052 found. The other two are drawn
-- end to end by checks written the day they were fixed; this one was left covered by reading
-- the line rather than by measuring it, and the backlog says so out loud.
;(function()
	local held = FamilyDB.wide
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["postfam"] = { name = "Postal-Thunderstrike", grants = {}, siblings = {},
			members = {
				["Postal-Thunderstrike"] = {
					meta = { name = "Postal", realm = "Thunderstrike",
						classFile = "MAGE", level = 60, faction = "Alliance",
						mailCount = 2, mailSeen = time(),
						mailExpiresBy = time() + 20 * 86400 },
					payload = { mail = { seen = time(), letters = {
						{ sender = "Borrowed Postmaster", subject = "Ashes of Al'ar",
							expiresBy = time() + 20 * 86400 },
						{ sender = "Borrowed Auctioneer", subject = "Sold",
							money = 4200, expiresBy = time() + 25 * 86400 },
					} } },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("postfam", "Postal-Thunderstrike", true)

	local key = Family.Wide:BorrowedKey("postfam", "Postal-Thunderstrike")

	-- Said out loud, because a check that only asserted the first would pass with the bug
	-- back: `UI:Payload` was always right, it was simply not the one being called.
	check("a sibling's post is there when asked the way a panel asks",
		(Family.UI:Payload(key) or {}).mail ~= nil)
	check("and absent when asked of the database, which is the trap",
		Family.Database:Payload(key) == nil)

	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton("Activity")
	Family.UI:Refresh()

	check("the sibling is drawn on the set that counts letters", drawnText("Postal"))

	local row
	for _, f in ipairs(frames) do
		if f.__shown == true and f.memberKey == key and f.mailHit
			and f.mailHit.__shown == true and f.mailHit.__scripts
			and f.mailHit.__scripts.OnClick then
			row = f
		end
	end
	check("with the figure counting their letters armed", row ~= nil)

	check("and nothing of theirs unfolded before it is clicked",
		drawnText("Borrowed Postmaster") == false)

	row.mailHit.__scripts.OnClick(row.mailHit)

	check("clicking it names who wrote to them", drawnText("Borrowed Postmaster"))
	check("and what the letter is about", drawnText("Ashes of Al'ar"))
	check("every letter, not the first of them", drawnText("Borrowed Auctioneer"))

	Family.UI:FoldEverything()
	Family.UI:Refresh()
	check("and a borrowed member's letters fold away like our own",
		drawnText("Borrowed Postmaster") == false)

	Family.Wide:SetSibling("postfam", "Postal-Thunderstrike", false)
	FamilyDB.wide = held
	clickButton("Overview")
	Family.UI:Refresh()
end)()

--------------------------------------------------------------------------------------------
-- A cooldown belonging to a profession nobody has any more
--
-- `payload.professions` keeps every profession Family has ever read for a member, which is
-- right: somebody who drops enchanting and takes it up again has not lost their recipe list.
-- The cooldowns in meta are a different matter. One out of a profession they no longer have
-- is a reminder about something they cannot do, and it never expires by itself - the entry is
-- only rewritten when that profession's window is opened, and it never will be.
--------------------------------------------------------------------------------------------

print()
print("cooldowns from a profession that has been dropped")

;(function()
	local key = Family:CurrentMember()

	local payload = Family.Database:Payload(key) or {}
	payload.professions = {
		Blacksmithing = { recipes = { { name = "Runed Copper Breastplate" } } },
		Alchemy = { recipes = {
			{ name = "Transmute: Arcanite", readyAt = time() - 86400 },
		} },
	}
	Family.Database:SetPayload(key, payload)

	-- Blacksmithing is theirs; Alchemy was, and is not.
	Family.Database:SetMeta(key, { skills = { [164] = { name = "Blacksmithing", rank = 287, maxRank = 375 } } })

    -- Recorded the way the scanner records it, which is what the guard has to survive.
	local cooldowns = {}
	for name, entry in pairs(payload.professions) do
		if (Family.Database:Meta(key).skills or {})[name] then
			for _, recipe in ipairs(entry.recipes or {}) do
				if recipe.readyAt then
					cooldowns[#cooldowns + 1] = { name = recipe.name, profession = name,
						readyAt = recipe.readyAt }
				end
			end
		end
	end

	check("a dropped profession's cooldown is not carried into meta", #cooldowns == 0,
		tostring(#cooldowns))

	-- And with the profession back, it counts again: the rule is "not theirs", not "old".
	Family.Database:SetMeta(key, { skills = {
		Blacksmithing = { rank = 287, maxRank = 375 },
		Alchemy = { rank = 300, maxRank = 300 },
	} })
	Family.Database:SetMeta(key, { craftCooldowns = {
		{ name = "Transmute: Arcanite", profession = "Alchemy", readyAt = time() - 86400 },
	} })

	local ready = Family.Cooldowns:Summarise(Family.Database:Meta(key))
	check("while one they still have is reported ready", ready == 1, tostring(ready))

	-- And it can be named, which is the only way to see one that should not be there.
	local named
	for _, entry in ipairs(Family.Cooldowns:For(Family.Database:Meta(key))) do
		if entry.ready then named = entry.name end
	end
	check("and named rather than only counted", named == "Transmute: Arcanite",
		tostring(named))

	Family.Database:SetMeta(key, { craftCooldowns = Family.CLEAR })
end)()

--------------------------------------------------------------------------------------------
-- A profession cell keeps its numbers
--
-- The cell clips what will not fit and it clips the end, which is where the rank is.
-- "Leatherworking 360/375" came out as "Leatherworking 360/..." - the name survived, which is
-- recognisable from its first letters anyway, and the numbers went, which are not recoverable
-- from anything.
--------------------------------------------------------------------------------------------

print()
print("professions on the summary")

;(function()
	Family.Database:SetMeta("Longname-FireMaw", {
		name = "Longname", realm = "Fire Maw", level = 70, faction = "Horde",
		skills = {
			Leatherworking = { rank = 360, maxRank = 375, recipesSeen = time() },
			Mining = { rank = 375, maxRank = 375, recipesSeen = time() },
		},
	})

	Family.UI:ShowTab("summary")

	-- The last match, not the first. "Professions" is the name of a tab as well as of a
	-- column set, and the tab is built at load while the set button is built the first time
	-- the summary is drawn - so the first match is the tab, and clicking it walks away from
	-- the panel this is about.
	local function clickLast(label)
		local found
		for _, f in ipairs(frames) do
			if type(f.__text) == "string" and f.__text:find(label, 1, true)
				and f.__scripts.OnClick then
				found = f
			end
		end
		if found then fireClick(found) end
		return found ~= nil
	end

	check("the professions column set can be reached", clickLast("Professions"))

	local shown
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find("360", 1, true)
			and f.__text:find("375", 1, true) and f.__visible ~= false then
			shown = f.__text
		end
	end

	check("a long profession keeps both of its numbers", shown ~= nil, tostring(shown))
	check("and gives up the end of its name instead",
		shown ~= nil and shown:find("Leatherwor", 1, true) ~= nil, tostring(shown))

	-- A short one is not touched at all.
	local mining
	for _, f in ipairs(fontStrings) do
		if type(f.__text) == "string" and f.__text:find("Mining", 1, true)
			and f.__visible ~= false then
			mining = f.__text
		end
	end
	check("a short one is left exactly as it was",
		mining ~= nil and mining:find("Mining |", 1, true) ~= nil, tostring(mining))

	Family.Database:Forget("Longname-FireMaw")
end)()

--------------------------------------------------------------------------------------------
-- Crafting cooldowns, grouped and shown
--
-- Thirty transmutes share one timer, and listing thirty of them answers nothing. Family works
-- the grouping out from the data - recipes of one profession carrying the same moment are on
-- the same timer - rather than from a table somebody would have to keep per expansion.
--------------------------------------------------------------------------------------------

print()
print("crafting cooldowns")

;(function()
	local key = "Alchemist-FireMaw"

	-- Three transmutes on one timer, a mooncloth on its own, and a salt shaker that is an
	-- item rather than a recipe and belongs to leatherworking all the same.
	--
	-- 15846 is the real Salt Shaker, not a stand-in. It has to be: the panel now takes an
	-- item cooldown only where the generated table says a profession makes the maker and uses
	-- what it makes, so an invented id would be filtered out and every check below would be
	-- testing a member with no cooldowns at all.
	--
	-- **Filed by skill line id, which is how the scanner really files them.** This fixture
	-- said `profession = "Alchemy"` for a year and every check below passed, while the panel
	-- drew "?" over the transmute column on every real client: the payload is keyed by id,
	-- the label became the number 171, and the summary's `shortened` returns "?" for anything
	-- that is not a string. The check was modelled on the instance somebody typed rather than
	-- on what the recorder writes, which is the failure the top of LESSONS.md names.
	--
	-- 171 is Alchemy, 197 Tailoring, 165 Leatherworking.
	Family.Database:SetMeta(key, {
		name = "Alchemist", realm = "Fire Maw", level = 70, faction = "Horde",
		craftCooldowns = {
			{ name = "Transmute: Arcanite", profession = 171, readyAt = time() + 3600 },
			{ name = "Transmute: Earth to Water", profession = 171,
				readyAt = time() + 3600 },
			{ name = "Transmute: Air to Fire", profession = 171,
				readyAt = time() + 3600 },
			{ name = "Bolt of Imbued Netherweave", profession = 197 },
		},
		itemCooldowns = { { id = 15846, readyAt = time() + 7200 } },
		cooldownItems = { [15846] = 165 },
	})

	local kinds = Family.Cooldowns:Crafting(Family.Database:Meta(key))

	local byLabel = {}
	for _, kind in ipairs(kinds) do byLabel[kind.label] = kind end

	-- One entry for the lot of them, named for the profession rather than for whichever
	-- transmute happened to sort first.
	check("recipes sharing one timer become one entry", byLabel.Alchemy ~= nil)
	check("and it says how many it stands for",
		byLabel.Alchemy and byLabel.Alchemy.count == 3,
		byLabel.Alchemy and tostring(byLabel.Alchemy.count))
	check("and that it is not available yet",
		byLabel.Alchemy and byLabel.Alchemy.ready == false)

	-- A cooldown of one keeps its own name: "Tailoring" would be less, not more.
	check("a cooldown nothing shares keeps the recipe's name",
		byLabel["Bolt of Imbued Netherweave"] ~= nil)
	check("and a recipe with no moment on it is available",
		byLabel["Bolt of Imbued Netherweave"]
			and byLabel["Bolt of Imbued Netherweave"].ready == true)

	-- The salt shaker case: an item's cooldown, attributed to the profession that makes it.
	local shaker
	for _, kind in ipairs(kinds) do
		if kind.item == 15846 then shaker = kind end
	end
	check("an item on cooldown is one of these too", shaker ~= nil)
	check("and it answers to the profession that makes it",
		shaker and shaker.profession == 165,
		shaker and tostring(shaker.profession))

	-- Every label is a **word**, whatever the profession was recorded as. A number reaching
	-- the summary is drawn as "?", which is how this hid: the fault produced a plausible
	-- placeholder instead of an error, on a column heading nobody could argue with.
	for _, kind in ipairs(kinds) do
		check("the label for " .. tostring(kind.key) .. " is something a player can read",
			type(kind.label) == "string", type(kind.label))
	end

	-- And a member recorded under the word rather than the id - an older record, or a client
	-- with no skill line ids - still reads as that profession rather than as the raw word in
	-- whatever language it was written in.
	Family.Database:SetMeta("Elder-FireMaw", { name = "Elder", realm = "Fire Maw",
		craftCooldowns = {
			{ name = "Transmute: Arcanite", profession = "Alchemy", readyAt = time() + 60 },
			{ name = "Transmute: Mithril", profession = "Alchemy", readyAt = time() + 60 },
		} })
	local older = Family.Cooldowns:Crafting(Family.Database:Meta("Elder-FireMaw"))
	check("a profession recorded as a word is still labelled with one",
		older[1] and older[1].label == "Alchemy", older[1] and tostring(older[1].label))
	Family.Database:Forget("Elder-FireMaw")

	-- The label is the reader's word, not the scanner's.
	--
	-- A family is played across clients, and a recipe's name is stored as the word the client
	-- that scanned it wrote down. A Mooncloth recorded on a French client was headed "Etoffe
	-- lunaire" on an English panel, beside columns saying Alchemy and Salt Shaker. Reported
	-- from play. The ids were recorded beside the word for exactly this (§2.1).
	Family.Database:SetMeta("Abroad-FireMaw", { name = "Abroad", realm = "Fire Maw",
		craftCooldowns = { { name = "Etoffe lunaire", profession = 197, itemID = 2589,
			readyAt = time() + 3600 } } })
	local abroad = Family.Cooldowns:Crafting(Family.Database:Meta("Abroad-FireMaw"))
	check("a recipe recorded in another language is labelled in this one",
		abroad[1] and abroad[1].label == "Linen Cloth",
		abroad[1] and tostring(abroad[1].label))

	-- And where the client cannot name it, the recorded word beats nothing at all.
	Family.Database:SetMeta("Abroad-FireMaw", { craftCooldowns = {
		{ name = "Etoffe lunaire", profession = 197, itemID = 999999,
			readyAt = time() + 3600 } } })
	local unnamed = Family.Cooldowns:Crafting(Family.Database:Meta("Abroad-FireMaw"))
	check("and one the client cannot name keeps the word it was recorded with",
		unnamed[1] and unnamed[1].label == "Etoffe lunaire",
		unnamed[1] and tostring(unnamed[1].label))
	Family.Database:Forget("Abroad-FireMaw")

	-- A cooldown whose recipe name never made it to disk falls back to the profession, and
	-- that fallback has to be a word too. It is the same fault one line over, and it survived
	-- a mutation until this fixture existed: every other cooldown here carries a name, so the
	-- fallback was never reached.
	Family.Database:SetMeta("Nameless-FireMaw", { name = "Nameless", realm = "Fire Maw",
		craftCooldowns = { { profession = 171, readyAt = time() + 60 } } })
	local nameless = Family.Cooldowns:Crafting(Family.Database:Meta("Nameless-FireMaw"))
	check("a cooldown with no recipe name falls back to a word, not an id",
		nameless[1] and nameless[1].label == "Alchemy",
		nameless[1] and tostring(nameless[1].label))
	Family.Database:Forget("Nameless-FireMaw")

	-- Available first: it is the half anybody opened the panel for.
	check("what is available sorts to the front", kinds[1] and kinds[1].ready == true)

	-- And the column set draws it.
	Family.UI:ShowTab("summary")
	local function clickLast(label)
		local found
		for _, f in ipairs(frames) do
			if type(f.__text) == "string" and f.__text:find(label, 1, true)
				and f.__scripts.OnClick then
				found = f
			end
		end
		if found then fireClick(found) end
		return found ~= nil
	end

	check("the summary has a set for them", clickLast("Crafting"))
	check("what is available says so", visibleText("ready"))

	-- An item whose cooldown has come back is shown as ready, and used to vanish instead.
	-- The bag scan dropped a ready item entirely, so the panel could only ever show a salt
	-- shaker while it was unavailable - reported from play, and the same complaint as
	-- "it shows only what is on cooldown".
	Family.Database:SetMeta(key, {
		itemCooldowns = { { id = 15846 } },
		cooldownItems = { [15846] = 165 },
	})
	local back = Family.Cooldowns:Crafting(Family.Database:Meta(key))
	local idle
	for _, kind in ipairs(back) do
		if kind.item == 15846 then idle = kind end
	end
	check("an item off cooldown is still one of these", idle ~= nil)
	check("and it says it is ready", idle and idle.ready == true,
		tostring(idle and idle.ready))

	-- Per expansion, because a maker that waits on one build does not on another. The salt
	-- shaker is three days on Era, just under three on Burning Crusade and nothing at all on
	-- Mists - and a Mote of Fire is a third of a second on Mists and the "no cooldown"
	-- sentinel on Burning Crusade, which a union carried onto builds where it does not exist.
	-- Reported from play: Mote to Primal is not a cooldown to show on Burning Crusade.
	do
		local heldXpac = Family.Capabilities.expansion
		check("the salt shaker is a crafting cooldown on Era",
			Family.Cooldowns:IsCraftingItem(15846) == true)

		Family.Capabilities.expansion = 2
		check("the salt shaker is one on Burning Crusade too",
			Family.Cooldowns:IsCraftingItem(15846) == true)

		Family.Capabilities.expansion = 5
		check("and not on Mists, where it has no cooldown at all",
			Family.Cooldowns:IsCraftingItem(15846) == false)

		for _, xpac in ipairs { 1, 2, 5 } do
			Family.Capabilities.expansion = xpac
			check("a Mote of Fire is not one on expansion " .. xpac,
				Family.Cooldowns:IsCraftingItem(22574) == false)
		end

		Family.Capabilities.expansion = heldXpac
	end

	-- And an entry already on the record from an older rule is filtered where it is *shown*,
	-- not only where it is written. `cooldownItems` is learned and never pruned, so an item
	-- that qualified once is on disk for good - which is how a Super Snapper FX survived a fix
	-- that only changed what gets recorded.
	Family.Database:SetMeta(key, { itemCooldowns = { { id = 9328 } },
		cooldownItems = { [9328] = 202 } })
	local stale = Family.Cooldowns:Crafting(Family.Database:Meta(key))
	local lingering = false
	for _, kind in ipairs(stale) do
		if kind.item == 9328 then lingering = true end
	end
	check("an entry left on the record by an older rule is not shown", lingering == false)

	-- And it is still not *announced* at login. The panel is a table somebody opened; the
	-- login line is a claim pushed at them, and an item is used out of the bags with nothing
	-- open for Family to see. That difference is deliberate and this holds it.
	local announced = Family.Cooldowns:For(Family.Database:Meta(key))
	local shouted = false
	for _, entry in ipairs(announced) do
		if entry.id == 15846 then shouted = true end
	end
	check("but a ready item is not announced at login", shouted == false)

	-- The recording half, driven through the real bag scan rather than by writing meta.
	-- Slot 3 of the backpack has no cooldown running on it; the item in it is one this
	-- member has been seen with a cooldown on before, which is the only thing that makes
	-- "ready" sayable at all.
	do
		local mine = Family:CurrentMember()
		local held = Family.Database:Meta(mine).cooldownItems
		Family.Database:SetMeta(mine, { cooldownItems = { [15846] = 165 } })

		BAGS[0].items[3] = { 15846, 1 }
		Family.Bags:Scan()

		local recorded
		for _, entry in ipairs(Family.Database:Meta(mine).itemCooldowns or {}) do
			if entry.id == 15846 then recorded = entry end
		end
		check("a bag scan records an item whose cooldown has come back",
			recorded ~= nil and recorded.readyAt == nil,
			tostring(recorded and recorded.readyAt))

		-- A maker nobody has ever been caught mid-cooldown with is still recorded as ready.
		-- The generated table says the salt shaker has a cooldown, so nothing has to be
		-- watched first - which is the difference between the panel and the item tooltip
		-- that was reported: the tooltip named a character as able to make one and said
		-- "ready now" while the panel did not list them at all.
		BAGS[0].items[5] = { 15846, 1 }
		Family.Bags:Scan()
		local shaker
		for _, entry in ipairs(Family.Database:Meta(mine).itemCooldowns or {}) do
			if entry.id == 15846 then shaker = entry end
		end
		check("a salt shaker nobody has watched counting down is still ready",
			shaker ~= nil and shaker.readyAt == nil, tostring(shaker and shaker.readyAt))
		BAGS[0].items[5] = nil

		-- And a Chronoboon Displacer is not. It creates a supercharged one and has an hour's
		-- cooldown, so it is a maker in the generated table - but no profession makes it, and
		-- it turned up as a column on the Crafting panel beside Alchemy. Reported from play.
		BAGS[0].items[6] = { 184937, 1 }
		Family.Bags:Scan()
		local boon = false
		for _, entry in ipairs(Family.Database:Meta(mine).itemCooldowns or {}) do
			if entry.id == 184937 then boon = true end
		end
		check("a Chronoboon is not a crafting cooldown", boon == false)
		BAGS[0].items[6] = nil

		-- Nor is a Super Snapper FX, which a profession *does* make. It has a cooldown and it
		-- makes something, so "crafted by a profession" was not enough to keep it out -
		-- reported from play an hour after the Chronoboon. What it makes is a reagent in
		-- nothing, which is the rule that separates it from the salt shaker.
		BAGS[0].items[6] = { 9328, 1 }
		Family.Bags:Scan()
		local toy = false
		for _, entry in ipairs(Family.Database:Meta(mine).itemCooldowns or {}) do
			if entry.id == 9328 then toy = true end
		end
		check("nor is a Super Snapper FX, whose product feeds nothing", toy == false)
		BAGS[0].items[6] = nil

		-- And an item nobody has ever seen a cooldown on is not invented as ready. Slot 4
		-- holds one this member has no history with, and which the generated table has never
		-- heard of either.
		BAGS[0].items[4] = { 2589, 1 }
		Family.Bags:Scan()
		local invented = false
		for _, entry in ipairs(Family.Database:Meta(mine).itemCooldowns or {}) do
			if entry.id == 2589 then invented = true end
		end
		check("and does not invent one for an item it has never seen counting down",
			invented == false)

		BAGS[0].items[3], BAGS[0].items[4] = nil, nil
		Family.Bags:Scan()
		Family.Database:SetMeta(mine, { cooldownItems = held or Family.CLEAR })
	end

	-- Only the members who have a cooldown at all get a row on this set. A family of thirty
	-- with three alchemists was twenty-seven blank lines.
	Family.Database:SetMeta("Idle-FireMaw", { name = "Idle", realm = "Fire Maw",
		level = 60, faction = "Horde" })
	Family.UI:ShowTab("summary")
	clickLast("Overview") clickLast("Crafting")
	check("a member with no cooldown at all is not listed here",
		visibleText("Idle") == false)
	clickLast("Overview")
	check("but is listed on a set that is about everybody", visibleText("Idle"))
	Family.Database:Forget("Idle-FireMaw")
	clickLast("Crafting")
	check("and what is not says when it comes back", visibleText("1h"))
	check("with the shared one under the profession's name", visibleText("Alchemy"))

	Family.Database:Forget(key)
end)()

print()
print("how many crafting cooldowns a member is announced as having")

-- Reported from play 2026-09-05, off the login line itself: *temps de recharge d'artisanat
-- prêts : Ermete (3), Hooga (3), Nervina, Puzzolente (3)*. The number is how many Family
-- thinks are ready, and three of those four characters had **one** ready timer each - they
-- are alchemists who have learned three transmutes, and the client puts every transmute on
-- one shared cooldown.
--
-- The rule was already written down, over `Crafting`: recipes of one profession sharing a
-- readyAt are one timer, because a timer is the thing somebody can go and do. `Summarise` was
-- walking the flat list instead and counting recipes.
--
-- Nothing caught it because every fixture in this file had one recipe per timer, which is
-- exactly the shape that makes grouped and ungrouped agree. L-054.
;(function()
	local key = "Transmuter-Fire Maw"
	local came = time() - 3600
	local three = {
		{ name = "Transmute: Arcanite", profession = 171, readyAt = came },
		{ name = "Transmute: Air to Fire", profession = 171, readyAt = came },
		{ name = "Transmute: Earth to Water", profession = 171, readyAt = came },
	}

	Family.Database:SetMeta(key, { name = "Transmuter", realm = "Fire Maw",
		classFile = "SHAMAN", level = 60, faction = "Alliance",
		craftCooldowns = three })

	-- Both halves said out loud, because the fault was the two being confused: the record
	-- really does hold three recipes, and what somebody can go and do is one thing.
	local raw = 0
	for _, entry in ipairs(Family.Cooldowns:For(Family.Database:Meta(key))) do
		if entry.ready then raw = raw + 1 end
	end
	check("three transmutes are three recipes on the record", raw == 3, tostring(raw))

	local ready = Family.Cooldowns:Summarise(Family.Database:Meta(key))
	check("and one thing to go and do", ready == 1, tostring(ready))

	-- The login line reads its number from here, and drops it entirely at one - so this is
	-- the difference between "Transmuter (3)" and "Transmuter", which is what was reported.
	local counted
	for _, member in ipairs(Family.Cooldowns:Ready()) do
		if member.key == key then counted = member.count end
	end
	check("so the notice names them with no number after it", counted == 1,
		tostring(counted))

	-- And the other direction, which is what stops this being fixed by always answering one.
	Family.Database:SetMeta(key, { craftCooldowns = {
		{ name = "Transmute: Arcanite", profession = 171, readyAt = came },
		{ name = "Transmute: Air to Fire", profession = 171, readyAt = came },
		{ name = "Mooncloth", profession = 197, readyAt = came },
	} })
	check("two professions ready are two things to go and do",
		Family.Cooldowns:Summarise(Family.Database:Meta(key)) == 2,
		tostring(Family.Cooldowns:Summarise(Family.Database:Meta(key))))

	-- One ready and one still running: the count is about the first and the moment is about
	-- the second, and a grouping that lost the running one would lose the moment with it.
	local later = time() + 7200
	Family.Database:SetMeta(key, { craftCooldowns = {
		{ name = "Transmute: Arcanite", profession = 171, readyAt = came },
		{ name = "Transmute: Air to Fire", profession = 171, readyAt = came },
		{ name = "Mooncloth", profession = 197, readyAt = later },
	} })
	local some, next_ = Family.Cooldowns:Summarise(Family.Database:Meta(key))
	check("one timer ready beside one still running counts one", some == 1, tostring(some))
	check("and the running one is still when the next comes back", next_ == later,
		tostring(next_))

	-- The item half, which is the trap in doing this through `Crafting` at all. That call
	-- draws a panel, so it carries the crafting *items* as well - including ready ones, which
	-- it shows on purpose. The login line must not: an item is used out of the bags with
	-- nothing open for Family to see, so "ready" means only that nobody has looked.
	Family.Database:SetMeta(key, { craftCooldowns = Family.CLEAR,
		itemCooldowns = { { id = 15846 } }, cooldownItems = { [15846] = 165 } })

	local shown
	for _, kind in ipairs(Family.Cooldowns:Crafting(Family.Database:Meta(key))) do
		if kind.item == 15846 then shown = kind end
	end
	check("a ready crafting item is drawn on the panel", shown ~= nil and shown.ready == true,
		tostring(shown and shown.ready))
	check("and told apart from a craft by what it is, not by what it happens to carry",
		shown and shown.kind == "item", tostring(shown and shown.kind))
	-- **And it counts**, which reverses 2026-09-01 and is argued in `DECISIONS.md`. The
	-- ground for the old split was that a panel is a table somebody opened and a notice is
	-- a claim pushed at them; what it left out is that the two are symmetric - an alt's
	-- bags can only be emptied by playing that alt, and playing it runs a bag scan, exactly
	-- as a transmute can only be used through the window whose scan records it.
	check("and it counts towards what is announced, as any other cooldown does",
		Family.Cooldowns:Summarise(Family.Database:Meta(key)) == 1,
		tostring(Family.Cooldowns:Summarise(Family.Database:Meta(key))))

	-- What is *not* announced is a cooldown that is not a crafting one, and that filter
	-- comes with `Crafting` rather than being written again here: a Chronoboon has a
	-- cooldown and makes something and is not this.
	Family.Database:SetMeta(key, { itemCooldowns = { { id = 9328 } },
		cooldownItems = { [9328] = 202 } })
	check("while an item that is not a crafting cooldown still is not",
		Family.Cooldowns:Summarise(Family.Database:Meta(key)) == 0,
		tostring(Family.Cooldowns:Summarise(Family.Database:Meta(key))))
	Family.Database:SetMeta(key, { itemCooldowns = { { id = 15846 } },
		cooldownItems = { [15846] = 165 } })

	-- A running item is a fact Family still has, so it may say when - and still never counts.
	local soon = time() + 900
	Family.Database:SetMeta(key, {
		itemCooldowns = { { id = 15846, readyAt = soon } } })
	local none, when = Family.Cooldowns:Summarise(Family.Database:Meta(key))
	check("a running item is not announced either", none == 0, tostring(none))
	check("but it does say when it comes back", when == soon, tostring(when))

	Family.Database:Forget(key)
end)()

print()
print("the login line about crafting cooldowns")

-- Nothing measured this notice at all until 2026-09-05, which is how it came to hold two
-- faults at once: it counted recipes rather than timers (L-054, above) and it ran every name
-- together on one line.
--
-- The one-name-a-line rule is written out over `UI:MailNotice` and was taken the day that
-- notice was built. This one predates it and never got it, so a player with a dozen crafters
-- got a paragraph. Asked about from play 2026-09-05, on the worry that it might overrun 255
-- bytes - it cannot: `Family:Print` goes to `AddMessage`, which wraps, and 255 is the cap on
-- `SendChatMessage` and on addon messages. Unreadable rather than truncated, which is reason
-- enough and is the reason the other notice gives.
;(function()
	local roster = {
		-- Three transmutes on one timer, so this one is also the count from L-054 read
		-- back through the notice itself rather than through `Summarise`.
		{ key = "Brewer-Fire Maw", name = "Brewer", realm = "Fire Maw", count = 3 },
		{ key = "Weaver-Fire Maw", name = "Weaver", realm = "Fire Maw", count = 1 },
		-- Somewhere else, so the settled realm rule has something to say about a name.
		{ key = "Faraway-Thunderstrike", name = "Faraway", realm = "Thunderstrike",
			count = 1 },
	}

	local came = time() - 3600
	for _, member in ipairs(roster) do
		local cooldowns = {}
		for index = 1, member.count do
			-- Each on a timer of its own, so the count is the number of timers. Three
			-- sharing one would be one thing to do, which is what the block above holds.
			cooldowns[index] = { name = "Transmute " .. index, profession = 170 + index,
				readyAt = came }
		end

		-- One that has **not** come back, on whoever has several. The notice says what is
		-- ready and not what exists, and without a running timer beside a ready one in the
		-- fixture the mutation that names every craft passes: everything in it was ready,
		-- so "ready" and "craft" picked out the same list. The same shape as L-054, one
		-- rung along.
		if member.count > 1 then
			cooldowns[#cooldowns + 1] = { name = "Still Brewing", profession = 185,
				readyAt = time() + 7200 }
		end
		Family.Database:SetMeta(member.key, { name = member.name, realm = member.realm,
			classFile = "SHAMAN", level = 60, faction = "Alliance",
			craftCooldowns = cooldowns })
	end

	local lines = Family.UI:CooldownNotice()
	check("the notice has something to say", lines ~= nil and #lines > 1,
		tostring(lines and #lines))

	local function lineFor(name)
		local found, seen = nil, 0
		for index = 2, #(lines or {}) do
			if lines[index]:find(name, 1, true) then
				found = lines[index]
				seen = seen + 1
			end
		end
		return found, seen
	end

	-- The property the whole change is about, and it is checked by looking for the *other*
	-- names on a line rather than by counting lines: a notice that grew a heading and still
	-- joined the names would have the right number of lines and the wrong shape.
	local brewer = lineFor("Brewer")
	check("each character is named", brewer ~= nil)
	check("and has a line to itself, with nobody else on it",
		brewer and not brewer:find("Weaver", 1, true)
			and not brewer:find("Faraway", 1, true), tostring(brewer))

	local _, brewerLines = lineFor("Brewer")
	check("named once and not on several lines", brewerLines == 1, tostring(brewerLines))

	-- **What is ready, and not how much of it.** A name and a number said which character
	-- to log into and never what for. The names are the count and say more than it did, so
	-- there is no number beside them - and a check that a number is *absent* is what stops
	-- the two creeping back together.
	check("a character with several timers ready names each of them",
		brewer and brewer:find("Transmute 1", 1, true)
			and brewer:find("Transmute 3", 1, true), tostring(brewer))

	local weaver = lineFor("Weaver")
	check("and one with a single timer names its one thing",
		weaver and weaver:find("Transmute 1", 1, true) ~= nil, tostring(weaver))

	-- Matched on a number in brackets rather than on a bracket, because `UI:NameOf` puts
	-- the other side's initial in brackets too and the first draft of this check read that
	-- as a count. The looser version failed for the right reason on the wrong evidence.
	check("with no count beside the names, which would be the same fact twice",
		brewer and brewer:find("%(%d+%)") == nil, tostring(brewer))

	-- What is ready, not what exists. A timer still running is on the Crafting panel with
	-- the time left beside it, and has no business in a line whose whole claim is that
	-- something is waiting for you now.
	check("and a timer still running is not named as though it were ready",
		brewer and brewer:find("Still Brewing", 1, true) == nil, tostring(brewer))

	-- And that marker is a rule rather than an accident of the fixture: a character on the
	-- other side keeps a different bank, mailbox and auction house, so what can be done
	-- about their cooldown is not what can be done about anybody else's.
	check("a character on the other side is marked as such",
		weaver and weaver:find("(A)", 1, true) ~= nil, tostring(weaver))

	-- The settled realm rule, in both directions, because a rule with one direction checked
	-- is half a rule. Names are unique per realm and not per realm group, so a character
	-- somewhere else has to say where.
	local faraway = lineFor("Faraway")
	check("a character on another realm carries it",
		faraway and faraway:find("Thunderstrike", 1, true) ~= nil, tostring(faraway))
	check("and one on the realm being played does not",
		weaver and weaver:find("Fire Maw", 1, true) == nil, tostring(weaver))

	-- A ready crafting **item** is drawn on the Crafting panel and is deliberately never
	-- announced here - `DECISIONS.md` 2026-09-01. That was pinned from `Cooldowns`' side
	-- when the counting was fixed; this holds it from the notice's, which is where naming
	-- the cooldowns could have let one in through the back door.
	do
		-- A Super Snapper beside the shaker: it has a cooldown, it makes something, and
		-- it is not a crafting cooldown - what it makes is a reagent in nothing. It is
		-- here so that the filter has something to exclude rather than being a line
		-- nothing tests.
		Family.Database:SetMeta("Weaver-Fire Maw", {
			itemCooldowns = { { id = 15846 }, { id = 9328 } },
			cooldownItems = { [15846] = 165, [9328] = 202 } })

		local withItem = Family.UI:CooldownNotice()
		local line
		for index = 2, #(withItem or {}) do
			if withItem[index]:find("Weaver", 1, true) then line = withItem[index] end
		end

		check("a character with a ready crafting item beside a craft is named",
			line ~= nil, tostring(line))
		check("their craft is named", line and line:find("Transmute 1", 1, true) ~= nil,
			tostring(line))

		-- Until the client has been told what item 15846 is, all this line can honestly
		-- say is the id. It does not invent a profession to stand in for the name: in a
		-- list where a shared timer is already named after its profession, that word
		-- would have meant two different things a column apart.
		check("and the item beside it, by the only name the client has given so far",
			line and line:find("15846", 1, true) ~= nil, tostring(line))

		-- Which is why it is asked for early. An item's name is a fact about this
		-- session and not about the account - an alt's shaker is in that alt's bags -
		-- so the first ask gets a placeholder and a promise. The notice speaks eight
		-- seconds in and asks two seconds in, and that gap is the whole mechanism.
		do
			local asked = {}
			local held = C_Item.RequestLoadItemDataByID
			C_Item.RequestLoadItemDataByID = function(id) asked[id] = true end

			local count = Family.UI:WarmCooldownNames()
			check("the names are asked for before the line is written", asked[15846] == true,
				tostring(count) .. " asked")
			check("and only about the items this notice could ever name",
				asked[9328] == nil, tostring(count) .. " asked")

			C_Item.RequestLoadItemDataByID = held
		end

		-- And when the answer lands, the line says the thing's name.
		do
			ITEM_NAMES[15846] = "Salt Shaker"
			fire("GET_ITEM_INFO_RECEIVED", 15846, true)

			local answered = Family.UI:CooldownNotice()
			local said
			for index = 2, #(answered or {}) do
				if answered[index]:find("Weaver", 1, true) then said = answered[index] end
			end
			check("and once the client answers, it is named rather than numbered",
				said and said:find("Salt Shaker", 1, true) ~= nil, tostring(said))
			check("with the number gone from the line", said
				and said:find("15846", 1, true) == nil, tostring(said))

			ITEM_NAMES[15846] = nil
		end

		Family.Database:SetMeta("Weaver-Fire Maw", {
			itemCooldowns = Family.CLEAR, cooldownItems = Family.CLEAR })
	end

	-- The heading is the translated one, not a sentence built here.
	check("with a heading a translator can reach",
		lines and lines[1] == Family.L["crafting cooldowns ready:"], tostring(lines[1]))

	-- The character being played is left out, and says why in the file: a transmute you can
	-- cast is already on your own action bar.
	local mine = Family:CurrentMember()
	Family.Database:SetMeta(mine, { craftCooldowns = {
		{ name = "Transmute: Arcanite", profession = 171, readyAt = came },
	} })
	local withMine = Family.UI:CooldownNotice()
	local named = false
	for index = 2, #(withMine or {}) do
		if withMine[index]:find(Family.Database:Meta(mine).name or "?", 1, true) then
			named = true
		end
	end
	check("and the character being played is not on the list at all", named == false)
	Family.Database:SetMeta(mine, { craftCooldowns = Family.CLEAR })

	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
end)()

--------------------------------------------------------------------------------------------
-- The seam between the client and us
--
-- Every other check of the addon channel calls Comm:Receive directly, which covers the
-- transport in detail and covers the one line joining it to the game not at all. That line
-- was wrong for the whole of this project's life: the handler took the event's first *value*
-- where the dispatcher passes the event's *name*, so the prefix test compared
-- "CHAT_MSG_ADDON" against "Family" and dropped every message Family was ever sent.
--
-- Nothing that crossed the wire had ever worked - no Wide Family link, no guild announcement,
-- either direction, any client - and both features looked like they had faults of their own.
--
-- So this one fires the real event through the real dispatcher, and it is the shape of check
-- worth having wherever our code meets the client's.
--------------------------------------------------------------------------------------------

print()
print("an addon message arriving the way the game delivers it")

;(function()
	local heard = {}
	Family.Comm:On("seam", function(_, body, sender) heard[#heard + 1] = { body, sender } end)

	local sent = {}
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, text, channel, target)
			sent[#sent + 1] = { prefix = prefix, text = text, channel = channel,
				target = target }
			return true
		end,
	}

	Family.Comm:Send("seam", "a message that has to arrive", "WHISPER", "Somebody", false)
	check("something was queued to go out", #sent == 1, tostring(#sent))

	-- Delivered as CHAT_MSG_ADDON, through Core's dispatcher, exactly as the client does it.
	for _, message in ipairs(sent) do
		fire("CHAT_MSG_ADDON", message.prefix, message.text, message.channel, "Grella")
	end

	check("and it arrives", #heard == 1, tostring(#heard))
	check("as the body it was sent as",
		heard[1] and heard[1][1] == "a message that has to arrive",
		heard[1] and tostring(heard[1][1]))
	check("from whoever sent it", heard[1] and heard[1][2] == "Grella",
		heard[1] and tostring(heard[1][2]))

	-- Somebody else's addon on the same channel must still be ignored.
	fire("CHAT_MSG_ADDON", "SomeOtherAddon", "1\0011\0011\001seam\001not ours", "WHISPER",
		"Grella")
	check("while another addon's messages are left alone", #heard == 1, tostring(#heard))
end)()

print()
print("what the client says when it is handed a message")

-- "messages sent from here: 4" counts what Family queued. It says nothing about what the
-- client did with it, so a message the client refused outright is reported as sent - which is
-- exactly the half of a two-client silence that had no instrumentation at all.
--
-- Kept verbatim, by value and by type, and decoded against nothing: reading a result code
-- against a table written from memory would be Family claiming to know what the number means
-- when all it has is the number. DATASOURCES §2, the same rule the guild log probe follows.
;(function()
    Family.Comm:Abandon()
    Family.Comm.stats.answers = {}
    Family.Comm.stats.lastAnswer = nil

    check("with nothing sent there is nothing to report", Family.Comm:Answers() == nil,
        tostring(Family.Comm:Answers()))

    C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function() return 0 end,
    }
    Family.Comm:Send("answers", "one", "WHISPER", "Somebody", false)
    check("the client's answer is kept with its type", Family.Comm:Answers() == "1 x number 0",
        tostring(Family.Comm:Answers()))

    C_ChatInfo.SendAddonMessage = function() return 4 end
    Family.Comm:Send("answers", "two", "WHISPER", "Somebody", false)
    Family.Comm:Send("answers", "three", "WHISPER", "Somebody", false)
    check("a different answer is counted apart from the first",
        Family.Comm:Answers() == "2 x number 4, 1 x number 0", tostring(Family.Comm:Answers()))

    -- Three sends that all said the same thing and two that said different things are
    -- different diagnoses, and the last answer alone shows them as identical.
    check("and the last one is remembered by name", Family.Comm.stats.lastAnswer == "number 4",
        tostring(Family.Comm.stats.lastAnswer))

    -- A call that throws and a call that returns nil are a client that refused and a client
    -- with no opinion. Family:TryCall answers nil to both, which is why this one uses pcall.
    C_ChatInfo.SendAddonMessage = function() error("no") end
    Family.Comm:Send("answers", "four", "WHISPER", "Somebody", false)
    check("a call that throws is not a call that answered nothing",
        Family.Comm.stats.lastAnswer == "threw", tostring(Family.Comm.stats.lastAnswer))

    C_ChatInfo.SendAddonMessage = function() return nil end
    Family.Comm:Send("answers", "five", "WHISPER", "Somebody", false)
    check("and one that answers nothing says so", Family.Comm.stats.lastAnswer == "nil nil",
        tostring(Family.Comm.stats.lastAnswer))

    -- A client with no such call at all, which is the shape Era and Burning Crusade were
    -- written for and the one that must not be reported as a refusal.
    C_ChatInfo = nil
    local wasGlobal = _G.SendAddonMessage
    _G.SendAddonMessage = nil
    Family.Comm:Send("answers", "six", "WHISPER", "Somebody", false)
    check("a client with no such call says that instead",
        Family.Comm.stats.lastAnswer == "no such call",
        tostring(Family.Comm.stats.lastAnswer))
    _G.SendAddonMessage = wasGlobal

    Family.Comm:Abandon()
    Family.Comm.stats.answers = {}
end)()

print()
print("counting what the client hands over, above the prefix test")

-- Two silent clients produce "announcements arrived: 0" whether the channel delivered nothing
-- or delivered everything into a handler that dropped it, and those two have opposite answers:
-- one is somebody else's and one is ours. Guild.stats cannot tell them apart because every one
-- of its counters is taken after the message is already Family's.
--
-- So the count is taken at the seam, above the prefix test - which is exactly where the bug
-- the section above exists for was living, invisible to five hundred checks.
;(function()
	local before = {
		events = Family.Comm.stats.events,
		ours = Family.Comm.stats.ours,
		malformed = Family.Comm.stats.malformed,
		unhandled = Family.Comm.stats.unhandled,
	}

	Family.Comm:On("counted", function() end)

	-- Somebody else's addon. Counted as traffic, not as ours: the pair is the whole point.
	local mine = Family.Comm:Heard("SomeOtherAddon", "1\0011\0011\001counted\001x",
		"GUILD", "Grella")
	check("another addon's message is not ours", mine == false, tostring(mine))
	check("but it still counts as the client handing something over",
		Family.Comm.stats.events == before.events + 1,
		tostring(Family.Comm.stats.events - before.events))
	check("and not as one of ours", Family.Comm.stats.ours == before.ours,
		tostring(Family.Comm.stats.ours - before.ours))

	mine = Family.Comm:Heard("Family", "1\0011\0011\001counted\001x", "GUILD", "Ginetta")
	check("one of ours is ours", mine == true, tostring(mine))
	check("and counts in both places",
		Family.Comm.stats.events == before.events + 2
			and Family.Comm.stats.ours == before.ours + 1,
		string.format("%d/%d", Family.Comm.stats.events - before.events,
			Family.Comm.stats.ours - before.ours))
	check("naming who it came from", Family.Comm.stats.lastFrom == "Ginetta",
		tostring(Family.Comm.stats.lastFrom))
	check("and on which channel", Family.Comm.stats.lastChannel == "GUILD",
		tostring(Family.Comm.stats.lastChannel))

	-- A body with no header at all. It reached us and it is ours; it is the parse that failed,
	-- and saying so is the difference between blaming the guild and reading our own code.
	Family.Comm:Heard("Family", "not a message at all", "GUILD", "Ginetta")
	check("something of ours that will not parse is counted as that",
		Family.Comm.stats.malformed == before.malformed + 1,
		tostring(Family.Comm.stats.malformed - before.malformed))

	-- A well-formed message for a kind nobody registered.
	Family.Comm:Heard("Family", "1\0011\0011\001nobodyhandlesthis\001x", "GUILD", "Ginetta")
	check("and one nothing handles is counted separately",
		Family.Comm.stats.unhandled == before.unhandled + 1
			and Family.Comm.stats.malformed == before.malformed + 1,
		string.format("%d/%d", Family.Comm.stats.unhandled - before.unhandled,
			Family.Comm.stats.malformed - before.malformed))
end)()

print()
print("whispering somebody who is not there")

-- An exchange is hundreds of whispers, and the client answers every one of them with a line
-- of chat when the name is offline. Pressing Update on a family whose character had logged
-- out therefore filled the screen and kept filling it. There is no way to ask first - the
-- client will not say whether a name is online and the addon channel acknowledges nothing
-- (§11.1) - so the failure is the answer, and it arrives as chat rather than as anything a
-- function returns.
;(function()
	local sent = {}
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, text, channel, target)
			sent[#sent + 1] = { channel = channel, target = target }
			return true
		end,
	}

	Family.Comm:Abandon()

	-- Out of the fight while the whispers go, and in it afterwards.
	--
	-- This held everything with combat from the first line, and then fired a complaint about
	-- a whisper that had never left the client. It passed for as long as the absent list was
	-- keyed on the bare name: the complaint named a character nothing had addressed, and it
	-- was marked absent regardless. Keyed on the character it failed, and it was right to -
	-- the client complains about whispers it was handed, so a fixture where none was handed
	-- is describing a line that cannot arrive.
	--
	-- So the canary leaves, which is the real sequence: one chunk goes, the refusal comes
	-- back about it, and what is still queued behind it is dropped. The fight then holds the
	-- rest, which is the state the fault happens in - hundreds of messages waiting on
	-- somebody who is not there.
	InCombatLockdown = function() return false end

	-- Long enough to be many messages, which is the shape of the fault: one whisper would
	-- have produced one complaint and nobody would have minded.
	-- Whispered with the realm on it, because that is how the sender's name arrives and so
	-- that is what Family whispers back to. The client's complaint will not have the realm
	-- on it, because that is the form a player types. Both name one character and the two
	-- strings are not equal - which is the whole of why the first version of this fix
	-- dropped nothing and the storm carried on. The first version of this *check* used the
	-- same name on both sides and passed, which is why it shipped.
	Family.Comm:Send("bulk", string.rep("x", 4000), "WHISPER", "Grella-Thunderstrike", true)
	local queued = Family.Comm:Pending()
	check("a family's records are many whispers, not one", queued > 5, tostring(queued))

	-- Somebody else's transfer, to prove the wrong one is not thrown away with it.
	Family.Comm:Send("bulk", string.rep("y", 600), "WHISPER", "Tossica-Thunderstrike", true)
	local both = Family.Comm:Pending()

	-- And now the fight, so that what is left stays left and the drop is what moves it.
	InCombatLockdown = function() return true end

	local before = #DEFAULT_CHAT_FRAME.messages
	fire("CHAT_MSG_SYSTEM",
		string.format(_G.ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is "
			.. "currently playing.", "Grella"))

	check("the client saying so empties what was queued for them",
		Family.Comm:Pending() < both - 5,
		Family.Comm:Pending() .. " left of " .. both)
	check("and leaves what was queued for anybody else", Family.Comm:Pending() > 0,
		tostring(Family.Comm:Pending()))

	-- One chunk first, to somebody nobody has heard from.
	--
	-- The client refuses a whisper to somebody who is not there, once per message, in red in
	-- the chat frame. Abandoning what is still queued at the first refusal is not enough: the
	-- queue drains two chunks every fifth of a second and a refusal takes a round trip, so
	-- three or four had gone before it arrived - and a family of five characters tried in
	-- turn produced twenty of those lines, none of them Family's to suppress.
	--
	-- Somebody we have just heard from needs no canary, because receiving a message is proof
	-- they are there. This is the other case, and it is the one that makes the noise.
	do
		-- Out of combat, because bulk waits for that as well and a check that cannot tell
		-- the two waits apart is measuring neither.
		local realCombat = InCombatLockdown
		InCombatLockdown = function() return false end

		-- An empty queue first, or this measures whatever the checks above left in it.
		Family.Comm:AbandonTo("Tossica-Thunderstrike")
		advance(5)

		local before = Family.Comm:Pending()
		Family.Comm:Send("bulk", string.rep("z", 900), "WHISPER",
			"Nobodyhasheardfromthem-Thunderstrike", true)

		local queued = Family.Comm:Pending() - before
		advance(1)
		local left = Family.Comm:Pending() - before

		check("only one chunk goes to somebody nobody has heard from",
			left >= queued - 1, tostring(queued - left) .. " of " .. tostring(queued)
				.. " sent")

		-- And the rest once the wait is over, so a character who is there costs a second
		-- and a half on a transfer nobody is watching rather than never arriving.
		advance(4)
		check("and the rest follows once the wait is over",
			Family.Comm:Pending() - before < queued - 1,
			tostring(Family.Comm:Pending() - before) .. " still queued")

		-- Both halves of an exchange, not only the big one. An exchange is everything we
		-- are sharing and a request for theirs, and the request going out beside the
		-- canary cost a second refusal from the client for a character who was not there.
		advance(5)
		do
			local base = Family.Comm:Pending()
			Family.Comm:Send("bulk", string.rep("z", 900), "WHISPER",
				"Nobodyelsehasheardfromthem-Thunderstrike", true)
			Family.Comm:Send("want", "x", "WHISPER",
				"Nobodyelsehasheardfromthem-Thunderstrike", true)

			local queuedBoth = Family.Comm:Pending() - base
			advance(0.4)

			check("a second message queued beside it waits as well",
				(queuedBoth - (Family.Comm:Pending() - base)) <= 1,
				tostring(queuedBoth - (Family.Comm:Pending() - base)) .. " sent")

			advance(5)
		end

		InCombatLockdown = realCombat
	end

	-- One line about it, not one per message.
	local said = 0
	for index = before + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("is not online", 1, true) then
			said = said + 1
		end
	end
	check("and says so once rather than once per message", said == 1, tostring(said))

	-- Asked by the name we would whisper, answered from the name the client complained
	-- about. If those two have to be equal then none of this works in the game.
	check("and remembers, so pressing the button again does not do it all over",
		Family.Comm:Absent("Grella-Thunderstrike") == true)
	check("about them and not about everybody",
		Family.Comm:Absent("Tossica-Thunderstrike") == false)

	-- Hearing from them settles it, whatever the server said a minute ago.
	Family.Comm:Receive("1\0011\0011\001hello\001hi", "Grella-Thunderstrike", "WHISPER")
	check("and hearing from them settles it again",
		Family.Comm:Absent("Grella-Thunderstrike") == false)

	-- The wording is the client's, in whatever language it ships in. Matching the English
	-- would work here and nowhere else, and would fail silently - which on this path means
	-- the storm comes back for everybody who does not play in English.
	check("the sentence it matches is the client's own, not ours",
		type(_G.ERR_CHAT_PLAYER_NOT_FOUND_S) == "string"
			and _G.ERR_CHAT_PLAYER_NOT_FOUND_S:find("%%s") ~= nil)

	------------------------------------------------------------------------------------
	-- Two characters of one name, on two realms
	------------------------------------------------------------------------------------

	-- Names are unique per realm and not per realm group, so a linked family - or ours plus
	-- a link - can hold two Rolandos. They can be played at the same moment, from two
	-- accounts: a family is a person's characters and not an account's. So the one who is
	-- there must not be taken off the list of who to try because the other one is not.

	local function complaint(about)
		return string.format(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, about)
	end

	do
		InCombatLockdown = function() return false end
		Family.Comm:Abandon()

		-- Both whispered, so both canaries leave and the window holds two characters of
		-- one name. This is the case no string can decide.
		Family.Comm:Send("bulk", string.rep("r", 900), "WHISPER",
			"Rolando-Thunderstrike", true)
		Family.Comm:Send("bulk", string.rep("r", 900), "WHISPER",
			"Rolando-Fire Maw", true)
		InCombatLockdown = function() return true end

		local waiting = Family.Comm:Pending()
		check("two characters of one name can both be waiting", waiting > 4,
			tostring(waiting))

		-- Hidden either way: the line is Family's noise whichever Rolando it is about, and
		-- taking it off the screen needs no attribution.
		check("the client's line about an unattributable name is still hidden",
			Family.Comm.__swallowNotFound(nil, nil, complaint("Rolando")) == true)

		fire("CHAT_MSG_SYSTEM", complaint("Rolando"))

		-- And acted on for neither. §2.2: not seen is not the same as empty.
		check("neither of them is marked absent on a refusal naming both",
			Family.Comm:Absent("Rolando-Thunderstrike") == false
				and Family.Comm:Absent("Rolando-Fire Maw") == false)
		check("and nothing queued for either of them is thrown away",
			Family.Comm:Pending() == waiting,
			Family.Comm:Pending() .. " of " .. waiting)
	end

	-- A different name, because the window is fifteen seconds and this harness's clock does
	-- not move: reusing Rolando would ask the second question with the first one's evidence
	-- still in the table.
	do
		InCombatLockdown = function() return false end
		Family.Comm:Abandon()

		-- Only one of the two whispered this time, so the bare name the client answers with
		-- is decided by what we addressed rather than by what it says.
		--
		-- **Deliberately not the realm being played.** `GetRealmName` answers "Fire Maw"
		-- here, and a bare name with nothing to resolve it falls back to the realm the
		-- player is on - so a check written against a Fire Maw character would pass on the
		-- fallback and prove nothing about the resolution. Thunderstrike is the realm the
		-- fallback would get wrong.
		Family.Comm:Send("bulk", string.rep("g", 900), "WHISPER",
			"Griselda-Thunderstrike", true)
		InCombatLockdown = function() return true end

		local waiting = Family.Comm:Pending()
		fire("CHAT_MSG_SYSTEM", complaint("Griselda"))

		check("one of the two whispered means the refusal is about that one",
			Family.Comm:Absent("Griselda-Thunderstrike") == true)
		check("and says nothing about the same name on another realm",
			Family.Comm:Absent("Griselda-Fire Maw") == false)
		check("and what was queued for the one it named is dropped",
			Family.Comm:Pending() < waiting,
			Family.Comm:Pending() .. " of " .. waiting)

		-- The other direction, and what it actually holds is the pair: the listener writes
		-- the character down and `Absent` reads the character back, so somebody being heard
		-- from on another realm cannot reach it. Said that way rather than as "Present is
		-- keyed on the character", which is a different claim and is held by the check
		-- above about hearing from them settling it.
		Family.Comm:Receive("1\0011\0011\001hello\001hi", "Griselda-Fire Maw",
			"WHISPER")
		check("hearing from one does not vouch for the other",
			Family.Comm:Absent("Griselda-Thunderstrike") == true)

		-- And the queue asked directly, because the refusal above cannot reach this: it
		-- abandons the character it named, and what has to be proved is that it leaves the
		-- other one's alone. Queued in the fight, so it is never sent and never becomes a
		-- second character of that name inside the window.
		Family.Comm:Send("bulk", string.rep("g", 900), "WHISPER",
			"Griselda-Fire Maw", true)
		local held = Family.Comm:Pending()
		check("abandoning one realm's queue does not empty the other realm's",
			Family.Comm:AbandonTo("Griselda-Thunderstrike") == 0
				and Family.Comm:Pending() == held,
			Family.Comm:Pending() .. " of " .. held)
	end

	-- The comparison everything above rests on, asked directly. It answers on what both
	-- sides know: strict once both carry a realm, tolerant while only one does - which is
	-- the complaint-against-a-stored-name case it was written for and still has to serve.
	check("a bare name and the same name with its realm are one character",
		Family.Comm:SameName("Grella", "Grella-Thunderstrike") == true)
	check("but two realms are two characters",
		Family.Comm:SameName("Rolando-Thunderstrike", "Rolando-Fire Maw") == false)
	check("and a realm written with its space compares as one without",
		Family.Comm:SameName("Rolando-FireMaw", "Rolando-Fire Maw") == true)
	check("and two names are never one character",
		Family.Comm:SameName("Rolando-Fire Maw", "Grella-Fire Maw") == false)

	Family.Comm:Abandon()
	InCombatLockdown = function() return false end
end)()

print()
print("a family is a person with several characters")

-- Update has to work if *any* of their characters is online, and must not be attempted at all
-- if none is. The one we whisper is whichever we heard from last, which may have been a week
-- ago and is very often not the one they are playing now - so being told that name is not
-- there eliminates a candidate rather than answering the question.
;(function()
	local sent = {}
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, text, channel, target)
			sent[#sent + 1] = { channel = channel, target = target }
			return true
		end,
	}

	local before = FamilyDB.wide
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["theirs"] = { name = "Grella-Thunderstrike", grants = {}, members = {},
			characters = {
				["Grella-Thunderstrike"] = time(),
				["Grellina-Thunderstrike"] = time() - 100,
				["Grellone-Thunderstrike"] = time() - 200,
			} } },
	}

	local function notFound(who)
		fire("CHAT_MSG_SYSTEM", string.format(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, who))
	end

	sent = {}
	local ok = Family.Wide:ExchangeWith("theirs", "a test")
	check("an exchange goes to the one we heard from last", ok
		and sent[1] and sent[1].target == "Grella-Thunderstrike",
		sent[1] and tostring(sent[1].target) or "nothing sent")

	-- And it goes one message at a time to somebody nobody has heard from.
	--
	-- An exchange is two things - everything we are sharing, and a request for theirs - and
	-- the second is one line. Sent eagerly it went out beside the first, so a character who
	-- was not online cost two refusals from the client instead of one. Both halves belong to
	-- the same exchange and wait on the same proof that anybody is there.
	do
		local link = Family.Wide:Links()["theirs"]
		link.characters["Neverheardofhim-Thunderstrike"] = time() + 60

		sent = {}
		Family.Wide:ExchangeWith("theirs", "a test")
		advance(0.4)

		local toThem = 0
		for _, message in ipairs(sent) do
			if message.target == "Neverheardofhim-Thunderstrike" then
				toThem = toThem + 1
			end
		end
		check("and one message at a time to somebody nobody has heard from",
			toThem <= 1, tostring(toThem) .. " messages")

		link.characters["Neverheardofhim-Thunderstrike"] = nil
		Family.Comm:AbandonTo("Neverheardofhim-Thunderstrike")
		advance(5)
	end

	sent = {}

	-- That one is not the one they are playing. The next is tried without anybody pressing
	-- anything, which is the whole point: a link is to the family, not to whichever of them
	-- happened to be logged in when it was made.
	sent = {}
	notFound("Grella")
	local tried = sent[1] and sent[1].target
	check("and being told they are not there tries the next of theirs",
		tried == "Grellina-Thunderstrike", tostring(tried))

	-- **And once, not once per message.** An exchange is many messages and the client refuses
	-- each of the ones that had already left, so the same name comes back three or four times.
	-- Every one of those used to walk the family again and send another whole exchange: five
	-- characters became twenty attempts, twenty refusals from the server, and four copies of
	-- every sentence Family prints about it. Reported from a live client.
	do
		sent = {}
		local saidBefore = #DEFAULT_CHAT_FRAME.messages

		notFound("Grella")
		notFound("Grella")
		notFound("Grella")

		check("and the same refusal arriving again sends nothing further",
			#sent == 0, tostring(#sent) .. " sent again")

		local repeated = 0
		for index = saidBefore + 1, #DEFAULT_CHAT_FRAME.messages do
			if DEFAULT_CHAT_FRAME.messages[index]:find("is not online", 1, true)
				or DEFAULT_CHAT_FRAME.messages[index]:find("None of", 1, true) then
				repeated = repeated + 1
			end
		end
		check("and says nothing further about it either", repeated == 0,
			tostring(repeated) .. " more lines")
	end

	-- Nothing said to the player while it is still working through them. Four lines naming
	-- which character is being tried next are the working, not the answer, and the answer is
	-- the one sentence at the end that says nobody was there. Anybody who wants the working
	-- switches the narration on, which is what this turns off to measure.
	sent = {}
	local wasNarrating = FamilyDB.debug
	FamilyDB.debug = false

	local quietFrom = #DEFAULT_CHAT_FRAME.messages
	notFound("Grellina")

	local said = 0
	for index = quietFrom + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("is not online", 1, true) then
			said = said + 1
		end
	end
	check("and says nothing to the player while it works through them",
		said == 0, tostring(said) .. " lines")

	FamilyDB.debug = wasNarrating

	check("and the next after that",
		sent[1] and sent[1].target == "Grellone-Thunderstrike",
		sent[1] and tostring(sent[1].target) or "nothing sent")

	-- And then it stops, rather than going round for ever. Every attempt eliminates one
	-- name, so the list runs out on its own.
	sent = {}
	local said = #DEFAULT_CHAT_FRAME.messages
	notFound("Grellone")
	check("and when they are all eliminated it stops trying", #sent == 0, tostring(#sent))

	local told
	for index = said + 1, #DEFAULT_CHAT_FRAME.messages do
		-- "is online" for one of them, "are online" for several: the message stopped
		-- forming its plural by hanging an "s" on the end when it was translated, because
		-- no language outside English forms all three of these the same way.
		if DEFAULT_CHAT_FRAME.messages[index]:find("online", 1, true) then
			told = DEFAULT_CHAT_FRAME.messages[index]
		end
	end
	check("and says that none of them is, rather than naming one of the three",
		told ~= nil and told:find("None of", 1, true) ~= nil, tostring(told))


	------------------------------------------------------------------------------------------
	-- A character they added after linking
	--
	-- Everything above works from `characters` - the ones we have heard from. A character
	-- created on their side after the link is not in it and never will be until they happen
	-- to send from it: they arrive as a *member*, which is what the Wide Family panel lists
	-- and what the summary borrows. So a family could see six of their characters, tick one
	-- as a sibling and read its bags, while this list held one name.
	--
	-- Reported from play, with the panel showing six and the update saying "none of their 1
	-- character is online" while the player was sitting on one of the other five.
	------------------------------------------------------------------------------------------
	do
		local link = Family.Wide:Links()["theirs"]

		-- Two of theirs that have never said a word here, and one that is a second spelling
		-- of somebody already in `characters` - because a member key carries the realm and
		-- the name the client complains with does not, and counting that one twice would put
		-- a number in front of the player that is not the size of their family.
		link.members = {
			["Spazzacamino-Thunderstrike"] = { meta = { name = "Spazzacamino" } },
			["Malachia-Thunderstrike"] = { meta = { name = "Malachia" } },
			["Grella-Thunderstrike"] = { meta = { name = "Grella" } },
		}

		-- Everybody above has already been refused once, and `time()` does not move in this
		-- harness, so an absent mark set earlier never expires on its own. The client saying
		-- somebody *is* there is what clears one, and it is what this uses.
		sent = {}
		Family.Comm:Abandon()
		for _, who in ipairs({ "Grella", "Grellina", "Grellone", "Malachia",
			"Spazzacamino" }) do
			Family.Comm:Present(who .. "-Thunderstrike")
		end

		-- Heard-from first, because being heard from is evidence of having been online and
		-- being shared is only evidence of existing.
		Family.Wide:ExchangeWith("theirs", "after they added one")
		check("a character they added after linking does not displace one we have heard from",
			sent[1] and sent[1].target == "Grella-Thunderstrike",
			sent[1] and tostring(sent[1].target) or "nothing sent")

		-- And when every heard-from name has been eliminated, the shared ones are still
		-- somebody to try - which is the whole fault: before this they were not.
		notFound("Grella")
		notFound("Grellina")
		notFound("Grellone")

		local reached = sent[#sent] and sent[#sent].target
		check("and once they are all eliminated, one they only told us about is tried",
			reached == "Malachia-Thunderstrike", tostring(reached))

		-- And a refusal naming *that* one is about this link too, so it moves on rather than
		-- landing nowhere. Matched against the heard-from list alone it belonged to no link.
		notFound("Malachia")
		check("and a refusal naming one of those moves on to the next",
			sent[#sent] and sent[#sent].target == "Spazzacamino-Thunderstrike",
			sent[#sent] and tostring(sent[#sent].target) or "nothing sent")

		-- Five, not six: Grella is in both lists and is one character.
		local from = #DEFAULT_CHAT_FRAME.messages
		notFound("Spazzacamino")

		local counted
		for index = from + 1, #DEFAULT_CHAT_FRAME.messages do
			local line = DEFAULT_CHAT_FRAME.messages[index]
			if line:find("None of", 1, true) then counted = line end
		end
		check("and the count is of characters, not of the lists they came from",
			counted ~= nil and counted:find("5 characters", 1, true) ~= nil,
			tostring(counted))

		link.members = {}
		Family.Comm:Abandon()
		advance(120)
	end


	------------------------------------------------------------------------------------------
	-- And the switch that turns that sentence off
	------------------------------------------------------------------------------------------

	check("the report is on until somebody turns it off", Family.Wide:Reports() == true)

	-- A fresh character of theirs each time, because the report is said once per name and
	-- everybody in this fixture has already been through it. Without a name that has not been
	-- refused before, both halves below would measure a silence that was already there.
	local function walkOut(who)
		local link = Family.Wide:Links()["theirs"]
		link.characters[who .. "-Thunderstrike"] = time() + 120

		sent = {}
		Family.Wide:ExchangeWith("theirs", "another go")
		advance(0.4)

		local from = #DEFAULT_CHAT_FRAME.messages
		notFound(who)

		local lines = 0
		for index = from + 1, #DEFAULT_CHAT_FRAME.messages do
			if DEFAULT_CHAT_FRAME.messages[index]:find("None of", 1, true) then
				lines = lines + 1
			end
		end

		link.characters[who .. "-Thunderstrike"] = nil
		return lines
	end

	Family.Wide:SetReports(false)
	local whenOff = walkOut("Grellotto")
	Family.Wide:SetReports(true)
	local whenOn = walkOut("Grellozzo")

	check("and switched off the player is not told", whenOff == 0, tostring(whenOff) .. " lines")
	check("and switched on they are, which is what makes the line above mean anything",
		whenOn == 1, tostring(whenOn) .. " lines")

	-- The fact is not lost with the interruption. Switching a report off should cost the line
	-- in the chat frame and nothing else, so it goes where the working already goes.
	local wasNarrating2 = FamilyDB.debug
	FamilyDB.debug = true
	Family.Wide:SetReports(false)

	local narrationFrom = #DEFAULT_CHAT_FRAME.messages
	walkOut("Grellucci")

	local narrated = false
	for index = narrationFrom + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("are online", 1, true) then
			narrated = true
		end
	end
	check("and narrates it instead, so what is lost is the interruption and not the fact",
		narrated)

	FamilyDB.debug = wasNarrating2
	Family.Wide:SetReports(true)

	-- **What it must not cover.** A request to link, a link made, a link ended and a version
	-- mismatch are all Family:Print in this same file, and every one of them is either a
	-- decision waiting for the player, their family changing shape, or a fault - none is
	-- feedback about an exchange, and a fault silenced is a fault that looks fixed.
	--
	-- Counted in the source rather than proved with a fixture each, because four fixtures to
	-- establish one rule are four fixtures that go stale separately - and because the thing
	-- worth catching is somebody later putting a fifth Print inside this guard.
	do
		local handle = io.open(ROOT .. "/addons/Family/Wide.lua")
		local source = handle and handle:read("*a") or ""
		if handle then handle:close() end

		local _, guards = source:gsub("if Wide:Reports%\(%\) then", "")
		local guarded = 0
		for block in source:gmatch("if Wide:Reports%\(%\) then\n(.-)\n%s*else\n") do
			local _, prints = block:gsub("Family:Print", "")
			guarded = guarded + prints
		end
		local _, total = source:gsub("Family:Print", "")

		check("the switch stands in front of exactly one report",
			guards == 1 and guarded == 1,
			tostring(guards) .. " guard(s), " .. tostring(guarded) .. " print(s)")
		check("and leaves the lines that are decisions, changes and faults alone",
			total - guarded >= 4, tostring(total - guarded) .. " ungoverned")
	end

	-- Pressing the button now must not start the whole thing over.
	sent = {}
	local again, why = Family.Wide:ExchangeWith("theirs", "pressed again")
	check("pressing update again sends nothing at all", #sent == 0, tostring(#sent))
	check("and says why, by the family's name rather than a character's",
		again == false and type(why) == "string"
			and why:find("Grella-Thunderstrike", 1, true) ~= nil, tostring(why))

	-- Hearing from any one of them puts the family back within reach.
	Family.Comm:Receive("1\0011\0011\001hello\001hi", "Grellina-Thunderstrike", "WHISPER")
	sent = {}
	check("and hearing from one of them makes the family reachable again",
		Family.Wide:ExchangeWith("theirs", "they are back") and #sent > 0)

	FamilyDB.wide = before
	Family.Comm:Abandon()
end)()

print()
print("the tab strip's pictures")

;(function()
	-- Named rather than counted off whatever is registered: this file registers tabs of its
	-- own - a deliberately broken one, and a second Talents to reload it - and a check that
	-- accepted whatever it found would pass the day somebody deleted a real tab.
	local WANTED = { "summary", "talents", "contents", "professions", "character",
		"wide", "guild", "options", "about" }

	local icons = Family.UI.TAB_ICONS
	local missing = {}
	for _, id in ipairs(WANTED) do
		if not icons[id] then missing[#missing + 1] = id end
	end
	check("every tab Family registers has a picture", #missing == 0,
		table.concat(missing, ", "))

	local seen, duplicate = {}, nil
	for id, path in pairs(icons) do
		if seen[path] then
			duplicate = string.format("%s and %s both draw %s", seen[path], id, path)
		else
			seen[path] = id
		end
	end
	check("and no two of them have the same one", duplicate == nil, duplicate)

	-- Set on the button, and not merely recorded in the table beside it.
	local found = {}
	for _, tab in ipairs(Family.UI:Tabs()) do
		local path = icons[tab.id]
		if path then
			for _, f in ipairs(frames) do
				if rawget(f, "icon") and f.__text == tab.label
					and f.icon.__texture == path then
					found[tab.id] = true
				end
			end
		end
	end

	local drawn = 0
	for _ in pairs(found) do drawn = drawn + 1 end
	check("and the picture reaches the button rather than only the table",
		drawn == #WANTED, tostring(drawn) .. " of " .. tostring(#WANTED))

	-- The Character panel's sections are the same table under another name, and they are
	-- read the same way: two sections drawing one picture is the same defect as two tabs
	-- doing it, and the same check catches it.
	local sections = Family.UI.SECTION_ICONS
	local sectionSeen, sectionClash = {}, nil
	local sectionCount = 0

	for name, path in pairs(sections) do
		sectionCount = sectionCount + 1
		if sectionSeen[path] then
			sectionClash = string.format("%s and %s both draw %s", sectionSeen[path], name,
				path)
		else
			sectionSeen[path] = name
		end
	end

	-- The number is written down rather than left as ">= 1", so that a section quietly
	-- losing its picture cannot pass and adding one is a deliberate edit in both places.
	check("every section of the Character panel has a picture", sectionCount == 5,
		tostring(sectionCount))
	check("and no two of those are the same either", sectionClash == nil, sectionClash)

	-- And none of them is a tab's, which would be one picture meaning two things in two
	-- places rather than in one.
	local crossed
	for name, path in pairs(sections) do
		if seen[path] then
			crossed = string.format("the %s tab and the %s section both draw %s",
				seen[path], name, path)
		end
	end
	check("nor is any of them a tab's", crossed == nil, crossed)
end)()

print()
print("every panel, asked whether its buttons can be clicked")

-- The rule was checked where it was written: one panel, at one moment. Every other panel in
-- the window had never been drawn at that point, and a widget that does not exist cannot be
-- found covering anything - so the rule that was meant to hold everywhere held in the one
-- place the fault had already been found.
--
-- This draws every tab, and inside the two panels that have sections of their own every
-- section, because each section builds a different arrangement out of the same row pool and
-- that is where all of this went wrong. Then it asks the question once, of everything that
-- was built. One sweep rather than one per tab on purpose: this harness does not model a
-- hidden frame hiding its children, so a per-tab answer would name a tab and mean the window.
;(function()
	if not Family.UI.window:IsShown() then Family.UI:Toggle() end

	local SECTIONS = { "Equipped gear", "Reputations", "Quests", "Currencies",
		"Whole family", "Overview", "Bags", "Activity", "Professions", "Crafting",
		"Miscellaneous" }

	local drawn = 0
	for _, tab in ipairs(Family.UI:Tabs()) do
		Family.UI:ShowTab(tab.id)
		drawn = drawn + 1

		if tab.id == "character" or tab.id == "summary" then
			for _, label in ipairs(SECTIONS) do clickButton(label) end
		end
	end

	check("every panel in the window has been drawn at least once", drawn >= 9,
		tostring(drawn))

	local function nameOf(f)
		return f.__text or (type(f.text) == "table" and f.text.__text) or nil
	end

	local blocked, by, count = nil, nil, 0
	for _, f in ipairs(frames) do
		if f.__shown == true and clickable(f) then
			count = count + 1
			local covering = coveredBy(f)
			if covering then
				blocked = nameOf(f) or "an unnamed widget"
				by = nameOf(covering) or "a row"
			end
		end
	end

	check("and nothing anywhere is drawn on a row that would eat its click",
		blocked == nil,
		blocked and string.format("%s is under %s", tostring(blocked), tostring(by)))
	check("with something actually there to have asked about", count > 100,
		tostring(count))
end)()

print()
print("a broken handler must not take the addon down")
Family:RegisterEvent("BAG_UPDATE_DELAYED", "explode", function() error("boom") end)
local survived = pcall(fire, "BAG_UPDATE_DELAYED")
check("event dispatch isolates a failing handler", survived)

--------------------------------------------------------------------------------------------
-- The release workflow can actually publish
--
-- v1.0.0-beta.1 uploaded to CurseForge and then returned 403 creating the GitHub release,
-- because GITHUB_TOKEN is read-only unless a job asks for more. That is the expensive shape
-- of failure: half the version published, and nothing to notice until the run went red.
--
-- Reading the workflow here is cheap and it fails on the day somebody removes the block,
-- rather than at the next release.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- What CurseForge is actually shown
--
-- `manual-changelog` in .pkgmeta names a file and the packager sends that file **whole**.
-- Pointed at CHANGELOG.md it published every version since 1.0.0 on every release - 58 kB of
-- history under an empty Unreleased heading - while .pkgmeta's own comment and the changelog's
-- header both said it published the release's section. The section release.sh cuts went into
-- the tag annotation, where nobody reads it.
--
-- Two files asserting one fact, nothing comparing them, and the fault visible only in the
-- published artifact: the same shape as the libraries in L-038, found the same way, by opening
-- what went out. So this compares them.
--------------------------------------------------------------------------------------------

print()
print("the notes CurseForge shows are this release's and not the whole history")
;(function()
	local meta = io.open(ROOT .. "/.pkgmeta")
	local pkgmeta = meta and meta:read("*a") or ""
	if meta then meta:close() end

	local named = pkgmeta:match("manual%-changelog:%s*\n%s*filename:%s*(%S+)")
	check("the packager is pointed at a file",
		named ~= nil, tostring(named))

	check("and it is not the whole changelog, which is history rather than notes",
		named ~= "CHANGELOG.md", tostring(named))

	local script = io.open(ROOT .. "/tools/release.sh")
	local sh = script and script:read("*a") or ""
	if script then script:close() end

	check("and release.sh writes exactly that file",
		named ~= nil and sh:find("> " .. named, 1, true) ~= nil,
		"release.sh does not write " .. tostring(named))

	-- Compared plainly rather than as a pattern: the file's name has a hyphen in it and a
	-- hyphen is a quantifier in a Lua pattern, so matching it as one asks a question about
	-- repeated Es. The first version of this check did exactly that and failed on a line
	-- that was right there.
	local staged = false
	for line in (sh .. "\n"):gmatch("([^\n]*)\n") do
		if line:find("git add ", 1, true) and named and line:find(named, 1, true) then
			staged = true
		end
	end
	check("and stages it with the release commit, or the tag would not carry it", staged)

	-- And what is in it now is one release's worth. A file holding two version headings is
	-- one that stopped being cut and started being appended to.
	local notes = named and io.open(ROOT .. "/" .. named)
	if notes then
		local text = notes:read("*a")
		notes:close()

		local versions = 0
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			if line:match("^## ") then versions = versions + 1 end
		end

		check("and the file itself holds one version, not a history",
			versions == 1, tostring(versions) .. " version headings")
		check("and does not carry the Unreleased heading into a published page",
			text:find("## Unreleased", 1, true) == nil)
	else
		check("the notes file is present", false, tostring(named) .. " is missing")
	end
end)()

print()
print("the release workflow may create the release it uploads")
;(function()
	local f = io.open(ROOT .. "/.github/workflows/release.yml")
	if not f then
		check("release.yml is where the harness expects it", false,
			ROOT .. "/.github/workflows/release.yml")
		return
	end
	local yml = f:read("*a")
	f:close()

	check("release.yml grants the job contents: write",
		yml:match("permissions:%s*\n%s*contents:%s*write") ~= nil,
		"without it the CurseForge upload succeeds and the GitHub release returns 403")

	-- And it opens what it built. The check below this one compares .pkgmeta against the
	-- .toc, which is the fault as it exists in the repository; this is the workflow step
	-- that looks in the zip the packager actually produced, which is the artifact nobody
	-- had ever opened until a player on a fresh machine could not link (L-038).
	check("release.yml opens the zip it built and looks for the libraries in it",
		yml:match("Look inside the zip") ~= nil and yml:match("zipfile") ~= nil,
		"the built artifact is the only place a wrong external destination is visible")
end)()

--------------------------------------------------------------------------------------------
-- The libraries land where the .toc looks for them
--
-- `addons/Family/Libs` is gitignored: the three libraries are `.pkgmeta` externals, fetched at
-- package time and never present in a clone. So the one place their path is stated twice is
-- between two files nobody compares - the .toc that loads them, and the .pkgmeta that puts
-- them somewhere.
--
-- They disagreed from v1.0.0 to v1.4.0. An external's destination is relative to the package
-- directory, which is the addon folder, so `Family/Libs/LibStub` resolved to
-- `Family/Family/Libs/LibStub` - one level deeper than `Libs\LibStub\LibStub.lua` looks. The
-- zip therefore carried all three libraries and the client loaded none of them, and since a
-- .toc silently skips a file it cannot find, the only symptom was Wide Family and Guild share
-- refusing to send: *this client has no serialisation libraries*. Reported from play by
-- somebody installing from CurseForge on a machine that had never had Family on it, five
-- releases after the fault shipped. Nothing on a developer's machine could ever show it -
-- `tools/FetchLibs.sh` puts the libraries where the .toc expects, so the checkout is right and
-- the release is wrong.
--
-- Both files are in the repository and both are readable here, which is the whole reason this
-- check can exist at all. See docs/LESSONS.md L-038.
--------------------------------------------------------------------------------------------

print()
print("every library the toc loads is fetched to where the toc looks")
;(function()
	local meta = io.open(ROOT .. "/.pkgmeta")
	if not meta then
		check(".pkgmeta is where the harness expects it", false, ROOT .. "/.pkgmeta")
		return
	end
	local pkgmeta = meta:read("*a")
	meta:close()

	-- The externals block, and only it. `move-folders` above it is keyed the other way -
	-- relative to the directory the package sits in rather than to the package - which is
	-- exactly the confusion that shipped, so reading the wrong block here would repeat it.
	local externals, inside = {}, false
	for line in pkgmeta:gmatch("[^\n]+") do
		if line:match("^externals:") then
			inside = true
		elseif inside then
			local destination = line:match("^%s+([^:%s]+):%s*%S")
			if destination then
				externals[destination] = true
			elseif line:match("^%S") then
				inside = false
			end
		end
	end

	check("the externals block names three libraries",
		externals["Libs/LibStub"] ~= nil and externals["Libs/LibSerialize"] ~= nil
			and externals["Libs/LibDeflate"] ~= nil,
		"read: " .. table.concat((function()
			local names = {}
			for name in pairs(externals) do names[#names + 1] = name end
			table.sort(names)
			return names
		end)(), ", "))

	for _, addon in ipairs({ "Family", "Family_UI" }) do
		local handle = io.open(ROOT .. "/addons/" .. addon .. "/" .. addon .. ".toc")
		if not handle then
			check(addon .. ".toc is where the harness expects it", false, addon)
		else
			local toc = handle:read("*a")
			handle:close()

			for line in toc:gmatch("[^\r\n]+") do
				local library = line:match("^Libs\\([^\\]+)\\")
				if library then
					check(addon .. " loads " .. library
						.. " from a path an external writes to",
						externals["Libs/" .. library] ~= nil,
						"the .toc reads Libs\\" .. library
							.. " and .pkgmeta writes it elsewhere")
				end
			end
		end
	end
end)()

--------------------------------------------------------------------------------------------
-- The deploy script says so when it is about to strip the libraries
--
-- addons/Family/Libs is gitignored - the three libraries are .pkgmeta externals that only
-- tools/FetchLibs.sh puts in a checkout. Deploy.bat mirrors with /MIR, so a source without
-- them does not merely fail to bring them: it deletes the ones the clients already have, in
-- every client at once, and reports it as a routine copy. A fresh checkout did exactly that
-- on 2026-08-27.
--
-- The warning lives in the batch file, where the mistake happens. This check reads the batch
-- file so the warning cannot quietly go away, the same way release.yml is read above.
--------------------------------------------------------------------------------------------


print()
print("a filter box gives the keyboard back when you click somewhere else")

-- Reported from play 2026-09-05: typing into a filter box on Possessions and then clicking
-- anywhere - the world included - left the keyboard in the box, so the arrow keys typed into
-- it instead of turning the character. Escape and closing the window were the only ways out.
--
-- That is the client's behaviour rather than a fault in it: an EditBox keeps focus until
-- something takes it. Taking it belongs to whoever put the box on the screen.
;(function()
	check("the client was asked whether it fires on any click, and said yes",
		Family.UI.__globalMouse == true, tostring(Family.UI.__globalMouse))

	Family.UI:Show()
	Family.UI:ShowTab("possessions")

	local box = _G.FamilyContentsSearch or _G.FamilySummarySearch
	check("there is a box to type into", box ~= nil)

	if box then
		box:SetFocus()
		check("clicking into it takes the keyboard", box:HasFocus() == true)

		-- The pointer is elsewhere, which is the case the report is about.
		box.__mouseOver = false
		fire("GLOBAL_MOUSE_DOWN")
		check("and a click anywhere else gives it back", box:HasFocus() == false)

		-- The other direction, and it is not a formality: a rule that cleared on every
		-- click would take the keyboard out of the box the moment somebody clicked into
		-- it, which is worse than the fault being fixed.
		box:SetFocus()
		box.__mouseOver = true
		fire("GLOBAL_MOUSE_DOWN")
		check("while a click on the box itself leaves it alone", box:HasFocus() == true)

		-- And the route for a client that has no such event. Less than was asked for -
		-- it cannot hear a click on the world - and it covers every click inside Family,
		-- which is where somebody who has just typed a filter clicks next.
		box.__mouseOver = false
		local window = _G.FamilyWindow
		check("the window is there to be clicked", window ~= nil)
		if window and window.__scripts.OnMouseDown then
			window.__scripts.OnMouseDown(window)
		end
		check("clicking the window itself gives the keyboard back too",
			box:HasFocus() == false)

		box.__mouseOver = nil
	end

	-- The convention, read out of the sources: a box somebody types into on purpose says
	-- `SetAutoFocus(false)`, and every one of those must also ask to be released. This is a
	-- rule about the tree rather than about a run, and it is the only thing that stops the
	-- next panel's box being the one that keeps the keyboard.
	local missing = {}
	for _, file in ipairs(UI_FILES) do
		local f = io.open(ROOT .. "/addons/Family_UI/" .. file)
		if f then
			local text = f:read("*a")
			f:close()

			local declared, released = 0, 0
			for _ in text:gmatch("SetAutoFocus%(false%)") do declared = declared + 1 end
			for _ in text:gmatch("ReleaseFocusOnClick%(") do released = released + 1 end

			-- Window.lua declares the helper and no box of its own.
			if file ~= "Window.lua" and released < declared then
				missing[#missing + 1] = string.format("%s (%d of %d)", file, released,
					declared)
			end
		end
	end

	check("every box somebody types into asks for the keyboard to be released",
		#missing == 0, table.concat(missing, ", "))
end)()
print()
print("the whole-family switch leaves its filters behind")

-- Asked for from play 2026-09-05. A filter means a different thing either side of the switch:
-- *Realm: Thunderstrike* over one character either keeps them or empties the panel, and over
-- forty it is a real narrowing - so one carried across reads as the switch having lost half the
-- family rather than as a filter still being on.
;(function()
	-- The button by its own global name, and the panel taken from it.
	--
	-- Three panels have a switch saying these words, none of them is hidden in a way a check
	-- can see, and clicking by the words alone drove the character panel while measuring this
	-- one - which passed *there is a switch* and failed every check after it. Walking up from
	-- the search box was no better: two steps of `__parent` landed on something that holds all
	-- three panels, so "this panel's realm picker" found three of them.
	local everyone = _G.FamilyProfessionsEveryone
	local box = _G.FamilyProfessionsSearch
	check("the professions panel's own switch and box are reachable by name",
		everyone ~= nil and box ~= nil)

	if everyone and box then
		local panel = everyone.__parent

		local function ours(f)
			local at = f
			while type(at) == "table" do
				if at == panel then return true end
				at = type(at.__parent) == "table" and at.__parent or nil
			end
			return false
		end

		local function realmPickers()
			local found = {}
			for _, f in ipairs(frames) do
				if f.prefix == Family.L["Realm"] and f.Choices and ours(f) then
					found[#found + 1] = f
				end
			end
			return found
		end

		local function typeInto(text)
			box:SetText(text)
			if box.__scripts.OnTextChanged then box.__scripts.OnTextChanged(box) end
		end

		typeInto("something typed")

		local pickers = realmPickers()
		check("this panel has one realm picker, not three", #pickers == 1,
			tostring(#pickers))
		for _, picker in ipairs(pickers) do picker:Choose("Fire Maw") end

		check("something is typed and something is chosen",
			box:GetText() ~= "" and pickers[1] and pickers[1]:Value() ~= nil,
			box:GetText())

		fireClick(everyone)
		check("switching empties the search box", box:GetText() == "",
			tostring(box:GetText()))

		local chosen = 0
		for _, picker in ipairs(realmPickers()) do
			if picker:Value() ~= nil then chosen = chosen + 1 end
		end
		check("and puts the pickers back to everybody", chosen == 0,
			tostring(chosen) .. " still narrowing")

		-- Both ways, because the switch is a toggle and coming back is the half somebody
		-- does without thinking about it.
		typeInto("typed again")
		fireClick(everyone)
		check("and the same on the way back", box:GetText() == "",
			tostring(box:GetText()))

		-- Left as it was found: this panel is measured again further down the file, and a
		-- block that hands the next one a panel with a word still in its box breaks checks
		-- it has nothing to do with.
		typeInto("")
		Family.UI:Refresh()
	end
end)()

print()
print("where a character was when they logged out")

-- Asked for as a column beside the hearthstone and probably more useful than it: a hearthstone
-- says where somebody chose to live and this says where they actually are.
--
-- Measured before it was built rather than assumed: `GetZoneText` and `GetSubZoneText` both
-- still answer during `PLAYER_LOGOUT` on a live client, and what is written then reaches the
-- saved variables. That probe is what made this a logout handler rather than a zone watcher.
;(function()
	local key = Family:CurrentMember()

	-- A client with a map, and with the zone calls the harness otherwise has none of. Stood
	-- up rather than relied on, for the reason the hearthstone's own block gives: a harness
	-- with no map API passes every one of these by doing nothing.
	local heldMap, heldZone, heldSub = _G.C_Map, _G.GetZoneText, _G.GetSubZoneText
	local asked = 0

	_G.C_Map = { GetAreaInfo = function(id)
		asked = asked + 1
		local areas = { [1537] = "Forgefer", [2257] = "Les Steppes Ardentes" }
		return areas[id]
	end }

	-- The client answers in its own language and its area table agrees with itself, which is
	-- the whole point of the id: the first draft of this had the zone call saying *Searing
	-- Gorge* while the area table knew only *Les Steppes Ardentes*, which is two languages
	-- inside one client and cannot happen. The lookup correctly found nothing, and the
	-- fixture was what was wrong.
	--
	-- The recorded-in-another-language case is the one the panel is checked on below, where
	-- an English word is stored beside the id and this client draws the French one.
	_G.GetZoneText = function() return "Les Steppes Ardentes" end
	_G.GetSubZoneText = function() return "Pyrox Flats" end

	Family.Database:SetMeta(key, { zone = Family.CLEAR, subzone = Family.CLEAR,
		zoneID = Family.CLEAR })

	fire("PLAYER_LOGOUT")

	local meta = Family.Database:Meta(key) or {}
	check("logging out records the zone", meta.zone == "Les Steppes Ardentes",
		tostring(meta.zone))
	check("and the subzone under it", meta.subzone == "Pyrox Flats", tostring(meta.subzone))

	-- The id, so that a French reader is told the French name of an English recording. The
	-- hearthstone's own reason, and the same machinery (L-020).
	check("and the id behind the zone, which is what makes it translatable",
		meta.zoneID == 2257, tostring(meta.zoneID))

	-- The scan costs a walk of every area id, so it is paid only when the word has moved -
	-- the rule the hearthstone already keeps. Logging out in the same place twice must not
	-- pay it twice.
	asked = 0
	fire("PLAYER_LOGOUT")
	check("logging out in the same place again costs no second search", asked == 0,
		tostring(asked) .. " ids asked about")

	-- And a new place pays it once.
	_G.GetZoneText = function() return "Forgefer" end
	_G.GetSubZoneText = function() return "" end
	fire("PLAYER_LOGOUT")

	meta = Family.Database:Meta(key) or {}
	check("moving somewhere else finds the new id", meta.zoneID == 1537,
		tostring(meta.zoneID))
	check("and a place with no subzone clears the last one rather than keeping it",
		meta.subzone == nil, tostring(meta.subzone))
	check("which cost a search, since the word had changed", asked > 0,
		tostring(asked) .. " ids asked about")

	-- Drawn, and drawn through the id: the recorded word is English and the client is
	-- answering in French, so a panel showing the recorded word would show the wrong one.
	Family.Database:SetMeta(key, { zone = "Searing Gorge", subzone = "Pyrox Flats",
		zoneID = 2257 })

	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton(Family.L["Miscellaneous"])
	Family.UI:Refresh()

	local said
	local at
	for index, column in ipairs(Family.UI.__summaryColumns or {}) do
		if column.key == "where" then at = index end
	end
	check("the miscellaneous set has a Where column", at ~= nil)

	if at then
		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true and f.memberKey == key then
				said = f.cells[at] and f.cells[at].__text
			end
		end

		check("it names the zone in the reader's own language, not the recorded one",
			said and said:find("Les Steppes Ardentes", 1, true) ~= nil, tostring(said))
		check("with the subzone under it, which has no id and stays as recorded",
			said and said:find("Pyrox Flats", 1, true) ~= nil, tostring(said))
		check("on a second line rather than run together",
			said and said:find("\n", 1, true) ~= nil, tostring(said))

		-- The column has to be allowed to use that second line, and the rows have to be
		-- tall enough to show it. Both are per-set and both are set on every row, because
		-- rows come from a pool and a cell that wrapped once would wrap under every set
		-- after it.
		local column = Family.UI.__summaryColumns[at]
		check("the column asks for the second line", column.wrap == true)

		local tall
		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true and f.memberKey == key then
				tall = f.__height
			end
		end
		check("and the row is tall enough to hold it", (tall or 0) > 18, tostring(tall))
	end

	-- **And it can be searched for**, which is what makes the column answer a question rather
	-- than only report one. Asked for from play 2026-09-05 as *who have I got in that place?*
	--
	-- The box on this row searches member names, as it does on every set, and the row has no
	-- width for a second one - so the set says what else its box looks in, the way a set says
	-- what it narrows by. One control, one question, and the set on screen decides what the
	-- answer may be found in.
	do
		local box = _G.FamilySummarySearch
		check("the summary's search box is there to type into", box ~= nil)

		local function typeInto(text)
			box:SetText(text)
			if box.__scripts.OnTextChanged then box.__scripts.OnTextChanged(box) end
		end

		local function drawing(name)
			for _, f in ipairs(frames) do
				local cell = f.cells and f.cells[1]
				if onScreen(f) and f.memberKey and cell
					and type(cell.__text) == "string"
					and cell.__text:find(name, 1, true) then
					return true
				end
			end
			return false
		end

		if box then
			local mine = Family.Database:Meta(key) or {}
			local myName = mine.name or key

			typeInto("")
			check("with nothing typed the member is drawn", drawing(myName))

			-- **The word the reader sees**, not the one that was recorded. This member's
			-- record says *Searing Gorge* and the panel draws *Les Steppes Ardentes*,
			-- because the id is what names it - so the place a player can type is the
			-- French one, and a box matching only the record would find nothing.
			typeInto("steppes")
			check("typing the place as it is drawn finds them", drawing(myName))

			-- The recorded word is searched as well. It costs nothing and it is the only
			-- thing there is for a place this client has never heard of.
			typeInto("searing")
			check("and typing it as it was recorded finds them too", drawing(myName))

			-- The subzone, which is the half with no id and reads as recorded either way.
			typeInto("pyrox")
			check("the subzone is searched as well as the zone", drawing(myName))

			typeInto("nowhere at all")
			check("and a place nobody is in finds nobody", drawing(myName) == false)

			-- On a set that says nothing about places, the same word finds nobody: the
			-- widening belongs to the set and not to the box.
			typeInto("")
			clickButton(Family.L["Overview"])
			Family.UI:Refresh()
			typeInto("steppes")
			check("while on a set that does not search places it finds nobody",
				drawing(myName) == false)

			typeInto("")
			clickButton(Family.L["Miscellaneous"])
			Family.UI:Refresh()
		end
	end

	-- **And it crosses a Wide Family link**, which is where this would otherwise have been
	-- shared and never read - the class of fault L-052 is about, met four times already. The
	-- three fields are in the `character` category; nothing said so from the far side.
	--
	-- It is also where the translation earns its keep: the sibling's record was written by a
	-- client running another language, and this reader's client names the zone in theirs. The
	-- subzone cannot be, and the check says that out loud rather than leaving it to be noticed.
	do
		local heldWide = FamilyDB.wide
		FamilyDB.wide = {
			enabled = true, id = "us", requests = {}, pendingOut = {},
			links = { ["zonefam"] = { name = "Wanderer-Thunderstrike", grants = {},
				siblings = {},
				members = {
					["Wanderer-Thunderstrike"] = {
						meta = { name = "Wanderer", realm = "Thunderstrike",
							classFile = "MAGE", level = 60, faction = "Alliance",
							-- Recorded on an English client: the word says one thing
							-- and the id says the same thing in every language.
							zone = "Searing Gorge", zoneID = 2257,
							subzone = "Pyrox Flats" },
						seen = time(),
					},
				} } },
		}
		Family.Wide:SetSibling("zonefam", "Wanderer-Thunderstrike", true)
		Family.UI:Refresh()

		local borrowed = Family.Wide:BorrowedKey("zonefam", "Wanderer-Thunderstrike")
		local theirs
		for _, f in ipairs(frames) do
			if f.cells and f.__shown == true and f.memberKey == borrowed then
				theirs = f.cells[at] and f.cells[at].__text
			end
		end

		check("a linked family's character brings where they logged out with them",
			theirs ~= nil and theirs ~= "", tostring(theirs))
		check("with the zone in this reader's language and not the one it was recorded in",
			theirs and theirs:find("Les Steppes Ardentes", 1, true) ~= nil,
			tostring(theirs))
		check("and the subzone as they recorded it, because there is no id to translate it "
			.. "from", theirs and theirs:find("Pyrox Flats", 1, true) ~= nil,
			tostring(theirs))

		Family.Wide:SetSibling("zonefam", "Wanderer-Thunderstrike", false)
		FamilyDB.wide = heldWide
	end

	-- **And that it is sent**, which the block above does not prove and looked as though it
	-- did. That one hands the sibling its record directly, so it measures how a *received*
	-- one is drawn; whether the three fields are in the `character` category is a different
	-- question, and the mutation that took them out of it failed nothing at all.
	do
		local heldWide = FamilyDB.wide
		FamilyDB.wide = { enabled = true, id = "us", requests = {}, pendingOut = {},
			links = { ["outfam"] = { name = "Nosy-Thunderstrike",
				grants = { [key] = { character = true } }, siblings = {}, members = {} } } }

		local offered = Family.Wide:Offering(FamilyDB.wide.links["outfam"])
		local sent = offered and offered[key]

		check("a member whose character facts are granted is offered at all", sent ~= nil
			and sent.meta ~= nil)
		check("and where they logged out goes with them",
			sent and sent.meta and sent.meta.zone ~= nil, tostring(sent and sent.meta
				and sent.meta.zone))
		check("the subzone too", sent and sent.meta and sent.meta.subzone ~= nil)
		check("and the id, which is the whole of what makes the zone translatable",
			sent and sent.meta and sent.meta.zoneID ~= nil)

		FamilyDB.wide = heldWide
	end

	_G.C_Map, _G.GetZoneText, _G.GetSubZoneText = heldMap, heldZone, heldSub
	clickButton(Family.L["Overview"])
	Family.UI:Refresh()
end)()

print()
print("the summary's filter bar is the shared one")

-- The last panel building its own. Two had grown one each, separately, and this was the second
-- of the two - so this buys no feature and stops the fifth idea of what a filter bar is.
--
-- The evidence a refactor wants is the checks that were already there passing unchanged, and
-- they do: the level boxes keep their names, pointed at the widget's own. What is added here is
-- what those cannot say - that the bar *is* the widget, and that it is the one without a realm
-- picker.
;(function()
	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton(Family.L["Overview"])
	Family.UI:Refresh()

	local filters = Family.UI.__summaryFilters
	check("the summary asks the widget for its filters", filters ~= nil
		and type(filters.Passes) == "function" and type(filters.Reset) == "function")

	if filters then
		-- **And the one without a realm picker.** Not a preference: this row also carries a
		-- search box, the set's own narrowing picker and the count of what is hidden, and a
		-- picker 130 wide takes it past the 740 the row has.
		check("without a realm picker, which this row has no width for",
			filters.realmButton == nil)

		-- The row still fits, which is the reason the picker was left out.
		local hint = 34
		local room = 740 - 4 - hint - 10 - 150 - 12 - filters:Width() - 12 - 150
		check("so the row still has the width it needs", room >= 0, tostring(room))

		-- And it filters. Driven through the widget's own controls, which is what a player
		-- touches.
		local classButton = filters.classButton
		check("the class picker is the widget's", classButton ~= nil)

		-- The two classes are put on the record rather than assumed to be there. A picker
		-- offers only what the family actually has, and `Reconcile` drops a choice that is
		-- no longer on offer - so a check that chooses a class this family happens not to
		-- hold chooses nothing, and then everything passes and the check reads as a filter
		-- that does not filter. That is what it did.
		Family.Database:SetMeta("Filtered-Fire Maw", { name = "Filtered", realm = "Fire Maw",
			classFile = "MAGE", level = 60, faction = "Alliance" })
		Family.Database:SetMeta("Other-Fire Maw", { name = "Other", realm = "Fire Maw",
			classFile = "ROGUE", level = 60, faction = "Alliance" })

		local mage = { name = "Filtered", realm = "Fire Maw", classFile = "MAGE", level = 60 }
		local rogue = { name = "Other", realm = "Fire Maw", classFile = "ROGUE", level = 60 }

		check("with nothing chosen both pass",
			filters:Passes(mage) and filters:Passes(rogue))

		if classButton then
			classButton:Choose("MAGE")
			check("choosing a class keeps it", filters:Passes(mage))
			check("and drops the others", filters:Passes(rogue) == false)
			check("and the bar says it is narrowing", filters:Active())
			classButton:Choose(Family.UI.ANY)
		end

		-- The level boxes kept their names, which is what lets every check written before
		-- this drive the new bar without being touched.
		check("the level boxes are still reachable by the names they had",
			_G.FamilySummaryLevelMin == filters.minBox
				and _G.FamilySummaryLevelMax == filters.maxBox)

		filters:Reset()
		check("resetting puts everybody back", filters:Active() == false)

		Family.Database:Forget("Filtered-Fire Maw")
		Family.Database:Forget("Other-Fire Maw")

		-- **No second bar is built to measure this against**, and that is worth a line.
		-- Standing one up - even parented to UIParent, where nothing shows it - turned a
		-- check further down the file red: it opens the summary's class list by the words
		-- on the button, and found the spare bar's instead. The same trap as a realm
		-- picker created and hidden, arriving from the other side.
		--
		-- Nothing is lost by not measuring it. That the picker is absent is checked above,
		-- and that the row fits is checked above that, which is the property the absence
		-- exists for. The difference between the two widths is arithmetic.
	end
end)()

print()
print("the log writes down which zone each heading is")

-- The other half, and it was uncovered: the mutation that made the scanner record no zone ids
-- at all failed nothing, because the block below hands the siblings a `zones` table ready made.
-- What is drawn and what is recorded are two claims.
;(function()
	local key = Family:CurrentMember()
	local heldMap, heldAreas = _G.C_Map, FamilyDB.areas
	local heldQuests = FamilyDB.quests

	_G.C_Map = { GetAreaInfo = function(id)
		if id == 42 then return "Elwynn Forest" end
	end }
	FamilyDB.areas = {}
	FamilyDB.quests = {}

	Family.Quests:Scan()

	local log = (Family.Database:Payload(key) or {}).quests
	check("the log is there to look at", log ~= nil and log.entries ~= nil)
	check("and carries the id of a zone this client can name",
		log and log.zones and log.zones["Elwynn Forest"] == 42,
		log and log.zones and tostring(log.zones["Elwynn Forest"]))

	-- One entry per zone and not per quest: two quests in Elwynn share the row. Counted so
	-- that a table growing per quest would be visible rather than merely wasteful.
	local zones = 0
	for _ in pairs((log or {}).zones or {}) do zones = zones + 1 end
	check("one entry per zone rather than one per quest", zones == 1, tostring(zones))

	-- A zone the client cannot name is left out rather than stored as a nothing: a table of
	-- falses would cross a Wide Family link saying nothing in more bytes than nothing takes.
	check("and a zone it cannot name is not in the table at all",
		log and log.zones and log.zones["Westfall"] == nil,
		log and log.zones and tostring(log.zones["Westfall"]))

	-- And the titles, by id, in this client's words. The client will not describe a quest the
	-- server never gave it, so a sibling's quest can only ever be named out of what somebody
	-- on this account has already read - which means the reading has to write it down.
	local store = Family.Names:QuestStore()
	check("the scan writes down what it read a quest was called", store ~= nil)

	local named, missing = 0, nil
	for _, quest in ipairs((log or {}).entries or {}) do
		if quest.id then
			if store and store[quest.id] == quest.title then
				named = named + 1
			else
				missing = missing or (tostring(quest.id) .. " -> "
					.. tostring(store and store[quest.id]))
			end
		end
	end
	check("every quest it found an id for is in the store under that id",
		missing == nil, missing)
	check("and there was at least one to write down", named > 0, tostring(named))

	-- Per language, because this store is id to word. The areas store is word to id and a
	-- second language only adds keys to it; this one would overwrite, and a player who
	-- switched their client would read every quest in the language they left.
	check("filed under the language this client is running",
		FamilyDB.quests[Family.locale] == store,
		tostring(Family.locale))

	_G.C_Map, FamilyDB.areas = heldMap, heldAreas
	FamilyDB.quests = heldQuests
end)()

print()
print("one zone, however many languages recorded it")

-- Alberto's question, 2026-09-05: in whole-family mode, does one quest become five - one per
-- language - so that *who is on this quest* cannot be asked at all?
--
-- The quest rows already knew: they key by quest id and fall back to the title only where there
-- is none. **Their headings did not.** A category is a word, so one zone appeared as two
-- headings the moment two clients in two languages shared a family, and the quests under it
-- were split between them.
;(function()
	local held = FamilyDB.wide
	local heldMap = _G.C_Map
	local heldAreas = FamilyDB.areas

	-- This reader's client speaks French and can name the zone from its id, which is the whole
	-- of the mechanism: the id is the same number in every language and the word is not.
	_G.C_Map = { GetAreaInfo = function(id)
		if id == 3483 then return "Peninsule des Flammes infernales" end
	end }
	FamilyDB.areas = {}

	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["langfam"] = { name = "Polyglot-Thunderstrike", grants = {}, siblings = {},
			members = {
				-- Recorded on an English client.
				["Englishman-Thunderstrike"] = {
					meta = { name = "Englishman", realm = "Thunderstrike",
						classFile = "MAGE", level = 70, faction = "Alliance" },
					payload = { quests = { seen = time(),
						zones = { ["Hellfire Peninsula"] = 3483 },
						entries = { { title = "The Longbeards", level = 61, id = 9001,
							category = "Hellfire Peninsula" } } } },
					seen = time(),
				},
				-- And the same zone, recorded on a French one. A different word, the same
				-- id, and the same place.
				["Francais-Thunderstrike"] = {
					meta = { name = "Francais", realm = "Thunderstrike",
						classFile = "ROGUE", level = 70, faction = "Alliance" },
					payload = { quests = { seen = time(),
						zones = { ["Peninsule des Flammes infernales"] = 3483 },
						entries = { { title = "Une autre quete", level = 61, id = 9002,
							category = "Peninsule des Flammes infernales" } } } },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("langfam", "Englishman-Thunderstrike", true)
	Family.Wide:SetSibling("langfam", "Francais-Thunderstrike", true)

	Family.UI:Show()
	Family.UI:ShowTab("character")
	check("the quests section can be opened", clickButton("Quests"))
	if not drawnText("The Longbeards") then clickButton("Whole family") end
	Family.UI:Refresh()

	check("both siblings' quests are drawn", drawnText("The Longbeards")
		and drawnText("Une autre quete"))

	-- The headings, read off the rows. A zone heading is a row with nothing in its middle.
	local headings = {}
	for _, f in ipairs(frames) do
		local left = type(f.left) == "table" and f.left.__text
		local middle = type(f.middle) == "table" and f.middle.__text
		if onScreen(f) and type(left) == "string" and left ~= ""
			and (middle == nil or middle == "") then
			headings[#headings + 1] = left
		end
	end
	local said = table.concat(headings, " | ")

	-- **One heading, not two.** This is the fault, and it is the reason the check exists.
	local hellfire = 0
	for _, heading in ipairs(headings) do
		if heading:find("Flammes infernales", 1, true)
			or heading:find("Hellfire", 1, true) then
			hellfire = hellfire + 1
		end
	end
	check("one zone is one heading, whichever language each record was written in",
		hellfire == 1, tostring(hellfire) .. " headings: " .. said)

	check("named in the reader's own language",
		said:find("Peninsule des Flammes infernales", 1, true) ~= nil, said)
	check("and not in the one the English record used",
		said:find("Hellfire Peninsula", 1, true) == nil, said)

	-- **The per-member view too**, which is a different function and was not covered: the
	-- mutation that stopped it translating failed nothing at all. A sibling's own quest page
	-- has the same problem as the family one, minus the grouping - their zone headings would
	-- read in their language on our screen.
	do
		local key = Family.Wide:BorrowedKey("langfam", "Englishman-Thunderstrike")
		local lines = Family.UI:QuestLines(key, Family.UI:Meta(key), nil)

		local said = ""
		for _, line in ipairs(lines or {}) do
			said = said .. " " .. tostring(line.left)
		end

		check("a sibling's own quest page names the zone in the reader's language",
			said:find("Peninsule des Flammes infernales", 1, true) ~= nil, said)
		check("and not in the one their client wrote",
			said:find("Hellfire Peninsula", 1, true) == nil, said)
	end

	Family.Wide:SetSibling("langfam", "Englishman-Thunderstrike", false)
	Family.Wide:SetSibling("langfam", "Francais-Thunderstrike", false)
	FamilyDB.wide = held
	_G.C_Map = heldMap
	FamilyDB.areas = heldAreas
	Family.UI:Refresh()
end)()

print()
print("a quest called what this client calls it")

-- The other half of the language question, and the half the zone work left behind: the heading
-- read in the reader's language and the quest under it still read in whoever recorded it. A row
-- half translated looks like a fault rather than a limit.
;(function()
	local heldLink, heldLog = _G.GetQuestLink, _G.C_QuestLog
	local heldWide, heldQuests = FamilyDB.wide, FamilyDB.quests
	FamilyDB.quests = {}

	-- A client that speaks French and will name a quest it is not on. Stood up rather than
	-- relied on: the harness's own stub answers only for quests in the log, which is the one
	-- thing that was ever measured.
	_G.GetQuestLink = function(id)
		if id == 9001 then
			return "|cffffff00|Hquest:9001:61|h[Les Longues-Barbes]|h|r"
		end
	end
	_G.C_QuestLog = nil

	check("a quest is named by the client from its id",
		Family.Names:Quest(9001, "The Longbeards") == "Les Longues-Barbes",
		tostring(Family.Names:Quest(9001, "The Longbeards")))

	check("and one it will not name falls back to what was recorded",
		Family.Names:Quest(4242, "The Longbeards") == "The Longbeards")

	check("with nothing recorded either, it answers nothing rather than a guess",
		Family.Names:Quest(4242, nil) == nil)

	-- The direct route where a build has it, tried before the link. Both are read back
	-- rather than assumed, which is what the scanner already does with this call.
	--
	-- Asked with the store emptied, because the store now answers first and would otherwise
	-- hide which of the two live routes ran.
	FamilyDB.quests = {}
	_G.C_QuestLog = { GetTitleForQuestID = function(id)
		if id == 9001 then return "Direkt benannt" end
	end }
	check("a build that names a quest outright is asked first",
		Family.Names:Quest(9001, "The Longbeards") == "Direkt benannt",
		tostring(Family.Names:Quest(9001, "The Longbeards")))

	-- And whatever answered is kept, so the next character to want it does not ask.
	check("and what it said is written down",
		(Family.Names:QuestStore() or {})[9001] == "Direkt benannt",
		tostring((Family.Names:QuestStore() or {})[9001]))

	_G.C_QuestLog = nil

	-- The case the whole store exists for: a client that will say nothing at all about this
	-- quest, because the server never described it to them. That is every sibling's quest,
	-- and it is why no live route can be the answer on its own.
	_G.GetQuestLink = function() end
	check("a quest no live route will name is read out of the store",
		Family.Names:Quest(9001, "The Longbeards") == "Direkt benannt",
		tostring(Family.Names:Quest(9001, "The Longbeards")))

	-- Somebody else's language is not an answer. A store written while the client ran French
	-- must not be read back by the same client running English.
	do
		local held = Family.locale
		Family.locale = "esES"
		check("and not out of the language the client used to be running",
			Family.Names:Quest(9001, "The Longbeards") == "The Longbeards",
			tostring(Family.Names:Quest(9001, "The Longbeards")))
		Family.locale = held
	end

	FamilyDB.quests = {}
	_G.GetQuestLink = function(id)
		if id == 9001 then
			return "|cffffff00|Hquest:9001:61|h[Les Longues-Barbes]|h|r"
		end
	end

	-- And on the panel, for a sibling - which is the case all of this is for.
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["namefam"] = { name = "Speaker-Thunderstrike", grants = {}, siblings = {},
			members = {
				["Speaker-Thunderstrike"] = {
					meta = { name = "Speaker", realm = "Thunderstrike",
						classFile = "MAGE", level = 70, faction = "Alliance" },
					payload = { quests = { seen = time(), entries = {
						{ title = "The Longbeards", level = 61, id = 9001,
							category = "Hellfire Peninsula" },
					} } },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("namefam", "Speaker-Thunderstrike", true)

	local key = Family.Wide:BorrowedKey("namefam", "Speaker-Thunderstrike")
	local lines = Family.UI:QuestLines(key, Family.UI:Meta(key), nil)

	local said = ""
	for _, line in ipairs(lines or {}) do
		said = said .. " " .. tostring(line.middle)
	end

	check("a sibling's quest page names it as this client does",
		said:find("Les Longues-Barbes", 1, true) ~= nil, said)
	check("and not as their client wrote it",
		said:find("The Longbeards", 1, true) == nil, said)

	-- **And the whole-family view**, which is a different function and was not covered: the
	-- mutation that made it keep the recorded title failed nothing at all. That view groups by
	-- the quest id, so what changes here is only what the row is called - but a row called by
	-- one client's word in a list built for another is the fault this exists to remove.
	do
		Family.UI:Show()
		Family.UI:ShowTab("character")
		clickButton("Quests")
		if not drawnText("Les Longues-Barbes") then clickButton("Whole family") end
		Family.UI:Refresh()

		check("the whole-family view names it as this client does",
			drawnText("Les Longues-Barbes"))
		check("and not as the record has it", drawnText("The Longbeards") == false)
	end

	Family.Wide:SetSibling("namefam", "Speaker-Thunderstrike", false)
	FamilyDB.wide, FamilyDB.quests = heldWide, heldQuests
	_G.GetQuestLink, _G.C_QuestLog = heldLink, heldLog
	Family.UI:Refresh()
end)()

print()
print("the deploy script warns before it mirrors a source with no libraries")
;(function()
	local f = io.open(ROOT .. "/tools/Deploy.bat")
	if not f then
		check("Deploy.bat is where the harness expects it", false,
			ROOT .. "/tools/Deploy.bat")
		return
	end
	local bat = f:read("*a")
	f:close()

	check("Deploy.bat tests the source for LibStub",
		bat:match('if exist "%%SRC%%\\%%ADDON_1%%\\Libs\\LibStub\\LibStub%.lua" set "LIBS=1"') ~= nil,
		"nothing else distinguishes a fetched checkout from a bare one")

	check("Deploy.bat warns when the source has none",
		bat:match('if not defined LIBS %(') ~= nil and bat:match("WARNING") ~= nil,
		"without it /MIR removes all three from every client and says nothing")

	-- This file is the one in the repository that names a particular machine, and it is in a
	-- public one. The share line carried a real LAN address from the seed commit until
	-- 2026-08-28 because nothing was looking. An address is the part that is worth catching:
	-- a drive letter says little, four numbers and dots say where somebody's network lives.
	local address = bat:match("%f[%d](%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?)%f[%D]")
	check("Deploy.bat names no real host",
		address == nil,
		address and ("it has " .. address .. " in it - the committed copy is the template, and "
			.. "the machine's own paths belong on the machine") or nil)

	-- And no person. The Google Drive destination added 2026-09-05 is the line most likely to
	-- arrive carrying one - Drive for Desktop is usually reached through somebody's home
	-- folder - and a name in a public repository is the same kind of thing as the LAN address
	-- above. The template uses the default mount point, which names nobody.
	--
	-- The first thing this caught was the comment beside that line, which spelled the home
	-- path out as an example. A guard that reads the whole file reads the prose too, and the
	-- example was not worth keeping once it was the only thing tripping it.
	check("nor anybody's user folder",
		bat:lower():find("\\users\\", 1, true) == nil,
		"a Drive or install path under C:\\Users names the person who runs it")

	-- The drive copy has a guard of its own, and it is not optional.
	--
	-- `:deploy` refuses anything that does not end in Interface\AddOns before it points /MIR
	-- at it, and that refusal is the whole reason that route exists. The drive is not a client
	-- and its folder is not called that, so it needed a second route - and a second route with
	-- no guard would be a mirroring delete aimed wherever a placeholder happened to point.
	check("Deploy.bat has a route for the drive copy",
		bat:match("\n:todrive\n") ~= nil,
		"the drive copy must not go through :deploy, whose guard is about clients")
	check("and it refuses a folder that is not an Addons folder",
		bat:match('if /i not "%%TAIL%%"=="\\Addons"') ~= nil,
		"/MIR deletes what it does not recognise, so the destination is checked first")
end)()

--------------------------------------------------------------------------------------------
-- The release gate reads the live checklist
--
-- docs/SMOKE.md is the only gate that runs against a real client. It said in bold that a
-- release with no row was a release that was not checked, and that RELEASING.md treated that
-- as a stop - and nothing in the tree had ever heard of the file. v1.0.0-beta.1 went out
-- that way: a rule written down, enforced by nobody.
--
-- No check can tell whether a client was launched. This one tells whether release.sh still
-- refuses to tag a version nobody wrote a row for, which is the part a script can hold. Read
-- the same way release.yml and Deploy.bat are read above.
--------------------------------------------------------------------------------------------

print()
print("the release script refuses a version with no live-check row")
;(function()
	local f = io.open(ROOT .. "/tools/release.sh")
	if not f then
		check("release.sh is where the harness expects it", false, ROOT .. "/tools/release.sh")
		return
	end
	local sh = f:read("*a")
	f:close()

	check("release.sh reads docs/SMOKE.md",
		sh:match('smoke="docs/SMOKE%.md"') ~= nil,
		"the live checklist is the only thing standing between a tag and an unchecked client")

	check("release.sh stops when no row records the version",
		sh:match("%[%[ %-n \"%$clients\" %]%] |") ~= nil,
		"without it the gate reads the file and then tags anyway")

	check("release.sh holds a full release to all three clients",
		sh:match("%*alpha%*|%*beta%*") ~= nil and sh:match("Anniversary:anni") ~= nil,
		"a pre-release needs one row; the version everybody is offered by default needs three")

	local g = io.open(ROOT .. "/docs/SMOKE.md")
	if not g then
		check("SMOKE.md is where release.sh expects it", false, ROOT .. "/docs/SMOKE.md")
		return
	end
	local md = g:read("*a")
	g:close()

	check("SMOKE.md carries the Runs table the gate parses",
		md:match("| Version | Client | Date | By | Result |") ~= nil,
		"release.sh reads the first cell of every row in it")

	-- L-012: SMOKE.md said RELEASING.md treated a missing row as a stop, and RELEASING.md had
	-- never heard of the file. A document that names another as its enforcer is making a claim
	-- about a second file, and it is worth what that file says. Read both ends together.
	local r = io.open(ROOT .. "/docs/RELEASING.md")
	if not r then
		check("RELEASING.md is where the harness expects it", false, ROOT .. "/docs/RELEASING.md")
		return
	end
	local rel = r:read("*a")
	r:close()

	check("RELEASING.md names the live check it is said to enforce",
		rel:match("SMOKE%.md") ~= nil,
		"the claim and the mechanism have to fail together or the claim outlives it")
end)()

--------------------------------------------------------------------------------------------
-- Two things the live check found that no check could have
--
-- Both were reported from a real client during the 1.0.0-beta.1 pass, which is the whole
-- argument for docs/SMOKE.md: the harness draws into a stub that has no idea how wide a
-- word is, so a heading drawn through the column beside it is invisible here and obvious
-- there. What can be held is the guard each fix put in. Neither of these is proof the
-- screen is right - that is the screenshot's job, the same way textures are - but a guard
-- that is deleted stops being a fix, and that part is readable.
--------------------------------------------------------------------------------------------

print()
print("the fixes the live check asked for are still in place")
;(function()
	local f = io.open(ROOT .. "/addons/Family_UI/Wide.lua")
	if not f then
		check("Wide.lua is where the harness expects it", false, ROOT .. "/addons/Family_UI/Wide.lua")
		return
	end
	local wide = f:read("*a")
	f:close()

	-- nextRow hands back a row whose text has width 0, which grows to fit whatever it is
	-- given. The column headings start at NAME_WIDTH, so the label above the names has to be
	-- bounded or it runs under the first of them.
	check("the borrowed grid's name heading is bounded",
		wide:match("theirLabels%.text:SetWidth%(NAME_WIDTH") ~= nil,
		"unbounded it grows past NAME_WIDTH and is drawn through the first column heading")

	local g = io.open(ROOT .. "/addons/Family_UI/Summary.lua")
	if not g then
		check("Summary.lua is where the harness expects it", false,
			ROOT .. "/addons/Family_UI/Summary.lua")
		return
	end
	local sum = g:read("*a")
	g:close()

	-- The stamp only reaches the cell if the row entry's own field is handed to it; meta has
	-- no idea when it arrived.
	check("the summary hands a borrowed member's stamp to its cells",
		sum:match("produce%(member%.meta, member%.key, member%.seen%)") ~= nil,
		"without it CELL.seen cannot know when a sibling was last shared and falls to a dash")

	-- The string became a format string when the panel was translated: the word and the
	-- date cannot stay welded together in a language that puts them the other way round.
	-- What is checked is unchanged - that the cell says "shared" and hands it the stamp.
	check("and Last seen says when a sibling was shared",
		sum:match('L%["|cff888888shared|r %%s"%], UI:Ago%(sharedAt%)') ~= nil,
		"a borrowed row's date is somebody else's exchange, not our own sighting")

	-- Reported live: clicking a mail count on Activity left the letters drawn on Currencies.
	-- The unfold hangs off the **member** column, which every set has, so nothing about it was
	-- ever tied to the set that owns the figure that opens it.
	check("the letters are drawn only where the mail column is",
		sum:match("if openMail == member%.key and showsMail then") ~= nil,
		"the unfold is drawn on every set, including the ones with no mail on them")

	-- Derived from the columns rather than from a set's name, so that moving the mail column
	-- takes its unfold with it instead of leaving this behind for somebody to find the next
	-- time a panel is rearranged. Naming the set here would fix the bug and plant the next one.
	check("and which set that is comes from the columns rather than a set's name",
		sum:match('if column%.key == "mail" then showsMail = true end') ~= nil
			and sum:match('currentSet%.id == "activity"') == nil,
		"gated on a hardcoded set id, which moves the fault rather than removing it")
end)()

--------------------------------------------------------------------------------------------
-- The translations
--
-- Three things can be wrong with a locale file and none of them is visible to a person who
-- does not speak the language, which is why they are checked here rather than trusted.
--
--   1. A key nothing asks for any more. English strings are the keys, so editing an English
--      sentence silently orphans its four translations and the panel quietly reverts to
--      English. The orphan set is exactly what went stale.
--   2. A translation that does not fit. German runs about a third longer than English and
--      Russian is not far behind; a label calibrated for "Last seen" in 95 pixels has no
--      room for "Zuletzt gesehen". Overrun text is drawn through whatever is beside it.
--   3. A format specifier that does not match its key. "%d of %d" translated with one %d
--      is not a cosmetic fault - string.format raises, and the panel dies mid-draw.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- Columns that hold their own headings
--
-- The rule the panels rely on when a translation is longer than the English it replaced:
-- widen the column, take the room from whatever has slack, and never put a column back
-- below its own heading. Driven here with headings far longer than any English one, because
-- that is the case English can never produce and therefore the case nothing else would test.
--------------------------------------------------------------------------------------------

print()
print("columns that hold their own headings")
;(function()
	local measure = CreateFrame("Frame"):CreateFontString()

	local function widthsFor(labels, widths, budget)
		local columns = {}
		for index, label in ipairs(labels) do
			columns[index] = { label = label, width = widths[index] }
		end
		UIPrivate:FitColumns(columns, budget, measure)
		local out, total = {}, 0
		for index, column in ipairs(columns) do
			out[index] = column.drawWidth
			total = total + column.drawWidth
		end
		return out, total, columns
	end

	-- English as it ships: everything already fits, so nothing should move.
	local out = widthsFor({ "Level", "Money", "Last seen" }, { 50, 145, 95 }, 714)
	check("a column wide enough for its heading is left alone",
		out[1] == 50 and out[2] == 145 and out[3] == 95,
		table.concat({ out[1], out[2], out[3] }, ", "))

	-- German for the same three, roughly. The first no longer fits the 50 it was given.
	local out2, _, columns2 = widthsFor(
		{ "Gegenstandsstufe", "Geld", "Zuletzt gesehen" }, { 50, 145, 95 }, 714)
	measure:SetText("Gegenstandsstufe")
	check("a column too narrow for its heading is widened to hold it",
		out2[1] >= measure:GetStringWidth(),
		out2[1] .. " for a heading needing " .. measure:GetStringWidth())

	-- And the room comes from somewhere: the row does not simply grow past its budget.
	local labels, widths = {}, {}
	for index = 1, 7 do
		labels[index] = "Eine sehr lange deutsche Spaltenueberschrift"
		widths[index] = 100
	end
	local out3, total3, columns3 = widthsFor(labels, widths, 500)
	check("a row that cannot fit is not allowed to grow without limit",
		total3 <= 500 or total3 == select(2, widthsFor(labels, widths, math.huge)),
		"total " .. total3)

	-- The one thing that must never happen, which is the fault this exists to fix.
	local worst = nil
	for index, column in ipairs(columns3) do
		measure:SetText(column.label)
		if column.drawWidth < measure:GetStringWidth() then worst = index end
	end
	check("and no column is ever left narrower than its own heading", worst == nil,
		worst and ("column " .. worst .. " was") or "")

	-- Rows of buttons, which had the same fault and now share the same answer. This is the
	-- one the live pass found: "Skill needed" fits the 110 pixels it was given and
	-- "Compétence requise" does not, and the button drew its label into the button beside it.
	do
		local function row(labels, minimum, budget)
			local buttons, widths = {}, {}
			for index, label in ipairs(labels) do
				local b = CreateFrame("Button")
				local fs = b:CreateFontString()
				fs:SetText(label)
				b.GetFontString = function() return fs end
				buttons[index] = b
			end
			UIPrivate:LayOutRow(buttons, minimum, 4, 0, nil, budget)
			local total = 0
			for index, b in ipairs(buttons) do
				widths[index] = b:GetWidth()
				total = total + widths[index]
			end
			return widths, total, buttons
		end

		local short = row({ "Difficulty", "Item level", "Skill needed" }, 110)
		check("a button wide enough for its label keeps the width the design gave it",
			short[1] == 110 and short[2] == 110 and short[3] == 110,
			table.concat({ short[1], short[2], short[3] }, ", "))

		local long, _, buttons = row(
			{ "Difficulté", "Niveau d'objet", "Compétence requise" }, 110)
		local fs = buttons[3]:GetFontString()
		check("a button too narrow for its label is widened to hold it",
			long[3] > fs:GetStringWidth(),
			long[3] .. " for a label needing " .. fs:GetStringWidth())

		-- Placed one after the next, so widening one moves the rest along rather than
		-- letting them overlap. That is the fault itself: the old row stepped by a fixed
		-- 114 pixels whatever the buttons turned out to be, so a 117-pixel button was
		-- overlapped by the one after it.
		do
			local placed = {}
			local wide = {}
			-- The long one first, deliberately. If it is last, nothing follows it to be
			-- drawn over and a row that steps by a fixed width passes anyway.
			for index, label in ipairs({ "Compétence requise", "Difficulté",
				"Niveau d'objet" }) do
				local b = CreateFrame("Button")
				local fs = b:CreateFontString()
				fs:SetText(label)
				b.GetFontString = function() return fs end
				wide[index] = b
			end
			UIPrivate:LayOutRow(wide, 110, 4, 0, function(button, at, width)
				placed[#placed + 1] = { at = at, width = width }
			end)

			local overlap = nil
			for index = 2, #placed do
				local previous = placed[index - 1]
				if placed[index].at < previous.at + previous.width then
					overlap = index
				end
			end
			check("and the buttons after it move along rather than overlapping",
				overlap == nil and #placed == 3,
				overlap and ("button " .. overlap .. " starts inside the one before it")
					or ("placed " .. #placed))
		end

		-- A row with a hard budget shares it out, the way the summary's set buttons must.
		local squeezed, total = row(
			{ "Aperçu", "Sacs", "Activité", "Métiers", "Monnaies", "Artisanat", "Divers" },
			92, 664)
		check("a row with a budget is held to it", total <= 664 + 7 * 4, "total " .. total)

		-- The fault this has to prevent: a row that grows until it runs off the panel and
		-- takes whatever sits beside it with it. Every row in Family is given a budget, so
		-- no button may be placed past the room its row was told it has.
		do
			local placed = {}
			local wide = {}
			local labels = { "Sehr lange Beschriftung", "Noch eine lange Beschriftung",
				"Und eine dritte davon", "Sowie eine vierte" }
			for index, label in ipairs(labels) do
				local b = CreateFrame("Button")
				local fs = b:CreateFontString()
				fs:SetText(label)
				b.GetFontString = function() return fs end
				wide[index] = b
			end
			UIPrivate:LayOutRow(wide, 110, 4, 0, function(button, at, width)
				placed[#placed + 1] = at + width
			end, 500)

			local past = nil
			for index, right in ipairs(placed) do
				if right > 500 then past = index end
			end
			-- Squeezing stops at the labels, so a row can legitimately be over budget -
			-- what it may not do is be over budget *silently*, and that is the warning.
			local complained = false
			for _, line in ipairs(DEFAULT_CHAT_FRAME.messages) do
				if line:find("longer than the room in this language", 1, true) then
					complained = true
				end
			end
			check("a row that cannot fit its budget says so rather than running off the panel",
				past == nil or complained,
				"button " .. tostring(past) .. " is past the edge and nothing was said")
		end
	end

	-- The room under a table for the captions beneath it, which is not a constant either.
	do
		local oneLine = UIPrivate:CaptionRoom(12, 0)
		local twoLines = UIPrivate:CaptionRoom(24, 0)
		check("a caption that wraps to two lines is given more room than one that does not",
			twoLines > oneLine, oneLine .. " then " .. twoLines)
		check("and the extra room is the extra line, not a guess at it",
			twoLines - oneLine == 12, tostring(twoLines - oneLine))

		local withNote = UIPrivate:CaptionRoom(12, 24)
		check("a note above the footer is given room of its own",
			withNote > oneLine, oneLine .. " then " .. withNote)

		-- The one that is easy to leave out: a clear line between the caption and the last
		-- row of the table, so the two do not read as one block of text.
		check("and the table is left clear of the caption",
			UIPrivate:CaptionRoom(12, 0, 8, 4, 8) - UIPrivate:CaptionRoom(12, 0, 8, 4, 0) == 8,
			"no gap is being left between the table and what sits under it")
	end

	-- Taking room back comes off the column with the most to spare, not off the tightest.
	local out4 = widthsFor({ "Level", "Money" }, { 50, 300 }, 200)
	check("room is taken from the column with the most to spare",
		out4[1] > out4[2] or out4[2] < 300, out4[1] .. ", " .. out4[2])
end)()

--------------------------------------------------------------------------------------------
-- Captions that stop at the edge of the panel
--
-- A font string given a left edge and never a right one has no width, so it does not wrap:
-- it grows to whatever its sentence happens to be and keeps going past the border. English
-- was short enough to hide it on the Options panel; French ran the guild-sharing note
-- straight through the right-hand side of the window.
--
-- Only prose is required to be bounded. A title, a column heading or a two-word hint is
-- meant to be its own length and has nothing to run into.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- Text a player can see that nobody translated
--
-- Three strings reached a French client in English because a bulk edit matched the call
-- shapes somebody thought of rather than the ones that existed: every relative date, a
-- talent grid's tier labels, and the word "empty" on an unfilled gear slot. Each was found
-- by a person looking at the screen (L-014).
--
-- This reads the sources properly - tracking comments and strings rather than pattern
-- matching over them, which is what produced the false positives that made the earlier
-- sweeps easy to wave through - and insists that anything that reads like a sentence is
-- either wrapped for translation or named below as deliberately not.
--------------------------------------------------------------------------------------------

print()
print("text a player can see that nobody translated")
;(function()
	-- Values that are compared against, keyed on, or sent over the wire. Translating any of
	-- these would break the thing that reads them back.
	local INTERNAL = {
		["asked for"] = true, ["on request"] = true, ["a grant changed"] = true,
		["guild changed"] = true, ["data source"] = true, ["seen in game"] = true,
		["expected"] = true, ["both"] = true, ["classic"] = true,
		["client has the symbol"] = true, ["client lacks the symbol"] = true,
		["Equipped gear"] = true, ["not in a guild"] = true,
		["the last one was offline"] = true,
	}

	-- Every literal in a file, with comments and nested quotes handled, because "a" .. "b"
	-- read by a pattern looks like the string ' .. '.
	local function literalsOf(text)
		local out = {}
		local i, n = 1, #text
		while i <= n do
			local two = text:sub(i, i + 1)
			if two == "--" then
				local stop = text:find("\n", i, true) or (n + 1)
				i = stop
			elseif text:sub(i, i) == '"' then
				local start = i
                local scan = i + 1
				while scan <= n do
					local c = text:sub(scan, scan)
					if c == "\\" then scan = scan + 2
					elseif c == '"' then break
					else scan = scan + 1 end
				end
				out[#out + 1] = { value = text:sub(start + 1, scan - 1), at = start }
				i = scan + 1
			else
				i = i + 1
			end
		end
		return out
	end

	-- The spans a literal may sit inside and be fine: a lookup, or narration that is English
	-- on purpose.
	local function spansOf(text, opener)
		local out, at = {}, 1
		while true do
			local from = text:find(opener, at)
			if not from then break end
			local open = text:find("[%[%(]", from)
			if not open then break end
			local close = text:sub(open, open) == "[" and "]" or ")"
			local depth, j = 1, open + 1
			while depth > 0 and j <= #text do
				local c = text:sub(j, j)
				if c == text:sub(open, open) then depth = depth + 1
				elseif c == close then depth = depth - 1 end
				if depth > 0 then j = j + 1 end
			end
			out[#out + 1] = { open, j }
			at = j + 1
		end
		return out
	end

	local bare = {}
	for _, name in ipairs { "Window", "MemberPicker", "ChoicePicker", "Tooltip", "Summary",
		"Talents", "Contents", "Professions", "Character", "Quests", "Wide", "Guild",
		"Broker", "Options", "About", "Slash" } do
		local path = "addons/Family_UI/" .. name .. ".lua"
		local f = io.open(ROOT .. "/" .. path)
		if f then
			local text = f:read("*a")
			f:close()

			local safe = {}
			for _, opener in ipairs { "%f[%w_]L%[", "Family:Debug%(" } do
				for _, span in ipairs(spansOf(text, opener)) do safe[#safe + 1] = span end
			end

			for _, literal in ipairs(literalsOf(text)) do
				local covered = false
				for _, span in ipairs(safe) do
					if literal.at >= span[1] and literal.at <= span[2] then covered = true end
				end

				if not covered and not INTERNAL[literal.value] then
					-- Order matters. Format specifiers go first, so that a colour built
					-- out of them - "|cff%02x%02x%02x" for a class colour - is reduced to
					-- a bare "|cff" and can be recognised as one; strip the whole codes
					-- first and that leftover reads as the word "cff".
					local plain = literal.value
						:gsub("%%[%-%+ #%d%.]*[a-zA-Z]", "")
						:gsub("|c%x%x%x%x%x%x%x%x", "")
						:gsub("|c%x?%x?%x?%x?%x?%x?%x?%x?", "")
						:gsub("|r", ""):gsub("\\n", " ")
					-- Two signals, because the faults that got through were single
					-- words. A colour code is the strong one: nothing internal is
					-- coloured, so |cff9d9d9dempty|r is text somebody will read even
					-- though "empty" on its own could be anything. Failing that, two
					-- words of letters is a sentence.
					local coloured = literal.value:match("|c%x%x%x%x%x%x%x%x") ~= nil
					if plain:match("%a%a") and not plain:match("^%s*[A-Z_]+%s*$")
						and (coloured or plain:match("%a%s+%a")) then
						bare[#bare + 1] = name .. ": " .. literal.value:sub(1, 40)
					end
				end
			end
		end
	end

	check("every sentence a player can see is wrapped for translation", #bare == 0,
		table.concat(bare, " | "))
end)()

print()
print("captions that stop at the edge of the panel")
;(function()
	local PROSE = 45          -- characters, above which a string is a sentence

	local unbounded = {}
	for _, name in ipairs { "Window", "MemberPicker", "ChoicePicker", "Tooltip", "Summary",
		"Talents", "Contents", "Professions", "Character", "Quests", "Wide", "Guild",
		"Broker", "Options", "About", "Slash" } do
		local path = "addons/Family_UI/" .. name .. ".lua"
		local f = io.open(ROOT .. "/" .. path)
		if f then
			local text = f:read("*a")
			f:close()

			for widget in text:gmatch("local ([%w_]+) = [%w_]+:CreateFontString%(") do
				local bounded =
					text:match(widget .. ':SetPoint%("RIGHT"') ~= nil
					or text:match(widget .. ':SetPoint%("TOPRIGHT"') ~= nil
					or text:match(widget .. ':SetPoint%("BOTTOMRIGHT"') ~= nil
					or text:match(widget .. ":SetWidth%(") ~= nil
					or text:match(widget .. ":SetAllPoints") ~= nil

				if not bounded then
					-- Two ways a widget earns a right edge.
					--
					-- One: it is handed a sentence outright. Two: it is handed something
					-- this check cannot read - a variable, a table field, a format string -
					-- because a widget whose contents are not knowable from here is exactly
					-- the widget that must not be trusted to be short. The Options notes
					-- are the second kind: `note:SetText(switch.note)`, where the sentence
					-- lives in a table three screens up. An earlier version of this check
					-- only looked for the first kind and passed happily on the panel that
					-- prompted it.
					local why = nil

					for argument in text:gmatch(widget .. ":SetText%(([^\n]*)") do
						local key = argument:match('^L%["([^"]*)"%]%)')
						if key then
							local plain = key:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
							if #plain > PROSE then why = #plain .. " characters" end
						elseif not argument:match('^"[^"]*"%)') then
							why = why or ("set from " .. argument:sub(1, 24))
						end
					end

					if why then
						unbounded[#unbounded + 1] =
							string.format("%s %s (%s)", name, widget, why)
					end
				end
			end
		end
	end

	check("every caption long enough to be a sentence is given a right edge to wrap at",
		#unbounded == 0,
		table.concat(unbounded, " | ")
			.. " - a font string with no right anchor and no width does not wrap")
end)()

--------------------------------------------------------------------------------------------
-- What each client calls a profession
--
-- The identity Era never had. Generated from the client's own SkillLine table by
-- tools/skill-lines.py, so nothing in it was typed from memory - which matters more here than
-- it looks: the builds disagree about two Spanish professions, and the Russian for Skinning
-- begins with a Latin C on one build and a Cyrillic ES on the other. Identical to the eye.
--------------------------------------------------------------------------------------------

print()
print("what each client calls a profession")
;(function()
	local lines = Family.SkillLines
	local count = 0
	for _ in pairs(lines) do count = count + 1 end
	check("the profession table was generated and loaded", count >= 12, tostring(count))

	-- The nine Era primaries, the three secondaries it has, and the two later ones.
	for _, id in ipairs { 164, 165, 171, 182, 186, 197, 202, 333, 393, 129, 185, 356, 755 } do
		if not lines[id] then
			check("skill line " .. id .. " is in the table", false, "missing")
		end
	end
	check("every profession Era and Burning Crusade have is in the table", true)

	-- Five languages, and every one of them resolves back to the same identity.
	local unresolved = {}
	for id, entry in pairs(lines) do
		for locale, names in pairs(entry.names) do
			for _, name in ipairs(names) do
				if Family:SkillLineFor(name) ~= id then
					unresolved[#unresolved + 1] = locale .. " " .. name
				end
			end
		end
	end
	check("every name in it resolves back to its own skill line", #unresolved == 0,
		table.concat(unresolved, ", "))

	-- The point of the whole exercise: a member recorded in one language, read in another.
	do
		local was = Family.locale
		Family.locale = "frFR"
		check("a German client's word for a profession reads as French to a French client",
			Family:ProfessionName(Family:SkillLineFor("Schneiderei")) == "Couture",
			tostring(Family:ProfessionName(Family:SkillLineFor("Schneiderei"))))
		Family.locale = "ruRU"
		check("and as Russian to a Russian one",
			Family:ProfessionName(Family:SkillLineFor("Schneiderei")) == "Портняжное дело",
			tostring(Family:ProfessionName(Family:SkillLineFor("Schneiderei"))))
		Family.locale = was
	end

	-- Both spellings, because the builds genuinely use both and a player may have either.
	check("both Spanish words for skill 197 resolve",
		Family:SkillLineFor("Costura") == 197 and Family:SkillLineFor("Sastrería") == 197)
	check("and both Russian spellings of skill 393, which differ by one invisible letter",
		Family:SkillLineFor("Снятие шкур") == 393
			and Family:SkillLineFor("Cнятие шкур") == 393,
		"one of them begins with a Latin C and the other with a Cyrillic ES")

	-- A profession from a client newer than this table still has a name to show.
	check("an unknown skill line falls back to what the recording client called it",
		Family:ProfessionName(999999, "Гончарное дело") == "Гончарное дело")

	-- Records made before professions were keyed by identity are filed under a word, and a
	-- member is only re-keyed by somebody logging in on them. A family of twenty-seven
	-- halfway through that read half in French and half in English on one screen, which is
	-- a migration showing through the panel rather than a language Family does not speak.
	do
		local was = Family.locale
		Family.locale = "frFR"
		check("a profession still filed under a word is named in the reader's language",
			Family:ProfessionName("Alchemy") == "Alchimie",
			tostring(Family:ProfessionName("Alchemy")))
		check("and so is one filed under a third language's word",
			Family:ProfessionName("Verzauberkunst") == "Enchantement",
			tostring(Family:ProfessionName("Verzauberkunst")))
		check("a word no table knows is still printed as it was recorded",
			Family:ProfessionName("Poisons") == "Poisons")
		Family.locale = was
	end

	-- Primary or secondary, from the table rather than from asking whether it can be
	-- unlearned and then patching up the three that cannot.
	check("the table says which professions are primary",
		lines[197].primary == true and lines[185].primary == false,
		"tailoring should be primary and cooking should not")

	-- The accessors live in the generated file and are written by the generator. They were
	-- once added to it by hand, which meant the next tools/skill-lines.py --fetch would have
	-- deleted them and left an addon that loads and then fails at the first profession.
	check("the generated profession file still carries the functions that read it",
		type(Family.ProfessionName) == "function"
			and type(Family.SkillLineFor) == "function")
end)()

--------------------------------------------------------------------------------------------
-- What each client calls a recipe
--
-- Reported from a live client: a French player opened the professions panel and read
-- Secourisme, Cuisine and Travail du cuir - and under them, twelve recipes in English,
-- because the list had been read on an English client first.
--
-- A recipe is a spell and a spell has an id, and Family has recorded that id since it
-- recorded recipes at all. It then showed the word instead. That word is also what a click
-- matches against the open trade skill window, which answers in the client's own language -
-- so selecting a row that was plainly on screen quietly did nothing.
--
-- Enchanting is where this has to be got right: some of its recipes make an item and some
-- make no item at all, and the id that names them is the recipe's spell either way.
--------------------------------------------------------------------------------------------

print()
print("what each client calls a recipe")
;(function()
	check("a recipe is named by the client, not by the word it was recorded under",
		Family.Names:Recipe { name = "Ench. de plastron (Vie majeure)", spellID = 13640 }
			== "Enchant Chest - Major Health",
		tostring(Family.Names:Recipe { name = "Ench. de plastron (Vie majeure)",
			spellID = 13640 }))

	check("and an enchant that makes an item is named the same way",
		Family.Names:Recipe { name = "Huile de sorcier", spellID = 25128, itemID = 20749 }
			== "Wizard Oil",
		tostring(Family.Names:Recipe { name = "Huile de sorcier", spellID = 25128,
			itemID = 20749 }))

	check("a recipe with no spell id keeps the word it was recorded under",
		Family.Names:Recipe { name = "Mystery Brew" } == "Mystery Brew")

	check("and so does one this client will not name",
		Family.Names:Recipe { name = "Mystery Brew", spellID = 900001 } == "Mystery Brew",
		tostring(Family.Names:Recipe { name = "Mystery Brew", spellID = 900001 }))

	check("nothing at all is not a recipe", Family.Names:Recipe("Wizard Oil") == nil)

	-- Where a hearthstone is bound, told in the reader's own words.
	--
	-- The recorded word is one language and one expansion: a French Era client writes
	-- "Ironforge" and a French Burning Crusade client reading it says "Forgefer". Shipping
	-- the tables to fix that measured 876 KB, so the id is stored and each reader's client
	-- names it - which /family hearth confirmed all three clients can do, in their own
	-- language and their own spelling.
	--
	-- Stood up here rather than relied upon, because the harness is a client with no map API
	-- at all and would otherwise pass every one of these by doing nothing.
	do
		local restore = _G.C_Map
		_G.C_Map = { GetAreaInfo = function(id)
			-- Two ids for one place and the second a copy, which is the real shape of it:
			-- Coldridge Valley is 132 and 6176, and the two are spelled differently in
			-- German even where they agree in French.
			-- 16394 is the highest named area on Era, which is the highest of the three
			-- clients. It is here so that the scan's ceiling has to clear it: a ceiling
			-- that fell short would find no id for a player bound up there, and would do
			-- it silently.
			local areas = { [132] = "Vallee des Frigeres", [1537] = "Forgefer",
				[5176] = "Vallee des Frigeres", [16394] = "The Far End" }
			return areas[id]
		end }

		check("a place is named by the reader's client, not by whoever recorded it",
			Family.Names:Area(1537, "Ironforge") == "Forgefer",
			tostring(Family.Names:Area(1537, "Ironforge")))

		check("and an id this client has never heard of falls back to the recorded word",
			Family.Names:Area(4242, "Dalaran") == "Dalaran")

		check("a word can be turned back into its id",
			Family.Names:AreaFor("Forgefer") == 1537)

		-- Counting upward is not an accident: the lower id is the original area and the
		-- higher one the copy, and picking the copy would read differently in some other
		-- language even though it reads the same in this one.
		check("and where a place is in the table twice, the original wins",
			Family.Names:AreaFor("Vallee des Frigeres") == 132,
			tostring(Family.Names:AreaFor("Vallee des Frigeres")))

		check("a word this client does not know has no id",
			Family.Names:AreaFor("Nowhere At All") == nil)

		check("and the scan reaches the highest area these clients have",
			Family.Names:AreaFor("The Far End") == 16394,
			tostring(Family.Names:AreaFor("The Far End")))

		-- **The walk happens once for a place and never again**, which is the whole of why
		-- the answers are written down. Counted rather than timed: what matters is that the
		-- client stops being asked, not how long the asking took.
		do
			local asked = 0
			local named = _G.C_Map.GetAreaInfo
			_G.C_Map.GetAreaInfo = function(id)
				asked = asked + 1
				return named(id)
			end

			FamilyDB.areas = nil

			Family.Names:AreaFor("Forgefer")
			local first = asked
			check("finding a place for the first time asks the client", first > 0,
				tostring(first) .. " ids asked about")

			asked = 0
			check("and finding it again gives the same answer",
				Family.Names:AreaFor("Forgefer") == 1537)
			check("without asking the client at all", asked == 0,
				tostring(asked) .. " ids asked about")

			-- A place that is not there at all is worth remembering too. A Northrend zone
			-- on an Era client would otherwise be walked for on every scan for ever, which
			-- is the expensive half of this and the half nobody would notice.
			asked = 0
			Family.Names:AreaFor("Nowhere At All")
			check("a place this client does not have is looked for once", asked > 0,
				tostring(asked))

			asked = 0
			check("and answers nothing the second time", Family.Names:AreaFor("Nowhere At All") == nil)
			check("without looking again", asked == 0, tostring(asked) .. " ids asked about")

			-- It is the account's and not a character's: the note on it says twenty alts
			-- share one answer, and nothing here is keyed by member.
			check("and what was found is kept where the whole account can read it",
				(Family.Names:AreaStore() or {})["Forgefer"] == 1537,
				tostring((Family.Names:AreaStore() or {})["Forgefer"]))

			_G.C_Map.GetAreaInfo = named
		end

		_G.C_Map = nil
		check("with no map API at all, the recorded word is what is shown",
			Family.Names:Area(1537, "Ironforge") == "Ironforge")
		-- **A word already found is still found**, and that is the point of writing them
		-- down rather than a hole in this check. An area id means the same thing on every
		-- build, so an answer this account got from a client that had the map API is still
		-- the right answer on one that does not.
		--
		-- This check used to say no id could be found for anything, which was true when
		-- nothing was remembered and is too strong now. Split rather than weakened: the
		-- half that still holds is the one about a word nobody has ever looked up.
		check("a place this account has already found is still named",
			Family.Names:AreaFor("Forgefer") == 1537,
			tostring(Family.Names:AreaFor("Forgefer")))

		check("and one it has not cannot be looked up without the map API",
			Family.Names:AreaFor("Somewhere Unasked") == nil)

		_G.C_Map = restore
	end

	-- Where the record was written in the reader's own language, the recorded word wins
	-- outright: it is the row the game itself drew. Smelting is what proves it - the game
	-- says "Smelt Copper" and the item it makes is a Copper Bar, so naming that row after
	-- its product is wrong for the one reader who can already read it.
	do
		ITEM_NAMES[2840] = "Copper Bar"
		local smelt = { name = "Smelt Copper", itemID = 2840 }

		check("a record written in the reader's language keeps its own words",
			Family.Names:Recipe(smelt, nil, nil, Family.locale) == "Smelt Copper",
			tostring(Family.Names:Recipe(smelt, nil, nil, Family.locale)))
		check("and one written in another language is named by what it makes",
			Family.Names:Recipe(smelt, nil, nil, "frFR") == "Copper Bar",
			tostring(Family.Names:Recipe(smelt, nil, nil, "frFR")))
		check("and so is one whose language was never recorded",
			Family.Names:Recipe(smelt) == "Copper Bar")
	end

	-- The client answers about an item only once it has loaded that item, so a list of a
	-- hundred and fifty comes back part answered - which on a live client was half a first
	-- aid list in French and half in English, and the same for cooking and leatherworking.
	do
		local told = false
		local waiting = { name = "Bandage en lin", itemID = 14529 }

		check("a recipe whose item has not loaded keeps the word it was recorded under",
			Family.Names:Recipe(waiting, "test", function() told = true end)
				== "Bandage en lin",
			tostring(Family.Names:Recipe(waiting)))

		ITEM_NAMES[14529] = "Runecloth Bandage"
		fire("GET_ITEM_INFO_RECEIVED", 14529, true)

		check("and the caller is told when the client answers", told)
		check("and it is named in this client's language from then on",
			Family.Names:Recipe(waiting) == "Runecloth Bandage",
			tostring(Family.Names:Recipe(waiting)))
	end

	-- The second id, for a record whose first one is missing. The spell id and the item id
	-- come out of different calls, so a client that will not answer one may answer the
	-- other - and an item name is in the reader's language where the recorded word is in
	-- whoever scanned it.
	ITEM_NAMES[20749] = "Wizard Oil"
	check("a recipe with no spell id is named by what it makes",
		Family.Names:Recipe { name = "Huile de sorcier", itemID = 20749 } == "Wizard Oil",
		tostring(Family.Names:Recipe { name = "Huile de sorcier", itemID = 20749 }))
	check("and falls back to the recorded word when the client knows neither id",
		Family.Names:Recipe { name = "Huile de sorcier", spellID = 900002,
			itemID = 999998 } == "Huile de sorcier")

	-- The recipe list itself, which is the screen the report came from. It is drawn for
	-- the member being played, so this borrows them and gives them back.
	do
		local me = Family:CurrentMember()
		local payload = Family.Database:Payload(me) or {}
		local heldSkills = (Family.Database:Meta(me) or {}).skills
		local heldProfessions = payload.professions

		Family.Database:SetMeta(me, { skills = {
			[333] = { name = "Enchantement", rank = 300, maxRank = 300 },
			-- Gathering professions have no window to open and so never have a recipe
			-- list. They belong in the note at the top, and four of them is what makes
			-- that note longer than a line - which is the state it has to survive,
			-- because naming professions and saying why each is missing is not a
			-- sentence that fits on one line in any language but English.
			[356] = { name = "Pêche", rank = 300, maxRank = 300, secondary = true },
			[182] = { name = "Herboristerie", rank = 300, maxRank = 300 },
			[186] = { name = "Minage", rank = 300, maxRank = 300 },
			[393] = { name = "Dépeçage", rank = 300, maxRank = 300 },
		} })
		payload.professions = { [333] = { seen = time(), recipes = {
			{ name = "Ench. de plastron (Vie majeure)", spellID = 13640,
				difficulty = "optimal" },
			{ name = "Huile de sorcier", spellID = 25128, itemID = 20749,
				difficulty = "easy" },
		} } }
		Family.Database:SetPayload(me, payload)

		Family.UI:Show()
		Family.UI:ShowTab("professions")
		Family.UI:Refresh()

		check("the recipe list is drawn in this client's language",
			visibleText("Wizard Oil"),
			"the list is still showing the words it was recorded in")
		check("and an enchant that makes nothing is drawn the same way",
			visibleText("Enchant Chest - Major Health"))
		check("and the recorded words are not on screen",
			not visibleText("Huile de sorcier")
				and not visibleText("Ench. de plastron"))

		-- Not only what is drawn. Clicking a row asks the open trade skill window to
		-- select it, by name, and that window answers in the language the client is
		-- running - so a row carrying the recorded word searched an English list for a
		-- French string and silently found nothing.
		local rowNames = {}
		for _, f in ipairs(frames) do
			if f.__shown == true and f.profession == 333
				and type(f.recipeName) == "string"
			then
				rowNames[f.recipeName] = true
			end
		end
		check("and a click looks for the word the open window would use",
			rowNames["Wizard Oil"] == true
				and rowNames["Huile de sorcier"] == nil,
			"the row would search the open window for a word it does not contain")

		-- The message that says which professions are not in the list, and why. It names
		-- them, so it is longer than a line in any language but English - and it did not
		-- wrap, so the half that fell off the right edge was the why.
		local note
		for _, f in ipairs(fontStrings) do
			if type(f.__text) == "string" and f.__text:find("Not listed", 1, true) then
				note = f
			end
		end
		check("the note about what is missing is on screen at all", note ~= nil,
			"nothing to measure - the fixture leaves no profession out")
		if note then
			check("and is given the room it needs rather than one line",
				(note.__height or 0) >= math.ceil(note:GetStringHeight() or 0),
				tostring(note.__height) .. " reserved for "
					.. tostring(note:GetStringHeight()))
			-- A profession with no recipe list has not been "recorded in another
			-- language" - it was never opened, and on a live client every member with
			-- fishing was being told the first of those because of the second.
			check("and says a profession with no list was never opened, not mistranslated",
				note.__text:find("another language", 1, true) == nil, note.__text)
		end

		Family.Database:SetMeta(me, { skills = heldSkills or Family.CLEAR })
		payload.professions = heldProfessions
		Family.Database:SetPayload(me, payload)
	end

	-- Its own member, with its own record, because by this point the family has been
	-- rearranged by thirty other checks and a fixture that depends on their leavings is a
	-- fixture that stops meaning anything the moment one of them changes.
	--
	-- Recorded in French, on a client that is not running French. Both enchanting shapes:
	-- one that makes an item and one that makes none.
	local who = "Enchanteur-FireMaw"
	Family.Database:SetMeta(who, { name = "Enchanteur", realm = "Fire Maw",
		classFile = "MAGE", level = 60, faction = "Alliance",
		skills = { [333] = { name = "Enchantement", rank = 300, maxRank = 300 } } })
	Family.Database:SetPayload(who, { professions = { [333] = {
		seen = time(),
		recipes = {
			{ name = "Ench. de plastron (Vie majeure)", spellID = 13640,
				difficulty = "optimal" },
			{ name = "Huile de sorcier", spellID = 25128, itemID = 20749,
				difficulty = "easy" },
		},
	} } })

	-- The crafters block on an item tooltip. Its two sides used to be an item name from
	-- this client and a recipe name from whoever scanned it, which is two languages.
	local crafters = Family.Recipes:Crafters("Enchantement", "Formula: Wizard Oil")
	local knows = false
	for _, member in ipairs(crafters or {}) do
		if member.state == "knows" then knows = true end
	end
	check("a member who knows it is found by the name this client uses",
		knows, "the crafters block matched nothing across two languages")

	-- The panel, which is where it was reported: searched by the word on this screen, and
	-- shown in it.
	Family.UI:Show()
	Family.UI:ShowTab("professions")
	if _G.FamilyProfessionsEveryone then
		_G.FamilyProfessionsEveryone.__scripts.OnClick(_G.FamilyProfessionsEveryone)

		_G.FamilyProfessionsSearch:SetText("Wizard")
		Family.UI:Refresh()
		check("the panel finds a French-recorded recipe by this client's word for it",
			visibleText("Wizard Oil"))
		check("and shows it in this client's word rather than the recorded one",
			not visibleText("Huile de sorcier"))

		-- And the other way, because a family holds lists read on other people's clients
		-- and somebody who knows the French word should not be unable to find it.
		_G.FamilyProfessionsSearch:SetText("Huile")
		Family.UI:Refresh()
		check("and finds it by the word it was recorded under too",
			visibleText("Wizard Oil"))

		_G.FamilyProfessionsSearch:SetText("")
		Family.UI:Refresh()
	else
		check("the professions panel offers a whole-family search", false, "not found")
	end

	Family.Database:Forget(who)
end)()

--------------------------------------------------------------------------------------------
-- What each client calls a race
--
-- The same fault as professions and the same fix, with one difference that changes the shape
-- of it: the identity was never missing. UnitRace has always handed back a language-neutral
-- file string and Family has always recorded it. What was missing was anything to turn it
-- back into a word, so a member last played on a French client stayed French for ever.
--
-- Nothing has to be migrated for this and no rescan is needed, which is why it is not the
-- same fix twice.
--------------------------------------------------------------------------------------------

print()
print("what each client calls a race")
;(function()
	local was = Family.locale

	local count = 0
	for _ in pairs(Family.Races) do count = count + 1 end
	check("the race table was generated and loaded", count >= 11, tostring(count))

	local missing = {}
	for _, id in ipairs { 1, 2, 3, 4, 5, 6, 7, 8, 10, 11 } do
		if not Family.Races[id] then missing[#missing + 1] = tostring(id) end
	end
	check("every race Era and Burning Crusade let a player be is in it",
		#missing == 0, table.concat(missing, ", "))

	-- What is not in it matters as much as what is. Race 23 is "Human" in the file string
	-- as well - it is the Gilnean one - and race 12 is a fel orc, and neither is anything a
	-- player can be. The table itself says which are playable and that is what was read,
	-- rather than a list somebody remembered.
	check("only the races a player can be are in the table",
		Family.Races[23] == nil and Family.Races[12] == nil and Family.Races[15] == nil,
		"a non-playable race got in, and one of them is called Human too")
	check("and the file string Human is the human a player can be",
		Family.RaceByFile["Human"] == 1 and Family.Races[1].names.enUS[1] == "Human")

	local wrong = {}
	for file, id in pairs(Family.RaceByFile) do
		if not (Family.Races[id] and Family.Races[id].key == file) then
			wrong[#wrong + 1] = file
		end
	end
	check("every file string points at the race it names", #wrong == 0,
		table.concat(wrong, ", "))

	-- The file string is not a word the game shows anybody. Falling back to it, which is
	-- what Family did until this table existed, tells an English player their undead rogue
	-- is a Scourge.
	Family.locale = "enUS"
	check("an undead reads as Undead and not as Scourge",
		Family:RaceName { raceFile = "Scourge" } == "Undead",
		tostring(Family:RaceName { raceFile = "Scourge" }))

	-- The whole point: a member recorded on one client, read on another.
	Family.locale = "esES"
	check("a French client's word for a race reads as Spanish to a Spanish client",
		Family:RaceName { race = "Nain", raceFile = "Dwarf", raceLocale = "frFR" } == "Enano",
		tostring(Family:RaceName { race = "Nain", raceFile = "Dwarf", raceLocale = "frFR" }))
	Family.locale = "deDE"
	check("and as German to a German one",
		Family:RaceName { race = "Nain", raceFile = "Dwarf", raceLocale = "frFR" } == "Zwerg",
		tostring(Family:RaceName { race = "Nain", raceFile = "Dwarf", raceLocale = "frFR" }))

	-- A word from the reader's own client beats the table, because the game genders it and
	-- the table cannot. Russian is where this shows: a female gnome is a Gnomka.
	Family.locale = "ruRU"
	check("a word this client wrote itself is kept, gender and all",
		Family:RaceName { race = "Гномка", raceFile = "Gnome", raceLocale = "ruRU" }
			== "Гномка",
		tostring(Family:RaceName { race = "Гномка", raceFile = "Gnome",
			raceLocale = "ruRU" }))

	-- And the same record written before Family recorded the language beside the word.
	-- Every record in every existing database is one of these, so if this fails, upgrading
	-- turns every Russian woman in the family into a man until somebody logs in on her.
	check("and so is one written before the language was recorded with it",
		Family:RaceName { race = "Гномка", raceFile = "Gnome" } == "Гномка",
		tostring(Family:RaceName { race = "Гномка", raceFile = "Gnome" }))

	-- But only when it is a word this language uses. Recognising it by shape rather than by
	-- a recorded language must not let a foreign word through.
	Family.locale = "esES"
	check("a foreign word with no language recorded is still translated",
		Family:RaceName { race = "Гномка", raceFile = "Gnome" } == "Gnomo",
		tostring(Family:RaceName { race = "Гномка", raceFile = "Gnome" }))

	-- Five languages is not all of them, and Family runs wherever the game does.
	Family.locale = "itIT"
	check("a language this table does not ship asks the client instead",
		Family:RaceName { raceFile = "Gnome" } == "Gnomo di prova",
		tostring(Family:RaceName { raceFile = "Gnome" }))
	check("and falls back to what the recorder called it when the client will not answer",
		Family:RaceName { race = "Nain", raceFile = "Dwarf" } == "Nain",
		tostring(Family:RaceName { race = "Nain", raceFile = "Dwarf" }))

	-- The recorded language earns its place here. In a language the table does not ship
	-- there is no list of words to recognise the recorded one by, so the only thing that
	-- can say "this word is already in the reader's language" is the language written down
	-- beside it - and without it an Italian player reads their own characters in whatever
	-- the client's own answer happens to be rather than in the word their client used.
	check("a word recorded in a language the table does not ship is kept, because it said so",
		Family:RaceName { race = "Gnomo mio", raceFile = "Gnome", raceLocale = "itIT" }
			== "Gnomo mio",
		tostring(Family:RaceName { race = "Gnomo mio", raceFile = "Gnome",
			raceLocale = "itIT" }))

	check("the generated race file still carries the function that reads it",
		type(Family.RaceName) == "function")

	-- The panels must ask this question rather than answer it. Two of them showed a race
	-- and one of them read the recorded word straight off the record, which is how a French
	-- word survived on a Spanish screen in the one place nobody thought to look.
	Family.locale = "esES"
	local member = { race = "Nain", raceFile = "Dwarf", raceLocale = "frFR" }
	check("and the panels ask it rather than answering it themselves",
		Family.UI:RaceName(member) == Family:RaceName(member)
			and Family.UI:RaceName(member) == "Enano",
		tostring(Family.UI:RaceName(member)))

	-- A race from a client newer than this table has no word at all, and a panel must not
	-- print a blank where a name goes.
	check("a race nothing can name still leaves the panel something to print",
		Family.UI:RaceName { raceFile = "Vulpera" } == "Vulpera",
		tostring(Family.UI:RaceName { raceFile = "Vulpera" }))

	-- The rule above, enforced rather than asserted. Changing the two panels that showed a
	-- race broke no check at all, because a check written against one panel's output says
	-- nothing about the next panel somebody adds - and one of the two had been reading the
	-- recorded word straight off the record for months with every check passing.
	do
		local offenders = {}
		for _, name in ipairs { "Window", "MemberPicker", "ChoicePicker", "Tooltip",
			"Summary", "Talents", "Contents", "Professions", "Character", "Quests", "Wide",
			"Guild", "Broker", "Options", "About", "Slash" } do
			local path = "addons/Family_UI/" .. name .. ".lua"
			local file = io.open(ROOT .. "/" .. path)
			if not file then
				check("harness can read " .. path, false, "missing")
			else
				local text = file:read("*a")
				file:close()
				local line = 0
				for each in (text .. "\n"):gmatch("([^\n]*)\n") do
					line = line + 1
					-- Window.lua is where RaceName is, and its last resort is the file
					-- string. Everywhere else, the word for a race comes from asking.
					if each:match("%f[%w]meta%.race%f[^%w]")
						or each:match("%f[%w]meta%.raceFile%f[^%w]")
						or each:match("%f[%w]meta%.raceID%f[^%w]")
					then
						if not (name == "Window" and each:match("Family:RaceName")) then
							offenders[#offenders + 1] = path .. ":" .. line
						end
					end
				end
			end
		end
		check("and no panel reads the recorded race off the record itself",
			#offenders == 0, table.concat(offenders, ", "))
	end

	Family.locale = was
end)()

print()
print("a client's answer, handed straight to something that takes a second argument")

-- Family:TryCall returns whatever the client returned, however many values that is. That is its
-- whole job - the calls it wraps differ across three clients and some of them answer in two
-- values where others answer in one - and it makes every use of it a variadic expression.
--
-- tonumber's second parameter is a *base*. So tonumber(Family:TryCall(GetNumGuildMembers))
-- became tonumber(5, 2) on a live client, which is five read in binary, which is nil. The guild
-- roster probe then reported an empty guild while standing in a guild of five, twice, and the
-- Lua was valid throughout.
--
-- One extra pair of brackets fixes each site and the brackets are invisible in review, so the
-- rule is held here instead. Scoped to TryCall rather than to every nested call, because TryCall
-- is the one that is variadic *by design*: a match with one capture returns one value and can be
-- read locally, while what a client answers cannot.
;(function()
	local FILES = {
		"addons/Family/Core.lua", "addons/Family/Comm.lua", "addons/Family/Guild.lua",
		"addons/Family/Wide.lua", "addons/Family/Database.lua", "addons/Family/Cooldowns.lua",
		"addons/Family/Recipes.lua", "addons/Family/Scanners/Talents.lua",
		"addons/Family/Scanners/Mail.lua", "addons/Family/Scanners/Currencies.lua",
		"addons/Family/Scanners/Professions.lua", "addons/Family/Scanners/Identity.lua",
		"addons/Family/Scanners/Bank.lua", "addons/Family/Scanners/Quests.lua",
		"addons/Family_UI/Tooltip.lua", "addons/Family_UI/Slash.lua",
		"addons/Family_UI/Guild.lua", "addons/Family_UI/Options.lua",
	}

	local read, bare = 0, {}
	for _, path in ipairs(FILES) do
		local handle = io.open(ROOT .. "/" .. path)
		if handle then
			local text = handle:read("*a")
			handle:close()
			read = read + 1

			-- The unsafe shape: exactly one bracket between the outer call and TryCall.
			for outer in text:gmatch("(%a[%w_]*)%(Family:TryCall%(") do
				if outer == "tonumber" or outer == "select" then
					bare[#bare + 1] = path .. ": " .. outer .. "(Family:TryCall("
				end
			end
		end
	end

	check("the source files this rule covers are all there", read == #FILES,
		string.format("%d of %d", read, #FILES))
	check("no client answer is handed straight to something that takes a second argument",
		#bare == 0, table.concat(bare, " | "))
end)()

print()
print("what this client calls a character, and whether two can collide")

-- A probe, not a feature. onHello decides an announcement is our own by comparing bare names
-- with the realm stripped from both sides, and the client's own echo shows the two sides are
-- spelled differently: the message comes back as "Eccebombo-MirageRaceway" while
-- UnitName("player") answers "Eccebombo". If a guild can hold two characters of one name on
-- two realms, one of them is read as us - dropped as an echo, never answered, and listed as
-- not running Family for ever.
--
-- Whether a guild can hold two is a question about the client, so it is asked rather than
-- reasoned about. These checks are about the questions being put properly: every value each
-- call returned, with its type, and nothing interpreted.
;(function()
	local held = {}
	for _, name in ipairs { "UnitName", "UnitFullName", "GetRealmName",
		"GetNormalizedRealmName", "GetAutoCompleteRealms", "GetNumGuildMembers",
		"GetGuildRosterInfo", "GuildRoster" } do
		held[name] = _G[name]
	end

	-- The roster is asked for and read back three seconds later, so every run below has to
	-- let the clock move. A probe that reads the roster cold reports zero on a client
	-- standing in a guild, which is what the first version of this did on a live client.
	local asked = 0
	_G.GuildRoster = function() asked = asked + 1 end

	local function restore()
		for name, fn in pairs(held) do _G[name] = fn end
	end

	local function lines(from)
		local out = {}
		for index = from + 1, #DEFAULT_CHAT_FRAME.messages do
			out[#out + 1] = tostring(DEFAULT_CHAT_FRAME.messages[index])
		end
		return table.concat(out, "\n")
	end

	_G.UnitName = function() return "Ecce" end
	_G.UnitFullName = function() return "Ecce", "MirageRaceway" end
	_G.GetRealmName = function() return "Mirage Raceway" end
	_G.GetNormalizedRealmName = nil
	_G.GetAutoCompleteRealms = function() return { "MirageRaceway", "Whitemane" } end
	_G.GetNumGuildMembers = function() return 0 end
	_G.GetGuildRosterInfo = function() return nil end

	local mark = #DEFAULT_CHAT_FRAME.messages
	Family.Guild:ProbeNames()
	check("the roster is asked for before it is read", asked == 1
		and lines(mark):find("entries,", 1, true) == nil, tostring(asked))
	advance(5)
	local said = lines(mark)

	-- The whole point of a probe: the answer's shape is part of what is being asked, so a
	-- call that answers in two values must show both, each with its type.
	check("every value a call returned is printed, with its type",
		said:find("1:Ecce(string) 2:MirageRaceway(string)", 1, true) ~= nil)

	-- A client that simply does not have one of these must say so rather than error or be
	-- reported as having answered nothing.
	check("a call this client does not have says so",
		said:find("GetNormalizedRealmName() -> ", 1, true) ~= nil
			and said:find("no such call", 1, true) ~= nil)

	-- A table printed as an address answers nothing at all, and the connected-realm list is
	-- the one call here that returns one.
	check("a table is expanded rather than printed as an address",
		said:find("{MirageRaceway, Whitemane}", 1, true) ~= nil)

	check("and an empty roster is said to be empty rather than reported on",
		said:find("no roster came back", 1, true) ~= nil
			and said:find("entries,", 1, true) == nil)

	-- A count of zero and a call that is not there are different answers, and TryCall
	-- returns nil for both. The probe has to print which it got.
	check("with the roster calls printed, so zero can be told from absent",
		said:find("GetNumGuildMembers() -> ", 1, true) ~= nil
			and said:find("GetGuildRosterInfo(1) -> ", 1, true) ~= nil)

	-- The case this probe was written for.
	_G.GetNumGuildMembers = function() return 2 end
	_G.GetGuildRosterInfo = function(index)
		if index == 1 then return "Ecce-MirageRaceway" end
		return "Ecce-Whitemane"
	end

	mark = #DEFAULT_CHAT_FRAME.messages
	Family.Guild:ProbeNames()
	advance(5)
	said = lines(mark)

	check("two characters of one name on two realms are reported as a collision",
		said:find("2 entries share this character's name", 1, true) ~= nil)
	check("and the roster says how many entries carry a realm at all",
		said:find("2 entries, 2 of them carrying a realm", 1, true) ~= nil)
	-- The examples are capped at four, and a list of four under a count of five would invite
	-- a conclusion about the fifth. The cap is stated rather than implied.
	check("and says how many of them it is about to spell out",
		said:find("the first 2 of those", 1, true) ~= nil)

	-- And the ordinary guild, where it cannot be shown. Said as what is known: a guild that
	-- has no collision today is not a client that cannot produce one.
	_G.GetGuildRosterInfo = function(index)
		if index == 1 then return "Ecce-MirageRaceway" end
		return "Somebody-Whitemane"
	end

	mark = #DEFAULT_CHAT_FRAME.messages
	Family.Guild:ProbeNames()
	advance(5)
	said = lines(mark)

	check("a guild with nobody of our name says the collision cannot be shown here",
		said:find("nobody else in the roster shares this character's name", 1, true) ~= nil)
	check("and does not claim a collision", said:find("collision is real", 1, true) == nil)

	restore()
end)()

print()
print("heard by others, never by ourselves")

-- A character on a realm other than the guild's own can receive on the guild addon channel and
-- cannot send on it (DATASOURCES §2, measured on Mists). Every send is accepted - the same
-- answer the client gives when a message does arrive - and the message then does not exist,
-- for anybody, this client included.
--
-- Family cannot fix that. What it must stop doing is sending the player to look at the channel,
-- which is the one part they cannot inspect, when the shape of it is right here in the counts.
;(function()
	local stats = Family.Guild.stats
	local held = { sent = stats.sent, echo = stats.echo, answered = stats.answered,
		arrived = stats.arrived }

	local function saidOn(sent, echo, answered)
		stats.sent, stats.echo, stats.answered = sent, echo, answered
		stats.arrived = echo + answered

		local mark = #DEFAULT_CHAT_FRAME.messages
		Family.Guild:Diagnose()

		local out = {}
        for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
			out[#out + 1] = tostring(DEFAULT_CHAT_FRAME.messages[index])
		end
		return table.concat(out, "\n")
	end

	local WARNING = "Your own announcements are not coming back"

	check("somebody heard and nothing of ours came back is named",
		saidOn(3, 0, 1):find(WARNING, 1, true) ~= nil)

	-- Gated on having heard somebody. A lone Family user on a client that simply does not echo
	-- would otherwise be told they are broken, and whether Era and Burning Crusade echo at all
	-- is unmeasured.
	check("but being alone in the guild is not, on any client",
		saidOn(3, 0, 0):find(WARNING, 1, true) == nil,
		"a lone user on a client that does not echo would be told they are broken")

	check("and neither is a client whose own announcements do come back",
		saidOn(3, 2, 1):find(WARNING, 1, true) == nil)

	check("and neither is one that has sent nothing",
		saidOn(0, 0, 1):find(WARNING, 1, true) == nil)

	stats.sent, stats.echo, stats.answered, stats.arrived =
		held.sent, held.echo, held.answered, held.arrived
end)()

print()
print("a guild that spans a connected group")

-- Measured 2026-08-30: guild Uga holds Eccebombo-MirageRaceway and Zinetta-Garalon at once, and
-- Offering() required an exact realm match - so a character genuinely in the guild was withheld
-- from it, and the loss is the size of the cluster.
--
-- The grid is the trap. Guild:Key builds the key from the realm, so a box ticked while playing
-- Zinetta lands in "Uga-Garalon" and one ticked while playing Pinetta in "Uga-Mirage Raceway" -
-- the same guild, two drawers. Harmless while Offering() only described this realm; once it
-- describes the group, the panel would draw a row from the wrong drawer, find it empty, and
-- write a second grant for a decision already taken.
;(function()
	local held, heldRealms = FamilyDB.guild, _G.GetAutoCompleteRealms
	_G.GetAutoCompleteRealms = function()
		return { "MirageRaceway", "Garalon", "Norushen" }
	end

	check("a realm is its own group", Family.Guild:SameRealmGroup("Garalon", "Garalon"))
	check("and two realms the client calls one group are one group",
		Family.Guild:SameRealmGroup("Garalon", "Mirage Raceway"),
		"GetRealmName spells it with a space and the list without one")
	check("but a realm outside the list is not",
		Family.Guild:SameRealmGroup("Pyrewood Village", "Mirage Raceway") == false)

	-- A list that does not contain us is a list about somebody else.
	check("and neither is one where we are not in the list ourselves",
		Family.Guild:SameRealmGroup("Garalon", "Pyrewood Village") == false)

	-- Where the client will not answer, the exact match is the answer. Widening on a list
	-- nobody returned would offer a character in a guild called Ronin on one realm to a guild
	-- called Ronin on an unconnected other.
	_G.GetAutoCompleteRealms = nil
	check("a client with no such call falls back to an exact match",
		Family.Guild:SameRealmGroup("Garalon", "Garalon")
			and Family.Guild:SameRealmGroup("Garalon", "Mirage Raceway") == false)

	-- **An empty table, which is what a realm with no partners actually answers.** Measured on
	-- Burning Crusade: `GetAutoCompleteRealms() -> 1:{}(table)`, the call present and the list
	-- empty. The absent-call case above was the one written from imagination; this is the one
	-- two clients out of three will hit, and nothing had exercised it.
	_G.GetAutoCompleteRealms = function() return {} end
	check("and so does one whose list of connected realms is empty",
		Family.Guild:SameRealmGroup("Thunderstrike", "Thunderstrike")
			and Family.Guild:SameRealmGroup("Garalon", "Thunderstrike") == false,
		"an empty list must narrow to the exact match, not widen to everything")

	_G.GetAutoCompleteRealms = function()
		return { "MirageRaceway", "Garalon" }
	end

	-- One decision, read from either character.
	FamilyDB.guild = { known = {}, users = {}, grants = {}, recipes = {}, announced = {} }
	local heldMembers = Family.Database.Members
	Family.Database.Members = function()
		return {
			["Pinetta-MirageRaceway"] = { meta = { guild = "Uga", realm = "Mirage Raceway" } },
			["Zinetta-Garalon"] = { meta = { guild = "Uga", realm = "Garalon" } },
			["Elsewhere-Pyrewood"] = { meta = { guild = "Uga", realm = "Pyrewood Village" } },
		}
	end

	-- Ticked while playing Zinetta, whose client calls the guild Uga-Garalon.
	Family.Guild:SetShare("Uga-Garalon", "Zinetta-Garalon", 197, true)
	check("a grant ticked on one realm is filed under that character's own guild key",
		FamilyDB.guild.grants["Uga-Garalon"]
			and FamilyDB.guild.grants["Uga-Garalon"]["Zinetta-Garalon"][197] == true)

	-- Read while playing Pinetta, whose client calls the same guild Uga-Mirage Raceway.
	check("and is read as ticked from a character on the other realm",
		Family.Guild:Shares("Uga-Mirage Raceway", "Zinetta-Garalon", 197),
		"the panel would draw an empty box over a decision already taken")

	-- And ticking from there must not open a second drawer for the same decision.
	Family.Guild:SetShare("Uga-Mirage Raceway", "Zinetta-Garalon", 197, false)
	check("and unticking it from there undoes the same grant, not a second one",
		Family.Guild:Shares("Uga-Garalon", "Zinetta-Garalon", 197) == false
			and FamilyDB.guild.grants["Uga-Mirage Raceway"] == nil,
		"a second grant was written for one decision")

	-- A character who has since joined another guild must not have that guild's grants read
	-- under this one's name.
	Family.Guild:SetShare("Somewhere Else-Garalon", "Zinetta-Garalon", 197, true)
	check("a grant in another guild is not read under this one",
		Family.Guild:Shares("Uga-Mirage Raceway", "Zinetta-Garalon", 197) == false)

	-- And that Offering and the diagnosis actually *use* the predicate.
	--
	-- The checks above hold the predicate and not the claim, which is L-030 exactly: putting
	-- the exact realm match back into Offering left every one of them green.
	local heldGuildInfo, heldRealmName = _G.GetGuildInfo, _G.GetRealmName
	local heldPayload = Family.Database.Payload
	_G.GetGuildInfo = function() return "Uga", "Member", 3 end
	_G.GetRealmName = function() return "Mirage Raceway" end
	Family.Database.Payload = function() return {} end

	local offering = Family.Guild:Offering() or {}
	check("a character on a connected realm is offered to the guild",
		offering["Zinetta-Garalon"] ~= nil,
		"in the guild, on a realm the client calls the same group, and withheld from it")
	check("our own character on this realm still is",
		offering["Pinetta-MirageRaceway"] ~= nil)
	check("and one in the same guild on an unconnected realm still is not",
		offering["Elsewhere-Pyrewood"] == nil)

	-- The diagnosis has to agree with what was actually sent, or it names people who are
	-- being offered as people who are not.
	local mark = #DEFAULT_CHAT_FRAME.messages
	Family.Guild:Diagnose()
	local said = {}
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		said[#said + 1] = tostring(DEFAULT_CHAT_FRAME.messages[index])
	end
	said = table.concat(said, "\n")

	check("the diagnosis names the one on an unconnected realm as not offered",
		said:find("recorded on another realm", 1, true) ~= nil
			and said:find("Elsewhere", 1, true) ~= nil)
	check("and does not name the one it is now offering",
		said:find("Zinetta", 1, true) == nil,
		"the diagnosis says withheld about a character that was sent")

	Family.Database.Payload = heldPayload
	_G.GetGuildInfo, _G.GetRealmName = heldGuildInfo, heldRealmName
	Family.Database.Members = heldMembers
	FamilyDB.guild = held
	_G.GetAutoCompleteRealms = heldRealms
end)()

print()
print("reading a charge count off a tooltip")

-- The only place in Family that reads a tooltip. No container call answers this: on Mists
-- GetContainerItemInfo returns twelve fields and stackCount is 1 for a five-charge oil.
--
-- What comes back is an integer, which is what §2.1 asks. The sentence around it is the
-- client's and is thrown away - and the pattern is built from ITEM_SPELL_CHARGES rather than
-- written out, so a French client matches "5 Charges" and a German one matches whatever German
-- says, without either word appearing here.
;(function()
	local heldFormat = _G.ITEM_SPELL_CHARGES
	_G.-- The player's auras, and what a tooltip pointed at one says.
--
-- A Chronoboon's contents are tooltip text and nothing else (DATASOURCES §2), and the shape
-- matters more than the content: the whole of it arrives in **one** tooltip line, as rows
-- separated by \r\n, each buff row carrying an icon escape and a colour code. A fake that
-- handed back one row per tooltip line would pass a reader that only ever read the first row -
-- which is exactly the reader that was written first, and exactly the misread behind L-034.
PLAYER_AURAS = {}
AURA_LINES = {}
AURA_ASKED = 0

function UnitBuff(unit, index)
	local aura = PLAYER_AURAS[index]
	if not aura then return nil end
	-- Ten returns, because the tenth is the spell id and that is the one Family reads.
	return aura.name, nil, aura.count, nil, nil, nil, nil, nil, nil, aura.spellID
end

function frameMethods:SetUnitBuff(unit, index)
	AURA_ASKED = AURA_ASKED + 1
	wipe(self.__lines)

	local lines = AURA_LINES[index] or {}
	for line = 1, 12 do
		local text = lines[line]
		if text then table.insert(self.__lines, { text }) end
		_G[(self.__name or "?") .. "TextLeft" .. line] =
			text and { GetText = function() return text end } or nil
	end
end

ITEM_SPELL_CHARGES = "%d |4Charge:Charges;"

	-- First call builds the tooltip through the real CreateFrame, which registers the global.
	Family:ChargesIn(0, 1)
	local tip = _G.FamilyScanTooltip
	check("a scanning tooltip is made, and only one", tip ~= nil and tip.__name == "FamilyScanTooltip")

	-- The frame stub answers nil for methods it does not know and TryCall pcalls, so the real
	-- lines have to be supplied here.
	local lines = {}
	tip.NumLines = function() return #lines end
	tip.SetOwner = function() end
	tip.SetBagItem = function() end
	local function showing(...)
		lines = { ... }
		for index = 1, #lines do
			_G["FamilyScanTooltipTextLeft" .. index] =
				{ GetText = function() return lines[index] end }
		end
	end

	_G.-- The player's auras, and what a tooltip pointed at one says.
--
-- A Chronoboon's contents are tooltip text and nothing else (DATASOURCES §2), and the shape
-- matters more than the content: the whole of it arrives in **one** tooltip line, as rows
-- separated by \r\n, each buff row carrying an icon escape and a colour code. A fake that
-- handed back one row per tooltip line would pass a reader that only ever read the first row -
-- which is exactly the reader that was written first, and exactly the misread behind L-034.
PLAYER_AURAS = {}
AURA_LINES = {}
AURA_ASKED = 0

function UnitBuff(unit, index)
	local aura = PLAYER_AURAS[index]
	if not aura then return nil end
	-- Ten returns, because the tenth is the spell id and that is the one Family reads.
	return aura.name, nil, aura.count, nil, nil, nil, nil, nil, nil, aura.spellID
end

function frameMethods:SetUnitBuff(unit, index)
	AURA_ASKED = AURA_ASKED + 1
	wipe(self.__lines)

	local lines = AURA_LINES[index] or {}
	for line = 1, 12 do
		local text = lines[line]
		if text then table.insert(self.__lines, { text }) end
		_G[(self.__name or "?") .. "TextLeft" .. line] =
			text and { GetText = function() return text end } or nil
	end
end

ITEM_SPELL_CHARGES = "%d |4Charge:Charges;"
	showing("Lesser Mana Oil", "Requires Level 40",
		"Use: While applied to target weapon it restores 8 mana. (1 Sec Cooldown)",
		"5 Charges", "<Made by Nervina>")
	check("the charge line is found among the others", Family:ChargesIn(0, 1) == 5,
		tostring(Family:ChargesIn(0, 1)))

	-- The lines either side are the ones that would be matched by a sloppier pattern: one
	-- begins with a number and one contains a bracketed one.
	showing("Requires Level 40", "Use: something. (1 Sec Cooldown)", "<Made by Nervina>")
	check("and an item with no charge line answers nothing",
		Family:ChargesIn(0, 1) == nil, tostring(Family:ChargesIn(0, 1)))

	showing("Wizard Oil", "1 Charge")
	check("one charge reads as one, not as the plural markup",
		Family:ChargesIn(0, 1) == 1, tostring(Family:ChargesIn(0, 1)))

	-- The whole reason the pattern is built rather than written: this client speaks French and
	-- nothing in the source says "Charges" in any language.
	_G.ITEM_SPELL_CHARGES = "%d |4charge:charges;"
	showing("Huile de mage mineure", "3 charges")
	check("a client in another language is read by the same code",
		Family:ChargesIn(0, 1) == 3, tostring(Family:ChargesIn(0, 1)))

	-- A locale whose sentence carries pattern punctuation must not become a pattern.
	_G.ITEM_SPELL_CHARGES = "Charges (%d)"
	showing("Something", "Charges (7)")
	check("and one whose wording carries brackets is escaped rather than matched",
		Family:ChargesIn(0, 1) == 7, tostring(Family:ChargesIn(0, 1)))

	-- A client whose global is not there must answer nothing rather than throw. The pattern
	-- is cached on the string it came from, so this also holds that a missing global is not
	-- cached as an answer for the session.
	_G.ITEM_SPELL_CHARGES = nil
	showing("Something", "5 Charges")
	check("a client with no such global reads no charges and does not throw",
		Family:ChargesIn(0, 1) == nil, tostring(Family:ChargesIn(0, 1)))

	_G.ITEM_SPELL_CHARGES = heldFormat
end)()

print()
print("and recording it, for the few slots that need it")

-- The reader above is held by its own checks; these hold that anything *uses* it. Putting the
-- exact realm match back into Offering() left every check green this morning for exactly this
-- reason (L-030), and the same shape was waiting here: the scanners could stop reading charges
-- altogether and nothing would have said so.
;(function()
	local heldFormat = _G.ITEM_SPELL_CHARGES
	_G.-- The player's auras, and what a tooltip pointed at one says.
--
-- A Chronoboon's contents are tooltip text and nothing else (DATASOURCES §2), and the shape
-- matters more than the content: the whole of it arrives in **one** tooltip line, as rows
-- separated by \r\n, each buff row carrying an icon escape and a colour code. A fake that
-- handed back one row per tooltip line would pass a reader that only ever read the first row -
-- which is exactly the reader that was written first, and exactly the misread behind L-034.
PLAYER_AURAS = {}
AURA_LINES = {}
AURA_ASKED = 0

function UnitBuff(unit, index)
	local aura = PLAYER_AURAS[index]
	if not aura then return nil end
	-- Ten returns, because the tenth is the spell id and that is the one Family reads.
	return aura.name, nil, aura.count, nil, nil, nil, nil, nil, nil, aura.spellID
end

function frameMethods:SetUnitBuff(unit, index)
	AURA_ASKED = AURA_ASKED + 1
	wipe(self.__lines)

	local lines = AURA_LINES[index] or {}
	for line = 1, 12 do
		local text = lines[line]
		if text then table.insert(self.__lines, { text }) end
		_G[(self.__name or "?") .. "TextLeft" .. line] =
			text and { GetText = function() return text end } or nil
	end
end

ITEM_SPELL_CHARGES = "%d |4Charge:Charges;"

	local key = Family:CurrentMember()
	local tip = _G.FamilyScanTooltip
	local asked = 0
	tip.SetOwner = function() end
	tip.NumLines = function() return 2 end
	tip.SetBagItem = function(_, bag, slot) asked = asked + 1 end
	_G.FamilyScanTooltipTextLeft1 = { GetText = function() return "Lesser Mana Oil" end }
	_G.FamilyScanTooltipTextLeft2 = { GetText = function() return "5 Charges" end }

	-- 20747 is Lesser Mana Oil and is in the generated table at 5; the other slots hold a
	-- hearthstone and cloth, which are not.
	BAGS[1].items[8] = { 20747, 1 }
	asked = 0
	Family.Bags:Scan()

	local bags = (Family.Database:Payload(key) or {}).bags or {}
	local slot = ((bags[1] or {}).slots or {})[8]
	check("a charged item in a bag records how many are left",
		slot and slot.charges == 5, slot and tostring(slot.charges) or "no slot")

	-- The gate is the whole reason this is affordable: a bag of cloth must cost a table
	-- lookup a slot and no tooltip at all.
	check("and nothing else in the bags is tooltipped", asked == 1,
		asked .. " slots were tooltipped, and one holds a charged item")

	BAGS[1].items[8] = nil
	Family.Bags:Scan()
	bags = (Family.Database:Payload(key) or {}).bags or {}
	check("and using the last charge leaves nothing behind",
		((bags[1] or {}).slots or {})[8] == nil)

	-- The personal bank, on the same gate. The guild bank is deliberately not on it: its tabs
	-- arrive a page at a time and a charge read off one that has not would be wrong rather
	-- than absent.
	-- An earlier section takes this bag away and shuts the window, and the bank refuses to
	-- record anything with no window in front of it - which is the point of that section.
	BANK_BAGS[6] = BANK_BAGS[6] or { size = 16, free = 15, bagType = 0, items = {} }
	BANK_BAGS[6].items[2] = { 20747, 1 }
	fire("BANKFRAME_OPENED")
	asked = 0
	Family.Bank:Scan()

	local bank = (Family.Database:Payload(key) or {}).bank or {}
	local held = ((bank.containers or {})[6] or {}).slots or {}
	check("a charged item in the bank records it too",
		held[2] and held[2].charges == 5, held[2] and tostring(held[2].charges) or "no slot")
	check("and the bank is gated the same way", asked == 1, tostring(asked))

	BANK_BAGS[6].items[2] = nil
	Family.Bank:Scan()
	fire("BANKFRAME_CLOSED")

	------------------------------------------------------------------------------------
	-- An item the client does not have yet
	--
	-- Reported live: an oil showed no charge count until it was moved between slots. The
	-- tooltip is empty until the client has the item, and at login it has not - so the scan
	-- that runs first read nothing, recorded nil, and nothing ever asked again. The reader
	-- was working perfectly the whole time, which is why it took a probe to find.
	------------------------------------------------------------------------------------
	-- 21713 is Elune's Candle: in the charged table, and an id nothing anywhere in this run
	-- names or looks up - which matters twice over, because Names caches a name once it has
	-- one and the client itself never forgets. Once known, always known, here as in the game,
	-- so a "does not know it yet" check needs an id nothing has introduced.
	BAGS[1].items[9] = { 21713, 1 }
	CHARGE_LINES["1:9"] = { "Elune's Candle", "5 Charges" }
	Family.Bags:Scan()

	local bags = (Family.Database:Payload(key) or {}).bags or {}
	check("an item the client does not have yet records no charges",
		((bags[1] or {}).slots or {})[9]
			and ((bags[1] or {}).slots or {})[9].charges == nil,
		((bags[1] or {}).slots or {})[9]
			and ("charges " .. tostring(((bags[1] or {}).slots or {})[9].charges))
			or "no slot 9 at all")

	-- And the client answering is what asks again. Without this the nil above is what the
	-- panel shows until something unrelated moves the item.
	ITEM_NAMES[21713] = "Elune's Candle"
	fire("GET_ITEM_INFO_RECEIVED", 21713, true)
	advance(2)

	bags = (Family.Database:Payload(key) or {}).bags or {}
	check("and the count arrives once the client answers about it",
		((bags[1] or {}).slots or {})[9]
			and ((bags[1] or {}).slots or {})[9].charges == 5,
		tostring(((bags[1] or {}).slots or {})[9]
			and ((bags[1] or {}).slots or {})[9].charges))

	ITEM_NAMES[21713] = nil
	BAGS[1].items[9] = nil
	Family.Bags:Scan()
	_G.ITEM_SPELL_CHARGES = heldFormat
	_G.FamilyScanTooltipTextLeft1, _G.FamilyScanTooltipTextLeft2 = nil, nil
end)()

print()
print("which items can carry more than one charge")

-- No container call says how many charges are left: GetContainerItemInfo answers twelve fields
-- and stackCount is 1, not the count. The remaining number is only in the tooltip, and reading
-- a tooltip per slot is not free when a bag is eighty slots of mostly cloth.
--
-- So this table is the gate - a slot whose item is not in it is never tooltipped - and it is
-- generated from the client's own ItemEffect rather than typed, because the alternative is a
-- hand-kept list of oils that is wrong the first time somebody carries a Bag of Marbles.
;(function()
	local table_ = Family.ChargedItems
	check("the generated table is there", type(table_) == "table")

	local count, worst = 0, nil
	for id, most in pairs(table_ or {}) do
		count = count + 1
		if type(id) ~= "number" or type(most) ~= "number" or most < 2 then
			worst = worst or string.format("%s = %s", tostring(id), tostring(most))
		end
	end

	-- A number rather than a range, because the table is generated: a build that halved it
	-- would be a fetch that half failed, and that is exactly what should stop a release.
	check("and holds the union of the three builds", count > 300,
		count .. " items, and three builds gave 181, 158 and 246 with 355 distinct")

	-- Ids are keys and maxima are values, and one charge is not a charge worth tooltipping.
	check("every row is an id against a maximum of two or more", worst == nil, tostring(worst))

	-- Anchors, measured from wago on 2026-08-30 and named here so that a regenerated table
	-- that has quietly lost its oils fails rather than passes smaller.
	check("the oils are in it", (table_ or {})[20747] == 5 and (table_ or {})[20749] == 5,
		"Lesser Mana Oil and Wizard Oil are the items this was built for")
	check("and so is the one with the most", (table_ or {})[234142] == 200,
		"Bottomless Noggenfogger Elixir, 200 charges, the top of the range")

	-- And the generator still exists and still names every build DATASOURCES pins, because a
	-- table nothing can rebuild is a table that goes stale in silence.
	local handle = io.open(ROOT .. "/tools/charged-items.py")
	local tool = handle and handle:read("*a") or ""
	if handle then handle:close() end

	local missing = {}
	for _, build in ipairs { "1.15.9.69109", "2.5.6.69110", "5.5.4.69078" } do
		if not tool:find(build, 1, true) then missing[#missing + 1] = build end
	end
	check("tools/charged-items.py knows every build this table was measured from",
		tool ~= "" and #missing == 0, table.concat(missing, ", "))
end)()

print()
print("a world buff banked in a Chronoboon")

-- A charged Chronoboon is a different item from an empty one - 184937 the Displacer, 184938 the
-- Supercharged one - and that pair is identical on all three builds (DATASOURCES §3). So which
-- character has a buff banked is answerable by id, with no tooltip and no new capability, from
-- bag contents Family already records.
--
-- Recorded into meta rather than read out of the payload at draw time, because the summary
-- draws every member at once and meta is what it may read for all of them. What is *inside* one
-- is a different question and is not this.
;(function()
	local key = Family:CurrentMember()
	local slot = BAGS[1].items

	check("no boon is recorded when none is carried",
		(Family.Database:Members()[key].meta or {}).boons == nil)

	slot[6] = { 184938, 1 }
	Family.Bags:Scan()
	check("a Supercharged Chronoboon in a bag is recorded",
		(Family.Database:Members()[key].meta or {}).boons == true,
		tostring((Family.Database:Members()[key].meta or {}).boons))

	-- An empty Displacer is not a banked buff, and recording it as one would send somebody to
	-- log in a character that has nothing.
	slot[6] = { 184937, 1 }
	Family.Bags:Scan()
	check("an empty Displacer is not", (Family.Database:Members()[key].meta or {}).boons == nil,
		tostring((Family.Database:Members()[key].meta or {}).boons))

	-- A flag and not a count, and it stays one however many are found. There is no way to hold
	-- two - the supercharged item is made by using the empty one, which cannot be used again
	-- until the first is released - so a number here could only ever be 1, and a column that
	-- showed it would be counting to one while the question was how many buffs are inside.
	slot[6] = { 184938, 1 }
	slot[7] = { 184938, 1 }
	Family.Bags:Scan()
	check("and it stays a flag however many a bag is made to hold",
		(Family.Database:Members()[key].meta or {}).boons == true,
		tostring((Family.Database:Members()[key].meta or {}).boons))

	-- Used, and the fact has to go: a stale "has a boon" is worse than none.
	slot[6], slot[7] = nil, nil
	Family.Bags:Scan()
	check("and using them clears it rather than leaving it on disk",
		(Family.Database:Members()[key].meta or {}).boons == nil,
		tostring((Family.Database:Members()[key].meta or {}).boons))

	-- What is inside goes to disk in the same scan as the boon itself, so a panel can never
	-- draw contents for a boon this character no longer carries.
	local REAL = "World effects suspended:\r\n\r\n"
		.. " |T134153:24|t |cffffffffRallying Cry of the Dragonslayer (120m)|r\r\n\r\n"
		.. "While a world effect is suspended, you cannot benefit from"

	slot[6] = { 184938, 1 }
	PLAYER_AURAS[1] = { name = "Supercharged Chronoboon Displacer", spellID = 349981 }
	AURA_LINES[1] = { "Supercharged Chronoboon Displacer", REAL }
	Family.Bags:Scan()

	local banked = (Family.Database:Members()[key].meta or {}).banked
	check("a bag scan records what is inside the boon", banked and #banked == 1,
		tostring(banked and #banked))
	check("as an icon and a number, with no name among them",
		banked and banked[1].icon == 134153 and banked[1].minutes == 120
			and banked[1].name == nil,
		tostring(banked and banked[1] and banked[1].icon))

	-- Released between one scan and the next. A stale list of buffs is worse than none: it
	-- sends somebody to log in a character whose boon is already spent.
	PLAYER_AURAS[1], AURA_LINES[1] = nil, nil
	Family.Bags:Scan()
	check("and releasing it clears them rather than leaving them on disk",
		(Family.Database:Members()[key].meta or {}).banked == nil,
		tostring((Family.Database:Members()[key].meta or {}).banked))

	slot[6] = nil
	Family.Bags:Scan()
end)()

-- Which recipes have a cooldown, without anybody having watched one run
--
-- `GetTradeSkillCooldown` says how long is left and says nothing at all when there is none, so
-- a transmute that is ready looks exactly like a bandage. Family learned it by watching, and a
-- character had to be caught mid-transmute once before anything would say they had one at all.
-- The client's own `SpellCooldowns` knows, and `RecipeCooldowns.lua` is generated from it.
;(function()
	local ARCANITE, TRUESILVER_BAR = 17187, 6037
	local MITHRIL_TO_TRUESILVER = 11480

	check("a transmute is known to have one, by spell",
		Family.Cooldowns:Known(ARCANITE, nil) == 172800,
		tostring(Family.Cooldowns:Known(ARCANITE, nil)))

	-- The half that matters most: a recipe on Classic Era usually arrives with an item id and
	-- no spell at all - measured on a French client, 111 alchemy recipes and not one spell id
	-- among them - so a table keyed only by spell would miss exactly the case it is for.
	-- 171 is Alchemy and 186 is Mining, the skill line ids the recorder files a profession
	-- under. Both are in SkillLines.lua, which is where those numbers come from.
	local ALCHEMY, MINING, GOLD_BAR = 171, 186, 3577

	check("and by what it makes, which is all an Era recipe carries",
		Family.Cooldowns:Known(nil, TRUESILVER_BAR, ALCHEMY) == 172800,
		tostring(Family.Cooldowns:Known(nil, TRUESILVER_BAR, ALCHEMY)))

	-- **And only for the profession whose recipe has the cooldown.** A Truesilver Bar is
	-- transmuted by an alchemist on a two-day wait and smelted by a miner for nothing at
	-- all; a Gold Bar is the same pair. Answered by item alone, the alchemist's cooldown was
	-- handed to the miner - and since mining has no cooldowns whatever on Classic Era, every
	-- miner who could smelt gold grew a Mining column reading "ready" for ever. Reported
	-- from play, with the panel showing it beside a real one.
	check("but not for a profession that makes the same thing for nothing",
		Family.Cooldowns:Known(nil, TRUESILVER_BAR, MINING) == nil,
		tostring(Family.Cooldowns:Known(nil, TRUESILVER_BAR, MINING)))

	check("and the same for gold, which is the pair that was reported",
		Family.Cooldowns:Known(nil, GOLD_BAR, ALCHEMY) == 86400
			and Family.Cooldowns:Known(nil, GOLD_BAR, MINING) == nil,
		tostring(Family.Cooldowns:Known(nil, GOLD_BAR, ALCHEMY)) .. " / "
			.. tostring(Family.Cooldowns:Known(nil, GOLD_BAR, MINING)))

	-- A caller with no profession to offer gets nothing rather than whichever entry is in
	-- the table, which is the same rule the other way round (§2.2).
	check("and a caller who cannot say which profession is answered nothing",
		Family.Cooldowns:Known(nil, TRUESILVER_BAR, nil) == nil,
		tostring(Family.Cooldowns:Known(nil, TRUESILVER_BAR, nil)))

	check("something with no cooldown is not given one",
		Family.Cooldowns:Known(nil, 2589, ALCHEMY) == nil,
		tostring(Family.Cooldowns:Known(nil, 2589, ALCHEMY)))

	-- Per expansion, and not as a nicety: the same transmute is 48 hours on Era, 20 on
	-- Burning Crusade and gone on Mists. A single table would tell a Mists alchemist about a
	-- two-day cooldown that does not exist.
	local held = Family.Capabilities.expansion
	check("on Era, mithril to truesilver has one",
		Family.Cooldowns:Known(MITHRIL_TO_TRUESILVER, nil) == 172800,
		tostring(Family.Cooldowns:Known(MITHRIL_TO_TRUESILVER, nil)))

	Family.Capabilities.expansion = 2
	check("on Burning Crusade it is shorter",
		Family.Cooldowns:Known(MITHRIL_TO_TRUESILVER, nil) == 72000,
		tostring(Family.Cooldowns:Known(MITHRIL_TO_TRUESILVER, nil)))

	Family.Capabilities.expansion = 5
	check("and on Mists it is gone entirely",
		Family.Cooldowns:Known(MITHRIL_TO_TRUESILVER, nil) == nil,
		tostring(Family.Cooldowns:Known(MITHRIL_TO_TRUESILVER, nil)))

	Family.Capabilities.expansion = held

	-- A client whose expansion the table has never heard of answers nothing rather than
	-- reaching for whichever entry happens to be first.
	Family.Capabilities.expansion = 99
	check("an expansion the table does not carry answers nothing",
		Family.Cooldowns:Known(ARCANITE, TRUESILVER_BAR, ALCHEMY) == nil)
	Family.Capabilities.expansion = held

	-- And the scanner acts on it. A recipe whose cooldown nobody has ever seen running is
	-- marked as having one because the client's own tables say so - which is the whole point,
	-- and was the one thing above that no check reached.
	do
		local held = TRADE_SKILL_OPEN
		TRADE_SKILL_OPEN = true
		TRADE_RECIPES[#TRADE_RECIPES + 1] = { "Transmute Truesilver", "optimal", 0,
			"|cffffd000|Hspell:11480|h[Transmute Truesilver]|h|r",
			"|cffffffff|Hitem:6037|h[Truesilver Bar]|h|r" }

		Family.Professions:Scan(true)

		local marked
		for _, record in pairs((Family.Database:Payload(key) or {}).professions or {}) do
			for _, recipe in ipairs(record.recipes or {}) do
				if recipe.itemID == 6037 then marked = recipe end
			end
		end
		check("a scan marks a recipe the client's tables say has a cooldown",
			marked ~= nil and marked.hasCooldown == true,
			tostring(marked and marked.hasCooldown))

		-- And one that has none is left alone, or every recipe in the window would be
		-- reported as a thing somebody is waiting for.
		local plain
		for _, record in pairs((Family.Database:Payload(key) or {}).professions or {}) do
			for _, recipe in ipairs(record.recipes or {}) do
				if recipe.itemID == 2864 then plain = recipe end
			end
		end
		check("and leaves alone one the tables say has none",
			plain ~= nil and plain.hasCooldown == nil,
			tostring(plain and plain.hasCooldown))

		TRADE_RECIPES[#TRADE_RECIPES] = nil
		Family.Professions:Scan(true)
		TRADE_SKILL_OPEN = held
	end

	-- And the same row under two windows means two different things.
	--
	-- Smelt Gold is a mining recipe that makes a Gold Bar, and it carries no spell id on
	-- Classic Era - an item id is all a trade skill record has there. Transmute: Iron to Gold
	-- makes the same bar on a day's cooldown. So the item lane, asked without a profession,
	-- handed the alchemist's cooldown to the miner: mining has no cooldowns at all on that
	-- build, and every miner who could smelt gold grew a Mining column reading "ready" for
	-- ever. Reported from play, from a French Era client, beside a real transmute column.
	do
		local heldOpen, heldName = TRADE_SKILL_OPEN, TRADE_SKILL_NAME
		TRADE_SKILL_OPEN = true

		-- No recipe link, which is what Era hands back for a trade skill row, so the only
		-- id here is the bar it makes.
		TRADE_RECIPES[#TRADE_RECIPES + 1] = { [1] = "Smelt Gold", [2] = "optimal", [3] = 0,
			[5] = "|cffffffff|Hitem:3577|h[Gold Bar]|h|r" }

		local function smeltUnder(profession)
			TRADE_SKILL_NAME = profession
			Family.Professions:Scan(true)

			for line, record in pairs((Family.Database:Payload(key) or {}).professions or {}) do
				if line == Family:SkillLineFor(profession) then
					for _, recipe in ipairs(record.recipes or {}) do
						if recipe.itemID == 3577 then return recipe end
					end
				end
			end
		end

		local mined = smeltUnder("Mining")
		check("a miner's smelt is not given the alchemist's cooldown",
			mined ~= nil and mined.hasCooldown == nil,
			mined and tostring(mined.hasCooldown) or "the row was not recorded at all")

		-- And the alchemist still gets it, or the fix would be a way of answering nothing.
		local transmuted = smeltUnder("Alchemy")
		check("and the alchemist who transmutes the same bar still is",
			transmuted ~= nil and transmuted.hasCooldown == true,
			transmuted and tostring(transmuted.hasCooldown) or "the row was not recorded")

		-- **And the wrong answer already on disk is undone by the fix, not preserved by it.**
		--
		-- A mark used to be carried forward by name for ever, so the miner's rows stayed
		-- marked no matter how often the window was opened: the row was marked because it
		-- had been marked. What is carried forward now is only what Family watched counting
		-- down, and `readyAt` is that evidence. Written here exactly as the old version left
		-- it - a mark and nothing behind it.
		do
			local stale
			for line, record in pairs((Family.Database:Payload(key) or {}).professions or {}) do
				if line == Family:SkillLineFor("Mining") then
					for _, recipe in ipairs(record.recipes or {}) do
						if recipe.itemID == 3577 then stale = recipe end
					end
				end
			end
			stale.hasCooldown = true
			stale.watched = nil

			local after = smeltUnder("Mining")
			check("and a mark left by the old rule is dropped rather than carried forward",
				after ~= nil and after.hasCooldown == nil,
				after and tostring(after.hasCooldown) or "the row went missing")

			-- What Family actually watched survives, or this would have thrown away the
			-- one thing the client cannot say twice.
			--
			-- **Earned through the client, not written by hand.** Setting the mark in the
			-- record and checking it is still there measures nothing: removing the line
			-- that writes it left that check passing. So the row is put on cooldown, the
			-- window is read, and only then is it taken off again.
			TRADE_RECIPES[#TRADE_RECIPES][6] = 3600

			local running = smeltUnder("Mining")
			check("a row the client says is counting down is marked as watched",
				running ~= nil and running.watched == true and running.hasCooldown == true,
				running and tostring(running.watched) or "the row went missing")

			TRADE_RECIPES[#TRADE_RECIPES][6] = nil

			local kept = smeltUnder("Mining")
			check("and stays marked once it has come back, which nothing else can say",
				kept ~= nil and kept.hasCooldown == true and kept.watched == true,
				kept and tostring(kept.hasCooldown) or "the row went missing")

			kept.hasCooldown, kept.watched = nil, nil
		end

		TRADE_RECIPES[#TRADE_RECIPES] = nil
		TRADE_SKILL_NAME = heldName
		Family.Professions:Scan(true)
		TRADE_SKILL_OPEN = heldOpen
	end

	-- And a trinket is not a recipe. A Mechanical Dragonling's summon is filed under
	-- Engineering and has an hour's cooldown, which sailed over the duration floor in the
	-- first version of the generated table. A recipe makes something; that one makes nothing.
	check("a trinket's use cooldown is not mistaken for a recipe's",
		Family.Cooldowns:Known(4073, nil) == nil,
		tostring(Family.Cooldowns:Known(4073, nil)))
end)()

-- The generated table that puts a name under a recorded icon
--
-- Keyed by icon and not by spell, because the icon is what a tooltip row carries and what
-- Family records. 134153 is Rallying Cry both in the client's own SpellMisc and in the bytes
-- the game returned when this was measured (DATASOURCES §2), which is what makes the table a
-- confirmation rather than a correspondence.
;(function()
	local buffs = Family.WorldBuffs or {}

	check("the world buff table is keyed by icon fileID", buffs[134153] == 22888,
		tostring(buffs[134153]))

	local count = 0
	for _ in pairs(buffs) do count = count + 1 end
	check("and holds the twelve a boon can carry", count == 12, tostring(count))

	-- The whole design rests on one icon meaning one buff. If two ever shared one, the panel
	-- would file one under the other's picture and say nothing about it.
	local spells = {}
	local shared = {}
	for icon, spell in pairs(buffs) do
		if spells[spell] then shared[#shared + 1] = tostring(spell) end
		spells[spell] = icon
	end
	check("with no two icons pointing at one spell", #shared == 0, table.concat(shared, " "))
end)()

-- What is inside a boon, which is one tooltip line and eight rows
--
-- The fixture is the string the game actually returned, byte for byte, measured on an enUS Era
-- client with one buff stored (DATASOURCES §2). Its length is checked *first* and on its own,
-- because the whole of L-034 is that a string of this shape can be misread as a shorter one:
-- if a later edit trims the fixture to something tidier, every check below would still pass
-- against a shape the client never produces.
;(function()
	local ROW = " |T134153:24|t |cffffffffRallying Cry of the Dragonslayer (120m)|r"
	local HEAD = "World effects suspended:"
	local FOOT = "While a world effect is suspended, you cannot benefit from"
	local REAL = HEAD .. "\r\n\r\n\r\n" .. ROW .. "\r\n\r\n\r\n\r\n" .. FOOT

	check("the fixture is the 162 bytes the client returned", #REAL == 162, tostring(#REAL))
	check("and the buff row inside it is 66 of them, not the 41 it reads as",
		#ROW == 66, tostring(#ROW))

	PLAYER_AURAS, AURA_LINES = {}, {}

	check("a character with no boon has nothing banked", Family:BankedBuffs() == nil)

	-- The boon is deliberately not first. It was at index 1 in every dump taken, and a reader
	-- that walked to the first aura would have passed every one of them.
	PLAYER_AURAS[1] = { name = "Arcane Intellect", spellID = 10157 }
	PLAYER_AURAS[2] = { name = "Mage Armor", spellID = 22783 }
	PLAYER_AURAS[3] = { name = "Supercharged Chronoboon Displacer", spellID = 349981 }
	AURA_LINES[3] = { "Supercharged Chronoboon Displacer", REAL }

	local banked = Family:BankedBuffs()
	check("a boon with one buff in it reads as one", banked and #banked == 1,
		tostring(banked and #banked))
	check("the icon is the fileID out of the escape, not a name",
		banked and banked[1].icon == 134153, tostring(banked and banked[1].icon))
	check("and the duration is the number of minutes",
		banked and banked[1].minutes == 120, tostring(banked and banked[1].minutes))

	-- The header and the closing sentence are rows of the same string and must not be read as
	-- buffs. Neither ends in a parenthesised duration, which is the whole of the test the
	-- reader applies - and the only one available, since both are localised.
	check("the header and the footer are not counted as buffs", #banked == 1)

	-- A localised client says all of this differently, and nothing in the reader may depend on
	-- an English word. Only the icon escape and the parenthesised duration survive translation.
	AURA_LINES[3] = { "Déplaceur de chronochance surchargé",
		"Effets de monde suspendus :\r\n\r\n" ..
		" |T134153:24|t |cffffffffCri de ralliement du Tueur de dragons (120m)|r\r\n\r\n" ..
		"Tant qu'un effet de monde est suspendu, vous ne pouvez pas bénéficier de" }
	local french = Family:BankedBuffs()
	check("a French client reads the same icon and the same minutes",
		french and #french == 1 and french[1].icon == 134153 and french[1].minutes == 120,
		tostring(french and french[1] and french[1].icon))

	-- Two buffs in one string. **This shape is inferred, not measured** - every dump taken had
	-- one buff in it (DATASOURCES §2 says so in as many words). The check exists so that the
	-- reader's behaviour on more than one is decided here rather than in the game, and it is
	-- written to take any number in any order precisely so the guess is not load-bearing.
	AURA_LINES[3] = { "Supercharged Chronoboon Displacer",
		HEAD .. "\r\n\r\n" ..
		" |T136109:24|t |cffffffffFengus' Ferocity (60m)|r\r\n" ..
		ROW .. "\r\n\r\n" .. FOOT }
	local two = Family:BankedBuffs()
	check("two buffs in one string read as two", two and #two == 2, tostring(two and #two))
	check("in the order the game wrote them", two and two[1].icon == 136109
		and two[2].icon == 134153, tostring(two and two[1].icon))
	check("each with its own duration", two and two[1].minutes == 60
		and two[2].minutes == 120, tostring(two and two[1].minutes))

	-- The duration is the parenthesised number **at the end of the row**, and not the first one
	-- in it. This row is synthetic - no measured buff name carries a bracket - and the check is
	-- here to pin the rule rather than a string: the header and the footer are already excluded
	-- by having no icon escape at all, so anchoring is the only thing standing between a name
	-- with a number in it and a duration read out of the middle of a sentence.
	AURA_LINES[3] = { "Supercharged Chronoboon Displacer",
		HEAD .. "\r\n\r\n" ..
		" |T134153:24|t |cffffffffRallying Cry (2) (120m)|r\r\n\r\n" .. FOOT }
	local bracketed = Family:BankedBuffs()
	check("the duration is the group at the end of the row, not the first one in it",
		bracketed and bracketed[1].minutes == 120,
		tostring(bracketed and bracketed[1] and bracketed[1].minutes))

	-- A boon whose rows say nothing this can parse answers *nothing*, not an empty list. Not
	-- looked and none are different facts (§2.2), and an empty list is the second one.
	AURA_LINES[3] = { "Supercharged Chronoboon Displacer", HEAD .. "\r\n\r\n" .. FOOT }
	check("a boon holding nothing readable answers nothing, not an empty list",
		Family:BankedBuffs() == nil)

	-- Released: the aura goes, and so must the answer.
	PLAYER_AURAS[3] = nil
	check("and releasing the boon clears it", Family:BankedBuffs() == nil)

	PLAYER_AURAS, AURA_LINES = {}, {}
end)()

print()
print("dropping a player nobody has heard from")

-- The other half of the promise in spec §7.1, and the only half that does not need the other
-- person to turn up. A withdrawal travels in the next offering and an offering has to be heard,
-- so somebody who unticks a profession and stops playing stays answerable on every client that
-- holds their last one. Fourteen days is the bound; this is what it does when it fires.
--
-- The one that would be a real fault: `grants` is our own grid, keyed by our own characters,
-- and confusing it with what somebody sent us would quietly untick a player's own professions
-- because a guildmate went on holiday.
;(function()
	local held = FamilyDB.guild
	local NOW, DAY = time(), 86400
	local KEY = "Testers-Fire Maw"

	FamilyDB.guild = {
		known = { [KEY] = {
			["Ancient-FireMaw"] = { from = "Faraway-FireMaw", at = NOW - 15 * DAY,
				meta = { name = "Ancient" } },
			["Fresh-FireMaw"] = { from = "Nearby-FireMaw", at = NOW - 13 * DAY,
				meta = { name = "Fresh" } },
			-- Nothing in `users` for this one at all, which is what a database written
			-- before that table existed looks like. It must still expire.
			["Orphan-FireMaw"] = { from = "Nobody-FireMaw", at = NOW - 30 * DAY,
				meta = { name = "Orphan" } },
		} },
		-- Lower case, because that is what bareName returns and what noteUser writes.
		users = { [KEY] = { faraway = NOW - 15 * DAY, nearby = NOW - 13 * DAY } },
		grants = { [KEY] = { ["Ours-FireMaw"] = { [197] = true } } },
		recipes = { [KEY] = {
			["Ancient-FireMaw"] = { [197] = { spells = { 1 } } },
			["Fresh-FireMaw"] = { [197] = { spells = { 2 } } },
			["Orphan-FireMaw"] = { [197] = { spells = { 3 } } },
		} },
		announced = {},
	}

	local dropped = Family.Guild:ForgetAbandoned()

	local names = {}
	for _, gone in ipairs(dropped) do names[#names + 1] = gone.name end
	check("the ones nobody has heard from are dropped, and named",
		table.concat(names, ",") == "faraway,nobody", table.concat(names, ","))

	local known = FamilyDB.guild.known[KEY]
	check("their characters go with them", known["Ancient-FireMaw"] == nil
		and known["Orphan-FireMaw"] == nil)
	check("and so do the recipe lists filed under those characters",
		FamilyDB.guild.recipes[KEY]["Ancient-FireMaw"] == nil
			and FamilyDB.guild.recipes[KEY]["Orphan-FireMaw"] == nil)
	check("and the note of when they were last heard",
		FamilyDB.guild.users[KEY].faraway == nil)

	-- Thirteen days against fourteen. A bound nobody is inside is not a bound.
	check("somebody heard from inside the window is left alone",
		known["Fresh-FireMaw"] ~= nil)
	check("with their recipe list", FamilyDB.guild.recipes[KEY]["Fresh-FireMaw"] ~= nil)
	check("and their place in who we have heard from",
		FamilyDB.guild.users[KEY].nearby ~= nil)

	-- The fault this check exists for.
	check("our own grid is not touched by any of it",
		FamilyDB.guild.grants[KEY] and FamilyDB.guild.grants[KEY]["Ours-FireMaw"]
			and FamilyDB.guild.grants[KEY]["Ours-FireMaw"][197] == true,
		"a guildmate going quiet unticked our own professions")

	-- One that had nothing to say the first time must have nothing to say the second, or
	-- every login writes to disk and marks the database changed for nothing.
	local again = Family.Guild:ForgetAbandoned()
	check("and running it again drops nothing", #again == 0, tostring(#again))

	FamilyDB.guild = held
end)()

print()
print("the changelog, as release.sh will cut it")

-- release.sh cuts everything between "## Unreleased" and the next "## " into RELEASE-NOTES.md,
-- which is what CurseForge shows. Nobody reads that block whole until it is being published,
-- which is exactly why it drifts: entries are appended a slice at a time, over weeks, by
-- somebody looking at the top of the file.
--
-- It had drifted. The Unreleased section carried "### Added", "### Fixed", "### Added",
-- "### Fixed" - written in two passes a day apart, each pass adding its own headings without
-- looking down - and the release page would have shown all four. Found by reading the section
-- for a status report, not by anything that runs.
;(function()
	local handle = io.open(ROOT .. "/CHANGELOG.md")
	local text = handle and handle:read("*a") or ""
	if handle then handle:close() end

	local sections, headings, twice, loose = 0, 0, {}, {}
	local section, seen = nil, {}

	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		if line:match("^## ") then
			section, seen = line, {}
			sections = sections + 1
		elseif line:match("^### ") then
			headings = headings + 1
			if seen[line] then
				twice[#twice + 1] = string.format("%s -> %s", tostring(section), line)
			end
			seen[line] = true
			seen.any = true
		elseif line:match("^%- %*%*") and section and not seen.any then
			-- An entry above its section's first heading. It reads as belonging to the
			-- version rather than to Added or Fixed, and it is the same drift by another
			-- route: appended to the top of a section instead of the top of a heading.
			loose[#loose + 1] = string.format("%s -> %s", tostring(section),
				line:sub(1, 50))
		end
	end

	-- The scan before anything is concluded from it. A pattern that stops matching reports a
	-- perfectly clean changelog, and this one reads a file the harness does not otherwise
	-- touch, so nothing else would notice.
	check("the changelog is there and has versions and headings in it",
		text ~= "" and sections > 1 and headings > 1,
		string.format("%d section(s), %d heading(s)", sections, headings))

	check("no version repeats a heading, which release.sh would publish twice",
		#twice == 0, table.concat(twice, " | "))
	check("and no entry sits above the heading it belongs under",
		#loose == 0, table.concat(loose, " | "))
end)()

print()
print("the translations")
;(function()
	local function slurp(path)
		local f = io.open(ROOT .. "/" .. path)
		if not f then return nil end
		local text = f:read("*a")
		f:close()
		return text
	end

	-- Characters, not bytes. Cyrillic is two bytes a letter in UTF-8 and a byte count would
	-- declare every Russian translation twice as wide as it is.
	local function width(text)
		local n = 0
		for _ in text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gmatch("[^\128-\191]") do
			n = n + 1
		end
		return n
	end

	local sources = {}
	do
		local list = { "addons/Family/Core.lua", "addons/Family/Locale.lua" }
		for _, name in ipairs { "Comm", "Database", "Wide", "Guild", "Names", "Index",
			"Recipes", "Cooldowns", "Capabilities", "Codec" } do
			list[#list + 1] = "addons/Family/" .. name .. ".lua"
		end
		for _, name in ipairs { "Bags", "Talents", "Professions", "Bank", "Identity",
			"Auctions", "Mail", "Character", "Quests", "Currencies" } do
			list[#list + 1] = "addons/Family/Scanners/" .. name .. ".lua"
		end
		-- Taken from the list this file already loads the panels with, rather than
		-- written out a second time.
		--
		-- It *was* written out a second time, and it drifted: `MemberFilters.lua` was added
		-- to one and not the other, so every string that widget asks for was invisible to
		-- this scan. Nothing was untranslated by luck - all three of its captions are asked
		-- for elsewhere too - and the hole showed itself the day the character panel stopped
		-- asking for one of them and the scan called it unused. A hand-written list beside a
		-- hand-written list is L-047's shape, and the answer is the same: one list.
		for _, name in ipairs(UI_FILES) do
			list[#list + 1] = "addons/Family_UI/" .. name
		end
		for _, path in ipairs(list) do
			local text = slurp(path)
			if not text then
				check("harness can read " .. path, false, "missing")
			else
				sources[path] = text
			end
		end
	end

	-- Every L[...] the source asks for, with the concatenated forms joined back into the one
	-- string the client will actually look up. L["a " .. "b"] is one key, "a b".
	-- One L["..."] lookup, read out of the source at the bracket that opens it.
	--
	-- A function rather than a loop body because two scans below need it - what the addon asks
	-- for, and what it *prints* - and a key read two slightly different ways is a key the two
	-- scans would disagree about while both looked right.
	--
	-- Returns nil for the forms that cannot be read statically, and in every case the position
	-- to carry on scanning from.
	local function keyFrom(text, open)
		local i = text:find("%[", open)
		if not i then return nil, open + 1 end

		local depth, j = 1, i + 1
		while depth > 0 and j <= #text do
			local c = text:sub(j, j)
			if c == "[" then depth = depth + 1
			elseif c == "]" then depth = depth - 1 end
			if depth > 0 then j = j + 1 end
		end

		local inside = text:sub(i + 1, j - 1)
		-- Only the literal forms. L[name] with a variable cannot be read statically and
		-- is deliberately not counted; the strata buttons are the one such site.
		if not inside:match('^%s*"') then return nil, j end

		-- Walked rather than matched. A Lua pattern cannot say "a quote that is not
		-- preceded by a backslash", so '"([^"]*)"' ends a literal at the first \"
		-- inside it and splits the key in two - which showed up as three perfectly
		-- good translations being reported as orphans.
		local joined = {}
		local at = 1
		while true do
			local from = inside:find('"', at, true)
			if not from then break end
			local scan, out = from + 1, {}
			while scan <= #inside do
				local c = inside:sub(scan, scan)
				if c == "\\" then
					out[#out + 1] = inside:sub(scan, scan + 1)
					scan = scan + 2
				elseif c == '"' then
					break
				else
					out[#out + 1] = c
					scan = scan + 1
				end
			end
			joined[#joined + 1] = table.concat(out)
			at = scan + 1
		end

		-- Read out of the file as text, so an escape is still two characters here
		-- and is one character in the table the client builds. Undone, or every
		-- string with a newline in it would be reported as an orphan.
		local key = table.concat(joined)
			:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub('\\"', '"'):gsub("\\\\", "\\")
		return key, j
	end

	local asked = {}
	for path, text in pairs(sources) do
		local at = 1
		while true do
			local open = text:find("%f[%w_]L%[", at)
			if not open then break end
			local key, j = keyFrom(text, open)
			if key then asked[key] = path end
			at = j + 1
		end
	end

	-- What Family says to the player's chat frame, wherever it says it from.
	--
	-- The rule below used to be drawn at a file - everything Slash.lua asks for - on the
	-- grounds that Slash.lua is where Family writes sentences rather than labels. That was
	-- true when it was written and stopped being true without anybody noticing: Guild:Diagnose
	-- prints some forty lines from Family/Guild.lua, and three sentences were added to it with
	-- no translation in any language while this check stayed green.
	--
	-- So the rule follows the call rather than the file. Family:Print is the one way anything
	-- reaches the chat frame, and a string handed straight to it is a sentence being said to
	-- somebody by definition - which is exactly the distinction the comment below draws and
	-- the filename was only ever standing in for.
	--
	-- The whole argument list of each call, not the first thing in it. Three shapes reach the
	-- chat frame and only one of them puts the literal where a simpler scan would look:
	--
	--   Family:Print(L["..."], x)                     the ordinary one
	--   Family:Print(Family.L["..."], x)              Core.lua, which has no local L
	--   Family:Print(n == 1 and L["..."] or L["..."]) singular and plural, both of them said
	--
	-- A scan anchored on "L[ immediately after the bracket" sees the first and misses the
	-- other two, which between them are eight sentences including every error Family prints
	-- when one of its own handlers throws.
	--
	-- Walking to the closing bracket means stepping over string literals rather than counting
	-- brackets blindly: "%d container(s)" is a real argument to a real call, and its bracket
	-- would close the call three arguments early.
	local function callEnd(text, open)
		local depth, j = 1, open + 1
		while depth > 0 and j <= #text do
			local c = text:sub(j, j)
			if c == '"' then
				j = j + 1
				while j <= #text do
					local d = text:sub(j, j)
					if d == "\\" then j = j + 2
					elseif d == '"' then break
					else j = j + 1 end
				end
			elseif c == "-" and text:sub(j, j + 1) == "--" then
				j = (text:find("\n", j, true) or #text + 1)
			elseif c == "(" then depth = depth + 1
			elseif c == ")" then depth = depth - 1
			end
			j = j + 1
		end
		return j
	end

	-- Exercised on a fixture, because nothing in the addon needs it today and that is a fact
	-- rather than an assumption: taking the string-skipping out changes what the scan finds by
	-- exactly nothing. Every real call puts its literal first, so the walk has already read the
	-- key before it reaches any bracket, and a bracket inside a string is balanced in every one
	-- of them - "%d container(s)" closes itself.
	--
	-- It stays for the call that is one character different. A lone bracket inside a string is
	-- ordinary English, and the first Family:Print that has one before its second sentence -
	-- the singular-or-plural form puts one there - would lose that sentence with no sign that
	-- it had. The fixture is the only place that case exists, so the fixture is where it is
	-- held.
	do
		local fixture = 'Family:Print("ends here :)", L["kept"])'
		check("the span walk steps over a bracket inside a string",
			callEnd(fixture, fixture:find("%(")) > fixture:find("L%["),
			"a bracket inside a string closed the call early")

		-- And over one inside a comment, for the same reason and by the same measurement:
		-- no call in the addon has a comment in the middle of it today, and a comment in the
		-- middle of a call is an ordinary thing to write.
		local noted = 'Family:Print(L["a"], -- a note with ) in it\n\t\tL["kept"])'
		check("and over a bracket inside a comment",
			-- Bracketed, both of them. find returns two values, and an inner call left bare
			-- hands its second one on as the next argument - which for find is the plain-search
			-- flag, so the pattern stops being a pattern. This check found that by dying.
			callEnd(noted, (noted:find("%("))) > (noted:find("L%[", (noted:find("\n")))),
			"a bracket inside a comment closed the call early")
	end

	local printed = {}
	for path, text in pairs(sources) do
		local at = 1
		while true do
			-- find returns where the match ended, and the match ends on the bracket.
			local call, open = text:find("Family:Print%s*%(", at)
			if not call then break end

			local last = callEnd(text, open)
			local scan = open
			while true do
				local found = text:find("%f[%w_]L%[", scan)
				if not found or found > last then break end
				local key, j = keyFrom(text, found)
				if key then printed[key] = path end
				scan = j + 1
			end
			at = last
		end
	end

	-- Three lists are looked up as L[name] with a name held in a variable, so the scan above
	-- cannot see them: the section buttons on Character and on Talents, and the window's
	-- frame strata. Read the lists themselves - they are the only dynamic lookups there are,
	-- and a fourth one appearing without a line here shows up as an orphan rather than
	-- silently going untranslated.
	for _, file in ipairs { "addons/Family_UI/Character.lua", "addons/Family_UI/Talents.lua",
		"addons/Family_UI/Window.lua" } do
		local text = sources[file] or ""
		for _, name in ipairs { "SECTIONS", "STRATA" } do
			local list = text:match("local " .. name .. " = {([^}]*)}")
			if list then
				for item in list:gmatch('"([^"]*)"') do asked[item] = file end
			end
		end
	end

	local askedCount = 0
	for _ in pairs(asked) do askedCount = askedCount + 1 end
	check("the sources ask for translated strings at all", askedCount > 0,
		"no L[...] lookups found - the scan is broken, not the addon")

	-- The room each constrained string has, in pixels, read from the code that reserves it
	-- rather than copied into a second list that could drift from it.
	-- A label can be constrained in more than one place - "Professions" is both a tab and a
	-- set button, and the set button is much the narrower. The tightest wins, or the check
	-- would clear a translation that fits one of them and overruns the other.
	local budget = {}
	local function reserve(label, px)
		if budget[label] == nil or px < budget[label] then budget[label] = px end
	end

	local summary = sources["addons/Family_UI/Summary.lua"] or ""
	for label, px in summary:gmatch('label = L%["([^"]*)"%],%s*width = (%d+)') do
		reserve(label, tonumber(px))
	end
	for label, px in summary:gmatch('label = "([^"]*)",%s*width = (%d+)') do
		reserve(label, tonumber(px))
	end

	-- The set buttons across the top of the summary share out a fixed run of pixels, so how
	-- much room a label has depends on how many sets there are. Computed the way the panel
	-- computes it rather than copied, for the same reason as everything else here.
	do
		local chooser = tonumber(summary:match("local CHOOSER_WIDTH = (%d+)"))
		local faction = tonumber(summary:match("local FACTION_ROOM = (%d+)"))
		local sets = {}
		for label in summary:gmatch('id = "[a-z]+", label = L%["([^"]*)"%]') do
			sets[#sets + 1] = label
		end
		if chooser and faction and #sets > 0 then
			local each = math.floor((chooser - faction) / #sets) - 2
			for _, label in ipairs(sets) do reserve(label, each) end
		end
		check("the summary's set buttons were found and measured", #sets > 0,
			"the pattern that reads them no longer matches")
	end

	-- Every other panel reserves its room the same way: a widget is given a width, and
	-- somewhere else in the same file it is given text. Pairing the two by the name of the
	-- widget covers the Professions, Talents, Character, Guild and Wide Family headings
	-- without a hand-written list of them, which would be one more thing to keep in step.
	for path, text in pairs(sources) do
		local reserved = {}
		for widget, px in text:gmatch("([%w_%.%[%]]+):SetWidth%((%d+)%)") do
			reserved[widget] = { px = tonumber(px), button = false }
		end
		-- A button's template puts padding either side of its label.
		for widget, px in text:gmatch("([%w_%.%[%]]+):SetSize%((%d+)%s*,%s*%d+%)") do
			if not reserved[widget] then
				reserved[widget] = { px = tonumber(px), button = true }
			end
		end
		for widget, key in text:gmatch('([%w_%.%[%]]+):SetText%(L%["([^"]*)"%]%)') do
			local room = reserved[widget]
			if room and room.px > 24 then
				reserve(key, room.button and (room.px - 10) or room.px)
			end
		end
	end

	-- Two helpers take their label as an argument rather than setting it on a widget the
	-- pairing above can see: Wide Family's row buttons, and the choice pickers. Both
	-- reserve a known width, so both can still be held to it.
	do
		local wide = sources["addons/Family_UI/Wide.lua"] or ""
		local px = tonumber(wide:match("local BUTTON_W = (%d+)"))
		if px then
			for key in wide:gmatch('nextButton%(L%["([^"]*)"%]') do reserve(key, px - 10) end
		end
		for _, text in pairs(sources) do
			for px2, key in text:gmatch('CreateChoicePicker%([%w_]+, (%d+), L%["([^"]*)"%]') do
				reserve(key, tonumber(px2) - 12)
			end
		end
	end

	-- The section buttons on Character and on Talents are drawn from a list of English
	-- names, looked up as L[name], so the pairing above cannot see them.
	do
		local character = sources["addons/Family_UI/Character.lua"] or ""
		local sw = tonumber(character:match("local SECTION_W = (%d+)"))
		local si = tonumber(character:match("local SECTION_INSET = (%d+)"))
		local list = character:match("local SECTIONS = {([^}]*)}")
		if sw and si and list then
			for name in list:gmatch('"([^"]*)"') do reserve(name, sw - si - 4) end
		end

		local talents = sources["addons/Family_UI/Talents.lua"] or ""
		local tlist = talents:match("local SECTIONS = {([^}]*)}")
		local tpx = tonumber(talents:match("button:SetSize%((%d+), 20%)"))
		if tlist and tpx then
			for name in tlist:gmatch('"([^"]*)"') do reserve(name, tpx - 10) end
		end

		-- The three column headings each panel draws above its list.
		for _, file in ipairs { "addons/Family_UI/Character.lua", "addons/Family_UI/Talents.lua" } do
			local text = sources[file] or ""
			local first = tonumber(text:match("headings%[1%]:SetWidth%((%d+)%)"))
			local third = tonumber(text:match("headings%[3%]:SetWidth%((%d+)%)"))
			for row in text:gmatch("= { (L%[\"[^\n]-) },") do
				local cells = {}
				for key in row:gmatch('L%["([^"]*)"%]') do cells[#cells + 1] = key end
				if #cells == 3 then
					if first then reserve(cells[1], first) end
					if third then reserve(cells[3], third) end
				end
			end
		end
	end

	-- A tab's text starts after its picture and stops short of the strip's edge.
	local window = sources["addons/Family_UI/Window.lua"] or ""
	local tabW = tonumber(window:match("local TAB_W, TAB_H = (%d+)")) or 160
	local inset = tonumber(window:match("local TAB_TEXT_INSET = (%d+)")) or 22
	local tabRoom = tabW - inset - 4
	for _, text in pairs(sources) do
		for label in text:gmatch('RegisterTab%("[%w_]+", L%["([^"]*)"%]') do
			reserve(label, tabRoom)
		end
		for label in text:gmatch('RegisterTab%("[%w_]+", "([^"]*)"') do
			reserve(label, tabRoom)
		end
	end

	local budgeted = 0
	for _ in pairs(budget) do budgeted = budgeted + 1 end
	check("the width budget was read from the source", budgeted > 0,
		"no labelled widths found - the patterns no longer match the code they read")

	-- GameFontNormalSmall averages a little over six pixels a character at this size. The
	-- constant is not a guess dressed up as a measurement: English is checked against it
	-- too, just below, so a value too tight to be true fails on the strings that are known
	-- to fit today.
	local PX_PER_CHAR = 6.5

	local tooLong = {}
	for label, px in pairs(budget) do
		local room = math.floor(px / PX_PER_CHAR)
		if width(label) > room then
			tooLong[#tooLong + 1] = string.format("%s (%d > %d)", label, width(label), room)
		end
	end
	check("English itself fits the budget the check uses", #tooLong == 0,
		table.concat(tooLong, ", ") .. " - loosen PX_PER_CHAR or the check is lying")

	-- End to end, the way a French client sees it: the same lookup that every panel makes,
	-- against the table the client would have chosen. Everything above this reads files;
	-- this is the only check here that proves the mechanism itself resolves anything.
	do
		local was = Family.locale
		Family.locale = "frFR"
		check("a French client reads French out of the same table the panels use",
			Family.L["Summary"] == "Résumé", tostring(Family.L["Summary"]))
		check("and falls back to English for anything not translated yet",
			Family.L["a sentence nobody has translated"] == "a sentence nobody has translated")
		Family.locale = "ruRU"
		check("and a Russian client reads Russian", Family.L["Options"] == "Настройки",
			tostring(Family.L["Options"]))
		Family.locale = "enUS"
		check("and an English client is handed the key back unchanged",
			Family.L["Summary"] == "Summary")
		Family.locale = was
	end

	-- L-013: a document may not claim a language the tree cannot produce.
	--
	-- The store page said five languages for the interface while there was no string table
	-- at all, and the claim survived every reading because the half of the sentence about
	-- the recorded data was true. This reads the languages back out of the documents that
	-- make the claim and insists each one has a locale file with translations in it.
	--
	-- English needs no file: the key is the English sentence (Locale.lua).
	do
		local SPOKEN = {
			German = "deDE", French = "frFR", Spanish = "esES", Russian = "ruRU",
			English = false,
		}

		for _, path in ipairs { "docs/CURSEFORGE.md", "docs/Project high level specs.md" } do
			local f = io.open(ROOT .. "/" .. path)
			if not f then
				check(path .. " is where the harness expects it", false, path)
			else
				local text = f:read("*a")
				f:close()

				-- The one sentence in each that lists them, so a language named in prose
				-- somewhere else is not mistaken for a claim of support.
				local claim = text:match("English, German, French, Spanish and Russian[^\n]*")
				check(path .. " still states which languages Family speaks",
					claim ~= nil,
					"the sentence the check reads has been reworded - update both")

				if claim then
					local missing = {}
					for language, code in pairs(SPOKEN) do
						if code and claim:find(language, 1, true) then
							local table_ = Family.locales[code]
							local n = 0
							if table_ then for _ in pairs(table_) do n = n + 1 end end
							if n == 0 then
								missing[#missing + 1] = language .. " (" .. code .. ")"
							end
						end
					end
					check(path .. " claims no language the tree cannot produce",
						#missing == 0,
						table.concat(missing, ", ") .. " - claimed with no translations")
				end
			end
		end
	end

	for _, code in ipairs { "deDE", "frFR", "esES", "ruRU" } do
		local table_ = Family.locales[code]
		if not table_ then
			check(code .. " registered a table", false, "Locales/" .. code .. ".lua ran but set nothing")
		else
			local orphans, over, mangled = {}, {}, {}
			local count = 0
			for key, word in pairs(table_) do
				count = count + 1
				if not asked[key] then orphans[#orphans + 1] = key end

				local px = budget[key]
				if px and word ~= "" then
					local room = math.floor(px / PX_PER_CHAR)
					if width(word) > room then
						over[#over + 1] = string.format("%q %d > %d", word, width(word), room)
					end
				end

				-- Same specifiers, same order. Anything else is a crash waiting for the one
				-- player whose client is set to this language.
				local function specs(text)
					local found = {}
					for spec in text:gmatch("%%[%-%+ #0-9%.]*([diouxXeEfgGqsc%%])") do
						if spec ~= "%" then found[#found + 1] = spec end
					end
					return table.concat(found, ",")
				end
				if word ~= "" and specs(key) ~= specs(word) then
					mangled[#mangled + 1] = string.format("%q wants [%s] got [%s]",
						key, specs(key), specs(word))
				end
			end

			check(code .. " translates only strings the addon still asks for",
				#orphans == 0, table.concat(orphans, " | "))
			check(code .. " fits the space English was measured in",
				#over == 0, table.concat(over, " | "))
			check(code .. " keeps every format specifier its English keeps",
				#mangled == 0, table.concat(mangled, " | "))
		end
	end


	--------------------------------------------------------------------------------------------
	-- The game's own word for every game noun Family's own sentences use
	--
	-- Family writes prose that names things in the game - "transmutes, mooncloth, salt shakers" -
	-- and those nouns were translated by hand. A hand-translated item name is a name no player
	-- recognises, because the word on their screen came from Blizzard and the word in the sentence
	-- came from a guess. A French player found two of them; nobody was going to find the Spanish
	-- and Russian ones, and there were three.
	--
	-- `tools/game-words.py` is what settles them: it reads the id out of the client's own tables
	-- per locale, per pinned build, and says whether each locale file uses the answer. It needs the
	-- network, so it cannot be a check - and a table nothing enforces is a table that rots the
	-- first time somebody rewrites a sentence.
	--
	-- So the answers live here as well, as the exact fragment each file should carry, with the id
	-- they were measured from. Run the tool when the words change; this is what notices when the
	-- files stop agreeing with them.
	--
	-- Fragments rather than whole names on purpose, and each one for a stated reason: Russian makes
	-- its plural by changing the ending, so "solonka" is carried as its stem; French and Spanish
	-- capitalise these at the start of a heading and not mid-sentence, so the first letter is left
	-- off where that happens.
	--------------------------------------------------------------------------------------------
	
	local GAME_WORDS = {
		deDE = {
			{ 14342, "Mondstoff", "mooncloth" },
			{ 15846, "Salzstreuer", "salt shaker" },
			{ 4338, "Magiestoff", "mageweave" },
			{ 6948, "Ruhestein", "hearthstone" },
		},
		frFR = {
			{ 14342, "étoffe lunaire", "mooncloth" },
			{ 15846, "tamis à sel", "salt shaker" },
			{ 4338, "étoffe de tisse-mage", "mageweave" },
			{ 6948, "ierre de foyer", "hearthstone" },
		},
		esES = {
			{ 14342, "tela lunar", "mooncloth" },
			{ 15846, "salero", "salt shaker" },
			-- Era calls this "Tela de paño mágico" and both later builds call it "Paño de
			-- tejido mágico". The newer two win, and the disagreement is in DATASOURCES §3
			-- rather than only here, because it is the client's and not ours.
			{ 4338, "paño de tejido mágico", "mageweave" },
			{ 6948, "iedra de hogar", "hearthstone" },
		},
		ruRU = {
			{ 14342, "луноткань", "mooncloth" },
			{ 15846, "солонк", "salt shaker" },
			{ 4338, "агическая ткань", "mageweave" },
			{ 6948, "амень возвр", "hearthstone" },
		},
	}
	
	for _, code in ipairs { "deDE", "frFR", "esES", "ruRU" } do
		local handle = io.open(ROOT .. "/addons/Family/Locales/" .. code .. ".lua")
		local text = handle and handle:read("*a") or ""
		if handle then handle:close() end
	
		local absent = {}
		for _, row in ipairs(GAME_WORDS[code]) do
			if not text:find(row[2], 1, true) then
				absent[#absent + 1] = string.format("%s (id %d, our word %q)",
					row[2], row[1], row[3])
			end
		end
	
		check(code .. " calls each thing in the game what the game calls it",
			#absent == 0, table.concat(absent, " | "))
	end
	
	-- And the English is where the list comes from, so a noun added to a sentence without being
	-- added here would be a noun nothing checks. There is no way to notice that from inside a
	-- harness with no client - but there is one thing it can hold: that the tool which *can*
	-- notice it still exists and still names every id these rows do.
	do
		local handle = io.open(ROOT .. "/tools/game-words.py")
		local tool = handle and handle:read("*a") or ""
		if handle then handle:close() end
	
		local missing = {}
		for _, row in ipairs(GAME_WORDS.enUS or GAME_WORDS.deDE) do
			if not tool:find(tostring(row[1]), 1, true) then
				missing[#missing + 1] = tostring(row[1])
			end
		end
	
		check("and tools/game-words.py knows every id those rows were measured from",
			tool ~= "" and #missing == 0, table.concat(missing, ", "))
	end

	-- Every sentence Family says to the player is translated in all four languages.
	--
	-- Not a rule about coverage in general. A missing translation degrades to readable
	-- English on purpose, and that is right for a label standing on its own. It is wrong for
	-- a sentence, because the values inside one come from the same helpers the panels use
	-- and are translated whatever the sentence around them is - so an untranslated line
	-- reads "seen il y a 19j, 2 container(s), meta says jamais", half of each, which is what
	-- a French player was sent when a diagnosis was added without its translations.
	--
	-- **Drawn at the call, not at the file.** It used to say "everything Slash.lua asks for",
	-- because Slash.lua was where Family wrote sentences rather than labels. That was true
	-- when it was written and quietly stopped being true: Guild:Diagnose grew to some forty
	-- printed lines in Family/Guild.lua, and three sentences were added to it in one afternoon
	-- with no translation in any language while this check stayed green. A rule sited at a
	-- filename holds only until somebody writes a sentence somewhere else, and nothing warns
	-- them.
	--
	-- Family:Print is the one door to the chat frame, so a literal handed straight to it is a
	-- sentence being said to somebody by definition. Slash.lua is kept whole beside it rather
	-- than replaced by it: nearly all of it is printed, and the handful that is passed through
	-- a variable first is covered by the file it lives in and would be lost by the swap.
	-- The scan itself, held up before anything is concluded from it.
	--
	-- A check whose input is gathered by a pattern passes perfectly when the pattern stops
	-- matching, and this one gathers its input from eleven files by three different shapes.
	-- The second of these is the widening stated as a property: a rule sited at Slash.lua is
	-- what was wrong, so a scan that has quietly narrowed back to Slash.lua is the failure to
	-- look for, and it would otherwise be invisible.
	local printedCount, printedFiles, beyondSlash = 0, {}, false
	for _, path in pairs(printed) do
		printedCount = printedCount + 1
		printedFiles[path] = true
		if path ~= "addons/Family_UI/Slash.lua" then beyondSlash = true end
	end

	check("the sources print sentences the scan can see", printedCount > 0,
		"no Family:Print(L[...]) calls found - the scan is broken, not the addon")

	-- A floor under the scan above, found a second and much simpler way.
	--
	-- Everything in this section only fails when something is *untranslated*, so a scan that
	-- quietly stops finding keys breaks nothing and reports nothing - it just asks less. The
	-- span walk is the part that could do that: it steps over string literals and comments to
	-- find the end of a call, and getting that wrong loses whole calls silently.
	--
	-- So the plainest possible pattern - a literal sitting immediately inside the bracket -
	-- runs as well, and every key it finds must be one the walk found too. It cannot see the
	-- Family.L and the singular-or-plural forms, which is why it is a floor and not the rule.
	local floor = {}
	for path, text in pairs(sources) do
		local at = 1
		while true do
			local call, open = text:find("Family:Print%s*%(%s*L%[", at)
			if not call then break end
			local key, j = keyFrom(text, text:find("L%[", call))
			if key and printed[key] == nil then floor[#floor + 1] = key end
			at = (j or open) + 1
		end
	end
	table.sort(floor)
	check("and the span walk finds everything the plainest pattern does", #floor == 0,
		table.concat(floor, " | "))
	check("and it sees them outside Slash.lua, which is the whole of this widening",
		beyondSlash, "only Slash.lua - the rule has narrowed back to the file it was moved off")

	-- Everything the addon asks the locale table for, wherever it asks from.
	--
	-- This used to take Slash.lua's `L[...]` lookups and nobody else's, on the reasoning that
	-- Slash.lua is where the sentences are and everywhere else has labels. Two things were
	-- wrong with it. Labels are read by players too - the About panel is Family's own manual,
	-- six dozen strings of prose, and dropping a German line out of it failed nothing at all.
	-- And a rule drawn at a filename goes stale the moment somebody writes a sentence in a
	-- different file, which is the same fault the `printed` scan above was rewritten to fix.
	--
	-- Widening it cost one string. Measured before it was done, rather than after: 638 keys in
	-- the tree and one of them missing from all four languages, so the tree was already
	-- translated and only the gate was narrow. A check that would have passed either way is
	-- worth having anyway - it is the next one that it catches.
	local mustTranslate = {}
	for key, path in pairs(printed) do mustTranslate[key] = path end
	for key, path in pairs(asked) do mustTranslate[key] = path end

	-- The rule held against the scan, because with the tree fully translated a rule that has
	-- narrowed fails nothing at all.
	--
	-- This was found by mutation and not by reasoning: putting the Slash.lua filter back on
	-- the line above - the exact regression this section was rewritten to prevent - left every
	-- check in the file green, including the two guarding the scan. Those watch what was
	-- gathered; this watches what is actually demanded of it, and they are not the same thing.
	local dropped = {}
	for key in pairs(printed) do
		if mustTranslate[key] == nil then dropped[#dropped + 1] = key end
	end
	table.sort(dropped)
	check("and every sentence found is a sentence required", #dropped == 0,
		table.concat(dropped, " | "))

	-- And the same guard for the widening beside it, for the same reason and found the same
	-- way. Putting the Slash.lua filter back on the `asked` line left every check in this file
	-- green, exactly as it had for `printed`: with the tree fully translated, a rule that has
	-- narrowed fails nothing at all until somebody writes the next untranslated string, and by
	-- then nobody is looking at this. So the rule is asserted rather than its consequences.
	local narrowed = {}
	for key, path in pairs(asked) do
		if mustTranslate[key] == nil then narrowed[#narrowed + 1] = path .. ": " .. key end
	end
	table.sort(narrowed)
	check("and every string the addon looks up is required, not one file's worth",
		#narrowed == 0, table.concat(narrowed, " | "))

	-- The scan reaching the panel that made this worth widening. `asked` being empty for a
	-- file, whether because the scan stopped reading it or because somebody moved it, would
	-- satisfy the check above by having nothing to demand.
	local fromAbout = 0
	for _, path in pairs(mustTranslate) do
		if path == "addons/Family_UI/About.lua" then fromAbout = fromAbout + 1 end
	end
	check("and the About panel - Family's own manual - is among the files it reads",
		fromAbout > 20, tostring(fromAbout))

	for _, code in ipairs { "deDE", "frFR", "esES", "ruRU" } do
		local table_ = Family.locales[code] or {}
		local half = {}
		for key in pairs(mustTranslate) do
			if rawget(table_, key) == nil then half[#half + 1] = key end
		end
		table.sort(half)
		check(code .. " translates every sentence Family says to the player",
			#half == 0, table.concat(half, " | "))
	end
end)()

--------------------------------------------------------------------------------------------
-- Handing the minimap button to a collector the player already has
--
-- LibDBIcon is used and never shipped, so it is absent from a clone exactly as it is absent
-- from the game of a player who runs nothing else that embeds it - which is why every check
-- above drove the hand-written button. This drives the other branch by putting a library in
-- front of the real decision function, not in front of a copy of it.
--
-- Last in the file on purpose: adopting a collector is one-way within a session, and every
-- check that wanted the hand-written button has already run.
--------------------------------------------------------------------------------------------

print()
print("the minimap button, where another addon already brought a collector")

;(function()
	local registered, calls = {}, { register = 0, show = 0, hide = 0 }
	local fakeIcon = {
		Register = function(_, name, object, db)
			calls.register = calls.register + 1
			registered[name] = { object = object, db = db }
		end,
		IsRegistered = function(_, name) return registered[name] ~= nil end,
		Show = function(_, name) calls.show = calls.show + 1; calls.shown = name end,
		Hide = function(_, name) calls.hide = calls.hide + 1; calls.hidden = name end,
	}

	local button = _G.FamilyMinimapButton
	local object = Family.UI.broker
	check("there is a broker object to hand over", type(object) == "table")

	-- Refused before adopted, because a refusal that runs afterwards would be testing a
	-- collector that is already in place.
	check("a collector missing the calls we make is refused",
		Family.UI:GiveButtonToCollector({ Register = true }, object) == false)
	check("and so is a collector with nothing to register",
		Family.UI:GiveButtonToCollector(fakeIcon, nil) == false)
	check("neither of which took the button",
		calls.register == 0 and button and button:IsShown() == true)

	FamilyDB.ui.minimapIcon = nil
	FamilyDB.ui.minimapAngle = 137
	Family.UI:SetMinimapShown(true)

	local realGetLibrary = LibStub.GetLibrary
	LibStub.GetLibrary = function(self, name, silent)
		if name == "LibDBIcon-1.0" then return fakeIcon end
		return realGetLibrary(self, name, silent)
	end

	check("login hands the button to the collector", Family.UI:BuildMinimapButton() == "collector")
	check("registering it once, under Family's own name",
		calls.register == 1 and registered["Family"] ~= nil)
	check("with the object the broker bars are given",
		registered["Family"] and registered["Family"].object == object)

	-- The whole point of seeding it: a player who dragged the button somewhere finds it
	-- there, rather than back at the library's default.
	local db = registered["Family"] and registered["Family"].db
	check("and the angle the player left it at, in the unit the library reads",
		db and db.minimapPos == 137, tostring(db and db.minimapPos))
	check("the setting travels with it", db and db.hide == false, tostring(db and db.hide))

	check("Family's own button gets out of the way", button and button:IsShown() == false)

	-- A second login within one session must not register a second time: LibDBIcon raises an
	-- error on a name it already has, which would take the rest of the addon down with it.
	check("a second pass does not register twice",
		Family.UI:BuildMinimapButton() == "collector" and calls.register == 1,
		tostring(calls.register))

	Family.UI:SetMinimapShown(false)
	check("turning the button off asks the collector to hide it",
		calls.hide == 1 and calls.hidden == "Family")
	check("and writes it down where the collector will read it next login",
		db and db.hide == true, tostring(db and db.hide))

	Family.UI:SetMinimapShown(true)
	check("turning it back on asks the collector to show it",
		calls.show == 1 and calls.shown == "Family")
	check("and says so in the same place", db and db.hide == false, tostring(db and db.hide))

	-- A collector that will hand the frame over gets the frame toggled instead, because the
	-- library's own Show repositions as well as showing - it re-anchors the button to the
	-- minimap's centre, which would tear it out of the bar that collected it. Nothing about
	-- that is visible from a check on `hide`, so the check is on which call was made.
	local frame = CreateFrame("Button", nil, Minimap)
	local second = { register = 0, show = 0, hide = 0 }
	local handing = {
		Register = function(_, _, _, passed) second.register = second.register + 1
			second.db = passed end,
		IsRegistered = function() return false end,
		Show = function() second.show = second.show + 1 end,
		Hide = function() second.hide = second.hide + 1 end,
		GetMinimapButton = function(_, name) return name == "Family" and frame or nil end,
	}

	check("a collector that hands the frame over is adopted the same way",
		Family.UI:GiveButtonToCollector(handing, object) == true and second.register == 1)

	Family.UI:SetMinimapShown(false)
	check("turning the button off hides the frame it gave us",
		frame:IsShown() == false)
	check("without the library's Show or Hide, which would move it",
		second.show == 0 and second.hide == 0,
		second.show .. "/" .. second.hide)
	check("and it is still written down for the next login",
		second.db and second.db.hide == true, tostring(second.db and second.db.hide))

	Family.UI:SetMinimapShown(true)
	check("turning it back on shows that same frame", frame:IsShown() == true)
	check("still without the call that repositions", second.show == 0, tostring(second.show))

	-- Handing the button over is one-way: LibDBIcon registers and never unregisters. A player
	-- who has the option off at login therefore hands nothing over at all, which is the only
	-- way that setting can be honoured against a collector that keeps what it is given.
	Family.UI:SetMinimapShown(false)

	local third = { register = 0 }
	local waiting = {
		Register = function() third.register = third.register + 1 end,
		IsRegistered = function() return third.register > 0 end,
		Show = function() end,
		Hide = function() end,
	}

	check("a collector is still taken while the button is switched off",
		Family.UI:GiveButtonToCollector(waiting, object) == true)
	check("but nothing is handed to it, so there is nothing to collect",
		third.register == 0, tostring(third.register))

	Family.UI:SetMinimapShown(true)
	check("switching the button on is what hands it over",
		third.register == 1, tostring(third.register))

	-- A collector that grabs the frame and keeps it. HidingBar does exactly this - it takes
	-- buttons parented to the minimap by name rather than through the broker object, and
	-- after that Hide leaves IsShown true, measured in play on 2026-09-04. Neither the
	-- library nor Family can win that argument, so the player is told once.
	local grabbed = {
		shown = true,
		Show = function(self) self.shown = true end,
		Hide = function() end,
		SetShown = function(self, on) if on then self.shown = true end end,
		IsShown = function(self) return self.shown end,
	}
	local stubborn = {
		Register = function() end,
		IsRegistered = function() return true end,
		Show = function() end,
		Hide = function() end,
		GetMinimapButton = function() return grabbed end,
	}
	check("a collector that will not give the button up is taken like any other",
		Family.UI:GiveButtonToCollector(stubborn, object) == true)

	local function saidSince(mark)
		local said = 0
		for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
			if DEFAULT_CHAT_FRAME.messages[index]:find("holding Family's minimap button",
				1, true) then said = said + 1 end
		end
		return said
	end

	local mark = #DEFAULT_CHAT_FRAME.messages
	Family.UI:SetMinimapShown(false)
	check("the button that would not go is noticed rather than assumed away",
		grabbed:IsShown() == true)
	check("and the player is told, instead of watching a tick box do nothing",
		saidSince(mark) == 1, tostring(saidSince(mark)))
	check("the setting is still recorded, so the next login hands nothing over",
		FamilyDB.ui.minimapIcon.hide == true)

	-- Once. A sentence that arrives every time the box is touched is a sentence nobody reads.
	mark = #DEFAULT_CHAT_FRAME.messages
	Family.UI:SetMinimapShown(true)
	Family.UI:SetMinimapShown(false)
	check("and told once, not on every flip", saidSince(mark) == 0, tostring(saidSince(mark)))

	-- Nothing new is fetched or loaded for any of this. The gate that proved the libraries
	-- were landing where the .toc looks is the same gate that would catch us shipping one.
	local function slurp(path)
		local handle = io.open(ROOT .. "/" .. path)
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end

	local toc = slurp("addons/Family_UI/Family_UI.toc")
	check("the .toc is where this check expects it", toc ~= nil)
	check("and none of this puts LibDBIcon in it",
		toc ~= nil and toc:find("LibDBIcon", 1, true) == nil)

	local pkgmeta = slurp(".pkgmeta")
	check(".pkgmeta is where this check expects it", pkgmeta ~= nil)
	check("nor either library among the externals the packager fetches",
		pkgmeta ~= nil and pkgmeta:find("LibDBIcon", 1, true) == nil
			and pkgmeta:find("LibDataBroker", 1, true) == nil)

	LibStub.GetLibrary = realGetLibrary
end)()

--------------------------------------------------------------------------------------------
-- The icon the addon list shows
--
-- A texture cannot be probed: the client takes whatever path it is handed and never says
-- whether it found anything, which is why HANDOFF section 2 sends textures through a
-- screenshot. Two things about one are checkable here anyway, and both are the kind that a
-- screenshot taken once would not catch again six months later.
--
-- The first is drift. The .toc names a file and Broker.lua names a file, and nothing but
-- reading them together stops one being redrawn under a new name while the other keeps
-- pointing at the old one.
--
-- The second is the format. The client silently declines a TGA it cannot decode, and what it
-- can decode is narrow: uncompressed, 32-bit, sides a power of two. tools/GenerateIcon.py
-- writes one today; the check is here for the day somebody edits the file in something else
-- and saves it compressed, which looks identical everywhere except in the game.
--------------------------------------------------------------------------------------------

print()
print("the icon the addon list and the minimap share")

;(function()
	local function slurp(path, mode)
		local handle = io.open(ROOT .. "/" .. path, mode)
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end

	-- Interface\AddOns\Family_UI\... is where the client looks; addons/Family_UI/... is
	-- where this repository keeps it.
	local function onDisk(clientPath)
		local rest = clientPath:match("^[Ii]nterface\\[Aa]dd[Oo]ns\\(.+)$")
		if not rest then return nil end
		return "addons/" .. rest:gsub("\\", "/")
	end

	local declared = {}
	for _, toc in ipairs { "addons/Family/Family.toc", "addons/Family_UI/Family_UI.toc" } do
		local text = slurp(toc)
		check(toc .. " is where this check expects it", text ~= nil)

		local named = text and text:match("##%s*IconTexture:%s*(%S+)")
		check("and it tells the addon list which icon to draw", named ~= nil, toc)
		declared[toc] = named
	end

	local broker = slurp("addons/Family_UI/Broker.lua") or ""
	local fromCode = broker:match('local ICON = "([^"]+)"')
	check("Broker.lua still names its icon where this check reads it", fromCode ~= nil)

	-- Escaped in the source and plain in the .toc, so they are compared as paths.
	local plain = fromCode and fromCode:gsub("\\\\", "\\")
	for toc, named in pairs(declared) do
		check(toc .. " draws the icon the minimap button draws", named == plain,
			tostring(named) .. " vs " .. tostring(plain))
	end

	local file = plain and onDisk(plain)
	check("and that path points inside this repository", file ~= nil, tostring(plain))

	local tga = file and slurp(file, "rb")
	check("where the file is", tga ~= nil, tostring(file))

	if tga and #tga > 18 then
		local function byte(at) return string.byte(tga, at) end
		local function short(at) return byte(at) + byte(at + 1) * 256 end

		-- Type 2 is uncompressed true-colour. Type 10 is the same picture RLE-packed, which
		-- an image editor will hand you without mentioning it and the client will not draw.
		check("the icon is an uncompressed true-colour TGA", byte(3) == 2, tostring(byte(3)))

		local width, height, bpp = short(13), short(15), byte(17)
		check("32 bits a pixel, so it has the alpha a round button needs",
			bpp == 32, tostring(bpp))

		local function powerOfTwo(n) return n >= 2 and (n % 2 == 0) and 2 ^ math.floor(
			math.log(n) / math.log(2) + 0.5) == n end
		check("and sides the client will accept, which are powers of two",
			powerOfTwo(width) and powerOfTwo(height), width .. "x" .. height)

		-- The pixels are all of it: a file that stops early draws as much of the mark as it
		-- has and nothing says so.
		check("with every pixel present", #tga >= 18 + width * height * 4,
			#tga .. " bytes for " .. width .. "x" .. height)
	end
end)()

--------------------------------------------------------------------------------------------
-- Filtering the summary
--
-- Driven through the boxes and the list the player uses, not through the predicate behind
-- them: L-040 is one screen away, and it says that a check on the call proves the caller and
-- nothing else. So the text goes into the named edit box and its own OnTextChanged fires, the
-- class is chosen by opening the picker and clicking a row in it, and every check afterwards
-- is on which rows are on screen.
--------------------------------------------------------------------------------------------

print()
print("filtering the summary by name, class and level")

;(function()
	local roster = {
		{ key = "Filtera-Fire Maw", name = "Filtera", classFile = "MAGE",    level = 60 },
		{ key = "Filterb-Fire Maw", name = "Filterb", classFile = "MAGE",    level = 24 },
		{ key = "Otherly-Fire Maw", name = "Otherly", classFile = "WARRIOR", level = 42 },
		-- Never told us either. It is here because a filter must not claim to know.
		{ key = "Nameless-Fire Maw", name = "Nameless" },
	}
	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = "Fire Maw",
			classFile = member.classFile, level = member.level, faction = "Alliance" })
	end

	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton("Overview")
	Family.UI:Refresh()

	local search = _G.FamilySummarySearch
	local minBox, maxBox = _G.FamilySummaryLevelMin, _G.FamilySummaryLevelMax
	check("the summary has a filter box", search ~= nil)
	check("and a level range with two ends", minBox ~= nil and maxBox ~= nil)
	if not (search and minBox and maxBox) then return end

	local function typeInto(box, text)
		box:SetText(text)
		if box.__scripts and box.__scripts.OnTextChanged then
			box.__scripts.OnTextChanged(box)
		end
	end

	local function showing()
		local seen = {}
		for _, f in ipairs(frames) do
			if f.__shown ~= false and f.memberKey then seen[f.memberKey] = true end
		end
		return seen
	end

	local everybody = showing()
	check("with nothing typed the family is all there",
		everybody["Filtera-Fire Maw"] and everybody["Filterb-Fire Maw"]
			and everybody["Otherly-Fire Maw"] and everybody["Nameless-Fire Maw"])

	typeInto(search, "filter")
	local byName = showing()
	check("a name narrows the rows to the ones that match",
		byName["Filtera-Fire Maw"] and byName["Filterb-Fire Maw"])
	check("and takes the ones that do not off the screen",
		not byName["Otherly-Fire Maw"] and not byName["Nameless-Fire Maw"])

	-- The whole point of saying so. A panel that silently drops thirty rows is
	-- indistinguishable from one that has lost them.
	check("and the panel says how much it is hiding", visibleText(" shown|r"))

	typeInto(search, "")
	check("clearing the box brings them back",
		showing()["Otherly-Fire Maw"] ~= nil)

	typeInto(minBox, "50")
	typeInto(maxBox, "70")
	local byLevel = showing()
	check("a level range keeps the members inside it", byLevel["Filtera-Fire Maw"] ~= nil)
	check("and drops the ones outside", byLevel["Filterb-Fire Maw"] == nil
		and byLevel["Otherly-Fire Maw"] == nil)

	-- A guard on an invariant rather than a case from play: nothing writes a member without a
	-- level, and Summary.lua carries the measurement that says so. This is what would catch
	-- the guard being taken out, and the fixture is built by hand because the game has no way
	-- to produce one.
	check("a record with no level in it would not be filtered out by level",
		byLevel["Nameless-Fire Maw"] ~= nil)

	typeInto(minBox, "")
	typeInto(maxBox, "")
	check("emptying the range restores everybody", showing()["Filterb-Fire Maw"] ~= nil)

	-- The class list, opened and clicked the way a player opens and clicks it. `onScreen`
	-- rather than `__shown`, because three panels carry a control with this prefix and only
	-- one of them is open.
	local picker
	for _, f in ipairs(frames) do
		if f.prefix == Family.L["Class"] and f.Choices and onScreen(f) then picker = f end
	end
	check("the summary offers a class to filter by", picker ~= nil)

	if picker then
		local offered = {}
		for _, choice in ipairs(picker:Choices()) do offered[tostring(choice.value)] = true end
		check("offering the classes the family actually has",
			offered["MAGE"] and offered["WARRIOR"])
		-- Offering a warlock filter to a family with no warlock is offering a way to show
		-- nothing, which is the rule the character panel's pickers already follow.
		check("and not the ones it does not", offered["WARLOCK"] == nil)

		picker.__scripts.OnClick(picker)
		local list = _G.FamilyChoicePickerList
		check("clicking it opens the list", list ~= nil and list.__shown == true)

		-- A row of the list is a font string on a button rather than a button's own label,
		-- and the choice it carries lives in its handler's closure - so it is found by what
		-- it says, which is what a player has to go on too.
		local picked = false
		for _, row in ipairs(list and list.rows or {}) do
			local text = rawget(row, "text")
			if row.__shown ~= false and type(text) == "table"
				and type(text.__text) == "string"
				and text.__text:find("Mage", 1, true)
				and row.__scripts.OnClick then
				row.__scripts.OnClick(row)
				picked = true
				break
			end
		end
		check("and one of its rows can be chosen", picked)

		local byClass = showing()
		check("choosing a class keeps that class", byClass["Filtera-Fire Maw"] ~= nil
			and byClass["Filterb-Fire Maw"] ~= nil)
		check("and drops the others", byClass["Otherly-Fire Maw"] == nil)
		check("and a record with no class in it would not be filtered out by class",
			byClass["Nameless-Fire Maw"] ~= nil)

		-- Composed with the set, not replacing it. Crafting narrows to members with a
		-- cooldown running, and a class chosen on top of that narrows *that*.
		clickButton("Crafting")
		local crafting = showing()
		check("a set that narrows on its own still narrows with a filter on",
			crafting["Filtera-Fire Maw"] == nil and crafting["Otherly-Fire Maw"] == nil)
		clickButton("Overview")

		-- Put back, which the teardown below says it does and did not: the box was emptied
		-- and the roster forgotten, and the class was left on Mage. Reconcile only drops a
		-- choice the family no longer has, and after this roster goes there are still mages
		-- - so every check after this one was reading a panel filtered to them. Found by the
		-- next section, whose warrior and paladin were simply not on the screen.
		picker:Choose(Family.UI.ANY)
	end

	-- Left as it was found, so that nothing after this reads a filtered panel.
	typeInto(search, "")
	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
	Family.UI:Refresh()
end)()

print()
print("a linked family's quests, end to end")

-- Entry 1 of the backlog, and it was written as a check rather than a feature: the `quests`
-- grant has carried the payload and the count since it was written, and what nothing had ever
-- confirmed was that anything on this side draws them.
--
-- Nothing did. `UI:QuestLines` asked `Family.Database:Payload`, and a borrowed member's key
-- begins with "@" - which the database has never heard of - so a linked family's character
-- came back as *Nothing recorded for this member*: a sentence about our own storage, said
-- about somebody else's records, with the data sitting in memory the whole time.
;(function()
	local held = FamilyDB.wide
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["qfam"] = { name = "Questy-Thunderstrike", grants = {}, siblings = {},
			members = {
				["Questy-Thunderstrike"] = {
					meta = { name = "Questy", realm = "Thunderstrike",
						classFile = "ROGUE", level = 60, faction = "Alliance",
						questCount = 1, questMax = 25 },
					payload = { quests = { seen = time(), entries = {
						{ title = "Borrowed Errand", level = 58, id = 9001,
							objectives = 3, done = 3, category = "Silithus" },
					} } },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("qfam", "Questy-Thunderstrike", true)

	local key = Family.Wide:BorrowedKey("qfam", "Questy-Thunderstrike")

	-- The two halves of the fault, said out loud: the panel's reader finds it and the
	-- database's does not. A check that only asserted the first would pass with the bug
	-- back, because `UI:Payload` was always right - it was simply not the one being called.
	check("a sibling's payload is there when asked the way a panel asks",
		(Family.UI:Payload(key) or {}).quests ~= nil)
	check("and absent when asked of the database, which is the whole trap",
		Family.Database:Payload(key) == nil)

	local lines, message = Family.UI:QuestLines(key, Family.UI:Meta(key), nil)
	check("a linked family's quest log draws rows", lines ~= nil and #lines > 0,
		tostring(message))

	local said = ""
	for _, line in ipairs(lines or {}) do
		said = said .. " " .. tostring(line.left) .. " " .. tostring(line.middle)
	end
	check("naming the quest that was shared",
		said:find("Borrowed Errand", 1, true) ~= nil, said)
	check("and the zone it is in", said:find("Silithus", 1, true) ~= nil, said)

	-- The count comes from the meta, which crosses in the same grant.
	check("and the cap it was shared with",
		type(message) == "string" and message:find("25", 1, true) ~= nil, tostring(message))

	Family.Wide:SetSibling("qfam", "Questy-Thunderstrike", false)
	FamilyDB.wide = held
end)()

print()
print("a linked family's recipes, in the whole-family search")

-- Reported from play 2026-09-05 with a screenshot of Professions / Whole family: twelve
-- bandages found and not one linked family's character among the people who can make them.
--
-- `Recipes:Search` walked `Database:Members` alone, which has never heard of a borrowed key -
-- L-052's class for the fourth time. The data had been crossing the whole time: `professions`
-- is a shared payload, and the summary draws those siblings' skills on the same screen.
;(function()
	local held = FamilyDB.wide
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["recfam"] = { name = "Baker-Thunderstrike", grants = {}, siblings = {},
			members = {
				["Baker-Thunderstrike"] = {
					meta = { name = "Baker", realm = "Thunderstrike",
						classFile = "MAGE", level = 60, faction = "Alliance",
						skills = { [197] = { rank = 275, maxRank = 300 } } },
					payload = { professions = {
						[197] = { recipes = {
							{ name = "Borrowed Mooncloth", spellID = 90001 },
						} },
					} },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("recfam", "Baker-Thunderstrike", true)

	-- Said out loud, because a check that only asserted the second would pass with the bug
	-- back: the record really is unreachable the way this used to ask for it.
	local key = Family.Wide:BorrowedKey("recfam", "Baker-Thunderstrike")
	check("the database has never heard of their key, which is the trap",
		Family.Database:Payload(key) == nil)

	local found = Family.Recipes:Search("borrowed mooncloth")
	check("the search finds the recipe they know", #found == 1, tostring(#found))

	local who = found[1] and found[1].members and found[1].members[1]
	check("with them named as somebody who can make it",
		who and who.name == "Baker", who and tostring(who.name))
	check("and their rank in that profession, which rode in on the same grant",
		who and who.rank == 275, who and tostring(who.rank))
	check("and whose character it is, because it is not one to log in on",
		who and who.familyName == "Baker-Thunderstrike",
		who and tostring(who.familyName))

	-- And drawn, which is the half the report was actually about.
	Family.UI:Show()
	Family.UI:ShowTab("professions")

	local box
	for _, f in ipairs(frames) do
		if f.__name == "FamilyProfessionsSearch" then box = f end
	end
	check("the professions search box is there to type into", box ~= nil)

	if box then
		-- The switch first and the typing after, which is the order the block further
		-- down this file uses and the order that works: clicking it once the results are
		-- up finds whichever panel's button is first in the pool rather than this one's.
		clickButton("Whole family")

		local function typeInto(text)
			box:SetText(text)
			if box.__scripts and box.__scripts.OnTextChanged then
				box.__scripts.OnTextChanged(box)
			end
		end

		typeInto("borrowed mooncloth")

		-- The name the search itself settled on, not the one written in the fixture:
		-- `Names:Recipe` prefers what this client calls a spell, so asking for the
		-- recorded word would be checking the fixture rather than the panel.
		local shownName = found[1] and found[1].name or "Borrowed Mooncloth"
		check("the recipe is drawn", drawnText(shownName), shownName)

		local note
		for _, f in ipairs(frames) do
			local text = type(f.text) == "table" and f.text.__text
			if f.__shown ~= false and type(text) == "string"
				and text:find(shownName, 1, true)
				and type(f.note) == "table" then
				note = f.note.__text
			end
		end

		check("with the sibling named beside it", note
			and note:find("Baker", 1, true) ~= nil, tostring(note))

		-- The same string the possessions search and the item tooltip use, so the three
		-- cannot come to word it differently.
		check("and said to be theirs rather than ours", note
			and note:find("Baker-Thunderstrike", 1, true) ~= nil, tostring(note))

		typeInto("")
	end

	Family.Wide:SetSibling("recfam", "Baker-Thunderstrike", false)
	FamilyDB.wide = held
	Family.UI:Refresh()
end)()

print()
print("a sibling with a crafting cooldown, on the summary's crafting set")

-- Reported from play 2026-09-05: the professions set lists a linked family's characters and the
-- crafting set lists none of them, though one of them is an alchemist. Nothing covered this -
-- the cooldowns travel in the professions grant and there were checks that they are *sent*, and
-- none that a borrowed one reaches the set that only draws members who have one.
;(function()
	local held = FamilyDB.wide
	FamilyDB.wide = {
		enabled = true, id = "us", requests = {}, pendingOut = {},
		links = { ["cdfam"] = { name = "Brewer-Thunderstrike", grants = {}, siblings = {},
			members = {
				["Brewer-Thunderstrike"] = {
					meta = { name = "Brewer", realm = "Thunderstrike",
						classFile = "SHAMAN", level = 60, faction = "Alliance",
						skills = { [171] = { rank = 300, maxRank = 300 } },
						craftCooldowns = {
							{ name = "Transmute: Arcanite", profession = 171,
								readyAt = time() + 3600 },
						} },
					seen = time(),
				},
			} } },
	}
	Family.Wide:SetSibling("cdfam", "Brewer-Thunderstrike", true)

	local borrowed
	for _, member in ipairs(Family.Wide:Siblings()) do
		if member.memberKey == "Brewer-Thunderstrike" then borrowed = member end
	end
	check("the sibling is there to be drawn", borrowed ~= nil)
	check("and its cooldown arrived with it, which is what the grant carries",
		borrowed and #Family.Cooldowns:Crafting(borrowed.meta) > 0,
		borrowed and tostring(#Family.Cooldowns:Crafting(borrowed.meta)))

	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton("Crafting")
	Family.UI:Refresh()

	check("and the crafting set draws them", visibleText("Brewer"))
	check("under the family they belong to", visibleText("Brewer-Thunderstrike"))

	clickButton("Overview")
	Family.Wide:SetSibling("cdfam", "Brewer-Thunderstrike", false)
	FamilyDB.wide = held
	Family.UI:Refresh()
end)()

print()
print("filtering the summary's professions by profession")

-- "Who are the blacksmiths?" - asked from play 2026-09-05 of a summary showing twenty members
-- and every profession each of them holds. Name, class and level are questions about a member
-- and the bar could already ask them; which profession is a question about the column, and
-- nothing could ask it.
;(function()
	local roster = {
		-- Filed by skill line id, which is how a record written today is filed.
		{ key = "Smithy-Fire Maw", name = "Smithy", classFile = "WARRIOR",
			skills = { [164] = { rank = 300, max = 300 } } },
		-- And filed under the word, which is how an older one is - the same profession, and
		-- a picker keyed on what it finds would offer it twice and narrow to half a family
		-- with either. This member is the whole reason the id is normalised.
		{ key = "Oldsmith-Fire Maw", name = "Oldsmith", classFile = "PALADIN",
			skills = { ["Blacksmithing"] = { rank = 150, max = 300 } } },
		{ key = "Stitcher-Fire Maw", name = "Stitcher", classFile = "MAGE",
			skills = { [197] = { rank = 300, max = 300 } } },
	}
	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = "Fire Maw",
			classFile = member.classFile, level = 60, faction = "Alliance",
			skills = member.skills })
	end

	Family.UI:Show()
	Family.UI:ShowTab("summary")

	-- The set button and not the tab of the same name. `clickButton` takes the first frame
	-- whose text matches and the tab strip is built before any panel is, so asking it for
	-- "Professions" opens the professions *panel*. Told apart by where they live: a set
	-- button is inside the summary, and the summary is two frames above its filter box.
	local panel = _G.FamilySummarySearch and _G.FamilySummarySearch.__parent
	panel = panel and panel.__parent
	check("the summary panel is where this check expects it", panel ~= nil)

	local function inPanel(f)
		local at = f
		while type(at) == "table" do
			if at == panel then return true end
			at = type(at.__parent) == "table" and at.__parent or nil
		end
		return false
	end

	local function clickSet(label)
		for _, f in ipairs(frames) do
			if type(f.__text) == "string" and f.__text:find(label, 1, true)
				and clickable(f) and inPanel(f) then
				fireClick(f)
				return true
			end
		end
		return false
	end

	check("the professions column set can be opened", clickSet(Family.L["Professions"]))
	Family.UI:Refresh()

	-- Before anything is chosen, and this is the half that stops the other half being
	-- written as "always sort by rank": with no profession named, a rank would be the rank
	-- of whichever came first alphabetically, so the column is headed and ordered by the
	-- word in it.
	do
		local heading
		for _, column in ipairs(Family.UI.__summaryColumns or {}) do
			if column.key == "prof1" then heading = column.label end
		end
		check("with no profession chosen the column is headed for all of them",
			heading == Family.L["Professions"], tostring(heading))
	end

	local function showing()
		local seen = {}
		for _, f in ipairs(frames) do
			if f.__shown ~= false and f.memberKey then seen[f.memberKey] = true end
		end
		return seen
	end

	local narrow = Family.UI.__summaryNarrow
	check("the professions set brings a profession picker with it",
		narrow ~= nil and narrow:IsShown() == true)

	if narrow then
		local offered, blacksmiths = {}, 0
		for _, choice in ipairs(narrow:Choices()) do
			offered[tostring(choice.label)] = true
			if choice.label == Family:ProfessionName(164) then
				blacksmiths = blacksmiths + 1
			end
		end
		check("offering the professions the family actually has",
			offered[Family:ProfessionName(164)] and offered[Family:ProfessionName(197)])

		-- The record filed under the word and the record filed under the id are one
		-- profession. Offered twice, either choice would find half the blacksmiths and the
		-- list would say the same word twice.
		check("and offering each of them once, however it was filed", blacksmiths == 1,
			tostring(blacksmiths))

		narrow.__scripts.OnClick(narrow)
		local list = _G.FamilyChoicePickerList

		local picked = false
		for _, row in ipairs(list and list.rows or {}) do
			local text = rawget(row, "text")
			if row.__shown ~= false and type(text) == "table"
				and type(text.__text) == "string"
				and text.__text:find(Family:ProfessionName(164), 1, true)
				and row.__scripts.OnClick then
				row.__scripts.OnClick(row)
				picked = true
				break
			end
		end
		check("and one of them can be chosen", picked)

		local byProfession = showing()
		check("choosing a profession keeps whoever has it",
			byProfession["Smithy-Fire Maw"] ~= nil)
		check("including the one whose record was filed under the word",
			byProfession["Oldsmith-Fire Maw"] ~= nil)
		check("and drops whoever does not have it",
			byProfession["Stitcher-Fire Maw"] == nil)

		----------------------------------------------------------------------------
		-- And the rank of *that* profession, which is the rest of the original ask
		--
		-- The file said for a week what this needed: somebody to say which profession
		-- first, because a rank sorted with none chosen would be the rank of whichever
		-- came first alphabetically. The picker above is that somebody, and this is the
		-- two joined.
		----------------------------------------------------------------------------

		local heading
		for _, column in ipairs(Family.UI.__summaryColumns or {}) do
			if column.key == "prof1" then heading = column.label end
		end
		check("the column says which profession it is now about",
			heading == Family:ProfessionName(164), tostring(heading))

		-- Read off the anchors rather than out of the pool: rows are handed out in an
		-- order that is not the order they are drawn in.
		local function order()
			local seen = {}
			for _, f in ipairs(frames) do
				if onScreen(f) and type(f.memberKey) == "string" and f.__points then
					local point = f.__points.TOPLEFT
					seen[#seen + 1] = { key = f.memberKey,
						y = type(point) == "table" and point.y or 0 }
				end
			end
			table.sort(seen, function(a, b) return (a.y or 0) > (b.y or 0) end)

			local keys = {}
			for _, row in ipairs(seen) do keys[#keys + 1] = row.key end
			return keys
		end

		local function positionOf(key, list)
			for index, at in ipairs(list) do
				if at == key then return index end
			end
		end

		Family.UI:SetSummarySort("professions", "prof1")
		Family.UI:Refresh()

		local up = order()
		check("ordering by it puts the lower rank first",
			positionOf("Oldsmith-Fire Maw", up) < positionOf("Smithy-Fire Maw", up),
			table.concat(up, ", "))

		-- The record filed under the word sorts with the one filed under the id, because
		-- `professionID` makes them one profession here as it does in the picker. Filed
		-- apart, the 150 would have had no rank at all and sorted last.
		check("with the record filed under the word ordered by its rank, not left out",
			positionOf("Oldsmith-Fire Maw", up) ~= nil, table.concat(up, ", "))

		Family.UI:SetSummarySort("professions", "prof1")
		Family.UI:Refresh()

		local down = order()
		check("and clicking again turns it round",
			positionOf("Smithy-Fire Maw", down) < positionOf("Oldsmith-Fire Maw", down),
			table.concat(down, ", "))

		Family.UI:SetSummarySort("professions", "prof1")
		Family.UI:Refresh()

		-- Composed with the rest of the bar rather than replacing it: "which of my level 60
		-- blacksmiths" is one question with both halves on one row.
		local minBox = _G.FamilySummaryLevelMin
		minBox:SetText("70")
		if minBox.__scripts and minBox.__scripts.OnTextChanged then
			minBox.__scripts.OnTextChanged(minBox)
		end
		check("and a level range on top of it narrows that rather than replacing it",
			showing()["Smithy-Fire Maw"] == nil)
		minBox:SetText("")
		if minBox.__scripts and minBox.__scripts.OnTextChanged then
			minBox.__scripts.OnTextChanged(minBox)
		end

		-- A set with no narrowing of its own takes the control away rather than leaving it
		-- asking a question about a column that is no longer on the screen.
		check("another set can be opened", clickSet(Family.L["Overview"]))
		Family.UI:Refresh()
		check("and a set that narrows nothing takes the picker away",
			narrow:IsShown() == false)

		-- And the choice with it. Reconcile drops a value that is no longer offered, so
		-- going back finds everybody rather than the blacksmiths from a minute ago.
		check("and going back to it starts from everybody again",
			clickSet(Family.L["Professions"]))
		Family.UI:Refresh()
		local back = showing()
		check("with nobody left out by a choice made before the set changed",
			back["Stitcher-Fire Maw"] ~= nil, tostring(narrow:Label()))

		clickSet(Family.L["Overview"])
	end

	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
	Family.UI:Refresh()
end)()

print()
print("filtering the summary's crafting by which cooldown")

-- The rest of the backlog's entry 3 for this set: *crafting by cooldown and profession*. One
-- list answers both, because in the data they are one list - a timer several recipes share is
-- named after its profession, and alchemy's always is, while a profession with exactly one
-- timed recipe is named after the recipe. So "Alchemy" and "Mooncloth" are offered side by
-- side, each being the widest true thing that can be said about the timer under it.
--
-- And this set is the one where a narrowing has a second job. It is the only set that admits
-- to hiding columns for want of room, so choosing a cooldown cuts the columns to that one -
-- narrowing only the rows would have left the same headings on screen and answered nothing.
;(function()
	local roster = {
		-- Two recipes on one timer, which is what the client does with every transmute: they
		-- arrive with the same readyAt, group into one, and are headed by the profession
		-- because "Transmute: Arcanite" is a lie about the other one.
		{ key = "Alchy-Fire Maw", name = "Alchy", classFile = "SHAMAN",
			craftCooldowns = {
				{ name = "Transmute: Arcanite", profession = 171,
					readyAt = time() + 3600 },
				{ name = "Transmute: Air to Fire", profession = 171,
					readyAt = time() + 3600 },
			} },
		-- One timed recipe, so the recipe's own name is the more useful heading.
		{ key = "Weaver-Fire Maw", name = "Weaver", classFile = "PRIEST",
			craftCooldowns = {
				{ name = "Mooncloth", profession = 197, readyAt = time() + 7200 },
			} },
		{ key = "Tanner-Fire Maw", name = "Tanner", classFile = "ROGUE",
			craftCooldowns = {
				{ name = "Salt Shaker", profession = 165, readyAt = time() + 900 },
			} },
	}
	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = "Fire Maw",
			classFile = member.classFile, level = 60, faction = "Alliance",
			craftCooldowns = member.craftCooldowns })
	end

	Family.UI:Show()
	Family.UI:ShowTab("summary")

	-- The set button and not the tab of the same name, told apart by where it lives - the
	-- same reason the professions check above tells them apart.
	local panel = _G.FamilySummarySearch and _G.FamilySummarySearch.__parent
	panel = panel and panel.__parent

	local function inPanel(f)
		local at = f
		while type(at) == "table" do
			if at == panel then return true end
			at = type(at.__parent) == "table" and at.__parent or nil
		end
		return false
	end

	local function clickSet(label)
		for _, f in ipairs(frames) do
			if type(f.__text) == "string" and f.__text:find(label, 1, true)
				and clickable(f) and inPanel(f) then
				fireClick(f)
				return true
			end
		end
		return false
	end

	local function showing()
		local seen = {}
		for _, f in ipairs(frames) do
			if f.__shown ~= false and f.memberKey then seen[f.memberKey] = true end
		end
		return seen
	end

	local function headings()
		local said = {}
		for _, column in ipairs(Family.UI.__summaryColumns or {}) do
			said[#said + 1] = tostring(column.label)
		end
		return said
	end

	local function heads(word)
		for _, label in ipairs(headings()) do
			if label:find(word, 1, true) then return true end
		end
		return false
	end

	check("the crafting column set can be opened", clickSet(Family.L["Crafting"]))
	Family.UI:Refresh()

	local alchemy = Family:ProfessionName(171)
	check("a shared timer is headed by its profession", heads(alchemy), alchemy)
	check("and a lone one by the recipe", heads("Mooncloth"))

	local narrow = Family.UI.__summaryNarrow
	check("the crafting set brings a cooldown picker with it",
		narrow ~= nil and narrow:IsShown() == true)
	check("captioned as the thing it narrows", narrow.prefix == Family.L["Cooldowns"],
		tostring(narrow.prefix))

	local offered = {}
	for _, choice in ipairs(narrow:Choices()) do offered[tostring(choice.label)] = true end
	check("offering the cooldowns the family actually has",
		offered[alchemy] and offered["Mooncloth"] and offered["Salt Shaker"])

	local everybody = showing()
	check("with all three of them drawn before anything is chosen",
		everybody["Alchy-Fire Maw"] and everybody["Weaver-Fire Maw"]
			and everybody["Tanner-Fire Maw"])

	narrow.__scripts.OnClick(narrow)
	local list = _G.FamilyChoicePickerList

	local picked = false
	for _, row in ipairs(list and list.rows or {}) do
		local text = rawget(row, "text")
		if row.__shown ~= false and type(text) == "table"
			and type(text.__text) == "string"
			and text.__text:find("Mooncloth", 1, true) and row.__scripts.OnClick then
			row.__scripts.OnClick(row)
			picked = true
			break
		end
	end
	check("and one of them can be chosen", picked)

	local byCooldown = showing()
	check("choosing a cooldown keeps whoever is waiting on it",
		byCooldown["Weaver-Fire Maw"] ~= nil)
	check("and drops whoever is waiting on a different one",
		byCooldown["Alchy-Fire Maw"] == nil and byCooldown["Tanner-Fire Maw"] == nil)

	-- The half that makes this worth having on this set rather than on any other. A panel
	-- that hides columns for want of room and then offers a filter that leaves them all up
	-- has answered the easy half of the question.
	check("and the columns come down to the one that was chosen", heads("Mooncloth"))
	check("with the others gone rather than merely unpopulated",
		heads(alchemy) == false and heads("Salt Shaker") == false,
		table.concat(headings(), ", "))

	-- Composed with the rest of the bar, like every other narrowing: both halves of "which
	-- of my level 60s is waiting on the mooncloth" are on one row.
	--
	-- **Both directions**, because a rule with one direction checked is half a rule. Every
	-- member of this roster is level 60, so a range that excludes them all would have gone
	-- green with no narrowing in the file at all - which is what the first draft of this did,
	-- and the mutation that removes the set's `narrow` is what said so.
	local minBox = _G.FamilySummaryLevelMin
	local function typeLevel(text)
		minBox:SetText(text)
		if minBox.__scripts and minBox.__scripts.OnTextChanged then
			minBox.__scripts.OnTextChanged(minBox)
		end
	end

	typeLevel("50")
	local composed = showing()
	check("a level range they all pass leaves the chosen cooldown's member drawn",
		composed["Weaver-Fire Maw"] ~= nil)
	check("and the others still dropped, so the range has not replaced the choice",
		composed["Alchy-Fire Maw"] == nil and composed["Tanner-Fire Maw"] == nil)

	typeLevel("70")
	check("and a range none of them passes drops that member too, the other way round",
		showing()["Weaver-Fire Maw"] == nil)
	typeLevel("")

	-- Leaving the set and coming back starts from everybody, because Reconcile drops a value
	-- the new set does not offer - and the columns have to come back with it, or the panel
	-- would keep the one column a choice nobody can see any more had cut it to.
	clickSet(Family.L["Overview"])
	Family.UI:Refresh()
	check("a set that narrows nothing takes the picker away", narrow:IsShown() == false)

	clickSet(Family.L["Crafting"])
	Family.UI:Refresh()
	local back = showing()
	check("and coming back finds everybody again", back["Alchy-Fire Maw"] ~= nil)
	check("with the columns it had cut back on the panel", heads(alchemy),
		table.concat(headings(), ", "))

	clickSet(Family.L["Overview"])
	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
	Family.UI:Refresh()
end)()

--------------------------------------------------------------------------------------------
-- Every field Wide Family shares is a field Family writes
--
-- `CATEGORIES` maps a grant onto the meta and payload keys it carries, and it is written by
-- hand beside the scanners rather than derived from them - which is deliberate, because a new
-- scanner must not be able to widen what a link already agreed to. The cost of that is a list
-- of strings with nothing joining it to the fields those scanners actually write.
--
-- It cost something. `mailExpires` sat in the mail category from the first commit and nothing
-- has ever written a field by that name: the scanner writes `mailExpiresBy`. Every sibling
-- ever shared arrived without an expiry, silently, and both sides looked like they were
-- working - the category was granted, the letters came through, and only the one figure that
-- says *when you lose them* was missing.
--
-- A word boundary, not a substring: `mailExpires` is a prefix of `mailExpiresBy`, so a plain
-- find would have called the typo written and passed.
--------------------------------------------------------------------------------------------

print()
print("what Wide Family shares is what Family records")

;(function()
	local function slurp(path)
		local handle = io.open(ROOT .. "/" .. path)
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end

	local toc = slurp("addons/Family/Family.toc")
	check("Family.toc is where this check expects it", toc ~= nil)

	-- Every file the data addon loads except Wide.lua itself, because a field named only
	-- there is by definition a field nothing writes. The libraries are fetched at package
	-- time and are absent from a clone.
	local sources, unreadable = {}, {}
	for line in (toc or ""):gmatch("[^\r\n]+") do
		local file = line:match("^%s*([%w_\\/]+%.lua)%s*$")
		if file and not file:find("^Libs") then
			local path = "addons/Family/" .. file:gsub("\\", "/")
			if not path:find("Wide%.lua$") then
				local text = slurp(path)
				if text then sources[#sources + 1] = text
				else unreadable[#unreadable + 1] = path end
			end
		end
	end

	check("and every file it lists could be read", #unreadable == 0,
		table.concat(unreadable, " "))
	check("with enough of them for the question to mean anything",
		#sources > 20, tostring(#sources))

	local function namedSomewhere(field)
		local pattern = "%f[%w_]" .. field .. "%f[^%w_]"
		for _, text in ipairs(sources) do
			if text:find(pattern) then return true end
		end
		return false
	end

	local wide = slurp("addons/Family/Wide.lua") or ""
	local identity = wide:match("local IDENTITY = {(.-)}")
	check("Wide.lua still declares its identity fields where this reads them",
		identity ~= nil)

	local orphans = {}
	local function consider(field)
		if not namedSomewhere(field) then orphans[#orphans + 1] = field end
	end

	for name in (identity or ""):gmatch('"([%w_]+)"') do consider(name) end
	for _, category in ipairs(Family.Wide.CATEGORIES or {}) do
		for _, field in ipairs(category.meta or {}) do consider(field) end
		for _, key in ipairs(category.payload or {}) do consider(key) end
	end

	check("no field is shared under a name nothing in Family writes",
		#orphans == 0, table.concat(orphans, ", "))
end)()

--------------------------------------------------------------------------------------------
-- Saying at login whose mail is running out
--------------------------------------------------------------------------------------------

print()
print("the notice about mail that is about to go")

;(function()
	local now = time()
	local roster = {
		{ key = "Losted-Fire Maw", name = "Losted", expires = now - 3600 },
		{ key = "Postie-Fire Maw", name = "Postie", expires = now + 86400 },
		{ key = "Latera-Fire Maw", name = "Latera", expires = now + 10 * 86400 },
		{ key = "Nomail-Fire Maw", name = "Nomail" },
	}
	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = "Fire Maw",
			level = 60, classFile = "MAGE", faction = "Alliance",
			mailExpiresBy = member.expires })
	end

	check("three days is what it warns at until somebody says otherwise",
		Family.UI:MailNoticeDays() == 3, tostring(Family.UI:MailNoticeDays()))

	local function named()
		local seen = {}
		for _, member in ipairs(Family.Mail:Expiring(Family.UI:MailNoticeDays() * 86400)) do
			seen[member.name] = member
		end
		return seen
	end

	local within = named()
	check("a character whose letters go tomorrow is in it", within["Postie"] ~= nil)
	check("and one whose letters have already gone", within["Losted"] ~= nil)
	check("marked as gone rather than as expiring now, which are different facts",
		within["Losted"] and within["Losted"].expired == true)
	check("one with ten days left is not", within["Latera"] == nil)
	check("and one with nothing in the post is not", within["Nomail"] == nil)

	-- Soonest first, so the one that cannot be saved reads before the one that can.
	local order = Family.Mail:Expiring(Family.UI:MailNoticeDays() * 86400)
	check("soonest first", order[1] and order[1].name == "Losted", order[1] and order[1].name)

	-- One character to a line, under a heading, so the notice is a list rather than a wall.
	local function noticeText()
		return table.concat(Family.UI:MailNotice() or {}, "\n")
	end

	local lines = Family.UI:MailNotice()
	check("the notice is a heading and a line for each of them",
		lines and #lines == 4, tostring(lines and #lines))
	check("the heading says what the list is about",
		lines and lines[1]:find("mail running out", 1, true) ~= nil,
		tostring(lines and lines[1]))

	local said = noticeText()
	check("the notice names them", said:find("Postie", 1, true)
		and said:find("Losted", 1, true), said)

	-- Same-named alts on two realms are ordinary, and a line that names one names neither.
	check("with the realm beside the name",
		said:find("Postie-Fire Maw", 1, true) ~= nil, said)
	check("and leaves out the one that is not running out",
		said:find("Latera", 1, true) == nil, said)
	check("saying outright that one of them is already lost",
		said:find("already gone", 1, true) ~= nil, said)

	-- The number is the player's, inside bounds it is worth having.
	check("a longer warning takes in more of them", Family.UI:SetMailNoticeDays(14) == 14
		and named()["Latera"] ~= nil)
	check("nought is refused", Family.UI:SetMailNoticeDays(0) == nil)
	check("and so is longer than mail lives", Family.UI:SetMailNoticeDays(31) == nil)
	check("and so is a word", Family.UI:SetMailNoticeDays("soon") == nil)
	check("a refused number leaves the one in force alone",
		Family.UI:MailNoticeDays() == 14, tostring(Family.UI:MailNoticeDays()))

	-- A saved variables file from another build, or edited by hand.
	FamilyDB.mailNoticeDays = 99
	check("a stored number this build will not accept falls back to three",
		Family.UI:MailNoticeDays() == 3, tostring(Family.UI:MailNoticeDays()))
	Family.UI:SetMailNoticeDays(3)

	-- The whole way through: the event, the wait, and the line in the chat frame.
	-- Everything said from the heading onwards, because the notice is a heading and then a
	-- line per character - reading only the line that carries the heading would have said
	-- the whole thing arrived when only its first word had.
	local function saidAtLogin()
		local mark = #DEFAULT_CHAT_FRAME.messages
		fire("PLAYER_ENTERING_WORLD")
		for _ = 1, 4 do advance(4) end

		local block, from = {}, nil
		for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
			local message = DEFAULT_CHAT_FRAME.messages[index]
			if message:find("mail running out", 1, true) then from = index end
			if from and index >= from then block[#block + 1] = message end
		end

		return #block > 0 and table.concat(block, "\n") or nil
	end

	local atLogin = saidAtLogin()
	check("logging in says it, without anything being opened", atLogin ~= nil)
	check("naming the character whose letters go tomorrow",
		atLogin and atLogin:find("Postie", 1, true) ~= nil, tostring(atLogin))

	FamilyDB.mailNotice = false
	check("and switching it off is silence, not a shorter sentence",
		saidAtLogin() == nil)
	FamilyDB.mailNotice = nil

	-- The control in the options panel, driven the way a player drives it.
	Family.UI:Show()
	Family.UI:ShowTab("options")

	local field
	for _, f in ipairs(frames) do
		local name = f.__name
		if type(name) == "string" and name:find("FamilyOptionNumber", 1, true) then
			field = f
		end
	end
	check("the options panel has a box to put the number in", field ~= nil)

	if field then
		field:SetText("7")
		field.__scripts.OnEnterPressed(field)
		check("what is typed into it becomes the setting",
			Family.UI:MailNoticeDays() == 7, tostring(Family.UI:MailNoticeDays()))

		-- Silently keeping a refused value would be the control lying about the setting.
		field:SetText("99")
		field.__scripts.OnEnterPressed(field)
		check("a number it will not take leaves the setting alone",
			Family.UI:MailNoticeDays() == 7, tostring(Family.UI:MailNoticeDays()))
		check("and the box goes back to saying what is actually in force",
			field.__text == "7", tostring(field.__text))
	end

	-- A shared character, named by the family it belongs to. Built the other way round first,
	-- on an assumption about how Wide Family gets used; §6 is why the family name is here and
	-- not a marker meaning "somebody else's".
	local wide = Family.Wide:Store()
	wide.links["fam-post"] = {
		name = "Spazzacamino",
		grants = {},
		siblings = {},
		members = {
			["Tossica-Auberdine"] = {
				meta = { name = "Tossica", realm = "Auberdine", classFile = "MAGE",
					level = 60, faction = "Alliance", mailExpiresBy = now + 2 * 86400 },
				seen = now,
			},
		},
	}
	check("a shared character can be made a sibling",
		Family.Wide:SetSibling("fam-post", "Tossica-Auberdine", true) == true)

	Family.UI:SetMailNoticeDays(3)
	local withSibling = noticeText()
	check("a sibling whose mail is going is named too",
		withSibling:find("Tossica-Auberdine", 1, true) ~= nil, withSibling)
	check("under the name of the family it belongs to",
		withSibling:find("Spazzacamino", 1, true) ~= nil, withSibling)
	check("and still in urgency order, ours and theirs together",
		withSibling:find("Losted", 1, true) < withSibling:find("Tossica", 1, true),
		withSibling)

	-- Wide Family off is not "no siblings today", it is nothing shared at all.
	local wasEnabled = Family.Wide:Enabled()
	Family.Wide:SetEnabled(false)
	check("with Wide Family switched off no sibling is named",
		noticeText():find("Tossica", 1, true) == nil, noticeText())
	Family.Wide:SetEnabled(wasEnabled)

	--------------------------------------------------------------------------------------
	-- A family big enough to be a wall of text
	--------------------------------------------------------------------------------------

	local crowd = {}
	for index = 1, 25 do
		local key = string.format("Crowder%02d-Fire Maw", index)
		crowd[#crowd + 1] = key
		Family.Database:SetMeta(key, { name = string.format("Crowder%02d", index),
			realm = "Fire Maw", level = 60, classFile = "MAGE", faction = "Alliance",
			mailExpiresBy = now + 2 * 86400 + index })
	end

	local crowdLines = Family.UI:MailNotice()
	local expiring = Family.Mail:Expiring(Family.UI:MailNoticeDays() * 86400)

	-- **Nobody is left off.** This was capped at ten with the remainder counted, and the
	-- reason it is not is that a character missing from the list is a character whose mail
	-- goes without being mentioned - which a number at the bottom does not prevent. The
	-- length is the player's to control: the warning period is a setting.
	check("a big family gets a line each, however big it is",
		crowdLines and #crowdLines == #expiring + 1,
		tostring(crowdLines and #crowdLines) .. " lines for " .. #expiring .. " members")

	local crowded = table.concat(crowdLines or {}, "\n")
	check("with every one of them named", (function()
		for index = 1, 25 do
			if not crowded:find(string.format("Crowder%02d-Fire Maw", index), 1, true) then
				return false
			end
		end
		return true
	end)())

	check("one character to a line and no more", (function()
		for index = 2, #(crowdLines or {}) do
			if select(2, crowdLines[index]:gsub(",", "")) > 0 then return false end
		end
		return true
	end)())

	check("and the most urgent still at the top",
		crowded:find("Losted", 1, true) < crowded:find("Crowder01", 1, true), crowded)

	for _, key in ipairs(crowd) do Family.Database:Forget(key) end
	Family.Wide:SetSibling("fam-post", "Tossica-Auberdine", false)
	wide.links["fam-post"] = nil

	Family.UI:SetMailNoticeDays(3)
	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
end)()

--------------------------------------------------------------------------------------------
-- Which names carry their realm
--
-- Last in the file, because the second half of it empties every realm but one out of the
-- database to ask the other question, and nothing after it would find what it expected.
--------------------------------------------------------------------------------------------

print()
print("the realm on a name, and when it is worth the width")

;(function()
	local here = GetRealmName()
	check("the harness knows which realm is being played", type(here) == "string")

	local mine = { { name = "Solo", realm = here, key = "Solo-" .. tostring(here) } }
	Family.UI:NamesOf(mine)
	check("a character on the realm being played carries no realm",
		mine[1].label:find("(@", 1, true) == nil, mine[1].label)

	local away = { { name = "Solo", realm = "Pyrewood Village", key = "Solo-Pyrewood" } }
	Family.UI:NamesOf(away)
	check("and one anywhere else carries it, alone in its list or not",
		away[1].label:find("(@Pyrewood Village", 1, true) ~= nil, away[1].label)

	-- Two of one name are told apart whichever realms they are on, including when one of
	-- them is the realm being played: that one would otherwise be the bare name beside a
	-- qualified one, which reads as though only the other needed explaining.
	local twins = {
		{ name = "Twin", realm = here, key = "Twin-here" },
		{ name = "Twin", realm = "Pyrewood Village", key = "Twin-away" },
	}
	Family.UI:NamesOf(twins)
	check("two of one name are told apart even on the realm being played",
		twins[1].label:find("(@", 1, true) ~= nil
			and twins[2].label:find("(@Pyrewood Village", 1, true) ~= nil,
		twins[1].label .. " / " .. twins[2].label)
end)()

--------------------------------------------------------------------------------------------
-- Calling a linked family something else
--------------------------------------------------------------------------------------------

print()
print("an alias for a linked family")

;(function()
	local store = Family.Wide:Store()
	store.links["fam-alias"] = {
		name = "Smith-PyrewoodVillage",
		grants = {},
		siblings = {},
		members = {
			["Soulsock-PyrewoodVillage"] = {
				meta = { name = "Soulsock", realm = "PyrewoodVillage", classFile = "WARRIOR",
					level = 60, faction = "Horde" },
				seen = time(),
			},
		},
	}
	local link = store.links["fam-alias"]

	check("with no alias a family is called what the link was made under",
		Family.Wide:Called(link) == "Smith-PyrewoodVillage",
		tostring(Family.Wide:Called(link)))

	check("setting one takes", Family.Wide:SetAlias("fam-alias", "Zia Pina") == "Zia Pina")
	check("and it is what the family is called", Family.Wide:Called(link) == "Zia Pina")
	check("while the name it is reached at is untouched",
		link.name == "Smith-PyrewoodVillage", tostring(link.name))

	-- The names a whisper can be addressed to are the link's own name and the members it has
	-- told us about. None of them may become the alias: a whisper to "Zia Pina" reaches
	-- nobody, and the failure would be silent - Wide Family would simply stop updating.
	local addressable = { link.name }
	for memberKey in pairs(link.members or {}) do
		addressable[#addressable + 1] = memberKey
	end

	local aliased = false
	for _, name in ipairs(addressable) do
		if name:find("Zia Pina", 1, true) then aliased = true end
	end
	check("and no name a whisper is addressed to became the alias", not aliased,
		table.concat(addressable, ", "))

	check("spaces round it are not part of it",
		Family.Wide:SetAlias("fam-alias", "  Zia Pina  ") == "Zia Pina")
	check("and emptying it puts the real name back",
		Family.Wide:SetAlias("fam-alias", "   ") == nil
			and Family.Wide:Called(link) == "Smith-PyrewoodVillage")

	Family.Wide:SetAlias("fam-alias", "Zia Pina")
	Family.Wide:SetSibling("fam-alias", "Soulsock-PyrewoodVillage", true)

	local named
	for _, member in ipairs(Family.Wide:Siblings()) do
		if member.memberKey == "Soulsock-PyrewoodVillage" then named = member.familyName end
	end
	check("a sibling is filed under the alias", named == "Zia Pina", tostring(named))

	-- And so is a borrowed member, which is a different list and was answering differently.
	--
	-- `Siblings` are the ones ticked into our own lists; `BorrowedMembers` is everybody a
	-- link shares, which is what the character picker offers - and it handed out `link.name`
	-- raw. So the picker headed a group "shared by Smith-PyrewoodVillage" while every other
	-- screen in the addon called that family Zia Pina. Reported from play 2026-09-05, and it
	-- is this file's own recurring shape: two functions answering one question, one of them
	-- right, and nothing asking the second.
	local borrowed
	for _, member in ipairs(Family.Wide:BorrowedMembers()) do
		if member.key == "Soulsock-PyrewoodVillage" then borrowed = member.familyName end
	end
	check("and so is a borrowed member, which is the list the picker offers",
		borrowed == "Zia Pina", tostring(borrowed))

	-- Read through the picker's own gatherer rather than through the list under it, because
	-- that is where the heading is actually built and it is the thing that was wrong.
	local heading
	for _, member in ipairs(Family.UI:EveryMember()) do
		if member.key == Family.Wide:BorrowedKey("fam-alias", "Soulsock-PyrewoodVillage") then
			heading = member.group
		end
	end
	check("so the picker heads their group with what the family is called",
		heading and heading:find("Zia Pina", 1, true) ~= nil, tostring(heading))
	check("and not with the character the link was made through",
		heading and heading:find("Smith-PyrewoodVillage", 1, true) == nil, tostring(heading))

	-- And the tooltip, which reads its own way round: the index looks the link up from a
	-- borrowed key rather than being handed one. Left unchecked, a mutation putting the raw
	-- name back here went unnoticed while every other check stayed green.
	link.members["Soulsock-PyrewoodVillage"].payload = {
		bags = { { slots = { { id = 2589, count = 5 } } } },
	}
	Family.Index:Invalidate(Family.Wide:BorrowedKey("fam-alias", "Soulsock-PyrewoodVillage"))

	local onTooltip
	for _, owner in ipairs(select(1, Family.Index:Owners(2589))) do
		if owner.name == "Soulsock" then onTooltip = owner.familyName end
	end
	check("and an item tooltip says the alias too", onTooltip == "Zia Pina",
		tostring(onTooltip))

	-- And the possessions panel, which had the field and drew the bare name anyway. A count
	-- against a name is read as "I can go and get that", and for somebody else's character
	-- that is not true - which is the reason the tooltip has said whose it is all along.
	--
	-- The whole label in one string, realm and all, because that is what a reader sees on the
	-- line: the two halves found separately could be two different rows.
	-- A guild bank on the realm being played, holding the same cloth, so that the panel has a
	-- guild row to draw at all. Long on purpose: the report was a name cut in the middle by a
	-- realm the reader is already standing on. Without one of these here, putting the raw key
	-- back in the panel failed nothing - the check for it was measuring an empty list.
	FamilyDB.guilds = FamilyDB.guilds or {}
	FamilyDB.guilds["Loch Modan Yachting Club-Fire Maw"] = {
		tabs = { { slots = { { id = 2589, count = 12 } } } },
	}
	Family.Index:Invalidate()

	Family.UI:ShowTab("contents")
	local contentsEveryoneAgain = _G.FamilyContentsEveryone
	check("the possessions panel is there to ask", contentsEveryoneAgain ~= nil)

	if contentsEveryoneAgain then
		contentsEveryoneAgain.__scripts.OnClick(contentsEveryoneAgain)
		_G.FamilyContentsSearch:SetText("Linen")
		Family.UI:Refresh()

		check("the possessions search says whose character it is",
			visibleText("Soulsock |cff888888(@PyrewoodVillage)|r |cff9d9d9dof Zia Pina|r"))

		-- The whole label with its colour closed, so that a realm left on the end of it
		-- would put a character between the name and the "|r" and fail this.
		check("and a guild bank on this realm is not made to carry the realm",
			visibleText("|cff40c040Loch Modan Yachting Club|r"))

		------------------------------------------------------------------------------
		-- And in an order the player chose
		--
		-- The list was items in the search's order with each item's owners in the
		-- index's, which is two nested loops imposing one answer. Driven through the
		-- buttons rather than through the variable behind them, because a button is
		-- what a player has - and read off what was drawn rather than off the rows,
		-- which are pooled and say what they were last given.
		------------------------------------------------------------------------------

		local sort = Family.UI.__contentsSort
		check("the possessions search offers an order", sort ~= nil
			and sort.buttons.item ~= nil and sort.buttons.who ~= nil
			and sort.buttons.many ~= nil)

		if sort then
			check("and its bar and its caption are both there while it is asked",
				sort.bar:IsShown() == true and sort.note:IsShown() == true)

			-- Same rule as the professions panel: the caption belongs to the panel, so a
			-- second line lands under the bar where the status line lives, and the bar has
			-- to grow to hold it.
			-- Asked of every order rather than of whichever happens to be on.
			--
			-- Only one of these three captions wraps at this harness's metrics, and a check
			-- looking at either of the other two cannot fail - which is what the first
			-- version of this did. Which of them wraps also depends on the language, so
			-- picking one by hand would be picking today's.
			local tallEnough, worst = true, ""
			for _, id in ipairs { "item", "who", "many" } do
				sort.buttons[id].__scripts.OnClick(sort.buttons[id])
				local needed = math.ceil(sort.note:GetStringHeight() or 0)
				if (sort.bar.__height or 0) < needed then
					tallEnough = false
					worst = id .. ": " .. tostring(sort.bar.__height)
						.. " against " .. tostring(needed)
				end
			end
			sort.buttons.item.__scripts.OnClick(sort.buttons.item)

			check("and the bar is at least as tall as whichever caption is on it",
				tallEnough, worst)

			local function drawnAs(field)
				local out = {}
				for _, line in ipairs(Family.UI.__contentsLines or {}) do
					out[#out + 1] = line[field]
				end
				return out
			end

			-- More than one line, or nothing below is measuring an order.
			check("and there is more than one line to put in one",
				#drawnAs("sortWho") > 1, tostring(#drawnAs("sortWho")))

			-- By item first, which is what it opens on: one item name here, so what is
            -- being read is the tiebreak under it - most first.
			local counts = drawnAs("count")
			local falling = true
			for index = 2, #counts do
				if counts[index] > counts[index - 1] then falling = false end
			end
			check("by item, whoever has most of it comes first", falling,
				table.concat(counts, ", "))

			sort.buttons.who.__scripts.OnClick(sort.buttons.who)

			local names = drawnAs("sortWho")
			local rising = true
			for index = 2, #names do
				if names[index] < names[index - 1] then rising = false end
			end
			check("and asking for character order gives one", rising,
				table.concat(names, ", "))

			-- A guild bank sorts among the names by the name it shows, not by the colour
			-- code in front of it - which is what sorting the drawn label would do.
			local found = false
			for _, name in ipairs(names) do
				if name == "Loch Modan Yachting Club" then found = true end
			end
			check("and a guild sorts by its name rather than by its colour code", found,
				table.concat(names, ", "))

			sort.buttons.item.__scripts.OnClick(sort.buttons.item)
		end

		_G.FamilyContentsSearch:SetText("")
		contentsEveryoneAgain.__scripts.OnClick(contentsEveryoneAgain)

		-- And both halves away again with the mode.
		--
		-- The check above says the caption is there when the buttons are, and on its own
		-- that passes just as well for a caption that is *always* there - which is the
		-- fault this panel's neighbour shipped: an order explained over a list that is not
		-- in it. A rule with one direction checked is half a rule.
		if sort then
			check("and the bar and its caption both go with the mode",
				sort.bar:IsShown() == false and sort.note:IsShown() == false)
		end
	end

	FamilyDB.guilds["Loch Modan Yachting Club-Fire Maw"] = nil
	Family.Index:Invalidate()

	-- A guild's key is its name and its realm joined with a hyphen, and it was drawn raw into
	-- a column 160 pixels wide - so "Loch Modan Yachting Club" on the realm being played came
	-- out cut, losing the end of the name to a realm the reader is on. Reported from play.
	--
	-- The realm comes off by matching a realm we can name and never by cutting at a hyphen,
	-- which is what the fourth of these is about: a guild may have one in its name.
	check("a guild on the realm being played does not carry it",
		Family.UI:GuildLabel("Loch Modan Yachting Club-Fire Maw")
			== "Loch Modan Yachting Club",
		tostring(Family.UI:GuildLabel("Loch Modan Yachting Club-Fire Maw")))
	check("written either way, because a key is built from GetRealmName and a whisper is not",
		Family.UI:GuildLabel("Loch Modan Yachting Club-FireMaw")
			== "Loch Modan Yachting Club")
	check("and a guild anywhere else keeps its realm, as a character does",
		Family.UI:GuildLabel("Loch Modan Yachting Club-Thunderstrike")
			== "Loch Modan Yachting Club-Thunderstrike")
	check("and a hyphen in the guild's own name survives",
		Family.UI:GuildLabel("Half-Life-Fire Maw") == "Half-Life",
		tostring(Family.UI:GuildLabel("Half-Life-Fire Maw")))

	-- **Never sent.** It is our name for their family and not theirs, and the check is on
	-- what actually leaves rather than on a comment saying it does not.
	local offering = Family.Wide:Offering(link)
	local function mentions(value)
		if type(value) == "string" then return value:find("Zia Pina", 1, true) ~= nil end
		if type(value) ~= "table" then return false end
		for key, item in pairs(value) do
			if mentions(key) or mentions(item) then return true end
		end
		return false
	end
	check("and nothing carrying the alias goes out", not mentions(offering))

	Family.Wide:SetSibling("fam-alias", "Soulsock-PyrewoodVillage", false)
	store.links["fam-alias"] = nil
end)()

--------------------------------------------------------------------------------------------
-- The consent grid's own arithmetic, and what the new categories carry
--
-- `Family_UI/Wide.lua` works out whether the grid fits the row it is drawn in and prints a
-- line when it does not. Its comment says the harness reads that line, and searching for one
-- that names it finds nothing - which is what this was written to fix.
--
-- **That first reading was too strong, and a mutation said so.** Putting the cell width back
-- to what would not fit turns this check red *and* the check that nothing complains while the
-- summary draws, because the complaint is printed at database-ready and that check sweeps
-- whatever arrived. So it was covered, sideways, by something looking for any complaint at
-- all. What it did not have was a check that says the number out loud - and a gate that only
-- fires as "something printed a warning" tells you a category too many was added without ever
-- telling you by how much, which is the difference between a red light and a diagnosis.
--------------------------------------------------------------------------------------------

print()
print("what a linked family may be granted")

;(function()
	local function slurp(path)
		local handle = io.open(ROOT .. "/" .. path)
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end

	------------------------------------------------------------------------------------
	-- The possessions search's three columns, added up
	--
	-- Item, who has it, where it is - three font strings on one row, and the room they get
	-- is four numbers written in four places. Forty pixels moved from the first to the
	-- second on 2026-09-05 so that a linked family's name could follow a character's and a
	-- guild's name would stop being cut, and moving a number in a row of numbers that have
	-- to add up is exactly how a column comes to be drawn over the one beside it.
	--
	-- Read out of the panel's own source, the way the consent grid's are below, because the
	-- alternative is a check that agrees with a constant copied into this file - which
	-- agrees with itself and with nothing else.
	------------------------------------------------------------------------------------

	local contents = slurp("addons/Family_UI/Contents.lua")
	check("the possessions panel is where this check expects it", contents ~= nil)

	local textAt = tonumber((contents or ""):match('r%.text:SetPoint%("LEFT", (%d+), 0%)'))
	local textWide = tonumber((contents or ""):match("r%.text:SetWidth%((%d+)%)"))
	local whoAt = tonumber((contents or ""):match('r%.who:SetPoint%("LEFT", (%d+), 0%)'))
	local whoWide = tonumber((contents or ""):match("r%.who:SetWidth%((%d+)%)"))
	local whereAt = tonumber((contents or ""):match('r%.where:SetPoint%("RIGHT", %-(%d+), 0%)'))
	local whereWide = tonumber((contents or ""):match("r%.where:SetWidth%((%d+)%)"))

	check("and still lays its result row out in the six numbers this adds up",
		textAt and textWide and whoAt and whoWide and whereAt and whereWide)

	if textAt and textWide and whoAt and whoWide and whereAt and whereWide then
		local room = (Family.UI.CONTENT_W or 0) - (Family.UI.SCROLLBAR_W or 0)

		check("the item column stops before the owner column starts",
			textAt + textWide <= whoAt,
			(textAt + textWide) .. " against " .. whoAt)

		-- The rightmost is anchored to the right-hand edge, so where it starts depends on
		-- how wide the list is - which is the panel's content less its scroll bar.
		local whereFrom = room - whereAt - whereWide
		check("and the owner column stops before the where column starts",
			room > 0 and whoAt + whoWide <= whereFrom,
			(whoAt + whoWide) .. " against " .. whereFrom .. " in " .. room)
	end

	local source = slurp("addons/Family_UI/Wide.lua")
	check("the grid's panel is where this check expects it", source ~= nil)

	local nameWidth = tonumber((source or ""):match("local NAME_WIDTH = (%d+)"))
	local cellMin = tonumber((source or ""):match("local CELL_MIN = (%d+)"))
	check("and still declares the two widths this arithmetic needs",
		nameWidth ~= nil and cellMin ~= nil)

	local room = (Family.UI.CONTENT_W or 0) - (Family.UI.SCROLLBAR_W or 0)
	local needed = (nameWidth or 0) + #Family.Wide.CATEGORIES * (cellMin or 0)
	check("the consent grid fits the row it is drawn in", room > 0 and needed <= room,
		needed .. " needed, " .. room .. " there, for " .. #Family.Wide.CATEGORIES
			.. " categories")

	--------------------------------------------------------------------------------------
	-- What each category actually carries
	--------------------------------------------------------------------------------------

	local store = Family.Wide:Store()
	store.links["fam-grant"] = { name = "Granter-FireMaw", grants = {}, siblings = {},
		members = {} }

	Family.Database:SetMeta("Granted-FireMaw", {
		name = "Granted", realm = "Fire Maw", level = 60, classFile = "MAGE",
		faction = "Alliance",
		played = 123456, rested = 4321, xpMax = 9999,
		guild = "Social Airlines", hearth = "Southshore", hearthID = 42,
		currencies = { [1] = 7 }, currenciesSeen = time(),
		boons = true, banked = { "Rallying Cry" },
		craftCooldowns = { { profession = 171, readyAt = time() + 3600 } },
		cooldownItems = { [3577] = 171 }, itemCooldowns = { [3577] = time() + 60 },
		specs = { [171] = 1 }, specsSeen = time(),
	})

	local function offered()
		local members = Family.Wide:Offering(store.links["fam-grant"])
		local entry = members["Granted-FireMaw"]
		return entry and entry.meta or {}
	end

	-- Nothing granted, nothing sent. Said first, because every check below it is only
	-- meaningful if this one holds.
	store.links["fam-grant"].grants["Granted-FireMaw"] = {}
	check("a member with no category granted is not offered at all",
		-- Parenthesised: Offering answers the members *and* a count, and next(t, count)
		-- is next asked about a key that is not in the table.
		next((Family.Wide:Offering(store.links["fam-grant"]))) == nil)

	local expected = {
		character  = { "played", "rested", "xpMax", "guild", "guildless", "hearth",
			"hearthID" },
		currencies = { "currencies", "currenciesSeen" },
		worldbuffs = { "boons", "banked" },
		professions = { "skills", "specs", "specsSeen", "craftCooldowns", "cooldownItems",
			"itemCooldowns" },
		quests     = { "questCount", "questMax" },
	}

	for id, fields in pairs(expected) do
		store.links["fam-grant"].grants["Granted-FireMaw"] = { [id] = true }
		local meta = offered()

		local missing = {}
		for _, field in ipairs(fields) do
			-- `guildless` and `questMax` are not set on this fixture, so what is checked is
			-- that the category names them, not that a value happened to exist.
			local named = false
			for _, category in ipairs(Family.Wide.CATEGORIES) do
				if category.id == id then
					for _, carried in ipairs(category.meta or {}) do
						if carried == field then named = true end
					end
				end
			end
			if not named then missing[#missing + 1] = field end
		end

		check(id .. " carries everything the panels read for it", #missing == 0,
			table.concat(missing, ", "))

		-- And carries nothing from the categories beside it.
		check("and nothing " .. id .. " was not granted", (function()
			for _, other in pairs(expected) do
				for _, field in ipairs(other) do
					local mine = false
					for _, want in ipairs(fields) do if want == field then mine = true end end
					if not mine and meta[field] ~= nil then return false end
				end
			end
			return true
		end)())
	end

	-- The report that started this: a shared character's crafting cooldowns.
	store.links["fam-grant"].grants["Granted-FireMaw"] = { professions = true }
	local meta = offered()
	check("a granted profession now carries its cooldowns, which is the reported fault",
		type(meta.craftCooldowns) == "table" and #meta.craftCooldowns == 1,
		tostring(meta.craftCooldowns))
	check("and enough of them for the crafting panel to draw a row",
		#Family.Cooldowns:Crafting(meta) > 0,
		tostring(#Family.Cooldowns:Crafting(meta)))

	store.links["fam-grant"] = nil
	Family.Database:Forget("Granted-FireMaw")
end)()

--------------------------------------------------------------------------------------------
-- One member, one line
--------------------------------------------------------------------------------------------

print()
print("a record that says the same thing twice is one answer")

;(function()
	local key = "Doubled-Fire Maw"
	Family.Database:SetMeta(key, { name = "Doubled", realm = "Fire Maw", level = 60,
		classFile = "MAGE", faction = "Alliance",
		skills = { [171] = { name = "Alchemy", rank = 300, maxRank = 300 } } })

	-- The same recipe twice, which is what a stored record can hold: the scanner writes back
	-- every row the client's window listed and does not decide that two of them were one.
	-- The second copy is the one carrying the timer, deliberately - dropping it silently is
	-- the failure worth checking for, because the row would then say ready.
	Family.Database:SetPayload(key, { professions = { [171] = {
		rank = 300, maxRank = 300, recipes = {
			{ name = "Transmute: Fire to Earth", itemID = 7078, hasCooldown = true },
			{ name = "Transmute: Fire to Earth", itemID = 7078, hasCooldown = true,
				readyAt = time() + 3600 },
		},
	} } })
	Family.Index:Invalidate(key)

	local row
	for _, found in ipairs(Family.Recipes:Search("fire to earth")) do
		if found.name and found.name:find("Fire to Earth", 1, true) then row = found end
	end
	check("the recipe is found at all", row ~= nil)

	local mine, listed = 0, nil
	for _, member in ipairs(row and row.members or {}) do
		if member.key == key then
			mine = mine + 1
			listed = listed or member
		end
	end
	check("and a member whose record holds it twice is listed once", mine == 1, tostring(mine))

	check("with the timer the second copy carried, not the first copy's silence",
		listed and listed.cooldown and listed.cooldown.ready == false,
		tostring(listed and listed.cooldown and listed.cooldown.ready))

	-- The other way round, and it is the half that matters more: a copy saying *ready* must
	-- never be allowed to overwrite one that knows a timer is running. With the timer only
	-- ever second, a rule that simply took the last copy would pass the check above and send
	-- somebody to an alchemist who cannot transmute for another three hours.
	local other = "Reversed-Fire Maw"
	Family.Database:SetMeta(other, { name = "Reversed", realm = "Fire Maw", level = 60,
		classFile = "MAGE", faction = "Alliance",
		skills = { [171] = { name = "Alchemy", rank = 300, maxRank = 300 } } })
	Family.Database:SetPayload(other, { professions = { [171] = {
		rank = 300, maxRank = 300, recipes = {
			{ name = "Transmute: Fire to Earth", itemID = 7078, hasCooldown = true,
				readyAt = time() + 3600 },
			{ name = "Transmute: Fire to Earth", itemID = 7078, hasCooldown = true },
		},
	} } })
	Family.Index:Invalidate(other)

	local reversed
	for _, found in ipairs(Family.Recipes:Search("fire to earth")) do
		if found.name and found.name:find("Fire to Earth", 1, true) then
			for _, member in ipairs(found.members) do
				if member.key == other then reversed = member end
			end
		end
	end
	check("and a running timer is not overwritten by a copy that says ready",
		reversed and reversed.cooldown and reversed.cooldown.ready == false,
		tostring(reversed and reversed.cooldown and reversed.cooldown.ready))
	Family.Database:Forget(other)

	--------------------------------------------------------------------------------------
	-- And the window that listed it twice says so, rather than being guessed at
	--------------------------------------------------------------------------------------

	local wasDebug, wasOpen, wasName = FamilyDB.debug, TRADE_SKILL_OPEN, TRADE_SKILL_NAME
	local wasRecipes = TRADE_RECIPES

	FamilyDB.debug = true
	TRADE_SKILL_OPEN, TRADE_SKILL_NAME = true, "Alchemy"
	TRADE_RECIPES = {
		{ "Header", "header" },
		{ "Silver Rod", "optimal", 2, "|cffffd000|Hspell:3339|h[Silver Rod]|h|r",
		  "|cffffffff|Hitem:6338|h[Silver Rod]|h|r" },
		{ "Silver Rod", "optimal", 2, "|cffffd000|Hspell:3339|h[Silver Rod]|h|r",
		  "|cffffffff|Hitem:6338|h[Silver Rod]|h|r" },
	}

	local mark = #DEFAULT_CHAT_FRAME.messages
	fire("TRADE_SKILL_SHOW")
	advance(1)

	local noticed = false
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("listed spell:3339 twice", 1, true) then
			noticed = true
		end
	end
	check("a window listing one recipe on two rows says which rows", noticed)

	-- Nothing is dropped: which of two identical rows is the real one is a question about
	-- the client, and a scanner that answers it by guessing is worse than a record with a
	-- duplicate in it that every reader already handles.
	local stored = Family.Database:Payload(Family:CurrentMember())
	local alchemy = stored and stored.professions and stored.professions[171]
	check("and keeps both, because which one is real is not its question",
		alchemy and alchemy.recipes and #alchemy.recipes == 2,
		alchemy and alchemy.recipes and tostring(#alchemy.recipes))

	TRADE_RECIPES, TRADE_SKILL_NAME = wasRecipes, wasName
	TRADE_SKILL_OPEN, FamilyDB.debug = wasOpen, wasDebug
	Family.Database:Forget(key)
end)()

--------------------------------------------------------------------------------------------
-- Everybody's reputations on one screen
--------------------------------------------------------------------------------------------

print()
print("the family's reputations, as factions rather than as members")

;(function()
	-- The same lookup the panel uses, so this compares what is drawn against what the client
	-- would call it rather than against a word written here.
	local function standingWord(standing)
		return _G["FACTION_STANDING_LABEL" .. standing] or tostring(standing)
	end

	local function rep(id, name, category, standing, value, maximum)
		return { id = id, name = name, category = category, standing = standing,
			value = value, maximum = maximum }
	end

	local ours = {
		{ key = "Repone-Fire Maw", name = "Repone", reps = {
			rep(59, "Thorium Brotherhood", "Steamwheedle", 5, 100, 1000),
			rep(576, "Timbermaw Hold", "Other", 4, 500, 1000),
		} },
		{ key = "Reptwo-Fire Maw", name = "Reptwo", reps = {
			-- The same faction, further along: this member heads the faction's block
			-- rather than adding a second block for it.
			rep(59, "Thorium Brotherhood", "Steamwheedle", 7, 200, 1000),
			-- And one nobody else has, which must still be listed.
			rep(270, "Zandalar Tribe", "Other", 3, 10, 1000),
		} },
		-- Two more with the same faction, so that it has more people than a block shows
		-- and the fold has something to fold. Three is the cut, so four is the smallest
		-- fixture that can tell "shows everybody" from "shows three and says so".
		{ key = "Repthree-Fire Maw", name = "Repthree", reps = {
			rep(59, "Thorium Brotherhood", "Steamwheedle", 4, 300, 1000),
		} },
		{ key = "Repfour-Fire Maw", name = "Repfour", reps = {
			rep(59, "Thorium Brotherhood", "Steamwheedle", 3, 400, 1000),
		} },
	}

	for _, member in ipairs(ours) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = "Fire Maw",
			level = 60, classFile = "MAGE", faction = "Alliance" })
		Family.Database:SetPayload(member.key, { reputations = member.reps })
	end

	Family.UI:Show()
	Family.UI:ShowTab("character")
	check("the reputations section can be opened", clickButton("Reputations"))

	-- Read off the rows themselves rather than swept out of every font string in the
	-- client: two panels can say "Timbermaw Hold" and only one of them is this one.
	local function rowSaying(needle)
		local found = {}
		for _, f in ipairs(frames) do
			local left = type(f.left) == "table" and f.left.__text
			if f.__shown ~= false and type(left) == "string"
				and left:find(needle, 1, true) then
				found[#found + 1] = f
			end
		end
		return found
	end

	-- The switch is a toggle and something earlier in this file may have left it on, so it
	-- is driven until the panel is showing what this block is about rather than clicked
	-- once and hoped over. A check that depends on which order the file happens to run in
	-- is a check that will go red for the wrong reason one day.
	local function wholeFamilyShowing()
		return #rowSaying("Thorium Brotherhood") > 0
	end

	check("the whole family switch is offered on this section",
		clickButton("Whole family"))
	Family.UI:Refresh()

	if not wholeFamilyShowing() then
		clickButton("Whole family")
		Family.UI:Refresh()
	end

	-- A faction and its people, which is what this section became on 2026-09-05. It used to
	-- keep whoever had got furthest and say how many there were, and the question actually
	-- asked of it is *which of my characters*, because the next thing done with the answer
	-- is to go and log in on one of them.
	-- The rows **of one faction**, and not any row anywhere that says a name.
	--
	-- The first version of these asked whether some row on the panel mentioned "Repone",
	-- and Repone heads another faction two blocks down - so a mutation that drew only the
	-- furthest of each faction's people still passed. The block is the faction's own line
	-- and the lines under it, which are the ones with nothing in the left column; rows are
	-- taken from the pool in the order they are drawn, so walking forward is walking down
	-- the page.
	local function blockUnder(head)
		local page = frames
		local out, at = {}, nil
		for index, f in ipairs(page) do
			if f == head then
				at = index
				break
			end
		end
		if not at then return out end

		-- Anything that is not one of this panel's rows is stepped over rather than read as
		-- the end of the block: other panels put frames in between.
		for index = at + 1, #page do
			local f = page[index]
			if type(f.left) == "table" and type(f.middle) == "table"
				and type(f.right) == "table" then
				local left = f.left.__text
				if f.__shown == false or type(left) ~= "string" or left ~= "" then
					break
				end
				out[#out + 1] = f
			end
		end
		return out
	end

	local function saidUnder(head, needle)
		for _, f in ipairs(blockUnder(head)) do
			local middle = type(f.middle) == "table" and f.middle.__text
			if type(middle) == "string" and middle:find(needle, 1, true) then return f end
		end
		return nil
	end

	local thorium = rowSaying("Thorium Brotherhood")
	check("a faction is named once however many of its people are under it",
		#thorium == 1, tostring(#thorium))

	-- The category heading counts what is under it, beside the heading and not in the
	-- right-hand column. That column is headed *Standing*, so a category of two read as a
	-- reputation of two - asked from play 2026-09-05 as *what is that 5?*, which is the
	-- clearest possible report that a number was in the wrong place.
	do
		local heading
		for _, f in ipairs(frames) do
			local left = type(f.left) == "table" and f.left.__text
			if f.__shown ~= false and type(left) == "string"
				and left:find("Steamwheedle", 1, true) then
				heading = f
			end
		end

		check("a category heading is drawn", heading ~= nil)
		check("with how many are under it, beside the name",
			heading and heading.left.__text:find("(1)", 1, true) ~= nil,
			heading and heading.left.__text)
		check("and nothing in the column that says what a standing is",
			heading and (heading.right.__text or "") == "",
			heading and heading.right.__text)
	end

	-- Furthest at the top, which is the one fact the old shape did keep.
	local head = thorium[1] and thorium[1].middle and thorium[1].middle.__text or ""
	check("with the one who has got furthest on its own line",
		head:find("Reptwo", 1, true) ~= nil, head)

	-- And the others under it. This is the change: the second name was deliberately absent
	-- before, because the panel kept a winner rather than a list.
	local behind = thorium[1] and saidUnder(thorium[1], "Repone")
	check("and everybody else who has met it listed under that", behind ~= nil)
	check("each with their own standing rather than the family's best",
		behind and (behind.right.__text or ""):find(standingWord(5), 1, true) ~= nil,
		behind and behind.right.__text)
	check("while the one at the top keeps theirs",
		thorium[1] and (thorium[1].right.__text or ""):find(standingWord(7), 1, true) ~= nil,
		thorium[1] and thorium[1].right.__text)

	-- Three, and then a way to see the rest. A faction a family of forty has all met is
	-- forty lines nobody scrolls past.
	check("only three of them are shown at once",
		thorium[1] and saidUnder(thorium[1], "Repfour") == nil)

	-- Matched through the client's own sentence rather than the English word in it: this
	-- addon is read in five languages and a needle typed in one of them finds nothing in
	-- the other four.
	-- Counted out of the fixture rather than written here. It said 1, and adding a fifth
	-- member to that faction turned this check red for a reason that had nothing to do with
	-- what it is about - a number in a check that the fixture decides belongs to the fixture.
	local onThorium = 0
	for _, member in ipairs(ours) do
		for _, entry in ipairs(member.reps) do
			if entry.id == 59 then onThorium = onThorium + 1 end
		end
	end

	local moreSaid = string.format(Family.L["|cff888888and %d more|r"], onThorium - 3)

	-- By what it carries rather than by where it sits, for the reason the fold-back row
	-- below carries: a row taken from a growing pool is last in `frames` the first time it
	-- is made, not beside the rows it was drawn with.
	local more
	for _, f in ipairs(frames) do
		local middle = type(f.middle) == "table" and f.middle.__text
		if f.__shown ~= false and f.expandFaction == "id:59"
			and type(middle) == "string" and middle:find(moreSaid, 1, true) then
			more = f
		end
	end
	check("and the rest are offered rather than dropped", more ~= nil,
		more and more.middle.__text)

	if more then
		more.__scripts.OnClick(more)

		thorium = rowSaying("Thorium Brotherhood")
		check("clicking that shows them",
			thorium[1] and saidUnder(thorium[1], "Repfour") ~= nil)

		-- Found by what it carries, not by where it sits.
		--
		-- Rows come from a pool that grows, so the row that folds a faction back is a row
		-- that was *just made* the first time a page needs it - and a new row is last in
		-- `frames`, not next to the ones it was drawn beside. Walking to it found three of
		-- four lines and called the fourth missing. It knows which faction it belongs to,
		-- so ask it.
		local fewer
		for _, f in ipairs(frames) do
			local middle = type(f.middle) == "table" and f.middle.__text
			if f.__shown ~= false and f.expandFaction == "id:59"
				and type(middle) == "string"
				and middle:find(Family.L["|cff888888fewer|r"], 1, true) then
				fewer = f
			end
		end
		check("and offers to fold them away again", fewer ~= nil)

		if fewer then
			fewer.__scripts.OnClick(fewer)
			thorium = rowSaying("Thorium Brotherhood")
			check("which puts it back to three",
				thorium[1] and saidUnder(thorium[1], "Repfour") == nil)
		end
	end

	-- And folded away by the window closing.
	--
	-- An unfold is a way of looking at the page in front of you, not a setting. Reported from
	-- play: a faction opened once was still open the next time the window was opened, so a
	-- page read as "these three and sixteen more" came back as twenty rows with nothing on
	-- screen to say why. The professions search had the same field and the same fault.
	do
		local wasOpen = thorium[1] and saidUnder(thorium[1], moreSaid)
		if wasOpen then wasOpen.__scripts.OnClick(wasOpen) end
		check("a faction can be left open", Family.UI.__openFaction ~= nil,
			tostring(Family.UI.__openFaction))

		Family.UI.__openCrafters = "something the professions panel had open"

		Family.UI:Hide()
		check("and the window being put away folds it back",
			Family.UI.__openFaction == nil, tostring(Family.UI.__openFaction))
		check("and does the same for the professions search, which had the same field",
			Family.UI.__openCrafters == nil, tostring(Family.UI.__openCrafters))

		-- Every panel that draws an unfold registers one, and none of them threw.
		--
		-- Three today: this one, the professions search, and the summary's letters and
		-- boon. A panel that never registered and one that registered and failed both end
		-- the same way - the page comes back with something still open and nothing says
		-- which - so the two are counted apart.
		--
		-- **What this does not pin** is that each folder clears the right thing. The two
		-- above do that for their own; the summary's holds file locals this file cannot
		-- reach, so the only way in is the rows they cause to be drawn. That was owed for
		-- a day and is paid: *the letters, put away with everything else* opens a member's
		-- post and their boon and counts the rows back down, and the mutation that clears
		-- only the letters is caught by the boon alone.
		local folded, failed = Family.UI:FoldEverything()
		check("every panel with something to fold has registered a way to fold it",
			folded >= 3, tostring(folded))
		check("and none of them threw on the way", failed == 0, tostring(failed))

		Family.UI:Show()

		-- And choosing again folds too, whether or not the choice changes: clicking the
		-- tab, section or profession you are already on is how somebody asks for the page
		-- back. Asked for from play, after the window half was reported.
		Family.UI.__openFaction = "id:59"
		Family.UI:ShowTab("character")
		check("and asking for the page you are already on folds it as well",
			Family.UI.__openFaction == nil, tostring(Family.UI.__openFaction))

		Family.UI:Refresh()
	end

	-- A faction only one of them has ever met is still that faction, and needs no fold.
	local zandalar = rowSaying("Zandalar Tribe")
	check("a faction only one member has is listed too", #zandalar == 1, tostring(#zandalar))
	check("with nothing offered to unfold, because there is nothing behind it",
		zandalar[1] and zandalar[1].expandFaction == nil)

	-- The filter box, and **not** the one the global happens to hold.
	--
	-- This panel is built twice in this file - a second time with Mists in force, so that
	-- the sections only that client has are drawn at all - and both builds name their box
	-- `FamilyCharacterSearch`, so the global is the second one while the panel on screen is
	-- the first. Typing into the wrong one filtered nothing and looked like a fault in the
	-- filtering. L-041 again, in a file that already carries the lesson.
	local searches = {}
	for _, f in ipairs(frames) do
		if f.__name == "FamilyCharacterSearch" then searches[#searches + 1] = f end
	end
	check("this panel still has its filter box", #searches > 0, tostring(#searches))

	if #searches > 0 then
		-- Typed into every box of that name, and the reason is not laziness. Neither build
		-- is hidden in a way this can see, so "which one is on screen" has no answer here -
		-- and picking one by creation order is the guess that made this look like a fault
		-- in the filtering rather than a fault in the reaching. Typing into both drives the
		-- one that matters and cannot drive the wrong one instead of it.
		--
		-- Its own handler rather than a refresh called from the side: what a player does is
		-- type, and the box is what decides that typing redraws anything.
		local function typeInto(text)
			for _, box in ipairs(searches) do
				box:SetText(text)
				if box.__scripts and box.__scripts.OnTextChanged then
					box.__scripts.OnTextChanged(box)
				end
			end
		end

		typeInto("timbermaw")
		check("a filter narrows the factions",
			#rowSaying("Timbermaw Hold") == 1 and #rowSaying("Thorium Brotherhood") == 0,
			#rowSaying("Timbermaw Hold") .. " timbermaw, "
				.. #rowSaying("Thorium Brotherhood") .. " thorium")

		typeInto("")
		check("and clearing it brings them back", #rowSaying("Thorium Brotherhood") == 1)
	end

	-- Back to one member, so nothing after this reads a panel showing everybody.
	clickButton("Whole family")
	Family.UI:Refresh()
	for _, member in ipairs(ours) do Family.Database:Forget(member.key) end
end)()

print()
print("a member's name, drawn the same way wherever this panel says it")

-- Two things asked for from play 2026-09-05 off one screenshot of the whole family's
-- reputations, and they turn out to be one thing.
--
-- **Colour the names by class.** Twenty names in one gold is a list nobody can pick a member
-- out of, and the summary has coloured its own for as long as it has had rows.
--
-- **The tooltip drops the realm.** The row said *Eccebombo (@Soulseeker)* and the tooltip
-- beside it said *Eccebombo*, because the row asked `UI:NameOf` and the fallback built
-- `held.name` by hand. L-052's shape: two readers of one fact, one right, and the wrong one
-- silent because a bare name looks like an answer.
--
-- A fixture of its own rather than more members in the block above. Rows come out of a pool
-- that grows, and one extra person in a faction that block counts makes the panel draw a row
-- it has never drawn - which is appended to `frames` rather than sitting with the rows it was
-- drawn beside, so the walk that reads a faction's block steps straight past it. Measured
-- twice: it turned *clicking that shows them* red while the panel drew the name perfectly.
-- Everything here finds its row by what the row says, never by walking a block.
;(function()
	-- White where no class was recorded, which is what makes the colour a reading of the
	-- record rather than a decoration. Checked before anything is drawn, because a panel
	-- that used the default everywhere would look exactly like one that used the class.
	local mage = Family.UI:ClassMarkup("MAGE")
	local none = Family.UI:ClassMarkup(nil)
	check("a class Family knows has a colour of its own", mage ~= none, mage)
	check("and one it does not is left white", none == "|cffffffff", none)

	local roster = {
		{ key = "Tinta-Fire Maw", name = "Tinta", realm = "Fire Maw", classFile = "MAGE" },
		-- Somewhere else, so the name has a realm to carry and the tooltip has something
		-- to lose.
		{ key = "Faraway-Thunderstrike", name = "Faraway", realm = "Thunderstrike",
			classFile = "MAGE" },
	}

	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = member.realm,
			level = 60, classFile = member.classFile, faction = "Alliance" })
		Family.Database:SetPayload(member.key, { reputations = {
			{ id = 909, name = "Colour Guard", category = "Other", standing = 5,
				value = 100, maximum = 1000 },
		} })
	end

	Family.UI:Show()
	Family.UI:ShowTab("character")
	clickButton("Reputations")
	Family.UI:Refresh()

	local function rowNaming(needle)
		for _, f in ipairs(frames) do
			local middle = type(f.middle) == "table" and f.middle.__text
			if f.__shown ~= false and type(middle) == "string"
				and middle:find(needle, 1, true) then
				return f
			end
		end
	end

	-- The whole family switch is a toggle and the block above leaves it wherever it left
	-- it, so it is driven until the panel is showing what this block is about. A check that
	-- depends on the order this file happens to run in goes red one day for the wrong
	-- reason - the block above says so about itself, in the same words.
	if not rowNaming("Faraway") then
		clickButton("Whole family")
		Family.UI:Refresh()
	end

	local here, away = rowNaming("Tinta"), rowNaming("Faraway")
	check("both of them are drawn on the faction", here ~= nil and away ~= nil)

	check("a name is painted in its class's colour",
		here and here.middle.__text:find(mage, 1, true) ~= nil,
		here and here.middle.__text)

	-- The settled realm rule, which the row already kept.
	check("and a character on another realm carries it",
		away and away.middle.__text:find("Thunderstrike", 1, true) ~= nil,
		away and away.middle.__text)
	check("while one on the realm being played does not",
		here and here.middle.__text:find("Fire Maw", 1, true) == nil,
		here and here.middle.__text)

	-- The half that was wrong. The client describes no faction row, so what a hover shows
	-- is the row's own lines - and those were being built from the bare name.
	if away then
		GameTooltip.__shownAs = nil
		wipe(GameTooltip.__lines)
		away.__scripts.OnEnter(away)

		local said = ""
		for _, line in ipairs(GameTooltip.__lines) do
			said = said .. " " .. tostring(line[1]) .. " " .. tostring(line[2])
		end

		check("hovering the row says who it is about", said:find("Faraway", 1, true) ~= nil,
			said)
		check("with the realm the row itself carries, which it used to drop",
			said:find("Thunderstrike", 1, true) ~= nil, said)
		check("and the faction it is about", said:find("Colour Guard", 1, true) ~= nil, said)
	end

	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
	Family.UI:Refresh()
end)()

--------------------------------------------------------------------------------------------
-- The key binding
--
-- Bindings live in XML because the client reads them before any addon Lua runs, which means
-- nothing in this harness loads that file and nothing would ever notice it going wrong. What
-- can be checked is every join it has: the .toc lists it, its binding name and header match
-- the globals Slash.lua sets, and the Lua inside it runs and does what it says.
--
-- That last one matters most. The body of a binding is a string the client compiles on a key
-- press: a typo in it is a syntax error the player meets in the middle of whatever they were
-- doing, and nothing else in the addon would ever have compiled it.
--------------------------------------------------------------------------------------------

print()
print("opening Family from the keyboard")

;(function()
	local function slurp(path)
		local handle = io.open(ROOT .. "/" .. path)
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end

	local toc = slurp("addons/Family_UI/Family_UI.toc")
	check("the .toc is where this check expects it", toc ~= nil)
	-- **And does not list the bindings file.** The client finds it by name in the folder;
	-- naming it here as well hands it to the ordinary UI XML loader, which has never heard
	-- of a Binding element and says so on every login. Burning Crusade reported it, Classic
	-- Era swallowed it, and it shipped because nothing here asked.
	check("and does not list the bindings file, which the client finds by name",
		toc ~= nil and toc:find("%f[%w]Bindings%.xml%f[^%w]") == nil)

	local xml = slurp("addons/Family_UI/Bindings.xml")
	check("which is in the addon folder", xml ~= nil)

	local name = xml and xml:match('<Binding%s+name="([%w_]+)"')

	-- **The name of a global, read as one.** The first version of this check took a `header`
	-- attribute and built `BINDING_HEADER_` .. it, which is a name this file invented: the
	-- client reads `Category` and looks up whatever global it names. Written from an
	-- assumption, the check was green while the game put the binding in "Other" with a row
	-- called HEADER_FAMILY beside an unbound key - the same shape as L-047, the same day.
	-- Anchored on the element, not on the word. Matched loose, this found
	-- `Category="BINDING_HEADER_WEAKAURAS"` inside this file's own comment - the example it
	-- cites - and then reported that a global by that name was missing. Third time in a day
	-- that a check greping for a token found the sentence explaining the token; a check that
	-- reads a file has to anchor on that file's structure.
	local category = xml and xml:match('<Binding%s[^>]-Category="([%w_]+)"')
	check("declaring a binding and the global that names its section",
		name ~= nil and category ~= nil,
		tostring(name) .. " / " .. tostring(category))
	check("and no `header` attribute, which this client does not understand",
		xml ~= nil and xml:match('<Binding[^>]-%sheader="') == nil)

	-- The window looks these two up by name. A rename on either side is silent: what the
	-- player sees is the raw action name, which is also what an unlocalised binding looks
	-- like, so the two faults are indistinguishable on screen.
	check("the client is given a word for the binding",
		type(_G["BINDING_NAME_" .. tostring(name)]) == "string"
			and _G["BINDING_NAME_" .. tostring(name)] ~= "",
		tostring(_G["BINDING_NAME_" .. tostring(name)]))
	check("and for the heading it sits under",
		type(_G[tostring(category)]) == "string" and _G[tostring(category)] ~= "",
		tostring(_G[tostring(category)]))
	check("which is named BINDING_HEADER_something, as the client expects",
		category ~= nil and category:find("^BINDING_HEADER_") ~= nil, tostring(category))

	-- And a word, not the action name shown back at the player: BINDING_NAME_FAMILY_TOGGLE
	-- reading "FAMILY_TOGGLE" is what a missing global looks like.
	check("a word rather than the action's own name",
		_G["BINDING_NAME_" .. tostring(name)] ~= name)

	--------------------------------------------------------------------------------------
	-- What the key actually does
	--------------------------------------------------------------------------------------

	-- `%s` after the tag name on purpose: without it this matches the `<Bindings>` wrapper
	-- too, because "Bindings" begins with "Binding", and the body then starts with the
	-- opening tag of the binding itself and will not compile.
	local body = xml and xml:match("<Binding%s[^>]*>(.-)</Binding>")
	check("the binding has something to run", body ~= nil and body:match("%S") ~= nil)

	local chunk, err = loadstring(body or "")
	check("and it compiles, which nothing else in the addon would ever try",
		chunk ~= nil, tostring(err))

	if chunk then
		Family.UI:Hide()
		local before = Family.UI:IsShown()
		chunk()
		check("pressing the key opens Family", Family.UI:IsShown() ~= before)
		chunk()
		check("and pressing it again closes it", Family.UI:IsShown() == before)
	end

	-- Guarded, because a key can be pressed while the player is still zoning in and before
	-- Family_UI has finished loading. An error thrown from a binding lands on whatever they
	-- were doing at the time.
	if chunk then
		local realFamily = _G.Family
		_G.Family = nil
		local ok = pcall(chunk)
		_G.Family = realFamily
		check("and pressing it before Family has loaded does nothing at all", ok)
	end
end)()

--------------------------------------------------------------------------------------------
-- A letter whose attachments are not in the first slots
--
-- `itemCount` from the header says how many a letter has and nothing about where they sit.
-- They have gaps, and some of them are past that number - so a loop bounded by the count
-- reads part of a letter and the record looks complete, which is how four stacks of linen and
-- two of wool went missing without anything saying so. Measured in play by walking the slots
-- and printing the ones that answer nothing (L-044).
--------------------------------------------------------------------------------------------

print()
print("a letter that keeps its attachments in odd slots")

;(function()
	local key = Family:CurrentMember()

	INBOX[#INBOX + 1] = {
		sender = "Wetpaper", subject = "Wool Cloth (20)", money = 0, cod = 0, days = 19,
		-- Six attachments; the client reports six; they sit in ten slots with gaps, and two
		-- of them are past the sixth. Read the way this used to be read, three are lost.
		count = 6,
		items = { [1] = { 2592, 20 }, [3] = { 2592, 20 }, [4] = { 2592, 20 },
		          [8] = { 2592, 20 }, [9] = { 2592, 20 }, [10] = { 2592, 20 } },
	}
	local at = #INBOX

	local mark = #DEFAULT_CHAT_FRAME.messages
	local wasDebug = FamilyDB.debug
	FamilyDB.debug = true

	fire("MAIL_SHOW")
	advance(1)

	local letters = (Family.Database:Payload(key) or {}).mail
	letters = letters and letters.letters or {}

	local found
	for _, letter in ipairs(letters) do
		if letter.subject == "Wool Cloth (20)" then found = letter end
	end
	check("the letter is recorded", found ~= nil)

	check("with every attachment, including the ones past the count",
		found and #found.attachments == 6, tostring(found and #found.attachments))

	-- The gaps must not become entries: an empty slot is not an attachment of one.
	local counted = 0
	for _, carried in ipairs(found and found.attachments or {}) do
		if carried.id == 2592 and carried.count == 20 then counted = counted + 1 end
	end
	check("and nothing invented for the slots that answered nothing", counted == 6,
		tostring(counted))

	check("what the letter said it had is kept beside what was found",
		found and found.attachmentsExpected == 6,
		tostring(found and found.attachmentsExpected))

	-- Agreeing is the ordinary case, so it says nothing.
	local said = 0
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("attachment(s) and", 1, true) then
			said = said + 1
		end
	end
	check("and a letter that adds up is not remarked on", said == 0, tostring(said))

	-- And one that does not add up says so, rather than looking complete.
	INBOX[at].count = 9
	mark = #DEFAULT_CHAT_FRAME.messages
	fire("MAIL_SHOW")
	advance(1)

	local complained = false
	for index = mark + 1, #DEFAULT_CHAT_FRAME.messages do
		if DEFAULT_CHAT_FRAME.messages[index]:find("says 9 attachment(s) and 6 answered",
			1, true) then complained = true end
	end
	check("a letter that says nine and answers six says so", complained)

	INBOX[at] = nil
	FamilyDB.debug = wasDebug
	fire("MAIL_SHOW")
	advance(1)

	--------------------------------------------------------------------------------------
	-- And the same on the way out
	--
	-- A player fills slots 2 and 8 of an outgoing letter and leaves the rest empty; a
	-- player also opens a letter, takes two of its attachments and puts it back. Neither
	-- side may assume the slots are filled, or filled in order. The send path already
	-- walked every slot - it was written that way and never checked, which is a property
	-- one refactor away from being lost.
	--------------------------------------------------------------------------------------

	local wasItems = SEND_MAIL.items
	SEND_MAIL.items = { [2] = { 2589, 20 }, [8] = { 4306, 5 } }

	local recipient = "Gappy-Fire Maw"
	Family.Database:SetMeta(recipient, { name = "Gappy", realm = "Fire Maw" })

	SendMail("Gappy", "Two of eight", "")
	fire("MAIL_SEND_SUCCESS")

	local posted = (Family.Database:Payload(recipient) or {}).mail
	local sent = posted and posted.letters and posted.letters[1]
	check("a letter posted with only slots 2 and 8 filled carries both",
		sent and #sent.attachments == 2, tostring(sent and #sent.attachments))
	check("and neither of them is an empty slot read as one",
		sent and sent.attachments[1].id == 2589 and sent.attachments[2].id == 4306,
		sent and sent.attachments[1].id .. "/" .. sent.attachments[2].id)

	SEND_MAIL.items = wasItems
	Family.Database:Forget(recipient)
end)()

--------------------------------------------------------------------------------------------
-- A skill that is an ability
--
-- Lockpicking has a rank and a maximum, cannot be unlearned, is not one of the three
-- secondaries and has no window to have opened - so every test the scanner had said it was
-- not worth recording, and it was not recorded. The client's own SkillLine table says what it
-- is: skill line 633, category 7, which is neither the professions category nor the secondary
-- one. Present on Classic Era and Burning Crusade and absent from Mists, where the skill was
-- taken out of the game.
--------------------------------------------------------------------------------------------

print()
print("lockpicking, which is a skill and not a profession")

;(function()
	check("the table knows the skill line by id",
		Family.SkillLines[633] ~= nil)
	check("and files it as neither a primary nor a secondary profession",
		Family.SkillLines[633] and Family.SkillLines[633].class == true
			and Family.SkillLines[633].primary == false)
	check("with the client's word for it in every language this table carries", (function()
		local names = Family.SkillLines[633] and Family.SkillLines[633].names or {}
		for _, locale in ipairs { "enUS", "deDE", "frFR", "esES", "ruRU" } do
			if not (names[locale] and names[locale][1]) then return false end
		end
		return true
	end)())

	-- Not abandonable, not a secondary, no window: the shape that used to be skipped.
	SKILL_LINES[#SKILL_LINES + 1] =
		{ name = "Lockpicking", rank = 285, maxRank = 300, abandonable = false }

	local key = Family:CurrentMember()
	fire("SKILL_LINES_CHANGED")
	advance(1)

	local meta = Family.Database:Meta(key) or {}
	local held = (meta.skills or {})[633]
	check("a rogue's lockpicking is recorded at all", held ~= nil)
	check("under its skill line id rather than under a word",
		held ~= nil and (meta.skills or {})["Lockpicking"] == nil)
	check("with the rank the client reported",
		held and held.rank == 285 and held.maxRank == 300,
		held and (held.rank .. "/" .. held.maxRank))
	check("and marked as the ability it is", held and held.class == true)

	-- And not as a secondary profession, which is a separate claim in the same record.
	-- Every panel is guarded by `class`, so this one being wrong is invisible on screen
	-- and would still be a rogue with three secondaries to anything that counts them.
	check("and not as a secondary profession, which it is also not",
		held and held.secondary == false, tostring(held and held.secondary))

	-- Neither list on the summary. Filed as a secondary it would be a third secondary
	-- profession for every rogue, one they cannot train, abandon or choose.
	-- A member of this block's own. The character the scanner writes to was forgotten a long
	-- way further up this file, so anything asking "is it drawn" about them was asking about
	-- a row that is not there - a check that cannot fail, and three of them were written
	-- here before this was noticed.
	Family.Database:SetMeta("Picker-Fire Maw", {
		name = "Picker", realm = "Fire Maw", level = 60, classFile = "ROGUE",
		faction = "Alliance",
		skills = {
			[164] = { rank = 300, maxRank = 300, name = "Blacksmithing", secondary = false },
			[633] = { rank = 285, maxRank = 300, name = "Lockpicking", secondary = false,
				class = true },
		},
	})

	-- **The professions panel is deliberately not asserted on here.** Two checks were written
	-- against it - that a profession with no recipe list is named, and that lockpicking is
	-- not - and both passed on text belonging to another window until `visibleText` learned
	-- to walk a font string's whole parent chain, at which point neither could be made to
	-- pass at all: pointing the panel's member picker at a member built in this block does
	-- not put that member's professions on screen, and finding out why is its own piece of
	-- work rather than a line in a lockpicking check.
	--
	-- What holds the property up is the record - `class` true and `secondary` false, both
	-- checked above and both caught by mutation - and the two guards that read them. Writing
	-- that down beats keeping two checks that cannot fail.

	-- It belongs with the things this member can do. Every member picker is pointed at the
	-- rogue first, for the reason the reputation checks type into every search box: several
	-- panels have one and picking by creation order points at whichever was built first.
	Family.UI:Show()
	for _, f in ipairs(frames) do
		if f.Select and f.Reconcile then
			f:Select({ key = "Picker-Fire Maw",
				meta = Family.Database:Meta("Picker-Fire Maw") })
		end
	end

	Family.UI:ShowTab("talents")
	clickButton("Spellbook")
	Family.UI:Refresh()
	check("it is on the abilities panel, with its rank", drawnText("Lockpicking"))
	check("and the rank is the one recorded", drawnText("285"))

	Family.Database:Forget("Picker-Fire Maw")
	SKILL_LINES[#SKILL_LINES] = nil
	fire("SKILL_LINES_CHANGED")
	advance(1)
end)()

--------------------------------------------------------------------------------------------
-- One clock
--
-- The harness freezes `time` so that a check about "three days from now" means the same thing
-- every run. Reaching past it to the world's clock puts one side of a comparison on one
-- moves and the other on a clock that does not, and the check then holds until a date and not
-- one minute longer: the mail send check was written against a letter dated thirty days after
-- the frozen epoch and went red at 2026-09-05 07:06:40, on a day nothing had changed (L-045).
--
-- Checked by reading this file, which is the only thing that can: a clock fault is invisible
-- until the day it is not.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- What "on screen" means here
--
-- `visibleText` used to ask whether a font string's *immediate* parent was shown, which is no
-- question at all: the text on a panel sits on a row, the row sits in a list, and the frame
-- that gets hidden when you change tab is four levels above that. So a word on any panel ever
-- built answered for a word on the panel in front of you.
--
-- It cost three checks in one day and one of them was wrong for a month: the summary writes
-- "Auction House" as a letter's sender and a check asked for "Auctioneer", which passed
-- because the development icon sheet says that word somewhere. Both helpers now walk the whole
-- chain, and this pins that rather than trusting it - a visibility rule is exactly the kind of
-- thing that quietly loosens.
--------------------------------------------------------------------------------------------

print()
print("a panel that is not on screen says nothing")

;(function()
	local hidden = CreateFrame("Frame", nil, UIParent)
	local row = CreateFrame("Frame", nil, hidden)
	row.left = row:CreateFontString()
	row.left:SetText("Quarrelsome Zephyr")

	hidden:Hide()
	check("text under a hidden ancestor is not drawn text",
		drawnText("Quarrelsome Zephyr") == false)
	check("and is not visible text either",
		visibleText("Quarrelsome Zephyr") == false)

	hidden:Show()
	check("and the same text is both once its window is open",
		drawnText("Quarrelsome Zephyr") and visibleText("Quarrelsome Zephyr"))

	-- The row between them is shown throughout: what changed is four levels up, which is
	-- exactly the distance the old rule could not see.
	check("with the row itself shown the whole time", row.__shown ~= false)

	hidden:Hide()
end)()

print()
print("the harness lives on one clock")

;(function()
	local handle = io.open(ROOT .. "/tests/Harness.lua")
	check("this file can read itself", handle ~= nil)

	if handle then
		local text = handle:read("*a")
		handle:close()

		-- Its own mention of the name, in the sentence above and in this check, is the one
		-- thing that is not a use of it - so the pattern requires the call.
		local uses = 0
		for _ in text:gmatch("os%.time%s*%(") do uses = uses + 1 end

		check("and never asks the world what time it is", uses == 0, tostring(uses))
	end
end)()

--------------------------------------------------------------------------------------------
-- Reading the summary in an order of your own
--------------------------------------------------------------------------------------------

print()
print("the summary sorted by a column somebody chose")

;(function()
	local realm = GetRealmName()
	local roster = {
		{ key = "Rich-" .. realm,  name = "Rich",  level = 60, money = 9000000 },
		{ key = "Broke-" .. realm, name = "Broke", level = 60, money = 12 },
		{ key = "Never-" .. realm, name = "Never", level = 60 },
	}
	for _, member in ipairs(roster) do
		Family.Database:SetMeta(member.key, { name = member.name, realm = realm,
			level = member.level, classFile = "MAGE", faction = "Alliance",
			money = member.money })
	end

	-- One of them with a transmute running, because the crafting set builds its columns out
	-- of the cooldowns the family actually has: with nobody waiting on anything it draws the
	-- member column and nothing else, and a check about a column built at draw time would
	-- have had no column to ask about.
	Family.Database:SetMeta(roster[1].key, {
		skills = { [171] = { rank = 300, maxRank = 300, name = "Alchemy" } },
		craftCooldowns = { { profession = 171, readyAt = time() + 3600 } },
	})

	Family.UI:Show()
	Family.UI:ShowTab("summary")
	clickButton("Overview")
	Family.UI:Refresh()

	-- The order the rows are actually drawn in, read off the panel rather than out of the
	-- comparator: what is being checked is that somebody's choice reached the table.
	local function order()
		local seen = {}
		for _, f in ipairs(frames) do
			if onScreen(f) and type(f.memberKey) == "string" and f.__points then
				local point = f.__points.TOPLEFT
				local y = type(point) == "table" and point.y or 0
				seen[#seen + 1] = { key = f.memberKey, y = y }
			end
		end
		table.sort(seen, function(a, b) return (a.y or 0) > (b.y or 0) end)

		local names = {}
		for _, row in ipairs(seen) do names[#names + 1] = row.key end
		return names
	end

	local function positionOf(name, list)
		for index, key in ipairs(list) do
			if key:find(name, 1, true) then return index end
		end
	end

	check("nothing is chosen to begin with", Family.UI:SummarySort("overview") == nil)

	-- Money ascending: the poorest first, and the one nobody has logged in on last - not
	-- first, which is where a nought would put them.
	Family.UI:SetSummarySort("overview", "money")
	Family.UI:Refresh()

	local up = order()
	check("choosing a column puts the table in its order",
		positionOf("Broke", up) < positionOf("Rich", up),
		table.concat(up, ", "))
	check("and a member whose money was never read is last, not poorest",
		positionOf("Never", up) > positionOf("Rich", up), table.concat(up, ", "))

	-- The same column again turns it round, and the unread member stays last.
	Family.UI:SetSummarySort("overview", "money")
	Family.UI:Refresh()

	local down = order()
	check("choosing it again turns the order round",
		positionOf("Rich", down) < positionOf("Broke", down), table.concat(down, ", "))
	check("and the one never read is still last, both ways",
		positionOf("Never", down) > positionOf("Broke", down), table.concat(down, ", "))

	-- And a third time puts the panel back to its own order, which is the way back for
	-- somebody who does not know what the default was.
	Family.UI:SetSummarySort("overview", "money")
	check("and a third time gives the panel back its own order",
		Family.UI:SummarySort("overview") == nil)

	-- Per set: an order that makes sense of Activity means nothing on Miscellaneous.
	Family.UI:SetSummarySort("overview", "money")
	check("the order is remembered per column set",
		Family.UI:SummarySort("overview") ~= nil
			and Family.UI:SummarySort("misc") == nil)

	-- Remembered, unlike the filters: an order hides nothing, so a panel opened tomorrow in
	-- it does not look broken.
	check("and it is written down rather than held for this session",
		FamilyDB.ui.sort and FamilyDB.ui.sort.overview
			and FamilyDB.ui.sort.overview.key == "money")

	-- A column made of nothing sortable cannot be chosen, and asking is how a heading knows
	-- whether to offer a button at all.
	check("a column with no value behind it is not sortable",
		Family.UI:SummarySortable("") ~= true
			and Family.UI:SummarySortable("no such column") ~= true)
	check("and one that is, is", Family.UI:SummarySortable("money") == true)
	check("the professions column is sortable, by the word it shows",
		Family.UI:SummarySortable("prof1") == true)

	-- The auction figures come out of the payload rather than out of meta, and they carry
	-- the same distinction the cells do: read and holding none is a nought, never read is no
	-- answer at all. Sorted as a nought, the member nobody has logged in on heads an
	-- ascending column and reads as the one with nothing on the auction house.
	--
	-- Named to start with an A on purpose. Ties fall back to the panel's own order, which
	-- ends in the name, so a member called Never would sort after Broke whether the absence
	-- was honoured or not and the check would pass either way.
	Family.Database:SetMeta("Aaa-" .. realm, { name = "Aaa", realm = realm, level = 60,
		classFile = "MAGE", faction = "Alliance" })
	Family.Database:SetMeta(roster[1].key, { auctionsSeen = time() })
	Family.Database:SetMeta(roster[2].key, { auctionsSeen = time() })

	Family.UI:SetSummarySort("overview", nil)
	clickButton("Activity")
	Family.UI:SetSummarySort("activity", "auctions")
	Family.UI:Refresh()

	local byAuction = order()
	check("a member whose auction house was never read sorts last",
		positionOf("Aaa", byAuction) > positionOf("Broke", byAuction),
		table.concat(byAuction, ", "))

	Family.UI:SetSummarySort("activity", nil)
	Family.Database:Forget("Aaa-" .. realm)
	clickButton("Overview")
	Family.UI:Refresh()
	check("the professions column is sortable, by the word it shows",
		Family.UI:SummarySortable("prof1") == true)

	-- The auction figures come out of the payload rather than out of meta, and they carry
	-- the same distinction the cells do: read and holding none is a nought, never read is no
	-- answer. Sorted as a nought, the member nobody has logged in on heads an ascending
	-- column and reads as the one with nothing on the auction house.
	Family.Database:SetMeta("Aaa-" .. realm, { name = "Aaa", realm = realm, level = 60,
		classFile = "MAGE", faction = "Alliance" })
	Family.Database:SetMeta(roster[1].key, { auctionsSeen = time() })
	Family.Database:SetMeta(roster[2].key, { auctionsSeen = time() })

	Family.UI:SetSummarySort("overview", nil)
	clickButton("Activity")
	Family.UI:SetSummarySort("activity", "auctions")
	Family.UI:Refresh()

	local byAuction = order()
	check("a member whose auction house was never read sorts last",
		positionOf("Aaa", byAuction) > positionOf("Broke", byAuction),
		table.concat(byAuction, ", "))

	Family.UI:SetSummarySort("activity", nil)
	Family.Database:Forget("Aaa-" .. realm)
	clickButton("Overview")
	Family.UI:Refresh()

	-- The ones built while the panel is drawn bring their own value with them, beside the
	-- cell that draws them: a column that exists only at draw time would otherwise be the
	-- one kind that cannot be ordered, and "who can make this soonest" is the question the
	-- crafting set exists for.
	clickButton("Crafting")
	Family.UI:Refresh()

	local built = 0
	for _, column in ipairs(Family.UI.__summaryColumns or {}) do
		if type(column.key) == "string" and column.key:find("^cd:")
			and Family.UI:SummarySortable(column.key) then
			built = built + 1
		end
	end
	check("a column built while the panel draws is sortable too", built > 0,
		tostring(built))

	clickButton("Overview")
	Family.UI:Refresh()

	-- Race and class sort by what the cell draws, which is this client's word for them.
	check("race is sortable, by the word the reader sees",
		Family.UI:SummarySortable("race") == true)

	Family.UI:SetSummarySort("overview", nil)
	for _, member in ipairs(roster) do Family.Database:Forget(member.key) end
	Family.UI:Refresh()
end)()

--------------------------------------------------------------------------------------------
-- The harness loads what the game loads
--
-- This file keeps its own list of the addon's files, because it loads them by hand in an
-- order it controls. The client reads a `.toc`. Nothing joined the two, so a file added to
-- the addon was simply absent from every check here until somebody noticed - which is how a
-- widget added on 2026-09-05 produced "attempt to call a nil value" from a panel that had
-- worked perfectly in the game.
--
-- The other direction matters as much: a file left in this list after being removed from the
-- `.toc` would be tested and never shipped.
--------------------------------------------------------------------------------------------

print()
print("the harness loads the same files the client does")

;(function()
	local function slurp(path)
		local handle = io.open(ROOT .. "/" .. path)
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end

	local function listed(toc)
		local text = slurp(toc) or ""
		local files = {}
		for line in text:gmatch("[^\r\n]+") do
			local file = line:match("^%s*([%w_\\/]+%.lua)%s*$")
			-- The libraries are fetched at package time and are absent from a clone, which
			-- is deliberate and is checked elsewhere.
			if file and not file:find("^Libs") then
				files[file:gsub("\\", "/")] = true
			end
		end
		return files
	end

	local function compare(name, toc, loaded)
		local wanted = listed(toc)
		check(name .. " lists files this check can read", next(wanted) ~= nil)

		local missing, extra = {}, {}
		local have = {}
		for _, file in ipairs(loaded) do have[file] = true end

		for file in pairs(wanted) do
			if not have[file] then missing[#missing + 1] = file end
		end
		for file in pairs(have) do
			if not wanted[file] then extra[#extra + 1] = file end
		end

		table.sort(missing)
		table.sort(extra)

		check("everything " .. name .. " loads is loaded here too", #missing == 0,
			table.concat(missing, ", "))
		check("and nothing is loaded here that " .. name .. " does not ship", #extra == 0,
			table.concat(extra, ", "))
	end

	compare("Family_UI.toc", "addons/Family_UI/Family_UI.toc", UI_FILES)
end)()

--------------------------------------------------------------------------------------------
-- One filter bar, used by every panel that narrows a list of characters
--------------------------------------------------------------------------------------------

print()
print("narrowing a list of characters")

;(function()
	local realm = GetRealmName()

	-- A member on a second realm, because the pickers offer only what the family has and
	-- `Reconcile` drops a choice nobody is on - which is right, and which made the first
	-- draft of these checks pass by filtering on nothing at all.
	Family.Database:SetMeta("Awarrior-Pyrewood Village", { name = "Awarrior",
		realm = "Pyrewood Village", classFile = "WARRIOR", level = 24,
		faction = "Alliance" })

	local filters = Family.UI:CreateMemberFilters(UIParent, function() end)
	check("a panel can ask for a filter bar", type(filters) == "table")

	local mage = { name = "Amage", realm = realm, classFile = "MAGE", level = 60 }
	local warrior = { name = "Awarrior", realm = "Pyrewood Village",
		classFile = "WARRIOR", level = 24 }
	-- Everything about this one is unrecorded, which is the case §2.2 is about.
	local unknown = { name = "Aunknown" }

	check("with nothing chosen everybody passes",
		filters:Passes(mage) and filters:Passes(warrior) and filters:Passes(unknown))
	check("and it says it is not narrowing anything", filters:Active() == false)

	filters.classButton:Choose("MAGE")
	check("choosing a class keeps that class", filters:Passes(mage))
	check("and drops the others", filters:Passes(warrior) == false)
	check("while a record with no class recorded still passes", filters:Passes(unknown))
	check("and the bar says it is narrowing now", filters:Active() == true)

	filters.classButton:Choose(Family.UI.ANY)
	filters.realmButton:Choose("Pyrewood Village")
	check("choosing a realm keeps that realm", filters:Passes(warrior))
	check("and drops the others", filters:Passes(mage) == false)
	check("while a record with no realm recorded still passes", filters:Passes(unknown))

	filters.realmButton:Choose(Family.UI.ANY)
	filters.minBox:SetText("50")
	filters.maxBox:SetText("70")
	check("a level range keeps the members inside it", filters:Passes(mage))
	check("and drops the ones outside", filters:Passes(warrior) == false)
	check("while a record with no level recorded still passes", filters:Passes(unknown))

	filters:Reset()
	check("resetting puts everybody back",
		filters:Passes(mage) and filters:Passes(warrior) and filters:Active() == false)

	--------------------------------------------------------------------------------------
	-- And the panel that now has one
	--------------------------------------------------------------------------------------

	Family.UI:Show()
	Family.UI:ShowTab("professions")
	check("the professions panel offers the whole family",
		clickButton("Whole family"))

	local professionSearch
	for _, f in ipairs(frames) do
		if f.__name == "FamilyProfessionsSearch" then professionSearch = f end
	end
	check("and has a box to search it with", professionSearch ~= nil)

	if professionSearch then
		local function typeInto(text)
			professionSearch:SetText(text)
			if professionSearch.__scripts and professionSearch.__scripts.OnTextChanged then
				professionSearch.__scripts.OnTextChanged(professionSearch)
			end
		end

		typeInto("silver rod")
		check("a recipe somebody knows is found", drawnText("Silver Rod"))

		-- The crafter's name in the colour of their class, asked for from play
		-- 2026-09-05 of a search fifteen recipes long whose every name was one gold.
		-- `Recipes.lua` has carried `classFile` on these entries since they were
		-- written and nothing had ever read it.
		--
		-- The expected colour is worked out from the record rather than written here,
		-- so this says *their class's colour* and not *this particular blue*.
		do
			local wanted = Family.UI:ClassMarkup(
				(Family.Database:Meta(Family:CurrentMember()) or {}).classFile)

			local note
			for _, f in ipairs(frames) do
				local text = type(f.text) == "table" and f.text.__text
				if f.__shown ~= false and type(text) == "string"
					and text:find("Silver Rod", 1, true)
					and type(f.note) == "table" then
					note = f.note.__text
				end
			end

			check("with whoever can make it named beside it", note ~= nil
				and note ~= "", tostring(note))
			check("in the colour of their class",
				note and note:find(wanted, 1, true) ~= nil,
				tostring(note))
		end

		-- A class nobody with that recipe has. The recipe row is left with nobody who
		-- passes, and a row naming a recipe and nobody who can make it answers the
		-- opposite of the question it was asked - so it goes entirely.
		-- Chosen on every realm picker there is, for the reason the search boxes are typed
		-- into every box of their name: more than one panel has one, none of them is hidden
		-- in a way a check can see, and picking by creation order points at whichever panel
		-- was built first rather than the one in front of us.
		local pickers = 0
		local function chooseRealm(value)
			for _, f in ipairs(frames) do
				if f.prefix == Family.L["Realm"] and f.Choices then
					pickers = pickers + 1
					f:Choose(value)
				end
			end
			Family.UI:Refresh()
		end

		-- A realm that exists and that nobody with this recipe is on. A realm nobody is on
		-- at all would be dropped by `Reconcile` and would filter nothing, which is right
		-- and which the first draft of this check mistook for a fault.
		chooseRealm("Pyrewood Village")
		check("the whole-family reading has a realm filter on it", pickers > 0)
		check("and filtering to a realm the finder is not on empties the results",
			not drawnText("Silver Rod"))

		chooseRealm(Family.UI.ANY)
		check("while clearing it brings them back", drawnText("Silver Rod"))

		typeInto("")
		clickButton("Whole family")
		Family.UI:Refresh()
	end

	Family.Database:Forget("Awarrior-Pyrewood Village")
end)()

--------------------------------------------------------------------------------------------
-- The client complaining about Family's own whispers
--
-- Walking a linked family of six to find one online produces six lines of "No player named X
-- is currently playing". They are the client's, not Family's, which is why switching Family's
-- reporting off left every one of them on the screen - the complaint that produced this.
--------------------------------------------------------------------------------------------

print()
print("the client's complaints about whispers Family sent")

;(function()
	local swallow = Family.Comm.__swallowNotFound
	check("the filter is there to be asked", type(swallow) == "function")
	if type(swallow) ~= "function" then return end

	local function complaint(name)
		return _G.ERR_CHAT_PLAYER_NOT_FOUND_S:format(name)
	end

	-- Nobody has been whispered yet, so nothing of this is ours.
	check("a complaint about somebody Family never wrote to is left alone",
		swallow(nil, "CHAT_MSG_SYSTEM", complaint("Astranger")) == false)

	-- What a probe actually looks like: Family whispers **Name-Realm**, because that is what
	-- a linked family's members are keyed as, and the client complains about the bare name.
	--
	-- The first version of this check whispered "Absentee" and was answered about "Absentee",
	-- which is a shape no caller produces - and it passed while the filter, keyed on the
	-- whole address, found nothing and swallowed nothing. Reported from play as the noise
	-- still being there after the fix.
	Family.Comm:Send("hello", "x", "WHISPER", "Absentee-Thunderstrike", false)
	check("a complaint about one Family has just written to is taken off the screen",
		swallow(nil, "CHAT_MSG_SYSTEM", complaint("Absentee")) == true)
	check("and the realm it was addressed with is not what makes them different",
		swallow(nil, "CHAT_MSG_SYSTEM", complaint("Absentee-Thunderstrike")) == true)

	-- The same name, the player's own whisper, long after ours.
	local wasTime = time
	time = function() return wasTime() + 600 end
	check("and the same complaint later is left alone, because it is not ours",
		swallow(nil, "CHAT_MSG_SYSTEM", complaint("Absentee")) == false)
	time = wasTime

	-- Anything else the client says goes straight through. A filter that swallows more than
	-- it was written for is worse than the noise it was written for.
	check("and nothing else the client says is touched",
		swallow(nil, "CHAT_MSG_SYSTEM", "Your loot: a thing") == false)
	check("nor a message that is not a string at all",
		swallow(nil, "CHAT_MSG_SYSTEM", nil) == false)
end)()

print()
if failures == 0 then
	print("all checks passed")
else
	print(failures .. " CHECK(S) FAILED")
	os.exit(1)
end
