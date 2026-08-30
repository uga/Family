# Family — Where the data comes from

Companion to `HANDOFF.md`, which says what Family is; this one says where its facts come
from. Everything Family holds, it holds because the client said it, or because another
Family said it (specification §6). Nothing is inferred from a table shipped in the box.

---

## 1. The order of preference

The one design principle stated here, and it is worth more than any dataset:

> **Ask the client first, by id, and store ids rather than words.**

A name stored as a word is one language and goes stale. A name stored as an id is every
language, is whatever Blizzard currently calls it, and is one line in a file instead of
eleven. Where the client can answer, nothing else should be asked, and nothing else should be
shipped.

---

## 2. The client itself

Free, correct, current, no licence question, all eleven languages at once. Everything below
was confirmed working on Classic Era, Burning Crusade Anniversary and Mists Classic.

### By id

| What | How |
|---|---|
| Zones, instances, wings, battlegrounds | `C_Map.GetAreaInfo(areaID)` |
| Factions | `C_Reputation.GetFactionDataByID(id).name`, older clients `GetFactionInfoByID(id)` |
| Spells, and so profession names | `GetSpellInfo(spellID)` |
| Item class / subclass names | `C_Item.GetItemClassInfo`, `C_Item.GetItemSubClassInfo`, older clients the bare globals |

The ids themselves are not in the client in any readable form — that is what §3 is for.

### Currencies, which are three different APIs wearing one name

Honor points, arena points and everything Mists calls a currency. There is no single call
that works on all three clients, and no way to ask which one this is — so each is tried in
turn and whichever answers is believed. `addons/Family/Scanners/Currencies.lua` does this.

| Client | How | Gives an id? |
|---|---|---|
| Mists, and anything on the modern engine | `C_CurrencyInfo.GetCurrencyListSize()` / `GetCurrencyListInfo(index)` → a **table** | yes, `info.currencyID`, or from `GetCurrencyListLink(index)` |
| The list-keeping clients before it | `GetCurrencyListSize()` / `GetCurrencyListInfo(index)` → **eleven return values** | only inside `GetCurrencyListLink(index)`, as `currency:<id>` |
| Burning Crusade Anniversary | `GetHonorCurrency()`, `GetArenaCurrency()` → a bare number each | **no** |

Three things this costs, all of them worth knowing before writing it again:

- **Only one of them may be used.** A client that keeps a list has honor in that list, so
  asking the standalone calls as well counts the same points twice under two keys that
  nothing downstream can tell apart.
- **The last row has no id**, which is the one place Family cannot key by one
  (specification §2.1). Those two get keys of Family's own — `honor` and `arena`, never
  translated and never shown — and the label on screen is whatever the client last called
  them.
- **A maximum of `0` means "no cap"**, everywhere it appears. Stored as `nil`, or every
  uncapped currency reports itself as permanently full.

Zero is a balance and nil is silence, and the client answers nil for both a missing call and
a currency it will not discuss — so a call that answers `0` is recorded as `0`, and one that
answers nothing at all records nothing (specification §2.2).

Caveat on factions: the client answers for a faction the character has actually met, and may
answer nothing for the other side's. Treat an empty answer as normal and fall through.

### By global string

A large vocabulary is simply sitting in `_G`, already translated. Confirmed useful:

- **Equipment slots** — `INVTYPE_HEAD`, `INVTYPE_CHEST`, `INVTYPE_CLOAK` (Back),
  `INVTYPE_HAND` (Hands), `INVTYPE_BODY` (Shirt), `INVTYPE_WEAPONMAINHAND`,
  `INVTYPE_WEAPONOFFHAND`, `INVTYPE_2HWEAPON`, `INVTYPE_RANGED`, `INVTYPE_RELIC`,
  `INVTYPE_TABARD`, `INVTYPE_BAG`, `SHIELDSLOT`
- **Stats** — `ITEM_MOD_AGILITY_SHORT` and siblings, `ITEM_MOD_HEALTH_REGENERATION_SHORT`,
  `ITEM_MOD_POWER_REGEN0_SHORT`
