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

---

## 4. A minimap button other addons can collect — RESERVED

**Asked:** use LibDBIcon or similar so the icon behaves inside the popup panels other addons
build out of minimap buttons.

**Today:** confirmed, with the complaint quoted at us. `Family_UI/Broker.lua` builds
`CreateFrame("Button", "FamilyMinimapButton", Minimap)` by hand, and the screenshot shows
another addon naming `FamilyMinimapButton` and asking its author to use LibDBIcon instead.
Altoholic and GBankClassic are collected; Family is not.

**Reserved.** Adopting a third-party library is on the ask-never-decide list. Mechanically it
is small — `.pkgmeta` already fetches three externals and the harness now checks that every
library the `.toc` loads is one the packager writes where it looks — but it is not a decision
to take while writing the code.

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

## 6. A keybind that opens Family

**Asked:** open the window from the keyboard.

**Today:** nothing. No `Bindings.xml`, no `BINDING_` globals anywhere in the addon.

**Shape:** small and self-contained — a bindings file and two localised strings. The only care
needed is that the binding name is a global the client localises, not a word we ship.

---

## 7. Lockpicking, for rogues

**Asked:** record lockpicking skill.

**Today:** not recorded. `Family/SkillLines.lua` carries 15 skill lines and lockpicking is not
among them, so a rogue's lockpicking has no identity to be stored under and would fall back to
a name — which §2.1 exists to prevent.

**Shape:** extend `tools/skill-lines.py` to take it, then the professions scanner. Worth
asking what it belongs beside: it is a skill with a rank and no recipes, which is a shape
Family does not otherwise hold.

---

## 8. A whole-family view of reputations

**Asked:** a filterable family-wide reputation view.

**Today:** half of it exists. Reputations are scanned (`Family/Scanners/Character.lua`), they
cross a Wide Family link (`reputations` payload, `reputationCount` meta), and they are shown
**per character** on the Character panel. What is missing is the view across everybody.

**Shape:** the data is already stored and already shared; this is a panel. It shares its
filtering problem with entry 3, and doing 3 first would make this most of the way done.
