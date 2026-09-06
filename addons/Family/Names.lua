-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Ids in, names out.
--
-- Family stores ids and never names (§2.1), so this is the layer that makes that liveable.
-- It exists because the decision it serves is not free: the client answers about an item
-- only once it has loaded that item, so a bag belonging to a member you have not played
-- this session can hand back nothing at all.
--
-- The contract is deliberately not "return the name". It is:
--
--   * return the name if the client knows it,
--   * otherwise return a legible placeholder, ask the client, and tell the caller later.
--
-- Showing "Item #12345" for a moment is the honest state of affairs. Showing nothing, or
-- blocking until an answer arrives, are both worse.

local _, Family = ...

local Names = {}
Family.Names = Names

local cache = {}      -- itemID -> name, for this session. Backed by the store below.
local waiting = {}    -- itemID -> { [key] = callback }

-- **What this account has already been told an item is called**, kept on disk between sessions.
--
-- The client's own item cache does not survive a relog. That was claimed here once and it was
-- wrong: Alberto refused it from play - *la cache sta su disco, ma evidentemente la cancelli
-- ogni volta! Altrimenti perche uscendo dal gioco e rientrando se la ricostruisce?* - and the
-- login warm-up that spreads the asking over the first minute has been starting from nothing
-- every session since. This is the half that stops it being the same minute every time.
--
-- **Kept per language, like the quest titles and unlike the areas.** The areas store is word to
-- id, so a second language only adds keys; this one is id to word, and a single store would
-- have a player who switched clients reading every item in the language they left. So each
-- language has its own table, the other languages stay on disk untouched rather than being
-- thrown away, and the check is per item rather than a stamp on the whole store - which is the
-- shape Alberto arrived at when he thought it through out loud.
--
-- **No ceiling, deliberately.** It is bounded by what this family holds - its recipes and its
-- bags - and not by how long Family has been running: a player with forty alts fills it and
-- then it stops. The shipped recipe tables are 1,406 products on Era, so the realistic size is
-- a few thousand short strings per language, which Alberto has judged against the disk it
-- costs. `FamilyDB.quests` is the same shape and has none either.
--
-- **And knowing an answer must never stop us noticing it changed.** A cache that only ever
-- adds is not a cache, it is a fossil: the client is asked first and overwrites whatever is
-- here, but that only corrects the items the client happens to have loaded - and the whole
-- point of this store is that on a cold client it has loaded almost none. So the store carries
-- the build it was written at, and a build it does not recognise empties it.
--
-- The build is the right trigger rather than a timer, because item names live in the client's
-- own data files: they change when the client changes and at no other moment. And it empties
-- rather than marking each entry suspect, because half a store that cannot say which half is
-- worse than none - the session after a patch then costs what every session costs today, which
-- is the thing this is replacing.
local function clientBuild()
	local version, build = Family:TryCall(GetBuildInfo)
	if type(version) ~= "string" or version == "" then return nil end
	return version .. "." .. tostring(build or "?")
end

local function itemRecord()
	if type(_G.FamilyDB) ~= "table" then return nil end

	-- No build, no trust. A client that will not say what it is cannot be checked against
	-- what was written down, and showing a name from an unknown build is exactly the fossil
	-- above.
	local at = clientBuild()
	if not at then return nil end

	FamilyDB.itemNames = FamilyDB.itemNames or {}

	local locale = Family.locale or "enUS"
	local mine = FamilyDB.itemNames[locale]
	if not mine or mine.at ~= at then
		-- Only this language. The other languages keep what they have and are emptied on
		-- the first session somebody plays in them, which is when their build is checked.
		mine = { at = at, names = {} }
		FamilyDB.itemNames[locale] = mine
	end
	return mine
end

local function itemStore()
	local mine = itemRecord()
	return mine and mine.names or nil
end

-- Reachable so a check can read what was written down rather than infer it from timing.
function Names:ItemStore() return itemStore() end

