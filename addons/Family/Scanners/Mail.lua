-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- The mailbox.
--
-- Readable only while a mailbox is open, so it is a snapshot like the bank - but like an
-- auction and unlike a bank, its contents leave on their own. Mail expires, and expired mail
-- takes whatever was attached to it. Days left is therefore recorded as the moment it runs
-- out, so that a snapshot taken on Monday still says something true on Wednesday.
--
-- That expiry is the reason the specification puts a warning on this (§5): the whole point of
-- an alt manager noticing is that it is *not* the character you are playing whose mail is
-- about to be destroyed.
--
-- The other half of this file is the one moment where Family knows something about a mailbox
-- that is not open: posting to one of your own characters. The money, the attachments and the
-- subject are all in front of you at the instant you press Send, so they are written into the
-- *recipient's* record then and there, and their row is right before that member has logged
-- in (§5).
--
-- That is not an exception to §2.2. The letter was seen - by the sender, being sent. What is
-- carefully not claimed is that it has arrived, so a letter recorded that way is marked as
-- being in the post, and the moment that member opens their own mailbox their own scan
-- replaces the lot. A real inbox is a better fact than a prediction of one, and it wins
-- without having to be reconciled.

local _, Family = ...

local Mail = {}
Family.Mail = Mail

local DAY = 86400

-- How long a letter nobody collects stands before the game sends it back. Used only for mail
-- Family watched being posted; anything read out of a real mailbox carries the client's own
-- countdown and needs no rule of thumb.
local RETURNS_AFTER = 30 * DAY

--------------------------------------------------------------------------------------------

