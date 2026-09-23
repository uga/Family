-- Family Probe - a throwaway addon that asks one client what it calls things
--
-- Not part of Family and never shipped with it. Copy this folder into AddOns, log in once on
-- each client and language, and send back the SavedVariables file it writes.
--
-- Why it exists: a profession has no identifier on Era. The skill list hands back "Couture"
-- and a rank and nothing that says which profession that is, so Family keys professions by
-- name - and a name is one language, which is how a Spanish client came to list five French
-- professions as never opened.
--
-- The fix is a table mapping each language's names onto one identity. Writing that table from
-- memory is exactly the sort of confidence this project does not accept: "Erste Hilfe" and
-- "Erstehilfe" look equally plausible from here and only one of them matches. So the client
-- is asked instead, and what it answers is the evidence the table is built from.
--
-- It reads. It writes one saved variable. It sends nothing anywhere.

local ADDON = ...

FamilyProbeDB = FamilyProbeDB or {}

-- Candidate identifiers, and the whole point is that these are NOT trusted.
--
-- Each is a guess at the spell that teaches a profession and at its skill line. The probe
-- asks the client what each one resolves to and writes down the answer, including "nothing".
-- Whichever of them the client recognises, and agrees with the skill list about, is a
-- verified pair; the rest are discarded. A wrong number here costs a line in a report.
local CANDIDATES = {
    { key = "Alchemy",         spell = 2259,  skillLine = 171 },
    { key = "Blacksmithing",   spell = 2018,  skillLine = 164 },
    { key = "Enchanting",      spell = 7411,  skillLine = 333 },
    { key = "Engineering",     spell = 4036,  skillLine = 202 },
    { key = "Herbalism",       spell = 2366,  skillLine = 182 },
    { key = "Leatherworking",  spell = 2108,  skillLine = 165 },
    { key = "Mining",          spell = 2575,  skillLine = 186 },
    { key = "Skinning",        spell = 8613,  skillLine = 393 },
    { key = "Tailoring",       spell = 3908,  skillLine = 197 },
    { key = "Cooking",         spell = 2550,  skillLine = 185 },
    { key = "First Aid",       spell = 3273,  skillLine = 129 },
    { key = "Fishing",         spell = 7620,  skillLine = 356 },
    { key = "Jewelcrafting",   spell = 25229, skillLine = 755 },
    { key = "Inscription",     spell = 45357, skillLine = 773 },
}

-- The globals the game already carries for the three that cannot be unlearned. Family uses
-- these today, so the probe records them as a cross-check: if the spell lookup and the global
-- disagree about what Cooking is called, that is worth knowing before shipping either.
local KNOWN_GLOBALS = {
    Cooking = "PROFESSIONS_COOKING",
    ["First Aid"] = "PROFESSIONS_FIRST_AID",
    Fishing = "PROFESSIONS_FISHING",
    Archaeology = "PROFESSIONS_ARCHAEOLOGY",
}

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

-- The skill list only reports what is visible, so a collapsed header hides its skills. Put
-- back exactly as found - leaving somebody's skill window rearranged is rude.
local function readSkillList()
    local collapsed = {}
    local count = try(GetNumSkillLines) or 0
    for index = 1, count do
        local name, isHeader, isExpanded = try(GetSkillLineInfo, index)
        if name and isHeader and not isExpanded then collapsed[name] = true end
    end

    try(ExpandSkillHeader, 0)

    local lines = {}
    count = try(GetNumSkillLines) or 0
    for index = 1, count do
        local name, isHeader, _, rank, _, _, maxRank, isAbandonable =
            try(GetSkillLineInfo, index)
        if name and not isHeader then
            lines[#lines + 1] = {
                name = name,
                rank = tonumber(rank) or 0,
                maxRank = tonumber(maxRank) or 0,
                abandonable = isAbandonable and true or false,
            }
        end
    end

    -- Back the way it was.
    count = try(GetNumSkillLines) or 0
    for index = count, 1, -1 do
        local name, isHeader = try(GetSkillLineInfo, index)
        if name and isHeader and collapsed[name] then try(CollapseSkillHeader, index) end
    end

    return lines
end

-- Where the client offers it, a name and its skill line id arrive together - which is a
-- verified pair with nothing guessed at all, and the best evidence this probe can collect.
local function readModern()
    if type(GetProfessions) ~= "function" then return nil end

    local pairsFound = {}
    local slots = { try(GetProfessions) }
    for position = 1, 6 do
        local index = slots[position]
        if index then
            local name, _, rank, maxRank, _, _, skillLine = try(GetProfessionInfo, index)
            if name then
                pairsFound[#pairsFound + 1] = {
                    name = name,
                    skillLine = tonumber(skillLine),
                    rank = tonumber(rank) or 0,
                    maxRank = tonumber(maxRank) or 0,
                    position = position,
                }
            end
        end
    end
    return pairsFound
end

local function collect()
    local locale = (GetLocale and GetLocale()) or "unknown"
    local report = FamilyProbeDB[locale] or {}
    FamilyProbeDB[locale] = report

    report.locale = locale
    report.build = { try(GetBuildInfo) }

    -- What each candidate id resolves to on this client, whatever that turns out to be.
    report.spells = report.spells or {}
    for _, candidate in ipairs(CANDIDATES) do
        local name = try(GetSpellInfo, candidate.spell)
        report.spells[candidate.key] = {
            spell = candidate.spell,
            skillLine = candidate.skillLine,
            resolved = name or false,
        }
    end

    report.globals = report.globals or {}
    for key, global in pairs(KNOWN_GLOBALS) do
        report.globals[key] = _G[global] or false
    end

    -- Accumulated across characters, because one character does not have every profession
    -- and the skill list only shows what it has.
    local who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    report.characters = report.characters or {}
    report.characters[who] = {
        skills = readSkillList(),
        modern = readModern(),
        seenAt = time(),
    }

    local found = 0
    for _, entry in pairs(report.spells) do
        if entry.resolved then found = found + 1 end
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff66bbffFamily Probe|r: %s, %d of %d ids resolved, skills read for %s. "
        .. "Log out to write the file.", locale, found, #CANDIDATES, who))
end

