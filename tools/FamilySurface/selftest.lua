-- Family Surface - what can be checked without a client
--
-- Run it before copying the folder to a client:  lua5.1 tools/FamilySurface/selftest.lua
--
-- It loads the real addon with the real generated surface list, stubs the handful of client
-- functions the login path needs, and fires PLAYER_LOGIN. Two things are asserted, and both
-- are things that have already gone wrong:
--
--  1. The no-argument sweep does not run below interface 120000. Version 6 took Mists 5.5.4
--     down 28 seconds into the world - ACCESS_VIOLATION at address 0, with
--     C_Housing.GetMaxHouseLevel() on the Lua stack, inside three pcalls that caught nothing
--     (L-108). Here the namespace from that crash is in place with its calls counted, and a
--     Classic interface must leave them alone.
--  2. A currency's name survives being written down. Its table has twenty-five fields, keys
--     are printed in sorted order, and `name` sits past the twelfth - so the run that was
--     meant to answer what the Catalyst's charges are called came back without a single
--     name in it (L-109).
--
-- It proves nothing about what a client answers. It proves the probe does not do, to any
-- client, the two things it has already done.

local ROOT = arg[0]:match("^(.*)selftest%.lua$") or "tools/FamilySurface/"

local called, pvpCalled, cancelled, listener

local function stubs(interface)
	called, pvpCalled, cancelled, listener = 0, 0, 0, nil
	FamilySurfaceDB = nil
	_G.GetBuildInfo = function() return "x", "69585", "Aug 27 2026", interface end
	_G.UnitName = function() return "Tester" end
	_G.GetRealmName = function() return "Nowhere" end
	_G.GetLocale = function() return "enUS" end
	_G.WOW_PROJECT_ID = 5
	-- A second constant with the same prefix, so that the sweep is seen to find by prefix
	-- rather than by the three names the brief happens to give.
	_G.WOW_PROJECT_MAINLINE = 1
	_G.date, _G.time = os.date, os.time
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.SlashCmdList = {}
	_G.CreateFrame = function()
		local frame = {}
		-- One event this pretend client does not have, so that a refusal is seen to be written
		-- down and not silently dropped. Family:RegisterEvent reads the same refusal.
		function frame:RegisterEvent(name)
			if type(name) == "string" and name:find("GARRISON", 1, true) then
				error("unknown event " .. name, 0)
			end
		end
		function frame:UnregisterAllEvents() end
		function frame:SetScript(_, fn) listener = fn end
		function frame:Hide() end
		function frame:IsShown() return false end
		return frame
	end
	-- The namespace from the crash log. On a real Classic client these take the process
	-- down; here they only count themselves, which is enough to see whether they were called.
	_G.C_Housing = {
		GetMaxHouseLevel = function() called = called + 1 return 12 end,
		-- This one refuses the way the real client did on 2026-09-20: it raises the
		-- blocked-action event **while it is being called**, and names the function
		-- `UNKNOWN()`, exactly as Midnight does. Only the probe's own bookkeeping can say
		-- which call it was.
		GetTrackedHouseGuid = function()
			called = called + 1
			if listener then listener(nil, "ADDON_ACTION_FORBIDDEN", "FamilySurface", "UNKNOWN()") end
			return nil
		end,
	}
	_G.C_TradeSkillUI = { GetAllRecipeIDs = function() return {} end,
		-- The real one, from the run of 2026-09-20: `Cancel` begins with `Can` and is an action.
		-- If it is ever called here the count says so, and the claim below goes red.
		CancelProfessionRespec = function() cancelled = cancelled + 1 end,
		CanChangeTalents = function() return false end }
	-- One of the brief's namespaces (§13). Its functions are listed on every client and called
	-- only where the sweep is allowed, so this counter says which happened.
	_G.C_Reputation = {
		GetNumFactions = function() called = called + 1 return 7 end,
		GetFactionDataByIndex = function() called = called + 1 return {} end,
	}
	_G.C_QuestLog = { GetInfo = function() return { title = "A Quest" } end }
	-- The second brief's domains (§14): looked up on every client, called only where the sweep
	-- is allowed. One name from each block is enough to count; the rest are absent, which is
	-- itself what the probe writes down on a client that lacks them.
	_G.UnitHonorLevel = function() pvpCalled = pvpCalled + 1 return 3 end
	_G.GetNumSavedInstances = function() pvpCalled = pvpCalled + 1 return 2 end
	_G.Enum = { BankType = { Account = 2, Character = 0 },
		BagIndex = { Backpack = 0, AccountBankTab_1 = 13 } }
	-- A currency table wide enough that `name` sorts past the twelfth key, as the real one is.
	_G.C_CurrencyInfo = {
		GetCurrencyListSize = function() return 1 end,
		GetCurrencyListInfo = function()
			local info = { name = "A Named Currency", quantity = 8 }
			for index = 1, 15 do info["a" .. index] = index end
			return info
		end,
	}
