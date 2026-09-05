-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Getting a message from one copy of Family to another.
--
-- Everything Wide Family does (§6) travels through here, and the game's addon channel has
-- three properties that shape all of it:
--
--   **A message is 255 bytes.** A member's possessions are not. So anything larger is cut
--   into pieces here and put back together at the other end, and nothing above this file
--   knows that happened.
--
--   **The channel is shared and rate limited.** Every addon the player runs sends down it,
--   and flooding it does not drop Family's messages - it delays everybody's, including the
--   ones the game itself needs. So there is a queue and a fixed rate, and a large transfer
--   takes the time it takes.
--
--   **Delivery is not acknowledged.** A whisper to somebody who has logged out goes nowhere
--   and says nothing. Anything that matters is therefore asked for again rather than assumed
--   to have arrived, and a transfer that stops halfway is abandoned on a timer with whatever
--   arrived kept (§2.2 again: a partial answer is not a wrong one, as long as it says so).
--
-- Sending is not forbidden in combat. It is deferred all the same, for bulk only: a hundred
-- chunks during a boss fight competes with the raid's own addons for the same channel, and
-- nothing Family carries is worth that. Small control messages go straight out, because a
-- reply that waits for the fight to end is a reply nobody connects to what they asked.

local _, Family = ...

local L = Family.L

local Comm = {}
Family.Comm = Comm

-- One prefix for everything. The game registers prefixes per addon and they are a limited
-- resource shared with every other addon loaded.
local PREFIX = "Family"

-- What actually happened on the wire, at the seam between this file and the client.
--
-- Guild.stats counts every point a guild announcement can be dropped *once it is Family's*,
-- and that is one layer too high to answer the question two silent clients actually pose. A
-- guild diagnosis reading "announcements arrived: 0" is produced identically by a channel that
-- delivered nothing and by a channel that delivered everything into a handler that dropped it,
-- and the difference is the whole of the diagnosis: one is somebody else's fault and the other
-- is ours.
--
-- The line joining this file to the game has been wrong before, in exactly the way these
-- counters would have shown at a glance - the handler read the event's own name as the prefix
-- and every message Family was ever sent died on its first line, while five hundred checks
-- that called Comm:Receive directly all passed. So the count that matters is taken *above*
-- the prefix test, not below it: `events` proves the event is live at all, and `ours` proves
-- the prefix test is letting our own traffic through.
--
-- `answers` is the same argument pointed the other way. Guild.stats.sent counts what Family
-- *queued*; it says nothing about what the client did with it, so a message the client
-- refused outright is reported as sent. What the call answers is therefore kept too.
Comm.stats = { events = 0, ours = 0, malformed = 0, unhandled = 0, answers = {} }

-- What fits in a message, less the header this file puts on the front. 255 is the game's
-- limit; the rest is the message id, the sequence numbers and their separators, and it is
-- generous rather than exact because being wrong here truncates silently.
local CHUNK = 200

-- How fast the queue drains. Ten a second is the rate the community's throttling library
-- settled on for bulk traffic, and it is not worth being cleverer than that.
local PER_TICK = 2
local TICK = 0.2

-- A transfer nobody finished. Long enough for a slow exchange over a busy channel, short
-- enough that a logout does not leave half a member's bags in memory for the session.
local ABANDON_AFTER = 60

--------------------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------------------

local outgoing = {}
local nextMessageID = 0
local ticker

-- What the client said when it was handed a message, kept verbatim and never interpreted.
--
-- By value *and* by type, and decoded against nothing. These clients are three different
-- builds and the answer is part of what is being asked (DATASOURCES §2): reading a number
-- against a table of result codes written from memory would be Family claiming to know what
-- the number means when all it has is the number. The same rule the guild event log probe is
-- built on, for the same reason.
--
-- Counted per distinct answer rather than only kept as the last one, because "four sends and
-- all four said the same thing" and "three fine and one refused" are quite different
-- diagnoses and the last answer alone shows them as identical.
local function noteAnswer(key)
    local answers = Comm.stats.answers
    answers[key] = (answers[key] or 0) + 1
    Comm.stats.lastAnswer = key
end

