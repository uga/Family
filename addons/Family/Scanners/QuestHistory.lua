-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The quests a character has already handed in, for *which of my characters has done this*.
--
-- Backlog 92. One route answers on all three builds, measured 2026-09-20: `GetQuestsCompleted`
-- fills the table it is handed with the ids of every quest this character has finished - 1099 of
-- them in 4 ms on an Era level 60 - and nothing has to be asked of the server first. So the whole
-- history is read again at login and after every turn-in, rather than appended to: a read that
-- costs milliseconds is cheaper than keeping two copies of the truth agreeing.
--
-- **Stored as flags against one family list, never as a table of ids.** Records are kept plain
-- since backlog 74, and the client writes a list of numbers to the saved variables one line per
-- number - a thousand of them per character, more on the later builds, and families here reach two
-- hundred characters. See `Encode` for the shape.
--
-- **Not shared yet.** No Wide Family category lists `questsDone`, so it stays on this machine. The
-- grant grid has no room for a fourteenth column, and putting it inside *Quests* would widen a
-- consent already given; both are Alberto's to decide.

local _, Family = ...

local QuestHistory = {}
Family.QuestHistory = QuestHistory

--------------------------------------------------------------------------------------------
-- The string
--------------------------------------------------------------------------------------------

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function base36(number)
	if number == 0 then return "0" end
	local out = ""
	while number > 0 do
		local digit = number % 36
		out = DIGITS:sub(digit + 1, digit + 1) .. out
		number = math.floor(number / 36)
	end
	return out
end

-- **One list for the family, and a row of flags for each character** - Alberto, 2026-09-23: *the
-- quests in game are a finite number; store the quests that anybody has done, plus, for each of
-- them, the flags of who has completed it.* Two characters of one level have done most of the
-- same quests, so writing each id once for the family and one bit per character against it is
-- what keeps two hundred characters from carrying two hundred copies of the same few thousand ids.
--
-- **The family list only grows, at its end.** A quest nobody had done is appended, and what is
-- already there never moves - so a character's flags, written against the list as it was, stay
-- right however many ids are added after them. Nothing is ever taken out: a character deleted
-- leaves ids nobody else holds, which cost a few bytes each and are otherwise harmless.
--
-- The list is `FamilyDB.questPool`, the ids in the order they were first seen, in base 36 and
-- separated by commas - about four bytes an id, once. A character's flags are six to a character,
-- so a family that has handed in five thousand different quests costs each character about 830
-- bytes, whatever the ids are. The first character says the shape, `p`, so a later one can be
-- told apart.
local MAP = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local MAP_VALUE = {}
for index = 1, #MAP do MAP_VALUE[MAP:sub(index, index)] = index - 1 end

-- The family list, unpacked once a session: `ids` in order, and `at[id]` its place.
local pool

local function thePool()
	if pool then return pool end
	pool = { ids = {}, at = {} }
	local text = type(FamilyDB) == "table" and FamilyDB.questPool or nil
	for word in (type(text) == "string" and text or ""):gmatch("[^,]+") do
		local id = tonumber(word, 36)
		if id and not pool.at[id] then
			pool.ids[#pool.ids + 1] = id
			pool.at[id] = #pool.ids
		end
	end
	return pool
end

-- Forgotten when the saved list is replaced from outside, which only the harness does.
function QuestHistory:ForgetPool() pool = nil end

function QuestHistory:PoolSize() return #thePool().ids end

function QuestHistory:Encode(ids)
	local held = thePool()

	-- New ids go on the end, smallest first so that the same history always grows the list
	-- the same way.
	local fresh = {}
	for _, id in ipairs(ids) do
		if not held.at[id] then
			held.at[id] = -1
			fresh[#fresh + 1] = id
		end
	end
	if #fresh > 0 then
		table.sort(fresh)
		local words = {}
		for _, id in ipairs(fresh) do
			held.ids[#held.ids + 1] = id
			held.at[id] = #held.ids
			words[#words + 1] = base36(id)
		end
		local was = FamilyDB.questPool
		FamilyDB.questPool = (type(was) == "string" and was ~= "")
			and (was .. "," .. table.concat(words, ",")) or table.concat(words, ",")
	end

	local chunks, highest = {}, 0
	for _, id in ipairs(ids) do
		local place = held.at[id]
		local chunk = math.floor((place - 1) / 6) + 1
		if chunk > highest then
			for fill = highest + 1, chunk do chunks[fill] = 0 end
			highest = chunk
		end
		local bit = 2 ^ ((place - 1) % 6)
		if math.floor(chunks[chunk] / bit) % 2 == 0 then chunks[chunk] = chunks[chunk] + bit end
	end

	local out = {}
	for index = 1, highest do out[index] = MAP:sub(chunks[index] + 1, chunks[index] + 1) end
	return "p" .. table.concat(out)
end

-- The ids back, as a set. Kept per string, so a history is unpacked once however often it is
-- asked about; a new reading is a new string, and flags already written never change meaning.
local unpackedByText = {}

function QuestHistory:Decode(text)
	if type(text) ~= "string" or text:sub(1, 1) ~= "p" then return {} end
	local held = unpackedByText[text]
	if held then return held end

	local ids = thePool().ids
	local set = {}
	for index = 2, #text do
		local value = MAP_VALUE[text:sub(index, index)]
		if not value then
			set = {}
			break
		end
		for bit = 0, 5 do
			if value % 2 == 1 then
				local id = ids[(index - 2) * 6 + bit + 1]
				if id then set[id] = true end
			end
			value = math.floor(value / 2)
		end
	end
	unpackedByText[text] = set
	return set
end

--------------------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------------------

-- Every id this character has finished, or nil where the client cannot say.
--
-- The call fills the table it is handed, keyed by id - the probe counted its keys and asked
-- `IsQuestFlaggedCompleted` about one of them, which answered true. A client that hands back a
-- table of its own instead is believed too.
function QuestHistory:Read()
	if type(_G.GetQuestsCompleted) ~= "function" then return nil end

	local into = {}
	local answer = Family:TryCall(GetQuestsCompleted, into)
	local source = next(into) and into or (type(answer) == "table" and answer or into)

	local ids = {}
	for id, done in pairs(source) do
		local number = tonumber(id)
		if done and number and number > 0 and number == math.floor(number) then
			ids[#ids + 1] = number
		end
	end
	return ids
end

function QuestHistory:Scan()
	local key = Family:CurrentMember()
	if not key then return end

	local ids = self:Read()
	if not ids then
		Family:Debug("no quest history on this client")
		return
	end

	-- An empty history is an answer: a character on its first quest has finished nothing.
	local payload = Family.Database:Payload(key) or {}
	payload.questsDone = self:Encode(ids)
	Family.Database:SetPayload(key, payload, { "questsDone" })

	Family.Database:SetMeta(key, { questsDoneCount = #ids })
	Family:Debug("scanned quest history: %d finished", #ids)
end

-- Whether this member has finished this quest: true, false, or nil where their history has
-- never been read.
function QuestHistory:Done(memberKey, questID)
	local payload = Family.Database:Payload(memberKey)
	local text = payload and payload.questsDone
	if text == nil then return nil end
	return self:Decode(text)[tonumber(questID) or -1] == true
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("questHistory", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "questHistory", function()
		Family:After(6, "questHistory", function() QuestHistory:Scan() end)
	end)

	-- A few seconds after a turn-in, so the client has filed the quest before it is asked.
	Family:RegisterEvent("QUEST_TURNED_IN", "questHistory", function()
		Family:After(3, "questHistory", function() QuestHistory:Scan() end)
	end)
end)
