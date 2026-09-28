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
-- And the Retail client this branch ports to: 120100 live and 120105 on the PTR, both 12.
local MIDNIGHT = 12

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
	-- Midnight: seven tabs, a tab's name and rights, and a slot's link and count all answered at a
	-- guild bank on 2026-09-27, and opening it sends `GUILDBANKBAGSLOTS_CHANGED` eight times, which
	-- the bank scanner already waits on; `GUILDBANKFRAME_OPENED` was not among what it sent
	-- (`docs/MIDNIGHT.md` §127).
	guildBank    = { [VANILLA] = false, [TBC] = true,  [MISTS] = true, [MIDNIGHT] = true },
	-- Midnight's column for this block and `weaponSkills` below, from readings (`docs/MIDNIGHT.md`
	-- §133): daily quests and transmog are in the game, Alberto's word, with `C_Transmog` and
	-- `C_TransmogCollection` answering tables; currencies answer 49 through `C_CurrencyInfo`; one
	-- specialisation group, `GetNumSpecGroups` 1; the Classic tree calls, the three glyph calls and
	-- `KEYRING_CONTAINER` are all absent; no ammunition - the client still defines an *AmmoSlot*,
	-- which says nothing, and Alberto: *there is no ammo slot anymore on hunters*.
	dailyQuests  = { [VANILLA] = false, [TBC] = true,  [MISTS] = true, [MIDNIGHT] = true },
	-- Burning Crusade is the one people correct us on, and the table is right: Blizzard
	-- builds all of these from one codebase, so Anniversary ships the whole achievement API
	-- and the game behind it has no achievements. The client carrying the call is a fact
	-- about the build, not about the game - which is the whole thesis of this file.
	-- Midnight: 169 categories and 5,087 achievements answered on Ahia, 2026-09-27; the walk
	-- steps by a time budget there, since one category took 446 ms (`docs/MIDNIGHT.md` §127).
	achievements = { [VANILLA] = false, [TBC] = false, [MISTS] = true, [MIDNIGHT] = true },
	currencies   = { [VANILLA] = false, [TBC] = true,  [MISTS] = true, [MIDNIGHT] = true },
	dualSpec     = { [VANILLA] = true,  [TBC] = true,  [MISTS] = true, [MIDNIGHT] = false },
	talentTrees  = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false, [MIDNIGHT] = false },
	glyphs       = { [VANILLA] = false, [TBC] = false, [MISTS] = true, [MIDNIGHT] = false },
	keyring      = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false, [MIDNIGHT] = false },
	ammoBags     = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false, [MIDNIGHT] = false },
	transmogrify = { [VANILLA] = false, [TBC] = false, [MISTS] = true, [MIDNIGHT] = true },

	-- Whether a character can leave the ground at all. Not an API question and not researched
	-- from anywhere but the client's own tables: `SpellEffect` on Classic Era has **no spell**
	-- carrying aura 207, mounted flight speed, and Burning Crusade has 49 of them. So the mount
	-- column says `100%/-` where flying is a thing somebody might have and does not, and plain
	-- `100%` where the game has no such thing to have - a dash promising something Era never
	-- offers is worse than saying nothing. Midnight flies: Ahia's Mount column said *Skyriding*
	-- from the style's aura (`docs/MIDNIGHT.md` §86), so a Midnight character with neither style
	-- read shows the dash as a Burning Crusade one with no wings does (§132).
	flying       = { [VANILLA] = false, [TBC] = true,  [MISTS] = true, [MIDNIGHT] = true },

	-- Whether weapon skills are a thing this game has. Cataclysm took them out: on Era and
	-- Burning Crusade the skill sheet has a *Weapon Skills* heading with a rank and a maximum
	-- under it, and on Mists there is no skill sheet at all - the character pane is
	-- *Spellbook & Abilities*, and what it says about weapons is a passive naming which ones
	-- a class may hold, with no number anywhere.
	--
	-- **This is the entry this whole file exists for, and the scanner was deciding it the
	-- other way until 2026-09-06**: it asked whether the client carried `GetProfessions` and
	-- dropped weapon ranks where it did. `GetProfessions` is present and answering on Classic
	-- Era - measured on a live client that day, `type` function and a slot index back - and
	-- Era is one of the two builds where weapon skills are real. So every Era and Burning
	-- Crusade character scanned after that test shipped lost the lot.
	--
	-- **Found while chasing something else**, and worth saying so: the screenshot that started
	-- it was a Mists client, where dropping them was already the right answer, and the fault
	-- it looked like was not this one. The API still hands ranks back on Mists (`Axes 166/245`
	-- on a paladin) and they govern nothing and are shown nowhere, which is why the answer
	-- there is no.
	weaponSkills = { [VANILLA] = true,  [TBC] = true,  [MISTS] = false, [MIDNIGHT] = false },

	-- Whether an addon may ask the client to cast a spell by its name, out of combat and from a
	-- click. Family does it for one thing: opening a profession's window from its button, because
	-- on Burning Crusade the secure button alone opened nothing (backlog 61). **Midnight forbids
	-- it**: clicking that button there, 2026-09-24, put up *Family has been blocked from an action
	-- only available to the Blizzard UI*, `ADDON_ACTION_FORBIDDEN` with the function named
	-- `UNKNOWN()`, twice, from that button and nothing else (`docs/MIDNIGHT.md` §54). Not an error
	-- a `TryCall` can catch - the client stops the call and asks the player what to do - so the
	-- call is not made where the table says no.
	addonCasts   = { [VANILLA] = true,  [TBC] = true,  [MISTS] = true, [MIDNIGHT] = false },

	-- **Skyriding and Steady Flight**, Midnight's two flying styles, and no Classic client's. Seen
	-- on the PTR, 12.1.5, 2026-09-25: `C_MountJournal.IsDragonridingUnlocked()` true on Ahia and
	-- the chosen style an aura on the character, 404464 or 404468 (`docs/MIDNIGHT.md` §85).
	skyriding    = { [MIDNIGHT] = true },

	-- **The Chronoboon Displacer**, which banks world buffs, and the Chrono column that counts
	-- them. Measured on Era (DATASOURCES §3). On Burning Crusade and Mists the column is drawn
	-- today and this keeps it so: whether the item is had there is `main`'s question, not this
	-- branch's. Midnight has no world buffs to bank, so no column there, and the answer is no:
	-- written in its column, and expected only - §93 saw the column empty on every row, which says
	-- nobody holds one, not that the game has none (`docs/MIDNIGHT.md` §133).
	chronoboon   = { [VANILLA] = true,  [TBC] = true,  [MISTS] = true, [MIDNIGHT] = false },

	-- **Talents as a tree of nodes**, Midnight's: a class side, a specialisation side and hero
	-- talents, with loadouts. Seen on the PTR, 12.1.5, 2026-09-26, on Ahia: the game's window, and
	-- `C_Traits` answering one tree of 206 nodes for the active loadout (`docs/MIDNIGHT.md` §94).
	talentNodes  = { [MIDNIGHT] = true },

	-- **A reagent bag**, a sixth carried bag for crafting reagents, which gathered ore and herbs go
	-- into by themselves. Seen on Midnight: Mara's *Gatherer's Reagent Bag*, 26 slots, in Alberto's
	-- screenshot of 2026-09-19, and container 5 answering 26 slots in the same login sweep
	-- (`docs/MIDNIGHT.md` §6). Alberto's Copper Ore was in it and the family's count said none
	-- (§102).
	reagentBag   = { [MIDNIGHT] = true },

	-- **A ranged slot on the character.** Midnight has none: slot 18 is still numbered
	-- `INVSLOT_RANGED` there and answered nothing on Ahia, a rogue, while Family drew it beside the
	-- two weapons (`docs/MIDNIGHT.md` §110). Mists took the slot away too; it is true there only to
	-- keep drawing what Mists draws today, which is `main`'s to change.
	rangedSlot   = { [VANILLA] = true,  [TBC] = true,  [MISTS] = true, [MIDNIGHT] = false },

	-- **A quest log whose size is asked, not taken from `MAX_QUESTS`.** Midnight's holds 35:
	-- `C_QuestLog.GetMaxNumQuestsCanAccept()` answered 35 there, while `MAX_QUESTS` still says 25
	-- and `GetMaxNumQuests()` answers 175, a ceiling of another kind (`docs/MIDNIGHT.md` §113). The
	-- old constant answers and is wrong, so the choice of reader is the game's and lives here.
	questLogAsked = { [MIDNIGHT] = true },

	-- **A lock that keeps its bosses one by one.** On Midnight a Molten Core lock answered ten
	-- bosses by `GetSavedInstanceEncounterInfo`, Gehennas alone killed, and its row's columns 11 and
	-- 12 said 10 and 1 (`docs/MIDNIGHT.md` §121). Mists answers the same call with one boss for the
	-- same place and draws no progress in its own Raid Information window, so there the call is
	-- there and is not asked.
	lockoutBosses = { [MIDNIGHT] = true },

	-- **A hunter's pet's GUID that names a generic creature.** On Midnight a cat whose active-list
	-- row says `creatureID=42718` had `Pet-0-5769-0-2041-165189-...` for a GUID (`docs/MIDNIGHT.md`
	-- §124), where Era and Burning Crusade put the tamed creature in that field. A warlock's Imp
	-- still answered a `Creature-` GUID naming 416. The GUID answers and is wrong for a pet there,
	-- so which reader names the creature is the game's and lives here.
	petGuidGeneric = { [MIDNIGHT] = true },

	-- **An achievement's completion that is the Warband's.** On Midnight `GetAchievementInfo`'s
	-- fourth value is true for 1,790 of Ahia's achievements and its thirteenth, earned by this
	-- character, for 1,145 (`docs/MIDNIGHT.md` §127). The fourth answers and is not this
	-- character's, so which value a member's achievements are read from lives here.
	achievementsWarband = { [MIDNIGHT] = true },

	-- **A Warband bank**: tabs every character of the account shares, containers 12 to 16 by the
	-- client's `Enum.BagIndex`, read on Ahia at a bank 2026-09-27 (`docs/MIDNIGHT.md` §128). Read in
	-- Midnight's first release by Alberto's exception to §111.
	warbandBank = { [MIDNIGHT] = true },

	-- **A bank of tabs the player names**, where Classic's bank holds bags. On Midnight containers 6
	-- to 11 are the character's tabs, and the item in each one's slot answers *Character Bank Tab
	-- Bag (DNT)*, the client's placeholder, while `C_Bank.FetchPurchasedBankTabData` names them as
	-- the player did, *Tab 1* to *Void Storage 2*, read at a bank on Ahia 2026-09-27
	-- (`docs/MIDNIGHT.md` §130). The item's name answers and is wrong there, so which one titles
	-- a block lives here.
	bankTabs     = { [MIDNIGHT] = true },

	-- **A look learnt by wearing a lower armour type.** On Midnight a Warrior who put on the
	-- uncollected cloth *Master's Leggings* and took them off had collected the look, while the
	-- game's class answer for it named Priest, Mage and Warlock alone (`docs/MIDNIGHT.md` §134). On
	-- Mists a plate Paladin learns nothing from mail or cloth (`main`, backlog 108). So there the
	-- class answer says who may **use** a look, and who can **learn** it is whoever can wear it.
	transmogWearLower = { [MIDNIGHT] = true },

	-- **An item's price that moves with its level.** On Midnight the *Eventide Coif of the
	-- Harmonious* at item level 54 sells for 4g 97s 29c, the game's own line: `GetItemInfo` by its
	-- link answered 49729, and by its id the base item's 406 - which Family showed (`docs/MIDNIGHT.md`
	-- §134). The id answers and is wrong there, so which one prices an item lives here.
	scaledPrices = { [MIDNIGHT] = true },

	-- **Profession tools and accessories**, worn in slots of their own: `GetProfessionSlots` answered
	-- 20-22 for Enchanting, 23-25 for Skinning, 26-27 Cooking and 28-30 Fishing, and slot 24 held
	-- the skinner's *Durable Pack* (`docs/MIDNIGHT.md` §135). No Classic client has them.
	professionGear = { [MIDNIGHT] = true },

	-- **Skinning makes things.** On the Classic clients it gathers and has no window; on Midnight
	-- its window lists recipes, refining and bait among them - Mara's page, twenty (`docs/MIDNIGHT.md`
	-- §138). Guild share asks *who can make this*, so where this holds a skinner is asked too.
	skinningRecipes = { [MIDNIGHT] = true },

	-- Archaeology came with Cataclysm. `GetNumArchaeologyRaces` is absent on Era and Burning
	-- Crusade and answers 13 on Mists (probe, 2026-09-27; backlog 104). Midnight answers 20, and
	-- each of the four calls the scanner makes in the shape Mists does: a race's six values, the
	-- project's name and icon, an artifact's first solved and times solved, the project listed
	-- among them with nought (`docs/MIDNIGHT.md` §131).
	archaeology  = { [VANILLA] = false, [TBC] = false, [MISTS] = true, [MIDNIGHT] = true },
}