- **Reputation standings** — `FACTION_STANDING_LABEL1` … `LABEL8`
- **Qualities** — `ITEM_QUALITY3_DESC` (Rare) … `ITEM_QUALITY5_DESC` (Legendary)
- **Trade skill ranks** — `APPRENTICE`, `JOURNEYMAN`, `EXPERT`, `ARTISAN`
- **Classes** — `LOCALIZED_CLASS_NAMES_MALE`, keyed by the English name in capitals
- **Odds and ends** — `ARMOR`, `WEAPON`, `AUCTION_CATEGORY_WEAPONS`, `MISCELLANEOUS`,
  `ARENA`, `HONOR`, `PVP`, `REPUTATION`, `MOUNTS`, `PETS`, `COMPANIONS`, `REFRESH`

Armour types and most weapon types come from `GetItemSubClassInfo`: class 4 subclasses 1–4 are
Cloth/Leather/Mail/Plate and 6 is Shields; class 2 has Guns (3), Polearms (6), Daggers (15),
Fishing Poles (20); class 6 is Projectile with Bullet (2); class 0 has Elixirs (2) and Flasks
(3); class 7 has Parts (1) and Explosives (2); class 12 is Quest; class 3 is Gem.

**The client will not give you plain "Axes", "Maces" or "Swords."** It only ever says
"One-Handed Axes". Those three have to be written by hand — a small, complete list of the
exceptions, which is worth knowing in advance.

**Build every one of these behind a guard that skips a nil.** A constant a given client does
not have must simply not register, so the name falls through to whatever is next. Written that
way, a missing global degrades to English instead of erroring, and the same code runs on three
very different clients.

### Recipe links, measured rather than assumed

**`GetTradeSkillRecipeLink(index)` returns `nil` on Classic Era.** Not an unexpected link kind
— nothing at all. `GetTradeSkillItemLink(index)` answers normally beside it. Measured on
1.15.9 with a leatherworking window open:

```
row 1: recipe nil | item nil                     -- row 1 is the header
row 2: recipe nil | item |Hitem:15564:...|h[Renfort d'armure robuste]|h|r
row 3: recipe nil | item |Hitem:8173:...|h[Renfort d'armure épais]|h|r
```

The same character's saved records: 150 leatherworking, 67 cooking and 12 first aid recipes,
**an item id on every one and a spell id on none**.

So **the item a recipe makes is the identity most recipes actually have on Era**, and its name
is what `Family.Names:Recipe` falls back to — which is what names a recipe in the reader's
language there. The spell id is still preferred where a client does supply one, because a few
rows are not named after their product; smelting says *Smelt Copper* and makes a Copper Bar.
The link is read for `enchant:`, `spell:` and `trade:` rather than for the one kind that was
assumed, which costs nothing and is not what fixed Era.

**The Craft frame on Era is not only enchanting.** The same window carries the leatherworking
specialisations: with a leatherworking trade skill window open, `GetCraftName()` answered
*Travail du cuir d'écailles de dragon* — Dragonscale Leatherworking — with no recipes under it.
A craft window can therefore name something real and have nothing in it, which is why
`readCraftRecipes` returning nil on an empty list matters.

**The recipe-id window hands back a recipe and stops there.** Mists has `C_TradeSkillUI`, and
`GetRecipeInfo` answers with a name, a difficulty and an icon — and nothing at all about the
item the recipe produces. Read that way, every recipe on that client is a spell and no more,
and *"who can make one of these"* has only the recipe's **name** to work from: the product's
name for most trade skills, and not for the ones that are not named after what they make.
Smelting says *Smelt Copper* and makes a Copper Bar.

So `GetRecipeItemLink` is asked as well, through `TryCall` and read back — a client that does
not have the call answers nothing and the record is exactly as it was. **Not yet confirmed on a
live Mists client**, which is the one measurement on this page that is still an expectation;
`docs/SMOKE.md` asks for it.

**On the Craft frame the two calls are the other way round from their names.** Measured on
1.15.9 with an enchanting window open:

```
row 1: recipe nil | item |Henchant:20051|h[Bâtonnet runique en arcanite]|h|r
row 2: recipe nil | item |Henchant:20023|h[Ench. de bottes (Agilité supérieure)]|h|r
```

`GetCraftRecipeLink` is nil for every row, and `GetCraftItemLink` returns an **enchant** link —
including for the Runed Arcanite Rod on row 1, which does make an item. So the enchant id, which
is the spell, arrives through the call named after the item, and no item id arrives at all. That
character held 101 enchanting recipes with neither id until both links were read for both.