end

local function load(path, surface)
	return assert(loadfile(ROOT .. path))("FamilySurface", surface)
end

local function login(interface)
	stubs(interface)
	local surface = {}
	load("Surface.lua", surface)
	load("FamilySurface.lua", surface)
	assert(listener, "no event listener was registered")
	listener(nil, "PLAYER_LOGIN")
	local _, run = next(FamilySurfaceDB)
	assert(run, "the login wrote no run")
	return run
end

local function currencyLine(run)
	for _, line in ipairs(run.windows.professions or {}) do
		if line:find("GetCurrencyListInfo(1)", 1, true) then return line end
	end
end

local failures = 0
local function check(claim, ok, detail)
	if ok then
		print("  ok    " .. claim)
	else
		failures = failures + 1
		print("  FAIL  " .. claim .. (detail and ("\n        " .. tostring(detail)) or ""))
	end
end

print("Family Surface selftest")

local mists = login(50504)
check("interface 50504 does not sweep a namespace with no arguments", called == 0,
	called .. " calls were made")
local skipped = mists.windows.discovery
check("and the run says why it did not", skipped and #skipped == 1
	and skipped[1]:find("discovery skipped", 1, true) or false, skipped and skipped[1])

local line = currencyLine(mists)
check("a currency is written down with its name", line
	and line:find('name="A Named Currency"', 1, true) or false, line)

-- The brief's namespaces: named on every client, called on none but Midnight.
local listed = mists.namespaces["C_Reputation (brief)"]
check("a namespace the brief names is listed on a Classic client",
	listed and listed:find("GetFactionDataByIndex", 1, true) ~= nil or false, listed)
local brief = table.concat(mists.windows.brief, "\n")
check("and its calls are not made there", called == 0, called .. " calls were made")
check("while the quest call, which Family's own namespace answers, still is",
	brief:find("C_QuestLog.GetInfo(1) answers", 1, true) ~= nil, brief)
check("the warband bank enumeration is written down",
	(mists.namespaces["Enum.BagIndex (enum)"] or ""):find("AccountBankTab_1=13", 1, true) ~= nil,
	mists.namespaces["Enum.BagIndex (enum)"])
