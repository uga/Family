-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The bank, and the guild bank.
--
-- Bags could be kept current because the game announces every change to them. A bank cannot:
-- it is readable only while its window is open, so what Family holds is a photograph of the
-- last visit and is labelled with the date it was taken (§2.2). "Never visited" and "empty"
-- are different answers and are never allowed to look alike.
--
-- The guild bank is the same, twice over. It is somebody else's window as much as yours, so
-- a tab nobody has opened is unknown rather than empty, and the whole thing only exists at
-- all on a client that has guild banks and for a member actually in a guild.

local _, Family = ...

local Bank = {}
Family.Bank = Bank

local container = C_Container or {}

local GetNumSlots = container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetNumFreeSlots = container.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
local GetItemInfo = container.GetContainerItemInfo or _G.GetContainerItemInfo
local ToInventoryId = container.ContainerIDToInventoryID or _G.ContainerIDToInventoryID
local GetLink = container.GetContainerItemLink or _G.GetContainerItemLink

-- The bank's own window, then the bags bought to go in it.
local BANK = _G.BANK_CONTAINER or -1

local FIRST_BANK_BAG = (_G.NUM_BAG_SLOTS or 4) + 1
local LAST_BANK_BAG = FIRST_BANK_BAG + (_G.NUM_BANKBAGSLOTS or 7) - 1

-- The third return is the item string, and only for the items whose id does not describe them
-- - a random-enchantment suffix, an enchant, a gem. See Family:ItemString in Core.lua.
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
	if info == nil then return nil end

	local itemID = select(10, GetItemInfo(bag, slot))
	if itemID then return itemID, count or 1, worth end
	return nil
end

--------------------------------------------------------------------------------------------
-- The bank
--------------------------------------------------------------------------------------------

function Bank:Scan()
	local key = Family:CurrentMember()

	local containers = {}
	local slots, free = 0, 0

	for bag = BANK, LAST_BANK_BAG do
		-- The bank container is -1 and the bank bags start above the carried ones, so the
		-- carried bags in between are skipped rather than scanned twice.
		local isBankBag = (bag == BANK) or (bag >= FIRST_BANK_BAG)

		if isBankBag then
			local size = GetNumSlots and GetNumSlots(bag) or 0

			if size and size > 0 then
				local bagFree, bagType = 0, 0
				if GetNumFreeSlots then
					bagFree, bagType = GetNumFreeSlots(bag)
					bagFree = bagFree or 0
				end

				local special = (bagType or 0) ~= 0 and bag ~= BANK

				local entry = {
					size = size,
					free = bagFree,
					bagType = bagType or 0,
					special = special,
					slots = {},
				}

				if bag ~= BANK and ToInventoryId then
					entry.itemID = GetInventoryItemID("player", ToInventoryId(bag))
				end

				for slot = 1, size do
					local itemID, count, worth = slotContents(bag, slot)
					if itemID then
						entry.slots[slot] = { id = itemID, count = count, item = worth }
					end
				end

				containers[bag] = entry

				-- Special bags in the bank are excluded from the free total for the same
				-- reason they are in the bags (§3): they are not room for anything else.
				if not special then
					slots = slots + size
					free = free + bagFree
				end
			end
		end
	end

	if not next(containers) then
		Family:Debug("bank scan found nothing - is the window actually open?")
		return
	end

	local payload = Family.Database:Payload(key) or {}
	payload.bank = { containers = containers, seen = time() }
	Family.Database:SetPayload(key, payload)

	Family.Database:SetMeta(key, {
		bankSlots = slots,
		bankFree = free,
		bankSeen = time(),
	})

	-- What was written, not just the totals. A scan that finds the bank container and nothing
	-- in it looks identical to a healthy one in a line that only reports free slots, and it
	-- replaces whatever was there - so the two numbers that say whether a record just got
	-- smaller belong in the narration.
	local wrote, held = 0, 0
	for _, entry in pairs(containers) do
		wrote = wrote + 1
		for _ in pairs(entry.slots) do held = held + 1 end
	end

	Family:Debug("scanned bank: %d/%d free, %d container(s), %d item(s)",
		free, slots, wrote, held)
end

--------------------------------------------------------------------------------------------
-- The guild bank
--------------------------------------------------------------------------------------------

