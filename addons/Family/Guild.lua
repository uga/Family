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

-- How many cooldowns one profession may carry, for the same reason and with the same kind of
-- margin. A busy character has three or four of these across every profession they have; a
-- profession with forty of its own does not exist, so this can only ever catch a client
-- saying something absurd.
local COOLDOWN_CEILING = 40

-- The longest cooldown that can be believed, in seconds. Nothing in the game is on a timer of
-- days - the longest of them are a day, and a shutdown or a client with a wrong clock is what
-- produces a bigger number. A duration beyond this is dropped rather than turned into a
-- moment years away that no panel would ever stop showing.
local COOLDOWN_LONGEST = 7 * 86400

-- How old what we hold about somebody has to be before hearing from them is a reason to ask
-- again. This is the whole of the traffic control, and it is what makes "once seen, it is
-- kept" (§7) cheap rather than expensive: a guild of twenty Family users costs one round of
-- transfers on the day you meet them and nothing on the days after.
local STALE_AFTER = 6 * 3600

-- How long a player nobody has heard from goes on being answerable.
--
-- **This is a consent number, not a housekeeping one** (spec §7.1). A withdrawal is carried by
-- the next offering, and an offering has to be heard: two clients can only talk while both are
-- online and there is no offline mailbox, so somebody who unticks a profession and stops
-- playing goes on being answerable on every client that holds their last one, for as long as
-- that client keeps it. Dropping it is the only bound there is.
--
-- Fourteen days, chosen on an asymmetry rather than on taste. Dropping too early costs one
-- exchange: with nothing held from somebody, `quiet` in onHello is false, so their next hello
-- runs SendTo and AskOne and the record rebuilds itself. Dropping too late costs a consent
-- window nobody can close - not the person who withdrew, not the person holding it. A cheap,
-- self-repairing failure on one side and an unclosable one on the other argues short.
--
-- Not shorter, because a fortnight is the longest ordinary absence - a holiday, a busy month -
-- and anybody met inside it never expires at all. Past it they have stopped playing that
-- character, which is exactly the population whose withdrawal can never arrive by any other
-- route. Thirty days was considered for matching mail expiry and refused: it doubles the window
-- and saves no traffic, because the traffic is only ever paid by people who were not met.
local ABANDON_AFTER = 14 * 86400

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
	local was = store().enabled == true
	store().enabled = on and true or false
	Family.Database:Changed("guild")

	-- **Switching it on says so.** Being heard from is the only way anybody knows anybody runs
	-- this at all - §7, and `onHello` argues the same where the traffic control could swallow
	-- it - and until this, a player who turned guild share on stayed invisible to their guild
	-- until their next login, or until somebody else happened to announce and they answered.
	-- Reported from a live client: two characters, both switched on, and each panel went on
	-- reading "not running Family" about the other.
	--
	-- Marked as a change rather than sent as a plain hello, and for the reason Refresh is
	-- marked: the far end skips the exchange when what it holds from us is recent, and
	-- somebody who has this moment switched the feature on is precisely who that rule must not
	-- silence.
	--
	-- **Switching it off says nothing, and must not.** Off means this client neither asks nor
	-- answers, and a parting announcement would be it doing one last of both.
	--
	-- Only on the edge, so a panel that writes the same value twice does not put two messages
	-- on the channel.
	if store().enabled and not was then
		Family:After(2, "guild.enabled", function()
			if not Guild:Enabled() then return end
			if not Guild:Current() then return end
			if not Family.Codec:CanTalk() then return end
			Guild:AnnounceChange()
		end)
	end

	return store().enabled
end

--------------------------------------------------------------------------------------------
-- What is offered, one character and one profession at a time (§7.1)
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
-- Which professions guild share is even about
--------------------------------------------------------------------------------------------

-- Professions that make nothing anybody would ask a guildmate for.
--
-- Guild crafters answers one question - *who can make this* - so a profession that makes
-- nothing has no answer to give, and a tick box beside it is a box that does nothing. Five of
-- the fifteen the skill line table knows:
--
--   Herbalism, Fishing, Skinning   gather. There is no recipe list behind them at all.
--   Archaeology                    makes artifacts, on its own schedule rather than on
--                                  request, and the generated table has names for it in two
--                                  locales out of five (DATASOURCES §3).
--   First Aid                      makes bandages, and is excluded by decision rather than by
--                                  argument: everybody has it, it is trivial to level, and
--                                  nobody has ever whispered a guildmate for a bandage.
--
-- **Mining is not here**, and that is the one that needed deciding: it gathers, but it also
-- smelts, and "can you smelt these bars" is a real request.
--
-- Poisons and Runeforging need no entry. Neither has a skill line id at all, so §2.1 has
-- refused them since the wire was written - a profession filed under a word cannot cross.
--
-- An exclusion rather than a list of what is allowed, which is the shorter statement of the
-- decision and lets each entry carry its reason. The cost of that choice is stated rather than
-- hidden: a profession a future client adds is included until somebody puts it here.
local MAKES_NOTHING = {
	[129] = true,   -- First Aid
	[182] = true,   -- Herbalism
	[356] = true,   -- Fishing
	[393] = true,   -- Skinning
	[794] = true,   -- Archaeology
}

-- Whether guild share has anything to say about this profession at all.
--
-- One predicate, consulted by the grid that draws the boxes, by the count under it, and by the
-- wire. Three places that have to agree: a box drawn for something that never crosses is a box
-- that lies, and a count that includes it is a number that does not match the panel.
function Guild:Shareable(skillLine)
	if type(skillLine) ~= "number" then return false end
	return not MAKES_NOTHING[skillLine]
