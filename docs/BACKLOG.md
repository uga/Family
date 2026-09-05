# Backlog

What has been asked for and not built. Reported by players, or by Alberto from play.

**This file is not a plan and not a promise.** It is a place for a request to wait without
being reconstructed later from a screenshot. A decision to build one of these is a row in
[`DECISIONS.md`](DECISIONS.md), taken in the turn it is taken; until then an entry here is
only a thing somebody asked for.

Each entry says what exists today, **measured rather than remembered** — because half of what
looks like a new feature turns out to be an existing one that reaches only one panel, and the
other half turns out to need a measurement before a line of code is worth writing.

Received 2026-09-04, from users.

## The order, agreed 2026-09-04

**Honor last, in a build of its own.** It is the only entry that needs research, then a model,
then code, and its research turned up three systems sharing a word — so it would hold everything
else behind it for no reason. Everything else ships first, then a release, then honor.

**"The other seven" as first written is now nine**: entries 9 and 10 arrived on the same day and
belong in the same batch. Restated on 2026-09-04 after a release was proposed early and Alberto
held the order to what it says: 1.5.0 is cut when the rest of this list is done and not before,
however full `Unreleased` looks.

Done so far in this batch: **4**, **6**, **7**, **8**, **11**, and slice one of **3**. Left
before the release: **1**, **2**, the rest of **3**, **9**, **10**.

Two things that order should not hide:

- **Entry 2 also has a client question in it** — whether a tooltip can be redrawn while a
  modifier is held — and it is small but it is a probe, not a guess. It is not in honor's class
  and it is not nothing.
- **Entry 4 is done**, and it never entered this order: it was decided on 2026-09-04 and built
  the same turn, because the answer turned out not to need a library adopted at all.

Suggested sequence for the seven, and the reason is dependency rather than size: **3 then 8**
(the family-wide reputation view is a panel that wants the filtering from entry 3, so doing 3
first leaves 8 mostly done), with **6 and 7** available whenever a session wants something
self-contained, **1** as a check that may turn into a small fix, and **2** after its probe.

---

## 1. Wide Family: quest sharing, verified end to end

**Asked:** check that quest sharing works across a Wide Family link.

**Today:** `quests` is a real category — `Family/Wide.lua` `CATEGORIES` carries the `quests`
payload and the `questCount` meta, so the data crosses. What is unverified is the other half:
whether a linked family's quests are *shown* anywhere, and whether a sibling's quest count
reaches the panels that display quests.

**Shape:** a check, not a feature. If the data crosses and nothing draws it, that is the gap.

---

## 2. A recipe item's tooltip, both ways

**Asked:** a profession item's tooltip shows the crafted item — except enchanting, which shows
the crafting spell. Both should be reachable: hovering gives the item, hovering with **CTRL**
held gives the recipe.

**Today:** the label comes from `Family.Names:Recipe`, which prefers the spell where a client
gave one and the product where it did not — which is why enchanting reads differently from
everything else. The two-lane matching added on 2026-08-31 means both identifiers are now
usually known for the same row, so the second reading is available rather than needing to be
found.

**Unknown:** whether the tooltip hook can redraw on a modifier press, or whether the player has
to move the mouse off and back. That decides whether this feels like a feature or a trick.

---

## 3. Filters and sorting on every panel that lists characters

**Asked:** filter by level range, class and character name everywhere; and per panel —
overview by level, rested XP, money, last seen, free bags, free bank, bags/bank seen; activity
by mail, expiry, mail seen; professions filtered by profession and sorted by that profession's
skill; crafting by cooldown and profession; misc by guild and hearthstone.

**Today:** filters exist in exactly one place. `Family_UI/Character.lua` has a realm picker, a
class picker and a search box, built on `UI:CreateChoicePicker`. **The Summary panels have
none.** So this is extending a pattern that already works, not inventing one — and the widget
to extend is named above.

**Shape:** the largest entry here by far, and the one most worth slicing: one panel end to end
beats a filter bar that half-works on six.

**Slice one, done 2026-09-04:** the three filters that are asked for everywhere - name, class
and level range - on the Summary panel, composed with each column set's own narrowing, with a
count of what is being hidden. `docs/DECISIONS.md` carries why they are not remembered between
sessions and why an unrecorded level does not hide a member.

**Still open, and it is three more slices rather than one.** Measured 2026-09-05.

