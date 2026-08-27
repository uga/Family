# Family — the CurseForge project description

The text CurseForge shows on the project page, kept here so it is reviewed like everything
else rather than typed into a web form once and forgotten. CurseForge asks for the features,
what each one does to a player's experience, and a clear reason to download; the sections
below are ordered so that a reader who stops after two paragraphs has still been told what
Family changes about the game.

Paste everything below the rule into *Description* on the project page. CurseForge's editor
takes headings, bold and lists. Upload `images/family-logo.png` as the project logo, which is
a required field, and the screenshots in `images/` are worth adding beside the text — the two
panels people decide on, the summary and the whole-family gear grid, are much easier to see
than to describe.

**On length.** This was three times longer and was cut on purpose. CurseForge's moderation
guidance asks for detail *and* warns against walls of text, and calls the description the most
common reason a project is sent back — so the concrete examples were kept and the scaffolding
around them was dropped, on the view that a page nobody finishes reading fails the same test a
vague one does. The fuller text is a `git log -p` away if a moderator ever asks for more.

Keep it true to the version that is actually published. Two things go stale: what Wide Family
is doing (switched off in `1.0.0-beta.1`) and the client list.

---

## Family

**See what your other characters have, without logging into them.**

In WoW Classic there is exactly one way to find out what is in your bank alt's bags, whether
your druid ever learned that recipe, or which character is carrying the Arcanite Bars: log out,
log in, look, log back. The server will tell you nothing about a character you are not standing
on.

Family watches each character as you play it — what it owns, what it knows, what it is wearing,
what it has in the post — and shows all of it from any other character, at any time, in one
window. It calls them **members** rather than alts, and it is built for people who have a lot
of them.

**On the game's own item tooltips.** Hover any item anywhere — a quest reward, an auction house
listing — and Family adds who in the family owns one, how many, and **where**: bags, bank,
guild bank, mailbox, auction house. Hover a recipe and it says who can make it, who can learn
it today, and who is not high enough yet. You stop buying the second Thorium Lockbox because
you had forgotten the first one is in your rogue's bank.

**The whole family on one screen.** Every character you have played, grouped by realm and
faction, with money, bag space, professions, level and currencies, and totals per realm. A
realm where you play both sides is split in two, because two factions share no auction house
and no mailbox and adding their gold together would be a lie.

**Everyone's gear at once.** One row per member: their class, then every slot in the order the
character sheet uses them, item level printed over each icon, the item's own tooltip on hover,
and filters built from what your family actually contains. Any addon can show you a character
sheet. This answers the question people actually have — *which of my characters is behind* —
like the level 42 trinket your warrior is still wearing at 60.

**Possessions and professions, searchable across the whole family.** Bags, bank, guild bank and
mailbox drawn as the containers they are rather than as a list, and every member's recipe lists,
sortable by difficulty that orders properly *within* each colour band rather than alphabetically.
Both carry a search that answers *who has this* and *who can make this*.

**Mail written down as you post it.** Send gold or items to one of your own characters and it
appears against them straight away, marked as being in the post, until that character opens
their own mailbox and the truth replaces it. Mail approaching its return-or-destroy date is
announced on any member — which is the whole point, since it is never the one you are playing.

**Cooldowns that survive being logged out.** Recorded as the moment they come ready rather than
as a duration, so they stay correct however long the client has been shut, and announced at
login. Thirty alchemy transmutes share one timer and appear as a single column.

Also: a full character sheet for any member, with enchants, gems, reputations, quests and
achievements; both talent specialisations, glyphs and the spellbook; a minimap button and a
data broker feed carrying the family's money.

### Sharing

**Guild share is on, and one switch turns it off.** Guildmates running Family show each other
their characters' gear and talent shape, including the offline ones once you have seen them.
**Nothing else is shared** — no bags, no mail, no gold. It is on by default because all of it
is what the game already shows anyone who inspects you.

**Wide Family ships switched off in this version.** Linking two players' families, with
per-member and per-category consent on a grid that starts empty, is finished and its checks
pass — but none of them has run against a live server, and sharing is the one thing a later
version cannot undo. `/family wide on` if you want to help test it.

### What to expect

- **It starts empty and fills as you play.** There is no import from any other addon, ever.
  Everything Family holds, it holds because it watched it happen.
- **Log into each character once.** Bank, guild bank, mailbox and profession windows are
  recorded while they are open; bags update on every change.
- **Nothing is shown as empty when it was simply never seen**, and every screen says how old
  what it is showing is.

### Clients and languages

Classic Era, Classic Burning Crusade (Anniversary) and Classic Mists of Pandaria. Season of
Discovery and Retail are not supported and not planned.

English, German, French, Spanish and Russian, for both the interface and the recorded data —
Family stores identifiers rather than names, so a character recorded on a German client reads
back correctly on a French one.

Two addons in one download: `Family` records, `Family_UI` shows. Free software under
**GPL-3.0-or-later**, source public — nobody can take Family closed, including if this project
is ever abandoned.
