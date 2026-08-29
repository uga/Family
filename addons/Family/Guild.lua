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
-- **That is the whole of the argument for the list above having no consent grid**, and it is
-- worth stating rather than leaving as an omission, because §6 spends a file insisting on the
-- opposite. A dialogue in front of a fact the game gives away for free does not protect
-- anybody; it teaches players to click through dialogues, which costs §6 its grid. So: no grid
-- for that list, one switch, and the switch works in both directions at once - a client with
-- this off neither asks nor answers.
--
-- **One thing is offered beyond that list, and it is the exception that has a grid**:
-- professions (§7.1). Inspect shows a guildmate's gear and talents and shows nobody's recipe
-- list, so the same argument that refuses a dialogue in front of the first demands one in
-- front of the second. The grid is our characters by their professions, it starts empty, and
-- nothing is offered until a box in it is ticked. It is not a second switch: guild share's
-- switch is the transport, and an empty grid already says "nothing".
--
-- It still ships off. Not because consent needs it - the argument above stands - but because
-- a first release that starts talking to a guild on somebody's behalf before they have asked
-- is a poor introduction, whatever it is saying. The panel is there and the switch is on it.
--
-- **Never** bags, bank, mail, quests, money, auctions, reputations. Not "not yet". Wanting a
-- guildmate's bags is a perfectly reasonable thing to want, and it is a Wide Family link.
--
-- The two features know nothing about each other and neither implies the other. Two routes to
-- the same fact would mean two places to look for it and two places to withdraw it, and the
-- second of those is what makes it a defect rather than a duplication.

local _, Family = ...

local L = Family.L

local Guild = {}
Family.Guild = Guild

local SCHEMA = 1

-- Recipe lists travel as their own kind with their own version (§7.1). `gdata` stays at
-- SCHEMA above: bumping it would make every 1.0.0 client drop the whole message and be
-- dropped in turn, while an unknown *kind* is discarded harmlessly (Comm.lua) - so a client
-- too old for this exchanges gear and talents exactly as it always did and simply never asks
-- for a recipe list.
local RECIPE_SCHEMA = 1

-- How many recipes one message may carry. A maxed primary is around 250 and weighs 983 bytes
-- on the wire, five chunks - measured, `tools/wire-size.lua`, not guessed. The cap is far
-- above that and exists only so that a client sending something absurd cannot make this one
-- spend a minute of channel on it.
local RECIPE_CEILING = 1000

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

	-- No default is written here. Whether guild share is on is Enabled()'s answer alone, and
	-- a value written at creation would be that answer made permanent by whichever version
	-- happened to create the file first.

	guild.known = guild.known or {}     -- guildKey -> memberKey -> what they sent
	guild.users = guild.users or {}     -- guildKey -> bare name -> when we last heard them
	guild.grants = guild.grants or {}   -- guildKey -> memberKey -> skill line -> true
	guild.recipes = guild.recipes or {} -- guildKey -> memberKey -> skill line -> what they can make
	guild.announced = guild.announced or {} -- guildKey -> what we last told them we can make

	-- Kept apart from `known` on purpose. Everything a player sends in `gdata` replaces
	-- everything held from that player, which is what makes a withdrawal take effect - and a
	-- recipe list is the one thing that must survive that, because it is asked for once and
	-- then never again while its fingerprint holds. Filed here, it is pruned deliberately
	-- when a profession stops being offered rather than swept away on every hello.

	-- The grid is created empty and stays empty until somebody ticks something, for the same
	-- reason nothing is written for the switch above: a value written at creation is a
	-- decision taken by whichever version happened to create the file, on behalf of a player
	-- who was never asked.

	return guild
end

-- Off until it is asked for, like Wide Family. Everything guild share carries is what the
-- game already shows anybody who targets you and presses Inspect, so consent is not the
-- argument - but a first release that starts talking to a guild on somebody's behalf,
-- however harmlessly, is not the first impression to make. The panel is there, the switch is
-- on it, and it takes one click.
function Guild:Enabled() return store().enabled == true end

function Guild:SetEnabled(on)
	store().enabled = on and true or false
	Family.Database:Changed("guild")
	return store().enabled
end

--------------------------------------------------------------------------------------------
-- What is offered, one character and one profession at a time (§7.1)
--------------------------------------------------------------------------------------------

-- Whether one of our characters offers one of its professions to one guild.
--
-- **Absence is the answer.** Nothing is written for a box that has never been ticked, so a
-- grid nobody has touched shares nothing and there is no default for a version to make
-- permanent - exactly as Enabled() has it a few lines above.
--
-- Keyed by the guild as well as by the character and the profession, because that is what was
-- agreed to: *this guild may see this*. A grant that followed its owner into the next guild
-- would not be a grant anybody had made.
function Guild:Shares(guildKey, memberKey, skillLine)
	if not (guildKey and memberKey and skillLine) then return false end

	local perMember = (store().grants[guildKey] or {})[memberKey]
	return (perMember and perMember[skillLine]) and true or false
