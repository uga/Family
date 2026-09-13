-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The last file the .toc loads, and nothing in it but the moment it ran.
--
-- **For the loading screen's share of Family**, which is where storing records plain moves the
-- cost that compression kept out of the first whole-family question (backlog 74). The client reads
-- every file an addon lists, then that addon's saved variables, then tells it `ADDON_LOADED`; so
-- the time between the end of this file and `Database:Initialise` is the saved data being parsed.
-- `/family status` prints it. Measured once before records are stored plain and once after, on
-- the same account, which is the only comparison that means anything.
--
-- Last on purpose: a file listed after this one would be counted as saved data. The harness holds
-- the .toc to that.

local _, Family = ...

if type(_G.debugprofilestop) == "function" then
	Family.filesLoadedAt = _G.debugprofilestop()
end
