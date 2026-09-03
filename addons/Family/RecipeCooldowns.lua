-- Which recipes have a cooldown, and how long. GENERATED - see
-- tools/recipe-cooldowns.py. Do not edit.
--
-- From the client's own SpellCooldowns, so a recipe is known to have a cooldown
-- before anybody has watched one run - which is what GetTradeSkillCooldown cannot
-- say while it is ready. Seconds, not milliseconds.
--
-- **Keyed by expansion**, because the same spell differs: Transmute: Mithril to
-- Truesilver is 48 hours on Classic Era, 20 on Burning Crusade and gone on Mists.
-- Read through Family.Capabilities.expansion, as TalentSpells.lua is.
--
-- Keyed twice within that: by spell, and by the item the recipe makes, because a
-- recipe on Classic Era often arrives with an item id and no spell at all.
--
-- The item lane is keyed again by the skill line that teaches it, because what a
-- recipe makes does not say which profession made it: a Gold Bar is smelted by a
-- miner for nothing and transmuted by an alchemist on a day's wait. Without the
-- line, every Era miner who could smelt gold grew a Mining column that read ready
-- for ever. So a match has to agree about the profession as well as the item.

local _, Family = ...

Family.RecipeCooldowns = {
	[1] = {
		spell = {
			[11479] = 86400,
			[11480] = 172800,
			[17187] = 172800,
			[17559] = 86400,
			[17560] = 86400,
			[17561] = 86400,
			[17562] = 86400,
			[17563] = 86400,
			[17564] = 86400,
			[17565] = 86400,
			[17566] = 86400,
			[18560] = 345600,
			[22430] = 7200,
		},
		item = {
			[3577] = { [171] = 86400 },
			[6037] = { [171] = 172800 },
			[7076] = { [171] = 86400 },
			[7078] = { [171] = 86400 },
			[7080] = { [171] = 86400 },
			[7082] = { [171] = 86400 },
			[12360] = { [171] = 172800 },
			[12803] = { [171] = 86400 },
			[12808] = { [171] = 86400 },
			[14342] = { [197] = 345600 },
			[17967] = { [171] = 7200 },
		},
	},
	[2] = {
		spell = {
			[11479] = 72000,
			[11480] = 72000,
			[17559] = 72000,
			[17560] = 72000,
			[17561] = 72000,
			[17562] = 72000,
			[17563] = 72000,
			[17564] = 72000,
			[17565] = 72000,
			[17566] = 72000,
			[26751] = 331200,
			[28027] = 172800,
			[28028] = 172800,
			[28566] = 72000,
			[28567] = 72000,
			[28568] = 72000,
			[28569] = 72000,
			[28580] = 72000,
			[28581] = 72000,
			[28582] = 72000,
			[28583] = 72000,
			[28584] = 72000,
			[28585] = 72000,
			[29688] = 72000,
			[31373] = 331200,
			[32765] = 72000,
			[32766] = 72000,
			[36686] = 331200,
			[47280] = 72000,
		},
		item = {
			[3577] = { [171] = 72000 },
			[6037] = { [171] = 72000 },
			[7076] = { [171] = 72000 },
			[7078] = { [171] = 72000 },
			[7080] = { [171] = 72000 },
			[7082] = { [171] = 72000 },
			[12803] = { [171] = 72000 },
			[12808] = { [171] = 72000 },
			[21845] = { [197] = 331200 },
			[21884] = { [171] = 72000 },
			[21885] = { [171] = 72000 },
			[21886] = { [171] = 72000 },
			[22451] = { [171] = 72000 },
			[22452] = { [171] = 72000 },
			[22456] = { [171] = 72000 },
			[22457] = { [171] = 72000 },
			[22459] = { [333] = 172800 },
			[22460] = { [333] = 172800 },
			[23571] = { [171] = 72000 },
			[24271] = { [197] = 331200 },
			[24272] = { [197] = 331200 },
			[25867] = { [171] = 72000 },
			[25868] = { [171] = 72000 },
			[35945] = { [755] = 72000 },
		},
	},
	[5] = {
		spell = {
			[28027] = 172800,
			[28028] = 172800,
			[47280] = 72000,
		},
		item = {
			[22459] = { [333] = 172800 },
			[22460] = { [333] = 172800 },
			[191061] = { [755] = 72000 },
		},
	},
}
