# Guild crafters — working handoff

**What this document is.** The design study behind specification §7.1, written up so the
build can be picked up cold. It is a *working* document: as each slice lands, what it says
moves into the specification, `DECISIONS.md` and the code, and the section here is struck
out. When all three slices have landed it is deleted, because by then it says nothing that
is not said better somewhere authoritative.

**Where authority lies.** The specification §7.1 governs behaviour. `DECISIONS.md` governs
project state — twelve rows dated 2026-08-29 carry the decisions this document explains.
Where this file and either of those disagree, they win and this one is stale.

**Line numbers below are as of `0a3716b`** and are given with the name of what they point at,
because names survive and line numbers do not. Re-read before citing (CLAUDE.md).

**Slices 1 and 2 seen working on a live wire, 2026-08-30.** Two accounts, one guild, Burning
Crusade: a profession ticked on one client, its recipe list crossing, and *Goblin Deviled
Clams* answering **Guild crafters — Rolando — 13m ago** on the other client's tooltip. Slice 3
is what remains.

**Re-read on 2026-08-29 at `v1.1.0`.** Every trap in §6 was checked against the source and all
seven held; none of the files §3 cites had changed, so its line numbers are still good. Traps 6
and 7 have since been cleared. §7.1 is at specification line 785 and the twelve `DECISIONS.md`
rows are present.

---

## 1. The question

*"Which guildie can craft this?"* It is asked in guild chat several times an evening and
answered by whoever is awake. The person who could make the thing is usually offline, and so
is the alt of theirs that has the profession — which is the case Family is for.

Family already answers this for **one family**: `Recipes:Crafters` and `Recipes:Search`. What
is missing is a second source of crafters, and the consent to fill it.

---

## 2. Status

| | |
|---|---|
| Specification | §7.1 written, plus three amendments to §7 above it |
| Decisions | twelve rows, `DECISIONS.md`, 2026-08-29 |
| Code | **slices 1 and 2 landed 2026-08-29, slice 3 on 2026-08-30.** The feature is complete |
| Harness | 70 checks, in the guild share section; every mutation tried against them failed one |
| Changelog | slices 1 and 2 are under **Unreleased** |

The three amendments to §7 were required rather than cosmetic: professions came off its
**Never** list, its opening no longer claims guild share "needs no approval at all", and the
consent-grid heading is now scoped to the list above it. Without those the section
contradicted the subsection.

---

## 3. What this builds on

Roughly seventy per cent of the feature exists. It answers for one family and it needs a
second source, not a new mechanism.

### Transport, already working

| Where | What it gives |
|---|---|
| `Guild.lua:45` `SCHEMA` | wire version, currently 1; a mismatch rejects the whole body |
| `Guild.lua:51` `STALE_AFTER` | six hours; the traffic control that makes "kept once seen" cheap |
| `Guild.lua:169` `Offering()` | our characters in this guild, built from records *now*, never from what was sent last time |
| `Guild.lua:276` `CharactersOf()` | what we hold about one player, found by who sent it rather than by who it is about |
| `Guild.lua:326` `Forget()` | drops a guild's records — **and nothing calls it**, see §6 |
| `Guild.lua:428` `forThisGuild()` | drops anything about a guild we are not in |
| `Guild.lua:525` `onData()` | replaces everything held from a sender rather than merging |
| `Comm.lua:47` `CHUNK` / `:51` `PER_TICK` | 200 bytes a message, two every 0.2s |
| `Comm.lua:314` `Comm:On` | one handler per kind; **an unknown kind is dropped harmlessly** |

### The consent pattern to copy

`Wide.lua:43` `CATEGORIES`, and `Wide.lua:805/812/834/850` — `Granted`, `setGrant`, `Grant`,
`GrantMany`. Guild crafters wants the same shape with different axes: members × professions
rather than members × categories.

### The answer, already written for one family

