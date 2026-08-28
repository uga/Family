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
SlashCmdList.FAMILYPROBE = collect
