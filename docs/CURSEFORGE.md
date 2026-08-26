# Family — the CurseForge project description

The text CurseForge shows on the project page, kept here so it is reviewed like everything
else rather than typed into a web form once and forgotten. CurseForge asks for the features,
what each one does to a player's experience, and a clear reason to download; the sections
below are ordered so that a reader who stops after two paragraphs has still been told what
Family changes about the game.

Paste everything below the rule into *Description* on the project page. CurseForge's editor
takes headings, bold and lists; the screenshots named in `docs/images/` are worth uploading
beside it, because the two panels people decide on — the summary and the whole-family gear
grid — are much easier to see than to describe.

Keep it true to the version that is actually published. Two lines in particular go stale:
what Wide Family is doing (switched off in `1.0.0-beta.1`) and the client list.

---

## Family

**An alt manager that answers "what does my other character have?" without logging into them.**

World of Warcraft Classic gives you exactly one way to find out what is in your bank alt's
bags, whether your druid ever learned that recipe, or which of your eleven characters is
carrying the Arcanite Bar: log out, log in, look, log back. The server will not tell you
anything about a character you are not standing on. Family removes that trip. It watches each
character as you play it — what it owns, what it knows, what it is wearing, what it has in the
post — and shows you all of it from any other character, at any time, in one window.

Family calls those characters **members** rather than alts, and it is built for people who
have a lot of them. Forty is a design target, not a stress case.

### The whole family on one screen

The **Summary** is every character you have played, grouped by realm and by faction, with
money, bag space, professions, level, currencies and the rest — and a totals line per realm
plus a grand total. A realm where you play both sides is split into two blocks with their own
subtotals, because two characters on opposite factions of one realm share no auction house and
no mailbox and adding their gold together would be a lie.

What it changes: "how much gold do I actually have" and "which character has bag space" stop
being a login sequence and become a glance.

### Every item, and who has one, on the game's own tooltips

This is the feature you will use most and notice least. Mouse over any item anywhere — a
quest reward, an auction house listing, something in a friend's trade window — and Family adds
a line saying who in the family has one, how many, and **where**: bags, bank, guild bank,
mailbox, auction house. Hover a recipe and it tells you who can already make it, who can learn
it right now, and who is not high enough yet.

What it changes: you stop buying the second Thorium Lockbox because you had forgotten the
first one is in your rogue's bank. The breakdown collapses to a single total if you prefer a
quieter tooltip, and item id and item level can be switched on.

### Possessions, drawn as bags rather than as a spreadsheet

**Possessions** shows a member's containers as containers — the bags, the bank, the guild
bank, the mailbox, laid out the way they look in the game. Clicking an item opens the bag it
lives in, when it is the character you are playing. There is a search across the entire family
that answers *who has this*, so "where did I put the Onyxia head" is one box rather than eleven
logins.

### Professions, including the ones you gave up

Every member's professions with their full recipe lists, sortable three ways — including by
difficulty, which orders **within** each colour band by the skill the recipe needed and then by
what it makes, so nine grey recipes are not just listed alphabetically and called sorted.
Clicking a recipe selects it in a profession window you already have open. Search runs across
the whole family here too: *who can make this*.

Drop a profession and Family keeps its recipe list, so taking it up again loses nothing.

### Everyone's gear on one screen

Any alt manager can show you a character sheet. The question people actually have is **which
of my characters is behind**, and that is not answerable one sheet at a time. Character →
Equipped gear → *Whole family* is one row per member: their class, then every slot in the order
the character sheet uses them, item level printed over each icon, the item's own tooltip on
hover, and filters on realm and class built from what your family actually contains. Empty
slots are visible as empty.

What it changes: you can see at a glance that your warrior is wearing a level 42 trinket at 60,
which is the sort of thing that survives for months because nothing ever puts it in front of you.

### Character, abilities and talents

The full character sheet for any member: equipped gear laid out as the game lays it out, with
the enchants and gems on it, plus currencies, reputations, the quest log and achievements. Both
talent specialisations, glyphs and the spellbook, with untaken talents greyed so a build reads
as a shape rather than as a list of numbers.

### Mail is written down as you post it

Send gold or items to one of your own characters and it appears against **them** immediately —
the money, the attachments, the subject — marked as being in the post. When that character next
opens their own mailbox, what is really there replaces the prediction. Mail approaching its
return-or-destroy date is announced in chat, on any member, which is the whole point: it is
never the character you are playing that is about to lose a letter.

### Cooldowns that survive being logged out

Crafting and item cooldowns are recorded as **the moment they come ready**, not as a duration,
so they stay correct however long the client has been shut, and you are told at login. The
Summary has a Crafting column per cooldown kind — green when it is up, grey with the time when
it is not. Thirty alchemy transmutes share one timer and appear as one column, worked out by
watching them come back together rather than from a list somebody has to maintain.

Hearthstones and trinkets are deliberately not in this: the floor is six hours, comfortably
below a daily cooldown and comfortably above everything that is merely on cooldown.

### A minimap button and a data broker feed

Both carry the family's money, and the tooltip breaks it down by realm.

### Guild share — on, and one switch turns it off

Everyone in your guild running Family shows their characters' gear and talent shape to everyone
else running it, including their offline characters once you have seen them once. You see
theirs on the Guild tab. **Nothing else is shared** — no bags, no mail, no gold.

It is on by default because all of it is what the game already shows anyone who inspects you,
and a consent dialogue in front of public information mostly teaches people to click through
consent dialogues. One switch in the options turns it off completely. Guildmates who do not run
Family are simply invisible to it.

### Wide Family — present, and switched off in this version

Linking two players' families, with per-member and per-category consent on a grid that starts
with nothing ticked, so a friend can see your gear but not your gold, or one character and not
the rest. Untick a box and the other side is asked to forget it at once. It is finished and its
checks pass, but no check has run against a live server, and sharing is the one thing a later
version cannot undo — so it ships **off** and waits until it has been proven live.
`/family wide on` if you want to help test it.

## What to expect when you install it

Family is honest about the difference between *nothing* and *not seen yet*, and that shapes how
it behaves on day one.

- **It starts empty and fills as you play.** There is no import from any other addon, ever.
  Everything Family holds, it holds because it watched it happen.
- **Log into each character once** to get the bulk of it. Bank, guild bank, mailbox and each
  profession window need opening once per character, because the game only reveals their
  contents while they are open.
- **Bags are the exception** — rescanned after every login and on every change.
- **Nothing is ever shown as empty when it was simply never seen**, and every screen says how
  old what it is showing is.
- **Records survive the characters.** Deleted a character? Its records stay until you clear
  them; right-click on the summary removes a member, a realm or an account.
- **Each client keeps its own records.** Era, Burning Crusade and Mists are separate
  installations with separate saved files and Family does not merge them.

## Clients and languages

Classic Era, Classic Burning Crusade (Anniversary) and Classic Mists of Pandaria. Season of
Discovery and Retail are not supported and not planned.

Interface and recorded data in **English, German, French, Spanish and Russian** — every
language Blizzard ships a Classic client in. Family stores identifiers rather than names, so a
character recorded on a German client reads back correctly on a French one with no translation
involved.

## Two addons, one download

`Family` records and `Family_UI` shows. Neither is useful without the other, so they travel
together in one zip and installing is one action.

## Free software

Family is licensed **GPL-3.0-or-later**, and the source is public. You may use, study, modify
and redistribute it. Nobody can take Family closed — including if this project is ever
abandoned, which is the reason that licence was chosen.