| Where | What it gives |
|---|---|
| `Recipes.lua:201` `Crafters()` | states `knows / can / later / level / unknown`, sorted in the order somebody deciding who to ask reads them |
| `Recipes.lua:113` `Search()` | one row per recipe, crafters beside it, keyed by spell id where there is one |
| `Tooltip.lua:165` `crafterLines()` | the "Family crafters" block |
| `Professions.lua` whole-family mode | the search box and its result rows |

### What is recorded per member

`Scanners/Professions.lua:596` writes `payload.professions[skillLineID]`, each carrying
`rank`, `maxRank`, `secondary`, `name`, and — only if that profession's window has been
opened — `recipes`, `recipesSeen`, `locale`, `openWith`. A recipe carries `name`,
`difficulty`, `available`, `icon`, and where the client gave one, `spellID` and `itemID`,
plus `hasCooldown` and `readyAt`.

`Scanners/Professions.lua:687` writes `meta.craftCooldowns`, entries of
`{ name, profession, readyAt }`. `Cooldowns.lua:36/124` read them.

---

## 4. The design

### 4.1 Consent

**One tick per member per profession.** Each character in the guild lists its professions and
each is ticked separately. Nothing is offered until it is. A tick carries the rank, the recipe
list and the cooldowns **together** — splitting them doubles the grid for a distinction almost
nobody holds an opinion about, and a grid that is tedious to read gets agreed to unread.

**Why this has a grid when gear does not.** Inspect shows gear and talents, so a dialogue in
front of them teaches players to click through dialogues. Inspect shows nobody's recipe list.
Same answer, two different facts — the grid is where the difference is visible, and §7's
argument is strengthened rather than undermined by it.

**No second switch.** Guild share's existing switch is the transport. A switch that does
nothing until you also tick something is two concepts where there is one; an empty grid
already says "nothing".

**And this feature does not change what that switch defaults to.** Guild share ships **off**
for a new player and for anyone whose saved variables have been cleared, and nothing here
alters that: a player who wants guild features turns them on, and one who does not is never
opted in on their behalf. With it off there are two independent reasons nothing crosses — no
transport, and an empty grid — and the grid must *look* inert rather than merely be inert. It
greys itself and says where the switch is, the way the Guild and Wide Family panels were made
to in 1.0.0. A live-looking grid that quietly records grants before the transport is on would
be the one way this feature could undo a default it has no business touching.

### 4.2 What a grant is attached to

Keyed by **guild, character and profession** together, and it works both ways:

- A **character who leaves the guild stops sharing.** `Offering()` already filters by the
  current guild, so this mostly falls out — but the grant must not survive into the next
  guild, which was never the guild that was agreed to.
- A **player who leaves the guild stops holding** what that guild shared. This needs a caller
  for `Forget()`; see §6.

What Family can promise is that it will not send what was not granted and will ask the other
side to forget what was withdrawn. The other end is somebody else's computer. That is a
promise honestly kept on this side, not a lock, and the interface must not imply otherwise.

### 4.3 What crosses the wire

**Identifiers, never names** (§2.1). A shared recipe is its `spellID`, with the `itemID` of
what it makes beside it — the second one is what lets the answer appear on a **crafted item**
and not only on a pattern. A recipe the client gave no id for **is not shared**, and the count
of those is shown rather than quietly dropped.

**A new message kind with its own schema.** `gdata` stays at `SCHEMA = 1`. Bumping it would
make every 1.0.0 client drop the whole message and be dropped in turn; an unknown kind is
already discarded harmlessly (`Comm.lua:314`), so an old client simply sees no professions
while still exchanging gear and talents.

### 4.4 Traffic

A recipe list is the largest thing §7 has ever carried.

~~**Estimated**, not measured: a maxed primary is 150–250 recipes; two ids each, sorted and
delta-encoded through LibSerialize and LibDeflate, plausibly 600–900 bytes, so three to five
chunks per profession. Three characters sharing five professions is roughly 4KB, about twenty
chunks, about two seconds of queue.~~