The rule that follows, and it is the same one twice: **read every link for every id it might
carry, and do not trust a call's name to say what it returns.**

### Bank containers, measured

The bank's own window is container `-1` and the bags bought for it start above the carried
ones, at `5`. `ContainerIDToInventoryID` maps them to consecutive inventory slots and is
correct — measured on 1.15.9 with a bank window open, via `/family bank`:

```
container -1: 24 slots, inventory slot nil     -- the window itself is not a bag
container  5: 14 slots, inventory slot 88, bag item 9587
container  6: 14 slots, inventory slot 89, bag item 11324
container  7: 20 slots, inventory slot 90, bag item 22248
container  8: 20 slots, inventory slot 91, bag item 22248
```

**`GetContainerNumFreeSlots(BANK_CONTAINER)` is wrong by four on Classic Era.** The bank has 24
slots and the client computes its free count from 28, so it reports four more free than exist,
whatever is in it. Measured two ways on live clients: a bank with all 24 slots occupied
reported 4 free, and an empty one reported 28 of 24 — which is where `scanned bank: 56/52 free`
came from.

Do not ask it. Every slot is read to record the contents anyway, so free is the size less what
was found, and a record derived that way cannot contradict itself. The same call's *second*
return, the bag family, is correct and is still used.

**And do not reach for `NUM_BANKGENERIC_SLOTS` to correct it.** It says 28 because Blizzard
builds these clients from one codebase and Era inherited the later files, not because Era has
28 bank slots — the same shape as the achievement API being present on Burning Crusade, which
`Capabilities.lua` is written around. A symbol in the client is a fact about the build, not
about the game.

The carried bags are not affected: all four of one character's bank bags added up exactly, and
so does the backpack.

Written down because a player reported a bag shown one slot along from where it sits, and the
mapping was the obvious suspect. It was not: the panel lists the bank's own window first and
the bags after it, so the first *bank bag* is the second *block*. There is nothing to fix in
either the mapping or the order, and this is here so the same suspect is not questioned twice.

### What the client cannot do

It has no network access. Any addon that talks to a server does it through a companion
desktop program reading SavedVariables. Plan accordingly: an in-game addon can *collect*, but
publishing what it collected is an out-of-game job.

---

### A client does not hear its own guild-channel addon message, measured on Mists 2026-08-30

Sending on the `GUILD` addon channel does **not** come back to the sender on Mists of Pandaria
Classic. Measured on a live client whose diagnosis read `announcements arrived: 1 (0 ours coming
back)` - it had received somebody else's announcement over that channel perfectly well and had
never once seen its own, across three runs.

Not Family dropping it: `Comm:Receive` has no filter on the sender, and `onHello` counts an
arrival *before* the echo guard discards it, so an echo would show in both numbers.

It matters because a diagnosis was built on the opposite assumption. *"This client has sent and
heard nothing at all, not even its own announcement coming back off the guild channel - that
points at the channel"* fires on Mists every time somebody is the only Family user online, and
names the one part of the system they cannot inspect. It now says what is known instead.

**Unmeasured on Era and Burning Crusade.** If they do echo, the sentence is only wrong on one
client; if they do not, it was never right anywhere.

### The guild event log, measured on all three clients 2026-08-30

`/family guild log`, run four times: in **ZERO** on Pyrewood Village (Era) as **rank index 8**,
a rank-and-file member; in **Loch Modan Yachting Club** on Thunderstrike (Burning Crusade) as
**Officer, rank index 2**; and in **Uga** on Mirage Raceway (Mists) as both **Initiate, rank
index 4** and **Guild Master, rank index 0**.

`QueryGuildEventLog`, `GetNumGuildEvents` and `GetGuildEventInfo` all exist. `GetGuildEventInfo`
answers with **eight values**:

| # | type | what it is |
|---:|---|---|
| 1 | string | the event: `invite`, `join`, `promote`, `demote`, `quit` |
| 2 | string | **the actor**, realm-qualified where the realm differs — `Ethelberg-NethergardeKeep`. On `invite` this is the person doing the inviting |
| 3 | string or **nil** | **the subject**, where the actor is not it: the invitee on `invite`, and nil on `join` and `quit` |
| 4 | string | a **rank name**, and this guild's own words — `Alt`, `Member`, `Guild Master`, and empty on `join` |
| 5–8 | number | **how long ago**, as years, months, days, hours |

Three things that are not what they look like:

