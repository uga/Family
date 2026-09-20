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

    for index = 1, math.min(#rest, 6) do
        out[#out + 1] = rest[index] .. "=" .. tostring(value[rest[index]])
    end
    if #rest > 6 then out[#out + 1] = "(+" .. (#rest - 6) .. " more)" end
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
        try(call)
        return "asked; run this again in a moment and see whether the count below changes"
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
        local resting = there("IsResting")
        local exhaustion = there("GetXPExhaustion")
        return table.concat({
            "resting=" .. tostring(resting and try(resting) or "absent"),
            "rested=" .. tostring(exhaustion and try(exhaustion) or "absent"),
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
        -- 392 honor and 390 conquest, by id, through whichever of the two currency calls this
        -- client carries. Ids because a name is one language (§2.1).
        local modern = inside("C_CurrencyInfo", "GetCurrencyInfo")
        local old = there("GetCurrencyInfo")
        local out = {}
        for _, pair in ipairs({ { "honor", 392 }, { "conquest", 390 } }) do
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
                out[#out + 1] = "[id " .. tostring(id) .. ", link " ..
                    (link and describe(link) or "nothing") .. "] " .. shape(answer)
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
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
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

    collect()
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff66bbffFamily Probe|r: |cffffd700/familyprobe apis|r asks what this client carries "
        .. "for quests completed, lockouts, rested and honor.")
end