-- Which version of a member's record the login walk has already read all the way through.
--
-- The walk decodes one member per call and the timer fires once a second, so a family of 210
-- costs three and a half minutes of login - and from the second session on it buys nothing,
-- because the store above already holds every answer. This is how it is told: a short mark of
-- the record as it sits on disk, written down when that record has been read through and every
-- name in it is known, so the next walk can step past the member without decoding it.
--
-- **Kept beside the names and not beside the members**, which is what makes it self-correcting.
-- A mark says "everything this record asks for is in *this* store"; when the store is emptied -
-- a new client build, or the first session in a language - the record holding it is replaced
-- whole and the marks go with it. Nothing has to remember to clear them.
--
-- Made on first use rather than written into the shape above, so a store already on somebody's
-- disk is read without being rewritten.
function Names:ItemWalk(key)
	local mine = itemRecord()
	local walked = mine and mine.walked
	return walked and walked[key] or nil
end

function Names:LearnItemWalk(key, mark)
	if key == nil then return end
	local mine = itemRecord()
	if not mine then return end
	mine.walked = mine.walked or {}
	mine.walked[key] = mark
end

local function storedItem(id)
	local known = itemStore()
	local name = known and known[id]
	if type(name) == "string" and name ~= "" then return name end
	return nil
end

local function getItemName(id)
	if C_Item and C_Item.GetItemInfo then
		return (C_Item.GetItemInfo(id))
	end
	return (GetItemInfo(id))
end

local function requestItem(id)
	if C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(id)
	else
		-- On clients without the explicit request, asking is what triggers the load.
		getItemName(id)
	end
end

-- The placeholder. Deliberately not "Unknown": the id is a fact, and it is enough to look
-- the thing up, which "Unknown" is not.
-- One place where a name that came from the client is remembered, so that the three callers
-- that receive one cannot each decide differently about the disk.
--
-- Only what the client said. A name read back off the disk is already there, and a placeholder
-- is not a name at all.
function Names:LearnItem(id, name)
	if not id or type(name) ~= "string" or name == "" then return end
	cache[id] = name

	local known = itemStore()
	if known then known[id] = name end
end

function Names:Placeholder(id)
	return "|cff9d9d9dItem #" .. tostring(id) .. "|r"
end

-- Returns name, known. When known is false the name is a placeholder and the callback, if
-- given, fires once the real one arrives.
--
-- The key exists so a panel that redraws can replace its own pending callback rather than
-- accumulating one per redraw - forty rows redrawn ten times should leave forty callbacks.
function Names:Item(id, key, callback)
	if not id then return "", false end

	local name = cache[id] or getItemName(id)
	if name then
		self:LearnItem(id, name)
		return name, true
	end

	-- **What the client said last time.** Asked after the client rather than before it, so an
	-- item the game has renamed corrects itself the first session somebody looks at it - the
	-- disk is the fallback, never the authority.
	--
	-- And no request is sent behind it. Sending one would ask the client for everything this
	-- store exists to stop asking for, which is the whole of the ten-second freeze this is
	-- about. What a caller gets is the name, which is what this function promises; anything
	-- that needs the item's icon or its quality asks the client itself.
	local remembered = storedItem(id)
	if remembered then
		cache[id] = remembered
		return remembered, true
	end

	if callback then
		waiting[id] = waiting[id] or {}
		waiting[id][key or "anonymous"] = callback
	end
	requestItem(id)

	return self:Placeholder(id), false
end

-- Spells are easier than items in the one way that matters: the client answers about any
-- spell id straight away, for any class, without having to load anything first. That is why
-- the spellbook can be stored as ids alone with no cached names beside them (§2.1).
function Names:Spell(id)
	if not id then return nil end

	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(id)
		if type(info) == "table" then return info.name, info.iconID end
		if type(info) == "string" then return info end
	end

	local name, _, icon = GetSpellInfo(id)
	return name, icon
end

-- What to call a recipe, in the language of whoever is reading.
--
-- A recipe is a spell and a spell has an id, and Family has recorded that id since the day it
-- recorded recipes at all - and then displayed the word the scanning client happened to use.
-- So a list read on an English client stayed English on a French one, under a profession that
-- had just been taught to say Secourisme. The id was there the whole time.
--
-- This is not only about what is drawn. The name is matched against the live trade skill
-- window when a click asks it to select a row, and that window answers in the client's own
-- language - so the recorded word was failing to find rows that were on screen.
--
-- Memoised for the session, like item names: changing the client language means a reload.
local recipeNames = {}

