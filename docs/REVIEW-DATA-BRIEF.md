# Brief for a second opinion: data, compression, whole-family questions, Wide Family, efficiency

Written 2026-09-13 at the end of a long working session, for a **fresh session on this repository**
that is asked for an opinion and not for code. Alberto (the author) wants an independent read of
the whole data path before a decision that rewrites every record on every player's disk is built.

## How to use this brief

- **Read `CLAUDE.md` first and follow it.** In particular: before citing a path, a function, a
  section or a measurement, read it in *your* session. Everything below is a pointer with the
  place it came from, not a substitute for opening the file. Where this brief and a file disagree,
  the file wins, and saying so is part of the answer.
- **Opinion only.** Change no code, commit nothing, deploy nothing. If a measurement would settle
  a question, write the reading Alberto should take in game (`/family ...` commands go in the
  game's chat frame, not in a shell).
- **Answer with a recommendation and numbered options**, with the cost of each, and say which
  claims are measured and which are inferred.
- Repository language is English; Alberto writes in Italian and reads both.

## What Family is, in the part that matters here

A World of Warcraft Classic alt manager (Era, Burning Crusade Anniversary, Mists). `addons/Family`
records, `addons/Family_UI` shows. One saved variable, `FamilyDB`, per account. Some users have
**200+ characters**. Wide Family links two accounts ("families") and exchanges characters over the
addon whisper channel.

Authoritative documents, by `CLAUDE.md`'s table: `docs/HANDOFF.md` (architecture and settled
decisions), `docs/Project high level specs.md` (behaviour), `docs/DATASOURCES.md` (data),
`docs/DECISIONS.md` (state), `docs/LESSONS.md` (mistakes), `docs/BACKLOG.md` (open entries),
`docs/WIDE-TRANSFER.md` (the transfer, with timings).

## 1. How a character is stored today

`addons/Family/Database.lua`, header comment and `record`, `Payload`, `SetPayload`:

- `FamilyDB.members[key] = { meta = {...}, codec = "ld1", payload = "<string>" }`.
- `meta` is small and plain: what the summary reads for everybody (money, level, free slots, the
  `*Seen` stamps).
- `payload` is everything bulky (bags, bank, mail, auctions, equipment, professions with every
  recipe, talents, quests, reputations, spells, pets, ...), serialised with LibSerialize, deflated
  at level 5 and printable-encoded (`Codec:Encode`, `addons/Family/Codec.lua`).
- **Every write re-encodes the whole payload.** Each scanner reads the payload, replaces its own
  key and calls `SetPayload`. The bag scan runs 0.5 s after every `BAG_UPDATE_DELAYED`, so after
  every loot (inventory table in `docs/BACKLOG.md` §72).
- `Payload(key)` decodes and caches for the session.
- Wide Family siblings are **not** in `FamilyDB.members`. They live under `FamilyDB.wide`
  (`Wide.lua`, `store()`), arrived as tables and are stored plain (`Recipes.lua`, comment above
  `everybody()`).

**Why compression was chosen**: `docs/HANDOFF.md`, *Lazy, compressed storage*, and spec §2.4. On
forty alts, parsing every record at login was called the largest single cost, so records are
decoded only for the character being looked at. Whether that was measured is not stated in the
text; checking is worth it.

## 2. Why that premise broke, and what has been done

Many readers now ask about **everybody at once** and decode every record:

- `Recipes:Search`, `Recipes:KnowersOf`, `Recipes:Crafters` through `everybody()` (`Recipes.lua`),
  which includes siblings;
- the possessions index behind item tooltips (`Index.lua`: built once, invalidated per member,
  not saved);
- the whole-family views in `Family_UI/Character.lua` and `Summary.lua`;
- the guild share (`Guild.lua`).

**Reported from play 2026-09-13**: *script ran too long* twice, at the first whole-family question
after login, under the recipe search and under a recipe tooltip.