- **Positions 5 to 8 are an elapsed time, not a date.** A row reading `0, 0, 0, 4` is four hours
  ago, and `0, 1, 10, 4` is a month and ten days ago. A calendar month is never 0 - and the
  Mists guild settles it: three events minutes old came back `0, 0, 0, 0`, which is a duration
  of nothing and could not be a date at all.
- **Index 1 is the oldest and the last index is the newest**, which is the opposite way round
  from a chat log. **Measured outright** in a guild made for the purpose: a character was
  taken out of the guild, then invited, then joined, in that order and by hand, and the log
  came back `[1] quit`, `[2] invite`, `[3] join`. **How** the first was done is not recorded,
  because it was not reported and must not be guessed - what was caused in a known order is the
  order, and that is all this rests on. Nothing is inferred there - the events were caused in
  a known order and the indices match it. It agrees with the offsets on the two older clients:
  Era `[1]` 1 month 10 days, `[3]` 1 month 7 days, `[100]` four hours; Burning Crusade `[1]` 10
  months 28 days, `[8]` 9 months 19 days, `[100]` 8 days.
- **Position 4 is a guild's own rank name**, not an index and not a game constant. `Alt` is a
  rank this guild invented. Nothing can key on it.

**A rank-and-file member reads the whole log**, and so do an officer and the guild master. Four
ranks across three clients, and on Mists an Initiate and the Guild Master read the same three
entries. That was the question that decided whether this could be a source at all: a log only
officers can read cannot settle anything, because everyone has to reach the same conclusion or
the guild disagrees about who is in it.

**All three clients answer identically** — same three calls, same eight values, same types,
same nil in position three on `join` and `quit`, same rank name in position four. Nothing here
is any one client's.

**A guild's own creation is not an event, and neither is its founder's membership.** The Mists
guild read `entries: 0` until somebody was invited, then 3. So asking is enough on Mists - the
zero was an empty history and not a failure to fetch.

**Capped at exactly 100 entries on both.** How far that reaches is the guild's business and not
the client's: 100 entries covered **a month and ten days** in the busy guild and **ten months
and twenty-eight days** in the quiet one. A count, not a period.

That cap matters less than it looks, and `GUILD-CRAFTERS.md` §6a has the argument: what the log
reaches falls as a guild's churn rises, and so does the need for it, because a guild busy enough
to fill a hundred entries in two months is a guild where everybody is exchanging with everybody
anyway.

| | Era, ZERO | Burning Crusade, Loch Modan Yachting Club |
|---|---:|---:|
| `invite` | 29 | 5 |
| `join` | 27 | 4 |
| `quit` | 26 | 51 |
| `promote` | 16 | 22 |
| `demote` | 2 | 18 |
| `remove` | — | — |

**Deleting a character produces a `quit`**, measured 2026-08-30 by deleting one: the log gained
`quit / Ginetta / nil / Initiate`, and the client also said *"Ginetta left the guild"* in chat.
So a deletion is indistinguishable from a departure, and that costs nothing - the consequence
is the same either way, which is that the character is gone and nothing of it should still be
offered. **This is the question the probe was opened for, and the answer is that there is a
trace.**

Two things fell out of the same run.

- **Position four is the rank at the moment of the event**, not the character's rank now.
  Ginetta reads `Member` on the entry where she left as a charter signee and `Initiate` on the
  one where she was deleted, because she rejoined at the default rank in between.
- **The log is a stream and not a state.** One character appears as many times as things
  happened to them - Ginetta is `quit`, `invite`, `join`, `quit` across four entries - so
  anything deciding *is this character in the guild now* has to take their **last** mention and
  not their first. With the oldest at index 1, that is the highest index that names them.

**Being kicked is its own kind, `remove`** - measured 2026-08-30, and the opposite of what 200
entries across two guilds had suggested.

Done through the **guild frame's Remove button**. `/gkick` does not exist on Mists of Pandaria
Classic and neither does `/gquit` - both answer *Unknown command*, reported by the player taking
the measurement. Whether a slash command elsewhere produces the same kind is untested; this
records what was actually pressed. The chat line was *"Pinetta has been kicked out of the guild
by Eccebombo"*. Neither of those guilds had kicked
anybody in its window, which is why a count of nothing is not a measurement.

**And it names the departed in a different position from `quit`.** This is the trap in the whole
table:

