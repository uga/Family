-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Wide Family: two players' families, linked, each seeing exactly what the other chose.
--
-- The specification (§6) puts one principle above everything else here, and every decision
-- below follows from it: **nothing is ever visible that was not deliberately made visible,
-- one member and one category at a time.** So:
--
--   Until a link is accepted, nothing whatever has been exchanged - not a member list, not a
--   name, not the fact that a link was wanted by anybody but the one who asked.
--   A link starts with nothing granted. There is no "share everything" default, because a
--   default is not a decision.
--   Every outgoing payload is built from the grants at the moment of sending, and never from
--   what was sent last time. A grant taken away is a grant taken away, immediately.
--
-- A link is between two *families*, not two characters, so each installation has an id of its
-- own that survives switching members. Characters are only how a family is reached: whichever
-- of theirs we have most recently heard from is the one whispered.
--
-- **What is enforceable and what is not.** Family will not send what was not granted, and on
-- revoking a grant it tells the other side to forget what it has. That last part is a
-- request. The other side is somebody else's computer running somebody else's copy, and no
-- addon can compel it. The consent grid is a promise between two people that Family keeps
-- honestly on this side; it is not a lock, and the interface says so rather than implying a
-- guarantee it cannot make.

local _, Family = ...

local Wide = {}
Family.Wide = Wide

-- What may be granted, and what each one actually carries. The categories are the
-- specification's (§6) and the mapping is here so that adding a scanner cannot quietly widen
-- what a link already agreed to: a new payload key shares nothing until it is named below.
local CATEGORIES = {
    { id = "possessions", label = "Possessions", payload = { "bags", "bank" },
      meta = { "bagSlots", "bagFree", "bankSlots", "bankFree", "bagsSeen", "bankSeen" } },
    -- Its own category rather than part of possessions, and the specification says why (§6):
    -- what somebody is wearing is the thing most often worth showing a friend and the thing
    -- least like a list of what they own. Plenty of people will share one and not the other,
    -- and a category they cannot separate is a decision they cannot make.
    { id = "equipment",   label = "Equipment",   payload = { "equipment" },
      meta = { "itemLevel" } },
    { id = "professions", label = "Professions", payload = { "professions" },
      meta = { "skills" } },
    { id = "talents",     label = "Talents",     payload = { "talents", "spells" } },
    { id = "quests",      label = "Quests",      payload = { "quests" },
      meta = { "questCount" } },
    { id = "mail",        label = "Mail",        payload = { "mail" },
      meta = { "mailCount", "mailSeen", "mailExpires" } },
    { id = "auctions",    label = "Auctions",    payload = { "auctions" },
      meta = { "auctionSeen" } },
    { id = "reputations", label = "Reputations", payload = { "reputations" },
      meta = { "reputationCount" } },
    { id = "money",       label = "Money",       meta = { "money" } },
}

Wide.CATEGORIES = CATEGORIES

-- Offering a member at all means agreeing to this much: who they are. Without it the other
-- side has a row it cannot label, which is not sharing, it is noise. Nothing here is a
-- possession, a location or an activity - it is the name on the door.
local IDENTITY = { "name", "realm", "classFile", "race", "raceFile", "level", "faction" }

--------------------------------------------------------------------------------------------
-- Where all of this lives
--------------------------------------------------------------------------------------------

local function store()
    FamilyDB.wide = FamilyDB.wide or {}
    local wide = FamilyDB.wide

    wide.links = wide.links or {}
    wide.requests = wide.requests or {}
    wide.pendingOut = wide.pendingOut or {}

    -- This installation's own id, made once and kept. Random rather than derived from a
    -- character name: a family is not any one of its members, and a player who deletes the
    -- character they happened to link on has not stopped being the same family.
    if not wide.id then
        wide.id = string.format("%x-%x", math.floor(time()), math.random(0, 0xffffff))
    end

    if wide.auto == nil then wide.auto = true end

    return wide
end

function Wide:Store() return store() end
function Wide:ID() return store().id end
function Wide:Links() return store().links end
function Wide:Requests() return store().requests end

