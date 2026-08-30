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

-- `retrying` is set only by the retry below re-entering. Everything else - a login, a guild
-- change, the roster arriving - is a *fresh reason to ask*, and re-arms the attempts.
function Identity:Scan(retrying)
	local key = Family:CurrentMember()

	-- The counter bounds one series of attempts, not the session, and until this it did the
	-- second. Once five had gone by, every later scan incremented it, saw it was past the
	-- limit and gave up on its first try - so a client that was slow to name a guild once
	-- never asked again until the next login, however many times the game said the guild had
	-- changed. Seen on a freshly created guild: the character who had just made it was still
	-- recorded as being in none, and everything in §7 is keyed on that.
	--
	-- The harness had been resetting this by hand between checks, which is the tell: a fixture
	-- that has to reach into a scanner to make the next check possible is describing something
	-- a real caller cannot do.
	if not retrying then self.waitingForGuild = nil end

	local fields = {
		name = UnitName("player"),
		realm = GetRealmName(),
		level = UnitLevel("player"),
		classFile = select(2, UnitClass("player")),
		-- Four answers about one fact, because no single one of them is enough.
		-- raceFile is the language-neutral id and is what everything keys on; Races.lua
		-- turns it back into a word in the reader's language. raceID says the same thing
		-- and is what the client itself answers to. race is what this client called it,
		-- which is the game's own gendered word and beats any table - but only for a
		-- reader running the same language, so the language it is in is recorded with it.
		-- Without that, "Humaine" and "Humain" are two strings and nothing can say which
		-- of them a Spanish client is looking at.
		race = UnitRace("player"),
		raceFile = select(2, UnitRace("player")),
		raceID = select(3, UnitRace("player")),
		raceLocale = Family.locale,
		sex = UnitSex and UnitSex("player") or nil,
		faction = UnitFactionGroup("player"),
		hearth = Family:TryCall(GetBindLocation),
		-- hearthID is filled in below, not here: finding it costs a scan and the word is
		-- what says whether that scan is needed.
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

	-- The id of the place, so that every reader is told it in their own words rather than in
	-- whichever language and expansion happened to record it (L-020). Found only when the
	-- word has changed or was never resolved, because finding it means asking the client
	-- about every area id in turn - cheap once, wasteful on every scan, and a hearthstone
	-- moves about as often as a player decides to live somewhere else.
	local known = Family.Database:Meta(key)
	if fields.hearth and fields.hearth ~= "" then
		if not (known and known.hearthID and known.hearth == fields.hearth) then
			fields.hearthID = Family.Names:AreaFor(fields.hearth) or Family.CLEAR
		end
	elseif known and known.hearthID then
		fields.hearthID = Family.CLEAR
	end

	-- The guild, which is the one fact on this scan the client will not answer straight away.
	--
	-- **IsInGuild answers the moment the client loads and GetGuildInfo does not** - the same
	-- fact Scanners/Bank.lua sets out at length, and the same handling, because the cost of
	-- getting it wrong is higher here. The two read together say three different things:
	--
	--   in a guild, and named       record it
	--   in a guild, not yet named   the client has not caught up: keep what is held, ask
	--                               again in a moment, and give up after a few
	--   not in a guild              clear it, because SetMeta merges and a nil field is
	--                               skipped rather than written - so the last guild would sit
	--                               there for ever, and a character who left one would go on
	--                               being offered to it
	--
	-- Writing nothing in the middle case is what this did, and it cost a character their
	-- whole guild identity: everything in §7 is keyed by the guild a character is *recorded*
	-- as being in, so one whose scan landed in the gap was absent from the offering and read
	-- as "not running Family" on every guildmate's roster, while looking perfectly ordinary
	-- on every other panel. Nothing fires afterwards to put it right - PLAYER_GUILD_UPDATE
	-- has been and gone by then, and it is what scheduled the scan that missed.
	local canAsk = type(IsInGuild) == "function"
	local guild, rank, rankIndex = Family:TryCall(GetGuildInfo, "player")

	if type(guild) == "string" and guild ~= "" then
		self.waitingForGuild = nil
		fields.guild = guild
		fields.guildRank = rank
		fields.guildRankIndex = rankIndex
	elseif canAsk and Family:TryCall(IsInGuild) then
		self.waitingForGuild = (self.waitingForGuild or 0) + 1

		-- A few times and then it stops, for the reason the guild bank gives: a client that
		-- is going to answer does so within a few seconds, and a scanner waking up for ever
		-- is what "wait for it to arrive" turns into when it never does.
		if self.waitingForGuild > 5 then
			Family:Debug("in a guild and the client will not say which - none recorded")
		else
			Family:Debug("in a guild but it has no name yet - asking again")
			Family:After(3, "identity.guild", function() Identity:Scan(true) end)
		end
	elseif canAsk then
		self.waitingForGuild = nil
		fields.guild = Family.CLEAR
		fields.guildRank = Family.CLEAR
		fields.guildRankIndex = Family.CLEAR
	end
	-- ...and where the client has no IsInGuild at all, nothing is written either way. There
	-- is then no way to tell "not in a guild" from "has not said yet", and clearing on the
	-- second of those would take a guild away from somebody who is in one.

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

	-- The roster arriving is the client saying outright that it knows which guild this is,
	-- and it is the one event that says so. Kept apart from the list below because it fires
	-- constantly - every refresh, and a client with the guild frame open refreshes over and
	-- over - so it does nothing at all unless the fact it would settle is actually missing.
	Family:RegisterEvent("GUILD_ROSTER_UPDATE", "identity.roster", function()
		if not Family:TryCall(IsInGuild) then return end

		local meta = Family.Database:Meta(Family:CurrentMember())
		if meta and type(meta.guild) == "string" and meta.guild ~= "" then return end

		Family:After(1, "identity", function() Identity:Scan() end)
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
