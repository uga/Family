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

Written down because a player reported a bag shown one slot along from where it sits, and the
mapping was the obvious suspect. It was not: the panel lists the bank's own window first and
the bags after it, so the first *bank bag* is the second *block*. There is nothing to fix in
either the mapping or the order, and this is here so the same suspect is not questioned twice.

### What the client cannot do

It has no network access. Any addon that talks to a server does it through a companion
desktop program reading SavedVariables. Plan accordingly: an in-game addon can *collect*, but
publishing what it collected is an out-of-game job.

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

Mists is not in it: its talents have ids of their own that the client resolves for any class.

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