**Measured 2026-08-29, `tools/wire-size.lua`.** Against the real libraries, because the harness
stubs both with pass-throughs and can therefore prove the protocol but not weigh it.

| recipes | array of pairs | two arrays | two arrays, delta-encoded | chunks | seconds |
|---:|---:|---:|---:|---:|---:|
| 50 | 339 | 284 | **250** | 2 | 0.2 |
| 150 | 893 | 739 | **617** | 4 | 0.4 |
| 250 | 1,444 | 1,178 | **983** | 5 | 0.5 |
| 400 | 2,282 | 1,884 | **1,511** | 8 | 0.8 |

**The estimate was right about the shape and about half of the size.** A maxed primary is
983 bytes and five chunks, inside the 600–900 guess only if you read the low end of the recipe
range. The figure that was properly wrong is the one the feature is sized by: a character with
two maxed primaries and three secondaries is **2,824 bytes and 15 chunks**, and three such
characters are **8,472 bytes, 43 chunks and 4.3 seconds of queue** — a little over twice the
4KB / twenty chunks / two seconds that was written down.

The conclusion the estimate drew survives the correction: that is affordable once, and the
fingerprint below is what makes it affordable for ever. Four seconds of queue on the day a
guild meets is not a cost worth designing around; four seconds every login would be.

**Two decisions come out of the table rather than out of taste.** Recipes cross as two
parallel arrays rather than as an array of `{spellID, itemID}` tables — the pairs shape costs
about a third more, because every entry pays for its own keys. And the spell ids are **sorted
and sent as deltas**, which is a further sixth: sorted ids differ by tens or hundreds, and
LibSerialize spends one byte on a small integer and three on a large one. Item ids stay
absolute, because they are in spell order and therefore in no order of their own — delta
encoding an unsorted run makes it larger, not smaller.

That is affordable once. What makes it affordable forever is a **fingerprint**: each shared
profession announces its recipe count and a cheap hash of the sorted ids, and the list is
asked for only when that differs from what is held. A settled guild costs nothing after the
day everybody met. Withdrawing a profession changes the fingerprint, so a withdrawal is never
mistaken for something already held and skipped.

### 4.5 Cooldowns

For shared professions and no others, which follows from a tick meaning one thing.

They travel as **seconds remaining** and are stored on arrival as the moment they come ready.
Two clients need not agree on an epoch; a duration is right whoever reads it. Storing a moment
is still the rule everywhere else, because a countdown written yesterday is wrong today.

The distinction `Cooldowns.lua` already draws is carried across unchanged: a **craft** is used
through a window Family watches, so one reading *ready* is evidence; an **item** is used out of
the bags where Family sees nothing, so it crosses only while still running and never as a claim
that it is available.

They appear **beside the crafter**, not as a board. For anything with a cooldown, "who can make
this" is the wrong question and "whose is up" is the right one.

### 4.6 Where the answer appears

Two places, and no third:

- **The item's own tooltip**, under the crafters from your own family. Capped and ordered —
  knows it first, online first — because a tooltip that fills the screen has answered a
  different question.
- **The recipe search that already exists**, as a second group labelled as the guild's.

The Guild tab keeps being about people, and **the grid of what you share lives there**, beside
the roster it governs, as Wide Family's grid lives on Wide Family's panel. A switch belongs in
Options; a grid does not, because a grid is the feature rather than a preference about it.

**The answer is a person, not a character.** Guild records are keyed by the player who sent
them, so a row reads as *this player, online now on that character, has an alt who can make
it*. You whisper the player.

---

## 5. The slices

Each is recorded, stored and shown before the next begins. Each is worth having alone.

### ~~Slice 1 — ranks~~ — landed 2026-08-29

~~The grid, and profession-with-rank crossing the wire.~~

**What it turned out to be**, where this section was not already right:

- The grid is `FamilyDB.guild.grants[guildKey][memberKey][skillLine]`, and `Guild:Shares` /
  `Guild:SetShare` are its two doors. Absence is the answer, so nothing is written for a box
  nobody has touched — the same shape `Guild:Enabled` uses.
