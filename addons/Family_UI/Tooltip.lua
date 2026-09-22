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

-- **The link behind the tooltip, which is the only thing that says which variant this is.**
--
-- An item id names the plain item; a random-enchantment one is that id plus a suffix, and the
-- suffix is the whole of what tells *of the Bear* from *of the Whale* (backlog 67). So the
-- possessions and worth blocks need the link, not the number.
--
-- Two routes because neither is on every client, which is already why both tooltip hooks are
-- registered a few hundred lines below. The newer one hands the item over in its data and leaves
-- nothing on the tooltip - measured, and the reason taking that branch *instead* made the whole
-- block vanish on Mists. The older one leaves it on the tooltip and hands over nothing.
--
-- `data.hyperlink` is read rather than assumed: where it is absent the tooltip is asked, and
-- where both come back with nothing the id alone is used and the answer is the one Family gave
-- before variants existed. Nothing here can be worse than that.
local function linkFrom(tooltip, data)
	if type(data) == "table" and type(data.hyperlink) == "string" then
		return data.hyperlink
	end

	if tooltip and tooltip.GetItem then
		local _, link = Family:TryCall(tooltip.GetItem, tooltip)
		if type(link) == "string" then return link end
	end

	return nil
end

-- How many, and where they are: "37 (17 bags, 20 bank)".
--
-- Moved to `UI:HeldWhere` in Window.lua when the possessions search started saying the same
-- thing in its right-hand column, which is where the reasoning behind the wording now lives.
-- Kept as a name here because this file asks for it in three places.
local function placesOf(owner)
	return UI:HeldWhere(owner)
end

-- Whose character it is, where it is not one of ours.
--
-- Three blocks on this tooltip say it and they all say it the same way, which is the point: a
-- count or a rank against a bare name reads as *I can go and get that*, and for somebody else's
-- character it is not true. Said here once rather than three times.
local function whose(who)
    if not who.familyName then return who.label end
    return string.format(L["%s |cff9d9d9dof %s|r"], who.label, tostring(who.familyName))
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
-- How many names a block will list before it starts counting instead. A tooltip that fills the
-- screen has answered a different question from the one it was asked.
--
-- **Declared above every block that uses one.** Written below the first, a local is a global
-- there and a global is nil - and `UI:ShowAtMost` given a nil cap quietly returns the whole list
-- rather than throwing, so the contraction would simply not happen and nothing would say so
-- (L-069). The crafters block was moved up here for the same reason before it.
--
-- Two numbers because the questions are different sizes. *Who can make this* is answered by a
-- handful of names; *who has one* can be answered by a whole family, and the owners block is the
-- one somebody reads on an item two hundred characters happen to carry.
-- How many names a block may list on *this* tooltip: its own cap while folding is on, and what
-- the screen has left when it is off.
--
-- **What the tooltip already holds is asked of the tooltip**, not guessed: the item's own text and
-- whatever every other addon put there before Family was called. Alberto, 2026-09-16, asked the
-- question that decides the shape of this - *IF Family is the last one building something.
-- Otherwise how can you know it?* - and the answer is that Family cannot: an addon whose hook runs
-- after ours adds lines nothing here can see, and no call reports them. So this number is a floor
-- and is treated as one, which is what the ceiling inside `UI:TooltipCap` is for.
--
-- **Declared above the first block that uses one**, which is the rule this file already carries for
-- its caps: written below, a local is a global there and a global is nil (L-069).
-- **Whether the key this hint offers can reach Family at all on this tooltip.**
--
-- Asked by Alberto 2026-09-16, having found the hint offered where it does nothing: *would it be
-- possible to avoid printing the dim CTRL hint when hovering over unsupported slots?*
--
-- An action bar slot is the case. Family cannot repaint a tooltip it does not own, so the key works
-- only where the frame's owner re-shows the tooltip when a modifier changes - a bag addon does
-- (Bagnon was read doing it on Era), and a bar does not, because every action bar addon takes
-- control, shift and alt for a slot's second and third binding. The hint is drawn for a reader, and
-- a reader who presses the key there is told nothing at all.
--
-- **Read off the frame rather than by the addon's name.** A slot on any bar - Dominos, Bartender,
-- the game's own - is a secure action button, and a secure action button is the one thing here that
-- can be asked what it is: it carries the `action` attribute the client casts from. Nothing is
-- assumed about which addon drew it.
--
-- The answer only ever removes the offer. With the key already held, the lines it asks for are
-- drawn exactly as they are anywhere else - which is what a reader who holds it first sees.
local function ownerKeepsModifiers(tooltip)
	local owner = tooltip and tooltip.GetOwner and (Family:TryCall(tooltip.GetOwner, tooltip))
	if not (owner and owner.GetAttribute) then return false end

	if (Family:TryCall(owner.GetAttribute, owner, "action")) ~= nil then return true end
	return (Family:TryCall(owner.GetAttribute, owner, "type")) == "action"
end

local function roomFor(tooltip, cap)
	local used = tonumber((Family:TryCall(tooltip and tooltip.NumLines, tooltip))) or 0
	return UI:TooltipCap(cap, used)
end

local OWNER_CAP = 10
local GUILD_CAP = 5

-- **When this owner's one can next be used**, where it is counting down.
--
-- Reported from play 2026-09-19: a Salt Shaker used on Deiana said *2 Days 23 Hrs* on her own
-- tooltip, and hovered from anybody else's the line with her name on it said where it was and
-- nothing about the wait - while the record had it all along. The same for a Chronoboon.
--
-- Running only, and the soonest of several: an absence is "not counting down when this member
-- was last read" and not a claim that it is ready, for the reason `Cooldowns:For` gives - an
-- item is used out of the bags with nothing open for Family to see. The record is keyed by the
-- base item, so this is asked by id and not by variant.
--
-- Through `UI:Meta`, because the owners include a linked family's characters.
local function runningFor(key, itemID)
	local soonest
	for _, entry in ipairs((UI:Meta(key) or {}).itemCooldowns or {}) do
		if entry.id == itemID and entry.readyAt and entry.readyAt > time()
			and (not soonest or entry.readyAt < soonest) then
			soonest = entry.readyAt
		end
	end
	return soonest
end

-- **Whose possessions, and of what**, where the thing counted is not the thing hovered.
--
-- On an item's own tooltip the subject is the line above and a bare heading is right: twenty,
-- of the thing whose name is at the top. On a rock in the ground it is not. Reported by Alberto
-- 2026-09-22, looking at a Copper Vein with *Family possessions 20* under it: twenty of what?
-- Twenty veins is a perfectly fair reading of that tooltip, and the ore is never named anywhere
-- on it. The name comes from the client, by the id the route resolved - the whole entry ships
-- no word of any language and this is not the place to start.
local function possessionHeading(named)
	if named then
		return string.format(L["|cff66bbffFamily possessions: %s|r"], named)
	end
	return L["|cff66bbffFamily possessions|r"]
end