- **Measured on Alberto's client** with `/family decodecost`: 31 records took 524 ms to decode, the
  largest 35–50 ms each (`docs/DECISIONS.md`, row "Records are decoded a step at a time after
  login").
- **Cause** (`docs/LESSONS.md` L-094): the recipe-name login walk used to decode members as a side
  effect. Backlog 25 taught it to skip unchanged members, and nothing decoded ahead any more.
- **Stopgap in place**: `Database:WarmPayloads` decodes one record every 0.3 s, starting 3 s after
  arrival. At 200 records that is about a minute, and the crash is still possible inside it.

**Backlog 74** (`docs/BACKLOG.md` §74) lists three ways:
1. stop compressing;
2. keep compressing and add small plain summaries;
3. spread decoding and answer partially.

**Alberto chose 1**. His argument: once a whole-family question has run, every record is decoded
in memory anyway, so compression saves no RAM. It only saves disk, which he does not mind. **The
build is paused** until this opinion is in.

**Not measured yet**:
- what the records weigh uncompressed (`/family decodecost` now prints it, but no reading is
  recorded);
- what parsing a plain `FamilyDB` of 200 characters costs at the loading screen.

## 3. The plan for 74 as it stood when paused

Nothing of this is in the tree. Review it, don't assume it is right.

1. **Storing.** `SetPayload` stores the table itself (`codec = "plain"`). The wire (Wide Family,
   guild share) keeps LibSerialize + LibDeflate.
2. **Migration without a stall.** A record still stored as a string is rewritten plain the first
   time `Payload` reads it. `WarmPayloads` then only visits records still stored as strings, one a
   step, and finds nothing to do from the next session on.
3. **The mark problem, which is the delicate part.** Two readers ask *has this member changed?*
   without decoding:
   - the login recipe-name walk (`Family_UI/Slash.lua`, `UI:WarmRecipeNames`, compared with
     `Names:ItemWalk`);
   - Wide Family's `sendingMark` (`Wide.lua`), which decides whom to resend.

   Both use `Database:PayloadMark`, a fold over **the stored string**, which returns nil for a plain
   record. Folding the table instead costs about 35 ms a record (`/family paycost`, table in
   BACKLOG §72), too much per exchange. So the plan:
   - stamp `entry.mark = "w<time()>.<session write count>"` on every `SetPayload`;
   - at migration, keep the old string fold as the mark, so updating does not resend every member
     of every family;
   - give a plain record with no mark a fresh one the first time it is asked.
4. **A hazard noticed, not resolved.** Once `payload` *is* the stored table, any code that changes
   a decoded payload in place without calling `SetPayload` now changes saved data, without moving
   the mark. Readers checked so far look read-only; scanners change and then write. This was not
   audited exhaustively.
5. **Probes.** `/family decodecost` and `/family status` would say how many records are still
   compressed. `About.lua` and `Options.lua` print "compressed storage" from `Codec.compressing`
   and would need rewording.

## 4. Wide Family, where efficiency bites next

`docs/WIDE-TRANSFER.md` §1–§4, `Comm.lua`, `Wide.lua`:

**The wire budget.**
- `LIMIT` 252, `PER_TICK` 2, `TICK` 0.2 give about **2.3 KB/s, one queue for every link**.
- About 3.8 KB per member as sent.
- 210 members over one link is about 6 minutes; over fifteen links, about 90 minutes
  (WIDE-TRANSFER §2, measured 2026-09-08 for the packing and arithmetic for the rest).

**Members are sent whole.** `offering` builds every granted category and `onData` replaces the
member (`link.members[memberKey] = entry`).

**The mark moves at an idle relog.**
- `sendingMark` includes `meta.lastSeen`, which every `SetMeta` writes.
- The payload holds `seen = time()` stamps written at every login (quests, talents, pets,
  achievements).
- Deadlines are computed from time left (`expiresBy`, `readyAt`) and jitter.
- Read on the client: `ld1:7510:2347148292` → `ld1:7510:1867974627` after a relog doing nothing
  (BACKLOG §72).
- Four payload keys are in no shared category and still move the mark.

**Backlog 72** (send only the categories that changed, mark each part at write time) is written with
an inventory and costs, and **deferred by Alberto** until a large family is observed.

**The `have` list.** About 20 bytes on the wire per member held (BACKLOG §41, two readings: 5 and 30
members).

**Reach.** A whisper reaches only the connected-realm group (spec §11.1, corrected 2026-09-13;
backlog 73).

## 5. Is the crash really about decoding?

Alberto asks for this to be judged on its own, before anything above is built on it. It is not
proven.

**What was reported.** Two *script ran too long* errors on 2026-09-13, each at the first
whole-family question after logging a character in.

- **First:** stopped at `Names.lua:132`, under `Recipes:Search` from the professions search box.
  - It was read as the item-name store asking `GetBuildInfo` on every name (`DECISIONS.md`, row
    *The item-name store asks the client for its build once*).
  - That fix went in (`1d8dea7`).
  - The row itself says it does not establish that the search now finishes in time: *the search
    still walks every recipe of every character on each keystroke*.
- **Second:** with that fix deployed, stopped at `Names.lua:280`, under `Recipes:KnowersOf` from a
  recipe tooltip.
  - In today's file that line is in `Names:Recipe`, straight after `Names:Spell(id)`, which calls
    `GetSpellInfo` / `C_Spell.GetSpellInfo`.
  - Check that the numbering matches the deployed file (`git log -- addons/Family/Names.lua`).

**What was measured.** Only the decode: 31 records, 524 ms, taken straight off the disk by
`/family decodecost`. The search and the tooltip were **not** timed with the records already
decoded. Nobody has checked whether the errors stop once `Database:WarmPayloads` has finished.

**What else fits the same evidence.**

- *script ran too long* names the line where the client's budget ran out, not where the time
  went (L-094). Both errors stopped in naming code, not in `Codec:Decode`.
- `Names:Recipe` only takes its fast path when the list was recorded in the reader's language.
  - Otherwise it asks the client for the spell's name, once per spell id per session, memoised
    in `recipeNames`.
  - A first whole-family pass can therefore make one client call for every recipe of every
    foreign or unlabelled list.
  - `Recipes.lua` calls it at lines 480 and 931 (matching *who teaches / can make*) and at 735
    (the search).
- How many lists really are foreign or unlabelled is unknown. The probe's *271 of 289* was wrong
  (L-095); the corrected `/family decodecost` names them, and no reading has been taken yet.
- The search runs on every keystroke and walks every recipe of every character, siblings
  included.
- **Why only now.** The missing pre-decode dates from `db45d3d` (2026-09-06). Work on 2026-09-12
  added to the same code paths: recipe row icons, *Can make it*, tooltip crafters. Neither cause
  is established.

**Readings that would tell them apart**, for Alberto to take in game. Say which you would take and
in what order:

- repeat the tooltip and the search after the warm-up has had time to finish (200 × 0.3 s is the
  upper bound; 31 × 0.3 s on his family);
- time `Recipes:Search` and `Recipes:KnowersOf` on their own, with every record already decoded;
- the corrected `/family decodecost`, for how many lists fall off the fast path.

If decoding turns out not to be the main cost, plain storage does not fix the crash, and the
opinion on §6's questions changes with it.

## 6. What Alberto would like an opinion on

0. **Is decoding the cause of the two crashes**, or one cost among several? Is naming recipes that
   fall off the fast path, or the per-keystroke walk, a better explanation? Which readings settle
   it first (§5)?
1. **Storage.**
   - Is stopping compression (74 way 1) right for families of 200+?
   - Or is there a better shape: plain storage with persisted derived indices, per-category
     storage, compressing only cold categories?
   - What does the loading-screen parse of a large plain `FamilyDB` risk, and how should it be
     measured before shipping?
2. **The mark under plain storage.** Is a write stamp sound, including across crashes, reloads,
   `Forget` and re-creation? Or should marks be per part, computed at write time, which would also
   serve backlog 72? Is keeping the old string fold across the migration safe?
3. **Whole-family questions.** Items have an index. Recipes are searched by walking every
   professions list, siblings included. Should recipes (and *who can make it*) get an index like
   `Index.lua`, invalidated per member? And does that remove the need for the other changes, or
   add to it?
4. **In-place mutation** once decoded and stored are the same table. How should it be guarded
   (read-only proxies, copy on write, a discipline plus a harness check)?
5. **Wide Family efficiency at scale.**
   - Is whole-member resend plus a moving `lastSeen` acceptable for 200 × N links, given 2.3 KB/s?
   - What should come first: stable marks (strip clocks, round deadlines), per-category sends
     (72), or something else?
6. **Order of work.** Which of the above should be built first so that each step is useful on its
   own, given the project's rule that a slice is one domain end to end.

## Where the tree stood

- Branch `main`, last commit `ac66954` (*Count only recipe lists in decodecost, and name the ones
  in another language*).
- The gate is `lua5.1 tests/Harness.lua .` (3171 checks, green); mutations are run with
  `python3 tools/mutate.py`.
- 51 commits are not pushed. Pushing, tagging and deploying are Alberto's.