function Bank:ScanGuildBank()
	if not Family.Capabilities:Has("guildBank") then return end
	if not IsInGuild or not IsInGuild() then return end

	local tabs = Family:TryCall(GetNumGuildBankTabs) or 0
	if tabs == 0 then return end

	-- The guild's name, or nothing yet.
	--
	-- IsInGuild answers the moment the client loads and GetGuildInfo does not: for the first
	-- few seconds of a session, and sometimes longer, a character who is certainly in a guild
	-- has no guild name to give. Filing the tabs under a made-up name would put a guild
	-- called "Unknown" in the index, in the summary and on every tooltip that item appears
	-- on - and it would stay there after the real name arrived and the same tabs were filed
	-- again under it (§2.2: not known is not a value).
	--
	-- So nothing is written and the scan is asked for again. The window is still open; the
	-- second attempt costs nothing and by then the client will answer.
	--
	-- A few times and then it stops. Asking again for ever is what "wait for it to arrive"
	-- turns into when it never does, and a client that is going to answer does so within a
	-- few seconds - so a name that has not come by then is not coming, and a scanner quietly
	-- waking up every three seconds until logout is worse than one that gave up and said so.
	local guild = Family:TryCall(GetGuildInfo, "player")
	local realm = GetRealmName()

	if type(guild) ~= "string" or guild == "" or type(realm) ~= "string" or realm == "" then
		self.waitingForName = (self.waitingForName or 0) + 1

		if self.waitingForName > 5 then
			Family:Debug("guild bank open and the client will not say which guild - "
				.. "nothing recorded")
			return
		end

		Family:Debug("guild bank open but the guild has no name yet - trying again")
		Family:After(3, "bank.guild.named", function() Bank:ScanGuildBank() end)
		return
	end

	self.waitingForName = nil

	local contents = {}
	local known = 0

	for tab = 1, tabs do
		-- Asking about a tab nobody has opened returns nothing, which is not the same as
		-- the tab being empty. Only what was actually seen is recorded.
		local slots = {}
		local seen = false

		for slot = 1, (_G.MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
			local link = Family:TryCall(GetGuildBankItemLink, tab, slot)
			local _, count = Family:TryCall(GetGuildBankItemInfo, tab, slot)

			if link then
				seen = true
				local itemID = tonumber(link:match("item:(%d+)"))
				if itemID then
					slots[slot] = { id = itemID, count = tonumber(count) or 1,
						item = Family:ItemString(link) }
				end
			end
		end

		if seen then
			known = known + 1
			contents[tab] = { slots = slots, seen = time() }
		end
	end

	if known == 0 then return end

	-- Filed under the guild rather than the member: it belongs to the guild, and every
	-- member in it would otherwise store their own copy of the same thing.
	FamilyDB.guilds = FamilyDB.guilds or {}
	local guildKey = guild .. "-" .. realm

	FamilyDB.guilds[guildKey] = FamilyDB.guilds[guildKey] or {}
	FamilyDB.guilds[guildKey].tabs = contents
	FamilyDB.guilds[guildKey].seen = time()
	FamilyDB.guilds[guildKey].seenBy = Family:CurrentMember()

	Family:Debug("scanned %d guild bank tab(s) for %s", known, guildKey)
end

--------------------------------------------------------------------------------------------
-- When to scan
--------------------------------------------------------------------------------------------

-- Whether the bank window is open, which is the only time any of this can be read at all.
local isOpen = false

function Bank:IsOpen()
	return isOpen
end

Family:OnDatabaseReady("bank", function()
	for _, event in ipairs { "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED",
		"PLAYERBANKBAGSLOTS_CHANGED" } do
		Family:RegisterEvent(event, "bank", function()
			isOpen = true
			Family:After(0.5, "bank", function() Bank:Scan() end)
		end)
	end

	-- Moving something between the bank and the bags changes both, and the bank half of that
	-- is not always announced as a bank event: the bought bank bags are containers like any
	-- other and report themselves through BAG_UPDATE. Without this, taking twelve of
	-- something out of a bank bag left the bank still recorded as holding them, so the item
	-- tooltip counted the same twelve twice - in the bags, where they now were, and in the
	-- bank, where they used to be.
	--
	-- Only while the window is open, which costs nothing the rest of the time and is the only
	-- time the answer would be worth anything anyway.
	Family:RegisterEvent("BAG_UPDATE_DELAYED", "bank", function()
		if not isOpen then return end
		Family:After(0.5, "bank", function() Bank:Scan() end)
	end)

	-- One last look on the way out, so anything moved while the window was open is kept.
	-- Scanned before the flag is cleared, because the scan is what the flag is about.
	Family:RegisterEvent("BANKFRAME_CLOSED", "bank", function()
		Bank:Scan()
		isOpen = false
	end)

	for _, event in ipairs { "GUILDBANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED" } do
		Family:RegisterEvent(event, "bank", function()
			Family:After(1, "bank.guild", function() Bank:ScanGuildBank() end)
		end)
	end
end)
