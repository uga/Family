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

Done so far in this batch: **1**, **2**, **3**, **4**, **6**, **7**, **8**, **11**, **12** and
**13**. Left before the release: **9**, **10**, then **5** in a build of its own.

*Corrected 2026-09-06.* This paragraph said **1**, **2**, the rest of **3**, **9** and **10** were
left, three days after all of 1, 2 and 3 had been finished and marked so in their own entries. It
was read as the list of what to do next and cost a session's opening on entry 13, which was
already built. A summary of entries that lives above the entries goes stale the turn one of them
is finished; this one is now a pointer to the headings and not a second copy of them.

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

## 13. The possessions search across the family: whose, how long, and in what order — DONE 2026-09-05

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

## 15. What is left to level: weapon skills, lockpicking, and a Skills set — DONE 2026-09-06

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

**The second of those three was taken on 2026-09-06 and this entry was not told.** The switch on
the professions set's filter row *is* "fold Skills into an existing set": the scanner records the
weapon skills, `Summary.lua`'s `weaponsOf` draws them, and pressing the switch puts the panel on
them. Lockpicking came back among the secondaries in the same week. So by the time this entry was
opened, the recording half and most of the showing half were built, and what stood between them and
the ask was the cost that option was predicted to have — written down here before it was paid.

**The predicted cost was real.** *"Its narrowing picker is about professions and would have to mean
something else there"* — it did not mean something else, it went on meaning professions: the
control beside the switch was captioned *Profession* over a table of weapon skills, offering trades
as a way to narrow a list of weapons. **Built 2026-09-06:** the picker follows the view. Its
caption, the choices it offers and the filter behind it are all the list on screen, the first
weapon column takes the chosen weapon's name as its heading, and clicking that heading orders the
family by that weapon's rank — which is what *what have I still got to level* was a question about
and what no panel could do until now.

**And the eighth set button is not wanted any more.** A *Skills* set would hold the weapon skills
and lockpicking, and this panel draws both. The 81-pixel arithmetic above still stands and is still
the reason a set cannot simply be added; nothing needs it.

**Two faults came out of the same measurement**, one shape twice. `narrow.passes` and `SORT.prof1`
both tested `not skill.class` — true of the list they were written against, and false from the day
lockpicking joined the secondaries. The picker offered *Lockpicking* and matched nobody with it, so
choosing it hid every rogue and said so in a count underneath; ordering by it answered nil for
every row, which reads as a heading that does not sort. Both fixed the same day, and the mutations
that put either back redden a check.

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

## 17. A shared character's quests read in the language they were recorded in — DONE 2026-09-05

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

**The category half is done, 2026-09-05.** The log carries a zone id per heading, both views name
the zone through `Names:Area`, and the whole-family view groups on that - so one zone is one
heading whatever language each record was written in. The check reproduces the case exactly: two
siblings, two languages, one zone, and the mutation that groups on the word again reports the two
headings side by side.

**And the walk that finds an id is now paid once for a place, ever.** Alberto's, on being shown
the arithmetic - a quest log is re-read as often as every fifteen seconds, holds six to ten zones,
and walking twenty thousand ids for each of them would be a hundred and sixty thousand questions
a minute. `Names:AreaFor` writes what it finds into `FamilyDB`, which is the only disk an addon
has, so it survives the session and belongs to the **account**: twenty alts share one answer for
one zone. A place the client does not have is remembered as absent too, or it would be walked for
on every scan for ever - which is the expensive half and the half nobody would notice.

That store is inside `AreaFor` and not beside any one caller, so the hearthstone and the logout
zone got it without being touched.

**The title is done too, the same day.** `Names:Quest(id, recorded)` is the same shape as
`Names:Area`: two routes tried and the answer read back - `C_QuestLog.GetTitleForQuestID` where a
build has it, then `GetQuestLink`, whose title is the part inside the brackets - and the recorded
word as the fallback. Both views use it.

**And the answer to what was left open is no**, measured the same day. The probe printed *nothing
at all*, which is itself the finding: `GetQuestLink` **raises** for a quest the client has no
data for rather than returning nothing, so the error landed before the `print` and a one-line
probe with two arguments said less than it looked like it would. `Family:TryCall` is what turns
that into a fallthrough rather than a broken panel. So the live routes reach only quests the
server has already described to this client - in practice, the ones in your own log.

Alberto then asked the right follow-up: *does wago not give us the titles from the id? and does
the current client not?* Both measured, in `DATASOURCES.md` under *A quest's title is not in the
client's tables at all*. **wago cannot**: `QuestV2` is served for all three pinned builds with
the columns `ID,UniqueBitFlag`, `Quest` and `QuestLine` are not tables there at all, and
`QuestInfo` is 166 bytes naming the *kinds* of quest. There is no file to ship - which is a
different answer from the hearthstone's, where 876 KB was a trade and this is no trade at all.

**So the answers are remembered instead, which is Alberto's own method from the areas store.**
Every quest any character on this account reads is written down by id in this client's words, by
the scanner that already holds both halves, and `Names:Quest` reads that before it asks anything.
A French player whose own alt has done *The Love Potion* then reads an English sibling's record
of it in French. Kept **per language**, unlike the areas store: that one is word to id so a
second language only adds keys, this one is id to word and would overwrite.

**And the floor was lower than it needed to be, which Alberto found the same hour.** A screenshot
of Family's own tooltip: a level 5 character hovering a sibling's level 58 quest, and the client
describing it **in French**. So *the client cannot name a quest it was never given* was wrong,
and the disproof had been on screen since `Tooltip.lua` started asking with
`SetHyperlink("quest:<id>:<level>")` the day before. Two calls failing had been read as the
client failing, when both need the quest to be in the player's own log and the tooltip does not
(L-057).

So the tooltip is the third route, after the store and the two direct calls, and the **level** is
half the question - a bare `quest:84` answers nought lines. Both panels pass `quest.level`
through. The store still earns its place and is what makes this affordable: one tooltip per quest
for the life of the account, rather than one per row per draw.

Now it covers every quest the client will describe, which is every real quest - not only what
this account has read.

**Closed, 2026-09-05.**

---

## 18. `GetZoneText` answers with a word that is not an area name — DONE 2026-09-05

**Found from play, 2026-09-05.** A character who logged out in Ironforge on an English client
kept reading *City of Ironforge* on a French one, while the quest headings beside it translated
correctly. Alberto's probe of the record settled which half was wrong:

    Eccebombo-PyrewoodVillage  City of Ironforge  Ironforge  id nil -> nil

So `Names:AreaFor` walked all twenty thousand ids and found nothing, and then remembered the word
as absent - correctly, because it is. The measurement is in `DATASOURCES.md` under *`GetZoneText`
does not answer with an area name*: Era's `AreaTable` has **no row containing "City of"** at all,
in any locale; Ironforge is area 1537, named `Ironforge` in both English and French; `UiMap`
calls it 1455 and `Map` does not mention it. Meanwhile `GetSubZoneText` in the same spot answered
`Ironforge`, which **is** area 1537 - so the two calls read different tables and only the
subzone's answer is an area name.

Every other caller of `AreaFor` is safe and that is why nothing else showed it: `GetBindLocation`
returns an area name, and a quest log's headings are area names. `GetZoneText` is the one source
that is not.

**Fixed, 2026-09-05, and the probe chose the route.** From Ironforge on French Era:

    GetZoneText()                      Cité d'Ironforge
    GetRealZoneText()                  Cité d'Ironforge
    GetSubZoneText()                   Ironforge
    C_Map.GetBestMapForUnit("player")  1455
    C_Map.GetMapInfo(1455).name        Ironforge

So `GetRealZoneText` is not a second chance - the same word, and that word is in no area table.
The map id is, and 1455 agrees with wago's `UiMap` character for character. `GetBestMapForUnit`
answers it with no search at all, which also **takes the twenty-thousand-id walk out of
`PLAYER_LOGOUT`** - the expensive half, spent looking for something that could not be found.

