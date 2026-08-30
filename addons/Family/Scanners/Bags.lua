-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Bags and money: the first thing Family records, and the slice that proves the rest.
--
-- Bags are the one thing that can be kept genuinely current (§9): the game announces every
-- change, so unlike the bank or a profession there is no "as of when you last looked" to
-- apologise for. That is why they are first.

local _, Family = ...

local Bags = {}
Family.Bags = Bags

local BACKPACK = 0

-- The keyring is a container like any other and is numbered below the backpack. It is not
-- carrying space and is never counted as any: a key is not a thing you could have carried
-- something else instead of. Scanned all the same, so that a key answers "who has this one"
-- the way every other item does.
local KEYRING = _G.KEYRING_CONTAINER or -2

--------------------------------------------------------------------------------------------
-- Client differences, in one place
--
-- C_Container arrived partway through these clients' lives and the loose globals still exist
-- on some. Asking once, here, keeps the rest of the file readable and means a third client
-- costs one shim rather than a branch in every loop.
--------------------------------------------------------------------------------------------

local container = C_Container or {}

local GetNumSlots = container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetNumFreeSlots = container.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
local GetItemInfo = container.GetContainerItemInfo or _G.GetContainerItemInfo
local ToInventoryId = container.ContainerIDToInventoryID or _G.ContainerIDToInventoryID
local GetCooldown = container.GetContainerItemCooldown or _G.GetContainerItemCooldown
local GetLink = container.GetContainerItemLink or _G.GetContainerItemLink

local lastBagSlot = _G.NUM_BAG_SLOTS or 4

-- A world buff banked in a Chronoboon Displacer.
--
-- **A charged one is a different item from an empty one**: 184937 is the Displacer and 184938
-- the Supercharged Displacer holding buffs. Measured from `ItemSparse` on all three builds
-- (DATASOURCES §3), where that pair is identical everywhere - so this needs no branch, and a
-- bag holding 184938 means the same thing wherever it is found.
--
-- By id, which is the whole of what §2.1 asks of it. What is *inside* one is per-instance
-- tooltip text and a different question: this records that a character has one banked, not
-- which buffs are in it.
--
-- Bags only. A boon in the bank is not recorded here, and the bank is scanned by another file
-- against a window that is usually shut - a fact that would be present for one character and
-- absent for the next is worse than one that is honestly about bags.
local BOON_STORED = 184938

-- GetContainerItemInfo returns a table on newer clients and a list on older ones. The item id
-- and the stack size are nearly always the whole of it - everything else about an item is the
-- client's to answer later, by id (§2.1).
--
-- The exception is the third return, and it is not a small one in Classic: a random-enchantment
-- item is one id wearing one of dozens of suffixes, and the suffix is where its stats live.
-- Family:ItemString answers with the item string for those and with nothing for the ordinary
-- case, so a bag of cloth costs exactly what it always did.
local function slotContents(bag, slot)
	if not GetItemInfo then return nil end

	local info, count = GetItemInfo(bag, slot)

	local worth
	if GetLink then
		worth = Family:ItemString(Family:TryCall(GetLink, bag, slot))
	end

	if type(info) == "table" then
		return info.itemID, info.stackCount or 1, worth
	end

	-- Older signature: texture, count, locked, quality, readable, lootable, link, filtered,
	-- noValue, itemID. The first return is a texture, so only the count and the id matter.
	if info == nil then return nil end
	local itemID = select(10, GetItemInfo(bag, slot))
	if itemID then
		return itemID, count or 1, worth
	end
	return nil
end

--------------------------------------------------------------------------------------------
-- The scan
--------------------------------------------------------------------------------------------

-- A bag whose type is anything but zero is restricted to one kind of thing - a quiver, a
-- soul bag, a profession bag. §3: its slots are recorded and shown, and never counted as
-- room to carry things, because a full quiver is not sixteen slots of space.
local function bagIsSpecial(bagType)
	return (bagType or 0) ~= 0
end