--------------------------------------------------------------------------------------------
-- Which calls this client carries, for backlog 5, 92, 93 and 94
--
-- Four questions were asked of the addon on 2026-09-20 - the quests a character has already
-- finished, instance lockouts, rested experience while a character is away, and honor - and each
-- brief came with an account of which API answers on which build. Those accounts disagree with
-- what this repository wrote down in `DATASOURCES.md` on at least one point, and neither side is
-- a measurement. This is the measurement.
--
-- **Nothing is unpacked by position and believed.** A return is recorded as what it is - its type
-- and, where it is small, its value - because the shape of these calls differs between builds and
-- reading them by position is the fault `Scanners/Quests.lua` and `Talents.lua` both document.
--
-- **Nothing here changes anything.** Two calls ask the server for what it already knows
-- (`QueryQuestsCompleted`, `RequestRaidInfo`), which is what the game's own windows do when they
-- open; everything else reads.
--------------------------------------------------------------------------------------------

-- Declared before the probes, which mention it, and given a body after the readers it needs.
local watchInstanceInfo

local function describe(value)
    local kind = type(value)
    if kind == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return "table(" .. count .. ")"
    end
    if kind == "string" then return '"' .. value:sub(1, 40) .. '"' end
    if kind == "function" then return "function" end
    return tostring(value)
end

-- **Every return, however many there are.** `try` above hands back eight, which is plenty for a
-- profession and not for `GetSavedInstanceInfo`: the columns this is being asked about - the
-- difficulty's name, how many bosses, how many are down - are at the end of a list longer than
-- that, and eight would have reported them as absent. So these keep the count the call really
-- answered with, and nothing is mapped onto a name.
local function packed(ok, ...)
    if not ok then return { n = 0, failed = true } end
    local count = select("#", ...)
    local out = { n = count }
    for index = 1, count do out[index] = (select(index, ...)) end
    return out
end

local function callPacked(fn, ...)
    if type(fn) ~= "function" then return nil end
    return packed(pcall(fn, ...))
end

local function shape(answer)
    if answer == nil then return "absent" end
    if answer.failed then return "the call refused these arguments" end
    if answer.n == 0 then return "no returns" end
    local out = {}
    for index = 1, answer.n do
        out[index] = index .. "=" .. describe(answer[index])
    end
    return table.concat(out, " ")
end

-- A table's own fields, because the question a currency answers is *what is in it* - the amount,
-- the cap, and whether a weekly one is there at all. Saying "table(24)" would hide the whole of
-- what backlog 5 is waiting to know.
--
-- **The ones that answer the question come first, by name.** Sorted alphabetically and cut at
-- fourteen, the first reading on Mists spent its whole allowance on `canEarnPerWeek`,
-- `description` and `iconFileID` and pushed `quantity` and the weekly cap into "+10 more" - the
-- two fields it was run for. A cut has to be made somewhere; it may as well be made where the
-- answer is not.
--
-- **And the cut is thirty, read rather than chosen** (backlog 101, DATASOURCES *A fourth case the same
-- day settles which of the two answers is right*). It was the named keys and six more in alphabetical
-- order, and an alphabetical cut is biased as well as lossy: flags sort first (`atWarWith`,
-- `canSetInactive`, `isHeader`) and the field naming the thing - `name`, `title`, `questID`,
-- `talentID` - sorts late. Four readings on the Midnight tree lost exactly that field. The widest
-- answers shaped like a *record* there are 28 and 29 keys, and everything wider is a list, where a cut
-- is right. `WANTED` stays as the memory of the currency reading that put it here; it covers nothing
-- else, and the cut is what covers the calls nobody has got wrong yet.
local CUT = 30

local WANTED = {
    "name", "currencyID", "quantity", "maxQuantity", "quantityEarnedThisWeek",
    "maxWeeklyQuantity", "totalEarned", "useTotalEarnedForMaxQty", "discovered",
}