-- The key and callback are the same arrangement Names:Item has, and for the same reason: the
-- client answers about an item only once it has loaded that item, so a list of a hundred and
-- fifty comes back part answered. Without them, half a first aid list read French and half
-- English on one screen - whichever items this session happened to have already seen.
-- `locale` is the language the record was written in, where the caller knows it. When that is
-- the reader's own language the recorded word wins outright, because it is the row the game
-- itself drew and nothing here beats that: smelting is the case that proves it, where the game
-- says "Fonte de cuivre" and the item it makes is a "Barre de cuivre". Naming a recipe after
-- its product is right where there is nothing better and wrong where the game already said.
function Names:Recipe(recipe, key, callback, locale)
	if type(recipe) ~= "table" then return nil end

	if locale and locale == Family.locale and type(recipe.name) == "string"
		and recipe.name ~= ""
	then
		return recipe.name
	end

	local id = recipe.spellID
	if id then
		local known = recipeNames[id]
		if known ~= nil then return known or recipe.name end

		local name = Names:Spell(id)
		if type(name) ~= "string" or name == "" then
			-- Remembered as "the client would not say", so a list of three hundred does
			-- not ask three hundred times a draw for an answer that is not coming.
			recipeNames[id] = false
			return recipe.name
		end

		recipeNames[id] = name
		return name
	end

	-- Failing that, what it makes. The item id came out of a different call than the spell
	-- id did, so a client that will not answer one may still answer the other - and an item
	-- name is in the reader's language where the recorded word is in the scanner's.
	--
	-- Second rather than first because a few rows are not named after their product:
	-- smelting says "Smelt Copper" and makes a Copper Bar. Where the spell answers, it is
	-- the better answer; this is for where it does not.
	if recipe.itemID then
		local item = Names:CachedItem(recipe.itemID)
		if type(item) == "string" and item ~= "" then return item end

		-- Not loaded yet. Ask for it and let the caller draw again when it lands. The
		-- recorded word is returned meanwhile rather than Names:Item's placeholder: a
		-- recipe named in the wrong language is worth more to a reader than "Item #8545".
		if callback then Names:Item(recipe.itemID, key, callback) end
	end

	return recipe.name
end

-- For callers that only want to know, and will look again themselves.
-- Where a hearthstone is bound, in the words of whoever is reading.
--
-- The word GetBindLocation hands back is one language and one expansion, and both matter: a
-- French Era client says "Ironforge" where a French Burning Crusade client says "Forgefer", so
-- a member recorded on one read on the other was wrong even though nothing had changed
-- language. The tables that would fix that out of a file measure 876 KB across five languages
-- and three builds, which is not a trade worth making for one column (L-020).
--
-- So the id is stored and the reader's own client is asked to name it. Measured on all three
-- clients before this was written, because a symbol being present is not evidence it works
-- (L-018): Era, Burning Crusade and Mists all answer, each in its own language and its own
-- spelling, and each agrees character-for-character with the table wago serves for that build.
--
-- An id this client knows nothing about - a Northrend area on an Era client - comes back empty
-- rather than wrong, and the recorded word is used instead. That is the honest answer for a
-- place this game does not have.
function Names:Area(id, recorded)
	if type(id) == "number" and C_Map and C_Map.GetAreaInfo then
		local name = Family:TryCall(C_Map.GetAreaInfo, id)
		if type(name) == "string" and name ~= "" then return name end
	end
	if type(recorded) == "string" and recorded ~= "" then return recorded end
	return nil
end

-- What the client calls a **map**, which is a different table from the areas above and answers
-- where they do not.
--
-- `GetZoneText` does not hand back an area name. Measured 2026-09-05 after a character who logged
-- out in Ironforge on an English client went on reading *City of Ironforge* on a French one: Era's
-- `AreaTable` has no row containing "City of" at all, in any locale - Ironforge is area 1537 and
-- is named `Ironforge` in both - so `AreaFor` walked all twenty thousand ids and correctly found
-- nothing. `UiMap` is the table that word comes from, and it names Ironforge **1455**.
--
-- `GetBestMapForUnit` answers with that id and needs no search at all, which is the second reason
-- to prefer it: the walk it replaces was happening during `PLAYER_LOGOUT`.
--
-- A map id is **not** an area id and the two must not be stored in one field. They are different
-- numbering, and 1455 means Ironforge in one and something else entirely in the other.
function Names:Map(id)
	if type(id) ~= "number" then return nil end
	if not (C_Map and C_Map.GetMapInfo) then return nil end

	local info = Family:TryCall(C_Map.GetMapInfo, id)
	if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
		return info.name
	end

	return nil
