-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Which instances each character is saved to, and when each lock lets go.
--
-- Backlog 93. The answer is read while the character is being played, like everything else
-- Family knows, and kept as the **moment** the lock resets rather than the seconds the client
-- hands over: seconds left written down yesterday are wrong today (`Cooldowns.lua` says this at
-- length, and `resetAt` rounds to the minute in `Codec.lua`'s `DEADLINES` for the same reason
-- `readyAt` does).
--
-- **The list is read when `UPDATE_INSTANCE_INFO` says so, and never beside the request.** Measured
-- on Mists 2026-09-21: a row already present answered *not locked* next to `RequestRaidInfo` and
-- *locked* when the event arrived (DATASOURCES, *And Mists answers the same fourteen columns*). A
-- reader that took the early answer would have had a lockout and called it unlocked.
--
-- **Fourteen values, kept by position only where the row is the row that was measured.** Era,
-- Burning Crusade and Mists all answered fourteen, saved or not. The fourteenth is the instance's
-- id in the client's `Map` table and it is what a lockout is keyed by, beside the difficulty's id
-- - a heroic and a normal of one place are two locks. The first and tenth are words in the
-- client's language, so they travel as labels and never as keys, the way a currency's name does:
-- nothing on these builds turns 469 back into *Blackwing Lair* for a reader in another language.
--
-- **No boss progress.** Columns 11 and 12 read like bosses and bosses down on Era and were both
-- retracted on Mists, where a lock with bosses killed on it answered `1` and `0` and the game's own
-- Raid Information window drew no progress either. Nothing here claims one.

local _, Family = ...

local Lockouts = {}
Family.Lockouts = Lockouts

--------------------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------------------

-- The width of the row that was measured, on all three builds. A row of another length is not
-- that row, and its fourteenth value is not trusted to be an instance's id.
local MEASURED_ROW = 14

-- Every value the call answered, and how many. Called through `pcall` here rather than
-- `Family:TryCall`, whose `unpack` of a table with holes in it cannot promise a count: a row with a
-- nil in it would come back short, and the width is what says which row this is.
local function rowFrom(ok, ...)
	if not ok then return {}, 0 end
	return { ... }, select("#", ...)
end

local function wholePositive(value)
	local number = tonumber(value)
	if not number or number <= 0 or number ~= math.floor(number) then return nil end
	return number
end

-- One lock, or nothing if this row is not one.
--
-- A character saved to nothing still gets a row back - `nil 0 nil 0 false ...`, read on all
-- three builds - so an absent name is the "no lockout" answer and not a fault. A row that is not
-- locked and not extended is a lock that has run out and is only still listed so that it can be
-- extended; it holds nobody, and is not recorded.
local function lockFrom(row, width, now)
	local name = row[1]
	if type(name) ~= "string" or name == "" then return nil end

	local left = tonumber(row[3])
	if not left or left <= 0 then return nil end
	if row[5] ~= true and row[6] ~= true then return nil end

	local instance = width == MEASURED_ROW and wholePositive(row[14]) or nil
	local difficulty = wholePositive(row[4])
	local label = row[10]
	if type(label) ~= "string" or label == "" then label = nil end

	-- By id where there is one, and by the word only where there is not: a name will not line
	-- up across two languages, but it is better than no lock at all.
	local key = (instance and ("i" .. instance) or ("n:" .. name))
		.. ":" .. tostring(difficulty or 0)

	return {
		key = key,
		instance = instance,
		difficulty = difficulty,
		name = name,
		difficultyName = label,
		-- The number the game's own window prints in grey under the name, and the one two
		-- players compare to find out whether they are in the same raid.
		lockID = wholePositive(row[2]),
		resetAt = now + math.floor(left),
		extended = row[6] == true or nil,
		raid = row[8] == true or nil,
		players = wholePositive(row[9]),
	}
end

-- Every lock the client reports for this character, or nil where the client has no way to ask.
function Lockouts:Read()
	if type(_G.GetNumSavedInstances) ~= "function"
		or type(_G.GetSavedInstanceInfo) ~= "function" then
		return nil
	end

	local count = tonumber((Family:TryCall(GetNumSavedInstances)))
	if not count then return nil end

	local now = time()
	local found = {}
	for index = 1, count do
		local row, width = rowFrom(pcall(GetSavedInstanceInfo, index))
		local lock = lockFrom(row, width, now)
		if lock then found[#found + 1] = lock end
	end

	table.sort(found, function(a, b)
		if a.resetAt ~= b.resetAt then return a.resetAt < b.resetAt end
		return a.key < b.key
	end)

	return found
end

-- The locks a member is still held by, soonest first. A recorded lock whose moment has passed
-- has let go whether or not anybody logged in to see it, so it is not drawn.
function Lockouts:For(meta)
	local live = {}
	local now = time()
	for _, lock in ipairs((meta or {}).lockouts or {}) do
		if (lock.resetAt or 0) > now then live[#live + 1] = lock end
	end
	return live
end

-- What a lock is called on a heading: the place, and the difficulty where the client named one.
function Lockouts:Label(lock)
	if lock.difficultyName then
		return string.format("%s  %s", tostring(lock.name), lock.difficultyName)
	end
	return tostring(lock.name)
end

--------------------------------------------------------------------------------------------
-- Recording
--
-- In meta, beside the crafting cooldowns, for the reason those are there: the summary reads
-- every member's without decoding anybody's payload, and there are a handful at most.
--------------------------------------------------------------------------------------------

function Lockouts:Scan()
	local key = Family:CurrentMember()
	if not key then return end

	local found = self:Read()
	if not found then
		Family:Debug("no instance lockouts on this client")
		return
	end

	-- **An empty list is an answer here**, unlike the currencies: it came with the event that
	-- says the server has spoken, and a character whose locks all ran out is saved to nothing.
	-- `lockoutsSeen` is what tells that nothing apart from a character never read.
	Family.Database:SetMeta(key, {
		lockouts = #found > 0 and found or Family.CLEAR,
		lockoutsSeen = time(),
	})

	Family:Debug("scanned %d instance lockouts", #found)
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("lockouts", function()
	-- Asked for, then read when the answer comes - at login, and again after a boss dies, which
	-- is when a lock is made. Whether the client also sends the event unasked at that moment has
	-- not been measured, so it is asked rather than waited for. A client without `BOSS_KILL`
	-- declines the registration and is read at the next login instead.
	local function ask()
		Family:After(5, "lockouts.ask", function() Family:TryCall(_G.RequestRaidInfo) end)
	end
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "lockouts", ask)
	Family:RegisterEvent("BOSS_KILL", "lockouts", ask)

	Family:RegisterEvent("UPDATE_INSTANCE_INFO", "lockouts", function()
		Family:After(1, "lockouts", function() Lockouts:Scan() end)
	end)
end)