**Slice two — sorting the summary by any of its columns.** That is most of what the original
ask calls per-panel: rested XP, money, last seen, free bags, free bank, bags and bank seen,
mail, expiry, mail seen, guild, hearthstone. One mechanism covers every set because the sets
are data-driven. **Done 2026-09-05.**

**Slice three — the filter bar on the panels that already show the whole family. Done
2026-09-05**, on Professions and Possessions; the summary and the character panel keep their own
for now and moving them onto the widget is a refactor with its own run. Asked for 2026-09-05: Professions and Possessions each have a real *Whole family* switch and a search box
of their own, and neither has the realm, class or level filters. The Character panel has realm
and class in that mode and no level range.

**The Character panel's level range, asked for again from play 2026-09-05** with a screenshot of
*Equipped gear* across twenty members: it has *Realm* and *Class* and a filter box, and no level
boxes at all. It is the one panel that still builds its own bar instead of asking
`UI:CreateMemberFilters` for one, and the widget has had the two boxes since slice one - so this
is the migration above, not a fourth thing to build. Doing it any other way is the fifth copy
this section exists to avoid.

**And what a fifth copy would cost.** Two filter bars exist already - the summary's and the
character panel's - and they were written separately. Three more would be five ideas of what a
filter bar is. The shape this wants is the one `UI:CreateChoicePicker` already set: one widget,
built once, used by every panel that lists characters. That extraction is the work; the filters
themselves are a line each afterwards.

**Slice four — a whole-family mode for Quests.** It has none today. The parallel is the
professions panel's family mode, which searches recipes across everybody: here it is *which
members have this quest*, and the filters follow from that.

**Abilities & Talents is out**, said 2026-09-05 when it had been in the same sentence the day
it was asked: it needs no whole-family reading and therefore no filters. Which is the right
answer - a talent tree is one character's arrangement of points and means nothing averaged over
forty, and the spellbook half is already reachable per member.

**Still open under the original ask and not covered above:** professions sorted by that
profession's skill, and crafting filtered by cooldown and profession. Those are filters on a
column set rather than on a member, which is a different mechanism again.

**Professions filtered by profession: done 2026-09-05**, asked again from play as *who are the
blacksmiths?* A set may now declare a `narrow` of its own - a caption, the choices the family
holds, and a predicate - and one shared picker takes on whatever the open set is asking. The
mechanism is there for the crafting pair above to use rather than to invent.

---

## 4. A minimap button other addons can collect — DONE 2026-09-04

**Asked:** use LibDBIcon or similar so the icon behaves inside the popup panels other addons
build out of minimap buttons.

**Was:** confirmed, with the complaint quoted at us. `Family_UI/Broker.lua` built
`CreateFrame("Button", "FamilyMinimapButton", Minimap)` by hand, and the screenshot showed
another addon naming `FamilyMinimapButton` and asking its author to use LibDBIcon instead.
Altoholic and GBankClassic were collected; Family was not.

**Built as: used, never shipped.** The reserved question was *adopt a library?*, and reading the
licences turned it into a different question. LibDBIcon's terms forbid redistributing a
stand-alone version without written permission from the Ace3 lead, and the LibDataBroker it
hard-requires states no licence in its source, its README or its project page, where the field
reads **All Rights Reserved**. Neither can travel inside a zip promising GPL-3.0-or-later to
whoever receives it, whatever the rest of the ecosystem does — so nothing was adopted. Family
registers with LibDBIcon where the player's game already has it, and keeps its own button
everywhere else.

**Two addons are involved and the entry should not blur them.** LibDBIcon is *embedded* by most
large addons for their own icon — DBM and WeakAuras both fetch it and LibDataBroker as externals,
measured 2026-09-04 from their `.pkgmeta` — which is why it is usually loaded in a game that
never asked for it. None of them collects anything. The collector is a third addon, the kind
that sweeps LibDBIcon buttons into one bag, and it is the one in the screenshot. The embedders
are why the library is *there*; the collector is who this is *for*.
`.pkgmeta` fetches nothing new, neither `.toc` loads anything new, and the harness checks both.

Two options were rejected rather than ruled out, and stay available if this is not enough:
shipping the libraries anyway, or asking their authors in writing.

Verified in play against two collectors on 2026-09-04: **HidingBar**, which is the one from the
report and which keeps a button once it has grabbed it, and **Leatrix Plus**, which does not.
Both collect Family now, and unticking the option removes it from either.