| kind | who has gone | who did it |
|---|---|---|
| `quit` | position **2** | — |
| `remove` | position **3** | position 2 |

`remove / Eccebombo / Pinetta / Initiate` is *Eccebombo removed Pinetta*. Reading position 2 the
way `quit` allows would conclude that **the guild master had left**.

**Position four means different things by kind**, so nothing may key on it. It is the departed
character's rank on `quit` (`Member`, then `Initiate` for the same character after a rejoin) and
on `remove` (`Initiate`, the removed one's, not the remover's); it is the *actor's* rank on
`invite` (`Guild Master`); and it is empty on `join`.

**The offsets tick.** The three oldest entries read `0, 0, 0, 0` when they were minutes old and
`0, 0, 0, 1` an hour later - the same rows, one hour older. That is positions five to eight
being an elapsed time, watched changing rather than deduced.

**Out of the guild, the log reads nothing.** A character kicked from the guild reads
`entries: 0`, with the calls all present. So this is only ever readable about a guild you are
currently in, which is the only case that matters.

---

## 3. wago.tools — the client's own tables, out of game

`https://wago.tools/db2/<Table>/csv?build=<build>` returns the client's DB2 tables as CSV, for
an exact build. This is where the ids in §2 come from, and where a good deal of item data
comes from.

Builds pinned today, which are what the numbers below were measured against:

| Game | Build |
|---|---|
| Classic Era | `1.15.9.69109` |
| Burning Crusade Anniversary | `2.5.6.69110` |
| Mists of Pandaria Classic | `5.5.4.69078` |

Tables that earned their keep:

| Table | What it gives |
|---|---|
| `AreaTable` | `ID`, `AreaName_lang` — the area ids |
| `Faction` | `ID`, `Name_lang` — the faction ids |
| `SkillLineAbility` | `MinSkillLineRank`, `TrivialSkillLineRankLow` (yellow), `TrivialSkillLineRankHigh` (grey) |
| `ItemSparse` | `Display_lang`, `OverallQualityID`, `ItemLevel`, `RequiredLevel`, `InventoryType`, `RequiredSkillRank`, `MinFactionID`, `MinReputation` |
| `Item` | `ClassID`, `SubclassID` |
| `ItemEffect` | `ParentItemID` → `SpellID`, which links a recipe item to what it teaches |
| `SpellName`, `SkillLine` | names, `DisplayName_lang` |
| `Talent` | `TierID`, `ColumnIndex`, `TabID`, `ClassID`, `SpellRank_0` — the spell a talent is |
| `TalentTab` | `ID`, `OrderIndex`, `ClassMask` — which of a class's three trees this is |
| `ChrClasses` | `ID`, `Filename` — the class file string `UnitClass` answers with |
| `ChrRaces` | `ID`, `Name_lang`, `Name_female_lang`, `ClientFileString`, `PlayableRaceBit` |

`Talent` and `TalentTab` are what `addons/Family/TalentSpells.lua` is generated from, by
`tools/talents.py`. **`Talent.SpellRank_0` is the spell id of a talent's first rank**, which is
the whole reason talents stopped needing to be stored as words: the client will not describe
another class's talents, but it will name any spell for any class. So that file ships no names
at all — a position maps to a spell id and the reader's own client answers, in every language
the game has.

Two measurements it rests on:

- **The client counts tiers and columns from one; the table counts from zero.** Taken from
  `Family_UI/Talents.lua`, which places a cell at `(tier - 1) * CELL` on a grid that has been
  looked at in the game.
- **Era and Burning Crusade disagree about 32 of the 419 positions they share.** Blizzard moved
  talents between them, so one merged table would name those 32 wrongly on one of the two
  clients. They are kept apart, keyed by the expansion number `Family.Capabilities` already
  derives from the interface version.

`TalentTab.Name_lang` supplies the three tree headings — *Arcane*, *Fire*, *Frost* — which are
the one part of the talent panel with no spell behind them. Fetched per locale, like
`SkillLine` and `ChrRaces`, because `GetTalentTabInfo` has the same limitation
`GetTalentInfo` has: it answers only for the class being played. Which class a tab belongs to
is taken by joining through the talents themselves — every `Talent` row carries both `TabID`
and `ClassID` — rather than by decoding `TalentTab`'s class bitmask, so it is the table saying
it rather than a person.

