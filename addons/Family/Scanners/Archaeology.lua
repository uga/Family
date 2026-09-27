-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What a character's Archaeology holds: fragments by race, the project in progress, and the
-- artifacts solved.
--
-- Backlog 104, Mists only (the `archaeology` capability). Read on Luga 2026-09-27 with the window
-- never opened and again with it open, and the two readings agree (DATASOURCES, *Archaeology on
-- Mists*): so this is read at login and after the events that change it, never waiting for the
-- window.
--
-- `GetArchaeologyRaceInfo(i)` answers name, icon, keystone, **fragments held, fragments the
-- project needs, cap**. `GetActiveArtifactByRace(i)` answers the project - name, description,
-- rarity, icon - or nothing. `GetNumArtifactsByRace(i)` counts the solved artifacts **and** the
-- project in progress, and `GetArtifactInfoByRace(i, j)`'s ninth and tenth are the moment it was
-- first solved and how many times; a solved one is one with a count above nought (the game's own
-- tooltip, *First Completion* and *Number of times completed*, read beside it).
--
-- **Kept by race index, not by name.** The name is the client's language; the index is the same
-- thirteen on every Mists client, and this exists on no other build.
--
-- **In two places.** The summary reads meta without decoding anybody (HANDOFF §1), so each race's
-- fragments, project and solved count go there - a handful of short entries. The list of solved
-- artifacts, which only grows, goes in the payload for the Character panel.

local _, Family = ...

local Archaeology = {}
Family.Archaeology = Archaeology

local function row(ok, ...)
	if not ok then return {}, 0 end
	return { ... }, select("#", ...)
end

local function number(value)
	local n = tonumber(value)
	if not n or n ~= n then return 0 end
	return n
end

-- Every race this character has anything in, and every artifact solved, or nil where the client
-- has no archaeology.
function Archaeology:Read()
	if not Family.Capabilities:Has("archaeology") then return nil end
	if type(_G.GetNumArchaeologyRaces) ~= "function" then return nil end

	local count = tonumber((Family:TryCall(GetNumArchaeologyRaces))) or 0
	local races, solved = {}, {}

	for index = 1, count do
		local info = row(pcall(GetArchaeologyRaceInfo, index))
		local name = info[1]
		local fragments, need, cap = number(info[4]), number(info[5]), number(info[6])

		local project
		if type(_G.GetActiveArtifactByRace) == "function" then
			local active, width = row(pcall(GetActiveArtifactByRace, index))
			if width > 0 and type(active[1]) == "string" and active[1] ~= "" then
				project = { name = active[1], icon = active[4] }
			end
		end

		local done = 0
		local listed = type(_G.GetNumArtifactsByRace) == "function"
			and number((Family:TryCall(GetNumArtifactsByRace, index))) or 0
		if type(_G.GetArtifactInfoByRace) == "function" then
			for artifact = 1, listed do
				local a = row(pcall(GetArtifactInfoByRace, index, artifact))
				local times = number(a[10])
				if type(a[1]) == "string" and times > 0 then
					done = done + 1
					solved[#solved + 1] = { race = index, name = a[1], icon = a[4],
						firstAt = number(a[9]) > 0 and number(a[9]) or nil, count = times }
				end
			end
		end

		-- A race with nothing in it is not recorded: thirteen rows of noughts for every
		-- archaeologist, and every one of them for anybody who never dug.
		if type(name) == "string" and (fragments > 0 or project or done > 0) then
			races[#races + 1] = {
				race = index,
				name = name,
				icon = info[2],
				fragments = fragments,
				need = project and need > 0 and need or nil,
				cap = cap > 0 and cap or nil,
				project = project and project.name or nil,
				projectIcon = project and project.icon or nil,
				solved = done > 0 and done or nil,
			}
		end
	end

	return races, solved
end

function Archaeology:Scan()
	local key = Family:CurrentMember()
	if not key then return end

	local races, solved = self:Read()
	if not races then return end

	-- Nothing at all is an answer: this character has never dug, and `archaeologySeen` says it
	-- was asked.
	Family.Database:SetMeta(key, {
		archaeology = #races > 0 and races or Family.CLEAR,
		archaeologySeen = time(),
	})

	local payload = Family.Database:Payload(key) or {}
	payload.archaeologySolved = #solved > 0 and solved or nil
	Family.Database:SetPayload(key, payload, { "archaeologySolved" })

	Family:Debug("scanned archaeology: %d race(s), %d solved", #races, #solved)
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("archaeology", function()
	if not Family.Capabilities:Has("archaeology") then return end

	Family:RegisterEvent("PLAYER_ENTERING_WORLD", "archaeology", function()
		Family:After(8, "archaeology", function() Archaeology:Scan() end)
	end)

	-- Fragments are counted as a currency, and a solve, a new project and a new dig all
	-- announce themselves. Whichever of these the client has.
	for _, event in ipairs {
		"CURRENCY_DISPLAY_UPDATE",
		"ARTIFACT_COMPLETE",
		"ARTIFACT_UPDATE",
		"RESEARCH_ARTIFACT_COMPLETE",
		"RESEARCH_ARTIFACT_UPDATE",
		"ARTIFACT_HISTORY_READY",
	} do
		Family:RegisterEvent(event, "archaeology", function()
			Family:After(3, "archaeology", function() Archaeology:Scan() end)
		end)
	end
end)
