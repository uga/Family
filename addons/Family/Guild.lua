-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Guild share: a lighter Wide Family (§7).
--
-- It carries much less, and it carries it with much more automation. Those are the same
-- decision rather than two. Wide Family asks a player to approve one member and one category
-- at a time because it can reach anything a member owns; this reaches class, level, gear and
-- talents, and stops - which is precisely what the game already hands any guildmate who
-- targets you and presses Inspect. Family is not disclosing it. It is saving both of you the
-- trip, across characters who are not standing in front of you and at hours when neither of
-- you is online.
--
-- **That is the whole of the argument for it having no consent grid**, and it is worth stating
-- rather than leaving as an omission, because §6 spends a file insisting on the opposite. A
-- dialogue in front of a fact the game gives away for free does not protect anybody; it
-- teaches players to click through dialogues, which costs §6 its grid. So: on by default, one
-- switch, and the switch works in both directions at once - a client with this off neither
-- asks nor answers.
--
-- **Never** bags, bank, mail, quests, professions, money, auctions, reputations. Not "not
-- yet". Wanting a guildmate's bags is a perfectly reasonable thing to want, and it is a Wide
-- Family link.
--
-- The two features know nothing about each other and neither implies the other. Two routes to
-- the same fact would mean two places to look for it and two places to withdraw it, and the
-- second of those is what makes it a defect rather than a duplication.

local _, Family = ...

local L = Family.L

local Guild = {}
Family.Guild = Guild

local SCHEMA = 1

-- How old what we hold about somebody has to be before hearing from them is a reason to ask
-- again. This is the whole of the traffic control, and it is what makes "once seen, it is
-- kept" (§7) cheap rather than expensive: a guild of twenty Family users costs one round of
-- transfers on the day you meet them and nothing on the days after.
local STALE_AFTER = 6 * 3600

-- Long enough after entering the world that this character's own scanners have run, so what
-- goes out is who they are now rather than who they were while the client was still loading.
-- The same reasoning, and the same number, as Wide Family's announcement.
local ANNOUNCE_AFTER = 12

--------------------------------------------------------------------------------------------
-- Where it lives
--------------------------------------------------------------------------------------------

local function store()
	FamilyDB.guild = FamilyDB.guild or {}
	local guild = FamilyDB.guild

	-- On unless somebody says otherwise (§7). Written as "not false" rather than defaulted
	-- at creation, so a database written before this feature existed is on as well.
	if guild.enabled == nil then guild.enabled = true end

	guild.known = guild.known or {}     -- guildKey -> memberKey -> what they sent
	guild.users = guild.users or {}     -- guildKey -> bare name -> when we last heard them

	return guild
end

function Guild:Enabled() return store().enabled ~= false end

function Guild:SetEnabled(on)
	store().enabled = on and true or false
	Family.Database:Changed("guild")
	return store().enabled
end

--------------------------------------------------------------------------------------------
-- Which guild, and who of ours is in it
--------------------------------------------------------------------------------------------

-- A guild is filed under its name and the realm of whoever recorded it, which is the key the
-- guild bank uses too (Scanners/Bank.lua): two realms can have a guild of the same name.
--
-- **That key is ours alone and never crosses the wire.** On connected realms the members of
-- one guild do not agree about what realm they are on - the roster says "Eccebombo-
-- Thunderstrike" and "Petrise-Somewhere" of two people in the same guild - so a message
-- carrying this key would be dropped by everybody whose client answered GetRealmName
-- differently, which is how a guild of Family users can sit there reading "0 running Family".
-- What crosses is the guild's name, because that is the thing everybody in it agrees on.
function Guild:Key(name, realm)
	if type(name) ~= "string" or name == "" then return nil end
	if type(realm) ~= "string" or realm == "" then return nil end
	return name .. "-" .. realm
end

-- The guild the character being played is in, or nothing. Nothing is the ordinary answer for
-- a great many characters and is not a fault.
function Guild:Current()
	local name = Family:TryCall(GetGuildInfo, "player")
	local realm = Family:TryCall(GetRealmName)

	if type(name) ~= "string" or name == "" then return nil end
	if type(realm) ~= "string" or realm == "" then return nil end

	return self:Key(name, realm), name, realm
end

