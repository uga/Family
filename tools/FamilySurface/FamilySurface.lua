-- Family Surface - a throwaway addon that asks one client about everything Family touches
--
-- Not part of Family and never shipped with it. It exists for the first step of the Midnight
-- branch: before any code is written for a fourth client, write down which of the calls Family
-- makes that client lacks, which it has and answers differently, and which it has and throws.
--
-- The thesis of Capabilities.lua is the reason this asks four questions and not one. A
-- symbol's presence is a fact about the build, not the game, and a function can exist and
-- throw when called - Anniversary's GetNumSpecGroups does. So presence is recorded, and then,
-- for the calls that are safe to make, the call is made and its answer or its error recorded.
--
-- The list of names is tools/surface.py's, generated from the Family sources into Surface.lua;
-- nothing in it is typed from memory. The calls below are the one hand-written part, and they
-- are hand-written because only a person can say a call is safe: anything that opens a
-- window, sends a query to the server or changes what the character is doing is looked up and
-- never called.
--
-- It reads. It writes one saved variable. It sends nothing anywhere.

local ADDON, Surface = ...

-- An error is kept longer than an answer: its path comes first and what it says comes last.
local LIMIT, ERROR_LIMIT = 80, 200

-- How many of a table's keys are printed. Twelve is enough for the shape of an answer and
-- short enough to read; a caller that needs a particular field asks for more, because the
-- keys are sorted and a `name` sits past the twelfth of a currency's twenty-five (L-201).
local KEYS = 12

local showTable

-- The name of the call in flight, set by `ask` for the length of the call and read by the
-- blocked-action recorder at the bottom. The client raises that event while the call is
-- running, so whatever is written here at that instant is the call it refused.
local doing

local function show(value, limit, keys)
	limit = limit or LIMIT
	local kind = type(value)
	if kind == "table" then return showTable(value, keys) end
	if kind == "function" or kind == "userdata" then return kind end
	local ok, text = pcall(tostring, value)
	if not ok then return "unprintable: " .. tostring(text) end
	if #text > limit then text = text:sub(1, limit) .. "..." end
	if kind == "string" then return '"' .. text .. '"' end
	return text
end

