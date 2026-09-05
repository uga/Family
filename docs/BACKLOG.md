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

## 1. Wide Family: quest sharing, verified end to end — DONE 2026-09-05

**Asked:** check that quest sharing works across a Wide Family link.

**Today:** `quests` is a real category — `Family/Wide.lua` `CATEGORIES` carries the `quests`
payload and the `questCount` meta, so the data crosses. What is unverified is the other half:
whether a linked family's quests are *shown* anywhere, and whether a sibling's quest count
reaches the panels that display quests.

**Shape:** a check, not a feature. If the data crosses and nothing draws it, that is the gap.

**And that is exactly what it was.** The data crossed and nothing drew it: `UI:QuestLines` asked
`Family.Database:Payload`, which has never heard of a borrowed key, so a shared character's
Quests section said *Nothing recorded for this member* with the log in memory. Asking whether it
was a class found two more - the summary's letter unfold and the tooltip's maker block - and all
three failed into a sentence Family says on purpose, which is why none had been reported. L-052.

Two of the three are now drawn end to end in the harness. The third is below.

---

## 2. A recipe item's tooltip, both ways — DONE 2026-09-05

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

**Probed 2026-09-05, and it is a step rather than the answer.** Run with a tooltip up, on Era
and on TBC:

    /run print(GameTooltip:IsShown(), GameTooltip:GetOwner()
        and GameTooltip:GetOwner():GetName())

    true  BagnonContainerItem24

So while a tooltip is up the client will say **that it is up and what it is anchored to**, and
the owner is reachable and has a name - here another addon's bag button, which is worth
noticing on its own: whatever redraws this has to re-anchor to a frame Family did not create
and does not control.