**Confirmed in use on all three live clients**, 2026-08-28, with `/family talents`: it reports
per specialisation how many of its talents the table can name without falling back, and every
member on every client answered N of N — 44 to 52 per class on Era, 61 to 67 on Anniversary,
18 per specialisation on Mists. That matters because where a client's language matches the
language a record was written in, a table that names nothing looks exactly like one that works:
the fallback is the recorded word, and the recorded word is the same word. Names matching the
game's own tooltips was necessary and not sufficient; this is the sufficient part.

Mists is in it too, in a shape of its own: six tiers of three, each talent carrying an id the
client reports and Family records, so there is no position to key on. It uses `SpellID` where
the other two use `SpellRank_0` — measured, not assumed: the ranked column is zero for a third
of the Mists rows and set for every one of the Era ones.

`ChrRaces` is what `addons/Family/Races.lua` is generated from, by `tools/races.py`. Three
findings there, all of which a hand-written table gets wrong:

- **`ClientFileString` is not unique.** Race 23 is `Human` as well — the Gilnean one — and
  races 24, 25 and 26 are all `Pandaren`. Read `PlayableRaceBit`: it is `-1` for every race a
  player cannot be, including 23, and the generator reads it rather than deciding.
- **The file string is not the name, even in English.** The undead are `Scourge` in it and
  *Undead* on their own character sheet, and night elves are `NightElf`. Falling back to it
  shows a player a word their game never uses.
- **Era genders race names in Russian and in nothing else.** `Name_female_lang` equals
  `Name_lang` for German, French and Spanish on 1.15.9 and differs on 2.5.6 and 5.5.4
  (*Zwerg*/*Zwergin*, *Humain*/*Humaine*). Era wins where the builds disagree, so both forms
  are shipped to recognise a word a client already wrote rather than to choose between them.

wago serves no German `ChrRaces` for Burning Crusade at all — the request succeeds and returns
an empty body — which costs nothing, because Era and Mists name every race on that build in
German. The generator reports it rather than filling the gap.

`SkillLine` is what `addons/Family/SkillLines.lua` is generated from, by `tools/skill-lines.py`.
`CategoryID` 11 is exactly the primary professions on every build; category 9 is a mixed bag of
racials and riding skills, so the four professions in it are named by id. Fetch it per locale
with `&locale=frFR`.

Three findings worth keeping:

- **The builds disagree about names, and both spellings are real.** Spanish calls skill 197
  `Costura` on Era and `Sastrería` on Burning Crusade, and skill 165 `Marroquinería` and
  `Peletería`. Anything matching on these has to accept either.
- **Russian skill 393 begins with a Latin `C` on Burning Crusade and a Cyrillic `С` on Era.**
  U+0043 against U+0421 — identical on screen, different bytes, and no amount of care would
  have caught it by hand. It is the single best argument in this file for generating tables
  rather than writing them.
- **Mists needs none of this.** `GetProfessions` there returns a name and its skill line id
  together. The table exists for Era and Burning Crusade, which hand back a name and nothing
  else. Which is fortunate, because wago serves the Mists build slowly enough to time out.

Two findings worth keeping:

- **The client does not carry the orange point of a recipe.** It has yellow and grey. Green is
  the midpoint of the two, computed. Orange is where the recipe is learned, which is trainer
  data, i.e. server data, i.e. not in the client at all. Where a recipe drops rather than
  being trained, its
  requirement is on the teaching item, via `ItemEffect` → `ItemSparse.RequiredSkillRank`.
- **`ItemSparse.MinFactionID` / `MinReputation` give the reputation an item requires**, for
  every item, without the character having to know it. That is a whole third-party library's
  job done by the client — 418 items on Era alone.

Licence position: these are Blizzard's own client files, republished. wago.tools is a mirror,
not an author. Using it carries whatever risk using the client's own data carries, and no
more; it does not create a *new* rights holder to negotiate with. That is a materially better
position than any compilation of the same facts by somebody else.

---

## 4. Measured numbers

Taken from the client's own tables, at the builds pinned in §3, so that nobody has to
re-derive them.

| | |
|---|---|
| Craft-level recipes | Era 1536, TBC +956, MoP +2804 = 5048 |
| Era items whose reputation requirement the client states outright | 418 |

### What a shared recipe list weighs, `tools/wire-size.lua`

