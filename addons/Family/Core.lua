-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The one global, and the event plumbing every other file hangs off.

local ADDON_NAME, Family = ...

_G.Family = Family

Family.version = C_AddOns and C_AddOns.GetAddOnMetadata
	and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
	or (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version"))
	or "0.0.0"

--------------------------------------------------------------------------------------------
-- Talking to the player
--------------------------------------------------------------------------------------------

local PREFIX = "|cff66bbff" .. ADDON_NAME .. "|r: "

function Family:Print(fmt, ...)
	local text = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. text)
end

-- Off by default. Set FamilyDB.debug to see the scanners narrate themselves.
function Family:Debug(fmt, ...)
	if not (FamilyDB and FamilyDB.debug) then return end
	local text = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cff888888" .. text .. "|r")
end

--------------------------------------------------------------------------------------------
-- Events
--
-- One frame for the whole addon. Files register interest by name and are called back with
-- the event's own arguments. A handler that errors is reported once and unregistered, so a
-- broken scanner cannot take the rest of the addon down with it on every bag update.
--------------------------------------------------------------------------------------------

local listeners = {}
local frame = CreateFrame("Frame", "FamilyEventFrame")

function Family:RegisterEvent(event, key, handler)
	if not listeners[event] then
		listeners[event] = {}
		local ok = pcall(frame.RegisterEvent, frame, event)
		if not ok then
			-- An event this client does not have. Nothing to listen to, and nothing wrong.
			listeners[event] = nil
			self:Debug("event %s does not exist on this client", event)
			return false
		end
	end
	listeners[event][key] = handler
	return true
end

function Family:UnregisterEvent(event, key)
	local bucket = listeners[event]
	if not bucket then return end
	bucket[key] = nil
	if not next(bucket) then
		listeners[event] = nil
		frame:UnregisterEvent(event)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	local bucket = listeners[event]
	if not bucket then return end
	for key, handler in pairs(bucket) do
		local ok, err = pcall(handler, event, ...)
		if not ok then
			Family:Print("|cffff5555error in %s handler for %s|r: %s", key, event, tostring(err))
			Family:UnregisterEvent(event, key)
		end
	end
end)

--------------------------------------------------------------------------------------------
-- Calling an API that may not be here
--
-- These clients do not simply omit the calls their version does not support. They ship a
-- function that exists, passes every `if GetNumSpecGroups then` test ever written, and
-- throws when called:
--
--     Script_GetNumSpecGroups: API unsupported in this version of World of Warcraft.
--
-- So the only honest test of an optional API is to call it and see. Existence proves
-- nothing; this is the third distinct way that has been true on these clients, after a
-- symbol without its feature and a feature without its symbol.
--
-- Use this for anything that is not present on all three clients. An unavailable call
-- answers nil, which falls through to the next candidate rather than taking the addon down.
--------------------------------------------------------------------------------------------

function Family:TryCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local results = { pcall(fn, ...) }
	if not results[1] then
		return nil
	end
	return unpack(results, 2)
end

--------------------------------------------------------------------------------------------
-- When an id is not enough
--
-- Family stores ids (§2.1), and for nearly everything an id is the whole truth: the client
-- will describe item 12345 in whatever language it is running in, and two stacks of copper ore
-- are the same copper ore.
--
-- Some items are not like that. A random-enchantment item - the "of the Eagle" family, which
-- is most of what drops in Classic - is one item id wearing one of dozens of suffixes, and the
-- suffix is where its whole stat line lives. An enchant, a gem and a patch are the same story
-- on a worn piece. Ask the client about the id alone and it answers about the generic item and
-- says "<Random enchantment>" where the stats should be, which is a description of nothing
-- anybody owns.
--
-- What carries that is the item string - "item:" and a row of numbers, ids the whole way, so
-- this is no exception to §2.1. The rest of a link is a colour and the item's name in the
-- language of whoever was holding it, and that is exactly the part left behind.
--
-- Kept only when it says something the id cannot. Storing it for every slot would put forty
-- characters against every stack of cloth in forty members' bags to record a suffix of nought,
-- and the split between meta and payload (Database.lua) is not an excuse to be careless inside
-- payload.
--------------------------------------------------------------------------------------------