-- **Asked by variant** (backlog 67). Hovering a Superior Sword *of the Bear* says how many of
-- *those* the family has, not how many swords of that id in any suffix - which is what Alberto
-- asked for in as many words and what the collapsed key was getting wrong.
--
-- `node` is the rock in the ground where the block is drawn on one, carrying what the client
-- calls the thing it yields, and nil where the subject is an item somebody could click.
local function possessionLines(tooltip, itemID, variant, node)
	local owners, guilds = Family.Index:Owners(variant or itemID)

	if #owners == 0 and #guilds == 0 then
		-- Silence rather than "nobody has any". A tooltip that grows a line for every
		-- item nobody owns is a tooltip nobody reads.
		return nil
	end

	local total = 0
	for _, owner in ipairs(owners) do total = total + owner.total end

	local lines = { { possessionHeading(node and node.named),
		total > 0 and ("|cffffd700" .. total .. "|r") or "" } }

	-- **A family can be bigger than a tooltip.**
	--
	-- Asked 2026-09-12: two hundred and ten characters, nearly all carrying a Runecloth Bag.
	-- This block wrote one line an owner and nothing stopped it, so that tooltip was two
	-- hundred and eleven lines - off the top of the screen, and the item's own text with it.
	-- Every other list in the addon had been given the treatment and this one had been missed.
	--
	-- The list arrives sorted by how many each holds and then by name (`Index:Owners`), so the
	-- ones drawn are the ones worth walking to. `UI:ShowAtMost` is the rule the rest of the
	-- addon uses, and it is a cap on what is worth **hiding**: eleven owners draw eleven,
	-- because a line reading *and 1 more* costs exactly the line it hides.
	--
	-- The count the hidden ones hold goes in the right-hand column, where every other line in
	-- this block already carries a count - so the header's total still adds up, which is the
	-- whole reason somebody reads this block on an item they own hundreds of.
	-- Where a cursor holds several nodes at once the room is shared between their blocks, so the
	-- cap arrives from the caller; everywhere else it is this block's own.
	local shown = UI:ShowAtMost(#owners, (node and node.owners)
		or roomFor(tooltip, OWNER_CAP))
	local named = labelled(owners)

	for index = 1, shown do
		local owner = named[index]
		local r, g, b = classColour(owner.classFile)
		-- A sibling's name carries their family. The count means something different for
		-- them - it is not in a bag you can walk to - and a line that read the same as
		-- your own would be inviting a trip to the wrong bank.
		local where = placesOf(owner)
		local waits = runningFor(owner.key, itemID)
		if waits then
			where = where .. " " .. string.format(L["|cffff8040ready %s|r"], UI:In(waits))
		end
		lines[#lines + 1] = { whose(owner), where, r, g, b, 0.8, 0.8, 0.8 }
	end

	-- **Whether the gesture is worth offering on this tooltip at all.**
	--
	-- Three conditions, and none of them is about how long the list is. `ItemClickArmed` says the
	-- hook is installed, so a modified click reaches Family on this client rather than on a client
	-- somebody hopes is the same. `ownerKeepsModifiers` says the frame under the pointer is a
	-- secure action button - an action bar slot, whoever drew it - where control and alt are the
	-- slot's own second and third bindings and the click is a cast rather than an item click.
	-- The CTRL hints a few hundred lines below are kept off a bar by the same test for a
	-- different reason: there the key never arrives, here the click never routes. One offer that
	-- does nothing is worth as little as the other.
	--
	-- **And the third is the subject.** The gesture rides `HandleModifiedItemClick`, which the
	-- client calls for a click on an *item* - a bag slot, a link in chat, a worn piece. A vein in
	-- the ground is not one, and neither is a blip on the minimap or a pin on the world map. Both
	-- tests above ask about the client and the frame, and nothing in this block had ever had to
	-- ask what it was drawn on, because until backlog 96 every caller was an item. Reported by
	-- Alberto 2026-09-22 off three screenshots: the note was under all three of them, promising a
	-- gesture that cannot fire - and on the world node it is worse than a promise nothing keeps,
	-- because control and alt and a click on a rock is a click on a rock, and the reader who
	-- takes the tooltip at its word mines the thing they were only asking about.
	local offers = UI.ItemClickArmed and UI:ItemClickArmed()
		and not ownerKeepsModifiers(tooltip)
		and not node

	if shown < #owners then
		local rest = 0
		for index = shown + 1, #owners do rest = rest + (owners[index].total or 0) end

		lines[#lines + 1] = { string.format(L["|cff888888and %d more|r"], #owners - shown),
			"|cff888888" .. rest .. "|r", nil, nil, nil, 0.5, 0.5, 0.5 }

		-- **And where the rest of them are**, because a contraction on this block is not the
		-- same as one on the crafters block. *Who can make it* is answered by three or four
		-- names and the rest are spares; *who has one* is a list somebody may genuinely need
		-- all of - they are deciding which character to log in as. So the tooltip says where
		-- the whole of it lives rather than leaving them to find it.
		--
		-- Both names come from the same table the panel draws its own from, so the note is in
		-- the reader's language and says what is actually written on the screen.
		-- **The shortest way there, where this client offers one.** A modified click on the
		-- item opens exactly that page already filtered to it (ItemClick.lua), which is worth
		-- saying instead of the directions - and where the hook could not be installed, the
		-- directions are still true.
		lines[#lines + 1] = { offers and L["|cff888888(CTRL-ALT-click to open the family's list)|r"]
			or string.format(
				L["|cff888888the whole list is on Family's %s page, under %s|r"],
				L["Possessions"], L["Whole family"]), "", 0.5, 0.5, 0.5 }

	-- **And on a list drawn whole, the gesture is still worth saying.** Alberto, 2026-09-17, on
	-- finding it mentioned nowhere but under a contraction: the click works on every one of these
	-- tooltips and was advertised only on the ones too long to draw, so a family of four never met
	-- it. A contraction is a reason a reader *needs* the page; it was never what makes the gesture
	-- available, and the two had been the same line since it was built.
	--
	-- The directions have no second home here, which is the asymmetry and it is deliberate: where
	-- the whole list is already on the screen there is nothing to send anybody to a panel for, so
	-- an unarmed client draws nothing rather than a note pointing at what the reader is looking at.
	elseif offers then
		lines[#lines + 1] = { L["|cff888888(CTRL-ALT-click to open the family's list)|r"],
			"", 0.5, 0.5, 0.5 }
	end

	-- The guild banks under them, capped the same way and by the same reasoning: a family
	-- this size has more than one guild, and this block is already the longest on the tooltip.
	local guildsShown = UI:ShowAtMost(#guilds, roomFor(tooltip, GUILD_CAP))

	for index = 1, guildsShown do
		local guild = guilds[index]
		lines[#lines + 1] = { "|cff40c040" .. UI:GuildLabel(guild.key) .. "|r",
			string.format(L["%d guild bank"], guild.count),
			nil, nil, nil, 0.8, 0.8, 0.8 }
	end

	if guildsShown < #guilds then
		local rest = 0
		for index = guildsShown + 1, #guilds do rest = rest + (guilds[index].count or 0) end

		lines[#lines + 1] = { string.format(L["|cff888888and %d more|r"], #guilds - guildsShown),
			"|cff888888" .. rest .. "|r", nil, nil, nil, 0.5, 0.5, 0.5 }
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
			string.format("%s |cff888888%s|r", whose(who), tostring(who.rank or "?")),
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

		-- One over the cap is drawn whole: a line reading "and 1 more" costs the line the
		-- name would have cost (UI:ShowAtMost).
		local shown = UI:ShowAtMost(#theirs, roomFor(tooltip, GUILD_CAP))

		for index = 1, shown do
			local who = theirs[index]
			local r, g, b = classColour(who.classFile)

			local character = tostring(who.name or who.key or "?")
			character = character:match("^([^%-]+)") or character

			lines[#lines + 1] = {
				string.format(L["%s |cff66bbff(guild)|r"], character),
				L["|cff40bf40knows it|r"], r, g, b, 1, 1, 1,
			}
		end

		if shown < #theirs then
			lines[#lines + 1] = { string.format(L["|cff888888and %d more|r"],
				#theirs - shown), "" }
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

local function makerLines(tooltip, ours, theirs)
	local total = #ours + #theirs
	if total == 0 then return nil end

	local lines = { { L["|cff66bbffCan make it|r"],
		string.format("|cff888888%d|r", total) } }
	-- One over the cap is drawn whole, here as everywhere: the contraction line costs the
	-- line the name would have cost (UI:ShowAtMost).
	local shown = UI:ShowAtMost(total, roomFor(tooltip, GUILD_CAP))
	local room = shown

	for index = 1, math.min(room, #ours) do
		local who = labelled(ours)[index]
		local r, g, b = classColour(who.classFile)
		lines[#lines + 1] = {
			whose(who),
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
	if shown < total then
		lines[#lines + 1] = { string.format(L["|cff888888and %d more|r"],
			total - shown), "" }
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
				-- Through `UI:Meta`, because `Index:Owners` answers with borrowed keys as
				-- well as our own. Asked of the database, a linked family's character came
				-- back with no professions at all and was dropped by the rank test below -
				-- which reads exactly like the deliberate case a line down, where somebody
				-- whose profession has never been read is left out.
				local meta = UI:Meta(owner.key) or {}

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

local function makerBlock(tooltip, itemID)
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

	-- **The spell that makes it, from the shipped tables, before any name.** Without it a wand -
	-- whose recipes on Burning Crusade and Mists carry the spell and not the item - was matched
	-- by name against every recipe of every list not in the reader's language, asking the client
	-- for a spell name each time; one of the two *script ran too long* reports of 2026-09-13
	-- stopped exactly there (data-path review, §1 and §3 step 2).
	local ours = Family.Recipes:KnowersOf(Family.Recipes:MadeBy(itemID), itemID, itemName)
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

	return makerLines(tooltip, ours, theirs)
end

-- **What a vendor pays, and what a vendor charges.** Off unless asked for.
--
-- Two numbers of very different standing, which is why they are built here together rather than
-- taken for one feature. The **sell** price comes with the item: the client hands it to any addon
-- that asks, everywhere, exactly. The **buy** price is only ever a thing Family was shown - the
-- client's own table carries a buy price for Sulfuras, which is forged and sold by nobody
-- (`docs/DATASOURCES.md` §3) - so it is drawn only for items seen on a merchant's own list, where
-- being for sale is not an inference.
--
-- Not on by default. It is the one thing Family puts on a tooltip that is not about the family.
-- **How many are in the pile the pointer is on**, where the pointer is on a pile at all.
--
-- A tooltip does not carry a stack size, so this asks the frame the tooltip was opened for.
-- Two places can answer, and neither is guaranteed of an arbitrary frame: a container button
-- is its slot and its parent is its bag, with newer clients putting the bag on the button as
-- well; an auction row is an index into the browse list the client is holding.
--
-- **So the guess is checked before it is used.** Whatever the frame chain suggests has to
-- actually hold the item the tooltip is describing; where it does not, this answers nothing and
-- the stack line is not drawn. A wrong guess therefore costs a missing line rather than a wrong
-- number, which is the only trade worth making - a count against the wrong item would read
-- exactly like a right one. That rule was written into backlog 62 before the reading was taken
-- rather than after it, and it is what makes an unknown frame safe to ask.
local function ownerChain(tooltip)
	if not (tooltip and tooltip.GetOwner) then return nil, nil end

	local owner = Family:TryCall(tooltip.GetOwner, tooltip)
	if type(owner) ~= "table" then return nil, nil end

	local parent = owner.GetParent and Family:TryCall(owner.GetParent, owner) or nil
	return owner, type(parent) == "table" and parent or nil
end

local function idOf(frame)
	if type(frame) ~= "table" or type(frame.GetID) ~= "function" then return nil end
	return tonumber((Family:TryCall(frame.GetID, frame)))
end

local function bagCount(owner, parent, itemID)
	local slot = idOf(owner)
	local bag = owner.bagID
	if bag == nil then bag = idOf(parent) end

	if not Family.Bags then return nil end
	local found, count = Family.Bags:SlotContents(bag, slot)
	if found ~= itemID then return nil end

	count = tonumber(count)
	return count and count > 1 and count or nil
end

-- **Which row of the browse list a frame is showing.**
--
-- Backlog 62 held this back for two days on the grounds that away from the bags there is nothing
-- to check a count against. The reading taken 2026-09-12 found the chain - the owner is a
-- `BrowseButtonNItem` whose own id is nought, its parent is `BrowseButtonN` with id N - and the
-- first version stopped there, treating N as the row and trusting `GetAuctionItemLink` to catch
-- it if it was not.
--
-- **That check was worthless and the reading that found it out was one hover.** Reported from
-- play the same day: unscrolled the counts are right, scrolled the tooltip claims a stack of ten
-- over a stack of five. Two faults at once, and the second is the one that matters.
--
-- The first: N is the **slot on the screen**, not the row in the list. The client names its
-- fifteen buttons once and never renumbers them, so scrolled down three rows the fifth button is
-- showing the eighth auction.
--
-- The second, and the reason the first was not caught: **a browse list is a list of one item.**
-- Somebody searching for Linen Cloth is looking at twenty rows of Linen Cloth, so *the link at
-- this index matches the tooltip* is satisfied by every row on the page - the wrong one included.
-- A check a sibling can satisfy is not a check, and this one read as one right up until it was
-- pointed at a scrolled list. L-087.
--
-- So the row is worked out properly and the check goes back to being a check rather than the
-- thing holding the feature up.
--
-- **Identity, not a name.** `_G["BrowseButton5"]` being this very frame is what says the client's
-- own browse list is under the pointer - and therefore that `BrowseScrollFrame` is the scroll
-- frame governing it. Matching the frame's name as a string would accept anything that happened
-- to be called that; comparing the objects cannot. Where the frame is somebody else's, or the
-- offset cannot be read at all, this answers nothing and no line is drawn.
local function browseIndexOf(frame)
	-- The nil is refused because the line below would concatenate it and take a tooltip down
	-- with it. **A slot of nought is not refused separately**, and used to be: `BrowseButton0`
	-- is not a frame the client has, so the identity test already answers no - a second guard
	-- in front of it was one nothing could reach, and the mutation aimed at it survived every
	-- run because it described a fault that cannot happen (L-086).
	local slot = idOf(frame)
	if not slot then return nil end
	if _G["BrowseButton" .. slot] ~= frame then return nil end

	local offset = tonumber((Family:TryCall(_G.FauxScrollFrame_GetOffset,
		_G.BrowseScrollFrame)))
	if not offset then return nil end

	return offset + slot
end

-- **Checked on the variant and not on the id**, because a browse list is also where two rows of
-- one item id sit next to each other wearing different suffixes. Comparing the numbers would
-- call *of the Bear* a match for *of the Whale*.
--
-- It is a sanity check on the arithmetic above and no longer the thing the feature stands on:
-- it catches an index that has landed on a different item, and cannot catch one that has landed
-- on another row of the same one.
local function auctionRowCount(index, variant)
	local link = Family:TryCall(GetAuctionItemLink, "list", index)
	if type(link) ~= "string" then return nil end
	if Family:VariantKey(itemIDFrom(link), link) ~= variant then return nil end

	local _, _, count = Family:TryCall(GetAuctionItemInfo, "list", index)
	count = tonumber(count)
	return count and count > 1 and count or nil
end

-- **A merchant's row, which the client can also be asked about by index.**
--
-- Read from play 2026-09-12, and the chain is the auction row's turned around: the owner is
-- `MerchantItem8ItemButton` carrying id **8**, and its parent `MerchantItem8` carries nought.
-- So the walk below has to try both ends, which it already did.
--
-- `GetMerchantItemInfo` was read rather than recalled, every return printed and numbered:
--
--     1=Wall Shield  2=134949  3=1839  4=1  5=-1  6=false  7=false  8=false
--
-- name, texture, price, **quantity**, how many are left, and three flags. The fourth is the
-- one wanted - what one purchase hands over - and it is the position this whole probe existed
-- to establish rather than assume.
--
-- Identity again, and for the reason L-087 gives: the frame must be one of the client's own
-- merchant buttons, not something that merely carries a number.
local function merchantIndexOf(frame)
	local index = idOf(frame)
	if not (index and index > 0) then return nil end

	-- The buttons are named by their **slot on the page** and carry the index into the
	-- merchant's list, which on the first page are the same number - so the frame is looked
	-- for among the slots rather than found by building its name out of its own id. A vendor
	-- with two pages would answer `MerchantItem18ItemButton` to the second, and there is no
	-- such frame.
	local slots = tonumber(_G.MERCHANT_ITEMS_PER_PAGE) or 12
	for slot = 1, slots do
		if _G["MerchantItem" .. slot .. "ItemButton"] == frame then return index end
	end

	return nil
end

local function merchantRowCount(index, variant)
	local link = Family:TryCall(GetMerchantItemLink, index)
	if type(link) ~= "string" then return nil end
	if Family:VariantKey(itemIDFrom(link), link) ~= variant then return nil end

	local _, _, _, quantity = Family:TryCall(GetMerchantItemInfo, index)
	quantity = tonumber(quantity)
	return quantity and quantity > 1 and quantity or nil
end

-- **A loot window's row**, the third and last of the places backlog 62 names.
--
-- Read from play 2026-09-12: the owner is `LootButton2` carrying id **2** and its parent is
-- `LootFrame` carrying nought - so this one holds its number one step higher up than a
-- merchant's row does, which is the third arrangement of three and the reason none of them
-- were guessed at.
--
--     1=133754  2=Flimsy Chain Cloak  3=1
--
-- texture, name, **quantity**. The third, and a different position from the merchant's fourth,
-- which is exactly what makes reading these rather than recalling them worth the two hovers.
local function lootIndexOf(frame)
	local index = idOf(frame)
	if not (index and index > 0) then return nil end

	local slots = tonumber(_G.LOOTFRAME_NUMBUTTONS) or 4
	for slot = 1, slots do
		if _G["LootButton" .. slot] == frame then return index end
	end

	return nil
end

local function lootRowCount(index, variant)
	local link = Family:TryCall(GetLootSlotLink, index)
	if type(link) ~= "string" then return nil end
	if Family:VariantKey(itemIDFrom(link), link) ~= variant then return nil end

	local _, _, quantity = Family:TryCall(GetLootSlotInfo, index)
	quantity = tonumber(quantity)
	return quantity and quantity > 1 and quantity or nil
end

local function pileCount(tooltip, itemID, variant)
	local owner, parent = ownerChain(tooltip)
	if not owner then return nil end

	local count = bagCount(owner, parent, itemID)
	if count then return count end

	-- The owner first and its parent second, because that is the order the reading found them
	-- in: the texture carries the picture and the button around it carries the row.
	for _, frame in ipairs { owner, parent } do
		local index = browseIndexOf(frame)
		if index then
			count = auctionRowCount(index, variant)
			if count then return count end
		end

		index = merchantIndexOf(frame)
		if index then
			count = merchantRowCount(index, variant)
			if count then return count end
		end

		index = lootIndexOf(frame)
		if index then
			count = lootRowCount(index, variant)
			if count then return count end
		end
	end

	return nil
end

-- **Three of these lines are about the item and two are about the variant**, and getting that
-- split wrong is how a tooltip comes to contradict itself (backlog 67).
--
-- What a vendor pays and what a merchant was seen charging are read out of the client by id, and
-- the stack in front of you is a stack of one item. What the auction house is asking, and what
-- the family's lot comes to, are about the thing being pointed at - and an *of the Bear* sword
-- is not priced by an *of the Whale* one.
-- **What this thing is made with**, on the tooltip of anything a profession makes.
--
-- Asked for 2026-09-12, with three caveats that are the whole of the design:
--
--   1. *se un componente puo essere comprato da piu fonti, la piu economica vince*
--   2. *se di un componente acquistabile non ho il prezzo devo indicare "sconosciuto", non
--      zero* - which is §2.2 said again: nought is different from not read
--   3. *componenti che sono bop drop sommano zero al totale non perche "valgano" zero, ma
--      perche comunque non richiedono soldi per acquisirli*
--
-- The arithmetic is `Recipes:CostToMake` and none of it is here; this decides what is said.
-- **A recipe with one unpriced material has no total at all** - not a total with a hole in it -
-- and one whose materials include something nobody can buy says so under the number, because a
-- reader comparing that figure with an auction price has to know what it leaves out.
--
-- **The list comes first and the arithmetic second**, which is Alberto's 2026-09-12 correction:
-- *mentre impariamo ancora come fare il conto economico, possiamo intanto cominciare a stampare
-- la BoM sul tooltip, perche quella la conosciamo.* So the section is drawn for anything the
-- game says is craftable, whether or not anybody in the family can make one and whether or not a
-- single material has a price - what is known is the recipe, and a price is a thing that fills in
-- later.
--
-- **It sits under *Can make it* and above the prices**, which is the order asked for and is the
-- order the blocks are listed in below: who owns one, who can make one, what making one takes,
-- what selling one is worth.
--
-- Behind its own switch under Extras, and off until somebody asks for it: an eight-material
-- recipe is nine lines, and nine lines on every craftable thing in the game is a tooltip
-- somebody turns the whole addon off over.
local function madeWith(cost)
	if not cost or #cost.parts == 0 then return nil end

	local lines = { { L["|cff66bbffMade with|r"], "" } }

	for _, part in ipairs(cost.parts) do
		-- The client's own name where it has met the item, and the id where it has not. A
		-- tooltip cannot wait for a name to arrive, and a row reading `item 21877` is still
		-- a row somebody can act on - a blank one is not.
		local name = Family.Names:CachedItem(part.item)
			or string.format(L["item %d"], part.item)

		local said
		if part.unknown then
			said = "|cff9d9d9d" .. L["unknown"] .. "|r"
		elseif part.bound then
			-- **Not *farmed*, which was the first word here and is wrong for two thirds of
			-- them.** Reading the generated set out on 2026-09-12 to answer *ce ne sono
			-- anche molti altri?* showed it holds three kinds: drops a crafter goes and
			-- gets (Skin of Shadow, Blood of Heroes), things earned rather than bought
			-- (Primal Nether, in 114 Burning Crusade recipes), and crafted intermediates
			-- that bind (Lionheart Blade). All three are true to *no money buys this* and
			-- only the first is farming.
			said = "|cff9d9d9d" .. L["not for sale"] .. "|r"
		else
			said = UI:MoneyLine(part.total)
		end

		lines[#lines + 1] = { string.format("%s |cff888888x%d|r", name, part.count), said,
			1, 1, 1, 1, 1, 1 }
	end

	-- **The total, or the reason there is not one.** A number that quietly left a material out
	-- is worse than no number: somebody would compare it with an auction price and undercut
	-- themselves with it.
	if cost.total == nil then
		lines[#lines + 1] = { L["Total"],
			"|cffffaa00" .. L["some prices are missing"] .. "|r",
			0.4, 0.73, 1, 1, 1, 1 }
	else
		lines[#lines + 1] = { L["Total"], UI:MoneyLine(cost.total, true), 0.4, 0.73, 1, 1, 1, 1 }

		-- Said only when it happened, and said under the number rather than beside it: it is
		-- a qualification of the total and not another figure.
		if cost.bound > 0 then
			lines[#lines + 1] = { "|cff888888" .. L["not counting materials no money can buy"]
				.. "|r" }
		end

		-- **What time would buy.** Alberto, 2026-09-19: *we are totalling what is the cheapest
		-- way to make the item, but we are not counting the cost of time.* A route that waits
		-- on a crafting cooldown or on farming does not set the total where something can be
		-- bought today (`Recipes:CostOfSpell`); the total it would come to instead is said here,
		-- in the money column like every other figure. And where the total itself waits on a
		-- cooldown, because nothing was for sale, that is said as well.
		--
		-- **A second total, not the difference.** The first drawing put the saving beside *less
		-- with a crafting cooldown*, and Alberto could not tell which it was: *the money on its
		-- right is the cost of the item using a cd, or the savings on the above cost?* A line
		-- that reads like the Total above it, and is compared with it at a glance, needs no
		-- arithmetic and cannot be read two ways.
		if cost.timed then
			lines[#lines + 1] = { "|cff888888" .. L["made with a crafting cooldown"] .. "|r" }
		end

		local why = cost.why or {}
		if (cost.saving or 0) > 0 and (why.cooldown or why.farming) then
			local said = (why.cooldown and why.farming)
				and L["Total with a crafting cooldown and farming"]
				or why.cooldown and L["Total with a crafting cooldown"]
				or L["Total by farming"]
			lines[#lines + 1] = { "|cff888888" .. said .. "|r",
				UI:MoneyLine(cost.total - cost.saving), nil, nil, nil, 0.53, 0.53, 0.53 }
		end
	end

	return lines
end

local function costLines(tooltip, itemID)
	if not (Family.Extras and Family.Extras:On("craftingCost")) then return nil end
	return madeWith(Family.Recipes and Family.Recipes.CostToMake
		and Family.Recipes:CostToMake(itemID) or nil)
end

-- The same block for a recipe that makes nothing, asked of the spell. One function draws both, so
-- an enchant's *Made with* and a sword's cannot come to word or count it differently.
local function spellCostLines(spellID)
	if not (Family.Extras and Family.Extras:On("craftingCost")) then return nil end
	return madeWith(Family.Recipes and Family.Recipes.CostOfSpell
		and Family.Recipes:CostOfSpell(spellID) or nil)
end

local function priceLines(tooltip, itemID, variant)
	if not (FamilyDB and FamilyDB.prices) then return nil end

	local lines = {}

	-- The eleventh return, and asked for without a guard because the tooltip being drawn is
	-- itself the proof this item is in the client's cache - it is showing its name.
	local sell = tonumber((select(11, Family:TryCall(GetItemInfo, itemID))))
	if sell and sell > 0 then
		lines[#lines + 1] = { Family:GameWord("SELL_PRICE", L["Sell price"]),
			UI:MoneyLine(sell), 0.4, 0.73, 1, 1, 1, 1 }
	end

	local buy = Family.Merchant and Family.Merchant:PriceOf(itemID)
	if buy then
		lines[#lines + 1] = { L["Vendor price"], UI:MoneyLine(buy), 0.4, 0.73, 1, 1, 1, 1 }
	end

	-- **And what the auction house was last asking**, with the age of the reading beside it.
	--
	-- A vendor's price is a fact that holds until Blizzard changes it; this is a photograph of a
	-- market, and a photograph without a date on it is a claim about today made from something
	-- that might be a fortnight old. So the two are never drawn alike: the age is part of the
	-- answer, not a detail behind a hover.
	--
	-- Per realm and per faction, which `Auctions:PriceOf` handles - a price read on one side of
	-- one realm says nothing about the other.
	local auction, seen = nil, nil
	if Family.Auctions then auction, seen = Family.Auctions:PriceOf(variant or itemID) end
	if auction then
		-- **The age in front of the money, and in brackets.** Asked for 2026-09-12 off a
		-- screenshot: with it trailing, the price on this line ends where the age begins and
		-- no longer lines up with the sell price above it or the worth below - so the one
		-- column a reader is actually comparing down is the one thing that moves. Every
		-- figure on this block is right-aligned by the tooltip itself, so putting the
		-- qualification first puts them all back in a column.
		lines[#lines + 1] = { L["Auction"],
			string.format("|cff888888(%s)|r %s", UI:Ago(seen), UI:MoneyLine(auction)),
			0.4, 0.73, 1, 1, 1, 1 }
	end

	-- **What the pile in front of you is worth**, which is the question a per-item price is
	-- usually standing in for. Behind CTRL because it is the answer to a different question and
	-- two more lines on every stack in the bag is a tooltip nobody thanked anybody for.
	--
	-- **The key can be pressed with the pointer already there**, measured in play 2026-09-10 on a
	-- Bagnon frame: hover the stack, then hold CTRL, and the line arrives. That is not this file
	-- repainting somebody else's tooltip - the thing the note at the foot of this file measured
	-- as unreliable - it is the bag addon re-showing its own tooltip when the modifier changes,
	-- which re-fires the hook. The owner asking for its own tooltip again is the route that note
	-- already calls stable; the difference is only which owner. Nothing here has to arrange it,
	-- and where a bag addon does not, moving off and back with the key held still works.
	--
	-- The sell price only. *What do I get for this lot* is what a stack is asked; *what would
	-- this lot cost* is not, and would need the buy price to be a thing the family could act on
	-- rather than a thing one vendor was seen charging.
	local count = (sell and sell > 0) and pileCount(tooltip, itemID, variant) or nil
	local held = Family.Index and Family.Index.WorthOfItem
		and Family.Index:WorthOfItem(variant or itemID) or nil
	-- Nought held at nought each is not an answer worth a line, and neither is a lot this
	-- client could not price at all.
	--
	-- **Nor a lot that comes to nothing.** Reported from play 2026-09-12 on Holy Dust: two
	-- held, both soulbound, and the client's sell price for it is nought - so the key was
	-- offered, pressing it drew *Worth 0c* and *at vendor prices 2*, and the reader had been
	-- promised an answer and given a rounding. A sell price of nought **is** a price and
	-- `Index.lua` is right to count it as one: a thing nobody buys contributes nothing to what
	-- a character is worth, which is different from Family not knowing. That is the summary's
	-- question. This is a tooltip, and here nought is a line nobody wanted.
	if held and (held.worth == 0 or (held.atMarket + held.atVendor) == 0) then held = nil end

	local down = Family:TryCall(IsControlKeyDown) and true or false

	if count and down then
		lines[#lines + 1] = { string.format(L["Stack of %d"], count),
			UI:MoneyLine(sell * count), 0.4, 0.73, 1, 1, 1, 1 }
	end

	-- **And what the family's whole lot of it comes to**, which is the question the stack line
	-- answers for the pile in front of you and could never answer anywhere else.
	--
	-- Reported 2026-09-10 from play, at an auction house: *CTRL does not multiply here*. It
	-- cannot, and not for want of trying - the count in the bags case is only usable because it
	-- can be checked against the item the tooltip is describing, and on somebody else's auction
	-- row there is nothing to check it against. So outside your own bags the key answers the
	-- question Family is the only addon in the game that can answer: not what this pile is
	-- worth, but what everything your characters are holding of it is worth.
	--
	-- Drawn like the Stock cell's tooltip on the summary, with the same three already-translated
	-- labels under it, because it is the same figure asked about one item instead of one member -
	-- and because a total reached at vendor prices and one reached at the auction house are two
	-- very different numbers.
	if held and down then
		-- With the age of the oldest market reading that went into it, for the same reason the
		-- auction line carries one: a market price is a photograph, and part of the lot may have
		-- been valued from a reading taken on a realm nobody has visited for a fortnight.
		-- The age leads here too, for the reason the auction line above gives: these two are
		-- the figures somebody reads down, and only one of them carrying a tail is what put
		-- them out of line.
		local figure = UI:MoneyLine(held.worth, true)
		if held.oldest then
			figure = string.format("|cff888888(%s)|r %s", UI:Ago(held.oldest), figure)
		end

		lines[#lines + 1] = { L["Worth"], figure, 0.4, 0.73, 1, 1, 1, 1 }

		-- **How many copies each lane covers, counted in the words rather than in the column.**
		--
		-- Reported by a user of 4.1.0, 2026-09-17, as CTRL multiplying the quantities and not
		-- the prices. Nothing was miscomputed - his own screenshot has 78 units at 37c drawn as
		-- a stack of 28s 86c and 574 of them as a worth of 2g 12s 38c, both exact. These three
		-- lines were the fault: `WorthOfItem` counts **items** into the three lanes, and they
		-- were drawn on the right, which is the column every other line of this tooltip puts
		-- money in. So *aux prix marchands 574* read as a price of 574 that nobody had
		-- multiplied, on a tooltip whose whole subject is money.
		--
		-- The count goes into the sentence instead, which is how the Possessions panel has
		-- always said the same fact - *20 at auction prices, 7 at vendor prices, 3 not priced* -
		-- and the right-hand column is left carrying nothing but money. The strings are shared
		-- with the summary's row tooltip, which drew the same three lines the same way.
		if held.atMarket > 0 then
			lines[#lines + 1] = { string.format(L["%d at auction prices"], held.atMarket),
				"", 0.6, 0.6, 0.6, 0.8, 0.8, 0.8 }
		end
		if held.atVendor > 0 then
			lines[#lines + 1] = { string.format(L["%d at vendor prices"], held.atVendor),
				"", 0.6, 0.6, 0.6, 0.8, 0.8, 0.8 }
		end
		if held.unpriced > 0 then
			lines[#lines + 1] = { string.format(L["%d with no price"], held.unpriced),
				"", 0.6, 0.6, 0.6, 0.8, 0.8, 0.8 }
		end
	end

	-- Said out loud only where it would do something, so an item nobody is holding and that is
	-- not in a stack in front of you carries no offer of a key that would answer nothing.
	--
	-- **And it names both answers where there are two.** One hint used to stand for the pair
	-- and the stack won wherever both applied, on the reasoning that it is the nearer of the
	-- two - so on every stack anybody owns, the hint promised one line and CTRL produced four,
	-- and the family's lot was announced only on the things nobody had two of. Reported from
	-- play 2026-09-12 in exactly those terms: *the family's lot comment already appears but
	-- only on stacks of 1 items only.* Promising less than a key does is not modesty, it is a
	-- reader never finding out the answer is there.
	if not down and not ownerKeepsModifiers(tooltip) then
		if count and held then
			lines[#lines + 1] =
				{ L["|cff888888CTRL: what the stack and the family's lot is worth|r"] }
		elseif count then
			lines[#lines + 1] = { L["|cff888888CTRL: what the stack is worth|r"] }
		elseif held then
			lines[#lines + 1] = { L["|cff888888CTRL: what the family's lot is worth|r"] }
		end
	end

	return #lines > 0 and lines or nil
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

	UI:MoneyFontFrom(tooltip)

	local lines = makerLines(tooltip, ours, theirs)

	-- **And what it is made of, counted and priced.** Asked for off the tooltip of an enchant,
	-- which said who can make it and nothing about what it takes: an enchant makes no item, so
	-- the thing-shaped route never reached it, and it has a bill of materials all the same. Drawn
	-- with the item route's own function, as its own block after the crafters.
	local cost = spellCostLines(spellID)
	if not lines and not cost then return end

	-- The same right-hand column as an item's (`UI:MoneyEven`).
	local all = {}
	for _, line in ipairs(lines or {}) do all[#all + 1] = line end
	for _, line in ipairs(cost or {}) do all[#all + 1] = line end
	UI:MoneyEven(all, 2)

	if lines then
		tooltip:AddLine(" ")
		for index, line in ipairs(lines) do
			if index == 1 then
				tooltip:AddDoubleLine(line[1], line[2], 0.4, 0.73, 1, 0.53, 0.53, 0.53)
			else
				tooltip:AddDoubleLine(line[1], line[2], line[3] or 1, line[4] or 1,
					line[5] or 1, line[6] or 0.61, line[7] or 0.61, line[8] or 0.61)
			end
		end
	end

	if cost then
		tooltip:AddLine(" ")
		for _, line in ipairs(cost) do
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

-- **Blocks on to the tooltip, spaced.** Each block that has something to say is preceded by one
-- blank line and the last is followed by one, so two blocks are separated by exactly one gap and
-- a block with nothing to say leaves no trace at all. Family is rarely the only addon writing on
-- a tooltip, and without the closing line whatever is added next reads as part of this list.
--
-- Shared by the item route and the gathering-node route rather than written twice. The spacing
-- is the part a reader notices and so the part that would drift.
local function writeBlocks(tooltip, blocks)
	if #blocks == 0 then return end

	-- Every money figure on the tooltip one width, across the blocks, since they share one
	-- right-hand column (`UI:MoneyEven`).
	local all = {}
	for _, lines in ipairs(blocks) do
		for _, line in ipairs(lines) do all[#all + 1] = line end
	end
	UI:MoneyEven(all, 2)

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

local function onItem(tooltip, itemID, data)
	if not tooltip then return end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return end
	if not (FamilyDB and FamilyDB.tooltips ~= false) then return end

	-- The newer route hands the item over; the older one has to be asked. Either may be
	-- the one that fires on a given client, so both are accepted.
	local link = linkFrom(tooltip, data)
	if not itemID then itemID = itemIDFrom(link) end
	if not itemID then return end

	-- Which of the item's random-enchantment variants this is, or the plain id where there is
	-- no suffix and where no link could be had at all.
	local variant = Family:VariantKey(itemID, link)

	-- **The guard is on the variant**, not on the item. Two suffixed swords of one id are two
	-- different tooltips, and keying this on the id alone would have shown the first one's
	-- block against the second one's stats.
	-- **And on the frame as well as the variant**, which a browse list is the reason for. The
	-- guard exists so that a tooltip re-firing for the thing it is already describing does not
	-- get the block twice; keyed on the variant alone it also refuses to redraw when the
	-- pointer moves from one row of Linen Cloth to the next, because those two rows are the
	-- same variant. `OnTooltipCleared` normally fires between them and clears this - but a
	-- stack count belongs to the row and not to the item, so where it does not fire the reader
	-- is left looking at the previous row's number. Two rows, one item, different counts is
	-- exactly the case reported from play 2026-09-12, and it is not a case to leave resting on
	-- another addon firing an event.
	local owner = tooltip.GetOwner and (Family:TryCall(tooltip.GetOwner, tooltip)) or nil
	local describing = tostring(variant) .. "@" .. tostring(owner)

	if lastDescribed[tooltip] == describing then return end
	lastDescribed[tooltip] = describing

	-- Worked out before anything is written, because a tooltip has no way to take a line
	-- back off. Each block that has something to say is preceded by one blank line and the
	-- last is followed by one - so two blocks are separated by exactly one gap, and a block
	-- with nothing to say leaves no trace at all.
	--
	-- Family is rarely the only addon writing on a tooltip. Without the closing line,
	-- whatever is added next reads as part of this list.
	-- Measured in this tooltip's own font, before a figure is built (`UI:MoneyFontFrom`).
	UI:MoneyFontFrom(tooltip)

	local blocks = {}

	-- **The item id and the variant both travel**, and each block takes the one its question
	-- is about: who owns one and what it is worth are the variant's, who can make one and what
	-- the client will say about it are the item's. Backlog 67 is that table and nothing else.
	for _, build in ipairs { possessionLines, crafterLines, makerBlock, costLines,
		priceLines } do
		local lines = build(tooltip, itemID, variant)
		if lines and #lines > 0 then blocks[#blocks + 1] = lines end
	end

	writeBlocks(tooltip, blocks)
end

--------------------------------------------------------------------------------------------
-- A herb in the ground
--
-- Backlog 96. Hovering a Silverleaf in the world puts Family's possessions block on the
-- client's own tooltip, the same block a Silverleaf in a bag gets.
--
-- **Neither of the two routes above reaches one**, and that is measured rather than assumed.
-- Four readings across Era `1.15.9` and Mists `5.5.4`, on both a herb and a vein: `GetItem`,
-- `GetSpell` and `GetUnit` all answer nothing, there is no frame under the pointer, and on
-- Mists - which *has* the modern tooltip system - a post-call was registered against every one
-- of the 28 members of `Enum.TooltipDataType` and a world node fired **none** of them. So a
-- gathering node hands over a name and nothing else, on every client Family runs on, and the
-- only way in is the tooltip being shown at all.
--
-- **What a node looks like: two lines, and the second is the profession.** *Silverleaf* over
-- *Herbalism*, *Copper Vein* over *Mining*, in the client's own words. That second line is not
-- a word Family has to ship - `Family.SkillLineByName` carries every profession name in every
-- locale, generated from the client's own `SkillLine` table - so **which profession a node
-- belongs to is answerable by id in any language**, which is the whole discriminator.
--
-- **And the herb half needs no table of node names at all.** A herb node is named exactly what
-- the herb is named, measured on Liferoot, Plaguebloom, Dreamfoil and Silverleaf. So the word
-- on the tooltip is the client's, the word it is matched against is the client's - `Index:Search`
-- names what the family owns - and what comes out is an id. Nothing is shipped, nothing is
-- translated, and it works in a language nobody here speaks. Alberto's rule for this entry, in
-- as many words: *locale words must come from official game vocabulary, not our translations.*
--
-- Mining is not here. A vein is **not** named after its ore - *Copper Vein* against *Copper
-- Ore* - so it needs a join, and what a vein is called in any language but English has never
-- been read. That reading is owed before the join is written and not after.
--------------------------------------------------------------------------------------------

-- The two the world hands over. Ids, so the test is in no language.
local HERBALISM, MINING = 182, 186

-- **The rule for a vein, and every number in it was measured rather than chosen.**
--
-- A herb node is named exactly what the herb is named, so a herb is a lookup. A vein is not -
-- *Copper Vein* against *Copper Ore* - so a vein is a **score**: the longest run of bytes the
-- vein's name and a candidate ore's name share, as a share of the ore name's own length.
--
-- Share and not a count of characters is the whole of what makes it work. A short metal word
-- filling a short plain name is a strong match and the same word buried in a long specific one
-- is a weak one: `eisen` is 5 of 8 in `Eisenerz` and 5 of 14 in `Dunkeleisenerz`, so a plain
-- vein takes the plain ore, while `dunkeleisen` is 11 of 14 and the specific vein takes the
-- specific one. A longest-run join ties three ways in German and this does not tie at all.
--
-- **Measured on every mining node of the three builds Family ships for, in five languages**,
-- scored against the ore names from the client's own tables - the reading is in DATASOURCES.
-- With the word rule below, these numbers name **446 correctly and none wrong**, saying nothing
-- about 88; without it, 422 and 112. Each number is here because a reading put it here:
--
-- * `0.27` because at 0.26 the Russian *Большая обсидиановая глыба* still takes obsidium ore -
--   a stone node named as a metal - and at 0.27 it stops;
-- * `4` because ore names can be short: `Torio` is what a Spanish client calls thorium ore, and
--   `tor` is three letters of five, so *Torre de vigilancia* - a watchtower, and a label a
--   pointer crosses on a map - clears the floor without it. **Re-measured 2026-09-22 and it is
--   not exercised by any of the 970 rows**: with the word rule in, a minimum of 1, 2, 3 and 4
--   answer identically. It stays as a guard over the case above, which the corpus does not
--   contain, and this sentence is here so nobody mistakes it for a rule the rows earn;
-- * `0.55` as the floor under both.
--
-- Bytes rather than characters, and `lower` folds A to Z and nothing else, because that is
-- what Lua does and so it is what was measured. Folding Cyrillic as well was measured on the
-- same rows and **refused**: it names 28 more and gets one wrong, and the one is
-- *Большая обсидиановая глыба* taking obsidium - the exact row the margin above was set to
-- close. A rule that buys answers by re-opening the failure this entry exists to prevent is a
-- worse rule however the total reads.
local ORE_FLOOR, ORE_MARGIN, ORE_RUN = 0.55, 0.27, 4

-- **Cheapest test first, and the order is the point.** This runs on every tooltip the game
-- shows, so what it must not do is ask the client four questions about a bag slot. The line
-- count throws out most of them for the price of one call, and the profession line - a table
-- lookup, free - throws out very nearly all the rest. Only then is it worth asking the three
-- calls what this tooltip is about. Getting that order the wrong way round is L-119 in
-- miniature: a test whose cost is set by how often it runs rather than by what it answers.
-- **The gathering words this client uses**, from `SkillLines.lua` rather than from anything
-- written here: skill 182 and 186 carry their names in five locales, generated from the client's
-- own table. A locale can spell one of them more than one way and both are kept.
local gatheringWords
do
	local words
	gatheringWords = function()
		if words then return words end
		words = {}
		for _, skill in ipairs { HERBALISM, MINING } do
			local entry = Family.SkillLines and Family.SkillLines[skill]
			local named = entry and entry.names
				and (entry.names[Family.locale] or entry.names.enUS)
			for _, word in ipairs(named or {}) do
				if type(word) == "string" and word ~= "" then
					words[#words + 1] = { word = word:lower(), skill = skill }
				end
			end
		end
		return words
	end
end

-- **Which gathering profession a tooltip names, anywhere in its second or third line.**
--
-- `contains` and not `equals`, which is the correction that matters. Alberto, 2026-09-22: a
-- character **without** the profession still sees the node, and what the line says is *requires*
-- the profession; a miner whose skill is too low for the vein reads *Requires Mining (275)*.
-- Both were being turned away by a test that asked the line to **be** the word, so the block
-- showed only to characters who could already gather the node - and the one who wants it most is
-- the one who cannot, standing there wondering whether an alt has the ore.
--
-- Two lines rather than one, because where the requirement sits is not known here and guessing
-- it would be the same fault again. A reading would settle the order; this does not need it.
local function professionNamed(frameName, lines)
	for index = 2, math.min(lines, 3) do
		local region = _G[frameName .. "TextLeft" .. index]
		local text = region and region.GetText and (Family:TryCall(region.GetText, region))
		if type(text) == "string" and text ~= "" then
			local lowered = text:lower()
			for _, entry in ipairs(gatheringWords()) do
				if lowered:find(entry.word, 1, true) then return entry.skill, text end
			end
		end
	end
	return nil
end

-- **Is the pointer on something drawn on the minimap?**
--
-- Not *is it the minimap*, which was the first shape and excluded exactly the pins worth
-- serving. Alberto, 2026-09-22: GatherMate, Gatherer and their like remember where nodes were
-- and draw their own pins with their own tooltips, and those are nodes too. Their frames are
-- children of `Minimap`, so a walk up the parents admits them without this file knowing one
-- addon's name.
--
-- `GetMouseFocus` on Era and `GetMouseFoci` on Mists - measured, the first is nil there - so
-- both are asked and neither is assumed.
local function onAMap()
	local frame = Family:TryCall(_G.GetMouseFocus)
	if type(frame) ~= "table" then
		local several = Family:TryCall(_G.GetMouseFoci)
		frame = type(several) == "table" and several[1] or nil
	end

	-- **The world map as well as the minimap**, on Alberto's *I want both*. A pin an addon drew
	-- from where it remembers a node being is the same question with the same answer wanted, and
	-- the narration settled that a world map pin does reach `GameTooltip` and was refused here
	-- and nowhere else: `1 line(s): Silverleaf / nil`, and nothing after it.
	local maps = { _G.Minimap, _G.WorldMapFrame }

	-- Bounded rather than walked to the top: a parent chain that loops would hang the client,
	-- and nothing drawn on either map is eight deep.
	local steps = 0
	while type(frame) == "table" and steps < 8 do
		for _, map in ipairs(maps) do
			if map and frame == map then return true end
		end
		frame = frame.GetParent and (Family:TryCall(frame.GetParent, frame)) or nil
		steps = steps + 1
	end
	return false
end

-- **What this client calls an area id**, asked three ways and assumed in none.
local function areaNamed(id)
	local said = _G.C_Map and (Family:TryCall(_G.C_Map.GetAreaInfo, id))
	if type(said) ~= "string" or said == "" then
		said = Family:TryCall(_G.GetAreaInfo, id)
	end
	return type(said) == "string" and said ~= "" and said or nil
end

-- **Places whose names this rule would take for a metal, refused by id.**
--
-- Alberto, 2026-09-22, on being told that 11 of Era's 1,018 area names score as an ore: *just
-- for the fact that you can know this, you can write an exception table.* Quite so. It ships as
-- **ids** in `Gathered.lua` and the client names them, so the exception holds in whatever
-- language somebody plays in - which a table of names could not do, and which matters because
-- the collisions are not the same set in each: 11 in English and **53** across the five.
--
-- Worked out once. A client that will not name an area id is recorded as such and not asked
-- again, because it will not start being able to.
local refusedPlaces
local function placesToRefuse()
	if refusedPlaces ~= nil then return refusedPlaces or nil end

	local set = Family.Gathered and Family.Gathered[Family.Capabilities.expansion]
	local ids = set and set.places
	if not ids then
		refusedPlaces = false
		return nil
	end

	local out, named = {}, 0
	for _, id in ipairs(ids) do
		local name = areaNamed(id)
		if name then
			out[name:lower()] = true
			named = named + 1
		end
	end

	if named == 0 then
		Family:Debug("node: this client names no area id, so no place can be refused by name")
		refusedPlaces = false
		return nil
	end

	Family:Debug("node: %d of %d places named and refused", named, #ids)
	refusedPlaces = out
	return refusedPlaces
end

-- Answers the node's name, the skill if the tooltip said one, and where it was drawn.
--
-- **Cheapest test first, and the order is the point.** This runs on every tooltip the game
-- shows, so what it must not do is ask the client four questions about a bag slot. The line
-- count throws out most of them for the price of one call, and the profession scan - a handful
-- of `find`s - throws out very nearly all the rest. Only then is it worth asking the three calls
-- what this tooltip is about. Getting that order the wrong way round is L-119 in miniature.
-- **A name can arrive wearing a colour**, and a herb is matched exactly, so it has to come off.
--
-- Read from play 2026-09-22 and visible in the screenshot rather than in any log: on the
-- minimap, GatherMate2 draws a herb's name in green and a vein's in red, which means its text is
-- `|cff00ff00Bruiseweed|r` and not `Bruiseweed`. A vein survived that because it is **scored**,
-- and the share is measured against the candidate's own length, so ten bytes of markup on the
-- other side of the comparison change nothing. A herb is matched **exactly** and did not survive
-- it at all. That is the whole of *herbalism works in the world and not on the minimap*: the
-- client's own tooltip carries no markup and somebody else's pin does.
--
-- Textures go too, for the same reason and before anybody reports it: a pin that draws its icon
-- inline puts `|T...|t` in the same string.
local function trimmed(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function plainly(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|T.-|t", "")
	return trimmed(text)
end

local function gatheringNode(tooltip)
	if not tooltip then return nil end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return nil end

	-- **No ceiling on the line count**, and the reading that took the ceiling away did not say
	-- what I first read it as saying.
	--
	-- `5 line(s): Mageroyal / Herbalism` looked like a node tooltip growing under another addon.
	-- It is not: the narration of 2026-09-22 shows the pair per hover - `2 line(s)` on the
	-- immediate call, which resolves and writes, then `5 line(s)` on the deferred one, which is
	-- **our own block counted back to us**. A blank line, a header, an owner and a blank line is
	-- three more than two. So that reading is no evidence for a ceiling being wrong, and the
	-- claim that it explained *showed the block then lost it* is withdrawn.
	--
	-- The ceiling still goes, for a reason that is about what can be relied on rather than what
	-- was seen: nothing says a node tooltip is Family's alone before Family writes on it, and an
	-- addon that adds a line above ours would have pushed it past three. What keeps this cheap
	-- is the profession scan, which reads at most two font strings and asks a handful of `find`s
	-- of them - a bag slot's second line is not the word Mining in any language.
	local lines = tonumber((Family:TryCall(tooltip.NumLines, tooltip))) or 0
	if lines < 1 then return nil end

	local frameName = tooltip:GetName()
	if not frameName then return nil end

	-- **One line is the minimap and nowhere else.** A blip gives the name and no profession
	-- line, so nothing in the text says it is a node - measured, and the reason the resolution
	-- cannot be trusted to decide on its own there: 647 of 43,356 ordinary item names score as
	-- an ore under the rules a vein passes, and no threshold separates the two. Where it was
	-- drawn is the only signal left, so it is required.
	local skill, said
	if lines == 1 then
		if not onAMap() then return nil end
	else
		skill, said = professionNamed(frameName, lines)
		if not skill then
			Family:Debug("node: %d line(s) and none of 2..3 names a gathering profession",
				lines)
			return nil
		end
	end

	-- Anything the client will name is not a node. Asked last because by here almost nothing
	-- that is not a node is left, and asked at all because a tooltip that happens to carry the
	-- word *Mining* is a thing somebody's addon will make one day.
	local named = (Family:TryCall(tooltip.GetItem, tooltip))
		or (Family:TryCall(tooltip.GetSpell, tooltip))
		or (Family:TryCall(tooltip.GetUnit, tooltip))
	if named then
		Family:Debug("node: the client calls it %s, so it is not one", tostring(named))
		return nil
	end

	local region = _G[frameName .. "TextLeft1"]
	local first = region and region.GetText and (Family:TryCall(region.GetText, region))
	if type(first) ~= "string" or first == "" then
		Family:Debug("node: line 1 is not text")
		return nil
	end

	first = plainly(first)
	if first == "" then
		Family:Debug("node: line 1 is nothing but markup")
		return nil
	end

	if said then Family:Debug("node: line naming the profession is %s", said) end
	return first, skill, lines == 1 and "minimap" or "world"
end

-- **What the client calls each id this build can gather**, and whether it answered about all
-- of them.
--
-- A name that has not arrived cannot be matched against, and an answer worked out while the
-- client was still silent must not be remembered: that is how the first hover of a session
-- would fix a wrong reading in place for the rest of it. So completeness travels with the
-- answer and an incomplete pass is thrown away rather than cached.
--
-- **How many are still silent travels too**, and only so that the narration can say it. A node
-- left alone because the client has not finished answering and a node the score genuinely cannot
-- place are the same silence from outside, and they want opposite responses - hover again, or
-- nothing will ever come of this one. Reported 2026-09-22 on two thorium veins on the world map
-- while a mithril deposit beside them answered, which is exactly the shape a part-named list
-- makes and exactly the shape nothing here could say out loud.
local function namesFor(which)
	local set = Family.Gathered and Family.Gathered[Family.Capabilities.expansion]
	local ids = set and set[which]
	if not ids then return nil, false, 0 end

	local named, whole, silent = {}, true, 0
	for _, id in ipairs(ids) do
		local name, known = Family.Names:Item(id, "nodes")
		if known and type(name) == "string" and name ~= "" then
			named[id] = name
		else
			whole = false
			silent = silent + 1
		end
	end
	return named, whole, silent
end

-- The longest run of bytes two names share, **and where it starts in the candidate**. Two
-- rolling rows rather than a whole table: the names are a few dozen bytes and this runs once
-- per node name, behind the memo.
local function sharedRun(vein, name)
	local a, b = vein:lower(), name:lower()
	local width = #b
	local best, at, previous, current = 0, 0, {}, {}
	for index = 0, width do previous[index] = 0 end

	for i = 1, #a do
		local byte = a:byte(i)
		current[0] = 0
		for j = 1, width do
			if byte == b:byte(j) then
				local run = previous[j - 1] + 1
				current[j] = run
				if run > best then best, at = run, j - run + 1 end
			else
				current[j] = 0
			end
		end
		previous, current = current, previous
	end

	return best, at
end

-- **And whether that run begins at a word of the candidate's own name.**
--
-- Reported from play 2026-09-22, on Burning Crusade: a `Rich Thorium Vein` and a `Small Thorium
-- Vein` on the minimap drew nothing while a `Dark Iron Deposit` beside them answered. The cause
-- is `Khorium Ore`, which that build adds and Era does not: `thorium ` is 8 bytes of `Thorium
-- Ore` and `horium ` is 7 of `Khorium Ore`, so the two score 0.727 and 0.636 and the margin -
-- which exists to refuse a guess between two metals - refuses a vein that was never in doubt.
-- Symmetrically, a `Khorium Vein` is silenced by thorium.
--
-- What separates them is not how much they share but **where**: `thorium` is the whole of the
-- winner's first word, and `horium` starts inside the runner-up's. A candidate whose run starts
-- mid-word has matched a coincidence, and a coincidence should not be able to silence a real
-- answer by standing close to it.
--
-- Three ways to be at a word, and the middle one is the easy thing to get wrong: the run may
-- **open with the separator itself**, which is what `Minerai de cuivre` does against `Filon de
-- cuivre`, and testing only the byte before would throw those away. Separators are checked by
-- byte, never by asking what a letter is - the names are UTF-8 and a letter here can be two
-- bytes.
--
-- Measured over every mining node Wowhead lists for the three builds in five languages, against
-- the ore names from the client's own tables: **446 named correctly and 0 wrong, against 422 and
-- 0 for the rule without it**, with the silent falling from 112 to 88. Nothing that was right
-- became wrong and nothing that was wrong became right - what moved was silence.
local SEPARATORS = { [32] = true, [45] = true, [39] = true }

local function atAWord(name, at)
	if at <= 1 then return at == 1 end
	if SEPARATORS[name:byte(at)] then return true end
	return SEPARATORS[name:byte(at - 1)] and true or false
end

-- **A herb is a lookup**, because a herb node is named exactly what the herb is named -
-- measured on Liferoot, Plaguebloom, Dreamfoil, Silverleaf and Peacebloom. Exactly, and not the
-- way a search box matches: loosely, *Silverleaf* would also find *Silverleaf Pendant* and the
-- node would report the family's holdings of something else under the name of the thing in the
-- ground.
local function herbNamed(wanted, named)
	local lowered = wanted:lower()
	for id, name in pairs(named) do
		if name:lower() == lowered then return id end
	end
	return nil
end

-- **A vein is a score.** The rule and its three numbers are set out above.
local function oreScored(vein, named)
	local bestID, bestName, bestShare, bestRun = nil, nil, 0, 0
	local nextName, nextShare = nil, 0

	for id, name in pairs(named) do
		local run, at = sharedRun(vein, name)
		local share = run / #name
		-- **A candidate that matched mid-word has not matched this name at all**, so it neither
		-- wins nor stands as the runner-up the margin is measured against. Dropped here rather
		-- than at the end, because its whole effect is on what the runner-up is.
		if not atAWord(name:lower(), at) then run, share = 0, 0 end
		-- Ties broken by the longer run and then left alone, so the answer does not depend on
		-- the order `pairs` happens to walk in.
		if run > 0 and (share > bestShare or (share == bestShare and run > bestRun)) then
			nextName, nextShare = bestName, bestShare
			bestID, bestName, bestShare, bestRun = id, name, share, run
		elseif share > nextShare then
			nextName, nextShare = name, share
		end
	end

	if not bestID or bestShare < ORE_FLOOR or bestRun < ORE_RUN then return nil end

	-- **A runner-up whose name sits inside the winner's is one metal seen twice**, not two
	-- candidates - `Silver Ore` under `Truesilver Ore` - so the margin, which is what tells two
	-- metals apart, has nothing to say and is waived. Worth 28 correct answers of the 422 and
	-- no wrong ones: without it the margin silences every Truesilver node in the game.
	local lowered = bestName:lower()
	local kin = nextName and (nextName:lower():find(lowered, 1, true) ~= nil
		or lowered:find(nextName:lower(), 1, true) ~= nil)

	if not kin and (bestShare - nextShare) < ORE_MARGIN then return nil end
	return bestID
end

-- **Worked out once per name, and forgotten whenever the records change.**
--
-- Naming every candidate and scoring against all of them is work a pointer crossing a field of
-- herbs must not pay twice, and the answer does not move: a name belongs to an item whatever
-- anybody happens to be carrying. A miss is kept as well as a hit - a herb nobody owns is
-- exactly the node somebody hovers again - **unless the client had not named everything yet**,
-- which is the one case where the answer really can change without the records doing so.
local resolvedNames = {}

--
-- **What to try, and in what order.** Where the tooltip named a profession there is one list to
-- look in. Where it did not - a minimap blip, which gives the name and nothing else - both are
-- tried, herbs first and exactly, ores second and scored. That order is safe and measured: of
-- the 752 vein names read for the three builds in five languages, **none** is also the name of
-- a herb, so the exact step cannot take a vein for a plant.
local function itemsForNode(said, skill)
	-- **A zone label is not a node.** Checked before anything is scored, and by name against the
	-- ids the build ships: of 929 vein names read across three builds and five languages, not
	-- one is also the name of a refused place, so this cannot silence a real node.
	local refused = placesToRefuse()
	if refused and refused[said:lower()] then
		Family:Debug("node: \"%s\" is a place this rule would misread, so it is refused", said)
		return nil
	end

	local key = tostring(skill or 0) .. ":" .. said
	local held = resolvedNames[key]
	if held ~= nil then return held or nil end

	-- **Both lists, and each name asked of them in turn.**
	--
	-- Where the tooltip named a profession there is one list to look in. Where it did not - a
	-- pin, which gives names and nothing else - both are tried, **herbs first and exactly, ores
	-- second and scored**. That order is safe and measured: of the 752 vein names read for the
	-- three builds in five languages, none is also the name of a herb, so the exact step cannot
	-- take a vein for a plant.
	local herbs, herbsWhole, herbsSilent = nil, true, 0
	local ores, oresWhole, oresSilent = nil, true, 0
	if skill ~= MINING then herbs, herbsWhole, herbsSilent = namesFor("herbs") end
	if skill ~= HERBALISM then ores, oresWhole, oresSilent = namesFor("ores") end

	local function notYet(which, silent)
		Family:Debug("node: \"%s\" is left alone: the client has not named %d of the "
			.. "%d %s this build ships, so this list has not said no yet",
			said, silent, #((Family.Gathered[Family.Capabilities.expansion]
				or {})[which] or {}), which)
	end

	-- **A tooltip line can carry more than one name**, from several pins under one cursor: the
	-- probe read back `"Plaguebloom\nPlaguebloom"` as a single line, and a world map zoomed out
	-- over Searing Gorge gave sixteen. So the line is split and each name asked on its own, and
	-- what comes back is **every distinct thing the cursor is holding**, in the order the tooltip
	-- names them. One pin and sixteen are the same question with a longer answer.
	local ids, seen = {}, {}

	for piece in tostring(said):gmatch("[^\r\n]+") do
		-- Trimmed and not stripped: the markup came off the whole line already, and what it
		-- leaves behind is the spacing that sat between it and the name - which is inside the
		-- line and so outside what trimming the ends of it reached.
		local name = trimmed(piece)
		local one = herbs and herbNamed(name, herbs) or nil

		-- **A list that did not answer, and was not complete, has not said no.**
		--
		-- The client had not named everything in it yet, so *no herb of that name* is unknown
		-- rather than false - and going on to score the name against the ores turns an unknown
		-- into a wrong answer. Read in play 2026-09-22, on a minimap blip: `"Silverleaf" is item
		-- 2775`, which is **Silver Ore**. The herb list had not been named, the exact step
		-- therefore found nothing, and the ore scorer then took `silver` out of `Silver Ore` at
		-- 0.6 with the kin rule waiving the margin against `Truesilver Ore`.
		--
		-- Naming the wrong metal confidently is the one failure this entry set out not to have,
		-- and in the world the profession line prevents it by saying which list to look in. On a
		-- pin there is no such line, so the guard has to be here. Nothing is remembered either:
		-- the answer is not *no*, it is *not yet*.
		if not one and herbs and not herbsWhole then
			notYet("herbs", herbsSilent)
			return nil
		end

		if not one and ores then one = oreScored(name, ores) end
		if not one and ores and not oresWhole then
			notYet("ores", oresSilent)
			return nil
		end

		if one and not seen[one] then
			seen[one] = true
			ids[#ids + 1] = one
		end
	end

	-- A name this build cannot place sits beside the ones it can rather than silencing them,
	-- because each answer carries the name of what it is about and so cannot be read as being
	-- about the pin next to it. That was not true while a cursor holding several things got one
	-- unnamed answer, and it is why that case was silent until 2026-09-22.
	local answer = #ids > 0 and ids or nil
	if answer or (herbsWhole and oresWhole) then resolvedNames[key] = answer or false end
	return answer
end

local function onNode(tooltip)
	if not tooltip then return end
	if not (FamilyDB and FamilyDB.tooltips ~= false) then return end

	-- **Every tooltip, while somebody is looking.**
	--
	-- The line-count gate below turns nearly every tooltip in the game away and so is the one
	-- gate that cannot narrate on its own account - a pointer crosses far too many. Which makes
	-- it the one gate whose rejection is indistinguishable, from outside, from this route never
	-- running at all: *nothing is printed when hovering on silverleaf*, reported 2026-09-21 with
	-- the build deployed and debug on. So the shape of every tooltip is reported here instead,
	-- before any gate. Noisy with `/family debug` on and completely silent without it, which is
	-- the trade a diagnostic is allowed to make and a feature is not.
	if FamilyDB.debug then
		local named = tooltip.GetName and (Family:TryCall(tooltip.GetName, tooltip))
		local one = named and _G[tostring(named) .. "TextLeft1"]
		local two = named and _G[tostring(named) .. "TextLeft2"]
		Family:Debug("node: %s shown with %d line(s): %s / %s", tostring(named),
			tonumber((Family:TryCall(tooltip.NumLines, tooltip))) or 0,
			tostring(one and one.GetText and (Family:TryCall(one.GetText, one))),
			tostring(two and two.GetText and (Family:TryCall(two.GetText, two))))
	end

	local said, skill, where = gatheringNode(tooltip)
	if not said then return end

	-- **The guard first**, so a route that runs twice for one tooltip - which it does, at
	-- `OnShow` and again a frame later - resolves once and narrates once.
	local describing = "node:" .. tostring(where) .. ":" .. said
	if lastDescribed[tooltip] == describing then return end
	lastDescribed[tooltip] = describing

	local ids = itemsForNode(said, skill)

	if not ids then
		-- A vein the score cannot place, or a herb that is not in the list this build ships.
		-- Silence, and the client's own tooltip left exactly as it drew it: naming the wrong
		-- metal confidently is the only failure here that matters, and on the nodes this was
		-- measured against it never did.
		Family:Debug("node: \"%s\" on the %s, skill %s, and nothing here can place it",
			said, tostring(where), tostring(skill or "not said"))
		return
	end

	Family:Debug("node: \"%s\" is %d thing(s), the first being item %d", said, #ids, ids[1])

	UI:MoneyFontFrom(tooltip)

	-- **How much of the screen is left, shared out between them.**
	--
	-- A cursor on a zoomed-out world map can hold sixteen pins, and GatherMate2 draws a line for
	-- each before Family writes anything - so the room this block has is what the tooltip has not
	-- already spent, and it has to be divided rather than handed to each answer in turn. Three
	-- rows is the least an answer is worth having: its heading, one holder, and the blank line
	-- that separates it from the next.
	--
	-- `TooltipRows` is measured from the screen's own height and the tooltip font's own size, so
	-- this follows a player's UI scale rather than a number chosen on one monitor.
	-- **What an answer costs besides its holders**: its heading, the line counting the holders it
	-- did not name, the line saying where the rest of them are, and the blank that separates it
	-- from the next answer. Four, and they are why a budget of *three rows each* wrote fifteen
	-- lines into a screen with room for twelve on the first try - the holders were counted and
	-- the furniture around them was not.
	local FIXED_EACH = 4
	local used = tonumber((Family:TryCall(tooltip.NumLines, tooltip))) or 0
	local room = math.max(UI:TooltipRows() - used - 2, FIXED_EACH + 1)
	local shown = math.min(#ids, math.max(1, math.floor(room / (FIXED_EACH + 1))))

	-- **Never looser than this block's own cap, and never wider than its share of what is left.**
	--
	-- `roomFor` is the cap the rest of the addon keeps - ten holders with folding on, the
	-- screen's worth with it off (backlog 82 and 89) - so one node is the tooltip it always was:
	-- its share of the room is the whole of it, and the cap is what bites. The share only bites
	-- once there is a second answer to divide it with.
	--
	-- **There was a `shown > 1` guard here and a mutation said it did nothing**, which was true:
	-- with one answer the share is larger than the cap and the `min` was already choosing the
	-- cap. A condition that cannot change an answer is a condition that will be read as
	-- protecting something.
	local owners = math.max(1, math.min(roomFor(tooltip, OWNER_CAP),
		math.floor(room / shown) - FIXED_EACH))

	local blocks = {}

	for index = 1, shown do
		local itemID = ids[index]

		-- **What the client calls what comes out of it.** Asked again rather than carried back
		-- from the resolver, because the resolver answers by id on purpose and a name that
		-- arrived after it was memoised would never reach this line. Where the client has not
		-- named the item yet the heading goes back to the bare one: an unnamed subject is exactly
		-- the tooltip this note was added for, and *Family possessions:* with nothing after the
		-- colon is worse than no colon at all.
		local named, known = Family.Names:Item(itemID, "nodes")
		if not (known and type(named) == "string" and named ~= "") then named = nil end

		-- **And not where the tooltip has already said it, which only one answer can be.**
		--
		-- A herb node is named exactly what the herb is named - that is the whole reason a herb
		-- is a lookup and a vein is scored - so *Family possessions: Silverleaf* sits directly
		-- under a line reading *Silverleaf* and spends the width on nothing. Alberto's reading of
		-- a Silverleaf on a non-herbalist, 2026-09-22.
		--
		-- Where the cursor holds several things every heading carries its name, whatever the
		-- lines above say. The tooltip names all of them and the blocks have to be told apart
		-- from each other, which is the one job the bare heading cannot do.
		if #ids == 1 and named and said:lower():find(named:lower(), 1, true) then named = nil end

		-- **Possessions and nothing else.** What a node is worth, who can make one and what it
		-- costs are questions about an item somebody is holding; a rock in the ground is a place
		-- to go, and the only question is whether anybody has already been. Neither a herb nor an
		-- ore carries a random suffix, so the variant is the id.
		local lines = possessionLines(tooltip, itemID, itemID,
			{ named = named, owners = owners })

		-- **And *nobody has any* is an answer**, which on an item's own tooltip it is not.
		--
		-- `possessionLines` is silent where nothing is owned, and rightly: a tooltip that grows a
		-- line for every item nobody has is a tooltip nobody reads, and an item tooltip is drawn
		-- whenever a pointer crosses a bag. A node is different twice over. It is hovered
		-- deliberately, by somebody standing over the thing deciding whether to take it, and
		-- *none* is exactly the answer that decides it. Reported twice as *herb nodes do not work
		-- at all* while this said nothing, which is the other half of the reason.
		if not lines or #lines == 0 then
			lines = { { possessionHeading(named), "|cff9d9d9d" .. L["none"] .. "|r" } }
		end

		blocks[#blocks + 1] = lines
	end

	-- And what the room did not stretch to, counted rather than dropped in silence - the same
	-- rule every contracted list in the addon keeps.
	if shown < #ids then
		blocks[#blocks + 1] = { { string.format(L["|cff888888and %d more|r"], #ids - shown),
			"", nil, nil, nil, 0.5, 0.5, 0.5 } }
	end

	writeBlocks(tooltip, blocks)
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
		onItem(tooltip, data and data.id, data)
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

	-- **And the world, which is neither of those routes.**
	--
	-- `GameTooltip` alone: a herb in the ground is never described on an `ItemRefTooltip` or in
	-- a shopping comparison. `OnShow` rather than any of the setters, because no setter runs -
	-- that is the whole finding behind `onNode`.
	--
	-- **A frame later**, which the probe had to do before it could read a node's lines at all:
	-- at `OnShow` the tooltip is up and its text is not all on it yet. `Show` is called again at
	-- the end of the write, which is what resizes it around the lines just added.
	--
	-- Kept reachable for the same reason `__modernCallback` is: this route cannot be reached
	-- from a setter, so a test that cannot call it cannot catch it breaking.
	UI.__nodeCallback = onNode

	-- What a name resolves to is a fact about the game; whether anybody holds one is a fact
	-- about the records, and that is the half that moves.
	Family.Database:OnChanged("tooltip.nodes", function() wipe(resolvedNames) end)

	if _G.GameTooltip and _G.GameTooltip.HookScript then
		-- **And again whenever the tooltip is emptied and refilled.**
		--
		-- Reported from play 2026-09-22: on one and the same Mageroyal, *sometimes the rich
		-- tooltip, sometimes the basic one*, with and without the skill alike. This route writes
		-- once, at a moment it does not control, and it is only ever asked at `OnShow` - so a
		-- tooltip that is refilled **in place**, which is what happens when a pointer crosses
		-- from one node straight to another without the tooltip ever hiding, is never offered
		-- to it at all. No second `OnShow`, no block, and nothing to say why.
		--
		-- `OnTooltipCleared` is the one signal that a rebuild has started. `forget` is already
		-- hooked to it and drops the already-described mark, so asking again a frame later
		-- redraws rather than doubling. Bounded: `AddLine` fires no clear, and `Show` on a frame
		-- that is already shown fires no `OnShow`, so this cannot feed itself.
		_G.GameTooltip:HookScript("OnTooltipCleared", function(self)
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function() onNode(self) end)
			end
		end)

		_G.GameTooltip:HookScript("OnShow", function(self)
			-- **Both, and the guard makes that safe.** At `OnShow` the tooltip is up and its
			-- text may not all be on it, which is why the probe had to wait a frame to read a
			-- node at all; but a client that fills it before showing it would then be read a
			-- frame after something else had taken the tooltip over. `lastDescribed` already
			-- refuses to describe the same thing twice, so trying at both moments costs one
			-- rejected call and covers both clients.
			onNode(self)
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function() onNode(self) end)
			end
		end)
	end

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

-- **The item itself, by the longest form there is of it.** A link carries the enchant, the
-- gems and the random suffix; an id carries the item somebody bought and nothing that happened
-- to it since. Both are tried because neither is on every client and neither can be trusted to
-- report failure.
--
-- Shared, because the two slot lanes below fall back to it: a slot this client will not
-- describe should leave the row saying what a sibling's row says, not saying nothing.
local function describeItem(what)
	if what.link then
		Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, what.link)
		if wroteAnything() then return end
	end

	if not what.id then return end

	Family:TryCall(GameTooltip.SetItemByID, GameTooltip, what.id)
	if not wroteAnything() then
		Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. what.id)
	end
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

	-- **The slot this client is holding, rather than a description of the item in it.**
	--
	-- Reported from play 2026-09-11, with both tooltips side by side: a shield that had been
	-- worn and taken off reads **Soulbound** in the game's own bag and *Binds when equipped*
	-- on Family's page. Neither is wrong - the second is the game describing the **item**,
	-- because a link is all a panel drawing somebody else's bag can have, and binding is not
	-- in a link (Core.lua says the same about charges). But where the bag is one this client
	-- is holding, there is no need to settle for the item: the slot itself can be asked, and
	-- it answers about the thing in front of you.
	--
	-- The bag, the slot, and what to say if the slot will not answer - because some
	-- containers do not. Reported from play on Classic Era 2026-09-11: a key in the keyring
	-- draws no tooltip at all, while the bags either side of it draw one. The keyring's
	-- container number is negative and Family has known since the scanner was written that
	-- the client answers questions about it oddly (Scanners/Bags.lua); this is the same
	-- awkwardness reaching the panel.
	--
	-- A setter that describes nothing and a setter that is not there both come back as
	-- silence (Family:TryCall), and silence here meant the row showed **nothing**, where
	-- every other member's copy of that same key shows the item. So the slot is asked first
	-- and the item second: precision where the client will give it, and the item everywhere
	-- else.
	bagslot = function(where)
		if type(where) ~= "table" then return end
		Family:TryCall(GameTooltip.SetBagItem, GameTooltip,
			tonumber(where.bag), tonumber(where.slot))
		if not wroteAnything() then describeItem(where) end
	end,

	-- A slot on this character's own body, for the same reason the bag slot exists: a worn
	-- bind-on-equip piece is bound, and its link goes on saying *binds when equipped* because
	-- that is a fact about the item rather than about the one on somebody's back.
	wornslot = function(where)
		if type(where) ~= "table" then return end
		Family:TryCall(GameTooltip.SetInventoryItem, GameTooltip, "player",
			tonumber(where.slot))
		if not wroteAnything() then describeItem(where) end
	end,

	spell = function(id)
		Family:TryCall(GameTooltip.SetSpellByID, GameTooltip, id)
		if not wroteAnything() then
			Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. id)
		end
	end,

	-- A quest link is its id **and its level**, and a bare "quest:84" describes nothing.
	--
	-- Measured on Era and TBC 2026-09-05: `quest:84` answered nought lines and `quest:84:20`
	-- answered three and drew the quest. This asked for the first form since it was written,
	-- so every quest row in Family has been falling silently through to its own lines - and
	-- because the fallback is good, nobody had reason to report it.
	--
	-- The caller passes the two joined, because the level belongs to the row and not to this
	-- table. Where a row has no level to give, what arrives is a bare id, the client says
	-- nothing, and the fallback takes over exactly as it did before.
	quest = function(spec)
		Family:TryCall(GameTooltip.SetHyperlink, GameTooltip, "quest:" .. tostring(spec))
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
-- Which of our frames the pointer is on, so that a modifier pressed without moving it can ask
-- that frame to show its tooltip again.
local hovered

-- The modifiers as they were the last time this looked, and how to look. Up here with
-- `hovered` because the row's own OnEnter seeds them, and that is written before the frame
-- that watches them is - a local declared after its first use is a global, and a global is nil.
local lastCtrl, lastShift, lastAlt

-- Made here and given its behaviour further down, where the reasoning for it is. It has to
-- exist before `AttachTooltip`, which shows and hides it as the pointer arrives and leaves.
local modifiers = CreateFrame("Frame")
modifiers:Hide()

local function modifierState()
	return (IsControlKeyDown and IsControlKeyDown()) and true or false,
		(IsShiftKeyDown and IsShiftKeyDown()) and true or false,
		(IsAltKeyDown and IsAltKeyDown()) and true or false
end

local function showFor(frame)
	local resolve = frame and frame.__familyTooltip
	if not resolve then return end

	local kind, id, fallback, hint, extra = resolve(frame)

	-- A row with nothing to say **takes the tooltip down** rather than leaving it alone.
	--
	-- Leaving it alone leaves whatever the last row put there, which is a tooltip about
	-- another row sitting beside this one and looking exactly like this row's own. The
	-- pointer leaving a row hides it, so this only shows itself where one row's tooltip is
	-- still up as another is entered - and the cost of hiding something already hidden is
	-- nothing. It is the on-screen twin of the fault L-063 records inside the scanner.
	if not kind and not fallback then
		GameTooltip:Hide()
		return
	end

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	Family:TryCall(GameTooltip.ClearLines, GameTooltip)

	local show = kind and SHOW[kind]
	if show and id then show(id) end

	if not wroteAnything() then
		if not fallback or #fallback == 0 then
			GameTooltip:Hide()
			return
		end

		-- Taken back before anything of ours is written on it.
		--
		-- A lane that asked the client for something it will not describe does not leave the
		-- tooltip as it found it: lines added afterwards go nowhere. Reported from play the
		-- hour the quest lane started asking in a form the client sometimes answers - a
		-- single character's quest rows went from showing Family's own summary to showing
		-- nothing at all, and that summary had been the whole tooltip on those rows since
		-- they were written.
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		Family:TryCall(GameTooltip.ClearLines, GameTooltip)

		for _, line in ipairs(fallback) do
			if line[2] then
				GameTooltip:AddDoubleLine(line[1], line[2])
			else
				GameTooltip:AddLine(line[1])
			end
		end
	end

	-- What Family knows and the client does not, written under whatever the client said.
	--
	-- Every lane above asks the game to describe a thing by its id, and the game describes
	-- it as it is **for whoever is being played**. That is right for an item and wrong for a
	-- quest: hovering another character's row and reading *You are on this quest* over a
	-- list of four requirements, on a row the panel has just said is two of four done, is
	-- the client answering a question about the player under somebody else's name. Reported
	-- from play 2026-09-05.
	--
	-- So this is not a fallback. The client's answer is kept - it is the quest's own text,
	-- which is worth having - and the per-character half is added to it.
	for _, line in ipairs(extra or {}) do
		if line[2] then
			GameTooltip:AddDoubleLine(line[1], line[2])
		else
			GameTooltip:AddLine(line[1])
		end
	end

	-- Said out loud, because a reading you only find by holding a key you had no reason to
	-- hold is a reading nobody finds.
	if hint then GameTooltip:AddLine(hint) end

	GameTooltip:Show()
end

function UI:AttachTooltip(frame, resolve)
	frame:EnableMouse(true)
	frame.__familyTooltip = resolve

	frame:SetScript("OnEnter", function(self)
		hovered = self

		-- What the keys are *now*, so that arriving on a row with CTRL already held does
		-- not read as the key having just been pressed. The row's own resolver has already
		-- taken that into account below; this is only about what counts as a change.
		lastCtrl, lastShift, lastAlt = modifierState()
		modifiers:Show()

		showFor(self)
	end)

	frame:SetScript("OnLeave", function(self)
		if hovered == self then
			hovered = nil
			modifiers:Hide()
		end
		GameTooltip:Hide()
	end)
end

-- A modifier pressed while the pointer is held still.
--
-- Measured on Era and TBC before it was written (backlog entry 2). The client *will* repaint a
-- tooltip with the mouse still - but a repaint that puts something **else** in it is painted
-- over by whoever owns the tooltip, and on a bag it is another addon's frame that owns it.
-- Asking the owner to show the same thing again is stable, and here the owner is ours.
--
-- So this does not reach into `GameTooltip`: it asks the row the pointer is on to draw its own
-- tooltip a second time, and the row decides what the modifier now means.
-- **Watched rather than listened for, and that is the whole of this.**
--
-- This used `MODIFIER_STATE_CHANGED`, which is the obvious event and is the right one until a
-- box on the same panel has the keyboard. Then the client gives the key to the box and the
-- event never arrives - so the swap worked with an empty search box and was dead the moment
-- anything was typed into one, which on the whole-family readings is always, because the
-- search is what produces the rows.
--
-- Reported from play 2026-09-05 as *CTRL does nothing in whole family*, and it looked like two
-- faults for a day: whole family broken, and single character breaking after the pointer left
-- a row and came back. One cause. Alberto found it - *it only stops when there is a filter in
-- the box* - and the confirming test was to click the filter away and watch the key start
-- working again.
--
-- Taking the focus off the box instead would have been fighting the player for the keyboard
-- while they are still typing. Reading the key is not something that needs an event.
-- Only while the pointer is on one of our rows. A frame runs `OnUpdate` when it is shown, so
-- being hidden the rest of the time is the whole of the cost control - there is no timer to
-- cancel and nothing to remember to stop.
--
-- **What this cannot do, measured 2026-09-06 rather than reasoned about.** Reported from play as
-- *sometimes the CTRL trick stops working*, with the conditions found by Alberto himself: WoW
-- windowed on one screen, something else clicked on a second screen, then the pointer moved back
-- over a recipe row without clicking. Tooltips still appear; CTRL does nothing. Clicking anywhere
-- in the Family window wakes it, and clicking another application on the *same* screen never
-- breaks it - because getting back to WoW from that screen means clicking WoW.
--
-- A probe recorded one sample a second: `.. .. .. .W .W .W .W .W .W .W .W .. .. .W .. .. C.`,
-- where the first letter is `IsControlKeyDown()` and the second is whether this frame was shown.
-- Seventeen samples in seventeen seconds, so the client goes on running scripts perfectly well
-- while it has no focus. Eight consecutive `.W` are the seconds he was holding CTRL on a row:
-- **the watcher was awake and the client said no key was down.** The last sample, `C.`, is the
-- same probe seeing CTRL the instant the window had focus again.
--
-- **And what it cannot do on an action bar, told by Alberto 2026-09-16.** Pressing CTRL with the
-- pointer already on a bar slot changes nothing: the bar is Dominos, and every action bar addon -
-- the game's own included - listens to shift, control and alt to offer a second and third binding
-- on the same slot. The key is the bar's, and the slot is not re-shown because of it. Family cannot
-- repair that from here: it does not own that tooltip and repainting somebody else's is what the
-- note at the top of ItemClick.lua is about. The key still works there the other way round - held
-- before the pointer arrives, the tooltip is built with it down.
--
-- So the key never reaches the game, and there is nothing here to repair: `IsControlKeyDown` is
-- the only source there is, and a key the client was never given cannot be read from it. Nor can
-- it be worked around - knowing the window is unfocused, if it could be known, still would not
-- say whether a key is being held. Written down here so that the next session to meet this
-- measures nothing twice.
modifiers:SetScript("OnUpdate", function()
	local ctrl, shift, alt = modifierState()
	if ctrl == lastCtrl and shift == lastShift and alt == lastAlt then return end

	lastCtrl, lastShift, lastAlt = ctrl, shift, alt

	if hovered and hovered.IsVisible and hovered:IsVisible() then
		showFor(hovered)
	end
end)

UI.__tooltipModifiers = modifiers

-- **The pile the pointer is on, reachable by the harness**, because the whole of backlog 62
-- is one decision - does the frame chain name the same item the tooltip is describing - and a
-- decision that cannot be asked directly is a decision tested through four other layers.
UI.__pileCount = pileCount

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