`mapID` is its own field and never `zoneID`, because a map id and an area id are different
numbering. The area id stays for records that already have one and for a build without the map
call.

And a rule came with it: **the recorded word wins where its language is the reader's own.** A
French client says *Cité d'Ironforge* where its own map is called *Ironforge*, so naming
everything from the id would make a player's own characters read less precisely than before.
`zoneLocale` is recorded and shared for that, and `Names:Where` is the one answer both the cell
and the search box ask.

**And it does not answer during `PLAYER_LOGOUT`**, which is the one thing that was left open and
is now measured - by shipping the live call, logging out in the Military Ward of Ironforge and
reading the record back: `Cité d'Ironforge  map nil  loc frFR`. There is no `/run` that reaches
that moment, because there is no frame left to print to.

So the map is read while playing - `PLAYER_ENTERING_WORLD` and the three `ZONE_CHANGED` events -
and the last answer is kept with the zone word it was the answer for. The logout handler tries the
live call first and falls back to the kept one only where that word matches the place it is
recording; where the player has moved since, the area id carries it as before.

**Still unmeasured:** whether `GetBestMapForUnit` exists on Burning Crusade and Mists. Guarded on
the symbol, and the area-id walk is the path where it is not.

Records already written keep the word they have until that character is played again.

---

**The route as it was written before the probe:** The decision row for entry 16 already
left this open in the other direction - *`C_Map.GetBestMapForUnit` would answer without a search*
- and it now looks like the fix rather than an optimisation, because a UiMapID is an id the
client will translate and needs no walk at all. `GetRealZoneText` is the other candidate and may
simply be the area name. Both, in one line, standing in Ironforge:

    /run local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local i = m and C_Map.GetMapInfo(m)
        print("zone[" .. tostring(GetZoneText()) .. "] real[" .. tostring(GetRealZoneText())
            .. "] sub[" .. tostring(GetSubZoneText()) .. "] map=" .. tostring(m)
            .. " name[" .. tostring(i and i.name) .. "]")

Two things the fix has to carry whichever route wins. A UiMapID is **not** an areaID, so it wants
a field and a naming call of its own rather than being written into `zoneID` where `Names:Area`
would look it up in the wrong table. And whatever is recorded has to answer **during
`PLAYER_LOGOUT`**, which is measured for `GetZoneText` and `GetSubZoneText` and is not measured
for the map API - if it does not, the value wants keeping during play and writing at logout.

---

## 19. A mount destroyed is not a permission lost — DONE 2026-09-06

**Named by Alberto on 2026-09-06, while the shape of the mount column was being chosen, and
deferred by him in the same sentence.**

The column answers *how fast can this character travel* by looking at what they can summon - the
mount spells they know and the mount items they carry. That is the right key, and the reasons are
in `addons/Family/Mounts.lua`: on Classic Era the riding skill is a permission whose value is
always 300, one character can hold several of them, and a paladin's or a warlock's mount teaches
no riding skill at all.

**But owning the mount is evidence of the permission, and losing it is not evidence of losing the
permission.** A character who earned tiger riding, bought a tiger and then destroyed it by mistake
may still buy another, and Family will say they are on foot.

Closing it means reading the riding skills as well and saying two things instead of one - *may
ride: tiger, ram* beside *travels at: on foot*. The skills are already scanned since 2026-09-06,
so the data is there; what is missing is the decision about how to draw two facts in one column's
width, which is the same question the icon overview is about.

**Built 2026-09-06.** The tooltip, not a column - the width was the whole obstacle and the
professions and misc rows had already settled where a fact goes when its cell has no room for it.
Hovering a member on Overview gives the speed and the riding skills they hold, so *earned tiger
riding, destroyed the tiger* is now distinguishable from *never learnt to ride*.

**Two things measured while building it that the entry above had slightly wrong.** The panel does
not say *on foot* for that character: `CELL.mount` returns an empty string, which says nothing,
which is honest as far as it goes. And the rank cannot be shown beside the permission the way the
entry's *may ride: tiger, ram* sketch implies a number might be - on Era every riding line sits at
300 and means nothing, and where the skill is the ladder the cell already reports what the rank
buys. `RidingLadder[300]` is 100%/280%, a rung from a game those Era numbers are not being read on.

**And a third answer the entry did not have**: a member whose bags have never been read. That is
neither a mount nor an empty stable, and the tooltip repeats the cell's dash rather than deciding
which of the two it is (§2.2). The first cut let it fall through and be reported as an empty
stable, and the check written for it is what said so.

---

## 20. On Mists the riding skill sets the speed, and Family reads the mount — DONE 2026-09-06

**Measured 2026-09-06**, from Alberto's question about whether Master Riding upgrades the mounts
you already own. It does, and `MountCapability` is why: on that build each row maps a required
riding skill to the aura that applies the speed, so the mount carries none of it.

| Riding skill | Ground | Air |
|---|---|---|
| 75 Apprentice | +60% | — |
| 150 Journeyman | +100% | — |
| 225 Expert | +100% | +150% |
| 300 Artisan | +100% | +280% |
| 375 Master | +100% | **+310%** |

`Mounts:Fastest` reads the mount, which is right on Classic Era and Burning Crusade and **wrong on
Mists**: a character there with Master Riding and an old 100% mount would be reported at whatever
that mount's own aura says rather than at 310%.

The fix is small and the data is already scanned: skill line 762's rank is recorded since riding
was added to the table the same day, so it is a lookup against the five rows above, chosen by
build.

**The first version of this entry gave a bad reason for not doing it** - *nobody in this family is
on Mists* - which confused Alberto's own characters with the people the addon is released to. Mists
is a shipped build and the harness has covered it since long before this: it puts that build in
force twice and reloads the panel under it, and one block runs against all three. Corrected here
rather than quietly, because a wrong reason for not doing something is worse than no reason.

**What is genuinely missing is one measurement, and the harness cannot supply it**: whether a live
Mists client still lists *Riding* among `GetSkillLineInfo`'s rows, and at what rank. The harness's
skill list is a fixture written by hand, so asking it that question would be asking my own guess -
which is the shape of L-037 and L-053 both, and the shape of three separate faults in the week this
was written.

**And there is no such thing as a 310% mount**, which is Alberto's question asked the other way
round. `MountTypeXCapability` settles it: a mount has a *type*, and the type is what holds the
ladder.

| Mount type | Mounts of it | Riding rungs it has |
|---|---|---|
| 230 (ground) | 291 | 75, 150 — **and no more** |
| 248 (flying) | 208 | 75, 150, 225, 300, 375 |
| 263 (special) | 16 | 75 … 375, with extra rows |

So a flying mount serves every rung: bought at Expert it flies at 150%, and the **same** mount
flies at 310% the day Master Riding is learned. Nothing is gated by being too fast for its owner,
and nothing has to be bought again. The mirror is true too and is the part worth remembering: a
ground mount tops out at Journeyman's 100% however high the riding skill goes, because its type has
no rung above 150.

**Which makes the fix two lookups and not one.** The rank alone is not enough - a character with
Master Riding and none but ground mounts flies at nothing - so it wants the mount's type as well.
`Mount.db2` carries `MountTypeID` against `SourceSpellID`, 526 rows on that build, so the shipped
table would gain a type per spell and the rank would do the rest.

**Built 2026-09-06**, once Alberto said he had a Mists client and measured on it. `Mounts:FromJournal`
reads `C_MountJournal` where there is one - keeping the rows whose fifth return is true, which is
*usable by this character* and already accounts for the rank - and multiplies possession by the
rung: the rank says how fast, the journal says whether there is anything to be that fast on and
whether any of it flies. The five rungs and the 225 mounts whose type can fly are generated by
`tools/mounts.py` from `MountCapability`, `MountTypeXCapability` and `Mount`.

