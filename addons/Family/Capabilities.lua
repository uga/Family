-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What this client can do.
--
-- §2.3 of the specification says capability is data, not branching, and that a feature the
-- client lacks is absent rather than empty. This is where that is decided, once.
--
--------------------------------------------------------------------------------------------
-- Why this file does not ask the client
--------------------------------------------------------------------------------------------
--
-- It used to. The idea was that asking beats assuming, because these clients have been given
-- things their expansions never shipped with - dual specialisation on Era and Burning
-- Crusade, currencies on Anniversary - so a table derived from expansion history is wrong
-- before it is written. That reasoning is still correct. What was wrong was believing the
-- client could answer.
--
-- Run against all three clients on 2026-08-08, the probes reported:
--
--   Era    achievements yes, currencies yes, guild bank yes   - none of them true
--   Mists  keyring yes                                        - gone since patch 4.2
--
-- Four wrong answers, against one useful one. The cause is not four bad probes; it is that
-- **the symbol surface of these clients is not evidence about the game they run.** They are
-- built from a codebase that has all of this in it. GetAchievementInfo, C_GuildBank and
-- KEYRING_CONTAINER exist on clients where achievements, guild banks and keyrings are not
-- features a player can use. Asking whether a function exists asks about the build, not
-- about the game.
--
-- Even behaviour-shaped questions did not save it: CanShowAchievementUI is as present, and
-- as affirmative, on a client with no achievements.
--
-- There turned out to be a third way for existence to mislead, and it is the nastiest:
-- **a function can exist and throw when called.** Anniversary carries GetNumSpecGroups and
-- answers "API unsupported in this version of World of Warcraft" the moment it is used. So
-- `if GetNumSpecGroups then` is not merely uninformative, it is a trap - it passes, and then
-- the call it guards takes the scan down. Anything not present on all three clients is
-- therefore *called* through Family:TryCall rather than tested for.
--
-- So the table below is the answer, and it is authoritative. It is not a guess dressed up as
-- a fallback - it is researched, and increasingly it is *observed*, which is the only source
-- that has been right every time. Where an entry has been checked in a running client it
-- says so, and /family caps shows which.
--
-- The probes are kept, and they no longer decide anything. They run as a diagnostic: when
-- one disagrees with the table, /family caps says so, and a human goes and looks. That keeps
-- the early warning if a client ever changes underneath us, without letting the client's
-- symbol table vote on what the game contains.
--
-- **To correct an entry: play the client, look, and edit the table.** That is not a
-- limitation to apologise for. It is the same rule the rest of this project runs on - the
-- specification comes from behaviour, and behaviour means the game in front of you.

local _, Family = ...

local Capabilities = {}
Family.Capabilities = Capabilities

-- Expansion, from the interface number rather than a project constant: 11509 -> 1,
-- 20506 -> 2, 50504 -> 5. Version-agnostic, and it needs no constant per client.
local VANILLA, TBC, MISTS = 1, 2, 5

local function expansion()
	local _, _, _, interface = GetBuildInfo()
	return math.floor((tonumber(interface) or 11509) / 10000)
end

--------------------------------------------------------------------------------------------
-- The table
--
-- Marked entries have been seen in a running client and are settled. Unmarked ones are
-- researched expectations and are the ones to check first if something looks wrong.
--------------------------------------------------------------------------------------------

local EXPECTED = {
	guildBank    = { [VANILLA] = false, [TBC] = true,  [MISTS] = true  },
	dailyQuests  = { [VANILLA] = false, [TBC] = true,  [MISTS] = true  },
	-- Burning Crusade is the one people correct us on, and the table is right: Blizzard
	-- builds all of these from one codebase, so Anniversary ships the whole achievement API
	-- and the game behind it has no achievements. The client carrying the call is a fact
	-- about the build, not about the game - which is the whole thesis of this file.
	achievements = { [VANILLA] = false, [TBC] = false, [MISTS] = true  },
	currencies   = { [VANILLA] = false, [TBC] = true,  [MISTS] = true  },
	dualSpec     = { [VANILLA] = true,  [TBC] = true,  [MISTS] = true  },
	talentTrees  = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false },
	glyphs       = { [VANILLA] = false, [TBC] = false, [MISTS] = true  },
	keyring      = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false },
	ammoBags     = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false },
	transmogrify = { [VANILLA] = false, [TBC] = false, [MISTS] = true  },
}