Not from the client's tables but from the libraries the addon channel is fed through, and
here for the same reason: so that nobody re-derives it, and so that the next person to size
something for that channel has a real number to scale from.

Measured 2026-08-29 against LibSerialize and LibDeflate as fetched by `tools/FetchLibs.sh`,
encoded for the addon channel, and divided by `Comm.lua`'s own 200-byte chunk and two-chunks-
per-fifth-of-a-second queue.

| recipes | array of `{spellID, itemID}` | two parallel arrays | two arrays, spell ids delta-encoded |
|---:|---:|---:|---:|
| 50 | 339 | 284 | **250** |
| 150 | 893 | 739 | **617** |
| 250 | 1,444 | 1,178 | **983** |
| 400 | 2,282 | 1,884 | **1,511** |

A maxed primary profession is around 250 recipes: **983 bytes, five chunks, half a second**.
A character with two maxed primaries and three secondaries is 2,824 bytes and 15 chunks.

**The shape matters more than it looks.** An array of two-key tables costs about a third more
than two parallel arrays, because every entry pays for its own keys; delta-encoding the sorted
spell ids saves a further sixth, because LibSerialize spends one byte on a small integer and
three on a large one. Item ids are left absolute: they travel in spell order and so are in no
order of their own, and delta-encoding an unsorted run makes it bigger.

### The game's own word for every game noun Family's text uses, `tools/game-words.py`

Family writes sentences that name things in the game, and those nouns were translated by hand.
A hand-translated item name is a name no player recognises: the word on their screen came from
Blizzard and the word in the sentence came from a guess. A French player found two of them; the
Spanish and Russian ones nobody was going to find, and there were three.

Measured 2026-08-30 from `ItemSparse.Display_lang`, per locale, at the three builds pinned
above.

| our word | id | deDE | frFR | esES | ruRU |
|---|---:|---|---|---|---|
| mooncloth | 14342 | Mondstoff | Étoffe lunaire | Tela lunar | Луноткань |
| salt shaker | 15846 | Salzstreuer | Tamis à sel | Salero | Солонка |
| mageweave | 4338 | Magiestoff | Étoffe de tisse-mage | *see below* | Магическая ткань |
| hearthstone | 6948 | Ruhestein | Pierre de foyer | Piedra de hogar | Камень возвращения |

**The builds disagree about one of them.** Spanish calls item 4338 *Tela de paño mágico* on
Classic Era and *Paño de tejido mágico* on both Burning Crusade and Mists. The two newer builds
win, and it is written down here because it is the client's disagreement and not ours.

**Two things are deliberately not checked.** A spell name that is a verb phrase cannot be
pluralised into a sentence - the game says *Transmute: Arcanite*, *Transmutieren: Arkanit*,
*Transmutation d'arcanite*, and our text says "transmutes" as an ordinary plural noun, for which
there is no game string. And *auction house*, *mailbox* and *guild bank* are places and panels,
named by globals the client supplies at runtime rather than by anything in a DB2. Only nouns
with an id are checked.

**wago.tools answers 403 to Python's default User-Agent**, measured the same day: the same URL
is 200 to `curl` and 403 to a bare `urlopen`, and 200 again with any header set.

Every fetcher in `tools/` now sends one, and each was **exercised against the live server rather
than read**: its own `fetch()` was called with the cache pointed at a temporary directory and
stopped after the first request, and `skill-lines.py`, `races.py`, `talents.py`, `areas.py` and
`game-words.py` all answered 200. `areas.py` and `GenerateCraftLevels.py` already sent one.

The header names the project rather than pretending to be curl. This is somebody else's server
given away for nothing, and the courtesy sleep `areas.py` puts between requests is there for the
same reason.

The fetch path is only reached at a new build, which is exactly when nobody wants to be
debugging the fetcher - three of these had been broken for an unknown length of time and ran
only because their caches were already full.

**What a cooldown adds**, measured the same way on 2026-08-30: a shared profession on the
offering is **98 bytes**, and **170** with four cooldowns attached to it — about eighteen bytes
each, on a message that was going anyway. Four on one profession is already generous; a busy
alchemist has a transmute and a salt shaker. This is why they ride along on `gdata` rather than
having a message of their own.

**The harness cannot answer this.** It stubs both libraries with pass-throughs on purpose, so
it can prove the protocol and not weigh it. That is why this is a tool and not a check.
