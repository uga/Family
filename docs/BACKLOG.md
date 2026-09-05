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

**Still open:** the per-panel filters and sorts. Overview by rested XP, money, last seen, free
bags, free bank and bags/bank seen; activity by mail, expiry and mail seen; professions filtered
by profession and sorted by that profession's skill; crafting by cooldown and profession; misc
by guild and hearthstone. And the same three filters on the character panel's other sections,
which has its own realm and class pickers already but not the level range.

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

**One thing to settle rather than assume.** The realm rule as asked is *different from the one
Family uses now*: today a name carries its realm when the **account** spans more than one realm
(`UI:AcrossRealms`, decided 2026-09-04), and what is asked here is when the alt's realm differs
from **the logged-in character's**. On a single-realm account the two agree. On an account
spread about they do not: today every name carries a realm, and the rule as asked would leave
the ones on your own realm bare. Worth one sentence from Alberto before building, because
changing it changes tooltips and search results too.

**Received:** 2026-09-05, from Alberto.

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

### Three probes are out and unanswered

Handed over 2026-09-04, needed before their entries can start:

- **Entry 9** — whether the client will name a hunter's stabled pets while the stable is shut.
- **Entry 10** — whether the warlock demon-ability tab exists without the demon summoned.
- **Entry 2** — whether a tooltip can be redrawn while a modifier is held.
