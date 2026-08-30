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

local fontMeta = {}
fontMeta.__index = function(_, key)
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
	Show = 1, Hide = 1, IsShown = 1, SetShown = 1, SetAlpha = 1,
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
	SetAutoFocus = 1, ClearFocus = 1, HighlightText = 1, SetMaxLetters = 1,
	SetNumeric = 1, SetFocus = 1,
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

function frameMethods:SetHyperlink(link)
	local kind, id = tostring(link):match("^(%a+):(%d+)")

	-- What was done to the item after it was bought. The stub used to stop at the id, so
	-- an item string and a bare id looked identical here - which is exactly the difference
	-- the gear tooltips turned out to be losing.
	local enchant = tonumber(tostring(link):match("^item:%d+:(%d+)"))
	if not TOOLTIP_KNOWS[kind] then
		-- A link type this client does not know says nothing, which is exactly the case
		-- the fallback lines exist for.
		return
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
function frameMethods:SetPoint(point, a, b, c, d)
	if type(point) ~= "string" then return end
	self.__points = self.__points or {}
	self.__points[point] = true

	self.__offsets = self.__offsets or {}
	if type(a) == "number" then
		self.__offsets[point] = { x = a, y = b }
	elseif type(c) == "number" then
		self.__offsets[point] = { x = c, y = d }
	end
end

function frameMethods:SetAllPoints()
	self.__points = { TOPLEFT = true, BOTTOMRIGHT = true }
end

function frameMethods:ClearAllPoints() self.__points = nil end

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
local BAGS = {
	[0] = { size = 16, free = 14, bagType = 0,
	        items = { [1] = { 6948, 1 }, [2] = { 2589, 20 } } },
	[1] = { size = 16, free = 15, bagType = 0, items = { [5] = { 4306, 12 } } },
	[2] = { size = 16, free = 16, bagType = 1, items = {} },
	-- The keyring, whose container number is negative. Everything about it is a special
	-- case and it was never in this list, so none of those cases was ever exercised.
	[-2] = { size = 8, free = 6, bagType = 0, items = { [1] = { 5178, 1 } } },
}

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
local SEND_MAIL = { money = 12000, cod = 0, items = { { 2589, 20 }, { 4306, 5 } } }
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
	[2661] = "Copper Chain Belt", [3339] = "Silver Rod",
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
	return quest.title, quest.level, 0, false, false, nil, 0, quest.id
end

-- The id comes from a call that says it is one, not from a guess at which number in the
-- list above happens to be it: quest ids start at 1 here, so by size alone one is
-- indistinguishable from a level.
GetQuestLink = function(index)
	local row = questRows()[index]
	if not (row and row.quest) then return nil end
	return string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", row.quest.id,
		row.quest.level, row.quest.title)
end

GetNumQuestLeaderBoards = function(index)
	local row = questRows()[index]
	return (row and row.quest and row.quest.objectives) or 0
end

GetQuestLogLeaderBoard = function(objective, index)
	local row = questRows()[index]
	if not (row and row.quest) then return nil end
	return "an objective", "monster", objective <= (row.quest.done or 0)
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
	local a = OWNED[index]
	if not a or which ~= "owner" then return nil end
	return a[1], nil, a[2], nil, nil, nil, nil, a[3], nil, a[4], a[5], a[6],
		nil, nil, nil, nil, 2840 + index
end
GetAuctionItemTimeLeft = function(_, index) return OWNED[index] and OWNED[index][7] or 0 end
GetOwnerAuctionItems = function() end

