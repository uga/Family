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

-- Roughly what a character costs in the fonts Family draws labels in. One number, read by
-- the harness out of this file, so the budget it enforces and the width Fit measures cannot
-- drift apart.
local PX_PER_CHAR = 6.5

-- "Level" is the game's word before it is ours, and on a German client the game has already
-- decided what it is called. Taking Blizzard's own string means Family says what the rest of
-- the interface says, in all eleven languages, including the seven nobody here can write.
--
-- The English key is still passed, and is still what the harness measures, because a global
-- can be missing: absent on a client, renamed between expansions, or empty. Then this falls
-- through to Family's own translation rather than to a blank label.
--
-- What cannot be done is measure the global. Blizzard's German for a thing is whatever it
-- is, and it is not known here - so anything drawn in a fixed space goes through Fit below.
function Family:GameWord(global, english)
	local word = global and rawget(_G, global)
	if type(word) == "string" and word ~= "" then return word end
	return Family.L[english]
end

-- Cut to the room there is, on a character boundary rather than a byte one.
--
-- UTF-8 continuation bytes are 0x80-0xBF; cutting between a letter's bytes leaves the client
-- drawing a broken glyph, which is the one outcome worse than a word that is too long.
-- Cyrillic is two bytes a letter and every accented Latin letter is two, so a byte count
-- here would truncate German at half the words it should and Russian at every one of them.
function Family:Fit(text, pixels)
	if type(text) ~= "string" then return "" end
	local limit = math.floor(pixels / PX_PER_CHAR)

	local count, byte = 0, 0
	while byte < #text do
		byte = byte + 1
		local c = text:byte(byte)
		-- Colour codes are not drawn and do not count against the room.
		if c == 124 then                       -- "|"
			local next_ = text:byte(byte + 1)
			if next_ == 99 then byte = byte + 9      -- |cffffffff
			elseif next_ == 114 then byte = byte + 1 -- |r
			end
		elseif c < 128 or c > 191 then
			count = count + 1
			if count > limit then
				-- Back off to the start of this character, then leave room for the mark.
				local cut = byte - 1
				while cut > 0 and text:byte(cut) >= 128 and text:byte(cut) <= 191 do
					cut = cut - 1
				end
				return text:sub(1, math.max(cut - 1, 1)) .. "..."
			end
		end
	end

	return text
end
