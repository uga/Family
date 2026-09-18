# Family — the manual

An alt manager for World of Warcraft Classic. It records what each of your characters owns
and knows, and shows it to you while you play a different one. Family calls your characters
**members**.

A shorter guide is inside the addon, on the **About** tab.

---

## Contents

1. [The five minutes that matter](#1-the-five-minutes-that-matter)
2. [Opening Family](#2-opening-family)
3. [Summary](#3-summary)
4. [Abilities & Talents](#4-abilities--talents)
5. [Possessions](#5-possessions)
6. [Professions](#6-professions)
7. [Character](#7-character)
8. [On the game's own tooltips](#8-on-the-games-own-tooltips)
9. [Searching the whole family](#9-searching-the-whole-family)
10. [Crafting cooldowns](#10-crafting-cooldowns)
11. [Wide Family](#11-wide-family)
12. [Guild share](#12-guild-share)
13. [Options](#13-options)
14. [What Family will not do, and why](#14-what-family-will-not-do-and-why)
15. [When something looks wrong](#15-when-something-looks-wrong)

---

## 1. The five minutes that matter

**It starts empty.** Family records the character you are playing, as you play. A character
appears the first time you log in on them. A family of ten needs ten logins, and then keeps
itself up to date. Nothing is imported from any other addon.

**It speaks your language.** Family is written in English, German, French, Spanish and
Russian, and follows the language of your game. Where the game has its own word for something
— a gear slot, a class, a reputation standing, a profession, a race — Family uses that word.
Anything not yet translated appears in English.

**Some things need doing once per character.** Bags, money, gear, skills, talents, currencies
and quests are read without your help. The game shows the rest only while a window is open or
a pet is out. Do each of these once on each character. After that, Family updates them every
time you open the same window again.

| Do this | To record |
|---|---|
| open your **bank** | what is in it, and how many slots are free |
| open the **guild bank** (Burning Crusade and Mists) | what is in each tab you look at |
| open your **mailbox** | what is waiting, and when it expires |
| open the **auction house** | your auctions and your bids |
| open each **profession** window | its recipes, their difficulty, and its cooldowns |
| **summon** each pet or demon | what that creature can do |

**Nothing is shown as empty when it was never seen.** A bank nobody has opened reads *bank not
seen*, not *0 items*. A crafting cooldown that started while the profession window was shut is
unknown until you open that window again. Every screen says how old its information is. If a
number looks wrong, first check when Family last saw it. The answer is on screen.

**After an update, new information fills in as you play.** When a new version records
something for the first time, it is blank on each character until you log in on them once. A
character that a linked family shares with you fills in when its owner logs in on the new
version.

---

## 2. Opening Family

| How | What it does |
|---|---|
| `/family` or `/fam` | opens the window, or closes it if it is open |
| `/family help` | lists everything that can be typed |
| **minimap button**, left-click | opens Family on the summary |
| **minimap button**, right-click | opens the options |
| **minimap button**, drag | moves it around the edge of the minimap |
| any **data broker** bar | the same clicks, with money and bag space on the bar |
| **shift-click** the button or the broker | changes what the bar counts |

The bar starts on **the character you are playing**. It shows a bag icon with their free and
total bag slots, *16/76*, then their money. The bag figure counts ordinary bag slots, like the
summary's bag columns.

**Shift-click** moves on to **the whole family**, then to **your faction on this realm**, then
back to the character. Those two show a group icon and the number of characters counted. A
middle click does the same as shift-click. Your choice is remembered, and the tooltip always
says which of the three the bar is showing.

The realm setting counts one faction only. Two factions on one realm share no mailbox and no
auction house, so that figure is gold you can spend together.

Left-click always opens the summary and right-click always opens the options. Click again
while that page is showing and the window closes.

**Hover the minimap button or the broker** to see the whole family at a glance: every realm,
every member with their level, item level and money, and a total for all realms. Below that:

- **Crafting cooldowns ready**, as a number of members. The **Crafting** columns of the
  summary name them (§10).
- **Mail expiring soon**, as a number of members with mail less than three days from being
  returned or destroyed. This always counts the whole family, whatever the bar is set to.

The tooltip always lists everybody. When the bar counts less than that, a line near the bottom
says what the bar is counting.

**A large family still fits the screen.** The realm totals, the grand total and the two
warnings are always shown. The list of characters takes the room that is left and ends with
*and 14 more* where it has to stop. The realm you are on gets room first, and within each
realm the richest characters are kept.

![The minimap button hovered: every realm, every member, and the totals](images/broker-tooltip.png)

---

## 3. Summary

One line per member, grouped by realm. Each realm has a totals line, and a grand total follows
when you have more than one realm. Click a column heading to sort by it.

![The summary on Overview, a family across two realms with a totals line](images/summary-overview.png)

The buttons across the top choose which columns are shown:

| Set | Columns |
|---|---|
| **Overview** | level, item level, rested experience, money, worth, time played, last seen |
| **Bags** | free and total slots in the bags and in the bank, and when each was last seen |
| **Activity** | mail, mail on its way, when it expires, auctions, bid value, buyout value, and when the mailbox and the auction house were last seen |
| **Professions** | every profession and its rank, primaries first |
| **Currencies** | honor, arena points, and anything else your game counts as a currency |
| **Crafting** | every crafting cooldown in the family: ready, or when it comes back |
| **Miscellaneous** | race, guild, where they logged out, hearthstone, mount, and world buffs stored in a Chronoboon |

**A realm where you play both factions is split in two**, with a subtotal under each. The two
sides share no mail and no auction house, so each subtotal is gold those characters can send
one another. A realm with one faction on it is not split.

**The two banners** at the right of the buttons filter by faction. Both are on to begin with,
and you can switch either off.

What you can click:

- **A member on Professions** opens their recipes.
- **A member on Bags** opens their possessions.
- **The Mail figure** on Activity unfolds that member's mail: one line per letter, with its
  sender, what is attached and when it expires.
- **The Chrono figure** on Miscellaneous unfolds what their Chronoboon holds: each world buff
  as its own icon, with the time left on it and the game's own description on hover.
- **Right-click a member** to remove them from Family. You are asked first, by name and realm.
  This removes Family's record only, never anything in the game.

The two unfolds are independent. Opening one does not close the other.

**A blank and a dash mean different things.** In the **Chrono** column a number is how many
buffs are stored, a blank means none, and a dash means Family does not know yet. In the
**Guild** column a blank means the character is in no guild, and a dash means Family does not
know yet. A dash fills in the next time you play that character.

**Worth** is what everything that character holds comes to, in gold. It is the same figure as
the line on their Possessions page. Hover the row for the exact amount, and for how much of it
comes from auction prices and how much from vendor prices. Worth adds up per realm and per
faction, like money. A character with nothing priced yet is blank, not zero.

**Siblings** (§11) appear here too. They sit under the realm they are on, after your own
members, under the name of the family they belong to. They are never added to the totals.
Right-click does not remove a sibling. Untick them on the Wide Family panel.

**Class** is the colour of each member's name, and is spelled out in the row's tooltip.

Two limits to know. Free and total slots leave out quivers, soul bags and other special bags,
because nothing else fits in them. The Currencies set shows the currencies your family holds
most of, and says how many it left out.

---

## 4. Abilities & Talents

The talent trees as the game draws them: icons at the tier and column they really occupy, with
the ones nobody has taken drawn grey rather than left out. Where the gaps are is half of what a
tree says.

![Abilities and Talents: a tree drawn as the game draws it, untaken talents greyed](images/talents.png)

- Both **specialisations** where the character has two, with the active one marked.
- **Points spent** out of points available, and how many are left to spend.
- **Glyphs**, on the clients that have them.
- The **spellbook**, by school, and a hunter's Beast Training with it.
- **Pets**, for a hunter's stable and a warlock's demons: every creature Family has seen, with
  what each of them can do.

Hovering anything shows the game's own description of it.

**About Pets.** A hunter's four pets each know different things, and so does each of a warlock's
demons — and the game will only say what a creature knows while that creature is out. So the page
fills in one summon at a time, and it keeps what it has seen: a pet you summoned last month is
still listed with its abilities today. A pet the stable names but that has never been out is
listed too, under *In the stable*, with nothing claimed about what it can do, because nothing has
been seen. The abilities themselves are named by your own client, in your own language, whoever
recorded the creature.

**Training points add up.** Each ability carries what it cost, and the creature says how much of
what it has spent that accounts for — *273 of 273 Training Points accounted for*. What a pet has
**left to spend** is in green on its row, the number you would go to a trainer about; a freshly
tamed pet, which owes points until it is loyal, says so in red. The **Beast Training** list says
each line's rank, cost and the level the pet needs, with the game's own tooltip on it. The trainer's
window only prices what the creature you have out can learn, so open it once on each hunter, and
each visit fills in what the last one could not see.

Talents are named by your own client, whoever recorded the character and whatever language
they were playing in.

---

## 5. Possessions

One member's gear, bags, bank, mailbox, auctions and guild bank, drawn as the containers
themselves.
Where a thing sits in a bag is information — the potions are together, the third bag is the one
that is full — and a sorted list throws all of it away.

![Possessions: the containers themselves, one bag hovered for its tooltip](images/possessions.png)

**What they are wearing comes first**, as a block of its own — it is on the character rather
than in anything they carry. It counts as theirs everywhere else too: hover a sword one character
has in the bank and another has on their back, and Family says *2*, one bank and one equipped.

Each container is one row: the **bag itself first**, then its slots. Hovering the bag says
which bag it is, how full it is, and whether anything else will fit in it — a quiver's free
slots are not room for anything else, and it says so.

**Clicking an item opens the bag it is in**, when it is the character you are playing. A bag
of somebody else's is a picture, and clicking a picture of a bag cannot open it.

**An item used a fixed number of times shows what is left of it.** A Wizard Oil with two uses
gone reads `3` in the corner of its icon, where the game itself puts the number — Mana Oils,
Wizard Oils, a Bag of Marbles, anything with charges. It comes from your bags, your bank and
the guild bank tabs you have actually opened. Nothing else can say: no call the game offers
tells an addon how many charges are left on an item, so this is read off the item's own
tooltip, and an item the client has not finished loading is read again when it has.

**Soulbound means soulbound here too.** Your own gear and bags are described by the slot they are
in, so a shield you wore once reads *Soulbound* on this page exactly as it does in your bag, rather
than *binds when equipped*. **Hover a letter** under a character to read it in full: the whole
subject, who sent it, when it expires and the money in it.

Mail and the auction house are drawn as containers too. They are not bags and do not pretend
to be — but *where is that thing* is one question, and answering it in two shapes on one panel
would be answering it twice.

**Mail you posted to that member is already there**, before they have logged in. When you send
anything to one of your own characters, Family writes the money and the attachments down
against *them* at that moment, and the mail row says how many are still **in the post**. That
is a claim about the post and not about their mailbox: the moment that character opens their
own mailbox, what is really in it replaces the lot. Mail sent to somebody who is not one of
yours is not recorded anywhere.

---

## 6. Professions

What one member can make.

![Professions: one member's recipes, sorted by difficulty](images/professions.png)

Sort by:

| Order | The question it answers |
|---|---|
| **Difficulty** | what will skill me up |
| **Item level** | what is worth making |
| **Skill needed** | what will I be able to make next |

Recipes are coloured as the game colours them — orange, yellow, green, grey — and the counts
along the top say how many of each there are.

**Every recipe row says what it is made of**: the materials, with how many of each, on the right of
the recipe's own line — for every character, not only the one whose window is open. **Hover one of
those pictures** and you get that material's own tooltip, with who in the family already has some;
hover anywhere else on the line and you get the thing being made. Clicking a picture does what
clicking the line does. **Can make**
counts what that character had in their bags and bank the last time they logged in. Wands, rods
and oils an enchanter makes are shown as **the thing itself**, with its own picture, who holds one
and what it takes to make.

**Hold CTRL over a recipe** and its tooltip adds up what the family holds of what the recipe makes,
and what that is worth — what CTRL does over an item everywhere else (§15).

**Clicking a recipe** finds it in the open profession window. If no window is open, the recipe
is remembered and the panel says which button will open it; clicking that button opens the
window and selects the recipe on arrival.

**Professions that make nothing are not listed here.** Herbalism, skinning and fishing have no
window and no recipes, and a button leading to an empty list costs a click every time somebody
tries it to find that out again. They are on the summary, with their rank. The note under the
bar names anything left out and says which of the two reasons applies: *makes nothing*, or
*never opened* — which are different facts, and Family only knows the difference by having
seen the window.

---

## 7. Character

Five sections about one member.

**Equipped gear**, laid out the way the character sheet lays it out — a column down each side
and the weapons along the bottom. An empty slot in the right place is far more obvious than a
row saying "empty". Item level is on each piece, and the tooltip is the item as it really is,
with its enchant, its gems and its patch.

![Character, Equipped gear: the paper-doll layout with item levels](images/character-gear.png)

**Whole family**, the button at the top right of that section, is the same gear read the other
way round. Everybody becomes one row: their class picture, then every slot in the same order
the character sheet uses, with the item level written over each icon and the item's own tooltip
on hover. Hover the class picture for who they are — name, race, class, level and average item
level.

![Character, Whole family: one row per member, every slot in order](images/character-gear-family.png)

A character sheet tells you what one character is wearing. This tells you **which of them is
behind**, which is the question that made you open Family, and it is not answerable one sheet
at a time. Siblings (§11) are in it too. The two filters — **Realm** and **Class** — open a list of what
your family actually has: a family with no warlock is not offered a warlock. *All* is the first
entry of every list, so there is always one click back to everybody. Classes are named as your
client names them and coloured as the game colours them.

Where a realm has characters on both sides, they are **grouped by side** — Alliance and Horde
each get a heading and a count — the same way the summary groups them. A row here is a class
picture and nineteen slots and says nothing else about whose character it is, so without the
headings a family with one character on the other side read as a family that had lost them.
The grouping appears only where there are two sides to tell apart; one side gets no heading it
does not need.

**Currencies**: everything this member holds, with what each is capped at and how far off it
is. Anything uncapped says so rather than showing a ceiling of zero.

**Reputations**, by standing, with progress through the current one.

**Quests**: the active log, by zone, with the difficulty banding the game uses and the
progress on each. **Clicking a quest opens it in the log**, when it is the character you are
playing — and only those rows light up on hover, because only those do anything.

When Family opens one of the game's own windows for you — the quest log, and the character
sheet when you click a worn item on your own paper doll — **Family closes**. It has to: Family draws above the game's panels, and
in this game a window in a higher layer cannot be brought in front by clicking the one behind
it, so the log you just opened would sit under Family with no way to get at it. You clicked in
order to look at that window. `/family` brings Family back, on the tab you left it on.

**Achievements**, by category, with points and the progress on partial ones. Absent entirely
on a client that has no achievements — absent, rather than empty.

---

## 8. On the game's own tooltips

This is the half of Family that gets used most, and it needs no window open.

Hover **any item anywhere** — a vendor, the auction house, the floor, somebody's trade window —
and Family adds who in the family has one and where it is: bags, bank, mail, auctions, guild
bank, and what they are wearing.

**The ten holding the most are named**, and the rest are counted with how many they hold between
them, so the total at the top still adds up — an item nearly all of two hundred characters carry
would otherwise fill the screen. Guild banks are cut the same way. **Hold CTRL and ALT and click the
item** — in your bags, in chat, anywhere the game lets a modified click through — and Family opens
on the whole-family search for it, with every character who has one. The tooltip says so on any
item somebody in the family has, in grey under the list of owners, and stays quiet on an action
bar slot, where those two keys are the bar's own and the click never reaches Family.

**Which of your *other* characters' copies are soulbound** is said too, in the game's own word —
nothing else can tell you, because their copy is not on the machine the game is asking. For the
character you are playing the game already says it, and Family does not repeat it.

**Random-suffix items are counted one version at a time.** A Superior Sword *of the Bear* and one
*of the Whale* share an item number and nothing else, so hovering the Bear one says how many of
*those* the family has and what a Bear one is going for. Enchants and gems do not make versions:
two of one sword with different enchants are two of one thing.

![An item's own tooltip in the game, with Family's block added to it](images/tooltip-item.png)

Hover a **recipe** and it adds a **Family crafters** block: who already knows it, who can
learn it today, and who has the profession but is not high enough yet. Only members with that
profession are listed, because nobody else is an answer to the question.

**A recipe is recognised by what it is, not by what it is called.** The trade skill window
abbreviates some names and shortens others, and a family played across languages writes them
down in whichever one scanned them — so matching on the word left an enchanter who had known a
formula for a year being offered it as one to learn. Family matches on the recipe a book
teaches and on the thing that recipe makes, both of which are numbers and the same in every
language. The word is still read for the few recipes neither number is known for.

Both blocks name the realm on a member only when two members with the same name are listed,
and mark anybody on the opposing faction.

**What a thing is made of** — every material and how many of it, under who can make it, with what
it all costs where Family has prices — on anything a profession makes and on an enchant, is one of
the Extras, off until you switch it on (§13, *Extras*).

Turn either off in Options.

---

**Recipes that need a specialisation.** An armoursmith cannot make a sword and a goblin
engineer cannot make a gnomish one. Where a recipe belongs to a branch, a character on a
different branch is not offered as able to learn it — the line names the branch it wanted
instead, in your language. Blacksmithing, Leatherworking and Engineering on Classic Era, those
plus Tailoring on Burning Crusade, and Engineering alone on Mists, the rest having been removed
from the game. A character you have not logged into since Family learned to ask says *may know
it* rather than guessing either way; log in on them once and it fills in.

**Things made by using an item rather than a recipe.** Refined Deeprock Salt is on nobody's
recipe list — it comes out of a Salt Shaker, which has a four-day cooldown. Hovering the salt
names whoever owns a shaker **and** has the profession to use it, and says whether theirs is
ready or when it comes back. Owning one is not enough: a Salt Shaker asks 250 Leatherworking of
whoever picks it up, so a character holding one without the skill is not listed.

---

## 9. Searching the whole family

Possessions and Professions each have a **Whole family** button at the top right — the same
button, in the same place, as the one on the Character panel's gear section (§7). Switching
between two ways of looking is not a setting, so it is not dressed as one.

Pressed, the search stops being about the member on screen and becomes about everybody — and
the results say **who**. *Who has the mageweave. Who can make this belt. Who knows this
enchant.* Two letters minimum, because a one-letter search across a family of forty is not a
search.

On Possessions the answers come out grouped: the item once, then whoever has some of it
underneath, most first, with how many and where they are keeping it. Sort by character instead
and it is the same list the other way up. Each version of a random-suffix item (§8) is a line of
its own, named and drawn as itself.

On Professions, **click a recipe** and its materials appear on a line underneath, and the people
who can make it are listed several to a line rather than one per row, so a dozen crafters do not
push the recipe's own name off the top. The search waits for you to stop typing before it looks.

**Long lists fold only when the page cannot hold them.** A list of ten or fewer is always drawn
whole. Where every block on the page fits, nothing folds however long a block is; where they do
not, every block folds by the same amount — as little as brings the page back to one screen, and
never below three — behind a line you can click.

**Unless you turn it off.** Untick *Fold long lists to fit the page* under Options and every name in
every group is drawn, on Family's own pages and on the game's tooltips alike; the page scrolls
instead. A tooltip has no scrollbar, so there it still stops before it would run off your screen,
and leaves room for whatever other addons write on the same tooltip.

Only items the client has named can be matched. An item nobody has looked at since the last
patch has no name yet, and Family says so rather than letting a search quietly answer for less
than it searched.

---

## 10. Crafting cooldowns

Transmutes, mooncloth, salt shakers and the rest.

**Crafting cooldowns, and nothing else.** Not raid lockouts, not heroic resets, not daily
quest resets. Those are a different kind of thing, and Family does not record them — the name
is spelled out everywhere it appears so that nobody has to find that out by waiting for a
warning that was never coming.

Family records **the moment a cooldown comes ready**, never the time remaining. That is the
whole trick: time remaining goes stale the second the client shuts, and a moment does not. A
cooldown recorded three days ago is still right today.

**Summary / Crafting** is where you look at all of them at once: a line for each kind of
cooldown, with everybody who has it underneath — the ones who can do it now first, then whoever
comes back soonest. Green when it is available and grey with the time when it is not. Grey
rather than red — everywhere else in Family red means something is wrong or about to be lost,
and a transmute you used two hours ago is neither.

Beside the cooldown's name is **how many of your characters can do it right now**, so a list
that has folded away its fourth and fifth crafter still tells you how many are waiting for you.
A long list folds behind a line you can click by the rule in §9, the same as the reputations list;
clicking the cooldown's own name opens and closes it too.

Thirty alchemy transmutes share one timer, so they are one line called *Alchemy* rather than
thirty. **Family asks the game which cooldowns are shared** rather than working it out by
watching — the client's own tables distinguish a recipe's own timer from one a whole category
shares, which is what players mean by *all the transmutes share one cooldown*. It differs by
expansion: alchemy on Classic Era, alchemy and enchanting on the Burning Crusade, enchanting on
Mists, where Void Sphere and Prismatic Sphere are two names for one timer. A cooldown nothing
shares keeps its own recipe's name.

A **salt shaker** is in there too, under leatherworking. The cooldown is on the item, and
nothing in the game says which profession it answers to — but Family records what each recipe
makes, so an item on cooldown that one of your own recipes produces belongs to that recipe's
profession.

**A transmute shows up before you have ever been caught doing one.** Family used to learn that
a recipe had a cooldown only by watching one run, so an alchemist nobody had seen mid-transmute
was simply blank. It now knows from the game's own tables which recipes carry one — and knows it
per expansion, because the same recipe differs: mithril to truesilver is two days on Classic
Era, twenty hours on Burning Crusade and gone on Mists, and Family says whichever of those is
true where you are playing. Watching still fills in anything those tables have never heard of,
and a member Family has nothing on is blank rather than shown as available, because blank is
what is true.

**Only members who have a crafting cooldown are listed.** Thirty members with three alchemists
is three rows rather than twenty-seven blank ones. The totals under the window still count
everybody, because that line says what the family has and does not change because a panel is
showing fewer rows.

**Columns are named in your language**, whichever client recorded the cooldown. A mooncloth
scanned on a French character is not headed *Étoffe lunaire* on an English one.

What is ready is counted on the broker tooltip (§2) and is announced when you log in. Turn the
announcement off in Options. `/family ready` lists them by name, which is how you check what
a message is actually about.

**Only professions the character still has.** Drop alchemy and Family keeps its recipe list —
take it up again and nothing was lost — but its cooldowns stop counting, because a reminder
about something you can no longer do never stops arriving on its own.

**And only cooldowns of six hours or more.** A hearthstone is on a cooldown; nobody needs
telling about it. What this is for is the once-a-day things a character forgets precisely
because they are on the character you are not playing.

**A crafting cooldown and an item's are not the same kind of fact**, and Family treats them
differently. Using a craft needs the profession window open and Family reads that window, so a
transmute still reading *ready* really has not been used. Using an item needs nothing open at
all — so once an item's cooldown elapses Family knows only that it was running the last time
anybody looked, which is not the same as *waiting for you*. Those stop being reported when
they come ready. The panel shows them either way — ready or counting down — because a panel is
a table you opened and are reading against the ages beside it, and a salt shaker you cannot see
is exactly what you opened it to find.

A cooldown appears only if it was seen. One that started while the profession window was shut
is not known until the window is next opened, and *no cooldown seen* is what Family says
rather than *no cooldown*.

---

## 11. Wide Family

> **Switched off until you ask for it.** The panel is there either way, so you can read what
> it does before deciding; the switch is in **Options**, beside the one for Guild share, or
> `/family wide on`. Neither needs a reload. Both of you need to do it. Nothing is shared with anybody until you link and tick what they may see.
> `/family wide off` puts it back; anything already borrowed simply stops being shown.
>
> The rest of this section describes it as it works once switched on.

A family need not be one account. You can add another player's characters as members of yours,
and they can add yours.

**Your realm, or one connected to it.** They do not have to share a guild with you or be in a
group with you — only be online, running Family, and on a realm your character can whisper at the
moment you ask. A whisper reaches your own realm and the realms connected to it, and a link travels
by whisper, so that is as far as it goes: on Classic Era, Pyrewood Village reaches Nethergarde Keep
and Mirage Raceway and does not reach Soulseeker. When every character of a linked family is out
of reach, the panel says that none of them is on a realm this character can reach, rather than
calling them offline.

> *A picture of this is still to be taken: `docs/images/wide-family.png`.*

One principle governs the whole feature: **nothing is ever visible that was not deliberately
made visible, one member and one category at a time.**

### Linking

Type the other player's character name on the **Wide Family** panel and press *Ask to link*.
They see a request and accept it. **Until they accept, nothing whatever has been exchanged** —
not a member list, not a name, not what anybody has.

A link is between two *families*, not two characters, so it survives either of you switching
character.

### If nobody answers

A request you have sent and not had answered stays on the panel under **Waiting for them to
answer**, with how long ago you asked. After a couple of minutes it is marked *no answer*, and
you can *Ask again* or *Forget*.

Family says *no answer* rather than *failed*, because it genuinely cannot tell which happened.
The game's addon channel acknowledges nothing: a message that was delivered and a message the
server dropped look exactly alike from inside the client. So the panel names all three
possibilities instead of picking one:

- they are offline, or not running Family
- their Family is too old to know how to answer
- the two of you cannot exchange addon messages at all

The third is the one worth knowing about. Addon messages travel by whisper, and **a whisper
that reaches somebody is not always a whisper that carries an addon message with it.** Two
characters on the same realm are fine. Beyond that it depends on the client and on how the
realms are connected, and no addon can work around it — including this one. If *Ask again*
never produces an answer and you know they are online with Family running, that is the likely
reason.

### Saying what may be seen

Click a link to open its grid: your members down one side, categories across the top.

| Category | What it carries |
|---|---|
| Possessions | bags and bank, and the slot counts |
| Equipment | what they are wearing, and their item level |
| Professions | recipes, ranks, specialisations and cooldowns |
| Talents | talent trees and the spellbook |
| Quests | the active log |
| Mail | what is waiting, and when it expires |
| Auctions | what is listed |
| Reputations | standings |
| Money | money |
| Character | time played, rested experience, guild, hearthstone, where they are, mount |
| Currencies | currencies |
| World buffs | the buffs they carry and what is banked in a Chronoboon |

**The grid starts with nothing ticked.** There is no *share everything* — a default is not a
decision. Offering a member at all shares who they are: name, realm, class, race, level and
side. Nothing else moves without a tick.

**Unticking tells the other side to forget it, at once** — not at the next exchange.

### When data moves

- **When a linked family comes online.** Each side announces itself on login and whoever
  hears it exchanges. Neither of you has to remember anything.
- **When you change what is shared**, immediately.
- **When you press Update now.** It asks for theirs and sends what changed since they last said
  what they hold — and when nothing has, it says *nothing to send* and how many are unchanged,
  in chat and on the line under the family.

**Nothing is sent as you log out.** By the time an addon knows it is logging out the client is
already leaving, and a message posted then does not arrive. The login exchange covers the same
ground honestly: the next time either of you plays, both sides are brought up to date.

The first two are one tick box on the panel — **Exchange automatically** — and you can turn it
off. Off means nothing happens without somebody asking for it: no announcement on login and no
answer to anybody else's. *Update now* stays, and always will, and works the same with the box
unticked.

**Sending everybody again**, whatever they already hold, is a command rather than the button:
`/family wide resend <family>`, with the family's name as the panel shows it. It says first how
many characters it will send, about how much and for how long — about six minutes for two hundred
characters — and the panel names it on the line under a family you have opened. It is for the rare
case where something on their side looks wrong although nothing changed on yours; *Update now*
already repairs everything else, because each side tells the other what it holds.

**A share that stops part way picks up where it stopped.** Logging out, closing the game or the
other person going offline no longer leaves characters Family believes it has sent: each side
tells the other what it already holds, and the other side **confirms** what it stored, so the line
under a family counts *confirmed* rather than *sent*. Anything never confirmed is sent again next
time. While a share is going out, the same line says how many pieces are left, and the count moves
as you watch.

One thing crosses that switch on purpose. **Unticking a box is still sent at once**, whether
automatic exchange is on or off. Automatic update is a convenience and it is yours to switch
off; telling somebody to forget what they may no longer see is a promise, and a promise that
waits for you to press a button is not one.

During a fight, a large transfer waits for the fight to end. Sending is not forbidden in
combat — but the channel is shared with every other addon in the raid, and they need it more
than Family does.

### What linked data is, and is not

- **Kept separately** from your own members and always marked as another family's. Never
  merged, never edited.
- **A snapshot**, refreshed when exchanged. It does not subscribe — nothing either of you does
  while playing is sent as it happens. Selling something, swapping a piece of gear, looting a
  bag: none of it reaches the other family until the next exchange.
- **As old as the last exchange**, and the panel says how old that is.
- **Both of you must be online at once**, because the transport is the game's own addon
  channel.

### Siblings

Under **Shared with you** at the bottom of the panel is everyone the other families have
given you, each with a tick box. Tick one and they become a **sibling**: they appear in your
summary, on the realm they are on, in a small section under the name of the family they belong
to, in every column set.

Ticking sends nothing and asks nobody, and that is not a shortcut. You can only tick somebody
that family has *already* decided to share with you — the consent was given before the name
could appear in the list. What is left is a decision about your own screen.

If they later untick that member, or either of you ends the link, the sibling goes with them.
There is nothing to tidy up.

A sibling's possessions also count on item tooltips: hover anything and their name appears
among the owners, with the family they belong to beside it.

**You do not have to make somebody a sibling to look at them.** Everyone a linked family
shares with you is offered by the member button on Abilities & Talents, Possessions,
Professions and Character, listed at the bottom under that family's name rather than filed
under a realm. A sibling is the stronger statement: *this one belongs in my lists, beside my
own*. Where a whole family's worth of shared characters would only get in the way of reading
your own summary, leave them unticked and go and look at them when you want them.

An exchange happens when either of you logs in, if *Exchange automatically* is ticked, and
whenever anybody presses **Update now**, and when a grant is ticked or unticked. That is the
whole list. Both of you must be **online at once** for one — either of you, on any character. A
linked family is a person, not one of their alts, so **Update now** tries whoever you heard
from last, then the next of theirs, until one answers. Only when every one of them has been
found offline does Family say the family is not online, and sends nothing — it finds out the only way anyone can, by the client complaining about the
first whisper, and it stops there rather than complaining several hundred times.

### What they share with you

Click a linked family's line and it opens on both halves of the link. Underneath *What they
may see of your characters* is the grid you tick. Underneath *What ... shares with you* is
everyone they have given you, and against each one the same columns — greyed, because that is their decision being reported
rather than yours to take. Read the two together and you have both halves of the link: what
they see of yours, and what you see of theirs.

The marks are what they *said* they granted, not what happened to arrive. A character with an
empty mailbox and a character whose mail was never shared send the same nothing, and Family
will not report the first as the second. A linked family running an older version says nothing
about its grants, and there Family shows what arrived and nothing more.

### Ticking a lot of boxes

A family of eleven is eighty-eight boxes, and the decision is usually one decision taken
eleven times. Click a linked family's name to open its grid — the line is a button, not a heading.

**Click a column's name** — *Equipment*, *Professions* — to grant it for every
member at once; click it again to clear the column. The other family is told once, not once
per member.

### The one thing it cannot promise

Family will not send what was not granted, and on unticking a box it asks the other side to
forget what it has. **That last part is a request.** The other side is somebody else's
computer running somebody else's copy, and no addon can compel it. The consent grid is a
promise between two people that Family keeps honestly on your side; it is not a lock, and the
panel says so rather than showing a padlock that means less than it looks like.

### If the panel says it cannot run

Wide Family needs `LibSerialize` and `LibDeflate` — the addon channel carries text and nothing
else. A copy installed from CurseForge has them. A copy built from a `git clone` does not, and
the panel says so outright rather than offering a link that never works.

---

## 12. Guild share

A much lighter Wide Family, and the lightness is the point: it carries very little, so it can
carry it without asking anybody anything.

> **Switched off until you ask for it.** The panel is there either way, so you can read what
> it does before deciding; the switch is in **Options**, beside the one for Wide Family, or
> `/family guild on`. Neither needs a reload.
>
> Off works in both directions at once — a Family with this switched off neither asks nor
> answers.

**What it carries, and nothing else:** for every guildmate running Family, and for every one
of *their* characters who is also in this guild — class, level, **both talent
specialisations**, and **equipped gear with its average item level**.

**Never:** bags, bank, mail, quests, professions, money, auctions, reputations. Not *not yet*.
Wanting a guildmate's bag contents is a perfectly reasonable thing to want — it is a Wide
Family link, and it is one on purpose.

**Why there is no consent grid for this.** Everything in that list is what the game already
shows any guildmate who targets you and presses Inspect. Family is not disclosing it; it is
saving you both the trip, across characters who are not standing in front of you and at hours
when neither of you is online. A dialogue asking permission for a fact the game gives away for
free protects nobody, and teaches people to click through the dialogues that do matter.

### The panel

> *A picture of this is still to be taken: `docs/images/guild-share.png`.*

The guild's own roster, with **Online only** or **Everyone**. Each row carries a dot: filled
for somebody running Family, grey for somebody who is not. Most of a guild will be grey, and
nothing on your side changes that.

Click one of the filled ones to see their characters — each with their gear laid out slot by
slot, item levels over the icons, tooltips throughout, and both specialisations beside them.
The one in gold is the one they are actually in.

Talents arrive as the **shape** of the build — which trees and how many points in each — not
talent by talent. That is about the channel rather than about privacy: whole trees for
everybody's alts, every time somebody logs in, is Family taking a channel it shares with every
other addon in the guild for a picture almost nobody is looking at. Somebody's build in full
is a Wide Family link, where it goes to the one person who asked for it.

**Once you have seen somebody, they are kept.** A guildmate who logged off an hour ago is
still there, with the age of the record on the row. Nothing is fetched from somebody who is
offline, because there is nobody there to fetch it from.

**Alts outside the guild are not offered**, and there is no setting to add them. A scope with
a switch to widen it is not a scope; somebody's characters elsewhere are a Wide Family link.

**Connected realms count as one.** Most guilds now span a group of connected realms, and your
characters on any of them are offered to the guild — not only the ones on the realm you happen
to be standing on. The realm test is still a real test: it is the game's own list of connected
realms, not a name match, so a guild that shares a name with one on an unconnected realm is
still a different guild. Anything you had already ticked for those characters was kept and
takes effect now.

**Records from somebody nobody has heard from in a fortnight are dropped.** If a guildmate
turns a profession off and then stops playing, the message saying so has nobody to reach, so
what they last shared would otherwise stay answerable on your client for ever. It expires
after two weeks and rebuilds itself the moment they come back. Your own sharing grid is never
touched by this — what you have chosen to share is yours and does not expire.

The two features know nothing about each other. Linking families with a guildmate does not
change what the guild panel shows, and what the guild panel shows is never affected by a link.
Two routes to the same fact would mean two places to look for it and two places to withdraw
it.

Guild share needs `LibSerialize` and `LibDeflate` for the same reason Wide Family does, and
says so plainly when they are missing.

`/family guild on` and `/family guild off` do the same as the switch in Options, and
`/family guild` on its own says which it currently is — along with what is actually happening
on the channel: how many addon messages your client is handing over at all, what it did with
each thing Family gave it to send, and how many of your guildmates have answered.

`/family guild test` sends one announcement and reports what became of it. The case it exists
for is a real one and looks exactly like a bug: **a character on a realm other than the
guild's own can hear the guild and cannot speak to it.** Guild chat works both ways, addon
messages arrive normally, and nothing you send ever leaves — the game's doing and not Family's.
The report says so in as many words, and says that what you share still reaches anybody who
says hello first. If you have alts on a connected realm and one of them seems invisible to the
guild while the others are fine, this is why.

---

## 13. Options

| Setting | What it does |
|---|---|
| Show the minimap button | and it remembers where you dragged it |
| Always open Family on one panel | a star beside each panel locks Family to it; on the summary it takes the set of columns too |
| Add Family to item tooltips | §8 above |
| Show prices on item tooltips | what a vendor pays and charges, and the auction house's last price (§15) |
| Say whose mail is running out when you log in | with how many days' warning you want |
| Say which crafting cooldowns are ready when you log in | cooldown announcements (§10) |
| Share gear and talents with your guild | §12 above, both ways at once |
| Share with families you link to | Wide Family, §11 above |
| Say in chat how a Wide Family update went | whether a linked family had anybody online to talk to |
| Fold long lists to fit the page | on; untick it to see every name in every group, on Family's pages and on the game's tooltips |
| Draw the carried bags as one block, and the bank as another | Possessions then shows one run of slots for the bags and one for the bank |
| Narrate what the scanners are doing | chat messages while recording; for working out faults |
| How far in front the window sits | raise it if another addon draws over Family |

The line at the bottom says which version is running, which client it thinks this is, which
tooltip route it hooked and how storage is kept — *plain*, or *plain, no sharing* on a copy without
the libraries Wide Family and Guild share need. It is the first thing worth reading when something
is wrong, and the first thing to quote in a fault report.

### Extras

The panel above Options holds **jobs Family will do for you that are not what Family is for**. Each
is switched on or off by itself.

| Extra | Starts | What it does |
|---|---|---|
| Read prices at the auction house | on | whatever the auction window shows is read for prices, including another addon's whole-house scan |
| Let Family read the whole auction house itself | on | a **Family** tab on the auction window, with a button that reads every page |
| Say what a craftable item is made with | off | every material and how many, on the tooltip of anything a profession makes and of an enchant, totalled where Family has prices |
| Say what came out of the mailbox | off | a line in chat for each sum and item taken out of a letter, and what the visit came to |

**Reading prices off** means Family values what your characters hold at what a vendor pays, reads
nothing at an auction house, and puts no tab on that window. Prices already recorded are kept, so
switching it back on finds them.

**Made with.** A material that is itself made follows its own recipe — a Lionheart Champion needs a
Lionheart Blade, so its cost is what the Blade's materials come to, as deep as the chain goes — and
where somebody is selling a part, what they ask wins over what making it would cost. A material
with no price makes the total say *some prices are missing* rather than quietly leaving it out, and
one no money can buy adds nothing, with the total saying so.

**What came out of the mailbox** works with the game's own Open All and with mail addons, and the
total arrives as soon as there is nothing left to take, or when you close the mailbox if that comes
first.

### The auction house

**Prices come from what you look at.** Family reads the list the auction window is showing — your
own searches, and the whole-house scan of an addon like Auctionator, which fills the same prices in
one go and for nothing. It never sends a request of its own unless you ask it to read the whole
house. Prices are kept per realm and per side; a price read at a **goblin** auction house counts
for both sides of that realm, because it is one market, and your own side's house still wins where
it has a price.

**Connected realms share one auction house**, on Classic Era and on Mists alike, goblin houses
included — so a price read on any realm of a connected group counts for your characters on all of
them, the most recent reading winning, and an item banned on one is banned for the group. Family
learns which realms are connected from the game each time you log in, so log in once on any realm
of a group and it knows the whole group from then on.

**The Family tab** on the auction window carries the *Read it all* button and a line saying how far
a read has got: pages done, prices taken, and roughly how long is left, worked out from the pages
already read. The button clears the search, searches, and walks every page there is; pressed again
it stops, and whatever was read is kept. It says when somebody else's scan is filling your prices.
Where the tab cannot be built, the button sits beside *Reset* on the Browse panel instead.

**It takes minutes, and that is the server.** A whole Classic Era house is about 584 pages in five
minutes, most of it the game refusing to let the next question out until the last has been
answered. If you already run an auction addon, its own full scan is faster and Family hears it. On
**Mists of Pandaria** the whole house answers one request, so the same button reads it in one go.

A read that stops getting answers ends itself and says why. If it will not start, search the
auction house once and turn one page: the read replays that search rather than inventing one. It
also refuses to reuse a request another addon made for the entire house at once.

`/family ah scan go` and `/family ah scan stop` do the same as the button, typed.

**Random-suffix items are priced one version at a time** (§8).

---

## 14. What Family will not do, and why

Family **reports**. It does not advise. Specifically, it will not tell you:

- which recipes a member is still missing
- which piece of gear to improve next
- where in the game an item is looted, sold or rewarded

None of that is in the game client. **The client knows what a thing *is*; it does not know
where a thing *comes from*, because that lives on the server.** An addon that answers those
questions is reading a catalogue somebody compiled outside the game — which brings a licence
to honour, a dataset to keep current across three clients and eleven languages, and answers
whose staleness there would be no honest way to state.

So it is not a feature that is coming later. It is the shape of the addon: everything Family
says, it says because the client said it, or because another Family said it.

---

## 15. When something looks wrong

**"It says not seen."** That is not a fault. Open the window in question once — bank, mailbox,
profession — and it will be recorded from then on.

**"A number is out of date."** Every screen says when it was last seen. Bags and money are
live for the character you are playing; everything else is as old as the last time that
character was played, or that window opened.

**"A sibling's *Last seen* says *shared*."** It is answering a different question, because it
has to. When somebody else's character last played is not among the facts a linked family
sends (§11); when their Family last told you about them is. So a borrowed row reads *shared 2
h ago* — the age of what you hold, not a sighting — and your own rows stay bare. A date with
no word beside it is your own family's; one that says *shared* came from theirs.

**"A profession has no recipes."** Its window has not been opened since Family was installed,
or it is a gathering profession that has none. The Professions panel says which.

**"A profession or its recipes are in the wrong language."** Professions and races are shown in
your language whoever recorded them, and a recipe is named from what it makes, which your own
client translates. A recipe list read before you changed language may take a moment to catch up
the first time the panel is opened, while the client loads the items it has not seen this
session.

**"Do my pet's training points add up?"** Type `/family pettp`. For every creature Family has a
record of, it lists the abilities the creature knows, what the trainer's window says each of them
costs, and what the client says the creature has spent altogether — and then it says how many
abilities it could price and what those come to.

It reads what is already on disk: nothing is scanned and nothing is sent. What it can price
depends on what the trainer's window has shown you, so a creature whose abilities all have a
price beside them is one whose Beast Training window you have opened with that creature out. A
dash means Family has no price for that ability, which is not the same as it being free.

**"What is all my stuff worth?"** It is on the character's own **Possessions** page, under the
line that says how recently each part of the list was seen — what they are wearing, bags, bank,
mail and auctions, which is also exactly what the figure covers — and in the **Worth** column of the
summary's Overview (§3). Not the guild bank, which is the guild's, and not the keyring, which is
worth nothing anyway.

Each thing is valued at what the auction house was last seen asking for it, and where Family has
never seen one, at what a vendor pays — which the game knows for nearly everything, and is what
makes the figure cover a whole bank alt rather than the few dozen things you happened to search
for. **Something soulbound is always valued at what a vendor pays**: what is on sale at the auction
house is the unbound version, and a sword you have worn cannot be listed at any price.

The line never gives a total on its own. It says how much came from auction prices and how much
from vendor prices, because those are two very different numbers, and how many things it had no
price for at all — which is only what your client has never seen named.

**"Can Family show vendor prices?"** Yes, and it is off until you turn it on — *Show prices on item
tooltips*, in Options. These lines appear on an item's tooltip:

**Sell price** is what a vendor pays you. The game knows it for every item and Family simply says
it, everywhere, straight away. Prices are written in full — gold, silver and copper — so the lines
under one another end at the same edge.

**Vendor price** is what a vendor charges, and it appears only for items Family has actually seen
on a merchant's list. Open a merchant and Family reads the shelf and remembers it, so the price is
there afterwards wherever you meet the item — in your bags, in the auction house, on the floor. An
item you have never seen for sale gets no such line, because Family would be guessing that anybody
sells it at all.

**Auction** is what the auction house was last asking, with how long ago that was in front of it —
*(3d ago) 4g 20s 00c*. Family reads it from the list you are already looking at while you search; it
never asks the auction house for anything on its own. Prices are kept per realm and per side,
because they are not the same market. Among everything on show in one visit the cheapest wins,
since that is what you would actually pay; your next visit replaces it whatever it says, because
a price a fortnight old is a photograph and the newest one is the truth.

**Hold CTRL over a stack in your bags** and a third line says what the whole stack sells for —
*Stack of 20*, and the total. You can press the key with the pointer already on the stack; the
tooltip fills the line in. The line offering the key appears only over a stack, so an item sitting
on its own never mentions it. Family works out how many are there from the slot the pointer
is on, and says nothing at all unless that slot really holds the item being described, so an
unusual bag addon costs you the line rather than a wrong number.

**Over an action bar slot, press CTRL first.** Pressing it while the tooltip is already up does
nothing there: action bar addons — Dominos, Bartender, and the game's own bars — use shift, control
and alt to give a slot a second and third binding, so the key belongs to the bar. Hold it before the
pointer arrives and the tooltip is built with it down. Family does not offer you the key there,
since pressing it would do nothing; everywhere else — bags, the auction house, a vendor, a link in
chat — the offer appears as it always did.

**Hold CTRL anywhere else** — at the auction house, at a vendor, over a link somebody posted in
chat — and Family answers a question nothing else can: *what is everything my characters are
holding of this worth?* One line with the money, and under it how much of it was reached at
auction prices and how much at what a vendor pays, because those are two very different numbers.
Each character is valued at their own realm's market, not at yours, and the age of the oldest
reading that went into the figure sits beside it. The guild bank is counted on its own line above
and is left out of this one: it is the guild's, not yours to spend.

**The stack line works away from your bags too**: over an auction row, whichever row you are
pointing at and however far the list has scrolled, on a vendor's shelf and over a loot window. When
both answers apply, the hint says both. An item the game will not pay a copper for offers neither.

If two characters see different prices for one thing, the higher is kept: a reputation discount
only ever makes a vendor cheaper, so the highest price anyone was quoted is the closest thing to
the real one.

**"What does my client offer at the auction house?"** Type `/family ah`. It lists the auction
calls this version of the game has and whether one would be accepted right now, says how many rows
are on show, and how many prices Family is holding for the realm and side you are on, with the age
of the oldest and newest. It asks the game rather than Family's records, and it sends no query.

**"A character's abilities look wrong."** Type `/family spellbook`. It walks the client's own
spellbook in front of you and says, tab by tab, which tabs Family reads and which it leaves alone,
every row it would record with that row's id, what is behind a button that opens into several
spells, and how many rows it passed over and what the game called them.

It asks the game, not Family's records — which is the point, because the records are the thing in
doubt. Nothing is scanned and nothing is sent. On Mists of Pandaria the spellbook has a tab for
each specialisation, listing everything that specialisation can ever do; those are not this
character's abilities and Family says so rather than recording them.

**"The game stops for a moment when Wide Family is on."** Type `/family widetime`. It says, per
link, how many members are shared, how long deciding which of them changed takes, and how many are
unchanged — an unchanged character is never opened and never sent. Where some are not, it says why
and names them: **changed since they were sent**, which is what playing a character does, or
**never confirmed as sent**, which is the one to look into. Underneath, in grey, is what the same
exchange used to cost, there to be compared against. It measures and sends nothing, and nobody has
to be online.

**"How much would an exchange send?"** `/family widecost` weighs what asking a linked family for
theirs puts on the wire, without sending it. Sending everybody again is `/family wide resend
<family>` (§11), which says what it will cost before it starts.

**"Family is slow to load, or I have a great many characters."** `/family status` says how long your
saved Family data took to read at the loading screen and how many characters are still saved the
old way — none, once the first login after updating to 3.0.0 has converted them. `/family
decodecost` says what every character's record weighs and which recipe lists were recorded in
another language, naming each character's lists that are. `/family paycost` says how many times
this session wrote a character's record, which parts, and what marking each part takes. All three
are measurements: they change nothing and send nothing.

**Something errored.** Turn on *Narrate what the scanners are doing* in Options, reproduce it,
and report the message together with the line at the bottom of the Options panel. It says
which version, which client and which routes Family found, which is most of a diagnosis.

Faults and suggestions: <https://github.com/uga/Family>