check("and the out-of-combat half of the combat comparison is taken at login",
	#(mists.windows.combatOut or {}) > 0, "no combatOut block")

-- The second brief (§14): the same division, checked the same way. A name is written down on
-- every client and a call is made on none but Midnight.
local pvp = table.concat(mists.windows.pvp or {}, "\n")
check("the second brief's PvP names are looked up on a Classic client",
	pvp:find("UnitHonorLevel (looked up) is function", 1, true) ~= nil, pvp)
check("and none of its calls are made there", pvpCalled == 0, pvpCalled .. " calls were made")
local lockouts = table.concat(mists.windows.lockouts or {}, "\n")
check("and the lockout block says why it is short rather than just being short",
	lockouts:find("skipped below interface", 1, true) ~= nil, lockouts)
check("an event the brief names is asked with the generated literals, refusal and all",
	mists.events["UPDATE_INSTANCE_INFO"] == "registers"
		and (mists.events["GARRISON_MISSION_LIST_UPDATE"] or ""):find("^refused") ~= nil,
	tostring(mists.events["GARRISON_MISSION_LIST_UPDATE"]))
local project = table.concat(mists.windows.project or {}, "\n")
check("the WOW_PROJECT constants are found by their prefix, not by being named",
	project:find("WOW_PROJECT_MAINLINE (constant) is number 1", 1, true) ~= nil, project)

-- Every line of the new blocks must be one tools/surface.py can key and compare, or the block is
-- written down and then dropped by every comparison the report makes (L-110). The reader's own
-- rule is a `)` and then a lower-case word: tools/surface.py:156.
local keyed, unkeyed = 0, {}
for _, block in ipairs { "pvp", "lockouts", "project" } do
	for _, line in ipairs(mists.windows[block] or {}) do
		if line:match("^(.-%)) ([a-z]+ ?.*)$") then keyed = keyed + 1
		elseif not line:find("skipped below interface", 1, true) then
			unkeyed[#unkeyed + 1] = block .. ": " .. line
		end
	end
end
check("and every line of the new blocks is one the report can key and compare",
	keyed > 0 and #unkeyed == 0, table.concat(unkeyed, "\n        "))

local midnight = login(120100)
check("interface 120100 still sweeps", called > 0, called .. " calls were made")
-- Not a line per call: the sweep also reaches every other namespace whose name holds one of
-- its words, and those are not counted here. What is asserted is that the call the crash log
-- names was made and written down under its own name.
local swept = table.concat(midnight.windows.discovery, "\n")
check("and writes down the call the crash log names",
	swept:find("C_Housing.GetMaxHouseLevel", 1, true) ~= nil, swept)
local asked = table.concat(midnight.windows.brief, "\n")
check("and there the brief's own calls are made",
	asked:find("C_Reputation.GetNumFactions() answers 7", 1, true) ~= nil, asked)
local answered = table.concat(midnight.windows.pvp, "\n")
	.. "\n" .. table.concat(midnight.windows.lockouts, "\n")
check("and so are the second brief's, in both of its blocks",
	answered:find('UnitHonorLevel("player") answers 3', 1, true) ~= nil
		and answered:find("GetNumSavedInstances() answers 2", 1, true) ~= nil, answered)

-- The sweep on the client where it does run, held to the rule that was missing on 2026-09-20:
-- a read word has to be a whole word. `CancelProfessionRespec` begins with `Can` and is an
-- action; version 9 called it, and called C_AuctionHouse.CancelAuction() beside it. Nothing is
-- known to have been changed by either - the second was given no auction to cancel - and that is
-- luck, not a property of the probe (L-113).
check("an action whose name begins with a read word is not called, even where the sweep runs",
	cancelled == 0, cancelled .. " calls were made")
check("and the predicate that only looks like it is still called",
	swept:find("C_TradeSkillUI.CanChangeTalents() answers", 1, true) ~= nil, swept)
check("and the near miss is written down, so the filter is audited by reading",
	swept:find("CancelProfessionRespec", 1, true) ~= nil
		and swept:find("begin with a read word and continue it", 1, true) ~= nil, swept)

-- The blocked-action events. The dialog the client puts up names the addon and not the call,
-- which left two sessions reasoning about which one it had been. Whatever the client sends is
-- written down as it arrives; nothing here claims to know what that is.
stubs(120100)
local surface = {}
load("Surface.lua", surface)
load("FamilySurface.lua", surface)
listener(nil, "PLAYER_LOGIN")
local before = select(2, next(FamilySurfaceDB))
local duringLogin = table.concat(before.windows.blocked or {}, "\n")
check("a call refused while it runs is named by the probe, not by the client",
	duringLogin:find("while calling C_Housing.GetTrackedHouseGuid()", 1, true) ~= nil, duringLogin)
check("and what the client did say is kept beside it, UNKNOWN and all",
	duringLogin:find("ADDON_ACTION_FORBIDDEN", 1, true) ~= nil
		and duringLogin:find("UNKNOWN()", 1, true) ~= nil, duringLogin)
local howMany = #(before.windows.blocked or {})
listener(nil, "ADDON_ACTION_BLOCKED", "FamilySurface", "SomeProtectedThing()")
check("one arriving outside any call is written down too, and says so",
	(table.concat(before.windows.blocked, "\n")):find("nothing this file started", 1, true) ~= nil,
	table.concat(before.windows.blocked, "\n"))
check("and neither is mistaken for a window that schedules a second probe",
	#before.windows.blocked == howMany + 1, tostring(#before.windows.blocked))

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
