-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The quest log: what each member is in the middle of (§4, Quests).
--
-- Unlike the bank or the mailbox this is readable at any time, so it is kept current rather
-- than photographed - which is what makes it worth having. The question an alt manager
-- answers here is "which of my characters is sitting on a half-finished Elwynn Forest, and
-- how far through", and that is only useful if it is true now.
--
-- Two things about the log are traps, and both have bitten this addon before in other
-- scanners:
--
--   Collapsed headers hide their quests, exactly as a collapsed header hides skills in the
--   skill list. Everything is expanded before reading and put back afterwards.
--
--   Expanding and collapsing makes the game announce that the quest log changed, and that
--   announcement is one of the things that asks for a scan. Left alone, a scan books the
--   next scan for ever - which is how the reputation scanner once hung the Burning Crusade
--   client. Hence the scanning flag, which is not about re-entrancy.
--
-- Difficulty is deliberately *not* recorded. How hard a quest is depends on the level of the
-- character holding it, that character's level is already stored beside it, and a colour
-- computed at display time cannot go stale the way a stored one would.

local _, Family = ...

local Quests = {}
Family.Quests = Quests

--------------------------------------------------------------------------------------------
-- Reading one entry
--
-- GetQuestLogTitle answers with a different list on each of these clients, and Mists answers
-- with a table from somewhere else entirely. The lesson from the talent grid applies here
-- unchanged: unpack by position and it works until the next client. So the returns are
-- inspected, and only what can be identified with confidence is kept.
--------------------------------------------------------------------------------------------

local function pack(...) return { n = select("#", ...), ... } end

-- The title and the level are the first two returns on every one of these clients, and the
-- id is deliberately not guessed at from the rest: quest ids start at 1 here, so by size
-- alone one is indistinguishable from a level or a suggested group size, and an id guessed
-- wrong would open somebody else's quest in a tooltip. It is asked for separately below.
local function interpretTitle(returns)
	local title = returns[1]
	if type(title) ~= "string" or title == "" then return nil end

	local level = tonumber(returns[2])

	-- Whether this row is a zone heading rather than a quest. In every shape these clients
	-- use, the first boolean in the third to sixth position is isHeader; a client that
	-- answers with no boolean at all falls back to the level, which a heading does not have.
	--
	-- Where it was found is returned as well, because the flag that says whether a heading
	-- is shut sits immediately after it - and looking for "the first true boolean" without
	-- knowing that would find isHeader itself and report every heading as collapsed.
	local isHeader, at
	for index = 3, math.min(returns.n, 6) do
		if type(returns[index]) == "boolean" then
			isHeader, at = returns[index], index
			break
		end
	end
	if isHeader == nil then isHeader = (level or 0) <= 0 end

	return {
		title = title,
		level = level,
		isHeader = isHeader and true or false,
		headerAt = at,
	}
end

-- Which of `GetQuestLogTitle`'s returns holds the id, worked out by asking rather than by
-- counting, and then reused for the rest of the session.
--
-- The list changes between clients and the id cannot be told from a level or a group size by
-- size alone, which is why this file has always refused to unpack it by position. But it can be
-- *asked about*: `GetQuestLink` takes an id - the client says so outright, *Usage:
-- GetQuestLink(questID)* - and answers with a link carrying the quest's title. So a candidate
-- is handed over and the answer read back (§2.1), which is the same discipline as everywhere
-- else in Family.
--
-- **And it works in every language for free**, because both sides of the comparison come from
-- the client: the title in the log and the title in the link are the same client's words, and
-- nothing here is matched against a word Family wrote down.
--
-- Measured on TBC 2026-09-05, after a member's quests were found to have no ids at all: this
-- client answers title, level, nil, false, false, 1, 1, 9794 - and 9794 is the id. Nothing
-- below depends on it being the eighth.
local idColumn, idGivenUp, idTried = nil, false, 0

-- How many quests to ask about before deciding this client will not say. More than one,
-- because a single quest the client happens not to link would otherwise settle it for the
-- whole session.
local ID_ATTEMPTS = 5

local function titleIn(link)
	if type(link) ~= "string" then return nil end
	return link:match("%[(.-)%]")
end

