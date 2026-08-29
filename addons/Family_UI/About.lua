-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- What Family is, who wrote it, and how to use it - in the addon rather than on a website.
--
-- An addon is installed by somebody who then has to work out what it does from what it shows
-- them. Most of Family is discoverable that way; three things are not, and they are the three
-- that make the difference between it looking broken and it working:
--
--   that it fills up as you play rather than importing anything,
--   that a bank, a mailbox and a profession window have to be opened once each,
--   and that "not seen" is a different answer from "none".
--
-- Those are the first three paragraphs below for that reason. The rest is a tour.
--
-- The longer manual lives in docs/MANUAL.md and has pictures. This one has to fit on a panel
-- and be worth reading in the ninety seconds somebody will give it.

local _, UI = ...

local Family = _G.Family
local L = Family.L

local GOLD = "|cffffd700"
local GREY = "|cff9d9d9d"
local BLUE = "|cff66bbff"

--------------------------------------------------------------------------------------------
-- The text
--
-- A list of blocks rather than one long string, so the panel decides the spacing and the
-- writing decides the words. `heading` starts a section, `text` is a paragraph, `item` is a
-- line in a list, and `gap` is a breath.
--------------------------------------------------------------------------------------------

local MANUAL = {
	{ heading = L["What it is"] },
	{ text = L["Family remembers what each of your characters owns and knows, and shows it to "
		.. "you while you are logged in on a different one. Who has the mageweave, who can "
		.. "make the belt, which of them has a transmute ready."] },

	{ heading = L["It starts empty"] },
	{ text = L["Family imports nothing from anywhere. It records the character you are "
		.. "playing, as you play, and a character appears in it the first time you log in "
		.. "on them. A family of ten takes ten logins to be complete, and then stays "
		.. "complete on its own."] },

	{ heading = L["Three windows to open once each"] },
	{ text = L["Bags, money, gear, skills, talents and quests are read without being asked. "
		.. "Three things are only visible to the game while their window is open, so open "
		.. "each of them once per character and Family has them from then on:"] },
	{ item = L["your |cffffd700bank|r, at any bank"] },
	{ item = L["your |cffffd700mailbox|r"] },
	{ item = L["each |cffffd700profession|r window, for the recipes in it"] },
	{ text = L["|cff9d9d9dAnything Family has not seen is reported as not seen, never as "
		.. "empty. Every screen says how old what it is showing is.|r"] },

	{ heading = L["Opening Family"] },
	{ item = L["|cffffd700/family|r or |cffffd700/fam|r opens this window"] },
	{ item = L["|cffffd700/family help|r lists everything that can be typed"] },
	{ item = L["the minimap button: left-click opens Family, right-click the options. Drag it "
		.. "around the edge to move it"] },
	{ item = L["any data broker bar shows the same, with the family's money on it"] },

	{ heading = L["Summary"] },
	{ text = L["Every member on one table, one line each. The buttons along the top change "
		.. "which columns are shown - money and bags, professions, quests, everything else "
		.. "- and each realm is totalled separately."] },
	{ item = L["left-click a profession to open that member's recipes"] },
	{ item = L["right-click a member to remove them from the family"] },

	{ heading = L["Abilities & Talents"] },
	{ text = L["The talent trees as the game draws them, both specialisations where the "
		.. "character has two, the glyphs, and the spellbook. Hovering anything shows the "
		.. "game's own description of it."] },

	{ heading = L["Possessions"] },
	{ text = L["One member's bags, bank, mailbox, auctions and guild bank, drawn as the bags "
		.. "themselves. Clicking an item opens the bag it is in, when it is the character "
		.. "you are playing."] },
	{ text = L["Tick |cffffd700the whole family|r and the search looks through everybody at "
		.. "once, and says who has what it found."] },

	{ heading = L["Professions"] },
	{ text = L["What one member can make, sorted by what will skill them up, by what it is "
		.. "worth, or by what they will be able to make next. Clicking a recipe opens it "
		.. "in the profession window, opening the profession first if it is shut - for the "
		.. "character you are playing."] },
	{ text = L["Professions that make nothing are not listed here; the summary has them and "
		.. "their level. |cffffd700The whole family|r searches every recipe of everybody: "
		.. "who can make this, who could learn it."] },

	{ heading = L["Character"] },
	{ text = L["Equipped gear laid out as the character sheet lays it out, with currencies, "
		.. "reputations, the quest log and achievements beside it. Clicking a quest opens "
		.. "it in the log."] },
	{ text = L["|cffffd700Whole family|r turns that gear the other way round: one row per "
		.. "member, their class and then every slot in the same order, with the item level "
		.. "over each icon. A character sheet says what one character is wearing; this "
		.. "says which of them is behind. Filters on realm and class."] },

	{ heading = L["Mail you send"] },
	{ text = L["Post anything to one of your own characters and it is written down against "
		.. "them at once - the money, the attachments and all - so their row is right "
		.. "before they have logged in. It is marked as being |cffffd700in the post|r "
		.. "until that character opens their own mailbox, and then what is really in it "
		.. "replaces the guess."] },

	{ heading = L["The other money"] },
	{ text = L["Honor and arena points, and on Mists everything else the client calls a "
		.. "currency, are recorded alongside gold. The summary totals the ones the family "
		.. "holds most of; Character shows one member's in full, with what each is capped "
		.. "at and how far off it is."] },

	{ heading = L["On the game's own tooltips"] },
	{ text = L["Hovering any item anywhere - a vendor, the auction house, the floor - adds who "
		.. "in the family has one and where it is. On a recipe it adds who can make it "
		.. "already, who can learn it today, and who is not high enough yet."] },

	{ heading = L["Wide Family"] },
	{ text = L["|cff9d9d9dSwitched off until you ask for it. Sharing is the one thing here a "
		.. "later version cannot take back, so it waits to be asked for rather than "
		.. "arriving switched on - but the panel is there so you can see what it is before "
		.. "deciding. The switch is in Options, beside the one for Guild share. Both of you "
		.. "need to.|r"] },
	{ text = L["A family need not be one account. Type another player's character name on the "
		.. "Wide Family panel and ask to link; they accept, and then each of you says what "
		.. "the other may see — one member and one category at a time, on a grid that "
		.. "starts with nothing ticked."] },
	{ item = L["nothing at all is exchanged until they accept"] },
	{ item = L["unticking a box tells them to forget it, at once"] },
	{ item = L["linked members are kept separately and never mixed with your own"] },
	{ item = L["both of you must be online: it is a snapshot, not a subscription"] },
	{ item = L["a request nobody answers is shown as unanswered, with the reasons it could be "
		.. "- the addon channel confirms nothing, so Family will not guess which"] },
	{ text = L["|cff9d9d9dExchanges happen when a linked family comes online, when you change "
		.. "what is shared, and whenever you press Update. Nothing is sent as you log out "
		.. "- the client is already leaving by then and it would not arrive. The first two "
		.. "are one tick box and can be switched off; Update always works, and unticking a "
		.. "box is always sent at once.|r"] },
	{ text = L["Among the members another family shares with you, tick the ones worth seeing "
		.. "every day and they become |cffffd700siblings|r: they appear in your summary, "
		.. "under their own family's name, on the realm they are on. Ticking sends nothing "
		.. "and asks nobody - they had already decided you may see them."] },

	{ heading = L["Guild share"] },
	{ text = L["On, and one tick box turns it off. Everyone in your guild running Family shows "
		.. "their characters' gear and both talent specialisations to everyone else "
		.. "running it, and you see theirs - including while they are offline, once you "
		.. "have seen them once."] },
	{ item = L["nothing else is shared: bags, mail, money and the rest need a Wide Family link"] },
	{ item = L["only their characters who are in this guild, and there is no way to add the "
		.. "others"] },
	{ item = L["guildmates not running Family are invisible to it, which is the ordinary state "
		.. "of a guild"] },
	{ text = L["|cff9d9d9dIt needs no consent grid because all of it is what the game already "
		.. "shows anybody who inspects you. A dialogue in front of that would only teach "
		.. "people to click through the dialogues that matter.|r"] },

	{ heading = L["What Family will not tell you"] },
	{ text = L["Family reports what your characters have and know. It does not advise. It will "
		.. "not tell you which recipes a member is still missing, which piece of gear to "
		.. "improve next, or where in the game an item can be found."] },
	{ text = L["|cff9d9d9dNone of that is in the game client - where a thing comes from lives "
		.. "on the server - so an addon that answers it is reading a list somebody typed "
		.. "up outside the game, and cannot tell you how old that list is. Everything "
		.. "Family says, it says because the client said it.|r"] },

	{ heading = L["Cooldowns"] },
	{ text = L["Transmutes, mooncloth, salt shakers and the rest are recorded as the moment "
		.. "they come ready rather than as time remaining, so they stay right however long "
		.. "the client has been shut. Family says what is ready when you log in."] },
}

