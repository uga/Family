-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The quest log of any member, by zone (§4, Quests).
--
-- The panel answers two questions. "What is this character in the middle of", which is the
-- zone grouping, and "is any of it worth going back for", which is the difficulty and the
-- progress. A list of twenty quest names in log order answers neither.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local ROW = 15

--------------------------------------------------------------------------------------------
-- Difficulty
--
-- Worked out here rather than stored, because how hard a quest is depends on the level of
-- the character holding it: the same quest is red on one member and grey on the next, and a
-- colour written down at scan time would be wrong for the member it is shown for.
--
-- The client has GetQuestGreenRange, and it is not used: it answers for whoever is being
-- played, and this panel is nearly always looking at somebody else. The table below is the
-- game's own banding, applied to the level actually stored beside the quest.
--------------------------------------------------------------------------------------------

-- The words are the ones a player would use for the colours the game paints these in. Yellow
-- was called "even", which is a word for a fight and not for a quest, and read as though it
-- meant something particular. Normal is what yellow means: the level it was written for.
local DIFFICULTY = {
	{ id = "impossible", label = L["very hard"], colour = "|cffff2020" },
	{ id = "hard",       label = L["hard"],      colour = "|cffff8040" },
	{ id = "normal",     label = L["normal"],    colour = "|cffffff00" },
	{ id = "easy",       label = L["easy"],      colour = "|cff40bf40" },
	{ id = "trivial",    label = L["trivial"],   colour = "|cff9d9d9d" },
}

local function greenRange(level)
	if level <= 5 then return 5 end
	if level <= 39 then return 6 end
	if level <= 59 then return 9 end
	return 11
end

-- Answers nil when either level is missing, because "no level recorded" is not "trivial".
local function difficultyOf(questLevel, memberLevel)
	if not questLevel or not memberLevel or questLevel <= 0 then return nil end

	local difference = questLevel - memberLevel

	if difference >= 5 then return DIFFICULTY[1] end
	if difference >= 3 then return DIFFICULTY[2] end
	if difference >= -2 then return DIFFICULTY[3] end
	if questLevel > memberLevel - greenRange(memberLevel) then return DIFFICULTY[4] end
	return DIFFICULTY[5]
end


--------------------------------------------------------------------------------------------
-- Opening one
--
-- Only for the member being played, and that is not a nicety: the quest log is the log of
-- whoever is logged in, so opening "their" quest on somebody else would open a different
-- quest or none at all. For anybody else the row is a row.
--
-- The call to make differs by client and none of them exist everywhere, so each is tried and
-- the first that works wins. Nothing here assumes the panel opened: a client that refuses -
-- in combat, say - simply leaves the game as it was.
--------------------------------------------------------------------------------------------

function UI:OpenQuest(memberKey, questID, title)
	if memberKey ~= Family:CurrentMember() then return false end

	-- Mists, where the log lives on the map and is addressed by quest id.
	if questID then
		local api = _G.C_QuestLog
		if api and api.SetSelectedQuest then
			Family:TryCall(api.SetSelectedQuest, questID)
		end
		if _G.QuestMapFrame_OpenToQuestDetails then
			Family:TryCall(QuestMapFrame_OpenToQuestDetails, questID)

			-- The call answers nothing either way, so whether it worked is judged by
			-- whether the frame it opens is now up.
			if _G.QuestMapFrame and _G.QuestMapFrame:IsShown() then return true end
		end
	end

	-- Era and Burning Crusade: a window with a list, addressed by position in that list -
	-- so the position has to be found again, because it moves as quests come and go.
	--
	-- Headers are opened first and left open, unlike the scan, which puts them back. A quest
	-- under a shut header has no position to select and would not be on screen if it did;
	-- somebody who has just clicked on it wants to see it, not to have their log tidied.
	Family:TryCall(ExpandQuestHeader, 0)

	local count = Family:TryCall(GetNumQuestLogEntries) or 0
	local wanted

	for index = 1, count do
		local questTitle = Family:TryCall(GetQuestLogTitle, index)
		if questTitle == title then
			wanted = index
			break
		end
	end

	if not wanted then return false end

	Family:TryCall(SelectQuestLogEntry, wanted)

	if _G.QuestLogFrame and _G.ShowUIPanel then
		Family:TryCall(ShowUIPanel, QuestLogFrame)
	end
	if _G.QuestLog_SetSelection then Family:TryCall(QuestLog_SetSelection, wanted) end
	if _G.QuestLog_Update then Family:TryCall(QuestLog_Update) end

	return true
end

--------------------------------------------------------------------------------------------
-- Turning one member's log into rows
--
-- This is not a panel of its own. A quest log belongs with the rest of what a character is
-- rather than beside the bank and the professions, so it is a section of the character panel
-- and this file hands it the rows to draw. Keeping the difficulty banding and the zone
-- grouping here rather than in Character.lua is what stops that panel growing a third job.
--------------------------------------------------------------------------------------------

-- Zones in the order the log had them, and the quests under each sorted hardest first, which
-- is the order that answers "what should I go and do".
-- What a zone is called for whoever is reading, which is not always what it was called for
-- whoever recorded it.
--
-- A category arrives as a word, and a word is a language. A sibling playing in French files
-- their quests under *Peninsule des Flammes infernales*, and drawing that on an English panel
-- says nothing an English reader can act on - and, worse, sits beside *Hellfire Peninsula* as
-- though the two were different places. The log carries a zone id per category since
-- 2026-09-05; `Names:Area` turns it into this reader's word and falls back to the recorded one
-- for a zone this client has never heard of, which is the honest answer rather than a wrong one.
local function zoneName(log, word)
	if type(word) ~= "string" or word == "" then return nil end

	local id = log and log.zones and log.zones[word]
	return Family.Names:Area(id, word) or word