local function questIDAt(index, returns, title)
	local api = _G.C_QuestLog

	if api then
		-- Through a local first. A call that returns nothing at all hands tonumber no
		-- argument rather than a nil one, which is an error and not a nil.
		local answer = Family:TryCall(api.GetQuestIDForLogIndex, index)
		local id = tonumber(answer)
		if id and id > 0 then return id end
	end

	if type(returns) ~= "table" then return nil end
	if idColumn then return tonumber(returns[idColumn]) end
	if idGivenUp then return nil end

	-- The title and the level are the first two and are not it; everything after them is a
	-- candidate, and the client is asked about each in turn.
	for at = 3, returns.n or 0 do
		local candidate = tonumber(returns[at])
		if candidate and candidate > 0 then
			if titleIn(Family:TryCall(GetQuestLink, candidate)) == title then
				idColumn = at
				return candidate
			end
		end
	end

	idTried = idTried + 1
	if idTried >= ID_ATTEMPTS then idGivenUp = true end

	return nil
end

-- A heading that is shut, which is a heading whose quests the log will not list at all.
local function isCollapsed(entry, returns)
	if not entry.headerAt then return false end

	for index = entry.headerAt + 1, math.min(returns.n, entry.headerAt + 2) do
		if type(returns[index]) == "boolean" then return returns[index] end
	end

	return false
end