-- A character's name without its realm, in lower case. Three things need it now and the
-- earliest is the send below, so it lives above all of them rather than being forward-declared:
-- a name used above the line that declares it is a global and nil, and this file has already
-- been caught by that once.
local function nameKey(name)
    if type(name) ~= "string" then return nil end
    local base = name:match("^([^%-]+)") or name
    return base:lower()
end

-- Who Family has just whispered, and when.
--
-- Kept so that the client's complaint about them can be taken off the screen. Walking a linked
-- family of six to find one online produces six lines of *No player named X is currently
-- playing* - the client's own, not Family's, which is why switching Family's reporting off did
-- nothing to them. Reported from play.
--
-- Keyed the way every other name in this file is keyed - without the realm. Family whispers
-- `Rolando-Thunderstrike` and the client complains about `Rolando`, so a table keyed on what
-- was addressed is a table nothing ever finds. That shipped for an hour, and the check that
-- should have caught it used a fixture with a bare name while every real caller sends a
-- realm - the fixture was easier to write than the case.
local whispered = {}

-- How long a complaint can arrive after the whisper that caused it and still be ours. Short,
-- because the one thing this must not swallow is the answer to a whisper the *player* sent.
local NOT_FOUND_WINDOW = 15

-- The client's own call, wherever it lives. It moved into C_ChatInfo partway through these
-- clients' lives and the older global is still there on the older ones.
local function sendRaw(text, channel, target)
    local api = _G.C_ChatInfo
    local call = (api and api.SendAddonMessage) or _G.SendAddonMessage

    if type(call) ~= "function" then
        noteAnswer("no such call")
        return nil
    end

    -- pcall rather than Family:TryCall, which is what the rest of Family uses and which
    -- returns nil both when a call throws and when it returns nil. Those are different
    -- diagnoses - one is a client that refused and one is a client that has no opinion - and
    -- telling them apart is the entire reason this is being recorded.
    if channel == "WHISPER" then
        local key = nameKey(target)
        if key then whispered[key] = time() end
    end

    local ok, answer = pcall(call, PREFIX, text, channel, target)
    if not ok then
        noteAnswer("threw")
        return nil
    end

    noteAnswer(type(answer) .. " " .. tostring(answer))
    return answer
end

-- Whether anything may go out right now.
--
-- Bulk waits for the fight to be over; control does not. The distinction is the caller's to
-- make, because only the caller knows whether what it is sending is an answer somebody is
-- waiting for or a hundred chunks nobody is watching.
-- One chunk first, and the rest a moment later.
--
-- The client refuses a whisper to somebody who is not there, once per message, and says so in
-- the chat frame in red. Abandoning what is still queued at the first refusal is not enough:
-- the queue drains two chunks every fifth of a second and the refusal takes a round trip, so
-- three or four had already left. A family of five characters, tried one after another,
-- produced twenty of those lines - and none of them was Family's to suppress.
--
-- So a bulk transfer sends its first chunk and then waits. If that character is not there the
-- refusal arrives inside the wait, everything else for them is dropped, and the player is told
-- once instead of four times. If they are there, the pause costs a second and a half on a
-- transfer that already takes several and that nobody is watching.
--
-- Only bulk, and only whispers: an announcement is one message and has nothing to hold back.
local PROBATION = 1.5

local probing = {}

-- When we last had a message from somebody, which is proof they were there. Kept beside the
-- queue rather than asked of Comm:Present, which records the same thing for a different
-- question and clears it on being asked.
local present = {}

local function now()
    return Family:TryCall(GetTime) or time()
end

local function readyFor(entry)
    if not entry.bulk then return true end
    if Family:TryCall(InCombatLockdown) then return false end

    if entry.channel ~= "WHISPER" or not entry.target then return true end

    local key = nameKey(entry.target)
    if not key then return true end

    -- Somebody we have just heard from is somebody who is there. Receiving a message marks
    -- its sender present, so a reply needs no canary: this paces the case of writing to a
    -- character nobody has heard from in a while, which is the case that produces the
    -- refusals.
    if present[key] and (now() - present[key]) < PROBATION * 20 then return true end

    local since = probing[key]
    if not since then
        -- This one is the canary. Nothing else for them goes until it has had time to
        -- come back refused.
        probing[key] = now()
        return true
    end

    return (now() - since) >= PROBATION
