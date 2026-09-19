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

-- Asked two seconds after the window's own event, so that what it lists has arrived. Only
-- reads: nothing here queries the server, and the auction house calls read what the window
-- has already loaded. Old and new calls side by side, because each client answers one set.
local WINDOWS = {
	TRADE_SKILL_SHOW = { key = "tradeSkill", calls = {
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
	BANKFRAME_OPENED = { key = "bank", calls = {
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
	MERCHANT_SHOW = { key = "merchant", calls = {
		{ "GetMerchantNumItems" }, { "GetMerchantItemInfo", 1 }, { "GetMerchantItemLink", 1 },
		{ "GetMerchantItemCostInfo", 1 },
	} },
}

local function ask(call)
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
local function askWindow(window)
	if not current then probe() end
	local answers = {}
	for _, call in ipairs(window.calls) do answers[#answers + 1] = ask(call) end
	current.windows[window.key] = answers
	local threw = 0
	for _, line in ipairs(answers) do
		if line:find(") throws ", 1, true) then threw = threw + 1 end
	end
	print(("|cff88ccffFamily Surface|r %s: %d calls asked, %d threw."):format(window.key,
		#answers, threw))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
-- Each open event is registered in a pcall of its own: a client without one refuses it, and
-- that must not stop the others.
for event in pairs(WINDOWS) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event)
	local window = WINDOWS[event]
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