local function showAllWith(keys, ...)
	local count = select("#", ...)
	if count == 0 then return "(nothing)" end
	local parts = {}
	for index = 1, math.min(count, 12) do
		parts[index] = show((select(index, ...)), nil, keys)
	end
	if count > 12 then parts[#parts + 1] = "+" .. (count - 12) .. " more" end
	return table.concat(parts, " | ")
end

local function showAll(...)
	return showAllWith(nil, ...)
end

-- One level deep, keys sorted, numbers before names: `{#3 1=6948, 2=6949, 3=...}` for a
-- list, `{#2 iconID=134414, name="Hearthstone"}` for a record. Enough to see the shape of an
-- answer that the first runs recorded only as "table".
function showTable(value, keyLimit)
	keyLimit = keyLimit or KEYS
	local keys = {}
	local ok = pcall(function()
		for key in pairs(value) do keys[#keys + 1] = key end
	end)
	if not ok then return "table (unreadable)" end
	table.sort(keys, function(a, b)
		if type(a) ~= type(b) then return type(a) == "number" end
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for index = 1, math.min(#keys, keyLimit) do
		local key = keys[index]
		local inner = value[key]
		local text = type(inner) == "table" and "table" or show(inner, 40)
		parts[index] = tostring(key) .. "=" .. text
	end
	if #keys > keyLimit then parts[#parts + 1] = "..." end
	return "{#" .. #keys .. " " .. table.concat(parts, ", ") .. "}"
end

-- Every return, holes included: a call that answers nil, 3 has said two things.
local function pack(...)
	return { n = select("#", ...), ... }
end

-- A dotted name, looked up without letting a missing namespace throw.
local function lookup(name)
	local value = _G
	for part in name:gmatch("[^.]+") do
		if type(value) ~= "table" then return nil end
		value = value[part]
	end
	return value
end

-- Safe to call: each one only reads, and none of them needs a window open to be asked. Many
-- answer nothing useful out of their window - a trade skill with none open, an inbox with no
-- mailbox - and that is fine: the question here is whether the call exists and what it does
-- when made, not what it knows. Arguments are the smallest that make sense: the first index,
-- the player, the Hearthstone (item 6948, spell 8690).
local CALLS = {
	{ "GetBuildInfo" }, { "GetLocale" }, { "GetRealmName" }, { "GetNormalizedRealmName" },
	{ "GetAutoCompleteRealms" }, { "GetMaxPlayerLevel" }, { "GetMoney" }, { "GetTime" },
	{ "InCombatLockdown" }, { "GetZoneText" }, { "GetSubZoneText" }, { "GetBindLocation" },
	{ "GetXPExhaustion" }, { "GetCursorInfo" },

	{ "UnitName", "player" }, { "UnitGUID", "player" }, { "UnitLevel", "player" },
	{ "UnitRace", "player" }, { "UnitClass", "player" }, { "UnitSex", "player" },
	{ "UnitFactionGroup", "player" }, { "UnitXP", "player" }, { "UnitXPMax", "player" },
	{ "UnitCharacterPoints", "player" }, { "UnitCreatureFamily", "pet" },
	{ "C_CreatureInfo.GetRaceInfo", 1 },

	{ "GetNumSkillLines" }, { "GetSkillLineInfo", 1 }, { "GetProfessions" },
	{ "GetNumTradeSkills" }, { "GetTradeSkillLine" }, { "GetNumCrafts" },
	{ "C_TradeSkillUI.GetTradeSkillLine" }, { "C_TradeSkillUI.GetAllRecipeIDs" },

	{ "GetNumSpecGroups" }, { "GetNumTalentGroups" }, { "GetActiveSpecGroup" },
	{ "GetActiveTalentGroup" }, { "GetSpecialization" }, { "GetSpecializationInfo", 1 },
	{ "C_SpecializationInfo.GetSpecialization" }, { "GetNumTalentTabs" },
	-- The reader Scanners/Talents.lua tries first, asked the way it asks.
	{ "C_SpecializationInfo.GetTalentInfo",
		{ tier = 1, column = 1, groupIndex = 1, isInspect = false } },
	{ "GetTalentTabInfo", 1 }, { "GetNumTalents", 1 }, { "GetTalentInfo", 1, 1 },
	{ "GetNumTalentTiers" }, { "GetNumGlyphSockets" }, { "GetGlyphSocketInfo", 1 },
	{ "HasPetSpells" }, { "GetPetTrainingPoints" },

	{ "GetNumSpellTabs" }, { "GetSpellTabInfo", 1 }, { "GetSpellBookItemInfo", 1, "spell" },
	{ "GetSpellBookItemName", 1, "spell" }, { "GetSpellInfo", 8690 },
	{ "C_Spell.GetSpellInfo", 8690 }, { "GetSpellSubtext", 8690 },

	{ "GetItemInfo", 6948 }, { "C_Item.GetItemInfo", 6948 }, { "GetItemInfoInstant", 6948 },
	{ "C_Item.GetItemInfoInstant", 6948 }, { "GetItemIcon", 6948 },
	{ "C_Item.GetItemInventoryTypeByID", 6948 }, { "C_Item.GetDetailedItemLevelInfo", 6948 },
	{ "GetContainerItemID", 0, 1 }, { "C_Container.GetContainerItemID", 0, 1 },
	{ "GetInventoryItemID", "player", 1 }, { "GetInventoryItemLink", "player", 1 },
	{ "GetNumBankSlots" },

	{ "GetNumQuestLogEntries" }, { "GetQuestLogTitle", 1 }, { "GetNumQuestLeaderBoards", 1 },
	{ "GetQuestLogLeaderBoard", 1, 1 }, { "GetNumFactions" }, { "GetFactionInfo", 1 },

	{ "GetCurrencyListSize" }, { "C_CurrencyInfo.GetCurrencyListSize" },
	{ "GetCurrencyListInfo", 1 }, { "GetHonorCurrency" }, { "GetArenaCurrency" },

	{ "IsInGuild" }, { "GetGuildInfo", "player" }, { "GetNumGuildMembers" },
	{ "GetGuildRosterInfo", 1 }, { "GetNumGuildBankTabs" },

	{ "GetTotalAchievementPoints" }, { "GetCategoryList" },

	{ "GetInboxNumItems" }, { "GetMerchantNumItems" }, { "GetNumAuctionItems", "list" },
	{ "CanSendAuctionQuery" }, { "C_AuctionHouse.GetNumReplicateItems" },
	{ "C_AuctionHouse.GetNumOwnedAuctions" }, { "GetStablePetInfo", 1 },

	{ "C_Map.GetBestMapForUnit", "player" }, { "C_AddOns.IsAddOnLoaded", ADDON },
	{ "C_AddOns.GetAddOnMetadata", ADDON, "Version" }, { "GetAddOnMetadata", ADDON, "Version" },
	{ "C_Texture.GetAtlasInfo", "auctionhouse-icon-favorite" },
}

-- The relayed brief (MIDNIGHT.md §13) names five namespaces Family has never used. Their
-- functions are **listed** on every client and called on none of it by this list: a name written
-- down settles most of what the brief claims - whether `GetFactionDataByIndex` is there at all -
-- and costs nothing, where calling an unknown function is what took Mists down (L-200).
-- The last three come from the second brief (§14) and are named the same way and for the same
-- reason: `C_Garrison`, `C_ToyBox` and `C_Heirloom` are domains Family has never recorded, and
-- the census knows only that they exist and how many functions each holds. `C_Traits` and
-- `C_ClassTalents` are not here because the word list below already matches them by name.
local BRIEF_SPACES = { "C_Reputation", "C_MajorFactions", "C_Bank", "C_WeeklyRewards",
	"C_MythicPlus", "C_PetJournal", "C_Garrison", "C_ToyBox", "C_Heirloom" }

-- And these are called, with the arguments a person chose, where the sweep is allowed to run.
-- Each one is a read the brief names and Family would need if that category is ever recorded.
local BRIEF_CALLS = {
	{ "C_Reputation.GetNumFactions" }, { "C_Reputation.GetFactionDataByIndex", 1 },
	{ "C_MajorFactions.GetMajorFactionIDs" },
	{ "C_WeeklyRewards.GetActivities" }, { "C_MythicPlus.GetRunHistory", false, true },
	{ "C_PetJournal.GetNumPets" }, { "C_ClassTalents.GetActiveConfigID" },
	{ "C_Bank.FetchPurchasedBankTabIds", function()
		return _G.Enum and _G.Enum.BankType and _G.Enum.BankType.Account
	end },
}

-- Asked everywhere: `C_QuestLog` is a namespace Family already uses, and an index is the same
-- argument the absent `GetQuestLogTitle(1)` took.
local QUEST_CALL = { "C_QuestLog.GetInfo", 1 }

-- What the brief calls unreadable Secret Values in combat. Not a lookup but a comparison: the
-- same reads are asked out of combat at login and again two seconds into a fight, and the two
-- are written down side by side. Nothing here is assumed about how an unreadable answer prints -
-- if the two readings differ, that is the finding, and if they do not, that is also the finding.
local COMBAT_CALLS = {
	{ "InCombatLockdown" }, { "UnitLevel", "player" }, { "UnitClass", "player" },
	{ "GetMoney" }, { "GetInventoryItemLink", "player", 1 },
	{ "C_Item.GetItemInfoInstant", 6948 },
	{ "GetSpecialization" }, { "GetSpecializationInfo", 1 },
	{ "C_SpecializationInfo.GetTalentInfo",
		{ tier = 1, column = 1, groupIndex = 1, isInspect = false } },
	{ "C_Container.GetContainerNumSlots", 0 }, { "C_Container.GetContainerItemInfo", 0, 1 },
	QUEST_CALL,
}

-- The values of an enumeration, read rather than called. The brief puts the warband bank behind
-- `Enum.BagIndex.AccountBankTab_1`; §6 found bag 12 by sweeping the ids, and these two readings
-- either agree or one of them is wrong.
local ENUMS = { "Enum.BagIndex", "Enum.BankType" }

-- Arguments worked out when the window is open, the way Family works them out.
local function firstRecipe()
	local api = _G.C_TradeSkillUI
	local ids = api and api.GetAllRecipeIDs and api.GetAllRecipeIDs()
	return type(ids) == "table" and ids[1] or nil
end
local function bank() return _G.BANK_CONTAINER or -1 end
local function firstBankBag() return (_G.NUM_BAG_SLOTS or 4) + 1 end

-- Defined below, after `ask`, and used by the windows.
local ask, sweep, namedReads, discover, professionLines, briefCalls

-- Asked two seconds after the window's own event, so that what it lists has arrived. Only
-- reads: nothing here queries the server, and the auction house calls read what the window
-- has already loaded. Old and new calls side by side, because each client answers one set.
local WINDOWS = {
	TRADE_SKILL_SHOW = { key = "tradeSkill", extra = function()
		local lines = discover("Prof")
		for _, call in ipairs {
			{ "C_TradeSkillUI.GetBaseProfessionInfo" }, { "C_TradeSkillUI.GetChildProfessionInfo" },
			{ "C_TradeSkillUI.GetChildProfessionInfos" },
			{ "C_TradeSkillUI.GetProfessionChildSkillLineID" },
			{ "C_TradeSkillUI.GetProfessionInventorySlots" },
			{ "C_TradeSkillUI.IsRecipeFirstCraft", firstRecipe },
			{ "C_TradeSkillUI.GetRecipeCooldown", firstRecipe },
			{ "C_TradeSkillUI.GetQualitiesForRecipe", firstRecipe },
		} do lines[#lines + 1] = ask(call) end
		return lines
	end, calls = {
		{ "GetProfessions" }, { "C_TradeSkillUI.GetTradeSkillLine" },
		{ "C_TradeSkillUI.GetAllRecipeIDs" }, { "C_TradeSkillUI.GetRecipeInfo", firstRecipe, keys = 40 },
		{ "C_TradeSkillUI.GetRecipeItemLink", firstRecipe },
		{ "GetNumTradeSkills" }, { "GetTradeSkillLine" }, { "GetTradeSkillInfo", 1 },
		{ "GetTradeSkillItemLink", 1 }, { "GetTradeSkillRecipeLink", 1 },
		{ "GetTradeSkillIcon", 1 }, { "GetTradeSkillCooldown", 1 },
		{ "GetNumCrafts" }, { "GetCraftInfo", 1 },
	} },
	AUCTION_HOUSE_SHOW = { key = "auctionHouse", calls = {
		{ "CanSendAuctionQuery" }, { "GetNumAuctionItems", "list" },
		{ "GetNumAuctionItems", "owner" }, { "GetAuctionItemInfo", "list", 1 },
		{ "GetAuctionItemLink", "list", 1 }, { "GetAuctionItemInfo", "owner", 1 },
		{ "C_AuctionHouse.IsThrottledMessageSystemReady" },
		{ "C_AuctionHouse.GetNumOwnedAuctions" }, { "C_AuctionHouse.GetOwnedAuctionInfo", 1 },
		{ "C_AuctionHouse.GetNumReplicateItems" }, { "C_AuctionHouse.GetReplicateItemInfo", 0 },
		{ "C_AuctionHouse.GetBrowseResults" },
	} },
	BANKFRAME_OPENED = { key = "bank", extra = function() return { sweep() } end, calls = {
		{ "GetNumBankSlots" },
		{ "C_Container.GetContainerNumSlots", bank },
		{ "C_Container.GetContainerItemInfo", bank, 1 },
		{ "C_Container.GetContainerItemLink", bank, 1 },
		{ "C_Container.GetContainerNumSlots", firstBankBag },
		{ "C_Container.ContainerIDToInventoryID", firstBankBag },
		{ "GetContainerNumSlots", bank }, { "GetContainerItemInfo", bank, 1 },
		{ "GetContainerItemLink", bank, 1 },
	} },
	MAIL_SHOW = { key = "mailbox", calls = {
		{ "GetInboxNumItems" }, { "GetInboxHeaderInfo", 1 }, { "GetInboxItem", 1, 1 },
		{ "GetInboxItemLink", 1, 1 },
	} },
	-- Two seconds into a fight, which is when the brief says an answer may come back
	-- unreadable. The same calls were asked out of combat at login, under `combatOut`.
	PLAYER_REGEN_DISABLED = { key = "combat", calls = COMBAT_CALLS, extra = function()
		return { "InCombatLockdown() when asked: " .. tostring(InCombatLockdown()) }
	end },
	MERCHANT_SHOW = { key = "merchant", shown = "MerchantFrame", atOnce = true, extra = function() return namedReads("C_MerchantFrame") end,
	calls = {
		{ "GetMerchantNumItems" }, { "GetMerchantItemInfo", 1 }, { "GetMerchantItemLink", 1 },
		{ "GetMerchantItemCostInfo", 1 },
	} },
}

function ask(call)
	local name = call[1]
	local fn = lookup(name)
	local args = {}
	for index = 2, #call do
		local arg = call[index]
		if type(arg) == "function" then
			local ok, value = pcall(arg)
			arg = ok and value or nil
		end
		args[index - 1] = arg
	end
	local shown = #call > 1 and showAll(unpack(args, 1, #call - 1)) or ""
	if type(fn) ~= "function" then
		return name .. "(" .. shown .. ") absent (" .. type(fn) .. ")"
	end
	-- What is being called, for as long as the call lasts. The client raises its blocked-action
	-- event **during** the call, and on 2026-09-20 it named the function `UNKNOWN()`, so the only
	-- thing on this machine that can say which call it was is this file's own bookkeeping.
	doing = name .. "(" .. shown .. ")"
	local results = pack(pcall(fn, unpack(args, 1, #call - 1)))
	doing = nil
	if results[1] then
		-- `keys` on the call asks for a wider table than the usual twelve, for an answer
		-- whose interesting field sorts past it.
		return name .. "(" .. shown .. ") answers "
			.. showAllWith(call.keys, unpack(results, 2, results.n))
	end
	return name .. "(" .. shown .. ") throws " .. show(results[2], ERROR_LIMIT)
end

-- Which container ids hold slots, across a range wide enough not to need knowing where a
-- client keeps things. Asked at login and again with the bank open: the ids that hold slots
-- only then are the bank. Each is written with its slot count and the first item found in it.
local SWEEP_FROM, SWEEP_TO = -20, 40

function sweep()
	local api = _G.C_Container
	local count = api and api.GetContainerNumSlots or _G.GetContainerNumSlots
	local info = api and api.GetContainerItemInfo
	if type(count) ~= "function" then return "GetContainerNumSlots absent" end
	local found = {}
	for id = SWEEP_FROM, SWEEP_TO do
		local ok, slots = pcall(count, id)
		if ok and type(slots) == "number" and slots > 0 then
			local first
			for slot = 1, slots do
				local got, item = pcall(info or function() end, id, slot)
				if got and type(item) == "table" and item.itemID then
					first = item.itemID .. " at " .. slot
					break
				end
			end
			found[#found + 1] = id .. "=" .. slots .. (first and (" (" .. first .. ")") or "")
		end
	end
	return ("C_Container.GetContainerNumSlots(%d..%d) answers %s"):format(SWEEP_FROM, SWEEP_TO,
		#found > 0 and table.concat(found, " | ") or "(nothing)")
end

-- Named from memory rather than taken from Family's sources, and recorded as such: where the
-- A name counts as a read when it begins with one of these words **as a word**: the character
-- after the prefix must be upper case. Without that rule `^Can` also matches `Cancel…`, and on
-- 2026-09-20 version 9 called twelve of those on a live character - `C_AuctionHouse.CancelAuction()`
-- among them (L-205). Nothing is known to have been changed by any of them, because none was given
-- the argument it would have needed; that is luck rather than a property of this file. The
-- decision of 2026-09-19 justified the sweep with *actions are never called, since no action is
-- named that way*; that sentence was false and is now false by measurement.
--
-- `Get`, `Is` and `Has` showed no such over-match in the 639 names that run swept, but they are
-- held to the same rule, because what failed was the shape of the test and not the word it was
-- applied to. One function, two call sites, different word lists.
local SWEEP_PREFIXES = { "Get", "Is", "Can", "Has" }
local NAMED_PREFIXES = { "Get", "Is" }

local function isRead(name, prefixes)
	for _, prefix in ipairs(prefixes) do
		if name:find("^" .. prefix .. "%u") then return true end
	end
	return false
end

-- A name that begins with a read word and then continues it into another word - `Cancel` out of
-- `Can`. Written down rather than merely skipped, so that the next run is audited by reading a
-- line instead of by an incident.
local function continuesTheWord(name, prefixes)
	for _, prefix in ipairs(prefixes) do
		if name:find("^" .. prefix) and not name:find("^" .. prefix .. "%u") then return true end
	end
	return false
end

-- merchant's GetMerchantItemInfo went on Midnight is not in any namespace Family uses, and the
-- decision of 2026-09-19 names a namespace only when a missing call needs one. This one does.
local NAMED = { "C_MerchantFrame" }

-- Every read in a named namespace, asked with index 1 when its window is open. Found by the
-- functions' own names - Get, Is - rather than by naming them, which would be guessing.
function namedReads(space)
	local api = _G[space]
	if type(api) ~= "table" then return { space .. " absent (" .. type(api) .. ")" } end
	local names = {}
	for key, value in pairs(api) do
		if type(value) == "function" and isRead(tostring(key), NAMED_PREFIXES) then
			names[#names + 1] = key
		end
	end
	table.sort(names)
	local lines = {}
	for _, name in ipairs(names) do lines[#lines + 1] = ask({ space .. "." .. name, 1 }) end
	return lines
end

-- Every C_ namespace this client has, with how many functions each holds. Listed rather than
-- named: where a profession's specialisations or a house's decor live is not in any namespace
-- Family uses, and listing them all observes where instead of guessing.
local function census()
	local found = {}
	for name, space in pairs(_G) do
		if type(name) == "string" and name:find("^C_") and type(space) == "table" then
			local count = 0
			pcall(function()
				for _, value in pairs(space) do
					if type(value) == "function" then count = count + 1 end
				end
			end)
			found[#found + 1] = name .. "=" .. count
		end
	end
	table.sort(found)
	return found
end

-- Words taken from the briefs (MIDNIGHT.md §8, §10 and §11). A namespace whose own name holds one
-- has its functions listed, and its reads - Get, Is, Can, Has - asked with no arguments: an
-- answer, or an error that usually says what the call wants.
local WORDS = { "Prof", "Trade", "Craft", "Trait", "Talent", "Catalyst", "Housing", "House",
	"Decor", "Neighborhood" }

-- And it is asked on Midnight and on no other client. On Mists 5.5.4, build 69585, version 6
-- took the process down 28 seconds into the world: ACCESS_VIOLATION reading address 0, with
-- `C_Housing.GetMaxHouseLevel()` on the Lua stack - the same call that answers 12 on Midnight.
-- The three `pcall`s between it and the login timer caught nothing, because a native null
-- dereference is not a Lua error (L-200). A call with no arguments is only safe where it has
-- been seen to be safe, so the sweep stays where it has run whole: interface 120000 and up.
local DISCOVER_FROM = 120000

local function mayDiscover()
	local interface = select(4, GetBuildInfo())
	return type(interface) == "number" and interface >= DISCOVER_FROM
end

local function matching(word)
	local spaces = {}
	for name, space in pairs(_G) do
		if type(name) == "string" and name:find("^C_") and type(space) == "table" then
			for _, each in ipairs(word and { word } or WORDS) do
				if name:find(each, 1, true) then spaces[#spaces + 1] = name break end
			end
		end
	end
	table.sort(spaces)
	return spaces
end

function discover(word)
	local lines = {}
	if not mayDiscover() then
		-- Written down rather than left out: a run with no discovery lines in it should say
		-- why, or the next reader takes an absence for an answer.
		return { ("discovery skipped: the no-argument sweep runs on interface %d and up, and "
			.. "this client is %s"):format(DISCOVER_FROM, tostring(select(4, GetBuildInfo()))) }
	end
	for _, space in ipairs(matching(word)) do
		local names, refused = {}, {}
		for key, value in pairs(_G[space]) do
			local text = tostring(key)
			if type(value) == "function" then
				if isRead(text, SWEEP_PREFIXES) then
					names[#names + 1] = text
				elseif continuesTheWord(text, SWEEP_PREFIXES) then
					refused[#refused + 1] = text
				end
			end
		end
		table.sort(names)
		table.sort(refused)
		-- The near miss is written down, and only the near miss: a name that begins with a read
		-- word and then turns into another one. Every other name in the namespace is skipped in
		-- silence, as it always was. This line is how the next reader audits the filter by
		-- reading rather than by watching an action happen (L-205).
		if #refused > 0 then
			lines[#lines + 1] = ("%s: %d name(s) begin with a read word and continue it, so are"
				.. " listed and not called: %s"):format(space, #refused, table.concat(refused, " "))
		end
		for _, name in ipairs(names) do lines[#lines + 1] = ask({ space .. "." .. name }) end
	end
	return lines
end

-- The brief's calls (MIDNIGHT.md §13). The quest one is asked on every client: `C_QuestLog` is
-- a namespace Family already uses and the argument is an index, the same one the absent
-- `GetQuestLogTitle(1)` took. The rest are asked only where the sweep is allowed, because this
-- repository has never seen any of them answer, and L-200 is what a first call can cost on the
-- wrong client. Their names are written down everywhere regardless, by the listing above.
function briefCalls()
	local lines = { ask(QUEST_CALL) }
	if not mayDiscover() then
		lines[#lines + 1] = ("the brief's other calls are skipped below interface %d, and this "
			.. "client is %s - their namespaces are listed rather than called")
			:format(DISCOVER_FROM, tostring(select(4, GetBuildInfo())))
		return lines
	end
	for _, call in ipairs(BRIEF_CALLS) do lines[#lines + 1] = ask(call) end
	return lines
end

-- A second brief, relayed 2026-09-20 (MIDNIGHT.md §14), names four domains Family has never
-- recorded: PvP standing, raid lockouts, the account-wide collections and the mission tables.
-- None of their names are in Surface.lua, because that list is generated from what Family calls,
-- so they are hand-written like everything else in this file that is called.
--
-- Presence is read on **every** client and calling is not, which is the same division the first
-- brief settled into (L-200). It is also the right division for what this brief claims: *supported
-- in all versions* is a statement about a name existing, and a lookup answers it for nothing.
-- The shape of the line matters as much as the reading in it. `tools/surface.py` keys a line by
-- what precedes a `)` and compares the words after it, so a line with neither is written into the
-- file and then dropped by every comparison the report makes - which is a block that looks
-- measured and answers nothing (L-202). Hence `name (looked up) is ...`: the key is the same on
-- every client and the answer is the part that differs. And `absent` rather than `nil`, because
-- the report treats a nil as *this character happens to hold nothing* and forgives it.
local function presence(name, what)
	local value = lookup(name)
	local kind = type(value)
	local answer = kind == "nil" and "absent" or kind
	if kind == "number" or kind == "string" then answer = kind .. " " .. show(value) end
	return name .. " (" .. (what or "looked up") .. ") is " .. answer
end

-- Looked up everywhere, called where the sweep is allowed, and the skipped run says so rather
-- than leaving a shorter block for the next reader to misread as an absence.
local function guarded(reads, what)
	local lines = {}
	for _, call in ipairs(reads) do lines[#lines + 1] = presence(call[1]) end
	if not mayDiscover() then
		lines[#lines + 1] = ("the %s calls are skipped below interface %d, and this client is %s -"
			.. " the names above are looked up rather than called"):format(what, DISCOVER_FROM,
			tostring(select(4, GetBuildInfo())))
		return lines
	end
	for _, call in ipairs(reads) do lines[#lines + 1] = ask(call) end
	return lines
end

-- The rank is the argument its own reader answers with, so it is worked out at the moment of
-- asking the way a window's arguments are.
local function playerRank()
	return _G.UnitPVPRank and _G.UnitPVPRank("player")
end

local PVP_READS = {
	{ "UnitHonor", "player" }, { "UnitHonorMax", "player" }, { "UnitHonorLevel", "player" },
	{ "UnitPVPRank", "player" }, { "GetPVPRankInfo", playerRank },
	{ "GetPVPLifetimeStats" }, { "GetPVPSessionStats" }, { "GetPVPYesterdayStats" },
}

-- The brief says a lockout is read by the same two calls on every client it has ever been read
-- on. That is the one claim in it which, if true, is worth a module that needs no fourth column.
local LOCKOUT_READS = { { "GetNumSavedInstances" }, { "GetSavedInstanceInfo", 1 } }

-- Honour and conquest, which the brief says are ordinary currencies on Midnight. This is the one
-- new reading asked on every client, because the id is what is new and not the call:
-- `C_CurrencyInfo.GetCurrencyInfo` is already asked everywhere by professionLines below. Thirty
-- keys, because `totalEarned` and `maxQuantity` are the fields the claim is about and they sort
-- past the twelfth of a currency's twenty-five (L-201).
local CURRENCY_IDS = {
	{ "C_CurrencyInfo.GetCurrencyInfo", 1792, keys = 30 },
	{ "C_CurrencyInfo.GetCurrencyInfo", 1602, keys = 30 },
}

local function pvpReads()
	local lines = guarded(PVP_READS, "PvP")
	for _, call in ipairs(CURRENCY_IDS) do lines[#lines + 1] = ask(call) end
	return lines
end

local function lockoutReads()
	return guarded(LOCKOUT_READS, "lockout")
end

-- Thirteen event names the brief uses that Family does not. They are asked with the generated
-- literals and written into the same block, because that is the block the report compares against
-- the control - and because a name no Family file mentions is marked `(no file found)` there,
-- which says where it came from without a second list saying so. `BAG_UPDATE` is among them
-- although Family deliberately listens to `BAG_UPDATE_DELAYED` instead (`Core.lua`), since
-- whether the un-coalesced event still exists is a fact about the client either way.
local BRIEF_EVENTS = { "BAG_UPDATE", "CHAT_MSG_COMBAT_HONOR_GAIN",
	"GARRISON_FOLLOWER_LIST_UPDATE", "GARRISON_MISSION_LIST_UPDATE", "HEIRLOOMS_UPDATED",
	"HONOR_XP_UPDATE", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "NEW_MOUNT_ADDED",
	"PET_JOURNAL_LIST_UPDATE", "PVP_HONOR_XP_UPDATE", "TOYS_UPDATED", "UPDATE_INSTANCE_INFO",
	"WEEKLY_REWARDS_UPDATE" }

-- Every `WOW_PROJECT` constant this client has, with its value. Swept rather than named, because
-- naming three of them from a brief is how a fourth is missed. The brief proposes branching on
-- `WOW_PROJECT_ID`; this branch does not - what a client can do is data in Capabilities.lua and
-- a question for Family:TryCall (CLAUDE.md) - but what the constant answers on each client is
-- still a fact worth one line.
local function projectConstants()
	local found = {}
	for name, value in pairs(_G) do
		local kind = type(value)
		if type(name) == "string" and name:find("^WOW_PROJECT")
				and kind ~= "table" and kind ~= "function" then
			found[#found + 1] = presence(name, "constant")
		end
	end
	table.sort(found)
	if #found == 0 then found[1] = "WOW_PROJECT (constant) is absent on this client" end
	return found
end

-- Every skill line the client lists as a profession's, and for each its details and the
-- currency its concentration is kept in. All names Midnight reported (MIDNIGHT.md §8).
function professionLines()
	local lines = {}
	local api = _G.C_TradeSkillUI
	lines[#lines + 1] = ask({ "C_TradeSkillUI.GetAllProfessionTradeSkillLines" })
	local ok, ids = pcall(function() return api.GetAllProfessionTradeSkillLines() end)
	if ok and type(ids) == "table" then
		for _, id in ipairs(ids) do
			lines[#lines + 1] = ask({ "C_TradeSkillUI.GetProfessionInfoBySkillLineID", id })
			lines[#lines + 1] = ask({ "C_TradeSkillUI.GetConcentrationCurrencyID", id })
			local got, currency = pcall(api.GetConcentrationCurrencyID, id)
			if got and type(currency) == "number" and currency > 0 then
				lines[#lines + 1] = ask({ "C_CurrencyInfo.GetCurrencyInfo", currency, keys = 30 })
			end
		end
	end
	for index = 1, 6 do lines[#lines + 1] = ask({ "GetProfessionInfo", index }) end
	-- How many specialisations each class has, for the Devourer the talents brief names (§11).
	for class = 1, 14 do
		lines[#lines + 1] = ask({ "C_SpecializationInfo.GetNumSpecializationsForClassID", class })
	end
	-- Every currency in the list, for the Catalyst's charges (§11). Headers included, as listed.
	local count = _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetCurrencyListSize
	local got, size = pcall(count or function() end)
	for index = 1, (got and type(size) == "number") and size or 0 do
		lines[#lines + 1] = ask({ "C_CurrencyInfo.GetCurrencyListInfo", index, keys = 30 })
	end
	-- The treasure quest the professions brief names, for this character and for the account.
	lines[#lines + 1] = ask({ "C_QuestLog.IsQuestFlaggedCompleted", 89117 })
	lines[#lines + 1] = ask({ "C_QuestLog.IsQuestFlaggedCompletedOnAccount", 89117 })
	return lines
end

local current

-- Lines from the blocked-action events below. Kept out here because one can arrive before
-- the first probe has run, and must then still reach the run it belongs to.
local blocked = {}

local function probe()
	FamilySurfaceDB = FamilySurfaceDB or {}

	local version, build, date_, interface = GetBuildInfo()
	local who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
	local run = {
		version = version, build = build, date = date_, interface = interface,
		project = WOW_PROJECT_ID, locale = GetLocale(), character = who,
		when = date("%Y-%m-%d %H:%M"),
		globals = {}, members = {}, events = {}, templates = {}, calls = {}, windows = {},
	}

	-- A number or a string is written down with its value: BANK_CONTAINER being -1 on one
	-- client and something else on another is exactly what a type would hide.
	for _, name in ipairs(Surface.globals) do
		local value = _G[name]
		local kind = type(value)
		if kind == "number" or kind == "string" then
			run.globals[name] = kind .. " " .. show(value)
		else
			run.globals[name] = kind
		end
	end

	run.containers = sweep()
	run.census = table.concat(census(), " ")

	-- What each namespace Family already uses holds on this client, by name. The namespaces
	-- come from the generated list rather than from anybody's idea of what Retail has, and
	-- what they hold is where the replacement for an absent call will be found, if anywhere.
	run.namespaces = {}
	for _, name in ipairs(Surface.globals) do
		local space = _G[name]
		if name:find("^C_") and type(space) == "table" then
			local names = {}
			pcall(function()
				for key in pairs(space) do names[#names + 1] = tostring(key) end
			end)
			table.sort(names)
			run.namespaces[name] = table.concat(names, " ")
		end
	end
	for _, name in ipairs(NAMED) do
		local space = _G[name]
		if type(space) == "table" then
			local names = {}
			pcall(function()
				for key in pairs(space) do names[#names + 1] = tostring(key) end
			end)
			table.sort(names)
			run.namespaces[name .. " (named)"] = table.concat(names, " ")
		else
			run.namespaces[name .. " (named)"] = "absent (" .. type(space) .. ")"
		end
	end
	-- The brief's five, listed and not called (MIDNIGHT.md §13). A namespace that is not there
	-- is written down as absent, because "the brief named it and the client has it" is half the
	-- claim and the other half is the name of the function inside it.
	for _, name in ipairs(BRIEF_SPACES) do
		local space = _G[name]
		if type(space) == "table" then
			local names = {}
			pcall(function()
				for key, value in pairs(space) do
					if type(value) == "function" then names[#names + 1] = tostring(key) end
				end
			end)
			table.sort(names)
			run.namespaces[name .. " (brief)"] = #names .. ": " .. table.concat(names, " ")
		else
			run.namespaces[name .. " (brief)"] = "absent (" .. type(space) .. ")"
		end
	end
	-- Enumerations, read as tables. `Enum.BagIndex` is where the brief puts the warband bank.
	for _, name in ipairs(ENUMS) do
		local value = lookup(name)
		if type(value) == "table" then
			local parts = {}
			pcall(function()
				for key, inner in pairs(value) do
					parts[#parts + 1] = tostring(key) .. "=" .. tostring(inner)
				end
			end)
			table.sort(parts)
			run.namespaces[name .. " (enum)"] = table.concat(parts, " ")
		else
			run.namespaces[name .. " (enum)"] = "absent (" .. type(value) .. ")"
		end
	end
	for _, name in ipairs(Surface.members) do
		run.members[name] = type(lookup(name))
	end

	-- Refused is what an event this client does not have looks like: Family:RegisterEvent asks
	-- the same way and reads the same answer.
	local listener = CreateFrame("Frame")
	for _, list in ipairs { Surface.literals, BRIEF_EVENTS } do
		for _, name in ipairs(list) do
			local ok, problem = pcall(listener.RegisterEvent, listener, name)
			run.events[name] = ok and "registers" or ("refused: " .. show(problem, ERROR_LIMIT))
		end
	end
	listener:UnregisterAllEvents()

	-- Built on the frame type Family builds it on, "Button:UIPanelButtonTemplate".
	for _, name in ipairs(Surface.templates) do
		local kind, template = name:match("^(%w+):(.+)$")
		local ok, problem = pcall(CreateFrame, kind, nil, UIParent, template)
		if ok and problem then problem:Hide() end
		run.templates[name] = ok and "builds" or ("throws: " .. show(problem, ERROR_LIMIT))
	end

	for _, call in ipairs(CALLS) do
		run.calls[#run.calls + 1] = ask(call)
	end

	FamilySurfaceDB[(version or "?") .. " " .. who] = run
	current = run

	-- Filed as windows so the report reads them the same way; neither needs one open.
	local ok, lines = pcall(professionLines)
	run.windows.professions = ok and lines or { "professionLines throws " .. show(lines, ERROR_LIMIT) }
	ok, lines = pcall(discover)
	run.windows.discovery = ok and lines or { "discover throws " .. show(lines, ERROR_LIMIT) }
	ok, lines = pcall(briefCalls)
	run.windows.brief = ok and lines or { "briefCalls throws " .. show(lines, ERROR_LIMIT) }
	-- The out-of-combat half of the Secret Values comparison. The other half is asked when a
	-- fight starts, and the two sit side by side under `combat`.
	-- Anything the client has already refused this session, so a block that happens before
	-- the first probe is not lost.
	if #blocked > 0 then run.windows.blocked = blocked end
	run.windows.combatOut = {}
	for _, call in ipairs(COMBAT_CALLS) do
		run.windows.combatOut[#run.windows.combatOut + 1] = ask(call)
	end
	-- The second brief's four blocks (§14). None of them needs a window open, so version 9 asks
	-- nothing more of whoever runs it than version 8 did.
	ok, lines = pcall(pvpReads)
	run.windows.pvp = ok and lines or { "pvpReads throws " .. show(lines, ERROR_LIMIT) }
	ok, lines = pcall(lockoutReads)
	run.windows.lockouts = ok and lines or { "lockoutReads throws " .. show(lines, ERROR_LIMIT) }
	ok, lines = pcall(projectConstants)
	run.windows.project = ok and lines or { "projectConstants throws " .. show(lines, ERROR_LIMIT) }
	for _, space in ipairs(matching()) do
		local names = {}
		for key in pairs(_G[space]) do names[#names + 1] = tostring(key) end
		table.sort(names)
		run.namespaces[space .. " (matched)"] = table.concat(names, " ")
	end

	local counts = { absent = 0, refused = 0, throws = 0 }
	for _, kind in pairs(run.globals) do
		if kind == "nil" then counts.absent = counts.absent + 1 end
	end
	for _, kind in pairs(run.members) do
		if kind == "nil" then counts.absent = counts.absent + 1 end
	end
	for _, answer in pairs(run.events) do
		if answer:find("^refused") then counts.refused = counts.refused + 1 end
	end
	for _, line in ipairs(run.calls) do
		if line:find(") throws ", 1, true) then counts.throws = counts.throws + 1 end
	end
	print(("|cff88ccffFamily Surface|r %s (%s): %d names absent, %d literals refused as events,"
		.. " %d calls threw. Log out to write the file."):format(tostring(version),
		tostring(interface), counts.absent, counts.refused, counts.throws))
end

-- Into the run this login made; the latest opening of a window replaces the one before.
-- A window asked at once is filed under its key with "AtOnce" added, so the two moments sit side
-- by side. `shown` names the window's frame where one is named - from memory, like
-- C_MerchantFrame - and says whether it was still open when asked: a merchant list that is
-- empty after the window closed says nothing about the client.
local function askWindow(window, atOnce)
	if not current then probe() end
	local answers = {}
	if window.shown then
		local frame = _G[window.shown]
		local ok, open = pcall(function() return frame and frame:IsShown() end)
		answers[#answers + 1] = window.shown .. ":IsShown() " .. (frame == nil and "absent (nil)"
			or ok and ("answers " .. tostring(open)) or ("throws " .. show(open, ERROR_LIMIT)))
	end
	for _, call in ipairs(window.calls) do answers[#answers + 1] = ask(call) end
	if window.extra then
		local ok, lines = pcall(window.extra)
		for _, line in ipairs(ok and lines or { "extra throws " .. show(lines, ERROR_LIMIT) }) do
			answers[#answers + 1] = line
		end
	end
	local key = window.key .. (atOnce and "AtOnce" or "")
	current.windows[key] = answers
	local threw = 0
	for _, line in ipairs(answers) do
		if line:find(") throws ", 1, true) then threw = threw + 1 end
	end
	print(("|cff88ccffFamily Surface|r %s: %d calls asked, %d threw."):format(key,
		#answers, threw))
end

-- When the client stops an addon touching something reserved to its own interface, it puts up a
-- dialog that names the addon and **not the function**. Twice now that has left a session
-- reasoning about which call it might have been: once on Midnight, where the answer turned out to
-- be a `Cancel…` the sweep had no business calling (L-205), and once on Mists, where the sweep
-- does not run at all and reasoning got nowhere.
--
-- So the client is asked instead. Nothing here assumes what these events carry - the arguments
-- are written down as they arrive, whatever they are - and the line is printed in chat at the
-- moment it happens, so that whoever is at the client reads the name without waiting for a logout
-- and a file. Registered in a `pcall` each, like every other literal: a client that does not have
-- one refuses it and the other must still arrive.
local BLOCKED_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }

local function noteBlocked(event, ...)
	-- The client named the function `UNKNOWN()` on 2026-09-20, every time. What it says is
	-- kept anyway, and the call this file knows it was making is written beside it.
	local line = event .. " " .. showAll(...)
		.. " while calling " .. (doing or "nothing this file started")
	blocked[#blocked + 1] = line
	if current then current.windows.blocked = blocked end
	print("|cff88ccffFamily Surface|r blocked: " .. line)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
-- Each open event is registered in a pcall of its own: a client without one refuses it, and
-- that must not stop the others.
for event in pairs(WINDOWS) do pcall(frame.RegisterEvent, frame, event) end
for _, event in ipairs(BLOCKED_EVENTS) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event, ...)
	-- Before anything else, and never treated as a window: one of these arriving must not
	-- schedule a second probe five seconds later.
	for _, name in ipairs(BLOCKED_EVENTS) do
		if event == name then return noteBlocked(event, ...) end
	end
	local window = WINDOWS[event]
	-- A Mists vendor that sold goods answered no items two seconds after opening, so the
	-- merchant is also asked the moment it opens.
	if window and window.atOnce then
		local ok, problem = pcall(askWindow, window, true)
		if not ok then print("|cff88ccffFamily Surface|r failed: " .. tostring(problem)) end
	end
	C_Timer.After(window and 2 or 5, function()
		local ok, problem = pcall(window and askWindow or probe, window)
		if not ok then print("|cff88ccffFamily Surface|r failed: " .. tostring(problem)) end
	end)
end)

SLASH_FAMILYSURFACE1 = "/familysurface"
SlashCmdList.FAMILYSURFACE = function()
	local ok, problem = pcall(probe)
	if not ok then print("|cff88ccffFamily Surface|r failed: " .. tostring(problem)) end
end