end

local function byCategory(entries, log)
	local order, groups = {}, {}

	for _, quest in ipairs(entries) do
		local category = zoneName(log, quest.category) or L["Elsewhere"]
		if not groups[category] then
			groups[category] = {}
			order[#order + 1] = category
		end
		table.insert(groups[category], quest)
	end

	for _, quests in pairs(groups) do
		table.sort(quests, function(a, b)
			local levelA, levelB = a.level or 0, b.level or 0
			if levelA ~= levelB then return levelA > levelB end
			return (a.title or "") < (b.title or "")
		end)
	end

	return order, groups
end

-- Returns a list of rows and a line to put above them, or nothing and the reason why.
--
-- A row is { left, middle, right, questID }, which is the shape the character panel's rows
-- already have - the same three columns that carry a piece of equipment or a reputation.
-- `UI:Payload` and never `Family.Database:Payload`.
--
-- A borrowed member's key begins with "@" and the database has never heard of it, so asking
-- the database directly answers nothing for a linked family's character - and §2.2 then turns
-- that nothing into *Nothing recorded for this member*, which is a sentence about our storage
-- said about somebody else's. `UI:Payload` knows both kinds of key and is why it exists.
--
-- Found on 2026-09-05 by going to check whether quest sharing works end to end. The `quests`
-- grant has been crossing the wire since it was written and nothing on this side could read
-- it, which is exactly the gap that check was written to look for.
function UI:QuestLines(key, meta, matches)
	local payload = UI:Payload(key)
	local log = payload and payload.quests

	-- §2.2: a member whose log has never been read says so, and is not drawn as a member
	-- with nothing to do.
	if not log then return nil, L["|cffffaa00Nothing recorded for this member.|r"] end

	meta = meta or {}

	local ready = 0
	for _, quest in ipairs(log.entries) do
		if quest.done and quest.objectives and quest.done >= quest.objectives then
			ready = ready + 1
		end
	end

	-- Built in pieces rather than as one sentence with a "s" hung on the end of it. A
	-- suffix is a plural only in a language that forms plurals with a suffix, and the cap
	-- has to be able to move: "20 of 25" reads the other way round in some of them.
	local counted = string.format(
		#log.entries == 1 and L["|cffffd700%d|r quest"] or L["|cffffd700%d|r quests"],
		#log.entries)
	if meta.questMax then
		counted = counted .. string.format(L[" of %s"], meta.questMax)
	end

	local status = string.format(
		L["%s   |cff888888|||r   %s   |cff888888|||r   seen %s"],
		counted,
		ready > 0 and string.format(L["|cff40bf40%d ready to hand in|r"], ready)
			or L["|cff9d9d9dnothing ready to hand in|r"],
		UI:Ago(log.seen))

	-- The objectives are read from the same payload and not from the log, because they are
	-- deliberately not part of it: they are recorded under a key no Wide Family category
	-- lists, so a borrowed member has none and the rows below simply carry nothing. Which is
	-- the right answer for a linked family rather than a gap - what the client would say
	-- about their quest is about the player anyway.
	local objectives = payload.questObjectives or {}

	local rows = {}
	local order, groups = byCategory(log.entries, log)

	for _, category in ipairs(order) do
		local shown = {}
		for _, quest in ipairs(groups[category]) do
			if not matches or matches(quest.title) or matches(category) then
				shown[#shown + 1] = quest
			end
		end

		-- Worked out before the heading is added, so a zone with nothing matching the
		-- filter does not leave its name behind with no quests under it.
		if #shown > 0 then
			rows[#rows + 1] = {
				left = string.format("|cff88bbff%s|r |cff888888(%d)|r", category, #shown),
				middle = "",
				right = "",
			}

			for _, quest in ipairs(shown) do
				local difficulty = difficultyOf(quest.level, meta.level)
				local colour = difficulty and difficulty.colour or "|cffdddddd"

				-- The level and how hard that is share a column. They are one fact said
				-- twice - once as a number and once as a word - and the word is there
				-- because a colour alone is no use to everyone.
				local left = quest.level
					and string.format("%s%d%s|r", colour, quest.level,
						difficulty and ("  " .. difficulty.label) or "")
					or "|cff9d9d9d-|r"

				local right = ""
				-- Objectives, not a yes or no: "3 of 5" is the answer somebody wants. A
				-- quest with none at all - a delivery, a talk-to - says nothing rather
				-- than claiming to be at nought of nought.
				if quest.objectives and quest.objectives > 0 then
					local done = quest.done or 0
					if done >= quest.objectives then
						right = L["|cff40bf40ready to hand in|r"]
					else
						right = string.format(L["|cffffd700%d|r of %d"], done,
							quest.objectives)
					end
				end

				-- The title as this reader's client says it, out of the id recorded beside
				-- it. The zone above it has read this way since the same afternoon, and a
				-- row whose heading was translated and whose name was not would be half a
				-- fix that looked like a fault.
				local named = Family.Names:Quest(quest.id, quest.title, quest.level)

				rows[#rows + 1] = {
					left = left,
					middle = colour .. (named or "?") .. "|r",
					right = right,
					questID = quest.id,
					questLevel = quest.level,
					title = quest.title,
					progress = quest.title and objectives[quest.title] or nil,
				}
			end
		end
	end

	return rows, status
end
