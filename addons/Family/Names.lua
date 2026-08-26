-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Ids in, names out.
--
-- Family stores ids and never names (§2.1), so this is the layer that makes that liveable.
-- It exists because the decision it serves is not free: the client answers about an item
-- only once it has loaded that item, so a bag belonging to a member you have not played
-- this session can hand back nothing at all.
--
-- The contract is deliberately not "return the name". It is:
--
--   * return the name if the client knows it,
--   * otherwise return a legible placeholder, ask the client, and tell the caller later.
--
-- Showing "Item #12345" for a moment is the honest state of affairs. Showing nothing, or
-- blocking until an answer arrives, are both worse.

local _, Family = ...

local Names = {}
Family.Names = Names

local cache = {}      -- itemID -> name, for this session only. Never written to disk.
local waiting = {}    -- itemID -> { [key] = callback }

local function getItemName(id)
	if C_Item and C_Item.GetItemInfo then
		return (C_Item.GetItemInfo(id))
	end
	return (GetItemInfo(id))
end

local function requestItem(id)
	if C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(id)
	else
		-- On clients without the explicit request, asking is what triggers the load.
		getItemName(id)
	end
end

-- The placeholder. Deliberately not "Unknown": the id is a fact, and it is enough to look
-- the thing up, which "Unknown" is not.
function Names:Placeholder(id)
	return "|cff9d9d9dItem #" .. tostring(id) .. "|r"
end

-- Returns name, known. When known is false the name is a placeholder and the callback, if
-- given, fires once the real one arrives.
--
-- The key exists so a panel that redraws can replace its own pending callback rather than
-- accumulating one per redraw - forty rows redrawn ten times should leave forty callbacks.
function Names:Item(id, key, callback)
	if not id then return "", false end

	local name = cache[id] or getItemName(id)
	if name then
		cache[id] = name
		return name, true
	end

	if callback then
		waiting[id] = waiting[id] or {}
		waiting[id][key or "anonymous"] = callback
	end
	requestItem(id)

	return self:Placeholder(id), false
end

-- Spells are easier than items in the one way that matters: the client answers about any
-- spell id straight away, for any class, without having to load anything first. That is why
-- the spellbook can be stored as ids alone with no cached names beside them (§2.1).
function Names:Spell(id)
	if not id then return nil end

	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(id)
		if type(info) == "table" then return info.name, info.iconID end
		if type(info) == "string" then return info end
	end

	local name, _, icon = GetSpellInfo(id)
	return name, icon
end

-- For callers that only want to know, and will look again themselves.
function Names:CachedItem(id)
	if not id then return nil end
	local name = cache[id] or getItemName(id)
	if name then cache[id] = name end
	return name
end

Family:RegisterEvent("GET_ITEM_INFO_RECEIVED", "names", function(_, id, success)
	if not id then return end

	if success == false then
		-- The client is telling us this id has no item. Stop asking, and let anyone
		-- waiting know so they can settle on the placeholder for good.
		waiting[id] = nil
		return
	end

	local name = getItemName(id)
	if not name then return end
	cache[id] = name

	local callbacks = waiting[id]
	if not callbacks then return end
	waiting[id] = nil

	for _, callback in pairs(callbacks) do
		local ok, err = pcall(callback, id, name)
		if not ok then
			Family:Debug("name callback for %d failed: %s", id, tostring(err))
		end
	end
end)
