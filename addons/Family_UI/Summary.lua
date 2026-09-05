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
local L = Family.L

local ROW_HEIGHT = 18

-- A letter's own line, which is taller than a row of figures because it carries pictures.
-- Twelve is what a letter can hold, and an icon small enough to fit an eighteen-pixel row is
-- an icon nobody can recognise - which is the whole reason for showing one rather than a
-- count.
local LETTER_HEIGHT = 26
-- A boon's contents get one line and no more: twelve icons in a row, which is the most a
-- Chronoboon can hold (DATASOURCES §2), each with the game's own tooltip on it.
local BOON_ICON = 22
local BOON_SLOTS = 12

local LETTER_ICON = 22
local LETTER_SLOTS = 12
local HEADER_HEIGHT = 22

-- The filter row. Twenty-four is the height of the boxes in it plus the two pixels that keep
-- a box's border off the heading below; it comes out of the scroll area, which is one row of
-- forty fewer on screen and the trade the filters are for.
local FILTER_HEIGHT = 24

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
local MEMBER_COLUMN = { key = "name", label = L["Member"], width = 130, justify = "LEFT" }

-- Declared before the sets, which use them, and defined below with everything else that
-- turns a record into a piece of text. Written the other way round, the professions set
-- captured a global that never got set and the panel died the first time it was drawn.
local skillsOf, skillText

-- Built further down, where the cells they have to register alongside are. Declared here
-- because the sets below are written first and would otherwise capture a global that never
-- arrives.
local currencyColumns, craftingColumns

-- A profession as one thing, however it was filed.
--
-- Records written before skill line ids were used are keyed by the profession's name, in the
-- language of the client that read it; newer ones are keyed by the id. Both name one
-- profession, and a picker that offered them separately would offer the same word twice and
-- narrow to half a family each time.
local function professionID(id)
	if type(id) == "string" then return Family:SkillLineFor(id) or id end
	return id
end