Both halves of his question are checks now: the same mounts read *100%/150%* at Expert and
*100%/310%* at Master, and a character with nothing but a ground mount flies at nothing however
high the rank goes.

---

## 21. The check that every cell fits its column never draws a narrow window — DONE 2026-09-06

**Found from play 2026-09-06**, an hour after the Mount column shipped: a druid's `100%/150%` came
back cut off at `100%/1`, and the check that exists to catch exactly that had passed.

It passed honestly. It draws the panel at its full width, measures each cell against the width its
column *declares*, and nine characters at the harness's 6.5 pixels each is 58 against a column of
70. What it never does is draw the panel **narrower than the sum of its columns**, which is when
`UI:FitColumns` shrinks every one of them - and the cell that suffers is whichever carries the most
text, which was this one.

So the check measures the layout as designed and not the layout as squeezed, and every set on the
summary has the same blind spot.

**What closing it would take**: a second pass of the same loop with the window set narrow enough to
force the shrinking, and a rule for what "fits" means then - a column that has given up room is
allowed to clip its heading, so the test cannot simply be *nothing is wider than its column*.

Worked round at the time by making the cell shorter - one per cent sign for the pair rather than
two - and by giving the column eighteen more pixels out of Money. That is a smaller cell, not a
check.

**Built 2026-09-06, and the entry above has its own bug slightly wrong.** "Never draws the panel
narrower than the sum of its columns" reads as though a narrow window were the trigger. The window
is a fixed width and never changes. What shrinks a column is a **heading**: `UI:FitColumns` widens
any column too narrow for its own heading and takes the difference back from whatever is carrying
the most text. The Miscellaneous set's columns add up to exactly the row's budget, so that happens
in every language, including the one the widths were chosen in.

So the second pass does not narrow anything. Per set and per language it takes the columns as
drawn, asks `Family.L` for the heading that language would really use - it resolves through
`Family.locale` at lookup, so it can be asked without reloading - re-fits against the row's real
budget, and measures every cell of every member row against the width that came back.

**The rule this entry expected to be hard was not needed.** `shrinkToFit` never takes a column
below its own heading, so a heading always fits and it is only ever cells that give. "Every cell
fits its drawn width" is the whole rule.

**And it found a second blind spot immediately**, one this entry never suspected: the old check
filtered to `__width <= 130` to skip captions, and in doing so skipped every *column* wider than
130 - the ones carrying the most text. The guild column is 164, and *Loch Modan Yachting Club* was
running over the edge of it in a shipped build, in English. That cell is clipped now like the two
beside it, with the whole name on the row's tooltip and only where it is actually cut. L-060.

---

## 22. The item names are asked for again every session, and never written down — DONE 2026-09-06

**Agreed with Alberto on 2026-09-06, in design, and then not written down anywhere — which is
the reason this entry exists at all.** It has been carried in a conversation since, and a
conversation is not a file.

**Today.** Nothing on disk holds an item's name. Family persists two other name stores and
neither covers items:

- `FamilyDB.areas`, word to id, one store for every language — `Names.lua:277`. A second
  language only adds keys, so it needs no per-locale split.
- `FamilyDB.quests[locale][id]`, id to word, split by language *because* it is that way round —
  `Names.lua:334`, with the reason written beside it: a player who switched clients would
  otherwise read every quest in the language they left.

An item name is the same shape as a quest title — id to word — and has no store at all.
`UI:WarmRecipeNames(budget)` (`Slash.lua:800`) asks the client for a few ids per call from
login, which is what stopped the Professions panel freezing a cold client for ten seconds. It
warms **the client's own cache**, from nothing, every session.

**And the client's cache does not survive a relog.** Recorded here because the session that
built the warm-up claimed it did and was wrong: Alberto refused the claim from play — *la cache
sta su disco, ma evidentemente la cancelli ogni volta! Altrimenti perché uscendo dal gioco e
rientrando se la ricostruisce?* The warm-up runs from scratch at every login, which is exactly
the work this entry would stop repeating.

**The shape agreed.** `FamilyDB.itemNames[locale][itemID]`, written whenever the client answers.
Read back **only for the current locale**, and checked **item by item** rather than by trusting
the whole store: a player who switches language keeps the other languages inert on disk instead
of losing them. Alberto's judgement on the cost, in his words: the disk taken by a multilingual
dump is not a concern.

**Built 2026-09-06.** `FamilyDB.itemNames[locale] = { at = <build>, names = { [id] = word } }`.

**The ceiling was decided rather than deferred: there is none.** `FamilyDB.quests` is the same
shape and has none either.

**Measured properly on 2026-09-06**, after Alberto asked what happens to a user of his with
**210 characters** - three full realms at seventy each. The reasoning first written here said
the store is bounded by the family and that "forty alts fill it and it stops", which reached the
right conclusion by the wrong argument, and quoted the wrong table with it: 1,406 is
`RecipeMadeBy`, the products Family can name a maker for, where the warm-up asks about whatever
a scanned recipe *makes*.

**The store is keyed by item id, so it does not scale with characters at all.** Two hundred and
ten alts and four converge on the same ids: blacksmithing's recipes are the same recipes whoever
knows them. What bounds it is the game's own item table, not the account's:

| | ids | at 36 bytes a line |
|---|---|---|
| every item any recipe in any of the three builds makes | 2,647 | **98 KB** per language |
| every item in the whole Era client | 24,442 | 907 KB per language |

The first row is the real ceiling for the recipe half and it is reached only by a family that
knows every recipe in the game. The second is unreachable - it would need every item in the
client to have passed through a panel. Bags and bank add ids on top of the first row and overlap
heavily, since forty characters carry the same consumables.

So the answer for 210 characters is that this store costs them what it costs anybody: **under
a hundred kilobytes per language in practice.**

**Confirmed in play 2026-09-06**, which is the only place it could be: on the first login after
the deploy, opening Professions was slow the way it always was; on the second it opened at once.
That is the whole claim - the client's cache does not survive a relog and this one does.

**And it refreshes, which Alberto asked for while it was being written**: *il fatto di conoscere
la traduzione non ci deve impedire di accorgerci che dobbiamo rinfrescare il dato perché è
cambiato dall'origine.* He was right that the first draft could not. The client is asked before
the disk and overwrites it, but that only corrects items the client has loaded - and on a cold
client it has loaded almost none, which is the whole reason this store exists. So the store
carries the build it was written at and **a build it does not recognise empties it**, for the
language being played and no other. The build is the trigger rather than a timer because item
names live in the client's own data files: they change when the client changes and at no other
moment. It empties rather than marking each entry suspect because half a store that cannot say
which half is worse than none - the session after a patch then costs exactly what every session
costs today, which is the thing being replaced.

---

## 23. A specialisation's own picture, in place of its profession's — DONE 2026-09-06

**Received 2026-09-06, from Alberto, immediately after the branches reached the tooltip.**

**Asked:** where a character has taken a branch, the cell on *Professions* should draw the
branch's picture rather than the trade's — an Axesmith shows the Axesmith icon, not the generic
blacksmithing one. Alberto is compiling the icons for the three clients himself and asked that
nothing be built until that list arrives.

**Today.** `Family.Specialisations` holds 16 branch spells across 5 professions
(`addons/Family/Specialisations.lua`, generated), and a character's own are on
`meta.specialisations` since 2026-09-06. The cell's picture comes from
`Family.SkillLines[professionID(id)].icon` — one picture per skill line, with no room in that
table for a per-character one, so the branch's image would have to be chosen at draw time.

**Two things to settle before the list is worth acting on**, both raised with him the moment he
announced it:

- **The client may already answer.** `GetSpellInfo(spellID)` returns an icon as well as a name,
  and `Names:Spell` already receives it and drops it. If those sixteen icons are real rather
  than generic, the whole list is a screenshot of `tools/FamilyIconSheet` per client instead of
  a hand-compiled table — which is how the skill line pictures were settled, and for the same
  reason: a texture cannot be probed, but the sheet can be looked at.
