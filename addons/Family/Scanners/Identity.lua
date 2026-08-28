-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The small facts about a member: experience, time played, guild, where the hearthstone is.
--
-- All of it is cheap to read, none of it needs a window open, and every one of them belongs
-- in meta rather than payload (Database.lua) - the summary shows them for every member at
-- once, so they must not cost a decode each.
--
-- Time played is the exception to "cheap", and it is an odd one. It cannot be read at all:
-- the server sends it, unprompted at login and again whenever it is asked for, and asking
-- prints a line in the chat frame that the player did not ask to see. So Family listens for
-- it and does not ask - except once for a member it has never had it for, where one line is
-- a fair price for the number existing at all. /family played asks on demand.

local _, Family = ...

local Identity = {}
Family.Identity = Identity

--------------------------------------------------------------------------------------------

function Identity:Scan()
	local key = Family:CurrentMember()

	local fields = {
		name = UnitName("player"),
		realm = GetRealmName(),
		level = UnitLevel("player"),
		classFile = select(2, UnitClass("player")),
		-- Three answers about one fact, because no single one of them is enough.
		-- raceFile is the language-neutral id and is what everything keys on. raceID lets
		-- a later client name the race in whatever language it is running in, whoever
		-- recorded it. race is what this client called it, kept as the fallback for the
		-- clients that will not answer by id - the same shape as the talent-name exception
		-- (specification §4), and for the same reason.
		race = UnitRace("player"),
		raceFile = select(2, UnitRace("player")),
		raceID = select(3, UnitRace("player")),
		sex = UnitSex and UnitSex("player") or nil,
		faction = UnitFactionGroup("player"),
		hearth = Family:TryCall(GetBindLocation),
	}

	-- Experience stops existing at the level cap, and a zero would read as "no progress"
	-- rather than "finished". Left absent instead, and the interface says so.
	local maxLevel = Family:TryCall(GetMaxPlayerLevel) or 0
	if (fields.level or 0) < maxLevel or maxLevel == 0 then
		local xp, xpMax = UnitXP("player"), UnitXPMax("player")
		if xpMax and xpMax > 0 then
			fields.xp = xp
			fields.xpMax = xpMax
			fields.rested = Family:TryCall(GetXPExhaustion) or 0
		end
	else
		-- Cleared rather than left nil: SetMeta merges, so a nil would leave the last
		-- figures recorded before the cap sitting there for ever.
		fields.xp = Family.CLEAR
		fields.xpMax = Family.CLEAR
		fields.rested = Family.CLEAR
	end

	local guild, rank, rankIndex = Family:TryCall(GetGuildInfo, "player")
	fields.guild = guild
	fields.guildRank = rank
	fields.guildRankIndex = rankIndex

	Family.Database:SetMeta(key, fields)
end

--------------------------------------------------------------------------------------------
-- Time played
--------------------------------------------------------------------------------------------

-- Set while a request of ours is in flight, so the answer can be told apart from the one the
-- game sends by itself at login.
local asked = false

function Identity:RequestPlayed()
	asked = true
	Family:TryCall(RequestTimePlayed)
end

local function recordPlayed(total, atLevel)
	if not total then return end
	Family.Database:SetMeta(Family:CurrentMember(), {
		played = tonumber(total) or 0,
		playedAtLevel = tonumber(atLevel) or 0,
		playedSeen = time(),
	})
	Family:Debug("time played recorded: %s", tostring(total))
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("identity", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "identity", function()
		Family:After(2, "identity", function()
			Identity:Scan()

			-- Asked for only when this member has never had one, because asking costs a
			-- line in the chat frame that nobody requested.
			local meta = Family.Database:Meta(Family:CurrentMember())
			if not (meta and meta.played) then
				Family:After(8, "identity.played", function()
					local current = Family.Database:Meta(Family:CurrentMember())
					if not (current and current.played) then
						Identity:RequestPlayed()
					end
				end)
			end
		end)
	end)

	Family:RegisterEvent("TIME_PLAYED_MSG", "identity", function(_, total, atLevel)
		asked = false
		recordPlayed(total, atLevel)
	end)

	for _, event in ipairs {
		"PLAYER_XP_UPDATE",
		"UPDATE_EXHAUSTION",
		"PLAYER_LEVEL_UP",
		"PLAYER_GUILD_UPDATE",
		"HEARTHSTONE_BOUND",
		"PLAYER_UPDATE_RESTING",
	} do
		Family:RegisterEvent(event, "identity", function()
			Family:After(1, "identity", function() Identity:Scan() end)
		end)
	end
end)