-- The mailbox. One letter is about to expire and one is not, because the only number on the
-- summary worth reacting to is how long until something is destroyed.
local INBOX = {
	{ sender = "Deiana", subject = "Cloth", money = 0, cod = 0, days = 0.5,
	  items = { { 2589, 20 } } },
	{ sender = "Auction House", subject = "Sold", money = 50000, cod = 0, days = 25,
	  items = {} },
}
GetInboxNumItems = function() return #INBOX end
GetInboxHeaderInfo = function(index)
	local m = INBOX[index]
	if not m then return nil end
	return nil, nil, m.sender, m.subject, m.money, m.cod, m.days, #m.items, true
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
local SKILL_LINES = {
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

local TRADE_RECIPES = {
	{ "Header", "header" },
	{ "Copper Chain Belt", "trivial", 0, "|cffffd000|Henchant:2661|h[Copper Chain Belt]|h|r",
	  "|cffffffff|Hitem:2864|h[Copper Chain Belt]|h|r" },
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
GetTradeSkillLine = function()
	return TRADE_SKILL_OPEN and "Blacksmithing" or "UNKNOWN"
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
GetTradeSkillCooldown = function() return nil end

-- The bank: container -1, plus one bought bank bag at 6. Bag 5 is deliberately absent.
-- The bank's own window answers 20 free while holding one thing in twenty-four slots, which
-- is what a live Classic Era client does: it computes that count from twenty-eight and the
-- bank is twenty-four, so it is four out whatever is in it. Family does not ask - it reads
-- every slot anyway, so free is the size less what was found - and this fixture is the client
-- being wrong about it.
local BANK_BAGS = {
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
C_Container.GetContainerItemCooldown = function(bag, slot)
	if bag == 0 and slot == 1 then return 900, 86400, 1 end
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

local ITEM_NAMES = { [6948] = "Hearthstone", [2589] = "Linen Cloth" }

-- Recipe items, and one deliberate impostor. Arcane dust is trade goods with a subclass
-- named after a profession, which is exactly why a subtype matching a profession cannot on
-- its own be taken for a recipe.
local RECIPE_ITEMS = {
	[2881] = { name = "Plans: Copper Chain Belt", profession = "Blacksmithing",
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

local function fire(event, ...)
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
	"SkillLines.lua", "Races.lua", "TalentSpells.lua",
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
local UI_FILES = { "Window.lua", "MemberPicker.lua", "ChoicePicker.lua", "Tooltip.lua",
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
	and bs.recipes[1].name == "Copper Chain Belt", bs.recipes and bs.recipes[1].name)
check("a recipe keeps the spell id from its link", bs.recipes
	and bs.recipes[1].spellID == 2661, bs.recipes and tostring(bs.recipes[1].spellID))
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
		GetAllRecipeIDs = function() return { 3304, 2661 } end,
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
		if recipe.spellID == 2661 then spellOnly = recipe end
	end

	check("a recipe id window is read at all", made ~= nil and spellOnly ~= nil)
	check("and the id of what each one makes is asked for separately",
		made and made.itemID == 3576, made and tostring(made.itemID) or "nothing")
	check("while one the client will not answer for keeps its spell and no more",
		spellOnly and spellOnly.spellID == 2661 and spellOnly.itemID == nil)

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
		return nil
	end
	GetGuildBankItemInfo = function() return "Linen Cloth", 20 end

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
-- give at once. Tester knows Copper Chain Belt already (it is in the recipes read from the
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
	recipes = { { name = "Copper Chain Belt", spellID = 2661 } } } } })

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
	RECIPE_ITEMS[7191] = { name = "Copper Chain Belt", profession = "Blacksmithing",
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
check("and the ones with nothing to be confused with are left alone", otherName == 0)

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
local function visibleText(needle)
	for _, f in ipairs(fontStrings) do
		-- A font string made on its own - a tooltip line, a frame's title - has no parent
		-- recorded, and asking a bare table for one gets the metatable's answer for
		-- anything it does not know, which is a function.
		local parent = type(f.__parent) == "table" and f.__parent or nil

		if type(f.__text) == "string" and f.__text:find(needle, 1, true)
			and f.__visible ~= false
			and (parent == nil or parent.__shown ~= false) then
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
check("and still chooses that profession in the panel", visibleText("Copper Chain Belt"))

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
	recipes = { { name = "Copper Chain Belt", difficulty = "medium" } } } } })
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
	Family.UI:SelectRecipe(key, "Blacksmithing", "Copper Chain Belt") == true
		and selectedRecipe ~= nil, tostring(selectedRecipe))

selectedRecipe = nil
check("a recipe of somebody else's selects nothing",
	Family.UI:SelectRecipe("Somebody-Else", "Blacksmithing", "Copper Chain Belt") == false)
check("and a profession whose window is shut selects nothing",
	Family.UI:SelectRecipe(key, "Tailoring", "Bolt of Linen Cloth") == false)