-- The shape of a build rather than the build itself: which trees, how many points in each,
-- and which of the two specialisations they are actually in.
--
-- **This is deliberately less than Family stores**, and the reason is the channel rather than
-- privacy. A full pair of trees is every talent's name, icon path, tier and column - some
-- kilobytes per character, and a player with five alts in the guild multiplies it by five,
-- and a guild where ten people run Family multiplies it again. The addon channel is shared
-- with every other addon in the guild and is rate limited for all of them together, so
-- sending whole trees to everybody at login would be Family taking the channel for a picture
-- almost nobody is looking at.
--
-- What is sent is exactly what the guild panel draws. Somebody who wants another player's
-- build talent by talent wants Wide Family, where it goes to one person who asked for it.
local function talentDigest(talents)
	if type(talents) ~= "table" or type(talents.groups) ~= "table" then return nil end

	local out = {
		system = talents.system,
		activeGroup = talents.activeGroup,
		groupCount = talents.groupCount,
		seen = talents.seen,
		groups = {},
	}

	for index, group in pairs(talents.groups) do
		local tabs
		if type(group.tabs) == "table" then
			tabs = {}
			for position, tab in ipairs(group.tabs) do
				tabs[position] = { name = tab.name, points = tab.points }
			end
		end

		out.groups[index] = {
			system = group.system,
			specID = group.specID,
			pointsSpent = group.pointsSpent,
			tabs = tabs,
		}
	end

	return out
end

-- Our own characters in that guild, in the shape they go over the wire.
--
-- Built now, from the records as they stand now, and never from what was sent last time -
-- the same rule as §6, and for the same reason: a character who left the guild has to stop
-- being in what we send, not merely stop being added to it.
function Guild:Offering()
	local guildKey, name, realm = self:Current()
	if not guildKey then return nil end

	local out = {}

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}

		if meta.guild == name and meta.realm == realm then
			local payload = Family.Database:Payload(key) or {}

			out[key] = {
				meta = {
					name = meta.name,
					realm = meta.realm,
					classFile = meta.classFile,
					race = meta.race,
					raceFile = meta.raceFile,
					level = meta.level,
					faction = meta.faction,
					guild = meta.guild,
					guildRank = meta.guildRank,
					itemLevel = meta.itemLevel,
				},
				equipment = payload.equipment,
				talents = talentDigest(payload.talents),
				-- When this side last looked, not when it was sent. A fact does not get
				-- younger by being posted (§2.2).
				seen = meta.lastSeen,
			}
		end
	end

	if not next(out) then return nil end
	return out, guildKey
end

--------------------------------------------------------------------------------------------
-- What we have been told
--------------------------------------------------------------------------------------------

-- A character name with the realm taken off, in lower case. The guild roster answers with
-- bare names and the addon channel answers with whatever the server calls the sender, which
-- is "Name" on some of these clients and "Name-Some Realm" on others. Comparing the two as
-- they stand matches on one client and not on the next.
local function bareName(name)
	if type(name) ~= "string" then return nil end
	return (name:match("^([^%-]+)") or name):lower()
end

function Guild:BareName(name) return bareName(name) end

local function noteUser(guildKey, sender)
	local bare = bareName(sender)
	if not (guildKey and bare) then return end

	local guild = store()
	guild.users[guildKey] = guild.users[guildKey] or {}
	guild.users[guildKey][bare] = time()
end

-- One of our own, in this guild. The client answering for them is this one, so whether they
-- run Family is not a question - and a panel telling you that you are not running the addon
-- you are reading it in is worse than no answer at all.
--
-- This is not a nicety. Our own announcement comes back to us off the guild channel and is
-- dropped as an echo, which is right; without this, the effect of that was your own row saying
-- "not running Family" on the one client in the guild you can be certain about.
function Guild:IsOurs(name)
	local bare = bareName(name)
	if not bare then return false end

	local _, guildName = self:Current()
	if not guildName then return false end

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		if meta.guild == guildName and bareName(meta.name or key) == bare then
			return true
		end
	end

	return false
end

-- Whether that guildmate has been heard from, which is the only way to know they run Family -
-- except for our own, who need no telling.  Somebody who runs it and has not been heard from
-- is invisible to this, and nothing on our side changes that (§7).
function Guild:RunsFamily(guildKey, name)
	local bare = bareName(name)
	if not (guildKey and bare) then return false end
	if self:IsOurs(name) then return true end
	return ((store().users[guildKey] or {})[bare]) and true or false
end

-- Everything we hold for a guild, keyed as the sender keyed it.
function Guild:Known(guildKey)
	if not guildKey then return {} end
	return (store().known[guildKey]) or {}
end

