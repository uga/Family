-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The summary: one row per member, grouped by realm, with a totals line.
--
-- This screen is the reason meta and payload are separate (Database.lua). It reads every
-- member Family knows about, and it reads nothing but meta - so it costs the same whether an
-- account has four members or forty, and no member's bag contents are decoded to draw it.
--
-- Slice one draws the Overview column set only. The others (§4.1) hang off the same rows.

local _, UI = ...

local Family = _G.Family

local ROW_HEIGHT = 18
local HEADER_HEIGHT = 22

-- One set of columns at a time (§4.1). Cramming everything into a single view is what made
-- the professions column wrap onto two lines: there is only so much width, and the answer is
-- to show fewer things at once rather than to shrink all of them.
--
-- The member column is not listed here. It leads every set, because a row nobody can identify
-- is not worth showing whatever is beside it.
-- Widths are a budget, not a preference. The panel is 900 wide, the tab strip and the scroll
-- bar take their share, and what is left for a row is a little over seven hundred - so a set
-- adding up to more than that has a column nobody can read, and there is no sideways scroll
-- to rescue it. Every set below is inside that, and should stay inside it.
local MEMBER_COLUMN = { key = "name", label = "Member", width = 130, justify = "LEFT" }

-- Declared before the sets, which use them, and defined below with everything else that
-- turns a record into a piece of text. Written the other way round, the professions set
-- captured a global that never got set and the panel died the first time it was drawn.
local skillsOf, skillText

-- Built further down, where the cells they have to register alongside are. Declared here
-- because the sets below are written first and would otherwise capture a global that never
-- arrives.
local currencyColumns, craftingColumns

