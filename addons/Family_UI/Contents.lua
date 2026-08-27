-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a member possesses, drawn the way they carry it.
--
-- This was a list of names and it is now a set of bags, because a bag is not a list. Where a
-- thing sits in a bag is information - the potions are together, the third bag is the one
-- that is full, that stack of cloth has been there since Tuesday - and a sorted list of names
-- throws all of it away and gives back only alphabetical order, which nobody arranged.
--
-- So: every container in the order the game numbers them, each with its own icon, name and
-- capacity, and its slots in the order they really are, with quantities and nothing else.
-- What each thing is comes from the tooltip, exactly as it does in the game's own bags.
--
-- Mail and the auction house are drawn as containers too. They are not bags and they do not
-- pretend to be one - neither has slots in any real sense - but "where is that thing" is one
-- question, and answering it in two different shapes on the same panel would be answering it
-- twice.

local _, UI = ...

local Family = _G.Family

local SLOT = 32           -- twice the size of a list row's icon, which is what a bag looks like
local GAP = 4
local BLOCK_GAP = 10

local BACKPACK = 0
local BANK = _G.BANK_CONTAINER or -1
local KEYRING = _G.KEYRING_CONTAINER or -2

--------------------------------------------------------------------------------------------

local function membersWithContents()
	return UI:EveryMember()
end

local function guildOf(meta)
	if not meta.guild or not meta.realm then return nil end
	local guilds = FamilyDB and FamilyDB.guilds
	if not guilds then return nil end
	return guilds[meta.guild .. "-" .. meta.realm]
end

-- The name of a container, in the client's own words wherever it has any. A bought bag is an
-- item and answers for itself; the backpack and the bank are the game's own globals.
-- The picture for a container that is not an item.
--
-- A bought bag answers for itself and needs nothing here. Everything else was drawn as a
-- backpack, which is a picture of the wrong thing for four of them - a mailbox is not a
-- rucksack, and a player looking for their keys is looking for keys.
--
-- The game's own files, so each is right in every language and on every client that has the
-- container at all: no client draws a guild bank tab and lacks a tabard to draw it with.
local CONTAINER_ICON = {
	keyring  = "Interface\\ContainerFrame\\KeyRing-Bag-Icon",
	mail     = "Interface\\Icons\\INV_Letter_15",
	auctions = "Interface\\Icons\\INV_Misc_Coin_02",
	guild    = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
	fallback = "Interface\\Buttons\\Button-Backpack-Up",
}

local function containerIcon(entry)
	if entry.where == "bags" and entry.bag == KEYRING then
		return CONTAINER_ICON.keyring
	end

	if entry.itemID then
		local icon = Family:TryCall(GetItemIcon, entry.itemID)
		if icon then return icon end
	end

	return CONTAINER_ICON[entry.where] or CONTAINER_ICON.fallback
end

local function containerName(entry, bag, where)
	if where == "bags" and bag == BACKPACK then
		return _G.BACKPACK_TOOLTIP or "Backpack"
	end
	if where == "bags" and bag == KEYRING then
		return _G.KEYRING or "Keyring"
	end
	if where == "bank" and bag == BANK then
		return _G.BANK or "Bank"
	end

	if entry.itemID then
		local name = Family.Names:CachedItem(entry.itemID)
		if name then return name end
	end

	return string.format("%s %d", where == "bank" and "Bank bag" or "Bag", bag)
end

--------------------------------------------------------------------------------------------
-- The containers of one member, in the order they are carried
--
-- Each is { where, bag, size, free, slots, itemID, special }, and mail and auctions arrive
-- in the same shape with a size that is however many things are in them - so one drawing
-- routine covers all four.
--------------------------------------------------------------------------------------------

