-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- /family, and /fam for people in a hurry.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local commands = {}

local function usage()
	Family:Print(L["commands:"])
	for _, entry in ipairs(commands) do
		Family:Print(L["  |cffffd700/family %s|r - %s"], entry.name, entry.help)
	end
end

local function add(name, help, fn)
	tinsert(commands, { name = name, help = help, fn = fn })
end

add("show", L["open the window"], function() UI:Show() end)
add("hide", L["close it"], function() UI:Hide() end)
add("toggle", L["open it if closed, close it if open"], function() UI:Toggle() end)

add("forget", L["forget a member: /family forget Name-Realm"], function(argument)
	if not argument or argument == "" then
		Family:Print(L["which member? /family forget Name-Realm"])
		return
	end
	if Family.Database:Forget(argument) then
		Family:Print(L["forgotten %s. This changes Family's records, nothing in the game."],
			argument)
		UI:Refresh()
	else
		Family:Print(L["no member called %s. Names are as they appear in the summary."],
			argument)
	end
end)

-- Why a recipe is showing the wrong language, answered by the client rather than by anybody's
-- reasoning about it.
--
-- A recipe is named from its spell id, and where there is no id there is nothing to name it
-- with but the word the scanning client used. Whether that id is there is not something this
-- repository can know about somebody's saved data, and it is the whole difference between a
-- display fault and a scan that needs running again.
add("recipes", L["why a recipe is in the wrong language: /family recipes"], function()
	local key = Family:CurrentMember()
	local payload = Family.Database:Payload(key) or {}
	local professions = payload.professions or {}

	Family:Print(L["|cffffd700Recipes|r held for %s"], tostring(key))

	local any = false
	for id, record in pairs(professions) do
		any = true
		local recipes = record.recipes or {}
		local spells, items = 0, 0
		for _, recipe in ipairs(recipes) do
			if recipe.spellID then spells = spells + 1 end
			if recipe.itemID then items = items + 1 end
		end

		-- **And which language it was read in**, which is the question this command exists
		-- to answer and the one thing it was leaving to be inferred from which words look
		-- French. It decides more than the display: a record whose locale is the reader's
		-- is drawn from the recorded word with neither id touched, so a family read on the
		-- client it was scanned with never waits for an item name at all.
		--
		-- Said beside the reader's own, because "frFR" alone answers half the question.
		-- Nothing where the record predates the field, which is honest rather than tidy:
		-- a record with no locale is exactly one the fast path cannot use.
		Family:Print(L["  %s: %d recipe(s), %d with a spell id, %d with an item id, "
			.. "read in %s and you are reading in %s"],
			tostring(Family:ProfessionName(id, record.name)), #recipes, spells, items,
			tostring(record.locale or "?"), tostring(Family.locale))

		-- Three of them in full, because a count says how many are missing an id and not
		-- what the client says about the ones that have one.
		for index = 1, math.min(3, #recipes) do
			local recipe = recipes[index]
			Family:Print(L["    %s  |cff888888spell|r %s -> %s  |cff888888item|r "
				.. "%s -> %s"],
				tostring(recipe.name),
				tostring(recipe.spellID),
				tostring(recipe.spellID and Family.Names:Spell(recipe.spellID)),
				tostring(recipe.itemID),
				tostring(recipe.itemID and Family.Names:CachedItem(recipe.itemID)))
		end
	end

	if not any then
		Family:Print(L["  nothing recorded - open each profession window once"])
	end

	-- What the client actually hands back, for a window open right now. Records keep ids
	-- and not links, so this is the only place the raw answer can be seen - and "the call
	-- returns nothing" and "the call returns a link of a kind nobody expected" are two
	-- different faults with one symptom.
	--
	-- The bars are doubled so the chat frame prints the link instead of rendering it.
	local function shown(link)
		if type(link) ~= "string" then return tostring(link) end
		return (link:gsub("|", "||"))
	end

	local line = Family:TryCall(GetTradeSkillLine)
	if line and line ~= "UNKNOWN" then
		Family:Print(L["  open trade skill window: %s"], tostring(line))
		for index = 1, math.min(3, Family:TryCall(GetNumTradeSkills) or 0) do
			Family:Print(L["    row %d: recipe %s | item %s"], index,
				shown(Family:TryCall(GetTradeSkillRecipeLink, index)),
				shown(Family:TryCall(GetTradeSkillItemLink, index)))
		end
	end

	local craft = Family:TryCall(GetCraftName)
	if craft and craft ~= "UNKNOWN" then
		Family:Print(L["  open craft window: %s"], tostring(craft))
		for index = 1, math.min(3, Family:TryCall(GetNumCrafts) or 0) do
			Family:Print(L["    row %d: recipe %s | item %s"], index,
				shown(Family:TryCall(GetCraftRecipeLink, index)),
				shown(Family:TryCall(GetCraftItemLink, index)))
		end
	end
end)

-- Why a bank record is missing, or a bag is shown in the wrong slot.
--
-- Two questions this repository cannot answer about somebody's client: which members have a
-- bank record at all, and whether the container the client reports a bag in is the container
-- the player sees it in. The first is in the saved data and the second can only be had from a
-- bank window that is open right now.
add("bank", L["why a bank record is missing or a bag is in the wrong slot: /family bank"],
function()
	Family:Print(L["|cffffd700Bank records|r"])

	local members = {}
	for key in pairs(Family.Database:Members()) do members[#members + 1] = key end
	table.sort(members)

	for _, key in ipairs(members) do
		local meta = Family.Database:Meta(key) or {}
		local payload = Family.Database:Payload(key)
		local bank = payload and payload.bank

		local containers, filled = 0, 0
		for _, entry in pairs((bank or {}).containers or {}) do
			containers = containers + 1
			for _ in pairs(entry.slots or {}) do filled = filled + 1 end
		end

		Family:Print(L["  %s: %s, %d container(s), %d item(s), meta says %s"],
			key,
			bank and bank.seen and string.format(L["seen %s"], UI:Ago(bank.seen))
				or L["no bank record"],
			containers, filled,
			meta.bankSeen and UI:Ago(meta.bankSeen) or L["never"])
	end

	-- What the client says this moment, which is the only place the answer to a bag in the
	-- wrong slot can come from: the record keeps container ids and the player sees positions.
	-- Described whether or not a window is open, and it says which. What the client answers
	-- about the bank container with no bank in front of you is the question: a scan that ran
	-- there and got an answer would record a bank with nothing in it, over whatever was
	-- there before.
	local open = Family.Bank:IsOpen()
	Family:Print(open and L["  a bank window is open"]
		or L["  no bank window is open - what follows is what the client says anyway"])

	local containerAPI = C_Container or {}
	local numSlots = containerAPI.GetContainerNumSlots or _G.GetContainerNumSlots
	local numFree = containerAPI.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
	local getItem = containerAPI.GetContainerItemInfo or _G.GetContainerItemInfo
	local toInventory = containerAPI.ContainerIDToInventoryID or _G.ContainerIDToInventoryID

	-- How many bank bag slots have been bought, and whether they are all used. Asked because
	-- the bank's free count exceeds what its size allows and the difference has to come from
	-- somewhere; empty bag slots are the nearest thing to it on that window. Printed, not
	-- acted on - the last theory about this fitted perfectly and was wrong.
	local bought, full = Family:TryCall(GetNumBankSlots)
	Family:Print(L["  bank bag slots bought: %s, all used: %s"],
		tostring(bought), tostring(full))

	Family:Print(L["  open now, as the client reports it:"])
	for bag = -1, 11 do
		if bag == -1 or bag >= 5 then
			local size = numSlots and Family:TryCall(numSlots, bag) or 0
			if (size or 0) > 0 then
				local inventory = toInventory and Family:TryCall(toInventory, bag)
				local itemID = inventory
					and Family:TryCall(GetInventoryItemID, "player", inventory)

				-- Free as well as size, because a container reporting more free than it
				-- has is the whole of the fault being chased: a bank totalling "56 of 52
				-- free" is one of these lying, and this says which.
				local free = numFree and Family:TryCall(numFree, bag)

				Family:Print(L["    container %d: %d slots, %s free, inventory slot %s, "
					.. "bag item %s %s"],
					bag, size, tostring(free), tostring(inventory), tostring(itemID),
					tostring(itemID and Family.Names:CachedItem(itemID) or ""))

				-- And what is actually in it, counted by asking every slot the size
				-- claims. If the size is short, this is short by the same amount, and the
				-- items in the slots past it are ones Family has never seen.
				local held = 0
				for slot = 1, (size or 0) do
					if Family:TryCall(getItem, bag, slot) then held = held + 1 end
				end
				Family:Print(L["      %d of those %d slots have something in them"],
					held, size)

				-- And past where the size call says the container ends. A slot that does
				-- not exist answers nothing, and so does an empty one - so this only ever
				-- proves the container is bigger, never that it is not. Put something in a
				-- bank square the panel does not show and it will be found here.
				local beyond = {}
				for slot = (size or 0) + 1, (size or 0) + 8 do
					if Family:TryCall(getItem, bag, slot) then
						beyond[#beyond + 1] = tostring(slot)
					end
				end
				if #beyond > 0 then
					Family:Print(L["      and something is in slot(s) %s, past where the "
						.. "size call says this container ends"],
						table.concat(beyond, ", "))
				end
			end
		end
	end
end)

add("guild", L["guild share on, off, test, log or names: /family guild test"], function(argument)
	local wanted = (argument or ""):lower():match("^%S*")

	if wanted ~= "on" and wanted ~= "off" and wanted ~= "test" and wanted ~= "log"
		and wanted ~= "names" then
		Family:Print(L["Guild share is currently |cffffd700%s|r."],
			Family.Guild:Enabled() and L["on"] or L["off"])
		Family:Print(L["It shows your guild the gear and talents of your characters in it, "
			.. "and shows you theirs. Nothing else - bags, mail and the rest need a Wide "
			.. "Family link. All of it is what the game already shows anybody who "
			.. "inspects you."])
		Family:Print(L["|cffffd700/family guild off|r to stop, which stops both halves: "
			.. "Family then neither asks nor answers."])
		Family:Print(L["|cffffd700/family guild test|r says what has actually crossed the "
			.. "wire. Run it on both clients and compare - the fault is wherever the two "
			.. "stop agreeing."])
		Family:Print(L["|cffffd700/family guild log|r asks this client what it can read of "
			.. "the guild's own event log. Family does not use it; this is finding out "
			.. "whether it could."])
		Family:Print(L["|cffffd700/family guild names|r asks what this client calls your "
			.. "character and everybody in the roster, which decides whether two people of "
			.. "the same name can be told apart."])
		return
	end

	if wanted == "test" then
		Family.Guild:Diagnose()
		return
	end

	if wanted == "log" then
		Family.Guild:ProbeEventLog()
		return
	end

	if wanted == "names" then
		Family.Guild:ProbeNames()
		return
	end

	local on = wanted == "on"
	Family.Guild:SetEnabled(on)
	Family:Print(L["Guild share is now |cffffd700%s|r."], on and L["on"] or L["off"])
	UI:Refresh()
end)

add("wide", L["Wide Family, which is off by default: /family wide on"],
	function(argument)
		local wanted = (argument or ""):lower():match("^%S*")

		if wanted ~= "on" and wanted ~= "off" then
			Family:Print(L["Wide Family is currently |cffffd700%s|r."],
				Family.Wide:Enabled() and L["on"] or L["off"])
			Family:Print(L["It lets two players link their families and share chosen members. "
				.. "Sharing is the one thing here a later version cannot take back, so it "
				.. "is off until you say otherwise rather than on until you notice."])
			Family:Print(L["|cffffd700/family wide on|r to switch it on, "
				.. "|cffffd700/family wide off|r to switch it back off."])
			return
		end

		local on = wanted == "on"
		if Family.Wide:Enabled() == on then
			Family:Print(L["Wide Family is already %s."], on and L["on"] or L["off"])
			return
		end

		Family.Wide:SetEnabled(on)

		-- The panel is in the list whether this is on or off, so there is nothing to reload
		-- for any more: the switch takes effect where it is thrown.
		Family:Print(L["Wide Family is now |cffffd700%s|r."], on and L["on"] or L["off"])
		if on then
			Family:Print(L["Nothing is shared with anybody until you link with them and tick "
				.. "what they may see."])
		end
	end)

add("status", L["what Family knows, and how it is storing it"], function()
	local members = 0
	for _ in pairs(Family.Database:Members()) do members = members + 1 end

	Family:Print(L["version %s on %s"], Family.version, Family.Capabilities.name)
	Family:Print(members == 1 and L["%d member recorded"] or L["%d members recorded"],
		members)
	Family:Print(L["storage: %s"], Family.Codec.compressing
		and "compressed"
		or L["|cffffaa00uncompressed|r - LibSerialize and LibDeflate are not installed"])

	-- Which tooltip route took, because the answer differs per client and a missing
	-- possessions block is otherwise indistinguishable from owning nothing.
	Family:Print(L["tooltips: %s"], Family.tooltipRoute or L["|cffffaa00not hooked|r"])
end)

add("tooltiptest", L["check the possessions block for an item: /family tooltiptest 2589"],
	function(argument)
		local itemID = tonumber((argument or ""):match("(%d+)"))
		if not itemID then
			Family:Print(L["give an item id, or shift-click an item link into chat and " ..
				"use the number from it."])
			return
		end

		local owners, guilds = Family.Index:Owners(itemID)
		Family:Print(L["item %d: %d member(s), %d guild bank(s)"], itemID, #owners, #guilds)

		for _, owner in ipairs(owners) do
			Family:Print(L["  %s: %d (bags %d, bank %d, mail %d, auction %d)"],
				owner.name, owner.total, owner.bags, owner.bank, owner.mail,
				owner.auctions)
		end
		for _, guild in ipairs(guilds) do
			Family:Print(L["  %s: %d in the guild bank"], guild.key, guild.count)
		end

		if #owners == 0 and #guilds == 0 then
			Family:Print(L["nobody holds one, so no tooltip block would be added."])
		end
	end)

add("talents", L["what talent data is actually stored, and for whom"], function()
	local found = 0

	for key, entry in pairs(Family.Database:Members()) do
		local payload, reason = Family.Database:Payload(key)

		if not payload then
			Family:Print(L["  %s: |cffffaa00no payload|r%s"], key,
				reason and (" - " .. reason) or "")
		elseif not payload.talents then
			Family:Print(L["  %s: payload present, |cffffaa00no talents in it|r"], key)
		else
			found = found + 1
			local t = payload.talents
			Family:Print(L["  |cff44dd44%s|r: %s, %d group(s), active %d"],
				key, t.system or "?", t.groupCount or 0, t.activeGroup or 0)

			for group = 1, (t.groupCount or 0) do
				local data = t.groups and t.groups[group]
				if not data then
					Family:Print(L["     spec %d: |cffffaa00missing|r"], group)
				elseif data.system == "trees" then
					local ranked = 0
					for _, tab in pairs(data.tabs or {}) do
						for _, talent in pairs(tab.talents or {}) do
							if (talent.rank or 0) > 0 then ranked = ranked + 1 end
						end
					end
					Family:Print(L["     spec %d: %d point(s), %d tab(s), %d talent(s) ranked%s"],
						group, data.pointsSpent or 0, #(data.tabs or {}), ranked,
						data.visited == false and L[" |cff888888(unvisited)|r"] or "")

					-- How many of them the generated table can name, asked without a
					-- fallback so a miss answers nothing instead of quietly handing back
					-- the word this record was written with. On a client whose language
					-- matches the record the two are identical on screen, so a table that
					-- names nothing at all looks exactly like one that works.
					local named, total = 0, 0
					local class = (Family.Database:Meta(key) or {}).classFile
					for tab, tabData in pairs(data.tabs or {}) do
						for _, talent in pairs(tabData.talents or {}) do
							total = total + 1
							if Family:TalentName(class, tab, talent.tier, talent.column)
							then
								named = named + 1
							end
						end
					end
					Family:Print(L["       the talent table names %d of those %d"],
						named, total)
				else
					local chosen = 0
					for _, row in pairs(data.tiers or {}) do
						if row.chosen then chosen = chosen + 1 end
					end
					Family:Print(L["     spec %d: %d tier(s), %d chosen, spec id %s"],
						group, #(data.tiers or {}), chosen, tostring(data.specID))

					local named, total = 0, 0
					for _, row in pairs(data.tiers or {}) do
						for _, choice in pairs(row.choices or {}) do
							total = total + 1
							if Family:TalentNameByID(choice.id) then
								named = named + 1
							end
						end
					end
					Family:Print(L["       the talent table names %d of those %d"],
						named, total)
				end
			end
		end
	end

	if found == 0 then
		Family:Print(L["|cffffaa00No member has talent data.|r Try /family rescan, then " ..
			"look at what it says."])
	end
end)

-- Whether this client can name a place from its id, which decides whether the hearthstone
-- column can ever be right.
--
-- Family stores where a hearthstone is bound as the word GetBindLocation hands back, and a word
-- is one language and one expansion: a French Era client says "Ironforge" where a French
-- Burning Crusade client says "Forgefer" (L-020). The fix wants an id, and the tables that
-- would turn an id back into a word in five languages measure 876 KB - so the only affordable
-- fix is the client naming its own places, and nothing in a file can say whether it can.
--
-- Three known ids are asked for by name so the answer can be read rather than trusted: 1537 is
-- Ironforge, 1519 Stormwind City, 3703 Shattrath City. A client that answers with the words
-- this player's game uses is a client that makes the table unnecessary.
add("hearth", L["whether this client can name a place from its id: /family hearth"], function()
	Family:Print(L["language %s, expansion %s"],
		tostring(Family.locale), tostring(Family.Capabilities.expansion))

	local bound = Family:TryCall(GetBindLocation)
	if bound and bound ~= "" then
		Family:Print(L["this client calls your hearthstone's home %s"],
			"|cff44dd44" .. tostring(bound) .. "|r")
	else
		Family:Print(L["|cffffaa00This client does not say where your hearthstone is "
			.. "bound.|r"])
		bound = nil
	end

	-- Held by name rather than called directly, so that a client without one says so instead
	-- of erroring, and so that what was asked is printed beside what came back.
	local candidates = {
		{ "C_Map.GetAreaInfo", C_Map and C_Map.GetAreaInfo },
		{ "GetAreaInfo", _G.GetAreaInfo },
		{ "C_Map.GetMapInfo", C_Map and C_Map.GetMapInfo },
	}

	local namer
	for _, candidate in ipairs(candidates) do
		local label, fn = candidate[1], candidate[2]
		if type(fn) ~= "function" then
			Family:Print(L["  %s: |cffffaa00not on this client|r"], label)
		else
			local answers = {}
			for _, id in ipairs { 1537, 1519, 3703 } do
				local ok, answer = pcall(fn, id)
				if ok and type(answer) == "table" then answer = answer.name end
				if ok and type(answer) == "string" and answer ~= "" then
					answers[#answers + 1] = string.format("%d=%s", id, answer)
					namer = namer or fn
				else
					answers[#answers + 1] = string.format("%d=?", id)
				end
			end
			Family:Print(L["  %s: %s"], label, table.concat(answers, "  "))
		end
	end

	if not namer then
		Family:Print(L["|cffffaa00Nothing here can name a place from its id.|r The "
			.. "hearthstone column cannot be translated without shipping a table."])
		return
	end

	if not bound then return end

	-- The other half of the question: a name can be turned back into an id only by asking
	-- for every id until one matches. Worth knowing what that costs before relying on it.
	local found, asked = nil, 0
	for id = 1, 6000 do
		asked = id
		local ok, answer = pcall(namer, id)
		if ok and type(answer) == "table" then answer = answer.name end
		if ok and answer == bound then
			found = id
			break
		end
	end

	if found then
		Family:Print(L["|cff44dd44Found it at id %d|r after %d calls, so a record could "
			.. "store the id instead of the word."], found, asked)
	else
		Family:Print(L["|cffffaa00No id in %d matched|r what this client calls that "
			.. "place, so the word cannot be turned into an id here."], asked)
	end
end)

add("ready", L["which crafting cooldowns have come back, and for whom"], function()
	local waiting = Family.Cooldowns:Ready()

	if #waiting == 0 then
		Family:Print(L["no crafting cooldowns are ready."])
		Family:Print(L["|cff888888Crafting cooldowns only - transmutes, mooncloth, salt "
			.. "shakers. Raid and heroic lockouts are a different thing and are not "
			.. "recorded yet.|r"])
		return
	end

	-- Named, not counted. "3 ready" is the answer to a question nobody asked; which three
	-- is the answer to "why is this telling me anything at all", which is what somebody
	-- typing this is usually after - and it is the only way to see a cooldown that should
	-- not be in the list at all.
	for _, member in ipairs(waiting) do
		local meta = Family.Database:Meta(member.key)
		local names = {}

		for _, entry in ipairs(Family.Cooldowns:For(meta)) do
			if entry.ready then
				names[#names + 1] = entry.name
					or (entry.id and string.format(L["item %s"], entry.id))
					or L["something unnamed"]
			end
		end

		Family:Print("  |cff40bf40%s|r: %s", member.name,
			#names > 0 and table.concat(names, ", ")
				or string.format(L["%d ready"], member.count))
	end
end)

-- Whether a creature's training points add up, on the client that has the creature.
--
-- Two readings of the same character put beside each other: the book says which abilities the
-- creature holds and at which rank, the trainer's window says what each row costs, and
-- `GetPetTrainingPoints` says how many points have been spent altogether. The sum of the priced
-- abilities against that number is the question.
--
-- **It is a reading and not a claim.** Whether the trainer's window prices a rank the creature
-- already holds is not measured anywhere in this repository - the window prices what the creature
-- that is out *can learn*, and whether that includes the rank it is already on is exactly what
-- this finds out. So it prints the working: how many abilities could be priced, how many could
-- not, and what the priced ones come to. Nothing is scanned and nothing is sent; it reads what is
-- already on disk.
add("pettp", L["check a pet's training points against what its abilities cost"], function()
	local found = 0

	for key in pairs(Family.Database:Members()) do
		local payload = Family.Database:Payload(key)

		for _, creature in ipairs(Family.Pets:Training(payload)) do
			if creature.total then
				found = found + 1

				Family:Print(L["|cffffd700%s|r (%s): the client says %d of %d training "
					.. "points are spent."], creature.name or creature.family or key,
					key, creature.spent or 0, creature.total)

				for _, ability in ipairs(creature.abilities) do
					Family:Print("    %s %s   %s   |cff888888%s|r",
						tostring(ability.name or ability.id),
						tostring(ability.rank or ""),
						ability.points and tostring(ability.points) or "|cff888888-|r",
						tostring(ability.id or "-"))

					-- What the window holds under the same word, where the ids did not
					-- meet. Numbers and the client's own words only, so there is no
					-- sentence here to translate and nothing to read as a claim: it is
					-- the working, put in front of somebody who can act on it.
					for _, row in ipairs(ability.near or {}) do
						Family:Print("      |cff888888%s   %s   %s   %s|r",
							tostring(row.rank or "-"),
							tostring(row.spellID or "-"),
							tostring(row.trainingPoints or "-"),
							tostring(row.petLevel or "-"))
					end
				end

				Family:Print(L["  %d priced, %d with no price in the trainer's window, %d "
					.. "the client would not name - and the priced ones come to "
					.. "|cffffd700%d|r."],
					#creature.abilities - creature.unpriced - creature.nameless,
					creature.unpriced, creature.nameless, creature.counted)
			end
		end
	end

	if found == 0 then
		Family:Print(L["no creature with training points is recorded yet - summon a pet on a "
			.. "client that has them, open Beast Training, and look again."])
	end
end)

-- What a Wide Family exchange costs, in milliseconds, on the client complaining about it.
--
-- Reported from play by somebody with two accounts and eighty characters between them: the game
-- stops for a moment at every login while Wide Family is on. The shape of the answer is not a
-- guess - an exchange builds every granted member's offering, which decodes that member's whole
-- record, and then folds the built table byte by byte to see whether it has changed - but how
-- much it costs depends on how many members and how big their records are, and only their client
-- can say that.
--
-- So this measures the three things separately rather than reporting one number: what building
-- the offering costs, what fingerprinting it costs, and what the cheap answer to the same
-- question would cost - the mark of the record as it sits on disk, which the login walk already
-- uses and which needs no decoding at all. Two of those are what a login pays today and the third
-- is what it could pay instead.
--
-- Nothing is sent. The offering is built and thrown away, which is worth saying to anybody being
-- asked to type a diagnostic into a game.
-- **What the client's spellbook says, row by row, and what Family takes from it.**
--
-- Written after three rounds of pasting macros into a chat box that cuts them off at the top.
-- Everything here is asked of the **client**, not of the record: what is in doubt is which tabs
-- Family reads, what kind the client calls each row, and what a flyout gives up when it is
-- opened. The record is downstream of all three and cannot answer for any of them.
--
-- Only the rows Family would keep are listed, because those are the ones an answer is wanted
-- about; the ones passed over are counted instead, which is the same shape `/family pettp` uses.
add("spellbook", L["what the client's spellbook says, and what Family takes from it"], function()
	local tabs = tonumber((Family:TryCall(GetNumSpellTabs))) or 0
	if tabs == 0 then
		Family:Print(L["This client has no spellbook that Family can read."])
		return
	end

	for tab = 1, tabs do
		local name, _, offset, count, _, offSpec = Family:TryCall(GetSpellTabInfo, tab)
		offset, count = tonumber(offset) or 0, tonumber(count) or 0
		local slotsOf = 0

		if type(offSpec) == "number" and offSpec > 0 then
			Family:Print(L["|cffffd700%s|r: %d row(s), and it is specialisation %d's own "
				.. "list - not read."], tostring(name), count, offSpec)
		else
			local passed, kinds = 0, {}

			Family:Print(L["|cffffd700%s|r: %d row(s), read."], tostring(name), count)

			for position = offset + 1, offset + count do
				local kind, id =
					Family:TryCall(GetSpellBookItemInfo, position, "spell")

				if kind == "SPELL" then
					Family:Print("    %s   |cff888888%s|r",
						tostring(Family:TryCall(GetSpellBookItemName, position,
							"spell") or "?"), tostring(id))
				elseif kind == "FLYOUT" then
					-- The one row that stands for spells rather than being one, and
					-- the reason Call Pet went missing. Its slots are printed with
					-- what each says about itself, because that is what decides
					-- whether Family keeps it.
					local word, _, slots = Family:TryCall(GetFlyoutInfo, id)
					slotsOf = tonumber(slots) or 0
					Family:Print(L["    flyout |cff888888%s|r %s, %s slot(s)"],
						tostring(id), tostring(word or "?"),
						tostring(slots or "?"))

					for slot = 1, slotsOf do
						local spellID, _, known =
							Family:TryCall(GetFlyoutSlotInfo, id, slot)
						Family:Print("        %s   |cff888888%s   %s|r",
							tostring(spellID
								and Family:TryCall(GetSpellInfo, spellID)
								or "?"),
							tostring(spellID), tostring(known))
					end
				else
					passed = passed + 1
					kinds[tostring(kind)] = (kinds[tostring(kind)] or 0) + 1
				end
			end

			if passed > 0 then
				local said = {}
				for word, howMany in pairs(kinds) do
					said[#said + 1] = string.format("%s %d", word, howMany)
				end
				table.sort(said)
				Family:Print(L["    and %d row(s) passed over: %s"], passed,
					table.concat(said, ", "))
			end
		end
	end
end)

-- **What the client can say about binding**, which the worth arithmetic needs and does not have.
--
-- Reported 2026-09-11: an item's auction price is a price for the **unbound** version of it. A
-- bind-on-equip sword in a bag can be sold there; the identical one on somebody's back cannot,
-- and Family was valuing both at the auction price. Two of the same sword on one character, one
-- worn, are ten gold and half a gold.
--
-- Three questions and only one of them is per-instance, which is why this prints before anything
-- is built: what the game's own binding words are on this client, what `GetItemInfo` says about
-- the **kind** - and **which of its returns carries that**, which is not written down anywhere in
-- this repository and is not going to be guessed - and what the tooltip says about the instance.
add("bind", L["what this client can say about what is bound: /family bind"], function()
	for _, name in ipairs { "ITEM_SOULBOUND", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_PICKUP",
		"ITEM_BIND_ON_USE", "ITEM_ACCOUNTBOUND", "ITEM_BIND_QUEST" } do
		Family:Print("    %-22s |cff888888%s|r", name, tostring(rawget(_G, name)))
	end

	for _, name in ipairs { "C_Item", "C_Container" } do
		Family:Print("    %-22s |cff888888%s|r", name, type(rawget(_G, name)))
	end
	Family:Print("    %-22s |cff888888%s|r", "C_Item.IsBound",
		_G.C_Item and type(C_Item.IsBound) or "-")

	-- **What is worn**, where anything that binds at all already has. Read first because it is
	-- the half this week's change made wrong: gear went into the worth at auction prices.
	local FIRST = _G.INVSLOT_FIRST_EQUIPPED or 1
	local LAST = _G.INVSLOT_LAST_EQUIPPED or 19
	local shown = 0

	for slot = FIRST, LAST do
		local id = Family:TryCall(GetInventoryItemID, "player", slot)
		if id and shown < 6 then
			shown = shown + 1
			Family:Print(L["  worn slot %d, item %d: |cffffd700%s|r"], slot, id,
				tostring(Family:BindingWorn(slot)))
		end
	end

	-- **And what is carried.** The interesting rows are the ones the tooltip says something
	-- about, so an ordinary bag of cloth does not fill the chat frame with nothing.
	local said, quiet = 0, 0
	for bag = 0, 4 do
		for slot = 1, 36 do
			local id = Family:TryCall(GetContainerItemID, bag, slot)
				or (_G.C_Container and Family:TryCall(C_Container.GetContainerItemID, bag, slot))

			-- **Including the ones that say nothing**, which the first writing of this left
			-- out - and they are the ones that decide whether a tooltip has to be built for
			-- every slot of every bag. A reading that filters to the interesting rows cannot
			-- answer a question about the boring ones.
			if id and said < 14 then
				local binding = Family:BindingIn(bag, slot)
				if binding or quiet < 4 then
					if not binding then quiet = quiet + 1 end
					said = said + 1
					local row = Family:ItemInfoRow(id)
					Family:Print(L["  bag %d slot %d, item %d: |cffffd700%s|r"],
						bag, slot, id, tostring(binding))
					-- Every return, numbered. Which position carries the bind type is the
					-- whole point of printing them rather than naming one.
					for index = 9, 15 do
						Family:Print("      %-3d |cff888888%s|r", index,
							tostring(row[index]))
					end
				end
			end
		end
	end

	if said == 0 then
		Family:Print(L["  nothing in the bags said anything about binding"])
	end
end)

-- **What the profession button was holding when it was clicked.**
--
-- Backlog 61. The word is right - Alberto's own probe answered `165 75 Leatherworking` - and
-- casting that word by hand opens the window, so the fault is in the button. Which of the three
-- ways it can fail cannot be told apart from outside the click: arming refuses in silence, an
-- attribute that did not take reads back nil, and a template that never applied leaves no mark.
--
-- One click, told once, and nothing decided here: the values are printed and the reading is
-- Alberto's, because the repair depends on which of them is the odd one.
add("openwith", L["what a profession button is holding when you click it"], function()
	UI:TellNextProfessionClick(function(seen)
		for _, pair in ipairs(seen or {}) do
			Family:Print("    %-12s |cff888888%s|r", pair[1], pair[2])
		end
	end)

	Family:Print(L["click a profession on the professions page: the next click will say what its button held"])
end)

-- **Whose is that?**
--
-- Asked 2026-09-12, about a bar of item buttons built by alt-clicking worn armour: it outlives
-- the character sheet, it can be dragged around the screen, and an item with an on-use makes a
-- button you can put where you want it. Good enough to want to know who wrote it.
--
-- A frame is the one thing on screen that can be asked. Almost every addon names its frames after
-- itself, and where a frame is anonymous its parent usually is not - so the chain upward is the
-- answer, and the client gives it. Five seconds because the pointer has to be somewhere else to
-- type this, and pointing at a thing is the whole of what it asks of anybody.
--
-- Nothing is sent, nothing is changed, nothing is stored. It reads names.
add("whatis", L["name the frame the pointer is resting on, five seconds from now"], function()
	Family:Print(L["point at it and wait five seconds"])

	Family:After(5, "ui.whatis", function()
		local frame = (Family:TryCall(GetMouseFocus))

		if type(frame) ~= "table" then
			Family:Print(L["  the client named nothing under the pointer"])
			return
		end

		-- Up the chain rather than the one frame, and no further than eight: an anonymous
		-- button in an anonymous row usually hangs off something with its author's name on
		-- it, and it is that name the question is really about.
		for depth = 0, 8 do
			if type(frame) ~= "table" then break end

			Family:Print("    %-2d %-28s |cff888888%s|r", depth,
				tostring((Family:TryCall(frame.GetName, frame))),
				tostring((Family:TryCall(frame.GetObjectType, frame))))

			frame = (Family:TryCall(frame.GetParent, frame))
		end
	end)
end)

-- **What a modified click on an item is, on this client.**
--
-- Alberto's idea, for a possessions list too long to draw whole: hold a modifier, click the item,
-- and Family opens at it. `/family caps` says the crossroads exists on Mists; whether it fires
-- from a **bag slot**, what it hands over and which modifiers reach it are three more questions,
-- and nothing is built until they have been answered on all three clients.
--
-- One click, told once, and nothing decided here - the values are printed and the reading is
-- Alberto's, the same arrangement `/family openwith` uses.
add("itemclick", L["what a modified click on an item hands over"], function()
	if type(_G.HandleModifiedItemClick) ~= "function" then
		Family:Print(L["this client has no crossroads for a modified click on an item"])
		return
	end

	UI:TellNextItemClick(function(seen)
		for _, pair in ipairs(seen or {}) do
			Family:Print("    %-10s |cff888888%s|r", pair[1], pair[2])
		end
	end)

	-- **How many have gone past already**, which is what tells *the hook is not called from a
	-- bag* apart from *the hook was never installed*. Both arrive as silence otherwise.
	-- **What this client has already spoken for.** The Dressing Room takes CTRL and a click,
	-- and holding ALT as well does not stop it - measured from play on Mists 2026-09-12, with
	-- the game's own window saying so. Which combination is free is the client's to answer, not
	-- ours to pick: this is the same list its key bindings screen draws.
	for _, pair in ipairs(UI:ModifiedClickActions()) do
		Family:Print("    %-22s |cff888888%s|r", pair[1], pair[2])
	end

	Family:Print(L["  modified clicks heard since login: |cffffd700%d|r"], UI:ItemClicksSeen())
	Family:Print(L["hold your modifiers and click an item: the next one will say what it held"])
end)

-- **One page, replayed from the client's own query, and one at a time.**
--
-- Two versions of this stood here and both were wrong. The first alternated between two guessed
-- argument layouts, which made *try the other one* the natural response to silence (L-070). The
-- second let those layouts be named, which is better and still a guess - and one of them put the
-- page where `getAll` lives, where `0` is not a page but **true**.
--
-- Nothing is guessed now. `/family ah watch` records what the auction house asks for, and this
-- sends that same call with the page changed. If nothing has been watched, nothing is sent.
local inFlight = nil

local function askOnce(page)
	if inFlight and (time() - inFlight) < 60 then
		Family:Print(L["a query sent %d second(s) ago has not answered yet - nothing more is sent"],
			time() - inFlight)
		return
	end

	local function report()
		local onPage, inAll = Family.Auctions:ListTotals()
		Family:Print(L["  the browse list holds %s row(s), of %s on sale in all"],
			tostring(onPage), tostring(inAll))

		-- Printed rather than counted: a query that came back is not a query that came back
		-- with the right thing, and the rows are what say which it was.
		for _, row in ipairs(Family.Auctions:OldListSample(3) or {}) do
			Family:Print("    %-3s %-8s x%-5s |cff888888%s|r",
				tostring(row[1]), tostring(row[2]), tostring(row[3]), tostring(row[4]))
		end
	end

	local answered = false
	Family.Auctions:TellNextList(function()
		answered = true
		inFlight = nil
		report()
	end)

	Family:Print(L["  asking for page %d, the client's own query with the page changed"], page)

	inFlight = time()

	local ok, err = Family.Auctions:ReplayQuery(page)
	if not ok then
		inFlight = nil
		Family.Auctions:TellNextList(nil)
		Family:Print(L["  refused: %s"], tostring(err))
		return
	end

	Family:After(30, "auctions.probe", function()
		if answered then return end
		Family.Auctions:TellNextList(nil)
		Family:Print(L["  nothing answered within %d seconds"], 30)
	end)
end

-- **Asking the newer auction house for its whole list, once.**
--
-- Entry 55 slice 3. Mists has no pages to walk - `AUCTION_ITEM_LIST_UPDATE` never fires there and
-- the browse panel does not exist - but it has a call that asks the server for every listing at
-- once. Whether that call answers, how much of it arrives, in how many pieces, whether the rows
-- are numbered from nought or from one, and what the throttle does are five things nothing in
-- this repository knows.
--
-- It is the same family of call as the one that crawled a live client for minutes, so it is sent
-- **once**, by a word nobody types by accident, and it is locked while it is in the air. A probe
-- that offers a second try is a probe that will be tried twice (L-070), and this is the one place
-- in the addon where that costs somebody their evening.
local replicating = nil

local function replicateOnce()
	if not Family.Auctions:CanReplicate() then
		Family:Print(L["this build has no whole-list read on the auction house"])
		return
	end

	if replicating and (time() - replicating) < 60 then
		Family:Print(L["a query sent %d second(s) ago has not answered yet - nothing more is sent"],
			time() - replicating)
		return
	end

	-- Read before, so that *the throttle was not ready* and *the call did nothing* stop being
	-- the same silence.
	Family:Print(L["  the throttled message system is ready: |cffffd700%s|r"],
		tostring(Family.Auctions:ThrottleReady()))
	Family:Print(L["  it holds %s replicated row(s) before asking"],
		tostring(Family.Auctions:ReplicateCount()))

	local answered = false

	Family.Auctions:TellNextReplicate(function()
		answered = true
		replicating = nil

		Family:Print(L["  it holds %s replicated row(s) now, after %d answer(s)"],
			tostring(Family.Auctions:ReplicateCount()),
			Family.Auctions:ReplicateHeard())

		-- **Printed by position, never by name.** Which return holds what is the whole of
		-- what is being asked, and nought is among the indices because whether this list
		-- starts there is one of the unknowns.
		for _, row in ipairs(Family.Auctions:ReplicateSample { 0, 1 }) do
			Family:Print("    %-3s |cff888888%s|r", tostring(row.index), tostring(row.n))
			for position, value in ipairs(row.values) do
				Family:Print("      %-3s |cff888888%s|r", position, value)
			end
		end

		-- **And which of those positions is which**, worked out rather than read off the
		-- shape of the numbers. The player's own auctions are readable through a route that
		-- answers **named** fields, and those same auctions are in this list - so a row
		-- carrying all three of an auction's values says where each of them lives. The
		-- client describing one auction twice, and the map falling out of the difference.
		Family:Print(L["  looking for your own auctions in the replicated list:"])

		local map = Family.Auctions:ReplicateMatchOwned()
		Family:Print("    %-14s |cff888888%s / %s / %s|r", "owned/stacks/scanned",
			tostring(map.owned), tostring(map.stacks), tostring(map.scanned))

		for _, match in ipairs(map.matches) do
			for _, field in ipairs(match.at) do
				Family:Print("      %-14s |cff888888%s = %s|r",
					field[1], tostring(field[2]), tostring(field[3]))
			end
		end
	end)

	replicating = time()

	local ok, err = Family.Auctions:AskReplicate()
	if not ok then
		replicating = nil
		Family.Auctions:TellNextReplicate(nil)
		Family:Print(L["  refused: %s"], tostring(err))
		return
	end

	Family:Print(L["  asked for the whole list once - nothing else will be sent"])

	Family:After(30, "auctions.replicate.probe", function()
		if answered then return end
		replicating = nil
		Family.Auctions:TellNextReplicate(nil)
		Family:Print(L["  nothing answered within %d seconds"], 30)

		-- **And what the client looks like now that it has not answered.** Seen from play on
		-- Mists 2026-09-12: two calls answered forty-three thousand rows each and a third,
		-- minutes later, answered nothing at all. A whole-list read is the kind of thing a
		-- server rations, so the state after the silence is worth as much as the state
		-- before it - a throttle that has closed and a call that did nothing are the same
		-- silence otherwise, which is the shape this whole probe exists to avoid.
		Family:Print(L["  the throttled message system is ready: |cffffd700%s|r"],
			tostring(Family.Auctions:ThrottleReady()))
		Family:Print(L["  it holds %s replicated row(s) before asking"],
			tostring(Family.Auctions:ReplicateCount()))
	end)
end

-- **Reading the whole house, which is what all of the above was for.**
--
-- Off by default and started by a word nobody types by accident. Measured on Burning Crusade
-- 2026-09-11: the house held 180,205 auctions, which at fifty a page is 3,605 pages and the best
-- part of an hour standing at the auctioneer. *Read everything, I will wait* is a thing somebody
-- asks for on purpose, so it takes a second word to start - and one to stop.
-- Why it stopped, in words. The walk answers with a code and the words are here, because a
-- sentence written in the scanner would be an English one wherever it was read (§2.1) - and this
-- is the file the translation gate reads.
local WHY = {
	asked = L["you asked it to stop"],
	closed = L["the auction house was closed"],
	refusing = L["the client went on refusing queries"],
	quiet = L["a page was asked for and never arrived"],
	query = L["the client would not take the query"],
	running = L["a read of the house is already running"],
	-- **What to actually do about it**, rather than the name of the thing that is missing.
	-- Reported from play 2026-09-11: *scan go goes on being refused unless I do watch first*.
	-- `watch` teaches Family nothing - it only prints what it hears. What teaches it is the
	-- player using the auction house: Search gives it a query of the client's own to replay,
	-- and Next gives it a second one differing in the page and nothing else.
	seenNothing = L["press Search on the auction house first - the read replays the client's own query rather than composing one"],
	pageUnknown = L["press Next on the auction house once - two queries differing in one place are what says which argument is the page"],
	newerHouse = L["this build has the newer auction house, which has no pages to walk"],
	olderHouse = L["this build has the older auction house, which is read a page at a time"],
	emptyList = L["the client answered no rows at all"],
}

-- **How long, in words somebody can act on.**
--
-- This asked the client first, through `SecondsToTime`, on the grounds that its answer is
-- already in the player's language (§2.5). Read back from play on Burning Crusade 2026-09-11,
-- that answer arrives as **`49 |4Sec:Secs;`** - the game's plural escape, unresolved, printed
-- raw into the chat frame. The call is real and its answer is a template somebody else's
-- renderer finishes, so asking it was right and using what came back was not.
--
-- So Family says it in its own words, which are translated in this repository and arrive whole.
local function spanOf(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))

	if seconds < 60 then return string.format(L["%d second(s)"], seconds) end
	return string.format(L["%d minute(s)"], math.floor(seconds / 60 + 0.5))
end

-- **Started from two places**: this command, and the button on the auction window itself
-- (Auctions.lua). The words live here whichever pressed it, because this is the file the
-- translation gate reads and a sentence written anywhere else would be an English one wherever
-- it was read (§2.1).
function UI:StopHouseRead()
	if Family.Auctions:StopReplicateRead("asked") then return true end
	if Family.Auctions:StopWalk("asked") then return true end
	Family:Print(L["nothing is being read"])
	return false
end

-- **The newer house, read whole.** Not a walk: it answers its entire list to one call, so there
-- are no pages and nothing to pace towards the server. What there is instead is forty-three
-- thousand rows to go through without the client stopping answering its keyboard, which is why
-- this reports its way along rather than finishing in a frame.
local function startReplicateRead()
	local shown = 0

	local ok, why = Family.Auctions:StartReplicateRead(function(what, state, reason)
		if what == "some" then
			-- Every so often rather than every slice: eighty-six lines is not progress.
			if state.done - shown >= 5000 or state.done >= state.rows then
				shown = state.done
				Family:Print(L["  %d of %d row(s) read, %d price(s) taken"],
					state.done, state.rows or 0, state.kept or 0)
			end
			return
		end

		if what == "finished" then
			Family:Print(L["read the whole house: %d row(s) in %s, %d price(s) taken, %d known here"],
				state.done or 0,
				spanOf(Family.Auctions:WalkSeconds(state) or 0),
				state.kept or 0, Family.Auctions:PriceCount())
			if UI.HouseReadChanged then UI:HouseReadChanged() end
			return
		end

		Family:Print(L["stopped after %d page(s) in %s: %s"], state.done or 0,
			spanOf(Family.Auctions:WalkSeconds(state) or 0),
			WHY[reason] or tostring(reason))
		if UI.HouseReadChanged then UI:HouseReadChanged() end
	end)

	if not ok then Family:Print(L["  refused: %s"], WHY[why] or tostring(why)) end
	if UI.HouseReadChanged then UI:HouseReadChanged() end
	return ok, why
end

function UI:StartHouseRead(everything)
	if Family.Auctions:Walking() or Family.Auctions:ReplicateReading() then
		Family:Print(L["%s - /family ah scan stop ends it"], WHY.running)
		return false, "running"
	end

	-- **Which house this is decides how it is read**, by the call being there and never by a
	-- build number (§2.3). The newer one hands its whole list over at once; the older one is
	-- walked a page at a time because a page is what it offers.
	if Family.Auctions:CanReplicate() then return startReplicateRead() end

	local ok, why = Family.Auctions:StartWalk(function(what, state, reason)
		if what == "page" then
			-- Said every so often rather than every page: three and a half thousand lines
			-- is not progress, it is a chat frame nobody can use while it happens.
			if state.pages and (state.done == 1 or state.done % 25 == 0) then
				-- **Taken first, then the clock.** *Taken* is what these pages actually
				-- gave up, and it is the figure that says whether the walk is moving at
				-- all - *known here* barely moves on a realm somebody has browsed, so it
				-- is kept for the end rather than repeated every twenty-five pages.
				--
				-- **And how long is left, measured rather than guessed**: the pages read
				-- so far took as long as they took, and the ones to come are the same
				-- pages off the same server. Asked for from play - *how long will it
				-- take?* - which nothing could answer while the walk timed itself and
				-- told nobody.
				local gone = Family.Auctions:WalkSeconds(state) or 0
				local left = state.done > 0
					and gone / state.done * (state.pages - state.done) or 0

				Family:Print(L["  page %d of %d, %d price(s) taken - %s gone, about %s to go"],
					state.done, state.pages, state.kept or 0,
					spanOf(gone), spanOf(left))
			end
			return
		end

		if what == "finished" then
			local took = Family.Auctions:WalkSeconds(state) or 0

			-- **What it read, which is not always the house.** A walk replays the
			-- client's last query with the page changed, so a player who had searched
			-- *Recipe* was walked through the recipes and told the whole house had been
			-- read. Reported from play 2026-09-11: sixty-eight pages, on a house this
			-- repository measured at 3,605 the week it was written. Nothing can look at a
			-- query and tell a blank one from a narrow one - so this says whichever it
			-- was told, and it is told only by whoever cleared the form.
			Family:Print(state.everything
					and L["read the whole house: %d page(s) in %s, %d price(s) taken, %d known here"]
					or L["read every page of that search: %d page(s) in %s, %d price(s) taken, %d known here"],
				state.done or 0, spanOf(took), state.kept or 0,
				Family.Auctions:PriceCount())

			-- **Where that time actually went**, which is the only way to answer whether a
			-- read could be made faster. Asked from play: other addons scan without drawing
			-- the window - is that quicker? Waiting is the server's half and cannot be
			-- argued with; the rest is Family's own pacing between pages, and that is a
			-- decision rather than a fact.
			-- **Three parts, because the first writing of this had two and the second
			-- was a lie.** Read back from play on Classic Era 2026-09-12: *1 minute
			-- waiting for the server, 4 minutes of Family's own pacing* on 394 pages,
			-- where the settle at a tenth of a second accounts for forty seconds. The
			-- other three minutes were the client refusing to send - the server's own
			-- throttle, arriving as `CanSendAuctionQuery` saying no and being waited out
			-- half a second at a time. Calling the remainder *ours* put somebody else's
			-- limit under our name and pointed the only tuning decision at the wrong knob.
			local waited = Family.Auctions:WalkWaiting(state)
			local held = Family.Auctions:WalkHeld(state) or 0
			if waited then
				Family:Print(L["  %s waiting for the server, %s while it would not send, %s of Family's own pacing"],
					spanOf(waited), spanOf(held),
					spanOf(math.max(0, took - waited - held)))
			end

			if UI.HouseReadChanged then UI:HouseReadChanged() end
			return
		end

		-- Everything already taken is kept. A half-read house is a lot of prices.
		Family:Print(L["stopped after %d page(s) in %s: %s"], state.done or 0,
			spanOf(Family.Auctions:WalkSeconds(state) or 0),
			WHY[reason] or tostring(reason))

		if UI.HouseReadChanged then UI:HouseReadChanged() end
	end, everything)

	if not ok then Family:Print(L["  refused: %s"], WHY[why] or tostring(why)) end

	-- **Whatever happened, whoever is showing it says so again.** A read that ends between
	-- one list update and the next leaves nothing to redraw on, which is how a button went on
	-- reading *Stop* after the read had finished - and then started a new one when it was
	-- pressed. Reported from play 2026-09-12.
	if UI.HouseReadChanged then UI:HouseReadChanged() end
	return ok, why
end

local function scan(word)
	if word == "stop" then return UI:StopHouseRead() end

	if word ~= "go" then
		if Family.Auctions:Walking() then
			Family:Print(L["%s - /family ah scan stop ends it"], WHY.running)
		else
			Family:Print(L["this walks every page of the search the auction house last made and takes a long time: /family ah scan go"])
		end
		return
	end

	UI:StartHouseRead()
end

-- **Watching the client ask, which should have been the first thing tried.**
--
-- The auction house calls `QueryAuctionItems` itself every time Search is pressed, with the
-- arguments that are right for that build. Hooked, it costs no traffic and cannot get anybody
-- disconnected; two queries of our own, one of which said `getAll = true` by accident, are what
-- it took to go and look for this.
local function watchOne()
	Family.Auctions:TellNextQuery(function(args, count)
		Family:Print(L["  the client asked with %d argument(s):"], count or 0)
		for index = 1, (count or 0) do
			Family:Print("    %-3s |cff888888%s|r", index, tostring(args[index]))
		end

		local at = Family.Auctions:PagePosition()
		if at then
			Family:Print(L["  and the page is argument %d, from two of its own queries"], at)
		else
			Family:Print(L["  press Next as well: two queries differing in one place say which argument is the page"])
		end
	end)

	-- **And the newer house's own query, where that is the house there is.** The old hook can
	-- never fire on that build, so arming only it would leave a probe silent forever - which
	-- reads as a broken probe rather than as a different auction house.
	if _G.C_AuctionHouse and type(C_AuctionHouse.SendBrowseQuery) == "function" then
		Family:Print(L["this build has the newer auction house, which has no pages to walk"])

		Family.Auctions:TellNextBrowse(function(rows)
			Family:Print(L["  the client browsed with %d field(s):"], #rows)
			for _, pair in ipairs(rows) do
				Family:Print("    %-22s |cff888888%s|r", pair[1], pair[2])
			end
		end)
	end

	Family:Print(L["press Search on the auction house: the next query the client sends will be printed"])
end

-- **What this client offers on the auction house, and what it answers.**
--
-- Family reads the browse list and sends no query at all, which needs nothing from this. What
-- needs it is the thing after: a full read of everything on sale, which is the one feature in
-- this addon that could get somebody disconnected, and whose calls have never been touched
-- anywhere in this repository - so nothing is built on them until this has been run on all
-- three clients and the answers written down (§2.3, and the reason `/family spellbook` exists).
--
-- Symbols are reported as present or absent rather than called, except the one whose whole
-- purpose is to be asked - `CanSendAuctionQuery` says whether a query would be accepted right
-- now, and that answer is the difference between a scanner that is safe and one that is not.
add("ah", L["what this client offers on the auction house"], function(argument)
	if argument == "watch" then return watchOne() end

	if argument == "replicate" then return replicateOnce() end

	local scanning = type(argument) == "string" and argument:match("^scan%s*(%a*)$")
	if scanning then return scan(scanning) end

	local asked = type(argument) == "string" and argument:match("^query%s*(%d*)$")
	if asked then return askOnce(tonumber(asked) or 0) end

	for _, name in ipairs {
		"GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink",
		"QueryAuctionItems", "CanSendAuctionQuery", "SortAuctionItems",
		"GetAuctionItemSubClasses", "GetSelectedAuctionItem",
	} do
		Family:Print("    %-26s |cff888888%s|r", name, type(_G[name]))
	end

	-- **And what the auction window's own controls are called.**
	--
	-- Asked for from play 2026-09-11: *what if we put a button in the auction house window, the
	-- way other addons do?* The answer to *why is the read refused* is that Family replays the
	-- client's own query and has not heard one - and a button that presses the window's own
	-- Search, and then its own Next, would give it both without Family composing anything. That
	-- is the same shape as the profession button, which asks the client to open its own window
	-- rather than reaching inside it.
	--
	-- Which is buildable only once these are known to be there, under these names, on each of
	-- the three clients - a frame that is not there answers nil and a button under another name
	-- answers nil in exactly the same way (§2.3).
	for _, name in ipairs {
		"AuctionFrame", "AuctionFrameBrowse", "BrowseSearchButton",
		"BrowseNextPageButton", "BrowsePrevPageButton", "BrowseResetButton",
		"AuctionFrameBrowse_Search", "AuctionFrameBrowse_OnEvent",
	} do
		Family:Print("    %-26s |cff888888%s|r", name, type(_G[name]))
	end

	-- **And Family's own button on that window, which was reported missing.**
	--
	-- Two faults look identical from the player's chair - a build without it, and one where it
	-- was drawn somewhere nothing can be seen - and this line tells them apart: absent says the
	-- first, a size and a corner says the second.
	-- Which window the newer house draws, which nothing here had ever asked. The button hangs
	-- off it, so a name that is not there and a name spelled wrong have to stop reading alike.
	local _, found = UI.__modernAuctionWindow and UI.__modernAuctionWindow()
	Family:Print("    %-26s |cff888888%s|r", "AuctionHouseFrame", tostring(found))

	local ours = _G.FamilyReadHouseButton
	if type(ours) == "table" then
		-- Composed rather than written into the format, because the format is a sentence
		-- the moment it carries an English word and this file is where those are caught.
		local point, _, _, x, y = Family:TryCall(ours.GetPoint, ours, 1)
		Family:Print("    %-26s |cff888888%s|r", "FamilyReadHouseButton", table.concat({
			tostring((Family:TryCall(ours.GetWidth, ours))),
			tostring((Family:TryCall(ours.GetHeight, ours))),
			tostring(point), tostring(x), tostring(y),
			tostring((Family:TryCall(ours.IsVisible, ours))),
		}, " / "))
	else
		Family:Print("    %-26s |cff888888%s|r", "FamilyReadHouseButton", type(ours))
	end

	-- **Asked here because this is where somebody lands when the prices are not showing.**
	--
	-- The switch ships off, and `FamilyDB` is one file per game version - so turning it on for
	-- Burning Crusade turns on nothing for Era, and the first report of it was exactly that:
	-- prices remembered and none drawn.
	Family:Print(L["  prices on tooltips are switched: |cffffd700%s|r"],
		FamilyDB.prices and L["on"] or L["off"])

	local askable = Family:TryCall(CanSendAuctionQuery)
	Family:Print(L["  a query would be accepted now: |cffffd700%s|r"], tostring(askable))

	-- All three lists rather than the one Family reads, because *nought on the browse list* and
	-- *nought everywhere* are different faults and only one of them is about the selector.
	for _, which in ipairs { "list", "bidder", "owner" } do
		Family:Print("    %-8s |cff888888%s|r", which,
			tostring((Family:TryCall(GetNumAuctionItems, which))))
	end

	-- **Both returns of it**, because the second is the one a page walk needs and nothing in
	-- this repository has ever read it: fifty rows is one page, and how many pages there are
	-- is the total divided by that.
	local onPage, inAll = Family.Auctions:ListTotals()
	Family:Print(L["  the browse list holds %s row(s), of %s on sale in all"],
		tostring(onPage), tostring(inAll))

	-- Whether the event ever arrives is the first of the three things that could be wrong, and
	-- it is the one no amount of looking at the list can answer.
	local fired, lastRows = Family.Auctions:ReadingsSeen()
	Family:Print(L["  list updates heard since login: |cffffd700%d|r, last one showed %s"],
		fired, tostring(lastRows))

	-- And whether this build has the newer auction house at all, which would put what the player
	-- is looking at somewhere the calls above cannot see.
	local modern = {}
	for _, name in ipairs { "GetBrowseResults", "SearchForFavorites", "GetNumReplicateItems",
		"QueryOwnedAuctions", "SendBrowseQuery" } do
		if C_AuctionHouse and type(C_AuctionHouse[name]) == "function" then
			modern[#modern + 1] = name
		end
	end
	Family:Print(L["  newer auction house: |cffffd700%s|r"],
		#modern > 0 and table.concat(modern, ", ") or tostring(C_AuctionHouse ~= nil))

	-- **And how the newer house is paged**, which is a different question from whether it is
	-- there. One search answered five hundred rows on Mists and a house has more than five
	-- hundred things in it, so something has to say whether that was all of them.
	local paging = {}
	for _, name in ipairs { "HasFullBrowseResults", "RequestMoreBrowseResults",
		"ReplicateItems", "GetReplicateItemInfo", "GetReplicateItemLink",
		"IsThrottledMessageSystemReady" } do
		if C_AuctionHouse and type(C_AuctionHouse[name]) == "function" then
			paging[#paging + 1] = name
		end
	end
	Family:Print(L["  paging the newer house: |cffffd700%s|r"],
		#paging > 0 and table.concat(paging, ", ") or "-")

	if #modern > 0 then
		local browse, owned = Family.Auctions:ModernCounts()
		Family:Print(L["  it is holding %s browse result(s) and %s of your own auctions"],
			tostring(browse), tostring(owned))

		local events, heard = Family.Auctions:ModernEvents()
		for _, event in ipairs(events) do
			Family:Print("    %-38s |cff888888%d|r", event, heard[event] or 0)
		end

		-- The shape of one row, printed rather than assumed. Field names are the thing
		-- that has gone wrong twice today, and the client is sitting right here.
		for _, pair in ipairs(Family.Auctions:ModernSample() or {}) do
			Family:Print("    %-24s |cff888888%s|r", pair[1], pair[2])
		end

		-- And one of this character's own, which is backlog 56 rather than the prices.
		local calls, owned = Family.Auctions:ModernOwnedSample()
		-- The client's own symbol names, with nothing of ours beside them. The gate that
		-- caught the first version of this line was right: *owner calls* is English, and a
		-- label is a sentence however short it is.
		Family:Print("    |cff888888%s|r",
			#(calls or {}) > 0 and table.concat(calls, ", ") or "-")
		for _, pair in ipairs(owned or {}) do
			Family:Print("      %-22s |cff888888%s|r", pair[1], pair[2])
		end
	end

	-- The older house's own listings, where there are any. Whether that buyout is the stack
	-- or one of them has never been read, and everything on Era and Burning Crusade rests on
	-- it - the browse prices divide by the quantity.
	for _, pair in ipairs(Family.Auctions:OldOwnedSample() or {}) do
		Family:Print("    %-24s |cff888888%s|r", pair[1], pair[2])
	end

	-- **Which house this is**, which nothing here has ever asked and which decides whether a
	-- price crosses the faction line.
	--
	-- Alberto, 2026-09-11: the neutral auction house is shared by both sides of one realm, so a
	-- price read there applies to a Horde character on that realm as well - and only there. A
	-- price read at an Alliance house says nothing about what Horde pays. Family files every
	-- reading under *realm and the reader's faction*, so a neutral reading is filed as though it
	-- were one side's, and the other side's characters fall back on what a vendor pays. That is
	-- what makes four units of leather on a Horde alt read *at vendor prices* beside thirty-nine
	-- at market on the same realm.
	--
	-- So the question is whether the client will say the auctioneer is neutral. These are
	-- candidates, none of them confirmed anywhere in this repository, and the answer is what
	-- they print rather than what they are called. Meaningful only with the window open.
	--
	-- Read on all three clients 2026-09-11, each at a friendly auctioneer. Burning Crusade and
	-- Mists answer the same thing under both names - *Auctioneer Lympkin / Alliance / true*,
	-- *Auctioneer Chilton / Alliance / true*. Classic Era answers under `target` alone and says
	-- **nothing at all** for `npc`. So whichever of these turns out to carry the faction,
	-- `target` is the one every client has.
	--
	-- And none of the three settles the question, because all three auctioneers were one side's.
	-- What is still wanted is this same line read standing at a **goblin** auctioneer, which is
	-- the only place the answer can differ.
	for _, name in ipairs { "npc", "target" } do
		Family:Print("    %-10s |cff888888%s / %s / %s|r", name,
			tostring((Family:TryCall(UnitName, name))),
			tostring((Family:TryCall(UnitFactionGroup, name))),
			tostring((Family:TryCall(UnitIsFriend, "player", name))))
	end

	for _, name in ipairs { "GetAuctionHouseDepositRate", "GetAuctionDeposit",
		"C_AuctionHouse.GetAuctionHouseDepositRate" } do
		local fn = rawget(_G, name)
		if not fn and _G.C_AuctionHouse then
			fn = C_AuctionHouse[(name:gsub("^C_AuctionHouse%.", ""))]
		end
		Family:Print("    %-38s |cff888888%s|r", name, type(fn))
	end

	local prices, oldest, newest, held = Family.Auctions:Prices(), nil, nil, 0
	for _, row in pairs(prices) do
		if type(row) == "table" and row.at then
			held = held + 1
			if not oldest or row.at < oldest then oldest = row.at end
			if not newest or row.at > newest then newest = row.at end
		end
	end

	Family:Print(L["  prices remembered for this realm and side: |cffffd700%d|r"], held)
	if held > 0 then
		Family:Print(L["  oldest %s, newest %s"], UI:Ago(oldest), UI:Ago(newest))
	end
end)

add("widetime", L["how long a Wide Family exchange takes on this client"], function()
	if not Family.Wide:Enabled() then
		Family:Print(L["Wide Family is switched off, so there is nothing to time."])
		return
	end

	-- `debugprofilestop` is the client's own millisecond clock and is what this wants; a
	-- client without it is timed by the frame clock instead, which is coarser and still says
	-- whether the answer is two milliseconds or two thousand.
	local clock = _G.debugprofilestop
	local function now()
		if clock then return (Family:TryCall(clock)) or 0 end
		return ((Family:TryCall(GetTime)) or 0) * 1000
	end

	local links = 0

	for familyID, link in pairs(Family.Wide:Links()) do
		links = links + 1

		local at = now()
		local members = Family.Wide:Offering(link)
		local building = now() - at

		local count, folding = 0, 0
		at = now()
		for _, entry in pairs(members) do
			count = count + 1
			Family.Codec:Fingerprint(entry)
		end
		folding = now() - at

		at = now()
		for memberKey in pairs(link.grants or {}) do
			Family.Database:PayloadMark(memberKey)
		end
		local marking = now() - at

		at = now()
		local total, held = Family.Wide:MarkCost(link)
		local deciding = now() - at

		-- **What it costs now, first and in plain words.**
		--
		-- The three timings above are the old road, walked on purpose so that there is
		-- something to compare against - and printing them first was a mistake that
		-- misled the first two people who read the output, one of them the author of the
		-- addon. A diagnostic that has to be explained is not one.
		Family:Print(L["|cffffd700%s|r: %d members. Now: marking %d ms, %d of %d "
			.. "unchanged, and an unchanged member is never opened."],
			Family.Wide:Called(link) or familyID, count, deciding, held, total)

		Family:Print(L["  |cff888888What it used to cost, for comparison: building %d ms, "
			.. "fingerprinting %d ms.|r"], building, folding)
	end

	if links == 0 then
		Family:Print(L["no links, so there is nothing to time."])
		return
	end

	Family:Print(L["|cff888888Nothing was sent, and nobody had to be online.|r"])
end)

-- Diagnostic rather than a feature. Working out which shape of the talent call a build wants
-- has needed a round trip through a real client every single time, and this is what makes
-- that one round trip instead of five.
add("talentprobe", L["what this client answers when asked about a talent"], function()
	if Family.Capabilities:Has("talentTrees") then
		Family:Print(L["this client uses talent trees; the probe is for the choices clients."])
		return
	end
	Family.Talents:Probe()
end)

add("rescan", L["scan the current member again, now, and say what it found"], function()
	Family:Print(L["scanning %s ..."], Family:CurrentMember())
	local ok, err = pcall(function() Family.Talents:Scan() end)
	if not ok then
		Family:Print(L["|cffff5555talent scan failed|r: %s"], tostring(err))
		return
	end
	local ok2, err2 = pcall(function() Family.Bags:Scan() end)
	if not ok2 then
		Family:Print(L["|cffff5555bag scan failed|r: %s"], tostring(err2))
	end

	-- **And the character itself**, which this command did not do and is named as though it
	-- did. Reported 2026-09-11: a bind-on-equip helm worn by another member was still valued
	-- at what the auction house asks, because whether a worn piece has bound is written by
	-- `Character:ScanNow` and by nothing else - so a record made before that field existed
	-- carries no binding, and the one command whose whole purpose is *scan me again* left the
	-- equipment exactly as it found it.
	local ok3, err3 = pcall(function() Family.Character:Scan() end)
	if not ok3 then
		Family:Print(L["|cffff5555character scan failed|r: %s"], tostring(err3))
	end

	Family.Index:Invalidate()
	UI:Refresh()
	Family:Print(L["done. /family talents to see what landed."])
end)

add("strata", L["how far in front the window sits: MEDIUM, HIGH or DIALOG"], function(argument)
	if not argument or argument == "" then
		Family:Print(L["window strata is |cffffd700%s|r. Choices: %s."], UI:CurrentStrata(),
			table.concat(UI:StrataChoices(), ", "))
		Family:Print(L["Raise it if another addon draws over the window."])
		return
	end

	local applied = UI:SetStrata(argument)
	if applied then
		Family:Print(L["window strata is now |cffffd700%s|r."], applied)
	else
		Family:Print(L["no strata called %s. Choices: %s."], argument,
			table.concat(UI:StrataChoices(), ", "))
	end
end)

add("caps", L["what this client can do, and how Family worked it out"], function()
	Family:Print(L["%s, interface build %s"], Family.Capabilities.name,
		tostring(select(4, GetBuildInfo())))

	-- Green means somebody has looked at this in the game. Amber means it is researched
	-- but unverified, and is where to look first when something seems wrong.
	for _, entry in ipairs(Family.Capabilities:Report()) do
		local mark = entry.answer and L["|cff44dd44yes|r"] or L["|cff888888no |r"]
		local colour = entry.source == "seen in game" and "|cff44dd44" or "|cffffaa00"

		-- A disagreement is information, never a correction. These clients carry symbols
		-- for features they do not have, which is why the table decides and this only
		-- reports.
		local note = ""
		if entry.disagrees then
			note = " |cff8888ff(" .. entry.disagrees .. ")|r"
		end

		Family:Print("  %s  %-16s %s%s|r%s", mark, entry.feature, colour,
			L[entry.source], note)
	end

	-- **Whether a modified click on an item can be caught at all**, asked because Alberto
	-- suggested the tooltip could say *hold CTRL-ALT and click to open Family here*.
	--
	-- Family cannot repaint somebody else's tooltip - the note at the foot of `Tooltip.lua`
	-- measured that as unreliable, and the CTRL worth block only works because the bag addon
	-- re-shows its own tooltip when the modifier changes. A click is a different route and
	-- would not depend on that. `HandleModifiedItemClick` is the client's own crossroads for
	-- one, and whether it is there, and whether it fires from a bag slot on these builds, is
	-- unread - so nothing is built on it until this line has been looked at on all three.
	for _, name in ipairs { "HandleModifiedItemClick", "IsModifiedClick",
		"ChatEdit_InsertLink", "SetItemRef" } do
		Family:Print("    %-26s |cff888888%s|r", name, type(_G[name]))
	end

	-- **What this client has for drawing a race**, asked because Alberto suggested the
	-- equipment block wear the character's own race-and-gender picture and he is right that
	-- the client must already hold it - icons do not travel from a server.
	--
	-- Family has the other half already: `Identity.lua` records `raceFile`, `raceID` and
	-- `sex` for every member. What is missing is how to address the picture, and the class
	-- icons say how that is done here - `CLASS_ICON_TCOORDS`, a table the **client** provides,
	-- with `Character.lua` giving up rather than guessing where an entry is absent, because a
	-- wrong corner of that file is a picture of somebody else's class.
	--
	-- These names are candidates and none of them is confirmed anywhere in this repository.
	-- The answer is what is printed, not what they are called.
	for _, name in ipairs { "CLASS_ICON_TCOORDS", "RACE_ICON_TCOORDS",
		"RACE_ICON_TCOORDS_256", "GetRaceAtlas", "SetPortraitTexture" } do
		Family:Print("    %-24s |cff888888%s|r", name, type(rawget(_G, name)))
	end

	-- And the shape of its keys, printed rather than named: a table keyed "DWARF" and one
	-- keyed "DWARF_MALE" are different features, and only one of them can draw a gender.
	local coords = rawget(_G, "RACE_ICON_TCOORDS")
	if type(coords) == "table" then
		local keys, shown = {}, 0
		for key in pairs(coords) do keys[#keys + 1] = tostring(key) end
		table.sort(keys)
		for _, key in ipairs(keys) do
			if shown < 6 then
				shown = shown + 1
				Family:Print("      %s", key)
			end
		end
	end
end)

add("debug", L["narrate what the scanners are doing"], function()
	FamilyDB.debug = not FamilyDB.debug
	Family:Print(L["debug %s"], FamilyDB.debug and L["on"] or L["off"])
end)

local function handler(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")

	if input == "" then
		UI:Toggle()
		return
	end

	local name, rest = input:match("^(%S+)%s*(.*)$")
	name = name:lower()

	for _, entry in ipairs(commands) do
		if entry.name == name then
			entry.fn(rest)
			return
		end
	end

	Family:Print(L["no command called |cffffd700%s|r."], name)
	usage()
end

--------------------------------------------------------------------------------------------
-- What was ready while nobody was looking
--
-- Said once, shortly after logging in, and only about members other than the one being
-- played: their own cooldowns are on their own action bars, and telling somebody about their
-- own transmute is the sort of message that gets an addon switched off.
--------------------------------------------------------------------------------------------

-- One character to a line, which is the rule the mail notice below sets out at length and
-- which this notice predates. It ran its names together with commas, and a player with a
-- dozen crafters got one paragraph across the chat frame - the wall the other notice exists
-- not to be. Nothing is truncated by it: `Family:Print` goes to `AddMessage`, which wraps;
-- 255 bytes is the cap on `SendChatMessage` and on addon messages, not on this. It is simply
-- unreadable, which is enough.
--
-- The name carries its realm where the character is not on the one being played, by the
-- settled rule that a name is unique per realm and not per realm group. `UI:NameOf` applies
-- it, and a bare list of first names had no way to say which of two namesakes was meant.
--
-- Returned rather than printed, so a check can ask what this would say without waiting eight
-- seconds for a timer - the seam `UI:MailNotice` already has, and the reason nothing here was
-- ever measured.
function UI:CooldownNotice()
	local lines = nil

	-- **Including the character being played**, which reverses the rule this line was written
	-- with. That rule said a transmute you can cast is already on your own action bar - true,
	-- and it answers a question nobody asked. Alberto's, 2026-09-06, after reloading on an
	-- alchemist with a cooldown ready and being told about somebody else instead: *when you
	-- log in, it makes a lot of sense to be notified that YOU, first of all, have something to
	-- do.* The one character you can act on without logging out is the one most worth naming.
	--
	-- `WarmCooldownNames` below had the same exclusion and lost it in the same breath: it asks
	-- the client for the item names this line is about to print, and leaving your own out
	-- would have printed your own salt shaker as a number.
	for _, member in ipairs(Family.Cooldowns:Ready()) do
		-- "Crafting cooldowns" in full, every time, because the thing people
		-- assume next is that Family also watches raid lockouts and heroic
		-- resets. It does not. Those are specified (§3, §4.7) and not built,
		-- which is a different statement from "cannot be done" and should not be
		-- allowed to sound like it - a character can read its own lockouts
		-- perfectly well while it is being played, which is how Family learns
		-- everything else.
		lines = lines or { L["crafting cooldowns ready:"] }

		local meta = Family.Database:Meta(member.key) or {}
		local shown = UI:NameOf(meta)

		-- **What is ready, named.** A name and a number said which character to
		-- log into and never what for, so somebody with two trades had to go and
		-- look. Asked for from play 2026-09-05.
		--
		-- The same grouping the Crafting panel draws, so the words match what
		-- that table says: a timer several recipes share is named after its
		-- profession - *Alchemy*, always, the client putting every transmute on
		-- one - and a profession with a single timed recipe after the recipe.
		--
		-- **Crafting items too**, which reverses 2026-09-01. Family's own help
		-- text for `/family cooldowns` has always said this feature is about
		-- "transmutes, mooncloth, salt shakers", and the shaker is an item - so
		-- the login line was leaving out a thing the addon tells the player it
		-- watches. What `Crafting` carries here is already filtered by
		-- `IsCraftingItem`, so a Chronoboon does not come with it.
		--
		-- Asked with no key and no callback, like the panel's own `only`: a name
		-- the client has not cached falls back to the word that was recorded, and
		-- a callback here would reprint the notice rather than redraw a table.
		local named = {}
		for _, group in ipairs(Family.Cooldowns:Crafting(meta)) do
			if group.ready then
				-- Whatever `Crafting` called it, and nothing worked out
				-- again here. An earlier draft filled an unresolved item
				-- name with the profession that makes the item, and it was
				-- wrong twice over: it printed a fact this line had not
				-- read, and in a list where a shared timer is *already*
				-- named after a profession the same word would have meant
				-- two different things a column apart. `WarmCooldownNames`
				-- below is the answer instead - ask early, print late.
				named[#named + 1] = tostring(group.label)
			end
		end

		-- No count beside them. The names *are* the count and say more than it
		-- did, and "(2)" in front of two names is the same fact twice. All of
		-- them however many, which is the rule the mail notice settled: this is
		-- one line per character already, and a profession's name is short.
		lines[#lines + 1] = string.format("  |cff40bf40%s|r", shown)
			.. (#named > 0 and string.format("  |cff888888%s|r",
				table.concat(named, ", ")) or "")
	end

	return lines
end

-- Ask the client for the item names this notice is about to need.
--
-- An item's name is not a fact about the account, it is a fact about this **session**: the
-- client answers for what it has loaded, and an alt's salt shaker is in that alt's bags and
-- not in the bags of whoever is being played. So the first thing to ask for it gets a
-- placeholder and a promise, which is what `Names:Item` is built around - it requests the item
-- and calls back when the answer lands.
--
-- A panel can live with that: it draws a placeholder and redraws. A line printed once cannot,
-- and it must not invent something to print instead. What it can do is ask sooner than it
-- speaks, which costs nothing and needs no fallback: the request goes out early and the answer
-- is there by the time the line is written.
--
-- Crafts need none of this. A recipe carries the words it was scanned with, and a shared
-- timer is named after its profession, which is a table this addon ships.
function UI:WarmCooldownNames()
	local asked = 0

	-- Read straight off the records, through neither `Cooldowns:Ready` nor
	-- `Cooldowns:Crafting`. Both of those answer a different question and ask the client for
	-- these names as a side effect of grouping - so the first two versions of this were
	-- untestable: emptying the loop entirely changed nothing a check could see, because the
	-- call that fetched the members had already done the asking. A warm-up that cannot be
	-- told apart from the thing it is warming is not one.
	--
	-- Every member with a crafting item rather than only those with one ready, because that
	-- is what is cheap to know here without grouping, and asking about a handful of ids the
	-- client then caches costs nothing.
	for _, member in pairs(Family.Database:Members()) do
		for _, entry in ipairs((member.meta or {}).itemCooldowns or {}) do
			-- The same filter the panel and the notice inherit, asked here rather
			-- than restated: a Chronoboon is not one of these and there is no
			-- reason to ask the client about it.
			if entry.id and Family.Cooldowns:IsCraftingItem(entry.id) then
				Family.Names:Item(entry.id)
				asked = asked + 1
			end
		end
	end

	return asked
end

-- Ask the client about the recipe items before somebody opens a profession.
--
-- Reported from play: on a client started cold, opening Professions froze the game for about ten
-- seconds and then drew normally, once per character with a long recipe list and never again.
--
-- **The panel is not what is slow.** Timed in the game with `debugprofilestart`, the whole draw is
-- **34 ms**. What follows it is the client fetching three hundred items it has not been told about
-- this session.
--
-- *This session* and not ever: the first note here said the client keeps them on disk, which
-- Alberto refused on the evidence - a full restart pays the cost again, so whatever the client
-- keeps, it does not keep that. Nothing here measured it and nothing here needed to; the claim was
-- asserted and is withdrawn.
--
-- So the work cannot be made smaller from here, only moved. This asks for the same ids a few at a
-- time, from the moment the player logs in, so that by the time anybody clicks the answers are
-- already there.
--
-- Spread twice over, because both halves cost. One member's record is decoded per call - decoding
-- thirty at once is its own stall - and at most `budget` unnamed ids are asked for per call. An id
-- the client has already named is skipped without being counted, so a warm client finishes the
-- whole queue in a few calls rather than pretending to work.
--
-- **A notice was considered and is not possible.** Nothing can be drawn while the client is
-- blocked, so a line saying *reading* would appear after the freeze it was meant to explain.
-- **And this time it is said out loud**, which is a reversal of the line above and of the
-- decision that goes with it.
--
-- That refusal was right about the case it was about: a panel that blocks the client for ten
-- seconds cannot draw anything, so a notice would have appeared after the freeze it existed to
-- explain. This is the other case. The walk below runs in the background with the client
-- perfectly responsive, so a line printed while it works is a line somebody actually reads -
-- and Alberto asked for one on behalf of a user with 210 characters, for whom the walk is three
-- and a half minutes rather than four seconds.
--
-- **A line in the chat frame rather than a popup**, which is what he suggested. Family's two
-- popups both ask a question and wait for an answer; one that only informs is a modal to
-- dismiss, arriving during login, which is the worst moment there is. And this is not urgent -
-- nothing is broken, something is merely slower than it will be tomorrow.
--
-- Only where the walk is long enough to notice and there is real work in it. A family of four
-- finishes in four seconds and would be told about it for nothing, and a family of any size
-- whose names are already on disk asks for nothing at all - which is why this stops appearing
-- by itself after the first session rather than needing a switch.
local ANNOUNCE_AFTER = 25

-- How many members the walk may step past on one call, once it can tell they have nothing new.
-- Twenty, because a mark costs about a millisecond to make and a tick that decodes one member
-- costs considerably more than twenty of them - so this is a smaller piece of work than the one
-- it replaces, whatever the family size. A module field rather than a local so a check can hold
-- it low and watch the cap work.
UI.WARM_SKIPS = 20

local warmQueue, warmAt, warmPending, warmSaid

-- What the walk is in the middle of reading: whose record it picked up, the mark that record
-- had at the time, and whether any name it asked for failed to arrive. One table rather than
-- three locals because this file is close to Lua's ceiling of sixty upvalues per function and
-- has been over it twice.
local walking = {}

local function rememberWalk()
	-- **Written down only where every name answered.** A member whose ids are all known is one
	-- the next walk can step past. One with a name the client would not give is not: the mark
	-- is left unwritten so the walk comes back for it next login, which is the only occasion
	-- that id is ever asked for again.
	--
	-- Which makes the second session the one that pays. On a cold client nothing is named yet,
	-- so nothing is marked and the walk costs what it always cost; the names land on disk
	-- during that session, the second walk finds them cached and marks as it goes, and the
	-- third login and every one after it steps past the whole family. Two logins to warm, and
	-- then it is free - rather than one login to warm and a wrong answer whenever the client
	-- was slow.
	if walking.key and walking.mark and not walking.missed then
		Family.Names:LearnItemWalk(walking.key, walking.mark)
	end
	walking.key, walking.mark, walking.missed = nil, nil, nil
end

function UI:WarmRecipeNames(budget)
	budget = budget or 40

	if not warmQueue then
		warmQueue, warmAt, warmPending = {}, 1, {}
		for key in pairs(Family.Database:Members()) do
			warmQueue[#warmQueue + 1] = key
		end

		-- **And everyone a linked family shares with us**, which is where a language
		-- mismatch is not a coincidence but the point: you link with a French family
		-- because they are French, so every one of their lists falls through the fast
		-- path and wants an item name.
		--
		-- Left out until 2026-09-06 and it was the one case the warm-up was built for and
		-- did not cover: `Database:Members` is ours only, borrowed members live under
		-- `FamilyDB.wide`, and a sibling's list was paying at the click - the stall this
		-- exists to move off the click.
		--
		-- **Cheaper to walk than our own**, which is why this costs less than it looks. A
		-- borrowed payload arrived over the wire as a table and was never encoded, so
		-- there is no decoding to spread, and the decoding is the whole reason our own
		-- are taken one per call.
		--
		-- Everyone shared and not only the siblings, for the reason written beside
		-- `UI:EveryMember`: a sibling is a decision about the summary, and every shared
		-- member is reachable on the panels whether or not they are one.
		for _, member in ipairs(Family.Wide:BorrowedMembers()) do
			if member.borrowedKey then
				warmQueue[#warmQueue + 1] = member.borrowedKey
			end
		end
		-- Sorted, so two runs of this walk the members in the same order and a check can
		-- say where it got to - and then the character being played is moved to the front,
		-- because they are the one somebody is about to open. Alphabetical order would
		-- otherwise spend the first half-minute on members nobody is looking at.
		table.sort(warmQueue)

		local playing = Family:CurrentMember()
		for index, key in ipairs(warmQueue) do
			if key == playing then
				table.remove(warmQueue, index)
				table.insert(warmQueue, 1, key)
				break
			end
		end
	end

	-- **Step past everyone whose record has not changed since the walk last read it through.**
	--
	-- This is what the entry was measured for. One second and one payload decode per character
	-- at every login, whether or not that character has anything left to ask about: invisible
	-- at thirty, and three and a half minutes at 210 - spent proving that there is nothing to
	-- do. `Database:PayloadMark` answers that question without decoding anything, and what the
	-- last walk marked is on disk beside the names it learned.
	--
	-- **Several per call rather than one**, because the reason members are taken one at a time
	-- is the decode, and a skip has none: a mark is a fold over the ends of a string the client
	-- already holds. Stepping past them one a second would leave the cost exactly where it
	-- was. Capped all the same, so that no family size can be a stall.
	--
	-- **A borrowed member is never skipped**, because they have no mark. Their payload arrived
	-- over the wire as a table and was never encoded, so there is no decode to save - the same
	-- reason they were cheap enough to add to this queue in the first place.
	local skipped, capped = 0, false
	while #warmPending == 0 and warmAt <= #warmQueue do
		if skipped >= (self.WARM_SKIPS or 20) then
			-- Stopped by the cap and not by a member worth reading, so this call ends
			-- here. Reading the next one anyway would decode a record the mark has
			-- already said there is nothing to learn from - the one thing this exists
			-- to stop - on every call that fills its cap.
			capped = true
			break
		end

		local key = warmQueue[warmAt]
		local mark = Family.Database:PayloadMark(key)
		if mark == nil or Family.Names:ItemWalk(key) ~= mark then break end
		warmAt = warmAt + 1
		skipped = skipped + 1
	end

	-- One member's payload per call. `Database:Payload` decodes and then caches for the
	-- session, so this is the decode being spread rather than a second one being paid.
	if not capped and #warmPending == 0 and warmAt <= #warmQueue then
		-- The mark is read before the record, and it is the record as it sits on disk now.
		-- Taken afterwards it could be a mark for a scan that landed while this call was
		-- running, and the walk would write down that it had read something it had not.
		local key = warmQueue[warmAt]
		walking.key, walking.mark, walking.missed = key, Family.Database:PayloadMark(key), false

		-- Through the window's reader rather than the database's, because half this queue
		-- is borrowed now and `Database:Payload` knows only ours (L-052). For our own keys
		-- it is the same call underneath.
		local payload = UI:Payload(key) or {}
		warmAt = warmAt + 1

		for _, record in pairs(payload.professions or {}) do
			-- **A list read in the reader's own language needs none of this.**
			--
			-- `Names:Recipe` has a fast path before either id: where `record.locale` is
			-- the reader's, it returns the recorded word and touches neither the spell
			-- nor the item. The professions panel passes that locale, so for a family
			-- scanned on the client it is being read on, every name asked for here is a
			-- name nothing will ever read.
			--
			-- Which makes this the difference between a first login that stalls and one
			-- that does not, for everybody who plays in one language. Alberto pays it
			-- because he has been switching an Era client between English and French for
			-- days, so some of his lists are French and some are not - and he cannot tell
			-- which any more, because Family translates them on the way to the screen.
			--
			-- **Only the two calls that can request are what matters**, and both were
			-- read before this was written: `Professions.lua` passes `record.locale` and
			-- short-circuits, and `Cooldowns.lua` passes nil deliberately - a Mooncloth
			-- recorded in French was headed *Etoffe lunaire* on an English panel - but it
			-- asks about cooldown recipes, which are a handful and have a warm-up of
			-- their own. Everything else names a recipe without a callback and so cannot
			-- ask the client for anything.
			--
			-- Nil is not a match. A record written before that field existed cannot use
			-- the fast path either, so it is warmed like any other.
			if record.locale ~= Family.locale then
				for _, recipe in ipairs(record.recipes or {}) do
					if recipe.itemID then
						warmPending[#warmPending + 1] = recipe.itemID
					end
				end
			end
		end
	end

	local asked = 0
	while #warmPending > 0 and asked < budget do
		local id = table.remove(warmPending)
		-- Already named costs nothing and is not work: counting it would let a warm
		-- client report a full budget while asking for nothing.
		if not Family.Names:CachedItem(id) then
			local _, known = Family.Names:Item(id)
			if not known then walking.missed = true end
			asked = asked + 1
		end
	end

	-- Emptied, so whoever it belonged to has been read all the way through.
	if #warmPending == 0 then rememberWalk() end

	-- Said on the first call that actually asks for something, so it arrives at the start of
	-- the wait rather than in the middle of it - and once, because a line repeated every
	-- second for three minutes is not a notice, it is a fault.
	if asked > 0 and not warmSaid and #warmQueue > ANNOUNCE_AFTER then
		warmSaid = true
		Family:Print(L["|cff888888reading what %d characters' recipes are called. The "
			.. "professions page will be slow until that finishes, and quick from the "
			.. "next time you log in.|r"], #warmQueue)
	end

	return asked, #warmPending == 0 and warmAt > #warmQueue
end

-- How many characters the walk has left, or nothing once it has finished.
--
-- **Asked by the professions panel**, which is where the waiting is actually felt. Alberto
-- corrected the first version of this notice on exactly that point: the wait he means is not
-- the login, it is the hourglass the first time that window is opened, and a line in the chat
-- frame is not where somebody staring at an hourglass is looking. So the panel says it too,
-- for as long as it is true.
--
-- Nothing before the walk has started, which is the same answer as finished and is the right
-- one: there is nothing to warn about until there is something to warn about.
function UI:RecipeWarmUpLeft()
	if not warmQueue then return nil end
	local left = #warmQueue - warmAt + 1
	if left <= 0 and #warmPending == 0 then return nil end
	return math.max(left, 0), warmSaid == true
end

-- Reachable so a check can start it over rather than depend on whatever the run before left.
function UI:ForgetRecipeWarmUp()
	warmQueue, warmAt, warmPending, warmSaid = nil, nil, nil, nil
	walking.key, walking.mark, walking.missed = nil, nil, nil
end

Family:OnDatabaseReady("recipes.warm", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "recipes.warm", function()
		UI:ForgetRecipeWarmUp()

		-- Every second until the queue is empty, and then it stops. A timer that went on
		-- ticking over a finished queue would be a heartbeat nobody asked for.
		local function step()
			local _, done = UI:WarmRecipeNames()
			if done then return end
			Family:After(1, "recipes.warm", step)
		end

		-- Late enough that the client has finished its own arrival. The cooldown warm-up
		-- next door starts at two seconds and this is the heavier of the two.
		Family:After(6, "recipes.warm", step)
	end)
end)

Family:OnDatabaseReady("cooldowns.notice", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "cooldowns.notice", function()
		-- Well before the line is written, and not on the same beat: the whole point is
		-- to leave the client time to answer.
		Family:After(2, "cooldowns.warm", function()
			if FamilyDB.cooldownNotice == false then return end
			UI:WarmCooldownNames()
		end)

		Family:After(8, "cooldowns.notice", function()
			if FamilyDB.cooldownNotice == false then return end

			local lines = UI:CooldownNotice()
			if not lines then return end

			for _, line in ipairs(lines) do Family:Print(line) end
		end)
	end)
end)

--------------------------------------------------------------------------------------------
-- Whose mail is about to go
--
-- The same shape as the notice above, with two deliberate differences.
--
-- **It does not leave out the character being played.** The cooldown notice does, because a
-- transmute you can cast is already on your own action bar and being told about it is what
-- gets an addon switched off. Mail is not like that: the game gives the player an envelope on
-- the minimap and never once says when what is in it goes away, so the character standing
-- there is exactly as badly informed as the other thirty-nine.
--
-- **A second later than the cooldowns.** Two lines of chat in the same instant read as one
-- wall and neither gets looked at; a beat apart they read as two facts.
--------------------------------------------------------------------------------------------

local DEFAULT_MAIL_NOTICE_DAYS = 3
UI.DEFAULT_MAIL_NOTICE_DAYS = DEFAULT_MAIL_NOTICE_DAYS

-- Bounds rather than a free number. Mail lives thirty days, so a warning period longer than
-- that names every letter in the game and a period of nought names nothing that is not
-- already lost.
UI.MAIL_NOTICE_MIN, UI.MAIL_NOTICE_MAX = 1, 30

function UI:MailNoticeDays()
	local days = tonumber(FamilyDB and FamilyDB.mailNoticeDays)
	if not days then return DEFAULT_MAIL_NOTICE_DAYS end

	days = math.floor(days)
	if days < UI.MAIL_NOTICE_MIN or days > UI.MAIL_NOTICE_MAX then
		return DEFAULT_MAIL_NOTICE_DAYS
	end
	return days
end

function UI:SetMailNoticeDays(days)
	days = tonumber(days)
	if not days then return nil end

	days = math.floor(days)
	if days < UI.MAIL_NOTICE_MIN or days > UI.MAIL_NOTICE_MAX then return nil end

	FamilyDB.mailNoticeDays = days
	return days
end

-- One character to a line.
--
-- A family of forty with the warning set wide enough is forty names, and each carries a realm
-- and sometimes a family as well. Run together they are a wall, and a wall of text at login is
-- a thing people switch off rather than read; a line each, indented under a heading, is a list
-- somebody's eye can go down.
--
-- **All of them, however many there are.** This was capped at ten with the remainder counted,
-- on the reasoning that a very long list is a wall of its own - and Alberto's answer was that
-- a character left off is a character whose mail is lost, which no count at the bottom
-- prevents. A list of forty is long; forty letters gone is worse, and the player is the one
-- who set the warning period that produced the list.
--
-- The length is theirs to control and there is a control for it: the notice is switchable off
-- and the warning period is a number in the options panel, so a list somebody finds too long
-- has a shorter one behind it that does not cost them anything.
--
-- One name to a line also removed a question rather than only a nuisance. The first cut at
-- this capped the *characters* in a single line against a byte budget, and measuring it
-- correctly - the plain text rather than the coloured, twelve bytes a reader never sees per
-- entry - was the one thing in that version no check here noticed.

-- The lines the notice would print right now, or nil when it would say nothing. Separate from
-- the event so that a check can ask the question without waiting nine seconds for a timer.
function UI:MailNotice()
	local waiting = Family.Mail:Expiring(UI:MailNoticeDays() * 86400)
	if #waiting == 0 then return nil end

	-- Name-Realm, which is the form the game itself uses and the form a whisper wants, so
	-- nobody has to learn a second one. The family in grey after it where the character is
	-- somebody else's: §6 says whose a character is never gets merged away, and a login
	-- notice is exactly where two families' alts would otherwise run together.
	--
	-- No realm is a guard rather than a case - `Identity.lua` writes name and realm in one
	-- breath and Wide Family has always sent both - but a notice is not the place to find out
	-- by printing "Tossica-nil".
	--
	local function entryFor(member)
		local shown = member.realm and string.format("%s-%s", member.name, member.realm)
			or member.name

		if member.family then
			shown = string.format("%s |cff888888[%s]|r", shown, member.family)
		end

		if member.expired then
			return string.format(L["%s |cffff4444(already gone)|r"], shown)
		end
		return string.format("%s |cff888888(%s)|r", shown, UI:In(member.expiresBy))
	end

	local lines = { L["mail running out:"] }

	-- Urgency order, so the ones that can still be saved read after the ones that cannot and
	-- the eye stops at the right place going down.
	for _, member in ipairs(waiting) do
		lines[#lines + 1] = "  " .. entryFor(member)
	end

	return lines
end

Family:OnDatabaseReady("mail.notice", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "mail.notice", function()
		Family:After(9, "mail.notice", function()
			if FamilyDB.mailNotice == false then return end

			local lines = UI:MailNotice()
			if not lines then return end

			for _, line in ipairs(lines) do Family:Print(line) end
		end)
	end)
end)

SLASH_FAMILY1 = "/family"
SLASH_FAMILY2 = "/fam"

--------------------------------------------------------------------------------------------
-- What the Key Bindings window calls Family's binding
--
-- Two more globals the client asks for by name, beside the two above, and they are the same
-- kind of exception: the game looks them up itself and there is nowhere else to put them.
--
-- Set here rather than written into Bindings.xml, and that is the whole care this needed. A
-- name in the XML is one string in one language, invisible to the locale files and therefore
-- English on every client - and the Key Bindings window is exactly where a player who does not
-- read English is looking for the word they know.
--
-- `BINDING_HEADER_FAMILY` is the heading the binding sits under and matches the `header` in
-- Bindings.xml; `BINDING_NAME_FAMILY_TOGGLE` matches the binding's `name`. Both agreements are
-- checked by the harness, because a rename on one side is silent on the other: the window
-- simply shows the raw action name, which is what an unlocalised binding looks like too.
BINDING_HEADER_FAMILY = L["Family"]
BINDING_NAME_FAMILY_TOGGLE = L["Open and close Family"]
SlashCmdList["FAMILY"] = handler