`docs/DECISIONS.md` 2026-09-04 carries the reasoning; `Family_UI/Broker.lua`
`GiveButtonToCollector`, `registerWithCollector` and `BuildMinimapButton` carry the code.

---

## 5. Honor: rank, this week's progress, and what is left of the cap

**Asked:** track honor, including ranks and weekly progress, and how much is missing for the
weekly cap.

**Today:** nothing. Family records no honor at all.

**Measure first, and the rules are now written down.** See *Honor: what it is on each build* in
[`DATASOURCES.md`](DATASOURCES.md). The short of it: one word, three systems. Era has fourteen
ranks and a **500,000 honor weekly cap**, and the decay every guide describes was removed in
patch 1.14.4 — so the vanilla description is wrong for the client we ship against. Burning
Crusade has no ranks at all and its weekly thing is arena points from team rating, so *missing
for the weekly cap* has no meaning there as asked. Mists has two currencies and a conquest cap
that **differs per character**, which Family can only read, never compute.

What is still missing is every probe: which call answers what, on each build. That section
lists them, and none has been run.

---

## 6. A keybind that opens Family — DONE 2026-09-04

**Asked:** open the window from the keyboard.

**Today:** nothing. No `Bindings.xml`, no `BINDING_` globals anywhere in the addon.

**Shape:** small and self-contained — a bindings file and two localised strings. The only care
needed is that the binding name is a global the client localises, not a word we ship.

**Built 2026-09-04**, and that care was the whole of it. The words are `BINDING_HEADER_FAMILY`
and `BINDING_NAME_FAMILY_TOGGLE`, set in `Slash.lua` from the locale table. The harness reads
the XML, checks both names against those globals, and then **compiles and runs the binding's
body** - which nothing else in the addon would ever do, so a typo in it would have been a
syntax error a player met in the middle of a fight.

---

## 7. Lockpicking, for rogues — DONE 2026-09-04

**Asked:** record lockpicking skill.

**Today:** not recorded. `Family/SkillLines.lua` carries 15 skill lines and lockpicking is not
among them, so a rogue's lockpicking has no identity to be stored under and would fall back to
a name — which §2.1 exists to prevent.

**Shape:** extend `tools/skill-lines.py` to take it, then the professions scanner. Worth
asking what it belongs beside: it is a skill with a rank and no recipes, which is a shape
Family does not otherwise hold.

**Built 2026-09-04**, and the question of what it belongs beside had an answer: nothing it
already held. The record grew a third state - `class`, alongside primary and secondary - and it
is drawn on **Abilities & Talents**, under Spellbook, because it is technically an ability.
Skill line 633, category 7, on Era and Burning Crusade; absent from Mists, where the skill left
the game.

**One property is guarded and not pinned**: that it does not appear among the professions. Three
checks were written for it and all three passed for the wrong reason - `visibleText` sweeps every
font string in the client and cannot tell two panels apart, which is L-041's shape for the third
time. Telling them apart is its own piece of work and is worth doing.

---

## 8. A whole-family view of reputations — DONE 2026-09-04

**Asked:** a filterable family-wide reputation view.

**Today:** half of it exists. Reputations are scanned (`Family/Scanners/Character.lua`), they
cross a Wide Family link (`reputations` payload, `reputationCount` meta), and they are shown
**per character** on the Character panel. What is missing is the view across everybody.

**Shape:** the data is already stored and already shared; this is a panel. It shares its
filtering problem with entry 3, and doing 3 first would make this most of the way done.

**Built 2026-09-04**, and doing 3 first did make it most of the way done - the realm, class and
name filters were already there and needed only to stop being gated on the gear section. The
panel's *Whole family* switch was gated the same way in six places; one name replaces all six,
so the next section that wants a family reading has one line to add rather than six to find.
Rows are factions, not members: `docs/DECISIONS.md` carries why.

---

## 9. Hunters: the pet abilities known, and the pets themselves

**Asked:** read which per-pet abilities a hunter has learned, and the specialisations of the
pets they own — listing the pets as well, not only the abilities.

**Today:** not measured. `Family/Scanners/Talents.lua` and `Specialisations.lua` read the
character's own trees; nothing reads a stable. Whether the client will say what is in a stable
while the pet is not summoned is the first question, and it is a probe, not a guess.

**Received:** 2026-09-04, from Alberto.

---

## 10. Warlocks: the per-demon abilities known