- A change to the grid **announces to the guild at once**, as `ghello` carrying `changed =
  true`, debounced by eight seconds. That field is read by one line in `onHello`: the traffic
  control skips the exchange when what the other end holds is recent, which is right for a
  login and is precisely what a withdrawal has to get past. Whispering each person instead was
  considered and refused — it is unbounded, and the channel already has a message for this.
- `Guild:Forget` now drops the **grid** as well as the records, and its caller is
  `Guild:ForgetLeft`, run before the switch is consulted on entering the world and five
  seconds after `PLAYER_GUILD_UPDATE`. It decides from our own members' records rather than
  from the guild being stood in, which is what makes an alt in a second guild safe (trap 4:
  a stale `meta.guild` keeps a guild too long, never drops one too early).
- The grid is **folded by default** and its heading is the switch, kept in
  `FamilyDB.ui.guildGrid`. Thirty rows of grid standing on a roster of a hundred and sixty is
  a grid hiding the panel it was put on.
- The tick boxes are **lifted five frame levels above the rows**, and the grid's rows have
  their mouse switched off. A row is a Button and takes the mouse from birth, so the first
  version of this shipped a grid nobody could click — see L-022, which is also about the
  harness check that was supposed to catch exactly that and did not.
- The **tooltip did not join this slice**. Its *may know it* line needs `Recipes:Crafters` to
  take a second source, which is slice 2's file list. Slice 1 shows its answer on the Guild
  panel instead, beside the character it is about — recorded, stored and shown without
  reaching into slice 2's files.

- **Store:** grants under the guild key, by member key and skill line. No default is written;
  absence is the answer, as `Guild:Enabled` does it.
- **Wire:** per member, a list of `{ skillLine, rank, maxRank }`. Under a hundred bytes for a
  family; it can ride with what §7 already sends.
- **Receive:** onto the existing per-sender record, replaced wholesale like everything else.
- **Show:** the tooltip block. With ranks alone the honest states are *may know it* and *not
  enough skill yet* — **never** *cannot*, and never *knows it*.
- **Files:** `addons/Family/Guild.lua`, `addons/Family_UI/Guild.lua`, `tests/Harness.lua`,
  `CHANGELOG.md`, `docs/DECISIONS.md`.
- **Checks:** a grant absent by default; a grant for a character not in this guild is never
  offered; leaving the guild empties the offering; a rank arrives and is read back; the
  tooltip never says *knows it* without a recipe list.

### ~~Slice 2 — recipes~~ — landed 2026-08-29

~~The list of ids, the fingerprint, and the search. This is the slice the feature is named
for.~~

**What it turned out to be**, where this section was not already right:

- The wire shape came out of `tools/wire-size.lua` rather than out of taste: two parallel
  arrays, and the sorted spell ids sent as the gaps between them. See §4.4, now measured.
- Lists live in `FamilyDB.guild.recipes`, **apart from `known`** — because everything a player
  sends in `gdata` replaces everything held from them, which is what makes a withdrawal take
  effect and is exactly what a list asked for once must survive. It is pruned deliberately
  instead, when a profession stops appearing in what arrives.
- `grec` carries the list's own age (`recipesSeen`) as well as arriving with one, so the two
  ages §7.1 asks for can compose. An older client sends only the second, and absent is a fine
  answer for the first.
- Both surfaces landed: the tooltip block and the search group. The tooltip needs no
  profession and no skill requirement — it matches on the ids, which is why it works on a
  crafted item where the family's own block, working from the item's subtype, often cannot.
- The search resolves every guild id to a name through *this* client's tables on each
  keystroke, bounded by a ceiling. That is the §2.1 payoff made visible, and it is the one
  check in the whole harness that proves it end to end.

- **Wire:** per shared profession, sorted `spellID`s with `itemID` where known, plus the count
  and fingerprint. Recipes without an id are omitted and counted.