- **A profession can carry two branches.** A blacksmith may be a Weaponsmith *and* a Master
  Axesmith, and both are recorded. Proposed: the more specific wins — Axesmith over Weaponsmith,
  being the branch taken second. Not decided; it is his call and it changes what the list needs
  to contain.

**Built 2026-09-06**, once the icons arrived. Both questions were answered by him: the list
made the icon sheet unnecessary, and the deeper branch covers the shallower - a Master Axesmith
draws the axe rather than the Weaponsmith they necessarily also are.

**What his list did not settle, and he said so himself:** the names in it were labels for icon
codes, not the game's names for the spells. Those came from wago's `SpellName` - see *Which
branch is which* in [`DATASOURCES.md`](DATASOURCES.md) - and it mattered: **17040 is Master
Hammersmith and 17041 is Master Axesmith**, the opposite of the obvious guess and the opposite
of what an earlier session had written into a test fixture from memory.

**Mists' cooking ways are not in this** and are entry 24.

**Confirmed in play 2026-09-06**, on Alberto's own client, and this is the part no harness
could have given: the sixteen file ids are pictures, and a picture cannot be probed - the client
hands back whatever path it was given, so a wrong id and a right one are the same answer from
inside. What was checked is that the branch cell draws the branch, that riding is gone from the
professions page's grey line, and that mining is not swept in with the gatherers. The mapping
being right rather than merely consistent - **17040 Master Hammersmith, 17041 Master Axesmith** -
rests on that look, not on the generator.

---

## 24. Mists' six cooking ways — SET ASIDE 2026-09-06

**Named 2026-09-06**, inside Alberto's icon list for entry 23: on Mists every branch of every
trade was removed except alchemy's, and cooking gained six of its own - Way of the Grill, Oven,
Steamer, Pot, Wok and Brew, with icons 629054 to 629059.

**They are a different mechanism from every other branch**, which is why they are here rather
than in entry 23. Measured in the cached tables at build 5.5.4.69078:

- They are **child skill lines**: `SkillLine` 975 to 980, `ParentSkillLineID` 185, category 9.
  They are the only rows on any of the three builds with a parent that is not a cooking rank.
- They are **not spells taught under a profession**. The only `SpellEffect` 47 rows under
  cooking are the Apprentice-to-Zen-Master chain, so the sieve that finds every other branch
  cannot see these and neither can the spellbook the others are read from.
- The spells that grant them exist - 124694, 125584, 125586, 125587, 125588 and 125589, by
  `SpellEffect` 118 naming 975 to 980 - but a skill-granting spell is normally the trainer's
  and is not kept in the book afterwards.

**So the first thing needed is a probe, not code**, and it is one line on a Mists cook:

    /run for i=1,GetNumSkillLines() do local n,h,_,r,_,_,m=GetSkillLineInfo(i)
        if not h then print(i,n,r,m) end end
    /run for _,s in ipairs({124694,125584,125586,125587,125588,125589}) do
        print(s, IsSpellKnown and IsSpellKnown(s), (GetSpellInfo(s))) end

If the ways come back from the **skill list** with a rank, they need no new mechanism at all:
`Scanners/Professions.lua` already walks every skill line, and what is missing is only their
names and pictures in the shipped table - `tools/skill-lines.py` takes category 11 and five
named ids, and 975 to 980 are in neither.

**And then a question about what a cell should show.** Every other branch is one per profession,
so replacing the trade's picture with the branch's is unambiguous. A cook can learn **all six**
ways, so there is nothing to replace cooking's picture with. Six extra cells, or a picture that
stands for "several", or leave cooking alone - undecided, and not decidable before the probe
says what is actually recorded.

**Set aside by Alberto on 2026-09-06**, the same day it was written: *lasciamo stare le Way di
Mists*. Left here rather than deleted because the measurement in it is the expensive part and
would otherwise be made twice.

---

## 25. The login warm-up walks every character, however many there are — DONE 2026-09-06

**Found 2026-09-06**, answering Alberto's question about a user with **210 characters** - three
realms at seventy each. It is not the item name store that suffers; it is the walk that fills
it, and this was true before that store existed.

**Measured, in `addons/Family_UI/Slash.lua`:**

- `UI:WarmRecipeNames` decodes **one member's payload per call**, deliberately, because
  decoding thirty at once is its own stall.
- The timer that drives it fires **once a second** until the queue is empty.

So the walk takes **one second per character**: about four seconds for a small family, and
**three and a half minutes for 210** - at every login.

**And it decodes them all whether or not there is anything to learn.** The decode happens before
the ids inside it can be looked at, so on the second session - when the names store already
holds every answer - 210 payloads are decoded to discover that nothing needs asking.

**They are also all held.** `Database:Payload` caches into `decoded[key]` and nothing ever
evicts it (`addons/Family/Database.lua:167`), so a warm-up that has walked the whole family has
every member's decoded payload in memory for the rest of the session. That is by design for a
family of forty; for 210 it is a number nobody has measured, and this session did not measure it
either - Lua's memory is not something this harness can weigh.

**What closing it would take.** Skipping the decode needs a way to tell, without decoding, that
a member has nothing new: the encoded payload is on disk as a string, so its length or a hash of
it is a candidate fingerprint - remembered per member beside the names store and cleared when
that store is cleared. That is a design, not a line, and it is worth doing only if the walk is
actually hurting somebody.

**Not built, and Alberto proposed a different answer on 2026-09-06**: rather than making the
walk cheaper, say that it is happening. *Potrebbe bastare un warning in occasione della prima
lettura.*

**Built as two lines, not a popup.** Family's two popups both ask a question and wait for an
answer; one that only informs is a modal to dismiss, arriving during login, which is the worst
moment there is - and nothing is broken, something is merely slower than it will be tomorrow.
So: one line in the chat frame when the walk starts and has real work and the family is longer
than 25, and one on the professions window itself for as long as the walk is unfinished.

**The second is the one that matters, and it took a correction to find that out.** The first
version said it only in the chat frame, on the reasoning that the wait is at login. Alberto
corrected that: the wait he means is the hourglass **the first time the professions window is
opened**, when the walk has not yet reached that member and their window pays for it. A line in
the chat frame is not where somebody staring at an hourglass is looking.

**It still cannot be drawn during the wait**, and that limit is unchanged - nothing can, which
is why the original notice was refused. It is drawn either side of it, for as long as
`UI:RecipeWarmUpLeft()` says there is walking left.

**The fingerprint design above is still not built**, and the notice does not remove the case for
it: three and a half minutes of decoding at every login is still three and a half minutes, and
it is still provably pointless from the second session on. What the notice removes is the
*mystery*, which is what was actually hurting.

**Confirmed quiet in play 2026-09-06.** Alberto's own thirty-member family now warms in silence -
*la passeggiata è muta, già da un paio di deploy* - which is the names store and the language
skip working together: nothing is asked, so a notice that only fires on real work never appears.

**That lowers this entry rather than closing it.** What is left is the walking alone: a second
and a payload decode per character, buying nothing, on every login after the first. Invisible at
thirty and three and a half minutes at two hundred and ten. Worth building when somebody says
their login is slow, and not before.

**And the reading that would make that a false negative, written down so it is not forgotten:**
the notice is also silent for a family of 25 or fewer, and silent when the walk finds no work at
all - so a quiet walk proves the walk found nothing, not that the notice works. His family is
thirty and `/family recipes` still shows two of Deiana's lists in French, so there was work to
find and the store had already found it.

### What the walk actually costs, read out of the code 2026-09-06

Alberto asked whether thirty blacksmiths make Family walk three hundred recipes thirty times.
Read rather than recalled, and the answer is in two halves.