**Asked:** read which demon-specific abilities a warlock has learned.

**Today:** not measured. Same shape as entry 9 and probably the same scanner, which is why the
two are written next to each other: both are "what does this class know that is filed under a
creature rather than under the character".

**Received:** 2026-09-04, from Alberto.

---

## 11. Say at login whose mail is about to expire — DONE 2026-09-04

**Asked:** at login, name in chat the characters whose mailbox holds mail that has expired or
is about to. Switchable off from the options panel, on by default. And the warning period -
how many days or hours before expiry counts as *about to* - chosen by the player in the same
panel.

**Today:** the data is recorded and the pattern exists. `Scanners/Mail.lua` writes
`mailExpiresBy` and offers `Mail:TimeToExpiry(meta)`; `Family_UI/Slash.lua` already says which
crafting cooldowns are ready eight seconds after `PLAYER_ENTERING_WORLD`, gated on
`FamilyDB.cooldownNotice`, and that is the shape to follow.

**What is missing is the third part.** `Family_UI/Options.lua` has tick boxes and nothing else -
`SWITCHES` is a list of booleans - so a number the player chooses needs a control that does not
exist yet. That is the work in this entry; the notice itself is an evening.

**Found while measuring it:** `Wide.lua` shared a mail field by the wrong name, so no sibling
has ever carried an expiry. Fixed separately - see `docs/LESSONS.md` - because a notice built on
top of it would have been quietly wrong for half the family.

**Received:** 2026-09-04, from Alberto.

**Verified in play 2026-09-04**, with the warning set to 29 days so that a thirty-day mailbox
would answer: five characters named, soonest first, each with the time it has left.

**Built 2026-09-04.** `Mail:Expiring(within)` in the data layer, the notice beside the crafting
one in `Family_UI/Slash.lua`, and the options panel's first numeric control - the switch schema
grew a `number` field rather than that row growing a special case, so the next setting that is
a number has somewhere to go. Three days by default, one to thirty. `docs/DECISIONS.md` carries
why the character being played is named and why *already gone* is not *expiring now*.


---

## 12. The whole-family reputations view, as it was actually asked for

**Supersedes the shape built for entry 8.** What shipped lists one row per faction showing how
far the family has got and who got there. What was asked for is a faction and *its people*.

**Asked, 2026-09-05:**

- It behaves like the professions panel: turning **Whole family** on empties the panel of the
  one-member reading, rather than sitting beside it.
- The filter box at the top acts on **faction names**.
- The page lists factions, and under each the alts who have a standing with it, each with the
  standing and the score:

      Ironforge                    Alt1    Friendly (1300/6000)
                                   Alt3    Exalted (…)
                                   Alt15   Honored (…)

- **Two levels, because the list can be long.** Three alts are shown under a faction; where
  there are more, the third is followed by **"n more"**, and clicking that drills down to the
  rest.
- The realm, class and name filters at the top act on **the list of alts**, in this view too.
- An alt on a realm other than the logged-in character's carries its realm, as everywhere else.

**What exists to build on:** the gathering is already written - `Family_UI/Character.lua` walks
every member and every sibling and groups their reputations by faction id. What changes is the
drawing: rows become faction-plus-people rather than faction-plus-best, and the panel grows a
drill-down of the kind the professions search already has (`UI.__openCrafters`).

**The realm rule was settled 2026-09-05 and is no longer a question here.** A name carries its
realm whenever the character is not on the realm being played, because names are unique per
realm and not per realm group - one account with alts on two realms of a group already has two
characters who can mail each other and are not the same person. Panels that segment by realm,
like the overview, are the exception and say it in their headings instead. Built the same day;
`docs/DECISIONS.md` carries it.

**Received:** 2026-09-05, from Alberto.

---

## 13. The possessions search across the family: whose, how long, and in what order

**Received:** 2026-09-05, from Alberto, with a screenshot of *Possessions / Whole family*
searching `cloth` - twenty lines, the filter row working, and three things wrong with the list
under it.

**Whose it is.** A character belonging to a linked family is drawn with its bare name, exactly
like one of ours. The data is already there and already labelled: `Family/Index.lua:227` puts
`familyName = Wide:Called(link)` on every owner it returns, and the item tooltip already draws
it - `Family_UI/Tooltip.lua:105` reads *Rolando |cff9d9d9dof Faraway|r* through the string
`L["%s |cff9d9d9dof %s|r"]`. The panel is the one place that has the field and ignores it. It is
the same reason the tooltip gives: a count against a name is read as *I can go and get that*,
and for somebody else's character that is not true.