-- Whether Wide Family runs at all.
--
-- Off unless somebody turns it on, and off means genuinely inert: nothing is sent, nothing
-- that arrives is acted on, and the panel is not there. Everything else in Family has been
-- played with for months; this has been exercised by a harness, and a harness is this code
-- talking to itself. No part of it has crossed a real server.
--
-- The reason it waits rather than shipping with a warning label: consent is the one thing
-- here that cannot be repaired afterwards. A wrong tooltip is corrected in the next version,
-- but a member shared with somebody who was never granted them has already been shared by the
-- time anyone notices, and no later version takes that back. A feature whose whole purpose is
-- to hold a line gets to prove it holds before it is handed out.
--
-- Turned on with /family wide on, by the people testing it, until a live client has shown it
-- does what the harness says it does.
function Wide:Enabled() return store().enabled == true end

function Wide:SetEnabled(on)
    store().enabled = on and true or false
    return store().enabled
end

-- How long an unanswered request stands before it is worth saying so. Long enough that
-- somebody reading their mail has not been declared unreachable, short enough that a player
-- testing whether they can reach another realm gets an answer while they still care.
local UNANSWERED_AFTER = 120

-- Whom we have asked and not heard back from. The addon channel gives no delivery
-- acknowledgement of any kind (§11.1): a whisper to a name that cannot be reached from this
-- realm succeeds locally and is dropped by the server without a word. So silence is all there
-- is to go on, and the honest thing is to show the silence rather than to leave the panel
-- looking as though nothing was ever asked.
function Wide:Outgoing()
    local out, now = {}, time()
    for name, entry in pairs(store().pendingOut) do
        out[#out + 1] = {
            name = name,
            at = entry.at,
            waited = now - (entry.at or now),
            unanswered = (now - (entry.at or now)) >= UNANSWERED_AFTER,
        }
    end
    table.sort(out, function(a, b) return (a.at or 0) > (b.at or 0) end)
    return out
end

-- Giving up on one. Nothing is sent: there is nobody known to be listening, which is the
-- whole reason for giving up.
function Wide:Forget(characterName)
    local wide = store()
    if not wide.pendingOut[characterName] then return false, "not waiting on that name" end
    wide.pendingOut[characterName] = nil
    Family.Database:Changed("wide")
    return true
end

-- Whether Family begins an exchange on its own: announcing itself on login, and answering
-- somebody else's announcement while you play. Both halves, one switch (§6).
--
-- Off does not mean the feature is off. *Update now* stays, and stays whatever this says,
-- because on demand is the floor the whole of §6 stands on rather than a convenience on top
-- of it. What this governs is whether anything happens without a person asking for it.
--
-- One thing is deliberately not governed by it: withdrawing a grant is still sent at once
-- (see Grant, below). Automatic update is a convenience and it is yours to switch off;
-- telling somebody to forget what they may no longer see is a promise, and it is the other
-- player's.
function Wide:AutoUpdate() return store().auto ~= false end

function Wide:SetAutoUpdate(on)
    store().auto = on and true or false
end

--------------------------------------------------------------------------------------------
-- Siblings
--
-- Among the members a linked family has already granted us, the ones worth seeing beside our
-- own (§6). A sibling appears in the summary, under their own family, inside the realm they
-- are on.
--
-- **This sends nothing and asks nobody, and that is not a shortcut.** A sibling is chosen
-- from members that family has already decided to share, so the consent that matters was
-- given before the name could appear in the list at all. There is nothing left to agree to;
-- what is left is a decision about our own screen. Everywhere else in this file the answer is
-- "both sides must agree", so the one place where the question is already answered is worth
-- saying out loud rather than leaving as a silence.
--------------------------------------------------------------------------------------------

-- One name for a borrowed member that cannot collide with one of ours or with another
-- family's. Two linked families can both have an Alberta-Firemaw, and so can we.
function Wide:BorrowedKey(familyID, memberKey)
    return "@" .. tostring(familyID) .. "/" .. tostring(memberKey)
end

function Wide:SplitBorrowedKey(key)
    if type(key) ~= "string" then return nil end
    return key:match("^@([^/]+)/(.+)$")
end

-- A borrowed member by that key: their meta, their payload, and whose they are. This is how a
-- panel reads a sibling without knowing that borrowed data is stored anywhere different.
function Wide:Borrowed(key)
    local familyID, memberKey = self:SplitBorrowedKey(key)
    if not familyID then return nil end

    local link = self:Links()[familyID]
    if not link then return nil end

    local entry = (link.members or {})[memberKey]
    if not entry then return nil end

    return entry, link, familyID, memberKey