end

local function drain()
    local sent, held = 0, 0

    for index = 1, #outgoing do
        if sent >= PER_TICK then break end

        local entry = outgoing[index]
        if entry and not entry.done then
            if readyFor(entry) then
                sendRaw(entry.text, entry.channel, entry.target)
                entry.done = true
                sent = sent + 1
            else
                held = held + 1
            end
        end
    end

    -- Compacted rather than removed one at a time: taking from the front of a list inside
    -- the loop that is walking it is how a queue comes to skip every other item.
    local kept = {}
    for _, entry in ipairs(outgoing) do
        if not entry.done then kept[#kept + 1] = entry end
    end
    outgoing = kept

    -- A probe is forgotten after a while, so that a transfer minutes later probes again:
    -- somebody who was there an hour ago may not be now.
    --
    -- By age rather than by the queue emptying, which is what this did first and was wrong.
    -- An exchange is two messages, and where the first is short enough to be one chunk the
    -- queue empties between them - so the second arrived to find no probe outstanding,
    -- started its own, and went straight out beside the one that was meant to be alone.
    for key, at in pairs(probing) do
        if (now() - at) > PROBATION * 4 then probing[key] = nil end
    end

    if #outgoing == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end

    -- Something is waiting on the canary rather than on the channel, so something has to
    -- come back for it.
    --
    -- The ticker would, where there is one. There is not always one - a client without
    -- C_Timer drains in a single pass and stops - and on that path the held chunks would
    -- have waited for a caller that was never coming. Which is exactly what happened the
    -- first time this was written, and the harness is one of those clients.
    if #outgoing > 0 and held > 0 then
        -- A little after the wait rather than exactly at it. A clock accumulated a tenth of
        -- a second at a time lands a hair under the number it was counting to, so a retry
        -- scheduled for the instant the wait ends arrives to find it has not quite ended -
        -- and then schedules another, for ever.
        Family:After(PROBATION + 0.3, "comm.probation", drain)
    end
end

local function pump()
    if ticker or #outgoing == 0 then return end

    local ticked = _G.C_Timer and _G.C_Timer.NewTicker
    if ticked then
        ticker = C_Timer.NewTicker(TICK, drain)
        return
    end

    -- No ticker on this client: everything goes at once. Worse for the channel and better
    -- than not working, and Family says which it did rather than pretending.
    while #outgoing > 0 do
        local before = #outgoing
        drain()
        if #outgoing == before then break end
    end
end

-- Split a body across as many messages as it takes.
--
-- Every piece carries the message id and its place in the whole, so a receiver can put them
-- back in order and can tell two transfers apart when they interleave - which they will, as
-- soon as two people answer at once.
function Comm:Send(kind, body, channel, target, bulk)
    if type(kind) ~= "string" then return false end
    body = tostring(body or "")

    nextMessageID = nextMessageID + 1
    local id = nextMessageID

    local total = math.max(math.ceil(#body / CHUNK), 1)

    for index = 1, total do
        local piece = body:sub((index - 1) * CHUNK + 1, index * CHUNK)
        outgoing[#outgoing + 1] = {
            text = string.format("%d\1%d\1%d\1%s\1%s", id, index, total, kind, piece),
            channel = channel or "WHISPER",
            target = target,
            bulk = bulk and true or false,
        }
    end

    pump()
    return true
end

-- How much is still waiting, so a panel can say "sending, 40 of 120" rather than appearing
-- to have hung. §6 asks for exactly this.
function Comm:Pending()
    return #outgoing
end

function Comm:Abandon()
    outgoing = {}
end

--------------------------------------------------------------------------------------------
-- Whispering somebody who is not there
--
-- A whisper to a character who is offline is answered by the client, in the chat frame, once
-- per whisper. An exchange is not one whisper - a family's records take hundreds of them - so
-- pressing Update on a family whose linked character had logged out filled the screen with
-- "No player named 'Grella' is currently playing" and kept filling it, because nothing in
-- here was listening to the only thing that ever finds out.
--
-- There is no way to ask first. The client will not say whether a name is online, and the
-- addon channel acknowledges nothing (§11.1), so the failure *is* the answer - and it arrives
-- as a line of chat rather than as anything a function returns.
--------------------------------------------------------------------------------------------

-- The client's own wording, turned into something to match against. Never the English: these
-- clients ship in a dozen languages and the sentence is different in every one, while the
-- global holding it is the same everywhere.
local function patternFor(format)
    if type(format) ~= "string" or format == "" then return nil end

    -- Everything magic escaped, which turns the %s placeholder into %%s, and that is then
    -- the one piece put back as a capture.
    local escaped = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    escaped = escaped:gsub("%%%%s", "(.+)")
    return "^" .. escaped .. "$"
end

-- Names as they can actually be compared.
--
-- We whisper "Grella-Thunderstrike", because that is how the sender's name arrived and it is
-- the form that always works. The client complains about "Grella", because that is the form a
-- player typed and the realm is its own. Both are the same character and neither string is
-- wrong; they simply are not equal, which is why the first version of this dropped nothing at
-- all and the storm carried on exactly as before.
--
-- Two characters of the same name on two realms would be conflated by this. That is a real
-- cost and it is the smaller one: the alternative is what was happening, and a link is to one
-- family whose characters are usually all in one place.
local absent = {}

-- Who wants to know that a name turned out not to be there. One entry per interested part of
-- Family, by name, so registering twice replaces rather than accumulates.
--
-- A listener rather than Comm calling Wide directly: this file knows about whispers and
-- queues and has no business knowing that some of them are a family exchange with another
-- character to fall back on.
local absentListeners = {}

function Comm:OnAbsent(name, fn)
    absentListeners[name] = fn
end

-- Whether two names are the same character. Exported because everywhere that holds a name has
-- this problem and not only this file: "Grella" from the client's own complaint, and
-- "Grella-Thunderstrike" as the sender's name arrived, are one character and two strings.
-- Comparing them with == is the fault that made the first two attempts at this do nothing,
-- once in the queue and once in the list of who to try next.
function Comm:SameName(a, b)
    local first, second = nameKey(a), nameKey(b)
    return first ~= nil and first == second
end

-- How long a name stays known-absent. Long enough that the panel can answer without asking
-- the server again, short enough that somebody who logs in is not locked out of a link they
-- are sitting in front of.
local ABSENT_FOR = 60

function Comm:AbandonTo(target)
    local wanted = nameKey(target)
    if not wanted then return 0 end

    local dropped, kept = 0, {}
    for _, entry in ipairs(outgoing) do
        if entry.channel == "WHISPER" and nameKey(entry.target) == wanted then
            dropped = dropped + 1
        else
            kept[#kept + 1] = entry
        end
    end
    outgoing = kept

    return dropped
end

-- Whether this name was found to be offline recently enough to still believe it.
function Comm:Absent(target)
    local key = nameKey(target)
    local at = key and absent[key]
    if not at then return false end
    if time() - at > ABSENT_FOR then
        absent[key] = nil
        return false
    end
    return true
end

function Comm:Present(target)
    local key = nameKey(target)
    if not key then return end

    absent[key] = nil
    -- And noted as the moment we last had proof, which is what lets the queue skip its
    -- canary when writing back to somebody who has just spoken.
    present[key] = now()
end

-- The client complaining about a whisper Family sent, taken off the screen.
--
-- **Only about names Family itself has just addressed**, and only for a few seconds after. A
-- player who whispers an absent character still gets told; what goes is the client answering
-- Family's own probing, which the player never asked for and cannot act on - and which arrives
-- six times over while Family walks a linked family looking for somebody online.
--
-- Not gated on Family's reporting switch, because these are not Family's sentences: switching
-- that off already silences the one line Family writes and left these six untouched, which is
-- exactly the complaint. They go to the narration instead, so the working is still there for
-- anybody who turns it on.
--
-- The message is matched through the client's own format string, never an English one.
local function swallowNotFound(_, _, text)
    if type(text) ~= "string" then return false end

    local pattern = patternFor(_G.ERR_CHAT_PLAYER_NOT_FOUND_S)
    if not pattern then return false end

    local name = text:match(pattern)
    if not name then return false end

    local at = whispered[nameKey(name)]
    if not at or (time() - at) > NOT_FOUND_WINDOW then return false end

    Family:Debug("comm: the client says %s is not playing, and we asked", name)
    return true
end

if type(_G.ChatFrame_AddMessageEventFilter) == "function" then
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", swallowNotFound)
end

Comm.__swallowNotFound = swallowNotFound

Family:RegisterEvent("CHAT_MSG_SYSTEM", "comm.absent", function(_, text)
    local pattern = patternFor(_G.ERR_CHAT_PLAYER_NOT_FOUND_S)
    if not pattern or type(text) ~= "string" then return end

    local name = text:match(pattern)
    if not name then return end

    -- Whether we had already been told about this one, asked *before* it is written down.
    --
    -- One refusal comes back for every message that had already left, and an exchange is many
    -- messages - so the second, third and fourth are the same news arriving again. What was
    -- still queued has been abandoned by the time the first is answered; the rest are about
    -- messages nothing can be done with. A listener that acts on each of them walks the same
    -- ground again and sends again, which is how a family of five characters became twenty
    -- attempts and four copies of every sentence.
    --
    -- Told rather than worked out by each listener, because only this file knows: everything
    -- else can see that a name is absent and not that it has just become so.
    local already = Comm:Absent(name)

    absent[nameKey(name)] = time()

    -- Everything still queued for them, dropped at once. What has already gone is already
    -- being complained about; the point is that the rest does not follow it.
    local dropped = Comm:AbandonTo(name)

    -- Told before anything is said to the player, so that whoever picks this up has the
    -- chance to try somebody else and report that instead. A family is a person with several
    -- characters and only one of them is logged in; "they are not online" is only true once
    -- every one of them has been tried.
    local handled
    for _, listener in pairs(absentListeners) do
        local ok, answer = pcall(listener, name, dropped, already)
        if ok and answer then handled = true end
    end

    if dropped > 0 and not handled then
        Family:Print(L["|cffffaa00%s is not online.|r %d message(s) not sent."], name, dropped)
    end
end)

--------------------------------------------------------------------------------------------
-- Receiving
--------------------------------------------------------------------------------------------

-- Comm.stats, declared at the top of this file, is where the counting happens. Everything
-- below adds to it.

local partial = {}
local handlers = {}

-- Called with (kind, body, sender, channel). One handler per kind, which is all Wide Family
-- needs and keeps the dispatch honest: an unknown kind is dropped rather than guessed at.
function Comm:On(kind, handler)
    handlers[kind] = handler
end

local function complete(key, entry, sender, channel)
    local body = table.concat(entry.pieces)
    partial[key] = nil

    local handler = handlers[entry.kind]
    if not handler then
        Comm.stats.unhandled = Comm.stats.unhandled + 1
        Family:Debug("comm: nothing handles %s", tostring(entry.kind))
        return
    end

    local ok, err = pcall(handler, entry.kind, body, sender, channel)
    if not ok then
        Family:Debug("comm: %s handler failed: %s", tostring(entry.kind), tostring(err))
    end
end

function Comm:Receive(text, sender, channel)
    if type(text) ~= "string" then return end

    -- Hearing from somebody settles the question of whether they are there, whatever the
    -- server said a minute ago. Kept here rather than in the handler above, because this is
    -- the one place every arriving message passes through.
    Comm:Present(sender)

    local id, index, total, kind, piece =
        text:match("^(%d+)\1(%d+)\1(%d+)\1([^\1]*)\1(.*)$")
    if not id then
        Comm.stats.malformed = Comm.stats.malformed + 1
        return
    end

    index, total = tonumber(index), tonumber(total)
    if not index or not total or index > total then return end

    -- Keyed by who sent it as well as by the id, or two people transferring at once would
    -- write into each other's message.
    local key = tostring(sender) .. "\1" .. id

    local entry = partial[key]
    if not entry then
        entry = { kind = kind, pieces = {}, have = 0, total = total, at = time() }
        partial[key] = entry
    end

    if not entry.pieces[index] then
        entry.pieces[index] = piece
        entry.have = entry.have + 1
    end
    entry.at = time()

    if entry.have == entry.total then
        complete(key, entry, sender, channel)
    end
end

-- Anything that stopped halfway. Called on a timer rather than when the next piece arrives,
-- because the case that matters is the one where no next piece is coming.
function Comm:Sweep()
    local now = time()
    for key, entry in pairs(partial) do
        if now - (entry.at or now) > ABANDON_AFTER then
            Family:Debug("comm: abandoned %s after %d of %d pieces",
                tostring(entry.kind), entry.have, entry.total)
            partial[key] = nil
        end
    end
end

function Comm:Waiting()
    local count = 0
    for _ in pairs(partial) do count = count + 1 end
    return count
end

--------------------------------------------------------------------------------------------

-- One addon message off the wire, whoever it was for.
--
-- The whole of the event handler except for unpacking its arguments, and here rather than
-- there so that the seam can be exercised by a check. Everything the game hands us passes
-- through this function: the ones for other addons are counted and dropped, and ours are
-- counted again and passed on.
function Comm:Heard(prefix, text, channel, sender)
    Comm.stats.events = Comm.stats.events + 1
    if prefix ~= PREFIX then return false end

    Comm.stats.ours = Comm.stats.ours + 1
    Comm.stats.lastFrom = tostring(sender)
    Comm.stats.lastChannel = tostring(channel)

    Comm:Receive(text, sender, channel)
    return true
end

-- Everything the client has answered this session, most frequent first and by name after
-- that, so that two runs of the same session print the same line.
function Comm:Answers()
    local keys = {}
    for key in pairs(Comm.stats.answers) do keys[#keys + 1] = key end
    if #keys == 0 then return nil end

    table.sort(keys, function(a, b)
        local left, right = Comm.stats.answers[a], Comm.stats.answers[b]
        if left ~= right then return left > right end
        return a < b
    end)

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = string.format("%d x %s", Comm.stats.answers[key], key)
    end
    return table.concat(parts, ", ")
end

function Comm:Prefix() return PREFIX end

Family:OnDatabaseReady("comm", function()
    local api = _G.C_ChatInfo
    local registered = false

    if api and api.RegisterAddonMessagePrefix then
        registered = Family:TryCall(api.RegisterAddonMessagePrefix, PREFIX) and true or false
    elseif _G.RegisterAddonMessagePrefix then
        registered = Family:TryCall(_G.RegisterAddonMessagePrefix, PREFIX) and true or false
    end

    -- A prefix that was never registered receives nothing, silently, for ever. Worth
    -- knowing about rather than discovering as "the other person never replies".
    Comm.registered = registered
    if not registered then
        Family:Debug("comm: the addon prefix would not register - nothing will arrive")
    end

    -- The leading argument is the event's own name, not the first of its values.
    --
    -- Core.lua's dispatcher calls every handler as handler(event, ...), which is why every
    -- other one in Family opens with an underscore. This one did not, so `prefix` held
    -- "CHAT_MSG_ADDON", the test below it compared that against "Family", and every addon
    -- message Family has ever been sent was dropped on the first line of the handler.
    --
    -- Nothing that crosses the wire has ever worked: not a Wide Family link request, not a
    -- guild announcement, in either direction, on any client. Both features looked like they
    -- had faults of their own - a guild that read "0 running Family", link requests that were
    -- never answered - and both were this.
    --
    -- It survived five hundred checks because every one of them called Comm:Receive directly.
    -- The transport was covered in detail and the single line joining it to the game was not,
    -- which is the shape of gap worth looking for elsewhere: the seam between our code and the
    -- client is exactly where a harness stops being able to help.
    Family:RegisterEvent("CHAT_MSG_ADDON", "comm", function(_, prefix, text, channel, sender)
        Comm:Heard(prefix, text, channel, sender)
    end)

    Family:RegisterEvent("PLAYER_REGEN_ENABLED", "comm", function()
        -- The fight is over and the bulk that was waiting for it can go.
        pump()
    end)
end)