end

-- Where a character was when they last logged out, in the words of whoever is reading.
--
-- **The recorded word wins where it was written in this reader's own language**, which is the rule
-- `Names:Recipe` and `Races.lua` already apply and for the same reason: it is the word the game
-- itself drew on that client, and nothing here beats that. It matters exactly here - a French
-- client's `GetZoneText` says *Cité d'Ironforge* where its own map is called *Ironforge*, so
-- naming from the id would make a player's own characters read less precisely than before.
--
-- Then the map, then the area, then the word as recorded. The area id is kept because records
-- written before the map id existed have one, and because a build without `GetBestMapForUnit`
-- still writes one.
function Names:Where(meta)
	if type(meta) ~= "table" then return nil end

	if meta.zoneLocale and meta.zoneLocale == Family.locale
		and type(meta.zone) == "string" and meta.zone ~= ""
	then
		return meta.zone
	end

	return self:Map(meta.mapID) or self:Area(meta.zoneID, meta.zone)
end

-- The id behind a place this client has just named, found the only way there is: by asking for
-- every id until one answers with the same word. GetBindLocation returns a word and nothing
-- returns its id.
--
-- Counted upward on purpose. Some places are in the table twice - Coldridge Valley is 132 and
-- 6176, and the second is a copy - and where the two are spelled the same here they can still
-- be spelled differently in another language ("Das Eisklammtal" against "Eisklammtal"). The
-- lower id is the original, so the first match found counting up is the one to keep.
--
-- How far up to count, measured rather than picked. The highest named area is 16,394 on Era;
-- Mists reaches 15,325 and Burning Crusade only 4,140. A ceiling of six thousand was tried
-- first and would have skipped 11% of Era's areas and 18% of Mists's - a player bound in any
-- of them getting no id at all, silently, which is the same shape of fault as the word this
-- work exists to replace.
--
-- Twenty thousand leaves room for a build that adds more.
--
-- **And every answer is kept, so the walk happens once for a place and never again.**
--
-- That mattered little while a hearthstone was the only caller - a bind location moves when
-- somebody decides to live somewhere else. It matters entirely now that quest categories want
-- ids too: the quest log is re-read as often as every fifteen seconds while somebody is playing,
-- a log holds six to ten zones, and walking for each of them on each scan would be a hundred and
-- sixty thousand questions a minute. Alberto's, on being told the arithmetic: *why not do the
-- walk, save it, and read that instead.*
--
-- Kept in `FamilyDB`, which is the only disk an addon has - there is no file to open, and what
-- the client saves and reloads for us is a Lua table. So it survives the session, and it is the
-- **account's** rather than a character's: twenty alts share one answer for one zone.
--
-- A shipped table was the other way and is measured at 876 KB across five languages (see the
-- note over `Names:Area`), which is why the client is asked instead. This keeps what the client
-- said rather than shipping what it would have said.
--
-- Words from two languages sit in it together and that is not a fault: a player who switches
-- their client adds a second word for the same place, and both map to the same id.
local AREA_CEILING = 20000

local function areaStore()
    if type(_G.FamilyDB) ~= "table" then return nil end
    FamilyDB.areas = FamilyDB.areas or {}
    return FamilyDB.areas
end

-- Reachable so a check can see what was written down rather than infer it from how long
-- something took.
function Names:AreaStore() return areaStore() end

function Names:AreaFor(word)
	if type(word) ~= "string" or word == "" then return nil end

	local known = areaStore()
	if known then
		local found = known[word]
		-- `false` is "asked and there is no such place here", which is worth keeping: a
		-- Northrend zone on an Era client would otherwise be walked for on every scan for
		-- ever. It is not the same as never having asked.
		if found ~= nil then return found or nil end
	end

	if not (C_Map and C_Map.GetAreaInfo) then return nil end

	for id = 1, AREA_CEILING do
		if Family:TryCall(C_Map.GetAreaInfo, id) == word then
			if known then known[word] = id end
			return id
		end
	end

	if known then known[word] = false end
	return nil