end

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

	-- Asked here rather than only where boxes are drawn, so that a grant ticked by a version
	-- that offered more professions than this one does stops counting the moment it is read.
	-- Nothing is deleted from the grid to achieve that: the tick is somebody's, it costs a
	-- few bytes, and a version that narrowed the perimeter is not a reason to throw away a
	-- decision they made.
	if not self:Shareable(skillLine) then return false end

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
		for line in pairs(perMember) do
			if Guild:Shareable(line) then ticks = ticks + 1; any = true end
		end
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
-- Over **both** ids, because on some clients only one of them exists and which one it is
-- differs by window. A hash over spells alone answered the same number for every Era trade
-- skill list, since every entry's spell is nought there.
local function fingerprintOf(spells, items)
	local hash = 5381

	for index, id in ipairs(spells) do
		hash = (hash * 33 + id) % 16777213
		hash = (hash * 33 + ((items or {})[index] or 0)) % 16777213
	end

	return hash
end

-- The same hash over a string, for the one number that says whether two ends agree about what
-- one of them is offering. Same shape and same modulus as the fingerprint above, for the same
-- reason: every intermediate stays exact in a double, so both ends compute it identically.
local function hashOf(text)
	local hash = 5381

	for index = 1, #text do
		hash = (hash * 33 + text:byte(index)) % 16777213
	end

	return hash
end

-- One line per character per profession, in a settled order, so that two clients holding the
-- same facts build the same string. A profession with no recipe list yet is a state worth
-- recording as much as a list is, and a character with nothing ticked is part of the shape:
-- losing one is a change even where no profession was involved.
local function offerHash(rows)
	table.sort(rows)
	return hashOf(table.concat(rows, "|"))
end

local function offerRow(memberKey, profession)
	if not profession then return memberKey .. ":-" end

	return string.format("%s:%d:%s:%s", memberKey, profession.skillLine,
		tostring(profession.count or "-"), tostring(profession.fingerprint or "-"))
end

Guild.RECIPE_CEILING = RECIPE_CEILING