-- What we hold about one player: every character of theirs that is in this guild.
--
-- Found by the bare name of whoever sent it rather than by the character it is about,
-- because a player's alts are not named after them: the whole point is that Ceccardo and
-- Nervina are one person, and the only thing that says so is that one client sent both.
function Guild:CharactersOf(guildKey, playerName)
	local bare = bareName(playerName)
	local out = {}
	if not bare then return out end

	-- Ours come out of our own records rather than out of what anybody sent us, because
	-- nobody sent them: we do not whisper ourselves. Clicking your own row on the panel then
	-- shows the same thing every guildmate running Family sees of you, which is the honest
	-- answer to "what am I sharing".
	if self:IsOurs(playerName) then
		for memberKey, entry in pairs(self:Offering() or {}) do
			out[#out + 1] = { key = memberKey, meta = entry.meta or {},
				equipment = entry.equipment, talents = entry.talents,
				seen = entry.seen, at = entry.seen, from = playerName, ours = true }
		end

		table.sort(out, function(a, b)
			local levelA, levelB = a.meta.level or 0, b.meta.level or 0
			if levelA ~= levelB then return levelA > levelB end
			return tostring(a.meta.name or a.key) < tostring(b.meta.name or b.key)
		end)

		return out
	end

	for memberKey, entry in pairs(self:Known(guildKey)) do
		if bareName(entry.from) == bare then
			out[#out + 1] = { key = memberKey, meta = entry.meta or {},
				equipment = entry.equipment, talents = entry.talents,
				seen = entry.seen, at = entry.at, from = entry.from }
		end
	end

	table.sort(out, function(a, b)
		local levelA, levelB = a.meta.level or 0, b.meta.level or 0
		if levelA ~= levelB then return levelA > levelB end
		return tostring(a.meta.name or a.key) < tostring(b.meta.name or b.key)
	end)

	return out
end

-- When we last heard anything at all from that player, so a round of asking can skip the
-- people it heard from an hour ago.
function Guild:HeardFrom(guildKey, playerName)
	local bare = bareName(playerName)
	if not bare then return nil end
	return (store().users[guildKey] or {})[bare]
end

function Guild:Forget(guildKey)
	local guild = store()
	guild.known[guildKey] = nil
	guild.users[guildKey] = nil
	Family.Database:Changed("guild")
end

--------------------------------------------------------------------------------------------
-- Talking
--------------------------------------------------------------------------------------------

local function envelope(extra)
	local guildKey = Guild:Current()

	local _, guildName = Guild:Current()

	local body = {
		schema = SCHEMA,
		version = Family.version,
		character = Family:CurrentMember(),
		-- The guild's *name*, not our key for it. Named rather than assumed, because
		-- somebody in two guilds on two characters is ordinary and a message that did not
		-- say which one it was about would file one guild's gear under the other's name -
		-- but named in the one way everybody in the guild agrees on. See Guild:Key.
		guild = guildName,
	}

	for key, value in pairs(extra or {}) do body[key] = value end
	return body
end

local function say(kind, channel, target, extra, bulk)
	if not Guild:Enabled() then return false end
	if not Family.Codec:CanTalk() then return false end

	local body = Family.Codec:ToWire(envelope(extra))
	if not body then return false end

	Guild.stats.sent = Guild.stats.sent + 1
	return Family.Comm:Send(kind, body, channel, target, bulk)
end

-- Announcing to the guild that this client exists. Tiny, and the only thing that ever goes
-- to the guild channel: everything with any size in it is whispered to the one person who
-- asked for it, because the guild channel is shared with every other addon in the guild.
function Guild:Announce(why)
	local guildKey = self:Current()
	if not guildKey then return false, L["not in a guild"] end

	Family:Debug("guild: announcing (%s)", tostring(why or "login"))
	return say("ghello", "GUILD", nil, {})
end

function Guild:AskOne(name)
	if type(name) ~= "string" or name == "" then return false end
	return say("gwant", "WHISPER", name, {})
end

-- Everything of ours, to one person. Bulk: it is gear and talents for however many characters
-- we have in the guild, and nobody is watching the moment it lands.
function Guild:SendTo(name)
	local offering, guildKey = self:Offering()
	if not offering then return false, L["nothing of ours is in this guild"] end

	return say("gdata", "WHISPER", name, { characters = offering }, true)
end

--------------------------------------------------------------------------------------------
-- Receiving
--------------------------------------------------------------------------------------------