- **Receive:** replace per sender per profession.
- **Show:** the guild group in the whole-family search, and *knows it* in the tooltip.
- **Files:** `addons/Family/Guild.lua`, `addons/Family/Recipes.lua`,
  `addons/Family_UI/Professions.lua`, `addons/Family_UI/Tooltip.lua`, `tests/Harness.lua`,
  `CHANGELOG.md`, `docs/DECISIONS.md`.
- **Checks:** a withdrawn profession disappears at the next exchange; an unchanged list is not
  re-sent; a changed one is; a recipe with no id is omitted *and counted*; a French-recorded
  list is found by a German search, because only ids crossed.

### ~~Slice 3 — cooldowns~~ — landed 2026-08-30

Done as written, with three additions the writing did not foresee.

- The cooldown entry carries **both** ids rather than the `spellID` this said, for slice 2's
  measured reason: Era knows a transmute only as the item it makes.
- **Which cooldowns are running is part of `MarkChanged`'s comparison.** Without it the wire
  was right and the feature was wrong: cooldowns ride along on `gdata`, nothing on `gdata`
  goes out unless something changed, and a cooldown starting changed nothing the comparison
  looked at — so a transmute used this afternoon went on reading *ready* at the far end.
  Coarse on purpose, because `readyAt` drifts by a second or two on every scan.
- **The family's own crafters carry it too**, on both surfaces. A tooltip saying a guildmate's
  transmute is up while saying nothing about your own alt's answers half a question.

`Cooldowns:Sharable` holds the item/craft rule, in the file that argues it; `Guild.lua`
serialises what it hands over and turns durations back into moments at the door.

- **Measured:** a shared profession is 98 bytes on the offering, 170 with four cooldowns on it
  (`tools/wire-size.lua`, DATASOURCES §4).
- **Checks:** 25 of them, each pinned by a mutation. A duration crosses and becomes a moment;
  an item cooldown that has come ready does not cross; a craft that is ready does; an item's
  that arrives with no duration is neither shown nor written to disk; an hour on, a craft has
  come back and an item has stopped being a fact; a scan where a cooldown started announces
  and the same one scanned again a second later does not.

---

## 6. Traps found while studying

Each of these was read in the source, not remembered.

0. **A character who leaves the guild kept their recipe list.** **Cleared 2026-08-30.** The
   walk that reads an arriving offering only reaches the characters in it, so the third way a
   list stops being ours - not the guild left, not the profession unticked, but the character
   gone - had no path at all. Found by reading the three paths together rather than from a
   report: nothing could see it, because every answer looks the character up in `known` first.

1. ~~**`Guild:Forget` has no caller.**~~ **Cleared 2026-08-29.** `Guild:ForgetLeft` is that
   caller, and `Forget` now drops the grid for the guild as well as its `known` and `users`.
   Two checks hold it either way: a guild another of our characters is still in is *not*
   forgotten, and one none of them is in any more is.

2. ~~**`meta.craftCooldowns` has no `spellID`.**~~ **Cleared 2026-08-30.** The entry carries
   `spellID` and `itemID` both, and it was the one-line addition the note below predicted.

   The original note: `Scanners/Professions.lua:661` stored a localised recipe name, nothing
   keyed by a name can cross the wire (§2.1), and slice 3 was blocked until the entry
   recorded the id.

   **Smaller than it reads, checked 2026-08-29.** `recipe.spellID` is already set well before
   this point — `Scanners/Professions.lua:253` for trade skills and `:341` for crafts — so the
   entry can simply carry it. A one-line addition, not a change to how scanning works, which
   is worth knowing when sizing slice 3.

3. **Bumping `SCHEMA` would break every 1.0.0 client.** `onData` rejects the whole body on a
   mismatch. Hence the separate message kind.

4. **`meta.guild` is only refreshed when that character is played** (`Scanners/Identity.lua`).
   A character who left the guild while not being played still reads as in it until next
   login. Worth a thought in slice 1's leaving path.