-- Checked in the game. 2026-08-08 unless noted.
local CONFIRMED = {
	achievements = { [VANILLA] = true, [TBC] = true, [MISTS] = true, [MIDNIGHT] = true },
	currencies   = { [VANILLA] = true, [TBC] = true, [MISTS] = true, [MIDNIGHT] = true },
	dualSpec     = { [VANILLA] = true, [TBC] = true, [MISTS] = true, [MIDNIGHT] = true },
	guildBank    = {                   [TBC] = true, [MISTS] = true, [MIDNIGHT] = true },
	keyring      = { [VANILLA] = true, [TBC] = true,               [MIDNIGHT] = true },
	glyphs       = {                                 [MISTS] = true, [MIDNIGHT] = true },
	-- 2026-09-06, from Alberto: the skill sheet photographed on Era and on Burning Crusade
	-- with its three headings and a Weapon Skills rank under the last of them, and Mists
	-- opened on a death knight to find no skill sheet at all.
	weaponSkills = { [VANILLA] = true, [TBC] = true, [MISTS] = true, [MIDNIGHT] = true },
	-- 2026-09-11, Burning Crusade: *cast Leatherworking, callWorked true, windowNow
	-- Leatherworking*, measured from inside the click (Family_UI/Professions.lua).
	-- Midnight 2026-09-24: the dialog and `ADDON_ACTION_FORBIDDEN` on that click (§54).
	addonCasts   = {                   [TBC] = true,               [MIDNIGHT] = true },
	-- Midnight 2026-09-25: *Skyriding* in Ahia's Mount column (§86).
	flying       = { [MIDNIGHT] = true },
	skyriding    = { [MIDNIGHT] = true },
	talentNodes  = { [MIDNIGHT] = true },
	reagentBag   = { [MIDNIGHT] = true },
	questLogAsked = { [MIDNIGHT] = true },
	lockoutBosses = { [MIDNIGHT] = true },
	petGuidGeneric = { [MIDNIGHT] = true },
	achievementsWarband = { [MIDNIGHT] = true },
	warbandBank = { [MIDNIGHT] = true },
	bankTabs     = { [MIDNIGHT] = true },
	-- Midnight 2026-09-27: the Warrior and the cloth leggings (§134).
	transmogWearLower = { [MIDNIGHT] = true },
	-- Midnight 2026-09-27: the Eventide Coif, 406 by its id and 49729 by its link (§134).
	scaledPrices = { [MIDNIGHT] = true },
	-- Midnight 2026-09-27: the skinner's slots and pack (§135).
	professionGear = { [MIDNIGHT] = true },
	-- Midnight 2026-09-28: Mara's Skinning page, twenty recipes (§138).
	skinningRecipes = { [MIDNIGHT] = true },
	-- Midnight 2026-09-26: slot 18 answered nil to `GetInventoryItemID` on Ahia (§110).
	rangedSlot   = { [MIDNIGHT] = true },
	-- Midnight 2026-09-27 (§133): Alberto's word for dailies and transmog, the item data for the
	-- Chronoboon (184937 not there), the old tree calls absent.
	dailyQuests  = { [MIDNIGHT] = true },
	transmogrify = { [MIDNIGHT] = true },
	talentTrees  = { [MIDNIGHT] = true },
	chronoboon   = { [MIDNIGHT] = true },
	ammoBags     = { [MIDNIGHT] = true },
	-- 2026-09-27, FamilyProbe on all three: absent on Era and Burning Crusade, 13 races on Mists.
	-- Midnight 2026-09-27, on live: Drust, 153 of 200 fragments, its project and seven artifacts.
	archaeology  = { [VANILLA] = true, [TBC] = true, [MISTS] = true, [MIDNIGHT] = true },
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
