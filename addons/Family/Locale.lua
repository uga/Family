-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The string table, and the reason English needs no file of its own.
--
-- The key IS the English sentence. `L["Summary"]` on an English client returns "Summary"
-- because nothing translated it, not because somebody wrote enUS["Summary"] = "Summary".
-- That is the whole design: there is no key vocabulary to invent, keep in step or misspell,
-- a missing translation degrades to readable English rather than to `MISSING_KEY_47`, and
-- the diff that introduced this feature could be read as prose.
--
-- The cost is that changing an English string orphans its four translations. The harness
-- catches that: it reads every locale file and reports any key that no source file asks for
-- any more, which is exactly the set that went stale.

local _, Family = ...

-- Registered by the files in Locales/. They load after this one and are all read, whatever
-- the client language is - a file that returned early on the wrong locale would be invisible
-- to the harness, and an untestable translation is how the last set of these got to be wrong.
Family.locales = {}

Family.locale = (GetLocale and GetLocale()) or "enUS"

Family.L = setmetatable({}, {
	__index = function(_, key)
		local table = Family.locales[Family.locale]
		local word = table and rawget(table, key)
		-- An empty string in a locale file means "deliberately left English", which is not
		-- the same as absent and is how a term that should not be translated says so.
		if word == nil or word == "" then return key end
		return word
	end,
})

--------------------------------------------------------------------------------------------
-- Words the game already has
--------------------------------------------------------------------------------------------

-- "Level" is the game's word before it is ours, and on a German client the game has already
-- decided what it is called. Taking Blizzard's own string means Family says what the rest of
-- the interface says, in all eleven languages, including the seven nobody here can write.
--
-- The English key is still passed, and is still what the harness measures, because a global
-- can be missing: absent on a client, renamed between expansions, or empty. Then this falls
-- through to Family's own translation rather than to a blank label.
--
-- What cannot be done is predict the global. Blizzard's German for a thing is whatever it is
-- and is not known to this repository, so nothing here may reserve room for it by counting
-- characters. Anything drawn in a fixed space is measured with GetStringWidth and given the
-- room it turns out to need - UI:FitColumns and UI:LayOutRow in Family_UI/Window.lua - which
-- is the whole of the rule: the layout gives way to the word, never the word to the layout
-- (specification §8).
-- **Trailing punctuation is taken off.**
--
-- Several of these globals are the game's own *labels* rather than its words, and a label ends
-- in a colon because the game draws a number after it: `TRAINING_POINTS` is "Training Points:"
-- on an English client. Family uses them inside sentences, so the colon arrives in the middle of
-- one - reported from play 2026-09-09 as *77 Training Points:* and *248 of 273 Training Points:
-- accounted for*.
--
-- Only what trails, and only punctuation the game hangs on a label: a colon, a full stop, and
-- whatever space is around them. Nothing inside the word is touched, so a language that writes a
-- colon-like character as part of a word keeps it.
function Family:GameWord(global, english)
	local word = global and rawget(_G, global)

	if type(word) == "string" and word ~= "" then
		local trimmed = word:gsub("%s*[:.]%s*$", "")
		if trimmed ~= "" then return trimmed end
		return word
	end

	return Family.L[english]
end
