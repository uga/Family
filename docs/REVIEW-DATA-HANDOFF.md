# Handoff from the data-path review, 2026-09-13

For the development session. Everything below was read in the reviewing session on the tree at
`e3e7e5a`; re-read before citing, as `CLAUDE.md` requires. Nothing here is built. Nothing here
was written into `docs/` by the review.

## 0. What the review found that the brief and the logs got wrong

1. **The first crash did not stop on `GetBuildInfo`.** In the file deployed at the time
   (`db45d3d`, identical to `1d8dea7^`), `Names.lua:132` is inside `storedItem`: the read of an
   item name from the on-disk store. That path is reached only from `Names:CachedItem`, i.e. from
   `Names:Recipe`'s item branch, which every Era trade-skill recipe (itemID, no spellID) takes
   when its list is not in the reader's language. The build fix in `1d8dea7` removed a real cost
   on that path; the path itself is untouched. `DECISIONS.md` row *The item-name store asks the
   client for its build once* should be corrected to say so.
2. **The second crash is at `1d8dea7:280`**, the check after `Names:Spell(id)` in
   `Names:Recipe`. Reached from `KnowersOf` (`Recipes.lua:480`) only for recipes without an
   itemID, and from `Crafters` (`Recipes.lua:931`) for every recipe until one matches.
3. **The harness never runs the `plain` codec.** `tests/Harness.lua:1936-1958` stands in fake
   `LibSerialize`/`LibDeflate`, so `Codec.compressing` is always true and no check contains
   `codec = "plain"`. Backlog 74 builds on a path with no coverage.
4. **`Names:CachedItem` does not memoise misses** (`Names.lua:649-661`); `recipeNames` does
   (`Names.lua:283`). An item neither the client nor the store knows is asked of the client on
   every call.
5. **The Era enchanting *record* did not change** in the last day. `Scanners/Professions.lua`
   only gained the collapse trap (`dc37820`); `everybody`, `Search`, `KnowersOf`, `Crafters` in
   `Recipes.lua` are identical to 2026-09-12 16:00. What changed is what a row describes and
   asks, see §1.

## 1. Where the two crashes most likely come from (verified paths, not timings)

Measured: 31 records decode in 521-524 ms (two readings). 31 of 49 recipe lists are `frFR`,
over twelve characters. Not measured: the client's *script ran too long* budget, the search
and the tooltip with the records already decoded.

**Crash 1, the search.** Every keystroke calls `frame:Refresh()` with no delay
(`Family_UI/Professions.lua:502`). `Recipes:Search` names every recipe of every member through
`Names:Recipe(recipe, nil, nil, record.locale)` (`Recipes.lua:735`). Then the default family
order `byRecipeName` (`Family_UI/Professions.lua`, just above `FAMILY_ORDERS` at line 230, from
`8e2bf6c` 2026-09-05) calls `Names:Recipe(a)` **without a locale on every comparison**, so on
Era every comparison goes through `CachedItem`: a client call and, on a miss, the store read at
the crash line. N log N per keystroke, for a name the row already carries in `row.name`.

**Crash 2, the tooltip.** Since `61462f3` (2026-09-12 22:12), a recipe row whose spell makes a
product (wand, rod, oil) opens the **item** tooltip (`Family_UI/Professions.lua:901`,
`self.itemID or Recipes:Product(self.spellID)`). The item lane goes through `SetItemByID`, so
`OnTooltipSetItem` fires and `onItem` (`Tooltip.lua:1097`) draws five blocks in one frame:
`possessionLines` (`Index:Owners`, whose first call rebuilds the index and decodes everybody),
`crafterLines` (`Recipes:Crafters`, walks everybody), `makerBlock` (`Tooltip.lua:518-547`:
`KnowersOf(nil, itemID, name)`; for a wand `ItemProfession` answers nothing, so `KnowersOf`
takes the **name path** over every enchanting recipe of every foreign list, calling
`Names:Spell` at exactly line 280), `costLines`, `priceLines`. Before `61462f3` those rows opened
the spell tooltip, `KnowersOf(spellID)` (`Tooltip.lua:1056`), which matches by id and names
nothing. The item lane has existed for bags and the auction house since `58d0ac9` (08-30); the
professions rows entered it last night. Whether the reported tooltip was a professions row or a
bag item is not recorded.

**Also new, and whole-family on a one-member page.** Since `aba1a49` (2026-09-12 22:44) every
row of a single member's professions page calls `Recipes:CanMake` → `Index:HeldBy` →
`refresh()` → `rebuild()` (`Index.lua:198-213`, `385-389`), which decodes every member the first
time. A page that decoded one member now decodes the family.

The fold and unfold commits of the same window (`fe2fcba`, `9bfaa78`, `f8df409`, `43e3c73`,
`88f5275`) were checked by the files they touch, not line by line: layout only, no payload reads.