end

-- What this account has been told a quest is called, in this reader's own language.
--
-- The client answers about a quest only once the server has described that quest to it, which
-- in practice means one in this character's own log - and a sibling's quest is exactly the case
-- that is not. There is nothing to fall back on either: wago serves QuestV2 for all three
-- pinned builds with the columns `ID,UniqueBitFlag` and no name in it, in any locale, and
-- neither `Quest` nor `QuestLine` is a table there at all (measured 2026-09-05). A quest's
-- title is not in the client's tables, so there is no file anybody could ship - this is not the
-- 876 KB trade `Names:Area` refused, it is no trade at all.
--
-- So it is remembered rather than fetched. Every quest any character on this account reads is
-- written down by id in the words this client used, which is the arrangement `FamilyDB.areas`
-- has and was Alberto's idea there: do the asking once and read the answer afterwards. A French
-- player whose own alt has done *The Love Potion* then reads an English sibling's record of it
-- as *Le philtre d'amour*, because their own game said so once.
--
-- **Kept per language, unlike the areas store.** That one is word to id, so a second language
-- only adds keys. This one is id to word and a second language would overwrite - a player who
-- switched their client would read every quest in the language they left.
--
-- It covers what this account has seen and no more. A quest nobody here has ever picked up
-- stays in the recorded word, which is the honest limit rather than a gap.
local function questStore()
	if type(_G.FamilyDB) ~= "table" then return nil end
	FamilyDB.quests = FamilyDB.quests or {}

	local locale = Family.locale or "enUS"
	local mine = FamilyDB.quests[locale]
	if not mine then
		mine = {}
		FamilyDB.quests[locale] = mine
	end
	return mine
end

-- Reachable so a check can read what was written down rather than infer it.
function Names:QuestStore() return questStore() end

-- Written by the quest scanner, which holds the id and the title together for every row it
-- reads, and by Names:Quest below whenever the client does answer.
function Names:LearnQuest(id, title)
	if type(id) ~= "number" or type(title) ~= "string" or title == "" then return end

	local known = questStore()
	if known then known[id] = title end
end

-- What this reader's client calls a quest category that is not a zone.
--
-- A quest log groups by heading and a heading is a word. Most are zones, and those have read in
-- the reader's own language since the log started carrying a zone id per heading. The rest did
-- not, and Alberto had one left in French in the middle of an English page: *Demoniste*, with
-- *Cuisinier*, *Forgeron* and *Secourisme* behind it on other characters.
--
-- They come from `QuestSort`, which is a table of its own and is not the professions table -
-- the French for Cooking is *Cuisine* and the heading says *Cuisinier*. 52 rows across the three
-- builds, 10 KB with all five languages in it, which is the case the 876 KB of area names was
-- not (L-020).
--
-- **By the word and not by an id**, because nothing records one: a reader is handed whatever the
-- recording client wrote. So this asks which row holds that word, in any language, and hands back
-- the same row's word in the reader's own - which also means it works on records written before
-- any of this, with nothing new crossing a link.
local sortByName

function Names:QuestSort(word)
	if type(word) ~= "string" or word == "" then return nil end

	local sorts = Family.QuestSorts
	if type(sorts) ~= "table" then return nil end

	if not sortByName then
		sortByName = {}
		for id, entry in pairs(sorts) do
			for _, words in pairs(entry) do
				for _, name in ipairs(words) do
					-- The lowest id wins, so two draws of one page agree where a
					-- word somehow sits in two rows.
					if not sortByName[name] or id < sortByName[name] then
						sortByName[name] = id
					end
				end
			end
		end
	end

	local entry = sorts[sortByName[word]]
	if not entry then return nil end

	local words = entry[Family.locale] or entry.enUS
	return words and words[1] or nil
end

-- A quest log heading, in the reader's own words: the zone where there is an id for one, the
-- quest sort where the word names one, and the word as recorded where neither.
--
-- One function rather than one per panel. The two views of a quest log had a copy each, and this
-- view has been the half nothing covered three times in three days - a shared answer is one place
-- to fix and one place to check.
function Names:Heading(word, areaID)
	if type(word) ~= "string" or word == "" then return nil end

	if areaID then
		local named = self:Area(areaID, nil)
		if named then return named end
	end

	return self:QuestSort(word) or word