function Mail:Scan()
	local key = Family:CurrentMember()

	local count = Family:TryCall(GetInboxNumItems) or 0
	local letters = {}
	local now = time()
	local soonest

	for index = 1, count do
		local _, _, sender, subject, money, cod, daysLeft, itemCount, wasRead =
			Family:TryCall(GetInboxHeaderInfo, index)

		-- daysLeft is a fraction of days and counts down in real time, so it is only
		-- meaningful next to the moment it was read.
		local expires = daysLeft and (now + (daysLeft * DAY)) or nil

		local letter = {
			sender = sender,
			subject = subject,
			money = tonumber(money) or 0,
			cod = tonumber(cod) or 0,
			expiresBy = expires,
			read = wasRead and true or false,
			attachments = {},
		}

		for attachment = 1, (tonumber(itemCount) or 0) do
			local link = Family:TryCall(GetInboxItemLink, index, attachment)
			local _, itemID, _, quantity = Family:TryCall(GetInboxItem, index, attachment)

			itemID = tonumber(itemID) or (link and tonumber(link:match("item:(%d+)")))
			if itemID then
				letter.attachments[#letter.attachments + 1] = {
					id = itemID,
					count = tonumber(quantity) or 1,
					-- Only where the id does not describe it: a posted "of the Eagle"
					-- is one id and a suffix, and the suffix is the whole point of it
					-- (Core.lua).
					item = Family:ItemString(link),
				}
			end
		end

		if expires and (not soonest or expires < soonest) then soonest = expires end
		letters[#letters + 1] = letter
	end

	local payload = Family.Database:Payload(key) or {}
	payload.mail = { letters = letters, seen = now }
	Family.Database:SetPayload(key, payload)

	Family.Database:SetMeta(key, {
		mailCount = #letters,
		mailSeen = now,
		mailExpiresBy = soonest or Family.CLEAR,
		-- Whatever was recorded as being in the post has either arrived, in which case it
		-- is in the list above and counted properly, or it has not and there is no longer
		-- any reason to believe it will. Either way the guess is over.
		mailInPost = Family.CLEAR,
	})

	Family:Debug("scanned mailbox: %d letter(s)", #letters)
end

-- Everything still in the box as of now, with what has expired since the snapshot dropped.
function Mail:Live(record)
	if not record then return {} end

	local now = time()
	local live = {}

	for _, letter in ipairs(record.letters or {}) do
		if not letter.expiresBy or letter.expiresBy > now then
			live[#live + 1] = letter
		end
	end

	return live
end

--------------------------------------------------------------------------------------------
-- Posting to one of your own
--------------------------------------------------------------------------------------------

-- Which member a typed name refers to, or nothing.
--
-- The box takes "Nervina" or "Nervina-Firemaw", in whatever case somebody felt like typing,
-- and Family's keys are "Name-RealmWithoutSpaces". So the comparison is made on both halves
-- separately and without case, rather than by tidying the typed name into a key and hoping
-- the two tidying rules agree. A bare name means this realm, which is what the game means by
-- it.
local function memberNamed(recipient)
	if type(recipient) ~= "string" then return nil end

	local name, realm = recipient:match("^([^%-]+)%-(.+)$")
	name = name or recipient
	name = name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
	if name == "" then return nil end

	realm = (realm or Family:TryCall(GetRealmName) or ""):gsub("%s+", ""):lower()

	for key, entry in pairs(Family.Database:Members()) do
		local meta = entry.meta or {}
		local theirName = (meta.name or key:match("^([^%-]+)") or ""):lower()
		local theirRealm = (meta.realm or ""):gsub("%s+", ""):lower()

		if theirName == name and (theirRealm == realm or theirRealm == "") then
			return key
		end
	end

	return nil
end

-- What is attached to the letter about to go, read now because in a moment it will not be.
--
-- The client clears the attachments when the server confirms the send, so this is read as the
-- send is made and held until the confirmation arrives. Reading it afterwards gets an empty
-- frame, which would record every parcel as an empty envelope - the worst kind of wrong,
-- because it looks like a working feature.
local function attachmentsNow()
	local attachments = {}
	local slots = tonumber(_G.ATTACHMENTS_MAX_SEND) or 12

	for slot = 1, slots do
		local _, itemID, _, count = Family:TryCall(GetSendMailItem, slot)

		-- Some of these clients answer with the id and some only with a link, so both are
		-- asked and the first one that produces a number wins (§2.1 - what is stored is the
		-- id either way).
		if not itemID then
			local link = Family:TryCall(GetSendMailItemLink, slot)
			itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
		end

		itemID = tonumber(itemID)
		if itemID then
			attachments[#attachments + 1] = { id = itemID, count = tonumber(count) or 1,
				item = Family:ItemString(Family:TryCall(GetSendMailItemLink, slot)) }
		end
	end

	return attachments
end

-- One letter onto a member's record, and the three figures in meta that follow from it.
--
-- Shared by the two things that can put a letter on a record before anybody has seen a
-- mailbox: posting to an alt, and winning an auction. Both are claims about the post and not
-- about a mailbox, and both are replaced wholesale the moment that character opens their own.
local function addLetter(key, letter)
	local meta = Family.Database:Meta(key)
	if not meta then return false end

	local payload = Family.Database:Payload(key) or {}
	payload.mail = payload.mail or { letters = {} }
	payload.mail.letters = payload.mail.letters or {}

	table.insert(payload.mail.letters, letter)
	Family.Database:SetPayload(key, payload)

	local inPost = 0
	local soonest = meta.mailExpiresBy
	for _, entry in ipairs(payload.mail.letters) do
		if entry.inPost then inPost = inPost + 1 end
		if entry.expiresBy and (not soonest or entry.expiresBy < soonest) then
			soonest = entry.expiresBy
		end
	end

	Family.Database:SetMeta(key, {
		mailCount = #payload.mail.letters,
		mailInPost = inPost,
		mailExpiresBy = soonest or Family.CLEAR,
	})

	return true
end

-- Held between the send and the server saying it worked. A send the server refuses is never
-- recorded: the record is written on the confirmation, not on the button.
local posted

function Mail:NoteSend(recipient, subject)
	local key = memberNamed(recipient)
	if not key then
		-- Somebody who is not one of ours. Nothing is written down about them, here or
		-- anywhere else.
		posted = nil
		return nil
	end

	posted = {
		key = key,
		subject = subject,
		money = tonumber((Family:TryCall(GetSendMailMoney))) or 0,
		cod = tonumber((Family:TryCall(GetSendMailCOD))) or 0,
		attachments = attachmentsNow(),
		at = time(),
	}

	return key
end

-- The server said it went. Now it is a fact about somebody else's mailbox.
function Mail:CommitSend()
	local letter = posted
	posted = nil
	if not letter then return false end

	-- Only for a member Family already knows. Writing a record here for a name that has
	-- never been played would invent a member out of an addressed envelope.
	local meta = Family.Database:Meta(letter.key)
	if not meta then return false end

	local from = Family.Database:Meta(Family:CurrentMember())
	local expires = letter.at + RETURNS_AFTER

	addLetter(letter.key, {
		sender = (from and from.name) or Family:CurrentMember(),
		subject = letter.subject,
		money = letter.money,
		cod = letter.cod,
		expiresBy = expires,
		read = false,
		-- The whole of what is being claimed, and the whole of what is not. This letter was
		-- posted, at this moment, and nobody has yet seen it in a mailbox.
		inPost = true,
		sentAt = letter.at,
		attachments = letter.attachments,
	})

	Family:Debug("posted to %s: %d attachment(s), %d copper", letter.key,
		#letter.attachments, letter.money)

	return true
end

-- An auction won, which the server sends as mail to whoever won it.
--
-- The same claim as a letter posted to an alt and made the same way: something is on its way
-- to this character that is not in their bags yet, and the moment they open their own mailbox
-- the real contents replace it. It is written here rather than in the auction scanner because
-- what is being recorded is a letter, and letters live in one place.
--
-- **Only ever on the server saying the auction was won.** Auctions.lua watches the bid go and
-- holds what was bid on; nothing reaches here until the client is told it was won, so a buyout
-- somebody beat you to, or one there was not gold for, writes nothing at all. That is the same
-- guarantee `MAIL_SEND_SUCCESS` gives the outgoing side, from the same reasoning.
--
-- No subject: a player's letter has one because a player typed it, and an auction has an item.
-- The name of that item is the client's to supply from the id at draw time (§2.1).
function Mail:CommitWon(won)
	if not won or not won.id then return false end

	local key = Family:CurrentMember()
	if not key or not Family.Database:Meta(key) then return false end

	local at = time()

	local ok = addLetter(key, {
		sender = Family.L["Auction House"],
		money = 0,
		cod = 0,
		expiresBy = at + RETURNS_AFTER,
		read = false,
		inPost = true,
		wonAt = at,
		sentAt = at,
		attachments = { { id = won.id, count = won.count or 1, item = won.item } },
	})

	if ok then Family:Debug("won at auction: item %d x%d", won.id, won.count or 1) end
	return ok
end

-- How many letters this member has that nobody has seen in a mailbox yet.
function Mail:InPost(meta)
	return (meta and tonumber(meta.mailInPost)) or 0
end

--------------------------------------------------------------------------------------------

-- How long until this member loses something, in seconds, or nil when nothing is at risk.
function Mail:TimeToExpiry(meta)
	if not meta or not meta.mailExpiresBy then return nil end
	local remaining = meta.mailExpiresBy - time()
	if remaining <= 0 then return 0 end
	return remaining
end

-- Everybody holding something that has expired or will within `within` seconds, soonest
-- first.
--
-- **Siblings as well as our own**, each carrying the name of the family it belongs to. This
-- was built the other way first, on the reasoning that a mailbox in somebody else's family is
-- a problem the reader cannot go and fix - which turned out to be an assumption about how
-- people use Wide Family rather than a fact about it, and Alberto's answer was that they
-- coordinate. Whose a character is is never merged away (§6), which is what the family name
-- is doing here.
--
-- The realm travels with every one of them. Same-named alts on different realms are ordinary,
-- and a notice that names one of them names neither.
--
-- `expired` rather than a time of nought, because the two are different facts and the caller
-- has to be able to say so: mail whose moment has passed is mail already lost, and telling
-- somebody it expires "now" invites them to run for a mailbox that has nothing in it.
function Mail:Expiring(within)
	local found = {}

	local function consider(key, meta, familyName)
		local left = Mail:TimeToExpiry(meta)
		if not left or left > (within or 0) then return end

		found[#found + 1] = {
			key = key,
			name = meta.name or key,
			realm = meta.realm,
			family = familyName,
			expiresBy = meta.mailExpiresBy,
			left = left,
			expired = left <= 0,
		}
	end

	for key, entry in pairs(Family.Database:Members()) do
		consider(key, entry.meta or {}, nil)
	end

	-- Nothing at all when Wide Family is switched off, which `Siblings` answers for us, and
	-- nothing for a shared character whose family has not sent an expiry: a link that last
	-- exchanged before that field was sent by the right name has no such figure, and an
	-- absence is not a nought (§2.2).
	for _, member in ipairs(Family.Wide and Family.Wide:Siblings() or {}) do
		consider(member.key, member.meta or {}, member.familyName)
	end

	table.sort(found, function(a, b)
		if a.left ~= b.left then return a.left < b.left end
		if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
		if (a.realm or "") ~= (b.realm or "") then return (a.realm or "") < (b.realm or "") end
		return (a.family or "") < (b.family or "")
	end)

	return found
end

--------------------------------------------------------------------------------------------

Family:OnDatabaseReady("mail", function()
	for _, event in ipairs { "MAIL_INBOX_UPDATE", "MAIL_SHOW" } do
		Family:RegisterEvent(event, "mail", function()
			Family:After(0.5, "mail", function() Mail:Scan() end)
		end)
	end

	-- One last look on the way out, so anything taken while the box was open is gone from
	-- the record too.
	Family:RegisterEvent("MAIL_CLOSED", "mail", function()
		Mail:Scan()
	end)

	-- Watching the outgoing letter go.
	--
	-- Hooked rather than reimplemented: the send is Blizzard's, and the hook runs
	-- immediately after their call with the frame still holding everything that was
	-- attached to it. Wrapped in a check that the hook exists at all, like every other
	-- optional call in Family - the addon works without this, it simply learns about the
	-- letter later, when the recipient opens their own mailbox.
	if type(_G.hooksecurefunc) == "function" and type(_G.SendMail) == "function" then
		Family:TryCall(_G.hooksecurefunc, "SendMail", function(recipient, subject)
			Mail:NoteSend(recipient, subject)
		end)
	else
		Family:Debug("no way to watch outgoing mail on this client")
	end

	-- The confirmation, which is the only thing that makes a send a fact. A send the
	-- server refuses fires nothing, and nothing is what gets recorded.
	Family:RegisterEvent("MAIL_SEND_SUCCESS", "mail", function()
		Mail:CommitSend()
	end)
end)