-- When a thing in a bag will be usable again, as a moment rather than as a countdown - the
-- same reason mail expiry is stored that way: a countdown read tomorrow is a lie and a moment
-- is not.
--
-- Long cooldowns only, and "long" means the better part of a day.
--
-- The things worth an alt manager's attention are the ones a character can do once a day and
-- therefore forgets: a transmute, a bolt of mooncloth, a salt shaker. The floor was a minute,
-- which was set against potions and healthstones and let in everything else - and what it let
-- in first was the **hearthstone**, whose half-hour cooldown got a member announced at login
-- as having something ready. Nobody has ever needed telling that.
--
-- Six hours: comfortably above a hearthstone, a trinket and a mana stone, comfortably below
-- anything on a daily. There is no profession item under a day, so nothing worth reporting
-- falls through it.
local SIX_HOURS = 6 * 60 * 60

local function itemReadyAt(bag, slot)
	local start, duration = Family:TryCall(GetCooldown, bag, slot)
	if not start or start == 0 then return nil end
	if not duration or duration < SIX_HOURS then return nil end

	local now = Family:TryCall(GetTime) or 0
	local remaining = (start + duration) - now
	if remaining <= 0 then return nil end

	return time() + remaining
end

function Bags:Scan()
	local key = Family:CurrentMember()

	local cooldowns = {}
	local boons = 0
	local bags = {}
	local generalSlots, generalFree = 0, 0
	local specialSlots, specialFree = 0, 0

	-- The keyring first, so it keeps its own number rather than being folded in with the
	-- carried bags. Only on the clients that have one (§2.3).
	local order = {}
	if Family.Capabilities:Has("keyring") then order[#order + 1] = KEYRING end
	for bag = BACKPACK, lastBagSlot do order[#order + 1] = bag end

	for _, bag in ipairs(order) do
		local size = GetNumSlots and GetNumSlots(bag) or 0

		if size and size > 0 then
			local free, bagType = 0, 0
			if GetNumFreeSlots then
				free, bagType = GetNumFreeSlots(bag)
				free = free or 0
			end

			local special = bagIsSpecial(bagType)

			-- The backpack is never a special bag whatever a client reports for it.
			if bag == BACKPACK then special = false end

			-- The keyring is special by definition: its slots hold keys and nothing
			-- else, so counting them as room to carry things would be a lie of exactly
			-- the kind §3 is about.
			if bag == KEYRING then special = true end

			local entry = {
				size = size,
				free = free,
				bagType = bagType or 0,
				special = special,
				slots = {},
			}

			-- Which bag this is, as an id. The name, icon and tooltip all come from the
			-- client at display time.
			--
			-- Only for a bag that is really an item somebody bought and put in a bag slot.
			-- The backpack is not one, and neither is the keyring: its container number is
			-- negative, ContainerIDToInventoryID turns it into an equipment slot all the
			-- same, and the client duly answers with whatever is worn there - which is how
			-- the keyring came to be drawn as a helm. A call answering is not a call
			-- agreeing that the question made sense.
			if bag > BACKPACK and ToInventoryId then
				entry.itemID = GetInventoryItemID("player", ToInventoryId(bag))
			end

			for slot = 1, size do
				local itemID, count, worth = slotContents(bag, slot)
				if itemID then
					entry.slots[slot] = { id = itemID, count = count, item = worth }

					-- How many charges are left, for the few items that have any.
					--
					-- Gated on the generated table, so a bag of cloth costs one lookup a
					-- slot and no tooltip: no container call answers this, and reading a
					-- tooltip eighty times a scan to learn nothing is the reason the gate
					-- exists rather than a bare attempt on every slot (DATASOURCES §3).
					if Family.ChargedItems and Family.ChargedItems[itemID] then
					-- **The tooltip is empty until the client has the item**, and at login
					-- it has not: a scan that runs first reads no charges, records nil, and
					-- nothing ever asks again - measured live, where an oil showed no count
					-- until it was moved between slots.
					--
					-- So the id is asked for the way everything else in Family asks for one,
					-- and the scan runs again when the client answers. Family:After replaces
					-- a pending timer of the same name, so a bagful of unknown items costs
					-- one more scan rather than one each.
						local _, known = Family.Names:Item(itemID, "bags.charges",
							function()
								Family:After(0.5, "bags", function() Bags:Scan() end)
							end)

						if known then
							entry.slots[slot].charges = Family:ChargesIn(bag, slot)
						end
					end

					-- Things with a cooldown of their own - a salt shaker, a hearth,
					-- an alchemy stone. Kept beside the crafting cooldowns because the
					-- question is the same one: what of mine is ready.
					local readyAt = itemReadyAt(bag, slot)
					if readyAt then
						cooldowns[#cooldowns + 1] = { id = itemID, readyAt = readyAt }
					end

					if itemID == BOON_STORED then boons = boons + (count or 1) end
				end
			end

			bags[bag] = entry

			if special then
				specialSlots = specialSlots + size
				specialFree = specialFree + free
			else
				generalSlots = generalSlots + size
				generalFree = generalFree + free
			end
		end
	end

	-- Meta is what the summary reads for every member at once, so it holds totals and
	-- nothing that grows with what is in the bags (Database.lua).
	Family.Database:SetMeta(key, {
		name        = UnitName("player"),
		realm       = GetRealmName(),
		level       = UnitLevel("player"),
		classFile   = select(2, UnitClass("player")),
		-- The token to key on, the word to show, and the language that word is in.
		-- Races.lua turns the token back into a word for whoever is reading, so the word
		-- itself is no longer the only answer - but it is still the best one for a reader
		-- running this same language, and it is only that if we say which language it is.
		race        = UnitRace("player"),
		raceFile    = select(2, UnitRace("player")),
		raceLocale  = Family.locale,
		faction     = UnitFactionGroup("player"),
		money       = GetMoney(),
		-- Bags are the one thing that is genuinely live, but "live" still means "as of the
		-- last time this member was played". Recorded so a summary can say which member
		-- the bag figures are a week old for.
		bagsSeen    = time(),
		itemCooldowns = next(cooldowns) and cooldowns or Family.CLEAR,
		-- A count rather than a flag: a character can carry more than one, and "two banked"
		-- is a different answer from "one" to somebody deciding who to log in.
		boons       = boons > 0 and boons or Family.CLEAR,
		-- And what is inside one, which is the aura's tooltip and not the item's - a list of
		-- `{ icon, minutes }`, an identifier and a number, no name among them (§2.1).
		--
		-- Read here rather than in a scanner of its own because it is the same fact from the
		-- same moment: the boon in the bag and the buffs inside it go to disk together, so a
		-- panel can never show contents for a boon this character no longer carries. Only
		-- ever readable for whoever is logged in, which is true of every other bag fact too.
		banked      = Family:BankedBuffs() or Family.CLEAR,
		bagSlots    = generalSlots,
		bagFree     = generalFree,
		specialSlots = specialSlots,
		specialFree = specialFree,
	})

	-- Payload is everything that grows: one entry per occupied slot.
	local payload = Family.Database:Payload(key) or {}
	payload.bags = bags
	Family.Database:SetPayload(key, payload)

	Family:Debug("scanned bags: %d/%d free, %d special slots", generalFree, generalSlots,
		specialSlots)
end

--------------------------------------------------------------------------------------------
-- When to scan
--
-- Coalesced, because BAG_UPDATE_DELAYED can still arrive several times in a row when a
-- stack is split or a vendor is emptied, and a scan walks every slot.
--------------------------------------------------------------------------------------------

local function scanSoon(reason)
	Family:After(0.5, "bags", function()
		Family:Debug("bag scan (%s)", reason)
		Bags:Scan()
	end)
end

Family:OnDatabaseReady("bags", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "bags", function()
		-- §9: bags are rescanned shortly after every login. Shortly, rather than
		-- immediately, because the client has not necessarily filled them in yet.
		Family:After(3, "bags", function() Bags:Scan() end)
	end)

	Family:RegisterEvent("BAG_UPDATE_DELAYED", "bags", function()
		scanSoon("bag update")
	end)

	Family:RegisterEvent("PLAYER_MONEY", "bags", function()
		-- Money alone: no need to walk every slot for a vendor sale.
		Family.Database:SetMeta(Family:CurrentMember(), { money = GetMoney() })
	end)

	Family:RegisterEvent("PLAYER_LEVEL_UP", "bags", function(_, level)
		Family.Database:SetMeta(Family:CurrentMember(), { level = level or UnitLevel("player") })
	end)
end)