5. **Recipes without a `spellID` are stored under a name and a locale.** They cannot be shared
   and must be *counted*, or the panel silently claims a smaller list than it shows.

6. ~~**Specification §11.0 is stale.**~~ **Cleared 2026-08-29.** It read "Settled 2026-08-27:
   it ships on" while `DECISIONS.md` line 111 had reversed that on 2026-08-28. §11.0 now
   records both answers and says which one shipped, and keeps the beta.2 live pass, which is
   still true of the feature switched on.

7. ~~**The reason `CLAUDE.md` and the session configuration are untracked is recorded only in
   `.gitignore`'s own comment.**~~ **Cleared 2026-08-29**, and it had grown: the effort
   accounting joined them in `.gitignore` the same day. Two rows in `DECISIONS.md` — one for
   what is kept out and why, one for the consequence, which is that anything a session must
   read has to live in a tracked document. That second one is why the routing table sits in
   `HANDOFF.md` and not in `CLAUDE.md` (L-021).

---

## 6a. The guild event log — what is known

Probed on Classic Era and Burning Crusade 2026-08-30 and written up in DATASOURCES §2. The two
questions that decided whether it could be a source at all both came back yes: **the calls
exist on a 1.15 client**, and **a rank-and-file member reads the whole log**. The two clients
answer identically.

What it gives is a `quit` row naming the character, which is an authoritative departure signal
that costs no wire and that every client reaches the same conclusion from.

What it does not give, and what therefore cannot be built on it alone:

- It is **capped at 100 entries**, a count and not a period. That covered a month and ten days
  in a busy guild and eleven months in a quiet one.
- **Whether a deleted character appears at all is untested**, and that is the case this was
  opened for.
- **Whether being kicked is a `quit` or a `remove` is unknown** — no removes in 200 entries
  across two guilds, beside 77 quits.
- Mists is unrun.

**The hundred-entry cap is not the problem it looks like**, and the reason is that its weakness
cancels itself. What 100 entries *reaches* falls as a guild's churn rises - two months in a
guild of a hundred and sixty, eleven months in a guild of a dozen - but the need for the log
falls the same way, because a guild busy enough to fill its log in two months is a guild where
everybody is exchanging with everybody anyway.

That holds at the harder reading too. The requirement is not "is the guild busy" but "have I
exchanged with **the owner of the departed character** since it left", which is much narrower.
It still holds: in the busy guild that happens within a session, and in the quiet guild where it
might take weeks the log reaches back months.

### Four ways a record goes wrong, and the line that actually divides them

The line is not whether there is a gap - all four leave one. It is **whether an owner who comes
back can close it**.

| what happened | repaired by | bounded by |
|---|---|---|
| a profession is unticked | the owner's next overlap with each person | their next login; failing that, the abandonment timeout |
| the owner leaves the guild **while playing that character** | the same | the same |
| the character is **kicked, or leaves, while its owner is not playing it** | nothing | nothing |
| the character is **deleted** | nothing | nothing |

**The first two are repairable, and no design can do better than they already do.** Unticking
goes through `offerChanged`, which changes `OfferHash`, and `onHello` skips an exchange only
when `not body.changed and not behind` - so the withdrawal is never swallowed by the six hours
and is never missed for being announced to an empty channel. But it still has to *reach*
somebody, and two addon clients can only talk while both are online. There is no offline
mailbox. **A withdrawal cannot reach a player who is not there, by any design at all** - so the
exposure runs until the two of them next overlap, and if the owner never logs in again it runs
until the abandonment timeout drops their whole record.

**The last two are not repairable even by an owner who plays every day**, because their own
records assert the wrong thing and everybody else is faithfully repeating it. That is the one
thing this protocol cannot route around: the owner is the authority.

**A crowded guild helps the first two and not the last two**, and works against them: a guild of
a hundred and sixty removes people, a guild of a dozen does not.

### The untick window is a consent question, not housekeeping