end

-- A quest's name, in the words of whoever is reading rather than whoever recorded it.
--
-- The store first, because it is this client's own answer already in hand and costs nothing.
-- Then the two live routes, neither assumed: `C_QuestLog.GetTitleForQuestID` where a build has
-- it, then `GetQuestLink`, whose title is the part of the link inside the brackets. Whatever
-- answers is written down, so the next character to want it does not ask.
--
-- The recorded word last. That is what a quest nobody on this account has done reads as, and it
-- is the same word the panel drew before any of this existed - so this costs nothing where it
-- cannot help.
function Names:Quest(id, recorded, level)
	if type(id) == "number" then
		local known = questStore()
		if known then
			local name = known[id]
			if type(name) == "string" and name ~= "" then return name end
		end

		local api = _G.C_QuestLog
		if api and api.GetTitleForQuestID then
			local name = Family:TryCall(api.GetTitleForQuestID, id)
			if type(name) == "string" and name ~= "" then
				self:LearnQuest(id, name)
				return name
			end
		end

		-- `GetQuestLink` *raises* for a quest the client has no data for rather than
		-- answering nothing - which is why the first probe of it printed nothing at all,
		-- the error landing before the print. `TryCall` is what makes that a fallthrough
		-- rather than a broken panel, and it is not memoised: a quest picked up later in
		-- the session is one the client can suddenly name, and the store above is what
		-- stops the asking being repeated for anything already answered.
		local link = Family:TryCall(GetQuestLink, id)
		if type(link) == "string" then
			local name = link:match("%[(.-)%]")
			if type(name) == "string" and name ~= "" then
				self:LearnQuest(id, name)
				return name
			end
		end

		-- And the route that reaches a quest nobody on this account has ever had.
		--
		-- Alberto found it in a screenshot of Family's own tooltip: a level 5 character
		-- hovering a level 58 quest belonging to a sibling, and the client describing it
		-- **in French**, title and objectives, for a quest that character can never have
		-- seen. So the two calls above are not the client's only answer - they are the two
		-- that need the quest to be in the player's own log - and the conclusion drawn from
		-- them failing was wrong (L-057).
		--
		-- `Tooltip.lua` already asks this way and measured the form: a bare `quest:84`
		-- answers nought lines and `quest:84:20` answers three, so **the level is part of
		-- the question** and a row without one cannot ask it. The title is the first line.
		--
		-- Read off the scanning tooltip rather than the one on screen, because this is
		-- wanted while a panel is being drawn and the visible tooltip belongs to whatever
		-- the pointer is over.
		if type(level) == "number" then
			local said = Family:ScanTooltipLine(function(tip)
				Family:TryCall(tip.SetHyperlink, tip,
					"quest:" .. id .. ":" .. level)
			end, 1)

			if type(said) == "string" and said ~= "" then
				self:LearnQuest(id, said)
				return said
			end
		end
	end

	if type(recorded) == "string" and recorded ~= "" then return recorded end
	return nil
end

-- Whether this item is already named, without asking the client to load anything.
--
-- The login warm-up uses this to skip what it does not need to ask for, so reading the disk
-- here is what turns the second session's warm-up into nothing: the queue drains without a
-- single request.
function Names:CachedItem(id)
	if not id then return nil end

	local name = cache[id] or getItemName(id)
	if name then
		self:LearnItem(id, name)
		return name
	end

	local remembered = storedItem(id)
	if remembered then cache[id] = remembered end
	return remembered
end

Family:RegisterEvent("GET_ITEM_INFO_RECEIVED", "names", function(_, id, success)
	if not id then return end

	if success == false then
		-- The client is telling us this id has no item. Stop asking, and let anyone
		-- waiting know so they can settle on the placeholder for good.
		waiting[id] = nil
		return
	end

	local name = getItemName(id)
	if not name then return end
	Names:LearnItem(id, name)

	local callbacks = waiting[id]
	if not callbacks then return end
	waiting[id] = nil

	for _, callback in pairs(callbacks) do
		local ok, err = pcall(callback, id, name)
		if not ok then
			Family:Debug("name callback for %d failed: %s", id, tostring(err))
		end
	end
end)
