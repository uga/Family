-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Family, on every item tooltip in the game.
--
-- This is the half of the specification (§5) that matters most in practice: the answer is
-- wanted where the question arises, and the question arises over an item on the floor, at a
-- vendor, in the auction house - not in a window the player has to go and open. Somebody
-- deciding whether to buy a stack of linen wants to know they already have four hundred, at
-- the moment their cursor is over it.
--
-- Everything here reads the index rather than the members (Index.lua). A tooltip fires on
-- every mouse movement across a bag, so nothing in this file may be expensive.

local _, UI = ...

local Family = _G.Family
local L = Family.L

--------------------------------------------------------------------------------------------

local function itemIDFrom(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

-- How many, and where they are: "37 (17 bags, 20 bank)".
--
-- The total leads and is the only part in gold, because it is the answer to the question
-- being asked - the breakdown says where to go and get them, which is the next question and
-- not the first one. A member with them in one place only still reads "20 (20 bank)", since
-- a column where some rows have a total and some do not is harder to read than a repetitive
-- one.
local function placesOf(owner)
	local parts = {}
	-- Each place is a whole phrase rather than a number with a word stuck after it: where
	-- the number goes inside the phrase is a fact about the language, not about the bag.
	if owner.bags > 0 then parts[#parts + 1] = string.format(L["%d bags"], owner.bags) end
	if owner.bank > 0 then parts[#parts + 1] = string.format(L["%d bank"], owner.bank) end
	if owner.mail > 0 then parts[#parts + 1] = string.format(L["%d mail"], owner.mail) end
	if owner.auctions > 0 then
		parts[#parts + 1] = string.format(L["%d auction"], owner.auctions)
	end

	local where = table.concat(parts, ", ")
	if where == "" then return "" end

	return string.format("|cffffd700%d|r |cffb0b0b0(%s)|r", owner.total, where)
end

-- Names to show for a list of members, with the realm added to the ones that need it.
--
-- Two characters on two realms can share a name, and Family keeps them apart everywhere else
-- by realm - but a tooltip has no column to say which is which, and a line reading
-- "Eccebombo" twice with different numbers is a line that cannot be acted on.
--
-- Only the ones that clash. Putting the realm on every name would spend a third of the width
-- saying something that is nearly always obvious, on a tooltip that is already sharing the
-- item with whatever else the player runs.
-- Names for a list of members, with the realm on the ones that clash and the side on the ones
-- playing the other one. Both live in Window.lua, because a search result needs exactly the
-- same treatment and neither should have its own idea of it.
local function labelled(entries)
	return UI:NamesOf(entries)
end

local function classColour(classFile)
	local colours = _G.RAID_CLASS_COLORS
	local colour = classFile and colours and colours[classFile]
	if not colour then return 1, 1, 1 end
	return colour.r, colour.g, colour.b
end

--------------------------------------------------------------------------------------------

-- Neither block writes the blank lines around itself. Both used to, and with two of them on
-- one tooltip that produced a double gap in the middle and a stray one at the end. Spacing
-- between blocks is a property of there being two, so it is decided where they are put
-- together (below) and nowhere else.
local function possessionLines(tooltip, itemID)
	local owners, guilds = Family.Index:Owners(itemID)

	if #owners == 0 and #guilds == 0 then
		-- Silence rather than "nobody has any". A tooltip that grows a line for every
		-- item nobody owns is a tooltip nobody reads.
		return nil
	end

	local total = 0
	for _, owner in ipairs(owners) do total = total + owner.total end

	local lines = { { L["|cff66bbffFamily possessions|r"],
		total > 0 and ("|cffffd700" .. total .. "|r") or "" } }

	for _, owner in ipairs(labelled(owners)) do
		local r, g, b = classColour(owner.classFile)
		-- A sibling's name carries their family. The count means something different for
		-- them - it is not in a bag you can walk to - and a line that read the same as
		-- your own would be inviting a trip to the wrong bank.
		local label = owner.familyName
			and string.format(L["%s |cff9d9d9dof %s|r"], owner.label,
				tostring(owner.familyName))
			or owner.label
		lines[#lines + 1] = { label, placesOf(owner), r, g, b, 0.8, 0.8, 0.8 }
	end

	for _, guild in ipairs(guilds) do
		lines[#lines + 1] = { "|cff40c040" .. guild.key .. "|r",
			string.format(L["%d guild bank"], guild.count),
			nil, nil, nil, 0.8, 0.8, 0.8 }
	end

	return lines
end

--------------------------------------------------------------------------------------------
-- Recipes
--
-- The skill a recipe needs is not in any call the client offers. It is written on the item's
-- own tooltip - "Requires Tailoring (250)" - and this is the one moment that tooltip is in
-- hand, so it is read from there.
--
-- Found by looking for the profession's name, which the client has just given us in its own
-- language as the item's subtype, and taking the number out of that line. Nothing here knows
-- the word "requires" in any language, and it does not need to.
--------------------------------------------------------------------------------------------

local function requiredSkill(tooltip, profession)
	local name = tooltip.GetName and tooltip:GetName()
	if not name then return nil end

	local lines = tonumber((Family:TryCall(tooltip.NumLines, tooltip))) or 0

	for index = 1, lines do
		local widget = _G[name .. "TextLeft" .. index]
		local text = widget and widget.GetText and widget:GetText()

		if type(text) == "string" and text:find(profession, 1, true) then
			local number = text:match("(%d+)")
			if number then return tonumber(number) end
		end
	end

	return nil
end

-- How each member stands with this recipe, in as few words as a tooltip can afford.
local STATE = {
	knows   = function() return L["|cff40bf40knows it|r"] end,
	can     = function() return L["|cffffd700can learn it|r"] end,
	later   = function(who, required)
		return string.format("|cffff8040%d|r|cff888888/%d|r", who.rank or 0, required or 0)
	end,
	level   = function(who, _, minLevel)
		return string.format(L["|cffff8040level %d|r"], minLevel or 0)
	end,
	unknown = function() return L["|cff9d9d9dmay know it|r"] end,
	-- Named rather than merely refused. "Cannot learn it" leaves somebody wondering why; the
	-- branch's own name says why, and says which character to look for instead. The word comes
	-- from the client, so it is in the reader's language and no list of branches is shipped.
	branch  = function(who)
		local name = who.needs and Family:TryCall(GetSpellInfo, who.needs)
		if not name then return L["|cffff8040another branch|r"] end
		return string.format(L["|cffff8040needs %s|r"], name)
	end,
}

-- How many names either crafters block will list before it starts counting instead. A tooltip
-- that fills the screen has answered a different question from the one asked.
--
-- Declared above both of them: written below the first, it was a global there and nil, and the
-- guild half of the pattern block would have thrown the moment a guildmate turned out to know
-- one - which nothing exercised, so the harness was quiet about it.
local GUILD_CAP = 5

local function crafterLines(tooltip, itemID)
	local profession, minLevel, certain, itemName = Family.Recipes:ItemProfession(itemID)
	if not profession then return nil end

	local required = requiredSkill(tooltip, profession)

	-- A subtype naming a profession is not proof of a recipe: trade goods have one too. The
	-- client saying outright that this is a recipe is proof; failing that, a skill
	-- requirement written on the tooltip is, and a stack of arcane dust has neither.
	if not certain and not required then return nil end

	local crafters = Family.Recipes:Crafters(profession, itemName, required, minLevel, itemID)

	-- No heading unless somebody has the profession. A recipe for something nobody in the
	-- family can make is a recipe this block has nothing to say about.
	if #crafters == 0 then return nil end

	local lines = { { L["|cff66bbffFamily crafters|r"],
		required and string.format("|cff888888%s %d|r", profession, required)
			or ("|cff888888" .. profession .. "|r") } }

	for _, who in ipairs(labelled(crafters)) do
		local r, g, b = classColour(who.classFile)

		lines[#lines + 1] = {
			string.format("%s |cff888888%s|r", who.label, tostring(who.rank or "?")),
			STATE[who.state](who, required, minLevel),
			r, g, b, 1, 1, 1,
		}
	end

	-- And whoever in the guild already knows it.
	--
	-- The same question this block has always asked, from the second source: a guildmate's
	-- shared list *is* the list of recipes they know, so a pattern they are already holding
	-- is one you may not need to buy.
	--
	-- Found by the two ids a formula's own id resolves to - the spell it teaches and the item
	-- that spell makes - because a guild list holds ids, and which of the two it holds differs
	-- by client. The name is passed as well and still answers for the recipes neither table
	-- has heard of; both sides of *that* comparison are worked out by this client, from the
	-- ids that crossed (§2.1).
	--
	-- Only "knows it": the states above are about learning, and nothing in a shared list
	-- says what a guildmate could learn - only what they have.
	if Family.Guild and Family.Guild:Enabled() and itemName then
		local theirs = Family.Guild:CraftersOf(Family.Recipes:TaughtBy(itemID),
			Family.Recipes:Makes(itemID), itemName)

		for index = 1, math.min(GUILD_CAP, #theirs) do
			local who = theirs[index]
			local r, g, b = classColour(who.classFile)

			local character = tostring(who.name or who.key or "?")
			character = character:match("^([^%-]+)") or character

			lines[#lines + 1] = {
				string.format(L["%s |cff66bbff(guild)|r"], character),
				L["|cff40bf40knows it|r"], r, g, b, 1, 1, 1,
			}
		end

		if #theirs > GUILD_CAP then
			lines[#lines + 1] = { string.format(L["|cff888888and %d more|r"],
				#theirs - GUILD_CAP), "" }
		end
	end

	return lines
end

-- The same question, answered by the guild (§7.1).
--
-- A block of its own under the family's, rather than more rows in theirs: they are two
-- sources with two different kinds of certainty behind them, and a guildmate's alt is
-- somebody to whisper rather than somebody to log into.
--
-- **The character, and only the character.** A guild record is keyed by whoever sent it, so
-- the player who sent it is known - and naming them as well buys nothing here, because
-- everything §7 shares is a character *in this guild*. The crafter is therefore on the same
-- roster the reader is looking at: whisperable if online, visibly not if not. Two names where
-- one is enough is clutter on the one surface that cannot afford any.
--
-- Answered by identifier, so it needs no profession and no skill requirement read off the
-- tooltip: what crossed is the spell of each recipe and the item it makes, and hovering
-- either one matches. That is why this block appears on a crafted item where the family's
-- block, which works from the item's subtype, often cannot.
-- **Who can make this**, ours and the guild's, in one block.
--
-- One rather than two, because it is one question. Every other block on this tooltip answers
-- something a player asked - what have I got, who owns one - and splitting the answer to "who
-- can make it" by which list the answer came out of would be Family showing its own filing.
--
-- Ours first and unadorned, the guild's marked as theirs, because what you do about them
-- differs: one is a character to log into and the other is somebody to whisper. Local, and
-- defined above both routes that use it: written as a forward declaration lower down it was a
-- second local that shadowed nothing, while the definition quietly made a global - and the
-- spell route called the empty one.
-- What the right-hand column says when the thing under the cursor is on a timer.
--
-- **A cooldown outranks whatever that column would otherwise have said** - a rank, or how long
-- ago we heard from them - for the same reason the professions panel lets it outrank "can make
-- 4": a transmute nobody can do for another six hours is not one they can make, whatever else
-- is true of the crafter. Where there is no cooldown the column says exactly what it said
-- before, which is most rows on most tooltips.
--
-- The two strings are the panel's own, reused rather than restated: "ready now" and "ready in
-- three hours" already exist in five languages and mean here what they mean there.
local function readyText(cooldown)
	if not cooldown then return nil end
	if cooldown.ready then return L["|cff40bf40ready now|r"] end
	return string.format(L["|cffff8040ready %s|r"], UI:In(cooldown.readyAt))
end

local function makerLines(ours, theirs)
	local total = #ours + #theirs
	if total == 0 then return nil end

	local lines = { { L["|cff66bbffCan make it|r"],
		string.format("|cff888888%d|r", total) } }
	local room = GUILD_CAP

	for index = 1, math.min(room, #ours) do
		local who = labelled(ours)[index]
		local r, g, b = classColour(who.classFile)
		lines[#lines + 1] = {
			who.label,
			readyText(who.cooldown)
				or string.format("|cff888888%s|r", tostring(who.rank or "?")),
			r, g, b, 1, 1, 1,
		}
	end

	room = room - math.min(room, #ours)

	for index = 1, math.min(room, #theirs) do
		local who = theirs[index]
		local r, g, b = classColour(who.classFile)

		-- The realm taken off for reading: this is a name somebody is about to type into
		-- a whisper, not the lower-cased key the protocol matches on.
		local character = tostring(who.name or who.key or "?")
		character = character:match("^([^%-]+)") or character

		-- The age is kept rather than replaced, which the family's half does not need to
		-- do. Ours is read off this machine and is current; theirs is a record of an
		-- announcement made at some point in the past, and "ready" out of a record four
		-- hours old is a weaker claim than "ready" out of one from a minute ago. Saying
		-- both is what lets the reader tell those apart (§2.2).
		local age = string.format("|cff9d9d9d%s|r", UI:Ago(who.at))
		local state = readyText(who.cooldown)

		lines[#lines + 1] = {
			string.format(L["%s |cff66bbff(guild)|r"], character),
			state and (state .. " " .. age) or age,
			r, g, b, 1, 1, 1,
		}
	end

	-- A tooltip that fills the screen has answered a different question from the one asked,
	-- so the rest are counted rather than listed.
	if total > GUILD_CAP then
		lines[#lines + 1] = { string.format(L["|cff888888and %d more|r"],
			total - GUILD_CAP), "" }
	end

	return lines
end

-- On the thing itself, rather than on the pattern that teaches it.
--
-- The block above this one answers about a *recipe* - who knows it, who could learn it - and
-- it finds people by the item's subtype and the skill written on its tooltip, which only a
-- pattern carries. Hovering the robe rather than the plans for it therefore said who owned one
-- and nothing about who could make another, and once the guild's answer arrived it said who in
-- the guild could make one while staying silent about the character sitting in your own list.
--
-- Answered by identifier here, and by the name only where a client gave no identifier at all.
-- Who owns the thing that makes this, and whether theirs is ready.
--
-- Refined Deeprock Salt is on nobody's recipe list. It comes out of a Salt Shaker, which is an
-- item with a four-day cooldown - so *who can make me one* is really *who owns a shaker, and is
-- theirs ready*. Family already answered both halves separately: the index knows who owns what,
-- and a member's own record knows which of their items are counting down. What was missing was
-- the join between the salt and the shaker, which no call in the client exposes and which is
-- therefore generated (DATASOURCES §2). Reported from play: the salt showed who *had* some and
-- said nothing at all about who could make more.
--
-- **No record of a cooldown is read as ready**, because `itemCooldowns` holds the running ones
-- and drops them as they come back - so an absence is "not counting down when this member was
-- last read", which is what every other figure on this panel means too.
local function makersOwned(itemID)
	local makers = (Family.MadeByItem or {})[itemID]
	if not makers then return {} end

	local found, seen = {}, {}

	for _, maker in ipairs(makers) do
		for _, owner in ipairs(Family.Index:Owners(maker.item)) do
			if not seen[owner.key] then
				local meta = Family.Database:Meta(owner.key) or {}

				-- **Owning it is not using it.** A Salt Shaker asks 250 leatherworking of
				-- whoever picks it up, so a character can hold one and be no use at all -
				-- reported from play, and the client's own table carried the condition the
				-- whole time. Where the profession has never been read for that member,
				-- nothing is claimed and they are left out: this block is a list of people
				-- to go and ask, and a name on it that cannot help is worse than a short
				-- list.
				local able = true
				if maker.skill then
					local skill = (meta.skills or {})[maker.skill]
					able = skill ~= nil and (skill.rank or 0) >= (maker.rank or 0)
				end

				if able then
					seen[owner.key] = true

					local cooldown = { ready = true }
					for _, entry in ipairs(meta.itemCooldowns or {}) do
						if entry.id == maker.item and entry.readyAt
							and entry.readyAt > time() then
							cooldown = { ready = false, readyAt = entry.readyAt }
						end
					end

					found[#found + 1] = {
						key = owner.key, name = owner.name, realm = owner.realm,
						classFile = owner.classFile, familyName = owner.familyName,
						cooldown = cooldown,
					}
				end
			end
		end
	end

	return found
end

local function makerBlock(_, itemID)
	-- Not on a pattern. A profession window lists the crafting *spells* a character has
	-- learnt, and a pattern in a bag or an auction house is the book that teaches one - two
	-- different things, and two different questions. Hovering the plans asks who knows the
	-- recipe, which the block above answers; hovering what the plans make asks who can make
	-- another, which is this one.
	--
	-- Without this they overlap on exactly one shape of item: a pattern whose recipe carries
	-- no id of what it makes, where the name fallback below recognises "Plans: X" as teaching
	-- "X" and answers a question the block above has already answered better.
	local certain = select(3, Family.Recipes:ItemProfession(itemID))
	if certain then return nil end

	local itemName = Family.Names:CachedItem(itemID)

	local ours = Family.Recipes:KnowersOf(nil, itemID, itemName)
	local theirs = (Family.Guild and Family.Guild:Enabled())
		and Family.Guild:CraftersOf(nil, itemID, itemName) or {}

	-- And whoever owns the item that makes it, where a recipe is not what makes it. Added
	-- rather than replacing: nothing stops a thing being both, and a member who turns up
	-- twice would read as two.
	local seen = {}
	for _, who in ipairs(ours) do seen[who.key] = true end
	for _, who in ipairs(makersOwned(itemID)) do
		if not seen[who.key] then ours[#ours + 1] = who end
	end

	return makerLines(ours, theirs)
end

--------------------------------------------------------------------------------------------
-- Hooking
--
-- OnTooltipSetItem can fire more than once for the same tooltip, so each one remembers what
-- it last described and refuses to say it twice. Without that, moving the cursor along a row
-- of bags leaves a tooltip with the same block on it three times.
--------------------------------------------------------------------------------------------

local lastDescribed = {}

-- A recipe that makes nothing has no item tooltip to appear on.
--
-- An enchant is a spell and produces no object, so there is nothing in the world to hover:
-- it is seen in a trade skill window, in a recipe link somebody posted, and on Family's own
-- panels. Everything above this hooks OnTooltipSetItem, so the one profession whose answers
-- are most worth having was the one profession that could never be asked.
--
-- Answered by id here, and only by id: a spell tooltip states which spell it is, and that is
-- the same number the guild sent. No name is involved at all, which the item route cannot
-- always manage.
local function onSpell(tooltip, spellID)
	if not tooltip then return end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return end
	if not (FamilyDB and FamilyDB.tooltips ~= false) then return end

	if not spellID and tooltip.GetSpell then
		spellID = select(2, tooltip:GetSpell())
	end
	if not spellID then return end

	-- The same guard the item route uses, and the same reason: OnTooltipSetSpell can fire
	-- more than once for one tooltip, and a block added twice reads as a fault.
	if lastDescribed[tooltip] == "spell:" .. spellID then return end
	lastDescribed[tooltip] = "spell:" .. spellID

	-- The same block as the item route, because it is the same question: a recipe's own
	-- tooltip is simply the only place an enchant can be asked it.
	local ours = Family.Recipes:KnowersOf(spellID)
	local theirs = (Family.Guild and Family.Guild:Enabled())
		and Family.Guild:CraftersOf(spellID, nil, nil) or {}

	local lines = makerLines(ours, theirs)
	if not lines then return end

	tooltip:AddLine(" ")
	for index, line in ipairs(lines) do
		if index == 1 then
			tooltip:AddDoubleLine(line[1], line[2], 0.4, 0.73, 1, 0.53, 0.53, 0.53)
		else
			tooltip:AddDoubleLine(line[1], line[2], line[3] or 1, line[4] or 1,
				line[5] or 1, line[6] or 0.61, line[7] or 0.61, line[8] or 0.61)
		end
	end
	tooltip:AddLine(" ")
	tooltip:Show()
end

local function onItem(tooltip, itemID)
	if not tooltip then return end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return end
	if not (FamilyDB and FamilyDB.tooltips ~= false) then return end

	-- The newer route hands the item over; the older one has to be asked. Either may be
	-- the one that fires on a given client, so both are accepted.
	if not itemID and tooltip.GetItem then
		local _, link = tooltip:GetItem()
		itemID = itemIDFrom(link)
	end
	if not itemID then return end

	if lastDescribed[tooltip] == itemID then return end
	lastDescribed[tooltip] = itemID

	-- Worked out before anything is written, because a tooltip has no way to take a line
	-- back off. Each block that has something to say is preceded by one blank line and the
	-- last is followed by one - so two blocks are separated by exactly one gap, and a block
	-- with nothing to say leaves no trace at all.
	--
	-- Family is rarely the only addon writing on a tooltip. Without the closing line,
	-- whatever is added next reads as part of this list.
	local blocks = {}

	for _, build in ipairs { possessionLines, crafterLines, makerBlock } do
		local lines = build(tooltip, itemID)
		if lines and #lines > 0 then blocks[#blocks + 1] = lines end
	end

	if #blocks == 0 then return end

	for _, lines in ipairs(blocks) do
		tooltip:AddLine(" ")
		for _, line in ipairs(lines) do
			if line[2] then
				tooltip:AddDoubleLine(line[1], line[2], line[3], line[4], line[5],
					line[6], line[7], line[8])
			else
				tooltip:AddLine(line[1])
			end
		end
	end

	tooltip:AddLine(" ")
	tooltip:Show()
end

local function forget(tooltip)
	lastDescribed[tooltip] = nil
end

local function hookClears(tooltip)
	if not tooltip or not tooltip.HookScript then return end
	tooltip:HookScript("OnTooltipCleared", forget)
	tooltip:HookScript("OnHide", forget)
end

local function hookSetItem(tooltip)
	if not tooltip or not tooltip.HookScript then return end
	tooltip:HookScript("OnTooltipSetItem", function(self) onItem(self) end)
end

local function hookSetSpell(tooltip)
	if not tooltip or not tooltip.HookScript then return end
	tooltip:HookScript("OnTooltipSetSpell", function(self) onSpell(self) end)
end

Family:OnDatabaseReady("tooltips", function()
	local tooltips = { _G.GameTooltip, _G.ItemRefTooltip,
		_G.ShoppingTooltip1, _G.ShoppingTooltip2 }

	-- Whichever route ends up firing, the guard has to be reset when a tooltip is put
	-- away, or the same item hovered twice in a row shows the block only once.
	for _, tooltip in ipairs(tooltips) do hookClears(tooltip) end

	-- Both routes are registered rather than one or the other.
	--
	-- Mists Classic runs on a newer engine than its expansion suggests and has the modern
	-- tooltip system, so the old OnTooltipSetItem hook is not what fires there. But taking
	-- the modern branch *instead* was worse: the post-call is handed the item in its data
	-- rather than leaving it on the tooltip, so asking GetItem for it came back with
	-- nothing and the block was silently never added.
	--
	-- Registering both is safe because the guard above refuses to describe the same item
	-- on the same tooltip twice, which is the same thing that stops the older hook
	-- repeating itself when it fires more than once.
	local modern = false

	-- Kept reachable so the harness can fire it: this is the route that failed silently in
	-- the game, and a test that cannot call it cannot catch that happening again.
	UI.__modernCallback = function(tooltip, data)
		onItem(tooltip, data and data.id)
	end

	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
		and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		local ok = pcall(TooltipDataProcessor.AddTooltipPostCall,
			Enum.TooltipDataType.Item, UI.__modernCallback)
		modern = ok and true or false
	end

	for _, tooltip in ipairs(tooltips) do hookSetItem(tooltip) end

	-- And the same pair of routes for spells, which is where an enchant lives.
	UI.__modernSpellCallback = function(tooltip, data)
		onSpell(tooltip, data and data.id)
	end

	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
		and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell then
		pcall(TooltipDataProcessor.AddTooltipPostCall,
			Enum.TooltipDataType.Spell, UI.__modernSpellCallback)
	end

	for _, tooltip in ipairs(tooltips) do hookSetSpell(tooltip) end

	Family.tooltipRoute = modern and "both" or "classic"
	Family:Debug("tooltip hooks installed: %s", Family.tooltipRoute)
end)

--------------------------------------------------------------------------------------------
-- Putting Family's own rows on the game's tooltip
--
-- Every panel that lists an item wants the real tooltip on mouseover, and none of them
-- should each work out how. Given a frame and something to identify the item by, this makes
-- it behave like a bag slot does.
--------------------------------------------------------------------------------------------

-- Every kind of thing Family lists that the game will describe, and how to ask it.
--
-- Each entry tries the direct call first and a constructed link second. Both exist because
-- neither is on every client: SetItemByID arrived partway through these clients' lives, and
-- a link works everywhere but says nothing at all for a kind the client does not know.
--
-- None of them can be trusted to report success - SetItemByID returns nothing whether it
-- worked or not - so what actually happened is read off the tooltip afterwards.
local function wroteAnything()
	local lines = Family:TryCall(GameTooltip.NumLines, GameTooltip)
	return (tonumber(lines) or 0) > 0
end

local SHOW = {
	item = function(id)
		Family:TryCall(GameTooltip.SetItemByID, GameTooltip, id)
		if not wroteAnything() then
			Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id)
		end
	end,

	-- A worn item, as it really is: the item plus its enchant, its gems and its patch. An
	-- item string carries all of that and an item id carries none of it, which is why gear
	-- is the one place Family keeps the longer form.
	itemlink = function(item)
		Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, item)
	end,

	spell = function(id)
		Family:TryCall(GameTooltip.SetSpellByID, GameTooltip, id)
		if not wroteAnything() then
			Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. id)
		end
	end,

	quest = function(id)
		Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "quest:" .. id)
	end,

	-- Honor and arena points on the clients that keep no currency list have no id at all,
	-- so nothing reaches here for those and the recorded lines are shown instead.
	currency = function(id)
		Family:TryCall(GameTooltip.SetCurrencyByID, GameTooltip, id)
		if not wroteAnything() then
			Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "currency:" .. id)
		end
	end,

	achievement = function(id)
		-- An achievement link carries far more than an id - who earned it and when - and
		-- the client fills the rest in from the zeroes. The guid is the player's own
		-- because that is what the game puts there; it decides nothing but the "earned
		-- by" line, and this member may not be the player anyway.
		local guid = Family:TryCall(UnitGUID, "player") or "0"
		Family:TryCall(GameTooltip.SetHyperlink, GameTooltip,
			string.format("achievement:%d:%s:0:0:0:0:0:0:0:0", id, tostring(guid)))
	end,

	talent = function(id)
		Family:TryCall(GameTooltip.SetTalent, GameTooltip, id)
		if not wroteAnything() then
			Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "talent:" .. id)
		end
	end,

	-- A talent in a tree, by where it sits. There is no id to ask about on these clients -
	-- which is why talent names are the one thing Family stores as words - but the game
	-- will describe the talent at a given tab and index, and for a member of the player's
	-- own class those are the same talents in the same places.
	--
	-- Which call does that differs by client, and the difference cannot be asked about: a
	-- setter that is missing and a setter that describes nothing both come back as silence
	-- (Family:TryCall), which is exactly how this went unnoticed - the panel fell back to
	-- Family's own three lines and looked like a tooltip that had simply not been finished.
	--
	-- So they are tried in turn and the first that writes something is kept, the same way the
	-- talent scanner picks its reader. Nothing here assumes which client it is on.
	talentslot = function(slot)
		if type(slot) ~= "table" then return end
		UI:DescribeTalentSlot(slot)
	end,
}

local talentRoutes = {
	{
		how = "SetTalent(tab, index)",
		call = function(slot)
			Family:TryCall(GameTooltip.SetTalent, GameTooltip, slot.tab, slot.index)
		end,
	},
	{
		-- The tree clients that grew a second specialisation want to be told which one,
		-- and the two before them ignore the extra arguments.
		how = "SetTalent(tab, index, false, false, group)",
		call = function(slot)
			Family:TryCall(GameTooltip.SetTalent, GameTooltip, slot.tab, slot.index,
				false, false, slot.group)
		end,
	},
	{
		-- A different call altogether, for the clients whose tooltip no longer has a
		-- talent setter at all. A link describes itself.
		how = "SetHyperlink(GetTalentLink(tab, index))",
		call = function(slot)
			local link = Family:TryCall(GetTalentLink, slot.tab, slot.index,
				false, false, slot.group)
			if type(link) == "string" then
				Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, link)
			end
		end,
	},
}

-- The one that has worked, once one has. Kept so that hovering a tree is not four failed
-- calls per talent, and reported once so a client that needs a fifth route can say so.
local talentRoute

function UI:DescribeTalentSlot(slot)
	if talentRoute then
		talentRoute.call(slot)
		if wroteAnything() then return true end
		-- It answered once and does not now. That is not proof it is the wrong route, but
		-- it is no reason to stop the others being tried.
		Family:TryCall(GameTooltip.ClearLines, GameTooltip)
	end

	for _, route in ipairs(talentRoutes) do
		route.call(slot)
		if wroteAnything() then
			if talentRoute ~= route then
				talentRoute = route
				Family:Debug("talent tooltips: %s", route.how)
			end
			return true
		end
		Family:TryCall(GameTooltip.ClearLines, GameTooltip)
	end

	return false
end

-- The one way any row in any panel opens a tooltip.
--
-- `resolve` is given the row and answers what it is: a kind and an id the game can describe,
-- and optionally a list of { left, right } lines to fall back on. The fallback matters more
-- than it looks - a talent in a tree has no id of any sort on these clients (Talents.lua
-- says why at length), so the only thing that can be shown for one is what Family recorded
-- about it, and showing that is better than a row that answers nothing on hover.
--
-- A row whose resolve returns nothing gets no tooltip, and a kind the client turns out not
-- to know gets the fallback rather than an empty frame.
function UI:AttachTooltip(frame, resolve)
	frame:EnableMouse(true)

	frame:SetScript("OnEnter", function(self)
		local kind, id, fallback = resolve(self)
		if not kind and not fallback then return end

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		Family:TryCall(GameTooltip.ClearLines, GameTooltip)

		local show = kind and SHOW[kind]
		if show and id then show(id) end

		if not wroteAnything() then
			if not fallback or #fallback == 0 then
				GameTooltip:Hide()
				return
			end

			for _, line in ipairs(fallback) do
				if line[2] then
					GameTooltip:AddDoubleLine(line[1], line[2])
				else
					GameTooltip:AddLine(line[1])
				end
			end
		end

		GameTooltip:Show()
	end)

	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- The two that came first, kept because an item row is by far the commonest case and reads
-- better named than as a kind passed in.
function UI:AttachItemTooltip(frame, getItemID)
	UI:AttachTooltip(frame, function(self)
		return "item", getItemID(self)
	end)
end

function UI:AttachSpellTooltip(frame, getSpellID)
	UI:AttachTooltip(frame, function(self)
		return "spell", getSpellID(self)
	end)
end