**How long a name may be.** The guild bank row shows it: `Loch Modan Yachting Club-...` is cut,
because `Family_UI/Contents.lua:684` writes the raw guild key - which is `Name-Realm` - into a
font string 160 pixels wide with `NoWrap` on it. Adding *of Faraway* to the character rows makes
the same column worse.

Two things are worth separating here. The realm on a guild key is the settled realm rule not
being applied: a guild on the realm being played should not be carrying its realm at all, and
dropping it wins back most of the width for nothing. What is left after that is a genuine
sharing problem between three columns - item name, who, where - and the room they get is three
constants, `260`, `160` and `220`, in `Contents.lua`.

**In what order.** There is none to choose. `Index:Owners` sorts owners by how many they hold
and then by name, inside an item order that comes from the search - so the list is by item, and
a family wanting *what does Gulliver have* has to read down the page for the name. Asked for:
by item and by character. The nearest precedent is the professions panel's sort bar
(`Family_UI/Professions.lua` `ORDERS`), which is a row of buttons and a note saying what the
order means - not the summary's column headings, because this list has no headings.

**And the professions search wants the same ordering**, asked 2026-09-05 in the same breath.
That panel has a sort bar already - `ORDERS`, with a caption saying what each order means - and
the whole-family search deliberately puts it away, leaving `Family/Recipes.lua`'s own order,
which is by name.

**Done 2026-09-05.** A second `FAMILY_ORDERS` on the same bar - by name, by profession, by how
many of the family can make it - with both rows of buttons built once and shown by mode.

**Why re-enabling the old bar was not the answer, measured 2026-09-05.** All three of its orders read
fields the whole-family rows do not have: `Family/Recipes.lua` builds each row of that search as
`name, id, profession, icon, spellID, itemID, members, listed` - no `difficulty`, no `minSkill`,
no item level. Those are properties of a recipe *as one member sees it*, and across forty
members a recipe has forty of them. So the work is a second set of orders that mean something
about the family's answer rather than about one character's: by recipe name, by profession, and
by how many of them can make it. Which is new strings and a second `ORDERS`, not a `Show()`.

*The caption that was left behind when those buttons were hidden is fixed and is not part of
this - 2026-09-05, `bc69b0b`.*

**How many crafters a row can name is already settled and needs nothing.** Asked 2026-09-05:
what happens when ten alts can make one recipe. Four are named with their skill, the rest
become `+6`, and the row unfolds into one line each when clicked - `Family_UI/Professions.lua`
around the `spare` count and `UI.__openCrafters`. Guild crafters get three by the same rule. The
comment there says why: the line does not wrap, and eight names ran off the edge mid-name, which
lost the count as well as the names.

**Whose it is, and how long a name may be: done 2026-09-05.** `UI:GuildLabel` and the family
after the character's name, with forty pixels moved from the item column to pay for both and a
gate that adds the three columns up out of the panel's source.

**The ordering on possessions: done 2026-09-05.** By item, by character, or by how many, on a
sort bar built like the professions panel's. Left: the same on professions, which needs its own
set of orders for the reason above.

The possessions three were one slice: they are all the same list, and doing the
ordering without the naming would mean laying that column out twice.

---

## Owed to ourselves, not asked for

This page is for requests, and these are not — they are debts this session took on knowingly.
They are here so that there is one place to look rather than two.

### The harness cannot tell two panels' text apart — PAID 2026-09-05

`visibleText` in `tests/Harness.lua` sweeps every font string in the client. Several panels are
built, none is hidden in a way a check can see, and so "this word is not on screen" is answered
by the word being on a screen nobody is looking at.

It bit three times on 2026-09-04: a check written for the character panel's class filter that
had silently moved to the summary's (L-041), the reputation filter box that was typed into on
the wrong build of the panel, and lockpicking - where three checks were written, all three
passed for the wrong reason, and the honest end was to delete them and write down that the
property is guarded and not pinned.

Entries 9, 10 and 12 are all panels. This is worth closing before them.

**Closed.** `onScreen` walks the whole chain and is now the one rule; `visibleText` uses it, and
`drawnText` is new for checks about a panel rather than about the screen. Sharpening it found a
check that had been wrong for longer than a day - the summary writes a letter's sender as
*Auction House* and the check asked for *Auctioneer*, passing on the development icon sheet -
and three that were reading a window the harness never showed. L-046.