local ABOUT = {
	{ heading = L["Family"] },
	{ text = L["Written from scratch by |cffffd700Alberto Pittaluga|r. Not a fork of anything."] },
	{ text = L["Free software under the |cffffd700GNU General Public License, version 3 or "
		.. "later|r. You may use, study, change and pass it on; a changed version has to "
		.. "carry the same licence and say what was changed. Nobody can take Family "
		.. "closed, including if this project is ever abandoned - which is why that "
		.. "licence."] },
	{ text = L["Source, faults and suggestions: |cff66bbffhttps://github.com/uga/Family|r"] },
}

--------------------------------------------------------------------------------------------

local function build(frame)
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -4)
	title:SetText(L["About Family"])

	local version = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	version:SetPoint("LEFT", title, "RIGHT", 10, -1)
	version:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
	version:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -32)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(1, 1)
	scroll:SetScrollChild(list)
	UI:MakeScrollable(scroll)

	local widgets = {}

	local function nextWidget(index, style)
		local widget = widgets[index]
		if not widget then
			widget = list:CreateFontString(nil, "ARTWORK", style)
			widgets[index] = widget
		end
		return widget
	end

	function frame:Refresh()
		local used, y = 0, 0
		local width = math.max(UI:ListWidth(scroll) - 16, 200)
		list:SetWidth(width + 16)

		-- Laid out by measuring, not by guessing: a paragraph's height depends on how many
		-- lines it wrapped to, and the client is the only thing that knows that. Asking it
		-- afterwards is what keeps the panel right at any window width.
		local function place(block)
			local isHeading = block.heading ~= nil
			local text = block.heading or block.text or block.item

			used = used + 1
			local widget = nextWidget(used,
				isHeading and "GameFontNormalLarge" or "GameFontHighlightSmall")
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", block.item and 16 or 2, -y)
			widget:SetWidth(width - (block.item and 16 or 0))
			widget:SetJustifyH("LEFT")
			widget:SetJustifyV("TOP")
			widget:SetText(isHeading and (GOLD .. text .. "|r")
				or (block.item and ("|cff888888-|r  " .. text) or text))
			widget:Show()

			if isHeading and y > 0 then
				y = y + 10
				widget:SetPoint("TOPLEFT", 2, -y)
			end

			y = y + math.max(widget:GetStringHeight() or 12, 12) + (isHeading and 6 or 4)
		end

		for _, block in ipairs(ABOUT) do place(block) end
		y = y + 12
		for _, block in ipairs(MANUAL) do place(block) end

		for index = used + 1, #widgets do widgets[index]:Hide() end
		list:SetHeight(math.max(y, 1))

		-- What is running, which is the first thing worth knowing when something is wrong
		-- and the first thing anybody reporting a fault should be able to read off.
		version:SetText(string.format(L["%sversion %s   |||   %s   |||   %s|r"],
			GREY, tostring(Family.version),
			Family.Capabilities and Family.Capabilities.name or L["unknown client"],
			Family.Codec and Family.Codec.compressing and L["compressed storage"]
				or L["uncompressed storage"]))
	end
end

UI:RegisterTab("about", L["About"], build)
