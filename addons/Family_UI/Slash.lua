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

		Family:Print(L["  %s: %d recipe(s), %d with a spell id, %d with an item id"],
			tostring(Family:ProfessionName(id, record.name)), #recipes, spells, items)

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

Family:OnDatabaseReady("cooldowns.notice", function()
	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "cooldowns.notice", function()
		Family:After(8, "cooldowns.notice", function()
			if FamilyDB.cooldownNotice == false then return end

			local waiting = {}
			for _, member in ipairs(Family.Cooldowns:Ready()) do
				if member.key ~= Family:CurrentMember() then
					waiting[#waiting + 1] = member.count > 1
						and string.format("%s (%d)", member.name, member.count)
						or member.name
				end
			end

			if #waiting == 0 then return end

			-- "Crafting cooldowns" in full, every time, because the thing people assume
			-- next is that Family also watches raid lockouts and heroic resets. It does
			-- not. Those are specified (§3, §4.7) and not built, which is a different
			-- statement from "cannot be done" and should not be allowed to sound like it -
			-- a character can read its own lockouts perfectly well while it is being
			-- played, which is how Family learns everything else.
			Family:Print(L["crafting cooldowns ready: |cff40bf40%s|r"],
				table.concat(waiting, ", "))
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
SlashCmdList["FAMILY"] = handler