### Two characters of one name on two realms are one character to `Comm` — PAID 2026-09-05

`nameKey` strips the realm, so `Rolando-Thunderstrike` and `Rolando-Fire Maw` are the same key
everywhere in `Family/Comm.lua`: `SameName`, the absent list, the queue's abandonment, and now
the filter that swallows the client's *no player named* complaint.

A linked family spanning two realms can hold two characters of one name, and so can a link
plus our own family. Then one refusal marks both absent, and messages queued for the one who
**is** online are abandoned with the one who is not.

Asked by Alberto 2026-09-05, while checking whether the client's complaint carries a realm.

**The filter is not the part that suffers, and saying it was got this backwards.** Hiding needs
no attribution: two Rolandos produce two complaints, both of them caused by Family's own
whispering, and hiding both is right whichever is which. What needs attribution is the listener
that has been there since long before the filter - `CHAT_MSG_SYSTEM` in `Comm.lua` marks the
name **absent** and abandons everything queued for it. A refusal about one Rolando drops the
queue for the other, who may be online. That is the bug.

**And they really can both be online.** A family - ours or a linked one - is a person's
characters, not an account's, so nothing stops the two Rolandos being played from two accounts
at the same moment. The first reading of this assumed the collapse only ever confused an
offline character with an offline character; it does not. Three things follow from one refusal:

- `Wide.lua:435` - `reachableName` skips any candidate `Comm:Absent` answers for, so for
  `ABSENT_FOR` (60s, `Comm.lua:399`) the Rolando who is logged in is unreachable, and the
  family is told nobody is online while somebody is sitting in front of that character.
- `Wide.lua:641` - the absent listener attributes the refusal through `SameName`, so it lands
  on **every** link holding any Rolando, and each of them moves on to its next name.
- `Comm.lua:431` - `Present` collapses the same way in the other direction. Hearing from one
  Rolando lets the queue skip its canary (`Comm.lua:207`) when writing to the other, who was
  never heard from.

**The probe no longer gates the design.** `whispered` already holds what Family addressed and
when; keyed on the full target it also holds *which* Rolando, and the window is 15 seconds. So:
one Rolando addressed inside the window means the refusal is attributable exactly, whatever
form the client echoes back; two means it is genuinely undecidable and §2.2 says mark neither.
Both branches fall out of the same structure, and the probe only widens the first one.

Which makes the shape of the fix clear: **the collapse belongs to the filter and to nothing
else.** Its comment at `Comm.lua:120` says it is keyed "the way every other name in this file
is keyed" - that sameness is the fault. The filter should drop the realm on purpose, because
it is matching a bare name the client chose; `absent`, `AbandonTo`, `reachableName` and
`Present` should all carry the realm, because they are answering about a character.

Narrowing `nameKey` touches the queue, the absent list and `SameName`, which is why this is
written down rather than done in passing.

**Paid 2026-09-05, and the shape held.** `nameKey` became two: `baseKey`, which the filter uses
because it is matching a name the client chose, and `fullKey`, which `absent`, `AbandonTo`,
`Absent`, `Present` and the queue's canary use because they are answering about a character.
`whispered` keeps the bare name as its key and the full target underneath, which is what lets a
bare complaint be resolved by what Family addressed rather than by the string. `SameName`
answers on what both sides know - strict once both carry a realm - so `Family/Wide.lua` stopped
attributing a refusal to every link holding a namesake without being touched.

Nine mutations, every one caught. The seventh caught a check of my own that was passing on the
fallback rather than on the resolution, because the fixture's realm was the realm the harness
plays on; L-049.

### Three probes are out and unanswered

Handed over 2026-09-04, needed before their entries can start:

- **Entry 9** — whether the client will name a hunter's stabled pets while the stable is shut.
- **Entry 10** — whether the warlock demon-ability tab exists without the demon summoned.
- **Entry 2** — whether a tooltip can be redrawn while a modifier is held.
- ~~**The complaint above** — whether the client's *no player named* message carries the realm
  when the whisper was addressed with one.~~ **No longer gates anything, 2026-09-05.** The
  refusal is attributed from what Family addressed inside the window instead: one character of
  that name whispered decides it whatever form the client sends back, two decides nothing. An
  answer would widen the first case and is not needed for either.