local SETS = {
	{
		id = "overview", label = "Overview",
		columns = {
			{ key = "level",  label = "Level",     width = 50,  justify = "RIGHT" },
			{ key = "ilvl",   label = "Item lvl",  width = 70,  justify = "RIGHT" },
			{ key = "xp",     label = "Rest XP",   width = 90,  justify = "RIGHT" },
			{ key = "money",  label = "Money",     width = 145, justify = "RIGHT" },
			{ key = "played", label = "Played",    width = 85,  justify = "RIGHT" },
			{ key = "seen",   label = "Last seen", width = 95,  justify = "RIGHT" },
		},
	},
	{
		id = "bags", label = "Bags",
		columns = {
			{ key = "bagfree",  label = "Free bags",  width = 90, justify = "RIGHT" },
			{ key = "bagtotal", label = "Bag slots",  width = 90, justify = "RIGHT" },
			{ key = "bankfree", label = "Free bank",  width = 90, justify = "RIGHT" },
			{ key = "banktotal",label = "Bank slots", width = 90, justify = "RIGHT" },
			{ key = "bankseen", label = "Bank seen",  width = 100, justify = "RIGHT" },
			-- Bags are live, but only for a member who has been played: this says how
			-- old "live" is for each of them.
			{ key = "bagseen",  label = "Bags seen",  width = 100, justify = "RIGHT" },
		},
	},
	{
		id = "activity", label = "Activity",
		-- The widest set there is, and it has to fit: there is no sideways scrolling, so a
		-- column past the edge is a column nobody can read. These add up to the width of
		-- the panel with the member column, and should stay that way.
		columns = {
			-- Wide enough for "not seen", which is what these say far more often than
			-- they say a number. At fifty it broke across two lines and drew over the
			-- member underneath.
			{ key = "mail",     label = "Mail",       width = 65,  justify = "RIGHT" },
			{ key = "mailexp",  label = "Expires in", width = 80,  justify = "RIGHT" },
			{ key = "mailseen", label = "Mail seen",  width = 75,  justify = "RIGHT" },
			{ key = "auctions", label = "Auctions",   width = 65,  justify = "RIGHT" },
			{ key = "bids",     label = "Bid value",  width = 105, justify = "RIGHT" },
			{ key = "buyouts",  label = "Buyout",     width = 105, justify = "RIGHT" },
			{ key = "aucseen",  label = "AH seen",    width = 70,  justify = "RIGHT" },
		},
	},
	{
		id = "professions", label = "Professions",
		columns = {
			-- Four columns, and as many lines per member as it takes. Professions do
			-- not fit on one line - five side by side cut "Leatherworking 289/300"
			-- off in the middle of a number - and two lines on two different grids
			-- were worse than one crowded line: nothing under anything.
			--
			-- So it is one grid. The primaries take the first line and everything
			-- else takes the ones below, in the same columns, so a member's
			-- professions line up with each other and with everybody else's.
			--
			-- Three columns rather than four, and wider. There are only ever two
			-- primaries, so the fourth column stood empty on every member's first
			-- line while "Leatherworking 360/375" was being cut in half in the
			-- first - width spent where there was nothing to put it and withheld
			-- where there was.
			{ key = "prof1",  label = "Primary",   width = 194, justify = "LEFT" },
			{ key = "prof2",  label = "Primary",   width = 194, justify = "LEFT" },
			{ key = "",       label = "",          width = 194, justify = "LEFT" },
		},
		-- Everything that is not a primary, three to a line, in whatever order the
		-- member has them. A member with none gets no extra line at all.
		extra = function(meta)
			local lines, line = {}, nil

			for index, entry in ipairs(skillsOf(meta, true)) do
				if (index - 1) % 3 == 0 then
					line = {}
					lines[#lines + 1] = line
				end
				line[#line + 1] = skillText(entry)
			end

			return lines
		end,
	},
	{
		-- The one set whose columns are not written down here.
		--
		-- Which currencies exist is the client's business and differs by expansion, and
		-- which of them anybody actually holds is the family's - a set fixed at honor and
		-- arena would be two empty columns on Mists and the wrong two on Era. So this set
		-- is built from what has been recorded, most held first, and stops at what a row
		-- can carry. currencyColumns below does that and says what it left out.
		id = "currencies", label = "Currencies",
		columns = {},
		build = function() return currencyColumns() end,
	},
	{
		-- Built from what the family actually has cooldowns for, the same way Currencies is
		-- and for the same reason: which cooldowns exist depends on which professions this
		-- family took, and a fixed set of columns would be Alchemy and Tailoring for
		-- everybody, empty for most of them.
		id = "crafting", label = "Crafting",
		columns = {},
		build = function() return craftingColumns() end,
	},
	{
		id = "misc", label = "Miscellaneous",
		columns = {
			{ key = "guild",  label = "Guild",       width = 160, justify = "LEFT" },
			{ key = "hearth", label = "Hearthstone", width = 170, justify = "LEFT" },
			{ key = "race",   label = "Race",        width = 100, justify = "LEFT" },
			{ key = "class",  label = "Class",       width = 110, justify = "LEFT" },
		},
	},
}

-- What a row actually has: the window, less the tab strip down the side, less the scroll bar
-- and the margins. Kept as a number here so the check below can be made rather than assumed.
local ROW_BUDGET = 714

-- The most columns a set built at draw time may ask for. Rows are built once with enough
-- cells for the widest set there is, so a set that grows its own columns has to have a
-- ceiling somewhere, and here is better than finding out when a cell is missing.
local MAX_BUILT_COLUMNS = 7

-- Checked at load rather than trusted. A set that outgrows the row loses its last column off
-- the edge, and there is no sideways scroll to find it with - so it goes missing quietly,
-- which is the part worth catching.
--
-- A set that builds its own columns cannot be checked here, because it has nothing to check
-- until there is a family to build them from. It keeps to the same budget itself.
for _, set in ipairs(SETS) do
	if not set.build then
		local width = MEMBER_COLUMN.width
		for _, column in ipairs(set.columns) do width = width + column.width end

		if width > ROW_BUDGET then
			Family:Print("|cffffaa00the %s columns add up to %d, wider than the %d a row "
				.. "has|r", set.label, width, ROW_BUDGET)
		end
	end
end

-- The row of set buttons has the same problem the table does, and no scroll bar either. The
-- faction filters hold the right-hand end of it, so a set too many does not fall off the edge
-- quietly - it lands underneath them, which is worse, because both are then unusable.
--
-- Checked here for the same reason the row is: the Currencies set pushed the filters off the
-- window and nothing said so.
-- This guard was here, and it worked, and it went unread: adding the Crafting set made it
-- fire and the warning went into a chat frame nobody was looking at while the buttons quietly
-- overlapped the filters on screen. A warning nobody reads is not a guard, so two things
-- changed. The buttons now share out the room they have, so they cannot overflow by
-- construction - and what is left to go wrong is the opposite fault, a set too many making all
-- of them too narrow to read, which is what this now watches for.
local CHOOSER_WIDTH = 740        -- the window, less the tab strip and the margins
local FACTION_ROOM = 76          -- two narrow buttons and a gap before them

-- Enough for "Miscellaneous", which is the longest label there is and the one that decides it.
local SET_BUTTON_MINIMUM = 88

local SET_BUTTON_WIDTH = math.floor((CHOOSER_WIDTH - FACTION_ROOM) / #SETS) - 2
local SET_BUTTON_STEP = SET_BUTTON_WIDTH + 2

if SET_BUTTON_WIDTH < SET_BUTTON_MINIMUM then
	Family:Print("|cffffaa00%d column sets leave %d pixels each across the top, and a label "
		.. "needs %d|r", #SETS, SET_BUTTON_WIDTH, SET_BUTTON_MINIMUM)
end

local currentSet = SETS[1]

local function columnsOf(set)
	local columns = { MEMBER_COLUMN }
	for _, column in ipairs(set.build and set.build() or set.columns) do
		columns[#columns + 1] = column
	end
	return columns
end

-- The widest a set gets, so every row is built once with enough cells for any of them.
local MAX_CELLS = MAX_BUILT_COLUMNS + 1
for _, set in ipairs(SETS) do
	MAX_CELLS = math.max(MAX_CELLS, #set.columns + 1)
end

--------------------------------------------------------------------------------------------
-- Turning what was recorded into what a cell says
--
-- Every one of these answers nil when the thing was never seen, and the caller draws the
-- honest placeholder. That is §2.2 in one convention: nothing here invents a zero.
--------------------------------------------------------------------------------------------

-- The window's, so that a dash here and a dash anywhere else are the same dash.
local UNKNOWN = UI.UNKNOWN
local NOT_SEEN = "|cff9d9d9dnot seen|r"

function skillsOf(meta, secondary)
	local found = {}
	for name, skill in pairs(meta.skills or {}) do
		if (skill.secondary or false) == secondary then
			found[#found + 1] = { name = name, skill = skill }
		end
	end
	table.sort(found, function(a, b) return a.name < b.name end)
	return found
end

-- "Blacksmithing 287/375", or "Cooking 300" where it is finished - the maximum of a capped
-- profession is the rank said twice, and these cells are narrow.
--
-- The name is greyed when Family has not seen that profession's recipes lately, which is how
-- staleness is shown without a column for it. A rank is always current and a recipe list
-- never is, so the one thing worth saying per profession is whether the list behind it can
-- still be believed - and a date beside each of five professions would be five dates nobody
-- reads.
local STALE = 7 * 86400

-- What a profession cell can hold, in characters, at the width the professions set gives it.
--
-- The cell clips whatever will not fit, and it clips the *end* - which is where the numbers
-- are. "Leatherworking 360/375" came out as "Leatherworking 360/..." and lost the one part of
-- itself that was information: the name is recognisable from its first letters and the rank is
-- not recoverable from anything. So the name is shortened here instead, and the numbers always
-- survive.
--
-- Counted rather than measured because there is nothing to measure with: GetStringWidth
-- answers for a font string that has already been given its text, and this decides what the
-- text should be. A character count is approximate and always errs the same way.
-- Counted, and generous, because it is a backstop rather than a layout.
--
-- It was 21 and it was doing the layout's job, which it cannot do: the font is proportional,
-- so "Jewelcrafting 373/375" and "Leatherworking 360/375" are the same number of characters
-- and not the same number of pixels - the first fitted and the second did not. The column is
-- wide enough for both now, and this is here so that something genuinely absurd still cannot
-- write through the side of the cell.
local CELL_CHARACTERS = 28

local function fitted(name, tail)
	local room = CELL_CHARACTERS - #tail
	if #name <= room then return name end
	if room < 4 then return name end
	return name:sub(1, room - 1) .. "-"
end

function skillText(entry)
	if not entry then return nil end

	local seen = entry.skill.recipesSeen
	local name = entry.name
	local stale = not seen or (time() - seen) > STALE

	-- Not every profession has a rank. A death knight's runeforging is a window full of
	-- things they can make and no skill anywhere, and this compared its rank against its
	-- maximum without checking either existed - so learning runeforging threw this whole
	-- panel over. The name alone is the honest answer.
	local rank, maxRank = entry.skill.rank, entry.skill.maxRank

	-- Shortened against the numbers that are going to follow it, and coloured afterwards:
	-- the colour codes are not characters anybody can see and must not be counted as though
	-- they were.
	local function drawn(text)
		return stale and ("|cff9d9d9d" .. text .. "|r") or text
	end

	if not (rank and maxRank) then return drawn(fitted(name, "")) end

	-- Amber at the ceiling, because that is the one worth noticing at a glance.
	if rank >= maxRank then
		local tail = " " .. tostring(rank)
		return string.format("%s |cffffaa00%d|r", drawn(fitted(name, tail)), rank)
	end

	local tail = string.format(" %d/%d", rank, maxRank)
	return string.format("%s |cffffd700%d|r/%d", drawn(fitted(name, tail)), rank, maxRank)
end

-- "3d 4h", or "4h 20m" - the two largest units that matter and no more.
local function duration(seconds)
	if not seconds or seconds <= 0 then return nil end

	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if days > 0 then return string.format("%dd %dh", days, hours) end
	if hours > 0 then return string.format("%dh %dm", hours, minutes) end
	return string.format("%dm", minutes)
end

local CELL = {}

CELL.name = function(meta, key)
	return "  " .. (meta.name or key), UI:ClassColour(meta.classFile)
end

CELL.level = function(meta) return meta.level and tostring(meta.level) or "?" end

CELL.money = function(meta) return UI:Money(meta.money) end

CELL.ilvl = function(meta)
	if not meta.itemLevel then return UNKNOWN end
	return string.format("%.1f", meta.itemLevel)
end

-- Letters watched being posted are counted here with everything else, and said separately.
-- They are the one thing in this table known from the other end - somebody sent them, nobody
-- has yet seen them in a mailbox (§5) - and a column that folded them in silently would be
-- claiming a mailbox had been looked at when it had not.
CELL.mail = function(meta)
	local inPost = Family.Mail:InPost(meta)

	if not meta.mailSeen then
		if inPost > 0 then
			return string.format("|cffffd700%d|r |cff888888in post|r", inPost)
		end
		return NOT_SEEN
	end

	if inPost > 0 then
		return string.format("%d |cff888888(%d in post)|r", meta.mailCount or 0, inPost)
	end
	return tostring(meta.mailCount or 0)
end

CELL.mailseen = function(meta)
	if not meta.mailSeen then return UNKNOWN end
	return UI:Ago(meta.mailSeen), 0.7, 0.7, 0.7
end

-- The one number on this screen worth reacting to, so it is the one that goes red. Mail
-- that expires takes its attachments with it.
CELL.mailexp = function(meta)
	local remaining = Family.Mail:TimeToExpiry(meta)
	if not remaining then return UNKNOWN end
	if remaining <= 0 then return "|cffff4444gone|r" end

	local text = duration(remaining) or "soon"
	if remaining < 3 * 86400 then return "|cffff4444" .. text .. "|r" end
	if remaining < 7 * 86400 then return "|cffffaa00" .. text .. "|r" end
	return text
end

-- Aggregates rather than a list: on one row per member, what is worth knowing is how much is
-- riding on the auction house, not which items are on it.
local function auctionTotals(meta, key)
	-- Through the window's reader rather than the database's, because a sibling's record is
	-- not in the database and this cell has no business knowing that (§6).
	local payload = UI:Payload(key)
	if not (payload and payload.auctions) then return nil end

	local selling = Family.Auctions:Live(payload.auctions)
	local bid, buyout = 0, 0
	for _, entry in ipairs(selling) do
		bid = bid + (entry.bid > 0 and entry.bid or entry.minBid or 0)
		buyout = buyout + (entry.buyout or 0)
	end

	return #selling, bid, buyout
end

CELL.auctions = function(meta, key)
	if not meta.auctionsSeen then return NOT_SEEN end
	local count = auctionTotals(meta, key)
	return tostring(count or 0)
end

CELL.bids = function(meta, key)
	if not meta.auctionsSeen then return UNKNOWN end
	local _, bid = auctionTotals(meta, key)
	return UI:Money(bid or 0)
end

CELL.buyouts = function(meta, key)
	if not meta.auctionsSeen then return UNKNOWN end
	local _, _, buyout = auctionTotals(meta, key)
	return UI:Money(buyout or 0)
end

CELL.aucseen = function(meta)
	if not meta.auctionsSeen then return UNKNOWN end
	return UI:Ago(meta.auctionsSeen), 0.7, 0.7, 0.7
end

-- "Never" is a thing we can say about our own, whose comings and goings Family watches. When
-- a linked family shares somebody, when they last played is not among the facts that travel -
-- so this column answers the question it can answer about a borrowed member, which is how old
-- what we hold about them is. The exchange stamps that, the Wide Family panel has always shown
-- it on hover as "as of", and a dash here was the panel declining to say a thing it knew.
--
-- The two readings are different facts in one column and the header cannot say both, so the
-- borrowed answer is written as "shared" and our own is left bare. A date with no word beside
-- it is this family's; a date that says shared came from somebody else's.
CELL.seen = function(meta, key, sharedAt)
	if not meta.lastSeen and UI:IsBorrowed(key) then
		if not sharedAt then return UNKNOWN end
		return "|cff888888shared|r " .. UI:Ago(sharedAt), 0.7, 0.7, 0.7
	end
	return UI:Ago(meta.lastSeen), 0.7, 0.7, 0.7
end

CELL.played = function(meta)
	return duration(meta.played) or NOT_SEEN
end

-- Rested experience as a share of a level, which is how it is actually thought about -
-- "half a level banked" means something, "38400" does not.
CELL.xp = function(meta, key)
	-- "Max level" is deduced from having no maximum left to reach, which is true of a
	-- member Family scanned and says nothing about one a linked family handed over without
	-- this category in it. Grella, at 61 on a client whose maximum is 70, was being called
	-- max level on exactly that reasoning.
	if not meta.xpMax and UI:IsBorrowed(key) then return UNKNOWN end
	if not meta.xpMax then return "|cff9d9d9dmax level|r" end
	local rested = meta.rested or 0
	if rested == 0 then return "0%" end
	return string.format("|cff8080ff%d%%|r", math.floor(rested / meta.xpMax * 100))
end

CELL.bagfree = function(meta)
	if not meta.bagSlots or meta.bagSlots == 0 then return UNKNOWN end
	local free = meta.bagFree or 0
	local tight = free <= 3
	return tostring(free), tight and 1 or 0.9, tight and 0.7 or 0.9, tight and 0.2 or 0.9
end

CELL.bagtotal = function(meta)
	return meta.bagSlots and tostring(meta.bagSlots) or UNKNOWN
end

CELL.bankfree = function(meta)
	if not meta.bankSeen then return NOT_SEEN end
	return tostring(meta.bankFree or 0)
end

CELL.banktotal = function(meta)
	if not meta.bankSeen then return UNKNOWN end
	return tostring(meta.bankSlots or 0)
end

CELL.bagseen = function(meta)
	if not meta.bagsSeen then return NOT_SEEN end
	return UI:Ago(meta.bagsSeen), 0.7, 0.7, 0.7
end

CELL.bankseen = function(meta)
	if not meta.bankSeen then return NOT_SEEN end
	return UI:Ago(meta.bankSeen), 0.7, 0.7, 0.7
end

CELL.prof1 = function(meta) return skillText(skillsOf(meta, false)[1]) or UNKNOWN end
CELL.prof2 = function(meta) return skillText(skillsOf(meta, false)[2]) or UNKNOWN end

CELL.guild = function(meta) return meta.guild or UNKNOWN end
CELL.hearth = function(meta) return meta.hearth or UNKNOWN end
CELL.race = function(meta) return meta.raceFile or UNKNOWN end

CELL.class = function(meta)
	if not meta.classFile then return UNKNOWN end
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	local localised = names and names[meta.classFile]
	return localised or meta.classFile, UI:ClassColour(meta.classFile)
end

--------------------------------------------------------------------------------------------
-- What a column adds up to
--
-- Only the columns where adding up means something have an entry here. Everything else is
-- left blank on a totals row rather than filled in for the sake of it: the sum of six item
-- levels is not a number anybody wants, and the average of six "last seen" times is worse.
--------------------------------------------------------------------------------------------

local function sumOf(members, field)
	local sum = 0
	for _, member in ipairs(members) do sum = sum + (member.meta[field] or 0) end
	return sum
end

local TOTAL = {
	money = function(members) return UI:Money(sumOf(members, "money")) end,

	played = function(members)
		return duration(sumOf(members, "played")) or UNKNOWN
	end,

	bagfree   = function(members) return tostring(sumOf(members, "bagFree")) end,
	bagtotal  = function(members) return tostring(sumOf(members, "bagSlots")) end,
	bankfree  = function(members) return tostring(sumOf(members, "bankFree")) end,
	banktotal = function(members) return tostring(sumOf(members, "bankSlots")) end,
	mail      = function(members) return tostring(sumOf(members, "mailCount")) end,

	auctions = function(members)
		local count = 0
		for _, member in ipairs(members) do
			count = count + (auctionTotals(member.meta, member.key) or 0)
		end
		return tostring(count)
	end,

	bids = function(members)
		local total = 0
		for _, member in ipairs(members) do
			local _, bid = auctionTotals(member.meta, member.key)
			total = total + (bid or 0)
		end
		return UI:Money(total)
	end,

	buyouts = function(members)
		local total = 0
		for _, member in ipairs(members) do
			local _, _, buyout = auctionTotals(member.meta, member.key)
			total = total + (buyout or 0)
		end
		return UI:Money(total)
	end,
}

--------------------------------------------------------------------------------------------
-- Gathering
--
-- Members are grouped by realm because an account spread over several realms is the normal
-- case, not the exception (§4).
--------------------------------------------------------------------------------------------

-- Which sides are being shown. A filter rather than a choice: an account with characters on
-- both is normal, and so is wanting to see one of them, and so is wanting to see all of it.
-- Both on until somebody says otherwise, and remembered because it is a preference.
local FACTIONS = { "Alliance", "Horde" }

-- The sides, from the one place that holds them (Window.lua). The whole family's gear groups
-- by side as well, and it has to group by the same three and colour them the same way.
local UNKNOWN_SIDE = UI.UNKNOWN_SIDE
local SIDE_ORDER = UI.SIDE_ORDER
local SIDE_COLOUR = UI.SIDE_COLOUR

local function factionShown(faction)
	local switches = FamilyDB and FamilyDB.ui and FamilyDB.ui.factions
	if not switches then return true end

	-- A member whose side was never recorded is shown whatever the switches say. They
	-- cannot be filtered by something Family does not know about them.
	if not faction then return true end
	return switches[faction] ~= false
end

local function byLevelThenName(a, b)
	local levelA, levelB = a.meta.level or 0, b.meta.level or 0
	if levelA ~= levelB then return levelA > levelB end
	return (a.meta.name or "") < (b.meta.name or "")
end

-- Siblings, arranged the way they are drawn: the realm they are on, and inside it the family
-- they belong to (§6).
--
-- Whose they are is never merged away, which is why they are grouped by family rather than
-- mixed in with our own members and marked somehow. A row that has to be inspected to find
-- out whose it is has already blurred the one line §6 exists to hold.
local function gatherSiblings()
	local byRealm = {}

	for _, member in ipairs(Family.Wide:Siblings()) do
		local meta = member.meta or {}
		if factionShown(meta.faction) then
			local realm = meta.realm or "Unknown realm"
			local here = byRealm[realm]
			if not here then
				here = { families = {}, order = {}, count = 0 }
				byRealm[realm] = here
			end

			local group = here.families[member.family]
			if not group then
				group = { name = member.familyName or "another family", members = {} }
				here.families[member.family] = group
				tinsert(here.order, group)
			end

			tinsert(group.members, { key = member.key, meta = meta, borrowed = true,
				seen = member.seen })
			here.count = here.count + 1
		end
	end

	for _, here in pairs(byRealm) do
		table.sort(here.order, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
		for _, group in ipairs(here.order) do
			table.sort(group.members, byLevelThenName)
		end
	end

	return byRealm
end

local function gather()
	local byRealm, realms = {}, {}
	local totalMoney, totalFree, totalSlots, count = 0, 0, 0, 0

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta
		if meta and factionShown(meta.faction) then
			local realm = meta.realm or "Unknown realm"
			if not byRealm[realm] then
				byRealm[realm] = {}
				tinsert(realms, realm)
			end
			tinsert(byRealm[realm], { key = key, meta = meta })

			totalMoney = totalMoney + (meta.money or 0)
			totalFree = totalFree + (meta.bagFree or 0)
			totalSlots = totalSlots + (meta.bagSlots or 0)
			count = count + 1
		end
	end

	-- A sibling can be on a realm where we have nobody at all, and that realm still has to
	-- have a heading for them to sit under. Nothing is added to the totals, here or below:
	-- the money on the totals line is this family's money, and adding somebody else's would
	-- produce a figure that describes nobody.
	local siblings = gatherSiblings()
	for realm in pairs(siblings) do
		if not byRealm[realm] then
			byRealm[realm] = {}
			tinsert(realms, realm)
		end
	end

	table.sort(realms)
	for _, members in pairs(byRealm) do
		table.sort(members, byLevelThenName)
	end

	return realms, byRealm, {
		money = totalMoney,
		free = totalFree,
		slots = totalSlots,
		members = count,
	}, siblings
end

--------------------------------------------------------------------------------------------
-- Currencies, which are columns nobody wrote down
--
-- Honor and arena points on the Burning Crusade clients, a list of a dozen on Mists, and on
-- Era whatever that client turns out to answer. Fixed columns cannot be right for all three,
-- so this set asks the family what it holds and builds columns for that.
--------------------------------------------------------------------------------------------

local CURRENCY_WIDTH = 105

-- 75000 is unreadable and 75,000 is not. The separator is a comma rather than the client's,
-- which is a thing to put right when the language file lands, not before.
local function counted(number)
	local text = tostring(math.floor(tonumber(number) or 0))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Enough of the name to know which column it is. A currency called "Lesser Charm of Good
-- Fortune" cannot be a hundred-pixel heading, and the character panel has the full name.
local function shortened(name, limit)
	if type(name) ~= "string" then return "?" end
	if #name <= limit then return name end
	return name:sub(1, limit - 1) .. "..."
end

local function currencyOf(meta, key)
	for _, currency in ipairs(meta.currencies or {}) do
		if currency.key == key then return currency end
	end
	return nil
end

-- Every currency anybody has been seen holding, and what the family has of each.
local function currenciesHeld()
	local byKey, order = {}, {}

	for _, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		if factionShown(meta.faction) then
			for _, currency in ipairs(meta.currencies or {}) do
				-- Records written before the scanner insisted on a key are already on
				-- disk, and one of them indexed a table with a nil and took this whole
				-- panel down. They are skipped until that member is scanned again.
				local found = currency.key and byKey[currency.key]
				if currency.key and not found then
					found = { key = currency.key, total = 0 }
					byKey[currency.key] = found
					order[#order + 1] = found
				end
				if found then
					-- The name from whoever has the most of it, which on a family
					-- split across two language clients is at least a name somebody
					-- recognises.
					if currency.quantity and currency.quantity >= (found.best or -1) then
						found.best, found.name = currency.quantity, currency.name
					end
					found.total = found.total + (currency.quantity or 0)
				end
			end
		end
	end

	-- Most held first: with room for five columns and a dozen currencies, the ones the
	-- family actually has are the ones worth the room.
	table.sort(order, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return tostring(a.name or a.key) < tostring(b.name or b.key)
	end)

	return order
end

-- How many were left out, so the panel can say so rather than quietly showing five of twelve.
local currenciesOmitted = 0

--------------------------------------------------------------------------------------------
-- Crafting cooldowns, one column per kind the family has
--
-- Green when it is available, which is the half anybody opened this for. Grey with the time
-- when it is not - grey rather than red, because everywhere else in Family red means something
-- is wrong or about to be lost, and a transmute you used two hours ago is neither. "Not yet"
-- is what this means and grey is how the game says it.
--
-- A member who has never been seen with that cooldown at all gets nothing, not a nought: they
-- may not have the profession, or Family may simply never have watched the recipe on cooldown
-- (Cooldowns.lua). Both are absences and neither is "available in nought minutes".
--------------------------------------------------------------------------------------------

local CRAFTING_WIDTH = 120

-- Every kind of crafting cooldown anybody in the family has, most-held first so that the ones
-- the family really uses take the room a row has.
local function craftingKinds()
	local byLabel, order = {}, {}

	for _, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		if factionShown(meta.faction) then
			for _, kind in ipairs(Family.Cooldowns:Crafting(meta)) do
				-- Keyed by what it is called rather than by the group's own key, which
				-- carries the moment it comes back and would make a column per member.
				local found = byLabel[kind.label]
				if not found then
					found = { label = kind.label, members = 0 }
					byLabel[kind.label] = found
					order[#order + 1] = found
				end
				found.members = found.members + 1
			end
		end
	end

	table.sort(order, function(a, b)
		if a.members ~= b.members then return a.members > b.members end
		return tostring(a.label) < tostring(b.label)
	end)

	return order
end

-- How many were left out, so the panel can say so rather than quietly showing four of nine.
local craftingOmitted = 0

function craftingColumns()
	local kinds = craftingKinds()
	local columns = {}

	local room = math.floor((ROW_BUDGET - MEMBER_COLUMN.width) / CRAFTING_WIDTH)
	local limit = math.min(room, MAX_BUILT_COLUMNS, #kinds)
	craftingOmitted = #kinds - limit

	for index = 1, limit do
		local label = kinds[index].label
		local key = "cd:" .. label

		columns[index] = { key = key, label = shortened(label, 15),
			width = CRAFTING_WIDTH, justify = "RIGHT" }

		CELL[key] = function(meta)
			for _, kind in ipairs(Family.Cooldowns:Crafting(meta)) do
				if kind.label == label then
					if kind.ready then
						return "|cff40bf40ready|r"
					end
					return string.format("|cff9d9d9d%s|r",
						duration(kind.readyAt - time()) or "soon")
				end
			end
			return ""
		end
	end

	return columns
end

function currencyColumns()
	local held = currenciesHeld()
	local columns = {}

	local room = math.floor((ROW_BUDGET - MEMBER_COLUMN.width) / CURRENCY_WIDTH)
	local limit = math.min(room, MAX_BUILT_COLUMNS, #held)
	currenciesOmitted = #held - limit

	for index = 1, limit do
		local currency = held[index]
		local key = "cur:" .. currency.key

		columns[index] = { key = key, label = shortened(currency.name or currency.key, 13),
			width = CURRENCY_WIDTH, justify = "RIGHT" }

		-- Registered rather than looked up: every other column in this file has its cell
		-- and its total written beside it, and these have to behave the same way or the
		-- drawing code would need to know that one set is special.
		CELL[key] = function(meta)
			-- Never seen is not none. A member scanned before Family could read
			-- currencies has no answer here, and a zero would be an invented one.
			if not meta.currenciesSeen then return NOT_SEEN end

			local held = currencyOf(meta, currency.key)
			if not held then return "|cff9d9d9d0|r" end
			return counted(held.quantity)
		end

		TOTAL[key] = function(members)
			local sum = 0
			for _, member in ipairs(members) do
				local held = currencyOf(member.meta, currency.key)
				sum = sum + (held and held.quantity or 0)
			end
			return counted(sum)
		end
	end

	return columns
end


--------------------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------------------

-- Built once with as many cells as the widest set needs, then moved and resized when the set
-- changes. Rebuilding every row on each switch would churn a hundred frames to show the same
-- forty members.
local function makeRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row.cells = {}

	for index = 1, MAX_CELLS do
		row.cells[index] = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	end

	-- A row is a fixed height, so a cell that wraps draws over the row beneath it rather
	-- than making room for itself: "not seen" in a narrow column took two lines and the
	-- member below it with them. Cut off instead, which leaves the table readable.
	UI:NoWrap(unpack(row.cells))

	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.06)
	row.highlight:Hide()

	row:SetScript("OnEnter", function(self) self.highlight:Show() end)
	row:SetScript("OnLeave", function(self) self.highlight:Hide() end)

	-- Left opens whatever the cell under the cursor is about; right removes the member.
	-- Right for the destructive one, because it should not be what an ordinary click
	-- reaches.
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self, button)
		if not self.memberKey then return end

		if button == "RightButton" then
			-- A sibling is not ours to delete, and offering to would be offering to do
			-- something that cannot be done. What we hold of them goes when they stop
			-- sharing them, or when the link ends - both of which are decisions somebody
			-- makes on the Wide Family panel, so that is where the answer is.
			if self.borrowed then
				Family:Print("|cff888888%s belongs to a linked family. Untick them as a "
					.. "sibling on the Wide Family panel to take them off this table.|r",
					tostring(self.memberName))
				return
			end

			-- Named with their realm, because two characters can share a name and the
			-- one being deleted is not always the one you are looking at.
			UI:ConfirmForget(self.memberKey, self.memberName, self.memberRealm)
			return
		end

		if self.opens then self.opens(self) end
	end)

	return row
end

-- Places a row's cells for the set being shown, and hides the spare ones so a wide set
-- leaves nothing behind when a narrow one replaces it.
local function layOut(cells, columns)
	local x = 0
	for index = 1, MAX_CELLS do
		local cell, column = cells[index], columns[index]
		cell:ClearAllPoints()

		if column then
			cell:SetPoint("LEFT", x + 4, 0)
			cell:SetWidth(column.width - 8)
			cell:SetJustifyH(column.justify)
			cell:Show()
			x = x + column.width
		else
			cell:SetText("")
			cell:Hide()
		end
	end
end

local function setCell(row, index, text, r, g, b)
	local cell = row.cells[index]
	if not cell then return end
	cell:SetText(text or "")
	cell:SetTextColor(r or 1, g or 1, b or 1)
end

--------------------------------------------------------------------------------------------

local function build(frame)
	local chooser = CreateFrame("Frame", nil, frame)
	chooser:SetPoint("TOPLEFT", 0, 0)
	chooser:SetPoint("TOPRIGHT", 0, 0)
	chooser:SetHeight(24)

	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", chooser, "BOTTOMLEFT", 0, -2)
	header:SetPoint("TOPRIGHT", chooser, "BOTTOMRIGHT", 0, -2)
	header:SetHeight(HEADER_HEIGHT)

	local headerCells = {}
	for index = 1, MAX_CELLS do
		local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		text:SetTextColor(1, 0.82, 0)
		headerCells[index] = text
	end

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", -26, 28)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	footer:SetPoint("BOTTOMLEFT", 4, 8)
	footer:SetPoint("BOTTOMRIGHT", -4, 8)
	footer:SetJustifyH("LEFT")

	-- Above the footer, because it is about the columns rather than about the totals.
	local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 4)
	note:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
	note:SetJustifyH("LEFT")

	local rows = {}
	local setButtons = {}

	-- Sized against how many sets there are rather than fixed, because adding one is how this
	-- row came to run under the side filters at the right-hand end: seven buttons at the width
	-- four had is wider than the panel, and nothing complains - it just overlaps. Worked out
	-- once, above, where the check that it is still legible lives beside it.
	local setWidth, setStep = SET_BUTTON_WIDTH, SET_BUTTON_STEP

	local x = 0
	for _, set in ipairs(SETS) do
		local button = CreateFrame("Button", nil, chooser, "UIPanelButtonTemplate")
		button:SetSize(setWidth, 20)
		button:SetPoint("LEFT", x, 0)
		button:SetText(set.label)
		button:SetScript("OnClick", function()
			currentSet = set
			frame:Refresh()
		end)
		setButtons[set.id] = button
		x = x + setStep
	end

	-- The two sides, anchored to the right-hand end of the row rather than laid out after
	-- the last set button.
	--
	-- Trailing the sets meant that adding one pushed these two off the edge of the window,
	-- where there is no sideways scroll to find them with - which is exactly what adding
	-- the Currencies set did. They are a filter over the whole table, not another set, so
	-- the right-hand end is where they belong anyway, and no future set can move them.
	--
	-- Narrow, because each shows one banner. They were as wide as a set button and spent a
	-- hundred and forty pixels saying "A" and "H".
	--
	-- A banner rather than a letter, now that there is a picture for it that has been looked
	-- at on all three clients (Window.lua). "A" and "H" are the initials of the English words
	-- and of nothing else: the two sides have different initials in four of the five
	-- languages Family supports, and a filter labelled in a language the player is not
	-- running is a filter nobody presses. The banners say it in none of them.
	local FACTION_BANNER = {
		Alliance = "Interface\\Icons\\INV_BannerPVP_02",
		Horde    = "Interface\\Icons\\INV_BannerPVP_01",
	}

	local factionButtons = {}
	for index, faction in ipairs(FACTIONS) do
		local button = CreateFrame("Button", nil, chooser, "UIPanelButtonTemplate")
		button:SetSize(28, 20)
		button:SetPoint("RIGHT", -(#FACTIONS - index) * 30, 0)

		button.banner = button:CreateTexture(nil, "ARTWORK")
		button.banner:SetSize(16, 16)
		button.banner:SetPoint("CENTER")
		button.banner:SetTexture(FACTION_BANNER[faction])

		-- The game's own word for the side, since the button no longer says it. Nobody
		-- should have to learn which banner is which by pressing one and watching rows
		-- disappear.
		UI:AttachTooltip(button, function()
			return nil, nil, { { UI:SideName(faction),
				factionShown(faction) and "|cff40bf40shown|r" or "|cff9d9d9dhidden|r" } }
		end)

		button:SetScript("OnClick", function()
			FamilyDB.ui = FamilyDB.ui or {}
			FamilyDB.ui.factions = FamilyDB.ui.factions or {}
			FamilyDB.ui.factions[faction] = not factionShown(faction)
			frame:Refresh()
		end)
		factionButtons[faction] = button
	end

	function frame:Refresh()
		local columns = columnsOf(currentSet)
		local realms, byRealm, totals, siblings = gather()

		-- The set being shown is the one you cannot click, which is how the tab strip
		-- already says the same thing.
		for id, button in pairs(setButtons) do
			UI:MarkSelected(button, id == currentSet.id)
		end

		-- Greyed out when that side is filtered away, which is how the game says "this is
		-- off" about a picture. MarkSelected does the highlight; this does the banner.
		for faction, button in pairs(factionButtons) do
			local shown = factionShown(faction)
			UI:MarkSelected(button, shown)
			if button.banner.SetDesaturated then
				button.banner:SetDesaturated(not shown)
			end
			button.banner:SetAlpha(shown and 1 or 0.4)
		end

		layOut(headerCells, columns)
		for index = 1, MAX_CELLS do
			headerCells[index]:SetText(columns[index] and columns[index].label or "")
		end

		local used = 0
		local y = 0

		-- Before any row is anchored to it, not after: a row anchored to a scroll child
		-- that is still one pixel wide has no width of its own.
		list:SetWidth(scroll:GetWidth())

		-- Which column the cursor is over, so a click on a profession opens that
		-- profession rather than merely that member. Everything is divided by the
		-- effective scale because the cursor is reported in screen pixels and a frame is
		-- not - the same arithmetic the minimap button does for the same reason.
		local function columnUnderCursor(row)
			local left = row.GetLeft and row:GetLeft()
			if not left then return nil end

			local scale = row:GetEffectiveScale()
			if not scale or scale == 0 then scale = 1 end

			local offset = (GetCursorPosition() / scale) - left
			local edge = 0

			for index, column in ipairs(columns) do
				if offset >= edge and offset < edge + column.width then return index end
				edge = edge + column.width
			end

			return nil
		end

		-- The profession each cell of a member's first line is showing, by cell number, so
		-- a click can say which one it landed on.
		local function professionsIn(meta)
			local names = {}
			local primaries = skillsOf(meta, false)
			names[2] = primaries[1] and primaries[1].name or nil
			names[3] = primaries[2] and primaries[2].name or nil
			return names
		end

		local function openProfession(row)
			local index = columnUnderCursor(row)
			local profession = index and row.professions and row.professions[index]
			UI:ShowProfessionFor(row.memberKey, profession)
		end

		local function nextRow()
			used = used + 1
			local row = rows[used]
			if not row then
				row = makeRow(list)
				rows[used] = row
			end
			row.opens = nil
			-- Wiped here rather than by each caller. A row that is shown but not written
			-- keeps whatever it last said, which is how a blank spacer came to be drawn as
			-- a second "total" line - with the money and played figures of the column set
			-- that had been on screen before it.
			row.memberKey, row.memberName, row.memberRealm = nil, nil, nil
			row.borrowed = nil
			layOut(row.cells, columns)
			for index = 1, MAX_CELLS do setCell(row, index, "") end
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetPoint("TOPRIGHT", 0, -y)
			row:Show()
			y = y + ROW_HEIGHT
			return row
		end

		-- Which column the first total lands in, or nothing at all when none of this set
		-- adds up. Professions and races do not have totals, and a row of blank cells under
		-- a heading called "total" is worse than no row.
		local firstTotal
		for index, column in ipairs(columns) do
			if TOTAL[column.key] then
				firstTotal = index
				break
			end
		end

		-- A totals line under a group of members, filling only the columns that add up.
		--
		-- The label goes immediately to the left of the first figure rather than out in the
		-- member column, where it sat a screen's width away from the thing it was labelling.
		local function totalsRow(label, members, r, g, b)
			if not firstTotal then return end

			local total = nextRow()
			setCell(total, math.max(firstTotal - 1, 1), label, r or 0.55, g or 0.55,
				b or 0.55)

			for index, column in ipairs(columns) do
				local add = TOTAL[column.key]
				if add then setCell(total, index, add(members), r, g, b) end
			end
		end

		-- One member, on whichever line it has reached. Written once and called twice: our
		-- own members and a linked family's siblings are drawn identically on purpose, and a
		-- second copy of this that drifted from the first would be exactly the bug that
		-- makes a sibling look like a different kind of thing (§6).
		local function drawMember(member, isSibling)
			local row = nextRow()
			row.memberKey = member.key
			row.memberName = member.meta.name or member.key
			row.memberRealm = member.meta.realm
			-- So the right-click does not offer to delete somebody who is not ours to
			-- delete. What we hold of them is theirs, and it goes when they stop sharing
			-- it or when the link ends.
			row.borrowed = isSibling and true or false

			for index, column in ipairs(columns) do
				-- Called rather than folded into an and/or, because a cell returns
				-- its colour alongside its text and that would keep only the text.
				local produce = CELL[column.key]
				if produce then
					-- member.seen is the stamp the exchange put on a borrowed member and
					-- is nil for our own, whose cells do not read it.
					setCell(row, index, produce(member.meta, member.key, member.seen))
				else
					setCell(row, index, "")
				end
			end

			-- A sibling's name lines up with our own members' names, and their family's
			-- name lines up with the realm's, so the table has two levels rather than
			-- four. They were indented a step further in on the reasoning that a sibling
			-- sits inside its family heading - but the eye reads a column, and a name that
			-- starts further right than every other name reads as a different kind of
			-- thing, which is the one impression §6 asks this table not to give.
			if isSibling then
				setCell(row, 1, "  " .. (member.meta.name or member.key),
					UI:ClassColour(member.meta.classFile))
			end

			-- Clicking a profession opens it, on that member, in the panel that is
			-- about professions. Which profession is worked out from where the
			-- cursor was, so the answer is the one that was clicked rather than
			-- whichever happens to come first.
			if currentSet.id == "professions" then
				row.professions = professionsIn(member.meta)
				row.opens = openProfession
			end

			-- The lines below, on the same grid, with the member column left empty:
			-- the name has been said and saying it again would make two members of
			-- one. A member with nothing to put there gets no extra line.
			local secondaries = skillsOf(member.meta, true)
			local drawn = 0

			for _, line in ipairs(currentSet.extra and currentSet.extra(member.meta,
				member.key) or {}) do
				local extra = nextRow()
				extra.memberKey = member.key
				extra.memberName = member.meta.name or member.key
				extra.memberRealm = member.meta.realm
				extra.borrowed = row.borrowed

				for index, text in ipairs(line) do
					setCell(extra, index + 1, text)
				end

				-- The same click, for the same reason: these are professions too.
				if currentSet.id == "professions" then
					local names = {}
					for index = 1, #line do
						local entry = secondaries[drawn + index]
						names[index + 1] = entry and entry.name or nil
					end
					extra.professions = names
					extra.opens = openProfession
				end

				drawn = drawn + #line
			end
		end

		for _, realm in ipairs(realms) do
			local heading = nextRow()
			for index = 1, MAX_CELLS do setCell(heading, index, "") end

			-- A heading is one line of text, not a row of cells, so its first cell is
			-- widened to the whole row and told not to wrap.
			--
			-- Left at the Member column's width, "Hydraxian Waterlords  (2)" did not fit
			-- and the count wrapped onto a line of its own underneath, where it read as a
			-- member of the realm called "(2)" - and pushed every row below it half a line
			-- out of step with the header.
			local title = heading.cells[1]
			title:SetWidth(math.max(list:GetWidth() - 8, 1))
			if title.SetWordWrap then title:SetWordWrap(false) end

			-- The count goes in the realm's own cell. Put in the next one along it read
			-- as a value under whatever column happened to be second, which on the
			-- activity set meant a realm appearing to have two pieces of mail.
			local here = siblings[realm]

			-- The count is our own members, and the siblings said separately rather than
			-- added in. "(4 + 2)" is two facts; "(6)" is one fact that is not true of
			-- anything - there is no family of six here.
			setCell(heading, 1, string.format("%s  |cff888888(%d%s)|r",
				realm, #byRealm[realm],
				(here and here.count > 0) and string.format(" + %d", here.count) or ""),
				0.6, 0.8, 1)

			------------------------------------------------------------------------------
			-- Our own, split by side where there is a split to make
			--
			-- Two characters on one realm on opposite sides have less to do with each other
			-- than two on different realms on the same side: different auction house,
			-- different mail, different everything this table is asked about. So a realm
			-- holding both is two groups with a subtotal each, and the money on each line
			-- is money that can actually reach the others on it.
			--
			-- And where there is no split - one side on this realm, or one side filtered
			-- away - none of that is drawn. A heading over every member of the realm and a
			-- subtotal identical to the realm's own total are two rows that say nothing,
			-- and the table is long enough already.
			------------------------------------------------------------------------------

			local bySide, sides = {}, {}
			for _, member in ipairs(byRealm[realm]) do
				local side = member.meta.faction or UNKNOWN_SIDE
				if not bySide[side] then
					bySide[side] = {}
					sides[#sides + 1] = side
				end
				tinsert(bySide[side], member)
			end

			-- Alliance, then Horde, then anybody whose side was never recorded.
			table.sort(sides, function(a, b)
				return (SIDE_ORDER[a] or 99) < (SIDE_ORDER[b] or 99)
			end)

			-- Whether there is a split to make is decided by the *known* sides alone. A
			-- member whose side was never recorded is not a third faction; they are a
			-- member Family has not finished reading, and letting them force the division
			-- would put a heading and a subtotal over a realm that has only one side on it
			-- because one character has not been logged into yet.
			local known = 0
			for _, side in ipairs(sides) do
				if side ~= UNKNOWN_SIDE then known = known + 1 end
			end

			if known > 1 then
				for position, side in ipairs(sides) do
					-- A line's space between one side and the next. Without it the
					-- second side's heading sits directly under the first side's
					-- subtotal, one row apart from figures it has nothing to do
					-- with, and the two groups read as one long list with a stray
					-- line of numbers through the middle of it.
					if position > 1 then nextRow() end

					local sideHeading = nextRow()
					for index = 1, MAX_CELLS do setCell(sideHeading, index, "") end

					local sideTitle = sideHeading.cells[1]
					sideTitle:SetWidth(math.max(list:GetWidth() - 8, 1))
					if sideTitle.SetWordWrap then sideTitle:SetWordWrap(false) end

					local colour = SIDE_COLOUR[side] or { 0.8, 0.8, 0.8 }
					setCell(sideHeading, 1, string.format("   %s  |cff888888(%d)|r",
						UI:SideName(side),
						#bySide[side]), colour[1], colour[2], colour[3])

					for _, member in ipairs(bySide[side]) do
						drawMember(member)
					end

					totalsRow(UI:SideName(side),
						bySide[side], colour[1] * 0.8, colour[2] * 0.8, colour[3] * 0.8)
				end
			else
				for _, member in ipairs(byRealm[realm]) do
					drawMember(member)
				end
			end

			-- Then, under this realm and after our own, one sub-section per linked family
			-- that has a sibling here (§6). Under the realm because the realm is the fact
			-- that decides whether two characters can hand each other anything; under the
			-- family because whose they are is never merged away.
			if here then
				-- A line's space first, so a linked family does not run straight on from
				-- the last of our own members as though it were one more of them.
				nextRow()

				for _, group in ipairs(here.order) do
					local sub = nextRow()
					for index = 1, MAX_CELLS do setCell(sub, index, "") end

					local label = sub.cells[1]
					label:SetWidth(math.max(list:GetWidth() - 8, 1))
					if label.SetWordWrap then label:SetWordWrap(false) end

					setCell(sub, 1, string.format("%s  |cff888888(%d)|r",
						group.name, #group.members), 0.78, 0.68, 0.95)

					for _, member in ipairs(group.members) do
						drawMember(member, true)
					end
				end
			end

			-- Under its own members rather than beside the realm name, so the figures sit
			-- in the columns they are totals of, and with a line's space after it so the
			-- next realm does not run straight on from this one's figures.
			-- Only where there is something of ours to add up. A realm we reach solely
			-- through a sibling would otherwise get a totals line of noughts, which reads
			-- as "your characters here have nothing" rather than "you have none here".
			if #byRealm[realm] > 0 then
				-- Where the realm was split by side, its own total lands directly
				-- under the last side's subtotal, in the same columns and one row
				-- down - which is where a reader expects one more side, not the line
				-- that adds the sides together. A line's space is the difference.
				-- Only where a total is actually drawn: the sets with nothing to add
				-- up would otherwise get a blank on top of the blank that ends every
				-- realm.
				if known > 1 and firstTotal then nextRow() end

				totalsRow("Total", byRealm[realm])
			end

			-- A blank line after every realm, whether or not it had anything to total.
			-- Tied to the totals it was written for, the sets with nothing to add up -
			-- professions, and the miscellaneous columns - had their realms running
			-- straight into one another.
			nextRow()
		end

		-- Only where there is more than one realm to add up. With one, the grand total is
		-- the realm total written twice.
		if #realms > 1 then
			-- Set apart from the last realm's own figures, which are the numbers it is
			-- most easily mistaken for.
			nextRow()

			local everyone = {}
			for _, realm in ipairs(realms) do
				for _, member in ipairs(byRealm[realm]) do
					everyone[#everyone + 1] = member
				end
			end

			totalsRow("Grand totals", everyone, 1, 0.82, 0)
		end

		for index = used + 1, #rows do
			rows[index]:Hide()
		end

		list:SetHeight(math.max(y, 1))

		-- The one thing about these numbers that is not obvious from them. A quiver, a soul
		-- bag or an enchanting bag has slots and none of them are room for anything else, so
		-- they are left out of every figure here - and the panel that shows what is actually
		-- in them does not leave them out, which would be a different mistake.
		if currentSet.id == "professions" then
			note:SetText("|cff888888Primary professions on the first line of each member, "
				.. "everything else on the second. A profession in grey has recipes "
				.. "Family has not seen for a week, or has never seen: ranks are always "
				.. "current, recipe lists are only as new as the last time that window "
				.. "was open.|r")
		elseif currentSet.id == "bags" then
			note:SetText("|cff888888Free and total slots leave out quivers, soul bags and "
				.. "the like: their slots are not room for anything else. Possessions "
				.. "shows them all the same.|r")
		elseif currentSet.id == "crafting" then
			note:SetText(string.format("|cff888888Crafting cooldowns only - transmutes, "
				.. "mooncloth, salt shakers. A column appears once Family has seen that "
				.. "cooldown running at least once, because the client will not say a "
				.. "recipe has one while it is ready. Blank means never seen it, which is "
				.. "not the same as nought.%s|r",
				craftingOmitted > 0
					and string.format(" |cffffaa00%d more not shown - there is only so "
						.. "much room in a row.|r|cff888888", craftingOmitted)
					or ""))
		elseif currentSet.id == "currencies" then
			-- The columns are whatever the family holds most of, so the panel has to say
			-- that: five columns out of twelve currencies is not the same claim as five
			-- columns out of five, and they look identical.
			note:SetText(string.format("|cff888888The currencies this family holds most "
				.. "of, most first.%s Character shows one member's in full, with what "
				.. "each is capped at.|r",
				currenciesOmitted > 0
					and string.format(" |cffffaa00%d more not shown - there is only so "
						.. "much room in a row.|r|cff888888", currenciesOmitted)
					or ""))
		else
			note:SetText("")
		end

		if totals.members == 0 and not (factionShown("Alliance") or factionShown("Horde")) then
			footer:SetText("|cffffaa00Both sides are switched off.|r |cff888888Turn one back "
				.. "on with the buttons at the end of the row above.|r")
		elseif totals.members == 0 then
			footer:SetText("|cff9d9d9dNothing recorded yet. Family fills as you play each " ..
				"member - log in on one and its bags and money are written down.|r")
		else
			footer:SetText(string.format(
				"|cffffd700Grand totals:|r  %d member%s   |cff888888|||r   %s   " ..
				"|cff888888|||r   %d of %d bag slots free   |cff888888|||r   " ..
				"|cff888888right-click a member to remove them|r",
				totals.members, totals.members == 1 and "" or "s",
				UI:Money(totals.money), totals.free, totals.slots))
		end
	end
end

UI:RegisterTab("summary", "Summary", build)