end

-- Whatever was just decided, told to the guild - once, a few seconds after the last box was
-- ticked, rather than once per box.
--
-- **Prompt rather than at the next Update**, for the reason §6 gives and §7.1 repeats: the
-- half of an exchange that takes something away must not wait for somebody to press a button.
-- Nothing has to be sent to undo a grant - everything one player sends replaces everything
-- held from that player, so the next offering simply no longer contains what was withdrawn.
-- What has to happen is that a next offering happens at all.
--
-- Which is why this is an announcement marked as a change rather than a whisper each to
-- however many people run Family here. One small message, on the channel §7 built for small
-- messages, and everybody who hears it asks - including the ones whose traffic control would
-- otherwise have decided that what they hold from us is recent enough to skip.
local function offerChanged()
	Family.Database:Changed("guild")

	-- Family:After replaces a pending timer of the same name, so a player working down a grid
	-- of eight professions puts one message on the channel and not eight.
	Family:After(8, "guild.offer", function()
		if not Guild:Enabled() then return end
		if not Guild:Current() then return end
		Guild:AnnounceChange()
	end)
end

function Guild:SetShare(guildKey, memberKey, skillLine, on)
	if not (guildKey and memberKey and skillLine) then return false end

	local grants = store().grants
	grants[guildKey] = grants[guildKey] or {}
	grants[guildKey][memberKey] = grants[guildKey][memberKey] or {}
	grants[guildKey][memberKey][skillLine] = on and true or nil

	-- Emptied rather than left as a table of nothing. A grid that has been unticked should
	-- leave nothing behind on disk, and "has this character granted anything" should be one
	-- next() rather than a walk over keys that are all nil.
	if not next(grants[guildKey][memberKey]) then grants[guildKey][memberKey] = nil end
	if not next(grants[guildKey]) then grants[guildKey] = nil end

	offerChanged()
	return true
end

-- How much of one guild's grid is ticked, for a panel that wants to say so without walking it.
function Guild:CountShared(guildKey)
	local ticks, members = 0, 0

	for _, perMember in pairs((store().grants[guildKey]) or {}) do
		local any = false
		for _ in pairs(perMember) do ticks = ticks + 1; any = true end
		if any then members = members + 1 end
	end

	return ticks, members
end

--------------------------------------------------------------------------------------------
-- What a recipe list is, and how to tell two of them apart cheaply (§7.1)
--------------------------------------------------------------------------------------------

-- A cheap hash of the sorted spell ids, which with the count beside it is what says "this is
-- the list you already have" without sending the list.
--
-- Not a cryptographic digest and not trying to be: the question is whether a list has changed
-- since the last exchange, the two ends are cooperating, and the cost of a collision is one
-- stale list until the next recipe is learnt. Djb2 over the ids, modulo a prime below 2^24 so
-- that every intermediate stays exact in a double - Lua 5.1 has no integers, and a hash that
-- silently loses its low bits on one client and not another would answer differently at each
-- end, which is the one thing a fingerprint may not do.
local function fingerprintOf(spells)
	local hash = 5381

	for _, id in ipairs(spells) do
		hash = (hash * 33 + id) % 16777213
	end

	return hash
end

Guild.RECIPE_CEILING = RECIPE_CEILING