end

function Wide:IsSibling(familyID, memberKey)
    local link = self:Links()[familyID]
    if not link then return false end
    return ((link.siblings or {})[memberKey]) and true or false
end

function Wide:SetSibling(familyID, memberKey, on)
    local link = self:Links()[familyID]
    if not link then return false end

    -- Only for somebody they actually share. Marking a member we have never been given
    -- would leave a flag waiting to take effect the moment they granted them, which is a
    -- decision taken before the thing it is about exists.
    if on and not (link.members or {})[memberKey] then return false end

    link.siblings = link.siblings or {}
    link.siblings[memberKey] = on and true or nil

    Family.Database:Changed("wide")
    return true
end

-- Every sibling, in the shape the panels want: keyed, labelled with whose they are, and
-- carrying the age of the record like everything else borrowed.
function Wide:Siblings()
    if not self:Enabled() then return {} end

    local list = {}

    for familyID, link in pairs(self:Links()) do
        for memberKey in pairs(link.siblings or {}) do
            local entry = (link.members or {})[memberKey]
            if entry then
                list[#list + 1] = {
                    key = self:BorrowedKey(familyID, memberKey),
                    memberKey = memberKey,
                    meta = entry.meta or {},
                    payload = entry.payload,
                    seen = entry.seen,
                    family = familyID,
                    familyName = link.name,
                    exchanged = link.lastExchange,
                    sibling = true,
                }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.familyName ~= b.familyName then
            return tostring(a.familyName) < tostring(b.familyName)
        end
        return tostring(a.meta.name) < tostring(b.meta.name)
    end)

    return list
end

--------------------------------------------------------------------------------------------
-- Talking
--------------------------------------------------------------------------------------------

local SCHEMA = 1

