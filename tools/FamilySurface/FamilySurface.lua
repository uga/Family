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

local showTable

local function show(value, limit)
	limit = limit or LIMIT
	local kind = type(value)
	if kind == "table" then return showTable(value) end
	if kind == "function" or kind == "userdata" then return kind end
	local ok, text = pcall(tostring, value)
	if not ok then return "unprintable: " .. tostring(text) end
	if #text > limit then text = text:sub(1, limit) .. "..." end
	if kind == "string" then return '"' .. text .. '"' end
	return text
end

local function showAll(...)
	local count = select("#", ...)
	if count == 0 then return "(nothing)" end
	local parts = {}
	for index = 1, math.min(count, 12) do
		parts[index] = show((select(index, ...)))
	end
	if count > 12 then parts[#parts + 1] = "+" .. (count - 12) .. " more" end
	return table.concat(parts, " | ")
end

-- One level deep, keys sorted, numbers before names: `{#3 1=6948, 2=6949, 3=...}` for a
-- list, `{#2 iconID=134414, name="Hearthstone"}` for a record. Enough to see the shape of an
-- answer that the first runs recorded only as "table".
function showTable(value)
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
	for index = 1, math.min(#keys, 12) do
		local key = keys[index]
		local inner = value[key]
		local text = type(inner) == "table" and "table" or show(inner, 40)
		parts[index] = tostring(key) .. "=" .. text
	end
	if #keys > 12 then parts[#parts + 1] = "..." end
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

-- Arguments worked out when the window is open, the way Family works them out.
local function firstRecipe()
	local api = _G.C_TradeSkillUI
	local ids = api and api.GetAllRecipeIDs and api.GetAllRecipeIDs()
	return type(ids) == "table" and ids[1] or nil
end
local function bank() return _G.BANK_CONTAINER or -1 end
local function firstBankBag() return (_G.NUM_BAG_SLOTS or 4) + 1 end

-- Defined below, after `ask`, and used by the windows.
local ask, sweep, namedReads, discover, professionLines

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
		{ "C_TradeSkillUI.GetAllRecipeIDs" }, { "C_TradeSkillUI.GetRecipeInfo", firstRecipe },
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
	local results = pack(pcall(fn, unpack(args, 1, #call - 1)))
	if results[1] then
		return name .. "(" .. shown .. ") answers " .. showAll(unpack(results, 2, results.n))
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
		if type(value) == "function" and (tostring(key):find("^Get") or tostring(key):find("^Is")) then
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

-- Words taken from the two briefs (MIDNIGHT.md §8 and §10). A namespace whose own name holds one
-- has its functions listed, and its reads - Get, Is, Can, Has - asked with no arguments: an
-- answer, or an error that usually says what the call wants.
local WORDS = { "Prof", "Trade", "Craft", "Trait", "Housing", "House", "Decor", "Neighborhood" }

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
	for _, space in ipairs(matching(word)) do
		local names = {}
		for key, value in pairs(_G[space]) do
			local text = tostring(key)
			if type(value) == "function" and (text:find("^Get") or text:find("^Is")
					or text:find("^Can") or text:find("^Has")) then
				names[#names + 1] = text
			end
		end
		table.sort(names)
		for _, name in ipairs(names) do lines[#lines + 1] = ask({ space .. "." .. name }) end
	end
	return lines
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
				lines[#lines + 1] = ask({ "C_CurrencyInfo.GetCurrencyInfo", currency })
			end
		end
	end
	for index = 1, 6 do lines[#lines + 1] = ask({ "GetProfessionInfo", index }) end
	-- The treasure quest the professions brief names, for this character and for the account.
	lines[#lines + 1] = ask({ "C_QuestLog.IsQuestFlaggedCompleted", 89117 })
	lines[#lines + 1] = ask({ "C_QuestLog.IsQuestFlaggedCompletedOnAccount", 89117 })
	return lines
end

local current

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
	for _, name in ipairs(Surface.members) do
		run.members[name] = type(lookup(name))
	end

	-- Refused is what an event this client does not have looks like: Family:RegisterEvent asks
	-- the same way and reads the same answer.
	local listener = CreateFrame("Frame")
	for _, name in ipairs(Surface.literals) do
		local ok, problem = pcall(listener.RegisterEvent, listener, name)
		run.events[name] = ok and "registers" or ("refused: " .. show(problem, ERROR_LIMIT))
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
-- Each open event is registered in a pcall of its own: a client without one refuses it, and
-- that must not stop the others.
for event in pairs(WINDOWS) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event)
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
