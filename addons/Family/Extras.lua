-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Which of the jobs Family is not for it is doing anyway.
--
-- Asked for 2026-09-12: *mi stanno venendo in mente un po' di queste features collaterali,
-- forse puo valer la pena di creare un ulteriore pannello Extras (sopra Options) per
-- abilitarle / disabilitarle singolarmente.*
--
-- **The answers live here and the panel lives in Family_UI**, which is not tidiness. The
-- recorder obeys these - the auction reader stops reading when the auction extra is off - and
-- `Family_UI` is a separate addon a player can have disabled. A setting the scanners consult
-- cannot live in the half of the pair that may not be loaded.
--
-- **The line between an extra and an option** is what the switch is about rather than how big
-- it is. Options settles how Family behaves while doing its job: whether the tooltip carries a
-- possessions block, who may see what, how far in front the window sits. An extra is a job
-- Family would not otherwise be doing at all.

local _, Family = ...

local Extras = {}
Family.Extras = Extras

-- **The default per extra, and the whole of why this table exists.** Written here rather than
-- as `~= false` at each asking site, which is how two places come to disagree about what an
-- unset value means.
--
-- **A new extra ships off.** These are opted into by definition, and a feature that starts
-- talking in somebody's chat frame because they updated an addon is a feature they uninstall
-- the addon over.
--
-- The auction house is the exception and is not really one: it is not a new job. Family has
-- read prices since the day the store was written, and shipping that switch off would take
-- every auction price off every tooltip on upgrade - which is a change nobody asked for
-- wearing the clothes of a new feature. `houseWalk` is on for the same reason and no other:
-- the button exists today, and a switch that removed it on upgrade would be that same change.
local DEFAULTS = {
	auctionPrices = true,
	craftingCost = false,
	houseWalk = true,
	mailReport = false,
}

function Extras:Defaults() return DEFAULTS end

-- Every name there is, sorted, so that a panel and a probe list the same set in the same order
-- without either of them keeping a second copy of it.
function Extras:Names()
	local out = {}
	for name in pairs(DEFAULTS) do out[#out + 1] = name end
	table.sort(out)
	return out
end

function Extras:On(name)
	if DEFAULTS[name] == nil then return false end

	local held = type(_G.FamilyDB) == "table" and FamilyDB.extras
		and FamilyDB.extras[name]
	if held == nil then return DEFAULTS[name] end
	return held and true or false
end

function Extras:Set(name, on)
	if DEFAULTS[name] == nil then return false end
	if type(_G.FamilyDB) ~= "table" then return false end

	FamilyDB.extras = FamilyDB.extras or {}
	FamilyDB.extras[name] = on and true or false

	-- **Said out loud rather than waited for.** Turning the auction house off has to take the
	-- tab off that window and turning it on has to put one there, and neither happens by
	-- itself: the window is only built when an auction house opens.
	local UI = Family.UI
	if UI and UI.ExtraChanged then Family:TryCall(UI.ExtraChanged, UI, name) end

	return true
end