function Family:ItemString(link)
	if type(link) ~= "string" then return nil end

	local worth = link:match("|H(item[%-%d:]+)|h")
	if not worth and link:match("^item[%-%d:]+$") then worth = link end
	if not worth then return nil end

	-- item : id : enchant : gem1 : gem2 : gem3 : gem4 : suffix : unique : ...
	--
	-- Suffixes are negative on these clients, which is why the pattern above accepts a minus
	-- sign - without it the match stopped at the dash and the string was silently truncated
	-- to something that no longer described the item at all.
	-- Split by hand rather than with gmatch. "[^:]+" drops the empty fields these links
	-- genuinely contain and "[^:]*" yields an empty string between every pair of colons, so
	-- both of them shift every field along and the suffix is read out of the gem slot.
	local parts, from = {}, 1
	while true do
		local at = worth:find(":", from, true)
		if not at then
			parts[#parts + 1] = worth:sub(from)
			break
		end
		parts[#parts + 1] = worth:sub(from, at - 1)
		from = at + 1
	end

	for index = 3, 8 do
		if (tonumber(parts[index]) or 0) ~= 0 then return worth end
	end

	return nil
end

--------------------------------------------------------------------------------------------
-- Deferred work
--
-- Several things are worth doing once, shortly after a burst of events, rather than once per
-- event: bags fire BAG_UPDATE per bag, and a bank visit fires a great many at once.
--------------------------------------------------------------------------------------------

local pending = {}
local ticker = CreateFrame("Frame")

ticker:SetScript("OnUpdate", function(_, elapsed)
	local due
	for key, entry in pairs(pending) do
		entry.remaining = entry.remaining - elapsed
		if entry.remaining <= 0 then
			due = due or {}
			due[key] = entry.fn
		end
	end
	if not due then return end
	for key, fn in pairs(due) do
		pending[key] = nil
		local ok, err = pcall(fn)
		if not ok then
			Family:Print("|cffff5555error in deferred %s|r: %s", key, tostring(err))
		end
	end
	if not next(pending) then ticker:Hide() end
end)

ticker:Hide()

-- Calling this again before it fires restarts the delay rather than queueing a second run.
function Family:After(delay, key, fn)
	pending[key] = { remaining = delay, fn = fn }
	ticker:Show()
end

--------------------------------------------------------------------------------------------
-- Who we are
--
-- Members are keyed "Name-Realm" throughout, with the realm as the client spells it minus
-- spaces, so the key is stable and readable in a saved variables file.
--------------------------------------------------------------------------------------------

function Family:MemberKey(name, realm)
	return name .. "-" .. (realm or ""):gsub("%s+", "")
end

-- Who is being played. Worked out once, because it cannot change without the game being
-- restarted - but only once there is an answer to work it out from.
--
-- Asked early enough, the client answers with no name or an empty realm, and a wrong key
-- cached here would follow the whole session: every panel opens on "the member being played"
-- and none of them would ever find one. Nothing is better than something wrong.
function Family:CurrentMember()
	if not self.currentMember then
		local name = UnitName("player")
		local realm = GetRealmName()

		if type(name) ~= "string" or name == "" then return nil end
		if type(realm) ~= "string" or realm == "" then return nil end

		self.currentMember = self:MemberKey(name, realm)
	end
	return self.currentMember
end

--------------------------------------------------------------------------------------------
-- Startup
--
-- ADDON_LOADED for our own name is the earliest point at which FamilyDB exists. Everything
-- that needs saved data waits for Family:OnDatabaseReady, and everything that needs the
-- world waits for PLAYER_LOGIN.
--------------------------------------------------------------------------------------------

local onReady = {}

function Family:OnDatabaseReady(key, fn)
	if self.databaseReady then
		fn()
	else
		onReady[key] = fn
	end
end

Family:RegisterEvent("ADDON_LOADED", "core", function(_, name)
	if name ~= ADDON_NAME then return end

	Family.Database:Initialise()
	Family.Capabilities:Detect()

	Family.databaseReady = true
	for key, fn in pairs(onReady) do
		local ok, err = pcall(fn)
		if not ok then
			Family:Print("|cffff5555error starting %s|r: %s", key, tostring(err))
		end
	end
	wipe(onReady)

	Family:UnregisterEvent("ADDON_LOADED", "core")
end)