Worth stating plainly, because §7.1's promise - *"nothing has to be sent to take a grant away,
the next offering simply no longer contains what was withdrawn"* - is conditional on there being
a next offering that somebody hears, and that condition was never written down.

Until then, a profession somebody has withdrawn is still answerable on every client that holds
their last one. A stale character is cosmetic; this is consent. So **how long the abandonment
timeout runs is a decision about consent rather than about disk**, and that argues for a shorter
number than tidying up would suggest.

### The case the argument does not cover, and where this earns its keep

A character removed from the guild **while its owner is not playing it**.

`Offering()` builds from our own records, filtered on `meta.guild`, and `Scanners/Identity.lua`
only refreshes `meta.guild` for the character being played. `ForgetLeft` says so in its own
comment: one kicked while logged out "still reads as a member until their next login". So the
owner's client goes on offering that character to the guild, indefinitely, and **no exchange
corrects it** - because the correction would have to come from the owner, and the owner is the
one who is wrong.

Nothing else in §7 can reach that. Not the wholesale replacement, which faithfully replaces the
wrong list with the same wrong list. Not the abandonment timeout, which is about an owner who
has gone rather than one who is playing. Only Blizzard knows, and the event log is where it says
so - to every client in the guild at once, including the owner's own.

So this is not an accelerator on top of relay. It is the only source for one specific case, it
needs no relay to be worth building, and it would fix a hole that exists today.

And the thing no log can ever supply: a profession being unticked, or unlearned, is an absence
Blizzard knows nothing about. Versioned whole-player snapshots stay the floor if relay is ever
built.

---

## 7. To check in the game

### 7.0 Connected realms and `Offering()`'s realm test — open, suspected

`Guild.lua` `Offering()` takes our characters where `meta.guild == name` **and `meta.realm ==
realm`**. On connected realms two characters in one guild do not agree about what realm they
are on — which is the fact `Guild:Key` already sets out at length, and the reason the key never
crosses the wire. The same fact makes the realm half of that test exclude a character of ours
who is genuinely in the guild, on the partner realm.

Not changed, because it is not free: the realm test is also the only thing stopping a character
in a guild called *Ronin* on one realm being offered to a guild called *Ronin* on an unconnected
other, where the player has characters in both. A certain failure traded for a rare one is
probably the right trade, but it should be made on evidence.

`/family guild test` now names the case — *"in this guild but recorded on another realm, so
they are not offered"* — so the next live pass on a connected realm settles it either way.


Mists of Pandaria may already show guildmates' professions, and possibly their recipes, in its
own guild roster. If it does, the argument for the *rank* half looks different there, the way
Inspect changes it for gear.

`Capabilities.lua:15-58` is explicit that this is **not** settled by probing: probes were tried,
returned four wrong answers out of five, and now decide nothing, because the symbol surface of
these clients is not evidence about the game they run. So:

1. Open the guild frame on Mists. Is there a professions view?
2. If so, does it list a guildmate's **recipes**, and does it work for one who is **offline**?
3. While there, does every profession row yield a link with a spell id? That decides slice 2's
   omission count on that client.
4. Write down what was seen.

**Decided in advance** (`DECISIONS.md`, 2026-08-29): the feature behaves the same on all three
clients whatever the answer. A consent grid that means something different per expansion is a
grid nobody can reason about, and even where the game shows professions it does not show them
for somebody who is offline — which is the premise. A finding here goes in `DATASOURCES.md` as
context, not into `Capabilities.EXPECTED` as a branch.

---

## 8. Deliberately not decided

- **A standing guild cooldown board** — everything ready across the guild, in one list. A
  reasonable thing to want, not this, and addable later without changing anything above.
- **Sharing a craft alt that is not in the guild.** §7's scope is kept as written: a scope with
  a switch to widen it is not a scope. That alt is a Wide Family link.
- **Reagents.** "What can be made from this" is a different question and is not in scope.
- **A `merge=union` `.gitattributes` for the append-only logs.** Raised, not taken.