**The asking does not repeat.** `Slash.lua` checks `Names:CachedItem(id)` per id and skips a
known one **without spending the budget** - the comment beside it says why, and the session cache
and the disk store both answer. So the number of questions put to the client is bounded by the
**distinct** item ids across the whole family. Twenty blacksmiths cost what one costs, plus
whatever the twentieth knows that the first did not.

**The walking does repeat.** The queue advances one member per call and the timer fires once a
second, so a member contributing nothing still costs a second and a payload decode. Ten
characters is ten seconds; two hundred and ten is three and a half minutes, for the same
questions. That is the half the fingerprint above would fix, and it is the whole of the
difference between his ten-alt user and his 210-alt one.

### The third thing was already answered, and answered the other way

I claimed most recipes are named from their spell and that the walk therefore asks for item
names nothing will read. **It is the opposite, and it was measured and written down in February
of this work** - `DATASOURCES.md` §2, *Recipe links, measured rather than assumed*:
`GetTradeSkillRecipeLink` returns **nothing at all** on Classic Era, so every recipe there has an
item id and no spell.

Alberto ran `/family recipes` and it came back with the same three numbers that section already
quotes, off the same character: **150 leatherworking, 67 cooking, 12 first aid, an item id on
every one and a spell id on none.**

So there is nothing to trim. Every recipe on Era needs its item name, the walk's asking is real
work, and with the names store it is real work done **once ever** rather than once a session.

**What is left is only the walking**, one second and one payload decode per character whether or
not that character contributes anything - which is what the fingerprint at the top of this entry
would fix, and it is worth exactly the sessions after the first.

**And this is L-026 biting a second time**: reasoning about a data source without opening
`DATASOURCES.md`, which the routing table says beats everything on data. It cost Alberto a
command he did not need to type.

---

### Built 2026-09-06, and it is the fingerprint the top of this entry designed

Alberto asked for it before the release, in those words: *we do need a way to significantly
optimise "login burden" for people with 100 - 200 - 300 alts.*

**What the walk does now.** Before it picks a member up it asks `Database:PayloadMark` for a
short mark of that member's record *as it sits on disk*, which costs a fold over a string and no
decode at all. If the mark matches what the last walk wrote down, the member is stepped past. Up
to `UI.WARM_SKIPS` of them per call - twenty - and a call that fills its cap ends there rather
than reading a twenty-first record it has already been told is empty.

**Measured in the harness**: twelve members cost **13 ticks** on a cold walk and **2** once
settled. The arithmetic that follows from the cap is that a settled family of 300 costs
`ceil(300 / 20)` ticks and a few more for members with no record at all - about sixteen seconds
against five minutes.

**A mark is written only where every name answered.** A member with an id the client would not
name is left unmarked, so the next walk comes back for it - the walk is the only thing that ever
asks. That makes the *second* session the one that pays on a truly cold client: the first learns
the names and marks nobody, the second finds them all on disk and marks as it goes, and every
login after that steps past the family. Two logins to warm, and then free.

**The marks live inside the item-name store** - `FamilyDB.itemNames[locale].walked` - and not
beside the members. A mark says *everything this record asks for is in this store*, so when the
store is emptied, which is a new client build or the first session in a language, the record
holding it is replaced whole and the marks go with it. Nothing has to remember to clear them.

**Only where the record is a string.** Stored plain - the fallback with no compression libraries
- the payload *is* the table and `Codec:Decode` hands it straight back, so there is no decode to
skip and folding it would cost more than the walk. No mark means the member is read as before,
which is also what happens to a linked family's members: theirs arrived over the wire as a table
and were never encoded.

**And the shortcut that was tried first is written down in L-061.** The mark folded only the
length and the first and last 256 bytes, which is sixty times cheaper - 0.017 ms against 1.0 ms
for a 30 KB record - and wrong: a member's language is four bytes in the middle, `enUS` and
`frFR` are the same length, and the harness flips one. Three existing checks went red. The whole
record is folded now and the number that made the shortcut tempting pays for the cap instead.

Ten checks, eight mutations, all reddening.

## 26. The warm-up asks for names the reader's own language makes unnecessary — DONE 2026-09-06

**Found 2026-09-06**, from Alberto asking why recipe *names* are still stored at all when the
plan had always been to keep ids and look names up. The answer to his question is that both are
kept and the ids are the identity - `DECISIONS.md` 2026-08-28 says a recipe is named from its
spell id at display and the recorded word is only the fallback, with a second row adding that it
falls back to the item's name before it falls back to the word. But reading the code to answer
him turned up something else.

**`Names:Recipe` has a fast path before either id.** Its first branch:

    if locale and locale == Family.locale and recipe.name ~= "" then return recipe.name end

`locale` there is `record.locale`, written by the scanner as `entry.locale = Family.locale`. So
**a profession record written in the reader's own language is drawn from the recorded word and
neither id is touched at all** - no spell lookup, no item lookup, no request, no waiting. For a
player who reads their own family on the client they scanned it with, that is every recipe.