-- Where to whisper. A family is reached through whichever of its characters was heard from
-- most recently, because that is the only one there is any reason to think is online.
-- Which of their characters to whisper.
--
-- A family is a person, and the person is playing one character at a time - never necessarily
-- the one we heard from last. So the most recently heard from is tried first, and any the
-- client has just told us is not there is skipped, and the next is tried instead. A link is
-- to the family, not to whichever of them happened to be logged in when it was made.
--
-- Nothing left to try is a real answer and it is answered plainly: none of them is online.
-- That is different from "we have never heard from any of them", which is the other way this
-- can come back empty, and the two are told apart because they need different things done
-- about them.
local function reachableName(link)
    local names = {}
    for name, at in pairs(link.characters or {}) do
        names[#names + 1] = { name = name, at = at or 0 }
    end
    table.sort(names, function(a, b) return a.at > b.at end)

    -- The name the link was made under, last, and only if we have nothing better. It is a
    -- character name too, but it is the oldest thing we know.
    if link.name then names[#names + 1] = { name = link.name, at = 0 } end

    local anyKnown = false
    for _, entry in ipairs(names) do
        anyKnown = true
        if not Family.Comm:Absent(entry.name) then return entry.name end
    end

    return nil, anyKnown
end

-- Everyone of theirs worth trying, so a caller can say how many were tried rather than
-- guessing at the shape of the family.
local function characterCount(link)
    local seen, count = {}, 0
    for name in pairs(link.characters or {}) do seen[name] = true end
    if link.name then seen[link.name] = true end
    for _ in pairs(seen) do count = count + 1 end
    return count
end

local function send(link, kind, table_, bulk)
    -- Not to anybody the client has just told us is not there. Only what was learned the
    -- hard way, a moment ago, and only for a minute: there is no way to ask whether a name is
    -- online, so the one thing worth acting on is the answer the server already gave.
    local target, anyKnown = reachableName(link)

    if not target then
        if anyKnown then
            local count = characterCount(link)
            return false, string.format("none of %s's %d character%s is online",
                tostring(link.name), count, count == 1 and "" or "s")
        end
        return false, "nobody of theirs has ever been heard from"
    end

    local body, why = Family.Codec:ToWire(table_)
    if not body then return false, why end

    -- Every payload says which family it came from and which schema wrote it. The second is
    -- §6's requirement rather than a nicety: two versions that disagree must say so by name
    -- rather than quietly misreading each other's tables.
    return Family.Comm:Send(kind, body, "WHISPER", target, bulk)
end

local function envelope(extra)
    local body = {
        family = store().id,
        schema = SCHEMA,
        version = Family.version,
        character = Family:CurrentMember(),
    }
    for key, value in pairs(extra or {}) do body[key] = value end
    return body
end

--------------------------------------------------------------------------------------------
-- What we are willing to send
--------------------------------------------------------------------------------------------

local function grantsFor(link, memberKey)
    return (link.grants or {})[memberKey]
end

-- One member, cut down to exactly what was granted. Built now, from the grants as they stand
-- now - never from what was sent last time, which is how a revoked grant would go on being
-- honoured by a payload nobody rebuilt.
local function offering(link, memberKey)
    local granted = grantsFor(link, memberKey)
    if not granted or not next(granted) then return nil end

    local meta = Family.Database:Meta(memberKey)
    if not meta then return nil end

    local out = { meta = {}, payload = {} }

    for _, field in ipairs(IDENTITY) do out.meta[field] = meta[field] end

    local payload
    for _, category in ipairs(CATEGORIES) do
        if granted[category.id] then
            for _, field in ipairs(category.meta or {}) do
                out.meta[field] = meta[field]
            end

            if category.payload then
                payload = payload or Family.Database:Payload(memberKey) or {}
                for _, key in ipairs(category.payload) do
                    out.payload[key] = payload[key]
                end
            end
        end
    end

    if not next(out.payload) then out.payload = nil end

    -- What was granted, said outright rather than left to be worked out from what arrived.
    --
    -- The other side can nearly infer it - a category is present if any of its keys came
    -- through - but nearly is the problem: a member with no auctions and a member whose
    -- auctions were not shared send exactly the same nothing, and telling somebody "they are
    -- not sharing their auctions" when they are sharing an empty auction house is a fact
    -- invented out of an absence (2.2). A few short strings settle it.
    out.granted = {}
    for _, category in ipairs(CATEGORIES) do
        if granted[category.id] then
            out.granted[#out.granted + 1] = category.id
        end
    end

    -- Stamped with when this side last looked, not with when it was sent. The other end
    -- shows the age of the fact, and a fact does not get younger by being posted.
    out.seen = meta.seen or time()

    return out
end

function Wide:Offering(link)
    local members = {}
    local count = 0

    for memberKey in pairs(link.grants or {}) do
        local entry = offering(link, memberKey)
        if entry then
            members[memberKey] = entry
            count = count + 1
        end
    end

    return members, count
end

--------------------------------------------------------------------------------------------
-- The exchange
--------------------------------------------------------------------------------------------

-- An exchange is two halves that do not depend on each other: what we send is decided by our
-- grants, what we receive is decided by theirs. Asking is therefore also offering, and one
-- round trip carries both directions - §6 asks for exactly that.
function Wide:ExchangeWith(familyID, why)
    if not self:Enabled() then return false, "Wide Family is not switched on" end

    local link = self:Links()[familyID]
    if not link then return false, "no such link" end

    local members, count = self:Offering(link)

    local ok, problem = send(link, "data", envelope({
        members = members,
        -- Which members we are *not* offering matters as much as which we are: it is how
        -- the other side knows to forget one that was withdrawn, rather than keeping a
        -- stale copy for ever because nothing arrived to replace it.
        offering = self:GrantedKeys(link),
    }), true)

    if not ok then return false, problem end

    send(link, "want", envelope({}))

    link.lastAsked = time()
    Family:Debug("wide: exchanged with %s (%d members offered, %s)",
        tostring(link.name), count, tostring(why or "on request"))

    return true, count
end

-- One of their characters turned out to be offline, mid-exchange.
--
-- A family is a person, and a person is playing one character. The one we whispered is very
-- often not that one - it is whichever we heard from last, which may have been a week ago -
-- so being told they are not there is not the end of the question, it is the elimination of
-- one candidate. Try the next.
--
-- This terminates on its own: every attempt marks one more name absent, so the list
-- reachableName can offer shrinks by one each time and runs out.
Family.Comm:OnAbsent("wide", function(name)
    local store_ = store()
    if not (store_.enabled and store_.links) then return false end

    local handled = false

    for familyID, link in pairs(store_.links) do
        -- By character rather than by string. The client complains about "Grella" and every
        -- name we hold carries a realm, so == answers false for the one link this is about.
        local ours = Family.Comm:SameName(link.name, name)
        for character in pairs(link.characters or {}) do
            if Family.Comm:SameName(character, name) then ours = true end
        end

        if ours then
            handled = true
            local nextName, anyKnown = reachableName(link)

            if nextName then
                Family:Print("|cff888888%s is not online - trying %s.|r", name, nextName)
                Wide:ExchangeWith(familyID, "the last one was offline")
            elseif anyKnown then
                local count = characterCount(link)
                Family:Print("|cffffaa00None of %s's %d character%s is online.|r Nothing "
                    .. "was sent. Try again when one of them is.",
                    tostring(link.name), count, count == 1 and "" or "s")
            end
        end
    end

    return handled
end)

function Wide:GrantedKeys(link)
    local keys = {}
    for memberKey, granted in pairs(link.grants or {}) do
        if next(granted) then keys[#keys + 1] = memberKey end
    end
    return keys
end

function Wide:ExchangeAll(why)
    local asked = 0
    for familyID in pairs(self:Links()) do
        if self:ExchangeWith(familyID, why) then asked = asked + 1 end
    end
    return asked
end

--------------------------------------------------------------------------------------------
-- Receiving
--------------------------------------------------------------------------------------------

local function noteHeard(link, sender)
    if type(sender) ~= "string" or sender == "" then return end
    link.characters = link.characters or {}
    -- Sender arrives as "Name-Realm" on some clients and "Name" on others. Kept as it
    -- arrived, because it is going straight back into a whisper.
    link.characters[sender] = time()
end

local function linkOf(body, sender)
    if type(body) ~= "table" or type(body.family) ~= "string" then return nil end
    local link = store().links[body.family]
    if not link then return nil end
    noteHeard(link, sender)
    link.version = body.version or link.version
    return link, body.family
end

-- Somebody wants to link. Nothing happens until a person says yes: the request is written
-- down and the player is told, and no data of any kind moves either way in the meantime.
Family.Comm = Family.Comm or {}

local function onLink(_, text, sender)
    local body = Family.Codec:FromWire(text)
    if type(body) ~= "table" or type(body.family) ~= "string" then return end

    local wide = store()

    -- Already linked: treat it as a hello rather than as a request, because a second link
    -- request from somebody already linked is a client that lost track, not a decision to
    -- be asked about again.
    if wide.links[body.family] then
        noteHeard(wide.links[body.family], sender)
        return
    end

    wide.requests[body.family] = {
        from = sender,
        name = body.character or sender,
        version = body.version,
        at = time(),
    }

    Family:Print("|cffffd700%s|r would like to link families. "
        .. "Open Family, Wide Family, to accept or decline.", tostring(sender))
    Family.Database:Changed("wide")
end

-- A character name with the realm taken off, in lower case.
--
-- A request is addressed to a name that was typed - "Faraway" - and the answer comes back
-- from whatever the server calls that character, which is "Faraway-Some Realm" on some
-- clients and "Faraway" on others. Comparing the two as they stand matches on one client and
-- not on the next, which would mean an acceptance that is silently ignored.
local function bareName(name)
    if type(name) ~= "string" then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

local function onLinked(_, text, sender)
    local body = Family.Codec:FromWire(text)
    if type(body) ~= "table" or type(body.family) ~= "string" then return end

    local wide = store()

    -- Only in answer to something we asked for. An unsolicited "you are linked" is somebody
    -- else deciding for us, which is the one thing this whole file exists to prevent.
    --
    -- Matched by who is answering rather than by their family id, because their family id is
    -- exactly the thing we did not know when we asked - it arrives with this message.
    local pending, asked
    for name, entry in pairs(wide.pendingOut or {}) do
        if bareName(name) == bareName(sender)
            or bareName(name) == bareName(body.character) then
            pending, asked = entry, name
        end
    end

    if not pending and not wide.links[body.family] then
        Family:Debug("wide: acceptance from %s, who was never asked - ignored",
            tostring(sender))
        return
    end

    wide.links[body.family] = wide.links[body.family] or {
        name = body.character or sender,
        grants = {},
        members = {},
        auto = true,
    }
    noteHeard(wide.links[body.family], sender)
    wide.links[body.family].version = body.version

    if asked and wide.pendingOut then wide.pendingOut[asked] = nil end

    Family:Print("Linked with |cffffd700%s|r. Nothing is shared until you say what may be.",
        tostring(sender))
    Family.Database:Changed("wide")
end

local function onUnlink(_, text, sender)
    local body = Family.Codec:FromWire(text)
    local link, familyID = linkOf(body, sender)
    if not link then return end

    store().links[familyID] = nil
    Family:Print("|cffffd700%s|r has ended the link. Their data has been forgotten.",
        tostring(sender))
    Family.Database:Changed("wide")
end

local function onWant(_, text, sender)
    local body = Family.Codec:FromWire(text)
    local link, familyID = linkOf(body, sender)
    if not link then return end

    -- Answered with whatever is granted right now, and with nothing else. A request is not
    -- permission; the grants are.
    local members = select(1, Wide:Offering(link))
    send(link, "data", envelope({ members = members, offering = Wide:GrantedKeys(link) }),
        true)
    Family:Debug("wide: answered a request from %s", tostring(sender))
end

local function onData(_, text, sender)
    local body = Family.Codec:FromWire(text)
    local link, familyID = linkOf(body, sender)
    if not link then return end

    if body.schema ~= SCHEMA then
        -- §6 states this as a requirement rather than leaving it to the implementation,
        -- because getting it wrong corrupts records instead of failing visibly.
        link.problem = string.format("their Family writes schema %s and this one reads %s",
            tostring(body.schema), tostring(SCHEMA))
        Family:Print("|cffffaa00%s's Family speaks a different version - %s|r",
            tostring(sender), link.problem)
        Family.Database:Changed("wide")
        return
    end

    link.problem = nil
    link.members = link.members or {}

    local arrived = 0
    for memberKey, entry in pairs(body.members or {}) do
        if type(entry) == "table" and type(entry.meta) == "table" then
            link.members[memberKey] = entry
            arrived = arrived + 1
        end
    end

    -- Anything they no longer offer is dropped here. A grant taken away on their side has to
    -- become an absence on ours, or "revocable at any time" means only "revocable until the
    -- next time nobody looks".
    if type(body.offering) == "table" then
        local still = {}
        for _, memberKey in ipairs(body.offering) do still[memberKey] = true end

        for memberKey in pairs(link.members) do
            if not still[memberKey] then
                link.members[memberKey] = nil
                -- The sibling goes with the member. A flag pointing at somebody who is no
                -- longer shared would put an empty row in the summary and, worse, would
                -- quietly come back to life if they were ever granted again.
                if link.siblings then link.siblings[memberKey] = nil end
            end
        end
    end

    link.lastExchange = time()
    Family:Debug("wide: %d member(s) arrived from %s", arrived, tostring(sender))
    Family.Database:Changed("wide")
end

-- Somebody linked has come online. Their client says so on login, and this side answers by
-- exchanging - which is the whole of the automatic update: neither end polls, and neither
-- end has to be asked.
local function onHello(_, text, sender)
    local body = Family.Codec:FromWire(text)
    local link, familyID = linkOf(body, sender)
    if not link then return end

    Family.Database:Changed("wide")

    if not Wide:AutoUpdate() or link.auto == false then return end

    -- A moment later, so that two families logging in together do not both send everything
    -- they have into the same instant.
    Family:After(2 + math.random() * 3, "wide.hello." .. familyID, function()
        Wide:ExchangeWith(familyID, "they came online")
    end)
end

--------------------------------------------------------------------------------------------
-- Asking for a link, and answering one
--------------------------------------------------------------------------------------------

function Wide:RequestLink(characterName)
    if not self:Enabled() then return false, "Wide Family is not switched on" end
    if type(characterName) ~= "string" or characterName == "" then
        return false, "a character name is needed"
    end
    if not Family.Codec:CanTalk() then
        return false, "this client has no serialisation libraries, so nothing can be sent"
    end

    local wide = store()

    -- Whom we asked is remembered by name rather than by family id, because we do not know
    -- their family id until they answer. The acceptance carries it.
    --
    -- Asking again simply restarts the clock. There is no harm in a second request - the
    -- other end keeps one entry per family, not one per message - and re-asking is the only
    -- thing a player can usefully do when the first went unanswered.
    wide.pendingOut[characterName] = { at = time() }

    Family.Comm:Send("link", Family.Codec:ToWire(envelope({})) or "", "WHISPER",
        characterName, false)

    return true
end

function Wide:Accept(familyID)
    local wide = store()
    local request = wide.requests[familyID]
    if not request then return false, "no such request" end

    wide.links[familyID] = {
        name = request.name or request.from,
        version = request.version,
        characters = { [request.from] = time() },
        grants = {},
        members = {},
        auto = true,
    }
    wide.requests[familyID] = nil

    -- Accepting shares nothing. It creates somewhere for a decision about sharing to be
    -- made, and the grid starts empty on purpose (§6).
    send(wide.links[familyID], "linked", envelope({}))
    Family.Database:Changed("wide")

    return true
end

function Wide:Decline(familyID)
    local wide = store()
    if not wide.requests[familyID] then return false end
    wide.requests[familyID] = nil
    Family.Database:Changed("wide")
    return true
end

function Wide:Unlink(familyID)
    local wide = store()
    local link = wide.links[familyID]
    if not link then return false end

    send(link, "unlink", envelope({}))
    wide.links[familyID] = nil
    Family.Database:Changed("wide")
    return true
end

--------------------------------------------------------------------------------------------
-- Granting
--------------------------------------------------------------------------------------------

function Wide:Granted(familyID, memberKey, categoryID)
    local link = self:Links()[familyID]
    if not link then return false end
    local granted = (link.grants or {})[memberKey]
    return (granted and granted[categoryID]) and true or false
end

local function setGrant(link, memberKey, categoryID, on)
    link.grants = link.grants or {}
    link.grants[memberKey] = link.grants[memberKey] or {}
    link.grants[memberKey][categoryID] = on and true or nil

    if not next(link.grants[memberKey]) then link.grants[memberKey] = nil end
end

-- Telling them, once, whatever was just decided.
--
-- At once rather than at the next exchange. Taking a grant away is the half of this that has
-- to be prompt: waiting until somebody happens to press Update would mean the other side kept
-- it for as long as nobody did.
--
-- Deliberately not gated on AutoUpdate. That switch is about being left alone by a
-- convenience; this message is the other player's, and a promise that waits for somebody to
-- press a button is not a promise.
local function grantsChanged(self, familyID)
    self:ExchangeWith(familyID, "a grant changed")
    Family.Database:Changed("wide")
end

function Wide:Grant(familyID, memberKey, categoryID, on)
    local link = self:Links()[familyID]
    if not link then return false end

    setGrant(link, memberKey, categoryID, on)
    grantsChanged(self, familyID)

    return true
end

-- The same decision taken about several members at once, and told once.
--
-- Not a loop over Grant, which is the obvious way to write it and would send a whole exchange
-- per member: ticking a column of eleven would be eleven of them, for one decision a player
-- made with one click. The promise that a withdrawal is prompt is kept by the single exchange
-- at the end, which carries the lot.
function Wide:GrantMany(familyID, memberKeys, categoryID, on)
    local link = self:Links()[familyID]
    if not link then return false end

    for _, memberKey in ipairs(memberKeys) do
        setGrant(link, memberKey, categoryID, on)
    end

    grantsChanged(self, familyID)

    return true, #memberKeys
end

-- What a linked family is sharing with us about one of their members, as { [id] = true }.
--
-- Their word for it where they sent one, and what actually arrived where they did not - an
-- older Family says nothing about its grants, and answering nothing at all for those would
-- make the panel look broken rather than look old. Which of the two is being shown is a thing
-- the panel says, because they are not the same claim.
function Wide:Received(entry)
    if type(entry) ~= "table" then return {}, false end

    if type(entry.granted) == "table" then
        local told = {}
        for _, id in ipairs(entry.granted) do told[id] = true end
        return told, true
    end

    local guessed = {}
    local meta, payload = entry.meta or {}, entry.payload or {}

    for _, category in ipairs(CATEGORIES) do
        for _, field in ipairs(category.meta or {}) do
            if meta[field] ~= nil then guessed[category.id] = true end
        end
        for _, key in ipairs(category.payload or {}) do
            if payload[key] ~= nil then guessed[category.id] = true end
        end
    end

    return guessed, false
end

function Wide:CountGranted(familyID)
    local link = self:Links()[familyID]
    if not link then return 0, 0 end

    local members, grants = 0, 0
    for _, granted in pairs(link.grants or {}) do
        local any = false
        for _ in pairs(granted) do grants = grants + 1; any = true end
        if any then members = members + 1 end
    end
    return members, grants
end

--------------------------------------------------------------------------------------------
-- The members another family has shared with us
--------------------------------------------------------------------------------------------

-- Always marked as somebody else's, never merged with our own. §6 is explicit: linked data is
-- stored separately, is never edited, and is as old as the last exchange.
--
-- Nothing borrowed is shown while the feature is off either. The records stay on disk
-- untouched, so switching it back on restores them - but a switched-off feature that still
-- puts other people's characters on your summary is not switched off.
function Wide:BorrowedMembers()
    if not self:Enabled() then return {} end

    local list = {}

    for familyID, link in pairs(self:Links()) do
        for memberKey, entry in pairs(link.members or {}) do
            list[#list + 1] = {
                -- Both: the family's own name for them, which is what the grid was ticked
                -- against, and the name nothing else can collide with, which is what a
                -- panel showing them beside our own members has to use.
                key = memberKey,
                borrowedKey = self:BorrowedKey(familyID, memberKey),
                meta = entry.meta or {},
                payload = entry.payload,
                seen = entry.seen,
                family = familyID,
                familyName = link.name,
                exchanged = link.lastExchange,
                sibling = self:IsSibling(familyID, memberKey),
                -- What they are sharing about this one, so the panel can show it back.
                received = select(1, self:Received(entry)),
                toldUs = select(2, self:Received(entry)),
            }
        end
    end

    table.sort(list, function(a, b)
        if a.familyName ~= b.familyName then
            return tostring(a.familyName) < tostring(b.familyName)
        end
        return tostring(a.meta.name) < tostring(b.meta.name)
    end)

    return list
end

--------------------------------------------------------------------------------------------

-- One gate in front of all six handlers rather than six copies of the same line. A message
-- that arrives for a feature which is switched off is dropped where it lands: not stored, not
-- answered, and not held as a request for somebody to find later.
local function whenEnabled(handler)
    return function(...)
        if not Wide:Enabled() then return end
        return handler(...)
    end
end

Family:OnDatabaseReady("wide", function()
    Family.Comm:On("link", whenEnabled(onLink))
    Family.Comm:On("linked", whenEnabled(onLinked))
    Family.Comm:On("unlink", whenEnabled(onUnlink))
    Family.Comm:On("want", whenEnabled(onWant))
    Family.Comm:On("data", whenEnabled(onData))
    Family.Comm:On("hello", whenEnabled(onHello))

    Family:RegisterEvent("PLAYER_ENTERING_WORLD", "wide", function()
        -- Late, and only once the rest of this session's scanning has settled: what goes out
        -- should be this character as they are now, not as they were when the client
        -- finished loading.
        Family:After(10, "wide.hello", function()
            if not Wide:Enabled() then return end

            -- Announcing ourselves is what makes the other side exchange, so it is half of
            -- the automatic update and not a separate courtesy. Switched off, this side
            -- neither starts an exchange nor causes one - which is what "off" has to mean
            -- for somebody who turned it off to be left alone by it.
            if not Wide:AutoUpdate() then
                Family:Debug("wide: automatic update is off, so no announcement")
                return
            end

            if not Family.Codec:CanTalk() then
                Family:Debug("wide: no serialisation libraries, so no links can be used")
                return
            end

            local wide = store()
            for familyID, link in pairs(wide.links) do
                local body = Family.Codec:ToWire(envelope({}))
                local target = reachableName(link)
                if body and target then
                    Family.Comm:Send("hello", body, "WHISPER", target, false)
                end
            end
        end)
    end)

    -- Abandoning half-arrived transfers, which only matters when nothing else is coming.
    if _G.C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(15, function() Family.Comm:Sweep() end)
    end
end)