-- Checked in the game. 2026-08-08 unless noted.
local CONFIRMED = {
	achievements = { [VANILLA] = true, [TBC] = true, [MISTS] = true },
	currencies   = { [VANILLA] = true, [TBC] = true, [MISTS] = true },
	dualSpec     = { [VANILLA] = true, [TBC] = true, [MISTS] = true },
	guildBank    = {                   [TBC] = true, [MISTS] = true },
	keyring      = { [VANILLA] = true, [TBC] = true                 },
	glyphs       = {                                 [MISTS] = true },
}

--------------------------------------------------------------------------------------------
-- Diagnostics only
--
-- These decide nothing. They exist so that a client changing underneath the table is
-- noticed by a person rather than discovered by a bug. Every one of them is known to lie on
-- at least one client, which is the entire point of them no longer being trusted.
--------------------------------------------------------------------------------------------

-- Where a probe can *call* something rather than merely look for it, it does. That is a
-- strictly better question, because these clients ship functions that exist and throw:
--
--     Script_GetNumSpecGroups: API unsupported in this version of World of Warcraft.
--
-- GetNumSpecGroups is present on Anniversary and answers that when called, which is how
-- dualSpec came back "confirmed" here on the strength of nothing at all. Calling through
-- Family:TryCall turns that into an honest no.
local PROBE = {
	guildBank    = function() return GetNumGuildBankTabs ~= nil or C_GuildBank ~= nil end,
	achievements = function() return GetAchievementInfo ~= nil end,
	glyphs       = function() return GetNumGlyphSockets ~= nil or C_GlyphInfo ~= nil end,
	keyring      = function() return KEYRING_CONTAINER ~= nil end,
	dualSpec     = function()
		local count = Family:TryCall(GetNumSpecGroups)
			or Family:TryCall(GetNumTalentGroups)
		return (tonumber(count) or 1) > 1
	end,
	currencies   = function()
		return (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize ~= nil)
			or GetCurrencyListSize ~= nil
	end,
}

--------------------------------------------------------------------------------------------

function Capabilities:Detect()
	local xpac = expansion()
	self.expansion = xpac
	self.name = (xpac == VANILLA and "Classic Era")
		or (xpac == TBC and "Burning Crusade")
		or (xpac == MISTS and "Mists of Pandaria")
		or ("interface " .. xpac)

	self.can = {}
	self.source = {}
	self.disagrees = {}

	for feature, byExpansion in pairs(EXPECTED) do
		local answer = byExpansion[xpac]
		if answer == nil then answer = false end

		self.can[feature] = answer
		self.source[feature] = (CONFIRMED[feature] and CONFIRMED[feature][xpac])
			and "seen in game" or "expected"

		local probe = PROBE[feature]
		if probe then
			local ok, found = pcall(probe)
			if ok and (found and true or false) ~= answer then
				self.disagrees[feature] = found and "client has the symbol"
					or "client lacks the symbol"
				Family:Debug("capability %s: table says %s, %s - worth a look, not a change",
					feature, tostring(answer), self.disagrees[feature])
			end
		end
	end
end

-- Family.Capabilities:Has("guildBank"). Unknown names answer false rather than nil, so a
-- typo disables a feature instead of erroring in the middle of a scan.
function Capabilities:Has(feature)
	return self.can and self.can[feature] or false
end

-- Everything, sorted, with where the answer came from and whether the client's symbols
-- disagree. /family caps prints this.
function Capabilities:Report()
	local names = {}
	for feature in pairs(self.can or {}) do names[#names + 1] = feature end
	table.sort(names)

	local report = {}
	for _, feature in ipairs(names) do
		report[#report + 1] = {
			feature = feature,
			answer = self.can[feature],
			source = self.source[feature] or "expected",
			disagrees = self.disagrees and self.disagrees[feature] or nil,
		}
	end
	return report
end