## 2. Readings Alberto takes in game, before step 4 is authorised

R1. Log in, wait 20 s, then `/run print(Family.Database:WarmPayloads())` must print `false`.
    Then the search and the tooltip as on the 13th. Crash gone: the decode was necessary to it.
    Crash still there: the decode is not the cause and step 4 does not fix it.
R2. Same session, after R1, each twice in a row (first pays the cold names, second does not):
    `/run local c=debugprofilestop local t=c() local r=Family.Recipes:Search("ar") print(#r, math.floor(c()-t).." ms")`
    `/run local c=debugprofilestop local t=c() local r=Family.Recipes:KnowersOf(nil, 0, "Lesser Magic Wand") print(#r, math.floor(c()-t).." ms")`
    With the decode known (0.52 s), the three costs are then separated: decode, cold names,
    the walk itself.
R3. Optional: open each French-recorded profession window on the English client. That rewrites
    `recipes` and `locale` together (`Scanners/Professions.lua:1302-1304`) and puts the list
    back on the fast path; if the search gets visibly cheaper, the naming explanation is
    confirmed from the other side.
R4. Before and after step 4, on the same account:
    `/run UpdateAddOnMemoryUsage() print(GetAddOnMemoryUsage("Family").." KB")`
    and the size of `WTF\Account\<account>\SavedVariables\Family.lua` after a `/reload`.

Record every reading in `docs/DECISIONS.md` or the backlog entry it answers, with the date.

**Taken by Alberto 2026-09-13, after the review**, Era client, 31 records:
`WarmPayloads()` printed `false` (nothing left to decode); `KnowersOf(nil, 0, "Lesser Magic
Wand")` printed `3  1 ms` then `3  2 ms`; `Search("ar")` printed `149  15 ms` then
`149  10 ms`. With every record decoded and the login name walk finished, the tooltip's
question costs one to two milliseconds and a two-letter search, sort included, ten to fifteen.
So the walk and the names are not the cost once warm; the decode (521-524 ms in one frame) is
the only measured cost of the size that crashed. Not measured, and not measurable without a code probe: the cold-name cost at the
first question of a session, before `UI:WarmRecipeNames` has run - bounded by the item
requests the walk makes for the foreign lists, paid in one frame instead of over 20 s.
Consequence for the order below: **step 4 is the fix for the crash and comes right after
step 3**; steps 1 and 2 are hygiene for the cold case and for scale, still worth doing, no
longer first. Alberto still says *go* on step 4, because the plan carries the amendments in §3.

## 3. Order of work, one slice per session, each useful alone

Order after the readings: **3, then 4, then 1, 2, 5, 6.** Steps 1-3 need no decision from
Alberto: they sit inside decisions already taken and are reversible. Step 4 waits for Alberto's
*go* on the amended plan (R1 is taken and points at the decode). Steps 5-6 are after 4. Every
slice:
state the file list before starting, extend the harness, record the mutations in
`tools/mutations/`, changelog Unreleased, `DECISIONS.md` in the same turn, `LESSONS.md` where a
mistake cost time.

**Step 1. The search's hot path.** May touch: `addons/Family_UI/Professions.lua`,
`addons/Family/Names.lua`, `tests/Harness.lua`, `tools/mutations/*.mut`, `CHANGELOG.md`,
`docs/DECISIONS.md`, `docs/LESSONS.md`.
- `byRecipeName` and the two family orders that fall through to it sort on `a.name` (the name
  the search already resolved), not on `Names:Recipe(a)`. Check: sorting N rows makes no
  `getItemName` call. Mutation: put `Names:Recipe(a)` back.
- `OnTextChanged` refreshes 0.2 s after the last keystroke (`Family:After` with one key).
  Check: three keystrokes inside the delay run one search.
- `Names:CachedItem` remembers a miss for the session, cleared by `GET_ITEM_INFO_RECEIVED` for
  that id, the way `recipeNames` remembers *the client would not say*. Check: a second
  `CachedItem` on an unknown id makes no client call; the event clears it.

**Step 2. The tooltip's hot path.** May touch: `addons/Family_UI/Tooltip.lua`,
`addons/Family/Recipes.lua`, `addons/Family/Index.lua`, `tests/Harness.lua`,
`tools/mutations/*.mut`, `CHANGELOG.md`, `docs/DECISIONS.md`, `docs/LESSONS.md`.
- `makerBlock` asks `Recipes:MadeBy(itemID)` first and hands the spell to `KnowersOf`;
  `KnowersOf` takes the name path only where no shipped table answered for the item. Check:
  hovering a product whose spell is in `RecipeProducts` makes no `Names:Spell` call.
