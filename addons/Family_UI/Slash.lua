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

add("guild", L["guild share on, off, or test: /family guild test"], function(argument)
	local wanted = (argument or ""):lower():match("^%S*")

	if wanted ~= "on" and wanted ~= "off" and wanted ~= "test" then
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
		return
	end

	if wanted == "test" then
		Family.Guild:Diagnose()
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

		-- The panel is registered at load, so it appears or disappears at the next one. Said
		-- plainly rather than left as a tab that did not turn up.
		Family:Print(L["Wide Family is now |cffffd700%s|r. Type |cffffd700/reload|r for the "
			.. "panel to %s."], on and L["on"] or L["off"], on and L["appear"] or L["go"])
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
				else
					local chosen = 0
					for _, row in pairs(data.tiers or {}) do
						if row.chosen then chosen = chosen + 1 end
					end
					Family:Print(L["     spec %d: %d tier(s), %d chosen, spec id %s"],
						group, #(data.tiers or {}), chosen, tostring(data.specID))
				end
			end
		end
	end

	if found == 0 then
		Family:Print(L["|cffffaa00No member has talent data.|r Try /family rescan, then " ..
			"look at what it says."])
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

SLASH_FAMILY1 = "/family"
SLASH_FAMILY2 = "/fam"
SlashCmdList["FAMILY"] = handler