-- How far through a quest is. Asked for as objectives done out of objectives total rather
-- than as a yes or no, because "3 of 5 wolves" is the answer somebody wants and "not
-- complete" is not. A quest with no objectives at all - a delivery, a talk-to - reports
-- nothing rather than pretending to be at zero of zero.
local function progressOf(index, questID)
	local total = Family:TryCall(GetNumQuestLeaderBoards, index) or 0
	local done = 0

	-- Each objective as the client wrote it, kept alongside the count.
	--
	-- The count answers *how far*, and it is the only part worth a column. What it cannot
	-- answer is *which* - "2 of 4" says nothing about which two gems are still missing, and
	-- that is the question somebody hovering the row is asking. Reported from play
	-- 2026-09-05 with a screenshot of a tooltip listing all four requirements of a quest the
	-- panel said was two-thirds done.
	--
	-- The client will not answer it either, and this is the §2.1 case in reverse: a quest is
	-- described by id, and the description that comes back is about **whoever is being
	-- played**. Hovering another character's row and reading *You are on this quest* is the
	-- client answering a question about the player, printed beside somebody else's name. So
	-- the per-character half has to be recorded here or it does not exist.
	--
	-- **Stored as words, and they are the words of the client that read the log.** An
	-- objective has no identity of any kind on these clients - no id, no index that survives
	-- the quest being turned in - so unlike a profession (L-015) there is nothing to file it
	-- under but its own text. A log read on a French client reads in French afterwards, and
	-- that is a property of the data rather than a fault to be fixed later.
	local lines = {}

	local function keep(text, finished)
		if type(text) == "string" and text ~= "" then
			lines[#lines + 1] = { text = text, done = finished and true or nil }
		end
	end

	for objective = 1, total do
		local text, _, finished = Family:TryCall(GetQuestLogLeaderBoard, objective, index)
		if finished then done = done + 1 end
		keep(text, finished)
	end

	-- Mists moved the objectives to the quest id, and the older calls are gone with it.
	local api = _G.C_QuestLog
	if total == 0 and questID and api then
		total = Family:TryCall(api.GetNumQuestObjectives, questID) or 0
		for objective = 1, total do
			local text, _, finished = Family:TryCall(GetQuestObjectiveInfo, questID,
				objective, false)
			if finished then done = done + 1 end
			keep(text, finished)
		end
	end

	if total == 0 then return nil end
	return done, total, lines
end

--------------------------------------------------------------------------------------------
-- Expanding, and putting it back
--------------------------------------------------------------------------------------------

local function collapsedHeaders()
	local collapsed = {}
	local count = Family:TryCall(GetNumQuestLogEntries) or 0

	-- Noted by name rather than by index, because opening one heading moves every index
	-- below it and the list has to be walked again to put things back.
	for index = 1, count do
		local returns = pack(Family:TryCall(GetQuestLogTitle, index))
		local entry = interpretTitle(returns)

		if entry and entry.isHeader and isCollapsed(entry, returns) then
			collapsed[entry.title] = true
		end
	end

	return collapsed
end

-- Walked backwards and bounded by the count, for the same reason the skill list is: shutting
-- one heading moves every index below it, and a client that answers for an index past the
-- end would make a `while true` run until the game killed it.
local function restore(collapsed)
	if not next(collapsed) then return end

	local count = Family:TryCall(GetNumQuestLogEntries) or 0
	for index = count, 1, -1 do
		local entry = interpretTitle(pack(Family:TryCall(GetQuestLogTitle, index)))
		if entry and entry.isHeader and collapsed[entry.title] then
			Family:TryCall(CollapseQuestHeader, index)
		end
	end
end

--------------------------------------------------------------------------------------------

local scanning = false
local lastScan = 0

function Quests:IsScanning()
	return scanning
end

function Quests:Scan()
	if scanning then return end
	scanning = true

	local ok, err = pcall(function() self:ScanNow() end)

	scanning = false
	if not ok then error(err, 0) end
end

function Quests:ScanNow()
	local key = Family:CurrentMember()

	if type(GetNumQuestLogEntries) ~= "function" then
		Family:Debug("no quest log on this client")
		return
	end

	local collapsed = collapsedHeaders()
	Family:TryCall(ExpandQuestHeader, 0)          -- 0 means all of them

	local count = Family:TryCall(GetNumQuestLogEntries) or 0
	local entries = {}
	local category = nil
	local complete = 0

	-- Kept apart from `entries` on purpose, and the reason is the wire rather than the shape.
	--
	-- `Wide.lua` shares a payload key whole - `out.payload[key] = payload[key]` - so a field
	-- added inside `quests` starts crossing every link the moment it is written, without
	-- anybody deciding that it should. These are bulky, they are in one client's language,
	-- and the channel they would travel down is 200-byte chunks on a rate-limited channel
	-- shared with every other addon the player runs. So they live under a key no category
	-- lists, which is what makes "not shared" the state of the code rather than a promise.
	--
	-- Sharing them later is one entry in `CATEGORIES`, and a decision of its own.
	local objectives = {}

	for index = 1, count do
		-- Kept, because the id is found among these returns rather than asked for
		-- separately, and finding it means having them.
		local returns = pack(Family:TryCall(GetQuestLogTitle, index))
		local entry = interpretTitle(returns)

		if entry and entry.isHeader then
			-- A heading is where the quests below it are, and that is the whole of what
			-- it is worth keeping: it is written onto each quest rather than stored as a
			-- row of its own, so the panel can group, filter and sort freely.
			category = entry.title
		elseif entry then
			local questID = questIDAt(index, returns, entry.title)
			local done, total, lines = progressOf(index, questID)

			-- Filed under the title, which is what the panel has in its hand when it draws
			-- the row, and which the game keeps unique within one log - it will not hand a
			-- character the same quest twice. Never under the position in the list, which
			-- changes the moment anything is turned in.
			if lines and #lines > 0 then objectives[entry.title] = lines end

			if done and total and done >= total then complete = complete + 1 end

			entries[#entries + 1] = {
				title = entry.title,
				level = entry.level,
				id = questID,
				category = category,
				done = done,
				objectives = total,
			}
		end
	end

	restore(collapsed)

	-- §2.2: an empty log and a log that could not be read are different answers. Nothing is
	-- written unless the read got as far as producing a list, and the list is allowed to be
	-- empty - a member with no quests at all is a fact, once it has been seen.
	local payload = Family.Database:Payload(key) or {}
	payload.quests = { entries = entries, seen = time() }
	payload.questObjectives = objectives
	Family.Database:SetPayload(key, payload)

	Family.Database:SetMeta(key, {
		questCount = #entries,
		questsComplete = complete,
		questsSeen = time(),
		-- The cap is what makes the count mean anything: twenty of twenty-five is a
		-- different situation from twenty of a hundred.
		questMax = tonumber(_G.MAX_QUESTS) or nil,
	})

	lastScan = time()
	Family:Debug("scanned quests: %d in the log, %d ready to hand in", #entries, complete)
end

--------------------------------------------------------------------------------------------
-- When to scan
--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("quests", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "quests", function()
		Family:After(4, "quests", function() Quests:Scan() end)
	end)

	-- The moments the log genuinely changes. Few, deliberate, and always worth answering.
	for _, event in ipairs { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" } do
		Family:RegisterEvent(event, "quests", function()
			if Quests:IsScanning() then return end
			Family:After(2, "quests", function() Quests:Scan() end)
		end)
	end

	-- These two arrive constantly - one of them fires on every objective that ticks, and
	-- this scanner's own expanding and collapsing fires the other. Ignored during a scan,
	-- which stops a scan booking the next one for ever, and refused for a while after one,
	-- which stops the pair of them keeping the client permanently busy. Fifteen seconds is
	-- how stale a wolf count is allowed to get; anything that matters more than that has
	-- its own event above.
	local QUIET = 15

	for _, event in ipairs { "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED" } do
		Family:RegisterEvent(event, "quests", function()
			if Quests:IsScanning() then return end
			if (time() - lastScan) < QUIET then return end
			Family:After(2, "quests", function() Quests:Scan() end)
		end)
	end
end)