-- What one of our characters can make with one profession, in the shape it is stored and
-- compared in: spell ids, sorted, with the item each one makes beside it.
--
-- **Identifiers, never names** (§2.1), and **whichever identifier the client gave**.
--
-- This asked for a spell id and dropped everything without one, which is the shape of the
-- clients it was written against and not the shape of all of them. DATASOURCES §2 has the
-- measurement: `GetTradeSkillRecipeLink` returns nothing at all on Classic Era, so a
-- character there holds a hundred and fifty leatherworking recipes with **an item id on every
-- one and a spell id on none** - and this shared none of them. The Craft frame on the same
-- client is the mirror image, answering with an enchant id and no item, which is why
-- enchanting was the one thing that did cross.
--
-- So a recipe crosses when it has either id, and carries both where it has both. A recipe the
-- client would name in neither way cannot cross - a name is one language, and the whole point
-- is that a French list answers a German search - so it is left out and *counted*, because a
-- panel claiming a shorter list than it shows is worse than one saying what it could not
-- carry.
function Guild:RecipesFor(memberKey, skillLine)
	local payload = Family.Database:Payload(memberKey)
	local record = payload and payload.professions and payload.professions[skillLine]

	if not (record and record.recipes) then return nil end

	local rows, missing = {}, 0

	for _, recipe in ipairs(record.recipes) do
		local spell = tonumber(recipe.spellID) or 0
		local item = tonumber(recipe.itemID) or 0

		if spell ~= 0 or item ~= 0 then
			rows[#rows + 1] = { spell = spell, item = item }
		else
			missing = missing + 1
		end
	end

	-- Nothing shareable is not an empty list, it is no list. A profession whose window came
	-- back with no rows at all - or whose every recipe the client would name in neither way -
	-- has nothing to advertise, and advertising it anyway produced a count and a fingerprint
	-- that the far end dutifully asked about and received nothing for. Seen on a live
	-- client as "recipe lists held from the guild: 4, 0 recipe(s) in all".
	if #rows == 0 then return nil end

	-- Sorted, and by both, because a client where every spell is nought would otherwise have
	-- no order at all and two ends would disagree about it.
	table.sort(rows, function(a, b)
		if a.spell ~= b.spell then return a.spell < b.spell end
		return a.item < b.item
	end)

	local spells, items = {}, {}
	for index, row in ipairs(rows) do
		spells[index] = row.spell
		items[index] = row.item
	end

	return spells, items, missing, fingerprintOf(spells, items), record.recipesSeen
end

-- The same, said in the two numbers that ride with the ranks: how many, and which list.
function Guild:RecipeMark(memberKey, skillLine)
	local spells, _, _, fingerprint = self:RecipesFor(memberKey, skillLine)
	if not spells then return nil end
	return #spells, fingerprint
end

-- What we are offering, in one number.
--
-- **This is what closes the six-hour hole.** The traffic control in onHello asks whether what
-- *we* hold from somebody is recent, and one of the things it decides is whether they get what
-- *we* have - so two clients that each hold recent data from the other exchange nothing, even
-- when one of them has something new. A change made while the other was logged off waits out
-- the whole of STALE_AFTER, because MarkChanged announces at the moment of the change and
-- there is nobody there to hear it.
--
-- One number in a message that was going anyway. The hearer builds the same number out of what
-- it already holds from us, and if the two differ it stops being quiet. Nothing has changed
-- means the numbers match and the saving §7 was built for is untouched.
--
-- Deliberately not over ranks or gear. Those change constantly and are what the six hours are
-- *for*; this exists for the one thing that is asked for once and then never again while its
-- fingerprint holds.
function Guild:OfferHash()
	local offering = self:Offering()
	if not offering then return 0 end

	local rows = {}

	for memberKey, entry in pairs(offering) do
		if entry.professions and #entry.professions > 0 then
			for _, profession in ipairs(entry.professions) do
				rows[#rows + 1] = offerRow(memberKey, profession)
			end
		else
			rows[#rows + 1] = offerRow(memberKey, nil)
		end
	end

	return offerHash(rows)
end

-- The same number, built from what we hold from one player, so it can be compared with the one
-- their announcement carries. Nothing held is nothing to compare.
-- Through the method rather than the local, because this sits above where that local is
-- declared: a file-scope local is nil until its line runs, and this one is reached from a
-- message handler long after the file has finished loading. Written the other way it threw on
-- every hello, and the handler isolation swallowed it - the only symptom was a client that
-- answered nothing at all.
function Guild:HeldOfferHash(guildKey, playerName)
	local bare = self:BareName(playerName)
	if not (guildKey and bare) then return nil end

	local rows, any = {}, false

	for memberKey, entry in pairs(self:Known(guildKey)) do
		if self:BareName(entry.from) == bare then
			any = true

			if entry.professions and #entry.professions > 0 then
				for _, profession in ipairs(entry.professions) do
					rows[#rows + 1] = offerRow(memberKey, profession)
				end
			else
				rows[#rows + 1] = offerRow(memberKey, nil)
			end
		end
	end

	if not any then return nil end
	return offerHash(rows)
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
-- Which of one profession's cooldowns are running, as a short string that two scans apart can
-- be compared by. Identifiers and a flag; never a moment.
--
-- Coarse on purpose. `readyAt` is `time()` plus whatever the client answered a moment ago, so
-- it moves by a second or two on every scan of the same unchanged cooldown - and a marker
-- built out of it would announce to the guild each time somebody opened a profession window.
local function runningMark(memberKey, line)
	local meta = Family.Database:Meta(memberKey)
	if not meta then return "" end

	local marks = {}

	for _, entry in ipairs(Family.Cooldowns:Sharable(meta)) do
		local at = type(entry.profession) == "number" and entry.profession
			or Family:SkillLineFor(entry.profession)

		if at == line then
			marks[#marks + 1] = string.format("%d:%d:%s",
				entry.spell or 0, entry.item or 0, entry.left and "r" or "-")
		end
	end

	table.sort(marks)
	return table.concat(marks, ",")
end

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

			-- And whether its cooldowns are running, which is the other thing a scan can
			-- change and the fingerprint deliberately does not cover.
			--
			-- **A cooldown starting has an event behind it rather than a clock.** Using a
			-- craft means having its window open, and having it open means a scan - so
			-- the moment the fact changes is a moment this side is already awake for, and
			-- it costs the one small message a grid change costs. Nothing announces when
			-- one comes back, because nothing needs to: what crossed was a duration, and
			-- the far end has been counting it down ever since.
			--
			-- Kept out of the fingerprint on purpose. That number decides whether the
			-- other end asks for the whole recipe list again, and a transmute would then
			-- cost a thousand bytes twice a day for nothing.
			now[at] = now[at] .. "/" .. runningMark(memberKey, line)

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

	-- What is on cooldown, gathered once and filed by skill line, rather than walked again
	-- for each of the eight professions this loop may ask about. Cooldowns:Sharable decides
	-- what may cross at all; this only decides which tick it belongs to.
	--
	-- Resolved by the same rule the loop below uses, and it has to be the same rule: a
	-- profession filed under a word is looked up in the skill line table, and if the two
	-- disagreed a cooldown would be attached to a profession nobody had granted.
	local waiting = {}
	for _, entry in ipairs(Family.Cooldowns:Sharable(meta)) do
		local line = type(entry.profession) == "number" and entry.profession
			or Family:SkillLineFor(entry.profession)

		if line then
			local rows = waiting[line] or {}
			waiting[line] = rows

			if #rows < COOLDOWN_CEILING then
				rows[#rows + 1] = {
					spell = entry.spell,
					item = entry.item,
					left = entry.left and math.floor(entry.left) or nil,
					bags = entry.bags,
				}
			end
		end
	end

	for id, skill in pairs(meta.skills or {}) do
		-- A profession filed under a word rather than an id is still that profession where
		-- the skill line table knows the word, so it is looked up rather than refused. A
		-- member recorded by a version that had no ids, and not played since, is filed that
		-- way for every profession they have; the grid resolves them the same way, and both
		-- ends have to agree or a box could be ticked for something that never crossed.
		local line = type(id) == "number" and id or Family:SkillLineFor(id)

		-- Shares() already refuses a profession outside the perimeter, so the wire is covered
		-- by that alone. Named here as well because this loop is what somebody reads to find
		-- out what crosses, and a rule enforced two files away is a rule they will not find.
		if line and not seen[line] and Guild:Shareable(line)
			and Guild:Shares(guildKey, memberKey, line) then
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
				-- Riding along on a message that was going anyway, and never a reason
				-- to send one: what is on cooldown changes every hour of the day, and a
				-- guild whose members announced each time would be a guild talking to
				-- itself about nothing. MarkChanged is deliberately blind to these -
				-- it compares recipe lists - so a cooldown is as fresh as the last
				-- thing that was worth saying, and the age beside it says so.
				cooldowns = waiting[line],
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

-- Everything held from a player nobody has heard from inside ABANDON_AFTER, dropped.
--
-- The other half of the promise in §7.1, and the only half of it that does not need the other
-- person to turn up. `ForgetLeft` above drops a whole guild once none of our characters is in
-- it; this drops one player out of a guild we are still in, on the one ground that can be
-- decided without them - that nothing has been heard.
--
-- **The grid is not touched.** `grants` is our own decision about what we offer, keyed by our
-- own characters; it is only ever cleared by the player or by leaving the guild. What goes is
-- what *they* sent: their characters out of `known`, and the recipe lists filed under those
-- characters. Confusing the two would silently untick somebody's own professions because a
-- guildmate went on holiday.
--
-- Measured from `users`, which records every hello and is therefore "heard anything at all"
-- rather than "sent us data". A database written before `users` existed has records with no
-- entry there at all, and those would never expire, so the newest `at` among what they sent
-- stands in - it is the same question asked of the other table.
function Guild:ForgetAbandoned()
	local guild = store()
	local now = time()

	local dropped = {}
	for guildKey, known in pairs(guild.known) do
		local heard = guild.users[guildKey] or {}

		-- When we last had anything from each player, by either measure.
		local last = {}
		for bare, at in pairs(heard) do
			if type(at) == "number" then last[bare] = at end
		end
		for _, entry in pairs(known) do
			local bare = bareName(entry.from)
			local at = tonumber(entry.at)
			if bare and at and (not last[bare] or at > last[bare]) then last[bare] = at end
		end

		for bare, at in pairs(last) do
			-- Never ourselves. Our own characters are answered out of our own records and
			-- never out of `known`, and `noteUser` is reached only past the echo guard, so
			-- this should not be able to fire - which is the reason it is cheap to keep.
			if (now - at) > ABANDON_AFTER and not self:IsOurs(bare) then
				dropped[#dropped + 1] = { guildKey = guildKey, name = bare,
					silent = now - at }
			end
		end
	end

	table.sort(dropped, function(a, b)
		if a.guildKey ~= b.guildKey then return a.guildKey < b.guildKey end
		return a.name < b.name
	end)

	for _, gone in ipairs(dropped) do
		local known = guild.known[gone.guildKey] or {}
		local recipes = guild.recipes[gone.guildKey] or {}

		for memberKey, entry in pairs(known) do
			if bareName(entry.from) == gone.name then
				known[memberKey] = nil
				recipes[memberKey] = nil
			end
		end

		if guild.users[gone.guildKey] then guild.users[gone.guildKey][gone.name] = nil end

		Family:Debug("guild: dropping everything held from %s in %s - nothing heard for %d day(s)",
			gone.name, gone.guildKey, math.floor(gone.silent / 86400))
	end

	if #dropped > 0 then Family.Database:Changed("guild") end
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
-- What this client calls a spell, remembered for as long as the session lasts.
--
-- The name pass below walks every recipe held for the guild, which is some hundreds, and it
-- runs on a mouseover. Asking the client once per id and keeping the answer turns every hover
-- after the first into table lookups. Not written to disk: it is a word, and a word is one
-- language - the ids are what is stored (§2.1).
local spellNames, namedIn = {}, nil

local function spellNamed(id)
	if id == 0 then return nil end

	-- Emptied if the client's language has changed under it. A language is chosen between
	-- sessions, so in the game this never fires - but a memo of words that outlived one
	-- would answer in the wrong ones, and the rule is worth stating where it is kept rather
	-- than assumed from how the game happens to be started.
	if namedIn ~= Family.locale then
		spellNames, namedIn = {}, Family.locale
	end

	local known = spellNames[id]
	if known ~= nil then return known ~= false and known or nil end

	local name = Family.Names:Spell(id)
	spellNames[id] = name or false
	return name
end

-- The cooldown on one recipe of theirs, or nothing at all - which is the ordinary answer,
-- because most recipes have none.
--
-- Matched on the ids *they* sent for that row rather than on the ids under the cursor, and the
-- two are not the same thing: an Era client knows a transmute only as the item it makes, a
-- Burning Crusade one sends the spell as well, so a lookup by whichever id the reader happens
-- to be hovering matches on one client and quietly fails on the next. The row that matched is
-- known, so their own pair for it is known, and that is what to ask with.
--
-- A cooldown with no moment on it is a craft that is ready, which is an answer rather than a
-- gap: it is in the list at all only because its owner has been watched doing it once. An
-- item's is let go the moment it passes, for the reason Cooldowns.lua gives at length -
-- nobody watched their bags, so "ready" would be a claim rather than a fact (§2.2).
local function cooldownFor(profession, spell, item)
	if not profession then return nil end

	local now = time()
	spell, item = tonumber(spell) or 0, tonumber(item) or 0

	for _, entry in ipairs(profession.cooldowns or {}) do
		if (spell ~= 0 and entry.spell == spell)
			or (item ~= 0 and entry.item == item) then

			local ready = not entry.readyAt or entry.readyAt <= now
			if entry.bags and ready then return nil end

			return {
				ready = ready,
				readyAt = (not ready) and entry.readyAt or nil,
				bags = entry.bags,
			}
		end
	end

	return nil
end

-- The same lookup, for a caller holding one of their characters and one of their rows. The
-- whole-family search reads its guild half straight out of the recipe lists rather than
-- through CraftersOf, so it has the pair in hand already and needs only this.
function Guild:CooldownOn(entry, skillLine, spellID, itemID)
	for _, profession in ipairs((entry or {}).professions or {}) do
		if profession.skillLine == skillLine then
			return cooldownFor(profession, spellID, itemID)
		end
	end

	return nil
end

function Guild:CraftersOf(spellID, itemID, itemName)
	local guildKey = self:Current()
	if not (guildKey and (spellID or itemID or itemName)) then return {} end

	local known = self:Known(guildKey)
	local found = {}

	for memberKey, perLine in pairs((store().recipes[guildKey]) or {}) do
		local entry = known[memberKey]

		for line, list in pairs(perLine) do
			-- Which row of their list matched, not merely that one did. Their own ids for
			-- that recipe are what a cooldown is looked up by below, and looking it up by
			-- the ids under the cursor instead would miss on every client that gave only
			-- one of the two - which is most of them, and a different one each time.
			local knows, matched = false, nil

			for index, spell in ipairs(list.spells or {}) do
				-- Either id answers, because either may be the only one a client gave.
				if (spellID and spellID ~= 0 and spell == spellID)
					or (itemID and itemID ~= 0 and (list.items or {})[index] == itemID) then
					knows, matched = true, index
					break
				end

				-- And where no id can answer, the name can.
				--
				-- An enchanting recipe on Classic Era crosses as its enchant id and
				-- nothing else - the Craft frame gives no item id at all, even for the
				-- rows that make an item (DATASOURCES §2). So the oil under the cursor
				-- has an item id that is in no list, and the formula that teaches an
				-- enchant has one that was never related to it. Neither could ever
				-- match, and enchanting answered nothing while every other profession
				-- answered.
				--
				-- The name is worked out *here*, from the id that crossed, and the item
				-- is named here too. Both sides of the comparison are in the reader's
				-- language, so this is §2.1 being spent rather than broken - which is
				-- exactly what the family's own crafters block has always done.
				if itemName then
					-- Whichever of the two the sender's client gave a name to. A
					-- spell where there is one, and otherwise the thing it makes -
					-- which for a trade skill recipe is what it is named after, and
					-- is the only id an Era trade skill record carries at all.
					local made = (list.items or {})[index]
					local recipeName = (spell ~= 0 and spellNamed(spell))
						or (made and made ~= 0 and Family.Names:CachedItem(made))

					if recipeName
						and Family.Recipes:Teaches(itemName, recipeName) then
						knows, matched = true, index
						break
					end
				end
			end

			if knows and entry then
				local rank, cooldown
				for _, profession in ipairs(entry.professions or {}) do
					if profession.skillLine == line then
						rank = profession.rank
						cooldown = matched and cooldownFor(profession,
							(list.spells or {})[matched],
							(list.items or {})[matched]) or nil
					end
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
					cooldown = cooldown,
				}
			end
		end
	end

	-- Whoever cannot do it yet goes last, and among those the one whose turn comes soonest
	-- goes first. For anything on a timer this is the whole question: "who can make this" has
	-- an answer everybody already knows and "whose is up" is what somebody is actually asking
	-- (§4.5). Everyone else keeps the old order - whoever we heard from most recently, then by
	-- name - so the list is the same twice running and reads top down.
	table.sort(found, function(a, b)
		local aWaiting = (a.cooldown and not a.cooldown.ready) and 1 or 0
		local bWaiting = (b.cooldown and not b.cooldown.ready) and 1 or 0
		if aWaiting ~= bWaiting then return aWaiting < bWaiting end

		if aWaiting == 1 and (a.cooldown.readyAt or 0) ~= (b.cooldown.readyAt or 0) then
			return (a.cooldown.readyAt or 0) < (b.cooldown.readyAt or 0)
		end

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
	return say("ghello", "GUILD", nil, { offer = self:OfferHash() })
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
	return say("ghello", "GUILD", nil, { changed = true, offer = self:OfferHash() })
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

	-- Carrying what we are offering, so that a reply which exists only to say "I am here"
	-- also says "and this is what I have". Without it the quiet path is silent in both
	-- directions and a change made while somebody was logged off waits out the six hours.
	return say("ghello", "WHISPER", name, { reply = true, offer = self:OfferHash() })
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

	-- What they say they are offering, against what we hold from them. One number each way,
	-- and the whole of the catch-up: a change made while we were logged off is invisible to
	-- everything else here, because the announcement that carried it went out to a guild we
	-- were not in yet.
	local theirOffer = tonumber(body.offer)
	local ourRecordOfIt = Guild:HeldOfferHash(guildKey, sender)
	local behind = theirOffer ~= nil and ourRecordOfIt ~= nil
		and theirOffer ~= ourRecordOfIt

	-- Somebody saying hello back, which is the whole of what that message is for: it has
	-- been counted and noted above, and answering it would start a conversation with no end
	-- to it.
	--
	-- Except to ask, once, when their reply says they are offering something we have not got.
	-- Asking is not answering: it produces one message from them and no further hello.
	if body.reply then
		Family:Debug("guild: %s said hello back", tostring(sender))

		if behind then
			Family:After(2 + math.random() * 4,
				"guild.behind." .. tostring(bareName(sender)), function()
					if not Guild:Enabled() then return end
					Family:Debug("guild: %s has something we have not - asking",
						tostring(sender))
					Guild:AskOne(sender)
				end)
		end

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
	--
	-- And except when the one number they sent does not match the one we can build out of
	-- what we hold from them, which says they have something we have not - however recent
	-- what we hold happens to be. That is the case six hours of silence used to swallow.
	local quiet = (not body.changed) and (not behind)
		and newest and (time() - newest) < STALE_AFTER

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
-- Durations back into moments, and the item rule kept on this side as well as on the other.
--
-- **A duration crossed and a moment is stored**, which is the whole reason a duration crossed:
-- two clients need not agree about what time it is, but they agree about how long is left.
-- Everything Family keeps is a moment, for the reason mail expiry is - a countdown written
-- down yesterday is wrong today - so the conversion happens here, once, at the door.
--
-- An item's cooldown that arrives without a duration is dropped rather than read as ready. It
-- should never have been sent (Cooldowns:Sharable), and this is the other end of that promise:
-- what Family cannot know about somebody else's bags, it does not say (§2.2).
local function readCooldowns(list)
	if type(list) ~= "table" then return nil end

	local now, out = time(), {}

	for _, entry in ipairs(list) do
		if type(entry) == "table" and #out < COOLDOWN_CEILING then
			local spell = tonumber(entry.spell) or 0
			local item = tonumber(entry.item) or 0
			local left = tonumber(entry.left)
			local bags = entry.bags == true

			-- A duration of nothing or less is a craft that is ready, said the long way
			-- round, and is read as one.
			--
			-- A duration longer than anything the game has, or one that is not a number
			-- at all, is not a duration: a clock set wrong, or a client saying something
			-- absurd. The row goes rather than being turned into a moment years away
			-- that no panel would ever stop showing - and rather than being read as
			-- ready, which would be Family making a claim nobody sent.
			local absurd = entry.left ~= nil and (left == nil or left > COOLDOWN_LONGEST)
			if left and left <= 0 then left = nil end

			if not absurd and (spell ~= 0 or item ~= 0) and not (bags and not left) then
				out[#out + 1] = {
					spell = spell,
					item = item,
					readyAt = left and (now + left) or nil,
					bags = bags or nil,
				}
			end
		end
	end

	if not next(out) then return nil end
	return out
end

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
				-- What of this profession is on cooldown, as of when they said so.
				-- Held here rather than beside the recipe list on purpose: a recipe
				-- list is asked for once and kept for as long as its fingerprint holds,
				-- and a cooldown is only ever as good as the last announcement. Filed
				-- with the thing that is replaced wholesale, it can never be stale in a
				-- way the age beside it does not admit to.
				cooldowns = readCooldowns(entry.cooldowns),
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
			-- Offered *with something to send*. A profession they still tick but that has
			-- nothing to share carries no fingerprint, and a list we hold for it is one
			-- they can no longer replace - so it is dropped here rather than kept until
			-- they untick the profession itself.
			offered[profession.skillLine] = profession.fingerprint ~= nil

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
				if offered[line] ~= true then mine[line] = nil end
			end
			if not next(mine) then recipes[memberKey] = nil end
		end
	end

	-- And a character of theirs who has gone altogether: left the guild, or was deleted.
	--
	-- The walk above only reaches the characters that arrived, so a list held for one who did
	-- not arrive stayed on our disk for ever. Harmless to read - every answer is built by
	-- looking the character up in `known`, and the sweep at the top of this function has just
	-- taken them out of it - which is exactly why nothing noticed. It is still somebody's
	-- recipes kept after they stopped offering them, and only forgetting the whole guild ever
	-- cleared it.
	--
	-- Decided by whether anybody is still offering that character, and not by who this
	-- message came from. `known` is the record of what is on offer, from everybody in the
	-- guild; a list for a character nobody appears in it with is a list nobody is offering,
	-- whichever message happens to be the one that noticed. A test on the sender was written
	-- here first and could not be given a case that told the two apart, which is the whole
	-- argument against keeping it.
	for memberKey in pairs(recipes or {}) do
		if guild.known[guildKey][memberKey] == nil then
			recipes[memberKey] = nil
			Family:Debug("guild: dropping the recipes held for %s - nobody offers them now",
				tostring(memberKey))
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

	-- One of the two may be nought on any given row - which of them depends on the client
	-- and on the window (DATASOURCES §2) - but a row that is nought in both is a row about
	-- nothing, and is not written to our disk on somebody's say-so (§2.3).
	local kept = { spells = {}, items = {} }
	for index, spell in ipairs(spells) do
		if spell ~= 0 or (items[index] or 0) ~= 0 then
			kept.spells[#kept.spells + 1] = spell
			kept.items[#kept.items + 1] = items[index] or 0
		end
	end
	spells, items = kept.spells, kept.items

	local guild = store()
	guild.recipes[guildKey] = guild.recipes[guildKey] or {}
	guild.recipes[guildKey][body.member] = guild.recipes[guildKey][body.member] or {}

	-- A list of nothing is not a list, and holding one is worse than holding none: it counts
	-- on the panel and in the diagnosis as something that arrived, and answers no question
	-- ever put to it. An older client can still send one - this end stopped, but the far end
	-- may not have - so the entry goes rather than being written empty.
	if #spells == 0 then
		guild.recipes[guildKey][body.member][body.line] = nil
		if not next(guild.recipes[guildKey][body.member]) then
			guild.recipes[guildKey][body.member] = nil
		end

		Family:Debug("guild: %s sent an empty list for %s - dropped", tostring(sender),
			tostring(body.member))
		Family.Database:Changed("guild")
		return
	end

	guild.recipes[guildKey][body.member][body.line] = {
		spells = spells,
		items = items,
		-- Recipes the other end could not share because their client gave no id for them.
		-- Carried across so that a panel can say a list is short rather than implying it
		-- is complete (§7.1).
		missing = tonumber(body.missing) or 0,
		fingerprint = tonumber(body.fingerprint) or fingerprintOf(spells, items),
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

		-- **Named with their realm.** This printed the bare name, and a player with an alt
		-- of the same name on another realm - which is ordinary, and is how a name gets
		-- reused - saw the character standing in the guild on this list when it was not on
		-- it. An evening went into reading that as a fault in the scanner. A diagnosis that
		-- cannot tell two characters apart is answering about neither.
		for key, entry in pairs(Family.Database:Members()) do
			local meta = entry.meta or {}
			if meta.guild == nil then
				local named = meta.realm
					and string.format("%s (%s)", tostring(meta.name or key),
						tostring(meta.realm))
					or tostring(meta.name or key)

				if #blank < 10 then
					blank[#blank + 1] = named
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
	local wire = Family.Comm.stats or {}
	Family:Print(L["  messages sent from here: %d"], stats.sent)

	-- Sent means *queued*, which is not the same as gone. Two things can happen to a message
	-- between here and the wire and neither is visible from the count above it: the queue can
	-- still be holding it, and the client can refuse it. A refused message is reported as sent
	-- by every count in this file.
	Family:Print(L["  what the client answered to those: %s"], Family.Comm:Answers()
		or L["|cffff5555nothing has been handed to it at all|r"])

	local pending = Family.Comm:Pending()
	if pending > 0 then
		Family:Print(L["  |cffffaa00still in Family's own queue, never handed over: %d|r"],
			pending)
	end

	-- One layer below every other count here, and the only pair of numbers that says whose
	-- silence this is. Everything else on this page counts what happened to a message once it
	-- was Family's; these two count what the client handed over in the first place, ours and
	-- everybody's. Two clients that cannot hear each other look identical from up here and
	-- quite different from down there. See Comm.stats for the argument in full.
	Family:Print(L["  addon messages the client handed us: %d, %d of them Family's%s"],
		wire.events or 0, wire.ours or 0,
		wire.lastFrom and string.format(L[" (last from %s on %s)"], tostring(wire.lastFrom),
			tostring(wire.lastChannel)) or "")

	if (wire.malformed or 0) > 0 or (wire.unhandled or 0) > 0 then
		Family:Print(L["  |cffffaa00of ours, %d would not parse and %d had nothing to handle "
			.. "them|r"], wire.malformed or 0, wire.unhandled or 0)
	end
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
		local ticked, ready, silent = 0, 0, {}

		for memberKey, perMember in pairs((store().grants[guildKey]) or {}) do
			for line in pairs(perMember) do
				ticked = ticked + 1

				if self:RecipeMark(memberKey, line) then
					ready = ready + 1
				elseif #silent < 8 then
					-- Named, not counted. "One of three has nothing to send" tells a
					-- player something is missing and gives them no way to find out
					-- which window to open, which is the same fault as the note that
					-- said "1 left out" and made somebody go looking.
					local entry = Family.Database:Members()[memberKey] or {}
					silent[#silent + 1] = string.format("%s (%s)",
						Family:ProfessionName(line),
						tostring((entry.meta or {}).name or memberKey))
				end
			end
		end

		if ticked > 0 then
			Family:Print(L["  professions ticked: %d, of which %d have a recipe list to "
				.. "send"], ticked, ready)

			if #silent > 0 then
				table.sort(silent)
				Family:Print(L["  |cffffaa00nothing to send for: %s|r"],
					table.concat(silent, ", "))
				Family:Print(L["  |cff888888those share a rank and nothing else. Open each "
					.. "one's window once - and if it stays on this list afterwards, "
					.. "another addon is standing in front of that window|r"])
			end
		end

		local lists, recipes, withItem = 0, 0, 0
		for _, perMember in pairs(self:AllRecipes(guildKey)) do
			for _, list in pairs(perMember) do
				lists = lists + 1
				recipes = recipes + #(list.spells or {})

				for index = 1, #(list.spells or {}) do
					local item = (list.items or {})[index]
					if item and item ~= 0 then withItem = withItem + 1 end
				end
			end
		end

		-- **How many carry the id of what they make**, which is the half that answers on a
		-- crafted item. A recipe with only its spell answers on the pattern and on nothing
		-- else, so a guild whose lists are all spell and no item looks exactly like a guild
		-- whose lists never arrived - to anybody hovering the food rather than the recipe.
		Family:Print(L["  recipe lists held from the guild: %d, %d recipe(s) in all, "
			.. "%d with the id of what they make"], lists, recipes, withItem)

		if recipes > 0 and withItem == 0 then
			Family:Print(L["  |cffffaa00none of them says what it makes, so they can only "
				.. "answer on a recipe and never on the thing itself|r"])
		end

		if lists == 0 and known > 0 then
			Family:Print(L["  |cff888888nothing yet: they arrive a few seconds after an "
				.. "exchange, and only for professions the other end has ticked and "
				.. "opened|r"])
		end
	end

	-- **Said as what is known rather than as a verdict, and split three ways to keep it that
	-- way.** Nothing arriving has three quite different causes - the client handing this
	-- character no addon traffic at all, handing it everybody's but not ours, and handing it
	-- ours only for us to drop it - and a single sentence covering all three usefully advises
	-- none of them. It sends somebody to look at the channel, which is the one part they
	-- cannot inspect, when the answer might be sitting in our own counters.
	--
	-- The three tests are on Comm.stats rather than on anything here, because every count in
	-- this file is taken after the point where the interesting failures happen.
	if stats.sent > 0 and stats.arrived == 0 then
		if (wire.ours or 0) > 0 then
			-- The client did hand Family messages to this character, and none of them was
			-- an announcement this code counted. Whatever is wrong is on this side of the
			-- wire, which is the half that can actually be looked at.
			Family:Print(L["|cffffaa00Family messages did reach this client|r, and none of "
				.. "them was an announcement. The channel is carrying our traffic, so "
				.. "whatever is dropping it is in Family rather than in the guild. Worth "
				.. "reporting with this whole page."])
		elseif (wire.events or 0) == 0 then
			-- Not one addon message from anybody. It is not proof on its own - a quiet
			-- moment on a quiet realm can produce it - but it is the one reading that
			-- points away from Family entirely, and it is worth saying which way to look.
			Family:Print(L["|cffffaa00No addon message from any addon has reached this "
				.. "character.|r That is not about Family - nothing at all is being handed "
				.. "over. Check that this character may speak in guild chat: type something "
				.. "in /g and see whether anybody answers."])
		else
			-- **Said as what is known rather than as a verdict.** Other addons are being
			-- heard and ours is not, which on Mists is what being the only Family user
			-- online looks like: a client there does not hear its own guild announcement
			-- come back (DATASOURCES §2). A diagnosis that names the wrong culprit is worse
			-- than one that says less.
			Family:Print(L["|cffffaa00Nothing of Family's has arrived here.|r In a guild "
				.. "where nobody else runs Family that is the ordinary answer - and on some "
				.. "clients your own announcement does not come back to you either, so by "
				.. "itself this is not proof of a fault. Ask somebody else in the guild to "
				.. "run this: if their copy shows messages arriving, the channel is working."])
		end
	end
end

--------------------------------------------------------------------------------------------
-- The guild's own event log, which Family does not read and might
--
-- Printed by /family guild log. A **probe**, not a diagnosis: nothing in Family uses this, and
-- the question is whether it could. Blizzard records who joined a guild and who left it, and
-- that is a second source for the one fact §7 has no good answer for - a character who is
-- *gone*, whose absence nothing announces, nobody can be asked about, and which currently only
-- comes to light when their owner next logs in on another alt.
--
-- **Written to read the answers back rather than to confirm what the calls are named.** Every
-- value each call returns is printed, by position and with its type, however many there turn
-- out to be - the shape of the answer is part of what is being asked. That is DATASOURCES §2's
-- rule, and L-023's postscript is why it is not negotiable here: `GetGuildRosterInfo` reads
-- like the roster, is a *filtered* view of it, and a diagnostic built on the name could not see
-- the case it was written for.
--
-- Four questions, and each of them decides something:
--
--   does it exist at all   On three clients, one of which is 1.15. "No" on Era ends the idea:
--                          a second source two clients out of three lack is not a source.
--   who may read it        Run it as a rank-and-file member *and* as an officer. A log only
--                          officers can read is no use here - everybody has to reach the same
--                          conclusion, or the guild disagrees about who is in it.
--   how far back it goes   It is capped. If being away a fortnight means the event has
--                          scrolled off, this is an accelerator and never a guarantee, and
--                          the expiry has to stay as the backstop.
--   what a deletion looks  Leaving is something a player does. Deleting is a character
--   like                   ceasing to exist, and whether that leaves any trace at all is the
--                          whole question for the case this was opened for.
--
-- The answers go into DATASOURCES §2 as measurements. Until they do, nothing may be built on
-- top of this.
--------------------------------------------------------------------------------------------

-- How many entries are printed in full. A probe, not a listing: a hundred lines in the chat
-- frame answers nothing that eight do not.
local EVENT_SHOWN = 8

-- Lua 5.1 has no table.pack, and the count is the point: a call that answers with a nil in the
-- middle or at the end is exactly the shape this exists to notice, and `#` on such a table
-- cannot be trusted to say so.
local function pack(...) return select("#", ...), { ... } end

-- One entry, as whatever it turned out to be.
local function eventLine(index)
	local count, got = pack(pcall(_G.GetGuildEventInfo, index))
	if not got[1] then return nil end

	local bits = {}
	for at = 2, count do
		bits[#bits + 1] = string.format("%d:%s(%s)", at - 1, tostring(got[at]),
			type(got[at]))
	end

	return table.concat(bits, " "), got[2]
end

function Guild:ProbeEventLog()
	local _, guildName, realm = self:Current()

	Family:Print(L["|cffffd700Guild event log|r on %s"], Family.Capabilities.name)
	Family:Print(L["  guild: %s"], guildName and string.format("%s (realm %s)", guildName,
		tostring(realm)) or "|cffff5555not in one|r")

	-- Which rank is asking, because the answer may well depend on it and comparing two ranks
	-- is half the point of running this. Index 0 is the guild master.
	local _, rankName, rankIndex = Family:TryCall(GetGuildInfo, "player")
	Family:Print(L["  asking as: %s, rank index %s"], tostring(rankName or "?"),
		tostring(rankIndex or "?"))

	local absent = false
	for _, name in ipairs { "QueryGuildEventLog", "GetNumGuildEvents", "GetGuildEventInfo" } do
		local there = type(_G[name]) == "function"
		Family:Print(L["  %s exists: %s"], name, there and "yes" or "|cffff5555no|r")
		if not there then absent = true end
	end

	if absent then
		Family:Print(L["  |cffffaa00this client has no event log to read, so it cannot be a "
			.. "source here|r"])
		return
	end

	-- Asked for, and read back a moment later rather than in the same breath. The log comes
	-- from the server the way the roster does, and reading it straight away reads whatever
	-- happened to be there already - which is how a probe answers about the last question
	-- somebody asked instead of about this one.
	Family:TryCall(_G.QueryGuildEventLog)
	Family:Print(L["  asked the server - reading it back in a moment"])

	Family:After(3, "guild.eventlog", function()
		local count = tonumber(Family:TryCall(_G.GetNumGuildEvents)) or 0
		Family:Print(L["  entries: %d"], count)

		if count == 0 then
			Family:Print(L["  |cffffaa00nothing came back. Either this rank may not read "
				.. "it, or the guild has no history, or asking is not enough|r"])
			return
		end

		Family:Print(L["  |cff888888every value each call returned, by position and type. "
			.. "These go into DATASOURCES, not into a memory|r"])

		for index = 1, math.min(EVENT_SHOWN, count) do
			local line = eventLine(index)
			Family:Print("  [%d] %s", index, line or "|cffff5555the call errored|r")
		end

		-- And the other end of the log, because how far it reaches is one of the four
		-- questions and eight rows from one end cannot answer it.
		--
		-- Which end is which is not assumed here and was got wrong before it was measured:
		-- on Era the **first** index is the oldest and the last is the newest, which is the
		-- opposite of what a chat log looks like. The row says so itself - what those last
		-- four numbers carry is how long ago, not a date - so printing both ends and reading
		-- them is what settles it on a client nobody has run this on yet.
		if count > EVENT_SHOWN then
			local line = eventLine(count)
			Family:Print("  [%d] %s", count, line or "|cffff5555the call errored|r")
		end

		-- Every kind of event in the whole log, which is what says how a departure appears -
		-- and, run again after deleting a character, whether that appears at all.
		local kinds, order = {}, {}
		for index = 1, count do
			local _, kind = eventLine(index)
			if kind ~= nil then
				local word = tostring(kind)
				if not kinds[word] then order[#order + 1] = word end
				kinds[word] = (kinds[word] or 0) + 1
			end
		end

		table.sort(order)
		local bits = {}
		for _, word in ipairs(order) do
			bits[#bits + 1] = string.format("%s x%d", word, kinds[word])
		end

		Family:Print(L["  kinds of event in the whole log: %s"],
			#bits > 0 and table.concat(bits, ", ") or "|cffffaa00none said|r")
	end)
end

--------------------------------------------------------------------------------------------

-- Announcing as soon as the client will say which guild this is.
--
-- **`GetGuildInfo` answers late**, and the two moments that matters most are the two where it
-- is slowest: joining a guild, and creating one. Every announcement here looked once and gave
-- up - `if Guild:Current() then Announce() end` and nothing else - so a character who had just
-- joined told the guild nothing, and nothing tried again until the next login. Reported from a
-- live client: a character invited, accepted and standing in the guild, and the guild master
-- two feet away never heard of them.
--
-- The same shape as L-027 one file over, and the same fix: a wait that is bounded has to be
-- re-armed by whatever counts as a fresh reason, and a wait that is *not* re-armed has to at
-- least be tried more than once.
--
-- Bounded for the reason every wait here is bounded: a client that is going to answer does so
-- within a few seconds, and one that never will must not be woken for ever.
local function announceWhenReady(why, tries)
	tries = tries or 0

	if not Guild:Enabled() then return end
	if not Family.Codec:CanTalk() then
		Family:Debug("guild: no serialisation libraries, so nothing can be shared")
		return
	end

	if Guild:Current() then
		Guild:Announce(why)
		return
	end

	if tries >= 5 then
		Family:Debug("guild: in a guild the client will not name - nothing announced (%s)",
			tostring(why))
		return
	end

	Family:After(3, "guild.announce", function() announceWhenReady(why, tries + 1) end)
end

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
			Guild:ForgetAbandoned()

			announceWhenReady("login")
		end)
	end)

	-- Changing guild changes which guild everything above is about, and the client says so
	-- some seconds after the world has loaded as often as not.
	Family:RegisterEvent("PLAYER_GUILD_UPDATE", "guild", function()
		Family:After(5, "guild.rejoin", function()
			-- The moment this is actually for: a guild left is a guild whose records and
			-- whose grid stop being ours the same evening, rather than at the next login.
			Guild:ForgetLeft()
			Guild:ForgetAbandoned()

			announceWhenReady("guild changed")
		end)
	end)
end)