-- Whether a message is about the guild we are actually in. Anything else is dropped: it is
-- either a stray from a guild we have left or a client that has not noticed it changed guild,
-- and neither is a reason to write down somebody else's gear under our guild's name.
-- What has actually happened on the wire, counted at every point a message can be dropped.
--
-- Two clients in one guild, each seeing only itself, is a symptom with a dozen causes and no
-- way to tell them apart by looking at the panel: a message that never went, one that went and
-- never arrived, one that arrived and was dropped for the wrong guild, and one that arrived
-- and would not decode all look exactly alike from outside. So each is counted where it
-- happens and /family guild prints the lot.
--
-- This is not instrumentation added for one bug. The addon channel acknowledges nothing
-- (§11.1), so "did it work" is never answerable directly - only by counting what this end did
-- and comparing it with what the other end saw.
Guild.stats = { sent = 0, arrived = 0, echo = 0, otherGuild = 0, unreadable = 0, answered = 0 }

local function forThisGuild(body)
	local guildKey, guildName = Guild:Current()
	if not guildKey then return nil end
	if type(body) ~= "table" then return nil end
	if type(body.guild) ~= "string" then return nil end

	-- By name, and without case. The realm is deliberately not in this comparison (see
	-- Guild:Key), and the case is not either: a name that comes back from the roster and a
	-- name that comes back from GetGuildInfo have agreed on every client seen so far, and
	-- being wrong about that costs the whole feature silently.
	if body.guild:lower() ~= guildName:lower() then return nil end

	return guildKey
end

local function onHello(_, text, sender)
	Guild.stats.arrived = Guild.stats.arrived + 1

	local body = Family.Codec:FromWire(text)
	if type(body) ~= "table" then
		Guild.stats.unreadable = Guild.stats.unreadable + 1
		return
	end

	local guildKey = forThisGuild(body)
	if not guildKey then
		Guild.stats.otherGuild = Guild.stats.otherGuild + 1
		Guild.stats.lastOtherGuild = tostring(body.guild)
		return
	end

	-- Our own announcement comes back to us off the guild channel, and answering it would be
	-- this client whispering itself a copy of its own gear.
	if bareName(sender) == bareName(Family:TryCall(UnitName, "player")) then
		Guild.stats.echo = Guild.stats.echo + 1
		return
	end

	Guild.stats.answered = Guild.stats.answered + 1
	Guild.stats.lastHeard = tostring(sender)

	noteUser(guildKey, sender)
	Family.Database:Changed("guild")

	local held = Guild:CharactersOf(guildKey, sender)
	local newest
	for _, entry in ipairs(held) do
		if entry.at and (not newest or entry.at > newest) then newest = entry.at end
	end

	-- Answering is also asking, in one round trip, exactly as §6 does it - and both halves
	-- are skipped when what we hold is recent. This is the whole of the traffic control: a
	-- guild where everybody has met everybody costs nothing on login, which is what makes
	-- "kept once seen" affordable rather than a promise paid for by the channel.
	if newest and (time() - newest) < STALE_AFTER then
		Family:Debug("guild: %s announced, and what we have is recent", tostring(sender))
		return
	end

	-- A moment later, and not the same moment for everybody: a guild logging in together
	-- would otherwise put every one of its clients on the channel at once.
	Family:After(2 + math.random() * 6, "guild.hello." .. tostring(bareName(sender)),
		function()
			if not Guild:Enabled() then return end
			Guild:SendTo(sender)
			Guild:AskOne(sender)
		end)
end

local function onWant(_, text, sender)
	local body = Family.Codec:FromWire(text)
	local guildKey = forThisGuild(body)
	if not guildKey then return end

	noteUser(guildKey, sender)
	Guild:SendTo(sender)
	Family:Debug("guild: answered %s", tostring(sender))
end

local function onData(_, text, sender)
	local body = Family.Codec:FromWire(text)
	local guildKey = forThisGuild(body)
	if not guildKey then return end

	noteUser(guildKey, sender)

	if body.schema ~= SCHEMA then
		-- Named rather than guessed at, for the reason §6 states it as a requirement:
		-- getting this wrong corrupts records instead of failing visibly.
		store().problem = string.format("%s's Family writes schema %s and this one reads %s",
			tostring(sender), tostring(body.schema), tostring(SCHEMA))
		Family:Debug("guild: %s", store().problem)
		Family.Database:Changed("guild")
		return
	end

	store().problem = nil

	local guild = store()
	guild.known[guildKey] = guild.known[guildKey] or {}

	-- Everything this player sent replaces everything we held from this player, rather than
	-- being merged into it. A character of theirs who has left the guild is absent from what
	-- arrives, and a merge would keep them in our list for ever.
	local bare = bareName(sender)
	for memberKey, entry in pairs(guild.known[guildKey]) do
		if bareName(entry.from) == bare then guild.known[guildKey][memberKey] = nil end
	end

	local arrived = 0
	for memberKey, entry in pairs(body.characters or {}) do
		if type(entry) == "table" and type(entry.meta) == "table" then
			entry.from = sender
			entry.at = time()
			guild.known[guildKey][memberKey] = entry
			arrived = arrived + 1
		end
	end

	Family:Debug("guild: %d character(s) arrived from %s", arrived, tostring(sender))
	Family.Database:Changed("guild")