local SETS = {
	{
		id = "overview", label = L["Overview"],
		columns = {
			{ key = "level",  label = L["Level"],     width = 50,  justify = "RIGHT" },
			{ key = "ilvl",   label = L["Item lvl"],  width = 70,  justify = "RIGHT" },
			{ key = "xp",     label = L["Rest XP"],   width = 90,  justify = "RIGHT" },
			{ key = "money",  label = L["Money"],     width = 145, justify = "RIGHT" },
			{ key = "played", label = L["Played"],    width = 85,  justify = "RIGHT" },
			{ key = "seen",   label = L["Last seen"], width = 95,  justify = "RIGHT" },
		},
	},
	{
		id = "bags", label = L["Bags"],
		columns = {
			{ key = "bagfree",  label = L["Free bags"],  width = 90, justify = "RIGHT" },
			{ key = "bagtotal", label = L["Bag slots"],  width = 90, justify = "RIGHT" },
			{ key = "bankfree", label = L["Free bank"],  width = 90, justify = "RIGHT" },
			{ key = "banktotal",label = L["Bank slots"], width = 90, justify = "RIGHT" },
			{ key = "bankseen", label = L["Bank seen"],  width = 100, justify = "RIGHT" },
			-- Bags are live, but only for a member who has been played: this says how
			-- old "live" is for each of them.
			{ key = "bagseen",  label = L["Bags seen"], width = 100, justify = "RIGHT" },
		},
	},
	{
		id = "activity", label = L["Activity"],
		-- The widest set there is, and it has to fit: there is no sideways scrolling, so a
		-- column past the edge is a column nobody can read. These add up to the width of
		-- the panel with the member column, and should stay that way.
		columns = {
			-- Wide enough for "not seen", which is what these say far more often than
			-- they say a number. At fifty it broke across two lines and drew over the
			-- member underneath.
			--
			-- The money columns are the slack in this row: "4085g 87s 01c" is the widest
			-- sum anybody in a test family has and it is not a hundred and five pixels
			-- wide. What that slack bought is a column for the mail in post, which used
			-- to be a phrase inside the mail column and was truncated in every language
			-- including English.
			-- Each of these is at the width its own contents need, not at a round
			-- number: "not seen" is fifty-two pixels and is what half of them say most
			-- of the time, a money column has to hold four figures of gold, and a date
			-- column has to hold "il y a 19j" as well as "19d ago".
			{ key = "mail",     label = L["Mail"],       width = 61,  justify = "RIGHT" },
			{ key = "inpost",   label = L["In post"],    width = 60,  justify = "RIGHT" },
			{ key = "mailexp",  label = L["Expires in"], width = 67,  justify = "RIGHT" },
			{ key = "mailseen", label = L["Mail seen"],  width = 75,  justify = "RIGHT" },
			{ key = "auctions", label = L["Auctions"],   width = 61,  justify = "RIGHT" },
			{ key = "bids",     label = L["Bid value"],  width = 93,  justify = "RIGHT" },
			{ key = "buyouts",  label = L["Buyout"],     width = 93,  justify = "RIGHT" },
			{ key = "aucseen",  label = L["AH seen"],    width = 74,  justify = "RIGHT" },
		},
	},
	{
		id = "professions", label = L["Professions"],

		-- **Which profession**, which is a narrowing this set owns rather than one the
		-- member filters beside it can express. *Who are the blacksmiths* is a question
		-- about a column; name, class and level are questions about a member. Asked from
		-- play 2026-09-05.
		--
		-- By skill line id and never by the word. The same profession is recorded in
		-- whatever language the client that read it was set to, so two members can hold one
		-- profession under two spellings - the fault L-015 is about - and an older record is
		-- filed under the word itself. `Family:SkillLineFor` turns that word back into the
		-- id, so both are one choice, and `Family:ProfessionName` puts the reader's own
		-- language on the label.
		narrow = {
			label = L["Profession"],

			-- Only what the family actually has, which is the rule every picker in Family
			-- follows: offering blacksmithing to a family with no blacksmith is offering a
			-- way to show nothing.
			choices = function()
				local seen, list = {}, {}
				for _, entry in pairs(Family.Database:Members()) do
					for _, secondary in ipairs({ false, true }) do
						for _, held in ipairs(skillsOf(entry.meta or {}, secondary)) do
							local id = professionID(held.id)
							if id ~= nil and not seen[id] then
								seen[id] = true
								list[#list + 1] = { value = id, label = held.name }
							end
						end
					end
				end
				table.sort(list, function(a, b) return a.label < b.label end)
				return list
			end,

			-- Walked rather than looked up, because the key a record is filed under is not
			-- always the key the picker offers: one of them may be a word.
			passes = function(meta, wanted)
				for id, skill in pairs((meta or {}).skills or {}) do
					if not skill.class and professionID(id) == wanted then return true end
				end
				return false
			end,
		},

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
			-- Headed once, and not "Primary". The two primaries are on a member's first
			-- line and everything else is on the second, so a column headed Primary is
			-- telling the truth about half of what is under it - which is worse than
			-- saying nothing, because the note below already explains the arrangement.
			{ key = "prof1",  label = L["Professions"], width = 194, justify = "LEFT" },
			{ key = "prof2",  label = "",               width = 194, justify = "LEFT" },
			{ key = "",       label = "",               width = 194, justify = "LEFT" },
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
		id = "currencies", label = L["Currencies"],
		columns = {},
		build = function() return currencyColumns() end,
	},
	{
		-- Built from what the family actually has cooldowns for, the same way Currencies is
		-- and for the same reason: which cooldowns exist depends on which professions this
		-- family took, and a fixed set of columns would be Alchemy and Tailoring for
		-- everybody, empty for most of them.
		id = "crafting", label = L["Crafting"],
		columns = {},
		build = function() return craftingColumns() end,
		-- Only the members who have one. Everybody else is a blank row on a panel whose
		-- every column is about waiting for something.
		-- Counted, not named: this only asks *whether* there are any, and asking the client
		-- for names it has not loaded would redraw the panel to answer a question about how
		-- many rows it has, which redraws it again.
		only = function(meta) return #Family.Cooldowns:Crafting(meta) > 0 end,
	},
	{
		id = "misc", label = L["Miscellaneous"],
		columns = {
			{ key = "guild",  label = L["Guild"],       width = 160, justify = "LEFT" },
			{ key = "hearth", label = L["Hearthstone"], width = 170, justify = "LEFT" },
			{ key = "race",   label = L["Race"],        width = 100, justify = "LEFT" },
			{ key = "class",  label = L["Class"],       width = 110, justify = "LEFT" },
			-- World buffs banked in a Chronoboon, beside the other per-character facts
			-- about a thing somebody is carrying. Forty pixels, which is what this set had
			-- left of ROW_BUDGET and is more than a small number needs.
			--
			-- **Deliberately not added up.** Miscellaneous is a set where nothing adds up,
			-- and a set where nothing adds up is given no totals line at all - a rule that
			-- exists because a blank one under the professions kept whatever the previous
			-- set had left in those cells. A family-wide count of banked buffs would be
			-- mildly interesting and would put a new row on a panel nobody asked to change,
			-- to answer a question this column is not for: what is wanted here is *who*.
			--
			-- The heading is a **stem of the game's own word**, not the English nickname.
			-- Forty pixels carries no language's full name for it - `Chronoboon Displacer`,
			-- `Déplaceur de chronochance`, `Chronostärkungsversetzer`, `Reubicador
			-- cronológico`, `Темпоральный манипулятор` - and four of those five share one.
			-- "Boon" is what English players say and appears in nobody else's item at all,
			-- which is §2.1's argument applied to a column heading.
			{ key = "boon",   label = L["Chrono"],      width = 40,  justify = "RIGHT" },
		},
	},
}

-- What a row actually has: the window, less the tab strip down the side, less the scroll bar
-- and the margins. Kept as a number here so the check below can be made rather than assumed.
-- The space under the table: a margin below the footer, a gap between the footer and the
-- note above it, and a clear line between the whole block and the last row of the table.
-- How tall the block itself is, is not a constant - it is measured, because two lines of
-- French where English fits one is the ordinary case rather than the exceptional one.
local FOOTER_MARGIN = 8
local CAPTION_GAP = 4
local TABLE_GAP = 8

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
			Family:Print(L["|cffffaa00the %s columns add up to %d, wider than the %d a row "
				.. "has|r"], set.label, width, ROW_BUDGET)
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
	Family:Print(L["|cffffaa00%d column sets leave %d pixels each across the top, and a label "
		.. "needs %d|r"], #SETS, SET_BUTTON_WIDTH, SET_BUTTON_MINIMUM)
end

local currentSet = SETS[1]

-- Whose letters are open, by member key, or nothing. One at a time: a table with every
-- member's post unfolded is a table nobody can read, and the question is always about one
-- character.
local openMail

-- And whose boon is open, kept apart from the letters so that opening one does not shut the
-- other: they are different questions about the same character and both fit on the screen.
local openBoon

-- Both of them put away with everything else. They close on a second click of the same row,
-- which is what a drill-down does everywhere in Family - and they were surviving the window
-- closing, which is the half that was reported about the factions and is the same fault here.
UI:OnFold("summary", function()
	openMail, openBoon = nil, nil
end)

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
local NOT_SEEN = L["|cff9d9d9dnot seen|r"]

function skillsOf(meta, secondary)
	local found = {}
	-- Filed by skill line id; shown in the language of whoever is reading, which is not
	-- necessarily the language it was recorded in.
	for id, skill in pairs(meta.skills or {}) do
		-- A class skill is in neither list, and that is a decision rather than an
		-- oversight. Lockpicking has a rank and a maximum and reads exactly like a
		-- profession from here - it was drawn on the "everything else" line for an hour,
		-- beside cooking and fishing, until Alberto pointed out that it is technically an
		-- ability. A rogue would have had three secondary professions, one of which cannot
		-- be trained, abandoned or chosen. It is on the abilities panel instead, where an
		-- ability goes.
		if not skill.class and (skill.secondary or false) == secondary then
			found[#found + 1] = {
				name = Family:ProfessionName(id, skill.name), id = id, skill = skill,
			}
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

	if days > 0 then return string.format(L["%dd %dh"], days, hours) end
	if hours > 0 then return string.format(L["%dh %dm"], hours, minutes) end
	return string.format(L["%dm"], minutes)
end

-- What is left on a banked buff, short enough to sit in the corner of a 22-pixel icon.
--
-- Whole hours as hours, because a world buff is two hours or one and "2h" is what a player
-- would say; anything else in minutes, because "1h 45m" does not fit and rounding it to "1h"
-- would be Family stating something untrue about a number it was given exactly.
local function boonLeft(minutes)
	if minutes >= 60 and minutes % 60 == 0 then
		return string.format(L["%dh"], minutes / 60)
	end
	return string.format(L["%dm"], minutes)
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

-- Two facts, and they were one column until they would not fit in it.
--
-- Letters watched being posted are the one thing in this table known from the other end -
-- somebody sent them, nobody has yet seen them in a mailbox (§5) - so they cannot be folded
-- in silently: that would claim a mailbox had been looked at when it had not. Said in the
-- same cell they read "1 (1 in post)", which is fourteen characters of a sixty-five pixel
-- column in English and "1 (1 en el correo)" in Spanish, and what a player actually saw was
-- "1 (1 in p...".
--
-- Two columns of one number each fit in any language, because neither of them holds a word.
CELL.mail = function(meta)
	if not meta.mailSeen then return NOT_SEEN end
	return tostring(meta.mailCount or 0)
end

-- Gold, because it is the column that says something is coming. Nothing on the way is a
-- dash rather than a nought, so the eye passes over the rows with nothing to say - and it
-- does not depend on a mailbox having been seen, because this is the half that is known
-- without one.
CELL.inpost = function(meta)
	local inPost = Family.Mail:InPost(meta)
	if inPost <= 0 then return UNKNOWN end
	return string.format("|cffffd700%d|r", inPost)
end

CELL.mailseen = function(meta)
	if not meta.mailSeen then return UNKNOWN end
	return UI:Ago(meta.mailSeen), 0.7, 0.7, 0.7
end

-- The one number on this screen worth reacting to, so it is the one that goes red. Mail
-- that expires takes its attachments with it.
-- One letter, in a line. Who it is from, what it is called, and what is attached to it -
-- which is the whole of what the mailbox itself shows before you open one.
--
-- The subject is what a player recognises a letter by; the sender is what they decide by. So
-- both, sender first, and the attachments counted rather than listed: a letter with nine
-- stacks in it is one line here and nine lines is a screen nobody asked for.
local function describeLetter(letter)
	local parts = { tostring(letter.sender or "?") }

	if letter.subject and letter.subject ~= "" then
		parts[#parts + 1] = "|cff9d9d9d" .. letter.subject .. "|r"
	end

	return table.concat(parts, "  ")
end

-- The gold on a letter, and what it costs to take it.
--
-- Cash on delivery is the one thing on a letter that takes rather than gives, so it is said
-- in red and on its own: opening one by mistake is a real loss, and it must not read like the
-- money that is being sent to you.
local function letterMoney(letter)
	if (letter.cod or 0) > 0 then
		return string.format(L["|cffff4444C.O.D. %s|r"], UI:Money(letter.cod))
	end
	if (letter.money or 0) > 0 then return UI:Money(letter.money) end
	return nil
end

CELL.mailexp = function(meta)
	local remaining = Family.Mail:TimeToExpiry(meta)
	if not remaining then return UNKNOWN end
	if remaining <= 0 then return L["|cffff4444gone|r"] end

	local text = duration(remaining) or L["soon"]
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
		return string.format(L["|cff888888shared|r %s"], UI:Ago(sharedAt)), 0.7, 0.7, 0.7
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
	if not meta.xpMax then return L["|cff9d9d9dmax level|r"] end
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

-- A name, blank for somebody the client said is in no guild, and a dash for everybody else.
--
-- Three answers rather than two. A nil guild used to draw a dash whatever caused it, so a
-- character in no guild looked exactly like one nobody has ever scanned - and the second is a
-- gap Family should be honest about while the first is simply the truth about them. What
-- separates them is `guildless`, which the identity scan writes only where the client answered
-- outright; where it would not say, both stay a dash, which is the honest answer to a question
-- nobody got a reply to.
CELL.guild = function(meta)
	if meta.guild then return meta.guild end
	if meta.guildless then return "" end
	return UNKNOWN
end
-- Named from the id where there is one, so a member recorded on a French Era client reads
-- "Forgefer" on a French Burning Crusade one instead of "Ironforge". Falls back to the word
-- that was recorded, which is what a member carries until somebody next logs into them.
CELL.hearth = function(meta)
	return Family.Names:Area(meta.hearthID, meta.hearth) or UNKNOWN
end
CELL.race = function(meta) return UI:RaceName(meta) end

-- How many world buffs this character has banked, which is how many Supercharged Chronoboon
-- Displacers are in their bags (Scanners/Bags.lua).
--
-- **Three answers, not two.** Nothing banked and never looked are different facts and §2.2 is
-- the whole of why: a character whose bags have never been read has no answer here, and drawing
-- a blank for them would say "none" about somebody nobody has asked. `bagsSeen` is what tells
-- the two apart, and it is set by the same scan that would have counted a boon.
-- How many world buffs are trapped, which is the question somebody is actually asking. It
-- used to be how many boons were carried, and that number could only ever be one.
--
-- A boon whose contents were never read answers *unknown* rather than a number, because the
-- column asks one question and "there is a boon" is not an answer to it. That happens to a
-- character recorded before Family could read them, and it fills in the next time they are
-- played - and it is not clickable meanwhile, which is the same dash meaning the same thing
-- everywhere else on this panel.
CELL.boon = function(meta)
	if not meta.bagsSeen then return UNKNOWN end
	if meta.banked then return tostring(#meta.banked) end
	if meta.boons then return UNKNOWN end
	return ""
end

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

-- What each column is worth when the table is put in its order.
--
-- A cell's *text* is not it: "3g 40s 12c" sorts before "12g" as a string, and "not seen" sorts
-- among the dates. So a column that can be ordered says which number or word it is made of,
-- and one that says nothing here cannot be sorted by - which is the honest answer for the
-- professions columns, where a member's two primaries are not a value at all.
--
-- **Nothing is invented for what was never recorded.** A member whose money Family has never
-- read is not a member with no money (§2.2), so `nil` comes back and the comparison below puts
-- them last whichever way the column is pointing - never first in ascending order, which is
-- where a nought would put them and where they would look like the poorest character in the
-- family rather than the one nobody has logged in on.
local SORT = {
	name      = function(meta) return meta.name end,
	level     = function(meta) return meta.level end,
	ilvl      = function(meta) return meta.itemLevel end,
	xp        = function(meta) return meta.rested end,
	money     = function(meta) return meta.money end,
	played    = function(meta) return meta.played end,
	seen      = function(meta) return meta.lastSeen end,
	bagfree   = function(meta) return meta.bagFree end,
	bagtotal  = function(meta) return meta.bagSlots end,
	bankfree  = function(meta) return meta.bankFree end,
	banktotal = function(meta) return meta.bankSlots end,
	bagseen   = function(meta) return meta.bagsSeen end,
	bankseen  = function(meta) return meta.bankSeen end,
	mail      = function(meta) return meta.mailCount end,
	inpost    = function(meta) return meta.mailInPost end,
	mailexp   = function(meta) return meta.mailExpiresBy end,
	mailseen  = function(meta) return meta.mailSeen end,
	aucseen   = function(meta) return meta.auctionsSeen end,
	guild     = function(meta) return meta.guild end,
	hearth    = function(meta) return meta.hearth end,

	-- The auction figures come out of the payload rather than out of meta, so they are
	-- worked out by the same function that draws them. Never seen stays nil and sorts last:
	-- a member whose auction house Family has never read has not got nothing on it.
	auctions  = function(meta, key)
		if not meta.auctionsSeen then return nil end
		return (select(1, auctionTotals(meta, key))) or 0
	end,
	bids      = function(meta, key)
		if not meta.auctionsSeen then return nil end
		return (select(2, auctionTotals(meta, key))) or 0
	end,
	buyouts   = function(meta, key)
		if not meta.auctionsSeen then return nil end
		return (select(3, auctionTotals(meta, key))) or 0
	end,

	-- The professions columns, by the word they show. A member's primaries are drawn
	-- alphabetically, so ordering by the first of them puts everybody with the same
	-- profession together - which is the useful half of "sort by profession" and is
	-- honestly what this column holds.
	--
	-- **Not** the other half of the original ask, which is *sorted by that profession's
	-- skill*: that needs somebody to say which profession first, and the control to say it
	-- with is the filter bar of slice three. A rank sorted here would be the rank of
	-- whichever profession happened to come first alphabetically, which answers nobody.
	prof1     = function(meta) return skillText(skillsOf(meta, false)[1]) end,
	prof2     = function(meta) return skillText(skillsOf(meta, false)[2]) end,

	-- How many world buffs are banked. Three answers as the cell has three: bags never read
	-- is nil, a Chronoboon carried whose contents are unknown is nil too - both are "no
	-- answer" rather than none - and everything else is a count.
	boon      = function(meta)
		if not meta.bagsSeen then return nil end
		if meta.banked then return #meta.banked end
		if meta.boons then return nil end
		return 0
	end,

	-- Both of these are stored as an identity and drawn in the reader's language, so they
	-- are ordered by **what the cell draws** rather than by the identity behind it: sorted
	-- on `classFile` a German reader would get Magier under M-for-MAGE, and sorted on the
	-- recorded word they would get whatever language the character was last read in.
	--
	-- Neither reaches for the record itself. `UI:RaceName` resolves the id into this
	-- client's language and is the accessor the cell uses, and the class names are the
	-- client's own table - which is why sorting these is possible at all, and why the first
	-- cut of this file left them out on the grounds that it was not.
	race      = function(meta) return UI:RaceName(meta) end,
	class     = function(meta)
		local names = _G.LOCALIZED_CLASS_NAMES_MALE
		return (names and meta.classFile and names[meta.classFile]) or meta.classFile
	end,
}

-- Which column a set is ordered by, and which way.
--
-- Remembered, unlike the filters beside it, and the reasoning does not carry across: a filter
-- left on hides rows, so a panel opened tomorrow showing four of forty looks broken. An order
-- hides nothing - every row is there, in a different sequence - and somebody who reads this
-- panel for money every morning should not have to say so every morning.
--
-- Per set, because the columns are per set: the order that makes sense of Activity means
-- nothing on Miscellaneous.
function UI:SummarySort(setID)
	local kept = FamilyDB and FamilyDB.ui and FamilyDB.ui.sort
	local chosen = kept and kept[setID]

	if type(chosen) ~= "table" or not SORT[chosen.key] then return nil end
	return chosen
end

function UI:SetSummarySort(setID, key)
	if not setID then return nil end

	FamilyDB.ui = FamilyDB.ui or {}
	FamilyDB.ui.sort = FamilyDB.ui.sort or {}

	local current = FamilyDB.ui.sort[setID]

	-- Clicking the column that is already chosen turns it round, and clicking it a third
	-- time puts the panel back to its own order. Three states rather than two, so that
	-- there is a way back to the default without knowing what the default was.
	if not SORT[key] then
		FamilyDB.ui.sort[setID] = nil
	elseif type(current) == "table" and current.key == key then
		if current.descending then
			FamilyDB.ui.sort[setID] = nil
		else
			FamilyDB.ui.sort[setID] = { key = key, descending = true }
		end
	else
		FamilyDB.ui.sort[setID] = { key = key, descending = false }
	end

	return FamilyDB.ui.sort[setID]
end

function UI:SummarySortable(key) return SORT[key] ~= nil end

local function byLevelThenName(a, b)
	local levelA, levelB = a.meta.level or 0, b.meta.level or 0
	if levelA ~= levelB then return levelA > levelB end
	return (a.meta.name or "") < (b.meta.name or "")
end

-- The order a set is read in: the column somebody chose, or the panel's own.
--
-- Within a group and never across one. The rows are grouped by realm and by side because those
-- are facts about what can be done with a character - a bank on one realm is not a bank on
-- another - and an order that broke the grouping would be sorting a table that no longer means
-- what its headings say.
--
-- Ties fall back to the panel's own order rather than to nothing, so that two members with the
-- same money are not in whichever sequence `pairs` handed them, which changes between draws.
local function orderFor(setID)
	local chosen = UI:SummarySort(setID)
	local value = chosen and SORT[chosen.key]
	if not value then return byLevelThenName end

	return function(a, b)
		local left, right = value(a.meta or {}, a.key), value(b.meta or {}, b.key)

		if left == right then return byLevelThenName(a, b) end

		-- Never recorded goes last whichever way the column points. Sorted as a nought it
		-- would head an ascending column and read as the poorest character in the family
		-- rather than the one nobody has logged in on (§2.2).
		if left == nil then return false end
		if right == nil then return true end

		if chosen.descending then return left > right end
		return left < right
	end
end

-- Siblings, arranged the way they are drawn: the realm they are on, and inside it the family
-- they belong to (§6).
--
-- Whose they are is never merged away, which is why they are grouped by family rather than
-- mixed in with our own members and marked somehow. A row that has to be inspected to find
-- out whose it is has already blurred the one line §6 exists to hold.
local function gatherSiblings(only, order)
	local byRealm = {}

	for _, member in ipairs(Family.Wide:Siblings()) do
		local meta = member.meta or {}
		if factionShown(meta.faction) and (not only or only(meta)) then
			local realm = meta.realm or L["Unknown realm"]
			local here = byRealm[realm]
			if not here then
				here = { families = {}, order = {}, count = 0 }
				byRealm[realm] = here
			end

			local group = here.families[member.family]
			if not group then
				group = { name = member.familyName or L["another family"], members = {} }
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
			table.sort(group.members, order or byLevelThenName)
		end
	end

	return byRealm
end

-- `only` narrows which members get a **row**, and nothing else.
--
-- The Crafting set uses it: a family of thirty with three alchemists was twenty-seven blank
-- lines and three with anything on them, which is a table nobody can read. Asked for from play.
--
-- The totals below are counted over everybody regardless, because the line under the window
-- says what the *family* has and that does not change because a column set is showing fewer
-- rows. A realm nobody passes the filter on gets no heading at all rather than an empty one.
local function gather(only, order)
	local byRealm, realms = {}, {}
	local totalMoney, totalFree, totalSlots, count = 0, 0, 0, 0

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta
		if meta and factionShown(meta.faction) then
			totalMoney = totalMoney + (meta.money or 0)
			totalFree = totalFree + (meta.bagFree or 0)
			totalSlots = totalSlots + (meta.bagSlots or 0)
			count = count + 1

			if not only or only(meta) then
				local realm = meta.realm or L["Unknown realm"]
				if not byRealm[realm] then
					byRealm[realm] = {}
					tinsert(realms, realm)
				end
				tinsert(byRealm[realm], { key = key, meta = meta })
			end
		end
	end

	-- A sibling can be on a realm where we have nobody at all, and that realm still has to
	-- have a heading for them to sit under. Nothing is added to the totals, here or below:
	-- the money on the totals line is this family's money, and adding somebody else's would
	-- produce a figure that describes nobody.
	local siblings = gatherSiblings(only, order)
	for realm in pairs(siblings) do
		if not byRealm[realm] then
			byRealm[realm] = {}
			tinsert(realms, realm)
		end
	end

	table.sort(realms)
	for _, members in pairs(byRealm) do
		table.sort(members, order or byLevelThenName)
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
			for _, kind in ipairs(Family.Cooldowns:Crafting(meta, "summary.crafting",
				function() UI:Refresh() end)) do
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
			for _, kind in ipairs(Family.Cooldowns:Crafting(meta, "summary.crafting",
				function() UI:Refresh() end)) do
				if kind.label == label then
					if kind.ready then
						return L["|cff40bf40ready|r"]
					end
					return string.format("|cff9d9d9d%s|r",
						duration(kind.readyAt - time()) or L["soon"])
				end
			end
			return ""
		end

		-- Written beside the cell, because a column built at draw time would otherwise be
		-- the one kind of column that cannot be ordered - and "who can make this soonest"
		-- is the question this whole set exists to answer.
		--
		-- Ready is nought, so ascending reads as soonest first and the ones who can do it
		-- now head the column. A member without that cooldown at all has no answer and
		-- sorts last, which is not the same as being ready.
		SORT[key] = function(meta)
			for _, kind in ipairs(Family.Cooldowns:Crafting(meta)) do
				if kind.label == label then
					return kind.ready and 0 or (kind.readyAt or 0)
				end
			end
			return nil
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

		-- The same distinction the cell makes, kept: never read is nil and sorts last,
		-- and a member who has been read and holds none is a nought that sorts as one.
		SORT[key] = function(meta)
			if not meta.currenciesSeen then return nil end
			local amount = currencyOf(meta, currency.key)
			return amount and amount.quantity or 0
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

	-- Something to click on the mail figure with. A cell is a font string and cannot take a
	-- click, so this sits over one - invisible, the width of that column, and shown only on
	-- the rows that have letters to show.
	row.mailHit = CreateFrame("Button", nil, row)
	row.mailHit:RegisterForClicks("LeftButtonUp")
	row.mailHit:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	row.mailHit:Hide()

	-- What is attached to a letter, as pictures rather than as a number: "2 items" says
	-- nothing anybody wanted to know, and the point of looking is to see what is there.
	--
	-- Buttons rather than plain textures so each one can say what it is on hover. An icon
	-- nobody can identify is decoration.
	row.attach = {}
	for index = 1, LETTER_SLOTS do
		local slot = CreateFrame("Button", nil, row)
		slot:SetSize(LETTER_ICON, LETTER_ICON)

		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetAllPoints()

		slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		slot.count:SetPoint("BOTTOMRIGHT", -1, 1)

		slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		UI:AttachTooltip(slot, function(self)
			if self.itemLink then return "itemlink", self.itemLink end
			if self.itemID then return "item", self.itemID end
			return nil
		end)

		slot:Hide()
		row.attach[index] = slot
	end

	-- The Chrono figure, made clickable the same way the mail figure is.
	row.boonHit = CreateFrame("Button", nil, row)
	row.boonHit:RegisterForClicks("LeftButtonUp")
	row.boonHit:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	row.boonHit:Hide()

	-- What is inside a boon, as the game's own pictures with the time left written on them.
	--
	-- The tooltip is the **spell's**, not anything Family wrote: what a world buff does is the
	-- game's to say, in the player's language, and a summary that paraphrased it would be one
	-- more thing to keep true. The recorded fileID is turned back into a spell through
	-- `Family.WorldBuffs`; a buff too new for that table still draws its own icon and simply
	-- has no tooltip, which is the honest answer rather than a wrong one.
	row.boon = {}
	for index = 1, BOON_SLOTS do
		local slot = CreateFrame("Button", nil, row)
		slot:SetSize(BOON_ICON, BOON_ICON)

		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetAllPoints()

		slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		slot.count:SetPoint("BOTTOMRIGHT", -1, 1)

		slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		UI:AttachTooltip(slot, function(self)
			if self.spellID then return "spell", self.spellID end
			return nil
		end)

		slot:Hide()
		row.boon[index] = slot
	end

	-- The gold in the letter, beside its attachments and never folded into the line of
	-- prose, where it was the first thing the column's width threw away.
	row.attachMoney = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	row.attachMoney:SetJustifyH("RIGHT")
	row.attachMoney:Hide()
	UI:NoWrap(row.attachMoney)

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
				Family:Print(L["|cff888888%s belongs to a linked family. Untick them as a "
					.. "sibling on the Wide Family panel to take them off this table.|r"],
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

-- English decided the column widths in the table above, and English is the shortest of the
-- five languages Family speaks. The widths are a starting point rather than a rule; the
-- work of widening them to hold their own headings is UI:FitColumns, in Window.lua, because
-- every panel with a row of headings has the same problem.
local measure

-- Places a row's cells for the set being shown, and hides the spare ones so a wide set
-- leaves nothing behind when a narrow one replaces it.
local function layOut(cells, columns)
	local x = 0
	for index = 1, MAX_CELLS do
		local cell, column = cells[index], columns[index]
		cell:ClearAllPoints()

		if column then
			local width = column.drawWidth or column.width
			-- Where this column ended up, so that something can be put over one of them.
			-- Worked out here rather than a second time somewhere else, because a width
			-- that two places compute is a width they will one day disagree about.
			column.drawX = x
			cell:SetPoint("LEFT", x + 4, 0)
			cell:SetWidth(width - 8)
			cell:SetJustifyH(column.justify)
			cell:Show()
			x = x + width
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

	-- The filters, on their own row.
	--
	-- Not in the chooser row above: that row is already two pixels short of its own labels in
	-- English, and the room at its right-hand end holds the two side buttons. A control that
	-- has to share a row nobody can widen is a control that overlaps something in the first
	-- language that needs an extra letter.
	local filters = CreateFrame("Frame", nil, chooser)
	filters:SetPoint("TOPLEFT", chooser, "BOTTOMLEFT", 0, -4)
	filters:SetPoint("TOPRIGHT", chooser, "BOTTOMRIGHT", 0, -4)
	filters:SetHeight(FILTER_HEIGHT)

	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", filters, "BOTTOMLEFT", 0, -2)
	header:SetPoint("TOPRIGHT", filters, "BOTTOMRIGHT", 0, -2)
	header:SetHeight(HEADER_HEIGHT)

	local headerCells = {}
	for index = 1, MAX_CELLS do
		local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		text:SetTextColor(1, 0.82, 0)
		headerCells[index] = text
	end

	-- One button over each heading, invisible, for choosing the order.
	--
	-- Over rather than instead of: `layOut` positions font strings and is shared with every
	-- row on the panel, and a heading that became a Button would have to be laid out by a
	-- second copy of that arithmetic. It already records where each column ended up - the
	-- comment there says it is so that something can be put over one of them - and this is
	-- the something.
	--
	-- A button only where the column can be ordered at all. A heading that highlights under
	-- the cursor and does nothing when clicked is worse than one that does not react: the
	-- first is a promise.
	local headerButtons = {}
	for index = 1, MAX_CELLS do
		local button = CreateFrame("Button", nil, header)
		button:SetHeight(HEADER_HEIGHT)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		button:Hide()
		headerButtons[index] = button
	end

	-- Never shown, never placed. It exists to be asked how wide a heading would be.
	measure = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	measure:Hide()

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", -26, 28)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	footer:SetPoint("BOTTOMLEFT", 4, FOOTER_MARGIN)
	footer:SetPoint("BOTTOMRIGHT", -4, FOOTER_MARGIN)
	footer:SetJustifyH("LEFT")

	-- Above the footer, because it is about the columns rather than about the totals.
	local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, CAPTION_GAP)
	note:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, CAPTION_GAP)
	note:SetJustifyH("LEFT")

	local rows = {}
	local setButtons = {}

	-- Sized against how many sets there are rather than fixed, because adding one is how this
	-- row came to run under the side filters at the right-hand end: seven buttons at the width
	-- four had is wider than the panel, and nothing complains - it just overlaps. Worked out
	-- once, above, where the check that it is still legible lives beside it.
	-- The set this panel was starred on, if it was. Read once, as the panel is built, which
	-- is the first time it is looked at rather than at login.
	local home = UI:DefaultSet()
	if home then
		for _, set in ipairs(SETS) do
			if set.id == home then currentSet = set end
		end
	end

	-- Which set is showing, so that starring this panel can take it as it stands. Kept where
	-- the window can read it rather than reached for across files.
	UI.__summarySet = currentSet.id

	local setRow = {}
	for _, set in ipairs(SETS) do
		local button = CreateFrame("Button", nil, chooser, "UIPanelButtonTemplate")
		button:SetHeight(20)
		button:SetText(set.label)
		button:SetScript("OnClick", function()
			currentSet = set
			UI.__summarySet = set.id
			-- The star above goes hollow when the columns stop being the starred ones,
			-- which is how somebody discovers they can move home to this set.
			UI:RefreshStars()
			frame:Refresh()
		end)
		setButtons[set.id] = button
		setRow[#setRow + 1] = button
	end

	-- Each as wide as its own label, no narrower than the share the English design gave it,
	-- and the whole row held to the pixels there are. Where a language needs more than the
	-- row has, the room comes off whichever buttons have the most to spare - the same rule
	-- the columns below use, and the same code.
	--
	-- A gap of one rather than two, which is six pixels across seven buttons. English itself
	-- was four over - the client reported 668 against 664 and said so every time the summary
	-- was built - and there was nowhere else to take it from: the padding is shared with
	-- every other button row, and the room to the right holds the two faction buttons. One
	-- pixel between buttons is not a thing anybody can see; a warning in the chat frame on
	-- every draw is.
	--
	-- Nothing here can check this. The harness measures text at a flat rate per character and
	-- makes these seven labels 549 pixels, comfortably inside the budget - it is the real
	-- font, in the real client, that is wider. This is one of the few things only the game
	-- can answer, which is exactly why that warning is printed at runtime rather than
	-- assumed at build time.
	-- No gap at all between them. Seven sets whose English labels come to 666 pixels in a
	-- row that has 664 is two pixels short, and the six single-pixel gaps are the only six
	-- pixels in it that are not somebody's word: the buttons carry their own padding, and a
	-- segmented row of them reads as one control rather than as seven with hairlines.
	UI:LayOutRow(setRow, SET_BUTTON_WIDTH, 0, 0, nil, CHOOSER_WIDTH - FACTION_ROOM)

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
				factionShown(faction) and L["|cff40bf40shown|r"] or L["|cff9d9d9dhidden|r"] } }
		end)

		button:SetScript("OnClick", function()
			FamilyDB.ui = FamilyDB.ui or {}
			FamilyDB.ui.factions = FamilyDB.ui.factions or {}
			FamilyDB.ui.factions[faction] = not factionShown(faction)
			frame:Refresh()
		end)
		factionButtons[faction] = button
	end

	--------------------------------------------------------------------------------------
	-- What the filters hold, and what they let through
	--------------------------------------------------------------------------------------

	-- Not remembered between sessions, and that is the decision rather than an omission. The
	-- side buttons above are remembered because they are a preference - which half of an
	-- account somebody plays does not change from one evening to the next. A name typed into
	-- a box is a question being asked once, and a panel that opens tomorrow still showing
	-- four of forty members, because of a word nobody remembers typing, is a panel that looks
	-- broken.
	local classFilter, levelMin, levelMax

	local hint = filters:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("LEFT", 4, 0)
	hint:SetText(L["filter"])

	-- Named, like the search on the character panel, so a macro or a check can reach it.
	local search = CreateFrame("EditBox", "FamilySummarySearch", filters, "InputBoxTemplate")
	search:SetPoint("LEFT", hint, "RIGHT", 10, 0)
	search:SetSize(150, 20)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function() frame:Refresh() end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	-- Only the classes the family actually has. Offering a warlock filter to a family with no
	-- warlock is offering a way to show nothing, which is the rule the character panel's own
	-- pickers already follow.
	local function classesHeld()
		local seen, list = {}, {}
		for _, entry in pairs(Family.Database:Members()) do
			local classFile = entry.meta and entry.meta.classFile
			if classFile and not seen[classFile] then
				seen[classFile] = true
				list[#list + 1] = classFile
			end
		end
		table.sort(list)
		return list
	end

	local classButton = UI:CreateChoicePicker(filters, 120, L["Class"], "all", function()
		local names = _G.LOCALIZED_CLASS_NAMES_MALE
		local list = {}
		for _, classFile in ipairs(classesHeld()) do
			local red, green, blue = UI:ClassColour(classFile)
			list[#list + 1] = {
				value = classFile,
				label = (names and names[classFile]) or classFile,
				r = red, g = green, b = blue,
			}
		end
		return list
	end, function()
		frame:Refresh()
	end)
	classButton:SetPoint("LEFT", search, "RIGHT", 12, 0)

	-- Two numbers rather than a list of brackets. Brackets would have to be right on three
	-- clients whose ceilings are 60, 70 and 90, and a set of ranges built for one of them is
	-- wrong on the other two - so the player says the range and no client has to be guessed
	-- at.
	local levelLabel = filters:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	levelLabel:SetPoint("LEFT", classButton, "RIGHT", 12, 0)
	levelLabel:SetText(L["Level"])

	local function levelBox(name, anchor, gap)
		local box = CreateFrame("EditBox", name, filters, "InputBoxTemplate")
		box:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
		box:SetSize(34, 20)
		box:SetAutoFocus(false)
		box:SetNumeric(true)
		box:SetMaxLetters(3)
		box:SetJustifyH("CENTER")
		box:SetScript("OnTextChanged", function() frame:Refresh() end)
		box:SetScript("OnEscapePressed", function(self)
			self:SetText("")
			self:ClearFocus()
		end)
		return box
	end

	local minBox = levelBox("FamilySummaryLevelMin", levelLabel, 10)
	local dash = filters:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	dash:SetPoint("LEFT", minBox, "RIGHT", 6, 0)
	dash:SetText("-")
	local maxBox = levelBox("FamilySummaryLevelMax", dash, 10)

	-- The narrowing a set brings with it, in one control that changes what it is asking.
	--
	-- One picker rather than one per set, because the sets that want one want *a* one - a
	-- list of things the family holds, narrowed to one of them - and a second copy would be
	-- the fifth filter bar this addon has already learned not to build.
	--
	-- Its caption and its list are the current set's, reassigned as the set changes, and its
	-- value is asked of `Reconcile` rather than remembered: a set with no narrowing offers an
	-- empty list, and Reconcile drops a choice that is no longer on offer. So switching from
	-- Professions to Crafting puts it back to *all* without anything having to remember to.
	local narrowButton = UI:CreateChoicePicker(filters, 150, "", "all", function()
		local narrow = currentSet and currentSet.narrow
		return narrow and narrow.choices() or {}
	end, function()
		frame:Refresh()
	end)
	narrowButton:SetPoint("LEFT", maxBox, "RIGHT", 12, 0)
	narrowButton:Hide()

	-- Reachable, so a check can drive the control a player drives rather than the variable
	-- behind it.
	UI.__summaryNarrow = narrowButton

	-- How much is being hidden, at the right-hand end of the same row. A filter that quietly
	-- removes thirty rows and says nothing is indistinguishable from a panel that has lost
	-- them, which is the complaint every filter without a count eventually produces.
	local counter = filters:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	counter:SetPoint("RIGHT", -4, 0)
	counter:SetJustifyH("RIGHT")

	local function numberIn(box)
		local typed = tonumber(box:GetText())
		return typed and typed > 0 and typed or nil
	end

	-- The two `meta.classFile and` / `if level then` guards below are a **guard on an
	-- invariant, not a case**, and the difference is worth writing down because the first
	-- draft of this comment claimed the second and was wrong.
	--
	-- Measured 2026-09-04: no record reaches this without both. `Scanners/Identity.lua` and
	-- `Scanners/Bags.lua` are the only two writers that create a member and both write
	-- `UnitLevel` and `UnitClass` together; every other scanner merges fields onto a record
	-- that already exists; `addLetter` in `Scanners/Mail.lua`, the one path that could have
	-- made a bare record out of a letter posted to an alt, refuses a key it has no meta for;
	-- `Wide.lua` has sent `classFile` and `level` in IDENTITY since the first commit, so not
	-- even a sibling from an older Family arrives without them; and nothing clears either.
	--
	-- They stay because the cost is one `and` and the failure they prevent is silent: a
	-- member disappearing from a panel because a filter decided an absence was a mismatch.
	-- What they are not is evidence of anything - if a check here goes red, the thing to fix
	-- is whatever started writing records with a gap in them.
	local function typedFilters(meta)
		if classFilter and meta.classFile and meta.classFile ~= classFilter then
			return false
		end

		local level = meta.level
		if level then
			if levelMin and level < levelMin then return false end
			if levelMax and level > levelMax then return false end
		end

		local needle = (search:GetText() or ""):lower()
		if needle ~= "" then
			local name = (meta.name or ""):lower()
			if not name:find(needle, 1, true) then return false end
		end

		return true
	end

	-- The set's own narrowing and the player's, composed. Crafting shows the members with a
	-- cooldown running; a name typed into the box narrows *that*, rather than replacing it
	-- with everybody.
	local function passes(meta)
		if currentSet.only and not currentSet.only(meta) then return false end

		-- And the set's own narrowing, where it has one and the player has chosen. Composed
		-- with the rest rather than replacing it: "which of my level 60s are blacksmiths"
		-- is one question and both halves of it are on the same row.
		local narrow = currentSet.narrow
		local wanted = narrow and narrowButton:Value()
		if wanted ~= nil and not narrow.passes(meta, wanted) then return false end

		return typedFilters(meta)
	end

	function frame:Refresh()
		levelMin, levelMax = numberIn(minBox), numberIn(maxBox)

		-- Asked of the picker rather than remembered from the click, because Reconcile also
		-- drops a choice the family no longer has. Filter to the one warlock, delete that
		-- character, and a remembered value would leave the panel empty and the button still
		-- saying Warlock - which is what the character panel already learned.
		classFilter = classButton:Reconcile()

		-- The narrowing picker takes on whatever the set on screen is asking, or goes away
		-- where the set asks nothing. Reconciled after its provider has been pointed at the
		-- new set, or it would be dropping a choice against the old set's list.
		local narrow = currentSet and currentSet.narrow
		narrowButton.prefix = narrow and narrow.label or ""
		narrowButton:SetShown(narrow ~= nil)
		narrowButton:Reconcile()

		local columns = columnsOf(currentSet)

		-- Whether the set on screen is the one whose mail figure opens the letters.
		--
		-- The unfold is drawn under the **member** column, which every set has, so nothing
		-- about it was ever tied to the set that owns the count - and clicking a mail figure
		-- on Activity then left the letters sitting on Currencies, a panel with no mail on it
		-- at all. Reported live.
		--
		-- Asked of the columns rather than of the set's name, so that moving the mail column
		-- to another set takes its unfold with it rather than leaving this behind to be found
		-- the next time somebody rearranges a panel.
		local showsMail, showsBoon = false, false
		for _, column in ipairs(columns) do
			if column.key == "mail" then showsMail = true end
			if column.key == "boon" then showsBoon = true end
		end
		UI:FitColumns(columns, ROW_BUDGET, measure)
		local realms, byRealm, totals, siblings = gather(passes, orderFor(currentSet.id))

		-- Said only while something is typed. With the boxes empty this is the whole family
		-- and a count of it against itself is noise; the moment a filter is on, it is the
		-- difference between "there are four of them" and "thirty-six are hidden".
		--
		-- Counted against what this *set* would show, not against the family: on Crafting,
		-- where the set already narrows to members with a cooldown running, comparing with
		-- forty would report a filter nobody set.
		if (search:GetText() or "") ~= "" or classFilter or levelMin or levelMax then
			local shown, all = 0, 0
			for _, entry in pairs(Family.Database:Members()) do
				local meta = entry.meta
				if meta and factionShown(meta.faction)
					and (not currentSet.only or currentSet.only(meta)) then
					all = all + 1
					if typedFilters(meta) then shown = shown + 1 end
				end
			end
			counter:SetText(string.format(L["|cffffaa00%d of %d shown|r"], shown, all))
		else
			counter:SetText("")
		end

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

		-- What this set is actually drawing, kept where something else can read it. The set
		-- id has been kept this way for the window since the star was built; the columns are
		-- the other half of the same question, and half of them do not exist until the panel
		-- is drawn - the crafting cooldowns and the currencies are built from what the
		-- family turns out to have.
		UI.__summaryColumns = columns

		local chosen = UI:SummarySort(currentSet.id)

		for index = 1, MAX_CELLS do
			local column = columns[index]
			local label = column and column.label or ""

			-- The arrow says which column the table is in the order of and which way, and
			-- it is drawn rather than said because a heading has no room for a sentence.
			-- Only on the one column that is ordered: an arrow on every heading would be
			-- five claims where there is one fact.
			if column and chosen and chosen.key == column.key then
				label = label .. (chosen.descending and " |cffffd700v|r" or " |cffffd700^|r")
			end

			headerCells[index]:SetText(label)

			local button = headerButtons[index]
			if column and column.key and UI:SummarySortable(column.key)
				and column.drawX then
				button:ClearAllPoints()
				button:SetPoint("LEFT", header, "LEFT", column.drawX, 0)
				button:SetWidth(column.drawWidth or column.width)
				button:SetScript("OnClick", function()
					UI:SetSummarySort(currentSet.id, column.key)
					frame:Refresh()
				end)
				button:Show()
			else
				button:SetScript("OnClick", nil)
				button:Hide()
			end
		end

		local used = 0
		local y = 0

		-- Before any row is anchored to it, not after: a row anchored to a scroll child
		-- that is still one pixel wide has no width of its own.
		list:SetWidth(UI:ListWidth(scroll))

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
				local width = column.drawWidth or column.width
				if offset >= edge and offset < edge + width then return index end
				edge = edge + width
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

		local function nextRow(height)
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

			-- Put away whatever the last thing drawn on this row left behind. Rows come
			-- out of a pool and a letter's pictures would otherwise sit under a member.
			for _, slot in ipairs(row.attach) do slot:Hide() end
			for _, slot in ipairs(row.boon) do slot:Hide() end
			row.attachMoney:Hide()

			row:SetHeight(height or ROW_HEIGHT)
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetPoint("TOPRIGHT", 0, -y)
			row:Show()
			y = y + (height or ROW_HEIGHT)
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

			-- Beside the first number it labels, which is where it reads best - unless the
			-- word is too long for that column, and then at the far left, where a totals
			-- row has the whole member column to itself and nothing to collide with.
			--
			-- "Grand totals" fits the column left of the money in English with six pixels
			-- to spare. "Totaux generaux" needs sixteen more than there are and "Totales
			-- generales" twenty-nine, and a label drawn through the number it is labelling
			-- is worse than one sitting further from it.
			local at = math.max(firstTotal - 1, 1)
			local beside = columns[at]
			local room = (beside and (beside.drawWidth or beside.width) or 0) - 8
			measure:SetText(label or "")
			if (measure:GetStringWidth() or 0) > room then at = 1 end

			setCell(total, at, label, r or 0.55, g or 0.55, b or 0.55)

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

			-- The figure that counts the letters, made clickable where there are any to
			-- show. Placed over that column rather than beside it, so what is clicked is
			-- the number that prompted the question.
			row.mailHit:Hide()
			row.mailHit:SetScript("OnClick", nil)

			row.boonHit:Hide()
			row.boonHit:SetScript("OnClick", nil)

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

			-- Armed only where there is something behind it: a nought that opens nothing
			-- teaches a player that the figure is not a button, which costs the ones that
			-- are.
			for index, column in ipairs(columns) do
				if column.key == "mail" and (member.meta.mailCount or 0) > 0 then
					local width = column.drawWidth or column.width
					local key = member.key

					row.mailHit:ClearAllPoints()
					row.mailHit:SetPoint("LEFT", column.drawX or 0, 0)
					row.mailHit:SetSize(width, ROW_HEIGHT)
					row.mailHit:SetScript("OnClick", function()
						openMail = (openMail ~= key) and key or nil
						frame:Refresh()
					end)
					row.mailHit:Show()
				end

				-- The Chrono figure, the same way. Armed only where something was recorded:
				-- the column also shows a dash for a character whose bags nobody has read,
				-- and a dash that opens an empty line answers a question with a shrug.
				if column.key == "boon" and member.meta.banked then
					local width = column.drawWidth or column.width
					local key = member.key

					row.boonHit:ClearAllPoints()
					row.boonHit:SetPoint("LEFT", column.drawX or 0, 0)
					row.boonHit:SetSize(width, ROW_HEIGHT)
					row.boonHit:SetScript("OnClick", function()
						openBoon = (openBoon ~= key) and key or nil
						frame:Refresh()
					end)
					row.boonHit:Show()
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

			-- The letters themselves, when somebody has clicked the figure that counts them.
			--
			-- Under the member and indented, on the member column rather than the mail one:
			-- the mail column is sixty pixels and a sender's name is not, and the widest
			-- column on the row is the one with room for a line of prose.
			--
			-- Only the live ones. A letter that has expired is gone from the mailbox and
			-- listing it would be Family showing something that is not there any more -
			-- which is the opposite of what §2.2 asks of every other screen.
			if openMail == member.key and showsMail then
				local payload = Family.Database:Payload(member.key) or {}
				local letters = Family.Mail:Live(payload.mail)

				for _, letter in ipairs(letters) do
					local line = nextRow(LETTER_HEIGHT)
					line.memberKey = member.key
					line.memberName = member.meta.name or member.key
					line.memberRealm = member.meta.realm
					line.borrowed = row.borrowed

					setCell(line, 1, "      " .. describeLetter(letter))

					-- Each letter's own expiry, under the column that says the soonest.
					for index, column in ipairs(columns) do
						if column.key == "mailexp" then
							setCell(line, index, letter.expiresBy
								and (duration(letter.expiresBy - time()) or L["soon"])
								or "")
						end
					end

					-- What is in it, right-aligned so that a letter with one attachment
					-- and one with twelve end at the same edge and the eye can compare
					-- them down the column.
					local attachments = letter.attachments or {}
					local shown = math.min(LETTER_SLOTS, #attachments)

					for index = 1, shown do
						local carried = attachments[index]
						local slot = line.attach[index]

						slot:ClearAllPoints()
						slot:SetPoint("RIGHT", -6 - (shown - index) * (LETTER_ICON + 2), 0)

						-- Asked for by id, and the name asked for with it: an item this
						-- client has never seen answers nothing until it has, and the
						-- panel redraws when it does.
						Family.Names:Item(carried.id, "summary.mail", function()
							if frame:IsShown() then frame:Refresh() end
						end)

						slot.itemID = carried.id
						slot.itemLink = carried.item
						slot.icon:SetTexture(Family:TryCall(GetItemIcon, carried.id)
							or "Interface\\Icons\\INV_Misc_QuestionMark")
						slot.count:SetText((carried.count or 1) > 1
							and tostring(carried.count) or "")
						slot:Show()
					end

					local money = letterMoney(letter)
					if money then
						line.attachMoney:ClearAllPoints()
						line.attachMoney:SetPoint("RIGHT",
							-6 - shown * (LETTER_ICON + 2) - 4, 0)
						line.attachMoney:SetText(money)
						line.attachMoney:Show()
					end
				end

				if #letters == 0 then
					local line = nextRow()
					setCell(line, 1, L["      |cff9d9d9dnothing in the post that Family "
						.. "has seen|r"])
				end
			end

			-- What the boon is holding: one line, the buffs in the order the game listed
			-- them, each as its own picture with the time left written on it.
			--
			-- One line and not one per buff, unlike the post. A letter is a paragraph - a
			-- sender, a subject, an expiry - and a world buff is a picture and a number, so
			-- twelve of them fit across a row and reading them as a row is how the eye
			-- compares two characters' boons.
			if openBoon == member.key and showsBoon then
				local banked = member.meta.banked or {}
				local line = nextRow(LETTER_HEIGHT)
				line.memberKey = member.key
				line.memberName = member.meta.name or member.key
				line.memberRealm = member.meta.realm
				line.borrowed = row.borrowed

				local shown = math.min(BOON_SLOTS, #banked)
				for index = 1, shown do
					local buff = banked[index]
					local slot = line.boon[index]

					slot:ClearAllPoints()
					-- Anchored to the right edge and growing leftwards, the way a letter's
					-- attachments are: a character with one buff and a character with four
					-- then end at the same edge, and the eye compares them down the column
					-- instead of measuring from a name of a different length each time.
					-- The order the game listed them in is kept.
					slot:SetPoint("RIGHT", -6 - (shown - index) * (BOON_ICON + 2), 0)

					-- The fileID is what was recorded and is what is drawn, so a buff this
					-- table has never heard of still appears as itself. The spell is only
					-- ever for the tooltip, and nil is a fine answer for it.
					slot.spellID = (Family.WorldBuffs or {})[buff.icon]
					slot.icon:SetTexture(buff.icon)
					slot.count:SetText(boonLeft(buff.minutes or 0))
					slot:Show()
				end

				if shown == 0 then
					setCell(line, 1, L["      |cff9d9d9dnothing in the boon that Family "
						.. "has read|r"])
				end
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

				totalsRow(L["Total"], byRealm[realm])
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

			totalsRow(L["Grand totals"], everyone, 1, 0.82, 0)
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
			note:SetText(L["|cff888888Primary professions on the first line of each member, "
				.. "everything else on the second. A profession in grey has recipes "
				.. "Family has not seen for a week, or has never seen: ranks are always "
				.. "current, recipe lists are only as new as the last time that window "
				.. "was open.|r"])
		elseif currentSet.id == "bags" then
			note:SetText(L["|cff888888Free and total slots leave out quivers, soul bags and "
				.. "the like: their slots are not room for anything else. Possessions "
				.. "shows them all the same.|r"])
		elseif currentSet.id == "crafting" then
			note:SetText(string.format(L["|cff888888Crafting cooldowns only - transmutes, "
				.. "mooncloth, salt shakers. Only the members who have one are listed. "
				.. "Blank means Family has not seen that member's, which is not the same "
				.. "as nought.%s|r"],
				craftingOmitted > 0
					and string.format(L[" |cffffaa00%d more not shown - there is only so "
						.. "much room in a row.|r|cff888888"], craftingOmitted)
					or ""))
		elseif currentSet.id == "currencies" then
			-- The columns are whatever the family holds most of, so the panel has to say
			-- that: five columns out of twelve currencies is not the same claim as five
			-- columns out of five, and they look identical.
			note:SetText(string.format(L["|cff888888The currencies this family holds most "
				.. "of, most first.%s Character shows one member's in full, with what "
				.. "each is capped at.|r"],
				currenciesOmitted > 0
					and string.format(L[" |cffffaa00%d more not shown - there is only so "
						.. "much room in a row.|r|cff888888"], currenciesOmitted)
					or ""))
		else
			note:SetText("")
		end

		if totals.members == 0 and not (factionShown("Alliance") or factionShown("Horde")) then
			footer:SetText(L["|cffffaa00Both sides are switched off.|r |cff888888Turn one back "
				.. "on with the buttons at the end of the row above.|r"])
		elseif totals.members == 0 then
			footer:SetText(L["|cff9d9d9dNothing recorded yet. Family fills as you play each " ..
				"member - log in on one and its bags and money are written down.|r"])
		else
			footer:SetText(string.format(totals.members == 1
				and L["|cffffd700Grand totals:|r  %d member   |cff888888|||r   %s   "
					.. "|cff888888|||r   %d of %d bag slots free   |cff888888|||r   "
					.. "|cff888888right-click a member to remove them|r"]
				or L["|cffffd700Grand totals:|r  %d members   |cff888888|||r   %s   "
					.. "|cff888888|||r   %d of %d bag slots free   |cff888888|||r   "
					.. "|cff888888right-click a member to remove them|r"],
				totals.members,
				UI:Money(totals.money), totals.free, totals.slots))
		end

		-- The footer and the note above it are as tall as the language makes them. English
		-- fits both on one line each and 28 pixels was enough; French wraps both to two and
		-- the table's last row was drawn underneath them. Measured after they are written,
		-- because that is the only moment the answer exists.
		do
			-- Bottom margin, then the footer, then the note above it where there is one,
			-- then a clear line before the table starts. Each measured after it is
			-- written, because how tall a caption is depends on the language it is in:
			-- English fits the grand totals on one line and French does not.
			local caption = note:GetText()
			scroll:SetPoint("BOTTOMRIGHT", -26, UI:CaptionRoom(
				footer:GetStringHeight(),
				(caption and caption ~= "") and note:GetStringHeight() or 0,
				FOOTER_MARGIN, CAPTION_GAP, TABLE_GAP))
		end
	end
end

UI:RegisterTab("summary", L["Summary"], build)
