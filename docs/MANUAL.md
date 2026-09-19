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
14. [What Family will not do](#14-what-family-will-not-do)
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

### 2.1 The broker bar

The bar starts on **the character you are playing**. It shows a bag icon with their free and
total bag slots, then their money. The bag figure counts bag slots only.

**Shift-click** moves on to **the whole family**, then to **your faction on this realm**, then
back to the character. Those two show a group icon and the number of characters counted. A
middle click does the same as shift-click. Your choice is remembered, and the tooltip always
says which of the three the bar is showing.

The "your faction on this realm" setting counts one faction only. Two factions on one realm
share no mailbox and no auction house, so adding up the money of both sides would be
misleading.

Left-click always opens Family, on the Summary panel unless you have set another one in
Options (§13). Right-click always opens the Options panel. Click again while that page is
showing and the window closes.

### 2.2 The recap tooltip

**Hover the minimap button or the broker** to see the whole family at a glance: every realm,
every member with their level, item level and money, and a total for all realms. Below that:

- **Crafting cooldowns ready**, as a number of members. The **Crafting** section of the
  Summary panel names them (§10).
- **Mail expiring soon**, as a number of members with mail less than three days from being
  returned or destroyed. This always counts the whole family, whatever the bar is set to.

The tooltip always lists everybody. When the bar counts less than that, a line near the bottom
says what the bar is counting.

**Even a very large family fits the screen.** The realm totals, the grand total and the two
warnings are always shown. The list of characters takes the room that is left and ends with
*and N more* where it has to stop. The realm you are on gets room first, and within each
realm the richest characters are kept.

![The minimap button hovered: every realm, every member, and the totals](images/broker-tooltip.png)

---

## 3. Summary

This is where your members are listed, grouped by realm. Where there is something to add up,
each realm has a totals line, and a grand total follows when you have more than one realm.
Click a column heading to sort by it.

![The summary on Overview, a family across two realms with a totals line](images/summary-overview.png)

The buttons across the top choose which sections are shown:

| Section | Columns |
|---|---|
| **Overview** | level, item level, rested experience, money, worth, time played, last seen |
| **Bags** | free and total slots in the bags and in the bank, and when each was last seen |
| **Activity** | mail, mail on its way from a family member, when it expires, auctions, bid value, buyout value, and when the mailbox and the auction house were last seen |
| **Professions** | every profession known by each member and its rank, primaries first |
| **Currencies** | honor, arena points, and anything else your game counts as a currency |
| **Crafting** | every crafting cooldown in the family: ready, or when it comes back |
| **Miscellaneous** | race, guild, where they logged out, hearthstone location, riding skill, and world buffs stored in a Chronoboon |

**A realm where you play both factions is split in two**, with a subtotal under each. The two
sides share no mail and no auction house, so each subtotal counts only gold those characters
can send one another. A realm where you play one faction is not split.

**The two banners** at the right of the section buttons filter by faction. Both are on to
begin with, and you can switch either off.

What you can click:

- **A member on Professions** opens their Professions panel.
- **A member on Bags** opens their Possessions panel.
- **The Mail figure** on Activity unfolds that member's mail: one line per letter, with its
  sender, what is attached and when it expires.
- **The Chrono figure** on Miscellaneous unfolds what their Chronoboon holds: each world buff
  as its own icon, with the time left on it and the game's own description on hover. The
  figure itself is how many buffs the Chronoboon holds.
- **Right-click a member** to remove them from Family. You are asked first, by name and
  realm. This removes Family's record only, never anything in the game.

**A blank and a dash mean different things.** In the **Chrono** column a number is how many
buffs are stored, a blank means none, and a dash means Family does not know yet. In the
**Guild** column a blank means the character is in no guild, and a dash means Family does not
know yet. A dash fills in the next time you play that character.

**Worth** is what everything that character holds comes to, in gold. Tradable items are valued
at the most recent auction house buyout Family has seen, and everything else at what a vendor
pays. The same figure appears as a line on their Possessions page. Hover the row for the exact
amount, and for how much of it comes from auction prices and how much from vendor prices.
Worth adds up per realm and per faction, the same way money does. A character with nothing
priced yet is blank, not zero.

**Siblings** (§11) appear here too. They sit under the realm they are on, after your own
members, and under the name or alias of the family they belong to. They are never added to the
totals. Right-click does not remove a sibling. Untick them on the Wide Family panel to do
that.

**Class** is the colour of each member's name, and is spelled out in the row's tooltip.

Two things to know. Free and total slots count general storage, so they leave out quivers,
soul bags and other special bags, because nothing else fits in them. The Currencies set shows
the currencies your family holds most of, and says how many it left out.

---

## 4. Abilities & Talents

The talent trees, drawn like the game draws them. Each icon sits at its own tier and column,
and talents nobody has taken are drawn grey. On Mists the page shows the choice made at each
tier.

![Abilities and Talents: a tree drawn as the game draws it, untaken talents greyed](images/talents.png)

- Both **specialisations**, with the active one marked. A specialisation that was never
  activated says *Never activated - nothing recorded*.
- **Points spent** in each tree, and how many are left to spend.
- **Glyphs**, on Mists.
- The **spellbook**, by school, with a filter box. A hunter's Beast Training is listed with
  it.
- **Pets**: a hunter's stable and a warlock's demons, with what each creature can do.

Hover anything for the game's own description of it. Talents and abilities are named by your
own game, in your current language, whatever language the game was set to when the character
was recorded.

**Pets and demons fill in one summon at a time.** The game says what a creature knows only
while that creature is out. A hunter pet that is in the stable but has never been out is
listed under *In the stable, never summoned - nothing recorded*.

**Hunter training points.** Each hunter pet ability shows what it cost. Each creature shows
how many of its spent points Family can account for, such as *273 of 273 accounted for*.
Points left to spend are in green on the creature's row. A freshly tamed pet owes points until
it becomes loyal, and that figure is in red. The **Beast Training** list gives each line's
rank, its cost and the level the pet needs. The hunter's window prices only what the pets you
have read into Family can learn, so open it once with each pet out. Each visit adds what the
last one could not see. An ability the hunter learnt for a kind of pet they no longer own
stays on the Beast Training list, but shows no training point cost until that hunter tames,
and Family reads, a pet able to learn it.

---

## 5. Possessions

One member's gear, bags, bank, mailbox, auctions and guild bank, drawn as containers. Items
sit in the slots they occupy in the game.

![Possessions: the containers themselves, one bag hovered for its tooltip](images/possessions.png)

**The line under the member's name** says how old each part is: *bags 2 hours ago*, *bank not
seen*. It also says what everything on the page is worth (§15).

**Worn gear comes first**, as a block of its own, titled *Equipped*. It counts as owned on
tooltips too. If one character has a sword in the bank and is wearing another identical one,
the tooltip says *2*: one in the bank and one equipped.

**Each container is one row**: the backpack itself, then bags equipped in their slots. Hover
the bag to see which bag it is, how many slots are free, and what it is restricted to if it is
a quiver, a soul bag or another special bag. An option draws all the bags as one solid block,
and the bank as another (§13). The keyring stays separate.

**The filter box at the top dims everything that does not match** what you type, so the
matches stand out where they are.

**Clicking an item opens the bag it is in**, when it belongs to the character you are playing.
Another character's bags cannot be opened from here.

**Items with charges show how many are left.** A Wizard Oil with two uses gone shows `3` in
the corner of its icon. The same goes for Mana Oils, a Bag of Marbles and anything else with
charges, in your bags, your bank and the guild bank tabs you have opened.

**Tooltips match what you see in your own bags.** A bind-on-equip shield you have worn reads
*Soulbound* here, as it does in your bag.

**Mail and auctions are drawn as containers too.** Hover a letter to read its subject, who
sent it, when it expires and the money in it.

**Mail you sent to a member is already there**, before they log in. When you send money or
items to one of your own characters, Family records them against that character at once, and
the mail row says how many letters are *in the post*. When that character opens their mailbox,
what is really there replaces the lot. Mail sent to anybody else is not recorded.

See §9 for the **Whole family** button.

---

## 6. Professions

What one member can make.

![Professions: one member's recipes, sorted by difficulty](images/professions.png)

Sort by:

| Order | What comes first |
|---|---|
| **Difficulty** | the hardest recipes, which are the ones that skill you up. Within a colour, the ones that took the most skill to learn |
| **Item level** | the hardest recipes, and within a colour the ones that make the highest-level items |
| **Skill needed** | the lowest skill, so you see what you can make next. The skill is not known for every recipe yet |

Each recipe is called by the name of the item or spell it produces. The name is coloured as
the game colours its difficulty at that member's current skill: orange, yellow, green, grey.

The counts along the top say how many recipes of each colour the member knows.

The search box finds a recipe by the name of the item or spell it produces.

Hover a recipe's icon or its line for the game's tooltip of the item or spell. Family adds who
in the family already owns the item, who can craft it, and which materials the recipe needs,
with their cost where known.

**Every recipe row shows its materials** as icons on the right, with the quantity on each.
This works for every character, not only the one you are playing. Hover an icon for that
material's own tooltip, with who in the family already has or can make some, and its cost
where known.

**Can make** appears beside the materials of some recipes, and says how many times that
character could make the recipe. It counts the materials Family last saw in that member's bags
and bank. Mail, auctions and worn gear are not counted.

Wands, rods and oils made by an enchanter are shown as the item itself, with its own icon, who
holds one and what it takes to make.

**Hold CTRL over a recipe** whose item somebody in the family owns, and the tooltip adds what
the family holds of the item it makes, and what that is worth (§15).

**Click a recipe** to select it in the current member's profession window, if that window is
open. If it is not, Family remembers the recipe and the panel highlights that profession's
button at the top. Click that button and the profession window opens with the recipe selected.
This works only for the character you are playing.

**Professions that make nothing are not listed here.** Herbalism, skinning and fishing have no
recipes. They are on the summary, with their rank. A note under the buttons names any
profession left out and says why: it makes nothing, or its window was *never opened* on that
character.

See §9 for the **Whole family** button.

---

## 7. Character

Five sections about one member.

**Equipped gear** is laid out like the character sheet: a column down each side and the
weapons along the bottom. Each piece shows its item level. The tooltip is the item as it
really is, with its enchant and its gems.

![Character, Equipped gear: the paper-doll layout with item levels](images/character-gear.png)

**Whole family**, the button at the top right of that section, shows everybody's gear at
once. Each member is one row: their class icon, then every slot in the order of the character
sheet, with the item level over each icon and the item's own tooltip on hover. Hover the class
icon for their name, race, class, level and average item level. One look tells you which of
your characters is behind. Siblings (§11) are listed too.

![Character, Whole family: one row per member, every slot in order](images/character-gear-family.png)

Two filters, **Realm** and **Class**, list only what your family has. A family with no warlock
is not offered a warlock. *All* is the first entry of each list. Where a realm has characters
of both factions, the rows are grouped under an Alliance and a Horde heading, as on the
summary.

**Currencies**: everything this member holds, with each cap and how far they are from it. A
currency without a cap says *no cap*. Currencies exist from Burning Crusade on.

**Reputations**, by standing, with progress through the current standing.

**Quests**: the quest log, by zone, in the game's difficulty colours for that member's level,
with progress on each quest. **Click a quest to open it in the game's quest log**, when it
belongs to the character you are playing. Only those rows light up on hover.

Reputations and Quests also have a **Whole family** view. For quests it lists each quest once,
with the characters who have it underneath, the one furthest along first.

See §9 for more about **Whole family**.

**Achievements**, by category, with points and the progress on unfinished ones. Mists only. On
the other versions the section is not shown.

**Family closes when it opens one of the game's windows for you.** That happens when you click
a quest, or a worn item on your own character. Family is drawn above the game's panels, so the
window you asked for would be hidden behind it. Type `/family` to bring Family back on the
page you left.

---

## 8. On the game's own tooltips

Family adds a lot of information to the game's own tooltips, with no window open.

**Hover any item, anywhere**: at a vendor, at the auction house, in a trade window. Family adds
a **Family possessions** block: who in the family has one, how many, and where. The places are
bags, bank, mail, auctions, guild bank, and equipped.

![An item's own tooltip in the game, with Family's block added to it](images/tooltip-item.png)

**Up to ten members, those holding the most, are named**, where the screen has room for that
many. The rest are counted together, with how many they hold, so the total at the top still
adds up. Guild banks are shortened the same way. Untick *Fold long lists to fit the page* in
Options and the tooltip names as many as fit on your screen.

**Hold CTRL and ALT and click the item** to open Family on Possessions, **Whole family**,
showing everyone who has one. It works in your bags, on a link in chat, and anywhere else the
game passes the click on. The tooltip mentions the shortcut in grey, under the owners, on any
item the family holds. It is left off action bar buttons, where those keys belong to the bar.

**Soulbound copies on your other characters are marked**, in the game's own word. For the
character you are currently playing the game already says it, and Family does not repeat it.

**An owner's item on cooldown says when it can be used again.** Hover a Salt Shaker or a
Chronoboon Displacer while playing another character, and the line with each owner's name
carries *ready in 3h* beside where the item is.

**Random-suffix items are counted one version at a time.** A sword *of the Bear* and the same
sword *of the Whale* are counted, and priced, separately. Enchants and gems make no difference
though: two of one sword with different enchants are counted as two of the same thing.

**Hover a recipe item** and Family adds a **Family crafters** block. It lists who knows the
recipe, who can learn it now, and who has the profession but needs more skill or levels. Only
members with that profession are listed.

- The recipe is recognised by what it teaches and what it makes, so it is matched correctly
  whatever language the game was in when a character was recorded.
- **Recipes that need a specialisation.** An armoursmith cannot make a sword, and a goblin
  engineer cannot make a gnomish device. A character on the wrong branch is not offered as
  able to learn the recipe. The line names the branch the recipe needs, in your game's
  current language.
- A character Family has not read since it learned to check branches says *may know it*. Log
  in on them once and it fills in.

**Items made by using another item.** Refined Deeprock Salt is on nobody's recipe list. It
comes out of a Salt Shaker, which has a cooldown. Hover the salt and Family names whoever owns
a shaker and has the 250 Leatherworking to use it, and says whether theirs is ready or when it
comes back.

Both blocks add the realm to a name only when two listed members share that name. Members of
the opposite faction are marked.

**What an item is made of** can be added too: every material, how many, and what they cost
where Family has prices. It appears on anything a profession makes, and on enchants. It is one
of the Extras and is off until you switch it on (§13).

The possessions block and the prices are switched on/off in **Options**.

---

## 9. Searching the whole family

Possessions and Professions each have a **Whole family** button at the top right. It is the
same button as the one on the Character page's gear section (§7).

Press it and the search covers everybody, and the results say **who**: who has the mageweave,
who can make this belt, who knows this enchant. Type at least two letters in the search box at
the top, then refine the list.

**On Possessions** each item is listed once, with whoever has some underneath: most first,
with how many and where they keep it. **Sort by** character and you get each character with
what they carry. Each version of a random-suffix item (§8) is a line of its own.

**On Professions**, click a recipe and its materials appear on a line underneath. The people
who can make it are listed several to a line. Guildmates who share their professions (§12) are
listed as a second group. The search waits until you stop typing.

**Long lists of owners or crafters fold only when the page cannot hold them.** Where
everything fits, nothing folds. Where it does not, every list on the page folds by the same
amount, as little as brings the page back to one screen. A folded list always keeps at least
three names, and ends in a line you can click to open it.

**To stop lists folding**, untick *Fold long lists to fit the page* in Options. Every name is
then drawn and the page scrolls (or scrolls longer). This applies to the game's tooltips too,
which still stop before they run off your screen.

Only items your game has named can be found. An item nobody has looked at since the last patch
has no name yet, and Family says so.

---

## 10. Crafting cooldowns

Transmutes, mooncloth, salt shakers and the rest.

**Crafting cooldowns only.** Raid lockouts, heroic resets and daily quest resets are not
recorded.

**Family records the moment a cooldown comes ready**, not the time remaining. That is why a
cooldown recorded three days ago is still right today, however long the game was closed.

**Summary / Crafting** shows all of them at once. There is a line for each kind of cooldown,
with everybody who has it underneath: those who can use it now first, then whoever comes back
soonest. Ready is green. Waiting is grey, with the time left.

Beside each cooldown's name is how many of your characters can use it right now. A long list
folds by the rule in §9. Click the cooldown's name to open or close its list.

**Cooldowns that share a timer are one line.** All alchemy transmutes share one timer on
Classic Era and Burning Crusade, so they appear as one line called *Alchemy*. Enchanting works
the same way on Burning Crusade and Mists. A cooldown that shares nothing keeps its recipe's
name.

**A salt shaker is listed under leatherworking.** The cooldown is on the item, and Family
files it under the profession whose recipe makes that item.

**A transmute is listed even before you have ever used it.** Family knows from the game which
recipes carry a cooldown, and for how long on your version of the game. Mithril to truesilver
is two days on Classic Era and twenty hours on Burning Crusade.

**Only members with a crafting cooldown are listed.** Thirty members with three alchemists
make three rows.

**Cooldowns are named in your language**, whatever language the game was in when they were
recorded.

**At login Family says which cooldowns are ready.** Switch that off in Options if you want.
The minimap tooltip counts them (§2), and `/family ready` lists them by name.

**Only professions the character still has.** Drop alchemy and cooldowns stop counting.

**Item cooldowns are not announced when they come ready while you play.** Using a recipe needs
the profession window open, and Family reads that window. Opening the profession window one
minute after a cooldown became ready will give the right information, but nothing will push
that information to the game's chat without opening the Family window first.

---

## 11. Wide Family

A family need not be just one account. You can add another player's characters as members of
yours, and they can add yours. Nothing is shared until you tick it, one member and one
category at a time.

> **Wide Family is switched off until you ask for it.** The switch is in **Options**, beside
> the one for Guild share, or type `/family wide on`. It needs no reload, and both players
> have to switch it on. `/family wide off` switches it
> off again, and anything you were shown through a link stops being shown.

**Who you can link with.** The other player must be online, running Family, and on your realm
or a realm connected to it, and on your faction when you establish the link. You do not need
to share a guild or a group. A link travels by whisper, so it reaches as far as a whisper
does. When a linked family has no character within reach, the panel says that none of their
characters is on a realm this character can reach.

### Linking

Type the other player's online character name on the **Wide Family** panel and press *Ask to
link*. They see the request and press *Accept* or *Decline*. Until they accept, nothing has
been exchanged: no member list, no names.

Once established, a link is between two families, not two characters. Both players see it on
every one of their characters. It keeps working whichever character either of you is playing.

Open a link and you can type a name or alias in **Call them**. That is what the family will be
called on your screen from then on. Empty the box to get the default name back, which is the
name of the character the link was made with.

### If nobody answers

A request with no answer stays on the panel under **Waiting for them to answer**, with how
long ago you asked. After a couple of minutes it is marked *no answer*, and you can *Ask
again* or *Forget*.

Family cannot tell why there was no answer, so the panel lists the possible reasons:

- they are offline, or not running Family
- their Family version is too old to know how to answer
- the two of you cannot exchange addon messages at all

The third happens between some realms. A whisper can reach somebody and still not carry an
addon's message with it, and no addon can work around that. If *Ask again* never gets an
answer and you know they are online with Family running, this is the likely reason.

### Deciding what may be seen

Click a linked family's name to open it. Under *What they may see of your characters* is a
grid: your members down the side, categories across the top.

| Category | What it carries |
|---|---|
| Possessions | bags and bank, and the slot counts |
| Equipment | what they are wearing, and their item level |
| Professions | recipes, ranks, specialisations and cooldowns |
| Talents | talent trees and the spellbook |
| Quests | the quest log |
| Mail | what is waiting, and when it expires |
| Auctions | what is listed |
| Reputations | standings |
| Money | money |
| Character | time played, rested experience, guild, hearthstone, where they are, mount |
| Currencies | currencies |
| World buffs | the buffs they carry and what is stored in a Chronoboon |

**The grid starts with nothing ticked**, and there is no *share everything*. Offering a member
at all shares who they are: name, realm, class, race, level and faction. Nothing else is sent
without a tick.

**Click a category's name** to tick it for every member at once. Click it again to clear the
column. The other family is told once, not once per member.

**Unticking a box tells the other side to forget what it held, at once.** This is sent even
when automatic exchange is off.

### When data moves

- **When a linked family comes online.** Each side announces itself at login and the two
  exchange.
- **When you change what is shared**, at once.
- **When you press Update now.** It asks for their data and sends what changed on your side.
  When nothing changed, it says *nothing to send* and how many members are unchanged.

The first of these is the tick box **Exchange automatically when a linked family comes
online**. Untick it and nothing is announced at login and nobody's announcement is answered.
*Update now* works the same either way.

**Both of you must be online at the same time**, on any character. *Update now* tries the
character you last heard from, then the family's others, until one answers. If none does,
Family says the family is not online and sends nothing.

**Nothing is sent as you log out.** The next login brings both sides up to date.

**A share that stops part way continues next time.** Each side confirms what it stored, and
the line under a family counts *confirmed* members. Anything not confirmed is sent again at
the next exchange. While a share is going out, the same line says how many pieces are left.

**To send everybody again**, type `/family wide resend <family>`, with the family's name as
the panel shows it. Family first says how many characters it will send and about how long it
will take. Use it when something looks wrong on their side although nothing changed on yours.

**A large transfer waits for combat to end.**

### What linked data is, and is not

- **Kept apart** from your own members and always marked as another family's. It is never
  merged and never edited.
- **A snapshot.** Nothing is sent as it happens. What the other player sells, equips or loots
  reaches you at the next exchange, not in real time.
- **As old as the last exchange.** The panel says how old that is.

### What they share with you

Under *What ... shares with you* is everyone that family has given you. Beside each member are
the same category columns, greyed, because they are the other player's choice. They show what
that player granted. A family running an older version of Family does not report its grants,
and there Family shows only what arrived.

**You can look at any shared character.** The member buttons on Abilities & Talents,
Possessions, Professions and Character lists them at the bottom, under their family's name.

### Siblings

Each member shared with you by the other party has a **Sibling** tick box. Tick it and that
character is listed with your own in the Summary, under the realm they are on and the name of
their family, in every column set. They are also in the whole-family gear rows (§7), and their
possessions count on item tooltips, where their name carries their family's name. Click the
word *Sibling* to tick the whole column.

Ticking a sibling sends nothing and asks nobody. Ticking a linked character into a Sibling
only changes where you see its data on your end, not which data you get or don't get. You can
only tick a character that the other family already shares with you.

A sibling is never added to your totals.

If the other player unticks that member, or either of
you ends the link, the sibling disappears with it.

### What Family cannot promise

Family never sends what you did not tick. When you untick a box, Family asks the other side to
delete what it has. That is a request to another player's computer, and no addon can enforce
it there.

### If the panel says it cannot run

Wide Family needs two libraries, `LibSerialize` and `LibDeflate`. A copy of Family installed
from CurseForge includes them. A copy built from the source code does not, and the panel says
so.

---

## 12. Guild share

Guildmates who run Family see each other's characters in that guild, and only those, without
anybody ticking anything. You can also tell the guild what your characters can craft.

> **Guild share is switched off until you ask for it.** The switch is in **Options**, beside
> the one for Wide Family, or type `/family guild on`. It needs no reload. The panel is in the
> list either way. While it is off, Family neither asks the guild nor answers it.

**What is shared as soon as it is on:** for each of your characters in this same guild, their
class, race, level, the shape of both talent specialisations, and their equipped gear with its
average item level. All of that is what the game already shows a guildmate who inspects you.

**Never shared with the guild:** bags, bank, mail, quests, money, auctions, reputations. To
show somebody those, link with them through Wide Family (§11).

**Professions are shared only if you tick them** (below).

### The panel

The guild roster, with **Online only** or **Everyone**. Each row has a dot: filled for
somebody running Family, grey for somebody who is not.

Click a guildmate with a filled dot to see their characters in the guild. Each one shows
their gear slot by slot, with item levels and tooltips, and both specialisations. The active
one is in gold.

**Talents arrive as the shape of the build**: which trees, and how many points in each. For a
build talent by talent, link with that player through Wide Family.

**Once you have seen somebody, they are kept.** A guildmate who logged off an hour ago is
still listed, with the age of the record on the row. Nothing can be fetched from somebody who
is offline. **Update now** asks everybody who is online.

**Alts outside the guild are not shown**, and there is no setting to add them.

**Connected realms count as one guild.** Your characters on any realm of the group are offered
to the guild, not only those on the realm you are on. Family uses the game's own list of
connected realms, so a guild with the same name on an unconnected realm stays a different
guild.

### Sharing what you can craft

At the top of the panel, click **What you share with** your guild. Each of your characters in
the guild lists its professions, each with a tick box. Nothing is ticked to begin with.

A tick shares three things together: the rank, what that profession can make, and its
cooldowns. Guildmates running Family then see your character:

- on the tooltip of an item it can make, under the crafters from their own family, with
  *ready now* or *ready in 4h* for anything on a cooldown;
- in the recipe search on their Professions page, as a second group beside their own members.

Each answer carries its age. It is as old as the last time you opened that profession, or the
last time they heard from you, whichever is older. A profession you ticked but never opened
shares only its rank, and you are listed as *may know it*.

Professions that make nothing have no tick box: fishing, herbalism, skinning, first aid and
archaeology. Mining has one, for smelting.

Untick a profession and it stops being sent. What guildmates already hold is replaced the next
time they hear from you. Records from anybody who has not been heard from for two weeks are
dropped, and come back when that player does. Your own ticks never expire.

A few recipes cannot be shared, because the game gives Family no number for them, only a name
in one language. The panel lists them after *Not offered*.

### Things to know

Guild share and Wide Family are separate. Linking with a guildmate does not change what the
Guild panel shows, and the Guild panel does not change what a link shows.

Guild share needs the same two libraries as Wide Family (§11), and the panel says so when they
are missing.

`/family guild on` and `/family guild off` do the same as the switch in Options. `/family
guild` on its own says whether it is on, how many addon messages your game is sending, and how
many guildmates have answered.

**A character on a connected realm may hear the guild and not be heard by it.** Guild chat
works, other players' data arrives, and nothing Family sends reaches the guild. That is the
game's doing. `/family guild test` sends one announcement and reports what happened to it.
What you share still reaches any guildmate whose Family announces itself first.

---

## 13. Options

| Setting | What it does |
|---|---|
| Show the minimap button | the button remembers where you dragged it |
| Always open Family on one panel | a star beside each panel makes Family open on it. On the summary it keeps the set of columns too |
| Add Family to item tooltips | who owns one, and where (§8) |
| Show prices on item tooltips | what a vendor pays and charges, and the auction house's last price (§15) |
| Draw the carried bags as one block, and the bank as another | Possessions shows one run of slots for the bags and one for the bank |
| Fold long lists to fit the page | on to begin with. Untick it to see every name in every group (§9) |
| Say whose mail is running out when you log in | with how many days' warning you want |
| Say which crafting cooldowns are ready when you log in | the login message in §10 |
| Share gear and talents with your guild | Guild share (§12), in both directions at once |
| Share with families you link to | Wide Family (§11) |
| Say in chat how a Wide Family update went | for example, that a linked family had nobody online |
| Narrate what the scanners are doing | chat messages while Family records. For tracking down faults |
| How far in front the window sits | raise it if another addon draws over Family |

The line at the bottom says which version of Family is running and which version of the game
it found. Quote it when you report a fault.

### Extras

The **Extras** panel holds optional jobs. Each has its own switch.

| Extra | Starts | What it does |
|---|---|---|
| Read prices at the auction house | on | reads prices from whatever the auction window shows, including another addon's full scan |
| Let Family read the whole auction house itself | on | adds a **Family** tab to the auction window, with a button that reads every page |
| Say what a craftable item is made with | off | lists every material and how many, on the tooltip of anything a profession makes and of enchants, with the total cost where Family has prices |
| Say what came out of the mailbox | off | a chat line for each sum and item taken out of a letter, and a total for the visit |

**With price reading off**, Family values everything at what a vendor pays, reads nothing at
the auction house and adds no tab there. Prices already recorded are kept, so they show up
again, with their age, when you switch it back on.

**Made with.** An item that is crafted is costed through its own recipe, however deep the
chain goes. A Lionheart Champion needs a Lionheart Blade, so it costs what the Blade's
materials cost. Each material is priced at the cheapest of buying it and making it: a Bolt of
Runecloth is costed from its own recipe when one of your characters can weave it and weaving
comes to less than the auction house or a vendor asks. A material nobody in your family can
make is priced at what it sells for. When a material has no price, the total says *some prices
are missing*.

Where making a material would save money but waits on a crafting cooldown, such as a transmute
or a Salt Shaker, or on farming, the total stays at what you can buy today. A second total
under it says what the slower way would come to.

**What a vendor pays is known from the first day. What a vendor charges is not**, until one of
your characters visits a vendor who sells that item. So Family can value everything you own at
vendor prices straight away, but at first it cannot say what a recipe costs to make. Most
material prices come from auction house listings. Basic reagents such as vials, thread and
flux have to be seen once at a vendor. A vendor's price is the same on every realm and for
both factions, so a price seen once counts for all your characters on that version of the
game.

**What came out of the mailbox** works with the game's own Open All and with mail addons. The
total of the money collected from all letters appears when nothing is left to take, or when
you close the mailbox.

### The auction house

**Prices come from what you look at.** Family reads the list the auction window is showing:
your own searches, and the full scan of a specialised addon such as Auctionator or Auctioneer.
It sends no request of its own unless you press *Read it all*, which you do not need if you
scan with another addon. Prices are kept per realm and per faction. A price read at a
**goblin** auction house counts for both factions of that realm, and your own faction's
auction house wins where it has a price.

**Connected realms share one auction house**, goblin houses included. A price read on any
realm of a connected group counts for your characters on all of them, and the most recent
reading wins. Family learns which realms are connected from the game at login. Log in once on
any realm of a group and it knows the whole group.

**The Family tab** on the auction window has the *Read it all* button and a progress line:
pages done, prices taken, and roughly how long is left. Press the button again to stop. What
was read is kept. Where the tab cannot be added, the button sits beside *Reset* on the Browse
panel.

**A full read takes minutes on Classic Era and Burning Crusade.** The game answers one page at
a time. If you run an auction addon, its own full scan is faster and Family reads the same
prices from it. On **Mists of Pandaria** the whole house arrives in one answer, within seconds.

A read that stops getting answers ends and says why. If it will not start, search the auction
house once and turn one page, then press the button again.

`/family ah scan go` and `/family ah scan stop` do the same as the button.

**Random-suffix items are priced one version at a time** (§8).

### The price list

On the Extras panel, **Auction prices** lists every price Family holds: the item, the market,
the price of one, the price it replaced and when it was seen. Filter it by market, by item
name, or by the auction house's own categories. The panel is mainly for finding and managing
troll prices.

- A price ten times or more the one it replaced, or ten times what the item costs on your
  other markets, is marked in red as a suspect. **Suspects only** shows just those.
- **Delete** removes a price. Your next visit to that auction house reads a new one.
- **Ban** keeps the price in your database but leaves it out of every figure Family works
  out, until you press **Lift** or delete it. Family goes on showing it beside the ban. A ban
  on one realm of a connected group covers the whole group. **Bans only** shows just the
  bans. Scanning the auction house again updates the figures, so with **Bans only** you can
  quickly see which troll prices are gone and **Lift** the ban.

---

## 14. What Family will not do

Family reports what your characters have. It does not advise. It will not tell you:

- which recipes a member is still missing
- which piece of gear to improve next
- where an item is looted, sold or rewarded

The game tells an addon what an item is, not where it comes from. Everything Family shows
comes from your own game, or from another player's Family.

---

## 15. When something looks wrong

**"It says not seen."** That is not a fault. Open that window once on that character — bank,
mailbox, auction house, profession — and it is recorded from then on.

**"A number is out of date."** Every screen says when it was last seen. Bags and money are
current for the character you are playing. Everything else is as old as the last time that
character was played, or that window was opened.

**"A sibling's *Last seen* says *shared*."** A linked family does not send when its characters
last played. A sibling's row shows *shared 2 h ago*: the age of what you hold from them. A date
with no word beside it belongs to your own family.

**"A profession has no recipes."** Its window has not been opened since Family was installed,
or it is a gathering profession. The Professions page says which.

**"A profession or its recipes are in the wrong language."** Professions, races and recipes
are shown in your language, whoever recorded them. After you change the game's language, a
recipe list may take a moment to catch up the first time you open the page.

**"I clicked a recipe and nothing happened."** Family selects the recipe in the game's own
profession window. An addon that replaces that window, such as Skillet, draws its own list and
may not show the selection.

**"Do my pet's training points add up?"** Type `/family pettp`. For every creature Family has
recorded, it lists the abilities the creature knows, what each costs, and what the creature
has spent in all. A dash means Family has no price for that ability yet. Open the Beast
Training window with that pet out to fill it in.

**"What is all my stuff worth?"** The figure is on the character's **Possessions** page, under
the line that says how old each part is, and in the **Worth** column of the summary (§3). It
covers worn gear, bags, bank, mail and auctions. It leaves out the guild bank, which belongs
to the guild, and the keyring.

- Each item is valued at the last auction price Family saw. Where there is none, it is valued
  at what a vendor pays.
- **A soulbound item is always valued at what a vendor pays**, because it cannot be sold at
  auction.
- The line says how much of the total came from auction prices, how much from vendor prices,
  and how many items had no price at all.

**"Can Family show prices on tooltips?"** Yes. Tick *Show prices on item tooltips* in Options.
Three lines can appear:

- **Sell price** is what a vendor pays you. The game knows it for every item.
- **Vendor price** is what a vendor charges. It appears only for items Family has seen on a
  merchant's list. Open a merchant and Family remembers what they sell. If two characters saw
  different prices, the higher is kept, because a reputation discount only lowers a price.
- **Auction** is the last auction price, with its age in front: *(3d ago) 4g 20s 00c*. Within
  one visit the cheapest listing counts. The next visit replaces it.

**Hold CTRL over a stack** and a line says what the whole stack sells for: *Stack of 20*, and
the total. You can press the key with the pointer already on the stack. It works in your bags,
on an auction row, on a vendor's list and in a loot window.

**Hold CTRL over any item** and Family says what everything your characters hold of it is
worth, and how much of that is at auction prices and how much at vendor prices. Each character
is valued on their own realm and faction, and the age of the oldest price used is shown beside
the figure. The guild bank has its own line and is left out of this figure.

**On an action bar button, press CTRL before you point at it.** Action bars use shift, control
and alt for their own bindings, so pressing the key while the tooltip is up does nothing there.

**"What can Family read at the auction house?"** Type `/family ah`. It says what this version
of the game allows, how many rows are on show, and how many prices Family holds for your realm
and faction, with the age of the oldest and the newest. It sends nothing to the auction house.

**"A character's abilities look wrong."** Type `/family spellbook`. It goes through the game's
spellbook tab by tab and says which tabs Family records, every row it would record, and how
many rows it passed over. On Mists the spellbook has a tab for each specialisation, listing
everything that specialisation can ever learn. Family does not record those tabs.

**"The game stops for a moment when Wide Family is on."** Type `/family widetime`. For each
link it says how many members are shared, how long it takes to work out which of them changed,
and how many are unchanged. Unchanged characters are never sent. Where some have to be sent,
it names them and says why: *changed since they were sent*, or *never confirmed as sent*. It
sends nothing, and nobody has to be online.

**"Family is slow to load."** Type `/family status`. It says how long your saved data took to
read at the loading screen, and how many characters it holds.

**Something errored.** Tick *Narrate what the scanners are doing* in Options and make it
happen again. Report the message together with the line at the bottom of the Options page.

Faults and suggestions: <https://github.com/uga/Family/issues>