-- What one of our characters can make with one profession, in the shape it is stored and
-- compared in: spell ids, sorted, with the item each one makes beside it.
--
-- **Identifiers, never names** (§2.1). A recipe the client gave no id for cannot cross - a
-- name is one language, and the whole point is that a French list answers a German search -
-- so it is left out and *counted*, because a panel claiming a shorter list than it shows is
-- worse than one that says how many it could not carry.
function Guild:RecipesFor(memberKey, skillLine)
	local payload = Family.Database:Payload(memberKey)
	local record = payload and payload.professions and payload.professions[skillLine]

	if not (record and record.recipes) then return nil end

	local rows, missing = {}, 0

	for _, recipe in ipairs(record.recipes) do
		if type(recipe.spellID) == "number" then
			rows[#rows + 1] = { spell = recipe.spellID, item = tonumber(recipe.itemID) or 0 }
		else
			missing = missing + 1
		end
	end

	-- Sorted, because the fingerprint is over the order and two clients must agree on it.
	table.sort(rows, function(a, b) return a.spell < b.spell end)

	local spells, items = {}, {}
	for index, row in ipairs(rows) do
		spells[index] = row.spell
		items[index] = row.item
	end

	return spells, items, missing, fingerprintOf(spells), record.recipesSeen
end

-- The same, said in the two numbers that ride with the ranks: how many, and which list.
function Guild:RecipeMark(memberKey, skillLine)
	local spells, _, _, fingerprint = self:RecipesFor(memberKey, skillLine)
	if not spells then return nil end
	return #spells, fingerprint
end

-- Whether what we offer has changed since the guild was last told, and telling them if it has.
--
-- **The grid is not the only thing that changes an offering.** Opening a profession's window
-- for the first time gives a ticked profession a recipe list where it had none; learning one
-- recipe changes a list that was already there. Neither touches the grid, so neither went
-- through offerChanged - and the traffic control then did exactly what it exists to do: both
-- ends held recent gear and talents, so no exchange happened, so the new fingerprint never
-- crossed, so the list was never asked for.
--
-- Reported from a live guild, and the symptom is the worst kind: a profession ticked, its
-- window opened, everything on both panels correct, and nothing whatever on the wire. The
-- sending client's own diagnosis said "messages sent from here: 1".
--
-- What was last said is remembered per guild, so this is a comparison rather than a reason to
-- announce on every scan.
function Guild:MarkChanged()
	local guildKey = self:Current()
	if not guildKey then return false end

	local guild = store()
	local last = guild.announced[guildKey] or {}
	local now, changed = {}, false

	for memberKey, perMember in pairs(guild.grants[guildKey] or {}) do
		for line in pairs(perMember) do
			local count, fingerprint = self:RecipeMark(memberKey, line)
			local at = memberKey .. "/" .. tostring(line)

			-- A profession with no list yet is a state worth remembering as much as a
			-- list is: going from nothing to something is the change this exists for.
			now[at] = count and (count .. ":" .. fingerprint) or "-"
			if last[at] ~= now[at] then changed = true end
		end
	end

	for at in pairs(last) do
		if now[at] == nil then changed = true end
	end

	guild.announced[guildKey] = now

	if changed then
		Family:Debug("guild: what our characters can make has changed")
		offerChanged()
	end

	return changed
end

-- What we hold from somebody else, for one of their characters and one profession.
function Guild:HeldRecipes(guildKey, memberKey, skillLine)
	local perMember = ((store().recipes[guildKey] or {})[memberKey])
	return perMember and perMember[skillLine] or nil
end

-- Sorted ids differ by tens or hundreds and LibSerialize spends one byte on a small integer
-- and three on a large one, so what crosses is the gaps rather than the numbers - a sixth off
-- the whole message, measured in `tools/wire-size.lua`. Item ids stay absolute: they travel in
-- spell order and are therefore in no order of their own, and delta-encoding an unsorted run
-- makes it larger.
local function toDeltas(spells)
	local out, previous = {}, 0

	for index, id in ipairs(spells) do
		out[index] = id - previous
		previous = id
	end

	return out
end

local function fromDeltas(deltas)
	local out, running = {}, 0

	for index, gap in ipairs(deltas) do
		if type(gap) ~= "number" or gap < 0 then return nil end
		running = running + gap
		out[index] = running
	end

	return out
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

-- The professions one of our characters offers to this guild, with their ranks (§7.1).
--
-- Read from the record as it stands now, like everything else in the offering: a rank that
-- went up this evening goes out this evening, and a profession that has been dropped stops
-- being sent whether or not its box is still ticked.
--
-- **Identifiers, never names** (§2.1). A profession this client's skill line table has no id
-- for is filed under the word the client used, and a word is one language - so it cannot
-- cross. The grid does not offer those and says how many it left out rather than appearing to
-- share them; this is the other half of that promise, kept where the wire is.
local function sharedProfessions(guildKey, memberKey, meta)
	local out, seen = nil, {}

	for id, skill in pairs(meta.skills or {}) do
		-- A profession filed under a word rather than an id is still that profession where
		-- the skill line table knows the word, so it is looked up rather than refused. A
		-- member recorded by a version that had no ids, and not played since, is filed that
		-- way for every profession they have; the grid resolves them the same way, and both
		-- ends have to agree or a box could be ticked for something that never crossed.
		local line = type(id) == "number" and id or Family:SkillLineFor(id)

		if line and not seen[line] and Guild:Shares(guildKey, memberKey, line) then
			seen[line] = true
			out = out or {}

			-- The count and the fingerprint ride with the rank, and the list itself does
			-- not: that pair is what lets the other end decide whether to ask (§7.1). Two
			-- numbers against a thousand bytes, on a message that was going anyway.
			local count, fingerprint = Guild:RecipeMark(memberKey, line)

			out[#out + 1] = {
				skillLine = line,
				rank = tonumber(skill.rank) or 0,
				maxRank = tonumber(skill.maxRank) or 0,
				count = count,
				fingerprint = fingerprint,
			}
		end
	end

	-- Sorted, so that two clients holding the same grant build the same list. Slice 2's
	-- fingerprint is taken over a sorted list, and this is where that habit starts.
	if out then
		table.sort(out, function(a, b) return a.skillLine < b.skillLine end)
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
				-- Only what the grid says, and absent entirely when it says nothing.
				professions = sharedProfessions(guildKey, key, meta),
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
				professions = entry.professions,
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
				professions = entry.professions,
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

-- Everything about one guild: what it told us, who in it we have heard from, and what we
-- offered it.
--
-- The grid goes with the rest deliberately. A grant said *this guild may see this*, and a
-- guild we are no longer in is not the guild that was agreed to; rejoining it a year later
-- should present an empty grid rather than quietly resume sharing with whoever is in it now.
function Guild:Forget(guildKey)
	local guild = store()
	guild.known[guildKey] = nil
	guild.users[guildKey] = nil
	guild.grants[guildKey] = nil
	guild.recipes[guildKey] = nil
	Family.Database:Changed("guild")
end

-- Every guild we still hold something about, dropped unless one of our characters is still in
-- it. **This is Forget's caller**, and until now it had none: leaving a guild stopped you
-- *seeing* its records, because every panel looks them up by the guild being stood in, while
-- the records themselves sat on disk waiting to come back stale on a rejoin.
--
-- Decided from our own records rather than from the roster, because a roster is only ever
-- about the guild being stood in and can say nothing at all about the other one.
--
-- **Wrong in the safe direction on purpose.** A character's meta.guild is only refreshed when
-- that character is played (Scanners/Identity.lua), so one who was kicked while logged out
-- still reads as a member until their next login, and this keeps that guild a little too
-- long. That is the direction to be wrong in: keeping costs a stale record the next login
-- corrects, and dropping costs somebody the grid they ticked.
function Guild:ForgetLeft()
	local guild = store()

	local ours = {}
	local current = self:Current()
	if current then ours[current] = true end

	for _, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		local guildKey = self:Key(meta.guild, meta.realm)
		if guildKey then ours[guildKey] = true end
	end

	local stale = {}
	for _, held in ipairs { guild.known, guild.users, guild.grants, guild.recipes } do
		for guildKey in pairs(held) do
			if not ours[guildKey] then stale[guildKey] = true end
		end
	end

	local dropped = {}
	for guildKey in pairs(stale) do dropped[#dropped + 1] = guildKey end
	table.sort(dropped)

	for _, guildKey in ipairs(dropped) do
		Family:Debug("guild: dropping everything about %s - no character of ours is in it",
			guildKey)
		self:Forget(guildKey)
	end

	return dropped
end

-- Every recipe list we hold for a guild, for a caller that means to walk the lot. The search
-- is the only one: everything else asks about one thing and uses CraftersOf below.
function Guild:AllRecipes(guildKey)
	if not guildKey then return {} end
	return (store().recipes[guildKey]) or {}
end

-- Who in this guild can make this, found by identifier and never by name (§2.1).
--
-- Both ids are looked at, because both were sent: the spell is the pattern and the item is
-- the thing it makes, so hovering either one answers. That second id is the whole reason the
-- answer can appear on a crafted item and not only on a recipe.
--
-- **The answer is a person, not a character.** Guild records are keyed by whoever sent them,
-- so a row reads as *this player has a character who can make it* - and whispering the player
-- is what somebody does about it. Naming only the alt would name somebody who is not there.
function Guild:CraftersOf(spellID, itemID)
	local guildKey = self:Current()
	if not (guildKey and (spellID or itemID)) then return {} end

	local known = self:Known(guildKey)
	local found = {}

	for memberKey, perLine in pairs((store().recipes[guildKey]) or {}) do
		local entry = known[memberKey]

		for line, list in pairs(perLine) do
			local knows = false

			for index, spell in ipairs(list.spells or {}) do
				if (spellID and spell == spellID)
					or (itemID and itemID ~= 0 and (list.items or {})[index] == itemID) then
					knows = true
					break
				end
			end

			if knows and entry then
				local rank
				for _, profession in ipairs(entry.professions or {}) do
					if profession.skillLine == line then rank = profession.rank end
				end

				-- The older of the two ages, which is all an answer built from them can
				-- honestly claim. A list read a fortnight ago and heard from an hour ago
				-- is a fortnight old (§7.1).
				local age = list.at
				if list.seen and list.seen < age then age = list.seen end

				found[#found + 1] = {
					player = list.from or entry.from,
					key = memberKey,
					name = (entry.meta or {}).name or memberKey,
					classFile = (entry.meta or {}).classFile,
					level = (entry.meta or {}).level,
					skillLine = line,
					rank = rank,
					missing = list.missing,
					at = age,
				}
			end
		end
	end

	-- Whoever we heard from most recently first, then by name, so the list is the same
	-- twice running. Somebody deciding who to whisper reads it top down.
	table.sort(found, function(a, b)
		if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
		return tostring(a.name) < tostring(b.name)
	end)

	return found
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

-- The same announcement, marked as saying that what we offer has changed.
--
-- The traffic control in onHello skips the exchange when what the other end holds from us is
-- recent, which is right for a login and wrong for exactly this: a profession that has just
-- been withdrawn is the one case where what they hold being recent is the problem rather than
-- the reason to relax. So the mark, and one line in onHello that reads it.
--
-- A client too old to know the field ignores it and behaves as it always did. It has no
-- professions to be stale about, so there is nothing for it to be wrong about either.
function Guild:AnnounceChange()
	local guildKey = self:Current()
	if not guildKey then return false end

	Family:Debug("guild: announcing that what we share has changed")
	return say("ghello", "GUILD", nil, { changed = true })
end

-- Hello, said back to one person rather than to the guild.
--
-- The traffic control below skips the whole exchange when what we hold from somebody is
-- recent, and that was the only thing this client ever sent them - so somebody whose database
-- had been cleared, or who had reinstalled, announced to a guild full of clients that all
-- decided in silence that they had nothing to say, and their panel listed every one of them
-- as not running Family. What we hold from them says nothing about what they hold from us.
--
-- Marked as a reply, because a reply must never be answered with another one: two clients
-- that both have recent data would otherwise whisper hello at each other until one logs out.
function Guild:SayHelloBack(name)
	if type(name) ~= "string" or name == "" then return false end
	return say("ghello", "WHISPER", name, { reply = true })
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

-- Asking one player for one character's one profession, because the fingerprint they sent
-- does not match what we hold.
--
-- One profession per message rather than everything at once. A maxed primary is five chunks
-- and a character with five professions is fifteen, so asking for a family's worth in one
-- breath is the burst §7 spends its whole traffic control avoiding - and the answers arrive
-- one list at a time whatever we do.
function Guild:AskRecipes(name, memberKey, skillLine)
	if type(name) ~= "string" or name == "" then return false end
	if not (memberKey and skillLine) then return false end

	return say("gwantrec", "WHISPER", name, { member = memberKey, line = skillLine })
end

-- What one of ours can make, to the one person who asked for it. Bulk: it is the largest
-- thing §7 has ever carried, and nobody is watching the moment it lands.
function Guild:SendRecipes(name, memberKey, skillLine)
	local guildKey = self:Current()
	if not guildKey then return false end

	-- Offered, or not sent. The grid is consulted here as well as where the offering is
	-- built, because this message is answered on request rather than sent in a round: a
	-- request naming a profession that was ticked an hour ago and unticked since must be
	-- answered by today's grid, not by the one they last heard about.
	if not self:Shares(guildKey, memberKey, skillLine) then
		Family:Debug("guild: asked for %s on %s, which is not offered", tostring(skillLine),
			tostring(memberKey))
		return false
	end

	local spells, items, missing, fingerprint, seen = self:RecipesFor(memberKey, skillLine)
	if not spells then return false end

	return say("grec", "WHISPER", name, {
		rschema = RECIPE_SCHEMA,
		member = memberKey,
		line = skillLine,
		spells = toDeltas(spells),
		items = items,
		missing = missing,
		fingerprint = fingerprint,
		-- When *this* side last read the list, which is not when it was sent. A fact does
		-- not get younger by being posted (§2.2), and an answer built on this is only as
		-- current as the older of the two ages it was built from (§7.1).
		seen = seen,
	}, true)
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

	-- Somebody saying hello back, which is the whole of what that message is for: it has
	-- been counted and noted above, and answering it would start a conversation with no end
	-- to it.
	if body.reply then
		Family:Debug("guild: %s said hello back", tostring(sender))
		return
	end

	local held = Guild:CharactersOf(guildKey, sender)
	local newest
	for _, entry in ipairs(held) do
		if entry.at and (not newest or entry.at > newest) then newest = entry.at end
	end

	-- Answering is also asking, in one round trip, exactly as §6 does it - and both halves
	-- are skipped when what we hold is recent. This is the whole of the traffic control: a
	-- guild where everybody has met everybody costs nothing on login, which is what makes
	-- "kept once seen" affordable rather than a promise paid for by the channel.
	--
	-- Skipped, but not in silence. Being quiet here is what left a player who had cleared
	-- their saved variables looking at a guild of people their panel said were not running
	-- Family: every one of those clients held recent data from them, decided there was
	-- nothing to do, and sent nothing - and being heard from is the only way anybody knows
	-- anybody runs this at all (§7).
	--
	-- Except when they say outright that what they offer has changed, which is the one case
	-- where holding something recent is the problem: a withdrawn profession is undone by the
	-- next offering arriving, and skipping the exchange is precisely what would stop it.
	local quiet = (not body.changed) and newest and (time() - newest) < STALE_AFTER

	-- A moment later, and not the same moment for everybody: a guild logging in together
	-- would otherwise put every one of its clients on the channel at once. Both branches
	-- share the timer, because they are two answers to one hello and never both wanted.
	Family:After(2 + math.random() * 6, "guild.hello." .. tostring(bareName(sender)),
		function()
			if not Guild:Enabled() then return end
			if quiet then
				Family:Debug("guild: %s announced, and what we have is recent",
					tostring(sender))
				Guild:SayHelloBack(sender)
				return
			end
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

-- What arrived, kept only in the shape it was promised in: a skill line id, a rank and a
-- ceiling. Anything else is somebody else's client being wrong, and it is not written to our
-- disk on their say-so - a name that arrived where an id was expected would be a word stored
-- as an identity, which is the one mistake §2.1 exists to prevent.
local function readProfessions(list)
	if type(list) ~= "table" then return nil end

	local out = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and type(entry.skillLine) == "number" then
			out[#out + 1] = {
				skillLine = entry.skillLine,
				rank = tonumber(entry.rank) or 0,
				maxRank = tonumber(entry.maxRank) or 0,
				-- How many recipes and which list, where they sent them. Kept because
				-- this pair is the whole of the traffic control: without it every
				-- announcement is a reason to ask for a thousand bytes again. Absent
				-- from an older client, and absent is a fine answer - it means "no
				-- recipe list", which is exactly what an older client has.
				count = tonumber(entry.count),
				fingerprint = tonumber(entry.fingerprint),
			}
		end
	end

	if not next(out) then return nil end
	return out
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
			entry.professions = readProfessions(entry.professions)
			entry.from = sender
			entry.at = time()
			guild.known[guildKey][memberKey] = entry
			arrived = arrived + 1
		end
	end

	Family:Debug("guild: %d character(s) arrived from %s", arrived, tostring(sender))

	-- What they no longer offer, dropped; and what they offer that we do not hold, asked for.
	--
	-- Both fall out of the same walk, and both have to happen here rather than at the next
	-- Update: a withdrawn profession must stop being answerable the moment its owner says so,
	-- and a changed list is only known to have changed because this message said which list
	-- it is now.
	local recipes = store().recipes[guildKey]
	local wanted = {}

	for memberKey, entry in pairs(body.characters or {}) do
		local offered = {}

		for _, profession in ipairs(entry.professions or {}) do
			offered[profession.skillLine] = true

			-- Asked for only when the count or the fingerprint differs from what is held.
			-- A settled guild costs nothing after the day everybody met, which is what
			-- makes "once seen, it is kept" affordable for a list this size (§7.1).
			if type(profession.fingerprint) == "number" then
				local mine = Guild:HeldRecipes(guildKey, memberKey, profession.skillLine)

				if not mine or mine.fingerprint ~= profession.fingerprint
					or #mine.spells ~= (profession.count or -1) then
					wanted[#wanted + 1] = { memberKey, profession.skillLine }
				end
			end
		end

		-- A profession that has been unticked is absent from what just arrived, and the
		-- list we hold for it goes with it. Nothing has to be sent to take a grant away -
		-- this is the other end keeping the promise that nothing does.
		local mine = recipes and recipes[memberKey]
		if mine then
			for line in pairs(mine) do
				if not offered[line] then mine[line] = nil end
			end
			if not next(mine) then recipes[memberKey] = nil end
		end
	end

	-- Spread out, and one at a time. Fifteen lists is fifteen requests and forty-three chunks
	-- of answer; asking for them in one breath is the burst the queue exists to avoid.
	for index, want in ipairs(wanted) do
		Family:After(2 + index * 3, string.format("guild.recipes.%s.%s", want[1], want[2]),
			function()
				if not Guild:Enabled() then return end
				Guild:AskRecipes(sender, want[1], want[2])
			end)
	end

	Family.Database:Changed("guild")
end

local function onWantRecipes(_, text, sender)
	local body = Family.Codec:FromWire(text)
	local guildKey = forThisGuild(body)
	if not guildKey then return end

	noteUser(guildKey, sender)

	if type(body.member) ~= "string" or type(body.line) ~= "number" then return end

	Guild:SendRecipes(sender, body.member, body.line)
end

local function onRecipes(_, text, sender)
	local body = Family.Codec:FromWire(text)
	local guildKey = forThisGuild(body)
	if not guildKey then return end

	noteUser(guildKey, sender)

	-- Its own version, checked on its own. A mismatch here costs the recipe half and leaves
	-- gear and talents exchanging normally, which is the whole reason this is a separate
	-- kind rather than a bigger `gdata` (§7.1).
	if body.rschema ~= RECIPE_SCHEMA then
		Family:Debug("guild: %s writes recipe schema %s and this one reads %s",
			tostring(sender), tostring(body.rschema), tostring(RECIPE_SCHEMA))
		return
	end

	if type(body.member) ~= "string" or type(body.line) ~= "number" then return end
	if type(body.spells) ~= "table" then return end
	if #body.spells > RECIPE_CEILING then
		Family:Debug("guild: %s sent %d recipes for one profession - ignored",
			tostring(sender), #body.spells)
		return
	end

	local spells = fromDeltas(body.spells)
	if not spells then
		Family:Debug("guild: %s sent a recipe list that does not decode", tostring(sender))
		return
	end

	-- Only from somebody whose offering says this profession is theirs to send. An arriving
	-- list about a character we hold nothing for is a client answering a question nobody
	-- asked, and it is not written to our disk on its say-so (§2.3).
	local held = (store().known[guildKey] or {})[body.member]
	if not (held and bareName(held.from) == bareName(sender)) then
		Family:Debug("guild: %s sent recipes for %s, who is not theirs", tostring(sender),
			tostring(body.member))
		return
	end

	local items = {}
	if type(body.items) == "table" then
		for index = 1, #spells do items[index] = tonumber(body.items[index]) or 0 end
	end

	local guild = store()
	guild.recipes[guildKey] = guild.recipes[guildKey] or {}
	guild.recipes[guildKey][body.member] = guild.recipes[guildKey][body.member] or {}

	guild.recipes[guildKey][body.member][body.line] = {
		spells = spells,
		items = items,
		-- Recipes the other end could not share because their client gave no id for them.
		-- Carried across so that a panel can say a list is short rather than implying it
		-- is complete (§7.1).
		missing = tonumber(body.missing) or 0,
		fingerprint = tonumber(body.fingerprint) or fingerprintOf(spells),
		-- When it reached us, and when they last read it. Two ages, kept apart, because
		-- the older of the two is what any answer built on this carries (§7.1) and an
		-- older client sends only the first of them.
		at = time(),
		seen = tonumber(body.seen),
		from = sender,
	}

	Family:Debug("guild: %d recipe(s) for %s from %s", #spells, tostring(body.member),
		tostring(sender))
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
	--
	-- **Marked as a change, because that is what pressing the button means.** The traffic
	-- control skips the exchange when the other end holds something recent, which is right
	-- for a login and wrong for the one button somebody presses precisely because they think
	-- what they are looking at is stale. Update now that answers "no need" is a button that
	-- does nothing, and it looks identical to one that is broken.
	Family:Debug("guild: asked for an exchange (%s)", tostring(why or "asked for"))
	return self:AnnounceChange()
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

	-- Ours with no guild recorded at all, which is the state that hides a character from
	-- everything §7 does.
	--
	-- **Asked without the roster, deliberately.** The client only lists offline guild members
	-- when it has been told to, which is a setting on the game's own guild frame that this
	-- panel's Online only / Everyone button drives - so the first version of this, which
	-- cross-referenced the roster, could not see the one character it was written for: an alt
	-- played this morning and offline now. A check that cannot see the case it exists for is
	-- worse than no check, because it answers.
	--
	-- Noisy by nature and said plainly rather than filtered: most players have alts in no
	-- guild at all and those belong on this list too. What the reader is looking for is a name
	-- they know is in a guild.
	do
		local blank, extra = {}, 0

		for key, entry in pairs(Family.Database:Members()) do
			local meta = entry.meta or {}
			if meta.guild == nil then
				if #blank < 10 then
					blank[#blank + 1] = tostring(meta.name or key)
				else
					extra = extra + 1
				end
			end
		end

		table.sort(blank)

		if #blank > 0 then
			Family:Print(L["  characters of ours with no guild recorded: %s%s"],
				table.concat(blank, ", "),
				extra > 0 and string.format(L[" and %d more"], extra) or "")
			Family:Print(L["  |cff888888ordinary for one who is in no guild - but one that "
				.. "*is* in this guild stays missing from everything above until it has been "
				.. "logged into once|r"])
		end
	end

	-- The other two reasons a character of ours is not in the offering, named the same way.
	--
	-- **These went through the guild roster and no longer do.** The roster the client hands
	-- back holds offline members only when it has been told to - a setting this panel's Online
	-- only / Everyone button drives - so cross-referencing it was blind to exactly the case
	-- somebody runs a diagnosis about: an alt played this morning and offline now. It is the
	-- same fault as the no-guild line above had, and "on the roster by definition" was the
	-- reasoning that left it here after that one was fixed. The roster is not needed for either
	-- question: Offering() decides from our own records, so our own records can say why.
	if guildName then
		local elsewhere, otherGuild, more, moreGuilds = {}, {}, 0, 0

		for key, entry in pairs(Family.Database:Members()) do
			local meta = entry.meta or {}
			local name = tostring(meta.name or key)

			if meta.guild == nil then
				-- Said above, and not twice.
			elseif meta.guild ~= guildName then
				if #otherGuild < 10 then
					otherGuild[#otherGuild + 1] = string.format("%s (%s)", name,
						tostring(meta.guild))
				else
					moreGuilds = moreGuilds + 1
				end
			elseif meta.realm ~= realm then
				-- In this guild by name and left out anyway, which on connected realms is a
				-- thing that happens to characters who are genuinely in it: two members of
				-- one guild do not agree about what realm they are on (see Guild:Key), and
				-- Offering() takes the ones whose realm matches this character's.
				if #elsewhere < 10 then
					elsewhere[#elsewhere + 1] = string.format("%s (%s)", name,
						tostring(meta.realm))
				else
					more = more + 1
				end
			end
		end

		table.sort(otherGuild)
		table.sort(elsewhere)

		if #otherGuild > 0 then
			Family:Print(L["  recorded in another guild: %s%s"],
				table.concat(otherGuild, ", "),
				moreGuilds > 0 and string.format(L[" and %d more"], moreGuilds) or "")
			Family:Print(L["  |cff888888ordinary for an alt in a different guild - but one that "
				.. "*is* in this one is named under whichever guild it was last played in, and "
				.. "one login puts it right|r"])
		end

		if #elsewhere > 0 then
			Family:Print(L["  |cffffaa00in this guild but recorded on another realm, so they are "
				.. "not offered: %s%s (this character is on %s)|r"],
				table.concat(elsewhere, ", "),
				more > 0 and string.format(L[" and %d more"], more) or "",
				tostring(realm))
		end
	end

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

	-- What is actually shareable, and what has actually arrived (§7.1).
	--
	-- Both are invisible from the panel: a profession can be ticked and have nothing to send
	-- because its window has never been opened, and a list can be asked for and never turn
	-- up. Neither shows anywhere, and the last thing this project learned the expensive way
	-- is that state nobody can look at costs an evening the first time it is wrong.
	do
		local ticked, ready = 0, 0

		for memberKey, perMember in pairs((store().grants[guildKey]) or {}) do
			for line in pairs(perMember) do
				ticked = ticked + 1
				if self:RecipeMark(memberKey, line) then ready = ready + 1 end
			end
		end

		if ticked > 0 then
			Family:Print(L["  professions ticked: %d, of which %d have a recipe list to "
				.. "send"], ticked, ready)
			if ready < ticked then
				Family:Print(L["  |cff888888the rest share a rank and nothing else until "
					.. "that profession's window has been opened once|r"])
			end
		end

		local lists, recipes = 0, 0
		for _, perMember in pairs(self:AllRecipes(guildKey)) do
			for _, list in pairs(perMember) do
				lists = lists + 1
				recipes = recipes + #(list.spells or {})
			end
		end

		Family:Print(L["  recipe lists held from the guild: %d, %d recipe(s) in all"],
			lists, recipes)

		if lists == 0 and known > 0 then
			Family:Print(L["  |cff888888nothing yet: they arrive a few seconds after an "
				.. "exchange, and only for professions the other end has ticked and "
				.. "opened|r"])
		end
	end

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
	Family.Comm:On("gwantrec", whenEnabled(onWantRecipes))
	Family.Comm:On("grec", whenEnabled(onRecipes))

	-- A scan that gives a ticked profession something new to say is told to the guild, on the
	-- same debounce as a grid change - one message however many recipes were learnt.
	--
	-- Filtered on the key, because this handler's own work writes to the database under
	-- "guild" and answering that would be a loop. Everything else is a member being scanned.
	Family.Database:OnChanged("guild.offer", function(what)
		if what == "guild" then return end
		if not Guild:Enabled() then return end

		Family:After(6, "guild.marks", function()
			if Guild:Enabled() then Guild:MarkChanged() end
		end)
	end)

	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "guild", function()
		Family:After(ANNOUNCE_AFTER, "guild.hello", function()
			-- Ahead of the switch, because a guild none of our characters is in any more
			-- is not ours to keep whether or not we are talking to anybody. With the
			-- feature off there is nothing held and this costs one empty loop.
			Guild:ForgetLeft()

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
			-- The moment this is actually for: a guild left is a guild whose records and
			-- whose grid stop being ours the same evening, rather than at the next login.
			Guild:ForgetLeft()

			if not Guild:Enabled() then return end
			if Guild:Current() then Guild:Announce("guild changed") end
		end)
	end)
end)
