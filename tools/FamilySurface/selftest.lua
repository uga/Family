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

local called, listener

local function stubs(interface)
	called, listener = 0, nil
	FamilySurfaceDB = nil
	_G.GetBuildInfo = function() return "x", "69585", "Aug 27 2026", interface end
	_G.UnitName = function() return "Tester" end
	_G.GetRealmName = function() return "Nowhere" end
	_G.GetLocale = function() return "enUS" end
	_G.WOW_PROJECT_ID = 5
	_G.date, _G.time = os.date, os.time
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.SlashCmdList = {}
	_G.CreateFrame = function()
		local frame = {}
		function frame:RegisterEvent() end
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
		GetTrackedHouseGuid = function() called = called + 1 return nil end,
	}
	_G.C_TradeSkillUI = { GetAllRecipeIDs = function() return {} end }
	-- One of the brief's namespaces (§13). Its functions are listed on every client and called
	-- only where the sweep is allowed, so this counter says which happened.
	_G.C_Reputation = {
		GetNumFactions = function() called = called + 1 return 7 end,
		GetFactionDataByIndex = function() called = called + 1 return {} end,
	}
	_G.C_QuestLog = { GetInfo = function() return { title = "A Quest" } end }
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

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