local function containersOf(payload, meta)
	local blocks = {}

	local function addRange(source, where, first, last)
		if not source then return end

		local order = {}
		for bag in pairs(source) do
			if bag >= first and bag <= last then order[#order + 1] = bag end
		end
		table.sort(order)

		for _, bag in ipairs(order) do
			local entry = source[bag]
			blocks[#blocks + 1] = {
				where = where,
				bag = bag,
				size = entry.size,
				free = entry.free,
				special = entry.special,
				itemID = entry.itemID,
				slots = entry.slots or {},
			}
		end
	end

	-- The carried bags first, then the keyring after them. The game numbers it below the
	-- backpack, but nobody thinks of their keys as the first thing they carry: it is a
	-- drawer at the end of the row, and it is drawn where it is thought of.
	addRange(payload and payload.bags, "bags", BACKPACK, 11)
	addRange(payload and payload.bags, "bags", KEYRING, KEYRING)
	addRange(payload and payload.bank and payload.bank.containers, "bank", BANK, 11)

	-- Mail: one block, its attachments in the order the letters are in. Nothing is dropped
	-- for being an odd shape - a letter with three things on it is three slots.
	if payload and payload.mail then
		local slots, count, inPost = {}, 0, 0
		local live = Family.Mail:Live(payload.mail)

		for _, letter in ipairs(live) do
			if letter.inPost then inPost = inPost + 1 end
			for _, item in ipairs(letter.attachments or {}) do
				count = count + 1
				slots[count] = { id = item.id, count = item.count or 1,
					from = letter.sender, inPost = letter.inPost }
			end
		end

		if count > 0 then
			blocks[#blocks + 1] = { where = "mail", size = count, slots = slots,
				free = 0, count = #live, inPost = inPost }
		end
	end

	-- The auction house: what is still listed. What expired since the snapshot is gone and
	-- is not drawn as an empty slot, because it is not a slot at all (§2.2).
	if payload and payload.auctions then
		local selling = Family.Auctions:Live(payload.auctions)
		local slots = {}
		for index, entry in ipairs(selling) do
			slots[index] = { id = entry.id, count = entry.count or 1 }
		end

		if #selling > 0 then
			blocks[#blocks + 1] = { where = "auctions", size = #selling, slots = slots,
				free = 0 }
		end
	end

	local guild = guildOf(meta)
	if guild then
		local tabs = {}
		for tab in pairs(guild.tabs or {}) do tabs[#tabs + 1] = tab end
		table.sort(tabs)

		for _, tab in ipairs(tabs) do
			local contents = guild.tabs[tab]
			local size = 0
			for slot in pairs(contents.slots or {}) do
				if slot > size then size = slot end
			end

			blocks[#blocks + 1] = { where = "guild", bag = tab, size = size,
				free = 0, slots = contents.slots or {} }
		end
	end

	return blocks
end

--------------------------------------------------------------------------------------------
-- Opening the real thing
--
-- Only for the member being played, and only where there is something to open. A bag of
-- somebody else's is a picture, and clicking a picture of a bag cannot open it.
--------------------------------------------------------------------------------------------

-- Toggled rather than opened, and the decision made here rather than left to the client.
--
-- Opening a bag that is already open does nothing, which is indistinguishable from a click
-- that did not work. Handing the whole question to ToggleBag was no better: it answered
-- differently depending on which of several frames the game had put that bag in, so a click
-- opened, or closed, or did nothing, and there was no way to tell which from the outside.
--
-- IsBagOpen is the client's own answer to the only question that matters, so it is asked and
-- acted on. Where a client does not have it, a click opens and never closes, which is the
-- safe half of the behaviour rather than an unpredictable whole.
-- Which calls this client actually has is checked, not assumed.
--
-- OpenBag and CloseBag are written in the game's own Lua rather than built into the engine,
-- and that file is rewritten between expansions - so a client can perfectly well have
-- OpenBackpack and not OpenBag. That is exactly what "the backpack opens and nothing else
-- does" looked like, and TryCall could not tell anybody: a call that is missing and a call
-- that did nothing are both silence.
--
-- So each one is looked for before it is used, the routes are tried in order of how well
-- they aim, and where the client will say whether a bag is open that answer is read back
-- afterwards rather than the call being taken at its word.
local function have(name)
	return type(_G[name]) == "function"
end

local function showContainer(bag)
	-- The keyring has a window of its own where a client has one at all, and ToggleBag
	-- turns round and calls this - so calling both, as this once did, opened it and shut
	-- it again in the same click.
	if bag == KEYRING then
		if have("ToggleKeyRing") then
			Family:TryCall(ToggleKeyRing)
		else
			Family:TryCall(ToggleBag, bag)
		end
		return
	end

	-- nil, not false, on a client that will not say. The three are different: open, shut,
	-- and no way to find out - and the last one means every attempt below has to be the
	-- only attempt, because trying the next route blind would toggle twice and land back
	-- where it started.
	local known = have("IsBagOpen")
	local open = known and (Family:TryCall(IsBagOpen, bag) and true or false) or nil

	local function verified(expected)
		if not known then return true end
		return (Family:TryCall(IsBagOpen, bag) and true or false) == expected
	end

	if bag == BACKPACK and have("OpenBackpack") and have("CloseBackpack") then
		if open then
			Family:TryCall(CloseBackpack)
		else
			Family:TryCall(OpenBackpack)
		end
		return
	end

	if open and have("CloseBag") then
		Family:TryCall(CloseBag, bag)
		if verified(false) then return end
	elseif not open and have("OpenBag") then
		Family:TryCall(OpenBag, bag)
		if verified(true) then return end
	end

	-- Decides for itself which container frame that bag belongs in, which is why it is not
	-- the first choice, but it is on clients that have nothing better.
	if have("ToggleBag") then
		Family:TryCall(ToggleBag, bag)
		if verified(not open) then return end
	end

	-- Nothing bag-by-bag works here. Opening all of them is blunt and the wrong shape for a
	-- click that named one, but the item the player pointed at is on the screen afterwards,
	-- which is the thing they were actually asking for.
	if not open and have("OpenAllBags") then
		Family:TryCall(OpenAllBags)
	end
end

local function openContainer(block, memberKey)
	if memberKey ~= Family:CurrentMember() then return end

	if block.where == "bags" then
		showContainer(block.bag)
		return
	end

	-- The bank's own window has to be open for any of it to be reachable: its bags live
	-- inside it, and it can only be looked at while standing at one. The bank container
	-- itself is the window, so there is nothing to open for it.
	if block.where == "bank" and block.bag ~= BANK and Family.Bank:IsOpen() then
		showContainer(block.bag)
	end
end

--------------------------------------------------------------------------------------------

local function build(frame)
	local blocks = {}          -- one drawn container each, reused between redraws
	local search

	local picker = UI:CreateMemberPicker(frame, 200, membersWithContents, function()
		if search then search:SetText("") end
		frame:Refresh()
	end)
	picker:SetPoint("TOPLEFT", 0, -2)

	-- Named, because a search box is the one control worth being able to reach from
	-- somewhere else - a macro, a test, or another addon.
	-- The label goes in front of the box rather than after it.
	--
	-- A caption to the right of the field it captions is read after the thing it was meant to
	-- explain, which is the wrong order for the one control here whose purpose is not obvious
	-- from looking at it. It also left the caption floating between this box and whatever came
	-- next, belonging to neither.
	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", picker, "RIGHT", 16, 0)
	hint:SetText("dim everything but")

	search = CreateFrame("EditBox", "FamilyContentsSearch", frame, "InputBoxTemplate")
	search:SetPoint("LEFT", hint, "RIGHT", 10, 0)
	search:SetSize(200, 20)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function() frame:Refresh() end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)


	-- "Who has one of these" is a different question from "what is this member carrying",
	-- and it wants a different answer: a list, with a name against every line. Bags are the
	-- wrong shape for it - forty bags of five members drawn one after another is not a
	-- search result - so the panel changes shape rather than pretending one fits.
	-- The same control the Character panel uses for the same idea, in the same place: a
	-- button at the top right that holds itself highlighted while it is on. It was a tick
	-- box and a caption, which is a second visual language for a thing that already had one
	-- three panels away - and "the whole family" beside a small square reads as a setting
	-- rather than as the switch between two ways of looking that it actually is.
	local wholeFamily = false

	local everyone = CreateFrame("Button", "FamilyContentsEveryone", frame, "UIPanelButtonTemplate")
	everyone:SetSize(120, 22)
	everyone:SetPoint("TOPRIGHT", -4, -2)
	everyone:SetText("Whole family")
	everyone:SetScript("OnClick", function()
		wholeFamily = not wholeFamily

		-- Straight into the box on the way in. Across the family this panel has nothing
		-- to draw until something is typed, so the switch empties the screen and leaves
		-- the one thing left to do sitting in an unfocused box at the top - which reads
		-- as the panel having broken rather than as it waiting.
		if wholeFamily then search:SetFocus() else search:ClearFocus() end

		frame:Refresh()
	end)

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	status:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 2, -6)
	status:SetPoint("RIGHT", -8, 0)
	status:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -2, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	----------------------------------------------------------------------------------------
	-- One container, and the slots in it
	----------------------------------------------------------------------------------------

	local function slotButton(block, index)
		local existing = block.slots[index]
		if existing then return existing end

		local button = CreateFrame("Button", nil, block.frame)
		button:SetSize(SLOT, SLOT)

		button.border = button:CreateTexture(nil, "BACKGROUND")
		button.border:SetAllPoints()
		button.border:SetColorTexture(1, 1, 1, 0.06)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)

		button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		button.count:SetPoint("BOTTOMRIGHT", -2, 2)
		button.count:SetJustifyH("RIGHT")

		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

		-- The real item tooltip, which carries Family's own blocks with it, so hovering a
		-- slot here says who else has one and who could make it (Tooltip.lua).
		--
		-- By the item string where the record has one, and by id for everything else. The
		-- id describes the item somebody bought; what is in the bag is that item plus its
		-- random-enchantment suffix, and the suffix is where a "of the Eagle" keeps its
		-- entire stat line. Asked by id alone, the client answers about the generic item and
		-- writes "<Random enchantment>" where the stats should be - a description of
		-- something nobody owns (Core.lua).
		UI:AttachTooltip(button, function(self)
			if self.itemLink then return "itemlink", self.itemLink end
			return "item", self.itemID
		end)

		button:RegisterForClicks("LeftButtonUp")
		button:SetScript("OnClick", function(self)
			if self.block then openContainer(self.block, self.memberKey) end
		end)

		block.slots[index] = button
		return button
	end

	-- One line of a family-wide search: what it is, who has it, and where.
	local resultRows = {}

	local function resultRow(index)
		local existing = resultRows[index]
		if existing then return existing end

		local r = CreateFrame("Button", nil, list)
		r:SetHeight(20)

		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(18, 18)
		r.icon:SetPoint("LEFT", 4, 0)

		r.text = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.text:SetPoint("LEFT", 26, 0)
		r.text:SetWidth(260)
		r.text:SetJustifyH("LEFT")

		r.who = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.who:SetPoint("LEFT", 290, 0)
		r.who:SetWidth(160)
		r.who:SetJustifyH("LEFT")

		r.where = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.where:SetPoint("RIGHT", -8, 0)
		r.where:SetWidth(220)
		r.where:SetJustifyH("RIGHT")

		UI:NoWrap(r.text, r.who, r.where)
		UI:AttachTooltip(r, function(self)
			if self.itemLink then return "itemlink", self.itemLink end
			return "item", self.itemID
		end)

		resultRows[index] = r
		return r
	end

	local function blockFrame(index)
		local existing = blocks[index]
		if existing then return existing end

		local block = { slots = {} }
		block.frame = CreateFrame("Frame", nil, list)

		-- The bag itself, at the head of its own row of slots rather than on a line above
		-- them. Six containers used to cost six headings and six lines of counts, and the
		-- bags fell off the bottom of a screen that had room for all of them - which is the
		-- one thing a panel about somebody's bags has to get right.
		--
		-- A button rather than a picture, because everything the heading used to say is on
		-- it now: what the bag is called, how full it is, and what it will hold.
		block.icon = CreateFrame("Button", nil, block.frame)
		block.icon:SetSize(SLOT, SLOT)
		block.icon:SetPoint("TOPLEFT", 0, 0)

		block.icon.texture = block.icon:CreateTexture(nil, "ARTWORK")
		block.icon.texture:SetAllPoints()

		-- Family's own lines rather than the bag item's tooltip. What is wanted here is how
		-- full this container is, which is a fact about the container and not about the bag
		-- that was bought to make it - and the bag's name is the first line of it anyway.
		UI:AttachTooltip(block.icon, function(self)
			return nil, nil, self.lines
		end)

		blocks[index] = block
		return block
	end

	----------------------------------------------------------------------------------------

	function frame:Refresh()
		UI:MarkSelected(everyone, wholeFamily)

		-- The box does two different jobs and the caption has to say which. Against one
		-- member it dims what does not match, and everything stays on screen; across the
		-- family it is the search itself, and nothing is on screen until it has something
		-- in it. A caption still reading "dim everything but" over an empty panel says the
		-- panel lost the items rather than that it is waiting to be asked.
		hint:SetText(wholeFamily and "find across the family" or "dim everything but")

		local member = picker:Reconcile()

		local width = math.max(scroll:GetWidth(), 200)
		list:SetWidth(width)

		local perRow = math.max(math.floor((width - 8) / (SLOT + GAP)), 1)
		local needle = (search:GetText() or ""):lower()

		local used, y = 0, 0


		local usedResults = 0

		local function finish(message)
			if message then status:SetText(message) end
			for index = used + 1, #blocks do blocks[index].frame:Hide() end
			for index = usedResults + 1, #resultRows do resultRows[index]:Hide() end
			list:SetHeight(math.max(y, 1))
		end

		----------------------------------------------------------------------------------
		-- Searching everybody
		----------------------------------------------------------------------------------

		if wholeFamily then
			picker:Hide()

			if #needle < 2 then
				return finish("|cff9d9d9dSearching the whole family. Type at least two "
					.. "letters in the box above to see who has what.|r")
			end

			local matches = Family.Index:Search(needle)
			local shown = 0

			for _, item in ipairs(matches) do
				local owners, guilds = Family.Index:Owners(item.id)

				UI:NamesOf(owners)

				for _, owner in ipairs(owners) do
					usedResults = usedResults + 1
					local r = resultRow(usedResults)
					r:SetPoint("TOPLEFT", 0, -y)
					r:SetPoint("TOPRIGHT", 0, -y)
					r:Show()
					y = y + 20
					shown = shown + 1

					-- By id, and only by id. A search result is one line for an item that
					-- several members may hold in several different suffixed forms, so
					-- there is no one string that describes it - and a row reused from a
					-- previous search would otherwise keep the last one it was given.
					r.itemID, r.itemLink = item.id, nil
					r.icon:SetTexture(Family:TryCall(GetItemIcon, item.id)
						or "Interface\\Icons\\INV_Misc_QuestionMark")
					r.text:SetText(string.format("%s |cffffd700%d|r", item.name,
						owner.total))

					local red, green, blue = UI:ClassColour(owner.classFile)
					r.who:SetText(owner.label or owner.name)
					r.who:SetTextColor(red, green, blue)

					local places = {}
					if owner.bags > 0 then places[#places + 1] = owner.bags .. " bags" end
					if owner.bank > 0 then places[#places + 1] = owner.bank .. " bank" end
					if owner.mail > 0 then places[#places + 1] = owner.mail .. " mail" end
					if owner.auctions > 0 then
						places[#places + 1] = owner.auctions .. " auction"
					end
					r.where:SetText("|cff888888" .. table.concat(places, ", ") .. "|r")
				end

				for _, guild in ipairs(guilds) do
					usedResults = usedResults + 1
					local r = resultRow(usedResults)
					r:SetPoint("TOPLEFT", 0, -y)
					r:SetPoint("TOPRIGHT", 0, -y)
					r:Show()
					y = y + 20
					shown = shown + 1

					-- By id, and only by id. A search result is one line for an item that
					-- several members may hold in several different suffixed forms, so
					-- there is no one string that describes it - and a row reused from a
					-- previous search would otherwise keep the last one it was given.
					r.itemID, r.itemLink = item.id, nil
					r.icon:SetTexture(Family:TryCall(GetItemIcon, item.id)
						or "Interface\\Icons\\INV_Misc_QuestionMark")
					r.text:SetText(string.format("%s |cffffd700%d|r", item.name,
						guild.count))
					r.who:SetText("|cff40c040" .. guild.key .. "|r")
					r.who:SetTextColor(1, 1, 1)
					r.where:SetText("|cff888888guild bank|r")
				end
			end

			-- Only what the client has named. An item nobody has looked at since the
			-- last patch has no name to match against yet, and saying so is better than
			-- letting a search quietly answer for less than it searched.
			status:SetText(string.format(
				"|cffffd700%d|r line%s for \"%s\" across the family   |cff888888|||r   " ..
				"|cff888888only items the client has named can be matched|r",
				shown, shown == 1 and "" or "s", needle))

			if shown == 0 then
				status:SetText(string.format(
					"|cff9d9d9dNothing named like \"%s\" is held by anybody.|r", needle))
			end

			return finish()
		end

		picker:Show()

		if not member then
			return finish("|cff9d9d9dNothing recorded yet.|r")
		end

		local payload = UI:Payload(member.key)
		local meta = member.meta
		local drawn = containersOf(payload, meta)

		-- How current each part of this is, said before it rather than after: the bank is
		-- a photograph and the bags are not, and a panel that draws them identically has
		-- to say so somewhere (§2.2).
		local parts = {}
		parts[#parts + 1] = payload and payload.bags
			and ("bags " .. UI:Ago(meta.bagsSeen)) or "|cff9d9d9dbags not seen|r"
		parts[#parts + 1] = meta.bankSeen and ("bank " .. UI:Ago(meta.bankSeen))
			or "|cff9d9d9dbank not seen|r"
		parts[#parts + 1] = meta.mailSeen and ("mail " .. UI:Ago(meta.mailSeen))
			or "|cff9d9d9dmail not seen|r"
		parts[#parts + 1] = meta.auctionsSeen and ("auctions " .. UI:Ago(meta.auctionsSeen))
			or "|cff9d9d9dauctions not seen|r"
		status:SetText(table.concat(parts, "   |cff888888|||r   "))

		if #drawn == 0 then
			return finish(status:GetText() ..
				"   |cff9d9d9d- nothing to show yet|r")
		end

		local LABEL = {
			bags = "", bank = "|cff88bbff(bank)|r", mail = "|cffff8040Mail|r",
			auctions = "|cffffd700Auctions|r", guild = "|cff40c040Guild bank|r",
		}

		for index, container in ipairs(drawn) do
			used = index
			local block = blockFrame(index)

			-- The bag takes the first place in its own row, so a container of sixteen in a
			-- row that holds eighteen is one line rather than three.
			local acrossRow = math.max(perRow - 1, 1)
			local rows = math.ceil(math.max(container.size, 1) / acrossRow)
			local height = rows * (SLOT + GAP)

			block.frame:SetSize(width, height)
			block.frame:ClearAllPoints()
			block.frame:SetPoint("TOPLEFT", 0, -y)
			block.frame:Show()
			y = y + height + BLOCK_GAP

			block.icon.texture:SetTexture(containerIcon(container))

			local title
			if container.where == "mail" then
				title = string.format("%s |cff888888%d letter%s|r", LABEL.mail,
					container.count or 0, (container.count or 0) == 1 and "" or "s")

				-- Said on the heading rather than only on the slots, because the
				-- difference between "this member has it" and "this member has been
				-- sent it" is the whole of what the block is worth (§5).
				if (container.inPost or 0) > 0 then
					title = title .. string.format("  |cffffd700%d in the post|r",
						container.inPost)
				end
			elseif container.where == "auctions" then
				title = LABEL.auctions
			elseif container.where == "guild" then
				title = string.format("%s |cff888888tab %d|r", LABEL.guild,
					container.bag or 0)
			else
				title = containerName(container, container.bag, container.where)
				if container.where == "bank" then
					title = title .. "  " .. LABEL.bank
				end
			end

			-- What the heading and the counts used to say, on the bag itself.
			--
			-- Six containers cost six headings and six lines of counts, and that pushed the
			-- last bags off a screen with room for all of them. None of it is worth a line
			-- of its own: which bag this is, is answered by its picture nine times out of
			-- ten, and how full it is, is answered by the gaps in the row beside it. What
			-- is left is worth asking for and not worth being shown.
			local lines = { { title } }

			if container.where == "bags" or container.where == "bank" then
				lines[#lines + 1] = { string.format("|cff888888%d of %d free|r",
					container.free or 0, container.size or 0) }
				if container.special then
					-- §3: a quiver's free slots are not room for anything else, and this
					-- is the one place that fact has anywhere left to be said.
					lines[#lines + 1] = { "|cffffaa00only its own kind of thing fits "
						.. "here|r" }
				end
			else
				lines[#lines + 1] = { string.format("|cff888888%d|r", container.size or 0) }
			end

			block.icon.lines = lines

			for slot = 1, container.size do
				local button = slotButton(block, slot)
				local item = container.slots[slot]

				button:ClearAllPoints()
				-- One place further along than the slot number says, on the first row,
				-- because the bag itself is sitting in the place before it.
				local column = (slot - 1) % acrossRow + 1
				local row = math.floor((slot - 1) / acrossRow)
				button:SetPoint("TOPLEFT", block.frame, "TOPLEFT",
					column * (SLOT + GAP), -(row * (SLOT + GAP)))
				button:Show()

				button.block = container
				button.memberKey = member.key
				button.itemID = item and item.id or nil
				button.itemLink = item and item.item or nil

				if item then
					-- Asked for by id, and the row draws itself again when the client
					-- answers - the same arrangement the list had (§2.1).
					Family.Names:Item(item.id, "contents", function()
						if frame:IsShown() then frame:Refresh() end
					end)

					button.icon:SetTexture(Family:TryCall(GetItemIcon, item.id)
						or "Interface\\Icons\\INV_Misc_QuestionMark")
					button.count:SetText(item.count > 1 and item.count or "")

					-- Filtering dims rather than hides. A bag with the matches taken
					-- out of it is not that bag any more, and where a thing sits is
					-- half of what this panel is for.
					local name = Family.Names:CachedItem(item.id)
					local matches = needle == "" or not name
						or name:lower():find(needle, 1, true) ~= nil
					button.icon:SetAlpha(matches and 1 or 0.15)
					button.count:SetAlpha(matches and 1 or 0.15)
				else
					button.icon:SetTexture(nil)
					button.count:SetText("")
				end
			end

			-- Slots this container no longer has - it was a bigger bag last time.
			for slot = container.size + 1, #block.slots do
				block.slots[slot]:Hide()
			end
		end

		return finish()
	end
end

UI:RegisterTab("contents", "Possessions", build)
