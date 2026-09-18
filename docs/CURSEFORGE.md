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

**On the manual.** It is linked, never pasted. `MANUAL.md` is six thousand words against this
page's eight hundred, and the length below is the whole point of the section under it — but a
reader who wants more than this page has to have somewhere to go, and a link stays right
without anybody re-pasting it on every revision.

**On length.** This was three times longer and was cut on purpose. CurseForge's moderation
guidance asks for detail *and* warns against walls of text, and calls the description the most
common reason a project is sent back — so the concrete examples were kept and the scaffolding
around them was dropped, on the view that a page nobody finishes reading fails the same test a
vague one does. The fuller text is a `git log -p` away if a moderator ever asks for more.

Keep it true to the version that is actually published. Three things go stale: whether the two
sharing features ship on or off (both ship **off**, as of `1.0.0`), where their switches are
(**Options**, since `1.0.0` — the panels no longer carry their own), and the client list.

---

## Family

**See what your other characters have, without logging into them.**

Family records each character while you play it: what it owns, what it knows, what it wears,
what is in its mailbox. Every other character can then see all of it, in one window. Family
calls your characters **members**.

The game tells you nothing about a character you are not logged into. With Family you stop
relogging to look inside a bank alt's bags.

**On the game's own item tooltips.** Hover any item, anywhere: a quest reward, an auction
listing. Family adds who in the family owns one, how many, and where: bags, bank, guild bank,
mailbox, auction house, or equipped. Hover a recipe and it names who knows it, who can learn
it now, and who needs more skill or levels first. You stop buying a recipe your druid already
knows. Hold CTRL and ALT and click an item, and Family opens on every copy the family holds.

**The whole family on one screen.** One row per member, grouped by realm and faction, with
totals for each group. The columns cover level, item level, rested experience, money, bag and
bank space, professions, mail and auctions. Play both factions on one realm and you get two
groups. The two sides share no mailbox and no auction house, so their gold is counted apart.

**Everyone's gear at once.** One row per member: the class icon, then every slot in the order
of the character sheet. Each icon carries its item level and shows the item's own tooltip on
hover. Filter by realm or by class. One look tells you who is behind, like the warrior still
wearing a level 42 trinket at 60.

**Bags, bank and recipes, searchable across the family.** Bags, bank, guild bank and mailbox
are drawn as containers, the way the game draws them. Each profession lists its recipes, and
you filter them by difficulty colour, by equipment slot or by name. One search answers *who
has this*. Another answers *who can make this*.

**What it is all worth.** Family reads auction prices from the listings you browse. It scans
the whole auction house only when you press **Read it all**. Each member's page says what
their bags, bank, mail, auctions and worn gear come to, and how much of that figure is auction
prices and how much is vendor prices. Switch on prices in **Options** and holding CTRL over
any item shows what the family's copies of it are worth. Realms that share an auction house
share their prices.

**Charges and world buffs.** The charges left on a Wizard Oil or a Bag of Marbles are printed
in the corner of the icon, in your bags, your bank and the guild bank. The summary counts the
world buffs each member has stored in a **Chronoboon**. Click the number and each buff appears
as its own icon, with the time left on it.

**Mail recorded as you send it.** Send gold or items to one of your own characters and the
mail shows against them at once, marked as in the post. When that character opens their
mailbox, what is really there replaces it. Family also warns you when any member's mail is
close to being returned or destroyed, whichever character you are playing.

**Cooldowns that survive logging out.** Family stores the moment a crafting cooldown comes
ready, so it stays correct however long the game was closed. At login it tells you which
members have one ready. Alchemy transmutes share one timer and appear as one cooldown.

Also:

- A character sheet for any member, with enchants and gems on the gear, plus reputations,
  quests, currencies and achievements where the game has them.
- Both talent specialisations, glyphs and the spellbook.
- A minimap button and a data broker feed showing the family's money. Shift-click it to count
  one realm and faction, or one character.

### Sharing

Both sharing features are switched off when you install Family. Both switches are in
**Options**, and neither needs a reload.

**Guild share.** Guildmates who run Family see each other's characters in the guild: class,
race, level, gear and the shape of both talent builds. All of that is what the game already
shows anyone who inspects you. A guildmate you have seen once stays listed after they log
off. Guilds spanning **connected realms** count as one guild. You can also offer your
professions, one character and one profession at a time, on a grid that starts empty. Then a
guildmate hovering an item sees which of your characters can make it, and whether its cooldown
is ready. Bags, bank, mail and gold are **never** shared with the guild.

**Wide Family.** Link your family with another player's, and each of you can see the other's
characters. You choose what they may see, one member and one category at a time: possessions,
equipment, professions, talents, quests, mail, auctions, reputations, money and more. The
grid starts empty, so nothing is shared until you tick it. Untick a box and what was shared
under it is deleted from their side the next time the two families are in contact. Both
players must switch it on, in **Options** or with `/family wide on`.

### What to expect

- **It starts empty and fills as you play.** Nothing is imported from any other addon.
- **Log into each character once.** Bags update on every change. The bank, guild bank,
  mailbox, auction house and profession windows are recorded while they are open.
- **Every screen says how old its information is.** Something Family has never seen is shown
  as not seen, never as empty.

### Clients and languages

Classic Era, Classic Burning Crusade (Anniversary) and Classic Mists of Pandaria. Season of
Discovery and Retail are not supported and not planned.

English, German, French, Spanish and Russian, for both the interface and the recorded data.
A character recorded on a German client reads correctly on a French one.

The download contains two addons: `Family` records and `Family_UI` shows. Family is free
software under **GPL-3.0-or-later**, and its source is public.

### The full manual

Every panel, every column, and what to do when something looks wrong:
<https://github.com/uga/Family/blob/main/docs/MANUAL.md>

Faults and suggestions: <https://github.com/uga/Family/issues>