- `Index:HeldBy` must not force a whole rebuild for a page about one member: build that
  member's part on demand, or rebuild one member per step after login the way
  `Database:WarmPayloads` does. Check: opening one member's professions page decodes one
  record (count `Codec:Decode` calls).
- Lesson to write: a helper made a one-member page a whole-family question and nothing said so
  (L-094's class). The check above is what now catches it.

**Step 3. Cover the `plain` path and measure the loading screen.** May touch:
`tests/Harness.lua`, `addons/Family_UI/Slash.lua`, `addons/Family/Database.lua` (two
timestamps only), `addons/Family/Family.toc` if a last file is needed, four locales,
`tools/mutations/*.mut`, `CHANGELOG.md`, `docs/DECISIONS.md`.
- A second pass of the database, scanner and reader checks with `Codec.compressing` false
  (`codec = "plain"`), with a fixture record holding a numeric key, a hole in an array and a
  `false`.
- After every scanner and every reader exercised on the plain path, `Codec:Fingerprint` of the
  stored payload equals the one taken at the last `SetPayload`: no mutation outside a write.
- `/family status` prints Family's own load time: `debugprofilestop()` at the end of the last
  file the `.toc` loads and at `ADDON_LOADED`; the saved-variables parse is between them. Read
  once now on the 31-member account, again after step 4.

**Step 4. Backlog 74, way 1, only after R1 and Alberto's confirmation.** May touch:
`addons/Family/Database.lua`, `addons/Family/Codec.lua`, `addons/Family_UI/Slash.lua`,
`addons/Family_UI/About.lua`, `addons/Family_UI/Options.lua`, four locales, `tests/Harness.lua`,
`tools/mutations/*.mut`, `CHANGELOG.md`, `docs/DECISIONS.md`, `docs/BACKLOG.md` 74,
`docs/HANDOFF.md` §1 and `docs/Project high level specs.md` §2.4 (both currently say records
are compressed and decoded on demand; they must say what is true after this).
Amendments to the plan in the brief, all recommended by the review:
- the write stamp carries a per-session nonce beside `time()` and the write count, so `Forget`
  and re-creation in the same second cannot collide;
- the migration computes the old string fold **before** replacing the string, stores it as
  `entry.mark`, and does not go through `SetPayload` (no new stamp, no `Changed`, no
  `Index:Invalidate`), so no member is resent and no walk repeats;
- `PayloadMark` answers `entry.mark` for a plain record; a plain record with no mark gets a
  fresh stamp the first time it is asked, as planned;
- `WarmPayloads` visits only records still stored as strings;
- per-part marks are **not** in this slice (see step 6);
- checks: a plain record round-trips through the SV shape; a migrated record keeps its mark;
  `sendingMark` of a migrated member equals the pre-migration value; `WarmPayloads` finds nothing
  on the second session; `/family status` says how many records are still compressed.
The 200-member experiment (a tool in `tools/` that multiplies the members of a saved
`Family.lua`, loaded on a test account with the original put aside) is Alberto's to run: it
overwrites a saved file.

**Step 5. A recipe index**, built one member per step after login, invalidated per member from
`SetPayload` as `Index.lua` already is, whole on `Changed("wide")`. `Search`, `KnowersOf`,
`Crafters` read it; `stillHeld` moves into the build; `ready` is computed at read time. May
touch: a new `addons/Family/RecipeIndex.lua` (name is the session's), `addons/Family/Family.toc`,
`addons/Family/Recipes.lua`, `addons/Family/Database.lua` (invalidation call), `tests/Harness.lua`,
`tools/mutations/*.mut`, `CHANGELOG.md`, `docs/DECISIONS.md`, `docs/HANDOFF.md` §1.

**Step 6. Stable marks for Wide Family: needs Alberto's yes first**, because it changes what
leaves the machine. Per-part marks folded at write time for the part the scanner names (not by
table identity: `Scanners/Professions.lua` reassigns the same table, and `Database.lua:257`
already says identity counts are a floor), with `seen`/`recipesSeen` left out and deadlines
rounded to the minute; the member mark is a fold of the part marks; the clocks travel in the
offering list (backlog 72 point 2) so a held-back member's age still refreshes on the far side.
Then observe with `/family widetime`; backlog 72's per-category send only if a large family
shows the need.

## 4. Do not

- Do not touch `everybody`, `Search`'s walk or the professions scanner in steps 1-3.
- Do not start step 4 before Alberto's *go* on the amended plan; R1 and R2 are taken and go
  into `DECISIONS.md` and backlog 74 first.
- Do not change the wire (`Wide.lua`, `Comm.lua`) without Alberto's yes.
- Do not persist any index: `Index.lua`'s header says why, and it still holds.
- Do not tag or deploy: Alberto's.
- Do not cite the brief's `Names.lua:132 = GetBuildInfo` reading anywhere; correct it.