end

--------------------------------------------------------------------------------------------
-- Asking everybody, which is what the panel's Update now does
--------------------------------------------------------------------------------------------

function Guild:Refresh(why)
	if not self:Enabled() then return false, L["Guild share is switched off"] end
	if not Family.Codec:CanTalk() then
		return false, L["this client has no serialisation libraries, so nothing can be sent"]
	end

	local guildKey = self:Current()
	if not guildKey then return false, L["this character is not in a guild"] end

	-- One announcement rather than a whisper each. Everybody running Family hears it and
	-- answers, and everybody who is not is not troubled by a message they cannot read.
	return self:Announce(why or "asked for")
end

--------------------------------------------------------------------------------------------
-- What actually happened
--
-- Printed by /family guild test, and meant to be run on both clients and compared. Each line
-- is a thing that either did or did not happen on *this* end; put the two side by side and the
-- fault is wherever the two stop agreeing.
--------------------------------------------------------------------------------------------

function Guild:Diagnose()
	local guildKey, guildName, realm = self:Current()

	Family:Print(L["|cffffd700Guild share|r on %s"], Family.Capabilities.name)
	Family:Print(L["  switched on: %s"], self:Enabled() and "yes" or "|cffff5555no|r")
	Family:Print(L["  can serialise: %s"], Family.Codec:CanTalk() and "yes"
		or "|cffff5555no - LibSerialize/LibDeflate missing, nothing can be sent|r")
	Family:Print(L["  addon prefix registered: %s"], Family.Comm.registered and "yes"
		or "|cffff5555no - nothing will ever arrive|r")
	Family:Print(L["  guild: %s"], guildName and string.format("%s (realm %s)", guildName,
		tostring(realm)) or "|cffff5555not in one|r")

	local offering, _ = self:Offering()
	local mine = 0
	for _ in pairs(offering or {}) do mine = mine + 1 end
	Family:Print(L["  characters of ours in it: %d"], mine)

	local stats = self.stats
	Family:Print(L["  messages sent from here: %d"], stats.sent)
	Family:Print(L["  announcements arrived: %d  (%d ours coming back, %d for another guild, "
		.. "%d unreadable)"], stats.arrived, stats.echo, stats.otherGuild, stats.unreadable)
	Family:Print(L["  announcements from somebody else: %s"], stats.answered > 0
		and string.format("%d, last from %s", stats.answered, tostring(stats.lastHeard))
		or "|cffff5555none|r")

	if stats.otherGuild > 0 then
		-- The likeliest quiet failure: two clients that disagree about what the guild is
		-- called drop each other's messages and each look perfectly healthy doing it.
		Family:Print(L["  |cffffaa00last one was for %s, and this client calls the guild %s|r"],
			tostring(stats.lastOtherGuild), tostring(guildName))
	end

	local known = 0
	for _ in pairs(self:Known(guildKey)) do known = known + 1 end
	Family:Print(L["  characters held for this guild: %d"], known)

	if stats.sent > 0 and stats.arrived == 0 then
		Family:Print(L["|cffffaa00This client has sent and heard nothing at all, not even its "
			.. "own announcement coming back off the guild channel. That points at the "
			.. "channel rather than at either end.|r"])
	end
end

--------------------------------------------------------------------------------------------

local function whenEnabled(handler)
	return function(...)
		if not Guild:Enabled() then return end
		return handler(...)
	end
end

Family:OnDatabaseReady("guild", function()
	Family.Comm:On("ghello", whenEnabled(onHello))
	Family.Comm:On("gwant", whenEnabled(onWant))
	Family.Comm:On("gdata", whenEnabled(onData))

	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "guild", function()
		Family:After(ANNOUNCE_AFTER, "guild.hello", function()
			if not Guild:Enabled() then return end
			if not Family.Codec:CanTalk() then
				Family:Debug("guild: no serialisation libraries, so nothing can be shared")
				return
			end
			Guild:Announce("login")
		end)
	end)

	-- Changing guild changes which guild everything above is about, and the client says so
	-- some seconds after the world has loaded as often as not.
	Family:RegisterEvent("PLAYER_GUILD_UPDATE", "guild", function()
		Family:After(5, "guild.rejoin", function()
			if not Guild:Enabled() then return end
			if Guild:Current() then Guild:Announce("guild changed") end
		end)
	end)
end)