**What is still unknown is the redraw.** Knowing the owner is what makes a redraw *possible*;
whether calling `SetOwner` and `SetHibItem` again while the mouse has not moved actually
repaints, rather than flickering or closing, is the thing that decides feature from trick. The
next probe is to do it and look:

    /run local o = GameTooltip:GetOwner() GameTooltip:SetOwner(o, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("|Hitem:2589|h") GameTooltip:Show()

With the mouse held still over a bag item. If the tooltip changes to Linen Cloth without the
pointer moving, the modifier can do the same thing.

**That probe was wrong and errored, 2026-09-05.** Two faults, both mine, and the second is the
interesting one.

`GetOwner()` came back nil - *Usage: GameTooltip:SetOwner(region)* - because typing `/run` puts
the cursor in the chat box and the mouse is no longer over anything, so there is no owner left
to re-use. And `|Hitem:2589|h` does not survive the chat box: the error's own `msg` shows the
bar doubled to `||`, because a typed pipe is escaped. `SetHyperlink("item:2589")` needs no bars
at all.

Underneath both: **this cannot be measured from a command line**, because the gesture being
measured is *hold the mouse still and press a key*, and reaching a command line means moving
it. So it has to be armed first and triggered after:

    /run local f=CreateFrame("Frame") f:RegisterEvent("MODIFIER_STATE_CHANGED")
        f:SetScript("OnEvent",function(_,_,k,d) local o=GameTooltip:GetOwner()
        if d==1 and o then GameTooltip:SetOwner(o,"ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:2589") GameTooltip:Show()
        print("redrawn onto",o:GetName()) end end)
        print("armed: hover an item, then press ctrl")

Then hover a bag item and press CTRL without moving.

**Answered 2026-09-05: it repaints, and then the owner paints over it.** Linen Cloth appeared
for a moment and the original came straight back. So the client is willing - a tooltip *can* be
redrawn with the pointer held still, which was the whole unknown - and what undoes it is the
frame that owns the tooltip setting it again on its own account.

Which settles the shape of the feature rather than blocking it: **Family must not set the
tooltip itself, it must make the owner set it** and let its existing `OnTooltipSetItem` hook add
the second reading during that repaint. Fighting the owner is a fight Family loses every time,
and on somebody else's bag addon it is not even Family's frame to fight over.

Next, and the last thing this entry needs before it can be built:

    /run local g,f=GameTooltip,CreateFrame("Frame")
        f:RegisterEvent("MODIFIER_STATE_CHANGED") f:SetScript("OnEvent",function()
        local o=g:GetOwner() local s=o and o:GetScript("OnEnter") if s then s(o) end end)

That one did nothing: this owner does not go through `OnEnter`.

**Answered 2026-09-05, and the entry is unblocked.** Three things were measured, in this order:

1. A forced `SetHyperlink` to a *different* item repaints with the pointer held still, and is
   then put back.
2. Hooking `OnTooltipSetItem` and holding still over **a bag item**, the hook fires over and
   over: that owner repaints on its own, every frame or close to it.

   The first reading of this said the opposite, and it was wrong because the pointer was not
   over a bag item at all. Corrected the same hour, and the correction changes the explanation
   rather than the answer: what put our forced change back was not the owner *reacting* to
   anything, it was simply its next repaint arriving. Which also means how often a tooltip
   repaints is a fact about whoever owns it, not about the client - so a design that leans on
   it would work over Bagnon's bags and not over a frame that paints once.
3. Re-setting **the same** item on `MODIFIER_STATE_CHANGED` repaints and *stays*:

        /run local g,f=GameTooltip,CreateFrame("Frame")
            f:RegisterEvent("MODIFIER_STATE_CHANGED") f:SetScript("OnEvent",function()
            local _,l=g:GetItem() if l then g:SetHyperlink(l) end end)

**So the shape is: never replace what the tooltip is showing - ask it to show the same thing
again, and let Family's existing `OnTooltipSetItem` hook decide which reading to add.** The
owner has nothing to correct because nothing it cares about changed, and Family does not have to
own a frame it did not create.

And it is the right shape whichever kind of owner is underneath. Where the owner repaints on its
own the hook would run anyway and the re-set merely coincides with one of its repaints; where it
paints once, the re-set is the only thing that makes the reading change at all. Leaning on the
owner's repainting would have worked on the bags it was measured over and nowhere else.

---

## 3. Filters and sorting on every panel that lists characters — DONE 2026-09-05

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

**Done 2026-09-05.** The character panel asks the widget for its bar, and the widget grew an
optional `population` so it can offer the realms and classes of the siblings this panel draws
beside our own. Which leaves the summary as the last panel with a filter bar of its own.

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

**Slice four — a whole-family mode for Quests. Done 2026-09-05.** A quest and the people on it,
three at a time, built the way the reputations view is. It had none today. The parallel is the
professions panel's family mode, which searches recipes across everybody: here it is *which
members have this quest*, and the filters follow from that.

**Abilities & Talents is out**, said 2026-09-05 when it had been in the same sentence the day
it was asked: it needs no whole-family reading and therefore no filters. Which is the right
answer - a talent tree is one character's arrangement of points and means nothing averaged over
forty, and the spellbook half is already reachable per member.

**Professions sorted by that profession's skill: done 2026-09-05**, and it needed nothing new -
only the two halves joined. `Summary.lua` had been carrying the reason it could not be built:
sorting a rank with no profession named would sort the rank of whichever came first
alphabetically, *which answers nobody*, and the control to name one with was slice three's. Slice
three brought the narrowing picker. So with a profession chosen the column orders by that
profession's rank and is **headed with its name**; with none chosen it is headed *Professions*
and orders by the word, which is the direction that stops the rule being written as *always sort
by rank*.

**The refactor is done, 2026-09-05, and entry 3 is closed with it.** The summary asks
`UI:CreateMemberFilters` for its class picker and level boxes; its search box stays its own,
which is the widget's own rule - every panel has one and no two of them search the same thing.

It needed one thing added to the widget, and that was measured rather than preferred: **a bar
without the realm picker.** The summary's row already carries a search box, the set's own
narrowing picker and the count of what is hidden, and a picker 130 wide takes it past the 740
the row has - the mutation that puts it back reports the row 36 pixels over. It costs the
summary nothing it had: rows there are grouped under realm headings, so which realm a member is
on is already on the screen.

The picker is **not created** rather than created and hidden. A hidden control still answers to
a click, and the harness proved it at once - a check that opens the character panel's realm list
by the words on it found the summary's invisible one first.

The level boxes keep the global names they had, pointed at the widget's own. That is what lets
every check written before this drive the new bar untouched, which is the best evidence a
refactor can produce.

**Crafting filtered by cooldown and profession: done 2026-09-05**, and the two turned out to be
one list rather than two controls. A timer several recipes share is headed by its profession -
alchemy's always is, the client putting every transmute on one - and a profession with exactly
one timed recipe is headed by the recipe, so *Alchemy* and *Mooncloth* are offered side by side
and each is the widest true thing about the timer under it. Which also settles the room: the
filter row holds one narrowing picker and there is no width for a second, measured rather than
guessed.

The choice cuts the **columns** as well as the rows, and that is the half worth having. This is
the only set that admits to hiding columns for want of room - the note under the table says how
many - so a filter that narrowed the members and left every heading up would have answered the
easy half of the question.

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

**Probed 2026-09-05, and the answer is half an answer.** Run on Era and on TBC:

    /run print(GetNumStablePets and GetNumStablePets() or "no stable api")
        for i=0,4 do local n=GetStablePetInfo and select(1,GetStablePetInfo(i))
        print(i,tostring(n)) end

- `GetNumStablePets` **does not exist** on either client - both answered *no stable api*. So
  how many pets are in a stable is not a question this call can be asked, and the count has to
  come from walking the slots until they run out.
- `GetStablePetInfo` **does** exist and **does** answer with the stable shut, which was the
  question. Era answered for slots 0, 1, 2 and 3 and nothing for 4; TBC answered for 0, 1 and
  3 and nothing for 2 or 4 - so a nil slot is a gap rather than the end of the list, and
  walking has to run the whole range rather than stop at the first empty one.

**What it does not yet say is whether the pets are named.** The probe read `select(1, ...)`,
and the first return of `GetStablePetInfo` is the **icon**: 132189, 132192, 132203 on Era and
132194, 132192 on TBC are texture ids, not names. The name is the second return. So this is
still owed, and it is one line:

    /run for i=0,4 do local icon,name,level,family,loyalty = GetStablePetInfo(i)
        print(i, tostring(name), tostring(level), tostring(family)) end

Reading the wrong return and reporting it as a name would have been the whole entry built on a
number.

**Answered 2026-09-05, and the entry is unblocked.** The names, levels and families all come back
with the stable shut - see *A hunter's stable, and a warlock's demon* in
[`DATASOURCES.md`](DATASOURCES.md) for the readings on both clients. Two things in the answer
shape whatever is built:

- **Index 0 and index 1 are the same pet.** A walk from 0 to 4 lists one pet twice, on both
  clients. The list has to be de-duplicated.
- **There is no id in the answer at all** - icon, name, level, family. A pet is the one thing
  Family would store under a name, and the name is the player's own word rather than the game's,
  so §2.1 has nothing to be applied to here rather than being set aside.

What is still not measured is the **abilities** half of this entry, which is the other question:
a hunter's pet spells are read the way a warlock's are, and entry 10 has just established that
that only answers while the creature is out.

---

## 10. Warlocks: the per-demon abilities known

**Asked:** read which demon-specific abilities a warlock has learned.

**Today:** not measured. Same shape as entry 9 and probably the same scanner, which is why the
two are written next to each other: both are "what does this class know that is filed under a
creature rather than under the character".

**Received:** 2026-09-04, from Alberto.

**Probed 2026-09-05, and it answers the question by not containing one.** Run on a warlock, on
Era and on TBC:

    /run for i=1,GetNumSpellTabs() do local n,_,o,c=GetSpellTabInfo(i) print(i,n,o,c) end

    Era   1 General 0 14   2 Affliction 14 59   3 Demonology 73 46   4 Destruction 121 27
    TBC   1 General 0 11   2 Affliction 11 47   3 Demonology 58 41   4 Destruction 99 24

Four tabs, and every one of them is the character's own: General and the three talent trees.
**There is no demon tab in the spell tabs at all**, summoned or not - *Demonology* is the
warlock's own tree and not the demon's book, and reading it would answer a different question
from the one this entry asks.

So the spell tabs are the wrong door. What is left to probe is the pet book, which on these
clients is reached with `HasPetSpells()` and the pet book type rather than through
`GetSpellTabInfo` - and whether **that** answers with no demon out is the question entry 9's
probe answered for the stable. Owed, and it is:

    /run local n, texture = HasPetSpells() print(tostring(n), tostring(texture))

Run it once with a demon summoned and once without, because the difference between the two
answers is the whole entry.

**Answered 2026-09-05, and the difference is the whole entry.** Identical on Era and Burning
Crusade: `4  DEMON` with a demon summoned, and `nil  nil` with none.

So the demon's book cannot be read on demand. Family can only record a demon's abilities at the
moment that demon is out, and a record of all of them is something it accumulates over time
rather than reads in one go - the same shape as a profession's recipe list, which is only
readable while its window is open, and which Family already handles that way.

That is a constraint rather than an obstacle, and it decides the design: the scanner watches for
a pet being summoned rather than being asked. It also settles what the panel may say about a
warlock whose imp has never been out - **nothing**, and §2.2 says nothing rather than none.

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

## 12. The whole-family reputations view, as it was actually asked for — DONE 2026-09-05

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

**Built the same day.** One thing in the ask was read rather than asked about, and it is worth
saying which: the bullets say both that the filter box acts on faction names and that *the
realm, class and name filters* act on the list of alts. This panel has one box, and the first
bullet says outright what it is for - so the box narrows factions, realm and class narrow alts,
and the member-name filter is the one this panel does not have yet. It arrives with the
migration onto `UI:CreateMemberFilters` in entry 3, which is where a fourth copy of a filter bar
stops being built.

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

### A sibling's crafting cooldowns: the path works, the data was not arriving — ANSWERED 2026-09-05

Reported from play 2026-09-05, with two screenshots: the summary's professions set lists a
linked family's six characters, one of them an alchemist, and the crafting set lists only our
own three.

**Measured, and every step of the path is right.** `Family/Wide.lua` `offering` copies
`craftCooldowns`, `cooldownItems` and `itemCooldowns` out of the meta for any member whose
`professions` grant is on; `Wide:Siblings` passes a borrowed `meta` through untouched;
`gatherSiblings` in `Family_UI/Summary.lua` applies the crafting set's `only` to that meta;
and `Cooldowns:Crafting` reads `meta.craftCooldowns` with no ownership test in the way.

**Nothing covered it, and that was the real gap.** There were checks that the field is sent and
checks that our own cooldowns are drawn, and none that a *borrowed* one reaches the set that
draws only members who have one. Written 2026-09-05: a link whose sibling carries a cooldown now
has to appear on that set, and a mutation that stops gathering siblings or stops reading the
field fails it.

**So the remaining explanation is the sender.** The three fields were folded into the
`professions` grant on 2026-09-04, and a linked family running a Family older than that sends
`skills` and not the cooldowns - the same grant, fewer fields. Handed over as a probe rather
than guessed at:

    /run for _,m in ipairs(Family.Wide:Siblings()) do print(m.memberKey,
        m.meta.craftCooldowns and #m.meta.craftCooldowns or "none",
        m.meta.skills and "skills" or "no skills") end

Skills present and cooldowns absent says it is their build. Both absent says the grant is not on
for that member. Cooldowns present says the fault is somewhere this entry has not looked.

**Answered the same day.** All six siblings came back `none skills` - the grant is on and the
fields are not in it. So it is the sender's build, and there is nothing to fix here.

**One thing worth saying out loud, because Alberto's own reading of it was that the other family
had not granted the cooldowns.** There is nothing for them to grant. The three fields live inside
the `professions` category, which is why `skills` arrive from the same consent - the note at
`Family/Wide.lua` line 52 says a link that granted Professions starts sending them at the next
exchange without being asked again. The other side has to **update Family**, not tick anything.
That distinction is the difference between a message that fixes it and one that sends somebody
looking for a box that does not exist.

---

### Two things about the summary's letter unfold that no check reaches — PAID 2026-09-05

**The fold.** `UI:FoldEverything` runs every registered folder and the harness counts them, so a
panel that never registered one is caught - but nothing pins that the summary's folder clears
the right thing, because `openMail` and `openBoon` are file locals in `Family_UI/Summary.lua`.

**And the read.** The same unfold was asking `Family.Database:Payload` for a member whose key may
be borrowed, so a sibling's letters drew none (L-052). That is fixed, and the mutation putting it
back fails nothing.

Both want the same thing: a check that finds the mail figure on a drawn row and clicks it.
Nothing in the harness does that yet, and until it does these two are covered by reading rather
than by measuring.

**Not to be closed with a check that reads the panel's source and calls it proof.** There is one
of those in this file already, about this same unfold, and all it says is that a line of code
exists.

Written down 2026-09-05.

**Paid the same day, and the condition above is what shaped it.** Nothing reads `openMail` or
`openBoon`, because nothing outside `Summary.lua` can: the way in is the rows they cause to be
drawn. So the check finds the figure on a drawn row - by what the row carries, never by where it
sits in `frames`, which grows - clicks it, counts the rows up, folds everything, and counts them
back down. Sixteen checks in two blocks: *the letters, put away with everything else* and *a
linked family's letters, unfolded on the summary*. No addon code changed.

Four mutations, and the fourth is the one worth recording. Deleting the panel's folder
registration outright left *the summary has a folder of its own to run* green, because
`FoldEverything` counts every panel's folders and three others had registered one - so that
check was deleted rather than kept beside the ones that work. What pins the two locals being
two is the boon: clearing only `openMail` fails exactly one check, and it is the boon's.

The third mutation puts L-052 back - `Family.Database:Payload` for a borrowed key - and fails
three. That was the site this section called covered by reading rather than by measuring, and it
is the last of the three.

---

### What a tooltip lane leaves behind when the client will not answer — ANSWERED 2026-09-05

Measured rather than guessed, after the guess had already been made once:

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_CURSOR") t:ClearLines()
        t:SetHyperlink("quest:999999:60")
        print(t:NumLines(), t:IsShown(), t:GetOwner() ~= nil)

    0  false  false

So a declined link is not merely silent: it **hides the tooltip and drops the owner**, and
anything written afterwards goes nowhere. The stub models that now, which is what makes the
fallback's own `SetOwner` checkable instead of a precaution nobody could measure.

**And measuring it found the real fault, which was not the owner at all.** The quest branch of
the character panel's tooltip resolver handed over the id and **not the row's fallback lines**,
so a quest the client will not describe had nothing to fall back to and the tooltip was hidden.
That had been true since the branch was written; it only became visible when the lane started
asking in a form the client sometimes answers, because before that it never answered for
anything and every quest row was equally blank.

---

### Three probes are out — all three answered 2026-09-05

Handed over 2026-09-04, needed before their entries can start:

- ~~**Entry 9** — whether the client will name a hunter's stabled pets while the stable is
  shut.~~ **Answered 2026-09-05: yes**, with names, levels and families, and with slot 0
  repeating slot 1.
- ~~**Entry 10** — whether the warlock demon-ability tab exists without the demon summoned.~~
  **Answered 2026-09-05: no.** `HasPetSpells()` is `nil` with no demon out and `4, DEMON` with
  one, on both clients.
- ~~**Entry 2** — whether a tooltip can be redrawn while a modifier is held.~~ **Answered
  2026-09-05: yes**, and the entry shipped. What the answer left out cost a day afterwards: the
  *event* it was built on does not arrive while a search box has the keyboard, so the swap was
  dead on every whole-family reading. L-056.
- ~~**The complaint above** — whether the client's *no player named* message carries the realm
  when the whisper was addressed with one.~~ **No longer gates anything, 2026-09-05.** The
  refusal is attributed from what Family addressed inside the window instead: one character of
  that name whispered decides it whatever form the client sends back, two decides nothing. An
  answer would widen the first case and is not needed for either.

---

## 14. Guild share: a filter for the guildmates who run Family — DONE 2026-09-05

**Received:** 2026-09-05, from Alberto.

**Asked:** on the Guild share panel, a filter at the top for *only the people running Family*.
A large guild is a long list, and most of it is people this panel can never exchange anything
with.

**Today:** not measured. Whether the panel already knows which guildmates have answered is the
first question and it is a read, not a guess - `Family/Guild.lua` records what has been heard
from whom, and the panel may or may not have that in its hand where the rows are drawn.

**Read 2026-09-05, and it does.** `Family_UI/Guild.lua` computes `RunsFamily` per row, right
where it draws them - it is what fills the dot green and what the status line counts. So this
was a switch and not a new fact.

**Done the same day.** A third button beside *Online only*, off by default: a guild of a hundred
with two users in it would otherwise open on two rows and look broken, and the ordinary state of
a guild is exactly that, which this panel says out loud in its status line.

One thing in it is not obvious and is checked on its own: **our own rows survive the filter.**
`RunsFamily` answers on what has been *heard*, and nothing is ever heard from our own
characters - the panel's own counting already treats the two apart for that reason. A filter
asking `RunsFamily` alone would hide the player's own row from a list of the people running
Family, which is the one row they can be certain about.

---

## 15. What is left to level: weapon skills, lockpicking, and a Skills set

**Received:** 2026-09-05, from Alberto.

**Asked:** lockpicking is read and shown on Abilities & Talents because it is an ability rather
than a profession, and that is right — but the reason for reading it is a question that is
bigger than lockpicking: *what have I still got to level on this character?* Across a family
that is four kinds of thing:

- **professions** — tracked, and the answer is already on *Overview / Professions*
- **weapon skills**, Unarmed included — not recorded
- **lockpicking**, rogues only — recorded
- **poisons**, rogues only — recorded, filed with the professions, which is what it behaves like

So: read the weapon skills too, and put those plus lockpicking on a Summary column set of their
own, **Skills**.

**Read 2026-09-05, and the recording half is nearly free.** `Scanners/Professions.lua` already
walks *every* skill line the client has — `GetNumSkillLines` and `GetSkillLineInfo`, from index
1 — and throws the weapon skills away on purpose: the comment at line 170 says what separates
them is that a profession can be given up and Swords cannot. So there is no new call to make and
no new window to open. What is missing is an identity to file them under: `tools/skill-lines.py`
takes category **11** (primary professions) and **7** (lockpicking, by id), and the weapon skills
are in neither. Which category they are in is a question for the SkillLine table on wago, not for
the client.

**Whether Mists has them at all is unmeasured** and is the same question lockpicking turned out
to have — weapon skills were taken out of the game in Cataclysm, so the 5.5.4 table probably
carries none, and the generator needs no rule for that (a build whose table has no line
contributes no name). Worth confirming from the table rather than remembered, exactly as
skill line 633 was.

**The space problem is real and here is the number.** The set buttons share one row:
`CHOOSER_WIDTH` 740 less `FACTION_ROOM` 76, divided by however many sets there are, less 2. With
the seven that exist that is **92 pixels each**, and `SET_BUTTON_MINIMUM` is **88** — so the row
is four pixels from its own floor. An eighth set makes it **81**, and `Summary.lua` prints a
complaint at the player when that happens, which it was built to do precisely so this could not
be discovered in a screenshot.

So an eighth set cannot simply be added. Three ways out, none of them chosen yet:

- **Two rows of set buttons.** The most room, and it costs a row of the table.
- **Fold Skills into an existing set.** *Professions* is the natural neighbour and is already the
  answer to the same question for professions; the cost is that its narrowing picker is about
  professions and would have to mean something else there.
- **Shorter labels.** Refused before, on 2026-09-04, and for a reason that has not changed: we
  would have to know the abbreviation for every category in every language.

---

## 16. Where each character logged out — DONE 2026-09-05

**Received:** 2026-09-05, from Alberto.

**Asked:** a *Where* column on Miscellaneous saying where each character was when they logged
out — zone and subzone, in the reader's own language. Possibly more useful than the Hearthstone
column beside it.

**Read 2026-09-05, and almost all of this is already built.** The hearthstone column solved the
identical problem last month and left the machinery behind:

- `Names:Area(id, recorded)` turns an area id into the reader's own language, and it is
  **measured on all three clients** rather than assumed — Era, Burning Crusade and Mists each
  answer in their own language and agree character-for-character with the table wago serves
  (`Names.lua` line 172 says so, and L-018 is why it was measured).
- `Names:AreaFor(word)` finds the id behind a word the client has just said, which is the only
  way there is: `GetBindLocation` returns a word and nothing returns its id.
- `meta.hearth` and `meta.hearthID` are stored as **word and id together**, and both already
  cross a Wide Family link in the `character` category.

So the shape is settled by precedent: record the word *and* the id, show the id through
`Names:Area` with the word as the fallback for a place this client has never heard of.

**The one thing that needs care is when.** `Names:AreaFor` counts ids upward to 20,000, and the
comment on it says outright that this is affordable *because a hearthstone moves rarely*. A zone
changes every time somebody walks anywhere, so the same lookup on every zone change would be a
different proposition entirely. Recording at **logout** — once a session — puts it back in the
class the ceiling was chosen for.

**Probed 2026-09-05: they both answer**, and what is written then reaches the saved variables -
*Searing Gorge* and *Pyrox Flats* came back from a live client. So it is a logout handler and
not a zone watcher, which is the same record for far less work.

**Built the same day.** Word and id together as the hearthstone does it, shown through
`Names:Area`, shared in the `character` category, and drawn on Miscellaneous.

Two things about it were decided by measurement rather than taste:

- **The row had no room.** The five Miscellaneous columns already used 580 of the 584 a row has
  beside the member column, so the width came out of them - Guild gives the most because
  `UI:GuildLabel` stopped drawing the realm on it. The check that every cell fits its column is
  what settled the numbers; two passes of it moved Guild back up and the hearthstone down.
- **Zone and subzone do not fit on one line**, said from play and true of far longer names than
  the example. So the set declares a taller row and the column declares that it may wrap. Both
  are per-set and both are applied on every row, because rows come from a pool and a cell that
  wrapped once would go on wrapping under every set after it.

**Left open:** the id costs a walk of every area id and is paid when the zone word has changed.
That guard is the hearthstone's, and it is weaker here - a hearthstone moves when somebody
decides to live somewhere else, and a logout zone changes far more often.
`C_Map.GetBestMapForUnit` would answer without a search and is worth probing if it ever shows.

---

## 17. A shared character's quests read in the language they were recorded in

**Received:** 2026-09-05, from Alberto, on being told it and asking whether I was sure.

**I was, and it is worth having verified rather than asserted.** Four reads, all in the same
session:

- `Family/Wide.lua:64` — the `quests` payload crosses a link.
- `Family/Scanners/Quests.lua` — each entry carries `title` and `category` as **words**, beside
  the quest `id` recorded since 2026-09-05.
- `Family_UI/Quests.lua` lines 143, 232 and 265 — the panel draws `quest.title` and the category
  exactly as recorded.
- `Family/Names.lua` has `Item`, `Spell`, `Recipe` and `Area`, and **no `Quest`**. There is
  nothing that could translate one.

So an English client shows a French sibling's quest list in French, title and zone heading both.
And the tooltip on that same row is in English, because that one goes through the quest id -
which makes the row and its own tooltip disagree on the same screen.

**The title is closeable and the category is harder.**

- A quest **has an id**, and `GetQuestLink(questID)` answers with a link carrying the title in
  the reader's own language. The scanner already makes that call - it is how the id is found in
  the first place - so a `Names:Quest(id, recorded)` is the same shape as `Names:Area` and would
  fall back to the word for a quest this client has never heard of.
- The **category is a zone name** and has no id stored beside it. `Names:AreaFor` could find one,
  but it walks every area id, and a quest log has one category per zone - so it would want doing
  once at scan time and storing, not at draw time.

**Not built.** Recorded here so the question is not asked a third time from memory, and because
it is the same class as the subzone (entry 16) with the opposite answer: that one cannot be
translated because no id exists, and this one can.

---

**Alberto's second question, 2026-09-05: does the whole-family view then show one quest as five,
one per language?** Read rather than answered from memory, and the answer is three answers.

**The grouping already knew.** `Family_UI/Character.lua` keys that view by `"id:" .. quest.id`
and falls back to `"title:"` only where there is no id, and the comment above it was written for
exactly this worry: *a title is a language: a family plays across clients, and the id is the same
word in all of them.* So a quest whose record carries an id is one row however many languages it
was recorded in.

**But ids are two days old.** Nothing recorded before 2026-09-05 has one, and a log only gains
them when it is re-read after that build. Until a character is played again its quests key by
title, and those really do split by language.

**And the zone headings split regardless.** The rows are grouped by `row.category`, which is a
word with no id beside it, so *Hellfire Peninsula* and *Péninsule des Flammes infernales* are two
headings holding one zone's quests. That is the same fault the row keys were fixed for, one level
up, and it is what makes the category half of this entry worth doing rather than optional.

**And the search matches the stored title**, so a quest can only be found by typing the language
it happened to be recorded in - which is the question *who is on this quest* asked in a language
the asker may not have.

So the shape of the work is settled by this: the title wants `Names:Quest(id, recorded)`, and the
category wants a **zone id recorded beside it at scan time**. The second is what actually fixes
the view; the first fixes what it is called.