-- The window's own name is not checked against the profession's. The craft frame is titled
-- one thing and belongs to a skill line called another, so enchanting never matched itself -
-- and a member scanned on a French client has the profession under a different name again.
selectedRecipe = nil
check("a recipe is found in the open window whatever that window calls itself",
	Family.UI:SelectRecipe(key, "Forgeage", "Copper Chain Belt") == true
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
shownAs = hoverRow(function(f) return f.spellID == 2661 end)
check("hovering a recipe opens the tooltip for the spell it casts",
	shownAs and shownAs.kind == "spell", shownAs and shownAs.kind)

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
		visibleText("Copper Chain Belt"))
	-- Not "Runeforging", which the same recipe is also filed under here: where a recipe is
	-- held under both a real profession and one the client's table has never heard of, the
	-- identified one is the label.
	check("with the profession it belongs to", visibleText("Blacksmithing"))
	check("and everybody who can make it", visibleText("Tester"))

	_G.FamilyProfessionsSearch:SetText("")
	professionsEveryone.__scripts.OnClick(professionsEveryone)
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

-- The bar and the tooltip are two views of one sum and must not be able to disagree. The
-- bar was written once at login and never again, so a player who had spent two gold since
-- read one total on their screen and a different one in the tooltip above it - and the
-- tooltip, which is rebuilt on every hover, was the right one.
do
	-- LibDataBroker is a .pkgmeta external and is not in a clone, so there is no bar object
	-- here unless one is made. It is one field, and the whole of what the library gives us.
	Family.UI.broker = Family.UI.broker or { text = "" }

	local before = Family.UI.broker.text
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
		professions = { [164] = { recipes = { { name = "Copper Chain Belt" } } } },
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
		letter and letter.expiresBy and letter.expiresBy > os.time())

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
				seen = os.time(),
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
	local function buttonSaying(label)
		for _, f in ipairs(frames) do
			if f.__shown == true and type(f.__text) == "string"
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

	check("the classes are a list too",
		clickButton("Class: all") and chooseFromList("Mage"))
	check("named as the client names them",
		buttonSaying("Class: Mage") or buttonSaying("Class: MAGE"))

	-- Every list offers everything again, at the top, whatever is currently chosen.
	check("and everything is always back on offer",
		clickButton("Realm: Fire Maw") and chooseFromList("all|r"))
	check("which clears the filter", buttonSaying("Realm: all"))

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
		Family.Database:SetMeta("Oldtimer-FireMaw", { name = "Oldtimer", realm = "Fire Maw",
			guild = guildName, classFile = "DRUID", level = 60, skills = {
				["Herbalism"] = { rank = 300, maxRank = 300, name = "Herbalism" },
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
				{ name = "Copper Chain Belt", spellID = 2661, itemID = 2864 },
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
			spells and spells[1] == 2661 and spells[2] == 3339 and spells[3] == 7421)
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
			spells = { 2661, 678 }, items = { 2864, 0 },
			missing = 4, fingerprint = 4242,
		}, "WHISPER", "Tester")
		advance(3)
		deliver("Faraway")

		local theirList = Family.Guild:HeldRecipes(guildKey, "Faraway-FireMaw", smith)
		check("and what comes back is stored", theirList ~= nil)
		check("with the gaps read back as the ids they were",
			theirList and theirList.spells[1] == 2661 and theirList.spells[2] == 3339,
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
				spells = { 2661, 678 }, items = { 60001, 0 },
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
				.recipes[1].spellID = 2661

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
		local herbs = Family:SkillLineFor("Herbalism")
		Family.Guild:SetShare(guildKey, "Oldtimer-FireMaw", herbs, true)
		Family.UI:Refresh()

		-- Found by being ticked, not by the word on it. Another member of this fixture has
		-- Herbalism too, keyed by an id, and a needle that matched the word alone found
		-- their box and passed whatever this panel did to Oldtimer's.
		local older
		for _, f in ipairs(fontStrings) do
			local parent = type(f.__parent) == "table" and f.__parent or nil
			if type(f.__text) == "string" and f.__text:find("Herbalism", 1, true)
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
				[herbs] = { rank = 275, maxRank = 300, name = "Herbalism" },
				["Herbalism"] = { rank = 275, maxRank = 300, name = "Herbalism" },
			} })
		Family.Guild:SetShare(guildKey, "Twice-FireMaw", herbs, true)

		local twice = (Family.Guild:Offering() or {})["Twice-FireMaw"].professions
		check("and one held under both an id and a word crosses once, not twice",
			twice and #twice == 1, twice and tostring(#twice) or "nothing")

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
	check("naming who each one is from", visibleText("Auctioneer"))

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
		Blacksmithing = { recipes = { { name = "Copper Chain Belt" } } },
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
	Family.Database:SetMeta(key, {
		name = "Alchemist", realm = "Fire Maw", level = 70, faction = "Horde",
		craftCooldowns = {
			{ name = "Transmute: Arcanite", profession = "Alchemy", readyAt = time() + 3600 },
			{ name = "Transmute: Earth to Water", profession = "Alchemy",
				readyAt = time() + 3600 },
			{ name = "Transmute: Air to Fire", profession = "Alchemy",
				readyAt = time() + 3600 },
			{ name = "Bolt of Imbued Netherweave", profession = "Tailoring" },
		},
		itemCooldowns = { { id = 30046, readyAt = time() + 7200 } },
		cooldownItems = { [30046] = "Leatherworking" },
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
		if kind.item == 30046 then shaker = kind end
	end
	check("an item on cooldown is one of these too", shaker ~= nil)
	check("and it answers to the profession that makes it",
		shaker and shaker.profession == "Leatherworking",
		shaker and tostring(shaker.profession))

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
	check("and what is not says when it comes back", visibleText("1h"))
	check("with the shared one under the profession's name", visibleText("Alchemy"))

	Family.Database:Forget(key)
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

	-- Held in the queue rather than gone the moment it was sent. This harness has no timer,
	-- so everything drains at once unless something stops it - and being in a fight stops
	-- bulk, which is what a family's records are. That is the state the fault happens in
	-- anyway: hundreds of messages still waiting to go to somebody who is not there.
	InCombatLockdown = function() return true end

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

		_G.C_Map = nil
		check("with no map API at all, the recorded word is what is shown",
			Family.Names:Area(1537, "Ironforge") == "Ironforge")
		check("and no id can be found for anything",
			Family.Names:AreaFor("Forgefer") == nil)

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
		for _, name in ipairs { "Window", "MemberPicker", "ChoicePicker", "Tooltip", "Summary",
			"Talents", "Contents", "Professions", "Character", "Quests", "Wide", "Guild",
			"Broker", "Options", "About", "Slash" } do
			list[#list + 1] = "addons/Family_UI/" .. name .. ".lua"
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
	local asked = {}
	for path, text in pairs(sources) do
		local at = 1
		while true do
			local open = text:find("%f[%w_]L%[", at)
			if not open then break end
			local i = text:find("%[", open)
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
			if inside:match('^%s*"') then
				-- Walked rather than matched. A Lua pattern cannot say "a quote that is not
				-- preceded by a backslash", so '"([^"]*)"' ends a literal at the first \"
				-- inside it and splits the key in two - which showed up as three perfectly
				-- good translations being reported as orphans.
				local joined = {}
				do
					local at = 1
					while true do
						local open = inside:find('"', at, true)
						if not open then break end
						local scan, out = open + 1, {}
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
				end
				-- Read out of the file as text, so an escape is still two characters here
				-- and is one character in the table the client builds. Undone, or every
				-- string with a newline in it would be reported as an orphan.
				local key = table.concat(joined)
					:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub('\\"', '"'):gsub("\\\\", "\\")
				asked[key] = path
			end
			at = j + 1
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

	-- Every sentence the slash commands print is translated in all four languages.
	--
	-- Not a rule about coverage in general. A missing translation degrades to readable
	-- English on purpose, and that is right for a label standing on its own. It is wrong for
	-- a sentence, because the values inside one come from the same helpers the panels use
	-- and are translated whatever the sentence around them is - so an untranslated line
	-- reads "seen il y a 19j, 2 container(s), meta says jamais", half of each, which is what
	-- a French player was sent when a diagnosis was added without its translations.
	--
	-- Slash.lua is where Family writes sentences rather than labels, which is why the rule
	-- is drawn there and not everywhere.
	for _, code in ipairs { "deDE", "frFR", "esES", "ruRU" } do
		local table_ = Family.locales[code] or {}
		local half = {}
		for key, path in pairs(asked) do
			if path == "addons/Family_UI/Slash.lua" and rawget(table_, key) == nil then
				half[#half + 1] = key
			end
		end
		table.sort(half)
		check(code .. " translates every sentence the slash commands print",
			#half == 0, table.concat(half, " | "))
	end
end)()

print()
if failures == 0 then
	print("all checks passed")
else
	print(failures .. " CHECK(S) FAILED")
	os.exit(1)
end