**The warm-up does not know that.** It queues `recipe.itemID` for every recipe of every member
regardless of `record.locale`:

    for _, record in pairs(payload.professions or {}) do
        for _, recipe in ipairs(record.recipes or {}) do
            if recipe.itemID then warmPending[#warmPending + 1] = recipe.itemID end

So for a single-language player the entire walk may be asking the client for names that nothing
will ever read.

**Which would also explain the freeze that started all of this**, and this is the part to
confirm before acting. Alberto's `/family recipes` on 2026-09-06 came back with recipe names in
**French** and item names in **English** - *Bandage épais en étoffe runique* against *Heavy
Runecloth Bandage*. `Names:CachedItem` asks the live client first, so English item names mean an
English client, and French recipe names mean records scanned on a French one. That is precisely
the case where the fast path does **not** fire and every item name is genuinely needed.

**So the premise is one question, not a probe:** is he reading French records on an English
client? If yes, the freeze he reported is the mismatched-language case working as designed, most
users never pay it, and the fix is one condition in the warm-up. If no, the fast path is not
firing when it should and that is a different and worse fault.

**Confirmed by Alberto the same evening**, and the question was a bad one as asked - *e come
faccio a sapere se sto leggendo record francesi?* He could not, and his own observation says why:
*visto il lavoro ottimo che abbiamo fatto, ora non vedo nemmeno più quali sono, perché Family me
le traduce al volo.* The answer he could give was better than the one asked for: he has been
switching an Era client between English and French for days, so some of his lists are French and
some are not.

**So `/family recipes` now says it outright** - per profession, the language the list was read in
beside the language the reader is in. That command exists to answer "why is this recipe in the
wrong language" and was leaving its most useful fact to be inferred from which of the printed
words happen to look French.

**And the warm-up skips a record whose locale is the reader's.** Every call site that can
*request* an item name was read before the change, not after: `Professions.lua` passes
`record.locale` and short-circuits; `Cooldowns.lua` passes nil on purpose - a Mooncloth recorded
in French was headed *Etoffe lunaire* on an English panel - but it asks about cooldown recipes,
which are a handful and have a warm-up of their own; every other call site names a recipe with
no callback and so cannot ask the client for anything.

A record with no locale is warmed like any other, because the fast path cannot use one either.

**What this does not fix** is the walking - one second and one payload decode per character
whether or not that character contributes anything. That is entry 25's fingerprint and is
untouched.
---

## 27. The warm-up covers our own family and not the one we borrowed — DONE 2026-09-06

**Asked 2026-09-06 as a school case**, and answered by reading rather than by reasoning: a user
with 200 English alts, always English, links with a French family of 100 and shares his own back.

**During the first sync: nothing.** `Wide.lua` names nothing - it contains no call into `Names`
at all. What crosses is the payload, already a table, and the `professions` category carries the
whole record including its `locale`, so a borrowed list arrives knowing which language it was
read in. No client is asked anything.

**The first time Professions is opened on a French sibling: the freeze is back.** The warm-up
walks `Family.Database:Members()`, which is `FamilyDB.members` - **ours only**. Borrowed members
live under `FamilyDB.wide` and are reached through `UI:Payload`, which the panel uses and the
warm-up does not. So a sibling's list is never warmed, its locale is `frFR` against a reader in
`enUS`, `Names:Recipe` falls through to the item id, and every name is asked for at the moment
of the click - which is precisely the stall the warm-up was built to move off the click.

**After a logoff: it does not happen twice.** Whatever was learnt went into
`FamilyDB.itemNames[enUS]` and is read back at the next session, so the second opening is
immediate. The store does not care whose character taught it a name.

**And it is symmetrical.** The French friend receives 200 English lists and pays the same on his
side, in reverse.

**What would close it.** Put borrowed members in the warm queue. They are unusually cheap to
walk - a borrowed payload was never encoded, so there is no decode to spread, which is the whole
of what makes our own members cost a second each. And they are exactly the case where a locale
mismatch is not a coincidence but the point: you link with a French family *because* they are
French.

**The cost to weigh:** a hundred more members in the queue at a second each, against a freeze at
the click. The notice now explains the wait either way, and the names store means it is paid
once ever rather than once a session.

**Built the same evening**, Alberto's call. `Wide:BorrowedMembers()` joins the queue and the
walk reads through `UI:Payload` rather than `Database:Payload`, which knows only ours (L-052).
The language rule applies to a borrowed list exactly as to one of ours: the rule is about the
record, not about whose it is.

**Two things Alberto observed about the store while it was being written, both true:**

- **What a borrowed list teaches outlives the friendship.** The store is keyed by item id and
  by the *reader's* language, and is filed under nobody: unlinking a family, or forgetting every
  character in it, takes none of it away. The next French family found already answers most of
  what it needs. Nothing outside `Names.lua` touches that table, which is what makes this true
  rather than merely likely - and there is now a check that unlinks a family and looks.
- **Nothing is stored twice.** `FamilyDB.itemNames[locale][itemID]` is a map: meeting *Blue
  Dragonscale Breastplate* on thirty characters writes one entry, and a second write to the same
  id overwrites rather than appends. The pending *queue* is a list and can hold an id twice, but
  the second one is skipped at the moment of asking, without spending the budget - which is what
  the check for a warm client asking for nothing already pins.
---

## 28. Shipping the item names instead of learning them — measured, not built

**Asked out of curiosity 2026-09-06**: why not ship a table of every translation and skip the
learning entirely? Measured rather than guessed, so that nobody has to derive it twice.

**What it would have to hold.** Only the items a recipe makes - the rest of an item's name is
wanted by bags and mail, which this would not help. Counted from `SkillLineAbility` against
`SpellEffect` 24, one owner per spell:

| build | recipes that make something | distinct items made |
|---|---|---|
| Classic Era | 1,468 | **1,462** |
| Burning Crusade | 2,036 | 2,025 |
| Mists | 4,851 | 4,807 |
| union | | **5,244** |

**What it would weigh.** The per-language cost is measured off `SkillLines.lua`, which Family
already ships in five: German x1.13 of English, French x1.10, Spanish x1.19, **Russian x3.35** -
two bytes a letter in UTF-8 - for a mean of x1.55. The mean English item name is 20.6 bytes.

| | rows | file |
|---|---|---|
| Era only, one language | 1,462 | **69 KB** |
| Era only, five languages | 7,310 | **343 KB** |
| all three builds, five languages | 26,220 | **1.2 MB** |

Against an addon that is 1.6 MB and 752 KB today, whose largest single file is
`RecipeTeaches.lua` at 228 KB. The full version would be **the biggest thing in the addon by a
factor of five**, and four fifths of it would be languages the reader is not using, loaded into
memory at every login for everybody.

**What it would buy.** It removes the walk for recipes entirely - not merely the asking, the
whole thing - because there would be nothing to ask the client for.

**What it would cost beyond the bytes.**

- **It duplicates data the client already has**, correctly, in the reader's own language, for
  free. Family's whole shape is asking the client rather than carrying a copy: §2.1 stores ids
  and looks names up for exactly this reason.
- **It goes stale in a way the store does not.** `FamilyDB.itemNames` carries the build it was
  written at and empties itself when the client changes. A shipped table has no such escape: a
  patch renames an item and the addon says the old name until somebody regenerates and releases.
- **It helps recipes and nothing else.** Bags, bank, mail and the possessions search want item
  names too, and a recipe table answers none of them.
- **It is the wrong side of a standing decision.** *No item library, and no catalogue of where
  items come from* - `DECISIONS.md` 2026-08-09 - is about advising rather than about naming, so
  this is adjacent to it rather than forbidden by it. Said plainly rather than stretched.

**And the cost it removes is already one-off.** Since the names store, the walk is paid once
ever rather than once a session, and only for lists in a language that is not the reader's. A
1.2 MB shipped table would buy back a wait that now happens once, on a first login, with a line
on screen explaining it.

**Not built, and the recommendation is not to.** Written down so the numbers exist.
---

## 29. An unlearned profession is forgotten by the panels and remembered by the search — DONE 2026-09-06

**Asked 2026-09-06**: what happens when an alt unlearns a profession? Read rather than reasoned,
and the two halves of the record answer differently.

**Meta forgets it within a second, on the character it happened to.** Unlearning changes the
skill sheet, so the client fires `SKILL_LINES_CHANGED`; the scanner has been listening for that
since the beginning and books a scan one second later. `ReadRanks` reads the **whole** sheet,
`Scanners/Professions.lua` writes `skills = summary`, and `Database:SetMeta` replaces a field
rather than merging into it - so the whole skills table is the new one.

**Only on that character, and that is the whole of the limit.** A scan reads the client, and the
client is one character. Family cannot learn anything about an alt nobody is playing, so an
unlearn on Deiana is known the moment it happens and an unlearn on Eccebombo is unknown until
somebody logs in on them. That is true of every fact Family holds and is not special to this.

**And the event is not the only chance, which answers the case where Family was switched off for
it.** `PLAYER_ENTERING_WORLD` books the same scan four seconds after every login, and that scan
reads the whole sheet and replaces `meta.skills` with it. So a profession unlearnt on a machine
without Family - or during a lag that swallowed the event, or on a client that never fired it -
is noticed the next time somebody logs in on that character. Alberto proposed exactly this check
on 2026-09-06; it is already there, and the readers now gate on the thing it writes.

The scan refuses to file anything when the sheet comes back empty (`if not next(everything) and
not includeRecipes then return end`), which is what stops a client that cannot read skills from
wiping them.

**So the login pass already closed the display half. Pruning the payload bought bytes and
nothing a reader can see** - the recipes stayed on disk and a link went on sending them - and
Alberto asked for it anyway on 2026-09-06, so it is built. See *the prune, as built* below. Everything that reads skills loses the profession with it:

- the summary's professions cells, which are built from `skillsOf(meta, …)`
- the professions panel, whose loop is `for id, skill in pairs(skills)` and looks the recipe
  record up by that id rather than the other way round
- **the guild share grid**, which walks `meta.skills` at `Guild.lua:815` - so an unlearned
  profession stops being offered and nothing about it crosses to a guildmate. The outward-facing
  path is safe.

**The payload remembers it for ever.** The recipe scan begins `local stored = payload.professions
or {}` and only ever assigns into it; nothing prunes.

**Why it cannot prune, which is worth stating rather than asserting.** The two halves of that
scan see different amounts of the world:

- `ReadRanks` reads the **whole skill sheet** in one go. It knows every profession the character
  has, so replacing `meta.skills` wholesale is a claim it is entitled to make.
- `ReadRecipes` reads **one window, the one that happens to be open** - the comment above it says
  so: *recipes only when a window is actually open, and only for the one profession it is open
  on. Everything else keeps whatever it last saw.*

So a scan that pruned the payload to what it just read would delete a member's alchemy list
because they opened the forge. That is §2.2 exactly: not-seen is not empty, and the recipe reader
is told about one profession and nothing at all about the others.

**Which also says how it *could* be pruned**, if it ever needs to be: not by the recipe reader,
which has no basis, but at the moment `ReadRanks` hands back a full skill sheet - drop payload
entries for professions that sheet does not have.

**And there is a mine in that, found by reading rather than by trying it.** Some professions are
in the payload and in **no skill sheet at all**. A death knight's runeforging is *a window full
of things they can make and no skill anywhere*; the recipe scan says so itself and injects such a
profession into `skills` from what the window reported, precisely because the sheet will not. A
prune that trusted the sheet would delete every death knight's runeforging list at every login,
and a recipe list is not rebuildable - it needs that window reopened on that character.

So the rule would have to be **prune only a profession whose key resolves to a skill line the
shipped table knows, and which that sheet does not have**: runeforging resolves to nothing and is
kept, and anything the table has never heard of is kept for the same reason `stillHeld` keeps it.
Guarded, as above, on the sheet being non-empty.

**No exception list is needed for that, and one would be worse.** Alberto proposed naming
runeforging outright - *aggiungiamo l'eccezione e storia finita*. Checked: `Runeforging` is in
neither `SkillLines.lua` nor the generator's inputs, so `SkillLineFor` answers nothing for it and
the rule above already keeps it, without it being named. A hand list of one is a list that is
wrong the first time a class or an expansion adds a second.

**And the second half of his proposal needs nothing at all.** He asked that professions *without*
recipes - herbalism was his example - also be forgotten, or an unlearnt one would go on being
listed under Overview and in the professions page's grey line. Read rather than assumed:
`meta.skills` is built at `Scanners/Professions.lua:818` from the freshly read sheet alone, with
nothing carried over from what was there before, so an unlearnt herbalism leaves it at the next
scan and both of those screens lose it with it. Nothing accumulates on that side; only the
payload does, and only for professions that have a window to accumulate from.

The unpruned payload is wrong for two readers that walk it **without asking whether the member
still has the skill**:

- `Recipes.lua:328`, the crafters block: *who can make this*, on an item's tooltip
- `Recipes.lua:592`, the whole-family recipe search

So Family goes on saying a character can make things they can no longer make, on the two screens
whose whole job is answering that question.

**With one tell, and it is not a good one.** The rank in that block is read from meta -
`rank = (meta.skills or {})[profession] and meta.skills[profession].rank` - so an unlearned
profession lists the member with **no rank at all**, which is exactly how a member whose rank was
never read appears. The two cases are indistinguishable on screen.

**It never corrects itself**, short of re-learning the profession or forgetting the member.

**What closing it would take.** Both walks already have `meta` in hand; each needs to skip a
profession the member's skills no longer hold. The one subtlety is the key: a record written
before professions had ids is filed under a word, so the test has to resolve it the way
`Guild.lua:820` already does - `type(id) == "number" and id or Family:SkillLineFor(id)` - or an
old record would be pruned from the search for having the wrong kind of key, which is a worse
fault than the one being fixed.

**Built 2026-09-06.** `stillHeld(meta, profession)` in `Recipes.lua`, and both walks pass their
recipe list through it. Both sides of the key are resolved through `SkillLineFor` before
comparing, and the answer is **yes wherever the question cannot be put** (§2.2): a member with no
skills recorded is one nobody has read rather than one who has unlearnt everything, and a key no
shipped table knows cannot be judged either way.

**Six mutations, and two of them caught nothing at first.** The two word-against-id checks had the
same kind of key on both sides, so the first branch answered and the resolution below it was
never reached - they passed with it mutated away. Rewritten to cross it in one direction each,
plus a third where the word resolves to a trade the member does *not* have, which is what pins
that the word is resolved rather than merely tolerated.

### What this reaches, and what it does not

**Ours, on our own screens.** `KnowersOf` and `Crafters` - the two that feed an item tooltip's
*can be made by* - walk `Database:Members()` and nothing else, so they are about our own family.
`Search` walks ours **and our siblings**, which is the population every whole-family list uses.

**The guild stops being told.** The share grid is built from `meta.skills` (`Guild.lua:815`), so
an unlearned profession stops being offered; the next announcement carries a character entry
without it, the receiver replaces that entry wholesale, and the walk right after drops any recipe
list held for a profession no longer offered - *a withdrawn profession must stop being answerable
the moment its owner says so*, which is already written there.

**A linked family is a different mechanism with the same outcome.** What crosses is the whole
`professions` payload, and the payload is never pruned - so the stale list **does** still cross
the wire. It stops being shown because the same category carries `skills` in meta, and the reader
runs `stillHeld` against their borrowed copy. The guild *stops sending*; a link *goes on sending*
and the reader *stops believing*. Both end in the reference disappearing; only one of them stops
spending bytes on it.
---

## 30. The prune, as built — DONE 2026-09-06

**Where.** In `Scanners/Professions.lua`, beside the older prune that drops a profession's
name-shaped key once it has an id - the two read as one idea: drop what no longer belongs. It is
in the scan that reads the **whole** skill sheet, never in the recipe reader, which is told about
one window and nothing about the others.

**The rule.** A stored profession is dropped when the sheet was read at all, the profession is
absent from it, and `onSheet` says the sheet has carried it before.

**`onSheet` is the half the first version got wrong**, and the harness caught it inside a minute.
A profession can reach the record from its **window** rather than from the sheet: a death
knight's runeforging is *a window full of things they can make and no skill anywhere*, and the
scan injects such a thing into its own skill list from what the window reported, precisely
because no sheet will ever list it. At the next scan with that window shut it is missing - and
the first rule read that as an unlearn and deleted it. Something that has never been on a sheet
cannot be missed from one.

**Rogue poisons were named as a second example of that, in this file and in the scanner, and it
was wrong.** Alberto sent the Skills tab of an Era rogue on 2026-09-06: *Class Skills* -
Assassination, Combat, **Lockpicking**, **Poisons**, Subtlety - sits on the same list as
*Professions* and *Secondary Skills*, and that list is what the scanner reads. So poisons comes
off the sheet like anything else. Whether runeforging is the same on Mists is unconfirmed and he
has a death knight to look with.

**The rule did not care, and that is the property worth keeping.** `onSheet` records what a
client's sheet actually said, so it is right about poisons whichever of us was right about them,
and it will be right about runeforging without anybody having to settle it first.

**And they cannot be unlearned anyway**, which Alberto pointed out and which closes the worry
underneath the question: a skill that can never leave the sheet can never be read as having left
it, so the prune cannot reach lockpicking or poisons however the marking works out. Burning
Crusade is the same as Era - he checked. See *What the skill sheet actually holds* in
[`DATASOURCES.md`](DATASOURCES.md).

**And runeforging is confirmed**, from his own Mists death knight: Mists has no skill sheet at
all, its *Professions* page does not list runeforging, and the spellbook carries it as a passive
present in every branch. So the window branch this whole rule was written around has a real
client, and `onSheet` keeps runeforging safe without anybody naming it.

The mark is set once and never unset, which is not decoration: a scan whose sheet could not be
read at all, with that profession's own window open, would otherwise clear it - and one bad read
would disable the rule for that profession for ever.

**Six mutations, and the first pass was worth less than it looked.** Three of them killed the
harness rather than reddening a check - a pruned record made a fixture two thousand lines away
index a nil - which reads as an infrastructure fault rather than as a finding, the same lesson as
the loop that once hung the run. That fixture now says what went wrong. And two checks were
weak: the §2.2 guard passed with the guard removed, because a scan with no recipes gives up long
before reaching it, so it is exercised with a window open now; and the remembered mark was pinned
by nothing until the bad-read case above was written down as a check.
---

## 31. Every grant re-sends everything, and the wire is 2 KB a second — DONE 2026-09-06

**Reported by Alberto on 2026-09-06**, from linking with the family aliased *Serena* the day
before: she ticked her columns quickly, and on his side the marks took *"a good minute or two"* to
appear, arriving in bursts — one, then another, then ten at once, then a pause.

**Measured 2026-09-06, and it is exactly what the code does.**

- `Comm.lua` drains its queue at `PER_TICK = 2` every `TICK = 0.2` — **ten messages a second** —
  and `CHUNK = 200` bytes fit in each. So the wire is **2 KB a second**, deliberately: the comment
  there says ten a second is the rate the community's throttling library settled on and it is not
  worth being cleverer.
- `Wide:Grant` calls `grantsChanged`, which calls `ExchangeWith` — **one whole exchange per
  checkbox**. `Wide:GrantMany` exists so that a column is one exchange instead of eleven, and its
  comment says why.
- But **an exchange sends the data, not the decision**. `ExchangeWith` sends `self:Offering(link)`,
  which is `offering()` for every granted member — their bags, equipment, professions, quests,
  mail, auctions, reputations, money, currencies. What actually changed when a box is ticked is
  one flag.

So thirteen category columns are thirteen full transfers of everything granted so far, each one
larger than the last. At 2 KB a second a 20 KB offering is ten seconds on its own.

**And the burstiness is the reassembly, not the network.** `Comm.lua` completes a transfer only
when the last chunk lands — `if entry.have == entry.total then complete(...)` — so nothing appears
while a payload trickles in at ten messages a second, and then the whole of it appears at once.
One tick, a pause, ten in a flash: that is a small payload, then a large one arriving whole.

**The waiting half is built, 2026-09-06.** Alberto's decision, and it made the entry below mostly
unnecessary: knowing a friend is mid-click is something he can live without, and not packaging
anything while they are still clicking is worth a three-second wait. So `grantsChanged` defers
through `Family:After`, which restarts its delay under the same key rather than queueing - a
debounce that was already in the codebase. Fourteen columns are one transfer now instead of
fourteen, and no protocol changed, so nothing an older Family has to ignore.

The second question answered itself: the withdrawal promise survives, because it still goes with
nobody pressing Update. Three seconds later is still a promise.

**What is left, and it is smaller than it was.** The transfer that does go still carries the whole
offering rather than the flag that changed, so the *first* time a family grants a lot of members
it is still every record on the wire at 2 KB a second. That is the shape below, and it is now a
question of how big one exchange is rather than how many there are.

**And built the same day, once the premise above was measured and found wrong.** This entry said
the fix was "a protocol addition and has to be readable by a Family that has never heard of it".
It is not. `onData` **merges** `members` and forgets on `offering` — it has done since it was
written — so a partial `members` is already correct on every client in existence. Nothing new goes
on the wire; what changed is how much of the old thing does.

Each side now keeps a mark per member in the link, on disk, and carries only the members whose
records have moved since it last sent them. The `offering` list is still sent whole, always: it is
a list of keys, it costs nothing, and it is what keeps *unchanged* and *withdrawn* two different
sentences. A grant settling also stops sending `want`, so a decision about our own flags no longer
makes the other side reply with their entire offering.

*Update now* sends everything, because that is the button somebody presses when a thing looks
wrong. A link made or remade forgets its marks rather than forcing a full send, which says the
true thing: we do not know what they hold.

---

## 32. The possessions search repeated the item on every line, and put the count in its name — DONE 2026-09-06

**Reported 2026-09-06** from play, with a screenshot of *Possessions / Whole family* searching
`bronze`, in two parts.

**The number read as part of the name.** The item column drew `Bronze Bar 209`, and that 209 is
not a fact about the item - it is how many *that line's* character holds. Alberto: *it took me a
sec to understand what the numbers after the item meant.* He named the fix himself and named the
precedent for it: put the total at the head of the right-hand column, in front of the breakdown,
`209 (62 bags, 147 bank)` - *exactly as it happens on the tooltip after all*.

**And the item was written five times for five holders.** *Why didn't we adopt a consolidated
left column model, like the format used for Whole Fam Reputations search? On the left column
Bronze Bar only once, on the central column the list of all having some, and on the right the
quantities each. Chars having the product should be listed from the one owning the highest amount
down.*

**Why it was not, read rather than recalled.** Entry 13 above is where these rows got their
present shape, and it never considered the question: the panel began as a set of bags, the
whole-family search was bolted on as a flat list, and the ordering slice added a sort bar over
that flat list without touching how it was drawn. The order captions have been describing blocks
since the day they were written - *by item, and under each of them whoever has the most* - and the
drawing never caught up with them.

**Built the same day.** The sorted list is cut into runs sharing the order's group key, and the
value that made the run is written on its first line only. The columns keep their meanings
whichever order is on - item, then who, then how many and where - so grouping only stops a column
repeating itself, rather than swapping what the columns hold. Five holders are drawn and the rest
fold behind *and %d more*, which is the reputations list's own mechanism and the tooltip's own
number: a panel should not hide what a tooltip already says.

**Grouped on the key and never on the word**, because two characters of one name on two realms are
two characters (§2.1) and two items can share a name. The item's id joins its name in the order
for the same reason: without it, two items sharing a word interleave by how many are held and each
comes out as four or five blocks under one heading.

**And the sentence in the right-hand column is now the tooltip's own**, moved to `UI:HeldWhere` in
`Window.lua` and called by both. The panel had its own copy of the same four phrases; one question
should have one sentence wherever it is asked.

*The "How many" order groups nothing, deliberately: "most first, wherever in the family they
happen to be" has no block to head, so every line there says all three things.*

Sixteen checks, nine mutations, all reddening - and two of the nine only after the check they were
aimed at was rewritten. The first grouped the key and the column under one literal, so a mutation
of the key silently turned the column off and reddened the wrong thing; the second tried to prove
the id in the order by looking for a block holding two items, which cannot happen because blocks
are cut on the id - what the id buys is that one item is **one** block, and counting headings is
what says so.

---

### CTRL stops swapping a recipe row after the window loses focus — ANSWERED 2026-09-06, nothing to build

**Reported 2026-09-06** from play: *sometimes the CTRL trick stops working, but I'll be damned if
I can understand what makes that happen.* Alberto found the conditions himself, which is the whole
of why this took one probe instead of five: WoW windowed on one screen, something clicked on a
second screen, then back over a recipe row **without clicking**. Tooltips still appear and CTRL
does nothing. Clicking anywhere in the Family window wakes it. Clicking another application on the
*same* screen never breaks it - because getting back to WoW from there means clicking WoW.

**The measurement.** A probe recording one sample a second, the first letter `IsControlKeyDown()`
and the second whether the modifier watcher was shown:

`17 .. .. .. .W .W .W .W .W .W .W .W .. .. .W .. .. C.`

Seventeen samples in seventeen seconds, so the client runs scripts perfectly well unfocused - the
watcher is not asleep and `OnUpdate` is not throttled. The eight consecutive `.W` are the seconds
he held CTRL on a row: **awake, on a row, and the client saying no key was down.** The final `C.`
is the same probe seeing CTRL the instant the window had focus back.

**So the key never reaches the game.** `IsControlKeyDown` is the only source there is, and it
answers about what the client was given. Nothing in Family can read a key the client never
received, and nothing can work around it either: even if the window could be asked whether it has
focus, that would not say whether a key is being held.

*Two things worth keeping from this. The swap lives in exactly one place -
`Family_UI/Professions.lua:706`, the recipe rows - and my first instruction said "hover a quest or
item row", which was wrong and Alberto corrected it. And the first probe printed nothing at all,
not even before the window lost focus, because a fault inside an `OnUpdate` is silent while
`scriptErrors` is off, which is the default. A probe that does not announce itself cannot be told
from a probe that found nothing.*