local function fields(value)
    if type(value) ~= "table" then return describe(value) end

    local out, said = {}, {}
    for _, key in ipairs(WANTED) do
        if value[key] ~= nil and type(value[key]) ~= "table" then
            out[#out + 1] = key .. "=" .. tostring(value[key])
            said[key] = true
        end
    end

    local rest = {}
    for key, held in pairs(value) do
        if type(key) == "string" and not said[key] and type(held) ~= "table"
            and type(held) ~= "function" then
            rest[#rest + 1] = key
        end
    end
    table.sort(rest)

    local room = math.max(CUT - #out, 0)
    for index = 1, math.min(#rest, room) do
        out[#out + 1] = rest[index] .. "=" .. tostring(value[rest[index]])
    end
    if #rest > room then out[#out + 1] = "(+" .. (#rest - room) .. " more)" end
    if #out == 0 then return describe(value) end
    return table.concat(out, " ")
end

local function elapsed(fn)
    local clock = _G.debugprofilestop
    local start = clock and clock() or nil
    local answer = fn()
    if start then return answer, _G.debugprofilestop() - start end
    return answer, nil
end

local function there(name)
    local value = _G[name]
    if type(value) == "function" then return value end
    return nil
end

local function inside(namespace, name)
    local holder = _G[namespace]
    if type(holder) ~= "table" then return nil end
    if type(holder[name]) ~= "function" then return nil end
    return holder[name]
end

-- Each probe answers a sentence. A probe whose call this client does not carry says so and is
-- not a failure: that is the answer, and it is the one the capability table is built from.
local PROBES = {
    ----------------------------------------------------------------------------------------
    -- Backlog 92: the quests a character has already finished
    ----------------------------------------------------------------------------------------
    { area = "quests", name = "GetQuestsCompleted", ask = function()
        local call = there("GetQuestsCompleted")
        if not call then return "absent" end
        local into = {}
        local _, took = elapsed(function() return try(call, into) end)
        local count = 0
        for _ in pairs(into) do count = count + 1 end
        -- The table it filled, and how long filling it took: *it will lag* is the reason this
        -- feature has not been built and is a number nobody has.
        return count .. " ids" .. (took and string.format(" in %.1f ms", took) or "")
    end },

    { area = "quests", name = "C_QuestLog.GetAllCompletedQuestIDs", ask = function()
        local call = inside("C_QuestLog", "GetAllCompletedQuestIDs")
        if not call then return "absent" end
        local answer, took = elapsed(function() return try(call) end)
        local count = type(answer) == "table" and #answer or 0
        return count .. " ids" .. (took and string.format(" in %.1f ms", took) or "")
    end },

    { area = "quests", name = "C_QuestLog.IsQuestFlaggedCompleted", ask = function()
        local call = inside("C_QuestLog", "IsQuestFlaggedCompleted")
        if not call then return "absent" end
        -- One id this character really has finished, taken from whichever call above answered,
        -- and one that exists nowhere. A call that says true to both is a call that means
        -- something other than what its name says.
        local known = nil
        local fill = there("GetQuestsCompleted")
        if fill then
            local into = {}
            try(fill, into)
            for id in pairs(into) do known = id break end
        end
        local list = inside("C_QuestLog", "GetAllCompletedQuestIDs")
        if not known and list then
            local ids = try(list)
            known = type(ids) == "table" and ids[1] or nil
        end
        return "known " .. tostring(known) .. " -> " .. tostring(try(call, known or 2))
            .. ", nonsense 999999 -> " .. tostring(try(call, 999999))
    end },

    { area = "quests", name = "QueryQuestsCompleted", ask = function()
        local call = there("QueryQuestsCompleted")
        if not call then return "absent" end
        try(call)
        return "asked; if the count above grows on a second run, the answer arrives by event"
    end },

    { area = "quests", name = "GetDailyQuestsCompleted", ask = function()
        local call = there("GetDailyQuestsCompleted")
        if not call then return "absent" end
        return shape(callPacked(call))
    end },

    ----------------------------------------------------------------------------------------
    -- Backlog 93: instance lockouts
    ----------------------------------------------------------------------------------------
    { area = "instances", name = "RequestRaidInfo", ask = function()
        local call = there("RequestRaidInfo")
        if not call then return "absent" end

        -- **And the answer is read again when the server's own reply arrives.**
        --
        -- The line below this one reads the list in the same instant the request goes out, which
        -- is the shape that reports nothing whatever the truth is: `UPDATE_INSTANCE_INFO` is the
        -- client saying *now I know*, and until 2026-09-20 this probe never waited for it. A
        -- reading taken before the answer arrives is not evidence of an empty list.
        watchInstanceInfo()
        try(call)
        return "asked; the line marked 'after UPDATE_INSTANCE_INFO' below is the one to read"
    end },

    { area = "instances", name = "GetNumSavedInstances", ask = function()
        local call = there("GetNumSavedInstances")
        if not call then return "absent" end
        return tostring(try(call) or 0) .. " saved"
    end },

    { area = "instances", name = "GetSavedInstanceInfo", ask = function()
        local call = there("GetSavedInstanceInfo")
        if not call then return "absent" end
        local count = tonumber(try(there("GetNumSavedInstances") or function() return 0 end)) or 0
        if count == 0 then
            -- The case every reader will meet, and the one an addon gets wrong.
            return "nothing saved; index 1 answers: " .. shape(callPacked(call, 1))
        end
        local lines = {}
        for index = 1, math.min(count, 3) do
            lines[#lines + 1] = "[" .. index .. "] " .. shape(callPacked(call, index))
        end
        return table.concat(lines, " | ")
    end },

    -- **Where the bosses are, if they are anywhere.**
    --
    -- Read twice in Molten Core on Mists, 2026-09-21, half an hour and several bosses apart:
    -- columns 11 and 12 of `GetSavedInstanceInfo` said `1` and `0` both times, and column 3 -
    -- the countdown - was the only thing in the whole row that moved. So on that client the row
    -- does not carry boss progress, whatever it carries on Era, and *N bosses down* has to come
    -- from somewhere else or from nowhere.
    --
    -- This is the somewhere else worth asking about: a per-encounter call the client may or may
    -- not have. Asked for eight slots rather than for a count, because the count to ask for is
    -- exactly the number that is in doubt - column 11 says one, and if that is wrong then a loop
    -- bounded by it reads one boss and stops. Every answer is printed by position and nothing is
    -- unpacked on faith.
    { area = "instances", name = "GetSavedInstanceEncounterInfo", ask = function()
        local call = there("GetSavedInstanceEncounterInfo")
        if not call then return "absent" end

        local count = tonumber(try(there("GetNumSavedInstances") or function() return 0 end)) or 0
        if count == 0 then
            return "nothing saved; (1,1) answers: " .. shape(callPacked(call, 1, 1))
        end

        local lines = {}
        for slot = 1, 8 do
            local answer = callPacked(call, 1, slot)
            lines[#lines + 1] = "(1," .. slot .. ") " .. shape(answer)
        end
        return table.concat(lines, " | ")
    end },

    { area = "instances", name = "GetNumSavedWorldBosses", ask = function()
        local call = there("GetNumSavedWorldBosses")
        if not call then return "absent" end
        local count = tonumber(try(call)) or 0
        local info = there("GetSavedWorldBossInfo")
        if count == 0 or not info then return count .. " saved" end
        return count .. " saved; [1] " .. shape(callPacked(info, 1))
    end },

    { area = "instances", name = "the clock", ask = function()
        -- Seconds-to-reset only means something beside the moment it was read at.
        return "time " .. tostring(time()) .. ", server " ..
            tostring(try(there("GetServerTime") or function() return nil end))
    end },

    ----------------------------------------------------------------------------------------
    -- Backlog 94: rested experience
    ----------------------------------------------------------------------------------------
    { area = "rested", name = "the sample", ask = function()
        -- **A call that answered false is not a call that is missing**, and the first writing of
        -- this said `absent` for both: `x and try(x) or "absent"` takes the false branch on a
        -- false answer. Read on Burning Crusade 2026-09-20 off a character standing in the
        -- Valley of Trials, where *not resting* is the whole of what was being asked. The test
        -- is on the function now, and whatever it answers is printed as it is.
        local resting = there("IsResting")
        local exhaustion = there("GetXPExhaustion")
        return table.concat({
            "resting=" .. (resting and tostring(try(resting)) or "no such call"),
            "rested=" .. (exhaustion and tostring(try(exhaustion)) or "no such call"),
            "xp=" .. tostring(try(UnitXP, "player")),
            "xpMax=" .. tostring(try(UnitXPMax, "player")),
            "level=" .. tostring(try(UnitLevel, "player")),
            "where=" .. tostring(try(GetSubZoneText) or try(GetZoneText)),
            "at=" .. tostring(time()),
        }, " ")
    end },

    ----------------------------------------------------------------------------------------
    -- Backlog 5: honor, and what the weekly thing is on this build
    ----------------------------------------------------------------------------------------
    { area = "pvp", name = "UnitPVPRank / GetPVPRankInfo", ask = function()
        local rank = there("UnitPVPRank")
        if not rank then return "absent" end
        local number = try(rank, "player")
        local info = there("GetPVPRankInfo")
        if not info then return "rank " .. tostring(number) .. ", GetPVPRankInfo absent" end
        return "rank " .. tostring(number) .. " -> " ..
            shape(callPacked(info, number, "player"))
    end },

    { area = "pvp", name = "GetPVPThisWeekStats", ask = function()
        local call = there("GetPVPThisWeekStats")
        if not call then return "absent" end
        return shape(callPacked(call))
    end },

    { area = "pvp", name = "GetPVPLastWeekStats", ask = function()
        local call = there("GetPVPLastWeekStats")
        if not call then return "absent" end
        return shape(callPacked(call))
    end },

    { area = "pvp", name = "GetPVPSessionStats", ask = function()
        -- Alberto, 2026-09-20: kills and honor for this session, on Era and Burning Crusade.
        local call = there("GetPVPSessionStats")
        if not call then return "absent" end
        return shape(callPacked(call))
    end },

    { area = "pvp", name = "GetPVPYesterdayStats", ask = function()
        local call = there("GetPVPYesterdayStats")
        if not call then return "absent" end
        return shape(callPacked(call))
    end },

    { area = "pvp", name = "the honor calls that take a unit", ask = function()
        -- `UnitHonorLevel` and its two neighbours are the newer shape of the same question, and
        -- Alberto expects the first of them on Burning Crusade. Asked of the player rather than
        -- with no argument: a unit call given no unit answers nothing on some builds and errors
        -- on others, and neither is an answer about honor.
        local out = {}
        for _, name in ipairs({ "UnitHonorLevel", "UnitHonor", "UnitHonorMax" }) do
            local call = there(name)
            out[#out + 1] = name .. "=" ..
                (call and shape(callPacked(call, "player")) or "absent")
        end
        return table.concat(out, " | ")
    end },

    { area = "pvp", name = "GetPVPLifetimeStats", ask = function()
        local call = there("GetPVPLifetimeStats")
        if not call then return "absent" end
        return shape(callPacked(call))
    end },

    { area = "pvp", name = "honor and conquest as currencies", ask = function()
        -- Honor and conquest by id, through whichever of the two currency calls this client
        -- carries. Ids because a name is one language (§2.1).
        --
        -- **Four ids, because the first two were the wrong ones and answered anyway.** 392 is
        -- honor on Cataclysm and on retail, and it is what this asked alone until 2026-09-21.
        -- On Mists 5.5.4 it answers a full table named **"Honor Deprecated 3"** with
        -- `currencyID = 0`, which reads like a client that has retired honor and is nothing of
        -- the sort: `CurrencyTypes` for that build carries 1901 *Honor Points* and 1900 *Arena
        -- Points* beside three deprecated honor rows - 104, 181 and 392. 1901 is also the id
        -- Burning Crusade 2.5.6 was measured to use, twice over, from the row and from the link.
        --
        -- So the reading that looked like an answer was the probe asking a retired number and
        -- being answered politely. Present is not meaningful, and a call that answers is not
        -- thereby answering about the thing you meant.
        local modern = inside("C_CurrencyInfo", "GetCurrencyInfo")
        local old = there("GetCurrencyInfo")
        local out = {}
        for _, pair in ipairs({ { "honor 1901", 1901 }, { "arena 1900", 1900 },
            { "honor 392 (retired on Mists)", 392 }, { "conquest 390", 390 } }) do
            if modern then
                out[#out + 1] = pair[1] .. " C_CurrencyInfo -> " ..
                    fields(try(modern, pair[2]))
            elseif old then
                out[#out + 1] = pair[1] .. " GetCurrencyInfo -> " .. shape(callPacked(old, pair[2]))
            end
        end
        if #out == 0 then return "neither currency call is here" end
        return table.concat(out, " | ")
    end },

    { area = "pvp", name = "the currency list", ask = function()
        -- **By walking the list, not by asking for an id.** The two ids above are the ones
        -- Cataclysm gave honor and conquest; Burning Crusade answered nothing to either, and
        -- Family itself has never read a currency by id - `Scanners/Currencies.lua` walks the
        -- list the player sees, in whichever of its two shapes this client answers in. So this
        -- asks the same way, and what comes back names honor's real id on this build.
        -- **Which call, and what size**, before any walking. The first writing of this said
        -- "no currency list on this client" for both of the things that can be true, and they
        -- are not the same thing: a client without the call, and a client whose list is empty
        -- because this character has never earned a currency. Mists answered that sentence on
        -- a character with none, and it read as the build having no list at all.
        local modern = _G.C_CurrencyInfo
        local out = {}

        local how = "C_CurrencyInfo " .. (modern == nil and "absent" or
            (type(modern.GetCurrencyListSize) == "function"
                and ("list size " .. tostring(try(modern.GetCurrencyListSize)))
                or "has no GetCurrencyListSize"))
        how = how .. ", older GetCurrencyListSize " ..
            (type(_G.GetCurrencyListSize) == "function"
                and tostring(try(GetCurrencyListSize)) or "absent")

        -- **Which members it has, one by one.** Mists 5.5.4 answered that `C_CurrencyInfo`
        -- is there and has no `GetCurrencyListSize`, which sends Family down the older route
        -- on a client nobody expected it on. If the table still has `GetCurrencyListInfo`,
        -- the list can be walked with the older size and read as a table - which hands over
        -- `currencyID` outright and beats reading an id out of a position. That is a
        -- different route from either of the two, and it is worth knowing before one is
        -- written: absent is a fact, and so is present.
        if modern then
            local members = {}
            for _, name in ipairs({ "GetCurrencyListSize", "GetCurrencyListInfo",
                "GetCurrencyListLink", "GetCurrencyInfo", "GetBackpackCurrencyInfo" }) do
                members[#members + 1] = name ..
                    (type(modern[name]) == "function" and "=there" or "=absent")
            end
            how = how .. " (C_CurrencyInfo: " .. table.concat(members, " ") .. ")"
        end

        -- **And the same three as globals**, which the line above does not answer and Family
        -- depends on. 5.5.4 answered that `C_CurrencyInfo` keeps `GetCurrencyListLink` and has
        -- no list calls at all - so whether the *global* link is there decides whether an id on
        -- that build comes out of a link or out of a position, and only one of those two is a
        -- promise. Asked by presence, because a list of size nought cannot be walked to find out.
        local globals = {}
        for _, name in ipairs({ "GetCurrencyListInfo", "GetCurrencyListLink" }) do
            globals[#globals + 1] = name ..
                (type(_G[name]) == "function" and "=there" or "=absent")
        end
        how = how .. " (globals: " .. table.concat(globals, " ") .. ")"

        local size = modern and tonumber(try(modern.GetCurrencyListSize)) or nil
        if size and size > 0 then
            for index = 1, math.min(size, 16) do
                local info = try(modern.GetCurrencyListInfo, index)
                if type(info) == "table" and not info.isHeader then
                    local id = info.currencyID
                    if not id then
                        local link = try(modern.GetCurrencyListLink, index)
                        id = type(link) == "string" and link:match("currency:(%d+)") or nil
                    end
                    out[#out + 1] = "[" .. tostring(id) .. "] " .. tostring(info.name) ..
                        " " .. tostring(info.quantity) .. "/" .. tostring(info.maxQuantity)
                end
            end
            return how .. " -- " .. table.concat(out, " | ")
        end

        size = type(_G.GetCurrencyListSize) == "function"
            and tonumber(try(GetCurrencyListSize)) or nil
        if not size or size == 0 then
            return how .. " -- nothing to walk: either the call is not here, or this character "
                .. "has earned no currency at all. Run it on one that has some."
        end

        for index = 1, math.min(size, 16) do
            local answer = callPacked(_G.GetCurrencyListInfo, index)
            if answer and not answer[2] then
                -- **The link, printed as it comes.** Family reads a currency's id out of one
                -- and on Burning Crusade there was no id in the answer: either the call is
                -- absent, or it answers something with no currency in it, and those are
                -- different faults. Whatever comes back is shown rather than summarised.
                local link = try(_G.GetCurrencyListLink, index)
                local id = type(link) == "string" and link:match("currency:(%d+)") or nil

                -- **And the other link call, on the same index.** Both 2.5.6 and 5.5.4 keep
                -- `C_CurrencyInfo.GetCurrencyListLink` while having no list calls in that
                -- table at all, and on 2.5.6 the *global* link answered nothing whatsoever for
                -- a currency that plainly has an id. If this one answers a real link for the
                -- same row, an id comes out of a promise instead of out of a position on both
                -- builds - and if it answers nothing either, the position is all there is and
                -- that is worth knowing rather than assuming.
                local other = modern and try(modern.GetCurrencyListLink, index)
                local otherID = type(other) == "string"
                    and other:match("currency:(%d+)") or nil

                out[#out + 1] = "[id " .. tostring(id) .. ", link " ..
                    (link and describe(link) or "nothing") ..
                    ", C_CurrencyInfo link " .. (other and describe(other) or "nothing") ..
                    " -> id " .. tostring(otherID) .. "] " .. shape(answer)
            end
        end
        return how .. " -- " .. table.concat(out, " | ")
    end },

    { area = "pvp", name = "the standalone honor and arena calls", ask = function()
        local out = {}
        for _, name in ipairs({ "GetHonorCurrency", "GetArenaCurrency" }) do
            local call = there(name)
            out[#out + 1] = name .. "=" .. (call and shape(callPacked(call)) or "absent")
        end
        return table.concat(out, " | ")
    end },

    { area = "pvp", name = "GetPersonalRatedInfo", ask = function()
        local call = there("GetPersonalRatedInfo")
        if not call then return "absent" end
        local out = {}
        for bracket = 1, 4 do
            out[#out + 1] = "[" .. bracket .. "] " .. shape(callPacked(call, bracket))
        end
        return table.concat(out, " | ")
    end },

    { area = "pvp", name = "GetArenaTeam", ask = function()
        local call = there("GetArenaTeam")
        if not call then return "absent" end
        local out = {}
        for team = 1, 3 do out[#out + 1] = "[" .. team .. "] " .. shape(callPacked(call, team)) end
        return table.concat(out, " | ")
    end },
}

-- **Which announcements this client will take a registration for.**
--
-- A scanner is half a reading and half a moment to read it at, and every brief so far has named
-- events this repository has never asked about. A client refuses to register an event it has
-- never heard of, so a registration that is accepted says the name exists here.
--
-- **Accepted is not the same as fires**, and this cannot tell the two apart: an event that is
-- accepted and never sent looks exactly like one that is waiting for something to happen. What
-- it rules out is the other half - a name carried over from a build that had it, registered
-- against a client that does not, which is a scanner that never runs and says nothing.
local EVENTS = {
    instances = { "UPDATE_INSTANCE_INFO", "RAID_INSTANCE_WELCOME", "BOSS_KILL",
        "INSTANCE_LOCK_START", "INSTANCE_LOCK_STOP" },
    rested = { "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "PLAYER_XP_UPDATE" },
    pvp = { "CURRENCY_DISPLAY_UPDATE", "HONOR_XP_UPDATE", "PVP_HONOR_XP_UPDATE",
        "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_PVP_RANK_CHANGED", "PLAYER_PVP_KILLS_CHANGED" },
    quests = { "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "QUEST_QUERY_COMPLETE" },
}

-- What the server says when it has finished answering `RequestRaidInfo`, printed as a line of
-- its own because it arrives after every other line has been written.
local instanceWatcher

function watchInstanceInfo()
    if not instanceWatcher then
        instanceWatcher = CreateFrame("Frame")
        instanceWatcher:SetScript("OnEvent", function(self)
            pcall(self.UnregisterEvent, self, "UPDATE_INSTANCE_INFO")

            local count = tonumber(try(there("GetNumSavedInstances"))) or 0
            local out = {}
            for index = 1, math.min(count, 5) do
                out[#out + 1] = "[" .. index .. "] " ..
                    shape(callPacked(there("GetSavedInstanceInfo"), index))
            end

            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  |cffffd700instances|r after UPDATE_INSTANCE_INFO  %d saved%s",
                count, #out > 0 and (": " .. table.concat(out, " | ")) or ""))
        end)
    end
    pcall(instanceWatcher.RegisterEvent, instanceWatcher, "UPDATE_INSTANCE_INFO")
end

local eventFrame

local function eventsFor(area)
    if not eventFrame then eventFrame = CreateFrame("Frame") end

    local out = {}
    for _, event in ipairs(EVENTS[area] or {}) do
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        out[#out + 1] = event .. "=" .. (ok and "accepted" or "refused")
        if ok then pcall(eventFrame.UnregisterEvent, eventFrame, event) end
    end
    return table.concat(out, " | ")
end

for _, area in ipairs({ "quests", "instances", "rested", "pvp" }) do
    PROBES[#PROBES + 1] = { area = area, name = "the events this client accepts",
        ask = function() return eventsFor(area) end }
end

--------------------------------------------------------------------------------------------
-- Backlog 96: a herb node or a mining vein under the pointer
--
-- Family's possessions block fires on `OnTooltipSetItem` and `OnTooltipSetSpell`, and on the
-- newer clients on `TooltipDataProcessor` post-calls for the Item and Spell types. A Silverleaf
-- in the world is neither, so nothing Family has today fires on one.
--
-- Before a line of that is written there is one thing to find out, and it decides the whole
-- shape: **does a world object arrive here carrying an id, or a name and nothing else?** A name
-- is one language, and this project files by id (§2.1) - so a name alone means the mapping from
-- node to item has to be learned or shipped, and an id means it does not.
--
-- Route 1 of the four in the backlog entry, and the cheapest: ask the client. Two static probes
-- below answer the half that needs no hovering - which tooltip types this build knows about at
-- all - and the watcher answers the half that does.
--------------------------------------------------------------------------------------------

-- A table's member names rather than its size. `describe` would say `table(17)` and the whole
-- question here is *which seventeen* - whether one of them is an object.
local function membersOf(value)
    if type(value) ~= "table" then return "absent" end

    local names = {}
    for name in pairs(value) do names[#names + 1] = tostring(name) end
    if #names == 0 then return "present, no members" end

    table.sort(names)
    return "(" .. #names .. ") " .. table.concat(names, " ")
end

PROBES[#PROBES + 1] = { area = "nodes", name = "Enum.TooltipDataType", ask = function()
    local enum = _G.Enum
    if type(enum) ~= "table" then return "no Enum on this client" end
    return membersOf(enum.TooltipDataType)
end }

PROBES[#PROBES + 1] = { area = "nodes", name = "the modern tooltip system", ask = function()
    local processor = _G.TooltipDataProcessor
    return "TooltipDataProcessor=" .. type(processor)
        .. " AddTooltipPostCall=" .. (type(processor) == "table"
            and type(processor.AddTooltipPostCall) or "n/a")
        .. " C_TooltipInfo=" .. membersOf(_G.C_TooltipInfo)
end }

PROBES[#PROBES + 1] = { area = "nodes", name = "the frame under the pointer", ask = function()
    return "GetMouseFocus=" .. type(_G.GetMouseFocus)
        .. " GetMouseFoci=" .. type(_G.GetMouseFoci)
end }

-- **What else is drawing on this interface**, because a reading of the minimap is worth nothing
-- without it.
--
-- Four node readings were taken before anybody asked whether the client had GatherMate on it, and
-- the answer decides what `Minimap  |  "Copper Vein"` even means: the client's own tracking blip,
-- or an addon's pin anchored to the minimap. It was asked by hand in the end, which is the sort of
-- thing a reading should carry with it. Now every run says so.
PROBES[#PROBES + 1] = { area = "nodes", name = "what else is loaded", ask = function()
    local count = tonumber(try(there("GetNumAddOns"))) or 0
    if count == 0 then return "GetNumAddOns says nothing" end

    local info = there("GetAddOnInfo") or inside("C_AddOns", "GetAddOnInfo")
    local loaded = there("IsAddOnLoaded") or inside("C_AddOns", "IsAddOnLoaded")
    if not info then return count .. " addons, and no way to name them here" end

    local out = {}
    for index = 1, count do
        local name = (try(info, index))
        if type(name) == "string" and (not loaded or (try(loaded, index))) then
            out[#out + 1] = name
        end
    end

    table.sort(out)
    return "(" .. #out .. " of " .. count .. " loaded) " .. table.concat(out, " ")
end }

-- **What the modern system was asked about**, recorded by type rather than guessed at.
--
-- A post-call is registered for *every* value `Enum.TooltipDataType` carries, not for the one
-- that looks like it means an object. Which member a world node comes through is exactly what
-- is unknown, and a probe that registers the one it expects can only ever confirm itself.
--
-- Registered once and for the whole session, which a throwaway addon may do: nothing is printed
-- unless the watcher is armed.
local lastTypeName, lastTypeID
local armed = false

local function watchEveryTooltipType()
    local processor = _G.TooltipDataProcessor
    local enum = _G.Enum and _G.Enum.TooltipDataType

    if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function"
        or type(enum) ~= "table" then
        return false
    end

    for name, value in pairs(enum) do
        if type(value) == "number" then
            pcall(processor.AddTooltipPostCall, value, function(_, data)
                if not armed then return end
                lastTypeName = tostring(name)
                lastTypeID = data and data.id or nil
            end)
        end
    end

    return true
end

local function pointerFrame()
    local frame = try(there("GetMouseFocus"))
    if type(frame) ~= "table" then
        local list = try(there("GetMouseFoci"))
        frame = type(list) == "table" and list[1] or nil
    end
    if type(frame) ~= "table" then return "nothing" end

    local named = frame.GetName and try(frame.GetName, frame)
    return tostring(named or "an unnamed frame")
end

-- Six lines is more than any node tooltip has and enough to see whether the client added
-- anything of its own under the name.
local function tooltipText()
    local count = tonumber(try(GameTooltip.NumLines, GameTooltip)) or 0
    if count == 0 then return "no lines" end

    local out = {}
    for index = 1, math.min(count, 6) do
        local left = _G["GameTooltipTextLeft" .. index]
        local right = _G["GameTooltipTextRight" .. index]
        local a = left and left.GetText and try(left.GetText, left)
        local b = right and right.GetText and try(right.GetText, right)
        if a and a ~= "" then
            out[#out + 1] = index .. '="' .. a .. '"' .. (b and b ~= "" and ('/"' .. b .. '"') or "")
        end
    end

    return "(" .. count .. " lines) " .. table.concat(out, " ")
end

-- What the tooltip says it is about, asked three ways. All three answering nothing is what a
-- world object is expected to look like, and is the reading this is here for.
local function tooltipSubject()
    local itemName, itemLink = try(GameTooltip.GetItem, GameTooltip)
    local spellName, spellID = try(GameTooltip.GetSpell, GameTooltip)
    local unitName, unitToken = try(GameTooltip.GetUnit, GameTooltip)

    return "item=" .. describe(itemLink or itemName)
        .. " spell=" .. describe(spellID or spellName)
        .. " unit=" .. describe(unitToken or unitName)
end

local sightings = 0
local SIGHTINGS = 3

-- Every tooltip this saw while armed, and every one it turned down. Declared up here because the
-- disarm message reports them: *three readings, and nine tooltips went past* is a different world
-- from *three readings, and nothing else was ever offered*.
local seenWhileArmed, refused = 0, 0
local TOLD = 3

local function tally()
    return string.format("Saw %d tooltips while armed, declined %d.", seenWhileArmed, refused)
end

local function record(text)
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd700nodes|r " .. text)

    local locale = (GetLocale and GetLocale()) or "unknown"
    local report = FamilyProbeDB[locale] or {}
    FamilyProbeDB[locale] = report
    report.apis = report.apis or {}
    report.apis.nodes = report.apis.nodes or {}

    local seen = report.apis.nodes.sightings or {}
    seen[#seen + 1] = { says = text, at = time(),
        who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?") }
    report.apis.nodes.sightings = seen
end

local function dump()
    record(pointerFrame() .. "  |  " .. tooltipSubject() .. "  |  " .. tooltipText()
        .. "  |  modern=" .. (lastTypeName and (lastTypeName .. " id=" .. tostring(lastTypeID))
            or "nothing fired"))

    sightings = sightings + 1
    if sightings >= SIGHTINGS then
        armed = false
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff66bbffFamily Probe|r: that is " .. SIGHTINGS .. ", and the watcher is off again. "
            .. tally() .. " |cffffd700/familyprobe node|r arms it for three more.")
    end
end

-- **Only a tooltip that is about none of the three**, because a bag slot, a unit frame and an
-- action button are all things the pointer crosses on the way to a node, and a dump for each of
-- them is a dump nobody reads. A world object is the case where the client will not say what
-- the tooltip is about - which is the whole reason this entry exists.
--
-- A tick late, so that whatever `TooltipDataProcessor` was going to say has been said. The two
-- fire in an order nothing here controls, and reading the one from the other without waiting is
-- how a reading comes back "nothing fired" on a client where something did.
-- **And only where a node can be**, which the frame names taught us rather than a guess.
--
-- The first three readings this took on Burning Crusade went on `MiniMapTrackingButton`, the
-- minimap itself and `QuestieFrame804`: two of the three spent on things that are not nodes, out
-- of an arming that gives three. The client names none of those as an item, a spell or a unit
-- either, so the test above lets them all through.
--
-- What separates them is the frame. A world node has **no frame at all** - measured four times
-- across two builds - and a minimap blip reports the minimap. Everything else that got through was
-- a named frame belonging to an addon or to the interface. So the dump is now limited to those
-- two, and `/familyprobe node all` keeps the old behaviour for the case where the interesting
-- thing is what was filtered out.
local everything = false

local function couldBeANode()
    local frame = try(there("GetMouseFocus"))
    if type(frame) ~= "table" then
        local list = try(there("GetMouseFoci"))
        frame = type(list) == "table" and list[1] or nil
    end

    -- No frame under the pointer: the world, which is where a node is.
    if type(frame) ~= "table" then return true end

    local named = frame.GetName and try(frame.GetName, frame)
    if type(named) ~= "string" then return false end

    -- The minimap itself, and not a button sitting on it.
    return named == "Minimap" or named == "MinimapCluster"
end

-- **A refusal is a reading, and this used to throw them away.**
--
-- Reported from play 2026-09-21: armed, hovering a vein on a character who is **not a miner** -
-- the game draws the tooltip, red *Requires Mining* line and all - and the probe says nothing.
-- Which is indistinguishable, from the outside, from the tooltip never having reached the probe
-- at all. Those are two different worlds: one where the client routes that case somewhere else,
-- and one where this file declined it on a test of its own.
--
-- §2.2's rule, in the tool rather than in the addon. So every tooltip seen while armed is counted,
-- and a refusal out in the world says which gate refused it and what the client had said. Capped,
-- because a pointer crosses a great many tooltips and a probe that reports each one is one nobody
-- leaves armed.
local function decline(why)
    refused = refused + 1
    if refused > TOLD then return end

    DEFAULT_CHAT_FRAME:AddMessage("  |cff888888nodes declined|r " .. why
        .. "  |  " .. tooltipText())
end

local function onTooltipShown()
    if not armed then return end

    seenWhileArmed = seenWhileArmed + 1

    local itemName, itemLink = try(GameTooltip.GetItem, GameTooltip)
    local spellName, spellID = try(GameTooltip.GetSpell, GameTooltip)
    local unitName, unitToken = try(GameTooltip.GetUnit, GameTooltip)
    local named = itemName or itemLink or spellName or spellID or unitName or unitToken

    local couldBe = couldBeANode()

    -- Only a refusal **where a node could have been** is worth a line. A bag slot declined for
    -- being an item is the filter doing its job and is not news.
    if named then
        if couldBe then
            decline("the client named it: " .. tooltipSubject())
        end
        return
    end

    if not everything and not couldBe then return end

    if C_Timer and C_Timer.After then C_Timer.After(0, dump) else dump() end
end

local watching = false

local function watchNodes(wantEverything)
    if not watching then
        local modern = watchEveryTooltipType()
        pcall(GameTooltip.HookScript, GameTooltip, "OnShow", onTooltipShown)
        pcall(GameTooltip.HookScript, GameTooltip, "OnHide", function()
            lastTypeName, lastTypeID = nil, nil
        end)
        watching = true

        DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffFamily Probe|r: watching the tooltip"
            .. (modern and ", and every tooltip type this client knows" or "")
            .. ". Nothing is sent anywhere and nothing is changed.")
    end

    sightings = 0
    seenWhileArmed, refused = 0, 0
    armed = true
    everything = wantEverything and true or false

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff66bbffFamily Probe|r: armed. Hover a herb node, then a mining vein, then a dot on "
        .. "the minimap - three readings and it disarms itself. Skipped: anything the client can "
        .. "name as an item, a spell or a unit, and "
        .. (everything and "nothing else (|cffffd700all|r)."
            or "anything on a named frame that is not the minimap - so a quest pin and the "
            .. "tracking button no longer spend a reading. |cffffd700/familyprobe node all|r "
            .. "keeps those."))
end

local function askEverything()
    local locale = (GetLocale and GetLocale()) or "unknown"
    local report = FamilyProbeDB[locale] or {}
    FamilyProbeDB[locale] = report
    report.build = { try(GetBuildInfo) }

    local who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    report.apis = report.apis or {}

    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff66bbffFamily Probe|r: %s, build %s, %s - what this client answers",
        locale, tostring(report.build[1]), who))

    for _, probe in ipairs(PROBES) do
        local ok, says = pcall(probe.ask)
        if not ok then says = "error: " .. tostring(says) end

        -- Readings that are a sample of a moment are kept one after another; answers about
        -- which call exists replace the one before, because they cannot differ.
        report.apis[probe.area] = report.apis[probe.area] or {}
        if probe.area == "rested" then
            local samples = report.apis.rested.samples or {}
            samples[#samples + 1] = { who = who, says = says, at = time() }
            report.apis.rested.samples = samples
        else
            report.apis[probe.area][probe.name] = { says = says, who = who, at = time() }
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffd700%s|r %s|r  %s",
            probe.area, probe.name, tostring(says)))
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff66bbffFamily Probe|r: log out to write the file. Run it once per client, and twice "
        .. "a few hours apart for the rested sample.")
end

local frame = CreateFrame("Frame")
-- **When each character went away and came back**, which is the measurement every rested reading
-- was actually about and which none of them carried.
--
-- 2026-09-21: Tontazzo's overnight pair was scored against the gap between two *readings* - 19.94
-- hours - because that is all the file held. The pool fills while a character is **logged out**,
-- and those are not the same interval: a character can be read, stay logged in for hours accruing
-- nothing in the field, and only then be put away. Scored on the reading gap the rate came out at
-- 4.01% of a level per 32 hours; scored on Ziofurgone, whose logout followed his reading by nine
-- minutes, 4.95%. One of those two numbers is an artefact of the wrong interval and nothing in the
-- file can say which.
--
-- `PLAYER_LOGOUT` fires before the saved variables are written, so the moment survives. With both
-- ends recorded the next pair is scored on the interval that the rule is about, rather than on the
-- one that happened to be written down.
-- **The interval is worked out at login and stored**, not left to be worked out later from two
-- fields that the next logout will overwrite. A file sent after another session would otherwise
-- hold that session's logout beside that session's login, and the night in between - the only
-- thing anybody wanted - would be gone.
local function mark(field)
    local locale = (GetLocale and GetLocale()) or "unknown"
    local report = FamilyProbeDB[locale] or {}
    FamilyProbeDB[locale] = report

    local who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    report.away = report.away or {}
    local mine = report.away[who] or {}
    report.away[who] = mine

    local now = time()

    if field == "in" and mine.out then
        mine.awayFor = now - mine.out
        mine.cameBackAt = now
    end

    mine[field] = now
end

-- What the last absence was, for the line that reports rested. Nothing to say on a character this
-- probe has not seen go away yet, which is every character until it has been installed for one
-- logout - and saying so is the point.
local function away()
    local locale = (GetLocale and GetLocale()) or "unknown"
    local report = FamilyProbeDB[locale] or {}
    local mine = report.away and report.away[(UnitName("player") or "?") .. "-"
        .. (GetRealmName() or "?")]

    if not mine or not mine.awayFor then
        return "awayFor=unknown (this probe has not seen this character log out yet)"
    end

    return string.format("awayFor=%d s (%.2f h) out=%d back=%d",
        mine.awayFor, mine.awayFor / 3600, mine.out or 0, mine.cameBackAt or 0)
end

-- Beside the rested sample, because it is half of every sum anybody does with one.
PROBES[#PROBES + 1] = { area = "rested", name = "the last absence", ask = away }

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
-- **The rested calls asked at the one moment the answer is the one wanted.**
--
-- `Scanners/Identity.lua` already writes the logout zone during `PLAYER_LOGOUT` and measured what
-- can be read there: `GetZoneText` and `GetSubZoneText` still answer, and `GetBestMapForUnit` does
-- **not** - the map system is already gone by then. Nobody has ever asked that of
-- `GetXPExhaustion`, and the answer decides something real: a reading taken at logout is the exact
-- start of the absence, and one taken earlier is a guess about when the character actually left.
--
-- This is the shape of question that cannot be settled from a `/run`, for the same reason that one
-- could not - the moment only exists on the way out. So it is written then and read back off the
-- saved file, which is how that one was settled.
local function sampleAtLogout()
    local locale = (GetLocale and GetLocale()) or "unknown"
    local report = FamilyProbeDB[locale] or {}
    FamilyProbeDB[locale] = report
    report.apis = report.apis or {}
    report.apis.rested = report.apis.rested or {}

    for _, probe in ipairs(PROBES) do
        if probe.area == "rested" and probe.name == "the sample" then
            local ok, says = pcall(probe.ask)
            local samples = report.apis.rested.samples or {}
            samples[#samples + 1] = {
                who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"),
                says = "AT LOGOUT: " .. (ok and tostring(says) or ("error: " .. tostring(says))),
                at = time(),
            }
            report.apis.rested.samples = samples
            return
        end
    end
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        mark("out")
        sampleAtLogout()
        return
    end

    mark("in")

    -- A moment after login: the skill list is not always populated at the instant it fires.
    if C_Timer and C_Timer.After then
        C_Timer.After(5, collect)
    else
        collect()
    end
end)

SLASH_FAMILYPROBE1 = "/familyprobe"
SlashCmdList.FAMILYPROBE = function(argument)
    argument = (argument or ""):lower()

    -- The four questions of 2026-09-20. Kept off the login run: it reads a character's whole
    -- quest history and asks the server twice, which is not a thing to do to somebody who only
    -- wanted the profession names.
    if argument == "apis" then
        askEverything()
        return
    end

    -- Backlog 96, and the one probe here that needs the player to do something: nothing can ask
    -- a client what a herb node looks like except by pointing at one.
    if argument == "node" or argument == "nodes" then
        watchNodes(false)
        return
    end

    if argument == "node all" or argument == "nodes all" then
        watchNodes(true)
        return
    end

    collect()
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff66bbffFamily Probe|r: |cffffd700/familyprobe apis|r asks what this client carries "
        .. "for quests completed, lockouts, rested and honor. |cffffd700/familyprobe node|r "
        .. "watches what arrives when you hover a herb node, a vein or a minimap dot.")
end
